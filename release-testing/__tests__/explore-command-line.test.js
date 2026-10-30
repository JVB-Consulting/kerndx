// SPDX-License-Identifier: Apache-2.0
const {parseArguments} = require('../e2e/explore/command-line');

describe('parseArguments', () =>
{
	it('keeps the explorer defaults and reads the volume options', () =>
	{
		const options = parseArguments(['--seed', '5', '--phases', 'widths', '--timing-budget-read', '800']);
		expect(options).toMatchObject({seed: 5, sessions: 3, steps: 40, phases: ['widths'], manifest: null, timingBudgets: {pageOpenMilliseconds: 3000, inPageReadMilliseconds: 800}});
		expect(parseArguments(['--manifest', 'm.json'])).toMatchObject({manifest: 'm.json', phases: ['volume']});
		const defaults = parseArguments([]);
		expect(defaults.manifest).toBeNull();
		expect(defaults.outputDirectory).toBeNull();
		expect(defaults.phases).toEqual(['sessions', 'hostile', 'probes', 'widths']);
		expect(defaults.timingBudgets).toEqual({pageOpenMilliseconds: 3000, inPageReadMilliseconds: 1000});
		expect(Number.isInteger(defaults.seed) && defaults.seed > 0).toBe(true);
		expect(parseArguments(['--output-directory', 'out', '--timing-budget-page', '2500'])).toMatchObject({outputDirectory: 'out', timingBudgets: {pageOpenMilliseconds: 2500}});
	});

	it('walks the volume phase only with a manifest, which defaults to that phase alone and may add the shaped ones by name', () =>
	{
		expect(parseArguments(['--manifest', 'm.json']).phases).toEqual(['volume']);
		expect(parseArguments(['--manifest', 'm.json', '--phases', 'volume']).phases).toEqual(['volume']);
		expect(parseArguments(['--manifest', 'm.json', '--phases', 'widths,volume']).phases).toEqual(['widths', 'volume']);
		expect(parseArguments(['--manifest', 'm.json', '--phases', 'widths']).phases).toEqual(['widths', 'volume']);
		expect(() => parseArguments(['--phases', 'volume'])).toThrow(/--manifest/);
	});

	it('refuses a bad number, an unknown phase and an unknown flag', () =>
	{
		expect(() => parseArguments(['--seed', 'x'])).toThrow(/--seed/);
		expect(() => parseArguments(['--phases', 'dance'])).toThrow(/dance/);
		expect(() => parseArguments(['--nope'])).toThrow(/--nope/);
		expect(() => parseArguments(['--manifest'])).toThrow(/--manifest/);
		expect(() => parseArguments(['--seed', 'x'])).toThrow(/Usage: node explore-consoles.js/);
	});
});
