// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for moduleController LWC module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, July 2026
 */

// Byte-real label mocks (values mirror CustomLabels.labels-meta.xml) so the
// display-string assertions below exercise the shipped copy — live again now that
// moduleController imports these labels directly.
jest.mock('@salesforce/label/c.ModuleNotification_ErrorTitle', () => ({default: 'Error'}), {virtual: true});
jest.mock('@salesforce/label/c.ModuleController_FailedControllerCall', () => ({default: 'Failed controller call'}), {virtual: true});

// Mock utilitySystem - must be before imports
jest.mock('c/utilitySystem', () => ({
	reduceErrors: jest.fn((error) =>
	{
		if(typeof error === 'string')
		{
			return error;
		}
		if(error?.body?.message)
		{
			return error.body.message;
		}
		if(error?.message)
		{
			return error.message;
		}
		return 'Unknown error';
	})
}));

// lightning/platformShowToastEvent is deliberately NOT jest.mock'd: the sfdx-lwc-jest stub
// dispatches a CustomEvent('lightning__showtoast') carrying the toast config in `detail`, so the
// tests assert on the dispatched event's shape instead. Mocking this module here is unsafe:
// jest keys an explicit mock by a raw-specifier module id at registration, but once ANY earlier
// suite in the same worker has loaded the real c/moduleController chain, the run-shared resolver
// cache makes the source's lookup resolve to the absolute stub path — the ids no longer match
// and the mock silently stops intercepting (root-caused 2026-07-07; this was the intermittent
// full-suite failure of the four error-path tests below).
const dispatchedToast = (component, callIndex = 0) =>
{
	const event = component.dispatchEvent.mock.calls[callIndex][0];
	expect(event.type).toBe('lightning__showtoast');
	return event.detail;
};

import initialiseControllerModule, {
	initialiseCallControllerMethod, initialiseHandleWireResponse, FAILED_CONTROLLER_CALL_ERROR, CALL_CONTROLLER_METHOD_NAME, HANDLE_WIRE_RESPONSE_METHOD_NAME
} from 'c/moduleController';

describe('moduleController', () =>
{
	let mockComponent;

	beforeEach(() =>
	{
		jest.clearAllMocks();
		mockComponent = {
			dispatchEvent: jest.fn(), consoleError: jest.fn()
		};
	});

	describe('constants', () =>
	{
		it('should export FAILED_CONTROLLER_CALL_ERROR', () =>
		{
			expect(FAILED_CONTROLLER_CALL_ERROR).toBe('Failed controller call');
		});

		it('should export CALL_CONTROLLER_METHOD_NAME', () =>
		{
			expect(CALL_CONTROLLER_METHOD_NAME).toBe('callControllerMethod');
		});

		it('should export HANDLE_WIRE_RESPONSE_METHOD_NAME', () =>
		{
			expect(HANDLE_WIRE_RESPONSE_METHOD_NAME).toBe('handleWireResponse');
		});
	});

	describe('initialiseCallControllerMethod', () =>
	{
		it('should add callControllerMethod to component', () =>
		{
			initialiseCallControllerMethod(mockComponent);
			expect(typeof mockComponent.callControllerMethod).toBe('function');
		});

		it('should call controller method with parameters', async() =>
		{
			const mockController = jest.fn().mockResolvedValue('success');
			initialiseCallControllerMethod(mockComponent);

			const result = await mockComponent.callControllerMethod(mockController, {param: 'value'});

			expect(mockController).toHaveBeenCalledWith({param: 'value'});
			expect(result).toBe('success');
		});

		it('should use empty object as default parameters', async() =>
		{
			const mockController = jest.fn().mockResolvedValue('success');
			initialiseCallControllerMethod(mockComponent);

			await mockComponent.callControllerMethod(mockController);

			expect(mockController).toHaveBeenCalledWith({});
		});

		it('should handle controller error without throwing', async() =>
		{
			const testError = new Error('Controller error');
			const mockController = jest.fn().mockRejectedValue(testError);
			initialiseCallControllerMethod(mockComponent);

			const result = await mockComponent.callControllerMethod(mockController);

			expect(mockComponent.consoleError).toHaveBeenCalledWith(testError, 'callControllerMethod: ');
			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(1);
			expect(result).toBeUndefined();

			const toastDetail = dispatchedToast(mockComponent);
			expect(toastDetail.title).toBe('Error');
			expect(toastDetail.variant).toBe('error');
		});

		it('should throw error when isThrow is true', async() =>
		{
			const testError = new Error('Controller error');
			const mockController = jest.fn().mockRejectedValue(testError);
			initialiseCallControllerMethod(mockComponent);

			await expect(mockComponent.callControllerMethod(mockController, {}, true)).rejects.toThrow(FAILED_CONTROLLER_CALL_ERROR);

			expect(mockComponent.consoleError).toHaveBeenCalled();
			expect(mockComponent.dispatchEvent).toHaveBeenCalled();
		});

		it('preserves the original error as the cause of the thrown failure', async() =>
		{
			const testError = new Error('Controller error');
			const mockController = jest.fn().mockRejectedValue(testError);
			initialiseCallControllerMethod(mockComponent);

			let caught;
			try
			{
				await mockComponent.callControllerMethod(mockController, {}, true);
			}
			catch(thrown)
			{
				caught = thrown;
			}

			expect(caught).toBeInstanceOf(Error);
			expect(caught.message).toBe(FAILED_CONTROLLER_CALL_ERROR);
			expect(caught.cause).toBe(testError);
		});

		it('should handle string error message', async() =>
		{
			const mockController = jest.fn().mockRejectedValue('String error');
			initialiseCallControllerMethod(mockComponent);

			await mockComponent.callControllerMethod(mockController);

			const toastDetail = dispatchedToast(mockComponent);
			expect(toastDetail.message).toBe('String error');
		});

		it('should handle error with body.message (Apex style)', async() =>
		{
			const apexError = {body: {message: 'Apex error message'}};
			const mockController = jest.fn().mockRejectedValue(apexError);
			initialiseCallControllerMethod(mockComponent);

			await mockComponent.callControllerMethod(mockController);

			const toastDetail = dispatchedToast(mockComponent);
			expect(toastDetail.message).toBe('Apex error message');
		});
	});

	describe('initialiseHandleWireResponse', () =>
	{
		it('should add handleWireResponse to component', () =>
		{
			initialiseHandleWireResponse(mockComponent);
			expect(typeof mockComponent.handleWireResponse).toBe('function');
		});

		it('should return data when data is present', () =>
		{
			initialiseHandleWireResponse(mockComponent);
			const testData = {
				records: [
					1,
					2,
					3
				]
			};

			const result = mockComponent.handleWireResponse({data: testData, error: undefined});

			expect(result).toBe(testData);
			expect(mockComponent.consoleError).not.toHaveBeenCalled();
			expect(mockComponent.dispatchEvent).not.toHaveBeenCalled();
		});

		it('should handle error and show toast', () =>
		{
			initialiseHandleWireResponse(mockComponent);
			const testError = new Error('Wire error');

			const result = mockComponent.handleWireResponse({data: undefined, error: testError});

			expect(result).toBeUndefined();
			expect(mockComponent.consoleError).toHaveBeenCalledWith(testError, 'handleWireResponse: ');
			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(1);

			const toastDetail = dispatchedToast(mockComponent);
			expect(toastDetail.title).toBe('Error');
			expect(toastDetail.variant).toBe('error');
		});

		it('should return undefined when neither data nor error', () =>
		{
			initialiseHandleWireResponse(mockComponent);

			const result = mockComponent.handleWireResponse({data: undefined, error: undefined});

			expect(result).toBeUndefined();
			expect(mockComponent.consoleError).not.toHaveBeenCalled();
		});

		it('should prioritize error over data', () =>
		{
			initialiseHandleWireResponse(mockComponent);
			const testError = new Error('Wire error');
			const testData = {records: []};

			const result = mockComponent.handleWireResponse({data: testData, error: testError});

			// Error is checked first, so data is not returned
			expect(result).toBeUndefined();
			expect(mockComponent.consoleError).toHaveBeenCalled();
		});
	});

	describe('initialiseControllerModule (default export)', () =>
	{
		it('should add both controller methods to component', () =>
		{
			initialiseControllerModule(mockComponent);

			expect(typeof mockComponent.callControllerMethod).toBe('function');
			expect(typeof mockComponent.handleWireResponse).toBe('function');
		});

		it('should allow callControllerMethod to work correctly', async() =>
		{
			const mockController = jest.fn().mockResolvedValue('result');
			initialiseControllerModule(mockComponent);

			const result = await mockComponent.callControllerMethod(mockController);

			expect(result).toBe('result');
		});

		it('should allow handleWireResponse to work correctly', () =>
		{
			initialiseControllerModule(mockComponent);
			const testData = {value: 'test'};

			const result = mockComponent.handleWireResponse({data: testData});

			expect(result).toBe(testData);
		});
	});
});
