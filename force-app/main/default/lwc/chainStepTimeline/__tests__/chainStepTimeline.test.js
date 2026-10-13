// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainStepTimeline LWC component
 * @author Jason van Beukering
 * @date April 2026, October 2026
 */

import {createElement} from 'lwc';
import ChainStepTimeline from 'c/chainStepTimeline';
import {mockCallControllerMethod} from 'c/componentBuilder';

// Custom Label mocks — values byte-equal the real CustomLabels entries so DOM
// text assertions exercise the shipped text.
jest.mock('@salesforce/label/c.ChainMonitor_ClassLabel', () => ({default: 'Class'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ContinueOnErrorLabel', () => ({default: 'Continue on Error'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_Duration', () => ({default: 'Duration'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ErrorSection', () => ({default: 'Error'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_LoadingSteps', () => ({default: 'Loading steps'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ManualRetryMarker', () => ({default: 'Retried manually'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ManualRetryMarkerAfter', () => ({default: 'Retried manually after {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_NoStepsRecorded', () => ({default: 'No steps recorded.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_Status', () => ({default: 'Status'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusCompleted', () => ({default: 'Completed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusContinued', () => ({default: 'Continued'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusDidNotRun', () => ({default: 'Did not run'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusFailed', () => ({default: 'Failed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusNoResultRecorded', () => ({default: 'No result recorded'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusPending', () => ({default: 'Pending'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusRunning', () => ({default: 'Running'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StepTimelineTitle', () => ({default: 'Step Timeline'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_Yes', () => ({default: 'Yes'}), {virtual: true});

const MOCK_STEPS = [
	{name: 'Create Account', className: 'CreateAccountStep', stepStatus: 'success', durationLabel: '0.8s', errorMessage: null},
	{name: 'Call API', className: 'CallApiStep', stepStatus: 'warning', durationLabel: '2.1s', errorMessage: 'Non-fatal: skipped', continueOnError: true},
	{name: 'Send Notification', className: 'SendNotificationStep', stepStatus: 'pending', durationLabel: null, errorMessage: null}
];

const RETRIED_STEPS = [
	{name: 'Create Account', className: 'CreateAccountStep', stepStatus: 'success', durationLabel: '0.8s', errorMessage: null, manuallyRetried: false},
	{name: 'Call API', className: 'CallApiStep', stepStatus: 'success', durationLabel: '2.1s', errorMessage: null, manuallyRetried: true, manualRetryAfterLabel: '37m'},
	{
		name: 'Reconcile',
		className: 'ReconcileStep',
		stepStatus: 'failed',
		durationLabel: '0.5s',
		errorMessage: 'Refused',
		continueOnError: false,
		manuallyRetried: true,
		manualRetryAfterLabel: null
	},
	{name: 'Send Receipt', className: 'SendReceiptStep', stepStatus: 'pending', durationLabel: null, errorMessage: null, manuallyRetried: false}
];

// A retried step that crashed again: the marker sits above a step the ended run recorded no result for.
const RETRIED_AND_CRASHED_STEPS = [
	{name: 'Create Account', className: 'CreateAccountStep', stepStatus: 'success', durationLabel: '0.8s', errorMessage: null, manuallyRetried: false},
	{
		name: 'Call Billing API',
		className: 'CallBillingApiStep',
		stepStatus: 'noResultRecorded',
		durationLabel: null,
		errorMessage: null,
		manuallyRetried: true,
		manualRetryAfterLabel: '37m'
	},
	{name: 'Send Receipt', className: 'SendReceiptStep', stepStatus: 'didNotRun', durationLabel: null, errorMessage: null, manuallyRetried: false}
];

const MOCK_CHAIN_DETAIL = {
	status: 'Completed', steps: [
		{name: 'Step A', className: 'StepA', stepStatus: 'success', durationLabel: '1s', errorMessage: null},
		{name: 'Step B', className: 'StepB', stepStatus: 'failed', durationLabel: '0.5s', errorMessage: 'Error occurred'}
	]
};

describe('c-chain-step-timeline', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function createComponent(props = {})
	{
		const element = createElement('c-chain-step-timeline', {is: ChainStepTimeline});
		Object.assign(element, props);
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		return element;
	}

	it('should render steps from api property', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const icons = element.shadowRoot.querySelectorAll('lightning-icon');
		expect(icons.length).toBe(3);
	});

	it('should show step names', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const truncatedElements = element.shadowRoot.querySelectorAll('.slds-truncate');
		expect(truncatedElements[0].textContent).toContain('Create Account');
		expect(truncatedElements[1].textContent).toContain('Call API');
		expect(truncatedElements[2].textContent).toContain('Send Notification');
	});

	it('should show error message inline for failed steps', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const errorMsg = element.shadowRoot.querySelector('.slds-text-color_error');
		expect(errorMsg).toBeTruthy();
		expect(errorMsg.textContent).toContain('Non-fatal: skipped');
	});

	it('should spin the icon of the step the controller sends as running, and only that one', async() =>
	{
		const runningSteps = [
			{name: 'Step 1', className: 'Step1', stepStatus: 'success', durationLabel: '0.5s', errorMessage: null},
			{name: 'Step 2', className: 'Step2', stepStatus: 'running', durationLabel: null, errorMessage: null},
			{name: 'Step 3', className: 'Step3', stepStatus: 'pending', durationLabel: null, errorMessage: null}
		];
		const element = await createComponent({steps: runningSteps});

		const icons = element.shadowRoot.querySelectorAll('lightning-icon');
		expect(icons[1].iconName).toBe('utility:spinner');
		expect(icons[1].classList.contains('icon-spinning')).toBe(true);
		expect(icons[2].iconName).toBe('utility:clock');
		expect(icons[2].classList.contains('icon-spinning')).toBe(false);
	});

	it('should show empty message when no steps', async() =>
	{
		const element = await createComponent({steps: []});

		const emptyMsg = element.shadowRoot.querySelector('.slds-text-color_weak');
		expect(emptyMsg).toBeTruthy();
		expect(emptyMsg.textContent).toBe('No steps recorded.');
	});

	it('should show the empty message when the loaded detail carries no steps at all', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({status: 'Completed'});
		const element = await createComponent({recordId: 'a00000000000001AAA'});

		const emptyMsg = element.shadowRoot.querySelector('.slds-text-color_weak');
		expect(emptyMsg.textContent).toBe('No steps recorded.');
	});

	it('should load steps from controller when recordId provided', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_CHAIN_DETAIL);
		const element = await createComponent({recordId: 'a00000000000001AAA'});

		expect(mockCallControllerMethod).toHaveBeenCalledWith(expect.any(Function), {executionId: 'a00000000000001AAA'});

		const icons = element.shadowRoot.querySelectorAll('lightning-icon');
		expect(icons.length).toBe(2);
	});

	it('names its spinner for assistive users while the run\'s steps are still being fetched', async() =>
	{
		// A fetch that never settles holds the component in its loading state for the assertion.
		mockCallControllerMethod.mockReturnValue(new Promise(() => undefined));
		const element = await createComponent({recordId: 'a00000000000001AAA'});

		const spinner = element.shadowRoot.querySelector('lightning-spinner');
		expect(spinner.alternativeText).toBe('Loading steps');
		expect(element.shadowRoot.querySelector('lightning-card')).toBeNull();
	});

	it('should not load from controller when steps api property provided', async() =>
	{
		await createComponent({steps: MOCK_STEPS});

		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	it('should reload data on refresh api call', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_CHAIN_DETAIL);
		const element = await createComponent({recordId: 'a00000000000001AAA'});
		mockCallControllerMethod.mockClear();

		await element.refresh();

		expect(mockCallControllerMethod).toHaveBeenCalled();
	});

	it('should not reload on refresh when no recordId', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		await element.refresh();

		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	it('should use correct icons for each status', async() =>
	{
		const allStatuses = [
			{name: 'S1', className: 'S1', stepStatus: 'success', durationLabel: '1s', errorMessage: null},
			{name: 'S2', className: 'S2', stepStatus: 'warning', durationLabel: '1s', errorMessage: 'warn'},
			{name: 'S3', className: 'S3', stepStatus: 'failed', durationLabel: '1s', errorMessage: 'fail'},
			{name: 'S4', className: 'S4', stepStatus: 'pending', durationLabel: null, errorMessage: null}
		];
		const element = await createComponent({steps: allStatuses});

		const icons = element.shadowRoot.querySelectorAll('lightning-icon');
		expect(icons[0].iconName).toBe('utility:check');
		expect(icons[1].iconName).toBe('utility:warning');
		expect(icons[2].iconName).toBe('utility:close');
		expect(icons[3].iconName).toBe('utility:clock');
	});

	it('should render card with title', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const card = element.shadowRoot.querySelector('lightning-card');
		expect(card).toBeTruthy();
		expect(card.title).toBe('Step Timeline');
	});

	it('should show duration labels for completed steps', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const actionElements = element.shadowRoot.querySelectorAll('.slds-timeline__actions');
		const texts = Array.from(actionElements).map(el => el.textContent.trim());
		expect(texts).toContain('0.8s');
		expect(texts).toContain('2.1s');
	});

	it('should show status label for pending steps without duration', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const actionElements = element.shadowRoot.querySelectorAll('.slds-timeline__actions');
		const texts = Array.from(actionElements).map(el => el.textContent.trim());
		expect(texts).toContain('Pending');
	});

	it('should render hover popover with step metadata', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const popovers = element.shadowRoot.querySelectorAll('.step-popover');
		expect(popovers.length).toBe(3);

		const firstPopover = popovers[0];
		expect(firstPopover.textContent).toContain('CreateAccountStep');
		expect(firstPopover.textContent).toContain('Completed');
	});

	it('should show continueOnError in popover for warning steps', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const popovers = element.shadowRoot.querySelectorAll('.step-popover');
		const warningPopover = popovers[1];
		expect(warningPopover.textContent).toContain('Continue on Error');
		expect(warningPopover.textContent).toContain('Yes');
	});

	it('should show error message in popover for failed steps', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS});

		const popovers = element.shadowRoot.querySelectorAll('.step-popover');
		const warningPopover = popovers[1];
		expect(warningPopover.textContent).toContain('Non-fatal: skipped');
	});

	it('should fall back to the pending mapping when stepStatus is unrecognised', async() =>
	{
		const unknownStatusSteps = [
			{name: 'S1', className: 'S1', stepStatus: 'mystery', durationLabel: null, errorMessage: null}
		];
		const element = await createComponent({steps: unknownStatusSteps});

		const icon = element.shadowRoot.querySelector('lightning-icon');
		expect(icon.iconName).toBe('utility:clock');

		const action = element.shadowRoot.querySelector('.slds-timeline__actions');
		expect(action.textContent.trim()).toBe('Pending');
	});

	it('should assign unique row keys when the same step class and name repeat in a chain', () =>
	{
		const repeatedSteps = [
			{name: 'Send Email', className: 'SendEmailStep', stepStatus: 'success', durationLabel: '1s', errorMessage: null},
			{name: 'Send Email', className: 'SendEmailStep', stepStatus: 'pending', durationLabel: null, errorMessage: null}
		];
		const descriptor = Object.getOwnPropertyDescriptor(ChainStepTimeline.prototype, 'displaySteps');
		const result = descriptor.get.call({steps: repeatedSteps, loadedSteps: []});

		expect(new Set(result.map((step) => step.key)).size).toBe(repeatedSteps.length);
	});

	it('should render every occurrence of a repeated step class', async() =>
	{
		const repeatedSteps = [
			{name: 'Send Email', className: 'SendEmailStep', stepStatus: 'success', durationLabel: '1s', errorMessage: null},
			{name: 'Send Email', className: 'SendEmailStep', stepStatus: 'pending', durationLabel: null, errorMessage: null}
		];
		const element = await createComponent({steps: repeatedSteps});

		expect(element.shadowRoot.querySelectorAll('[data-testid="step-row"]')).toHaveLength(repeatedSteps.length);
	});

	it('should map the words of the steps loaded from the controller', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({
			status: 'Running', steps: [
				{name: 'Loaded', className: 'LoadedStep', stepStatus: 'running', durationLabel: null, errorMessage: null}
			]
		});
		const element = await createComponent({recordId: 'a00000000000099AAA'});

		const icon = element.shadowRoot.querySelector('lightning-icon');
		expect(icon.iconName).toBe('utility:spinner');
	});

	describe('the manual retry marker', () =>
	{
		it('should show the manual retry marker with its wait above a retried step that went on to succeed', async() =>
		{
			const element = await createComponent({steps: RETRIED_STEPS});

			const markers = element.shadowRoot.querySelectorAll('[data-testid="manual-retry-marker"]');
			expect(markers[0].textContent.trim()).toBe('Retried manually after 37m');
			expect(markers[0].parentElement.querySelector('[data-testid="step-row"]').textContent).toContain('Call API');
			expect(markers[0].nextElementSibling.querySelector('[data-testid="step-row"]').textContent).toContain('Call API');
		});

		it('should show the manual retry marker without a wait when the wait is unknown', async() =>
		{
			const element = await createComponent({steps: RETRIED_STEPS});

			const markers = element.shadowRoot.querySelectorAll('[data-testid="manual-retry-marker"]');
			expect(markers[1].textContent.trim()).toBe('Retried manually');
		});

		it('should show one marker per retried step and leave the rows and icons as they were', async() =>
		{
			const element = await createComponent({steps: RETRIED_STEPS});

			expect(element.shadowRoot.querySelectorAll('[data-testid="manual-retry-marker"]').length).toBe(2);
			expect(element.shadowRoot.querySelectorAll('[data-testid="step-row"]').length).toBe(4);
			expect(element.shadowRoot.querySelectorAll('lightning-icon').length).toBe(4);
		});

		it('should show no marker on a run nobody retried', async() =>
		{
			const element = await createComponent({steps: MOCK_STEPS});

			expect(element.shadowRoot.querySelectorAll('[data-testid="manual-retry-marker"]').length).toBe(0);
		});

		it('should show the manual retry marker above a step the run recorded no result for', async() =>
		{
			const element = await createComponent({steps: RETRIED_AND_CRASHED_STEPS});

			const markers = element.shadowRoot.querySelectorAll('[data-testid="manual-retry-marker"]');
			const texts = Array.from(element.shadowRoot.querySelectorAll('.slds-timeline__actions')).map(el => el.textContent.trim());
			expect(markers.length).toBe(1);
			expect(markers[0].textContent.trim()).toBe('Retried manually after 37m');
			expect(markers[0].parentElement.querySelector('[data-testid="step-row"]').textContent).toContain('Call Billing API');
			expect(texts[1]).toBe('No result recorded');
		});
	});

	describe('the icon, colour and label each status word maps to', () =>
	{
		it.each([
			[
				'success',
				'utility:check',
				'success',
				'Completed'
			],
			[
				'warning',
				'utility:warning',
				'warning',
				'Continued'
			],
			[
				'failed',
				'utility:close',
				'error',
				'Failed'
			],
			[
				'pending',
				'utility:clock',
				'neutral',
				'Pending'
			],
			[
				'running',
				'utility:spinner',
				'brand',
				'Running'
			],
			[
				'noResultRecorded',
				'utility:question',
				'neutral',
				'No result recorded'
			],
			[
				'didNotRun',
				'utility:dash',
				'neutral',
				'Did not run'
			]
		])('should show the %s word with icon %s, variant %s and label %s', async(stepStatus, iconName, variant, label) =>
		{
			const element = await createComponent({steps: [{name: 'S1', className: 'S1', stepStatus, durationLabel: null, errorMessage: null}]});

			const icon = element.shadowRoot.querySelector('lightning-icon');
			expect(icon.iconName).toBe(iconName);
			expect(icon.variant).toBe(variant);
			expect(icon.alternativeText).toBe(label);
			expect(element.shadowRoot.querySelector('.slds-timeline__actions').textContent.trim()).toBe(label);
		});
	});
});
