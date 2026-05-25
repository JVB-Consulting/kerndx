// SPDX-License-Identifier: BUSL-1.1
/**
 * @description API to check if a password has been compromised using the [Pwned Passwords](https://haveibeenpwned.com/API/v3#PwnedPasswords) free service.
 * This class extends API_Outbound to perform HTTP GET requests to the Pwned Passwords API, checking if a password's SHA-1 hash appears in their dataset.
 *
 * @see API_GetPwndPasswords_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
public inherited sharing class API_GetPwndPasswords extends API_Outbound
{
	/**
	 * @description Length of the hash prefix used for querying the Pwned Passwords API.
	 */
	private static final Integer HASH_PREFIX_LENGTH = 5;

	/**
	 * @description Test password used for testing purposes.
	 */
	@TestVisible
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	private static final String TEST_PASSWORD = 'billybob';

	/**
	 * @description Required parameter key for the password to be checked.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String PARAMETER_PASSWORD = 'password';

	/**
	 * @description Indicates whether the password was found in the Pwned Passwords response suffixes.
	 */
	public Boolean passwordFound
	{
		get
		{
			return response.getBody()?.contains(UTIL_String.removeStart(hashedPassword, passwordHashPrefix)) == true;
		}
	}

	/**
	 * @description Retrieves the set of required inputs for the web service call.
	 *
	 * @return Set<String> The set of required input names, including PARAMETER_PASSWORD.
	 */
	public override Set<String> getRequiredInputs()
	{
		Set<String> requiredInputs = super.getRequiredInputs();
		requiredInputs.add(PARAMETER_PASSWORD);
		return requiredInputs;
	}

	/**
	 * @description Specifies the HTTP method for the web service call.
	 *
	 * @return GET as the HTTP method.
	 */
	public override HttpMethod getHttpMethod()
	{
		return HttpMethod.GET;
	}

	/**
	 * @description Constructs the web service endpoint URL by formatting the base endpoint with the password hash prefix.
	 *
	 * @return String The formatted endpoint URL for the Pwned Passwords API.
	 */
	public override String getWebServiceEndPoint()
	{
		return String.format
				(
						super.getWebServiceEndPoint(),
						new List<String>
						{
								EncodingUtil.urlEncode(passwordHashPrefix, UTF8_ENCODING_SCHEME)
						}
				);
	}

	/**
	 * @description Initializes the API configuration, setting the mock type for testing.
	 */
	public override void configure()
	{
		super.configure();
		defaultMockBody =
				'003CD215739D7C1B2218670D26F81408237:1\n' +
				'003D68EB55068C33ACE09247EE4C639306B:4\n' +
				'012C192B2F16F82EA0EB9EF18D9D539B0DD:3\n' +
				'01330C689E5D64F660D6947A93AD634EF8F:1\n' +
				'0161D96B45F0098840A638034BF2A2986F7:1\n' +
				'0198748F3315F40B1A102BF18EEA0194CD9:2\n' +
				'01F9033B3C00C65DBFD6D1DC4D22918F5E9:4\n' +
				'34ABB0B33A02C947A09D03FEBB151E998F6:47645';
		requiresTriggeringRecord = false;
	}

	/**
	 * @description Computes the SHA-1 hash of the provided password.
	 *
	 * @see UTIL_Crypto.generateSHA1Hash
	 */
	private String hashedPassword
	{
		get
		{
			if(String.isBlank(hashedPassword))
			{
				hashedPassword = UTIL_Crypto.generateSHA1Hash(inputs.get(PARAMETER_PASSWORD))?.toUpperCase();
			}
			return hashedPassword;
		}
		set;
	}

	/**
	 * @description Provides the prefix of the password hash used for querying the Pwned Passwords API.
	 */
	@SuppressWarnings('ApexControlFlowAnalysis')
	private String passwordHashPrefix
	{
		get
		{
			return UTIL_String.left(hashedPassword, HASH_PREFIX_LENGTH);
		}
	}

	/**
	 * @description Sets the HTTP headers for the web service call, including the User-Agent header with the organization name.
	 */
	public override void setHeaders()
	{
		super.setHeaders();
		request.setHeader(HTTP_HEADER_USER_AGENT, UserInfo.getOrganizationName());
	}

}