// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller class responsible for managing the instantiation of a search interface and
 * executing the associated search method. Provides flexibility by dynamically instantiating
 * the controller based on the provided class name, which must support the `IF_Search` interface.
 *
 * @see CTRL_ExecuteSearch_TEST
 * @see IF_Search
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class CTRL_ExecuteSearch
{
	/**
	 * @description Dynamically creates an instance of the specified search controller and executes the search
	 * operation with the provided search term and parameters.
	 * This method utilizes reflection to instantiate the controller based on the `controllerName`,
	 * which must implement the `IF_Search` interface. The search term and parameters are then passed
	 * to the search method of the instantiated controller to retrieve relevant results.
	 *
	 * @param controllerName The fully qualified class name of the search controller to instantiate, such as "AccountSearchController".
	 * Must be a valid class name implementing the `IF_Search` interface.
	 * @param searchTerm The search term or criteria for executing the search. The search term is passed as an Object
	 * to support various data types, based on the needs of the specific search implementation.
	 * @param searchParameters A map of search parameters, with each key-value pair representing additional criteria
	 * or filters that can be applied during the search. The map allows for flexible, dynamic search functionality.
	 *
	 * @return The search results as an Object. The structure of the returned data depends on the specific implementation
	 * of the search controller instantiated via the `controllerName`.
	 *
	 * @throws IllegalArgumentException If the specified `controllerName` does not implement the required `IF_Search`
	 * interface or if any search parameters are invalid.
	 *
	 * @example
	 * ```apex
	 * Object result = CTRL_ExecuteSearch.executeSearchController('value', 'value', new Map<String, Object>{'key' => 'value'});
	 * ```
	 */
	@AuraEnabled
	public static Object executeSearchController(String controllerName, Object searchTerm, Map<String, Object> searchParameters)
	{
		Type controllerType = UTIL_System.getTypeForClassName(controllerName, IF_Search.class);
		return ((IF_Search)controllerType.newInstance()).search(searchTerm, searchParameters);
	}
}