// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base class for custom lookup components. Provides search term debouncing,
 * keyboard navigation, result filtering/display, selected record management, message
 * channel integration, and display format customization. Extend this class and wire
 * search results to build SObject-specific or DTO-based lookups.
 *
 * @author Jason van Beukering
 *
 * @date September 2022, June 2026
 */
import Component from '@salesforce/messageChannel/Component__c';
import {ComponentBuilder} from 'c/componentBuilder';
import {api} from 'lwc';
import lookupTemplate from './baseLookup.html';

// ── Constants ────────────────────────────────────────────────────────────

/**
 * @description The delay in milliseconds used when debouncing event handlers before invoking Apex.
 */
export const DELAY = 300;

/**
 * @description Sentinel value indicating no search option is currently focused.
 * @type {number}
 */
const NO_FOCUSED_OPTION = -1;

const ENTER_KEY = 13;
const UP_KEY = 38;
const DOWN_KEY = 40;
const ESCAPE_KEY = 27;

/**
 * @description Map-based keyboard dispatch table. Each entry maps a key code to a handler
 * function receiving the component context and the keyboard event.
 * @type {Map<number, Function>}
 */
const KEY_HANDLERS = new Map([
	[
		ESCAPE_KEY,
		(context, event) =>
		{
			event.preventDefault();
			context.hideResults();
		}
	],
	[
		ENTER_KEY,
		(context, event) =>
		{
			event.preventDefault();
			context.selectedRecord = context.searchResults[context.currentFocusedSearchOption];
		}
	],
	[
		UP_KEY,
		(context, event) =>
		{
			event.preventDefault();
			context.previousSearchResult();
			context.selectSearchOptionUI();
		}
	],
	[
		DOWN_KEY,
		(context, event) =>
		{
			event.preventDefault();
			context.nextSearchResult();
			context.selectSearchOptionUI();
		}
	]
]);

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Toggles the visibility of a DOM element located by selector, using
 * the SLDS `slds-show`/`slds-hide` class pair.
 * @param {Object} template - The LWC template reference
 * @param {string} selector - CSS selector to locate the element
 * @param {boolean} show - Whether the element should be visible
 */
function toggleElementVisibility(template, selector, show)
{
	const element = template.querySelector(selector);
	if(element)
	{
		element.classList.remove(show ? 'slds-hide' : 'slds-show');
		element.classList.add(show ? 'slds-show' : 'slds-hide');
	}
}

// ── Component ────────────────────────────────────────────────────────────

export default class BaseLookup extends ComponentBuilder('controller', 'lightning-message')
{
	// ── @api Properties ──────────────────────────────────────────────────

	@api outerElementClasses = '';

	/**
	 * @description Disable text input
	 * @type {boolean}
	 */
	@api disableElement = false;

	/**
	 * @description Custom Name given to the lookup element
	 * @type {string}
	 */
	@api elementName;

	/**
	 * @description Provide a custom label that overrides the default field Label
	 */
	@api fieldLabelName = 'Name';

	/**
	 * @description Is lookup element read-only
	 * @type {boolean}
	 */
	@api readOnly = false;

	/**
	 * @description Provide a custom placeholder text for lookup search
	 * @type {string}
	 */
	@api placeholder = 'Search';

	/**
	 * @description List of field API names e.g. ['FirstName','LastName'] to display
	 * @type {string[]}
	 */
	@api displayFields = ['Name'];

	/**
	 * @description Format for lookup item display e.g. 'Mr. LastName'
	 * @type {string}
	 */
	@api displayFormat;

	/**
	 * @description SLDS Icon name for result items
	 * @type {string} slds-icon name
	 * @see https://www.lightningdesignsystem.com/icons/
	 */
	@api iconName;

	/**
	 * @description Is element value required
	 * @type {boolean}
	 */
	@api isRequired = false;

	/**
	 * @description Unique identifier for the passed in objects
	 * @type {string}
	 */
	@api idField = 'Id';
	templateHTML = lookupTemplate;
	searchResults = [];
	searchTerm = '';

	// ── Internal State ───────────────────────────────────────────────────
	isSearchLoading = false;
	hasRecords = false;
	record;
	preselectedRecordId;
	delayTimeout;
	currentFocusedSearchOption = NO_FOCUSED_OPTION;
	valueSelectEventParams = {};

	_searchOptions = [];

	/**
	 * @description Options to pre-populate the results list with. Assigning this reactively
	 * (re)seeds the displayed results, so a consumer that supplies the list asynchronously —
	 * for example after an awaited Apex call in its own connectedCallback, by which point this
	 * component has already mounted — still gets a populated, searchable dropdown. The one-shot
	 * seed in connectedCallback covers the case where the list is already present at mount.
	 * @type {[]}
	 */
	@api get searchOptions()
	{
		return this._searchOptions;
	}

	set searchOptions(value)
	{
		this._searchOptions = value || [];
		this.searchResults = [...this._searchOptions];
	}

	// ── Computed Properties ──────────────────────────────────────────────

	get defaultRecordId()
	{
		return this.preselectedRecordId;
	}

	/**
	 * @description Record Id passed in to preselect lookup field
	 */
	set defaultRecordId(value)
	{
		this.preselectedRecordId = value || null;
	}

	get fieldLabelClass()
	{
		return this.isRequired ? 'slds-form-element__label required-field' : 'slds-form-element__label';
	}

	get elementClass()
	{
		return `slds-form-element slds-combobox_container slds-has-selection slds-color__background_gray-1 ${this.outerElementClasses}`.trim();
	}

	/**
	 * @see findDefaultRecordById
	 * @returns {string} SObject record Id
	 */
	get recordId()
	{
		return this.getResultIdentifier(this.selectedRecord) || this.defaultRecordId;
	}

	get icon()
	{
		return this.iconName || '';
	}

	get pillLabel()
	{
		return this.selectedRecord ? this.generateRecordLabel(this.selectedRecord) : '';
	}

	get displayFieldFormat()
	{
		return this.displayFormat || this.displayFields[0];
	}

	get lookupInputContainerClassList()
	{
		return this.template.querySelector('.lookupInputContainer').classList;
	}

	get displaySearchOptions()
	{
		this.currentFocusedSearchOption = NO_FOCUSED_OPTION;
		let searchOptions = this.searchResults
		.map(item =>
		{
			let option = {...item};
			option.label = this.generateRecordLabel(option);
			option.resultIdentifier = this.getResultIdentifier(option);
			return option;
		})
		.filter(item => this.displayFields.some(displayField => (item[displayField] || '').toLowerCase().includes(this.searchTerm.toLowerCase())));

		this.isSearchLoading = !!this.searchTerm && (searchOptions.length === 0);
		this.hasRecords = searchOptions.length > 0;
		if(this.searchTerm && !this.record)
		{
			this.showResults();
			this.selectSearchOptionUI();
		}
		return searchOptions;
	}

	get selectedRecord()
	{
		return this.record;
	}

	set selectedRecord(value)
	{
		this.record = value;
		if(this.record)
		{
			this.handleSelectRecordHelper();
		}
		else
		{
			this.defaultRecordId = null;
			this.clearLookupUI();
			this.dispatchSearchTermChangedEvent();
		}

		this.dispatchValueSelectEvent();
		this.publishValueSelectMessage();
	}

	/**
	 * @event BaseLookup#searchtermchanged Event containing the current search term and lookup component's name
	 * @property {{searchTerm, elementName}} detail
	 */
	get searchTermChangedEvent()
	{
		return new CustomEvent('searchtermchanged', {detail: {searchTerm: this.searchTerm, elementName: this.elementName}});
	}

	get valueSelectDetail()
	{
		return {
			selectedId: this.getResultIdentifier(this.record), ...this.valueSelectEventParams, elementName: this.elementName, isRequired: this.isRequired
		};
	}

	/**
	 * @event BaseLookup#valueselect Event containing the selected lookup Id, field api name, component name, and all params inside 'valueSelectEventParams'
	 */
	get valueSelectEvent()
	{
		return new CustomEvent('valueselect', {
			detail: this.valueSelectDetail
		});
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	connectedCallback()
	{
		if(this.searchOptions.length > 0)
		{
			this.searchResults = [...this.searchOptions];
		}
	}

	// ── Record Label ─────────────────────────────────────────────────────

	/**
	 * @description Generates display label for a search result by replacing field name
	 * tokens in the display format with actual record values.
	 * @param record
	 * @returns {string}
	 */
	generateRecordLabel(record)
	{
		return this.displayFields.reduce((label, originalField) =>
		{
			const field = originalField.trim();
			return label.replace(field, record[field]);
		}, this.displayFieldFormat);
	}

	// ── Results Visibility ───────────────────────────────────────────────

	showResults()
	{
		const classList = this.lookupInputContainerClassList;
		classList.add('slds-is-open');
	}

	hideResults()
	{
		const classList = this.lookupInputContainerClassList;
		classList.remove('slds-is-open');
	}

	// ── Lookup Clearing ──────────────────────────────────────────────────

	@api clearLookup()
	{
		this.searchTerm = '';
		this.selectedRecord = undefined;
	}

	clearLookupUI()
	{
		this.isSearchLoading = false;
		toggleElementVisibility(this.template, '.searchBoxWrapper', true);
		toggleElementVisibility(this.template, '.pillDiv', false);
	}

	// ── Record Selection ─────────────────────────────────────────────────

	handleSelectedRecord({currentTarget})
	{
		const objId = currentTarget.getAttribute('data-recid');
		this.selectedRecord = this.searchResults.find(option => String(this.getResultIdentifier(option)) === objId);
	}

	nextSearchResult()
	{
		if(this.currentFocusedSearchOption < this.searchResults.length)
		{
			this.currentFocusedSearchOption += 1;
		}
	}

	previousSearchResult()
	{
		if(this.currentFocusedSearchOption > 0)
		{
			this.currentFocusedSearchOption -= 1;
		}
	}

	selectSearchOptionUI()
	{
		const searchOptions = this.template.querySelectorAll('.search-options');
		searchOptions.forEach((element, index) =>
		{
			element.classList.remove('search-option-selected');
			if(this.currentFocusedSearchOption === index)
			{
				element.classList.add('search-option-selected');
			}
		});
	}

	/**
	 * @description Retrieves identifier field of a search result
	 * @param result Search result. Can be SObject or DTO
	 * @returns {string}
	 */
	getResultIdentifier(result)
	{
		return result && (result[this.idField] || result.Id);
	}

	/**
	 * @description Updates DOM to show the selected record pill and hide the search input.
	 */
	handleSelectRecordHelper()
	{
		this.template.querySelector('.lookupInputContainer').classList.remove('slds-is-open');
		toggleElementVisibility(this.template, '.searchBoxWrapper', false);
		toggleElementVisibility(this.template, '.pillDiv', true);
	}

	// ── Keyboard Handling ────────────────────────────────────────────────

	handleKeyDown(event)
	{
		const handler = KEY_HANDLERS.get(event.keyCode);
		if(handler)
		{
			handler(this, event);
		}
	}

	/**
	 * @description Handles key presses from within search bar.
	 * @param event
	 * @see https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.apex_wire_method for SF recommended de-bounce
	 */
	handleKeyChange(event)
	{
		// Debouncing this method: Do not update the reactive property as long as this function is
		// being called within a delay of DELAY. This is to avoid a very large number of Apex method calls.
		this.isSearchLoading = true;
		clearTimeout(this.delayTimeout);
		const searchKey = event.target.value;
		this.setSearchTimeoutFn(searchKey);
		if(!searchKey)
		{
			this.hideResults();
		}
	}

	// ── Event Dispatching ────────────────────────────────────────────────

	/**
	 * @description Dispatches an event when the user selects a lookup value.
	 * Declared as a prototype method (not an arrow class field) so Jest can spy on and
	 * invoke it directly via the prototype without needing a live component instance.
	 * @fires BaseLookup#valueselect
	 */
	dispatchValueSelectEvent()
	{
		this.dispatchEvent(this.valueSelectEvent);
	}

	/**
	 * @description Publishes a message when the user selects a lookup value.
	 * See `dispatchValueSelectEvent` for why this is a prototype method.
	 * @fires BaseLookup#valueselect
	 */
	publishValueSelectMessage()
	{
		if(this.messageContext)
		{
			this.publishLightningMessage(Component, this.valueSelectDetail);
		}
	}

	/**
	 * @description Dispatches an event when the current search term changes.
	 * See `dispatchValueSelectEvent` for why this is a prototype method.
	 * @fires BaseLookup#searchtermchanged
	 */
	dispatchSearchTermChangedEvent()
	{
		this.dispatchEvent(this.searchTermChangedEvent);
	}

	setSearchTimeoutFn(searchKey)
	{
		// eslint-disable-next-line @lwc/lwc/no-async-operation
		this.delayTimeout = setTimeout(() =>
		{
			this.searchTerm = searchKey;
			this.dispatchSearchTermChangedEvent();
		}, DELAY);
	}
}