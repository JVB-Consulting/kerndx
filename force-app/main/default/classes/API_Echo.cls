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
 * @date February 2026, May 2026
 */
public inherited sharing class API_Echo extends API_Inbound
{
	@TestVisible
	private static Boolean simulatePostCommitProcessing = false;
	@TestVisible
	private static final String ERROR_NO_BODY_RECEIVED = 'No request body received';
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
	 * @description This method can be overridden by inheriting classes to update the response DTO
	 * with any relevant information before the response is sent. It is intended to allow
	 * customization of the response body data based on the request or processed results.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
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