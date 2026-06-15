// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Custom, searchable ARIA 1.2 combobox/listbox used as the per-field masking-rule
 * dropdown in the Data Masking Advisor. Unlike `lightning-combobox`, it supports type-ahead
 * filtering and renders a category secondary line under each rule label. It offers only the
 * rules a field can take (the parent passes the field's applicable rules as `options`), marks
 * the selected rule with a checkmark, and emits a `rulechange` event carrying the chosen rule
 * DeveloperName. Built with reactive templates (no innerHTML / global handlers) so it composes
 * safely as one instance per field row.
 *
 * Visual + interaction design is grounded in the locked advisor prototype: the closed control
 * reads as a 38px dropdown button (selected label + chevron), the open menu is a popover of
 * options with the selected one in brand-blue + bold and a trailing checkmark, and filtering is
 * debounced so a large option set never re-renders on every keystroke.
 *
 * @author Jason van Beukering
 * @date May 2026, June 2026
 */
import {api, LightningElement} from 'lwc';
import RULE_PICKER_LABEL from '@salesforce/label/c.DataMaskingAdvisor_RulePicker_Label';
import RULE_PICKER_PLACEHOLDER from '@salesforce/label/c.DataMaskingAdvisor_RulePicker_Placeholder';
import RULE_PICKER_NO_MATCHES from '@salesforce/label/c.DataMaskingAdvisor_RulePicker_NoMatches';

/**
 * @description Debounce delay (ms) applied before a typed filter term updates the rendered
 * option list, so rapid typing re-renders the listbox once per pause rather than per keystroke.
 * @type {number}
 */
export const FILTER_DELAY = 200;

/**
 * @description Sentinel index meaning no option is the active descendant.
 * @type {number}
 */
const NO_ACTIVE_OPTION = -1;

/**
 * @description Stable id of the listbox popup within this component's shadow root. IDREFs
 * (`aria-controls`, `aria-activedescendant`) resolve within the same shadow tree, so a static
 * id is collision-free across multiple picker instances on a page.
 * @type {string}
 */
const LISTBOX_ID = 'rulepick-listbox';

/**
 * @description Map-based keyboard dispatch table keyed by `KeyboardEvent.key`. Each entry receives
 * the component context and the event, mirroring the repo's baseLookup keyboard pattern.
 * @type {Map<string, Function>}
 */
const KEY_HANDLERS = new Map([
	[
		'ArrowDown',
		(context, event) =>
		{
			event.preventDefault();
			context.openMenu();
			context.moveActiveOption(1);
		}
	],
	[
		'ArrowUp',
		(context, event) =>
		{
			event.preventDefault();
			context.openMenu();
			context.moveActiveOption(-1);
		}
	],
	[
		'Enter',
		(context, event) =>
		{
			event.preventDefault();
			context.selectActiveOption();
		}
	],
	[
		'Escape',
		(context, event) =>
		{
			event.preventDefault();
			context.closeMenu();
		}
	],
	[
		'Home',
		(context, event) =>
		{
			event.preventDefault();
			context.openMenu();
			context.setActiveOption(0);
		}
	],
	[
		'End',
		(context, event) =>
		{
			event.preventDefault();
			context.openMenu();
			context.setActiveOption(context.filteredOptions.length - 1);
		}
	]
]);

/**
 * @description Normalizes a raw option into the `{value, label, category}` shape, tolerating
 * partial inputs (a missing label falls back to the value; a missing category becomes '').
 * @param {Object} option - Raw option supplied by the consumer.
 * @returns {{value: string, label: string, category: string}}
 */
function normalizeOption(option)
{
	const value = option && option.value != null ? String(option.value) : '';
	return {
		value, label: option && option.label ? String(option.label) : value, category: option && option.category ? String(option.category) : ''
	};
}

/**
 * @description Builds a DOM-safe option id from a rule DeveloperName by replacing any character
 * outside the id-safe set with an underscore.
 * @param {string} value - The rule DeveloperName.
 * @returns {string}
 */
function optionDomId(value)
{
	return `${LISTBOX_ID}-opt-${String(value).replace(/[^A-Za-z0-9_-]/g, '_')}`;
}

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class MaskingRulePicker extends LightningElement
{
	/**
	 * @description Accessible label for the combobox (also the listbox label). Defaults to a
	 * generic value; the parent should pass a field-specific label for screen-reader clarity.
	 * @type {string}
	 */
	@api label = RULE_PICKER_LABEL;

	/**
	 * @description Placeholder text shown when no rule label occupies the input.
	 * @type {string}
	 */
	@api placeholder = RULE_PICKER_PLACEHOLDER;

	/**
	 * @description When true the control is non-interactive (used while a row is unchecked).
	 * @type {boolean}
	 */
	@api disabled = false;
	searchTerm = '';
	isOpen = false;
	activeIndex = NO_ACTIVE_OPTION;
	filterTimeout;

	_options = [];

	/**
	 * @description The rules this field can take, each `{value, label, category}` where `value`
	 * is the rule DeveloperName, `label` the rule's display label, and `category` an optional
	 * grouping hint (blank for uncategorized / subscriber-created rules). Each `value` must be
	 * unique and non-empty — it keys both the option DOM id and the template iteration.
	 * @type {Array<{value: string, label: string, category: string}>}
	 */
	@api get options()
	{
		return this._options;
	}

	set options(value)
	{
		this._options = Array.isArray(value) ? value.map(normalizeOption) : [];
		this.syncSearchTermToSelection();
	}

	_value = null;

	/**
	 * @description The currently-selected rule DeveloperName, or null when none is chosen.
	 * Assigning it re-syncs the input text to the matching rule's label.
	 * @type {string|null}
	 */
	@api get value()
	{
		return this._value;
	}

	set value(value)
	{
		this._value = value || null;
		this.syncSearchTermToSelection();
	}

	/**
	 * @description The option object matching the current value, or null.
	 * @returns {{value: string, label: string, category: string}|null}
	 */
	get selectedOption()
	{
		return this._options.find(option => option.value === this._value) || null;
	}

	/**
	 * @description The options to render, filtered by the typed term. In "browse" mode (empty term
	 * or a term equal to the selected rule's label) every option is shown so the user can see the
	 * full set; otherwise the label or category must contain the term (case-insensitive). Each
	 * returned option is decorated with the presentation flags the template needs.
	 * @returns {Array<Object>}
	 */
	get filteredOptions()
	{
		const term = (this.searchTerm || '').trim().toLowerCase();
		const selectedLabel = (this.selectedOption ? this.selectedOption.label : '').toLowerCase();
		const browse = term === '' || term === selectedLabel;
		const matches = browse ? this._options : this._options.filter(option => option.label.toLowerCase().includes(term) || option.category.toLowerCase().includes(term));

		return matches.map((option, index) =>
		{
			const isSelected = option.value === this._value;
			const isActive = index === this.activeIndex;
			let optionClass = 'rulepick__opt';
			if(isSelected)
			{
				optionClass += ' is-sel';
			}
			if(isActive)
			{
				optionClass += ' is-active';
			}
			return {
				value: option.value,
				label: option.label,
				category: option.category,
				id: optionDomId(option.value),
				isSelected,
				ariaSelected: isSelected ? 'true' : 'false',
				showCategory: option.category !== '',
				optionClass
			};
		});
	}

	/**
	 * @description True when no option matches the current filter term.
	 * @returns {boolean}
	 */
	get isEmpty()
	{
		return this.filteredOptions.length === 0;
	}

	/**
	 * @description Message shown in the listbox when the filter matches no rule.
	 * @returns {string}
	 */
	get noMatchesLabel()
	{
		return RULE_PICKER_NO_MATCHES;
	}

	/**
	 * @description The id of the listbox popup (target of `aria-controls`).
	 * @returns {string}
	 */
	get listboxId()
	{
		return LISTBOX_ID;
	}

	/**
	 * @description String form of the expanded state for the `aria-expanded` attribute.
	 * @returns {string}
	 */
	get ariaExpanded()
	{
		return this.isOpen ? 'true' : 'false';
	}

	/**
	 * @description The DOM id of the active option for `aria-activedescendant`, or '' when the menu
	 * is closed or no option is active.
	 * @returns {string}
	 */
	get activeDescendantId()
	{
		if(!this.isOpen || this.activeIndex === NO_ACTIVE_OPTION)
		{
			return '';
		}
		const active = this.filteredOptions[this.activeIndex];
		return active ? active.id : '';
	}

	/**
	 * @description Class for the `.rulepick` container, toggling the open state used by the CSS.
	 * @returns {string}
	 */
	get pickerClass()
	{
		return this.isOpen ? 'rulepick is-open' : 'rulepick';
	}

	connectedCallback()
	{
		this.syncSearchTermToSelection();
	}

	disconnectedCallback()
	{
		clearTimeout(this.filterTimeout);
	}

	/**
	 * @description Re-syncs the input text to the selected rule's label (or clears it when nothing
	 * is selected). Called on mount and whenever `value`/`options` change.
	 */
	syncSearchTermToSelection()
	{
		const selected = this.selectedOption;
		this.searchTerm = selected ? selected.label : '';
	}

	/**
	 * @description Commits a selection: updates the value, resets the input text + menu, and emits
	 * `rulechange`.
	 * @param {string} value - The chosen rule DeveloperName.
	 * @fires MaskingRulePicker#rulechange
	 */
	commitSelection(value)
	{
		this._value = value;
		this.syncSearchTermToSelection();
		this.isOpen = false;
		this.activeIndex = NO_ACTIVE_OPTION;
		this.dispatchEvent(new CustomEvent('rulechange', {detail: {value}}));
	}

	/**
	 * @description Selects the option at the active index, if the menu is open and one is active.
	 */
	selectActiveOption()
	{
		if(!this.isOpen || this.activeIndex === NO_ACTIVE_OPTION)
		{
			return;
		}
		const active = this.filteredOptions[this.activeIndex];
		if(active)
		{
			this.commitSelection(active.value);
		}
	}

	/**
	 * @description Opens the menu (no-op when disabled), seeding the active index to the selected
	 * option so keyboard navigation starts from the current choice.
	 */
	openMenu()
	{
		if(this.disabled || this.isOpen)
		{
			return;
		}
		this.isOpen = true;
		this.activeIndex = this.filteredOptions.findIndex(option => option.isSelected);
	}

	/**
	 * @description Closes the menu and restores the input text to the current selection so a
	 * half-typed filter does not linger.
	 */
	closeMenu()
	{
		this.isOpen = false;
		this.activeIndex = NO_ACTIVE_OPTION;
		this.syncSearchTermToSelection();
	}

	/**
	 * @description Moves the active option by a step, clamped to the filtered range.
	 * @param {number} step - +1 for next, -1 for previous.
	 */
	moveActiveOption(step)
	{
		const next = this.activeIndex === NO_ACTIVE_OPTION ? 0 : this.activeIndex + step;
		this.setActiveOption(next);
	}

	/**
	 * @description Sets the active option to an absolute index, clamped to the filtered range (or to
	 * no-active when the list is empty). Drives Home/End jumps and the step navigation above.
	 * @param {number} index - The desired active index.
	 */
	setActiveOption(index)
	{
		const count = this.filteredOptions.length;
		this.activeIndex = count === 0 ? NO_ACTIVE_OPTION : Math.min(Math.max(index, 0), count - 1);
	}

	/**
	 * @description Opens the menu when the input is focused or clicked.
	 */
	handleOpen()
	{
		this.openMenu();
	}

	/**
	 * @description Closes the menu when the pointer leaves the control (mouse dismissal).
	 */
	handleMouseLeave()
	{
		if(this.isOpen)
		{
			this.closeMenu();
		}
	}

	/**
	 * @description Closes the menu when focus leaves the control — e.g. the user Tabs away. Option
	 * selection commits on `mousedown` with `preventDefault`, so choosing an option never blurs the
	 * input and this does not fire spuriously mid-selection.
	 */
	handleFocusOut()
	{
		if(this.isOpen)
		{
			this.closeMenu();
		}
	}

	/**
	 * @description Debounces the typed term into the reactive `searchTerm` so the option list
	 * re-renders once per pause. Opens the menu and resets the active option on input.
	 * @param {InputEvent} event
	 */
	handleInput(event)
	{
		if(this.disabled)
		{
			return;
		}
		const term = event.target.value;
		this.isOpen = true;
		this.activeIndex = NO_ACTIVE_OPTION;
		clearTimeout(this.filterTimeout);
		// eslint-disable-next-line @lwc/lwc/no-async-operation
		this.filterTimeout = setTimeout(() =>
		{
			this.searchTerm = term;
			if(this.activeIndex >= this.filteredOptions.length)
			{
				this.activeIndex = NO_ACTIVE_OPTION;
			}
		}, FILTER_DELAY);
	}

	/**
	 * @description Routes a keydown to the keyboard dispatch table.
	 * @param {KeyboardEvent} event
	 */
	handleKeyDown(event)
	{
		const handler = KEY_HANDLERS.get(event.key);
		if(handler)
		{
			handler(this, event);
		}
	}

	/**
	 * @description Commits the chosen option on mousedown. Calling `preventDefault` keeps focus on the
	 * input (so the focus-out dismissal does not fire mid-selection) while the value commits.
	 * @param {MouseEvent} event
	 */
	handleOptionMouseDown(event)
	{
		event.preventDefault();
		this.commitSelection(event.currentTarget.dataset.value);
	}
}