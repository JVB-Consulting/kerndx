// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for baseComponent LWC
 *
 * @author Jason van Beukering
 *
 * @date December 2025, May 2026
 */

		// Create mock functions that can be tracked
const mockDebug = jest.fn();
const mockInfo = jest.fn();
const mockWarn = jest.fn();
const mockError = jest.fn();

// Mock utilityLogger - use inline object to avoid hoisting issues
jest.mock('c/utilityLogger', () => ({
	__esModule: true, default: {
		debug: (...args) => mockDebug(...args), info: (...args) => mockInfo(...args), warn: (...args) => mockWarn(...args), error: (...args) => mockError(...args)
	}
}), {virtual: true});

// Mock utilityString
jest.mock('c/utilityString', () => ({
	formatTemplateString: jest.fn((template, substitutes) =>
	{
		let result = template || '';
		for(let i = 0; i < substitutes.length; i++)
		{
			result = result.replace(`{${i}}`, substitutes[i]);
		}
		return result;
	})
}), {virtual: true});

// Mock utilitySystem
jest.mock('c/utilitySystem', () => ({
	setPropertyOnObject: jest.fn((obj, key, value) =>
	{
		obj[key] = value;
		return obj;
	})
}), {virtual: true});

// Mock spinner.html
jest.mock('../spinner.html', () => ({}), {virtual: true});

import {createElement} from 'lwc';
import BaseComponent from 'c/baseComponent';

// Import exported constants for testing
import {
	CUSTOM_NOTIFICATION_UNINITIALISED_ERROR, CUSTOM_NOTIFICATION_FACTORY_UNINITIALISED_ERROR, SHOW_INFO_TOAST_UNINITIALISED_ERROR, SHOW_WARNING_TOAST_UNINITIALISED_ERROR,
	SHOW_ERROR_TOAST_UNINITIALISED_ERROR, SHOW_SUCCESS_TOAST_UNINITIALISED_ERROR, REDIRECT_TO_RECORD_PAGE_UNINITIALISED_ERROR, GENERATE_RECORD_PAGE_URL_UNINITIALISED_ERROR,
	CLEAR_SUBSCRIPTIONS_UNINITIALISED_ERROR, PUBLISH_LIGHTNING_MESSAGE_UNINITIALISED_ERROR, ADD_SUBSCRIPTION_UNINITIALISED_ERROR, CALL_CONTROLLER_UNINITIALISED_ERROR,
	HANDLE_WIRE_RESPONSE_UNINITIALISED_ERROR, FLOW_NAVIGATION_NEXT_EVENT_UNINITIALISED_ERROR, FLOW_NAVIGATION_BACK_EVENT_UNINITIALISED_ERROR,
	FLOW_NAVIGATION_FINISH_EVENT_UNINITIALISED_ERROR
} from 'c/baseComponent';

describe('baseComponent', () =>
{
	let element;

	beforeEach(() =>
	{
		jest.clearAllMocks();
		element = createElement('c-base-component', {is: BaseComponent});
		document.body.appendChild(element);
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
	});

	describe('error constants', () =>
	{
		it('should export CUSTOM_NOTIFICATION_UNINITIALISED_ERROR', () =>
		{
			expect(CUSTOM_NOTIFICATION_UNINITIALISED_ERROR).toContain('notification');
			expect(CUSTOM_NOTIFICATION_UNINITIALISED_ERROR).toContain('customNotification');
		});

		it('should export CUSTOM_NOTIFICATION_FACTORY_UNINITIALISED_ERROR', () =>
		{
			expect(CUSTOM_NOTIFICATION_FACTORY_UNINITIALISED_ERROR).toContain('notification');
			expect(CUSTOM_NOTIFICATION_FACTORY_UNINITIALISED_ERROR).toContain('customNotificationFactory');
		});

		it('should export SHOW_INFO_TOAST_UNINITIALISED_ERROR', () =>
		{
			expect(SHOW_INFO_TOAST_UNINITIALISED_ERROR).toContain('notification');
			expect(SHOW_INFO_TOAST_UNINITIALISED_ERROR).toContain('showInfoToast');
		});

		it('should export SHOW_WARNING_TOAST_UNINITIALISED_ERROR', () =>
		{
			expect(SHOW_WARNING_TOAST_UNINITIALISED_ERROR).toContain('notification');
			expect(SHOW_WARNING_TOAST_UNINITIALISED_ERROR).toContain('showWarningToast');
		});

		it('should export SHOW_ERROR_TOAST_UNINITIALISED_ERROR', () =>
		{
			expect(SHOW_ERROR_TOAST_UNINITIALISED_ERROR).toContain('notification');
			expect(SHOW_ERROR_TOAST_UNINITIALISED_ERROR).toContain('showErrorToast');
		});

		it('should export SHOW_SUCCESS_TOAST_UNINITIALISED_ERROR', () =>
		{
			expect(SHOW_SUCCESS_TOAST_UNINITIALISED_ERROR).toContain('notification');
			expect(SHOW_SUCCESS_TOAST_UNINITIALISED_ERROR).toContain('showSuccessToast');
		});

		it('should export REDIRECT_TO_RECORD_PAGE_UNINITIALISED_ERROR', () =>
		{
			expect(REDIRECT_TO_RECORD_PAGE_UNINITIALISED_ERROR).toContain('navigation');
			expect(REDIRECT_TO_RECORD_PAGE_UNINITIALISED_ERROR).toContain('redirectToRecordPage');
		});

		it('should export GENERATE_RECORD_PAGE_URL_UNINITIALISED_ERROR', () =>
		{
			expect(GENERATE_RECORD_PAGE_URL_UNINITIALISED_ERROR).toContain('navigation');
			expect(GENERATE_RECORD_PAGE_URL_UNINITIALISED_ERROR).toContain('generateRecordPageURL');
		});

		it('should export CLEAR_SUBSCRIPTIONS_UNINITIALISED_ERROR', () =>
		{
			expect(CLEAR_SUBSCRIPTIONS_UNINITIALISED_ERROR).toContain('lightning-message');
			expect(CLEAR_SUBSCRIPTIONS_UNINITIALISED_ERROR).toContain('clearSubscriptions');
		});

		it('reports lightning-message module name when clearSubscriptions is called without activation', () =>
		{
			expect(CLEAR_SUBSCRIPTIONS_UNINITIALISED_ERROR).toContain('lightning-message');
			expect(CLEAR_SUBSCRIPTIONS_UNINITIALISED_ERROR).not.toContain('navigation');
		});

		it('should export PUBLISH_LIGHTNING_MESSAGE_UNINITIALISED_ERROR', () =>
		{
			expect(PUBLISH_LIGHTNING_MESSAGE_UNINITIALISED_ERROR).toContain('lightning-message');
			expect(PUBLISH_LIGHTNING_MESSAGE_UNINITIALISED_ERROR).toContain('publishLightningMessage');
		});

		it('should export ADD_SUBSCRIPTION_UNINITIALISED_ERROR', () =>
		{
			expect(ADD_SUBSCRIPTION_UNINITIALISED_ERROR).toContain('lightning-message');
			expect(ADD_SUBSCRIPTION_UNINITIALISED_ERROR).toContain('addMessageChannelSubscription');
		});

		it('should export CALL_CONTROLLER_UNINITIALISED_ERROR', () =>
		{
			expect(CALL_CONTROLLER_UNINITIALISED_ERROR).toContain('controller');
			expect(CALL_CONTROLLER_UNINITIALISED_ERROR).toContain('callControllerMethod');
		});

		it('should export HANDLE_WIRE_RESPONSE_UNINITIALISED_ERROR', () =>
		{
			expect(HANDLE_WIRE_RESPONSE_UNINITIALISED_ERROR).toContain('controller');
			expect(HANDLE_WIRE_RESPONSE_UNINITIALISED_ERROR).toContain('handleWireResponse');
		});

		it('should export FLOW_NAVIGATION_NEXT_EVENT_UNINITIALISED_ERROR', () =>
		{
			expect(FLOW_NAVIGATION_NEXT_EVENT_UNINITIALISED_ERROR).toContain('flow-navigation');
			expect(FLOW_NAVIGATION_NEXT_EVENT_UNINITIALISED_ERROR).toContain('dispatchFlowNextEvent');
		});

		it('should export FLOW_NAVIGATION_BACK_EVENT_UNINITIALISED_ERROR', () =>
		{
			expect(FLOW_NAVIGATION_BACK_EVENT_UNINITIALISED_ERROR).toContain('flow-navigation');
			expect(FLOW_NAVIGATION_BACK_EVENT_UNINITIALISED_ERROR).toContain('dispatchFlowBackEvent');
		});

		it('should export FLOW_NAVIGATION_FINISH_EVENT_UNINITIALISED_ERROR', () =>
		{
			expect(FLOW_NAVIGATION_FINISH_EVENT_UNINITIALISED_ERROR).toContain('flow-navigation');
			expect(FLOW_NAVIGATION_FINISH_EVENT_UNINITIALISED_ERROR).toContain('dispatchFlowFinishEvent');
		});
	});

	describe('navigation handlers (@api)', () =>
	{
		it('should have navigationHandler getter', () =>
		{
			// navigationHandler is @api so accessible
			expect(element.navigationHandler).toBeDefined();
		});

		it('should allow setting navigationHandler', () =>
		{
			const mockHandler = jest.fn();
			element.navigationHandler = mockHandler;
			expect(element.navigationHandler).toBe(mockHandler);
		});

		it('should have generateUrlHandler getter', () =>
		{
			expect(element.generateUrlHandler).toBeDefined();
		});

		it('should allow setting generateUrlHandler', () =>
		{
			const mockHandler = jest.fn();
			element.generateUrlHandler = mockHandler;
			expect(element.generateUrlHandler).toBe(mockHandler);
		});
	});

	describe('subscription management (@api)', () =>
	{
		it('should return activeSubscriptions via @api getter', () =>
		{
			expect(element.activeSubscriptions).toEqual([]);
		});

		it('should add subscription via @api addActiveSubscription', () =>
		{
			const subscription = {id: 'sub1'};
			const count = element.addActiveSubscription(subscription);

			expect(count).toBe(1);
			expect(element.activeSubscriptions).toContain(subscription);
		});

		it('should add multiple subscriptions', () =>
		{
			element.addActiveSubscription({id: 'sub1'});
			element.addActiveSubscription({id: 'sub2'});
			const count = element.addActiveSubscription({id: 'sub3'});

			expect(count).toBe(3);
			expect(element.activeSubscriptions).toHaveLength(3);
		});

		it('should clear subscriptions via @api clearActiveSubscriptions', () =>
		{
			element.addActiveSubscription({id: 'sub1'});
			element.addActiveSubscription({id: 'sub2'});

			element.clearActiveSubscriptions();

			expect(element.activeSubscriptions).toEqual([]);
		});

		it('should have componentMessageContext @api getter', () =>
		{
			// componentMessageContext returns undefined in test environment
			// since @wire(MessageContext) requires runtime context,
			// but the property should be accessible on the element
			// (verifying that accessing it doesn't throw)
			expect(() => element.componentMessageContext).not.toThrow();
			// The value is undefined because @wire doesn't populate in tests
			expect(element.componentMessageContext).toBeUndefined();
		});
	});

	describe('teardown operations (@api)', () =>
	{
		it('should add and execute teardown operation on disconnect', () =>
		{
			const teardownFn = jest.fn();
			element.addTearDownOperation(teardownFn);

			// Trigger disconnectedCallback by removing element
			document.body.removeChild(element);

			expect(teardownFn).toHaveBeenCalledTimes(1);
		});

		it('should execute multiple teardown operations in order', () =>
		{
			const order = [];
			const firstTeardown = jest.fn(() => order.push(1));
			const secondTeardown = jest.fn(() => order.push(2));
			const thirdTeardown = jest.fn(() => order.push(3));

			element.addTearDownOperation(firstTeardown);
			element.addTearDownOperation(secondTeardown);
			element.addTearDownOperation(thirdTeardown);

			document.body.removeChild(element);

			expect(order).toEqual([
				1,
				2,
				3
			]);
		});
	});

	describe('uninitialised notification methods (@api)', () =>
	{
		it('should log error when customNotification is called uninitialised', () =>
		{
			element.customNotification('Title', 'Message', 'info', [], 'dismissible');

			expect(mockError).toHaveBeenCalledWith(CUSTOM_NOTIFICATION_UNINITIALISED_ERROR, expect.objectContaining({title: 'Title', message: 'Message'}));
		});

		it('should log error when customNotificationFactory is called uninitialised', () =>
		{
			element.customNotificationFactory('info', 'dismissible');

			expect(mockError).toHaveBeenCalledWith(CUSTOM_NOTIFICATION_FACTORY_UNINITIALISED_ERROR, expect.objectContaining({variant: 'info', mode: 'dismissible'}));
		});

		it('should log error when showInfoToast is called uninitialised', () =>
		{
			element.showInfoToast('Info message', 'Info');

			expect(mockError).toHaveBeenCalledWith(SHOW_INFO_TOAST_UNINITIALISED_ERROR, expect.objectContaining({message: 'Info message', header: 'Info'}));
		});

		it('should log error when showWarningToast is called uninitialised', () =>
		{
			element.showWarningToast('Warning message', 'Warning');

			expect(mockError).toHaveBeenCalledWith(SHOW_WARNING_TOAST_UNINITIALISED_ERROR, expect.objectContaining({message: 'Warning message', header: 'Warning'}));
		});

		it('should log error when showErrorToast is called uninitialised', () =>
		{
			element.showErrorToast('Error message', 'Error');

			expect(mockError).toHaveBeenCalledWith(SHOW_ERROR_TOAST_UNINITIALISED_ERROR, expect.objectContaining({message: 'Error message', header: 'Error'}));
		});

		it('should log error when showSuccessToast is called uninitialised', () =>
		{
			element.showSuccessToast('Success message', 'Success');

			expect(mockError).toHaveBeenCalledWith(SHOW_SUCCESS_TOAST_UNINITIALISED_ERROR, expect.objectContaining({message: 'Success message', header: 'Success'}));
		});

		it('should use default parameters when customNotification is called with minimal args', () =>
		{
			element.customNotification('Title', 'Message');

			expect(mockError).toHaveBeenCalledWith(CUSTOM_NOTIFICATION_UNINITIALISED_ERROR, expect.objectContaining({variant: 'info', messageData: [], mode: 'dismissible'}));
		});

		it('should use default parameters when customNotificationFactory is called with no args', () =>
		{
			element.customNotificationFactory();

			expect(mockError).toHaveBeenCalledWith(CUSTOM_NOTIFICATION_FACTORY_UNINITIALISED_ERROR, expect.objectContaining({variant: 'info', mode: 'dismissible'}));
		});

		it('should use default header for showInfoToast', () =>
		{
			element.showInfoToast('message');

			expect(mockError).toHaveBeenCalledWith(SHOW_INFO_TOAST_UNINITIALISED_ERROR, expect.objectContaining({header: 'Info'}));
		});

		it('should use default header for showWarningToast', () =>
		{
			element.showWarningToast('message');

			expect(mockError).toHaveBeenCalledWith(SHOW_WARNING_TOAST_UNINITIALISED_ERROR, expect.objectContaining({header: 'Warning'}));
		});

		it('should use default header for showErrorToast', () =>
		{
			element.showErrorToast('message');

			expect(mockError).toHaveBeenCalledWith(SHOW_ERROR_TOAST_UNINITIALISED_ERROR, expect.objectContaining({header: 'Error'}));
		});

		it('should use default header for showSuccessToast', () =>
		{
			element.showSuccessToast('message');

			expect(mockError).toHaveBeenCalledWith(SHOW_SUCCESS_TOAST_UNINITIALISED_ERROR, expect.objectContaining({header: 'Success'}));
		});
	});

	describe('uninitialised navigation methods (@api)', () =>
	{
		it('should log error when redirectToRecordPage is called uninitialised', () =>
		{
			element.redirectToRecordPage('001xx000003ABCD');

			expect(mockError).toHaveBeenCalledWith(REDIRECT_TO_RECORD_PAGE_UNINITIALISED_ERROR, expect.objectContaining({recordId: '001xx000003ABCD'}));
		});

		it('should log error when generateRecordPageURL is called uninitialised', () =>
		{
			element.generateRecordPageURL('001xx000003ABCD');

			expect(mockError).toHaveBeenCalledWith(GENERATE_RECORD_PAGE_URL_UNINITIALISED_ERROR, expect.objectContaining({recordId: '001xx000003ABCD'}));
		});
	});

	describe('uninitialised lightning message methods (@api)', () =>
	{
		it('should log error when clearSubscriptions is called uninitialised', () =>
		{
			element.clearSubscriptions();

			expect(mockError).toHaveBeenCalledWith(CLEAR_SUBSCRIPTIONS_UNINITIALISED_ERROR);
			const actualMessage = mockError.mock.calls.find(([msg]) => typeof msg === 'string' && msg.includes('clearSubscriptions'))[0];
			expect(actualMessage).toContain('lightning-message');
			expect(actualMessage).not.toContain('navigation');
		});

		it('should log error when publishLightningMessage is called uninitialised', () =>
		{
			const mockChannel = {channel: true};
			element.publishLightningMessage(mockChannel, {data: 'test'});

			expect(mockError).toHaveBeenCalledWith(PUBLISH_LIGHTNING_MESSAGE_UNINITIALISED_ERROR, expect.objectContaining({messageChannel: mockChannel, payload: {data: 'test'}}));
		});

		it('should log error when addMessageChannelSubscription is called uninitialised', () =>
		{
			const mockChannel = {channel: true};
			const mockCallback = jest.fn();
			element.addMessageChannelSubscription(mockChannel, mockCallback);

			expect(mockError).toHaveBeenCalledWith(ADD_SUBSCRIPTION_UNINITIALISED_ERROR, expect.objectContaining({messageChannel: mockChannel, callback: 'function'}));
		});

		it('should use default payload for publishLightningMessage', () =>
		{
			const mockChannel = {channel: true};
			element.publishLightningMessage(mockChannel);

			expect(mockError).toHaveBeenCalledWith(PUBLISH_LIGHTNING_MESSAGE_UNINITIALISED_ERROR, expect.objectContaining({payload: {}}));
		});
	});

	describe('uninitialised controller methods (@api)', () =>
	{
		it('should log error when callControllerMethod is called uninitialised', () =>
		{
			const mockMethod = jest.fn();
			element.callControllerMethod(mockMethod, {param: 'value'}, false);

			expect(mockError)
			.toHaveBeenCalledWith(CALL_CONTROLLER_UNINITIALISED_ERROR, expect.objectContaining({controllerMethod: 'function', parameterMap: {param: 'value'}, isThrow: false}));
		});

		it('should log error when handleWireResponse is called uninitialised', () =>
		{
			element.handleWireResponse({error: null, data: {test: 'data'}});

			expect(mockError).toHaveBeenCalledWith(HANDLE_WIRE_RESPONSE_UNINITIALISED_ERROR, expect.objectContaining({error: null, data: {test: 'data'}}));
		});

		it('should use default parameters for callControllerMethod', () =>
		{
			const mockMethod = jest.fn();
			element.callControllerMethod(mockMethod);

			expect(mockError).toHaveBeenCalledWith(CALL_CONTROLLER_UNINITIALISED_ERROR, expect.objectContaining({parameterMap: {}, isThrow: false}));
		});
	});

	describe('uninitialised flow navigation methods (@api)', () =>
	{
		it('should log error when dispatchFlowNextEvent is called uninitialised', () =>
		{
			element.dispatchFlowNextEvent();

			expect(mockError).toHaveBeenCalledWith(FLOW_NAVIGATION_NEXT_EVENT_UNINITIALISED_ERROR);
		});

		it('should log error when dispatchFlowBackEvent is called uninitialised', () =>
		{
			element.dispatchFlowBackEvent();

			expect(mockError).toHaveBeenCalledWith(FLOW_NAVIGATION_BACK_EVENT_UNINITIALISED_ERROR);
		});

		it('should log error when dispatchFlowFinishEvent is called uninitialised', () =>
		{
			element.dispatchFlowFinishEvent();

			expect(mockError).toHaveBeenCalledWith(FLOW_NAVIGATION_FINISH_EVENT_UNINITIALISED_ERROR);
		});
	});

	describe('event handling (@api dispatchCustomEvent)', () =>
	{
		it('should dispatch custom event via dispatchCustomEvent', () =>
		{
			const eventHandler = jest.fn();
			const eventName = 'customevent';
			const detailKey = 'myEvent';
			element.addEventListener(eventName, eventHandler);

			element.dispatchCustomEvent(detailKey, {key: 'value'});

			expect(eventHandler).toHaveBeenCalledTimes(1);
			const event = eventHandler.mock.calls[0][0];
			expect(event.detail).toHaveProperty(detailKey);
			expect(event.detail[detailKey]).toEqual({key: 'value'});
		});

		it('should dispatch custom event with empty detail by default', () =>
		{
			const eventHandler = jest.fn();
			const eventName = 'customevent';
			const detailKey = 'emptyEvent';
			element.addEventListener(eventName, eventHandler);

			element.dispatchCustomEvent(detailKey);

			const event = eventHandler.mock.calls[0][0];
			expect(event.detail[detailKey]).toEqual({});
		});
	});

	describe('logging methods (@api)', () =>
	{
		it('should log debug message via consoleLog with value', () =>
		{
			element.consoleLog('Test description', {testData: 'value'});

			expect(mockDebug).toHaveBeenCalledWith('Test description', expect.objectContaining({value: {testData: 'value'}}));
		});

		it('should log debug message via consoleLog without value', () =>
		{
			element.consoleLog('Description only');

			expect(mockDebug).toHaveBeenCalledWith('Description only');
		});

		it('should log debug message via consoleLog with null value', () =>
		{
			element.consoleLog('Null value test', null);

			expect(mockDebug).toHaveBeenCalledWith('Null value test');
		});

		it('should bypass proxy for objects by default', () =>
		{
			const testObj = {nested: {data: 'test'}};
			element.consoleLog('Object test', testObj, true);

			expect(mockDebug).toHaveBeenCalledWith('Object test', expect.objectContaining({value: {nested: {data: 'test'}}}));
		});

		it('should not bypass proxy when bypassProxy is false', () =>
		{
			const testObj = {data: 'test'};
			element.consoleLog('No bypass test', testObj, false);

			expect(mockDebug).toHaveBeenCalledWith('No bypass test', expect.objectContaining({value: testObj}));
		});

		it('should handle non-object values in consoleLog', () =>
		{
			element.consoleLog('String value', 'test string');

			expect(mockDebug).toHaveBeenCalledWith('String value', {value: 'test string'});
		});

		it('should log error via consoleError', () =>
		{
			const testError = new Error('Test error');
			element.consoleError(testError, 'Error context');

			expect(mockError).toHaveBeenCalledWith('Error context', testError);
		});

		it('should use default description in consoleError', () =>
		{
			const testError = new Error('Test error');
			element.consoleError(testError);

			expect(mockError).toHaveBeenCalledWith('Description', testError);
		});
	});

	describe('disconnectedCallback', () =>
	{
		it('should execute teardown operations when element is removed', () =>
		{
			const teardownFn = jest.fn();
			element.addTearDownOperation(teardownFn);

			// Remove element to trigger disconnectedCallback
			document.body.removeChild(element);

			expect(teardownFn).toHaveBeenCalled();
		});

		it('should handle no teardown operations gracefully', () =>
		{
			// Should not throw when no teardown operations are registered
			expect(() =>
			{
				document.body.removeChild(element);
			}).not.toThrow();
		});
	});

	describe('errorCallback', () =>
	{
		it('should log component errors via utilityLogger', () =>
		{
			// errorCallback is a lifecycle hook called by the framework when child errors bubble up.
			// LWC doesn't expose lifecycle hooks on element, so we call directly on prototype.
			const testError = new Error('Test child component error');
			testError.name = 'TestError';
			const testStack = 'c-child-component > c-grandchild-component';

			// Call errorCallback on prototype with empty context (it only uses utilityLogger)
			BaseComponent.prototype.errorCallback.call({}, testError, testStack);

			// Verify utilityLogger.error was called with correct parameters
			expect(mockError).toHaveBeenCalledWith('Component error', expect.objectContaining({
				errorMessage: 'Test child component error', errorName: 'TestError', componentStack: 'c-child-component > c-grandchild-component'
			}));
		});

		it('should include error stack in log context', () =>
		{
			const testError = new Error('Stack test error');
			testError.stack = 'Error: Stack test error\n    at someFunction (file.js:10:5)';

			BaseComponent.prototype.errorCallback.call({}, testError, 'c-test-component');

			expect(mockError).toHaveBeenCalledWith('Component error', expect.objectContaining({
				errorStack: expect.stringContaining('Stack test error')
			}));
		});
	});
});
