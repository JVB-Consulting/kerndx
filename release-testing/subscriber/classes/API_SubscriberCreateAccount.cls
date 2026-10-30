// SPDX-License-Identifier: Apache-2.0
/**
 * @description Inbound service that creates an Account from a JSON request. REST_SubscriberApi receives the HTTP POST
 * and hands it to the framework, which runs this class: it checks the request, inserts the Account and fills in the
 * response.
 */
public with sharing class API_SubscriberCreateAccount extends kern.API_Inbound
{
	/**
	 * @description The Account that onSuccess inserted, kept so that updateResponseDTO can return its Id.
	 */
	private Account createdAccount;

	/**
	 * @description Tells the framework which classes hold the request and the response: the incoming JSON is read into a
	 * DTO_Request and the answer is written from a DTO_Response.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
	}

	/**
	 * @description Checks the request before any record is saved: the account name and the industry are both required.
	 *
	 * @return One message for each missing value; an empty list when the request is valid.
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		DTO_Request dto = (DTO_Request)requestPayload;

		if(String.isBlank(dto.accountName))
		{
			errors.add('Account Name is required');
		}
		if(String.isBlank(dto.industry))
		{
			errors.add('Industry is required');
		}

		return errors;
	}

	/**
	 * @description Does the work of the service: builds the Account from the request and inserts it with doInsert, the
	 * method an inbound service inherits from kern.API_Inbound for saving records.
	 */
	public override void onSuccess()
	{
		super.onSuccess();
		DTO_Request dto = (DTO_Request)requestPayload;

		createdAccount = new Account(
				Name = dto.accountName,
				Industry = dto.industry,
				Description = dto.description,
				Phone = dto.phone
		);

		doInsert(createdAccount);
	}

	/**
	 * @description Fills in the response. When the request succeeded it reports the new Account's Id and a confirmation
	 * message; when it did not, the response fields are left empty.
	 */
	public override void updateResponseDTO()
	{
		DTO_Response dto = (DTO_Response)responsePayload;

		if(result.isSuccess)
		{
			dto.success = true;
			dto.accountId = createdAccount.Id;
			dto.message = 'Account created successfully';
		}
	}

	/**
	 * @description The JSON body a caller sends to create an Account.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class DTO_Request extends kern.DTO_JsonBase
	{
		/**
		 * @description Name of the new Account. Required.
		 */
		public String accountName;
		/**
		 * @description Industry of the new Account. Required.
		 */
		public String industry;
		/**
		 * @description Free text copied to the Account's Description. Optional.
		 */
		public String description;
		/**
		 * @description Phone number copied to the Account. Optional.
		 */
		public String phone;
	}

	/**
	 * @description The JSON body the caller gets back.
	 */
	@JsonAccess(serializable='always')
	public class DTO_Response extends kern.DTO_JsonBase
	{
		/**
		 * @description True when the Account was created. Not set when the request failed.
		 */
		public Boolean success;
		/**
		 * @description Id of the Account that was created.
		 */
		public String accountId;
		/**
		 * @description A confirmation the caller can show or log.
		 */
		public String message;
	}
}
