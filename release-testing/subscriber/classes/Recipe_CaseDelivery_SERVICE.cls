// SPDX-License-Identifier: Apache-2.0
/**
 * @description Outbound delivery service for the transactional-outbox composition pattern:
 * posts a closed case to the downstream system, stamping a record-grain idempotency key in
 * prepareRequest() so an at-least-once delivery cannot double-apply on the far end. Proof
 * artifact for the Async Processing guide's "Calling an external system only after the
 * transaction commits" pattern.
 *
 * @see Recipe_CaseDelivery_SERVICE_TEST
 * @see Recipe_CommittedDelivery_DEMO
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
public with sharing class Recipe_CaseDelivery_SERVICE extends kern.API_Outbound
{
	/**
	 * @description Prefix for the record-grain idempotency key.
	 */
	public static final String IDEMPOTENCY_KEY_PREFIX = 'case-delivery-';

	/**
	 * @description Initialises DTOs and the default mock body. Always call super.configure()
	 * first so the framework sets its defaults before this override applies changes.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"status": "received"}';
	}

	/**
	 * @description Stamps the record-grain idempotency key before the request is sent. A
	 * pre-set key on the call record always wins over the framework's derived keys, so the
	 * far end can recognise a repeat delivery for the same case.
	 */
	public override void prepareRequest()
	{
		super.prepareRequest();
		apiCall.kern__IdempotencyKey__c = IDEMPOTENCY_KEY_PREFIX + apiCall.kern__TriggeringRecordId__c;
	}

	/**
	 * @description Request DTO; the delivery body stays minimal for the pattern.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class DTO_Request extends kern.DTO_JsonBase
	{
	}

	/**
	 * @description Response DTO matching the downstream acknowledgement.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class DTO_Response extends kern.DTO_JsonBase
	{
		/**
		 * @description The acknowledgement status returned by the downstream system.
		 */
		private String status;

		/**
		 * @description Returns the concrete type the framework deserialises the response into.
		 *
		 * @return DTO_Response.class
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}
}
