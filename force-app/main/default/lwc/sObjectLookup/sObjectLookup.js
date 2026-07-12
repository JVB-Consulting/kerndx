// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Lookup element that can search for any SObject by specified field name.
 * Extends `BaseLookup` with SObject-specific features: object metadata fetching via
 * `getObjectInfo`, Apex-backed search via `CTRL_Search`, default record lookup by ID,
 * and automatic icon generation from object metadata.
 *
 * @author Jason van Beukering
 *
 * @date October 2022, July 2026
 */
import search from '@salesforce/apex/CTRL_Search.search';
import BaseLookup from 'c/baseLookup';
import {getObjectInfo} from 'lightning/uiObjectInfoApi';
import {api, wire} from 'lwc';

export default class SObjectLookup extends BaseLookup
{
	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description SObject API Name
	 * @type {string}
	 */
	@api objectApiName;

	// ── Internal State ───────────────────────────────────────────────────

	/** @description Object metadata returned by the getObjectInfo wire adapter. */
	objectInfo;

	// ── Computed Properties ──────────────────────────────────────────────

	/** @description Parameters for the SObject search wire adapter. */
	get searchSObjectsParams()
	{
		return {selectFields: this.displayFields, objectName: this.objectApiName};
	}

	/** @description Parameters for the record-by-ID fetch wire adapter. */
	get fetchRecordByIdParams()
	{
		return {recordId: this.recordId, selectFields: this.displayFields};
	}

	/**
	 * @description Resolves the SLDS icon for the lookup results. Custom objects use the
	 * explicitly set `iconName` (or empty string); standard objects derive the icon from
	 * the object API name (e.g., `standard:account`). While the object API name has not
	 * been provided yet, resolves to an empty string so rendering never throws.
	 * @returns {string}
	 */
	get icon()
	{
		const isCustomObject = this.objectInfo?.custom;
		if(isCustomObject)
		{
			return this.iconName || '';
		}

		const standardIconName = this.objectApiName?.toLowerCase();
		return standardIconName ? `standard:${standardIconName}` : '';
	}

	// ── Rendering ────────────────────────────────────────────────────────

	render()
	{
		return this.templateHTML;
	}

	// ── Wire Adapters ────────────────────────────────────────────────────

	@wire(getObjectInfo, {objectApiName: '$objectApiName'}) fetchObjectInfo(result)
	{
		this.objectInfo = this.handleWireResponse(result);
	}

	@wire(search, {searchTerm: '$searchTerm', searchParameters: '$searchSObjectsParams'}) fetchRecords(result)
	{
		this.searchResults = this.handleWireResponse(result) || [];
		this.isSearchLoading = false;
	}

	/**
	 * @description Wires the default record lookup. When a response arrives and the
	 * record differs from the currently selected one, updates the selection.
	 * @param {Object} result - Wire adapter result
	 */
	@wire(search, {searchTerm: '', searchParameters: '$fetchRecordByIdParams'}) findDefaultRecordById(result)
	{
		const response = this.handleWireResponse(result);
		if(!response)
		{
			return;
		}

		const isNewRecord = !this.selectedRecord || this.selectedRecord.Id !== response.Id;
		if(isNewRecord)
		{
			this.selectedRecord = response;
		}
	}
}