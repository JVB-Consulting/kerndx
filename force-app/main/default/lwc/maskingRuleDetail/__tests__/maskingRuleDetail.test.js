// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the maskingRuleDetail LWC — the rule-detail popup built on
 *              lightning/modal (LightningModal). It explains a masking rule (what it masks, applicable
 *              field types, where it's applied), runs a sample-value test via previewWithRule, and — for
 *              a managed rule (an existing target or a candidate) — carries a masked-after-deploy
 *              checkbox. Done resolves {wantActive}; Manage-in-Setup resolves {wantActive, action}; a
 *              read-only object-wide context rule carries no checkbox. Verified via real DOM rendering
 *              with the global lightning/modal mock (whose close() is a shared jest.fn).
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {createElement} from 'lwc';
import {mockClose} from 'lightning/modal';

// The @lwc/jest-transformer rewrites the component's `import previewWithRule from
// '@salesforce/apex/CTRL_MaskingAdvisor.previewWithRule'` into a try/catch whose catch arm
// reads `global.__lwcJestMock_previewWithRule || function previewWithRule(){...}`. Setting that
// global before loading the component drives the preview from the same jest.fn and covers the
// truthy arm; the fallback test below deletes it to cover the default-stub arm.
const APEX_GLOBAL_KEY = '__lwcJestMock_previewWithRule';
let MaskingRuleDetail;
let previewWithRule;

beforeAll(() =>
{
	previewWithRule = jest.fn();
	global[APEX_GLOBAL_KEY] = previewWithRule;
	MaskingRuleDetail = require('c/maskingRuleDetail').default;
});

afterAll(() =>
{
	delete global[APEX_GLOBAL_KEY];
});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Pill_Active', () => ({default: 'Active'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Pill_Inactive', () => ({default: 'Inactive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Pill_NotApplied', () => ({default: 'Not applied'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_WhatItMasks_Heading', () => ({default: 'What it masks'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_NoDescription', () => ({default: 'No description is recorded for this rule.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_TestThisRule_Heading', () => ({default: 'Test this rule'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Test_Prompt', () => ({default: 'Type a value, then select Try a value.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AppliesTo_Heading', () => ({default: 'Applies to field types'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_Heading', () => ({default: 'Where it\'s applied'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_FieldLevel', () => ({default: 'Field-level on {0}.{1}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_ObjectWide', () => ({default: 'Object-wide on {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_FieldCandidate', () => ({default: 'Candidate on {0}.{1}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_ObjectWideCandidate', () => ({default: 'Object-wide candidate on {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_MaskingNothingSuffix', () => ({default: 'currently masking nothing'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_MaskedAfterDeploy_Label', () => ({default: 'Masked / active after deploy'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_StaysMasked', () => ({default: 'After deploy: stays masked.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_Disabled', () => ({default: 'After deploy: masking disabled.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_Reenabled', () => ({default: 'After deploy: re-enabled.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_StaysInactive', () => ({default: 'After deploy: stays inactive.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_Added', () => ({default: 'After deploy: added to masking.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_NotAdded', () => ({default: 'After deploy: not added.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Candidate_Note', () => ({default: 'Ticked rules are created when you export and deploy this package.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_ObjectWideManaged_Note',
		() => ({default: 'This rule is applied object-wide. Tick or untick it in the object-wide coverage banner, or open Setup to edit its pattern.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_ManageInSetup_Link', () => ({default: 'Manage in Setup'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Done', () => ({default: 'Done'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Example_TryButton_Label', () => ({default: 'Try a value'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Example_TryInput_Placeholder', () => ({default: 'Sample value'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Example_TryInput_AriaLabel', () => ({default: 'Sample value to mask'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Example_NoChange_Note', () => ({default: 'This rule didn\'t change that value. Try a value that looks like real data.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Example_PreviewFailed_Note', () => ({default: 'Couldn\'t preview this value. Try again, or check the rule\'s pattern.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Example_JsonHint_Note', () => ({default: 'This rule masks keys inside a JSON payload. Paste JSON to see it redacted.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Text', () => ({default: 'Text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_LongText', () => ({default: 'Long text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Url', () => ({default: 'URL'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Email', () => ({default: 'Email'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Phone', () => ({default: 'Phone'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_EncryptedText', () => ({default: 'Encrypted text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_AnyText', () => ({default: 'Any text field'}), {virtual: true});

/**
 * @description Mounts a maskingRuleDetail with the supplied @api properties, defaulting to an existing
 * active field-level rule, and returns the element.
 * @param {Object} [props] - @api property overrides applied before append.
 * @returns {HTMLElement}
 */
function createDetail(props = {})
{
	const element = createElement('c-masking-rule-detail', {is: MaskingRuleDetail});
	element.ruleLabel = props.ruleLabel === undefined ? 'Mask Credit Card' : props.ruleLabel;
	element.ruleDeveloperName = props.ruleDeveloperName === undefined ? 'Mask_Card' : props.ruleDeveloperName;
	element.ruleDescription = props.ruleDescription === undefined ? 'Redacts card-shaped numbers.' : props.ruleDescription;
	element.ruleActive = props.ruleActive === undefined ? true : props.ruleActive;
	element.applicableFieldTypes = props.applicableFieldTypes === undefined ? [
		'STRING',
		'TEXTAREA'
	] : props.applicableFieldTypes;
	element.origin = props.origin === undefined ? 'active' : props.origin;
	element.scope = props.scope === undefined ? 'F' : props.scope;
	element.objectApiName = props.objectApiName === undefined ? 'Contact' : props.objectApiName;
	element.fieldApiName = props.fieldApiName === undefined ? 'PaymentDetails__c' : props.fieldApiName;
	element.desired = props.desired === undefined ? true : props.desired;
	element.supersededByLabel = props.supersededByLabel === undefined ? '' : props.supersededByLabel;
	document.body.appendChild(element);
	return element;
}

/**
 * @description Flushes the LWC microtask render queue a few times so an awaited Apex mock settles.
 * @returns {Promise<void>}
 */
async function flush()
{
	await Promise.resolve();
	await Promise.resolve();
	await Promise.resolve();
}

/**
 * @description Reads the text content of the element matched by the given test id, or null.
 * @param {HTMLElement} element
 * @param {string} testId
 * @returns {?string}
 */
function textOf(element, testId)
{
	const node = element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
	return node ? node.textContent : null;
}

/**
 * @description Types a sample value into the test input and runs the test button.
 * @param {HTMLElement} element
 * @param {string} value
 * @returns {Promise<void>}
 */
async function runTest(element, value)
{
	const input = element.shadowRoot.querySelector('[data-testid="test-input"]');
	input.value = value;
	input.dispatchEvent(new CustomEvent('change', {detail: {value}, target: {value}}));
	await flush();
	element.shadowRoot.querySelector('[data-testid="test-button"]').click();
	await flush();
}

afterEach(() =>
{
	while(document.body.firstChild)
	{
		document.body.removeChild(document.body.firstChild);
	}
	jest.clearAllMocks();
});

describe('c-masking-rule-detail', () =>
{
	describe('rule body (C1)', () =>
	{
		it('renders the rule label, the active pill, and the description', async() =>
		{
			const element = createDetail({ruleLabel: 'Mask Credit Card', ruleDescription: 'Redacts card numbers.'});
			await flush();

			expect(element.shadowRoot.querySelector('lightning-modal-header').label).toBe('Mask Credit Card');
			const pill = element.shadowRoot.querySelector('[data-testid="rule-pill"]');
			expect(pill.textContent).toBe('Active');
			expect(pill.dataset.on).toBe('true');
			expect(textOf(element, 'what-it-masks')).toBe('Redacts card numbers.');
		});

		it('falls back to a no-description note when the rule has no description', async() =>
		{
			const element = createDetail({ruleDescription: ''});
			await flush();
			expect(textOf(element, 'what-it-masks')).toBe('No description is recorded for this rule.');
		});

		it('renders the supersession note when the rule carries one', async() =>
		{
			const element = createDetail({supersededByLabel: 'Superseded by Mask Payment Card Numbers. Rebind those objects first.'});
			await flush();
			expect(textOf(element, 'superseded-note')).toBe('Superseded by Mask Payment Card Numbers. Rebind those objects first.');
		});

		it('renders no supersession note when the rule carries none', async() =>
		{
			const element = createDetail({});
			await flush();
			expect(element.shadowRoot.querySelector('[data-testid="superseded-note"]')).toBeNull();
		});

		it('maps applicable field types to friendly names', async() =>
		{
			const element = createDetail({
				applicableFieldTypes: [
					'STRING',
					'EMAIL',
					'ENCRYPTEDSTRING'
				]
			});
			await flush();
			expect(textOf(element, 'applies-to')).toBe('Text, Email, Encrypted text');
		});

		it('reads "Any text field" for an unscoped rule', async() =>
		{
			const element = createDetail({applicableFieldTypes: []});
			await flush();
			expect(textOf(element, 'applies-to')).toBe('Any text field');
		});

		it('reads "Any text field" when no applicable types are supplied at all', async() =>
		{
			const element = createDetail({applicableFieldTypes: null});
			await flush();
			expect(textOf(element, 'applies-to')).toBe('Any text field');
		});

		it('falls back to the raw type name for a type with no friendly label', async() =>
		{
			const element = createDetail({
				applicableFieldTypes: [
					'STRING',
					'DATETIME'
				]
			});
			await flush();
			expect(textOf(element, 'applies-to')).toBe('Text, DATETIME');
		});

		it('renders the object-wide candidate where-line', async() =>
		{
			const element = createDetail({scope: 'O', origin: 'candidate', objectApiName: 'ApiCall__c'});
			await flush();
			expect(textOf(element, 'where-applied')).toBe('Object-wide candidate on ApiCall__c');
		});

		it('renders the pill in its off styling for an applied rule whose rule is itself inactive', async() =>
		{
			const element = createDetail({origin: 'active', ruleActive: false});
			await flush();
			expect(element.shadowRoot.querySelector('[data-testid="rule-pill"]').dataset.on).toBe('false');
		});

		it('renders the field-level where-line for a field rule', async() =>
		{
			const element = createDetail({scope: 'F', origin: 'active', objectApiName: 'Contact', fieldApiName: 'SSN__c'});
			await flush();
			expect(textOf(element, 'where-applied')).toBe('Field-level on Contact.SSN__c');
		});

		it('appends the masking-nothing suffix for an inactive rule', async() =>
		{
			const element = createDetail({scope: 'F', origin: 'inactive', desired: false, objectApiName: 'Contact', fieldApiName: 'SSN__c'});
			await flush();
			expect(textOf(element, 'where-applied')).toBe('Field-level on Contact.SSN__c — currently masking nothing');
		});

		it('renders the object-wide where-line for an object-wide rule', async() =>
		{
			const element = createDetail({scope: 'O', origin: 'active', objectApiName: 'ApiCall__c', fieldApiName: 'RequestBody__c'});
			await flush();
			expect(textOf(element, 'where-applied')).toBe('Object-wide on ApiCall__c');
		});

		it('renders the candidate where-line and the not-applied pill for a candidate', async() =>
		{
			const element = createDetail({scope: 'F', origin: 'candidate', objectApiName: 'Contact', fieldApiName: 'MailingStreet'});
			await flush();
			expect(textOf(element, 'rule-pill')).toBe('Not applied');
			expect(textOf(element, 'where-applied')).toBe('Candidate on Contact.MailingStreet');
		});

		it('shows the candidate footer note and no Manage-in-Setup link for a candidate', async() =>
		{
			const element = createDetail({origin: 'candidate'});
			await flush();
			expect(textOf(element, 'candidate-note')).toContain('created when you export');
			expect(element.shadowRoot.querySelector('[data-testid="manage-in-setup"]')).toBeNull();
		});

		it('shows the Manage-in-Setup link for an applied rule', async() =>
		{
			const element = createDetail({origin: 'active'});
			await flush();
			expect(element.shadowRoot.querySelector('[data-testid="manage-in-setup"]')).not.toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="candidate-note"]')).toBeNull();
		});

		it('renders no checkbox and a read-only note for a context (object-wide) rule', async() =>
		{
			const element = createDetail({origin: 'context', scope: 'O'});
			await flush();
			expect(element.shadowRoot.querySelector('[data-testid="masked-after-deploy"]')).toBeNull();
			expect(textOf(element, 'object-wide-managed-note')).toContain('applied object-wide');
			expect(element.shadowRoot.querySelector('[data-testid="manage-in-setup"]')).not.toBeNull();
		});
	});

	describe('test this rule (C2)', () =>
	{
		it('runs previewWithRule with the object, field, rule, and value', async() =>
		{
			previewWithRule.mockResolvedValue({maskedValue: '•••• 1111', failedRuleDeveloperNames: [], expectsJsonInput: false});
			const element = createDetail({objectApiName: 'Contact', fieldApiName: 'PaymentDetails__c', ruleDeveloperName: 'Mask_Card'});
			await flush();

			await runTest(element, '4111 1111 1111 1111');

			expect(previewWithRule)
			.toHaveBeenCalledWith({objectApiName: 'Contact', fieldApiName: 'PaymentDetails__c', ruleDeveloperName: 'Mask_Card', value: '4111 1111 1111 1111'});
			expect(textOf(element, 'test-masked')).toContain('•••• 1111');
		});

		it('shows a no-change note when the rule leaves the value unchanged', async() =>
		{
			previewWithRule.mockResolvedValue({maskedValue: 'hello', failedRuleDeveloperNames: [], expectsJsonInput: false});
			const element = createDetail();
			await flush();

			await runTest(element, 'hello');

			expect(textOf(element, 'test-message')).toContain('didn\'t change that value');
			expect(element.shadowRoot.querySelector('[data-testid="test-masked"]')).toBeNull();
		});

		it('shows the JSON hint when an unchanged value comes from a JSON-keyed rule', async() =>
		{
			previewWithRule.mockResolvedValue({maskedValue: 'plain', failedRuleDeveloperNames: [], expectsJsonInput: true});
			const element = createDetail();
			await flush();

			await runTest(element, 'plain');

			expect(textOf(element, 'test-message')).toContain('JSON payload');
		});

		it('shows a failure note when the preview errors', async() =>
		{
			previewWithRule.mockRejectedValue(new Error('boom'));
			const element = createDetail();
			await flush();

			await runTest(element, 'whatever');

			expect(textOf(element, 'test-message')).toContain('Couldn\'t preview');
		});

		it('shows a failure note when the rule failed to run', async() =>
		{
			previewWithRule.mockResolvedValue({maskedValue: 'x', failedRuleDeveloperNames: ['Mask_Card'], expectsJsonInput: false});
			const element = createDetail();
			await flush();

			await runTest(element, 'x');

			expect(textOf(element, 'test-message')).toContain('Couldn\'t preview');
		});

		it('prompts and does not call the controller for an empty value', async() =>
		{
			const element = createDetail();
			await flush();

			element.shadowRoot.querySelector('[data-testid="test-button"]').click();
			await flush();

			expect(previewWithRule).not.toHaveBeenCalled();
			expect(textOf(element, 'test-message')).toContain('Type a value');
		});
	});

	describe('masked-after-deploy checkbox + resolution (C3)', () =>
	{
		it('seeds the checkbox from the desired state and resolves it unchanged on Done', async() =>
		{
			const element = createDetail({origin: 'active', desired: true});
			await flush();

			expect(element.shadowRoot.querySelector('[data-testid="masked-after-deploy"]').checked).toBe(true);
			expect(textOf(element, 'after-deploy-note')).toBe('After deploy: stays masked.');

			element.shadowRoot.querySelector('[data-testid="done-button"]').click();
			expect(mockClose).toHaveBeenCalledWith({wantActive: true});
		});

		it('flips wantActive and the after-deploy note when the checkbox is toggled', async() =>
		{
			const element = createDetail({origin: 'active', desired: true});
			await flush();

			const box = element.shadowRoot.querySelector('[data-testid="masked-after-deploy"]');
			box.checked = false;
			box.dispatchEvent(new CustomEvent('change', {target: {checked: false}}));
			await flush();

			expect(textOf(element, 'after-deploy-note')).toBe('After deploy: masking disabled.');
			element.shadowRoot.querySelector('[data-testid="done-button"]').click();
			expect(mockClose).toHaveBeenCalledWith({wantActive: false});
		});

		it('reads the re-enable note for a ticked inactive rule', async() =>
		{
			const element = createDetail({origin: 'inactive', desired: false});
			await flush();

			const box = element.shadowRoot.querySelector('[data-testid="masked-after-deploy"]');
			box.checked = true;
			box.dispatchEvent(new CustomEvent('change', {target: {checked: true}}));
			await flush();

			expect(textOf(element, 'after-deploy-note')).toBe('After deploy: re-enabled.');
		});

		it('reads the added note for a ticked candidate', async() =>
		{
			const element = createDetail({origin: 'candidate', desired: true});
			await flush();
			expect(textOf(element, 'after-deploy-note')).toBe('After deploy: added to masking.');
		});

		it('reads the not-added note for an unticked candidate', async() =>
		{
			const element = createDetail({origin: 'candidate', desired: false});
			await flush();
			expect(textOf(element, 'after-deploy-note')).toBe('After deploy: not added.');
		});

		it('reads the stays-inactive note for an unticked inactive rule', async() =>
		{
			const element = createDetail({origin: 'inactive', desired: false});
			await flush();
			expect(textOf(element, 'after-deploy-note')).toBe('After deploy: stays inactive.');
		});

		it('resolves a manage-setup action alongside the desired state', async() =>
		{
			const element = createDetail({origin: 'active', desired: true});
			await flush();

			element.shadowRoot.querySelector('[data-testid="manage-in-setup"]').click();
			expect(mockClose).toHaveBeenCalledWith({wantActive: true, action: 'manageSetup'});
		});

		it('resolves the seed unchanged for a read-only context rule with no checkbox', async() =>
		{
			const element = createDetail({origin: 'context', scope: 'O', desired: true});
			await flush();

			element.shadowRoot.querySelector('[data-testid="manage-in-setup"]').click();
			expect(mockClose).toHaveBeenCalledWith({wantActive: true, action: 'manageSetup'});
		});
	});

	describe('apex import fallback (transformer)', () =>
	{
		it('falls back to the transformer default stub when no global mock is registered', () =>
		{
			delete global[APEX_GLOBAL_KEY];
			let Fresh;
			jest.isolateModules(() =>
			{
				Fresh = require('c/maskingRuleDetail').default;
			});
			global[APEX_GLOBAL_KEY] = previewWithRule;

			expect(typeof Fresh).toBe('function');
		});
	});
});
