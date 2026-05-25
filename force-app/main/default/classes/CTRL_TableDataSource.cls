// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller class responsible for managing the instantiation of a data source class that
 * supports the table data source interface. This controller allows fetching table data from
 * dynamically specified classes, providing flexible table-based data retrieval capabilities.
 *
 * @see CTRL_TableDataSource_TEST
 * @see IF_TableDataSource
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
 * DTO_BaseTable result = CTRL_TableDataSource.fetch(
 *     'AccountTableSource',
 *     new Map<String, Object>{'industry' => 'Technology'}
 * );
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class CTRL_TableDataSource
{
	/**
	 * @description Dynamically creates an instance of a specified table data source controller and retrieves
	 * data based on the provided search parameters. The class specified by `controllerName` must implement
	 * the `IF_TableDataSource` interface.
	 *
	 * @param controllerName The fully qualified class name of the data source controller to instantiate.
	 * The class must implement the `IF_TableDataSource` interface.
	 * @param searchParameters A map of search parameters, where each key-value pair specifies a criterion or filter to apply to the data source.
	 *
	 * @return A `DTO_BaseTable` object containing the search results formatted as a table.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_BaseTable result = CTRL_TableDataSource.fetch('MyDataSource', new Map<String, Object>{'key' => 'value'});
	 * ```
	 */
	@AuraEnabled
	global static DTO_BaseTable fetch(String controllerName, Map<String, Object> searchParameters)
	{
		IF_TableDataSource controller = (IF_TableDataSource)UTIL_System.getTypeForClassName(controllerName, IF_TableDataSource.class).newInstance();
		return controller.fetch(searchParameters);
	}
}