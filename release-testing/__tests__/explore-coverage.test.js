// SPDX-License-Identifier: BUSL-1.1
jest.mock('../e2e/helpers/sf-cli', () => ({soqlQuery: jest.fn(), runApexScript: jest.fn(), executeAnonymousApex: jest.fn()}));
jest.mock('../e2e/helpers/sf-namespace', () => ({namespacePrefix: () => '', apexNamespacePrefix: () => '', fillNamespaceTokens: (source) => source}));
const {collectPageKeys, findRepeatsAndLosses, isOrdered, readPageLabel, pageCapFor, restoreViewport} = require('../e2e/explore/coverage');

describe('collectPageKeys', () =>
{
	it('walks Next until the paginator stops and keeps every page\'s keys', async() =>
	{
		const pages = [['a', 'b'], ['c', 'd'], ['e']];
		let index = 0;
		const monitor = {
			getRowKeys: jest.fn(async() => pages[index]),
			getNextPageButton: () => ({isDisabled: async() => index >= pages.length - 1, click: async() => { index++; }})
		};
		const result = await collectPageKeys(monitor, 10, {settle: async() => {}});
		expect(result).toEqual({keys: ['a', 'b', 'c', 'd', 'e'], pages: 3, secondPresses: 0});
	});

	it('presses Next a second time when the page after it is the page before it, and says how often', async() =>
	{
		const pages = [['a', 'b'], ['a', 'b'], ['c', 'd']];
		let index = 0;
		const monitor = {
			getRowKeys: jest.fn(async() => pages[index]),
			getNextPageButton: () => ({isDisabled: async() => index >= pages.length - 1, click: async() => { index++; }})
		};
		const result = await collectPageKeys(monitor, 10, {settle: async() => {}});
		expect(result).toEqual({keys: ['a', 'b', 'c', 'd'], pages: 2, secondPresses: 1});
	});

	it('stops at the page cap', async() =>
	{
		let press = 0;
		const monitor = {getRowKeys: jest.fn(async() => [`x${press}`]), getNextPageButton: () => ({isDisabled: async() => false, click: async() => { press++; }})};
		await expect(collectPageKeys(monitor, 2, {settle: async() => {}})).resolves.toEqual({keys: ['x0', 'x1'], pages: 2, secondPresses: 0});
	});

	it('names repeats and losses against the oracle', () =>
	{
		expect(findRepeatsAndLosses(['a', 'b', 'b'], ['a', 'b', 'c'])).toEqual({repeats: ['b'], losses: ['c']});
	});
});

describe('resolveOutputDirectory', () =>
{
	const {resolveOutputDirectory} = require('../e2e/explore/coverage');

	it('sends a release run under results, a development run under tmp, and a shaped run where PLAN-166 put it', () =>
	{
		expect(resolveOutputDirectory({manifest: 'm.json', namespacePrefix: 'kern__', version: '1.8.0-1'}))
		.toMatch(/release-testing[\\/]results[\\/]1\.8\.0-1[\\/]consoles-at-volume$/);
		expect(resolveOutputDirectory({manifest: 'm.json', namespacePrefix: '', version: '1.8.0-1'})).toMatch(/tmp[\\/]consoles-at-volume[\\/]exploration$/);
		expect(resolveOutputDirectory({manifest: null, namespacePrefix: '', version: '1.8.0-1'})).toMatch(/tmp[\\/]plan166$/);
		expect(resolveOutputDirectory({manifest: 'm.json', namespacePrefix: 'kern__', version: '1.8.0-1', outputDirectory: '/given'})).toBe('/given');
	});
});

describe('isOrdered and readTotal', () =>
{
	it('accepts ties and a null value at either end, in both directions', () =>
	{
		expect(isOrdered([1, 1, 2, 3], false)).toBe(true);
		expect(isOrdered([3, 2, 2, 1], true)).toBe(true);
		expect(isOrdered([1, 3, 2], false)).toBe(false);
		expect(isOrdered(['Volume_A', 'Volume_B'], false)).toBe(true);
		expect(isOrdered(['e2e Checkout', 'E2E Nightly', 'Volume_A'], false)).toBe(true);
		expect(isOrdered([null, 1, 2], false)).toBe(true);
		expect(isOrdered([], true)).toBe(true);
	});

	it('reads the page number and the page count from the page label, which names no run total', () =>
	{
		expect(readPageLabel('Page 3 of 125')).toEqual({page: 3, pages: 125});
		expect(readPageLabel('Page 1 of 1,234')).toEqual({page: 1, pages: 1234});
		expect(readPageLabel(null)).toEqual({page: null, pages: null});
	});

	it('caps a page walk at the pages the count fills plus one, under the ceiling, and restores the session viewport', async() =>
	{
		expect(pageCapFor(3362)).toBe(170);
		expect(pageCapFor(0)).toBe(1);
		expect(pageCapFor(1_000_000)).toBe(1000);
		const page = {setViewportSize: jest.fn(async() => {})};
		await restoreViewport({page});
		expect(page.setViewportSize).toHaveBeenCalledWith({width: 1440, height: 900});
	});
});

describe('describeGates and expectedGates', () =>
{
	const ChainMonitorPage = require('../e2e/pages/chain-monitor.page');
	const {describeGates, expectedGates} = require('../e2e/explore/coverage');

	it('expects a retry on the idempotent run alone and a restart wherever the row declares one', () =>
	{
		expect(expectedGates({name: 'CHAIN-1', allowRestart: true}, {name: 'CHAIN-2', allowRestart: true}))
		.toBe('idempotent CHAIN-1: retry enabled, restart enabled; restartable CHAIN-2: retry disabled, restart enabled');
		expect(expectedGates({name: 'CHAIN-1', allowRestart: false}, null)).toBe('idempotent CHAIN-1: retry enabled, restart disabled');
		expect(expectedGates(null, null)).toBe('no Failed candidate left to read');
	});

	it('reads each operator gate from the rendered inner button, which the lightning-button host never carries', async() =>
	{
		const host = (innerDisabled) => ({isDisabled: async() => false, locator: (selector) => ({isDisabled: async() => selector === 'button' && innerDisabled})});
		const monitor = new ChainMonitorPage({});
		monitor.getRetryButton = () => host(false);
		monitor.getRestartButton = () => host(true);
		await expect(describeGates(monitor)).resolves.toBe('retry enabled, restart disabled');
	});
});

describe('timeDrawerOpen', () =>
{
	const {timeDrawerOpen} = require('../e2e/explore/coverage');
	const LogConsolePage = require('../e2e/pages/log-console.page');

	it('stops the drawer timer when the drawer is on screen and settles afterwards, outside the sample', async() =>
	{
		const order = [];
		const logConsole = {
			detailPanel: () => ({isVisible: async() => false, waitFor: async() => {}}),
			selectRowUntilDetail: jest.fn(async() => { order.push('select'); }),
			waitForListSettled: jest.fn(async() => { order.push('settle'); })
		};
		const timing = {markRead: jest.fn((name) => { order.push(name); })};
		await timeDrawerOpen({logConsole, timing}, 0);
		expect(order).toEqual(['select', 'drawer-open', 'settle']);
		expect(logConsole.selectRowUntilDetail).toHaveBeenCalledWith(0);
	});

	it('selects the row and returns at the drawer, with no fixed wait inside', async() =>
	{
		const order = [];
		const page = {waitForTimeout: jest.fn(async() => { order.push('sleep'); })};
		const logConsole = new LogConsolePage(page);
		const radio = {isVisible: async() => false};
		const row = {locator: () => ({first: () => radio}), click: async() => { order.push('click'); }};
		logConsole.rows = () => ({nth: () => row});
		logConsole.detailPanel = () => ({waitFor: async({state}) => { order.push(`drawer ${state}`); }});
		await logConsole.selectRowUntilDetail(0);
		expect(order).toEqual(['click', 'drawer visible']);
		expect(page.waitForTimeout).not.toHaveBeenCalled();
	});
});
