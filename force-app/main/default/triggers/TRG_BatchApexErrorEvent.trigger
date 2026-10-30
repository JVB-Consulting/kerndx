// SPDX-License-Identifier: Apache-2.0
/**
 * @description Batch job failure trigger: hands each failure the platform reports to the framework, which writes it to the log
 *
 * @author Jason van Beukering
 *
 * @date September 2026, October 2026
 */
trigger TRG_BatchApexErrorEvent on BatchApexErrorEvent (after insert)
{
	new TRG_Dispatcher().run();
}
