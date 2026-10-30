// SPDX-License-Identifier: Apache-2.0
jest.mock('child_process', () => ({execSync: jest.fn()}));

// The one query run-all makes through the journeys' helper: which namespace the org gives the package.
jest.mock('../e2e/helpers/sf-namespace', () => ({namespacePrefix: jest.fn()}));

jest.mock('../runner/result-compiler', () => ({compile: jest.fn()}));

// run-all reads the alias when it loads, so it is set here, before anything is required, and no test depends on the shell.
// The shell's own value is put back once this file is done, because jest runs other test files in the same process.
const ORG_ALIAS = 'MySubscriberOrg';
const ALIAS_BEFORE_THIS_FILE = process.env.SF_SUBSCRIBER_ORG_ALIAS;
process.env.SF_SUBSCRIBER_ORG_ALIAS = ORG_ALIAS;

const fs = require('fs');
const {execSync} = require('child_process');
const {namespacePrefix} = require('../e2e/helpers/sf-namespace');
const {compile} = require('../runner/result-compiler');
const {RECORDED_RESULTS_PATH, ReleaseTargetError} = require('../runner/release-target');

const {main, reportFailure, resolveVersion, readInstalledKernVersion} = require('../runner/run-all');

const VERSION = '1.7.0-13';
const SUBSCRIBER_PACKAGE_VERSION_ID = '04t5f000000AbCdEAA';
const FALLBACK_VERSION = '1.0.0-XX';
const RECORDED_BEFORE_THE_RUN = {packageVersion: '1.6.0-3', testDate: '2026-07-26', phase2: {scripts: {'section-1': {result: 'PASS', score: '6/6'}}}};

const realReadFileSync = fs.readFileSync;

// Answers for the recorded results alone; every other read, jest's own included, goes to the real file system.
function readRecordedResults(filePath, options)
{
	return String(filePath) === RECORDED_RESULTS_PATH ? JSON.stringify(RECORDED_BEFORE_THE_RUN) : realReadFileSync(filePath, options);
}

describe('run-all', () =>
{
	const realArguments = process.argv;
	let writeSpy;

	beforeEach(() =>
	{
		// execSync, namespacePrefix and compile are module-level jest.fn()s, so clearing the calls would leave any return
		// value or throw a test scripted on one of them in place for the tests that follow. Reset gives every test the
		// same unscripted mocks. The spies below are made after this line, so resetting cannot reach them.
		jest.resetAllMocks();
		process.argv = [
			'node',
			'run-all.js',
			VERSION,
			'--skip-phase2',
			'--skip-phase3'
		];
		writeSpy = jest.spyOn(fs, 'writeFileSync').mockImplementation(() => undefined);
		jest.spyOn(fs, 'mkdirSync').mockImplementation(() => undefined);
		jest.spyOn(fs, 'readFileSync').mockImplementation(readRecordedResults);
		jest.spyOn(process, 'exit').mockImplementation(() => undefined);
		jest.spyOn(console, 'log').mockImplementation(() => undefined);
	});

	afterEach(() =>
	{
		process.argv = realArguments;
		jest.restoreAllMocks();
	});

	afterAll(() =>
	{
		if(ALIAS_BEFORE_THIS_FILE === undefined)
		{
			delete process.env.SF_SUBSCRIBER_ORG_ALIAS;
		}
		else
		{
			process.env.SF_SUBSCRIBER_ORG_ALIAS = ALIAS_BEFORE_THIS_FILE;
		}
	});

	it('stops against an org without the package before it writes the recorded results, starts a phase or compiles anything', async() =>
	{
		namespacePrefix.mockReturnValue('');

		await expect(main()).rejects.toThrow(ReleaseTargetError);

		expect(writeSpy).not.toHaveBeenCalled();
		expect(execSync).not.toHaveBeenCalled();
		expect(compile).not.toHaveBeenCalled();
	});

	it('names the org it was pointed at when it stops', async() =>
	{
		namespacePrefix.mockReturnValue('');

		await expect(main()).rejects.toThrow(`"${ORG_ALIAS}"`);
	});

	it('stops the same way, and writes nothing, when the org cannot be asked at all', async() =>
	{
		namespacePrefix.mockImplementation(() =>
		{
			throw Object.assign(new Error('Command failed: sf data query'), {status: 1, stdout: ''});
		});

		await expect(main()).rejects.toThrow(ReleaseTargetError);

		expect(writeSpy).not.toHaveBeenCalled();
		expect(execSync).not.toHaveBeenCalled();
		expect(compile).not.toHaveBeenCalled();
	});

	it('stamps the version and the date into the recorded results for an org with the package installed, and keeps what the file held', async() =>
	{
		namespacePrefix.mockReturnValue('kern__');

		await main();

		expect(writeSpy).toHaveBeenCalledTimes(1);
		const [writtenPath, content] = writeSpy.mock.calls[0];
		const written = JSON.parse(content);
		expect(writtenPath).toBe(RECORDED_RESULTS_PATH);
		expect(written.packageVersion).toBe(VERSION);
		expect(written.testDate).toMatch(/^\d{4}-\d{2}-\d{2}$/);
		expect(written.phase2).toEqual(RECORDED_BEFORE_THE_RUN.phase2);
		expect(compile).toHaveBeenCalledWith(VERSION);
		expect(process.exit).toHaveBeenCalledWith(0);
	});

	describe('resolveVersion', () =>
	{
		it('takes the version it was given on the command line and asks the org nothing', () =>
		{
			expect(resolveVersion(VERSION)).toStrictEqual({version: VERSION, subscriberPackageVersionId: undefined});
			expect(execSync).not.toHaveBeenCalled();
		});

		it('takes the version and the package version id from the org when the command line names none', () =>
		{
			execSync.mockReturnValue(JSON.stringify({
				result: [
					{
						SubscriberPackageName: 'Kern',
						SubscriberPackageNamespace: 'kern',
						SubscriberPackageVersionNumber: '1.7.0.13',
						SubscriberPackageVersionId: SUBSCRIBER_PACKAGE_VERSION_ID
					}
				]
			}));

			expect(resolveVersion(undefined)).toStrictEqual({version: VERSION, subscriberPackageVersionId: SUBSCRIBER_PACKAGE_VERSION_ID});
		});

		it('falls back to a placeholder version, and to no package version id, when the org has nothing to report', () =>
		{
			jest.spyOn(console, 'warn').mockImplementation(() => undefined);
			execSync.mockImplementation(() =>
			{
				throw new Error('No authorization information found');
			});

			expect(resolveVersion(undefined)).toStrictEqual({version: FALLBACK_VERSION, subscriberPackageVersionId: undefined});
		});
	});

	describe('readInstalledKernVersion', () =>
	{
		it('turns the Kern row of the installed package list into the version the results are filed under', () =>
		{
			const output = JSON.stringify({
				result: [
					{SubscriberPackageName: 'Other', SubscriberPackageNamespace: 'other', SubscriberPackageVersionNumber: '3.2.1.9'},
					{SubscriberPackageName: 'Kern', SubscriberPackageNamespace: 'kern', SubscriberPackageVersionNumber: '1.10.0.4'}
				]
			});

			expect(readInstalledKernVersion(output)).toBe('1.10.0-4');
		});

		it('answers null when the org has no Kern package installed', () =>
		{
			const output = JSON.stringify({result: [{SubscriberPackageName: 'Other', SubscriberPackageNamespace: 'other', SubscriberPackageVersionNumber: '3.2.1.9'}]});

			expect(readInstalledKernVersion(output)).toBeNull();
			expect(readInstalledKernVersion(JSON.stringify({result: []}))).toBeNull();
		});
	});

	describe('reportFailure', () =>
	{
		beforeEach(() =>
		{
			jest.spyOn(console, 'error').mockImplementation(() => undefined);
		});

		it('prints a refusal as its message alone, with no stack trace, and ends the run as failed', () =>
		{
			reportFailure(new ReleaseTargetError('which org, why, and what to change'));

			expect(console.error).toHaveBeenCalledWith('which org, why, and what to change');
			expect(console.error).not.toHaveBeenCalledWith('Pipeline failed:', expect.anything());
			expect(process.exit).toHaveBeenCalledWith(1);
		});

		it('prints any other failure whole, so its stack trace is kept, and ends the run as failed', () =>
		{
			const failure = new Error('something nobody planned for');

			reportFailure(failure);

			expect(console.error).toHaveBeenCalledWith('Pipeline failed:', failure);
			expect(process.exit).toHaveBeenCalledWith(1);
		});
	});
});
