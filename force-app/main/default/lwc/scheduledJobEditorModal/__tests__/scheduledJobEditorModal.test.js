// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the scheduledJobEditorModal LWC component: what the modal adds to the shared
 *              scheduled job form. The form itself is tested through this modal in scheduledJobEditorForm's suite.
 *
 * @author Jason van Beukering
 * @date March 2026, October 2026
 */
import LOAD_RECORD_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_LoadRecordFailed';
import SAVE_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_SaveFailed';
import SUCCESS_TOAST_TITLE from '@salesforce/label/c.ScheduledJobEditorModal_SuccessToastTitle';
import CREATED from '@salesforce/label/c.ScheduledJob_Created';
import SAVED from '@salesforce/label/c.ScheduledJob_Saved';
import * as utilitySystem from 'c/utilitySystem';
import * as uiRecordApi from 'lightning/uiRecordApi';
import {
	classNameNotSchedulable, createFormContext, findPropertyDescriptor, flushPromises, readBundleTemplate, READY_TO_SAVE, registerScheduledJobFormMocks, saveFrom
} from '../../scheduledJobEditorForm/__tests__/fixtures/editorFormTestSupport';

// No lightning/* or c/* module is jest.mock'd here: such a mock is keyed by the raw specifier, and once another suite in the
// same worker has loaded the real module the component's import resolves to the stub's path, so the mock silently stops
// intercepting. Instead:
//   - lightning/modal comes from the moduleNameMapper stub in jest.config.js;
//   - lightning/uiRecordApi is the sfdx-lwc-jest stub, whose getFieldValue is already a jest.fn the tests program;
//   - lightning/platformShowToastEvent is the sfdx-lwc-jest stub, which builds a CustomEvent('lightning__showtoast')
//     carrying the toast in `detail`, so the tests assert on the event the component dispatched;
//   - c/utilitySystem's reduceErrors is spied on below.
const dispatchedToasts = (context) => context.dispatchEvent.mock.calls.map(([event]) => event).filter((event) => event.type === 'lightning__showtoast');

registerScheduledJobFormMocks();

// The job runner fields the modal reads beside the shared form's fields, named the way the tests program getFieldValue.
jest.mock('@salesforce/schema/ScheduledJob__c.ExecutionMode__c', () => ({default: 'ScheduledJob__c.ExecutionMode__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.RunPriority__c', () => ({default: 'ScheduledJob__c.RunPriority__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.OverlapPolicy__c', () => ({default: 'ScheduledJob__c.OverlapPolicy__c'}), {virtual: true});

describe('c-scheduled-job-editor-modal', () =>
{
	const ScheduledJobEditorModal = require('c/scheduledJobEditorModal').default;
	const prototype = ScheduledJobEditorModal.prototype;
	const {getFieldValue} = uiRecordApi;
	const getSchedulableClasses = require('@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses').default;
	const getParameterDefinitions = require('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions').default;
	const getUserTimezone = require('@salesforce/apex/CTRL_ScheduledJob.getUserTimezone').default;
	const saveRecord = require('@salesforce/apex/CTRL_ScheduledJob.saveRecord').default;

	const getGetter = (name) => findPropertyDescriptor(prototype, name).get;

	const createMockContext = (overrides = {}) => createFormContext(prototype, {
		disableClose: false, errorMessage: '', close: jest.fn(), dispatchEvent: jest.fn(), ...overrides
	});

	const mountModal = (properties = {}) =>
	{
		const {createElement} = require('lwc');
		let element = createElement('c-scheduled-job-editor-modal', {is: ScheduledJobEditorModal});
		Object.assign(element, properties);
		document.body.appendChild(element);
		return element;
	};

	// A spy on the real module's export, not jest.mock('c/utilitySystem'): such a mock stops intercepting once another
	// suite in the same worker has loaded the real module, while a spy replaces the export the component itself calls.
	beforeEach(() =>
	{
		jest.spyOn(utilitySystem, 'reduceErrors').mockReturnValue('mock error detail');
		// The stub's getFieldValue reads a real record; these tests program each answer, so every test starts with none.
		getFieldValue.mockReset();
	});

	afterEach(() =>
	{
		utilitySystem.reduceErrors.mockRestore();
		jest.clearAllMocks();
	});

	describe('class structure', () =>
	{
		it('has @api prefill property', () =>
		{
			expect(findPropertyDescriptor(prototype, 'prefill')).toBeDefined();
		});

		it.each([
			'isClassNameLocked',
			'hasErrorMessage'
		])('has %s getter', (getterName) =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, getterName);
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});
	});

	describe('instance behavior', () =>
	{
		describe('hasErrorMessage', () =>
		{
			it('returns false when errorMessage is empty', () =>
			{
				expect(getGetter('hasErrorMessage').call(createMockContext({errorMessage: ''}))).toBe(false);
			});

			it('returns true when errorMessage is set', () =>
			{
				expect(getGetter('hasErrorMessage').call(createMockContext({errorMessage: 'Something went wrong'}))).toBe(true);
			});
		});

		describe('isClassNameLocked', () =>
		{
			it.each([
				[
					'returns true when className appears in lockedFields',
					[
						'objectName',
						'className'
					],
					true
				],
				[
					'returns false when className is not in lockedFields',
					['objectName'],
					false
				],
				[
					'returns false when lockedFields is empty',
					[],
					false
				],
				[
					'returns false when lockedFields is undefined',
					undefined,
					false
				]
			])('%s', (_title, lockedFields, expected) =>
			{
				expect(getGetter('isClassNameLocked').call(createMockContext({lockedFields}))).toBe(expected);
			});
		});

		describe('wiredRecord', () =>
		{
			it('surfaces a record load failure inside the modal instead of dispatching a toast', () =>
			{
				// Toasts dispatched while a LightningModal is open are swallowed by the overlay,
				// so load errors must render in the modal's inline error region instead.
				let context = createMockContext();
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.errorMessage).toBe('mock error detail');
				expect(context.dispatchEvent).not.toHaveBeenCalled();
				expect(dispatchedToasts(context)).toEqual([]);
			});

			it('uses the fallback label when reduceErrors returns empty on wire error', () =>
			{
				utilitySystem.reduceErrors.mockReturnValueOnce('');
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
				expect(context.jobRunnerSettings).toEqual({executionMode: null, runPriority: null, overlapPolicy: null});
			});

			it('keeps the job runner fields of the loaded record and sends them back unchanged on save', async() =>
			{
				const savedRunPriority = 4;
				const savedFields = {
					'ScheduledJob__c.ExecutionMode__c': 'JobRunner', 'ScheduledJob__c.RunPriority__c': savedRunPriority, 'ScheduledJob__c.OverlapPolicy__c': 'Allow'
				};
				getFieldValue.mockImplementation((record, field) => savedFields[field] ?? null);
				let context = createMockContext();
				prototype.wiredRecord.call(context, {data: {fields: {}}});

				expect(context.jobRunnerSettings).toEqual({executionMode: 'JobRunner', runPriority: savedRunPriority, overlapPolicy: 'Allow'});
				expect(getGetter('isJobRunnerMode').call(context)).toBe(true);

				saveRecord.mockResolvedValue('a00000000000001');
				await saveFrom(prototype, createMockContext, {jobRunnerSettings: context.jobRunnerSettings});
				let request = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(request).toEqual(expect.objectContaining({executionMode: 'JobRunner', runPriority: savedRunPriority, overlapPolicy: 'Allow'}));
			});

			it('is not in job runner mode for a record that keeps its own scheduled job', () =>
			{
				expect(getGetter('isJobRunnerMode').call(createMockContext({jobRunnerSettings: {executionMode: 'OwnScheduledJob'}}))).toBe(false);
			});
		});

		describe('loadParameterDefinitions', () =>
		{
			it('refuses a class name at the field, with no toast and no modal error', async() =>
			{
				getParameterDefinitions.mockRejectedValue(new Error('Not found'));
				let context = createMockContext({parameterDefinitions: [{name: 'old'}]});
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.parameterDefinitions).toBeNull();
				expect(context.classNameError).toBe(classNameNotSchedulable('BadClassName'));
				expect(context.errorMessage).toBe('');
				expect(dispatchedToasts(context)).toEqual([]);
			});

			it('also puts the refusal in the modal error region when the class name is locked', async() =>
			{
				getParameterDefinitions.mockRejectedValue(new Error('Not found'));
				let context = createMockContext({isClassNameLocked: true});
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.errorMessage).toBe(classNameNotSchedulable('BadClassName'));
			});

			it('leaves the modal error alone when a later request replaced this one', async() =>
			{
				let context = createMockContext({isClassNameLocked: true, errorMessage: 'kept'});
				// A newer request starts while this one waits for its answer.
				getParameterDefinitions.mockImplementation(() =>
				{
					context.parameterRequestNumber += 1;
					return Promise.reject(new Error('Not found'));
				});
				let result = await prototype.loadParameterDefinitions.call(context, 'SCHED_PurgeRecords');
				expect(result).toBeNull();
				expect(context.errorMessage).toBe('kept');
			});

			it('clears the inline error when definitions load successfully', async() =>
			{
				getParameterDefinitions.mockResolvedValue([{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}]);
				let context = createMockContext({errorMessage: 'stale error'});
				await prototype.loadParameterDefinitions.call(context, 'SCHED_PurgeRecords');
				expect(context.errorMessage).toBe('');
			});
		});

		describe('handleSave', () =>
		{
			const saveModal = (overrides = {}) => saveFrom(prototype, createMockContext, overrides);

			/**
			 * @description Builds a context ready to save in edit mode and records every value disableClose takes during the
			 *              save, so the close guard's timing can be asserted.
			 *
			 * @return {{context: Object, disableCloseValues: boolean[]}} The context and the values, in the order they were set.
			 */
			const createCloseGuardContext = () =>
			{
				let context = createMockContext(READY_TO_SAVE);
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

				return {context, disableCloseValues};
			};

			it('closes the modal with the saved record id', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = await saveModal();
				expect(context.close).toHaveBeenCalledWith('a00000000000001');
			});

			it('dispatches success toast with create message in create mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000NEW');
				let context = await saveModal({recordId: undefined, schedulerName: 'Test', cronExpression: '0 0 * * * ?'});
				expect(dispatchedToasts(context).map((event) => event.detail)).toEqual([
					expect.objectContaining({
						title: SUCCESS_TOAST_TITLE, message: CREATED, variant: 'success'
					})
				]);
				expect(context.close).toHaveBeenCalledWith('a00000000000NEW');
			});

			it('dispatches success toast with edit message in edit mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = await saveModal();
				expect(dispatchedToasts(context).map((event) => event.detail)).toEqual([
					expect.objectContaining({
						title: SUCCESS_TOAST_TITLE, message: SAVED, variant: 'success'
					})
				]);
			});

			it('sets disableClose during save', async() =>
			{
				saveRecord.mockImplementation(() => Promise.resolve('a00000000000001'));
				let {context, disableCloseValues} = createCloseGuardContext();

				await prototype.handleSave.call(context);
				expect(disableCloseValues).toContain(true);
				expect(disableCloseValues[disableCloseValues.length - 1]).toBe(false);
			});

			it('releases disableClose before invoking close() on successful save', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let {context, disableCloseValues} = createCloseGuardContext();
				let disableCloseAtCloseCall;

				context.close = jest.fn(() =>
				{
					disableCloseAtCloseCall = disableCloseValues[disableCloseValues.length - 1];
				});

				await prototype.handleSave.call(context);

				expect(context.close).toHaveBeenCalledWith('a00000000000001');
				expect(disableCloseAtCloseCall).toBe(false);
			});

			it('surfaces a save failure inside the modal instead of dispatching a toast', async() =>
			{
				// Toasts dispatched while a LightningModal is open are swallowed by the overlay,
				// so save errors must render in the modal's inline error region instead.
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = await saveModal();
				expect(context.errorMessage).toBe('mock error detail');
				expect(context.dispatchEvent).not.toHaveBeenCalled();
				expect(dispatchedToasts(context)).toEqual([]);
				expect(context.close).not.toHaveBeenCalled();
			});

			it('shows the fallback label inline when reduceErrors fails', async() =>
			{
				utilitySystem.reduceErrors.mockImplementationOnce(() =>
				{
					throw new Error('reduce failed');
				});
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = await saveModal();
				expect(context.errorMessage).toBe(SAVE_FAILED_LABEL);
			});

			it('shows the fallback label inline when reduceErrors returns empty', async() =>
			{
				utilitySystem.reduceErrors.mockReturnValueOnce('');
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = await saveModal();
				expect(context.errorMessage).toBe(SAVE_FAILED_LABEL);
			});

			it('clears a previous inline error when a new save attempt starts', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = await saveModal({errorMessage: 'stale error'});
				expect(context.errorMessage).toBe('');
			});

			it('closes with recordId as fallback when saveRecord returns null', async() =>
			{
				saveRecord.mockResolvedValue(null);
				let context = await saveModal();
				expect(context.close).toHaveBeenCalledWith('a00000000000001');
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
		beforeEach(() =>
		{
			getSchedulableClasses.mockResolvedValue([]);
			getUserTimezone.mockResolvedValue('UTC');
		});

		/**
		 * @description Builds the bare context connectedCallback runs on for a new record with a prefill.
		 *
		 * @param {Object} prefill The payload Health Check hands the modal.
		 * @param {Object} overrides State the test sets, such as a recordId or locked fields.
		 *
		 * @return {Object} The context.
		 */
		const createPrefillContext = (prefill, overrides = {}) => ({
			recordId: undefined,
			schedulerName: '',
			className: '',
			cronExpression: '',
			isActive: false,
			description: '',
			parameterValues: {},
			lastLoadedClassName: undefined,
			prefill,
			loadSchedulableClasses: jest.fn().mockResolvedValue(),
			loadUserTimezone: jest.fn().mockResolvedValue(),
			loadParameterDefinitions: jest.fn().mockResolvedValue(), ...overrides
		});

		it('initialises form state from the prefill payload when there is no recordId', () =>
		{
			const prefillClassName = 'SCHED_PurgeRecords';
			let context = createPrefillContext({
				schedulerName: 'Purge Log Entries',
				className: prefillClassName,
				cronExpression: '0 0 2 * * ?',
				isActive: true,
				parameterValues: {objectName: 'kern__LogEntry__c', minimumNumberOfDays: '90'}
			}, {
				lockedFields: [
					'objectName',
					'className'
				]
			});

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
			let context = createPrefillContext({schedulerName: 'Should not win', className: 'kern.Other', cronExpression: '0 0 5 * * ?'}, {recordId: 'a00xx00000001'});

			prototype.connectedCallback.call(context);

			expect(context.schedulerName).not.toBe('Should not win');
			expect(context.className).not.toBe('kern.Other');
			expect(context.loadParameterDefinitions).not.toHaveBeenCalled();
		});

		it('triggers loadParameterDefinitions when prefill supplies className', () =>
		{
			const prefillClassName = 'SCHED_PurgeRecords';
			let context = createPrefillContext({className: prefillClassName});

			prototype.connectedCallback.call(context);

			expect(context.loadParameterDefinitions).toHaveBeenCalledWith(prefillClassName);
			expect(context.lastLoadedClassName).toBe(prefillClassName);
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
				let context = createPrefillContext({className: prefillClassName});

				prototype.connectedCallback.call(context);

				expect(context.className).toBe(prefillClassName);
				expect(context.loadParameterDefinitions).toHaveBeenCalledWith(prefillClassName);
				expect(context.lastLoadedClassName).toBe(prefillClassName);
			});
		});

		it('does not call loadParameterDefinitions when prefill has no className', () =>
		{
			let context = createPrefillContext({schedulerName: 'Only Name'});

			prototype.connectedCallback.call(context);

			expect(context.loadParameterDefinitions).not.toHaveBeenCalled();
			expect(context.schedulerName).toBe('Only Name');
		});

		it('applies prefill description when supplied', () =>
		{
			let context = createPrefillContext({description: 'Prefilled description text'});

			prototype.connectedCallback.call(context);

			expect(context.description).toBe('Prefilled description text');
		});

		it('connectedCallback still calls loadSchedulableClasses and loadUserTimezone even when prefill is supplied', () =>
		{
			let context = createPrefillContext({schedulerName: 'Name'});

			prototype.connectedCallback.call(context);

			expect(context.loadSchedulableClasses).toHaveBeenCalled();
			expect(context.loadUserTimezone).toHaveBeenCalled();
		});

		// Root-cause fix: when the field is locked we render a read-only lightning-input,
		// which sidesteps the classOptions async-load race that produced the original bug.
		it('renders class-name as a read-only lightning-input when className appears in lockedFields', async() =>
		{
			let element = mountModal({
				lockedFields: [
					'objectName',
					'className'
				], prefill: {className: 'SCHED_PurgeRecords'}
			});
			await flushPromises();

			expect(element.shadowRoot.querySelector('c-scheduled-job-class-picker[data-testid="class-name"]')).toBeNull();

			let input = element.shadowRoot.querySelector('lightning-input[data-testid="class-name"]');
			expect(input).toBeTruthy();
			expect(input.readOnly).toBe(true);
			expect(input.value).toBe('SCHED_PurgeRecords');
		});

		it('renders class-name as the class picker when className is not locked', async() =>
		{
			let element = mountModal({lockedFields: []});
			await flushPromises();

			expect(element.shadowRoot.querySelector('c-scheduled-job-class-picker[data-testid="class-name"]')).toBeTruthy();
			expect(element.shadowRoot.querySelector('lightning-input[data-testid="class-name"]')).toBeNull();
		});

		it('does not render any lightning-icon with empty icon-name when locked and prefilled', async() =>
		{
			let element = mountModal({
				lockedFields: [
					'objectName',
					'className'
				], prefill: {
					schedulerName: 'Purge Log Entries',
					className: 'SCHED_PurgeRecords',
					cronExpression: '0 0 2 * * ?',
					isActive: true,
					parameterValues: {objectName: 'kern__LogEntry__c', minimumNumberOfDays: '90'}
				}
			});
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

		it('shows a refused class name under the class field, not in the modal error region', async() =>
		{
			getParameterDefinitions.mockRejectedValue(new Error('Not found'));
			let element = mountModal();
			await flushPromises();

			let classField = element.shadowRoot.querySelector('c-scheduled-job-class-picker[data-testid="class-name"]');
			classField.dispatchEvent(new CustomEvent('classchange', {detail: {value: 'SCHED_BadClass'}}));
			await flushPromises();

			expect(classField.errorMessage).toBe(classNameNotSchedulable('SCHED_BadClass'));
			expect(element.shadowRoot.querySelector('[data-testid="inline-error"]')).toBeNull();
		});

		it('a locked prefill with a rejected definition read shows the label in the modal error region', async() =>
		{
			getParameterDefinitions.mockRejectedValue(new Error('Not found'));
			let element = mountModal({lockedFields: ['className'], prefill: {schedulerName: 'Watchdog', className: 'SCHED_GoneAway', cronExpression: '0 0 * * * ?'}});
			await flushPromises();

			expect(element.shadowRoot.querySelector('c-scheduled-job-class-picker')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="inline-error-message"]').textContent).toBe(classNameNotSchedulable('SCHED_GoneAway'));
			expect(element.shadowRoot.querySelector('[data-testid="save-button"]').disabled).toBe(true);
		});

		it('does not render the inline error region when there is no error', async() =>
		{
			let element = mountModal();
			await flushPromises();

			expect(element.shadowRoot.querySelector('[data-testid="inline-error"]')).toBeNull();
		});
	});

	describe('an existing job runner record', () =>
	{
		it('opens a stepped expression the job runner accepts with the cron editor valid and Save enabled', async() =>
		{
			const RUNNER_EXPRESSION = '0 */15 * * * ?';
			const savedFields = {
				'ScheduledJob__c.SchedulerName__c': 'Runner job',
				'ScheduledJob__c.ClassName__c': 'SCHED_Test',
				'ScheduledJob__c.CronExpression__c': RUNNER_EXPRESSION,
				'ScheduledJob__c.ExecutionMode__c': 'JobRunner'
			};
			getFieldValue.mockImplementation((record, field) => savedFields[field] ?? null);
			getSchedulableClasses.mockResolvedValue(['SCHED_Test']);
			getUserTimezone.mockResolvedValue('UTC');
			getParameterDefinitions.mockResolvedValue([]);
			let element = mountModal({recordId: 'a00000000000001'});
			await flushPromises();

			uiRecordApi.getRecord.emit({fields: {}});
			await flushPromises();

			let cronEditor = element.shadowRoot.querySelector('c-cron-expression-editor');
			expect(cronEditor.jobRunnerMode).toBe(true);
			expect(cronEditor.cronExpression).toBe(RUNNER_EXPRESSION);
			expect(cronEditor.isValid).toBe(true);
			expect(element.shadowRoot.querySelector('[data-testid="save-button"]').disabled).toBe(false);

			// Switching the editor to custom mode keeps the expression and makes the editor report its validity again.
			cronEditor.shadowRoot.querySelector('[data-testid="cron-mode"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushPromises();

			expect(element.shadowRoot.querySelector('[data-testid="save-button"]').disabled).toBe(false);
		});
	});

	describe('template structure', () =>
	{
		it('contains modal header, body, and footer elements', () =>
		{
			let template = readBundleTemplate('scheduledJobEditorModal');
			expect(template).toContain('lightning-modal-header');
			expect(template).toContain('lightning-modal-body');
			expect(template).toContain('lightning-modal-footer');
		});

		it('contains the inline error region bound to errorMessage', () =>
		{
			let template = readBundleTemplate('scheduledJobEditorModal');
			expect(template).toContain('data-testid="inline-error"');
			expect(template).toContain('{errorMessage}');
			expect(template).toContain('role="alert"');
		});

		it('renders a locked class name as a read-only lightning-input', () =>
		{
			let template = readBundleTemplate('scheduledJobEditorModal');
			expect(template).toContain('isClassNameLocked');
			expect(template).toMatch(/<lightning-input[^>]*data-testid="class-name"[^>]*read-only/);
		});
	});
});
