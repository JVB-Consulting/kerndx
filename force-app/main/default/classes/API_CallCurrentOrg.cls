// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base API class for all handlers that call the current Org standard APIs.
 * Uses session-ID-based authentication and resolves the org base URL dynamically
 * via URL.getOrgDomainURL(). Subscribers must add a Remote Site Setting for their
 * My Domain URL.
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * global class API_OrgMetadata extends API_CallCurrentOrg
 * {
 *     global override void configure()
 *     {
 *         super.configure();
 *         requestPayload = new DTO_Request();
 *         responsePayload = new DTO_Response();
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global virtual inherited sharing class API_CallCurrentOrg extends API_Outbound
{
	/**
	 * @description Initialises the handler and sets the base URL to the current org domain.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void configure()
	 * {
	 *     super.configure();
	 *     requestPayload = new DTO_Request();
	 * }
	 * ```
	 */
	global protected virtual override void configure()
	{
		super.configure();
		baseUrl = Url.getOrgDomainUrl().toExternalForm();
	}

	/**
	 * @description Will return the current session Id as authorisation token.
	 *
	 * @return Authorisation Header value
	 *
	 * @see UserInfo.getSessionId
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global class API_OrgMetadata extends API_CallCurrentOrg
	 * {
	 *     // Uses inherited getAuthorisationToken() which returns 'Bearer <sessionId>'
	 *     // to authenticate against the current org's REST API
	 * }
	 * ```
	 */
	global protected virtual override String getAuthorisationToken()
	{
		return HTTP_AUTH_TOKEN_BEARER + UTIL_System.getApiEnabledSessionId();
	}

	/**
	 * @description Constructs the full endpoint URL by combining the current org domain
	 * URL with the endpoint path from ApiSetting__mdt configuration.
	 *
	 * @return The full URL endpoint for the web service
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // With EndpointPath__c = '/services/data/v{0}/sobjects/StreamingChannel/{1}/push'
	 * // Returns: 'https://myorg.my.salesforce.com/services/data/v{0}/sobjects/StreamingChannel/{1}/push'
	 * ```
	 */
	global protected virtual override String getWebServiceEndPoint()
	{
		String orgBaseUrl = Url.getOrgDomainUrl().toExternalForm();
		String endpointPath = setting?.EndpointPath__c;

		return orgBaseUrl + (String.isNotBlank(endpointPath) ? endpointPath : UTIL_String.EMPTY);
	}
}