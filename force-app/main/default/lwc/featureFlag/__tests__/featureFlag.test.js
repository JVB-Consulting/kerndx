// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the featureFlag LWC utility module — verifies the
 * bridge forwards the flagName to `CTRL_FeatureFlag.isEnabled` and propagates the
 * boolean result to the caller.
 *
 * The @lwc/jest-transformer rewrites `import isEnabled from '@salesforce/apex/...'`
 * into a try/catch whose catch arm reads `global.__lwcJestMock_isEnabled || function
 * isEnabled() { return Promise.resolve(); }`. Pre-setting that global (truthy arm) and
 * deleting it (default-stub arm), each with a fresh isolated module load, exercises both
 * sides of the generated expression — the same pattern viewRecord uses.
 *
 * @author Jason van Beukering
 *
 * @date May 2026
 */

const APEX_GLOBAL_KEY = '__lwcJestMock_isEnabled';

describe('featureFlag bridge', () =>
{
	afterEach(() =>
	{
		delete global[APEX_GLOBAL_KEY];
	});

	/**
	 * @description Loads c/featureFlag in an isolated module registry so the
	 * transformer's apex try/catch runs fresh against the current global stub state.
	 * @returns {Function} The isFlagEnabled bridge.
	 */
	function loadBridge()
	{
		let bridge;
		jest.isolateModules(() =>
		{
			bridge = require('c/featureFlag').isFlagEnabled;
		});
		return bridge;
	}

	it('should forward the flag name and resolve true when the controller returns true', async() =>
	{
		const mockIsEnabled = jest.fn().mockResolvedValue(true);
		global[APEX_GLOBAL_KEY] = mockIsEnabled;
		const isFlagEnabled = loadBridge();

		const result = await isFlagEnabled('NewCheckout_Enabled');

		expect(result).toBe(true);
		expect(mockIsEnabled).toHaveBeenCalledWith({flagName: 'NewCheckout_Enabled'});
	});

	it('should resolve false when the controller returns false', async() =>
	{
		const mockIsEnabled = jest.fn().mockResolvedValue(false);
		global[APEX_GLOBAL_KEY] = mockIsEnabled;
		const isFlagEnabled = loadBridge();

		const result = await isFlagEnabled('Disabled_Flag');

		expect(result).toBe(false);
		expect(mockIsEnabled).toHaveBeenCalledWith({flagName: 'Disabled_Flag'});
	});

	it('should propagate controller errors to the caller', async() =>
	{
		const mockIsEnabled = jest.fn().mockRejectedValue(new Error('Network failure'));
		global[APEX_GLOBAL_KEY] = mockIsEnabled;
		const isFlagEnabled = loadBridge();

		await expect(isFlagEnabled('Any_Flag')).rejects.toThrow('Network failure');
	});

	it('should fall back to the transformer default stub when no global mock is registered', async() =>
	{
		delete global[APEX_GLOBAL_KEY];
		const isFlagEnabled = loadBridge();

		await expect(isFlagEnabled('Any_Flag')).resolves.toBeUndefined();
	});
});
