// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate subscriber trigger naming violation — not prefixed with TRG_.
 * Used to validate SubscriberTriggerNaming PMD rule.
 *
 * Expected violations:
 * - SubscriberTriggerNaming (x1: trigger not named TRG_ObjectName)
 */
trigger BadTriggerNaming on Account (before insert)
{
	new TRG_Dispatcher().run();
}
