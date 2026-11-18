// SPDX-License-Identifier: Apache-2.0
/**
 * @description Stands in for the reader's own service that the scheduled job sample of the Why KernDX page calls. It
 * archives nothing. It saves a task whose subject names the number of days it was given, so a test can see what the job
 * passed in.
 *
 * @see CaseArchiveJob
 * @see DocumentationSamplesFrontPage_TEST
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
public with sharing class CaseArchiveService
{
	/**
	 * @description The start of the subject of the task this service saves; the number of days follows it.
	 */
	public static final String SUBJECT_PREFIX = 'Archive cases older than ';

	/**
	 * @description Saves a task that says how many days of cases the job asked to keep.
	 *
	 * @param daysToKeep The number of days of cases to keep.
	 */
	public static void archiveOlderThan(Integer daysToKeep)
	{
		kern.DML_Builder.newTransaction().doInsert(new Task(Subject = SUBJECT_PREFIX + daysToKeep)).execute();
	}
}
