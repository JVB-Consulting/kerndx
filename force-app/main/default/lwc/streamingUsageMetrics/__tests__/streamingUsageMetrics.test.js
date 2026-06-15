// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for the streamingUsageMetrics LWC component. Exercises the
 * native-SVG (no-D3) redesign: imperative loads, zero-padded bucket axis, log-scaled bars,
 * the searchfilterchange refetch / displayfilterchange client-side split, chart/table view
 * switch, and the empty/error states.
 * @author Jason van Beukering
 * @date December 2025, June 2026
 */
import {createElement} from 'lwc';
import LOCALE from '@salesforce/i18n/locale';
import TIME_ZONE from '@salesforce/i18n/timeZone';
import COUNT_NO_DATA from '@salesforce/label/c.EventUsageMetrics_CountBadge_NoData';
import COUNT_SHOWING_ALL from '@salesforce/label/c.EventUsageMetrics_CountBadge_ShowingAll';
import COUNT_SHOWING_FILTERED from '@salesforce/label/c.EventUsageMetrics_CountBadge_ShowingFiltered';

jest.mock('c/utilityStreaming', () => ({
	getCompactTimeLabel: jest.fn((time, segment) => `c:${segment}:${time instanceof Date ? time.getTime() : time}`),
	formatCount: jest.fn((value) => (value == null ? '' : String(value))),
	toTitleCase: jest.fn(
			(value) => (typeof value === 'string' ? value.replace(/[-_]/g, ' ').replace(/\w\S*/g, (word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()) : ''))
}), {virtual: true});

jest.mock('c/utilityLogger', () => ({
	__esModule: true, default: {
		error: jest.fn(), warn: jest.fn(), info: jest.fn(), debug: jest.fn()
	}
}), {virtual: true});

// The @lwc/jest-transformer rewrites each `import x from '@salesforce/apex/...'` into a catch-block
// fallback `x = global.__lwcJestMock_<name> || function <name>(){}`. Pre-seeding those globals with
// jest.fns before the component is required gives the test control of the resolved values AND covers
// the truthy-LHS branch the transformer generates (the retryApiIssue technique). Because the seeding
// must precede the require, the component is loaded lazily in createComponent, not at module top.
let getEventUsageMetrics;
let isEnhancedUsageMetricEnabled;
let resizeObserve;
let resizeDisconnect;
let resizeCallback;

beforeAll(() =>
{
	getEventUsageMetrics = jest.fn();
	isEnhancedUsageMetricEnabled = jest.fn();
	global.__lwcJestMock_getEventUsageMetrics = getEventUsageMetrics;
	global.__lwcJestMock_isEnhancedUsageMetricEnabled = isEnhancedUsageMetricEnabled;
	global.ResizeObserver = class
	{
		constructor(callback)
		{
			resizeCallback = callback;
		}

		observe(...args)
		{
			resizeObserve(...args);
		}

		disconnect(...args)
		{
			resizeDisconnect(...args);
		}
	};
});

afterAll(() =>
{
	delete global.__lwcJestMock_getEventUsageMetrics;
	delete global.__lwcJestMock_isEnhancedUsageMetricEnabled;
});

const MS_PER_HOUR = 3600000;
const MS_PER_DAY = 24 * MS_PER_HOUR;

const SINGLE_SERIES_DAILY = [
	{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-01T00:00:00.000Z', Value: 100},
	{Name: 'CDC_EVENTS_PUBLISHED', StartDate: '2026-06-01T00:00:00.000Z', Value: 40}
];

describe('c-streaming-usage-metrics', () =>
{
	beforeEach(() =>
	{
		resizeObserve = jest.fn();
		resizeDisconnect = jest.fn();
		isEnhancedUsageMetricEnabled.mockResolvedValue(true);
		getEventUsageMetrics.mockResolvedValue(SINGLE_SERIES_DAILY);
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

	async function createComponent()
	{
		const StreamingUsageMetrics = require('c/streamingUsageMetrics').default;
		const element = createElement('c-streaming-usage-metrics', {is: StreamingUsageMetrics});
		document.body.appendChild(element);
		await flushPromises();
		await flushPromises();
		return element;
	}

	function bars(element)
	{
		return element.shadowRoot.querySelectorAll('[data-testid="usage-bar"]');
	}

	function badgeLabel(element)
	{
		return element.shadowRoot.querySelector('[data-spec-id="usage-count-badge"]').label;
	}

	function dispatchFromChild(element, eventName, detail)
	{
		const filters = element.shadowRoot.querySelector('c-streaming-usage-filters');
		filters.dispatchEvent(new CustomEvent(eventName, {detail}));
	}

	it('probes the org and fetches the Daily 30-day default on connect, rendering bars and a Showing-all badge', async() =>
	{
		const element = await createComponent();

		expect(isEnhancedUsageMetricEnabled).toHaveBeenCalledTimes(1);
		expect(getEventUsageMetrics).toHaveBeenCalledTimes(1);
		const args = getEventUsageMetrics.mock.calls[0][0];
		expect(args.timeSegment).toBe('Daily');
		const spanMs = Date.parse(args.endDate) - Date.parse(args.startDate);
		expect(Math.round(spanMs / MS_PER_DAY)).toBe(30);

		expect(bars(element).length).toBeGreaterThan(0);
		expect(badgeLabel(element)).toBe(COUNT_SHOWING_ALL);
	});

	it('zero-pads buckets the server omitted and renders them at the baseline', async() =>
	{
		const start = new Date('2026-06-02T00:00:00.000Z');
		getEventUsageMetrics.mockResolvedValue([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T03:00:00.000Z', Value: 120},
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T07:00:00.000Z', Value: 80}
		]);
		const element = await createComponent();

		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: new Date(start.getTime() + 24 * MS_PER_HOUR).toISOString()
		});
		await flushPromises();

		const allBars = bars(element);
		expect(allBars.length).toBe(25);
		const nonZero = [...allBars].filter((bar) => parseFloat(bar.getAttribute('height')) > 0);
		expect(nonZero.length).toBe(2);
	});

	it('refetches with the new arguments when the child emits searchfilterchange', async() =>
	{
		const element = await createComponent();
		expect(getEventUsageMetrics).toHaveBeenCalledTimes(1);

		const start = new Date('2026-06-02T00:00:00.000Z');
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: new Date(start.getTime() + 12 * MS_PER_HOUR).toISOString()
		});
		await flushPromises();

		expect(getEventUsageMetrics).toHaveBeenCalledTimes(2);
		expect(getEventUsageMetrics.mock.calls[1][0].timeSegment).toBe('Hourly');
	});

	it('hides a series and reflects a Showing-filtered badge on displayfilterchange without refetching', async() =>
	{
		const element = await createComponent();
		const totalBars = bars(element).length;
		expect(getEventUsageMetrics).toHaveBeenCalledTimes(1);

		dispatchFromChild(element, 'displayfilterchange', {
			visibleTypes: [
				true,
				false
			]
		});
		await flushPromises();

		expect(getEventUsageMetrics).toHaveBeenCalledTimes(1);
		expect(bars(element).length).toBeLessThan(totalBars);
		expect(badgeLabel(element)).toBe(COUNT_SHOWING_FILTERED);
	});

	it('shows the error state and logs when the fetch rejects, then clears it and refetches on Retry', async() =>
	{
		const utilityLogger = require('c/utilityLogger').default;
		getEventUsageMetrics.mockRejectedValueOnce(new Error('boom'));
		const element = await createComponent();

		expect(element.shadowRoot.querySelector('[data-spec-id="usage-error-state"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('.usage-chart')).toBeNull();
		expect(utilityLogger.error).toHaveBeenCalled();

		getEventUsageMetrics.mockResolvedValue(SINGLE_SERIES_DAILY);
		element.shadowRoot.querySelector('[data-spec-id="usage-error-retry"]').click();
		await flushPromises();

		expect(element.shadowRoot.querySelector('[data-spec-id="usage-error-state"]')).toBeNull();
		expect(bars(element).length).toBeGreaterThan(0);
		expect(getEventUsageMetrics).toHaveBeenCalledTimes(2);
	});

	it('shows the empty state for an empty result and refetches defaults on Reset', async() =>
	{
		getEventUsageMetrics.mockResolvedValueOnce([]);
		const element = await createComponent();

		expect(element.shadowRoot.querySelector('[data-spec-id="usage-empty-state"]')).not.toBeNull();
		expect(bars(element).length).toBe(0);
		expect(badgeLabel(element)).toBe(COUNT_NO_DATA);

		element.shadowRoot.querySelector('[data-spec-id="usage-clear-filters"]').click();
		await flushPromises();

		expect(getEventUsageMetrics).toHaveBeenCalledTimes(2);
		expect(getEventUsageMetrics.mock.calls[1][0].timeSegment).toBe('Daily');
	});

	it('shows the empty state when every series is hidden', async() =>
	{
		const element = await createComponent();
		dispatchFromChild(element, 'displayfilterchange', {
			visibleTypes: [
				false,
				false
			]
		});
		await flushPromises();

		expect(element.shadowRoot.querySelector('[data-spec-id="usage-empty-state"]')).not.toBeNull();
		expect(bars(element).length).toBe(0);
	});

	it('renders the table view newest-first with a column per visible series, then switches back to the chart', async() =>
	{
		const start = new Date('2026-06-02T00:00:00.000Z');
		getEventUsageMetrics.mockResolvedValue([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T00:00:00.000Z', Value: 10},
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T01:00:00.000Z', Value: 20}
		]);
		const element = await createComponent();
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: new Date(start.getTime() + MS_PER_HOUR).toISOString()
		});
		await flushPromises();

		element.shadowRoot.querySelector('[data-spec-id="usage-view-table"]').click();
		await flushPromises();

		const table = element.shadowRoot.querySelector('[data-spec-id="usage-table"]');
		expect(table).not.toBeNull();
		const headerCells = table.querySelectorAll('thead th');
		expect(headerCells.length).toBe(2);
		const firstRowCells = table.querySelectorAll('tbody tr:first-child td');
		expect(firstRowCells[firstRowCells.length - 1].textContent).toBe('20');

		element.shadowRoot.querySelector('[data-spec-id="usage-view-chart"]').click();
		await flushPromises();
		expect(element.shadowRoot.querySelector('[data-spec-id="usage-table"]')).toBeNull();
		expect(element.shadowRoot.querySelector('.usage-chart')).not.toBeNull();
	});

	it('passes the enhanced-usage flag to the child as false when the probe reports it disabled', async() =>
	{
		isEnhancedUsageMetricEnabled.mockResolvedValue(false);
		const element = await createComponent();

		const filters = element.shadowRoot.querySelector('c-streaming-usage-filters');
		expect(filters.isEnhancedUsageMetricEnabled).toBe(false);
	});

	it('defaults the enhanced-usage flag to false and logs when the probe rejects', async() =>
	{
		const utilityLogger = require('c/utilityLogger').default;
		isEnhancedUsageMetricEnabled.mockRejectedValueOnce(new Error('probe down'));
		const element = await createComponent();

		const filters = element.shadowRoot.querySelector('c-streaming-usage-filters');
		expect(filters.isEnhancedUsageMetricEnabled).toBe(false);
		expect(utilityLogger.error).toHaveBeenCalled();
	});

	it('observes the chart host and disconnects the ResizeObserver on disconnect', async() =>
	{
		const element = await createComponent();
		expect(resizeObserve).toHaveBeenCalledTimes(1);

		document.body.removeChild(element);
		expect(resizeDisconnect).toHaveBeenCalledTimes(1);
	});

	it('builds a tooltip with the bucket time and one row per visible series on bar hover, then hides it', async() =>
	{
		const start = new Date('2026-06-02T00:00:00.000Z');
		getEventUsageMetrics.mockResolvedValue([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T00:00:00.000Z', Value: 55}
		]);
		const element = await createComponent();
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: start.toISOString()
		});
		await flushPromises();

		const firstBar = element.shadowRoot.querySelector('[data-testid="usage-bar"]');
		firstBar.dispatchEvent(new MouseEvent('mouseenter', {clientX: 100, clientY: 100, bubbles: true}));
		await flushPromises();

		const tooltip = element.shadowRoot.querySelector('[data-spec-id="usage-tooltip"]');
		expect(tooltip).not.toBeNull();
		expect(tooltip.querySelectorAll('.tt-row').length).toBe(1);
		expect(tooltip.textContent).toContain('55');

		firstBar.dispatchEvent(new MouseEvent('mouseleave', {bubbles: true}));
		await flushPromises();
		expect(element.shadowRoot.querySelector('[data-spec-id="usage-tooltip"]')).toBeNull();
	});

	it('refreshes with the last search arguments when the refresh button is clicked', async() =>
	{
		const element = await createComponent();
		const start = new Date('2026-06-02T00:00:00.000Z');
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: new Date(start.getTime() + MS_PER_HOUR).toISOString()
		});
		await flushPromises();
		expect(getEventUsageMetrics).toHaveBeenCalledTimes(2);

		element.shadowRoot.querySelector('[data-spec-id="usage-refresh"]').click();
		await flushPromises();

		expect(getEventUsageMetrics).toHaveBeenCalledTimes(3);
		expect(getEventUsageMetrics.mock.calls[2][0].timeSegment).toBe('Hourly');
	});

	it('exposes the card title through a labelled, spec-tagged slot', async() =>
	{
		const element = await createComponent();
		const title = element.shadowRoot.querySelector('[data-spec-id="usage-card-title"]');
		expect(title).not.toBeNull();
		expect(title.textContent.trim().length).toBeGreaterThan(0);
	});

	it('resizes the chart to the width reported by the ResizeObserver and ignores non-positive widths', async() =>
	{
		const element = await createComponent();
		expect(element.shadowRoot.querySelector('.usage-chart').getAttribute('viewBox')).toBe('0 0 1000 400');

		resizeCallback([{contentRect: {width: 640}}]);
		await flushPromises();
		expect(element.shadowRoot.querySelector('.usage-chart').getAttribute('viewBox')).toBe('0 0 640 400');

		resizeCallback([{contentRect: {width: 0}}]);
		await flushPromises();
		expect(element.shadowRoot.querySelector('.usage-chart').getAttribute('viewBox')).toBe('0 0 640 400');
	});

	it('renders the chart without a ResizeObserver when the browser does not provide one', async() =>
	{
		const realResizeObserver = global.ResizeObserver;
		global.ResizeObserver = undefined;
		try
		{
			const element = await createComponent();
			expect(element.shadowRoot.querySelector('.usage-chart')).not.toBeNull();
			expect(resizeObserve).not.toHaveBeenCalled();
		}
		finally
		{
			global.ResizeObserver = realResizeObserver;
		}
	});

	it('ignores a bar hover whose bucket is no longer present', async() =>
	{
		const element = await createComponent();
		const bar = element.shadowRoot.querySelector('[data-testid="usage-bar"]');
		bar.setAttribute('data-bucket', '1');
		bar.dispatchEvent(new MouseEvent('mouseenter', {clientX: 50, clientY: 50, bubbles: true}));
		await flushPromises();

		expect(element.shadowRoot.querySelector('[data-spec-id="usage-tooltip"]')).toBeNull();
	});

	it('treats a null result as no data', async() =>
	{
		getEventUsageMetrics.mockResolvedValueOnce(null);
		const element = await createComponent();

		expect(element.shadowRoot.querySelector('[data-spec-id="usage-empty-state"]')).not.toBeNull();
		expect(badgeLabel(element)).toBe(COUNT_NO_DATA);
	});

	it('floors a non-zero "1 event" bucket to a visible height while leaving omitted buckets flat', async() =>
	{
		const start = new Date('2026-06-02T00:00:00.000Z');
		getEventUsageMetrics.mockResolvedValue([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T00:00:00.000Z', Value: 1}
		]);
		const element = await createComponent();
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: new Date(start.getTime() + MS_PER_HOUR).toISOString()
		});
		await flushPromises();

		const heights = [...bars(element)].map((bar) => parseFloat(bar.getAttribute('height')));
		expect(heights).toContain(0); // the server-omitted bucket stays on the baseline
		expect(heights.some((height) => height >= 2)).toBe(true); // the value-1 bucket is lifted clear of it
		expect(heights).not.toContain(Number.NaN);
	});

	it('keeps the latest result when an earlier slow search resolves after a newer one', async() =>
	{
		const element = await createComponent();

		let resolveStale;
		getEventUsageMetrics.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveStale = resolve;
		}));
		const staleStart = new Date('2026-06-02T00:00:00.000Z');
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: staleStart.toISOString(), endDate: new Date(staleStart.getTime() + 24 * MS_PER_HOUR).toISOString()
		});
		await flushPromises();

		getEventUsageMetrics.mockResolvedValueOnce([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-03T00:00:00.000Z', Value: 5}
		]);
		const freshStart = new Date('2026-06-03T00:00:00.000Z');
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: freshStart.toISOString(), endDate: new Date(freshStart.getTime() + MS_PER_HOUR).toISOString()
		});
		await flushPromises();
		const freshBarCount = bars(element).length;
		expect(freshBarCount).toBe(2);

		// The stale window covers 24h with two series — 50 bars if (wrongly) applied — so a regression
		// that dropped the latest-wins guard would visibly change the count.
		resolveStale([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: staleStart.toISOString(), Value: 99},
			{Name: 'CDC_EVENTS_PUBLISHED', StartDate: staleStart.toISOString(), Value: 77}
		]);
		await flushPromises();

		expect(bars(element).length).toBe(freshBarCount);
	});

	it('ignores a stale rejection that arrives after a newer search has already succeeded', async() =>
	{
		const utilityLogger = require('c/utilityLogger').default;
		const element = await createComponent();

		let rejectStale;
		getEventUsageMetrics.mockReturnValueOnce(new Promise((resolve, reject) =>
		{
			rejectStale = reject;
		}));
		const staleStart = new Date('2026-06-02T00:00:00.000Z');
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: staleStart.toISOString(), endDate: new Date(staleStart.getTime() + 24 * MS_PER_HOUR).toISOString()
		});
		await flushPromises();

		getEventUsageMetrics.mockResolvedValueOnce([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-03T00:00:00.000Z', Value: 5}
		]);
		const freshStart = new Date('2026-06-03T00:00:00.000Z');
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: freshStart.toISOString(), endDate: new Date(freshStart.getTime() + MS_PER_HOUR).toISOString()
		});
		await flushPromises();
		expect(element.shadowRoot.querySelector('[data-spec-id="usage-error-state"]')).toBeNull();
		utilityLogger.error.mockClear();

		rejectStale(new Error('stale failure'));
		await flushPromises();

		expect(element.shadowRoot.querySelector('[data-spec-id="usage-error-state"]')).toBeNull();
		expect(utilityLogger.error).not.toHaveBeenCalled();
	});

	it('floors off-grid rows onto the bucket axis and keeps the chip total equal to the plotted total', async() =>
	{
		// Live-evidenced shape: a fresh scratch org returns daily PlatformEventUsageMetric rows anchored
		// at 09:00:00Z, which an exact-equality bucket join silently drops from the chart while the
		// legend chip still counts them.
		getEventUsageMetrics.mockResolvedValue([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T00:00:00.000Z', Value: 100},
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-03T09:00:00.000Z', Value: 40}
		]);
		const element = await createComponent();
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Daily', startDate: '2026-06-02T00:00:00.000Z', endDate: '2026-06-04T00:00:00.000Z'
		});
		await flushPromises();

		const nonZeroBars = [...bars(element)].filter((bar) => parseFloat(bar.getAttribute('height')) > 0);
		expect(nonZeroBars.length).toBe(2);

		const filters = element.shadowRoot.querySelector('c-streaming-usage-filters');
		const chipTotal = filters.eventTypes[0].total;
		element.shadowRoot.querySelector('[data-spec-id="usage-view-table"]').click();
		await flushPromises();
		const cellValues = [...element.shadowRoot.querySelectorAll('[data-spec-id="usage-table"] td.num')].map((cell) => Number(cell.textContent));
		const plottedTotal = cellValues.reduce((sum, value) => sum + value, 0);
		expect(plottedTotal).toBe(chipTotal);
		expect(chipTotal).toBe(140);
	});

	it('sums rows that floor to the same bucket', async() =>
	{
		getEventUsageMetrics.mockResolvedValue([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T00:00:00.000Z', Value: 30},
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T09:00:00.000Z', Value: 12}
		]);
		const element = await createComponent();
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Daily', startDate: '2026-06-02T00:00:00.000Z', endDate: '2026-06-02T00:00:00.000Z'
		});
		await flushPromises();

		element.shadowRoot.querySelector('[data-spec-id="usage-view-table"]').click();
		await flushPromises();
		const cells = [...element.shadowRoot.querySelectorAll('[data-spec-id="usage-table"] td.num')];
		expect(cells.map((cell) => cell.textContent)).toEqual(['42']);
	});

	it('passes the user timezone and locale to every compact-label call site (ticks, table, tooltip)', async() =>
	{
		const {getCompactTimeLabel} = require('c/utilityStreaming');
		const start = new Date('2026-06-02T00:00:00.000Z');
		getEventUsageMetrics.mockResolvedValue([
			{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: '2026-06-02T00:00:00.000Z', Value: 55}
		]);
		const element = await createComponent();
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: start.toISOString()
		});
		await flushPromises();

		// Chart view renders the axis ticks; hovering renders the tooltip; the table view renders
		// the period column — every one of those labels must be in the user's timezone and locale,
		// not the browser default.
		const bar = element.shadowRoot.querySelector('[data-testid="usage-bar"]');
		bar.dispatchEvent(new MouseEvent('mouseenter', {clientX: 100, clientY: 100, bubbles: true}));
		await flushPromises();
		element.shadowRoot.querySelector('[data-spec-id="usage-view-table"]').click();
		await flushPromises();

		expect(getCompactTimeLabel).toHaveBeenCalled();
		getCompactTimeLabel.mock.calls.forEach((callArguments) =>
		{
			expect(callArguments[2]).toBe(TIME_ZONE);
			expect(callArguments[3]).toBe(LOCALE);
		});
	});

	it('keeps a hidden series hidden across a Refresh refetch, in both the badge and the legend chips', async() =>
	{
		const element = await createComponent();
		// Hide the second chip through the real path — clicking the child's legend chip — so the
		// child's own visibility state toggles too, exactly as a user interaction would.
		// Sorted series order is [CDC_EVENTS_PUBLISHED, PLATFORM_EVENTS_PUBLISHED].
		const filtersChild = element.shadowRoot.querySelector('c-streaming-usage-filters');
		filtersChild.shadowRoot.querySelectorAll('[data-spec-id="usage-legend-chip"]')[1].click();
		await flushPromises();
		const filteredBarCount = bars(element).length;
		expect(badgeLabel(element)).toBe(COUNT_SHOWING_FILTERED);

		element.shadowRoot.querySelector('[data-spec-id="usage-refresh"]').click();
		await flushPromises();

		expect(bars(element).length).toBe(filteredBarCount);
		expect(badgeLabel(element)).toBe(COUNT_SHOWING_FILTERED);
		const filters = element.shadowRoot.querySelector('c-streaming-usage-filters');
		const chips = filters.shadowRoot.querySelectorAll('[data-spec-id="usage-legend-chip"]');
		expect([...chips].map((chip) => chip.getAttribute('aria-pressed'))).toEqual([
			'true',
			'false'
		]);
	});

	it('defaults a newly appearing series to visible while keeping prior selections on refetch', async() =>
	{
		const element = await createComponent();
		// Hide CDC_EVENTS_PUBLISHED (first in sorted order) through the real chip-click path.
		const filtersChild = element.shadowRoot.querySelector('c-streaming-usage-filters');
		filtersChild.shadowRoot.querySelectorAll('[data-spec-id="usage-legend-chip"]')[0].click();
		await flushPromises();

		getEventUsageMetrics.mockResolvedValue([
			...SINGLE_SERIES_DAILY,
			{Name: 'STANDARD_VOLUME_EVENTS_PUBLISHED', StartDate: '2026-06-01T00:00:00.000Z', Value: 7}
		]);
		element.shadowRoot.querySelector('[data-spec-id="usage-refresh"]').click();
		await flushPromises();

		const filters = element.shadowRoot.querySelector('c-streaming-usage-filters');
		const chips = filters.shadowRoot.querySelectorAll('[data-spec-id="usage-legend-chip"]');
		expect([...chips].map((chip) => chip.getAttribute('aria-pressed'))).toEqual([
			'false',
			'true',
			'true'
		]);
		expect(badgeLabel(element)).toBe(COUNT_SHOWING_FILTERED);
	});

	it('drops the stale selection of a vanished series so it returns visible on a later refetch', async() =>
	{
		const element = await createComponent();
		// Hide PLATFORM_EVENTS_PUBLISHED (second in sorted order), then refetch without it.
		dispatchFromChild(element, 'displayfilterchange', {
			visibleTypes: [
				true,
				false
			]
		});
		await flushPromises();

		getEventUsageMetrics.mockResolvedValue([
			{Name: 'CDC_EVENTS_PUBLISHED', StartDate: '2026-06-01T00:00:00.000Z', Value: 40}
		]);
		element.shadowRoot.querySelector('[data-spec-id="usage-refresh"]').click();
		await flushPromises();
		expect(badgeLabel(element)).toBe(COUNT_SHOWING_ALL);

		// The vanished series returns — its stale hidden entry must not have been remembered.
		getEventUsageMetrics.mockResolvedValue(SINGLE_SERIES_DAILY);
		element.shadowRoot.querySelector('[data-spec-id="usage-refresh"]').click();
		await flushPromises();
		expect(badgeLabel(element)).toBe(COUNT_SHOWING_ALL);
	});

	it('restores every series to visible when Reset filters is clicked from the all-hidden empty state', async() =>
	{
		const element = await createComponent();
		dispatchFromChild(element, 'displayfilterchange', {
			visibleTypes: [
				false,
				false
			]
		});
		await flushPromises();
		expect(element.shadowRoot.querySelector('[data-spec-id="usage-empty-state"]')).not.toBeNull();

		element.shadowRoot.querySelector('[data-spec-id="usage-clear-filters"]').click();
		await flushPromises();

		expect(bars(element).length).toBeGreaterThan(0);
		expect(badgeLabel(element)).toBe(COUNT_SHOWING_ALL);
	});

	it('drops a fetch resolution that arrives after the component is disconnected', async() =>
	{
		const {toTitleCase} = require('c/utilityStreaming');
		const element = await createComponent();

		let resolveInFlight;
		getEventUsageMetrics.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveInFlight = resolve;
		}));
		const start = new Date('2026-06-02T00:00:00.000Z');
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: new Date(start.getTime() + MS_PER_HOUR).toISOString()
		});
		await flushPromises();

		document.body.removeChild(element);
		toTitleCase.mockClear();

		// Resolving after disconnect must be dropped — applyMetrics (whose series derivation calls
		// toTitleCase) must never run against the dead component.
		resolveInFlight([{Name: 'PLATFORM_EVENTS_PUBLISHED', StartDate: start.toISOString(), Value: 9}]);
		await flushPromises();

		expect(toTitleCase).not.toHaveBeenCalled();
	});

	it('drops a fetch rejection that arrives after the component is disconnected', async() =>
	{
		const utilityLogger = require('c/utilityLogger').default;
		const element = await createComponent();

		let rejectInFlight;
		getEventUsageMetrics.mockReturnValueOnce(new Promise((resolve, reject) =>
		{
			rejectInFlight = reject;
		}));
		const start = new Date('2026-06-02T00:00:00.000Z');
		dispatchFromChild(element, 'searchfilterchange', {
			timeSegment: 'Hourly', startDate: start.toISOString(), endDate: new Date(start.getTime() + MS_PER_HOUR).toISOString()
		});
		await flushPromises();

		document.body.removeChild(element);
		utilityLogger.error.mockClear();

		rejectInFlight(new Error('late failure'));
		await flushPromises();

		expect(utilityLogger.error).not.toHaveBeenCalled();
	});

	it('does not issue the initial metrics query when disconnected during the capability probe', async() =>
	{
		let resolveProbe;
		isEnhancedUsageMetricEnabled.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveProbe = resolve;
		}));
		const StreamingUsageMetrics = require('c/streamingUsageMetrics').default;
		const element = createElement('c-streaming-usage-metrics', {is: StreamingUsageMetrics});
		document.body.appendChild(element);
		await flushPromises();

		document.body.removeChild(element);
		resolveProbe(true);
		await flushPromises();

		expect(getEventUsageMetrics).not.toHaveBeenCalled();
	});

	it('loads with the transformer apex fallback when no mock global is seeded', () =>
	{
		delete global.__lwcJestMock_getEventUsageMetrics;
		delete global.__lwcJestMock_isEnhancedUsageMetricEnabled;
		let StreamingUsageMetrics;
		jest.isolateModules(() =>
		{
			StreamingUsageMetrics = require('c/streamingUsageMetrics').default;
		});
		expect(typeof StreamingUsageMetrics).toBe('function');
		global.__lwcJestMock_getEventUsageMetrics = getEventUsageMetrics;
		global.__lwcJestMock_isEnhancedUsageMetricEnabled = isEnhancedUsageMetricEnabled;
	});
});
