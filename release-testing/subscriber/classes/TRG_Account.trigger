// SPDX-License-Identifier: Apache-2.0
trigger TRG_Account on Account (before insert, before update, after insert, after update, before delete, after delete, after undelete)
{
	new kern.TRG_Dispatcher().run();
}
