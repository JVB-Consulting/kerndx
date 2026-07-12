// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base class for custom lookup components. Provides search term debouncing,
 * keyboard navigation, result filtering/display, selected record management, message
 * channel integration, and display format customization. Extend this class and wire
 * search results to build SObject-specific or DTO-based lookups.
 *
 * @author Jason van Beukering
 *
 * @date September 2022, July 2026
 */
import NO_RECORDS_FOUND from '@salesforce/label/c.BaseLookup_NoRecordsFound';
import REMOVE_SELECTED_OPTION from '@salesforce/label/c.BaseLookup_RemoveSelectedOption';
import SEARCH_PLACEHOLDER from '@salesforce/label/c.BaseLookup_SearchPlaceholder';
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
 * @description Matches regular-expression metacharacters so display field names can be
 * escaped before being compiled into the display-format token pattern.
 * @type {RegExp}
 */
const REGULAR_EXPRESSION_METACHARACTERS = /[.*+?^${}()|[\]\\]/g;

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
			context.selectedRecord = context.filteredSearchResults[context.currentFocusedSearchOption];
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
	@api placeholder = SEARCH_PLACEHOLDER;

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
	searchTerm = '';

	// ── Internal State ───────────────────────────────────────────────────
	isSearchLoading = false;
	record;
	preselectedRecordId;
	delayTimeout;
	currentFocusedSearchOption = NO_FOCUSED_OPTION;
	valueSelectEventParams = {};

	/** @description Template-bound Custom Labels for the empty state and pill-clear button. */
	labels = {
		noRecordsFound: NO_RECORDS_FOUND, removeSelectedOption: REMOVE_SELECTED_OPTION
	};

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

	_searchResults = [];

	get searchResults()
	{
		return this._searchResults;
	}

	/**
	 * @description Search results backing the dropdown. Assigning results marks the
	 * in-flight search as settled, resets keyboard focus, and reopens the dropdown when a
	 * search term is active without a selection. Subclasses and parents settle a search by
	 * assigning results here, either directly or through `searchOptions`.
	 */
	set searchResults(value)
	{
		this._searchResults = value || [];
		this.isSearchLoading = false;
		this.resetSearchOptionFocus();
		if(this.searchTerm && !this.record)
		{
			this.showResults();
		}
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
		return this.template.querySelector('.lookupInputContainer')?.classList;
	}

	/**
	 * @description Raw search results that match the current search term across the
	 * configured display fields, in the order the dropdown renders them. Keyboard
	 * navigation and Enter selection index into this list so they always track what
	 * is visible.
	 * @returns {[]}
	 */
	get filteredSearchResults()
	{
		return this.searchResults.filter(item => this.displayFields.some(displayField => (item[displayField] || '').toLowerCase().includes(this.searchTerm.toLowerCase())));
	}

	/**
	 * @description Pure render-path projection of the filtered results, decorated with
	 * the generated display label and result identifier. Performs no state mutation and
	 * no DOM work; the dropdown-open and focus-reset side effects live in the input
	 * handlers and the `searchResults` setter.
	 * @returns {[]}
	 */
	get displaySearchOptions()
	{
		return this.filteredSearchResults.map(item =>
		{
			let option = {...item};
			option.label = this.generateRecordLabel(option);
			option.resultIdentifier = this.getResultIdentifier(option);
			return option;
		});
	}

	get hasRecords()
	{
		return this.filteredSearchResults.length > 0;
	}

	/**
	 * @description Whether the 'No Records Found' empty state should render. Gated on the
	 * search being settled, so the empty state stays hidden while a search is in flight.
	 * @returns {boolean}
	 */
	get displayNoRecordsFound()
	{
		return !this.isSearchLoading && !this.hasRecords;
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

	/**
	 * @description Clears the pending debounce timer so a torn-down instance cannot run
	 * the delayed search callback, then chains to the framework teardown.
	 */
	disconnectedCallback()
	{
		super.disconnectedCallback?.();
		clearTimeout(this.delayTimeout);
	}

	// ── Record Label ─────────────────────────────────────────────────────

	/**
	 * @description Generates the display label for a search result by replacing field
	 * name tokens in the display format with the record's values. Tokens are matched
	 * longest-first in a single pass, so overlapping field names (e.g. `FirstName` and
	 * `Name`) cannot corrupt each other and replaced values are never re-scanned.
	 * Missing values render as empty text rather than the literal 'undefined'.
	 * @param record
	 * @returns {string}
	 */
	generateRecordLabel(record)
	{
		const fieldTokens = this.displayFields
		.map(displayField => displayField.trim())
		.filter(displayField => displayField.length > 0)
		.sort((firstField, secondField) => secondField.length - firstField.length)
		.map(displayField => displayField.replace(REGULAR_EXPRESSION_METACHARACTERS, '\\$&'));

		if(fieldTokens.length === 0)
		{
			return this.displayFieldFormat;
		}

		const fieldTokenPattern = new RegExp(fieldTokens.join('|'), 'g');
		return this.displayFieldFormat.replace(fieldTokenPattern, fieldToken => record[fieldToken] ?? '');
	}

	// ── Results Visibility ───────────────────────────────────────────────

	showResults()
	{
		this.lookupInputContainerClassList?.add('slds-is-open');
	}

	hideResults()
	{
		this.lookupInputContainerClassList?.remove('slds-is-open');
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
		if(this.currentFocusedSearchOption < this.filteredSearchResults.length - 1)
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

	/**
	 * @description Returns keyboard focus to the no-focus sentinel and clears any focus
	 * highlight from the rendered options.
	 */
	resetSearchOptionFocus()
	{
		this.currentFocusedSearchOption = NO_FOCUSED_OPTION;
		this.selectSearchOptionUI();
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
		clearTimeout(this.delayTimeout);
		const searchKey = event.target.value;
		this.isSearchLoading = !!searchKey;
		this.setSearchTimeoutFn(searchKey);
		if(searchKey)
		{
			this.showResults();
		}
		else
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

	/**
	 * @description Debounces applying the typed search key to the search term. When the
	 * debounced key matches the already-applied term (for example a keystroke reverted
	 * within the debounce window), reassigning the term is a no-op for reactive search
	 * parameters, so no results assignment ever arrives to settle the in-flight flag;
	 * the callback settles it here instead. Subclasses that search imperatively raise
	 * and settle the flag themselves around their own search call.
	 * @param {string} searchKey - The current search input value.
	 */
	setSearchTimeoutFn(searchKey)
	{
		// eslint-disable-next-line @lwc/lwc/no-async-operation
		this.delayTimeout = setTimeout(() =>
		{
			if(this.searchTerm === searchKey)
			{
				this.isSearchLoading = false;
			}

			this.searchTerm = searchKey;
			this.resetSearchOptionFocus();
			this.dispatchSearchTermChangedEvent();
		}, DELAY);
	}
}