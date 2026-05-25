// SPDX-License-Identifier: BUSL-1.1
jest.mock('child_process', () => ({
	exec: jest.fn(), execSync: jest.fn()
}));

// run-phase2 imports NamedOrgNotFoundError + isNamedOrgNotFoundError from
// cmdt-deployer for the pre-flight check. The mock must export both so
// module load doesn't break. jest.mock() is hoisted above import statements
// so the fake class is defined inline.
jest.mock('../../release-testing/runner/cmdt-deployer', () =>
{
	class _FakeNamedOrgNotFoundError extends Error
	{
		constructor(orgAlias, originalMessage)
		{
			super(`NamedOrgNotFoundError ${orgAlias}: ${originalMessage}`);
			this.name = 'NamedOrgNotFoundError';
			this.orgAlias = orgAlias;
		}
	}
	return {
		deployCmdtState: jest.fn(),
		isNamedOrgNotFoundError: jest.fn(() => false),
		NamedOrgNotFoundError: _FakeNamedOrgNotFoundError
	};
});

const {exec} = require('child_process');

const {
	INDEPENDENT_SCRIPTS, MAX_CONCURRENT, runScript, runBatch
} = require('../runner/run-phase2');

describe('INDEPENDENT_SCRIPTS', () =>
{
	it('should contain 26 scripts', () =>
	{
		expect(INDEPENDENT_SCRIPTS).toHaveLength(26);
	});

	it('should have unique section numbers', () =>
	{
		const sections = INDEPENDENT_SCRIPTS.map(s => s.section);
		expect(new Set(sections).size).toBe(sections.length);
	});

	it('should not include sections 3, 11, 18, 22, 27', () =>
	{
		const sections = INDEPENDENT_SCRIPTS.map(s => s.section);
		expect(sections).not.toContain(3);
		expect(sections).not.toContain(11);
		expect(sections).not.toContain(18);
		expect(sections).not.toContain(22);
		expect(sections).not.toContain(27);
	});

	it('should have expected assertion counts for each section', () =>
	{
		const section1 = INDEPENDENT_SCRIPTS.find(s => s.section === 1);
		expect(section1.expected).toBe(5);

		const section9 = INDEPENDENT_SCRIPTS.find(s => s.section === 9);
		expect(section9.expected).toBe(6);

		const section15 = INDEPENDENT_SCRIPTS.find(s => s.section === 15);
		expect(section15.expected).toBe(12);
	});

	it('should have valid file names matching section numbers', () =>
	{
		for(const script of INDEPENDENT_SCRIPTS)
		{
			expect(script.file).toContain(`section-${script.section}-`);
			expect(script.file).toMatch(/\.apex$/);
		}
	});
});

describe('MAX_CONCURRENT', () =>
{
	it('should be 5', () =>
	{
		expect(MAX_CONCURRENT).toBe(5);
	});
});

describe('runScript', () =>
{
	it('should resolve with parsed PASS/FAIL counts', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, [
				'USER_DEBUG [5]|DEBUG|1a PASS: works',
				'USER_DEBUG [10]|DEBUG|1b PASS: also works'
			].join('\n'));
		});

		const result = await runScript('/path/to/script.apex');
		expect(result.pass).toBe(2);
		expect(result.fail).toBe(0);
		expect(result.total).toBe(2);
	});

	it('should handle failures gracefully', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(new Error('timeout'), 'USER_DEBUG [5]|DEBUG|1a FAIL: broken');
		});

		const result = await runScript('/path/to/script.apex');
		expect(result.fail).toBe(1);
		expect(result.error).toBeDefined();
	});

	it('should not count BYPASS audit lines as PASS (bypass-audit regression test)', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, [
				'USER_DEBUG [5]|DEBUG|1a PASS: works',
				'USER_DEBUG [10]|DEBUG|  Log: [WARN] kern.TRG_Base.bypass — Trigger bypass audit: BYPASS OBJECT_NAME "Account"',
				'USER_DEBUG [15]|DEBUG|  Log: [WARN] kern.TRG_Base.bypass — Trigger bypass audit: BYPASS ACTION_NAME "TRG_SetFoobarDefaults"'
			].join('\n'));
		});

		const result = await runScript('/path/to/script.apex');
		expect(result.pass).toBe(1);
		expect(result.fail).toBe(0);
	});

	it('should handle empty output', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, '');
		});

		const result = await runScript('/path/to/script.apex');
		expect(result.pass).toBe(0);
		expect(result.fail).toBe(0);
	});
});

describe('runBatch', () =>
{
	it('should process all scripts and return results', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, 'USER_DEBUG [5]|DEBUG|1a PASS: test');
		});

		const scripts = [
			{section: 1, file: 'test-1.apex', expected: 1},
			{section: 2, file: 'test-2.apex', expected: 1}
		];

		const results = await runBatch(scripts, 2);

		expect(results['section-1'].result).toBe('PASS');
		expect(results['section-1'].score).toBe('1/1');
		expect(results['section-2'].result).toBe('PASS');
	});

	it('should mark FAIL when pass count does not match expected', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, 'USER_DEBUG [5]|DEBUG|1a PASS: test');
		});

		const scripts = [{section: 1, file: 'test.apex', expected: 5}];
		const results = await runBatch(scripts, 1);

		expect(results['section-1'].result).toBe('FAIL');
		expect(results['section-1'].score).toBe('1/5');
	});

	it('should mark FAIL when there are failures even with correct pass count', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, [
				'USER_DEBUG [5]|DEBUG|1a PASS: test',
				'USER_DEBUG [10]|DEBUG|1b FAIL: broken'
			].join('\n'));
		});

		const scripts = [{section: 1, file: 'test.apex', expected: 1}];
		const results = await runBatch(scripts, 1);

		expect(results['section-1'].result).toBe('FAIL');
	});

	it('should respect concurrency limit', async() =>
	{
		let concurrentCount = 0;
		let maxConcurrent = 0;

		exec.mockImplementation((cmd, opts, callback) =>
		{
			concurrentCount++;
			maxConcurrent = Math.max(maxConcurrent, concurrentCount);
			setTimeout(() =>
			{
				concurrentCount--;
				callback(null, 'USER_DEBUG [5]|DEBUG|1a PASS: test');
			}, 10);
		});

		const scripts = Array.from({length: 10}, (_, i) => ({
			section: i + 1, file: `test-${i + 1}.apex`, expected: 1
		}));

		await runBatch(scripts, 3);

		expect(maxConcurrent).toBeLessThanOrEqual(3);
	});
});
