// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Pattern matching utility for mock selection and route matching.
 *
 * @see API_MockMatcher_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
public inherited sharing class API_MockMatcher
{
	/**
	 * @description Maximum payload size for regex matching. Payloads exceeding this fall back to contains().
	 */
	private static final Integer MAX_REGEX_PAYLOAD_SIZE = 32768;

	/**
	 * @description Matches a mock's pattern against a request body.
	 *
	 * @param mock The mock metadata record with pattern configuration
	 * @param requestBody The request body to match against
	 *
	 * @return True if the pattern matches or no pattern is defined
	 */
	public static Boolean matches(ApiMock__mdt mock, String requestBody)
	{
		if(String.isBlank(mock.MatchRequestBodyPattern__c))
		{
			return true;
		}

		if(String.isBlank(requestBody))
		{
			return false;
		}

		String patternString = mock.MatchRequestBodyPattern__c;

		if(mock.IsRegex__c && requestBody.length() > MAX_REGEX_PAYLOAD_SIZE)
		{
			LOG_Builder.build().info(
					'Payload exceeds ' + MAX_REGEX_PAYLOAD_SIZE + ' bytes. Using contains() match.'
			).emitAt(API_MockMatcher.class.getName() + '.matches');
			return requestBody.containsIgnoreCase(patternString);
		}

		if(mock.IsRegex__c)
		{
			try
			{
				Pattern compiledPattern = Pattern.compile(patternString);
				return compiledPattern.matcher(requestBody).find();
			}
			catch(Exception regexError)
			{
				LOG_Builder.build().error(regexError).emitAt(API_MockMatcher.class.getName() + '.matches');
				return false;
			}
		}

		return requestBody.containsIgnoreCase(patternString);
	}

	/**
	 * @description Matches a URL path pattern against a request path.
	 *
	 * @param pathPattern The pattern (may contain * wildcards)
	 * @param requestPath The actual request path to match
	 *
	 * @return True if the path matches the pattern
	 */
	public static Boolean matchesPath(String pathPattern, String requestPath)
	{
		if(String.isBlank(pathPattern) || String.isBlank(requestPath))
		{
			return false;
		}

		if(!pathPattern.contains('*'))
		{
			return pathPattern.equalsIgnoreCase(requestPath);
		}

		try
		{
			String regexPattern = '(?i)' + pathPattern
					.replace('.', '\\.')
					.replace('*', '.*');

			return Pattern.compile(regexPattern).matcher(requestPath).matches();
		}
		catch(Exception compileError)
		{
			LOG_Builder.build().error(compileError).emitAt(API_MockMatcher.class.getName() + '.matchesPath');
			return false;
		}
	}

}