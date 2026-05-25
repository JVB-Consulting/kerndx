// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Fast Start demonstration of inbound API handling. Receives a contact
 *              creation request from an external system, validates the email field,
 *              creates an Account record, and returns the new record ID.
 *
 * @see FastStart_InboundAPI_REST
 *
 * @see FastStart_InboundAPI_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_InboundAPI_DEMO extends kern.API_Inbound
{
	/** @description The Account record created by this handler. */
	private Account newAccount;

	/**
	 * @description Initializes request and response DTOs.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
	}

	/**
	 * @description Validates the incoming request data.
	 *
	 * @return A list of validation error messages. Empty list means validation passed.
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		DTO_Request dto = (DTO_Request)requestPayload;

		if(String.isBlank(dto.email))
		{
			errors.add('Email is required');
		}

		return errors;
	}

	/**
	 * @description Creates an Account from the submitted data.
	 *              Uses inherited doInsert() so the framework commits all DML atomically.
	 */
	public override void onSuccess()
	{
		super.onSuccess();
		DTO_Request dto = (DTO_Request)requestPayload;

		newAccount = new Account(
			Name = dto.name,
			Phone = dto.phone,
			Website = dto.email
		);

		doInsert(newAccount);
	}

	/**
	 * @description Populates the response DTO after the database commit.
	 *              Record IDs are available here because this runs post-commit.
	 */
	public override void updateResponseDTO()
	{
		DTO_Response dto = (DTO_Response)responsePayload;

		if(result.isSuccess && newAccount?.Id != null)
		{
			dto.success = true;
			dto.accountId = newAccount.Id;
			dto.message = 'Account created successfully.';
		}
	}

	/** @description Incoming request payload from the external system. */
	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Request extends kern.DTO_JsonBase
	{
		/** @description The account name. */
		public String name;

		/** @description Contact email address. Required. */
		public String email;

		/** @description Contact phone number. Optional. */
		public String phone;
	}

	/** @description Response returned to the caller after processing. */
	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Response extends kern.DTO_JsonBase
	{
		/** @description Whether the request was processed successfully. */
		public Boolean success;

		/** @description The Salesforce ID of the created Account record. */
		public String accountId;

		/** @description A human-readable status message. */
		public String message;
	}
}
