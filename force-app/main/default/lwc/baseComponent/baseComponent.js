// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base class for the KernDX LWC component framework. Provides event dispatching,
 * structured logging, lifecycle management, and stub methods for optional modules (notification,
 * navigation, controller, lightning-message, flow-navigation).
 *
 * Modules are activated via ComponentBuilder — unactivated module methods log an error
 * with guidance on which module identifier to include.
 *
 * @author Jason van Beukering
 *
 * @date December 2025, July 2026
 */
import utilityLogger from 'c/utilityLogger';
import {formatTemplateString} from 'c/utilityString';
import {setPropertyOnObject} from 'c/utilitySystem';
import {MessageContext} from 'lightning/messageService';
import {NavigationMixin} from 'lightning/navigation';
import {api, LightningElement, wire} from 'lwc';
// noinspection ES6UnusedImports - LWC pattern for importing HTML templates
// @ts-ignore - LWC HTML template import resolved at compile time
import SpinnerHtml from './spinner.html';

// ── Module Error Factory ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/** @description Template for uninitialised module error messages. */
		// Developer-only invariant: guides a developer who calls a module method without wiring
		// that module in the ComponentBuilder invocation — never reachable from subscriber interaction.
		// eslint-disable-next-line kerndx/no-hardcoded-user-text
const MISSING_MODULE_TEMPLATE = 'Please include {0} in LwcBuilder invocation to use the {1} method';

/**
 * @description Builds an error message indicating that a module method was called without
 * first activating the required module via ComponentBuilder.
 *
 * @param {string} moduleName The module identifier that should have been passed to ComponentBuilder
 * @param {string} methodName The method that was invoked
 * @returns {string} Human-readable error message
 * @private
 */
function missingModuleMessage(moduleName, methodName)
{
	return formatTemplateString(MISSING_MODULE_TEMPLATE, [
		moduleName,
		methodName
	]);
}

/**
 * @description Registry of uninitialised-module error messages, keyed by method name.
 * Each entry maps to a pre-formatted string built from {@link missingModuleMessage}.
 *
 * @type {Readonly<Object<string, string>>}
 * @private
 */
const UNINITIALISED_ERRORS = Object.freeze({
	customNotification: missingModuleMessage('notification', 'customNotification'),
	customNotificationFactory: missingModuleMessage('notification', 'customNotificationFactory'),
	showInfoToast: missingModuleMessage('notification', 'showInfoToast'),
	showWarningToast: missingModuleMessage('notification', 'showWarningToast'),
	showErrorToast: missingModuleMessage('notification', 'showErrorToast'),
	showSuccessToast: missingModuleMessage('notification', 'showSuccessToast'),
	redirectToRecordPage: missingModuleMessage('navigation', 'redirectToRecordPage'),
	generateRecordPageURL: missingModuleMessage('navigation', 'generateRecordPageURL'),
	clearSubscriptions: missingModuleMessage('lightning-message', 'clearSubscriptions'),
	publishLightningMessage: missingModuleMessage('lightning-message', 'publishLightningMessage'),
	addMessageChannelSubscription: missingModuleMessage('lightning-message', 'addMessageChannelSubscription'),
	callControllerMethod: missingModuleMessage('controller', 'callControllerMethod'),
	handleWireResponse: missingModuleMessage('controller', 'handleWireResponse'),
	dispatchFlowNextEvent: missingModuleMessage('flow-navigation', 'dispatchFlowNextEvent'),
	dispatchFlowBackEvent: missingModuleMessage('flow-navigation', 'dispatchFlowBackEvent'),
	dispatchFlowFinishEvent: missingModuleMessage('flow-navigation', 'dispatchFlowFinishEvent')
});

// ── Exported Error Constants ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

export const CUSTOM_NOTIFICATION_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.customNotification;
export const CUSTOM_NOTIFICATION_FACTORY_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.customNotificationFactory;
export const SHOW_INFO_TOAST_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.showInfoToast;
export const SHOW_WARNING_TOAST_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.showWarningToast;
export const SHOW_ERROR_TOAST_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.showErrorToast;
export const SHOW_SUCCESS_TOAST_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.showSuccessToast;
export const REDIRECT_TO_RECORD_PAGE_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.redirectToRecordPage;
export const GENERATE_RECORD_PAGE_URL_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.generateRecordPageURL;
export const CLEAR_SUBSCRIPTIONS_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.clearSubscriptions;
export const PUBLISH_LIGHTNING_MESSAGE_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.publishLightningMessage;
export const ADD_SUBSCRIPTION_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.addMessageChannelSubscription;
export const CALL_CONTROLLER_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.callControllerMethod;
export const HANDLE_WIRE_RESPONSE_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.handleWireResponse;
export const FLOW_NAVIGATION_NEXT_EVENT_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.dispatchFlowNextEvent;
export const FLOW_NAVIGATION_BACK_EVENT_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.dispatchFlowBackEvent;
export const FLOW_NAVIGATION_FINISH_EVENT_UNINITIALISED_ERROR = UNINITIALISED_ERRORS.dispatchFlowFinishEvent;

// ── BaseComponent ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

// noinspection SpellCheckingInspection
export default class BaseComponent extends NavigationMixin(LightningElement)
{
	/** @description Reference to spinner template. */
	spinnerHtml = SpinnerHtml;

	/** @description Generic reusable indicator that the component is still loading data. */
	isLoading = false;

	/**
	 * @description Message context for Lightning Message Service.
	 * @type {Object}
	 */
	@wire(MessageContext) messageContext;

	/**
	 * @description Contains all active lightning message Subscription objects.
	 * @type {Object[]}
	 */
	activeMessageSubscriptions = [];

	/**
	 * @description Contains all required functionality to be initialised for component.
	 * @type {('all'|'navigation'|'notification'|'lightning-message'|'controller'|'flow-navigation')[]}
	 */
	functionality = [];

	/**
	 * @description List of teardown operation function handlers.
	 * @type {(function(): void)[]}
	 */
	tearDown = [];

	/** @description Navigation function from NavigationMixin. Navigates to the specified page reference. */
	navigate = this[NavigationMixin.Navigate];

	/** @description URL generation function from NavigationMixin. Returns a Promise resolving to the URL. */
	generateUrl = this[NavigationMixin.GenerateUrl];

	// ── Public Accessors ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

	@api get navigationHandler()
	{
		return this.navigate;
	}

	// noinspection JSUnusedGlobalSymbols
	/** @description Setter to override the default navigation handler. */
	set navigationHandler(handler)
	{
		this.navigate = handler;
	}

	@api get generateUrlHandler()
	{
		return this.generateUrl;
	}

	// noinspection JSUnusedGlobalSymbols
	/** @description Setter to override the default generateUrl handler. */
	set generateUrlHandler(handler)
	{
		this.generateUrl = handler;
	}

	@api get activeSubscriptions()
	{
		return this.activeMessageSubscriptions;
	}

	@api get componentMessageContext()
	{
		return this.messageContext;
	}

	@api clearActiveSubscriptions()
	{
		this.activeMessageSubscriptions = [];
	}

	/**
	 * @description Adds a subscription to the active subscriptions list.
	 * @param {Object} value Subscription object to track
	 * @returns {number} Updated subscription count
	 */
	@api addActiveSubscription(value)
	{
		return this.activeMessageSubscriptions.push(value);
	}

	/**
	 * @description Adds teardown operation to teardown array.
	 * @param {function(): void} operation Teardown function to register
	 */
	@api addTearDownOperation(operation)
	{
		this.tearDown.push(operation);
	}

	// ── Notification Stubs ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

	/**
	 * @description Displays a custom toast notification. Requires the 'notification' module.
	 * @param {string} title Toast notification title
	 * @param {string} message Toast notification message
	 * @param {'info'|'success'|'warning'|'error'} variant Toast variant
	 * @param {string[]} messageData Array of data to replace template placeholders
	 * @param {'dismissible'|'pester'|'sticky'} mode Toast mode
	 */
	@api customNotification = (title, message, variant = 'info', messageData = [], mode = 'dismissible') =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.customNotification, {title, message, variant, messageData, mode});
	};

	/**
	 * @description Returns a factory function for creating toast notifications with preset variant and mode.
	 * @param {'info'|'success'|'warning'|'error'} variant Toast variant
	 * @param {'dismissible'|'pester'|'sticky'} mode Toast mode
	 * @returns {Function|void} Factory function or void if uninitialised
	 */
	@api customNotificationFactory = (variant = 'info', mode = 'dismissible') =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.customNotificationFactory, {variant, mode});
	};

	/**
	 * @description Shows an informational toast. Requires the 'notification' module.
	 * @param {string} message Toast message
	 * @param {string} header Toast heading
	 */
	@api showInfoToast = (message, header = 'Info') =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.showInfoToast, {message, header});
	};

	/**
	 * @description Shows a warning toast. Requires the 'notification' module.
	 * @param {string} message Toast message
	 * @param {string} header Toast heading
	 */
	@api showWarningToast = (message, header = 'Warning') =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.showWarningToast, {message, header});
	};

	/**
	 * @description Shows an error toast. Requires the 'notification' module.
	 * @param {string} message Toast message
	 * @param {string} header Toast heading
	 */
	@api showErrorToast = (message, header = 'Error') =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.showErrorToast, {message, header});
	};

	/**
	 * @description Shows a success toast. Requires the 'notification' module.
	 * @param {string} message Toast message
	 * @param {string} header Toast heading
	 */
	@api showSuccessToast = (message, header = 'Success') =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.showSuccessToast, {message, header});
	};

	// ── Navigation Stubs ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

	/**
	 * @description Redirects to a record page. Requires the 'navigation' module.
	 * @param {string} recordId Valid SObject record ID
	 */
	@api redirectToRecordPage = (recordId) =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.redirectToRecordPage, {recordId});
	};

	/**
	 * @description Generates a record page URL for use in href attributes or window.open().
	 * Requires the 'navigation' module.
	 * @param {string} recordId Salesforce record ID
	 * @returns {Promise<string>|void}
	 */
	@api generateRecordPageURL = (recordId) =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.generateRecordPageURL, {recordId});
	};

	// ── Lightning Message Service Stubs ──────────────────────────────────────────────────────────────────────────────────────────────────────────

	/**
	 * @description Unsubscribes from all active message channel subscriptions.
	 * Requires the 'lightning-message' module.
	 */
	@api clearSubscriptions = () =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.clearSubscriptions);
	};

	/**
	 * @description Publishes a message to a Lightning Message Channel.
	 * Requires the 'lightning-message' module.
	 * @param {Object} messageChannel Message Channel reference
	 * @param {Object} payload Message payload
	 */
	@api publishLightningMessage = (messageChannel, payload = {}) =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.publishLightningMessage, {messageChannel, payload});
	};

	/**
	 * @description Subscribes to a Lightning Message Channel with a handler callback.
	 * Requires the 'lightning-message' module.
	 * @param {Object} messageChannel Message Channel reference
	 * @param {Function} callback Handler function for received messages
	 * @returns {number|void} Number of active subscriptions
	 */
	@api addMessageChannelSubscription = (messageChannel, callback) =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.addMessageChannelSubscription, {messageChannel, callback: typeof callback});
	};

	// ── Controller Stubs ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

	/**
	 * @description Calls an Apex controller method with automatic error handling.
	 * Requires the 'controller' module.
	 * @param {Function} controllerMethod Imported Apex method
	 * @param {Object} parameterMap Apex method parameters
	 * @param {boolean} isThrow Whether to re-throw caught errors
	 * @returns {Promise<*>|void}
	 */
	@api callControllerMethod = (controllerMethod, parameterMap = {}, isThrow = false) =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.callControllerMethod, {controllerMethod: typeof controllerMethod, parameterMap, isThrow});
	};

	/**
	 * @description Extracts data from a wired method response with error handling.
	 * Requires the 'controller' module.
	 * @param {{error: Error, data: *}} result Wire result containing error or data
	 * @returns {*}
	 */
	@api handleWireResponse = ({error, data}) =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.handleWireResponse, {error, data});
	};

	// ── Event Dispatching ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

	/**
	 * @description Creates and dispatches a custom event. The event name is always 'customevent',
	 * with the actual event name embedded in the detail payload for routing.
	 *
	 * @param {string} eventName The name of the custom event
	 * @param {Object} detail The event detail payload
	 */
	@api dispatchCustomEvent(eventName, detail = {})
	{
		// noinspection JSUnresolvedVariable
		this.dispatchEvent(new CustomEvent('customevent', {
			detail: setPropertyOnObject({}, eventName, detail)
		}));
	}

	// ── Flow Navigation Stubs ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

	/**
	 * @description Dispatches a Flow Next navigation event. Requires the 'flow-navigation' module.
	 * Only works when the next element in the flow is another screen (not the End element).
	 */
	@api dispatchFlowNextEvent = () =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.dispatchFlowNextEvent);
	};

	/**
	 * @description Dispatches a Flow Back navigation event. Requires the 'flow-navigation' module.
	 * Only works when there is a previous screen to navigate to.
	 */
	@api dispatchFlowBackEvent = () =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.dispatchFlowBackEvent);
	};

	/**
	 * @description Dispatches a Flow Finish event. Requires the 'flow-navigation' module.
	 * Only works when the next element in the flow is the End element.
	 */
	@api dispatchFlowFinishEvent = () =>
	{
		utilityLogger.error(UNINITIALISED_ERRORS.dispatchFlowFinishEvent);
	};

	// ── Lifecycle Hooks ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

	/**
	 * @description LWC lifecycle hook invoked when an error occurs in a descendant component.
	 * @param {Error} error The error object
	 * @param {string} stack The component stack trace
	 */
	errorCallback(error, stack)
	{
		utilityLogger.error('Component error', {
			errorMessage: error.message, errorName: error.name, errorStack: error.stack, componentStack: stack
		});
	}

	/**
	 * @description Executes all registered teardown operations when the component is removed from the DOM.
	 */
	disconnectedCallback()
	{
		for(const operation of this.tearDown)
		{
			operation();
		}
	}

	// ── Logging ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

	/**
	 * @description Logs a value with optional Locker Service proxy bypass. Complex objects are
	 * round-tripped through JSON to strip framework proxies and reveal actual data. Only an
	 * absent value (null/undefined) logs the description alone — legitimate falsy values such
	 * as `0`, `false`, and `''` are logged as values.
	 *
	 * @param {string} description Label for the log entry
	 * @param {*} value Object or value to log
	 * @param {boolean} bypassProxy When true, JSON round-trips objects to strip Locker proxies
	 */
	@api consoleLog(description, value = null, bypassProxy = true)
	{
		if(value === null)
		{
			utilityLogger.debug(description);
			return;
		}

		const resolved = (typeof value === 'object' && bypassProxy) ? JSON.parse(JSON.stringify(value)) : value;
		utilityLogger.debug(description, {value: resolved});
	}

	/**
	 * @description Logs an error with structured context. Delegates to utilityLogger for
	 * server-side persistence.
	 *
	 * @param {Error} error The error object
	 * @param {string} description Description of the error context
	 */
	@api consoleError = (error, description = 'Description') =>
	{
		utilityLogger.error(description, error);
	};
}