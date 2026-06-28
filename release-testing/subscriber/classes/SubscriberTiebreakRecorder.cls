// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test-only recorder for the 1.2 deterministic trigger-action tiebreak proof.
 * The two tied Before Insert actions (TRG_TiebreakZ and TRG_TiebreakA) append their marker to
 * {@link order} only while {@link recording} is set, so the always-on actions stay inert for
 * the rest of the subscriber suite and only the tiebreak test observes their sequence.
 *
 * @see Subscriber_TriggerActionTiebreak_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date June 2026
 */
public with sharing class SubscriberTiebreakRecorder
{
	/**
	 * @description When true, the tied tiebreak actions append their marker to {@link order}.
	 */
	public static Boolean recording = false;

	/**
	 * @description Markers appended by the tied actions, in execution order.
	 */
	public static List<String> order = new List<String>();
}
