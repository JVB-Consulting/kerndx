// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The "＋ Add object" grouped search dialog for the Data Masking Advisor, built on
 * lightning/modal (LightningModal) so the chrome and the WCAG focus-trap come from the platform. It
 * replaces the standing flat object picker (one combobox over 800+ objects) with a searchable, grouped
 * list: the full selectable-object universe is partitioned into Needs attention (objects the coverage scan
 * flagged with likely-sensitive fields and no masking), Your custom objects (own un-namespaced custom
 * objects, already-masked ones tagged "Masked"), Standard objects, and From managed packages. The long
 * standard and managed lists are sampled behind a "type to narrow" hint, and the managed group stays
 * collapsed behind an expander until it is expanded or a search term is typed.
 *
 * The grouping and search are pure client-side partitions of the @api inputs the caller already holds —
 * opening an object changes nothing in the org. Picking a row resolves close(apiName); Close resolves null.
 * The caller hands the resolved api name to its existing per-object describe path.
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {api} from 'lwc';
import LightningModal from 'lightning/modal';
import TITLE from '@salesforce/label/c.DataMaskingAdvisor_AddObject_Title';
import INTRO from '@salesforce/label/c.DataMaskingAdvisor_AddObject_Intro';
import SEARCH_PLACEHOLDER from '@salesforce/label/c.DataMaskingAdvisor_AddObject_SearchPlaceholder';
import GROUP_ATTENTION from '@salesforce/label/c.DataMaskingAdvisor_AddObject_GroupAttention';
import GROUP_OWN from '@salesforce/label/c.DataMaskingAdvisor_AddObject_GroupOwn';
import GROUP_STANDARD from '@salesforce/label/c.DataMaskingAdvisor_AddObject_GroupStandard';
import GROUP_MANAGED from '@salesforce/label/c.DataMaskingAdvisor_AddObject_GroupManaged';
import PILL_NO_MASKING from '@salesforce/label/c.DataMaskingAdvisor_AddObject_PillNoMasking';
import PILL_MASKED from '@salesforce/label/c.DataMaskingAdvisor_AddObject_PillMasked';
import STANDARD_HINT from '@salesforce/label/c.DataMaskingAdvisor_AddObject_StandardHint';
import MANAGED_HINT from '@salesforce/label/c.DataMaskingAdvisor_AddObject_ManagedHint';
import MANAGED_EXPAND from '@salesforce/label/c.DataMaskingAdvisor_AddObject_ManagedExpand';
import NO_MATCHES from '@salesforce/label/c.DataMaskingAdvisor_AddObject_NoMatches';
import CLOSE from '@salesforce/label/c.DataMaskingAdvisor_AddObject_Close';

// How many rows of the long standard / managed lists to show before the "type to narrow" hint takes over;
// a search term lifts the cap so a narrowed list shows every match.
const PICKER_SAMPLE_SIZE = 8;
// Row pill kinds, doubling as the row's `data-kind` so CSS and tests key off the same token.
const PILL_KIND_ATTENTION = 'attention';
const PILL_KIND_MASKED = 'masked';

/**
 * @description Static label strings the template renders, grouped so the markup reads `{labels.x}`.
 * @type {Object<string, string>}
 */
const LABELS = {
	title: TITLE, intro: INTRO, searchPlaceholder: SEARCH_PLACEHOLDER, groupAttention: GROUP_ATTENTION, groupOwn: GROUP_OWN, groupStandard: GROUP_STANDARD, close: CLOSE
};

export default class MaskingAddObjectDialog extends LightningModal
{
	/**
	 * @description The full selectable-object universe — option rows `{Id, Name, isCustom, namespacePrefix}`
	 * the caller already loaded for the picker. Partitioned client-side into the standard / own / managed
	 * groups.
	 * @type {Array<Object>}
	 */
	@api objectOptions = [];

	/**
	 * @description The coverage scan's flagged objects `{apiName, objectLabel, flaggedFields}` — the source
	 * of the "Needs attention" group. Empty when the scan has not run or flagged nothing.
	 * @type {Array<Object>}
	 */
	@api flaggedObjects = [];

	/**
	 * @description Api names of objects that already have active masking, used to tag rows "Masked".
	 * @type {Array<string>}
	 */
	@api maskedApiNames = [];

	/**
	 * @description The live search term typed into the box; filters every group by api name or label.
	 * @type {string}
	 */
	searchTerm = '';

	/**
	 * @description True once the admin expands the collapsed managed-packages group.
	 * @type {boolean}
	 */
	managedExpanded = false;

	/**
	 * @description Static label strings for the template.
	 * @returns {Object<string, string>}
	 */
	get labels()
	{
		return LABELS;
	}

	/**
	 * @description The trimmed, lower-cased search term used for matching (blank when nothing is typed).
	 * @returns {string}
	 */
	get normalizedTerm()
	{
		return (this.searchTerm || '').trim().toLowerCase();
	}

	/**
	 * @description The set of already-masked api names for O(1) pill lookups.
	 * @returns {Set<string>}
	 */
	get maskedSet()
	{
		return new Set(this.maskedApiNames || []);
	}

	/**
	 * @description The flagged-object api names, so the "Your custom objects" group can exclude objects that
	 * already lead the "Needs attention" group.
	 * @returns {Set<string>}
	 */
	get flaggedApiNames()
	{
		return new Set((this.flaggedObjects || []).map((object) => object.apiName));
	}

	/**
	 * @description The "Needs attention" rows — flagged objects matching the term, each tagged "No masking".
	 * @returns {Array<Object>}
	 */
	get attentionRows()
	{
		return (this.flaggedObjects || [])
		.filter((object) => this.matchesTerm(object.apiName, object.objectLabel))
		.map((object) => this.decorate(object.apiName, object.objectLabel, PILL_KIND_ATTENTION));
	}

	/**
	 * @description True when at least one flagged object matches the term, gating the attention group.
	 * @returns {boolean}
	 */
	get hasAttention()
	{
		return this.attentionRows.length > 0;
	}

	/**
	 * @description The "Your custom objects" rows — own un-namespaced custom objects matching the term,
	 * minus any already shown under attention; masked ones carry the "Masked" pill.
	 * @returns {Array<Object>}
	 */
	get ownRows()
	{
		const flagged = this.flaggedApiNames;
		return (this.objectOptions || [])
		.filter((option) => option.isCustom && !option.namespacePrefix && !flagged.has(option.Id) && this.matchesTerm(option.Id, option.Name))
		.map((option) => this.decorate(option.Id, option.Name, this.pillKindFor(option.Id)));
	}

	/**
	 * @description True when at least one own custom object matches the term, gating that group.
	 * @returns {boolean}
	 */
	get hasOwn()
	{
		return this.ownRows.length > 0;
	}

	/**
	 * @description Standard objects (no `__c` suffix) matching the term, before sampling.
	 * @returns {Array<Object>}
	 */
	get standardMatches()
	{
		return (this.objectOptions || []).filter((option) => !option.isCustom && this.matchesTerm(option.Id, option.Name));
	}

	/**
	 * @description The rendered standard rows — every match while searching, otherwise the first
	 * PICKER_SAMPLE_SIZE; masked ones carry the "Masked" pill.
	 * @returns {Array<Object>}
	 */
	get standardRows()
	{
		const matches = this.standardMatches;
		const rows = this.normalizedTerm ? matches : matches.slice(0, PICKER_SAMPLE_SIZE);
		return rows.map((option) => this.decorate(option.Id, option.Name, this.pillKindFor(option.Id)));
	}

	/**
	 * @description True when at least one standard object renders, gating that group.
	 * @returns {boolean}
	 */
	get hasStandard()
	{
		return this.standardRows.length > 0;
	}

	/**
	 * @description True when the standard list is a (no-term) sample, so the "type to narrow" hint shows.
	 * @returns {boolean}
	 */
	get showStandardHint()
	{
		return !this.normalizedTerm && this.standardRows.length > 0;
	}

	/**
	 * @description The standard "type to narrow" hint with the shown and total counts interpolated.
	 * @returns {string}
	 */
	get standardHintText()
	{
		return this.format(STANDARD_HINT, this.standardRows.length, this.standardMatches.length);
	}

	/**
	 * @description Managed-package custom objects (namespaced) matching the term, before sampling.
	 * @returns {Array<Object>}
	 */
	get managedMatches()
	{
		return (this.objectOptions || []).filter((option) => option.isCustom && option.namespacePrefix && this.matchesTerm(option.Id, option.Name));
	}

	/**
	 * @description Count of all managed-package objects (term-independent), shown in the group heading and
	 * the expander.
	 * @returns {number}
	 */
	get managedAllCount()
	{
		return (this.objectOptions || []).filter((option) => option.isCustom && option.namespacePrefix).length;
	}

	/**
	 * @description True while the managed group is collapsed — no term typed and not yet expanded.
	 * @returns {boolean}
	 */
	get managedCollapsed()
	{
		return !this.normalizedTerm && !this.managedExpanded;
	}

	/**
	 * @description True when the collapsed managed group should offer its expander (there are managed
	 * objects to reveal).
	 * @returns {boolean}
	 */
	get showManagedExpand()
	{
		return this.managedCollapsed && this.managedAllCount > 0;
	}

	/**
	 * @description The rendered managed rows — none while collapsed, every match while searching, otherwise
	 * the first PICKER_SAMPLE_SIZE; masked ones carry the "Masked" pill.
	 * @returns {Array<Object>}
	 */
	get managedRows()
	{
		if(this.managedCollapsed)
		{
			return [];
		}
		const matches = this.managedMatches;
		const rows = this.normalizedTerm ? matches : matches.slice(0, PICKER_SAMPLE_SIZE);
		return rows.map((option) => this.decorate(option.Id, option.Name, this.pillKindFor(option.Id)));
	}

	/**
	 * @description True when the expanded managed list is a (no-term) sample, so its hint shows.
	 * @returns {boolean}
	 */
	get showManagedHint()
	{
		return !this.normalizedTerm && this.managedExpanded && this.managedRows.length > 0;
	}

	/**
	 * @description The managed "type to narrow" hint with the shown and total counts interpolated.
	 * @returns {string}
	 */
	get managedHintText()
	{
		return this.format(MANAGED_HINT, this.managedRows.length, this.managedMatches.length);
	}

	/**
	 * @description The managed group heading with the total managed count interpolated.
	 * @returns {string}
	 */
	get managedHeading()
	{
		return this.format(GROUP_MANAGED, this.managedAllCount);
	}

	/**
	 * @description The managed expander label with the total managed count interpolated.
	 * @returns {string}
	 */
	get managedExpandLabel()
	{
		return this.format(MANAGED_EXPAND, this.managedAllCount);
	}

	/**
	 * @description True when the managed group renders at all — either the expander or at least one row.
	 * @returns {boolean}
	 */
	get hasManagedGroup()
	{
		return this.showManagedExpand || this.managedRows.length > 0;
	}

	/**
	 * @description True when no group renders any content, so the no-matches message shows instead.
	 * @returns {boolean}
	 */
	get showEmptyState()
	{
		return !(this.hasAttention || this.hasOwn || this.hasStandard || this.hasManagedGroup);
	}

	/**
	 * @description The no-matches message with the (raw, as-typed) search term interpolated.
	 * @returns {string}
	 */
	get emptyText()
	{
		return this.format(NO_MATCHES, this.searchTerm);
	}

	/**
	 * @description Whether the api name or label contains the active search term (always true when blank).
	 * @param {string} apiName - The object api name.
	 * @param {string} label - The object label.
	 * @returns {boolean}
	 */
	matchesTerm(apiName, label)
	{
		const term = this.normalizedTerm;
		return !term || apiName.toLowerCase().includes(term) || label.toLowerCase().includes(term);
	}

	/**
	 * @description The pill kind for a row — "masked" when the object already has masking, otherwise none.
	 * @param {string} apiName - The object api name.
	 * @returns {string|null}
	 */
	pillKindFor(apiName)
	{
		return this.maskedSet.has(apiName) ? PILL_KIND_MASKED : null;
	}

	/**
	 * @description Builds a render row carrying the api name, label, stable key, and pill presence/label/kind.
	 * @param {string} apiName - The object api name (also the stable key and data-api-name).
	 * @param {string} label - The object label.
	 * @param {string|null} pillKind - The pill kind (attention | masked) or null for no pill.
	 * @returns {Object}
	 */
	decorate(apiName, label, pillKind)
	{
		return {
			apiName,
			label,
			key: apiName,
			hasPill: !!pillKind,
			pillKind: pillKind || '',
			pillLabel: pillKind === PILL_KIND_ATTENTION ? PILL_NO_MASKING : (pillKind === PILL_KIND_MASKED ? PILL_MASKED : '')
		};
	}

	/**
	 * @description Interpolates positional `{0}`, `{1}`… placeholders in a label with the supplied arguments.
	 * @param {string} template - The label template.
	 * @param {...*} args - The replacement values, in order.
	 * @returns {string}
	 */
	format(template, ...args)
	{
		// Function replacement (not a string) so a value containing $-patterns — e.g. a search term like "$&"
		// echoed into the no-matches message — is inserted literally, not interpreted by String.replace.
		return args.reduce((text, argument, index) => text.replace('{' + index + '}', () => String(argument)), template);
	}

	/**
	 * @description Records the typed search term, re-running every group's filter through the getters.
	 * @param {CustomEvent} event - The search input's change event carrying the new value in detail.
	 */
	handleSearch(event)
	{
		this.searchTerm = event.detail.value;
	}

	/**
	 * @description Expands the collapsed managed-packages group to reveal its rows.
	 */
	handleExpandManaged()
	{
		this.managedExpanded = true;
	}

	/**
	 * @description Resolves the dialog with the clicked row's object api name.
	 * @param {Event} event - The row button's click event; the api name rides its dataset.
	 */
	handlePick(event)
	{
		this.close(event.currentTarget.dataset.apiName);
	}

	/**
	 * @description Dismisses the dialog without picking an object.
	 */
	handleClose()
	{
		this.close(null);
	}
}