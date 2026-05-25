// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the PushTopic SObject. Provides default field configuration
 * and query methods for PushTopic records.
 *
 * @see SEL_Base
 * @see SEL_PushTopic_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date November 2025, May 2026
 */
public inherited sharing class SEL_PushTopic extends SEL_Base
{
	/**
	 * @description Constructs a PushTopic selector.
	 */
	public SEL_PushTopic()
	{
		super(PushTopic.SObjectType);
	}

	/**
	 * @description Returns the core fields for PushTopic queries.
	 *
	 * @return List of PushTopic SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				PushTopic.Name
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. PushTopic is Setup metadata that
	 * running users typically can't read, so USER_MODE reads would return empty and streaming-
	 * subscription registration machinery would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves all PushTopic records ordered by Name.
	 *
	 * @return List of all PushTopic records
	 */
	public List<PushTopic> getAll()
	{
		return query.orderBy(PushTopic.Name).toList();
	}
}