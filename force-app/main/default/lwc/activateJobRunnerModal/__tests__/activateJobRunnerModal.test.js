// SPDX-License-Identifier: Apache-2.0
/**
 * @description Jest unit tests for activateJobRunnerModal LWC component.
 *
 * @author Jason van Beukering
 * @date September 2026, October 2026
 */

jest.mock('@salesforce/label/c.HealthCheck_JobRunner_CheckFrequencyOptions', () => ({
	default: 'Every hour (1 slot)=60|Every 30 minutes (2 slots)=30|Every 15 minutes (4 slots)=15|Every 10 minutes (6 slots)=10|Every 5 minutes (12 slots)=5'
}), {virtual: true});

// Restore the real English values for the bundle's labels (the default sfdx-lwc-jest stub
// resolves each to the bare string 'c.<Name>') so rendering assertions verify the shipped copy.
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_ModalTitle', () => ({default: 'Activate the job runner'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_ModalSubtitle', () => ({
	default: 'Choose how often the runner checks for due jobs. Each choice costs a fixed number of the org\'s 100 scheduled-job slots; every job you put on the '
			+ 'runner is then free.'
}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_CheckFrequencyLabel', () => ({default: 'Check for due jobs'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_RunsAsNote', () => ({
	default: 'The runner\'s jobs will run as you ({0}). Deactivate and activate again as a different user to change this.'
}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_ConfirmButton', () => ({default: 'Activate'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_Cancel', () => ({default: 'Cancel'}), {virtual: true});

const DEFAULT_INTERVAL_MINUTES = '15';
const HOURLY_INTERVAL_MINUTES = '60';
const FASTEST_INTERVAL_MINUTES = '5';

describe('c-activate-job-runner-modal', () =>
{
	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const ActivateJobRunnerModal = require('c/activateJobRunnerModal').default;
			expect(ActivateJobRunnerModal).toBeDefined();
			expect(typeof ActivateJobRunnerModal).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const ActivateJobRunnerModal = require('c/activateJobRunnerModal').default;
		const prototype = ActivateJobRunnerModal.prototype;

		it('has @api runningUserName property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'runningUserName');
			expect(descriptor).toBeDefined();
		});

		it('has checkIntervalOptions getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'checkIntervalOptions');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has runsAsNote getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'runsAsNote');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has showRunsAsNote getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'showRunsAsNote');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has connectedCallback method', () =>
		{
			expect(typeof prototype.connectedCallback).toBe('function');
		});

		it('has handleCheckIntervalChange method', () =>
		{
			expect(typeof prototype.handleCheckIntervalChange).toBe('function');
		});

		it('has handleConfirm method', () =>
		{
			expect(typeof prototype.handleConfirm).toBe('function');
		});

		it('has handleCancel method', () =>
		{
			expect(typeof prototype.handleCancel).toBe('function');
		});
	});

	describe('instance behavior', () =>
	{
		const ActivateJobRunnerModal = require('c/activateJobRunnerModal').default;
		const prototype = ActivateJobRunnerModal.prototype;

		const getGetter = (name) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, name).get;
		};

		const createMockContext = (overrides = {}) =>
		{
			let context = {runningUserName: 'Admin', selectedIntervalMinutes: DEFAULT_INTERVAL_MINUTES, close: jest.fn(), ...overrides};
			if(!Object.prototype.hasOwnProperty.call(overrides, 'checkIntervalOptions'))
			{
				Object.defineProperty(context, 'checkIntervalOptions', Object.getOwnPropertyDescriptor(prototype, 'checkIntervalOptions'));
			}
			return context;
		};

		describe('checkIntervalOptions', () =>
		{
			it('parses the pipe-delimited label=minutes tokens into the five {label, value} options', () =>
			{
				let context = createMockContext();
				let options = getGetter('checkIntervalOptions').call(context);

				expect(options).toEqual([
					{label: 'Every hour (1 slot)', value: HOURLY_INTERVAL_MINUTES},
					{label: 'Every 30 minutes (2 slots)', value: '30'},
					{label: 'Every 15 minutes (4 slots)', value: DEFAULT_INTERVAL_MINUTES},
					{label: 'Every 10 minutes (6 slots)', value: '10'},
					{label: 'Every 5 minutes (12 slots)', value: FASTEST_INTERVAL_MINUTES}
				]);
			});
		});

		describe('runsAsNote', () =>
		{
			it('names the user the runner will run its jobs as', () =>
			{
				let context = createMockContext({runningUserName: 'Priya Raman'});

				expect(getGetter('runsAsNote').call(context))
				.toBe('The runner\'s jobs will run as you (Priya Raman). Deactivate and activate again as a different user to change this.');
			});

			it('is shown only when a name arrived', () =>
			{
				expect(getGetter('showRunsAsNote').call(createMockContext())).toBe(true);
				expect(getGetter('showRunsAsNote').call(createMockContext({runningUserName: undefined}))).toBe(false);
			});
		});

		describe('connectedCallback', () =>
		{
			it('keeps the fifteen-minute default because the options offer it', () =>
			{
				let context = createMockContext();

				prototype.connectedCallback.call(context);

				expect(context.selectedIntervalMinutes).toBe(DEFAULT_INTERVAL_MINUTES);
			});

			it('falls back to the first option when the options no longer offer the default', () =>
			{
				let context = createMockContext({
					checkIntervalOptions: [
						{label: 'Every hour (1 slot)', value: HOURLY_INTERVAL_MINUTES}
					]
				});

				prototype.connectedCallback.call(context);

				expect(context.selectedIntervalMinutes).toBe(HOURLY_INTERVAL_MINUTES);
			});
		});

		describe('handleCheckIntervalChange', () =>
		{
			it('updates the selected check interval from the combobox event', () =>
			{
				let context = createMockContext();

				prototype.handleCheckIntervalChange.call(context, {detail: {value: FASTEST_INTERVAL_MINUTES}});

				expect(context.selectedIntervalMinutes).toBe(FASTEST_INTERVAL_MINUTES);
			});
		});

		describe('handleConfirm', () =>
		{
			it('closes with the chosen check interval on confirm', () =>
			{
				let context = createMockContext();

				prototype.connectedCallback.call(context);
				prototype.handleCheckIntervalChange.call(context, {detail: {value: FASTEST_INTERVAL_MINUTES}});
				prototype.handleConfirm.call(context);

				expect(context.close).toHaveBeenCalledWith({action: 'confirm', intervalMinutes: FASTEST_INTERVAL_MINUTES});
			});
		});

		describe('handleCancel', () =>
		{
			it('closes with cancel and no check interval', () =>
			{
				let context = createMockContext();

				prototype.handleCancel.call(context);

				expect(context.close).toHaveBeenCalledWith({action: 'cancel'});
			});
		});
	});

	describe('DOM rendering', () =>
	{
		const mount = (runningUserName) =>
		{
			const {createElement} = require('lwc');
			const ActivateJobRunnerModal = require('c/activateJobRunnerModal').default;
			let element = createElement('c-activate-job-runner-modal', {is: ActivateJobRunnerModal});
			element.runningUserName = runningUserName;
			document.body.appendChild(element);
			return element;
		};

		afterEach(() =>
		{
			while(document.body.firstChild)
			{
				document.body.removeChild(document.body.firstChild);
			}
		});

		it('offers the five check intervals with fifteen minutes preselected and names who the jobs will run as', () =>
		{
			let element = mount('Admin');

			let combobox = element.shadowRoot.querySelector('[data-testid="activate-job-runner-check-interval"]');
			expect(combobox.options.map((option) => option.value)).toEqual([
				'60',
				'30',
				'15',
				'10',
				'5'
			]);
			expect(combobox.value).toBe(DEFAULT_INTERVAL_MINUTES);
			expect(element.shadowRoot.querySelector('[data-testid="activate-job-runner-runs-as"]').textContent)
			.toBe('The runner\'s jobs will run as you (Admin). Deactivate and activate again as a different user to change this.');
		});

		it('hides the running-user note when no name arrived', () =>
		{
			let element = mount(undefined);

			expect(element.shadowRoot.querySelector('[data-testid="activate-job-runner-runs-as"]')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="activate-job-runner-check-interval"]')).not.toBeNull();
		});

		it('renders the real label values on the header, the body and the footer', () =>
		{
			let element = mount('Admin');

			expect(element.shadowRoot.querySelector('[data-testid="activate-job-runner-title"]').label).toBe('Activate the job runner');
			expect(element.shadowRoot.querySelector('[data-testid="activate-job-runner-subtitle"]').textContent).toContain('Choose how often the runner checks for due jobs.');
			expect(element.shadowRoot.querySelector('[data-testid="activate-job-runner-check-interval"]').label).toBe('Check for due jobs');
			expect(element.shadowRoot.querySelector('[data-testid="activate-job-runner-confirm"]').label).toBe('Activate');
			expect(element.shadowRoot.querySelector('[data-testid="cancel-button"]').label).toBe('Cancel');
			expect(element.shadowRoot.querySelector('[data-testid="activate-job-runner-root"]')).not.toBeNull();
		});
	});
});
