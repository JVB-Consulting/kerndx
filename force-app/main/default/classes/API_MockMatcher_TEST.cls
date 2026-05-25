// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for API_MockMatcher pattern matching utility.
 *
 * @see API_MockMatcher
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class API_MockMatcher_TEST
{
	/**
	 * @description Tests that a mock without a pattern matches any request body.
	 */
	@IsTest
	private static void shouldMatchWhenNoPatternDefined()
	{
		ApiMock__mdt mock = new ApiMock__mdt(MatchRequestBodyPattern__c = null, IsRegex__c = false);

		Boolean result = API_MockMatcher.matches(mock, '{"any":"body"}');

		Assert.isTrue(result, 'Should match when no pattern is defined');
	}

	/**
	 * @description Tests that a mock with a pattern does not match a blank request body.
	 */
	@IsTest
	private static void shouldNotMatchWhenRequestBodyIsBlank()
	{
		ApiMock__mdt mock = new ApiMock__mdt(MatchRequestBodyPattern__c = 'somePattern', IsRegex__c = false);

		Boolean result = API_MockMatcher.matches(mock, '');

		Assert.isFalse(result, 'Should not match when request body is blank');
	}

	/**
	 * @description Tests case-insensitive contains matching.
	 */
	@IsTest
	private static void shouldMatchContainsIgnoreCase()
	{
		ApiMock__mdt mock = new ApiMock__mdt(MatchRequestBodyPattern__c = 'invoice', IsRegex__c = false);

		Boolean result = API_MockMatcher.matches(mock, '{"type":"INVOICE","id":"123"}');

		Assert.isTrue(result, 'Should match case-insensitive contains');
	}

	/**
	 * @description Tests that contains matching returns false when pattern is not found.
	 */
	@IsTest
	private static void shouldNotMatchContainsWhenAbsent()
	{
		ApiMock__mdt mock = new ApiMock__mdt(MatchRequestBodyPattern__c = 'notfound', IsRegex__c = false);

		Boolean result = API_MockMatcher.matches(mock, '{"type":"Invoice"}');

		Assert.isFalse(result, 'Should not match when pattern is absent');
	}

	/**
	 * @description Tests regex pattern matching.
	 */
	@IsTest
	private static void shouldMatchRegexPattern()
	{
		ApiMock__mdt mock = new ApiMock__mdt(MatchRequestBodyPattern__c = '"id":\\s*"\\d+"', IsRegex__c = true);

		Boolean result = API_MockMatcher.matches(mock, '{"id": "12345"}');

		Assert.isTrue(result, 'Should match regex pattern');
	}

	/**
	 * @description Tests that an invalid regex pattern returns false.
	 */
	@IsTest
	private static void shouldReturnFalseForInvalidRegex()
	{
		ApiMock__mdt mock = new ApiMock__mdt(MatchRequestBodyPattern__c = '[invalid(', IsRegex__c = true);

		Boolean result = API_MockMatcher.matches(mock, '{"data":"test"}');

		Assert.isFalse(result, 'Should return false for invalid regex');
	}

	/**
	 * @description Tests that regex falls back to contains for payloads exceeding the size limit.
	 */
	@IsTest
	private static void shouldFallBackToContainsForLargePayload()
	{
		ApiMock__mdt mock = new ApiMock__mdt(MatchRequestBodyPattern__c = 'searchterm', IsRegex__c = true);
		String largePayload = 'searchterm' + 'x'.repeat(40000);

		Boolean result = API_MockMatcher.matches(mock, largePayload);

		Assert.isTrue(result, 'Should fall back to contains for large payloads');
	}

	/**
	 * @description Tests exact path matching without wildcards.
	 */
	@IsTest
	private static void shouldMatchExactPath()
	{
		Boolean result = API_MockMatcher.matchesPath('/api/v1/accounts', '/api/v1/accounts');

		Assert.isTrue(result, 'Should match exact path');
	}

	/**
	 * @description Tests case-insensitive exact path matching.
	 */
	@IsTest
	private static void shouldMatchPathCaseInsensitive()
	{
		Boolean result = API_MockMatcher.matchesPath('/api/v1/Accounts', '/api/v1/accounts');

		Assert.isTrue(result, 'Should match path case-insensitive');
	}

	/**
	 * @description Tests wildcard path matching.
	 */
	@IsTest
	private static void shouldMatchWildcardPath()
	{
		Boolean result = API_MockMatcher.matchesPath('/api/v1/*', '/api/v1/accounts');

		Assert.isTrue(result, 'Should match wildcard path');
	}

	/**
	 * @description Tests that a wildcard path does not match a different prefix.
	 */
	@IsTest
	private static void shouldNotMatchDifferentPrefix()
	{
		Boolean result = API_MockMatcher.matchesPath('/api/v2/*', '/api/v1/accounts');

		Assert.isFalse(result, 'Should not match different path prefix');
	}

	/**
	 * @description Tests that blank paths return false.
	 */
	@IsTest
	private static void shouldReturnFalseForBlankPaths()
	{
		Assert.isFalse(API_MockMatcher.matchesPath('', '/api/v1/accounts'), 'Should return false for blank pattern');
		Assert.isFalse(API_MockMatcher.matchesPath('/api/v1/*', ''), 'Should return false for blank request path');
	}

	/**
	 * @description Tests that an invalid wildcard path pattern returns false.
	 */
	@IsTest
	private static void shouldReturnFalseForInvalidWildcardPattern()
	{
		Boolean result = API_MockMatcher.matchesPath('/api/[*', '/api/test');

		Assert.isFalse(result, 'Should return false for invalid wildcard pattern');
	}
}