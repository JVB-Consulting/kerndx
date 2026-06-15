// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_FieldDefinition selector. Self-contained — exercises every path
 * without relying on a consumer's tests.
 *
 * @see SEL_FieldDefinition
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_FieldDefinition_TEST
{
	/**
	 * @description Tests that `findByEntity` runs the bounded EntityDefinition query and returns the
	 * field definitions for a known standard object. Account always exposes queryable fields, so the
	 * result is non-empty — exercising the `toList` query path.
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
	}

	/**
	 * @description Tests that `systemModeRequired` is true — FieldDefinition is Setup metadata that
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
}