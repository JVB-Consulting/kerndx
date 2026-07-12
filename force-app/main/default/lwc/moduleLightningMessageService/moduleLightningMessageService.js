// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Lightning Message Service module for the ComponentBuilder framework.
 * Provides publish/subscribe messaging with automatic subscription lifecycle management.
 *
 * @author Jason van Beukering
 *
 * @date February 2022, July 2026
 */
import {APPLICATION_SCOPE, publish, subscribe, unsubscribe} from 'lightning/messageService';

// ── Internal Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Validates that a required parameter is truthy, throwing a descriptive
 * error when it is not.
 *
 * @param {*} value The value to check
 * @param {string} parameterName The name of the parameter for the error message
 * @private
 */
function requireParameter(value, parameterName)
{
	if(!value)
	{
		// Developer-only invariant: null-guard for a missing required argument —
		// never reachable from subscriber interaction.
		// eslint-disable-next-line kerndx/no-hardcoded-user-text
		throw new Error(`Error: ${parameterName} is ${value}`);
	}
}

/**
 * @description Wires the `clearSubscriptions` method onto a component instance.
 * Unsubscribes from all active message channel subscriptions.
 *
 * @param {Object} component The BaseComponent instance to enhance
 * @private
 */
function initialiseClearSubscriptions(component)
{
	component.clearSubscriptions = function()
	{
		component.activeSubscriptions.forEach((subscription) => unsubscribe(subscription));
		component.clearActiveSubscriptions();
		return component.activeSubscriptions.length;
	};
}

// ── Exported Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Subscribes to a Lightning message channel with optional application scope.
 * Validates all required parameters before subscribing.
 *
 * @param {Object} messageContext The Lightning MessageContext wire adapter value
 * @param {Object} messageChannel The imported message channel reference
 * @param {Function} handler Callback invoked when a message is received
 * @param {boolean} [isApplicationScope=false] When true, receives messages from the entire application
 * @returns {Object} The subscription handle for later unsubscription
 */
export const subscribeToMessageChannel = function(messageContext, messageChannel, handler, isApplicationScope = false)
{
	requireParameter(messageContext, 'messageContext');
	requireParameter(messageChannel, 'messageChannel');
	requireParameter(handler, 'handler');

	const options = isApplicationScope ? {scope: APPLICATION_SCOPE} : null;
	return subscribe(messageContext, messageChannel, (message) => handler(message), options);
};

/**
 * @description Publishes a message payload to a Lightning message channel.
 * Validates context and channel before publishing.
 *
 * @param {Object} messageContext The Lightning MessageContext wire adapter value
 * @param {Object} messageChannel The imported message channel reference
 * @param {Object} payload The message data to publish
 */
export const publishMessage = function(messageContext, messageChannel, payload)
{
	requireParameter(messageContext, 'messageContext');
	requireParameter(messageChannel, 'messageChannel');

	publish(messageContext, messageChannel, payload);
};

// ── Module Initialisers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Wires the `addMessageChannelSubscription` method onto a component instance.
 * Manages subscription registration and error handling.
 *
 * @param {Object} component The BaseComponent instance to enhance
 * @param {boolean} [shouldInitialiseClear=true] Whether to also wire the clearSubscriptions method
 */
export const initialiseSubscriptionService = function(component, shouldInitialiseClear = true)
{
	component.addMessageChannelSubscription = function(messageChannel, callback)
	{
		let numberOfSubscriptions;

		try
		{
			numberOfSubscriptions = component.addActiveSubscription(subscribeToMessageChannel(component.componentMessageContext, messageChannel, callback));
		}
		catch(error)
		{
			component.consoleError(error);
			throw error;
		}

		return numberOfSubscriptions;
	};

	if(shouldInitialiseClear)
	{
		initialiseClearSubscriptions(component);
	}
};

/**
 * @description Wires the `publishLightningMessage` method onto a component instance.
 * Provides error-handled message publishing.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialisePublishService = function(component)
{
	component.publishLightningMessage = function(messageChannel, payload = {})
	{
		let success;

		try
		{
			publishMessage(component.componentMessageContext, messageChannel, payload);
			success = true;
		}
		catch(error)
		{
			component.consoleError(error);
			throw error;
		}

		return success;
	};
};

// ── Default Export ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Activates the Lightning Message Service module on a BaseComponent instance,
 * wiring subscription management (which includes the clearSubscriptions cleanup method)
 * and publishing.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export default function initialiseLightningMessageModule(component)
{
	initialiseSubscriptionService(component);
	initialisePublishService(component);
}