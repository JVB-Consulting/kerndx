// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A class of the subscriber's own that writes one log entry without naming where it was written. The
 * logger then works out the writer from the top of the call stack: in an org where the framework is an installed
 * package, its own frames are hidden, so the top frame is this class. SubscriberWhoWroteIt_TEST reads the entry back.
 *
 * @see kern.LOG_Builder
 * @see SubscriberWhoWroteIt_TEST
 *
 * @author your.name@company.com
 *
 * @group Logging
 *
 * @date October 2026
 */
public with sharing class SubscriberWhoWroteIt
{
	/**
	 * @description Writes one WARN entry with the given message and no location, so the logger takes the class and
	 * method from the call stack.
	 *
	 * @param message The message of the entry, which the reader uses to find it.
	 */
	public static void write(String message)
	{
		kern.LOG_Builder.build().warn(message).emit();
	}
}
