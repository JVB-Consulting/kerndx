// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger on ApiCall__c. Fires the configured trigger actions for data masking before
 * insert and update, and before a delete the action that refuses the delete to every user the Bypass API
 * Record Delete Guard feature flag is off for (out of the box, everyone without the Delete API Records
 * permission), then the content-document cleanup.
 *
 * @see TRG_GuardApiRecordDeletion
 * @see TRG_DeleteApiCallDocuments
 * @see ApiCall__c
 *
 * @author Jason van Beukering
 *
 * @date November 2023, October 2026
 */
trigger TRG_ApiCall on ApiCall__c (before insert, before update, before delete)
{
	new TRG_Dispatcher().run();
}