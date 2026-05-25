// SPDX-License-Identifier: BUSL-1.1
/**
 * @description TRG_ScheduledJob activated by saving Scheduled Job records (rule: 1 record per periodic job setting)
 *
 * @author Jason van Beukering
 *
 * @date 2019, February 2026
 */
trigger TRG_ScheduledJob on ScheduledJob__c(before insert, before update, before delete)
{
	new TRG_Dispatcher().run();
}