// SPDX-License-Identifier: BUSL-1.1
trigger TRG_Case on Case (after update)
{
	new kern.TRG_Dispatcher().run();
}
