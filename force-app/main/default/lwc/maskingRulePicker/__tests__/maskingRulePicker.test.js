// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the maskingRulePicker LWC primitive — a custom,
 *              searchable ARIA 1.2 combobox/listbox used as the per-field masking-rule
 *              dropdown. Verified through real DOM rendering (createElement + shadowRoot)
 *              because the component is a standalone primitive (no ComponentBuilder mixin),
 *              so its template resolves under sfdx-lwc-jest. Covers structure, ARIA wiring,
 *              selection marking, the rulechange contract, debounced type-ahead filtering
 *              (including the not-before-window and keystroke-coalescing properties),
 *              keyboard navigation (arrows / Home / End / Enter / Escape), focus-out and
 *              mouse dismissal, the disabled guard, the announced no-matches state, and a
 *              500-option scale check.
 *
 * @author Jason van Beukering
 * @date May 2026, June 2026
 */
import {createElement} from 'lwc';
import MaskingRulePicker, {FILTER_DELAY} from 'c/maskingRulePicker';

jest.mock('@salesforce/label/c.DataMaskingAdvisor_RulePicker_Label', () => ({default: 'Masking rule'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RulePicker_Placeholder', () => ({default: 'Search rules'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RulePicker_NoMatches', () => ({default: 'No matching rules'}), {virtual: true});

/**
 * @description Builds a fresh rule-option list for each test so no test mutates a shared
 * fixture (kerndx/no-mutating-shared-fixture).
 * @returns {Array<{value: string, label: string, category: string}>}
 */
function ruleOptions()
{
	return [
		{value: 'MaskEmail', label: 'Mask Email Addresses', category: 'Contact'},
		{value: 'MaskCreditCard', label: 'Mask Credit Card Numbers', category: 'Payment'},
		{value: 'MaskFreeText', label: 'Mask Free Text', category: ''}
	];
}

/**
 * @description Mounts a maskingRulePicker with the supplied properties and returns the element.
 * @param {Object} [props] - @api property overrides applied before append.
 * @returns {HTMLElement}
 */
function createPicker(props = {})
{
	const element = createElement('c-masking-rule-picker', {is: MaskingRulePicker});
	element.options = props.options === undefined ? ruleOptions() : props.options;
	if(props.value !== undefined)
	{
		element.value = props.value;
	}
	if(props.label !== undefined)
	{
		element.label = props.label;
	}
	if(props.disabled !== undefined)
	{
		element.disabled = props.disabled;
	}
	document.body.appendChild(element);
	return element;
}

/**
 * @description The combobox input within a mounted picker.
 * @param {HTMLElement} element
 * @returns {HTMLInputElement}
 */
function comboboxOf(element)
{
	return element.shadowRoot.querySelector('input[role="combobox"]');
}

/**
 * @description The rendered option elements within a mounted picker.
 * @param {HTMLElement} element
 * @returns {HTMLElement[]}
 */
function optionsOf(element)
{
	return [...element.shadowRoot.querySelectorAll('[role="option"]')];
}

/**
 * @description Dispatches a keydown carrying the given key onto an input.
 * @param {HTMLElement} input
 * @param {string} key
 */
function pressKey(input, key)
{
	input.dispatchEvent(new KeyboardEvent('keydown', {key, bubbles: true}));
}

/**
 * @description Chooses an option the way the component listens for it — a cancelable mousedown
 * (the component commits on mousedown + preventDefault to keep focus on the input).
 * @param {HTMLElement} option
 */
function chooseOption(option)
{
	option.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, cancelable: true}));
}

/**
 * @description Types a term into the input and lets the debounce window elapse.
 * @param {HTMLInputElement} input
 * @param {string} term
 */
function typeAndSettle(input, term)
{
	input.value = term;
	input.dispatchEvent(new CustomEvent('input'));
	jest.advanceTimersByTime(FILTER_DELAY);
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
	jest.clearAllTimers();
	jest.useRealTimers();
});

describe('c-masking-rule-picker', () =>
{
	describe('combobox structure (ARIA 1.2)', () =>
	{
		it('renders a role=combobox input wired to a role=listbox popup', async() =>
		{
			const element = createPicker();
			await flush();

			const input = comboboxOf(element);
			const listbox = element.shadowRoot.querySelector('[role="listbox"]');

			expect(input).not.toBeNull();
			expect(listbox).not.toBeNull();
			expect(input.getAttribute('aria-haspopup')).toBe('listbox');
			expect(input.getAttribute('aria-autocomplete')).toBe('list');
			expect(input.getAttribute('aria-expanded')).toBe('false');
			expect(input.getAttribute('aria-controls')).toBe(listbox.id);
		});

		it('renders one role=option per supplied rule, each with a unique id and value', async() =>
		{
			const element = createPicker();
			await flush();

			const options = optionsOf(element);
			expect(options).toHaveLength(3);
			expect(options[0].dataset.value).toBe('MaskEmail');
			expect(options[0].id).toBeTruthy();
			expect(options[0].textContent).toContain('Mask Email Addresses');
			expect(new Set(options.map((option) => option.id)).size).toBe(3);
		});

		it('reports aria-activedescendant empty while closed', async() =>
		{
			const element = createPicker();
			await flush();
			expect(comboboxOf(element).getAttribute('aria-activedescendant')).toBe('');
		});

		it('exposes options and value as readable @api properties', async() =>
		{
			const element = createPicker({value: 'MaskEmail'});
			await flush();

			expect(element.options).toHaveLength(3);
			expect(element.options[0].value).toBe('MaskEmail');
			expect(element.value).toBe('MaskEmail');
		});

		it('marks every option aria-selected=false when no value is set', async() =>
		{
			const element = createPicker();
			await flush();
			expect(optionsOf(element).every((option) => option.getAttribute('aria-selected') === 'false')).toBe(true);
		});
	});

	describe('selection marking', () =>
	{
		it('marks the option matching value with aria-selected=true and a checkmark', async() =>
		{
			const element = createPicker({value: 'MaskCreditCard'});
			await flush();

			const selected = optionsOf(element).find((option) => option.dataset.value === 'MaskCreditCard');
			const unselected = optionsOf(element).find((option) => option.dataset.value === 'MaskEmail');

			expect(selected.getAttribute('aria-selected')).toBe('true');
			expect(selected.querySelector('.rule-picker__selected-check')).not.toBeNull();
			expect(unselected.getAttribute('aria-selected')).toBe('false');
			expect(unselected.querySelector('.rule-picker__selected-check')).toBeNull();
		});

		it('shows the selected option label in the input when value is preset', async() =>
		{
			const element = createPicker({value: 'MaskEmail'});
			await flush();
			expect(comboboxOf(element).value).toBe('Mask Email Addresses');
		});

		it('updates the input text and selection marking when value is set after mount', async() =>
		{
			const element = createPicker();
			await flush();

			element.value = 'MaskCreditCard';
			await flush();

			expect(comboboxOf(element).value).toBe('Mask Credit Card Numbers');
			const selected = optionsOf(element).find((option) => option.dataset.value === 'MaskCreditCard');
			expect(selected.getAttribute('aria-selected')).toBe('true');
		});

		it('clears the selection and input text when value is set to null', async() =>
		{
			const element = createPicker({value: 'MaskEmail'});
			await flush();

			element.value = null;
			await flush();

			expect(element.value).toBeNull();
			expect(comboboxOf(element).value).toBe('');
			expect(optionsOf(element).some((option) => option.getAttribute('aria-selected') === 'true')).toBe(false);
		});
	});

	describe('category secondary line', () =>
	{
		it('renders a category line for categorized rules and none for a blank category', async() =>
		{
			const element = createPicker();
			await flush();

			const withCategory = optionsOf(element).find((option) => option.dataset.value === 'MaskEmail');
			const withoutCategory = optionsOf(element).find((option) => option.dataset.value === 'MaskFreeText');

			expect(withCategory.querySelector('.rulepick__opt-cat').textContent).toBe('Contact');
			expect(withoutCategory.querySelector('.rulepick__opt-cat')).toBeNull();
		});
	});

	describe('rulechange contract', () =>
	{
		it('fires a non-bubbling rulechange with exactly {value} and updates the input on a mouse choice', async() =>
		{
			const element = createPicker();
			await flush();
			const handler = jest.fn();
			element.addEventListener('rulechange', handler);

			chooseOption(optionsOf(element).find((option) => option.dataset.value === 'MaskCreditCard'));
			await flush();

			expect(handler).toHaveBeenCalledTimes(1);
			const event = handler.mock.calls[0][0];
			expect(event.detail).toEqual({value: 'MaskCreditCard'});
			expect(event.bubbles).toBe(false);
			expect(event.composed).toBe(false);
			expect(comboboxOf(element).value).toBe('Mask Credit Card Numbers');
		});

		it('collapses the popup after a selection', async() =>
		{
			const element = createPicker();
			await flush();

			const input = comboboxOf(element);
			input.click();
			await flush();
			expect(input.getAttribute('aria-expanded')).toBe('true');

			chooseOption(element.shadowRoot.querySelector('[role="option"]'));
			await flush();
			expect(input.getAttribute('aria-expanded')).toBe('false');
		});
	});

	describe('keyboard navigation', () =>
	{
		it('opens on ArrowDown and points aria-activedescendant at the first option', async() =>
		{
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);

			pressKey(input, 'ArrowDown');
			await flush();

			expect(input.getAttribute('aria-expanded')).toBe('true');
			expect(input.getAttribute('aria-activedescendant')).toBe(optionsOf(element)[0].id);
		});

		it('clamps the active option at the first and last entries', async() =>
		{
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);
			const options = optionsOf(element);

			pressKey(input, 'ArrowDown');
			pressKey(input, 'ArrowUp');
			await flush();
			expect(input.getAttribute('aria-activedescendant')).toBe(options[0].id);

			pressKey(input, 'ArrowDown');
			pressKey(input, 'ArrowDown');
			pressKey(input, 'ArrowDown');
			await flush();
			expect(input.getAttribute('aria-activedescendant')).toBe(options[2].id);
		});

		it('jumps to the first option on Home and the last on End', async() =>
		{
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);
			const options = optionsOf(element);

			pressKey(input, 'End');
			await flush();
			expect(input.getAttribute('aria-activedescendant')).toBe(options[2].id);

			pressKey(input, 'Home');
			await flush();
			expect(input.getAttribute('aria-activedescendant')).toBe(options[0].id);
		});

		it('selects the active option on Enter, fires rulechange, and updates the input', async() =>
		{
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);
			const handler = jest.fn();
			element.addEventListener('rulechange', handler);

			pressKey(input, 'ArrowDown');
			pressKey(input, 'Enter');
			await flush();

			expect(handler).toHaveBeenCalledTimes(1);
			expect(handler.mock.calls[0][0].detail.value).toBe('MaskEmail');
			expect(input.getAttribute('aria-expanded')).toBe('false');
			expect(input.value).toBe('Mask Email Addresses');
		});

		it('ignores Enter when the menu is closed and nothing is active', async() =>
		{
			const element = createPicker();
			await flush();
			const handler = jest.fn();
			element.addEventListener('rulechange', handler);

			pressKey(comboboxOf(element), 'Enter');
			await flush();

			expect(handler).not.toHaveBeenCalled();
		});

		it('closes on Escape, restores the selection, and re-opens to the full list', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker({value: 'MaskEmail'});
			await flush();
			const input = comboboxOf(element);

			pressKey(input, 'ArrowDown');
			typeAndSettle(input, 'cred');
			await flush();

			pressKey(input, 'Escape');
			await flush();
			expect(input.getAttribute('aria-expanded')).toBe('false');
			expect(input.value).toBe('Mask Email Addresses');

			pressKey(input, 'ArrowDown');
			await flush();
			const options = optionsOf(element);
			expect(options).toHaveLength(3);
			expect(options.find((option) => option.dataset.value === 'MaskEmail').getAttribute('aria-selected')).toBe('true');
		});

		it('drops the active descendant when options shrink below the active index', async() =>
		{
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);

			pressKey(input, 'End');
			await flush();
			expect(input.getAttribute('aria-activedescendant')).toBe(optionsOf(element)[2].id);

			element.options = [{value: 'MaskEmail', label: 'Mask Email Addresses', category: 'Contact'}];
			await flush();

			expect(input.getAttribute('aria-activedescendant')).toBe('');
		});
	});

	describe('debounced type-ahead filtering', () =>
	{
		it('does not filter until the debounce window elapses', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);

			input.value = 'credit';
			input.dispatchEvent(new CustomEvent('input'));
			jest.advanceTimersByTime(FILTER_DELAY - 1);
			await flush();
			expect(optionsOf(element)).toHaveLength(3);

			jest.advanceTimersByTime(1);
			await flush();
			expect(optionsOf(element)).toHaveLength(1);
		});

		it('coalesces rapid keystrokes into a single filter on the final term', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);

			for(const term of [
				'c',
				'cr',
				'cred',
				'credit'
			])
			{
				input.value = term;
				input.dispatchEvent(new CustomEvent('input'));
				jest.advanceTimersByTime(FILTER_DELAY - 50);
			}
			await flush();
			expect(optionsOf(element)).toHaveLength(3);

			jest.advanceTimersByTime(FILTER_DELAY);
			await flush();
			expect(optionsOf(element).map((option) => option.dataset.value)).toEqual(['MaskCreditCard']);
		});

		it('clears a stale active option when the debounce shrinks the list beneath it', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);

			input.value = 'credit';
			input.dispatchEvent(new CustomEvent('input'));
			pressKey(input, 'ArrowDown');
			pressKey(input, 'ArrowDown');
			await flush();
			expect(input.getAttribute('aria-activedescendant')).toBe(optionsOf(element)[1].id);

			jest.advanceTimersByTime(FILTER_DELAY);
			await flush();
			expect(optionsOf(element)).toHaveLength(1);
			expect(input.getAttribute('aria-activedescendant')).toBe('');
		});

		it('filters options by label after the debounce window', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker();
			await flush();

			typeAndSettle(comboboxOf(element), 'credit');
			await flush();

			expect([...element.shadowRoot.querySelectorAll('.rulepick__opt-label')].map((node) => node.textContent))
			.toEqual(['Mask Credit Card Numbers']);
		});

		it('filters options by category as well as label', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker();
			await flush();

			typeAndSettle(comboboxOf(element), 'payment');
			await flush();

			expect(optionsOf(element).map((option) => option.dataset.value)).toEqual(['MaskCreditCard']);
		});

		it('matches a term against one option\'s label and another\'s category (union, not intersection)', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker({
				options: [
					{value: 'RuleA', label: 'Contact form mask', category: 'Personal'},
					{value: 'RuleB', label: 'Mask phone number', category: 'Contact'}
				]
			});
			await flush();

			typeAndSettle(comboboxOf(element), 'contact');
			await flush();

			expect(optionsOf(element).map((option) => option.dataset.value).sort()).toEqual([
				'RuleA',
				'RuleB'
			]);
		});

		it('announces a no-matches status and renders no options when nothing matches', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker();
			await flush();
			const input = comboboxOf(element);

			typeAndSettle(input, 'zzzzz');
			await flush();

			expect(optionsOf(element)).toHaveLength(0);
			const empty = element.shadowRoot.querySelector('.rulepick__empty');
			expect(empty.getAttribute('role')).toBe('status');
			expect(empty.getAttribute('aria-live')).toBe('polite');
			expect(empty.textContent).toBe('No matching rules');

			pressKey(input, 'ArrowDown');
			await flush();
			expect(input.getAttribute('aria-activedescendant')).toBe('');
		});

		it('narrows a 500-option list down to the matching subset', async() =>
		{
			jest.useFakeTimers();
			const many = Array.from({length: 500}, (unused, index) => ({
				value: `Rule${index}`, label: `Mask Rule ${String(index).padStart(3, '0')}`, category: 'Bulk'
			}));
			const element = createPicker({options: many});
			await flush();
			expect(optionsOf(element)).toHaveLength(500);

			typeAndSettle(comboboxOf(element), 'Rule 037');
			await flush();
			expect(optionsOf(element)).toHaveLength(1);
		});
	});

	describe('dismissal and disabled state', () =>
	{
		it('closes and restores the selection when the pointer leaves', async() =>
		{
			const element = createPicker({value: 'MaskEmail'});
			await flush();
			const input = comboboxOf(element);

			pressKey(input, 'ArrowDown');
			await flush();
			expect(input.getAttribute('aria-expanded')).toBe('true');

			element.shadowRoot.querySelector('.rulepick').dispatchEvent(new CustomEvent('mouseleave'));
			await flush();
			expect(input.getAttribute('aria-expanded')).toBe('false');
			expect(input.value).toBe('Mask Email Addresses');
		});

		it('does nothing when the pointer leaves an already-closed picker', async() =>
		{
			const element = createPicker();
			await flush();

			element.shadowRoot.querySelector('.rulepick').dispatchEvent(new CustomEvent('mouseleave'));
			await flush();
			expect(comboboxOf(element).getAttribute('aria-expanded')).toBe('false');
		});

		it('closes when focus leaves the control', async() =>
		{
			const element = createPicker({value: 'MaskEmail'});
			await flush();
			const input = comboboxOf(element);

			pressKey(input, 'ArrowDown');
			await flush();
			expect(input.getAttribute('aria-expanded')).toBe('true');

			element.shadowRoot.querySelector('.rulepick').dispatchEvent(new CustomEvent('focusout'));
			await flush();
			expect(input.getAttribute('aria-expanded')).toBe('false');
			expect(input.value).toBe('Mask Email Addresses');
		});

		it('does not open when disabled', async() =>
		{
			const element = createPicker({disabled: true});
			await flush();
			const input = comboboxOf(element);

			expect(input.disabled).toBe(true);
			input.click();
			pressKey(input, 'ArrowDown');
			await flush();
			expect(input.getAttribute('aria-expanded')).toBe('false');
		});

		it('does not open or filter when typing in a disabled picker', async() =>
		{
			jest.useFakeTimers();
			const element = createPicker({disabled: true});
			await flush();
			const input = comboboxOf(element);

			typeAndSettle(input, 'credit');
			await flush();

			expect(input.getAttribute('aria-expanded')).toBe('false');
			expect(optionsOf(element)).toHaveLength(3);
		});
	});

	describe('teardown', () =>
	{
		it('clears the pending debounce timer on disconnect', () =>
		{
			jest.useFakeTimers();
			const element = createPicker();
			const input = comboboxOf(element);

			input.value = 'credit';
			input.dispatchEvent(new CustomEvent('input'));
			document.body.removeChild(element);

			expect(() => jest.advanceTimersByTime(FILTER_DELAY)).not.toThrow();
		});
	});

	describe('degenerate input', () =>
	{
		it('coerces a null options assignment to an empty list', async() =>
		{
			const element = createPicker({options: null});
			await flush();

			expect(optionsOf(element)).toHaveLength(0);
			expect(element.shadowRoot.querySelector('.rulepick__empty')).not.toBeNull();
		});

		it('tolerates partial options, falling back a missing label to the value', async() =>
		{
			const element = createPicker({
				options: [
					{value: 'MaskExample'},
					{}
				]
			});
			await flush();

			const options = optionsOf(element);
			expect(options).toHaveLength(2);
			expect(options[0].querySelector('.rulepick__opt-label').textContent).toBe('MaskExample');
			expect(options[0].querySelector('.rulepick__opt-cat')).toBeNull();
		});
	});
});
