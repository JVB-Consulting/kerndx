// SPDX-License-Identifier: BUSL-1.1
/**
 * @description LWC component that performs record searches using a configurable
 * controller implementing the IF_Search interface. Extends BaseLookup with
 * Apex-driven search, preselection support, and customizable result extraction.
 *
 * @author Jason van Beukering
 *
 * @date October 2022, February 2026
 */
import executeSearchController from '@salesforce/apex/CTRL_ExecuteSearch.executeSearchController';
import BaseLookup, {DELAY} from 'c/baseLookup';
import {setPropertyOnObject} from 'c/utilitySystem';
import utilityLogger from 'c/utilityLogger';
import {api} from 'lwc';

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Parses a semicolon-delimited parameter string into a key-value object.
 *
 * @param {string} paramString - Semicolon-separated key=value pairs
 *   (e.g. "objectName=Foobar__c;maximumNumberOfResults=10").
 * @returns {Object} Parsed parameters as a plain object.
 */
function parseSearchParameters(paramString)
{
	return Object.fromEntries(paramString.split(';').map((pair) => pair.split('=')));
}

/**
 * @description Resolves which controller function to use for the search call.
 * Returns the Apex controller when a controller name is provided,
 * otherwise falls back to the component's custom callController function.
 *
 * @param {string} controllerName - The Apex controller name, if any.
 * @param {Function} fallbackController - The custom controller function.
 * @returns {Function} The resolved controller function.
 */
function resolveSearchController(controllerName, fallbackController)
{
	return controllerName ? executeSearchController : fallbackController;
}

// ── Component ────────────────────────────────────────────────────────────

export default class SearchLookup extends BaseLookup
{
	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Controller name. Pass in the name of a controller that implements the IF_Search interface.
	 * @type {string}
	 */
	@api controllerName;

	/**
	 * @description Search params that can be passed in format e.g. -
	 * @example
	 * objectName=Foobar__c;recordId=0018K000008Z3A1QAK;maximumNumberOfResults=10
	 */
	@api controllerSearchParameters;
	/** @description Cached preselected record reference. */
	preselected;

	@api get name()
	{
		return this.elementName;
	}

	set name(value)
	{
		this.elementName = value;
	}

	@api get fieldLabel()
	{
		return this.fieldLabelName;
	}

	set fieldLabel(value)
	{
		this.fieldLabelName = value;
	}

	@api get resultUniqueId()
	{
		return this.idField;
	}

	//noinspection JSUnusedGlobalSymbols
	set resultUniqueId(value)
	{
		this.idField = value;
	}

	@api get addedElementClass()
	{
		return this.outerElementClasses;
	}

	//noinspection JSUnusedGlobalSymbols
	set addedElementClass(value)
	{
		this.outerElementClasses = value;
	}

	//noinspection JSUnusedGlobalSymbols
	get preselectedRecord()
	{
		return this.preselected;
	}

	@api set preselectedRecord(value)
	{
		if(this.getResultIdentifier(this.preselected) !== this.getResultIdentifier(value))
		{
			this.preselected = value;
			this.selectedRecord = value;
		}
	}

	/** @description Returns the selected record, falling back to the preselected record. */
	get selectedRecord()
	{
		return super.selectedRecord || this.preselected;
	}

	set selectedRecord(value)
	{
		setPropertyOnObject(this.valueSelectEventParams, 'selectedOption', value);
		super.selectedRecord = value;
	}

	// ── Internal State ───────────────────────────────────────────────────

	/**
	 * @description Default controller function used when no controllerName is provided.
	 *
	 * @returns {Promise<Array>} Resolves to an empty array.
	 */
	@api callController = () => new Promise((resolve) =>
	{
		utilityLogger.info('No controller passed in.');
		resolve([]);
	});

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Default result extraction function. Returns the response list unchanged.
	 *
	 * @param {Array} responseList - Raw results from the controller.
	 * @returns {Array} Extracted results.
	 */
	@api extractResults = (responseList = []) =>
	{
		utilityLogger.info('No list extraction passed in.');
		return responseList;
	};

	@api clearLookup()
	{
		this.preselected = null;
		super.clearLookup();
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Returns the inherited template for rendering.
	 */
	render()
	{
		return this.templateHTML;
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Executes the search by resolving the controller, parsing parameters,
	 * and delegating to callControllerMethod.
	 *
	 * @returns {Promise} Resolves when search results have been applied.
	 */
	getResults()
	{
		this.isSearchLoading = true;

		const searchParameters = parseSearchParameters(this.controllerSearchParameters);
		const resolvedController = resolveSearchController(this.controllerName, this.callController);

		return this.callControllerMethod(resolvedController, {controllerName: this.controllerName, searchTerm: this.searchTerm, searchParameters})
		.then((results) =>
		{
			this.searchResults = this.extractResults(results);
			this.isSearchLoading = false;
		});
	}

	/**
	 * @description Debounces the search input and triggers getResults after the configured delay.
	 *
	 * @param {string} searchKey - The current search input value.
	 */
	setSearchTimeoutFn(searchKey)
	{
		// eslint-disable-next-line @lwc/lwc/no-async-operation
		this.delayTimeout = setTimeout(async() =>
		{
			this.searchTerm = searchKey;
			this.dispatchSearchTermChangedEvent();
			if(this.searchTerm)
			{
				await this.getResults();
			}
		}, DELAY);
	}
}