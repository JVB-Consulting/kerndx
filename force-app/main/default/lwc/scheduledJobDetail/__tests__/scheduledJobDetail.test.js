// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for scheduledJobDetail LWC component.
 *
 * @author Jason van Beukering
 * @date March 2026, September 2026
 */
import {createElement} from 'lwc';
import LOADING_LABEL from '@salesforce/label/c.ScheduledJobDetail_Loading';
import LOAD_FAILED_LABEL from '@salesforce/label/c.ScheduledJobDetail_LoadFailed';
import LOAD_PARAMETERS_FAILED from '@salesforce/label/c.ScheduledJob_LoadParameterDefinitionsFailed';
import ACTIVE_STATUS from '@salesforce/label/c.ScheduledJob_Active';
import INACTIVE_STATUS from '@salesforce/label/c.ScheduledJob_Inactive';

jest.mock('lightning/uiRecordApi', () => ({
	getRecord: jest.fn(), getFieldValue: jest.fn(), getFieldDisplayValue: jest.fn(), notifyRecordUpdateAvailable: jest.fn().mockResolvedValue()
}), {virtual: true});

jest.mock('@salesforce/schema/ScheduledJob__c.SchedulerName__c', () => ({default: 'ScheduledJob__c.SchedulerName__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.ClassName__c', () => ({default: 'ScheduledJob__c.ClassName__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.CronExpression__c', () => ({default: 'ScheduledJob__c.CronExpression__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.IsActive__c', () => ({default: 'ScheduledJob__c.IsActive__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Description__c', () => ({default: 'ScheduledJob__c.Description__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Parameters__c', () => ({default: 'ScheduledJob__c.Parameters__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Timezone__c', () => ({default: 'ScheduledJob__c.Timezone__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.ExecutionMode__c', () => ({default: 'ScheduledJob__c.ExecutionMode__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.NextRunAt__c', () => ({default: 'ScheduledJob__c.NextRunAt__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.LastRunAt__c', () => ({default: 'ScheduledJob__c.LastRunAt__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.LastRunOutcome__c', () => ({default: 'ScheduledJob__c.LastRunOutcome__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.LastRunReason__c', () => ({default: 'ScheduledJob__c.LastRunReason__c'}), {virtual: true});

jest.mock('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ScheduledJob.getJobRunnerState', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ScheduledJob.runNow', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ScheduledJob.findLastRunLogEntryId', () => ({default: jest.fn()}), {virtual: true});

// The job runner labels resolve to their shipped values, so every assertion below reads the
// sentence a subscriber sees rather than the default 'c.X' stub.
jest.mock('@salesforce/label/c.ScheduledJob_ExecutionModeOwn', () => ({default: 'Its own scheduled job'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_ExecutionModeJobRunner', () => ({default: 'Job runner'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_RunNow', () => ({default: 'Run now'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_RunNowStarted', () => ({default: 'The job was started. Its outcome appears on this record when the run finishes.'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_SkippedPreviousRunStillRunning', () => ({default: 'Skipped: the previous run was still running when this run was due.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_SkippedRecordNoLongerOnRunner', () => ({default: 'Skipped: when the run started the job was inactive or no longer on the job runner.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_ParkedClassNotFound', () => ({default: 'The job was parked because its class could not be loaded: {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_ParkedExpressionCannotBePlaced',
		() => ({default: 'The job was parked because its next run time could not be worked out. The log entry for this record has the detail.'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJob_ExpressionCannotFireWithinHorizon',
		() => ({default: 'This expression never fires within the next four years, so the job runner cannot schedule it.'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJobDetail_NoRunYet', () => ({default: 'Not run yet'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJobDetail_ViewLog', () => ({default: 'View log'}), {virtual: true});
jest.mock('@salesforce/label/c.ScheduledJobDetail_LogEntryNotFound', () => ({default: 'The log entry for this run is no longer available.'}), {virtual: true});

jest.mock('c/cronExpressionEditor', () => ({
	describeCronExpression: jest.fn().mockReturnValue('Every day at noon')
}), {virtual: true});

jest.mock('c/utilitySystem', () => ({
	reduceErrors: jest.fn().mockReturnValue('mock error detail')
}), {virtual: true});

describe('c-scheduled-job-detail', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const ScheduledJobDetail = require('c/scheduledJobDetail').default;
			expect(ScheduledJobDetail).toBeDefined();
			expect(typeof ScheduledJobDetail).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const ScheduledJobDetail = require('c/scheduledJobDetail').default;
		const prototype = ScheduledJobDetail.prototype;

		it('has @api recordId property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'recordId');
			expect(descriptor).toBeDefined();
		});

		it('has hasRecord getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'hasRecord');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has viewSchedulerName getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'viewSchedulerName');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has viewClassName getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'viewClassName');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has viewCronExpression getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'viewCronExpression');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has viewCronDescription getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'viewCronDescription');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has hasParameterDefinitions getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'hasParameterDefinitions');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has viewTimezone getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'viewTimezone');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has viewTimezoneLabel getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'viewTimezoneLabel');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has wire method for getRecord', () =>
		{
			expect(prototype.wiredRecord).toBeDefined();
		});

		it('has loadParameterDefinitions method', () =>
		{
			expect(typeof prototype.loadParameterDefinitions).toBe('function');
		});
	});

	describe('instance behavior', () =>
	{
		const ScheduledJobDetail = require('c/scheduledJobDetail').default;
		const prototype = ScheduledJobDetail.prototype;
		const {getFieldValue, getFieldDisplayValue} = require('lightning/uiRecordApi');

		const getGetter = (name) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, name).get;
		};

		const createMockContext = (overrides = {}) =>
		{
			return {
				recordId: 'a00000000000001',
				record: null,
				parameterDefinitions: null,
				loadErrorMessage: '',
				_lastLoadedClassName: undefined,
				showSuccessToast: jest.fn(),
				showErrorToast: jest.fn(),
				consoleError: jest.fn(),
				dispatchEvent: jest.fn(),
				callControllerMethod: jest.fn().mockResolvedValue(null),
				redirectToRecordPage: jest.fn(),
				loadParameterDefinitions: jest.fn(),
				loadJobRunnerState: jest.fn().mockResolvedValue(),
				jobRunnerState: {isActive: false, checkIntervalMinutes: null, canManage: false}, ...overrides
			};
		};

		describe('wiredRecord', () =>
		{
			it('populates record from wire data', () =>
			{
				getFieldValue.mockReturnValue('SCHED_PurgeRecords');
				let context = createMockContext();
				let mockRecord = {fields: {}};
				prototype.wiredRecord.call(context, {data: mockRecord});
				expect(context.record).toBe(mockRecord);
			});

			it('loads parameter definitions when class name is present', () =>
			{
				getFieldValue.mockReturnValue('SCHED_PurgeRecords');
				let context = createMockContext();
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.loadParameterDefinitions).toHaveBeenCalledWith('SCHED_PurgeRecords');
			});

			it('does not reload definitions when class name unchanged', () =>
			{
				getFieldValue.mockReturnValue('SCHED_PurgeRecords');
				let context = createMockContext({_lastLoadedClassName: 'SCHED_PurgeRecords'});
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.loadParameterDefinitions).not.toHaveBeenCalled();
			});

			it('clears record on wire error', () =>
			{
				let context = createMockContext({record: {fields: {}}});
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.record).toBeUndefined();
			});

			it('surfaces the load failure instead of blanking silently on wire error', () =>
			{
				let context = createMockContext({record: {fields: {}}});
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.loadErrorMessage).toBe('mock error detail');
			});

			it('uses the fallback label when reduceErrors returns empty on wire error', () =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockReturnValueOnce('');
				let context = createMockContext();
				prototype.wiredRecord.call(context, {error: {message: 'Error'}});
				expect(context.loadErrorMessage).toBe(LOAD_FAILED_LABEL);
			});

			it('clears the load error when record data arrives', () =>
			{
				getFieldValue.mockReturnValue(null);
				let context = createMockContext({loadErrorMessage: 'stale error'});
				prototype.wiredRecord.call(context, {data: {fields: {}}});
				expect(context.loadErrorMessage).toBe('');
			});
		});

		describe('loading and error state getters', () =>
		{
			it('isLoadingRecord returns true before the wire emits anything', () =>
			{
				let context = createMockContext({record: null, loadErrorMessage: ''});
				let getter = getGetter('isLoadingRecord');
				expect(getter.call(context)).toBe(true);
			});

			it('isLoadingRecord returns false once the record has loaded', () =>
			{
				let context = createMockContext({record: {fields: {}}, loadErrorMessage: ''});
				let getter = getGetter('isLoadingRecord');
				expect(getter.call(context)).toBe(false);
			});

			it('isLoadingRecord returns false once the wire has errored', () =>
			{
				let context = createMockContext({record: undefined, loadErrorMessage: 'mock error detail'});
				let getter = getGetter('isLoadingRecord');
				expect(getter.call(context)).toBe(false);
			});

			it('hasLoadError returns false when there is no load error', () =>
			{
				let context = createMockContext({loadErrorMessage: ''});
				let getter = getGetter('hasLoadError');
				expect(getter.call(context)).toBe(false);
			});

			it('hasLoadError returns true when the wire has errored', () =>
			{
				let context = createMockContext({loadErrorMessage: 'mock error detail'});
				let getter = getGetter('hasLoadError');
				expect(getter.call(context)).toBe(true);
			});
		});

		describe('view getters', () =>
		{
			it('returns empty string for viewSchedulerName when no record', () =>
			{
				let context = createMockContext({record: null});
				let getter = getGetter('viewSchedulerName');
				expect(getter.call(context)).toBe('');
			});

			it('returns field value for viewSchedulerName when record exists', () =>
			{
				getFieldValue.mockReturnValue('My Job');
				let context = createMockContext({record: {fields: {}}});
				let getter = getGetter('viewSchedulerName');
				expect(getter.call(context)).toBe('My Job');
			});

			it('returns empty string for viewClassName when no record', () =>
			{
				let context = createMockContext({record: null});
				let getter = getGetter('viewClassName');
				expect(getter.call(context)).toBe('');
			});

			it('returns field value for viewClassName when record exists', () =>
			{
				getFieldValue.mockReturnValue('SCHED_PurgeRecords');
				let context = createMockContext({record: {fields: {}}});
				let getter = getGetter('viewClassName');
				expect(getter.call(context)).toBe('SCHED_PurgeRecords');
			});

			it('returns empty string for viewCronExpression when no record', () =>
			{
				let context = createMockContext({record: null});
				let getter = getGetter('viewCronExpression');
				expect(getter.call(context)).toBe('');
			});

			it('returns field value for viewCronExpression when record exists', () =>
			{
				getFieldValue.mockReturnValue('0 0 12 * * ?');
				let context = createMockContext({record: {fields: {}}});
				let getter = getGetter('viewCronExpression');
				expect(getter.call(context)).toBe('0 0 12 * * ?');
			});

			it('returns empty string for viewTimezone when no record', () =>
			{
				let context = createMockContext({record: null});
				let getter = getGetter('viewTimezone');
				expect(getter.call(context)).toBe('');
			});

			it('returns field value for viewTimezone when record exists', () =>
			{
				getFieldValue.mockReturnValue('Africa/Johannesburg');
				let context = createMockContext({record: {fields: {}}});
				let getter = getGetter('viewTimezone');
				expect(getter.call(context)).toBe('Africa/Johannesburg');
			});

			it('returns display name for viewTimezoneLabel when timezone is set', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewTimezone', {get: () => 'America/New_York'});
				let getter = getGetter('viewTimezoneLabel');
				let result = getter.call(context);
				expect(result).toBeTruthy();
				expect(result).not.toBe('');
			});

			it('returns empty string for viewTimezoneLabel when timezone is empty', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewTimezone', {get: () => ''});
				let getter = getGetter('viewTimezoneLabel');
				expect(getter.call(context)).toBe('');
			});

			it('returns fallback for viewTimezoneLabel when timezone is invalid', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewTimezone', {get: () => 'Invalid/Timezone'});
				let getter = getGetter('viewTimezoneLabel');
				expect(getter.call(context)).toBe('Invalid/Timezone');
			});

			it('returns cron description with timezone when timezone is present', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewCronExpression', {get: () => '0 0 12 * * ?'});
				Object.defineProperty(context, 'viewTimezoneLabel', {get: () => 'South Africa Standard Time'});
				let getter = getGetter('viewCronDescription');
				expect(getter.call(context)).toBe('Every day at noon (South Africa Standard Time)');
			});

			it('returns plain cron description when no timezone', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewCronExpression', {get: () => '0 0 12 * * ?'});
				Object.defineProperty(context, 'viewTimezoneLabel', {get: () => ''});
				let getter = getGetter('viewCronDescription');
				expect(getter.call(context)).toBe('Every day at noon');
			});

			it('returns false for viewIsActive when no record', () =>
			{
				let context = createMockContext({record: null});
				let getter = getGetter('viewIsActive');
				expect(getter.call(context)).toBe(false);
			});

			it('returns field value for viewIsActive when record exists', () =>
			{
				getFieldValue.mockReturnValue(true);
				let context = createMockContext({record: {fields: {}}});
				let getter = getGetter('viewIsActive');
				expect(getter.call(context)).toBe(true);
			});

			it('returns empty string for viewDescription when no record', () =>
			{
				let context = createMockContext({record: null});
				let getter = getGetter('viewDescription');
				expect(getter.call(context)).toBe('');
			});

			it('returns field value for viewDescription when record exists', () =>
			{
				getFieldValue.mockReturnValue('Some description');
				let context = createMockContext({record: {fields: {}}});
				let getter = getGetter('viewDescription');
				expect(getter.call(context)).toBe('Some description');
			});

			it('returns empty string for viewParameters when no record', () =>
			{
				let context = createMockContext({record: null});
				let getter = getGetter('viewParameters');
				expect(getter.call(context)).toBe('');
			});

			it('returns field value for viewParameters when record exists', () =>
			{
				getFieldValue.mockReturnValue('{"nameValueMap":{"objectName":"Account"}}');
				let context = createMockContext({record: {fields: {}}});
				let getter = getGetter('viewParameters');
				expect(getter.call(context)).toBe('{"nameValueMap":{"objectName":"Account"}}');
			});

			it('returns Active label when isActive is true', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewIsActive', {get: () => true});
				let getter = getGetter('activeStatusLabel');
				expect(getter.call(context)).toBe(ACTIVE_STATUS);
			});

			it('returns Inactive label when isActive is false', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewIsActive', {get: () => false});
				let getter = getGetter('activeStatusLabel');
				expect(getter.call(context)).toBe(INACTIVE_STATUS);
			});

			it('returns success variant when active', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewIsActive', {get: () => true});
				let getter = getGetter('activeStatusVariant');
				expect(getter.call(context)).toBe('slds-badge badge-success');
			});

			it('returns default variant when inactive', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewIsActive', {get: () => false});
				let getter = getGetter('activeStatusVariant');
				expect(getter.call(context)).toBe('slds-badge');
			});

			it('returns false for hasRecord when record is null', () =>
			{
				let context = createMockContext({record: null});
				let getter = getGetter('hasRecord');
				expect(getter.call(context)).toBe(false);
			});

			it('returns true for hasRecord when record exists', () =>
			{
				let context = createMockContext({record: {fields: {}}});
				let getter = getGetter('hasRecord');
				expect(getter.call(context)).toBe(true);
			});

			it('returns true for hasViewDescription when description exists', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewDescription', {get: () => 'Some description'});
				let getter = getGetter('hasViewDescription');
				expect(getter.call(context)).toBe(true);
			});

			it('returns false for hasViewDescription when empty', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewDescription', {get: () => ''});
				let getter = getGetter('hasViewDescription');
				expect(getter.call(context)).toBe(false);
			});
		});

		describe('hasParameterDefinitions getter', () =>
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

		describe('viewParameterPairs getter', () =>
		{
			it('returns empty array when no definitions', () =>
			{
				let context = createMockContext({parameterDefinitions: null});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => false});
				Object.defineProperty(context, 'viewParameters', {get: () => '{"nameValueMap":{"objectName":"Account"}}'});
				let getter = getGetter('viewParameterPairs');
				expect(getter.call(context)).toEqual([]);
			});

			it('returns empty array when no attributes', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}]
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'viewParameters', {get: () => ''});
				let getter = getGetter('viewParameterPairs');
				expect(getter.call(context)).toEqual([]);
			});

			it('returns parameter pairs from attributes', () =>
			{
				let context = createMockContext({
					parameterDefinitions: [
						{name: 'objectName', label: 'Object Name', dataType: 'TEXT', defaultValue: ''},
						{name: 'batchSize', label: 'Batch Size', dataType: 'NUMERIC', defaultValue: '2000'}
					]
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'viewParameters', {get: () => '{"nameValueMap":{"objectName":"Account"}}'});
				let getter = getGetter('viewParameterPairs');
				let result = getter.call(context);
				expect(result).toHaveLength(2);
				expect(result[0].label).toBe('Object Name');
				expect(result[0].value).toBe('Account');
				expect(result[1].label).toBe('Batch Size');
				expect(result[1].value).toBe('2000');
			});

			it('falls back to empty string when the attribute and defaultValue are both missing', () =>
			{
				// Exercises the third operand of `attributeMap[name] || defaultValue || ''`.
				// Parameter definition has no defaultValue and the parsed attributes do not
				// include the parameter name, so the empty-string fallback fires.
				let context = createMockContext({
					parameterDefinitions: [
						{name: 'missingParam', label: 'Missing', dataType: 'TEXT'}
					]
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'viewParameters', {get: () => '{"nameValueMap":{"other":"value"}}'});
				let getter = getGetter('viewParameterPairs');
				let result = getter.call(context);
				expect(result).toHaveLength(1);
				expect(result[0].name).toBe('missingParam');
				expect(result[0].value).toBe('');
			});

			it('returns empty-value pairs when parsed JSON has no nameValueMap', () =>
			{
				// Exercises `parsed.nameValueMap || {}` — the parsed object has no
				// nameValueMap property so the fallback empty map is used, which in
				// turn yields empty `attributeMap[name]` lookups for every definition.
				let context = createMockContext({
					parameterDefinitions: [
						{name: 'objectName', label: 'Object Name', dataType: 'TEXT', defaultValue: 'Account'}
					]
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'viewParameters', {get: () => '{"other":"value"}'});
				let getter = getGetter('viewParameterPairs');
				let result = getter.call(context);
				expect(result).toHaveLength(1);
				// attributeMap[name] is undefined (no nameValueMap), so defaultValue wins.
				expect(result[0].value).toBe('Account');
			});

			it('returns empty-value pairs when the raw parameter JSON is malformed', () =>
			{
				// Exercises the catch block of parseAttributes — invalid JSON is
				// swallowed and treated as an empty map, so definitions with no
				// defaultValue fall through to the empty-string fallback.
				let context = createMockContext({
					parameterDefinitions: [
						{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}
					]
				});
				Object.defineProperty(context, 'hasParameterDefinitions', {get: () => true});
				Object.defineProperty(context, 'viewParameters', {get: () => '{not valid json'});
				let getter = getGetter('viewParameterPairs');
				let result = getter.call(context);
				expect(result).toHaveLength(1);
				expect(result[0].value).toBe('');
			});
		});

		describe('hasViewParameterPairs getter', () =>
		{
			it('returns true when parameter pairs exist', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewParameterPairs', {get: () => [{name: 'key', label: 'Key', value: 'val'}]});
				let getter = getGetter('hasViewParameterPairs');
				expect(getter.call(context)).toBe(true);
			});

			it('returns false when no parameter pairs', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewParameterPairs', {get: () => []});
				let getter = getGetter('hasViewParameterPairs');
				expect(getter.call(context)).toBe(false);
			});
		});

		describe('loadParameterDefinitions', () =>
		{
			it('sets parameter definitions from controller', async() =>
			{
				let mockDefinitions = [{name: 'objectName', label: 'Object Name', dataType: 'TEXT'}];
				let context = createMockContext();
				context.callControllerMethod = jest.fn().mockResolvedValue(mockDefinitions);
				await prototype.loadParameterDefinitions.call(context, 'SCHED_PurgeRecords');
				expect(context.parameterDefinitions).toEqual(mockDefinitions);
			});

			it('sets null and shows error toast when controller call fails', async() =>
			{
				let context = createMockContext({parameterDefinitions: [{name: 'old'}]});
				context.callControllerMethod = jest.fn().mockRejectedValue(new Error('Not found'));
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.parameterDefinitions).toBeNull();
				expect(context.showErrorToast).toHaveBeenCalledWith('mock error detail');
			});

			it('uses fallback message when reduceErrors returns empty', async() =>
			{
				const {reduceErrors} = require('c/utilitySystem');
				reduceErrors.mockReturnValueOnce('');
				let context = createMockContext({parameterDefinitions: [{name: 'old'}]});
				context.callControllerMethod = jest.fn().mockRejectedValue(new Error('Not found'));
				await prototype.loadParameterDefinitions.call(context, 'BadClassName');
				expect(context.showErrorToast).toHaveBeenCalledWith(LOAD_PARAMETERS_FAILED);
			});
		});

		describe('job runner fields', () =>
		{
			const runNow = require('@salesforce/apex/CTRL_ScheduledJob.runNow').default;
			const findLastRunLogEntryId = require('@salesforce/apex/CTRL_ScheduledJob.findLastRunLogEntryId').default;
			const getJobRunnerState = require('@salesforce/apex/CTRL_ScheduledJob.getJobRunnerState').default;
			const RUN_NOW_STARTED = 'The job was started. Its outcome appears on this record when the run finishes.';

			/**
			 * Builds the wired-record shape the component reads, keyed the way the schema mocks name
			 * each field, and points getFieldValue at it.
			 */
			const recordOf = (fieldValues, displayValues = {}) =>
			{
				let record = {fields: {}};

				for(let fieldName of Object.keys(fieldValues))
				{
					let value = fieldValues[fieldName];
					let displayValue = Object.prototype.hasOwnProperty.call(displayValues, fieldName) ? displayValues[fieldName] : value;
					record.fields['ScheduledJob__c.' + fieldName] = {value, displayValue};
				}

				getFieldValue.mockImplementation((wiredRecord, fieldName) => (wiredRecord.fields[fieldName] ? wiredRecord.fields[fieldName].value : null));
				getFieldDisplayValue.mockImplementation((wiredRecord, fieldName) => (wiredRecord.fields[fieldName] ? wiredRecord.fields[fieldName].displayValue : null));
				return record;
			};

			const runnerContext = (fieldValues, overrides = {}, displayValues = {}) =>
			{
				return createMockContext({record: recordOf(fieldValues, displayValues), ...overrides});
			};

			afterEach(() =>
			{
				getFieldValue.mockReset();
				getFieldDisplayValue.mockReset();
			});

			it('names where the job runs', () =>
			{
				let onRunner = runnerContext({ExecutionMode__c: 'JobRunner'});
				expect(getGetter('isJobRunnerRecord').call(onRunner)).toBe(true);
				expect(getGetter('viewExecutionMode').call(onRunner)).toBe('Job runner');

				let ownMode = runnerContext({ExecutionMode__c: 'OwnScheduledJob'});
				expect(getGetter('isJobRunnerRecord').call(ownMode)).toBe(false);
				expect(getGetter('viewExecutionMode').call(ownMode)).toBe('Its own scheduled job');

				expect(getGetter('isJobRunnerRecord').call(createMockContext({record: null}))).toBe(false);
			});

			it('shows the next run, the last run and the outcome of a record that has run', () =>
			{
				let context = runnerContext({
					ExecutionMode__c: 'JobRunner', NextRunAt__c: '2026-09-11T14:15:00.000Z', LastRunAt__c: '2026-09-11T14:00:00.000Z', LastRunOutcome__c: 'Failed'
				});

				expect(getGetter('viewNextRun').call(context)).not.toBe('');
				expect(getGetter('viewLastRun').call(context)).not.toBe('Not run yet');
				expect(getGetter('viewLastRunOutcome').call(context)).toBe('Failed');
			});

			it('reads the never-run words before the first run', () =>
			{
				let context = runnerContext({ExecutionMode__c: 'JobRunner'});

				expect(getGetter('viewNextRun').call(context)).toBe('');
				expect(getGetter('viewLastRun').call(context)).toBe('Not run yet');
				expect(getGetter('viewLastRunOutcome').call(context)).toBe('Not run yet');
			});

			it('shows the outcome in the reader own language, falling back to the stored value', () =>
			{
				let translated = runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: 'Succeeded'}, {}, {LastRunOutcome__c: 'Reussi'});
				expect(getGetter('viewLastRunOutcome').call(translated)).toBe('Reussi');

				let withoutDisplayValue = runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: 'Succeeded'}, {}, {LastRunOutcome__c: null});
				expect(getGetter('viewLastRunOutcome').call(withoutDisplayValue)).toBe('Succeeded');
			});

			it.each([
				[
					'Succeeded',
					'slds-badge badge-success'
				],
				[
					'Failed',
					'slds-badge slds-theme_error'
				],
				[
					'Parked',
					'slds-badge slds-theme_warning'
				],
				[
					'Skipped',
					'slds-badge'
				],
				[
					null,
					'slds-badge'
				]
			])('badges the %s outcome', (outcome, expectedClass) =>
			{
				let context = runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: outcome});
				expect(getGetter('outcomeBadgeClass').call(context)).toBe(expectedClass);
			});

			it.each([
				[
					'PreviousRunStillRunning',
					'Skipped: the previous run was still running when this run was due.'
				],
				[
					'RecordNoLongerOnRunner',
					'Skipped: when the run started the job was inactive or no longer on the job runner.'
				],
				[
					'ExpressionCannotBePlaced',
					'The job was parked because its next run time could not be worked out. The log entry for this record has the detail.'
				],
				[
					'ExpressionCannotFireWithinHorizon',
					'This expression never fires within the next four years, so the job runner cannot schedule it.'
				]
			])('explains the %s reason in its own sentence', (reason, expectedSentence) =>
			{
				let context = runnerContext({ExecutionMode__c: 'JobRunner', LastRunReason__c: reason});
				expect(getGetter('viewLastRunReason').call(context)).toBe(expectedSentence);
				expect(getGetter('hasLastRunReason').call(context)).toBe(true);
			});

			it('names the class a parked job could not load', () =>
			{
				let context = runnerContext({ExecutionMode__c: 'JobRunner', LastRunReason__c: 'ClassNotFound', ClassName__c: 'SCHED_PurgeRecords'});
				expect(getGetter('viewLastRunReason').call(context)).toBe('The job was parked because its class could not be loaded: SCHED_PurgeRecords');
			});

			it('shows a reason it does not recognise rather than an empty row, and no row at all without a reason', () =>
			{
				let laterRelease = runnerContext({ExecutionMode__c: 'JobRunner', LastRunReason__c: 'SomethingNewer'});
				expect(getGetter('viewLastRunReason').call(laterRelease)).toBe('SomethingNewer');

				let noReason = runnerContext({ExecutionMode__c: 'JobRunner'});
				expect(getGetter('viewLastRunReason').call(noReason)).toBe('');
				expect(getGetter('hasLastRunReason').call(noReason)).toBe(false);
			});

			it('offers Run now only for an active runner job to a user who may manage the runner', () =>
			{
				let managing = {isActive: true, checkIntervalMinutes: 15, canManage: true};
				expect(getGetter('showRunNow').call(runnerContext({ExecutionMode__c: 'JobRunner', IsActive__c: true}, {jobRunnerState: managing}))).toBe(true);
				expect(getGetter('showRunNow').call(runnerContext({ExecutionMode__c: 'JobRunner', IsActive__c: false}, {jobRunnerState: managing}))).toBe(false);
				expect(getGetter('showRunNow').call(runnerContext({ExecutionMode__c: 'OwnScheduledJob', IsActive__c: true}, {jobRunnerState: managing}))).toBe(false);
				expect(getGetter('showRunNow').call(runnerContext({ExecutionMode__c: 'JobRunner', IsActive__c: true}))).toBe(false);
			});

			it('offers the way to the log entry for a failed and a parked run only', () =>
			{
				expect(getGetter('showLastRunLog').call(runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: 'Failed'}))).toBe(true);
				expect(getGetter('showLastRunLog').call(runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: 'Parked'}))).toBe(true);
				expect(getGetter('showLastRunLog').call(runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: 'Succeeded'}))).toBe(false);
				expect(getGetter('showLastRunLog').call(runnerContext({ExecutionMode__c: 'JobRunner'}))).toBe(false);
			});

			it('starts the job and says so, then asks the page for the new values', async() =>
			{
				const {notifyRecordUpdateAvailable} = require('lightning/uiRecordApi');
				let context = runnerContext({ExecutionMode__c: 'JobRunner', IsActive__c: true});
				context.callControllerMethod = jest.fn().mockResolvedValue('7071234567890ABCDE');

				await prototype.handleRunNow.call(context);

				expect(context.callControllerMethod).toHaveBeenCalledWith(runNow, {recordId: context.recordId});
				expect(context.showSuccessToast).toHaveBeenCalledWith(RUN_NOW_STARTED);
				expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{recordId: context.recordId}]);
			});

			it('says nothing started when the run was refused', async() =>
			{
				let context = runnerContext({ExecutionMode__c: 'JobRunner', IsActive__c: true});
				context.callControllerMethod = jest.fn().mockResolvedValue(null);

				await prototype.handleRunNow.call(context);

				expect(context.showSuccessToast).not.toHaveBeenCalled();
			});

			it('opens the log entry of the last run', async() =>
			{
				let context = runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: 'Failed'});
				context.callControllerMethod = jest.fn().mockResolvedValue('a0L000000000001AAA');

				await prototype.handleViewLastRunLog.call(context);

				expect(context.callControllerMethod).toHaveBeenCalledWith(findLastRunLogEntryId, {recordId: context.recordId});
				expect(context.redirectToRecordPage).toHaveBeenCalledWith('a0L000000000001AAA');
			});

			it('says so when the log entry of the last run is gone', async() =>
			{
				let context = runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: 'Failed'});
				context.callControllerMethod = jest.fn().mockResolvedValue(null);

				await prototype.handleViewLastRunLog.call(context);

				expect(context.redirectToRecordPage).not.toHaveBeenCalled();
				expect(context.showErrorToast).toHaveBeenCalledWith('The log entry for this run is no longer available.');
			});

			it('leaves a failed lookup to the failure the controller call already reported', async() =>
			{
				// A failed call is surfaced by the component builder and resolves as undefined; only the
				// controller's own answer of nothing at all means there is no entry to open.
				let context = runnerContext({ExecutionMode__c: 'JobRunner', LastRunOutcome__c: 'Failed'});
				context.callControllerMethod = jest.fn().mockResolvedValue(undefined);

				await prototype.handleViewLastRunLog.call(context);

				expect(context.redirectToRecordPage).not.toHaveBeenCalled();
				expect(context.showErrorToast).not.toHaveBeenCalled();
			});

			it('tells the schedule description that the job is on the runner and how often the runner checks', () =>
			{
				const {describeCronExpression} = require('c/cronExpressionEditor');
				let context = runnerContext({ExecutionMode__c: 'JobRunner', CronExpression__c: '0 */5 * * * ?'}, {
					jobRunnerState: {isActive: true, checkIntervalMinutes: 15, canManage: true}
				});
				Object.defineProperty(context, 'viewCronExpression', {get: () => '0 */5 * * * ?'});
				Object.defineProperty(context, 'viewTimezoneLabel', {get: () => ''});

				getGetter('viewCronDescription').call(context);

				expect(describeCronExpression).toHaveBeenCalledWith('0 */5 * * * ?', {jobRunnerMode: true, activeCheckIntervalMinutes: 15});
			});

			it('leaves the check interval out of the description while no runner is active', () =>
			{
				const {describeCronExpression} = require('c/cronExpressionEditor');
				let context = runnerContext({ExecutionMode__c: 'JobRunner', CronExpression__c: '0 */5 * * * ?'});
				Object.defineProperty(context, 'viewCronExpression', {get: () => '0 */5 * * * ?'});
				Object.defineProperty(context, 'viewTimezoneLabel', {get: () => ''});

				getGetter('viewCronDescription').call(context);

				expect(describeCronExpression).toHaveBeenCalledWith('0 */5 * * * ?', {jobRunnerMode: true, activeCheckIntervalMinutes: null});
			});

			it('reads the runner state when the component connects, and falls back when it cannot', async() =>
			{
				let connecting = createMockContext();
				prototype.connectedCallback.call(connecting);
				expect(connecting.loadJobRunnerState).toHaveBeenCalled();

				getJobRunnerState.mockResolvedValueOnce({isActive: true, checkIntervalMinutes: 15, canManage: true});
				let reading = createMockContext();
				await prototype.loadJobRunnerState.call(reading);
				expect(reading.jobRunnerState).toEqual({isActive: true, checkIntervalMinutes: 15, canManage: true});

				getJobRunnerState.mockRejectedValueOnce(new Error('no access'));
				let failing = createMockContext({jobRunnerState: {isActive: true, checkIntervalMinutes: 15, canManage: true}});
				await prototype.loadJobRunnerState.call(failing);
				expect(failing.jobRunnerState).toEqual({isActive: false, checkIntervalMinutes: null, canManage: false});

				getJobRunnerState.mockResolvedValueOnce(null);
				let empty = createMockContext({jobRunnerState: {isActive: true, checkIntervalMinutes: 15, canManage: true}});
				await prototype.loadJobRunnerState.call(empty);
				expect(empty.jobRunnerState).toEqual({isActive: true, checkIntervalMinutes: 15, canManage: true});
			});
		});
	});

	describe('DOM rendering', () =>
	{
		async function createEditorElement()
		{
			const ScheduledJobDetail = require('c/scheduledJobDetail').default;
			let element = createElement('c-scheduled-job-editor', {is: ScheduledJobDetail});
			element.recordId = 'a00000000000001';
			document.body.appendChild(element);
			await Promise.resolve();
			return element;
		}

		it('renders the card with a loading spinner before the record wire emits', async() =>
		{
			// Documents the intended behaviour change for the Release-A backward-compat gate:
			// the component previously rendered nothing at all until the wire emitted, leaving
			// a blank region on slow loads and on wire errors. It now always renders its card
			// shell with an explicit loading state until data or an error arrives.
			let element = await createEditorElement();
			let card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
			let spinner = element.shadowRoot.querySelector('lightning-spinner');
			expect(spinner).not.toBeNull();
			expect(spinner.alternativeText).toBe(LOADING_LABEL);
		});

		it('does not render the record body or the error region while loading', async() =>
		{
			let element = await createEditorElement();
			expect(element.shadowRoot.querySelector('[data-testid="schedule-heading"]')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="load-error"]')).toBeNull();
		});

		it('does not contain edit form elements in template', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobDetail.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).not.toContain('lightning-combobox');
			expect(template).not.toContain('c-cron-expression-editor');
			expect(template).not.toContain('lightning-textarea');
			expect(template).not.toContain('handleSave');
		});

		it('contains view-only elements in template', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobDetail.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('viewSchedulerName');
			expect(template).toContain('viewClassName');
			expect(template).toContain('activeStatusLabel');
		});

		it('contains loading and error states in template', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobDetail.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('lightning-spinner');
			expect(template).toContain('isLoadingRecord');
			expect(template).toContain('lwc:elseif={hasLoadError}');
			expect(template).toContain('data-testid="load-error"');
			expect(template).toContain('{loadErrorMessage}');
			expect(template).toContain('role="alert"');
		});

		it('does not contain edit button or handleEdit reference', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobDetail.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).not.toContain('handleEdit');
			expect(template).not.toContain('lightning-button-icon');
		});

		it('declares size before any device-specific size on every lightning-layout-item', () =>
		{
			// The template assigns properties in attribute order, and lightning-layout-item's
			// device-size setters throw at render time when size has not been assigned yet —
			// so a device-size attribute written before size crashes the whole record page.
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobDetail.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			const layoutItemTags = template.match(/<lightning-layout-item[^>]*>/g) ?? [];
			expect(layoutItemTags.length).toBeGreaterThan(0);
			for(const tag of layoutItemTags)
			{
				const deviceSizePosition = tag.search(/[a-z]+-device-size=/);
				if(deviceSizePosition >= 0)
				{
					const sizePosition = tag.search(/\ssize=/);
					expect(sizePosition).toBeGreaterThanOrEqual(0);
					expect(sizePosition).toBeLessThan(deviceSizePosition);
				}
			}
		});

		it('renders the runner rows, the Run now action and the way to the log, each behind its own condition', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobDetail.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).toContain('data-testid="detail-execution-mode"');
			expect(template).toContain('lwc:if={isJobRunnerRecord}');
			expect(template).toContain('data-testid="detail-next-run"');
			expect(template).toContain('data-testid="detail-last-run"');
			expect(template).toContain('data-testid="detail-last-run-outcome"');
			expect(template).toContain('lwc:if={hasLastRunReason}');
			expect(template).toContain('data-testid="detail-last-run-reason"');
			expect(template).toContain('lwc:if={showRunNow}');
			expect(template).toContain('data-testid="run-now-button"');
			expect(template).toContain('slot="actions"');
			expect(template).toContain('lwc:if={showLastRunLog}');
			expect(template).toContain('data-testid="detail-last-run-log"');
		});

		it('carries no trace of the free-text message the record no longer holds', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobDetail.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).not.toContain('LastRunMessage');
			expect(template).not.toContain('detail-last-run-message');
		});
	});

	/*
	 * The @lwc/jest-transformer rewrites `import getParameterDefinitions from
	 * '@salesforce/apex/...'` into a try/catch. When the module-level jest.mock
	 * factory succeeds (the default path), the catch is never entered and the
	 * generated `global.__lwcJestMock_getParameterDefinitions || function...`
	 * binary expression has both branches uncovered. These two tests force the
	 * catch to run — once with the global pre-populated (LHS truthy) and once
	 * empty (RHS wins) — so both branches fire exactly once.
	 */
	describe('apex-stub fallback (jest-transformer catch block)', () =>
	{
		const stubAllImports = () =>
		{
			jest.doMock('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions', () =>
			{
				throw new Error('forced require failure');
			}, {virtual: true});
			jest.doMock('lightning/uiRecordApi', () => ({
				getRecord: jest.fn(), getFieldValue: jest.fn(), getFieldDisplayValue: jest.fn(), notifyRecordUpdateAvailable: jest.fn().mockResolvedValue()
			}), {virtual: true});
			jest.doMock('@salesforce/apex/CTRL_ScheduledJob.getJobRunnerState', () => ({default: jest.fn()}), {virtual: true});
			jest.doMock('@salesforce/apex/CTRL_ScheduledJob.runNow', () => ({default: jest.fn()}), {virtual: true});
			jest.doMock('@salesforce/apex/CTRL_ScheduledJob.findLastRunLogEntryId', () => ({default: jest.fn()}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.ExecutionMode__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.NextRunAt__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.LastRunAt__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.LastRunOutcome__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.LastRunReason__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.SchedulerName__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.ClassName__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.CronExpression__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.IsActive__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.Description__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.Parameters__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('@salesforce/schema/ScheduledJob__c.Timezone__c', () => ({default: 'x'}), {virtual: true});
			jest.doMock('c/cronExpressionEditor', () => ({describeCronExpression: jest.fn()}), {virtual: true});
			jest.doMock('c/utilitySystem', () => ({reduceErrors: jest.fn()}), {virtual: true});
		};

		afterEach(() =>
		{
			jest.resetModules();
			delete global.__lwcJestMock_getParameterDefinitions;
		});

		it('uses the pre-set global.__lwcJestMock_getParameterDefinitions when present', () =>
		{
			const fallback = jest.fn().mockResolvedValue([]);
			global.__lwcJestMock_getParameterDefinitions = fallback;

			let loaded;
			jest.isolateModules(() =>
			{
				stubAllImports();
				loaded = require('c/scheduledJobDetail').default;
			});

			expect(loaded).toBeDefined();
			expect(typeof loaded).toBe('function');
			expect(global.__lwcJestMock_getParameterDefinitions).toBe(fallback);
		});

		it('generates the stub function when the global is empty', () =>
		{
			delete global.__lwcJestMock_getParameterDefinitions;

			let loaded;
			jest.isolateModules(() =>
			{
				stubAllImports();
				loaded = require('c/scheduledJobDetail').default;
			});

			expect(loaded).toBeDefined();
			expect(typeof global.__lwcJestMock_getParameterDefinitions).toBe('function');
		});
	});
});
