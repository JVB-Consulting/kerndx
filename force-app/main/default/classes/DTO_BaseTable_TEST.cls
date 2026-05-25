// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behavior of the {@link DTO_BaseTable} class.
 *
 * @see DTO_BaseTable
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class DTO_BaseTable_TEST
{
	/**
	 * @description Test column label value.
	 */
	private static final String TEST_LABEL = 'Account Name';

	/**
	 * @description Test column field name value.
	 */
	private static final String TEST_FIELD_NAME = 'name';

	/**
	 * @description Test column type value.
	 */
	private static final String TEST_TYPE = 'text';

	/**
	 * @description Tests that addColumn creates a non-sortable column by default.
	 *
	 * @see DTO_BaseTable.addColumn
	 */
	@IsTest
	private static void shouldAddColumnWithDefaultSortable()
	{
		DTO_BaseTable table = new DTO_BaseTable();

		Test.startTest();

		table.addColumn(TEST_LABEL, TEST_FIELD_NAME, TEST_TYPE);

		Test.stopTest();

		Assert.areEqual(1, table.columns.size(), 'Should have one column');
		Assert.areEqual(TEST_LABEL, table.columns[0].label, 'Label should match');
		Assert.areEqual(TEST_FIELD_NAME, table.columns[0].fieldName, 'Field name should match');
		Assert.areEqual(TEST_TYPE, table.columns[0].type, 'Type should match');
		Assert.isFalse(table.columns[0].sortable, 'Column should not be sortable by default');
	}

	/**
	 * @description Tests that addColumn creates a sortable column when specified.
	 *
	 * @see DTO_BaseTable.addColumn
	 */
	@IsTest
	private static void shouldAddSortableColumn()
	{
		DTO_BaseTable table = new DTO_BaseTable();

		Test.startTest();

		table.addColumn(TEST_LABEL, TEST_FIELD_NAME, TEST_TYPE, true);

		Test.stopTest();

		Assert.isTrue(table.columns[0].sortable, 'Column should be sortable');
	}

	/**
	 * @description Tests that addRow adds data to the table rows.
	 *
	 * @see DTO_BaseTable.addRow
	 */
	@IsTest
	private static void shouldAddRow()
	{
		DTO_BaseTable table = new DTO_BaseTable();
		Map<String, Object> rowData = new Map<String, Object> {TEST_FIELD_NAME => 'Acme Corp'};

		Test.startTest();

		table.addRow(rowData);

		Test.stopTest();

		Assert.areEqual(1, table.rows.size(), 'Should have one row');
		Assert.areEqual(rowData, table.rows[0], 'Row data should match');
	}

	/**
	 * @description Tests that columns returns null when no columns have been added.
	 *
	 * @see DTO_BaseTable.columns
	 */
	@IsTest
	private static void shouldReturnNullColumnsWhenNoneAdded()
	{
		DTO_BaseTable table = new DTO_BaseTable();

		Test.startTest();

		List<DTO_BaseTable.DTO_Column> result = table.columns;

		Test.stopTest();

		Assert.isNull(result, 'Columns should be null when none have been added');
	}

	/**
	 * @description Tests that rows returns an empty list when no rows have been added.
	 *
	 * @see DTO_BaseTable.rows
	 */
	@IsTest
	private static void shouldReturnEmptyRowsWhenNoneAdded()
	{
		DTO_BaseTable table = new DTO_BaseTable();

		Test.startTest();

		List<Object> result = table.rows;

		Test.stopTest();

		Assert.isTrue(result.isEmpty(), 'Rows should be empty when none have been added');
	}

	/**
	 * @description Tests that multiple columns can be added to the table.
	 *
	 * @see DTO_BaseTable.addColumn
	 */
	@IsTest
	private static void shouldAddMultipleColumns()
	{
		DTO_BaseTable table = new DTO_BaseTable();

		Test.startTest();

		table.addColumn(TEST_LABEL, TEST_FIELD_NAME, TEST_TYPE);
		table.addColumn('Revenue', 'revenue', 'currency', true);

		Test.stopTest();

		Assert.areEqual(2, table.columns.size(), 'Should have two columns');
	}
}