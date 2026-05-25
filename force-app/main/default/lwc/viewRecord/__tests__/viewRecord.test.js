// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for viewRecord LWC component.
 *
 *              The transformer-generated apex-import catch blocks are covered by
 *              pre-setting `global.__lwcJestMock_<name>` and loading the component
 *              inside `jest.isolateModules`, with one paired test that deletes the
 *              global slot so the fallback-stub function expression is evaluated.
 *
 * @author Jason van Beukering
 * @date December 2025, February 2026, April 2026
 */

/*
 * NB: no inline jest.mock('@salesforce/apex/...') — the @lwc/jest-transformer
 * rewrites those imports into a try/catch that reads from `global.__lwcJestMock_<name>`.
 * Pre-setting the global and isolating the module load lets us exercise both
 * sides of the generated `global.X || function X() {...}` expression.
 */

describe('c-view-record', () =>
{
	let getFieldSetByDeveloperName;
	let getDefaultActiveSectionsField;
	let getFieldSetApiNamesField;
	let getFieldSetsForRecord;
	let getObjectNameFromId;

	const APEX_GLOBAL_KEYS = [
		'__lwcJestMock_getFieldSetByDeveloperName',
		'__lwcJestMock_getDefaultActiveSectionsField',
		'__lwcJestMock_getFieldSetApiNamesField',
		'__lwcJestMock_getFieldSetsForRecord',
		'__lwcJestMock_getObjectNameFromId'
	];

	beforeAll(() =>
	{
		getFieldSetByDeveloperName = jest.fn();
		getDefaultActiveSectionsField = jest.fn();
		getFieldSetApiNamesField = jest.fn();
		getFieldSetsForRecord = jest.fn();
		getObjectNameFromId = jest.fn();
		global.__lwcJestMock_getFieldSetByDeveloperName = getFieldSetByDeveloperName;
		global.__lwcJestMock_getDefaultActiveSectionsField = getDefaultActiveSectionsField;
		global.__lwcJestMock_getFieldSetApiNamesField = getFieldSetApiNamesField;
		global.__lwcJestMock_getFieldSetsForRecord = getFieldSetsForRecord;
		global.__lwcJestMock_getObjectNameFromId = getObjectNameFromId;
	});

	afterAll(() =>
	{
		APEX_GLOBAL_KEYS.forEach((key) => delete global[key]);
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
	});

	/**
	 * @description Loads the component in an isolated module registry so the
	 *              transformer's apex try/catch block runs fresh each time.
	 * @returns {Function} The LwcViewRecord class.
	 */
	function loadComponent()
	{
		let component;
		jest.isolateModules(() =>
		{
			component = require('c/viewRecord').default;
		});
		return component;
	}

	describe('module exports', () =>
	{
		it('exports LwcViewRecord as default', () =>
		{
			const LwcViewRecord = loadComponent();
			expect(LwcViewRecord).toBeDefined();
			expect(typeof LwcViewRecord).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		it('has @api properties', () =>
		{
			const LwcViewRecord = loadComponent();
			const prototype = LwcViewRecord.prototype;

			const recordIdDesc = Object.getOwnPropertyDescriptor(prototype, 'recordId');
			expect(recordIdDesc).toBeDefined();

			const fieldSetDevNameDesc = Object.getOwnPropertyDescriptor(prototype, 'fieldSetDeveloperName');
			expect(fieldSetDevNameDesc).toBeDefined();
		});

		it('has computed getters', () =>
		{
			const LwcViewRecord = loadComponent();
			const prototype = LwcViewRecord.prototype;

			const getterNames = [
				'displaySections',
				'fieldSetsAndActiveSections',
				'displayActiveSections',
				'fetchFieldSetParameters'
			];

			getterNames.forEach((getterName) =>
			{
				const descriptor = Object.getOwnPropertyDescriptor(prototype, getterName);
				expect(descriptor).toBeDefined();
				expect(typeof descriptor.get).toBe('function');
			});
		});

		it('has @wire methods', () =>
		{
			const LwcViewRecord = loadComponent();
			const prototype = LwcViewRecord.prototype;

			expect(prototype.fetchFieldSetGroup).toBeDefined();
			expect(prototype.fetchFieldSets).toBeDefined();
			expect(prototype.fetchObjectApiName).toBeDefined();
			expect(prototype.fetchFieldApiNamesField).toBeDefined();
			expect(prototype.fetchActiveSectionsField).toBeDefined();
		});
	});

	describe('class instantiation', () =>
	{
		it('can be instantiated via createElement', async() =>
		{
			const {createElement} = require('lwc');
			const LwcViewRecord = require('c/viewRecord').default;

			const element = createElement('c-view-record', {is: LwcViewRecord});
			element.recordId = '001000000000001';
			element.fieldSetDeveloperName = 'TestFieldSet';
			document.body.appendChild(element);

			await new Promise((resolve) => setTimeout(resolve, 0));

			expect(element.recordId).toBe('001000000000001');
			expect(element.fieldSetDeveloperName).toBe('TestFieldSet');
		});

		it('exercises the transformer fallback stubs when global slots are empty', () =>
		{
			APEX_GLOBAL_KEYS.forEach((key) => delete global[key]);

			let LwcViewRecordFresh;
			jest.isolateModules(() =>
			{
				LwcViewRecordFresh = require('c/viewRecord').default;
			});

			global.__lwcJestMock_getFieldSetByDeveloperName = getFieldSetByDeveloperName;
			global.__lwcJestMock_getDefaultActiveSectionsField = getDefaultActiveSectionsField;
			global.__lwcJestMock_getFieldSetApiNamesField = getFieldSetApiNamesField;
			global.__lwcJestMock_getFieldSetsForRecord = getFieldSetsForRecord;
			global.__lwcJestMock_getObjectNameFromId = getObjectNameFromId;

			expect(typeof LwcViewRecordFresh).toBe('function');
			expect(typeof LwcViewRecordFresh.prototype.fetchFieldSetGroup).toBe('function');
		});
	});

	describe('instance behavior', () =>
	{
		let prototype;

		beforeAll(() =>
		{
			prototype = loadComponent().prototype;
		});

		function createMockContext()
		{
			return {
				recordId: '001000000000001',
				fieldSetDeveloperName: 'TestFieldSet',
				objectApiName: '',
				fieldSets: null,
				fieldSetGroup: null,
				fieldApiNamesField: null,
				activeSectionsField: null,
				isLoading: false,
				handleWireResponse: jest.fn((result) => result.data)
			};
		}

		describe('getters', () =>
		{
			it('displaySections returns empty array when fieldSets is null', () =>
			{
				const context = createMockContext();
				context.fieldSets = null;
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'displaySections');
				expect(descriptor.get.call(context)).toEqual([]);
			});

			it('displaySections returns empty array when recordId not in fieldSets', () =>
			{
				const context = createMockContext();
				context.fieldSets = {otherRecordId: {}};
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'displaySections');
				expect(descriptor.get.call(context)).toEqual([]);
			});

			it('displaySections returns sections when fieldSets has data', () =>
			{
				const context = createMockContext();
				context.fieldSets = {
					'001000000000001': {
						'TestFieldSet': [{fieldSetName: 'Test Field Set', fieldAPIName: 'Name', fieldLabel: 'Name'}]
					}
				};
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'displaySections');
				const result = descriptor.get.call(context);
				expect(result).toHaveLength(1);
				expect(result[0].key).toBe('TestFieldSet');
				expect(result[0].label).toBe('Test Field Set');
				expect(result[0].value).toEqual([{fieldSetName: 'Test Field Set', fieldAPIName: 'Name', fieldLabel: 'Name'}]);
			});

			it('displaySections applies default empty array when fieldSetArray is undefined', () =>
			{
				const context = createMockContext();
				context.fieldSets = {
					'001000000000001': {
						UndefinedFieldSet: undefined
					}
				};
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'displaySections');
				const result = descriptor.get.call(context);
				expect(result).toHaveLength(1);
				expect(result[0].key).toBe('UndefinedFieldSet');
				expect(result[0].label).toBe('');
				expect(result[0].value).toEqual([]);
			});

			it('displaySections returns empty label when fieldSetArray is empty', () =>
			{
				const context = createMockContext();
				context.fieldSets = {
					'001000000000001': {
						'EmptyFieldSet': []
					}
				};
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'displaySections');
				const result = descriptor.get.call(context);
				expect(result).toHaveLength(1);
				expect(result[0].label).toBe('');
			});

			it('fieldSetsAndActiveSections returns empty arrays when fieldSetGroup is null', () =>
			{
				const context = createMockContext();
				context.fieldSetGroup = null;
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'fieldSetsAndActiveSections');
				expect(descriptor.get.call(context)).toEqual({fieldSetApiNames: [], activeSections: []});
			});

			it('fieldSetsAndActiveSections returns parsed values when fieldSetGroup exists', () =>
			{
				const context = createMockContext();
				context.fieldSetGroup = {
					FieldSetApiNames__c: 'FieldSet1,FieldSet2', DefaultActiveSections__c: 'FieldSet1'
				};
				context.fieldApiNamesField = {fieldApiName: 'FieldSetApiNames__c'};
				context.activeSectionsField = {fieldApiName: 'DefaultActiveSections__c'};
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'fieldSetsAndActiveSections');
				const result = descriptor.get.call(context);
				expect(result.fieldSetApiNames).toEqual([
					'FieldSet1',
					'FieldSet2'
				]);
				expect(result.activeSections).toEqual(['FieldSet1']);
			});

			it('fieldSetsAndActiveSections returns empty arrays when fields are null', () =>
			{
				const context = createMockContext();
				context.fieldSetGroup = {SomeField: 'value'};
				context.fieldApiNamesField = null;
				context.activeSectionsField = null;
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'fieldSetsAndActiveSections');
				expect(descriptor.get.call(context)).toEqual({fieldSetApiNames: [], activeSections: []});
			});

			it('displayActiveSections returns activeSections from fieldSetsAndActiveSections', () =>
			{
				const context = createMockContext();
				Object.defineProperty(context, 'fieldSetsAndActiveSections', {
					get: () => ({
						fieldSetApiNames: ['FS1'], activeSections: [
							'Section1',
							'Section2'
						]
					})
				});
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'displayActiveSections');
				expect(descriptor.get.call(context)).toEqual([
					'Section1',
					'Section2'
				]);
			});

			it('fetchFieldSetParameters returns empty object when recordId is null', () =>
			{
				const context = createMockContext();
				context.recordId = null;
				Object.defineProperty(context, 'fieldSetsAndActiveSections', {
					get: () => ({fieldSetApiNames: ['FS1'], activeSections: []})
				});
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'fetchFieldSetParameters');
				expect(descriptor.get.call(context)).toEqual({});
				expect(context.isLoading).toBe(false);
			});

			it('fetchFieldSetParameters returns parameters when recordId exists', () =>
			{
				const context = createMockContext();
				context.recordId = '001000000000001';
				Object.defineProperty(context, 'fieldSetsAndActiveSections', {
					get: () => ({
						fieldSetApiNames: [
							'FS1',
							'FS2'
						], activeSections: []
					})
				});
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'fetchFieldSetParameters');
				const result = descriptor.get.call(context);
				expect(result['001000000000001']).toEqual([
					'FS1',
					'FS2'
				]);
				expect(context.isLoading).toBe(true);
			});
		});

		describe('wire callbacks', () =>
		{
			it('fetchFieldSetGroup sets fieldSetGroup from response', () =>
			{
				const context = createMockContext();
				const mockData = {Name: 'TestGroup', FieldSetApiNames__c: 'FS1,FS2'};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchFieldSetGroup.call(context, {data: mockData});
				expect(context.fieldSetGroup).toBe(mockData);
			});

			it('fetchFieldSets sets fieldSets and stops loading', () =>
			{
				const context = createMockContext();
				context.isLoading = true;
				const mockData = {'001000000000001': {TestFieldSet: []}};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchFieldSets.call(context, {data: mockData});
				expect(context.fieldSets).toBe(mockData);
				expect(context.isLoading).toBe(false);
			});

			it('fetchObjectApiName sets objectApiName from response', () =>
			{
				const context = createMockContext();
				context.handleWireResponse = jest.fn(() => 'Account');
				prototype.fetchObjectApiName.call(context, {data: 'Account'});
				expect(context.objectApiName).toBe('Account');
			});

			it('fetchObjectApiName sets empty string when response is null', () =>
			{
				const context = createMockContext();
				context.handleWireResponse = jest.fn(() => null);
				prototype.fetchObjectApiName.call(context, {data: null});
				expect(context.objectApiName).toBe('');
			});

			it('fetchFieldApiNamesField sets fieldApiNamesField from response', () =>
			{
				const context = createMockContext();
				const mockData = {fieldApiName: 'FieldSetApiNames__c'};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchFieldApiNamesField.call(context, {data: mockData});
				expect(context.fieldApiNamesField).toBe(mockData);
			});

			it('fetchFieldApiNamesField sets empty string when response is null', () =>
			{
				const context = createMockContext();
				context.handleWireResponse = jest.fn(() => null);
				prototype.fetchFieldApiNamesField.call(context, {data: null});
				expect(context.fieldApiNamesField).toBe('');
			});

			it('fetchActiveSectionsField sets activeSectionsField from response', () =>
			{
				const context = createMockContext();
				const mockData = {fieldApiName: 'DefaultActiveSections__c'};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchActiveSectionsField.call(context, {data: mockData});
				expect(context.activeSectionsField).toBe(mockData);
			});

			it('fetchActiveSectionsField sets empty string when response is null', () =>
			{
				const context = createMockContext();
				context.handleWireResponse = jest.fn(() => null);
				prototype.fetchActiveSectionsField.call(context, {data: null});
				expect(context.activeSectionsField).toBe('');
			});
		});
	});
});
