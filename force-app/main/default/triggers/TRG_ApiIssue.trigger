// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger on ApiIssue__c. Fires the configured trigger actions for data masking
 * before insert and update so sensitive payload fragments captured in the diagnostic record
 * are redacted before persistence, regardless of whether the issue was created by the
 * web-service framework or by subscriber Apex.
 *
 * @see ApiIssue__c
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026
 */
trigger TRG_ApiIssue on ApiIssue__c (before insert, before update)
{
	new TRG_Dispatcher().run();
}