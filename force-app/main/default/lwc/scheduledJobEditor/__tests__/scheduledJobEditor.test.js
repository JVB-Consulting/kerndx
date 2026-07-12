// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for scheduledJobEditor LWC component.
 *
 * @author Jason van Beukering
 * @date March 2026, July 2026
 */
import CREATE_TITLE from '@salesforce/label/c.ScheduledJob_NewTitle';
import EDIT_TITLE from '@salesforce/label/c.ScheduledJob_EditTitle';
import SCHEDULE from '@salesforce/label/c.ScheduledJob_Schedule';
import LOAD_RECORD_FAILED from '@salesforce/label/c.ScheduledJob_LoadRecordFailed';
import LOAD_PARAMETERS_FAILED from '@salesforce/label/c.ScheduledJob_LoadParameterDefinitionsFailed';
import CREATED from '@salesforce/label/c.ScheduledJob_Created';
import SAVED from '@salesforce/label/c.ScheduledJob_Saved';
import SAVE_FAILED from '@salesforce/label/c.ScheduledJob_SaveFailed';

const mockShowSuccessToast = jest.fn();
const mockShowErrorToast = jest.fn();
const mockShowInfoToast = jest.fn();
const mockShowWarningToast = jest.fn();
const mockCallControllerMethod = jest.fn().mockResolvedValue({});
const mockRedirectToRecordPage = jest.fn();

jest.mock('c/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		const {LightningElement} = require('lwc');
		return class extends LightningElement
		{
			showSuccessToast(...args)
			{
				mockShowSuccessToast(...args);
			}

			showErrorToast(...args)
			{
				mockShowErrorToast(...args);
			}

			showInfoToast(...args)
			{
				mockShowInfoToast(...args);
			}

			showWarningToast(...args)
			{
				mockShowWarningToast(...args);
			}

			callControllerMethod(...args)
			{
				return mockCallControllerMethod(...args);
			}

			redirectToRecordPage(...args)
			{
				mockRedirectToRecordPage(...args);
			}
		};
	})
}), {virtual: true});

jest.mock('lightning/uiRecordApi', () => ({
	getRecord: jest.fn(), getFieldValue: jest.fn(), notifyRecordUpdateAvailable: jest.fn().mockResolvedValue()
}), {virtual: true});

jest.mock('@salesforce/schema/ScheduledJob__c.SchedulerName__c', () => ({default: 'ScheduledJob__c.SchedulerName__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.ClassName__c', () => ({default: 'ScheduledJob__c.ClassName__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.CronExpression__c', () => ({default: 'ScheduledJob__c.CronExpression__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.IsActive__c', () => ({default: 'ScheduledJob__c.IsActive__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Description__c', () => ({default: 'ScheduledJob__c.Description__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Parameters__c', () => ({default: 'ScheduledJob__c.Parameters__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Timezone__c', () => ({default: 'ScheduledJob__c.Timezone__c'}), {virtual: true});

jest.mock('@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ScheduledJob.getUserTimezone', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ScheduledJob.saveRecord', () => ({default: jest.fn()}), {virtual: true});

// Resolve the timezone-heading label to its real templated value so scheduleHeading's
// formatTemplateString interpolation (and the getTimezoneDisplayName raw-id fallback)
// can be asserted through the public getter, rather than the default 'c.X' stub.
jest.mock('@salesforce/label/c.ScheduledJob_ScheduleWithTimezone', () => ({default: 'Schedule ({0})'}), {virtual: true});

jest.mock('c/cronExpressionEditor', () =>
{
	const {LightningElement} = require('lwc');

	class CronExpressionEditorStub extends LightningElement
	{
	}

	return {
		__esModule: true, default: CronExpressionEditorStub, describeCronExpression: jest.fn().mockReturnValue('Every day at noon')
	};
}, {virtual: true});

jest.mock('c/utilitySystem', () => ({
	reduceErrors: jest.fn().mockReturnValue('mock error detail')
}), {virtual: true});

describe('c-scheduled-job-editor', () =>
{
	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const ScheduledJobEditor = require('c/scheduledJobEditor').default;
			expect(ScheduledJobEditor).toBeDefined();
			expect(typeof ScheduledJobEditor).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const ScheduledJobEditor = require('c/scheduledJobEditor').default;
		const prototype = ScheduledJobEditor.prototype;

		it('has @api recordId property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'recordId');
			expect(descriptor).toBeDefined();
		});

		it('has @api lockedFields property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'lockedFields');
			expect(descriptor).toBeDefined();
		});

		it('has isCreateMode getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'isCreateMode');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has cardTitle getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'cardTitle');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has isSaveDisabled getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'isSaveDisabled');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has hasParameterDefinitions getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'hasParameterDefinitions');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has editParameterFields getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'editParameterFields');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has connectedCallback method', () =>
		{
			expect(typeof prototype.connectedCallback).toBe('function');
		});

		it('has wire method for getRecord', () =>
		{
			expect(prototype.wiredRecord).toBeDefined();
		});

		it('has handleSchedulerNameChange method', () =>
		{
			expect(typeof prototype.handleSchedulerNameChange).toBe('function');
		});

		it('has handleClassNameChange method', () =>
		{
			expect(typeof prototype.handleClassNameChange).toBe('function');
		});

		it('has handleIsActiveChange method', () =>
		{
			expect(typeof prototype.handleIsActiveChange).toBe('function');
		});

		it('has handleDescriptionChange method', () =>
		{
			expect(typeof prototype.handleDescriptionChange).toBe('function');
		});

		it('has handleCronChange method', () =>
		{
			expect(typeof prototype.handleCronChange).toBe('function');
		});

		it('has handleParameterChange method', () =>
		{
			expect(typeof prototype.handleParameterChange).toBe('function');
		});

		it('has handleSave method', () =>
		{
			expect(typeof prototype.handleSave).toBe('function');
		});

		it('has handleCancel method', () =>
		{
			expect(typeof prototype.handleCancel).toBe('function');
		});

		it('has loadSchedulableClasses method', () =>
		{
			expect(typeof prototype.loadSchedulableClasses).toBe('function');
		});

		it('has loadParameterDefinitions method', () =>
		{
			expect(typeof prototype.loadParameterDefinitions).toBe('function');
		});

		it('has loadUserTimezone method', () =>
		{
			expect(typeof prototype.loadUserTimezone).toBe('function');
		});

		it('has scheduleHeading getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'scheduleHeading');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});
	});

	describe('DOM rendering', () =>
	{
		it('creates element with @api recordId', () =>
		{
			const {createElement} = require('lwc');
			const ScheduledJobEditor = require('c/scheduledJobEditor').default;
			let element = createElement('c-scheduled-job-editor', {is: ScheduledJobEditor});
			expect(element).toBeTruthy();
			element.recordId = 'a00000000000001';
			expect(element.recordId).toBe('a00000000000001');
		});

		it('exposes @api lockedFields with default empty array', () =>
		{
			const {createElement} = require('lwc');
			const ScheduledJobEditor = require('c/scheduledJobEditor').default;
			let element = createElement('c-scheduled-job-editor', {is: ScheduledJobEditor});
			expect(Array.isArray(element.lockedFields)).toBe(true);
			expect(element.lockedFields).toEqual([]);
			element.lockedFields = ['objectName'];
			expect(element.lockedFields).toEqual(['objectName']);
		});

		async function flushPromises()
		{
			for(let index = 0; index < 5; index++)
			{
				// eslint-disable-next-line no-await-in-loop -- flush one microtask tick per iteration
				await Promise.resolve();
			}
		}

		it('renders locked parameter input as read-only while leaving others editable', async() =>
		{
			const getParameterDefinitions = require('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions').default;
			getParameterDefinitions.mockResolvedValue([
				{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true},
				{name: 'minimumNumberOfDays', label: 'Minimum Number Of Days', dataType: 'NUMERIC', isRequired: false}
			]);
			const {createElement} = require('lwc');
			const ScheduledJobEditor = require('c/scheduledJobEditor').default;
			let element = createElement('c-scheduled-job-editor', {is: ScheduledJobEditor});
			element.lockedFields = ['objectName'];
			document.body.appendChild(element);
			await flushPromises();

			let combobox = element.shadowRoot.querySelector('lightning-combobox[data-testid="class-name"]');
			combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'SCHED_PurgeRecords'}}));
			await flushPromises();

			let objectInput = element.shadowRoot.querySelector('lightning-input[data-testid="param-objectName"]');
			expect(objectInput).toBeTruthy();
			expect(objectInput.readOnly).toBe(true);

			let daysInput = element.shadowRoot.querySelector('lightning-input[data-testid="param-minimumNumberOfDays"]');
			expect(daysInput).toBeTruthy();
			expect(daysInput.readOnly).toBe(false);
		});

		it('leaves inputs editable when lockedFields is empty', async() =>
		{
			const getParameterDefinitions = require('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions').default;
			getParameterDefinitions.mockResolvedValue([
				{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true}
			]);
			const {createElement} = require('lwc');
			const ScheduledJobEditor = require('c/scheduledJobEditor').default;
			let element = createElement('c-scheduled-job-editor', {is: ScheduledJobEditor});
			document.body.appendChild(element);
			await flushPromises();

			let combobox = element.shadowRoot.querySelector('lightning-combobox[data-testid="class-name"]');
			combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'SCHED_PurgeRecords'}}));
			await flushPromises();

			let objectInput = element.shadowRoot.querySelector('lightning-input[data-testid="param-objectName"]');
			expect(objectInput).toBeTruthy();
			expect(objectInput.readOnly).toBe(false);
		});
	});

	describe('instance behavior', () =>
	{
		const ScheduledJobEditor = require('c/scheduledJobEditor').default;
		const prototype = ScheduledJobEditor.prototype;
		const {getFieldValue, notifyRecordUpdateAvailable} = require('lightning/uiRecordApi');
		const getSchedulableClasses = require('@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses').default;
		const getParameterDefinitions = require('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions').default;
		const getUserTimezone = require('@salesforce/apex/CTRL_ScheduledJob.getUserTimezone').default;
		const saveRecord = require('@salesforce/apex/CTRL_ScheduledJob.saveRecord').default;

		const getGetter = (name) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, name).get;
		};

		const createMockContext = (overrides = {}) =>
		{
			return {
				recordId: 'a00000000000001',
				schedulerName: '',
				className: '',
				cronExpression: '',
				isActive: false,
				description: '',
				classOptions: [],
				parameterDefinitions: null,
				parameterValues: {},
				cronIsValid: true,
				isSaving: false,
				_lastLoadedClassName: undefined,
				showSuccessToast: mockShowSuccessToast,
				showErrorToast: mockShowErrorToast,
				redirectToRecordPage: mockRedirectToRecordPage,
				userTimezone: '',
				loadParameterDefinitions: jest.fn(),
				loadSchedulableClasses: jest.fn().mockResolvedValue(),
				loadUserTimezone: jest.fn().mockResolvedValue(), ...overrides
			};
		};

		describe('isCreateMode', () =>
		{
			it('returns true when recordId is undefined', () =>
			{
				let context = createMockContext({recordId: undefined});
				let getter = getGetter('isCreateMode');
				expect(getter.call(context)).toBe(true);
			});

			it('returns false when recordId is set', () =>
			{
				let context = createMockContext();
				let getter = getGetter('isCreateMode');
				expect(getter.call(context)).toBe(false);
			});
		});

		describe('cardTitle', () =>
		{
			it('returns New Scheduled Job in create mode', () =>
			{
				let context = createMockContext({recordId: undefined});
				Object.defineProperty(context, 'isCreateMode', {get: () => true});
				let getter = getGetter('cardTitle');
				expect(getter.call(context)).toBe(CREATE_TITLE);
			});

			it('returns Edit Scheduled Job in edit mode', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				let getter = getGetter('cardTitle');
				expect(getter.call(context)).toBe(EDIT_TITLE);
			});
		});

		describe('isSaveDisabled', () =>
		{
			it('returns true when saving is in progress', () =>
			{
				let context = createMockContext({isSaving: true, schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(true);
			});

			it('returns true when cron is invalid', () =>
			{
				let context = createMockContext({cronIsValid: false, schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(true);
			});

			it('returns true when scheduler name is empty', () =>
			{
				let context = createMockContext({schedulerName: '', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(true);
			});

			it('returns true when class name is empty', () =>
			{
				let context = createMockContext({schedulerName: 'Job', className: '', cronExpression: '0 0 12 * * ?'});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(true);
			});

			it('returns true when cron expression is empty', () =>
			{
				let context = createMockContext({schedulerName: 'Job', className: 'SCHED_Test', cronExpression: ''});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(true);
			});

			it('returns false when all required fields present and valid', () =>
			{
				let context = createMockContext({schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', cronIsValid: true});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(false);
			});

			it('returns true when required parameter is empty', () =>
			{
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					cronIsValid: true,
					parameterDefinitions: [{name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true}],
					parameterValues: {objectName: ''}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(true);
			});

			it('returns false when required parameter is populated', () =>
			{
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					cronIsValid: true,
					parameterDefinitions: [{name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true}],
					parameterValues: {objectName: 'Account'}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(false);
			});

			it('returns false when optional parameter is empty', () =>
			{
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					cronIsValid: true,
					parameterDefinitions: [{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC', isRequired: false}],
					parameterValues: {batchSize: ''}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(false);
			});

			it('returns false when a required parameter is satisfied only by its defaultValue', () =>
			{
				// The parameter input renders pre-filled with the defaultValue, so the form must
				// treat that default as a satisfied required value instead of keeping Save disabled.
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					cronIsValid: true,
					parameterDefinitions: [{name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true, defaultValue: 'LogEntry__c'}],
					parameterValues: {}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(false);
			});

			it('returns true when a required parameter was explicitly cleared despite a defaultValue', () =>
			{
				// An explicit empty entry means the user removed the pre-filled default,
				// so the requirement is no longer satisfied and Save stays disabled.
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					cronIsValid: true,
					parameterDefinitions: [{name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true, defaultValue: 'LogEntry__c'}],
					parameterValues: {objectName: ''}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('isSaveDisabled');
				expect(getter.call(context)).toBe(true);
			});
		});

		describe('hasParameterDefinitions', () =>
		{
			it('returns false when definitions are null', () =>
			{
				let context = createMockContext({parameterDefinitions: null});
				let getter = getGetter('hasParameterDefinitions');
				expect(getter.call(context)).toBe(false);
			});

			it('returns false when definitions are empty', () =>
			{
				let context = createMockContext({parameterDefinitions: []});
				let getter = getGetter('hasParameterDefinitions');
				expect(getter.call(context)).toBe(false);
			});

			it('returns true when definitions exist', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}]
				});
				let getter = getGetter('hasParameterDefinitions');
				expect(getter.call(context)).toBe(true);
			});
		});

		describe('editParameterFields', () =>
		{
			it('returns empty array when no definitions', () =>
			{
				let context = createMockContext({parameterDefinitions: null});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				let getter = getGetter('editParameterFields');
				expect(getter.call(context)).toEqual([]);
			});

			it('maps TEXT parameters correctly', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true, description: 'API name'}],
					parameterValues: {objectName: 'Account'}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].isText).toBe(true);
				expect(result[0].isNumeric).toBe(false);
				expect(result[0].isToggle).toBe(false);
				expect(result[0].value).toBe('Account');
				expect(result[0].isRequired).toBe(true);
				expect(result[0].description).toBe('API name');
			});

			it('maps NUMERIC parameters correctly', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC', defaultValue: '2000'}], parameterValues: {}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].isNumeric).toBe(true);
				expect(result[0].isText).toBe(false);
				expect(result[0].value).toBe('2000');
			});

			it('maps FLAG parameters correctly', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'allOrNothing', label: 'All or Nothing', dataType: 'FLAG'}], parameterValues: {allOrNothing: 'true'}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].isToggle).toBe(true);
				expect(result[0].isText).toBe(false);
				expect(result[0].toggleChecked).toBe(true);
			});

			it('defaults FLAG to unchecked when value is not true', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'allOrNothing', label: 'All or Nothing', dataType: 'FLAG'}], parameterValues: {}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].toggleChecked).toBe(false);
			});

			it('uses provided value over default', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC', defaultValue: '2000'}], parameterValues: {batchSize: '500'}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].value).toBe('500');
			});

			it('marks parameter isLocked when name appears in lockedFields', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [
						{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true},
						{name: 'minimumNumberOfDays', label: 'Minimum Number Of Days', dataType: 'NUMERIC', isRequired: false}
					], parameterValues: {objectName: 'kern__LogEntry__c', minimumNumberOfDays: '90'}, lockedFields: ['objectName']
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].isLocked).toBe(true);
				expect(result[1].isLocked).toBe(false);
			});

			it('leaves all parameters unlocked when lockedFields is empty', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true}], parameterValues: {objectName: 'Account'}, lockedFields: []
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].isLocked).toBe(false);
			});

			it('leaves all parameters unlocked when lockedFields is undefined', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true}],
					parameterValues: {objectName: 'Account'},
					lockedFields: undefined
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].isLocked).toBe(false);
			});

			it('treats a parameter with no dataType as an untyped field', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'mystery', label: 'Mystery', isRequired: false}], parameterValues: {mystery: 'x'}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				let getter = getGetter('editParameterFields');
				let result = getter.call(context);
				expect(result[0].isText).toBe(false);
				expect(result[0].isNumeric).toBe(false);
				expect(result[0].isToggle).toBe(false);
			});
		});

		describe('scheduleHeading', () =>
		{
			it('returns Schedule with timezone when userTimezone is set', () =>
			{
				let context = createMockContext({userTimezone: 'America/New_York'});
				let getter = getGetter('scheduleHeading');
				let result = getter.call(context);
				expect(result).toContain('Schedule (');
				expect(result).toContain(')');
			});

			it('returns plain Schedule when userTimezone is empty', () =>
			{
				let context = createMockContext({userTimezone: ''});
				let getter = getGetter('scheduleHeading');
				expect(getter.call(context)).toBe(SCHEDULE);
			});

			it('falls back to the raw timezone id when Intl cannot format the zone', () =>
			{
				let context = createMockContext({userTimezone: 'Totally/Bogus_Zone'});
				let getter = getGetter('scheduleHeading');
				expect(getter.call(context)).toBe('Schedule (Totally/Bogus_Zone)');
			});
		});

		describe('connectedCallback', () =>
		{
			it('loads schedulable classes and user timezone', () =>
			{
				let context = createMockContext();
				prototype.connectedCallback.call(context);
				expect(context.loadSchedulableClasses).toHaveBeenCalled();
				expect(context.loadUserTimezone).toHaveBeenCalled();
			});
		});

		describe('loadUserTimezone', () =>
		{
			it('sets userTimezone from Apex response', async() =>
			{
				getUserTimezone.mockResolvedValue('Africa/Johannesburg');
				let context = createMockContext();
				await prototype.loadUserTimezone.call(context);
				expect(context.userTimezone).toBe('Africa/Johannesburg');
			});

			it('sets empty userTimezone on error', async() =>
			{
				getUserTimezone.mockRejectedValue(new Error('Failed'));
				let context = createMockContext({userTimezone: 'old'});
				await prototype.loadUserTimezone.call(context);
				expect(context.userTimezone).toBe('');
			});
		});

		describe('loadSchedulableClasses', () =>
		{
			it('populates classOptions from Apex response', async() =>
			{
				const firstClassName = 'SCHED_PurgeRecords';
				const secondClassName = 'SCHED_DeactivateUsers';
				getSchedulableClasses.mockResolvedValue([
					firstClassName,
					secondClassName
				]);
				let context = createMockContext({classOptions: []});
				await prototype.loadSchedulableClasses.call(context);
				expect(context.classOptions).toEqual([
					{label: firstClassName, value: firstClassName},
					{label: secondClassName, value: secondClassName}
				]);
			});

			it('sets empty classOptions when Apex returns null', async() =>
			{
				getSchedulableClasses.mockResolvedValue(null);
				let context = createMockContext({classOptions: []});
				await prototype.loadSchedulableClasses.call(context);
				expect(context.classOptions).toEqual([]);
			});

			it('sets empty classOptions on error', async() =>
			{
				getSchedulableClasses.mockRejectedValue(new Error('Failed'));
				let context = createMockContext({classOptions: [{label: 'old', value: 'old'}]});
				await prototype.loadSchedulableClasses.call(context);
				expect(context.classOptions).toEqual([]);
			});
		});

		describe('wiredRecord', () =>
		{
			it('populates form fields from wire data', () =>
			{
				const wiredClassName = 'SCHED_PurgeRecords';
				getFieldValue
				.mockReturnValueOnce(wiredClassName)
				.mockReturnValueOnce('Purge Records')
				.mockReturnValueOnce('0 0 1 * * ?')
				.mockReturnValueOnce(true)
				.mockReturnValueOnce('Cleans up old records')
				.mockReturnValueOnce('{"nameValueMap":{"objectName":"LogEntry__c","minimumNumberOfDays":"30"}}');

				let context = createMockContext();
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.schedulerName).toBe('Purge Records');
				expect(context.className).toBe(wiredClassName);
				expect(context.cronExpression).toBe('0 0 1 * * ?');
				expect(context.isActive).toBe(true);
				expect(context.description).toBe('Cleans up old records');
				expect(context.parameterValues).toEqual({objectName: 'LogEntry__c', minimumNumberOfDays: '30'});
			});

			it('loads parameter definitions when class name is present', () =>
			{
				const wiredClassName = 'SCHED_PurgeRecords';
				getFieldValue.mockReturnValueOnce(wiredClassName).mockReturnValue(null);
				let context = createMockContext();
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.loadParameterDefinitions).toHaveBeenCalledWith(wiredClassName);
			});

			it('does not reload definitions when class name unchanged', () =>
			{
				getFieldValue.mockReturnValue('SCHED_PurgeRecords');
				let context = createMockContext({_lastLoadedClassName: 'SCHED_PurgeRecords'});
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.loadParameterDefinitions).not.toHaveBeenCalled();
			});

			it('handles empty field values gracefully', () =>
			{
				getFieldValue.mockReturnValue(null);
				let context = createMockContext();
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.schedulerName).toBe('');
				expect(context.className).toBe('');
				expect(context.cronExpression).toBe('');
				expect(context.isActive).toBe(false);
				expect(context.description).toBe('');
				expect(context.parameterValues).toEqual({});
			});

			it('shows error toast on wire error', () =>
			{
				let context = createMockContext();
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.showErrorToast).toHaveBeenCalledWith('mock error detail');
			});

			it('uses fallback message when reduceErrors returns empty on wire error', () =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockReturnValueOnce('');
				let context = createMockContext();
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.showErrorToast).toHaveBeenCalledWith(LOAD_RECORD_FAILED);
			});

			it('defaults to an empty parameter map when the stored JSON omits nameValueMap', () =>
			{
				getFieldValue
				.mockReturnValueOnce(null)
				.mockReturnValueOnce('Job')
				.mockReturnValueOnce('0 0 1 * * ?')
				.mockReturnValueOnce(true)
				.mockReturnValueOnce('Active job')
				.mockReturnValueOnce('{"unexpected":true}');
				let context = createMockContext();
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.parameterValues).toEqual({});
			});
		});

		describe('loadParameterDefinitions', () =>
		{
			it('sets parameter definitions from Apex', async() =>
			{
				let mockDefinitions = [{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}];
				getParameterDefinitions.mockResolvedValue(mockDefinitions);
				let context = createMockContext();
				await prototype.loadParameterDefinitions.call(context, 'SCHED_PurgeRecords');
				expect(context.parameterDefinitions).toEqual(mockDefinitions);
			});

			it('sets null and shows error toast on failure', async() =>
			{
				getParameterDefinitions.mockRejectedValue(new Error('Not found'));
				let context = createMockContext({parameterDefinitions: [{name: 'old'}]});
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.parameterDefinitions).toBeNull();
				expect(context.showErrorToast).toHaveBeenCalledWith('mock error detail');
			});

			it('uses fallback message when reduceErrors returns empty', async() =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockReturnValueOnce('');
				getParameterDefinitions.mockRejectedValue(new Error('Not found'));
				let context = createMockContext();
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.showErrorToast).toHaveBeenCalledWith(LOAD_PARAMETERS_FAILED);
			});
		});

		describe('handleSchedulerNameChange', () =>
		{
			it('updates scheduler name from event', () =>
			{
				let context = createMockContext();
				prototype.handleSchedulerNameChange.call(context, {detail: {value: 'New Name'}});
				expect(context.schedulerName).toBe('New Name');
			});
		});

		describe('handleClassNameChange', () =>
		{
			it('updates class name and reloads definitions', () =>
			{
				const selectedClassName = 'SCHED_PurgeRecords';
				let context = createMockContext();
				prototype.handleClassNameChange.call(context, {detail: {value: selectedClassName}});
				expect(context.className).toBe(selectedClassName);
				expect(context.loadParameterDefinitions).toHaveBeenCalledWith(selectedClassName);
			});

			describe.each([
				[
					'bare class name (non-namespaced org)',
					'SCHED_PurgeRecords'
				],
				[
					'managed-package namespace',
					'kern.SCHED_PurgeRecords'
				],
				[
					'rebranded subscriber namespace',
					'acme.SCHED_PurgeRecords'
				]
			])('forwards the dispatched class name verbatim (%s)', (_label, dispatchedClassName) =>
			{
				it('round-trips the combobox value into className and loadParameterDefinitions without namespace rewriting', () =>
				{
					let context = createMockContext();
					prototype.handleClassNameChange.call(context, {detail: {value: dispatchedClassName}});
					expect(context.className).toBe(dispatchedClassName);
					expect(context.loadParameterDefinitions).toHaveBeenCalledWith(dispatchedClassName);
				});
			});
		});

		describe('handleIsActiveChange', () =>
		{
			it('updates isActive from event', () =>
			{
				let context = createMockContext();
				prototype.handleIsActiveChange.call(context, {detail: {checked: true}});
				expect(context.isActive).toBe(true);
			});
		});

		describe('handleDescriptionChange', () =>
		{
			it('updates description from event', () =>
			{
				let context = createMockContext();
				prototype.handleDescriptionChange.call(context, {detail: {value: 'New description'}});
				expect(context.description).toBe('New description');
			});
		});

		describe('handleCronChange', () =>
		{
			it('tracks cron expression and validity', () =>
			{
				let context = createMockContext();
				prototype.handleCronChange.call(context, {detail: {value: '0 0 9 * * ?', isValid: true}});
				expect(context.cronExpression).toBe('0 0 9 * * ?');
				expect(context.cronIsValid).toBe(true);
			});

			it('tracks invalid cron expression', () =>
			{
				let context = createMockContext();
				prototype.handleCronChange.call(context, {detail: {value: 'bad', isValid: false}});
				expect(context.cronExpression).toBe('bad');
				expect(context.cronIsValid).toBe(false);
			});

			it('defaults isValid to true when not provided', () =>
			{
				let context = createMockContext();
				prototype.handleCronChange.call(context, {detail: {value: '0 0 12 * * ?'}});
				expect(context.cronIsValid).toBe(true);
			});
		});

		describe('handleParameterChange', () =>
		{
			it('updates parameter value for text input', () =>
			{
				let context = createMockContext({parameterValues: {}});
				prototype.handleParameterChange.call(context, {
					target: {dataset: {parameterName: 'objectName'}, type: 'text'}, detail: {value: 'Account'}
				});
				expect(context.parameterValues.objectName).toBe('Account');
			});

			it('updates parameter value for toggle input', () =>
			{
				let context = createMockContext({parameterValues: {}});
				prototype.handleParameterChange.call(context, {
					target: {dataset: {parameterName: 'allOrNothing'}, type: 'toggle'}, detail: {checked: true}
				});
				expect(context.parameterValues.allOrNothing).toBe('true');
			});

			it('updates parameter value for number input', () =>
			{
				let context = createMockContext({parameterValues: {}});
				prototype.handleParameterChange.call(context, {
					target: {dataset: {parameterName: 'batchSize'}, type: 'number'}, detail: {value: '500'}
				});
				expect(context.parameterValues.batchSize).toBe('500');
			});

			it('preserves existing parameter values', () =>
			{
				let context = createMockContext({parameterValues: {objectName: 'Account'}});
				prototype.handleParameterChange.call(context, {
					target: {dataset: {parameterName: 'batchSize'}, type: 'number'}, detail: {value: '500'}
				});
				expect(context.parameterValues.objectName).toBe('Account');
				expect(context.parameterValues.batchSize).toBe('500');
			});

			it('coerces a missing change value to an empty string', () =>
			{
				let context = createMockContext({parameterValues: {}});
				prototype.handleParameterChange.call(context, {
					target: {dataset: {parameterName: 'objectName'}, type: 'text'}, detail: {}
				});
				expect(context.parameterValues.objectName).toBe('');
			});
		});

		describe('handleSave', () =>
		{
			it('saves record and redirects to record page', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Purge Records',
					className: 'SCHED_PurgeRecords',
					cronExpression: '0 0 1 * * ?',
					isActive: true,
					description: 'Cleans up',
					userTimezone: 'Africa/Johannesburg',
					parameterDefinitions: [
						{name: 'objectName', label: 'Object Name', dataType: 'TEXT'},
						{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC'}
					],
					parameterValues: {objectName: 'LogEntry__c', batchSize: '500'}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed).toEqual(expect.objectContaining({
					recordId: 'a00000000000001', schedulerName: 'Purge Records', parameters: {objectName: 'LogEntry__c', batchSize: '500'}, timezone: 'Africa/Johannesburg'
				}));
				expect(context.redirectToRecordPage).toHaveBeenCalledWith('a00000000000001');
			});

			it('includes timezone in save payload', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', userTimezone: 'America/New_York'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed.timezone).toBe('America/New_York');
			});

			it('invalidates LDS cache before redirecting', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{recordId: 'a00000000000001'}]);
			});

			it('invalidates LDS cache with new record ID in create mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000NEW');
				let context = createMockContext({
					recordId: undefined, schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => true});
				await prototype.handleSave.call(context);
				expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{recordId: 'a00000000000NEW'}]);
			});

			it('shows success toast with create message in create mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000NEW');
				let context = createMockContext({
					recordId: undefined, schedulerName: 'Test', className: 'SCHED_Test', cronExpression: '0 0 * * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => true});
				await prototype.handleSave.call(context);
				expect(context.showSuccessToast).toHaveBeenCalledWith(CREATED);
				expect(context.redirectToRecordPage).toHaveBeenCalledWith('a00000000000NEW');
			});

			it('shows success toast with edit message in edit mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.showSuccessToast).toHaveBeenCalledWith(SAVED);
			});

			it('sends null parameters when no parameter definitions', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', parameterDefinitions: null
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed.parameters).toBeNull();
			});

			it('sends parameter values map when definitions exist', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', parameterDefinitions: [
						{name: 'objectName', label: 'Object Name', dataType: 'TEXT'},
						{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC'}
					], parameterValues: {objectName: 'Account', batchSize: ''}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed.parameters).toEqual({objectName: 'Account', batchSize: ''});
			});

			it('sets isSaving during save and resets after', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.isSaving).toBe(false);
			});

			it('shows error toast on save failure', async() =>
			{
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.showErrorToast).toHaveBeenCalledWith('mock error detail');
				expect(context.redirectToRecordPage).not.toHaveBeenCalled();
			});

			it('shows fallback error when reduceErrors fails', async() =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockImplementationOnce(() =>
				{
					throw new Error('reduce failed');
				});
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.showErrorToast).toHaveBeenCalledWith(SAVE_FAILED);
			});

			it('shows fallback error when reduceErrors returns empty', async() =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockReturnValueOnce('');
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.showErrorToast).toHaveBeenCalledWith(SAVE_FAILED);
			});

			it('resets isSaving after failure', async() =>
			{
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.isSaving).toBe(false);
			});

			it('uses recordId as fallback when saveRecord returns null', async() =>
			{
				saveRecord.mockResolvedValue(null);
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.redirectToRecordPage).toHaveBeenCalledWith('a00000000000001');
			});

			it('sends null recordId in create mode instead of undefined', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000NEW');
				let context = createMockContext({
					recordId: undefined, schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => true});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed.recordId).toBeNull();
			});

			it('sends boolean true for isActive when toggled on', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', isActive: true
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsedActive = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsedActive.isActive).toBe(true);
			});

			it('sends boolean false for isActive when not toggled', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', isActive: false
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsedInactive = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsedInactive.isActive).toBe(false);
			});

			it('serializes a null parameter value as an empty string in the save payload', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT'}],
					parameterValues: {objectName: null}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed.parameters.objectName).toBe('');
			});

			it('persists an untouched parameter defaultValue in the save payload', async() =>
			{
				// The form displays the defaultValue, so saving without touching the input
				// must persist exactly what the user saw instead of dropping the parameter.
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', parameterDefinitions: [
						{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true, defaultValue: 'LogEntry__c'},
						{name: 'minimumNumberOfDays', label: 'Minimum Number Of Days', dataType: 'NUMERIC', defaultValue: '30'}
					], parameterValues: {}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed.parameters).toEqual({objectName: 'LogEntry__c', minimumNumberOfDays: '30'});
			});

			it('prunes parameter values from a previously selected class out of the save payload', async() =>
			{
				// Switching schedulable classes leaves the old class's entries in parameterValues;
				// only parameters defined for the currently selected class may be serialised.
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT'}],
					parameterValues: {objectName: 'Account', staleParameterFromPreviousClass: 'stale'}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed.parameters).toEqual({objectName: 'Account'});
			});

			it('keeps an explicitly cleared parameter empty instead of restoring its defaultValue', async() =>
			{
				// Pins the what-you-see-is-what-saves rule: a cleared input shows empty,
				// so the payload carries an empty string, not the resurrected default.
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT', defaultValue: 'LogEntry__c'}],
					parameterValues: {objectName: ''}
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				let parsed = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsed.parameters.objectName).toBe('');
			});
		});

		describe('handleCancel', () =>
		{
			it('navigates back', () =>
			{
				let originalBack = window.history.back;
				window.history.back = jest.fn();
				let context = createMockContext();
				prototype.handleCancel.call(context);
				expect(window.history.back).toHaveBeenCalled();
				window.history.back = originalBack;
			});
		});
	});

	describe('template structure', () =>
	{
		it('contains lightning-card with form fields', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditor.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('lightning-card');
			expect(template).toContain('lightning-input');
			expect(template).toContain('lightning-combobox');
			expect(template).toContain('lightning-textarea');
			expect(template).toContain('c-cron-expression-editor');
		});

		it('contains Save and Cancel buttons in card footer', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditor.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('label={label.save}');
			expect(template).toContain('label={label.cancel}');
			expect(template).toContain('variant="brand"');
			expect(template).toContain('slot="footer"');
		});

		it('uses lightning-combobox for class name selection', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditor.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('name="className"');
		});

		it('binds card title to cardTitle getter', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditor.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('title={cardTitle}');
		});
	});
});
