// SPDX-License-Identifier: Apache-2.0
/**
 * @description Trigger on ApiCall__c. It registers every trigger event, so a trigger action row you add for this
 * object runs on any of them. The package's own rows use the before events. Before insert and update the trigger masks
 * the record's data. Before a delete it runs the action that refuses the delete to every user the Bypass API Record
 * Delete Guard feature flag is off for (out of the box, everyone without the Delete API Records permission), then the
 * content-document cleanup.
 *
 * @see TRG_GuardApiRecordDeletion
 * @see TRG_DeleteApiCallDocuments
 * @see ApiCall__c
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date November 2023, November 2026
 */
trigger TRG_ApiCall on ApiCall__c (before insert, before update, before delete, after insert, after update, after delete, after undelete)
{
	new TRG_Dispatcher().run();
}