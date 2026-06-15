// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for generateBundleModal LWC component.
 *
 * @author Jason van Beukering
 * @date May 2026, June 2026
 */
import {createElement} from 'lwc';
import GenerateBundleModal from 'c/generateBundleModal';
import {mockClose} from 'lightning/modal';

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const SCOPE_BODY = 'Masks values on Kern framework paths (logs, API calls, async chains, events). This is not encryption-at-rest and does not protect data org-wide.';

const createModal = (overrides = {}) =>
{
	const element = createElement('c-generate-bundle-modal', {is: GenerateBundleModal});
	element.heading = 'Confirm rule activations';
	element.leadParagraph = 'Your bundle will activate 1 dormant rule.';
	element.dormantRuleRows = [
		{key: 'Mask_Phone', message: 'Mask Phone — affects 2 existing active target(s) today.'},
		{key: 'Mask_Email', message: 'Mask Email — affects 0 existing active target(s) today.'}
	];
	element.scopeBody = SCOPE_BODY;
	element.acknowledgeLabel = 'I understand these rules will be activated when this bundle deploys.';
	element.confirmLabel = 'Generate bundle';
	element.cancelLabel = 'Cancel';
	Object.assign(element, overrides);
	document.body.appendChild(element);
	return element;
};

describe('c-generate-bundle-modal', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			expect(GenerateBundleModal).toBeDefined();
			expect(typeof GenerateBundleModal).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const prototype = GenerateBundleModal.prototype;

		const apiProperties = [
			'heading',
			'leadParagraph',
			'dormantRuleRows',
			'scopeBody',
			'acknowledgeLabel',
			'confirmLabel',
			'cancelLabel'
		];

		apiProperties.forEach((name) =>
		{
			it(`has @api ${name} property`, () =>
			{
				expect(Object.getOwnPropertyDescriptor(prototype, name)).toBeDefined();
			});
		});

		it('has confirmDisabled getter', () =>
		{
			const descriptor = Object.getOwnPropertyDescriptor(prototype, 'confirmDisabled');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		[
			'handleAcknowledgeChange',
			'handleConfirm',
			'handleCancel'
		].forEach((name) =>
		{
			it(`has ${name} method`, () =>
			{
				expect(typeof prototype[name]).toBe('function');
			});
		});
	});

	describe('rendered modal', () =>
	{
		it('renders one zebra-table row per dormant rule, keeping the framed zero blast-radius row', async() =>
		{
			const element = createModal();
			await flushPromises();

			const table = element.shadowRoot.querySelector('[data-testid="dormant-rule-table"]');
			expect(table).toBeTruthy();

			const rows = element.shadowRoot.querySelectorAll('[data-testid="dormant-rule-row"]');
			expect(rows).toHaveLength(2);
			expect(rows[0].textContent).toContain('Mask Phone');
			expect(rows[0].textContent).toContain('affects 2 existing active target(s) today');
			expect(rows[1].textContent).toContain('affects 0 existing active target(s) today');
		});

		it('surfaces the framework-path scope statement verbatim', async() =>
		{
			const element = createModal();
			await flushPromises();

			const scopeNote = element.shadowRoot.querySelector('[data-testid="scope-note"]');
			expect(scopeNote).toBeTruthy();
			expect(scopeNote.textContent).toContain(SCOPE_BODY);
		});

		it('renders the heading lead paragraph and button labels', async() =>
		{
			const element = createModal();
			await flushPromises();

			const lead = element.shadowRoot.querySelector('[data-testid="modal-lead-paragraph"]');
			expect(lead.textContent).toContain('Your bundle will activate 1 dormant rule');

			const confirm = element.shadowRoot.querySelector('[data-testid="modal-confirm-button"]');
			const cancel = element.shadowRoot.querySelector('[data-testid="modal-cancel-button"]');
			expect(confirm.label).toBe('Generate bundle');
			expect(cancel.label).toBe('Cancel');
		});

		it('keeps Confirm disabled until acknowledged and re-disables it when unchecked', async() =>
		{
			const element = createModal();
			await flushPromises();

			const confirm = () => element.shadowRoot.querySelector('[data-testid="modal-confirm-button"]');
			const ack = element.shadowRoot.querySelector('[data-testid="modal-acknowledge-checkbox"]');
			expect(confirm().disabled).toBe(true);

			ack.dispatchEvent(new CustomEvent('change', {detail: {checked: true}}));
			await flushPromises();
			expect(confirm().disabled).toBe(false);

			ack.dispatchEvent(new CustomEvent('change', {detail: {checked: false}}));
			await flushPromises();
			expect(confirm().disabled).toBe(true);
		});

		it('closes with a confirm action when Confirm is clicked after acknowledging', async() =>
		{
			const element = createModal();
			await flushPromises();

			const ack = element.shadowRoot.querySelector('[data-testid="modal-acknowledge-checkbox"]');
			ack.dispatchEvent(new CustomEvent('change', {detail: {checked: true}}));
			await flushPromises();

			element.shadowRoot.querySelector('[data-testid="modal-confirm-button"]').click();
			expect(mockClose).toHaveBeenCalledWith({action: 'confirm'});
			expect(mockClose).toHaveBeenCalledTimes(1);
		});

		it('does not close when Confirm is invoked while still unacknowledged', async() =>
		{
			const element = createModal();
			await flushPromises();

			element.shadowRoot.querySelector('[data-testid="modal-confirm-button"]').click();
			expect(mockClose).not.toHaveBeenCalled();
		});

		it('closes with a cancel action when Cancel is clicked', async() =>
		{
			const element = createModal();
			await flushPromises();

			element.shadowRoot.querySelector('[data-testid="modal-cancel-button"]').click();
			expect(mockClose).toHaveBeenCalledWith({action: 'cancel'});
			expect(mockClose).toHaveBeenCalledTimes(1);
		});
	});
});
