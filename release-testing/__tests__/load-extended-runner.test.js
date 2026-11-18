// SPDX-License-Identifier: Apache-2.0
jest.mock('../runner/subscriber-config', () => ({getSubscriberOrgAlias: jest.fn(() => 'LoadOrg')}));
const {runExtendedLoad} = require('../runner/load-extended-runner');

const BURST_PATH = 'release-testing/scripts/load-extended/parallel-callout-burst-100.js';
const SOAK_PATH = 'release-testing/scripts/load-extended/sustained-masker-soak.apex';
const FLOOD_PATH = 'release-testing/scripts/load-extended/sustained-logger-pe-flood.apex';
const CACHE_PATH = 'release-testing/scripts/load-extended/parallel-cache-contention.js';
const ENABLED_STATE = 'mock-all-apis-enabled';
const DISABLED_STATE = 'mock-all-apis-disabled';

// Runs the suite with fakes that write every action into one ordered list.
async function runWith({failingCommand = null, failingState = null} = {})
{
	const events = [];
	const errors = [];
	const execSync = jest.fn((command) =>
	{
		events.push(`run ${command}`);
		if(failingCommand && command.includes(failingCommand))
		{
			throw new Error('script failed');
		}
	});
	const deployCmdtState = jest.fn((state) =>
	{
		events.push(`deploy ${state}`);
		if(state === failingState)
		{
			throw new Error('deploy failed');
		}
	});
	const exitCode = await runExtendedLoad({
		orgAlias: 'LoadOrg', execSync, deployCmdtState, log: () => {}, logError: (message) => errors.push(message)
	});
	return {events, errors, exitCode};
}

describe('runExtendedLoad', () =>
{
	test('runs the callout burst between an enable and a disable deploy, in that order', async() =>
	{
		const {events, exitCode} = await runWith();

		const burstIndex = events.indexOf(`run node ${BURST_PATH}`);
		expect(events[burstIndex - 1]).toBe(`deploy ${ENABLED_STATE}`);
		expect(events[burstIndex + 1]).toBe(`deploy ${DISABLED_STATE}`);
		expect(exitCode).toBe(0);
	});

	test('turns the window off even when the burst fails, and counts the burst as failed', async() =>
	{
		const {events, exitCode} = await runWith({failingCommand: 'parallel-callout-burst-100'});

		const burstIndex = events.indexOf(`run node ${BURST_PATH}`);
		expect(events[burstIndex + 1]).toBe(`deploy ${DISABLED_STATE}`);
		expect(exitCode).toBe(1);
	});

	test('skips the burst when the enable fails, counts a failure and still runs the script after it', async() =>
	{
		const {events, exitCode} = await runWith({failingState: ENABLED_STATE});

		expect(events).not.toContain(`run node ${BURST_PATH}`);
		// A half-applied enable is turned off again.
		expect(events).toContain(`deploy ${DISABLED_STATE}`);
		expect(events).toContain(`run node ${CACHE_PATH}`);
		expect(exitCode).toBe(1);
	});

	test('counts a failure and names the fixture to deploy by hand when the restore fails', async() =>
	{
		const {errors, exitCode} = await runWith({failingState: DISABLED_STATE});

		expect(exitCode).toBe(1);
		expect(errors.join('\n')).toContain(`cmdt-states/${DISABLED_STATE}`);
	});

	test('runs the Apex scripts and the cache script with no deploy around them, in order', async() =>
	{
		const {events} = await runWith();

		expect(events).toEqual([
			`run sf apex run --file ${SOAK_PATH} -o LoadOrg`,
			`run sf apex run --file ${FLOOD_PATH} -o LoadOrg`,
			`deploy ${ENABLED_STATE}`,
			`run node ${BURST_PATH}`,
			`deploy ${DISABLED_STATE}`,
			`run node ${CACHE_PATH}`
		]);
	});
});
