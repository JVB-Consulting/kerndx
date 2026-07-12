// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for scheduledJobEditorModal LWC component.
 *
 * @author Jason van Beukering
 * @date March 2026, July 2026
 */
import LOAD_RECORD_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_LoadRecordFailed';
import LOAD_PARAMETER_DEFINITIONS_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_LoadParameterDefinitionsFailed';
import SAVE_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_SaveFailed';
import CREATE_TITLE from '@salesforce/label/c.ScheduledJob_NewTitle';
import EDIT_TITLE from '@salesforce/label/c.ScheduledJob_EditTitle';
import SCHEDULE from '@salesforce/label/c.ScheduledJob_Schedule';
import SUCCESS_TOAST_TITLE from '@salesforce/label/c.ScheduledJobEditorModal_SuccessToastTitle';
import CREATED from '@salesforce/label/c.ScheduledJob_Created';
import SAVED from '@salesforce/label/c.ScheduledJob_Saved';

// Resolve the timezone-heading label to its real templated value so scheduleHeading's
// formatTemplateString interpolation (and the getTimezoneDisplayName raw-id fallback)
// stay verified through the public getter rather than mocked to a pass-through.
jest.mock('@salesforce/label/c.ScheduledJob_ScheduleWithTimezone', () => ({default: 'Schedule ({0})'}), {virtual: true});

jest.mock('lightning/modal', () =>
{
	const lwc = require('lwc');
	return {__esModule: true, default: lwc.LightningElement};
}, {virtual: true});

jest.mock('lightning/uiRecordApi', () => ({
	getRecord: jest.fn(), getFieldValue: jest.fn()
}), {virtual: true});

jest.mock('lightning/platformShowToastEvent', () => ({
	ShowToastEvent: jest.fn().mockImplementation((params) => params)
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

jest.mock('c/utilitySystem', () => ({
	reduceErrors: jest.fn().mockReturnValue('mock error detail')
}), {virtual: true});

describe('c-scheduled-job-editor-modal', () =>
{
	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const ScheduledJobEditorModal = require('c/scheduledJobEditorModal').default;
			expect(ScheduledJobEditorModal).toBeDefined();
			expect(typeof ScheduledJobEditorModal).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const ScheduledJobEditorModal = require('c/scheduledJobEditorModal').default;
		const prototype = ScheduledJobEditorModal.prototype;

		it('has @api recordId property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'recordId');
			expect(descriptor).toBeDefined();
		});

		it('has isCreateMode getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'isCreateMode');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has modalTitle getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'modalTitle');
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

		it('has isClassNameLocked getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'isClassNameLocked');
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
			const ScheduledJobEditorModal = require('c/scheduledJobEditorModal').default;
			let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
			expect(element).toBeTruthy();
			element.recordId = 'a00000000000001';
			expect(element.recordId).toBe('a00000000000001');
		});
	});

	describe('instance behavior', () =>
	{
		const ScheduledJobEditorModal = require('c/scheduledJobEditorModal').default;
		const prototype = ScheduledJobEditorModal.prototype;
		const {getFieldValue} = require('lightning/uiRecordApi');
		const {ShowToastEvent} = require('lightning/platformShowToastEvent');
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
				disableClose: false,
				errorMessage: '',
				_lastLoadedClassName: undefined,
				userTimezone: '',
				close: jest.fn(),
				dispatchEvent: jest.fn(),
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

		describe('modalTitle', () =>
		{
			it('returns the create-mode title in create mode', () =>
			{
				let context = createMockContext({recordId: undefined});
				Object.defineProperty(context, 'isCreateMode', {get: () => true});
				let getter = getGetter('modalTitle');
				expect(getter.call(context)).toBe(CREATE_TITLE);
			});

			it('returns the edit-mode title in edit mode', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				let getter = getGetter('modalTitle');
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

		describe('hasErrorMessage', () =>
		{
			it('returns false when errorMessage is empty', () =>
			{
				let context = createMockContext({errorMessage: ''});
				let getter = getGetter('hasErrorMessage');
				expect(getter.call(context)).toBe(false);
			});

			it('returns true when errorMessage is set', () =>
			{
				let context = createMockContext({errorMessage: 'Something went wrong'});
				let getter = getGetter('hasErrorMessage');
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

			it('marks parameter isLocked and sets testId when name appears in lockedFields', () =>
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
				expect(result[0].testId).toBe('param-objectName');
				expect(result[1].isLocked).toBe(false);
				expect(result[1].testId).toBe('param-minimumNumberOfDays');
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
				expect(result[0].testId).toBe('param-objectName');
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

		describe('isClassNameLocked', () =>
		{
			it('returns true when className appears in lockedFields', () =>
			{
				let context = createMockContext({
					lockedFields: [
						'objectName',
						'className'
					]
				});
				let getter = getGetter('isClassNameLocked');
				expect(getter.call(context)).toBe(true);
			});

			it('returns false when className is not in lockedFields', () =>
			{
				let context = createMockContext({lockedFields: ['objectName']});
				let getter = getGetter('isClassNameLocked');
				expect(getter.call(context)).toBe(false);
			});

			it('returns false when lockedFields is empty', () =>
			{
				let context = createMockContext({lockedFields: []});
				let getter = getGetter('isClassNameLocked');
				expect(getter.call(context)).toBe(false);
			});

			it('returns false when lockedFields is undefined', () =>
			{
				let context = createMockContext({lockedFields: undefined});
				let getter = getGetter('isClassNameLocked');
				expect(getter.call(context)).toBe(false);
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
			it('loads schedulable classes and user timezone', async() =>
			{
				let context = createMockContext();
				await prototype.connectedCallback.call(context);
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

			it('surfaces a record load failure inside the modal instead of dispatching a toast', () =>
			{
				// Toasts dispatched while a LightningModal is open are swallowed by the overlay,
				// so load errors must render in the modal's inline error region instead.
				let context = createMockContext();
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.errorMessage).toBe('mock error detail');
				expect(context.dispatchEvent).not.toHaveBeenCalled();
				expect(ShowToastEvent).not.toHaveBeenCalled();
			});

			it('uses the fallback label when reduceErrors returns empty on wire error', () =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockReturnValueOnce('');
				let context = createMockContext();
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.errorMessage).toBe(LOAD_RECORD_FAILED_LABEL);
			});

			it('clears the inline error when record data arrives', () =>
			{
				getFieldValue.mockReturnValue(null);
				let context = createMockContext({errorMessage: 'stale error'});
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.errorMessage).toBe('');
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

			it('sets null and surfaces the failure inside the modal instead of dispatching a toast', async() =>
			{
				getParameterDefinitions.mockRejectedValue(new Error('Not found'));
				let context = createMockContext({parameterDefinitions: [{name: 'old'}]});
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.parameterDefinitions).toBeNull();
				expect(context.errorMessage).toBe('mock error detail');
				expect(context.dispatchEvent).not.toHaveBeenCalled();
				expect(ShowToastEvent).not.toHaveBeenCalled();
			});

			it('uses the fallback label when reduceErrors returns empty', async() =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockReturnValueOnce('');
				getParameterDefinitions.mockRejectedValue(new Error('Not found'));
				let context = createMockContext();
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.errorMessage).toBe(LOAD_PARAMETER_DEFINITIONS_FAILED_LABEL);
			});

			it('clears the inline error when definitions load successfully', async() =>
			{
				getParameterDefinitions.mockResolvedValue([{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}]);
				let context = createMockContext({errorMessage: 'stale error'});
				await prototype.loadParameterDefinitions.call(context, 'SCHED_PurgeRecords');
				expect(context.errorMessage).toBe('');
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
			it('saves record and closes modal with result ID', async() =>
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
				expect(context.close).toHaveBeenCalledWith('a00000000000001');
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

			it('dispatches success toast with create message in create mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000NEW');
				let context = createMockContext({
					recordId: undefined, schedulerName: 'Test', className: 'SCHED_Test', cronExpression: '0 0 * * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => true});
				await prototype.handleSave.call(context);
				expect(ShowToastEvent).toHaveBeenCalledWith(expect.objectContaining({
					title: SUCCESS_TOAST_TITLE, message: CREATED, variant: 'success'
				}));
				expect(context.close).toHaveBeenCalledWith('a00000000000NEW');
			});

			it('dispatches success toast with edit message in edit mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				expect(ShowToastEvent).toHaveBeenCalledWith(expect.objectContaining({
					title: SUCCESS_TOAST_TITLE, message: SAVED, variant: 'success'
				}));
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
				let parsedNull = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsedNull.parameters).toBeNull();
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
				let parsedParams = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsedParams.parameters).toEqual({objectName: 'Account', batchSize: ''});
			});

			it('sets disableClose during save', async() =>
			{
				saveRecord.mockImplementation(() => Promise.resolve('a00000000000001'));
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});

				let disableCloseValues = [];
				Object.defineProperty(context, 'disableClose', {
					set(value)
					{
						disableCloseValues.push(value);
					}, get()
					{
						return disableCloseValues[disableCloseValues.length - 1] || false;
					}
				});

				await prototype.handleSave.call(context);
				expect(disableCloseValues).toContain(true);
				expect(disableCloseValues[disableCloseValues.length - 1]).toBe(false);
			});

			it('releases disableClose before invoking close() on successful save', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});

				let disableCloseValues = [];
				let disableCloseAtCloseCall;

				Object.defineProperty(context, 'disableClose', {
					set(value)
					{
						disableCloseValues.push(value);
					}, get()
					{
						return disableCloseValues[disableCloseValues.length - 1] || false;
					}
				});

				context.close = jest.fn(() =>
				{
					disableCloseAtCloseCall = disableCloseValues[disableCloseValues.length - 1];
				});

				await prototype.handleSave.call(context);

				expect(context.close).toHaveBeenCalledWith('a00000000000001');
				expect(disableCloseAtCloseCall).toBe(false);
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

			it('surfaces a save failure inside the modal instead of dispatching a toast', async() =>
			{
				// Toasts dispatched while a LightningModal is open are swallowed by the overlay,
				// so save errors must render in the modal's inline error region instead.
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.errorMessage).toBe('mock error detail');
				expect(context.dispatchEvent).not.toHaveBeenCalled();
				expect(ShowToastEvent).not.toHaveBeenCalled();
				expect(context.close).not.toHaveBeenCalled();
			});

			it('shows the fallback label inline when reduceErrors fails', async() =>
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
				expect(context.errorMessage).toBe(SAVE_FAILED_LABEL);
			});

			it('shows the fallback label inline when reduceErrors returns empty', async() =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockReturnValueOnce('');
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.errorMessage).toBe(SAVE_FAILED_LABEL);
			});

			it('clears a previous inline error when a new save attempt starts', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', errorMessage: 'stale error'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.errorMessage).toBe('');
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

			it('closes with recordId as fallback when saveRecord returns null', async() =>
			{
				saveRecord.mockResolvedValue(null);
				let context = createMockContext({
					schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				await prototype.handleSave.call(context);
				expect(context.close).toHaveBeenCalledWith('a00000000000001');
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
				let parsedCreate = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(parsedCreate.recordId).toBeNull();
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

			it('serializes an empty string when a parameter has neither a value nor a defaultValue', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = createMockContext({
					schedulerName: 'Job',
					className: 'SCHED_Test',
					cronExpression: '0 0 12 * * ?',
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT'}],
					parameterValues: {}
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
			it('closes modal with null', () =>
			{
				let context = createMockContext();
				prototype.handleCancel.call(context);
				expect(context.close).toHaveBeenCalledWith(null);
			});
		});
	});

	describe('prefill + lockedFields', () =>
	{
		const ScheduledJobEditorModal = require('c/scheduledJobEditorModal').default;
		const prototype = ScheduledJobEditorModal.prototype;
		const getSchedulableClasses = require('@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses').default;
		const getUserTimezone = require('@salesforce/apex/CTRL_ScheduledJob.getUserTimezone').default;

		beforeEach(() =>
		{
			getSchedulableClasses.mockResolvedValue([]);
			getUserTimezone.mockResolvedValue('UTC');
		});

		it('has @api prefill property descriptor', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'prefill');
			expect(descriptor).toBeDefined();
		});

		it('has @api lockedFields property descriptor', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'lockedFields');
			expect(descriptor).toBeDefined();
		});

		it('exposes @api lockedFields with default empty array on instance', () =>
		{
			const {createElement} = require('lwc');
			let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
			expect(Array.isArray(element.lockedFields)).toBe(true);
			expect(element.lockedFields).toEqual([]);
			element.lockedFields = ['objectName'];
			expect(element.lockedFields).toEqual(['objectName']);
		});

		it('initialises form state from the prefill payload when there is no recordId', () =>
		{
			const prefillClassName = 'SCHED_PurgeRecords';
			let context = {
				recordId: undefined,
				schedulerName: '',
				className: '',
				cronExpression: '',
				isActive: false,
				description: '',
				parameterValues: {},
				_lastLoadedClassName: undefined,
				prefill: {
					schedulerName: 'Purge Log Entries',
					className: prefillClassName,
					cronExpression: '0 0 2 * * ?',
					isActive: true,
					parameterValues: {objectName: 'kern__LogEntry__c', minimumNumberOfDays: '90'}
				},
				lockedFields: [
					'objectName',
					'className'
				],
				loadSchedulableClasses: jest.fn().mockResolvedValue(),
				loadUserTimezone: jest.fn().mockResolvedValue(),
				loadParameterDefinitions: jest.fn().mockResolvedValue()
			};

			prototype.connectedCallback.call(context);

			expect(context.schedulerName).toBe('Purge Log Entries');
			expect(context.className).toBe(prefillClassName);
			expect(context.cronExpression).toBe('0 0 2 * * ?');
			expect(context.isActive).toBe(true);
			expect(context.parameterValues.objectName).toBe('kern__LogEntry__c');
			expect(context.parameterValues.minimumNumberOfDays).toBe('90');
			expect(context.lockedFields).toEqual([
				'objectName',
				'className'
			]);
		});

		it('does not use prefill when recordId is set (edit mode wins)', () =>
		{
			let context = {
				recordId: 'a00xx00000001',
				schedulerName: '',
				className: '',
				cronExpression: '',
				isActive: false,
				description: '',
				parameterValues: {},
				_lastLoadedClassName: undefined,
				prefill: {
					schedulerName: 'Should not win', className: 'kern.Other', cronExpression: '0 0 5 * * ?'
				},
				loadSchedulableClasses: jest.fn().mockResolvedValue(),
				loadUserTimezone: jest.fn().mockResolvedValue(),
				loadParameterDefinitions: jest.fn().mockResolvedValue()
			};

			prototype.connectedCallback.call(context);

			expect(context.schedulerName).not.toBe('Should not win');
			expect(context.className).not.toBe('kern.Other');
			expect(context.loadParameterDefinitions).not.toHaveBeenCalled();
		});

		it('triggers loadParameterDefinitions when prefill supplies className', () =>
		{
			const prefillClassName = 'SCHED_PurgeRecords';
			let context = {
				recordId: undefined,
				schedulerName: '',
				className: '',
				cronExpression: '',
				isActive: false,
				description: '',
				parameterValues: {},
				_lastLoadedClassName: undefined,
				prefill: {className: prefillClassName},
				loadSchedulableClasses: jest.fn().mockResolvedValue(),
				loadUserTimezone: jest.fn().mockResolvedValue(),
				loadParameterDefinitions: jest.fn().mockResolvedValue()
			};

			prototype.connectedCallback.call(context);

			expect(context.loadParameterDefinitions).toHaveBeenCalledWith(prefillClassName);
			expect(context._lastLoadedClassName).toBe(prefillClassName);
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
		])('round-trips any prefill.className Apex supplies (%s)', (_label, prefillClassName) =>
		{
			it('forwards the Apex-supplied class name verbatim into state and into loadParameterDefinitions', () =>
			{
				let context = {
					recordId: undefined,
					schedulerName: '',
					className: '',
					cronExpression: '',
					isActive: false,
					description: '',
					parameterValues: {},
					_lastLoadedClassName: undefined,
					prefill: {className: prefillClassName},
					loadSchedulableClasses: jest.fn().mockResolvedValue(),
					loadUserTimezone: jest.fn().mockResolvedValue(),
					loadParameterDefinitions: jest.fn().mockResolvedValue()
				};

				prototype.connectedCallback.call(context);

				expect(context.className).toBe(prefillClassName);
				expect(context.loadParameterDefinitions).toHaveBeenCalledWith(prefillClassName);
				expect(context._lastLoadedClassName).toBe(prefillClassName);
			});
		});

		it('does not call loadParameterDefinitions when prefill has no className', () =>
		{
			let context = {
				recordId: undefined,
				schedulerName: '',
				className: '',
				cronExpression: '',
				isActive: false,
				description: '',
				parameterValues: {},
				_lastLoadedClassName: undefined,
				prefill: {schedulerName: 'Only Name'},
				loadSchedulableClasses: jest.fn().mockResolvedValue(),
				loadUserTimezone: jest.fn().mockResolvedValue(),
				loadParameterDefinitions: jest.fn().mockResolvedValue()
			};

			prototype.connectedCallback.call(context);

			expect(context.loadParameterDefinitions).not.toHaveBeenCalled();
			expect(context.schedulerName).toBe('Only Name');
		});

		it('applies prefill description when supplied', () =>
		{
			let context = {
				recordId: undefined,
				schedulerName: '',
				className: '',
				cronExpression: '',
				isActive: false,
				description: '',
				parameterValues: {},
				_lastLoadedClassName: undefined,
				prefill: {description: 'Prefilled description text'},
				loadSchedulableClasses: jest.fn().mockResolvedValue(),
				loadUserTimezone: jest.fn().mockResolvedValue(),
				loadParameterDefinitions: jest.fn().mockResolvedValue()
			};

			prototype.connectedCallback.call(context);

			expect(context.description).toBe('Prefilled description text');
		});

		it('connectedCallback still calls loadSchedulableClasses and loadUserTimezone even when prefill is supplied', () =>
		{
			let context = {
				recordId: undefined,
				schedulerName: '',
				className: '',
				cronExpression: '',
				isActive: false,
				description: '',
				parameterValues: {},
				_lastLoadedClassName: undefined,
				prefill: {schedulerName: 'Name'},
				loadSchedulableClasses: jest.fn().mockResolvedValue(),
				loadUserTimezone: jest.fn().mockResolvedValue(),
				loadParameterDefinitions: jest.fn().mockResolvedValue()
			};

			prototype.connectedCallback.call(context);

			expect(context.loadSchedulableClasses).toHaveBeenCalled();
			expect(context.loadUserTimezone).toHaveBeenCalled();
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
			let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
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

		// Root-cause fix: when the field is locked we render a read-only lightning-input,
		// which sidesteps the classOptions async-load race that produced the original bug.
		it('renders class-name as a read-only lightning-input when className appears in lockedFields', async() =>
		{
			const {createElement} = require('lwc');
			let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
			element.lockedFields = [
				'objectName',
				'className'
			];
			element.prefill = {className: 'SCHED_PurgeRecords'};
			document.body.appendChild(element);
			await flushPromises();

			let combobox = element.shadowRoot.querySelector('lightning-combobox[data-testid="class-name"]');
			expect(combobox).toBeNull();

			let input = element.shadowRoot.querySelector('lightning-input[data-testid="class-name"]');
			expect(input).toBeTruthy();
			expect(input.readOnly).toBe(true);
			expect(input.value).toBe('SCHED_PurgeRecords');
		});

		it('renders class-name as an editable lightning-combobox when className is not locked', async() =>
		{
			const {createElement} = require('lwc');
			let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
			element.lockedFields = [];
			document.body.appendChild(element);
			await flushPromises();

			let combobox = element.shadowRoot.querySelector('lightning-combobox[data-testid="class-name"]');
			expect(combobox).toBeTruthy();
			expect(combobox.disabled).toBeFalsy();

			let input = element.shadowRoot.querySelector('lightning-input[data-testid="class-name"]');
			expect(input).toBeNull();
		});

		it('does not render any lightning-icon with empty icon-name when locked and prefilled', async() =>
		{
			const {createElement} = require('lwc');
			let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
			element.lockedFields = [
				'objectName',
				'className'
			];
			element.prefill = {
				schedulerName: 'Purge Log Entries',
				className: 'SCHED_PurgeRecords',
				cronExpression: '0 0 2 * * ?',
				isActive: true,
				parameterValues: {objectName: 'kern__LogEntry__c', minimumNumberOfDays: '90'}
			};
			document.body.appendChild(element);
			await flushPromises();

			let icons = element.shadowRoot.querySelectorAll('lightning-icon');

			for(let index = 0; index < icons.length; index++)
			{
				let name = icons[index].iconName || icons[index].getAttribute('icon-name');
				expect(name).toBeTruthy();
				expect(String(name).trim()).not.toBe('');
				expect(String(name).trim()).not.toBe('utility:');
			}
		});

		it('renders the inline error region when loading parameter definitions fails', async() =>
		{
			const getParameterDefinitions = require('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions').default;
			getParameterDefinitions.mockRejectedValue(new Error('Not found'));
			const {createElement} = require('lwc');
			let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
			document.body.appendChild(element);
			await flushPromises();

			let combobox = element.shadowRoot.querySelector('lightning-combobox[data-testid="class-name"]');
			combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'SCHED_BadClass'}}));
			await flushPromises();

			let errorRegion = element.shadowRoot.querySelector('[data-testid="inline-error"]');
			expect(errorRegion).toBeTruthy();
			expect(errorRegion.textContent).toContain('mock error detail');
		});

		it('does not render the inline error region when there is no error', async() =>
		{
			const {createElement} = require('lwc');
			let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
			document.body.appendChild(element);
			await flushPromises();

			expect(element.shadowRoot.querySelector('[data-testid="inline-error"]')).toBeNull();
		});
	});

	describe('template structure', () =>
	{
		it('contains modal header, body, and footer elements', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditorModal.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('lightning-modal-header');
			expect(template).toContain('lightning-modal-body');
			expect(template).toContain('lightning-modal-footer');
		});

		it('contains the inline error region bound to errorMessage', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditorModal.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('data-testid="inline-error"');
			expect(template).toContain('{errorMessage}');
			expect(template).toContain('role="alert"');
		});

		it('contains form fields in modal body', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditorModal.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('lightning-input');
			expect(template).toContain('lightning-combobox');
			expect(template).toContain('lightning-textarea');
			expect(template).toContain('c-cron-expression-editor');
		});

		it('contains Save and Cancel buttons in footer', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditorModal.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('label={label.save}');
			expect(template).toContain('label={label.cancel}');
			expect(template).toContain('variant="brand"');
		});

		it('uses lightning-combobox for unlocked class name and lightning-input for locked class name', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditorModal.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('name="className"');
			expect(template).toContain('isClassNameLocked');
			expect(template).toMatch(/<lightning-input[^>]*data-testid="class-name"[^>]*read-only/);
		});

		it('binds modal title to modalTitle getter', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobEditorModal.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('label={modalTitle}');
		});
	});
});
