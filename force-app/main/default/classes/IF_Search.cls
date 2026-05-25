// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Generic Interface for searches
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public class AccountSearch implements IF_Search
 * {
 *     public Object search(Object searchTerm, Map<String, Object> searchParameters)
 *     {
 *         return new SEL_Accounts().findByField(Account.Name, (String)searchTerm);
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global interface IF_Search
{
	/**
	 * @description Search function to be implemented
	 *
	 * @param searchTerm Search Term to be used for search/query
	 * @param searchParameters Map of search parameters - individual implementations can expect differing parameters.
	 *
	 * @return Response object. Individual implementations can cast to different structures as needed.
	 *
	 * @since 1.0
	 */
	Object search(Object searchTerm, Map<String, Object> searchParameters);
}