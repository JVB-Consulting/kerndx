// SPDX-License-Identifier: Apache-2.0
jest.mock('../e2e/helpers/sf-cli', () => ({runApexScript: jest.fn(), soqlQuery: jest.fn()}));
jest.mock('../e2e/helpers/sf-namespace', () => ({namespacePrefix: () => '', apexNamespacePrefix: () => '', fillNamespaceTokens: (source) => source}));
jest.mock('../e2e/helpers/sf-auth', () => ({getInstanceUrl: () => 'https://x', ensureAuthenticated: jest.fn(async() => {})}));
jest.mock('../e2e/helpers/wait-helpers', () => ({waitForSpinnerGone: jest.fn(async() => {})}));
jest.mock('../e2e/helpers/sf-navigation', () => ({waitForPageLoad: jest.fn(async() => {})}));
const {ensureAuthenticated} = require('../e2e/helpers/sf-auth');
const {openConsoleTimed, openMonitorTimed} = require('../e2e/explore/moves');

/**
 * @description A context whose page objects and timer record the order of what happened.
 * @param {Array<string>} events The list the order is written to.
 * @returns {Object} The context.
 */
function recordingContext(events)
{
	return {
		page: {waitForTimeout: async() => {}},
		logConsole: {
			navigateUntilRendered: async() => { events.push('console rendered'); },
			waitForListSettled: async() => { events.push('console settled'); }
		},
		monitor: {
			navigateUntilRendered: async() => { events.push('monitor rendered'); },
			getListPanel: () => ({waitFor: async() => {}})
		},
		timing: {openTimer: () => { events.push('timer started'); return {stop: (name) => events.push(`timer stopped ${name}`)}; }}
	};
}

describe('the timed tab opens', () =>
{
	beforeEach(() => ensureAuthenticated.mockClear());

	it('signs the page in before the console timer starts, stops it at the rendered list, then settles', async() =>
	{
		const events = [];
		ensureAuthenticated.mockImplementation(async() => { events.push('authenticated'); });
		await openConsoleTimed(recordingContext(events));
		expect(events).toEqual(['authenticated', 'timer started', 'console rendered', 'timer stopped console', 'console settled']);
	});

	it('signs the page in before the monitor timer starts', async() =>
	{
		const events = [];
		ensureAuthenticated.mockImplementation(async() => { events.push('authenticated'); });
		await openMonitorTimed(recordingContext(events));
		expect(events.slice(0, 4)).toEqual(['authenticated', 'timer started', 'monitor rendered', 'timer stopped monitor']);
	});
});
