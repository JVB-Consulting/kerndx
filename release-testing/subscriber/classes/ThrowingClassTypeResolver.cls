// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber-side fixture for `Subscriber_TypeResolver_TEST.cls`. Implements
 * `kern.UTIL_TypeResolver.INT_ClassTypeResolver` directly (so the chain can construct it via
 * `Type.newInstance()`) and unconditionally throws from `resolveType(String)`. Used by the
 * `shouldFallThroughOnThrowingResolver` test to prove the framework's current contract:
 * `PackageClassResolver` delegates via `nextResolver?.resolveType(typeName)` with no
 * `try/catch`, so any exception thrown by a custom resolver propagates to the caller.
 *
 * @see Subscriber_TypeResolver_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class ThrowingClassTypeResolver implements kern.UTIL_TypeResolver.INT_ClassTypeResolver
{
	/**
	 * @description Sentinel message thrown from `resolveType` so tests can assert message
	 * content without depending on platform-supplied strings.
	 */
	global static final String SENTINEL_MESSAGE = 'ThrowingClassTypeResolver: deliberate failure for fall-through test';

	/**
	 * @description Always throws `IllegalArgumentException` with `SENTINEL_MESSAGE`. The
	 * framework's `PackageClassResolver` does not wrap this call in a try/catch, so the
	 * exception propagates to the caller of `kern.UTIL_System.getTypeForClassName(name)` and
	 * `findTypeForClassName(name)`.
	 *
	 * @param typeName The class name being resolved (ignored).
	 *
	 * @return Never returns — always throws.
	 */
	global Type resolveType(String typeName)
	{
		throw new IllegalArgumentException(SENTINEL_MESSAGE);
	}

	/**
	 * @description Stores the next resolver in the chain. This fixture never delegates because
	 * `resolveType` always throws, but the setter is required by the interface contract.
	 *
	 * @param nextTypeResolver The next resolver in the chain.
	 *
	 * @return The next resolver (passthrough — matches `BaseClassResolver.setNext` semantics).
	 */
	global kern.UTIL_TypeResolver.INT_ClassTypeResolver setNext(kern.UTIL_TypeResolver.INT_ClassTypeResolver nextTypeResolver)
	{
		return nextTypeResolver;
	}
}
