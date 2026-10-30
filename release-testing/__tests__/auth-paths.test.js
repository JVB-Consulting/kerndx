// SPDX-License-Identifier: Apache-2.0
const fs = require('fs');
const path = require('path');

const AUTH_ROOT = path.join(__dirname, '..', 'e2e', '.auth');
const TEST_RESULTS_ROOT = path.join(__dirname, '..', 'test-results');

jest.mock('@playwright/test', () => ({defineConfig: configuration => configuration}));

function gapFinderOutputFolderFor(alias)
{
	process.env.SF_SUBSCRIBER_ORG_ALIAS = alias;
	jest.resetModules();
	return require('../e2e/gap-finder.config').outputDir;
}

function rawFolderFor(alias)
{
	process.env.SF_SUBSCRIBER_ORG_ALIAS = alias;
	jest.resetModules();
	return require('../scripts/process-stills').RAW_DIR;
}

let originalAlias;

beforeEach(() =>
{
	jest.resetModules();
	originalAlias = process.env.SF_SUBSCRIBER_ORG_ALIAS;
});

afterEach(() =>
{
	if(originalAlias === undefined)
	{
		delete process.env.SF_SUBSCRIBER_ORG_ALIAS;
	}
	else
	{
		process.env.SF_SUBSCRIBER_ORG_ALIAS = originalAlias;
	}
});

describe('authPathsFor', () =>
{
	it('keeps the three session files in a folder named after the org alias', () =>
	{
		const {authPathsFor} = require('../e2e/helpers/auth-paths');

		expect(authPathsFor('KernUpgradeSubscriber')).toEqual({
			directory: path.join(AUTH_ROOT, 'KernUpgradeSubscriber'),
			statePath: path.join(AUTH_ROOT, 'KernUpgradeSubscriber', 'state.json'),
			instancePath: path.join(AUTH_ROOT, 'KernUpgradeSubscriber', 'instance.json'),
			runTargetPath: path.join(AUTH_ROOT, 'KernUpgradeSubscriber', 'run-target.json')
		});
	});

	it('gives two orgs two folders, so a run against one never reads the other run\'s session', () =>
	{
		const {authPathsFor} = require('../e2e/helpers/auth-paths');
		const upgraded = authPathsFor('KernUpgradeSubscriber');
		const fresh = authPathsFor('FreshSubscriber');

		expect(upgraded.directory).not.toBe(fresh.directory);
		expect(upgraded.statePath).not.toBe(fresh.statePath);
		expect(upgraded.instancePath).not.toBe(fresh.instancePath);
		expect(upgraded.runTargetPath).not.toBe(fresh.runTargetPath);
	});

	it('uses the run\'s own alias when none is given', () =>
	{
		process.env.SF_SUBSCRIBER_ORG_ALIAS = 'KernUpgradeSubscriber';
		const {authPathsFor} = require('../e2e/helpers/auth-paths');

		expect(authPathsFor().statePath).toBe(path.join(AUTH_ROOT, 'KernUpgradeSubscriber', 'state.json'));
	});

	it('keeps a username alias as it is, since its characters are safe in a folder name', () =>
	{
		const {authFolderName} = require('../e2e/helpers/auth-paths');

		expect(authFolderName('test-abc@example.com')).toBe('test-abc@example.com');
	});

	it('replaces path separators and spaces, so an alias can never name a folder outside the session root', () =>
	{
		const {authPathsFor} = require('../e2e/helpers/auth-paths');
		const {directory} = authPathsFor('../outside/my org');

		expect(path.dirname(directory)).toBe(AUTH_ROOT);
		expect(path.basename(directory)).toBe('.._outside_my_org');
	});

	it.each(['', '   ', '.', '..', null, undefined])('refuses the alias %p, which cannot name a folder of its own', (alias) =>
	{
		const {authFolderName} = require('../e2e/helpers/auth-paths');

		expect(() => authFolderName(alias)).toThrow('cannot name a folder for the session files');
	});
});

describe('testResultsDirectoryFor', () =>
{
	it('gives two orgs two folders under release-testing/test-results, so one run never overwrites the other run\'s screenshots', () =>
	{
		const {testResultsDirectoryFor} = require('../e2e/helpers/auth-paths');

		expect(testResultsDirectoryFor('OrgA')).toBe(path.join(TEST_RESULTS_ROOT, 'OrgA'));
		expect(testResultsDirectoryFor('OrgB')).toBe(path.join(TEST_RESULTS_ROOT, 'OrgB'));
	});

	it('uses the run\'s own alias when none is given, and makes an unsafe alias safe the same way as the session folder', () =>
	{
		process.env.SF_SUBSCRIBER_ORG_ALIAS = 'KernUpgradeSubscriber';
		const {testResultsDirectoryFor} = require('../e2e/helpers/auth-paths');

		expect(testResultsDirectoryFor()).toBe(path.join(TEST_RESULTS_ROOT, 'KernUpgradeSubscriber'));
		expect(testResultsDirectoryFor('../outside/my org')).toBe(path.join(TEST_RESULTS_ROOT, '.._outside_my_org'));
	});

	it('keeps the gap-finder results in a gap-finder folder inside the org folder of the run', () =>
	{
		const first = gapFinderOutputFolderFor('FirstOrg');
		const second = gapFinderOutputFolderFor('SecondOrg');

		expect(first).not.toBe(second);
		expect(first.endsWith(path.join('FirstOrg', 'gap-finder'))).toBe(true);
		expect(second.endsWith(path.join('SecondOrg', 'gap-finder'))).toBe(true);
	});

	// The capture spec needs the Playwright test runner to load and does not export its folder, so the test reads
	// its source.
	it('builds the stills capture folder from the org folder of the run', () =>
	{
		const source = fs.readFileSync(path.join(__dirname, '..', 'e2e', 'specs', 'capture-stills.spec.js'), 'utf8');

		expect(source).toContain("const STILLS_DIR = path.join(testResultsDirectoryFor(), 'stills');");
	});

	it('reads the raw screenshots from a stills folder inside the org folder of the run', () =>
	{
		const first = rawFolderFor('FirstOrg');
		const second = rawFolderFor('SecondOrg');

		expect(first).not.toBe(second);
		expect(first.endsWith(path.join('FirstOrg', 'stills'))).toBe(true);
		expect(second.endsWith(path.join('SecondOrg', 'stills'))).toBe(true);
	});
});
