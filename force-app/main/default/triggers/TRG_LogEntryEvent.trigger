// SPDX-License-Identifier: Apache-2.0
/**
 * @description Log entry event trigger for handling log events
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date 2020, November 2026
 */
trigger TRG_LogEntryEvent on LogEntryEvent__e (after insert)
{
	new TRG_Dispatcher().run();
}