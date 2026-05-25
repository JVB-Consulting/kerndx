// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for flowFooter LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcFlowFooter, {BACK_NAVIGATION_EVENT, NEXT_NAVIGATION_EVENT} from 'c/flowFooter';

// Track message channel subscriptions
let mockSubscriptions = [];
let mockPublishedMessages = [];

// Mock ComponentBuilder to return a class with required functionality
jest.mock('c/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		// Return a mock LightningElement-like class
		const {LightningElement} = require('lwc');
		return class extends LightningElement
		{
			addMessageChannelSubscription(channel, handler)
			{
				mockSubscriptions.push({channel, handler});
			}

			publishLightningMessage(channel, message)
			{
				mockPublishedMessages.push({channel, message});
			}

			dispatchFlowBackEvent()
			{
				this.dispatchEvent(new CustomEvent('flowback'));
			}

			dispatchFlowNextEvent()
			{
				this.dispatchEvent(new CustomEvent('flownext'));
			}

			dispatchFlowFinishEvent()
			{
				this.dispatchEvent(new CustomEvent('flowfinish'));
			}
		};
	})
}), {virtual: true});

// Mock the message channel import
jest.mock('@salesforce/messageChannel/Navigation__c', () => ({
	default: 'NavigationChannel'
}), {virtual: true});

describe('c-flow-footer', () =>
{
	let element;

	beforeEach(() =>
	{
		mockSubscriptions = [];
		mockPublishedMessages = [];
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	/**
	 * Helper to create component and wait for render
	 */
	async function createComponent(props = {})
	{
		element = createElement('c-flow-footer', {
			is: LwcFlowFooter
		});
		Object.assign(element, props);
		document.body.appendChild(element);
		await Promise.resolve();
		return element;
	}

	describe('exported constants', () =>
	{
		it('should export BACK_NAVIGATION_EVENT constant', () =>
		{
			expect(BACK_NAVIGATION_EVENT).toBe('BACK');
		});

		it('should export NEXT_NAVIGATION_EVENT constant', () =>
		{
			expect(NEXT_NAVIGATION_EVENT).toBe('NEXT');
		});
	});

	describe('initial rendering', () =>
	{
		it('should render component successfully', async() =>
		{
			await createComponent();

			expect(element).toBeTruthy();
		});

		it('should render both Back and Next buttons by default', async() =>
		{
			await createComponent();

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			expect(buttons.length).toBe(2);
		});

		it('should render Next button with default title', async() =>
		{
			await createComponent();

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			const nextButton = buttons[1];
			expect(nextButton.label).toBe('Next');
		});

		it('should render Back button with default title', async() =>
		{
			await createComponent();

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			const backButton = buttons[0];
			expect(backButton.label).toBe('Back');
		});
	});

	describe('@api hideBackButton', () =>
	{
		it('should hide Back button when hideBackButton is true', async() =>
		{
			await createComponent({hideBackButton: true});

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			expect(buttons.length).toBe(1);
			expect(buttons[0].label).toBe('Next');
		});

		it('should show Back button when hideBackButton is false', async() =>
		{
			await createComponent({hideBackButton: false});

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			expect(buttons.length).toBe(2);
		});
	});

	describe('@api disableNext', () =>
	{
		it('should disable Next button when disableNext is true', async() =>
		{
			await createComponent({disableNext: true});

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			const nextButton = buttons[1];
			expect(nextButton.disabled).toBe(true);
		});

		it('should enable Next button when disableNext is false', async() =>
		{
			await createComponent({disableNext: false});

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			const nextButton = buttons[1];
			expect(nextButton.disabled).toBe(false);
		});
	});

	describe('@api isNextButtonDisabled', () =>
	{
		it('should disable Next button via isNextButtonDisabled setter', async() =>
		{
			await createComponent();

			element.isNextButtonDisabled = true;
			await Promise.resolve();

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			const nextButton = buttons[1];
			expect(nextButton.disabled).toBe(true);
		});

		it('should return current disabled state via getter', async() =>
		{
			await createComponent({disableNext: true});

			expect(element.isNextButtonDisabled).toBe(true);
		});
	});

	describe('@api nextTitle and previousTitle', () =>
	{
		it('should use custom next button title', async() =>
		{
			await createComponent({nextTitle: 'Continue'});

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			const nextButton = buttons[1];
			expect(nextButton.label).toBe('Continue');
		});

		it('should use custom previous button title', async() =>
		{
			await createComponent({previousTitle: 'Go Back'});

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			const backButton = buttons[0];
			expect(backButton.label).toBe('Go Back');
		});
	});

	describe('connectedCallback', () =>
	{
		it('should subscribe to message channel on connect', async() =>
		{
			await createComponent();

			expect(mockSubscriptions.length).toBe(1);
			expect(mockSubscriptions[0].channel).toBe('NavigationChannel');
		});

		it('should publish isReady message on connect', async() =>
		{
			await createComponent();

			expect(mockPublishedMessages.length).toBe(1);
			expect(mockPublishedMessages[0].message).toEqual({isReady: true});
		});

		it('should update nextDisabled when message received with disableNext', async() =>
		{
			await createComponent({disableNext: false});

			// Simulate message channel message
			const handler = mockSubscriptions[0].handler;
			handler({disableNext: true});
			await Promise.resolve();

			expect(element.isNextButtonDisabled).toBe(true);
		});

		it('should not update nextDisabled when message has no disableNext property', async() =>
		{
			await createComponent({disableNext: false});

			// Simulate message without disableNext
			const handler = mockSubscriptions[0].handler;
			handler({someOtherProperty: true});
			await Promise.resolve();

			expect(element.isNextButtonDisabled).toBe(false);
		});
	});

	describe('prevScreen - child component mode', () =>
	{
		it('should dispatch navigationevent with BACK when isChildComponent is true', async() =>
		{
			await createComponent({isChildComponent: true});

			const navigationHandler = jest.fn();
			element.addEventListener('navigationevent', navigationHandler);

			const backButton = element.shadowRoot.querySelectorAll('lightning-button')[0];
			backButton.click();
			await Promise.resolve();

			expect(navigationHandler).toHaveBeenCalledTimes(1);
			expect(navigationHandler.mock.calls[0][0].detail).toBe('BACK');
		});
	});

	describe('prevScreen - flow mode', () =>
	{
		it('should dispatch flowback event when not child and not override to finish', async() =>
		{
			await createComponent({isChildComponent: false, overridePreviousToFinish: false});

			const flowBackHandler = jest.fn();
			element.addEventListener('flowback', flowBackHandler);

			const backButton = element.shadowRoot.querySelectorAll('lightning-button')[0];
			backButton.click();
			await Promise.resolve();

			expect(flowBackHandler).toHaveBeenCalledTimes(1);
		});

		it('should dispatch flowfinish event when overridePreviousToFinish is true', async() =>
		{
			await createComponent({isChildComponent: false, overridePreviousToFinish: true});

			const flowFinishHandler = jest.fn();
			element.addEventListener('flowfinish', flowFinishHandler);

			const backButton = element.shadowRoot.querySelectorAll('lightning-button')[0];
			backButton.click();
			await Promise.resolve();

			expect(flowFinishHandler).toHaveBeenCalledTimes(1);
		});
	});

	describe('nextScreen - child component mode', () =>
	{
		it('should dispatch navigationevent with NEXT when isChildComponent is true', async() =>
		{
			await createComponent({isChildComponent: true});

			const navigationHandler = jest.fn();
			element.addEventListener('navigationevent', navigationHandler);

			const nextButton = element.shadowRoot.querySelectorAll('lightning-button')[1];
			nextButton.click();
			await Promise.resolve();

			expect(navigationHandler).toHaveBeenCalledTimes(1);
			expect(navigationHandler.mock.calls[0][0].detail).toBe('NEXT');
		});
	});

	describe('nextScreen - flow mode', () =>
	{
		it('should dispatch flownext event when not child and not override to finish', async() =>
		{
			await createComponent({isChildComponent: false, overrideNextToFinish: false});

			const flowNextHandler = jest.fn();
			element.addEventListener('flownext', flowNextHandler);

			const nextButton = element.shadowRoot.querySelectorAll('lightning-button')[1];
			nextButton.click();
			await Promise.resolve();

			expect(flowNextHandler).toHaveBeenCalledTimes(1);
		});

		it('should dispatch flowfinish event when overrideNextToFinish is true', async() =>
		{
			await createComponent({isChildComponent: false, overrideNextToFinish: true});

			const flowFinishHandler = jest.fn();
			element.addEventListener('flowfinish', flowFinishHandler);

			const nextButton = element.shadowRoot.querySelectorAll('lightning-button')[1];
			nextButton.click();
			await Promise.resolve();

			expect(flowFinishHandler).toHaveBeenCalledTimes(1);
		});
	});

	describe('button styling', () =>
	{
		it('should use brand variant for both buttons', async() =>
		{
			await createComponent();

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			expect(buttons[0].variant).toBe('brand');
			expect(buttons[1].variant).toBe('brand');
		});

		it('should have margin class on Next button', async() =>
		{
			await createComponent();

			const buttons = element.shadowRoot.querySelectorAll('lightning-button');
			const nextButton = buttons[1];
			expect(nextButton.classList.contains('slds-m-left_small')).toBe(true);
		});
	});
});
