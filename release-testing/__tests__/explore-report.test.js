// SPDX-License-Identifier: BUSL-1.1
jest.mock('../e2e/helpers/sf-cli', () => ({runApexScript: jest.fn(), soqlQuery: jest.fn()}));
jest.mock('../e2e/helpers/sf-namespace', () => ({namespacePrefix: () => '', apexNamespacePrefix: () => '', fillNamespaceTokens: (source) => source}));
const fs = require('fs');
const os = require('os');
const path = require('path');
const {createFindingsLedger, sanitise, outputPaths} = require('../e2e/explore/report');

describe('outputPaths', () =>
{
	it('places the findings table, the timings and the screenshots under one folder', () =>
	{
		expect(outputPaths('/out/run')).toEqual({
			directory: '/out/run', screenshotDirectory: path.join('/out/run', 'screenshots'), findingsPath: path.join('/out/run', 'exploration-findings.md'),
			timingsPath: path.join('/out/run', 'timings.json')
		});
	});
});

describe('the findings ledger', () =>
{
	it('numbers findings, counts repeats of the same check and move, and writes the table', async() =>
	{
		const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'ledger-'));
		const ledger = createFindingsLedger({seed: 7, screenshotDirectory: directory, findingsPath: path.join(directory, 'findings.md'), maximumScreenshots: 1});
		const context = {page: {screenshot: jest.fn(async() => {})}};
		await ledger.report(context, {session: 'S1', step: 1, move: 'clear', check: 'rows', expected: '3', observed: '2', pins: {}});
		await ledger.report(context, {session: 'S1', step: 2, move: 'clear', check: 'rows', expected: '3', observed: '2', pins: {}});
		await ledger.report(context, {session: 'S1', step: 3, move: 'back', check: 'address', expected: 'x', observed: 'y', pins: {}, informational: true});
		expect(ledger.findings).toHaveLength(2);
		expect(ledger.findings[0]).toMatchObject({index: 1, seed: 7, repeats: 1, informational: false});
		expect(ledger.findings[1]).toMatchObject({index: 2, seed: 7, repeats: 0, informational: true});
		expect(ledger.reportableCount()).toBe(1);
		expect(context.page.screenshot).toHaveBeenCalledTimes(1);
		ledger.write('summary line');
		const written = fs.readFileSync(path.join(directory, 'findings.md'), 'utf8');
		expect(written).toContain('summary line');
		expect(written).toContain('| # | Seed | Session | Step | Move | Check |');
		expect(written).toContain('Findings: 1 (plus 1 recorded as observations only).');
		expect(sanitise('a|b\nc')).toBe('a/b c');
		fs.rmSync(directory, {recursive: true, force: true});
	});

	it('reports without a page, the way the seed check and the teardown do', async() =>
	{
		const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'ledger-'));
		const ledger = createFindingsLedger({seed: 1, screenshotDirectory: directory, findingsPath: path.join(directory, 'findings.md'), maximumScreenshots: 1});
		await ledger.report({page: null}, {session: 'TEARDOWN', step: 2, move: 'the teardown', check: 'seed-left-behind', expected: 'none', observed: '3 rows survived'});
		expect(ledger.findings[0]).toMatchObject({address: 'no page open', screenshot: ''});
		fs.rmSync(directory, {recursive: true, force: true});
	});
});
