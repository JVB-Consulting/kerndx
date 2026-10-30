// SPDX-License-Identifier: Apache-2.0
const fs = require('fs');
const os = require('os');
const path = require('path');
const {
	createManifest, readManifest, writeManifest, recordStage, isStageDone, assertSameRun, describeForeignManifest, describeManifest, newRunToken, letterOrdinal, mintVolumeId, KINDS,
	VOLUME_ID_SHAPE
} = require('../scripts/consoles-at-volume/manifest');

// The console's own rule for a tracking id it resolves (CTRL_LogConsole TRACKING_ID_SHAPE).
const TRACKING_ID_SHAPE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const ORG = {alias: 'X', namespacePrefix: ''};
const STARTED_AT = '2026-09-24T12:00:00.000Z';

describe('run tokens and ids', () =>
{
	it('run tokens and letter ordinals are letters only', () =>
	{
		expect(newRunToken(() => 0.999)).toBe('ffffffff');
		expect(newRunToken(() => 0)).toBe('aaaaaaaa');
		expect(letterOrdinal(0, 4)).toBe('aaaa');
		expect(letterOrdinal(6, 4)).toBe('aaba');
		expect(letterOrdinal(2028, 12)).toMatch(/^[a-f]{12}$/);
	});

	it('mints ids the console resolves and the masking target never rewrites', () =>
	{
		const id = mintVolumeId(KINDS.reconciliationRun, 'abcdefab', 12, 3, 124);
		expect(id).toMatch(VOLUME_ID_SHAPE);
		expect(id).toMatch(TRACKING_ID_SHAPE);
		expect(id).toHaveLength(36);
		expect(id.startsWith('abcdefab-bbbb-')).toBe(true);
		expect(mintVolumeId(KINDS.action, 'abcdefab', 0, 0, 0)).not.toBe(mintVolumeId(KINDS.action, 'abcdefab', 1, 0, 0));
	});
});

describe('the manifest', () =>
{
	let directory;
	beforeEach(() => { directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-')); });
	afterEach(() => { fs.rmSync(directory, {recursive: true, force: true}); });

	it('round-trips through disk and records stages in order', () =>
	{
		const manifest = createManifest({mode: 'staged', size: 1, runToken: 'abcdefab', org: ORG, startedAt: STARTED_AT, shape: {}});
		recordStage(manifest, 'preflight', {ok: true});
		const filePath = path.join(directory, 'manifest.json');
		writeManifest(filePath, manifest);
		const read = readManifest(filePath);
		expect(isStageDone(read, 'preflight')).toBe(true);
		expect(isStageDone(read, 'launch')).toBe(false);
		expect(read.stages.preflight.finishedAt).toBeDefined();
	});

	it('run refuses a manifest whose token differs', () =>
	{
		const manifest = createManifest({mode: 'staged', size: 1, runToken: 'abcdefab', org: ORG, startedAt: STARTED_AT, shape: {}});
		expect(() => assertSameRun(manifest, {mode: 'full', size: 1, alias: 'X'})).toThrow(/mode/);
		expect(() => assertSameRun(manifest, {mode: 'staged', size: 0.5, alias: 'X'})).toThrow(/size/);
		expect(() => assertSameRun(manifest, {mode: 'staged', size: 1, alias: 'Other'})).toThrow(/org/);
		expect(() => assertSameRun(manifest, {mode: 'staged', size: 1, alias: 'X'})).not.toThrow();
	});

	it('refuses a manifest from another org by naming both orgs and asking for it to be archived, never deleted', () =>
	{
		const manifest = createManifest({mode: 'staged', size: 1, runToken: 'abcdefab', org: {alias: 'KernSubscriber19', namespacePrefix: '', userId: '005A'}, startedAt: STARTED_AT, shape: {}});
		const message = describeForeignManifest(manifest, {alias: 'KernSubscriber20', manifestPath: 'tmp/m.json'});
		expect(message).toContain('The manifest at tmp/m.json belongs to org KernSubscriber19, but this command targets org KernSubscriber20');
		expect(message).toContain('Archive the manifest');
		expect(message).toContain('manifest-abcdefab-KernSubscriber19.json');
		expect(message).toContain('It is not deleted for you');
		expect(() => assertSameRun(manifest, {mode: 'staged', size: 1, alias: 'KernSubscriber20'})).toThrow(/belongs to org KernSubscriber19.*targets org KernSubscriber20/);
	});

	it('refuses a manifest whose alias now opens another org, or whose org cannot be reached', () =>
	{
		const manifest = createManifest({mode: 'staged', size: 1, runToken: 'abcdefab', org: {alias: 'Sub', namespacePrefix: '', userId: '005A'}, startedAt: STARTED_AT, shape: {}});
		expect(describeForeignManifest(manifest, {alias: 'Sub', userId: '005B'})).toContain('no longer exists');
		expect(describeForeignManifest(manifest, {alias: 'Sub', unreachable: 'No authorization found'})).toContain('could not be reached (No authorization found)');
		expect(describeForeignManifest(manifest, {alias: 'Sub', userId: '005A'})).toBeNull();
		expect(describeForeignManifest(null, {alias: 'Sub'})).toBeNull();
	});

	it('reads a missing manifest as null', () =>
	{
		expect(readManifest(path.join(directory, 'none.json'))).toBeNull();
	});

	it('describes a run on one screen, stage by stage, and a missing manifest plainly', () =>
	{
		const manifest = createManifest({mode: 'staged', size: 1, runToken: 'abcdefab', org: {alias: 'Dev', namespacePrefix: ''}, startedAt: STARTED_AT, shape: {}});
		recordStage(manifest, 'preflight', {ok: true});
		recordStage(manifest, 'launch', {ok: false, reason: 'Bulk import rejected rows: job 750x failed 2'});
		const text = describeManifest(manifest, 'm.json');
		expect(text).toContain('staged run, size 1, token abcdefab, org Dev [no namespace]');
		expect(text).toContain('preflight: ok at');
		expect(text).toContain('launch: FAILED at');
		expect(text).toContain('job 750x failed 2');
		expect(text).toContain('drain: not run');
		expect(describeManifest(null, 'm.json')).toBe('No manifest at m.json; nothing has run here.');
	});

	it('keeps the started-step Stalled rows apart from the screen-fixture rows, and names both on the status screen', () =>
	{
		const manifest = createManifest({mode: 'full', size: 1, runToken: 'abcdefab', org: {alias: 'Dev', namespacePrefix: ''}, startedAt: STARTED_AT, shape: {}});
		expect(manifest.synthesized).toMatchObject({stalledRows: [], startedStepRows: []});
		manifest.synthesized.stalledRows = ['x', 'y'];
		manifest.synthesized.startedStepRows = ['p', 'q', 'r'];
		expect(describeManifest(manifest, 'm.json')).toContain('2 screen-fixture Stalled rows and 3 started-step Stalled rows');
	});
});
