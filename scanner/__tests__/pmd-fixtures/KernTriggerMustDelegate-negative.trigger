// SPDX-License-Identifier: BUSL-1.1
trigger KernTriggerMustDelegateNegative on Account (before insert, after insert, before update, after update)
{
	new TRG_Dispatcher().run();
}
