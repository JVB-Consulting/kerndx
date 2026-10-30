// SPDX-License-Identifier: Apache-2.0
/**
 * @description Release-testing queueable that makes an outbound call the org refuses before it leaves, because a save
 * earlier in the same transaction left work pending. Given no record, it inserts a Foobar first (a save in a Queueable);
 * given a record, it deletes that record first (a save that is a delete). Either way the call, a POST without an
 * Idempotency-Key header, with one retry and a long wait, never reaches the external system: it must rest at Retry with a time, with no issue flag saying
 * the external system may have acted and no circuit breaker failure. Section 84 enqueues it and section 84b reads the
 * result. A Foobar it inserts is deleted after the call. The call names the saved or deleted record as its triggering
 * record, which is how section 84b finds the call's issue: an ad-hoc call is stored under the framework's own handler
 * name, not its credential.
 *
 * @see kern.UTIL_HttpClient
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
public with sharing class RetryLiveNeverSentJob implements Queueable, Database.AllowsCallouts
{
	/**
	 * @description The path the call is sent to. The org refuses the call before it leaves, because of the save before
	 * it. The credential does not exist either, a second guard, so the path is never reached.
	 */
	private static final String PATH = '/never-sent';

	/**
	 * @description The one retry the call is given, so a refused call is scheduled rather than ended.
	 */
	private static final Integer RETRY_BUDGET = 1;

	/**
	 * @description The wait before the scheduled retry, long enough that section 84b reads the call before the retry runs.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 600;

	/**
	 * @description The name the Foobar this job inserts carries, so a leftover is easy to find.
	 */
	private static final String FOOBAR_NAME = 'RetryLiveNeverSentJob';

	/**
	 * @description The Named Credential the call names, which is also the call's service name and circuit breaker name.
	 */
	private final String credentialName;

	/**
	 * @description The record to delete before the call, or null to insert a Foobar before it.
	 */
	private final Id recordToDelete;

	/**
	 * @description Builds the job for one call.
	 *
	 * @param credentialName The Named Credential the call names. It must not exist, so that a call the org did not
	 * refuse would still never reach an external system.
	 * @param recordToDelete The record to delete before the call, or null to insert a Foobar before it.
	 */
	public RetryLiveNeverSentJob(String credentialName, Id recordToDelete)
	{
		this.credentialName = credentialName;
		this.recordToDelete = recordToDelete;
	}

	/**
	 * @description Saves first, then makes the call the org refuses, then deletes the Foobar it inserted.
	 *
	 * @param context The queueable context; unused.
	 */
	public void execute(QueueableContext context)
	{
		kern__Foobar__c inserted;
		if(recordToDelete == null)
		{
			inserted = new kern__Foobar__c(Name = FOOBAR_NAME);
			kern.DML_Builder.newTransaction().doInsert(inserted).execute();
		}
		else
		{
			kern.DML_Builder.newTransaction().doDelete(recordToDelete.getSObjectType().newSObject(recordToDelete)).execute();
		}

		kern.UTIL_HttpClient.post(credentialName, PATH)
				.withTriggeringRecord(inserted?.Id ?? recordToDelete)
				.withRetry(RETRY_BUDGET, RETRY_BACKOFF_SECONDS)
				.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
				.withCircuitBreaker()
				.send();

		if(inserted != null)
		{
			kern.DML_Builder.newTransaction().doDelete(inserted).execute();
		}
	}
}
