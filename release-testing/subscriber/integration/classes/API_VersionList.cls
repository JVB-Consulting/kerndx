// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A handler with a canned answer and no credential of its own, used by the integration probe to show
 * that a handler run through the fluent client's delegation entry point makes its real call outside a unit test.
 * Its endpoint is the org's own REST API version list, which answers with no session.
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date September 2026
 */
public with sharing class API_VersionList extends kern.API_Outbound
{
	/**
	 * @description The REST API's version list, which answers with no session.
	 */
	private static final String ENDPOINT_PATH = '/services/data/';

	/**
	 * @description The answer a unit test of this handler receives instead of a real call.
	 */
	public static final String CANNED_BODY = '{"canned":true}';

	/**
	 * @description Declares the canned answer; the handler needs no triggering record.
	 */
	public override void configure()
	{
		super.configure();
		requiresTriggeringRecord = false;
		defaultMockBody = CANNED_BODY;
	}

	/**
	 * @description The version list is read with GET.
	 *
	 * @return The GET verb.
	 */
	public override kern.API_Base.HttpMethod getHttpMethod()
	{
		return kern.API_Base.HttpMethod.GET;
	}

	/**
	 * @description Points the call at the org's own version list, so no credential is needed.
	 *
	 * @return The version list URL on the org's domain.
	 */
	public override String getWebServiceEndPoint()
	{
		return Url.getOrgDomainUrl().toExternalForm() + ENDPOINT_PATH;
	}
}
