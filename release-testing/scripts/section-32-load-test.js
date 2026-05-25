// SPDX-License-Identifier: BUSL-1.1
/**
 * Section 32: Circuit Breaker Load Test
 *
 * Fires parallel HTTP requests at REST_ResilienceProbe to verify circuit breaker
 * behavior under concurrent load. Uses a two-phase approach:
 *   Phase 1 — Sequential trip: 5 failure requests one at a time (deterministic)
 *   Phase 2 — Concurrent verification: 25 parallel requests (should be blocked)
 *
 * Prerequisites:
 *   - subscriber scratch org with package installed
 *   - REST_ResilienceProbe deployed (release-testing/subscriber/classes/)
 *   - Node 22+ (global fetch)
 *
 * Run:
 *   node release-testing/scripts/section-32-load-test.js
 */

const {execSync} = require('child_process');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');

const ORG_ALIAS = getSubscriberOrgAlias();
const ENDPOINT = '/services/apexrest/v1/resilience-probe';
const FAILURE_THRESHOLD = 5;
const TIMEOUT_SECONDS = 30;
const PARALLEL_COUNT = 25;

function getOrgInfo()
{
	const raw = execSync(`sf org display -o ${ORG_ALIAS} --json`, {encoding: 'utf8'});
	const result = JSON.parse(raw).result;
	return {instanceUrl: result.instanceUrl, accessToken: result.accessToken};
}

async function sendProbe(instanceUrl, accessToken, body)
{
	const response = await fetch(`${instanceUrl}${ENDPOINT}`, {
		method: 'POST', headers: {
			'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json'
		}, body: JSON.stringify(body)
	});

	let data;
	try
	{
		data = await response.json();
	}
	catch
	{
		data = {parseError: true};
	}

	return {statusCode: response.status, ...data};
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
	await fetch(url, {
		method: 'DELETE', headers: {'Authorization': `Bearer ${accessToken}`}
	});
}

async function main()
{
	console.log('Section 32: Circuit Breaker Load Test');
	console.log('=====================================\n');

	const {instanceUrl, accessToken} = getOrgInfo();
	const circuitId = `load-test-${Date.now()}`;
	const probeBody = {circuitId, threshold: FAILURE_THRESHOLD, timeout: TIMEOUT_SECONDS, fail: true};

	console.log(`Target: ${instanceUrl}`);
	console.log(`Circuit ID: ${circuitId}`);
	console.log(`Failure threshold: ${FAILURE_THRESHOLD}`);
	console.log(`Parallel burst size: ${PARALLEL_COUNT}\n`);

	await resetCircuit(instanceUrl, accessToken, circuitId);

	let pass = 0;
	let fail = 0;

	// Phase 1: Sequential failures to trip the circuit breaker
	console.log(`Phase 1: Sequential trip (${FAILURE_THRESHOLD} failures)`);
	const sequentialResults = [];
	for(let i = 0; i < FAILURE_THRESHOLD; i++)
	{
		const result = await sendProbe(instanceUrl, accessToken, probeBody);
		sequentialResults.push(result);
		console.log(`  Request ${i + 1}: ${result.statusCode} (state=${result.state}, failures=${result.failureCount})`);
	}
	console.log('');

	// 32a: All sequential requests were allowed through
	const allAllowed = sequentialResults.every(r => r.allowed === true);
	if(allAllowed)
	{
		console.log('32a PASS: All sequential requests were allowed (circuit not yet OPEN during trip)');
		pass++;
	}
	else
	{
		const blockedCount = sequentialResults.filter(r => r.allowed !== true).length;
		console.log(`32a FAIL: ${blockedCount} sequential requests were unexpectedly blocked`);
		fail++;
	}

	// 32b: After sequential trip, verify state is OPEN
	const stateAfterTrip = await getState(instanceUrl, accessToken, circuitId);
	if(stateAfterTrip.state === 'OPEN')
	{
		console.log('32b PASS: Circuit breaker state is OPEN after sequential trip');
		pass++;
	}
	else
	{
		console.log(`32b FAIL: Expected state OPEN after trip, got ${stateAfterTrip.state}`);
		fail++;
	}

	// Phase 2: Concurrent burst — should be blocked by OPEN circuit
	console.log(`\nPhase 2: Concurrent verification (${PARALLEL_COUNT} parallel requests)`);
	const promises = Array.from({length: PARALLEL_COUNT}, () => sendProbe(instanceUrl, accessToken, probeBody));
	const parallelResults = await Promise.allSettled(promises);
	const settled = parallelResults
	.filter(r => r.status === 'fulfilled')
	.map(r => r.value);
	const rejected = parallelResults.filter(r => r.status === 'rejected');

	const blocked = settled.filter(r => r.blocked === true);
	const allowed = settled.filter(r => r.allowed === true);

	console.log(`  Fulfilled: ${settled.length} / ${PARALLEL_COUNT}`);
	console.log(`  Blocked:   ${blocked.length}`);
	console.log(`  Allowed:   ${allowed.length}`);
	if(rejected.length > 0)
	{
		console.log(`  Rejected:  ${rejected.length} (network/rate limit)`);
	}
	console.log('');

	// 32c: At least 80% of parallel requests were blocked
	const blockThreshold = Math.floor(PARALLEL_COUNT * 0.8);
	if(blocked.length >= blockThreshold)
	{
		console.log(`32c PASS: ${blocked.length} of ${PARALLEL_COUNT} concurrent requests blocked (>= ${blockThreshold} required)`);
		pass++;
	}
	else
	{
		console.log(`32c FAIL: Only ${blocked.length} blocked, expected >= ${blockThreshold}`);
		fail++;
	}

	// 32d: All blocked responses returned 503
	const blocked503 = blocked.filter(r => r.statusCode === 503);
	if(blocked.length > 0 && blocked503.length === blocked.length)
	{
		console.log('32d PASS: All blocked responses returned HTTP 503');
		pass++;
	}
	else if(blocked.length === 0)
	{
		console.log('32d FAIL: No blocked responses to verify');
		fail++;
	}
	else
	{
		console.log(`32d FAIL: ${blocked503.length} of ${blocked.length} blocked responses had 503`);
		fail++;
	}

	// Phase 3: Recovery — reset and verify CLOSED
	await resetCircuit(instanceUrl, accessToken, circuitId);
	const stateAfterReset = await getState(instanceUrl, accessToken, circuitId);

	if(stateAfterReset.state === 'CLOSED')
	{
		console.log('32e PASS: Circuit breaker accepts requests after reset (state CLOSED)');
		pass++;
	}
	else
	{
		console.log(`32e FAIL: Expected CLOSED after reset, got ${stateAfterReset.state}`);
		fail++;
	}

	// Summary
	console.log(`\nResults: ${pass} passed, ${fail} failed out of 5`);
	if(fail === 0)
	{
		console.log('=== Section 32 COMPLETE: All load test assertions passed ===');
	}
	else
	{
		process.exit(1);
	}
}

main().catch(error =>
{
	console.error(`Section 32 ERROR: ${error.message}`);
	process.exit(1);
});
