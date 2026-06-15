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
		deployCmdtState: jest.fn(), deployMetadataDir: jest.fn(), deleteCmdtRecords: jest.fn(), isNamedOrgNotFoundError: jest.fn(() => false), NamedOrgNotFoundError: _FakeNamedOrgNotFoundError
	};
});

const {exec} = require('child_process');
const {deployMetadataDir, deployCmdtState, deleteCmdtRecords} = require('../runner/cmdt-deployer');

const {
	INDEPENDENT_SCRIPTS, MAX_CONCURRENT, runScript, runBatch, runSection76, runSection67, runSection68, runSection69, runSection70, runSection71, runSection72, runSection75, runSection66, runSection65, runSection77
} = require('../runner/run-phase2');

describe('INDEPENDENT_SCRIPTS', () =>
{
	it('should contain 44 scripts', () =>
	{
		expect(INDEPENDENT_SCRIPTS).toHaveLength(44);
	});

	it('should have unique section numbers', () =>
	{
		const sections = INDEPENDENT_SCRIPTS.map(s => s.section);
		expect(new Set(sections).size).toBe(sections.length);
	});

	it('should not include sections 3, 11, 18, 22, 27, 65', () =>
	{
		const sections = INDEPENDENT_SCRIPTS.map(s => s.section);
		expect(sections).not.toContain(3);
		expect(sections).not.toContain(11);
		expect(sections).not.toContain(18);
		expect(sections).not.toContain(22);
		expect(sections).not.toContain(27);
		// 65 moved to the orchestrated launch + verify split (runSection65) — the
		// audit trail persists asynchronously, so the single-transaction parallel
		// slot raced platform-event delivery and flaked inside the suite.
		expect(sections).not.toContain(65);
	});

	it('should have expected assertion counts for each section', () =>
	{
		const section1 = INDEPENDENT_SCRIPTS.find(s => s.section === 1);
		expect(section1.expected).toBe(6);

		const section9 = INDEPENDENT_SCRIPTS.find(s => s.section === 9);
		expect(section9.expected).toBe(7);

		const section15 = INDEPENDENT_SCRIPTS.find(s => s.section === 15);
		expect(section15.expected).toBe(13);
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

describe('runSection76', () =>
{
	function mockScriptOutputs(passCounts)
	{
		const outputs = passCounts.map((count, scriptIndex) => Array.from({length: count}, (_, i) => `USER_DEBUG [5]|DEBUG|76${scriptIndex}${i} PASS: scenario`).join('\n'));
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});
	}

	beforeEach(() =>
	{
		jest.clearAllMocks();
	});

	it('should deploy the advisor bundles in round-trip order and aggregate 14 passes', async() =>
	{
		mockScriptOutputs([
			3,
			3,
			3,
			2,
			3
		]);

		const results = await runSection76();

		expect(results['section-76'].result).toBe('PASS');
		expect(results['section-76'].score).toBe('14/14');
		expect(deployMetadataDir).toHaveBeenCalledTimes(4);
		expect(deployMetadataDir).toHaveBeenNthCalledWith(1, expect.stringContaining('masking-advisor-bundles'));
		expect(deployMetadataDir.mock.calls[0][0].endsWith('create')).toBe(true);
		expect(deployMetadataDir.mock.calls[1][0].endsWith('disable')).toBe(true);
		expect(deployMetadataDir.mock.calls[2][0].endsWith('reenable')).toBe(true);
		expect(deployMetadataDir.mock.calls[3][0].endsWith('disable')).toBe(true);
	});

	it('should mark FAIL when a verify script under-passes', async() =>
	{
		mockScriptOutputs([
			3,
			2,
			3,
			2,
			3
		]);

		const results = await runSection76();

		expect(results['section-76'].result).toBe('FAIL');
		expect(results['section-76'].score).toBe('13/14');
	});

	it('should mark FAIL when any script reports a failure even at full pass count', async() =>
	{
		const outputs = [
			Array.from({length: 3}, (_, i) => `USER_DEBUG [5]|DEBUG|76a${i} PASS: scenario`).join('\n'),
			[
				'USER_DEBUG [5]|DEBUG|76d PASS: scenario',
				'USER_DEBUG [5]|DEBUG|76e PASS: scenario',
				'USER_DEBUG [5]|DEBUG|76j PASS: scenario',
				'USER_DEBUG [9]|DEBUG|76x FAIL: broken'
			].join('\n'),
			Array.from({length: 3}, (_, i) => `USER_DEBUG [5]|DEBUG|76f${i} PASS: scenario`).join('\n'),
			Array.from({length: 2}, (_, i) => `USER_DEBUG [5]|DEBUG|76h${i} PASS: scenario`).join('\n'),
			Array.from({length: 3}, (_, i) => `USER_DEBUG [5]|DEBUG|76g${i} PASS: scenario`).join('\n')
		];
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});

		const results = await runSection76();

		expect(results['section-76'].result).toBe('FAIL');
	});
});

describe('post-trigger action sections (67-70)', () =>
{
	// Each handler is a serial CMDT-state-fixture section: deploy a fixture, run the
	// script(s), restore postaction-disabled. The mock returns N PASS lines per script
	// call (in order) so the aggregate score and the fixture deploy sequence can be asserted.
	function mockPassCounts(passCounts)
	{
		const outputs = passCounts.map((count, scriptIndex) => Array.from({length: count}, (_, i) => `USER_DEBUG [5]|DEBUG|p${scriptIndex}${i} PASS: scenario`).join('\n'));
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});
	}

	beforeEach(() =>
	{
		jest.clearAllMocks();
	});

	it('section 67 deploys postaction-enabled, restores disabled, and aggregates 6 passes', async() =>
	{
		mockPassCounts([6]);

		const results = await runSection67();

		expect(results['section-67'].result).toBe('PASS');
		expect(results['section-67'].score).toBe('6/6');
		expect(deployCmdtState).toHaveBeenCalledTimes(2);
		expect(deployCmdtState).toHaveBeenNthCalledWith(1, 'postaction-enabled');
		expect(deployCmdtState).toHaveBeenNthCalledWith(2, 'postaction-disabled');
	});

	it('section 67 marks FAIL when the script under-passes', async() =>
	{
		mockPassCounts([5]);

		const results = await runSection67();

		expect(results['section-67'].result).toBe('FAIL');
		expect(results['section-67'].score).toBe('5/6');
	});

	it('section 68 cycles the flag off then on and aggregates 2 passes', async() =>
	{
		mockPassCounts([
			1,
			1
		]);

		const results = await runSection68();

		expect(results['section-68'].result).toBe('PASS');
		expect(results['section-68'].score).toBe('2/2');
		expect(deployCmdtState).toHaveBeenCalledTimes(3);
		expect(deployCmdtState).toHaveBeenNthCalledWith(1, 'postaction-disabled');
		expect(deployCmdtState).toHaveBeenNthCalledWith(2, 'postaction-enabled');
		expect(deployCmdtState).toHaveBeenNthCalledWith(3, 'postaction-disabled');
	});

	it('section 69 deploys dml-active, restores disabled, and aggregates 2 passes', async() =>
	{
		mockPassCounts([2]);

		const results = await runSection69();

		expect(results['section-69'].result).toBe('PASS');
		expect(results['section-69'].score).toBe('2/2');
		expect(deployCmdtState).toHaveBeenCalledTimes(2);
		expect(deployCmdtState).toHaveBeenNthCalledWith(1, 'dml-active');
		expect(deployCmdtState).toHaveBeenNthCalledWith(2, 'postaction-disabled');
	});

	it('section 70 cycles LogAndContinue then BlockDml and aggregates 4 passes', async() =>
	{
		mockPassCounts([
			2,
			2
		]);

		const results = await runSection70();

		expect(results['section-70'].result).toBe('PASS');
		expect(results['section-70'].score).toBe('4/4');
		expect(deployCmdtState).toHaveBeenCalledTimes(3);
		expect(deployCmdtState).toHaveBeenNthCalledWith(1, 'failing-logandcontinue');
		expect(deployCmdtState).toHaveBeenNthCalledWith(2, 'failing-blockdml');
		expect(deployCmdtState).toHaveBeenNthCalledWith(3, 'postaction-disabled');
	});

	it('section 70 marks FAIL when a script reports a failure even at full pass count', async() =>
	{
		const outputs = [
			Array.from({length: 2}, (_, i) => `USER_DEBUG [5]|DEBUG|70a${i} PASS: scenario`).join('\n'),
			[
				'USER_DEBUG [5]|DEBUG|70c PASS: scenario',
				'USER_DEBUG [5]|DEBUG|70d PASS: scenario',
				'USER_DEBUG [9]|DEBUG|70x FAIL: broken'
			].join('\n')
		];
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});

		const results = await runSection70();

		expect(results['section-70'].result).toBe('FAIL');
	});
});

describe('CDC change-event sections (71-72)', () =>
{
	// Each handler is a launch + verify section gated behind a CMDT fixture: deploy the fixture,
	// run the launch script, wait for asynchronous change-event delivery, run the verify script,
	// then restore the dormant fixture. The 30s delivery wait is stubbed to fire immediately so
	// the unit test stays fast. The mock returns N PASS lines per script call (launch then verify),
	// so the aggregate score and the fixture deploy sequence can be asserted.
	function mockPassCounts(passCounts)
	{
		const outputs = passCounts.map((count, scriptIndex) => Array.from({length: count}, (_, i) => `USER_DEBUG [5]|DEBUG|c${scriptIndex}${i} PASS: scenario`).join('\n'));
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});
	}

	beforeEach(() =>
	{
		jest.clearAllMocks();
		jest.spyOn(global, 'setTimeout').mockImplementation((fn) =>
		{
			fn();
			return 0;
		});
	});

	afterEach(() =>
	{
		global.setTimeout.mockRestore();
	});

	it('section 71 deploys cdc-header-enabled, restores disabled, and aggregates 3 passes', async() =>
	{
		mockPassCounts([
			1,
			2
		]);

		const results = await runSection71();

		expect(results['section-71'].result).toBe('PASS');
		expect(results['section-71'].score).toBe('3/3');
		expect(deployCmdtState).toHaveBeenCalledTimes(2);
		expect(deployCmdtState).toHaveBeenNthCalledWith(1, 'cdc-header-enabled');
		expect(deployCmdtState).toHaveBeenNthCalledWith(2, 'cdc-header-disabled');
	});

	it('section 71 marks FAIL when the verify under-passes', async() =>
	{
		mockPassCounts([
			1,
			1
		]);

		const results = await runSection71();

		expect(results['section-71'].result).toBe('FAIL');
		expect(results['section-71'].score).toBe('2/3');
	});

	it('section 72 deploys cdc-blockdml-degrade-active, restores disabled, and aggregates 4 passes', async() =>
	{
		mockPassCounts([
			1,
			3
		]);

		const results = await runSection72();

		expect(results['section-72'].result).toBe('PASS');
		expect(results['section-72'].score).toBe('4/4');
		expect(deployCmdtState).toHaveBeenCalledTimes(2);
		expect(deployCmdtState).toHaveBeenNthCalledWith(1, 'cdc-blockdml-degrade-active');
		expect(deployCmdtState).toHaveBeenNthCalledWith(2, 'cdc-header-disabled');
	});

	it('section 72 marks FAIL when a script reports a failure even at full pass count', async() =>
	{
		const outputs = [
			'USER_DEBUG [5]|DEBUG|72a PASS: scenario',
			[
				'USER_DEBUG [5]|DEBUG|72b PASS: scenario',
				'USER_DEBUG [5]|DEBUG|72c PASS: scenario',
				'USER_DEBUG [5]|DEBUG|72d PASS: scenario',
				'USER_DEBUG [9]|DEBUG|72x FAIL: broken'
			].join('\n')
		];
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});

		const results = await runSection72();

		expect(results['section-72'].result).toBe('FAIL');
	});
});

describe('queueable unhandled-exception section (75)', () =>
{
	// A launch + verify section with NO CMDT fixture: run the launch script, wait for the queueable to
	// run and fail, then run the verify script that asserts the surfaced Failed AsyncApexJob. The 30s
	// wait is stubbed to fire immediately so the unit test stays fast. The mock returns N PASS lines per
	// script call (launch then verify), so the aggregate score can be asserted and the absence of any
	// fixture deploy confirmed.
	function mockPassCounts(passCounts)
	{
		const outputs = passCounts.map((count, scriptIndex) => Array.from({length: count}, (_, i) => `USER_DEBUG [5]|DEBUG|q${scriptIndex}${i} PASS: scenario`).join('\n'));
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});
	}

	beforeEach(() =>
	{
		jest.clearAllMocks();
		jest.spyOn(global, 'setTimeout').mockImplementation((fn) =>
		{
			fn();
			return 0;
		});
	});

	afterEach(() =>
	{
		global.setTimeout.mockRestore();
	});

	it('section 75 aggregates 3 passes from launch + verify and deploys no fixture', async() =>
	{
		mockPassCounts([
			1,
			2
		]);

		const results = await runSection75();

		expect(results['section-75'].result).toBe('PASS');
		expect(results['section-75'].score).toBe('3/3');
		expect(deployCmdtState).not.toHaveBeenCalled();
	});

	it('section 75 marks FAIL when the verify under-passes', async() =>
	{
		mockPassCounts([
			1,
			1
		]);

		const results = await runSection75();

		expect(results['section-75'].result).toBe('FAIL');
		expect(results['section-75'].score).toBe('2/3');
	});

	it('section 75 marks FAIL when a script reports a failure even at full pass count', async() =>
	{
		const outputs = [
			'USER_DEBUG [5]|DEBUG|75a PASS: scenario',
			[
				'USER_DEBUG [5]|DEBUG|75b PASS: scenario',
				'USER_DEBUG [9]|DEBUG|75x FAIL: broken'
			].join('\n')
		];
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});

		const results = await runSection75();

		expect(results['section-75'].result).toBe('FAIL');
	});
});

describe('log-fingerprint flood-control section (66)', () =>
{
	// Launch + verify section with NO CMDT fixture: publish fingerprinted entries via the global
	// withFingerprint API, wait for LogEntryEvent__e delivery, then verify the persisted
	// detail/rollup shape. The 30s wait is stubbed to fire immediately so the unit test stays fast.
	// The mock returns N PASS lines per script call (launch 2 + verify 8 = 10), so the aggregate
	// score can be asserted and the absence of any fixture deploy confirmed.
	function mockPassCounts(passCounts)
	{
		const outputs = passCounts.map((count, scriptIndex) => Array.from({length: count}, (_, i) => `USER_DEBUG [5]|DEBUG|q${scriptIndex}${i} PASS: scenario`).join('\n'));
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});
	}

	beforeEach(() =>
	{
		jest.clearAllMocks();
		jest.spyOn(global, 'setTimeout').mockImplementation((fn) =>
		{
			fn();
			return 0;
		});
	});

	afterEach(() =>
	{
		global.setTimeout.mockRestore();
	});

	it('section 66 aggregates 10 passes from launch + verify and deploys no fixture', async() =>
	{
		mockPassCounts([
			2,
			8
		]);

		const results = await runSection66();

		expect(results['section-66'].result).toBe('PASS');
		expect(results['section-66'].score).toBe('10/10');
		expect(deployCmdtState).not.toHaveBeenCalled();
	});

	it('section 66 marks FAIL when the verify under-passes', async() =>
	{
		mockPassCounts([
			2,
			7
		]);

		const results = await runSection66();

		expect(results['section-66'].result).toBe('FAIL');
		expect(results['section-66'].score).toBe('9/10');
	});

	it('section 66 marks FAIL when a script reports a failure even at full pass count', async() =>
	{
		const verifyLines = Array.from({length: 8}, (_, i) => `USER_DEBUG [5]|DEBUG|66b-${i} PASS: scenario`);
		verifyLines.push('USER_DEBUG [9]|DEBUG|66b-x FAIL: broken');
		const outputs = [
			[
				'USER_DEBUG [5]|DEBUG|66-launch-emit PASS: scenario',
				'USER_DEBUG [5]|DEBUG|66-launch-handoff PASS: scenario'
			].join('\n'),
			verifyLines.join('\n')
		];
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});

		const results = await runSection66();

		expect(results['section-66'].result).toBe('FAIL');
	});
});

describe('framework-wide bypass audit section (65)', () =>
{
	// Launch + verify split: the launch half exercises the four bypass surfaces and
	// persists a Foobar__c handoff (2 PASS incl. the 65f flag check); the verify half
	// polls for the object-qualified audit targets + flood-control shape (6 PASS).
	// The 30s persistence wait is stubbed to fire immediately.
	function mockPassCounts(passCounts)
	{
		const outputs = passCounts.map((count, scriptIndex) => Array.from({length: count}, (_, i) => `USER_DEBUG [5]|DEBUG|q${scriptIndex}${i} PASS: scenario`).join('\n'));
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});
	}

	beforeEach(() =>
	{
		jest.clearAllMocks();
		jest.spyOn(global, 'setTimeout').mockImplementation((fn) =>
		{
			fn();
			return 0;
		});
	});

	afterEach(() =>
	{
		global.setTimeout.mockRestore();
	});

	it('section 65 aggregates 8 passes from launch + verify and deploys no fixture', async() =>
	{
		mockPassCounts([
			2,
			6
		]);

		const results = await runSection65();

		expect(results['section-65'].result).toBe('PASS');
		expect(results['section-65'].score).toBe('8/8');
		expect(deployCmdtState).not.toHaveBeenCalled();
	});

	it('section 65 marks FAIL when the verify under-passes', async() =>
	{
		mockPassCounts([
			2,
			5
		]);

		const results = await runSection65();

		expect(results['section-65'].result).toBe('FAIL');
		expect(results['section-65'].score).toBe('7/8');
	});

	it('section 65 marks FAIL when a script reports a failure even at full pass count', async() =>
	{
		const verifyLines = Array.from({length: 6}, (_, i) => `USER_DEBUG [5]|DEBUG|65b-${i} PASS: scenario`);
		verifyLines.push('USER_DEBUG [9]|DEBUG|65b-x FAIL: broken');
		const outputs = [
			[
				'USER_DEBUG [5]|DEBUG|65-launch PASS: scenario',
				'USER_DEBUG [5]|DEBUG|65f PASS: scenario'
			].join('\n'),
			verifyLines.join('\n')
		];
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});

		const results = await runSection65();

		expect(results['section-65'].result).toBe('FAIL');
	});
});

describe('masking CMDT collision section (77)', () =>
{
	// Seeded + recovery section: the runner deploys the collision-clone fixture (an org-local
	// MaskingRule sharing the packaged MaskPaymentCard DeveloperName), proves framework inserts
	// survive on the engine fallback, deletes the clone, and proves fast-path recovery plus the
	// persisted collision WARN. The 15s log-persistence wait is stubbed to fire immediately.
	function mockPassCounts(passCounts)
	{
		const outputs = passCounts.map((count, scriptIndex) => Array.from({length: count}, (_, i) => `USER_DEBUG [5]|DEBUG|q${scriptIndex}${i} PASS: scenario`).join('\n'));
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});
	}

	beforeEach(() =>
	{
		jest.clearAllMocks();
		jest.spyOn(global, 'setTimeout').mockImplementation((fn) =>
		{
			fn();
			return 0;
		});
	});

	afterEach(() =>
	{
		global.setTimeout.mockRestore();
	});

	it('section 77 deploys the collision clone, deletes it, and aggregates 5 passes', async() =>
	{
		mockPassCounts([
			2,
			3
		]);

		const results = await runSection77();

		expect(results['section-77'].result).toBe('PASS');
		expect(results['section-77'].score).toBe('5/5');
		expect(deployCmdtState).toHaveBeenCalledWith('collision-clone');
		expect(deleteCmdtRecords).toHaveBeenCalledWith(['kern__MaskingRule.MaskPaymentCard']);
	});

	it('section 77 runs deploy → seeded script → delete → recovery script, with the 30s persistence wait', async() =>
	{
		mockPassCounts([
			2,
			3
		]);

		await runSection77();

		const deployOrder = deployCmdtState.mock.invocationCallOrder[0];
		const deleteOrder = deleteCmdtRecords.mock.invocationCallOrder[0];
		const scriptOrders = exec.mock.invocationCallOrder;
		expect(deployOrder).toBeLessThan(scriptOrders[0]);
		expect(scriptOrders[0]).toBeLessThan(deleteOrder);
		expect(deleteOrder).toBeLessThan(scriptOrders[1]);
		expect(global.setTimeout).toHaveBeenCalledWith(expect.any(Function), 30_000);
	});

	it('section 77 deletes the clone and surfaces the failure when the delete itself throws', async() =>
	{
		mockPassCounts([
			2,
			3
		]);
		deleteCmdtRecords.mockImplementationOnce(() =>
		{
			throw new Error('CMDT delete failed for kern__MaskingRule.MaskPaymentCard');
		});

		await expect(runSection77()).rejects.toThrow('CMDT delete failed');
		expect(deleteCmdtRecords).toHaveBeenCalled();
	});

	it('section 77 marks FAIL when the seeded half under-passes (the pre-fallback brick)', async() =>
	{
		mockPassCounts([
			0,
			3
		]);

		const results = await runSection77();

		expect(results['section-77'].result).toBe('FAIL');
		expect(results['section-77'].score).toBe('3/5');
	});

	it('section 77 marks FAIL when a script reports a failure even at full pass count', async() =>
	{
		const outputs = [
			[
				'USER_DEBUG [5]|DEBUG|77a PASS: scenario',
				'USER_DEBUG [5]|DEBUG|77b PASS: scenario'
			].join('\n'),
			[
				'USER_DEBUG [5]|DEBUG|77a PASS: scenario',
				'USER_DEBUG [5]|DEBUG|77b PASS: scenario',
				'USER_DEBUG [5]|DEBUG|77c PASS: scenario',
				'USER_DEBUG [9]|DEBUG|77x FAIL: broken'
			].join('\n')
		];
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, outputs.shift() || '');
		});

		const results = await runSection77();

		expect(results['section-77'].result).toBe('FAIL');
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
