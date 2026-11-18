// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests the behavior of the {@link SEL_ScheduleSetting} class.
 *
 * @see SEL_ScheduleSetting
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SEL_ScheduleSetting_TEST
{
	/**
	 * @description Tests that getScheduleSetting returns null for a non-existent schedule name.
	 *
	 * @see SEL_ScheduleSetting.getScheduleSetting
	 */
	@IsTest
	private static void shouldReturnNullForNonExistentSchedule()
	{
		Test.startTest();

		ScheduleSetting__c result = SEL_ScheduleSetting.getScheduleSetting(UTIL_Random.randomName());

		Test.stopTest();

		Assert.isNull(result, 'Should return null when no matching schedule setting exists');
	}

	/**
	 * @description The locking read for a named setting reads the Schedule Setting object, filters on the Name field and
	 * ends with FOR UPDATE, so it locks the row it reads. Its SOQL equals the SOQL of the same read built step by step in this test.
	 *
	 * @see SEL_ScheduleSetting.buildLockingReadByName
	 */
	@IsTest
	private static void shouldBuildALockingReadForTheNamedSetting()
	{
		String scheduleName = UTIL_Random.randomName();
		String expectedSoql = QRY_Builder.selectFrom(ScheduleSetting__c.SObjectType)
				.systemModeInternal()
				.condition(ScheduleSetting__c.Name).equals(scheduleName)
				.forUpdate()
				.toSoql();

		Test.startTest();

		String soql = SEL_ScheduleSetting.buildLockingReadByName(scheduleName).toSoql();

		Test.stopTest();

		String upperCaseSoql = soql.toUpperCase();
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(ScheduleSetting__c.SObjectType).toUpperCase();
		String nameField = UTIL_SObjectDescribe.getCachedFieldName(ScheduleSetting__c.Name).toUpperCase();
		Assert.isTrue(upperCaseSoql.endsWith('FOR UPDATE'), 'Expected the read to lock the row, got ' + soql);
		Assert.isTrue(upperCaseSoql.contains('FROM ' + objectName), 'Expected the read to be from the Schedule Setting object, got ' + soql);
		Assert.isTrue(upperCaseSoql.contains('WHERE ' + nameField), 'Expected the read to filter on the Name field, got ' + soql);
		Assert.areEqual(expectedSoql, soql, 'Expected the same SOQL as the locking read built step by step in this test');
	}

	/**
	 * @description The locking read skips the running user's object and field permission checks (system mode). A user with
	 * the Minimum Access profile, who has no access to the Schedule Setting object, still reads and locks the saved setting.
	 *
	 * @see SEL_ScheduleSetting.buildLockingReadByName
	 */
	@IsTest
	private static void shouldReadTheLockedSettingForAUserWithoutAccessToTheObject()
	{
		String scheduleName = UTIL_Random.randomName();
		ScheduleSetting__c savedSetting = (ScheduleSetting__c)TST_Builder.of(ScheduleSetting__c.SObjectType)
				.withOverride(ScheduleSetting__c.Name, scheduleName)
				.build();
		List<ScheduleSetting__c> foundSettings;

		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_MINIMUM_ACCESS))
		{
			Test.startTest();

			foundSettings = SEL_ScheduleSetting.buildLockingReadByName(scheduleName).toList();

			Test.stopTest();
		}

		Assert.areEqual(1, foundSettings.size(), 'Expected exactly one setting to be read, got ' + foundSettings);
		Assert.areEqual(savedSetting.Id, foundSettings[0].Id, 'Expected the setting with the saved name to be read');
	}
}