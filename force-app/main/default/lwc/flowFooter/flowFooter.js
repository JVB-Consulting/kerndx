// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Common flow footer component for screen flows. Can be used directly on a
 * flow screen or extended within a parent LWC for custom navigation logic. Subscribes to
 * the Navigation message channel to receive dynamic button state changes and publishes an
 * `isReady` signal on connect.
 *
 * @event navigationevent {detail: eventName} Indicates whether the Back or Next button
 * was clicked. `eventName` values are either 'NEXT' or 'BACK'.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, May 2026
 */
import MC_NAV from '@salesforce/messageChannel/Navigation__c';
import {ComponentBuilder} from 'c/componentBuilder';
import {api} from 'lwc';

export const BACK_NAVIGATION_EVENT = 'BACK';
export const NEXT_NAVIGATION_EVENT = 'NEXT';

/**
 * @description Resolves the navigation action for a given direction based on component
 * mode and override flags. Returns a callback that, when invoked on the component
 * context, dispatches the correct flow or custom event.
 * @param {string} direction - Either 'BACK' or 'NEXT'
 * @param {boolean} isChildComponent - Whether the footer is used inside a parent LWC
 * @param {boolean} overrideToFinish - Whether this direction should dispatch a finish event
 * @returns {Function} Action to invoke on the component instance
 */
function resolveNavigationAction(direction, isChildComponent, overrideToFinish)
{
	if(isChildComponent)
	{
		return (context) => context.dispatchNavigationEvent(direction);
	}

	if(overrideToFinish)
	{
		return (context) => context.dispatchFlowFinishEvent();
	}

	return direction === BACK_NAVIGATION_EVENT ? (context) => context.dispatchFlowBackEvent() : (context) => context.dispatchFlowNextEvent();
}

export default class FlowFooter extends ComponentBuilder('lightning-message', 'flow-navigation')
{
	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Hides 'Back' button when set to true
	 * @type {boolean}
	 */
	@api hideBackButton = false;

	/**
	 * @description Initialises 'Next' button usability when the component loads. Disables 'Next' button when set to true. To make the 'Next' button disabled
	 * during runtime, use the isNextButtonDisabled property (HTML attribute: is-next-button-disabled).
	 * @type {boolean}
	 */
	@api disableNext = false;

	/**
	 * @description Overrides the title of the 'Next' button.
	 * @type {string}
	 */
	@api nextTitle = 'Next';

	/**
	 * @description Overrides the title of the 'Back' button.
	 * @type {string}
	 */
	@api previousTitle = 'Back';

	/**
	 * @description Causes the 'Back' button to dispatch a FlowNavigationFinishEvent event when set to true.
	 * @type {boolean}
	 */
	@api overridePreviousToFinish = false;

	/**
	 * @description Causes the 'Next' button to dispatch a FlowNavigationFinishEvent event when set to true.
	 * @type {boolean}
	 */
	@api overrideNextToFinish = false;

	/**
	 * @description Set to True when this component is inside a parent LWC to manually handle flow Events.
	 * @type {boolean}
	 */
	@api isChildComponent = false;

	// ── Internal State ───────────────────────────────────────────────────

	/**
	 * @description Tracks whether the Next button is currently disabled.
	 * @type {boolean}
	 */
	nextButtonDisabledState;

	// ── Computed Properties ──────────────────────────────────────────────

	get isNextButtonDisabled()
	{
		return this.nextButtonDisabledState;
	}

	@api set isNextButtonDisabled(value)
	{
		this.nextButtonDisabledState = value;
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	connectedCallback()
	{
		this.nextButtonDisabledState = this.disableNext;
		this.addMessageChannelSubscription(MC_NAV, (message) =>
		{
			if('disableNext' in message)
			{
				this.nextButtonDisabledState = message.disableNext;
			}
		});

		this.publishLightningMessage(MC_NAV, {isReady: true});
	}

	// ── Navigation Handlers ──────────────────────────────────────────────

	/**
	 * @description Dispatches relevant event when the Back button is clicked. Will emit a custom event if component is a child component, but will emit a flow
	 * event otherwise.
	 */
	prevScreen()
	{
		resolveNavigationAction(BACK_NAVIGATION_EVENT, this.isChildComponent, this.overridePreviousToFinish)(this);
	}

	/**
	 * @description Dispatches relevant event when the Next button is clicked. Will emit a custom event if component is a child component, but will emit a flow
	 * event otherwise.
	 */
	nextScreen()
	{
		resolveNavigationAction(NEXT_NAVIGATION_EVENT, this.isChildComponent, this.overrideNextToFinish)(this);
	}

	/**
	 * @description Dispatch a custom 'navigationevent' event for the parent component when a next or back button is clicked.
	 * Used as an event to implement custom navigation logic from a parent component.
	 * @param {'BACK' | 'NEXT'} eventName Possible events to be dispatched.
	 */
	dispatchNavigationEvent(eventName)
	{
		this.dispatchEvent(new CustomEvent('navigationevent', {detail: eventName}));
	}
}