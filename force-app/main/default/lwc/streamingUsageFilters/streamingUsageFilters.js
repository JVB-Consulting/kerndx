// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Filter controls for the Event Usage Metrics view. Owns the granularity segmented
 * control, the date-range preset selector (with a custom From/To range), the colour-coded legend
 * chips, and the enhanced-usage notice. It does not own the chart, table, count badge, or chart/table
 * view switch — those belong to the sibling streamingUsageMetrics component.
 *
 * Two events are dispatched:
 * - `searchfilterchange` — `{timeSegment, startDate, endDate}` (ISO strings). Fired when the
 *   granularity, a preset, or a valid custom range changes; it asks the parent to re-query the server.
 * - `displayfilterchange` — `{visibleTypes}` (boolean[]). Fired when a legend chip is toggled; it is a
 *   client-side show/hide signal only and does not trigger a server re-query.
 *
 * Granularity windows are the live-verified Platform Event Usage Metrics limits — Daily 30 days,
 * Hourly 24 hours, FifteenMinutes 1 hour — and the preset dropdown only offers presets that fit the
 * current granularity's window. The platform also enforces a live-verified lower bound: a custom
 * range must span at least one bucket of the chosen granularity (Daily 1 day, Hourly 1 hour,
 * FifteenMinutes 15 minutes) or the query is rejected outright. The human maxima/minima shown in the
 * too-wide and too-narrow errors are label-sourced so subscribers can translate them, mirroring
 * SEL_PlatformEventUsageMetric.maxRangeHuman / minRangeHuman.
 *
 * @author Jason van Beukering
 * @date March 2026, June 2026
 */
import {LightningElement, api} from 'lwc';
import {formatCount} from 'c/utilityStreaming';

import GRANULARITY_LABEL from '@salesforce/label/c.EventUsageMetrics_Granularity_Label';
import GRANULARITY_DAILY from '@salesforce/label/c.EventUsageMetrics_Granularity_Daily';
import GRANULARITY_HOURLY from '@salesforce/label/c.EventUsageMetrics_Granularity_Hourly';
import GRANULARITY_FIFTEEN_MINUTES from '@salesforce/label/c.EventUsageMetrics_Granularity_FifteenMinutes';
import DATE_RANGE_LABEL from '@salesforce/label/c.EventUsageMetrics_DateRange_Label';
import DATE_RANGE_FROM from '@salesforce/label/c.EventUsageMetrics_DateRange_From';
import DATE_RANGE_TO from '@salesforce/label/c.EventUsageMetrics_DateRange_To';
import DATE_RANGE_CUSTOM from '@salesforce/label/c.EventUsageMetrics_DateRange_Custom';
import DATE_RANGE_LAST_HOUR from '@salesforce/label/c.EventUsageMetrics_DateRange_LastHour';
import DATE_RANGE_LAST_24_HOURS from '@salesforce/label/c.EventUsageMetrics_DateRange_Last24Hours';
import DATE_RANGE_LAST_7_DAYS from '@salesforce/label/c.EventUsageMetrics_DateRange_Last7Days';
import DATE_RANGE_LAST_30_DAYS from '@salesforce/label/c.EventUsageMetrics_DateRange_Last30Days';
import ENHANCED_NOTICE_BODY from '@salesforce/label/c.EventUsageMetrics_EnhancedNotice_Body';
import ENHANCED_NOTICE_LINK_LABEL from '@salesforce/label/c.EventUsageMetrics_EnhancedNotice_LinkLabel';
import VALIDATION_FROM_BEFORE_TO from '@salesforce/label/c.EventUsageMetrics_Validation_FromBeforeTo';
import VALIDATION_RANGE_TOO_NARROW from '@salesforce/label/c.EventUsageMetrics_Validation_RangeTooNarrow';
import VALIDATION_RANGE_TOO_WIDE from '@salesforce/label/c.EventUsageMetrics_Validation_RangeTooWide';
import WINDOW_DAILY from '@salesforce/label/c.EventUsageMetrics_Window_Daily';
import WINDOW_HOURLY from '@salesforce/label/c.EventUsageMetrics_Window_Hourly';
import WINDOW_FIFTEEN_MINUTES from '@salesforce/label/c.EventUsageMetrics_Window_FifteenMinutes';
import MINIMUM_DAILY from '@salesforce/label/c.EventUsageMetrics_Minimum_Daily';
import MINIMUM_HOURLY from '@salesforce/label/c.EventUsageMetrics_Minimum_Hourly';
import MINIMUM_FIFTEEN_MINUTES from '@salesforce/label/c.EventUsageMetrics_Minimum_FifteenMinutes';

// ── Constants ────────────────────────────────────────────────────────────

const MILLISECONDS_PER_HOUR = 60 * 60 * 1000;
const MILLISECONDS_PER_DAY = 24 * MILLISECONDS_PER_HOUR;

const TIME_SEGMENT_DAILY = 'Daily';
const TIME_SEGMENT_HOURLY = 'Hourly';
const TIME_SEGMENT_FIFTEEN_MINUTES = 'FifteenMinutes';

const PRESET_LAST_HOUR = 'PT1H';
const PRESET_LAST_24_HOURS = 'P1D';
const PRESET_LAST_7_DAYS = 'P7D';
const PRESET_LAST_30_DAYS = 'P30D';
const PRESET_CUSTOM = 'CUSTOM';

const PRESET_ORDER = [
	PRESET_LAST_HOUR,
	PRESET_LAST_24_HOURS,
	PRESET_LAST_7_DAYS,
	PRESET_LAST_30_DAYS
];

const PRESET_RANGES_MS = {
	[PRESET_LAST_HOUR]: MILLISECONDS_PER_HOUR,
	[PRESET_LAST_24_HOURS]: MILLISECONDS_PER_DAY,
	[PRESET_LAST_7_DAYS]: 7 * MILLISECONDS_PER_DAY,
	[PRESET_LAST_30_DAYS]: 30 * MILLISECONDS_PER_DAY
};

const DEFAULT_PRESET_BY_SEGMENT = {
	[TIME_SEGMENT_DAILY]: PRESET_LAST_30_DAYS, [TIME_SEGMENT_HOURLY]: PRESET_LAST_24_HOURS, [TIME_SEGMENT_FIFTEEN_MINUTES]: PRESET_LAST_HOUR
};

// Live-verified platform query windows (NOT the abandoned 60d/7d/48h placeholders):
// Daily 30 days, Hourly 24 hours, FifteenMinutes 1 hour.
// Must match SEL_PlatformEventUsageMetric.MAX_RANGE_MINUTES_BY_SEGMENT.
const MAX_RANGE_MS_BY_SEGMENT = {
	[TIME_SEGMENT_DAILY]: 30 * MILLISECONDS_PER_DAY, [TIME_SEGMENT_HOURLY]: MILLISECONDS_PER_DAY, [TIME_SEGMENT_FIFTEEN_MINUTES]: MILLISECONDS_PER_HOUR
};

// Label-sourced human maxima for the too-wide message — mirrors the Apex layer so the values stay
// translatable rather than hardcoded "30 days" strings.
const MAX_RANGE_HUMAN_BY_SEGMENT = {
	[TIME_SEGMENT_DAILY]: WINDOW_DAILY, [TIME_SEGMENT_HOURLY]: WINDOW_HOURLY, [TIME_SEGMENT_FIFTEEN_MINUTES]: WINDOW_FIFTEEN_MINUTES
};

// Live-verified platform lower bound: the query interval must span at least ONE bucket of the chosen
// granularity, or the platform rejects the query outright (TimeSegmentValueTooLargeException) instead
// of returning empty. Inclusive — a span exactly one bucket wide is accepted.
// Must match SEL_PlatformEventUsageMetric.MIN_RANGE_MINUTES_BY_SEGMENT.
const MIN_RANGE_MS_BY_SEGMENT = {
	[TIME_SEGMENT_DAILY]: MILLISECONDS_PER_DAY, [TIME_SEGMENT_HOURLY]: MILLISECONDS_PER_HOUR, [TIME_SEGMENT_FIFTEEN_MINUTES]: MILLISECONDS_PER_HOUR / 4
};

// Label-sourced human minima for the too-narrow message — same translatability rationale as the maxima.
const MIN_RANGE_HUMAN_BY_SEGMENT = {
	[TIME_SEGMENT_DAILY]: MINIMUM_DAILY, [TIME_SEGMENT_HOURLY]: MINIMUM_HOURLY, [TIME_SEGMENT_FIFTEEN_MINUTES]: MINIMUM_FIFTEEN_MINUTES
};

const PRESET_LABELS = {
	[PRESET_LAST_HOUR]: DATE_RANGE_LAST_HOUR,
	[PRESET_LAST_24_HOURS]: DATE_RANGE_LAST_24_HOURS,
	[PRESET_LAST_7_DAYS]: DATE_RANGE_LAST_7_DAYS,
	[PRESET_LAST_30_DAYS]: DATE_RANGE_LAST_30_DAYS
};

const RANGE_MAX_PLACEHOLDER = '{0}';

const ENHANCED_USAGE_DOCS_URL = 'https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_monitor_enhanced_usage.htm';

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Substitutes the single `{0}` placeholder in a label template.
 * @param {string} template - The label text containing `{0}`.
 * @param {string} value - The replacement value.
 * @returns {string} The interpolated string.
 */
function formatLabel(template, value)
{
	return template.replace(RANGE_MAX_PLACEHOLDER, value);
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingUsageFilters extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/**
	 * @description The currently selected granularity (`Daily` | `Hourly` | `FifteenMinutes`).
	 * @type {string}
	 */
	segment = TIME_SEGMENT_DAILY;

	/**
	 * @description The currently selected preset key, or `CUSTOM` when a manual range is active.
	 * @type {string}
	 */
	preset = DEFAULT_PRESET_BY_SEGMENT[TIME_SEGMENT_DAILY];

	/**
	 * @description ISO start value bound to the custom-range From input. Undefined unless `CUSTOM`.
	 * @type {string|undefined}
	 */
	customFrom;

	/**
	 * @description ISO end value bound to the custom-range To input. Undefined unless `CUSTOM`.
	 * @type {string|undefined}
	 */
	customTo;

	/**
	 * @description Inline validation message for the custom range; empty when the range is valid.
	 * @type {string}
	 */
	rangeError = '';
	/**
	 * @description Per-event-type visibility flags driving the legend chips' pressed state and the
	 * `displayfilterchange` payload. Parallel to `_eventTypes`.
	 * @type {boolean[]}
	 */
	visible = [];
	/**
	 * @description Static label strings the template renders, grouped so the markup reads `{labels.x}`.
	 * @type {Object<string, string>}
	 */
	labels = {
		granularityLabel: GRANULARITY_LABEL,
		granularityDaily: GRANULARITY_DAILY,
		granularityHourly: GRANULARITY_HOURLY,
		granularityFifteenMinutes: GRANULARITY_FIFTEEN_MINUTES,
		dateRangeLabel: DATE_RANGE_LABEL,
		dateRangeFrom: DATE_RANGE_FROM,
		dateRangeTo: DATE_RANGE_TO,
		dateRangeCustom: DATE_RANGE_CUSTOM,
		enhancedNoticeBody: ENHANCED_NOTICE_BODY,
		enhancedNoticeLinkLabel: ENHANCED_NOTICE_LINK_LABEL
	};
	/**
	 * @description Whether the org has Enhanced Usage Metrics. When false, Hourly/15-minute granularity
	 * are disabled and the enhanced-usage notice is shown.
	 * @type {boolean}
	 */
	@api isEnhancedUsageMetricEnabled = false;

	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Backing store for the `eventTypes` API property.
	 * @type {Array<Object>}
	 */
	_eventTypes = [];

	/**
	 * @description Event-type metadata used to render the legend chips.
	 * @returns {Array<Object>} `[{index, name, label, color, total}]`.
	 */
	// noinspection JSUnusedGlobalSymbols
	get eventTypes()
	{
		return this._eventTypes;
	}

	/**
	 * @description Receives event-type metadata from the parent, preserving each chip's visibility by
	 * series name across the reassignment — a refetch must not silently snap a hidden series back to
	 * visible. Names not seen before default to visible; vanished names drop their remembered state.
	 * @param {Array<Object>} value - `[{index, name, label, color, total}]`.
	 */
	@api set eventTypes(value)
	{
		const previousVisibilityByName = new Map(this._eventTypes.map((eventType, index) => [
			eventType.name,
			this.visible[index]
		]));
		this._eventTypes = value || [];
		this.visible = this._eventTypes.map((eventType) => previousVisibilityByName.get(eventType.name) ?? true);
	}

	/**
	 * @description `aria-pressed` value for the Daily granularity button.
	 * @returns {string}
	 */
	get dailyPressed()
	{
		return String(this.segment === TIME_SEGMENT_DAILY);
	}

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description `aria-pressed` value for the Hourly granularity button.
	 * @returns {string}
	 */
	get hourlyPressed()
	{
		return String(this.segment === TIME_SEGMENT_HOURLY);
	}

	/**
	 * @description `aria-pressed` value for the 15-minute granularity button.
	 * @returns {string}
	 */
	get fifteenPressed()
	{
		return String(this.segment === TIME_SEGMENT_FIFTEEN_MINUTES);
	}

	/**
	 * @description Whether the Hourly/15-minute granularity buttons are disabled (no enhanced metrics).
	 * @returns {boolean}
	 */
	get enhancedDisabled()
	{
		return !this.isEnhancedUsageMetricEnabled;
	}

	/**
	 * @description Whether the enhanced-usage notice is shown (no enhanced metrics).
	 * @returns {boolean}
	 */
	get showEnhancedNotice()
	{
		return !this.isEnhancedUsageMetricEnabled;
	}

	/**
	 * @description Whether the custom From/To inputs are shown.
	 * @returns {boolean}
	 */
	get showCustomRange()
	{
		return this.preset === PRESET_CUSTOM;
	}

	/**
	 * @description Whether an inline range-validation error is present.
	 * @returns {boolean}
	 */
	get hasRangeError()
	{
		return Boolean(this.rangeError);
	}

	/**
	 * @description External documentation link for the Enhanced Usage Metrics feature.
	 * @returns {string}
	 */
	get enhancedDocsUrl()
	{
		return ENHANCED_USAGE_DOCS_URL;
	}

	/**
	 * @description Preset options for the combobox, gated so only presets the platform accepts for
	 * the current granularity are offered — at most the granularity's window, at least one bucket —
	 * with the custom option always appended.
	 * @returns {Array<{label: string, value: string}>}
	 */
	get presetOptions()
	{
		const maximumRangeMs = MAX_RANGE_MS_BY_SEGMENT[this.segment];
		const minimumRangeMs = MIN_RANGE_MS_BY_SEGMENT[this.segment];
		const options = PRESET_ORDER
		.filter((key) => PRESET_RANGES_MS[key] <= maximumRangeMs && PRESET_RANGES_MS[key] >= minimumRangeMs)
		.map((key) => ({label: PRESET_LABELS[key], value: key}));
		options.push({label: this.labels.dateRangeCustom, value: PRESET_CUSTOM});
		return options;
	}

	/**
	 * @description Render model for the legend chips, derived from the event types and visibility flags.
	 * @returns {Array<Object>}
	 */
	get chips()
	{
		return this._eventTypes.map((eventType, index) => ({
			index, label: eventType.label, total: formatCount(eventType.total), style: `background-color: ${eventType.color};`, ariaPressed: String(this.visible[index])
		}));
	}

	/**
	 * @description Resets the controls to the Daily default for the parent's empty-state "Reset
	 * filters" action: restores Daily granularity and its default preset, clears any custom range and
	 * inline error, and makes every legend chip visible. Does not dispatch — the parent re-queries the
	 * default range itself, so emitting here would double the fetch.
	 */
	@api reset()
	{
		this.segment = TIME_SEGMENT_DAILY;
		this.preset = DEFAULT_PRESET_BY_SEGMENT[TIME_SEGMENT_DAILY];
		this.customFrom = undefined;
		this.customTo = undefined;
		this.rangeError = '';
		this.visible = this._eventTypes.map(() => true);
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Switches granularity: snaps the preset to the segment default, discards any custom
	 * range, and emits a search for the new preset range.
	 * @param {Event} event - Click event from a granularity button (`data-segment` carries the value).
	 */
	handleSegmentClick(event)
	{
		this.applySegment(event.currentTarget.dataset.segment);
	}

	/**
	 * @description Applies a preset selection. For `CUSTOM`, reveals and seeds the From/To inputs
	 * without emitting; otherwise computes the range and emits a search.
	 * @param {CustomEvent} event - Change event from the preset combobox.
	 */
	handlePresetChange(event)
	{
		this.preset = event.detail.value;
		this.rangeError = '';
		if(this.preset === PRESET_CUSTOM)
		{
			this.seedCustomRange();
		}
		else
		{
			this.customFrom = undefined;
			this.customTo = undefined;
			this.emitSearchForPreset();
		}
	}

	/**
	 * @description Updates the custom From value and revalidates the range.
	 * @param {CustomEvent} event - Change event from the From input.
	 */
	handleCustomFromChange(event)
	{
		this.customFrom = event.detail.value;
		this.validateAndEmitCustom();
	}

	/**
	 * @description Updates the custom To value and revalidates the range.
	 * @param {CustomEvent} event - Change event from the To input.
	 */
	handleCustomToChange(event)
	{
		this.customTo = event.detail.value;
		this.validateAndEmitCustom();
	}

	/**
	 * @description Toggles a legend chip's visibility and emits the client-side display filter.
	 * @param {Event} event - Click event from a legend chip (`data-index` carries the position).
	 */
	handleChipToggle(event)
	{
		const index = Number(event.currentTarget.dataset.index);
		this.visible = this.visible.map((isVisible, position) => (position === index ? !isVisible : isVisible));
		this.dispatchEvent(new CustomEvent('displayfilterchange', {detail: {visibleTypes: [...this.visible]}}));
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Sets the active granularity, snaps the preset to its default, clears any custom
	 * range and error, then emits a search for the snapped preset range.
	 * @param {string} segment - The granularity to apply.
	 */
	applySegment(segment)
	{
		this.segment = segment;
		this.preset = DEFAULT_PRESET_BY_SEGMENT[segment];
		this.customFrom = undefined;
		this.customTo = undefined;
		this.rangeError = '';
		this.emitSearchForPreset();
	}

	/**
	 * @description Seeds the custom From/To inputs with the current segment's default-preset range so
	 * the initial custom values are always within the granularity window. Does not emit.
	 */
	seedCustomRange()
	{
		const now = Date.now();
		const defaultSpanMs = PRESET_RANGES_MS[DEFAULT_PRESET_BY_SEGMENT[this.segment]];
		this.customFrom = new Date(now - defaultSpanMs).toISOString();
		this.customTo = new Date(now).toISOString();
	}

	/**
	 * @description Validates the custom range (From before To, span within the granularity window) and
	 * either emits a search or renders the corresponding inline error.
	 */
	validateAndEmitCustom()
	{
		const fromMs = new Date(this.customFrom).getTime();
		const toMs = new Date(this.customTo).getTime();

		// `!(fromMs < toMs)` is deliberate, not `fromMs >= toMs`: it also rejects an unparseable input
		// (NaN), where every comparison is false. Do not "simplify" it to `>=` — that reintroduces a hole
		// where a NaN endpoint would slip past validation and emit a garbage range.
		if(!(fromMs < toMs))
		{
			this.rangeError = VALIDATION_FROM_BEFORE_TO;
			return;
		}

		if(toMs - fromMs > MAX_RANGE_MS_BY_SEGMENT[this.segment])
		{
			this.rangeError = formatLabel(VALIDATION_RANGE_TOO_WIDE, MAX_RANGE_HUMAN_BY_SEGMENT[this.segment]);
			return;
		}

		if(toMs - fromMs < MIN_RANGE_MS_BY_SEGMENT[this.segment])
		{
			this.rangeError = formatLabel(VALIDATION_RANGE_TOO_NARROW, MIN_RANGE_HUMAN_BY_SEGMENT[this.segment]);
			return;
		}

		this.rangeError = '';
		this.emitSearch(new Date(fromMs).toISOString(), new Date(toMs).toISOString());
	}

	/**
	 * @description Computes the current preset's range relative to now and emits a search.
	 */
	emitSearchForPreset()
	{
		const now = Date.now();
		const startDate = new Date(now - PRESET_RANGES_MS[this.preset]).toISOString();
		const endDate = new Date(now).toISOString();
		this.emitSearch(startDate, endDate);
	}

	/**
	 * @description Dispatches the `searchfilterchange` event asking the parent to re-query the server.
	 * @param {string} startDate - ISO start of the range.
	 * @param {string} endDate - ISO end of the range.
	 */
	emitSearch(startDate, endDate)
	{
		this.dispatchEvent(new CustomEvent('searchfilterchange', {detail: {timeSegment: this.segment, startDate, endDate}}));
	}
}