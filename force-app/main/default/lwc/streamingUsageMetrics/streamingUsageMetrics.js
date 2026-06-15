// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Event Usage Metrics view. Owns the chart, the chart/table view switch, the count
 * badge, and the empty/error states; the sibling streamingUsageFilters child owns the granularity,
 * date-range, legend, and enhanced-usage controls.
 *
 * Data flows imperatively: the org-capability probe runs once on connect, and the metrics query runs
 * on connect, on the child's `searchfilterchange` (a new granularity / preset / valid custom range),
 * and on Retry/Refresh/Reset. The chart is hand-rolled SVG — no D3, no static-resource load, no
 * `lwc:dom="manual"`.
 *
 * The server omits zero-activity rows, so the pipeline rebuilds the full bucket axis for the segment
 * and pads missing buckets with zero before charting. The legend's `displayfilterchange` is a
 * client-side show/hide that re-derives the bars without re-querying. Axis ticks, tooltip times, and
 * table periods render in the user's Salesforce timezone and locale (`@salesforce/i18n`), not the
 * browser default.
 *
 * @author Jason van Beukering
 * @date March 2026, June 2026
 */
import {LightningElement} from 'lwc';
import LOCALE from '@salesforce/i18n/locale';
import TIME_ZONE from '@salesforce/i18n/timeZone';
import getEventUsageMetrics from '@salesforce/apex/CTRL_EventMonitor.getEventUsageMetrics';
import isEnhancedUsageMetricEnabled from '@salesforce/apex/CTRL_EventMonitor.isEnhancedUsageMetricEnabled';
import {getCompactTimeLabel, formatCount, toTitleCase} from 'c/utilityStreaming';
import utilityLogger from 'c/utilityLogger';

import CARD_TITLE from '@salesforce/label/c.EventUsageMetrics_CardTitle';
import COUNT_NO_DATA from '@salesforce/label/c.EventUsageMetrics_CountBadge_NoData';
import COUNT_SHOWING_ALL from '@salesforce/label/c.EventUsageMetrics_CountBadge_ShowingAll';
import COUNT_SHOWING_FILTERED from '@salesforce/label/c.EventUsageMetrics_CountBadge_ShowingFiltered';
import EMPTY_HEADING from '@salesforce/label/c.EventUsageMetrics_Empty_Heading';
import EMPTY_BODY from '@salesforce/label/c.EventUsageMetrics_Empty_Body';
import ERROR_BODY from '@salesforce/label/c.EventUsageMetrics_Error_Body';
import ERROR_RETRY from '@salesforce/label/c.EventUsageMetrics_Error_Retry';
import RESET_FILTERS from '@salesforce/label/c.EventUsageMetrics_ResetFilters';
import TABLE_PERIOD_START from '@salesforce/label/c.EventUsageMetrics_Table_PeriodStart';
import VIEW_LABEL from '@salesforce/label/c.EventUsageMetrics_View_Label';
import VIEW_CHART_LABEL from '@salesforce/label/c.EventUsageMetrics_View_Chart';
import VIEW_TABLE_LABEL from '@salesforce/label/c.EventUsageMetrics_View_Table';

// ── Constants ────────────────────────────────────────────────────────────

const MILLISECONDS_PER_HOUR = 60 * 60 * 1000;
const MILLISECONDS_PER_DAY = 24 * MILLISECONDS_PER_HOUR;

const TIME_SEGMENT_DAILY = 'Daily';
const DAILY_DEFAULT_WINDOW_MS = 30 * MILLISECONDS_PER_DAY;

// Per-segment bucket width in milliseconds — must mirror the platform's TimeSegment step so the
// rebuilt axis aligns with the StartDate values the server returns.
const STEP_MS_BY_SEGMENT = {
	[TIME_SEGMENT_DAILY]: MILLISECONDS_PER_DAY, Hourly: MILLISECONDS_PER_HOUR, FifteenMinutes: 15 * 60 * 1000
};

// Fixed SLDS-derived series palette (cycled), matching the validated prototype.
const SERIES_COLORS = [
	'#0176D3',
	'#06A59A',
	'#9050E9',
	'#DD7A01'
];

const VIEW_CHART = 'chart';
const VIEW_TABLE = 'table';

const CHART_HEIGHT = 400;
const CHART_MARGIN = {top: 24, right: 16, bottom: 42, left: 56};
const DEFAULT_CHART_WIDTH = 1000;
const BAR_GROUP_WIDTH_RATIO = 0.82;
const BAR_CORNER_RADIUS = '1.5';
// Minimum rendered height (px) for a non-zero bucket. On the log axis a value of 1 maps to the
// baseline (height 0), making a "1 event" bucket indistinguishable from an omitted (zero) one; this
// floor lifts every non-zero bar just clear of the baseline while zero buckets stay flat.
const MINIMUM_NON_ZERO_BAR_HEIGHT = 2;
const X_TICK_TARGET_COUNT = 8;
const X_TICK_BASELINE_OFFSET = 16;
const GRIDLINE_LABEL_INSET = 8;
const GRIDLINE_LABEL_BASELINE = 3;
const TOOLTIP_CURSOR_OFFSET_X = 14;
const TOOLTIP_CURSOR_OFFSET_Y = 20;
const TOOLTIP_WIDTH = 220;

const EMPTY_TOOLTIP = Object.freeze({visible: false, style: '', time: '', rows: []});

// ── Pure pipeline helpers ──────────────────────────────────────────────────

/**
 * @description Rounds a coordinate to one decimal place to keep the rendered SVG attributes compact.
 * @param {number} value - The raw coordinate.
 * @returns {number} The value rounded to one decimal place.
 */
function roundCoordinate(value)
{
	return Math.round(value * 10) / 10;
}

/**
 * @description Substitutes ordered `{0}`, `{1}`, … placeholders in a label template.
 * @param {string} template - The label text containing the placeholders.
 * @param {Array<string>} values - The replacement values, applied positionally.
 * @returns {string} The interpolated string.
 */
function formatLabel(template, values)
{
	return values.reduce((text, value, index) => text.replace(`{${index}}`, value), template);
}

/**
 * @description Reduces raw Apex rows to chart-ready points keyed on series name and bucket timestamp.
 * @param {Array<Object>} rows - Raw `PlatformEventUsageMetric` rows (`Name`, `StartDate`, `Value`).
 * @returns {Array<{name: string, timestamp: number, value: number}>} Normalized points.
 */
function normalizeMetrics(rows)
{
	return (rows ?? []).map((row) => ({
		name: row.Name, timestamp: new Date(row.StartDate).getTime(), value: row.Value
	}));
}

/**
 * @description Builds the full list of bucket-start timestamps for a segment and range, aligned to
 * the segment's step boundary so the axis matches the server's StartDate values.
 * @param {string} segment - `Daily`, `Hourly`, or `FifteenMinutes`.
 * @param {number} startMs - Inclusive range start in epoch milliseconds.
 * @param {number} endMs - Inclusive range end in epoch milliseconds.
 * @returns {Array<number>} The aligned bucket-start timestamps.
 */
function generateBucketAxis(segment, startMs, endMs)
{
	const step = STEP_MS_BY_SEGMENT[segment];
	const firstBucket = Math.ceil(startMs / step) * step;
	const timestamps = [];
	for(let timestamp = firstBucket; timestamp <= endMs; timestamp += step)
	{
		timestamps.push(timestamp);
	}
	return timestamps;
}

/**
 * @description Joins the bucket axis to the normalized rows, filling each missing series/bucket pair
 * with zero (the server omits zero-activity rows). Each row's timestamp is floored to the segment
 * step before keying, because the platform can anchor an org's metric grid off the UTC step boundary
 * (live evidence: daily rows starting at 09:00:00Z on a fresh scratch org) — an exact-equality join
 * would silently drop such rows from the chart while the legend totals still counted them. Two rows
 * flooring to the same bucket are summed.
 * @param {Array<number>} bucketTimestamps - The aligned bucket-start timestamps.
 * @param {Array<string>} seriesNames - The ordered series names.
 * @param {Array<{name: string, timestamp: number, value: number}>} normalizedRows - Normalized points.
 * @param {number} stepMilliseconds - The segment's bucket width, used to floor row timestamps to the grid.
 * @returns {Array<{timestamp: number, values: Array<number>}>} Per-bucket values parallel to `seriesNames`.
 */
function padBuckets(bucketTimestamps, seriesNames, normalizedRows, stepMilliseconds)
{
	const valueByKey = new Map();
	normalizedRows.forEach((row) =>
	{
		const flooredTimestamp = Math.floor(row.timestamp / stepMilliseconds) * stepMilliseconds;
		const key = `${row.name}|${flooredTimestamp}`;
		valueByKey.set(key, (valueByKey.get(key) ?? 0) + row.value);
	});
	return bucketTimestamps.map((timestamp) => ({
		timestamp, values: seriesNames.map((name) => valueByKey.get(`${name}|${timestamp}`) ?? 0)
	}));
}

/**
 * @description Collects the values of the visible series across every bucket.
 * @param {Array<{timestamp: number, values: Array<number>}>} paddedBuckets - Per-bucket values.
 * @param {Array<number>} visibleSeriesIndices - Indices of the currently visible series.
 * @returns {Array<number>} The flattened visible values.
 */
function collectVisibleValues(paddedBuckets, visibleSeriesIndices)
{
	return paddedBuckets.flatMap((bucket) => visibleSeriesIndices.map((index) => bucket.values[index]));
}

/**
 * @description Produces the power-of-ten gridline values from 1 up to (and not meaningfully past) the
 * maximum value, for the logarithmic y-axis.
 * @param {number} maxValue - The largest plotted value.
 * @returns {Array<number>} Ascending powers of ten.
 */
function computeLogTicks(maxValue)
{
	const safeMax = Math.max(maxValue, 1);
	const topExponent = Math.ceil(Math.log10(safeMax));
	const ticks = [];
	for(let exponent = 0; exponent <= topExponent; exponent++)
	{
		const tickValue = 10 ** exponent;
		if(tickValue > safeMax * 1.05)
		{
			break;
		}
		ticks.push(tickValue);
	}
	return ticks;
}

/**
 * @description Computes the bar rectangles for the chart on a log y-axis. Zero values resolve to the
 * baseline with height 0, so omitted buckets still render (flat) rather than disappearing.
 * @param {Array<{timestamp: number, values: Array<number>}>} paddedBuckets - Per-bucket values.
 * @param {Array<number>} visibleSeriesIndices - Indices of the currently visible series.
 * @param {number} chartWidth - The chart host width in pixels.
 * @returns {Array<Object>} `{key, x, y, width, height, color, bucketTimestamp}` per bar.
 */
function computeBarGeometry(paddedBuckets, visibleSeriesIndices, chartWidth)
{
	const innerWidth = chartWidth - CHART_MARGIN.left - CHART_MARGIN.right;
	const innerHeight = CHART_HEIGHT - CHART_MARGIN.top - CHART_MARGIN.bottom;
	const baselineY = CHART_HEIGHT - CHART_MARGIN.bottom;
	const maxValue = Math.max(...collectVisibleValues(paddedBuckets, visibleSeriesIndices), 1);
	const logMax = Math.log10(maxValue) || 1;
	const slotWidth = innerWidth / paddedBuckets.length;
	const barWidth = Math.max(1, (slotWidth * BAR_GROUP_WIDTH_RATIO) / visibleSeriesIndices.length);
	const bars = [];
	paddedBuckets.forEach((bucket, bucketIndex) =>
	{
		visibleSeriesIndices.forEach((seriesIndex, position) =>
		{
			const value = bucket.values[seriesIndex];
			const logHeight = (Math.log10(Math.max(value, 1)) / logMax) * innerHeight;
			const height = value > 0 ? Math.max(logHeight, MINIMUM_NON_ZERO_BAR_HEIGHT) : 0;
			const y = baselineY - height;
			const x = CHART_MARGIN.left + bucketIndex * slotWidth + (slotWidth - barWidth * visibleSeriesIndices.length) / 2 + position * barWidth;
			bars.push({
				key: `${bucketIndex}-${seriesIndex}`,
				x: roundCoordinate(x),
				y: roundCoordinate(y),
				width: roundCoordinate(barWidth),
				height: roundCoordinate(height),
				color: SERIES_COLORS[seriesIndex % SERIES_COLORS.length],
				bucketTimestamp: bucket.timestamp
			});
		});
	});
	return bars;
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingUsageMetrics extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/** @description Whether the org has Enhanced Usage Metrics; passed to the filters child. */
	enhancedUsageEnabled = false;

	/** @description Series metadata for the legend chips: `[{index, name, label, color, total}]`. */
	eventTypeDefinitions = [];

	/** @description Per-series visibility flags, parallel to `eventTypeDefinitions`. */
	visibleSeries = [];

	/** @description Active view: `chart` or `table`. */
	view = VIEW_CHART;

	/** @description Whether the last fetch failed (shows the error state, hides the chart). */
	hasError = false;

	/** @description Tooltip render model for the hovered bar. */
	tooltip = {...EMPTY_TOOLTIP};

	/** @description Zero-padded per-bucket values for the current fetch. */
	_paddedBuckets = [];

	/** @description Granularity of the current fetch, driving the compact axis/tooltip/table labels. */
	_segment = TIME_SEGMENT_DAILY;

	/** @description Monotonic search id; a response is applied only if it is still the latest in flight. */
	_searchSequence = 0;

	/** @description Chart host width in pixels, tracked by the ResizeObserver. */
	_chartWidth = DEFAULT_CHART_WIDTH;

	/** @description The most recent search arguments, reused by Retry and Refresh. */
	_lastSearch;

	/** @description The chart-host ResizeObserver, constructed on first chart render. */
	_resizeObserver;

	/** @description Static label strings the template renders as `{labels.x}`. */
	labels = {
		cardTitle: CARD_TITLE,
		countNoData: COUNT_NO_DATA,
		countShowingAll: COUNT_SHOWING_ALL,
		countShowingFiltered: COUNT_SHOWING_FILTERED,
		emptyHeading: EMPTY_HEADING,
		emptyBody: EMPTY_BODY,
		errorBody: ERROR_BODY,
		errorRetry: ERROR_RETRY,
		resetFilters: RESET_FILTERS,
		tablePeriodStart: TABLE_PERIOD_START,
		viewLabel: VIEW_LABEL,
		viewChart: VIEW_CHART_LABEL,
		viewTable: VIEW_TABLE_LABEL
	};

	// ── Lifecycle ────────────────────────────────────────────────────────

	/** @description `viewBox` for the chart SVG, sized to the tracked width. @returns {string} */
	get chartViewBox()
	{
		return `0 0 ${this._chartWidth} ${CHART_HEIGHT}`;
	}

	/** @description Corner radius applied to each bar rectangle. @returns {string} */
	get barCornerRadius()
	{
		return BAR_CORNER_RADIUS;
	}

	/** @description Indices of the currently visible series. @returns {Array<number>} */
	get visibleSeriesIndices()
	{
		return this.visibleSeries.reduce((indices, isVisible, index) =>
		{
			if(isVisible)
			{
				indices.push(index);
			}
			return indices;
		}, []);
	}

	// ── Computed Properties ──────────────────────────────────────────────

	/** @description Total plotted data points (all series × buckets). @returns {number} */
	get totalDataPointCount()
	{
		return this._paddedBuckets.length * this.eventTypeDefinitions.length;
	}

	/** @description Visible plotted data points (visible series × buckets). @returns {number} */
	get visibleDataPointCount()
	{
		return this._paddedBuckets.length * this.visibleSeriesIndices.length;
	}

	/** @description Count-badge text reflecting the all/filtered/no-data state. @returns {string} */
	get countBadge()
	{
		const total = this.totalDataPointCount;
		if(total === 0)
		{
			return this.labels.countNoData;
		}
		const visible = this.visibleDataPointCount;
		if(visible !== total)
		{
			return formatLabel(this.labels.countShowingFiltered, [
				formatCount(visible),
				formatCount(total)
			]);
		}
		return formatLabel(this.labels.countShowingAll, [formatCount(total)]);
	}

	/** @description Whether the chart is shown (data present, no error, chart view). @returns {boolean} */
	get showChart()
	{
		return !this.hasError && this.visibleDataPointCount > 0 && this.view === VIEW_CHART;
	}

	/** @description Whether the table is shown (data present, no error, table view). @returns {boolean} */
	get showTable()
	{
		return !this.hasError && this.visibleDataPointCount > 0 && this.view === VIEW_TABLE;
	}

	/** @description Whether the empty state is shown (no visible data, no error). @returns {boolean} */
	get showEmpty()
	{
		return !this.hasError && this.visibleDataPointCount === 0;
	}

	/** @description `aria-pressed` for the Chart view button. @returns {string} */
	get chartPressed()
	{
		return String(this.view === VIEW_CHART);
	}

	/** @description `aria-pressed` for the Table view button. @returns {string} */
	get tablePressed()
	{
		return String(this.view === VIEW_TABLE);
	}

	/** @description Bar rectangles for the chart. @returns {Array<Object>} */
	get bars()
	{
		return computeBarGeometry(this._paddedBuckets, this.visibleSeriesIndices, this._chartWidth);
	}

	/** @description Horizontal log gridlines with their value labels. @returns {Array<Object>} */
	get gridlines()
	{
		const indices = this.visibleSeriesIndices;
		const maxValue = Math.max(...collectVisibleValues(this._paddedBuckets, indices), 1);
		const logMax = Math.log10(maxValue) || 1;
		const innerHeight = CHART_HEIGHT - CHART_MARGIN.top - CHART_MARGIN.bottom;
		const baselineY = CHART_HEIGHT - CHART_MARGIN.bottom;
		return computeLogTicks(maxValue).map((tickValue) =>
		{
			const y = roundCoordinate(baselineY - (Math.log10(tickValue) / logMax) * innerHeight);
			return {
				key: tickValue,
				y,
				x1: CHART_MARGIN.left,
				x2: this._chartWidth - CHART_MARGIN.right,
				labelX: CHART_MARGIN.left - GRIDLINE_LABEL_INSET,
				labelY: y + GRIDLINE_LABEL_BASELINE,
				label: formatCount(tickValue)
			};
		});
	}

	/** @description The chart baseline line. @returns {{x1: number, x2: number, y: number}} */
	get baseline()
	{
		return {x1: CHART_MARGIN.left, x2: this._chartWidth - CHART_MARGIN.right, y: CHART_HEIGHT - CHART_MARGIN.bottom};
	}

	/** @description Evenly-spaced x-axis tick labels. @returns {Array<Object>} */
	get xTicks()
	{
		const buckets = this._paddedBuckets;
		const innerWidth = this._chartWidth - CHART_MARGIN.left - CHART_MARGIN.right;
		const slotWidth = innerWidth / buckets.length;
		const tickEvery = Math.max(1, Math.ceil(buckets.length / X_TICK_TARGET_COUNT));
		const ticks = [];
		buckets.forEach((bucket, index) =>
		{
			if(index % tickEvery === 0)
			{
				ticks.push({
					key: bucket.timestamp,
					x: roundCoordinate(CHART_MARGIN.left + index * slotWidth + slotWidth / 2),
					y: CHART_HEIGHT - CHART_MARGIN.bottom + X_TICK_BASELINE_OFFSET,
					label: getCompactTimeLabel(bucket.timestamp, this._segment, TIME_ZONE, LOCALE)
				});
			}
		});
		return ticks;
	}

	/** @description Table header cells, one per visible series. @returns {Array<Object>} */
	get tableHeaders()
	{
		return this.visibleSeriesIndices.map((index) => ({key: index, label: this.eventTypeDefinitions[index].label}));
	}

	/** @description Table rows, newest bucket first, with a cell per visible series. @returns {Array<Object>} */
	get tableRows()
	{
		const indices = this.visibleSeriesIndices;
		return [...this._paddedBuckets].reverse().map((bucket) => ({
			key: bucket.timestamp,
			period: getCompactTimeLabel(bucket.timestamp, this._segment, TIME_ZONE, LOCALE),
			cells: indices.map((index) => ({key: index, value: formatCount(bucket.values[index])}))
		}));
	}

	/**
	 * @description Probes the org capability, then loads the Daily 30-day default range. The default
	 * search is recorded synchronously so a Refresh/Retry clicked during the probe round-trip (the card
	 * actions are always rendered) re-issues the valid default rather than a null query. The sequence
	 * check after the probe drops the initial query when the component disconnects (or a newer search
	 * starts) while the probe round-trip is still in flight.
	 */
	async connectedCallback()
	{
		this._lastSearch = this.buildDefaultSearch();
		const sequence = this._searchSequence;
		await this.loadEnhancedFlag();
		if(sequence !== this._searchSequence)
		{
			return;
		}
		await this.runSearch(this._lastSearch);
	}

	/**
	 * @description Wires the ResizeObserver to the chart host once it first renders so the chart
	 * tracks its container width.
	 */
	renderedCallback()
	{
		if(this._resizeObserver || typeof ResizeObserver === 'undefined')
		{
			return;
		}
		const host = this.refs?.chartHost;
		if(!host)
		{
			return;
		}
		this._resizeObserver = new ResizeObserver((entries) =>
		{
			const width = entries?.[0]?.contentRect?.width;
			if(width > 0)
			{
				this._chartWidth = width;
			}
		});
		this._resizeObserver.observe(host);
	}

	/**
	 * @description Disconnects the ResizeObserver when the component is torn down, and bumps the
	 * search sequence so any in-flight fetch resolution is dropped instead of writing state into the
	 * disconnected component.
	 */
	disconnectedCallback()
	{
		this._searchSequence++;
		if(this._resizeObserver)
		{
			this._resizeObserver.disconnect();
			this._resizeObserver = undefined;
		}
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Re-queries the server when the child requests a new segment / preset / custom range.
	 * @param {CustomEvent} event - The `searchfilterchange` event from the filters child.
	 */
	handleSearchFilterChange(event)
	{
		const {timeSegment, startDate, endDate} = event.detail;
		this.runSearch({timeSegment, startDate, endDate});
	}

	/**
	 * @description Applies a client-side series show/hide without re-querying the server.
	 * @param {CustomEvent} event - The `displayfilterchange` event from the filters child.
	 */
	handleDisplayFilterChange(event)
	{
		this.visibleSeries = [...event.detail.visibleTypes];
	}

	/** @description Switches to the chart view. */
	handleViewChart()
	{
		this.view = VIEW_CHART;
	}

	/** @description Switches to the table view. */
	handleViewTable()
	{
		this.view = VIEW_TABLE;
	}

	/** @description Re-issues the last search after a load failure. */
	handleRetry()
	{
		this.runSearch(this._lastSearch);
	}

	/** @description Re-queries the server with the current granularity and range. */
	handleRefresh()
	{
		this.runSearch(this._lastSearch);
	}

	/**
	 * @description Resets the filters child, restores every series to visible, and re-queries the
	 * Daily 30-day default. The explicit visibility restore matters: the child's reset re-shows every
	 * chip, and applyMetrics preserves visibility by name — without clearing the hidden flags here, an
	 * all-hidden state would survive the reset and the chart would stay empty.
	 */
	handleReset()
	{
		this.refs.filters?.reset?.();
		this.visibleSeries = this.visibleSeries.map(() => true);
		this.runSearch(this.buildDefaultSearch());
	}

	/**
	 * @description Builds the hover tooltip for the bar's bucket, listing each visible series, clamped
	 * inside the chart host.
	 * @param {Event} event - The bar `mouseenter` event (`data-bucket` carries the bucket timestamp).
	 */
	handleBarMouseEnter(event)
	{
		const timestamp = Number(event.currentTarget.dataset.bucket);
		const bucket = this._paddedBuckets.find((entry) => entry.timestamp === timestamp);
		if(!bucket)
		{
			return;
		}
		const rows = this.visibleSeriesIndices.map((index) => ({
			key: index,
			label: this.eventTypeDefinitions[index].label,
			value: formatCount(bucket.values[index]),
			dotStyle: `background-color: ${SERIES_COLORS[index % SERIES_COLORS.length]};`
		}));
		const hostRect = this.refs.chartHost.getBoundingClientRect();
		const left = Math.min(event.clientX + TOOLTIP_CURSOR_OFFSET_X, hostRect.left + hostRect.width - TOOLTIP_WIDTH);
		const top = event.clientY - TOOLTIP_CURSOR_OFFSET_Y;
		this.tooltip = {visible: true, style: `left: ${left}px; top: ${top}px;`, time: getCompactTimeLabel(timestamp, this._segment, TIME_ZONE, LOCALE), rows};
	}

	/** @description Hides the hover tooltip. */
	handleBarMouseLeave()
	{
		this.tooltip = {...EMPTY_TOOLTIP};
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Loads the Enhanced Usage Metrics capability, defaulting to disabled on failure.
	 */
	async loadEnhancedFlag()
	{
		try
		{
			this.enhancedUsageEnabled = await isEnhancedUsageMetricEnabled();
		}
		catch(error)
		{
			utilityLogger.error('Failed to probe Enhanced Usage Metrics capability', error);
			this.enhancedUsageEnabled = false;
		}
	}

	/**
	 * @description Runs a metrics query, applying the result or surfacing the error state.
	 * @param {{timeSegment: string, startDate: string, endDate: string}} searchArgs - The query window.
	 */
	async runSearch(searchArgs)
	{
		this._lastSearch = searchArgs;
		const sequence = ++this._searchSequence;
		try
		{
			const rows = await getEventUsageMetrics(searchArgs);
			// Drop a slow response that a newer search has already superseded, so a stale window can
			// never overwrite the freshest one the user asked for.
			if(sequence !== this._searchSequence)
			{
				return;
			}
			this.applyMetrics(rows, searchArgs);
			this.hasError = false;
		}
		catch(error)
		{
			if(sequence !== this._searchSequence)
			{
				return;
			}
			utilityLogger.error('Failed to load event usage metrics', error);
			this.hasError = true;
		}
	}

	/**
	 * @description Normalizes the rows, derives the series and their totals, and zero-pads the axis.
	 * Series visibility is preserved by series name across the rebuild — a Refresh must not silently
	 * snap a hidden series back to visible. Names not seen before default to visible; vanished names
	 * drop their remembered state.
	 * @param {Array<Object>} rows - Raw Apex rows.
	 * @param {{timeSegment: string, startDate: string, endDate: string}} searchArgs - The query window.
	 */
	applyMetrics(rows, searchArgs)
	{
		this._segment = searchArgs.timeSegment;
		const normalized = normalizeMetrics(rows);
		const seriesNames = [...new Set(normalized.map((row) => row.name))].sort();
		const previousVisibilityByName = new Map(this.eventTypeDefinitions.map((definition, index) => [
			definition.name,
			this.visibleSeries[index]
		]));
		this.eventTypeDefinitions = seriesNames.map((name, index) => ({
			index,
			name,
			label: toTitleCase(name),
			color: SERIES_COLORS[index % SERIES_COLORS.length],
			total: normalized.filter((row) => row.name === name).reduce((sum, row) => sum + row.value, 0)
		}));
		this.visibleSeries = seriesNames.map((name) => previousVisibilityByName.get(name) ?? true);
		const axis = generateBucketAxis(searchArgs.timeSegment, Date.parse(searchArgs.startDate), Date.parse(searchArgs.endDate));
		this._paddedBuckets = padBuckets(axis, seriesNames, normalized, STEP_MS_BY_SEGMENT[searchArgs.timeSegment]);
	}

	/**
	 * @description Builds the Daily 30-day default search window ending now.
	 * @returns {{timeSegment: string, startDate: string, endDate: string}} The default window.
	 */
	buildDefaultSearch()
	{
		const now = Date.now();
		return {
			timeSegment: TIME_SEGMENT_DAILY, startDate: new Date(now - DAILY_DEFAULT_WINDOW_MS).toISOString(), endDate: new Date(now).toISOString()
		};
	}
}
