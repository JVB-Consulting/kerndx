// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Proves, in an org where the framework is an installed package, that an entry written with no location
 * names the subscriber class that wrote it. The framework's own frames on the call stack are hidden there, so the top
 * frame the logger reads is the subscriber's: the entry's class and method and its source name SubscriberWhoWroteIt,
 * never a framework class, and its origin is APEX (Apex outside the framework), never FRAMEWORK.
 *
 * @see SubscriberWhoWroteIt
 * @see kern.LOG_Builder
 * @see kern.QRY_Builder
 *
 * @author your.name@company.com
 *
 * @group Logging
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SubscriberWhoWroteIt_TEST
{
	/**
	 * @description The message of the entry the test writes and reads back.
	 */
	private static final String PROBE_MESSAGE = 'who-wrote-it subscriber probe';

	/**
	 * @description The name of the method that writes the entry.
	 */
	private static final String WRITING_METHOD = 'write';

	/**
	 * @description The origin the logger stores for Apex outside the framework's namespace.
	 */
	private static final String ORIGIN_APEX = 'APEX';

	/**
	 * @description An entry written with no location takes its class and method from the subscriber class on top of the
	 * call stack: the class and method read SubscriberWhoWroteIt.write, the source reads SubscriberWhoWroteIt, and the
	 * origin reads APEX.
	 */
	@IsTest
	private static void shouldNameTheSubscriberClassAsTheWriterOfAnEntryWithNoLocation()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		String writerName = SubscriberWhoWroteIt.class.getName();

		Test.startTest();
		SubscriberWhoWroteIt.write(PROBE_MESSAGE);
		Test.getEventBus().deliver();
		Test.stopTest();

		List<kern__LogEntry__c> entries = (List<kern__LogEntry__c>)kern.QRY_Builder.selectFrom(kern__LogEntry__c.SObjectType)
				.fields(new List<SObjectField> {kern__LogEntry__c.kern__ClassMethod__c, kern__LogEntry__c.kern__Source__c, kern__LogEntry__c.kern__Origin__c})
				.condition(kern__LogEntry__c.kern__ShortMessage__c).equals(PROBE_MESSAGE)
				.toList();
		Assert.areEqual(1, entries.size(), 'Expected one entry with the probe message, got ' + entries.size());
		Assert.areEqual(writerName + '.' + WRITING_METHOD, entries[0].kern__ClassMethod__c, 'Expected the class and method on top of the call stack');
		Assert.areEqual(writerName, entries[0].kern__Source__c, 'Expected the source to be the subscriber class that wrote the entry');
		Assert.areEqual(ORIGIN_APEX, entries[0].kern__Origin__c, 'Expected the origin of Apex outside the framework');
	}
}
