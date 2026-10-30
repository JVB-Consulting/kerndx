// SPDX-License-Identifier: Apache-2.0
/**
 * @description Release-testing outbound handler that sends a POST to a Named Credential that does not exist, so every send
 * fails at the send point with the platform's own refusal. Its setting turns on Idempotency Enabled, so every attempt
 * carries an Idempotency-Key: the POST is safe to repeat and the failed call is scheduled for a retry. Section 84 uses it.
 *
 * @see kern.API_Outbound
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
public inherited sharing class API_RetryLiveKeyedPost extends kern.API_Outbound
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
	 * @description A POST; the key that makes it safe to repeat comes from the setting.
	 *
	 * @return POST.
	 */
	public override kern.API_Base.HttpMethod getHttpMethod()
	{
		return kern.API_Base.HttpMethod.POST;
	}

	/**
	 * @description The payload both directions use; the call never gets an answer, so it carries nothing.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class RetryLivePayload extends kern.DTO_JsonBase
	{
	}
}
