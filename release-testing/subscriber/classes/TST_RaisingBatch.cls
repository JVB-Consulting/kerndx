// SPDX-License-Identifier: Apache-2.0
/**
 * @description Release-test batch job that fails in every `execute()` call, to prove the framework logs a batch failure
 * the platform reports. The class opts into failure events (`Database.RaisesPlatformEvents`), so each failed
 * `execute()` makes the platform publish one `BatchApexErrorEvent`. The framework's trigger on that event writes one
 * ERROR log entry per failure, filed under `TST_RaisingBatch/execute` and linked to the job. Section 75c launches it over
 * the Foobar rows whose name starts with a given prefix; section 75d counts the entries.
 *
 * @author Jason van Beukering
 *
 * @group Release Testing
 *
 * @date October 2026
 */
public with sharing class TST_RaisingBatch implements Database.Batchable<SObject>, Database.RaisesPlatformEvents
{
	/**
	 * @description Message of the exception every `execute()` call throws; section 75d finds the log entries by it.
	 */
	public static final String FAILURE_MESSAGE = 'Intentional TST_RaisingBatch release-test failure';

	/**
	 * @description The start of the name of every Foobar row this job reads.
	 */
	private final String namePrefix;

	/**
	 * @description Creates the job for the Foobar rows whose name starts with the given text.
	 *
	 * @param namePrefix The start of the name of every row the job reads.
	 */
	public TST_RaisingBatch(String namePrefix)
	{
		this.namePrefix = namePrefix;
	}

	/**
	 * @description Reads the Foobar rows whose name starts with the prefix.
	 *
	 * @param context The batch context the platform supplies.
	 *
	 * @return The query over the rows to process.
	 */
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		return kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
				.fields(new List<SObjectField> {kern__Foobar__c.Name})
				.condition(kern__Foobar__c.Name).startsWith(namePrefix)
				.toQueryLocator();
	}

	/**
	 * @description Throws for every group of rows, so the platform reports each call as a failure.
	 *
	 * @param context The batch context the platform supplies.
	 * @param records The rows of this call.
	 */
	public void execute(Database.BatchableContext context, List<SObject> records)
	{
		throw new RaisingBatchException(FAILURE_MESSAGE);
	}

	/**
	 * @description Does nothing: the failures are what the release test reads.
	 *
	 * @param context The batch context the platform supplies.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	public void finish(Database.BatchableContext context)
	{
	}

	/**
	 * @description The exception every `execute()` call throws.
	 */
	public class RaisingBatchException extends Exception
	{
	}
}
