// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/* global d3 */
// noinspection JSUnresolvedFunction,FunctionWithMultipleReturnPointsJS,JSDeprecatedSymbols

/**
 * @description
 * LWC component that renders a real-time event usage timeline visualization using D3.js.
 *
 * The component:
 * - Loads D3 from a static resource
 * - Retrieves event usage metrics from Apex
 * - Normalizes event data into a format suitable for charting
 * - Renders a responsive time-series visualization with:
 *      - Time-based x-axis
 *      - Logarithmic y-axis
 *      - Color-coded event categories
 *      - Dynamic tooltips (mouse & data-driven)
 * - Supports dynamic filtering through the child filter component (LwcEventUsageMetricsFilters)
 *
 * The component listens for `filter change` events, applies all filters
 * (before/after timestamps and event type selections), and redraws the timeline accordingly.
 *
 * This LWC is designed for dashboards and monitoring pages that visualize
 * high-volume event activity over time.
 */
import {LightningElement} from 'lwc';
import {loadScript} from 'lightning/platformResourceLoader';
import D3 from '@salesforce/resourceUrl/d3';
import getEventUsageMetrics from '@salesforce/apex/CTRL_EventMonitor.getEventUsageMetrics';
import {getTimeLabel, toTitleCase} from 'c/utilityStreaming';
import utilityLogger from 'c/utilityLogger';

// ── Constants ────────────────────────────────────────────────────────────

const METRICS_CHART_HEIGHT_PX = '400px';
const MARGINS = {top: 40, right: 40, bottom: 40, left: 40};
const CIRCLE_RADIUS = 10;
const TOOLTIP_Y_OFFSET = 30;
const TIME_MARGIN_RATIO = 0.1;

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Normalizes a raw Apex metric record into a chart-ready data point.
 *
 * @param {Object} metric - The raw metric record from Apex with Name, StartDate, and Value.
 * @param {Map<string, number>} eventIndexes - A map of event names to their type index.
 * @returns {Object} A normalized metric with type, timestamp, timeLabel, and value.
 */
function normalizeMetric(metric, eventIndexes)
{
	const time = new Date(metric.StartDate);
	return {
		type: eventIndexes.get(metric.Name), timestamp: time.getTime(), timeLabel: getTimeLabel(time), value: metric.Value
	};
}

/**
 * @description Builds the event type definition array from unique event names and a D3 color scale.
 *
 * @param {Array<string>} eventNames - Sorted unique event names.
 * @param {Function} colorScale - A D3 sequential color scale function.
 * @returns {Array<Object>} An array of event type objects with index, label, and color.
 */
function buildEventTypeDefinitions(eventNames, colorScale)
{
	return eventNames.map((type, index) => ({
		index, label: toTitleCase(type), color: colorScale(index)
	}));
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

/**
 * @description Extracts the indices of unchecked (hidden) event types from a boolean array.
 *
 * @param {Array<boolean>} eventTypes - Boolean array where false indicates hidden.
 * @returns {Array<number>} Indices of the hidden event types.
 */
function getHiddenTypeIndices(eventTypes)
{
	return eventTypes.reduce((indices, isChecked, index) =>
	{
		if(!isChecked)
		{
			indices.push(index);
		}
		return indices;
	}, []);
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingUsageMetrics extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/** @description Full unfiltered list of event usage metrics. */
	allMetrics = [];

	/** @description Currently visible metrics after filtering. */
	filteredMetrics = [];

	/** @description Unique event type definitions with color assignments. */
	eventTypeDefinitions = [];

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

	/** @description D3 log scale for the Y-axis. */
	yScale;

	/** @description D3 bottom axis generator for the X-axis. */
	xAxis;

	/** @description D3 left axis generator for the Y-axis. */
	yAxis;

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Computed CSS class for showing/hiding the timeline container.
	 */
	get timelineClasses()
	{
		return `timeline ${this.filteredMetrics?.length > 0 ? '' : 'slds-hide'}`;
	}

	/**
	 * @description Displays the number of visible items vs the total dataset.
	 * Used for summary text below the chart.
	 */
	get eventCountLabel()
	{
		if(this.allMetrics?.length === 0)
		{
			return 'No data to display';
		}
		if(this.allMetrics?.length !== this.filteredMetrics?.length)
		{
			return `Showing ${this.filteredMetrics?.length} of ${this.allMetrics?.length} items`;
		}
		return `Showing ${this.allMetrics?.length} items`;
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description
	 * Lifecycle hook responsible for:
	 *  - Loading D3.js from static resources
	 *  - Retrieving event usage metrics from Apex
	 *  - Extracting unique event types & assigning colors
	 *  - Preprocessing records: converting timestamps, values, and labels
	 *  - Initializing the chart timeline
	 */
	async connectedCallback()
	{
		try
		{
			let [metrics] = await Promise.all([
				getEventUsageMetrics(),
				loadScript(this, D3)
			]);
			this.isD3Loaded = true;
			const eventNames = [...new Set(metrics.map(m => m.Name))].sort();
			const eventIndexes = new Map();
			eventNames.forEach((item, index) => eventIndexes.set(item, index));
			metrics = metrics.map((metric) => normalizeMetric(metric, eventIndexes));
			const colorScale = d3
			.scaleSequential()
			.domain([
				0,
				eventNames.length
			])
			.interpolator(d3.interpolateRainbow);
			this.filteredMetrics = metrics;
			this.allMetrics = this.filteredMetrics;
			this.eventTypeDefinitions = buildEventTypeDefinitions(eventNames, colorScale);

			this.initializeTimeline();
		}
		catch(error)
		{
			utilityLogger.error('Failed to initialize chart', error);
		}
	}

	/**
	 * @description Renders or re-renders the D3 visualization when DOM updates.
	 * Called automatically after every render cycle.
	 */
	async renderedCallback()
	{
		this.initializeTimeline();
	}

	// ── Chart Initialization ─────────────────────────────────────────────

	/**
	 * @description
	 * Initializes the D3 visualization container. This includes:
	 *  - Creating SVG root element
	 *  - Setting up dimensions & view box
	 *  - Creating axis groups
	 *  - Creating time and log scales
	 *  - Registering mouse movement handlers for live tooltips
	 *  - Rendering the initial timeline
	 */
	initializeTimeline()
	{
		if(!this.isD3Loaded)
		{
			return;
		}

		const rootElement = this.template.querySelector('.timeline');
		d3.select(rootElement).selectAll('*').remove();

		const svgElement = d3
		.select(rootElement)
		.append('svg')
		.attr('width', '100%')
		.attr('height', METRICS_CHART_HEIGHT_PX);

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
				const timeLabel = getTimeLabel(time);
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
		.scaleLog()
		.range([
			this.dimensions.height - this.dimensions.margin.bottom,
			this.dimensions.margin.top
		]);

		this.xAxis = d3.axisBottom(this.xScale);
		this.yAxis = d3.axisLeft(this.yScale);

		this.tooltipElement = d3
		.select(rootElement)
		.append('div')
		.style('visibility', 'hidden');

		try
		{
			this.drawTimeline();
		}
		catch(error)
		{
			utilityLogger.error('Failed to draw chart', error);
		}
	}

	// ── Chart Drawing ────────────────────────────────────────────────────

	/**
	 * @description Core chart drawing function.
	 * Updates X/Y domain values, axes, data points, and tooltip handlers.
	 */
	drawTimeline()
	{
		if(this.filteredMetrics.length === 0)
		{
			return;
		}
		const xMin = this.filteredMetrics[0].timestamp;
		const xMax = this.filteredMetrics[this.filteredMetrics.length - 1].timestamp;
		const chartTimeMargin = (xMax - xMin) * TIME_MARGIN_RATIO;
		const values = this.filteredMetrics.map((m) => m.value);

		this.xScale.domain([
			xMin - chartTimeMargin,
			xMax + chartTimeMargin
		]);
		this.yScale.domain([
			Math.min(...values),
			Math.max(...values)
		]);

		const xAxisElement = this.bounds.select('#x-axis');
		xAxisElement.selectAll('g').remove();
		xAxisElement.call(this.xAxis);
		this.bounds.select('#y-axis').transition().call(this.yAxis);

		const circles = this.bounds.selectAll('circle');
		circles
		.data(this.filteredMetrics)
		.join('circle')
		.attr('cx', (d) => this.xScale(d.timestamp))
		.attr('cy', (d) => this.yScale(d.value))
		.attr('r', CIRCLE_RADIUS)
		.attr('stroke', 'white')
		.style('fill', (d) => this.eventTypeDefinitions[d.type].color)
		.on('mouseenter', (event, d) =>
		{
			this.isShowingDataTooltip = true;
			const mousePos = d3.pointer(event);
			const lines = [
				d.timeLabel,
				`${d.value} ${this.eventTypeDefinitions[d.type].label}`
			];
			this.drawTooltip(mousePos, lines);
		})
		.on('mouseout', () =>
		{
			this.isShowingDataTooltip = false;
		});
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Hides the tooltip.
	 */
	hideTooltip()
	{
		this.tooltipElement.style('visibility', 'hidden');
	}

	/**
	 * @description Draws tooltip at specified mouse coordinates.
	 * Calculates optimal positioning and applies style classes.
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

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description
	 * Handles filter updates from the LwcEventUsageMetricsFilters child component.
	 * Applies after time, before time, and event type visibility filters,
	 * then triggers a redraw of the timeline.
	 *
	 * @param {CustomEvent} event - The filterchange event from the child filter component.
	 */
	handleFilterChange(event)
	{
		const {afterTime, beforeTime, eventTypes} = event.detail;
		const hiddenTypes = getHiddenTypeIndices(eventTypes);
		this.filteredMetrics = this.allMetrics
		.filter((e) => !afterTime || (e.timestamp && e.timestamp >= afterTime))
		.filter((e) => !beforeTime || (e.timestamp && e.timestamp <= beforeTime))
		.filter((e) => hiddenTypes.length === 0 || !hiddenTypes.includes(e.type));
		this.drawTimeline();
	}
}