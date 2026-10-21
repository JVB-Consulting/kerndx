// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_FieldDefinition selector. Self-contained: exercises every path
 * without relying on a consumer's tests. The tests do not run in parallel, because one of them creates a user to run
 * as, and the platform refuses to create a user in a parallel test.
 *
 * @see SEL_FieldDefinition
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date May 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_FieldDefinition_TEST
{
	/**
	 * @description The company name of the user with the Minimum Access profile that the access test runs as.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_FieldDefinition_TEST-low-privilege';

	/**
	 * @description Tests that `findByEntity` runs the bounded EntityDefinition query and returns the
	 * field definitions for a known standard object. Account always exposes queryable fields, so the
	 * result is non-empty. This exercises the `toList` query path.
	 */
	@IsTest
	private static void findByEntityReturnsFieldsForKnownObject()
	{
		List<FieldDefinition> results = new SEL_FieldDefinition().findByEntity('Account');

		Assert.isNotNull(results, 'Should return a list, never null');
		Assert.isFalse(results.isEmpty(), 'Account exposes queryable field definitions');
	}

	/**
	 * @description Tests that `findByEntity` short-circuits to an empty list for a blank or null
	 * SObject name, avoiding an unbounded FieldDefinition query the platform would reject.
	 */
	@IsTest
	private static void findByEntityReturnsEmptyForBlankName()
	{
		Assert.isTrue(new SEL_FieldDefinition().findByEntity('').isEmpty(), 'Blank name short-circuits to empty');
		Assert.isTrue(new SEL_FieldDefinition().findByEntity(null).isEmpty(), 'Null name short-circuits to empty');
	}

	/**
	 * @description Tests that `findByDurableIds` finds a field by its durable Id, the fixed key the platform gives
	 * each field, and that the result carries the field's API name and the API name of its object. The durable Id
	 * is read from the org first, through `findByEntity`.
	 */
	@IsTest
	private static void findByDurableIdsReturnsTheFieldWithTheNameOfItsObject()
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c);
		String durableId = findDurableIdOfFoobarText();

		List<FieldDefinition> results = new SEL_FieldDefinition().findByDurableIds(new Set<String> {durableId});

		Assert.areEqual(1, results.size(), 'Expected one field for one durable Id');
		Assert.areEqual(durableId, results[0].DurableId, 'Expected the field with the durable Id asked for');
		Assert.areEqual(fieldName, results[0].QualifiedApiName, 'Expected the field to carry its API name');
		Assert.areEqual(objectName, results[0].EntityDefinition.QualifiedApiName, 'Expected the field to carry the API name of its object');
	}

	/**
	 * @description Tests that `findByDurableIds` finds a field for a user who has no access to the field or its
	 * object. The masker reads the field of a deployed masking target this way, so a target that names a field must
	 * work whoever saves the record. The user has the Minimum Access profile and no permission on `Foobar__c`.
	 */
	@IsTest
	private static void findByDurableIdsReturnsTheFieldForAUserWithoutAccessToItsObject()
	{
		String durableId = findDurableIdOfFoobarText();
		List<FieldDefinition> results;

		System.runAs(TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY))
		{
			results = new SEL_FieldDefinition().findByDurableIds(new Set<String> {durableId});
		}

		Assert.areEqual(1, results.size(), 'Expected one field for one durable Id, for a user without access to the object');
		Assert.areEqual(durableId, results[0].DurableId, 'Expected the field with the durable Id asked for');
	}

	/**
	 * @description Tests that `findByDurableIds` returns an empty list for a null or empty set of durable Ids.
	 */
	@IsTest
	private static void findByDurableIdsReturnsEmptyWithoutDurableIds()
	{
		Assert.isTrue(new SEL_FieldDefinition().findByDurableIds(null).isEmpty(), 'Expected an empty list for a null set');
		Assert.isTrue(new SEL_FieldDefinition().findByDurableIds(new Set<String>()).isEmpty(), 'Expected an empty list for an empty set');
	}

	/**
	 * @description Tests that `getFields` returns the classification fields the advisor surfaces.
	 */
	@IsTest
	private static void getFieldsReturnsClassificationFields()
	{
		List<SObjectField> fields = new SEL_FieldDefinition().getFields();

		Assert.isFalse(fields.isEmpty(), 'getFields should return the default field list');
		Assert.isTrue(fields.contains(FieldDefinition.SecurityClassification), 'Default fields should include SecurityClassification');
		Assert.isTrue(fields.contains(FieldDefinition.ComplianceGroup), 'Default fields should include ComplianceGroup');
		Assert.isTrue(fields.contains(FieldDefinition.QualifiedApiName), 'Default fields should include QualifiedApiName');
		Assert.isTrue(fields.contains(FieldDefinition.DurableId), 'Default fields should include DurableId');
	}

	/**
	 * @description Tests that `systemModeRequired` is true. FieldDefinition is Setup metadata that
	 * running users typically can't read, so the selector must run in SYSTEM_MODE.
	 */
	@IsTest
	private static void shouldRequireSystemMode()
	{
		Assert.isTrue(new SEL_FieldDefinition().systemModeRequired(), 'FieldDefinition selector must always run in SYSTEM_MODE');
	}

	/**
	 * @description Tests that the selector routes through `QRY_Builder`, so a registered `TST_Mock`
	 * exception surfaces to the caller. This is the interceptability the advisor's classification read
	 * relies on to exercise its graceful-fallback (catch) path without a live query.
	 */
	@IsTest
	private static void findByEntitySurfacesMockedQueryFailure()
	{
		TST_Mock.throwsException(FieldDefinition.SObjectType, 'Simulated FieldDefinition query failure');

		try
		{
			new SEL_FieldDefinition().findByEntity('Account');
			Assert.fail('Expected the mocked query exception to surface');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Simulated FieldDefinition query failure', error.getMessage(), 'the registered mock exception surfaces to the caller');
		}
	}

	/**
	 * @description Reads the durable Id of `Foobar__c.Text__c` from the org through `findByEntity`. The durable Id is
	 * the fixed key the platform gives each field.
	 *
	 * @return The durable Id of the field
	 */
	private static String findDurableIdOfFoobarText()
	{
		String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c);
		String durableId;
		for(FieldDefinition field : new SEL_FieldDefinition().findByEntity(UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType)))
		{
			if(field.QualifiedApiName == fieldName)
			{
				durableId = field.DurableId;
			}
		}
		return durableId;
	}
}