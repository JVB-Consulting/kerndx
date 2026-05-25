// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/* global d3 */
// noinspection JSUnresolvedFunction,FunctionWithMultipleReturnPointsJS,JSDeprecatedSymbols

/**
 * @description LWC component that renders an interactive event timeline visualization
 * using the D3.js library. Events are plotted based on:
 * - Timestamp (X-axis, continuous timescale)
 * - Channel (Y-axis, band scale)
 *
 * The component exposes two public API properties:
 *  - `events`   — Array of event objects to plot. Each event must contain:
 *        - timestamp  (epoch ms)
 *        - channel    (string)
 *        - timeLabel  (formatted label for tooltip)
 *
 *  - `channels` — Array of channel names used to build the Y-axis categories.
 *
 * The timeline automatically:
 *  - Re-renders when either API property is updated
 *  - Loads D3 dynamically from a static resource
 *  - Displays time hover tooltips
 *  - Displays detailed data tooltips on event hover
 *  - Emits a `select` event when a user clicks an event dot
 *
 * This component is designed for dashboards, monitoring consoles, and real-time
 * streaming analytics pages that require chronological event visualization.
 */
import {LightningElement, api} from 'lwc';
import {loadScript} from 'lightning/platformResourceLoader';
import D3 from '@salesforce/resourceUrl/d3';
import {getTimeLabel} from 'c/utilityStreaming';

// ── Constants ────────────────────────────────────────────────────────────

const getEventTimestamp = (d) => d.timestamp;
const getEventChannel = (d) => d.channel;

const TIMELINE_HEIGHT_PX = '400px';
const MARGINS = {top: 0, right: 0, bottom: 20, left: 200};
const SCALE_PADDING = 1;
const CIRCLE_RADIUS = 10;
const COLOR_PALETTE_SIZE = 10;
const TOOLTIP_Y_OFFSET = 30;
const TIME_MARGIN_RATIO = 0.1;

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
 * @description Populates a D3 tooltip element with the provided label content,
 * supporting both single-line strings and multi-line arrays.
 *
 * @param {Object} tooltipElement - The D3 selection representing the tooltip container.
 * @param {string|Array<string>} label - The content to display.
 */
function buildTooltipContent(tooltipElement, label)
{
	tooltipElement.selectAll('*').remove();
	tooltipElement.text('');

	if(Array.isArray(label))
	{
		label.forEach((line, index) =>
		{
			if(index > 0)
			{
				tooltipElement.append('br');
			}
			tooltipElement.append('span').text(line);
		});
	}
	else
	{
		tooltipElement.text(label);
	}
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingTimeline extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/** @description List of event objects plotted on the timeline. */
	eventList = [];

	/** @description List of channel names for the Y-axis categories. */
	channelList = [];

	/** @description User timezone for time label formatting. */
	timezone;

	/** @description User locale for time label formatting. */
	locale;

	/** @description Whether D3 has been loaded and initialized. */
	isD3Loaded = false;

	/** @description Chart dimensions including margins. */
	dimensions;

	/** @description D3 group element containing the chart bounds. */
	bounds;

	/** @description D3 tooltip element for hover display. */
	tooltipElement;

	/** @description Whether the tooltip is showing data point details. */
	isShowingDataTooltip = false;

	/** @description D3 timescale for the X-axis. */
	xScale;

	/** @description D3 band scale for the Y-axis. */
	yScale;

	/** @description D3 bottom axis generator for the X-axis. */
	xAxis;

	/** @description D3 left axis generator for the Y-axis. */
	yAxis;

	// ── @api Properties ──────────────────────────────────────────────────

	get events()
	{
		return this.eventList;
	}

	@api set events(values)
	{
		this.eventList = values;
		this.drawTimeline();
	}

	get channels()
	{
		return this.channelList;
	}

	@api set channels(values)
	{
		this.channelList = values;
		this.drawTimeline();
	}

	get userTimezone()
	{
		return this.timezone;
	}

	@api set userTimezone(value)
	{
		this.timezone = value;
		this.drawTimeline();
	}

	get userLocale()
	{
		return this.locale;
	}

	@api set userLocale(value)
	{
		this.locale = value;
		this.drawTimeline();
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Lifecycle hook. Loads D3 static resource, then initializes charting.
	 */
	async connectedCallback()
	{
		await loadScript(this, D3);
		this.isD3Loaded = true;
		this.initializeTimeline();
	}

	/**
	 * @description Ensures D3 timeline is re-initialized whenever the component re-renders.
	 */
	async renderedCallback()
	{
		this.initializeTimeline();
	}

	// ── Chart Initialization ─────────────────────────────────────────────

	/**
	 * @description Initializes SVG container, scales, axes, and tooltip elements.
	 */
	initializeTimeline()
	{
		if(!this.isD3Loaded)
		{
			return;
		}

		const rootElement = this.template.querySelector('.timeline');
		rootElement.childNodes.forEach((childNode) => childNode.remove());

		const svgElement = d3
		.select(rootElement)
		.append('svg')
		.attr('width', '100%')
		.attr('height', TIMELINE_HEIGHT_PX);

		const rootElementRect = rootElement.getBoundingClientRect();
		this.dimensions = {
			x: rootElementRect.x, y: rootElementRect.y, width: rootElementRect.width, height: rootElementRect.height, margin: MARGINS
		};
		svgElement
		.attr('viewBox', `0 0 ${this.dimensions.width} ${this.dimensions.height}`)
		.on('mousemove', (event) =>
		{
			if(this.isShowingDataTooltip)
			{
				return;
			}

			const mousePos = d3.pointer(event);
			if(mousePos[0] > this.dimensions.margin.left && mousePos[1] < this.dimensions.height - this.dimensions.margin.bottom)
			{
				const time = this.xScale.invert(mousePos[0]);
				const timeLabel = getTimeLabel(time, this.timezone, this.locale);
				this.drawTooltip(mousePos, timeLabel);
			}
			else
			{
				this.hideTooltip();
			}
		})
		.on('mouseout', () =>
		{
			this.hideTooltip();
		});
		this.bounds = svgElement.append('g');

		this.bounds
		.append('g')
		.attr('id', 'x-axis')
		.attr('transform', `translate(0, ${this.dimensions.height - this.dimensions.margin.bottom})`);
		this.bounds
		.append('g')
		.attr('id', 'y-axis')
		.attr('transform', `translate(${this.dimensions.margin.left}, 0)`);

		this.xScale = d3
		.scaleTime()
		.range([
			this.dimensions.margin.left,
			this.dimensions.width - this.dimensions.margin.right
		]);
		this.yScale = d3
		.scaleBand()
		.range([
			this.dimensions.margin.top,
			this.dimensions.height - this.dimensions.margin.bottom
		])
		.paddingInner(SCALE_PADDING)
		.paddingOuter(SCALE_PADDING);

		this.xAxis = d3.axisBottom(this.xScale);
		this.yAxis = d3.axisLeft(this.yScale);

		this.tooltipElement = d3
		.select(rootElement)
		.append('div')
		.style('visibility', 'hidden');

		this.drawTimeline();
	}

	// ── Chart Drawing ────────────────────────────────────────────────────

	/**
	 * @description Draws event circles according to scales, binds hover/click events, and updates axes.
	 */
	drawTimeline()
	{
		if(!this.isD3Loaded)
		{
			return;
		}

		if(!this.events?.length)
		{
			return;
		}

		const userLocale = this.locale ? this.locale.replace('_', '-') : 'en-US';
		const testDate = new Date(2025, 0, 1, 13, 0, 0);
		const testFormat = testDate.toLocaleString(userLocale, {hour: 'numeric'});
		const usesTwelveHour = testFormat.includes('PM') || testFormat.includes('AM');
		const displayLocale = 'en-US';

		let previousTickDate = null;

		this.xAxis.tickFormat((d) =>
		{
			const result = formatAxisTick(d, previousTickDate, this.timezone, displayLocale, usesTwelveHour);
			previousTickDate = result.dateString;
			return result.label;
		});

		const chartStartsAt = this.events[0].timestamp;
		const chartEndsAt = this.events[this.events.length - 1].timestamp;
		const chartTimeMargin = (chartEndsAt - chartStartsAt) * TIME_MARGIN_RATIO;

		this.xScale.domain([
			chartStartsAt - chartTimeMargin,
			chartEndsAt + chartTimeMargin
		]);
		this.yScale.domain(this.channels);

		const xAxisElement = this.bounds.select('#x-axis');
		xAxisElement.selectAll('g').remove();
		xAxisElement.call(this.xAxis);

		xAxisElement
		.selectAll('g')
		.filter((d) => isMidnightBoundary(d, this.timezone))
		.attr('class', 'major-tick');
		this.bounds.select('#y-axis').transition().call(this.yAxis);

		const circles = this.bounds.selectAll('circle');
		circles
		.data(this.events)
		.join('circle')
		.attr('cx', (d) => this.xScale(getEventTimestamp(d)))
		.attr('cy', (d) => this.yScale(getEventChannel(d)))
		.attr('r', CIRCLE_RADIUS)
		.attr('class', (d) => this.getChannelColorClass(getEventChannel(d)))
		.on('mouseenter', (event, d) =>
		{
			this.isShowingDataTooltip = true;
			const mousePos = d3.pointer(event);
			const lines = [
				d.timeLabel,
				d.channel,
				'',
				'Click for more details.'
			];
			this.drawTooltip(mousePos, lines);
		})
		.on('mouseout', () =>
		{
			this.isShowingDataTooltip = false;
		})
		.on('click', (event, d) =>
		{
			this.hideTooltip();
			this.isShowingDataTooltip = false;
			const selectEvent = new CustomEvent('select', {
				detail: d
			});
			this.dispatchEvent(selectEvent);
		});
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

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
	 * @description Hides the tooltip element.
	 */
	hideTooltip()
	{
		this.tooltipElement.style('visibility', 'hidden');
	}

	/**
	 * @description Displays the tooltip at the specified mouse coordinates with the provided content.
	 *
	 * @param {Array<number>} mousePos - The [x, y] mouse coordinates relative to the SVG.
	 * @param {string|Array<string>} label - The content to display in the tooltip.
	 */
	drawTooltip(mousePos, label)
	{
		buildTooltipContent(this.tooltipElement, label);

		const tooltipRect = this.tooltipElement.node().getBoundingClientRect();
		const posX = mousePos[0] + this.dimensions.x - tooltipRect.width / 2;
		const posY = mousePos[1] + this.dimensions.y - TOOLTIP_Y_OFFSET - tooltipRect.height;
		this.tooltipElement
		.style('left', `${posX}px`)
		.style('top', `${posY}px`)
		.style('visibility', 'visible')
		.attr('class', this.isShowingDataTooltip ? 'tooltip data' : 'tooltip');
	}
}