// SPDX-License-Identifier: BUSL-1.1
// Every server read timed in the browser from request to response, every console open timed to a rendered list,
// each kind judged at the 75th percentile against the performance budgets (spec D2: 3 s to a settled list, 1 s per
// read), under the sample protocol below: one context, no login timed, cold opens apart, five samples or more.
'use strict';

const fs = require('fs');
const {consoleEntry} = require('./model');

const AURA_PATH = '/aura';
const DEFAULT_SHARE = 75;
const DEFAULT_MINIMUM_SAMPLES = 5;
const COLD_SUFFIX = ' (cold)';
const PERCENT = 100;
const JSON_INDENT = 2;

// What a P75 here means, written into timings.json beside the judgements so a reader of the numbers has the
// method they were taken by.
const SAMPLE_PROTOCOL = {
	context: 'one per walk',
	loginTimed: false,
	readMeasure: 'aura request start to response end',
	openMeasure: 'navigation to rendered list',
	coldOpensApart: true,
	minimumSamples: DEFAULT_MINIMUM_SAMPLES,
	share: DEFAULT_SHARE
};

/**
 * @description The value at the given percentile by the nearest-rank method, the way Core Web Vitals are read.
 * @param {Array<number>} values The measurements.
 * @param {number} share The percentile, 0 to 100.
 * @returns {number|null} The value at that rank, or null when there is no measurement.
 */
function percentile(values, share)
{
	if(values.length === 0)
	{
		return null;
	}
	const sorted = [...values].sort((left, right) => left - right);
	const rank = Math.max(1, Math.ceil((share / PERCENT) * sorted.length));
	return sorted[rank - 1];
}

/**
 * @description Watches the page's Aura requests and keeps a sample per counted controller method a finished
 *              request carried, from the request's start to its response end. Page opens are marked by the
 *              caller through the timer, the first open of each name as a cold one.
 * @param {Object} page The Playwright page.
 * @param {Array<string>} methods The controller method names to sample.
 * @returns {Object} The timing: `samples`, `markRead(name, durationMs)`, `markPageOpen(name, durationMs)`, `openTimer()` → `{stop(name)}`.
 */
function attachTiming(page, methods)
{
	const timing = {samples: []};
	page.on('requestfinished', (request) =>
	{
		if(request.method() !== 'POST' || !request.url().includes(AURA_PATH))
		{
			return;
		}
		let body = request.postData() || '';
		try
		{
			body = decodeURIComponent(body);
		}
		catch
		{
			// Counted as it arrived.
		}
		const responseEnd = request.timing().responseEnd;
		if(responseEnd < 0)
		{
			// The browser reports -1 when it has no timing for the request: no sample is better than a wrong one.
			return;
		}
		const durationMs = Math.round(responseEnd);
		for(const method of methods)
		{
			const occurrences = body.split(`"method":"${method}"`).length - 1;
			for(let count = 0; count < occurrences; count++)
			{
				timing.samples.push({kind: 'read', method, durationMs, at: Date.now()});
			}
		}
	});
	// A read the walk timed itself (a drawer opening), judged with the read budget like a server read.
	timing.markRead = (name, durationMs) =>
	{
		timing.samples.push({kind: 'read', method: name, durationMs, at: Date.now()});
	};
	const opened = new Set();
	timing.markPageOpen = (name, durationMs) =>
	{
		const cold = !opened.has(name);
		opened.add(name);
		timing.samples.push({kind: 'open', name, durationMs, at: Date.now(), cold});
	};
	timing.openTimer = () =>
	{
		const startedAt = Date.now();
		return {stop: (name) => timing.markPageOpen(name, Date.now() - startedAt)};
	};
	return timing;
}

/**
 * @description Groups the samples by kind and name (cold opens apart) and judges each group at the percentile
 *              against its budget. A group with fewer samples than the minimum, or of cold opens, is informational.
 * @param {Array<Object>} samples The samples the timing collected.
 * @param {Object} budgets The two budgets: `pageOpenMilliseconds` and `inPageReadMilliseconds`.
 * @param {Object} options The percentile share and the minimum sample count.
 * @returns {Array<Object>} One judgement per group: kind, name, samples, p75, budget, breach, informational.
 */
function judgeTimings(samples, budgets, {share = DEFAULT_SHARE, minimumSamples = DEFAULT_MINIMUM_SAMPLES} = {})
{
	const groups = new Map();
	for(const sample of samples)
	{
		const openName = sample.cold ? `${sample.name}${COLD_SUFFIX}` : sample.name;
		const name = sample.kind === 'read' ? sample.method : openName;
		const key = `${sample.kind}:${name}`;
		if(!groups.has(key))
		{
			groups.set(key, {kind: sample.kind, name, cold: Boolean(sample.cold), values: []});
		}
		groups.get(key).values.push(sample.durationMs);
	}
	return [...groups.values()].map((group) =>
	{
		const budget = group.kind === 'read' ? budgets.inPageReadMilliseconds : budgets.pageOpenMilliseconds;
		const value = percentile(group.values, share);
		return {
			kind: group.kind, name: group.name, samples: group.values.length, p75: value, budget, breach: value > budget,
			informational: group.cold || group.values.length < minimumSamples
		};
	});
}

/**
 * @description One finding in the ledger's shape per breached judgement, carrying the measured number.
 * @param {Array<Object>} judgements The judgements.
 * @param {Object} pins The pins to record the findings under.
 * @returns {Array<Object>} The findings.
 */
function timingFindings(judgements, pins)
{
	// One step number per breach, so each finding's screenshot has a name of its own.
	return judgements.filter((judgement) => judgement.breach).map((judgement, index) => ({
		session: 'TIMING', step: index + 1, move: judgement.kind === 'read' ? `read ${judgement.name}` : `open ${judgement.name}`, check: 'timing-breach',
		expected: `P75 at most ${judgement.budget} ms`, observed: `P75 ${judgement.p75} ms over ${judgement.samples} ${judgement.kind === 'read' ? 'reads' : 'opens'}`,
		pins, informational: judgement.informational
	}));
}

/**
 * @description Judges the run's samples and reports every breach to the ledger.
 * @param {Object} context The run context, carrying `timing` and `ledger`.
 * @param {Object} budgets The two budgets.
 * @returns {Promise<Array<Object>>} The judgements, for the timings file.
 */
async function reportTimingBreaches(context, budgets)
{
	const judgements = judgeTimings(context.timing.samples, budgets);
	for(const finding of timingFindings(judgements, consoleEntry()))
	{
		await context.ledger.report(context, finding);
	}
	return judgements;
}

/**
 * @description Writes the judgements with the protocol they were taken under.
 * @param {string} filePath Where to write.
 * @param {Array<Object>} judgements The judgements.
 */
function writeTimings(filePath, judgements)
{
	fs.writeFileSync(filePath, JSON.stringify({protocol: SAMPLE_PROTOCOL, judgements}, null, JSON_INDENT), 'utf8');
}

module.exports = {SAMPLE_PROTOCOL, percentile, attachTiming, judgeTimings, timingFindings, reportTimingBreaches, writeTimings};
