// SPDX-License-Identifier: Apache-2.0
/**
 * @description Utility class for managing SObject record sharing.
 * Provides methods for both permanent and time-bound (temporary) sharing.
 *
 * **How share records are saved.** Every save of a share record runs with
 * `.withSystemMode().bypassSharing()`. This holds on both paths: the grant path (`grant` and
 * `grantTemporary`) and the revoke path. System mode means the save skips the running user's
 * object and field permissions, and `bypassSharing()` means it also skips their record sharing.
 *
 * The revoke path needs this. A time-bound share is removed by a queued job that runs hours after
 * the grant, when the session of the user who granted it may no longer be valid.
 *
 * On the grant path, the target is the share table of a parent object the caller chooses, not a
 * record the framework owns. So a caller with few permissions in your org can grant access to
 * records they could not share themselves. `UTIL_PurgeRecords` and `UTIL_BulkUpdates` work
 * differently: they save with the access the User Mode DML feature flag selects, which by default is the running
 * user's object and field permissions.
 *
 * Supports any SObject type that has a corresponding Share object (custom objects
 * with __Share and standard objects like AccountShare, CaseShare, etc.).
 *
 * @see UTIL_AsynchronousJobLauncher
 * @see UTIL_Sharing_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date January 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
 *     .fields(new List<String>{'Id'})
 *     .withLimit(10)
 *     .toList();
 * Id groupId = new SEL_Group().findByName('AllUsers').Id;
 * // Permanent sharing - grant read access indefinitely
 * List<SObject> shares = UTIL_Sharing.grant(accounts, groupId, 'Read');
 * // Temporary sharing - grant read access for 30 minutes
 * List<SObject> tempShares = UTIL_Sharing.grantTemporary(accounts, groupId, 'Read', 30);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_Sharing
{
	/**
	 * @description Test flag to skip queueable enqueueing. Only for use in test context.
	 */
	@TestVisible
	private static Boolean skipAsyncInTests = false;

	/**
	 * @description Valid access levels for share records.
	 */
	@TestVisible
	private static final Set<String> VALID_ACCESS_LEVELS = new Set<String> {'Read', 'Edit', 'All'};

	/**
	 * @description Error message for empty records list.
	 */
	@TestVisible
	private static final String ERROR_EMPTY_RECORDS = 'Records list cannot be null or empty';

	/**
	 * @description Error message for null user or group ID.
	 */
	@TestVisible
	private static final String ERROR_NULL_USER_OR_GROUP = 'User or Group ID cannot be null';

	/**
	 * @description Error message for invalid access level.
	 */
	@TestVisible
	private static final String ERROR_INVALID_ACCESS_LEVEL = 'Access level must be one of: Read, Edit, All';

	/**
	 * @description Error message for invalid validity period.
	 */
	@TestVisible
	private static final String ERROR_INVALID_VALIDITY = 'Validity minutes must be greater than 0';

	/**
	 * @description Grants permanent access to the specified records for a user or group.
	 * Creates share records that remain until explicitly deleted.
	 *
	 * @param records The SObject records to share (must have an Id).
	 * @param userOrGroupId The ID of the User or Group to grant access to.
	 * @param accessLevel The level of access to grant ('Read', 'Edit', or 'All').
	 *
	 * @return The created share records.
	 *
	 * @throws IllegalArgumentException if any parameter is invalid.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .fields(new List<String>{'Id'})
	 *     .withLimit(10)
	 *     .toList();
	 * Id groupId = new SEL_Group().findByName('AllUsers').Id;
	 * List<SObject> shares = UTIL_Sharing.grant(accounts, groupId, 'Edit');
	 * ```
	 */
	global static List<SObject> grant(List<SObject> records, Id userOrGroupId, String accessLevel)
	{
		validateGrantParameters(records, userOrGroupId, accessLevel);
		return createShareRecords(records, userOrGroupId, accessLevel);
	}

	/**
	 * @description Grants temporary access to the specified records for a user or group.
	 * Creates share records and schedules their automatic revocation after the validity period.
	 *
	 * @param records The SObject records to share (must have an Id).
	 * @param userOrGroupId The ID of the User or Group to grant access to.
	 * @param accessLevel The level of access to grant ('Read', 'Edit', or 'All').
	 * @param validityMinutes The duration in minutes before access is revoked.
	 *
	 * @return The created share records.
	 *
	 * @throws IllegalArgumentException if any parameter is invalid.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .fields(new List<String>{'Id'})
	 *     .withLimit(10)
	 *     .toList();
	 * Id groupId = new SEL_Group().findByName('AllUsers').Id;
	 * List<SObject> shares = UTIL_Sharing.grantTemporary(accounts, groupId, 'Edit', 60);
	 * ```
	 */
	global static List<SObject> grantTemporary
			(
					List<SObject> records,
					Id userOrGroupId,
					String accessLevel,
					Integer validityMinutes
			)
	{
		if(validityMinutes == null || validityMinutes <= 0)
		{
			throw new IllegalArgumentException(ERROR_INVALID_VALIDITY);
		}

		List<SObject> shares = grant(records, userOrGroupId, accessLevel);

		scheduleRevocation(shares, validityMinutes);

		return shares;
	}

	/**
	 * @description Throws an IllegalArgumentException when the record list is null or empty, when no user or group is
	 * given, or when the access level is not exactly 'Read', 'Edit' or 'All' (the check is case-sensitive). It changes
	 * nothing.
	 *
	 * @param records The records to validate.
	 * @param userOrGroupId The user or group ID to validate.
	 * @param accessLevel The access level to validate.
	 */
	private static void validateGrantParameters(List<SObject> records, Id userOrGroupId, String accessLevel)
	{
		if(records == null || records.isEmpty())
		{
			throw new IllegalArgumentException(ERROR_EMPTY_RECORDS);
		}

		if(userOrGroupId == null)
		{
			throw new IllegalArgumentException(ERROR_NULL_USER_OR_GROUP);
		}

		if(String.isBlank(accessLevel) || !VALID_ACCESS_LEVELS.contains(accessLevel))
		{
			throw new IllegalArgumentException(ERROR_INVALID_ACCESS_LEVEL);
		}
	}

	/**
	 * @description Builds one share row for each record that has an Id, skipping null records and records without one, and
	 * saves them all in one insert. The insert skips the running user's permission and sharing checks.
	 *
	 * @param records The records to share.
	 * @param userOrGroupId The user or group to share with.
	 * @param accessLevel The access level to grant.
	 *
	 * @return The share records, already inserted.
	 */
	private static List<SObject> createShareRecords(List<SObject> records, Id userOrGroupId, String accessLevel)
	{
		List<SObject> sharesToInsert = new List<SObject>();

		for(SObject record : records)
		{
			if(String.isNotBlank(record?.Id))
			{
				SObject shareRecord = TST_Factory.newSObjectShare(record.Id, accessLevel, userOrGroupId);
				sharesToInsert.add(shareRecord);
			}
		}

		DML_Builder.newTransaction().withSystemMode().doInsert(sharesToInsert).bypassSharing().execute();

		return sharesToInsert;
	}

	/**
	 * @description Schedules the revocation of share records after the validity period.
	 * Uses the asynchronous processing framework with delayed dispatch for automatic
	 * chaining of delays greater than 10 minutes.
	 *
	 * @param shares The share records to revoke.
	 * @param validityMinutes The delay before revocation in minutes.
	 */
	private static void scheduleRevocation(List<SObject> shares, Integer validityMinutes)
	{
		if(!shares.isEmpty() && !skipAsyncInTests)
		{
			List<Object> items = new List<Object>();
			for(SObject share : shares)
			{
				items.add(share.Id);
			}

			UTIL_AsynchronousJobLauncher.process
					(
							new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items).withDelayMinutes(validityMinutes),
							new ShareDeletionProcessor()
					);
		}
	}

	/**
	 * @description Processor that deletes share records using the asynchronous framework.
	 * Implements Processable to leverage the framework's chunking and delay capabilities.
	 */
	public inherited sharing class ShareDeletionProcessor implements IF_Async.Processable
	{
		/**
		 * @description Deletes the share records identified by the provided IDs.
		 *
		 * @param items The list of share record IDs to delete.
		 */
		public void execute(List<Object> items)
		{
			List<SObject> sharesToDelete = new List<SObject>();

			for(Object item : items)
			{
				Id shareId = (Id)item;
				SObjectType shareType = UTIL_SObjectDescribe.getSObjectTypeById(shareId);

				if(shareType != null)
				{
					sharesToDelete.add(shareType.newSObject(shareId));
				}
			}

			DML_Builder.newTransaction().withSystemMode().doDelete(sharesToDelete).bypassSharing().allowPartial().execute();
		}
	}
}