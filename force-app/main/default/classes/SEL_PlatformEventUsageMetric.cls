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
 * @date November 2025, May 2026
 */
public inherited sharing class SEL_PlatformEventUsageMetric extends SEL_Base
{
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
	 * @description Retrieves all event usage metrics ordered by start date ascending.
	 *
	 * @return List of PlatformEventUsageMetric records ordered by StartDate
	 */
	public List<PlatformEventUsageMetric> getAllOrderByStartDate()
	{
		return query.orderBy(PlatformEventUsageMetric.StartDate).toList();
	}
}