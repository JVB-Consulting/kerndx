// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for PROC_LoginFrequencyAggregator.
 *
 * @see PROC_LoginFrequencyAggregator
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
private class PROC_LoginFrequencyAggregator_TEST
{
	/**
	 * @description The current running user's ID used across all test methods.
	 */
	private static final Id RUNNING_USER_ID = UserInfo.getUserId();

	/**
	 * @description Tests that finish() updates the LastSuccessfulRunTime watermark.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldUpdateWatermarkOnFinish()
	{
		TST_Builder.of(ScheduleSetting__c.SObjectType)
				.withOverride(ScheduleSetting__c.Name, PROC_LoginFrequencyAggregator.SETTING_NAME)
				.withOverride(ScheduleSetting__c.LastSuccessfulRunTime__c, UTIL_Random.randomDateTime())
				.build();

		ScheduleSetting__c settingBefore = SEL_ScheduleSetting.getScheduleSetting(PROC_LoginFrequencyAggregator.SETTING_NAME);
		Datetime previousRunTime = settingBefore.LastSuccessfulRunTime__c;

		new PROC_LoginFrequencyAggregator(Datetime.now()).finish(null);

		ScheduleSetting__c settingAfter = SEL_ScheduleSetting.getScheduleSetting(PROC_LoginFrequencyAggregator.SETTING_NAME);

		Assert.areNotEqual(previousRunTime, settingAfter.LastSuccessfulRunTime__c, 'Watermark should be updated after finish');
	}

	/**
	 * @description Tests that execute() converts LoginHistory records to DTOs and creates LoginFrequency__c records.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldConvertAndProcessLoginHistories()
	{
		List<LoginHistory> loginHistories = (List<LoginHistory>)JSON.deserialize
				(
						'[{"LoginTime":"2022-05-05T09:57:46.000+0000","UserId":"' + RUNNING_USER_ID + '"}]',
						List<LoginHistory>.class
				);

		Test.startTest();
		new PROC_LoginFrequencyAggregator(Datetime.now()).execute(loginHistories);
		Test.stopTest();

		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();

		Assert.areEqual(1, results.size(), 'Should create one LoginFrequency record');
		Assert.areEqual(1, results[0].TotalLoginCount__c, 'Should have one total login');
		Assert.areEqual(1, results[0].UniqueLoginCount__c, 'Should have one unique login day');
	}

	/**
	 * @description Tests that execute() logs errors and re-throws when processing fails.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldLogErrorWhenProcessingFails()
	{
		List<LoginHistory> loginHistories = (List<LoginHistory>)JSON.deserialize
				(
						'[{"UserId":"' + RUNNING_USER_ID + '"}]',
						List<LoginHistory>.class
				);

		try
		{
			new PROC_LoginFrequencyAggregator(Datetime.now()).execute(loginHistories);
			Assert.fail('Should throw exception for null LoginTime');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, NullPointerException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that generateAndStoreLoginFrequencies returns early for empty input without errors.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldHandleEmptyInput()
	{
		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>());

		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();

		Assert.isTrue(results.isEmpty(), 'Should not create any LoginFrequency records');
	}

	/**
	 * @description Tests that generateAndStoreLoginFrequencies updates existing LoginFrequency__c records correctly
	 * when all composite keys match pre-existing records.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldUpdateExistingLoginFrequencyRecords()
	{
		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = TST_Factory.getDtoLoginHistories();
		Set<String> concatenatedStrings = getConcatenatedStrings(dtoLoginHistories);

		List<LoginFrequency__c> createdLoginFrequencyRecords =
				TST_Factory.createLoginFrequencyRecords(concatenatedStrings.size(), concatenatedStrings);

		Test.startTest();

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(dtoLoginHistories);

		Test.stopTest();

		List<LoginFrequency__c> updatedLoginFrequencies = new SEL_LoginFrequency().getAll();

		Map<String, Integer> uniqueCountsMap = new Map<String, Integer>
		{
				dtoLoginHistories[0].userId + '_2022-05' => 1,
				dtoLoginHistories[3].userId + '_2022-05' => 2,
				dtoLoginHistories[4].userId + '_2022-05' => 1,
				dtoLoginHistories[5].userId + '_2022-06' => 1
		};

		Map<String, Integer> totalCountsMap = new Map<String, Integer>
		{
				dtoLoginHistories[0].userId + '_2022-05' => 2,
				dtoLoginHistories[3].userId + '_2022-05' => 2,
				dtoLoginHistories[4].userId + '_2022-05' => 1,
				dtoLoginHistories[5].userId + '_2022-06' => 1
		};

		Assert.areEqual(concatenatedStrings.size(), updatedLoginFrequencies.size(), 'Incorrect number of login frequencies');

		for(Integer i = 0; i < updatedLoginFrequencies.size(); i++)
		{
			LoginFrequency__c loginFrequencyBeforeUpdate = createdLoginFrequencyRecords.get(i);
			LoginFrequency__c loginFrequencyAfterUpdate = updatedLoginFrequencies.get(i);
			Integer expectedUniqueCount = (Integer)loginFrequencyBeforeUpdate.UniqueLoginCount__c
					+ uniqueCountsMap.get(loginFrequencyBeforeUpdate.CompositeKey__c);
			Integer expectedTotalCount = (Integer)loginFrequencyBeforeUpdate.TotalLoginCount__c
					+ totalCountsMap.get(loginFrequencyBeforeUpdate.CompositeKey__c);
			Assert.areEqual(expectedUniqueCount, loginFrequencyAfterUpdate.UniqueLoginCount__c, 'Unique count is not updated correctly');
			Assert.areEqual(expectedTotalCount, loginFrequencyAfterUpdate.TotalLoginCount__c, 'Total login count is not updated correctly');
		}
	}

	/**
	 * @description Tests that null input is handled gracefully without errors.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldHandleNullInput()
	{
		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(null);

		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();

		Assert.isTrue(results.isEmpty(), 'Should not create any LoginFrequency records');
	}

	/**
	 * @description Tests that multiple logins on the same calendar day (UTC) count as a single unique day.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldCountMultipleSameDayLoginsAsSingleUniqueDay()
	{
		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>
		{
				createDto(RUNNING_USER_ID, '2022-05-05T09:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-05-05T13:30:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-05-05T17:45:00.000+0000')
		};

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(dtoLoginHistories);

		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();

		Assert.areEqual(1, results.size(), 'Should create one LoginFrequency record');
		Assert.areEqual(3, results[0].TotalLoginCount__c, 'Should count all three logins');
		Assert.areEqual(1, results[0].UniqueLoginCount__c, 'Same-day logins should count as one unique day');
	}

	/**
	 * @description Tests that logins on distinct calendar days (UTC) each count as a unique day.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldCountEachDistinctDayAsUnique()
	{
		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>
		{
				createDto(RUNNING_USER_ID, '2022-05-01T10:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-05-15T10:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-05-28T10:00:00.000+0000')
		};

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(dtoLoginHistories);

		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();

		Assert.areEqual(1, results.size(), 'Should create one LoginFrequency record');
		Assert.areEqual(3, results[0].TotalLoginCount__c, 'Should count all three logins');
		Assert.areEqual(3, results[0].UniqueLoginCount__c, 'Different-day logins should each count as unique');
	}

	/**
	 * @description Tests that logins spanning a month boundary create separate LoginFrequency__c records
	 * with correct LoginMonth__c and LoginYear__c fields.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldCreateSeparateRecordsForDifferentMonths()
	{
		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>
		{
				createDto(RUNNING_USER_ID, '2022-05-15T10:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-06-15T10:00:00.000+0000')
		};

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(dtoLoginHistories);

		List<LoginFrequency__c> results = queryLoginFrequenciesWithMonthAndYear();
		Map<String, LoginFrequency__c> resultsByKey = toMapByCompositeKey(results);

		Assert.areEqual(2, results.size(), 'Should create two LoginFrequency records');

		LoginFrequency__c mayRecord = resultsByKey.get(RUNNING_USER_ID + '_2022-05');
		LoginFrequency__c juneRecord = resultsByKey.get(RUNNING_USER_ID + '_2022-06');

		Assert.isNotNull(mayRecord, 'Should create record for May');
		Assert.areEqual(5, mayRecord.LoginMonth__c, 'May record should have month 5');
		Assert.areEqual(2022, mayRecord.LoginYear__c, 'May record should have year 2022');

		Assert.isNotNull(juneRecord, 'Should create record for June');
		Assert.areEqual(6, juneRecord.LoginMonth__c, 'June record should have month 6');
		Assert.areEqual(2022, juneRecord.LoginYear__c, 'June record should have year 2022');
	}

	/**
	 * @description Tests that logins spanning a year boundary create separate LoginFrequency__c records
	 * with correct year values.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldCreateSeparateRecordsAcrossYearBoundary()
	{
		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>
		{
				createDto(RUNNING_USER_ID, '2022-12-15T10:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2023-01-15T10:00:00.000+0000')
		};

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(dtoLoginHistories);

		List<LoginFrequency__c> results = queryLoginFrequenciesWithMonthAndYear();
		Map<String, LoginFrequency__c> resultsByKey = toMapByCompositeKey(results);

		Assert.areEqual(2, results.size(), 'Should create two LoginFrequency records');

		LoginFrequency__c decemberRecord = resultsByKey.get(RUNNING_USER_ID + '_2022-12');
		LoginFrequency__c januaryRecord = resultsByKey.get(RUNNING_USER_ID + '_2023-01');

		Assert.isNotNull(decemberRecord, 'Should create record for December 2022');
		Assert.areEqual(12, decemberRecord.LoginMonth__c, 'December record should have month 12');
		Assert.areEqual(2022, decemberRecord.LoginYear__c, 'December record should have year 2022');

		Assert.isNotNull(januaryRecord, 'Should create record for January 2023');
		Assert.areEqual(1, januaryRecord.LoginMonth__c, 'January record should have month 1');
		Assert.areEqual(2023, januaryRecord.LoginYear__c, 'January record should have year 2023');
	}

	/**
	 * @description Tests that a single batch chunk correctly handles a mix of new and existing
	 * LoginFrequency__c records, creating some and updating others.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldHandleMixedCreateAndUpdate()
	{
		String mayKey = RUNNING_USER_ID + '_2022-05';

		TST_Builder.of(LoginFrequency__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						LoginFrequency__c.TotalLoginCount__c => 5,
						LoginFrequency__c.UniqueLoginCount__c => 3,
						LoginFrequency__c.CompositeKey__c => mayKey,
						LoginFrequency__c.User__c => RUNNING_USER_ID
				})
				.build();

		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>
		{
				createDto(RUNNING_USER_ID, '2022-05-20T10:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-06-10T10:00:00.000+0000')
		};

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(dtoLoginHistories);

		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();
		Map<String, LoginFrequency__c> resultsByKey = toMapByCompositeKey(results);

		Assert.areEqual(2, results.size(), 'Should have two LoginFrequency records');

		LoginFrequency__c updatedMay = resultsByKey.get(mayKey);

		Assert.areEqual(6, updatedMay.TotalLoginCount__c, 'May total should be incremented from 5 to 6');
		Assert.areEqual(4, updatedMay.UniqueLoginCount__c, 'May unique should be incremented from 3 to 4');

		LoginFrequency__c createdJune = resultsByKey.get(RUNNING_USER_ID + '_2022-06');

		Assert.isNotNull(createdJune, 'Should create record for June');
		Assert.areEqual(1, createdJune.TotalLoginCount__c, 'June total should be 1');
		Assert.areEqual(1, createdJune.UniqueLoginCount__c, 'June unique should be 1');
	}

	/**
	 * @description Tests that processing the same user and month across two separate chunks
	 * correctly increments the existing record on the second invocation.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldIncrementCountsAcrossMultipleChunks()
	{
		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> firstChunk = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>
		{
				createDto(RUNNING_USER_ID, '2022-05-05T09:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-05-05T14:00:00.000+0000')
		};

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(firstChunk);

		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> secondChunk = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>
		{
				createDto(RUNNING_USER_ID, '2022-05-10T09:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-05-10T15:00:00.000+0000'),
				createDto(RUNNING_USER_ID, '2022-05-20T11:00:00.000+0000')
		};

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(secondChunk);

		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();

		Assert.areEqual(1, results.size(), 'Should have one LoginFrequency record after two chunks');
		Assert.areEqual(5, results[0].TotalLoginCount__c, 'Total should be sum of both chunks (2 + 3)');
		Assert.areEqual(3, results[0].UniqueLoginCount__c, 'Unique should be sum of unique days per chunk (1 + 2)');
	}

	/**
	 * @description Tests that logins just before and after UTC midnight are counted as separate unique days.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void shouldDistinguishLoginDaysAtUtcMidnightBoundary()
	{
		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>
		{
				createDto(RUNNING_USER_ID, '2022-05-05T23:59:59.000+0000'),
				createDto(RUNNING_USER_ID, '2022-05-06T00:00:01.000+0000')
		};

		PROC_LoginFrequencyAggregator.generateAndStoreLoginFrequencies(dtoLoginHistories);

		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();

		Assert.areEqual(1, results.size(), 'Should create one LoginFrequency record for same month');
		Assert.areEqual(2, results[0].TotalLoginCount__c, 'Should count both logins');
		Assert.areEqual(2, results[0].UniqueLoginCount__c, 'Logins spanning UTC midnight should be two unique days');
	}

	private static List<LoginFrequency__c> queryLoginFrequenciesWithMonthAndYear()
	{
		return QRY_Builder.selectFrom(LoginFrequency__c.SObjectType)
				.fields(new List<SObjectField>
				{
						LoginFrequency__c.LoginMonth__c,
						LoginFrequency__c.LoginYear__c,
						LoginFrequency__c.TotalLoginCount__c,
						LoginFrequency__c.UniqueLoginCount__c,
						LoginFrequency__c.CompositeKey__c
				})
				.withSystemMode()
				.toList();
	}

	private static PROC_LoginFrequencyAggregator.DTO_LoginHistory createDto(Id userId, String isoTimestamp)
	{
		PROC_LoginFrequencyAggregator.DTO_LoginHistory dto = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		dto.userId = userId;
		dto.loginTime = UTIL_Date.dateTimeFromIso8601(isoTimestamp);
		return dto;
	}

	private static Map<String, LoginFrequency__c> toMapByCompositeKey(List<LoginFrequency__c> records)
	{
		Map<String, LoginFrequency__c> resultMap = new Map<String, LoginFrequency__c>();

		for(LoginFrequency__c record : records)
		{
			resultMap.put(record.CompositeKey__c, record);
		}

		return resultMap;
	}

	private static Set<String> getConcatenatedStrings(List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> loginHistories)
	{
		Set<String> concatenatedStrings = new Set<String>();

		for(PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory : loginHistories)
		{
			String concatenatedUserIdAndLoginMonth = loginHistory.userId + PROC_LoginFrequencyAggregator.UNDERSCORE + loginHistory.loginTime.formatGmt('yyyy-MM');
			concatenatedStrings.add(concatenatedUserIdAndLoginMonth);
		}
		return concatenatedStrings;
	}
}