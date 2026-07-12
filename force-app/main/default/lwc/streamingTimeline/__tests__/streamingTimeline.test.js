// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for the streamingTimeline LWC component (native template SVG).
 * DOM-first: geometry is asserted on rendered circle/text attributes computed by the real
 * c/utilityStreaming band layout, interactions through real MouseEvents, and the `select`
 * contract through a real circle click. No D3, no loadScript, no chainable mocks.
 * @author Jason van Beukering
 * @date December 2025, May 2026, July 2026
 */
import {createElement} from 'lwc';
import LwcEventTimeline from 'c/streamingTimeline';
import CLICK_FOR_DETAILS from '@salesforce/label/c.EventTimeline_Tooltip_ClickForDetails';
import {getTimeLabel} from 'c/utilityStreaming';

// Chart geometry constants mirrored from the component (independent oracle for the assertions).
const CHART_WIDTH = 1000;
const CHART_HEIGHT = 400;
const MARGIN_LEFT = 200;
const MARGIN_BOTTOM = 20;
const INNER_WIDTH = CHART_WIDTH - MARGIN_LEFT;
const BASELINE_Y = CHART_HEIGHT - MARGIN_BOTTOM;

// Two events 1,000 seconds apart: domain = [start - 10%, end + 10%] of the 1,000,000 ms span.
const EVENT_ONE_TIMESTAMP = 1000000;
const EVENT_TWO_TIMESTAMP = 2000000;
const mockEvents = [
	{
		id: 'evt-1', channel: '/event/TestEvent__e', timestamp: EVENT_ONE_TIMESTAMP, timeLabel: '1970-01-01 00:16:40', payload: '{"a":1}'
	},
	{
		id: 'evt-2', channel: '/event/AnotherEvent__e', timestamp: EVENT_TWO_TIMESTAMP, timeLabel: '1970-01-01 00:33:20', payload: '{"b":2}'
	}
];
const mockChannels = [
	'/event/TestEvent__e',
	'/event/AnotherEvent__e'
];

let resizeObserverCallback;

class ResizeObserverStub
{
	constructor(callback)
	{
		resizeObserverCallback = callback;
	}

	observe()
	{
	}

	disconnect()
	{
	}
}

describe('c-streaming-timeline', () =>
{
	beforeEach(() =>
	{
		resizeObserverCallback = undefined;
		global.ResizeObserver = ResizeObserverStub;
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		delete global.ResizeObserver;
		jest.clearAllMocks();
	});

	function flushPromises()
	{
		return new Promise((resolve) => setTimeout(resolve, 0));
	}

	async function createComponent({events = mockEvents, channels = mockChannels, userTimezone, userLocale} = {})
	{
		const element = createElement('c-streaming-timeline', {is: LwcEventTimeline});
		element.events = events;
		element.channels = channels;
		element.userTimezone = userTimezone;
		element.userLocale = userLocale;
		document.body.appendChild(element);
		await flushPromises();
		stubHostRect(element);
		return element;
	}

	// jsdom performs no layout, so the chart host reports a zero rect; pinning it at the viewport
	// origin at the chart's natural size makes clientX/clientY map 1:1 onto SVG coordinates.
	function stubHostRect(element)
	{
		const host = element.shadowRoot.querySelector('.timeline');
		host.getBoundingClientRect = () => ({
			x: 0, y: 0, top: 0, left: 0, right: CHART_WIDTH, bottom: CHART_HEIGHT, width: CHART_WIDTH, height: CHART_HEIGHT, toJSON()
			{
			}
		});
	}

	function chart(element)
	{
		return element.shadowRoot.querySelector('[data-spec-id="timeline-chart"]');
	}

	function circles(element)
	{
		return [...element.shadowRoot.querySelectorAll('[data-testid="timeline-dot"]')];
	}

	function tooltip(element)
	{
		return element.shadowRoot.querySelector('[data-spec-id="timeline-tooltip"]');
	}

	function tooltipLines(element)
	{
		return [...tooltip(element).querySelectorAll('div')].map((line) => line.textContent);
	}

	function xTickTexts(element)
	{
		return [...element.shadowRoot.querySelectorAll('svg text')].filter((text) => text.getAttribute('text-anchor') === 'middle');
	}

	function mouseMoveOnChart(element, clientX, clientY)
	{
		chart(element).dispatchEvent(new MouseEvent('mousemove', {clientX, clientY, bubbles: true}));
	}

	// ── Rendering ────────────────────────────────────────────────────────

	describe('rendering', () =>
	{
		it('renders the chart SVG with the default viewBox once events arrive', async() =>
		{
			const element = await createComponent();

			expect(chart(element)).not.toBeNull();
			expect(chart(element).getAttribute('viewBox')).toBe(`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`);
		});

		it('renders no chart content when the events list is empty', async() =>
		{
			const element = await createComponent({events: []});

			expect(chart(element)).toBeNull();
		});

		it('renders no chart content when events becomes undefined', async() =>
		{
			const element = await createComponent();
			element.events = undefined;
			await flushPromises();

			expect(chart(element)).toBeNull();
		});

		it('renders one circle per event with radius 10', async() =>
		{
			const element = await createComponent();
			const dots = circles(element);

			expect(dots).toHaveLength(2);
			dots.forEach((dot) => expect(dot.getAttribute('r')).toBe('10'));
		});

		it('renders the x-axis baseline across the chart width', async() =>
		{
			const element = await createComponent();
			const baseline = element.shadowRoot.querySelector('.axis-baseline');

			expect(baseline.getAttribute('x1')).toBe(String(MARGIN_LEFT));
			expect(baseline.getAttribute('x2')).toBe(String(CHART_WIDTH));
			expect(baseline.getAttribute('y1')).toBe(String(BASELINE_Y));
		});

		it('renders a y-axis label per channel at the band position', async() =>
		{
			const element = await createComponent();
			const labels = [...element.shadowRoot.querySelectorAll('text.axis-label')].filter((text) => text.getAttribute('text-anchor') === 'end');

			// Band layout for 2 channels over [0, 380] with padding 1: positions at 126.7 and 253.3.
			expect(labels).toHaveLength(2);
			expect(labels[0].textContent).toBe(mockChannels[0]);
			expect(Number(labels[0].getAttribute('y'))).toBeCloseTo(126.7 + 4, 1);
			expect(Number(labels[1].getAttribute('y'))).toBeCloseTo(253.3 + 4, 1);
		});
	});

	// ── Geometry ─────────────────────────────────────────────────────────

	describe('circle geometry', () =>
	{
		it('positions circles by timestamp interpolation with the 10% domain margin', async() =>
		{
			const element = await createComponent();
			const [first, second] = circles(element);

			// Domain: [900000, 2100000]. Event one sits at 100000/1200000 of the 800px inner width.
			expect(Number(first.getAttribute('cx'))).toBeCloseTo(MARGIN_LEFT + (100000 / 1200000) * INNER_WIDTH, 1);
			expect(Number(second.getAttribute('cx'))).toBeCloseTo(MARGIN_LEFT + (1100000 / 1200000) * INNER_WIDTH, 1);
		});

		it('positions circles vertically at their channel band', async() =>
		{
			const element = await createComponent();
			const [first, second] = circles(element);

			expect(Number(first.getAttribute('cy'))).toBeCloseTo(126.7, 1);
			expect(Number(second.getAttribute('cy'))).toBeCloseTo(253.3, 1);
		});

		it('renders a single event at the horizontal midpoint of the chart area', async() =>
		{
			const element = await createComponent({events: [mockEvents[0]], channels: mockChannels});
			const [only] = circles(element);

			expect(Number(only.getAttribute('cx'))).toBeCloseTo(MARGIN_LEFT + INNER_WIDTH / 2, 1);
		});

		it('anchors an event whose channel is not in the channel list at the top of the chart', async() =>
		{
			const element = await createComponent({events: [{...mockEvents[0], channel: '/event/Unknown__e'}], channels: mockChannels});
			const [only] = circles(element);

			expect(only.getAttribute('cy')).toBe('0');
		});

		it('renders an event without an id using its index as the iteration key', async() =>
		{
			const anonymous = {...mockEvents[0]};
			delete anonymous.id;
			const element = await createComponent({events: [anonymous], channels: mockChannels});

			expect(circles(element)).toHaveLength(1);
		});

		it('renders dots at the chart top and no channel labels when channels is undefined', async() =>
		{
			const element = await createComponent();
			element.channels = undefined;
			await flushPromises();
			const labels = [...element.shadowRoot.querySelectorAll('text.axis-label')].filter((text) => text.getAttribute('text-anchor') === 'end');

			expect(circles(element)).toHaveLength(2);
			expect(circles(element)[0].getAttribute('cy')).toBe('0');
			expect(labels).toHaveLength(0);
		});
	});

	// ── Channel colors ───────────────────────────────────────────────────

	describe('channel color classes', () =>
	{
		it('assigns the same deterministic color class for the same channel', async() =>
		{
			const twin = {...mockEvents[1], id: 'evt-3', channel: mockEvents[0].channel};
			const element = await createComponent({
				events: [
					mockEvents[0],
					twin
				], channels: mockChannels
			});
			const dots = circles(element);

			expect(dots[0].getAttribute('class')).toMatch(/channel-color-\d/);
			expect(dots[0].getAttribute('class')).toBe(dots[1].getAttribute('class'));
		});

		it('assigns different classes to channels hashing to different palette slots', async() =>
		{
			const element = await createComponent();
			const dots = circles(element);

			expect(dots[0].getAttribute('class')).not.toBe(dots[1].getAttribute('class'));
		});
	});

	// ── @api reactivity ──────────────────────────────────────────────────

	describe('@api reactivity', () =>
	{
		it('re-renders circles when the events property changes', async() =>
		{
			const element = await createComponent();
			element.events = [mockEvents[0]];
			await flushPromises();

			expect(circles(element)).toHaveLength(1);
		});

		it('re-renders band positions when the channels property changes', async() =>
		{
			const element = await createComponent();
			element.channels = [mockChannels[0]];
			await flushPromises();

			// One channel over [0, 380] with padding 1: single lane at 190.
			expect(Number(circles(element)[0].getAttribute('cy'))).toBeCloseTo(190, 1);
		});

		it('re-formats tick labels when the locale property changes', async() =>
		{
			const element = await createComponent({userTimezone: 'UTC', userLocale: 'en_US'});
			const twelveHourLabel = xTickTexts(element)[0].textContent;
			element.userLocale = 'en_ZA';
			await flushPromises();

			expect(twelveHourLabel).toMatch(/AM|PM/);
			expect(xTickTexts(element)[0].textContent).not.toMatch(/AM|PM/);
		});
	});

	// ── Tick generation & formatting ─────────────────────────────────────

	describe('tick formatting', () =>
	{
		it('renders step-aligned time ticks across the domain', async() =>
		{
			const element = await createComponent({userTimezone: 'UTC', userLocale: 'en_US'});
			const ticks = xTickTexts(element);

			// Span 1,200,000 ms resolves to the 5-minute ladder step: 900000..2100000 = 5 ticks.
			expect(ticks).toHaveLength(5);
			expect(ticks[0].textContent).toBe('12:15 AM');
		});

		it('renders 24-hour tick labels for a 24-hour locale', async() =>
		{
			const element = await createComponent({userTimezone: 'UTC', userLocale: 'en_ZA'});

			expect(xTickTexts(element)[0].textContent).toBe('00:15');
		});

		it('formats ticks in the requested timezone', async() =>
		{
			const element = await createComponent({userTimezone: 'Asia/Kolkata', userLocale: 'en_ZA'});

			// 900000 ms UTC is 06:00 + 15 min in Asia/Kolkata (UTC+5:30).
			expect(xTickTexts(element)[0].textContent).toBe('05:45');
		});

		it('switches a day-boundary tick to the short-date form and marks it major', async() =>
		{
			const dayBoundary = 86400000;
			const element = await createComponent({
				events: [
					{...mockEvents[0], timestamp: dayBoundary - 600000},
					{...mockEvents[1], timestamp: dayBoundary + 600000}
				], userTimezone: 'UTC', userLocale: 'en_US'
			});
			const ticks = xTickTexts(element);
			const majorTick = ticks.find((tick) => tick.getAttribute('class').includes('major-tick'));

			expect(majorTick.textContent).toBe('Jan 2');
		});

		it('marks a local-midnight tick as major when no timezone is set', async() =>
		{
			const localMidnight = new Date(1970, 0, 2, 0, 0, 0).getTime();
			const element = await createComponent({
				events: [
					{...mockEvents[0], timestamp: localMidnight - 600000},
					{...mockEvents[1], timestamp: localMidnight + 600000}
				], userLocale: 'en_US'
			});
			const majorTicks = xTickTexts(element).filter((tick) => tick.getAttribute('class').includes('major-tick'));

			expect(majorTicks).toHaveLength(1);
		});

		it('falls back to whole-day steps for a span beyond the tick ladder', async() =>
		{
			const fourHundredDays = 400 * 86400000;
			const element = await createComponent({
				events: [
					{...mockEvents[0], timestamp: 0},
					{...mockEvents[1], timestamp: fourHundredDays}
				], userTimezone: 'UTC', userLocale: 'en_US'
			});
			const ticks = xTickTexts(element);

			expect(ticks.length).toBeGreaterThanOrEqual(2);
			expect(ticks.length).toBeLessThanOrEqual(11);
		});

		it('renders a single midpoint tick for a zero-span domain', async() =>
		{
			const element = await createComponent({events: [mockEvents[0]], userTimezone: 'UTC', userLocale: 'en_US'});
			const ticks = xTickTexts(element);

			expect(ticks).toHaveLength(1);
			expect(Number(ticks[0].getAttribute('x'))).toBeCloseTo(MARGIN_LEFT + INNER_WIDTH / 2, 1);
		});
	});

	// ── Crosshair tooltip ────────────────────────────────────────────────

	describe('crosshair tooltip', () =>
	{
		it('shows the inverted time label when the pointer is inside the chart area', async() =>
		{
			const element = await createComponent({userTimezone: 'UTC', userLocale: 'en_US'});
			mouseMoveOnChart(element, 600, 100);
			await flushPromises();

			// x=600 inverts to 900000 + ((600-200)/800) * 1200000 = 1,500,000 ms.
			expect(tooltip(element)).not.toBeNull();
			expect(tooltip(element).getAttribute('class')).toBe('tooltip');
			expect(tooltipLines(element)).toEqual([getTimeLabel(1500000, 'UTC', 'en_US')]);
		});

		it('hides the tooltip when the pointer is left of the chart area', async() =>
		{
			const element = await createComponent();
			mouseMoveOnChart(element, 600, 100);
			await flushPromises();
			mouseMoveOnChart(element, 100, 100);
			await flushPromises();

			expect(tooltip(element)).toBeNull();
		});

		it('hides the tooltip when the pointer is below the baseline', async() =>
		{
			const element = await createComponent();
			mouseMoveOnChart(element, 600, 100);
			await flushPromises();
			mouseMoveOnChart(element, 600, 395);
			await flushPromises();

			expect(tooltip(element)).toBeNull();
		});

		it('hides the tooltip when the pointer leaves the chart host', async() =>
		{
			const element = await createComponent();
			mouseMoveOnChart(element, 600, 100);
			await flushPromises();
			element.shadowRoot.querySelector('.timeline').dispatchEvent(new MouseEvent('mouseleave'));
			await flushPromises();

			expect(tooltip(element)).toBeNull();
		});
	});

	// ── Data tooltip ─────────────────────────────────────────────────────

	describe('data tooltip', () =>
	{
		it('shows the event details on dot hover', async() =>
		{
			const element = await createComponent();
			circles(element)[0].dispatchEvent(new MouseEvent('mouseenter', {clientX: 300, clientY: 130, bubbles: true}));
			await flushPromises();

			expect(tooltip(element).getAttribute('class')).toBe('tooltip data');
			expect(tooltipLines(element)).toEqual([
				mockEvents[0].timeLabel,
				mockEvents[0].channel,
				'',
				CLICK_FOR_DETAILS
			]);
		});

		it('suppresses the crosshair tooltip while the data tooltip is showing', async() =>
		{
			const element = await createComponent();
			circles(element)[0].dispatchEvent(new MouseEvent('mouseenter', {clientX: 300, clientY: 130, bubbles: true}));
			await flushPromises();
			mouseMoveOnChart(element, 600, 100);
			await flushPromises();

			expect(tooltip(element).getAttribute('class')).toBe('tooltip data');
		});

		it('releases the crosshair suppression when the pointer leaves the dot', async() =>
		{
			const element = await createComponent();
			circles(element)[0].dispatchEvent(new MouseEvent('mouseenter', {clientX: 300, clientY: 130, bubbles: true}));
			await flushPromises();
			circles(element)[0].dispatchEvent(new MouseEvent('mouseleave', {bubbles: true}));
			await flushPromises();

			expect(tooltip(element)).toBeNull();

			mouseMoveOnChart(element, 600, 100);
			await flushPromises();

			expect(tooltip(element).getAttribute('class')).toBe('tooltip');
		});
	});

	// ── Selection ────────────────────────────────────────────────────────

	describe('select event', () =>
	{
		it('dispatches select with the raw event datum on dot click', async() =>
		{
			const element = await createComponent();
			const selectHandler = jest.fn();
			element.addEventListener('select', selectHandler);
			circles(element)[1].dispatchEvent(new MouseEvent('click', {bubbles: true}));
			await flushPromises();

			expect(selectHandler).toHaveBeenCalledTimes(1);
			expect(selectHandler.mock.calls[0][0].detail).toEqual(mockEvents[1]);
			expect(tooltip(element)).toBeNull();
		});
	});

	// ── Resize ───────────────────────────────────────────────────────────

	describe('resize', () =>
	{
		it('tracks the host width in the viewBox through the ResizeObserver', async() =>
		{
			const element = await createComponent();
			resizeObserverCallback([{contentRect: {width: 500}}]);
			await flushPromises();

			expect(chart(element).getAttribute('viewBox')).toBe(`0 0 500 ${CHART_HEIGHT}`);
		});

		it('ignores a zero-width resize entry', async() =>
		{
			const element = await createComponent();
			resizeObserverCallback([{contentRect: {width: 0}}]);
			await flushPromises();

			expect(chart(element).getAttribute('viewBox')).toBe(`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`);
		});

		it('ignores a resize callback without entries', async() =>
		{
			const element = await createComponent();
			resizeObserverCallback([]);
			await flushPromises();

			expect(chart(element).getAttribute('viewBox')).toBe(`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`);
		});

		it('renders without a ResizeObserver implementation', async() =>
		{
			delete global.ResizeObserver;
			const element = await createComponent();

			expect(chart(element)).not.toBeNull();
			expect(circles(element)).toHaveLength(2);
		});

		it('disconnects the observer when the component is removed', async() =>
		{
			const disconnectSpy = jest.spyOn(ResizeObserverStub.prototype, 'disconnect');
			const element = await createComponent();
			document.body.removeChild(element);

			expect(disconnectSpy).toHaveBeenCalled();
		});
	});
});
