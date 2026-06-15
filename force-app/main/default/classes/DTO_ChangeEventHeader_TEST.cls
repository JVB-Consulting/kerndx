// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for DTO_ChangeEventHeader. Exercises the full copy-constructor
 * mapping from EventBus.ChangeEventHeader to the Flow-accessible DTO, plus the no-arg
 * constructor required by some Flow runtime entry points.
 *
 * @see DTO_ChangeEventHeader
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date May 2026
 */
@IsTest(SeeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class DTO_ChangeEventHeader_TEST
{
	/**
	 * @description Verifies that the copy constructor maps every supported field from a
	 * platform EventBus.ChangeEventHeader to the DTO. The platform header type has no
	 * public constructor — we build one via JSON.deserialize using standard-object values
	 * (Account / User SObjectTypes) so the assertions remain namespace-immune when the
	 * test class ships with the managed package and runs in a subscriber org.
	 */
	@IsTest
	private static void shouldCopyEveryHeaderFieldFromPlatformHeader()
	{
		// Generate canonical 18-char Salesforce Ids via UTIL_Random.randomId — the JSON
		// deserializer auto-extends a 15-char Id to its 18-char form, which would break a
		// verbatim string assertion. The Id type itself is always 18-char in Apex, so a
		// generated Id is round-trip safe through JSON.
		String accountId = String.valueOf(UTIL_Random.randomId(Account.SObjectType));
		String secondAccountId = String.valueOf(UTIL_Random.randomId(Account.SObjectType));
		String userId = String.valueOf(UTIL_Random.randomId(User.SObjectType));
		Map<String, Object> headerData = new Map<String, Object>
		{
				'entityName' => 'Account',
				'changeType' => 'CREATE',
				'changeOrigin' => 'user/' + accountId,
				'transactionKey' => 'tx-key-0001',
				'sequenceNumber' => 1,
				'commitTimestamp' => 1717000000000L,
				'commitUser' => userId,
				'commitNumber' => 42L,
				'recordIds' => new List<String> {accountId, secondAccountId},
				'changedFields' => new List<String> {'Name', 'Description'},
				'nulledFields' => new List<String> {'Industry'},
				'diffFields' => new List<String> {'AnnualRevenue'}
		};
		EventBus.ChangeEventHeader source = (EventBus.ChangeEventHeader)JSON.deserialize(JSON.serialize(headerData), EventBus.ChangeEventHeader.class);

		Test.startTest();
		DTO_ChangeEventHeader dto = new DTO_ChangeEventHeader(source);
		Test.stopTest();

		Assert.areEqual('Account', dto.entityName, 'entityName should be copied verbatim');
		Assert.areEqual('CREATE', dto.changeType, 'changeType should be copied verbatim');
		Assert.areEqual('user/' + accountId, dto.changeOrigin, 'changeOrigin should be copied verbatim');
		Assert.areEqual('tx-key-0001', dto.transactionKey, 'transactionKey should be copied verbatim');
		Assert.areEqual(1, dto.sequenceNumber, 'sequenceNumber should be copied verbatim');
		Assert.areEqual(1717000000000L, dto.commitTimestamp, 'commitTimestamp should be copied verbatim');
		Assert.areEqual(userId, dto.commitUser, 'commitUser should be copied verbatim');
		Assert.areEqual(42L, dto.commitNumber, 'commitNumber should be copied verbatim');
		Assert.areEqual(new List<String> {accountId, secondAccountId}, dto.recordIds, 'recordIds list copied verbatim');
		Assert.areEqual(new List<String> {'Name', 'Description'}, dto.changedFields, 'changedFields list copied verbatim');
		Assert.areEqual(new List<String> {'Industry'}, dto.nulledFields, 'nulledFields list copied verbatim');
		Assert.areEqual(new List<String> {'AnnualRevenue'}, dto.diffFields, 'diffFields list copied verbatim');
	}

	/**
	 * @description Verifies that the no-arg constructor leaves all fields null. Some Flow
	 * runtime entry points instantiate Apex-defined variable types via the empty constructor
	 * before populating fields, so this contract must be preserved.
	 */
	@IsTest
	private static void shouldConstructEmptyDtoWithAllFieldsNull()
	{
		Test.startTest();
		DTO_ChangeEventHeader dto = new DTO_ChangeEventHeader();
		Test.stopTest();

		Assert.isNull(dto.entityName, 'entityName should default to null');
		Assert.isNull(dto.recordIds, 'recordIds should default to null');
		Assert.isNull(dto.changeType, 'changeType should default to null');
		Assert.isNull(dto.changeOrigin, 'changeOrigin should default to null');
		Assert.isNull(dto.transactionKey, 'transactionKey should default to null');
		Assert.isNull(dto.sequenceNumber, 'sequenceNumber should default to null');
		Assert.isNull(dto.commitTimestamp, 'commitTimestamp should default to null');
		Assert.isNull(dto.commitUser, 'commitUser should default to null');
		Assert.isNull(dto.commitNumber, 'commitNumber should default to null');
		Assert.isNull(dto.changedFields, 'changedFields should default to null');
		Assert.isNull(dto.nulledFields, 'nulledFields should default to null');
		Assert.isNull(dto.diffFields, 'diffFields should default to null');
	}
}