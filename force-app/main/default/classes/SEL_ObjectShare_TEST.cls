// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ObjectShare.
 *
 * @see SEL_ObjectShare
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ObjectShare_TEST
{
	/**
	 * @description Tests getShareDescribe for a custom object returns correct share object metadata.
	 */
	@IsTest
	private static void getShareDescribeForCustomObjectReturnsCorrectMetadata()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		SEL_ObjectShare.DTO_ObjectShareDescribe result = SEL_ObjectShare.getShareDescribe(record.Id);

		Assert.areEqual(SEL_ObjectShare.FIELD_ACCESS_LEVEL, result.accessLevel, 'Custom objects use AccessLevel field');
		Assert.areEqual('ParentId', result.parentIdFieldName, 'Custom objects use ParentId field');
		Assert.areEqual('Parent', result.parentObjectFieldName, 'Custom objects use Parent relationship');
		Assert.isTrue(result.shareObjectName.endsWith('__Share'), 'Custom object share name should end with __Share');
		Assert.isNotNull(result.estimatedHeapSize, 'Heap size should be set');
	}

	/**
	 * @description Tests getShareDescribe for Account returns correct share object metadata with special handling.
	 */
	@IsTest
	private static void getShareDescribeForAccountReturnsSpecialShareMetadata()
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType).withoutInsertion(true).build();

		SEL_ObjectShare.DTO_ObjectShareDescribe result = SEL_ObjectShare.getShareDescribe(account.Id);

		Assert.areEqual('AccountAccessLevel', result.accessLevel, 'Account uses AccountAccessLevel field');
		Assert.areEqual('AccountId', result.parentIdFieldName, 'Account uses AccountId field');
		Assert.areEqual('Account', result.parentObjectFieldName, 'Account uses Account relationship');
		Assert.areEqual('AccountShare', result.shareObjectName, 'Account share object is AccountShare');
	}

	/**
	 * @description Tests newShareObject creates a new share SObject instance.
	 */
	@IsTest
	private static void newShareObjectCreatesShareInstance()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		SEL_ObjectShare.DTO_ObjectShareDescribe shareDescribe = SEL_ObjectShare.getShareDescribe(record.Id);

		SObject result = shareDescribe.newShareObject();

		Assert.isNotNull(result, 'Share object should be created');
		Assert.isTrue(String.valueOf(result.getSObjectType()).endsWith('__Share'), 'Should be a share object');
	}

	/**
	 * @description Tests DTO_ObjectShareDescribe handles null SObjectType gracefully.
	 */
	@IsTest
	private static void dtoObjectShareDescribeHandlesNullType()
	{
		SEL_ObjectShare.DTO_ObjectShareDescribe result = new SEL_ObjectShare.DTO_ObjectShareDescribe(null);

		Assert.isNull(result.shareObjectName, 'Share object name should be null for null type');
		Assert.isNull(result.accessLevel, 'Access level should be null for null type');
	}

	/**
	 * @description Tests newShareObject returns null when share object name is blank.
	 */
	@IsTest
	private static void newShareObjectReturnsNullWhenNameBlank()
	{
		SEL_ObjectShare.DTO_ObjectShareDescribe shareDescribe = new SEL_ObjectShare.DTO_ObjectShareDescribe(null);

		SObject result = shareDescribe.newShareObject();

		Assert.isNull(result, 'Should return null when share object name is blank');
	}

	/**
	 * @description Tests public constants are accessible and have expected values.
	 */
	@IsTest
	private static void publicConstantsAreAccessible()
	{
		Assert.areEqual('AccessLevel', SEL_ObjectShare.FIELD_ACCESS_LEVEL, 'FIELD_ACCESS_LEVEL constant');
		Assert.areEqual('None', SEL_ObjectShare.ACCESS_LEVEL_NONE, 'ACCESS_LEVEL_NONE constant');
		Assert.areEqual('RowCause', SEL_ObjectShare.FIELD_ROW_CAUSE, 'FIELD_ROW_CAUSE constant');
		Assert.areEqual('UserOrGroupId', SEL_ObjectShare.FIELD_USER_OR_GROUP_ID, 'FIELD_USER_OR_GROUP_ID constant');
		Assert.areEqual('Manual', SEL_ObjectShare.ROW_CAUSE_MANUAL, 'ROW_CAUSE_MANUAL constant');
		Assert.areEqual('AccountShare', SEL_ObjectShare.OBJECT_ACCOUNT_SHARE, 'OBJECT_ACCOUNT_SHARE constant');
		Assert.isNotNull(SEL_ObjectShare.FIELD_OPPORTUNITY_ACCESS_LEVEL, 'FIELD_OPPORTUNITY_ACCESS_LEVEL constant');
	}
}