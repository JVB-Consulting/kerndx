// SPDX-License-Identifier: Apache-2.0
jest.mock('fs');

const fs = require('fs');
const {compile, main} = require('../runner/result-compiler');

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
		const firstSectionPosition = output.indexOf('section-1');
		const secondSectionPosition = output.indexOf('section-2');
		const tenthSectionPosition = output.indexOf('section-10');
		expect(firstSectionPosition).toBeLessThan(secondSectionPosition);
		expect(secondSectionPosition).toBeLessThan(tenthSectionPosition);
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
		const firstCheckPosition = output.indexOf('| V1 |');
		const thirdCheckPosition = output.indexOf('| V3 |');
		const fifthCheckPosition = output.indexOf('| V5 |');
		expect(firstCheckPosition).toBeLessThan(thirdCheckPosition);
		expect(thirdCheckPosition).toBeLessThan(fifthCheckPosition);
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

	it('should render a phase 3 section whose key is not a part, so a failure recorded there is seen as well as judged', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {
				scripts: {'section-1': {result: 'PASS'}}, testClasses: {result: 'PASS'}
			}, phase3: {
				part1: {V1: {result: 'PASS'}}, exploration: {V200: {result: 'FAIL', notes: 'the drawer lagged'}}
			}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('### exploration');
		expect(output).toContain('| V200 | FAIL | the drawer lagged |');
		expect(output.indexOf('### Part 1')).toBeLessThan(output.indexOf('### exploration'));
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

	it('should name an unlisted part Additional Checks', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase3: {part9: {V50: {result: 'PASS'}}}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.7.0-13');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('### Part 9: Additional Checks');
	});

	it('should skip a phase 3 part the recorded run left blank', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase3: {part1: '', part2: {V1: {result: 'PASS'}}}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.7.0-13');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).not.toContain('### Part 1:');
		expect(output).toContain('### Part 2: API Results, Config & Login');
	});

	it('should write the page, and call the run failed, when a phase 3 part was recorded as null', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase3: {part1: null}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.7.0-13');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**Overall:** FAIL');
	});

	it('should fall back to today and N/A when the run recorded neither a date nor a package version id', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.7.0-13');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toMatch(/\*\*Test Date:\*\* \d{4}-\d{2}-\d{2}\n/);
		expect(output).toContain('**Package Version ID:** N/A');
	});

	it('should leave the score and the notes blank when a row carries neither', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {scripts: {'section-1': {result: 'PASS'}}}, phase3: {part1: {V1: {result: 'PASS'}}}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.7.0-13');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('| section-1 | PASS |  |  |\n');
		expect(output).toContain('| V1 | PASS |  |\n');
	});

	it('should render the extended-load section without notes when the run recorded none', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			extendedLoad: {status: 'PASS'}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.7.0-13');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**Status:** PASS');
		expect(output).not.toContain('**Notes:**');
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

	it('should print the runner\'s note beside an ESLint count the run could not record', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {eslint: {fixtureViolations: null, frameworkViolations: 0, notes: 'Fixture scan failed: bad configuration'}}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**ESLint Fixture Violations:** not recorded (Fixture scan failed: bad configuration)');
		expect(output).toContain('**ESLint Framework Violations:** 0');
		expect(output).not.toContain('null');
	});

	it('should print the runner\'s note on its own line when both ESLint counts were recorded', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {eslint: {fixtureViolations: 6, frameworkViolations: 0, notes: 'Allowed to extend LightningElement but no longer reported: oldComponent.'}}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**ESLint Fixture Violations:** 6\n');
		expect(output).toContain('**ESLint Notes:** Allowed to extend LightningElement but no longer reported: oldComponent.');
	});

	it('should print the fixture files ESLint could not read apart from the fixture problems', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {eslint: {fixtureViolations: 6, fixtureParseFailures: 1, frameworkViolations: 0, notes: ''}}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**ESLint Fixture Violations:** 6\n');
		expect(output).toContain('**ESLint Fixture Parse Failures:** 1\n');
		expect(output).not.toContain('**ESLint Notes:**');
	});

	it('should print the framework files ESLint could not read', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({
			phase2: {eslint: {fixtureViolations: 6, frameworkViolations: 0, frameworkParseFailures: 1, notes: ''}}
		}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		compile('1.0.0-53');

		const output = fs.writeFileSync.mock.calls[0][1];
		expect(output).toContain('**ESLint Framework Violations:** 0\n');
		expect(output).toContain('**ESLint Framework Parse Failures:** 1\n');
	});

	it.each([
		[['--version', '1.11.0-1']],
		[['1.11.0-1']]
	])('should write 1.11.0-1.md with that title from the command line %j', (commandLine) =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readFileSync.mockReturnValue(JSON.stringify({}));
		fs.writeFileSync.mockImplementation(() =>
		{
		});

		main(commandLine);

		expect(fs.writeFileSync).toHaveBeenCalledWith(expect.stringMatching(/[\\/]1\.11\.0-1\.md$/), expect.any(String), 'utf8');
		expect(fs.writeFileSync.mock.calls[0][1]).toContain('# KernDX Release Test Results — 1.11.0-1\n');
	});

	it.each([
		[[]],
		[['--version']]
	])('should print the usage and write nothing when the command line %j names no version', (commandLine) =>
	{
		expect(() => main(commandLine)).toThrow('process.exit(1)');
		expect(console.error).toHaveBeenCalledWith(expect.stringContaining('Usage: node result-compiler.js'));
		expect(fs.writeFileSync).not.toHaveBeenCalled();
	});
});
