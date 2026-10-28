// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the scheduledJobEditorForm LWC module, run through both editors built on it: the
 *              record-page editor and the modal. What only one editor does (where its errors show, what follows a
 *              save, the job runner fields) is tested beside that editor.
 *
 * @author Jason van Beukering
 * @date October 2026
 */
import CREATE_TITLE from '@salesforce/label/c.ScheduledJob_NewTitle';
import EDIT_TITLE from '@salesforce/label/c.ScheduledJob_EditTitle';
import SCHEDULE from '@salesforce/label/c.ScheduledJob_Schedule';
import * as uiRecordApi from 'lightning/uiRecordApi';
import {
	classNameNotSchedulable, createFormContext, findPropertyDescriptor, flushPromises, readBundleTemplate, registerScheduledJobFormMocks, saveFrom
} from './fixtures/editorFormTestSupport';

// No lightning/* or c/* module is jest.mock'd here: such a mock is keyed by the raw specifier, and once another suite in the
// same worker has loaded the real module the component's import resolves to the stub's path, so the mock silently stops
// intercepting. lightning/modal comes from the moduleNameMapper stub in jest.config.js, c/componentBuilder from its global
// mock, and lightning/uiRecordApi is the sfdx-lwc-jest stub, whose getFieldValue is already a jest.fn the tests program.
registerScheduledJobFormMocks();

/**
 * @description The two editors the form is tested through. Each names the members a headless context needs beside the
 *              shared form's: what the editor's own completeSave and connectedCallback reach for.
 */
const HOSTS = [
	{
		tagName: 'c-scheduled-job-editor', bundleName: 'scheduledJobEditor', moduleName: 'c/scheduledJobEditor', labelBag: 'label', hostContext: () => ({
			showSuccessToast: jest.fn(),
			showErrorToast: jest.fn(),
			redirectToRecordPage: jest.fn(),
			loadJobRunnerState: jest.fn().mockResolvedValue(),
			refreshNextRunPreview: jest.fn()
		})
	},
	{
		tagName: 'c-scheduled-job-editor-modal',
		bundleName: 'scheduledJobEditorModal',
		moduleName: 'c/scheduledJobEditorModal',
		labelBag: 'labels',
		hostContext: () => ({disableClose: false, errorMessage: '', close: jest.fn(), dispatchEvent: jest.fn()})
	}
];

describe.each(HOSTS)('the scheduled job form through $tagName', (host) =>
{
	const Component = require(host.moduleName).default;
	const prototype = Component.prototype;
	const {getFieldValue} = uiRecordApi;
	const getSchedulableClasses = require('@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses').default;
	const getParameterDefinitions = require('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions').default;
	const getUserTimezone = require('@salesforce/apex/CTRL_ScheduledJob.getUserTimezone').default;
	const saveRecord = require('@salesforce/apex/CTRL_ScheduledJob.saveRecord').default;

	const getGetter = (name) => findPropertyDescriptor(prototype, name).get;
	const createMockContext = (overrides = {}) => createFormContext(prototype, {...host.hostContext(), ...overrides});

	const mountComponent = (properties = {}) =>
	{
		const {createElement} = require('lwc');
		let element = createElement(host.tagName, {is: Component});
		Object.assign(element, properties);
		document.body.appendChild(element);
		return element;
	};
	const classFieldOf = (element) => element.shadowRoot.querySelector('c-scheduled-job-class-picker[data-testid="class-name"]');
	const saveButtonOf = (element) => element.shadowRoot.querySelector('[data-testid="save-button"]');

	beforeEach(() =>
	{
		// The stub's getFieldValue reads a real record; these tests program each answer, so every test starts with none.
		getFieldValue.mockReset();
	});

	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			expect(Component).toBeDefined();
			expect(typeof Component).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		it.each([
			'recordId',
			'lockedFields'
		])('has @api %s property', (propertyName) =>
		{
			expect(findPropertyDescriptor(prototype, propertyName)).toBeDefined();
		});

		it.each([
			'isCreateMode',
			'formTitle',
			'scheduleHeading',
			'isSaveDisabled',
			'hasBlockingClassNameError',
			'hasParameterDefinitions',
			'editParameterFields'
		])('has %s getter', (getterName) =>
		{
			let descriptor = findPropertyDescriptor(prototype, getterName);
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has wire method for getRecord', () =>
		{
			expect(prototype.wiredRecord).toBeDefined();
		});

		it.each([
			'connectedCallback',
			'applyRecord',
			'handleSchedulerNameChange',
			'handleClassNameChange',
			'handleIsActiveChange',
			'handleDescriptionChange',
			'handleCronChange',
			'handleParameterChange',
			'buildSaveRequest',
			'handleSave',
			'completeSave',
			'reportSaveFailure',
			'handleCancel',
			'loadSchedulableClasses',
			'loadParameterDefinitions',
			'loadUserTimezone'
		])('has %s method', (methodName) =>
		{
			expect(typeof prototype[methodName]).toBe('function');
		});
	});

	describe('DOM rendering', () =>
	{
		it('creates element with @api recordId', () =>
		{
			let element = mountComponent();
			expect(element).toBeTruthy();
			element.recordId = 'a00000000000001';
			expect(element.recordId).toBe('a00000000000001');
		});

		it('exposes @api lockedFields with default empty array', () =>
		{
			let element = mountComponent();
			expect(Array.isArray(element.lockedFields)).toBe(true);
			expect(element.lockedFields).toEqual([]);
			element.lockedFields = ['objectName'];
			expect(element.lockedFields).toEqual(['objectName']);
		});

		it('renders locked parameter input as read-only while leaving others editable', async() =>
		{
			getParameterDefinitions.mockResolvedValue([
				{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true},
				{name: 'minimumNumberOfDays', label: 'Minimum Number Of Days', dataType: 'NUMERIC', isRequired: false}
			]);
			let element = mountComponent({lockedFields: ['objectName']});
			await flushPromises();

			classFieldOf(element).dispatchEvent(new CustomEvent('classchange', {detail: {value: 'SCHED_PurgeRecords'}}));
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
			getParameterDefinitions.mockResolvedValue([
				{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true}
			]);
			let element = mountComponent();
			await flushPromises();

			classFieldOf(element).dispatchEvent(new CustomEvent('classchange', {detail: {value: 'SCHED_PurgeRecords'}}));
			await flushPromises();

			let objectInput = element.shadowRoot.querySelector('lightning-input[data-testid="param-objectName"]');
			expect(objectInput).toBeTruthy();
			expect(objectInput.readOnly).toBe(false);
		});

		describe('a class name picked or typed', () =>
		{
			const mountReadyToSave = async() =>
			{
				getSchedulableClasses.mockResolvedValue(['SCHED_PurgeRecords']);
				let element = mountComponent();
				await flushPromises();
				element.shadowRoot.querySelector('[data-testid="scheduler-name"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'A job'}}));
				element.shadowRoot.querySelector('c-cron-expression-editor').dispatchEvent(new CustomEvent('cronchange', {detail: {value: '0 0 * * * ?', isValid: true}}));
				await flushPromises();
				return element;
			};

			it('offers the listed classes to the class field', async() =>
			{
				let element = await mountReadyToSave();
				expect(classFieldOf(element).options).toEqual([{label: 'SCHED_PurgeRecords', value: 'SCHED_PurgeRecords'}]);
			});

			it('accepts a name the list does not show, loads its parameter form and keeps Save open', async() =>
			{
				getParameterDefinitions.mockResolvedValue([{name: 'failOnPurpose', label: 'Fail on purpose', dataType: 'FLAG', defaultValue: 'false', isRequired: false}]);
				let element = await mountReadyToSave();
				classFieldOf(element).dispatchEvent(new CustomEvent('classchange', {detail: {value: 'FastStart_ScheduledJob_DEMO'}}));
				await flushPromises();
				expect(getParameterDefinitions).toHaveBeenCalledWith({className: 'FastStart_ScheduledJob_DEMO'});
				expect(element.shadowRoot.querySelector('[data-testid="param-failOnPurpose"]')).not.toBeNull();
				expect(classFieldOf(element).errorMessage).toBe('');
				expect(saveButtonOf(element).disabled).toBe(false);
			});

			it('refuses a name that cannot be scheduled at the field and keeps Save closed', async() =>
			{
				getParameterDefinitions.mockRejectedValue(new Error('Unable to resolve type for class "SCHED_NoSuchClass".'));
				let element = await mountReadyToSave();
				classFieldOf(element).dispatchEvent(new CustomEvent('classchange', {detail: {value: 'SCHED_NoSuchClass'}}));
				await flushPromises();
				expect(classFieldOf(element).errorMessage).toBe(classNameNotSchedulable('SCHED_NoSuchClass'));
				expect(saveButtonOf(element).disabled).toBe(true);
			});

			it('shows the parameters of the class picked last when the answer for an earlier class arrives later', async() =>
			{
				const FIRST_CLASS_NAME = 'SCHED_FirstClass';
				const SECOND_CLASS_NAME = 'SCHED_SecondClass';
				let answerFirstClass;
				getParameterDefinitions.mockImplementationOnce(() => new Promise((resolve) =>
				{
					answerFirstClass = resolve;
				}));
				getParameterDefinitions.mockResolvedValueOnce([{name: 'secondParameter', label: 'Second parameter', dataType: 'TEXT', isRequired: false}]);
				let element = await mountReadyToSave();

				classFieldOf(element).dispatchEvent(new CustomEvent('classchange', {detail: {value: FIRST_CLASS_NAME}}));
				classFieldOf(element).dispatchEvent(new CustomEvent('classchange', {detail: {value: SECOND_CLASS_NAME}}));
				await flushPromises();
				answerFirstClass([{name: 'firstParameter', label: 'First parameter', dataType: 'TEXT', isRequired: false}]);
				await flushPromises();

				expect(element.shadowRoot.querySelector('[data-testid="param-secondParameter"]')).not.toBeNull();
				expect(element.shadowRoot.querySelector('[data-testid="param-firstParameter"]')).toBeNull();
				expect(classFieldOf(element).errorMessage).toBe('');
			});

			it('keeps the class picked last accepted when an earlier class is refused later', async() =>
			{
				let refuseFirstClass;
				getParameterDefinitions.mockImplementationOnce(() => new Promise((resolve, reject) =>
				{
					refuseFirstClass = reject;
				}));
				getParameterDefinitions.mockResolvedValueOnce([{name: 'secondParameter', label: 'Second parameter', dataType: 'TEXT', isRequired: false}]);
				let element = await mountReadyToSave();

				classFieldOf(element).dispatchEvent(new CustomEvent('classchange', {detail: {value: 'SCHED_NoSuchClass'}}));
				classFieldOf(element).dispatchEvent(new CustomEvent('classchange', {detail: {value: 'SCHED_SecondClass'}}));
				await flushPromises();
				refuseFirstClass(new Error('Unable to resolve type for class "SCHED_NoSuchClass".'));
				await flushPromises();

				expect(element.shadowRoot.querySelector('[data-testid="param-secondParameter"]')).not.toBeNull();
				expect(classFieldOf(element).errorMessage).toBe('');
				expect(saveButtonOf(element).disabled).toBe(false);
			});
		});
	});

	describe('instance behavior', () =>
	{
		describe('isCreateMode', () =>
		{
			it('returns true when recordId is undefined', () =>
			{
				let context = createMockContext({recordId: undefined});
				expect(getGetter('isCreateMode').call(context)).toBe(true);
			});

			it('returns false when recordId is set', () =>
			{
				let context = createMockContext();
				expect(getGetter('isCreateMode').call(context)).toBe(false);
			});
		});

		describe('formTitle', () =>
		{
			it('returns the create-mode title in create mode', () =>
			{
				let context = createMockContext({recordId: undefined});
				Object.defineProperty(context, 'isCreateMode', {get: () => true});
				expect(getGetter('formTitle').call(context)).toBe(CREATE_TITLE);
			});

			it('returns the edit-mode title in edit mode', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'isCreateMode', {get: () => false});
				expect(getGetter('formTitle').call(context)).toBe(EDIT_TITLE);
			});
		});

		describe('isSaveDisabled', () =>
		{
			const readyToSave = {schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?', cronIsValid: true};

			it.each([
				[
					'saving is in progress',
					{isSaving: true}
				],
				[
					'cron is invalid',
					{cronIsValid: false}
				],
				[
					'scheduler name is empty',
					{schedulerName: ''}
				],
				[
					'class name is empty',
					{className: ''}
				],
				[
					'cron expression is empty',
					{cronExpression: ''}
				],
				[
					'the class field holds an error that closes Save',
					{hasBlockingClassNameError: true}
				]
			])('returns true when %s', (_reason, overrides) =>
			{
				let context = createMockContext({...readyToSave, ...overrides});
				expect(getGetter('isSaveDisabled').call(context)).toBe(true);
			});

			it('returns false when all required fields present and valid', () =>
			{
				let context = createMockContext(readyToSave);
				expect(getGetter('isSaveDisabled').call(context)).toBe(false);
			});

			const withParameter = (definition, parameterValues) =>
			{
				let context = createMockContext({...readyToSave, parameterDefinitions: [definition], parameterValues});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				return context;
			};

			it('returns true when required parameter is empty', () =>
			{
				let context = withParameter({name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true}, {objectName: ''});
				expect(getGetter('isSaveDisabled').call(context)).toBe(true);
			});

			it('returns false when required parameter is populated', () =>
			{
				let context = withParameter({name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true}, {objectName: 'Account'});
				expect(getGetter('isSaveDisabled').call(context)).toBe(false);
			});

			it('returns false when optional parameter is empty', () =>
			{
				let context = withParameter({name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC', isRequired: false}, {batchSize: ''});
				expect(getGetter('isSaveDisabled').call(context)).toBe(false);
			});

			it('returns false when a required parameter is satisfied only by its defaultValue', () =>
			{
				// The parameter input renders pre-filled with the defaultValue, so the form must
				// treat that default as a satisfied required value instead of keeping Save disabled.
				let context = withParameter({name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true, defaultValue: 'LogEntry__c'}, {});
				expect(getGetter('isSaveDisabled').call(context)).toBe(false);
			});

			it('returns true when a required parameter was explicitly cleared despite a defaultValue', () =>
			{
				// An explicit empty entry means the user removed the pre-filled default,
				// so the requirement is no longer satisfied and Save stays disabled.
				let context = withParameter({name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true, defaultValue: 'LogEntry__c'}, {objectName: ''});
				expect(getGetter('isSaveDisabled').call(context)).toBe(true);
			});
		});

		describe('hasBlockingClassNameError', () =>
		{
			it('is true for an error about a class chosen in this edit', () =>
			{
				let context = createMockContext({classNameError: 'refused', className: 'SCHED_Typed', recordClassName: 'SCHED_Saved'});
				expect(getGetter('hasBlockingClassNameError').call(context)).toBe(true);
			});

			it('is false for an error about the class the saved record names, so the job can still be switched off', () =>
			{
				let context = createMockContext({classNameError: 'refused', className: 'SCHED_Saved', recordClassName: 'SCHED_Saved'});
				expect(getGetter('hasBlockingClassNameError').call(context)).toBe(false);
			});

			it('is false without an error', () =>
			{
				let context = createMockContext({classNameError: '', className: 'SCHED_Typed', recordClassName: ''});
				expect(getGetter('hasBlockingClassNameError').call(context)).toBe(false);
			});
		});

		describe('hasParameterDefinitions', () =>
		{
			it('returns false when definitions are null', () =>
			{
				let context = createMockContext({parameterDefinitions: null});
				expect(getGetter('hasParameterDefinitions').call(context)).toBe(false);
			});

			it('returns false when definitions are empty', () =>
			{
				let context = createMockContext({parameterDefinitions: []});
				expect(getGetter('hasParameterDefinitions').call(context)).toBe(false);
			});

			it('returns true when definitions exist', () =>
			{
				let context = createMockContext({parameterDefinitions: [{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}]});
				expect(getGetter('hasParameterDefinitions').call(context)).toBe(true);
			});
		});

		describe('editParameterFields', () =>
		{
			const fieldsFor = (parameterDefinitions, parameterValues, overrides = {}) =>
			{
				let context = createMockContext({parameterDefinitions, parameterValues, ...overrides});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => parameterDefinitions !== null});
				return getGetter('editParameterFields').call(context);
			};

			it('returns empty array when no definitions', () =>
			{
				expect(fieldsFor(null, {})).toEqual([]);
			});

			it('maps TEXT parameters correctly', () =>
			{
				let result = fieldsFor([{name: 'objectName', label: 'Object Name', dataType: 'TEXT', isRequired: true, description: 'API name'}], {objectName: 'Account'});
				expect(result[0].isText).toBe(true);
				expect(result[0].isNumeric).toBe(false);
				expect(result[0].isToggle).toBe(false);
				expect(result[0].value).toBe('Account');
				expect(result[0].isRequired).toBe(true);
				expect(result[0].description).toBe('API name');
			});

			it('maps NUMERIC parameters correctly', () =>
			{
				let result = fieldsFor([{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC', defaultValue: '2000'}], {});
				expect(result[0].isNumeric).toBe(true);
				expect(result[0].isText).toBe(false);
				expect(result[0].value).toBe('2000');
			});

			it('maps FLAG parameters correctly', () =>
			{
				let result = fieldsFor([{name: 'allOrNothing', label: 'All or Nothing', dataType: 'FLAG'}], {allOrNothing: 'true'});
				expect(result[0].isToggle).toBe(true);
				expect(result[0].isText).toBe(false);
				expect(result[0].toggleChecked).toBe(true);
			});

			it('defaults FLAG to unchecked when value is not true', () =>
			{
				let result = fieldsFor([{name: 'allOrNothing', label: 'All or Nothing', dataType: 'FLAG'}], {});
				expect(result[0].toggleChecked).toBe(false);
			});

			it('uses provided value over default', () =>
			{
				let result = fieldsFor([{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC', defaultValue: '2000'}], {batchSize: '500'});
				expect(result[0].value).toBe('500');
			});

			it('marks parameter isLocked and sets testId when name appears in lockedFields', () =>
			{
				let result = fieldsFor([
					{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true},
					{name: 'minimumNumberOfDays', label: 'Minimum Number Of Days', dataType: 'NUMERIC', isRequired: false}
				], {objectName: 'kern__LogEntry__c', minimumNumberOfDays: '90'}, {lockedFields: ['objectName']});
				expect(result[0].isLocked).toBe(true);
				expect(result[0].testId).toBe('param-objectName');
				expect(result[1].isLocked).toBe(false);
				expect(result[1].testId).toBe('param-minimumNumberOfDays');
			});

			it('leaves all parameters unlocked when lockedFields is empty', () =>
			{
				let result = fieldsFor([{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true}], {objectName: 'Account'}, {lockedFields: []});
				expect(result[0].isLocked).toBe(false);
				expect(result[0].testId).toBe('param-objectName');
			});

			it('leaves all parameters unlocked when lockedFields is undefined', () =>
			{
				let result = fieldsFor([{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true}], {objectName: 'Account'}, {lockedFields: undefined});
				expect(result[0].isLocked).toBe(false);
			});

			it('treats a parameter with no dataType as an untyped field', () =>
			{
				let result = fieldsFor([{name: 'mystery', label: 'Mystery', isRequired: false}], {mystery: 'x'});
				expect(result[0].isText).toBe(false);
				expect(result[0].isNumeric).toBe(false);
				expect(result[0].isToggle).toBe(false);
			});
		});

		describe('scheduleHeading', () =>
		{
			it('returns Schedule with timezone when userTimezone is set', () =>
			{
				let result = getGetter('scheduleHeading').call(createMockContext({userTimezone: 'America/New_York'}));
				expect(result).toContain('Schedule (');
				expect(result).toContain(')');
			});

			it('returns plain Schedule when userTimezone is empty', () =>
			{
				expect(getGetter('scheduleHeading').call(createMockContext({userTimezone: ''}))).toBe(SCHEDULE);
			});

			it('falls back to the raw timezone id when Intl cannot format the zone', () =>
			{
				expect(getGetter('scheduleHeading').call(createMockContext({userTimezone: 'Totally/Bogus_Zone'}))).toBe('Schedule (Totally/Bogus_Zone)');
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

			it('remembers the class the saved record names', () =>
			{
				const wiredClassName = 'SCHED_PurgeRecords';
				getFieldValue.mockReturnValueOnce(wiredClassName).mockReturnValue(null);
				let context = createMockContext();
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.recordClassName).toBe(wiredClassName);
			});

			it('does not reload definitions when class name unchanged', () =>
			{
				getFieldValue.mockReturnValue('SCHED_PurgeRecords');
				let context = createMockContext({lastLoadedClassName: 'SCHED_PurgeRecords'});
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
		});

		describe('loadParameterDefinitions', () =>
		{
			it('sets parameter definitions from Apex and reports the class accepted', async() =>
			{
				let mockDefinitions = [{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}];
				getParameterDefinitions.mockResolvedValue(mockDefinitions);
				let context = createMockContext();
				let isAccepted = await prototype.loadParameterDefinitions.call(context, 'SCHED_PurgeRecords');
				expect(context.parameterDefinitions).toEqual(mockDefinitions);
				expect(isAccepted).toBe(true);
			});

			it('sets null, says at the class field that the class cannot be scheduled and reports the name refused', async() =>
			{
				getParameterDefinitions.mockRejectedValue(new Error('Not found'));
				let context = createMockContext({parameterDefinitions: [{name: 'old'}]});
				let isAccepted = await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.parameterDefinitions).toBeNull();
				expect(context.classNameError).toBe(classNameNotSchedulable('BadClassName'));
				expect(isAccepted).toBe(false);
			});

			it('clears the class field error once a name is accepted', async() =>
			{
				getParameterDefinitions.mockResolvedValue(null);
				let context = createMockContext({classNameError: 'stale'});
				await prototype.loadParameterDefinitions.call(context, 'SCHED_PurgeRecords');
				expect(context.classNameError).toBe('');
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

			it('clears the previous class error before the new name is checked', () =>
			{
				let context = createMockContext({classNameError: 'refused'});
				prototype.handleClassNameChange.call(context, {detail: {value: 'SCHED_PurgeRecords'}});
				expect(context.classNameError).toBe('');
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
				prototype.handleParameterChange.call(context, {target: {dataset: {parameterName: 'objectName'}, type: 'text'}, detail: {value: 'Account'}});
				expect(context.parameterValues.objectName).toBe('Account');
			});

			it('updates parameter value for toggle input', () =>
			{
				let context = createMockContext({parameterValues: {}});
				prototype.handleParameterChange.call(context, {target: {dataset: {parameterName: 'allOrNothing'}, type: 'toggle'}, detail: {checked: true}});
				expect(context.parameterValues.allOrNothing).toBe('true');
			});

			it('updates parameter value for number input', () =>
			{
				let context = createMockContext({parameterValues: {}});
				prototype.handleParameterChange.call(context, {target: {dataset: {parameterName: 'batchSize'}, type: 'number'}, detail: {value: '500'}});
				expect(context.parameterValues.batchSize).toBe('500');
			});

			it('preserves existing parameter values', () =>
			{
				let context = createMockContext({parameterValues: {objectName: 'Account'}});
				prototype.handleParameterChange.call(context, {target: {dataset: {parameterName: 'batchSize'}, type: 'number'}, detail: {value: '500'}});
				expect(context.parameterValues.objectName).toBe('Account');
				expect(context.parameterValues.batchSize).toBe('500');
			});

			it('coerces a missing change value to an empty string', () =>
			{
				let context = createMockContext({parameterValues: {}});
				prototype.handleParameterChange.call(context, {target: {dataset: {parameterName: 'objectName'}, type: 'text'}, detail: {}});
				expect(context.parameterValues.objectName).toBe('');
			});
		});

		describe('handleSave', () =>
		{
			/**
			 * @description Saves from a context ready to save and returns the request the controller received.
			 *
			 * @param {Object} overrides State the test sets on top of a form ready to save.
			 * @param {boolean} hasParameterDefinitions Whether the context reports parameters to serialise.
			 *
			 * @return {Promise<Object>} The parsed save request.
			 */
			const saveAndReadRequest = async(overrides = {}, hasParameterDefinitions = false) =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				await saveFrom(prototype, createMockContext, overrides, hasParameterDefinitions);
				return JSON.parse(saveRecord.mock.calls[0][0].requestJson);
			};

			it('sends the form as the save request', async() =>
			{
				let request = await saveAndReadRequest({
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
				}, true);
				expect(request).toEqual(expect.objectContaining({
					recordId: 'a00000000000001', schedulerName: 'Purge Records', parameters: {objectName: 'LogEntry__c', batchSize: '500'}, timezone: 'Africa/Johannesburg'
				}));
			});

			it('includes timezone in save payload', async() =>
			{
				let request = await saveAndReadRequest({userTimezone: 'America/New_York'});
				expect(request.timezone).toBe('America/New_York');
			});

			it('sends null parameters when no parameter definitions', async() =>
			{
				let request = await saveAndReadRequest({parameterDefinitions: null});
				expect(request.parameters).toBeNull();
			});

			it('sends parameter values map when definitions exist', async() =>
			{
				let request = await saveAndReadRequest({
					parameterDefinitions: [
						{name: 'objectName', label: 'Object Name', dataType: 'TEXT'},
						{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC'}
					], parameterValues: {objectName: 'Account', batchSize: ''}
				}, true);
				expect(request.parameters).toEqual({objectName: 'Account', batchSize: ''});
			});

			it('sets isSaving during save and resets after', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = await saveFrom(prototype, createMockContext);
				expect(context.isSaving).toBe(false);
			});

			it('resets isSaving after failure', async() =>
			{
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = await saveFrom(prototype, createMockContext);
				expect(context.isSaving).toBe(false);
			});

			it('sends null recordId in create mode instead of undefined', async() =>
			{
				let request = await saveAndReadRequest({recordId: undefined});
				expect(request.recordId).toBeNull();
			});

			it('sends boolean true for isActive when toggled on', async() =>
			{
				let request = await saveAndReadRequest({isActive: true});
				expect(request.isActive).toBe(true);
			});

			it('sends boolean false for isActive when not toggled', async() =>
			{
				let request = await saveAndReadRequest({isActive: false});
				expect(request.isActive).toBe(false);
			});

			it('serializes a null parameter value as an empty string in the save payload', async() =>
			{
				let request = await saveAndReadRequest({
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT'}], parameterValues: {objectName: null}
				}, true);
				expect(request.parameters.objectName).toBe('');
			});

			it('serializes an empty string when a parameter has neither a value nor a defaultValue', async() =>
			{
				let request = await saveAndReadRequest({parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT'}], parameterValues: {}}, true);
				expect(request.parameters.objectName).toBe('');
			});

			it('persists an untouched parameter defaultValue in the save payload', async() =>
			{
				// The form displays the defaultValue, so saving without touching the input
				// must persist exactly what the user saw instead of dropping the parameter.
				let request = await saveAndReadRequest({
					parameterDefinitions: [
						{name: 'objectName', label: 'Object', dataType: 'TEXT', isRequired: true, defaultValue: 'LogEntry__c'},
						{name: 'minimumNumberOfDays', label: 'Minimum Number Of Days', dataType: 'NUMERIC', defaultValue: '30'}
					], parameterValues: {}
				}, true);
				expect(request.parameters).toEqual({objectName: 'LogEntry__c', minimumNumberOfDays: '30'});
			});

			it('prunes parameter values from a previously selected class out of the save payload', async() =>
			{
				// Switching schedulable classes leaves the old class's entries in parameterValues;
				// only parameters defined for the currently selected class may be serialised.
				let request = await saveAndReadRequest({
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT'}],
					parameterValues: {objectName: 'Account', staleParameterFromPreviousClass: 'stale'}
				}, true);
				expect(request.parameters).toEqual({objectName: 'Account'});
			});

			it('keeps an explicitly cleared parameter empty instead of restoring its defaultValue', async() =>
			{
				// Checks the what-you-see-is-what-saves rule: a cleared input shows empty,
				// so the payload carries an empty string, not the resurrected default.
				let request = await saveAndReadRequest({
					parameterDefinitions: [{name: 'objectName', label: 'Object', dataType: 'TEXT', defaultValue: 'LogEntry__c'}], parameterValues: {objectName: ''}
				}, true);
				expect(request.parameters.objectName).toBe('');
			});
		});
	});

	describe('template structure', () =>
	{
		it('contains the form fields', () =>
		{
			let template = readBundleTemplate(host.bundleName);
			expect(template).toContain('lightning-input');
			expect(template).toContain('c-scheduled-job-class-picker');
			expect(template).toContain('lightning-textarea');
			expect(template).toContain('c-cron-expression-editor');
		});

		it('contains Save and Cancel buttons', () =>
		{
			let template = readBundleTemplate(host.bundleName);
			expect(template).toContain(`label={${host.labelBag}.save}`);
			expect(template).toContain(`label={${host.labelBag}.cancel}`);
			expect(template).toContain('variant="brand"');
		});

		it('uses the class picker for the class name', () =>
		{
			let template = readBundleTemplate(host.bundleName);
			expect(template).toContain('onclasschange={handleClassNameChange}');
			expect(template).toContain('error-message={classNameError}');
		});

		it('binds the title to the formTitle getter', () =>
		{
			expect(readBundleTemplate(host.bundleName)).toContain('{formTitle}');
		});
	});
});
