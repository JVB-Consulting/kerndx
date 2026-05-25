// SPDX-License-Identifier: BUSL-1.1
trigger TRG_Account on Account (before insert, before update, after insert, after update, before delete, after delete, after undelete)
{
	new kern.TRG_Dispatcher().run();
}
