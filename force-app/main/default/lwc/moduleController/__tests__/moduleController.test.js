// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for moduleController LWC module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, May 2026
 */

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
}), {virtual: true});

// Mock ShowToastEvent
const mockShowToastEventInstances = [];
jest.mock('lightning/platformShowToastEvent', () => ({
	ShowToastEvent: class MockShowToastEvent
	{
		constructor(config)
		{
			this.title = config.title;
			this.message = config.message;
			this.variant = config.variant;
			mockShowToastEventInstances.push(this);
		}
	}
}), {virtual: true});

import initialiseControllerModule, {
	initialiseCallControllerMethod, initialiseHandleWireResponse, FAILED_CONTROLLER_CALL_ERROR, CALL_CONTROLLER_METHOD_NAME, HANDLE_WIRE_RESPONSE_METHOD_NAME
} from 'c/moduleController';

describe('moduleController', () =>
{
	let mockComponent;

	beforeEach(() =>
	{
		jest.clearAllMocks();
		mockShowToastEventInstances.length = 0;
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

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Error');
			expect(toastEvent.variant).toBe('error');
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

		it('should handle string error message', async() =>
		{
			const mockController = jest.fn().mockRejectedValue('String error');
			initialiseCallControllerMethod(mockComponent);

			await mockComponent.callControllerMethod(mockController);

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.message).toBe('String error');
		});

		it('should handle error with body.message (Apex style)', async() =>
		{
			const apexError = {body: {message: 'Apex error message'}};
			const mockController = jest.fn().mockRejectedValue(apexError);
			initialiseCallControllerMethod(mockComponent);

			await mockComponent.callControllerMethod(mockController);

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.message).toBe('Apex error message');
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

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Error');
			expect(toastEvent.variant).toBe('error');
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
