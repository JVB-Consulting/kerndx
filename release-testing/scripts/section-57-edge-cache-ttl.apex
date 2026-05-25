/**
 * Section 57: UTIL_Cache — TTL & Edge Cases
 *
 * Closes gaps in UTIL_Cache capability coverage beyond section-28 (which already
 * exercises put/get/contains/remove + TTL-within-window + key isolation +
 * OperationResult). This script covers four anon-Apex edge scenarios from the extended-load spec
 * §6.6 plus a single-transaction partition-allocation reuse check:
 *
 *   1. TTL expiry via lazy-expiration wrapper — put with ttlSeconds=0; the
 *      framework's CacheEntry constructor sets validUntil = now + (0 * 1000) =
 *      now, so isValid() returns false on the very next get(). This precisely
 *      exercises the wrapper's lazy-expiration code path (UTIL_Cache.cls
 *      lines 339, 382) without burning CPU on busy-waits — see the deferral
 *      note below for why a wall-clock-based expiry assertion lives in a
 *      managed @IsTest, not anon Apex.
 *   2. Oversized value graceful rejection — put a ~150KB high-entropy random
 *      string. ZIP compression cannot meaningfully reduce truly random data,
 *      so the wrapper retains the uncompressed bytes; JSON-serialised wrapper
 *      length exceeds MAXIMUM_ENTRY_SIZE (102400 chars) and putToCache returns
 *      false with OperationResult.success=false, status=WRITE_FAILURE,
 *      errorMessage containing "exceeds maximum size".
 *   3. No-partition graceful degrade — UTIL_Cache.partition('local.<bogus>')
 *      returns a non-null Store (factory does not validate partition existence).
 *      isCacheAvailable() returns false; put/get/remove all report success=false
 *      with status=CACHE_UNAVAILABLE. No exception bubbles.
 *   4. putAll(Map) with 50 entries — bulk put + bulk getAll round-trip + per-key
 *      contains/get cross-check. Demonstrates that the framework's putAll
 *      iterates entries (Platform Cache lacks a native bulk put with TTL) and
 *      that getAll returns all values in a single call.
 *   5. Single-transaction partition allocation reuse — three sequential
 *      partition() factory calls in the same transaction all return functional
 *      Stores. The internal scopeProbeResults cache means the put/get probe
 *      runs at most once per scope per Store. True cross-transaction
 *      concurrency is deferred (see deferrals below).
 *
 * Total cumulative busy-wait: zero. Apex anon-script CPU governor is 10s
 * (not 60s — that's the wall-clock max for sync transactions). A 12s busy-wait
 * polling System.currentTimeMillis() in a tight loop blows the CPU budget on
 * the millis() calls themselves (verified empirically — a 12s loop reliably
 * exceeds 10s of CPU). Scenario 57a therefore drives the validity check via
 * ttlSeconds=0 (instant expiry through the wrapper's validUntil math) rather
 * than wall-clock waiting. Total wall-clock runtime: <2 seconds.
 *
 * Deferrals to managed @IsTest harness or framework follow-up:
 *
 *   - Wall-clock-based TTL expiry (waiting N real seconds and then asserting
 *     get() returns null): Apex has no sleep primitive, and busy-waiting
 *     System.currentTimeMillis() consumes CPU at the millis()-call rate
 *     (empirically reliable to blow the 10s anon-Apex CPU governor on a
 *     12-second wait). Scenario 57a covers the SAME validity-check code
 *     path (CacheEntry.isValid() → System.currentTimeMillis() < validUntil)
 *     by setting validUntil = now (ttlSeconds=0), proving the gating logic
 *     fires correctly. A wall-clock-bound assertion belongs in
 *     Subscriber_CacheEdges_TEST where Test.setCreatedDate or a mockable
 *     clock can advance time without burning real CPU. FRAMEWORK FOLLOW-UP:
 *     consider exposing a clock seam (e.g. UTIL_System.currentTimeMillis())
 *     so tests can fast-forward without the wrapper depending on the
 *     System primitive directly.
 *
 *   - True cross-transaction concurrency probe (two parallel transactions
 *     racing to allocate the same partition entry): cannot be reproduced in
 *     anon Apex (single-threaded). Belongs in a Subscriber_CacheEdges_TEST
 *     where two queueables enqueue against the same key and the test asserts
 *     last-writer-wins semantics. Scenario 57e covers the single-transaction
 *     reuse path (partition factory + scopeProbeResults caching) which is the
 *     only concurrency primitive observable from anon Apex.
 *
 *   - simulateCompressionFailure-driven oversized rejection: UTIL_Cache.cls
 *     line 85 declares simulateCompressionFailure as @TestVisible private,
 *     making it reachable only from @IsTest classes inside the kern namespace.
 *     Anon Apex from a subscriber org cannot toggle the flag. Scenario 57b
 *     therefore proves the rejection path with real high-entropy data, not
 *     the simulated failure flag — same code path (line 1522 size check),
 *     different trigger.
 *
 *   - Cache pollution sweep / partition exhaustion (allocating until the 1MB
 *     org partition is full): governor budget would not allow inserting
 *     thousands of entries within 10K DML rows, and the resulting cache state
 *     would leak into subsequent test runs in the same org. Belongs in a
 *     dedicated capacity-stress @IsTest with explicit cleanup. FRAMEWORK
 *     FOLLOW-UP: consider a UTIL_Cache.clearPartition(name) global helper for
 *     test cleanup — currently subscribers must enumerate keys to clear.
 *
 *   - contains() does NOT honour wrapper expiry (FRAMEWORK FOLLOW-UP).
 *     Empirically: with ttlSeconds=0, get() correctly returns null
 *     (CacheEntry.isValid() filter at line 1586), but contains() returns true
 *     because containsInCache (line 1626) does `partition.get(key) != null`
 *     against the raw CacheEntry wrapper — no unwrap, no validity check.
 *     Subscribers should treat get()-returns-null as the source of truth for
 *     "key not present"; contains() is unsafe as a TTL gate. Scenario 57a
 *     asserts the get() behaviour (source of truth) and documents this
 *     inconsistency rather than asserting an inconsistent shape. Fix would be
 *     to make containsInCache cast to CacheEntry and call isValid() before
 *     returning true.
 *
 * Run-isolation: self-contained — does not depend on prior section state.
 * Cleanup removes only the keys this script created (single-key remove() per
 * scenario); cache entries are ephemeral by nature so partition-level cleanup
 * is not required.
 *
 * Implementation notes:
 *   - All cache keys are stamped with KEY_RUN_STAMP (epoch ms) so concurrent
 *     re-runs do not collide on probe keys.
 *   - Scenario 57b uses kern.UTIL_Random.randomAlphanumeric(150000) for high-
 *     entropy data. Alphanumeric (rather than full random()) keeps the JSON
 *     serialisation simple — no escape sequences inflate the wrapper length
 *     unpredictably; the 150KB raw size guarantees the post-wrapper serialised
 *     length exceeds MAXIMUM_ENTRY_SIZE (102400) even if ZIP shaves a few
 *     percent off alphanumeric strings (random alphanumerics still compress
 *     poorly because per-character entropy is ~5.95 bits, leaving little
 *     redundancy for LZ77-style compression to exploit).
 *   - Scenario 57c uses 'local.NonExistentPartition57' + KEY_RUN_STAMP suffix
 *     as the bogus partition name; this maps to no PlatformCachePartition
 *     metadata in the org so Cache.Org.getPartition / Cache.Session.getPartition
 *     return null. The framework's getPartitionInstance returns null →
 *     putToCache hits the CACHE_UNAVAILABLE branch.
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *   - kern__Library Platform Cache partition allocated (1MB Org + 1MB Session,
 *     defined in release-testing/subscriber/cachePartitions/)
 *   - kern.UTIL_Random.randomAlphanumeric global accessor available (1.0+)
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-57-edge-cache-ttl.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <2 seconds.
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 57: UTIL_Cache TTL & Edge Cases ===');

kern.TRG_Base.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String KEY_RUN_STAMP = String.valueOf(Datetime.now().getTime());

// Scenario 57a — TTL expiry via lazy-expiration wrapper, instant-expiry variant. The CacheEntry
// constructor (UTIL_Cache.cls line 339) computes validUntil = System.currentTimeMillis() +
// (validitySeconds * 1000). Passing ttlSeconds=0 yields validUntil = now, so isValid() (line 382)
// returns false on the next get() because System.currentTimeMillis() < validUntil is now < now =
// false. The Platform Cache TTL is independently clamped to a 300s minimum (line 1507) so the
// underlying partition.put still uses 300s, but the wrapper's lazy expiration intercepts the
// retrieval first and returns null. This proves the wrapper enforces sub-300s TTLs that
// subscribers expect.
//
// Empirical finding (FRAMEWORK FOLLOW-UP): contains() does NOT honour the wrapper's
// validUntil — containsInCache (line 1626) returns `partition.get(key) != null` against the
// raw CacheEntry wrapper without unwrapping or validity-checking. So an expired entry where
// get() returns null will still report contains()=true until the underlying Platform Cache
// TTL elapses. Subscribers should rely on get() returning null as the source of truth, not
// contains(). This scenario asserts the get() behaviour (which is the source-of-truth path)
// and documents the contains() inconsistency rather than asserting the inconsistent shape.
//
// Wall-clock-based expiry (waiting N real seconds) cannot be done in anon Apex without blowing
// the 10s CPU governor — see header deferral.
try
{
	final String key57a = 'sub57a' + KEY_RUN_STAMP;
	kern.UTIL_Cache.Store cache57a = kern.UTIL_Cache.org();
	Boolean putResult57a = cache57a.put(key57a, 'expires_immediately', 0);
	Assert.isTrue(putResult57a, '57a: put with ttlSeconds=0 should still return true (Platform Cache TTL clamped to 300s, wrapper validUntil=now)');

	Object retrieved57a = cache57a.get(key57a);
	Assert.isNull(retrieved57a, '57a: get() should return null when wrapper validUntil=now (CacheEntry.isValid() returns false)');

	Map<String, Object> bulkRetrieved57a = cache57a.getAll(new Set<String>{key57a});
	Assert.areEqual(0, bulkRetrieved57a.size(),
			'57a: getAll() should also honour wrapper expiry — empty map for an expired key (getFromCache filters by isValid() before adding to results)');

	cache57a.remove(key57a);
	System.debug(LoggingLevel.INFO,
			'57a PASS: ttlSeconds=0 → wrapper validUntil=now → get()/getAll() honour lazy expiration (contains() does not — see header follow-up)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '57a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('57a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 57b — Oversized value graceful rejection. UTIL_Cache wraps every put in a CacheEntry
// (which adds metadata), JSON-serialises the wrapper, then size-checks against MAXIMUM_ENTRY_SIZE
// (102400 chars). For values > 4KB the framework attempts ZIP compression; if compression reduces
// size, the compressed bytes are stored. High-entropy random alphanumeric (~5.95 bits/char) compresses
// poorly (ZIP headers may even inflate it), so the wrapper retains the uncompressed serialised
// string and the size check rejects the put with success=false, status=WRITE_FAILURE, errorMessage
// containing "exceeds maximum size".
//
// Cannot use UTIL_Cache.simulateCompressionFailure (line 85) from anon Apex — it's @TestVisible
// private and only reachable from @IsTest classes in the kern namespace. Real high-entropy data
// drives the same code path through a non-simulated trigger.
try
{
	final String key57b = 'sub57b' + KEY_RUN_STAMP;
	kern.UTIL_Cache.Store cache57b = kern.UTIL_Cache.org();
	String oversizedValue57b = kern.UTIL_Random.randomAlphanumeric(150000);
	Assert.areEqual(150000, oversizedValue57b.length(), '57b: random alphanumeric should be exactly 150000 chars');

	Boolean putResult57b = cache57b.put(key57b, oversizedValue57b);
	Assert.isFalse(putResult57b, '57b: put of 150KB random data should return false (post-wrapper size > MAXIMUM_ENTRY_SIZE)');

	kern.UTIL_Cache.OperationResult opResult57b = cache57b.getLastOperationResult();
	Assert.isNotNull(opResult57b, '57b: getLastOperationResult should return a non-null OperationResult');
	Assert.isFalse(opResult57b.success, '57b: OperationResult.success should be false for oversized rejection');
	Assert.areEqual(kern.UTIL_Cache.Status.WRITE_FAILURE, opResult57b.status, '57b: OperationResult.status should be WRITE_FAILURE');
	Assert.isNotNull(opResult57b.errorMessage, '57b: OperationResult.errorMessage should be populated on failure');
	Assert.isTrue(opResult57b.errorMessage.contains('exceeds maximum size'),
			'57b: errorMessage should mention "exceeds maximum size" but was: ' + opResult57b.errorMessage);

	Object retrieved57b = cache57b.get(key57b);
	Assert.isNull(retrieved57b, '57b: rejected oversized value should not be retrievable');

	System.debug(LoggingLevel.INFO, '57b PASS: 150KB random value rejected gracefully — success=false, status=WRITE_FAILURE, errorMessage="' + opResult57b.errorMessage + '"');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '57b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('57b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 57c — No-partition graceful degrade. UTIL_Cache.partition(name) is a thin factory
// that records the partition name on the configuration; it does not validate that the partition
// metadata exists. The framework's behaviour against a non-existent partition depends on what
// Cache.Org.getPartition / Cache.Session.getPartition return:
//   - If they return null → getPartitionInstance returns null → CACHE_UNAVAILABLE path.
//   - If they return a non-null partition wrapper that throws on actual ops → exception is
//     caught and translated into WRITE_FAILURE / READ_FAILURE / REMOVE_FAILURE with an
//     errorMessage populated.
// Either way the framework MUST: return false from put/remove, return null from get, populate
// OperationResult.success=false with a populated errorMessage, and never let an exception bubble.
// Empirically in scratch orgs, Cache.Org.getPartition for a bogus name returns a non-null
// wrapper that throws on partition.put, so this scenario asserts the resilience contract
// (graceful failure + populated error) without locking in the specific Status enum value.
try
{
	final String bogusPartition57c = 'local.NonExistentPartition57' + KEY_RUN_STAMP.substring(KEY_RUN_STAMP.length() - 6);
	kern.UTIL_Cache.Store cache57c = kern.UTIL_Cache.partition(bogusPartition57c);
	Assert.isNotNull(cache57c, '57c: partition() factory should return a non-null Store even for a bogus partition name');

	Boolean cacheAvailable57c = cache57c.isCacheAvailable();
	Assert.isFalse(cacheAvailable57c, '57c: isCacheAvailable() should return false for a non-existent partition');

	final String key57c = 'sub57c' + KEY_RUN_STAMP;
	Boolean putResult57c = cache57c.put(key57c, 'should_not_persist');
	Assert.isFalse(putResult57c, '57c: put against a non-existent partition should return false (no exception)');

	kern.UTIL_Cache.OperationResult opResult57c = cache57c.getLastOperationResult();
	Assert.isNotNull(opResult57c, '57c: getLastOperationResult should return non-null after put attempt');
	Assert.isFalse(opResult57c.success, '57c: OperationResult.success should be false');
	Set<kern.UTIL_Cache.Status> acceptableStatuses57c = new Set<kern.UTIL_Cache.Status>
	{
		kern.UTIL_Cache.Status.CACHE_UNAVAILABLE,
		kern.UTIL_Cache.Status.WRITE_FAILURE
	};
	Assert.isTrue(acceptableStatuses57c.contains(opResult57c.status),
			'57c: status should be CACHE_UNAVAILABLE (null partition) or WRITE_FAILURE (partition.put threw); got ' + opResult57c.status);
	Assert.isNotNull(opResult57c.errorMessage, '57c: errorMessage should be populated');
	Assert.isTrue(opResult57c.errorMessage.length() > 0, '57c: errorMessage should be non-empty (got "' + opResult57c.errorMessage + '")');

	Object retrieved57c = cache57c.get(key57c);
	Assert.isNull(retrieved57c, '57c: get from non-existent partition should return null gracefully');

	Boolean removeResult57c = cache57c.remove(key57c);
	Assert.isFalse(removeResult57c, '57c: remove from non-existent partition should return false gracefully');

	System.debug(LoggingLevel.INFO,
			'57c PASS: bogus partition "' + bogusPartition57c + '" → isCacheAvailable=false, put/get/remove all degrade gracefully (status=' + opResult57c.status + ')');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '57c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('57c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 57d — putAll with 50 entries + getAll round-trip. The framework's putAll iterates
// each entry through partition.put() (Platform Cache has no native bulk put with TTL); getAll
// uses partition.get() per key but returns a single Map<String, Object> to the caller. Verify
// that all 50 entries written via putAll are retrievable both via individual get() and via
// batch getAll(). Sample-asserts a few specific keys to catch off-by-one or key-collision bugs.
try
{
	kern.UTIL_Cache.Store cache57d = kern.UTIL_Cache.org();
	Map<String, Object> bulkEntries57d = new Map<String, Object>();
	final Integer entryCount57d = 50;
	final String key57dPrefix = 'sub57d' + KEY_RUN_STAMP;
	for(Integer i = 0; i < entryCount57d; i++)
	{
		bulkEntries57d.put(key57dPrefix + i, 'bulkValue' + i);
	}
	Assert.areEqual(entryCount57d, bulkEntries57d.size(), '57d: bulk map should contain exactly ' + entryCount57d + ' entries');

	Boolean putAllResult57d = cache57d.putAll(bulkEntries57d);
	Assert.isTrue(putAllResult57d, '57d: putAll should return true after all entries written');

	for(Integer sampleIndex : new List<Integer>{0, 7, 24, 49})
	{
		String sampleKey = key57dPrefix + sampleIndex;
		Object individualValue = cache57d.get(sampleKey);
		Assert.areEqual('bulkValue' + sampleIndex, individualValue, '57d: individual get() for key index ' + sampleIndex + ' should match');
	}

	Map<String, Object> bulkRetrieved57d = cache57d.getAll(bulkEntries57d.keySet());
	Assert.areEqual(entryCount57d, bulkRetrieved57d.size(), '57d: getAll should return exactly ' + entryCount57d + ' entries');
	for(String storedKey : bulkEntries57d.keySet())
	{
		Object expectedValue = bulkEntries57d.get(storedKey);
		Object actualValue = bulkRetrieved57d.get(storedKey);
		Assert.areEqual(expectedValue, actualValue, '57d: getAll value for key ' + storedKey + ' should match what was put');
	}

	Boolean removeAllResult57d = cache57d.removeAll(bulkEntries57d.keySet());
	Assert.isTrue(removeAllResult57d, '57d: removeAll should return true');

	Map<String, Object> postRemove57d = cache57d.getAll(bulkEntries57d.keySet());
	Assert.areEqual(0, postRemove57d.size(), '57d: getAll after removeAll should return an empty map');

	System.debug(LoggingLevel.INFO, '57d PASS: putAll(' + entryCount57d + ') + getAll round-trip + per-key get cross-check + removeAll all green');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '57d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('57d: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 57e — Single-transaction partition allocation reuse. Three sequential partition()
// factory calls in the same anon Apex transaction: each must return a non-null Store, each
// must report isCacheAvailable=true (the kern__Library partition is allocated), and each
// must successfully put/get a probe value. Each call to partition() returns a fresh DefaultCache
// instance with its own scopeProbeResults map, so each instance runs the put/get probe once;
// this scenario verifies the factory itself is idempotent and reusable within a single tx.
// True cross-transaction concurrency (two threads racing on the same key) is deferred to a
// managed @IsTest with two queueables (see header).
try
{
	final String defaultPartition57e = kern.UTIL_Cache.getPlatformCacheName();
	final String probeKey57e = 'sub57eProbe' + KEY_RUN_STAMP;

	for(Integer attempt = 0; attempt < 3; attempt++)
	{
		kern.UTIL_Cache.Store cache57e = kern.UTIL_Cache.partition(defaultPartition57e);
		Assert.isNotNull(cache57e, '57e: attempt ' + attempt + ' — partition() should return a non-null Store');
		Assert.isTrue(cache57e.isCacheAvailable(), '57e: attempt ' + attempt + ' — isCacheAvailable should be true for allocated partition "' + defaultPartition57e + '"');

		String iterationKey = probeKey57e + attempt;
		Boolean probePut57e = cache57e.put(iterationKey, 'attempt' + attempt);
		Assert.isTrue(probePut57e, '57e: attempt ' + attempt + ' — put should succeed');

		Object probeGet57e = cache57e.get(iterationKey);
		Assert.areEqual('attempt' + attempt, probeGet57e, '57e: attempt ' + attempt + ' — get should match');

		cache57e.remove(iterationKey);
	}

	System.debug(LoggingLevel.INFO, '57e PASS: 3 sequential partition("' + defaultPartition57e + '") calls all returned functional Stores in one tx');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '57e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('57e: ' + scenarioError.getMessage());
	fail++;
}

kern.TRG_Base.clearAllBypasses();

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 57: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 57 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 57 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 57 COMPLETE: All scenarios passed ===');
}
