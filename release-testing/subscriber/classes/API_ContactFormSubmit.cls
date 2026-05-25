// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Processes Contact Us form submissions. Creates a Lead record.
 *
 * @see REST_ContactForm
 * @see API_ContactFormSubmit_TEST
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
public with sharing class API_ContactFormSubmit extends kern.API_Inbound
{
	/**
	 * @description The Lead record being created.
	 */
	private Lead newLead;

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

		if(String.isBlank(dto.lastName))
		{
			errors.add('Last name is required');
		}

		if(String.isBlank(dto.email))
		{
			errors.add('Email is required');
		}

		return errors;
	}

	/**
	 * @description Creates the Lead record from the submitted data.
	 */
	public override void onSuccess()
	{
		super.onSuccess();
		DTO_Request dto = (DTO_Request)requestPayload;

		newLead = new Lead(
				FirstName = dto.firstName,
				LastName = dto.lastName,
				Email = dto.email,
				Description = dto.message,
				LeadSource = 'Web',
				Company = dto.lastName + ' (Web Lead)'
		);

		doInsert(newLead);
	}

	/**
	 * @description Populates the response after the database commit.
	 */
	public override void updateResponseDTO()
	{
		DTO_Response dto = (DTO_Response)responsePayload;

		if(result.isSuccess && newLead?.Id != null)
		{
			dto.success = true;
			dto.leadId = newLead.Id;
			dto.message = 'Thank you for contacting us!';
		}
	}

	/**
	 * @description Incoming form submission data.
	 */
	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Request extends kern.DTO_JsonBase
	{
		/**
		 * @description Contact's first name.
		 */
		public String firstName;

		/**
		 * @description Contact's last name.
		 */
		public String lastName;

		/**
		 * @description Contact's email address.
		 */
		public String email;

		/**
		 * @description Message from the contact form.
		 */
		public String message;
	}

	/**
	 * @description Response returned to the caller.
	 */
	@JsonAccess(Serializable='always')
	public class DTO_Response extends kern.DTO_JsonBase
	{
		/**
		 * @description Whether the submission was successful.
		 */
		public Boolean success;

		/**
		 * @description The created Lead record ID.
		 */
		public String leadId;

		/**
		 * @description User-friendly response message.
		 */
		public String message;
	}
}
