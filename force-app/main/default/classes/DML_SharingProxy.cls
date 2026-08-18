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
 * @date February 2026, August 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters')
public inherited sharing class DML_SharingProxy
{
	/**
	 * @description Developer name of the feature flag that drives the subscriber-reachable
	 * DML default access mode.
	 */
	@TestVisible
	private static final String FLAG_USER_MODE_DML = 'UserModeDml_Enabled';

	/**
	 * @description The two access-permission tokens the fallback comparison recognises. A token
	 * outside this set — including a degenerate marker both operands could share after a platform
	 * rendering-format change — never matches, so the comparator can only degrade toward the
	 * flag-driven default, never elevate.
	 */
	private static final Set<String> KNOWN_ACCESS_PERMISSIONS = new Set<String> {'SYSTEM_MODE', 'USER_MODE'};

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
	 * @description Serialization-safe access-mode comparator. `System.AccessLevel` survives a
	 * queueable or batch hand-off by value but not by identity — the deserialized instance matches
	 * neither singleton under `==` — so every access-mode comparison on the async path must go
	 * through this method instead of raw `==`. Identity is compared first; for deserialized
	 * instances the comparison falls back to each operand's own rendered
	 * `currentAccessPermissions` token, which both live and deserialized renderings place last and
	 * which must be one of the two known mode names. When either token cannot be extracted or is
	 * not a known mode name (a platform rendering-format change), the comparator reports no match,
	 * degrading the caller to the flag-driven default — never a silent elevation. A
	 * permission-set-scoped USER_MODE variant carries the same `USER_MODE` token as the plain
	 * singleton and resolves as USER_MODE — the permission-set scoping is dropped, which is the
	 * stricter direction.
	 *
	 * @param candidate The access level under test, possibly deserialized from an async payload.
	 * @param reference The access level to compare against, normally the `AccessLevel.SYSTEM_MODE` or `AccessLevel.USER_MODE` singleton.
	 *
	 * @return True when both operands denote the same access mode; false when they differ, when either is null, or when the rendering cannot be parsed.
	 *
	 * @since 1.7
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
	 * @description Extracts an `AccessLevel` instance's own `currentAccessPermissions` token from
	 * its undocumented `String.valueOf` rendering. The instance's own token renders LAST — the
	 * nested renderings of the twin singletons embed both mode names earlier, so only the final
	 * occurrence identifies the operand; a `contains` check would match both modes.
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
	 * @description Default DML proxy using inherited sharing and SYSTEM_MODE access.
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
	 * @description DML proxy that bypasses sharing rules. Every method on `DatabaseProxy` is
	 * overridden here (delegating to `super`) so the `without sharing` annotation on this class
	 * governs the call frame that reaches `Database.*` — Apex resolves sharing by the class of
	 * the executing method, not by the dispatched-to target. The twin `DatabaseProxyWithSharing`
	 * class below is intentionally structurally identical; both must exist.
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
	 * @description DML proxy that enforces sharing rules. Every method on `DatabaseProxy` is
	 * overridden here (delegating to `super`) so the `with sharing` annotation on this class
	 * governs the call frame that reaches `Database.*` — Apex resolves sharing by the class of
	 * the executing method, not by the dispatched-to target. The twin `DatabaseProxyWithoutSharing`
	 * class above is intentionally structurally identical; both must exist.
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