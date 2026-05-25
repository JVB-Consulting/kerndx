// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Fetches a post from JSONPlaceholder by ID.
 *
 * @see API_GetPost_TEST
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
public with sharing class API_GetPost extends kern.API_Outbound
{
	/**
	 * @description Parameter name for the post ID.
	 */
	@TestVisible
	private static final String PARAM_POST_ID = 'postId';

	/**
	 * @description Initializes DTOs, mock body, and configuration.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"userId": 1, "id": 1, "title": "Mock Post Title", "body": "Mock post body"}';
		requiresTriggeringRecord = false;
	}

	/**
	 * @description Overrides HTTP method to GET (default is POST).
	 *
	 * @return The HTTP method for this service.
	 */
	public override kern.API_Base.HttpMethod getHttpMethod()
	{
		return kern.API_Base.HttpMethod.GET;
	}

	/**
	 * @description Appends the post ID to the endpoint path.
	 *
	 * @return The full endpoint URL.
	 */
	public override String getWebServiceEndPoint()
	{
		return super.getWebServiceEndPoint() + '/' + inputs.get(PARAM_POST_ID);
	}

	/**
	 * @description Registers required input parameters.
	 *
	 * @return The set of required parameter names.
	 */
	public override Set<String> getRequiredInputs()
	{
		Set<String> requiredInputs = super.getRequiredInputs();
		requiredInputs.add(PARAM_POST_ID);
		return requiredInputs;
	}

	/**
	 * @description Validates that the post ID is a positive integer.
	 *
	 * @return A list of validation error messages. Empty list means validation passed.
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		String postId = inputs.get(PARAM_POST_ID);

		if(!postId.isNumeric())
		{
			errors.add('Post ID must be a numeric value');
		}

		return errors;
	}

	/**
	 * @description Request DTO (empty for GET requests -- parameters go in the URL).
	 */
	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Request extends kern.DTO_JsonBase
	{
	}

	/**
	 * @description Response DTO matching the JSONPlaceholder post schema.
	 */
	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Response extends kern.DTO_JsonBase
	{
		/**
		 * @description The user who created the post.
		 */
		private Integer userId;

		/**
		 * @description The post ID.
		 */
		private Integer id;

		/**
		 * @description The post title.
		 */
		private String title;

		/**
		 * @description The post body text.
		 */
		private String body;

		/**
		 * @description Returns the Type used for deserialization.
		 *
		 * @return The DTO_Response Type.
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}
}
