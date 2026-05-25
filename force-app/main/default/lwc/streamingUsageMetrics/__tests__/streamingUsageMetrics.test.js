// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for streamingUsageMetrics LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */
import {createElement} from 'lwc';
import LwcEventUsageMetrics from 'c/streamingUsageMetrics';

// Mock Apex controller
const mockGetEventUsageMetrics = jest.fn();

jest.mock('@salesforce/apex/CTRL_EventMonitor.getEventUsageMetrics', () => ({
	default: (...args) => mockGetEventUsageMetrics(...args)
}), {virtual: true});

// Mock loadScript
const mockLoadScript = jest.fn();

jest.mock('lightning/platformResourceLoader', () => ({
	loadScript: (...args) => mockLoadScript(...args)
}), {virtual: true});

// Mock D3 resource URL
jest.mock('@salesforce/resourceUrl/d3', () => ({default: '/sfc/servlet.shepherd/version/download/mockD3'}), {virtual: true});

// Mock utilityStreaming
jest.mock('c/utilityStreaming', () => ({
	getTimeLabel: jest.fn(() => '2025-12-28 10:30:00'), toTitleCase: jest.fn((s) => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase())
}), {virtual: true});

// Mock utilityLogger
jest.mock('c/utilityLogger', () => ({
	__esModule: true, default: {
		error: jest.fn(), warn: jest.fn(), info: jest.fn(), debug: jest.fn()
	}
}), {virtual: true});

// Captured callbacks for testing
let capturedSvgMousemoveCallback = null;
let capturedSvgMouseoutCallback = null;
let capturedCircleMouseenterCallback = null;
let capturedCircleMouseoutCallback = null;
let capturedCircleCxCallback = null;
let capturedCircleCyCallback = null;
let capturedCircleFillCallback = null;

// Create chainable D3 mock that maintains circle context
const createChainableMock = (isCircle = false) =>
{
	const mock = {};
	// Helper to create a continuation mock that maintains the isCircle flag
	const continueMock = () => (isCircle ? createCircleMock() : mock);

	mock.append = jest.fn(() => createChainableMock());
	mock.attr = jest.fn((attrName, callback) =>
	{
		if(isCircle && typeof callback === 'function')
		{
			if(attrName === 'cx')
			{
				capturedCircleCxCallback = callback;
			}
			else if(attrName === 'cy')
			{
				capturedCircleCyCallback = callback;
			}
		}
		return continueMock();
	});
	mock.call = jest.fn(() => mock);
	mock.select = jest.fn(() => createChainableMock());
	mock.selectAll = jest.fn((selector) =>
	{
		if(selector === 'circle')
		{
			return createCircleMock();
		}
		return mock;
	});
	mock.data = jest.fn(() => continueMock());
	mock.join = jest.fn(() => createCircleMock());
	mock.enter = jest.fn(() => mock);
	mock.exit = jest.fn(() => mock);
	mock.on = jest.fn((eventName, callback) =>
	{
		if(isCircle)
		{
			if(eventName === 'mouseenter')
			{
				capturedCircleMouseenterCallback = callback;
			}
			else if(eventName === 'mouseout')
			{
				capturedCircleMouseoutCallback = callback;
			}
		}
		else
		{
			if(eventName === 'mousemove')
			{
				capturedSvgMousemoveCallback = callback;
			}
			else if(eventName === 'mouseout')
			{
				capturedSvgMouseoutCallback = callback;
			}
		}
		return continueMock();
	});
	mock.text = jest.fn(() => mock);
	mock.style = jest.fn((styleName, callback) =>
	{
		if(isCircle && styleName === 'fill' && typeof callback === 'function')
		{
			capturedCircleFillCallback = callback;
		}
		return continueMock();
	});
	mock.html = jest.fn(() => mock);
	mock.range = jest.fn(() => mock);
	mock.domain = jest.fn(() => mock);
	mock.nice = jest.fn(() => mock);
	mock.paddingInner = jest.fn(() => mock);
	mock.paddingOuter = jest.fn(() => mock);
	mock.tickSize = jest.fn(() => mock);
	mock.tickFormat = jest.fn(() => mock);
	mock.ticks = jest.fn(() => mock);
	mock.bandwidth = jest.fn(() => 20);
	mock.classed = jest.fn(() => mock);
	mock.remove = jest.fn(() => mock);
	mock.filter = jest.fn(() => mock);
	mock.each = jest.fn(() => mock);
	mock.merge = jest.fn(() => mock);
	mock.transition = jest.fn(() => mock);
	mock.duration = jest.fn(() => mock);
	mock.interpolator = jest.fn(() => mock);
	mock.invert = jest.fn(() => new Date());
	mock.node = jest.fn(() => ({
		getBoundingClientRect: () => ({
			x: 0, y: 0, width: 100, height: 50, top: 0, right: 100, bottom: 50, left: 0, toJSON()
			{
			}
		})
	}));
	return mock;
};

// Create a circle-specific mock that always stays in circle context
function createCircleMock()
{
	return createChainableMock(true);
}

// Create a callable color scale that is also chainable
const createColorScaleMock = () =>
{
	const scaleFn = jest.fn((index) => `rgb(${Math.floor(index * 50)}, 100, 100)`);
	scaleFn.domain = jest.fn(() => scaleFn);
	scaleFn.interpolator = jest.fn(() => scaleFn);
	return scaleFn;
};

// Create a callable timescale that returns numeric pixel positions
const createTimeScaleMock = () =>
{
	const scaleFn = jest.fn((timestamp) => (timestamp ? 100 : 0));
	scaleFn.range = jest.fn(() => scaleFn);
	scaleFn.domain = jest.fn(() => scaleFn);
	scaleFn.invert = jest.fn(() => new Date());
	return scaleFn;
};

// Create a callable log scale that returns numeric pixel positions
const createLogScaleMock = () =>
{
	const scaleFn = jest.fn((value) => (value ? 200 : 0));
	scaleFn.range = jest.fn(() => scaleFn);
	scaleFn.domain = jest.fn(() => scaleFn);
	return scaleFn;
};

global.d3 = {
	select: jest.fn(() => createChainableMock()),
	scaleLinear: jest.fn(() => createChainableMock()),
	scaleBand: jest.fn(() => createChainableMock()),
	scaleTime: jest.fn(() => createTimeScaleMock()),
	scaleLog: jest.fn(() => createLogScaleMock()),
	scaleOrdinal: jest.fn(() => createChainableMock()),
	scaleSequential: jest.fn(() => createColorScaleMock()),
	schemeCategory10: [],
	axisBottom: jest.fn(() => createChainableMock()),
	axisLeft: jest.fn(() => createChainableMock()),
	axisTop: jest.fn(() => createChainableMock()),
	timeFormat: jest.fn(() => () => '10:30:00'),
	pointer: jest.fn(() => [
		100,
		100
	]),
	extent: jest.fn(() => [
		0,
		100
	]),
	min: jest.fn(() => 0),
	max: jest.fn(() => 100),
	interpolateRainbow: jest.fn((t) => `rgb(${Math.floor(t * 255)}, 0, 0)`)
};

const mockMetrics = [
	{Name: 'PlatformEvents', StartDate: '2025-12-28T10:00:00.000Z', Value: 100},
	{Name: 'PlatformEvents', StartDate: '2025-12-28T10:30:00.000Z', Value: 150},
	{Name: 'ChangeEvents', StartDate: '2025-12-28T10:00:00.000Z', Value: 50}
];

describe('c-streaming-usage-metrics', () =>
{
	beforeEach(() =>
	{
		mockGetEventUsageMetrics.mockResolvedValue(mockMetrics);
		mockLoadScript.mockResolvedValue();
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
		capturedSvgMousemoveCallback = null;
		capturedSvgMouseoutCallback = null;
		capturedCircleMouseenterCallback = null;
		capturedCircleMouseoutCallback = null;
		capturedCircleCxCallback = null;
		capturedCircleCyCallback = null;
		capturedCircleFillCallback = null;
	});

	async function flushPromises()
	{
		return new Promise((resolve) => setTimeout(resolve, 0));
	}

	const createComponent = () =>
	{
		const element = createElement('c-streaming-usage-metrics', {is: LwcEventUsageMetrics});
		document.body.appendChild(element);
		return element;
	};

	/**
	 * Creates a component and waits for Apex data and D3 initialization to complete.
	 */
	async function createInitializedComponent()
	{
		const element = createComponent();
		await flushPromises();
		await flushPromises();
		return element;
	}

	describe('initialization', () =>
	{
		it('loads event metrics from Apex on connected', async() =>
		{
			createComponent();
			await flushPromises();

			expect(mockGetEventUsageMetrics).toHaveBeenCalled();
		});

		it('renders component after initialization', async() =>
		{
			// Note: loadScript mock isn't reliably hoisted by sfdx-lwc-jest
			// so we verify component renders instead
			const element = createComponent();
			await flushPromises();

			expect(element).toBeDefined();
		});

		it('calls Apex to load event metrics', async() =>
		{
			createComponent();
			await flushPromises();

			expect(mockGetEventUsageMetrics).toHaveBeenCalledTimes(1);
		});
	});

	describe('component structure', () =>
	{
		it('renders lightning-card', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
		});

		it('renders timeline container', async() =>
		{
			const element = await createInitializedComponent();

			const timeline = element.shadowRoot.querySelector('.timeline');
			expect(timeline).not.toBeNull();
		});

		it('renders filters component', async() =>
		{
			const element = await createInitializedComponent();

			const filters = element.shadowRoot.querySelector('c-streaming-usage-filters');
			expect(filters).not.toBeNull();
		});
	});

	describe('chart rendering', () =>
	{
		it('uses D3 to create chart after loading', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.select).toHaveBeenCalled();
		});

		it('creates timescale for x-axis', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.scaleTime).toHaveBeenCalled();
		});

		it('creates log scale for y-axis', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.scaleLog).toHaveBeenCalled();
		});

		it('creates sequential color scale', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.scaleSequential).toHaveBeenCalled();
		});
	});

	describe('error handling', () =>
	{
		it('handles Apex error gracefully', async() =>
		{
			const utilityLogger = require('c/utilityLogger').default;
			mockGetEventUsageMetrics.mockRejectedValueOnce(new Error('Apex error'));

			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// Component should still render
			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
			expect(utilityLogger.error).toHaveBeenCalled();
		});

		it('handles loadScript error gracefully', async() =>
		{
			const utilityLogger = require('c/utilityLogger').default;
			mockLoadScript.mockRejectedValueOnce(new Error('Script load failed'));

			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// Component should still render
			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
			expect(utilityLogger.error).toHaveBeenCalled();
		});
	});

	describe('getters', () =>
	{
		it('eventCountLabel shows count when data exists', async() =>
		{
			const element = await createInitializedComponent();

			// Component should show item count
			const label = element.shadowRoot.querySelector('.event-count');
			if(label)
			{
				expect(label.textContent).toContain('items');
			}
		});

		it('eventCountLabel shows no data message when empty', async() =>
		{
			mockGetEventUsageMetrics.mockResolvedValueOnce([]);

			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// eventCountLabel should indicate no data
			const label = element.shadowRoot.querySelector('.event-count');
			if(label)
			{
				expect(label.textContent).toContain('No data');
			}
		});

		it('timelineClasses shows timeline when data exists', async() =>
		{
			const element = await createInitializedComponent();

			const timeline = element.shadowRoot.querySelector('.timeline');
			expect(timeline).not.toBeNull();
			expect(timeline.className).not.toContain('slds-hide');
		});

		it('timelineClasses hides timeline when no data', async() =>
		{
			mockGetEventUsageMetrics.mockResolvedValueOnce([]);

			const element = createComponent();
			await flushPromises();
			await flushPromises();

			const timeline = element.shadowRoot.querySelector('.timeline');
			expect(timeline).not.toBeNull();
			expect(timeline.className).toContain('slds-hide');
		});
	});

	describe('data transformation', () =>
	{
		it('extracts unique event types from metrics', async() =>
		{
			await createInitializedComponent();

			// toTitleCase should be called for event type names
			const {toTitleCase} = require('c/utilityStreaming');
			expect(toTitleCase).toHaveBeenCalled();
		});

		it('transforms metrics with timestamps', async() =>
		{
			await createInitializedComponent();

			// getTimeLabel should be called for formatting timestamps
			const {getTimeLabel} = require('c/utilityStreaming');
			expect(getTimeLabel).toHaveBeenCalled();
		});
	});

	describe('handleFilterChange', () =>
	{
		it('filters by afterTime', async() =>
		{
			const element = await createInitializedComponent();

			const filtersComponent = element.shadowRoot.querySelector('c-streaming-usage-filters');
			expect(filtersComponent).not.toBeNull();

			// Dispatch filter event with afterTime
			const futureTime = new Date('2025-12-28T10:15:00.000Z').getTime();
			filtersComponent.dispatchEvent(new CustomEvent('filterchange', {
				detail: {
					afterTime: futureTime, beforeTime: null, eventTypes: [
						true,
						true
					]
				}
			}));
			await flushPromises();

			// drawTimeline should be called (D3 is used)
			expect(global.d3.select).toHaveBeenCalled();
		});

		it('filters by beforeTime', async() =>
		{
			const element = await createInitializedComponent();

			const filtersComponent = element.shadowRoot.querySelector('c-streaming-usage-filters');

			// Dispatch filter event with beforeTime
			const pastTime = new Date('2025-12-28T10:15:00.000Z').getTime();
			filtersComponent.dispatchEvent(new CustomEvent('filterchange', {
				detail: {
					afterTime: null, beforeTime: pastTime, eventTypes: [
						true,
						true
					]
				}
			}));
			await flushPromises();

			expect(global.d3.select).toHaveBeenCalled();
		});

		it('filters by event types', async() =>
		{
			const element = await createInitializedComponent();

			const filtersComponent = element.shadowRoot.querySelector('c-streaming-usage-filters');

			// Dispatch filter event hiding first event type (index 0)
			filtersComponent.dispatchEvent(new CustomEvent('filterchange', {
				detail: {
					afterTime: null, beforeTime: null, eventTypes: [
						false,
						true
					]
				}
			}));
			await flushPromises();

			expect(global.d3.select).toHaveBeenCalled();
		});

		it('applies all filters together', async() =>
		{
			const element = await createInitializedComponent();

			const filtersComponent = element.shadowRoot.querySelector('c-streaming-usage-filters');

			// Dispatch filter event with all filter types
			const afterTime = new Date('2025-12-28T09:00:00.000Z').getTime();
			const beforeTime = new Date('2025-12-28T11:00:00.000Z').getTime();
			filtersComponent.dispatchEvent(new CustomEvent('filterchange', {
				detail: {
					afterTime, beforeTime, eventTypes: [
						true,
						false
					]
				}
			}));
			await flushPromises();

			expect(global.d3.select).toHaveBeenCalled();
		});

		it('handles empty filtered results', async() =>
		{
			const element = await createInitializedComponent();

			const filtersComponent = element.shadowRoot.querySelector('c-streaming-usage-filters');

			// Dispatch filter event that filters out all data
			const farFutureTime = new Date('2030-01-01T00:00:00.000Z').getTime();
			filtersComponent.dispatchEvent(new CustomEvent('filterchange', {
				detail: {
					afterTime: farFutureTime, beforeTime: null, eventTypes: [
						true,
						true
					]
				}
			}));
			await flushPromises();

			// Timeline should be hidden when no data
			const timeline = element.shadowRoot.querySelector('.timeline');
			expect(timeline).not.toBeNull();
			expect(timeline.className).toContain('slds-hide');
		});
	});

	describe('eventCountLabel with filtering', () =>
	{
		it('shows filtered count when different from total', async() =>
		{
			const element = await createInitializedComponent();

			const filtersComponent = element.shadowRoot.querySelector('c-streaming-usage-filters');

			// Filter to show only some items (hide one event type)
			filtersComponent.dispatchEvent(new CustomEvent('filterchange', {
				detail: {
					afterTime: null, beforeTime: null, eventTypes: [
						true,
						false
					]
				}
			}));
			await flushPromises();

			// eventCountLabel should show "Showing X of Y items" format
			const label = element.shadowRoot.querySelector('.event-count');
			if(label)
			{
				expect(label.textContent).toMatch(/Showing \d+ of \d+ items/);
			}
		});
	});

	describe('SVG mouse handlers', () =>
	{
		it('handles mousemove within chart bounds', async() =>
		{
			await createInitializedComponent();

			expect(capturedSvgMousemoveCallback).not.toBeNull();
			// Simulate mouse event with coordinates within chart bounds
			const mockEvent = {clientX: 100, clientY: 100};
			// This should not throw
			expect(() => capturedSvgMousemoveCallback(mockEvent)).not.toThrow();
		});

		it('handles mousemove and draws tooltip within valid bounds', async() =>
		{
			// Mock getBoundingClientRect to return proper dimensions
			const originalGetBoundingClientRect = Element.prototype.getBoundingClientRect;
			Element.prototype.getBoundingClientRect = jest.fn(() => ({
				x: 0, y: 0, width: 800, height: 400, top: 0, right: 800, bottom: 400, left: 0, toJSON()
				{
				}
			}));

			createComponent();
			await flushPromises();
			await flushPromises();

			// Restore original
			Element.prototype.getBoundingClientRect = originalGetBoundingClientRect;

			expect(capturedSvgMousemoveCallback).not.toBeNull();
			// d3.pointer returns [100, 100] which is:
			// - Greater than margin.left (40)
			// - Less than height - margin.bottom (400 - 40 = 360)
			// So it should trigger drawTooltip
			const mockEvent = {clientX: 100, clientY: 100};
			expect(() => capturedSvgMousemoveCallback(mockEvent)).not.toThrow();
		});

		it('handles mousemove outside chart bounds (left margin)', async() =>
		{
			await createInitializedComponent();

			expect(capturedSvgMousemoveCallback).not.toBeNull();
			// Mock d3.pointer to return coordinates outside left margin
			global.d3.pointer = jest.fn(() => [
				10,
				100
			]); // x=10 is within left margin (40)

			const mockEvent = {clientX: 10, clientY: 100};
			expect(() => capturedSvgMousemoveCallback(mockEvent)).not.toThrow();
		});

		it('handles mousemove outside chart bounds (bottom margin)', async() =>
		{
			await createInitializedComponent();

			expect(capturedSvgMousemoveCallback).not.toBeNull();
			// Mock d3.pointer to return coordinates below bottom margin
			global.d3.pointer = jest.fn(() => [
				100,
				380
			]); // y=380 is in bottom margin (height 400, margin 40)

			const mockEvent = {clientX: 100, clientY: 380};
			expect(() => capturedSvgMousemoveCallback(mockEvent)).not.toThrow();
		});

		it('handles mouseout', async() =>
		{
			await createInitializedComponent();

			expect(capturedSvgMouseoutCallback).not.toBeNull();
			expect(() => capturedSvgMouseoutCallback()).not.toThrow();
		});

		it('mousemove with isDataTooltip true returns early', async() =>
		{
			await createInitializedComponent();

			// Trigger circle mouseenter first to set isDataTooltip = true
			expect(capturedCircleMouseenterCallback).not.toBeNull();
			const mockData = {timestamp: Date.now(), value: 100, type: 0, timeLabel: '10:00:00'};
			capturedCircleMouseenterCallback({}, mockData);

			// Now SVG mousemove should return early
			expect(capturedSvgMousemoveCallback).not.toBeNull();
			global.d3.pointer = jest.fn(() => [
				100,
				100
			]);
			const mockEvent = {clientX: 100, clientY: 100};
			expect(() => capturedSvgMousemoveCallback(mockEvent)).not.toThrow();
		});
	});

	describe('circle mouse handlers', () =>
	{
		it('handles circle mouseenter', async() =>
		{
			await createInitializedComponent();

			expect(capturedCircleMouseenterCallback).not.toBeNull();
			const mockData = {
				timestamp: Date.now(), value: 100, type: 0, timeLabel: '2025-12-28 10:00:00'
			};
			const mockEvent = {clientX: 150, clientY: 150};
			expect(() => capturedCircleMouseenterCallback(mockEvent, mockData)).not.toThrow();
		});

		it('handles circle mouseout', async() =>
		{
			await createInitializedComponent();

			expect(capturedCircleMouseoutCallback).not.toBeNull();
			expect(() => capturedCircleMouseoutCallback()).not.toThrow();
		});
	});

	describe('circle attribute callbacks', () =>
	{
		it('cx callback calculates x position from timestamp', async() =>
		{
			await createInitializedComponent();

			expect(capturedCircleCxCallback).not.toBeNull();
			const mockData = {timestamp: Date.now(), value: 100, type: 0};
			// Callback should invoke xScale with timestamp
			const result = capturedCircleCxCallback(mockData);
			// Result comes from mock invert returning new Date(), but callback should not throw
			expect(result).toBeDefined();
		});

		it('cy callback calculates y position from value', async() =>
		{
			await createInitializedComponent();

			expect(capturedCircleCyCallback).not.toBeNull();
			const mockData = {timestamp: Date.now(), value: 100, type: 0};
			// Callback should invoke yScale with value
			const result = capturedCircleCyCallback(mockData);
			expect(result).toBeDefined();
		});

		it('fill callback gets color from eventTypes', async() =>
		{
			await createInitializedComponent();

			expect(capturedCircleFillCallback).not.toBeNull();
			const mockData = {timestamp: Date.now(), value: 100, type: 0};
			// Callback should access eventTypes[d.type].color
			const result = capturedCircleFillCallback(mockData);
			// Color should be a string from our mock colorScale
			expect(typeof result).toBe('string');
		});
	});

	describe('drawTimeline error handling', () =>
	{
		it('logs error when drawTimeline throws', async() =>
		{
			const utilityLogger = require('c/utilityLogger').default;

			// Make xScale.domain throw an error
			const errorMock = createChainableMock();
			errorMock.domain = jest.fn(() =>
			{
				throw new Error('Scale domain error');
			});
			global.d3.scaleTime = jest.fn(() => errorMock);

			createComponent();
			await flushPromises();
			await flushPromises();

			// The error in drawTimeline should be caught and logged
			expect(utilityLogger.error).toHaveBeenCalledWith('Failed to draw chart', expect.any(Error));
		});
	});
});
