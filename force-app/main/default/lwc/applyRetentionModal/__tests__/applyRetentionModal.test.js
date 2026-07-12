// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for applyRetentionModal LWC component.
 *
 * @author Jason van Beukering
 * @date April 2026, May 2026
 */
jest.mock('lightning/modal', () =>
{
	const lwc = require('lwc');
	return {__esModule: true, default: lwc.LightningElement};
}, {virtual: true});

jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ScheduleOptions', () => ({
	default: 'Nightly 2:00 AM=0 0 2 * * ?|Nightly 1:00 AM=0 0 1 * * ?|Weekly Sunday 2:00 AM=0 0 2 ? * SUN|Monthly 1st at 2:00 AM=0 0 2 1 * ?'
}), {virtual: true});

// Restore the real English values for the bundle's labels (the default sfdx-lwc-jest stub
// resolves each to the bare string 'c.<Name>'). The retention template keeps its {0} form so the
// real formatTemplateString interpolation is verified end-to-end.
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ColumnObject', () => ({default: 'Object'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ColumnRecordsToday', () => ({default: 'Records today'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ColumnRetention', () => ({default: 'Retention'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ColumnSchedule', () => ({default: 'Schedule'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_RetentionDays', () => ({default: '{0} days'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_CancelButton', () => ({default: 'Cancel'}), {virtual: true});

describe('c-apply-retention-modal', () =>
{
	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const ApplyRetentionModal = require('c/applyRetentionModal').default;
			expect(ApplyRetentionModal).toBeDefined();
			expect(typeof ApplyRetentionModal).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const ApplyRetentionModal = require('c/applyRetentionModal').default;
		const prototype = ApplyRetentionModal.prototype;

		it('has @api proposals property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'proposals');
			expect(descriptor).toBeDefined();
		});

		it('has @api title property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'title');
			expect(descriptor).toBeDefined();
		});

		it('has @api subtitle property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'subtitle');
			expect(descriptor).toBeDefined();
		});

		it('has @api firstRunWarning property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'firstRunWarning');
			expect(descriptor).toBeDefined();
		});

		it('has @api confirmButtonLabel property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'confirmButtonLabel');
			expect(descriptor).toBeDefined();
		});

		it('has @api customizeLinkLabel property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'customizeLinkLabel');
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

		it('has handleCronChange method', () =>
		{
			expect(typeof prototype.handleCronChange).toBe('function');
		});

		it('has handleConfirm method', () =>
		{
			expect(typeof prototype.handleConfirm).toBe('function');
		});

		it('has handleCustomize method', () =>
		{
			expect(typeof prototype.handleCustomize).toBe('function');
		});

		it('has handleCancel method', () =>
		{
			expect(typeof prototype.handleCancel).toBe('function');
		});
	});

	describe('instance behavior', () =>
	{
		const ApplyRetentionModal = require('c/applyRetentionModal').default;
		const prototype = ApplyRetentionModal.prototype;

		const getGetter = (name) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, name).get;
		};

		const createMockContext = (overrides = {}) =>
		{
			return {
				proposals: [], workingProposals: [], title: '', subtitle: '', firstRunWarning: '', confirmButtonLabel: '', customizeLinkLabel: '', close: jest.fn(), ...overrides
			};
		};

		describe('scheduleOptions', () =>
		{
			it('parses pipe-delimited label=cron tokens into {label, value} objects', () =>
			{
				let context = createMockContext();
				let getter = getGetter('scheduleOptions');
				let options = getter.call(context);

				expect(Array.isArray(options)).toBe(true);
				expect(options).toHaveLength(4);
				expect(options[0]).toEqual({label: 'Nightly 2:00 AM', value: '0 0 2 * * ?'});
				expect(options[1]).toEqual({label: 'Nightly 1:00 AM', value: '0 0 1 * * ?'});
				expect(options[2]).toEqual({label: 'Weekly Sunday 2:00 AM', value: '0 0 2 ? * SUN'});
				expect(options[3]).toEqual({label: 'Monthly 1st at 2:00 AM', value: '0 0 2 1 * ?'});
			});
		});

		describe('connectedCallback', () =>
		{
			it('clones proposals into workingProposals so the caller array is not mutated', () =>
			{
				let originalProposals = [
					{objectApiName: 'LogEntry__c', objectLabel: 'Log Entry', recordCount: 100, retentionDays: 30, schedulerName: 'Purge Logs', cronExpression: '0 0 2 * * ?'},
					{objectApiName: 'ApiCall__c', objectLabel: 'Api Call', recordCount: 50, retentionDays: 60, schedulerName: 'Purge API', cronExpression: '0 0 1 * * ?'}
				];
				let context = createMockContext({proposals: originalProposals});

				prototype.connectedCallback.call(context);

				expect(context.workingProposals).toHaveLength(2);
				expect(context.workingProposals[0]).toEqual({...originalProposals[0], retentionDisplay: '30 days'});
				expect(context.workingProposals[1].retentionDisplay).toBe('60 days');
				expect(context.workingProposals[0]).not.toBe(originalProposals[0]);
				context.workingProposals[0].cronExpression = '0 0 9 * * ?';
				expect(originalProposals[0].cronExpression).toBe('0 0 2 * * ?');
			});

			it('handles null proposals gracefully', () =>
			{
				let context = createMockContext({proposals: null});
				prototype.connectedCallback.call(context);
				expect(context.workingProposals).toEqual([]);
			});
		});

		describe('handleCronChange', () =>
		{
			it('updates cronExpression only on the matching row', () =>
			{
				let context = createMockContext({
					workingProposals: [
						{objectApiName: 'LogEntry__c', cronExpression: '0 0 2 * * ?'},
						{objectApiName: 'ApiCall__c', cronExpression: '0 0 1 * * ?'}
					]
				});

				prototype.handleCronChange.call(context, {
					target: {dataset: {objectApiName: 'LogEntry__c'}}, detail: {value: '0 0 5 * * ?'}
				});

				expect(context.workingProposals[0]).toEqual({objectApiName: 'LogEntry__c', cronExpression: '0 0 5 * * ?'});
				expect(context.workingProposals[1]).toEqual({objectApiName: 'ApiCall__c', cronExpression: '0 0 1 * * ?'});
			});
		});

		describe('handleConfirm', () =>
		{
			it('calls close with action confirm and the working proposals', () =>
			{
				let workingProposals = [{objectApiName: 'LogEntry__c', cronExpression: '0 0 2 * * ?'}];
				let context = createMockContext({workingProposals});
				prototype.handleConfirm.call(context);
				expect(context.close).toHaveBeenCalledWith({action: 'confirm', proposals: workingProposals});
			});

			it('round-trips a cron edit through handleConfirm', () =>
			{
				let context = createMockContext({
					proposals: [
						{objectApiName: 'LogEntry__c', cronExpression: '0 0 2 * * ?'},
						{objectApiName: 'ApiCall__c', cronExpression: '0 0 2 * * ?'}
					]
				});
				prototype.connectedCallback.call(context);
				prototype.handleCronChange.call(context, {
					target: {dataset: {objectApiName: 'LogEntry__c'}}, detail: {value: '0 0 1 * * ?'}
				});
				prototype.handleConfirm.call(context);

				expect(context.close).toHaveBeenCalledWith({action: 'confirm', proposals: expect.any(Array)});
				let payload = context.close.mock.calls[0][0];
				expect(payload.proposals.find((proposal) => proposal.objectApiName === 'LogEntry__c').cronExpression).toBe('0 0 1 * * ?');
				expect(payload.proposals.find((proposal) => proposal.objectApiName === 'ApiCall__c').cronExpression).toBe('0 0 2 * * ?');
				// The display-only retention text must not leak into the payload the caller serialises to Apex.
				expect(payload.proposals[0]).not.toHaveProperty('retentionDisplay');
			});
		});

		describe('handleCustomize', () =>
		{
			it('calls close with action customize', () =>
			{
				let context = createMockContext();
				prototype.handleCustomize.call(context);
				expect(context.close).toHaveBeenCalledWith({action: 'customize'});
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
		it('renders one proposal-row per proposal with footer test hooks', async() =>
		{
			const {createElement} = require('lwc');
			const ApplyRetentionModal = require('c/applyRetentionModal').default;
			let element = createElement('c-apply-retention-modal', {is: ApplyRetentionModal});
			element.title = 'Apply Retention';
			element.subtitle = 'Create 2 jobs';
			element.firstRunWarning = 'Warning text';
			element.confirmButtonLabel = 'Apply 2 Jobs';
			element.customizeLinkLabel = 'Customize';
			element.proposals = [
				{objectApiName: 'LogEntry__c', objectLabel: 'Log Entry', recordCount: 100, retentionDays: 30, schedulerName: 'Purge Logs', cronExpression: '0 0 2 * * ?'},
				{objectApiName: 'ApiCall__c', objectLabel: 'Api Call', recordCount: 50, retentionDays: 60, schedulerName: 'Purge API', cronExpression: '0 0 1 * * ?'}
			];
			document.body.appendChild(element);
			await Promise.resolve();

			let rows = element.shadowRoot.querySelectorAll('[data-testid="proposal-row"]');
			expect(rows).toHaveLength(2);

			expect(element.shadowRoot.querySelector('[data-testid="confirm-button"]')).toBeTruthy();
			expect(element.shadowRoot.querySelector('[data-testid="customize-link"]')).toBeTruthy();
			expect(element.shadowRoot.querySelector('[data-testid="cancel-button"]')).toBeTruthy();
		});
	});
});
