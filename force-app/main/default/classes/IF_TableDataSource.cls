// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Generic Interface for Table data sources
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public class AccountTableSource implements IF_TableDataSource
 * {
 *     public DTO_BaseTable fetch(Map<String, Object> searchParameters)
 *     {
 *         DTO_BaseTable table = new DTO_BaseTable();
 *         table.addColumn('Name', 'name', 'text', true);
 *         return table;
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global interface IF_TableDataSource
{
	/**
	 * @description Table datasource function to be implemented
	 *
	 * @param searchParameters Map of fetch parameters - individual implementations can expect differing parameters.
	 *
	 * @return Table Response object. Individual implementations must all use the standard response structure.
	 *
	 * @since 1.0
	 */
	DTO_BaseTable fetch(Map<String, Object> searchParameters);
}