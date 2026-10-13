// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-testing inbound handler whose processing throws and whose own error handling throws too. The
 * framework must still answer the caller: status 500, with both messages in the body, and the call record ends Failed.
 * Section 84c calls it over REST through REST_RetryLiveInbound.
 *
 * @see kern.API_Inbound
 * @see REST_RetryLiveInbound
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
public inherited sharing class API_RetryLiveInbound extends kern.API_Inbound
{
	/**
	 * @description The message the processing fails with; section 84c looks for it in the answer.
	 */
	public static final String MESSAGE_PROCESSING_THREW = 'RetryLiveInbound: the processing threw on purpose';

	/**
	 * @description The message the error handling fails with; section 84c looks for it in the answer.
	 */
	public static final String MESSAGE_ERROR_HANDLING_THREW = 'RetryLiveInbound: the error handling threw on purpose';

	/**
	 * @description Sets the payloads.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new RetryLivePayload();
		responsePayload = new RetryLivePayload();
	}

	/**
	 * @description Throws while processing the request.
	 */
	public override void processRequest()
	{
		throw new RetryLiveException(MESSAGE_PROCESSING_THREW);
	}

	/**
	 * @description Throws while handling the failure, as a handler with a bug in its error handling would.
	 *
	 * @param error The exception the call failed with.
	 */
	public override void handleError(Exception error)
	{
		throw new RetryLiveException(MESSAGE_ERROR_HANDLING_THREW);
	}

	/**
	 * @description The exception both throws raise.
	 */
	public class RetryLiveException extends Exception
	{
	}

	/**
	 * @description The payload both directions use; the request body is ignored.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class RetryLivePayload extends kern.DTO_JsonBase
	{
	}
}
