// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Registry for managing SOQL bind variables.
 * Generates unique bind variable names and collects their values for use with Database.queryWithBinds().
 *
 * **VISIBILITY**: Intentionally `public` (package-internal), NOT `global`.
 * This is an internal implementation detail of the query framework.
 *
 * @see QRY_Builder
 * @see QRY_Generator
 * @see QRY_Condition
 * @see QRY_BindRegistry_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, May 2026
 */
public inherited sharing class QRY_BindRegistry
{
	/**
	 * @description Prefix for generated bind variable names.
	 */
	private static final String BIND_PREFIX = 'bv';

	/**
	 * @description Counter for generating unique bind variable names.
	 */
	private Integer counter = 0;

	/**
	 * @description Map of bind variable names to their values.
	 */
	private final Map<String, Object> bindings = new Map<String, Object>();

	/**
	 * @description Registers a value and returns the bind variable reference to use in SOQL.
	 *
	 * @param bindValue The value to bind
	 *
	 * @return The bind variable reference with colon prefix (e.g., ':bv0', ':bv1')
	 */
	public String register(Object bindValue)
	{
		String bindName = BIND_PREFIX + counter++;
		bindings.put(bindName, bindValue);
		return UTIL_String.COLON + bindName;
	}

	/**
	 * @description Registers a collection (Set, List, or other iterable) and returns
	 * the bind variable reference with colon prefix for use in IN/NOT IN clauses.
	 *
	 * @param values The collection to bind
	 *
	 * @return The bind variable reference (e.g., ':bv0', ':bv1') or empty parens if null
	 *
	 * @example
	 * ```apex
	 * QRY_BindRegistry registry = new QRY_BindRegistry();
	 * Set<String> statuses = new Set<String>{'Open', 'Pending'};
	 * String ref = registry.registerCollection(statuses); // Returns ':bv0'
	 * ```
	 */
	public String registerCollection(Object values)
	{
		return values == null ? '()' : register(values);
	}

	/**
	 * @description Returns the map of all registered bind variables.
	 *
	 * @return Map of bind variable names to values
	 */
	public Map<String, Object> getMap()
	{
		return bindings;
	}

	/**
	 * @description Returns true if no bindings have been registered.
	 *
	 * @return true if empty
	 */
	public Boolean isEmpty()
	{
		return bindings.isEmpty();
	}

	/**
	 * @description Returns the number of registered bind variables.
	 *
	 * @return The count of registered bindings
	 */
	public Integer size()
	{
		return bindings.size();
	}

	/**
	 * @description Clears all registered bindings.
	 */
	public void clear()
	{
		bindings.clear();
		counter = 0;
	}
}