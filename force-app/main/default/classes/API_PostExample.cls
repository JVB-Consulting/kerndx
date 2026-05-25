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
 * @date February 2026, May 2026
 */
public inherited sharing class API_PostExample extends API_Outbound
{
	@TestVisible
	private static final String TITLE_FIELD_NAME = 'title';
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
	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Request extends DTO_JsonBase
	{
		private String body;
		private String title;
		private Integer userId;

		public override void populate(Id recordId)
		{
			super.populate(recordId);

			userId = UTIL_Random.randomInteger();
			body = UTIL_Random.randomDescription();
		}

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
		private String body;
		private String title;
		private Integer userId;
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