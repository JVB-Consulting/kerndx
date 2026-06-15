// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Add-rule menu for the Data Masking Advisor, built on lightning/modal (LightningModal). It
 * lists the masking rules an admin can add to a field (type-matching rules not already present) or to an
 * object (rules not already applied object-wide), each with a short description, plus a footer link to
 * create a custom rule in Setup. It never changes the org: picking a rule resolves the chosen developer
 * name so the caller ticks it as a candidate in the export diff.
 *
 * Resolution contract: closes with `{pickedRuleDeveloperName}` when a rule is added; closes with
 * `{action:'createRule'}` from the Create-a-custom-rule link so the caller can navigate to Setup; Close and
 * the platform header dismiss both close with `null` / `undefined`, which the caller treats as "no change".
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {api} from 'lwc';
import LightningModal from 'lightning/modal';
import TITLE_FIELD from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Title_Field';
import TITLE_OBJECT_WIDE from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Title_ObjectWide';
import INTRO_FIELD from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Intro_Field';
import INTRO_OBJECT_WIDE from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Intro_ObjectWide';
import EMPTY_FIELD from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Empty_Field';
import EMPTY_OBJECT_WIDE from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Empty_ObjectWide';
import ADD_BUTTON from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_AddButton';
import CREATE_CUSTOM_RULE from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_CreateCustomRule';
import CLOSE from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_Close';

// The two menu scopes — adding a rule to a single field, or object-wide across every field — which pick the
// title, intro, and empty-state text variants.
const SCOPE_OBJECT = 'object';
// The resolution action the Create-a-custom-rule link carries so the caller can navigate to Setup.
const ACTION_CREATE_RULE = 'createRule';

/**
 * @description Static label strings the template renders, grouped so the markup reads `{labels.x}`.
 * @type {Object<string, string>}
 */
const LABELS = {
	addButton: ADD_BUTTON, createCustomRule: CREATE_CUSTOM_RULE, close: CLOSE
};

export default class MaskingAddRuleMenu extends LightningModal
{
	/**
	 * @description The menu scope — `field` (add to one field) or `object` (add object-wide). Picks the
	 * title / intro / empty-state variant.
	 * @type {string}
	 */
	@api menuScope;

	/**
	 * @description The analyzed object's API name, shown in the object-wide title and intro.
	 * @type {string}
	 */
	@api objectApiName;

	/**
	 * @description The field's display label, shown in the field title.
	 * @type {string}
	 */
	@api fieldLabel;

	/**
	 * @description The addable rules, already filtered by the caller to those that fit and are not present.
	 * Each carries `value` (rule developer name), `label`, `subtitle` (short description), `appliesTo` (the
	 * friendly applicable-field-types line), and `warning` (a no-match note for an object-wide rule whose types
	 * match no field on the object yet, blank otherwise). Empty renders the empty-state note.
	 * @type {Array<{value: string, label: string, subtitle: string, appliesTo: string, warning: string}>}
	 */
	@api options;

	/**
	 * @description Static label strings for the template.
	 * @returns {Object<string, string>}
	 */
	get labels()
	{
		return LABELS;
	}

	/**
	 * @description True when the menu is in object-wide scope.
	 * @returns {boolean}
	 */
	get isObjectWide()
	{
		return this.menuScope === SCOPE_OBJECT;
	}

	/**
	 * @description The modal title — naming the object for an object-wide add, or the field otherwise.
	 * @returns {string}
	 */
	get title()
	{
		return this.isObjectWide ? TITLE_OBJECT_WIDE.replace('{0}', this.objectApiName) : TITLE_FIELD.replace('{0}', this.fieldLabel);
	}

	/**
	 * @description The intro line explaining what adding a rule does, by scope.
	 * @returns {string}
	 */
	get intro()
	{
		return this.isObjectWide ? INTRO_OBJECT_WIDE.replace('{0}', this.objectApiName) : INTRO_FIELD;
	}

	/**
	 * @description The empty-state note shown when no rules are addable, by scope.
	 * @returns {string}
	 */
	get emptyText()
	{
		return this.isObjectWide ? EMPTY_OBJECT_WIDE : EMPTY_FIELD;
	}

	/**
	 * @description True when there is at least one addable rule.
	 * @returns {boolean}
	 */
	get hasOptions()
	{
		return Array.isArray(this.options) && this.options.length > 0;
	}

	/**
	 * @description Closes the menu, resolving the picked rule's developer name so the caller ticks it as a
	 * candidate.
	 * @param {Event} event
	 */
	handlePick(event)
	{
		this.close({pickedRuleDeveloperName: event.currentTarget.dataset.value});
	}

	/**
	 * @description Closes the menu carrying a create-rule action so the caller navigates to the New Masking
	 * Rule Setup page.
	 */
	handleCreateRule()
	{
		this.close({action: ACTION_CREATE_RULE});
	}

	/**
	 * @description Dismisses the menu without adding a rule.
	 */
	handleClose()
	{
		this.close(null);
	}
}