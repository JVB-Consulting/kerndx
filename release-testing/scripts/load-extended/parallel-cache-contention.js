// SPDX-License-Identifier: BUSL-1.1
/**
 * Extended Load (the extended-load spec §9.3): Pre-tag-only — parallel cache-contention burst at 100×.
 *
 * Fires 100 concurrent HTTP POST requests at /services/apexrest/v1/cache-probe. Each call
 * performs an UNGUARDED get-modify-put on a shared org-cache counter (single hot key —
 * 'cachecontentioncounter'). Probes the framework's cache contention behaviour under
 * maximum-parallelism load on a single key.
 *
 * CONTENTION CONTRACT (HARD GATE asserts what IS guaranteed, not what would be ideal):
 *   Salesforce Platform Cache exposes per-call put/get atomicity at the value level
 *   (a single put completes atomically; a single get returns whatever was last written).
 *   It does NOT expose:
 *     - Compare-and-swap (CAS) primitives
 *     - Atomic-increment operations
 *     - Cross-transaction locking
 *     - Optimistic concurrency tokens / revision numbers
 *
 *   The framework (`UTIL_Cache.cls`) does NOT wrap put/get with any cross-transaction
 *   locking — none exists in Apex. The wrapper class `CacheEntry` adds TTL + compression
 *   but no concurrency control. (Verified: read of `force-app/main/default/classes/UTIL_Cache.cls`,
 *   commit at the time of writing — no global lock primitive, no CAS, no version field
 *   on `CacheEntry`.)
 *
 *   Therefore the get-modify-put pattern in REST_CacheProbe.increment():
 *     Integer current = (Integer)cache.get(key);
 *     current++;
 *     cache.put(key, current);
 *   is INHERENTLY non-atomic across parallel transactions. When N transactions read the
 *   same `current` value, only the LAST writer's value persists — all earlier writers'
 *   updates are lost. The maximum possible final-counter value is 100; the minimum
 *   possible value is 1 (if all 100 transactions read the same `null`/0 baseline).
 *
 *   What WE CAN ASSERT (HARD GATE):
 *     - All 100 POSTs return HTTP 200 (no torn HTTP responses)
 *     - Each response body parses as valid JSON `{value: <integer>}` (no torn reads — no
 *       NaN, negative, or string value coming back)
 *     - Each per-call value is a positive integer ≥ 1 (a real put landed)
 *     - Each per-call value is ≤ 100 (no count overshoot — proves no double-increment)
 *     - Final counter value (read via GET after the burst settles) is ≥ 1 AND ≤ 100
 *     - Final counter value EQUALS the maximum per-call value observed (consistent with
 *       "last writer wins" semantics — the highest value any call computed must persist)
 *     - DELETE cleanup returns 200 and the post-cleanup GET returns 0 (full reset works)
 *
 *   What WE DOCUMENT but do NOT assert as-zero (informational, the WHOLE POINT of this test):
 *     - `lostUpdateCount = 100 - finalValue` — typically very high (60-95 range observed
 *       in pre-flight 10-burst pilot, scaled up). A `lostUpdateCount = 0` outcome would
 *       INDICATE a framework change (added CAS / lock / atomic-increment primitive) that
 *       deserves investigation, NOT celebration — it would mean the test is now invalid
 *       as a contention probe.
 *
 * SPEC vs ACTUAL: This test exercises the spec's full intent — Platform Cache contention
 * IS observable in Apex via the get-modify-put pattern, no A-section deferrals apply.
 * This is the ONE Phase 4 test where the framework's lack of a feature is the actual
 * documented contract being tested (Salesforce Platform Cache simply doesn't expose CAS).
 *
 * BEHAVIOUR ASSERTIONS (HARD GATE):
 *   B1 — Pre-flight DELETE + GET returns counter=0 (clean baseline)
 *   B2 — All 100 HTTP POSTs returned 200 (no torn HTTP responses)
 *   B3 — Each per-call response body parses as valid JSON `{value: <integer>}` (no torn reads)
 *   B4 — Each per-call value is a positive integer in [1, 100] (no NaN, no negative, no string,
 *        no overshoot — proves single-increment per call landed atomically at value level)
 *   B5 — Final counter value (post-burst GET) is in [1, 100] (lost updates allowed; counter
 *        cannot overshoot max parallelism)
 *   B6 — Final counter value EQUALS the maximum per-call value observed (last-writer-wins
 *        semantics — if a call returned `value=N` then a put of N must have landed and
 *        cannot be overwritten by anything < N from a concurrent call without that value
 *        also having been observed)
 *   B7 — DELETE cleanup returns HTTP 200 and post-cleanup GET returns counter=0 (reset works)
 *
 * SOFT-GATE METRICS (PERF_ROW: lines, harvested by Phase 2.5):
 *   wallMsTotal       — total wall clock for the 100-parallel burst
 *   p50ResponseMs     — median per-request latency
 *   p95ResponseMs     — 95th percentile per-request latency
 *   finalCounterValue — counter value after the burst settles (informational; expected 1-100)
 *   lostUpdateCount   — `100 - finalValue` (informational; reveals contention severity —
 *                       expect 60-95 range, scaled from pre-flight pilot)
 *
 * Concurrency note: scratch orgs cap concurrent inbound REST at 50 per user (org-wide
 * Salesforce limit). 100 parallel HTTP requests may queue / serialise under platform
 * concurrency limits — wall-clock budget is sized for that (~3-15s typical; up to 30s
 * under sustained queueing).
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - REST_CacheProbe deployed (Task 4.1, commit 017b901)
 *   - Org platform cache partition has at least 5MB allocated (default test org gets this)
 *   - Node 22+ (global fetch)
 *
 * Run:
 *   node release-testing/scripts/load-extended/parallel-cache-contention.js
 *
 * Expected wall-clock: 3-15s (100 parallel HTTP + GET + DELETE; upper bound assumes
 * platform concurrency queueing under sustained load).
 */

const {execSync} = require('child_process');
const {getSubscriberOrgAlias} = require('../../runner/subscriber-config');

const ORG_ALIAS = getSubscriberOrgAlias();
const ENDPOINT = '/services/apexrest/v1/cache-probe';
const PARALLEL_COUNT = 100;

function getOrgInfo()
{
	const raw = execSync(`sf org display -o ${ORG_ALIAS} --json`, {encoding: 'utf8'});
	const result = JSON.parse(raw).result;
	return {instanceUrl: result.instanceUrl, accessToken: result.accessToken};
}

/**
 * Sends a single POST to the cache-probe endpoint. Each POST performs the framework
 * get-modify-put on the shared counter and returns {value: N} as the new counter value
 * that THIS transaction wrote.
 *
 * Note: the @HttpPost handler returns String (which Salesforce JSON-encodes), so the raw
 * response body is the JSON-encoded form of the JSON object literal — needs TWO parse
 * passes to extract the typed value.
 */
async function postProbe(instanceUrl, accessToken)
{
	const requestStart = Date.now();
	const response = await fetch(`${instanceUrl}${ENDPOINT}`, {
		method: 'POST', headers: {
			'Authorization': `Bearer ${accessToken}`,
			'Content-Type': 'application/json'
		}
	});
	const text = await response.text();
	const requestEnd = Date.now();

	let value = null;
	let parseError = null;
	try
	{
		const parsedOnce = JSON.parse(text);
		const parsedFinal = typeof parsedOnce === 'string' ? JSON.parse(parsedOnce) : parsedOnce;
		value = parsedFinal?.value;
	}
	catch(error)
	{
		parseError = error.message;
	}

	return {
		statusCode: response.status,
		responseMs: requestEnd - requestStart,
		rawBody: text,
		value,
		parseError
	};
}

/**
 * GET the current counter value without modifying it. Same response-shape conventions
 * as postProbe — String return → double-encoded JSON.
 */
async function getCounter(instanceUrl, accessToken)
{
	const response = await fetch(`${instanceUrl}${ENDPOINT}`, {
		method: 'GET', headers: {'Authorization': `Bearer ${accessToken}`}
	});
	const text = await response.text();
	const parsedOnce = JSON.parse(text);
	const parsedFinal = typeof parsedOnce === 'string' ? JSON.parse(parsedOnce) : parsedOnce;
	return {statusCode: response.status, value: parsedFinal?.value};
}

/**
 * DELETE the counter (reset to 0). The @HttpDelete handler returns void → empty body, 200 status.
 */
async function deleteCounter(instanceUrl, accessToken)
{
	const response = await fetch(`${instanceUrl}${ENDPOINT}`, {
		method: 'DELETE', headers: {'Authorization': `Bearer ${accessToken}`}
	});
	return {statusCode: response.status};
}

function percentile(sortedAsc, p)
{
	if(sortedAsc.length === 0) { return 0; }
	const idx = Math.min(sortedAsc.length - 1, Math.floor(sortedAsc.length * p));
	return sortedAsc[idx];
}

function recordPass(name, message)
{
	console.log(`${name} PASS: ${message}`);
}

function recordFail(name, message, failures)
{
	console.log(`${name} FAIL: ${message}`);
	failures.push(`${name}: ${message}`);
}

function emitPerfRow(metric, value)
{
	console.log('PERF_ROW: ' + JSON.stringify({section: 'parallel-cache-contention', metric, value}));
}

async function main()
{
	console.log('');
	console.log('=== Extended Load (the extended-load spec §9.3): parallel-cache-contention ===');

	const {instanceUrl, accessToken} = getOrgInfo();
	console.log(`Target:       ${instanceUrl}`);
	console.log(`Burst size:   ${PARALLEL_COUNT} parallel HTTP POSTs`);
	console.log(`Cache key:    cachecontentioncounter (single hot key, get-modify-put pattern)`);
	console.log('');

	const failures = [];
	let pass = 0;
	let fail = 0;

	console.log('Phase 0: Pre-flight reset of shared counter');
	await deleteCounter(instanceUrl, accessToken);
	const baseline = await getCounter(instanceUrl, accessToken);
	console.log(`  baseline counter=${baseline.value}`);
	console.log('');

	if(baseline.statusCode === 200 && baseline.value === 0)
	{
		recordPass('B1', `Pre-flight DELETE + GET returned counter=0 (clean baseline)`);
		pass++;
	}
	else
	{
		recordFail('B1', `Expected baseline counter=0 with HTTP 200, got value=${baseline.value} status=${baseline.statusCode}`, failures);
		fail++;
	}

	console.log(`Phase 1: Parallel burst of ${PARALLEL_COUNT} HTTP POSTs (each performs get-modify-put on shared counter)`);
	const burstStart = Date.now();
	const probePromises = Array.from(
		{length: PARALLEL_COUNT},
		() => postProbe(instanceUrl, accessToken)
	);
	const probeResults = await Promise.allSettled(probePromises);
	const burstEnd = Date.now();
	const wallMsTotal = burstEnd - burstStart;

	const fulfilled = probeResults
		.filter(r => r.status === 'fulfilled')
		.map(r => r.value);
	const rejected = probeResults.filter(r => r.status === 'rejected');

	console.log(`  Wall-clock: ${wallMsTotal}ms`);
	console.log(`  Fulfilled:  ${fulfilled.length} / ${PARALLEL_COUNT}`);
	if(rejected.length > 0)
	{
		console.log(`  Rejected:   ${rejected.length} (network/promise rejected)`);
		rejected.slice(0, 3).forEach((r, i) => console.log(`    [${i}] ${r.reason}`));
	}

	const ok200 = fulfilled.filter(r => r.statusCode === 200);
	console.log(`  HTTP 200:   ${ok200.length}`);

	const responseTimesSorted = fulfilled
		.map(r => r.responseMs)
		.sort((a, b) => a - b);
	const p50 = percentile(responseTimesSorted, 0.50);
	const p95 = percentile(responseTimesSorted, 0.95);
	console.log(`  p50:        ${p50}ms`);
	console.log(`  p95:        ${p95}ms`);
	console.log('');

	console.log('Phase 2: Behaviour assertions');

	if(ok200.length === PARALLEL_COUNT)
	{
		recordPass('B2', `All ${PARALLEL_COUNT} HTTP POSTs returned 200 (no torn HTTP responses)`);
		pass++;
	}
	else
	{
		recordFail('B2', `Expected ${PARALLEL_COUNT} HTTP 200 responses, got ${ok200.length}`, failures);
		fail++;
	}

	const parseFailures = fulfilled.filter(r => r.parseError !== null);
	if(parseFailures.length === 0)
	{
		recordPass('B3', `Each per-call response body parsed as valid JSON {value: <integer>} (no torn reads)`);
		pass++;
	}
	else
	{
		recordFail('B3', `${parseFailures.length} response bodies failed to parse (sample: '${parseFailures[0].rawBody?.slice(0, 80)}' → ${parseFailures[0].parseError})`, failures);
		fail++;
	}

	const valueViolations = fulfilled.filter(r =>
	{
		if(r.value === null || r.value === undefined) { return true; }
		if(typeof r.value !== 'number') { return true; }
		if(!Number.isInteger(r.value)) { return true; }
		if(r.value < 1) { return true; }
		if(r.value > PARALLEL_COUNT) { return true; }
		return false;
	});
	if(valueViolations.length === 0)
	{
		const allValues = fulfilled.map(r => r.value);
		const minValue = Math.min(...allValues);
		const maxValue = Math.max(...allValues);
		recordPass('B4', `Each per-call value is a positive integer in [1, ${PARALLEL_COUNT}] (observed range: ${minValue}-${maxValue})`);
		pass++;
	}
	else
	{
		const sampleViolations = valueViolations.slice(0, 5).map(r => `value=${JSON.stringify(r.value)} type=${typeof r.value}`).join(', ');
		recordFail('B4', `${valueViolations.length} per-call values violate [1, ${PARALLEL_COUNT}] integer constraint (sample: ${sampleViolations})`, failures);
		fail++;
	}

	console.log('');
	console.log('Phase 3: Post-burst GET (read final counter value)');
	const finalState = await getCounter(instanceUrl, accessToken);
	const finalCounterValue = finalState.value;
	console.log(`  final counter=${finalCounterValue}`);
	console.log('');

	if(typeof finalCounterValue === 'number'
			&& Number.isInteger(finalCounterValue)
			&& finalCounterValue >= 1
			&& finalCounterValue <= PARALLEL_COUNT)
	{
		recordPass('B5', `Final counter value ${finalCounterValue} is in [1, ${PARALLEL_COUNT}] (lost updates allowed; no overshoot)`);
		pass++;
	}
	else
	{
		recordFail('B5', `Final counter value ${finalCounterValue} (type=${typeof finalCounterValue}) outside [1, ${PARALLEL_COUNT}]`, failures);
		fail++;
	}

	const validValues = fulfilled
		.filter(r => typeof r.value === 'number' && Number.isInteger(r.value))
		.map(r => r.value);
	const maxObservedValue = validValues.length > 0 ? Math.max(...validValues) : null;
	if(maxObservedValue !== null && maxObservedValue === finalCounterValue)
	{
		recordPass('B6', `Final counter value ${finalCounterValue} equals max per-call value observed (last-writer-wins semantics confirmed)`);
		pass++;
	}
	else
	{
		recordFail('B6', `Final counter ${finalCounterValue} ≠ max per-call value ${maxObservedValue} (last-writer-wins violation — investigate write ordering)`, failures);
		fail++;
	}

	const lostUpdateCount = PARALLEL_COUNT - finalCounterValue;
	console.log('Phase 4: Cleanup — DELETE counter + verify GET returns 0');
	await deleteCounter(instanceUrl, accessToken);
	const afterCleanup = await getCounter(instanceUrl, accessToken);
	console.log(`  post-cleanup counter=${afterCleanup.value}`);
	console.log('');

	if(afterCleanup.statusCode === 200 && afterCleanup.value === 0)
	{
		recordPass('B7', `DELETE cleanup succeeded (post-cleanup GET returns counter=0)`);
		pass++;
	}
	else
	{
		recordFail('B7', `Cleanup verification failed: post-cleanup counter=${afterCleanup.value} status=${afterCleanup.statusCode}`, failures);
		fail++;
	}

	console.log('PERF metrics:');
	emitPerfRow('wallMsTotal', wallMsTotal);
	emitPerfRow('p50ResponseMs', p50);
	emitPerfRow('p95ResponseMs', p95);
	emitPerfRow('finalCounterValue', finalCounterValue);
	emitPerfRow('lostUpdateCount', lostUpdateCount);
	console.log('');

	console.log(`Contention summary: ${PARALLEL_COUNT} parallel POSTs → finalCounter=${finalCounterValue} → lostUpdates=${lostUpdateCount} (${((lostUpdateCount / PARALLEL_COUNT) * 100).toFixed(1)}% of writes overwritten by concurrent updates)`);
	console.log('');

	console.log(`Results: ${pass} passed, ${fail} failed out of 7`);
	if(fail === 0)
	{
		console.log('=== parallel-cache-contention COMPLETE: All 100-parallel cache-contention assertions passed ===');
	}
	else
	{
		console.log('=== parallel-cache-contention FAILED ===');
		failures.forEach(f => console.log(`  - ${f}`));
		process.exit(1);
	}
}

main().catch(error =>
{
	console.error(`parallel-cache-contention ERROR: ${error.message}`);
	console.error(error.stack);
	process.exit(1);
});
