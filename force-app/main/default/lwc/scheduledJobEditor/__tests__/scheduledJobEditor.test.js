// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the scheduledJobEditor LWC component: what the record-page editor adds to the
 *              shared scheduled job form. The form itself is tested through this editor in scheduledJobEditorForm's suite.
 *
 * @author Jason van Beukering
 * @date March 2026, October 2026
 */
import LOAD_RECORD_FAILED from '@salesforce/label/c.ScheduledJob_LoadRecordFailed';
import CREATED from '@salesforce/label/c.ScheduledJob_Created';
import SAVED from '@salesforce/label/c.ScheduledJob_Saved';
import SAVE_FAILED from '@salesforce/label/c.ScheduledJob_SaveFailed';
import * as utilitySystem from 'c/utilitySystem';
import * as uiRecordApi from 'lightning/uiRecordApi';
import {
	createFormContext, findPropertyDescriptor, flushPromises, readBundleTemplate, registerScheduledJobFormMocks, saveFrom
} from '../../scheduledJobEditorForm/__tests__/fixtures/editorFormTestSupport';

const mockShowSuccessToast = jest.fn();
const mockShowErrorToast = jest.fn();
const mockShowInfoToast = jest.fn();
const mockShowWarningToast = jest.fn();
const mockCallControllerMethod = jest.fn().mockResolvedValue({});
const mockRedirectToRecordPage = jest.fn();

// c/componentBuilder is the one c/* module mocked here: jest.config.js maps it to its global mock, so the mock's id does
// not depend on the resolver cache and the mock keeps intercepting whatever ran earlier in the worker. The other modules
// use patterns that keep working whatever ran first: lightning/uiRecordApi is the sfdx-lwc-jest stub (getFieldValue and notifyRecordUpdateAvailable
// are jest.fn), c/utilitySystem's reduceErrors is spied on below, and c/cronExpressionEditor renders for real.
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

jest.mock('@salesforce/schema/ScheduledJob__c.ExecutionMode__c', () => ({default: 'ScheduledJob__c.ExecutionMode__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.RunPriority__c', () => ({default: 'ScheduledJob__c.RunPriority__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.OverlapPolicy__c', () => ({default: 'ScheduledJob__c.OverlapPolicy__c'}), {virtual: true});

jest.mock('@salesforce/apex/CTRL_ScheduledJob.getJobRunnerState', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ScheduledJob.previewNextRun', () => ({default: jest.fn()}), {virtual: true});

// The job runner labels resolve to their shipped values so the notes, the option labels and the
// next-run line can be asserted as a subscriber reads them, rather than as the default 'c.X' stub.
jest.mock('@salesforce/label/c.ScheduledJob_ExecutionMode', () => ({default: 'Execution mode'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_ExecutionModeOwn', () => ({default: 'Its own scheduled job'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_ExecutionModeJobRunner', () => ({default: 'Job runner'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_JobRunnerInactiveNote', () => ({default: 'Activate the job runner in Health Check first; this job will wait until then.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_JobRunnerActiveNote',
		() => ({default: 'This job runs at the first job runner check on or after each scheduled time (the runner checks every {0} minutes).'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_JobRunnerPermissionNote', () => ({default: 'You need the Manage Job Runner permission to put a job on the job runner.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_RunPriority', () => ({default: 'Run priority'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_RunPriorityHelp', () => ({default: 'Lower numbers start first when several jobs are due at the same check. Leave blank to go last.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_OverlapPolicy', () => ({default: 'Overlap policy'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_OverlapPolicySkip', () => ({default: 'Skip this run while the previous one is still running'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_OverlapPolicyAllow', () => ({default: 'Allow runs to overlap'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_NextRunPreview', () => ({default: 'Next run: {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_NextRunPreviewUnavailable', () => ({default: 'Next run: not available until the expression is valid'}), {virtual: true});

registerScheduledJobFormMocks();

const RUNNER_CHECK_INTERVAL_MINUTES = 15;
const SLOWER_RUNNER_CHECK_INTERVAL_MINUTES = 30;

describe('c-scheduled-job-editor', () =>
{
	const ScheduledJobEditor = require('c/scheduledJobEditor').default;
	const prototype = ScheduledJobEditor.prototype;
	const {getFieldValue, notifyRecordUpdateAvailable} = uiRecordApi;
	const getParameterDefinitions = require('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions').default;
	const getSchedulableClasses = require('@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses').default;
	const getUserTimezone = require('@salesforce/apex/CTRL_ScheduledJob.getUserTimezone').default;
	const saveRecord = require('@salesforce/apex/CTRL_ScheduledJob.saveRecord').default;
	const getJobRunnerState = require('@salesforce/apex/CTRL_ScheduledJob.getJobRunnerState').default;
	const previewNextRun = require('@salesforce/apex/CTRL_ScheduledJob.previewNextRun').default;

	const getGetter = (name) => findPropertyDescriptor(prototype, name).get;

	const createMockContext = (overrides = {}) => createFormContext(prototype, {
		showSuccessToast: mockShowSuccessToast,
		showErrorToast: mockShowErrorToast,
		redirectToRecordPage: mockRedirectToRecordPage,
		loadJobRunnerState: jest.fn().mockResolvedValue(),
		refreshNextRunPreview: jest.fn(), ...overrides
	});

	const mountEditor = () =>
	{
		const {createElement} = require('lwc');
		let element = createElement('c-scheduled-job-editor', {is: ScheduledJobEditor});
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
		it.each([
			'isJobRunnerMode',
			'executionModeOptions',
			'isExecutionModeDisabled',
			'showPermissionNote',
			'activeCheckIntervalMinutes',
			'jobRunnerNote',
			'overlapPolicyOptions',
			'nextRunPreviewLabel'
		])('has %s getter', (getterName) =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, getterName);
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it.each([
			'handleExecutionModeChange',
			'handleRunPriorityChange',
			'handleOverlapPolicyChange',
			'loadJobRunnerState',
			'refreshNextRunPreview'
		])('has %s method', (methodName) =>
		{
			expect(typeof prototype[methodName]).toBe('function');
		});
	});

	describe('DOM rendering', () =>
	{
		describe('execution mode', () =>
		{
			it('offers both modes and disables the runner option without the permission', async() =>
			{
				getJobRunnerState.mockResolvedValue({isActive: true, checkIntervalMinutes: RUNNER_CHECK_INTERVAL_MINUTES, canManage: false});
				let element = mountEditor();
				await flushPromises();

				let radio = element.shadowRoot.querySelector('[data-testid="execution-mode"]');
				expect(radio).not.toBeNull();
				expect(radio.options.map((option) => option.value)).toEqual([
					'OwnScheduledJob',
					'JobRunner'
				]);
				expect(radio.disabled).toBe(true);
				expect(element.shadowRoot.querySelector('[data-testid="job-runner-permission-note"]').textContent)
				.toBe('You need the Manage Job Runner permission to put a job on the job runner.');
			});

			it('shows the runner fields, the interval note and the next-run preview in runner mode', async() =>
			{
				getJobRunnerState.mockResolvedValue({isActive: true, checkIntervalMinutes: RUNNER_CHECK_INTERVAL_MINUTES, canManage: true});
				previewNextRun.mockResolvedValue('2026-09-11T14:15:00.000Z');
				let element = mountEditor();
				await flushPromises();

				element.shadowRoot.querySelector('[data-testid="execution-mode"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'JobRunner'}}));
				await flushPromises();

				expect(element.shadowRoot.querySelector('[data-testid="run-priority"]')).not.toBeNull();
				expect(element.shadowRoot.querySelector('[data-testid="overlap-policy"]').value).toBe('Skip');
				expect(element.shadowRoot.querySelector('[data-testid="job-runner-note"]').textContent).toContain('every 15 minutes');
				let cronEditor = element.shadowRoot.querySelector('c-cron-expression-editor');
				expect(cronEditor.jobRunnerMode).toBe(true);
				expect(cronEditor.activeCheckIntervalMinutes).toBe(RUNNER_CHECK_INTERVAL_MINUTES);
				expect(element.shadowRoot.querySelector('[data-testid="next-run-preview"]').textContent).toContain('Next run:');
			});

			it('sends the mode, priority and policy on save and defaults to own mode', async() =>
			{
				getJobRunnerState.mockResolvedValue({isActive: false, checkIntervalMinutes: null, canManage: true});
				getParameterDefinitions.mockResolvedValue(null);
				saveRecord.mockResolvedValue('a0X000000000001AAA');
				let element = mountEditor();
				await flushPromises();
				element.shadowRoot.querySelector('[data-testid="scheduler-name"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'A job'}}));
				element.shadowRoot.querySelector('[data-testid="class-name"]').dispatchEvent(new CustomEvent('classchange', {detail: {value: 'SCHED_PurgeRecords'}}));
				element.shadowRoot.querySelector('[data-testid="execution-mode"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'JobRunner'}}));
				await flushPromises();
				element.shadowRoot.querySelector('[data-testid="run-priority"]').dispatchEvent(new CustomEvent('change', {detail: {value: '2'}}));
				element.shadowRoot.querySelector('[data-testid="overlap-policy"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'Allow'}}));
				await flushPromises();

				element.shadowRoot.querySelector('[data-testid="save-button"]').click();
				await flushPromises();

				let request = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(request.executionMode).toBe('JobRunner');
				expect(request.runPriority).toBe(2);
				expect(request.overlapPolicy).toBe('Allow');
				expect(mockRedirectToRecordPage).toHaveBeenCalledWith('a0X000000000001AAA');
			});

			it('defaults a new job to its own scheduled job, with no runner fields and no preview', async() =>
			{
				getJobRunnerState.mockResolvedValue({isActive: true, checkIntervalMinutes: RUNNER_CHECK_INTERVAL_MINUTES, canManage: true});
				let element = mountEditor();
				await flushPromises();

				expect(element.shadowRoot.querySelector('[data-testid="execution-mode"]').value).toBe('OwnScheduledJob');
				expect(element.shadowRoot.querySelector('[data-testid="run-priority"]')).toBeNull();
				expect(element.shadowRoot.querySelector('[data-testid="overlap-policy"]')).toBeNull();
				expect(element.shadowRoot.querySelector('[data-testid="next-run-preview"]')).toBeNull();
				expect(element.shadowRoot.querySelector('[data-testid="job-runner-permission-note"]')).toBeNull();
				expect(element.shadowRoot.querySelector('c-cron-expression-editor').jobRunnerMode).toBe(false);
			});
		});

		it('refuses a class name that cannot be scheduled without a toast', async() =>
		{
			getJobRunnerState.mockResolvedValue({isActive: false, checkIntervalMinutes: null, canManage: true});
			getSchedulableClasses.mockResolvedValue(['SCHED_PurgeRecords']);
			getParameterDefinitions.mockRejectedValue(new Error('Unable to resolve type for class "SCHED_NoSuchClass".'));
			let element = mountEditor();
			await flushPromises();

			element.shadowRoot.querySelector('[data-testid="class-name"]').dispatchEvent(new CustomEvent('classchange', {detail: {value: 'SCHED_NoSuchClass'}}));
			await flushPromises();

			expect(element.shadowRoot.querySelector('[data-testid="class-name"]').errorMessage).not.toBe('');
			expect(mockShowErrorToast).not.toHaveBeenCalled();
		});
	});

	describe('instance behavior', () =>
	{
		describe('wiredRecord', () =>
		{
			it('shows error toast on wire error', () =>
			{
				let context = createMockContext();
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.showErrorToast).toHaveBeenCalledWith('mock error detail');
			});

			it('uses fallback message when reduceErrors returns empty on wire error', () =>
			{
				utilitySystem.reduceErrors.mockReturnValueOnce('');
				let context = createMockContext();
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.showErrorToast).toHaveBeenCalledWith(LOAD_RECORD_FAILED);
			});
		});

		describe('loadParameterDefinitions', () =>
		{
			it('refuses a class name at the field without a toast', async() =>
			{
				getParameterDefinitions.mockRejectedValue(new Error('Not found'));
				let context = createMockContext({parameterDefinitions: [{name: 'old'}]});
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.parameterDefinitions).toBeNull();
				expect(context.classNameError).not.toBe('');
				expect(context.showErrorToast).not.toHaveBeenCalled();
			});
		});

		describe('handleSave', () =>
		{
			const saveEditor = (overrides = {}) => saveFrom(prototype, createMockContext, overrides);

			it('redirects to the saved record', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = await saveEditor();
				expect(context.redirectToRecordPage).toHaveBeenCalledWith('a00000000000001');
			});

			it('invalidates LDS cache before redirecting', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				await saveEditor();
				expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{recordId: 'a00000000000001'}]);
			});

			it('invalidates LDS cache with new record ID in create mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000NEW');
				await saveEditor({recordId: undefined});
				expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{recordId: 'a00000000000NEW'}]);
			});

			it('shows success toast with create message in create mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000NEW');
				let context = await saveEditor({recordId: undefined, schedulerName: 'Test', cronExpression: '0 0 * * * ?'});
				expect(context.showSuccessToast).toHaveBeenCalledWith(CREATED);
				expect(context.redirectToRecordPage).toHaveBeenCalledWith('a00000000000NEW');
			});

			it('shows success toast with edit message in edit mode', async() =>
			{
				saveRecord.mockResolvedValue('a00000000000001');
				let context = await saveEditor();
				expect(context.showSuccessToast).toHaveBeenCalledWith(SAVED);
			});

			it('shows error toast on save failure', async() =>
			{
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = await saveEditor();
				expect(context.showErrorToast).toHaveBeenCalledWith('mock error detail');
				expect(context.redirectToRecordPage).not.toHaveBeenCalled();
			});

			it('shows fallback error when reduceErrors fails', async() =>
			{
				utilitySystem.reduceErrors.mockImplementationOnce(() =>
				{
					throw new Error('reduce failed');
				});
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = await saveEditor();
				expect(context.showErrorToast).toHaveBeenCalledWith(SAVE_FAILED);
			});

			it('shows fallback error when reduceErrors returns empty', async() =>
			{
				utilitySystem.reduceErrors.mockReturnValueOnce('');
				saveRecord.mockRejectedValue(new Error('Save failed'));
				let context = await saveEditor();
				expect(context.showErrorToast).toHaveBeenCalledWith(SAVE_FAILED);
			});

			it('uses recordId as fallback when saveRecord returns null', async() =>
			{
				saveRecord.mockResolvedValue(null);
				let context = await saveEditor();
				expect(context.redirectToRecordPage).toHaveBeenCalledWith('a00000000000001');
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

		describe('job runner mode', () =>
		{
			const createRunnerContext = (overrides = {}) =>
			{
				return createMockContext({
					executionMode: 'OwnScheduledJob',
					runPriority: '',
					overlapPolicy: 'Skip',
					jobRunnerState: {isActive: false, checkIntervalMinutes: null, canManage: false},
					nextRunPreview: '',
					nextRunPreviewRequest: 0, ...overrides
				});
			};

			it('keeps the runner option available to a user who may manage the runner', () =>
			{
				let context = createRunnerContext({jobRunnerState: {isActive: true, checkIntervalMinutes: RUNNER_CHECK_INTERVAL_MINUTES, canManage: true}});
				Object.defineProperty(context, 'isJobRunnerMode', {get: () => false});
				expect(getGetter('isExecutionModeDisabled').call(context)).toBe(false);
				expect(getGetter('showPermissionNote').call(context)).toBe(false);
			});

			it('leaves a job already on the runner editable even without the permission', () =>
			{
				let context = createRunnerContext({executionMode: 'JobRunner'});
				Object.defineProperty(context, 'isJobRunnerMode', {get: () => true});
				expect(getGetter('isExecutionModeDisabled').call(context)).toBe(false);
				expect(getGetter('showPermissionNote').call(context)).toBe(true);
			});

			it('reads the mode from the record and defaults each runner field when the record leaves it blank', () =>
			{
				getFieldValue.mockReturnValue(null);
				let context = createRunnerContext({executionMode: 'JobRunner', runPriority: '7', overlapPolicy: 'Allow'});
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.executionMode).toBe('OwnScheduledJob');
				expect(context.runPriority).toBe('');
				expect(context.overlapPolicy).toBe('Skip');
				expect(context.refreshNextRunPreview).toHaveBeenCalled();
			});

			it('reads the saved mode, priority and policy from the record', () =>
			{
				const savedRunPriority = 4;
				const savedRunnerFields = {
					'ScheduledJob__c.ExecutionMode__c': 'JobRunner', 'ScheduledJob__c.RunPriority__c': savedRunPriority, 'ScheduledJob__c.OverlapPolicy__c': 'Allow'
				};
				getFieldValue.mockImplementation((record, field) => savedRunnerFields[field] ?? null);
				let context = createRunnerContext();
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.executionMode).toBe('JobRunner');
				expect(context.runPriority).toBe(savedRunPriority);
				expect(context.overlapPolicy).toBe('Allow');
				getFieldValue.mockReset();
			});

			it('says what waiting means when no runner is active', () =>
			{
				let context = createRunnerContext();
				expect(getGetter('jobRunnerNote').call(context)).toBe('Activate the job runner in Health Check first; this job will wait until then.');
				expect(getGetter('activeCheckIntervalMinutes').call(context)).toBeNull();
			});

			it('names how often an active runner checks', () =>
			{
				let context = createRunnerContext({jobRunnerState: {isActive: true, checkIntervalMinutes: SLOWER_RUNNER_CHECK_INTERVAL_MINUTES, canManage: true}});
				expect(getGetter('jobRunnerNote').call(context)).toContain('every 30 minutes');
				expect(getGetter('activeCheckIntervalMinutes').call(context)).toBe(SLOWER_RUNNER_CHECK_INTERVAL_MINUTES);
			});

			it('offers both overlap policies and says the preview is unavailable until there is one', () =>
			{
				let context = createRunnerContext();
				expect(getGetter('overlapPolicyOptions').call(context).map((option) => option.value)).toEqual([
					'Skip',
					'Allow'
				]);
				expect(getGetter('nextRunPreviewLabel').call(context)).toBe('Next run: not available until the expression is valid');
			});

			it('shows the previewed instant once the controller answers', () =>
			{
				let context = createRunnerContext({nextRunPreview: '2026-09-11T14:15:00.000Z'});
				expect(getGetter('nextRunPreviewLabel').call(context)).toContain('Next run: ');
				expect(getGetter('nextRunPreviewLabel').call(context)).not.toBe('Next run: not available until the expression is valid');
			});

			it('falls back to no runner and no permission when the state cannot be read', async() =>
			{
				getJobRunnerState.mockRejectedValueOnce(new Error('no access'));
				let context = createRunnerContext({jobRunnerState: {isActive: true, checkIntervalMinutes: RUNNER_CHECK_INTERVAL_MINUTES, canManage: true}});
				await prototype.loadJobRunnerState.call(context);
				expect(context.jobRunnerState).toEqual({isActive: false, checkIntervalMinutes: null, canManage: false});
			});

			it('keeps the state it has when the controller answers with nothing', async() =>
			{
				getJobRunnerState.mockResolvedValueOnce(null);
				let context = createRunnerContext({jobRunnerState: {isActive: true, checkIntervalMinutes: RUNNER_CHECK_INTERVAL_MINUTES, canManage: true}});
				await prototype.loadJobRunnerState.call(context);
				expect(context.jobRunnerState).toEqual({isActive: true, checkIntervalMinutes: RUNNER_CHECK_INTERVAL_MINUTES, canManage: true});
			});

			it('previews the next run again once the user time zone has arrived', async() =>
			{
				// The time zone and the record arrive independently, so the first preview can be computed
				// before the zone is known; the zone's arrival has to ask for it again.
				getUserTimezone.mockResolvedValueOnce('America/New_York');
				let context = createRunnerContext();

				await prototype.loadUserTimezone.call(context);

				expect(context.userTimezone).toBe('America/New_York');
				expect(context.refreshNextRunPreview).toHaveBeenCalled();
			});

			it('previews the next run only for a valid expression on the runner', async() =>
			{
				previewNextRun.mockResolvedValueOnce('2026-09-11T14:15:00.000Z');
				let context = createRunnerContext({cronExpression: '0 */15 * * * ?', cronIsValid: true, userTimezone: 'UTC'});
				Object.defineProperty(context, 'isJobRunnerMode', {get: () => true});
				await prototype.refreshNextRunPreview.call(context);
				expect(previewNextRun).toHaveBeenCalledWith({cronExpression: '0 */15 * * * ?', timezone: 'UTC'});
				expect(context.nextRunPreview).toBe('2026-09-11T14:15:00.000Z');
			});

			it('clears the preview in own mode, for an invalid expression and when the controller fails', async() =>
			{
				let ownMode = createRunnerContext({cronExpression: '0 0 2 * * ?', nextRunPreview: 'stale'});
				Object.defineProperty(ownMode, 'isJobRunnerMode', {get: () => false});
				await prototype.refreshNextRunPreview.call(ownMode);
				expect(ownMode.nextRunPreview).toBe('');

				let invalid = createRunnerContext({cronExpression: 'nonsense', cronIsValid: false, nextRunPreview: 'stale'});
				Object.defineProperty(invalid, 'isJobRunnerMode', {get: () => true});
				await prototype.refreshNextRunPreview.call(invalid);
				expect(invalid.nextRunPreview).toBe('');

				previewNextRun.mockRejectedValueOnce(new Error('unreadable'));
				let failing = createRunnerContext({cronExpression: '0 */15 * * * ?', cronIsValid: true, nextRunPreview: 'stale'});
				Object.defineProperty(failing, 'isJobRunnerMode', {get: () => true});
				await prototype.refreshNextRunPreview.call(failing);
				expect(failing.nextRunPreview).toBe('');
			});

			it('keeps the answer for the latest expression when an earlier answer arrives last', async() =>
			{
				const EARLIER_NEXT_RUN = '2026-09-11T14:15:00.000Z';
				const LATER_NEXT_RUN = '2026-09-11T15:00:00.000Z';
				let answerEarlierRequest;
				previewNextRun.mockReturnValueOnce(new Promise((resolve) =>
				{
					answerEarlierRequest = resolve;
				}));
				previewNextRun.mockResolvedValueOnce(LATER_NEXT_RUN);
				let context = createRunnerContext({cronExpression: '0 */15 * * * ?', cronIsValid: true, userTimezone: 'UTC'});
				Object.defineProperty(context, 'isJobRunnerMode', {get: () => true});

				let earlierRefresh = prototype.refreshNextRunPreview.call(context);
				context.cronExpression = '0 0 * * * ?';
				await prototype.refreshNextRunPreview.call(context);
				answerEarlierRequest(EARLIER_NEXT_RUN);
				await earlierRefresh;

				expect(context.nextRunPreview).toBe(LATER_NEXT_RUN);
			});

			it('drops an answer that arrives after the expression became one with no preview', async() =>
			{
				let answerEarlierRequest;
				previewNextRun.mockReturnValueOnce(new Promise((resolve) =>
				{
					answerEarlierRequest = resolve;
				}));
				let context = createRunnerContext({cronExpression: '0 */15 * * * ?', cronIsValid: true, userTimezone: 'UTC'});
				Object.defineProperty(context, 'isJobRunnerMode', {get: () => true});

				let earlierRefresh = prototype.refreshNextRunPreview.call(context);
				context.cronIsValid = false;
				await prototype.refreshNextRunPreview.call(context);
				answerEarlierRequest('2026-09-11T14:15:00.000Z');
				await earlierRefresh;

				expect(context.nextRunPreview).toBe('');
			});

			it('blanks the preview when the controller answers with nothing', async() =>
			{
				previewNextRun.mockResolvedValueOnce(null);
				let context = createRunnerContext({cronExpression: '0 */15 * * * ?', cronIsValid: true, nextRunPreview: 'stale'});
				Object.defineProperty(context, 'isJobRunnerMode', {get: () => true});
				await prototype.refreshNextRunPreview.call(context);
				expect(context.nextRunPreview).toBe('');
			});

			it('refreshes the preview when the mode or the expression changes', () =>
			{
				let context = createRunnerContext();
				prototype.handleExecutionModeChange.call(context, {detail: {value: 'JobRunner'}});
				expect(context.executionMode).toBe('JobRunner');
				expect(context.refreshNextRunPreview).toHaveBeenCalled();

				let cronContext = createRunnerContext();
				prototype.handleCronChange.call(cronContext, {detail: {value: '0 */15 * * * ?', isValid: true}});
				expect(cronContext.refreshNextRunPreview).toHaveBeenCalled();
			});

			it('keeps the priority and the policy the user picks', () =>
			{
				let context = createRunnerContext();
				prototype.handleRunPriorityChange.call(context, {detail: {value: '2'}});
				prototype.handleOverlapPolicyChange.call(context, {detail: {value: 'Allow'}});
				expect(context.runPriority).toBe('2');
				expect(context.overlapPolicy).toBe('Allow');
			});

			it('sends a blank priority as nothing at all', async() =>
			{
				saveRecord.mockResolvedValue('a0X000000000001AAA');
				let context = createRunnerContext({schedulerName: 'A job', className: 'SCHED_PurgeRecords', cronExpression: '0 0 2 * * ?'});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'isCreateMode', {get: () => true});
				await prototype.handleSave.call(context);
				let request = JSON.parse(saveRecord.mock.calls[0][0].requestJson);
				expect(request.runPriority).toBeNull();
				expect(request.executionMode).toBe('OwnScheduledJob');
				expect(request.overlapPolicy).toBe('Skip');
			});
		});
	});

	describe('template structure', () =>
	{
		it('renders the form in a lightning-card with Save and Cancel in its footer', () =>
		{
			let template = readBundleTemplate('scheduledJobEditor');
			expect(template).toContain('lightning-card');
			expect(template).toContain('slot="footer"');
		});
	});
});
