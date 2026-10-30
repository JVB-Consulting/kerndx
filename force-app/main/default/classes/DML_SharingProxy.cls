// SPDX-License-Identifier: Apache-2.0
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
@SuppressWarnings('PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters,PMD.ExcessiveClassLength')
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
	 * @description Where the warning about fields left out of a save is logged from.
	 */
	private static final String LOG_LOCATION_FIELDS_LEFT_OUT = DML_SharingProxy.class.getName() + '.PermissionKeepingProxy';

	/**
	 * @description The start of the warning a save logs when it leaves out fields the running user cannot create or
	 * edit. The object names and the field names follow it. The values are never logged.
	 */
	private static final String MESSAGE_FIELDS_LEFT_OUT = 'The save ignored record sharing but kept the running user\'s field permissions. '
			+ 'These fields were left out because the user cannot create or edit them: ';

	/**
	 * @description The system fields that Salesforce fills in itself: who created and last changed a record, and when;
	 * whether the record is in the recycle bin; and when someone last logged an activity on it, viewed it or opened
	 * a page that refers to it. No user can write them, so the warning about fields left out of a save never names
	 * them. The names come from the Account tokens because the names are the same on every object that has the field.
	 */
	private static final List<SObjectField> SYSTEM_FIELDS = new List<SObjectField>
	{
			Account.CreatedDate, Account.CreatedById, Account.LastModifiedDate, Account.LastModifiedById, Account.SystemModstamp, Account.IsDeleted,
			Account.LastActivityDate, Account.LastViewedDate, Account.LastReferencedDate
	};

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

	/**
	 * @description Whether the running user has the object permission a save needs on an object: create for an insert, edit
	 * for an update, create and edit for an upsert, delete for a delete, and delete and undelete for an undelete. It asks
	 * the platform again on every call, so the answer is right inside System.runAs and when one transaction acts for more
	 * than one user.
	 *
	 * @param operation The kind of save.
	 * @param objectType The object.
	 *
	 * @return True when the running user may make this kind of save on the object.
	 */
	public static Boolean hasObjectPermission(DML_Builder.DatabaseOperation operation, SObjectType objectType)
	{
		switch on operation
		{
			when DML_INSERT
			{
				return UTIL_SObjectDescribe.isObjectCreateable(objectType);
			}
			when DML_UPDATE
			{
				return UTIL_SObjectDescribe.isObjectUpdateable(objectType);
			}
			when DML_UPSERT
			{
				return UTIL_SObjectDescribe.isObjectCreateable(objectType) && UTIL_SObjectDescribe.isObjectUpdateable(objectType);
			}
			when DML_DELETE
			{
				return UTIL_SObjectDescribe.isObjectDeletable(objectType);
			}
			when else
			{
				return UTIL_SObjectDescribe.isObjectDeletable(objectType) && UTIL_SObjectDescribe.isObjectUndeletable(objectType);
			}
		}
	}

	/**
	 * @description A proxy that ignores record sharing but keeps the running user's object and field permissions.
	 * DML_Transaction puts it around the proxy that getSharingProxy returns when a save asks to ignore record sharing
	 * and would otherwise run in user mode. User mode is the access mode that applies the running user's permissions
	 * and record sharing. System mode skips both. For each statement this proxy does the following, one object at a
	 * time:
	 * 1. It checks the object permission the save needs (see hasObjectPermission).
	 * 2. For an upsert on an external Id field, it checks that the user can read and edit that field. A match would
	 *    otherwise tell the user which record holds the value.
	 * 3. For an insert, update or upsert, it copies the records without the fields the user cannot create or edit
	 *    (Security.stripInaccessible). A field that links a record to the parent it was registered with is never
	 *    left out: the save would then create a record with no parent and no error, so the object is refused instead.
	 * 4. It saves the permitted records in system mode, without record sharing. When fields that depend on the user
	 *    were left out, it logs one warning that names the objects and the fields, never the values. Fields no user
	 *    can write are left out too, but the warning does not name them: formula fields, auto numbers, and the system
	 *    fields that say who created and last changed a record, and when. No warning is logged when the caller turned
	 *    logging off.
	 * 5. It copies each new Id from the saved copy back to the caller's record, so the caller and the children that
	 *    wait for that Id see it.
	 * A refused object is sent unchanged to the inner proxy in user mode, so the platform refuses it as user mode
	 * always does: the same exception, message and status code. In all-or-nothing mode one refused object sends the
	 * whole statement that way. When a partial save is allowed, only the refused objects go that way, and the results
	 * are put back in the order of the statement. A refused object is sent with the access level the caller passes, or
	 * in plain user mode when it is null. So when the caller sets user mode with a permission set, the platform takes
	 * that permission set into account for a refused object. The checks in steps 1 to 3 use only the running user's
	 * own permissions. The class runs without sharing, so an inner proxy with inherited sharing also ignores record
	 * sharing.
	 */
	@SuppressWarnings('PMD.ApexSharingViolations,PMD.ExcessiveParameterList')
	public without sharing class PermissionKeepingProxy extends DatabaseProxy
	{
		/**
		 * @description The proxy that runs each statement. It is the proxy getSharingProxy returned.
		 */
		private final DatabaseProxy innerProxy;

		/**
		 * @description True when the caller turned logging off. The warning about fields left out of a save is then
		 * not logged.
		 */
		private final Boolean isLoggingSuppressed;

		/**
		 * @description The records registered with a parent. The field at the same position in linkedFields holds
		 * the parent's Id. Records are compared by reference, never by value, because their values change during
		 * the save.
		 */
		private final List<SObject> linkedRecords = new List<SObject>();

		/**
		 * @description The field that links the record at the same position in linkedRecords to its parent.
		 */
		private final List<SObjectField> linkedFields = new List<SObjectField>();

		/**
		 * @description Creates the proxy around the proxy that runs each statement.
		 *
		 * @param innerProxy The proxy that getSharingProxy returned for the save.
		 * @param isLoggingSuppressed True when the caller turned logging off, so no warning is logged.
		 */
		public PermissionKeepingProxy(DatabaseProxy innerProxy, Boolean isLoggingSuppressed)
		{
			this.innerProxy = innerProxy;
			this.isLoggingSuppressed = isLoggingSuppressed;
		}

		/**
		 * @description Records that a record is linked to a parent through a field the save fills in with the
		 * parent's Id. A statement that would leave this field out of this record is refused.
		 *
		 * @param record The record that waits for its parent's Id.
		 * @param relationshipField The field that holds the parent's Id.
		 */
		public void addParentLink(SObject record, SObjectField relationshipField)
		{
			linkedRecords.add(record);
			linkedFields.add(relationshipField);
		}

		/**
		 * @description Inserts records with the user's object and field permissions and without record sharing.
		 *
		 * @param records The records to insert.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The caller's access level. It is used only for a refused object, which is sent with it, or in
		 * plain user mode when it is null. The permitted copies are always saved in system mode.
		 *
		 * @return A list of save results, one for each record, in the order of the records.
		 */
		public override List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			StatementPlan plan = new StatementPlan(DML_Builder.DatabaseOperation.DML_INSERT, records, null, this);
			return (List<Database.SaveResult>)save(plan, allOrNothing, accessLevel, new Database.SaveResult[records.size()]);
		}

		/**
		 * @description Updates records with the user's object and field permissions and without record sharing.
		 *
		 * @param records The records to update.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The caller's access level. It is used only for a refused object, which is sent with it, or in
		 * plain user mode when it is null. The permitted copies are always saved in system mode.
		 *
		 * @return A list of save results, one for each record, in the order of the records.
		 */
		public override List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			StatementPlan plan = new StatementPlan(DML_Builder.DatabaseOperation.DML_UPDATE, records, null, this);
			return (List<Database.SaveResult>)save(plan, allOrNothing, accessLevel, new Database.SaveResult[records.size()]);
		}

		/**
		 * @description Deletes records with the user's object permission and without record sharing.
		 *
		 * @param records The records to delete.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The caller's access level. It is used only for a refused object, which is sent with it, or in
		 * plain user mode when it is null. The permitted copies are always saved in system mode.
		 *
		 * @return A list of delete results, one for each record, in the order of the records.
		 */
		public override List<Database.DeleteResult> doDelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			StatementPlan plan = new StatementPlan(DML_Builder.DatabaseOperation.DML_DELETE, records, null, this);
			return (List<Database.DeleteResult>)save(plan, allOrNothing, accessLevel, new Database.DeleteResult[records.size()]);
		}

		/**
		 * @description Upserts records, matched on their Id, with the user's object and field permissions and without
		 * record sharing.
		 *
		 * @param records The records to upsert.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The caller's access level. It is used only for a refused object, which is sent with it, or in
		 * plain user mode when it is null. The permitted copies are always saved in system mode.
		 *
		 * @return A list of upsert results, one for each record, in the order of the records.
		 */
		public override List<Database.UpsertResult> doUpsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			StatementPlan plan = new StatementPlan(DML_Builder.DatabaseOperation.DML_UPSERT, records, null, this);
			return (List<Database.UpsertResult>)save(plan, allOrNothing, accessLevel, new Database.UpsertResult[records.size()]);
		}

		/**
		 * @description Upserts records, matched on an external Id field, with the user's object and field permissions
		 * and without record sharing. The user must be able to read and edit the external Id field.
		 *
		 * @param records The records to upsert.
		 * @param externalIdField The external ID field for matching.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The caller's access level. It is used only for a refused object, which is sent with it, or in
		 * plain user mode when it is null. The permitted copies are always saved in system mode.
		 *
		 * @return A list of upsert results, one for each record, in the order of the records.
		 */
		public override List<Database.UpsertResult> doUpsert(List<SObject> records, SObjectField externalIdField, Boolean allOrNothing, AccessLevel accessLevel)
		{
			StatementPlan plan = new StatementPlan(DML_Builder.DatabaseOperation.DML_UPSERT, records, externalIdField, this);
			return (List<Database.UpsertResult>)save(plan, allOrNothing, accessLevel, new Database.UpsertResult[records.size()]);
		}

		/**
		 * @description Undeletes records with the user's object permissions and without record sharing.
		 *
		 * @param records The records to undelete.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The caller's access level. It is used only for a refused object, which is sent with it, or in
		 * plain user mode when it is null. The permitted copies are always saved in system mode.
		 *
		 * @return A list of undelete results, one for each record, in the order of the records.
		 */
		public override List<Database.UndeleteResult> doUndelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			StatementPlan plan = new StatementPlan(DML_Builder.DatabaseOperation.DML_UNDELETE, records, null, this);
			return (List<Database.UndeleteResult>)save(plan, allOrNothing, accessLevel, new Database.UndeleteResult[records.size()]);
		}

		/**
		 * @description Runs one statement with the checks described on this class. When every object is permitted,
		 * the copies are saved in system mode in one statement. When an object is refused in all-or-nothing mode, or
		 * every object is refused, the caller's records are sent unchanged in user mode. Otherwise the permitted
		 * copies and the refused records go in two statements. The permitted copies are sent grouped by object, which
		 * can differ from the caller's order, so their results are always put back in the order of the caller's
		 * records.
		 *
		 * @param plan The checked statement: the kind of save, the caller's records and the external Id field an upsert
		 * matches on.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel The caller's access level, used for the refused records. Null means plain user mode.
		 * @param mergedResults An empty list of the right result type, with one place for each record. It is filled
		 * whenever permitted copies are saved.
		 *
		 * @return The results, one for each record, in the order of the caller's records.
		 */
		private List<Object> save(StatementPlan plan, Boolean allOrNothing, AccessLevel accessLevel, List<Object> mergedResults)
		{
			DML_Builder.DatabaseOperation kind = plan.kind;
			SObjectField externalIdField = plan.externalIdField;
			AccessLevel refusalAccessLevel = accessLevel ?? System.AccessLevel.USER_MODE;

			if(plan.refusedIndexes.isEmpty())
			{
				return putResultsInPlace(plan.permittedIndexes, savePermittedRecords(kind, plan, externalIdField, allOrNothing), mergedResults);
			}
			if(allOrNothing || plan.permittedIndexes.isEmpty())
			{
				return send(kind, plan.records, externalIdField, allOrNothing, refusalAccessLevel);
			}

			List<Object> permittedResults = savePermittedRecords(kind, plan, externalIdField, allOrNothing);
			List<Object> refusedResults = send(kind, plan.refusedRecords, externalIdField, allOrNothing, refusalAccessLevel);
			putResultsInPlace(plan.permittedIndexes, permittedResults, mergedResults);
			return putResultsInPlace(plan.refusedIndexes, refusedResults, mergedResults);
		}

		/**
		 * @description Puts each result at the place of its record in the caller's statement.
		 *
		 * @param indexes The positions, in the caller's statement, of the records the results belong to.
		 * @param results The results, in the order of indexes.
		 * @param mergedResults The list that holds one result for each record of the caller's statement.
		 *
		 * @return mergedResults, with the results in place.
		 */
		private List<Object> putResultsInPlace(List<Integer> indexes, List<Object> results, List<Object> mergedResults)
		{
			for(Integer position = 0; position < indexes.size(); position++)
			{
				mergedResults[indexes[position]] = results[position];
			}
			return mergedResults;
		}

		/**
		 * @description Logs the fields left out (unless the caller turned logging off), saves the permitted copies in
		 * system mode, and copies each new Id back to the caller's record.
		 *
		 * @param kind The kind of save.
		 * @param plan The checked statement.
		 * @param externalIdField The external Id field an upsert matches on, or null.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 *
		 * @return The results of the permitted copies, in the order of plan.permittedRecords.
		 */
		private List<Object> savePermittedRecords(DML_Builder.DatabaseOperation kind, StatementPlan plan, SObjectField externalIdField, Boolean allOrNothing)
		{
			if(!isLoggingSuppressed)
			{
				plan.logFieldsLeftOut();
			}
			List<Object> results = send(kind, plan.permittedRecords, externalIdField, allOrNothing, System.AccessLevel.SYSTEM_MODE);
			plan.copyNewIdsBack();
			return results;
		}

		/**
		 * @description Sends one statement to the inner proxy with the given access level.
		 *
		 * @param kind The kind of save.
		 * @param records The records to save.
		 * @param externalIdField The external Id field an upsert matches on, or null.
		 * @param allOrNothing If true, all records must succeed; if false, partial success is allowed.
		 * @param accessLevel System mode for the permitted copies; the caller's access level, or user mode, for the
		 * refused records.
		 *
		 * @return The inner proxy's results.
		 */
		private List<Object> send(DML_Builder.DatabaseOperation kind, List<SObject> records, SObjectField externalIdField, Boolean allOrNothing, AccessLevel accessLevel)
		{
			switch on kind
			{
				when DML_INSERT
				{
					return innerProxy.doInsert(records, allOrNothing, accessLevel);
				}
				when DML_UPDATE
				{
					return innerProxy.doUpdate(records, allOrNothing, accessLevel);
				}
				when DML_UPSERT
				{
					return externalIdField == null
							? innerProxy.doUpsert(records, allOrNothing, accessLevel)
							: innerProxy.doUpsert(records, externalIdField, allOrNothing, accessLevel);
				}
				when DML_DELETE
				{
					return innerProxy.doDelete(records, allOrNothing, accessLevel);
				}
				when else
				{
					return innerProxy.doUndelete(records, allOrNothing, accessLevel);
				}
			}
		}

		/**
		 * @description Whether the strip removed, from one of the given records, a field that links that record to
		 * its parent.
		 *
		 * @param records The records of one object, before the strip.
		 * @param removedFieldNames The lower-case names of the fields the strip removed from these records.
		 *
		 * @return True when a record would lose the field that holds its parent's Id.
		 */
		private Boolean isParentLinkRemoved(List<SObject> records, Set<String> removedFieldNames)
		{
			for(Integer linkIndex = 0; linkIndex < linkedRecords.size(); linkIndex++)
			{
				SObject linkedRecord = linkedRecords[linkIndex];
				SObjectField linkedField = linkedFields[linkIndex];
				if(!removedFieldNames.contains(UTIL_SObjectDescribe.getCachedFieldName(linkedField).toLowerCase()) || !linkedRecord.isSet(linkedField))
				{
					continue;
				}
				for(SObject record : records)
				{
					if(record === linkedRecord)
					{
						return true;
					}
				}
			}
			return false;
		}
	}

	/**
	 * @description The checks for one statement, made before anything is saved. It sorts the caller's records by
	 * object, decides for each object whether it is permitted or refused, and keeps the copies to save. Each record
	 * keeps its position in the statement, so the results can be put back in order.
	 */
	private inherited sharing class StatementPlan
	{
		/**
		 * @description The kind of save.
		 */
		private final DML_Builder.DatabaseOperation kind;

		/**
		 * @description The caller's records, in the order of the statement.
		 */
		private final List<SObject> records;

		/**
		 * @description The external Id field an upsert matches on, or null.
		 */
		private final SObjectField externalIdField;

		/**
		 * @description The positions, in the statement, of the records that are saved in system mode.
		 */
		private final List<Integer> permittedIndexes = new List<Integer>();

		/**
		 * @description The records saved in system mode: copies without the fields the user cannot create or edit,
		 * or the caller's records for a delete or an undelete. The record at each position belongs to the statement
		 * position at the same place in permittedIndexes.
		 */
		private final List<SObject> permittedRecords = new List<SObject>();

		/**
		 * @description The positions, in the statement, of the records of refused objects.
		 */
		private final List<Integer> refusedIndexes = new List<Integer>();

		/**
		 * @description The caller's records of refused objects, unchanged, sent in user mode.
		 */
		private final List<SObject> refusedRecords = new List<SObject>();

		/**
		 * @description For each object that lost fields, the object name and the names of the fields the strip
		 * removed. The object is the one the fields belong to. It can be the object of a parent record that a saved
		 * record names, not the object of the saved record.
		 */
		private final Map<String, Set<String>> fieldsLeftOutByObject = new Map<String, Set<String>>();

		/**
		 * @description Checks the statement, one object at a time.
		 *
		 * @param kind The kind of save.
		 * @param records The caller's records.
		 * @param externalIdField The external Id field an upsert matches on, or null.
		 * @param proxy The proxy that knows which records are linked to a parent.
		 */
		private StatementPlan(DML_Builder.DatabaseOperation kind, List<SObject> records, SObjectField externalIdField, PermissionKeepingProxy proxy)
		{
			this.kind = kind;
			this.records = records;
			this.externalIdField = externalIdField;

			Map<SObjectType, List<Integer>> indexesByType = new Map<SObjectType, List<Integer>>();
			for(Integer index = 0; index < records.size(); index++)
			{
				SObjectType objectType = records[index].getSObjectType();
				if(!indexesByType.containsKey(objectType))
				{
					indexesByType.put(objectType, new List<Integer>());
				}
				indexesByType.get(objectType).add(index);
			}

			for(SObjectType objectType : indexesByType.keySet())
			{
				planObject(objectType, indexesByType.get(objectType), externalIdField, proxy);
			}
		}

		/**
		 * @description Checks the records of one object and adds them to the permitted or the refused records.
		 *
		 * @param objectType The object.
		 * @param indexes The positions of its records in the statement.
		 * @param externalIdField The external Id field an upsert matches on, or null.
		 * @param proxy The proxy that knows which records are linked to a parent.
		 */
		private void planObject(SObjectType objectType, List<Integer> indexes, SObjectField externalIdField, PermissionKeepingProxy proxy)
		{
			List<SObject> objectRecords = new List<SObject>();
			for(Integer index : indexes)
			{
				objectRecords.add(records[index]);
			}

			Boolean isPermitted = hasObjectPermission(kind, objectType) && (externalIdField == null || UTIL_SObjectDescribe.isFieldAccessible(externalIdField));
			List<SObject> recordsToSave = objectRecords;
			AccessType stripType = getStripType();

			if(isPermitted && stripType != null)
			{
				SObjectAccessDecision decision = Security.stripInaccessible(stripType, objectRecords);
				Set<String> removedFieldNames = new Set<String>();
				for(Set<String> fieldNames : decision.getRemovedFields().values())
				{
					for(String fieldName : fieldNames)
					{
						removedFieldNames.add(fieldName.toLowerCase());
					}
				}
				Boolean isKeyRemoved = externalIdField != null && removedFieldNames.contains(UTIL_SObjectDescribe.getCachedFieldName(externalIdField).toLowerCase());
				isPermitted = !isKeyRemoved && !proxy.isParentLinkRemoved(objectRecords, removedFieldNames);
				recordsToSave = decision.getRecords();
				if(isPermitted)
				{
					addFieldsLeftOut(objectType, decision.getRemovedFields());
				}
			}

			for(Integer position = 0; position < indexes.size(); position++)
			{
				if(isPermitted)
				{
					permittedIndexes.add(indexes[position]);
					permittedRecords.add(recordsToSave[position]);
				}
				else
				{
					refusedIndexes.add(indexes[position]);
					refusedRecords.add(objectRecords[position]);
				}
			}
		}

		/**
		 * @description Keeps the names of the fields the strip removed from the records of one object, for the
		 * warning. The strip also removes fields from a parent record that a saved record names, so each field is
		 * kept under the object it belongs to. It keeps only the fields that depend on the running user's
		 * permissions. A field no user can write is left out of the warning: see canSomeUserWrite.
		 *
		 * @param objectType The object of the saved records. It is used when the strip names an object that cannot
		 * be found.
		 * @param removedFields The fields the strip removed, by the name of the object they belong to.
		 */
		private void addFieldsLeftOut(SObjectType objectType, Map<String, Set<String>> removedFields)
		{
			Set<String> systemFieldNames = new Set<String>();
			for(SObjectField systemField : SYSTEM_FIELDS)
			{
				systemFieldNames.add(UTIL_SObjectDescribe.getCachedFieldName(systemField).toLowerCase());
			}
			for(String removedFromObjectName : removedFields.keySet())
			{
				UTIL_SObjectDescribe objectDescribe = UTIL_SObjectDescribe.getDescribe(removedFromObjectName) ?? UTIL_SObjectDescribe.getDescribe(objectType);
				String objectName = UTIL_SObjectDescribe.getObjectNameFromType(objectDescribe.getSObjectType());
				for(String fieldName : removedFields.get(removedFromObjectName))
				{
					if(canSomeUserWrite(objectDescribe, systemFieldNames, fieldName))
					{
						if(!fieldsLeftOutByObject.containsKey(objectName))
						{
							fieldsLeftOutByObject.put(objectName, new Set<String>());
						}
						fieldsLeftOutByObject.get(objectName).add(fieldName);
					}
				}
			}
		}

		/**
		 * @description Checks whether some user could be allowed to write a field, so that leaving it out of a save
		 * depends on the running user's permissions. No user can write a formula field, an auto number, or one of the
		 * system fields that Salesforce fills in itself (see SYSTEM_FIELDS). The check reads only facts about the field
		 * that are the same for every user. It never asks whether the running user can create or edit the field.
		 *
		 * @param objectDescribe The describe of the object the field belongs to.
		 * @param systemFieldNames The lower-case names of the system fields that Salesforce fills in itself.
		 * @param fieldName The name of a field the strip removed.
		 *
		 * @return False for a field no user can write; true otherwise, also when the field cannot be found.
		 */
		private Boolean canSomeUserWrite(UTIL_SObjectDescribe objectDescribe, Set<String> systemFieldNames, String fieldName)
		{
			DescribeFieldResult fieldDescribe = objectDescribe.getFieldDescribe(fieldName);
			return !systemFieldNames.contains(fieldName.toLowerCase()) && fieldDescribe?.isCalculated() != true && fieldDescribe?.isAutoNumber() != true;
		}

		/**
		 * @description The kind of strip this save needs: fields the user cannot create, edit, or create and edit.
		 *
		 * @return The access type for Security.stripInaccessible, or null for a delete or an undelete, which save no fields.
		 */
		private AccessType getStripType()
		{
			switch on kind
			{
				when DML_INSERT
				{
					return AccessType.CREATABLE;
				}
				when DML_UPDATE
				{
					return AccessType.UPDATABLE;
				}
				when DML_UPSERT
				{
					return AccessType.UPSERTABLE;
				}
				when else
				{
					return null;
				}
			}
		}

		/**
		 * @description Logs one warning that names each object that lost fields, and those fields in sorted order. It
		 * logs nothing when no field was left out. The values are never logged.
		 */
		private void logFieldsLeftOut()
		{
			if(fieldsLeftOutByObject.isEmpty())
			{
				return;
			}
			List<String> parts = new List<String>();
			for(String objectName : fieldsLeftOutByObject.keySet())
			{
				List<String> fieldNames = new List<String>(fieldsLeftOutByObject.get(objectName));
				fieldNames.sort();
				parts.add(objectName + ' (' + String.join(fieldNames, ', ') + ')');
			}
			LOG_Builder.build().warn(MESSAGE_FIELDS_LEFT_OUT + String.join(parts, '; ')).at(LOG_LOCATION_FIELDS_LEFT_OUT).emit();
		}

		/**
		 * @description Copies each new Id from a saved copy back to the caller's record at the same position. It runs
		 * only for an insert or an upsert. A copy that did not save has no Id, so its record is left as it was.
		 */
		private void copyNewIdsBack()
		{
			if(kind != DML_Builder.DatabaseOperation.DML_INSERT && kind != DML_Builder.DatabaseOperation.DML_UPSERT)
			{
				return;
			}
			for(Integer position = 0; position < permittedIndexes.size(); position++)
			{
				SObject original = records[permittedIndexes[position]];
				SObject savedCopy = permittedRecords[position];
				if(original !== savedCopy && savedCopy.Id != null)
				{
					original.Id = savedCopy.Id;
				}
			}
		}
	}
}