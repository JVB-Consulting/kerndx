// SPDX-License-Identifier: BUSL-1.1
jest.mock('../e2e/helpers/sf-cli', () => ({runApexScript: jest.fn(), soqlQuery: jest.fn()}));
jest.mock('../e2e/helpers/sf-namespace', () => ({namespacePrefix: () => '', apexNamespacePrefix: () => '', fillNamespaceTokens: (source) => source}));
const {HistoryTape, consoleEntry, monitorEntry, samePins, expectedRowCount, freshSession, openedActionSession} = require('../e2e/explore/model');

describe('HistoryTape', () =>
{
	it('pushes, goes back and forward, and replaces in place', () =>
	{
		const tape = new HistoryTape(consoleEntry());
		tape.push(consoleEntry('action'));
		expect(tape.current()).toEqual(consoleEntry('action'));
		tape.goBack();
		expect(tape.current()).toEqual(consoleEntry());
		tape.goForward();
		expect(tape.current()).toEqual(consoleEntry('action'));
		tape.replace(consoleEntry('action', 'chain'));
		expect(tape.current()).toEqual(consoleEntry('action', 'chain'));
		expect(tape.canGoBack()).toBe(true);
		expect(tape.canGoForward()).toBe(false);
	});

	it('drops what was ahead when a push follows a Back', () =>
	{
		const tape = new HistoryTape(consoleEntry());
		tape.push(consoleEntry('first'));
		tape.push(consoleEntry('second'));
		tape.goBack();
		tape.push(consoleEntry('third'));
		expect(tape.entries.map((entry) => entry.action)).toEqual([null, 'first', 'third']);
		expect(tape.canGoForward()).toBe(false);
	});
});

describe('samePins and expectedRowCount', () =>
{
	it('compares pins by their four keys and counts the rows a state should show', () =>
	{
		expect(samePins(consoleEntry('a', null), consoleEntry('a'))).toBe(true);
		expect(samePins(monitorEntry('a'), consoleEntry('a'))).toBe(false);
		const now = Date.now();
		const oracle = {
			rows: [
				{level: 'ERROR', correlation: 'c', root: 'a', createdAt: now - 120_000},
				{level: 'INFO', correlation: 'd', root: 'a', createdAt: now - 120_000},
				{level: 'DEBUG', correlation: 'd', root: 'a', createdAt: now - 120_000}
			],
			actionSpans: {a: {first: now - 120_000, last: now - 120_000}}
		};
		const session = freshSession();
		expect(expectedRowCount(consoleEntry('a'), session, oracle)).toBeNull();
		openedActionSession(session, 'a');
		expect(expectedRowCount(consoleEntry('a'), session, oracle)).toBe(2);
	});
});
