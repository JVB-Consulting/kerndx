// =============================================================================
// Section 35 (kill-switch): Secure-By-Default Emergency Bypass
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed (>=1.0.0-38)
//   - Deploy CMDT state `section35-flags-disabled` before running this script
//     to flip both UserModeQueries_Enabled and UserModeDml_Enabled to false.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-35-kill-switch.apex
//
// After running, restore the shipped defaults by deploying `section35-flags-default`.
// =============================================================================

kern.TRG_Base.bypass(Schema.Account.SObjectType);

List<Id> cleanup = new List<Id>();

try
{
	// 35a-disabled — UserModeQueries_Enabled flag is now off (kill-switch active)
	{
		Boolean queriesEnabled = kern.UTIL_FeatureFlag.isEnabled('UserModeQueries_Enabled');
		System.assert(!queriesEnabled, '35a-disabled FAIL: UserModeQueries_Enabled should be false under kill-switch state');
		System.debug('35a-disabled PASS: UserModeQueries_Enabled = false');
	}

	// 35b-disabled — UserModeDml_Enabled flag is now off (kill-switch active)
	{
		Boolean dmlEnabled = kern.UTIL_FeatureFlag.isEnabled('UserModeDml_Enabled');
		System.assert(!dmlEnabled, '35b-disabled FAIL: UserModeDml_Enabled should be false under kill-switch state');
		System.debug('35b-disabled PASS: UserModeDml_Enabled = false');
	}

	// 35c-disabled — Default QRY_Builder query completes under SYSTEM_MODE fallback
	{
		Account seed = new Account(Name = 'SecureByDefault 35c-disabled');
		insert seed;
		cleanup.add(seed.Id);

		List<Account> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<Schema.SObjectField> {Account.Id, Account.Name})
				.condition(Account.Id).equals(seed.Id)
				.toList();

		System.assert(!results.isEmpty(), '35c-disabled FAIL: default query should succeed under SYSTEM_MODE fallback');
		System.debug('35c-disabled PASS: default query ran in SYSTEM_MODE fallback under kill-switch');
	}

	// 35d-disabled — Default DML_Builder insert completes under SYSTEM_MODE fallback
	{
		Account record = new Account(Name = 'SecureByDefault 35d-disabled');
		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(record)
				.execute();

		System.assert(result.isSuccess(), '35d-disabled FAIL: default DML should succeed under SYSTEM_MODE fallback');
		cleanup.add(record.Id);
		System.debug('35d-disabled PASS: default DML ran in SYSTEM_MODE fallback under kill-switch');
	}
}
finally
{
	kern.TRG_Base.clearAllBypasses();

	if(!cleanup.isEmpty())
	{
		delete [SELECT Id FROM Account WHERE Id IN :cleanup];
	}
}
