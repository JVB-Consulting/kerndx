// SPDX-License-Identifier: BUSL-1.1
/**
 * Section 51 (extended-load Phase 2): Load Test — UTIL_HttpClient callout storm
 *
 * First true-parallelism load test of extended-load Phase 2. Fires 50 concurrent HTTP
 * POST requests at /services/apexrest/v1/load-probe with body {"failRate": 50},
 * then verifies the framework's behavior under sustained parallel callout pressure:
 * inbound dispatch volume, outbound abort distribution, breaker state, and per-call
 * latency.
 *
 * SPEC vs ACTUAL — circuit-breaker + retry observability:
 *   the extended-load spec §7.8 expected the outbound to call .withRetry(3) + .withCircuitBreaker
 *   ('load-probe') + .withExponentialBackoff(3, 1) and to drive failures via a real
 *   HTTP rejection so the breaker would trip and retries would amortize. The deployed
 *   API_LoadProbeOutbound (Task 2.1, commit 95ed929) instead simulates failures via
 *   getValidationErrors() because API_Outbound.sendRequest() is `protected virtual`
 *   (not `global virtual`) and therefore non-overridable from subscriber code in a
 *   managed-package context. As a consequence, when failRate triggers:
 *     - The outbound call is ABORTED before HTTP dispatch (Status__c = 'Aborted')
 *     - No retries occur (aborts skip the retry path)
 *     - The circuit breaker does NOT see a failure (breaker only counts post-dispatch
 *       failures, not pre-dispatch validation aborts) — state stays CLOSED
 *     - No ApiIssue__c rows are created (issues are minted only on hard failures)
 *   The HTTP response from the inbound layer remains 200 OK because the inbound
 *   itself completes successfully — the abort is surfaced in the response body as
 *   {"outboundResult":"aborted: simulated failure (load probe)"}.
 *
 * BEHAVIOUR ASSERTIONS (HARD GATE):
 *   51a — All 50 inbound HTTP POSTs returned 200 (inbound dispatch always lands)
 *   51b — Exactly 50 Inbound ApiCall__c rows scoped to ServiceName=API_LoadProbe AND
 *         CreatedDate >= run-start
 *   51c — Exactly 50 Outbound ApiCall__c rows scoped to ServiceName=API_LoadProbeOutbound
 *         AND CreatedDate >= run-start
 *   51d — Outbound abort rate within ±20% absolute of failRate=50 (i.e., 30%-70%
 *         aborted; n=50 has substantial binomial variance, ±2σ ≈ ±14pp, so we use
 *         ±20pp as a conservative gate that catches gross misbehavior without
 *         flapping on legitimate variance)
 *   51e — All non-aborted outbound rows have Status__c = 'Completed' (no orphan/error
 *         status — confirms the success path stays clean under parallel load)
 *   51f — Breaker state is CLOSED after the burst (deployed shape — aborts don't
 *         trip; this is the actual framework contract for the v1.0 surface)
 *   51g — All non-aborted outbound rows have Retries__c = 0 (no retry storm; aborts
 *         and successes both bypass the retry path in the deployed shape)
 *   51h — DELETE → reset → GET state returns CLOSED with failureCount = 0
 *
 * SOFT-GATE METRICS (PERF_ROW: lines, harvested by Phase 2.5):
 *   wallMsTotal           — total wall clock for the parallel burst
 *   p50ResponseMs         — median per-request latency
 *   p95ResponseMs         — 95th percentile per-request latency
 *   breakerOpenAfterNCalls — null in the deployed shape (see deviation note above)
 *   retryWallMsAvg        — 0 in the deployed shape (no retries occur)
 *
 * Run-isolation: cleanup deletes the burst's ApiCall__c rows by Id at the end
 * (avoids cross-run pollution while leaving prior smoke-test data intact for
 * forensic inspection).
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - REST_LoadProbe + API_LoadProbe + API_LoadProbeOutbound deployed (Task 2.1)
 *   - Node 22+ (global fetch)
 *
 * Run:
 *   node release-testing/scripts/section-51-load-callout-storm.js
 *
 * Expected wall-clock: 30-60s (50 parallel HTTP + 4 ancillary calls + cleanup).
 */

const {execSync} = require('child_process');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');

const ORG_ALIAS = getSubscriberOrgAlias();
const ENDPOINT = '/services/apexrest/v1/load-probe';
const FAIL_RATE = 50;
const PARALLEL_COUNT = 50;
const CIRCUIT_ID = 'load-probe';
const ABORT_RATE_TOLERANCE_PP = 20;
const INBOUND_SERVICE = 'API_LoadProbe';
const OUTBOUND_SERVICE = 'API_LoadProbeOutbound';

function getOrgInfo()
{
	const raw = execSync(`sf org display -o ${ORG_ALIAS} --json`, {encoding: 'utf8'});
	const result = JSON.parse(raw).result;
	return {instanceUrl: result.instanceUrl, accessToken: result.accessToken};
}

async function sendProbe(instanceUrl, accessToken, body)
{
	const requestStart = Date.now();
	const response = await fetch(`${instanceUrl}${ENDPOINT}`, {
		method: 'POST', headers: {
			'Authorization': `Bearer ${accessToken}`,
			'Content-Type': 'application/json'
		},
		body: JSON.stringify(body)
	});
	let parsed;
	try { parsed = await response.json(); }
	catch { parsed = {parseError: true}; }
	const requestEnd = Date.now();
	return {
		statusCode: response.status,
		responseMs: requestEnd - requestStart,
		body: parsed
	};
}

async function getState(instanceUrl, accessToken, circuitId)
{
	const url = `${instanceUrl}${ENDPOINT}?circuitId=${encodeURIComponent(circuitId)}`;
	const response = await fetch(url, {
		method: 'GET', headers: {'Authorization': `Bearer ${accessToken}`}
	});
	return response.json();
}

async function resetCircuit(instanceUrl, accessToken, circuitId)
{
	const url = `${instanceUrl}${ENDPOINT}?circuitId=${encodeURIComponent(circuitId)}`;
	const response = await fetch(url, {
		method: 'DELETE', headers: {'Authorization': `Bearer ${accessToken}`}
	});
	return response.json();
}

function querySoql(soql)
{
	const escaped = soql.replace(/"/g, '\\"');
	const raw = execSync(
		`sf data query -o ${ORG_ALIAS} -q "${escaped}" --json`,
		{encoding: 'utf8', maxBuffer: 16 * 1024 * 1024}
	);
	return JSON.parse(raw).result;
}

function deleteByIds(ids)
{
	if(ids.length === 0) { return; }
	const fs = require('fs');
	const path = require('path');
	const csvPath = path.join('/tmp', `section-51-cleanup-${Date.now()}.csv`);
	fs.writeFileSync(csvPath, 'Id\n' + ids.join('\n') + '\n');
	try
	{
		execSync(
			`sf data delete bulk -o ${ORG_ALIAS} -s kern__ApiCall__c --file ${csvPath} --wait 5`,
			{encoding: 'utf8'}
		);
	}
	finally
	{
		try { fs.unlinkSync(csvPath); } catch {}
	}
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
	console.log('PERF_ROW: ' + JSON.stringify({section: 51, metric, value}));
}

async function main()
{
	console.log('');
	console.log('=== Section 51 (extended-load Phase 2): Load Test — UTIL_HttpClient callout storm ===');

	const {instanceUrl, accessToken} = getOrgInfo();
	console.log(`Target:       ${instanceUrl}`);
	console.log(`Circuit ID:   ${CIRCUIT_ID}`);
	console.log(`Burst size:   ${PARALLEL_COUNT} parallel HTTP POSTs`);
	console.log(`Fail rate:    ${FAIL_RATE}% (server-side simulated)`);
	console.log('');

	const failures = [];
	let pass = 0;
	let fail = 0;

	console.log('Phase 0: Pre-flight reset of circuit breaker');
	await resetCircuit(instanceUrl, accessToken, CIRCUIT_ID);
	const stateBeforeBurst = await getState(instanceUrl, accessToken, CIRCUIT_ID);
	console.log(`  state=${stateBeforeBurst.state}, failureCount=${stateBeforeBurst.failureCount}`);
	console.log('');

	console.log(`Phase 1: Parallel burst of ${PARALLEL_COUNT} HTTP POSTs (failRate=${FAIL_RATE})`);
	const runStartIso = new Date().toISOString();
	const burstStart = Date.now();
	const probeBody = {failRate: FAIL_RATE, circuitId: CIRCUIT_ID};
	const probePromises = Array.from(
		{length: PARALLEL_COUNT},
		() => sendProbe(instanceUrl, accessToken, probeBody)
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

	if(ok200.length === PARALLEL_COUNT)
	{
		recordPass('51a', `All ${PARALLEL_COUNT} HTTP POSTs returned 200`);
		pass++;
	}
	else
	{
		recordFail('51a', `Expected ${PARALLEL_COUNT} HTTP 200 responses, got ${ok200.length}`, failures);
		fail++;
	}

	console.log('Phase 2: Server-side ApiCall__c row inspection (scoped by ServiceName + CreatedDate)');
	const callRowsResult = querySoql(
		`SELECT Id, kern__ServiceName__c, kern__Direction__c, kern__Status__c, ` +
		`kern__StatusCode__c, kern__Retries__c FROM kern__ApiCall__c ` +
		`WHERE kern__ServiceName__c IN ('${INBOUND_SERVICE}', '${OUTBOUND_SERVICE}') ` +
		`AND CreatedDate >= ${runStartIso} ORDER BY CreatedDate ASC`
	);
	const allRows = callRowsResult.records || [];
	const inboundRows = allRows.filter(r => r.kern__ServiceName__c === INBOUND_SERVICE);
	const outboundRows = allRows.filter(r => r.kern__ServiceName__c === OUTBOUND_SERVICE);
	const outboundAborted = outboundRows.filter(r => r.kern__Status__c === 'Aborted');
	const outboundCompleted = outboundRows.filter(r => r.kern__Status__c === 'Completed');
	const outboundOther = outboundRows.filter(
		r => r.kern__Status__c !== 'Aborted' && r.kern__Status__c !== 'Completed'
	);

	console.log(`  Inbound rows:   ${inboundRows.length}`);
	console.log(`  Outbound rows:  ${outboundRows.length} (Aborted=${outboundAborted.length}, Completed=${outboundCompleted.length}, Other=${outboundOther.length})`);
	console.log('');

	if(inboundRows.length === PARALLEL_COUNT)
	{
		recordPass('51b', `Exactly ${PARALLEL_COUNT} Inbound ApiCall__c rows landed`);
		pass++;
	}
	else
	{
		recordFail('51b', `Expected ${PARALLEL_COUNT} Inbound rows, got ${inboundRows.length}`, failures);
		fail++;
	}

	if(outboundRows.length === PARALLEL_COUNT)
	{
		recordPass('51c', `Exactly ${PARALLEL_COUNT} Outbound ApiCall__c rows landed`);
		pass++;
	}
	else
	{
		recordFail('51c', `Expected ${PARALLEL_COUNT} Outbound rows, got ${outboundRows.length}`, failures);
		fail++;
	}

	const observedAbortPct = outboundRows.length > 0
		? (outboundAborted.length / outboundRows.length) * 100
		: 0;
	const abortDriftPp = Math.abs(observedAbortPct - FAIL_RATE);
	if(abortDriftPp <= ABORT_RATE_TOLERANCE_PP)
	{
		recordPass('51d', `Outbound abort rate ${observedAbortPct.toFixed(1)}% within ±${ABORT_RATE_TOLERANCE_PP}pp of failRate=${FAIL_RATE}% (drift=${abortDriftPp.toFixed(1)}pp)`);
		pass++;
	}
	else
	{
		recordFail('51d', `Outbound abort rate ${observedAbortPct.toFixed(1)}% drifted ${abortDriftPp.toFixed(1)}pp from failRate=${FAIL_RATE}% (tolerance ±${ABORT_RATE_TOLERANCE_PP}pp)`, failures);
		fail++;
	}

	if(outboundOther.length === 0)
	{
		recordPass('51e', `All non-aborted outbound rows have Status='Completed' (no orphan statuses)`);
		pass++;
	}
	else
	{
		const otherStatuses = [...new Set(outboundOther.map(r => r.kern__Status__c))].join(', ');
		recordFail('51e', `${outboundOther.length} outbound rows have unexpected Status (saw: ${otherStatuses})`, failures);
		fail++;
	}

	console.log('Phase 3: Circuit breaker state inspection');
	const stateAfterBurst = await getState(instanceUrl, accessToken, CIRCUIT_ID);
	console.log(`  state=${stateAfterBurst.state}, failureCount=${stateAfterBurst.failureCount}`);
	console.log('');

	if(stateAfterBurst.state === 'CLOSED')
	{
		recordPass('51f', `Breaker state CLOSED after burst (aborts do not trip breaker — deployed-shape contract)`);
		pass++;
	}
	else
	{
		recordFail('51f', `Expected CLOSED state after burst, got ${stateAfterBurst.state} (failureCount=${stateAfterBurst.failureCount})`, failures);
		fail++;
	}

	const allRetriesZero = outboundRows.every(r => Number(r.kern__Retries__c) === 0);
	const maxRetries = outboundRows.reduce(
		(max, r) => Math.max(max, Number(r.kern__Retries__c) || 0),
		0
	);
	if(allRetriesZero)
	{
		recordPass('51g', `All ${outboundRows.length} outbound rows have Retries=0 (no retry storm — aborts and successes bypass retry path)`);
		pass++;
	}
	else
	{
		recordFail('51g', `Some outbound rows have Retries>0 (max observed: ${maxRetries})`, failures);
		fail++;
	}

	console.log('Phase 4: Reset → CLOSED verification');
	const resetBody = await resetCircuit(instanceUrl, accessToken, CIRCUIT_ID);
	const stateAfterReset = await getState(instanceUrl, accessToken, CIRCUIT_ID);
	console.log(`  reset=${resetBody.reset}, post-reset state=${stateAfterReset.state}, failureCount=${stateAfterReset.failureCount}`);
	console.log('');

	if(stateAfterReset.state === 'CLOSED' && stateAfterReset.failureCount === 0)
	{
		recordPass('51h', `Reset succeeded — state=CLOSED, failureCount=0`);
		pass++;
	}
	else
	{
		recordFail('51h', `Post-reset state=${stateAfterReset.state}, failureCount=${stateAfterReset.failureCount} (expected CLOSED + 0)`, failures);
		fail++;
	}

	console.log('PERF metrics:');
	emitPerfRow('wallMsTotal', wallMsTotal);
	emitPerfRow('p50ResponseMs', p50);
	emitPerfRow('p95ResponseMs', p95);
	emitPerfRow('breakerOpenAfterNCalls', null);
	emitPerfRow('retryWallMsAvg', 0);
	console.log('');

	console.log('Phase 5: Cleanup — delete burst rows by Id');
	const idsToDelete = allRows.map(r => r.Id);
	try
	{
		deleteByIds(idsToDelete);
		console.log(`  Deleted ${idsToDelete.length} kern__ApiCall__c rows`);
	}
	catch(error)
	{
		console.log(`  Cleanup WARN: ${error.message}`);
	}
	console.log('');

	console.log(`Results: ${pass} passed, ${fail} failed out of 8`);
	if(fail === 0)
	{
		console.log('=== Section 51 COMPLETE: All callout-storm assertions passed ===');
	}
	else
	{
		console.log('=== Section 51 FAILED ===');
		failures.forEach(f => console.log(`  - ${f}`));
		process.exit(1);
	}
}

main().catch(error =>
{
	console.error(`Section 51 ERROR: ${error.message}`);
	console.error(error.stack);
	process.exit(1);
});
