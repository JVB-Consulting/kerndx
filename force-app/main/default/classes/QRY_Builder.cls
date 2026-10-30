// SPDX-License-Identifier: Apache-2.0
/**
 * @description Modern fluent query builder - the primary entry point for constructing and executing SOQL queries.
 * Provides a clean, type-safe API for building queries with support for conditions, ordering, pagination, caching,
 * and security enforcement.
 *
 * **Design Principle:** QRY_Builder passes the work to the existing query classes (QRY_Generator and QRY_Engine).
 * This keeps older code working while giving new code a cleaner set of methods.
 *
 * **95% Use Case**: Inline queries via `QRY_Builder.selectFrom(...)`
 * **5% Use Case**: Extend `Builder` for reusable custom selectors
 *
 * @see IF_Queryable
 * @see QRY_Condition.DateLiteral
 * @see QRY_Function
 * @see QRY_Builder_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Basic query
 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
 *     .fields(new List<String>{'Name', 'Industry'})
 *     .condition(Account.Industry).equals('Technology')
 *     .toList();
 * ```
 * ```apex
 * // With caching
 * Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
 *     .condition(Account.Id).equals(accountId)
 *     .withSystemMode()
 *     .withSharing()
 *     .withCache(300)
 *     .getFirst();
 * ```
 * ```apex
 * // Pagination
 * QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Account.SObjectType)
 *     .condition(Account.Type).equals('Customer')
 *     .getPage(2, 25);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.ExcessivePublicCount,PMD.ExcessiveClassLength,PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.NcssTypeCount')
global inherited sharing class QRY_Builder
{
	/**
	 * @description Developer name of the feature flag that sets the default access mode for queries. A subscriber
	 * can turn this flag on or off.
	 */
	@TestVisible
	private static final String FLAG_USER_MODE_QUERIES = 'UserModeQueries_Enabled';

	/**
	 * @description Largest page a cursor will hand back in one fetch. Both cursor kinds reject a bigger
	 * request outright, and the platform publishes no governor accessor for the figure, so getPage() states
	 * it here and turns an oversized page into a clear argument error at the API boundary rather than a
	 * platform error partway through the read.
	 *
	 * @date August 2026
	 */
	private static final Integer MAXIMUM_CURSOR_FETCH_ROWS = 2000;

	/**
	 * @description Message thrown when a test reads an alias that its registered aggregate row does not hold. The
	 * placeholders are the alias that was read and the aliases the row holds.
	 */
	private static final String AGGREGATE_ALIAS_NOT_SET_MESSAGE = 'The aggregate row has no alias {0}. The aliases set on this row are: {1}. '
			+ 'Check the spelling of the alias in the query and in the registered row.';

	/**
	 * @description Message thrown when a test registers an aggregate row with two aliases that differ only in case. The
	 * placeholders are the two aliases.
	 */
	private static final String AGGREGATE_ALIASES_DIFFER_ONLY_IN_CASE_MESSAGE = 'The aggregate row holds the aliases {0} and {1}, which differ only in case. '
			+ 'A real aggregate row cannot hold both, because a query cannot use the same alias twice. Keep one of them in the registered row.';

	/**
	 * @description Message thrown when a record read, such as toList(), meets an aggregate query that registered aggregate
	 * rows answered. The placeholder is the SObjectType.
	 */
	private static final String RECORDS_READ_FROM_AGGREGATE_MOCK_MESSAGE = 'Aggregate rows are registered for {0}, so this aggregate query cannot be read '
			+ 'as records. A live run would return AggregateResult rows here, and a test cannot build those. '
			+ 'Read the rows with toAggregateList() or getFirstAggregate(). '
			+ 'Reading an aggregate query with toList() or another record read is a sign the code should use toAggregateList() too.';

	/**
	 * @description Name of the toList() method, shown when a read with bypassSharing() alone is refused.
	 */
	private static final String METHOD_TO_LIST = 'toList';

	/**
	 * @description Name of the toAggregateList() method, shown when a read with bypassSharing() alone is refused.
	 */
	private static final String METHOD_TO_AGGREGATE_LIST = 'toAggregateList';

	/**
	 * @description Name of the getFirstAggregate() method, shown when a read with bypassSharing() alone is refused.
	 */
	private static final String METHOD_GET_FIRST_AGGREGATE = 'getFirstAggregate';

	/**
	 * @description Name of the toQueryLocator() method, shown when a read with bypassSharing() alone is refused.
	 */
	private static final String METHOD_TO_QUERY_LOCATOR = 'toQueryLocator';

	/**
	 * @description Name of the toCursor() method, shown when a read with bypassSharing() alone is refused.
	 */
	private static final String METHOD_TO_CURSOR = 'toCursor';

	/**
	 * @description Name of the count() method, shown when a read with bypassSharing() alone is refused.
	 */
	private static final String METHOD_COUNT = 'count';

	/**
	 * @description Name of the getPage() method, shown when a read with bypassSharing() alone is refused.
	 */
	private static final String METHOD_GET_PAGE = 'getPage';

	/**
	 * @description Name of the getRandomItems() method, shown when a read with bypassSharing() alone is refused.
	 */
	private static final String METHOD_GET_RANDOM_ITEMS = 'getRandomItems';

	/**
	 * @description Finds the field in one item of a sort list, as the query reads it: the first word, then ASC or DESC if
	 * written, then NULLS FIRST or NULLS LAST if written, in any letter case and with any spaces around the words. A
	 * function written with spaces inside its brackets, such as toLabel( Status ), does not match, so it is not checked.
	 */
	private static final Pattern SORT_ITEM_FIELD_PATTERN = Pattern.compile('(?i)\\s*(\\S+?)(?:\\s+(?:ASC|DESC))?(?:\\s+NULLS\\s+(?:FIRST|LAST))?\\s*');

	/**
	 * @description Returns whether queries a subscriber can reach run in `AccessLevel.USER_MODE` by default, which
	 * is the value of the `UserModeQueries_Enabled` feature flag. Every new `Builder.userModeEnabled` field starts
	 * with this value. `UTIL_FeatureFlag` and `SEL_FeatureFlag.activeFlags` cache the flag.
	 *
	 * @return True when `UserModeQueries_Enabled` is on; false otherwise.
	 */
	public static Boolean userModeQueriesEnabled()
	{
		return UTIL_FeatureFlag.isEnabled(FLAG_USER_MODE_QUERIES);
	}

	/**
	 * @description Entry point for inline queries. Creates a new Builder instance for the specified SObject type.
	 *
	 * @param sObjectType The SObject type to query
	 *
	 * @return Builder for fluent chaining
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .fields(new List<String>{'Name', 'Industry'})
	 *     .condition(Account.Industry).equals('Technology')
	 *     .toList();
	 * ```
	 */
	global static Builder selectFrom(SObjectType sObjectType)
	{
		return new Builder(sObjectType);
	}

	/**
	 * @description Registers mock records for a specific SObjectType during test execution.
	 * When mocks are registered, queries will return these records instead of executing actual SOQL.
	 *
	 * **Smart Mock Filtering:** WHERE conditions are evaluated in memory against mock records
	 * using FormulaEval when a context class is available for the SObjectType. Standard objects
	 * (Account, Contact, etc.) and Foobar__c are auto-detected. For custom objects, register
	 * a context class via registerMockContextClass() to enable filtering.
	 *
	 * When filtering is not possible (no context class, unsupported condition operators, or
	 * relationship field traversals), all mocks are returned with only LIMIT and pagination applied.
	 *
	 * @param sObjectType The SObjectType to mock
	 * @param mocks List of mock records to return for queries
	 *
	 * @throws IllegalArgumentException if mocks contain records of a different type than sObjectType
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Account> mockAccounts = (List<Account>)TST_Builder.of(Account.SObjectType)
	 *     .withOverride(Account.Name, 'Test Account')
	 *     .withCount(5)
	 *     .withoutInsertion(true)
	 *     .buildList();
	 * QRY_Builder.setMock(Account.SObjectType, mockAccounts);
	 * ```
	 */
	global static void setMock(SObjectType sObjectType, List<SObject> mocks)
	{
		QRY_Engine.setMock(sObjectType, mocks);
	}

	/**
	 * @description Registers an exception to be thrown when QRY_Builder is invoked
	 * for the specified SObjectType. Used for negative-path test coverage when a caller
	 * needs to exercise a catch block around a SOQL call. Cleared by TST_Mock.clear()
	 * and TST_Mock.clear(SObjectType).
	 *
	 * @param sObjectType The SObjectType for which queries should throw.
	 * @param exceptionToThrow The exception instance to throw.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.setMockException(Account.SObjectType, new QueryException('Simulated SOQL failure'));
	 * ```
	 */
	global static void setMockException(SObjectType sObjectType, Exception exceptionToThrow)
	{
		QRY_Engine.setMockException(sObjectType, exceptionToThrow);
	}

	/**
	 * @description Clears all registered mocks and mock context classes for all SObjectTypes.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.clearMocks();
	 * ```
	 */
	global static void clearMocks()
	{
		QRY_Engine.clearMocks();
	}

	/**
	 * @description Makes every aggregate query on this object type return these rows instead of reading the database,
	 * in your tests. Each map is one row: its keys are the aliases your code reads, its values what they hold. Pass
	 * null to clear.
	 *
	 * An aggregate query is one with count(field, alias), count(fieldName), countDistinct(), sum(), avg(), min(), max()
	 * or groupBy(). The count() that ends a query and returns a number is not one: like toList(), it reads record mocks
	 * set with setMock. Read the rows with toAggregateList() or getFirstAggregate(). The rows come back in the order you
	 * gave them; only the query's limit is applied to them. Aliases are matched without regard to case. Rows set here
	 * replace any set earlier for the type, as setMock replaces records; TST_Mock.registerAggregateRows adds to them
	 * instead. clearMocks() removes them too.
	 *
	 * @param sObjectType The object type whose aggregate queries the rows answer.
	 * @param rows The rows to return, in this order, or null to remove the rows set for the type.
	 *
	 * @throws IllegalArgumentException When sObjectType is null.
	 *
	 * @since 1.10
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.setAggregateMock(Account.SObjectType, new List<Map<String, Object>>
	 * {
	 *     new Map<String, Object> {'total' => 3, 'Industry' => 'Energy'}
	 * });
	 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .count(Account.Id, 'total')
	 *     .groupBy(Account.Industry)
	 *     .getFirstAggregate();
	 * Integer total = row.getInteger('total');
	 * ```
	 */
	global static void setAggregateMock(SObjectType sObjectType, List<Map<String, Object>> rows)
	{
		QRY_Engine.setAggregateMock(sObjectType, rows);
	}

	/**
	 * @description Registers a FormulaEval context class for an SObjectType, enabling smart mock filtering.
	 * When registered, mock queries against this SObjectType will evaluate WHERE conditions in memory
	 * using the specified context class, returning only matching mock records.
	 *
	 * Standard objects (Account, Contact, etc.) and Foobar__c are auto-detected and do not require
	 * explicit registration. Use this method for custom objects that need mock filtering.
	 *
	 * @param sObjectType The SObjectType to register the context for
	 * @param contextClassName The fully qualified class name of the FormulaEval context
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.registerMockContextClass(Invoice__c.SObjectType, 'InvoiceFormulaContext');
	 * QRY_Builder.setMock(Invoice__c.SObjectType, mockInvoices);
	 * // Queries against Invoice__c now filter mocks using InvoiceFormulaContext
	 * ```
	 */
	global static void registerMockContextClass(SObjectType sObjectType, String contextClassName)
	{
		QRY_Engine.registerMockContextClass(sObjectType, contextClassName);
	}

	/**
	 * @description Enumeration of valid SOQL scope values for use with the USING SCOPE clause.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Account> myAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .usingScope(QRY_Builder.Scope.MINE)
	 *     .toList();
	 * ```
	 */
	global enum Scope
	{
		/**
		 * @description Records owned by the current user.
		 */
		MINE,

		/**
		 * @description Records in the current user's territory.
		 */
		MY_TERRITORY,

		/**
		 * @description Records in the current user's team territory.
		 */
		MY_TEAM_TERRITORY,

		/**
		 * @description Records owned by the current user's team.
		 */
		TEAM,

		/**
		 * @description Records delegated to another user.
		 */
		DELEGATED,

		/**
		 * @description All records the user has access to.
		 */
		EVERYTHING
	}

	/**
	 * @description Result container for paged queries, providing records and pagination metadata.
	 *
	 * @since 1.0
	 */
	global class QueryPage
	{
		/**
		 * @description The records for the requested page.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(1, 25);
		 * List<SObject> pageRecords = page.records;
		 * ```
		 */
		global List<SObject> records;

		/**
		 * @description Total number of records matching the query criteria.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(1, 25);
		 * Integer total = page.totalRecords;
		 * ```
		 */
		global Integer totalRecords;

		/**
		 * @description Total number of pages available.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(1, 25);
		 * Integer pages = page.totalPages;
		 * ```
		 */
		global Integer totalPages
		{
			get
			{
				if(pageSize == null || pageSize <= 0)
				{
					return 1;
				}
				return (Integer)Math.ceil((Decimal)totalRecords / pageSize);
			}
		}

		/**
		 * @description The current page number (1-based).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(2, 25);
		 * Integer currentPage = page.pageNumber; // 2
		 * ```
		 */
		global Integer pageNumber;

		/**
		 * @description Number of records per page.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(1, 25);
		 * Integer size = page.pageSize; // 25
		 * ```
		 */
		global Integer pageSize;

		/**
		 * @description True if there are more pages after the current page.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(1, 25);
		 * if(page.hasMorePages)
		 * {
		 *     // Load next page
		 * }
		 * ```
		 */
		global Boolean hasMorePages
		{
			get
			{
				return pageNumber < totalPages;
			}
		}

		/**
		 * @description True if there are pages before the current page.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(2, 25);
		 * if(page.hasPriorPages)
		 * {
		 *     // Load previous page
		 * }
		 * ```
		 */
		global Boolean hasPriorPages
		{
			get
			{
				return pageNumber > 1;
			}
		}

		/**
		 * @description Number of records deleted since the cursor was created.
		 * Useful for detecting data changes between page fetches.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(1, 25);
		 * Integer deleted = page.deletedRecords;
		 * ```
		 */
		global Integer deletedRecords;

		/**
		 * @description The PaginationCursor, which a Lightning web component can send back to the server to read
		 * the next page. Passing it back keeps the pages stable across requests.
		 *
		 * It is null whenever the page was read without a pagination cursor. That happens when more records match
		 * than the paging allowance left in the transaction, or when the transaction has no pagination cursors left.
		 * The allowance is 100,000 records today, and every paged read in the same transaction uses it, so a later
		 * read has only what the earlier ones left. Such pages are read another way: `records`, `totalRecords` and
		 * every paging flag stay correct. Only `deletedRecords` is not available, so it reads 0. Check for null before
		 * passing the cursor back.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .getPage(1, 25);
		 * Database.PaginationCursor cursor = page.cursor;
		 * ```
		 */
		global Database.PaginationCursor cursor;

		/**
		 * @description Starts an empty first page: no records, a total of 0, page number 1 and 0 deleted records.
		 */
		public QueryPage()
		{
			records = new List<SObject>();
			totalRecords = 0;
			pageNumber = 1;
			deletedRecords = 0;
		}
	}

	/**
	 * @description Typed wrapper around AggregateResult for convenient value access.
	 * Provides typed accessors that eliminate the need for manual casting from Object.
	 *
	 * In a test, a row can also hold the values of a row registered with TST_Mock.registerAggregateRows or
	 * QRY_Builder.setAggregateMock. Such a row answers as a real row does: an alias is matched without regard to
	 * case, and reading an alias the row does not hold throws IllegalArgumentException. Its number getters also
	 * accept a whole number written as an Integer, a Long or a Decimal.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .count(Account.Id, 'total')
	 *     .groupBy(Account.Industry)
	 *     .toAggregateList()[0];
	 * Integer total = row.getInteger('total');
	 * String industry = row.getString('Industry');
	 * ```
	 */
	global inherited sharing class AggregateRow
	{
		/**
		 * @description The underlying AggregateResult. It is null when the row holds the values of a registered row.
		 */
		private final AggregateResult result;

		/**
		 * @description The values of a registered row, keyed by alias in lower case so that an alias is matched without
		 * regard to case. It is null when the row wraps an AggregateResult.
		 */
		private final Map<String, Object> valueByAlias;

		/**
		 * @description The aliases of a registered row as the test wrote them. The error for an alias the row does not
		 * hold lists them.
		 */
		private final List<String> registeredAliases;

		/**
		 * @description Constructs an AggregateRow wrapping an AggregateResult.
		 *
		 * @param aggregateResult The AggregateResult to wrap
		 */
		public AggregateRow(AggregateResult aggregateResult)
		{
			result = aggregateResult;
		}

		/**
		 * @description Constructs an AggregateRow from a row a test registered. The values are copied, so a later change
		 * to the registered map does not change this row. Each alias is stored in lower case, so it is matched without
		 * regard to case, as on a real row.
		 *
		 * @param values The row's values, keyed by alias. Null makes a row that holds no alias.
		 *
		 * @throws IllegalArgumentException When two aliases differ only in case, such as Total and total. A real
		 * AggregateResult cannot hold both, because a query cannot use the same alias twice. The error shows when the
		 * row is read, in toAggregateList() or getFirstAggregate(), not when it is registered; by then a queued answer
		 * that held the row has been used up.
		 */
		public AggregateRow(Map<String, Object> values)
		{
			valueByAlias = new Map<String, Object>();
			registeredAliases = new List<String>();
			Map<String, String> registeredAliasByKey = new Map<String, String>();
			for(String alias : values?.keySet() ?? new Set<String>())
			{
				String key = alias?.toLowerCase();
				if(registeredAliasByKey.containsKey(key))
				{
					throw new IllegalArgumentException(String.format(AGGREGATE_ALIASES_DIFFER_ONLY_IN_CASE_MESSAGE, new List<String> {registeredAliasByKey.get(key), alias}));
				}
				registeredAliasByKey.put(key, alias);
				valueByAlias.put(key, values.get(alias));
				registeredAliases.add(alias);
			}
		}

		/**
		 * @description Returns the value held under an alias. A real row answers through AggregateResult.get. A
		 * registered row matches the alias without regard to case, and returns null for an alias that holds null.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The raw value
		 *
		 * @throws IllegalArgumentException When the row is a registered row that does not hold the alias. A real
		 * AggregateResult throws on an unknown alias too.
		 */
		private Object readValue(String alias)
		{
			if(result != null)
			{
				return result.get(alias);
			}
			String key = alias?.toLowerCase();
			if(!valueByAlias.containsKey(key))
			{
				throw new IllegalArgumentException(String.format(AGGREGATE_ALIAS_NOT_SET_MESSAGE, new List<String> {alias, String.join(registeredAliases, ', ')}));
			}
			return valueByAlias.get(key);
		}

		/**
		 * @description Tells whether a value from a registered row is a whole number that the number getters convert. A
		 * value from a real row is never converted, so the getters keep the casts a real row has always had. A number
		 * with a fraction, such as 2.5, is not converted either: the getter then casts it and throws the same
		 * TypeException a real row throws.
		 *
		 * @param value The value read under an alias.
		 *
		 * @return True when the row is a registered row and the value is a whole number.
		 */
		private Boolean isConvertibleNumber(Object value)
		{
			return result == null && value instanceof Decimal && ((Decimal)value).stripTrailingZeros().scale() <= 0;
		}

		/**
		 * @description Gets a raw Object value by alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The raw value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .sum(Opportunity.Amount, 'total')
		 *     .getFirstAggregate();
		 * Object value = row.get('total');
		 * ```
		 */
		global Object get(String alias)
		{
			return readValue(alias);
		}

		/**
		 * @description Reads a number with decimals, such as the SUM or AVG of an amount. Returns null when the row holds null
		 * under the alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Decimal value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .sum(Opportunity.Amount, 'total')
		 *     .getFirstAggregate();
		 * Decimal total = row.getDecimal('total');
		 * ```
		 */
		global Decimal getDecimal(String alias)
		{
			return (Decimal)readValue(alias);
		}

		/**
		 * @description Reads a whole number, such as a COUNT. A row that a test registered with TST_Mock.registerAggregateRows
		 * may hold the number as a Long or a Decimal; a whole number held either way is converted to an Integer, and a number
		 * with a fraction, such as 2.5, throws a TypeException. Returns null when the row holds null under the alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Integer value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .count(Opportunity.Id, 'total')
		 *     .getFirstAggregate();
		 * Integer count = row.getInteger('total');
		 * ```
		 */
		global Integer getInteger(String alias)
		{
			Object value = readValue(alias);
			return isConvertibleNumber(value) ? ((Decimal)value).intValue() : (Integer)value;
		}

		/**
		 * @description Reads a text value, such as a grouped text or picklist field. A grouped field with no alias is read by its
		 * field name, such as 'Industry'. Returns null when the row holds null under the alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The String value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String industry = row.getString('Industry');
		 * ```
		 */
		global String getString(String alias)
		{
			return (String)readValue(alias);
		}

		/**
		 * @description Reads a record Id, such as a grouped lookup field. A grouped field with no alias is read by its field name,
		 * such as 'AccountId'. Returns null when the row holds null under the alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Id value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Id accountId = row.getId('AccountId');
		 * ```
		 */
		global Id getId(String alias)
		{
			return (Id)readValue(alias);
		}

		/**
		 * @description Reads a whole number as a Long. A value held as an Integer, such as a COUNT, is returned as a Long too.
		 * Returns null when the row holds null under the alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Long value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .count(Opportunity.Id, 'total')
		 *     .getFirstAggregate();
		 * Long total = row.getLong('total');
		 * ```
		 */
		global Long getLong(String alias)
		{
			Object value = readValue(alias);
			if(isConvertibleNumber(value))
			{
				return ((Decimal)value).longValue();
			}
			if(value instanceof Integer)
			{
				Integer integerValue = (Integer)value;
				return integerValue;
			}
			return value == null ? null : (Long)value;
		}

		/**
		 * @description Reads a date, such as the MIN or MAX of a date field. Returns null when the row holds null under the
		 * alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Date value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .min(Opportunity.CloseDate, 'earliest')
		 *     .getFirstAggregate();
		 * Date earliest = row.getDate('earliest');
		 * ```
		 */
		global Date getDate(String alias)
		{
			return (Date)readValue(alias);
		}
	}

	/**
	 * @description Fluent builder for field-level conditions (WHERE and HAVING).
	 *
	 * @since 1.0
	 */
	global inherited sharing class ConditionBuilder
	{
		/**
		 * @description Reference to the parent builder for method chaining.
		 */
		private final Builder parentBuilder;

		/**
		 * @description The field name this condition applies to.
		 */
		private final String fieldName;

		/**
		 * @description True when the condition goes into the HAVING clause and tests an aggregate, such as SUM(Amount). False
		 * when it goes into the WHERE clause and tests each record.
		 */
		private final Boolean isHaving;

		/**
		 * @description Starts a condition and checks its field text first, so a text that is not a field name fails at the
		 * call that started the condition, before an operator is chosen. The field may be a field path such as
		 * Account.Name, a date or distance function from QRY_Function, an aggregate such as SUM(Amount), or toLabel around
		 * a field path. A blank text is not checked here: the condition refuses it when the operator is chosen.
		 *
		 * @param parent The parent Builder
		 * @param field The field API name
		 * @param isHavingCondition Whether this is a HAVING condition
		 * @param methodName The builder method the developer called, such as condition or havingSumOf. The error message
		 * names it.
		 *
		 * @throws IllegalArgumentException if the field text is not blank and is not a field name. The message does not
		 * repeat the text.
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters,PMD.ExcessiveParameterList')
		public ConditionBuilder(Builder parent, String field, Boolean isHavingCondition, String methodName)
		{
			QRY_Generator.validateConditionField(field, methodName);
			parentBuilder = parent;
			fieldName = field;
			isHaving = isHavingCondition;
		}

		/**
		 * @description Hands the finished condition to the parent builder: to its HAVING conditions when isHaving is true, and
		 * to its WHERE conditions otherwise.
		 *
		 * @param condition The condition to add
		 */
		private void add(QRY_Condition.Evaluable condition)
		{
			if(isHaving)
			{
				parentBuilder.addHavingCondition(condition);
			}
			else
			{
				parentBuilder.addCondition(condition);
			}
		}

		/**
		 * @description Extracts field values from a list of SObjects. A null record always adds nothing. A record whose field
		 * is blank adds a blank value only when keepBlankValues is true. The IN conditions leave blanks out, so a blank key
		 * never matches a stored row whose field is blank too. The NOT IN conditions keep them, so rows whose field is blank
		 * stay out of the result.
		 *
		 * @param records SObjects to extract values from
		 * @param field The field to extract values from
		 * @param keepBlankValues True to add a blank value for each record whose field is blank
		 *
		 * @return List of extracted values; empty when no record gives a value
		 */
		private List<Object> extractFieldValues(List<SObject> records, SObjectField field, Boolean keepBlankValues)
		{
			List<Object> values = new List<Object>();
			for(SObject record : records)
			{
				if(record != null)
				{
					Object value = record.get(field);
					if(value != null || keepBlankValues)
					{
						values.add(value);
					}
				}
			}
			return values;
		}

		/**
		 * @description Keeps the records whose field holds exactly this value. The value is passed to the query as a bind
		 * variable, so you never escape quotes in text yourself. A null value keeps the records whose field is blank, as
		 * isNull() does. To compare with a relative date such as today, pass a QRY_Condition.DateLiteral.
		 *
		 * @param value Value to compare against
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Name).equals('Acme Corp')
		 *     .toList();
		 * ```
		 */
		@SuppressWarnings('ApexEqualsHashCodeNotPaired, PMD.OverrideBothEqualsAndHashcode')
		global Builder equals(Object value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.EQUALS, value));
			return parentBuilder;
		}

		/**
		 * @description Leaves out the records whose field holds exactly this value. The value is passed to the query as a bind
		 * variable, so you never escape quotes in text yourself. A null value keeps the records whose field has a value, as
		 * isNotNull() does.
		 *
		 * @param value Value to compare against
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).notEquals('Government')
		 *     .toList();
		 * ```
		 */
		global Builder notEquals(Object value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.NOT_EQUALS, value));
			return parentBuilder;
		}

		/**
		 * @description Adds an = condition comparing to an SObject's Id.
		 *
		 * @param record SObject whose Id to compare against
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .condition(Contact.AccountId).equals(account)
		 *     .toList();
		 * ```
		 */
		global Builder equals(SObject record)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.EQUALS, record?.Id));
			return parentBuilder;
		}

		/**
		 * @description Adds a != condition comparing to an SObject's Id.
		 *
		 * @param record SObject whose Id to exclude
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .condition(Contact.AccountId).notEquals(excludedAccount)
		 *     .toList();
		 * ```
		 */
		global Builder notEquals(SObject record)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.NOT_EQUALS, record?.Id));
			return parentBuilder;
		}

		/**
		 * @description Keeps the records whose field is larger than this value; for a date or a time, later. The value is passed
		 * to the query as a bind variable. After a having method such as havingSumOf, it compares the aggregate of each group
		 * instead of each record.
		 *
		 * @param value Value to compare against
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.AnnualRevenue).greaterThan(1000000)
		 *     .toList();
		 * ```
		 */
		global Builder greaterThan(Object value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.GREATER_THAN, value));
			return parentBuilder;
		}

		/**
		 * @description Keeps the records whose field is equal to this value or larger; for a date or a time, the same or later.
		 * The value is passed to the query as a bind variable. After a having method such as havingSumOf, it compares the
		 * aggregate of each group instead of each record.
		 *
		 * @param value Value to compare against
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.NumberOfEmployees).greaterThanOrEquals(100)
		 *     .toList();
		 * ```
		 */
		global Builder greaterThanOrEquals(Object value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.GREATER_THAN_OR_EQUAL_TO, value));
			return parentBuilder;
		}

		/**
		 * @description Keeps the records whose field is smaller than this value; for a date or a time, earlier. The value is
		 * passed to the query as a bind variable. After a having method such as havingSumOf, it compares the aggregate of each
		 * group instead of each record.
		 *
		 * @param value Value to compare against
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.AnnualRevenue).lessThan(50000)
		 *     .toList();
		 * ```
		 */
		global Builder lessThan(Object value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.LESS_THAN, value));
			return parentBuilder;
		}

		/**
		 * @description Keeps the records whose field is equal to this value or smaller; for a date or a time, the same or
		 * earlier. The value is passed to the query as a bind variable. After a having method such as havingSumOf, it compares
		 * the aggregate of each group instead of each record.
		 *
		 * @param value Value to compare against
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.NumberOfEmployees).lessThanOrEquals(10)
		 *     .toList();
		 * ```
		 */
		global Builder lessThanOrEquals(Object value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.LESS_THAN_OR_EQUAL_TO, value));
			return parentBuilder;
		}

		/**
		 * @description Keeps the records whose field holds any one of these values. A null or empty set adds a condition that is
		 * never true, so this condition matches no record; the query still runs. The values are copied, so a later change to
		 * the set does not change the query.
		 *
		 * @param values Values to include
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> industries = new Set<Object>{'Technology', 'Finance'};
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).isIn(industries)
		 *     .toList();
		 * ```
		 */
		global Builder isIn(Set<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				add(new QRY_Condition.FalseCondition());
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object>(values)));
			return parentBuilder;
		}

		/**
		 * @description Adds an IN condition using a List.
		 *
		 * @param values Values to include
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> types = new List<Object>{'Customer', 'Partner'};
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).isIn(types)
		 *     .toList();
		 * ```
		 */
		global Builder isIn(List<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				add(new QRY_Condition.FalseCondition());
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, values));
			return parentBuilder;
		}

		/**
		 * @description Adds an IN condition using a List of SObjects.
		 *
		 * @param records SObjects to include (their Ids will be matched)
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .condition(Contact.AccountId).isIn(parentAccounts)
		 *     .toList();
		 * ```
		 */
		global Builder isIn(List<SObject> records)
		{
			if(records == null || records.isEmpty())
			{
				add(new QRY_Condition.FalseCondition());
				return parentBuilder;
			}
			List<Object> ids = new List<Object>();
			for(SObject record : records)
			{
				if(record != null)
				{
					ids.add(record.Id);
				}
			}
			if(ids.isEmpty())
			{
				add(new QRY_Condition.FalseCondition());
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, ids));
			return parentBuilder;
		}

		/**
		 * @description Adds an IN condition by extracting field values from SObjects. A record whose key field is blank is skipped,
		 * so it never matches a row whose field is blank.
		 *
		 * @param records SObjects to extract values from
		 * @param field The field to extract values from
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).isIn(contacts, Contact.AccountId)
		 *     .toList();
		 * ```
		 */
		global Builder isIn(List<SObject> records, SObjectField field)
		{
			if(records == null || records.isEmpty())
			{
				add(new QRY_Condition.FalseCondition());
				return parentBuilder;
			}
			List<Object> values = extractFieldValues(records, field, false);
			if(values.isEmpty())
			{
				add(new QRY_Condition.FalseCondition());
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, values));
			return parentBuilder;
		}

		/**
		 * @description Adds a semi-join IN condition using a subquery.
		 *
		 * @param subquery Builder representing the subquery
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .fields(new List<SObjectField>{Contact.AccountId})
		 *     .condition(Contact.Email).isNotNull();
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).isIn(subquery)
		 *     .toList();
		 * ```
		 */
		global Builder isIn(Builder subquery)
		{
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, subquery.toSoqlBuilder()));
			return parentBuilder;
		}

		/**
		 * @description Adds an IN condition with strict empty list handling.
		 *
		 * @param values Values to include (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if values is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> statuses = new List<Object>{'Active', 'Pending'};
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).isInStrict(statuses)
		 *     .toList();
		 * ```
		 */
		global Builder isInStrict(List<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values list cannot be null or empty');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, values));
			return parentBuilder;
		}

		/**
		 * @description Adds an IN condition with strict empty set handling.
		 *
		 * @param values Values to include (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if values is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> statuses = new Set<Object>{'Active', 'Pending'};
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).isInStrict(statuses)
		 *     .toList();
		 * ```
		 */
		global Builder isInStrict(Set<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values set cannot be null or empty');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object>(values)));
			return parentBuilder;
		}

		/**
		 * @description Adds an IN condition using SObjects with strict handling.
		 *
		 * @param records SObjects to include (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if records is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> parents = [SELECT Id FROM Account LIMIT 10];
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .condition(Contact.AccountId).isInStrict(parents)
		 *     .toList();
		 * ```
		 */
		global Builder isInStrict(List<SObject> records)
		{
			if(records == null || records.isEmpty())
			{
				throw new IllegalArgumentException('Records list cannot be null or empty');
			}
			List<Object> ids = new List<Object>();
			for(SObject record : records)
			{
				if(record != null)
				{
					ids.add(record.Id);
				}
			}
			if(ids.isEmpty())
			{
				throw new IllegalArgumentException('Records list contains no valid records');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, ids));
			return parentBuilder;
		}

		/**
		 * @description Adds an IN condition by extracting field values with strict handling. A record whose key field is blank is
		 * skipped, so it never matches a row whose field is blank.
		 *
		 * @param records SObjects to extract values from (must not be null or empty)
		 * @param field The field to extract values from
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if records is null or empty, or no record has a value in the field
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = [SELECT AccountId FROM Contact LIMIT 10];
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).isInStrict(contacts, Contact.AccountId)
		 *     .toList();
		 * ```
		 */
		global Builder isInStrict(List<SObject> records, SObjectField field)
		{
			if(records == null || records.isEmpty())
			{
				throw new IllegalArgumentException('Records list cannot be null or empty');
			}
			List<Object> values = extractFieldValues(records, field, false);
			if(values.isEmpty())
			{
				throw new IllegalArgumentException('Records list contains no valid records');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, values));
			return parentBuilder;
		}

		/**
		 * @description Leaves out the records whose field holds any one of these values. A null or empty set adds no condition,
		 * so no record is left out; isIn() does the opposite and matches nothing. The values are copied, so a later change to
		 * the set does not change the query.
		 *
		 * @param values Values to exclude
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> excluded = new Set<Object>{'Competitor', 'Other'};
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).notInSet(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder notInSet(Set<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, new List<Object>(values)));
			return parentBuilder;
		}

		/**
		 * @description Adds a NOT IN condition using a List.
		 *
		 * @param values Values to exclude
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> excluded = new List<Object>{'Competitor', 'Other'};
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).notInSet(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder notInSet(List<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, values));
			return parentBuilder;
		}

		/**
		 * @description Adds a NOT IN condition using a List of SObjects.
		 *
		 * @param records SObjects to exclude
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> excluded = [SELECT Id FROM Account WHERE Type = 'Competitor'];
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .condition(Contact.AccountId).notInSet(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder notInSet(List<SObject> records)
		{
			if(records == null || records.isEmpty())
			{
				return parentBuilder;
			}
			List<Object> ids = new List<Object>();
			for(SObject record : records)
			{
				if(record != null)
				{
					ids.add(record.Id);
				}
			}
			if(ids.isEmpty())
			{
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, ids));
			return parentBuilder;
		}

		/**
		 * @description Adds a NOT IN condition by extracting field values from SObjects. A record whose key field is blank is
		 * kept, so rows whose field is blank are left out of the result too.
		 *
		 * @param records SObjects to extract values from
		 * @param field The field to extract values from
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = [SELECT AccountId FROM Contact WHERE IsDeleted = true];
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).notInSet(contacts, Contact.AccountId)
		 *     .toList();
		 * ```
		 */
		global Builder notInSet(List<SObject> records, SObjectField field)
		{
			if(records == null || records.isEmpty())
			{
				return parentBuilder;
			}
			List<Object> values = extractFieldValues(records, field, true);
			if(values.isEmpty())
			{
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, values));
			return parentBuilder;
		}

		/**
		 * @description Adds an anti-join NOT IN condition using a subquery.
		 *
		 * @param subquery Builder representing the subquery
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .fields(new List<SObjectField>{Contact.AccountId})
		 *     .condition(Contact.HasOptedOutOfEmail).equals(true);
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).notIn(subquery)
		 *     .toList();
		 * ```
		 */
		global Builder notIn(Builder subquery)
		{
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, subquery.toSoqlBuilder()));
			return parentBuilder;
		}

		/**
		 * @description Adds a NOT IN condition with strict empty list handling.
		 *
		 * @param values Values to exclude (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if values is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> excluded = new List<Object>{'Competitor', 'Other'};
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).notInSetStrict(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder notInSetStrict(List<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values list cannot be null or empty');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, values));
			return parentBuilder;
		}

		/**
		 * @description Adds a NOT IN condition with strict empty set handling.
		 *
		 * @param values Values to exclude (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if values is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> excluded = new Set<Object>{'Competitor', 'Other'};
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).notInSetStrict(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder notInSetStrict(Set<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values set cannot be null or empty');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, new List<Object>(values)));
			return parentBuilder;
		}

		/**
		 * @description Adds a NOT IN condition using SObjects with strict handling.
		 *
		 * @param records SObjects to exclude (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if records is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> excluded = [SELECT Id FROM Account WHERE Type = 'Competitor'];
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .condition(Contact.AccountId).notInSetStrict(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder notInSetStrict(List<SObject> records)
		{
			if(records == null || records.isEmpty())
			{
				throw new IllegalArgumentException('Records list cannot be null or empty');
			}
			List<Object> ids = new List<Object>();
			for(SObject record : records)
			{
				if(record != null)
				{
					ids.add(record.Id);
				}
			}
			if(ids.isEmpty())
			{
				throw new IllegalArgumentException('Records list contains no valid records');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, ids));
			return parentBuilder;
		}

		/**
		 * @description Adds a NOT IN condition by extracting field values with strict handling. A record whose key field is
		 * blank is kept, so rows whose field is blank are left out of the result too.
		 *
		 * @param records SObjects to extract values from (must not be null or empty)
		 * @param field The field to extract values from
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if records is null or empty, or every record in it is null
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = [SELECT AccountId FROM Contact WHERE IsDeleted = true];
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).notInSetStrict(contacts, Contact.AccountId)
		 *     .toList();
		 * ```
		 */
		global Builder notInSetStrict(List<SObject> records, SObjectField field)
		{
			if(records == null || records.isEmpty())
			{
				throw new IllegalArgumentException('Records list cannot be null or empty');
			}
			List<Object> values = extractFieldValues(records, field, true);
			if(values.isEmpty())
			{
				throw new IllegalArgumentException('Records list contains no valid records');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, values));
			return parentBuilder;
		}

		/**
		 * @description Keeps the records whose field is blank. It writes "field = null" into the query, the same as equals(null).
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .condition(Contact.Email).isNull()
		 *     .toList();
		 * ```
		 */
		global Builder isNull()
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.EQUALS, null));
			return parentBuilder;
		}

		/**
		 * @description Keeps the records whose field has a value. It writes "field != null" into the query, the same as
		 * notEquals(null).
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .condition(Contact.Email).isNotNull()
		 *     .toList();
		 * ```
		 */
		global Builder isNotNull()
		{
			add(new QRY_Condition.FieldCondition(fieldName).notEquals(null));
			return parentBuilder;
		}

		/**
		 * @description Adds a LIKE condition with wildcards on both sides (contains).
		 *
		 * @param value Text to search for
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Name).contains('Corp')
		 *     .toList();
		 * ```
		 */
		global Builder contains(String value)
		{
			add
					(
							new QRY_Condition.FieldCondition
									(
											fieldName,
											QRY_Condition.Operator.LIKE_X,
											QRY_Condition.LIKE_MULTIPLE_CHARACTER_WILDCARD + value + QRY_Condition.LIKE_MULTIPLE_CHARACTER_WILDCARD
									)
					);

			return parentBuilder;
		}

		/**
		 * @description Adds a LIKE condition with wildcard at end (starts with).
		 *
		 * @param value Text prefix
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Name).startsWith('Acme')
		 *     .toList();
		 * ```
		 */
		global Builder startsWith(String value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.LIKE_X, value + QRY_Condition.LIKE_MULTIPLE_CHARACTER_WILDCARD));
			return parentBuilder;
		}

		/**
		 * @description Adds a LIKE condition with wildcard at start (ends with).
		 *
		 * @param value Text suffix
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Name).endsWith('Inc.')
		 *     .toList();
		 * ```
		 */
		global Builder endsWith(String value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.LIKE_X, QRY_Condition.LIKE_MULTIPLE_CHARACTER_WILDCARD + value));
			return parentBuilder;
		}

		/**
		 * @description Adds an INCLUDES condition for multi-picklist fields.
		 *
		 * @param values Values that must all be selected
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> interests = new List<Object>{'Technology', 'Finance'};
		 * List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
		 *     .condition('Interests__c').includes(interests)
		 *     .toList();
		 * ```
		 
		 */
		global Builder includes(List<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				add(new QRY_Condition.FalseCondition());
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.INCLUDES, values));
			return parentBuilder;
		}

		/**
		 * @description Adds an INCLUDES condition for multi-picklist fields using a Set.
		 *
		 * @param values Values that must all be selected
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> interests = new Set<Object>{'Technology', 'Finance'};
		 * List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
		 *     .condition('Interests__c').includes(interests)
		 *     .toList();
		 * ```
		 */
		global Builder includes(Set<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				add(new QRY_Condition.FalseCondition());
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.INCLUDES, new List<Object>(values)));
			return parentBuilder;
		}

		/**
		 * @description Adds an INCLUDES condition with strict empty list handling.
		 *
		 * @param values Values that must all be selected (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if values is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> interests = new List<Object>{'Technology', 'Finance'};
		 * List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
		 *     .condition('Interests__c').includesStrict(interests)
		 *     .toList();
		 * ```
		 */
		global Builder includesStrict(List<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values list cannot be null or empty');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.INCLUDES, values));
			return parentBuilder;
		}

		/**
		 * @description Adds an INCLUDES condition with strict empty set handling.
		 *
		 * @param values Values that must all be selected (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if values is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> interests = new Set<Object>{'Technology', 'Finance'};
		 * List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
		 *     .condition('Interests__c').includesStrict(interests)
		 *     .toList();
		 * ```
		 */
		global Builder includesStrict(Set<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values set cannot be null or empty');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.INCLUDES, new List<Object>(values)));
			return parentBuilder;
		}

		/**
		 * @description Adds an EXCLUDES condition for multi-picklist fields.
		 *
		 * @param values Values that must not be selected
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> excluded = new List<Object>{'Inactive', 'Archived'};
		 * List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
		 *     .condition('Tags__c').excludes(excluded)
		 *     .toList();
		 * ```
		 
		 */
		global Builder excludes(List<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.EXCLUDES, values));
			return parentBuilder;
		}

		/**
		 * @description Adds an EXCLUDES condition for multi-picklist fields using a Set.
		 *
		 * @param values Values that must not be selected
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> excluded = new Set<Object>{'Inactive', 'Archived'};
		 * List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
		 *     .condition('Tags__c').excludes(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder excludes(Set<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				return parentBuilder;
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.EXCLUDES, new List<Object>(values)));
			return parentBuilder;
		}

		/**
		 * @description Adds an EXCLUDES condition with strict empty list handling.
		 *
		 * @param values Values that must not be selected (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if values is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> excluded = new List<Object>{'Inactive', 'Archived'};
		 * List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
		 *     .condition('Tags__c').excludesStrict(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder excludesStrict(List<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values list cannot be null or empty');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.EXCLUDES, values));
			return parentBuilder;
		}

		/**
		 * @description Adds an EXCLUDES condition with strict empty set handling.
		 *
		 * @param values Values that must not be selected (must not be null or empty)
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if values is null or empty
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> excluded = new Set<Object>{'Inactive', 'Archived'};
		 * List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
		 *     .condition('Tags__c').excludesStrict(excluded)
		 *     .toList();
		 * ```
		 */
		global Builder excludesStrict(Set<Object> values)
		{
			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values set cannot be null or empty');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.EXCLUDES, new List<Object>(values)));
			return parentBuilder;
		}
	}

	/**
	 * @description Fluent builder for WITH DATA CATEGORY filters.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	 *     .fields(new List<String>{'Id', 'Title'})
	 *     .condition('PublishStatus').equals('Online')
	 *     .withDataCategory('Geography__c').at('USA__c')
	 *     .withDataCategory('Product__c').below('Electronics__c')
	 *     .toList();
	 * ```
	 */
	global inherited sharing class DataCategoryBuilder
	{
		/**
		 * @description Reference to the parent builder for method chaining.
		 */
		private final Builder parentBuilder;

		/**
		 * @description The API name of the data category group to filter on, such as Geography__c. A query may hold only one
		 * filter for each group.
		 */
		private final String groupName;

		/**
		 * @description Holds the group until at, above, below or aboveOrBelow adds the filter to the parent builder.
		 * withDataCategory checks that the group name is not blank before it calls this. The group name must be a single
		 * API name, such as Name.
		 *
		 * @param parent The parent Builder
		 * @param categoryGroup The data category group name
		 *
		 * @throws IllegalArgumentException if the group name is not blank and is not a single API name, such as Name
		 */
		public DataCategoryBuilder(Builder parent, String categoryGroup)
		{
			QRY_Generator.validateFieldPath(categoryGroup, 'DataCategoryBuilder');
			parentBuilder = parent;
			groupName = categoryGroup;
		}

		/**
		 * @description Filters to the exact specified category.
		 * Text that comes from a page or a user must first be matched to a category through a list of names you allow.
		 *
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryName is blank, or is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .withDataCategory('Geography__c').at('USA__c')
		 * ```
		 */
		global Builder at(String categoryName)
		{
			return addFilter(QRY_Generator.DataCategoryOperator.AT, categoryName, 'at');
		}

		/**
		 * @description Filters to any of the specified categories.
		 * Text that comes from a page or a user must first be matched to a category through a list of names you allow.
		 *
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryNames is null or empty, or a name in it is not blank and is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .withDataCategory('Geography__c').at(new List<String>{'USA__c', 'Canada__c'})
		 * ```
		 */
		global Builder at(List<String> categoryNames)
		{
			return addFilter(QRY_Generator.DataCategoryOperator.AT, categoryNames, 'at');
		}

		/**
		 * @description Filters to categories above the specified category in the hierarchy.
		 * Text that comes from a page or a user must first be matched to a category through a list of names you allow.
		 *
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryName is blank, or is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .withDataCategory('Geography__c').above('USA__c')
		 * ```
		 */
		global Builder above(String categoryName)
		{
			return addFilter(QRY_Generator.DataCategoryOperator.ABOVE, categoryName, 'above');
		}

		/**
		 * @description Filters to categories above any of the specified categories in the hierarchy.
		 * Text that comes from a page or a user must first be matched to a category through a list of names you allow.
		 *
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryNames is null or empty, or a name in it is not blank and is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .withDataCategory('Geography__c').above(new List<String>{'USA__c', 'Canada__c'})
		 * ```
		 */
		global Builder above(List<String> categoryNames)
		{
			return addFilter(QRY_Generator.DataCategoryOperator.ABOVE, categoryNames, 'above');
		}

		/**
		 * @description Filters to categories below the specified category in the hierarchy.
		 * Text that comes from a page or a user must first be matched to a category through a list of names you allow.
		 *
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryName is blank, or is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .withDataCategory('Product__c').below('Electronics__c')
		 * ```
		 */
		global Builder below(String categoryName)
		{
			return addFilter(QRY_Generator.DataCategoryOperator.BELOW, categoryName, 'below');
		}

		/**
		 * @description Filters to categories below any of the specified categories in the hierarchy.
		 * Text that comes from a page or a user must first be matched to a category through a list of names you allow.
		 *
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryNames is null or empty, or a name in it is not blank and is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .withDataCategory('Product__c').below(new List<String>{'Electronics__c', 'Clothing__c'})
		 * ```
		 */
		global Builder below(List<String> categoryNames)
		{
			return addFilter(QRY_Generator.DataCategoryOperator.BELOW, categoryNames, 'below');
		}

		/**
		 * @description Filters to categories above or below the specified category in the hierarchy.
		 * Text that comes from a page or a user must first be matched to a category through a list of names you allow.
		 *
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryName is blank, or is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .withDataCategory('Audience__c').aboveOrBelow('External')
		 * ```
		 */
		global Builder aboveOrBelow(String categoryName)
		{
			return addFilter(QRY_Generator.DataCategoryOperator.ABOVE_BELOW, categoryName, 'aboveOrBelow');
		}

		/**
		 * @description Filters to categories above or below any of the specified categories in the hierarchy.
		 * Text that comes from a page or a user must first be matched to a category through a list of names you allow.
		 *
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryNames is null or empty, or a name in it is not blank and is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .withDataCategory('Audience__c').aboveOrBelow(new List<String>{'External', 'Internal'})
		 * ```
		 */
		global Builder aboveOrBelow(List<String> categoryNames)
		{
			return addFilter(QRY_Generator.DataCategoryOperator.ABOVE_BELOW, categoryNames, 'aboveOrBelow');
		}

		/**
		 * @description Validates and adds a single-category filter to the parent builder.
		 *
		 * @param operator The filtering operator
		 * @param categoryName The category API name
		 * @param methodName The builder method the developer called. The error message names it.
		 *
		 * @return Builder for chaining
		 */
		private Builder addFilter(QRY_Generator.DataCategoryOperator operator, String categoryName, String methodName)
		{
			if(String.isBlank(categoryName))
			{
				throw new IllegalArgumentException('Category name cannot be blank.');
			}
			return addFilter(operator, new List<String> {categoryName}, methodName);
		}

		/**
		 * @description Validates and adds a multi-category filter to the parent builder.
		 *
		 * @param operator The filtering operator
		 * @param categoryNames The category API names
		 * @param methodName The builder method the developer called. The error message names it.
		 *
		 * @return Builder for chaining
		 */
		private Builder addFilter(QRY_Generator.DataCategoryOperator operator, List<String> categoryNames, String methodName)
		{
			if(categoryNames == null || categoryNames.isEmpty())
			{
				throw new IllegalArgumentException('Category names list cannot be null or empty.');
			}
			for(String categoryName : categoryNames)
			{
				QRY_Generator.validateFieldPath(categoryName, methodName);
			}
			String key = groupName.toLowerCase();
			if(parentBuilder.dataCategoryFilters.containsKey(key))
			{
				throw new IllegalArgumentException
						(
								'A data category filter for group \'' + groupName + '\' has already been added. '
								+ 'SOQL only permits one filter per data category group.'
						);
			}
			parentBuilder.dataCategoryFilters.put(key, new DataCategoryEntry(groupName, operator, categoryNames));
			return parentBuilder;
		}
	}

	/**
	 * @description Extensible query builder class. Maintains internal query state
	 * and uses QRY_Generator for SOQL building and QRY_Engine for execution.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .addField(Account.Name)
	 *     .condition(Account.Industry).equals('Technology');
	 * List<Account> accounts = query.toList();
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessivePublicCount,PMD.TooManyFields')
	global virtual inherited sharing class Builder implements IF_Queryable
	{

		/**
		 * @description Fields explicitly requested by the caller. Lazy-loaded on first access.
		 */
		@TestVisible
		private final Set<String> explicitFields
		{
			get
			{
				if(explicitFields == null)
				{
					explicitFields = new Set<String>();
				}
				return explicitFields;
			}
			private set;
		}

		/**
		 * @description Whether to include default fields.
		 */
		@TestVisible
		private Boolean useDefaultFields = true;

		/**
		 * @description Whether to run the query in USER_MODE. Initial value resolves the
		 * `UserModeQueries_Enabled` feature flag; explicit `.withUserMode()` / `.withSystemMode()`
		 * calls override the flag-driven default.
		 */
		@TestVisible
		private Boolean userModeEnabled = QRY_Builder.userModeQueriesEnabled();

		/**
		 * @description Whether to strip inaccessible fields from results.
		 */
		@TestVisible
		private Boolean stripInaccessibleEnabled = false;

		/**
		 * @description Controls sharing rules enforcement. Null = inherited, true = with, false = without.
		 */
		@TestVisible
		private Boolean sharingEnforced;

		/**
		 * @description True when the last sharing call was the audited bypassSharing(). withSharing(),
		 * bypassSharingInternal() and withoutSecurity() set it back to false. When it is true and the read would
		 * otherwise run in USER_MODE, the read runs in SYSTEM_MODE without sharing and keeps the user's object and
		 * field checks in this class.
		 */
		private Boolean isAuditedSharingBypass = false;

		/**
		 * @description The bypass audit entries this builder will write for queries. The bypass audit records each
		 * time code skips the user's access checks. `withoutSecurity`, `withSystemMode` and `bypassSharing` add their
		 * entry to the queue with `auditQueue.queue(...)` when they are called. The first method that runs the query
		 * then records the builder's SObjectType with `auditQueue.recordOperation(...)`, which adds the object to each
		 * entry, and calls `auditQueue.flush()`. So a builder that is dropped before it runs writes nothing. The queue
		 * is created the first time it is used: when a bypass method is called, or when the builder runs.
		 */
		@TestVisible
		private final UTIL_BypassAudit.AuditQueue auditQueue
		{
			get
			{
				if(auditQueue == null)
				{
					auditQueue = new UTIL_BypassAudit.AuditQueue(UTIL_BypassAudit.SURFACE_QUERY);
				}
				return auditQueue;
			}
			private set;
		}

		/**
		 * @description Maximum number of records to return (LIMIT clause).
		 */
		@TestVisible
		private Integer maxRecords;

		/**
		 * @description Number of records to skip (OFFSET clause).
		 */
		@TestVisible
		private Integer offsetCount;

		/**
		 * @description Cache Time-To-Live in seconds. Null = no caching.
		 */
		@TestVisible
		private Integer cacheTTL;

		/**
		 * @description Where cached results may be kept. Null = no caching. Set by withCache and withoutCache.
		 */
		@TestVisible
		private UTIL_Cache.Scope cacheScope;

		/**
		 * @description Whether to lock records FOR UPDATE.
		 */
		@TestVisible
		private Boolean lockForUpdate = false;

		/**
		 * @description Whether to lock records FOR REFERENCE.
		 */
		@TestVisible
		private Boolean lockForReference = false;

		/**
		 * @description Whether to lock records FOR VIEW.
		 */
		@TestVisible
		private Boolean lockForView = false;

		/**
		 * @description Whether to include ALL ROWS (deleted/archived).
		 */
		@TestVisible
		private Boolean includeAllRows = false;

		/**
		 * @description List of WHERE conditions. Lazy-loaded on first access.
		 */
		@TestVisible
		private final List<ConditionEntry> conditions
		{
			get
			{
				if(conditions == null)
				{
					conditions = new List<ConditionEntry>();
				}
				return conditions;
			}
			private set;
		}

		/**
		 * @description List of HAVING conditions. Lazy-loaded on first access.
		 */
		@TestVisible
		private final QRY_Condition.AndCondition havingConditions
		{
			get
			{
				if(havingConditions == null)
				{
					havingConditions = new QRY_Condition.AndCondition();
				}
				return havingConditions;
			}
			private set;
		}

		/**
		 * @description Whether the next condition is an OR condition.
		 */
		@TestVisible
		private Boolean nextIsOr = false;

		/**
		 * @description List of ORDER BY clauses. Lazy-loaded on first access.
		 */
		@TestVisible
		private final List<QRY_Generator.OrderBy> orderByFields
		{
			get
			{
				if(orderByFields == null)
				{
					orderByFields = new List<QRY_Generator.OrderBy>();
				}
				return orderByFields;
			}
			private set;
		}

		/**
		 * @description Aggregate function type.
		 */
		@TestVisible
		private QRY_Generator.Aggregate aggregateType;

		/**
		 * @description Field for aggregate function.
		 */
		@TestVisible
		private String aggregateField;

		/**
		 * @description Explicitly aliased aggregate selections, applied to the generator in call order at
		 * build time. Unlike the single aggregate above, these selections add up, so one query can combine several
		 * aggregates (e.g. COUNT plus MIN and MAX) and read each back by its alias. Lazy-loaded on first
		 * access.
		 *
		 * @date July 2026
		 */
		@TestVisible
		private final List<AggregateSelection> aggregateSelections
		{
			get
			{
				if(aggregateSelections == null)
				{
					aggregateSelections = new List<AggregateSelection>();
				}
				return aggregateSelections;
			}
			private set;
		}

		/**
		 * @description Field(s) for GROUP BY. Lazy-loaded on first access.
		 */
		@TestVisible
		private final List<String> groupByFields
		{
			get
			{
				if(groupByFields == null)
				{
					groupByFields = new List<String>();
				}
				return groupByFields;
			}
			private set;
		}

		/**
		 * @description Whether to use GROUP BY ROLLUP.
		 */
		@TestVisible
		private Boolean rollupMode = false;

		/**
		 * @description Whether to use GROUP BY CUBE.
		 */
		@TestVisible
		private Boolean cubeMode = false;

		/**
		 * @description USING SCOPE clause.
		 */
		@TestVisible
		private Scope scope;

		/**
		 * @description Child subqueries. Lazy-loaded on first access.
		 */
		@TestVisible
		private final List<Builder> childQueries
		{
			get
			{
				if(childQueries == null)
				{
					childQueries = new List<Builder>();
				}
				return childQueries;
			}
			private set;
		}

		/**
		 * @description Child relationship name for subquery.
		 */
		@TestVisible
		private String childRelationshipName;

		/**
		 * @description Whether results came from cache on last execution.
		 */
		@TestVisible
		private Boolean lastResultCached = false;

		/**
		 * @description Whether to select all fields on the object.
		 */
		@TestVisible
		private Boolean selectAll = false;

		/**
		 * @description Data category filters keyed by lowercase group name. Lazy-loaded on first access.
		 */
		@TestVisible
		private final Map<String, DataCategoryEntry> dataCategoryFilters
		{
			get
			{
				if(dataCategoryFilters == null)
				{
					dataCategoryFilters = new Map<String, DataCategoryEntry>();
				}
				return dataCategoryFilters;
			}
			private set;
		}

		/**
		 * @description Whether to use string literals instead of bind parameters in queries.
		 * When true, condition values are inlined as literals in the SOQL string rather than
		 * using bind variables. Intended for testing literal generation through the full
		 * query pipeline.
		 */
		@TestVisible
		private Boolean useLiterals = false;

		/**
		 * @description True stops the query from writing a performance log entry, however long it takes.
		 * suppressPerformanceLogging sets it; forcePerformanceLogging and logPerformanceIfSlowerThan clear it.
		 */
		@TestVisible
		private Boolean suppressPerformanceLog = false;

		/**
		 * @description Whether to force performance logging regardless of threshold.
		 */
		@TestVisible
		private Boolean forcePerformanceLog = false;

		/**
		 * @description Custom performance threshold in milliseconds.
		 */
		@TestVisible
		private Integer performanceThresholdMs;

		/**
		 * @description The object this builder reads, as passed to QRY_Builder.selectFrom. You can read it but not change it. It
		 * is null on a builder made with the constructor that takes no arguments.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType);
		 * SObjectType queryType = query.objectType; // Account.SObjectType
		 * ```
		 */
		global SObjectType objectType {get; private set;}

		/**
		 * @description Creates a builder with no object to read: objectType stays null, and nothing can set it later. To build
		 * a query you will run, use QRY_Builder.selectFrom or the constructor that takes an SObjectType.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.Builder query = new QRY_Builder.Builder();
		 * ```
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		global Builder()
		{
			// Explicit no-arg constructor kept for subscriber Apex binding stability.
		}

		/**
		 * @description Creates a builder that reads the given object. QRY_Builder.selectFrom calls this constructor, so the two
		 * give the same builder. A class that extends Builder calls it to set the object it reads.
		 *
		 * @param sObjectType The SObject to query
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.Builder query = new QRY_Builder.Builder(Account.SObjectType);
		 * ```
		 */
		global Builder(SObjectType sObjectType)
		{
			this();
			objectType = sObjectType;
		}

		/**
		 * @description Override to provide default fields for this selector.
		 *
		 * @return Set of field API names
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public override Set<String> getDefaultFields()
		 * {
		 *     return new Set<String>{'Name', 'Industry', 'Type'};
		 * }
		 * ```
		 */
		global virtual Set<String> getDefaultFields()
		{
			return new Set<String> {'Id'};
		}

		/**
		 * @description Override to provide a base condition applied to ALL queries.
		 * This is an internal extension point for framework classes within the managed package.
		 *
		 * @return Condition or null
		 */
		public virtual QRY_Condition.Evaluable getBaseCondition()
		{
			return null;
		}

		/**
		 * @description Override to provide default ordering.
		 * This is an internal extension point for framework classes within the managed package.
		 *
		 * @return List of OrderBy clauses or null
		 */
		public virtual List<QRY_Generator.OrderBy> getDefaultOrderBy()
		{
			return null;
		}

		/**
		 * @description Adds a condition to the HAVING clause, which tests the aggregate of each group. HAVING conditions are
		 * always joined with AND.
		 *
		 * @param condition The condition to add
		 */
		@TestVisible
		private void addHavingCondition(QRY_Condition.Evaluable condition)
		{
			havingConditions.add(condition);
		}

		/**
		 * @description Builds a QRY_Generator for subquery generation (semi-join/anti-join).
		 *
		 * @return QRY_Generator configured with current query state
		 */
		@TestVisible
		private QRY_Generator toSoqlBuilder()
		{
			QRY_Generator generator = new QRY_Generator()
					.fromObject(objectType)
					.addFields(new List<String>(getEffectiveFields()));

			QRY_Condition.Evaluable effectiveCondition = buildEffectiveCondition();
			if(effectiveCondition != null)
			{
				generator.whereCondition(effectiveCondition);
			}

			if(maxRecords != null)
			{
				generator.limitTo(maxRecords);
			}
			if(offsetCount != null)
			{
				generator.offset(offsetCount);
			}

			return generator;
		}

		/**
		 * @description Builds the effective WHERE condition combining base condition and user conditions.
		 *
		 * @return The combined condition or null if no conditions
		 */
		@TestVisible
		private QRY_Condition.Evaluable buildEffectiveCondition()
		{
			QRY_Condition.Evaluable baseCondition = getBaseCondition();

			if(conditions.isEmpty() && baseCondition == null)
			{
				return null;
			}

			QRY_Condition.AndCondition andGroup = new QRY_Condition.AndCondition();
			QRY_Condition.OrCondition orGroup = null;

			if(baseCondition != null)
			{
				andGroup.add(baseCondition);
			}

			for(ConditionEntry entry : conditions)
			{
				if(entry.isOr)
				{
					if(orGroup == null)
					{
						orGroup = new QRY_Condition.OrCondition();
						if(!andGroup.conditions.isEmpty())
						{
							orGroup.add(andGroup);
							andGroup = new QRY_Condition.AndCondition();
						}
					}
					orGroup.add(entry.condition);
				}
				else
				{
					andGroup.add(entry.condition);
				}
			}

			if(orGroup != null)
			{
				if(!andGroup.conditions.isEmpty())
				{
					orGroup.add(andGroup);
				}
				return orGroup;
			}

			if(andGroup.conditions.size() == 1)
			{
				return andGroup.conditions.iterator().next();
			}

			return andGroup;
		}

		/**
		 * @description Works out the fields to select. It joins every field of the object when selectAllFields was called, the
		 * default fields unless fields(), fieldSet() or onlyFields() turned them off, and every field added to the builder.
		 * When all of these are empty it returns just Id.
		 *
		 * @return Set of field names
		 */
		@TestVisible
		private Set<String> getEffectiveFields()
		{
			Set<String> result = new Set<String>();
			if(selectAll && objectType != null)
			{
				result.addAll(UTIL_SObjectDescribe.getAllFieldNames(UTIL_SObjectDescribe.getObjectNameFromType(objectType), false));
			}
			if(useDefaultFields)
			{
				result.addAll(getDefaultFields());
			}
			result.addAll(explicitFields);
			if(result.isEmpty())
			{
				result.add('Id');
			}
			return result;
		}

		/**
		 * @description Explicitly select fields using SObjectField tokens.
		 *
		 * @param objectFields List of SObjectField tokens
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .fields(new List<SObjectField>{Account.Name, Account.Industry})
		 *     .toList();
		 * ```
		 */
		global Builder fields(List<SObjectField> objectFields)
		{
			useDefaultFields = false;
			return addFields(objectFields);
		}

		/**
		 * @description Explicitly select fields by API name.
		 *
		 * @param fieldNames List of field API names
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .fields(new List<String>{'Name', 'Industry', 'AnnualRevenue'})
		 *     .toList();
		 * ```
		 */
		global Builder fields(List<String> fieldNames)
		{
			useDefaultFields = false;
			if(fieldNames != null)
			{
				explicitFields.addAll(fieldNames);
			}
			return this;
		}

		/**
		 * @description Replaces the SELECT field list with the given fields (subqueries and aggregate
		 * selections, if any, are untouched). `fields()` adds to the fields already on the builder (a selector's
		 * `query` getter starts with the selector's default field list). This method removes those fields first. It
		 * is the only way to select fewer fields than a selector's defaults, for example in a list view that must not
		 * load large long-text fields. It is public, not global, so subscribers cannot call it. Making it `global`
		 * later only adds to the API, if application code needs it.
		 *
		 * @param objectFields List of SObjectField tokens forming the complete selection
		 *
		 * @return Builder for chaining
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().query
		 *     .onlyFields(new List<SObjectField>{AsyncChainExecution__c.Status__c})
		 *     .getPage(1, 20);
		 * ```
		 */
		public Builder onlyFields(List<SObjectField> objectFields)
		{
			useDefaultFields = false;
			explicitFields.clear();
			return addFields(objectFields);
		}

		/**
		 * @description Adds fields to the selection without disabling default fields.
		 *
		 * @param objectFields List of SObjectField tokens
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addFields(new List<SObjectField>{Account.Phone, Account.Website})
		 *     .toList();
		 * ```

		 */
		global Builder addFields(List<SObjectField> objectFields)
		{
			if(objectFields != null)
			{
				for(SObjectField field : objectFields)
				{
					explicitFields.add(UTIL_SObjectDescribe.getCachedFieldName(field));
				}
			}
			return this;
		}

		/**
		 * @description Adds fields to the selection without disabling default fields.
		 *
		 * @param fieldNames List of field API names
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addFields(new List<String>{'Phone', 'Website'})
		 *     .toList();
		 * ```
		 
		 */
		global Builder addFields(List<String> fieldNames)
		{
			if(fieldNames != null)
			{
				explicitFields.addAll(fieldNames);
			}
			return this;
		}

		/**
		 * @description Adds a single field without disabling default fields.
		 *
		 * @param objectField SObjectField token
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addField(Account.Website)
		 *     .toList();
		 * ```
		 
		 */
		global Builder addField(SObjectField objectField)
		{
			if(objectField != null)
			{
				explicitFields.add(UTIL_SObjectDescribe.getCachedFieldName(objectField));
			}
			return this;
		}

		/**
		 * @description Adds a single field without disabling default fields.
		 *
		 * @param fieldName API name
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addField('Website')
		 *     .toList();
		 * ```
		 
		 */
		global Builder addField(String fieldName)
		{
			if(String.isNotBlank(fieldName))
			{
				explicitFields.add(fieldName);
			}
			return this;
		}

		/**
		 * @description Adds a SOQL date-function expression to SELECT under an explicit alias, so you can read it
		 * back through AggregateRow (e.g. CALENDAR_MONTH(CloseDate) closeMonth, then row.getInteger('closeMonth')).
		 * Use it with groupBy(QRY_Function) and the same factory, so the SELECT and GROUP BY expressions match.
		 * The alias must be a plain name, the same rule as for the aliased aggregate selections, so an alias a
		 * caller supplies can never add SOQL syntax to the clause.
		 *
		 * @param functionField The date-function expression, from a QRY_Function factory
		 * @param alias The read-back alias for the projected expression; must be a bare identifier
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if alias is not a bare identifier (a letter followed by
		 * letters, digits or underscores)
		 *
		 * @since 1.1
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .addField(QRY_Function.calendarMonth(Opportunity.CloseDate), 'closeMonth')
		 *     .count('Id')
		 *     .groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
		 *     .toAggregateList();
		 * ```
		 */
		global virtual Builder addField(QRY_Function functionField, String alias)
		{
			explicitFields.add(functionField.toExpression() + UTIL_String.SPACE + QRY_Generator.validateSelectAlias(alias));
			return this;
		}

		/**
		 * @description Configures the query to select ALL fields on the object.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .selectAllFields()
		 *     .withLimit(10)
		 *     .toList();
		 * ```
		 */
		global Builder selectAllFields()
		{
			selectAll = true;
			return this;
		}

		/**
		 * @description Selects fields from a FieldSet.
		 *
		 * @param fieldSetName The API Name of the FieldSet
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .fieldSet('Account_Summary')
		 *     .toList();
		 * ```
		 
		 */
		global Builder fieldSet(String fieldSetName)
		{
			useDefaultFields = false;
			return addFieldSet(fieldSetName);
		}

		/**
		 * @description Selects fields from a FieldSet token.
		 *
		 * @param aFieldset The Schema.FieldSet token
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * FieldSet fs = SObjectType.Account.fieldSets.Account_Summary;
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .fieldSet(fs)
		 *     .toList();
		 * ```
		 */
		global Builder fieldSet(FieldSet aFieldset)
		{
			useDefaultFields = false;
			return addFieldSet(aFieldset);
		}

		/**
		 * @description Adds fields from a FieldSet without disabling default fields.
		 *
		 * @param fieldSetName The API Name of the FieldSet
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addFieldSet('Account_Summary')
		 *     .toList();
		 * ```
		 
		 */
		global Builder addFieldSet(String fieldSetName)
		{
			return addFieldSet(UTIL_SObjectDescribe.getDescribe(objectType)?.getFieldSetsMap()?.get(fieldSetName));
		}

		/**
		 * @description Adds fields from a FieldSet token without disabling default fields.
		 *
		 * @param aFieldset The Schema.FieldSet token
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * FieldSet fs = SObjectType.Account.fieldSets.Account_Summary;
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addFieldSet(fs)
		 *     .toList();
		 * ```
		 */
		global Builder addFieldSet(FieldSet aFieldset)
		{
			if(aFieldset != null)
			{
				for(FieldSetMember member : aFieldset.getFields())
				{
					explicitFields.add(member.getFieldPath());
				}
			}
			return this;
		}

		/**
		 * @description Adds parent (related) fields to the selection. Each text must be a field name or a path through
		 * parent records, such as Account.Owner.Name. Text that comes from a page or a user must first be matched to a
		 * field through a list of fields you allow.
		 *
		 * @param parentFields A list of field API names, such as Name or Account.Owner.Name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if a text in the list is not blank and is not a field name or a path through
		 * parent records, such as Account.Owner.Name. Nothing is added then.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .relatedFields(new List<String>{'Account.Name', 'Account.Industry'})
		 *     .toList();
		 * ```
		 */
		global Builder relatedFields(List<String> parentFields)
		{
			if(parentFields != null)
			{
				for(String parentField : parentFields)
				{
					QRY_Generator.validateFieldPath(parentField, 'relatedFields');
				}
				explicitFields.addAll(parentFields);
			}
			return this;
		}

		/**
		 * @description Adds a single parent field. The text must be a field name or a path through parent records, such as
		 * Account.Owner.Name. Text that comes from a page or a user must first be matched to a field through a list of
		 * fields you allow.
		 *
		 * @param parentField A field API name, such as Name or Account.Owner.Name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a field name or a path through parent records, such as Account.Owner.Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .relatedField('Account.Owner.Name')
		 *     .toList();
		 * ```
		 */
		global Builder relatedField(String parentField)
		{
			if(String.isNotBlank(parentField))
			{
				QRY_Generator.validateFieldPath(parentField, 'relatedField');
				explicitFields.add(parentField);
			}
			return this;
		}

		/**
		 * @description Adds a child subquery (child relationship query). The relationship name must be a single API name,
		 * such as Contacts. Text that comes from a page or a user must first be matched to a relationship through a list
		 * of names you allow.
		 *
		 * @param childQuery Configured Builder for the child object
		 * @param relationshipName The child relationship API name (e.g., 'Contacts')
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the relationship name is not blank and is not a single API name, such as Contacts
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.Builder contactQuery = new QRY_Builder.Builder(Contact.SObjectType)
		 *     .fields(new List<SObjectField>{Contact.FirstName, Contact.LastName});
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .subselect(contactQuery, 'Contacts')
		 *     .toList();
		 * ```
		 */
		global Builder subselect(Builder childQuery, String relationshipName)
		{
			if(childQuery != null && String.isNotBlank(relationshipName))
			{
				QRY_Generator.validateFieldPath(relationshipName, 'subselect');
				childQuery.childRelationshipName = relationshipName;
				childQueries.add(childQuery);
			}
			return this;
		}

		/**
		 * @description Adds a GROUP BY clause. The text is kept as given. It may be one field or several joined by commas, and
		 * each may be a date function from QRY_Function. Text that comes from a page or a user must first be matched to a field
		 * through a list of fields you allow.
		 *
		 * @param groupField A field API name, such as Name or Account.Owner.Name, or a list such as Name, Industry
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a list of field names or date functions
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .groupBy('Industry')
		 *     .count('Id')
		 *     .toAggregateList();
		 * Integer firstIndustryCount = rows[0].getInteger('count_Id');
		 * ```
		 
		 */
		global Builder groupBy(String groupField)
		{
			QRY_Generator.validateGroupList(groupField, 'groupBy');
			groupByFields.add(groupField);
			return this;
		}

		/**
		 * @description Adds a field to the GROUP BY clause using an SObjectField token.
		 * Call it more than once to group by several fields (SOQL allows at most 3).
		 *
		 * @param groupField The field to group by
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .groupBy(Account.Industry)
		 *     .groupBy(Account.Rating)
		 *     .count('Id')
		 *     .toAggregateList();
		 * ```
		 */
		global Builder groupBy(SObjectField groupField)
		{
			return groupBy(UTIL_SObjectDescribe.getCachedFieldName(groupField));
		}

		/**
		 * @description Adds a SOQL date-function expression to the GROUP BY clause (e.g. CALENDAR_MONTH(CloseDate)),
		 * bucketing records by that date part. Use the same QRY_Function factory in addField to project the bucket.
		 *
		 * @param functionField The date-function expression, from a QRY_Function factory
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.1
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .addField(QRY_Function.calendarMonth(Opportunity.CloseDate), 'closeMonth')
		 *     .count('Id')
		 *     .groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
		 *     .toAggregateList();
		 * ```
		 */
		global virtual Builder groupBy(QRY_Function functionField)
		{
			return groupBy(functionField.toExpression());
		}

		/**
		 * @description Flags the GROUP BY clause as ROLLUP for subtotals.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .groupBy(Opportunity.AccountId)
		 *     .sum(Opportunity.Amount)
		 *     .rollup()
		 *     .toAggregateList();
		 * ```
		 */
		global Builder rollup()
		{
			rollupMode = true;
			cubeMode = false;
			return this;
		}

		/**
		 * @description Flags the GROUP BY clause as CUBE for cross-tabulation.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .groupBy(Opportunity.LeadSource)
		 *     .sum(Opportunity.Amount)
		 *     .cube()
		 *     .toAggregateList();
		 * ```
		 */
		global Builder cube()
		{
			cubeMode = true;
			rollupMode = false;
			return this;
		}

		/**
		 * @description Adds a GROUPING(field) expression to the SELECT clause for use with ROLLUP or CUBE.
		 * Returns 1 for subtotal rows and 0 for regular data rows.
		 *
		 * @param field The field to wrap in GROUPING()
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .grouping(Opportunity.StageName)
		 *     .sum(Opportunity.Amount)
		 *     .rollup()
		 *     .toAggregateList();
		 * ```
		 */
		global Builder grouping(SObjectField field)
		{
			return grouping(UTIL_SObjectDescribe.getCachedFieldName(field));
		}

		/**
		 * @description Adds a GROUPING(field) expression to the SELECT clause by field name. Text that comes from a page or a
		 * user must first be matched to a field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name, or a date function from QRY_Function
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a field name or a date function
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * .groupBy('Industry').grouping('Industry').rollup()
		 * ```
		 */
		global Builder grouping(String fieldName)
		{
			QRY_Generator.validateFieldExpression(fieldName, 'grouping');
			explicitFields.add('GROUPING(' + fieldName + ')');
			return this;
		}

		/**
		 * @description Applies a SUM aggregate function.
		 *
		 * @param field The field to aggregate
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .sum(Opportunity.Amount)
		 *     .toAggregateList();
		 * Decimal firstStageTotal = rows[0].getDecimal('sum_Amount');
		 * ```
		 */
		global Builder sum(SObjectField field)
		{
			aggregateType = QRY_Generator.Aggregate.SUM;
			aggregateField = UTIL_SObjectDescribe.getCachedFieldName(field);
			return this;
		}

		/**
		 * @description Applies an AVG aggregate function.
		 *
		 * @param field The field to aggregate
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .avg(Opportunity.Amount)
		 *     .toAggregateList();
		 * Decimal firstStageAverage = rows[0].getDecimal('avg_Amount');
		 * ```
		 */
		global Builder avg(SObjectField field)
		{
			aggregateType = QRY_Generator.Aggregate.AVG;
			aggregateField = UTIL_SObjectDescribe.getCachedFieldName(field);
			return this;
		}

		/**
		 * @description Applies a MIN aggregate function.
		 *
		 * @param field The field to aggregate
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .min(Opportunity.CloseDate)
		 *     .toAggregateList();
		 * Date firstStageEarliestCloseDate = rows[0].getDate('min_CloseDate');
		 * ```
		 */
		global Builder min(SObjectField field)
		{
			aggregateType = QRY_Generator.Aggregate.MIN;
			aggregateField = UTIL_SObjectDescribe.getCachedFieldName(field);
			return this;
		}

		/**
		 * @description Applies a MAX aggregate function.
		 *
		 * @param field The field to aggregate
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .max(Opportunity.Amount)
		 *     .toAggregateList();
		 * Decimal firstStageLargest = rows[0].getDecimal('max_Amount');
		 * ```
		 */
		global Builder max(SObjectField field)
		{
			aggregateType = QRY_Generator.Aggregate.MAX;
			aggregateField = UTIL_SObjectDescribe.getCachedFieldName(field);
			return this;
		}

		/**
		 * @description Applies a COUNT aggregate function. Text that comes from a page or a user must first be matched to a
		 * field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name (or null for COUNT())
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a field name or a path through parent records, such as Account.Owner.Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .groupBy(Account.Industry)
		 *     .count('Id')
		 *     .toAggregateList();
		 * Integer firstIndustryCount = rows[0].getInteger('count_Id');
		 * ```
		 */
		global Builder count(String fieldName)
		{
			QRY_Generator.validateFieldPath(fieldName, 'count');
			aggregateType = QRY_Generator.Aggregate.COUNT;
			aggregateField = fieldName;
			return this;
		}

		/**
		 * @description Applies a COUNT_DISTINCT aggregate function.
		 *
		 * @param field The field to count distinct values
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .groupBy(Contact.AccountId)
		 *     .countDistinct(Contact.Email)
		 *     .toAggregateList();
		 * Integer firstAccountEmailCount = rows[0].getInteger('count_distinct_Email');
		 * ```
		 
		 */
		global Builder countDistinct(SObjectField field)
		{
			aggregateType = QRY_Generator.Aggregate.COUNT_DISTINCT;
			aggregateField = UTIL_SObjectDescribe.getCachedFieldName(field);
			return this;
		}

		/**
		 * @description Applies a COUNT_DISTINCT aggregate function. Text that comes from a page or a user must first be
		 * matched to a field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a field name or a path through parent records, such as Account.Owner.Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .groupBy(Contact.AccountId)
		 *     .countDistinct('Email')
		 *     .toAggregateList();
		 * Integer firstAccountEmailCount = rows[0].getInteger('count_distinct_Email');
		 * ```
		 */
		global Builder countDistinct(String fieldName)
		{
			QRY_Generator.validateFieldPath(fieldName, 'countDistinct');
			aggregateType = QRY_Generator.Aggregate.COUNT_DISTINCT;
			aggregateField = fieldName;
			return this;
		}

		/**
		 * @description Applies a COUNT aggregate under an explicit result alias. Aliased aggregates add up: unlike
		 * the overloads without an alias, each call adds one more selection. So one query can combine several
		 * aggregates and read each back by its alias on the AggregateRow.
		 *
		 * @param field The field to count
		 * @param alias The result alias; must be a bare identifier, unique across the aliased selections
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if alias is not a bare identifier (a letter followed by
		 * letters, digits or underscores); or, when the query builds, if the alias duplicates an
		 * earlier aliased selection
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .count(Opportunity.Id, 'rowTotal')
		 *     .min(Opportunity.CreatedDate, 'firstSeen')
		 *     .toAggregateList();
		 * ```
		 */
		global virtual Builder count(SObjectField field, String alias)
		{
			return addAggregateSelection(QRY_Generator.Aggregate.COUNT, field, alias);
		}

		/**
		 * @description Applies a COUNT_DISTINCT aggregate under an explicit result alias. Aliased
		 * aggregates add up, so one query can combine several aggregates and read each back by its alias.
		 *
		 * @param field The field to count distinct values of
		 * @param alias The result alias; must be a bare identifier, unique across the aliased selections
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if alias is not a bare identifier (a letter followed by
		 * letters, digits or underscores); or, when the query builds, if the alias duplicates an
		 * earlier aliased selection
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * .countDistinct(Contact.Email, 'uniqueEmails')
		 * ```
		 */
		global virtual Builder countDistinct(SObjectField field, String alias)
		{
			return addAggregateSelection(QRY_Generator.Aggregate.COUNT_DISTINCT, field, alias);
		}

		/**
		 * @description Applies a SUM aggregate under an explicit result alias. Aliased aggregates
		 * add up, so one query can combine several aggregates and read each back by its alias.
		 *
		 * @param field The field to sum
		 * @param alias The result alias; must be a bare identifier, unique across the aliased selections
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if alias is not a bare identifier (a letter followed by
		 * letters, digits or underscores); or, when the query builds, if the alias duplicates an
		 * earlier aliased selection
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * .sum(Opportunity.Amount, 'pipelineTotal')
		 * ```
		 */
		global virtual Builder sum(SObjectField field, String alias)
		{
			return addAggregateSelection(QRY_Generator.Aggregate.SUM, field, alias);
		}

		/**
		 * @description Applies an AVG aggregate under an explicit result alias. Aliased aggregates
		 * add up, so one query can combine several aggregates and read each back by its alias.
		 *
		 * @param field The field to average
		 * @param alias The result alias; must be a bare identifier, unique across the aliased selections
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if alias is not a bare identifier (a letter followed by
		 * letters, digits or underscores); or, when the query builds, if the alias duplicates an
		 * earlier aliased selection
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * .avg(Opportunity.Amount, 'meanAmount')
		 * ```
		 */
		global virtual Builder avg(SObjectField field, String alias)
		{
			return addAggregateSelection(QRY_Generator.Aggregate.AVG, field, alias);
		}

		/**
		 * @description Applies a MIN aggregate under an explicit result alias. Aliased aggregates
		 * add up, so one query can combine several aggregates and read each back by its alias.
		 *
		 * @param field The field to take the minimum of
		 * @param alias The result alias; must be a bare identifier, unique across the aliased selections
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if alias is not a bare identifier (a letter followed by
		 * letters, digits or underscores); or, when the query builds, if the alias duplicates an
		 * earlier aliased selection
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * .min(Opportunity.CreatedDate, 'firstSeen')
		 * ```
		 */
		global virtual Builder min(SObjectField field, String alias)
		{
			return addAggregateSelection(QRY_Generator.Aggregate.MIN, field, alias);
		}

		/**
		 * @description Applies a MAX aggregate under an explicit result alias. Aliased aggregates
		 * add up, so one query can combine several aggregates and read each back by its alias.
		 *
		 * @param field The field to take the maximum of
		 * @param alias The result alias; must be a bare identifier, unique across the aliased selections
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if alias is not a bare identifier (a letter followed by
		 * letters, digits or underscores); or, when the query builds, if the alias duplicates an
		 * earlier aliased selection
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * .max(Opportunity.CreatedDate, 'lastSeen')
		 * ```
		 */
		global virtual Builder max(SObjectField field, String alias)
		{
			return addAggregateSelection(QRY_Generator.Aggregate.MAX, field, alias);
		}

		/**
		 * @description Records one aliased aggregate selection, validating the alias immediately so a bad
		 * alias fails at the call site rather than at query build time. A duplicate alias across the
		 * selections is rejected when the query builds. An alias that clashes with the older automatic alias (e.g.
		 * count_Id), or with a GROUP BY field name, shows up as a QueryException when the query runs.
		 *
		 * @param aggregate The aggregate function to apply.
		 * @param field The field token to aggregate.
		 * @param alias The result alias; must be a bare identifier, unique across the aliased selections.
		 *
		 * @return Builder for chaining.
		 *
		 * @date July 2026
		 *
		 * @example
		 * ```apex
		 * return addAggregateSelection(QRY_Generator.Aggregate.COUNT, field, alias);
		 * ```
		 */
		private Builder addAggregateSelection(QRY_Generator.Aggregate aggregate, SObjectField field, String alias)
		{
			aggregateSelections.add(new AggregateSelection(aggregate, UTIL_SObjectDescribe.getCachedFieldName(field), QRY_Generator.validateSelectAlias(alias)));
			return this;
		}

		/**
		 * @description Starts a HAVING condition on the SUM of a field.
		 *
		 * @param field The field to aggregate
		 *
		 * @return ConditionBuilder configured for HAVING
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.AccountId)
		 *     .sum(Opportunity.Amount)
		 *     .havingSumOf(Opportunity.Amount).greaterThan(100000)
		 *     .toAggregateList();
		 * Decimal firstAccountTotal = rows[0].getDecimal('sum_Amount');
		 * ```
		 */
		global ConditionBuilder havingSumOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.SUM, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true, 'havingSumOf');
		}

		/**
		 * @description Starts a HAVING condition on the AVG of a field.
		 *
		 * @param field The field to aggregate
		 *
		 * @return ConditionBuilder configured for HAVING
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.AccountId)
		 *     .avg(Opportunity.Amount)
		 *     .havingAvgOf(Opportunity.Amount).greaterThan(50000)
		 *     .toAggregateList();
		 * Decimal firstAccountAverage = rows[0].getDecimal('avg_Amount');
		 * ```
		 */
		global ConditionBuilder havingAvgOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.AVG, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true, 'havingAvgOf');
		}

		/**
		 * @description Starts a HAVING condition on the MIN of a field.
		 *
		 * @param field The field to aggregate
		 *
		 * @return ConditionBuilder configured for HAVING
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.AccountId)
		 *     .min(Opportunity.Amount)
		 *     .havingMinOf(Opportunity.Amount).greaterThan(1000)
		 *     .toAggregateList();
		 * Decimal firstAccountSmallest = rows[0].getDecimal('min_Amount');
		 * ```
		 */
		global ConditionBuilder havingMinOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.MIN, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true, 'havingMinOf');
		}

		/**
		 * @description Starts a HAVING condition on the MAX of a field.
		 *
		 * @param field The field to aggregate
		 *
		 * @return ConditionBuilder configured for HAVING
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.AccountId)
		 *     .max(Opportunity.Amount)
		 *     .havingMaxOf(Opportunity.Amount).lessThan(1000000)
		 *     .toAggregateList();
		 * Decimal firstAccountLargest = rows[0].getDecimal('max_Amount');
		 * ```
		 */
		global ConditionBuilder havingMaxOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.MAX, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true, 'havingMaxOf');
		}

		/**
		 * @description Starts a HAVING condition on the COUNT of a field.
		 *
		 * @param field The field to count
		 *
		 * @return ConditionBuilder configured for HAVING
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .groupBy(Contact.AccountId)
		 *     .count('Id')
		 *     .havingCountOf(Contact.Id).greaterThan(10)
		 *     .toAggregateList();
		 * Integer firstAccountContactCount = rows[0].getInteger('count_Id');
		 * ```
		 */
		global ConditionBuilder havingCountOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.COUNT, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true, 'havingCountOf');
		}

		/**
		 * @description Starts a HAVING condition on the global COUNT().
		 *
		 * @return ConditionBuilder configured for HAVING
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .groupBy(Contact.AccountId)
		 *     .count('Id')
		 *     .havingCount().greaterThan(5)
		 *     .toAggregateList();
		 * Integer firstAccountContactCount = rows[0].getInteger('count_Id');
		 * ```
		 */
		global ConditionBuilder havingCount()
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.COUNT, 'Id');
			return new ConditionBuilder(this, aggField, true, 'havingCount');
		}

		/**
		 * @description Starts a WHERE condition on a field using an SObjectField token.
		 *
		 * @param objectField Field token
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).equals('Technology')
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder condition(SObjectField objectField)
		{
			return new ConditionBuilder(this, UTIL_SObjectDescribe.getCachedFieldName(objectField), false, 'condition');
		}

		/**
		 * @description Starts a WHERE condition on a field using its API name. The text may also be a date or distance
		 * function from QRY_Function, or toLabel around a field name. Text that comes from a page or a user must first be
		 * matched to a field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a field name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition('Industry').equals('Technology')
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder condition(String fieldName)
		{
			return new ConditionBuilder(this, fieldName, false, 'condition');
		}

		/**
		 * @description Starts an AND condition on a field using an SObjectField token.
		 *
		 * @param field Field token
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).equals('Technology')
		 *     .andCondition(Account.Type).equals('Customer')
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder andCondition(SObjectField field)
		{
			nextIsOr = false;
			return andCondition(UTIL_SObjectDescribe.getCachedFieldName(field));
		}

		/**
		 * @description Starts an AND condition on a field using its API name. The text may also be a date or distance
		 * function from QRY_Function, or toLabel around a field name. Text that comes from a page or a user must first be
		 * matched to a field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a field name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition('Industry').equals('Technology')
		 *     .andCondition('Type').equals('Customer')
		 *     .toList();
		 * ```
		 
		 */
		global ConditionBuilder andCondition(String fieldName)
		{
			nextIsOr = false;
			return new ConditionBuilder(this, fieldName, false, 'andCondition');
		}

		/**
		 * @description Starts an OR condition on a field using an SObjectField token.
		 *
		 * @param field Field token
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).equals('Technology')
		 *     .orCondition(Account.Industry).equals('Finance')
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder orCondition(SObjectField field)
		{
			nextIsOr = true;
			return orCondition(UTIL_SObjectDescribe.getCachedFieldName(field));
		}

		/**
		 * @description Starts an OR condition on a field using its API name. The text may also be a date or distance
		 * function from QRY_Function, or toLabel around a field name. Text that comes from a page or a user must first be
		 * matched to a field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a field name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition('Industry').equals('Technology')
		 *     .orCondition('Industry').equals('Finance')
		 *     .toList();
		 * ```
		 
		 */
		global ConditionBuilder orCondition(String fieldName)
		{
			nextIsOr = true;
			return new ConditionBuilder(this, fieldName, false, 'orCondition');
		}

		/**
		 * @description Starts a WHERE condition whose left-hand side is a SOQL function expression
		 * (for example a geolocation DISTANCE from `QRY_Function.distanceInMiles`), so you can filter on
		 * the function result: `.lessThan(10)` renders `DISTANCE(...) < 10`. Mirrors `condition(SObjectField)`
		 * but seats the rendered function expression on the comparison left-hand side.
		 *
		 * @param functionField The function expression, from a QRY_Function factory
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).lessThan(10)
		 *     .toList();
		 * ```
		 */
		global virtual ConditionBuilder condition(QRY_Function functionField)
		{
			return new ConditionBuilder(this, functionField.toExpression(), false, 'condition');
		}

		/**
		 * @description Starts an AND condition whose left-hand side is a SOQL function expression
		 * (for example a geolocation DISTANCE from `QRY_Function.distanceInMiles`). Mirrors
		 * `andCondition(SObjectField)` for function expressions.
		 *
		 * @param functionField The function expression, from a QRY_Function factory
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).equals('Technology')
		 *     .andCondition(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).lessThan(10)
		 *     .toList();
		 * ```
		 */
		global virtual ConditionBuilder andCondition(QRY_Function functionField)
		{
			nextIsOr = false;
			return andCondition(functionField.toExpression());
		}

		/**
		 * @description Starts an OR condition whose left-hand side is a SOQL function expression
		 * (for example a geolocation DISTANCE from `QRY_Function.distanceInMiles`). Mirrors
		 * `orCondition(SObjectField)` for function expressions.
		 *
		 * @param functionField The function expression, from a QRY_Function factory
		 *
		 * @return ConditionBuilder for specifying the operator
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).lessThan(10)
		 *     .orCondition(QRY_Function.distanceInMiles(Account.ShippingAddress, 37.775, -122.418)).lessThan(10)
		 *     .toList();
		 * ```
		 */
		global virtual ConditionBuilder orCondition(QRY_Function functionField)
		{
			nextIsOr = true;
			return orCondition(functionField.toExpression());
		}

		/**
		 * @description Adds a pre-built condition to the query.
		 * Use this for complex condition groups that cannot be expressed with the fluent API.
		 *
		 * @param condition The condition to add (created via QRY_Condition classes)
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.OrCondition statusGroup = new QRY_Condition.OrCondition();
		 * statusGroup.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
		 * statusGroup.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Pending'));
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).equals('Technology')
		 *     .addCondition(statusGroup)
		 *     .toList();
		 * ```
		 */
		global Builder addCondition(QRY_Condition.Evaluable condition)
		{
			if(condition != null)
			{
				conditions.add(new ConditionEntry(condition, nextIsOr));
			}
			nextIsOr = false;
			return this;
		}

		/**
		 * @description Adds an ORDER BY clause (default ascending).
		 *
		 * @param field Field token to sort by
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy(Account.Name).ascending()
		 *     .toList();
		 * ```
		 
		 */
		global Builder orderBy(SObjectField field)
		{
			orderByFields.add(new QRY_Generator.OrderBy(field));
			return this;
		}

		/**
		 * @description Adds an ORDER BY clause (default ascending). The text is written as given. It may be one sort item or
		 * several joined by commas. A sort item is a field name or a date or distance function from QRY_Function, then ASC or
		 * DESC if wanted, then NULLS FIRST or NULLS LAST if wanted, such as Name DESC NULLS LAST, CreatedDate. Text that comes
		 * from a page or a user must first be matched to a field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name, or a list of sort items
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a list of sort items
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy('CreatedDate').descending()
		 *     .toList();
		 * ```
		 
		 */
		global Builder orderBy(String fieldName)
		{
			QRY_Generator.validateSortList(fieldName, 'orderBy');
			orderByFields.add(new QRY_Generator.OrderBy(fieldName));
			return this;
		}

		/**
		 * @description Adds an ORDER BY clause with a dynamic sort direction. Nulls placement
		 * defaults to standard SOQL behavior (NULLS FIRST for ASC, NULLS LAST for DESC).
		 *
		 * @param field Field token to sort by
		 * @param sortDescending When true, sorts DESCENDING; otherwise ASCENDING
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean isDescending = true;
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy(Account.Name, isDescending)
		 *     .toList();
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		global Builder orderBy(SObjectField field, Boolean sortDescending)
		{
			return orderBy(field, sortDescending, sortDescending == true);
		}

		/**
		 * @description Adds an ORDER BY clause with a dynamic sort direction and nulls placement.
		 *
		 * @param field Field token to sort by
		 * @param sortDescending When true, sorts DESCENDING; otherwise ASCENDING
		 * @param nullsLast When true, places nulls last; otherwise places nulls first
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean isDescending = true;
		 * Boolean isNullsLast = true;
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy(Account.Name, isDescending, isNullsLast)
		 *     .toList();
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		global Builder orderBy(SObjectField field, Boolean sortDescending, Boolean nullsLast)
		{
			orderBy(field);
			return applyOrderByDirection(sortDescending, nullsLast);
		}

		/**
		 * @description Adds an ORDER BY clause with a dynamic sort direction. Nulls placement
		 * defaults to standard SOQL behavior (NULLS FIRST for ASC, NULLS LAST for DESC). The text may be a list of sort
		 * items joined by commas, as for orderBy(String), but its last item must have no direction and no nulls order,
		 * because this method adds them. Text that comes from a page or a user must first be matched to a field through a
		 * list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name
		 * @param sortDescending When true, sorts DESCENDING; otherwise ASCENDING
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not such a list
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean isDescending = false;
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy('CreatedDate', isDescending)
		 *     .toList();
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		global Builder orderBy(String fieldName, Boolean sortDescending)
		{
			return orderBy(fieldName, sortDescending, sortDescending == true);
		}

		/**
		 * @description Adds an ORDER BY clause with a dynamic sort direction and nulls placement. The text may be a list of
		 * sort items joined by commas, as for orderBy(String), but its last item must have no direction and no nulls order,
		 * because this method adds them. Text that comes from a page or a user must first be matched to a field through a
		 * list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name
		 * @param sortDescending When true, sorts DESCENDING; otherwise ASCENDING
		 * @param nullsLast When true, places nulls last; otherwise places nulls first
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not such a list
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean isDescending = true;
		 * Boolean isNullsLast = false;
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy('CreatedDate', isDescending, isNullsLast)
		 *     .toList();
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		global Builder orderBy(String fieldName, Boolean sortDescending, Boolean nullsLast)
		{
			QRY_Generator.validateSortListBeforeDirection(fieldName, 'orderBy');
			orderBy(fieldName);
			return applyOrderByDirection(sortDescending, nullsLast);
		}

		/**
		 * @description Orders by a SOQL date-function expression, ascending (e.g. ORDER BY CALENDAR_MONTH(CloseDate)).
		 *
		 * @param functionField The date-function expression, from a QRY_Function factory
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.1
		 *
		 * @example
		 * ```apex
		 * .orderBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
		 * ```
		 */
		global virtual Builder orderBy(QRY_Function functionField)
		{
			return orderBy(functionField.toExpression());
		}

		/**
		 * @description Orders by a SOQL date-function expression, ascending or descending.
		 *
		 * @param functionField The date-function expression, from a QRY_Function factory
		 * @param sortDescending When true, sorts DESCENDING; otherwise ASCENDING
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.1
		 *
		 * @example
		 * ```apex
		 * .orderBy(QRY_Function.calendarMonth(Opportunity.CloseDate), true)
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		global virtual Builder orderBy(QRY_Function functionField, Boolean sortDescending)
		{
			return orderBy(functionField.toExpression(), sortDescending);
		}

		/**
		 * @description Orders an aggregate query by COUNT of a field (e.g. ORDER BY COUNT(Id) DESC), the
		 * SOQL form for ranking grouped rows by how many records each group holds. To read only the top groups,
		 * combine this with withLimit. No NULLS clause is added, because COUNT never returns null.
		 *
		 * @param field The field whose COUNT orders the grouped rows
		 * @param sortDescending When true, sorts DESCENDING (largest groups first); otherwise ASCENDING
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if field is null
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> topSources = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .count(Opportunity.Id, 'rowTotal')
		 *     .orderByCount(Opportunity.Id, true)
		 *     .withLimit(3)
		 *     .toAggregateList();
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		global virtual Builder orderByCount(SObjectField field, Boolean sortDescending)
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(field);
			if(String.isBlank(fieldName))
			{
				throw new IllegalArgumentException('Aggregate ordering requires a field');
			}
			QRY_Generator.OrderBy aggregateOrder =
					new QRY_Generator.OrderBy(QRY_Generator.formatAggregate(QRY_Generator.Aggregate.COUNT, fieldName));
			orderByFields.add(sortDescending == true ? aggregateOrder.descending() : aggregateOrder.ascending());
			return this;
		}

		/**
		 * @description Applies sort direction and nulls placement to the last ORDER BY clause.
		 *
		 * @param sortDescending When true, sorts DESCENDING; otherwise ASCENDING
		 * @param nullsLast When true, places nulls last; otherwise places nulls first
		 *
		 * @return Builder for chaining
		 */
		private Builder applyOrderByDirection(Boolean sortDescending, Boolean nullsLast)
		{
			if(sortDescending == true)
			{
				descending();
			}
			else
			{
				ascending();
			}

			if(nullsLast == true)
			{
				nullsLast();
			}
			else
			{
				nullsFirst();
			}

			return this;
		}

		/**
		 * @description Sets the last ORDER BY clause to ASCENDING.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy(Account.Name).ascending()
		 *     .toList();
		 * ```
		 */
		global Builder ascending()
		{
			if(!orderByFields.isEmpty())
			{
				orderByFields[orderByFields.size() - 1].ascending();
			}
			return this;
		}

		/**
		 * @description Sets the last ORDER BY clause to DESCENDING.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy(Account.CreatedDate).descending()
		 *     .toList();
		 * ```
		 */
		global Builder descending()
		{
			if(!orderByFields.isEmpty())
			{
				orderByFields[orderByFields.size() - 1].descending();
			}
			return this;
		}

		/**
		 * @description Sets the last ORDER BY clause to NULLS FIRST.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy(Account.Industry).ascending().nullsFirst()
		 *     .toList();
		 * ```
		 */
		global Builder nullsFirst()
		{
			if(!orderByFields.isEmpty())
			{
				orderByFields[orderByFields.size() - 1].nullsFirst();
			}
			return this;
		}

		/**
		 * @description Sets the last ORDER BY clause to NULLS LAST.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy(Account.Industry).ascending().nullsLast()
		 *     .toList();
		 * ```
		 */
		global Builder nullsLast()
		{
			if(!orderByFields.isEmpty())
			{
				orderByFields[orderByFields.size() - 1].nullsLast();
			}
			return this;
		}

		/**
		 * @description Sets the maximum number of records to return (LIMIT).
		 *
		 * @param recordLimit Maximum number of records
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .withLimit(100)
		 *     .toList();
		 * ```
		 */
		global Builder withLimit(Integer recordLimit)
		{
			maxRecords = recordLimit;
			return this;
		}

		/**
		 * @description Sets the record offset (OFFSET).
		 *
		 * @param rowNumber Number of records to skip
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .withLimit(25)
		 *     .withOffset(50)
		 *     .toList();
		 * ```
		 */
		global Builder withOffset(Integer rowNumber)
		{
			offsetCount = rowNumber;
			return this;
		}

		/**
		 * @description Turns off every security check the builder controls, in one call. The query runs in
		 * SYSTEM_MODE, so object and field permissions are not checked. The stripInaccessible() choice is cleared. And
		 * record sharing is ignored through the `without sharing` proxy, exactly as `withSystemMode()` followed by
		 * `bypassSharing()` would do. Both bypasses are recorded in the bypass audit. To skip object and field
		 * permissions but keep the record sharing of the calling class, use `withSystemMode()` instead. This method
		 * ignores the `UserModeQueries_Enabled` flag.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .withoutSecurity()
		 *     .toList();
		 * ```
		 */
		global Builder withoutSecurity()
		{
			userModeEnabled = false;
			stripInaccessibleEnabled = false;
			sharingEnforced = false;
			isAuditedSharingBypass = false;
			auditQueue.queueSecurityMode();
			auditQueue.queueSharing();
			return this;
		}

		/**
		 * @description Runs the query in USER_MODE. With bypassSharing(), the read runs without record sharing but still
		 * checks object and field permissions.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .withUserMode()
		 *     .toList();
		 * ```
		 */
		global Builder withUserMode()
		{
			userModeEnabled = true;
			return this;
		}

		/**
		 * @description Runs the query in SYSTEM_MODE, whatever the `UserModeQueries_Enabled` feature flag says.
		 * Use it for a query that must read custom metadata, system tables, or objects the running user is not
		 * meant to have object or field access (CRUD/FLS) to. Each call is recorded in the bypass audit when the
		 * query runs.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TriggerSetting__mdt setting = (TriggerSetting__mdt)QRY_Builder.selectFrom(TriggerSetting__mdt.SObjectType)
		 *     .withSystemMode()
		 *     .condition(TriggerSetting__mdt.SObjectType__c).equals('Account')
		 *     .getFirst();
		 * ```
		 */
		global Builder withSystemMode()
		{
			systemModeInternal();
			auditQueue.queueSystemMode();
			return this;
		}

		/**
		 * @description The framework's own version of `withSystemMode()`. It turns USER_MODE off but adds no
		 * `BypassEvent` entry to the bypass audit. Framework selectors use it (`SEL_Base.query` when
		 * `systemModeRequired() == true`), and so do the framework's own lookups of custom metadata or custom settings
		 * (e.g., `UTIL_FeatureFlag.getCustomMetadataOrSettingValue`), because the framework is reading its own
		 * configuration. No subscriber is skipping a check in these reads, so they must not fill the `BypassEvent`
		 * audit trail. It is public, not global, so subscribers cannot call it. Application code that really needs to
		 * leave USER_MODE must call `withSystemMode()`, so the choice is audited.
		 *
		 * @return Builder for chaining
		 *
		 * @example
		 * ```apex
		 * SObject foundRecord = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(objectName))
		 *     .systemModeInternal()
		 *     .fields(new List<String> {fieldToReturn})
		 *     .condition('DeveloperName').equals(uniqueRecordName)
		 *     .getFirst();
		 * ```
		 */
		public Builder systemModeInternal()
		{
			userModeEnabled = false;
			return this;
		}

		/**
		 * @description Strips inaccessible fields from results.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .stripInaccessible()
		 *     .toList();
		 * ```
		 */
		global Builder stripInaccessible()
		{
			stripInaccessibleEnabled = true;
			return this;
		}

		/**
		 * @description Enforces sharing rules using a `with sharing` proxy class.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .withSharing()
		 *     .toList();
		 * ```
		 */
		global Builder withSharing()
		{
			sharingEnforced = true;
			isAuditedSharingBypass = false;
			return this;
		}

		/**
		 * @description Reads records whatever the record sharing, through a `without sharing` proxy class. The call is
		 * recorded in the bypass audit when the query runs.
		 *
		 * Under user mode (the `UserModeQueries_Enabled` flag on, or withUserMode()) the running user's object and field
		 * permissions still apply:
		 * - a user who cannot read the object is refused with a QueryException;
		 * - fields the user cannot read are removed from the rows, in parent fields and child rows too, and are not
		 *   reported;
		 * - a filter or a sort on a field of the queried object that the user cannot read is refused;
		 * - a query inside isIn() or notIn(), and a child query added with subselect(), are checked the same way, each on
		 *   its own object: the user must be able to read that object and the fields it filters or sorts on;
		 * - toQueryLocator(), toCursor() and every total or group read (toAggregateList(), getFirstAggregate(), or a
		 *   grouped query read as records) are refused, because their rows cannot be cleaned;
		 * - getPage() returns a page with a null cursor, for the same reason.
		 *
		 * A filter in your own Evaluable, on a path through a parent such as `Parent__r.Email__c`, or inside a function
		 * is not checked. Its rows can tell the user something about that field, so do not filter or sort on a field the
		 * user cannot read that way.
		 *
		 * To read a locator, a cursor or totals without sharing, add withSystemMode(). withSystemMode() also turns off
		 * the object and field permission checks for the read. With the `UserModeQueries_Enabled` flag off, a read runs
		 * in system mode, so nothing is checked, as for any read.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Reads every open case, whoever owns it. Fields the user cannot read are removed from the rows.
		 * List<Case> openCases = QRY_Builder.selectFrom(Case.SObjectType)
		 *     .condition(Case.IsClosed).equals(false)
		 *     .bypassSharing()
		 *     .toList();
		 * ```
		 * ```apex
		 * // A batch job's locator needs withSystemMode() too, which also turns off the field checks.
		 * Database.QueryLocator locator = QRY_Builder.selectFrom(Case.SObjectType)
		 *     .withSystemMode()
		 *     .bypassSharing()
		 *     .toQueryLocator();
		 * ```
		 */
		global Builder bypassSharing()
		{
			bypassSharingInternal();
			isAuditedSharingBypass = true;
			auditQueue.queueSharing();
			return this;
		}

		/**
		 * @description The framework's own version of `bypassSharing()`. It ignores record sharing but adds no
		 * `BypassEvent` entry to the bypass audit. Framework reads that must always see every record in the org use
		 * it, for example the health check's look at who may abort jobs, which reads setup entities, or the check that
		 * a community nickname is unique. No subscriber is skipping a check in these reads, so they must not fill the
		 * `BypassEvent` audit trail. It is public, not global, so subscribers cannot call it. Application code that
		 * really needs to ignore sharing must call `bypassSharing()`, so the choice is audited.
		 *
		 * @return Builder for chaining
		 *
		 * @example
		 * ```apex
		 * List<SetupEntityAccess> grants = QRY_Builder.selectFrom(SetupEntityAccess.SObjectType)
		 *     .bypassSharingInternal()
		 *     .toList();
		 * ```
		 */
		public Builder bypassSharingInternal()
		{
			sharingEnforced = false;
			isAuditedSharingBypass = false;
			return this;
		}

		/**
		 * @description Enables caching for this query. A non-null time-to-live means
		 * withCache(UTIL_Cache.Scope.AUTO, ttlSeconds); a null one requests no caching. A user-mode read is kept
		 * in memory for this transaction. A system-mode read that leaves the sharing setting to the
		 * calling class is not cached, because the cache cannot tell one calling class's sharing from another's;
		 * to cache a system-mode read, state the setting with withSharing() or bypassSharing(). A read with
		 * bypassSharing() alone under user mode is cached as a system-mode read, and the fields each running user cannot
		 * read are removed from the rows when they are returned.
		 *
		 * @param ttlSeconds Time-to-live in seconds for Platform Cache; ignored in memory; null requests no caching
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).equals(accountId)
		 *     .withSystemMode()
		 *     .withSharing()
		 *     .withCache(300)
		 *     .getFirst();
		 * ```
		 */
		global Builder withCache(Integer ttlSeconds)
		{
			cacheTTL = ttlSeconds;
			cacheScope = ttlSeconds == null ? null : UTIL_Cache.Scope.AUTO;
			return this;
		}

		/**
		 * @description Caches this query's results in the given scope. AUTO is not a place: it asks for the most
		 * durable storage that is safe for this read when it runs, Platform Cache for a system-mode read where a
		 * partition keeps it, and memory for this transaction otherwise. A user-mode read is only ever kept in
		 * memory for this transaction. A system-mode read whose sharing is left to the calling class is not cached;
		 * state it with withSharing() or bypassSharing(). A read with bypassSharing() alone under user mode is cached
		 * as a system-mode read, and the fields each running user cannot read are removed from the rows when they are
		 * returned. The last caching call on a builder wins.
		 *
		 * @param scope Where results may be kept; null means no caching
		 * @param ttlSeconds Time-to-live in seconds for Platform Cache; ignored in memory; null uses the default
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.8
		 *
		 * @example
		 * ```apex
		 * List<Account> parents = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).isIn(parentIds)
		 *     .withCache(UTIL_Cache.Scope.IN_TRANSACTION, null)
		 *     .toList();
		 * ```
		 */
		global virtual Builder withCache(UTIL_Cache.Scope scope, Integer ttlSeconds)
		{
			cacheScope = scope;
			cacheTTL = scope == null ? null : ttlSeconds;
			return this;
		}

		/**
		 * @description Makes this query read from the database, whatever caching the selector or an earlier call
		 * asked for. The last caching call on a builder wins.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.8
		 *
		 * @example
		 * ```apex
		 * List<Account> fresh = new SEL_Account().query.withoutCache().condition(Account.Id).isIn(ids).toList();
		 * ```
		 */
		global virtual Builder withoutCache()
		{
			cacheScope = null;
			cacheTTL = null;
			return this;
		}

		/**
		 * @description Locks returned records FOR UPDATE.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).equals(accountId)
		 *     .forUpdate()
		 *     .toList();
		 * ```
		 */
		global Builder forUpdate()
		{
			lockForUpdate = true;
			lockForReference = false;
			lockForView = false;
			includeAllRows = false;
			return this;
		}

		/**
		 * @description Locks returned records FOR REFERENCE.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).equals(accountId)
		 *     .forReference()
		 *     .toList();
		 * ```
		 */
		global Builder forReference()
		{
			lockForUpdate = false;
			lockForReference = true;
			lockForView = false;
			return this;
		}

		/**
		 * @description Locks returned records FOR VIEW.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).equals(accountId)
		 *     .forView()
		 *     .toList();
		 * ```
		 */
		global Builder forView()
		{
			lockForUpdate = false;
			lockForReference = false;
			lockForView = true;
			return this;
		}

		/**
		 * @description Includes deleted and archived records (ALL ROWS).
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.IsDeleted).equals(true)
		 *     .allRows()
		 *     .toList();
		 * ```
		 */
		global Builder allRows()
		{
			includeAllRows = true;
			lockForUpdate = false;
			return this;
		}

		/**
		 * @description Filters records by visibility scope using USING SCOPE clause.
		 *
		 * @param scopeValue The scope to apply
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .usingScope(QRY_Builder.Scope.MINE)
		 *     .toList();
		 * ```
		 */
		global Builder usingScope(Scope scopeValue)
		{
			scope = scopeValue;
			return this;
		}

		/**
		 * @description Starts a WITH DATA CATEGORY filter for the specified data category group. Text that comes from a page or
		 * a user must first be matched to a group through a list of names you allow.
		 *
		 * @param groupName The data category group API name, such as Geography__c
		 *
		 * @return DataCategoryBuilder for operator selection
		 *
		 * @throws IllegalArgumentException if groupName is blank, or is not a single API name, such as Name
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
		 *     .fields(new List<String>{'Id', 'Title'})
		 *     .condition('PublishStatus').equals('Online')
		 *     .withDataCategory('Geography__c').at('USA__c')
		 *     .withDataCategory('Product__c').below('Electronics__c')
		 *     .toList();
		 * ```
		 */
		global DataCategoryBuilder withDataCategory(String groupName)
		{
			if(String.isBlank(groupName))
			{
				throw new IllegalArgumentException('Data category group name cannot be blank.');
			}
			QRY_Generator.validateFieldPath(groupName, 'withDataCategory');
			return new DataCategoryBuilder(this, groupName);
		}

		/**
		 * @description Stops this query from writing a performance log entry, even when it is slow. Use it for a query you
		 * expect to be slow, so it does not fill the logs. The last of suppressPerformanceLogging, forcePerformanceLogging and
		 * logPerformanceIfSlowerThan called on the builder is the one that applies.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .suppressPerformanceLogging()
		 *     .toList();
		 * ```
		 */
		global Builder suppressPerformanceLogging()
		{
			suppressPerformanceLog = true;
			forcePerformanceLog = false;
			return this;
		}

		/**
		 * @description Forces performance logging regardless of threshold for this query.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .forcePerformanceLogging()
		 *     .toList();
		 * ```
		 */
		global Builder forcePerformanceLogging()
		{
			forcePerformanceLog = true;
			suppressPerformanceLog = false;
			return this;
		}

		/**
		 * @description Sets a custom performance threshold for this query.
		 * The query will be logged only if duration exceeds this threshold.
		 *
		 * @param thresholdMs Custom threshold in milliseconds
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .logPerformanceIfSlowerThan(500)
		 *     .toList();
		 * ```
		 */
		global Builder logPerformanceIfSlowerThan(Integer thresholdMs)
		{
			performanceThresholdMs = thresholdMs;
			suppressPerformanceLog = false;
			forcePerformanceLog = false;
			return this;
		}

		/**
		 * @description Builds a QRY_Generator from the current Builder state.
		 *
		 * @return Configured QRY_Generator
		 */
		@TestVisible
		private QRY_Generator buildGenerator()
		{
			return buildGeneratorWithCondition(buildEffectiveCondition());
		}

		/**
		 * @description Builds a QRY_Generator from the current Builder state using a pre-built condition.
		 *
		 * @param effectiveCondition The pre-built WHERE condition
		 *
		 * @return Configured QRY_Generator
		 */
		private QRY_Generator buildGeneratorWithCondition(QRY_Condition.Evaluable effectiveCondition)
		{
			QRY_Generator generator = new QRY_Generator(objectType);

			if(selectAll)
			{
				generator.selectAllFields();
			}
			else
			{
				generator.addFields(getEffectiveFields());
			}

			if(effectiveCondition != null)
			{
				generator.whereCondition(effectiveCondition);
			}

			if(!groupByFields.isEmpty())
			{
				for(String field : groupByFields)
				{
					generator.groupBy(field);
				}
				if(rollupMode)
				{
					generator.rollup();
				}
				else if(cubeMode)
				{
					generator.cube();
				}

				if(!havingConditions.conditions.isEmpty())
				{
					generator.havingCondition(havingConditions);
				}
			}

			if(aggregateType != null)
			{
				switch on aggregateType
				{
					when COUNT
					{
						generator.selectCount(aggregateField);
					}
					when SUM
					{
						generator.selectSum(aggregateField);
					}
					when AVG
					{
						generator.selectAvg(aggregateField);
					}
					when MIN
					{
						generator.selectMin(aggregateField);
					}
					when MAX
					{
						generator.selectMax(aggregateField);
					}
					when COUNT_DISTINCT
					{
						generator.selectCountDistinct(aggregateField);
					}
				}
			}

			for(AggregateSelection selection : aggregateSelections)
			{
				generator.selectAggregate(selection.aggregateFunction, selection.fieldName, selection.alias);
			}

			for(QRY_Generator.OrderBy orderBy : orderByFields)
			{
				generator.orderBy(orderBy);
			}

			for(Builder childQuery : childQueries)
			{
				QRY_Generator childGen = childQuery.buildGenerator();
				childGen.fromObject(childQuery.childRelationshipName);
				generator.addSubquery(childGen);
			}

			if(maxRecords != null)
			{
				generator.limitTo(maxRecords);
			}
			if(offsetCount != null)
			{
				generator.offset(offsetCount);
			}
			if(scope != null)
			{
				generator.usingScope(QRY_Generator.Scope.valueOf(scope.name()));
			}
			if(lockForUpdate)
			{
				generator.forUpdate();
			}
			else if(lockForReference)
			{
				generator.forReference();
			}
			else if(lockForView)
			{
				generator.forView();
			}
			if(includeAllRows)
			{
				generator.allRows();
			}

			for(DataCategoryEntry entry : dataCategoryFilters.values())
			{
				generator.withDataCategory(new QRY_Generator.DataCategoryFilter(
						entry.groupName,
						entry.operator,
						entry.categoryNames
				));
			}

			return generator;
		}

		/**
		 * @description Builds query parameters for QRY_Engine execution.
		 *
		 * @param registry The bind registry with values
		 *
		 * @return Configured QueryParameters
		 */
		@TestVisible
		private QRY_Engine.QueryParameters buildParameters(QRY_BindRegistry registry)
		{
			auditQueue.recordOperation(String.valueOf(objectType), UTIL_BypassAudit.OPERATION_QUERY, null);
			auditQueue.flush();
			QRY_Condition.Evaluable effectiveCondition = buildEffectiveCondition();
			QRY_Generator generator = buildGeneratorWithCondition(effectiveCondition);
			QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
			parameters.objectType = objectType;
			parameters.queryString = useLiterals ? generator.toSoql() : generator.toSoql(registry);
			parameters.bindMap = useLiterals ? new Map<String, Object>() : registry.getMap();
			parameters.userMode = isUserModeRead();
			parameters.enforceSharing = sharingEnforced;
			parameters.limitCount = maxRecords;
			parameters.cacheTTL = cacheTTL;
			parameters.cacheScope = cacheScope;
			parameters.lockForUpdate = lockForUpdate;
			parameters.lockForReference = lockForReference;
			parameters.lockForView = lockForView;
			parameters.includeAllRows = includeAllRows;
			parameters.suppressPerformanceLogging = suppressPerformanceLog;
			parameters.forcePerformanceLogging = forcePerformanceLog;
			parameters.customPerformanceThresholdMs = performanceThresholdMs;
			parameters.whereCondition = effectiveCondition;
			parameters.orderByFields = orderByFields;
			parameters.aggregateQuery = isAggregateQuery();
			return parameters;
		}

		/**
		 * @description Checks whether this query is an aggregate query: one with aggregate functions or a GROUP BY.
		 *
		 * @return True when the query has an aggregate function or a GROUP BY.
		 */
		private Boolean isAggregateQuery()
		{
			return aggregateType != null || !aggregateSelections.isEmpty() || !groupByFields.isEmpty();
		}

		/**
		 * @description Checks whether this read ignores record sharing but keeps the user's object and field checks. That
		 * is the case when the last sharing call was the audited bypassSharing() and the read would otherwise run in
		 * USER_MODE, because of the `UserModeQueries_Enabled` flag or withUserMode(). Such a read runs in SYSTEM_MODE
		 * without sharing. Before it runs, the builder checks object read and the field names it holds, and afterwards it
		 * removes the fields the user cannot read from the rows. After withSystemMode(), or with the flag off, the read
		 * already skips those checks, so nothing changes.
		 *
		 * @return True when the read ignores record sharing and keeps the user's object and field checks.
		 */
		private Boolean shouldKeepChecksWithoutSharing()
		{
			return isAuditedSharingBypass && sharingEnforced == false && userModeEnabled;
		}

		/**
		 * @description Checks whether the query runs in USER_MODE. It is the caller's own choice, except for a read that
		 * ignores record sharing and keeps the checks in this class: that read runs in SYSTEM_MODE.
		 *
		 * @return True when the query runs in USER_MODE.
		 */
		private Boolean isUserModeRead()
		{
			return userModeEnabled && !shouldKeepChecksWithoutSharing();
		}

		/**
		 * @description Refuses a read that ignores record sharing with bypassSharing() alone when it would show the
		 * running user something user mode hides. It does nothing for any other read. The checks run in this order, before
		 * any query and before any audit entry:
		 * - the user cannot read the object;
		 * - the read is toQueryLocator(), toCursor() or an aggregate query, whose rows the builder cannot clean;
		 * - a filter or a sort uses a field of the queried object that the user cannot read;
		 * - an inner query of the read, which is a query inside isIn() or notIn() or a child query added with
		 * subselect(), reads an object the user cannot read, or filters or sorts on a field of its own object that the
		 * user cannot read. A query inside isIn() or notIn() is also refused when it selects a field the user cannot
		 * read, because the values of that field decide which rows come back. The inner queries of an inner query are
		 * checked the same way.
		 *
		 * Only filters built from field names are checked, inside groups and NOT conditions too. A filter in another
		 * kind of condition, such as your own Evaluable, is not checked.
		 *
		 * @param methodName The name of the method the caller called, shown in the message.
		 *
		 * @throws QueryException When the running user cannot read the object, or the object of an inner query.
		 * @throws UTIL_Exceptions.IllegalStateException When the read is a locator, a cursor or an aggregate query, or when
		 * a filter or sort uses a field the running user cannot read.
		 */
		private void refuseReadThatCannotKeepChecks(String methodName)
		{
			if(!shouldKeepChecksWithoutSharing())
			{
				return;
			}

			refuseObjectTheUserCannotRead(objectType);

			if(methodName == METHOD_TO_QUERY_LOCATOR || methodName == METHOD_TO_CURSOR || isAggregateQuery())
			{
				throw new UTIL_Exceptions.IllegalStateException(String.format(System.Label.QueryBuilder_BypassSharingRead_NeedsSystemMode,
						new List<String> {methodName}));
			}

			refuseFilterOrSortTheUserCannotRead();
		}

		/**
		 * @description Refuses the read when the running user cannot read the object. It asks the platform each time,
		 * so the answer is right inside System.runAs too.
		 *
		 * @param queriedType The object a query or an inner query reads.
		 *
		 * @throws QueryException When the running user cannot read the object.
		 */
		private void refuseObjectTheUserCannotRead(SObjectType queriedType)
		{
			if(!UTIL_SObjectDescribe.isObjectAccessible(queriedType))
			{
				throw new QueryException(String.format(System.Label.QueryBuilder_BypassSharingObject_NotReadable,
						new List<String> {UTIL_SObjectDescribe.getObjectNameFromType(queriedType)}));
			}
		}

		/**
		 * @description Refuses the read when this query, or one of its inner queries, filters or sorts on a field the
		 * running user cannot read. Each query is checked against its own object. The inner queries are the queries
		 * inside isIn() and notIn() conditions, and the child queries added with subselect(); the object of each one
		 * must be readable too.
		 *
		 * @throws QueryException When the running user cannot read the object of an inner query.
		 * @throws UTIL_Exceptions.IllegalStateException When a filter or sort uses a field the running user cannot read.
		 */
		private void refuseFilterOrSortTheUserCannotRead()
		{
			Set<String> fieldNames = new Set<String>();
			List<QRY_Generator> innerQueries = new List<QRY_Generator>();
			collectConditionFieldNames(buildEffectiveCondition(), fieldNames, innerQueries);
			for(QRY_Generator.OrderBy orderBy : orderByFields)
			{
				fieldNames.add(orderBy.getField());
			}
			refuseFieldTheUserCannotRead(objectType, fieldNames);
			refuseInnerQueryTheUserCannotRead(innerQueries);

			for(Builder childQuery : childQueries)
			{
				refuseObjectTheUserCannotRead(childQuery.objectType);
				childQuery.refuseFilterOrSortTheUserCannotRead();
			}
		}

		/**
		 * @description Refuses the read when a query inside an isIn() or notIn() condition reads an object the running user
		 * cannot read, or filters on or selects a field of that object the user cannot read. The selected field is checked
		 * because its values decide which outer rows come back. A query found inside one of these queries is added to the
		 * list and checked the same way.
		 *
		 * @param innerQueries The queries found inside isIn() and notIn() conditions. The list grows while it is read.
		 *
		 * @throws QueryException When the running user cannot read the object of one of the queries.
		 * @throws UTIL_Exceptions.IllegalStateException When one of the queries filters on or selects a field the running
		 * user cannot read.
		 */
		private void refuseInnerQueryTheUserCannotRead(List<QRY_Generator> innerQueries)
		{
			for(Integer index = 0; index < innerQueries.size(); index++)
			{
				QRY_Generator innerQuery = innerQueries[index];
				SObjectType innerType = UTIL_SObjectDescribe.getSObjectTypeByName(innerQuery.getObjectName());
				refuseObjectTheUserCannotRead(innerType);

				Set<String> fieldNames = innerQuery.getSelectedFieldNames();
				collectConditionFieldNames(innerQuery.getWhereCondition(), fieldNames, innerQueries);
				refuseFieldTheUserCannotRead(innerType, fieldNames);
			}
		}

		/**
		 * @description Adds the field names of a condition to a list. It reads the field name of a condition on one field
		 * or on a set of values, and looks inside groups of conditions and NOT conditions. It skips every other kind of
		 * condition. When a condition compares a field with the values of another query, as isIn() and notIn() can, that
		 * query is added to the list of inner queries.
		 *
		 * @param condition The condition to read; null adds nothing.
		 * @param fieldNames The set the field names are added to.
		 * @param innerQueries The list the queries inside isIn() and notIn() conditions are added to.
		 */
		private void collectConditionFieldNames(QRY_Condition.Evaluable condition, Set<String> fieldNames, List<QRY_Generator> innerQueries)
		{
			if(condition instanceof QRY_Condition.FieldCondition)
			{
				fieldNames.add(((QRY_Condition.FieldCondition)condition).field);
			}
			else if(condition instanceof QRY_Condition.SetCondition)
			{
				QRY_Condition.SetCondition setCondition = (QRY_Condition.SetCondition)condition;
				fieldNames.add(setCondition.field);
				if(setCondition.builder != null)
				{
					innerQueries.add(setCondition.builder);
				}
			}
			else if(condition instanceof QRY_Condition.NotCondition)
			{
				collectConditionFieldNames(((QRY_Condition.NotCondition)condition).condition, fieldNames, innerQueries);
			}
			else if(condition instanceof QRY_Condition.ConditionGroup)
			{
				for(QRY_Condition.Evaluable member : ((QRY_Condition.ConditionGroup)condition).conditions)
				{
					collectConditionFieldNames(member, fieldNames, innerQueries);
				}
			}
		}

		/**
		 * @description Refuses the read when one of the names is a field of the queried object that the running user
		 * cannot read. Each name is read as the query reads it. A sort text may hold several items joined by commas:
		 * each item is trimmed, and ASC, DESC, NULLS FIRST and NULLS LAST after the field are left out. A field written
		 * after the name of the object and a dot, such as Account.Phone on an Account query, is the field itself, so the
		 * object name is left out too. A name that is not a field of this object, such as a path through a parent or a
		 * function, is skipped.
		 *
		 * @param queriedType The object the query reads.
		 * @param fieldNames The field names and sort texts the query filters or sorts on.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException When the running user cannot read one of the fields.
		 */
		private void refuseFieldTheUserCannotRead(SObjectType queriedType, Set<String> fieldNames)
		{
			UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(queriedType);
			DescribeSObjectResult objectDescribe = describe.getDescribe();
			String objectPrefix = objectDescribe.getName() + UTIL_String.DOT;
			String localObjectPrefix = objectDescribe.getLocalName() + UTIL_String.DOT;
			for(String fieldText : fieldNames)
			{
				for(String sortItem : (fieldText ?? UTIL_String.EMPTY).split(UTIL_String.COMMA))
				{
					Matcher itemMatcher = SORT_ITEM_FIELD_PATTERN.matcher(sortItem);
					String fieldName = itemMatcher.matches() ? itemMatcher.group(1) : UTIL_String.EMPTY;
					SObjectField field = describe.getField(fieldName.removeStartIgnoreCase(objectPrefix).removeStartIgnoreCase(localObjectPrefix));
					if(field != null && !UTIL_SObjectDescribe.isFieldAccessible(field))
					{
						throw new UTIL_Exceptions.IllegalStateException(String.format(System.Label.QueryBuilder_BypassSharingField_NotReadable,
								new List<String> {UTIL_SObjectDescribe.getCachedFieldName(field)}));
					}
				}
			}
		}

		/**
		 * @description Generates and returns the SOQL string without executing it.
		 *
		 * @return The built SOQL query string
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String soql = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).equals('Technology')
		 *     .toSoql();
		 * ```
		 */
		global String toSoql()
		{
			return buildGenerator().toSoql();
		}

		/**
		 * @description Executes the query and returns a List of SObjects.
		 *
		 * @return List<SObject> results
		 *
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException In a test, when the query is an aggregate query and rows
		 * registered with TST_Mock.registerAggregateRows answer it. Read an aggregate query with toAggregateList(). The
		 * other methods that return records, such as getFirst(), getPage() and asMap(), throw in the same case.
		 * @throws UTIL_Exceptions.IllegalStateException With bypassSharing() alone, under user mode, when the query is an
		 * aggregate query, or when it filters or sorts on a field the running user cannot read. Add withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Industry).equals('Technology')
		 *     .toList();
		 * ```
		 */
		global List<SObject> toList()
		{
			refuseReadThatCannotKeepChecks(METHOD_TO_LIST);
			return readRecordList();
		}

		/**
		 * @description Runs the query and returns its records, without the fields the running user cannot read when
		 * that is asked for. toList() and the other record reads use it after their own check.
		 *
		 * @return The records of the query.
		 */
		private List<SObject> readRecordList()
		{
			return removeInaccessibleFields(readRecords(runQuery()));
		}

		/**
		 * @description Runs the query through QRY_Engine.execute and notes whether the result came from the cache, for
		 * isCached().
		 *
		 * @return The result of the query.
		 */
		private QRY_Engine.QueryResult runQuery()
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryResult result = QRY_Engine.execute(buildParameters(registry));
			lastResultCached = result.isCached;
			return result;
		}

		/**
		 * @description Returns the records of a query result. Every method of this class that reads records gets them
		 * here. It refuses a result that registered aggregate rows answered: such a result holds no records, while a
		 * live run of the same query would return AggregateResult rows, so returning nothing would hide the mistake.
		 *
		 * @param result The result of the query.
		 *
		 * @return The records of the result.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException When registered aggregate rows answered the query. Read such a
		 * query with toAggregateList() or getFirstAggregate().
		 */
		private List<SObject> readRecords(QRY_Engine.QueryResult result)
		{
			if(result.aggregateRows != null)
			{
				throw newRecordsReadFromAggregateMockException();
			}
			return result.records;
		}

		/**
		 * @description Makes the error thrown when a record read meets an aggregate query that registered aggregate
		 * rows answer. readRecords and getRandomItems both throw it, so the message is written once.
		 *
		 * @return The error, which names the object type and says to read the rows with toAggregateList().
		 */
		private UTIL_Exceptions.IllegalStateException newRecordsReadFromAggregateMockException()
		{
			return new UTIL_Exceptions.IllegalStateException(String.format(RECORDS_READ_FROM_AGGREGATE_MOCK_MESSAGE, new List<String> {String.valueOf(objectType)}));
		}

		/**
		 * @description Removes the fields the running user cannot read from the records, when stripInaccessible()
		 * is on, or when the read ignores record sharing with bypassSharing() alone and keeps the user's checks.
		 * Otherwise it returns the records unchanged. It runs on every answer: the database, the cache or a test mock.
		 * The caller's stripInaccessible() choice is not changed.
		 *
		 * @param records The records read by the query.
		 *
		 * @return The records, with unreadable fields removed when that is asked for.
		 */
		private List<SObject> removeInaccessibleFields(List<SObject> records)
		{
			if((stripInaccessibleEnabled || shouldKeepChecksWithoutSharing()) && !records.isEmpty())
			{
				return Security.stripInaccessible(AccessType.READABLE, records).getRecords();
			}
			return records;
		}

		/**
		 * @description Returns a Database.QueryLocator for batch processing.
		 *
		 * @return Database.QueryLocator
		 *
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException With bypassSharing() alone, under user mode. A batch job reads
		 * the rows later, so the fields the running user cannot read cannot be removed. Add withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Database.QueryLocator locator = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .toQueryLocator();
		 * ```
		 */
		global Database.QueryLocator toQueryLocator()
		{
			refuseReadThatCannotKeepChecks(METHOD_TO_QUERY_LOCATOR);
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = buildParameters(registry);
			return QRY_Engine.getQueryLocator(params);
		}

		/**
		 * @description Returns a Database.Cursor for reading a large set of records in parts. The cursor is opened
		 * with the sharing this builder was set up with, or with the caller's own sharing when none is set. So a cursor
		 * built with withSystemMode() and bypassSharing() fetches every row the query matches, whatever the record sharing, on every later
		 * fetch in this transaction or a later one. An exception registered through TST_Mock.throwsException() is
		 * thrown from this call exactly as it is from every other method that runs the query.
		 *
		 * @return Database.Cursor
		 *
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException With bypassSharing() alone, under user mode. The rows are fetched
		 * later, so the fields the running user cannot read cannot be removed. Add withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Database.Cursor cursor = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .toCursor();
		 * ```
		 */
		global Database.Cursor toCursor()
		{
			refuseReadThatCannotKeepChecks(METHOD_TO_CURSOR);
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = buildParameters(registry);
			return QRY_Engine.getCursor(params);
		}

		/**
		 * @description Executes the query and returns the first record (or null).
		 *
		 * @return Single SObject or null
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).equals(accountId)
		 *     .getFirst();
		 * ```
		 */
		global SObject getFirst()
		{
			Integer originalLimit = maxRecords;
			maxRecords = 1;
			List<SObject> results = toList();
			maxRecords = originalLimit;
			return results.isEmpty() ? null : results.iterator().next();
		}

		/**
		 * @description Executes an aggregate query and returns results as typed AggregateRow wrappers.
		 * Use with aggregate methods like count(field, alias), sum(), avg(), min(), max() and groupBy(). The count() that
		 * ends a query and returns a number is not an aggregate read.
		 *
		 * In a test, rows registered with TST_Mock.registerAggregateRows or QRY_Builder.setAggregateMock answer the
		 * query instead of the database.
		 *
		 * @return List of AggregateRow wrappers
		 *
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException In a test, when record mocks are registered for the object type
		 * but no aggregate rows are. Record mocks never answer an aggregate query. Also with bypassSharing() alone, under
		 * user mode: totals and group values cannot have the fields the running user cannot read removed. Add
		 * withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .count(Account.Id, 'total')
		 *     .groupBy(Account.Industry)
		 *     .toAggregateList();
		 * Map<String, Integer> totalByIndustry = new Map<String, Integer>();
		 * for(QRY_Builder.AggregateRow row : rows)
		 * {
		 *     totalByIndustry.put(row.getString('Industry'), row.getInteger('total'));
		 * }
		 * ```
		 */
		global List<AggregateRow> toAggregateList()
		{
			refuseReadThatCannotKeepChecks(METHOD_TO_AGGREGATE_LIST);
			return readAggregateRows();
		}

		/**
		 * @description Runs the aggregate query and returns its rows as AggregateRow wrappers. toAggregateList() and
		 * getFirstAggregate() use it after their own check.
		 *
		 * @return The rows of the aggregate query.
		 */
		private List<AggregateRow> readAggregateRows()
		{
			QRY_Engine.QueryResult result = runQuery();
			List<AggregateRow> rows = new List<AggregateRow>();
			if(result.aggregateRows != null)
			{
				for(Map<String, Object> values : result.aggregateRows)
				{
					rows.add(new AggregateRow(values));
				}
				return rows;
			}
			for(SObject record : removeInaccessibleFields(readRecords(result)))
			{
				rows.add(new AggregateRow((AggregateResult)record));
			}
			return rows;
		}

		/**
		 * @description Executes an aggregate query and returns the first result as a typed AggregateRow.
		 * Convenience method for single-row aggregates (e.g., SUM without GROUP BY).
		 *
		 * @return Single AggregateRow or null if no results
		 *
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException With bypassSharing() alone, under user mode: totals and group
		 * values cannot have the fields the running user cannot read removed. Add withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .sum(Opportunity.Amount, 'totalAmount')
		 *     .getFirstAggregate();
		 * Decimal totalAmount = row.getDecimal('totalAmount');
		 * ```
		 */
		global AggregateRow getFirstAggregate()
		{
			refuseReadThatCannotKeepChecks(METHOD_GET_FIRST_AGGREGATE);
			List<AggregateRow> rows = readAggregateRows();
			return rows.isEmpty() ? null : rows[0];
		}

		/**
		 * @description Returns a single random record matching the query criteria.
		 *
		 * @return Single random SObject or null
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account random = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .getRandomItem();
		 * ```
		 */
		global SObject getRandomItem()
		{
			List<SObject> items = getRandomItems(1);
			return items.isEmpty() ? null : items.iterator().next();
		}

		/**
		 * @description Returns multiple random records matching the query criteria.
		 * Uses a Database.Cursor to fetch records at a random offset, eliminating
		 * the 2,000 SOQL OFFSET limitation. Supports random selection across the
		 * full result set (up to 50 million records).
		 *
		 * When mocks are active, falls back to standard SOQL OFFSET (capped at 2,000).
		 *
		 * With stripInaccessible() on, the fields the running user cannot read are removed from the records, as in
		 * toList().
		 *
		 * @param randomCount Maximum number of random records to return
		 *
		 * @return List of random SObjects
		 *
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException In a test, when the query is an aggregate query and aggregate
		 * rows are registered for the object type. Read such a query with toAggregateList(). Also with bypassSharing()
		 * alone, under user mode, when the query is an aggregate query, or when it filters or sorts on a field the running
		 * user cannot read. Add withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> randoms = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .getRandomItems(5);
		 * ```
		 */
		global List<SObject> getRandomItems(Integer randomCount)
		{
			if(randomCount == null || randomCount <= 0)
			{
				return new List<SObject>();
			}

			refuseReadThatCannotKeepChecks(METHOD_GET_RANDOM_ITEMS);

			if(isAggregateQuery() && QRY_Engine.hasAggregateMock(objectType))
			{
				throw newRecordsReadFromAggregateMockException();
			}

			Integer totalCount = countMatchingRecords();
			if(totalCount == 0)
			{
				return new List<SObject>();
			}

			Integer randomOffset = UTIL_Random.randomInteger(Math.max(totalCount - randomCount, 0));

			if(QRY_Engine.hasMock(objectType))
			{
				return fetchRandomViaOffset(randomCount, Math.min(randomOffset, QRY_Engine.MAX_QUERY_OFFSET));
			}

			return fetchRandomViaCursor(randomCount, randomOffset);
		}

		/**
		 * @description Fetches random records using cursor-based pagination through the query engine.
		 * Routes through QRY_Engine.execute() to respect sharing proxies and security settings.
		 *
		 * @param randomCount Number of records to fetch
		 * @param randomOffset The offset position to start fetching from
		 *
		 * @return List of random SObjects
		 */
		private List<SObject> fetchRandomViaCursor(Integer randomCount, Integer randomOffset)
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = buildParameters(registry);
			params.cursorMode = QRY_Engine.CursorMode.STANDARD;
			params.randomResults = true;
			params.offset = randomOffset;
			params.pageSize = randomCount;
			params.limitCount = null;

			return removeInaccessibleFields(readRecords(QRY_Engine.execute(params)));
		}

		/**
		 * @description Fetches random records using standard SOQL OFFSET.
		 * Used as a fallback when cursor-based fetch is not available (e.g., mock queries).
		 *
		 * @param randomCount Number of records to fetch
		 * @param randomOffset The offset position (capped at MAX_QUERY_OFFSET)
		 *
		 * @return List of random SObjects
		 */
		private List<SObject> fetchRandomViaOffset(Integer randomCount, Integer randomOffset)
		{
			Integer originalLimit = maxRecords;
			Integer originalOffset = offsetCount;

			maxRecords = randomCount;
			offsetCount = randomOffset;

			List<SObject> results = readRecordList();

			maxRecords = originalLimit;
			offsetCount = originalOffset;

			return results;
		}

		/**
		 * @description Returns the number of records that match the query criteria.
		 *
		 * @return Integer count
		 *
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException With bypassSharing() alone, under user mode, when the query is an
		 * aggregate query, or when it filters on a field the running user cannot read. Add withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer total = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .count();
		 * ```
		 */
		global Integer count()
		{
			refuseReadThatCannotKeepChecks(METHOD_COUNT);
			return countMatchingRecords();
		}

		/**
		 * @description Counts the records that match the query criteria. count() and getRandomItems use it after their
		 * own check.
		 *
		 * @return The number of matching records.
		 */
		private Integer countMatchingRecords()
		{
			auditQueue.recordOperation(String.valueOf(objectType), UTIL_BypassAudit.OPERATION_QUERY, null);
			auditQueue.flush();
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Generator gen = new QRY_Generator(objectType);
			gen.selectCount();

			QRY_Condition.Evaluable effectiveCondition = buildEffectiveCondition();
			if(effectiveCondition != null)
			{
				gen.whereCondition(effectiveCondition);
			}

			QRY_Engine.QueryParameters params = new QRY_Engine.QueryParameters();
			params.objectType = objectType;
			params.queryString = gen.toSoql(registry);
			params.bindMap = registry.getMap();
			params.userMode = isUserModeRead();
			params.enforceSharing = sharingEnforced;
			params.suppressPerformanceLogging = suppressPerformanceLog;
			params.forcePerformanceLogging = forcePerformanceLog;
			params.customPerformanceThresholdMs = performanceThresholdMs;

			return QRY_Engine.executeCount(params);
		}

		/**
		 * @description Adds everything the engine needs to read this page WITHOUT a pagination cursor. That is three
		 * queries: a limited count that decides whether a pagination cursor can be opened at all, a count with no limit
		 * that gives the total when no cursor can report it, and a plain LIMIT/OFFSET query for the same page. Above
		 * the platform's row allowance the cursor cannot be opened. The failure is then a governor limit exception
		 * thrown when the cursor is created, and nothing can catch it, so all three must be ready beforehand.
		 *
		 * The counts copy every clause that changes WHICH rows match: the same full condition, the same scope, and
		 * ALL ROWS. Copying the condition keeps a query that matches few rows on its cursor. Copying ALL ROWS keeps the
		 * count correct, because a count lower than the rows the page query matches would allow exactly the read that
		 * fails. Clauses that only change the shape or order of the matched rows are left out, and so is any WITH DATA
		 * CATEGORY filter. Counting too many only sends a read that would have worked to another way of reading the
		 * page. That costs the cursor and the deleted-record count, but returns the same records.
		 *
		 * A LIMIT set on the builder also limits the count that checks the row allowance (the guard count), so a query
		 * that can never reach the platform limit is never sent another way because of rows it would not have read.
		 * Such a LIMIT also stops the plain query from being built: a cursor applies that LIMIT across the whole
		 * result, and a LIMIT on one page cannot do the same. So the plain query is not built, because it would give a
		 * different answer.
		 *
		 * Aggregate pages get no other way of being read. The platform refuses to open EITHER kind of cursor over a
		 * query with aggregate expressions or a GROUP BY, so neither kind of cursor can be opened. The engine does not
		 * offer the plain way either (`canServePlainPage`). A LIMIT/OFFSET aggregate would run, but it would report a
		 * total counted over rows instead of groups, so the page would be read but wrong.
		 *
		 * @param parameters The parameters to stamp with the fallback queries
		 * @param registry The bind registry already carrying the page query's binds
		 * @param pageOffset The row offset of the requested page
		 * @param pageSize The number of records the requested page holds
		 *
		 * @date August 2026
		 */
		private void applyPaginationFallbacks(QRY_Engine.QueryParameters parameters, QRY_BindRegistry registry, Integer pageOffset, Integer pageSize)
		{
			QRY_Condition.Evaluable effectiveCondition = buildEffectiveCondition();

			QRY_Generator counter = new QRY_Generator(objectType);
			counter.selectCount();

			if(effectiveCondition != null)
			{
				counter.whereCondition(effectiveCondition);
			}
			if(scope != null)
			{
				counter.usingScope(QRY_Generator.Scope.valueOf(scope.name()));
			}
			if(includeAllRows)
			{
				counter.allRows();
			}

			parameters.totalRecordCountQuery = renderFallbackQuery(counter, registry);

			Integer guardRowLimit = QRY_Engine.getPaginationGuardRowLimit();
			counter.limitTo(maxRecords == null ? guardRowLimit : Math.min(maxRecords, guardRowLimit));
			parameters.paginationGuardQuery = renderFallbackQuery(counter, registry);

			if(maxRecords == null)
			{
				QRY_Generator plainPage = buildGeneratorWithCondition(effectiveCondition);
				plainPage.limitTo(pageSize);
				plainPage.offset(pageOffset);
				parameters.plainPageQuery = renderFallbackQuery(plainPage, registry);
			}

			if(!useLiterals)
			{
				// Each rendering above registered a fresh set of bind names for the same values, so the map
				// handed to the engine is re-read to carry the page query's binds and every fallback's.
				parameters.bindMap = registry.getMap();
			}
		}

		/**
		 * @description Renders one fallback query, using literals or shared bind names exactly as the page
		 * query did.
		 *
		 * @param generator The configured generator to render
		 * @param registry The bind registry shared with the page query
		 *
		 * @return The rendered SOQL
		 *
		 * @date August 2026
		 */
		private String renderFallbackQuery(QRY_Generator generator, QRY_BindRegistry registry)
		{
			return useLiterals ? generator.toSoql() : generator.toSoql(registry);
		}

		/**
		 * @description Executes a paged query and returns results with pagination metadata.
		 *
		 * A page may hold at most 2,000 records, which is all a cursor will hand back in one fetch.
		 *
		 * With bypassSharing() alone, under user mode, the page has no cursor: `cursor` is null. Rows read later from
		 * that cursor would keep the fields the user cannot read, so it is not handed back. `records`, `totalRecords`
		 * and the paging flags stay correct. Ask for each later page with getPage().
		 *
		 * @param requestedPageNumber The page number to retrieve (1-based)
		 * @param requestedPageSize Number of records per page, from 1 to 2000
		 *
		 * @return Page containing records and pagination metadata
		 *
		 * @throws IllegalArgumentException When the page number is below 1, or the page size is outside 1 to 2000
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException When the transaction has used up its cursors (about fifty
		 * paged reads in one transaction that could not use a pagination cursor), and the requested page also starts
		 * past the 2,000-row offset a plain query can reach. Spread the paged reads across transactions, or narrow the query.
		 * Also with bypassSharing() alone, under user mode, when the query is an aggregate query, or when it filters or sorts
		 * on a field the running user cannot read. Add withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .orderBy(Account.Name).ascending()
		 *     .getPage(2, 25);
		 * ```
		 */
		global QueryPage getPage(Integer requestedPageNumber, Integer requestedPageSize)
		{
			if(requestedPageNumber == null || requestedPageNumber < 1)
			{
				throw new IllegalArgumentException('Page number must be 1 or greater.');
			}
			if(requestedPageSize == null || requestedPageSize < 1 || requestedPageSize > MAXIMUM_CURSOR_FETCH_ROWS)
			{
				throw new IllegalArgumentException('Page size must be between 1 and ' + MAXIMUM_CURSOR_FETCH_ROWS + ' records.');
			}
			refuseReadThatCannotKeepChecks(METHOD_GET_PAGE);

			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = buildParameters(registry);
			params.cursorMode = QRY_Engine.CursorMode.PAGINATION;
			params.pageNumber = requestedPageNumber;
			params.pageSize = requestedPageSize;
			params.offset = (requestedPageNumber - 1) * requestedPageSize;
			params.limitCount = null;
			applyPaginationFallbacks(params, registry, params.offset, requestedPageSize);

			QRY_Engine.QueryResult result = QRY_Engine.execute(params);

			QueryPage page = new QueryPage();
			page.records = removeInaccessibleFields(readRecords(result));
			page.totalRecords = result.totalRecords;
			page.pageNumber = requestedPageNumber;
			page.pageSize = requestedPageSize;
			page.deletedRecords = result.deletedRecords;
			page.cursor = shouldKeepChecksWithoutSharing() ? null : result.cursor;

			return page;
		}

		/**
		 * @description Checks whether any records exist matching the query criteria.
		 *
		 * @return Boolean true if at least one record exists
		 *
		 * @throws QueryException With bypassSharing() alone, under user mode, when the running user cannot read the object, or the
		 * object of a query inside isIn(), notIn() or subselect().
		 * @throws UTIL_Exceptions.IllegalStateException With bypassSharing() alone, under user mode, when the query is an
		 * aggregate query, or when it filters on a field the running user cannot read. Add withSystemMode().
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean hasCustomers = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .exists();
		 * ```
		 */
		global Boolean exists()
		{
			return count() > 0;
		}

		/**
		 * @description Indicates whether the last execution retrieved results from cache.
		 *
		 * @return true if results came from cache
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType).withSystemMode().withSharing().withCache(300);
		 * List<SObject> results = query.toList();
		 * Boolean fromCache = query.isCached();
		 * ```
		 */
		global Boolean isCached()
		{
			return lastResultCached;
		}

		/**
		 * @description Executes the query and returns results as a Map<Id, SObject>.
		 *
		 * @return Map<Id, SObject>
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<Id, SObject> accountMap = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .asMap();
		 * ```
		 */
		global Map<Id, SObject> asMap()
		{
			return new Map<Id, SObject>(toList());
		}

		/**
		 * @description Executes the query and returns the results as a Map keyed by the
		 * specified Id field (e.g. a parent-lookup field). Last record wins when key values
		 * collide. Delegates to UTIL_SObject.indexById.
		 *
		 * @param keyField The SObjectField token whose value will be used as the map key.
		 * Must reference an Id-typed field on the returned SObject.
		 *
		 * @return Map<Id, SObject> keyed by the field value. Records with a null key field
		 * are mapped under the null key. Returns an empty map when the query yields no results.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<Id, SObject> contactsByAccount = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .addFields(new List<SObjectField>{Contact.Id, Contact.AccountId})
		 *     .condition(Contact.AccountId).isNotNull()
		 *     .asMapById(Contact.AccountId);
		 * ```
		 */
		global Map<Id, SObject> asMapById(SObjectField keyField)
		{
			return UTIL_SObject.indexById(toList(), keyField);
		}

		/**
		 * @description Executes the query and returns the results as a Map keyed by the
		 * specified Id field. Supports dot-notation for parent fields (e.g. 'Account.OwnerId').
		 * Delegates to UTIL_SObject.indexById.
		 *
		 * @param fieldName The API name of the Id field whose value will be used as the map key.
		 *
		 * @return Map<Id, SObject> keyed by the field value. Records with a null key field
		 * are mapped under the null key. Returns an empty map when the query yields no results.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<Id, SObject> contactsByOwner = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .addField(Contact.OwnerId)
		 *     .asMapById('OwnerId');
		 * ```
		 */
		global Map<Id, SObject> asMapById(String fieldName)
		{
			return UTIL_SObject.indexById(toList(), fieldName);
		}

		/**
		 * @description Executes the query and returns the results as a Map keyed by a String
		 * field value. Last record wins when key values collide. Key casing is preserved
		 * (no implicit lowering). Delegates to UTIL_SObject.indexByStringKey.
		 *
		 * @param keyField The SObjectField token whose value will be used as the map key.
		 *
		 * @return Map<String, SObject> keyed by the stringified field value. Returns an
		 * empty map when the query yields no results.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, SObject> accountByName = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addField(Account.Name)
		 *     .asMapByString(Account.Name);
		 * ```
		 */
		global Map<String, SObject> asMapByString(SObjectField keyField)
		{
			return UTIL_SObject.indexByStringKey(toList(), keyField);
		}

		/**
		 * @description Executes the query and returns the results as a Map keyed by a String
		 * field value. Supports dot-notation for parent fields (e.g. 'Owner.Name'). Key casing
		 * is preserved. Delegates to UTIL_SObject.indexByStringKey.
		 *
		 * @param fieldName The API name of the field whose value will be used as the map key.
		 *
		 * @return Map<String, SObject> keyed by the stringified field value. Returns an empty
		 * map when the query yields no results.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, SObject> accountByOwnerName = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addField(Account.OwnerId)
		 *     .relatedField('Owner.Name')
		 *     .asMapByString('Owner.Name');
		 * ```
		 */
		global Map<String, SObject> asMapByString(String fieldName)
		{
			return UTIL_SObject.indexByStringKey(toList(), fieldName);
		}

		/**
		 * @description Executes the query and returns the results grouped by an Id field
		 * (e.g. a parent-lookup field). Duplicates are preserved as separate entries within
		 * each group. Delegates to UTIL_SObject.groupByKey.
		 *
		 * @param keyField The SObjectField token whose value will be used as the map key.
		 * Must reference an Id-typed field on the returned SObject.
		 *
		 * @return Map<Id, List<SObject>> keyed by the field value. Records with a null key
		 * field are grouped under the null key. Returns an empty map if the query yields
		 * no results.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<Id, List<SObject>> contactsByAccount = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .addFields(new List<SObjectField>{Contact.Id, Contact.AccountId})
		 *     .condition(Contact.AccountId).isNotNull()
		 *     .asGroupedMapById(Contact.AccountId);
		 * ```
		 */
		global Map<Id, List<SObject>> asGroupedMapById(SObjectField keyField)
		{
			return UTIL_SObject.groupByKey(toList(), keyField);
		}

		/**
		 * @description Executes the query and returns the results grouped by an Id field.
		 * Supports dot-notation for parent fields. Delegates to UTIL_SObject.groupByKey.
		 *
		 * @param fieldName The API name of the Id field whose value will be used as the map key.
		 *
		 * @return Map<Id, List<SObject>> keyed by the field value. Records with a null key
		 * field are grouped under the null key. Returns an empty map when the query yields
		 * no results.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<Id, List<SObject>> contactsByOwner = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .addField(Contact.OwnerId)
		 *     .asGroupedMapById('OwnerId');
		 * ```
		 */
		global Map<Id, List<SObject>> asGroupedMapById(String fieldName)
		{
			return UTIL_SObject.groupByKey(toList(), fieldName);
		}

		/**
		 * @description Executes the query and returns the results grouped by a String field
		 * value. Duplicates are preserved as separate entries within each group. Key casing
		 * is preserved. Delegates to UTIL_SObject.groupByStringKey.
		 *
		 * @param keyField The SObjectField token whose value will be used as the map key.
		 *
		 * @return Map<String, List<SObject>> keyed by the stringified field value. Returns
		 * an empty map when the query yields no results.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, List<SObject>> accountsByIndustry = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addField(Account.Industry)
		 *     .asGroupedMapByString(Account.Industry);
		 * ```
		 */
		global Map<String, List<SObject>> asGroupedMapByString(SObjectField keyField)
		{
			return UTIL_SObject.groupByStringKey(toList(), keyField);
		}

		/**
		 * @description Executes the query and returns the results grouped by a String field
		 * value. Supports dot-notation for parent fields. Key casing is preserved.
		 * Delegates to UTIL_SObject.groupByStringKey.
		 *
		 * @param fieldName The API name of the field whose value will be used as the map key.
		 *
		 * @return Map<String, List<SObject>> keyed by the stringified field value. Returns
		 * an empty map when the query yields no results.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, List<SObject>> accountsByOwnerName = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addField(Account.OwnerId)
		 *     .relatedField('Owner.Name')
		 *     .asGroupedMapByString('Owner.Name');
		 * ```
		 */
		global Map<String, List<SObject>> asGroupedMapByString(String fieldName)
		{
			return UTIL_SObject.groupByStringKey(toList(), fieldName);
		}

		/**
		 * @description Executes the query and returns a Set of record Ids.
		 *
		 * @return Set<Id>
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Id> accountIds = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .asIdSet();
		 * ```
		 */
		global Set<Id> asIdSet()
		{
			return asMap().keySet();
		}

		/**
		 * @description Returns the results as a List of Ids.
		 *
		 * @return List<Id>
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Id> accountIds = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Type).equals('Customer')
		 *     .asIdList();
		 * ```
		 */
		global List<Id> asIdList()
		{
			return new List<Id>(asIdSet());
		}

		/**
		 * @description Executes the query and returns a Set of distinct values for the specified field.
		 *
		 * @param field The field token to extract values from
		 *
		 * @return Set<Object> of field values
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> industries = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .addField(Account.Industry)
		 *     .asValueSet(Account.Industry);
		 * ```
		 
		 */
		global Set<Object> asValueSet(SObjectField field)
		{
			Set<Object> result = new Set<Object>();
			for(SObject record : toList())
			{
				result.add(record.get(field));
			}
			return result;
		}

		/**
		 * @description Executes the query and returns a Set of distinct values for the specified field.
		 *
		 * @param fieldName The field API name to extract values from
		 *
		 * @return Set<Object> of field values
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Object> ownerNames = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .relatedField('Owner.Name')
		 *     .asValueSet('Owner.Name');
		 * ```
		 
		 */
		global Set<Object> asValueSet(String fieldName)
		{
			Set<Object> result = new Set<Object>();
			for(SObject record : toList())
			{
				result.add(UTIL_SObject.getFieldValue(record, fieldName));
			}
			return result;
		}

		/**
		 * @description Executes the query and returns a Set of distinct String values for the specified field.
		 *
		 * @param field The field token to extract String values from
		 *
		 * @return Set of String field values (nulls excluded)
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<String> nicknames = QRY_Builder.selectFrom(User.SObjectType)
		 *     .addField(User.CommunityNickname)
		 *     .condition(User.CommunityNickname).startsWith('Billy')
		 *     .asStringSet(User.CommunityNickname);
		 * ```
		 */
		global Set<String> asStringSet(SObjectField field)
		{
			return UTIL_SObject.extractUniqueValues(toList(), field, true);
		}

		/**
		 * @description Executes the query and returns a Set of distinct String values for the specified field.
		 *
		 * @param fieldName The field API name to extract String values from
		 *
		 * @return Set of String field values (nulls excluded)
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<String> ownerNames = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .relatedField('Owner.Name')
		 *     .asStringSet('Owner.Name');
		 * ```
		 */
		global Set<String> asStringSet(String fieldName)
		{
			return UTIL_SObject.extractUniqueValues(toList(), fieldName, true);
		}
	}

	/**
	 * @description Internal class to hold a condition with its join type (AND/OR).
	 */
	@TestVisible
	private class ConditionEntry
	{
		/**
		 * @description One condition of the WHERE clause, joined to the conditions before it as isOr says.
		 */
		public QRY_Condition.Evaluable condition;

		/**
		 * @description Whether this is an OR condition (vs AND).
		 */
		public Boolean isOr;

		/**
		 * @description Pairs a condition with how it joins the conditions before it: with OR when isOrCondition is true, which
		 * orCondition asks for, and with AND otherwise.
		 *
		 * @param cond The condition
		 * @param isOrCondition Whether this is an OR condition
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		public ConditionEntry(QRY_Condition.Evaluable cond, Boolean isOrCondition)
		{
			condition = cond;
			isOr = isOrCondition;
		}
	}

	/**
	 * @description Internal class to hold one explicitly aliased aggregate selection until the generator
	 * is built.
	 *
	 * @date July 2026
	 */
	@TestVisible
	private class AggregateSelection
	{
		/**
		 * @description The aggregate function to apply.
		 */
		public QRY_Generator.Aggregate aggregateFunction;

		/**
		 * @description The describe-derived API name of the field to aggregate.
		 */
		public String fieldName;

		/**
		 * @description The validated result alias the value is read back by.
		 */
		public String alias;

		/**
		 * @description Holds the three values as given. The builder reads the field name from the field token and checks the
		 * alias before it calls this. The field name is checked here too, so it must be a field name or a path through
		 * parent records, such as Account.Owner.Name.
		 *
		 * @param aggregateFunction The aggregate function to apply
		 * @param fieldName The describe-derived field API name
		 * @param alias The validated result alias
		 *
		 * @throws IllegalArgumentException if the field name is not blank and is not a field name or a path through parent records, such as Account.Owner.Name
		 */
		public AggregateSelection(QRY_Generator.Aggregate aggregateFunction, String fieldName, String alias)
		{
			QRY_Generator.validateFieldPath(fieldName, 'AggregateSelection');
			this.aggregateFunction = aggregateFunction;
			this.fieldName = fieldName;
			this.alias = alias;
		}
	}

	/**
	 * @description Internal class that holds one data category filter: the group, the operator and the categories.
	 */
	@TestVisible
	private class DataCategoryEntry
	{
		/**
		 * @description The API name of the data category group, as the caller wrote it. It goes into the query unchanged; the
		 * builder keys its filters by this name in lower case.
		 */
		public String groupName;

		/**
		 * @description The filtering operator.
		 */
		public QRY_Generator.DataCategoryOperator operator;

		/**
		 * @description The category name(s).
		 */
		public List<String> categoryNames;

		/**
		 * @description Holds the group, the operator and a copy of the categories. DataCategoryBuilder checks that the list of
		 * categories is not empty and that the group has no filter yet before it calls this. The copy means that a name the
		 * caller adds to the list after the check never reaches the query.
		 *
		 * @param categoryGroup The data category group name
		 * @param op The filtering operator
		 * @param categories The category name(s)
		 */
		public DataCategoryEntry(String categoryGroup, QRY_Generator.DataCategoryOperator op, List<String> categories)
		{
			groupName = categoryGroup;
			operator = op;
			categoryNames = categories.clone();
		}
	}
}