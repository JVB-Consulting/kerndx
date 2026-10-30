// SPDX-License-Identifier: Apache-2.0
const fs = require('fs');
const os = require('os');
const path = require('path');
const {runsPerRoot, leafOutcome, expectedReconciliation, planSmallActions, planBatches, scaleShape, readProbeReport, OPERATOR_WAVE} = require(
		'../scripts/consoles-at-volume/shapes');

// A measured report, as Task 1 writes it; the tests never read the committed one.
const REPORT = {
	measuredAt: '2026-09-25T09:00:00.000Z', org: 'Dev', verdict: 'FITS', jobsPerMinute: 120, peakActive: 60, peakHolding: 40, rootWallClockMinutes: 7,
	stallStrategy: 'synthesized', fitsInOneTransaction: true
};

describe('the reconciliation shape', () =>
{
	it('has 156 runs per root three deep at a fan-out of five', () =>
	{
		expect(runsPerRoot(5, 3)).toBe(156);
		expect(runsPerRoot(5, 0)).toBe(1);
	});

	it('fails every eighth leaf, cycling the three kinds, as the Apex rule does', () =>
	{
		expect(leafOutcome(1)).toBe('succeed');
		expect(leafOutcome(0)).toBe('fail');
		expect(leafOutcome(8)).toBe('failPermanently');
		expect(leafOutcome(16)).toBe('failAfterRetries');
		expect(leafOutcome(24)).toBe('fail');
	});

	it('expects 2,028 runs, 1,820 completed and 208 failed for thirteen roots', () =>
	{
		const expected = expectedReconciliation(13, 5, 3);
		expect(expected).toEqual({runs: 2028, leaves: 1625, byStatus: {Completed: 1820, Failed: 208}, byCategory: {StepException: 143, RetriesExhausted: 65}});
	});
});

describe('the small actions', () =>
{
	it('cycles five kinds and sizes each as its launches say', () =>
	{
		const actions = planSmallActions(5);
		expect(actions.map((action) => action.kind)).toEqual(['orders', 'imports', 'nightly', 'nested', 'handlers']);
		expect(actions.map((action) => action.expected.runs)).toEqual([5, 5, 5, 11, 7]);
		// The nested import's first leaf has ordinal 0, which the fan-out rule fails: six of its seven runs complete.
		expect(actions[3].expected.byStatus).toEqual({Completed: 8, Failed: 3});
		expect(actions.reduce((sum, action) => sum + action.expected.byStatus.Failed, 0)).toBe(12);
		expect(actions.reduce((sum, action) => sum + action.retryCandidates, 0)).toBe(3);
		expect(actions.reduce((sum, action) => sum + action.restartCandidates, 0)).toBe(3);
	});

	it('gives every other nightly action a deferred chain', () =>
	{
		const nightly = planSmallActions(20).filter((action) => action.kind === 'nightly');
		expect(nightly.map((action) => action.launches.some((launch) => launch.shape === 'DeferredNotification'))).toEqual([true, false, true, false]);
	});

	it('batches seven actions at a time', () =>
	{
		expect(planBatches(planSmallActions(16), 7).map((batch) => batch.length)).toEqual([7, 7, 2]);
	});
});

describe('scaleShape', () =>
{
	it('keeps the spec numbers at size one in full mode, with the batching the probe measured', () =>
	{
		const shape = scaleShape('full', 1, REPORT);
		expect(shape.reconciliation).toMatchObject({roots: 13, engineRoots: 13, fanOut: 5, targetDepth: 3, rootsPerBatch: 13, staggerRootsByMinutes: true});
		expect(shape.smallActions).toMatchObject({count: 200, engineCount: 200});
		expect(shape.wave).toEqual(OPERATOR_WAVE);
		expect(shape.expected.reconciliation.runs).toBe(2028);
		expect(shape.probe).toEqual({measuredAt: REPORT.measuredAt, jobsPerMinute: 120, peakHolding: 40});
		expect(scaleShape('full', 1, {...REPORT, fitsInOneTransaction: false}).reconciliation).toMatchObject({rootsPerBatch: 1, staggerRootsByMinutes: false});
	});

	it('puts one root and twelve actions through the engine in staged mode and fills the rest', () =>
	{
		const shape = scaleShape('staged', 1, REPORT);
		expect(shape.reconciliation).toMatchObject({roots: 13, engineRoots: 1});
		expect(shape.smallActions).toMatchObject({count: 200, engineCount: 12});
		expect(shape.wave).toEqual({retries: 3, restarts: 3, aborts: 2, killSwitchBatch: 5, deadJobStalls: 2, synthesizedStalled: 2});
	});

	it('scales by the size factor and never below one root', () =>
	{
		expect(scaleShape('full', 0.25, REPORT).reconciliation.roots).toBe(3);
		expect(scaleShape('full', 0.01, REPORT).reconciliation.roots).toBe(1);
		expect(scaleShape('full', 0.25, REPORT).smallActions.count).toBe(50);
	});
});

describe('readProbeReport', () =>
{
	it('refuses a missing report and an unmeasured one, naming what is missing', () =>
	{
		const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'probe-'));
		expect(() => readProbeReport(path.join(directory, 'none.json'))).toThrow(/consoles-at-volume-probe\.js/);
		const unmeasured = path.join(directory, 'zero.json');
		fs.writeFileSync(unmeasured, JSON.stringify({...REPORT, jobsPerMinute: 0}));
		expect(() => readProbeReport(unmeasured)).toThrow(/jobsPerMinute/);
		const measured = path.join(directory, 'ok.json');
		fs.writeFileSync(measured, JSON.stringify(REPORT));
		expect(readProbeReport(measured)).toEqual(REPORT);
		fs.rmSync(directory, {recursive: true, force: true});
	});
});
