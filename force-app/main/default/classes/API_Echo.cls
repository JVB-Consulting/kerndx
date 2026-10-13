// SPDX-License-Identifier: BUSL-1.1
/**
 * @description This is An example Inbound API call that will echo exactly what was sent
 *
 * @see API_Echo_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
public inherited sharing class API_Echo extends API_Inbound
{
	/**
	 * @description When a test sets this to true, updateResponseDTO throws after the base class has built the response, so the test can
	 * check what the framework does when a handler fails at that late step. It stays false outside tests.
	 */
	@TestVisible
	private static Boolean simulatePostCommitProcessing = false;
	/**
	 * @description The validation error returned when the request arrives with an empty body. There is nothing to echo back, so the
	 * call is rejected before it runs.
	 */
	@TestVisible
	private static final String ERROR_NO_BODY_RECEIVED = 'No request body received';
	/**
	 * @description The message of the exception thrown by updateResponseDTO when simulatePostCommitProcessing is true. Tests compare
	 * against it to prove the failure they see is the simulated one.
	 */
	@TestVisible
	private static final String ERROR_POST_COMMIT = 'Simulate Post Commit Error Processing';

	/**
	 * @description Validates if the API request should be allowed to run.
	 *
	 * @return A list of error messages. Empty list means validation passed.
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();

		if(String.isEmpty(requestBody))
		{
			errors.add(ERROR_NO_BODY_RECEIVED);
		}

		return errors;
	}

	/**
	 * @description sets response to the requestBody
	 */
	public override void updateCallResult()
	{
		super.updateCallResult();

		// ensure we echo back exactly what was sent
		result.responseBody = requestBody;
	}

	/**
	 * @description Keeps the response the base class builds, then throws when a test has set simulatePostCommitProcessing, so the
	 * test can see how the framework handles a handler that fails after the call has run.
	 */
	public override void updateResponseDTO()
	{
		super.updateResponseDTO();

		if(simulatePostCommitProcessing)
		{
			throw new IllegalArgumentException(ERROR_POST_COMMIT);
		}
	}

	/**
	 * @description Ensures that response Content-Type mimics that of the request Content-Type
	 */
	public override void writeResponse()
	{
		super.writeResponse();
		result.responseBody = responseBody;

		/* ensure we echo back the content type sent */
		response.headers.put(API_Base.HTTP_CONTENT_TYPE, getEncoding());
	}
}