// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for scheduledJobDetail LWC component.
 *
 * @author Jason van Beukering
 * @date March 2026, May 2026
 */
import {createElement} from 'lwc';

jest.mock('lightning/uiRecordApi', () => ({
	getRecord: jest.fn(), getFieldValue: jest.fn()
}), {virtual: true});

jest.mock('@salesforce/schema/ScheduledJob__c.SchedulerName__c', () => ({default: 'ScheduledJob__c.SchedulerName__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.ClassName__c', () => ({default: 'ScheduledJob__c.ClassName__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.CronExpression__c', () => ({default: 'ScheduledJob__c.CronExpression__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.IsActive__c', () => ({default: 'ScheduledJob__c.IsActive__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Description__c', () => ({default: 'ScheduledJob__c.Description__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Parameters__c', () => ({default: 'ScheduledJob__c.Parameters__c'}), {virtual: true});
jest.mock('@salesforce/schema/ScheduledJob__c.Timezone__c', () => ({default: 'ScheduledJob__c.Timezone__c'}), {virtual: true});

jest.mock('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions', () => ({default: jest.fn()}), {virtual: true});

jest.mock('c/cronExpressionEditor', () => ({
	describeCronExpression: jest.fn().mockReturnValue('Every day at noon')
}), {virtual: true});

jest.mock('c/utilitySystem', () => ({
	reduceErrors: jest.fn().mockReturnValue('mock error detail')
}), {virtual: true});

describe('c-scheduled-job-editor', () =>
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
		const {getFieldValue} = require('lightning/uiRecordApi');

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
				_lastLoadedClassName: undefined,
				showSuccessToast: jest.fn(),
				showErrorToast: jest.fn(),
				consoleError: jest.fn(),
				dispatchEvent: jest.fn(),
				callControllerMethod: jest.fn().mockResolvedValue(null),
				redirectToRecordPage: jest.fn(),
				loadParameterDefinitions: jest.fn(), ...overrides
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
				expect(getter.call(context)).toBe('Active');
			});

			it('returns Inactive label when isActive is false', () =>
			{
				let context = createMockContext();
				Object.defineProperty(context, 'viewIsActive', {get: () => false});
				let getter = getGetter('activeStatusLabel');
				expect(getter.call(context)).toBe('Inactive');
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
				expect(context.showErrorToast).toHaveBeenCalledWith('Failed to load parameter definitions');
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

		it('does not render lightning-card before record is loaded', async() =>
		{
			let element = await createEditorElement();
			let card = element.shadowRoot.querySelector('lightning-card');
			expect(card).toBeNull();
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

		it('does not contain edit button or handleEdit reference', () =>
		{
			const fs = require('fs');
			const path = require('path');
			let templatePath = path.resolve(__dirname, '..', 'scheduledJobDetail.html');
			let template = fs.readFileSync(templatePath, 'utf8');
			expect(template).not.toContain('handleEdit');
			expect(template).not.toContain('lightning-button-icon');
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
				getRecord: jest.fn(), getFieldValue: jest.fn()
			}), {virtual: true});
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
