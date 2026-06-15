// SPDX-License-Identifier: BUSL-1.1
/**
 * @description An action that will delete an linked content documents to the API call being deleted
 *
 * @see TRG_DeleteApiCallDocuments_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, June 2026
 */
@SuppressWarnings('ApexUnusedDeclaration,RedundantSuppression')
public inherited sharing class TRG_DeleteApiCallDocuments extends TRG_Base implements IF_Trigger.BeforeDelete
{
	/**
	 * @description Will ensure that any files linked to the API call are deleted
	 *
	 * @param oldList The items being deleted
	 */
	public void beforeDelete(List<ApiCall__c> oldList)
	{
		Set<Id> apiCallIds = UTIL_SObject.extractIds(oldList);

		List<ContentVersion> foundVersions = new SEL_ContentVersion().findByFirstPublishLocationId(apiCallIds);
		Set<Id> contentDocumentIds = UTIL_SObject.extractIds(foundVersions, ContentVersion.ContentDocumentId);

		List<ContentDocument> documentsToDelete = new List<ContentDocument>();

		for(Id contentDocumentId : contentDocumentIds)
		{
			ContentDocument documentToDelete = new ContentDocument();
			documentToDelete.Id = contentDocumentId;
			documentsToDelete.add(documentToDelete);
		}

		DML_Builder.newTransaction().systemModeInternal().doDelete(documentsToDelete).execute();
	}
}