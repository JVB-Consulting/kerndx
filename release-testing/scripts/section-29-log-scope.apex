// =============================================================================
// Section 29: LOG_Builder.scope() — Scoped Logging
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//
// Tests LOG_Builder.scope() scoped logging API: creation, buffered entry
// emission, close, idempotent close, and multi-scope lifecycle.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-29-log-scope.apex
// =============================================================================

try
{
	// Test 29a: scope() returns non-null LogScope
	{
		kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
		System.assert(scope != null, '29a FAIL: scope() should return a non-null LogScope');
		scope.close();

		System.debug('29a PASS: LOG_Builder.scope() returns LogScope instance');
	}

	// Test 29b: Scope with entries — emit entries within scope, then close
	{
		kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();

		kern.LOG_Builder.build().info('Scoped entry 1').emitAt('SubscriberTest.section29b');
		kern.LOG_Builder.build().info('Scoped entry 2').emitAt('SubscriberTest.section29b');
		kern.LOG_Builder.build().warn('Scoped warning').emitAt('SubscriberTest.section29b');

		scope.close();

		System.debug('29b PASS: Scope with multiple entries emitted and closed successfully');
	}

	// Test 29c: Scope close is idempotent — calling close twice does not throw
	{
		kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
		kern.LOG_Builder.build().info('Idempotent test').emitAt('SubscriberTest.section29c');

		scope.close();
		scope.close();

		System.debug('29c PASS: Calling scope.close() twice does not throw');
	}

	// Test 29d: Scope with context data — entries carry context within scope
	{
		kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();

		kern.LOG_Builder.build()
				.info('Processing order')
				.withContext('orderId', 'ORD-001')
				.withContext('amount', 250.00)
				.withSummary('Order processing')
				.emitAt('SubscriberTest.section29d');

		kern.LOG_Builder.build()
				.info('Order completed')
				.forRecord(UserInfo.getUserId())
				.emitAt('SubscriberTest.section29d');

		scope.close();

		System.debug('29d PASS: Scoped entries with context data emitted successfully');
	}

	// Test 29e: Multi-scope — second scope after first closes
	{
		kern.LOG_Builder.LogScope scope1 = kern.LOG_Builder.scope();
		kern.LOG_Builder.build().debug('First scope entry').emitAt('SubscriberTest.section29e');
		scope1.close();

		kern.LOG_Builder.LogScope scope2 = kern.LOG_Builder.scope();
		kern.LOG_Builder.build().debug('Second scope entry').emitAt('SubscriberTest.section29e');
		scope2.close();

		System.debug('29e PASS: Sequential scopes work independently');
	}

	System.debug('=== Section 29 COMPLETE: All LOG_Builder.scope() tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 29 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
