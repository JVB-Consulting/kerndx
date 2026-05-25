// SPDX-License-Identifier: BUSL-1.1
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
 * @date February 2026, May 2026
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
	private enum RunState
	{
		IDLE,
		ACTIVE,
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
		if(this.state == RunState.FINISHED)
		{
			return this.endedAt - this.startedAt;
		}
		if(this.state == RunState.ACTIVE)
		{
			return System.currentTimeMillis() - this.startedAt;
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
		if(this.state == RunState.FINISHED)
		{
			throw new UTIL_Exceptions.IllegalStateException('Stopwatch must be reset before being restarted.');
		}
		if(this.state != RunState.IDLE)
		{
			throw new UTIL_Exceptions.IllegalStateException('Stopwatch already started.');
		}
		this.endedAt = 0;
		this.startedAt = System.currentTimeMillis();
		this.state = RunState.ACTIVE;
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
		if(this.state != RunState.ACTIVE)
		{
			throw new UTIL_Exceptions.IllegalStateException('Stopwatch is not running.');
		}
		this.endedAt = System.currentTimeMillis();
		this.state = RunState.FINISHED;
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
		this.state = RunState.IDLE;
		this.startedAt = 0;
		this.endedAt = 0;
	}
}