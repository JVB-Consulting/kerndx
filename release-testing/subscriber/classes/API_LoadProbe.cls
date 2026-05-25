// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Inbound API handler for the load probe endpoint. Parses a {@code failRate} integer
 * (0-100) from the request body, delegates an outbound call to {@link API_LoadProbeOutbound}
 * via UTIL_HttpClient delegation mode, and returns the outbound result in the response.
 *
 * Designed to be called by the section-51 callout-storm load test. The {@code failRate} parameter
 * controls the probability (0-100%) that the outbound call will simulate a server-side failure,
 * allowing the test to drive circuit breaker trips and retry exhaustion under parallel HTTP pressure.
 *
 * @see REST_LoadProbe
 * @see API_LoadProbeOutbound
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date May 2026
 */
public with sharing class API_LoadProbe extends kern.API_Inbound
{
	/**
	 * @description Validation error message when failRate is outside the 0-100 range.
	 */
	private static final String ERROR_FAIL_RATE_RANGE = 'failRate must be an integer between 0 and 100 inclusive';

	/**
	 * @description Parameter name for the failure rate passed to the outbound handler.
	 */
	private static final String PARAM_FAIL_RATE = 'failRate';

	/**
	 * @description The outbound handler instance after the delegation call, used to populate the response.
	 */
	private kern.API_Outbound outboundHandler;

	/**
	 * @description Initialises request and response DTOs.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
	}

	/**
	 * @description Validates that {@code failRate} is present and in range 0-100.
	 *
	 * @return A list of validation error messages. Empty means validation passed.
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		DTO_Request dto = (DTO_Request)requestPayload;

		if(dto.failRate == null || dto.failRate < 0 || dto.failRate > 100)
		{
			errors.add(ERROR_FAIL_RATE_RANGE);
		}

		return errors;
	}

	/**
	 * @description Delegates the outbound call to {@link API_LoadProbeOutbound} via UTIL_HttpClient,
	 * passing the resolved {@code failRate} as a parameter.
	 */
	public override void processRequest()
	{
		DTO_Request dto = (DTO_Request)requestPayload;
		Integer failRate = dto.failRate != null ? dto.failRate : 0;

		outboundHandler = kern.UTIL_HttpClient.useHandler(API_LoadProbeOutbound.class)
				.withParameter(PARAM_FAIL_RATE, String.valueOf(failRate))
				.invoke();
	}

	/**
	 * @description Populates the response DTO with the outbound call outcome after the transaction
	 * commit phase completes.
	 */
	public override void updateResponseDTO()
	{
		DTO_Response dto = (DTO_Response)responsePayload;

		if(outboundHandler == null)
		{
			dto.outboundResult = 'no outbound call made';
			return;
		}

		if(outboundHandler.result.isSuccess)
		{
			dto.outboundResult = 'success';
		}
		else if(outboundHandler.result.isAborted)
		{
			dto.outboundResult = 'aborted: ' + String.join(outboundHandler.result.errors, '; ');
		}
		else
		{
			dto.outboundResult = 'failed: ' + outboundHandler.result.statusCode;
		}
	}

	/**
	 * @description Incoming load probe request payload.
	 */
	@JsonAccess(Deserializable='always')
	public class DTO_Request extends kern.DTO_JsonBase
	{
		/**
		 * @description Failure probability expressed as a percentage (0 = always succeed, 100 = always fail).
		 */
		public Integer failRate;

		/**
		 * @description Optional circuit breaker identifier. Reserved for future use by the load test harness.
		 */
		public String circuitId;
	}

	/**
	 * @description Load probe response payload returned to the caller.
	 */
	@JsonAccess(Serializable='always')
	public class DTO_Response extends kern.DTO_JsonBase
	{
		/**
		 * @description Passthrough of the outbound call result: {@code success}, {@code aborted: ...},
		 * or {@code failed: <statusCode>}.
		 */
		public String outboundResult;
	}
}
