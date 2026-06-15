// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the maskingInventoryExportDialog LWC — the regulated-field inventory
 *              export dialog built on lightning/modal (LightningModal). The base modal supplies the chrome +
 *              focus-trap; this dialog lets the administrator pick a scope (custom objects / masked objects /
 *              all objects) and a format (CSV / JSON), fetches that scope's per-object inventory through a
 *              bounded concurrency pool (getRegulatedFieldInventory, one object per call), shows a live
 *              preview of the first rows plus the true row count, and assembles + downloads the file
 *              client-side. The "All objects" scope is gated behind a confirm step because it can mean
 *              hundreds of per-object calls. The fetch/assembly are pure functions of the @api inputs and the
 *              per-object Apex; opening the dialog and previewing a scope change nothing in the org.
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {createElement} from 'lwc';
import {mockClose} from 'lightning/modal';
import MaskingInventoryExportDialog from 'c/maskingInventoryExportDialog';
import getRegulatedFieldInventory from '@salesforce/apex/CTRL_MaskingAdvisor.getRegulatedFieldInventory';

jest.mock('@salesforce/apex/CTRL_MaskingAdvisor.getRegulatedFieldInventory', () => ({default: jest.fn()}), {virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Title', () => ({default: 'Export field inventory'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Intro',
		() => ({default: 'A spreadsheet-ready inventory of fields that hold (or likely hold) regulated data. Read-only: nothing changes in your org.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ScopeHeading', () => ({default: 'Scope'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Scope_Custom', () => ({default: 'Custom objects (scanned)'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Scope_Masked', () => ({default: 'Objects with masking configured'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Scope_All', () => ({default: 'All objects'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ObjectCount_Singular', () => ({default: '{0} object'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ObjectCount_Plural', () => ({default: '{0} objects'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FormatHeading', () => ({default: 'Format'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Format_Csv', () => ({default: 'CSV (spreadsheet)'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Format_Json', () => ({default: 'JSON'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ColumnsHeading_Singular', () => ({default: 'Columns ({0} row in this scope)'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ColumnsHeading_Plural', () => ({default: 'Columns ({0} rows in this scope)'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_MoreRows_Singular', () => ({default: '… {0} more row'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_MoreRows_Plural', () => ({default: '… {0} more rows'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_Object', () => ({default: 'Object'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_Field', () => ({default: 'Field'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_FieldType', () => ({default: 'Field Type'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_LongTextArea', () => ({default: 'Long Text Area'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_SecurityClassification', () => ({default: 'Security Classification'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_ComplianceGroup', () => ({default: 'Compliance Group'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_Sensitivity', () => ({default: 'Sensitivity'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_RecommendedRule', () => ({default: 'Recommended Rule'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_MaskedToday', () => ({default: 'Masked Today'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_HistoryTrackingRecommended', () => ({default: 'History Tracking Recommended'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Cell_Yes', () => ({default: 'Yes'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Cell_No', () => ({default: 'No'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Cell_Empty', () => ({default: '—'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Building_Progress', () => ({default: 'Analyzing {0} of {1} objects…'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_AllScope_ConfirmBody', () => ({default: 'This will analyze all {0} objects and may take a minute.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_AllScope_ConfirmButton', () => ({default: 'Build preview'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_EmptyState', () => ({default: 'No regulated fields in this scope.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_PartialFailure_Singular', () => ({default: '{0} object could not be analyzed and was skipped.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_PartialFailure_Plural', () => ({default: '{0} objects could not be analyzed and were skipped.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_DownloadButton', () => ({default: '⤓ Download {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Close', () => ({default: 'Close'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FileName_Csv', () => ({default: 'regulated-field-inventory.csv'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FileName_Json', () => ({default: 'regulated-field-inventory.json'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Sensitivity_Sensitive', () => ({default: 'Sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Sensitivity_PossiblySensitive', () => ({default: 'Possibly Sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FormatNote', () => ({default: 'CSV uses readable labels; JSON keeps the raw API values.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_MaskedScopeNote',
		() => ({default: 'These objects are masked object-wide, so only independently flagged fields appear here.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_SensitiveOnly', () => ({default: 'Sensitive fields only'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FilteredEmptyState',
		() => ({default: 'No fields are classified Sensitive in this scope. Clear the filter to include possibly-sensitive fields.'}), {virtual: true});
// The shared field-type label helper (c/maskingFieldTypeLabels) imports these; mocked with friendly values so
// the CSV/preview assert the readable field type rather than the raw DisplayType.
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Text', () => ({default: 'Text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_LongText', () => ({default: 'Long Text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Url', () => ({default: 'URL'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Email', () => ({default: 'Email'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Phone', () => ({default: 'Phone'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_EncryptedText', () => ({default: 'Encrypted Text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_AnyText', () => ({default: 'Any text field'}), {virtual: true});

// Two standard, three own-custom (one already masked), one managed-custom. The "custom" scope = the three
// own un-namespaced custom objects; "masked" = the masked-api-names set; "all" = every option.
const OPTIONS = [
	{Id: 'Account', Name: 'Account', isCustom: false, namespacePrefix: null},
	{Id: 'Contact', Name: 'Contact', isCustom: false, namespacePrefix: null},
	{Id: 'CustomerFeedback__c', Name: 'Customer Feedback', isCustom: true, namespacePrefix: null},
	{Id: 'SupportTranscript__c', Name: 'Support Transcript', isCustom: true, namespacePrefix: null},
	{Id: 'DeliveryRoute__c', Name: 'Delivery Route', isCustom: true, namespacePrefix: null},
	{Id: 'blng__PaymentGatewayLog__c', Name: 'Payment Gateway Log', isCustom: true, namespacePrefix: 'blng'}
];
const MASKED = ['CustomerFeedback__c'];

// Per-object inventories the getRegulatedFieldInventory mock returns. CustomerFeedback__c carries a fully
// classified masked field and an unclassified Long Text Area; SupportTranscript__c carries a rule label with
// a comma so the CSV-escaping path is exercised; DeliveryRoute__c is regulated-field-free.
const INVENTORIES = {
	CustomerFeedback__c: {
		objectApiName: 'CustomerFeedback__c', objectLabel: 'Customer Feedback', rows: [
			{
				fieldApiName: 'CustomerEmail__c',
				fieldLabel: 'Customer Email',
				fieldType: 'EMAIL',
				isLongTextArea: false,
				securityClassification: 'Confidential',
				complianceGroup: 'PII',
				sensitivityLevel: 'Sensitive',
				recommendedRuleDeveloperName: 'Mask_Email',
				recommendedRuleLabel: 'Mask Email',
				maskedToday: true,
				historyTrackingRecommended: true
			},
			{
				fieldApiName: 'FeedbackBody__c',
				fieldLabel: 'Feedback Body',
				fieldType: 'TEXTAREA',
				isLongTextArea: true,
				securityClassification: null,
				complianceGroup: null,
				sensitivityLevel: 'PossiblySensitive',
				recommendedRuleDeveloperName: null,
				recommendedRuleLabel: null,
				maskedToday: false,
				historyTrackingRecommended: false
			}
		]
	},
	SupportTranscript__c: {
		objectApiName: 'SupportTranscript__c', objectLabel: 'Support Transcript', rows: [
			{
				fieldApiName: 'TranscriptBody__c',
				fieldLabel: 'Transcript Body',
				fieldType: 'TEXTAREA',
				isLongTextArea: true,
				securityClassification: 'Restricted',
				complianceGroup: 'GDPR',
				sensitivityLevel: 'Sensitive',
				recommendedRuleDeveloperName: 'Mask_FreeText',
				recommendedRuleLabel: 'Mask "Notes", free text',
				maskedToday: false,
				historyTrackingRecommended: true
			}
		]
	},
	DeliveryRoute__c: {objectApiName: 'DeliveryRoute__c', objectLabel: 'Delivery Route', rows: []},
	Account: {objectApiName: 'Account', objectLabel: 'Account', rows: []},
	Contact: {objectApiName: 'Contact', objectLabel: 'Contact', rows: []},
	'blng__PaymentGatewayLog__c': {objectApiName: 'blng__PaymentGatewayLog__c', objectLabel: 'Payment Gateway Log', rows: []}
};

const SCOPE_TESTID = 'inventory-export-scope';
const FORMAT_TESTID = 'inventory-export-format';

function emptyInventory(apiName)
{
	return {objectApiName: apiName, objectLabel: apiName, rows: []};
}

function defaultInventory(apiName)
{
	return INVENTORIES[apiName] || emptyInventory(apiName);
}

/**
 * @description A manually-resolvable promise, for holding a fetch open mid-flight to assert the progress UI.
 * @returns {{promise: Promise, resolve: Function}}
 */
function deferred()
{
	let resolve;
	const promise = new Promise((res) =>
	{
		resolve = res;
	});
	return {promise, resolve};
}

/**
 * @description Drains the LWC render queue and the fetch pool's microtasks.
 * @returns {Promise<void>}
 */
async function settle()
{
	for(let index = 0; index < 12; index += 1)
	{
		// eslint-disable-next-line no-await-in-loop
		await Promise.resolve();
	}
}

/**
 * @description Mounts a maskingInventoryExportDialog with the supplied @api props (defaulting to the
 *              representative universe + masked set above) and settles the default-scope fetch.
 * @param {Object} [props] - @api property overrides.
 * @returns {Promise<HTMLElement>}
 */
async function createDialog(props = {})
{
	const element = createElement('c-masking-inventory-export-dialog', {is: MaskingInventoryExportDialog});
	element.objectOptions = props.objectOptions === undefined ? OPTIONS : props.objectOptions;
	element.maskedApiNames = props.maskedApiNames === undefined ? MASKED : props.maskedApiNames;
	document.body.appendChild(element);
	await settle();
	return element;
}

function radioGroup(element, testId)
{
	return element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
}

async function changeScope(element, value)
{
	radioGroup(element, SCOPE_TESTID).dispatchEvent(new CustomEvent('change', {detail: {value}}));
	await settle();
}

async function changeFormat(element, value)
{
	radioGroup(element, FORMAT_TESTID).dispatchEvent(new CustomEvent('change', {detail: {value}}));
	await settle();
}

async function toggleSensitiveOnly(element, checked)
{
	const checkbox = element.shadowRoot.querySelector('[data-testid="inventory-export-sensitive-only"]');
	checkbox.checked = checked;
	checkbox.dispatchEvent(new CustomEvent('change'));
	await settle();
}

function textOf(element, testId)
{
	const node = element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
	return node ? node.textContent : null;
}

function previewRowCells(element)
{
	return [...element.shadowRoot.querySelectorAll('[data-testid="inventory-export-preview-row"]')]
	.map((row) => [...row.querySelectorAll('td')].map((cell) => cell.textContent));
}

beforeEach(() =>
{
	getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve(defaultInventory(objectApiName)));
});

afterEach(() =>
{
	while(document.body.firstChild)
	{
		document.body.removeChild(document.body.firstChild);
	}
	jest.clearAllMocks();
});

describe('c-masking-inventory-export-dialog — controls + scopes', () =>
{
	it('renders scope and format radio groups with the custom scope and CSV selected by default', async() =>
	{
		const element = await createDialog();
		const scope = radioGroup(element, SCOPE_TESTID);
		const format = radioGroup(element, FORMAT_TESTID);
		expect(scope.value).toBe('custom');
		expect(format.value).toBe('csv');
		expect(scope.options.map((option) => option.value)).toEqual([
			'custom',
			'masked',
			'all'
		]);
		expect(format.options.map((option) => option.value)).toEqual([
			'csv',
			'json'
		]);
	});

	it('labels each scope option with its object count (singular and plural)', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		const labels = radioGroup(element, SCOPE_TESTID).options.map((option) => option.label);
		expect(labels[0]).toBe('Custom objects (scanned) — 3 objects');
		expect(labels[1]).toBe('Objects with masking configured — 1 object');
		expect(labels[2]).toBe('All objects — 6 objects');
	});

	it('auto-fetches the custom scope on open, one call per own custom object', async() =>
	{
		await createDialog();
		const requested = getRegulatedFieldInventory.mock.calls.map((call) => call[0].objectApiName).sort();
		expect(requested).toEqual([
			'CustomerFeedback__c',
			'DeliveryRoute__c',
			'SupportTranscript__c'
		]);
	});

	it('does not request standard or managed objects for the custom scope', async() =>
	{
		await createDialog();
		const requested = getRegulatedFieldInventory.mock.calls.map((call) => call[0].objectApiName);
		expect(requested).not.toContain('Account');
		expect(requested).not.toContain('blng__PaymentGatewayLog__c');
	});

	it('closes with null when Close is clicked', async() =>
	{
		const element = await createDialog();
		element.shadowRoot.querySelector('[data-testid="inventory-export-close"]').click();
		expect(mockClose).toHaveBeenCalledWith(null);
	});
});

describe('c-masking-inventory-export-dialog — live preview', () =>
{
	it('shows the true row count for the scope (plural)', async() =>
	{
		const element = await createDialog();
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (3 rows in this scope)');
	});

	it('shows the singular row-count heading when the scope has exactly one row', async() =>
	{
		const element = await createDialog({maskedApiNames: ['SupportTranscript__c']});
		await changeScope(element, 'masked');
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (1 row in this scope)');
	});

	it('renders the ten column headers in order', async() =>
	{
		const element = await createDialog();
		const headers = [...element.shadowRoot.querySelectorAll('[data-testid="inventory-export-columns"] th')].map((node) => node.textContent);
		expect(headers).toEqual([
			'Object',
			'Field',
			'Field Type',
			'Long Text Area',
			'Security Classification',
			'Compliance Group',
			'Sensitivity',
			'Recommended Rule',
			'Masked Today',
			'History Tracking Recommended'
		]);
	});

	it('omits the native-classification and recommended-rule columns when every row leaves them blank', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({objectApiName, objectLabel: objectApiName, rows: [buildRow(0)]}));
		const element = await createDialog({objectOptions: [{Id: 'PlainCustom__c', Name: 'Plain', isCustom: true, namespacePrefix: null}], maskedApiNames: []});
		const headers = [...element.shadowRoot.querySelectorAll('[data-testid="inventory-export-columns"] th')].map((node) => node.textContent);
		expect(headers).not.toContain('Security Classification');
		expect(headers).not.toContain('Compliance Group');
		expect(headers).not.toContain('Recommended Rule');
		expect(headers).toEqual([
			'Object',
			'Field',
			'Field Type',
			'Long Text Area',
			'Sensitivity',
			'Masked Today',
			'History Tracking Recommended'
		]);
	});

	it('keeps the recommended-rule column while dropping the empty classification columns (partial drop)', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({
			objectApiName, objectLabel: objectApiName, rows: [{...buildRow(0), recommendedRuleLabel: 'Mask Email', recommendedRuleDeveloperName: 'Mask_Email'}]
		}));
		const element = await createDialog({objectOptions: [{Id: 'PlainCustom__c', Name: 'Plain', isCustom: true, namespacePrefix: null}], maskedApiNames: []});
		const headers = [...element.shadowRoot.querySelectorAll('[data-testid="inventory-export-columns"] th')].map((node) => node.textContent);
		expect(headers).not.toContain('Security Classification');
		expect(headers).not.toContain('Compliance Group');
		expect(headers).toContain('Recommended Rule');
	});

	it('renders the CSV/JSON format-contract note', async() =>
	{
		const element = await createDialog();
		expect(textOf(element, 'inventory-export-format-note')).toContain('CSV');
		expect(textOf(element, 'inventory-export-format-note')).toContain('JSON');
	});

	it('explains the masked scope (object-wide masking) only when the masked scope is selected', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-masked-scope-note"]')).toBeNull();
		await changeScope(element, 'masked');
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-masked-scope-note"]')).not.toBeNull();
	});

	it('renders preview rows mapping booleans to Yes/No, nulls to the empty placeholder, and the sensitivity label', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		const cells = previewRowCells(element);
		expect(cells[0]).toEqual([
			'CustomerFeedback__c',
			'CustomerEmail__c',
			'Email',
			'No',
			'Confidential',
			'PII',
			'Sensitive',
			'Mask Email',
			'Yes',
			'Yes'
		]);
		expect(cells[1]).toEqual([
			'CustomerFeedback__c',
			'FeedbackBody__c',
			'Long Text',
			'Yes',
			'—',
			'—',
			'Possibly Sensitive',
			'—',
			'No',
			'No'
		]);
	});

	it('caps the preview at four rows and notes the remainder (plural)', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({
			objectApiName, objectLabel: objectApiName, rows: Array.from({length: 6}, (ignored, index) => buildRow(index))
		}));
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		expect(previewRowCells(element)).toHaveLength(4);
		expect(textOf(element, 'inventory-export-more-rows')).toBe('… 2 more rows');
	});

	it('notes a single remaining row in the singular form', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({
			objectApiName, objectLabel: objectApiName, rows: Array.from({length: 5}, (ignored, index) => buildRow(index))
		}));
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		expect(textOf(element, 'inventory-export-more-rows')).toBe('… 1 more row');
	});

	it('shows the empty state and disables download when the scope has no regulated fields', async() =>
	{
		const element = await createDialog({objectOptions: [{Id: 'DeliveryRoute__c', Name: 'Delivery Route', isCustom: true, namespacePrefix: null}], maskedApiNames: []});
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-empty"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-download"]').disabled).toBe(true);
	});

	it('shows a progress indicator while the scope is being analyzed', async() =>
	{
		const gate = deferred();
		getRegulatedFieldInventory.mockImplementation(() => gate.promise);
		const element = createElement('c-masking-inventory-export-dialog', {is: MaskingInventoryExportDialog});
		element.objectOptions = OPTIONS;
		element.maskedApiNames = MASKED;
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-progress"]')).not.toBeNull();
		gate.resolve(emptyInventory('CustomerFeedback__c'));
		await settle();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-progress"]')).toBeNull();
	});
});

describe('c-masking-inventory-export-dialog — scope switching + caching', () =>
{
	it('fetches the masked scope on demand using the masked api names', async() =>
	{
		const element = await createDialog({
			maskedApiNames: [
				'CustomerFeedback__c',
				'SupportTranscript__c'
			]
		});
		getRegulatedFieldInventory.mockClear();
		await changeScope(element, 'masked');
		const requested = getRegulatedFieldInventory.mock.calls.map((call) => call[0].objectApiName).sort();
		expect(requested).toEqual([
			'CustomerFeedback__c',
			'SupportTranscript__c'
		]);
	});

	it('does not auto-fetch the All scope — it shows a confirm step first', async() =>
	{
		const element = await createDialog();
		getRegulatedFieldInventory.mockClear();
		await changeScope(element, 'all');
		expect(getRegulatedFieldInventory).not.toHaveBeenCalled();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-confirm"]')).not.toBeNull();
		expect(textOf(element, 'inventory-export-confirm')).toContain('all 6 objects');
	});

	it('fetches the All scope only after the confirm button is clicked', async() =>
	{
		const element = await createDialog();
		await changeScope(element, 'all');
		getRegulatedFieldInventory.mockClear();
		element.shadowRoot.querySelector('[data-testid="inventory-export-confirm-button"]').click();
		await settle();
		expect(getRegulatedFieldInventory).toHaveBeenCalledTimes(OPTIONS.length);
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-confirm"]')).toBeNull();
	});

	it('does not re-fetch a scope already loaded when switching back to it', async() =>
	{
		const element = await createDialog({maskedApiNames: ['SupportTranscript__c']});
		await changeScope(element, 'masked');
		const callsAfterMasked = getRegulatedFieldInventory.mock.calls.length;
		await changeScope(element, 'custom');
		await changeScope(element, 'masked');
		expect(getRegulatedFieldInventory.mock.calls.length).toBe(callsAfterMasked);
	});
});

describe('c-masking-inventory-export-dialog — download', () =>
{
	// The pristine document.createElement, captured before any spy, so the per-test spy below wraps the real
	// implementation rather than a previous test's spy (which would recurse).
	const realCreateElement = document.createElement.bind(document);
	let createdAnchors;
	let blobParts;
	let blobTypes;
	let originalBlob;
	let createElementSpy;

	beforeEach(() =>
	{
		createdAnchors = [];
		blobParts = [];
		blobTypes = [];
		createElementSpy = jest.spyOn(document, 'createElement').mockImplementation((tag) =>
		{
			const node = realCreateElement(tag);
			if(tag === 'a')
			{
				node.click = jest.fn();
				createdAnchors.push(node);
			}
			return node;
		});
		window.URL.createObjectURL = jest.fn().mockReturnValue('blob:url');
		window.URL.revokeObjectURL = jest.fn();
		originalBlob = global.Blob;
		global.Blob = jest.fn((parts, options) =>
		{
			blobParts.push(parts.join(''));
			blobTypes.push(options && options.type);
		});
	});

	afterEach(() =>
	{
		createElementSpy.mockRestore();
		global.Blob = originalBlob;
	});

	function clickDownload(element)
	{
		element.shadowRoot.querySelector('[data-testid="inventory-export-download"]').click();
	}

	it('downloads the CSV with the column header row and one escaped data row per field', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		clickDownload(element);
		expect(createdAnchors[0].download).toBe('regulated-field-inventory.csv');
		expect(createdAnchors[0].click).toHaveBeenCalled();
		const body = blobParts[0];
		expect(body.charCodeAt(0)).toBe(0xFEFF);
		expect(body.endsWith('\r\n')).toBe(true);
		const lines = body.slice(1).split('\r\n');
		expect(lines[0])
		.toBe('Object,Field,Field Type,Long Text Area,Security Classification,Compliance Group,Sensitivity,Recommended Rule,Masked Today,History Tracking Recommended');
		expect(lines[1]).toBe('CustomerFeedback__c,CustomerEmail__c,Email,No,Confidential,PII,Sensitive,Mask Email,Yes,Yes');
		expect(lines[2]).toBe('CustomerFeedback__c,FeedbackBody__c,Long Text,Yes,,,Possibly Sensitive,,No,No');
	});

	it('builds the CSV blob with an LWS-allowed MIME type, never text/csv', async() =>
	{
		// Lightning Web Security's URL.createObjectURL distortion throws "Unsupported MIME type" for a text/csv
		// Blob, silently aborting the download. The download attribute still names the file .csv, so the on-disk
		// file is unaffected by the Blob's MIME type. This guards against a regression back to text/csv.
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		clickDownload(element);
		expect(blobTypes[0]).toBe('application/octet-stream');
		expect(blobTypes[0]).not.toBe('text/csv');
	});

	it('frees the object URL after the download', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		clickDownload(element);
		expect(window.URL.revokeObjectURL).toHaveBeenCalledWith('blob:url');
	});

	it('quotes CSV cells containing commas or quotes', async() =>
	{
		const element = await createDialog({maskedApiNames: ['SupportTranscript__c']});
		await changeScope(element, 'masked');
		clickDownload(element);
		const lines = blobParts[0].split('\r\n');
		expect(lines[1]).toContain('"Mask ""Notes"", free text"');
	});

	it('quotes a cell containing a bare carriage return so the CRLF row separator is not torn apart', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({
			objectApiName, objectLabel: objectApiName, rows: [{...buildRow(0), recommendedRuleLabel: 'Line1\rLine2'}]
		}));
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		clickDownload(element);
		expect(blobParts[0]).toContain('"Line1\rLine2"');
	});

	it('neutralizes a formula-triggering cell (CSV injection defense) by prefixing a single quote', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({
			objectApiName, objectLabel: objectApiName, rows: [{...buildRow(0), recommendedRuleLabel: '=SUM(A1)'}]
		}));
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		clickDownload(element);
		const dataLine = blobParts[0].slice(1).split('\r\n')[1];
		expect(dataLine.split(',')).toContain(`'=SUM(A1)`);
	});

	it('downloads JSON with the stable camelCase keys and raw sensitivity / developer-name values', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		await changeFormat(element, 'json');
		clickDownload(element);
		expect(createdAnchors[0].download).toBe('regulated-field-inventory.json');
		const parsed = JSON.parse(blobParts[0]);
		expect(parsed[0]).toEqual({
			objectApiName: 'CustomerFeedback__c',
			fieldApiName: 'CustomerEmail__c',
			fieldType: 'EMAIL',
			isLongTextArea: false,
			securityClassification: 'Confidential',
			complianceGroup: 'PII',
			sensitivityLevel: 'Sensitive',
			recommendedRule: 'Mask_Email',
			maskedToday: true,
			historyTrackingRecommended: true
		});
		expect(parsed[1].securityClassification).toBeNull();
		expect(parsed[1].recommendedRule).toBeNull();
	});

	it('updates the download button label when the format changes and does not re-fetch', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		const callsBefore = getRegulatedFieldInventory.mock.calls.length;
		const downloadButton = element.shadowRoot.querySelector('[data-testid="inventory-export-download"]');
		expect(downloadButton.label).toContain('CSV');
		await changeFormat(element, 'json');
		expect(downloadButton.label).toContain('JSON');
		expect(getRegulatedFieldInventory.mock.calls.length).toBe(callsBefore);
	});

	it('downloads only the Sensitive rows in the CSV when the sensitive-only filter is on', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		await toggleSensitiveOnly(element, true);
		clickDownload(element);
		const lines = blobParts[0].slice(1).split('\r\n');
		expect(lines[1]).toContain('CustomerEmail__c');
		expect(blobParts[0]).not.toContain('FeedbackBody__c');
	});

	it('downloads only the Sensitive rows in the JSON when the sensitive-only filter is on', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		await toggleSensitiveOnly(element, true);
		await changeFormat(element, 'json');
		clickDownload(element);
		const parsed = JSON.parse(blobParts[0]);
		expect(parsed).toHaveLength(1);
		expect(parsed[0].fieldApiName).toBe('CustomerEmail__c');
		expect(parsed[0].sensitivityLevel).toBe('Sensitive');
	});

	it('drops a column only the filtered-out rows filled from the downloaded CSV header, not just the preview', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({
			objectApiName, objectLabel: objectApiName, rows: [
				{...buildRow(0), sensitivityLevel: 'Sensitive', securityClassification: null},
				{...buildRow(1), sensitivityLevel: 'PossiblySensitive', securityClassification: 'Confidential'}
			]
		}));
		const element = await createDialog({objectOptions: [{Id: 'PlainCustom__c', Name: 'Plain', isCustom: true, namespacePrefix: null}], maskedApiNames: []});
		await toggleSensitiveOnly(element, true);
		clickDownload(element);
		const headerLine = blobParts[0].slice(1).split('\r\n')[0];
		expect(headerLine).not.toContain('Security Classification');
	});
});

describe('c-masking-inventory-export-dialog — partial failure', () =>
{
	it('skips objects whose inventory call fails and notes how many were skipped (singular)', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) =>
		{
			if(objectApiName === 'SupportTranscript__c')
			{
				return Promise.reject(new Error('boom'));
			}
			return Promise.resolve(defaultInventory(objectApiName));
		});
		const element = await createDialog();
		expect(textOf(element, 'inventory-export-partial-failure')).toBe('1 object could not be analyzed and was skipped.');
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (2 rows in this scope)');
	});

	it('uses the plural partial-failure form when more than one object fails', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(() => Promise.reject(new Error('boom')));
		const element = await createDialog();
		expect(textOf(element, 'inventory-export-partial-failure')).toBe('3 objects could not be analyzed and were skipped.');
	});

	it('does not show the "no regulated fields" empty state when every object failed', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(() => Promise.reject(new Error('boom')));
		const element = await createDialog();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-empty"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-download"]').disabled).toBe(true);
	});
});

describe('c-masking-inventory-export-dialog — edge cases', () =>
{
	it('renders an unmapped sensitivity level as its raw value', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({
			objectApiName, objectLabel: objectApiName, rows: [{...buildRow(0), sensitivityLevel: 'Confidential'}]
		}));
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		// This row leaves the two classification columns and the recommended rule blank, so they drop — the
		// sensitivity column moves to index 4 (object, field, type, long-text-area, sensitivity).
		expect(previewRowCells(element)[0][4]).toBe('Confidential');
	});

	it('treats a null inventory response as zero rows without counting it as a failure', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) =>
		{
			if(objectApiName === 'SupportTranscript__c')
			{
				return Promise.resolve(null);
			}
			return Promise.resolve(defaultInventory(objectApiName));
		});
		const element = await createDialog();
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (2 rows in this scope)');
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-partial-failure"]')).toBeNull();
	});
});

describe('c-masking-inventory-export-dialog — sensitive-only filter', () =>
{
	function sensitiveOnlyCheckbox(element)
	{
		return element.shadowRoot.querySelector('[data-testid="inventory-export-sensitive-only"]');
	}

	it('defaults the filter off and shows both sensitivity levels', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		expect(sensitiveOnlyCheckbox(element).checked).toBe(false);
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (2 rows in this scope)');
	});

	it('shows the filter control when the scope holds a possibly-sensitive row', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		expect(sensitiveOnlyCheckbox(element)).not.toBeNull();
	});

	it('hides the filter control when every loaded row is already Sensitive', async() =>
	{
		const element = await createDialog({maskedApiNames: ['SupportTranscript__c']});
		await changeScope(element, 'masked');
		expect(sensitiveOnlyCheckbox(element)).toBeNull();
	});

	it('hides the filter control when the scope has no regulated fields at all', async() =>
	{
		const element = await createDialog({objectOptions: [{Id: 'DeliveryRoute__c', Name: 'Delivery Route', isCustom: true, namespacePrefix: null}], maskedApiNames: []});
		expect(sensitiveOnlyCheckbox(element)).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-empty"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-filtered-empty"]')).toBeNull();
	});

	it('filters the preview and row count to Sensitive rows when the filter is on', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		await toggleSensitiveOnly(element, true);
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (1 row in this scope)');
		const cells = previewRowCells(element);
		expect(cells).toHaveLength(1);
		expect(cells[0]).toContain('CustomerEmail__c');
		expect(cells[0]).toContain('Sensitive');
		expect(cells[0]).not.toContain('Possibly Sensitive');
	});

	it('restores all rows when the filter is toggled back off', async() =>
	{
		const element = await createDialog({maskedApiNames: ['CustomerFeedback__c']});
		await changeScope(element, 'masked');
		await toggleSensitiveOnly(element, true);
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (1 row in this scope)');
		await toggleSensitiveOnly(element, false);
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (2 rows in this scope)');
		expect(previewRowCells(element)).toHaveLength(2);
	});

	it('drops a column only the filtered-out rows filled', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({
			objectApiName, objectLabel: objectApiName, rows: [
				{...buildRow(0), sensitivityLevel: 'Sensitive', securityClassification: null},
				{...buildRow(1), sensitivityLevel: 'PossiblySensitive', securityClassification: 'Confidential'}
			]
		}));
		const element = await createDialog({objectOptions: [{Id: 'PlainCustom__c', Name: 'Plain', isCustom: true, namespacePrefix: null}], maskedApiNames: []});
		const headersOff = [...element.shadowRoot.querySelectorAll('[data-testid="inventory-export-columns"] th')].map((node) => node.textContent);
		expect(headersOff).toContain('Security Classification');
		await toggleSensitiveOnly(element, true);
		const headersOn = [...element.shadowRoot.querySelectorAll('[data-testid="inventory-export-columns"] th')].map((node) => node.textContent);
		expect(headersOn).not.toContain('Security Classification');
	});

	it('shows the filtered-empty note (not the scope empty state) and disables download when the filter removes every row', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) => Promise.resolve({objectApiName, objectLabel: objectApiName, rows: [buildRow(0)]}));
		const element = await createDialog({objectOptions: [{Id: 'PlainCustom__c', Name: 'Plain', isCustom: true, namespacePrefix: null}], maskedApiNames: []});
		await toggleSensitiveOnly(element, true);
		const filteredEmpty = element.shadowRoot.querySelector('[data-testid="inventory-export-filtered-empty"]');
		expect(filteredEmpty).not.toBeNull();
		// The note replaces the table in direct response to the toggle, so it is announced like the other dynamic notes.
		expect(filteredEmpty.getAttribute('role')).toBe('status');
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-empty"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-download"]').disabled).toBe(true);
		expect(sensitiveOnlyCheckbox(element)).not.toBeNull();
	});

	it('persists the filter across a scope switch — control hides where every row is Sensitive, restored on return', async() =>
	{
		const element = await createDialog({maskedApiNames: ['SupportTranscript__c']});
		await toggleSensitiveOnly(element, true);
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (2 rows in this scope)');
		await changeScope(element, 'masked');
		// The masked scope is all-Sensitive, so the filter has nothing to remove: the control hides but the flag persists
		// and every (already-Sensitive) row still shows — no data hidden, no filtered-empty note.
		expect(sensitiveOnlyCheckbox(element)).toBeNull();
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (1 row in this scope)');
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-filtered-empty"]')).toBeNull();
		await changeScope(element, 'custom');
		// Back on the mixed scope the control reappears already checked and the filter is still applied.
		expect(sensitiveOnlyCheckbox(element).checked).toBe(true);
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (2 rows in this scope)');
	});

	it('enters the filtered-empty state directly when switching, filter on, to an all-possibly-sensitive scope', async() =>
	{
		getRegulatedFieldInventory.mockImplementation(({objectApiName}) =>
		{
			if(objectApiName === 'PossiblyOnly__c')
			{
				return Promise.resolve({objectApiName, objectLabel: objectApiName, rows: [buildRow(0)]});
			}
			return Promise.resolve({
				objectApiName, objectLabel: objectApiName, rows: [
					{...buildRow(0), sensitivityLevel: 'Sensitive'},
					buildRow(1)
				]
			});
		});
		const element = await createDialog({objectOptions: [{Id: 'MixedCustom__c', Name: 'Mixed', isCustom: true, namespacePrefix: null}], maskedApiNames: ['PossiblyOnly__c']});
		await toggleSensitiveOnly(element, true);
		expect(textOf(element, 'inventory-export-row-count')).toBe('Columns (1 row in this scope)');
		await changeScope(element, 'masked');
		// No further toggle: the persisted filter empties the new scope on arrival, so the distinct note shows, download
		// is disabled, and the control stays visible so the filter remains clearable.
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-filtered-empty"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-download"]').disabled).toBe(true);
		expect(sensitiveOnlyCheckbox(element)).not.toBeNull();
	});
});

// Builds a synthetic regulated-field inventory row for count-driven preview tests.
function buildRow(index)
{
	return {
		fieldApiName: `Field${index}__c`,
		fieldLabel: `Field ${index}`,
		fieldType: 'STRING',
		isLongTextArea: false,
		securityClassification: null,
		complianceGroup: null,
		sensitivityLevel: 'PossiblySensitive',
		recommendedRuleDeveloperName: null,
		recommendedRuleLabel: null,
		maskedToday: false,
		historyTrackingRecommended: false
	};
}
