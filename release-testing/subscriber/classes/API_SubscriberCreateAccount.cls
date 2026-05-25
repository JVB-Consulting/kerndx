// SPDX-License-Identifier: BUSL-1.1
public with sharing class API_SubscriberCreateAccount extends kern.API_Inbound
{
	private Account createdAccount;

	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
	}

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

	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Request extends kern.DTO_JsonBase
	{
		public String accountName;
		public String industry;
		public String description;
		public String phone;
	}

	@JsonAccess(Serializable='always')
	public class DTO_Response extends kern.DTO_JsonBase
	{
		public Boolean success;
		public String accountId;
		public String message;
	}
}
