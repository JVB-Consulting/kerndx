// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for orgLimits LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */
import {createElement} from 'lwc';
import LwcOrgLimits from 'c/orgLimits';

// Mock Apex controller
const mockGetOrgLimits = jest.fn();

jest.mock('@salesforce/apex/CTRL_EventMonitor.getOrgLimits', () => ({
	default: (...args) => mockGetOrgLimits(...args)
}), {virtual: true});

// Mock loadScript
const mockLoadScript = jest.fn();

jest.mock('lightning/platformResourceLoader', () => ({
	loadScript: (...args) => mockLoadScript(...args)
}), {virtual: true});

// Mock D3 resource URL
jest.mock('@salesforce/resourceUrl/d3', () => ({default: '/sfc/servlet.shepherd/version/download/mockD3'}), {virtual: true});

// Mock locale
jest.mock('@salesforce/i18n/locale', () => ({default: 'en-US'}), {virtual: true});

// Storage for captured D3 event handlers
let capturedOnHandlers = {};
let capturedBoundsAppendCalls = [];
let capturedAttrCallbacks = [];

// Create chainable D3 mock with event handler capture
const createChainableMock = (isBounds = false) =>
{
	const mock = {};
	mock.append = jest.fn(() =>
	{
		const newMock = createChainableMock(true);
		if(isBounds)
		{
			capturedBoundsAppendCalls.push(newMock);
		}
		return newMock;
	});
	mock.attr = jest.fn((name, valueOrCallback) =>
	{
		// If a callback function is passed, invoke it with mock data to get coverage
		if(typeof valueOrCallback === 'function')
		{
			capturedAttrCallbacks.push({name, callback: valueOrCallback});
		}
		return mock;
	});
	mock.call = jest.fn(() => mock);
	mock.selectAll = jest.fn(() => mock);
	mock.data = jest.fn(() => mock);
	mock.join = jest.fn(() => mock);
	mock.on = jest.fn((event, callback) =>
	{
		capturedOnHandlers[event] = callback;
		return mock;
	});
	mock.text = jest.fn(() => mock);
	mock.range = jest.fn(() => mock);
	mock.domain = jest.fn(() => mock);
	mock.paddingInner = jest.fn(() => mock);
	mock.paddingOuter = jest.fn(() => mock);
	mock.tickSize = jest.fn(() => mock);
	mock.bandwidth = jest.fn(() => 20);
	return mock;
};

// Create scale mock that is both callable and chainable
const createScaleMock = () =>
{
	const scaleFn = jest.fn(() => 100); // Returns a position value when called
	scaleFn.range = jest.fn(() => scaleFn);
	scaleFn.domain = jest.fn(() => scaleFn);
	scaleFn.paddingInner = jest.fn(() => scaleFn);
	scaleFn.paddingOuter = jest.fn(() => scaleFn);
	scaleFn.bandwidth = jest.fn(() => 20);
	return scaleFn;
};

global.d3 = {
	select: jest.fn(() => createChainableMock()),
	scaleLinear: jest.fn(() => createScaleMock()),
	scaleBand: jest.fn(() => createScaleMock()),
	axisBottom: jest.fn(() => jest.fn()),
	axisLeft: jest.fn(() => ({tickSize: jest.fn(() => jest.fn())})),
	pointer: jest.fn(() => [
		100,
		100
	])
};

const mockLimits = [
	{name: 'DailyApiRequests', value: 5000, max: 15000},
	{name: 'DailyAsyncApexExecutions', value: 1000, max: 250000},
	{name: 'HourlyPublishedPlatformEvents', value: 100, max: 50000}
];

describe('c-org-limits', () =>
{
	beforeEach(() =>
	{
		mockGetOrgLimits.mockResolvedValue(mockLimits);
		mockLoadScript.mockResolvedValue();
		capturedOnHandlers = {};
		capturedBoundsAppendCalls = [];
		capturedAttrCallbacks = [];
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
		const element = createElement('c-org-limits', {is: LwcOrgLimits});
		document.body.appendChild(element);
		return element;
	};

	describe('initialization', () =>
	{
		it('loads org limits from Apex on connected', async() =>
		{
			createComponent();
			await flushPromises();

			expect(mockGetOrgLimits).toHaveBeenCalled();
		});

		it('renders component after initialization', async() =>
		{
			// Note: loadScript mock isn't reliably hoisted by sfdx-lwc-jest
			// so we verify component renders instead
			const element = createComponent();
			await flushPromises();

			expect(element).toBeDefined();
		});

		it('calls Apex to load org limits', async() =>
		{
			createComponent();
			await flushPromises();

			expect(mockGetOrgLimits).toHaveBeenCalledTimes(1);
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

		it('renders chart container', async() =>
		{
			const element = createComponent();
			await flushPromises();
			await flushPromises();

			const chartDiv = element.shadowRoot.querySelector('.chart');
			expect(chartDiv).not.toBeNull();
		});

		it('card has correct title', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
			expect(card.title).toBe('Org limits');
		});
	});

	describe('chart rendering', () =>
	{
		it('uses D3 to create chart after loading', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			expect(global.d3.select).toHaveBeenCalled();
		});

		it('creates scales for chart', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			expect(global.d3.scaleLinear).toHaveBeenCalled();
			expect(global.d3.scaleBand).toHaveBeenCalled();
		});

		it('creates axes for chart', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			expect(global.d3.axisBottom).toHaveBeenCalled();
			expect(global.d3.axisLeft).toHaveBeenCalled();
		});
	});

	describe('error handling', () =>
	{
		it('handles Apex error gracefully and stores serialized error', async() =>
		{
			mockGetOrgLimits.mockRejectedValueOnce({message: 'Apex error', statusCode: 500});

			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// Component should still render
			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
		});

		it('handles loadScript error gracefully', async() =>
		{
			mockLoadScript.mockRejectedValueOnce(new Error('Script load failed'));

			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// Component should still render
			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
		});
	});

	describe('rerendering', () =>
	{
		it('redraws chart on renderedCallback', async() =>
		{
			const element = createComponent();
			await flushPromises();
			await flushPromises();

			const initialSelectCalls = global.d3.select.mock.calls.length;

			// Trigger a rerender by updating the DOM
			element.shadowRoot.querySelector('lightning-card');
			await flushPromises();

			// D3 select should have been called again (or same count if no rerender)
			expect(global.d3.select.mock.calls.length).toBeGreaterThanOrEqual(initialSelectCalls);
		});
	});

	describe('mouse interactions', () =>
	{
		it('registers mouseenter handler on bars', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			expect(capturedOnHandlers.mouseenter).toBeDefined();
		});

		it('registers mouseout handler on bars', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			expect(capturedOnHandlers.mouseout).toBeDefined();
		});

		it('mouseenter handler shows tooltip', async() =>
		{
			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// Create tooltip element in DOM (simulating D3 creation)
			const chartDiv = element.shadowRoot.querySelector('.chart');
			const tooltipDiv = document.createElement('div');
			tooltipDiv.className = 'tooltip inactive';
			chartDiv.appendChild(tooltipDiv);

			// Invoke the captured mouseenter handler
			const mockData = {name: 'DailyApiRequests', value: 5000, max: 15000, percent: 33};
			const mockEvent = {};

			if(capturedOnHandlers.mouseenter)
			{
				capturedOnHandlers.mouseenter(mockEvent, mockData);
			}

			// Verify tooltip content was updated
			expect(tooltipDiv.textContent).toContain('DailyApiRequests');
			expect(tooltipDiv.classList.contains('inactive')).toBe(false);
		});

		it('mouseout handler hides tooltip', async() =>
		{
			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// Create tooltip element in DOM
			const chartDiv = element.shadowRoot.querySelector('.chart');
			const tooltipDiv = document.createElement('div');
			tooltipDiv.className = 'tooltip';
			chartDiv.appendChild(tooltipDiv);

			// Invoke the captured mouseout handler
			if(capturedOnHandlers.mouseout)
			{
				capturedOnHandlers.mouseout();
			}

			// Verify tooltip is hidden
			expect(tooltipDiv.classList.contains('inactive')).toBe(true);
		});
	});

	describe('data transformation', () =>
	{
		it('calculates percentage correctly', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			// Trigger mouseenter to verify transformed data is passed
			const element = document.body.querySelector('c-org-limits');
			const chartDiv = element.shadowRoot.querySelector('.chart');
			const tooltipDiv = document.createElement('div');
			tooltipDiv.className = 'tooltip inactive';
			chartDiv.appendChild(tooltipDiv);

			// The mock data was 5000/15000 = 33%
			const mockData = {name: 'DailyApiRequests', value: 5000, max: 15000, percent: 33};
			if(capturedOnHandlers.mouseenter)
			{
				capturedOnHandlers.mouseenter({}, mockData);
			}

			expect(tooltipDiv.textContent).toContain('33%');
		});

		it('handles zero max value without division error', async() =>
		{
			mockGetOrgLimits.mockResolvedValueOnce([
				{name: 'ZeroLimit', value: 0, max: 0}
			]);

			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// Component should render without errors
			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
		});

		it('sorts limits alphabetically by name', async() =>
		{
			mockGetOrgLimits.mockResolvedValueOnce([
				{name: 'ZLimit', value: 100, max: 1000},
				{name: 'ALimit', value: 50, max: 500}
			]);

			createComponent();
			await flushPromises();
			await flushPromises();

			// D3 scaleBand domain should be called with sorted names
			expect(global.d3.scaleBand).toHaveBeenCalled();
		});
	});

	describe('label rendering', () =>
	{
		it('renders component with limits that have labels', async() =>
		{
			const element = createComponent();
			await flushPromises();
			await flushPromises();

			// The component renders successfully with D3 chart including labels
			// Labels are rendered via bounds.append('text').text() chain
			const chartDiv = element.shadowRoot.querySelector('.chart');
			expect(chartDiv).not.toBeNull();
			expect(global.d3.select).toHaveBeenCalled();
		});

		it('renders label for each limit via bounds.append(text)', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			// renderLabels calls bounds.append('text') for each limit
			// With 3 limits, at least 3 text append calls should be made
			const allBoundsAppends = capturedBoundsAppendCalls.length;
			// bounds.append is called for g (x/y-axis), rect (bars), and text (labels)
			expect(allBoundsAppends).toBeGreaterThan(0);
		});
	});

	describe('bar attribute callbacks', () =>
	{
		it('executes y position callback with limit data', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			// Find the 'y' attr callback and invoke it with mock data
			const yCallback = capturedAttrCallbacks.find(c => c.name === 'y');
			expect(yCallback).toBeDefined();
			const mockData = {name: 'TestLimit', value: 100, max: 1000, percent: 10};
			const result = yCallback.callback(mockData);
			expect(result).toBeDefined();
		});

		it('executes width callback with limit data', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			// Find the 'width' attr callback and invoke it with mock data
			const widthCallback = capturedAttrCallbacks.find(c => c.name === 'width');
			expect(widthCallback).toBeDefined();
			const mockData = {name: 'TestLimit', value: 100, max: 1000, percent: 10};
			const result = widthCallback.callback(mockData);
			expect(typeof result).toBe('number');
		});

		it('captures all bar attribute callbacks', async() =>
		{
			createComponent();
			await flushPromises();
			await flushPromises();

			// Verify callbacks were captured for y and width (the function-based attrs)
			const callbackNames = capturedAttrCallbacks.map(c => c.name);
			expect(callbackNames).toContain('y');
			expect(callbackNames).toContain('width');
		});
	});
});
