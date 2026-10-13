// SPDX-License-Identifier: BUSL-1.1
/**
 * @description This is an example Outbound API call; that hits actual example service
 *
 * @see API_PostExample_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
public inherited sharing class API_PostExample extends API_Outbound
{
	/**
	 * @description The name of the title property in the request and response JSON. Nothing in this class reads it; it is visible to
	 * tests so they can name the property without repeating the literal.
	 */
	@TestVisible
	private static final String TITLE_FIELD_NAME = 'title';
	/**
	 * @description The name of the caller-supplied parameter whose value becomes the request title. Visible to tests so they can
	 * supply the parameter under the same name the request reads.
	 */
	@TestVisible
	private static final String PARAMETER_NAME = 'foo';

	/**
	 * @description Simulated validation error for testing subscriber validation in API_Base.
	 */
	@TestVisible
	private static String simulatedValidationError;

	/**
	 * @description When true, getValidationErrors() throws to test the base class exception handler.
	 */
	@TestVisible
	private static Boolean simulateValidationThrow = false;

	/**
	 * @description Override to set your request and response DTO types and any other globals you may have
	 */
	public override void configure()
	{
		super.configure();

		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"body": "Some Random Body","id": 101,"title": "{{request.title}}","userId": 9}';
	}

	/**
	 * @description Returns subscriber-level validation errors.
	 *
	 * @return A list of error messages. Empty list means validation passed.
	 */
	public override List<String> getValidationErrors()
	{
		if(simulateValidationThrow)
		{
			throw new UTIL_Exceptions.IllegalStateException('Simulated validation exception');
		}
		List<String> errors = new List<String>();
		if(String.isNotBlank(simulatedValidationError))
		{
			errors.add(simulatedValidationError);
		}
		return errors;
	}

	/**
	 * @description Example request object that can serialize to Json
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class DTO_Request extends DTO_JsonBase
	{
		/**
		 * @description The body text sent to the example service. Given a random value when the request is populated.
		 */
		private String body;
		/**
		 * @description The title sent to the example service: the value of the PARAMETER_NAME parameter when the caller supplied
		 * parameters, otherwise the record Id.
		 */
		private String title;
		/**
		 * @description The user number sent to the example service. Given a random value when the request is populated.
		 */
		private Integer userId;

		/**
		 * @description Runs the base population for the record, then gives the user id and body random values so every example call
		 * carries a distinct payload.
		 *
		 * @param recordId The Id of the record the request is built from.
		 */
		public override void populate(Id recordId)
		{
			super.populate(recordId);

			userId = UTIL_Random.randomInteger();
			body = UTIL_Random.randomDescription();
		}

		/**
		 * @description Runs the base population for the record and parameters, then takes the title from the PARAMETER_NAME parameter
		 * when the caller supplied any parameters and falls back to the record Id otherwise.
		 *
		 * @param recordId The Id of the record the request is built from.
		 * @param dtoRequestParameters The name-value parameters supplied by the caller; may be empty.
		 */
		public override void populate(Id recordId, DTO_NameValues dtoRequestParameters)
		{
			super.populate(recordId, dtoRequestParameters);

			title = !dtoRequestParameters.isEmpty() ? dtoRequestParameters.get(PARAMETER_NAME) : recordId;
		}
	}

	/**
	 * @description Example Response which can serialize to Json
	 */
	@SuppressWarnings('ApexUnusedDeclaration,ApexControlFlowAnalysis')
	public class DTO_Response extends DTO_JsonBase
	{
		/**
		 * @description The body text the example service returned. Filled when the response JSON is read; nothing in this class reads it.
		 */
		private String body;
		/**
		 * @description The title the example service returned. Filled when the response JSON is read; nothing in this class reads it.
		 */
		private String title;
		/**
		 * @description The user number the example service returned. Filled when the response JSON is read; nothing in this class reads it.
		 */
		private Integer userId;
		/**
		 * @description The number the example service gave the post it created. Filled when the response JSON is read; nothing in this
		 * class reads it.
		 */
		private Integer id;

		/**
		 * @description The Type of the DTO used when deserializing the class
		 *
		 * @return Class of the DTO
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}

}