// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for UTIL_FrameworkMasker.
 *
 * @see UTIL_FrameworkMasker
 *
 * @author Jason van Beukering
 *
 * @group Data Masking
 *
 * @date April 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ExcessiveParameterList,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class UTIL_FrameworkMasker_TEST
{
	/**
	 * @description The company name that marks the administrator user these tests run as.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_FrameworkMasker_TEST-admin';

	/**
	 * @description The company name that marks the low-privilege user the sharing and permission tests run as.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_FrameworkMasker_TEST-low-privilege';

	/**
	 * @description Sample value used across tests.
	 */
	private static final String SAMPLE_VALUE = 'alice@example.com';

	/**
	 * @description Sample caller class name used across tests.
	 */
	private static final String SAMPLE_CALLER = 'API_SendEmail';

	/**
	 * @description DeveloperName of the superseded predecessor rule in the supersession matrix.
	 */
	private static final String PREDECESSOR_RULE_NAME = 'OldCardRule';

	/**
	 * @description DeveloperName of the successor rule in the supersession matrix.
	 */
	private static final String SUCCESSOR_RULE_NAME = 'NewCardRule';

	/**
	 * @description A run key in the shape the chain engine creates (a version-4 UUID) whose last two groups look like a
	 * sixteen-digit payment card number to a card rule. A test run at high volume met this case once in several
	 * thousand chain starts.
	 */
	private static final String CARD_SHAPED_RUN_KEY = 'fb1f69f6-6768-4768-8833-380884223126';

	/**
	 * @description The shipped card rule's pattern: thirteen to nineteen digits, spaces or hyphens between them.
	 */
	private static final String CARD_PATTERN = '\\b\\d(?:[ -]?\\d){12,18}\\b';

	/**
	 * @description The token the shipped card rule writes in place of a matched card number.
	 */
	private static final String CARD_REPLACEMENT = '[CARD_REDACTED]';

	/**
	 * @description Token that only the predecessor rule matches. If it is still in an output value,
	 * the predecessor's target was dropped; if it was replaced, the predecessor ran.
	 */
	private static final String PREDECESSOR_TOKEN = 'PRED-TOKEN';

	/**
	 * @description Token only the successor rule matches, making the successor's application
	 * observable independently of the predecessor's.
	 */
	private static final String SUCCESSOR_TOKEN = 'SUCC-TOKEN';

	/**
	 * @description Replacement the predecessor rule writes. If it appears, the predecessor ran.
	 */
	private static final String PREDECESSOR_REPLACEMENT = '[P]';

	/**
	 * @description Replacement the successor rule writes. If it appears, the successor ran.
	 */
	private static final String SUCCESSOR_REPLACEMENT = '[S]';

	/**
	 * @description Replacement a tuned predecessor writes. If it appears, the tuned rule kept running.
	 */
	private static final String TUNED_REPLACEMENT = '[P-TUNED]';

	/**
	 * @description The fingerprint the entry masked by a misconfigured log rule is written with.
	 */
	private static final String MASKED_ENTRY_FINGERPRINT = 'masked-entry-fingerprint';

	/**
	 * @description The class and method that entry is written at.
	 */
	private static final String MASKED_ENTRY_CLASS_METHOD = 'OrderService.submitOrder';

	/**
	 * @description DeveloperName of the rule whose applicable field types name a type that does not exist.
	 */
	private static final String UNKNOWN_TYPE_RULE_NAME = 'LogEventUnknownFieldTypeRule';

	/**
	 * @description DeveloperName of the rule wired to a field whose type it excludes.
	 */
	private static final String MISMATCHED_TYPE_RULE_NAME = 'LogEventMismatchedFieldTypeRule';

	/**
	 * @description A field type no Apex type name matches, as an admin's typo leaves it.
	 */
	private static final String UNKNOWN_FIELD_TYPE = 'TEXTFIELD';

	/**
	 * @description A value no message of the test entry holds, so the misconfigured rules change nothing.
	 */
	private static final String UNMATCHED_TOKEN = 'never-in-a-message';

	/**
	 * @description Where the masker would say that a rule names a field type that does not exist.
	 */
	private static final String UNKNOWN_TYPE_WARNING_LOCATION = UTIL_FrameworkMasker.class.getName() + UTIL_String.DOT + 'parseApplicableFieldTypes';

	/**
	 * @description Where the masker would say that a target is wired to a field type its rule excludes.
	 */
	private static final String MISMATCHED_TYPE_WARNING_LOCATION = UTIL_FrameworkMasker.class.getName() + UTIL_String.DOT + 'filterTargetsByFieldType';

	/**
	 * @description Creates a separate test admin user, so System.runAs in each test starts with fresh
	 * permission checks. This avoids a problem in test orgs where cached permissions went stale when
	 * the running user's permission sets changed during a transaction. Also commits a low-privilege
	 * user (Minimum Access - Salesforce profile), so the low-privilege test
	 * (shouldMaskRecordForLowPrivilegeUser) can use System.runAs without causing
	 * MIXED_DML_OPERATION. User is a Setup object, and DML on users cannot be mixed with DML on
	 * standard or custom objects in the same transaction; creating the user here avoids that.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Tests that isMaskingEnabled returns true when the flag is active.
	 */
	@IsTest
	private static void isMaskingEnabledShouldReturnTrueWhenFlagIsActive()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);

			Assert.isTrue(UTIL_FrameworkMasker.isMaskingEnabled, 'isMaskingEnabled should return true when the flag is on');
		}
	}

	/**
	 * @description Tests that isMaskingEnabled returns false when an admin overrides the
	 * shipped default to disable the framework (simulated by removing it from the active
	 * flag cache).
	 */
	@IsTest
	private static void isMaskingEnabledShouldReturnFalseWhenFlagOverriddenOff()
	{
		System.runAs(getTestAdmin())
		{
			SEL_FeatureFlag.activeFlags.remove(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);

			Assert.isFalse(UTIL_FrameworkMasker.isMaskingEnabled, 'isMaskingEnabled should return false when the flag is disabled');
		}
	}

	/**
	 * @description Tests that isMaskingEnabled caches the result per transaction.
	 */
	@IsTest
	private static void isMaskingEnabledShouldCachePerTransaction()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);

			Boolean firstCall = UTIL_FrameworkMasker.isMaskingEnabled;
			Boolean secondCall = UTIL_FrameworkMasker.isMaskingEnabled;

			Assert.areEqual(firstCall, secondCall, 'Repeated reads should return the same cached value');
		}
	}

	/**
	 * @description Tests that mask returns the input unchanged in the skeleton.
	 */
	@IsTest
	private static void shouldPassInputThroughInSkeleton()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Email__c).mask(SAMPLE_VALUE);

			Assert.areEqual(SAMPLE_VALUE, result.maskedValue, 'maskedValue should equal input in the skeleton');
			Assert.areEqual(SAMPLE_VALUE.length(), result.originalLength, 'originalLength should reflect the input');
			Assert.areEqual(SAMPLE_VALUE.length(), result.maskedLength, 'maskedLength should equal originalLength when no changes');
		}
	}

	/**
	 * @description Tests that mask handles null input.
	 */
	@IsTest
	private static void shouldHandleNullValue()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Email__c).mask(null);

			Assert.isNull(result.maskedValue, 'maskedValue should be null for null input');
			Assert.areEqual(0, result.originalLength, 'originalLength should be 0 for null input');
			Assert.areEqual(0, result.maskedLength, 'maskedLength should be 0 for null input');
		}
	}

	/**
	 * @description Tests that calledFrom is persisted on the FieldMasker builder.
	 */
	@IsTest
	private static void shouldRecordCalledFromOnFieldMasker()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(Foobar__c.Email__c).calledFrom(SAMPLE_CALLER);

			Assert.areEqual(SAMPLE_CALLER, masker.callerClassName, 'calledFrom should be stored on the builder');
		}
	}

	/**
	 * @description Tests that RecordMasker.apply returns a non-null, error-free result for a
	 * record with no masking targets configured for its SObjectType.
	 */
	@IsTest
	private static void shouldApplyToSingleRecord()
	{
		System.runAs(getTestAdmin())
		{
			SObject record = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isNotNull(result, 'apply should return a result');
			Assert.isFalse(result.hadErrors, 'hadErrors should be false when no rules fire');
			Assert.areEqual(0, result.rulesMatched, 'No rules should have matched');
		}
	}

	/**
	 * @description Tests that calledFrom is persisted on the RecordMasker builder.
	 */
	@IsTest
	private static void shouldRecordCalledFromOnRecordMasker()
	{
		System.runAs(getTestAdmin())
		{
			SObject record = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

			UTIL_FrameworkMasker.RecordMasker masker = UTIL_FrameworkMasker.forRecord(record).calledFrom(SAMPLE_CALLER);

			Assert.areEqual(SAMPLE_CALLER, masker.callerClassName, 'calledFrom should be stored on the builder');
		}
	}

	/**
	 * @description Tests that BulkRecordMasker returns one result per input record.
	 */
	@IsTest
	private static void shouldReturnResultsForEveryRecord()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withCount(2).buildList();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(records).apply();

			Assert.areEqual(2, results.size(), 'Should return one result per input record');
			Assert.isFalse(results.get(0).hadErrors, 'First result should be clean when no rules fire');
			Assert.isFalse(results.get(1).hadErrors, 'Second result should be clean when no rules fire');
		}
	}

	/**
	 * @description Tests that BulkRecordMasker handles null gracefully.
	 */
	@IsTest
	private static void shouldHandleNullRecordsList()
	{
		System.runAs(getTestAdmin())
		{
			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(null).apply();

			Assert.isNotNull(results, 'Should return an empty list, not null, for null input');
			Assert.isTrue(results.isEmpty(), 'Should return empty list for null input');
		}
	}

	/**
	 * @description Tests that calledFrom is persisted on the BulkRecordMasker builder.
	 */
	@IsTest
	private static void shouldRecordCalledFromOnBulkRecordMasker()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.BulkRecordMasker masker = UTIL_FrameworkMasker.forRecords(new List<SObject>()).calledFrom(SAMPLE_CALLER);

			Assert.areEqual(SAMPLE_CALLER, masker.callerClassName, 'calledFrom should be stored on the builder');
		}
	}

	/**
	 * @description Tests that RecordMasker.apply masks a configured field in place and
	 * aggregates the match count on the returned result.
	 */
	@IsTest
	private static void shouldMaskConfiguredFieldOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'the secret is here')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X is here', record.Text__c, 'Field value should be masked in place on the record');
			Assert.areEqual(1, result.rulesMatched, 'Aggregate rulesMatched should reflect the single match');
		}
	}

	/**
	 * @description Tests that RecordMasker aggregates matches across multiple fields on a
	 * single record when several targets are configured.
	 */
	@IsTest
	private static void shouldAggregateMatchesAcrossFields()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'one', 'X', null, 'RuleOne', 10);
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_EXACT_MATCH, 'two', 'Y', null, 'RuleTwo', 20);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'value one')
					.withOverride(Foobar__c.TextArea__c, 'value two')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('value X', record.Text__c, 'Text__c should be masked');
			Assert.areEqual('value Y', record.TextArea__c, 'TextArea__c should be masked');
			Assert.areEqual(2, result.rulesMatched, 'Aggregate should count both field-level matches');
		}
	}

	/**
	 * @description Tests that RecordMasker skips fields that are null/unpopulated on the
	 * record: no attempt to mask, no error.
	 */
	@IsTest
	private static void shouldSkipUnpopulatedFieldsOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();
			record.Text__c = null;

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(0, result.rulesMatched, 'No rules should fire when the field is null');
			Assert.isFalse(result.hadErrors, 'Null-field skip is not a failure');
		}
	}

	/**
	 * @description Tests that BulkRecordMasker masks every record in place with a shared rule.
	 */
	@IsTest
	private static void shouldMaskRecordsInBulk()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'first secret')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'second secret')
					.withoutInsertion()
					.build();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();

			Assert.areEqual('first X', firstRecord.Text__c, 'First record should be masked');
			Assert.areEqual('second X', secondRecord.Text__c, 'Second record should be masked');
			Assert.areEqual(2, results.size(), 'One result per input record');
		}
	}

	/**
	 * @description Tests that a BlockDml rule failure during RecordMasker.apply propagates
	 * `MaskingBlockedException` out of the terminal, halting processing.
	 */
	@IsTest
	private static void shouldPropagateBlockDmlExceptionFromRecordMasker()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null, SEL_MaskingRule.FAILURE_BLOCK_DML);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'some value')
					.withoutInsertion()
					.build();

			try
			{
				UTIL_FrameworkMasker.forRecord(record).apply();
				Assert.fail('RecordMasker should propagate MaskingBlockedException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.MaskingBlockedException.class, 'Should throw MaskingBlockedException');
			}
		}
	}

	/**
	 * @description Tests that a BlockDml failure on the first record halts the bulk masker
	 * at once: later records should not be touched.
	 */
	@IsTest
	private static void shouldFastExitBulkMaskerOnBlockDmlFailure()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null, SEL_MaskingRule.FAILURE_BLOCK_DML);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'first')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'second')
					.withoutInsertion()
					.build();

			try
			{
				UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();
				Assert.fail('BulkRecordMasker should propagate MaskingBlockedException');
			}
			catch(UTIL_Exceptions.MaskingBlockedException error)
			{
				Assert.areEqual('first', firstRecord.Text__c, 'First record must not have been partially mutated');
				Assert.areEqual('second', secondRecord.Text__c, 'Second record must not have been processed');
			}
		}
	}

	/**
	 * @description Tests that forRecord(null).apply does not throw and returns an empty result.
	 */
	@IsTest
	private static void shouldHandleNullRecordArgument()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(null).apply();

			Assert.isNotNull(result, 'apply should return a result even for null input');
			Assert.areEqual(0, result.rulesMatched, 'No rules should match when there is no record');
			Assert.isFalse(result.hadErrors, 'Null record is not a failure');
		}
	}

	/**
	 * @description Tests that RecordMasker.apply aggregates rule-failure metadata (hadErrors
	 * and failedRuleDeveloperNames) from a LogAndContinue rule failure up to the record-level
	 * result.
	 */
	@IsTest
	private static void shouldAggregateRuleFailureOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'some value')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isTrue(result.hadErrors, 'Record-level result should surface field-level failures');
			Assert.areEqual(1, result.failedRuleDeveloperNames.size(), 'Failed rule name should bubble up');
			Assert.areEqual('TestRule', result.failedRuleDeveloperNames.get(0), 'Failed rule name should match');
		}
	}

	/**
	 * @description Tests that a MaskingTarget pointing at a field that does not exist on the
	 * SObjectType is skipped without notice. This protects against admin setup that is out of date.
	 */
	@IsTest
	private static void shouldSkipTargetReferencingMissingField()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('TestRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'x', 'y', 10)
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, 'NonExistentField__c', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'x here')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(0, result.rulesMatched, 'Target pointing at non-existent field should be a no-op');
			Assert.areEqual('x here', record.Text__c, 'Record should be untouched');
		}
	}

	/**
	 * @description Tests that a MaskingTarget whose Field__c is malformed (no object prefix /
	 * dot separator) is silently skipped rather than crashing.
	 */
	@IsTest
	private static void shouldSkipTargetWithMalformedFieldPath()
	{
		System.runAs(getTestAdmin())
		{
			String foobarName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);

			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('TestRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'x', 'y', 10)
					.withoutInsertion(true)
					.build();

			TST_Mock.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.IsActive__c, true)
					.withOverride(MaskingTarget__mdt.SObjectType__c, foobarName)
					.withOverride(MaskingTarget__mdt.Field__c, 'NoDotHere')
					.withOverride(MaskingTarget__mdt.Rule__c, rule)
					.build();

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'x here')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(0, result.rulesMatched, 'Malformed target Field__c should be a no-op');
			Assert.areEqual('x here', record.Text__c, 'Record should be untouched');
		}
	}

	/**
	 * @description Tests that RecordMasker respects the calledFrom caller when it goes through fields:
	 * rules limited to a caller only run when the caller matches.
	 */
	@IsTest
	private static void shouldHonourCallerScopeOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', 'API_SendEmail');

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'the secret here')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult wrongCaller = UTIL_FrameworkMasker.forRecord(record).calledFrom('API_Other').apply();

			Assert.areEqual('the secret here', record.Text__c, 'Scoped rule should not fire for non-matching caller');
			Assert.areEqual(0, wrongCaller.rulesMatched, 'No rules should have matched');

			UTIL_FrameworkMasker.MaskingResult rightCaller = UTIL_FrameworkMasker.forRecord(record).calledFrom('API_SendEmail').apply();

			Assert.areEqual('the X here', record.Text__c, 'Scoped rule should fire when caller matches');
			Assert.areEqual(1, rightCaller.rulesMatched, 'Caller-matching call should record the match');
		}
	}

	/**
	 * @description Tests that a Regex-mode MaskingTarget fires when mask() is called for its field.
	 */
	@IsTest
	private static void shouldApplyRegexRuleToField()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '\\d+', 'XXX', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('Code: 12345');

			Assert.areEqual('Code: XXX', result.maskedValue, 'Regex rule should replace the digits');
			Assert.areEqual(1, result.rulesMatched, 'One rule should have matched');
			Assert.areEqual(1, result.valuesRedacted, 'One value should be redacted');
			Assert.areEqual('TestRule', result.matchedRuleDeveloperNames.get(0), 'Matched rule name should be recorded');
		}
	}

	/**
	 * @description Tests that an ExactMatch-mode MaskingTarget replaces the exact literal.
	 */
	@IsTest
	private static void shouldApplyExactMatchRuleToField()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', '[REDACTED]', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('this secret is hidden');

			Assert.areEqual('this [REDACTED] is hidden', result.maskedValue, 'ExactMatch rule should replace the literal');
			Assert.areEqual(1, result.rulesMatched, 'One rule should have matched');
		}
	}

	/**
	 * @description Tests that a CreditCard-mode MaskingTarget redacts a Luhn-valid 16-digit
	 * card number embedded in free text. Exercises the framework dispatch into
	 * `UTIL_String.maskWithLuhnValidatedRegex`, proving a Luhn-passing match is treated the
	 * same way a plain Regex rule would treat its match.
	 */
	@IsTest
	private static void shouldMaskLuhnValidCardInCreditCardMode()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_CREDIT_CARD, '\\b(?:\\d[ -]*?){15,19}\\b', '[CARD]', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('customer card 4111111111111111 charged');

			Assert.areEqual('customer card [CARD] charged', result.maskedValue, 'Luhn-valid 16-digit card must be redacted in CreditCard mode');
			Assert.areEqual(1, result.rulesMatched, 'One rule should have matched');
		}
	}

	/**
	 * @description Tests that a CreditCard-mode MaskingTarget does NOT redact a 16-digit run
	 * that matches the regex but fails the Luhn checksum (e.g. a transaction ID). Catches the
	 * false-positive regression where a plain Regex mode would incorrectly over-redact.
	 */
	@IsTest
	private static void shouldNotMaskLuhnInvalidDigitRunInCreditCardMode()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_CREDIT_CARD, '\\b(?:\\d[ -]*?){15,19}\\b', '[CARD]', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('TID:1234567890123456 recorded');

			Assert.areEqual('TID:1234567890123456 recorded', result.maskedValue, 'Luhn-invalid 16-digit transaction ID must pass through in CreditCard mode');
			Assert.areEqual(0, result.rulesMatched, 'No rules should have matched when the Luhn gate fails');
		}
	}

	/**
	 * @description Tests that a Regex-mode rule with `MinInputLength__c` set is skipped when the
	 * field value is shorter than the configured threshold. Proves the short-circuit avoids
	 * compiling/executing the regex on values that cannot possibly match. Catches the regression
	 * where the length gate is ignored and the expensive regex fires on short framework fields.
	 */
	@IsTest
	private static void shouldSkipRegexRuleWhenValueShorterThanMinInputLength()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithMinInputLength(SEL_MaskingRule.MODE_REGEX, '\\d{15,19}', 'X', null, 15);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'short14chars12')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('short14chars12', record.Text__c, 'Value shorter than MinInputLength must bypass the rule without regex evaluation');
		}
	}

	/**
	 * @description Tests that a Regex-mode rule with `MinInputLength__c` set still applies when
	 * the field value meets or exceeds the threshold. Proves the short-circuit does not suppress
	 * rules whose regex might legitimately match.
	 */
	@IsTest
	private static void shouldApplyRegexRuleWhenValueAtLeastMinInputLength()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithMinInputLength(SEL_MaskingRule.MODE_REGEX, '\\d{15,19}', 'X', null, 15);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'long123456789012345string')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isTrue(record.Text__c.contains('X'), 'Value at or above MinInputLength must have the rule applied');
		}
	}

	/**
	 * @description Tests that a rule scoped to a CallerClass fires only when calledFrom matches.
	 */
	@IsTest
	private static void shouldHonourCallerClassScope()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', 'API_SendEmail');

			UTIL_FrameworkMasker.MaskingResult wrongCaller = UTIL_FrameworkMasker.forField(Foobar__c.Text__c)
					.calledFrom('API_Other')
					.mask('secret value');

			Assert.areEqual('secret value', wrongCaller.maskedValue, 'Rule should NOT fire for a different caller');
			Assert.areEqual(0, wrongCaller.rulesMatched, 'No rules should match when caller scope mismatches');

			UTIL_FrameworkMasker.MaskingResult rightCaller = UTIL_FrameworkMasker.forField(Foobar__c.Text__c)
					.calledFrom('API_SendEmail')
					.mask('secret value');

			Assert.areEqual('X value', rightCaller.maskedValue, 'Rule should fire when caller scope matches');
		}
	}

	/**
	 * @description Tests that a rule with blank CallerClass fires regardless of the caller.
	 */
	@IsTest
	private static void shouldFireUnscopedRuleForAnyCaller()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c)
					.calledFrom('AnyCaller')
					.mask('secret value');

			Assert.areEqual('X value', result.maskedValue, 'Unscoped rule should fire regardless of caller');
		}
	}

	/**
	 * @description Tests that rules targeting a different field do not fire.
	 */
	@IsTest
	private static void shouldSkipRulesForOtherFields()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('secret value');

			Assert.areEqual('secret value', result.maskedValue, 'Rule targeting TextArea__c should NOT fire on Text__c');
		}
	}

	/**
	 * @description Tests that a rule with an invalid regex is caught, flagged, and that
	 * LogAndContinue (the default FailureAction when unset) leaves the value unchanged and
	 * adds the rule to the per-transaction invalidation set.
	 */
	@IsTest
	private static void shouldCaptureRegexFailure()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('some value');

			Assert.isTrue(result.hadErrors, 'hadErrors should be true when a rule throws');
			Assert.areEqual(1, result.failedRuleDeveloperNames.size(), 'One failed rule should be recorded');
			Assert.areEqual('some value', result.maskedValue, 'LogAndContinue default keeps the value unchanged');
			Assert.isTrue(UTIL_FrameworkMasker.invalidatedRuleDeveloperNames.contains('TestRule'), 'Failed rule should be added to the invalidation set');
		}
	}

	/**
	 * @description Tests that a rule configured with `FailureAction__c = WriteFailureMarker`
	 * substitutes the FAILURE_MARKER sentinel instead of leaving the raw value in place.
	 */
	@IsTest
	private static void shouldWriteFailureMarkerWhenConfigured()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('some value');

			Assert.isTrue(result.hadErrors, 'hadErrors should be true when a rule throws');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'WriteFailureMarker should substitute the sentinel value');
		}
	}

	/**
	 * @description Tests that a rule configured with `FailureAction__c = BlockDml` throws
	 * `MaskingBlockedException` on first failure so the surrounding adapter aborts the DML.
	 */
	@IsTest
	private static void shouldBlockDmlWhenConfigured()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null, SEL_MaskingRule.FAILURE_BLOCK_DML);

			try
			{
				UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('some value');
				Assert.fail('BlockDml rule failure should have thrown MaskingBlockedException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.MaskingBlockedException.class, 'Should throw MaskingBlockedException');
			}
		}
	}

	/**
	 * @description Tests that a rule that has already failed is skipped on subsequent calls
	 * in the same transaction. This avoids wasted work for each record in bulk triggers, and stops
	 * each record from entering the logging loop again.
	 */
	@IsTest
	private static void shouldSkipInvalidatedRuleOnSubsequentCalls()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null);

			UTIL_FrameworkMasker.MaskingResult firstCall = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('first');
			UTIL_FrameworkMasker.MaskingResult secondCall = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('second');

			Assert.isTrue(firstCall.hadErrors, 'First call should record the failure');
			Assert.isFalse(secondCall.hadErrors, 'Second call should skip the invalidated rule entirely');
			Assert.areEqual(0, secondCall.failedRuleDeveloperNames.size(), 'Second call should not re-record the failed rule');
			Assert.areEqual('second', secondCall.maskedValue, 'Second call should pass through unchanged');
		}
	}

	/**
	 * @description Tests that a masking rule failing on a LogEntry__c target does not emit a
	 * warning log, which closes the logging loop across transactions from end to end.
	 */
	@IsTest
	private static void shouldSkipWarnLoggingWhenLogEntryTargetRuleFails()
	{
		System.runAs(getTestAdmin())
		{
			String logEntryObjectName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType);
			String fieldApiName = UTIL_SObjectDescribe.getCachedFieldName(LogEntry__c.Message__c);

			MaskingRule__mdt rule = (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
					.withOverride(MaskingRule__mdt.DeveloperName, 'LogEntryRule')
					.withOverride(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_REGEX)
					.withOverride(MaskingRule__mdt.Pattern__c, '([bad')
					.withOverride(MaskingRule__mdt.Replacement__c, 'X')
					.withOverride(MaskingRule__mdt.IsActive__c, true)
					.withOverride(MaskingRule__mdt.Order__c, 10)
					.withoutInsertion(true)
					.build();

			TST_Mock.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.IsActive__c, true)
					.withOverride(MaskingTarget__mdt.SObjectType__c, logEntryObjectName)
					.withOverride(MaskingTarget__mdt.Field__c, logEntryObjectName + UTIL_String.DOT + fieldApiName)
					.withOverride(MaskingTarget__mdt.Rule__c, rule)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(LogEntry__c.Message__c).mask('some value');

			Assert.isTrue(result.hadErrors, 'hadErrors should still be set for LogEntry target failures');
			Assert.isTrue(UTIL_FrameworkMasker.invalidatedRuleDeveloperNames.contains('LogEntryRule'), 'Rule invalidation still fires for LogEntry targets');
		}
	}

	/**
	 * @description Tests that isLogEntryTarget returns true for the LogEntry__c object and
	 * false for other objects. This is the check that stops warning logs on masking failures against
	 * LogEntry targets, which breaks the logging loop across transactions.
	 */
	@IsTest
	private static void shouldIdentifyLogEntryTargetByObjectName()
	{
		System.runAs(getTestAdmin())
		{
			MaskingTarget__mdt logEntryTarget = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType))
					.withoutInsertion(true)
					.build();

			MaskingTarget__mdt logEntryEventTarget = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType))
					.withoutInsertion(true)
					.build();

			MaskingTarget__mdt foobarTarget = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType))
					.withoutInsertion(true)
					.build();

			Assert.isTrue(UTIL_FrameworkMasker.isLogEntryTarget(logEntryTarget), 'LogEntry__c target should be identified');
			Assert.isTrue(UTIL_FrameworkMasker.isLogEntryTarget(logEntryEventTarget), 'LogEntryEvent__e target should be identified');
			Assert.isFalse(UTIL_FrameworkMasker.isLogEntryTarget(foobarTarget), 'Non-log target should not be identified');
		}
	}

	/**
	 * @description A masking rule misconfigured on the log event must not cost the entry being masked its
	 * fingerprint. The masker's warnings run inside the loop that builds an entry's events, while that entry's
	 * fingerprint is still open on the engine, and the warning's own emit closes it, so every message after the
	 * first would lose the fingerprint it was written with. The warnings are skipped on the log objects instead.
	 */
	@IsTest
	private static void shouldKeepTheFingerprintOfAnEntryAMisconfiguredLogRuleIsMasking()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;
			registerMisconfiguredRulesOnLogEntryEvents();

			Test.startTest();
			LOG_Builder.build()
					.warn(new List<String> {UTIL_Random.randomName(), UTIL_Random.randomName()})
					.withFingerprint(MASKED_ENTRY_FINGERPRINT)
					.emitAt(MASKED_ENTRY_CLASS_METHOD);
			Test.stopTest();

			List<LogEntry__c> rows = new SEL_LogEntry().findAllByMethod(MASKED_ENTRY_CLASS_METHOD);
			Assert.isFalse(rows.isEmpty(), 'The entry should be on file');
			for(LogEntry__c row : rows)
			{
				Assert.isTrue(row.Fingerprint__c?.contains(MASKED_ENTRY_FINGERPRINT) == true,
						'Every message of the entry keeps the fingerprint it was written with, and this one carries ' + row.Fingerprint__c);
			}
			Assert.isTrue(new SEL_LogEntry().findAllByMethod(UNKNOWN_TYPE_WARNING_LOCATION).isEmpty(), 'The masker says nothing about an unknown field type on a log entry');
			Assert.isTrue(new SEL_LogEntry().findAllByMethod(MISMATCHED_TYPE_WARNING_LOCATION).isEmpty(), 'The masker says nothing about a field-type mismatch on a log entry');
		}
	}

	/**
	 * @description Registers two misconfigured masking targets on the log event: one wildcard target whose rule
	 * names a field type that does not exist, and one wired to a field whose type its rule excludes. Each is a
	 * warning site the masker would otherwise reach from inside the event loop.
	 */
	private static void registerMisconfiguredRulesOnLogEntryEvents()
	{
		String logEntryEventName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType);

		MaskingRule__mdt unknownTypeRule = (MaskingRule__mdt)mockRuleBuilder(UNKNOWN_TYPE_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, UNMATCHED_TOKEN, 'X', 10)
				.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, UNKNOWN_FIELD_TYPE)
				.withoutInsertion(true)
				.build();
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, logEntryEventName)
				.withOverride(MaskingTarget__mdt.Field__c, null)
				.withOverride(MaskingTarget__mdt.Rule__c, unknownTypeRule)
				.build();

		MaskingRule__mdt mismatchedTypeRule = (MaskingRule__mdt)mockRuleBuilder(MISMATCHED_TYPE_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, UNMATCHED_TOKEN, 'X', 20)
				.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, String.valueOf(DisplayType.EMAIL))
				.withoutInsertion(true)
				.build();
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, logEntryEventName)
				.withOverride(MaskingTarget__mdt.Field__c, logEntryEventName + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(LogEntryEvent__e.Message__c))
				.withOverride(MaskingTarget__mdt.Rule__c, mismatchedTypeRule)
				.build();
	}

	/**
	 * @description Tests that a rule with a mode value not recognised by the dispatcher (e.g. a
	 * future picklist value that ships before the Apex update catches up) is a safe no-op.
	 */
	@IsTest
	private static void shouldSkipUnrecognisedModeGracefully()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText('SomeFutureMode', 'foo', 'bar', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('unchanged');

			Assert.areEqual('unchanged', result.maskedValue, 'Unrecognised mode should leave the value alone');
			Assert.areEqual(0, result.rulesMatched, 'Unrecognised mode should not count as a match');
		}
	}

	/**
	 * @description Tests that a JsonKey-mode MaskingTarget fires through UTIL_FrameworkMasker.
	 */
	@IsTest
	private static void shouldApplyJsonKeyRuleToField()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '^(password|token)$', '***', null);

			String input = '{"user":"alice","password":"hunter2","token":"abc"}';
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(input);

			Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result.maskedValue);
			Assert.areEqual('***', parsed.get('password'), 'JsonKey rule should redact password');
			Assert.areEqual('***', parsed.get('token'), 'JsonKey rule should redact token');
			Assert.areEqual('alice', parsed.get('user'), 'Non-matching key should remain');
			Assert.areEqual(1, result.rulesMatched, 'One rule should have matched');
		}
	}

	/**
	 * @description Tests that a masked value which grows past the field's length limit is
	 * truncated so the subsequent DML does not throw STRING_TOO_LONG.
	 */
	@IsTest
	private static void shouldTruncateMaskedValueToFieldLength()
	{
		System.runAs(getTestAdmin())
		{
			String longReplacement = 'X'.repeat(300);
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'a', longReplacement, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('a');

			Assert.areEqual(255, result.maskedValue.length(), 'Masked value should be truncated to field length (Text__c = 255)');
			Assert.areEqual(255, result.maskedLength, 'maskedLength metadata should reflect the truncated length');
		}
	}

	/**
	 * @description Tests that mask returns unchanged when no targets are configured for the field.
	 */
	@IsTest
	private static void shouldReturnUnchangedWhenNoTargets()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('unchanged');

			Assert.areEqual('unchanged', result.maskedValue, 'Value should pass through when no targets configured');
			Assert.areEqual(0, result.rulesMatched, 'No rules should match');
		}
	}

	/**
	 * @description Tests that two JsonKey rules on the same field apply in a single batched
	 * parse+serialize pass and both record a match.
	 */
	@IsTest
	private static void shouldBatchMultipleJsonKeyRules()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '^password$', 'P', null, 'PasswordRule', 10);
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '^token$', 'T', null, 'TokenRule', 20);

			String input = '{"password":"hunter2","token":"abc","user":"alice"}';
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(input);

			Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result.maskedValue);
			Assert.areEqual('P', parsed.get('password'), 'Password rule should fire');
			Assert.areEqual('T', parsed.get('token'), 'Token rule should fire');
			Assert.areEqual(2, result.rulesMatched, 'Both JsonKey rules should be recorded as matched');
		}
	}

	/**
	 * @description Tests that a JsonKey-mode rule applied to a record whose payload matches no
	 * keys completes without re-serializing the deserialized tree. A subsequent change removes
	 * the per-rule `JSON.serialize` before/after comparison; the CPU-budget assertion guards
	 * against a future regression reintroducing that double-serialize.
	 */
	@IsTest
	private static void shouldNotReserializeJsonTreeWhenNoJsonKeyRuleMatches()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_JSON_KEY, '^password$', '***', null);

			String payload = '{"user":"alice","role":"admin"}';
			Foobar__c record = new Foobar__c(Text__c = payload);

			Test.startTest();
			Integer cpuBefore = UTIL_Limits.cpuTime().used();
			UTIL_FrameworkMasker.forRecord(record).apply();
			Integer cpuAfter = UTIL_Limits.cpuTime().used();
			Test.stopTest();

			Assert.areEqual(payload, record.Text__c, 'Non-matching tree must pass through unchanged');
			Assert.isTrue(cpuAfter - cpuBefore < 200, 'Non-matching JsonKey mask must not serialize the tree (CPU budget < 200ms, observed=' + (cpuAfter - cpuBefore) + ')');
		}
	}

	/**
	 * @description Tests that a malformed JSON payload falls back to per-rule processing when
	 * the batched parse fails.
	 */
	@IsTest
	private static void shouldFallBackWhenJsonKeyBatchParseFails()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '^password$', '***', null);

			String malformedJson = '{"password": "hunter2", broken';
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(malformedJson);

			Assert.isTrue(result.maskedValue.contains('"password": "***"'), 'Fallback should still redact the password');
			Assert.isFalse(result.maskedValue.contains('hunter2'), 'Original secret must not remain');
		}
	}

	/**
	 * @description Tests that duplicate target configurations are deduped so the same rule only
	 * fires (and appears in the audit list) once.
	 */
	@IsTest
	private static void shouldDeduplicateIdenticalTargets()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('secret value');

			Assert.areEqual('X value', result.maskedValue, 'Rule should still fire');
			Assert.areEqual(1, result.rulesMatched, 'Duplicate target should be removed: only one match recorded');
		}
	}

	/**
	 * @description Tests that targets are applied in parent-rule Order__c ascending sequence.
	 * The earlier rule (Order__c = 10) runs first and replaces 'foo' with 'FIRST'; the later
	 * rule (Order__c = 20) then has nothing to match, proving execution order.
	 */
	@IsTest
	private static void shouldApplyTargetsInRuleOrderSequence()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'foo', 'SECOND', null, 'LaterRule', 20);
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'foo', 'FIRST', null, 'EarlierRule', 10);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('foo here');

			Assert.areEqual('EarlierRule', result.matchedRuleDeveloperNames.get(0), 'Rule with Order__c = 10 should execute first');
			Assert.areEqual(1, result.rulesMatched, 'Only the earlier rule should have matched: the later rule saw text that was already replaced');
			Assert.areEqual('FIRST here', result.maskedValue, 'Earlier rule wins; later rule cannot match because foo is already gone');
		}
	}

	/**
	 * @description Tests that a JsonKey rule with an invalid regex throws and is captured as a
	 * rule failure inside the batched JsonKey path. Works with the Regex-mode failure test.
	 */
	@IsTest
	private static void shouldCaptureJsonKeyRuleFailure()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '([bad', '***', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask('{"password":"hunter2"}');

			Assert.isTrue(result.hadErrors, 'hadErrors should be true when a JsonKey rule throws');
			Assert.areEqual(1, result.failedRuleDeveloperNames.size(), 'One failed JsonKey rule should be recorded');
			Assert.areEqual('TestRule', result.failedRuleDeveloperNames.get(0), 'The failing rule name should be recorded');
			Assert.areEqual(0, result.rulesMatched, 'No rules should count as matched when the rule threw');
		}
	}

	/**
	 * @description Tests UTIL_String.applyJsonKeyRuleToTree with a null input. Covers the null check
	 * that UTIL_FrameworkMasker relies on.
	 */
	@IsTest
	private static void applyJsonKeyRuleToTreeShouldHandleNull()
	{
		System.runAs(getTestAdmin())
		{
			Object result = UTIL_String.applyJsonKeyRuleToTree(null, '^password$', '***', false);

			Assert.isNull(result, 'Null tree should return null');
		}
	}

	/**
	 * @description Tests that `resolveQualifiedFieldName` assembles the qualified field path from
	 * the `SObjectType__r.QualifiedApiName` + `Field__r.QualifiedApiName` relationship fields
	 * when both are populated. This is the shape real deployed CMDT records expose via the
	 * selector. Mocks normally put the already-qualified string in `Field__c`, so this test
	 * covers the metadata-relationship branch explicitly.
	 */
	@IsTest
	private static void shouldResolveQualifiedFieldNameFromRelationshipFields()
	{
		System.runAs(getTestAdmin())
		{
			EntityDefinition entityDefinition = (EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
					.withOverride(EntityDefinition.QualifiedApiName, 'Foobar__c')
					.withoutInsertion()
					.build();

			FieldDefinition fieldDefinition = (FieldDefinition)TST_Builder.of(FieldDefinition.SObjectType)
					.withOverride(FieldDefinition.QualifiedApiName, 'Text__c')
					.withoutInsertion()
					.build();

			MaskingTarget__mdt target = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, entityDefinition)
					.withOverride(MaskingTarget__mdt.Field__c, fieldDefinition)
					.withoutInsertion(true)
					.build();

			String resolved = UTIL_FrameworkMasker.resolveQualifiedFieldName(target);

			Assert.areEqual('Foobar__c.Text__c', resolved, 'Resolved name should be assembled from relationship fields');
		}
	}

	/**
	 * @description Tests that a target naming a field wins over a wildcard (blank Field__c) target
	 * with the same rule and caller. This is the rule in `selectApplicableTargets` that a named field
	 * beats a wildcard. The wildcard target should be left out of the applicable targets, so only the
	 * target naming the field runs.
	 */
	@IsTest
	private static void shouldShadowWildcardTargetWithSpecificTarget()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('SharedRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'foo', 'BAR', 10)
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), null);
			registerMockTarget(rule, null, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('foo here');

			Assert.areEqual('BAR here', result.maskedValue, 'Specific-field target should apply');
			Assert.areEqual(1, result.rulesMatched, 'The target naming the field should win over the wildcard, so the rule runs only once');
		}
	}

	/**
	 * @description Tests that a JsonKey rule invalidated by a failure on an earlier record is
	 * skipped for later records in the same bulk operation. Exercises the invalidation filter
	 * inside `applyJsonKeyBatchStatic`. The filter skips the rule's work on records
	 * processed against a cached BatchPlan that still references the now-invalid target.
	 */
	@IsTest
	private static void shouldSkipInvalidatedJsonKeyRuleOnLaterRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '([bad', '***', null);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.TextArea__c, '{"password":"hunter2"}')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.TextArea__c, '{"password":"other"}')
					.withoutInsertion()
					.build();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();

			Assert.isTrue(results.get(0).hadErrors, 'First record should record the JsonKey failure');
			Assert.isFalse(results.get(1).hadErrors, 'Second record should skip the already-invalidated JsonKey rule');
			Assert.isTrue(UTIL_FrameworkMasker.invalidatedRuleDeveloperNames.contains('TestRule'), 'Rule should be in the invalidation set');
		}
	}

	/**
	 * @description Tests that a Regex/ExactMatch rule invalidated by a failure on an earlier
	 * record is skipped for later records in the same bulk operation. Exercises the
	 * invalidation filter inside `applySingleTargetStatic`. The filter skips the rule's
	 * work on records processed against a cached BatchPlan that still references the now-invalid
	 * target.
	 */
	@IsTest
	private static void shouldSkipInvalidatedSingleTargetRuleOnLaterRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'first')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'second')
					.withoutInsertion()
					.build();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();

			Assert.isTrue(results.get(0).hadErrors, 'First record should record the Regex failure');
			Assert.isFalse(results.get(1).hadErrors, 'Second record should skip the already-invalidated Regex rule');
			Assert.isTrue(UTIL_FrameworkMasker.invalidatedRuleDeveloperNames.contains('TestRule'), 'Rule should be in the invalidation set');
		}
	}

	/**
	 * @description Tests that a wildcard MaskingTarget (blank `Field__c`) applied through
	 * `RecordMasker.apply` expands to every updateable text-shaped field on the SObjectType via
	 * `buildBatchPlan` + `getUpdateableTextFields`. The same rule fires on `Text__c`,
	 * `TextArea__c`, `Email__c`, and every other text-shaped field that holds matching input.
	 */
	@IsTest
	private static void shouldApplyWildcardTargetViaRecordMasker()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('WildcardRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', 10)
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, null, null);

			Foobar__c record = buildFoobarWithTextAndTextArea('the secret one', 'another secret');

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X one', record.Text__c, 'Wildcard rule should fire on Text__c');
			Assert.areEqual('another X', record.TextArea__c, 'Wildcard rule should fire on TextArea__c');
			Assert.areEqual(2, result.rulesMatched, 'Wildcard rule should match on every populated text field');
		}
	}

	/**
	 * @description Tests that `getUpdateableTextFields` returns a non-empty list for Foobar__c. Runs
	 * the code that finds and filters writable text fields directly, so the cache and the field-type
	 * filter are both covered on their own, apart from the RecordMasker path.
	 */
	@IsTest
	private static void shouldEnumerateUpdateableTextFields()
	{
		System.runAs(getTestAdmin())
		{
			List<SObjectField> first = UTIL_FrameworkMasker.getUpdateableTextFields(Foobar__c.SObjectType);
			List<SObjectField> second = UTIL_FrameworkMasker.getUpdateableTextFields(Foobar__c.SObjectType);

			Assert.isFalse(first.isEmpty(), 'Foobar__c should expose at least one updateable text-shaped field');
			Assert.areEqual(first.size(), second.size(), 'Cached lookup should return the same list on repeated calls');
		}
	}

	/**
	 * @description Tests that a wildcard target never expands to a field that identifies the record:
	 * a unique key or an external id. Masking rewrites the value it matches; on a key that means the
	 * key is destroyed and, on a unique index, the NEXT record whose key masks to the same constant
	 * fails to insert. A chain correlation id built from a long numeric order number is exactly the
	 * shape a payment-card rule matches, and `AsyncChainExecution__c.CorrelationId__c` is unique.
	 */
	@IsTest
	private static void shouldNotExpandWildcardToUniqueOrExternalIdFields()
	{
		System.runAs(getTestAdmin())
		{
			Set<SObjectField> chainFields = new Set<SObjectField>(UTIL_FrameworkMasker.getUpdateableTextFields(AsyncChainExecution__c.SObjectType));
			Set<SObjectField> foobarFields = new Set<SObjectField>(UTIL_FrameworkMasker.getUpdateableTextFields(Foobar__c.SObjectType));

			Assert.isFalse(chainFields.contains(AsyncChainExecution__c.CorrelationId__c), 'A unique external-id key must never be a wildcard masking target');
			Assert.isFalse(chainFields.contains(AsyncChainExecution__c.ActiveDeduplicationKey__c), 'The unique deduplication key must never be a wildcard masking target');
			Assert.isTrue(chainFields.contains(AsyncChainExecution__c.ErrorMessage__c), 'Ordinary text fields on the same object still expand');
			Assert.isFalse(foobarFields.contains(Foobar__c.ExternalId__c), 'An external id that is not unique is still an identifier and must not be masked by a wildcard');
			Assert.isTrue(foobarFields.contains(Foobar__c.Text__c), 'Ordinary text fields on Foobar__c still expand');
		}
	}

	/**
	 * @description Tests the check for identifier fields, which every wildcard decision uses. It
	 * reads the field's describe settings and handles a field that cannot be found.
	 */
	@IsTest
	private static void shouldReportIdentifierFieldsFromTheirDescribeFacets()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isTrue(UTIL_FrameworkMasker.isIdentifierField(Foobar__c.ExternalId__c), 'An external id identifies its record');
			Assert.isFalse(UTIL_FrameworkMasker.isIdentifierField(Foobar__c.Text__c), 'An ordinary text field does not');
			Assert.isFalse(UTIL_FrameworkMasker.isIdentifierField((SObjectField)null), 'An unresolved field is not an identifier');
		}
	}

	/**
	 * @description Tests that a wildcard target never fires on an identifier field through `forField`
	 * either, which is the preview and sample path the advisor uses. Without this the preview would show a masking
	 * the record path (whose wildcard expansion skips identifier fields) never performs.
	 */
	@IsTest
	private static void shouldNotFireWildcardTargetOnIdentifierFieldThroughForField()
	{
		System.runAs(getTestAdmin())
		{
			mockTarget(null, SEL_MaskingRule.MODE_REGEX, '\\d+', 'XXX', null, 'TestRule', 10, null);

			UTIL_FrameworkMasker.MaskingResult identifierResult = UTIL_FrameworkMasker.forField(Foobar__c.ExternalId__c).mask('order 4111111111111111');
			UTIL_FrameworkMasker.MaskingResult textResult = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('order 4111111111111111');

			Assert.areEqual('order 4111111111111111', identifierResult.maskedValue, 'A wildcard must not rewrite an identifier field, even in preview');
			Assert.areEqual(0, identifierResult.rulesMatched, 'No rule should report a match on the identifier field');
			Assert.areEqual('order XXX', textResult.maskedValue, 'The same wildcard still fires on an ordinary text field');
		}
	}

	/**
	 * @description Tests that a target naming an identifier field explicitly is still applied: it is
	 * the administrator's deliberate choice. Only the wildcard skips identifier fields.
	 */
	@IsTest
	private static void shouldHonourExplicitTargetOnIdentifierField()
	{
		System.runAs(getTestAdmin())
		{
			mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.ExternalId__c), SEL_MaskingRule.MODE_REGEX, '\\d+', 'XXX', null, 'TestRule', 10, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.ExternalId__c).mask('order 12345');

			Assert.areEqual('order XXX', result.maskedValue, 'An explicit target on an identifier field is the administrator\'s deliberate choice and fires');
			Assert.areEqual(1, result.rulesMatched, 'The explicit rule should report its match');
		}
	}

	/**
	 * @description Tests that a wildcard target never covers the chain engine's run key. Every process running a
	 * chain run holds a copy of the key and compares it with the stored one. The key is random, and about once in
	 * several thousand keys its digit groups look like a payment card. Masking would then rewrite only the stored
	 * copy, and every process of that run would stop as out of date, leaving the run Running with no error
	 * anywhere.
	 */
	@IsTest
	private static void shouldNotExpandWildcardToTheChainRunKey()
	{
		System.runAs(getTestAdmin())
		{
			Set<SObjectField> chainFields = new Set<SObjectField>(UTIL_FrameworkMasker.getUpdateableTextFields(AsyncChainExecution__c.SObjectType));

			Assert.isFalse(chainFields.contains(AsyncChainExecution__c.RunKey__c), 'The run key is a fence token the engine compares for equality; no wildcard may rewrite it');
			Assert.isFalse(chainFields.contains(AsyncChainExecution__c.CurrentJobId__c), 'The job id is what the watchdog reads for liveness; no wildcard may rewrite it');
			Assert.isTrue(chainFields.contains(AsyncChainExecution__c.ErrorMessage__c), 'Ordinary text fields on the chain object still expand');
		}
	}

	/**
	 * @description Tests the record path end to end: a wildcard card rule applied to a chain run whose run key reads
	 * as a card number leaves the key exactly as minted while redacting the same digits in an ordinary text field of
	 * the same record.
	 */
	@IsTest
	private static void shouldLeaveTheChainRunKeyAsMintedUnderAWildcardCardRule()
	{
		System.runAs(getTestAdmin())
		{
			registerMockTargetOn(AsyncChainExecution__c.SObjectType, mockCardRule(), null, null);
			AsyncChainExecution__c run = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.RunKey__c, CARD_SHAPED_RUN_KEY)
					.withOverride(AsyncChainExecution__c.ErrorMessage__c, 'card ' + CARD_SHAPED_RUN_KEY.substringAfterLast('4768-'))
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.forRecord(run).apply();

			Assert.areEqual(CARD_SHAPED_RUN_KEY, run.RunKey__c, 'The run key must leave the masker exactly as minted');
			Assert.areEqual('card ' + CARD_REPLACEMENT, run.ErrorMessage__c, 'The same digits in an ordinary text field are redacted');
		}
	}

	/**
	 * @description Tests the preview path: a wildcard never fires on the run key through `forField` either, so the
	 * advisor's preview never claims a masking the record path refuses.
	 */
	@IsTest
	private static void shouldNotFireWildcardTargetOnTheChainRunKeyThroughForField()
	{
		System.runAs(getTestAdmin())
		{
			registerMockTargetOn(AsyncChainExecution__c.SObjectType, mockCardRule(), null, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(AsyncChainExecution__c.RunKey__c).mask(CARD_SHAPED_RUN_KEY);

			Assert.areEqual(CARD_SHAPED_RUN_KEY, result.maskedValue, 'A wildcard must not rewrite the run key, even in preview');
			Assert.areEqual(0, result.rulesMatched, 'No rule should report a match on the run key');
		}
	}

	/**
	 * @description Tests that a target naming the run key explicitly is still honoured, as for an identifier field:
	 * the administrator's deliberate choice; only the wildcard steps around the fence token.
	 */
	@IsTest
	private static void shouldHonourExplicitTargetOnTheChainRunKey()
	{
		System.runAs(getTestAdmin())
		{
			registerMockTargetOn(AsyncChainExecution__c.SObjectType, mockCardRule(), UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.RunKey__c), null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(AsyncChainExecution__c.RunKey__c).mask(CARD_SHAPED_RUN_KEY);

			Assert.areEqual('fb1f69f6-6768-4768-' + CARD_REPLACEMENT, result.maskedValue, 'An explicit target on the run key is the administrator\'s deliberate choice and fires');
			Assert.areEqual(1, result.rulesMatched, 'The explicit rule should report its match');
		}
	}

	/**
	 * @description Tests that `getUpdateableTextFields` also works on platform events, using
	 * `isCreateable()` instead of `isUpdateable()` because every platform event field reports
	 * `isUpdateable() == false`.
	 */
	@IsTest
	private static void shouldEnumerateCreateableTextFieldsOnPlatformEvent()
	{
		System.runAs(getTestAdmin())
		{
			List<SObjectField> fields = UTIL_FrameworkMasker.getUpdateableTextFields(LogEntryEvent__e.SObjectType);

			Assert.isFalse(fields.isEmpty(), 'Platform event should expose at least one createable text-shaped field');
		}
	}

	/**
	 * @description Tests that `RecordMasker.apply` skips fields whose value is an empty string
	 * (not null): the check for a filled but empty value inside `applyFieldPlanToRecord`.
	 */
	@IsTest
	private static void shouldSkipEmptyStringFieldValueOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, UTIL_String.EMPTY)
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(0, result.rulesMatched, 'No rules should fire when the field is an empty string');
			Assert.isFalse(result.hadErrors, 'Empty-string field skip is not a failure');
			Assert.areEqual(UTIL_String.EMPTY, record.Text__c, 'Record value should remain empty');
		}
	}

	/**
	 * @description Tests that a rule with `ApplicableFieldTypes__c` populated is filtered out
	 * of the batch plan for fields whose Apex `DisplayType` is excluded: no cost for each record,
	 * no regex run, no changed value. Card-masking rules can then limit themselves to
	 * `STRING;TEXTAREA;ENCRYPTEDSTRING`, which removes URL, Email and Phone fields from the loop over
	 * records entirely.
	 */
	@IsTest
	private static void shouldSkipRuleOnUrlFieldWhenExcludedByApplicableFieldTypes()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(
							SEL_MaskingRule.MODE_REGEX,
							'\\d{16}',
							'X',
							'TestCardExcludeUrl',
							'STRING;TEXTAREA'
					);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.URL__c, 'https://example.com?acct=4111111111111111')
					.withOverride(Foobar__c.Text__c, 'customer charged 4111111111111111 today')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isTrue(record.URL__c.contains('4111111111111111'), 'Url-typed field must be skipped when rule excludes URL via ApplicableFieldTypes__c');
			Assert.isTrue(record.Text__c.contains('X'), 'Text-typed field must still be scanned when rule includes STRING/TEXTAREA');
		}
	}

	/**
	 * @description Tests that when a `MaskingTarget__mdt` explicitly wires a rule to a specific
	 * `Field__c` whose DisplayType is excluded by the rule's `ApplicableFieldTypes__c`, the
	 * framework emits a one-time warning log to surface the misconfiguration. Without this
	 * signal, the admin's explicit wiring would be silently overridden by the rule-level
	 * filter: the rule would not run, but nothing in the log stream would explain why.
	 */
	@IsTest
	private static void shouldWarnOnceWhenSpecificFieldTargetDroppedByTypeFilter()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('TestSpecificFieldMismatch', SEL_MaskingRule.MODE_REGEX, '\\d{16}', 'X', 10)
					.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, 'STRING;TEXTAREA')
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.URL__c), null);

			UTIL_FrameworkMasker.warnedSpecificFieldTypeMismatches.clear();

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.URL__c, 'https://example.com?acct=4111111111111111')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isTrue(record.URL__c.contains('4111111111111111'), 'A target naming the field must not override the rule-level type filter: the rule should not run');
			Assert.areEqual(1, UTIL_FrameworkMasker.warnedSpecificFieldTypeMismatches.size(), 'Framework must warn once when explicit wiring is dropped by the type filter');
			String expectedWarnKey = 'TestSpecificFieldMismatch|' + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.URL__c);
			Assert.isTrue
					(
							UTIL_FrameworkMasker.warnedSpecificFieldTypeMismatches.contains(expectedWarnKey),
							'Warning key must identify rule + field so admins can locate the misconfigured target (expected ' + expectedWarnKey + ')'
					);

			UTIL_FrameworkMasker.cachedBatchPlans.clear();
			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(1, UTIL_FrameworkMasker.warnedSpecificFieldTypeMismatches.size(),
					'Warning must be written exactly once per rule and field pair per transaction: '
					+ 'clearing cachedBatchPlans forces the second apply to rebuild and re-enter '
					+ 'filterTargetsByFieldType, the contains-guard must suppress the duplicate warning');
		}
	}

	/**
	 * @description Tests that a rule with a blank `ApplicableFieldTypes__c` CSV applies to every
	 * text field, which is the original behaviour before field-type filters existed. Guards against a regression where
	 * an overly aggressive filter treats an unpopulated CSV as "no field types" instead of "all".
	 */
	@IsTest
	private static void shouldApplyRuleToAllTextFieldsWhenApplicableFieldTypesBlank()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(
							SEL_MaskingRule.MODE_EXACT_MATCH,
							'secret',
							'X',
							'TestBlankFilter',
							null
					);

			Foobar__c record = buildFoobarWithTextAndTextArea('the secret one', 'another secret');

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X one', record.Text__c, 'Blank ApplicableFieldTypes__c should still match STRING fields');
			Assert.areEqual('another X', record.TextArea__c, 'Blank ApplicableFieldTypes__c should still match TEXTAREA fields');
		}
	}

	/**
	 * @description Tests that the `ApplicableFieldTypes__c` CSV matches case-insensitively and
	 * trims spaces around entries: admins who set up CMDT through the UI may type
	 * ` string ; textarea ` and expect it to work the same as `STRING;TEXTAREA`.
	 */
	@IsTest
	private static void shouldMatchApplicableFieldTypesCaseInsensitivelyAndTrimmed()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(
							SEL_MaskingRule.MODE_EXACT_MATCH,
							'secret',
							'X',
							'TestMixedCase',
							' string ; textarea '
					);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'the secret one')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X one', record.Text__c, 'Lower-case CSV with whitespace should still admit STRING-typed fields');
		}
	}

	/**
	 * @description Tests the defensive fallback when every `ApplicableFieldTypes__c` token
	 * is unknown. If no token resolves the filter treats the rule as blank (apply to every
	 * text-shaped field) so misspelled configuration cannot silently disable a rule that is
	 * protecting sensitive data.
	 */
	@IsTest
	private static void shouldFallBackToApplyAllWhenApplicableFieldTypesAreAllUnknown()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(
							SEL_MaskingRule.MODE_EXACT_MATCH,
							'secret',
							'X',
							'TestAllTypos',
							'STRNIG;TEXARE;ENCYRPTED'
					);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'the secret one')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X one', record.Text__c,
					'Fully-typoed ApplicableFieldTypes must fall back to apply-to-all (secure default) so protection is not silently disabled');
		}
	}

	/**
	 * @description Tests that `parseApplicableFieldTypes` tolerates blank tokens produced by
	 * consecutive semicolons or whitespace-only entries in the CSV. Admins typing
	 * `STRING;;TEXTAREA` or `STRING; ;TEXTAREA` must get the same behaviour as `STRING;TEXTAREA`:
	 * the blank slot is skipped, not treated as an unknown token (which would trigger the
	 * "all unknown → apply everywhere" fallback).
	 */
	@IsTest
	private static void shouldSkipBlankTokensInApplicableFieldTypes()
	{
		MaskingRule__mdt rule = TST_Factory.newMaskingRule(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => 'TestBlankTokens',
				MaskingRule__mdt.ApplicableFieldTypes__c => 'STRING;; ;TEXTAREA'
		});
		MaskingTarget__mdt target = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>(), rule);

		Set<DisplayType> allowedTypes = UTIL_FrameworkMasker.parseApplicableFieldTypes(target);

		Assert.areEqual(2, allowedTypes.size(), 'Blank tokens must be skipped, not counted as unknown');
		Assert.isTrue(allowedTypes.contains(DisplayType.STRING), 'STRING token must resolve');
		Assert.isTrue(allowedTypes.contains(DisplayType.TEXTAREA), 'TEXTAREA token must resolve');
	}

	/**
	 * @description Tests that `parseApplicableFieldTypes` caches by the raw list text: later calls
	 * with the same list must return the same Set without splitting it again. Bulk triggers check the
	 * same rule for hundreds of field and record pairs; this cache keeps that cost constant instead of
	 * growing with the number of pairs.
	 */
	@IsTest
	private static void shouldCacheParsedApplicableFieldTypesByCsv()
	{
		MaskingRule__mdt rule = TST_Factory.newMaskingRule(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => 'TestCacheByCsv',
				MaskingRule__mdt.ApplicableFieldTypes__c => 'STRING;TEXTAREA'
		});
		MaskingTarget__mdt target = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>(), rule);

		Set<DisplayType> first = UTIL_FrameworkMasker.parseApplicableFieldTypes(target);
		UTIL_FrameworkMasker.parseApplicableFieldTypes(target);

		Assert.isTrue(UTIL_FrameworkMasker.cachedAllowedTypesByCsv.containsKey('STRING;TEXTAREA'), 'CSV key must be stored in the transaction cache after first parse');
		Assert.areEqual(2, first.size(), 'Two known tokens must resolve to two DisplayType enum values');
		Assert.isTrue(first.contains(DisplayType.STRING), 'STRING token must resolve to DisplayType.STRING');
		Assert.isTrue(first.contains(DisplayType.TEXTAREA), 'TEXTAREA token must resolve to DisplayType.TEXTAREA');
	}

	/**
	 * @description Registers a single active MaskingTarget pointing at Foobar__c.Text__c with an inline rule.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 */
	private static void mockTargetForFoobarText(String mode, String rulePattern, String replacement, String callerClassScope)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), mode, rulePattern, replacement, callerClassScope, 'TestRule', 10, null);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.Text__c with an explicit
	 * `FailureAction__c` value, for failure-handling tests (LogAndContinue / WriteFailureMarker / BlockDml).
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern (typically malformed so the rule throws)
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param failureAction The MaskingRule__mdt.FailureAction__c picklist value to assign
	 */
	private static void mockTargetForFoobarTextWithFailureAction(String mode, String rulePattern, String replacement, String callerClassScope, String failureAction)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), mode, rulePattern, replacement, callerClassScope, 'TestRule', 10, failureAction);
	}

	/**
	 * @description Registers a wildcard MaskingTarget (blank `Field__c`) on Foobar__c with an
	 * explicit `ApplicableFieldTypes__c` semicolon-delimited CSV so field-type-filter tests can
	 * verify that fields whose `DisplayType` is excluded from the rule are dropped at
	 * the time the batch plan is built, at no cost for each record.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param applicableFieldTypes The semicolon-delimited list of Apex DisplayType names (e.g. `STRING;TEXTAREA`)
	 */
	private static void mockTargetForFoobarWildcardWithApplicableFieldTypes
			(
					String mode,
					String rulePattern,
					String replacement,
					String ruleDeveloperName,
					String applicableFieldTypes
			)
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder(ruleDeveloperName, mode, rulePattern, replacement, 10)
				.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, applicableFieldTypes)
				.withoutInsertion(true)
				.build();
		registerMockTarget(rule, null, null);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.Text__c with an explicit
	 * `MinInputLength__c`, for tests that prove rules are skipped when the value
	 * is shorter than the configured threshold.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param minInputLength The MaskingRule__mdt.MinInputLength__c value; rule is skipped when the value is shorter
	 */
	private static void mockTargetForFoobarTextWithMinInputLength
			(
					String mode,
					String rulePattern,
					String replacement,
					String callerClassScope,
					Integer minInputLength
			)
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('TestRule', mode, rulePattern, replacement, 10)
				.withOverride(MaskingRule__mdt.MinInputLength__c, minInputLength)
				.withoutInsertion(true)
				.build();
		registerMockTarget(rule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), callerClassScope);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.Text__c with a custom rule
	 * developer name and Order__c, for duplicate and ordering tests.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param ruleOrder The MaskingRule__mdt.Order__c value controlling execution sequence
	 */
	private static void mockTargetForFoobarText(String mode, String rulePattern, String replacement, String callerClassScope, String ruleDeveloperName, Integer ruleOrder)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), mode, rulePattern, replacement, callerClassScope, ruleDeveloperName, ruleOrder, null);
	}

	/**
	 * @description Registers a single active MaskingTarget pointing at Foobar__c.TextArea__c with an inline rule.
	 * Used by shouldSkipRulesForOtherFields to prove targets for a different field don't fire.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope
	 */
	private static void mockTargetForFoobarTextArea(String mode, String rulePattern, String replacement, String callerClassScope)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c), mode, rulePattern, replacement, callerClassScope, 'TestRule', 10, null);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.TextArea__c with a custom rule
	 * developer name and Order__c, for batching and ordering tests.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param ruleOrder The MaskingRule__mdt.Order__c value controlling execution sequence
	 */
	private static void mockTargetForFoobarTextArea(String mode, String rulePattern, String replacement, String callerClassScope, String ruleDeveloperName, Integer ruleOrder)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c), mode, rulePattern, replacement, callerClassScope, ruleDeveloperName, ruleOrder, null);
	}

	/**
	 * @description Registers a MaskingTarget for a specific field on Foobar__c.
	 *
	 * @param fieldApiName The field API name (without the Foobar__c. prefix)
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param ruleOrder The MaskingRule__mdt.Order__c value controlling execution sequence
	 * @param failureAction The MaskingRule__mdt.FailureAction__c value; null leaves it unset
	 */
	private static void mockTarget
			(
					String fieldApiName,
					String mode,
					String rulePattern,
					String replacement,
					String callerClassScope,
					String ruleDeveloperName,
					Integer ruleOrder,
					String failureAction
			)
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder(ruleDeveloperName, mode, rulePattern, replacement, ruleOrder)
				.withOverride(MaskingRule__mdt.FailureAction__c, failureAction)
				.withoutInsertion(true)
				.build();
		registerMockTarget(rule, fieldApiName, callerClassScope);
	}

	/**
	 * @description Shared rule builder for the `mockTarget*` helper family. Returns a
	 * partially-configured `TST_Builder.Builder` with the six overrides every test-mock
	 * rule needs (DeveloperName, Mode, Pattern, Replacement, IsActive=true, Order). Callers
	 * chain their specialization overrides (FailureAction, MinInputLength,
	 * ApplicableFieldTypes, etc.) and terminate with `.withoutInsertion(true).build()`.
	 *
	 * @param developerName Rule DeveloperName
	 * @param mode Rule Mode__c
	 * @param pattern Rule Pattern__c
	 * @param replacement Rule Replacement__c
	 * @param order Rule Order__c
	 *
	 * @return A TST_Builder.Builder with the common rule overrides already applied
	 */
	private static TST_Builder.Builder mockRuleBuilder(String developerName, String mode, String pattern, String replacement, Decimal order)
	{
		return TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, developerName)
				.withOverride(MaskingRule__mdt.Mode__c, mode)
				.withOverride(MaskingRule__mdt.Pattern__c, pattern)
				.withOverride(MaskingRule__mdt.Replacement__c, replacement)
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withOverride(MaskingRule__mdt.Order__c, order);
	}

	/**
	 * @description Registers a single active `MaskingTarget__mdt` record for the given rule.
	 * Pass a blank `fieldApiName` to register a wildcard target (`Field__c = null`).
	 *
	 * @param rule The pre-built rule the target should point at
	 * @param fieldApiName The Foobar__c field API name (without object prefix); blank for a wildcard target
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 */
	private static void registerMockTarget(MaskingRule__mdt rule, String fieldApiName, String callerClassScope)
	{
		registerMockTargetOn(Foobar__c.SObjectType, rule, fieldApiName, callerClassScope);
	}

	/**
	 * @description Registers a single active `MaskingTarget__mdt` record for the given rule on any SObjectType.
	 * Pass a blank `fieldApiName` to register a wildcard target (`Field__c = null`).
	 *
	 * @param sObjectType The SObjectType the target names
	 * @param rule The pre-built rule the target should point at
	 * @param fieldApiName The field API name (without object prefix); blank for a wildcard target
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 */
	private static void registerMockTargetOn(SObjectType sObjectType, MaskingRule__mdt rule, String fieldApiName, String callerClassScope)
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(sObjectType);
		String fieldValue = String.isBlank(fieldApiName) ? null : objectName + UTIL_String.DOT + fieldApiName;

		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, objectName)
				.withOverride(MaskingTarget__mdt.Field__c, fieldValue)
				.withOverride(MaskingTarget__mdt.CallerClass__c, callerClassScope)
				.withOverride(MaskingTarget__mdt.Rule__c, rule)
				.build();
	}

	/**
	 * @description A mock with the shipped card rule's pattern and redaction token in regex mode (the shipped rules run
	 *              in credit-card mode with a Luhn check; the card-shaped run key these tests use passes it either way).
	 *
	 * @return An uninserted MaskingRule__mdt.
	 */
	private static MaskingRule__mdt mockCardRule()
	{
		return (MaskingRule__mdt)mockRuleBuilder('CardRule', SEL_MaskingRule.MODE_REGEX, CARD_PATTERN, CARD_REPLACEMENT, 10).withoutInsertion(true).build();
	}

	/**
	 * @description Builds an uninserted Foobar__c with Text__c and TextArea__c pre-populated.
	 * Several wildcard-target tests exercise the framework against a record carrying values on
	 * both field types; this helper builds that common record.
	 *
	 * @param textValue Value for `Foobar__c.Text__c`
	 * @param textAreaValue Value for `Foobar__c.TextArea__c`
	 *
	 * @return An uninserted Foobar__c with both fields set, ready to pass to the framework masker
	 */
	private static Foobar__c buildFoobarWithTextAndTextArea(String textValue, String textAreaValue)
	{
		return (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Text__c, textValue)
				.withOverride(Foobar__c.TextArea__c, textAreaValue)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Proves that UTIL_FrameworkMasker applies configured masking rules to a record in
	 * place when a subscriber user on the Minimum Access - Salesforce profile calls it. The running
	 * user has no FLS on the kern__ MaskingTarget CMDT objects or on kern__Foobar__c, yet masking must
	 * still read the applicable targets (framework-internal selectors run in system mode through
	 * systemModeRequired), match the configured rule, and change the record's field value whatever
	 * the caller's FLS.
	 *
	 * Catches: if a later change moved SEL_MaskingTarget (or any other selector used by masking) to
	 * USER_MODE, the low-privilege user's apply call would quietly do nothing. This test then fails
	 * when the 2GP build is validated, not later in a subscriber scratch org.
	 *
	 * @see UTIL_FrameworkMasker.forRecord
	 */
	@IsTest
	private static void shouldMaskRecordForLowPrivilegeUser()
	{
		mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Text__c, 'the secret is here')
				.withoutInsertion()
				.build();

		UTIL_FrameworkMasker.MaskingResult result;

		System.runAs(getLowPrivilegeUser())
		{
			result = UTIL_FrameworkMasker.forRecord(record).apply();
		}

		Assert.areEqual('the X is here', record.Text__c, 'Field value should be masked in place for low-privilege caller');
		Assert.areEqual(1, result.rulesMatched, 'Aggregate rulesMatched should reflect the single match');
		Assert.isFalse(result.hadErrors, 'Masking should complete without errors for low-privilege caller');
	}

	/**
	 * @description Verifies the preview method masks a value with a single rule even when no active
	 * MaskingTarget exists for the field, which is the core of previewing an unused rule. An unused
	 * Regex phone rule (no target configured) redacts a phone-shaped value, proving the active-target
	 * cache is not used.
	 */
	@IsTest
	private static void maskValueAgainstRuleRedactsDormantRegexRuleWithNoActiveTarget()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('PreviewPhone', SEL_MaskingRule.MODE_REGEX, '\\d{3}-\\d{3}-\\d{4}', '[PHONE_REDACTED]', 10)
					.withOverride(MaskingRule__mdt.IsActive__c, false)
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, rule, '415-555-1234');

			Assert.areEqual('[PHONE_REDACTED]', result.maskedValue, 'a dormant Regex rule redacts the value with no active target configured');
			Assert.areEqual(1, result.rulesMatched, 'the single preview rule matched once');
		}
	}

	/**
	 * @description Verifies the preview method applies a JsonKey rule to a JSON payload, redacting the
	 * value of the matched key while leaving the rest of the document intact.
	 */
	@IsTest
	private static void maskValueAgainstRuleMasksJsonKeyRuleOnJsonPayload()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('PreviewJsonKey', SEL_MaskingRule.MODE_JSON_KEY, 'password', '[REDACTED]', 10)
					.withOverride(MaskingRule__mdt.IsActive__c, false)
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.TextArea__c, rule, '{"password":"secret","name":"bob"}');

			Assert.areEqual(1, result.rulesMatched, 'the JsonKey rule matched the password key');
			Assert.isTrue(result.maskedValue.contains('[REDACTED]'), 'the matched key value is redacted');
			Assert.isFalse(result.maskedValue.contains('secret'), 'the original secret value is gone');
		}
	}

	/**
	 * @description Verifies the preview method leaves a plain value that is not JSON unchanged when
	 * handed a JsonKey rule. That is correct, not a failure. The console must not read this as a broken
	 * rule, so the method records zero matches and does not change the value.
	 */
	@IsTest
	private static void maskValueAgainstRuleNoOpsJsonKeyRuleOnNonJsonScalar()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('PreviewJsonKey', SEL_MaskingRule.MODE_JSON_KEY, 'password', '[REDACTED]', 10)
					.withOverride(MaskingRule__mdt.IsActive__c, false)
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, rule, 'just a plain string');

			Assert.areEqual('just a plain string', result.maskedValue, 'a JsonKey rule leaves a non-JSON scalar unchanged');
			Assert.areEqual(0, result.rulesMatched, 'no JsonKey match is recorded for a non-JSON scalar');
		}
	}

	/**
	 * @description Verifies the preview method returns the value unchanged when handed a blank value,
	 * stopping before any rule runs.
	 */
	@IsTest
	private static void maskValueAgainstRuleReturnsUnmaskedForBlankValue()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('PreviewPhone', SEL_MaskingRule.MODE_REGEX, '\\d{3}-\\d{3}-\\d{4}', '[PHONE_REDACTED]', 10)
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, rule, '');

			Assert.areEqual('', result.maskedValue, 'an empty value is returned unchanged');
			Assert.areEqual(0, result.rulesMatched, 'no rule fires on an empty value');
		}
	}

	/**
	 * @description Runs the shipped `MaskAddress` rule exactly as it deploys (a Regex rule that
	 * matches anything and replaces the whole value with a fixed token), proving the new unused rule
	 * masks a postal address through the framework masker, without the advisor pages.
	 */
	@IsTest
	private static void shippedMaskAddressRuleRedactsAddressValue()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result =
					UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, shippedRule(SEL_MaskingRule.RULE_MASK_ADDRESS), '742 Evergreen Terrace, Springfield');

			Assert.areEqual('[ADDRESS_REDACTED]', result.maskedValue, 'the shipped MaskAddress rule replaces the whole address with its token');
			Assert.areEqual(1, result.rulesMatched, 'the MaskAddress rule matched once');
		}
	}

	/**
	 * @description Runs the shipped `MaskFreeText` rule, proving the unused rule that matches anything
	 * masks a free-text value to its fixed token through the framework masker.
	 */
	@IsTest
	private static void shippedMaskFreeTextRuleRedactsTextValue()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result =
					UTIL_FrameworkMasker.maskValueAgainstRule
							(
									Foobar__c.TextArea__c,
									shippedRule(SEL_MaskingRule.RULE_MASK_FREE_TEXT),
									'Private note: customer prefers email contact only.'
							);

			Assert.areEqual('[TEXT_REDACTED]', result.maskedValue, 'the shipped MaskFreeText rule replaces the whole free-text value with its token');
			Assert.areEqual(1, result.rulesMatched, 'the MaskFreeText rule matched once');
		}
	}

	/**
	 * @description Runs the shipped `MaskPhoneInternational` rule, proving the unused rule that matches
	 * anything masks an international-format phone value (with a leading country code) to its fixed token.
	 */
	@IsTest
	private static void shippedMaskPhoneInternationalRuleRedactsValue()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result =
					UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, shippedRule(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL), '+44 20 7946 0958');

			Assert.areEqual('[PHONE_REDACTED]', result.maskedValue, 'the shipped MaskPhoneInternational rule replaces the whole phone number with its token');
			Assert.areEqual(1, result.rulesMatched, 'the MaskPhoneInternational rule matched once');
		}
	}

	/**
	 * @description Returns the shipped `MaskingRule__mdt` record with the given developer name, read
	 * through the framework's `SEL_MaskingTarget` selector (not a raw `getAll()`), so a round-trip test
	 * exercises the rule exactly as it ships (pattern, replacement, mode) through the same selector production
	 * uses, rather than a hand-built mock. Fails the test with a clear message when the rule is not
	 * deployed, so an un-deployed or renamed record surfaces as "rule not deployed" rather than an opaque
	 * downstream token-mismatch assertion.
	 *
	 * @param developerName The rule developer name to find (for example `MaskAddress`).
	 *
	 * @return The deployed rule (never `null`: a missing rule fails the test).
	 */
	private static MaskingRule__mdt shippedRule(String developerName)
	{
		MaskingRule__mdt found = null;
		for(MaskingRule__mdt rule : new SEL_MaskingTarget().getAllRulesById().values())
		{
			if(rule.DeveloperName == developerName)
			{
				found = rule;
				break;
			}
		}
		Assert.isNotNull(found, 'the shipped rule ' + developerName + ' must be deployed to the org for the round-trip test to run');
		return found;
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the low-privilege test to run UTIL_FrameworkMasker and prove that
	 * masking still works for subscriber users who have no FLS on the framework's own objects.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Tests that an untuned predecessor's target is dropped on a surface its untuned
	 * active successor mirrors: the predecessor token survives untouched (its rule never ran), the
	 * successor token is masked, and the result reports the successor as the only matched rule.
	 */
	@IsTest
	private static void shouldSuppressUntunedPredecessorTargetOnMirroredSurface()
	{
		System.runAs(getTestAdmin())
		{
			mockSupersessionPair(false, false, true);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual
					(
							PREDECESSOR_TOKEN + ' ' + SUCCESSOR_REPLACEMENT,
							record.Name,
							'The successor must mask its surface while the suppressed predecessor leaves its token untouched'
					);
			Assert.isTrue(result.matchedRuleDeveloperNames.contains(SUCCESSOR_RULE_NAME), 'The successor rule must run on the mirrored surface');
			Assert.isFalse(result.matchedRuleDeveloperNames.contains(PREDECESSOR_RULE_NAME), 'The suppressed predecessor rule must never run on the mirrored surface');
		}
	}

	/**
	 * @description Tests that a predecessor target keeps masking a field the successor does not also
	 * cover (the shape of a subscriber's custom object). The rule-level supersession check does pass,
	 * so only the missing successor target keeps the predecessor target running, and the test cannot
	 * pass for the wrong reason.
	 */
	@IsTest
	private static void shouldNotSuppressWhenSuccessorTargetMissingOnSurface()
	{
		System.runAs(getTestAdmin())
		{
			mockSupersessionPair(false, false, false);
			Foobar__c record = buildSupersessionRecord();

			Assert.isTrue(SEL_MaskingRule.findSupersededRuleNames(new SEL_MaskingTarget().getAllRulesById().values()).contains(PREDECESSOR_RULE_NAME),
					'Control check: the rule-level supersession must pass, so only the missing successor target keeps the predecessor running');

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_TOKEN, record.Name, 'The predecessor must keep masking surfaces the successor does not cover');
		}
	}

	/**
	 * @description Tests that a tuned predecessor (its current fingerprint no longer matches the
	 * successor's ReplacesFingerprint__c) is never dropped: both rules run and the tuned replacement
	 * is written, proving the subscriber's change stayed in force.
	 */
	@IsTest
	private static void shouldNotSuppressTunedPredecessor()
	{
		System.runAs(getTestAdmin())
		{
			mockSupersessionPair(true, false, true);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(TUNED_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT, record.Name, 'A tuned predecessor must keep running alongside the successor');
		}
	}

	/**
	 * @description Tests that a tuned successor (its current fingerprint no longer matches its own
	 * ShippedFingerprint__c) drops nothing: the predecessor keeps masking. The successor's change here
	 * (MinInputLength above the input length) also leaves its own token alone. This is the gap in
	 * coverage that made supersession check both the predecessor and the successor.
	 */
	@IsTest
	private static void shouldNotSuppressWhenSuccessorTuned()
	{
		System.runAs(getTestAdmin())
		{
			mockSupersessionPair(false, true, true);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual
					(
							PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_TOKEN,
							record.Name,
							'A tuned successor must not replace its predecessor: the predecessor still masks the field'
					);
		}
	}

	/**
	 * @description Tests that suppression requires an exact field|caller surface match: a
	 * wildcard predecessor target and a successor target bound to one specific field carry
	 * different composite keys, so both rules run.
	 */
	@IsTest
	private static void shouldNotSuppressAcrossDifferentSurfaceKeys()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingRule__mdt> pair = buildSupersessionRulePair(false, false);
			registerMockTarget(pair[0], null, null);
			registerMockTarget(pair[1], UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name), null);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT, record.Name,
					'A wildcard predecessor target and a field-specific successor target have different field keys: neither may be dropped');
		}
	}

	/**
	 * @description Tests that supersession pairs that exist side by side stay independent: pair one's
	 * successor covers the field and pair two's successor has no target there. Pair one's predecessor
	 * is dropped, while pair two's predecessor keeps masking. Pair one's coverage must never count
	 * for pair two.
	 */
	@IsTest
	private static void shouldSuppressEachSupersessionLinkIndependently()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingRule__mdt> firstPair = buildSupersessionRulePairNamed(PREDECESSOR_RULE_NAME, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT,
					SUCCESSOR_RULE_NAME, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT);
			List<MaskingRule__mdt> secondPair = buildSupersessionRulePairNamed('OldTextRule', 'PRED2-TOKEN', '[P2]', 'NewTextRule', 'SUCC2-TOKEN', '[S2]');
			overrideAllRules(new List<MaskingRule__mdt> {firstPair[0], firstPair[1], secondPair[0], secondPair[1]});
			registerMockTarget(firstPair[0], null, null);
			registerMockTarget(firstPair[1], null, null);
			registerMockTarget(secondPair[0], null, null);
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, PREDECESSOR_TOKEN + ' ' + SUCCESSOR_TOKEN + ' PRED2-TOKEN')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_TOKEN + ' ' + SUCCESSOR_REPLACEMENT + ' [P2]', record.Name,
					'Dropping pair one\'s predecessor must not drop pair two\'s predecessor: its own successor has no target on this field');
		}
	}

	/**
	 * @description Tests that a TUNED successor cannot use another successor's result for the same
	 * predecessor. The real successor covers only one named field, so the predecessor keeps its
	 * wildcard target even though the tuned successor's wildcard target is on the same field. The
	 * targets of a tuned successor must never decide which predecessor targets are dropped.
	 */
	@IsTest
	private static void shouldNotLetTunedSiblingSuccessorPiggybackOnAnotherLinksVerdict()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingRule__mdt> pair = buildSupersessionRulePairNamed(PREDECESSOR_RULE_NAME, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT,
					SUCCESSOR_RULE_NAME, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT);
			MaskingRule__mdt tunedSibling = (MaskingRule__mdt)mockRuleBuilder('TunedSiblingRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'SIBLING-TOKEN', '[T]', 200)
					.withOverride(MaskingRule__mdt.Replaces__c, PREDECESSOR_RULE_NAME)
					.withoutInsertion(true)
					.build();
			tunedSibling.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(pair[0]);
			tunedSibling.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(tunedSibling);
			tunedSibling.MinInputLength__c = 99;
			overrideAllRules(new List<MaskingRule__mdt> {pair[0], pair[1], tunedSibling});
			registerMockTarget(pair[0], null, null);
			registerMockTarget(pair[1], UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name), null);
			registerMockTarget(tunedSibling, null, null);
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, PREDECESSOR_TOKEN + ' ' + SUCCESSOR_TOKEN + ' SIBLING-TOKEN')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT + ' SIBLING-TOKEN', record.Name,
					'A tuned successor must not use another successor\'s result: the predecessor keeps the fields its real successor does not cover');
		}
	}

	/**
	 * @description Tests that the caller dimension participates in surface matching: a
	 * caller-scoped predecessor target and an unscoped successor target bind different surfaces,
	 * so both rules run for that caller.
	 */
	@IsTest
	private static void shouldNotSuppressCallerScopedPredecessorSurface()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingRule__mdt> pair = buildSupersessionRulePairNamed(PREDECESSOR_RULE_NAME, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT,
					SUCCESSOR_RULE_NAME, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT);
			overrideAllRules(pair);
			registerMockTarget(pair[0], null, SAMPLE_CALLER);
			registerMockTarget(pair[1], null, null);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).calledFrom(SAMPLE_CALLER).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT, record.Name,
					'A predecessor target limited to one caller does not match the successor target for every caller: nothing is dropped, both rules run');
		}
	}

	/**
	 * @description Tests that an org-local copy that shares the packaged predecessor's DeveloperName
	 * AND its values keeps masking when the packaged predecessor is dropped. A rule is identified by
	 * its namespace-qualified name everywhere (removing duplicates, checking supersession, dropping
	 * targets), so the packaged rule's result can never drop the copy's target. The namespaces are
	 * worked out at run time, so the test holds in an unmanaged org, in a managed package, and when
	 * rebuilt under any namespace.
	 */
	@IsTest
	private static void shouldNotSuppressIdenticalCloneFromAnotherNamespace()
	{
		System.runAs(getTestAdmin())
		{
			String runningNamespace = UTIL_System.getManagedPackageNamespace();
			String foreignNamespace = (runningNamespace ?? UTIL_String.EMPTY) + 'subscriber';
			MaskingRule__mdt predecessor = (MaskingRule__mdt)mockRuleBuilder(PREDECESSOR_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, PREDECESSOR_TOKEN,
					PREDECESSOR_REPLACEMENT, 200)
					.withOverride(MaskingRule__mdt.NamespacePrefix, runningNamespace)
					.withoutInsertion(true)
					.build();
			MaskingRule__mdt successor = (MaskingRule__mdt)mockRuleBuilder(SUCCESSOR_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT, 200)
					.withOverride(MaskingRule__mdt.Replaces__c, PREDECESSOR_RULE_NAME)
					.withOverride(MaskingRule__mdt.NamespacePrefix, runningNamespace)
					.withoutInsertion(true)
					.build();
			successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
			successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);
			MaskingRule__mdt clone = (MaskingRule__mdt)mockRuleBuilder(PREDECESSOR_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT, 200)
					.withOverride(MaskingRule__mdt.NamespacePrefix, foreignNamespace)
					.withoutInsertion(true)
					.build();
			overrideAllRules(new List<MaskingRule__mdt> {predecessor, successor, clone});
			registerMockTarget(predecessor, null, null);
			registerMockTarget(successor, null, null);
			registerMockTarget(clone, null, null);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT, record.Name,
					'The packaged predecessor is suppressed, but the identically-configured clone from another namespace must keep masking');
		}
	}

	/**
	 * @description Builds the standard supersession rule pair (a predecessor, and a successor naming
	 * it in Replaces__c, with both fingerprints set exactly as the shipped metadata would carry them).
	 * Applies the requested tuning AFTER the fingerprints are taken, and sets the selector's list of
	 * all rules, so supersession sees the successor rule even when no target refers to it.
	 *
	 * @param predecessorTuned Tune the predecessor's Replacement__c (fingerprint drifts; rule still matches its token)
	 * @param successorTuned Tune the successor's MinInputLength__c (fingerprint drifts; rule stops matching the short input)
	 *
	 * @return The pair: index 0 is the predecessor, index 1 the successor
	 */
	private static List<MaskingRule__mdt> buildSupersessionRulePair(Boolean predecessorTuned, Boolean successorTuned)
	{
		List<MaskingRule__mdt> pair = buildSupersessionRulePairNamed(PREDECESSOR_RULE_NAME, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT,
				SUCCESSOR_RULE_NAME, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT);

		if(predecessorTuned)
		{
			pair[0].Replacement__c = TUNED_REPLACEMENT;
		}

		if(successorTuned)
		{
			pair[1].MinInputLength__c = 99;
		}

		overrideAllRules(pair);

		return pair;
	}

	/**
	 * @description Builds a supersession rule pair with explicit names, tokens, and replacements,
	 * so a test can hold several separate pairs. Both fingerprints are taken exactly as the shipped
	 * metadata would carry them. Does NOT set the selector's list of all rules: callers that build
	 * several pairs set it once with overrideAllRules.
	 *
	 * @param predecessorName The predecessor rule DeveloperName
	 * @param predecessorToken The token only the predecessor matches
	 * @param predecessorReplacement The replacement the predecessor writes
	 * @param successorName The successor rule DeveloperName
	 * @param successorToken The token only the successor matches
	 * @param successorReplacement The replacement the successor writes
	 *
	 * @return The pair: index 0 is the predecessor, index 1 the successor
	 */
	private static List<MaskingRule__mdt> buildSupersessionRulePairNamed
			(
					String predecessorName,
					String predecessorToken,
					String predecessorReplacement,
					String successorName,
					String successorToken,
					String successorReplacement
			)
	{
		MaskingRule__mdt predecessor = (MaskingRule__mdt)mockRuleBuilder(predecessorName, SEL_MaskingRule.MODE_EXACT_MATCH, predecessorToken, predecessorReplacement, 200)
				.withoutInsertion(true)
				.build();
		MaskingRule__mdt successor = (MaskingRule__mdt)mockRuleBuilder(successorName, SEL_MaskingRule.MODE_EXACT_MATCH, successorToken, successorReplacement, 200)
				.withOverride(MaskingRule__mdt.Replaces__c, predecessorName)
				.withoutInsertion(true)
				.build();
		successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);

		return new List<MaskingRule__mdt> {predecessor, successor};
	}

	/**
	 * @description Replaces every masking rule the selector sees with the given rules, so the
	 * supersession checks see exactly these rules. The map keys are positions in the list, because
	 * copies may share a DeveloperName, and the code that reads the map reads only its values.
	 *
	 * @param rules Every masking rule the test needs
	 */
	private static void overrideAllRules(List<MaskingRule__mdt> rules)
	{
		Map<String, MaskingRule__mdt> rulesByKey = new Map<String, MaskingRule__mdt>();

		for(Integer index = 0; index < rules.size(); index++)
		{
			rulesByKey.put(String.valueOf(index), rules[index]);
		}

		SEL_MaskingTarget.allRulesOverrideForTest = rulesByKey;
	}

	/**
	 * @description Builds and registers the standard supersession matrix fixture: wildcard
	 * predecessor target, and (optionally) a wildcard successor target mirroring the same
	 * surface.
	 *
	 * @param predecessorTuned Tune the predecessor after fingerprint capture
	 * @param successorTuned Tune the successor after fingerprint capture
	 * @param successorTargetPresent Register the mirroring successor target (false = subscriber-custom-object shape)
	 */
	private static void mockSupersessionPair(Boolean predecessorTuned, Boolean successorTuned, Boolean successorTargetPresent)
	{
		List<MaskingRule__mdt> pair = buildSupersessionRulePair(predecessorTuned, successorTuned);

		registerMockTarget(pair[0], null, null);

		if(successorTargetPresent)
		{
			registerMockTarget(pair[1], null, null);
		}
	}

	/**
	 * @description Builds an uninserted Foobar__c whose Name carries both supersession tokens, so
	 * each rule's application is independently observable in the output value regardless of rule
	 * execution order.
	 *
	 * @return An uninserted Foobar__c ready for the framework masker
	 */
	private static Foobar__c buildSupersessionRecord()
	{
		return (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, PREDECESSOR_TOKEN + ' ' + SUCCESSOR_TOKEN)
				.withoutInsertion()
				.build();
	}
}