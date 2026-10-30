// SPDX-License-Identifier: Apache-2.0
/**
 * @description Measures elapsed wall-clock time. Provides the foundational timing API that
 * specialised performance timers build on.
 *
 * **Class Hierarchy:**
 * ```apex
 * UTIL_StopWatch (this class - foundational timing)
 *     ├── UTIL_PerformanceTimer      (general API/operation performance logging)
 *     ├── UTIL_QueryPerformanceTimer (database query performance logging)
 *     └── UTIL_TriggerPerformanceTimer (trigger action performance logging)
 * ```
 *
 * **Design Note:** The three performance timer subclasses share similar patterns (governor limit
 * tracking, fluent API, threshold-based logging) but are intentionally kept as separate implementations
 * rather than using an abstract base class. This trades some code duplication (~150 lines) for:
 * - Simpler debugging (each class is self-contained)
 * - Easier understanding (no need to trace through multiple inheritance levels)
 * - Independent evolution (changes to one timer don't risk breaking others)
 *
 * Consider refactoring to an abstract base class if adding a 4th+ timer type.
 *
 * @see UTIL_PerformanceTimer
 * @see UTIL_QueryPerformanceTimer
 * @see UTIL_TriggerPerformanceTimer
 * @see UTIL_StopWatch_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, October 2026
 *
 * @example
 * ```apex
 * UTIL_StopWatch timer = new UTIL_StopWatch();
 * timer.start();
 * // ... perform operation ...
 * timer.stop();
 * Long elapsedMillis = timer.getTime();
 * ```
 */
public virtual inherited sharing class UTIL_StopWatch
{
	/**
	 * @description The stage a timer is at: not started, running, or stopped. A stopped timer has to be cleared before it can run again.
	 */
	private enum RunState
	{
		/**
		 * @description Not started: a new timer, or one that has been cleared. No time has been measured.
		 */
		IDLE,
		/**
		 * @description Running: time is being measured and the elapsed time is still growing.
		 */
		ACTIVE,
		/**
		 * @description Stopped: the measured time is final and no longer changes.
		 */
		FINISHED
	}

	/**
	 * @description Epoch millis when timing began.
	 */
	private Long startedAt = 0;

	/**
	 * @description Epoch millis when timing ended.
	 */
	private Long endedAt = 0;

	/**
	 * @description Current lifecycle phase of the timer.
	 */
	private RunState state = RunState.IDLE;

	/**
	 * @description Returns the milliseconds that have elapsed since timing began.
	 * While active, the value increases on every call. Once stopped, the value is frozen.
	 *
	 * @return Elapsed duration in milliseconds, or 0 when the timer has never been started.
	 *
	 * @example
	 * ```apex
	 * UTIL_StopWatch timer = new UTIL_StopWatch();
	 * timer.start();
	 * timer.stop();
	 * Long elapsed = timer.getTime();
	 * ```
	 */
	public Long getTime()
	{
		if(state == RunState.FINISHED)
		{
			return endedAt - startedAt;
		}
		if(state == RunState.ACTIVE)
		{
			return System.currentTimeMillis() - startedAt;
		}
		return 0;
	}

	/**
	 * @description Begins tracking elapsed time. Can only be called on a timer that is idle (new or reset).
	 *
	 * @throws UTIL_Exceptions.IllegalStateException when the timer is already active or has finished without a reset.
	 *
	 * @example
	 * ```apex
	 * UTIL_StopWatch timer = new UTIL_StopWatch();
	 * timer.start();
	 * ```
	 */
	public virtual void start()
	{
		if(state == RunState.FINISHED)
		{
			throw new UTIL_Exceptions.IllegalStateException('Stopwatch must be reset before being restarted.');
		}
		if(state != RunState.IDLE)
		{
			throw new UTIL_Exceptions.IllegalStateException('Stopwatch already started.');
		}
		endedAt = 0;
		startedAt = System.currentTimeMillis();
		state = RunState.ACTIVE;
	}

	/**
	 * @description Halts time tracking and freezes the elapsed duration.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException when the timer is idle or already finished.
	 *
	 * @example
	 * ```apex
	 * UTIL_StopWatch timer = new UTIL_StopWatch();
	 * timer.start();
	 * timer.stop();
	 * Long elapsed = timer.getTime();
	 * ```
	 */
	public virtual void stop()
	{
		if(state != RunState.ACTIVE)
		{
			throw new UTIL_Exceptions.IllegalStateException('Stopwatch is not running.');
		}
		endedAt = System.currentTimeMillis();
		state = RunState.FINISHED;
	}

	/**
	 * @description Returns the timer to its initial idle state, discarding all recorded durations.
	 *
	 * @example
	 * ```apex
	 * UTIL_StopWatch timer = new UTIL_StopWatch();
	 * timer.start();
	 * timer.stop();
	 * timer.reset();
	 * ```
	 */
	public void reset()
	{
		state = RunState.IDLE;
		startedAt = 0;
		endedAt = 0;
	}
}