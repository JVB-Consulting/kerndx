// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the maskingAddObjectDialog LWC — the "＋ Add object" grouped search
 *              dialog built on lightning/modal (LightningModal). The base modal supplies the chrome +
 *              focus-trap; this dialog partitions the full selectable-object universe into four searchable
 *              groups — Needs attention (from the coverage scan), Your custom objects, Standard objects,
 *              and From managed packages — pills flagged objects "No masking" and already-masked objects
 *              "Masked", samples the long standard/managed lists with a "type to narrow" hint (managed
 *              collapsed behind an expander until expanded or searched), and resolves the picked object's
 *              api name via close(apiName); Close resolves null. The grouping/search are pure client-side
 *              partitions of the @api inputs, so the suite drives real DOM rendering with the global
 *              lightning/modal mock (whose close() is a shared jest.fn).
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {createElement} from 'lwc';
import {mockClose} from 'lightning/modal';
import MaskingAddObjectDialog from 'c/maskingAddObjectDialog';

jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_Title', () => ({default: 'Add an object to masking'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_Intro',
		() => ({default: 'Pick the object whose fields you want to review and mask. Opening an object changes nothing in your org.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_SearchPlaceholder', () => ({default: 'Search all objects by name…'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_GroupAttention', () => ({default: 'Needs attention — from your scan'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_GroupOwn', () => ({default: 'Your custom objects'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_GroupStandard', () => ({default: 'Standard objects'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_GroupManaged', () => ({default: 'From managed packages ({0})'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_PillNoMasking', () => ({default: 'No masking'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_PillMasked', () => ({default: 'Masked'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_StandardHint', () => ({default: 'Showing {0} of {1} standard objects — type to narrow.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_ManagedHint', () => ({default: 'Showing {0} of {1} managed-package objects — type to narrow.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_ManagedExpand', () => ({default: 'Show {0} managed-package objects ▸'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_NoMatches', () => ({default: 'No objects match “{0}”.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_Close', () => ({default: 'Close'}), {virtual: true});

// Three standard, two own-custom (one already masked), two managed-custom. CustomerFeedback__c is the one
// flagged object, so it belongs to the attention group and must NOT also appear under "Your custom objects".
const OPTIONS = [
	{Id: 'Account', Name: 'Account', isCustom: false, namespacePrefix: null},
	{Id: 'Contact', Name: 'Contact', isCustom: false, namespacePrefix: null},
	{Id: 'Case', Name: 'Case', isCustom: false, namespacePrefix: null},
	{Id: 'CustomerFeedback__c', Name: 'Customer Feedback', isCustom: true, namespacePrefix: null},
	{Id: 'Invoice__c', Name: 'Invoice', isCustom: true, namespacePrefix: null},
	{Id: 'blng__PaymentGatewayLog__c', Name: 'Payment Gateway Log', isCustom: true, namespacePrefix: 'blng'},
	{Id: 'FSL__ServiceAppointment__c', Name: 'Service Appointment', isCustom: true, namespacePrefix: 'FSL'}
];
const FLAGGED = [{apiName: 'CustomerFeedback__c', objectLabel: 'Customer Feedback', flaggedFields: [{fieldApiName: 'Body__c'}]}];
const MASKED = ['Invoice__c'];

/**
 * @description Mounts a maskingAddObjectDialog with the supplied properties and returns the element. The
 *              three @api inputs default to the representative universe / scan / masked-set above so each
 *              group renders unless a test overrides them.
 * @param {Object} [props] - @api property overrides applied before append.
 * @returns {HTMLElement}
 */
function createDialog(props = {})
{
	const element = createElement('c-masking-add-object-dialog', {is: MaskingAddObjectDialog});
	element.objectOptions = props.objectOptions === undefined ? OPTIONS : props.objectOptions;
	element.flaggedObjects = props.flaggedObjects === undefined ? FLAGGED : props.flaggedObjects;
	element.maskedApiNames = props.maskedApiNames === undefined ? MASKED : props.maskedApiNames;
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

/**
 * @description The api names of every option row inside a named group (or across the whole list when no
 *              group is given), in render order.
 * @param {HTMLElement} element - The mounted dialog.
 * @param {string} [group] - The group suffix (attention|own|standard|managed); omit for all rows.
 * @returns {Array<string>}
 */
function rowApiNames(element, group)
{
	const scope = group ? element.shadowRoot.querySelector(`[data-testid="add-object-group-${group}"]`) : element.shadowRoot;
	if(!scope)
	{
		return [];
	}
	return [...scope.querySelectorAll('[data-testid="add-object-option"]')].map((row) => row.dataset.apiName);
}

/**
 * @description Types a term into the dialog's search input and lets the re-render settle.
 * @param {HTMLElement} element - The mounted dialog.
 * @param {string} term - The search term.
 * @returns {Promise<void>}
 */
async function search(element, term)
{
	const input = element.shadowRoot.querySelector('[data-testid="add-object-search"]');
	input.dispatchEvent(new CustomEvent('change', {detail: {value: term}}));
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

describe('c-masking-add-object-dialog', () =>
{
	describe('chrome', () =>
	{
		it('renders the dialog title on the modal header', async() =>
		{
			const element = createDialog();
			await flush();

			expect(element.shadowRoot.querySelector('lightning-modal-header').label).toBe('Add an object to masking');
		});

		it('renders the intro line and the search input placeholder', async() =>
		{
			const element = createDialog();
			await flush();

			expect(element.shadowRoot.querySelector('[data-testid="add-object-intro"]').textContent)
			.toContain('Pick the object whose fields you want to review and mask');
			expect(element.shadowRoot.querySelector('[data-testid="add-object-search"]').placeholder)
			.toBe('Search all objects by name…');
		});
	});

	describe('groups', () =>
	{
		it('lists the scan-flagged object under "Needs attention" with a "No masking" pill', async() =>
		{
			const element = createDialog();
			await flush();

			expect(rowApiNames(element, 'attention')).toEqual(['CustomerFeedback__c']);
			const pill = element.shadowRoot.querySelector('[data-testid="add-object-group-attention"] [data-testid="add-object-pill"]');
			expect(pill.textContent).toBe('No masking');
			expect(pill.dataset.kind).toBe('attention');
		});

		it('hides the attention group when the scan has not flagged anything', async() =>
		{
			const element = createDialog({flaggedObjects: []});
			await flush();

			expect(element.shadowRoot.querySelector('[data-testid="add-object-group-attention"]')).toBeNull();
		});

		it('lists own un-namespaced custom objects under "Your custom objects", masked ones tagged "Masked"', async() =>
		{
			const element = createDialog();
			await flush();

			expect(rowApiNames(element, 'own')).toEqual(['Invoice__c']);
			const pill = element.shadowRoot.querySelector('[data-testid="add-object-group-own"] [data-testid="add-object-pill"]');
			expect(pill.textContent).toBe('Masked');
			expect(pill.dataset.kind).toBe('masked');
		});

		it('does not repeat a flagged object under "Your custom objects"', async() =>
		{
			const element = createDialog();
			await flush();

			expect(rowApiNames(element, 'own')).not.toContain('CustomerFeedback__c');
		});

		it('lists standard objects with a "type to narrow" hint carrying the shown/total counts', async() =>
		{
			const element = createDialog();
			await flush();

			expect(rowApiNames(element, 'standard')).toEqual([
				'Account',
				'Contact',
				'Case'
			]);
			expect(element.shadowRoot.querySelector('[data-testid="add-object-standard-hint"]').textContent)
			.toBe('Showing 3 of 3 standard objects — type to narrow.');
		});

		it('caps the standard sample and reports the true total in the hint', async() =>
		{
			const standards = Array.from({length: 10}, (unused, index) => ({Id: `Std${index}`, Name: `Std ${index}`, isCustom: false, namespacePrefix: null}));
			const element = createDialog({objectOptions: standards, flaggedObjects: [], maskedApiNames: []});
			await flush();

			expect(rowApiNames(element, 'standard')).toHaveLength(8);
			expect(element.shadowRoot.querySelector('[data-testid="add-object-standard-hint"]').textContent)
			.toBe('Showing 8 of 10 standard objects — type to narrow.');
		});

		it('counts managed objects in the heading and collapses them behind an expander', async() =>
		{
			const element = createDialog();
			await flush();

			expect(element.shadowRoot.querySelector('[data-testid="add-object-group-managed"]').textContent)
			.toContain('From managed packages (2)');
			expect(rowApiNames(element, 'managed')).toEqual([]);
			expect(element.shadowRoot.querySelector('[data-testid="add-object-managed-expand"]').textContent)
			.toBe('Show 2 managed-package objects ▸');
		});

		it('reveals managed objects with a hint once the expander is clicked', async() =>
		{
			const element = createDialog();
			await flush();

			element.shadowRoot.querySelector('[data-testid="add-object-managed-expand"]').click();
			await flush();

			expect(rowApiNames(element, 'managed')).toEqual([
				'blng__PaymentGatewayLog__c',
				'FSL__ServiceAppointment__c'
			]);
			expect(element.shadowRoot.querySelector('[data-testid="add-object-managed-hint"]').textContent)
			.toBe('Showing 2 of 2 managed-package objects — type to narrow.');
			expect(element.shadowRoot.querySelector('[data-testid="add-object-managed-expand"]')).toBeNull();
		});
	});

	describe('search', () =>
	{
		it('filters every group by api name or label, case-insensitively', async() =>
		{
			const element = createDialog();
			await search(element, 'inv');

			expect(rowApiNames(element)).toEqual(['Invoice__c']);
		});

		it('matches on the object label as well as the api name', async() =>
		{
			const element = createDialog();
			await search(element, 'payment gateway');

			expect(rowApiNames(element)).toEqual(['blng__PaymentGatewayLog__c']);
		});

		it('reveals managed matches without needing the expander while a term is active', async() =>
		{
			const element = createDialog();
			await search(element, 'service');

			expect(rowApiNames(element, 'managed')).toEqual(['FSL__ServiceAppointment__c']);
			expect(element.shadowRoot.querySelector('[data-testid="add-object-managed-expand"]')).toBeNull();
		});

		it('shows the no-matches message with the term when nothing matches', async() =>
		{
			const element = createDialog();
			await search(element, 'zzz');

			expect(rowApiNames(element)).toEqual([]);
			expect(element.shadowRoot.querySelector('[data-testid="add-object-empty"]').textContent)
			.toBe('No objects match “zzz”.');
		});
	});

	describe('resolution', () =>
	{
		it('resolves the picked object api name when a row is clicked', async() =>
		{
			const element = createDialog();
			await flush();

			element.shadowRoot.querySelector('[data-testid="add-object-group-own"] [data-testid="add-object-option"]').click();

			expect(mockClose).toHaveBeenCalledWith('Invoice__c');
		});

		it('resolves null when the Close button is clicked', async() =>
		{
			const element = createDialog();
			await flush();

			element.shadowRoot.querySelector('[data-testid="add-object-close"]').click();

			expect(mockClose).toHaveBeenCalledWith(null);
		});
	});

	describe('edge cases', () =>
	{
		it('renders the empty state without error when every input is null', async() =>
		{
			const element = createDialog({objectOptions: null, flaggedObjects: null, maskedApiNames: null});
			await flush();

			expect(rowApiNames(element)).toEqual([]);
			expect(element.shadowRoot.querySelector('[data-testid="add-object-empty"]')).not.toBeNull();
		});

		it('runs the managed filter against null options when a term is active', async() =>
		{
			const element = createDialog({objectOptions: null, flaggedObjects: null, maskedApiNames: null});
			await search(element, 'anything');

			expect(rowApiNames(element, 'managed')).toEqual([]);
		});

		it('renders the literal search term in the no-matches message even with $ replacement patterns', async() =>
		{
			const element = createDialog();
			await search(element, '$&');

			expect(element.shadowRoot.querySelector('[data-testid="add-object-empty"]').textContent).toBe('No objects match “$&”.');
		});

		it('decorates a row without error when the masked set is null', async() =>
		{
			const element = createDialog({
				objectOptions: [{Id: 'Account', Name: 'Account', isCustom: false, namespacePrefix: null}], flaggedObjects: null, maskedApiNames: null
			});
			await flush();

			expect(rowApiNames(element, 'standard')).toEqual(['Account']);
			expect(element.shadowRoot.querySelector('[data-testid="add-object-pill"]')).toBeNull();
		});
	});
});
