// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-testing outbound handler that sends a GET to a Named Credential that does not exist, so every send
 * fails at the send point with the platform's own refusal. A GET is safe to repeat, so the failed call is scheduled for a
 * retry. Section 84 and journey V158 use it.
 *
 * @see kern.API_Outbound
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
public inherited sharing class API_RetryLiveGet extends kern.API_Outbound
{
	/**
	 * @description Sets the payloads and clears the triggering-record requirement: the call is not about one record.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new RetryLivePayload();
		responsePayload = new RetryLivePayload();
		requiresTriggeringRecord = false;
	}

	/**
	 * @description A GET, so a repeat is safe.
	 *
	 * @return GET.
	 */
	public override kern.API_Base.HttpMethod getHttpMethod()
	{
		return kern.API_Base.HttpMethod.GET;
	}

	/**
	 * @description The payload both directions use; the call never gets an answer, so it carries nothing.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class RetryLivePayload extends kern.DTO_JsonBase
	{
	}
}
