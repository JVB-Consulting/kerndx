// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the PlatformEventUsageMetric SObject. Provides default field configuration
 * and query methods for platform event usage statistics.
 *
 * @see SEL_Base
 * @see SEL_PlatformEventUsageMetric_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date November 2025, June 2026
 */
public inherited sharing class SEL_PlatformEventUsageMetric extends SEL_Base
{
	/**
	 * @description Usage-metric granularities. Each member name matches the `TimeSegment` picklist
	 * api value the platform expects in SOQL, so `name()` is both the on-the-wire contract value and
	 * the SOQL filter literal. The PascalCase member names are load-bearing (renaming to upper-snake
	 * would break that contract), hence the FieldNamingConventions suppression.
	 */
	@SuppressWarnings('PMD.FieldNamingConventions')
	public enum TimeSegment
	{
		/**
		 * @description Daily buckets — the only granularity available without Enhanced Usage Metrics.
		 */
		Daily,
		/**
		 * @description Hourly buckets — requires Enhanced Usage Metrics; valid for ranges up to 24 hours.
		 */
		Hourly,
		/**
		 * @description Fifteen-minute buckets — requires Enhanced Usage Metrics; valid for ranges up to 1 hour.
		 */
		FifteenMinutes
	}

	/**
	 * @description Maximum query window per granularity, in minutes. The PlatformEventUsageMetric
	 * UDD query validator rejects wider ranges (`TimeIntervalTooLargeException` above 30 days;
	 * `TimeSegmentValueTooSmallException` when a fine segment spans too long an interval). Values were
	 * verified live against the platform and are undocumented — treat them as defensive UX, not a
	 * published contract.
	 */
	private static final Map<TimeSegment, Integer> MAX_RANGE_MINUTES_BY_SEGMENT = new Map<TimeSegment, Integer>
	{
			TimeSegment.Daily => 30 * 24 * 60,
			TimeSegment.Hourly => 24 * 60,
			TimeSegment.FifteenMinutes => 60
	};

	/**
	 * @description Minimum query window per granularity, in minutes — one bucket. The same UDD
	 * validator rejects ranges narrower than a single bucket of the requested segment with
	 * `TimeSegmentValueTooLargeException` ("the TimeSegment value can't exceed the time interval"),
	 * rather than returning an empty result. The bound is inclusive — a range exactly one bucket wide
	 * queries cleanly (live-verified; bucket boundary alignment is NOT required, only the span).
	 */
	private static final Map<TimeSegment, Integer> MIN_RANGE_MINUTES_BY_SEGMENT = new Map<TimeSegment, Integer>
	{
			TimeSegment.Daily => 24 * 60,
			TimeSegment.Hourly => 60,
			TimeSegment.FifteenMinutes => 15
	};

	/**
	 * @description Human-readable form of each granularity's maximum query window, sourced from
	 * Custom Labels so the duration shown to subscribers stays translatable. Paired with
	 * `MAX_RANGE_MINUTES_BY_SEGMENT` — both must describe the same window per segment.
	 */
	private static final Map<TimeSegment, String> MAX_RANGE_HUMAN_BY_SEGMENT = new Map<TimeSegment, String>
	{
			TimeSegment.Daily => System.Label.EventUsageMetrics_Window_Daily,
			TimeSegment.Hourly => System.Label.EventUsageMetrics_Window_Hourly,
			TimeSegment.FifteenMinutes => System.Label.EventUsageMetrics_Window_FifteenMinutes
	};

	/**
	 * @description Human-readable form of each granularity's minimum query range (one bucket),
	 * sourced from Custom Labels so the duration shown to subscribers stays translatable. Paired with
	 * `MIN_RANGE_MINUTES_BY_SEGMENT` — both must describe the same bucket length per segment.
	 */
	private static final Map<TimeSegment, String> MIN_RANGE_HUMAN_BY_SEGMENT = new Map<TimeSegment, String>
	{
			TimeSegment.Daily => System.Label.EventUsageMetrics_Minimum_Daily,
			TimeSegment.Hourly => System.Label.EventUsageMetrics_Minimum_Hourly,
			TimeSegment.FifteenMinutes => System.Label.EventUsageMetrics_Minimum_FifteenMinutes
	};

	/**
	 * @description Api name of the org-capability-dependent TimeSegment field. Referenced as a
	 * string — a compile-time SObjectField token would fail to compile in subscriber orgs that
	 * have not enabled Enhanced Usage Metrics.
	 */
	private static final String TIME_SEGMENT_FIELD_NAME = 'TimeSegment';

	/**
	 * @description Test seam for the TimeSegment availability probe. Lets unit tests exercise
	 * both the enhanced and legacy query branches irrespective of org capability.
	 */
	@TestVisible
	private static Boolean timeSegmentAvailableOverride;

	/**
	 * @description Constructs a PlatformEventUsageMetric selector.
	 */
	public SEL_PlatformEventUsageMetric()
	{
		super(PlatformEventUsageMetric.SObjectType);
	}

	/**
	 * @description Returns the core fields for PlatformEventUsageMetric queries.
	 *
	 * @return List of PlatformEventUsageMetric SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				PlatformEventUsageMetric.EndDate,
				PlatformEventUsageMetric.Name,
				PlatformEventUsageMetric.StartDate,
				PlatformEventUsageMetric.Value
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. PlatformEventUsageMetric is Setup
	 * audit data that running users can't read, so USER_MODE reads would return empty and
	 * framework platform-event health-check machinery would silently stop reporting.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Returns the maximum query window (in minutes) the platform permits for the given
	 * granularity. Callers must constrain their StartDate/EndDate span to this before querying.
	 *
	 * @param segment The granularity.
	 *
	 * @return The maximum span in minutes for that granularity.
	 */
	public static Integer maxRangeMinutes(TimeSegment segment)
	{
		return MAX_RANGE_MINUTES_BY_SEGMENT.get(segment);
	}

	/**
	 * @description Returns the human-readable maximum query window for the given granularity (for
	 * example "24 hours"), for substitution into the range-too-wide validation message. The phrase
	 * is label-sourced rather than a hardcoded literal so subscribers can translate it.
	 *
	 * @param segment The granularity.
	 *
	 * @return The label-sourced maximum-window phrase for that granularity.
	 */
	public static String maxRangeHuman(TimeSegment segment)
	{
		return MAX_RANGE_HUMAN_BY_SEGMENT.get(segment);
	}

	/**
	 * @description Returns the minimum query range (in minutes) the platform permits for the given
	 * granularity — one bucket. Callers must ensure their StartDate/EndDate span at least this before
	 * querying; the platform rejects narrower ranges outright instead of returning empty.
	 *
	 * @param segment The granularity.
	 *
	 * @return The minimum span in minutes for that granularity.
	 */
	public static Integer minRangeMinutes(TimeSegment segment)
	{
		return MIN_RANGE_MINUTES_BY_SEGMENT.get(segment);
	}

	/**
	 * @description Returns the human-readable minimum query range for the given granularity (for
	 * example "1 hour"), for substitution into the range-too-narrow validation message. The phrase
	 * is label-sourced rather than a hardcoded literal so subscribers can translate it.
	 *
	 * @param segment The granularity.
	 *
	 * @return The label-sourced minimum-range phrase for that granularity.
	 */
	public static String minRangeHuman(TimeSegment segment)
	{
		return MIN_RANGE_HUMAN_BY_SEGMENT.get(segment);
	}

	/**
	 * @description Resolves a raw segment string (as received across the Aura boundary) to a
	 * TimeSegment value. Matching is case-insensitive (Apex String `==` semantics).
	 *
	 * @param value The candidate segment string.
	 *
	 * @return The matching TimeSegment, or null when the string matches no member.
	 */
	public static TimeSegment toTimeSegment(String value)
	{
		for(TimeSegment segment : TimeSegment.values())
		{
			if(segment.name() == value)
			{
				return segment;
			}
		}

		return null;
	}

	/**
	 * @description Probes whether the org exposes Enhanced Usage Metrics by checking the
	 * PlatformEventUsageMetric describe for the TimeSegment field through the request-cached
	 * `UTIL_SObjectDescribe` wrapper. TimeSegment is a standard field, so the lookup pins
	 * `implyNamespace = false`. The field is absent on orgs that have not enabled Enhanced Usage
	 * Metrics, so a non-null lookup means the feature is on.
	 *
	 * @return `true` when the TimeSegment field exists (Enhanced Usage Metrics enabled).
	 */
	public static Boolean isTimeSegmentAvailable()
	{
		if(timeSegmentAvailableOverride != null)
		{
			return timeSegmentAvailableOverride;
		}

		return UTIL_SObjectDescribe.getDescribe(PlatformEventUsageMetric.SObjectType).getField(TIME_SEGMENT_FIELD_NAME, false) != null;
	}

	/**
	 * @description Retrieves usage metrics filtered by time segment and date range, ordered by start
	 * date ascending. On orgs with Enhanced Usage Metrics the TimeSegment field is added to the
	 * projection and filtered to the requested segment; on legacy orgs the segment is ignored and
	 * daily rows are returned.
	 *
	 * The caller is responsible for supplying non-null dates whose span is within
	 * `maxRangeMinutes(segment)` — the platform UDD query validator rejects wider ranges.
	 * `CTRL_EventMonitor.getEventUsageMetrics` applies the per-segment defaults and validation; this
	 * method trusts its inputs.
	 *
	 * Implementation note: each branch is a single unbroken fluent chain ending in `toList()` — the
	 * condition methods return the fluent condition type, not the builder, so an intermediate
	 * reassignment to a `QRY_Builder.Builder` local would not compile.
	 *
	 * @param segment The granularity to filter to; its `name()` is the SOQL TimeSegment value.
	 * @param startDate Inclusive lower bound on StartDate.
	 * @param endDate Inclusive upper bound on EndDate.
	 *
	 * @return List of PlatformEventUsageMetric records ordered by StartDate.
	 */
	public List<PlatformEventUsageMetric> getBySegmentAndDateRange(TimeSegment segment, Datetime startDate, Datetime endDate)
	{
		if(isTimeSegmentAvailable())
		{
			return query
					.addField(TIME_SEGMENT_FIELD_NAME)
					.condition(TIME_SEGMENT_FIELD_NAME).equals(segment.name())
					.condition(PlatformEventUsageMetric.StartDate).greaterThanOrEquals(startDate)
					.condition(PlatformEventUsageMetric.EndDate).lessThanOrEquals(endDate)
					.orderBy(PlatformEventUsageMetric.StartDate)
					.toList();
		}

		return query
				.condition(PlatformEventUsageMetric.StartDate).greaterThanOrEquals(startDate)
				.condition(PlatformEventUsageMetric.EndDate).lessThanOrEquals(endDate)
				.orderBy(PlatformEventUsageMetric.StartDate)
				.toList();
	}
}