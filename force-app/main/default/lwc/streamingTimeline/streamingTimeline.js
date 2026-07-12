// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description LWC component that renders an interactive event timeline as native template SVG —
 * no D3, no static-resource load, no `lwc:dom="manual"`. Events are plotted based on:
 * - Timestamp (X-axis, continuous timescale with a 10% domain margin)
 * - Channel (Y-axis, band layout)
 *
 * The component exposes four public API properties:
 *  - `events`       — Array of event objects to plot. Each event must contain:
 *        - timestamp  (epoch ms)
 *        - channel    (string)
 *        - timeLabel  (formatted label for tooltip)
 *  - `channels`     — Array of channel names used to build the Y-axis categories.
 *  - `userTimezone` — IANA timezone applied to axis ticks and the crosshair time label.
 *  - `userLocale`   — Salesforce locale (e.g. `en_US`) controlling the 12/24-hour clock.
 *
 * Rendering is a pure getter pipeline: geometry getters derive render-model arrays that the
 * template iterates into SVG, so any `@api` change re-renders declaratively. A ResizeObserver
 * tracks the host width into the `viewBox`. The component displays a crosshair time tooltip, a
 * per-dot detail tooltip, and emits a `select` event with the raw datum when a dot is clicked.
 *
 * @date March 2026, May 2026, July 2026
 */
import {LightningElement, api} from 'lwc';
import {computeBandLayout, getTimeLabel, roundCoordinate} from 'c/utilityStreaming';
import CHART_LABEL from '@salesforce/label/c.EventTimeline_ChartLabel';
import CLICK_FOR_DETAILS from '@salesforce/label/c.EventTimeline_Tooltip_ClickForDetails';

// ── Constants ────────────────────────────────────────────────────────────

const CHART_HEIGHT = 400;
const DEFAULT_CHART_WIDTH = 1000;
const MARGINS = {top: 0, right: 0, bottom: 20, left: 200};
const SCALE_PADDING = 1;
const CIRCLE_RADIUS = 10;
const COLOR_PALETTE_SIZE = 10;
const TOOLTIP_Y_OFFSET = 30;
const TIME_MARGIN_RATIO = 0.1;
const DISPLAY_LOCALE = 'en-US';
const X_TICK_TARGET_COUNT = 10;
const X_TICK_BASELINE_OFFSET = 16;
const Y_AXIS_LABEL_INSET = 8;
const TEXT_BASELINE_NUDGE = 4;
const TWELVE_HOUR_PROBE_DATE = new Date(2025, 0, 1, 13, 0, 0);
const EMPTY_TOOLTIP = Object.freeze({visible: false, style: '', className: 'tooltip', lines: []});

// Nice-step ladder for time-axis ticks (ms). Spans outside the ladder fall back to whole days.
const TIME_STEP_LADDER_MS = [
	1000,
	5000,
	15000,
	30000,
	60000,
	300000,
	900000,
	1800000,
	3600000,
	10800000,
	21600000,
	43200000,
	86400000,
	172800000,
	604800000,
	1209600000,
	2592000000
];
const MILLISECONDS_PER_DAY = 86400000;

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Formats a date for an axis tick label, detecting day boundaries
 * and switching between date and time display accordingly.
 *
 * @param {Date} date - The tick date to format.
 * @param {string|null} previousDateString - The formatted date string of the previous tick.
 * @param {string|undefined} timezone - The user's IANA timezone identifier.
 * @param {string} displayLocale - The locale for formatting display text.
 * @param {boolean} usesTwelveHour - Whether to use 12-hour time format.
 * @returns {{label: string, dateString: string}} The formatted label and date string for state tracking.
 */
function formatAxisTick(date, previousDateString, timezone, displayLocale, usesTwelveHour)
{
	const dateOptions = {day: 'numeric', month: 'numeric', year: 'numeric'};
	if(timezone)
	{
		dateOptions.timeZone = timezone;
	}
	const currentDateString = date.toLocaleString(displayLocale, dateOptions);
	const isNewDay = previousDateString !== null && previousDateString !== currentDateString;

	if(isNewDay)
	{
		const dayOptions = {month: 'short', day: 'numeric'};
		if(timezone)
		{
			dayOptions.timeZone = timezone;
		}
		return {label: date.toLocaleString(displayLocale, dayOptions), dateString: currentDateString};
	}

	const timeOptions = {hour: 'numeric', minute: '2-digit', hour12: usesTwelveHour};
	if(timezone)
	{
		timeOptions.timeZone = timezone;
	}
	return {label: date.toLocaleString(displayLocale, timeOptions), dateString: currentDateString};
}

/**
 * @description Determines whether the given date falls on a midnight boundary in the specified timezone.
 *
 * @param {Date} date - The date to check.
 * @param {string|undefined} timezone - The user's IANA timezone identifier.
 * @returns {boolean} True if the date is midnight (00:00) in the given timezone.
 */
function isMidnightBoundary(date, timezone)
{
	if(!timezone)
	{
		return date.getHours() === 0 && date.getMinutes() === 0;
	}
	const hourOptions = {hour: 'numeric', hour12: false, timeZone: timezone};
	const minuteOptions = {minute: 'numeric', timeZone: timezone};
	const hour = parseInt(date.toLocaleString('en-US', hourOptions), 10);
	const minute = parseInt(date.toLocaleString('en-US', minuteOptions), 10);
	return hour === 0 && minute === 0;
}

/**
 * @description Picks the smallest ladder step yielding at most targetCount ticks over the span.
 *
 * @param {number} spanMs - Domain span in milliseconds.
 * @param {number} targetCount - Desired maximum tick count.
 * @returns {number} The chosen step in milliseconds.
 */
function chooseTimeStep(spanMs, targetCount)
{
	const step = TIME_STEP_LADDER_MS.find((candidate) => spanMs / candidate <= targetCount);
	return step ?? Math.ceil(spanMs / targetCount / MILLISECONDS_PER_DAY) * MILLISECONDS_PER_DAY;
}

/**
 * @description Generates step-aligned tick timestamps across the domain (replaces d3.scaleTime ticks).
 *
 * @param {number} domainStart - Inclusive start (epoch ms).
 * @param {number} domainEnd - Inclusive end (epoch ms).
 * @param {number} targetCount - Desired maximum tick count.
 * @returns {Array<number>} Ascending tick timestamps; single start tick for a zero-width domain.
 */
function generateTimeTicks(domainStart, domainEnd, targetCount)
{
	if(domainEnd <= domainStart)
	{
		return [domainStart];
	}
	const step = chooseTimeStep(domainEnd - domainStart, targetCount);
	const ticks = [];
	for(let tick = Math.ceil(domainStart / step) * step; tick <= domainEnd; tick += step)
	{
		ticks.push(tick);
	}
	return ticks;
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingTimeline extends LightningElement
{
	// ── @api Properties ──────────────────────────────────────────────────

	/** @description List of event objects plotted on the timeline. */
	@api events = [];

	/** @description List of channel names for the Y-axis categories. */
	@api channels = [];

	/** @description User timezone for time label formatting. */
	@api userTimezone;

	/** @description User locale controlling the 12/24-hour clock. */
	@api userLocale;

	// ── Internal State ───────────────────────────────────────────────────

	/** @description Tooltip render model (crosshair or dot-detail variant). */
	tooltip = {...EMPTY_TOOLTIP};

	/** @description Whether the tooltip is showing data point details (suppresses the crosshair). */
	_isShowingDataTooltip = false;

	/** @description Chart host width in pixels, tracked by the ResizeObserver. */
	_chartWidth = DEFAULT_CHART_WIDTH;

	/** @description The chart-host ResizeObserver, constructed on first render. */
	_resizeObserver;

	/** @description Static label strings the template renders as `{labels.x}`. */
	labels = {
		chartLabel: CHART_LABEL, clickForDetails: CLICK_FOR_DETAILS
	};

	// ── Lifecycle ────────────────────────────────────────────────────────

	/** @description Whether the chart is shown (at least one event present). @returns {boolean} */
	get showChart()
	{
		return Boolean(this.events?.length);
	}

	/** @description `viewBox` for the chart SVG, sized to the tracked width. @returns {string} */
	get chartViewBox()
	{
		return `0 0 ${this._chartWidth} ${CHART_HEIGHT}`;
	}

	// ── Computed Properties ──────────────────────────────────────────────

	/** @description The x-axis baseline line. @returns {{x1: number, x2: number, y: number}} */
	get baseline()
	{
		return {x1: MARGINS.left, x2: this._chartWidth - MARGINS.right, y: CHART_HEIGHT - MARGINS.bottom};
	}

	/**
	 * @description Time domain spanning first to last event, padded by a 10% span margin on each
	 * side. A single-event (zero-span) domain carries no margin; its dot renders at the midpoint.
	 * @returns {{start: number, end: number}}
	 */
	get timeDomain()
	{
		const first = this.events[0].timestamp;
		const last = this.events[this.events.length - 1].timestamp;
		const margin = (last - first) * TIME_MARGIN_RATIO;
		return {start: first - margin, end: last + margin};
	}

	/** @description The channel list normalized to an array. @returns {Array<string>} */
	get channelList()
	{
		return this.channels ?? [];
	}

	/** @description Band layout for the channel lanes. @returns {{step: number, bandwidth: number, positions: Array<number>}} */
	get channelLayout()
	{
		return computeBandLayout(this.channelList.length, MARGINS.top, CHART_HEIGHT - MARGINS.bottom, SCALE_PADDING, SCALE_PADDING);
	}

	/** @description Whether the user's locale prefers a 12-hour clock. @returns {boolean} */
	get usesTwelveHour()
	{
		const probeLocale = this.userLocale ? this.userLocale.replace('_', '-') : DISPLAY_LOCALE;
		const probeFormat = TWELVE_HOUR_PROBE_DATE.toLocaleString(probeLocale, {hour: 'numeric'});
		return probeFormat.includes('PM') || probeFormat.includes('AM');
	}

	/** @description Circle render models, one per event. @returns {Array<Object>} */
	get circles()
	{
		const layout = this.channelLayout;
		return this.events.map((datum, index) =>
		{
			const bandIndex = this.channelList.indexOf(datum.channel);
			return {
				key: datum.id ?? index,
				index,
				cx: roundCoordinate(this.xPosition(datum.timestamp)),
				cy: bandIndex === -1 ? 0 : roundCoordinate(layout.positions[bandIndex]),
				r: CIRCLE_RADIUS,
				className: this.getChannelColorClass(datum.channel)
			};
		});
	}

	/** @description X-axis tick render models with day-boundary and midnight handling. @returns {Array<Object>} */
	get xTicks()
	{
		const usesTwelveHour = this.usesTwelveHour;
		const domain = this.timeDomain;
		let previousDateString = null;
		return generateTimeTicks(domain.start, domain.end, X_TICK_TARGET_COUNT).map((timestamp) =>
		{
			const tickDate = new Date(timestamp);
			const formatted = formatAxisTick(tickDate, previousDateString, this.userTimezone, DISPLAY_LOCALE, usesTwelveHour);
			previousDateString = formatted.dateString;
			return {
				key: timestamp,
				x: roundCoordinate(this.xPosition(timestamp)),
				y: CHART_HEIGHT - MARGINS.bottom + X_TICK_BASELINE_OFFSET,
				label: formatted.label,
				className: isMidnightBoundary(tickDate, this.userTimezone) ? 'axis-label major-tick' : 'axis-label'
			};
		});
	}

	/** @description Y-axis channel label render models. @returns {Array<Object>} */
	get yChannels()
	{
		const layout = this.channelLayout;
		return this.channelList.map((channel, index) => ({
			key: channel, label: channel, y: roundCoordinate(layout.positions[index] + TEXT_BASELINE_NUDGE), labelX: MARGINS.left - Y_AXIS_LABEL_INSET
		}));
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
		this._resizeObserver = new ResizeObserver((entries) =>
		{
			const width = entries?.[0]?.contentRect?.width;
			if(width > 0)
			{
				this._chartWidth = width;
			}
		});
		this._resizeObserver.observe(this.refs.chartHost);
	}

	/**
	 * @description Disconnects the ResizeObserver when the component is torn down.
	 */
	disconnectedCallback()
	{
		if(this._resizeObserver)
		{
			this._resizeObserver.disconnect();
			this._resizeObserver = undefined;
		}
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Shows the crosshair time tooltip while the pointer moves inside the chart area,
	 * unless a dot tooltip is showing. Client coordinates map 1:1 onto SVG coordinates because the
	 * viewBox width tracks the host width.
	 * @param {MouseEvent} event - The SVG mousemove event.
	 */
	handleChartMouseMove(event)
	{
		if(this._isShowingDataTooltip)
		{
			return;
		}
		const hostRect = this.refs.chartHost.getBoundingClientRect();
		const chartX = event.clientX - hostRect.left;
		const chartY = event.clientY - hostRect.top;
		if(chartX <= MARGINS.left || chartY >= CHART_HEIGHT - MARGINS.bottom)
		{
			this.hideTooltip();
			return;
		}
		const domain = this.timeDomain;
		const innerWidth = this._chartWidth - MARGINS.left - MARGINS.right;
		const time = domain.start + ((chartX - MARGINS.left) / innerWidth) * (domain.end - domain.start);
		this.showTooltip(event, 'tooltip', [getTimeLabel(time, this.userTimezone, this.userLocale)]);
	}

	/**
	 * @description Hides the tooltip when the pointer leaves the chart host.
	 */
	handleChartMouseLeave()
	{
		this.hideTooltip();
	}

	/**
	 * @description Shows the dot-detail tooltip and suppresses the crosshair.
	 * @param {MouseEvent} event - The circle mouseenter event (`data-index` identifies the datum).
	 */
	handleDotMouseEnter(event)
	{
		this._isShowingDataTooltip = true;
		const datum = this.events[Number(event.currentTarget.dataset.index)];
		// 'tooltip data' is the tooltip element's CSS className, not display text
		// (scanner false positive on the two-word value).
		// eslint-disable-next-line kerndx/no-hardcoded-user-text
		this.showTooltip(event, 'tooltip data', [
			datum.timeLabel,
			datum.channel,
			'',
			this.labels.clickForDetails
		]);
	}

	/**
	 * @description Releases the crosshair suppression and hides the tooltip when the pointer
	 * leaves a dot.
	 */
	handleDotMouseLeave()
	{
		this._isShowingDataTooltip = false;
		this.hideTooltip();
	}

	/**
	 * @description Emits the `select` event with the clicked dot's raw event datum.
	 * @param {MouseEvent} event - The circle click event (`data-index` identifies the datum).
	 */
	handleDotClick(event)
	{
		this._isShowingDataTooltip = false;
		this.hideTooltip();
		this.dispatchEvent(new CustomEvent('select', {
			detail: this.events[Number(event.currentTarget.dataset.index)]
		}));
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Maps a timestamp to its x pixel position inside the chart area. A zero-span
	 * domain resolves to the midpoint.
	 * @param {number} timestamp - The event timestamp in epoch ms.
	 * @returns {number} The x coordinate in SVG pixels.
	 */
	xPosition(timestamp)
	{
		const domain = this.timeDomain;
		const innerWidth = this._chartWidth - MARGINS.left - MARGINS.right;
		if(domain.end === domain.start)
		{
			return MARGINS.left + innerWidth / 2;
		}
		return MARGINS.left + ((timestamp - domain.start) / (domain.end - domain.start)) * innerWidth;
	}

	/**
	 * @description Returns a consistent CSS class for a given channel using hash-based assignment.
	 *
	 * @param {string} channel - The channel name to hash.
	 * @returns {string} A CSS class name in the format `channel-color-N` where N is 0-9.
	 */
	getChannelColorClass(channel)
	{
		let hash = 0;
		for(let i = 0; i < channel.length; i++)
		{
			hash = ((hash << 5) - hash) + channel.charCodeAt(i);
			hash &= hash;
		}
		const colorIndex = Math.abs(hash) % COLOR_PALETTE_SIZE;
		return `channel-color-${colorIndex}`;
	}

	/**
	 * @description Builds and positions the tooltip render model at the cursor, horizontally
	 * clamped inside the chart host (the CSS transform centres it above the cursor).
	 * @param {MouseEvent} event - The originating mouse event.
	 * @param {string} className - `tooltip` (crosshair) or `tooltip data` (dot detail).
	 * @param {Array<string>} lines - The tooltip content lines.
	 */
	showTooltip(event, className, lines)
	{
		const hostRect = this.refs.chartHost.getBoundingClientRect();
		const left = Math.min(Math.max(event.clientX, hostRect.left), hostRect.left + hostRect.width);
		const top = event.clientY - TOOLTIP_Y_OFFSET;
		this.tooltip = {
			visible: true, className, style: `left: ${left}px; top: ${top}px;`, lines: lines.map((text, index) => ({key: index, text}))
		};
	}

	/**
	 * @description Hides the tooltip.
	 */
	hideTooltip()
	{
		this.tooltip = {...EMPTY_TOOLTIP};
	}
}