// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Factory for Platform Cache instances with nested interface pattern.
 * Provides intelligent cache management with automatic fallback from Session to Org cache,
 * bulk operations, and user-scoped keys.
 *
 * Key Features:
 * - **Framework Safe**: Defaults to UTIL_System.getPlatformCacheName() for internal package usage.
 * - **Subscriber Ready**: Supports custom partitions via .withPartition().
 * - **Governor Friendly**: Uses putAll and getAll to minimize cache commits/reads.
 * - **Bulk Optimized**: getAll() uses native Platform Cache bulk retrieval for optimal performance.
 * - **Graceful Failure**: Silently handles missing partitions or cache unavailability.
 *
 * Performance Notes:
 * - getAll() and getFromCache() use optimized single-key get() instead of contains() + get() pattern.
 * - contains() uses get() instead of contains() to reduce network round-trips.
 * - putAll() and removeAll() iterate as Platform Cache does not support bulk operations with TTL.
 * - Each cache operation reduces round-trips by eliminating redundant contains() checks.
 *
 * **Concurrency model — non-atomic across transactions:**
 * All cache operations are per-transaction. Salesforce Platform Cache exposes NO
 * compare-and-swap, NO atomic-increment, and NO cross-transaction lock primitive — so a
 * read-modify-write pattern (e.g. `Integer current = (Integer)cache.get(KEY); cache.put(KEY, current + 1);`)
 * silently loses 80-95% of writes under realistic 50-100 parallel transaction load (last-writer-wins).
 * Empirically: the parallel-cache-contention extended load test runs 100 parallel HTTP POSTs each
 * incrementing the same counter; final counter is consistently `[1, 100]` rather than 100 — i.e. 85-94
 * lost updates per run. All 100 calls return `WRITE_SUCCESS` from their own transaction's perspective.
 * For counter-style use cases (rate limiters, dedupe caches, distributed semaphores) persist to a
 * custom object instead and use SOQL `FOR UPDATE` row locks; that is the only Salesforce-native atomic
 * primitive. See "Don't Use Cache for Counters or Semaphores" in the Utilities Developer Guide
 * (Platform Cache Framework → Best Practices) for the full pattern with the seed-the-row prerequisite.
 *
 * @see UTIL_Cache_TEST
 * @see UTIL_System
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date December 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_Cache.Store cache = UTIL_Cache.org();
 * cache.put('configKey', configValue, 3600);
 * Object cached = cache.get('configKey');
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.ExcessiveClassLength,PMD.AvoidBooleanMethodParameters,PMD.NcssTypeCount')
global inherited sharing class UTIL_Cache
{
	private static final Integer COMPRESSION_THRESHOLD = 4096; // Threshold in bytes for automatic compression (4KB). JSON compresses 80-90%, cache space is more scarce than CPU
	private static final Integer DEFAULT_ORG_TTL_SECONDS = 86400; // 24 hours
	private static final Integer DEFAULT_SESSION_TTL_SECONDS = 14400; // 4 hours
	@TestVisible
	private static final Integer MAXIMUM_ENTRY_SIZE = 1024 * 100; // Maximum serialized size in characters for a single cache entry (~100KB)
	@TestVisible
	private static final Integer MAXIMUM_HASH_KEY_CACHE_SIZE = 2000; //Only allow so many entries for local key to reduce memory usage
	private static final Integer MAXIMUM_KEY_LENGTH = 50; //The maximum length of a cache key
	private static final Integer ORG_MAXIMUM_TTL_SECONDS = 172800; // 48 hours
	private static final Integer ORG_MINIMUM_TTL_SECONDS = 300; // 5 minutes (platform constraint)
	private static final Integer SESSION_MAXIMUM_TTL_SECONDS = 28800; // 8 hours
	private static final Integer SESSION_MINIMUM_TTL_SECONDS = 300; // 5 minutes (platform constraint)
	private static final Map<String, String> KEY_HASH_CACHE = new Map<String, String>(); // Cache of original keys to hashed keys to avoid repeated hashing
	@TestVisible
	private static final String CACHE_PARTITION_NAME = 'Library';
	private static final String ZIP_ENTRY_NAME = 'data.json'; //Name of the zip entry used during compression and de-compression

	/**
	 * @description Per-transaction backing storage shared by every TransactionStore instance.
	 * Honest-lazy — only allocates the backing Map on first use, so transactions that never
	 * touch transaction-scope cache pay no construction cost. Static-by-platform-contract
	 * (Apex resets statics between transactions) is what gives the scope its name. Lives on
	 * the outer class because Apex forbids static fields on inner classes.
	 */
	private static final Map<String, Object> transactionStorage
	{
		get
		{
			if(transactionStorage == null)
			{
				transactionStorage = new Map<String, Object>();
			}
			return transactionStorage;
		}
		private set;
	}

	/**
	 * @description Test-only flag to simulate partition unavailability
	 */
	@TestVisible
	private static Boolean simulateNullPartition = false;

	/**
	 * @description Test-only flag to simulate cache get operation exceptions
	 */
	@TestVisible
	private static Boolean simulateGetException = false;

	/**
	 * @description Test-only flag to simulate cache put operation exceptions
	 */
	@TestVisible
	private static Boolean simulatePutException = false;

	/**
	 * @description Test-only flag to simulate scope probe exceptions
	 */
	@TestVisible
	private static Boolean simulateProbeException = false;

	/**
	 * @description Test-only flag to simulate compression failure
	 */
	@TestVisible
	private static Boolean simulateCompressionFailure = false;

	/**
	 * @description Cache type enumeration
	 *
	 * @since 1.0
	 */
	global enum Scope
	{
		/**
		 * @description Session cache (TTL: 5 minutes to 8 hours)
		 */
		SESSION,

		/**
		 * @description Org cache (TTL: 5 minutes to 48 hours)
		 */
		ORG,

		/**
		 * @description Auto-select dispatch: Session first, fallback to Org. **Durable-only** —
		 * this scope does not silently fall back to per-transaction storage when Platform Cache
		 * is unallocated. Subscribers that want graceful degradation use the
		 * autoWithTransactionFallback() factory instead.
		 */
		AUTO,

		/**
		 * @description Transaction cache (in-memory, lifetime = current Apex transaction).
		 * Used by inTransaction() and as the fallback tier in autoWithTransactionFallback().
		 * Never serializes; no key-name restrictions; no quota; always available.
		 * Identifier is `IN_TRANSACTION` because `TRANSACTION` is a reserved Apex identifier.
		 */
		IN_TRANSACTION
	}

	/**
	 * @description Operation status enumeration
	 *
	 * @since 1.0
	 */
	global enum Status
	{
		/**
		 * @description Read operation succeeded (all requested keys found)
		 */
		READ_SUCCESS,

		/**
		 * @description Write operation succeeded
		 */
		WRITE_SUCCESS,

		/**
		 * @description Remove operation succeeded
		 */
		REMOVE_SUCCESS,

		/**
		 * @description Cache miss (one or more keys not found, but operation was successful)
		 */
		CACHE_MISS,

		/**
		 * @description Cache partition not available or not configured
		 */
		CACHE_UNAVAILABLE,

		/**
		 * @description Read operation failed due to exception
		 */
		READ_FAILURE,

		/**
		 * @description Write operation failed due to exception
		 */
		WRITE_FAILURE,

		/**
		 * @description Remove operation failed due to exception
		 */
		REMOVE_FAILURE
	}

	/**
	 * @description Result of a cache operation with detailed status information
	 *
	 * @since 1.0
	 */
	global inherited sharing class OperationResult
	{
		/**
		 * @description Whether the operation succeeded (true for SUCCESS statuses and CACHE_MISS)
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.success;
		 * ```
		 */
		global Boolean success;

		/**
		 * @description Detailed status of the operation
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Status value = instance.status;
		 * ```
		 */
		global Status status;

		/**
		 * @description Cache type used (SESSION, ORG, or null if unavailable)
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Scope value = instance.cacheTypeUsed;
		 * ```
		 */
		global Scope cacheTypeUsed;

		/**
		 * @description Error message if operation failed
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.errorMessage;
		 * ```
		 */
		global String errorMessage;

		/**
		 * @description Number of keys requested (for bulk operations)
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.keysRequested;
		 * ```
		 */
		global Integer keysRequested;

		/**
		 * @description Number of keys found (for read operations)
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.keysFound;
		 * ```
		 */
		global Integer keysFound;

		/**
		 * @description Constructor for success result
		 *
		 * @param success Whether operation succeeded
		 * @param status Operation status
		 * @param cacheTypeUsed Cache type used
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_Cache.OperationResult instance = new UTIL_Cache.OperationResult(true, new Status(), new Scope());
		 * ```
		 */
		global OperationResult(Boolean success, Status status, Scope cacheTypeUsed)
		{
			this.success = success;
			this.status = status;
			this.cacheTypeUsed = cacheTypeUsed;
		}

		/**
		 * @description Constructor for failure result
		 *
		 * @param success Whether operation succeeded
		 * @param status Operation status
		 * @param cacheTypeAttempted Cache type attempted
		 * @param errorMessage Error message
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_Cache.OperationResult instance = new UTIL_Cache.OperationResult(true, new Status(), new Scope(), 'An error occurred');
		 * ```
		 */
		global OperationResult(Boolean success, Status status, Scope cacheTypeAttempted, String errorMessage)
		{
			this.success = success;
			this.status = status;
			cacheTypeUsed = cacheTypeAttempted;
			this.errorMessage = errorMessage;
		}
	}

	/**
	 * @description Wrapper for cached entries with validity tracking and automatic compression.
	 * Supports sub-300s TTL by embedding validity timestamps and lazy expiration checking.
	 * Automatically compresses large payloads to reduce cache memory usage.
	 *
	 * NOTE: This class is public (not global) as it's only used internally within the package.
	 *
	 * WRAPPER OVERHEAD TRADE-OFF:
	 * This wrapper adds metadata (validUntil, objectTypeName, cachedAt, etc.) to all cached values.
	 * For small primitives (Boolean, Integer, short Strings), the wrapper may be 3-5x larger than the actual data.
	 * This is an accepted trade-off for:
	 * - Unified sub-300s TTL support (validUntil logic)
	 * - Type-safe deserialization (objectTypeName)
	 * - Automatic compression for large payloads (saves significant cache space)
	 * If caching many small primitives is critical, consider using Platform Cache API directly.
	 */
	public inherited sharing class CacheEntry
	{
		/**
		 * @description Holds serialized JSON string (or Blob if compressed)
		 */
		public Object data;

		/**
		 * @description Timestamp (milliseconds) when entry expires
		 */
		public Long validUntil;

		/**
		 * @description Flag indicating whether data is compressed
		 */
		public Boolean isCompressed;

		/**
		 * @description Original data size in bytes (before compression)
		 */
		public Integer originalSize;

		/**
		 * @description When the cache snapshot was taken
		 */
		public Datetime cachedAt;

		/**
		 * @description Fully qualified type name for type-safe deserialization
		 */
		public String objectTypeName;

		/**
		 * @description Constructor that wraps a value with validity tracking and optional compression
		 *
		 * @param value The value to wrap
		 * @param validitySeconds How long the entry should be valid (actual expiry, not Platform Cache TTL)
		 */
		@SuppressWarnings('PMD.EmptyCatchBlock')
		public CacheEntry(Object value, Integer validitySeconds)
		{
			validUntil = System.currentTimeMillis() + (validitySeconds * 1000);
			cachedAt = Datetime.now();

			// Serialize once to measure size (avoid double serialization)
			String serialized = JSON.serialize(value);
			originalSize = serialized.length();

			// Store type information for type-safe deserialization
			objectTypeName = UTIL_System.getRuntimeTypeName(value);

			isCompressed = false;
			// Store serialized string (avoid double serialization by Salesforce)
			data = serialized;

			// Automatic compression for large payloads
			if(originalSize > COMPRESSION_THRESHOLD)
			{
				try
				{
					Blob compressed = compressData(serialized);

					// Safety check: Only use compression if it actually reduces size
					// Edge case: Random strings or already-compressed data may grow due to ZIP headers
					if(compressed.size() < originalSize)
					{
						isCompressed = true;
						data = compressed;
					}
				}
				catch(Exception error)
				{
					// Do nothing, use original serialized value if compression fails
				}
			}
		}

		/**
		 * @description Checks if the cached entry is still valid based on embedded timestamp
		 *
		 * @return True if entry has not expired
		 */
		public Boolean isValid()
		{
			return System.currentTimeMillis() < validUntil;
		}

		/**
		 * @description Extracts the actual data, decompressing and deserializing with type safety
		 *
		 * @return The unwrapped data with original type preserved when possible
		 */
		public Object unwrap()
		{
			String jsonString = isCompressed ? decompressData((Blob)data) : (String)data;

			try
			{
				return JSON.deserialize(jsonString, UTIL_System.getTypeForClassName(objectTypeName));
			}
			catch(Exception error)
			{
				//Revert to untyped
				return JSON.deserializeUntyped(jsonString);
			}
		}
	}

	/**
	 * @description Compresses a JSON string using ZIP compression
	 *
	 * @param jsonString The JSON string to compress
	 *
	 * @return Compressed data as Blob
	 */
	private static Blob compressData(String jsonString)
	{
		// Test simulation: Throw exception if simulateCompressionFailure flag is set
		if(simulateCompressionFailure)
		{
			throw new Cache.CacheException('Simulated compression failure');
		}

		Compression.ZipWriter zipWriter = new Compression.ZipWriter();
		zipWriter.addEntry(ZIP_ENTRY_NAME, Blob.valueOf(jsonString));
		return zipWriter.getArchive();
	}

	/**
	 * @description Decompresses a ZIP-compressed Blob back to JSON string
	 *
	 * @param compressedData The compressed Blob
	 *
	 * @return Decompressed JSON string
	 */
	private static String decompressData(Blob compressedData)
	{
		Compression.ZipReader zipReader = new Compression.ZipReader(compressedData);
		return zipReader.extract(ZIP_ENTRY_NAME).toString();
	}

	/**
	 * @description Interface for Platform Cache operations
	 *
	 * @since 1.0
	 */
	global interface Store
	{
		/**
		 * @description Sets the cache type preference (fluent API)
		 *
		 * @param cacheType The cache type to prefer (SESSION, ORG, AUTO)
		 *
		 * @return This instance
		 */
		Store withScope(Scope cacheType);

		/**
		 * @description Sets the partition name (fluent API)
		 *
		 * @param partitionName The fully qualified partition name (e.g., 'local.MyPartition')
		 *
		 * @return This instance
		 */
		Store withPartition(String partitionName);

		/**
		 * @description Enables or disables user-scoped keys (fluent API)
		 *
		 * @param userScoped Whether to scope keys by current user
		 *
		 * @return This instance
		 */
		Store withUserScope(Boolean userScoped);

		/**
		 * @description Stores a value in cache with default TTL.
		 *
		 * **Warning — non-atomic against concurrent writes.** Platform Cache exposes no
		 * compare-and-swap and no cross-transaction lock, so a read-modify-write loop
		 * (`get` → mutate → `put`) loses 80-95% of writes under 50-100 parallel transaction
		 * contention. For counter-style use cases (rate limiters, dedupe, semaphores) use a
		 * custom object with SOQL `FOR UPDATE` row locks instead.
		 *
		 * @param key The cache key
		 * @param value The value to cache
		 *
		 * @return True if stored successfully
		 */
		Boolean put(String key, Object value);

		/**
		 * @description Stores a value in cache with custom TTL.
		 *
		 * **Warning — non-atomic against concurrent writes.** Same caveat as the no-TTL
		 * overload: read-modify-write across parallel transactions silently loses writes.
		 * See the class-level "Concurrency model" note.
		 *
		 * @param key The cache key
		 * @param value The value to cache
		 * @param ttlSeconds TTL in seconds (null uses default)
		 *
		 * @return True if stored successfully
		 */
		Boolean put(String key, Object value, Integer ttlSeconds);

		/**
		 * @description Retrieves a value from cache.
		 *
		 * **Warning — read-modify-write is unsafe across parallel transactions.** A `get`
		 * paired with a subsequent `put` to mutate the value is non-atomic; concurrent
		 * transactions reading the same key see the same pre-mutation value and overwrite
		 * each other on `put`. See the class-level "Concurrency model" note.
		 *
		 * @param key The cache key
		 *
		 * @return The cached value or null if not found
		 */
		Object get(String key);

		/**
		 * @description Checks if a key exists in cache
		 *
		 * @param key The cache key
		 *
		 * @return True if key exists in cache
		 */
		Boolean contains(String key);

		/**
		 * @description Removes a value from cache
		 *
		 * @param key The cache key
		 *
		 * @return True if removed successfully
		 */
		Boolean remove(String key);

		/**
		 * @description Stores multiple values in cache with default TTL
		 *
		 * @param valuesMap Map of Key -> Value to store
		 *
		 * @return True if operation was attempted
		 */
		Boolean putAll(Map<String, Object> valuesMap);

		/**
		 * @description Stores multiple values in cache with custom TTL
		 *
		 * @param valuesMap Map of Key -> Value to store
		 * @param ttlSeconds TTL in seconds
		 *
		 * @return True if operation was attempted
		 */
		Boolean putAll(Map<String, Object> valuesMap, Integer ttlSeconds);

		/**
		 * @description Retrieves multiple values from cache
		 *
		 * @param keys Set of keys to retrieve
		 *
		 * @return Map of Key -> Value (found items only)
		 */
		Map<String, Object> getAll(Set<String> keys);

		/**
		 * @description Removes multiple keys from cache
		 *
		 * @param keys Set of keys to remove
		 *
		 * @return True if operation completed
		 */
		Boolean removeAll(Set<String> keys);

		/**
		 * @description Gets the result of the last cache operation for diagnostics
		 *
		 * @return Last operation result with detailed status information
		 */
		OperationResult getLastOperationResult();

		/**
		 * @description Checks if Platform Cache is available for the configured partition
		 *
		 * @return True if cache is available
		 */
		Boolean isCacheAvailable();
	}

	/**
	 * @description Creates a new cache instance backed by Platform Cache (Session → Org).
	 * Defaults to the Framework partition defined in UTIL_System.
	 *
	 * **Durable-only.** When Platform Cache is unallocated (Session and Org both unavailable),
	 * put/get operations return false / null and OperationResult reports Status.CACHE_UNAVAILABLE
	 * — the failure is loud and visible. This factory does NOT silently fall back to
	 * per-transaction in-memory storage. Use this factory when durability matters (security
	 * keys, distributed counters, cross-transaction state). UTIL_SessionEncryption is the
	 * canonical durability-required caller.
	 *
	 * For graceful degradation to per-transaction memory when Platform Cache is missing, use
	 * autoWithTransactionFallback() instead.
	 *
	 * @return New cache instance
	 *
	 * @since 1.0
	 *
	 * @example
	 * Basic usage with default configuration:
	 * ```apex
	 * UTIL_Cache.Store cache = UTIL_Cache.auto();
	 * cache.put('myKey', 'myValue');
	 * String value = (String)cache.get('myKey');
	 * ```
	 */
	global static Store auto()
	{
		DefaultCache cacheInstance = new DefaultCache();
		cacheInstance.configuration = new CacheConfiguration();
		return cacheInstance;
	}

	/**
	 * @description Convenience factory for Org cache with default partition.
	 * "Easy Button" for the most common use case - persistent org-wide caching.
	 *
	 * @return Org cache instance using framework default partition
	 *
	 * @since 1.0
	 *
	 * @example
	 * Quick access to Org cache for persistent data:
	 * ```apex
	 * UTIL_Cache.Store cache = UTIL_Cache.org();
	 * cache.put('globalConfig', myConfigObject);
	 * ```
	 */
	global static Store org()
	{
		return auto().withScope(Scope.ORG);
	}

	/**
	 * @description Convenience factory for Session cache with default partition.
	 * "Easy Button" for session-scoped caching (max 8 hours).
	 *
	 * @return Session cache instance using framework default partition
	 *
	 * @since 1.0
	 *
	 * @example
	 * Quick access to Session cache for temporary user data:
	 * ```apex
	 * UTIL_Cache.Store cache = UTIL_Cache.session();
	 * cache.put('userPreferences', prefsMap);
	 * ```
	 */
	global static Store session()
	{
		return auto().withScope(Scope.SESSION);
	}

	/**
	 * @description Convenience factory for custom partition (subscriber orgs).
	 * "Easy Button" for subscribers to use their local partitions.
	 *
	 * @param partitionName Fully qualified partition name (e.g., 'local.MyPartition')
	 *
	 * @return Cache instance configured for the specified partition
	 *
	 * @since 1.0
	 *
	 * @example
	 * Subscriber org using custom partition:
	 * ```apex
	 * UTIL_Cache.Store cache = UTIL_Cache.partition('local.MyPartition');
	 * cache.put('subscriberData', myData);
	 * ```
	 */
	global static Store partition(String partitionName)
	{
		return auto().withPartition(partitionName);
	}

	/**
	 * @description Convenience factory for transaction-scope cache (in-memory, per-Apex-transaction).
	 * Use for memorizing expensive describes, lazy-loaded singletons, or any value worth computing
	 * once per request but that does not need to survive into the next transaction.
	 *
	 * Unlike SESSION and ORG, transaction cache:
	 * - Never serializes (no JSON round-trips, no compression).
	 * - Has no key-name restrictions imposed by Platform Cache.
	 * - Has no quota or partition allocation requirements.
	 * - Is always available (isCacheAvailable() returns true unconditionally).
	 * - Ignores ttlSeconds — implicit TTL is end-of-transaction.
	 *
	 * Storage is shared across every inTransaction()-returned Store within the same transaction;
	 * each Store instance has its own getLastOperationResult() so independent callers do not
	 * trample each other's diagnostic state.
	 *
	 * @return Store backed by the per-transaction in-memory Map
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_Cache.Store cache = UTIL_Cache.inTransaction();
	 * cache.put('expensiveDescribe', myDescribeResult);
	 * Object cached = cache.get('expensiveDescribe');
	 * ```
	 */
	global static Store inTransaction()
	{
		return new TransactionStore();
	}

	/**
	 * @description Returns a Store that tries Session → Org Platform Cache first and falls back
	 * to per-transaction in-memory storage when no Platform Cache scope is available.
	 *
	 * Use this factory when graceful degradation matters more than strict durability — e.g.
	 * memorizing an expensive describe that benefits from cross-request reuse when available
	 * but does not break if Platform Cache is unallocated.
	 *
	 * Behavior:
	 * - When Platform Cache is allocated: identical to auto() (Session → Org).
	 * - When neither Platform Cache scope is allocated: the call succeeds via IN_TRANSACTION
	 *   scope. OperationResult.cacheTypeUsed reports the actual scope used (IN_TRANSACTION
	 *   when the fallback fired) so callers can detect the degraded path.
	 * - Durability-critical callers (security keys, distributed state, cross-transaction
	 *   counters) MUST use auto() — not this factory — so the loud failure signal stays loud
	 *   when Platform Cache is missing.
	 *
	 * @return Store with Session → Org → Transaction fallback chain
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_Cache.Store cache = UTIL_Cache.autoWithTransactionFallback();
	 * cache.put('expensiveDescribe', describeResult);
	 * UTIL_Cache.OperationResult result = cache.getLastOperationResult();
	 * if(result.cacheTypeUsed == UTIL_Cache.Scope.IN_TRANSACTION)
	 * {
	 *     // Degraded — Platform Cache unallocated. Cache works for this transaction only.
	 * }
	 * ```
	 */
	global static Store autoWithTransactionFallback()
	{
		return new CompositeStore();
	}

	/**
	 * @description Checks if Platform Cache is available (static utility)
	 *
	 * @return True if any cache type is available
	 *
	 * @since 1.0
	 *
	 * @example
	 * Check if Platform Cache is configured in the org:
	 * ```apex
	 * if(UTIL_Cache.isAvailable())
	 * {
	 *     UTIL_Cache.Store cache = UTIL_Cache.auto();
	 *     cache.put('myKey', 'myValue');
	 * }
	 * else
	 * {
	 *     System.debug('Platform Cache not configured');
	 * }
	 * ```
	 */
	global static Boolean isAvailable()
	{
		return isAvailable(Scope.AUTO);
	}

	/**
	 * @description Checks if a specific cache type is available (static utility)
	 *
	 * @param cacheType The cache type to check
	 *
	 * @return True if the cache type is available
	 *
	 * @since 1.0
	 *
	 * @example
	 * Check if a specific cache type is available:
	 * ```apex
	 * if(UTIL_Cache.isAvailable(UTIL_Cache.Scope.SESSION))
	 * {
	 *     System.debug('Session cache is available');
	 * }
	 * if(UTIL_Cache.isAvailable(UTIL_Cache.Scope.ORG))
	 * {
	 *     System.debug('Org cache is available');
	 * }
	 * ```
	 */
	global static Boolean isAvailable(Scope cacheType)
	{
		Store cache = auto();
		DefaultCache defaultCacheInstance = (DefaultCache)cache;
		return defaultCacheInstance.isCacheAvailableForType(cacheType);
	}

	/**
	 * @description Checks whether the cache partition has capacity allocated by performing
	 * a put/get round-trip on each scope independently. Tests Org cache first, then Session.
	 * Returns true if either scope can store and retrieve a value.
	 *
	 * This approach avoids the AUTO mode fallback issue where Session put reports success
	 * (partition exists) but silently drops data when 0 capacity is allocated.
	 *
	 * @return True if at least one cache scope (Org or Session) is functional
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * if(UTIL_Cache.isAllocated())
	 * {
	 *     System.debug('Platform Cache is functional');
	 * }
	 * ```
	 */
	global static Boolean isAllocated()
	{
		return isProbeSuccessful(org()) || isProbeSuccessful(session());
	}

	/**
	 * @description Checks whether the Organisation cache scope has capacity allocated by performing
	 * a put/get round-trip probe.
	 *
	 * @return True if Organisation cache can store and retrieve data
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * if(UTIL_Cache.isOrgAllocated())
	 * {
	 *     System.debug('Organisation Cache is functional');
	 * }
	 * ```
	 */
	global static Boolean isOrgAllocated()
	{
		return isProbeSuccessful(org());
	}

	/**
	 * @description Checks whether the Session cache scope has capacity allocated by performing
	 * a put/get round-trip probe.
	 *
	 * @return True if Session cache can store and retrieve data
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * if(UTIL_Cache.isSessionAllocated())
	 * {
	 *     System.debug('Session Cache is functional');
	 * }
	 * ```
	 */
	global static Boolean isSessionAllocated()
	{
		return isProbeSuccessful(session());
	}

	/**
	 * @description Performs a put/get round-trip probe on a specific cache scope
	 * to verify it can actually store and retrieve data. All Store operations
	 * handle exceptions internally, so no try-catch is needed here.
	 *
	 * @param cache The scoped cache Store instance to probe
	 *
	 * @return True if the probe value was stored and retrieved successfully
	 */
	private static Boolean isProbeSuccessful(Store cache)
	{
		String probeKey = 'HealthProbe';
		String probeValue = 'ok';

		cache.put(probeKey, probeValue);

		Object result = cache.get(probeKey);
		cache.remove(probeKey);

		return probeValue.equals(result);
	}

	/**
	 * @description Cache configuration class
	 */
	@TestVisible
	private class CacheConfiguration
	{
		/**
		 * @description Preferred cache type
		 */
		public Scope preferredScope;

		/**
		 * @description Partition name
		 */
		public String partitionName;

		/**
		 * @description Whether to scope keys by user
		 */
		public Boolean useUserScope;

		/**
		 * @description Default constructor
		 */
		public CacheConfiguration()
		{
			preferredScope = Scope.AUTO;
			partitionName = getPlatformCacheName();
			useUserScope = false;
		}
	}

	/**
	 * @description Default implementation of Store interface
	 */
	@TestVisible
	@SuppressWarnings('PMD.CyclomaticComplexity')
	private class DefaultCache implements Store
	{
		/**
		 * @description Configuration for this cache instance
		 */
		@TestVisible
		private CacheConfiguration configuration;

		/**
		 * @description Last operation result (for diagnostic purposes)
		 */
		@TestVisible
		private OperationResult lastOperationResult;

		/**
		 * @description Cached results of per-scope round-trip probes. Avoids repeating the probe
		 * on every put() call within the same transaction.
		 */
		private final Map<Scope, Boolean> scopeProbeResults = new Map<Scope, Boolean>();

		/**
		 * @description Sanitizes a cache key to meet Platform Cache requirements:
		 * - Alphanumeric only (no underscores, hyphens, or special characters)
		 * - Maximum 50 characters
		 *
		 * Keys are always hashed for security (may contain sensitive data) and to ensure
		 * consistency. Hashed keys are cached in memory to avoid repeated hashing operations.
		 *
		 * Uses MD5 with hex encoding to produce 32-character alphanumeric keys.
		 *
		 * @param key The original key
		 *
		 * @return A valid Platform Cache key (32 hex characters)
		 */
		/**
		 * @description Sanitizes a cache key - uses raw key if safe, hashes complex keys
		 * This hybrid approach preserves debuggability in Platform Cache Diagnostics for clean keys
		 *
		 * @param key The key to sanitize
		 *
		 * @return Safe cache key (raw or hashed)
		 */
		@TestVisible
		private String sanitizeKey(String key)
		{
			// Validate key is not null or empty
			if(String.isBlank(key))
			{
				throw new Cache.InvalidParamException('Invalid Key, Key cannot be null or empty');
			}

			// Return raw key if it's already safe (alphanumeric/hyphen/underscore) and reasonably short
			// This keeps the Cache Diagnostics page readable for most common use cases
			if(key.length() <= MAXIMUM_KEY_LENGTH && key.isAlphanumeric())
			{
				return key;
			}

			// Check if we've already hashed this complex key
			String hashedKey = KEY_HASH_CACHE.get(key);

			if(hashedKey == null)
			{
				hashedKey = UTIL_Crypto.generateMD5Hash(key);

				// Prevent heap leak: clear cache if it grows too large
				if(KEY_HASH_CACHE.size() > MAXIMUM_HASH_KEY_CACHE_SIZE)
				{
					KEY_HASH_CACHE.clear();
				}

				// Cache the result to avoid repeated hashing
				KEY_HASH_CACHE.put(key, hashedKey);
			}

			return hashedKey;
		}

		/**
		 * @description Sets the cache type preference (fluent API)
		 *
		 * @param cacheType The cache type to prefer (SESSION, ORG, AUTO)
		 *
		 * @return This instance
		 *
		 * @example
		 * Use only Org cache for data that needs to persist across user sessions:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto()
		 *     .withScope(UTIL_Cache.Scope.ORG);
		 * cache.put('sharedConfig', myConfigObject);
		 * ```
		 */
		public Store withScope(Scope cacheType)
		{
			configuration.preferredScope = cacheType;
			return this;
		}

		/**
		 * @description Sets the partition name (fluent API).
		 * Use this for Subscriber Org usage to target local partitions.
		 *
		 * @param partitionName The fully qualified partition name (e.g., 'local.MyPartition')
		 *
		 * @return This instance
		 *
		 * @example
		 * Subscriber org using custom partition:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto()
		 *     .withPartition('local.MyCustomPartition');
		 * cache.put('subscriberData', myData);
		 * ```
		 */
		public Store withPartition(String partitionName)
		{
			if(String.isNotBlank(partitionName))
			{
				configuration.partitionName = partitionName;
			}
			return this;
		}

		/**
		 * @description Enables or disables user-scoped keys (fluent API).
		 * Useful for caching per-user data in the Org cache.
		 *
		 * @param userScoped Whether to scope keys by current user
		 *
		 * @return This instance
		 *
		 * @example
		 * Cache user-specific preferences in Org cache (each user gets their own cache namespace):
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto()
		 *     .withScope(UTIL_Cache.Scope.ORG)
		 *     .withUserScope(true);
		 * cache.put('userPreferences', userPrefsMap);
		 * ```
		 */
		public Store withUserScope(Boolean userScoped)
		{
			configuration.useUserScope = userScoped;
			return this;
		}

		/**
		 * @description Stores a value in cache with default TTL
		 *
		 * @param key The cache key
		 * @param value The value to cache
		 *
		 * @return True if stored successfully
		 *
		 * @example
		 * Store a simple value with default TTL (4 hours for Session, 24 hours for Org):
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * Boolean success = cache.put('accountName', 'Acme Corp');
		 * ```
		 */
		public Boolean put(String key, Object value)
		{
			return put(key, value, null);
		}

		/**
		 * @description Stores a value in cache with custom TTL
		 *
		 * @param key The cache key
		 * @param value The value to cache
		 * @param ttlSeconds TTL in seconds (null uses default)
		 *
		 * @return True if stored successfully
		 *
		 * @example
		 * Store with custom TTL (1 hour):
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * Boolean success = cache.put('temporaryToken', myToken, 3600);
		 * ```
		 */
		public Boolean put(String key, Object value, Integer ttlSeconds)
		{
			if(String.isBlank(key))
			{
				return false;
			}

			Map<String, Object> singleEntry = new Map<String, Object> {key => value};
			return putAll(singleEntry, ttlSeconds);
		}

		/**
		 * @description Retrieves a value from cache
		 *
		 * @param key The cache key
		 *
		 * @return The cached value or null if not found
		 *
		 * @example
		 * Retrieve and cast cached value:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * String accountName = (String)cache.get('accountName');
		 * if(accountName != null)
		 * {
		 *     System.debug('Found cached account: ' + accountName);
		 * }
		 * ```
		 */
		public Object get(String key)
		{
			if(String.isBlank(key))
			{
				return null;
			}

			Map<String, Object> results = getAll(new Set<String> {key});
			return results.get(key);
		}

		/**
		 * @description Checks if a key exists in cache
		 *
		 * @param key The cache key
		 *
		 * @return True if key exists in cache
		 *
		 * @example
		 * Check before retrieving:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * if(cache.contains('accountName'))
		 * {
		 *     String name = (String)cache.get('accountName');
		 * }
		 * ```
		 */
		public Boolean contains(String key)
		{
			if(String.isBlank(key))
			{
				return false;
			}

			String scopedKey = getScopedKey(key);
			Boolean exists = false;

			if(isSessionPreferred())
			{
				exists = containsInCache(Scope.SESSION, scopedKey);
				if(exists)
				{
					return true;
				}
			}

			if(isOrgPreferred())
			{
				exists = containsInCache(Scope.ORG, scopedKey);
			}

			return exists;
		}

		/**
		 * @description Removes a value from cache
		 *
		 * @param key The cache key
		 *
		 * @return True if removed successfully
		 *
		 * @example
		 * Remove cached value when no longer needed:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * Boolean removed = cache.remove('temporaryToken');
		 * ```
		 */
		public Boolean remove(String key)
		{
			if(String.isBlank(key))
			{
				return false;
			}
			return removeAll(new Set<String> {key});
		}

		/**
		 * @description Stores multiple values in cache with default TTL
		 *
		 * @param valuesMap Map of Key -> Value to store
		 *
		 * @return True if operation was attempted
		 *
		 * @example
		 * Store multiple values efficiently:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * Map<String, Object> data = new Map<String, Object>
		 * {
		 *     'account1' => 'Acme Corp',
		 *     'account2' => 'Global Industries',
		 *     'account3' => 'Tech Solutions'
		 * };
		 * Boolean success = cache.putAll(data);
		 * ```
		 */
		public Boolean putAll(Map<String, Object> valuesMap)
		{
			return putAll(valuesMap, null);
		}

		/**
		 * @description Stores multiple values in cache with custom TTL
		 *
		 * @param valuesMap Map of Key -> Value to store
		 * @param ttlSeconds TTL in seconds
		 *
		 * @return True if operation was attempted
		 *
		 * @example
		 * Store multiple values with custom TTL (2 hours):
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * Map<String, Object> tempData = new Map<String, Object>
		 * {
		 *     'sessionToken' => token1,
		 *     'apiKey' => key1
		 * };
		 * Boolean success = cache.putAll(tempData, 7200);
		 * ```
		 */
		public Boolean putAll(Map<String, Object> valuesMap, Integer ttlSeconds)
		{
			if(valuesMap == null || valuesMap.isEmpty())
			{
				return false;
			}

			Map<String, Object> scopedMap = new Map<String, Object>();
			for(String key : valuesMap.keySet())
			{
				scopedMap.put(getScopedKey(key), valuesMap.get(key));
			}

			Boolean success = false;

			if(isSessionPreferred())
			{
				success = putToCache(Scope.SESSION, scopedMap, ttlSeconds);
			}

			if(isOrgPreferred())
			{
				success = putToCache(Scope.ORG, scopedMap, ttlSeconds) || success;
			}

			return success;
		}

		/**
		 * @description Retrieves multiple values from cache
		 *
		 * @param keys Set of keys to retrieve
		 *
		 * @return Map of Key -> Value (found items only)
		 *
		 * @example
		 * Retrieve multiple values efficiently:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * Set<String> requestedKeys = new Set<String>{'account1', 'account2', 'account3'};
		 * Map<String, Object> results = cache.getAll(requestedKeys);
		 * for(String key : results.keySet())
		 * {
		 *     System.debug(key + ': ' + results.get(key));
		 * }
		 * ```
		 */
		public Map<String, Object> getAll(Set<String> keys)
		{
			Map<String, Object> results = new Map<String, Object>();
			if(keys == null || keys.isEmpty())
			{
				return results;
			}

			Map<String, String> scopedToOriginalKey = new Map<String, String>();
			for(String key : keys)
			{
				scopedToOriginalKey.put(getScopedKey(key), key);
			}
			Set<String> scopedKeys = scopedToOriginalKey.keySet();

			if(isSessionPreferred())
			{
				Map<String, Object> sessionResults = getFromCache(Scope.SESSION, scopedKeys);
				if(sessionResults != null)
				{
					for(String scopedKey : sessionResults.keySet())
					{
						results.put(scopedToOriginalKey.get(scopedKey), sessionResults.get(scopedKey));
					}
				}
			}

			if(results.size() == keys.size() || !isOrgPreferred())
			{
				return results;
			}

			Set<String> missingScopedKeys = new Set<String>();
			for(String scopedKey : scopedKeys)
			{
				if(!results.containsKey(scopedToOriginalKey.get(scopedKey)))
				{
					missingScopedKeys.add(scopedKey);
				}
			}

			if(!missingScopedKeys.isEmpty())
			{
				Map<String, Object> orgResults = getFromCache(Scope.ORG, missingScopedKeys);
				if(orgResults != null)
				{
					for(String scopedKey : orgResults.keySet())
					{
						results.put(scopedToOriginalKey.get(scopedKey), orgResults.get(scopedKey));
					}
				}
			}

			return results;
		}

		/**
		 * @description Removes multiple keys from cache
		 *
		 * @param keys Set of keys to remove
		 *
		 * @return True if operation completed
		 *
		 * @example
		 * Remove multiple keys efficiently:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * Set<String> keysToRemove = new Set<String>{'tempToken1', 'tempToken2', 'tempToken3'};
		 * Boolean removed = cache.removeAll(keysToRemove);
		 * ```
		 */
		public Boolean removeAll(Set<String> keys)
		{
			if(keys == null || keys.isEmpty())
			{
				return false;
			}

			Set<String> scopedKeys = new Set<String>();
			for(String key : keys)
			{
				scopedKeys.add(getScopedKey(key));
			}

			Boolean removed = false;

			if(isSessionPreferred())
			{
				removed = removeFromCache(Scope.SESSION, scopedKeys) || removed;
			}

			if(isOrgPreferred())
			{
				removed = removeFromCache(Scope.ORG, scopedKeys) || removed;
			}

			return removed;
		}

		/**
		 * @description Gets the result of the last cache operation for diagnostics
		 *
		 * @return Last operation result with detailed status information
		 *
		 * @example
		 * Check operation result for diagnostics:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto();
		 * Boolean success = cache.put('myKey', 'myValue');
		 * UTIL_Cache.OperationResult result = cache.getLastOperationResult();
		 * if(!result.success)
		 * {
		 *     System.debug('Cache operation failed: ' + result.status);
		 *     System.debug('Error: ' + result.errorMessage);
		 * }
		 * ```
		 */
		public OperationResult getLastOperationResult()
		{
			return lastOperationResult;
		}

		/**
		 * @description Checks if Platform Cache is available for the configured partition
		 *
		 * @return True if cache is available
		 *
		 * @example
		 * Check if cache is available before using:
		 * ```apex
		 * UTIL_Cache.Store cache = UTIL_Cache.auto()
		 *     .withPartition('local.MyPartition');
		 * if(cache.isCacheAvailable())
		 * {
		 *     cache.put('myKey', 'myValue');
		 * }
		 * ```
		 */
		public Boolean isCacheAvailable()
		{
			return isCacheAvailableForType(configuration.preferredScope);
		}

		/**
		 * @description Checks if Session cache is preferred based on configuration
		 *
		 * @return True if Session cache should be used
		 */
		private Boolean isSessionPreferred()
		{
			return configuration.preferredScope == Scope.AUTO || configuration.preferredScope == Scope.SESSION;
		}

		/**
		 * @description Checks if Org cache is preferred based on configuration
		 *
		 * @return True if Org cache should be used
		 */
		private Boolean isOrgPreferred()
		{
			return configuration.preferredScope == Scope.AUTO || configuration.preferredScope == Scope.ORG;
		}

		/**
		 * @description Creates a user-scoped key if user scoping is enabled
		 *
		 * @param key The original cache key
		 *
		 * @return The scoped key (with user ID prefix if user scoping is enabled)
		 */
		private String getScopedKey(String key)
		{
			if(configuration.useUserScope)
			{
				return UserInfo.getUserId() + key;
			}
			return key;
		}

		/**
		 * @description Helper method to resolve the specific cache partition instance.
		 * Helps avoid code duplication by treating Session and Org partitions polymorphically via Cache.Partition.
		 *
		 * @param cacheType The type of cache (SESSION or ORG) to retrieve the partition for
		 *
		 * @return The Cache.Partition instance or null if not found
		 */
		private Cache.Partition getPartitionInstance(Scope cacheType)
		{
			if(simulateNullPartition)
			{
				return null;
			}

			Cache.Partition partition;

			switch on cacheType
			{
				when SESSION
				{
					partition = Cache.Session.getPartition(configuration.partitionName);
				}
				when ORG
				{
					partition = Cache.Org.getPartition(configuration.partitionName);
				}
			}

			return partition;
		}

		/**
		 * @description Performs a one-time put/get round-trip probe to verify that a cache scope
		 * can actually store and retrieve data. The result is cached in scopeProbeResults so
		 * subsequent calls within the same transaction skip the probe.
		 *
		 * @param cacheType The cache scope to probe (SESSION or ORG)
		 * @param partition The resolved partition instance (must not be null)
		 *
		 * @return True if the scope can store and retrieve data
		 */
		private Boolean isScopeFunctional(Scope cacheType, Cache.Partition partition)
		{
			if(scopeProbeResults.containsKey(cacheType))
			{
				return scopeProbeResults.get(cacheType);
			}

			Boolean functional = false;
			String probeKey = 'ScopeProbe';
			String probeValue = 'ok';

			try
			{
				if(simulateProbeException)
				{
					throw new Cache.CacheException('Simulated scope probe exception');
				}

				partition.put(probeKey, probeValue, 300);
				Object retrieved = partition.get(probeKey);
				partition.remove(probeKey);
				functional = probeValue.equals(retrieved);
			}
			catch(Exception error)
			{
				functional = false;
			}

			scopeProbeResults.put(cacheType, functional);
			return functional;
		}

		/**
		 * @description Stores values in the specified cache type
		 *
		 * @param cacheType The cache type to use (SESSION or ORG)
		 * @param values Map of scoped keys to values
		 * @param ttlSeconds Time-to-live in seconds (null uses default)
		 *
		 * @return True if successful
		 */
		private Boolean putToCache(Scope cacheType, Map<String, Object> values, Integer ttlSeconds)
		{
			try
			{
				Cache.Partition partition = getPartitionInstance(cacheType);

				// Test simulation: Throw exception if simulatePutException flag is set
				if(simulatePutException)
				{
					throw new Cache.CacheException('Simulated cache put exception');
				}

				if(partition != null)
				{
					if(!isScopeFunctional(cacheType, partition))
					{
						lastOperationResult = new OperationResult(false, Status.CACHE_UNAVAILABLE, cacheType,
								'Cache scope ' + cacheType + ' has no capacity allocated on partition: ' + configuration.partitionName);
						return false;
					}

					Integer defaultTTL = (cacheType == UTIL_Cache.Scope.SESSION) ? DEFAULT_SESSION_TTL_SECONDS : DEFAULT_ORG_TTL_SECONDS;
					Integer maxTTL = (cacheType == UTIL_Cache.Scope.SESSION) ? SESSION_MAXIMUM_TTL_SECONDS : ORG_MAXIMUM_TTL_SECONDS;
					Integer minTTL = (cacheType == UTIL_Cache.Scope.SESSION) ? SESSION_MINIMUM_TTL_SECONDS : ORG_MINIMUM_TTL_SECONDS;
					Integer platformCacheTTL = ttlSeconds != null ? Math.max(minTTL, Math.min(ttlSeconds, maxTTL)) : defaultTTL;

					// Determine actual validity period for the wrapper (may be shorter than Platform Cache TTL)
					Integer actualValiditySeconds = ttlSeconds != null ? ttlSeconds : defaultTTL;

					for(String key : values.keySet())
					{
						String sanitizedKey = sanitizeKey(key);
						Object value = values.get(key);

						// Wrap value in CacheEntryWrapper with validity tracking and compression
						CacheEntry wrapper = new CacheEntry(value, actualValiditySeconds);

						String serialized = JSON.serialize(wrapper);

						if(serialized.length() > MAXIMUM_ENTRY_SIZE)
						{
							lastOperationResult = new OperationResult(false, Status.WRITE_FAILURE, cacheType,
									'Cache entry exceeds maximum size (' + MAXIMUM_ENTRY_SIZE + ' chars): ' + key);
							return false;
						}

						partition.put(sanitizedKey, wrapper, platformCacheTTL);
					}

					lastOperationResult = new OperationResult(true, Status.WRITE_SUCCESS, cacheType);
					return true;
				}
				else
				{
					lastOperationResult = new OperationResult(false, Status.CACHE_UNAVAILABLE, cacheType, 'Cache partition not available: ' + configuration.partitionName);
				}
			}
			catch(Exception error)
			{
				String errorMsg = 'Write operation failed for ' + cacheType + ' [' + configuration.partitionName + ']: ' + error.getMessage();
				lastOperationResult = new OperationResult(false, Status.WRITE_FAILURE, cacheType, errorMsg);
			}
			return false;
		}

		/**
		 * @description Retrieves values from the specified cache type
		 *
		 * @param cacheType The cache type to use (SESSION or ORG)
		 * @param keys Set of scoped keys to retrieve
		 *
		 * @return Map of keys to values (found items only)
		 */
		private Map<String, Object> getFromCache(Scope cacheType, Set<String> keys)
		{
			Map<String, Object> results = new Map<String, Object>();
			try
			{
				Cache.Partition partition = getPartitionInstance(cacheType);

				// Test simulation: Throw exception if simulateGetException flag is set
				if(simulateGetException)
				{
					throw new Cache.CacheException('Simulated cache get exception');
				}

				if(partition != null)
				{
					for(String key : keys)
					{
						String sanitizedKey = sanitizeKey(key);
						Object cachedValue = partition.get(sanitizedKey);

						// Skip null values
						if(cachedValue == null)
						{
							continue;
						}

						// All cached values are wrapped in CacheEntryWrapper
						CacheEntry wrapper = (CacheEntry)cachedValue;

						// Check if entry is still valid (lazy expiration)
						if(wrapper.isValid())
						{
							// Unwrap and decompress if needed
							results.put(key, wrapper.unwrap());
						}
					}

					if(results.size() == keys.size())
					{
						lastOperationResult = new OperationResult(true, Status.READ_SUCCESS, cacheType);
					}
					else
					{
						lastOperationResult = new OperationResult(true, Status.CACHE_MISS, cacheType);
						lastOperationResult.keysRequested = keys.size();
						lastOperationResult.keysFound = results.size();
					}
				}
				else
				{
					lastOperationResult = new OperationResult(false, Status.CACHE_UNAVAILABLE, cacheType, 'Cache partition not available: ' + configuration.partitionName);
				}
			}
			catch(Exception error)
			{
				String errorMsg = 'Read operation failed for ' + cacheType + ' [' + configuration.partitionName + ']: ' + error.getMessage();
				lastOperationResult = new OperationResult(false, Status.READ_FAILURE, cacheType, errorMsg);
			}
			return results;
		}

		/**
		 * @description Checks if a key exists in the specified cache type
		 *
		 * @param cacheType The cache type to check (SESSION or ORG)
		 * @param key The scoped key to check
		 *
		 * @return True if key exists
		 */
		@SuppressWarnings('PMD.EmptyCatchBlock')
		private Boolean containsInCache(Scope cacheType, String key)
		{
			try
			{
				Cache.Partition partition = getPartitionInstance(cacheType);
				if(partition != null)
				{
					String sanitizedKey = sanitizeKey(key);
					Object cachedValue = partition.get(sanitizedKey);
					return cachedValue != null && ((CacheEntry)cachedValue).isValid();
				}
			}
			catch(Exception error)
			{
				// Safe to suppress
			}
			return false;
		}

		/**
		 * @description Removes keys from the specified cache type
		 *
		 * @param cacheType The cache type to use (SESSION or ORG)
		 * @param keys Set of scoped keys to remove
		 *
		 * @return True if successful
		 */
		private Boolean removeFromCache(Scope cacheType, Set<String> keys)
		{
			try
			{
				Cache.Partition partition = getPartitionInstance(cacheType);

				if(partition != null)
				{
					for(String key : keys)
					{
						String sanitizedKey = sanitizeKey(key);
						partition.remove(sanitizedKey);
					}

					lastOperationResult = new OperationResult(true, Status.REMOVE_SUCCESS, cacheType);
					return true;
				}
				else
				{
					lastOperationResult = new OperationResult(false, Status.CACHE_UNAVAILABLE, cacheType, 'Cache partition not available: ' + configuration.partitionName);
				}
			}
			catch(Exception error)
			{
				String errorMsg = 'Remove operation failed for ' + cacheType + ' [' + configuration.partitionName + ']: ' + error.getMessage();
				lastOperationResult = new OperationResult(false, Status.REMOVE_FAILURE, cacheType, errorMsg);
			}
			return false;
		}

		/**
		 * @description Checks if a specific cache type is available
		 *
		 * @param cacheType The cache type to check (SESSION, ORG, or AUTO)
		 *
		 * @return True if cache type is available
		 */
		@SuppressWarnings('PMD.EmptyCatchBlock')
		@TestVisible
		private Boolean isCacheAvailableForType(Scope cacheType)
		{
			if(cacheType == UTIL_Cache.Scope.AUTO)
			{
				return isCacheAvailableForType(UTIL_Cache.Scope.SESSION) || isCacheAvailableForType(UTIL_Cache.Scope.ORG);
			}

			try
			{
				Cache.Partition partition = getPartitionInstance(cacheType);
				return partition?.isAvailable() == true;
			}
			catch(Exception error)
			{
				// Safe to suppress
			}
			return false;
		}
	}

	/**
	 * @description Store implementation backed by a per-transaction in-memory Map. Statics reset
	 * between Apex transactions (platform contract), which is what gives this scope its name.
	 *
	 * Multiple TransactionStore instances within the same transaction share the same STORAGE
	 * map but each has its own lastOperationResult so independent callers do not see each
	 * other's diagnostic state.
	 */
	@TestVisible
	private class TransactionStore implements Store
	{
		/**
		 * @description Per-instance diagnostic. Per-instance (not static) so independent
		 * callers do not trample each other within one transaction.
		 */
		private OperationResult lastOperationResult;

		/**
		 * @description No-op fluent setter — transaction scope has no scope preference.
		 *
		 * @param cacheType Ignored.
		 *
		 * @return This instance for fluent chaining.
		 */
		public Store withScope(Scope cacheType)
		{
			return this;
		}

		/**
		 * @description No-op fluent setter — transaction scope has no Platform Cache partition.
		 *
		 * @param partitionName Ignored.
		 *
		 * @return This instance for fluent chaining.
		 */
		public Store withPartition(String partitionName)
		{
			return this;
		}

		/**
		 * @description No-op fluent setter — transaction scope storage is implicitly per-request, not per-user.
		 *
		 * @param userScoped Ignored.
		 *
		 * @return This instance for fluent chaining.
		 */
		public Store withUserScope(Boolean userScoped)
		{
			return this;
		}

		/**
		 * @description Stores a value in the per-transaction Map with no TTL.
		 *
		 * @param key The cache key.
		 * @param value The value to cache.
		 *
		 * @return True if stored; false if key is blank.
		 */
		public Boolean put(String key, Object value)
		{
			return put(key, value, null);
		}

		/**
		 * @description Stores a value in the per-transaction Map. ttlSeconds is ignored —
		 * transaction-scope storage has no TTL (lifetime = current Apex transaction).
		 *
		 * @param key The cache key.
		 * @param value The value to cache.
		 * @param ttlSeconds Ignored.
		 *
		 * @return True if stored; false if key is blank.
		 */
		public Boolean put(String key, Object value, Integer ttlSeconds)
		{
			if(String.isBlank(key))
			{
				return false;
			}
			transactionStorage.put(key, value);
			lastOperationResult = new OperationResult(true, Status.WRITE_SUCCESS, Scope.IN_TRANSACTION);
			return true;
		}

		/**
		 * @description Retrieves a value from the per-transaction Map. Records READ_SUCCESS on hit,
		 * CACHE_MISS on miss; both report cacheTypeUsed = Scope.IN_TRANSACTION.
		 *
		 * @param key The cache key.
		 *
		 * @return The cached value or null if not present / key blank.
		 */
		public Object get(String key)
		{
			if(String.isBlank(key))
			{
				return null;
			}
			if(transactionStorage.containsKey(key))
			{
				lastOperationResult = new OperationResult(true, Status.READ_SUCCESS, Scope.IN_TRANSACTION);
				return transactionStorage.get(key);
			}
			lastOperationResult = new OperationResult(true, Status.CACHE_MISS, Scope.IN_TRANSACTION);
			lastOperationResult.keysRequested = 1;
			lastOperationResult.keysFound = 0;
			return null;
		}

		/**
		 * @description Checks if a key exists in the per-transaction Map.
		 *
		 * @param key The cache key.
		 *
		 * @return True if the key is present; false if absent or blank.
		 */
		public Boolean contains(String key)
		{
			if(String.isBlank(key))
			{
				return false;
			}
			return transactionStorage.containsKey(key);
		}

		/**
		 * @description Removes a key from the per-transaction Map and reports REMOVE_SUCCESS.
		 *
		 * @param key The cache key.
		 *
		 * @return True if the key existed before removal; false otherwise.
		 */
		public Boolean remove(String key)
		{
			if(String.isBlank(key))
			{
				return false;
			}
			Boolean existed = transactionStorage.containsKey(key);
			transactionStorage.remove(key);
			lastOperationResult = new OperationResult(true, Status.REMOVE_SUCCESS, Scope.IN_TRANSACTION);
			return existed;
		}

		/**
		 * @description Bulk-stores values in the per-transaction Map with no TTL.
		 *
		 * @param valuesMap Map of key → value to store.
		 *
		 * @return True if attempted; false if the map is null or empty.
		 */
		public Boolean putAll(Map<String, Object> valuesMap)
		{
			return putAll(valuesMap, null);
		}

		/**
		 * @description Bulk-stores values in the per-transaction Map. ttlSeconds is ignored.
		 *
		 * @param valuesMap Map of key → value to store.
		 * @param ttlSeconds Ignored.
		 *
		 * @return True if attempted; false if the map is null or empty.
		 */
		public Boolean putAll(Map<String, Object> valuesMap, Integer ttlSeconds)
		{
			if(valuesMap == null || valuesMap.isEmpty())
			{
				return false;
			}
			transactionStorage.putAll(valuesMap);
			lastOperationResult = new OperationResult(true, Status.WRITE_SUCCESS, Scope.IN_TRANSACTION);
			return true;
		}

		/**
		 * @description Bulk-reads values from the per-transaction Map. Populates lastOperationResult
		 * with READ_SUCCESS on full hit or CACHE_MISS on partial; keysRequested / keysFound carry
		 * the counts. Empty / null key set short-circuits to empty result.
		 *
		 * @param keys Set of keys to retrieve.
		 *
		 * @return Map of key → value for found entries (empty when no hits).
		 */
		public Map<String, Object> getAll(Set<String> keys)
		{
			Map<String, Object> results = new Map<String, Object>();
			if(keys == null || keys.isEmpty())
			{
				return results;
			}
			for(String key : keys)
			{
				if(transactionStorage.containsKey(key))
				{
					results.put(key, transactionStorage.get(key));
				}
			}
			if(results.size() == keys.size())
			{
				lastOperationResult = new OperationResult(true, Status.READ_SUCCESS, Scope.IN_TRANSACTION);
			}
			else
			{
				lastOperationResult = new OperationResult(true, Status.CACHE_MISS, Scope.IN_TRANSACTION);
			}
			lastOperationResult.keysRequested = keys.size();
			lastOperationResult.keysFound = results.size();
			return results;
		}

		/**
		 * @description Bulk-removes keys from the per-transaction Map.
		 *
		 * @param keys Set of keys to remove.
		 *
		 * @return True if attempted; false if the key set is null or empty.
		 */
		public Boolean removeAll(Set<String> keys)
		{
			if(keys == null || keys.isEmpty())
			{
				return false;
			}
			for(String key : keys)
			{
				transactionStorage.remove(key);
			}
			lastOperationResult = new OperationResult(true, Status.REMOVE_SUCCESS, Scope.IN_TRANSACTION);
			return true;
		}

		/**
		 * @description Returns the per-instance diagnostic from the most recent operation.
		 *
		 * @return The last OperationResult, or null if no operation has run on this instance.
		 */
		public OperationResult getLastOperationResult()
		{
			return lastOperationResult;
		}

		/**
		 * @description Reports unconditional availability — transaction scope is always available
		 * because it requires no Platform Cache partition allocation.
		 *
		 * @return Always true.
		 */
		public Boolean isCacheAvailable()
		{
			return true;
		}
	}

	/**
	 * @description Composite Store that wraps a Platform-Cache-backed primary (today's auto())
	 * and a per-transaction in-memory fallback (today's inTransaction()). Each operation tries
	 * the primary first; when the primary signals unavailability (CACHE_UNAVAILABLE / scope
	 * probe failure / caught Platform Cache exception), the call automatically falls back to
	 * the in-transaction store. lastOperationResult.cacheTypeUsed reports IN_TRANSACTION when
	 * the fallback fired so callers can detect the degraded path without a separate API.
	 *
	 * Subscribers elect this behavior explicitly via autoWithTransactionFallback() — auto()
	 * itself stays durable-only so durability-required callers (UTIL_SessionEncryption etc.)
	 * keep their loud-failure signal.
	 */
	@TestVisible
	private class CompositeStore implements Store
	{
		/**
		 * @description Platform-Cache-backed primary Store (today's auto()).
		 */
		private final Store primary;
		/**
		 * @description In-transaction in-memory fallback Store (today's inTransaction()).
		 */
		private final Store fallback;
		/**
		 * @description Per-instance diagnostic for the most recent operation across both tiers.
		 */
		private OperationResult lastOperationResult;

		/**
		 * @description Wires primary + fallback for this composite. Subscribers never construct
		 * this directly — UTIL_Cache.autoWithTransactionFallback() is the entry point.
		 */
		public CompositeStore()
		{
			primary = auto();
			fallback = inTransaction();
		}

		/**
		 * @description Forwards scope preference to the primary Store. Fallback ignores scope.
		 *
		 * @param cacheType The Scope to prefer on the primary.
		 *
		 * @return This instance for fluent chaining.
		 */
		public Store withScope(Scope cacheType)
		{
			primary.withScope(cacheType);
			return this;
		}

		/**
		 * @description Forwards partition selection to the primary Store. Fallback ignores partition.
		 *
		 * @param partitionName Fully qualified Platform Cache partition name.
		 *
		 * @return This instance for fluent chaining.
		 */
		public Store withPartition(String partitionName)
		{
			primary.withPartition(partitionName);
			return this;
		}

		/**
		 * @description Forwards user-scope preference to the primary Store. Fallback ignores user scope.
		 *
		 * @param userScoped Whether keys should be scoped by current user on the primary.
		 *
		 * @return This instance for fluent chaining.
		 */
		public Store withUserScope(Boolean userScoped)
		{
			primary.withUserScope(userScoped);
			return this;
		}

		/**
		 * @description Stores a value via the primary; falls back to the in-transaction Store on
		 * primary failure. Routes through the ttlSeconds overload with null TTL.
		 *
		 * @param key The cache key.
		 * @param value The value to cache.
		 *
		 * @return True if either tier accepted the write.
		 */
		public Boolean put(String key, Object value)
		{
			return put(key, value, null);
		}

		/**
		 * @description Stores a value via the primary with custom TTL; falls back to the
		 * in-transaction Store on primary failure (CACHE_UNAVAILABLE / scope-probe failure /
		 * caught Platform Cache exception). On fallback success, reports
		 * OperationResult.cacheTypeUsed = Scope.IN_TRANSACTION so callers can detect the degraded path.
		 *
		 * @param key The cache key.
		 * @param value The value to cache.
		 * @param ttlSeconds TTL in seconds (forwarded to primary; ignored by fallback).
		 *
		 * @return True if either tier accepted the write; false if both failed.
		 */
		public Boolean put(String key, Object value, Integer ttlSeconds)
		{
			Boolean primaryOk = primary.put(key, value, ttlSeconds);
			if(primaryOk)
			{
				lastOperationResult = primary.getLastOperationResult();
				return true;
			}
			Boolean fallbackOk = fallback.put(key, value, ttlSeconds);
			if(fallbackOk)
			{
				lastOperationResult = new OperationResult(true, Status.WRITE_SUCCESS, Scope.IN_TRANSACTION);
				return true;
			}
			lastOperationResult = primary.getLastOperationResult();
			return false;
		}

		/**
		 * @description Reads a value from the primary first, then the in-transaction fallback if
		 * the primary returned null. Fallback hit reports cacheTypeUsed = Scope.IN_TRANSACTION.
		 *
		 * @param key The cache key.
		 *
		 * @return The cached value from whichever tier hit; null if both miss.
		 */
		public Object get(String key)
		{
			Object primaryValue = primary.get(key);
			if(primaryValue != null)
			{
				lastOperationResult = primary.getLastOperationResult();
				return primaryValue;
			}
			Object fallbackValue = fallback.get(key);
			if(fallbackValue != null)
			{
				lastOperationResult = new OperationResult(true, Status.READ_SUCCESS, Scope.IN_TRANSACTION);
				return fallbackValue;
			}
			lastOperationResult = primary.getLastOperationResult();
			return null;
		}

		/**
		 * @description Reports whether the key is present in either tier.
		 *
		 * @param key The cache key.
		 *
		 * @return True if either the primary or the fallback contains the key.
		 */
		public Boolean contains(String key)
		{
			return primary.contains(key) || fallback.contains(key);
		}

		/**
		 * @description Removes the key from BOTH tiers to avoid orphan keys on the fallback side
		 * after a Platform Cache recovery.
		 *
		 * @param key The cache key.
		 *
		 * @return True if either tier reported removal.
		 */
		public Boolean remove(String key)
		{
			Boolean removedPrimary = primary.remove(key);
			Boolean removedFallback = fallback.remove(key);
			return removedPrimary || removedFallback;
		}

		/**
		 * @description Bulk-stores values via the primary, falling back to the in-transaction Store
		 * on primary failure. Routes through the ttlSeconds overload with null TTL.
		 *
		 * @param valuesMap Map of key → value to store.
		 *
		 * @return True if either tier accepted the bulk write.
		 */
		public Boolean putAll(Map<String, Object> valuesMap)
		{
			return putAll(valuesMap, null);
		}

		/**
		 * @description Bulk-stores values via the primary with custom TTL; falls back to the
		 * in-transaction Store on primary failure. Reports cacheTypeUsed = Scope.IN_TRANSACTION
		 * on fallback success.
		 *
		 * @param valuesMap Map of key → value to store.
		 * @param ttlSeconds TTL in seconds (forwarded to primary; ignored by fallback).
		 *
		 * @return True if either tier accepted the bulk write; false if both failed.
		 */
		public Boolean putAll(Map<String, Object> valuesMap, Integer ttlSeconds)
		{
			Boolean primaryOk = primary.putAll(valuesMap, ttlSeconds);
			if(primaryOk)
			{
				lastOperationResult = primary.getLastOperationResult();
				return true;
			}
			Boolean fallbackOk = fallback.putAll(valuesMap, ttlSeconds);
			if(fallbackOk)
			{
				lastOperationResult = new OperationResult(true, Status.WRITE_SUCCESS, Scope.IN_TRANSACTION);
				return true;
			}
			lastOperationResult = primary.getLastOperationResult();
			return false;
		}

		/**
		 * @description Bulk-reads values, merging primary and fallback results. Keys missed by the
		 * primary are looked up in the fallback. cacheTypeUsed = Scope.IN_TRANSACTION only when
		 * EVERY satisfied key came from the fallback; mixed paths report the primary's scope.
		 *
		 * @param keys Set of keys to retrieve.
		 *
		 * @return Map of key → value across both tiers.
		 */
		public Map<String, Object> getAll(Set<String> keys)
		{
			Map<String, Object> primaryResults = primary.getAll(keys);
			if(keys == null || keys.isEmpty())
			{
				lastOperationResult = primary.getLastOperationResult();
				return primaryResults;
			}
			Set<String> missingFromPrimary = new Set<String>();
			for(String key : keys)
			{
				if(!primaryResults.containsKey(key))
				{
					missingFromPrimary.add(key);
				}
			}
			Map<String, Object> fallbackResults = missingFromPrimary.isEmpty()
					? new Map<String, Object>()
					: fallback.getAll(missingFromPrimary);
			Map<String, Object> merged = new Map<String, Object>(primaryResults);
			merged.putAll(fallbackResults);

			if(primaryResults.isEmpty() && !fallbackResults.isEmpty())
			{
				Status mergedStatus = merged.size() == keys.size() ? Status.READ_SUCCESS : Status.CACHE_MISS;
				lastOperationResult = new OperationResult(true, mergedStatus, Scope.IN_TRANSACTION);
				lastOperationResult.keysRequested = keys.size();
				lastOperationResult.keysFound = merged.size();
			}
			else
			{
				lastOperationResult = primary.getLastOperationResult();
			}
			return merged;
		}

		/**
		 * @description Bulk-removes keys from BOTH tiers to avoid orphan keys on the fallback side.
		 *
		 * @param keys Set of keys to remove.
		 *
		 * @return True if either tier reported a successful removal.
		 */
		public Boolean removeAll(Set<String> keys)
		{
			Boolean removedPrimary = primary.removeAll(keys);
			Boolean removedFallback = fallback.removeAll(keys);
			return removedPrimary || removedFallback;
		}

		/**
		 * @description Returns the per-instance diagnostic for the most recent operation.
		 *
		 * @return The last OperationResult; null if no operation has run.
		 */
		public OperationResult getLastOperationResult()
		{
			return lastOperationResult;
		}

		/**
		 * @description Reports unconditional availability — the composite is always available
		 * because the in-transaction fallback tier always is.
		 *
		 * @return Always true.
		 */
		public Boolean isCacheAvailable()
		{
			return true;
		}
	}

	/**
	 * @description Returns the name of the platform cache partition used by the framework.
	 *
	 * @return Cache name prefixed with framework namespace (e.g. 'kern.Library')
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String cacheName = UTIL_Cache.getPlatformCacheName();
	 * ```
	 */
	global static String getPlatformCacheName()
	{
		String namespace = UTIL_System.getManagedPackageNamespace();
		final String defaultPlatformCacheNamespace = 'local';

		return (String.isBlank(namespace) ? defaultPlatformCacheNamespace : namespace) + UTIL_String.DOT + CACHE_PARTITION_NAME;
	}
}