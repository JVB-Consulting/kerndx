// SPDX-License-Identifier: Apache-2.0
/**
 * @description Release-testing class that writes many log entries in one transaction and names no location for any of
 * them. The framework then works out who wrote each entry from the call stack: the origin (APEX for code outside the
 * package) and the source (the name of this class). Section 50 calls it; section 50b checks every entry it wrote.
 *
 * @see kern.LOG_Builder
 *
 * @author your.name@company.com
 *
 * @group Logging
 *
 * @date October 2026
 */
public inherited sharing class SubscriberLogVolumeEmitter
{
	/**
	 * @description The start of every message this class writes. Section 50b finds the entries by it.
	 */
	public static final String MESSAGE_PREFIX = 'Log volume entry ';

	/**
	 * @description Writes the given number of info entries, one emit each, with no at() and no emitAt(), so the
	 * framework reads the writer from the call stack.
	 *
	 * @param count How many entries to write.
	 */
	public static void emit(Integer count)
	{
		for(Integer index = 0; index < count; index++)
		{
			kern.LOG_Builder.build().info(MESSAGE_PREFIX + index).emit();
		}
	}
}
