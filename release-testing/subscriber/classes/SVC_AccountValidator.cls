// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Validates Account records and logs findings.
 *
 * @see SVC_AccountValidator_TEST
 *
 * @author your.name@company.com
 *
 * @group Account Management
 *
 * @date February 2026, May 2026
 */
public with sharing class SVC_AccountValidator
{
	/**
	 * @description Log context key for the validation result.
	 */
	@TestVisible private static final String CONTEXT_RESULT = 'result';

	/**
	 * @description Log context key for the issue count.
	 */
	@TestVisible private static final String CONTEXT_ISSUE_COUNT = 'issueCount';

	/**
	 * @description Validates an Account and returns a list of issues found.
	 *
	 * @param accountId The ID of the Account to validate.
	 *
	 * @return List of validation issue descriptions. Empty if the Account is valid.
	 */
	public List<String> validate(Id accountId)
	{
		kern.LOG_Builder.build().info('Validation started')
				.at('SVC_AccountValidator.validate')
				.forRecord(accountId)
				.emit();

		List<String> issues = new List<String>();

		try
		{
			Account record = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
					.fields(new List<SObjectField> {Account.Name, Account.Industry, Account.BillingCity})
					.condition(Account.Id).equals(accountId)
					.getFirst();

			if(String.isBlank(record.Industry))
			{
				issues.add('Industry is required');
				kern.LOG_Builder.build().warn('Missing Industry')
						.at('SVC_AccountValidator.validate')
						.forRecord(accountId)
						.emit();
			}

			if(String.isBlank(record.BillingCity))
			{
				issues.add('Billing City is required');
				kern.LOG_Builder.build().warn('Missing Billing City')
						.at('SVC_AccountValidator.validate')
						.forRecord(accountId)
						.emit();
			}

			String validationResult = issues.isEmpty() ? 'PASS' : 'FAIL';

			kern.LOG_Builder.build().info('Validation completed')
					.at('SVC_AccountValidator.validate')
					.forRecord(accountId)
					.withContext(CONTEXT_RESULT, validationResult)
					.withContext(CONTEXT_ISSUE_COUNT, issues.size())
					.emit();
		}
		catch(Exception error)
		{
			kern.LOG_Builder.build().error(error)
					.at('SVC_AccountValidator.validate')
					.forRecord(accountId)
					.emit();
			throw error;
		}

		return issues;
	}
}
