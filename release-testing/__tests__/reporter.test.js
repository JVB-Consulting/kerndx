// SPDX-License-Identifier: Apache-2.0
const fs = require('fs');
const path = require('path');

jest.mock('fs');

const KernReporter = require('../e2e/helpers/reporter');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');

const RECORDED_RESULTS_PATH = path.join(__dirname, '..', 'results', 'current-run.json');
const DEVELOPMENT_RESULTS_PATH = path.join(__dirname, '..', 'results', 'development-run.json');
// The run's own org folder: the reporter reads the run target global-setup wrote for the same org alias.
const RUN_TARGET_PATH = path.join(__dirname, '..', 'e2e', '.auth', getSubscriberOrgAlias(), 'run-target.json');
const PACKAGED_RUN_TARGET = JSON.stringify({namespacePrefix: 'kern__'});
const UNPACKAGED_RUN_TARGET = JSON.stringify({namespacePrefix: ''});

// Answers a read by path, and fails like a missing file for any path it was not given.
function mockFiles(contentByPath)
{
	fs.readFileSync.mockImplementation((filePath) =>
	{
		if(Object.prototype.hasOwnProperty.call(contentByPath, filePath))
		{
			return contentByPath[filePath];
		}
		throw new Error('ENOENT');
	});
}

function writtenPaths()
{
	return fs.writeFileSync.mock.calls.map((call) => call[0]);
}

const PASSING_V1 = [
	{title: 'V1: Kern App Home and Health Check', parent: {title: 'Part 1: App Home & Core Pages'}, annotations: []},
	{status: 'passed'}
];

describe('KernReporter', () =>
{
	let reporter;

	beforeEach(() =>
	{
		reporter = new KernReporter();
		jest.clearAllMocks();
		jest.spyOn(console, 'log').mockImplementation(() => undefined);
	});

	afterEach(() =>
	{
		console.log.mockRestore();
	});

	describe('onBegin', () =>
	{
		it('starts a run with nothing collected and reads no results file, because the org is not known yet', () =>
		{
			reporter.onBegin({}, {});

			expect(reporter.results.phase3).toEqual({});
			expect(fs.readFileSync).not.toHaveBeenCalled();
		});
	});

	describe('onTestEnd', () =>
	{
		beforeEach(() =>
		{
			reporter.onBegin({}, {});
		});

		it('should record a passing test', () =>
		{
			reporter.onTestEnd({
				title: 'V1: Kern App Home and Health Check', parent: {title: 'Part 1: App Home & Core Pages'}, annotations: []
			}, {status: 'passed'});

			expect(reporter.results.phase3.part1.V1.result).toBe('PASS');
		});

		it('should record a failing test with error message', () =>
		{
			reporter.onTestEnd({
				title: 'V3: Scheduled Job Lifecycle', parent: {title: 'Part 1: App Home'}, annotations: []
			}, {status: 'failed', error: {message: 'Expected true but got false'}});

			expect(reporter.results.phase3.part1.V3.result).toBe('FAIL');
			expect(reporter.results.phase3.part1.V3.notes).toContain('Expected true');
		});

		it('should extract part number from parent title', () =>
		{
			reporter.onTestEnd({
				title: 'V19: Setup CDC', parent: {title: 'Part 5: Streaming'}, annotations: []
			}, {status: 'passed'});

			expect(reporter.results.phase3.part5.V19.result).toBe('PASS');
		});

		it('should fall back to file path for part number', () =>
		{
			reporter.onTestEnd({
				title: 'V6: Echo Results', parent: {title: 'No part number here'}, location: {file: '/path/to/part2-api-config.spec.js'}, annotations: []
			}, {status: 'passed'});

			expect(reporter.results.phase3.part2.V6.result).toBe('PASS');
		});

		it('should ignore tests without V-number in title', () =>
		{
			reporter.onTestEnd({
				title: 'should set up test data', parent: {title: 'Part 1: App Home'}, annotations: []
			}, {status: 'passed'});

			expect(reporter.results.phase3.part1).toEqual({});
		});

		it('should ignore tests without part reference', () =>
		{
			reporter.onTestEnd({
				title: 'V1: some test', parent: {title: 'unrelated describe'}, annotations: []
			}, {status: 'passed'});

			expect(Object.keys(reporter.results.phase3)).toHaveLength(0);
		});

		it('should truncate long error messages to 200 characters', () =>
		{
			const longMessage = 'x'.repeat(500);
			reporter.onTestEnd({
				title: 'V1: test', parent: {title: 'Part 1: test'}, annotations: []
			}, {status: 'failed', error: {message: longMessage}});

			expect(reporter.results.phase3.part1.V1.notes.length).toBe(200);
		});

		it('should include annotation notes for passing tests', () =>
		{
			reporter.onTestEnd({
				title: 'V1: test', parent: {title: 'Part 1: test'}, annotations: [{type: 'notes', description: 'All health checks green'}]
			}, {status: 'passed'});

			expect(reporter.results.phase3.part1.V1.notes).toBe('All health checks green');
		});
	});

	describe('onEnd', () =>
	{
		beforeEach(() =>
		{
			reporter.onBegin({}, {});
		});

		it('records into the release results file when the run was against an org with the package installed', () =>
		{
			mockFiles({[RUN_TARGET_PATH]: PACKAGED_RUN_TARGET});
			reporter.onTestEnd(...PASSING_V1);

			reporter.onEnd({});

			expect(writtenPaths()).toEqual([RECORDED_RESULTS_PATH]);
			expect(console.log).toHaveBeenCalledWith('[results] journey results recorded in release-testing/results/current-run.json');
			expect(reporter.results.phase3Automated).toBe(true);
			expect(reporter.results.phase3.part1.V1.result).toBe('PASS');
		});

		it('keeps a run against an org without the package namespace out of the release results file', () =>
		{
			mockFiles({[RUN_TARGET_PATH]: UNPACKAGED_RUN_TARGET, [RECORDED_RESULTS_PATH]: JSON.stringify({packageVersion: '1.7.0-13'})});
			reporter.onTestEnd(...PASSING_V1);

			reporter.onEnd({});

			expect(writtenPaths()).toEqual([DEVELOPMENT_RESULTS_PATH]);
			expect(fs.readFileSync).not.toHaveBeenCalledWith(RECORDED_RESULTS_PATH, 'utf8');
			expect(console.log).toHaveBeenCalledWith('[results] journey results recorded in release-testing/results/development-run.json');
		});

		it('treats a run whose target was never written down as a development run', () =>
		{
			mockFiles({});

			reporter.onEnd({});

			expect(writtenPaths()).toEqual([DEVELOPMENT_RESULTS_PATH]);
		});

		it('treats a run target it cannot read as a development run', () =>
		{
			mockFiles({[RUN_TARGET_PATH]: 'not json'});

			reporter.onEnd({});

			expect(writtenPaths()).toEqual([DEVELOPMENT_RESULTS_PATH]);
		});

		it('treats a run target with no namespace entry as a development run', () =>
		{
			mockFiles({[RUN_TARGET_PATH]: JSON.stringify({})});

			reporter.onEnd({});

			expect(writtenPaths()).toEqual([DEVELOPMENT_RESULTS_PATH]);
		});

		it('adds this run to what the chosen file already holds, check by check', () =>
		{
			const existing = {
				packageVersion: '1.0.0-52', phase2: {section1: 'PASS'}, phase3: {part1: {V2: {result: 'PASS', notes: 'kept'}}, part5: {V19: {result: 'FAIL', notes: 'kept'}}}
			};
			mockFiles({[RUN_TARGET_PATH]: PACKAGED_RUN_TARGET, [RECORDED_RESULTS_PATH]: JSON.stringify(existing)});
			reporter.onTestEnd(...PASSING_V1);

			reporter.onEnd({});

			const written = JSON.parse(fs.writeFileSync.mock.calls[0][1]);
			expect(written.packageVersion).toBe('1.0.0-52');
			expect(written.phase2).toEqual({section1: 'PASS'});
			expect(written.phase3.part1.V1.result).toBe('PASS');
			expect(written.phase3.part1.V2.notes).toBe('kept');
			expect(written.phase3.part5.V19.result).toBe('FAIL');
			expect(written.phase3Automated).toBe(true);
		});

		it('starts a results file when the chosen one does not exist', () =>
		{
			mockFiles({[RUN_TARGET_PATH]: PACKAGED_RUN_TARGET});

			reporter.onEnd({});

			const written = JSON.parse(fs.writeFileSync.mock.calls[0][1]);
			expect(written.packageVersion).toBe('1.0.0-XX');
			expect(written.phase3).toEqual({});
		});

		it('writes two-space JSON that ends with a line break, as the recorded file always has', () =>
		{
			mockFiles({[RUN_TARGET_PATH]: PACKAGED_RUN_TARGET});

			reporter.onEnd({});

			const [, content, encoding] = fs.writeFileSync.mock.calls[0];
			expect(content).toBe(JSON.stringify(JSON.parse(content), null, 2) + '\n');
			expect(encoding).toBe('utf8');
		});
	});
});
