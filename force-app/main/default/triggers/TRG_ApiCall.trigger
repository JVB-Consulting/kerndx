// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger on ApiCall__c. Fires the configured trigger actions for content-document
 * cleanup on delete and for data masking before insert and update.
 *
 * @see TRG_DeleteApiCallDocuments
 * @see ApiCall__c
 *
 * @author Jason van Beukering
 *
 * @date November 2023, February 2026, April 2026
 */
trigger TRG_ApiCall on ApiCall__c (before insert, before update, before delete)
{
	new TRG_Dispatcher().run();
}