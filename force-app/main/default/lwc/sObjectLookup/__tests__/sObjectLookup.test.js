// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for sObjectLookup LWC component.
 *
 *              The transformer-generated apex-import catch block is covered by
 *              pre-setting `global.__lwcJestMock_search` and loading the component
 *              inside `jest.isolateModules`, with one paired test that deletes the
 *              global slot so the fallback-stub function expression is evaluated.
 *
 * @author Jason van Beukering
 * @date December 2025, April 2026
 */

jest.mock('@salesforce/messageChannel/Component__c', () => ({
	default: {}
}), {virtual: true});

jest.mock('lightning/uiObjectInfoApi', () => ({
	getObjectInfo: jest.fn()
}), {virtual: true});

describe('c-s-object-lookup', () =>
{
	let search;

	beforeAll(() =>
	{
		search = jest.fn();
		global.__lwcJestMock_search = search;
	});

	afterAll(() =>
	{
		delete global.__lwcJestMock_search;
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
	 *              transformer's apex try/catch runs fresh on each call.
	 * @returns {Function} The LwcSObjectLookup class.
	 */
	function loadComponent()
	{
		let component;
		jest.isolateModules(() =>
		{
			component = require('c/sObjectLookup').default;
		});
		return component;
	}

	describe('module exports', () =>
	{
		it('exports LwcSObjectLookup as default', () =>
		{
			const LwcSObjectLookup = loadComponent();
			expect(LwcSObjectLookup).toBeDefined();
			expect(typeof LwcSObjectLookup).toBe('function');
		});

		it('extends LwcBaseLookup', () =>
		{
			let LwcSObjectLookup;
			let LwcBaseLookup;
			jest.isolateModules(() =>
			{
				LwcSObjectLookup = require('c/sObjectLookup').default;
				LwcBaseLookup = require('c/baseLookup').default;
			});
			expect(LwcSObjectLookup.prototype instanceof LwcBaseLookup).toBe(true);
		});
	});

	describe('class structure', () =>
	{
		let prototype;

		beforeAll(() =>
		{
			prototype = loadComponent().prototype;
		});

		it('has render method', () =>
		{
			expect(typeof prototype.render).toBe('function');
		});

		it('has searchSObjectsParams getter', () =>
		{
			const desc = Object.getOwnPropertyDescriptor(prototype, 'searchSObjectsParams');
			expect(desc).toBeDefined();
			expect(typeof desc.get).toBe('function');
		});

		it('has fetchRecordByIdParams getter', () =>
		{
			const desc = Object.getOwnPropertyDescriptor(prototype, 'fetchRecordByIdParams');
			expect(desc).toBeDefined();
			expect(typeof desc.get).toBe('function');
		});

		it('overrides icon getter', () =>
		{
			const desc = Object.getOwnPropertyDescriptor(prototype, 'icon');
			expect(desc).toBeDefined();
			expect(typeof desc.get).toBe('function');
		});
	});

	describe('@api properties', () =>
	{
		it('has objectApiName as @api property', () =>
		{
			const LwcSObjectLookup = loadComponent();
			const desc = Object.getOwnPropertyDescriptor(LwcSObjectLookup.prototype, 'objectApiName');
			expect(desc).toBeDefined();
		});
	});

	describe('@wire methods', () =>
	{
		let prototype;

		beforeAll(() =>
		{
			prototype = loadComponent().prototype;
		});

		it('has fetchObjectInfo wired method', () =>
		{
			expect(prototype.fetchObjectInfo).toBeDefined();
		});

		it('has fetchRecords wired method', () =>
		{
			expect(prototype.fetchRecords).toBeDefined();
		});

		it('has findDefaultRecordById wired method', () =>
		{
			expect(prototype.findDefaultRecordById).toBeDefined();
		});
	});

	describe('dependency on lightning/uiObjectInfoApi', () =>
	{
		it('imports getObjectInfo', () =>
		{
			const {getObjectInfo} = require('lightning/uiObjectInfoApi');
			expect(getObjectInfo).toBeDefined();
		});
	});

	describe('instance behavior', () =>
	{
		let prototype;

		beforeAll(() =>
		{
			prototype = loadComponent().prototype;
		});

		const createMockContext = () =>
		{
			return {
				objectApiName: 'Account',
				objectInfo: null,
				displayFields: [
					'Name',
					'Industry'
				],
				iconName: null,
				searchResults: [],
				isSearchLoading: false,
				record: null,
				templateHTML: '<div>Template</div>',
				handleWireResponse: jest.fn((result) => result.data)
			};
		};

		const callGetter = (context, propertyName) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, propertyName).get.call(context);
		};

		describe('getters', () =>
		{
			it('searchSObjectsParams returns correct structure', () =>
			{
				const context = createMockContext();
				const result = callGetter(context, 'searchSObjectsParams');
				expect(result.selectFields).toEqual([
					'Name',
					'Industry'
				]);
				expect(result.objectName).toBe('Account');
			});

			it('fetchRecordByIdParams returns correct structure', () =>
			{
				const context = createMockContext();
				Object.defineProperty(context, 'recordId', {get: () => '001000000000001'});
				const result = callGetter(context, 'fetchRecordByIdParams');
				expect(result.recordId).toBe('001000000000001');
				expect(result.selectFields).toEqual([
					'Name',
					'Industry'
				]);
			});

			it('icon returns standard icon for non-custom objects', () =>
			{
				const context = createMockContext();
				context.objectInfo = {custom: false};
				expect(callGetter(context, 'icon')).toBe('standard:account');
			});

			it('icon returns iconName for custom objects when set', () =>
			{
				const context = createMockContext();
				context.objectInfo = {custom: true};
				context.iconName = 'custom:custom51';
				expect(callGetter(context, 'icon')).toBe('custom:custom51');
			});

			it('icon returns empty string for custom objects when iconName not set', () =>
			{
				const context = createMockContext();
				context.objectInfo = {custom: true};
				context.iconName = null;
				expect(callGetter(context, 'icon')).toBe('');
			});

			it('icon returns standard icon when objectInfo is null', () =>
			{
				const context = createMockContext();
				context.objectInfo = null;
				expect(callGetter(context, 'icon')).toBe('standard:account');
			});

			it('icon returns empty string instead of throwing while objectApiName is not yet provided', () =>
			{
				const context = createMockContext();
				context.objectInfo = null;
				context.objectApiName = undefined;
				expect(() => callGetter(context, 'icon')).not.toThrow();
				expect(callGetter(context, 'icon')).toBe('');
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
		});

		describe('wire callbacks', () =>
		{
			it('fetchObjectInfo sets objectInfo from response', () =>
			{
				const context = createMockContext();
				const mockData = {apiName: 'Account', custom: false};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchObjectInfo.call(context, {data: mockData});
				expect(context.objectInfo).toBe(mockData);
			});

			it('fetchRecords sets searchResults and stops loading', () =>
			{
				const context = createMockContext();
				const mockData = [{Id: '001', Name: 'Test'}];
				context.handleWireResponse = jest.fn(() => mockData);
				context.isSearchLoading = true;
				prototype.fetchRecords.call(context, {data: mockData});
				expect(context.searchResults).toBe(mockData);
				expect(context.isSearchLoading).toBe(false);
			});

			it('fetchRecords sets empty array when no data', () =>
			{
				const context = createMockContext();
				context.handleWireResponse = jest.fn(() => null);
				prototype.fetchRecords.call(context, {data: null});
				expect(context.searchResults).toEqual([]);
			});

			it('findDefaultRecordById sets selectedRecord when response differs (no existing)', () =>
			{
				const context = createMockContext();
				const mockData = {Id: '001', Name: 'Test'};
				context.handleWireResponse = jest.fn(() => mockData);
				const selectedRecordSetter = jest.fn();
				Object.defineProperty(context, 'selectedRecord', {
					get: () => null, set: selectedRecordSetter
				});
				prototype.findDefaultRecordById.call(context, {data: mockData});
				expect(selectedRecordSetter).toHaveBeenCalledWith(mockData);
			});

			it('findDefaultRecordById does not set selectedRecord when same Id', () =>
			{
				const context = createMockContext();
				const mockData = {Id: '001', Name: 'Test'};
				context.handleWireResponse = jest.fn(() => mockData);
				context.record = {Id: '001', Name: 'Existing'};
				const selectedRecordSetter = jest.fn();
				Object.defineProperty(context, 'selectedRecord', {
					get: () => context.record, set: selectedRecordSetter
				});
				prototype.findDefaultRecordById.call(context, {data: mockData});
				expect(selectedRecordSetter).not.toHaveBeenCalled();
			});

			it('findDefaultRecordById does nothing when response is null', () =>
			{
				const context = createMockContext();
				context.handleWireResponse = jest.fn(() => null);
				const selectedRecordSetter = jest.fn();
				Object.defineProperty(context, 'selectedRecord', {
					get: () => null, set: selectedRecordSetter
				});
				prototype.findDefaultRecordById.call(context, {data: null});
				expect(selectedRecordSetter).not.toHaveBeenCalled();
			});

			it('findDefaultRecordById sets selectedRecord when existing record has different Id', () =>
			{
				const context = createMockContext();
				const mockData = {Id: '002', Name: 'New Test'};
				context.handleWireResponse = jest.fn(() => mockData);
				context.record = {Id: '001', Name: 'Existing'};
				const selectedRecordSetter = jest.fn();
				Object.defineProperty(context, 'selectedRecord', {
					get: () => context.record, set: selectedRecordSetter
				});
				prototype.findDefaultRecordById.call(context, {data: mockData});
				expect(selectedRecordSetter).toHaveBeenCalledWith(mockData);
			});
		});
	});

	describe('class instantiation', () =>
	{
		it('can be instantiated via createElement with default property values', async() =>
		{
			const {createElement} = require('lwc');
			const LwcSObjectLookup = require('c/sObjectLookup').default;
			const element = createElement('c-s-object-lookup', {is: LwcSObjectLookup});
			element.objectApiName = 'Account';
			document.body.appendChild(element);

			await new Promise((resolve) => setTimeout(resolve, 0));

			expect(element.objectApiName).toBe('Account');
		});

		it('exercises the transformer fallback stub when global slot is empty', () =>
		{
			delete global.__lwcJestMock_search;

			let LwcSObjectLookupFresh;
			jest.isolateModules(() =>
			{
				LwcSObjectLookupFresh = require('c/sObjectLookup').default;
			});
			global.__lwcJestMock_search = search;

			expect(typeof LwcSObjectLookupFresh).toBe('function');
			expect(typeof LwcSObjectLookupFresh.prototype.render).toBe('function');
		});
	});
});
