// SPDX-License-Identifier: Apache-2.0
/**
 * @description Refuses the delete of an API call or an API issue. Runs before every delete of ApiCall__c and ApiIssue__c,
 * ahead of the other delete actions on those objects, for every user the BypassApiRecordDeleteGuard feature flag is off
 * for.
 *
 * API calls and API issues are the history of every call to and from other systems, and an issue is the record that a
 * call failed. One rule decides who may delete them: the BypassApiRecordDeleteGuard feature flag must be on for the
 * user. The two trigger action records that run this class name that flag as their bypass flag, so the trigger
 * framework skips this class for a user the flag is on for. The same flag decides for a delete from a record page, a
 * flow, your own Apex and the scheduled purge (UTIL_PurgeRecords) alike.
 *
 * A built-in rule turns the flag on for every user who holds the Delete API Records custom permission. That rule is a
 * protected strategy record of the package (a FeatureFlagStrategy__mdt row says who a flag applies to), so you do not
 * see it in Setup. The Kern Administrator permission set carries the permission, so an administrator, and a scheduled
 * purge run by an administrator, can delete. A resolver can see and retry every issue but cannot delete one.
 *
 * To let more users delete, add a strategy record of your own for a profile, a permission set or a user. To let every
 * user delete, set Result On No Match on the flag record to true. Is Enabled By Default does nothing here: the flag
 * reads it only when it has no strategy records. Deactivating the flag record refuses every delete, an administrator's
 * included, and the Health Check warns about it. Record sharing and object permissions still decide who can delete.
 *
 * A refusal fails the delete of every row with the DeleteApiRecords_PermissionRequired message. The action works in
 * memory only: no DML and no query.
 *
 * @see TRG_GuardApiRecordDeletion_TEST
 * @see SEL_TriggerAction
 * @see UTIL_FeatureFlag
 * @see UTIL_PurgeRecords
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date October 2026
 */
@SuppressWarnings('ApexUnusedDeclaration,RedundantSuppression')
public inherited sharing class TRG_GuardApiRecordDeletion extends TRG_Base implements IF_Trigger.BeforeDelete
{
	/**
	 * @description Refuses every row with the labelled message. The trigger framework runs this only for a user the
	 * BypassApiRecordDeleteGuard feature flag is off for, so every row it receives is a delete that user may not make.
	 *
	 * @param oldRecords The API calls or API issues about to be deleted.
	 */
	public void beforeDelete(List<SObject> oldRecords)
	{
		for(SObject record : oldRecords)
		{
			record.addError(System.Label.DeleteApiRecords_PermissionRequired);
		}
	}
}
