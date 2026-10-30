// SPDX-License-Identifier: Apache-2.0
jest.mock('../e2e/helpers/sf-cli', () => ({runApexScript: jest.fn()}));

const fs = require('fs');
const path = require('path');
const {runApexScript} = require('../e2e/helpers/sf-cli');
const {SHAPED_SEED_SCRIPTS, runShapedSeed} = require('../e2e/helpers/log-console-seed');

const FIRST_LINE = 'SEED_LOG_CONSOLE ns=[kern__] logRows=52 chainRows=1 auditBackdate=OK';
const SECOND_LINE = 'SEED_LOG_CONSOLE_ACTIONS ns=[kern__] logRows=9 chainRows=6';
const SEED_TIMEOUT_MILLISECONDS = 300_000;

// What the command line answers for a script that printed one debug line.
function resultPrinting(message)
{
	return {raw: `|USER_DEBUG|[1]|DEBUG|${message}`, results: [{message}]};
}

describe('runShapedSeed', () =>
{
	beforeEach(() =>
	{
		runApexScript.mockReset();
	});

	it('names two scripts that exist, the main story first and the whole-action rows second', () =>
	{
		expect(SHAPED_SEED_SCRIPTS.map((script) => path.basename(script.path))).toEqual(['seed-log-console.apex', 'seed-log-console-actions.apex']);
		SHAPED_SEED_SCRIPTS.forEach((script) => expect(fs.existsSync(script.path)).toBe(true));
	});

	it('prints in each script the debug line the runner waits for', () =>
	{
		SHAPED_SEED_SCRIPTS.forEach((script) => expect(fs.readFileSync(script.path, 'utf8')).toContain(`System.debug('${script.marker}`));
	});

	it('runs both scripts in order and joins their output', () =>
	{
		runApexScript.mockReturnValueOnce(resultPrinting(FIRST_LINE)).mockReturnValueOnce(resultPrinting(SECOND_LINE));

		const seed = runShapedSeed();

		expect(runApexScript.mock.calls.map((call) => call[0])).toEqual(SHAPED_SEED_SCRIPTS.map((script) => script.path));
		expect(runApexScript).toHaveBeenCalledWith(expect.any(String), {timeout: SEED_TIMEOUT_MILLISECONDS});
		expect(seed.results).toHaveLength(2);
		expect(seed.raw).toContain('auditBackdate=OK');
		expect(seed.raw).toContain('SEED_LOG_CONSOLE_ACTIONS');
	});

	it('passes a caller\'s timeout to each script', () =>
	{
		runApexScript.mockReturnValueOnce(resultPrinting(FIRST_LINE)).mockReturnValueOnce(resultPrinting(SECOND_LINE));

		runShapedSeed({timeout: 60_000});

		expect(runApexScript.mock.calls.every((call) => call[1].timeout === 60_000)).toBe(true);
	});

	it('stops before the second script when the first does not report its rows', () =>
	{
		runApexScript.mockReturnValueOnce(resultPrinting('something else'));

		expect(() => runShapedSeed()).toThrow('seed-log-console.apex did not report SEED_LOG_CONSOLE');
		expect(runApexScript).toHaveBeenCalledTimes(1);
	});

	it('does not take the second script\'s line for the first one\'s', () =>
	{
		runApexScript.mockReturnValueOnce(resultPrinting(SECOND_LINE));

		expect(() => runShapedSeed()).toThrow('seed-log-console.apex did not report SEED_LOG_CONSOLE');
	});

	it('fails when the second script does not report its rows', () =>
	{
		runApexScript.mockReturnValueOnce(resultPrinting(FIRST_LINE)).mockReturnValueOnce(resultPrinting('nothing'));

		expect(() => runShapedSeed()).toThrow('seed-log-console-actions.apex did not report SEED_LOG_CONSOLE_ACTIONS');
	});
});
