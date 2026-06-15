// SPDX-License-Identifier: BUSL-1.1
/* global d3 */
// noinspection JSUnresolvedFunction,FunctionWithMultipleReturnPointsJS,JSDeprecatedSymbols

/**
 * @description LWC component that renders a horizontal bar chart of Salesforce org limits
 * using D3.js. Each bar represents a limit's percentage consumed, with tooltips showing
 * the consumed value and maximum.
 *
 * @date March 2026, May 2026
 */
import {LightningElement} from 'lwc';
import getOrgLimits from '@salesforce/apex/CTRL_EventMonitor.getOrgLimits';
import {loadScript} from 'lightning/platformResourceLoader';
import D3 from '@salesforce/resourceUrl/d3';
import LOCALE from '@salesforce/i18n/locale';

// ── Constants ────────────────────────────────────────────────────────────

/**
 * @description Accessor function returning the percentage value of a limit record.
 *
 * @param {Object} datum - A single limit record.
 * @returns {number} The percentage consumed.
 */
const getPercentage = (datum) => datum.percent;

/**
 * @description Accessor function returning the name of a limit record.
 *
 * @param {Object} datum - A single limit record.
 * @returns {string} The limit name.
 */
const getLimitName = (datum) => datum.name;

/**
 * @description Localized number formatter used for rendering values in tooltips and labels.
 */
const numberFormatter = new Intl.NumberFormat(LOCALE);

/**
 * @description Margins used around the chart layout.
 */
const MARGINS = {top: 0, right: 20, bottom: 20, left: 300};

/**
 * @description Height in pixels for each row in the bar chart.
 */
const ROW_HEIGHT = 30;

const TOOLTIP_Y_OFFSET = 30;

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Transforms raw Apex limit records by computing the percentage consumed
 * and sorting alphabetically by name.
 *
 * @param {Array<Object>} rawLimits - Raw limit records from Apex.
 * @returns {Array<Object>} Transformed limits with computed `percent` field.
 */
function transformLimits(rawLimits)
{
	return rawLimits
	.map((limit) =>
	{
		const limitData = {...limit};
		limitData.percent = limitData.max === 0 ? 0 : Math.trunc((limitData.value / limitData.max) * 100);
		return limitData;
	})
	.sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * @description Calculates tooltip position relative to the chart root.
 *
 * @param {Array<number>} mousePos - The [x, y] mouse position.
 * @param {DOMRect} rootRect - Bounding rect of the chart root element.
 * @param {DOMRect} tooltipRect - Bounding rect of the tooltip element.
 * @returns {{posX: number, posY: number}} Calculated position.
 */
function calculateTooltipPosition(mousePos, rootRect, tooltipRect)
{
	return {
		posX: mousePos[0] + rootRect.x - tooltipRect.width / 2, posY: mousePos[1] + rootRect.y - TOOLTIP_Y_OFFSET - tooltipRect.height
	};
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class OrgLimits extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/** @description Transformed org limit records with computed percentages. */
	limits;

	/** @description Contains error information if the Apex call fails. */
	error;

	/** @description Whether D3 has been loaded and initialized. */
	isD3Loaded = false;

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Loads org limit data from Apex and the D3 script resource.
	 * Transforms limit data and draws the chart.
	 */
	async connectedCallback()
	{
		try
		{
			const [limits] = await Promise.all([
				getOrgLimits(),
				loadScript(this, D3)
			]);

			this.isD3Loaded = true;
			this.limits = transformLimits(limits);
			this.drawChart();
		}
		catch(error)
		{
			this.error = JSON.stringify(error);
		}
	}

	/**
	 * @description Ensures the chart is redrawn when component dimensions change.
	 */
	async renderedCallback()
	{
		this.drawChart();
	}

	// ── Chart Drawing ────────────────────────────────────────────────────

	/**
	 * @description Renders the limits bar chart using D3, including axes, bars, labels, and tooltip.
	 */
	drawChart()
	{
		if(!this.isD3Loaded)
		{
			return;
		}

		const rootElement = this.template.querySelector('.chart');
		rootElement.childNodes.forEach((childNode) => childNode.remove());

		const svg = d3.select(rootElement)
		.append('svg')
		.attr('width', '100%')
		.attr('height', `${this.limits.length * ROW_HEIGHT}px`);

		const dimensions = rootElement.getBoundingClientRect();
		svg.attr('viewBox', `0 0 ${dimensions.width} ${dimensions.height}`);

		const bounds = svg.append('g');

		const xAxisGroup = bounds
		.append('g')
		.attr('transform', `translate(0, ${dimensions.height - MARGINS.bottom})`);

		const yAxisGroup = bounds
		.append('g')
		.attr('transform', `translate(${MARGINS.left}, 0)`);

		const xScale = d3.scaleLinear()
		.range([
			MARGINS.left,
			dimensions.width - MARGINS.right
		])
		.domain([
			0,
			100
		]);

		const yScale = d3.scaleBand()
		.range([
			MARGINS.top,
			dimensions.height - MARGINS.bottom
		])
		.domain(this.limits.map((datum) => datum.name))
		.paddingInner(0.25)
		.paddingOuter(0.25);

		const xAxis = d3.axisBottom(xScale);
		xAxisGroup.call(xAxis);

		const yAxis = d3.axisLeft(yScale).tickSize(0);
		yAxisGroup.call(yAxis);

		d3.select(rootElement).append('div').attr('class', 'tooltip inactive');

		bounds
		.selectAll('.bar')
		.data(this.limits)
		.join('rect')
		.attr('class', 'bar')
		.attr('y', (datum) => yScale(getLimitName(datum)))
		.attr('height', yScale.bandwidth())
		.attr('x', MARGINS.left)
		.attr('width', (datum) => xScale(getPercentage(datum)) - MARGINS.left)
		.on('mouseenter', (event, datum) =>
		{
			const mousePos = d3.pointer(event);
			this.drawTooltip(mousePos, datum);
		})
		.on('mouseout', () => this.hideTooltip());

		this.renderLabels(bounds, xScale, yScale);
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Renders percentage labels at the end of each bar.
	 *
	 * @param {Object} bounds - D3 group element where labels will be appended.
	 * @param {Function} xScale - Preconfigured D3 x-scale.
	 * @param {Function} yScale - Preconfigured D3 y-scale.
	 */
	renderLabels(bounds, xScale, yScale)
	{
		this.limits.forEach((limitData) =>
		{
			const posX = xScale(getPercentage(limitData)) + 3;
			const posY = yScale(getLimitName(limitData)) + yScale.bandwidth() / 2 + 4;

			bounds.append('text')
			.attr('class', 'label')
			.attr('x', posX)
			.attr('y', posY)
			.text(`${limitData.percent}%`);
		});
	}

	/**
	 * @description Hides the tooltip by applying the inactive CSS class.
	 */
	hideTooltip()
	{
		const tooltipElement = this.template.querySelector('.tooltip');
		tooltipElement.classList.add('inactive');
	}

	/**
	 * @description Displays a tooltip at the given mouse coordinate with limit details.
	 *
	 * @param {Array<number>} mousePos - The [x, y] position from D3 pointer.
	 * @param {Object} data - The limit data object containing name, value, max, and percent.
	 */
	drawTooltip(mousePos, data)
	{
		const tooltip = this.template.querySelector('.tooltip');

		while(tooltip.firstChild)
		{
			tooltip.removeChild(tooltip.firstChild);
		}

		const nameElement = document.createElement('b');
		nameElement.textContent = data.name;
		tooltip.appendChild(nameElement);

		tooltip.appendChild(document.createElement('br'));
		tooltip.appendChild(document.createTextNode(`Consumed: ${numberFormatter.format(data.value)} (${data.percent}%)`));

		tooltip.appendChild(document.createElement('br'));
		tooltip.appendChild(document.createTextNode(`Limit: ${numberFormatter.format(data.max)}`));

		const tooltipRect = tooltip.getBoundingClientRect();
		const rootRect = this.template.querySelector('.chart').getBoundingClientRect();

		const {posX, posY} = calculateTooltipPosition(mousePos, rootRect, tooltipRect);

		tooltip.style.left = `${posX}px`;
		tooltip.style.top = `${posY}px`;
		tooltip.classList.remove('inactive');
	}
}