// SPDX-License-Identifier: BUSL-1.1
trigger KernTriggerMustDelegateNegativeNamespaced on Account (before insert)
{
	new kern.TRG_Dispatcher().run();
}
