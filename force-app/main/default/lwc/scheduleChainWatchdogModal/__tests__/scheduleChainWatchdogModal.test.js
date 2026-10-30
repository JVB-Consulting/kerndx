// SPDX-License-Identifier: Apache-2.0
/**
 * @description Jest unit tests for scheduleChainWatchdogModal LWC component.
 *
 * @author Jason van Beukering
 * @date July 2026, October 2026
 */

jest.mock('@salesforce/label/c.HealthCheck_ChainWatchdog_ScheduleOptions', () => ({
	default: 'Hourly on the hour=0 0 * * * ?|Every 30 minutes=0 0/30 * * * ?|Every 2 hours=0 0 0/2 * * ?|Nightly 2:00 AM=0 0 2 * * ?'
}), {virtual: true});

// Restore the real English values for the bundle's labels (the default sfdx-lwc-jest stub
// resolves each to the bare string 'c.<Name>') so rendering assertions verify the shipped copy.
jest.mock('@salesforce/label/c.HealthCheck_ChainWatchdog_ModalTitle', () => ({default: 'Schedule Chain Watchdog'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_ChainWatchdog_ModalSubtitle', () => ({
	default: 'Kern will create one active scheduled job that checks hourly for chains with no activity in the last 30 minutes and marks them Stalled, '
			+ 'firing each chain\'s error notification. Pick a different schedule below, or customize the job for full control.'
}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_ChainWatchdog_DefaultsNote', () => ({
	default: 'Stale threshold 30 minutes · up to 50 chains per sweep — adjustable later from Scheduled Jobs.'
}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_ChainWatchdog_CreateButton', () => ({default: 'Create scheduled job'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_Schedule', () => ({default: 'Schedule'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_Cancel', () => ({default: 'Cancel'}), {virtual: true});

const RECOMMENDED_HOURLY_CRON = '0 0 * * * ?';
const NIGHTLY_CRON = '0 0 2 * * ?';

describe('c-schedule-chain-watchdog-modal', () =>
{
	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const ScheduleChainWatchdogModal = require('c/scheduleChainWatchdogModal').default;
			expect(ScheduleChainWatchdogModal).toBeDefined();
			expect(typeof ScheduleChainWatchdogModal).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const ScheduleChainWatchdogModal = require('c/scheduleChainWatchdogModal').default;
		const prototype = ScheduleChainWatchdogModal.prototype;

		it('has @api proposal property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'proposal');
			expect(descriptor).toBeDefined();
		});

		it('has scheduleOptions getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'scheduleOptions');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has connectedCallback method', () =>
		{
			expect(typeof prototype.connectedCallback).toBe('function');
		});

		it('has handleScheduleChange method', () =>
		{
			expect(typeof prototype.handleScheduleChange).toBe('function');
		});

		it('has handleCreate method', () =>
		{
			expect(typeof prototype.handleCreate).toBe('function');
		});

		it('has handleCancel method', () =>
		{
			expect(typeof prototype.handleCancel).toBe('function');
		});
	});

	describe('instance behavior', () =>
	{
		const ScheduleChainWatchdogModal = require('c/scheduleChainWatchdogModal').default;
		const prototype = ScheduleChainWatchdogModal.prototype;

		const getGetter = (name) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, name).get;
		};

		const createMockContext = (overrides = {}) =>
		{
			let context = {proposal: null, selectedCronExpression: '', close: jest.fn(), ...overrides};
			Object.defineProperty(context, 'scheduleOptions', Object.getOwnPropertyDescriptor(prototype, 'scheduleOptions'));
			return context;
		};

		describe('scheduleOptions', () =>
		{
			it('parses the pipe-delimited label=cron tokens into the four {label, value} options', () =>
			{
				let context = createMockContext();
				let getter = getGetter('scheduleOptions');
				let options = getter.call(context);

				expect(Array.isArray(options)).toBe(true);
				expect(options).toHaveLength(4);
				expect(options[0]).toEqual({label: 'Hourly on the hour', value: RECOMMENDED_HOURLY_CRON});
				expect(options[1]).toEqual({label: 'Every 30 minutes', value: '0 0/30 * * * ?'});
				expect(options[2]).toEqual({label: 'Every 2 hours', value: '0 0 0/2 * * ?'});
				expect(options[3]).toEqual({label: 'Nightly 2:00 AM', value: NIGHTLY_CRON});
			});
		});

		describe('connectedCallback', () =>
		{
			it('preselects the proposal cron expression', () =>
			{
				let context = createMockContext({proposal: {cronExpression: NIGHTLY_CRON}});

				prototype.connectedCallback.call(context);

				expect(context.selectedCronExpression).toBe(NIGHTLY_CRON);
			});

			it('falls back to the first schedule option when the proposal is absent', () =>
			{
				let context = createMockContext();

				prototype.connectedCallback.call(context);

				expect(context.selectedCronExpression).toBe(RECOMMENDED_HOURLY_CRON);
			});

			it('falls back to the first schedule option when the proposal carries no cron expression', () =>
			{
				let context = createMockContext({proposal: {}});

				prototype.connectedCallback.call(context);

				expect(context.selectedCronExpression).toBe(RECOMMENDED_HOURLY_CRON);
			});
		});

		describe('handleScheduleChange', () =>
		{
			it('updates the selected cron expression from the combobox event', () =>
			{
				let context = createMockContext({selectedCronExpression: RECOMMENDED_HOURLY_CRON});

				prototype.handleScheduleChange.call(context, {detail: {value: NIGHTLY_CRON}});

				expect(context.selectedCronExpression).toBe(NIGHTLY_CRON);
			});
		});

		describe('handleCreate', () =>
		{
			it('calls close with action confirm and the selected cron expression', () =>
			{
				let context = createMockContext({selectedCronExpression: RECOMMENDED_HOURLY_CRON});

				prototype.handleCreate.call(context);

				expect(context.close).toHaveBeenCalledWith({action: 'confirm', cronExpression: RECOMMENDED_HOURLY_CRON});
			});

			it('round-trips a schedule change through handleCreate', () =>
			{
				let context = createMockContext({proposal: {cronExpression: RECOMMENDED_HOURLY_CRON}});

				prototype.connectedCallback.call(context);
				prototype.handleScheduleChange.call(context, {detail: {value: NIGHTLY_CRON}});
				prototype.handleCreate.call(context);

				expect(context.close).toHaveBeenCalledWith({action: 'confirm', cronExpression: NIGHTLY_CRON});
			});
		});

		describe('handleCancel', () =>
		{
			it('calls close with action cancel', () =>
			{
				let context = createMockContext();

				prototype.handleCancel.call(context);

				expect(context.close).toHaveBeenCalledWith({action: 'cancel'});
			});
		});
	});

	describe('DOM rendering', () =>
	{
		const createComponent = async(proposal) =>
		{
			const {createElement} = require('lwc');
			const ScheduleChainWatchdogModal = require('c/scheduleChainWatchdogModal').default;
			let element = createElement('c-schedule-chain-watchdog-modal', {is: ScheduleChainWatchdogModal});
			element.proposal = proposal;
			document.body.appendChild(element);
			await Promise.resolve();
			return element;
		};

		afterEach(() =>
		{
			while(document.body.firstChild)
			{
				document.body.removeChild(document.body.firstChild);
			}
		});

		it('renders the real label values on the header, body, and footer', async() =>
		{
			let element = await createComponent({cronExpression: RECOMMENDED_HOURLY_CRON});

			expect(element.shadowRoot.querySelector('[data-spec-id="watchdog-confirm-title"]').label).toBe('Schedule Chain Watchdog');
			expect(element.shadowRoot.querySelector('[data-testid="watchdog-confirm-subtitle"]').textContent)
			.toBe('Kern will create one active scheduled job that checks hourly for chains with no activity in the last 30 minutes and marks them Stalled, '
					+ 'firing each chain\'s error notification. Pick a different schedule below, or customize the job for full control.');
			expect(element.shadowRoot.querySelector('[data-testid="watchdog-defaults-note"]').textContent)
			.toBe('Stale threshold 30 minutes · up to 50 chains per sweep — adjustable later from Scheduled Jobs.');
			expect(element.shadowRoot.querySelector('[data-testid="create-button"]').label).toBe('Create scheduled job');
			expect(element.shadowRoot.querySelector('[data-testid="cancel-button"]').label).toBe('Cancel');
		});

		it('renders the schedule combobox with the four options preselected on the proposal cron', async() =>
		{
			let element = await createComponent({cronExpression: NIGHTLY_CRON});

			let combobox = element.shadowRoot.querySelector('[data-testid="watchdog-confirm-schedule"]');
			expect(combobox.label).toBe('Schedule');
			expect(combobox.options).toHaveLength(4);
			expect(combobox.options[0]).toEqual({label: 'Hourly on the hour', value: RECOMMENDED_HOURLY_CRON});
			expect(combobox.value).toBe(NIGHTLY_CRON);
		});

		it('preselects the recommended hourly default when no proposal is supplied', async() =>
		{
			let element = await createComponent(undefined);

			let combobox = element.shadowRoot.querySelector('[data-testid="watchdog-confirm-schedule"]');
			expect(combobox.value).toBe(RECOMMENDED_HOURLY_CRON);
		});
	});
});
