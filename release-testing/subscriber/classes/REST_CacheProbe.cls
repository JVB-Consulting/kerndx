// SPDX-License-Identifier: BUSL-1.1
/**
 * @description REST endpoint for parallel cache-contention load testing. Maintains a shared
 * counter in the org platform cache that can be incremented, read, and reset via HTTP verbs.
 * Used by the parallel-cache-contention extended load suite to observe race conditions under
 * 100 concurrent POST requests operating on the same hot cache key via an intentional
 * get-modify-put pattern (no locking).
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date May 2026
 */
@RestResource(UrlMapping='/v1/cache-probe')
global inherited sharing class REST_CacheProbe
{
	/**
	 * @description Shared cache key used for the contention counter across all HTTP verbs.
	 */
	private static final String COUNTER_KEY = 'cachecontentioncounter';

	/**
	 * @description Handles POST requests. Reads the current counter from org cache, increments
	 * it by one, writes it back, and returns the new value as a JSON object. This intentionally
	 * uses an unguarded get-modify-put sequence to expose cache-contention race conditions under
	 * parallel load.
	 *
	 * @return JSON string with a {@code value} property containing the incremented counter integer
	 */
	@HttpPost
	global static String increment()
	{
		kern.UTIL_Cache.Store cache = kern.UTIL_Cache.org();
		Integer current = (Integer)cache.get(COUNTER_KEY);
		if(current == null)
		{
			current = 0;
		}
		current++;
		cache.put(COUNTER_KEY, current);
		return JSON.serialize(new Map<String, Object>{'value' => current});
	}

	/**
	 * @description Handles DELETE requests. Removes the contention counter from org cache so
	 * subsequent load test runs start from a clean state.
	 */
	@HttpDelete
	global static void reset()
	{
		kern.UTIL_Cache.org().remove(COUNTER_KEY);
	}

	/**
	 * @description Handles GET requests. Returns the current counter value from org cache without
	 * modifying it. Returns zero when no value is stored.
	 *
	 * @return JSON string with a {@code value} property containing the current counter integer
	 */
	@HttpGet
	global static String currentValue()
	{
		Integer value = (Integer)kern.UTIL_Cache.org().get(COUNTER_KEY);
		return JSON.serialize(new Map<String, Object>{'value' => (value == null ? 0 : value)});
	}
}
