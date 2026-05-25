// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_MaskingRule selector.
 *
 * @see SEL_MaskingRule
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date April 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_MaskingRule_TEST
{
	/**
	 * @description Tests that getFields returns a populated list.
	 */
	@IsTest
	private static void shouldReturnDefaultFields()
	{
		List<SObjectField> fields = new SEL_MaskingRule().getFields();

		Assert.isFalse(fields.isEmpty(), 'getFields should return the default field list');
		Assert.isTrue(fields.contains(MaskingRule__mdt.Mode__c), 'Default fields should include Mode__c');
		Assert.isTrue(fields.contains(MaskingRule__mdt.Pattern__c), 'Default fields should include Pattern__c');
		Assert.isTrue(fields.contains(MaskingRule__mdt.FailureAction__c), 'Default fields should include FailureAction__c');
	}

	/**
	 * @description Tests that the mode and failure-action constants match the MaskingRule__mdt picklist values.
	 * Protects against accidental renames of the picklist values without matching constant updates.
	 */
	@IsTest
	private static void modeConstantsShouldMatchPicklistValues()
	{
		Set<String> modeValues = new Set<String>();

		for(Schema.PicklistEntry entry : MaskingRule__mdt.Mode__c.getDescribe().getPicklistValues())
		{
			modeValues.add(entry.getValue());
		}

		Assert.isTrue(modeValues.contains(SEL_MaskingRule.MODE_REGEX), 'MODE_REGEX constant should match a picklist value');
		Assert.isTrue(modeValues.contains(SEL_MaskingRule.MODE_JSON_KEY), 'MODE_JSON_KEY constant should match a picklist value');
		Assert.isTrue(modeValues.contains(SEL_MaskingRule.MODE_EXACT_MATCH), 'MODE_EXACT_MATCH constant should match a picklist value');
	}

	/**
	 * @description Tests that the failure-action constants match the FailureAction__c picklist values.
	 */
	@IsTest
	private static void failureActionConstantsShouldMatchPicklistValues()
	{
		Set<String> failureValues = new Set<String>();

		for(Schema.PicklistEntry entry : MaskingRule__mdt.FailureAction__c.getDescribe().getPicklistValues())
		{
			failureValues.add(entry.getValue());
		}

		Assert.isTrue(failureValues.contains(SEL_MaskingRule.FAILURE_LOG_AND_CONTINUE), 'FAILURE_LOG_AND_CONTINUE constant should match a picklist value');
		Assert.isTrue(failureValues.contains(SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER), 'FAILURE_WRITE_FAILURE_MARKER constant should match a picklist value');
		Assert.isTrue(failureValues.contains(SEL_MaskingRule.FAILURE_BLOCK_DML), 'FAILURE_BLOCK_DML constant should match a picklist value');
	}

	/**
	 * @description Tests that the MODE_CREDIT_CARD constant matches the picklist value string
	 * exactly. The framework masker dispatches on this constant when routing to
	 * `UTIL_String.maskWithLuhnValidatedRegex`; any drift between the Apex constant and the
	 * `MaskingRule__mdt.Mode__c` restricted picklist entry would cause silent no-ops.
	 */
	@IsTest
	private static void shouldExposeCreditCardModeConstant()
	{
		Assert.areEqual('CreditCard', SEL_MaskingRule.MODE_CREDIT_CARD, 'Constant value must match the Mode__c picklist value exactly');
	}
}