// SPDX-License-Identifier: Apache-2.0
/**
 * @description Controller module for the ComponentBuilder framework. Provides Apex controller
 * method invocation with automatic error handling and wire response extraction.
 *
 * @author Jason van Beukering
 *
 * @date February 2022, October 2026
 */
import ERROR_TITLE_LABEL from '@salesforce/label/c.ModuleNotification_ErrorTitle';
import FAILED_CONTROLLER_CALL_LABEL from '@salesforce/label/c.ModuleController_FailedControllerCall';
import {reduceErrors} from 'c/utilitySystem';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

// ── Constants ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

export const FAILED_CONTROLLER_CALL_ERROR = FAILED_CONTROLLER_CALL_LABEL;
export const CALL_CONTROLLER_METHOD_NAME = 'callControllerMethod';
export const HANDLE_WIRE_RESPONSE_METHOD_NAME = 'handleWireResponse';

// ── Internal Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Surfaces an Apex error to the user via toast and structured logging,
 * optionally throwing a normalised failure that carries the original error as its
 * `cause` so an upstream catch can still inspect what actually went wrong. The logged
 * description names the failing method and carries the failure text `reduceErrors`
 * resolved — the server's message, or the HTTP status line when the server sent none —
 * so the persisted entry reads as the failure rather than as the method alone.
 *
 * @param {Object} component The BaseComponent instance
 * @param {string} source Identifier of the method that failed
 * @param {Error|Object} error The error from the Apex call
 * @param {{isThrow: boolean, isSilent: boolean}} [callOptions={}] Resolved call options — `isSilent`
 *     suppresses the toast for a caller that shows the failure in its own UI, `isThrow` re-throws
 * @private
 */
function surfaceError(component, source, error, callOptions = {})
{
	const failureText = reduceErrors(error);

	component.consoleError(error, `${source}: ${failureText}`);

	if(!callOptions.isSilent)
	{
		component.dispatchEvent(new ShowToastEvent({
			title: ERROR_TITLE_LABEL, message: failureText, variant: 'error'
		}));
	}

	if(callOptions.isThrow)
	{
		const failedCallError = new Error(FAILED_CONTROLLER_CALL_ERROR);
		failedCallError.cause = error;
		throw failedCallError;
	}
}

/**
 * @description Reads `callControllerMethod`'s third argument, which accepts either the original
 * `isThrow` boolean or an options object (`{silent, isThrow}`). A boolean keeps its long-standing
 * meaning and never silences the toast; an options object lets a caller that renders the failure
 * in its own UI ask for the log entry without the toast.
 *
 * @param {boolean|{silent?: boolean, isThrow?: boolean}} options The third argument as supplied
 * @returns {{isThrow: boolean, isSilent: boolean}} The resolved options
 * @private
 */
function resolveCallOptions(options)
{
	if(typeof options === 'boolean')
	{
		return {isThrow: options, isSilent: false};
	}

	const {isThrow = false, silent = false} = options ?? {};

	return {isThrow, isSilent: silent};
}

// ── Module Initialisers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Wires the `callControllerMethod` function onto a component instance. The wired
 * method invokes an Apex controller and handles errors automatically: a failure is logged, shown
 * as a toast, and resolved as `undefined`. Its third argument is either the `isThrow` boolean
 * (re-throw the failure after logging) or an options object — `{silent: true}` keeps the log
 * entry and the `undefined` result but shows no toast, for a caller that reports the failure in
 * its own UI, and `{isThrow: true}` re-throws just as the boolean does.
 *
 * @param {Object} component The BaseComponent instance to enhance
 *
 * @example
 * const rows = await this.callControllerMethod(getLogEntries, {requestJson}, {silent: true});
 */
export const initialiseCallControllerMethod = function(component)
{
	component.callControllerMethod = (controllerMethod, parameterMap = {}, options = false) => controllerMethod(parameterMap)
	.catch((error) => surfaceError(component, CALL_CONTROLLER_METHOD_NAME, error, resolveCallOptions(options)));
};

/**
 * @description Wires the `handleWireResponse` function onto a component instance.
 * The wired method extracts data from a wire adapter result and handles errors.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialiseHandleWireResponse = function(component)
{
	component.handleWireResponse = ({error, data}) =>
	{
		if(error)
		{
			surfaceError(component, HANDLE_WIRE_RESPONSE_METHOD_NAME, error);
			return undefined;
		}

		return data ?? undefined;
	};
};

// ── Default Export ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Activates the controller module on a BaseComponent instance,
 * wiring both `callControllerMethod` and `handleWireResponse`.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export default function initialiseControllerModule(component)
{
	initialiseCallControllerMethod(component);
	initialiseHandleWireResponse(component);
}