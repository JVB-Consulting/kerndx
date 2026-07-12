// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainStepTimeline LWC component
 * @author Jason van Beukering
 * @date April 2026, May 2026
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
jest.mock('@salesforce/label/c.ChainMonitor_NoStepsRecorded', () => ({default: 'No steps recorded.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_Status', () => ({default: 'Status'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusCompleted', () => ({default: 'Completed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusContinued', () => ({default: 'Continued'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusFailed', () => ({default: 'Failed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusPending', () => ({default: 'Pending'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusRunning', () => ({default: 'Running'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StepTimelineTitle', () => ({default: 'Step Timeline'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_Yes', () => ({default: 'Yes'}), {virtual: true});

const MOCK_STEPS = [
	{name: 'Create Account', className: 'CreateAccountStep', stepStatus: 'success', durationLabel: '0.8s', errorMessage: null},
	{name: 'Call API', className: 'CallApiStep', stepStatus: 'warning', durationLabel: '2.1s', errorMessage: 'Non-fatal: skipped', continueOnError: true},
	{name: 'Send Notification', className: 'SendNotificationStep', stepStatus: 'pending', durationLabel: null, errorMessage: null}
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
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const icons = element.shadowRoot.querySelectorAll('lightning-icon');
		expect(icons.length).toBe(3);
	});

	it('should show step names', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const truncatedElements = element.shadowRoot.querySelectorAll('.slds-truncate');
		expect(truncatedElements[0].textContent).toContain('Create Account');
		expect(truncatedElements[1].textContent).toContain('Call API');
		expect(truncatedElements[2].textContent).toContain('Send Notification');
	});

	it('should show error message inline for failed steps', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const errorMsg = element.shadowRoot.querySelector('.slds-text-color_error');
		expect(errorMsg).toBeTruthy();
		expect(errorMsg.textContent).toContain('Non-fatal: skipped');
	});

	it('should show first pending step as running when chain is running', async() =>
	{
		const runningSteps = [
			{name: 'Step 1', className: 'Step1', stepStatus: 'success', durationLabel: '0.5s', errorMessage: null},
			{name: 'Step 2', className: 'Step2', stepStatus: 'pending', durationLabel: null, errorMessage: null},
			{name: 'Step 3', className: 'Step3', stepStatus: 'pending', durationLabel: null, errorMessage: null}
		];
		const element = await createComponent({steps: runningSteps, chainStatus: 'Running'});

		const icons = element.shadowRoot.querySelectorAll('lightning-icon');
		expect(icons[1].iconName).toBe('utility:spinner');
		expect(icons[2].iconName).toBe('utility:clock');
	});

	it('should show empty message when no steps', async() =>
	{
		const element = await createComponent({steps: [], chainStatus: 'Completed'});

		const emptyMsg = element.shadowRoot.querySelector('.slds-text-color_weak');
		expect(emptyMsg).toBeTruthy();
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

	it('should not load from controller when steps api property provided', async() =>
	{
		await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

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
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

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
		const element = await createComponent({steps: allStatuses, chainStatus: 'Completed'});

		const icons = element.shadowRoot.querySelectorAll('lightning-icon');
		expect(icons[0].iconName).toBe('utility:check');
		expect(icons[1].iconName).toBe('utility:warning');
		expect(icons[2].iconName).toBe('utility:close');
		expect(icons[3].iconName).toBe('utility:clock');
	});

	it('should render card with title', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const card = element.shadowRoot.querySelector('lightning-card');
		expect(card).toBeTruthy();
		expect(card.title).toBe('Step Timeline');
	});

	it('should show duration labels for completed steps', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const actionElements = element.shadowRoot.querySelectorAll('.slds-timeline__actions');
		const texts = Array.from(actionElements).map(el => el.textContent.trim());
		expect(texts).toContain('0.8s');
		expect(texts).toContain('2.1s');
	});

	it('should show status label for pending steps without duration', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const actionElements = element.shadowRoot.querySelectorAll('.slds-timeline__actions');
		const texts = Array.from(actionElements).map(el => el.textContent.trim());
		expect(texts).toContain('Pending');
	});

	it('should render hover popover with step metadata', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const popovers = element.shadowRoot.querySelectorAll('.step-popover');
		expect(popovers.length).toBe(3);

		const firstPopover = popovers[0];
		expect(firstPopover.textContent).toContain('CreateAccountStep');
		expect(firstPopover.textContent).toContain('Completed');
	});

	it('should show continueOnError in popover for warning steps', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const popovers = element.shadowRoot.querySelectorAll('.step-popover');
		const warningPopover = popovers[1];
		expect(warningPopover.textContent).toContain('Continue on Error');
		expect(warningPopover.textContent).toContain('Yes');
	});

	it('should show error message in popover for failed steps', async() =>
	{
		const element = await createComponent({steps: MOCK_STEPS, chainStatus: 'Completed'});

		const popovers = element.shadowRoot.querySelectorAll('.step-popover');
		const warningPopover = popovers[1];
		expect(warningPopover.textContent).toContain('Non-fatal: skipped');
	});

	it('should fall back to the pending mapping when stepStatus is unrecognised', async() =>
	{
		const unknownStatusSteps = [
			{name: 'S1', className: 'S1', stepStatus: 'mystery', durationLabel: null, errorMessage: null}
		];
		const element = await createComponent({steps: unknownStatusSteps, chainStatus: 'Completed'});

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
		const result = descriptor.get.call({steps: repeatedSteps, loadedSteps: [], isChainRunning: false});

		expect(new Set(result.map((step) => step.key)).size).toBe(repeatedSteps.length);
	});

	it('should render every occurrence of a repeated step class', async() =>
	{
		const repeatedSteps = [
			{name: 'Send Email', className: 'SendEmailStep', stepStatus: 'success', durationLabel: '1s', errorMessage: null},
			{name: 'Send Email', className: 'SendEmailStep', stepStatus: 'pending', durationLabel: null, errorMessage: null}
		];
		const element = await createComponent({steps: repeatedSteps, chainStatus: 'Completed'});

		expect(element.shadowRoot.querySelectorAll('[data-testid="step-row"]')).toHaveLength(repeatedSteps.length);
	});

	it('should use loaded chain status when chainStatus api property is absent', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({
			status: 'Running', steps: [
				{name: 'Loaded', className: 'LoadedStep', stepStatus: 'pending', durationLabel: null, errorMessage: null}
			]
		});
		const element = await createComponent({recordId: 'a00000000000099AAA'});

		const icon = element.shadowRoot.querySelector('lightning-icon');
		expect(icon.iconName).toBe('utility:spinner');
	});
});
