// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const path = require('path');

jest.mock('fs');

const KernReporter = require('../e2e/helpers/reporter');

const RESULTS_PATH = path.join(__dirname, '..', 'results', 'current-run.json');

describe('KernReporter', () =>
{
	let reporter;

	beforeEach(() =>
	{
		reporter = new KernReporter();
		jest.clearAllMocks();
	});

	describe('onBegin', () =>
	{
		it('should load existing results file', () =>
		{
			const existing = {packageVersion: '1.0.0-52', phase2: {}};
			fs.readFileSync.mockReturnValue(JSON.stringify(existing));

			reporter.onBegin({}, {});

			expect(reporter.results.packageVersion).toBe('1.0.0-52');
			expect(reporter.results.phase3).toEqual({});
		});

		it('should create default results when file does not exist', () =>
		{
			fs.readFileSync.mockImplementation(() =>
			{
				throw new Error('ENOENT');
			});

			reporter.onBegin({}, {});

			expect(reporter.results.packageVersion).toBe('1.0.0-XX');
			expect(reporter.results.phase3).toEqual({});
		});

		it('should not overwrite existing phase3 data', () =>
		{
			const existing = {phase3: {part1: {V1: {result: 'PASS'}}}};
			fs.readFileSync.mockReturnValue(JSON.stringify(existing));

			reporter.onBegin({}, {});

			expect(reporter.results.phase3.part1.V1.result).toBe('PASS');
		});
	});

	describe('onTestEnd', () =>
	{
		beforeEach(() =>
		{
			fs.readFileSync.mockImplementation(() =>
			{
				throw new Error('ENOENT');
			});
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
		it('should set phase3Automated flag and save', () =>
		{
			fs.readFileSync.mockImplementation(() =>
			{
				throw new Error('ENOENT');
			});
			reporter.onBegin({}, {});
			fs.mkdirSync.mockImplementation(() =>
			{
			});
			fs.writeFileSync.mockImplementation(() =>
			{
			});

			reporter.onEnd({});

			expect(reporter.results.phase3Automated).toBe(true);
			expect(fs.writeFileSync).toHaveBeenCalledWith(expect.stringContaining('current-run.json'), expect.any(String), 'utf8');
		});

		it('should write valid JSON', () =>
		{
			fs.readFileSync.mockImplementation(() =>
			{
				throw new Error('ENOENT');
			});
			reporter.onBegin({}, {});
			fs.mkdirSync.mockImplementation(() =>
			{
			});
			fs.writeFileSync.mockImplementation(() =>
			{
			});

			reporter.onEnd({});

			const writtenContent = fs.writeFileSync.mock.calls[0][1];
			expect(() => JSON.parse(writtenContent)).not.toThrow();
		});
	});
});
