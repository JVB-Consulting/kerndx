// SPDX-License-Identifier: Apache-2.0
/**
 * @description Global Jest mock for componentBuilder LWC module.
 *              This mock is used by all tests that import components using ComponentBuilder.
 *              It provides mock functions that can be spied on to verify component behavior.
 *              It also carries the base teardown contract: `addTearDownOperation` registers an
 *              operation, and `disconnectedCallback` runs every registered operation in order and
 *              then empties the list, as the real base component does. Both are prototype methods,
 *              so a component's own `disconnectedCallback` still runs and can chain to this one.
 */
import {api, LightningElement} from 'lwc';

// Export constants matching the real module
export const ALL_MODULES = 'all';
export const INVALID_INITIALISATION_ERROR = 'Verify that the module identifiers passed to ComponentBuilder are valid';

// Mock notification functions
export const mockShowErrorToast = jest.fn();
export const mockShowWarningToast = jest.fn();
export const mockShowInfoToast = jest.fn();
export const mockShowSuccessToast = jest.fn();
export const mockCustomNotification = jest.fn();
export const mockCustomNotificationFactory = jest.fn(() => mockCustomNotification);

// Mock console functions
export const mockConsoleError = jest.fn();
export const mockConsoleLog = jest.fn();

// Mock controller functions
export const mockCallControllerMethod = jest.fn((controller, params) =>
{
	if(typeof controller === 'function')
	{
		controller(params);
	}
	return Promise.resolve({});
});

export const mockHandleWireResponse = jest.fn((response) =>
{
	if(response.error)
	{
		mockShowErrorToast(response.error);
		return undefined;
	}
	return response.data;
});

// Mock navigation functions
export const mockNavigate = jest.fn();
export const mockGenerateUrl = jest.fn().mockResolvedValue('/mock-url');
export const mockRedirectToRecordPage = jest.fn();

// Mock lightning message service functions
export const mockPublishLightningMessage = jest.fn();
export const mockSubscribeToMessageChannel = jest.fn();
export const mockAddMessageChannelSubscription = jest.fn();
export const mockClearSubscriptions = jest.fn();

// Mock flow navigation functions
export const mockDispatchFlowNextEvent = jest.fn();
export const mockDispatchFlowBackEvent = jest.fn();
export const mockDispatchFlowFinishEvent = jest.fn();

/**
 * @description Mock ComponentBuilder factory that returns a class extending LightningElement.
 *              The returned class has mock implementations of all framework methods.
 */
export const ComponentBuilder = (...functionalityToInitialise) =>
{
	return class MockComponent extends LightningElement
	{
		functionality = functionalityToInitialise;

		// Common properties
		isLoading = false;
		spinnerHtml = '<div class="spinner"></div>';

		// Notification methods
		showErrorToast = mockShowErrorToast;
		showWarningToast = mockShowWarningToast;
		showInfoToast = mockShowInfoToast;
		showSuccessToast = mockShowSuccessToast;
		customNotification = mockCustomNotification;
		customNotificationFactory = mockCustomNotificationFactory;

		// Console methods
		consoleError = mockConsoleError;
		consoleLog = mockConsoleLog;

		// Controller methods
		callControllerMethod = mockCallControllerMethod;
		handleWireResponse = mockHandleWireResponse;

		// Navigation methods
		navigate = mockNavigate;
		generateUrl = mockGenerateUrl;
		redirectToRecordPage = mockRedirectToRecordPage;

		// Lightning message service methods
		publishLightningMessage = mockPublishLightningMessage;
		subscribeToMessageChannel = mockSubscribeToMessageChannel;
		addMessageChannelSubscription = mockAddMessageChannelSubscription;
		clearSubscriptions = mockClearSubscriptions;

		// Flow navigation methods
		dispatchFlowNextEvent = mockDispatchFlowNextEvent;
		dispatchFlowBackEvent = mockDispatchFlowBackEvent;
		dispatchFlowFinishEvent = mockDispatchFlowFinishEvent;

		// Teardown operations registered through addTearDownOperation
		tearDown = [];

		/**
		 * @description Adds an operation to run when the component is removed from the DOM.
		 * @param {function(): void} operation Teardown function to register
		 */
		@api addTearDownOperation(operation)
		{
			this.tearDown.push(operation);
		}

		/**
		 * @description Runs every registered teardown operation in order, then empties the list.
		 */
		disconnectedCallback()
		{
			for(const operation of this.tearDown)
			{
				operation();
			}

			this.tearDown = [];
		}
	};
};

// Default export for compatibility
export default ComponentBuilder;
