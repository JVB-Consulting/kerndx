// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-testing outbound handler that sends a POST with no Idempotency-Key to a Named Credential that does
 * not exist, so every send fails at the send point with the platform's own refusal. Such a request may have reached the
 * external system and is not safe to repeat, so the failed call ends Failed at once with an issue that says the external
 * system may have acted. Section 84 uses it.
 *
 * @see kern.API_Outbound
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
public inherited sharing class API_RetryLivePost extends kern.API_Outbound
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
	 * @description A POST, which is not safe to repeat without a key.
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
