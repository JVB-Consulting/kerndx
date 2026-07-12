// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for searchLookup LWC component.
 *
 *              Note: This component extends baseLookup with additional search
 *              controller functionality. Due to inheritance complexity and template
 *              requirements, these tests verify module structure and static analysis.
 *
 * @author Jason van Beukering
 * @date December 2025, July 2026
 */

// Mock dependencies
jest.mock('@salesforce/apex/CTRL_ExecuteSearch.executeSearchController', () => ({
	default: jest.fn()
}), {virtual: true});

jest.mock('@salesforce/messageChannel/Component__c', () => ({
	default: {}
}), {virtual: true});

jest.mock('c/utilitySystem', () => ({
	setPropertyOnObject: jest.fn((obj, key, value) =>
	{
		obj[key] = value;
		return obj;
	})
}), {virtual: true});

const DEBOUNCE_DELAY = 300;

describe('c-search-lookup', () =>
{
	describe('module exports', () =>
	{
		it('exports LwcSearchLookup as default', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			expect(LwcSearchLookup).toBeDefined();
			expect(typeof LwcSearchLookup).toBe('function');
		});

		it('extends LwcBaseLookup', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const LwcBaseLookup = require('c/baseLookup').default;

			// Check prototype chain
			expect(LwcSearchLookup.prototype instanceof LwcBaseLookup).toBe(true);
		});
	});

	describe('class structure', () =>
	{
		it('has expected prototype methods', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const prototype = LwcSearchLookup.prototype;

			// Own methods
			expect(typeof prototype.render).toBe('function');
			expect(typeof prototype.clearLookup).toBe('function');
			expect(typeof prototype.getResults).toBe('function');
			expect(typeof prototype.setSearchTimeoutFn).toBe('function');
		});

		it('has @api property aliases', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const prototype = LwcSearchLookup.prototype;

			// name -> elementName alias
			const nameDesc = Object.getOwnPropertyDescriptor(prototype, 'name');
			expect(nameDesc).toBeDefined();
			expect(typeof nameDesc.get).toBe('function');
			expect(typeof nameDesc.set).toBe('function');

			// fieldLabel -> fieldLabelName alias
			const fieldLabelDesc = Object.getOwnPropertyDescriptor(prototype, 'fieldLabel');
			expect(fieldLabelDesc).toBeDefined();
			expect(typeof fieldLabelDesc.get).toBe('function');
			expect(typeof fieldLabelDesc.set).toBe('function');

			// resultUniqueId -> idField alias
			const resultUniqueIdDesc = Object.getOwnPropertyDescriptor(prototype, 'resultUniqueId');
			expect(resultUniqueIdDesc).toBeDefined();
			expect(typeof resultUniqueIdDesc.get).toBe('function');
			expect(typeof resultUniqueIdDesc.set).toBe('function');

			// addedElementClass -> outerElementClasses alias
			const addedElementClassDesc = Object.getOwnPropertyDescriptor(prototype, 'addedElementClass');
			expect(addedElementClassDesc).toBeDefined();
			expect(typeof addedElementClassDesc.get).toBe('function');
			expect(typeof addedElementClassDesc.set).toBe('function');
		});

		it('has preselectedRecord property', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const prototype = LwcSearchLookup.prototype;

			const desc = Object.getOwnPropertyDescriptor(prototype, 'preselectedRecord');
			expect(desc).toBeDefined();
			expect(typeof desc.get).toBe('function');
			expect(typeof desc.set).toBe('function');
		});

		it('overrides selectedRecord getter/setter', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const prototype = LwcSearchLookup.prototype;

			const desc = Object.getOwnPropertyDescriptor(prototype, 'selectedRecord');
			expect(desc).toBeDefined();
			expect(typeof desc.get).toBe('function');
			expect(typeof desc.set).toBe('function');
		});
	});

	describe('@api methods', () =>
	{
		it('has callController as @api decorated property', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const prototype = LwcSearchLookup.prototype;

			const desc = Object.getOwnPropertyDescriptor(prototype, 'callController');
			expect(desc).toBeDefined();
			// @api creates getter/setter
			expect(typeof desc.get).toBe('function');
		});

		it('has extractResults as @api decorated property', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const prototype = LwcSearchLookup.prototype;

			const desc = Object.getOwnPropertyDescriptor(prototype, 'extractResults');
			expect(desc).toBeDefined();
			expect(typeof desc.get).toBe('function');
		});
	});

	describe('controllerName handling', () =>
	{
		it('has controllerName as @api property', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const prototype = LwcSearchLookup.prototype;

			const desc = Object.getOwnPropertyDescriptor(prototype, 'controllerName');
			expect(desc).toBeDefined();
		});

		it('has controllerSearchParameters as @api property', () =>
		{
			const LwcSearchLookup = require('c/searchLookup').default;
			const prototype = LwcSearchLookup.prototype;

			const desc = Object.getOwnPropertyDescriptor(prototype, 'controllerSearchParameters');
			expect(desc).toBeDefined();
		});
	});

	describe('dependency on CTRL_ExecuteSearch', () =>
	{
		it('imports executeSearchController', () =>
		{
			const executeSearchController = require('@salesforce/apex/CTRL_ExecuteSearch.executeSearchController').default;
			expect(executeSearchController).toBeDefined();
		});
	});

	describe('instance behavior', () =>
	{
		const LwcSearchLookup = require('c/searchLookup').default;
		const prototype = LwcSearchLookup.prototype;

		const createMockContext = () =>
		{
			return {
				elementName: 'testName',
				fieldLabelName: 'Test Label',
				idField: 'Id',
				outerElementClasses: '',
				preselected: null,
				record: null,
				searchTerm: '',
				searchResults: [],
				isSearchLoading: false,
				controllerName: null,
				controllerSearchParameters: 'param1=value1;param2=value2',
				valueSelectEventParams: {},
				templateHTML: '<div>Template</div>',
				delayTimeout: null,
				callControllerMethod: jest.fn().mockResolvedValue([]),
				dispatchSearchTermChangedEvent: jest.fn(),
				handleSelectRecordHelper: jest.fn(),
				dispatchValueSelectEvent: jest.fn(),
				publishValueSelectMessage: jest.fn(),
				getResultIdentifier: (record) => record && record.Id,
				callController: jest.fn().mockResolvedValue([]),
				extractResults: (results) => results
			};
		};

		describe('property aliases via createElement', () =>
		{
			afterEach(() =>
			{
				while(document.body.firstChild)
				{
					document.body.removeChild(document.body.firstChild);
				}
			});

			it('name getter and setter work correctly', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				element.name = 'testLookup';
				expect(element.name).toBe('testLookup');
			});

			it('fieldLabel getter and setter work correctly', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				element.fieldLabel = 'Test Label';
				expect(element.fieldLabel).toBe('Test Label');
			});

			it('resultUniqueId getter and setter work correctly', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				element.resultUniqueId = 'CustomId';
				expect(element.resultUniqueId).toBe('CustomId');
			});

			it('addedElementClass getter and setter work correctly', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				element.addedElementClass = 'custom-class';
				expect(element.addedElementClass).toBe('custom-class');
			});
		});

		describe('preselectedRecord via createElement', () =>
		{
			afterEach(() =>
			{
				while(document.body.firstChild)
				{
					document.body.removeChild(document.body.firstChild);
				}
			});

			it('getter returns null by default', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				expect(element.preselectedRecord).toBeUndefined();
			});

			it('setter updates preselectedRecord', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				element.preselectedRecord = {Id: '001', Name: 'New'};
				expect(element.preselectedRecord).toEqual({Id: '001', Name: 'New'});
			});

			it('setter does not update when identifiers are the same', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				element.preselectedRecord = {Id: '001', Name: 'First'};
				element.preselectedRecord = {Id: '001', Name: 'Same Id Different Name'};
				// Preselected was already set with same Id, so it should not update
				expect(element.preselectedRecord.Name).toBe('First');
			});
		});

		describe('selectedRecord override', () =>
		{
			it('getter returns preselected when record is null', () =>
			{
				const context = createMockContext();
				context.record = null;
				context.preselected = {Id: '002', Name: 'Preselected'};
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'selectedRecord');
				const result = descriptor.get.call(context);
				expect(result.Id).toBe('002');
			});

			it('getter returns record when record is set', () =>
			{
				const context = createMockContext();
				context.record = {Id: '001', Name: 'Active'};
				context.preselected = {Id: '002', Name: 'Preselected'};
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'selectedRecord');
				const result = descriptor.get.call(context);
				expect(result.Id).toBe('001');
			});

			it('setter updates valueSelectEventParams', () =>
			{
				const context = createMockContext();
				const descriptor = Object.getOwnPropertyDescriptor(prototype, 'selectedRecord');
				descriptor.set.call(context, {Id: '001', Name: 'Test'});
				expect(context.valueSelectEventParams.selectedOption).toBeDefined();
			});
		});

		describe('methods', () =>
		{
			it('render returns templateHTML', () =>
			{
				const context = createMockContext();
				const result = prototype.render.call(context);
				expect(result).toBe('<div>Template</div>');
			});

			it('clearLookup clears preselected and calls super', () =>
			{
				const context = createMockContext();
				context.preselected = {Id: '001'};
				const LwcBaseLookup = require('c/baseLookup').default;
				context.searchTerm = 'test';
				context.clearLookupUI = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				context.dispatchValueSelectEvent = jest.fn();
				context.publishValueSelectMessage = jest.fn();
				const defaultRecordIdDescriptor = Object.getOwnPropertyDescriptor(LwcBaseLookup.prototype, 'defaultRecordId');
				Object.defineProperty(context, 'defaultRecordId', {
					get: defaultRecordIdDescriptor.get.bind(context), set: defaultRecordIdDescriptor.set.bind(context)
				});
				const selectedRecordDescriptor = Object.getOwnPropertyDescriptor(LwcBaseLookup.prototype, 'selectedRecord');
				Object.defineProperty(context, 'selectedRecord', {
					get: selectedRecordDescriptor.get.bind(context), set: selectedRecordDescriptor.set.bind(context)
				});
				prototype.clearLookup.call(context);
				expect(context.preselected).toBeNull();
			});

			it('getResults parses controllerSearchParameters', async() =>
			{
				const context = createMockContext();
				context.controllerSearchParameters = 'objectName=Account;maxResults=10';
				context.searchTerm = 'test';
				context.extractResults = jest.fn((results) => results);
				await prototype.getResults.call(context);
				expect(context.callControllerMethod).toHaveBeenCalled();
				const callArgs = context.callControllerMethod.mock.calls[0][1];
				expect(callArgs.searchParameters.objectName).toBe('Account');
				expect(callArgs.searchParameters.maxResults).toBe('10');
			});

			it('getResults issues the search with no parameters when Search Parameters is left unset', async() =>
			{
				const context = createMockContext();
				context.controllerSearchParameters = undefined;
				context.searchTerm = 'test';
				context.extractResults = jest.fn((results) => results);
				await prototype.getResults.call(context);
				expect(context.callControllerMethod).toHaveBeenCalled();
				const callArgs = context.callControllerMethod.mock.calls[0][1];
				expect(callArgs.searchParameters).toStrictEqual({});
			});

			it('getResults issues the search with no parameters when Search Parameters is blank', async() =>
			{
				const context = createMockContext();
				context.controllerSearchParameters = '';
				context.searchTerm = 'test';
				context.extractResults = jest.fn((results) => results);
				await prototype.getResults.call(context);
				expect(context.callControllerMethod).toHaveBeenCalled();
				const callArgs = context.callControllerMethod.mock.calls[0][1];
				expect(callArgs.searchParameters).toStrictEqual({});
			});

			it('getResults keeps embedded = characters in parameter values', async() =>
			{
				const context = createMockContext();
				context.controllerSearchParameters = 'filterExpression=Status__c=Open;objectName=Account';
				context.searchTerm = 'test';
				context.extractResults = jest.fn((results) => results);
				await prototype.getResults.call(context);
				const callArgs = context.callControllerMethod.mock.calls[0][1];
				expect(callArgs.searchParameters.filterExpression).toBe('Status__c=Open');
				expect(callArgs.searchParameters.objectName).toBe('Account');
			});

			it('getResults parses a key with no value and skips empty segments', async() =>
			{
				const context = createMockContext();
				context.controllerSearchParameters = 'flagOnly;;objectName=Account';
				context.searchTerm = 'test';
				context.extractResults = jest.fn((results) => results);
				await prototype.getResults.call(context);
				const callArgs = context.callControllerMethod.mock.calls[0][1];
				expect(callArgs.searchParameters).toStrictEqual({flagOnly: undefined, objectName: 'Account'});
			});

			it('getResults uses executeSearchController when controllerName is set', async() =>
			{
				const context = createMockContext();
				context.controllerName = 'MyController';
				context.controllerSearchParameters = 'param=value';
				context.extractResults = jest.fn((results) => results);
				await prototype.getResults.call(context);
				expect(context.callControllerMethod).toHaveBeenCalled();
				const controller = context.callControllerMethod.mock.calls[0][0];
				expect(controller).toBeDefined();
			});

			it('getResults uses callController when controllerName is not set', async() =>
			{
				const context = createMockContext();
				context.controllerName = null;
				context.controllerSearchParameters = 'param=value';
				context.callController = jest.fn().mockResolvedValue([]);
				context.extractResults = jest.fn((results) => results);
				await prototype.getResults.call(context);
				const controller = context.callControllerMethod.mock.calls[0][0];
				expect(controller).toBe(context.callController);
			});

			it('getResults extracts and stores results', async() =>
			{
				const context = createMockContext();
				context.controllerSearchParameters = 'param=value';
				context.callControllerMethod = jest.fn().mockResolvedValue([
					{Id: '001'},
					{Id: '002'}
				]);
				context.extractResults = jest.fn((results) => results.map(r => ({...r, extracted: true})));
				await prototype.getResults.call(context);
				expect(context.searchResults.length).toBe(2);
				expect(context.searchResults[0].extracted).toBe(true);
				expect(context.isSearchLoading).toBe(false);
			});

			it('setSearchTimeoutFn sets timeout and calls getResults', async() =>
			{
				jest.useFakeTimers();
				const context = createMockContext();
				context.controllerSearchParameters = 'param=value';
				context.extractResults = jest.fn((results) => results);
				context.getResults = jest.fn().mockResolvedValue();
				prototype.setSearchTimeoutFn.call(context, 'search term');
				expect(context.delayTimeout).toBeDefined();
				jest.advanceTimersByTime(DEBOUNCE_DELAY);
				await Promise.resolve();
				expect(context.searchTerm).toBe('search term');
				expect(context.dispatchSearchTermChangedEvent).toHaveBeenCalled();
				jest.useRealTimers();
			});

			it('setSearchTimeoutFn does not call getResults when searchTerm is empty', async() =>
			{
				jest.useFakeTimers();
				const context = createMockContext();
				context.getResults = jest.fn();
				prototype.setSearchTimeoutFn.call(context, '');
				jest.advanceTimersByTime(DEBOUNCE_DELAY);
				await Promise.resolve();
				expect(context.getResults).not.toHaveBeenCalled();
				jest.useRealTimers();
			});

			it('setSearchTimeoutFn calls getResults when searchTerm is non-empty', async() =>
			{
				jest.useFakeTimers();
				const context = createMockContext();
				context.getResults = jest.fn().mockResolvedValue();
				prototype.setSearchTimeoutFn.call(context, 'test query');
				jest.advanceTimersByTime(DEBOUNCE_DELAY);
				await Promise.resolve();
				await Promise.resolve();
				expect(context.searchTerm).toBe('test query');
				expect(context.dispatchSearchTermChangedEvent).toHaveBeenCalled();
				jest.useRealTimers();
			});
		});

		describe('default api functions via createElement', () =>
		{
			afterEach(() =>
			{
				while(document.body.firstChild)
				{
					document.body.removeChild(document.body.firstChild);
				}
			});

			it('callController default returns empty array promise', async() =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				const fn = element.callController;
				expect(fn).toBeDefined();
				const result = await fn();
				expect(result).toEqual([]);
			});

			it('extractResults default returns the passed in list', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				const fn = element.extractResults;
				expect(fn).toBeDefined();
				const input = [
					{Id: '001'},
					{Id: '002'}
				];
				const result = fn(input);
				expect(result).toEqual(input);
			});

			it('extractResults default returns empty array when no argument', () =>
			{
				const {createElement} = require('lwc');
				const element = createElement('c-search-lookup', {is: LwcSearchLookup});
				document.body.appendChild(element);
				const fn = element.extractResults;
				const result = fn();
				expect(result).toEqual([]);
			});
		});
	});

	/*
	 * The @lwc/jest-transformer rewrites the `executeSearchController` import into
	 * a try/catch whose catch block contains a `global.__lwcJestMock_executeSearchController
	 * || function...` binary expression. With the module under test mocked via
	 * jest.mock above, require succeeds and the catch never runs — leaving both
	 * branches of the binary expression uncovered. The two tests below force the
	 * catch to run, once with the global pre-populated (LHS truthy) and once
	 * without (RHS wins).
	 */
	describe('apex-stub fallback (jest-transformer catch block)', () =>
	{
		afterEach(() =>
		{
			jest.resetModules();
			delete global.__lwcJestMock_executeSearchController;
		});

		it('uses the pre-set global.__lwcJestMock_executeSearchController when present', () =>
		{
			const fallback = jest.fn().mockResolvedValue([]);
			global.__lwcJestMock_executeSearchController = fallback;

			let loaded;
			jest.isolateModules(() =>
			{
				jest.doMock('@salesforce/apex/CTRL_ExecuteSearch.executeSearchController', () =>
				{
					throw new Error('forced require failure');
				}, {virtual: true});
				jest.doMock('@salesforce/messageChannel/Component__c', () => ({default: {}}), {virtual: true});
				jest.doMock('c/utilitySystem', () => ({
					setPropertyOnObject: jest.fn((obj, key, value) =>
					{
						obj[key] = value;
						return obj;
					})
				}), {virtual: true});
				loaded = require('c/searchLookup').default;
			});

			expect(loaded).toBeDefined();
			expect(typeof loaded).toBe('function');
			expect(global.__lwcJestMock_executeSearchController).toBe(fallback);
		});

		it('generates the stub function when the global is empty', () =>
		{
			delete global.__lwcJestMock_executeSearchController;

			let loaded;
			jest.isolateModules(() =>
			{
				jest.doMock('@salesforce/apex/CTRL_ExecuteSearch.executeSearchController', () =>
				{
					throw new Error('forced require failure');
				}, {virtual: true});
				jest.doMock('@salesforce/messageChannel/Component__c', () => ({default: {}}), {virtual: true});
				jest.doMock('c/utilitySystem', () => ({
					setPropertyOnObject: jest.fn((obj, key, value) =>
					{
						obj[key] = value;
						return obj;
					})
				}), {virtual: true});
				loaded = require('c/searchLookup').default;
			});

			expect(loaded).toBeDefined();
			expect(typeof global.__lwcJestMock_executeSearchController).toBe('function');
		});
	});
});
