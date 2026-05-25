// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for `CTRL_FeatureFlag` — verifies the LWC bridge resolves to a concrete
 * Boolean for known feature-flag state and preserves the `cacheable=true` annotation that the
 * `c/featureFlag` wire adapter depends on. Tests configure flag state via `SEL_FeatureFlag.activeFlags`
 * (the same injection pattern used by `UTIL_FeatureFlag_TEST`) so the assertion is anchored on a
 * known expected value rather than mirroring whatever `UTIL_FeatureFlag.isEnabled` returns.
 *
 * @see CTRL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class CTRL_FeatureFlag_TEST
{
	/**
	 * @description Developer name of a flag that is not configured in the org — exercises the no-match path.
	 */
	private static final String NONEXISTENT_FLAG = 'NonexistentFlag_NeverConfigured';

	/**
	 * @description Annotation contract the `c/featureFlag` wire adapter depends on.
	 */
	private static final String CACHEABLE_ANNOTATION = '@AuraEnabled(cacheable=true)';

	/**
	 * @description Tests that the LWC bridge returns `true` when the flag is configured to enabled
	 * via `IsEnabledByDefault__c = true` and no strategies are present. Anchors the assertion on a
	 * concrete expected Boolean rather than mirroring `UTIL_FeatureFlag.isEnabled`.
	 *
	 * @see CTRL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void shouldReturnTrueWhenFlagEnabled()
	{
		FeatureFlag__mdt enabledFlag = new FeatureFlag__mdt();
		enabledFlag.IsActive__c = true;
		enabledFlag.IsEnabledByDefault__c = true;
		enabledFlag.ResultOnNoMatch__c = false;
		SEL_FeatureFlag.activeFlags.put(SEL_FeatureFlag.TEST_FEATURE_FLAG, enabledFlag);

		Test.startTest();
		Boolean bridgeResult = CTRL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		Test.stopTest();

		Assert.isTrue(bridgeResult, 'Bridge must return true for a flag with IsEnabledByDefault__c = true and no strategies');
	}

	/**
	 * @description Tests that the LWC bridge returns `false` when the flag is configured to disabled
	 * via `IsEnabledByDefault__c = false` and no strategies are present.
	 *
	 * @see CTRL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void shouldReturnFalseWhenFlagDisabled()
	{
		FeatureFlag__mdt disabledFlag = new FeatureFlag__mdt();
		disabledFlag.IsActive__c = true;
		disabledFlag.IsEnabledByDefault__c = false;
		disabledFlag.ResultOnNoMatch__c = false;
		SEL_FeatureFlag.activeFlags.put(SEL_FeatureFlag.TEST_FEATURE_FLAG, disabledFlag);

		Test.startTest();
		Boolean bridgeResult = CTRL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		Test.stopTest();

		Assert.isFalse(bridgeResult, 'Bridge must return false for a flag with IsEnabledByDefault__c = false and no strategies');
	}

	/**
	 * @description Tests that the LWC bridge returns `false` for a flag DeveloperName that is not
	 * configured in the org. `UTIL_FeatureFlag.isEnabled(null)` resolves to `false` regardless of
	 * `ResultOnNoMatch__c` because the flag record itself is absent from the active-flag cache.
	 *
	 * @see CTRL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void shouldReturnFalseWhenFlagMissing()
	{
		SEL_FeatureFlag.activeFlags.remove(NONEXISTENT_FLAG);

		Test.startTest();
		Boolean bridgeResult = CTRL_FeatureFlag.isEnabled(NONEXISTENT_FLAG);
		Test.stopTest();

		Assert.isFalse(bridgeResult, 'Bridge must return false for a missing flag (flag is null in cache)');
	}

	/**
	 * @description Marker test that asserts `CTRL_FeatureFlag.isEnabled` retains its `@AuraEnabled(cacheable=true)`
	 * annotation. The `c/featureFlag` wire adapter and any subscriber `@wire`-bound consumer relies on the
	 * cacheable contract; dropping it silently breaks LWC consumers without compile-time signal. This test
	 * queries the deployed `ApexClass.Body` and fails if the annotation is absent. The check only runs
	 * in source-org context — `ApexClass.Body` is hidden when this class is installed as a managed
	 * package, so subscribers running the same test would always see an empty body and false negative.
	 *
	 * @see CTRL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void shouldBeAnnotatedCacheable()
	{
		if(String.isNotBlank(UTIL_System.getManagedPackageNamespacePrefix()))
		{
			return;
		}

		Test.startTest();
		List<ApexClass> classes =
		[
				SELECT Body
				FROM ApexClass
				WHERE Name = 'CTRL_FeatureFlag'
				LIMIT 1
		];
		Test.stopTest();

		Assert.isFalse(classes.isEmpty(), 'CTRL_FeatureFlag class should exist as ApexClass');
		String body = classes.iterator().next().Body;
		Assert.isNotNull(body, 'CTRL_FeatureFlag.Body must be queryable from current org context');
		Assert.isTrue(body.contains(CACHEABLE_ANNOTATION),
				'CTRL_FeatureFlag.isEnabled must retain @AuraEnabled(cacheable=true) — c/featureFlag wire adapter depends on it');
	}
}