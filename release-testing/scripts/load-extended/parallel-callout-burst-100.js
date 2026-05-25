// SPDX-License-Identifier: BUSL-1.1
/**
 * Extended Load (the extended-load spec §9.3): Pre-tag-only — parallel callout burst at 100×.
 *
 * Fires 100 concurrent HTTP POST requests at /services/apexrest/v1/load-probe with
 * body {"failRate": 50}, then verifies framework behaviour under maximum-parallelism
 * inbound dispatch pressure. 4× the section-32 burst (25 parallel), 2× the section-51
 * burst (50 parallel).
 *
 * Targets the breaker race window — many transactions checking breaker state
 * simultaneously BEFORE any failure recorded — combined with extended pre-tag-only
 * scope to expose race conditions invisible at smaller burst sizes.
 *
 * SPEC vs ACTUAL — original breaker-race intent NOT exercised in v1.0 surface:
 *   the extended-load spec §9.3 expected the burst to demonstrate the breaker race window:
 *     - N transactions check `allowRequest()` simultaneously, all see CLOSED, all proceed
 *     - Once breaker opens, subsequent requests fast-fail (no retry storm)
 *     - Breaker eventually opens (race window does NOT infinitely allow all 100)
 *
 *   Per consolidated tracker A32 (carried from Task 2.5, commit 83c4041):
 *   `API_Outbound.sendRequest()` is `protected virtual` (not `global virtual`) and
 *   therefore non-overridable from subscriber Apex in a managed-package context. As a
 *   consequence, `API_LoadProbeOutbound` cannot wire `.withRetry()` or
 *   `.withCircuitBreaker()` onto the outbound dispatch — failure simulation runs via
 *   `getValidationErrors()` instead. The circuit breaker exists in `REST_LoadProbe`
 *   only as a state probe (DELETE=reset, GET=getMetrics); no outbound path actually
 *   calls `.execute()` against it. Result: failureCount stays 0 across the burst,
 *   the breaker never opens, and `breakerOpenAfterNCalls` is structurally `null`.
 *
 *   Adaptation (1) chosen — same as Task 2.5: test what IS testable. 100 parallel
 *   inbound dispatches land cleanly, abort distribution matches failRate, no inbound
 *   dropped, breaker reset+state-inspect plumbing works. The original breaker-race
 *   intent stays deferred until the A32 fix ships.
 *
 * BEHAVIOUR ASSERTIONS (HARD GATE):
 *   B1 — All 100 inbound HTTP POSTs returned 200 (inbound dispatch always lands)
 *   B2 — Exactly 100 Inbound ApiCall__c rows scoped to ServiceName=API_LoadProbe AND
 *        CreatedDate >= run-start (no dropped requests under maximum parallelism)
 *   B3 — Exactly 100 Outbound ApiCall__c rows scoped to ServiceName=API_LoadProbeOutbound
 *        AND CreatedDate >= run-start
 *   B4 — Outbound abort rate within ±15pp of failRate=50 (n=100 has tighter binomial
 *        variance than n=50; ±2σ ≈ ±10pp, so ±15pp catches gross misbehavior without
 *        flapping on legitimate variance — slightly tighter than section-51's ±20pp
 *        because larger n gives narrower CI)
 *   B5 — All non-aborted outbound rows have Status__c = 'Completed' (no orphan/error
 *        statuses — confirms the success path stays clean under maximum parallel load)
 *   B6 — Breaker state is CLOSED after the burst (deployed shape — aborts don't trip,
 *        per A32; this is the actual framework contract for the v1.0 surface)
 *   B7 — All non-aborted outbound rows have Retries__c = 0 (no retry storm; aborts
 *        and successes both bypass the retry path in the deployed shape)
 *   B8 — Reset → CLOSED verification: DELETE → GET state returns CLOSED with
 *        failureCount = 0 (next batch starts from a clean state)
 *   B9 — Second small post-reset burst (5 inbound) lands cleanly to confirm the
 *        reset → CLOSED → next-batch-succeeds contract end-to-end
 *
 * SOFT-GATE METRICS (PERF_ROW: lines, harvested by Phase 2.5):
 *   wallMsTotal             — total wall clock for the 100-parallel burst
 *   p50ResponseMs           — median per-request latency
 *   p95ResponseMs           — 95th percentile per-request latency
 *   breakerOpenAfterNCalls  — null in the deployed shape (see SPEC vs ACTUAL above)
 *   parallelismFactor       — 100 (constant — for harvester reference)
 *
 * Run-isolation: cleanup deletes the burst's ApiCall__c rows by Id at the end
 * (avoids cross-run pollution while leaving prior smoke-test data intact for
 * forensic inspection). Cleanup also covers the post-reset 5-row mini-burst.
 *
 * Concurrency note: scratch orgs cap concurrent inbound REST at 50 per user
 * (org-wide variable — see Salesforce limits docs). 100 parallel HTTP requests
 * may queue / serialize under platform concurrency limits — wall-clock budget
 * is sized for that (~30-60s, generous given the queueing).
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - REST_LoadProbe + API_LoadProbe + API_LoadProbeOutbound deployed (Task 2.1)
 *   - Node 22+ (global fetch)
 *
 * Run:
 *   node release-testing/scripts/load-extended/parallel-callout-burst-100.js
 *
 * Expected wall-clock: 30-90s (100 parallel HTTP + ancillary calls + cleanup;
 * upper bound assumes platform concurrency queueing under sustained load).
 */

const {execSync} = require('child_process');
const {getSubscriberOrgAlias} = require('../../runner/subscriber-config');

const ORG_ALIAS = getSubscriberOrgAlias();
const ENDPOINT = '/services/apexrest/v1/load-probe';
const FAIL_RATE = 50;
const PARALLEL_COUNT = 100;
const POST_RESET_BURST = 5;
const CIRCUIT_ID = 'load-probe';
const ABORT_RATE_TOLERANCE_PP = 15;
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
	const csvPath = path.join('/tmp', `parallel-callout-burst-100-cleanup-${Date.now()}.csv`);
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
	console.log('PERF_ROW: ' + JSON.stringify({section: 'parallel-callout-burst-100', metric, value}));
}

async function main()
{
	console.log('');
	console.log('=== Extended Load (the extended-load spec §9.3): parallel-callout-burst-100 ===');

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
		recordPass('B1', `All ${PARALLEL_COUNT} HTTP POSTs returned 200`);
		pass++;
	}
	else
	{
		recordFail('B1', `Expected ${PARALLEL_COUNT} HTTP 200 responses, got ${ok200.length}`, failures);
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
		recordPass('B2', `Exactly ${PARALLEL_COUNT} Inbound ApiCall__c rows landed (no requests dropped under maximum parallelism)`);
		pass++;
	}
	else
	{
		recordFail('B2', `Expected ${PARALLEL_COUNT} Inbound rows, got ${inboundRows.length}`, failures);
		fail++;
	}

	if(outboundRows.length === PARALLEL_COUNT)
	{
		recordPass('B3', `Exactly ${PARALLEL_COUNT} Outbound ApiCall__c rows landed`);
		pass++;
	}
	else
	{
		recordFail('B3', `Expected ${PARALLEL_COUNT} Outbound rows, got ${outboundRows.length}`, failures);
		fail++;
	}

	const observedAbortPct = outboundRows.length > 0
		? (outboundAborted.length / outboundRows.length) * 100
		: 0;
	const abortDriftPp = Math.abs(observedAbortPct - FAIL_RATE);
	if(abortDriftPp <= ABORT_RATE_TOLERANCE_PP)
	{
		recordPass('B4', `Outbound abort rate ${observedAbortPct.toFixed(1)}% within ±${ABORT_RATE_TOLERANCE_PP}pp of failRate=${FAIL_RATE}% (drift=${abortDriftPp.toFixed(1)}pp)`);
		pass++;
	}
	else
	{
		recordFail('B4', `Outbound abort rate ${observedAbortPct.toFixed(1)}% drifted ${abortDriftPp.toFixed(1)}pp from failRate=${FAIL_RATE}% (tolerance ±${ABORT_RATE_TOLERANCE_PP}pp)`, failures);
		fail++;
	}

	if(outboundOther.length === 0)
	{
		recordPass('B5', `All non-aborted outbound rows have Status='Completed' (no orphan statuses)`);
		pass++;
	}
	else
	{
		const otherStatuses = [...new Set(outboundOther.map(r => r.kern__Status__c))].join(', ');
		recordFail('B5', `${outboundOther.length} outbound rows have unexpected Status (saw: ${otherStatuses})`, failures);
		fail++;
	}

	console.log('Phase 3: Circuit breaker state inspection');
	const stateAfterBurst = await getState(instanceUrl, accessToken, CIRCUIT_ID);
	console.log(`  state=${stateAfterBurst.state}, failureCount=${stateAfterBurst.failureCount}`);
	console.log('');

	if(stateAfterBurst.state === 'CLOSED')
	{
		recordPass('B6', `Breaker state CLOSED after burst (aborts do not trip breaker — A32 deployed-shape contract)`);
		pass++;
	}
	else
	{
		recordFail('B6', `Expected CLOSED state after burst, got ${stateAfterBurst.state} (failureCount=${stateAfterBurst.failureCount})`, failures);
		fail++;
	}

	const allRetriesZero = outboundRows.every(r => Number(r.kern__Retries__c) === 0);
	const maxRetries = outboundRows.reduce(
		(max, r) => Math.max(max, Number(r.kern__Retries__c) || 0),
		0
	);
	if(allRetriesZero)
	{
		recordPass('B7', `All ${outboundRows.length} outbound rows have Retries=0 (no retry storm — aborts and successes bypass retry path)`);
		pass++;
	}
	else
	{
		recordFail('B7', `Some outbound rows have Retries>0 (max observed: ${maxRetries})`, failures);
		fail++;
	}

	console.log('Phase 4: Reset → CLOSED verification');
	const resetBody = await resetCircuit(instanceUrl, accessToken, CIRCUIT_ID);
	const stateAfterReset = await getState(instanceUrl, accessToken, CIRCUIT_ID);
	console.log(`  reset=${resetBody.reset}, post-reset state=${stateAfterReset.state}, failureCount=${stateAfterReset.failureCount}`);
	console.log('');

	if(stateAfterReset.state === 'CLOSED' && stateAfterReset.failureCount === 0)
	{
		recordPass('B8', `Reset succeeded — state=CLOSED, failureCount=0`);
		pass++;
	}
	else
	{
		recordFail('B8', `Post-reset state=${stateAfterReset.state}, failureCount=${stateAfterReset.failureCount} (expected CLOSED + 0)`, failures);
		fail++;
	}

	console.log(`Phase 5: Post-reset mini-burst (${POST_RESET_BURST} inbound to confirm next-batch-succeeds)`);
	const postResetStartIso = new Date().toISOString();
	const postResetBody = {failRate: 0, circuitId: CIRCUIT_ID};
	const postResetPromises = Array.from(
		{length: POST_RESET_BURST},
		() => sendProbe(instanceUrl, accessToken, postResetBody)
	);
	const postResetResults = await Promise.allSettled(postResetPromises);
	const postResetFulfilled = postResetResults
		.filter(r => r.status === 'fulfilled')
		.map(r => r.value);
	const postResetOk200 = postResetFulfilled.filter(r => r.statusCode === 200);
	console.log(`  HTTP 200:   ${postResetOk200.length} / ${POST_RESET_BURST}`);
	console.log('');

	if(postResetOk200.length === POST_RESET_BURST)
	{
		recordPass('B9', `Post-reset mini-burst all ${POST_RESET_BURST} returned 200 (reset → CLOSED → next batch succeeds end-to-end)`);
		pass++;
	}
	else
	{
		recordFail('B9', `Post-reset mini-burst expected ${POST_RESET_BURST} HTTP 200, got ${postResetOk200.length}`, failures);
		fail++;
	}

	console.log('PERF metrics:');
	emitPerfRow('wallMsTotal', wallMsTotal);
	emitPerfRow('p50ResponseMs', p50);
	emitPerfRow('p95ResponseMs', p95);
	emitPerfRow('breakerOpenAfterNCalls', null);
	emitPerfRow('parallelismFactor', PARALLEL_COUNT);
	console.log('');

	console.log('Phase 6: Cleanup — delete burst rows by Id (main burst + post-reset mini-burst)');
	const cleanupRowsResult = querySoql(
		`SELECT Id FROM kern__ApiCall__c ` +
		`WHERE kern__ServiceName__c IN ('${INBOUND_SERVICE}', '${OUTBOUND_SERVICE}') ` +
		`AND CreatedDate >= ${runStartIso}`
	);
	const idsToDelete = (cleanupRowsResult.records || []).map(r => r.Id);
	try
	{
		deleteByIds(idsToDelete);
		console.log(`  Deleted ${idsToDelete.length} kern__ApiCall__c rows (main burst + post-reset)`);
	}
	catch(error)
	{
		console.log(`  Cleanup WARN: ${error.message}`);
	}
	console.log('');

	console.log(`Results: ${pass} passed, ${fail} failed out of 9`);
	if(fail === 0)
	{
		console.log('=== parallel-callout-burst-100 COMPLETE: All 100-parallel-burst assertions passed ===');
	}
	else
	{
		console.log('=== parallel-callout-burst-100 FAILED ===');
		failures.forEach(f => console.log(`  - ${f}`));
		process.exit(1);
	}
}

main().catch(error =>
{
	console.error(`parallel-callout-burst-100 ERROR: ${error.message}`);
	console.error(error.stack);
	process.exit(1);
});
