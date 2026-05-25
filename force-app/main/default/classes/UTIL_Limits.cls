// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Fluent interface for inspecting Salesforce governor limits. Provides named factory methods
 * per limit type for IDE discoverability and a LimitCheck builder for threshold and exhaustion checks.
 *
 * @see UTIL_Limits_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date April 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_Limits.callouts().isExhausted();
 * UTIL_Limits.soqlQueries().isNearLimit(0.8);
 * UTIL_Limits.cpuTime().remaining();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_Limits
{
	/**
	 * @description Internal enumeration of all supported Salesforce governor limit types.
	 */
	private enum LimitType
	{
		AGGREGATE_QUERIES,
		CALLOUTS,
		CPU_TIME,
		DML_ROWS,
		DML_STATEMENTS,
		EMAIL_INVOCATIONS,
		FUTURE_CALLS,
		HEAP_SIZE,
		MOBILE_PUSH_APEX_CALLS,
		PUBLISH_IMMEDIATE_DML,
		SOQL_QUERIES,
		SOQL_QUERY_ROWS,
		SOQL_QUERY_LOCATOR_ROWS,
		QUEUEABLE_JOBS,
		SOSL_QUERIES
	}

	/**
	 * @description Maps each limit type to its human-readable label, matching the format used by LOG_Engine.
	 */
	private static final Map<LimitType, String> LABELS = new Map<LimitType, String>
	{
			LimitType.AGGREGATE_QUERIES => 'Aggregate Queries',
			LimitType.CALLOUTS => 'Callouts',
			LimitType.CPU_TIME => 'Cpu Time',
			LimitType.DML_ROWS => 'DML Rows',
			LimitType.DML_STATEMENTS => 'DML Statements',
			LimitType.EMAIL_INVOCATIONS => 'Email Invocations',
			LimitType.FUTURE_CALLS => 'Future Calls',
			LimitType.HEAP_SIZE => 'Heap Size',
			LimitType.MOBILE_PUSH_APEX_CALLS => 'Mobile Push Apex Calls',
			LimitType.PUBLISH_IMMEDIATE_DML => 'Publish Immediate DML',
			LimitType.SOQL_QUERIES => 'Queries',
			LimitType.SOQL_QUERY_ROWS => 'Query Rows',
			LimitType.SOQL_QUERY_LOCATOR_ROWS => 'QueryLocator Rows',
			LimitType.QUEUEABLE_JOBS => 'Queueable Jobs',
			LimitType.SOSL_QUERIES => 'Sosl Queries'
	};

	/**
	 * @description Returns a LimitCheck for aggregate queries.
	 *
	 * @return LimitCheck scoped to aggregate queries
	 *
	 * @since 1.0
	 */
	global static LimitCheck aggregateQueries()
	{
		return new LimitCheck(LimitType.AGGREGATE_QUERIES);
	}

	/**
	 * @description Returns a LimitCheck for HTTP callouts.
	 *
	 * @return LimitCheck scoped to callouts
	 *
	 * @since 1.0
	 */
	global static LimitCheck callouts()
	{
		return new LimitCheck(LimitType.CALLOUTS);
	}

	/**
	 * @description Returns a LimitCheck for CPU time (milliseconds).
	 *
	 * @return LimitCheck scoped to CPU time
	 *
	 * @since 1.0
	 */
	global static LimitCheck cpuTime()
	{
		return new LimitCheck(LimitType.CPU_TIME);
	}

	/**
	 * @description Returns a LimitCheck for DML rows.
	 *
	 * @return LimitCheck scoped to DML rows
	 *
	 * @since 1.0
	 */
	global static LimitCheck dmlRows()
	{
		return new LimitCheck(LimitType.DML_ROWS);
	}

	/**
	 * @description Returns a LimitCheck for DML statements.
	 *
	 * @return LimitCheck scoped to DML statements
	 *
	 * @since 1.0
	 */
	global static LimitCheck dmlStatements()
	{
		return new LimitCheck(LimitType.DML_STATEMENTS);
	}

	/**
	 * @description Returns a LimitCheck for email invocations.
	 *
	 * @return LimitCheck scoped to email invocations
	 *
	 * @since 1.0
	 */
	global static LimitCheck emailInvocations()
	{
		return new LimitCheck(LimitType.EMAIL_INVOCATIONS);
	}

	/**
	 * @description Returns a LimitCheck for future calls.
	 *
	 * @return LimitCheck scoped to future calls
	 *
	 * @since 1.0
	 */
	global static LimitCheck futureCalls()
	{
		return new LimitCheck(LimitType.FUTURE_CALLS);
	}

	/**
	 * @description Returns a LimitCheck for heap size (bytes).
	 *
	 * @return LimitCheck scoped to heap size
	 *
	 * @since 1.0
	 */
	global static LimitCheck heapSize()
	{
		return new LimitCheck(LimitType.HEAP_SIZE);
	}

	/**
	 * @description Returns a LimitCheck for mobile push Apex calls.
	 *
	 * @return LimitCheck scoped to mobile push Apex calls
	 *
	 * @since 1.0
	 */
	global static LimitCheck mobilePushApexCalls()
	{
		return new LimitCheck(LimitType.MOBILE_PUSH_APEX_CALLS);
	}

	/**
	 * @description Returns a LimitCheck for publish immediate DML operations.
	 *
	 * @return LimitCheck scoped to publish immediate DML
	 *
	 * @since 1.0
	 */
	global static LimitCheck publishImmediateDml()
	{
		return new LimitCheck(LimitType.PUBLISH_IMMEDIATE_DML);
	}

	/**
	 * @description Returns a LimitCheck for SOQL queries.
	 *
	 * @return LimitCheck scoped to SOQL queries
	 *
	 * @since 1.0
	 */
	global static LimitCheck soqlQueries()
	{
		return new LimitCheck(LimitType.SOQL_QUERIES);
	}

	/**
	 * @description Returns a LimitCheck for SOQL query rows.
	 *
	 * @return LimitCheck scoped to SOQL query rows
	 *
	 * @since 1.0
	 */
	global static LimitCheck soqlQueryRows()
	{
		return new LimitCheck(LimitType.SOQL_QUERY_ROWS);
	}

	/**
	 * @description Returns a LimitCheck for SOQL query locator rows.
	 *
	 * @return LimitCheck scoped to SOQL query locator rows
	 *
	 * @since 1.0
	 */
	global static LimitCheck soqlQueryLocatorRows()
	{
		return new LimitCheck(LimitType.SOQL_QUERY_LOCATOR_ROWS);
	}

	/**
	 * @description Returns a LimitCheck for queueable jobs.
	 *
	 * @return LimitCheck scoped to queueable jobs
	 *
	 * @since 1.0
	 */
	global static LimitCheck queueableJobs()
	{
		return new LimitCheck(LimitType.QUEUEABLE_JOBS);
	}

	/**
	 * @description Returns a LimitCheck for SOSL queries.
	 *
	 * @return LimitCheck scoped to SOSL queries
	 *
	 * @since 1.0
	 */
	global static LimitCheck soslQueries()
	{
		return new LimitCheck(LimitType.SOSL_QUERIES);
	}

	/**
	 * @description Returns a LimitCheck for every governor limit type.
	 *
	 * @return List of LimitCheck instances, one per limit type
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<UTIL_Limits.LimitCheck> allLimits = UTIL_Limits.snapshot();
	 * ```
	 */
	global static List<LimitCheck> snapshot()
	{
		List<LimitCheck> checks = new List<LimitCheck>();

		for(LimitType limitType : LimitType.values())
		{
			checks.add(new LimitCheck(limitType));
		}

		return checks;
	}

	/**
	 * @description Returns a human-readable summary of all governor limits in the format "Label: used of maximum".
	 *
	 * @return Multi-line string with one line per limit type
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String limitsDebug = UTIL_Limits.toDebugString();
	 * ```
	 */
	global static String toDebugString()
	{
		List<String> lines = new List<String>();

		for(LimitCheck check : snapshot())
		{
			lines.add(check.label + ': ' + check.used() + ' of ' + check.maximum());
		}

		return UTIL_String.LF + String.join(lines, UTIL_String.LF);
	}

	/**
	 * @description Fluent limit inspector scoped to a single governor limit type. Provides methods
	 * to check remaining budget, usage percentage, exhaustion, and threshold proximity.
	 *
	 * @since 1.0
	 */
	global class LimitCheck
	{
		/**
		 * @description The internal limit type this check is scoped to.
		 */
		private final LimitType limitType;

		/**
		 * @description The human-readable label for this limit type (e.g. "Callouts", "Queries").
		 */
		global final String label;

		/**
		 * @description Constructs a LimitCheck scoped to the given limit type.
		 *
		 * @param limitType The governor limit type to inspect
		 */
		private LimitCheck(LimitType limitType)
		{
			this.limitType = limitType;
			this.label = getLabel(limitType);
		}

		/**
		 * @description Returns the number of limit units consumed in this transaction.
		 *
		 * @return Current usage count
		 *
		 * @since 1.0
		 */
		global Integer used()
		{
			return getUsed(limitType);
		}

		/**
		 * @description Returns the maximum allowed units for this limit type.
		 *
		 * @return Governor limit maximum
		 *
		 * @since 1.0
		 */
		global Integer maximum()
		{
			return getMaximum(limitType);
		}

		/**
		 * @description Returns the number of limit units remaining before the governor limit is hit.
		 *
		 * @return Remaining budget (maximum - used)
		 *
		 * @since 1.0
		 */
		global Integer remaining()
		{
			return maximum() - used();
		}

		/**
		 * @description Returns the percentage of the limit consumed as a value between 0.0 and 1.0.
		 *
		 * @return Usage percentage (0.0 = none used, 1.0 = fully exhausted)
		 *
		 * @since 1.0
		 */
		global Decimal percentUsed()
		{
			return Decimal.valueOf(used()).divide(maximum(), 4);
		}

		/**
		 * @description Returns whether the limit has been fully consumed (no remaining budget).
		 *
		 * @return True when remaining() is less than or equal to zero
		 *
		 * @since 1.0
		 */
		global Boolean isExhausted()
		{
			return remaining() <= 0;
		}

		/**
		 * @description Returns whether usage has reached or exceeded the given threshold. Values greater
		 * than 1.0 are automatically normalised by dividing by 100 (e.g. 80 becomes 0.8).
		 *
		 * @param threshold The threshold as a decimal (0.0–1.0) or percentage (e.g. 80 for 80%)
		 *
		 * @return True when percentUsed() is at or above the normalised threshold
		 *
		 * @since 1.0
		 */
		global Boolean isNearLimit(Decimal threshold)
		{
			Decimal normalised = threshold > 1.0 ? threshold / 100 : threshold;
			return percentUsed() >= normalised;
		}
	}

	/**
	 * @description Returns the human-readable label for a limit type.
	 *
	 * @param limitType The limit type to label
	 *
	 * @return Display label (e.g. "Callouts", "Queries", "Heap Size")
	 */
	private static String getLabel(LimitType limitType)
	{
		return LABELS.get(limitType);
	}

	/**
	 * @description Returns the current consumption value for a limit type by delegating to the
	 * corresponding Limits.getX() method.
	 *
	 * @param limitType The limit type to query
	 *
	 * @return Current usage count
	 */
	private static Integer getUsed(LimitType limitType)
	{
		Integer result = 0;

		switch on limitType
		{
			when AGGREGATE_QUERIES
			{
				result = Limits.getAggregateQueries();
			}
			when CALLOUTS
			{
				result = Limits.getCallouts();
			}
			when CPU_TIME
			{
				result = Limits.getCpuTime();
			}
			when DML_ROWS
			{
				result = Limits.getDmlRows();
			}
			when DML_STATEMENTS
			{
				result = Limits.getDmlStatements();
			}
			when EMAIL_INVOCATIONS
			{
				result = Limits.getEmailInvocations();
			}
			when FUTURE_CALLS
			{
				result = Limits.getFutureCalls();
			}
			when HEAP_SIZE
			{
				result = Limits.getHeapSize();
			}
			when MOBILE_PUSH_APEX_CALLS
			{
				result = Limits.getMobilePushApexCalls();
			}
			when PUBLISH_IMMEDIATE_DML
			{
				result = Limits.getPublishImmediateDML();
			}
			when SOQL_QUERIES
			{
				result = Limits.getQueries();
			}
			when SOQL_QUERY_ROWS
			{
				result = Limits.getQueryRows();
			}
			when SOQL_QUERY_LOCATOR_ROWS
			{
				result = Limits.getQueryLocatorRows();
			}
			when QUEUEABLE_JOBS
			{
				result = Limits.getQueueableJobs();
			}
			when SOSL_QUERIES
			{
				result = Limits.getSoslQueries();
			}
		}

		return result;
	}

	/**
	 * @description Returns the governor limit maximum for a limit type by delegating to the
	 * corresponding Limits.getLimitX() method.
	 *
	 * @param limitType The limit type to query
	 *
	 * @return Governor limit maximum
	 */
	private static Integer getMaximum(LimitType limitType)
	{
		Integer result = 0;

		switch on limitType
		{
			when AGGREGATE_QUERIES
			{
				result = Limits.getLimitAggregateQueries();
			}
			when CALLOUTS
			{
				result = Limits.getLimitCallouts();
			}
			when CPU_TIME
			{
				result = Limits.getLimitCpuTime();
			}
			when DML_ROWS
			{
				result = Limits.getLimitDmlRows();
			}
			when DML_STATEMENTS
			{
				result = Limits.getLimitDmlStatements();
			}
			when EMAIL_INVOCATIONS
			{
				result = Limits.getLimitEmailInvocations();
			}
			when FUTURE_CALLS
			{
				result = Limits.getLimitFutureCalls();
			}
			when HEAP_SIZE
			{
				result = Limits.getLimitHeapSize();
			}
			when MOBILE_PUSH_APEX_CALLS
			{
				result = Limits.getLimitMobilePushApexCalls();
			}
			when PUBLISH_IMMEDIATE_DML
			{
				result = Limits.getLimitPublishImmediateDML();
			}
			when SOQL_QUERIES
			{
				result = Limits.getLimitQueries();
			}
			when SOQL_QUERY_ROWS
			{
				result = Limits.getLimitQueryRows();
			}
			when SOQL_QUERY_LOCATOR_ROWS
			{
				result = Limits.getLimitQueryLocatorRows();
			}
			when QUEUEABLE_JOBS
			{
				result = Limits.getLimitQueueableJobs();
			}
			when SOSL_QUERIES
			{
				result = Limits.getLimitSoslQueries();
			}
		}

		return result;
	}
}