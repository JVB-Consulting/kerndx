// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for the streamingUsageFilters LWC component — the Event Usage Metrics
 * filter controls: a granularity segmented control, date-range presets with a custom From/To range,
 * legend chips, and the enhanced-usage notice. Under sfdx-lwc-jest custom labels resolve to their id
 * strings, so assertions target `data-spec-id` hooks and dispatched events rather than display text.
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {createElement} from 'lwc';
import StreamingUsageFilters from 'c/streamingUsageFilters';
import VALIDATION_FROM_BEFORE_TO from '@salesforce/label/c.EventUsageMetrics_Validation_FromBeforeTo';
import VALIDATION_RANGE_TOO_NARROW from '@salesforce/label/c.EventUsageMetrics_Validation_RangeTooNarrow';
import VALIDATION_RANGE_TOO_WIDE from '@salesforce/label/c.EventUsageMetrics_Validation_RangeTooWide';

const MILLISECONDS_PER_HOUR = 60 * 60 * 1000;
const MILLISECONDS_PER_DAY = 24 * MILLISECONDS_PER_HOUR;

const EVENT_TYPES = [
	{index: 0, name: 'PLATFORM_EVENTS_PUBLISHED', label: 'Platform Events Published', color: '#0176D3', total: 42},
	{index: 1, name: 'CDC_EVENTS_PUBLISHED', label: 'Change Data Capture', color: '#2E844A', total: 17}
];

describe('streamingUsageFilters', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	/**
	 * @description Creates and inserts the component with sensible defaults.
	 * @param {Object} [overrides] - Optional `eventTypes` / `enhanced` overrides.
	 * @returns {Element} The inserted component element.
	 */
	function createFilters({eventTypes = EVENT_TYPES, enhanced = true} = {})
	{
		const element = createElement('c-streaming-usage-filters', {is: StreamingUsageFilters});
		element.eventTypes = eventTypes;
		element.isEnhancedUsageMetricEnabled = enhanced;
		document.body.appendChild(element);
		return element;
	}

	/**
	 * @description Finds the first descendant carrying the given data-spec-id.
	 * @param {Element} element - The host component.
	 * @param {string} id - The data-spec-id value.
	 * @returns {Element|null}
	 */
	function spec(element, id)
	{
		return element.shadowRoot.querySelector(`[data-spec-id="${id}"]`);
	}

	/**
	 * @description Finds every descendant carrying the given data-spec-id.
	 * @param {Element} element - The host component.
	 * @param {string} id - The data-spec-id value.
	 * @returns {NodeList}
	 */
	function specAll(element, id)
	{
		return element.shadowRoot.querySelectorAll(`[data-spec-id="${id}"]`);
	}

	/**
	 * @description Dispatches a `change` event carrying a `detail.value`, matching how
	 * lightning-combobox / lightning-input surface user input.
	 * @param {Element} node - The control to change.
	 * @param {string} value - The new value.
	 */
	function changeValue(node, value)
	{
		node.dispatchEvent(new CustomEvent('change', {detail: {value}}));
	}

	/**
	 * @description Returns the detail of the most recent call to a jest handler.
	 * @param {jest.Mock} handler - The event handler spy.
	 * @returns {Object}
	 */
	function lastDetail(handler)
	{
		return handler.mock.calls[handler.mock.calls.length - 1][0].detail;
	}

	it('renders Daily pressed, the 30-day preset, no custom inputs, no notice, and one pressed chip per event type', async() =>
	{
		const element = createFilters();
		await Promise.resolve();

		expect(spec(element, 'usage-granularity-daily').getAttribute('aria-pressed')).toBe('true');
		expect(spec(element, 'usage-granularity-hourly').getAttribute('aria-pressed')).toBe('false');
		expect(spec(element, 'usage-granularity-fifteen').getAttribute('aria-pressed')).toBe('false');

		expect(spec(element, 'usage-range-preset').value).toBe('P30D');

		expect(spec(element, 'usage-range-from')).toBeNull();
		expect(spec(element, 'usage-range-to')).toBeNull();
		expect(spec(element, 'usage-enhanced-notice')).toBeNull();

		const chips = specAll(element, 'usage-legend-chip');
		expect(chips.length).toBe(EVENT_TYPES.length);
		chips.forEach((chip) => expect(chip.getAttribute('aria-pressed')).toBe('true'));
	});

	it('dispatches searchfilterchange with a 24-hour range when Hourly is selected', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		spec(element, 'usage-granularity-hourly').click();
		await Promise.resolve();

		expect(searchHandler).toHaveBeenCalledTimes(1);
		const detail = lastDetail(searchHandler);
		expect(detail.timeSegment).toBe('Hourly');
		const spanMs = new Date(detail.endDate).getTime() - new Date(detail.startDate).getTime();
		expect(spanMs).toBe(24 * MILLISECONDS_PER_HOUR);
		expect(spec(element, 'usage-range-preset').value).toBe('P1D');
	});

	it('dispatches searchfilterchange with a 1-hour range and the LastHour preset when 15 minutes is selected', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		spec(element, 'usage-granularity-fifteen').click();
		await Promise.resolve();

		expect(searchHandler).toHaveBeenCalledTimes(1);
		const detail = lastDetail(searchHandler);
		expect(detail.timeSegment).toBe('FifteenMinutes');
		const spanMs = new Date(detail.endDate).getTime() - new Date(detail.startDate).getTime();
		expect(spanMs).toBe(MILLISECONDS_PER_HOUR);
		expect(spec(element, 'usage-range-preset').value).toBe('PT1H');
	});

	it('disables Hourly and 15-minute, shows the enhanced notice, and still emits for Daily when enhanced metrics are off', async() =>
	{
		const element = createFilters({enhanced: false});
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		expect(spec(element, 'usage-granularity-hourly').disabled).toBe(true);
		expect(spec(element, 'usage-granularity-fifteen').disabled).toBe(true);
		expect(spec(element, 'usage-enhanced-notice')).not.toBeNull();

		spec(element, 'usage-granularity-daily').click();
		await Promise.resolve();

		expect(searchHandler).toHaveBeenCalledTimes(1);
		const detail = lastDetail(searchHandler);
		expect(detail.timeSegment).toBe('Daily');
		const spanMs = new Date(detail.endDate).getTime() - new Date(detail.startDate).getTime();
		expect(spanMs).toBe(30 * MILLISECONDS_PER_DAY);
	});

	it('dispatches searchfilterchange with a 7-day range when the 7-day preset is chosen under Daily', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		changeValue(spec(element, 'usage-range-preset'), 'P7D');
		await Promise.resolve();

		expect(searchHandler).toHaveBeenCalledTimes(1);
		const detail = lastDetail(searchHandler);
		expect(detail.timeSegment).toBe('Daily');
		const spanMs = new Date(detail.endDate).getTime() - new Date(detail.startDate).getTime();
		expect(spanMs).toBe(7 * MILLISECONDS_PER_DAY);
	});

	it('reveals From/To for the custom preset and shows an inline error without emitting when From is not before To', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		changeValue(spec(element, 'usage-range-preset'), 'CUSTOM');
		await Promise.resolve();

		expect(spec(element, 'usage-range-from')).not.toBeNull();
		expect(spec(element, 'usage-range-to')).not.toBeNull();
		searchHandler.mockClear();

		// Seeded To is "now"; a From in the far future is never before it.
		changeValue(spec(element, 'usage-range-from'), '2099-01-01T00:00:00.000Z');
		await Promise.resolve();

		// Assert the specific From-before-To message so the test cannot pass via the wrong branch.
		expect(spec(element, 'usage-range-error').textContent).toBe(VALIDATION_FROM_BEFORE_TO);
		expect(searchHandler).not.toHaveBeenCalled();
	});

	it('dispatches searchfilterchange with the ISO custom range and clears the error when From/To are valid', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		changeValue(spec(element, 'usage-range-preset'), 'CUSTOM');
		await Promise.resolve();

		// Spans four-plus days: above the Daily one-bucket minimum, below the 30-day maximum.
		const fromIso = '2026-06-01T10:00:00.000Z';
		const toIso = '2026-06-05T12:00:00.000Z';
		changeValue(spec(element, 'usage-range-from'), fromIso);
		await Promise.resolve();
		changeValue(spec(element, 'usage-range-to'), toIso);
		await Promise.resolve();

		// The final (To) change must be the emit we assert on: endDate === toIso only holds if the
		// To-change actually dispatched, so a regression that stopped emitting there cannot pass.
		expect(searchHandler).toHaveBeenCalled();
		const detail = lastDetail(searchHandler);
		expect(detail.timeSegment).toBe('Daily');
		expect(detail.startDate).toBe(fromIso);
		expect(detail.endDate).toBe(toIso);
		expect(spec(element, 'usage-range-error')).toBeNull();
	});

	it('shows the range-too-wide error and does not emit when the custom span exceeds the 15-minute window', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		spec(element, 'usage-granularity-fifteen').click();
		await Promise.resolve();
		changeValue(spec(element, 'usage-range-preset'), 'CUSTOM');
		await Promise.resolve();
		searchHandler.mockClear();

		// Two-hour span (valid order, but exceeds the 1-hour FifteenMinutes maximum).
		changeValue(spec(element, 'usage-range-to'), '2026-06-05T12:00:00.000Z');
		await Promise.resolve();
		changeValue(spec(element, 'usage-range-from'), '2026-06-05T10:00:00.000Z');
		await Promise.resolve();

		// Assert the range-too-wide message specifically (the From-before-To label resolves to a
		// distinct id under sfdx-lwc-jest), so a regression in the span check cannot hide behind the
		// order check.
		const errorText = spec(element, 'usage-range-error').textContent;
		expect(errorText).toBe(VALIDATION_RANGE_TOO_WIDE);
		expect(errorText).not.toBe(VALIDATION_FROM_BEFORE_TO);
		expect(searchHandler).not.toHaveBeenCalled();
	});

	it('shows the range-too-narrow error and does not emit when the custom span is shorter than one hourly bucket', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		spec(element, 'usage-granularity-hourly').click();
		await Promise.resolve();
		changeValue(spec(element, 'usage-range-preset'), 'CUSTOM');
		await Promise.resolve();
		searchHandler.mockClear();

		// 51-minute span — valid order, inside the 24-hour maximum, but shorter than one hourly
		// bucket. The platform rejects such queries (live-verified TimeSegmentValueTooLargeException),
		// so the client must catch it inline instead of surfacing a generic server error.
		changeValue(spec(element, 'usage-range-to'), '2026-06-05T14:15:00.000Z');
		await Promise.resolve();
		changeValue(spec(element, 'usage-range-from'), '2026-06-05T13:24:00.000Z');
		await Promise.resolve();

		// Assert the range-too-narrow message specifically so a regression in the minimum check
		// cannot hide behind the order or maximum checks.
		const errorText = spec(element, 'usage-range-error').textContent;
		expect(errorText).toBe(VALIDATION_RANGE_TOO_NARROW);
		expect(errorText).not.toBe(VALIDATION_FROM_BEFORE_TO);
		expect(errorText).not.toBe(VALIDATION_RANGE_TOO_WIDE);
		expect(searchHandler).not.toHaveBeenCalled();
	});

	it('dispatches searchfilterchange when the custom span is exactly one bucket wide (inclusive minimum)', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		spec(element, 'usage-granularity-hourly').click();
		await Promise.resolve();
		changeValue(spec(element, 'usage-range-preset'), 'CUSTOM');
		await Promise.resolve();
		searchHandler.mockClear();

		// Exactly 60 minutes — the platform accepts a span equal to one bucket (live-verified), so
		// the inclusive boundary must pass validation and emit.
		changeValue(spec(element, 'usage-range-to'), '2026-06-05T14:24:00.000Z');
		await Promise.resolve();
		changeValue(spec(element, 'usage-range-from'), '2026-06-05T13:24:00.000Z');
		await Promise.resolve();

		expect(spec(element, 'usage-range-error')).toBeNull();
		expect(searchHandler).toHaveBeenCalled();
		const detail = lastDetail(searchHandler);
		expect(detail.startDate).toBe('2026-06-05T13:24:00.000Z');
		expect(detail.endDate).toBe('2026-06-05T14:24:00.000Z');
	});

	it('dispatches displayfilterchange with the toggled boolean array when a legend chip is clicked', async() =>
	{
		const element = createFilters();
		const displayHandler = jest.fn();
		element.addEventListener('displayfilterchange', displayHandler);
		await Promise.resolve();

		specAll(element, 'usage-legend-chip')[0].click();
		await Promise.resolve();

		expect(displayHandler).toHaveBeenCalledTimes(1);
		expect(lastDetail(displayHandler).visibleTypes).toEqual([
			false,
			true
		]);

		specAll(element, 'usage-legend-chip')[0].click();
		await Promise.resolve();

		expect(displayHandler).toHaveBeenCalledTimes(2);
		expect(lastDetail(displayHandler).visibleTypes).toEqual([
			true,
			true
		]);
	});

	it('discards the custom range and emits the snapped preset range when granularity changes while Custom is active', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		await Promise.resolve();

		changeValue(spec(element, 'usage-range-preset'), 'CUSTOM');
		await Promise.resolve();
		expect(spec(element, 'usage-range-from')).not.toBeNull();
		searchHandler.mockClear();

		spec(element, 'usage-granularity-hourly').click();
		await Promise.resolve();

		expect(spec(element, 'usage-range-from')).toBeNull();
		expect(spec(element, 'usage-range-to')).toBeNull();
		expect(spec(element, 'usage-range-preset').value).toBe('P1D');

		expect(searchHandler).toHaveBeenCalledTimes(1);
		const detail = lastDetail(searchHandler);
		expect(detail.timeSegment).toBe('Hourly');
		const spanMs = new Date(detail.endDate).getTime() - new Date(detail.startDate).getTime();
		expect(spanMs).toBe(24 * MILLISECONDS_PER_HOUR);
	});

	it('gates the offered presets to the current granularity window', async() =>
	{
		const element = createFilters();
		await Promise.resolve();

		const valuesOf = () => spec(element, 'usage-range-preset').options.map((option) => option.value);

		// Last Hour is excluded under Daily: a one-hour span is below the one-day platform minimum,
		// so offering it would hand the user a preset that is guaranteed to fail validation.
		expect(valuesOf()).toEqual([
			'P1D',
			'P7D',
			'P30D',
			'CUSTOM'
		]);

		spec(element, 'usage-granularity-hourly').click();
		await Promise.resolve();
		expect(valuesOf()).toEqual([
			'PT1H',
			'P1D',
			'CUSTOM'
		]);

		spec(element, 'usage-granularity-fifteen').click();
		await Promise.resolve();
		expect(valuesOf()).toEqual([
			'PT1H',
			'CUSTOM'
		]);
	});

	it('renders legend chips as buttons and granularity controls with aria-pressed for accessibility', async() =>
	{
		const element = createFilters();
		await Promise.resolve();

		specAll(element, 'usage-legend-chip').forEach((chip) =>
		{
			expect(chip.tagName).toBe('BUTTON');
			expect(chip.getAttribute('aria-pressed')).not.toBeNull();
		});

		[
			'usage-granularity-daily',
			'usage-granularity-hourly',
			'usage-granularity-fifteen'
		].forEach((id) =>
		{
			expect(spec(element, id).getAttribute('aria-pressed')).not.toBeNull();
		});
	});

	it('exposes event types through the getter and preserves chip visibility by series name when eventTypes is reassigned', async() =>
	{
		const element = createFilters();
		await Promise.resolve();

		// Hide the first series, then re-supply event types (a refetch) — the setter must keep the
		// hidden chip hidden instead of silently snapping every series back to visible.
		specAll(element, 'usage-legend-chip')[0].click();
		await Promise.resolve();
		expect(specAll(element, 'usage-legend-chip')[0].getAttribute('aria-pressed')).toBe('false');

		element.eventTypes = [...EVENT_TYPES];
		await Promise.resolve();

		expect(element.eventTypes).toEqual(EVENT_TYPES);
		expect([...specAll(element, 'usage-legend-chip')].map((chip) => chip.getAttribute('aria-pressed'))).toEqual([
			'false',
			'true'
		]);
	});

	it('defaults a series name it has not seen before to visible while keeping prior selections', async() =>
	{
		const element = createFilters();
		await Promise.resolve();

		specAll(element, 'usage-legend-chip')[0].click();
		await Promise.resolve();

		element.eventTypes = [
			EVENT_TYPES[0],
			EVENT_TYPES[1],
			{index: 2, name: 'STANDARD_VOLUME_EVENTS_PUBLISHED', label: 'Standard Volume Events Published', color: '#9050E9', total: 3}
		];
		await Promise.resolve();

		expect([...specAll(element, 'usage-legend-chip')].map((chip) => chip.getAttribute('aria-pressed'))).toEqual([
			'false',
			'true',
			'true'
		]);
	});

	it('drops the remembered state of a vanished series so it returns visible', async() =>
	{
		const element = createFilters();
		await Promise.resolve();

		specAll(element, 'usage-legend-chip')[1].click();
		await Promise.resolve();

		element.eventTypes = [EVENT_TYPES[0]];
		await Promise.resolve();
		expect(specAll(element, 'usage-legend-chip').length).toBe(1);

		element.eventTypes = [...EVENT_TYPES];
		await Promise.resolve();

		expect([...specAll(element, 'usage-legend-chip')].map((chip) => chip.getAttribute('aria-pressed'))).toEqual([
			'true',
			'true'
		]);
	});

	it('renders without event types and without crashing', async() =>
	{
		const element = createElement('c-streaming-usage-filters', {is: StreamingUsageFilters});
		element.eventTypes = null;
		document.body.appendChild(element);
		await Promise.resolve();

		expect(specAll(element, 'usage-legend-chip').length).toBe(0);
		expect(spec(element, 'usage-granularity-daily')).not.toBeNull();
	});

	it('reset() restores the Daily default, clears the custom range, re-shows every chip, and does not emit', async() =>
	{
		const element = createFilters();
		const searchHandler = jest.fn();
		const displayHandler = jest.fn();
		element.addEventListener('searchfilterchange', searchHandler);
		element.addEventListener('displayfilterchange', displayHandler);
		await Promise.resolve();

		// Drive the controls off their defaults: switch to Hourly, then enter a custom range and hide a chip.
		spec(element, 'usage-granularity-hourly').click();
		await Promise.resolve();
		changeValue(spec(element, 'usage-range-preset'), 'CUSTOM');
		await Promise.resolve();
		specAll(element, 'usage-legend-chip')[0].click();
		await Promise.resolve();
		expect(spec(element, 'usage-range-from')).not.toBeNull();
		expect(specAll(element, 'usage-legend-chip')[0].getAttribute('aria-pressed')).toBe('false');
		searchHandler.mockClear();
		displayHandler.mockClear();

		element.reset();
		await Promise.resolve();

		expect(spec(element, 'usage-granularity-daily').getAttribute('aria-pressed')).toBe('true');
		expect(spec(element, 'usage-range-preset').value).toBe('P30D');
		expect(spec(element, 'usage-range-from')).toBeNull();
		specAll(element, 'usage-legend-chip').forEach((chip) => expect(chip.getAttribute('aria-pressed')).toBe('true'));
		expect(searchHandler).not.toHaveBeenCalled();
		expect(displayHandler).not.toHaveBeenCalled();
	});
});
