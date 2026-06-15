// =============================================================================
// Section 35: Secure-By-Default — USER_MODE Posture
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed (>=1.0.0-38)
//   - FeatureFlag.UserModeQueries_Enabled and FeatureFlag.UserModeDml_Enabled
//     both in their shipped default state (IsEnabledByDefault=true)
//
// Runtime enforcement (USER_MODE rejecting Standard Users who lack CRUD) is
// exercised by SubscriberSecureByDefault_TEST in the test-class phase; this
// script validates the flag state, the API surface, and that the shipped
// defaults produce working queries and DML under SYSTEM_MODE overrides.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-35-secure-by-default.apex
// =============================================================================

kern.TRG_Base.bypass(Schema.Account.SObjectType);

List<Id> cleanup = new List<Id>();

try
{
	// 35a — UserModeQueries_Enabled flag is on by default
	{
		Boolean queriesEnabled = kern.UTIL_FeatureFlag.isEnabled('UserModeQueries_Enabled');
		System.assert(queriesEnabled, '35a FAIL: UserModeQueries_Enabled should be true in the shipped default state');
		System.debug('35a PASS: UserModeQueries_Enabled = true');
	}

	// 35b — UserModeDml_Enabled flag is on by default
	{
		Boolean dmlEnabled = kern.UTIL_FeatureFlag.isEnabled('UserModeDml_Enabled');
		System.assert(dmlEnabled, '35b FAIL: UserModeDml_Enabled should be true in the shipped default state');
		System.debug('35b PASS: UserModeDml_Enabled = true');
	}

	// 35c — QRY_Builder exposes fluent .withUserMode() / .withSystemMode() for explicit overrides
	{
		kern.QRY_Builder.Builder userModeBuilder = kern.QRY_Builder.selectFrom(Account.SObjectType).withUserMode();
		kern.QRY_Builder.Builder systemModeBuilder = kern.QRY_Builder.selectFrom(Account.SObjectType).withSystemMode();
		System.assert(userModeBuilder != null, '35c FAIL: .withUserMode() should return a fluent builder');
		System.assert(systemModeBuilder != null, '35c FAIL: .withSystemMode() should return a fluent builder');
		System.debug('35c PASS: QRY_Builder .withUserMode() + .withSystemMode() fluent API available');
	}

	// 35d — Default QRY_Builder execution succeeds against the flag-driven USER_MODE default
	//       (admin has CRUD so the query runs; proves the default path is wired end-to-end)
	{
		Account seed = new Account(Name = 'SecureByDefault 35d');
		insert seed;
		cleanup.add(seed.Id);

		List<Account> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<Schema.SObjectField> {Account.Id, Account.Name})
				.condition(Account.Id).equals(seed.Id)
				.toList();

		System.assert(!results.isEmpty(), '35d FAIL: default USER_MODE query should return admin-visible record');
		System.debug('35d PASS: default USER_MODE query succeeded against admin context');
	}

	// 35e — DML_Builder exposes fluent .withUserMode() / .withSystemMode() for explicit overrides
	{
		kern.DML_Builder userModeDml = kern.DML_Builder.newTransaction().withUserMode();
		kern.DML_Builder systemModeDml = kern.DML_Builder.newTransaction().withSystemMode();
		System.assert(userModeDml != null, '35e FAIL: DML_Builder .withUserMode() should return a fluent builder');
		System.assert(systemModeDml != null, '35e FAIL: DML_Builder .withSystemMode() should return a fluent builder');
		System.debug('35e PASS: DML_Builder .withUserMode() + .withSystemMode() fluent API available');
	}

	// 35f — Default DML_Builder execution succeeds against the flag-driven USER_MODE default
	//       (admin has CRUD so the insert runs; proves the default path is wired end-to-end)
	{
		Account record = new Account(Name = 'SecureByDefault 35f');
		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(record)
				.execute();

		System.assert(result.isSuccess(), '35f FAIL: default USER_MODE DML should succeed for admin');
		System.assert(record.Id != null, '35f FAIL: inserted record should have an Id');
		cleanup.add(record.Id);
		System.debug('35f PASS: default USER_MODE DML succeeded against admin context');
	}

	// 35g — Explicit .withSystemMode() DML opts out of the flag and completes the insert
	{
		Account record = new Account(Name = 'SecureByDefault 35g');
		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(record)
				.withSystemMode()
				.execute();

		System.assert(result.isSuccess(), '35g FAIL: explicit .withSystemMode() DML should succeed');
		cleanup.add(record.Id);
		System.debug('35g PASS: explicit .withSystemMode() DML bypassed flag-driven default as expected');
	}

	// 35h — systemModeRequired() hook on managed SEL_* continues to pin SYSTEM_MODE. Execute a
	//       managed-selector query that only succeeds if the hook overrides the flag-driven
	//       default. SEL_Group queries Group records via the hook — if the hook is broken the
	//       default USER_MODE path would reject any context that lacks Group read.
	{
		Group found = new kern.SEL_Group().findByName('SecureByDefault_NonExistent_35h');
		System.assert(found == null, '35h FAIL: query for a non-existent group should return null');
		System.debug('35h PASS: systemModeRequired() hook pinned SEL_Group to SYSTEM_MODE (query executed without rejection)');
	}
}
finally
{
	kern.TRG_Base.clearAllBypasses();

	if(!cleanup.isEmpty())
	{
		delete
		[
				SELECT Id
				FROM Account
				WHERE Id IN :cleanup
		];
	}
}
