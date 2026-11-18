// SPDX-License-Identifier: Apache-2.0
/**
 * @description Reads saved log entries. Every read goes through a selector, in tests too, and the package does not give
 * you one for log entries, so you keep a short one of your own. It reads in user mode: the person running it needs read
 * access to log entries and the right to see all of them.
 *
 * @see FastStart_Logging_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date November 2026
 */
public with sharing class SEL_LogEntries extends kern.SEL_Base
{
	/**
	 * @description Creates the selector for log entries.
	 */
	public SEL_LogEntries()
	{
		super(kern__LogEntry__c.SObjectType);
	}

	/**
	 * @description Lists the fields every read returns.
	 *
	 * @return The fields.
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				kern__LogEntry__c.kern__Message__c,
				kern__LogEntry__c.kern__LogLevel__c,
				kern__LogEntry__c.kern__CorrelationId__c
		};
	}
}
