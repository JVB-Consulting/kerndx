// SPDX-License-Identifier: MIT
/**
 * MIT License
 *
 * Copyright (c) Mike Lockett 2024
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * @description Tests the LOG_Builder class's correlation and context features: starting, setting and reading the
 * correlation and the root, the parent transaction id, serializing and hydrating the context document, and the
 * global context values. The builder's fluent API, buffering and scoping tests live in LOG_Builder_TEST.
 *
 * @see LOG_Builder
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date September 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class LOG_BuilderContext_TEST
{
	/**
	 * @description A correlation a child job continues under, distinct from the action's.
	 */
	private static final String CHILD_CORRELATION_ID = 'child-run-correlation';

	/**
	 * @description Tests that startCorrelation generates a unique correlation ID.
	 *
	 * @see LOG_Builder.startCorrelation
	 */
	@IsTest
	private static void startCorrelationGeneratesUniqueId()
	{
		Test.startTest();

		String correlationId1 = LOG_Builder.startCorrelation();
		String correlationId2 = LOG_Builder.startCorrelation();

		Test.stopTest();

		Assert.isNotNull(correlationId1, 'First correlation ID should not be null');
		Assert.isNotNull(correlationId2, 'Second correlation ID should not be null');
		Assert.areNotEqual(correlationId1, correlationId2, 'Correlation IDs should be unique');
	}

	/**
	 * @description Tests setting and getting correlation ID.
	 *
	 * @see LOG_Builder.setCorrelationId
	 * @see LOG_Builder.correlationId
	 */
	@IsTest
	private static void setAndGetCorrelationId()
	{
		String expectedCorrelationId = 'test-correlation-123';

		Test.startTest();

		LOG_Builder.setCorrelationId(expectedCorrelationId);
		String actualCorrelationId = LOG_Builder.correlationId;

		Test.stopTest();

		Assert.areEqual(expectedCorrelationId, actualCorrelationId, 'Correlation ID should match');
	}

	/**
	 * @description Tests setting parent transaction ID.
	 *
	 * @see LOG_Builder.setParentTransactionId
	 */
	@IsTest
	private static void setParentTransactionId()
	{
		String parentTransactionId = 'parent-txn-456';

		Test.startTest();

		LOG_Builder.setParentTransactionId(parentTransactionId);

		Test.stopTest();

		Assert.areEqual(parentTransactionId, LOG_Engine.currentParentTransactionId, 'Parent transaction ID should be set');
	}

	/**
	 * @description Tests serializing and hydrating context for async jobs.
	 *
	 * @see LOG_Builder.serializeContext
	 * @see LOG_Builder.hydrateContext
	 */
	@IsTest
	private static void serializeAndHydrateContext()
	{
		String correlationId = 'async-correlation-789';
		LOG_Builder.setCorrelationId(correlationId);
		LOG_Builder.setGlobalContext('testKey', 'testValue');

		Test.startTest();

		String serialized = LOG_Builder.serializeContext();

		// Clear state to simulate new transaction
		LOG_Engine.currentCorrelationId = null;
		LOG_Engine.globalContextData.clear();

		LOG_Builder.hydrateContext(serialized);

		Test.stopTest();

		Assert.areEqual(correlationId, LOG_Builder.correlationId, 'Correlation ID should be restored');
		Assert.isTrue(LOG_Engine.globalContextData.containsKey('testKey'), 'Global context should be restored');
	}

	/**
	 * @description Tests that the root correlation id property answers the action's id: equal to the correlation id
	 * until a child continues under an id of its own, then still the action's.
	 *
	 * @see LOG_Builder.rootCorrelationId
	 */
	@IsTest
	private static void rootCorrelationIdAnswersTheActionsId()
	{
		Assert.isNull(LOG_Builder.rootCorrelationId, 'No root before a correlation is established');
		String actionCorrelationId = LOG_Builder.startCorrelation();

		Test.startTest();
		Assert.areEqual(actionCorrelationId, LOG_Builder.rootCorrelationId, 'The first correlation is the root');
		LOG_Builder.setCorrelationId(CHILD_CORRELATION_ID);
		Test.stopTest();

		Assert.areEqual(CHILD_CORRELATION_ID, LOG_Builder.correlationId, 'The live correlation follows the set');
		Assert.areEqual(actionCorrelationId, LOG_Builder.rootCorrelationId, 'The root stays with the action');
	}

	/**
	 * @description Tests that serializeContext excludes contextData field when no context is set.
	 * This prevents wasteful empty objects in the serialized JSON.
	 *
	 * @see LOG_Builder.serializeContext
	 */
	@IsTest
	private static void serializeContextExcludesEmptyContextData()
	{
		LOG_Builder.setCorrelationId(null);
		LOG_Engine.globalContextData.clear();

		LOG_Builder.startCorrelation();

		Test.startTest();

		String serialized = LOG_Builder.serializeContext();

		Test.stopTest();

		Assert.isTrue(serialized.contains('correlationId'), 'Should contain correlationId');
		Assert.isTrue(serialized.contains('parentTransactionId'), 'Should contain parentTransactionId');
		Assert.isFalse(serialized.contains('contextData'), 'Should NOT contain contextData when empty');
	}

	/**
	 * @description Tests that serializeContext(correlationId) produces a context document FOR the
	 * supplied correlation id without reading or touching the live transaction context: the live
	 * correlation stays exactly what it was (handing another execution its identity must never
	 * re-tag the logs this transaction emits afterwards), the document is minimal (no transaction
	 * lineage, no live context data), and hydrating it adopts the supplied id.
	 *
	 * @see LOG_Builder.serializeContext
	 * @see LOG_Builder.hydrateContext
	 */
	@IsTest
	private static void serializeContextForSuppliedCorrelationLeavesLiveContextUntouched()
	{
		String liveCorrelationId = 'live-correlation-123';
		String suppliedCorrelationId = 'supplied-correlation-456';
		LOG_Builder.setCorrelationId(liveCorrelationId);
		LOG_Builder.setGlobalContext('liveKey', 'liveValue');

		Test.startTest();

		String serialized = LOG_Builder.serializeContext(suppliedCorrelationId);

		Assert.areEqual(liveCorrelationId, LOG_Engine.currentCorrelationId, 'Serializing for a supplied id must not re-tag the live transaction correlation');
		Map<String, Object> document = (Map<String, Object>)JSON.deserializeUntyped(serialized);
		Assert.areEqual(suppliedCorrelationId, document.get('correlationId'), 'The document must carry the supplied correlation id');
		Assert.isFalse(serialized.contains('parentTransactionId'), 'The document is minimal: no transaction lineage rides it, not even as a null field');
		Assert.isFalse(serialized.contains('contextData'), 'The document is minimal: no live context data rides it, not even as a null field');

		LOG_Engine.currentCorrelationId = null;
		LOG_Engine.globalContextData.clear();
		LOG_Builder.hydrateContext(serialized);

		Test.stopTest();

		Assert.areEqual(suppliedCorrelationId, LOG_Engine.currentCorrelationId, 'Hydrating the document must adopt the supplied correlation id');
		Assert.isTrue(LOG_Engine.globalContextData.isEmpty(), 'A minimal document must hydrate no context data');
	}

	/**
	 * @description Tests that hydrateContext handles null/blank input gracefully.
	 *
	 * @see LOG_Builder.hydrateContext
	 */
	@IsTest
	private static void hydrateContextHandlesBlankInput()
	{
		Test.startTest();

		LOG_Builder.hydrateContext(null);
		LOG_Builder.hydrateContext('');
		LOG_Builder.hydrateContext('   ');

		Test.stopTest();

		Assert.isNull(LOG_Builder.correlationId, 'Correlation ID should remain null');
	}

	/**
	 * @description Tests that hydrateContext handles invalid JSON gracefully.
	 *
	 * @see LOG_Builder.hydrateContext
	 */
	@IsTest
	private static void hydrateContextHandlesInvalidJson()
	{
		Test.startTest();

		LOG_Builder.hydrateContext('not valid json {{{');

		Test.stopTest();

		Assert.isNull(LOG_Builder.correlationId, 'Correlation ID should remain null after invalid JSON');
	}

	/**
	 * @description Tests setting and clearing global context.
	 *
	 * @see LOG_Builder.setGlobalContext
	 * @see LOG_Builder.clearGlobalContext
	 */
	@IsTest
	private static void setAndClearGlobalContext()
	{
		Test.startTest();

		LOG_Builder.setGlobalContext('orderId', 'ORD-123');
		Assert.isTrue(LOG_Engine.globalContextData.containsKey('orderId'), 'Context should contain orderId');

		LOG_Builder.clearGlobalContext('orderId');

		Test.stopTest();

		Assert.isFalse(LOG_Engine.globalContextData.containsKey('orderId'), 'Context should not contain orderId after clear');
	}

	/**
	 * @description Tests clearing all global context.
	 *
	 * @see LOG_Builder.clearAllGlobalContext
	 */
	@IsTest
	private static void clearAllGlobalContext()
	{
		LOG_Builder.setGlobalContext('key1', 'value1');
		LOG_Builder.setGlobalContext('key2', 'value2');

		Test.startTest();

		LOG_Builder.clearAllGlobalContext();

		Test.stopTest();

		Assert.isTrue(LOG_Engine.globalContextData.isEmpty(), 'All global context should be cleared');
	}

	/**
	 * @description Tests that complex objects are serialized as JSON in context.
	 *
	 * @see LOG_Builder.setGlobalContext
	 */
	@IsTest
	private static void setGlobalContextSerializesComplexObjects()
	{
		Map<String, String> complexObject = new Map<String, String> {'nested' => 'value'};

		Test.startTest();

		LOG_Builder.setGlobalContext('complexKey', complexObject);

		Test.stopTest();

		String storedValue = LOG_Engine.globalContextData.get('complexKey');
		Assert.isTrue(storedValue.contains('nested'), 'Complex object should be JSON serialized');
	}
}
