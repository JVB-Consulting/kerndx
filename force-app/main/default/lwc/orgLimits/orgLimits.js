// SPDX-License-Identifier: BUSL-1.1

/**
 * @description LWC component that renders Salesforce org limits as a prioritised SLDS card grid.
 * Each card shows the limit's prettified name, a colour-coded usage bar, the percentage consumed,
 * and the raw "used of maximum" numbers. Cards default to worst-first (highest usage) order, and a
 * client-side sort and search operate over the single Apex load. Everything shown is derived purely
 * from what `OrgLimits.getAll()` returns (name, value, maximum); no reset interval, description, or
 * other metadata is fabricated.
 *
 * @author Jason van Beukering
 * @date July 2026
 */
import {LightningElement} from 'lwc';
import getOrgLimits from '@salesforce/apex/CTRL_EventMonitor.getOrgLimits';
import {formatCount} from 'c/utilityStreaming';
import LOCALE from '@salesforce/i18n/locale';

import CARD_TITLE from '@salesforce/label/c.OrgLimits_CardTitle';
import NOTICE from '@salesforce/label/c.OrgLimits_Notice';
import ERROR_BODY from '@salesforce/label/c.OrgLimits_Error_Body';
import EMPTY from '@salesforce/label/c.OrgLimits_Empty';
import SEARCH_PLACEHOLDER from '@salesforce/label/c.OrgLimits_SearchPlaceholder';
import SORT_BY_LABEL from '@salesforce/label/c.OrgLimits_SortBy_Label';
import SORT_WORST_FIRST from '@salesforce/label/c.OrgLimits_Sort_WorstFirst';
import SORT_NAME from '@salesforce/label/c.OrgLimits_Sort_Name';
import USAGE from '@salesforce/label/c.OrgLimits_Usage';

// ── Constants ────────────────────────────────────────────────────────────

/** @description Percentage at or above which a limit is shown in the amber (watch) band. */
const AMBER_THRESHOLD = 70;

/** @description Percentage at or above which a limit is shown in the red (urgent) band. */
const RED_THRESHOLD = 90;

const SORT_WORST = 'worst';
const SORT_ALPHABETICAL = 'name';

/**
 * @description Acronym dictionary for the cosmetic name prettify. A value of `1` keeps the token
 * upper-cased as-is; a string value substitutes an exact mixed-case rendering. Tokens not listed
 * are Title-cased normally, so ordinary words (Bulk, Einstein, …) need no entry.
 */
const ACRONYMS = {
	API: 1, ODATA: 'OData', CDC: 1, MB: 1, ID: 'Id', APEX: 'Apex', GMT: 1, SOQL: 1, SOSL: 1, URL: 1
};

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Substitutes positional `{0}`, `{1}`, … tokens in a label template.
 * @param {string} template - The label text containing positional tokens.
 * @param {...string} values - Replacement values, in order.
 * @returns {string} The interpolated string.
 */
function formatLabel(template, ...values)
{
	return values.reduce((accumulator, value, index) => accumulator.replace(`{${index}}`, value), template);
}

/**
 * @description Cosmetically prettifies a raw org-limit API name for display: splits camelCase and
 * digit boundaries, Title-cases each token, preserves known acronyms, and rejoins `V<digit>` tokens
 * (so `DailyBulkV2QueryJobs` reads `Daily Bulk V2 Query Jobs`). Purely presentational — no semantic
 * inference. The raw name remains the source of truth for search and the bar's aria-label.
 * @param {string} name - The raw org-limit API name.
 * @returns {string} The display name.
 */
function prettify(name)
{
	return name
	.replace(/([a-z0-9])([A-Z])/g, '$1 $2')
	.replace(/([A-Za-z])([0-9])/g, '$1 $2')
	.replace(/([0-9])([A-Za-z])/g, '$1 $2')
	.split(/\s+/)
	.map((token) =>
	{
		const upper = token.toUpperCase();
		if(ACRONYMS[upper])
		{
			return ACRONYMS[upper] === 1 ? upper : ACRONYMS[upper];
		}
		return token.charAt(0).toUpperCase() + token.slice(1);
	})
	.join(' ')
	.replace(/\bV (\d)\b/g, 'V$1');
}

/**
 * @description Computes the percentage consumed, guarding the max==0 (unprovisioned) case so an
 * unprovisioned feature reads 0% rather than NaN.
 * @param {number} used - The consumed value.
 * @param {number} max - The maximum value.
 * @returns {number} The integer percentage 0–100+ (may exceed 100 if usage exceeds the maximum).
 */
function percentageConsumed(used, max)
{
	return max > 0 ? Math.round((used / max) * 100) : 0;
}

/**
 * @description Maps a percentage to its colour band.
 * @param {number} percentage - The percentage consumed.
 * @returns {string} `green` (healthy), `amber` (watch), or `red` (urgent).
 */
function bandLevel(percentage)
{
	if(percentage >= RED_THRESHOLD)
	{
		return 'red';
	}
	return percentage >= AMBER_THRESHOLD ? 'amber' : 'green';
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class OrgLimits extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/** @description Raw org-limit records from Apex (`[{name, value, max}]`); undefined until loaded. */
	rawLimits;

	/** @description Serialized error when the Apex load fails; undefined on success. */
	error;

	/** @description The active sort key (`worst` | `name`). */
	sortKey = SORT_WORST;

	/** @description The current case-insensitive name search term. */
	searchTerm = '';

	/**
	 * @description Static label strings the template renders, grouped so the markup reads `{labels.x}`.
	 * @type {Object<string, string>}
	 */
	labels = {
		cardTitle: CARD_TITLE, notice: NOTICE, errorBody: ERROR_BODY, empty: EMPTY, searchPlaceholder: SEARCH_PLACEHOLDER, sortByLabel: SORT_BY_LABEL
	};

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Whether the Apex load is still pending (no data and no error yet).
	 * @returns {boolean}
	 */
	get isLoading()
	{
		return !this.rawLimits && !this.error;
	}

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Whether the Apex load failed.
	 * @returns {boolean}
	 */
	get hasError()
	{
		return Boolean(this.error);
	}

	/**
	 * @description The two sort options offered by the combobox.
	 * @returns {Array<{label: string, value: string}>}
	 */
	get sortOptions()
	{
		return [
			{label: SORT_WORST_FIRST, value: SORT_WORST},
			{label: SORT_NAME, value: SORT_ALPHABETICAL}
		];
	}

	/**
	 * @description The render model driving the grid: every raw limit mapped to its display shape,
	 * filtered by the search term, then sorted. Worst-first sorts by percentage descending with an
	 * alphabetical tie-break; name sorts alphabetically by the prettified name.
	 * @returns {Array<Object>} `[{key, name, rawName, percentage, percentLabel, level, barStyle, usageLine}]`.
	 */
	get displayLimits()
	{
		const term = this.searchTerm.trim().toLowerCase();
		const rows = this.rawLimits
		.map((limit) =>
		{
			const percentage = percentageConsumed(limit.value, limit.max);
			return {
				key: limit.name,
				name: prettify(limit.name),
				rawName: limit.name,
				percentage,
				percentLabel: `${percentage}%`,
				level: bandLevel(percentage),
				barStyle: `width: ${Math.min(percentage, 100)}%;`,
				usageLine: formatLabel(USAGE, formatCount(limit.value, LOCALE), formatCount(limit.max, LOCALE))
			};
		})
		.filter((row) => !term || row.name.toLowerCase().includes(term) || row.rawName.toLowerCase().includes(term));

		if(this.sortKey === SORT_ALPHABETICAL)
		{
			return rows.sort((first, second) => first.name.localeCompare(second.name));
		}
		return rows.sort((first, second) => second.percentage - first.percentage || first.name.localeCompare(second.name));
	}

	/**
	 * @description Whether the grid has at least one card to show after search filtering.
	 * @returns {boolean}
	 */
	get hasLimits()
	{
		return this.displayLimits.length > 0;
	}

	/**
	 * @description Loads org-limit data from Apex once. A failure stores the error so the template
	 * can render a visible error state rather than a silent blank card.
	 */
	async connectedCallback()
	{
		try
		{
			this.rawLimits = await getOrgLimits();
		}
		catch(error)
		{
			this.error = JSON.stringify(error);
		}
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Applies the search term from the search box (client-side; no Apex re-query).
	 * @param {Event} event - Change event from the search input.
	 */
	handleSearch(event)
	{
		this.searchTerm = event.target.value;
	}

	/**
	 * @description Applies the chosen sort order.
	 * @param {CustomEvent} event - Change event from the sort combobox.
	 */
	handleSort(event)
	{
		this.sortKey = event.detail.value;
	}
}