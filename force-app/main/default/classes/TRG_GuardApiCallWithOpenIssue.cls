// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Refuses the delete of an API call that still has an open API issue. Runs before every delete of
 * ApiCall__c, after the permission check (TRG_GuardApiRecordDeletion) and before the action that deletes the call's files,
 * so no file of a refused call is deleted.
 *
 * An open issue is a failure that nobody has dealt with yet, and its call holds the request that a retry runs again. So
 * a call with an open issue is kept from every user: a holder of the Delete API Records permission, a user the
 * BypassApiRecordDeleteGuard feature flag is on for, a System Administrator, and the scheduled purge (UTIL_PurgeRecords)
 * alike. This action reads no feature flag. To delete such a call, first resolve or dismiss its issue. The purge leaves
 * these calls out of what it deletes, so it does not log a refusal for each one.
 *
 * The action reads the open issues of the whole batch in one query, whoever owns them. A call that an earlier action
 * already refused is not checked again, so a delete the permission check refused costs no query. If the transaction has
 * no query left, the action refuses every call it still has to check, rather than let a delete through unchecked. A
 * refused call gets the DeleteApiCall_OpenIssue message, and in a delete that allows some rows to fail, the other calls
 * are still deleted.
 *
 * @see TRG_GuardApiCallWithOpenIssue_TEST
 * @see TRG_GuardApiRecordDeletion
 * @see SEL_ApiIssue
 * @see UTIL_PurgeRecords
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date October 2026
 */
@SuppressWarnings('ApexUnusedDeclaration,RedundantSuppression')
public inherited sharing class TRG_GuardApiCallWithOpenIssue extends TRG_Base implements IF_Trigger.BeforeDelete
{
	/**
	 * @description Refuses each call that has an open issue, with the labelled message. Skips a call an earlier action
	 * already refused. With no query left, refuses every call it still has to check.
	 *
	 * @param oldRecords The API calls about to be deleted.
	 */
	public void beforeDelete(List<SObject> oldRecords)
	{
		Map<Id, SObject> callsToCheck = new Map<Id, SObject>();
		for(SObject apiCall : oldRecords)
		{
			if(!apiCall.hasErrors())
			{
				callsToCheck.put(apiCall.Id, apiCall);
			}
		}

		if(callsToCheck.isEmpty())
		{
			return;
		}

		if(UTIL_Limits.soqlQueries().isExhausted())
		{
			refuse(callsToCheck.values());
			return;
		}

		List<SObject> callsWithOpenIssue = new List<SObject>();
		for(ApiIssue__c openIssue : new SEL_ApiIssue().findOpenByApiCalls(callsToCheck.keySet()))
		{
			SObject apiCall = callsToCheck.remove(openIssue.ApiCall__c);
			if(apiCall != null)
			{
				callsWithOpenIssue.add(apiCall);
			}
		}
		refuse(callsWithOpenIssue);
	}

	/**
	 * @description Puts the labelled refusal on each of the given calls.
	 *
	 * @param apiCalls The calls whose delete is refused.
	 */
	private static void refuse(List<SObject> apiCalls)
	{
		for(SObject apiCall : apiCalls)
		{
			apiCall.addError(System.Label.DeleteApiCall_OpenIssue);
		}
	}
}
