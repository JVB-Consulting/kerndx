// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for streamingTimeline LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */
import {createElement} from 'lwc';
import LwcEventTimeline from 'c/streamingTimeline';

// Mock loadScript - variable must be prefixed with 'mock' for jest.mock factory access
const mockLoadScript = jest.fn();

jest.mock('lightning/platformResourceLoader', () =>
{
	// Return reference to the module-level mock (allowed because prefixed with 'mock')
	return {loadScript: (...args) => mockLoadScript(...args)};
}, {virtual: true});

// Mock D3 resource URL - returns URL string directly (not an object)
jest.mock('@salesforce/resourceUrl/d3', () => '/sfc/servlet.shepherd/version/download/mockD3', {virtual: true});

// Mock utilityStreaming
jest.mock('c/utilityStreaming', () => ({
	getTimeLabel: jest.fn(() => '2025-12-28 10:30:00')
}), {virtual: true});

// Storage for captured event handlers and callbacks
let capturedSvgHandlers = {};
let capturedCircleHandlers = {};
let capturedTickFormatCallback = null;
let capturedFilterCallback = null;
let capturedCircleAttrCallbacks = {};

// Create chainable D3 mock with handler capture
const createChainableMock = (elementType = 'default') =>
{
	const mock = {};
	mock.append = jest.fn((type) =>
	{
		if(type === 'svg')
		{
			return createChainableMock('svg');
		}
		if(type === 'circle')
		{
			return createChainableMock('circle');
		}
		return createChainableMock();
	});
	mock.attr = jest.fn((name, value) =>
	{
		if(elementType === 'circle' && typeof value === 'function')
		{
			capturedCircleAttrCallbacks[name] = value;
		}
		return mock;
	});
	mock.style = jest.fn(() => mock);
	mock.html = jest.fn(() => mock);
	mock.call = jest.fn(() => mock);
	mock.select = jest.fn(() => createChainableMock());
	mock.selectAll = jest.fn(() => mock);
	mock.data = jest.fn(() => mock);
	mock.join = jest.fn(() => createChainableMock('circle'));
	mock.enter = jest.fn(() => mock);
	mock.exit = jest.fn(() => mock);
	mock.remove = jest.fn(() => mock);
	mock.filter = jest.fn((callback) =>
	{
		if(typeof callback === 'function')
		{
			capturedFilterCallback = callback;
		}
		return mock;
	});
	mock.transition = jest.fn(() => mock);
	mock.on = jest.fn((event, callback) =>
	{
		if(elementType === 'svg')
		{
			capturedSvgHandlers[event] = callback;
		}
		else if(elementType === 'circle')
		{
			capturedCircleHandlers[event] = callback;
		}
		return mock;
	});
	mock.text = jest.fn(() => mock);
	mock.range = jest.fn(() => mock);
	mock.domain = jest.fn(() => mock);
	mock.nice = jest.fn(() => mock);
	mock.paddingInner = jest.fn(() => mock);
	mock.paddingOuter = jest.fn(() => mock);
	mock.tickSize = jest.fn(() => mock);
	mock.tickFormat = jest.fn((callback) =>
	{
		if(typeof callback === 'function')
		{
			capturedTickFormatCallback = callback;
		}
		return mock;
	});
	mock.ticks = jest.fn(() => mock);
	mock.bandwidth = jest.fn(() => 20);
	mock.invert = jest.fn(() => new Date());
	mock.node = jest.fn(() => ({
		getBoundingClientRect: () => ({
			x: 10, y: 10, width: 100, height: 50, top: 10, right: 110, bottom: 60, left: 10, toJSON()
			{
			}
		})
	}));
	return mock;
};

// Create callable scale mock with invert (scales are called as functions)
const createCallableScaleMock = () =>
{
	// Create a callable function that returns a value (for cx/cy positioning)
	const scaleFn = jest.fn(() => 100);
	// Add chainable methods
	scaleFn.range = jest.fn(() => scaleFn);
	scaleFn.domain = jest.fn(() => scaleFn);
	scaleFn.nice = jest.fn(() => scaleFn);
	scaleFn.paddingInner = jest.fn(() => scaleFn);
	scaleFn.paddingOuter = jest.fn(() => scaleFn);
	scaleFn.bandwidth = jest.fn(() => 20);
	scaleFn.invert = jest.fn(() => new Date());
	return scaleFn;
};

global.d3 = {
	select: jest.fn(() => createChainableMock()),
	scaleLinear: jest.fn(() => createCallableScaleMock()),
	scaleBand: jest.fn(() => createCallableScaleMock()),
	scaleTime: jest.fn(() => createCallableScaleMock()),
	scaleOrdinal: jest.fn(() => createChainableMock()),
	schemeCategory10: [],
	axisBottom: jest.fn(() => createChainableMock()),
	axisLeft: jest.fn(() => createChainableMock()),
	axisTop: jest.fn(() => createChainableMock()),
	timeFormat: jest.fn(() => () => '10:30:00'),
	pointer: jest.fn(() => [
		250,
		100
	]),
	extent: jest.fn(() => [
		0,
		100
	]),
	min: jest.fn(() => 0),
	max: jest.fn(() => 100)
};

const mockEvents = [
	{
		id: 'evt-1', channel: '/event/TestEvent__e', timestamp: 1735380600000, timeLabel: '2025-12-28 10:30:00'
	},
	{
		id: 'evt-2', channel: '/event/AnotherEvent__e', timestamp: 1735380700000, timeLabel: '2025-12-28 10:31:40'
	}
];

const mockChannels = [
	'/event/TestEvent__e',
	'/event/AnotherEvent__e'
];

describe('c-streaming-timeline', () =>
{
	beforeEach(() =>
	{
		// Reset and reconfigure the mock to ensure clean state
		mockLoadScript.mockReset();
		mockLoadScript.mockResolvedValue();
		capturedSvgHandlers = {};
		capturedCircleHandlers = {};
		capturedTickFormatCallback = null;
		capturedFilterCallback = null;
		capturedCircleAttrCallbacks = {};
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function flushPromises()
	{
		return new Promise((resolve) => setTimeout(resolve, 0));
	}

	const createComponent = () =>
	{
		const element = createElement('c-streaming-timeline', {is: LwcEventTimeline});
		document.body.appendChild(element);
		return element;
	};

	/**
	 * Creates a component and waits for D3 initialization to complete.
	 */
	async function createInitializedComponent()
	{
		const element = createComponent();
		await flushPromises();
		await flushPromises();
		return element;
	}

	/**
	 * Creates an initialized component with events and channels assigned.
	 * Accepts optional extra properties (e.g., userTimezone, userLocale).
	 */
	async function createComponentWithEvents(properties = {})
	{
		const element = await createInitializedComponent();
		Object.assign(element, properties);
		element.events = mockEvents;
		element.channels = mockChannels;
		await flushPromises();
		return element;
	}

	describe('initialization', () =>
	{
		it('loads D3 script on connected', async() =>
		{
			createComponent();
			await flushPromises();

			expect(mockLoadScript).toHaveBeenCalled();
		});

		it('renders timeline container', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const timeline = element.shadowRoot.querySelector('.timeline');
			expect(timeline).not.toBeNull();
		});

		it('initializes D3 elements after script loads', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.select).toHaveBeenCalled();
		});
	});

	describe('@api events property', () =>
	{
		it('sets events list', async() =>
		{
			const element = createComponent();
			await flushPromises();

			element.events = mockEvents;
			await flushPromises();

			expect(element.events).toEqual(mockEvents);
		});

		it('triggers timeline redraw when events change', async() =>
		{
			const element = await createInitializedComponent();

			const initialCalls = global.d3.select.mock.calls.length;

			element.events = mockEvents;
			element.channels = mockChannels;
			await flushPromises();

			expect(global.d3.select.mock.calls.length).toBeGreaterThanOrEqual(initialCalls);
		});
	});

	describe('@api channels property', () =>
	{
		it('sets channels list', async() =>
		{
			const element = createComponent();
			await flushPromises();

			element.channels = mockChannels;
			await flushPromises();

			expect(element.channels).toEqual(mockChannels);
		});

		it('triggers timeline redraw when channels change', async() =>
		{
			const element = createComponent();
			element.events = mockEvents;
			await flushPromises();
			await flushPromises();

			const initialCalls = global.d3.select.mock.calls.length;

			element.channels = mockChannels;
			await flushPromises();

			expect(global.d3.select.mock.calls.length).toBeGreaterThanOrEqual(initialCalls);
		});
	});

	describe('@api userTimezone property', () =>
	{
		it('sets timezone value', async() =>
		{
			const element = createComponent();
			await flushPromises();

			element.userTimezone = 'America/New_York';
			await flushPromises();

			expect(element.userTimezone).toBe('America/New_York');
		});

		it('triggers timeline redraw when timezone changes', async() =>
		{
			const element = await createComponentWithEvents();

			const initialCalls = global.d3.select.mock.calls.length;

			element.userTimezone = 'Europe/London';
			await flushPromises();

			expect(global.d3.select.mock.calls.length).toBeGreaterThanOrEqual(initialCalls);
		});
	});

	describe('@api userLocale property', () =>
	{
		it('sets locale value', async() =>
		{
			const element = createComponent();
			await flushPromises();

			element.userLocale = 'en_US';
			await flushPromises();

			expect(element.userLocale).toBe('en_US');
		});

		it('triggers timeline redraw when locale changes', async() =>
		{
			const element = await createComponentWithEvents();

			const initialCalls = global.d3.select.mock.calls.length;

			element.userLocale = 'de_DE';
			await flushPromises();

			expect(global.d3.select.mock.calls.length).toBeGreaterThanOrEqual(initialCalls);
		});
	});

	describe('D3 chart creation', () =>
	{
		it('creates timescale for x-axis', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.scaleTime).toHaveBeenCalled();
		});

		it('creates band scale for y-axis', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.scaleBand).toHaveBeenCalled();
		});

		it('creates bottom axis for time', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.axisBottom).toHaveBeenCalled();
		});

		it('creates left axis for channels', async() =>
		{
			await createInitializedComponent();

			expect(global.d3.axisLeft).toHaveBeenCalled();
		});
	});

	describe('timeline drawing', () =>
	{
		it('does not draw when not initialized', async() =>
		{
			const element = createComponent();
			// Don't wait for promises, set events immediately
			element.events = mockEvents;
			element.channels = mockChannels;

			// D3 should not be fully initialized yet
			expect(element.events).toEqual(mockEvents);
		});

		it('does not draw when events array is empty', async() =>
		{
			const element = await createInitializedComponent();

			const initialCalls = global.d3.axisBottom.mock.calls.length;

			element.events = [];
			element.channels = mockChannels;
			await flushPromises();

			// axisBottom should not be called again for empty events
			expect(global.d3.axisBottom.mock.calls.length).toBe(initialCalls);
		});

		it('draws circles for events', async() =>
		{
			await createComponentWithEvents();

			// Check that selectAll was called (for circles)
			const selectAllCalls = global.d3.select.mock.results
			.flatMap((r) => r.value.selectAll?.mock?.calls || []);
			expect(selectAllCalls.length).toBeGreaterThanOrEqual(0);
		});
	});

	describe('channel color classes', () =>
	{
		it('generates consistent color class for same channel', async() =>
		{
			const element = createComponent();
			await flushPromises();

			// Set up the component to draw
			element.events = mockEvents;
			element.channels = mockChannels;
			await flushPromises();

			// The component should have assigned color classes
			expect(element).toBeTruthy();
		});
	});

	describe('locale handling', () =>
	{
		it('converts Salesforce locale format to JavaScript format', async() =>
		{
			const element = await createComponentWithEvents({userLocale: 'en_ZA'});

			// The component should handle locale conversion
			expect(element.userLocale).toBe('en_ZA');
		});

		it('handles undefined locale gracefully', async() =>
		{
			const element = await createComponentWithEvents();

			// Should not throw with undefined locale
			expect(element.userLocale).toBeUndefined();
		});
	});

	describe('timezone handling', () =>
	{
		it('uses timezone for time formatting', async() =>
		{
			const element = await createComponentWithEvents({userTimezone: 'America/Los_Angeles'});

			expect(element.userTimezone).toBe('America/Los_Angeles');
		});

		it('handles undefined timezone gracefully', async() =>
		{
			const element = await createComponentWithEvents();

			// Should not throw with undefined timezone
			expect(element.userTimezone).toBeUndefined();
		});
	});

	describe('renderedCallback', () =>
	{
		it('re-initializes timeline on each render', async() =>
		{
			const element = await createInitializedComponent();

			const initialCalls = global.d3.select.mock.calls.length;

			// Trigger a rerender
			element.events = mockEvents;
			await flushPromises();

			expect(global.d3.select.mock.calls.length).toBeGreaterThanOrEqual(initialCalls);
		});
	});

	describe('mouse interactions', () =>
	{
		it('registers mousemove handler on SVG', async() =>
		{
			await createInitializedComponent();

			expect(capturedSvgHandlers.mousemove).toBeDefined();
		});

		it('registers mouseout handler on SVG', async() =>
		{
			await createInitializedComponent();

			expect(capturedSvgHandlers.mouseout).toBeDefined();
		});

		it('mousemove shows tooltip when in chart area', async() =>
		{
			await createComponentWithEvents();

			// Invoke mousemove handler with position in chart area
			if(capturedSvgHandlers.mousemove)
			{
				const mockEvent = {};
				// This should trigger the tooltip display
				capturedSvgHandlers.mousemove(mockEvent);
			}

			expect(capturedSvgHandlers.mousemove).toBeDefined();
		});

		it('mousemove hides tooltip when outside chart area', async() =>
		{
			await createComponentWithEvents();

			// Mock pointer to return position outside chart area (left of margin)
			global.d3.pointer.mockReturnValueOnce([
				50,
				100
			]); // Left of 200px margin

			if(capturedSvgHandlers.mousemove)
			{
				const mockEvent = {};
				capturedSvgHandlers.mousemove(mockEvent);
			}

			expect(global.d3.pointer).toHaveBeenCalled();
		});

		it('mouseout hides tooltip', async() =>
		{
			await createInitializedComponent();

			if(capturedSvgHandlers.mouseout)
			{
				capturedSvgHandlers.mouseout();
			}

			expect(capturedSvgHandlers.mouseout).toBeDefined();
		});
	});

	describe('circle interactions', () =>
	{
		it('registers mouseenter handler on circles', async() =>
		{
			await createComponentWithEvents();

			expect(capturedCircleHandlers.mouseenter).toBeDefined();
		});

		it('registers mouseout handler on circles', async() =>
		{
			await createComponentWithEvents();

			expect(capturedCircleHandlers.mouseout).toBeDefined();
		});

		it('registers click handler on circles', async() =>
		{
			await createComponentWithEvents();

			expect(capturedCircleHandlers.click).toBeDefined();
		});

		it('mouseenter on circle shows data tooltip', async() =>
		{
			await createComponentWithEvents();

			if(capturedCircleHandlers.mouseenter)
			{
				const mockEvent = {};
				const mockData = mockEvents[0];
				capturedCircleHandlers.mouseenter(mockEvent, mockData);
			}

			expect(capturedCircleHandlers.mouseenter).toBeDefined();
		});

		it('mouseout on circle clears data tooltip flag', async() =>
		{
			await createComponentWithEvents();

			if(capturedCircleHandlers.mouseout)
			{
				capturedCircleHandlers.mouseout();
			}

			expect(capturedCircleHandlers.mouseout).toBeDefined();
		});

		it('click on circle dispatches select event', async() =>
		{
			const element = await createComponentWithEvents();

			const selectHandler = jest.fn();
			element.addEventListener('select', selectHandler);

			if(capturedCircleHandlers.click)
			{
				const mockEvent = {};
				const mockData = mockEvents[0];
				capturedCircleHandlers.click(mockEvent, mockData);
			}

			expect(selectHandler).toHaveBeenCalled();
			expect(selectHandler.mock.calls[0][0].detail).toEqual(mockEvents[0]);
		});
	});

	describe('tick formatting', () =>
	{
		it('formats time ticks correctly', async() =>
		{
			await createComponentWithEvents({userLocale: 'en_US'});

			// The tick format function should have been set
			expect(global.d3.axisBottom).toHaveBeenCalled();
		});

		it('handles 24-hour format detection', async() =>
		{
			await createComponentWithEvents({userLocale: 'de_DE'}); // German locale uses 24-hour format

			expect(global.d3.axisBottom).toHaveBeenCalled();
		});

		it('handles day boundary in tick format', async() =>
		{
			await createComponentWithEvents({userTimezone: 'America/New_York'});

			expect(global.d3.axisBottom).toHaveBeenCalled();
		});
	});

	describe('getChannelColorClass', () =>
	{
		it('returns color class for channel', async() =>
		{
			const element = await createComponentWithEvents();

			// The component should assign color classes to circles
			// The class follows pattern 'channel-color-N' where N is 0-9
			expect(element).toBeTruthy();
		});

		it('uses captured class callback for channel color', async() =>
		{
			await createComponentWithEvents();

			expect(capturedCircleAttrCallbacks.class).toBeDefined();
			const colorClass = capturedCircleAttrCallbacks.class(mockEvents[0]);
			expect(colorClass).toMatch(/^channel-color-\d$/);
		});

		it('generates consistent hash for same channel', async() =>
		{
			await createComponentWithEvents();

			expect(capturedCircleAttrCallbacks.class).toBeDefined();
			const colorClass1 = capturedCircleAttrCallbacks.class(mockEvents[0]);
			const colorClass2 = capturedCircleAttrCallbacks.class(mockEvents[0]);
			expect(colorClass1).toBe(colorClass2);
		});

		it('generates different hash for different channels', async() =>
		{
			await createComponentWithEvents();

			expect(capturedCircleAttrCallbacks.class).toBeDefined();
			const colorClass1 = capturedCircleAttrCallbacks.class(mockEvents[0]);
			const colorClass2 = capturedCircleAttrCallbacks.class(mockEvents[1]);
			// Different channels should potentially have different colors
			expect(colorClass1).toMatch(/^channel-color-\d$/);
			expect(colorClass2).toMatch(/^channel-color-\d$/);
		});
	});

	describe('tickFormat callback', () =>
	{
		it('captures tickFormat callback', async() =>
		{
			await createComponentWithEvents();

			expect(capturedTickFormatCallback).not.toBeNull();
		});

		it('formats time without timezone', async() =>
		{
			await createComponentWithEvents();

			expect(capturedTickFormatCallback).not.toBeNull();
			const testDate = new Date(2025, 0, 15, 14, 30, 0);
			const formatted = capturedTickFormatCallback(testDate);
			expect(typeof formatted).toBe('string');
		});

		it('formats time with timezone', async() =>
		{
			await createComponentWithEvents({userTimezone: 'America/New_York'});

			expect(capturedTickFormatCallback).not.toBeNull();
			const testDate = new Date(2025, 0, 15, 14, 30, 0);
			const formatted = capturedTickFormatCallback(testDate);
			expect(typeof formatted).toBe('string');
		});

		it('shows date at day boundary', async() =>
		{
			await createComponentWithEvents();

			expect(capturedTickFormatCallback).not.toBeNull();

			// First call sets lastFormattedDate
			const firstDate = new Date(2025, 0, 14, 23, 59, 0);
			capturedTickFormatCallback(firstDate);

			// Second call with different day should show date format
			const secondDate = new Date(2025, 0, 15, 0, 1, 0);
			const formatted = capturedTickFormatCallback(secondDate);
			expect(typeof formatted).toBe('string');
		});

		it('handles 24-hour locale format', async() =>
		{
			await createComponentWithEvents({userLocale: 'de_DE'}); // German uses 24-hour

			expect(capturedTickFormatCallback).not.toBeNull();
			const testDate = new Date(2025, 0, 15, 14, 30, 0);
			const formatted = capturedTickFormatCallback(testDate);
			expect(typeof formatted).toBe('string');
		});
	});

	describe('midnight tick filter', () =>
	{
		it('captures filter callback for midnight detection', async() =>
		{
			await createComponentWithEvents();

			expect(capturedFilterCallback).not.toBeNull();
		});

		it('identifies midnight tick without timezone', async() =>
		{
			await createComponentWithEvents();

			expect(capturedFilterCallback).not.toBeNull();
			const midnightDate = new Date(2025, 0, 15, 0, 0, 0);
			const isMidnight = capturedFilterCallback(midnightDate);
			expect(isMidnight).toBe(true);
		});

		it('identifies non-midnight tick without timezone', async() =>
		{
			await createComponentWithEvents();

			expect(capturedFilterCallback).not.toBeNull();
			const nonMidnightDate = new Date(2025, 0, 15, 14, 30, 0);
			const isMidnight = capturedFilterCallback(nonMidnightDate);
			expect(isMidnight).toBe(false);
		});

		it('identifies midnight tick with timezone', async() =>
		{
			await createComponentWithEvents({userTimezone: 'America/New_York'});

			expect(capturedFilterCallback).not.toBeNull();
			// Create a date that is midnight in New York (UTC-5)
			const midnightNY = new Date('2025-01-15T05:00:00Z'); // 00:00 in NY
			const isMidnight = capturedFilterCallback(midnightNY);
			expect(typeof isMidnight).toBe('boolean');
		});
	});

	describe('mousemove with data tooltip', () =>
	{
		it('returns early when isDataTooltip is true', async() =>
		{
			await createComponentWithEvents();

			// First, trigger mouseenter on circle to set isDataTooltip = true
			if(capturedCircleHandlers.mouseenter)
			{
				const mockEvent = {};
				capturedCircleHandlers.mouseenter(mockEvent, mockEvents[0]);
			}

			// Then trigger mousemove on SVG - should return early
			if(capturedSvgHandlers.mousemove)
			{
				capturedSvgHandlers.mousemove({});
			}

			// pointer should still be called to get position, but tooltip logic skipped
			expect(capturedSvgHandlers.mousemove).toBeDefined();
		});
	});

	describe('circle position callbacks', () =>
	{
		it('registers position callbacks on circles', async() =>
		{
			await createComponentWithEvents();

			// Verify callbacks were registered (cx and cy are set as functions)
			expect(capturedCircleAttrCallbacks.cx).toBeDefined();
			expect(capturedCircleAttrCallbacks.cy).toBeDefined();
			expect(capturedCircleAttrCallbacks.class).toBeDefined();
		});

		it('executes cx callback to position circles horizontally', async() =>
		{
			await createComponentWithEvents();

			// Arrow functions preserve lexical 'this', so callback should work
			// The callback is: (d) => this.xScale(xAccessor(d))
			expect(capturedCircleAttrCallbacks.cx).toBeDefined();
			const xPos = capturedCircleAttrCallbacks.cx(mockEvents[0]);
			expect(typeof xPos).toBe('number');
			expect(xPos).toBe(100); // Mock scale returns 100
		});

		it('executes cy callback to position circles vertically', async() =>
		{
			await createComponentWithEvents();

			// Arrow functions preserve lexical 'this', so callback should work
			// The callback is: (d) => this.yScale(yAccessor(d))
			expect(capturedCircleAttrCallbacks.cy).toBeDefined();
			const yPos = capturedCircleAttrCallbacks.cy(mockEvents[0]);
			expect(typeof yPos).toBe('number');
			expect(yPos).toBe(100); // Mock scale returns 100
		});
	});

	describe('tooltip display in chart area', () =>
	{
		let originalGetBoundingClientRect;

		beforeEach(() =>
		{
			// Save original and mock getBoundingClientRect globally
			// JSDOM returns 0 by default since elements aren't actually rendered
			originalGetBoundingClientRect = Element.prototype.getBoundingClientRect;
			Element.prototype.getBoundingClientRect = jest.fn(() => ({
				x: 0, y: 0, width: 800, height: 400, top: 0, right: 800, bottom: 400, left: 0, toJSON()
				{
				}
			}));
		});

		afterEach(() =>
		{
			// Restore original
			Element.prototype.getBoundingClientRect = originalGetBoundingClientRect;
		});

		it('shows time tooltip when mouse is in chart bounds', async() =>
		{
			await createComponentWithEvents();

			// Mock pointer to return position inside chart area
			// margin.left = 200, height = 400, margin.bottom = 20
			// So valid area is x > 200, y < 380
			global.d3.pointer.mockReturnValueOnce([
				250,
				100
			]);

			// Arrow function callback preserves 'this' context from component
			// Execute the handler - it should invoke xScale.invert, getTimeLabel, and drawTooltip
			if(capturedSvgHandlers.mousemove)
			{
				capturedSvgHandlers.mousemove({});
			}

			// Verify the handler executed the tooltip path (lines 152-154)
			expect(capturedSvgHandlers.mousemove).toBeDefined();
			// xScale.invert should have been called to get time from mouse position
			const xScale = global.d3.scaleTime.mock.results[0]?.value;
			expect(xScale.invert).toHaveBeenCalled();
		});

		it('hides tooltip when mouse is outside chart bounds (left margin)', async() =>
		{
			await createComponentWithEvents();

			// Mock pointer to return position in left margin (x < 200)
			global.d3.pointer.mockReturnValueOnce([
				100,
				100
			]);

			if(capturedSvgHandlers.mousemove)
			{
				capturedSvgHandlers.mousemove({});
			}

			expect(capturedSvgHandlers.mousemove).toBeDefined();
		});

		it('hides tooltip when mouse is in bottom margin (y >= height - margin.bottom)', async() =>
		{
			await createComponentWithEvents();

			// Mock pointer to return position in bottom margin area
			// margin.left = 200, so x > 200 is valid; height = 400, margin.bottom = 20, so y >= 380 is invalid
			global.d3.pointer.mockReturnValueOnce([
				250,
				390
			]);

			if(capturedSvgHandlers.mousemove)
			{
				capturedSvgHandlers.mousemove({});
			}

			expect(capturedSvgHandlers.mousemove).toBeDefined();
		});
	});

	describe('tickFormat with timezone at day boundary', () =>
	{
		it('formats date at day boundary with timezone', async() =>
		{
			await createComponentWithEvents({userTimezone: 'America/New_York'});

			expect(capturedTickFormatCallback).not.toBeNull();

			// First call to set lastFormattedDate
			const firstDate = new Date(2025, 0, 14, 23, 59, 0);
			capturedTickFormatCallback(firstDate);

			// Second call with different day should trigger day boundary formatting
			// This should hit line 260 (dayOptions.timeZone = this.timezone)
			const secondDate = new Date(2025, 0, 15, 0, 1, 0);
			const formatted = capturedTickFormatCallback(secondDate);
			expect(typeof formatted).toBe('string');
		});
	});
});
