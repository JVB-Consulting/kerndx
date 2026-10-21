// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-testing inbound handler that a test can put on hold. While an Account named RetryLive hold
 * exists, the handler fails every request on purpose. When no such Account exists, it answers status 200 with the body
 * it received. Section 84g calls it over REST through REST_RetryLiveOnHold: it puts the handler on hold, sends a
 * request that fails, takes the hold away, and sends the request again, so the second attempt succeeds.
 *
 * @see kern.API_Inbound
 * @see REST_RetryLiveOnHold
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
public inherited sharing class API_RetryLiveOnHold extends kern.API_Inbound
{
	/**
	 * @description The name of the Account that puts the handler on hold. Section 84g creates it and deletes it.
	 */
	public static final String HOLD_ACCOUNT_NAME = 'RetryLive hold';

	/**
	 * @description The message a request fails with while the handler is on hold. Section 84g looks for it in the answer.
	 */
	public static final String MESSAGE_ON_HOLD = 'RetryLiveOnHold: the service is on hold, so the request failed on purpose';

	/**
	 * @description Fails the request while the handler is on hold. Otherwise it does nothing, and the answer is the body
	 * the request carried.
	 */
	public override void processRequest()
	{
		if(isOnHold())
		{
			throw new RetryLiveOnHoldException(MESSAGE_ON_HOLD);
		}
	}

	/**
	 * @description Answers with the exact body the request carried.
	 */
	public override void updateCallResult()
	{
		super.updateCallResult();
		result.responseBody = requestBody;
	}

	/**
	 * @description Checks whether the Account that puts the handler on hold exists.
	 *
	 * @return True while an Account named RetryLive hold exists.
	 */
	private static Boolean isOnHold()
	{
		return kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Id})
				.condition(Account.Name).equals(HOLD_ACCOUNT_NAME)
				.getFirst() != null;
	}

	/**
	 * @description The exception a request fails with while the handler is on hold.
	 */
	public class RetryLiveOnHoldException extends Exception
	{
	}
}
