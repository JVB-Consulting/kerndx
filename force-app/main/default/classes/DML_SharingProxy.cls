// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Sharing proxy for DML operations. Delegates actual DML to inner classes that declare
 * specific sharing contexts (with sharing, without sharing, or inherited sharing).
 *
 * @see DML_SharingProxy_TEST
 * @see DML_Builder
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters')
public inherited sharing class DML_SharingProxy
{
	/**
	 * @description Developer name of the feature flag that sets the default access mode for DML. A subscriber can
	 * turn this flag on or off.
	 */
	@TestVisible
	private static final String FLAG_USER_MODE_DML = 'UserModeDml_Enabled';

	/**
	 * @description The two mode names that the fallback comparison in matchesAccessLevel accepts. Any other text
	 * never counts as a match. This holds even when both access levels show the same unknown text, which could
	 * happen if the platform changes how it prints an access level. So a failed comparison can only make the caller
	 * fall back to the flag's default mode. It can never give the caller more access.
	 */
	private static final Set<String> KNOWN_ACCESS_PERMISSIONS = new Set<String> {'SYSTEM_MODE', 'USER_MODE'};

	/**
	 * @description A proxy that a test installs in place of the real ones. While it is set, getSharingProxy returns
	 * it for every sharing type. A test uses it to act like the platform and refuse a save, for example with a row
	 * lock, without any test switch inside the code being tested. It is null in production and by default. The test
	 * that sets it also clears it.
	 */
	@TestVisible
	private static DatabaseProxy sharingProxyForTest;

	/**
	 * @description Returns the flag-driven default `AccessLevel` for DML operations.
	 *
	 * @return `AccessLevel.USER_MODE` when `UserModeDml_Enabled` is on; `AccessLevel.SYSTEM_MODE` otherwise.
	 */
	public static AccessLevel defaultAccessLevel()
	{
		return UTIL_FeatureFlag.isEnabled(FLAG_USER_MODE_DML) ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
	}

	/**
	 * @description Checks whether two access levels mean the same access mode, and stays correct after the value
	 * has been passed to a queueable or batch job. When the platform passes a `System.AccessLevel` to an async job,
	 * it saves the value and rebuilds it later. The rebuilt value is a new object, so `==` no longer matches
	 * `AccessLevel.SYSTEM_MODE` or `AccessLevel.USER_MODE`. Every comparison of access modes on the async path must
	 * therefore use this method, never `==`. The method first checks whether both are the same object. If they are
	 * not, it reads the mode name from the text that `String.valueOf` prints for each value. That text ends with the
	 * value's own `currentAccessPermissions` name, and the name must be one of the two known modes. If a name cannot
	 * be read, or is not a known mode, the method reports no match. This can happen if the platform changes how it
	 * prints an access level. The caller then falls back to the flag's default mode, so it never gains access by
	 * mistake. A USER_MODE value limited to a permission set prints the same `USER_MODE` name as the plain value, so
	 * it matches USER_MODE. The permission-set limit is lost, which leaves the stricter mode.
	 *
	 * @param candidate The access level under test, possibly deserialized from an async payload.
	 * @param reference The access level to compare against, normally the `AccessLevel.SYSTEM_MODE` or `AccessLevel.USER_MODE` singleton.
	 *
	 * @return True when both operands denote the same access mode; false when they differ, when either is null, or when the rendering cannot be parsed.
	 */
	public static Boolean matchesAccessLevel(AccessLevel candidate, AccessLevel reference)
	{
		if(candidate == reference)
		{
			return true;
		}
		if(candidate == null || reference == null)
		{
			return false;
		}
		String candidatePermission = extractCurrentAccessPermission(candidate);
		return KNOWN_ACCESS_PERMISSIONS.contains(candidatePermission) && candidatePermission == extractCurrentAccessPermission(reference);
	}

	/**
	 * @description Reads an `AccessLevel` value's own `currentAccessPermissions` name from the text that
	 * `String.valueOf` prints for it. The platform does not document this text. The value's own name comes LAST.
	 * The text also prints both mode names earlier, inside nested values, so only the last one names this value.
	 * A `contains` check would find both modes.
	 *
	 * @param accessLevel The access level whose rendered state to parse.
	 *
	 * @return The trailing `currentAccessPermissions` token (for example `SYSTEM_MODE`), or null when the rendering does not carry one.
	 */
	private static String extractCurrentAccessPermission(AccessLevel accessLevel)
	{
		String renderedTail = String.valueOf(accessLevel).substringAfterLast('currentAccessPermissions=');
		String permissionToken = renderedTail.substringBefore(',').substringBefore(']').trim();
		return String.isBlank(permissionToken) ? null : permissionToken;
	}

	/**
	 * @description Defines how sharing rules should be enforced during DML.
	 */
	public enum SharingType
	{
		/**
		 * @description Bypass sharing rules.
		 */
		BYPASS,
		/**
		 * @description Enforce sharing rules.
		 */
		ENFORCE,
		/**
		 * @description Inherit sharing from the calling context.
		 */
		INHERITED
	}

	/**
	 * @description Returns the appropriate sharing proxy for the given sharing type.
	 *
	 * @param shareType The sharing enforcement type.
	 *
	 * @return An initialised proxy for the requested sharing context.
	 */
	public static DatabaseProxy getSharingProxy(SharingType shareType)
	{
		if(sharingProxyForTest != null)
		{
			return sharingProxyForTest;
		}

		DatabaseProxy proxy;

		switch on shareType
		{
			when BYPASS
			{
				proxy = new DatabaseProxyWithoutSharing();
			}
			when ENFORCE
			{
				proxy = new DatabaseProxyWithSharing();
			}
			when else
			{
				proxy = new DatabaseProxy();
			}
		}

		return proxy;
	}

	/**
	 * @description The default DML proxy. It runs with inherited sharing. It uses the access level the caller passes, or,
	 * when that is null, the default that the `UserModeDml_Enabled` flag sets.
	 */
	@SuppressWarnings('PMD.ApexSharingViolations')
	public inherited sharing virtual class DatabaseProxy
	{
		/**
		 * @description Inserts records with an explicit access level. Null `accessLevel` resolves
		 * to the flag-driven default (`UserModeDml_Enabled`).
		 *
		 * @param records The records to insert.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of save results.
		 */
		public protected virtual List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return Database.insert(records, allOrNothing, accessLevel ?? defaultAccessLevel());
		}

		/**
		 * @description Updates records with an explicit access level. Null `accessLevel` resolves
		 * to the flag-driven default.
		 *
		 * @param records The records to update.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of save results.
		 */
		public protected virtual List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return Database.update(records, allOrNothing, accessLevel ?? defaultAccessLevel());
		}

		/**
		 * @description Deletes records with an explicit access level. Null `accessLevel` resolves
		 * to the flag-driven default.
		 *
		 * @param records The records to delete.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of delete results.
		 */
		public protected virtual List<Database.DeleteResult> doDelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return Database.delete(records, allOrNothing, accessLevel ?? defaultAccessLevel());
		}

		/**
		 * @description Upserts records with an explicit access level. Null `accessLevel` resolves
		 * to the flag-driven default.
		 *
		 * @param records The records to upsert.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of upsert results.
		 */
		public protected virtual List<Database.UpsertResult> doUpsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return Database.upsert(records, allOrNothing, accessLevel ?? defaultAccessLevel());
		}

		/**
		 * @description Upserts records using a specific external ID field with an explicit access
		 * level. Null `accessLevel` resolves to the flag-driven default.
		 *
		 * @param records The records to upsert.
		 * @param externalIdField The external ID field for matching.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of upsert results.
		 */
		public protected virtual List<Database.UpsertResult> doUpsert(List<SObject> records, SObjectField externalIdField, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return Database.upsert(records, externalIdField, allOrNothing, accessLevel ?? defaultAccessLevel());
		}

		/**
		 * @description Undeletes records with an explicit access level. Null `accessLevel` resolves
		 * to the flag-driven default.
		 *
		 * @param records The records to undelete.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of undelete results.
		 */
		public protected virtual List<Database.UndeleteResult> doUndelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return Database.undelete(records, allOrNothing, accessLevel ?? defaultAccessLevel());
		}
	}

	/**
	 * @description DML proxy that ignores sharing rules. This class overrides every method of `DatabaseProxy` and
	 * calls `super` in each one. That way the method that calls `Database.*` belongs to this class, so its
	 * `without sharing` keyword applies. Apex takes the sharing rule from the class whose method is running, not
	 * from the class the call was sent to. The matching class `DatabaseProxyWithSharing` below has the same shape
	 * on purpose, and both must exist.
	 */
	@SuppressWarnings('PMD.ExcessivePublicCount, DuplicatedCode')
	private without sharing class DatabaseProxyWithoutSharing extends DatabaseProxy
	{
		/**
		 * @description Inserts records without sharing enforcement with an explicit access level.
		 *
		 * @param records The records to insert.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of save results.
		 */
		public override List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doInsert(records, allOrNothing, accessLevel);
		}

		/**
		 * @description Updates records without sharing enforcement with an explicit access level.
		 *
		 * @param records The records to update.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of save results.
		 */
		public override List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doUpdate(records, allOrNothing, accessLevel);
		}

		/**
		 * @description Deletes records without sharing enforcement with an explicit access level.
		 *
		 * @param records The records to delete.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of delete results.
		 */
		public override List<Database.DeleteResult> doDelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doDelete(records, allOrNothing, accessLevel);
		}

		/**
		 * @description Upserts records without sharing enforcement with an explicit access level.
		 *
		 * @param records The records to upsert.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of upsert results.
		 */
		public override List<Database.UpsertResult> doUpsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doUpsert(records, allOrNothing, accessLevel);
		}

		/**
		 * @description Upserts records using an external ID field without sharing with an explicit access level.
		 *
		 * @param records The records to upsert.
		 * @param externalIdField The external ID field for matching.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of upsert results.
		 */
		public override List<Database.UpsertResult> doUpsert(List<SObject> records, SObjectField externalIdField, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doUpsert(records, externalIdField, allOrNothing, accessLevel);
		}

		/**
		 * @description Undeletes records without sharing enforcement with an explicit access level.
		 *
		 * @param records The records to undelete.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of undelete results.
		 */
		public override List<Database.UndeleteResult> doUndelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doUndelete(records, allOrNothing, accessLevel);
		}
	}

	/**
	 * @description DML proxy that enforces sharing rules. This class overrides every method of `DatabaseProxy` and
	 * calls `super` in each one. That way the method that calls `Database.*` belongs to this class, so its
	 * `with sharing` keyword applies. Apex takes the sharing rule from the class whose method is running, not from
	 * the class the call was sent to. The matching class `DatabaseProxyWithoutSharing` above has the same shape on
	 * purpose, and both must exist.
	 */
	@SuppressWarnings('PMD.ExcessivePublicCount, DuplicatedCode')
	private with sharing class DatabaseProxyWithSharing extends DatabaseProxy
	{
		/**
		 * @description Inserts records with sharing enforcement with an explicit access level.
		 *
		 * @param records The records to insert.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of save results.
		 */
		public override List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doInsert(records, allOrNothing, accessLevel);
		}

		/**
		 * @description Updates records with sharing enforcement with an explicit access level.
		 *
		 * @param records The records to update.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of save results.
		 */
		public override List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doUpdate(records, allOrNothing, accessLevel);
		}

		/**
		 * @description Deletes records with sharing enforcement with an explicit access level.
		 *
		 * @param records The records to delete.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of delete results.
		 */
		public override List<Database.DeleteResult> doDelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doDelete(records, allOrNothing, accessLevel);
		}

		/**
		 * @description Upserts records with sharing enforcement with an explicit access level.
		 *
		 * @param records The records to upsert.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of upsert results.
		 */
		public override List<Database.UpsertResult> doUpsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doUpsert(records, allOrNothing, accessLevel);
		}

		/**
		 * @description Upserts records using an external ID field with sharing enforcement with an explicit access level.
		 *
		 * @param records The records to upsert.
		 * @param externalIdField The external ID field for matching.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of upsert results.
		 */
		public override List<Database.UpsertResult> doUpsert(List<SObject> records, SObjectField externalIdField, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doUpsert(records, externalIdField, allOrNothing, accessLevel);
		}

		/**
		 * @description Undeletes records with sharing enforcement with an explicit access level.
		 *
		 * @param records The records to undelete.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The access level to use; `null` means use the flag-driven default.
		 *
		 * @return A list of undelete results.
		 */
		public override List<Database.UndeleteResult> doUndelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			return super.doUndelete(records, allOrNothing, accessLevel);
		}
	}
}