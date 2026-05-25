// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Flow Navigation module for the ComponentBuilder framework. Provides
 * dispatch methods for flow screen navigation events (next, back, finish).
 *
 * @author Jason van Beukering
 *
 * @date February 2022, May 2026
 */
import {FlowNavigationBackEvent, FlowNavigationFinishEvent, FlowNavigationNextEvent} from 'lightning/flowSupport';

// ── Flow Event Registry ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Maps flow navigation directions to their corresponding event constructors.
 * @type {Readonly<Map<string, Function>>}
 * @private
 */
const FLOW_EVENT_CONSTRUCTORS = Object.freeze(new Map([
	[
		'next',
		FlowNavigationNextEvent
	],
	[
		'back',
		FlowNavigationBackEvent
	],
	[
		'finish',
		FlowNavigationFinishEvent
	]
]));

// ── Internal Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Creates and dispatches the flow navigation event for the given direction.
 *
 * @param {Object} component The BaseComponent instance
 * @param {string} direction The navigation direction key ('next', 'back', or 'finish')
 * @private
 */
function dispatchFlowEvent(component, direction)
{
	/** @type {new() => Event} */
	const eventConstructor = FLOW_EVENT_CONSTRUCTORS.get(direction);
	component.dispatchEvent(new eventConstructor());
}

// ── Module Initialisers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Wires the `dispatchFlowNextEvent` method onto a component instance.
 * Dispatches a FlowNavigationNextEvent to advance the flow to the next screen.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialiseDispatchFlowNextEventMethod = function(component)
{
	component.dispatchFlowNextEvent = () => dispatchFlowEvent(component, 'next');
};

/**
 * @description Wires the `dispatchFlowBackEvent` method onto a component instance.
 * Dispatches a FlowNavigationBackEvent to return to the previous flow screen.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialiseDispatchFlowBackEventMethod = function(component)
{
	component.dispatchFlowBackEvent = () => dispatchFlowEvent(component, 'back');
};

/**
 * @description Wires the `dispatchFlowFinishEvent` method onto a component instance.
 * Dispatches a FlowNavigationFinishEvent to complete the flow.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialiseDispatchFlowFinishEventMethod = function(component)
{
	component.dispatchFlowFinishEvent = () => dispatchFlowEvent(component, 'finish');
};

// ── Default Export ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Activates the flow navigation module on a BaseComponent instance,
 * wiring next, back, and finish dispatch methods.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export default function initialiseFlowNavigationModule(component)
{
	initialiseDispatchFlowNextEventMethod(component);
	initialiseDispatchFlowBackEventMethod(component);
	initialiseDispatchFlowFinishEventMethod(component);
}