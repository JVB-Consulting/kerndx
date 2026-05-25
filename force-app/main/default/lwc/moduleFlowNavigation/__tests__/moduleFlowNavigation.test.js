// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for moduleFlowNavigation LWC module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, May 2026
 */

// Mock the lightning/flowSupport events - use class constructors
jest.mock('lightning/flowSupport', () => ({
	FlowNavigationNextEvent: class MockFlowNavigationNextEvent
	{
	}, FlowNavigationBackEvent: class MockFlowNavigationBackEvent
	{
	}, FlowNavigationFinishEvent: class MockFlowNavigationFinishEvent
	{
	}
}), {virtual: true});

import initialiseFlowNavigationModule, {
	initialiseDispatchFlowNextEventMethod, initialiseDispatchFlowBackEventMethod, initialiseDispatchFlowFinishEventMethod
} from 'c/moduleFlowNavigation';

describe('moduleFlowNavigation', () =>
{
	let mockComponent;

	beforeEach(() =>
	{
		jest.clearAllMocks();
		mockComponent = {
			dispatchEvent: jest.fn()
		};
	});

	describe('initialiseDispatchFlowNextEventMethod', () =>
	{
		it('should add dispatchFlowNextEvent method to component', () =>
		{
			initialiseDispatchFlowNextEventMethod(mockComponent);
			expect(typeof mockComponent.dispatchFlowNextEvent).toBe('function');
		});

		it('should dispatch FlowNavigationNextEvent when called', () =>
		{
			initialiseDispatchFlowNextEventMethod(mockComponent);
			mockComponent.dispatchFlowNextEvent();

			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(1);
			// Verify the event type passed to dispatchEvent
			const dispatchedEvent = mockComponent.dispatchEvent.mock.calls[0][0];
			expect(dispatchedEvent.constructor.name).toBe('MockFlowNavigationNextEvent');
		});
	});

	describe('initialiseDispatchFlowBackEventMethod', () =>
	{
		it('should add dispatchFlowBackEvent method to component', () =>
		{
			initialiseDispatchFlowBackEventMethod(mockComponent);
			expect(typeof mockComponent.dispatchFlowBackEvent).toBe('function');
		});

		it('should dispatch FlowNavigationBackEvent when called', () =>
		{
			initialiseDispatchFlowBackEventMethod(mockComponent);
			mockComponent.dispatchFlowBackEvent();

			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(1);
			const dispatchedEvent = mockComponent.dispatchEvent.mock.calls[0][0];
			expect(dispatchedEvent.constructor.name).toBe('MockFlowNavigationBackEvent');
		});
	});

	describe('initialiseDispatchFlowFinishEventMethod', () =>
	{
		it('should add dispatchFlowFinishEvent method to component', () =>
		{
			initialiseDispatchFlowFinishEventMethod(mockComponent);
			expect(typeof mockComponent.dispatchFlowFinishEvent).toBe('function');
		});

		it('should dispatch FlowNavigationFinishEvent when called', () =>
		{
			initialiseDispatchFlowFinishEventMethod(mockComponent);
			mockComponent.dispatchFlowFinishEvent();

			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(1);
			const dispatchedEvent = mockComponent.dispatchEvent.mock.calls[0][0];
			expect(dispatchedEvent.constructor.name).toBe('MockFlowNavigationFinishEvent');
		});
	});

	describe('initialiseFlowNavigationModule (default export)', () =>
	{
		it('should add all three flow navigation methods to component', () =>
		{
			initialiseFlowNavigationModule(mockComponent);

			expect(typeof mockComponent.dispatchFlowNextEvent).toBe('function');
			expect(typeof mockComponent.dispatchFlowBackEvent).toBe('function');
			expect(typeof mockComponent.dispatchFlowFinishEvent).toBe('function');
		});

		it('should allow all methods to work correctly', () =>
		{
			initialiseFlowNavigationModule(mockComponent);

			// Test next
			mockComponent.dispatchFlowNextEvent();
			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(1);

			// Test back
			mockComponent.dispatchFlowBackEvent();
			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(2);

			// Test finish
			mockComponent.dispatchFlowFinishEvent();
			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(3);
		});
	});
});
