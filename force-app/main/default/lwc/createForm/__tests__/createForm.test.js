// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for createForm LWC component.
 *
 *              Note: This component extends ComponentBuilder and uses multiple @wire decorators
 *              for data fetching. Due to inheritance complexity and template requirements,
 *              these tests verify module structure, exports, and static analysis.
 *
 * @author Jason van Beukering
 * @date December 2025, July 2026
 */

// Custom Label mocks — values byte-equal the real CustomLabels entries so value
// assertions (and formatTemplateString composition) exercise the shipped text.
jest.mock('@salesforce/label/c.CreateForm_CancelButton', () => ({default: 'Cancel'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_EmailPatternMismatch', () => ({default: 'Please enter a valid email address.'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_InvalidFieldWarning', () => ({default: 'Field "{0}" is not valid for SObject "{1}"'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_ModeNotSelected', () => ({default: 'Save Mode or Update Mode must be selected to use this feature.'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_NoFieldsConfigured', () => ({default: 'No fields or FieldSet API Name have been passed into this form.'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_PhoneFieldHelp', () => ({default: 'Telephone/Cellphone number e.g. 0129873456'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_RecordCreatedSuccess', () => ({default: 'Record Created Successfully'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_RecordUpdatedSuccess', () => ({default: 'Record Updated Successfully'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_RequiredError', () => ({default: 'Required'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_SaveButton', () => ({default: 'Save'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_UpdateButton', () => ({default: 'Update'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_UpdateRequiresRecordId', () => ({default: 'You are attempting to update a record without providing a Record Id'}), {virtual: true});
jest.mock('@salesforce/label/c.CreateForm_ValidationFailed', () => ({default: 'Validation Failed'}), {virtual: true});

// Mock dependencies
jest.mock('@salesforce/apex/CTRL_FieldSet.getObjectNameFromId', () => ({
	default: jest.fn()
}), {virtual: true});

jest.mock('@salesforce/apex/CTRL_FieldSet.search', () => ({
	default: jest.fn()
}), {virtual: true});

jest.mock('@salesforce/apex/CTRL_Search.search', () => ({
	default: jest.fn()
}), {virtual: true});

jest.mock('@salesforce/apex/CTRL_SObjectInformation.getSObjectAllFieldsInformation', () => ({
	default: jest.fn()
}), {virtual: true});

jest.mock('lightning/uiObjectInfoApi', () => ({
	getPicklistValuesByRecordType: jest.fn(), getObjectInfo: jest.fn()
}), {virtual: true});

jest.mock('lightning/uiRecordApi', () => ({
	createRecord: jest.fn(), generateRecordInputForCreate: jest.fn(), getRecordCreateDefaults: jest.fn(), updateRecord: jest.fn()
}), {virtual: true});

// Mock child component to prevent template resolution issues
jest.mock('c/sObjectLookup', () =>
{
	return {
		default: jest.fn()
	};
}, {virtual: true});

describe('c-create-form', () =>
{
	describe('module exports', () =>
	{
		it('exports LwcCreateForm as default', () =>
		{
			const LwcCreateForm = require('c/createForm').default;
			expect(LwcCreateForm).toBeDefined();
			expect(typeof LwcCreateForm).toBe('function');
		});

		it('exports Field class', () =>
		{
			const {Field} = require('c/createForm');
			expect(Field).toBeDefined();
			expect(typeof Field).toBe('function');
		});

		it('exports PicklistValue class', () =>
		{
			const {PicklistValue} = require('c/createForm');
			expect(PicklistValue).toBeDefined();
			expect(typeof PicklistValue).toBe('function');
		});
	});

	describe('field type constants', () =>
	{
		it('exports BOOLEAN_FIELD_TYPE', () =>
		{
			const {BOOLEAN_FIELD_TYPE} = require('c/createForm');
			expect(BOOLEAN_FIELD_TYPE).toBe('BOOLEAN');
		});

		it('exports DATETIME_FIELD_TYPE', () =>
		{
			const {DATETIME_FIELD_TYPE} = require('c/createForm');
			expect(DATETIME_FIELD_TYPE).toBe('DATETIME');
		});

		it('exports EMAIL_FIELD_TYPE', () =>
		{
			const {EMAIL_FIELD_TYPE} = require('c/createForm');
			expect(EMAIL_FIELD_TYPE).toBe('EMAIL');
		});

		it('exports ENCRYPTEDSTRING_FIELD_TYPE', () =>
		{
			const {ENCRYPTEDSTRING_FIELD_TYPE} = require('c/createForm');
			expect(ENCRYPTEDSTRING_FIELD_TYPE).toBe('ENCRYPTEDSTRING');
		});

		it('exports LOOKUP_FIELD_TYPE', () =>
		{
			const {LOOKUP_FIELD_TYPE} = require('c/createForm');
			expect(LOOKUP_FIELD_TYPE).toBe('REFERENCE');
		});

		it('exports PHONE_FIELD_TYPE', () =>
		{
			const {PHONE_FIELD_TYPE} = require('c/createForm');
			expect(PHONE_FIELD_TYPE).toBe('PHONE');
		});

		it('exports PICKLIST_FIELD_TYPE', () =>
		{
			const {PICKLIST_FIELD_TYPE} = require('c/createForm');
			expect(PICKLIST_FIELD_TYPE).toBe('PICKLIST');
		});

		it('exports TEXTAREA_FIELD_TYPE', () =>
		{
			const {TEXTAREA_FIELD_TYPE} = require('c/createForm');
			expect(TEXTAREA_FIELD_TYPE).toBe('TEXTAREA');
		});

		it('exports TEXT_FIELD_TYPE', () =>
		{
			const {TEXT_FIELD_TYPE} = require('c/createForm');
			expect(TEXT_FIELD_TYPE).toBe('STRING');
		});
	});

	describe('Field class', () =>
	{
		it('has default property values', () =>
		{
			const {Field} = require('c/createForm');
			const field = new Field();

			expect(field.fieldName).toBe('');
			expect(field.fieldValue).toBeUndefined();
			expect(field.fieldLabel).toBe('');
			expect(field.fieldType).toBe('');
			expect(field.fieldLookupObjectApiName).toBe('');
			expect(field.isRequired).toBe(false);
			expect(field.picklistValues).toEqual([]);
			expect(field.padPicklistValuesBeginning).toEqual([]);
			expect(field.padPicklistValuesEnd).toEqual([]);
			expect(field.validator).toBeUndefined();
			expect(field.validationErrorMessage).toBeUndefined();
		});

		it('has displayPicklistOptions getter combining all picklist sources', () =>
		{
			const {Field, PicklistValue} = require('c/createForm');
			const field = new Field();

			const beginValue = new PicklistValue();
			beginValue.label = 'Start';
			beginValue.value = 'start';

			const midValue = new PicklistValue();
			midValue.label = 'Middle';
			midValue.value = 'middle';

			const endValue = new PicklistValue();
			endValue.label = 'End';
			endValue.value = 'end';

			field.padPicklistValuesBeginning = [beginValue];
			field.picklistValues = [midValue];
			field.padPicklistValuesEnd = [endValue];

			expect(field.displayPicklistOptions).toHaveLength(3);
			expect(field.displayPicklistOptions[0].value).toBe('start');
			expect(field.displayPicklistOptions[1].value).toBe('middle');
			expect(field.displayPicklistOptions[2].value).toBe('end');
		});

		it('has displaySelectedPicklistValue getter returning fieldValue or default', () =>
		{
			const {Field, PicklistValue} = require('c/createForm');
			const field = new Field();

			// When no value and no default
			expect(field.displaySelectedPicklistValue).toBe('');

			// When fieldValue is set
			field.fieldValue = 'selected';
			expect(field.displaySelectedPicklistValue).toBe('selected');

			// When no fieldValue but default exists
			field.fieldValue = '';
			const defaultOption = new PicklistValue();
			defaultOption.value = 'defaultVal';
			defaultOption.isDefault = true;
			field.picklistValues = [defaultOption];
			expect(field.displaySelectedPicklistValue).toBe('defaultVal');
		});

		describe('field type getters', () =>
		{
			it('isText returns true for STRING type', () =>
			{
				const {Field, TEXT_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = TEXT_FIELD_TYPE;
				expect(field.isText).toBe(true);
			});

			it('isBoolean returns true for BOOLEAN type', () =>
			{
				const {Field, BOOLEAN_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = BOOLEAN_FIELD_TYPE;
				expect(field.isBoolean).toBe(true);
			});

			it('isLookup returns true for REFERENCE type', () =>
			{
				const {Field, LOOKUP_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = LOOKUP_FIELD_TYPE;
				expect(field.isLookup).toBe(true);
			});

			it('isEmail returns true for EMAIL type', () =>
			{
				const {Field, EMAIL_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = EMAIL_FIELD_TYPE;
				expect(field.isEmail).toBe(true);
			});

			it('isPicklist returns true for PICKLIST type', () =>
			{
				const {Field, PICKLIST_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = PICKLIST_FIELD_TYPE;
				expect(field.isPicklist).toBe(true);
			});

			it('isPhone returns true for PHONE type', () =>
			{
				const {Field, PHONE_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = PHONE_FIELD_TYPE;
				expect(field.isPhone).toBe(true);
			});

			it('isDateTime returns true for DATETIME type', () =>
			{
				const {Field, DATETIME_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = DATETIME_FIELD_TYPE;
				expect(field.isDateTime).toBe(true);
			});

			it('isTextArea returns true for TEXTAREA type', () =>
			{
				const {Field, TEXTAREA_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = TEXTAREA_FIELD_TYPE;
				expect(field.isTextArea).toBe(true);
			});

			it('isTextArea returns true for ENCRYPTEDSTRING type', () =>
			{
				const {Field, ENCRYPTEDSTRING_FIELD_TYPE} = require('c/createForm');
				const field = new Field();
				field.fieldType = ENCRYPTEDSTRING_FIELD_TYPE;
				expect(field.isTextArea).toBe(true);
			});
		});
	});

	describe('PicklistValue class', () =>
	{
		it('has default property values', () =>
		{
			const {PicklistValue} = require('c/createForm');
			const picklistValue = new PicklistValue();

			expect(picklistValue.label).toBe('');
			expect(picklistValue.value).toBe('');
			expect(picklistValue.isDefault).toBe(false);
		});

		it('allows setting property values', () =>
		{
			const {PicklistValue} = require('c/createForm');
			const picklistValue = new PicklistValue();

			picklistValue.label = 'Test Label';
			picklistValue.value = 'testValue';
			picklistValue.isDefault = true;

			expect(picklistValue.label).toBe('Test Label');
			expect(picklistValue.value).toBe('testValue');
			expect(picklistValue.isDefault).toBe(true);
		});
	});

	describe('LwcCreateForm class structure', () =>
	{
		it('has expected @api properties', () =>
		{
			expect.hasAssertions();
			const LwcCreateForm = require('c/createForm').default;
			const prototype = LwcCreateForm.prototype;

			const apiProps = [
				'saveButtonLabel',
				'formHeading',
				'fieldSetApiName',
				'isSaveMode',
				'showCancel',
				'objectApiName',
				'fields',
				'recordTypeId',
				'recordId',
				'isUpdateMode'
			];

			apiProps.forEach((propName) =>
			{
				const descriptor = Object.getOwnPropertyDescriptor(prototype, propName);
				// @api creates getter/setter or value descriptor
				expect(descriptor).toBeDefined();
				expect(descriptor.get || descriptor.set || descriptor.value !== undefined).toBeTruthy();
			});
		});

		it('has @api methods', () =>
		{
			const LwcCreateForm = require('c/createForm').default;
			const prototype = LwcCreateForm.prototype;

			expect(typeof prototype.validateForm).toBe('function');
			expect(typeof prototype.generateRecord).toBe('function');
			expect(typeof prototype.createRecordForApex).toBe('function');
			expect(typeof prototype.saveRecord).toBe('function');
			expect(typeof prototype.clearForm).toBe('function');
		});

		it('has expected computed getters', () =>
		{
			const LwcCreateForm = require('c/createForm').default;
			const prototype = LwcCreateForm.prototype;

			const getterNames = [
				'isFieldsLoading',
				'picklistMap',
				'defaultRecordTypeId',
				'availableRecordTypeId',
				'displayFieldList',
				'showFooter',
				'recordInputForCreate',
				'fieldApiNameList',
				'objectName',
				'fetchExistingRecordParams',
				'fetchFieldsetParams',
				'valueChangedEvent',
				'cancelEvent',
				'saveLabel',
				'inputFields',
				'picklistFields',
				'lookupFields'
			];

			getterNames.forEach((getterName) =>
			{
				const descriptor = Object.getOwnPropertyDescriptor(prototype, getterName);
				expect(descriptor).toBeDefined();
				expect(typeof descriptor.get).toBe('function');
			});
		});

		it('has prototype methods', () =>
		{
			const LwcCreateForm = require('c/createForm').default;
			const prototype = LwcCreateForm.prototype;

			expect(typeof prototype.mapFieldsToDisplayFieldList).toBe('function');
			expect(typeof prototype.getPicklistValues).toBe('function');
			expect(typeof prototype.getInputElementByDataId).toBe('function');
			expect(typeof prototype.insertRecord).toBe('function');
			expect(typeof prototype.updateRecord).toBe('function');
			expect(typeof prototype.clearFormFields).toBe('function');
			expect(typeof prototype.clearPicklistFields).toBe('function');
			expect(typeof prototype.clearLookupFields).toBe('function');
		});

		it('has @wire methods', () =>
		{
			const LwcCreateForm = require('c/createForm').default;
			const prototype = LwcCreateForm.prototype;

			// @wire methods are transformed but should exist on prototype
			expect(prototype.fetchObjectInfo).toBeDefined();
			expect(prototype.fetchPicklistCollection).toBeDefined();
			expect(prototype.fetchRecordDefaults).toBeDefined();
			expect(prototype.fetchExistingRecord).toBeDefined();
			expect(prototype.fetchFieldset).toBeDefined();
			expect(prototype.fetchObjectNameFromRecord).toBeDefined();
		});
	});

	describe('module dependencies', () =>
	{
		it('imports from Apex controllers', () =>
		{
			const getObjectNameFromId = require('@salesforce/apex/CTRL_FieldSet.getObjectNameFromId').default;
			const searchFieldSets = require('@salesforce/apex/CTRL_FieldSet.search').default;
			const searchSObjects = require('@salesforce/apex/CTRL_Search.search').default;
			const getSObjectAllFieldsInformation = require('@salesforce/apex/CTRL_SObjectInformation.getSObjectAllFieldsInformation').default;

			expect(getObjectNameFromId).toBeDefined();
			expect(searchFieldSets).toBeDefined();
			expect(searchSObjects).toBeDefined();
			expect(getSObjectAllFieldsInformation).toBeDefined();
		});

		it('imports from lightning/uiRecordApi', () =>
		{
			const {createRecord, updateRecord, generateRecordInputForCreate, getRecordCreateDefaults} = require('lightning/uiRecordApi');

			expect(createRecord).toBeDefined();
			expect(updateRecord).toBeDefined();
			expect(generateRecordInputForCreate).toBeDefined();
			expect(getRecordCreateDefaults).toBeDefined();
		});
	});

	describe('LwcCreateForm instance behavior', () =>
	{
		const LwcCreateForm = require('c/createForm').default;
		const prototype = LwcCreateForm.prototype;

		const createMockTemplate = () =>
		{
			return {
				querySelector: jest.fn(), querySelectorAll: jest.fn(() => [])
			};
		};

		const createMockContext = () =>
		{
			return {
				isLoading: false,
				awaitingRecordOperation: false,
				saveButtonLabel: null,
				formHeading: 'Test Form',
				fieldSetApiName: null,
				isSaveMode: true,
				showCancel: false,
				objectApiName: 'Account',
				fields: [],
				recordTypeId: '',
				recordId: null,
				isUpdateMode: false,
				recordDefaults: null,
				objectInfo: null,
				picklistCollection: null,
				formValueMap: {},
				existingRecord: null,
				objectNameFromRecord: null,
				fieldSetResult: null,
				template: createMockTemplate(),
				showSuccessToast: jest.fn(),
				showErrorToast: jest.fn(),
				showWarningToast: jest.fn(),
				reportInvalidFieldWarnings: jest.fn(),
				dispatchEvent: jest.fn()
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

		const prepareFieldMetadataContext = (context, overrides = {}) =>
		{
			context.isFieldValid = overrides.isFieldValid || (() => true);
			context.getFieldType = overrides.getFieldType || (() => 'STRING');
			context.getFieldLabel = overrides.getFieldLabel || (() => 'Name');
			context.getPicklistValues = overrides.getPicklistValues || (() => []);
			context.getLookupObjectApiName = overrides.getLookupObjectApiName || (() => '');
		};

		const createMockFormElement = () =>
		{
			return {
				reportValidity: jest.fn(() => true), setCustomValidity: jest.fn()
			};
		};

		describe('getters', () =>
		{
			it('showFooter returns true when isSaveMode or showCancel is true', () =>
			{
				const context = createMockContext();
				context.isSaveMode = true;
				context.showCancel = false;
				expect(callGetter(context, 'showFooter')).toBe(true);
			});

			it('showFooter returns true when showCancel is true', () =>
			{
				const context = createMockContext();
				context.isSaveMode = false;
				context.showCancel = true;
				expect(callGetter(context, 'showFooter')).toBe(true);
			});

			it('showFooter returns false when both isSaveMode and showCancel are false', () =>
			{
				const context = createMockContext();
				context.isSaveMode = false;
				context.showCancel = false;
				expect(callGetter(context, 'showFooter')).toBe(false);
			});

			it('isFieldsLoading returns true when displayFieldList is empty and isLoading', () =>
			{
				const context = createMockContext();
				context.isLoading = true;
				Object.defineProperty(context, 'displayFieldList', {get: () => []});
				expect(callGetter(context, 'isFieldsLoading')).toBe(true);
			});

			it('isFieldsLoading returns false when displayFieldList has items', () =>
			{
				const context = createMockContext();
				context.isLoading = true;
				Object.defineProperty(context, 'displayFieldList', {get: () => [{fieldName: 'Name'}]});
				expect(callGetter(context, 'isFieldsLoading')).toBe(false);
			});

			it('defaultRecordTypeId returns null when recordDefaults is null', () =>
			{
				const context = createMockContext();
				context.recordDefaults = null;
				expect(callGetter(context, 'defaultRecordTypeId')).toBeNull();
			});

			it('defaultRecordTypeId returns defaultRecordTypeId from recordDefaults', () =>
			{
				const context = createMockContext();
				context.recordDefaults = {
					objectInfos: {Account: {defaultRecordTypeId: '012000000000001'}}
				};
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				expect(callGetter(context, 'defaultRecordTypeId')).toBe('012000000000001');
			});

			it('availableRecordTypeId returns recordTypeId when set', () =>
			{
				const context = createMockContext();
				context.recordTypeId = '012000000000001';
				Object.defineProperty(context, 'defaultRecordTypeId', {get: () => '012000000000002'});
				expect(callGetter(context, 'availableRecordTypeId')).toBe('012000000000001');
			});

			it('availableRecordTypeId returns defaultRecordTypeId when recordTypeId is empty', () =>
			{
				const context = createMockContext();
				context.recordTypeId = '';
				Object.defineProperty(context, 'defaultRecordTypeId', {get: () => '012000000000002'});
				expect(callGetter(context, 'availableRecordTypeId')).toBe('012000000000002');
			});

			it('recordInputForCreate uses generateRecordInputForCreate when recordDefaults exists', () =>
			{
				const {generateRecordInputForCreate} = require('lightning/uiRecordApi');
				generateRecordInputForCreate.mockReturnValue({fields: {Name: 'Default'}});
				const context = createMockContext();
				context.recordDefaults = {
					record: {fields: {}}, objectInfos: {Account: {}}
				};
				context.isUpdateMode = false;
				context.recordId = null;
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				const result = callGetter(context, 'recordInputForCreate');
				expect(generateRecordInputForCreate).toHaveBeenCalled();
				expect(result.fields.Id).toBeNull();
			});

			it('recordInputForCreate returns empty fields when recordDefaults is null', () =>
			{
				const context = createMockContext();
				context.recordDefaults = null;
				context.isUpdateMode = true;
				context.recordId = '001000000000001';
				const result = callGetter(context, 'recordInputForCreate');
				expect(result.fields).toBeDefined();
				expect(result.fields.Id).toBeNull();
			});

			it('fieldApiNameList maps fields to field names', () =>
			{
				const context = createMockContext();
				context.fields = [
					{fieldName: 'Name'},
					{fieldName: 'Industry'}
				];
				expect(callGetter(context, 'fieldApiNameList')).toEqual([
					'Name',
					'Industry'
				]);
			});

			it('objectName returns empty string when both are falsy', () =>
			{
				const context = createMockContext();
				context.objectApiName = null;
				context.objectNameFromRecord = null;
				expect(callGetter(context, 'objectName')).toBe('');
			});

			it('valueChangedEvent returns CustomEvent with generated record', () =>
			{
				const context = createMockContext();
				context.generateRecord = jest.fn(() => ({fields: {Name: 'Test'}}));
				const result = callGetter(context, 'valueChangedEvent');
				expect(result).toBeInstanceOf(CustomEvent);
				expect(result.type).toBe('valuechanged');
			});

			it('saveLabel returns Update when isUpdateMode is true', () =>
			{
				const context = createMockContext();
				context.saveButtonLabel = null;
				context.isSaveMode = false;
				context.isUpdateMode = true;
				expect(callGetter(context, 'saveLabel')).toBe('Update');
			});

			it('saveLabel returns undefined when no mode is set', () =>
			{
				const context = createMockContext();
				context.saveButtonLabel = null;
				context.isSaveMode = false;
				context.isUpdateMode = false;
				expect(callGetter(context, 'saveLabel')).toBeUndefined();
			});

			it('saveLabel returns saveButtonLabel when set', () =>
			{
				const context = createMockContext();
				context.saveButtonLabel = 'Custom Save';
				context.isUpdateMode = false;
				expect(callGetter(context, 'saveLabel')).toBe('Custom Save');
			});

			it('saveLabel returns Save when isUpdateMode is false and no custom label', () =>
			{
				const context = createMockContext();
				context.saveButtonLabel = null;
				context.isUpdateMode = false;
				expect(callGetter(context, 'saveLabel')).toBe('Save');
			});

			it('objectName returns objectApiName or objectNameFromRecord', () =>
			{
				const context = createMockContext();
				context.objectApiName = 'Account';
				expect(callGetter(context, 'objectName')).toBe('Account');
			});

			it('objectName returns objectNameFromRecord when objectApiName is not set', () =>
			{
				const context = createMockContext();
				context.objectApiName = null;
				context.objectNameFromRecord = 'Contact';
				expect(callGetter(context, 'objectName')).toBe('Contact');
			});

			it('picklistMap returns empty object when picklistCollection is null', () =>
			{
				const context = createMockContext();
				context.picklistCollection = null;
				expect(callGetter(context, 'picklistMap')).toEqual({});
			});

			it('picklistMap returns picklistFieldValues when picklistCollection exists', () =>
			{
				const context = createMockContext();
				context.picklistCollection = {picklistFieldValues: {Status: {values: []}}};
				expect(callGetter(context, 'picklistMap')).toEqual({Status: {values: []}});
			});

			it('inputFields queries template for input elements', () =>
			{
				const context = createMockContext();
				const mockInputs = [{dataset: {id: 'Name'}}];
				context.template.querySelectorAll = jest.fn(() => mockInputs);
				const result = callGetter(context, 'inputFields');
				expect(context.template.querySelectorAll).toHaveBeenCalledWith('.input-field');
				expect(result).toBe(mockInputs);
			});

			it('picklistFields queries template for picklist elements', () =>
			{
				const context = createMockContext();
				const mockPicklists = [{dataset: {id: 'Status'}}];
				context.template.querySelectorAll = jest.fn(() => mockPicklists);
				const result = callGetter(context, 'picklistFields');
				expect(context.template.querySelectorAll).toHaveBeenCalledWith('.picklist-field');
				expect(result).toBe(mockPicklists);
			});

			it('lookupFields queries template for lookup elements', () =>
			{
				const context = createMockContext();
				const mockLookups = [{dataset: {id: 'AccountId'}}];
				context.template.querySelectorAll = jest.fn(() => mockLookups);
				const result = callGetter(context, 'lookupFields');
				expect(context.template.querySelectorAll).toHaveBeenCalledWith('c-s-object-lookup');
				expect(result).toBe(mockLookups);
			});

			it('fetchFieldsetParams returns parameters for field set fetch', () =>
			{
				const context = createMockContext();
				context.recordId = '001000000000001';
				context.fieldSetApiName = 'TestFieldSet';
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				expect(callGetter(context, 'fetchFieldsetParams')).toEqual({fieldSetApiList: ['TestFieldSet'], recordId: '001000000000001', objectName: 'Account'});
			});

			it('fetchExistingRecordParams returns parameters for existing record fetch', () =>
			{
				const context = createMockContext();
				context.recordId = '001000000000001';
				Object.defineProperty(context, 'fieldApiNameList', {
					get: () => [
						'Name',
						'Industry'
					]
				});
				expect(callGetter(context, 'fetchExistingRecordParams')).toEqual({
					recordId: '001000000000001', selectFields: [
						'Name',
						'Industry'
					]
				});
			});

			it('cancelEvent returns CustomEvent', () =>
			{
				const context = createMockContext();
				const result = callGetter(context, 'cancelEvent');
				expect(result).toBeInstanceOf(CustomEvent);
				expect(result.type).toBe('cancel');
			});
		});

		describe('methods', () =>
		{
			it('getInputElementByDataId returns element with matching data-id', () =>
			{
				const context = createMockContext();
				const mockElement = {dataset: {id: 'Name'}};
				context.template.querySelector = jest.fn(() => mockElement);
				const result = prototype.getInputElementByDataId.call(context, 'Name');
				expect(result).toBe(mockElement);
			});

			it('clearFormFields clears values of input fields', () =>
			{
				const context = createMockContext();
				const mockInput = {value: 'test'};
				Object.defineProperty(context, 'inputFields', {get: () => [mockInput]});
				prototype.clearFormFields.call(context);
				expect(mockInput.value).toBe('');
			});

			it('clearPicklistFields resets picklist values', () =>
			{
				const context = createMockContext();
				const mockPicklist = {value: 'Selected'};
				Object.defineProperty(context, 'picklistFields', {get: () => [mockPicklist]});
				prototype.clearPicklistFields.call(context);
				expect(mockPicklist.value).toBeUndefined();
			});

			it('clearLookupFields calls clearLookup on each lookup', () =>
			{
				const context = createMockContext();
				const mockLookup = {clearLookup: jest.fn()};
				Object.defineProperty(context, 'lookupFields', {get: () => [mockLookup]});
				prototype.clearLookupFields.call(context);
				expect(mockLookup.clearLookup).toHaveBeenCalled();
			});

			it('getPicklistValues returns empty array when no picklist data', () =>
			{
				const context = createMockContext();
				Object.defineProperty(context, 'picklistMap', {get: () => ({})});
				const result = prototype.getPicklistValues.call(context, 'Status');
				expect(result).toEqual([]);
			});

			it('getPicklistValues returns picklist values when available', () =>
			{
				const context = createMockContext();
				const picklistValues = {Status: {values: [{label: 'Open', value: 'Open'}]}};
				Object.defineProperty(context, 'picklistMap', {get: () => picklistValues});
				const result = prototype.getPicklistValues.call(context, 'Status');
				expect(result).toHaveLength(1);
				expect(result[0].label).toBe('Open');
				expect(result[0].value).toBe('Open');
				expect(result[0].isDefault).toBe(false);
			});

			it('validateForm calls generateRecord and validates fields', () =>
			{
				const context = createMockContext();
				context.generateRecord = jest.fn(() => ({fields: {Name: 'Test'}}));
				Object.defineProperty(context, 'displayFieldList', {get: () => []});
				const result = prototype.validateForm.call(context);
				expect(result).toEqual({isValid: true, validationErrors: []});
				expect(context.generateRecord).toHaveBeenCalled();
			});

			it('generateRecord builds record from fields and formValueMap', () =>
			{
				const context = createMockContext();
				context.fields = [{fieldName: 'Name', fieldValue: 'Test'}];
				context.formValueMap = {Industry: 'Tech'};
				context.existingRecord = null;
				Object.defineProperty(context, 'recordInputForCreate', {get: () => ({fields: {}})});
				const result = prototype.generateRecord.call(context);
				expect(result.fields.Name).toBe('Test');
				expect(result.fields.Industry).toBe('Tech');
			});

			it('generateRecord uses existingRecord only when fieldValue is nullish', () =>
			{
				const context = createMockContext();
				context.fields = [{fieldName: 'Name'}];
				context.formValueMap = {};
				context.existingRecord = {Name: 'Existing Value'};
				Object.defineProperty(context, 'recordInputForCreate', {get: () => ({fields: {}})});
				const result = prototype.generateRecord.call(context);
				expect(result.fields.Name).toBe('Existing Value');
			});

			it('createRecordForApex adds sobjectType to record', () =>
			{
				const context = createMockContext();
				context.generateRecord = jest.fn(() => ({fields: {Name: 'Test'}}));
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				const result = prototype.createRecordForApex.call(context);
				expect(result.Name).toBe('Test');
				expect(result.sobjectType).toBe('Account');
			});

			it('clearForm calls all clear methods', () =>
			{
				const context = createMockContext();
				context.clearFormFields = jest.fn();
				context.clearPicklistFields = jest.fn();
				context.clearLookupFields = jest.fn();
				prototype.clearForm.call(context);
				expect(context.clearFormFields).toHaveBeenCalled();
				expect(context.clearPicklistFields).toHaveBeenCalled();
				expect(context.clearLookupFields).toHaveBeenCalled();
			});
		});

		describe('wire callbacks', () =>
		{
			it('fetchObjectInfo sets objectInfo from response', () =>
			{
				const context = createMockContext();
				const mockData = {Name: {fieldType: 'STRING', fieldLabel: 'Name'}};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchObjectInfo.call(context, {data: mockData});
				expect(context.objectInfo).toBe(mockData);
			});

			it('fetchPicklistCollection sets picklistCollection from response', () =>
			{
				const context = createMockContext();
				const mockData = {picklistFieldValues: {Status: {values: []}}};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchPicklistCollection.call(context, {data: mockData});
				expect(context.picklistCollection).toBe(mockData);
			});

			it('fetchRecordDefaults sets recordDefaults from response', () =>
			{
				const context = createMockContext();
				const mockData = {record: {}, objectInfos: {}};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchRecordDefaults.call(context, {data: mockData});
				expect(context.recordDefaults).toBe(mockData);
			});

			it('fetchExistingRecord sets existingRecord when fieldSetApiName is not set', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				const mockData = {Id: '001', Name: 'Test'};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchExistingRecord.call(context, {data: mockData});
				expect(context.existingRecord).toBe(mockData);
			});

			it('fetchExistingRecord does not set existingRecord when fieldSetApiName is set', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = 'TestFieldSet';
				context.existingRecord = null;
				context.handleWireResponse = jest.fn(() => ({Id: '001'}));
				prototype.fetchExistingRecord.call(context, {data: {Id: '001'}});
				expect(context.existingRecord).toBeNull();
			});

			it('fetchFieldset sets fieldSetResult when fieldSetApiName is set', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = 'TestFieldSet';
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				const mockData = {
					Account: {
						TestFieldSet: [
							{fieldLabel: 'Name', fieldAPIName: 'Name', fieldValue: '', isRequired: true}
						]
					}
				};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchFieldset.call(context, {data: mockData});
				expect(context.fieldSetResult).toEqual([
					{fieldLabel: 'Name', fieldAPIName: 'Name', fieldValue: '', isRequired: true}
				]);
			});

			it('fetchFieldset does nothing when fieldSetApiName is not set', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				context.fieldSetResult = null;
				context.handleWireResponse = jest.fn(() => ({}));
				prototype.fetchFieldset.call(context, {data: {}});
				expect(context.fieldSetResult).toBeNull();
			});

			it('fetchObjectNameFromRecord sets objectNameFromRecord', () =>
			{
				const context = createMockContext();
				context.handleWireResponse = jest.fn(() => 'Account');
				prototype.fetchObjectNameFromRecord.call(context, {data: 'Account'});
				expect(context.objectNameFromRecord).toBe('Account');
			});

			it('fetchObjectNameFromRecord sets empty string when null', () =>
			{
				const context = createMockContext();
				context.handleWireResponse = jest.fn(() => null);
				prototype.fetchObjectNameFromRecord.call(context, {data: null});
				expect(context.objectNameFromRecord).toBe('');
			});

			it('fetchObjectInfo reports invalid-field warnings once the object information arrives', () =>
			{
				const context = createMockContext();
				const mockData = {Name: {fieldType: 'STRING'}};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchObjectInfo.call(context, {data: mockData});
				expect(context.reportInvalidFieldWarnings).toHaveBeenCalledTimes(1);
			});

			it('fetchFieldset reports invalid-field warnings once the field set result arrives', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = 'TestFieldSet';
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				const mockData = {Account: {TestFieldSet: [{fieldAPIName: 'Name'}]}};
				context.handleWireResponse = jest.fn(() => mockData);
				prototype.fetchFieldset.call(context, {data: mockData});
				expect(context.reportInvalidFieldWarnings).toHaveBeenCalledTimes(1);
			});
		});

		describe('field validation and metadata functions', () =>
		{
			it('isFieldValid returns true when field exists in objectInfo', () =>
			{
				const context = createMockContext();
				context.objectInfo = {Name: {fieldType: 'STRING'}, Industry: {fieldType: 'STRING'}};
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				expect(prototype.isFieldValid.call(context, 'Name')).toBe(true);
			});

			it('isFieldValid returns false for an invalid field without toasting (pure compute path)', () =>
			{
				const context = createMockContext();
				context.objectInfo = {Name: {fieldType: 'STRING'}};
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				expect(prototype.isFieldValid.call(context, 'InvalidField')).toBe(false);
				expect(context.showWarningToast).not.toHaveBeenCalled();
			});

			it('isFieldValid does not show warning for relationship fields', () =>
			{
				const context = createMockContext();
				context.objectInfo = {Name: {fieldType: 'STRING'}};
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				expect(prototype.isFieldValid.call(context, 'Contact__r.Name')).toBe(false);
				expect(context.showWarningToast).not.toHaveBeenCalled();
			});

			it('isFieldValid returns falsy when objectInfo is null', () =>
			{
				const context = createMockContext();
				context.objectInfo = null;
				expect(prototype.isFieldValid.call(context, 'Name')).toBeFalsy();
			});

			it('getFieldType returns field type from objectInfo', () =>
			{
				const context = createMockContext();
				context.objectInfo = {Name: {fieldType: 'STRING'}};
				expect(prototype.getFieldType.call(context, 'Name')).toBe('STRING');
			});

			it('getFieldType returns empty string when objectInfo is null', () =>
			{
				const context = createMockContext();
				context.objectInfo = null;
				expect(prototype.getFieldType.call(context, 'Name')).toBe('');
			});

			it('getFieldLabel returns field label from objectInfo', () =>
			{
				const context = createMockContext();
				context.objectInfo = {Name: {fieldLabel: 'Account Name'}};
				expect(prototype.getFieldLabel.call(context, 'Name')).toBe('Account Name');
			});

			it('getLookupObjectApiName returns lookup API name from objectInfo', () =>
			{
				const context = createMockContext();
				context.objectInfo = {AccountId: {lookupObjectApiName: 'Account'}};
				expect(prototype.getLookupObjectApiName.call(context, 'AccountId')).toBe('Account');
			});

			it('getFieldLabel returns empty string when objectInfo is null', () =>
			{
				const context = createMockContext();
				context.objectInfo = null;
				expect(prototype.getFieldLabel.call(context, 'Name')).toBe('');
			});

			it('getLookupObjectApiName returns empty string when objectInfo is null', () =>
			{
				const context = createMockContext();
				context.objectInfo = null;
				expect(prototype.getLookupObjectApiName.call(context, 'AccountId')).toBe('');
			});
		});

		/*
		 * Render-path purity: the invalid-field warning used to fire from isFieldValid,
		 * inside the displayFieldList compute path. It is now reported from the
		 * data-arrival points (the wire handlers and the fields setter), where field
		 * validity first becomes decidable, at most once per field/object pair.
		 */
		describe('reportInvalidFieldWarnings', () =>
		{
			const createWarningContext = (overrides = {}) =>
			{
				const context = createMockContext();
				Object.assign(context, overrides);
				context.isFieldValid = prototype.isFieldValid;
				Object.defineProperty(context, 'configuredFieldNames', getDescriptor('configuredFieldNames'));
				Object.defineProperty(context, 'fieldApiNameList', getDescriptor('fieldApiNameList'));
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				return context;
			};

			it('does nothing while the object information has not loaded', () =>
			{
				const context = createWarningContext({objectInfo: null, fields: [{fieldName: 'InvalidField'}]});
				prototype.reportInvalidFieldWarnings.call(context);
				expect(context.showWarningToast).not.toHaveBeenCalled();
			});

			it('reports a warning only for the configured fields missing from the object information', () =>
			{
				const context = createWarningContext({
					objectInfo: {Name: {fieldType: 'STRING'}}, fields: [
						{fieldName: 'Name'},
						{fieldName: 'InvalidField'}
					]
				});
				prototype.reportInvalidFieldWarnings.call(context);
				expect(context.showWarningToast).toHaveBeenCalledTimes(1);
				expect(context.showWarningToast).toHaveBeenCalledWith('Field "InvalidField" is not valid for SObject "Account"');
			});

			it('reports each invalid field once across repeated invocations', () =>
			{
				const context = createWarningContext({
					objectInfo: {Name: {fieldType: 'STRING'}}, fields: [{fieldName: 'InvalidField'}]
				});
				prototype.reportInvalidFieldWarnings.call(context);
				prototype.reportInvalidFieldWarnings.call(context);
				expect(context.showWarningToast).toHaveBeenCalledTimes(1);
			});

			it('does not report relationship fields or nameless fields', () =>
			{
				const context = createWarningContext({
					objectInfo: {Name: {fieldType: 'STRING'}}, fields: [
						{fieldName: 'Contact__r.Name'},
						{fieldName: ''},
						{}
					]
				});
				prototype.reportInvalidFieldWarnings.call(context);
				expect(context.showWarningToast).not.toHaveBeenCalled();
			});

			it('reports invalid field-set fields when a field set is configured, ignoring the fields property', () =>
			{
				const context = createWarningContext({
					objectInfo: {Name: {fieldType: 'STRING'}},
					fieldSetApiName: 'TestFieldSet',
					fieldSetResult: [{fieldAPIName: 'InvalidFieldSetField'}],
					fields: [{fieldName: 'InvalidField'}]
				});
				prototype.reportInvalidFieldWarnings.call(context);
				expect(context.showWarningToast).toHaveBeenCalledTimes(1);
				expect(context.showWarningToast).toHaveBeenCalledWith('Field "InvalidFieldSetField" is not valid for SObject "Account"');
			});

			it('falls back to the fields property while the field set result has not arrived', () =>
			{
				const context = createWarningContext({
					objectInfo: {Name: {fieldType: 'STRING'}}, fieldSetApiName: 'TestFieldSet', fieldSetResult: null, fields: [{fieldName: 'InvalidField'}]
				});
				prototype.reportInvalidFieldWarnings.call(context);
				expect(context.showWarningToast).toHaveBeenCalledWith('Field "InvalidField" is not valid for SObject "Account"');
			});
		});

		describe('fields property', () =>
		{
			/*
			 * The LWC engine freezes the component prototype at first createElement, so the
			 * component's own methods cannot be spied on or restored. A throwaway subclass
			 * shadows reportInvalidFieldWarnings on its own prototype instead; the authored
			 * fields setter resolves the shadowed method through the instance.
			 */
			it('round-trips through the public accessor and re-reports invalid-field warnings on replacement', () =>
			{
				const reportInvalidFieldWarningsMock = jest.fn();

				class ReportSpyCreateForm extends LwcCreateForm
				{
					reportInvalidFieldWarnings()
					{
						reportInvalidFieldWarningsMock();
					}
				}

				const {createElement} = require('lwc');
				const element = createElement('c-create-form-report-spy', {is: ReportSpyCreateForm});
				const replacementFields = [{fieldName: 'InvalidField'}];
				element.fields = replacementFields;
				expect(element.fields).toEqual(replacementFields);
				expect(reportInvalidFieldWarningsMock).toHaveBeenCalledTimes(1);
			});
		});

		describe('mapFieldsToDisplayFieldList', () =>
		{
			it('maps fields with field types and labels from objectInfo', () =>
			{
				const context = createMockContext();
				context.objectInfo = {
					Name: {fieldType: 'STRING', fieldLabel: 'Account Name', lookupObjectApiName: ''}
				};
				context.existingRecord = null;
				Object.defineProperty(context, 'picklistMap', {get: () => ({})});
				const isFieldValidFn = (fieldName) => context.objectInfo && Object.keys(context.objectInfo).includes(fieldName);
				const getFieldTypeFn = (fieldName) => context.objectInfo[fieldName].fieldType;
				const getFieldLabelFn = (fieldName) => context.objectInfo[fieldName].fieldLabel;
				const getPicklistValuesFn = () => [];
				const getLookupFn = () => '';
				context.isFieldValid = isFieldValidFn;
				context.getFieldType = getFieldTypeFn;
				context.getFieldLabel = getFieldLabelFn;
				context.getPicklistValues = getPicklistValuesFn;
				context.getLookupObjectApiName = getLookupFn;

				const fields = [{fieldName: 'Name', fieldType: '', fieldLabel: '', isRequired: false}];
				const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
				expect(result).toHaveLength(1);
				expect(result[0].fieldType).toBe('STRING');
				expect(result[0].fieldLabel).toBe('Account Name');
				expect(result[0].fieldValue).toBe('');
			});

			it('maps fields with existing record values', () =>
			{
				const context = createMockContext();
				context.objectInfo = {
					Name: {fieldType: 'STRING', fieldLabel: 'Name', lookupObjectApiName: ''}
				};
				context.existingRecord = {Name: 'Existing Account'};
				Object.defineProperty(context, 'picklistMap', {get: () => ({})});
				prepareFieldMetadataContext(context);

				const fields = [{fieldName: 'Name', fieldType: '', fieldLabel: '', isRequired: false}];
				const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
				expect(result[0].fieldValue).toBe('Existing Account');
			});

			it('maps fields with fieldValue already set', () =>
			{
				const context = createMockContext();
				context.objectInfo = {
					Name: {fieldType: 'STRING', fieldLabel: 'Name', lookupObjectApiName: ''}
				};
				context.existingRecord = null;
				Object.defineProperty(context, 'picklistMap', {get: () => ({})});
				prepareFieldMetadataContext(context);

				const fields = [{fieldName: 'Name', fieldType: '', fieldLabel: '', isRequired: false, fieldValue: 'Preset'}];
				const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
				expect(result[0].fieldValue).toBe('Preset');
			});

			describe('explicit falsy display values survive (mirrors generateRecord)', () =>
			{
				const buildContext = (existingRecord) =>
				{
					const context = createMockContext();
					context.objectInfo = {
						Amount: {fieldType: 'STRING', fieldLabel: 'Amount', lookupObjectApiName: ''}
					};
					context.existingRecord = existingRecord;
					Object.defineProperty(context, 'picklistMap', {get: () => ({})});
					prepareFieldMetadataContext(context);
					return context;
				};

				it('keeps an explicit 0 instead of the existing record value', () =>
				{
					const context = buildContext({Amount: 42});
					const fields = [{fieldName: 'Amount', fieldType: '', fieldLabel: '', isRequired: false, fieldValue: 0}];
					const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
					expect(result[0].fieldValue).toBe(0);
				});

				it('keeps an explicit false instead of the existing record value', () =>
				{
					const context = buildContext({Amount: true});
					const fields = [{fieldName: 'Amount', fieldType: '', fieldLabel: '', isRequired: false, fieldValue: false}];
					const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
					expect(result[0].fieldValue).toBe(false);
				});

				it('keeps an explicit empty string instead of the existing record value', () =>
				{
					const context = buildContext({Amount: 'Existing'});
					const fields = [{fieldName: 'Amount', fieldType: '', fieldLabel: '', isRequired: false, fieldValue: ''}];
					const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
					expect(result[0].fieldValue).toBe('');
				});

				it('displays an explicit empty string on a DATETIME field without converting', () =>
				{
					const context = buildContext(null);
					context.objectInfo = {
						DateField: {fieldType: 'DATETIME', fieldLabel: 'Date', lookupObjectApiName: ''}
					};
					prepareFieldMetadataContext(context, {
						getFieldType: () => 'DATETIME', getFieldLabel: () => 'Date'
					});
					const fields = [{fieldName: 'DateField', fieldType: 'DATETIME', fieldLabel: '', isRequired: false, fieldValue: ''}];
					const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
					expect(result[0].fieldValue).toBe('');
				});

				it('still falls back to the existing record value for an explicit null', () =>
				{
					const context = buildContext({Amount: 'Existing'});
					const fields = [{fieldName: 'Amount', fieldType: '', fieldLabel: '', isRequired: false, fieldValue: null}];
					const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
					expect(result[0].fieldValue).toBe('Existing');
				});
			});

			it('maps DATETIME field value to ISO string', () =>
			{
				const context = createMockContext();
				context.objectInfo = {
					DateField: {fieldType: 'DATETIME', fieldLabel: 'Date', lookupObjectApiName: ''}
				};
				context.existingRecord = null;
				Object.defineProperty(context, 'picklistMap', {get: () => ({})});
				prepareFieldMetadataContext(context, {
					getFieldType: () => 'DATETIME', getFieldLabel: () => 'Date'
				});

				const fields = [{fieldName: 'DateField', fieldType: 'DATETIME', fieldLabel: '', isRequired: false, fieldValue: '2025-01-15T10:00:00'}];
				const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
				expect(result[0].fieldValue).toContain('2025-01-15');
			});

			it('maps REFERENCE field to null when no value or existing record', () =>
			{
				const context = createMockContext();
				context.objectInfo = {
					AccountId: {fieldType: 'REFERENCE', fieldLabel: 'Account', lookupObjectApiName: 'Account'}
				};
				context.existingRecord = null;
				Object.defineProperty(context, 'picklistMap', {get: () => ({})});
				prepareFieldMetadataContext(context, {
					getFieldType: () => 'REFERENCE', getFieldLabel: () => 'Account', getLookupObjectApiName: () => 'Account'
				});

				const fields = [{fieldName: 'AccountId', fieldType: 'REFERENCE', fieldLabel: '', isRequired: false}];
				const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
				expect(result[0].fieldValue).toBeNull();
				expect(result[0].fieldLookupObjectApiName).toBe('Account');
			});

			it('filters out invalid fields', () =>
			{
				const context = createMockContext();
				context.objectInfo = {Name: {fieldType: 'STRING'}};
				prepareFieldMetadataContext(context, {
					isFieldValid: (fieldName) => fieldName === 'Name'
				});

				const fields = [
					{fieldName: 'Name', fieldType: '', isRequired: false},
					{fieldName: 'InvalidField', fieldType: '', isRequired: false}
				];
				const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
				expect(result).toHaveLength(1);
			});
		});

		describe('displayFieldList', () =>
		{
			/*
			 * Render-path purity: the getter is evaluated on every render, so it must not
			 * dispatch toasts (the missing-configuration warning now fires once, from
			 * connectedCallback) and must not recompute the derived list while its inputs
			 * are unchanged.
			 */
			it('does not toast from the getter when no fields or fieldSetApiName are provided', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				context.fields = [];
				context.fieldSetResult = null;
				context.mapFieldsToDisplayFieldList = jest.fn(() => []);
				callGetter(context, 'displayFieldList');
				expect(context.showErrorToast).not.toHaveBeenCalled();
			});

			it('memoises the derived list: repeated reads with unchanged inputs map once and return the same reference', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				const {Field} = require('c/createForm');
				const field = new Field();
				field.fieldName = 'Name';
				context.fields = [field];
				context.fieldSetResult = null;
				context.mapFieldsToDisplayFieldList = jest.fn((fields) => fields);
				const firstRead = callGetter(context, 'displayFieldList');
				const secondRead = callGetter(context, 'displayFieldList');
				expect(context.mapFieldsToDisplayFieldList).toHaveBeenCalledTimes(1);
				expect(secondRead).toBe(firstRead);
			});

			it('recomputes the list when an input reference changes', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				const {Field} = require('c/createForm');
				const field = new Field();
				field.fieldName = 'Name';
				context.fields = [field];
				context.fieldSetResult = null;
				context.mapFieldsToDisplayFieldList = jest.fn((fields) => fields);
				callGetter(context, 'displayFieldList');
				const replacementField = new Field();
				replacementField.fieldName = 'Industry';
				context.fields = [replacementField];
				const secondRead = callGetter(context, 'displayFieldList');
				expect(context.mapFieldsToDisplayFieldList).toHaveBeenCalledTimes(2);
				expect(secondRead[0].fieldName).toBe('Industry');
			});

			it('returns mapped fields from fields array', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				const {Field} = require('c/createForm');
				const field = new Field();
				field.fieldName = 'Name';
				context.fields = [field];
				context.fieldSetResult = null;
				context.mapFieldsToDisplayFieldList = jest.fn((fields) => fields);
				const result = callGetter(context, 'displayFieldList');
				expect(context.mapFieldsToDisplayFieldList).toHaveBeenCalled();
				expect(result).toHaveLength(1);
			});

			it('returns mapped fields from fieldSetResult', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = 'TestFS';
				context.fields = [];
				context.fieldSetResult = [
					{fieldLabel: 'Name', fieldAPIName: 'Name', fieldValue: 'Test', isRequired: true}
				];
				context.mapFieldsToDisplayFieldList = jest.fn((fields) => fields);
				const result = callGetter(context, 'displayFieldList');
				expect(result).toHaveLength(1);
				expect(result[0].fieldName).toBe('Name');
			});

			it('does not toast for an invalid field from the compute path', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				context.fields = [{fieldName: 'InvalidField', fieldType: '', fieldLabel: '', isRequired: false}];
				context.fieldSetResult = null;
				context.objectInfo = {Name: {fieldType: 'STRING', fieldLabel: 'Name', lookupObjectApiName: ''}};
				context.mapFieldsToDisplayFieldList = prototype.mapFieldsToDisplayFieldList;
				context.isFieldValid = prototype.isFieldValid;
				Object.defineProperty(context, 'objectName', {get: () => 'Account'});
				const result = callGetter(context, 'displayFieldList');
				expect(result).toEqual([]);
				expect(context.showWarningToast).not.toHaveBeenCalled();
			});
		});

		describe('connectedCallback', () =>
		{
			it('shows the no-fields error toast once when the form is connected without any field configuration', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				context.fields = [];
				prototype.connectedCallback.call(context);
				expect(context.showErrorToast).toHaveBeenCalledTimes(1);
				expect(context.showErrorToast).toHaveBeenCalledWith('No fields or FieldSet API Name have been passed into this form.');
			});

			it('does not toast when fields are configured', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = null;
				context.fields = [{fieldName: 'Name'}];
				prototype.connectedCallback.call(context);
				expect(context.showErrorToast).not.toHaveBeenCalled();
			});

			it('does not toast when a field set API name is configured', () =>
			{
				const context = createMockContext();
				context.fieldSetApiName = 'TestFieldSet';
				context.fields = [];
				prototype.connectedCallback.call(context);
				expect(context.showErrorToast).not.toHaveBeenCalled();
			});
		});

		describe('getPicklistValues with default', () =>
		{
			it('marks default picklist value correctly', () =>
			{
				const context = createMockContext();
				const picklistData = {
					Status: {
						values: [
							{label: 'Open', value: 'Open'},
							{label: 'Closed', value: 'Closed'}
						], defaultValue: 'Open'
					}
				};
				Object.defineProperty(context, 'picklistMap', {get: () => picklistData});
				const result = prototype.getPicklistValues.call(context, 'Status');
				expect(result).toHaveLength(2);
				expect(result[0].isDefault).toBe(true);
				expect(result[1].isDefault).toBe(false);
			});
		});

		describe('saveRecord', () =>
		{
			it('inserts record when isSaveMode is true and valid', async() =>
			{
				const context = createMockContext();
				context.isSaveMode = true;
				context.isUpdateMode = false;
				context.recordId = null;
				context.validateForm = jest.fn(() => ({isValid: true, validationErrors: []}));
				context.insertRecord = jest.fn().mockResolvedValue({});
				await prototype.saveRecord.call(context);
				expect(context.insertRecord).toHaveBeenCalled();
			});

			it('updates record when isUpdateMode is true and valid with recordId', async() =>
			{
				const context = createMockContext();
				context.isSaveMode = false;
				context.isUpdateMode = true;
				context.recordId = '001000000000001';
				context.validateForm = jest.fn(() => ({isValid: true, validationErrors: []}));
				context.updateRecord = jest.fn().mockResolvedValue({});
				await prototype.saveRecord.call(context);
				expect(context.updateRecord).toHaveBeenCalled();
			});

			it('shows warning when isUpdateMode is true but no recordId', async() =>
			{
				const context = createMockContext();
				context.isSaveMode = false;
				context.isUpdateMode = true;
				context.recordId = null;
				context.validateForm = jest.fn(() => ({isValid: true, validationErrors: []}));
				await prototype.saveRecord.call(context);
				expect(context.showWarningToast).toHaveBeenCalled();
				expect(context.awaitingRecordOperation).toBe(false);
			});

			it('shows warning when neither mode is selected', async() =>
			{
				const context = createMockContext();
				context.isSaveMode = false;
				context.isUpdateMode = false;
				context.validateForm = jest.fn(() => ({isValid: true, validationErrors: []}));
				await prototype.saveRecord.call(context);
				expect(context.showWarningToast).toHaveBeenCalled();
			});

			it('shows error toast when validation fails with errors', async() =>
			{
				const context = createMockContext();
				context.validateForm = jest.fn(() => ({isValid: false, validationErrors: [{fieldName: 'Name', error: 'Required'}]}));
				await prototype.saveRecord.call(context);
				expect(context.showErrorToast).toHaveBeenCalled();
			});

			it('does not show error when validation fails with no errors', async() =>
			{
				const context = createMockContext();
				context.validateForm = jest.fn(() => ({isValid: false, validationErrors: []}));
				await prototype.saveRecord.call(context);
				expect(context.showErrorToast).not.toHaveBeenCalled();
			});
		});

		// Record-operation contexts wire the REAL callControllerMethod (c/moduleController is not
		// mocked in this suite) so the failure-path tests prove the genuine error normalisation:
		// a rejected uiRecordApi call surfaces one error toast and resolves to undefined.
		const createRecordOperationContext = () =>
		{
			const {initialiseCallControllerMethod} = require('c/moduleController');
			const context = createMockContext();
			initialiseCallControllerMethod(context);
			context.consoleError = jest.fn();
			context.dispatchRecordCreatedEvent = jest.fn();
			context.dispatchRecordUpdatedEvent = jest.fn();
			return context;
		};

		describe('insertRecord', () =>
		{
			it('creates record and dispatches event on success', async() =>
			{
				const context = createMockContext();
				context.generateRecord = jest.fn(() => ({fields: {Name: 'Test'}}));
				context.callControllerMethod = jest.fn().mockResolvedValue({id: '001'});
				context.dispatchRecordCreatedEvent = jest.fn();
				await prototype.insertRecord.call(context);
				expect(context.awaitingRecordOperation).toBe(false);
				expect(context.callControllerMethod).toHaveBeenCalled();
				expect(context.dispatchRecordCreatedEvent).toHaveBeenCalled();
				expect(context.showSuccessToast).toHaveBeenCalled();
			});

			it('does not dispatch the created event or a success toast when the create fails', async() =>
			{
				const {createRecord} = require('lightning/uiRecordApi');
				createRecord.mockRejectedValueOnce({body: {message: 'Required fields are missing'}});
				const context = createRecordOperationContext();
				context.generateRecord = jest.fn(() => ({fields: {Name: 'Test'}}));

				await prototype.insertRecord.call(context);

				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				expect(context.dispatchEvent.mock.calls[0][0].detail.variant).toBe('error');
				expect(context.showSuccessToast).not.toHaveBeenCalled();
				expect(context.dispatchRecordCreatedEvent).not.toHaveBeenCalled();
				expect(context.awaitingRecordOperation).toBe(false);
			});
		});

		describe('updateRecord', () =>
		{
			it('updates record and dispatches event on success', async() =>
			{
				const {updateRecord} = require('lightning/uiRecordApi');
				updateRecord.mockResolvedValueOnce({id: '001'});
				const context = createRecordOperationContext();
				context.generateRecord = jest.fn(() => ({fields: {Id: '001', Name: 'Test'}}));
				await prototype.updateRecord.call(context);
				expect(updateRecord).toHaveBeenCalledWith({fields: {Id: '001', Name: 'Test'}});
				expect(context.awaitingRecordOperation).toBe(false);
				expect(context.dispatchRecordUpdatedEvent).toHaveBeenCalledWith({id: '001'});
				expect(context.showSuccessToast).toHaveBeenCalled();
			});

			it('surfaces an error toast and does not signal success when the update is rejected', async() =>
			{
				const {updateRecord} = require('lightning/uiRecordApi');
				updateRecord.mockRejectedValueOnce({body: {message: 'FIELD_CUSTOM_VALIDATION_EXCEPTION: Record is locked'}});
				const context = createRecordOperationContext();
				context.generateRecord = jest.fn(() => ({fields: {Id: '001', Name: 'Test'}}));

				await prototype.updateRecord.call(context);

				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				expect(context.dispatchEvent.mock.calls[0][0].detail.variant).toBe('error');
				expect(context.showSuccessToast).not.toHaveBeenCalled();
				expect(context.dispatchRecordUpdatedEvent).not.toHaveBeenCalled();
				expect(context.awaitingRecordOperation).toBe(false);
			});
		});

		describe('validateForm with fields', () =>
		{
			it('validates required field with no value', () =>
			{
				const context = createMockContext();
				const mockElement = createMockFormElement();
				context.generateRecord = jest.fn(() => ({fields: {Name: ''}}));
				context.getInputElementByDataId = jest.fn(() => mockElement);
				Object.defineProperty(context, 'displayFieldList', {
					get: () => [{fieldName: 'Name', isRequired: true}]
				});
				const result = prototype.validateForm.call(context);
				expect(result.isValid).toBe(false);
				expect(mockElement.setCustomValidity).toHaveBeenCalledWith('Required');
			});

			it('validates field with custom validator that passes', () =>
			{
				const context = createMockContext();
				const mockElement = createMockFormElement();
				context.generateRecord = jest.fn(() => ({fields: {Name: 'Valid'}}));
				context.getInputElementByDataId = jest.fn(() => mockElement);
				Object.defineProperty(context, 'displayFieldList', {
					get: () => [{fieldName: 'Name', isRequired: false, validator: (val) => val.length > 0}]
				});
				const result = prototype.validateForm.call(context);
				expect(result.isValid).toBe(true);
				// errorMessage is always set when validator exists (to DEFAULT_VALIDATION_ERROR),
				// so setCustomValidity is called with the message even when valid
				expect(mockElement.setCustomValidity).toHaveBeenCalledWith('Validation Failed');
			});

			it('validates field with custom validator that fails', () =>
			{
				const context = createMockContext();
				const mockElement = createMockFormElement();
				context.generateRecord = jest.fn(() => ({fields: {Name: ''}}));
				context.getInputElementByDataId = jest.fn(() => mockElement);
				Object.defineProperty(context, 'displayFieldList', {
					get: () => [
						{
							fieldName: 'Name', isRequired: false, validator: (val) => val && val.length > 3, validationErrorMessage: 'Must be longer than 3 characters'
						}
					]
				});
				const result = prototype.validateForm.call(context);
				// isFieldValid &&= validator('') where validator returns '' (falsy)
				// So isValid &&= '' which is falsy
				expect(result.isValid).toBeFalsy();
				expect(mockElement.setCustomValidity).toHaveBeenCalledWith('Must be longer than 3 characters');
			});

			it('adds validation error when no element and error message exists', () =>
			{
				const context = createMockContext();
				context.generateRecord = jest.fn(() => ({fields: {Name: ''}}));
				context.getInputElementByDataId = jest.fn(() => null);
				Object.defineProperty(context, 'displayFieldList', {
					get: () => [{fieldName: 'Name', isRequired: true}]
				});
				const result = prototype.validateForm.call(context);
				expect(result.isValid).toBe(false);
				expect(result.validationErrors).toHaveLength(1);
				expect(result.validationErrors[0].error).toBe('Required');
			});

			it('clears custom validity for valid non-required field without validator', () =>
			{
				const context = createMockContext();
				const mockElement = createMockFormElement();
				context.generateRecord = jest.fn(() => ({fields: {Name: 'Test'}}));
				context.getInputElementByDataId = jest.fn(() => mockElement);
				Object.defineProperty(context, 'displayFieldList', {
					get: () => [{fieldName: 'Name', isRequired: false}]
				});
				const result = prototype.validateForm.call(context);
				expect(result.isValid).toBe(true);
				// No errorMessage, so setCustomValidity is called with '' (line 667)
				expect(mockElement.setCustomValidity).toHaveBeenCalledWith('');
			});

			it('handles reportValidity returning false', () =>
			{
				const context = createMockContext();
				const mockElement = createMockFormElement();
				mockElement.reportValidity.mockReturnValue(false);
				context.generateRecord = jest.fn(() => ({fields: {Name: 'Test'}}));
				context.getInputElementByDataId = jest.fn(() => mockElement);
				Object.defineProperty(context, 'displayFieldList', {
					get: () => [{fieldName: 'Name', isRequired: false}]
				});
				const result = prototype.validateForm.call(context);
				expect(result.isValid).toBe(false);
			});
		});

		describe('event handler functions', () =>
		{
			it('handleFieldChange updates formValueMap and dispatches valuechanged', () =>
			{
				const context = createMockContext();
				context.formValueMap = {};
				context.dispatchValueChangedEvent = jest.fn();
				prototype.handleFieldChange.call(context, {detail: {value: 'NewValue'}, target: {dataset: {id: 'Name'}}});
				expect(context.formValueMap.Name).toBe('NewValue');
				expect(context.dispatchValueChangedEvent).toHaveBeenCalledTimes(1);
			});

			it('handleLookupValueSelect updates formValueMap and dispatches valuechanged', () =>
			{
				const context = createMockContext();
				context.formValueMap = {};
				context.dispatchValueChangedEvent = jest.fn();
				prototype.handleLookupValueSelect.call(context, {detail: {elementName: 'AccountId', selectedId: '001000000000001'}});
				expect(context.formValueMap.AccountId).toBe('001000000000001');
				expect(context.dispatchValueChangedEvent).toHaveBeenCalledTimes(1);
			});

			it('dispatchCancelEvent dispatches a cancel CustomEvent', () =>
			{
				const context = createMockContext();
				Object.defineProperty(context, 'cancelEvent', {
					get: () => new CustomEvent('cancel')
				});
				prototype.dispatchCancelEvent.call(context);
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				expect(context.dispatchEvent.mock.calls[0][0].type).toBe('cancel');
			});

			it('recordCreatedEvent builds a recordcreated CustomEvent with the create result', () =>
			{
				const event = prototype.recordCreatedEvent.call({}, {id: '001000000000001'});
				expect(event).toBeInstanceOf(CustomEvent);
				expect(event.type).toBe('recordcreated');
				expect(event.detail.createResult).toEqual({id: '001000000000001'});
			});

			it('dispatchRecordCreatedEvent dispatches the recordcreated event', () =>
			{
				const context = createMockContext();
				context.recordCreatedEvent = prototype.recordCreatedEvent;
				prototype.dispatchRecordCreatedEvent.call(context, {id: '001000000000001'});
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				const dispatched = context.dispatchEvent.mock.calls[0][0];
				expect(dispatched.type).toBe('recordcreated');
				expect(dispatched.detail.createResult).toEqual({id: '001000000000001'});
			});

			it('recordUpdatedEvent builds a recordupdated CustomEvent with the update result', () =>
			{
				const event = prototype.recordUpdatedEvent.call({}, {id: '001000000000002'});
				expect(event).toBeInstanceOf(CustomEvent);
				expect(event.type).toBe('recordupdated');
				expect(event.detail.updateResult).toEqual({id: '001000000000002'});
			});

			it('dispatchRecordUpdatedEvent dispatches the recordupdated event', () =>
			{
				const context = createMockContext();
				context.recordUpdatedEvent = prototype.recordUpdatedEvent;
				prototype.dispatchRecordUpdatedEvent.call(context, {id: '001000000000002'});
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				const dispatched = context.dispatchEvent.mock.calls[0][0];
				expect(dispatched.type).toBe('recordupdated');
				expect(dispatched.detail.updateResult).toEqual({id: '001000000000002'});
			});

			it('dispatchValueChangedEvent dispatches the valuechanged event from the getter', () =>
			{
				const context = createMockContext();
				const generatedEvent = new CustomEvent('valuechanged', {detail: {fields: {Name: 'Test'}}});
				Object.defineProperty(context, 'valueChangedEvent', {get: () => generatedEvent});
				prototype.dispatchValueChangedEvent.call(context);
				expect(context.dispatchEvent).toHaveBeenCalledWith(generatedEvent);
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

		it('can be instantiated via createElement with default property values', async() =>
		{
			const {createElement} = require('lwc');
			const LwcCreateForm = require('c/createForm').default;
			const element = createElement('c-create-form', {is: LwcCreateForm});
			element.objectApiName = 'Account';
			document.body.appendChild(element);

			await new Promise((resolve) => setTimeout(resolve, 0));

			// Verify instance is created (covers class body declarations lines 205-296)
			expect(element.objectApiName).toBe('Account');
			expect(element.isSaveMode).toBe(false);
			expect(element.showCancel).toBe(false);
			expect(element.isUpdateMode).toBe(false);
			expect(element.fields).toEqual([]);
			expect(element.recordTypeId).toBe('');
		});

		/*
		 * The @lwc/jest-transformer rewrites each `import X from '@salesforce/apex/...'`
		 * statement into a try/catch that stashes a `jest.fn()` on
		 * `global.__lwcJestMock_<name>` when the require() throws. Pre-setting the
		 * global and isolating the module load covers the truthy-LHS side of the
		 * generated `global.X || function X() {...}` expression; this paired test
		 * deletes the slot and re-isolates so the function-expression RHS is
		 * evaluated and its declared function covered too.
		 *
		 * This only affects Jest coverage — in production the try-path succeeds
		 * and the fallback code is never reached.
		 */
		it('exercises the transformer fallback stubs when apex global slots are empty', () =>
		{
			const apexGlobalKeys = [
				'__lwcJestMock_getObjectNameFromId',
				'__lwcJestMock_searchFieldSets',
				'__lwcJestMock_searchSObjects',
				'__lwcJestMock_getSObjectAllFieldsInformation'
			];
			const saved = {};
			apexGlobalKeys.forEach((key) =>
			{
				saved[key] = global[key];
				delete global[key];
			});

			let LwcCreateFormFresh;
			jest.isolateModules(() =>
			{
				LwcCreateFormFresh = require('c/createForm').default;
			});

			apexGlobalKeys.forEach((key) =>
			{
				if(saved[key] !== undefined)
				{
					global[key] = saved[key];
				}
			});

			expect(typeof LwcCreateFormFresh).toBe('function');
			expect(typeof LwcCreateFormFresh.prototype.validateForm).toBe('function');
		});

		it('pre-sets apex global slots and isolates to cover the truthy-LHS side of the generated stubs', () =>
		{
			const apexGlobals = {
				__lwcJestMock_getObjectNameFromId: jest.fn(),
				__lwcJestMock_searchFieldSets: jest.fn(),
				__lwcJestMock_searchSObjects: jest.fn(),
				__lwcJestMock_getSObjectAllFieldsInformation: jest.fn()
			};
			const saved = {};
			Object.keys(apexGlobals).forEach((key) =>
			{
				saved[key] = global[key];
			});
			Object.assign(global, apexGlobals);

			let LwcCreateFormFresh;
			try
			{
				jest.isolateModules(() =>
				{
					LwcCreateFormFresh = require('c/createForm').default;
				});
			}
			finally
			{
				// Restore/delete the pre-set slots — leaked __lwcJestMock_* globals survive this
				// file and poison later suites' module worlds (proven: moduleController's toast
				// mock stops intercepting when these leak).
				Object.keys(apexGlobals).forEach((key) =>
				{
					if(saved[key] === undefined)
					{
						delete global[key];
					}
					else
					{
						global[key] = saved[key];
					}
				});
			}

			expect(typeof LwcCreateFormFresh).toBe('function');
			expect(typeof LwcCreateFormFresh.prototype.validateForm).toBe('function');
		});
	});

	/*
	 * The following describe blocks exercise branches that the prototype-mock
	 * tests above couldn't reach before `isFieldValid` / `getFieldType` /
	 * `getFieldLabel` / `getLookupObjectApiName` / `handleFieldChange` /
	 * `handleLookupValueSelect` / event dispatchers were converted from arrow
	 * class fields to prototype methods. The refactor was essential — arrow
	 * class fields are per-instance bindings and are therefore invisible to
	 * prototype-mock tests and not exposed on the HTMLBridgeElement proxy.
	 */

	describe('mapFieldsToDisplayFieldList edge branches', () =>
	{
		const LwcCreateForm = require('c/createForm').default;
		const prototype = LwcCreateForm.prototype;

		function createMockContextWithMeta(overrides = {})
		{
			const context = {
				existingRecord: null,
				objectApiName: 'Account',
				showWarningToast: jest.fn(),
				objectInfo: {Name: {fieldType: 'STRING', fieldLabel: 'Account Name', lookupObjectApiName: ''}}, ...overrides
			};
			Object.defineProperty(context, 'picklistMap', {get: () => overrides.picklistMap || {}});
			context.isFieldValid = overrides.isFieldValid || (() => true);
			context.getFieldType = overrides.getFieldType || ((fieldName) => context.objectInfo?.[fieldName]?.fieldType ?? '');
			context.getFieldLabel = overrides.getFieldLabel || ((fieldName) => context.objectInfo?.[fieldName]?.fieldLabel ?? '');
			context.getPicklistValues = overrides.getPicklistValues || (() => []);
			context.getLookupObjectApiName = overrides.getLookupObjectApiName || (() => '');
			return context;
		}

		it('trims an undefined fieldName to empty string via the `|| \\\'\\\'` fallback', () =>
		{
			const context = createMockContextWithMeta({
				isFieldValid: () => true
			});
			const fields = [{fieldName: undefined, fieldType: 'STRING', fieldLabel: 'X', isRequired: false}];
			const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
			expect(result).toHaveLength(1);
			expect(result[0].fieldName).toBe('');
		});

		it('uses explicit picklist values when field.picklistValues has length > 0', () =>
		{
			const {PICKLIST_FIELD_TYPE, PicklistValue} = require('c/createForm');
			const presetValue = new PicklistValue();
			presetValue.label = 'Open';
			presetValue.value = 'Open';
			const context = createMockContextWithMeta({
				objectInfo: {Status: {fieldType: PICKLIST_FIELD_TYPE, fieldLabel: 'Status', lookupObjectApiName: ''}}
			});
			const fields = [{fieldName: 'Status', fieldType: PICKLIST_FIELD_TYPE, fieldLabel: 'Status', isRequired: false, picklistValues: [presetValue]}];
			const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
			expect(result[0].picklistValues).toEqual([presetValue]);
		});

		it('falls back to org picklist values when picklistValues is empty array', () =>
		{
			const {PICKLIST_FIELD_TYPE, PicklistValue} = require('c/createForm');
			const orgValue = new PicklistValue();
			orgValue.label = 'Closed';
			orgValue.value = 'Closed';
			const context = createMockContextWithMeta({
				objectInfo: {Status: {fieldType: PICKLIST_FIELD_TYPE, fieldLabel: 'Status', lookupObjectApiName: ''}}, getPicklistValues: () => [orgValue]
			});
			const fields = [{fieldName: 'Status', fieldType: PICKLIST_FIELD_TYPE, fieldLabel: 'Status', isRequired: false, picklistValues: []}];
			const result = prototype.mapFieldsToDisplayFieldList.call(context, fields);
			expect(result[0].picklistValues).toEqual([orgValue]);
		});
	});

	describe('generateRecord branch coverage', () =>
	{
		const LwcCreateForm = require('c/createForm').default;
		const prototype = LwcCreateForm.prototype;

		it('uses existingRecord fallback when fieldValue is missing', () =>
		{
			const context = {
				fields: [{fieldName: 'Phone', fieldValue: null}], formValueMap: {}, existingRecord: {Phone: '555-1212'}
			};
			Object.defineProperty(context, 'recordInputForCreate', {get: () => ({fields: {}})});
			const result = prototype.generateRecord.call(context);
			expect(result.fields.Phone).toBe('555-1212');
		});

		it('uses EMPTY string when neither fieldValue nor existingRecord has the value', () =>
		{
			const context = {
				fields: [{fieldName: 'Industry', fieldValue: null}], formValueMap: {}, existingRecord: {Industry: null}
			};
			Object.defineProperty(context, 'recordInputForCreate', {get: () => ({fields: {}})});
			const result = prototype.generateRecord.call(context);
			expect(result.fields.Industry).toBe('');
		});

		it('uses EMPTY string when existingRecord is null', () =>
		{
			const context = {
				fields: [{fieldName: 'Industry', fieldValue: null}], formValueMap: {}, existingRecord: null
			};
			Object.defineProperty(context, 'recordInputForCreate', {get: () => ({fields: {}})});
			const result = prototype.generateRecord.call(context);
			expect(result.fields.Industry).toBe('');
		});
	});

	/*
	 * Behavioural-visible correction: a parent-supplied falsy value (0 / false / '')
	 * previously fell through to the existing record value or an empty string; it now
	 * survives into the generated record. Only null/undefined fall back. These tests
	 * document the intended new behaviour for the backward-compat review.
	 */
	describe('generateRecord preserves explicit falsy field values', () =>
	{
		const LwcCreateForm = require('c/createForm').default;
		const prototype = LwcCreateForm.prototype;

		const generateWith = (fields, existingRecord) =>
		{
			const context = {fields, formValueMap: {}, existingRecord};
			Object.defineProperty(context, 'recordInputForCreate', {get: () => ({fields: {}})});
			return prototype.generateRecord.call(context);
		};

		it('keeps an explicit 0 instead of the existing record value', () =>
		{
			const result = generateWith([{fieldName: 'Quantity', fieldValue: 0}], {Quantity: 5});
			expect(result.fields.Quantity).toBe(0);
		});

		it('keeps an explicit false instead of the existing record value', () =>
		{
			const result = generateWith([{fieldName: 'IsActive', fieldValue: false}], {IsActive: true});
			expect(result.fields.IsActive).toBe(false);
		});

		it('keeps an explicit empty string instead of the existing record value', () =>
		{
			const result = generateWith([{fieldName: 'Name', fieldValue: ''}], {Name: 'Existing Value'});
			expect(result.fields.Name).toBe('');
		});

		it('surfaces a falsy existing-record value (0) when no fieldValue is supplied', () =>
		{
			const result = generateWith([{fieldName: 'Quantity'}], {Quantity: 0});
			expect(result.fields.Quantity).toBe(0);
		});

		it('surfaces a false existing-record value when no fieldValue is supplied', () =>
		{
			const result = generateWith([{fieldName: 'IsActive'}], {IsActive: false});
			expect(result.fields.IsActive).toBe(false);
		});
	});
});
