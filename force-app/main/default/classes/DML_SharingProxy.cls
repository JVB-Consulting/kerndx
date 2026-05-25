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
 * @date February 2026, May 2026
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
	 * @description Returns the flag-driven default `AccessLevel` for DML operations.
	 *
	 * @return `AccessLevel.USER_MODE` when `UserModeDml_Enabled` is on; `AccessLevel.SYSTEM_MODE` otherwise.
	 */
	public static AccessLevel defaultAccessLevel()
	{
		return UTIL_FeatureFlag.isEnabled(FLAG_USER_MODE_DML) ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
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