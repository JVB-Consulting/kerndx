// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Common component to display desired fields of a record. Takes in the Record Id, and uses FieldSetGroup__mdt configuration
 * to determine grouping of different sections (uses an accordion per section), and which section(s) are active by default.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, May 2026
 */
import getFieldSetByDeveloperName from '@salesforce/apex/CTRL_FieldSet.findByDeveloperName';
import getDefaultActiveSectionsField from '@salesforce/apex/CTRL_FieldSet.getDefaultActiveSectionsField';
import getFieldSetApiNamesField from '@salesforce/apex/CTRL_FieldSet.getFieldSetApiNamesField';
import getFieldSetsForRecord from '@salesforce/apex/CTRL_FieldSet.getFieldSetsForRecord';
import getObjectNameFromId from '@salesforce/apex/CTRL_FieldSet.getObjectNameFromId';
import {ComponentBuilder} from 'c/componentBuilder';
import {api, wire} from 'lwc';

/**
 * @description Splits a comma-separated field value from a metadata record into a
 * trimmed string array. Returns an empty array when the descriptor is falsy.
 * @param {Object} fieldSetGroup - The metadata record containing field values
 * @param {Object} fieldDescriptor - Descriptor with `fieldApiName` pointing to the field
 * @returns {string[]} Array of trimmed values
 */
function extractCommaSeparated(fieldSetGroup, fieldDescriptor)
{
	return fieldDescriptor ? fieldSetGroup[fieldDescriptor.fieldApiName].split(',') : [];
}

export default class ViewRecord extends ComponentBuilder('controller')
{
	// ── @api Properties ──────────────────────────────────────────────────

	/** @description The record Id to display. */
	@api recordId;

	/** @description The developer name of the FieldSetGroup__mdt record. */
	@api fieldSetDeveloperName;

	// ── Internal State ───────────────────────────────────────────────────

	/** @description The API name of the SObject resolved from the record Id. */
	objectApiName = '';

	/** @description Wire response containing field set data keyed by record Id. */
	fieldSets;

	/** @description The FieldSetGroup__mdt record resolved from the developer name. */
	fieldSetGroup;

	/** @description Descriptor for the field that stores comma-separated field set API names. */
	fieldApiNamesField;

	/** @description Descriptor for the field that stores comma-separated active section names. */
	activeSectionsField;

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Transforms the wire-returned field set data into an array of section
	 * objects suitable for the accordion template, each with key, label, and value.
	 * @returns {Array}
	 */
	get displaySections()
	{
		const recordFieldSets = this.fieldSets?.[this.recordId];
		if(!recordFieldSets)
		{
			return [];
		}

		//noinspection JSUnresolvedVariable
		return Object.entries(recordFieldSets).map(([fieldSetApiName, fieldSetArray = []]) => ({
			key: fieldSetApiName, label: fieldSetArray[0]?.fieldSetName ?? '', value: fieldSetArray
		}));
	}

	/**
	 * @description Extracts field set API names and active sections from the
	 * FieldSetGroup__mdt record using the configured field descriptors.
	 * @returns {{fieldSetApiNames: string[], activeSections: string[]}}
	 */
	get fieldSetsAndActiveSections()
	{
		if(!this.fieldSetGroup)
		{
			return {fieldSetApiNames: [], activeSections: []};
		}

		return {
			activeSections: extractCommaSeparated(this.fieldSetGroup, this.activeSectionsField),
			fieldSetApiNames: extractCommaSeparated(this.fieldSetGroup, this.fieldApiNamesField)
		};
	}

	/**
	 * @description Getter method used to get the sections to be active by default.
	 * @returns {string[]} List of sections to be made active, else empty list
	 */
	get displayActiveSections()
	{
		return this.fieldSetsAndActiveSections.activeSections;
	}

	/**
	 * @description Builds the parameter map for the `getFieldSetsForRecord` wire adapter.
	 * @returns {Object}
	 */
	get fetchFieldSetParameters()
	{
		const parameters = this.recordId ? {[this.recordId]: this.fieldSetsAndActiveSections.fieldSetApiNames} : {};

		if(this.recordId)
		{
			this.isLoading = true;
		}

		return parameters;
	}

	// ── Wire Adapters ────────────────────────────────────────────────────

	@wire(getFieldSetByDeveloperName, {developerName: '$fieldSetDeveloperName'}) fetchFieldSetGroup(result)
	{
		this.fieldSetGroup = this.handleWireResponse(result);
	}

	@wire(getFieldSetsForRecord, {recordIdToFieldSetListMap: '$fetchFieldSetParameters'}) fetchFieldSets(result)
	{
		this.fieldSets = this.handleWireResponse(result);
		this.isLoading = false;
	}

	@wire(getObjectNameFromId, {recordId: '$recordId'}) fetchObjectApiName(result)
	{
		this.objectApiName = this.handleWireResponse(result) || '';
	}

	@wire(getFieldSetApiNamesField) fetchFieldApiNamesField(result)
	{
		this.fieldApiNamesField = this.handleWireResponse(result) || '';
	}

	@wire(getDefaultActiveSectionsField) fetchActiveSectionsField(result)
	{
		this.activeSectionsField = this.handleWireResponse(result) || '';
	}
}