// SPDX-License-Identifier: Apache-2.0
/**
 * @description Trigger on ApiIssue__c. Fires the configured trigger actions for data masking
 * before insert and update so sensitive payload fragments captured in the diagnostic record
 * are redacted before persistence, regardless of whether the issue was created by the
 * web-service framework or by subscriber Apex. Before a delete it fires the action that refuses
 * the delete to every user the Bypass API Record Delete Guard feature flag is off for (out of the
 * box, everyone without the Delete API Records permission).
 *
 * @see TRG_GuardApiRecordDeletion
 * @see ApiIssue__c
 *
 * @author Jason van Beukering
 *
 * @date April 2026, October 2026
 */
trigger TRG_ApiIssue on ApiIssue__c (before insert, before update, before delete)
{
	new TRG_Dispatcher().run();
}