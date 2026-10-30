// SPDX-License-Identifier: Apache-2.0
trigger KernTriggerMustDelegateNegativeNamespaced on Account (before insert)
{
	new kern.TRG_Dispatcher().run();
}
