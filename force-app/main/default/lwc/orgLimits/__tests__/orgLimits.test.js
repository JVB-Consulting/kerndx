// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the orgLimits LWC card-grid redesign (PLAN-108). Exercises the
 * worst-first ordering, the 70/90 colour bands, the cosmetic name prettify, client-side search and
 * sort, the locale-aware usage line, the max==0 guard, and the loading/empty/error states.
 * @author Jason van Beukering
 * @date July 2026
 */
import {createElement} from 'lwc';
import CARD_TITLE from '@salesforce/label/c.OrgLimits_CardTitle';
import NOTICE from '@salesforce/label/c.OrgLimits_Notice';
import ERROR_BODY from '@salesforce/label/c.OrgLimits_Error_Body';
import EMPTY_LABEL from '@salesforce/label/c.OrgLimits_Empty';
import SORT_WORST from '@salesforce/label/c.OrgLimits_Sort_WorstFirst';
import SORT_NAME from '@salesforce/label/c.OrgLimits_Sort_Name';

jest.mock('@salesforce/i18n/locale', () => ({default: 'en-US'}), {virtual: true});

// The usage line interpolates two positional tokens; the default label stub carries no placeholders,
// so mock it to its real template to assert the interpolated, locale-formatted result.
jest.mock('@salesforce/label/c.OrgLimits_Usage', () => ({default: '{0} of {1}'}), {virtual: true});

// The @lwc/jest-transformer rewrites `import getOrgLimits from '@salesforce/apex/...'` into a fallback
// `getOrgLimits = global.__lwcJestMock_getOrgLimits || function getOrgLimits(){}`. Pre-seeding that
// global with a jest.fn before the component is required gives the test control of the resolved value
// and covers the truthy-LHS branch. Because the seeding must precede the require, the component is
// loaded lazily in createComponent, not at module top.
let getOrgLimits;

beforeAll(() =>
{
	getOrgLimits = jest.fn();
	global.__lwcJestMock_getOrgLimits = getOrgLimits;
});

afterAll(() =>
{
	delete global.__lwcJestMock_getOrgLimits;
});

const MIXED = [
	{name: 'DataStorageMB', value: 69, max: 100},        // 69% green  -> "Data Storage MB"
	{name: 'HourlyODataCallout', value: 70, max: 100},   // 70% amber  -> "Hourly OData Callout"
	{name: 'DailyApiRequests', value: 95, max: 100},     // 95% red    -> "Daily API Requests"
	{name: 'PermissionSets', value: 100, max: 100},      // 100% red   -> "Permission Sets"
	{name: 'MassEmail', value: 0, max: 0}                // 0% (max==0) -> "Mass Email"
];
const MIXED_WORST_FIRST = [
	'Permission Sets',
	'Daily API Requests',
	'Hourly OData Callout',
	'Data Storage MB',
	'Mass Email'
];
const MIXED_ALPHABETICAL = [
	'Daily API Requests',
	'Data Storage MB',
	'Hourly OData Callout',
	'Mass Email',
	'Permission Sets'
];

describe('c-org-limits', () =>
{
	beforeEach(() =>
	{
		getOrgLimits.mockResolvedValue(MIXED);
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	function flushPromises()
	{
		return new Promise((resolve) => setTimeout(resolve, 0));
	}

	function createComponent()
	{
		const LwcOrgLimits = require('c/orgLimits').default;
		const element = createElement('c-org-limits', {is: LwcOrgLimits});
		document.body.appendChild(element);
		return element;
	}

	async function renderWith(limits)
	{
		getOrgLimits.mockResolvedValueOnce(limits);
		const element = createComponent();
		await flushPromises();
		return element;
	}

	function cards(element)
	{
		return [...element.shadowRoot.querySelectorAll('[data-testid="org-limits-card"]')];
	}

	function cardNames(element)
	{
		return cards(element).map((card) => card.querySelector('.limit-name').textContent.trim());
	}

	// ── Initialization ───────────────────────────────────────────────────

	it('loads org limits from Apex exactly once on connect', async() =>
	{
		await renderWith(MIXED);
		expect(getOrgLimits).toHaveBeenCalledTimes(1);
	});

	it('renders the card title and notice from labels', async() =>
	{
		const element = await renderWith(MIXED);
		expect(element.shadowRoot.querySelector('[data-spec-id="org-limits-title"]').textContent).toBe(CARD_TITLE);
		expect(element.shadowRoot.querySelector('[data-spec-id="org-limits-notice"]').textContent).toContain(NOTICE);
	});

	it('shows a spinner while the Apex call is pending', () =>
	{
		getOrgLimits.mockReturnValueOnce(new Promise(() =>
		{
		}));
		const element = createComponent();
		expect(element.shadowRoot.querySelector('lightning-spinner')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-spec-id="org-limits-grid"]')).toBeNull();
	});

	// ── Grid + card anatomy ──────────────────────────────────────────────

	it('renders one card per limit inside the grid', async() =>
	{
		const element = await renderWith(MIXED);
		expect(element.shadowRoot.querySelector('[data-spec-id="org-limits-grid"]')).not.toBeNull();
		expect(cards(element)).toHaveLength(MIXED.length);
	});

	it('gives each card a progress bar carrying aria-valuenow and the raw name as aria-label', async() =>
	{
		const element = await renderWith(MIXED);
		for(const card of cards(element))
		{
			const bar = card.querySelector('[data-testid="limit-bar"]');
			expect(bar).not.toBeNull();
			expect(bar.getAttribute('role')).toBe('progressbar');
			expect(Number.isNaN(Number(bar.getAttribute('aria-valuenow')))).toBe(false);
			expect(bar.getAttribute('aria-label')).toBeTruthy();
		}
	});

	// ── Worst-first ordering ─────────────────────────────────────────────

	it('orders cards worst → best usage by default', async() =>
	{
		const element = await renderWith(MIXED);
		expect(cardNames(element)).toEqual(MIXED_WORST_FIRST);
	});

	it('breaks percentage ties alphabetically by prettified name', async() =>
	{
		const element = await renderWith([
			{name: 'BravoThing', value: 50, max: 100},
			{name: 'CharlieThing', value: 50, max: 100},
			{name: 'AlphaThing', value: 50, max: 100}
		]);
		expect(cardNames(element)).toEqual([
			'Alpha Thing',
			'Bravo Thing',
			'Charlie Thing'
		]);
	});

	// ── Colour bands ─────────────────────────────────────────────────────

	it('assigns the green/amber/red band as a pure function of percentage at every boundary', async() =>
	{
		const element = await renderWith([
			{name: 'Band00', value: 0, max: 100},
			{name: 'Band69', value: 69, max: 100},
			{name: 'Band70', value: 70, max: 100},
			{name: 'Band89', value: 89, max: 100},
			{name: 'Band90', value: 90, max: 100},
			{name: 'Band100', value: 100, max: 100},
			{name: 'BandZeroMax', value: 5, max: 0}
		]);
		const expectedLevel = (percent) => (percent >= 90 ? 'red' : percent >= 70 ? 'amber' : 'green');
		for(const card of cards(element))
		{
			const percent = Number(card.querySelector('[data-testid="limit-bar"]').getAttribute('aria-valuenow'));
			expect(card.getAttribute('data-level')).toBe(expectedLevel(percent));
			expect(card.querySelector('.limit-bar-fill').getAttribute('data-level')).toBe(expectedLevel(percent));
		}
	});

	it('caps the bar fill at 100% when usage exceeds the maximum', async() =>
	{
		const element = await renderWith([{name: 'OverLimit', value: 150, max: 100}]);
		const [card] = cards(element);
		expect(card.querySelector('[data-testid="limit-bar"]').getAttribute('aria-valuenow')).toBe('150');
		expect(card.getAttribute('data-level')).toBe('red');
		expect(card.querySelector('.limit-bar-fill').getAttribute('style')).toContain('100%');
	});

	// ── Name prettify ────────────────────────────────────────────────────

	it('prettifies API names, preserving acronyms and rejoining V-number tokens', async() =>
	{
		const element = await renderWith([
			{name: 'DailyApiRequests', value: 1, max: 100},
			{name: 'AnalyticsExternalDataSizeMB', value: 1, max: 100},
			{name: 'HourlyODataCallout', value: 1, max: 100},
			{name: 'DailyBulkV2QueryJobs', value: 1, max: 100},
			{name: 'DailyAsyncApexExecutions', value: 1, max: 100}
		]);
		expect(cardNames(element).sort()).toEqual([
			'Analytics External Data Size MB',
			'Daily API Requests',
			'Daily Async Apex Executions',
			'Daily Bulk V2 Query Jobs',
			'Hourly OData Callout'
		]);
	});

	it('keeps the raw API name available as the bar aria-label for search parity', async() =>
	{
		const element = await renderWith([{name: 'DailyApiRequests', value: 1, max: 100}]);
		expect(element.shadowRoot.querySelector('[data-testid="limit-bar"]').getAttribute('aria-label')).toBe('DailyApiRequests');
	});

	// ── max == 0 guard ───────────────────────────────────────────────────

	it('renders 0% (never NaN) for an unprovisioned max==0 limit and sorts it to the bottom', async() =>
	{
		const element = await renderWith(MIXED);
		const names = cardNames(element);
		expect(names[names.length - 1]).toBe('Mass Email');
		const massEmailCard = cards(element).find((card) => card.querySelector('.limit-name').textContent.trim() === 'Mass Email');
		expect(massEmailCard.querySelector('[data-testid="limit-bar"]').getAttribute('aria-valuenow')).toBe('0');
		expect(massEmailCard.querySelector('.limit-percent').textContent).toContain('0%');
	});

	// ── Usage line + percentage chip ─────────────────────────────────────

	it('renders a locale-formatted "{used} of {max}" usage line and a percentage chip', async() =>
	{
		const element = await renderWith([{name: 'DailyApiRequests', value: 4750000, max: 5000000}]);
		const [card] = cards(element);
		expect(card.querySelector('.limit-usage').textContent.trim()).toBe('4,750,000 of 5,000,000');
		expect(card.querySelector('.limit-percent').textContent.trim()).toBe('95%');
	});

	// ── Search ───────────────────────────────────────────────────────────

	it('filters the grid by the full typed text against the prettified name', async() =>
	{
		const element = await renderWith(MIXED);
		const search = element.shadowRoot.querySelector('[data-spec-id="org-limits-search"]');
		search.value = 'api';
		search.dispatchEvent(new CustomEvent('change'));
		await flushPromises();
		expect(cardNames(element)).toEqual(['Daily API Requests']);
	});

	it('matches the raw API name when the prettified name would not', async() =>
	{
		const element = await renderWith(MIXED);
		const search = element.shadowRoot.querySelector('[data-spec-id="org-limits-search"]');
		search.value = 'odatacallout';
		search.dispatchEvent(new CustomEvent('change'));
		await flushPromises();
		expect(cardNames(element)).toEqual(['Hourly OData Callout']);
	});

	it('shows the empty state (and hides the grid) when no limit matches', async() =>
	{
		const element = await renderWith(MIXED);
		const search = element.shadowRoot.querySelector('[data-spec-id="org-limits-search"]');
		search.value = 'zzznomatch';
		search.dispatchEvent(new CustomEvent('change'));
		await flushPromises();
		expect(element.shadowRoot.querySelector('[data-spec-id="org-limits-grid"]')).toBeNull();
		const empty = element.shadowRoot.querySelector('[data-spec-id="org-limits-empty"]');
		expect(empty).not.toBeNull();
		expect(empty.textContent).toContain(EMPTY_LABEL);
	});

	it('restores every card when the search is cleared', async() =>
	{
		const element = await renderWith(MIXED);
		const search = element.shadowRoot.querySelector('[data-spec-id="org-limits-search"]');
		search.value = 'api';
		search.dispatchEvent(new CustomEvent('change'));
		await flushPromises();
		search.value = '';
		search.dispatchEvent(new CustomEvent('change'));
		await flushPromises();
		expect(cards(element)).toHaveLength(MIXED.length);
	});

	// ── Sort ─────────────────────────────────────────────────────────────

	it('offers exactly the worst-first and name sort options', async() =>
	{
		const element = await renderWith(MIXED);
		const combobox = element.shadowRoot.querySelector('[data-spec-id="org-limits-sort"]');
		expect(combobox.options).toEqual([
			{label: SORT_WORST, value: 'worst'},
			{label: SORT_NAME, value: 'name'}
		]);
	});

	it('reorders the grid alphabetically when name sort is chosen', async() =>
	{
		const element = await renderWith(MIXED);
		const combobox = element.shadowRoot.querySelector('[data-spec-id="org-limits-sort"]');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'name'}}));
		await flushPromises();
		expect(cardNames(element)).toEqual(MIXED_ALPHABETICAL);
	});

	// ── Error state ──────────────────────────────────────────────────────

	it('renders the error state and hides the grid when the Apex call fails', async() =>
	{
		getOrgLimits.mockRejectedValueOnce({body: {message: 'boom'}});
		const element = createComponent();
		await flushPromises();
		const error = element.shadowRoot.querySelector('[data-spec-id="org-limits-error"]');
		expect(error).not.toBeNull();
		expect(error.textContent).toContain(ERROR_BODY);
		expect(element.shadowRoot.querySelector('[data-spec-id="org-limits-grid"]')).toBeNull();
	});

	// ── Transformer apex fallback ────────────────────────────────────────

	it('loads with the transformer apex fallback when no mock global is seeded', () =>
	{
		delete global.__lwcJestMock_getOrgLimits;
		let LwcOrgLimits;
		jest.isolateModules(() =>
		{
			LwcOrgLimits = require('c/orgLimits').default;
		});
		expect(typeof LwcOrgLimits).toBe('function');
		global.__lwcJestMock_getOrgLimits = getOrgLimits;
	});
});
