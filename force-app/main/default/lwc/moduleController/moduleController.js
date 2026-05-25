// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller module for the ComponentBuilder framework. Provides Apex controller
 * method invocation with automatic error handling and wire response extraction.
 *
 * @author Jason van Beukering
 *
 * @date February 2022, May 2026
 */
import {reduceErrors} from 'c/utilitySystem';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

// ── Constants ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

export const FAILED_CONTROLLER_CALL_ERROR = 'Failed controller call';
export const CALL_CONTROLLER_METHOD_NAME = 'callControllerMethod';
export const HANDLE_WIRE_RESPONSE_METHOD_NAME = 'handleWireResponse';

// ── Internal Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Surfaces an Apex error to the user via toast and structured logging,
 * optionally re-throwing to allow upstream catch handling.
 *
 * @param {Object} component The BaseComponent instance
 * @param {string} source Identifier of the method that failed
 * @param {Error|Object} error The error from the Apex call
 * @param {boolean} shouldThrow When true, re-throws after logging
 * @private
 */
function surfaceError(component, source, error, shouldThrow = false)
{
	component.consoleError(error, `${source}: `);

	component.dispatchEvent(new ShowToastEvent({
		title: 'Error', message: reduceErrors(error), variant: 'error'
	}));

	if(shouldThrow)
	{
		throw new Error(FAILED_CONTROLLER_CALL_ERROR);
	}
}

// ── Module Initialisers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Wires the `callControllerMethod` function onto a component instance.
 * The wired method invokes an Apex controller and handles errors automatically.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialiseCallControllerMethod = function(component)
{
	component.callControllerMethod = (controllerMethod, parameterMap = {}, isThrow = false) => controllerMethod(parameterMap)
	.catch((error) => surfaceError(component, CALL_CONTROLLER_METHOD_NAME, error, isThrow));
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