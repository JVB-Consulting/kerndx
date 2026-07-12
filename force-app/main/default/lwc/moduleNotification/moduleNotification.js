// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Notification module for the ComponentBuilder framework. Provides toast
 * notifications with variant-specific convenience methods and a curried factory pattern.
 *
 * @author Jason van Beukering
 *
 * @date February 2022, May 2026
 */
import ERROR_TITLE_LABEL from '@salesforce/label/c.ModuleNotification_ErrorTitle';
import INFO_TITLE_LABEL from '@salesforce/label/c.ModuleNotification_InfoTitle';
import SUCCESS_TITLE_LABEL from '@salesforce/label/c.ModuleNotification_SuccessTitle';
import WARNING_TITLE_LABEL from '@salesforce/label/c.ModuleNotification_WarningTitle';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {reduceErrors} from 'c/utilitySystem';

// ── Constants ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

const VALID_VARIANTS = new Set([
	'info',
	'success',
	'warning',
	'error'
]);
const VALID_MODES = new Set([
	'dismissible',
	'pester',
	'sticky'
]);

// Developer-only invariants: thrown when a caller passes an invalid variant/mode — a
// programming error surfaced during development, never reachable from subscriber interaction.
// eslint-disable-next-line kerndx/no-hardcoded-user-text
const INVALID_VARIANT_ERROR = 'Invalid Toast variant. Valid values are: \'info\' (default), \'success\', \'warning\', and \'error\'.';
// eslint-disable-next-line kerndx/no-hardcoded-user-text
const INVALID_MODE_ERROR = 'Invalid Toast mode. Valid values are: \'dismissible\' (default), \'pester\', and \'sticky\'.';

export const INFO_NOTIFICATION_TITLE = INFO_TITLE_LABEL;
export const WARNING_NOTIFICATION_TITLE = WARNING_TITLE_LABEL;
export const SUCCESS_NOTIFICATION_TITLE = SUCCESS_TITLE_LABEL;
export const ERROR_NOTIFICATION_TITLE = ERROR_TITLE_LABEL;

// ── Internal Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Validates that a value belongs to an allowed set, throwing with the
 * provided message when it does not.
 *
 * @param {Set<string>} allowedValues The set of permitted values
 * @param {string} value The value to validate
 * @param {string} errorMessage The error message if validation fails
 * @private
 */
function validateOption(allowedValues, value, errorMessage)
{
	if(!allowedValues.has(value))
	{
		throw new Error(errorMessage);
	}
}

// ── Module Initialisers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Wires the `customNotification` method onto a component instance.
 * Dispatches a ShowToastEvent after validating variant and mode.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialiseCustomNotification = function(component)
{
	component.customNotification = (title, message, variant = 'info', messageData = [], mode = 'dismissible') =>
	{
		validateOption(VALID_VARIANTS, variant, INVALID_VARIANT_ERROR);
		validateOption(VALID_MODES, mode, INVALID_MODE_ERROR);

		return component.dispatchEvent(new ShowToastEvent({title, message, variant, messageData, mode}));
	};
};

/**
 * @description Wires the `customNotificationFactory` curried method onto a component instance.
 * Returns a function pre-configured with variant and mode that accepts message and title.
 *
 * @param {Object} component The BaseComponent instance to enhance
 * @param {boolean} [shouldInitialiseNotification=true] Whether to also initialise the base customNotification method
 */
export const initialiseCustomNotificationFactory = function(component, shouldInitialiseNotification = true)
{
	if(shouldInitialiseNotification)
	{
		initialiseCustomNotification(component);
	}

	component.customNotificationFactory =
			(variant = 'info', mode = 'dismissible') => (message, title, messageData = []) => component.customNotification(title, message, variant, messageData, mode);
};

/**
 * @description Wires the `showInfoToast` convenience method onto a component instance.
 *
 * @param {Object} component The BaseComponent instance to enhance
 * @param {boolean} [isFactoryReady=true] Whether customNotificationFactory is already wired
 */
export const initializeShowInfoToast = function(component, isFactoryReady = true)
{
	if(!isFactoryReady)
	{
		initialiseCustomNotificationFactory(component);
	}

	component.showInfoToast = (message, header = INFO_NOTIFICATION_TITLE) => component.customNotificationFactory()(message, header);
};

/**
 * @description Wires the `showWarningToast` convenience method onto a component instance.
 *
 * @param {Object} component The BaseComponent instance to enhance
 * @param {boolean} [isFactoryReady=true] Whether customNotificationFactory is already wired
 */
export const initializeShowWarningToast = function(component, isFactoryReady = true)
{
	if(!isFactoryReady)
	{
		initialiseCustomNotificationFactory(component);
	}

	component.showWarningToast = (message, header = WARNING_NOTIFICATION_TITLE) => component.customNotificationFactory('warning')(message, header);
};

/**
 * @description Wires the `showSuccessToast` convenience method onto a component instance.
 *
 * @param {Object} component The BaseComponent instance to enhance
 * @param {boolean} [isFactoryReady=true] Whether customNotificationFactory is already wired
 */
export const initializeShowSuccessToast = function(component, isFactoryReady = true)
{
	if(!isFactoryReady)
	{
		initialiseCustomNotificationFactory(component);
	}

	component.showSuccessToast = (message, header = SUCCESS_NOTIFICATION_TITLE) => component.customNotificationFactory('success')(message, header);
};

/**
 * @description Wires the `showErrorToast` convenience method onto a component instance.
 *
 * Accepts either a string (existing pattern — passes straight through) or an Apex / UI API
 * error object (new pattern — normalised via `c/utilitySystem.reduceErrors`). Subscribers
 * catching an `AuraHandledException` result can now pass the raw `error` argument from a
 * `.catch(error => component.showErrorToast(error))` chain and get a sensible toast string,
 * not `[object Object]`.
 *
 * @param {Object} component The BaseComponent instance to enhance
 * @param {boolean} [isFactoryReady=true] Whether customNotificationFactory is already wired
 */
export const initializeShowErrorToast = function(component, isFactoryReady = true)
{
	if(!isFactoryReady)
	{
		initialiseCustomNotificationFactory(component);
	}

	component.showErrorToast = (message, header = ERROR_NOTIFICATION_TITLE) =>
	{
		const normalisedMessage = typeof message === 'string' ? message : reduceErrors(message);
		return component.customNotificationFactory('error')(normalisedMessage, header);
	};
};

// ── Default Export ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Activates the notification module on a BaseComponent instance,
 * wiring the notification factory and all variant-specific toast methods.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export default function initialiseNotificationModule(component)
{
	initialiseCustomNotificationFactory(component);
	initializeShowInfoToast(component);
	initializeShowWarningToast(component);
	initializeShowSuccessToast(component);
	initializeShowErrorToast(component);
}