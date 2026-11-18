// SPDX-License-Identifier: Apache-2.0
/**
 * @description TRG_ScheduledJob activated by saving Scheduled Job records (rule: 1 record per periodic job setting).
 * It registers every trigger event, so a trigger action row you add for this object runs on any of them. The
 * package's own rows use the before events.
 *
 * @author Jason van Beukering
 *
 * @group Async Processing
 *
 * @date 2019, November 2026
 */
trigger TRG_ScheduledJob on ScheduledJob__c(before insert, before update, before delete, after insert, after update, after delete, after undelete)
{
	new TRG_Dispatcher().run();
}