// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Creates an SObject form to Create/Clone/Edit an SObject. Supports both
 * field set-based and manual field configuration, picklist value management, lookup
 * integration, and form validation with custom validators.
 *
 * @author Jason van Beukering
 *
 * @see CTRL_FieldSet
 *
 * @date January 2022, March 2026
 */
import getObjectNameFromId from '@salesforce/apex/CTRL_FieldSet.getObjectNameFromId';
import searchFieldSets from '@salesforce/apex/CTRL_FieldSet.search';
import searchSObjects from '@salesforce/apex/CTRL_Search.search';
import getSObjectAllFieldsInformation from '@salesforce/apex/CTRL_SObjectInformation.getSObjectAllFieldsInformation';
import {ComponentBuilder} from 'c/componentBuilder';
import {EMPTY, formatTemplateString} from 'c/utilityString';
import {reduceErrors} from 'c/utilitySystem';
import {getPicklistValuesByRecordType} from 'lightning/uiObjectInfoApi';
import {createRecord, generateRecordInputForCreate, getRecordCreateDefaults, updateRecord} from 'lightning/uiRecordApi';
import {api, wire} from 'lwc';

// ── Exported Field Type Constants ────────────────────────────────────────

export const BOOLEAN_FIELD_TYPE = 'BOOLEAN';
export const DATETIME_FIELD_TYPE = 'DATETIME';
export const EMAIL_FIELD_TYPE = 'EMAIL';
export const ENCRYPTEDSTRING_FIELD_TYPE = 'ENCRYPTEDSTRING';
export const LOOKUP_FIELD_TYPE = 'REFERENCE';
export const PHONE_FIELD_TYPE = 'PHONE';
export const PICKLIST_FIELD_TYPE = 'PICKLIST';
export const TEXTAREA_FIELD_TYPE = 'TEXTAREA';
export const TEXT_FIELD_TYPE = 'STRING';

/**
 * @description Set of field types that render as a textarea input.
 * @type {Set<string>}
 */
const TEXTAREA_TYPES = new Set([
	TEXTAREA_FIELD_TYPE,
	ENCRYPTEDSTRING_FIELD_TYPE
]);

// ── Exported Classes ─────────────────────────────────────────────────────

/**
 * @description Internal class to hold field information
 */
export class Field
{
	/**
	 * @description SObject Field API name
	 * @type {string}
	 */
	fieldName = '';

	/**
	 * @description Field Value. Set in order to pre-populate the field
	 */
	fieldValue;

	/**
	 * @description Field Label
	 * @type {string}
	 */
	fieldLabel = '';
	/**
	 * @description Field Type. Defaults to TEXT_FIELD_TYPE (or 'STRING'). Set to change the field display type.
	 * @type {string}
	 */
	fieldType = '';

	/**
	 * @description Used when fieldType is LOOKUP_FIELD_TYPE (or 'REFERENCE'). Set to change the target SObject for the lookup field.
	 * @type {string}
	 */
	fieldLookupObjectApiName = '';

	/**
	 * @description Required indicator. Set to make the field display as required.
	 * @type {boolean}
	 */
	isRequired = false;

	/**
	 * @description List of picklist options if the field type is picklist
	 * @property {string} label API Name
	 * @property {string} value API Value
	 * @property {boolean} isDefault Marks the option as the default option for this list
	 * @type {PicklistValue[]}
	 */
	picklistValues = [];

	/**
	 * @description List of picklist values to pad the beginning of the picklist
	 * @type {PicklistValue[]}
	 */
	padPicklistValuesBeginning = [];

	/**
	 * @description List of picklist values to pad the end of the picklist
	 * @type {PicklistValue[]}
	 */
	padPicklistValuesEnd = [];

	/**
	 * @description Validator function. Takes in the current value of the form element, returns true if valid, else false.
	 * @type function
	 * @param {any} value Current value of the form element
	 * @returns {boolean}
	 */
	validator;

	/**
	 * @description Validation error
	 * @type {string} Validation Error message
	 */
	validationErrorMessage;

	/**
	 * @description List of picklist values to pad the end of the picklist
	 * @type {PicklistValue[]}
	 */
	get displayPicklistOptions()
	{
		//noinspection JSValidateTypes
		return [
			...this.padPicklistValuesBeginning,
			...this.picklistValues,
			...this.padPicklistValuesEnd
		];
	}

	//noinspection JSUnusedGlobalSymbols // Used in HTML
	get displaySelectedPicklistValue()
	{
		const defaultOption = this.displayPicklistOptions.find((picklistValue) => picklistValue.isDefault);
		return this.fieldValue || defaultOption?.value || '';
	}

	//noinspection JSUnusedGlobalSymbols // Used in HTML
	get isText()
	{
		return this.fieldType === TEXT_FIELD_TYPE;
	}

	//noinspection JSUnusedGlobalSymbols // Used in HTML
	get isBoolean()
	{
		return this.fieldType === BOOLEAN_FIELD_TYPE;
	}

	get isLookup()
	{
		return this.fieldType === LOOKUP_FIELD_TYPE;
	}

	//noinspection JSUnusedGlobalSymbols // Used in HTML
	get isEmail()
	{
		return this.fieldType === EMAIL_FIELD_TYPE;
	}

	get isPicklist()
	{
		return this.fieldType === PICKLIST_FIELD_TYPE;
	}

	//noinspection JSUnusedGlobalSymbols // Used in HTML
	get isPhone()
	{
		return this.fieldType === PHONE_FIELD_TYPE;
	}

	get isDateTime()
	{
		return this.fieldType === DATETIME_FIELD_TYPE;
	}

	//noinspection JSUnusedGlobalSymbols // Used in HTML
	get isTextArea()
	{
		return TEXTAREA_TYPES.has(this.fieldType);
	}
}

/**
 * @description Internal class to hold picklist value information
 */
export class PicklistValue
{
	label = '';
	value = '';
	isDefault = false;
}

// ── Internal Constants ───────────────────────────────────────────────────

const UPDATE_REQUIRES_RECORD_ID = 'You are attempting to update a record without providing a Record Id';
const GENERIC_VALIDATION_FAILURE = 'Validation Failed';
const INVALID_FIELD_WARNING = 'Field "{0}" is not valid for SObject "{1}"';
const NO_FIELDS_PASSED_INTO_FORM_ERROR = 'No fields or FieldSet API Name have been passed into this form.';
const RECORD_CREATED_SUCCESS_MESSAGE = 'Record Created Successfully';
const RECORD_UPDATED_SUCCESS_MESSAGE = 'Record Updated Successfully';
const RELATIONSHIP_SUFFIX = '__r.';
const REQUIRED_ERROR = 'Required';
const SAVE_LABEL = 'Save';
const SAVE_MODE_OR_UPDATE_MODE_NOT_SELECTED = 'Save Mode or Update Mode must be selected to use this feature.';
const UPDATE_LABEL = 'Update';

// ── Field Mapping Helpers ────────────────────────────────────────────────

/**
 * @description Resolves the field type for a display field, falling back to the
 * object metadata when the field has no explicit type.
 * @param {Object} field - Source field descriptor
 * @param {Function} getFieldType - Metadata-based type resolver
 * @returns {string} Resolved field type
 */
function resolveFieldType(field, getFieldType)
{
	return field.fieldType || getFieldType(field.fieldName);
}

/**
 * @description Resolves the display value for a field, considering explicit values,
 * existing record data, and field-type-specific defaults.
 * @param {Object} field - Source field descriptor
 * @param {Field} populatedField - Partially constructed display field
 * @param {Object} existingRecord - Previously fetched record data (if editing)
 * @returns {*} The resolved value
 */
function resolveFieldValue(field, populatedField, existingRecord)
{
	if(field.fieldValue)
	{
		return populatedField.isDateTime ? new Date(field.fieldValue).toISOString() : field.fieldValue;
	}
	if(existingRecord)
	{
		return existingRecord[field.fieldName];
	}
	return populatedField.isLookup ? null : '';
}

/**
 * @description Resolves picklist values from either the field descriptor or the
 * org-level picklist collection.
 * @param {Object} field - Source field descriptor
 * @param {Field} populatedField - Partially constructed display field
 * @param {Function} getPicklistValues - Org picklist value resolver
 * @returns {PicklistValue[]} Resolved picklist values
 */
function resolvePicklistValues(field, populatedField, getPicklistValues)
{
	const hasExplicitValues = populatedField.isPicklist && field.picklistValues?.length > 0;
	return hasExplicitValues ? field.picklistValues : getPicklistValues(field.fieldName);
}

/**
 * @description Resolves the lookup target object API name from either the field
 * descriptor or the org metadata.
 * @param {Object} field - Source field descriptor
 * @param {Field} populatedField - Partially constructed display field
 * @param {Function} getLookupObjectApiName - Metadata-based lookup resolver
 * @returns {string|undefined} Resolved object API name
 */
function resolveLookupObjectName(field, populatedField, getLookupObjectApiName)
{
	return (field.fieldLookupObjectApiName || '').trim() || (populatedField.isLookup ? getLookupObjectApiName(field.fieldName) : undefined);
}

// ── Validation Helpers ───────────────────────────────────────────────────

/**
 * @description Validates a single form field element by calling its native
 * `reportValidity()` method.
 * @param {HTMLElement|null} element - The input element (may be null for lookups)
 * @returns {boolean} Whether the element reports valid
 */
function validateFieldElement(element)
{
	if(!element)
	{
		return true;
	}
	//noinspection JSUnresolvedFunction
	return element.reportValidity();
}

/**
 * @description Resolves the validation state for a field based on its current value
 * and display configuration (required, custom validator). When a validator is present,
 * the error message is always populated (for `setCustomValidity`) while the invalid flag
 * tracks whether the validator actually rejected the value.
 * @param {*} currentValue - The current field value
 * @param {Field} displayField - The display field configuration
 * @returns {{errorMessage: string, isInvalid: boolean}}
 */
function resolveValidationError(currentValue, displayField)
{
	let errorMessage = '';
	let isInvalid = false;

	if(!currentValue && displayField.isRequired)
	{
		errorMessage = REQUIRED_ERROR;
		isInvalid = true;
	}

	if(displayField.validator)
	{
		errorMessage = displayField.validationErrorMessage || GENERIC_VALIDATION_FAILURE;
		isInvalid = !displayField.validator(currentValue);
	}

	return {errorMessage, isInvalid};
}

// ── Component ────────────────────────────────────────────────────────────

export default class CreateForm extends ComponentBuilder('notification', 'controller')
{
	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Save/Update button custom label
	 */
	@api saveButtonLabel;
	/**
	 * @description Form Heading
	 * @type {string}
	 */
	@api formHeading;
	/**
	 * @description Field Set API Name to fetch for a particular record. Will take preference to 'fields'.
	 * @type {string}
	 */
	@api fieldSetApiName;
	/**
	 * @description If true, shows the Save button
	 * @type {boolean}
	 */
	@api isSaveMode = false;
	/**
	 * @description If true, shows the Cancel button
	 * @type {boolean}
	 */
	@api showCancel = false;
	/**
	 * @description (Required) Object API Name
	 * @type {string}
	 */
	@api objectApiName;
	/**
	 * @description List of fields to display, see @type for object structure. Fields retrieved using 'fieldSetApiName' is preferred.
	 * @type {Field[]}
	 */
	@api fields = [];
	/**
	 * @description Record type Id to create the SObject. If not provided, the default record type Id
	 * will be used.
	 * @type {string}
	 */
	@api recordTypeId = '';
	/**
	 * @description Record Id to pre-populate form with existing values
	 */
	@api recordId;
	/**
	 * @description If set to true, perform an update operation instead of an insert operation. Defaults to false.
	 */
	@api isUpdateMode = false;

	// ── Internal State ───────────────────────────────────────────────────

	/**
	 * @description Creates SObject structure with required fields and default values.
	 * @type {{objectInfos, record}}
	 */
	recordDefaults;
	/**
	 * @description Returns field information such as type, label etc. required for form element rendering.
	 * @type {{data: {lookupObjectApiName}, error}}
	 */
	objectInfo;
	/**
	 * @description Retrieves picklist values for record type.
	 * @type {{picklistFieldValues}}
	 * @see https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.reference_wire_adapters_picklist_values_record
	 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_picklist_values_collection.htm
	 */
	picklistCollection;
	/**
	 * @description Contains the current state of the form
	 */
	formValueMap = {};
	/**
	 * @description Indicates whether the form is awaiting a record being created/updated (operation is in progress).
	 * @type {boolean}
	 */
	awaitingRecordOperation = false;
	/**
	 * @description Existing record fetched using recordId
	 */
	existingRecord;
	/**
	 * @description Stores object name associated with record Id
	 * @type {string}
	 */
	objectNameFromRecord;
	/**
	 * @type {{fieldLabel, fieldAPIName, fieldValue, fieldSetAPIName, fieldSetName}[]}
	 */
	fieldSetResult;

	constructor()
	{
		super();
		this.isLoading = true;
	}

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Indicates whether the fields are being fetched
	 * @type {boolean}
	 */
	get isFieldsLoading()
	{
		return (this.displayFieldList.length === 0) && this.isLoading;
	}

	/**
	 * @description Returns map of picklist values
	 * @returns {*}
	 */
	get picklistMap()
	{
		return this.picklistCollection ? this.picklistCollection.picklistFieldValues : {};
	}

	/**
	 * @description Returns default record type Id
	 * @returns {*|null}
	 */
	get defaultRecordTypeId()
	{
		return this.recordDefaults ? this.recordDefaults.objectInfos[this.objectName].defaultRecordTypeId : null;
	}

	/**
	 * @description Returns the record type Id for the object
	 * @returns {string|*|null}
	 */
	get availableRecordTypeId()
	{
		return this.recordTypeId || this.defaultRecordTypeId;
	}

	/**
	 * @description Converts fields into List of Field objects.
	 * @see fields
	 * @returns {Field[]}
	 */
	get displayFieldList()
	{
		if(!(this.fieldSetApiName || this.fields.length))
		{
			this.showErrorToast(NO_FIELDS_PASSED_INTO_FORM_ERROR);
		}

		let displayFieldList = [];

		if(this.fieldSetApiName && this.fieldSetResult)
		{
			displayFieldList = this.fieldSetResult.map(({fieldLabel, fieldAPIName, fieldValue, isRequired}) =>
			{
				let field = new Field();
				field.fieldLabel = fieldLabel;
				field.fieldName = fieldAPIName;
				field.fieldValue = fieldValue;
				field.isRequired = isRequired;
				return field;
			});
		}
		else if(this.fields.length)
		{
			displayFieldList = [...this.fields];
		}

		/*
		 * A previous `if(displayFieldList > 0) { this.isLoading = false; }`
		 * guard here was dead code — `Array > 0` coerces to NaN → false, so the
		 * branch never fired. `isFieldsLoading` short-circuits on
		 * `displayFieldList.length === 0`, so once the wire callbacks populate
		 * it the spinner hides regardless of `isLoading` (which is never
		 * cleared anywhere).
		 */
		return this.mapFieldsToDisplayFieldList(displayFieldList);
	}

	/**
	 * @description Only show footer if one of the footer buttons are required
	 * @returns {boolean}
	 */
	get showFooter()
	{
		return this.showCancel || this.isSaveMode;
	}

	/**
	 * @description Generates record object
	 * @returns {RecordInputRepresentation|{fields: {}}}
	 */
	get recordInputForCreate()
	{
		let recordInputForCreate = this.recordDefaults ? generateRecordInputForCreate(this.recordDefaults.record, this.recordDefaults.objectInfos[this.objectName]) : {fields: {}};
		recordInputForCreate.fields.Id = this.isUpdateMode ? null : this.recordId;
		return recordInputForCreate;
	}

	/**
	 * @description Returns field api names for sobject metadata retrieval
	 * @returns {string[]}
	 */
	get fieldApiNameList()
	{
		return this.fields.map(field => field.fieldName);
	}

	get objectName()
	{
		return this.objectApiName || this.objectNameFromRecord || '';
	}

	get fetchExistingRecordParams()
	{
		return {selectFields: this.fieldApiNameList, recordId: this.recordId};
	}

	get fetchFieldsetParams()
	{
		return {fieldSetApiList: [this.fieldSetApiName], recordId: this.recordId, objectName: this.objectName};
	}

	/**
	 * @description Creates the 'valuechanged' CustomEvent
	 * @event CreateForm#valuechanged
	 * @returns {CustomEvent<{RecordInputRepresentation}>}
	 */
	get valueChangedEvent()
	{
		return new CustomEvent('valuechanged', {detail: this.generateRecord()});
	}

	/**
	 * @description Creates the 'cancel' CustomEvent
	 * @event CreateForm#cancel
	 * @returns {CustomEvent}
	 */
	get cancelEvent()
	{
		return new CustomEvent('cancel');
	}

	get saveLabel()
	{
		if(this.saveButtonLabel)
		{
			return this.saveButtonLabel;
		}
		if(this.isSaveMode)
		{
			return SAVE_LABEL;
		}
		if(this.isUpdateMode)
		{
			return UPDATE_LABEL;
		}
		return undefined;
	}

	get inputFields()
	{
		return this.template.querySelectorAll('.input-field');
	}

	get picklistFields()
	{
		return this.template.querySelectorAll('.picklist-field');
	}

	get lookupFields()
	{
		return this.template.querySelectorAll('c-s-object-lookup');
	}

	// ── Field Mapping ────────────────────────────────────────────────────

	mapFieldsToDisplayFieldList(fields)
	{
		return fields
		.filter(field => this.isFieldValid(field.fieldName))
		.map(field =>
		{
			let populatedField = new Field();
			populatedField.fieldType = resolveFieldType(field, this.getFieldType.bind(this));
			populatedField.isRequired = Boolean(field.isRequired);
			populatedField.fieldName = (field.fieldName || '').trim();
			populatedField.fieldLabel = field.fieldLabel || this.getFieldLabel(field.fieldName);
			populatedField.picklistValues = resolvePicklistValues(field, populatedField, this.getPicklistValues.bind(this));
			populatedField.padPicklistValuesBeginning = field.padPicklistValuesBeginning || [];
			populatedField.padPicklistValuesEnd = field.padPicklistValuesEnd || [];
			populatedField.fieldLookupObjectApiName = resolveLookupObjectName(field, populatedField, this.getLookupObjectApiName.bind(this));
			populatedField.fieldValue = resolveFieldValue(field, populatedField, this.existingRecord);

			return populatedField;
		});
	}

	// ── Wire Adapters ────────────────────────────────────────────────────

	@wire(getSObjectAllFieldsInformation, {objectName: '$objectName'}) fetchObjectInfo(result)
	{
		this.objectInfo = this.handleWireResponse(result);
	}

	@wire(getPicklistValuesByRecordType, {objectApiName: '$objectName', recordTypeId: '$availableRecordTypeId'}) fetchPicklistCollection(result)
	{
		this.picklistCollection = this.handleWireResponse(result);
	}

	@wire(getRecordCreateDefaults, {objectApiName: '$objectName'}) fetchRecordDefaults(result)
	{
		this.recordDefaults = this.handleWireResponse(result);
	}

	@wire(searchSObjects, {searchTerm: '', searchParameters: '$fetchExistingRecordParams'}) fetchExistingRecord(result)
	{
		if(!this.fieldSetApiName)
		{
			this.existingRecord = this.handleWireResponse(result);
		}
	}

	@wire(searchFieldSets, {searchTerm: '', searchParameters: '$fetchFieldsetParams'}) fetchFieldset(result)
	{
		if(this.fieldSetApiName)
		{
			let wireResponse = this.handleWireResponse(result);
			let wireResponseByObjectName = wireResponse[this.objectName];
			this.fieldSetResult = wireResponseByObjectName[this.fieldSetApiName];
		}
	}

	@wire(getObjectNameFromId, {recordId: '$recordId'}) fetchObjectNameFromRecord(result)
	{
		this.objectNameFromRecord = this.handleWireResponse(result) || '';
	}

	// ── Field Metadata Accessors ─────────────────────────────────────────

	/**
	 * @description Checks if field name is a valid field API name for the object
	 * @param {string} fieldName Field name to be checked
	 * @returns {boolean}
	 */
	isFieldValid(fieldName)
	{
		let isValid = this.objectInfo && Object.keys(this.objectInfo).includes(fieldName);
		// NB: DO NOT CHANGE THIS STRICT EQUALITY CHECK. While objectInfo is still being fetched, isValid will be undefined (because of how '&&' is evaluated)
		if(isValid === false && !fieldName.includes(RELATIONSHIP_SUFFIX))
		{
			this.showWarningToast(formatTemplateString(INVALID_FIELD_WARNING, [
				fieldName,
				this.objectName
			]));
		}
		return isValid;
	}

	/**
	 * @description Returns field type from Salesforce
	 * @param {string} fieldName Field API Name
	 * @returns {string}
	 */
	getFieldType(fieldName)
	{
		return this.objectInfo ? this.objectInfo[fieldName].fieldType : '';
	}

	/**
	 * @description Returns the field label from Salesforce
	 * @param {string} fieldName Field API Name
	 * @returns {string}
	 */
	getFieldLabel(fieldName)
	{
		return this.objectInfo ? this.objectInfo[fieldName].fieldLabel : '';
	}

	/**
	 * @description Gets Lookup object API name from Salesforce
	 * @param {string} fieldName Field API Name
	 * @returns {*|string}
	 */
	getLookupObjectApiName(fieldName)
	{
		return this.objectInfo ? this.objectInfo[fieldName].lookupObjectApiName : '';
	}

	/**
	 * @description Returns picklist values for a field from the picklist collection.
	 * @param fieldName Field API name
	 * @returns {PicklistValue[]}
	 */
	getPicklistValues(fieldName)
	{
		const picklistData = this.picklistMap[fieldName];
		if(!picklistData)
		{
			return [];
		}

		const {defaultValue, values} = picklistData;
		const hasDefaultValue = Boolean(defaultValue);
		return values.map(({value, label}) =>
		{
			let picklistValue = new PicklistValue();
			picklistValue.value = value;
			picklistValue.label = label;
			picklistValue.isDefault = hasDefaultValue && (defaultValue === value);
			return picklistValue;
		});
	}

	getInputElementByDataId(id)
	{
		return this.template.querySelector(`[data-id="${id}"]`);
	}

	// ── Validation ───────────────────────────────────────────────────────

	/**
	 * @description Performs validation checks on each form field value. Returns object containing the validation status, and
	 * validation errors, if any.
	 * @returns {{isValid, validationErrors}}
	 */
	@api validateForm()
	{
		let isValid = true;
		let validationErrors = [];
		let formOutput = this.generateRecord();

		this.displayFieldList.forEach(displayField =>
		{
			const fieldName = displayField.fieldName;
			const currentValue = formOutput.fields[fieldName];
			const element = this.getInputElementByDataId(fieldName);

			let isFieldValid = validateFieldElement(element);

			if(isFieldValid)
			{
				const {errorMessage, isInvalid} = resolveValidationError(currentValue, displayField);

				if(isInvalid)
				{
					isFieldValid = false;
				}

				if(element)
				{
					//noinspection JSUnresolvedFunction
					element.setCustomValidity(errorMessage);
				}
				else if(errorMessage)
				{
					validationErrors.push({fieldName, error: errorMessage});
				}
			}

			isValid &&= isFieldValid;
		});

		return {isValid, validationErrors};
	}

	// ── Record Generation ────────────────────────────────────────────────

	//noinspection FunctionWithMultipleLoopsJS
	/**
	 * @description Create New Object that is ready for insert via uiRecordApi.createRecord
	 *
	 * @see RecordInputRepresentation {for object structure}
	 * @returns {RecordInputRepresentation}
	 */
	@api generateRecord()
	{
		let defaultRecord = this.recordInputForCreate;
		this.fields.forEach(({fieldName, fieldValue}) => (defaultRecord.fields[fieldName] = fieldValue || (this.existingRecord && this.existingRecord[fieldName]) || EMPTY));
		Object.keys(this.formValueMap)
		.forEach(key => (defaultRecord.fields[key] = this.formValueMap[key]));
		return defaultRecord;
	}

	/**
	 * @description Create New Object that is ready for insert via Apex controller
	 * @returns {{[p: string]: string | number | boolean | null}}
	 */
	@api createRecordForApex()
	{
		let defaultRecord = this.generateRecord();
		let apexRecord = defaultRecord.fields;
		apexRecord.sobjectType = this.objectName;
		return apexRecord;
	}

	// ── Record Operations ────────────────────────────────────────────────

	/**
	 * @description Inserts a new object based on the form inputs and object defaults via {uiRecordApi.createRecord}.
	 * @see uiRecordApi.generateRecord
	 * @returns {Promise<RecordRepresentation>}
	 * @type {Promise<RecordRepresentation>}
	 */
	insertRecord()
	{
		this.awaitingRecordOperation = true;
		let record = this.generateRecord();
		return this.callControllerMethod(createRecord, record)
		.then(createResult =>
		{
			this.dispatchRecordCreatedEvent(createResult);
			this.showSuccessToast(RECORD_CREATED_SUCCESS_MESSAGE);
			return createResult;
		}).finally(() =>
		{
			this.awaitingRecordOperation = false;
		});
	}

	/**
	 * @description Updates an existing object based on the form inputs and object defaults via {uiRecordApi.updateRecord}.
	 * @see uiRecordApi.updateRecord
	 * @returns {Promise<RecordRepresentation>}
	 * @type {Promise<RecordRepresentation>}
	 */
	updateRecord()
	{
		this.awaitingRecordOperation = true;
		return updateRecord(this.generateRecord())
		.then(updateResult =>
		{
			this.dispatchRecordUpdatedEvent(updateResult);
			this.showSuccessToast(RECORD_UPDATED_SUCCESS_MESSAGE);
			return updateResult;
		}).finally(() =>
		{
			this.awaitingRecordOperation = false;
		});
	}

	/**
	 * @description Save record. Routes to insert, update, or warning based on mode flags.
	 */
	@api async saveRecord()
	{
		const {isValid, validationErrors} = this.validateForm();

		if(!isValid)
		{
			if(validationErrors.length)
			{
				this.showErrorToast(reduceErrors(validationErrors));
			}
			return;
		}

		if(this.isUpdateMode && !this.recordId)
		{
			this.showWarningToast(UPDATE_REQUIRES_RECORD_ID);
			this.awaitingRecordOperation = false;
			return;
		}

		if(this.isUpdateMode)
		{
			await this.updateRecord();
			return;
		}

		if(this.isSaveMode)
		{
			await this.insertRecord();
			return;
		}

		this.showWarningToast(SAVE_MODE_OR_UPDATE_MODE_NOT_SELECTED);
	}

	// ── Form Reset ───────────────────────────────────────────────────────

	/**
	 * @description Resets form to have blank values
	 */
	@api clearForm()
	{
		this.clearFormFields();
		this.clearPicklistFields();
		this.clearLookupFields();
	}

	/**
	 * @description Clears all form fields
	 */
	clearFormFields()
	{
		this.inputFields.forEach(element => (element.value = ''));
	}

	/**
	 * @description Clears all picklist fields
	 */
	clearPicklistFields()
	{
		this.picklistFields.forEach(element => (element.value = undefined));
	}

	/**
	 * @description Clears all lookup fields
	 */
	clearLookupFields()
	{
		//noinspection JSUnresolvedFunction
		this.lookupFields.forEach(element => (element.clearLookup()));
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Saves Field values on change
	 * @param {CustomEvent} event Change event with `detail.value` and `target.dataset.id`
	 */
	handleFieldChange(event)
	{
		const {detail: {value}, target: {dataset: {id}}} = event;
		this.formValueMap[id] = value;
		this.dispatchValueChangedEvent();
	}

	/**
	 * @description Saves Lookup values on change
	 * @param {CustomEvent} event Value-select event with `detail.elementName` and `detail.selectedId`
	 */
	handleLookupValueSelect(event)
	{
		const {detail: {elementName, selectedId}} = event;
		this.formValueMap[elementName] = selectedId;
		this.dispatchValueChangedEvent();
	}

	// ── Event Dispatching ────────────────────────────────────────────────

	/**
	 * @description Creates the 'recordcreated' CustomEvent
	 * @param {*} createResult Result payload from the create operation
	 * @returns {CustomEvent<{createResult}>}
	 */
	recordCreatedEvent(createResult)
	{
		return new CustomEvent('recordcreated', {detail: {createResult}});
	}

	/**
	 * @description Dispatch Event indicating that the record has been created
	 * @param {*} createResult Result of record creation
	 * @fires CreateForm#recordcreated
	 */
	dispatchRecordCreatedEvent(createResult)
	{
		this.dispatchEvent(this.recordCreatedEvent(createResult));
	}

	/**
	 * @description Creates the 'recordupdated' CustomEvent
	 * @param {*} updateResult Result payload from the update operation
	 * @returns {CustomEvent<{updateResult}>}
	 */
	recordUpdatedEvent(updateResult)
	{
		return new CustomEvent('recordupdated', {detail: {updateResult}});
	}

	/**
	 * @description Dispatch Event indicating that the record has been updated
	 * @param {*} updateResult Result of record update
	 * @fires CreateForm#recordupdated
	 */
	dispatchRecordUpdatedEvent(updateResult)
	{
		this.dispatchEvent(this.recordUpdatedEvent(updateResult));
	}

	/**
	 * @description Dispatches Event indicating that a value on the form has been updated
	 * @fires CreateForm#valuechanged
	 */
	dispatchValueChangedEvent()
	{
		this.dispatchEvent(this.valueChangedEvent);
	}

	/**
	 * @description Dispatches a 'cancel' event indicating that the Cancel button was clicked.
	 * @fires CreateForm#cancel
	 */
	dispatchCancelEvent()
	{
		this.dispatchEvent(this.cancelEvent);
	}
}