// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Log entry event trigger for handling log events
 *
 * @author Jason van Beukering
 *
 * @date 2020, February 2026
 */
trigger TRG_LogEntryEvent on LogEntryEvent__e (after insert)
{
	new TRG_Dispatcher().run();
}