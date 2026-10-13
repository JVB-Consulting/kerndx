// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const os = require('os');
const path = require('path');
const {percentile, judgeTimings, timingFindings, attachTiming, reportTimingBreaches, writeTimings, SAMPLE_PROTOCOL} = require('../e2e/explore/timing');

describe('percentile', () =>
{
	it('takes the nearest rank', () =>
	{
		expect(percentile([100, 200, 300, 400], 75)).toBe(300);
		expect(percentile([5], 75)).toBe(5);
		expect(percentile([], 75)).toBeNull();
	});
});

describe('judgeTimings', () =>
{
	const read = (durationMs) => ({kind: 'read', method: 'getLogEntries', durationMs});
	const open = (durationMs, cold = false) => ({kind: 'open', name: 'monitor', durationMs, cold});

	it('judges each kind and name at the 75th percentile against its budget, cold opens apart', () =>
	{
		const samples = [read(400), read(1200), read(900), read(1400), read(700), open(2500, true), open(3600), open(2900), open(3100), open(3300), open(2800)];
		const judgements = judgeTimings(samples, {pageOpenMilliseconds: 3000, inPageReadMilliseconds: 1000});
		expect(judgements).toEqual(expect.arrayContaining([
			{kind: 'read', name: 'getLogEntries', samples: 5, p75: 1200, budget: 1000, breach: true, informational: false},
			{kind: 'open', name: 'monitor (cold)', samples: 1, p75: 2500, budget: 3000, breach: false, informational: true},
			{kind: 'open', name: 'monitor', samples: 5, p75: 3300, budget: 3000, breach: true, informational: false}
		]));
		const findings = timingFindings(judgements, {});
		expect(findings).toHaveLength(2);
		expect(findings[0]).toMatchObject({check: 'timing-breach', step: 1, observed: 'P75 1200 ms over 5 reads', expected: 'P75 at most 1000 ms', informational: false});
		expect(findings[1].step).toBe(2);
	});

	it('judges a kind with fewer than five samples as informational, breach or not', () =>
	{
		const judgements = judgeTimings([read(1500), read(1600)], {pageOpenMilliseconds: 3000, inPageReadMilliseconds: 1000});
		expect(judgements[0]).toMatchObject({samples: 2, breach: true, informational: true});
		expect(timingFindings(judgements, {})[0].informational).toBe(true);
	});
});

describe('attachTiming', () =>
{
	it('records one sample per counted method in a finished Aura request, and the first open of a console as cold', () =>
	{
		const handlers = {};
		const page = {on: (event, handler) => { handlers[event] = handler; }};
		const timing = attachTiming(page, ['getLogEntries', 'getActionSummary']);
		handlers.requestfinished({
			method: () => 'POST', url: () => 'https://x/aura?r=1', postData: () => '"method":"getLogEntries"..."method":"getActionSummary"',
			timing: () => ({startTime: 10, responseEnd: 250})
		});
		handlers.requestfinished({method: () => 'GET', url: () => 'https://x/other', postData: () => '', timing: () => ({startTime: 0, responseEnd: 5})});
		expect(timing.samples).toHaveLength(2);
		expect(timing.samples.map((sample) => sample.method)).toEqual(['getLogEntries', 'getActionSummary']);
		expect(timing.samples[0].durationMs).toBe(250);
		timing.openTimer().stop('console');
		timing.openTimer().stop('console');
		expect(timing.samples[2]).toMatchObject({kind: 'open', name: 'console', cold: true});
		expect(timing.samples[3]).toMatchObject({kind: 'open', name: 'console', cold: false});
	});

	it('takes a read the walk timed itself, judged with the read budget', () =>
	{
		const timing = attachTiming({on: () => {}}, []);
		timing.markRead('drawer-open', 420);
		expect(timing.samples[0]).toMatchObject({kind: 'read', method: 'drawer-open', durationMs: 420});
		expect(judgeTimings(timing.samples, {pageOpenMilliseconds: 3000, inPageReadMilliseconds: 1000})[0]).toMatchObject({kind: 'read', name: 'drawer-open', budget: 1000});
	});

	it('keeps no sample for a request whose timing the browser did not report', () =>
	{
		const handlers = {};
		const timing = attachTiming({on: (event, handler) => { handlers[event] = handler; }}, ['getLogEntries']);
		handlers.requestfinished({method: () => 'POST', url: () => 'https://x/aura', postData: () => '"method":"getLogEntries"', timing: () => ({startTime: 1, responseEnd: -1})});
		expect(timing.samples).toEqual([]);
	});
});

describe('reportTimingBreaches and writeTimings', () =>
{
	it('reports one ledger finding per breach and writes the protocol beside every judgement', async() =>
	{
		const reported = [];
		const context = {ledger: {report: async(ignored, finding) => { reported.push(finding); }}, timing: {samples: [
			{kind: 'read', method: 'getLogEntries', durationMs: 1500}, {kind: 'open', name: 'console', durationMs: 900, cold: true}
		]}};
		const judgements = await reportTimingBreaches(context, {pageOpenMilliseconds: 3000, inPageReadMilliseconds: 1000});
		expect(judgements).toHaveLength(2);
		expect(reported).toHaveLength(1);
		expect(reported[0]).toMatchObject({check: 'timing-breach', move: 'read getLogEntries', informational: true, pins: {kind: 'console'}});
		const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'timings-'));
		const filePath = path.join(directory, 'timings.json');
		writeTimings(filePath, judgements);
		const written = JSON.parse(fs.readFileSync(filePath, 'utf8'));
		expect(written.protocol).toEqual(SAMPLE_PROTOCOL);
		expect(written.protocol).toMatchObject({loginTimed: false, coldOpensApart: true, minimumSamples: 5});
		expect(written.judgements).toEqual(judgements);
		fs.rmSync(directory, {recursive: true, force: true});
	});
});
