// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Proof tests for the outbox pattern's delivery service, and the D5 idempotency
 * probe: prepareRequest() stamps a record-grain key on the call record, and a pre-set key
 * always wins over the framework's derived keys.
 *
 * @see Recipe_CaseDelivery_SERVICE
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false)
private class Recipe_CaseDelivery_SERVICE_TEST
{
	/**
	 * @description Verifies the mocked delivery succeeds and the record-grain idempotency key
	 * is stamped in prepareRequest(), both on the in-memory call record the engine's key
	 * resolution reads and on the persisted ApiCall__c row.
	 */
	@IsTest
	private static void shouldStampIdempotencyKeyFromTriggeringRecord()
	{
		Case deliveryCase = new Case(Subject = 'Idempotency probe');
		kern.DML_Builder.newTransaction().doInsert(deliveryCase).execute();

		Test.startTest();
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(Recipe_CaseDelivery_SERVICE.class)
				.withTriggeringRecord(deliveryCase.Id)
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'The mocked delivery should succeed; got: ' + handler.errorText);

		String expectedKey = Recipe_CaseDelivery_SERVICE.IDEMPOTENCY_KEY_PREFIX + deliveryCase.Id;
		Assert.areEqual(expectedKey, handler.apiCall.kern__IdempotencyKey__c,
				'prepareRequest should stamp the record-grain key the engine resolution reads');

		List<kern__ApiCall__c> persistedCalls =
		[
				SELECT kern__IdempotencyKey__c
				FROM kern__ApiCall__c
				WHERE kern__TriggeringRecordId__c = :deliveryCase.Id
		];
		Assert.areEqual(1, persistedCalls.size(), 'The delivery should persist one ApiCall row');
		Assert.areEqual(expectedKey, persistedCalls[0].kern__IdempotencyKey__c,
				'The stamped key should reach the persisted call record');
	}
}
