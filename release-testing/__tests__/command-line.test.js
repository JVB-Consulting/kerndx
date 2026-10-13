// SPDX-License-Identifier: BUSL-1.1
const {parseCommandLine} = require('../scripts/consoles-at-volume/command-line');

describe('parseCommandLine', () =>
{
	it('defaults to staged mode at size one under tmp/consoles-at-volume', () =>
	{
		const options = parseCommandLine(['run'], {alias: 'Dev'});
		expect(options).toMatchObject({command: 'run', mode: 'staged', size: 1, alias: 'Dev', reuse: false});
		expect(parseCommandLine(['status'], {alias: 'Dev'}).command).toBe('status');
		expect(options.outputDirectory).toMatch(/tmp[\\/]consoles-at-volume$/);
		expect(options.manifestPath).toMatch(/manifest\.json$/);
	});

	it('reads every option', () =>
	{
		const options = parseCommandLine(['verify', '--mode', 'full', '--size', '0.5', '--output-directory', 'out', '--org', 'Sub', '--reuse'], {alias: 'Dev'});
		expect(options).toMatchObject({command: 'verify', mode: 'full', size: 0.5, alias: 'Sub', reuse: true});
		expect(options.manifestPath).toMatch(/out[\\/]manifest\.json$/);
	});

	it('refuses an unknown command, mode or size', () =>
	{
		expect(() => parseCommandLine(['dance'], {alias: 'Dev'})).toThrow(/command/);
		expect(() => parseCommandLine(['run', '--mode', 'quick'], {alias: 'Dev'})).toThrow(/mode/);
		expect(() => parseCommandLine(['run', '--size', '0'], {alias: 'Dev'})).toThrow(/size/);
		// Above one the id scheme runs out of letters: a nested root ordinal of 1,000 plus the action's needs a fifth letter past 1.48.
		expect(() => parseCommandLine(['run', '--size', '1.5'], {alias: 'Dev'})).toThrow(/size/);
	});

	it('lays no started-step Stalled rows unless asked, and reads how many when asked', () =>
	{
		expect(parseCommandLine(['run'], {alias: 'Dev'}).stalledStarted).toBe(0);
		expect(parseCommandLine(['run', '--mode', 'full', '--stalled-started', '250'], {alias: 'Dev'})).toMatchObject({mode: 'full', stalledStarted: 250});
		expect(parseCommandLine(['operate', '--stalled-started', '0'], {alias: 'Dev'}).stalledStarted).toBe(0);
	});

	it('refuses a started-step row count that is not a whole number of zero or more', () =>
	{
		for(const wrong of ['-1', '2.5', 'many', undefined])
		{
			const words = ['run', '--stalled-started', wrong].filter((word) => word !== undefined);
			expect(() => parseCommandLine(words, {alias: 'Dev'})).toThrow(/--stalled-started must be a whole number/);
		}
	});
});
