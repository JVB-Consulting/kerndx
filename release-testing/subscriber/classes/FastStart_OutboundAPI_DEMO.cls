// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Drift-guard demo for the Fast Start - Outbound APIs guide. Fetches a single post from
 * JSONPlaceholder by ID, demonstrating the core outbound handler pattern: typed DTOs, parameter
 * validation, and the {@code getHttpMethod()} override that sets the HTTP verb for outbound calls.
 *
 * <p>This class uses {@code public with sharing} and is invoked directly by
 * {@link FastStart_OutboundAPI_DEMO_TEST} via {@code kern.UTIL_HttpClient.useHandler()} rather than
 * through the Type Resolver, so no Type Resolver class is required.
 *
 * @see FastStart_OutboundAPI_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_OutboundAPI_DEMO extends kern.API_Outbound
{
	/**
	 * @description Parameter name for the post ID to fetch.
	 */
	@TestVisible
	private static final String PARAM_POST_ID = 'postId';

	/**
	 * @description Validation error message when the post ID is not numeric.
	 */
	@TestVisible
	private static final String ERROR_POST_ID_NOT_NUMERIC = 'Post ID must be a numeric value';

	/**
	 * @description Initialises DTOs, the default mock body, and disables the triggering-record
	 * requirement. Always call {@code super.configure()} first so the framework sets its defaults
	 * before this override applies changes.
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
	 * @description Overrides the HTTP verb to GET. The default for all outbound handlers is POST.
	 * This override -- not {@code kern__Method__c} on ApiSetting__mdt -- is what the framework reads
	 * when building the outbound HTTP request.
	 *
	 * @return {@code kern.API_Base.HttpMethod.GET}
	 */
	public override kern.API_Base.HttpMethod getHttpMethod()
	{
		return kern.API_Base.HttpMethod.GET;
	}

	/**
	 * @description Appends the post ID path segment to the base endpoint from ApiSetting__mdt.
	 *
	 * @return The full endpoint path, e.g. {@code /posts/1}.
	 */
	public override String getWebServiceEndPoint()
	{
		return super.getWebServiceEndPoint() + '/' + inputs.get(PARAM_POST_ID);
	}

	/**
	 * @description Declares {@code postId} as a required input parameter. The framework aborts the
	 * call and records an Aborted status on the ApiCall__c record when any required input is absent.
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
	 * @description Validates that the post ID is a numeric string before the HTTP call is made.
	 * Business validation errors cause the call to be aborted without making a network request.
	 *
	 * @return A list of validation error messages. An empty list means validation passed.
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		String postId = inputs.get(PARAM_POST_ID);

		if(!postId.isNumeric())
		{
			errors.add(ERROR_POST_ID_NOT_NUMERIC);
		}

		return errors;
	}

	/**
	 * @description Request DTO for GET requests. No body fields are needed because all parameters
	 * travel in the URL path via {@code getWebServiceEndPoint()}.
	 *
	 * <p>{@code @JsonAccess} is required in managed package context: the framework serialises and
	 * deserialises DTOs from the {@code kern} namespace and needs explicit access grants.
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
		 * @description The ID of the user who created the post.
		 */
		private Integer userId;

		/**
		 * @description The post ID returned by the API.
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
		 * @description Returns the concrete type used by the framework to deserialise the response JSON.
		 *
		 * @return {@code DTO_Response.class}
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}
}
