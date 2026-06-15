// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the maskingAddRuleMenu LWC — the add-rule menu built on
 *              lightning/modal (LightningModal). It lists the masking rules addable to a field or
 *              object-wide, each with a short description, plus a Create-a-custom-rule footer link.
 *              Picking a rule resolves {pickedRuleDeveloperName}; the footer resolves {action:'createRule'};
 *              Close resolves null. Verified via real DOM rendering with the global lightning/modal mock
 *              (whose close() is a shared jest.fn).
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {createElement} from 'lwc';
import {mockClose} from 'lightning/modal';
import MaskingAddRuleMenu from 'c/maskingAddRuleMenu';

jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Title_Field', () => ({default: 'Add a rule to {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Title_ObjectWide', () => ({default: 'Add an object-wide rule to {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Intro_Field', () => ({default: 'Rules that match this field\'s type. Adding one ticks it into the export package.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Intro_ObjectWide', () => ({default: 'An object-wide rule runs on every field of {0}.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Empty_Field', () => ({default: 'No other template rules match this field\'s type.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Empty_ObjectWide', () => ({default: 'Every template rule is already applied object-wide here.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_AddButton', () => ({default: 'Add'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_CreateCustomRule', () => ({default: 'Create a custom rule'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Close', () => ({default: 'Close'}), {virtual: true});

const SAMPLE_OPTIONS = [
	{value: 'Mask_Card', label: 'Mask Credit Card', subtitle: 'Redacts card-shaped numbers.'},
	{value: 'Mask_SSN', label: 'Mask SSN', subtitle: 'Redacts US social security numbers.'}
];

/**
 * @description Mounts a maskingAddRuleMenu with the supplied @api properties (defaulting to a field menu
 * with two options) and returns the element.
 * @param {Object} [props]
 * @returns {HTMLElement}
 */
function createMenu(props = {})
{
	const element = createElement('c-masking-add-rule-menu', {is: MaskingAddRuleMenu});
	element.menuScope = props.menuScope === undefined ? 'field' : props.menuScope;
	element.objectApiName = props.objectApiName === undefined ? 'Contact' : props.objectApiName;
	element.fieldLabel = props.fieldLabel === undefined ? 'Mailing Street' : props.fieldLabel;
	element.options = props.options === undefined ? SAMPLE_OPTIONS : props.options;
	document.body.appendChild(element);
	return element;
}

/**
 * @description Flushes the LWC microtask render queue.
 * @returns {Promise<void>}
 */
function flush()
{
	return Promise.resolve();
}

afterEach(() =>
{
	while(document.body.firstChild)
	{
		document.body.removeChild(document.body.firstChild);
	}
	jest.clearAllMocks();
});

describe('c-masking-add-rule-menu', () =>
{
	it('titles and introduces a field menu', async() =>
	{
		const element = createMenu({menuScope: 'field', fieldLabel: 'Mailing Street'});
		await flush();
		expect(element.shadowRoot.querySelector('lightning-modal-header').label).toBe('Add a rule to Mailing Street');
		expect(element.shadowRoot.querySelector('[data-testid="menu-intro"]').textContent).toContain('this field\'s type');
	});

	it('titles and introduces an object-wide menu', async() =>
	{
		const element = createMenu({menuScope: 'object', objectApiName: 'ApiCall__c'});
		await flush();
		expect(element.shadowRoot.querySelector('lightning-modal-header').label).toBe('Add an object-wide rule to ApiCall__c');
		expect(element.shadowRoot.querySelector('[data-testid="menu-intro"]').textContent).toContain('ApiCall__c');
	});

	it('lists each addable rule with its label and description', async() =>
	{
		const element = createMenu();
		await flush();
		const items = [...element.shadowRoot.querySelectorAll('[data-testid="menu-item"]')];
		expect(items).toHaveLength(2);
		expect(items[0].textContent).toContain('Mask Credit Card');
		expect(items[0].textContent).toContain('Redacts card-shaped numbers.');
	});

	it('renders the applicable-types line and the no-match warning an option carries', async() =>
	{
		const element = createMenu({
			menuScope: 'object', objectApiName: 'ApiCall__c', options: [
				{
					value: 'Mask_Secret',
					label: 'Mask Secret Keys',
					subtitle: 'Redacts secret-looking JSON keys.',
					appliesTo: 'Applies to Long Text Area',
					warning: 'Won\'t match any field on this object yet'
				},
				{value: 'Mask_Phone', label: 'Mask Phone', subtitle: 'Redacts phone numbers.', appliesTo: 'Applies to Text, Phone', warning: ''}
			]
		});
		await flush();
		const items = [...element.shadowRoot.querySelectorAll('[data-testid="menu-item"]')];
		expect(items[0].querySelector('[data-testid="menu-applies"]').textContent).toContain('Long Text Area');
		expect(items[0].querySelector('[data-testid="menu-warning"]').textContent).toContain('Won\'t match any field');
		// A rule that matches a field on the object carries an applies-to line but no warning.
		expect(items[1].querySelector('[data-testid="menu-applies"]').textContent).toContain('Text, Phone');
		expect(items[1].querySelector('[data-testid="menu-warning"]')).toBeNull();
	});

	it('renders the supersession line an option carries and omits it otherwise', async() =>
	{
		const element = createMenu({
			options: [
				{value: 'Mask_Card', label: 'Mask Credit Card', subtitle: 'Redacts card-shaped numbers.', superseded: 'Superseded by Mask Payment Card Numbers.'},
				{value: 'Mask_SSN', label: 'Mask SSN', subtitle: 'Redacts US social security numbers.', superseded: ''}
			]
		});
		await flush();
		const items = [...element.shadowRoot.querySelectorAll('[data-testid="menu-item"]')];
		expect(items[0].querySelector('[data-testid="menu-superseded"]').textContent).toContain('Superseded by Mask Payment Card Numbers.');
		expect(items[1].querySelector('[data-testid="menu-superseded"]')).toBeNull();
	});

	it('renders the empty state when there are no addable rules', async() =>
	{
		const element = createMenu({menuScope: 'object', options: []});
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="menu-item"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="menu-empty"]').textContent).toContain('already applied object-wide');
	});

	it('renders the empty state when no options collection is supplied', async() =>
	{
		const element = createMenu({menuScope: 'field', options: null});
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="menu-item"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="menu-empty"]').textContent).toContain('this field\'s type');
	});

	it('resolves the picked rule developer name on Add', async() =>
	{
		const element = createMenu();
		await flush();
		element.shadowRoot.querySelectorAll('[data-testid="menu-add"]')[1].click();
		expect(mockClose).toHaveBeenCalledWith({pickedRuleDeveloperName: 'Mask_SSN'});
	});

	it('resolves a create-rule action from the footer link', async() =>
	{
		const element = createMenu();
		await flush();
		element.shadowRoot.querySelector('[data-testid="create-custom-rule"]').click();
		expect(mockClose).toHaveBeenCalledWith({action: 'createRule'});
	});

	it('resolves null on Close', async() =>
	{
		const element = createMenu();
		await flush();
		element.shadowRoot.querySelector('[data-testid="menu-close"]').click();
		expect(mockClose).toHaveBeenCalledWith(null);
	});
});
