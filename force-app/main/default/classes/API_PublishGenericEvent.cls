// SPDX-License-Identifier: BUSL-1.1
/**
 * @description This handler publishes a generic streaming event to a StreamingChannel
 * via the Salesforce REST API.
 *
 * @see API_PublishGenericEvent_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date November 2025, May 2026
 */
public inherited sharing class API_PublishGenericEvent extends API_CallCurrentOrg
{
	/**
	 * @description The string payload to publish.
	 */
	public static final String REQUIRED_PARAMETER_PAYLOAD = 'payload';

	/**
	 * @description Initialise the handler, setting up request/response DTOs and mock type.
	 */
	public override void configure()
	{
		super.configure();

		requestPayload = new DTO_Request();
		defaultMockBody = '[{"fanoutCount":0,"userOnlineStatus":{}}]';
	}

	/**
	 * @description Returns the set of required inputs needed to execute the request.
	 *
	 * @return A set of required input names
	 */
	public override Set<String> getRequiredInputs()
	{
		Set<String> parameters = super.getRequiredInputs();

		parameters.add(REQUIRED_PARAMETER_PAYLOAD);

		return parameters;
	}

	/**
	 * @description Method is use to return the URL of the web service.
	 * This assumes an ApiSetting__mdt record exists for this class
	 * with an EndpointPath__c like: /services/data/v{0}/sobjects/StreamingChannel/{1}/push
	 *
	 * @return the URL to use
	 */
	public override String getWebServiceEndPoint()
	{
		return
				String.format
						(
								super.getWebServiceEndPoint(),
								new List<String>
								{
										UTIL_System.getOrgApiVersion(),
										EncodingUtil.urlEncode(apiCall.TriggeringRecordId__c, UTF8_ENCODING_SCHEME)
								}
						);
	}

	/**
	 * @description DTO for the push request body.
	 */
	@JsonAccess(Serializable='always')
	public class DTO_Request extends DTO_JsonBase
	{
		/**
		 * @description The events to push for the given channel
		 */
		private List<DTO_PushEvent> pushEvents;

		/**
		 * @description Populate the request with relevant payload parameter
		 *
		 * @param recordId The channel for which this is required
		 * @param dtoRequestParameters The parameters provided
		 */
		public override void populate(Id recordId, DTO_NameValues dtoRequestParameters)
		{
			DTO_PushEvent event = new DTO_PushEvent();
			event.payload = dtoRequestParameters.get(REQUIRED_PARAMETER_PAYLOAD);
			pushEvents = new List<DTO_PushEvent> {event};
		}
	}

	/**
	 * @description Inner DTO for the pushEvent object.
	 */
	@JsonAccess(Serializable='always')
	public class DTO_PushEvent
	{
		/**
		 * @description The generic event payload
		 */
		private String payload;
	}

}