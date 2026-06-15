// SPDX-License-Identifier: BUSL-1.1
jest.mock('fs');

const fs = require('fs');
const {compile} = require('../runner/result-compiler');

describe('result-compiler', () =>
{
	let mockExit;

	beforeEach(() =>
	{
		jest.clearAllMocks();
		mockExit = jest.spyOn(process, 'exit').mockImplementation((code) =>
		{
			throw new Error(`process.exit(${code})`);
		});
		jest.spyOn(console, 'error').mockImplementation(() =>
		{
		});
		jest.spyOn(console, 'log').mockImplementation(() =>
		{
		});
	});

	afterEach(() =>
	{
		mockExit.mockRestore();
		console.error.mockRestore();
		console.log.mockRestore();
	});

	it('should exit when current-run.json does not exist', () =>
	{
		fs.existsSync.mockReturnValue(false);
		expect(() => compile('1.0.0-53')).toThrow('process.exit(1)');
		expect(mockExit).toHaveBeenCalledWith(1);
	});

	it('should generate markdown with version in title', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			testDate: '2026-03-13', subscriberPackageVersionId: '04txx'
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('# KernDX Release Test Results — 1.0.0-53');
		expect(output).toContain('**Test Date:** 2026-03-13');
		expect(output).toContain('**Package Version ID:** 04txx');
	});

	it('should include phase 2 script results sorted by section number', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {
				scripts: {
					'section-10': {result: 'PASS', score: '6/6'}, 'section-2': {result: 'PASS', score: '6/6'}, 'section-1': {result: 'PASS', score: '7/7'}
				}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		const section1Pos = output.indexOf('section-1');
		const section2Pos = output.indexOf('section-2');
		const section10Pos = output.indexOf('section-10');
		expect(section1Pos).toBeLessThan(section2Pos);
		expect(section2Pos).toBeLessThan(section10Pos);
	});

	it('should include test class results', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {
				testClasses: {result: 'PASS', passed: 65, failed: 0, coverage: '100%'}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**Result:** PASS');
		expect(output).toContain('**Passed:** 65');
		expect(output).toContain('**Coverage:** 100%');
	});

	it('should include scanner results', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {
				scanner: {violations: 36}, eslint: {fixtureViolations: 3, frameworkViolations: 0}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**PMD Violations:** 36');
		expect(output).toContain('**ESLint Fixture Violations:** 3');
	});

	it('should include phase 3 visual test results with part names', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase3: {
				part1: {
					V1: {result: 'PASS', notes: 'All green'}, V2: {result: 'PASS', notes: 'Tabs work'}
				}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('### Part 1: App Home & Core Pages');
		expect(output).toContain('V1');
		expect(output).toContain('All green');
	});

	it('should render phase 3 parts 7 and 8 with their names', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase3: {
				part7: {V30: {result: 'PASS'}}, part8: {V40: {result: 'PASS'}}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.1.0-1');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('### Part 7: Async Chain Orchestration');
		expect(output).toContain('### Part 8: Chain Monitor UI');
		expect(output).toContain('V30');
		expect(output).toContain('V40');
	});

	it('should include the platform/API version line when present', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			apiVersion: '67.0', subscriberPackageVersionId: '04txx'
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.1.0-1');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**Platform / API Version:** 67.0');
	});

	it('should omit the platform/API version line when absent', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			subscriberPackageVersionId: '04txx'
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).not.toContain('Platform / API Version');
	});

	it('should render the extended-load status when present', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			extendedLoad: {status: 'NOT_RUN', notes: 'Pre-tag-only gate — not executed this cycle.'}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.1.0-1');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('## Extended Load');
		expect(output).toContain('**Status:** NOT_RUN');
		expect(output).toContain('Pre-tag-only gate');
	});

	it('should sort visual checks by V-number', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase3: {
				part1: {
					V5: {result: 'PASS'}, V1: {result: 'PASS'}, V3: {result: 'PASS'}
				}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		const v1Pos = output.indexOf('| V1 |');
		const v3Pos = output.indexOf('| V3 |');
		const v5Pos = output.indexOf('| V5 |');
		expect(v1Pos).toBeLessThan(v3Pos);
		expect(v3Pos).toBeLessThan(v5Pos);
	});

	it('should report ALL PASS when everything passes', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {
				scripts: {'section-1': {result: 'PASS'}}, testClasses: {result: 'PASS'}
			}, phase3: {
				part1: {V1: {result: 'PASS'}}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**Overall:** ALL PASS');
	});

	it('should report FAIL when phase 2 has failures', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {
				scripts: {'section-1': {result: 'FAIL'}}, testClasses: {result: 'PASS'}
			}, phase3: {
				part1: {V1: {result: 'PASS'}}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**Overall:** FAIL');
	});

	it('should report FAIL when phase 3 has failures', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {
				scripts: {'section-1': {result: 'PASS'}}, testClasses: {result: 'PASS'}
			}, phase3: {
				part1: {V1: {result: 'FAIL', notes: 'Health check failed'}}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**Overall:** FAIL');
	});

	it('should include automation note when phase3Automated is set', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase3Automated: true, phase3: {}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('Playwright automation');
	});

	it('should write output to versioned file', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		const outputPath = compile('1.0.0-53');

		expect(outputPath).toContain('1.0.0-53.md');
		expect(fs.writeFileSync).toHaveBeenCalledWith(expect.stringContaining('1.0.0-53.md'), expect.any(String), 'utf8');
	});
});
