// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for the FastStart_AsyncChain_DEMO chain step.
 *
 * The success-path test drives the step through the framework — a one-step chain
 * is built, seeded with an Account Id via withInitialContext, and executed inside
 * Test.startTest/stopTest so the queueable flushes. The test then requeries the
 * Account and asserts the Description was stamped.
 *
 * The failure-path test seeds the chain context with a non-Id value under the
 * accountId key — the step's cast yields null, the failure branch executes, and
 * kern.UTIL_AsyncChain.getStatus reports the chain failed. Driving via the
 * framework (rather than calling work() directly) is required because
 * kern.UTIL_AsyncChain.ChainContext has a @TestVisible private constructor that
 * does not cross the managed-package namespace boundary.
 *
 * @see FastStart_AsyncChain_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_AsyncChain_DEMO_TEST
{
	/**
	 * @description Chain name used by every test in this class.
	 */
	private static final String CHAIN_NAME = 'FastStartAsyncChainDemo';

	/**
	 * @description Status value persisted on AsyncChainExecution__c when the chain failed.
	 */
	private static final String STATUS_FAILED = 'Failed';

	/**
	 * @description Verifies the step stamps the Description when an Account Id is present
	 *              in the chain context.
	 *
	 * Bypasses kern validation rules on Account so the test isolates from any rule
	 * fixtures (FastStart_RequiresDescription or others) that may be active in the
	 * subscriber org.
	 */
	@IsTest
	private static void shouldEnrichAccountWhenContextHasId()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, 'Async Chain Demo')
				.build();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.withInitialContext(FastStart_AsyncChain_DEMO.CONTEXT_KEY_ACCOUNT_ID, record.Id)
				.then(new FastStart_AsyncChain_DEMO())
				.execute();
		Test.stopTest();

		Account result = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Description})
				.condition(Account.Id).equals(record.Id)
				.getFirst();

		Assert.areEqual
				(
						FastStart_AsyncChain_DEMO.ENRICHMENT_NOTE,
						result.Description,
						'Description should be stamped by the chain step'
				);
		Assert.isNotNull(executionId, 'Chain executionId should be returned by execute()');
	}

	/**
	 * @description Verifies the step returns a failed StepResult when the chain context
	 *              does not carry an accountId, and that the chain execution record
	 *              reports the failure.
	 */
	@IsTest
	private static void shouldFailWhenContextMissingAccountId()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new FastStart_AsyncChain_DEMO())
				.execute();
		Test.stopTest();

		Map<String, Object> status = kern.UTIL_AsyncChain.getStatus(executionId);

		Assert.areEqual(STATUS_FAILED, (String)status.get('status'), 'Chain should be marked Failed when accountId missing');
		Assert.areEqual
				(
						FastStart_AsyncChain_DEMO.ERROR_MISSING_ACCOUNT_ID,
						(String)status.get('errorMessage'),
						'errorMessage should propagate the StepResult.failed message'
				);
	}
}
