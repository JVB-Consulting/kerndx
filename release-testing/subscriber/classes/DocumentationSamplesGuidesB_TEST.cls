// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs code samples from the guides on resilience, feature flags, data masking, validation, test data,
 * code scanning, utilities, objects and metadata, and logging, in an org where KernDX is installed with its kern
 * namespace. Each test runs a sample as the guide prints it, with the kern prefixes added, and checks what it really
 * does, so a guide can only say what the package does.
 *
 * The class does not run in parallel with other tests: some tests deliver a platform event and read the saved log
 * rows, and log rows saved by other tests at the same time would get in the way.
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class DocumentationSamplesGuidesB_TEST
{
	/**
	 * @description The account type before the change in the validation sample.
	 */
	private static final String TYPE_PROSPECT = 'Prospect';

	/**
	 * @description The account type after the change in the validation sample.
	 */
	private static final String TYPE_CUSTOMER = 'Customer - Direct';

	/**
	 * @description The formula the validation guide's test sample describes, as the guide prints it.
	 */
	private static final String IS_CHANGED_FORMULA = 'ISCHANGED(oldRecord, newRecord, Type)';

	/**
	 * @description The way the same guide teaches to find a changed field, compare the new value with the old one, with
	 * the picklist field Type turned into text first.
	 */
	private static final String TYPE_CHANGED_FORMULA = 'TEXT(newRecord.Type) <> TEXT(oldRecord.Type)';

	/**
	 * @description The example the Custom Validations Fast Start prints for a changed field, on the picklist field
	 * Industry.
	 */
	private static final String INDUSTRY_CHANGED_AS_WRITTEN_FORMULA = 'newRecord.Industry <> oldRecord.Industry';

	/**
	 * @description The same example with the picklist field turned into text first.
	 */
	private static final String INDUSTRY_CHANGED_FORMULA = 'TEXT(newRecord.Industry) <> TEXT(oldRecord.Industry)';

	/**
	 * @description The new-record check the validation guide prints under Change Detection.
	 */
	private static final String NEW_RECORD_AS_WRITTEN_FORMULA = 'ISBLANK(oldRecord)';

	/**
	 * @description The new-record check that tests the old record's Id instead.
	 */
	private static final String NEW_RECORD_FORMULA = 'ISBLANK(oldRecord.Id)';

	/**
	 * @description The industry before the change in the Fast Start sample.
	 */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/**
	 * @description The industry after the change in the Fast Start sample.
	 */
	private static final String INDUSTRY_TECHNOLOGY = 'Technology';

	/**
	 * @description The name the formula samples give the process, which the package puts in its error message.
	 */
	private static final String PROCESS_NAME = 'Documentation sample';

	/**
	 * @description The start of the fingerprint the package gives a recorded bypass.
	 */
	private static final String BYPASS_FINGERPRINT = 'detail:bypass:';

	/**
	 * @description The short message of a recorded validation bypass.
	 */
	private static final String VALIDATION_BYPASS_MESSAGE = 'BYPASS object:Account (validation)';

	/**
	 * @description The short message of a recorded trigger bypass, which the validation read must leave out.
	 */
	private static final String TRIGGER_BYPASS_MESSAGE = 'BYPASS object:Account (trigger)';

	/**
	 * @description The text a shadow-mode rule puts in its warning.
	 */
	private static final String SHADOW_MESSAGE = '[SHADOW] Account_Require_Industry would have blocked the save';

	/**
	 * @description The place in the code that writes the validation timing entries.
	 */
	private static final String VALIDATION_TIMING_PLACE = 'kern.UTIL_ValidationRule/processRulesForContext';

	/**
	 * @description The message the logging samples write.
	 */
	private static final String LOG_MESSAGE = 'Order processed';

	/**
	 * @description The place in the code the logging samples name.
	 */
	private static final String LOG_PLACE = 'DocumentationSamplesGuidesB_TEST.loggingSample';

	/**
	 * @description The tracking ID the chain run sample looks for.
	 */
	private static final String CORRELATION_ID = 'documentation-sample-correlation';

	/**
	 * @description The chain name on the chain run the sample looks for.
	 */
	private static final String CHAIN_NAME = 'Documentation sample chain';

	/**
	 * @description The feature flag that switches off every API call.
	 */
	private static final String DISABLE_ALL_APIS_FLAG = 'DisableAllAPIs';

	/**
	 * @description The email address start the test data sample's default provider writes.
	 */
	private static final String EMAIL_PREFIX = 'qa+';

	/**
	 * @description The name the package gives the result of count('Id') in a grouped read.
	 */
	private static final String COUNT_NAME = 'count_Id';

	/**
	 * @description The name the validation guide's bulk context used for the count, as written.
	 */
	private static final String COUNT_NAME_AS_WRITTEN = 'expr0';

	/**
	 * @description Builds an account in memory, not saved but with a made-up Id, with the type and industry given.
	 *
	 * @param accountType The account type.
	 * @param industry The account industry.
	 *
	 * @return The account, not saved.
	 */
	private static Account buildAccount(String accountType, String industry)
	{
		return (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Type, accountType)
				.withOverride(Account.Industry, industry)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Runs a formula over records, the way a validation rule runs it.
	 *
	 * @param formula The formula to run.
	 * @param oldRecords The old versions, or a list holding null for a new record.
	 * @param newRecords The new versions.
	 *
	 * @return The new versions of the records the formula matched.
	 */
	private static List<SObject> runFormula(String formula, List<SObject> oldRecords, List<SObject> newRecords)
	{
		kern.UTIL_FormulaFilter filter = new kern.UTIL_FormulaFilter(PROCESS_NAME, kern.UTIL_FormulaContext.AccountContext.class.getName(), formula);

		return filter.filter(oldRecords, newRecords).newRecords;
	}

	/**
	 * @description Runs a formula over one account whose type and industry changed.
	 *
	 * @param formula The formula to run.
	 *
	 * @return The new versions of the accounts the formula matched.
	 */
	private static List<SObject> runFormulaOnChange(String formula)
	{
		Account oldAccount = buildAccount(TYPE_PROSPECT, INDUSTRY_FINANCE);
		Account newAccount = oldAccount.clone(true);
		newAccount.Type = TYPE_CUSTOMER;
		newAccount.Industry = INDUSTRY_TECHNOLOGY;

		return runFormula(formula, new List<SObject> {oldAccount}, new List<SObject> {newAccount});
	}

	/**
	 * @description Runs a formula over one account being updated without a change, and one account being inserted, in
	 * that order.
	 *
	 * @param formula The formula to run.
	 *
	 * @return The new versions of the accounts the formula matched.
	 */
	private static List<SObject> runFormulaOnUpdateAndInsert(String formula)
	{
		Account updatedAccount = buildAccount(TYPE_PROSPECT, INDUSTRY_FINANCE);
		Account insertedAccount = buildAccount(TYPE_CUSTOMER, INDUSTRY_TECHNOLOGY);

		return runFormula(formula, new List<SObject> {updatedAccount, null}, new List<SObject> {updatedAccount.clone(true), insertedAccount});
	}

	/**
	 * @description Checks that the package refuses to build a formula, with the platform's formula error.
	 *
	 * @param formula The formula the package must refuse.
	 */
	private static void assertFormulaRefused(String formula)
	{
		try
		{
			runFormulaOnChange(formula);
			Assert.fail('Expected the package to refuse the formula ' + formula);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, FormulaValidationException.class, 'Expected a formula error for ' + formula);
			Assert.isTrue(error.getMessage().contains(formula), 'Expected the error to name the formula, got ' + error.getMessage());
		}
	}

	/**
	 * @description Saves one log row with the values given.
	 *
	 * @param values The field values for the row.
	 *
	 * @return The saved row.
	 */
	private static kern__LogEntry__c insertLogEntry(Map<SObjectField, Object> values)
	{
		return (kern__LogEntry__c)kern.TST_Builder.of(kern__LogEntry__c.SObjectType).withOverrides(values).build();
	}

	/**
	 * @description Writes one log message through the logger and delivers it, so the package saves the log row as it
	 * does in a real org.
	 */
	private static void emitLogMessage()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		kern.LOG_Builder.build().info(LOG_MESSAGE).emitAt(LOG_PLACE);
		Test.getEventBus().deliver();
	}

	/**
	 * @description The validation guide's test sample says the rule rejects ISCHANGED(oldRecord, newRecord, Type). The
	 * package cannot build that formula, so a rule written that way never runs.
	 */
	@IsTest
	private static void validationIsChangedFormulaAsWrittenIsRefused()
	{
		Test.startTest();
		assertFormulaRefused(IS_CHANGED_FORMULA);
		Test.stopTest();
	}

	/**
	 * @description The way the validation guide teaches to find a changed field, with the picklist turned into text,
	 * matches the account whose type changed and leaves an unchanged one alone.
	 */
	@IsTest
	private static void validationTypeChangedFormulaMatchesTypeChange()
	{
		Test.startTest();
		List<SObject> matched = runFormulaOnChange(TYPE_CHANGED_FORMULA);
		List<SObject> unchangedMatched = runFormulaOnUpdateAndInsert(TYPE_CHANGED_FORMULA);
		Test.stopTest();

		Assert.areEqual(1, matched.size(), 'Expected the formula to match the account whose type changed');
		Assert.areEqual(TYPE_CUSTOMER, ((Account)matched[0]).Type, 'Expected the matched record to be the new version');
		Assert.areEqual(1, unchangedMatched.size(), 'Expected only the new account to match, not the unchanged one');
		Assert.areEqual(TYPE_CUSTOMER, ((Account)unchangedMatched[0]).Type, 'Expected the new account to be the match');
	}

	/**
	 * @description The Custom Validations Fast Start's example for a changed field compares the picklist Industry
	 * directly, as written. The package cannot build that formula, because a picklist field only works inside certain
	 * functions.
	 */
	@IsTest
	private static void customValidationsIndustryChangedAsWrittenIsRefused()
	{
		Test.startTest();
		assertFormulaRefused(INDUSTRY_CHANGED_AS_WRITTEN_FORMULA);
		Test.stopTest();
	}

	/**
	 * @description The same example with the picklist turned into text matches the account whose industry changed.
	 */
	@IsTest
	private static void customValidationsIndustryChangedWithTextMatches()
	{
		Test.startTest();
		List<SObject> matched = runFormulaOnChange(INDUSTRY_CHANGED_FORMULA);
		Test.stopTest();

		Assert.areEqual(1, matched.size(), 'Expected the formula to match the account whose industry changed');
		Assert.areEqual(INDUSTRY_TECHNOLOGY, ((Account)matched[0]).Industry, 'Expected the matched record to be the new version');
	}

	/**
	 * @description The validation guide's new-record check, ISBLANK(oldRecord), as written. The package cannot build it,
	 * because a formula can read a field of the old record but not the old record itself.
	 */
	@IsTest
	private static void validationNewRecordCheckAsWrittenIsRefused()
	{
		Test.startTest();
		assertFormulaRefused(NEW_RECORD_AS_WRITTEN_FORMULA);
		Test.stopTest();
	}

	/**
	 * @description Testing the old record's Id matches the inserted account and leaves the updated one alone.
	 */
	@IsTest
	private static void validationNewRecordCheckOnIdMatchesInsertOnly()
	{
		Test.startTest();
		List<SObject> matched = runFormulaOnUpdateAndInsert(NEW_RECORD_FORMULA);
		Test.stopTest();

		Assert.areEqual(1, matched.size(), 'Expected only the inserted account to match, got ' + matched.size());
		Assert.areEqual(TYPE_CUSTOMER, ((Account)matched[0]).Type, 'Expected the inserted account to be the match');
	}

	/**
	 * @description The validation guide's bypass read returns only validation bypasses, newest first.
	 */
	@IsTest
	private static void validationBypassReadReturnsValidationBypassesNewestFirst()
	{
		kern__LogEntry__c olderBypass = insertLogEntry(new Map<SObjectField, Object>
		{
				kern__LogEntry__c.kern__Fingerprint__c => BYPASS_FINGERPRINT + 'older',
				kern__LogEntry__c.kern__ShortMessage__c => VALIDATION_BYPASS_MESSAGE
		});
		kern__LogEntry__c newerBypass = insertLogEntry(new Map<SObjectField, Object>
		{
				kern__LogEntry__c.kern__Fingerprint__c => BYPASS_FINGERPRINT + 'newer',
				kern__LogEntry__c.kern__ShortMessage__c => VALIDATION_BYPASS_MESSAGE
		});
		insertLogEntry(new Map<SObjectField, Object>
		{
				kern__LogEntry__c.kern__Fingerprint__c => BYPASS_FINGERPRINT + 'trigger',
				kern__LogEntry__c.kern__ShortMessage__c => TRIGGER_BYPASS_MESSAGE
		});
		Test.setCreatedDate(olderBypass.Id, Datetime.now().addDays(-2));
		Test.setCreatedDate(newerBypass.Id, Datetime.now().addDays(-1));

		Test.startTest();
		List<kern__LogEntry__c> validationBypasses = new SEL_LogEntries().query
				.condition(kern__LogEntry__c.kern__Fingerprint__c).startsWith('detail:bypass:')
				.andCondition(kern__LogEntry__c.kern__ShortMessage__c).endsWith('(validation)')
				.orderBy(kern__LogEntry__c.CreatedDate).descending()
				.toList();
		Test.stopTest();

		Assert.areEqual(2, validationBypasses.size(), 'Expected only the two validation bypasses, got ' + validationBypasses.size());
		Assert.areEqual(newerBypass.Id, validationBypasses[0].Id, 'Expected the newer bypass first');
		Assert.areEqual(olderBypass.Id, validationBypasses[1].Id, 'Expected the older bypass second');
		Assert.areEqual(VALIDATION_BYPASS_MESSAGE, validationBypasses[0].kern__ShortMessage__c, 'Expected the short message to be read');
	}

	/**
	 * @description The validation guide's shadow read returns only warnings that carry the shadow prefix.
	 */
	@IsTest
	private static void validationShadowReadReturnsShadowWarnings()
	{
		kern__LogEntry__c shadowWarning = insertLogEntry(new Map<SObjectField, Object>
		{
				kern__LogEntry__c.kern__LogLevel__c => LoggingLevel.WARN.name(),
				kern__LogEntry__c.kern__ShortMessage__c => SHADOW_MESSAGE
		});
		insertLogEntry(new Map<SObjectField, Object>
		{
				kern__LogEntry__c.kern__LogLevel__c => LoggingLevel.INFO.name(),
				kern__LogEntry__c.kern__ShortMessage__c => SHADOW_MESSAGE
		});
		insertLogEntry(new Map<SObjectField, Object>
		{
				kern__LogEntry__c.kern__LogLevel__c => LoggingLevel.WARN.name(),
				kern__LogEntry__c.kern__ShortMessage__c => LOG_MESSAGE
		});

		Test.startTest();
		List<kern__LogEntry__c> shadowViolations = new SEL_LogEntries().query
				.condition(kern__LogEntry__c.kern__LogLevel__c).equals('WARN')
				.andCondition(kern__LogEntry__c.kern__ShortMessage__c).contains('[SHADOW]')
				.orderBy(kern__LogEntry__c.CreatedDate).descending()
				.withLimit(100)
				.toList();
		Test.stopTest();

		Assert.areEqual(1, shadowViolations.size(), 'Expected only the shadow warning, got ' + shadowViolations.size());
		Assert.areEqual(shadowWarning.Id, shadowViolations[0].Id, 'Expected the shadow warning');
	}

	/**
	 * @description The validation guide's timing read returns the validation timing entries, slowest first, and keeps
	 * to its row limit.
	 */
	@IsTest
	private static void validationTimingReadReturnsSlowestFirst()
	{
		List<Integer> durations = new List<Integer> {120, 380, 45};

		for(Integer duration : durations)
		{
			insertLogEntry(new Map<SObjectField, Object>
			{
					kern__LogEntry__c.kern__LogLevel__c => LoggingLevel.DEBUG.name(),
					kern__LogEntry__c.kern__ClassMethod__c => VALIDATION_TIMING_PLACE,
					kern__LogEntry__c.kern__DurationMs__c => duration
			});
		}

		insertLogEntry(new Map<SObjectField, Object>
		{
				kern__LogEntry__c.kern__LogLevel__c => LoggingLevel.DEBUG.name(),
				kern__LogEntry__c.kern__ClassMethod__c => LOG_PLACE,
				kern__LogEntry__c.kern__DurationMs__c => 999
		});

		Test.startTest();
		List<kern__LogEntry__c> validationLogs = new SEL_LogEntries().query
				.condition(kern__LogEntry__c.kern__LogLevel__c).equals('DEBUG')
				.andCondition(kern__LogEntry__c.kern__ClassMethod__c).contains('UTIL_ValidationRule/processRulesForContext')
				.orderBy(kern__LogEntry__c.kern__DurationMs__c).descending()
				.withLimit(50)
				.toList();
		Test.stopTest();

		List<Decimal> returnedDurations = new List<Decimal>();

		for(kern__LogEntry__c entry : validationLogs)
		{
			returnedDurations.add(entry.kern__DurationMs__c);
		}

		Assert.areEqual(new List<Decimal> {380, 120, 45}, returnedDurations, 'Expected only the validation timing entries, slowest first');
	}

	/**
	 * @description The logging guide's right read finds the running user's saved log rows through the user ID field,
	 * and its wrong read, through the creator, finds none, because the Automated Process user saves every row.
	 */
	@IsTest
	private static void loggingUserReadFindsRowsAndCreatorReadFindsNone()
	{
		Test.startTest();
		emitLogMessage();
		Test.stopTest();

		List<kern__LogEntry__c> myLogs = new SEL_LogEntries().query
				.condition(kern__LogEntry__c.kern__UserId__c).equals(UserInfo.getUserId())
				.orderBy(kern__LogEntry__c.CreatedDate).descending()
				.toList();

		List<kern__LogEntry__c> brokenQuery = new SEL_LogEntries().query
				.condition(kern__LogEntry__c.CreatedById).equals(UserInfo.getUserId())
				.toList();

		Assert.isFalse(myLogs.isEmpty(), 'Expected the read by user ID to find the saved log row');
		Assert.areEqual(LOG_PLACE, myLogs[0].kern__ClassMethod__c, 'Expected the saved row to be the one the test wrote');
		Assert.isTrue(brokenQuery.isEmpty(), 'Expected the read by creator to find no rows, got ' + brokenQuery.size());
	}

	/**
	 * @description The logging guide's clean-up sample finds the user's log rows older than 30 days and deletes them,
	 * and leaves a newer row alone.
	 */
	@IsTest
	private static void loggingCleanupDeletesOnlyOldRows()
	{
		Id targetUserId = UserInfo.getUserId();
		kern__LogEntry__c oldEntry = insertLogEntry(new Map<SObjectField, Object> {kern__LogEntry__c.kern__UserId__c => targetUserId});
		kern__LogEntry__c newEntry = insertLogEntry(new Map<SObjectField, Object> {kern__LogEntry__c.kern__UserId__c => targetUserId});
		Test.setCreatedDate(oldEntry.Id, Datetime.now().addDays(-31));

		Test.startTest();
		List<kern__LogEntry__c> stale = new SEL_LogEntries().query
				.condition(kern__LogEntry__c.kern__UserId__c).equals(targetUserId)
				.andCondition(kern__LogEntry__c.CreatedDate).lessThan(Datetime.now().addDays(-30))
				.toList();
		kern.DML_Builder.newTransaction().doDelete(stale).execute();
		Test.stopTest();

		Assert.areEqual(1, stale.size(), 'Expected the read to find only the old row, got ' + stale.size());
		Assert.areEqual(oldEntry.Id, stale[0].Id, 'Expected the old row');
		Assert.isNull(new SEL_LogEntries().findById(oldEntry.Id), 'Expected the old row to be deleted');
		Assert.isNotNull(new SEL_LogEntries().findById(newEntry.Id), 'Expected the newer row to stay');
	}

	/**
	 * @description The objects and metadata guide's chain run read finds the run by its tracking ID and fills in the
	 * four fields the sample reads.
	 */
	@IsTest
	private static void chainRunReadFindsRunByCorrelationId()
	{
		kern__AsyncChainExecution__c savedRun = (kern__AsyncChainExecution__c)kern.TST_Builder.of(kern__AsyncChainExecution__c.SObjectType)
				.withOverride(kern__AsyncChainExecution__c.kern__CorrelationId__c, CORRELATION_ID)
				.withOverride(kern__AsyncChainExecution__c.kern__ChainName__c, CHAIN_NAME)
				.withOverride(kern__AsyncChainExecution__c.kern__CompletedSteps__c, 1)
				.withOverride(kern__AsyncChainExecution__c.kern__TotalSteps__c, 3)
				.build();
		kern.TST_Builder.of(kern__AsyncChainExecution__c.SObjectType).build();

		Test.startTest();
		kern__AsyncChainExecution__c execution = (kern__AsyncChainExecution__c)new SEL_AsyncChainExecutions().query
				.condition(kern__AsyncChainExecution__c.kern__CorrelationId__c).equals(CORRELATION_ID)
				.getFirst();
		Test.stopTest();

		Assert.areEqual(savedRun.Id, execution.Id, 'Expected the run with the tracking ID');
		Assert.areEqual(CHAIN_NAME, execution.kern__ChainName__c, 'Expected the chain name to be read');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'Expected the completed steps to be read');
		Assert.areEqual(3, execution.kern__TotalSteps__c, 'Expected the total steps to be read');
		Assert.isNotNull(execution.kern__Status__c, 'Expected the status to be read');
	}

	/**
	 * @description The DisableAllAPIs flag reads the ApiRuntimeSwitch__c setting: with Disable All APIs ticked for the
	 * running user, the flag is on.
	 */
	@IsTest
	private static void disableAllApisFlagFollowsUserSetting()
	{
		kern.TST_Builder.of(kern__ApiRuntimeSwitch__c.SObjectType)
				.withOverride(kern__ApiRuntimeSwitch__c.SetupOwnerId, UserInfo.getUserId())
				.withOverride(kern__ApiRuntimeSwitch__c.kern__DisableAllApis__c, true)
				.build();

		Test.startTest();
		Boolean isDisabled = kern.UTIL_FeatureFlag.isEnabled(DISABLE_ALL_APIS_FLAG);
		Test.stopTest();

		Assert.isTrue(isDisabled, 'Expected the flag to be on when the user setting ticks Disable All APIs');
	}

	/**
	 * @description With no ApiRuntimeSwitch__c setting saved, the DisableAllAPIs flag is off.
	 */
	@IsTest
	private static void disableAllApisFlagIsOffWithoutSetting()
	{
		Test.startTest();
		Boolean isDisabled = kern.UTIL_FeatureFlag.isEnabled(DISABLE_ALL_APIS_FLAG);
		Test.stopTest();

		Assert.isFalse(isDisabled, 'Expected the flag to be off when no setting ticks Disable All APIs');
	}

	/**
	 * @description The test data guide's default provider makes Industry a required field on accounts and writes its
	 * own email addresses, once it is set for the transaction.
	 */
	@IsTest
	private static void testDataDefaultProviderFillsIndustryAndEmail()
	{
		kern.TST_Builder.defaultValueProvider = new MyDefaultProvider();

		Test.startTest();
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType).withoutInsertion(true).build();
		Contact contact = (Contact)kern.TST_Builder.of(Contact.SObjectType)
				.withDefaultedField(Contact.Email)
				.withoutInsertion(true)
				.build();
		Test.stopTest();

		Assert.isNotNull(account.Industry, 'Expected the provider to make the builder fill in Industry');
		Assert.isTrue(contact.Email?.startsWith(EMAIL_PREFIX) == true, 'Expected the provider to write the email address, got ' + contact.Email);
	}

	/**
	 * @description The validation guide's bulk context read the count under the name expr0, as written. The package
	 * names the result of count('Id') count_Id, so that read fails.
	 */
	@IsTest
	private static void validationBulkContextCountNameAsWrittenFails()
	{
		kern.UTIL_ValidationRule.bypassObject(String.valueOf(Account.SObjectType));
		kern.UTIL_ValidationRule.bypassObject(String.valueOf(Contact.SObjectType));
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();
		kern.TST_Builder.of(Contact.SObjectType).withOverride(Contact.AccountId, account.Id).build();

		Test.startTest();
		List<kern.QRY_Builder.AggregateRow> rows = kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.count('Id')
				.groupBy(Contact.AccountId)
				.condition(Contact.AccountId).isIn(new List<Id> {account.Id})
				.toAggregateList();
		Test.stopTest();

		try
		{
			rows[0].get(COUNT_NAME_AS_WRITTEN);
			Assert.fail('Expected the row to have no value named ' + COUNT_NAME_AS_WRITTEN);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Expected a field error for ' + COUNT_NAME_AS_WRITTEN);
		}
	}

	/**
	 * @description The validation guide's bulk context counts the contacts of each account in one grouped read through
	 * a contact selector. It returns the same counts as the read straight through the query builder that the guide
	 * printed before.
	 */
	@IsTest
	private static void validationBulkContextCountsContactsThroughSelector()
	{
		kern.UTIL_ValidationRule.bypassObject(String.valueOf(Account.SObjectType));
		kern.UTIL_ValidationRule.bypassObject(String.valueOf(Contact.SObjectType));
		Account accountWithTwo = (Account)kern.TST_Builder.of(Account.SObjectType).build();
		Account accountWithOne = (Account)kern.TST_Builder.of(Account.SObjectType).build();
		Account accountWithNone = (Account)kern.TST_Builder.of(Account.SObjectType).build();
		List<Id> parentIds = new List<Id> {accountWithTwo.Id, accountWithTwo.Id, accountWithOne.Id};

		for(Id parentId : parentIds)
		{
			kern.TST_Builder.of(Contact.SObjectType).withOverride(Contact.AccountId, parentId).build();
		}

		List<Id> accountIds = new List<Id> {accountWithTwo.Id, accountWithOne.Id, accountWithNone.Id};

		Test.startTest();
		List<kern.QRY_Builder.AggregateRow> selectorRows = new SEL_Contacts().query
				.count('Id')
				.groupBy(Contact.AccountId)
				.condition(Contact.AccountId).isIn(accountIds)
				.toAggregateList();
		List<kern.QRY_Builder.AggregateRow> builderRows = kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.count('Id')
				.groupBy(Contact.AccountId)
				.condition(Contact.AccountId).isIn(accountIds)
				.toAggregateList();
		Test.stopTest();

		Map<Id, Integer> selectorCounts = countByAccountId(selectorRows);

		Assert.areEqual(new Map<Id, Integer> {accountWithTwo.Id => 2, accountWithOne.Id => 1}, selectorCounts,
				'Expected two contacts on the first account, one on the second, and no row for the third');
		Assert.areEqual(countByAccountId(builderRows), selectorCounts, 'Expected the selector read to return the same counts as the builder read');
	}

	/**
	 * @description Turns grouped contact counts into a map of each account's contact count, the way the validation
	 * guide's bulk context does.
	 *
	 * @param rows The grouped rows, one for each account.
	 *
	 * @return The number of contacts for each account.
	 */
	private static Map<Id, Integer> countByAccountId(List<kern.QRY_Builder.AggregateRow> rows)
	{
		Map<Id, Integer> contactCountByAccountId = new Map<Id, Integer>();

		for(kern.QRY_Builder.AggregateRow row : rows)
		{
			contactCountByAccountId.put((Id)row.get('AccountId'), (Integer)row.get(COUNT_NAME));
		}

		return contactCountByAccountId;
	}

	/**
	 * @description The contact selector the validation guide's bulk context reads through.
	 */
	private with sharing class SEL_Contacts extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for contacts.
		 */
		public SEL_Contacts()
		{
			super(Contact.SObjectType);
		}

		/**
		 * @description Lists the fields every read returns.
		 *
		 * @return The fields.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField> {Contact.AccountId};
		}
	}

	/**
	 * @description The log selector the guides show, with the fields of the validation guide's version.
	 */
	private with sharing class SEL_LogEntries extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for log rows.
		 */
		public SEL_LogEntries()
		{
			super(kern__LogEntry__c.SObjectType);
		}

		/**
		 * @description Lists the fields every read returns.
		 *
		 * @return The fields.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField>
			{
					kern__LogEntry__c.kern__UserId__c,
					kern__LogEntry__c.kern__ShortMessage__c,
					kern__LogEntry__c.kern__ClassMethod__c,
					kern__LogEntry__c.CreatedDate,
					kern__LogEntry__c.kern__ContextData__c,
					kern__LogEntry__c.kern__OccurrenceCount__c,
					kern__LogEntry__c.LastModifiedDate,
					kern__LogEntry__c.kern__Message__c,
					kern__LogEntry__c.kern__DurationMs__c
			};
		}
	}

	/**
	 * @description The chain run selector from the objects and metadata guide.
	 */
	private with sharing class SEL_AsyncChainExecutions extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for chain runs.
		 */
		public SEL_AsyncChainExecutions()
		{
			super(kern__AsyncChainExecution__c.SObjectType);
		}

		/**
		 * @description Lists the fields every read returns.
		 *
		 * @return The fields.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField>
			{
					kern__AsyncChainExecution__c.kern__ChainName__c,
					kern__AsyncChainExecution__c.kern__Status__c,
					kern__AsyncChainExecution__c.kern__CompletedSteps__c,
					kern__AsyncChainExecution__c.kern__TotalSteps__c
			};
		}
	}

	/**
	 * @description The default value provider from the test data guide.
	 */
	private inherited sharing class MyDefaultProvider extends kern.UTIL_SObjectBuilderDefaultProvider
	{
		/**
		 * @description Makes Industry a field the builder fills in on accounts.
		 *
		 * @param sObjectType The object being built.
		 *
		 * @return The fields the builder fills in.
		 */
		public override Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
		{
			if(sObjectType == Account.SObjectType)
			{
				return new Set<SObjectField> {Account.Industry};
			}
			return super.defineSObjectRequiredFields(sObjectType);
		}

		/**
		 * @description Writes an email address that starts with qa+ and the record's number.
		 *
		 * @param fieldDescribe The email field.
		 * @param recordIndex The number of the record being built.
		 *
		 * @return The email address.
		 */
		public override String getEmailDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
		{
			return 'qa+' + recordIndex + '@example.com';
		}
	}
}
