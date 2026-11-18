// SPDX-License-Identifier: Apache-2.0
/**
 * @description Subscriber-side proof that the global members added in 1.12 can be reached and used from a class outside
 * the package. A member that compiles inside the package can still be hidden from, or unusable by, a subscriber class;
 * these tests call each one from here and check what it does through the real call path.
 *
 * Covered: findByTriggeringRecordIds and findByTriggeringRecordValues on the API Call selector and on the API Issue
 * selector, and UTIL_BulkUpdates.copyField used as the release note's script uses it, to fill Triggering Record Index
 * on a call saved while that field was not being filled.
 *
 * Each test runs as a Standard User who holds the package's Administrator permission set, because the finders check the
 * running user's object access, field access and record sharing.
 *
 * @see kern.SEL_ApiCall
 * @see kern.SEL_ApiIssue
 * @see kern.UTIL_BulkUpdates
 * @see kern.TRG_Base
 * @see kern.TST_Builder
 * @see kern.TST_Factory
 *
 * @author your.name@company.com
 *
 * @group Testing
 *
 * @date November 2026
 */
@IsTest(seeAllData=false isParallel=false)
private class SubscriberApi112Surface_TEST
{
	/**
	 * @description The profile of the user every test runs as.
	 */
	private static final String PROFILE_STANDARD_USER = 'Standard User';

	/**
	 * @description The package permission set the running user holds. It gives read and edit access to both objects
	 * and to the Triggering Record Index field, and lets the user see and change every row.
	 */
	private static final String PERMISSION_SET_ADMINISTRATOR = 'Administrator';

	/**
	 * @description Company name of the user the tests run as, by which each test finds the user again.
	 */
	private static final String ADMINISTRATOR_USER_COMPANY = 'SubscriberApi112Surface_TEST-administrator';

	/**
	 * @description A value that is not a record Id, such as an order number from another system, written as the
	 * Triggering Record Id of a call and an issue. It fits the 18 characters the issue's field holds.
	 */
	private static final String ORDER_NUMBER = 'ORD-99182';

	/**
	 * @description The service name written on every call and issue the tests save.
	 */
	private static final String SERVICE_NAME = 'SubscriberApi112SurfaceService';

	/**
	 * @description The most rows each finder may return in these tests.
	 */
	private static final Integer ROW_LIMIT = 10;

	/**
	 * @description How many rows each background job of copyField reads at a time.
	 */
	private static final Integer RECORDS_PER_BATCH = 200;

	/**
	 * @description The field the backfill copies from.
	 */
	private static final String FIELD_TRIGGERING_RECORD_ID = 'kern__TriggeringRecordId__c';

	/**
	 * @description The field the backfill copies into.
	 */
	private static final String FIELD_TRIGGERING_RECORD_INDEX = 'kern__TriggeringRecordIndex__c';

	/**
	 * @description The API name of the API Call object, as the backfill script passes it.
	 */
	private static final String OBJECT_API_CALL = 'kern__ApiCall__c';

	/**
	 * @description Saves the user the tests run as: a Standard User with the package's Administrator permission set.
	 */
	@TestSetup
	private static void setupUser()
	{
		kern.TST_Factory.newUserWithPermissionSet(PROFILE_STANDARD_USER, ADMINISTRATOR_USER_COMPANY, PERMISSION_SET_ADMINISTRATOR);
	}

	/**
	 * @description A call and an issue saved for a record are found by that record's Id, through both selectors. Each
	 * row's Triggering Record Index holds the Id in its 18-character form, as the framework writes it.
	 */
	@IsTest
	private static void shouldFindTheCallAndTheIssueOfARecordByItsId()
	{
		kern__ApiCall__c call;
		kern__ApiIssue__c issue;
		List<kern__ApiCall__c> foundCalls;
		List<kern__ApiIssue__c> foundIssues;

		System.runAs(getAdministratorUser())
		{
			kern__Foobar__c record = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType).build();
			call = insertCall(String.valueOf(record.Id));
			issue = insertIssue(String.valueOf(record.Id));

			Test.startTest();
			foundCalls = new kern.SEL_ApiCall().findByTriggeringRecordIds(new Set<Id> {record.Id}, ROW_LIMIT);
			foundIssues = new kern.SEL_ApiIssue().findByTriggeringRecordIds(new Set<Id> {record.Id}, ROW_LIMIT);
			Test.stopTest();

			Assert.areEqual(1, foundCalls.size(), 'Expected the call saved for the record to be found by its Id');
			Assert.areEqual(call.Id, foundCalls[0].Id, 'Expected the call saved for the record');
			Assert.areEqual(String.valueOf(record.Id), foundCalls[0].kern__TriggeringRecordIndex__c, 'Expected Triggering Record Index of the call to hold the 18-character Id');
			Assert.areEqual(1, foundIssues.size(), 'Expected the issue saved for the record to be found by its Id');
			Assert.areEqual(issue.Id, foundIssues[0].Id, 'Expected the issue saved for the record');
		}
	}

	/**
	 * @description A call and an issue saved with a value that is not a record Id, such as an order number, are found
	 * by that value through the text finder of both selectors.
	 */
	@IsTest
	private static void shouldFindTheCallAndTheIssueByAValueThatIsNotARecordId()
	{
		kern__ApiCall__c call;
		kern__ApiIssue__c issue;
		List<kern__ApiCall__c> foundCalls;
		List<kern__ApiIssue__c> foundIssues;

		System.runAs(getAdministratorUser())
		{
			call = insertCall(ORDER_NUMBER);
			issue = insertIssue(ORDER_NUMBER);

			Test.startTest();
			foundCalls = new kern.SEL_ApiCall().findByTriggeringRecordValues(new Set<String> {ORDER_NUMBER}, ROW_LIMIT);
			foundIssues = new kern.SEL_ApiIssue().findByTriggeringRecordValues(new Set<String> {ORDER_NUMBER}, ROW_LIMIT);
			Test.stopTest();

			Assert.areEqual(1, foundCalls.size(), 'Expected the call saved with the order number to be found by it');
			Assert.areEqual(call.Id, foundCalls[0].Id, 'Expected the call saved with the order number');
			Assert.areEqual(ORDER_NUMBER, foundCalls[0].kern__TriggeringRecordIndex__c, 'Expected Triggering Record Index of the call to hold the order number as written');
			Assert.areEqual(1, foundIssues.size(), 'Expected the issue saved with the order number to be found by it');
			Assert.areEqual(issue.Id, foundIssues[0].Id, 'Expected the issue saved with the order number');
		}
	}

	/**
	 * @description A call saved while its trigger was switched off has Triggering Record Index blank, so the text finder does not find
	 * it. After copyField copies Triggering Record Id into Triggering Record Index, with the search conditions the release
	 * note's script uses, the finder finds it.
	 */
	@IsTest
	private static void shouldFillTheBlankIndexFieldOfACallThroughCopyField()
	{
		List<kern__ApiCall__c> foundBeforeCopy;
		List<kern__ApiCall__c> foundAfterCopy;

		System.runAs(getAdministratorUser())
		{
			kern.TRG_Base.bypass(kern__ApiCall__c.SObjectType);
			kern__ApiCall__c call = insertCall(ORDER_NUMBER);
			kern.TRG_Base.clearBypass(kern__ApiCall__c.SObjectType);
			foundBeforeCopy = new kern.SEL_ApiCall().findByTriggeringRecordValues(new Set<String> {ORDER_NUMBER}, ROW_LIMIT);
			kern.QRY_Condition.Evaluable callsToFill = new kern.QRY_Condition.AndCondition()
					.add(new kern.QRY_Condition.FieldCondition(FIELD_TRIGGERING_RECORD_ID, kern.QRY_Condition.Operator.NOT_EQUALS, null))
					.add(new kern.QRY_Condition.FieldCondition(FIELD_TRIGGERING_RECORD_INDEX, kern.QRY_Condition.Operator.EQUALS, null));

			Test.startTest();
			kern.UTIL_BulkUpdates.copyField(OBJECT_API_CALL, FIELD_TRIGGERING_RECORD_ID, FIELD_TRIGGERING_RECORD_INDEX, callsToFill, RECORDS_PER_BATCH, false);
			Test.stopTest();

			foundAfterCopy = new kern.SEL_ApiCall().findByTriggeringRecordValues(new Set<String> {ORDER_NUMBER}, ROW_LIMIT);

			Assert.isTrue(foundBeforeCopy.isEmpty(), 'Expected a call saved with its trigger switched off to have no Triggering Record Index, so the finder misses it');
			Assert.areEqual(1, foundAfterCopy.size(), 'Expected copyField to fill Triggering Record Index, so the finder finds the call');
			Assert.areEqual(call.Id, foundAfterCopy[0].Id, 'Expected the call whose Triggering Record Index copyField filled');
			Assert.areEqual(ORDER_NUMBER, foundAfterCopy[0].kern__TriggeringRecordIndex__c, 'Expected Triggering Record Index to hold the Triggering Record Id as written');
		}
	}

	/**
	 * @description Finds the user the tests run as.
	 *
	 * @return The Standard User with the Administrator permission set.
	 */
	private static User getAdministratorUser()
	{
		return new kern.SEL_User().findByCompanyName(ADMINISTRATOR_USER_COMPANY);
	}

	/**
	 * @description Saves one call with the given Triggering Record Id.
	 *
	 * @param triggeringRecordId The value to write as the call's Triggering Record Id.
	 *
	 * @return The saved call.
	 */
	private static kern__ApiCall__c insertCall(String triggeringRecordId)
	{
		return (kern__ApiCall__c)kern.TST_Builder.of(kern__ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						kern__ApiCall__c.kern__ServiceName__c => SERVICE_NAME,
						kern__ApiCall__c.kern__TriggeringRecordId__c => triggeringRecordId
				})
				.build();
	}

	/**
	 * @description Saves one issue with the given Triggering Record Id.
	 *
	 * @param triggeringRecordId The value to write as the issue's Triggering Record Id.
	 *
	 * @return The saved issue.
	 */
	private static kern__ApiIssue__c insertIssue(String triggeringRecordId)
	{
		return (kern__ApiIssue__c)kern.TST_Builder.of(kern__ApiIssue__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						kern__ApiIssue__c.kern__ServiceName__c => SERVICE_NAME,
						kern__ApiIssue__c.kern__TriggeringRecordId__c => triggeringRecordId
				})
				.build();
	}
}
