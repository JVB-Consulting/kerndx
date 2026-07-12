// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_PlatformEventUsageMetric selector.
 *
 * @see SEL_PlatformEventUsageMetric
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, June 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_PlatformEventUsageMetric_TEST
{
	/**
	 * @description Tests that maxRangeMinutes returns the per-segment platform query window.
	 */
	@IsTest
	private static void shouldExposeMaxRangeMinutesPerSegment()
	{
		Assert.areEqual(30 * 24 * 60, SEL_PlatformEventUsageMetric.maxRangeMinutes(SEL_PlatformEventUsageMetric.TimeSegment.Daily), 'Daily window should be 30 days');
		Assert.areEqual(24 * 60, SEL_PlatformEventUsageMetric.maxRangeMinutes(SEL_PlatformEventUsageMetric.TimeSegment.Hourly), 'Hourly window should be 24 hours');
		Assert.areEqual(60, SEL_PlatformEventUsageMetric.maxRangeMinutes(SEL_PlatformEventUsageMetric.TimeSegment.FifteenMinutes), 'FifteenMinutes window should be 1 hour');
	}

	/**
	 * @description Tests that maxRangeHuman returns the label-sourced window phrase for each segment.
	 */
	@IsTest
	private static void shouldExposeMaxRangeHumanPerSegment()
	{
		Assert.areEqual
				(
						System.Label.EventUsageMetrics_Window_Daily,
						SEL_PlatformEventUsageMetric.maxRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.Daily),
						'Daily should map to its window label'
				);
		Assert.areEqual
				(
						System.Label.EventUsageMetrics_Window_Hourly,
						SEL_PlatformEventUsageMetric.maxRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.Hourly),
						'Hourly should map to its window label'
				);
		Assert.areEqual
				(
						System.Label.EventUsageMetrics_Window_FifteenMinutes,
						SEL_PlatformEventUsageMetric.maxRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.FifteenMinutes),
						'FifteenMinutes should map to its window label'
				);

		Set<String> distinctPhrases = new Set<String>
		{
				SEL_PlatformEventUsageMetric.maxRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.Daily),
				SEL_PlatformEventUsageMetric.maxRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.Hourly),
				SEL_PlatformEventUsageMetric.maxRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.FifteenMinutes)
		};

		Assert.areEqual(3, distinctPhrases.size(), 'Each granularity must map to a distinct window phrase');
	}

	/**
	 * @description Tests that minRangeMinutes returns one bucket per segment — the live-verified
	 * platform minimum below which the UDD validator rejects the query outright.
	 */
	@IsTest
	private static void shouldExposeMinRangeMinutesPerSegment()
	{
		Assert.areEqual(24 * 60, SEL_PlatformEventUsageMetric.minRangeMinutes(SEL_PlatformEventUsageMetric.TimeSegment.Daily), 'Daily minimum should be 1 day');
		Assert.areEqual(60, SEL_PlatformEventUsageMetric.minRangeMinutes(SEL_PlatformEventUsageMetric.TimeSegment.Hourly), 'Hourly minimum should be 1 hour');
		Assert.areEqual(15, SEL_PlatformEventUsageMetric.minRangeMinutes(SEL_PlatformEventUsageMetric.TimeSegment.FifteenMinutes), 'FifteenMinutes minimum should be 15 minutes');
	}

	/**
	 * @description Tests that minRangeHuman returns the label-sourced minimum phrase for each segment.
	 */
	@IsTest
	private static void shouldExposeMinRangeHumanPerSegment()
	{
		Assert.areEqual
				(
						System.Label.EventUsageMetrics_Minimum_Daily,
						SEL_PlatformEventUsageMetric.minRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.Daily),
						'Daily should map to its minimum label'
				);
		Assert.areEqual
				(
						System.Label.EventUsageMetrics_Minimum_Hourly,
						SEL_PlatformEventUsageMetric.minRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.Hourly),
						'Hourly should map to its minimum label'
				);
		Assert.areEqual
				(
						System.Label.EventUsageMetrics_Minimum_FifteenMinutes,
						SEL_PlatformEventUsageMetric.minRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.FifteenMinutes),
						'FifteenMinutes should map to its minimum label'
				);

		Set<String> distinctPhrases = new Set<String>
		{
				SEL_PlatformEventUsageMetric.minRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.Daily),
				SEL_PlatformEventUsageMetric.minRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.Hourly),
				SEL_PlatformEventUsageMetric.minRangeHuman(SEL_PlatformEventUsageMetric.TimeSegment.FifteenMinutes)
		};

		Assert.areEqual(3, distinctPhrases.size(), 'Each granularity must map to a distinct minimum phrase');
	}

	/**
	 * @description Tests that the TimeSegment availability probe reflects the live org schema when
	 * no test override is set. The expected value is computed from a raw describe so the oracle is
	 * independent of the cached wrapper the probe uses; child relationships are deferred
	 * (SObjectDescribeOptions.DEFERRED) since only the field map is read.
	 */
	@IsTest
	private static void shouldDetectTimeSegmentAvailabilityFromSchema()
	{
		Boolean expected = PlatformEventUsageMetric.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap().containsKey('timesegment');

		Assert.areEqual(expected, SEL_PlatformEventUsageMetric.isTimeSegmentAvailable(), 'Probe should mirror the describe result');
	}

	/**
	 * @description Tests that toTimeSegment resolves known segment strings (case-insensitively) and
	 * returns null for unsupported values.
	 */
	@IsTest
	private static void shouldResolveTimeSegmentStrings()
	{
		Assert.areEqual(SEL_PlatformEventUsageMetric.TimeSegment.FifteenMinutes, SEL_PlatformEventUsageMetric.toTimeSegment('FifteenMinutes'), 'Exact-case string should resolve');
		Assert.areEqual(SEL_PlatformEventUsageMetric.TimeSegment.Daily, SEL_PlatformEventUsageMetric.toTimeSegment('daily'), 'Lower-case string should resolve (case-insensitive)');
		Assert.isNull(SEL_PlatformEventUsageMetric.toTimeSegment('Weekly'), 'Unknown string should resolve to null');
	}

	/**
	 * @description Tests the segment-and-range query on the legacy (probe-off) branch: no
	 * TimeSegment projection or condition, the supplied range applied.
	 */
	@IsTest
	private static void shouldGetBySegmentAndDateRangeLegacyBranch()
	{
		SEL_PlatformEventUsageMetric.timeSegmentAvailableOverride = false;

		TST_Mock.of(PlatformEventUsageMetric.SObjectType)
				.withOverride(PlatformEventUsageMetric.Name, 'PLATFORM_EVENTS_PUBLISHED')
				.withOverride(PlatformEventUsageMetric.Value, 42)
				.build();

		List<PlatformEventUsageMetric> results = new SEL_PlatformEventUsageMetric()
				.getBySegmentAndDateRange(SEL_PlatformEventUsageMetric.TimeSegment.Daily, Datetime.now().addDays(-30), Datetime.now());

		Assert.isNotNull(results, 'Legacy branch should return a list without referencing TimeSegment');
	}

	/**
	 * @description Tests the segment-and-range query on the enhanced (probe-on) branch: TimeSegment
	 * is projected and filtered dynamically.
	 */
	@IsTest
	private static void shouldGetBySegmentAndDateRangeEnhancedBranch()
	{
		SEL_PlatformEventUsageMetric.timeSegmentAvailableOverride = true;

		TST_Mock.of(PlatformEventUsageMetric.SObjectType)
				.withOverride(PlatformEventUsageMetric.Name, 'PLATFORM_EVENTS_PUBLISHED')
				.withOverride(PlatformEventUsageMetric.Value, 7)
				.build();

		List<PlatformEventUsageMetric> results = new SEL_PlatformEventUsageMetric()
				.getBySegmentAndDateRange(SEL_PlatformEventUsageMetric.TimeSegment.Hourly, Datetime.now().addHours(-12), Datetime.now());

		Assert.isNotNull(results, 'Enhanced branch should return a list with the dynamic TimeSegment condition');
	}
}