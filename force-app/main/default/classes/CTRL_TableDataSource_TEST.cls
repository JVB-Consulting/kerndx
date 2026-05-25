// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test Class for CTRL_TableDataSource
 *
 * @see CTRL_TableDataSource
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class CTRL_TableDataSource_TEST
{
	/**
	 * @description Will check that table results are successfully retrieved
	 *
	 * @see CTRL_TableDataSource.fetch
	 */
	@IsTest
	private static void shouldFetchTableData()
	{
		Test.startTest();

		DTO_BaseTable dtoTable = CTRL_TableDataSource.fetch(MockTableDataSource.class.getName(), null);

		Test.stopTest();

		Assert.isFalse(dtoTable.columns.isEmpty(), 'No columns returned');
		Assert.isFalse(dtoTable.rows.isEmpty(), 'No rows returned');
	}

	/**
	 * @description Will check that search fails to not being provided with a controller name
	 *
	 * @see CTRL_TableDataSource.fetch
	 */
	@IsTest
	private static void nullControllerName()
	{
		assertExceptionThrown(null, IllegalArgumentException.class);
	}

	/**
	 * @description Will check that call to controller fails correctly
	 *
	 * @param controllerName The name of the search controller class
	 * @param exceptionType The expected exception to be thrown
	 */
	private static void assertExceptionThrown(String controllerName, Type exceptionType)
	{
		Test.startTest();

		try
		{
			CTRL_TableDataSource.fetch(controllerName, null);
			Assert.fail('Expected Error to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, exceptionType, 'Incorrect exception thrown:' + error.getTypeName());
		}

		Test.stopTest();
	}

	/**
	 * @description Will check that search fails to not being provided with a controller name
	 *
	 * @see CTRL_TableDataSource.fetch
	 */
	@IsTest
	private static void blankControllerName()
	{
		assertExceptionThrown(UTIL_String.EMPTY, IllegalArgumentException.class);
	}

	/**
	 * @description Will check that search fails to not being provided with a visible class name
	 *
	 * @see CTRL_TableDataSource.fetch
	 */
	@IsTest
	private static void invalidControllerName()
	{
		assertExceptionThrown(CTRL_TableDataSource_TEST.class.getName(), IllegalArgumentException.class);
	}

	/**
	 * @description Will check that search fails to not being provided a class that supports the search interface
	 *
	 * @see CTRL_TableDataSource.fetch
	 */
	@IsTest
	private static void interfaceNotSupported()
	{
		assertExceptionThrown(CTRL_TableDataSource.class.getName(), TypeException.class);
	}

	/**
	 * @description Mock implementation of IF_TableDataSource for testing.
	 */
	public class MockTableDataSource implements IF_TableDataSource
	{
		/**
		 * @description Returns a mock table with sample data.
		 *
		 * @param searchParameters The search parameters (ignored in mock).
		 *
		 * @return A DTO_BaseTable with mock columns and rows.
		 */
		public DTO_BaseTable fetch(Map<String, Object> searchParameters)
		{
			DTO_BaseTable table = new DTO_BaseTable();
			table.addColumn('Name', 'name', 'text');
			table.addRow(new Map<String, Object> {'name' => 'Test Row'});
			return table;
		}
	}
}