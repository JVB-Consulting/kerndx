// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for baseLookup LWC component.
 *
 *              Note: This component extends ComponentBuilder and uses custom templates.
 *              Due to LWC template resolution limitations in Jest, these tests verify
 *              module structure, exports, and static analysis rather than DOM rendering.
 *
 * @author Jason van Beukering
 * @date December 2025, July 2026
 */

// Custom Label mocks — values byte-equal the real CustomLabels entries so any
// value assertion exercises the shipped text.
jest.mock('@salesforce/label/c.BaseLookup_NoRecordsFound', () => ({default: 'No Records Found....'}), {virtual: true});
jest.mock('@salesforce/label/c.BaseLookup_RemoveSelectedOption', () => ({default: 'Remove selected option'}), {virtual: true});
jest.mock('@salesforce/label/c.BaseLookup_SearchPlaceholder', () => ({default: 'Search'}), {virtual: true});

// Mock dependencies
jest.mock('@salesforce/messageChannel/Component__c', () => ({
	default: {}
}), {virtual: true});

const DEBOUNCE_DELAY = 300;

describe('c-base-lookup', () =>
{
	describe('module exports', () =>
	{
		it('exports DELAY constant', () =>
		{
			const {DELAY} = require('c/baseLookup');
			expect(DELAY).toBe(300);
		});

		it('exports LwcBaseLookup as default', () =>
		{
			const LwcBaseLookup = require('c/baseLookup').default;
			expect(LwcBaseLookup).toBeDefined();
			expect(typeof LwcBaseLookup).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		it('has expected prototype methods', () =>
		{
			const LwcBaseLookup = require('c/baseLookup').default;
			const prototype = LwcBaseLookup.prototype;

			// Core methods
			expect(typeof prototype.generateRecordLabel).toBe('function');
			expect(typeof prototype.showResults).toBe('function');
			expect(typeof prototype.hideResults).toBe('function');
			expect(typeof prototype.clearLookup).toBe('function');
			expect(typeof prototype.clearLookupUI).toBe('function');
			expect(typeof prototype.handleSelectedRecord).toBe('function');
			expect(typeof prototype.handleKeyDown).toBe('function');
			expect(typeof prototype.handleKeyChange).toBe('function');
			expect(typeof prototype.nextSearchResult).toBe('function');
			expect(typeof prototype.previousSearchResult).toBe('function');
			expect(typeof prototype.selectSearchOptionUI).toBe('function');
			expect(typeof prototype.resetSearchOptionFocus).toBe('function');
			expect(typeof prototype.getResultIdentifier).toBe('function');
			expect(typeof prototype.handleSelectRecordHelper).toBe('function');
			expect(typeof prototype.setSearchTimeoutFn).toBe('function');
			expect(typeof prototype.connectedCallback).toBe('function');
			expect(typeof prototype.disconnectedCallback).toBe('function');
			expect(typeof prototype.dispatchValueSelectEvent).toBe('function');
			expect(typeof prototype.publishValueSelectMessage).toBe('function');
			expect(typeof prototype.dispatchSearchTermChangedEvent).toBe('function');
		});

		it('has getter/setter pairs for key properties', () =>
		{
			const LwcBaseLookup = require('c/baseLookup').default;
			const prototype = LwcBaseLookup.prototype;

			// Check getter/setter descriptors
			const defaultRecordIdDesc = Object.getOwnPropertyDescriptor(prototype, 'defaultRecordId');
			expect(defaultRecordIdDesc).toBeDefined();
			expect(typeof defaultRecordIdDesc.get).toBe('function');
			expect(typeof defaultRecordIdDesc.set).toBe('function');

			const selectedRecordDesc = Object.getOwnPropertyDescriptor(prototype, 'selectedRecord');
			expect(selectedRecordDesc).toBeDefined();
			expect(typeof selectedRecordDesc.get).toBe('function');
			expect(typeof selectedRecordDesc.set).toBe('function');

			const searchResultsDesc = Object.getOwnPropertyDescriptor(prototype, 'searchResults');
			expect(searchResultsDesc).toBeDefined();
			expect(typeof searchResultsDesc.get).toBe('function');
			expect(typeof searchResultsDesc.set).toBe('function');
		});

		it('has computed getters', () =>
		{
			const LwcBaseLookup = require('c/baseLookup').default;
			const prototype = LwcBaseLookup.prototype;

			const getterNames = [
				'fieldLabelClass',
				'elementClass',
				'recordId',
				'icon',
				'pillLabel',
				'displayFieldFormat',
				'lookupInputContainerClassList',
				'filteredSearchResults',
				'displaySearchOptions',
				'hasRecords',
				'displayNoRecordsFound',
				'searchTermChangedEvent',
				'valueSelectDetail',
				'valueSelectEvent'
			];

			getterNames.forEach((getterName) =>
			{
				const descriptor = Object.getOwnPropertyDescriptor(prototype, getterName);
				expect(descriptor).toBeDefined();
				expect(typeof descriptor.get).toBe('function');
			});
		});
	});

	describe('DELAY constant', () =>
	{
		it('is 300 milliseconds for debouncing', () =>
		{
			const {DELAY} = require('c/baseLookup');
			expect(DELAY).toBe(300);
			expect(typeof DELAY).toBe('number');
		});
	});

	describe('keyboard constants', () =>
	{
		it('module loads successfully indicating constants are valid', () =>
		{
			// We can't directly access the constants (ENTER_KEY, UP_KEY, etc.)
			// because they're module-private, but we verify the module loads
			const LwcBaseLookup = require('c/baseLookup').default;
			expect(LwcBaseLookup).toBeDefined();
		});
	});

	describe('@api properties', () =>
	{
		it('defines expected @api property descriptors', () =>
		{
			expect.hasAssertions();

			const LwcBaseLookup = require('c/baseLookup').default;
			const prototype = LwcBaseLookup.prototype;

			// @api properties have getter/setter created by LWC decorator
			const apiProps = [
				'outerElementClasses',
				'disableElement',
				'elementName',
				'fieldLabelName',
				'readOnly',
				'placeholder',
				'displayFields',
				'displayFormat',
				'iconName',
				'isRequired',
				'idField',
				'searchOptions'
			];

			apiProps.forEach((propName) =>
			{
				const descriptor = Object.getOwnPropertyDescriptor(prototype, propName);
				// @api creates getter/setter
				expect(descriptor).toBeDefined();
				expect(descriptor.get || descriptor.set || descriptor.value !== undefined).toBeTruthy();
			});
		});
	});

	describe('event generation', () =>
	{
		it('searchTermChangedEvent getter exists', () =>
		{
			const LwcBaseLookup = require('c/baseLookup').default;
			const descriptor = Object.getOwnPropertyDescriptor(LwcBaseLookup.prototype, 'searchTermChangedEvent');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('valueSelectEvent getter exists', () =>
		{
			const LwcBaseLookup = require('c/baseLookup').default;
			const descriptor = Object.getOwnPropertyDescriptor(LwcBaseLookup.prototype, 'valueSelectEvent');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});
	});

	describe('instance behavior', () =>
	{
		const LwcBaseLookup = require('c/baseLookup').default;
		const prototype = LwcBaseLookup.prototype;

		const createMockClassList = () =>
		{
			const classes = new Set();
			return {
				add: jest.fn((className) => classes.add(className)), remove: jest.fn((className) => classes.delete(className)), has: (className) => classes.has(className)
			};
		};

		const createMockTemplate = () =>
		{
			const mockClassList = createMockClassList();
			const mockSearchOptions = [];
			return {
				querySelector: jest.fn((selector) =>
				{
					if(selector === '.lookupInputContainer')
					{
						return {classList: mockClassList};
					}
					if(selector === '.searchBoxWrapper')
					{
						return {classList: createMockClassList()};
					}
					if(selector === '.pillDiv')
					{
						return {classList: createMockClassList()};
					}
					return null;
				}), querySelectorAll: jest.fn((selector) =>
				{
					if(selector === '.search-options')
					{
						return mockSearchOptions;
					}
					return [];
				})
			};
		};

		const createMockContext = () =>
		{
			return {
				preselectedRecordId: null,
				record: null,
				searchTerm: '',
				searchResults: [],
				searchOptions: [],
				isSearchLoading: false,
				currentFocusedSearchOption: -1,
				delayTimeout: null,
				displayFields: ['Name'],
				displayFormat: null,
				idField: 'Id',
				elementName: 'testLookup',
				isRequired: false,
				outerElementClasses: '',
				iconName: null,
				valueSelectEventParams: {},
				template: createMockTemplate(),
				dispatchEvent: jest.fn(),
				publishLightningMessage: jest.fn(),
				messageContext: null
			};
		};

		const getDescriptor = (propertyName) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, propertyName);
		};

		const callGetter = (context, propertyName) =>
		{
			return getDescriptor(propertyName).get.call(context);
		};

		const callSetter = (context, propertyName, value) =>
		{
			getDescriptor(propertyName).set.call(context, value);
		};

		const bindDescriptor = (context, propertyName) =>
		{
			const descriptor = getDescriptor(propertyName);
			Object.defineProperty(context, propertyName, {
				get: descriptor.get?.bind(context), set: descriptor.set?.bind(context)
			});
		};

		const prepareSearchContext = (context) =>
		{
			Object.defineProperty(context, 'displayFieldFormat', {get: () => 'Name'});
			bindDescriptor(context, 'filteredSearchResults');
			context.generateRecordLabel = prototype.generateRecordLabel.bind(context);
			context.getResultIdentifier = prototype.getResultIdentifier.bind(context);
			context.showResults = jest.fn();
			context.selectSearchOptionUI = jest.fn();
		};

		describe('getters', () =>
		{
			it('defaultRecordId returns preselectedRecordId', () =>
			{
				const context = createMockContext();
				context.preselectedRecordId = '001000000000001';
				const result = callGetter(context, 'defaultRecordId');
				expect(result).toBe('001000000000001');
			});

			it('fieldLabelClass returns required class when isRequired is true', () =>
			{
				const context = createMockContext();
				context.isRequired = true;
				const result = callGetter(context, 'fieldLabelClass');
				expect(result).toBe('slds-form-element__label required-field');
			});

			it('fieldLabelClass returns non-required class when isRequired is false', () =>
			{
				const context = createMockContext();
				context.isRequired = false;
				const result = callGetter(context, 'fieldLabelClass');
				expect(result).toBe('slds-form-element__label');
			});

			it('elementClass combines base classes with outerElementClasses', () =>
			{
				const context = createMockContext();
				context.outerElementClasses = 'custom-class';
				const result = callGetter(context, 'elementClass');
				expect(result).toContain('slds-form-element');
				expect(result).toContain('custom-class');
			});

			it('recordId returns selectedRecord id or defaultRecordId', () =>
			{
				const context = createMockContext();
				context.record = {Id: '001000000000002'};
				context.idField = 'Id';
				context.getResultIdentifier = prototype.getResultIdentifier.bind(context);
				Object.defineProperty(context, 'selectedRecord', {get: () => context.record});
				Object.defineProperty(context, 'defaultRecordId', {get: () => '001000000000001'});
				const result = callGetter(context, 'recordId');
				expect(result).toBe('001000000000002');
			});

			it('recordId falls back to defaultRecordId when selectedRecord has no identifier', () =>
			{
				const context = createMockContext();
				context.record = null;
				context.idField = 'Id';
				context.getResultIdentifier = prototype.getResultIdentifier.bind(context);
				Object.defineProperty(context, 'selectedRecord', {get: () => context.record});
				Object.defineProperty(context, 'defaultRecordId', {get: () => '001000000000099'});
				const result = callGetter(context, 'recordId');
				expect(result).toBe('001000000000099');
			});

			it('icon returns iconName or empty string', () =>
			{
				const context = createMockContext();
				context.iconName = 'standard:account';
				const result = callGetter(context, 'icon');
				expect(result).toBe('standard:account');
			});

			it('icon returns empty string when iconName is not set', () =>
			{
				const context = createMockContext();
				context.iconName = null;
				const result = callGetter(context, 'icon');
				expect(result).toBe('');
			});

			it('pillLabel returns empty string when no record selected', () =>
			{
				const context = createMockContext();
				Object.defineProperty(context, 'selectedRecord', {get: () => null});
				const result = callGetter(context, 'pillLabel');
				expect(result).toBe('');
			});

			it('pillLabel returns generated label when record is selected', () =>
			{
				const context = createMockContext();
				context.record = {Name: 'Test Account'};
				context.displayFields = ['Name'];
				context.displayFormat = 'Name';
				Object.defineProperty(context, 'selectedRecord', {get: () => context.record});
				context.generateRecordLabel = prototype.generateRecordLabel.bind(context);
				Object.defineProperty(context, 'displayFieldFormat', {get: () => 'Name'});
				const result = callGetter(context, 'pillLabel');
				expect(result).toBe('Test Account');
			});

			it('displayFieldFormat returns displayFormat when set', () =>
			{
				const context = createMockContext();
				context.displayFormat = 'Custom Format';
				const result = callGetter(context, 'displayFieldFormat');
				expect(result).toBe('Custom Format');
			});

			it('displayFieldFormat returns first displayField when displayFormat is not set', () =>
			{
				const context = createMockContext();
				context.displayFormat = null;
				context.displayFields = [
					'Email',
					'Name'
				];
				const result = callGetter(context, 'displayFieldFormat');
				expect(result).toBe('Email');
			});

			it('lookupInputContainerClassList returns classList from template', () =>
			{
				const context = createMockContext();
				const result = callGetter(context, 'lookupInputContainerClassList');
				expect(result).toBeDefined();
				expect(context.template.querySelector).toHaveBeenCalledWith('.lookupInputContainer');
			});

			it('displaySearchOptions filters and maps search results', () =>
			{
				const context = createMockContext();
				context.searchResults = [
					{Id: '001', Name: 'Test Account'},
					{Id: '002', Name: 'Another Account'}
				];
				context.searchTerm = 'test';
				context.record = null;
				context.displayFields = ['Name'];
				context.idField = 'Id';
				prepareSearchContext(context);
				const result = callGetter(context, 'displaySearchOptions');
				expect(result.length).toBe(1);
				expect(result[0].Name).toBe('Test Account');
				expect(result[0].label).toBe('Test Account');
				expect(result[0].resultIdentifier).toBe('001');
			});

			it('selectedRecord returns record', () =>
			{
				const context = createMockContext();
				context.record = {Id: '001', Name: 'Test'};
				const result = callGetter(context, 'selectedRecord');
				expect(result).toBe(context.record);
			});

			it('searchTermChangedEvent returns CustomEvent with search term', () =>
			{
				const context = createMockContext();
				context.searchTerm = 'test search';
				context.elementName = 'myLookup';
				const result = callGetter(context, 'searchTermChangedEvent');
				expect(result).toBeInstanceOf(CustomEvent);
				expect(result.type).toBe('searchtermchanged');
				expect(result.detail.searchTerm).toBe('test search');
				expect(result.detail.elementName).toBe('myLookup');
			});

			it('valueSelectDetail returns object with selectedId and metadata', () =>
			{
				const context = createMockContext();
				context.record = {Id: '001'};
				context.elementName = 'myLookup';
				context.isRequired = true;
				context.idField = 'Id';
				context.valueSelectEventParams = {extra: 'param'};
				context.getResultIdentifier = prototype.getResultIdentifier.bind(context);
				const result = callGetter(context, 'valueSelectDetail');
				expect(result.selectedId).toBe('001');
				expect(result.elementName).toBe('myLookup');
				expect(result.isRequired).toBe(true);
				expect(result.extra).toBe('param');
			});

			it('valueSelectEvent returns CustomEvent with valueSelectDetail', () =>
			{
				const context = createMockContext();
				Object.defineProperty(context, 'valueSelectDetail', {get: () => ({selectedId: '001'})});
				const result = callGetter(context, 'valueSelectEvent');
				expect(result).toBeInstanceOf(CustomEvent);
				expect(result.type).toBe('valueselect');
				expect(result.detail.selectedId).toBe('001');
			});
		});

		describe('setters', () =>
		{
			it('defaultRecordId sets preselectedRecordId', () =>
			{
				const context = createMockContext();
				callSetter(context, 'defaultRecordId', '001000000000001');
				expect(context.preselectedRecordId).toBe('001000000000001');
			});

			it('defaultRecordId sets null when value is falsy', () =>
			{
				const context = createMockContext();
				callSetter(context, 'defaultRecordId', '');
				expect(context.preselectedRecordId).toBe(null);
			});

			it('selectedRecord calls handleSelectRecordHelper when record is set', () =>
			{
				const context = createMockContext();
				context.handleSelectRecordHelper = jest.fn();
				context.dispatchValueSelectEvent = jest.fn();
				context.publishValueSelectMessage = jest.fn();
				callSetter(context, 'selectedRecord', {Id: '001'});
				expect(context.handleSelectRecordHelper).toHaveBeenCalled();
				expect(context.dispatchValueSelectEvent).toHaveBeenCalled();
				expect(context.publishValueSelectMessage).toHaveBeenCalled();
			});

			it('selectedRecord clears lookup when record is null', () =>
			{
				const context = createMockContext();
				context.clearLookupUI = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				context.dispatchValueSelectEvent = jest.fn();
				context.publishValueSelectMessage = jest.fn();
				bindDescriptor(context, 'defaultRecordId');
				callSetter(context, 'selectedRecord', null);
				expect(context.clearLookupUI).toHaveBeenCalled();
				expect(context.dispatchSearchTermChangedEvent).toHaveBeenCalled();
			});
		});

		describe('methods', () =>
		{
			it('connectedCallback populates searchResults from searchOptions', () =>
			{
				const context = createMockContext();
				context.searchOptions = [{Id: '001', Name: 'Test'}];
				prototype.connectedCallback.call(context);
				expect(context.searchResults).toEqual([{Id: '001', Name: 'Test'}]);
			});

			it('connectedCallback does not modify searchResults when searchOptions is empty', () =>
			{
				const context = createMockContext();
				context.searchOptions = [];
				context.searchResults = [{Id: '002'}];
				prototype.connectedCallback.call(context);
				expect(context.searchResults).toEqual([{Id: '002'}]);
			});

			it('generateRecordLabel replaces field names with values', () =>
			{
				const context = createMockContext();
				context.displayFields = [
					'FirstName',
					'LastName'
				];
				Object.defineProperty(context, 'displayFieldFormat', {get: () => 'FirstName LastName'});
				const record = {FirstName: 'John', LastName: 'Doe'};
				const result = prototype.generateRecordLabel.call(context, record);
				expect(result).toBe('John Doe');
			});

			it('showResults adds slds-is-open class', () =>
			{
				const context = createMockContext();
				const mockClassList = createMockClassList();
				Object.defineProperty(context, 'lookupInputContainerClassList', {get: () => mockClassList});
				prototype.showResults.call(context);
				expect(mockClassList.add).toHaveBeenCalledWith('slds-is-open');
			});

			it('hideResults removes slds-is-open class', () =>
			{
				const context = createMockContext();
				const mockClassList = createMockClassList();
				Object.defineProperty(context, 'lookupInputContainerClassList', {get: () => mockClassList});
				prototype.hideResults.call(context);
				expect(mockClassList.remove).toHaveBeenCalledWith('slds-is-open');
			});

			it('clearLookup resets searchTerm and selectedRecord', () =>
			{
				const context = createMockContext();
				context.searchTerm = 'test';
				context.clearLookupUI = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				context.dispatchValueSelectEvent = jest.fn();
				context.publishValueSelectMessage = jest.fn();
				bindDescriptor(context, 'defaultRecordId');
				bindDescriptor(context, 'selectedRecord');
				prototype.clearLookup.call(context);
				expect(context.searchTerm).toBe('');
				expect(context.record).toBeUndefined();
			});

			it('clearLookupUI updates DOM elements', () =>
			{
				const context = createMockContext();
				prototype.clearLookupUI.call(context);
				expect(context.isSearchLoading).toBe(false);
				expect(context.template.querySelector).toHaveBeenCalledWith('.searchBoxWrapper');
				expect(context.template.querySelector).toHaveBeenCalledWith('.pillDiv');
			});

			it('handleSelectedRecord finds and sets selected record', () =>
			{
				const context = createMockContext();
				context.searchResults = [
					{Id: '001', Name: 'Test 1'},
					{Id: '002', Name: 'Test 2'}
				];
				context.idField = 'Id';
				context.getResultIdentifier = prototype.getResultIdentifier.bind(context);
				context.handleSelectRecordHelper = jest.fn();
				context.dispatchValueSelectEvent = jest.fn();
				context.publishValueSelectMessage = jest.fn();
				bindDescriptor(context, 'selectedRecord');
				const mockEvent = {
					currentTarget: {getAttribute: jest.fn(() => '002')}
				};
				prototype.handleSelectedRecord.call(context, mockEvent);
				expect(context.record.Id).toBe('002');
			});

			it('nextSearchResult increments currentFocusedSearchOption', () =>
			{
				const context = createMockContext();
				context.currentFocusedSearchOption = 0;
				context.filteredSearchResults = [
					{},
					{},
					{}
				];
				prototype.nextSearchResult.call(context);
				expect(context.currentFocusedSearchOption).toBe(1);
			});

			it('previousSearchResult decrements currentFocusedSearchOption', () =>
			{
				const context = createMockContext();
				context.currentFocusedSearchOption = 2;
				prototype.previousSearchResult.call(context);
				expect(context.currentFocusedSearchOption).toBe(1);
			});

			it('previousSearchResult does not decrement below 0', () =>
			{
				const context = createMockContext();
				context.currentFocusedSearchOption = 0;
				prototype.previousSearchResult.call(context);
				expect(context.currentFocusedSearchOption).toBe(0);
			});

			it('selectSearchOptionUI updates CSS classes on search options', () =>
			{
				const context = createMockContext();
				const mockElement1 = {classList: createMockClassList()};
				const mockElement2 = {classList: createMockClassList()};
				context.template.querySelectorAll = jest.fn(() => [
					mockElement1,
					mockElement2
				]);
				context.currentFocusedSearchOption = 1;
				prototype.selectSearchOptionUI.call(context);
				expect(mockElement1.classList.remove).toHaveBeenCalledWith('search-option-selected');
				expect(mockElement2.classList.add).toHaveBeenCalledWith('search-option-selected');
			});

			it('getResultIdentifier returns idField value', () =>
			{
				const context = createMockContext();
				context.idField = 'CustomId';
				const result = prototype.getResultIdentifier.call(context, {CustomId: 'abc123'});
				expect(result).toBe('abc123');
			});

			it('getResultIdentifier falls back to Id field', () =>
			{
				const context = createMockContext();
				context.idField = 'CustomId';
				const result = prototype.getResultIdentifier.call(context, {Id: 'fallback123'});
				expect(result).toBe('fallback123');
			});

			it('getResultIdentifier returns falsy for null result', () =>
			{
				const context = createMockContext();
				const result = prototype.getResultIdentifier.call(context, null);
				expect(result).toBeFalsy();
			});

			it('handleSelectRecordHelper updates DOM elements', () =>
			{
				const context = createMockContext();
				prototype.handleSelectRecordHelper.call(context);
				expect(context.template.querySelector).toHaveBeenCalledWith('.lookupInputContainer');
				expect(context.template.querySelector).toHaveBeenCalledWith('.searchBoxWrapper');
				expect(context.template.querySelector).toHaveBeenCalledWith('.pillDiv');
			});

			it('handleKeyDown handles ESCAPE key', () =>
			{
				const context = createMockContext();
				context.hideResults = jest.fn();
				const mockEvent = {keyCode: 27, preventDefault: jest.fn()};
				prototype.handleKeyDown.call(context, mockEvent);
				expect(mockEvent.preventDefault).toHaveBeenCalled();
				expect(context.hideResults).toHaveBeenCalled();
			});

			it('handleKeyDown handles ENTER key', () =>
			{
				const context = createMockContext();
				context.filteredSearchResults = [{Id: '001'}];
				context.currentFocusedSearchOption = 0;
				context.handleSelectRecordHelper = jest.fn();
				context.dispatchValueSelectEvent = jest.fn();
				context.publishValueSelectMessage = jest.fn();
				bindDescriptor(context, 'selectedRecord');
				const mockEvent = {keyCode: 13, preventDefault: jest.fn()};
				prototype.handleKeyDown.call(context, mockEvent);
				expect(mockEvent.preventDefault).toHaveBeenCalled();
				expect(context.record.Id).toBe('001');
			});

			it('handleKeyDown handles UP key', () =>
			{
				const context = createMockContext();
				context.currentFocusedSearchOption = 1;
				context.selectSearchOptionUI = jest.fn();
				context.previousSearchResult = prototype.previousSearchResult.bind(context);
				const mockEvent = {keyCode: 38, preventDefault: jest.fn()};
				prototype.handleKeyDown.call(context, mockEvent);
				expect(mockEvent.preventDefault).toHaveBeenCalled();
				expect(context.currentFocusedSearchOption).toBe(0);
			});

			it('handleKeyDown handles DOWN key', () =>
			{
				const context = createMockContext();
				context.currentFocusedSearchOption = 0;
				context.filteredSearchResults = [
					{},
					{}
				];
				context.selectSearchOptionUI = jest.fn();
				context.nextSearchResult = prototype.nextSearchResult.bind(context);
				const mockEvent = {keyCode: 40, preventDefault: jest.fn()};
				prototype.handleKeyDown.call(context, mockEvent);
				expect(mockEvent.preventDefault).toHaveBeenCalled();
				expect(context.currentFocusedSearchOption).toBe(1);
			});

			it('handleKeyDown ignores other keys', () =>
			{
				const context = createMockContext();
				context.hideResults = jest.fn();
				const mockEvent = {keyCode: 65, preventDefault: jest.fn()};
				prototype.handleKeyDown.call(context, mockEvent);
				expect(mockEvent.preventDefault).not.toHaveBeenCalled();
			});

			it('handleKeyChange debounces and dispatches event', () =>
			{
				jest.useFakeTimers();
				const context = createMockContext();
				context.showResults = jest.fn();
				context.hideResults = jest.fn();
				context.resetSearchOptionFocus = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				context.setSearchTimeoutFn = prototype.setSearchTimeoutFn.bind(context);
				const mockEvent = {target: {value: 'test'}};
				prototype.handleKeyChange.call(context, mockEvent);
				expect(context.isSearchLoading).toBe(true);
				jest.advanceTimersByTime(DEBOUNCE_DELAY);
				expect(context.searchTerm).toBe('test');
				expect(context.dispatchSearchTermChangedEvent).toHaveBeenCalled();
				jest.useRealTimers();
			});

			it('handleKeyChange hides results when search key is empty', () =>
			{
				jest.useFakeTimers();
				const context = createMockContext();
				context.hideResults = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				context.setSearchTimeoutFn = prototype.setSearchTimeoutFn.bind(context);
				const mockEvent = {target: {value: ''}};
				prototype.handleKeyChange.call(context, mockEvent);
				expect(context.hideResults).toHaveBeenCalled();
				jest.useRealTimers();
			});

			it('setSearchTimeoutFn sets timeout and updates searchTerm', () =>
			{
				jest.useFakeTimers();
				const context = createMockContext();
				context.resetSearchOptionFocus = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				prototype.setSearchTimeoutFn.call(context, 'delayed search');
				expect(context.delayTimeout).toBeDefined();
				jest.advanceTimersByTime(DEBOUNCE_DELAY);
				expect(context.searchTerm).toBe('delayed search');
				expect(context.dispatchSearchTermChangedEvent).toHaveBeenCalled();
				jest.useRealTimers();
			});
		});

		describe('event dispatching', () =>
		{
			it('publishValueSelectMessage publishes when messageContext is set', () =>
			{
				const context = createMockContext();
				context.messageContext = {wireAdapter: true};
				Object.defineProperty(context, 'valueSelectDetail', {get: () => ({selectedId: '001'})});
				prototype.publishValueSelectMessage.call(context);
				expect(context.publishLightningMessage).toHaveBeenCalledTimes(1);
				expect(context.publishLightningMessage.mock.calls[0][1]).toEqual({selectedId: '001'});
			});

			it('publishValueSelectMessage does not publish when messageContext is null', () =>
			{
				const context = createMockContext();
				context.messageContext = null;
				prototype.publishValueSelectMessage.call(context);
				expect(context.publishLightningMessage).not.toHaveBeenCalled();
			});

			it('dispatchValueSelectEvent dispatches valueSelectEvent', () =>
			{
				const context = createMockContext();
				const customEvent = new CustomEvent('valueselect', {detail: {selectedId: '001'}});
				Object.defineProperty(context, 'valueSelectEvent', {get: () => customEvent});
				prototype.dispatchValueSelectEvent.call(context);
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				expect(context.dispatchEvent).toHaveBeenCalledWith(customEvent);
			});

			it('dispatchSearchTermChangedEvent dispatches searchtermchanged event', () =>
			{
				const context = createMockContext();
				const customEvent = new CustomEvent('searchtermchanged', {detail: {searchTerm: 'test'}});
				Object.defineProperty(context, 'searchTermChangedEvent', {get: () => customEvent});
				prototype.dispatchSearchTermChangedEvent.call(context);
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				expect(context.dispatchEvent).toHaveBeenCalledWith(customEvent);
			});
		});

		describe('displaySearchOptions edge cases', () =>
		{
			it('displaySearchOptions returns empty when no records match the search term', () =>
			{
				const context = createMockContext();
				context.searchResults = [
					{Id: '001', Name: 'Acme Corp'}
				];
				context.searchTerm = 'zzzzz';
				context.record = null;
				context.displayFields = ['Name'];
				context.idField = 'Id';
				prepareSearchContext(context);
				bindDescriptor(context, 'hasRecords');
				const result = callGetter(context, 'displaySearchOptions');
				expect(result.length).toBe(0);
				expect(context.hasRecords).toBe(false);
			});

			it('displaySearchOptions returns every record when the search term is empty', () =>
			{
				const context = createMockContext();
				context.searchResults = [
					{Id: '001', Name: 'Test Account'}
				];
				context.searchTerm = '';
				context.record = null;
				context.displayFields = ['Name'];
				context.idField = 'Id';
				prepareSearchContext(context);
				bindDescriptor(context, 'hasRecords');
				const result = callGetter(context, 'displaySearchOptions');
				// With empty searchTerm, all items pass filter (includes('')===true)
				expect(result.length).toBe(1);
				expect(context.hasRecords).toBe(true);
			});

			it('displaySearchOptions treats records with null display field values as empty strings for matching', () =>
			{
				const context = createMockContext();
				context.searchResults = [
					{Id: '001', Name: null},
					{Id: '002', Name: 'Acme'}
				];
				context.searchTerm = 'acme';
				context.record = null;
				context.displayFields = ['Name'];
				context.idField = 'Id';
				prepareSearchContext(context);
				const result = callGetter(context, 'displaySearchOptions');
				expect(result).toHaveLength(1);
				expect(result[0].Id).toBe('002');
			});
		});

		describe('clearLookupUI edge cases', () =>
		{
			it('handles missing searchBoxWrapper gracefully', () =>
			{
				const context = createMockContext();
				context.template.querySelector = jest.fn(() => null);
				// Should not throw
				prototype.clearLookupUI.call(context);
				expect(context.isSearchLoading).toBe(false);
			});
		});

		describe('render-path purity', () =>
		{
			it('displaySearchOptions leaves focus, loading, and dropdown state untouched during render', () =>
			{
				const context = createMockContext();
				context.searchResults = [{Id: '001', Name: 'Acme'}];
				context.searchTerm = 'acme';
				context.record = null;
				context.currentFocusedSearchOption = 0;
				context.isSearchLoading = true;
				prepareSearchContext(context);
				const result = callGetter(context, 'displaySearchOptions');
				expect(result).toHaveLength(1);
				expect(context.currentFocusedSearchOption).toBe(0);
				expect(context.isSearchLoading).toBe(true);
				expect(context.showResults).not.toHaveBeenCalled();
				expect(context.selectSearchOptionUI).not.toHaveBeenCalled();
			});

			it('filteredSearchResults returns the raw matching records in display order', () =>
			{
				const context = createMockContext();
				const matchingRecord = {Id: '001', Name: 'Acme'};
				context.searchResults = [
					matchingRecord,
					{Id: '002', Name: 'Beta'}
				];
				context.searchTerm = 'ac';
				context.displayFields = ['Name'];
				const result = callGetter(context, 'filteredSearchResults');
				expect(result).toHaveLength(1);
				expect(result[0]).toBe(matchingRecord);
			});

			it('hasRecords reflects whether any option matches the search term', () =>
			{
				const context = createMockContext();
				context.searchResults = [{Id: '001', Name: 'Acme'}];
				context.displayFields = ['Name'];
				context.searchTerm = 'acme';
				bindDescriptor(context, 'filteredSearchResults');
				bindDescriptor(context, 'hasRecords');
				expect(context.hasRecords).toBe(true);
				context.searchTerm = 'zzzzz';
				expect(context.hasRecords).toBe(false);
			});
		});

		describe('search settlement side effects', () =>
		{
			const createSetterContext = () =>
			{
				const context = createMockContext();
				context.isSearchLoading = true;
				context.resetSearchOptionFocus = jest.fn();
				context.showResults = jest.fn();
				return context;
			};

			it('assigning searchResults settles the in-flight search and resets keyboard focus', () =>
			{
				const context = createSetterContext();
				callSetter(context, 'searchResults', [{Id: '001', Name: 'Acme'}]);
				expect(callGetter(context, 'searchResults')).toEqual([{Id: '001', Name: 'Acme'}]);
				expect(context.isSearchLoading).toBe(false);
				expect(context.resetSearchOptionFocus).toHaveBeenCalledTimes(1);
			});

			it('assigning searchResults coerces a null value to an empty list', () =>
			{
				const context = createSetterContext();
				callSetter(context, 'searchResults', null);
				expect(callGetter(context, 'searchResults')).toEqual([]);
			});

			it('assigning searchResults reopens the dropdown while a search term is active', () =>
			{
				const context = createSetterContext();
				context.searchTerm = 'acme';
				context.record = null;
				callSetter(context, 'searchResults', [{Id: '001', Name: 'Acme'}]);
				expect(context.showResults).toHaveBeenCalledTimes(1);
			});

			it('assigning searchResults keeps the dropdown closed when no search term is active', () =>
			{
				const context = createSetterContext();
				context.searchTerm = '';
				callSetter(context, 'searchResults', [{Id: '001', Name: 'Acme'}]);
				expect(context.showResults).not.toHaveBeenCalled();
			});

			it('assigning searchResults keeps the dropdown closed when a record is selected', () =>
			{
				const context = createSetterContext();
				context.searchTerm = 'acme';
				context.record = {Id: '001', Name: 'Acme'};
				callSetter(context, 'searchResults', [{Id: '001', Name: 'Acme'}]);
				expect(context.showResults).not.toHaveBeenCalled();
			});

			it('resetSearchOptionFocus returns focus to the no-focus sentinel and clears highlights', () =>
			{
				const context = createMockContext();
				context.currentFocusedSearchOption = 2;
				context.selectSearchOptionUI = jest.fn();
				prototype.resetSearchOptionFocus.call(context);
				expect(context.currentFocusedSearchOption).toBe(-1);
				expect(context.selectSearchOptionUI).toHaveBeenCalledTimes(1);
			});
		});

		describe('search input handling side effects', () =>
		{
			it('typing a search key opens the results dropdown from the input handler', () =>
			{
				const context = createMockContext();
				context.showResults = jest.fn();
				context.hideResults = jest.fn();
				context.setSearchTimeoutFn = jest.fn();
				prototype.handleKeyChange.call(context, {target: {value: 'acme'}});
				expect(context.showResults).toHaveBeenCalledTimes(1);
				expect(context.hideResults).not.toHaveBeenCalled();
				expect(context.isSearchLoading).toBe(true);
			});

			it('clearing the input stops the loading indicator and hides the dropdown', () =>
			{
				const context = createMockContext();
				context.isSearchLoading = true;
				context.showResults = jest.fn();
				context.hideResults = jest.fn();
				context.setSearchTimeoutFn = jest.fn();
				prototype.handleKeyChange.call(context, {target: {value: ''}});
				expect(context.isSearchLoading).toBe(false);
				expect(context.hideResults).toHaveBeenCalledTimes(1);
				expect(context.showResults).not.toHaveBeenCalled();
			});

			it('the debounce firing resets keyboard focus before dispatching the term change', () =>
			{
				jest.useFakeTimers();
				const context = createMockContext();
				context.resetSearchOptionFocus = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				prototype.setSearchTimeoutFn.call(context, 'acme');
				jest.advanceTimersByTime(DEBOUNCE_DELAY);
				expect(context.searchTerm).toBe('acme');
				expect(context.resetSearchOptionFocus).toHaveBeenCalledTimes(1);
				expect(context.dispatchSearchTermChangedEvent).toHaveBeenCalledTimes(1);
				jest.useRealTimers();
			});

			it('the debounce firing on an unchanged term settles the in-flight search itself', () =>
			{
				// A keystroke reverted within the debounce window re-applies the same term, so
				// nothing downstream re-runs the search and no results assignment ever arrives to
				// settle the loading flag. The debounce callback settles it directly.
				jest.useFakeTimers();
				const context = createMockContext();
				context.searchTerm = 'acme';
				context.isSearchLoading = true;
				context.resetSearchOptionFocus = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				prototype.setSearchTimeoutFn.call(context, 'acme');
				jest.advanceTimersByTime(DEBOUNCE_DELAY);
				expect(context.isSearchLoading).toBe(false);
				expect(context.searchTerm).toBe('acme');
				expect(context.dispatchSearchTermChangedEvent).toHaveBeenCalledTimes(1);
				jest.useRealTimers();
			});

			it('the debounce firing on a changed term leaves the search in flight for the results assignment to settle', () =>
			{
				jest.useFakeTimers();
				const context = createMockContext();
				context.searchTerm = 'acme';
				context.isSearchLoading = true;
				context.resetSearchOptionFocus = jest.fn();
				context.dispatchSearchTermChangedEvent = jest.fn();
				prototype.setSearchTimeoutFn.call(context, 'acmes');
				jest.advanceTimersByTime(DEBOUNCE_DELAY);
				expect(context.isSearchLoading).toBe(true);
				expect(context.searchTerm).toBe('acmes');
				jest.useRealTimers();
			});
		});

		describe('keyboard navigation over the filtered list', () =>
		{
			it('nextSearchResult stops at the last visible option', () =>
			{
				const context = createMockContext();
				context.currentFocusedSearchOption = 2;
				context.searchResults = [
					{},
					{},
					{}
				];
				context.filteredSearchResults = [
					{},
					{},
					{}
				];
				prototype.nextSearchResult.call(context);
				expect(context.currentFocusedSearchOption).toBe(2);
			});

			it('nextSearchResult walks the filtered list, not the full result set', () =>
			{
				const context = createMockContext();
				context.currentFocusedSearchOption = 0;
				context.searchResults = [
					{},
					{},
					{}
				];
				context.filteredSearchResults = [{}];
				prototype.nextSearchResult.call(context);
				expect(context.currentFocusedSearchOption).toBe(0);
			});

			it('Enter selects the focused option from the filtered list, not the full result set', () =>
			{
				const context = createMockContext();
				const filteredRecord = {Id: '002', Name: 'Beta'};
				context.searchResults = [
					{Id: '001', Name: 'Acme'},
					filteredRecord
				];
				context.filteredSearchResults = [filteredRecord];
				context.currentFocusedSearchOption = 0;
				context.handleSelectRecordHelper = jest.fn();
				context.dispatchValueSelectEvent = jest.fn();
				context.publishValueSelectMessage = jest.fn();
				bindDescriptor(context, 'selectedRecord');
				prototype.handleKeyDown.call(context, {keyCode: 13, preventDefault: jest.fn()});
				expect(context.record).toBe(filteredRecord);
			});
		});

		describe('record label generation', () =>
		{
			const createLabelContext = (displayFields, displayFieldFormat) =>
			{
				const context = createMockContext();
				context.displayFields = displayFields;
				Object.defineProperty(context, 'displayFieldFormat', {get: () => displayFieldFormat});
				return context;
			};

			it('renders empty text instead of the literal undefined for missing field values', () =>
			{
				const context = createLabelContext([
					'FirstName',
					'LastName'
				], 'FirstName LastName');
				const result = prototype.generateRecordLabel.call(context, {FirstName: 'John'});
				expect(result).toBe('John ');
			});

			it('renders empty text instead of the literal null for null field values', () =>
			{
				const context = createLabelContext([
					'FirstName',
					'LastName'
				], 'FirstName LastName');
				const result = prototype.generateRecordLabel.call(context, {FirstName: 'John', LastName: null});
				expect(result).toBe('John ');
			});

			it('resolves overlapping field-name tokens without corrupting each other', () =>
			{
				const context = createLabelContext([
					'Name',
					'FirstName'
				], 'FirstName (Name)');
				const result = prototype.generateRecordLabel.call(context, {FirstName: 'Ada', Name: 'Lovelace'});
				expect(result).toBe('Ada (Lovelace)');
			});

			it('never re-scans replaced values for other field tokens', () =>
			{
				const context = createLabelContext([
					'FirstName',
					'LastName'
				], 'FirstName LastName');
				const result = prototype.generateRecordLabel.call(context, {FirstName: 'LastName', LastName: 'Smith'});
				expect(result).toBe('LastName Smith');
			});

			it('keeps falsy-but-present field values', () =>
			{
				const context = createLabelContext(['Amount'], 'Amount');
				const result = prototype.generateRecordLabel.call(context, {Amount: 0});
				expect(result).toBe('0');
			});

			it('returns the format unchanged when no usable display fields are configured', () =>
			{
				const context = createLabelContext([' '], 'Static Label');
				const result = prototype.generateRecordLabel.call(context, {Name: 'Acme'});
				expect(result).toBe('Static Label');
			});

			it('treats regular-expression metacharacters in field names as literal text', () =>
			{
				const context = createLabelContext(['Amount(USD)'], 'Amount(USD)');
				const result = prototype.generateRecordLabel.call(context, {'Amount(USD)': 42});
				expect(result).toBe('42');
			});
		});

		describe('empty-state gating', () =>
		{
			const createEmptyStateContext = (isSearchLoading, filteredSearchResults) =>
			{
				const context = createMockContext();
				context.isSearchLoading = isSearchLoading;
				context.filteredSearchResults = filteredSearchResults;
				bindDescriptor(context, 'hasRecords');
				return context;
			};

			it('displayNoRecordsFound stays false while a search is in flight', () =>
			{
				const context = createEmptyStateContext(true, []);
				expect(callGetter(context, 'displayNoRecordsFound')).toBe(false);
			});

			it('displayNoRecordsFound is true once the search settles with no matches', () =>
			{
				const context = createEmptyStateContext(false, []);
				expect(callGetter(context, 'displayNoRecordsFound')).toBe(true);
			});

			it('displayNoRecordsFound is false when settled results match', () =>
			{
				const context = createEmptyStateContext(false, [{Id: '001'}]);
				expect(callGetter(context, 'displayNoRecordsFound')).toBe(false);
			});
		});

		describe('unrendered template safety', () =>
		{
			it('showResults and hideResults tolerate an unrendered template', () =>
			{
				const context = {template: {querySelector: jest.fn(() => null)}};
				bindDescriptor(context, 'lookupInputContainerClassList');
				expect(() => prototype.showResults.call(context)).not.toThrow();
				expect(() => prototype.hideResults.call(context)).not.toThrow();
			});
		});

		describe('debounce teardown', () =>
		{
			it('chains the framework teardown when disconnecting', () =>
			{
				const parentPrototype = Object.getPrototypeOf(prototype);
				const parentDisconnectedCallback = jest.fn();
				parentPrototype.disconnectedCallback = parentDisconnectedCallback;
				try
				{
					const context = {delayTimeout: 42};
					prototype.disconnectedCallback.call(context);
					expect(parentDisconnectedCallback).toHaveBeenCalledTimes(1);
				}
				finally
				{
					delete parentPrototype.disconnectedCallback;
				}
			});
		});

	});

	describe('class instantiation', () =>
	{
		afterEach(() =>
		{
			while(document.body.firstChild)
			{
				document.body.removeChild(document.body.firstChild);
			}
		});

		it('can be instantiated via createElement with default property values', () =>
		{
			const {createElement} = require('lwc');
			const LwcBaseLookup = require('c/baseLookup').default;
			const element = createElement('c-base-lookup', {is: LwcBaseLookup});
			document.body.appendChild(element);

			// Verify @api defaults are initialized (covers lines 23-88)
			expect(element.outerElementClasses).toBe('');
			expect(element.disableElement).toBe(false);
			expect(element.fieldLabelName).toBe('Name');
			expect(element.readOnly).toBe(false);
			expect(element.placeholder).toBe('Search');
			expect(element.displayFields).toEqual(['Name']);
			expect(element.isRequired).toBe(false);
			expect(element.idField).toBe('Id');
			expect(element.searchOptions).toEqual([]);
		});

		it('initializes instance with all class field declarations', () =>
		{
			const {createElement} = require('lwc');
			const LwcBaseLookup = require('c/baseLookup').default;
			const element = createElement('c-base-lookup', {is: LwcBaseLookup});
			document.body.appendChild(element);

			// Verify instance is fully initialized (covers class field declarations)
			expect(element).toBeTruthy();
			expect(element.iconName).toBeUndefined();
			expect(element.elementName).toBeUndefined();
		});

		it('reactively seeds the results dropdown when searchOptions is assigned after mount', () =>
		{
			const {createElement} = require('lwc');
			const LwcBaseLookup = require('c/baseLookup').default;
			const element = createElement('c-base-lookup', {is: LwcBaseLookup});
			document.body.appendChild(element);

			element.searchOptions = [
				{Id: '001', Name: 'Alpha'},
				{Id: '002', Name: 'Beta'}
			];

			expect(element.searchOptions).toEqual([
				{Id: '001', Name: 'Alpha'},
				{Id: '002', Name: 'Beta'}
			]);
			return Promise.resolve().then(() =>
			{
				const options = element.shadowRoot.querySelectorAll('.search-options');
				expect(options).toHaveLength(2);
			});
		});

		it('coerces a null searchOptions assignment to an empty results list', () =>
		{
			const {createElement} = require('lwc');
			const LwcBaseLookup = require('c/baseLookup').default;
			const element = createElement('c-base-lookup', {is: LwcBaseLookup});
			document.body.appendChild(element);

			element.searchOptions = null;

			expect(element.searchOptions).toEqual([]);
		});
	});

	describe('search lifecycle (DOM)', () =>
	{
		afterEach(() =>
		{
			jest.useRealTimers();
			while(document.body.firstChild)
			{
				document.body.removeChild(document.body.firstChild);
			}
		});

		const mountLookup = () =>
		{
			const {createElement} = require('lwc');
			const LwcBaseLookup = require('c/baseLookup').default;
			const element = createElement('c-base-lookup', {is: LwcBaseLookup});
			document.body.appendChild(element);
			return element;
		};

		const typeSearchKey = (element, value) =>
		{
			const input = element.shadowRoot.querySelector('lightning-input');
			input.value = value;
			input.dispatchEvent(new CustomEvent('change'));
		};

		it('hides the No Records empty state while a search is in flight and shows it once the search settles', async() =>
		{
			jest.useFakeTimers();
			const element = mountLookup();
			expect(element.shadowRoot.querySelector('.no-records-found')).not.toBeNull();

			typeSearchKey(element, 'acme');
			await Promise.resolve();
			expect(element.shadowRoot.querySelector('.no-records-found')).toBeNull();

			jest.advanceTimersByTime(DEBOUNCE_DELAY);
			await Promise.resolve();
			expect(element.shadowRoot.querySelector('.no-records-found')).toBeNull();

			element.searchOptions = [];
			await Promise.resolve();
			expect(element.shadowRoot.querySelector('.no-records-found')).not.toBeNull();
		});

		it('opens the results dropdown as soon as a search key is typed', async() =>
		{
			jest.useFakeTimers();
			const element = mountLookup();

			typeSearchKey(element, 'acme');
			await Promise.resolve();

			const container = element.shadowRoot.querySelector('.lookupInputContainer');
			expect(container.classList.contains('slds-is-open')).toBe(true);
		});

		it('settles the spinner and re-shows the empty state when a debounced edit lands back on the already-applied term', async() =>
		{
			// Type-then-revert inside the debounce window: the callback re-applies the same
			// term, so a reactive-parameter search never re-fires and no results assignment
			// arrives. The debounce itself must settle the search, or the spinner sticks on
			// and the empty state the user was just seeing never returns.
			jest.useFakeTimers();
			const element = mountLookup();

			typeSearchKey(element, 'acme');
			jest.advanceTimersByTime(DEBOUNCE_DELAY);
			element.searchOptions = [];
			await Promise.resolve();
			expect(element.shadowRoot.querySelector('.no-records-found')).not.toBeNull();

			typeSearchKey(element, 'acmes');
			await Promise.resolve();
			expect(element.shadowRoot.querySelector('.no-records-found')).toBeNull();

			typeSearchKey(element, 'acme');
			jest.advanceTimersByTime(DEBOUNCE_DELAY);
			await Promise.resolve();

			expect(element.shadowRoot.querySelector('lightning-input').isLoading).toBe(false);
			expect(element.shadowRoot.querySelector('.no-records-found')).not.toBeNull();
		});

		it('clears the pending debounce search when the component is disconnected', () =>
		{
			jest.useFakeTimers();
			const element = mountLookup();
			const searchTermChangedHandler = jest.fn();
			element.addEventListener('searchtermchanged', searchTermChangedHandler);

			typeSearchKey(element, 'acme');
			document.body.removeChild(element);
			jest.advanceTimersByTime(DEBOUNCE_DELAY);

			expect(searchTermChangedHandler).not.toHaveBeenCalled();
		});
	});
});
