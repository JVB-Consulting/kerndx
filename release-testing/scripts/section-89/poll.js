// SPDX-License-Identifier: Apache-2.0
// Waiting, with a clock that tests can replace. Every wait in section 89 reads the org again and again until what it
// waits for is there or its time limit passes, and an interrupt (Ctrl-C) ends any wait at once.
'use strict';

const SLEEP_SLICE_MILLISECONDS = 1_000;

/**
 * @description Thrown when the person stops the run (Ctrl-C) during a wait, so the clean-up runs next.
 */
class InterruptedError extends Error
{
	/**
	 * @description Builds the error.
	 *
	 * @param {string} [message] What stopped the run.
	 */
	constructor(message = 'the run was interrupted')
	{
		super(message);
		this.name = 'InterruptedError';
	}
}

/**
 * @description The real clock: the time now, and a wait that ends early when the run is interrupted.
 *
 * @param {object} [signal] `{interrupted}`, set to true by the interrupt handler.
 *
 * @returns {{now: Function, sleep: Function}}
 */
function createClock(signal = {interrupted: false})
{
	return {
		now: () => Date.now(),
		sleep: async(milliseconds) =>
		{
			const end = Date.now() + milliseconds;
			while(Date.now() < end)
			{
				if(signal.interrupted)
				{
					throw new InterruptedError();
				}
				await new Promise((resolve) => setTimeout(resolve, Math.min(SLEEP_SLICE_MILLISECONDS, end - Date.now())));
			}
			if(signal.interrupted)
			{
				throw new InterruptedError();
			}
		}
	};
}

/**
 * @description Reads until a condition holds or a time limit passes. The first read is at once; each later read
 * waits the interval first.
 *
 * @param {object} options `read` (returns the value), `isDone` (value to boolean), `intervalMilliseconds`,
 *                         `timeLimitMilliseconds`, `clock` (`{now, sleep}`).
 *
 * @returns {Promise<{done: boolean, value: *, reads: number}>} The last value read.
 */
async function pollUntil({read, isDone, intervalMilliseconds, timeLimitMilliseconds, clock})
{
	const deadline = clock.now() + timeLimitMilliseconds;
	let reads = 0;
	// The outcome stays null while the wait goes on.
	let outcome = null;
	while(outcome === null)
	{
		const value = await read();
		reads++;
		if(isDone(value))
		{
			outcome = {done: true, value, reads};
		}
		else if(clock.now() + intervalMilliseconds > deadline)
		{
			outcome = {done: false, value, reads};
		}
		else
		{
			await clock.sleep(intervalMilliseconds);
		}
	}
	return outcome;
}

/**
 * @description Waits until a moment, in steps, so an interrupt still ends the wait.
 *
 * @param {number} moment The time to wait for, in milliseconds since 1970.
 * @param {object} clock `{now, sleep}`.
 *
 * @returns {Promise<void>}
 */
async function waitUntil(moment, clock)
{
	const wait = moment - clock.now();
	if(wait > 0)
	{
		await clock.sleep(wait);
	}
}

module.exports = {InterruptedError, createClock, pollUntil, waitUntil};
