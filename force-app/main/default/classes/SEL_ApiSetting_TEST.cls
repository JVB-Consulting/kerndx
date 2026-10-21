// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ApiSetting selector.
 *
 * @see SEL_ApiSetting
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ApiSetting_TEST
{
	/**
	 * @description A service name that no API setting names.
	 */
	private static final String SERVICE_WITH_NO_SETTING = 'ServiceWithNoSetting';

	/**
	 * @description Tests that findByClassName returns null for non-existent class.
	 */
	@IsTest
	private static void shouldReturnNullForNonExistentClassName()
	{
		ApiSetting__mdt result = new SEL_ApiSetting().findByClassName('NonExistentClass');

		Assert.isNull(result, 'Should return null for non-existent class');
	}

	/**
	 * @description Tests that findActiveInboundRoutes returns a list without errors.
	 */
	@IsTest
	private static void shouldReturnActiveInboundRoutes()
	{
		List<ApiSetting__mdt> results = new SEL_ApiSetting().findActiveInboundRoutes();

		Assert.isNotNull(results, 'Should return a non-null list');
	}

	/**
	 * @description Tests that findActiveByDirection returns a list without errors.
	 */
	@IsTest
	private static void shouldReturnActiveByDirection()
	{
		List<ApiSetting__mdt> results = new SEL_ApiSetting().findActiveByDirection(SEL_ApiSetting.DIRECTION_OUTBOUND);

		Assert.isNotNull(results, 'Should return a non-null list');
	}

	/**
	 * @description Tests that the class name of a service's setting is found from the service name, whatever the
	 * letter case of the service name, and that each of two settings gives its own class name.
	 */
	@IsTest
	private static void shouldFindTheClassNameForAServiceName()
	{
		String firstClassName = SEL_ApiSetting_TEST.class.getName();
		String secondClassName = SEL_ApiSetting.class.getName();
		TST_Factory.newOutboundApiSetting(firstClassName, null);
		TST_Factory.newOutboundApiSetting(secondClassName, null);

		String first = SEL_ApiSetting.findClassNameByServiceName(firstClassName.toUpperCase());
		String second = SEL_ApiSetting.findClassNameByServiceName(secondClassName);

		Assert.areEqual(firstClassName, first, 'Expected the class name of the first setting, got ' + first);
		Assert.areEqual(secondClassName, second, 'Expected the class name of the second setting, got ' + second);
	}

	/**
	 * @description Tests that a service name written with the package namespace finds the setting whose class name
	 * has none, so both forms name the same handler.
	 */
	@IsTest
	private static void shouldFindTheClassNameForAServiceNameWithThePackageNamespace()
	{
		String className = SEL_ApiSetting_TEST.class.getName().removeStart(UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT));
		TST_Factory.newOutboundApiSetting(className, null);

		String found = SEL_ApiSetting.findClassNameByServiceName(UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT) + className);

		Assert.areEqual(className, found, 'Expected the class name of the setting, got ' + found);
	}

	/**
	 * @description Tests that a service with no setting, and a blank service name, give the empty string, which means
	 * no caller.
	 */
	@IsTest
	private static void shouldAnswerEmptyForAServiceWithNoSetting()
	{
		TST_Factory.newOutboundApiSetting(SEL_ApiSetting_TEST.class.getName(), null);

		String unknown = SEL_ApiSetting.findClassNameByServiceName(SERVICE_WITH_NO_SETTING);
		String blank = SEL_ApiSetting.findClassNameByServiceName(null);

		Assert.areEqual(UTIL_String.EMPTY, unknown, 'Expected no class name for a service with no setting, got ' + unknown);
		Assert.areEqual(UTIL_String.EMPTY, blank, 'Expected no class name for a blank service name, got ' + blank);
	}

	/**
	 * @description Tests that the settings are read once per transaction: after the first answer, a read that would
	 * fail does not change the later answers, because they come from memory.
	 */
	@IsTest
	private static void shouldReadTheSettingsOncePerTransaction()
	{
		String className = SEL_ApiSetting_TEST.class.getName();
		TST_Factory.newOutboundApiSetting(className, null);
		SEL_ApiSetting.findClassNameByServiceName(className);
		TST_Mock.throwsException(ApiSetting__mdt.SObjectType);

		String found = SEL_ApiSetting.findClassNameByServiceName(className);

		Assert.areEqual(className, found, 'Expected the answer from the settings read on the first call, got ' + found);
	}

	/**
	 * @description Tests that settings that cannot be read give the empty string for every service, so API calls and
	 * issues are masked for no caller instead of failing their save.
	 */
	@IsTest
	private static void shouldAnswerEmptyWhenTheSettingsCannotBeRead()
	{
		TST_Mock.throwsException(ApiSetting__mdt.SObjectType);

		String found = SEL_ApiSetting.findClassNameByServiceName(SEL_ApiSetting_TEST.class.getName());

		Assert.areEqual(UTIL_String.EMPTY, found, 'Expected no class name when the settings cannot be read, got ' + found);
	}
}