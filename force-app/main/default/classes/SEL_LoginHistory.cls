// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the LoginHistory SObject. Provides default field configuration
 * and query methods for login history records.
 *
 * @see SEL_Base
 * @see SEL_LoginHistory_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_LoginHistory extends SEL_Base
{
	/**
	 * @description Constructs a LoginHistory selector.
	 */
	public SEL_LoginHistory()
	{
		super(LoginHistory.SObjectType);
	}

	/**
	 * @description Returns the core fields for LoginHistory queries.
	 *
	 * @return List of LoginHistory SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				LoginHistory.LoginTime,
				LoginHistory.UserId
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. LoginHistory is Setup audit data
	 * that running users can't read, so USER_MODE reads would return empty and scheduled login-
	 * frequency rollup batches would silently stop populating.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Returns a queryable for login history records within a time range.
	 * Records are filtered to those with LoginTime >= fromLoginTime and < now,
	 * ordered by UserId then LoginTime. The caller determines execution mode
	 * (toList for queueable, toQueryLocator for batch).
	 *
	 * @param fromLoginTime The earliest login time to include (defaults to epoch if null)
	 *
	 * @return IF_Queryable configured with login time criteria
	 */
	public IF_Queryable findByLoginTime(Datetime fromLoginTime)
	{
		return query
				.condition(LoginHistory.LoginTime).greaterThanOrEquals(fromLoginTime ?? UTIL_Date.getEpochDateTime())
				.condition(LoginHistory.LoginTime).lessThan(Datetime.now())
				.orderBy(LoginHistory.UserId)
				.orderBy(LoginHistory.LoginTime);
	}
}