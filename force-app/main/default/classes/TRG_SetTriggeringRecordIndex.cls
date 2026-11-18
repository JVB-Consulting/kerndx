// SPDX-License-Identifier: Apache-2.0
/**
 * @description Copies the Triggering Record ID field into the Triggering Record Index field. Runs before every insert
 * and every update of ApiCall__c and ApiIssue__c.
 *
 * Triggering Record Index is an External ID field, so the database keeps an index on it, and a search by the field
 * stays fast however many rows there are. The source field has no such index.
 *
 * On every save the field gets the source value exactly as written. The value can be a record Id or any other text,
 * such as an order number. Nothing is checked or changed: a 15-character Id stays 15 characters, upper and lower case
 * are kept, and a blank source gives a blank value. Because the field is set again on every save, it always matches its
 * source, even when some other code writes the field directly.
 *
 * The action runs after the other before-save actions on these objects, so it sees the final source value. A save made
 * while the trigger framework is turned off for the object leaves the field as it was.
 *
 * @see TRG_SetTriggeringRecordIndex_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date November 2026
 */
@SuppressWarnings('ApexUnusedDeclaration,RedundantSuppression')
public inherited sharing class TRG_SetTriggeringRecordIndex extends TRG_Base implements IF_Trigger.BeforeInsert, IF_Trigger.BeforeUpdate
{
	/**
	 * @description The Triggering Record ID field of each object the action serves: the value the action copies.
	 */
	private static final Map<SObjectType, SObjectField> SOURCE_FIELD_BY_OBJECT = new Map<SObjectType, SObjectField>
	{
			ApiCall__c.SObjectType => ApiCall__c.TriggeringRecordId__c,
			ApiIssue__c.SObjectType => ApiIssue__c.TriggeringRecordId__c
	};

	/**
	 * @description The Triggering Record Index field of each object the action serves: the field the action fills.
	 */
	private static final Map<SObjectType, SObjectField> INDEX_FIELD_BY_OBJECT = new Map<SObjectType, SObjectField>
	{
			ApiCall__c.SObjectType => ApiCall__c.TriggeringRecordIndex__c,
			ApiIssue__c.SObjectType => ApiIssue__c.TriggeringRecordIndex__c
	};

	/**
	 * @description Fills Triggering Record Index on each new row from its source field.
	 *
	 * @param newRecords The API calls or API issues about to be inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		copySourceIntoIndexField(newRecords);
	}

	/**
	 * @description Fills Triggering Record Index on each changed row from its source field again, so the field follows
	 * any change of the source and undoes any direct change of the field.
	 *
	 * @param newRecords The API calls or API issues about to be updated, with their new values.
	 * @param oldRecords The same rows with the values they had before the update. Not used.
	 */
	public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		copySourceIntoIndexField(newRecords);
	}

	/**
	 * @description Puts the source value of each row into its Triggering Record Index field, unchanged. A blank source
	 * gives a blank value.
	 *
	 * @param records The rows about to be saved.
	 */
	private static void copySourceIntoIndexField(List<SObject> records)
	{
		for(SObject record : records)
		{
			SObjectType objectType = record.getSObjectType();
			record.put(INDEX_FIELD_BY_OBJECT.get(objectType), record.get(SOURCE_FIELD_BY_OBJECT.get(objectType)));
		}
	}
}
