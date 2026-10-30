// SPDX-License-Identifier: Apache-2.0
trigger KernTriggerMustDelegateNegative on Account (before insert, after insert, before update, after update)
{
	new TRG_Dispatcher().run();
}
