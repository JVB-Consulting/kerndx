// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Example trigger demonstrating the Trigger Action framework
 *
 * @author Jason van Beukering
 *
 * @date 2019, February 2026
 */
trigger TRG_Foobar on Foobar__c(before insert, before update, before delete, after insert, after update, after delete, after undelete)
{
	new TRG_Dispatcher().run();
}