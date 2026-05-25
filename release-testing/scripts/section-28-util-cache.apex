// =============================================================================
// Section 28: UTIL_Cache — Platform Cache from Subscriber
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - Platform Cache partition allocated (kern__Library)
//
// Tests UTIL_Cache global API: org(), session(), auto(), isAvailable(),
// put/get/contains/remove cycle, TTL, key isolation, and OperationResult.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-28-util-cache.apex
// =============================================================================

try
{
	// Test 28a: isAvailable() returns a Boolean
	{
		Boolean available = kern.UTIL_Cache.isAvailable();
		System.assert(available != null, '28a FAIL: isAvailable() should return a non-null Boolean');
		System.debug('28a PASS: UTIL_Cache.isAvailable() returned ' + available);
	}

	// Test 28b: Org cache put/get/contains/remove cycle
	{
		kern.UTIL_Cache.Store orgCache = kern.UTIL_Cache.org();
		System.assert(orgCache != null, '28b FAIL: org() should return a non-null Store');

		String key = 'sub_test_28b_' + System.currentTimeMillis();
		orgCache.put(key, 'hello_subscriber');

		Object retrieved = orgCache.get(key);
		System.assertEquals('hello_subscriber', retrieved, '28b FAIL: get() should return the value that was put');

		Boolean exists = orgCache.contains(key);
		System.assert(exists, '28b FAIL: contains() should return true after put');

		orgCache.remove(key);

		Object afterRemove = orgCache.get(key);
		System.assertEquals(null, afterRemove, '28b FAIL: get() should return null after remove');

		System.debug('28b PASS: Org cache put/get/contains/remove cycle works');
	}

	// Test 28c: Session cache put/get/remove cycle
	{
		kern.UTIL_Cache.Store sessionCache = kern.UTIL_Cache.session();
		System.assert(sessionCache != null, '28c FAIL: session() should return a non-null Store');

		String key = 'sub_test_28c_' + System.currentTimeMillis();
		sessionCache.put(key, 42);

		Object retrieved = sessionCache.get(key);
		System.assertEquals(42, retrieved, '28c FAIL: session get() should return the value that was put');

		sessionCache.remove(key);
		System.debug('28c PASS: Session cache put/get/remove cycle works');
	}

	// Test 28d: Auto mode returns non-null Store
	{
		kern.UTIL_Cache.Store autoCache = kern.UTIL_Cache.auto();
		System.assert(autoCache != null, '28d FAIL: auto() should return a non-null Store');

		String key = 'sub_test_28d_' + System.currentTimeMillis();
		autoCache.put(key, 'auto_value');
		Object retrieved = autoCache.get(key);
		System.assertEquals('auto_value', retrieved, '28d FAIL: auto store put/get should work');
		autoCache.remove(key);

		System.debug('28d PASS: UTIL_Cache.auto() returns functional Store');
	}

	// Test 28e: TTL put — put(key, value, ttlSeconds) succeeds
	{
		kern.UTIL_Cache.Store orgCache = kern.UTIL_Cache.org();
		String key = 'sub_test_28e_' + System.currentTimeMillis();
		Boolean result = orgCache.put(key, 'ttl_value', 300);
		System.assert(result, '28e FAIL: put with TTL should return true');

		Object retrieved = orgCache.get(key);
		System.assertEquals('ttl_value', retrieved, '28e FAIL: TTL put value should be retrievable');
		orgCache.remove(key);

		System.debug('28e PASS: TTL put works with explicit seconds');
	}

	// Test 28f: Key isolation — different keys return different values
	{
		kern.UTIL_Cache.Store orgCache = kern.UTIL_Cache.org();
		String keyA = 'sub_test_28f_a_' + System.currentTimeMillis();
		String keyB = 'sub_test_28f_b_' + System.currentTimeMillis();

		orgCache.put(keyA, 'value_a');
		orgCache.put(keyB, 'value_b');

		System.assertEquals('value_a', orgCache.get(keyA), '28f FAIL: keyA should return value_a');
		System.assertEquals('value_b', orgCache.get(keyB), '28f FAIL: keyB should return value_b');

		orgCache.remove(keyA);
		orgCache.remove(keyB);

		System.debug('28f PASS: Key isolation verified — different keys return different values');
	}

	// Test 28g: getLastOperationResult() returns valid OperationResult
	{
		kern.UTIL_Cache.Store orgCache = kern.UTIL_Cache.org();
		String key = 'sub_test_28g_' + System.currentTimeMillis();
		orgCache.put(key, 'result_test');

		kern.UTIL_Cache.OperationResult opResult = orgCache.getLastOperationResult();
		System.assert(opResult != null, '28g FAIL: getLastOperationResult() should return non-null');
		System.assert(opResult.success, '28g FAIL: OperationResult.success should be true after successful put');

		orgCache.remove(key);

		System.debug('28g PASS: getLastOperationResult() returns valid OperationResult');
	}

	System.debug('=== Section 28 COMPLETE: All UTIL_Cache tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 28 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
