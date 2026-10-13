// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The Class Name field of the scheduled job editors. It suggests the org's schedulable classes as you
 *              type, and it also takes a name the list does not show: the list is kept for up to eight hours, so a
 *              class deployed since then is missing from it. On Enter, on picking a suggestion, or when focus leaves
 *              the field, it emits classchange with the name, trimmed, and spelt as the list spells it when the list
 *              holds it in another letter case or with a namespace prefix. The editor checks the name and passes any
 *              problem back as errorMessage, which shows under the field.
 *
 * @author Jason van Beukering
 *
 * @date October 2026
 */
import {api, LightningElement} from 'lwc';

/**
 * @description Index meaning no suggestion is highlighted.
 *
 * @type {number}
 */
const NO_ACTIVE_SUGGESTION = -1;

/**
 * @description Id of the suggestion list; ids and the attributes naming them resolve inside this component.
 *
 * @type {string}
 */
const LISTBOX_ID = 'class-picker-listbox';

/**
 * @description What separates a namespace prefix from a class name.
 *
 * @type {string}
 */
const NAMESPACE_SEPARATOR = '.';

/**
 * @description The field's classes while the name is fine.
 *
 * @type {string}
 */
const FORM_ELEMENT_CLASS = 'slds-form-element';

/**
 * @description The field's classes while it shows an error.
 *
 * @type {string}
 */
const FORM_ELEMENT_WITH_ERROR_CLASS = 'slds-form-element slds-has-error';

/**
 * @description The combobox's classes while the suggestions are closed.
 *
 * @type {string}
 */
const COMBOBOX_CLASS = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';

/**
 * @description The combobox's classes while the suggestions are open.
 *
 * @type {string}
 */
const OPEN_COMBOBOX_CLASS = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open';

/**
 * @description A suggestion's classes.
 *
 * @type {string}
 */
const SUGGESTION_CLASS = 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small';

/**
 * @description The highlighted suggestion's classes.
 *
 * @type {string}
 */
const ACTIVE_SUGGESTION_CLASS = 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small slds-has-focus';

/**
 * @description What each key the field handles does, keyed by KeyboardEvent.key.
 *
 * @type {Map<string, Function>}
 */
const KEY_HANDLERS = new Map([
	[
		'ArrowDown',
		(picker) => picker.moveActiveSuggestion(1)
	],
	[
		'ArrowUp',
		(picker) => picker.moveActiveSuggestion(-1)
	],
	[
		'Enter',
		(picker) => picker.commitActiveOrTypedName()
	],
	[
		'Escape',
		(picker) => picker.closeSuggestions()
	]
]);

/**
 * @description The name to send for what was typed: the listed name equal to it in any letter case; for a name without
 *              a namespace prefix, the one listed name that is that name with a prefix; otherwise the typed text,
 *              trimmed.
 *
 * @param {string} typedName The text as typed.
 * @param {string[]} listedNames The names the list offers.
 *
 * @return {string} The name to send.
 */
export function findListedClassName(typedName, listedNames)
{
	const name = String(typedName ?? '').trim();
	const lowerCaseName = name.toLowerCase();
	const sameName = listedNames.find((listed) => listed.toLowerCase() === lowerCaseName);

	if(sameName)
	{
		return sameName;
	}

	if(name === '' || name.includes(NAMESPACE_SEPARATOR))
	{
		return name;
	}

	const prefixedNames = listedNames.filter((listed) => listed.toLowerCase().endsWith(NAMESPACE_SEPARATOR + lowerCaseName));
	return prefixedNames.length === 1 ? prefixedNames[0] : name;
}

// eslint-disable-next-line kerndx/use-component-builder -- a plain form field with no toasts, Apex calls or navigation, as maskingRulePicker
export default class ScheduledJobClassPicker extends LightningElement
{
	/**
	 * @description The field's label.
	 *
	 * @type {string}
	 */
	@api label = '';

	/**
	 * @description The hint shown while the field is empty.
	 *
	 * @type {string}
	 */
	@api placeholder = '';

	/**
	 * @description Whether the field is marked as required.
	 *
	 * @type {boolean}
	 */
	@api required = false;

	/**
	 * @description Why the name cannot be used, shown under the field; empty while the name is fine.
	 *
	 * @type {string}
	 */
	@api errorMessage = '';

	/**
	 * @description The text in the field as typed.
	 *
	 * @type {string}
	 */
	typedName = '';

	/**
	 * @description Whether the suggestion list is open.
	 *
	 * @type {boolean}
	 */
	isOpen = false;

	/**
	 * @description The highlighted suggestion's index, or NO_ACTIVE_SUGGESTION.
	 *
	 * @type {number}
	 */
	activeIndex = NO_ACTIVE_SUGGESTION;

	/**
	 * @description The class names the list offers, taken from the options.
	 *
	 * @type {string[]}
	 */
	listedNames = [];

	/**
	 * @description The class name last taken, by setting the value or by committing a name.
	 *
	 * @type {string}
	 */
	committedName = '';

	/**
	 * @description The classes to suggest, as {label, value}; the value is the class name.
	 *
	 * @type {Array<{label: string, value: string}>}
	 */
	@api get options()
	{
		return this.listedNames.map((name) => ({label: name, value: name}));
	}

	set options(value)
	{
		this.listedNames = Array.isArray(value) ? value.map((option) => String(option?.value ?? '')).filter((name) => name !== '') : [];
	}

	/**
	 * @description The class name the field holds; setting it also sets the text.
	 *
	 * @type {string}
	 */
	@api get value()
	{
		return this.committedName;
	}

	set value(value)
	{
		this.committedName = value || '';
		this.typedName = this.committedName;
	}

	/**
	 * @description The suggestions to show: every listed class while the text is empty or is the chosen name, otherwise
	 *              the classes whose name holds the text, in any letter case.
	 *
	 * @return {Array<Object>} Each suggestion's name, id, selected state and classes.
	 */
	get suggestions()
	{
		const term = this.typedName.trim().toLowerCase();
		const isShowingEveryClass = term === '' || term === this.committedName.toLowerCase();
		const names = isShowingEveryClass ? this.listedNames : this.listedNames.filter((name) => name.toLowerCase().includes(term));

		return names.map((name, index) => ({
			value: name,
			id: `${LISTBOX_ID}-${index}`,
			ariaSelected: index === this.activeIndex ? 'true' : 'false',
			optionClass: index === this.activeIndex ? ACTIVE_SUGGESTION_CLASS : SUGGESTION_CLASS
		}));
	}

	/**
	 * @description The field's classes, marking it as in error while it shows one.
	 *
	 * @return {string} The classes for the form element.
	 */
	get formElementClass()
	{
		return this.errorMessage ? FORM_ELEMENT_WITH_ERROR_CLASS : FORM_ELEMENT_CLASS;
	}

	/**
	 * @description The combobox's classes, open only while the list is open and has a suggestion to show.
	 *
	 * @return {string} The classes for the combobox.
	 */
	get comboboxClass()
	{
		return this.isOpen && this.suggestions.length > 0 ? OPEN_COMBOBOX_CLASS : COMBOBOX_CLASS;
	}

	/**
	 * @description Whether the suggestion list is open, as the aria-expanded attribute takes it.
	 *
	 * @return {string} 'true' or 'false'.
	 */
	get ariaExpanded()
	{
		return this.isOpen ? 'true' : 'false';
	}

	/**
	 * @description Whether the field shows an error, as the aria-invalid attribute takes it.
	 *
	 * @return {string} 'true' or 'false'.
	 */
	get ariaInvalid()
	{
		return this.errorMessage ? 'true' : 'false';
	}

	/**
	 * @description Whether the field is required, as the aria-required attribute takes it.
	 *
	 * @return {string} 'true' or 'false'.
	 */
	get ariaRequired()
	{
		return this.required ? 'true' : 'false';
	}

	/**
	 * @description The id of the highlighted suggestion while the list is open; null otherwise, so the input carries no
	 *              aria-activedescendant naming nothing.
	 *
	 * @return {string|null} The highlighted suggestion's id, or null.
	 */
	get activeDescendantId()
	{
		return this.isOpen && this.activeIndex !== NO_ACTIVE_SUGGESTION ? `${LISTBOX_ID}-${this.activeIndex}` : null;
	}

	/**
	 * @description Opens the suggestions when the field is clicked.
	 */
	handleOpen()
	{
		this.isOpen = true;
	}

	/**
	 * @description Keeps the typed text and shows the suggestions that match it, with none highlighted.
	 *
	 * @param {Event} event The input's input event.
	 */
	handleInput(event)
	{
		this.typedName = event.target.value;
		this.isOpen = true;
		this.activeIndex = NO_ACTIVE_SUGGESTION;
	}

	/**
	 * @description Moves through the suggestions, commits, or closes the list; other keys are left to the input.
	 *
	 * @param {KeyboardEvent} event The input's keydown event.
	 */
	handleKeyDown(event)
	{
		const handler = KEY_HANDLERS.get(event.key);

		if(handler)
		{
			event.preventDefault();
			handler(this);
		}
	}

	/**
	 * @description Commits a picked suggestion. Runs on mousedown, with the default prevented, so the input keeps the
	 *              focus and leaving the field does not commit the half-typed text first.
	 *
	 * @param {MouseEvent} event The suggestion's mousedown event.
	 */
	handleSuggestionMouseDown(event)
	{
		event.preventDefault();
		this.commit(event.currentTarget.dataset.value);
	}

	/**
	 * @description Keeps the focus in the input when the list itself is pressed, as when its scrollbar is dragged, so
	 *              leaving the field does not commit the half-typed text.
	 *
	 * @param {MouseEvent} event The list's mousedown event.
	 */
	handleListMouseDown(event)
	{
		event.preventDefault();
	}

	/**
	 * @description Commits the typed text when focus leaves the field, not when it moves inside it. Focus leaving for
	 *              nowhere (the page itself) has no related target, which the template cannot be asked about.
	 *
	 * @param {FocusEvent} event The field's focusout event.
	 */
	handleFocusOut(event)
	{
		if(event.relatedTarget && this.template.contains(event.relatedTarget))
		{
			return;
		}

		this.commit(this.typedName);
	}

	/**
	 * @description Highlights the next or previous suggestion, opening the list; from none it starts at the first going
	 *              down and at the last going up, and it stops at either end.
	 *
	 * @param {number} step 1 for down, -1 for up.
	 */
	moveActiveSuggestion(step)
	{
		const count = this.suggestions.length;
		this.isOpen = true;

		if(count === 0)
		{
			this.activeIndex = NO_ACTIVE_SUGGESTION;
			return;
		}

		let next = this.activeIndex + step;

		if(this.activeIndex === NO_ACTIVE_SUGGESTION)
		{
			next = step > 0 ? 0 : count - 1;
		}

		this.activeIndex = Math.min(Math.max(next, 0), count - 1);
	}

	/**
	 * @description Commits the highlighted suggestion while the list is open, otherwise the typed text.
	 */
	commitActiveOrTypedName()
	{
		const active = this.isOpen ? this.suggestions[this.activeIndex] : undefined;
		this.commit(active ? active.value : this.typedName);
	}

	/**
	 * @description Closes the list, keeping the typed text.
	 */
	closeSuggestions()
	{
		this.isOpen = false;
		this.activeIndex = NO_ACTIVE_SUGGESTION;
	}

	/**
	 * @description Takes a name: closes the list, shows the name to send, and emits classchange when it differs from
	 *              the current one.
	 *
	 * @param {string} rawName The picked or typed name.
	 */
	commit(rawName)
	{
		const name = findListedClassName(rawName, this.listedNames);
		this.closeSuggestions();
		this.typedName = name;

		if(name === this.committedName)
		{
			return;
		}

		this.committedName = name;
		this.dispatchEvent(new CustomEvent('classchange', {detail: {value: name}}));
	}
}
