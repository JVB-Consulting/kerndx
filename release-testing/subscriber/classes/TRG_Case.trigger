// SPDX-License-Identifier: Apache-2.0
trigger TRG_Case on Case (after update)
{
	new kern.TRG_Dispatcher().run();
}
