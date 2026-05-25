// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the StreamingChannel SObject. Provides query methods for
 * retrieving streaming channels by name, with automatic generic channel prefix handling.
 *
 * @see SEL_Base
 * @see SEL_StreamingChannel_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date November 2025, May 2026
 */
public inherited sharing class SEL_StreamingChannel extends SEL_Base
{
	/**
	 * @description Prefix applied to all generic (user-defined) channel names.
	 */
	public static final String GENERIC_EVENT_NAME_PREFIX = '/u/';

	/**
	 * @description Constructs a StreamingChannel selector.
	 */
	public SEL_StreamingChannel()
	{
		super(StreamingChannel.SObjectType);
	}

	/**
	 * @description Returns the core fields for StreamingChannel queries.
	 *
	 * @return List of StreamingChannel SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				StreamingChannel.Description,
				StreamingChannel.IsDynamic,
				StreamingChannel.Name
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. StreamingChannel is Setup metadata
	 * that running users typically can't read, so USER_MODE reads would return empty and the
	 * streaming-subscription registration machinery would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves all StreamingChannel records ordered by Name.
	 *
	 * @return List of all StreamingChannel records sorted alphabetically by Name
	 */
	public List<StreamingChannel> getAllOrderByName()
	{
		return query.orderBy(StreamingChannel.Name).toList();
	}

	/**
	 * @description Finds a single generic StreamingChannel by its logical name. Automatically
	 * prefixes the provided name with '/u/' to match Salesforce's generic channel naming convention.
	 *
	 * @param channelName The logical name of the channel (without the '/u/' prefix)
	 *
	 * @return The matching StreamingChannel or null if not found
	 */
	public StreamingChannel findByName(String channelName)
	{
		return (StreamingChannel)query
				.condition(StreamingChannel.Name).equals(GENERIC_EVENT_NAME_PREFIX + channelName)
				.getFirst();
	}
}