// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for moduleLightningMessageService LWC module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, July 2026
 */

// Import from the shared mock
import {
	APPLICATION_SCOPE, subscribe, unsubscribe, publish
} from 'lightning/messageService';

import initialiseLightningMessageModule, {
	subscribeToMessageChannel, initialiseSubscriptionService, publishMessage, initialisePublishService
} from 'c/moduleLightningMessageService';

describe('moduleLightningMessageService', () =>
{
	let mockComponent;
	let mockMessageContext;
	let mockMessageChannel;

	beforeEach(() =>
	{
		jest.clearAllMocks();

		mockMessageContext = {context: true};
		mockMessageChannel = {channel: true};

		mockComponent = {
			componentMessageContext: mockMessageContext, activeSubscriptions: [], addActiveSubscription: jest.fn((sub) =>
			{
				mockComponent.activeSubscriptions.push(sub);
				return mockComponent.activeSubscriptions.length;
			}), clearActiveSubscriptions: jest.fn(() =>
			{
				mockComponent.activeSubscriptions = [];
			}), consoleError: jest.fn()
		};

		// Default subscribe mock returns subscription object
		subscribe.mockImplementation(() => ({subscription: true}));
	});

	describe('subscribeToMessageChannel', () =>
	{
		it('should subscribe to message channel', () =>
		{
			const handler = jest.fn();

			const result = subscribeToMessageChannel(mockMessageContext, mockMessageChannel, handler);

			expect(subscribe).toHaveBeenCalledWith(mockMessageContext, mockMessageChannel, expect.any(Function), null);
			expect(result).toEqual({subscription: true});
		});

		it('should subscribe with application scope when specified', () =>
		{
			const handler = jest.fn();

			subscribeToMessageChannel(mockMessageContext, mockMessageChannel, handler, true);

			expect(subscribe).toHaveBeenCalledWith(mockMessageContext, mockMessageChannel, expect.any(Function), {scope: APPLICATION_SCOPE});
		});

		it('should call handler when message is received', () =>
		{
			const handler = jest.fn();
			subscribe.mockImplementation((ctx, ch, callback) =>
			{
				// Simulate receiving a message
				callback({data: 'test'});
				return {subscription: true};
			});

			subscribeToMessageChannel(mockMessageContext, mockMessageChannel, handler);

			expect(handler).toHaveBeenCalledWith({data: 'test'});
		});

		it('should throw error when messageContext is null', () =>
		{
			expect(() => subscribeToMessageChannel(null, mockMessageChannel, jest.fn()))
			.toThrow('Error: messageContext is null');
		});

		it('should throw error when messageContext is undefined', () =>
		{
			expect(() => subscribeToMessageChannel(undefined, mockMessageChannel, jest.fn()))
			.toThrow('Error: messageContext is undefined');
		});

		it('should throw error when messageChannel is null', () =>
		{
			expect(() => subscribeToMessageChannel(mockMessageContext, null, jest.fn()))
			.toThrow('Error: messageChannel is null');
		});

		it('should throw error when messageChannel is undefined', () =>
		{
			expect(() => subscribeToMessageChannel(mockMessageContext, undefined, jest.fn()))
			.toThrow('Error: messageChannel is undefined');
		});

		it('should throw error when handler is null', () =>
		{
			expect(() => subscribeToMessageChannel(mockMessageContext, mockMessageChannel, null))
			.toThrow('Error: handler is null');
		});

		it('should throw error when handler is undefined', () =>
		{
			expect(() => subscribeToMessageChannel(mockMessageContext, mockMessageChannel, undefined))
			.toThrow('Error: handler is undefined');
		});
	});

	describe('publishMessage', () =>
	{
		it('should publish message to channel', () =>
		{
			const payload = {data: 'test payload'};

			publishMessage(mockMessageContext, mockMessageChannel, payload);

			expect(publish).toHaveBeenCalledWith(mockMessageContext, mockMessageChannel, payload);
		});

		it('should throw error when messageContext is null', () =>
		{
			expect(() => publishMessage(null, mockMessageChannel, {}))
			.toThrow('Error: messageContext is null');
		});

		it('should throw error when messageContext is undefined', () =>
		{
			expect(() => publishMessage(undefined, mockMessageChannel, {}))
			.toThrow('Error: messageContext is undefined');
		});

		it('should throw error when messageChannel is null', () =>
		{
			expect(() => publishMessage(mockMessageContext, null, {}))
			.toThrow('Error: messageChannel is null');
		});

		it('should throw error when messageChannel is undefined', () =>
		{
			expect(() => publishMessage(mockMessageContext, undefined, {}))
			.toThrow('Error: messageChannel is undefined');
		});
	});

	describe('initialiseSubscriptionService', () =>
	{
		it('should add addMessageChannelSubscription method to component', () =>
		{
			initialiseSubscriptionService(mockComponent);
			expect(typeof mockComponent.addMessageChannelSubscription).toBe('function');
		});

		it('should add clearSubscriptions method by default', () =>
		{
			initialiseSubscriptionService(mockComponent);
			expect(typeof mockComponent.clearSubscriptions).toBe('function');
		});

		it('should not add clearSubscriptions when initialiseClear is false', () =>
		{
			initialiseSubscriptionService(mockComponent, false);
			expect(mockComponent.clearSubscriptions).toBeUndefined();
		});

		it('should subscribe and track subscription', () =>
		{
			const callback = jest.fn();
			initialiseSubscriptionService(mockComponent);

			const count = mockComponent.addMessageChannelSubscription(mockMessageChannel, callback);

			expect(count).toBe(1);
			expect(mockComponent.addActiveSubscription).toHaveBeenCalledWith({subscription: true});
		});

		it('should handle subscription error and re-throw', () =>
		{
			mockComponent.componentMessageContext = null;
			initialiseSubscriptionService(mockComponent);

			expect(() => mockComponent.addMessageChannelSubscription(mockMessageChannel, jest.fn()))
			.toThrow('Error: messageContext is null');

			expect(mockComponent.consoleError).toHaveBeenCalled();
		});

		describe('clearSubscriptions', () =>
		{
			it('should unsubscribe from all active subscriptions', () =>
			{
				initialiseSubscriptionService(mockComponent);

				// Add some subscriptions
				mockComponent.addMessageChannelSubscription(mockMessageChannel, jest.fn());
				mockComponent.addMessageChannelSubscription(mockMessageChannel, jest.fn());

				mockComponent.clearSubscriptions();

				expect(unsubscribe).toHaveBeenCalledTimes(2);
			});

			it('should clear active subscriptions list', () =>
			{
				initialiseSubscriptionService(mockComponent);

				mockComponent.addMessageChannelSubscription(mockMessageChannel, jest.fn());
				mockComponent.clearSubscriptions();

				expect(mockComponent.clearActiveSubscriptions).toHaveBeenCalled();
			});

			it('should return the number of remaining subscriptions', () =>
			{
				initialiseSubscriptionService(mockComponent);

				mockComponent.addMessageChannelSubscription(mockMessageChannel, jest.fn());
				// After clearActiveSubscriptions, length will be 0
				const count = mockComponent.clearSubscriptions();

				expect(count).toBe(0);
			});
		});
	});

	describe('initialisePublishService', () =>
	{
		it('should add publishLightningMessage method to component', () =>
		{
			initialisePublishService(mockComponent);
			expect(typeof mockComponent.publishLightningMessage).toBe('function');
		});

		it('should publish message and return true on success', () =>
		{
			initialisePublishService(mockComponent);
			const payload = {data: 'test'};

			const result = mockComponent.publishLightningMessage(mockMessageChannel, payload);

			expect(result).toBe(true);
			expect(publish).toHaveBeenCalledWith(mockMessageContext, mockMessageChannel, payload);
		});

		it('should use empty object as default payload', () =>
		{
			initialisePublishService(mockComponent);

			mockComponent.publishLightningMessage(mockMessageChannel);

			expect(publish).toHaveBeenCalledWith(mockMessageContext, mockMessageChannel, {});
		});

		it('should handle publish error and re-throw', () =>
		{
			mockComponent.componentMessageContext = null;
			initialisePublishService(mockComponent);

			expect(() => mockComponent.publishLightningMessage(mockMessageChannel))
			.toThrow('Error: messageContext is null');

			expect(mockComponent.consoleError).toHaveBeenCalled();
		});
	});

	describe('initialiseLightningMessageModule (default export)', () =>
	{
		it('should add all LMS methods to component', () =>
		{
			initialiseLightningMessageModule(mockComponent);

			expect(typeof mockComponent.addMessageChannelSubscription).toBe('function');
			expect(typeof mockComponent.publishLightningMessage).toBe('function');
			expect(typeof mockComponent.clearSubscriptions).toBe('function');
		});

		it('should allow subscription and publishing to work together', () =>
		{
			initialiseLightningMessageModule(mockComponent);

			// Subscribe
			const callback = jest.fn();
			mockComponent.addMessageChannelSubscription(mockMessageChannel, callback);

			// Publish
			const success = mockComponent.publishLightningMessage(mockMessageChannel, {message: 'hello'});

			expect(success).toBe(true);
			expect(subscribe).toHaveBeenCalled();
			expect(publish).toHaveBeenCalled();
		});

		it('wires clearSubscriptions exactly once during full module activation', () =>
		{
			const wiredHandlers = [];
			Object.defineProperty(mockComponent, 'clearSubscriptions', {
				configurable: true, get()
				{
					return wiredHandlers[wiredHandlers.length - 1];
				}, set(handler)
				{
					wiredHandlers.push(handler);
				}
			});

			initialiseLightningMessageModule(mockComponent);

			expect(wiredHandlers).toHaveLength(1);
			expect(typeof mockComponent.clearSubscriptions).toBe('function');
		});

		it('should allow clearing subscriptions', () =>
		{
			initialiseLightningMessageModule(mockComponent);

			mockComponent.addMessageChannelSubscription(mockMessageChannel, jest.fn());
			mockComponent.addMessageChannelSubscription(mockMessageChannel, jest.fn());

			const remainingCount = mockComponent.clearSubscriptions();

			expect(remainingCount).toBe(0);
			expect(unsubscribe).toHaveBeenCalledTimes(2);
		});
	});
});
