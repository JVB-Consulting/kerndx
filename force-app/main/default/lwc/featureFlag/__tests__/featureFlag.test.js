// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the featureFlag LWC utility module — verifies the
 * bridge correctly forwards the flagName to `CTRL_FeatureFlag.isEnabled` and propagates
 * the boolean result to the caller.
 *
 * @author Jason van Beukering
 *
 * @date May 2026
 */

const mockIsEnabled = jest.fn();
jest.mock('@salesforce/apex/CTRL_FeatureFlag.isEnabled', () => ({
	__esModule: true, default: (...args) => mockIsEnabled(...args)
}), {virtual: true});

import {isFlagEnabled} from 'c/featureFlag';

describe('featureFlag bridge', () =>
{
	beforeEach(() =>
	{
		mockIsEnabled.mockReset();
	});

	it('should resolve isFlagEnabled(true) when controller returns true', async() =>
	{
		mockIsEnabled.mockResolvedValueOnce(true);

		const result = await isFlagEnabled('NewCheckout_Enabled');

		expect(result).toBe(true);
		expect(mockIsEnabled).toHaveBeenCalledWith({flagName: 'NewCheckout_Enabled'});
	});

	it('should resolve isFlagEnabled(false) when controller returns false', async() =>
	{
		mockIsEnabled.mockResolvedValueOnce(false);

		const result = await isFlagEnabled('Disabled_Flag');

		expect(result).toBe(false);
		expect(mockIsEnabled).toHaveBeenCalledWith({flagName: 'Disabled_Flag'});
	});

	it('should propagate controller errors', async() =>
	{
		const error = new Error('Network failure');
		mockIsEnabled.mockRejectedValueOnce(error);

		await expect(isFlagEnabled('Any_Flag')).rejects.toThrow('Network failure');
	});
});
