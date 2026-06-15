// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Modern fluent query builder - the primary entry point for constructing and executing SOQL queries.
 * Provides a clean, type-safe API for building queries with support for conditions, ordering, pagination, caching,
 * and security enforcement.
 *
 * **Design Principle:** QRY_Builder is an adapter that delegates to the existing query infrastructure.
 * This ensures backwards compatibility while providing a cleaner API surface for new development.
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
 * @date February 2026, June 2026
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
	 * @description Developer name of the feature flag that drives the subscriber-reachable
	 * query default access mode.
	 */
	@TestVisible
	private static final String FLAG_USER_MODE_QUERIES = 'UserModeQueries_Enabled';

	/**
	 * @description Returns whether subscriber-reachable queries default to `AccessLevel.USER_MODE`
	 * — i.e., the resolved value of the `UserModeQueries_Enabled` feature flag. Used as the
	 * initial value of every new `Builder.userModeEnabled` field. Caching is delegated to
	 * `UTIL_FeatureFlag` / `SEL_FeatureFlag.activeFlags`.
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
		 * @description The PaginationCursor state for LWC round-trips.
		 * Can be passed back to the server for stable pagination across requests.
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
		 * @description Default constructor for QueryPage.
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
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .count('Id')
	 *     .groupBy('Industry')
	 *     .toAggregateList()[0];
	 * Integer total = row.getInteger('expr0');
	 * String industry = row.getString('Industry');
	 * ```
	 */
	global inherited sharing class AggregateRow
	{
		/**
		 * @description The underlying AggregateResult.
		 */
		private final AggregateResult result;

		/**
		 * @description Constructs an AggregateRow wrapping an AggregateResult.
		 *
		 * @param aggregateResult The AggregateResult to wrap
		 */
		public AggregateRow(AggregateResult aggregateResult)
		{
			this.result = aggregateResult;
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
		 * Object value = row.get('expr0');
		 * ```
		 */
		global Object get(String alias)
		{
			return result.get(alias);
		}

		/**
		 * @description Gets a Decimal value by alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Decimal value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Decimal total = row.getDecimal('expr0');
		 * ```
		 */
		global Decimal getDecimal(String alias)
		{
			return (Decimal)result.get(alias);
		}

		/**
		 * @description Gets an Integer value by alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Integer value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer count = row.getInteger('expr0');
		 * ```
		 */
		global Integer getInteger(String alias)
		{
			return (Integer)result.get(alias);
		}

		/**
		 * @description Gets a String value by alias.
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
			return (String)result.get(alias);
		}

		/**
		 * @description Gets an Id value by alias.
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
			return (Id)result.get(alias);
		}

		/**
		 * @description Gets a Long value by alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Long value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Long total = row.getLong('expr0');
		 * ```
		 */
		global Long getLong(String alias)
		{
			Object value = result.get(alias);
			if(value instanceof Integer)
			{
				Integer integerValue = (Integer)value;
				return integerValue;
			}
			return value == null ? null : (Long)value;
		}

		/**
		 * @description Gets a Date value by alias.
		 *
		 * @param alias The aggregate alias or field name
		 *
		 * @return The Date value
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Date earliest = row.getDate('expr0');
		 * ```
		 */
		global Date getDate(String alias)
		{
			return (Date)result.get(alias);
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
		 * @description Whether this is a HAVING condition.
		 */
		private final Boolean isHaving;

		/**
		 * @description Constructs a ConditionBuilder.
		 *
		 * @param parent The parent Builder
		 * @param field The field API name
		 */
		public ConditionBuilder(Builder parent, String field)
		{
			this(parent, field, false);
		}

		/**
		 * @description Constructs a ConditionBuilder with HAVING support.
		 *
		 * @param parent The parent Builder
		 * @param field The field API name
		 * @param isHavingCondition Whether this is a HAVING condition
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		public ConditionBuilder(Builder parent, String field, Boolean isHavingCondition)
		{
			parentBuilder = parent;
			fieldName = field;
			isHaving = isHavingCondition;
		}

		/**
		 * @description Adds the condition to the query.
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
		 * @description Extracts field values from a list of SObjects.
		 *
		 * @param records SObjects to extract values from
		 * @param field The field to extract values from
		 *
		 * @return List of extracted values
		 */
		private List<Object> extractFieldValues(List<SObject> records, SObjectField field)
		{
			List<Object> values = new List<Object>();
			for(SObject record : records)
			{
				if(record != null)
				{
					values.add(record.get(field));
				}
			}
			return values;
		}

		/**
		 * @description Adds an = condition.
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
		@SuppressWarnings('ApexEqualsHashCodeNotPaired')
		global Builder equals(Object value)
		{
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.EQUALS, value));
			return parentBuilder;
		}

		/**
		 * @description Adds a != condition.
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
		 * @description Adds a > condition.
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
		 * @description Adds a >= condition.
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
		 * @description Adds a < condition.
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
		 * @description Adds a <= condition.
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
		 * @description Adds an IN condition using a Set.
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
		 * @description Adds an IN condition by extracting field values from SObjects.
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
			List<Object> values = extractFieldValues(records, field);
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
		 * @description Adds an IN condition by extracting field values with strict handling.
		 *
		 * @param records SObjects to extract values from (must not be null or empty)
		 * @param field The field to extract values from
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if records is null or empty
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
			List<Object> values = extractFieldValues(records, field);
			if(values.isEmpty())
			{
				throw new IllegalArgumentException('Records list contains no valid records');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, values));
			return parentBuilder;
		}

		/**
		 * @description Adds a NOT IN condition using a Set.
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
		 * @description Adds a NOT IN condition by extracting field values from SObjects.
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
			List<Object> values = extractFieldValues(records, field);
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
		 * @description Adds a NOT IN condition by extracting field values with strict handling.
		 *
		 * @param records SObjects to extract values from (must not be null or empty)
		 * @param field The field to extract values from
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if records is null or empty
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
			List<Object> values = extractFieldValues(records, field);
			if(values.isEmpty())
			{
				throw new IllegalArgumentException('Records list contains no valid records');
			}
			add(new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.NOT_IN, values));
			return parentBuilder;
		}

		/**
		 * @description Adds an IS NULL condition.
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
		 * @description Adds an IS NOT NULL condition.
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
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.LIKE_X, '%' + value + '%'));
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
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.LIKE_X, value + '%'));
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
			add(new QRY_Condition.FieldCondition(fieldName, QRY_Condition.Operator.LIKE_X, '%' + value));
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
		 * @description The data category group name.
		 */
		private final String groupName;

		/**
		 * @description Constructs a DataCategoryBuilder.
		 *
		 * @param parent The parent Builder
		 * @param categoryGroup The data category group name
		 */
		public DataCategoryBuilder(Builder parent, String categoryGroup)
		{
			this.parentBuilder = parent;
			this.groupName = categoryGroup;
		}

		/**
		 * @description Filters to the exact specified category.
		 *
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryName is blank
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
			return addFilter(QRY_Generator.DataCategoryOperator.AT, categoryName);
		}

		/**
		 * @description Filters to any of the specified categories.
		 *
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryNames is null or empty
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
			return addFilter(QRY_Generator.DataCategoryOperator.AT, categoryNames);
		}

		/**
		 * @description Filters to categories above the specified category in the hierarchy.
		 *
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryName is blank
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
			return addFilter(QRY_Generator.DataCategoryOperator.ABOVE, categoryName);
		}

		/**
		 * @description Filters to categories above any of the specified categories in the hierarchy.
		 *
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryNames is null or empty
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
			return addFilter(QRY_Generator.DataCategoryOperator.ABOVE, categoryNames);
		}

		/**
		 * @description Filters to categories below the specified category in the hierarchy.
		 *
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryName is blank
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
			return addFilter(QRY_Generator.DataCategoryOperator.BELOW, categoryName);
		}

		/**
		 * @description Filters to categories below any of the specified categories in the hierarchy.
		 *
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryNames is null or empty
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
			return addFilter(QRY_Generator.DataCategoryOperator.BELOW, categoryNames);
		}

		/**
		 * @description Filters to categories above or below the specified category in the hierarchy.
		 *
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryName is blank
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
			return addFilter(QRY_Generator.DataCategoryOperator.ABOVE_BELOW, categoryName);
		}

		/**
		 * @description Filters to categories above or below any of the specified categories in the hierarchy.
		 *
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 *
		 * @throws IllegalArgumentException if categoryNames is null or empty
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
			return addFilter(QRY_Generator.DataCategoryOperator.ABOVE_BELOW, categoryNames);
		}

		/**
		 * @description Validates and adds a single-category filter to the parent builder.
		 *
		 * @param operator The filtering operator
		 * @param categoryName The category API name
		 *
		 * @return Builder for chaining
		 */
		private Builder addFilter(QRY_Generator.DataCategoryOperator operator, String categoryName)
		{
			if(String.isBlank(categoryName))
			{
				throw new IllegalArgumentException('Category name cannot be blank.');
			}
			return addFilter(operator, new List<String> {categoryName});
		}

		/**
		 * @description Validates and adds a multi-category filter to the parent builder.
		 *
		 * @param operator The filtering operator
		 * @param categoryNames The category API names
		 *
		 * @return Builder for chaining
		 */
		private Builder addFilter(QRY_Generator.DataCategoryOperator operator, List<String> categoryNames)
		{
			if(categoryNames == null || categoryNames.isEmpty())
			{
				throw new IllegalArgumentException('Category names list cannot be null or empty.');
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
		 * @description Setter-time bypass-audit queue keyed to the query surface. Setter calls
		 * (`withoutSecurity` / `withSystemMode` / `bypassSharing`) enqueue their target via
		 * `auditQueue.queue(...)`; the first executing terminal records the builder's
		 * SObjectType via `auditQueue.recordOperation(...)` — the step that produces the
		 * object-qualified targets — then calls `auditQueue.flush()`, so a builder dropped
		 * before execution emits nothing. Lazy-initialised so the secure-by-default execution
		 * path (no bypass setters called) does not allocate the queue.
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
		 * @description Whether to suppress performance logging for this query.
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
		 * @description The SObjectType being queried by this builder.
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
		 * @description Default constructor.
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
		 * @description Constructor that sets the SObject type.
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
		 * @description Adds a HAVING condition to the query.
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
		 * @description Gets the effective fields for the query.
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
		 * @description Projects a SOQL date-function expression into SELECT under an explicit alias, for
		 * read-back via AggregateRow (e.g. CALENDAR_MONTH(CloseDate) closeMonth -> row.getInteger('closeMonth')).
		 * Pair with groupBy(QRY_Function) using the same factory so the SELECT and GROUP BY expressions match.
		 *
		 * @param functionField The date-function expression, from a QRY_Function factory
		 * @param alias The read-back alias for the projected expression
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
		global virtual Builder addField(QRY_Function functionField, String alias)
		{
			explicitFields.add(functionField.toExpression() + UTIL_String.SPACE + alias);
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
		 * @description Adds parent (related) fields to the selection.
		 *
		 * @param parentFields List of field paths (e.g., 'Account.Name')
		 *
		 * @return Builder for chaining
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
				explicitFields.addAll(parentFields);
			}
			return this;
		}

		/**
		 * @description Adds a single parent field.
		 *
		 * @param parentField Field path (e.g., 'Account.Owner.Name')
		 *
		 * @return Builder for chaining
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
				explicitFields.add(parentField);
			}
			return this;
		}

		/**
		 * @description Adds a child subquery (child relationship query).
		 *
		 * @param childQuery Configured Builder for the child object
		 * @param relationshipName The child relationship API name (e.g., 'Contacts')
		 *
		 * @return Builder for chaining
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
				childQuery.childRelationshipName = relationshipName;
				childQueries.add(childQuery);
			}
			return this;
		}

		/**
		 * @description Adds a GROUP BY clause.
		 *
		 * @param groupField The field to group by
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .groupBy('Industry')
		 *     .count('Id')
		 *     .toList();
		 * ```
		 
		 */
		global Builder groupBy(String groupField)
		{
			groupByFields.add(groupField);
			return this;
		}

		/**
		 * @description Adds a field to the GROUP BY clause using an SObjectField token.
		 * Call multiple times for multi-field grouping (max 3 per SOQL spec).
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
		 * @description Adds a GROUPING(field) expression to the SELECT clause by field name.
		 *
		 * @param fieldName The field API name to wrap in GROUPING()
		 *
		 * @return Builder for chaining
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .sum(Opportunity.Amount)
		 *     .toList();
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .avg(Opportunity.Amount)
		 *     .toList();
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .min(Opportunity.CloseDate)
		 *     .toList();
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.StageName)
		 *     .max(Opportunity.Amount)
		 *     .toList();
		 * ```
		 */
		global Builder max(SObjectField field)
		{
			aggregateType = QRY_Generator.Aggregate.MAX;
			aggregateField = UTIL_SObjectDescribe.getCachedFieldName(field);
			return this;
		}

		/**
		 * @description Applies a COUNT aggregate function.
		 *
		 * @param fieldName The field to count (or null for COUNT())
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .groupBy(Account.Industry)
		 *     .count('Id')
		 *     .toList();
		 * ```
		 */
		global Builder count(String fieldName)
		{
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .groupBy(Contact.AccountId)
		 *     .countDistinct(Contact.Email)
		 *     .toList();
		 * ```
		 
		 */
		global Builder countDistinct(SObjectField field)
		{
			aggregateType = QRY_Generator.Aggregate.COUNT_DISTINCT;
			aggregateField = UTIL_SObjectDescribe.getCachedFieldName(field);
			return this;
		}

		/**
		 * @description Applies a COUNT_DISTINCT aggregate function.
		 *
		 * @param fieldName The field name to count distinct values
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .groupBy(Contact.AccountId)
		 *     .countDistinct('Email')
		 *     .toList();
		 * ```
		 */
		global Builder countDistinct(String fieldName)
		{
			aggregateType = QRY_Generator.Aggregate.COUNT_DISTINCT;
			aggregateField = fieldName;
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.AccountId)
		 *     .sum(Opportunity.Amount)
		 *     .havingSumOf(Opportunity.Amount).greaterThan(100000)
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder havingSumOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.SUM, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true);
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.AccountId)
		 *     .avg(Opportunity.Amount)
		 *     .havingAvgOf(Opportunity.Amount).greaterThan(50000)
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder havingAvgOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.AVG, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true);
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.AccountId)
		 *     .min(Opportunity.Amount)
		 *     .havingMinOf(Opportunity.Amount).greaterThan(1000)
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder havingMinOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.MIN, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true);
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .groupBy(Opportunity.AccountId)
		 *     .max(Opportunity.Amount)
		 *     .havingMaxOf(Opportunity.Amount).lessThan(1000000)
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder havingMaxOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.MAX, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true);
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .groupBy(Contact.AccountId)
		 *     .count('Id')
		 *     .havingCountOf(Contact.Id).greaterThan(10)
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder havingCountOf(SObjectField field)
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.COUNT, UTIL_SObjectDescribe.getCachedFieldName(field));
			return new ConditionBuilder(this, aggField, true);
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
		 * List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
		 *     .groupBy(Contact.AccountId)
		 *     .count('Id')
		 *     .havingCount().greaterThan(5)
		 *     .toList();
		 * ```
		 */
		global ConditionBuilder havingCount()
		{
			String aggField = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.COUNT, 'Id');
			return new ConditionBuilder(this, aggField, true);
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
			return new ConditionBuilder(this, UTIL_SObjectDescribe.getCachedFieldName(objectField));
		}

		/**
		 * @description Starts a WHERE condition on a field using its API name.
		 *
		 * @param fieldName Field API name
		 *
		 * @return ConditionBuilder for specifying the operator
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
			return new ConditionBuilder(this, fieldName);
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
		 * @description Starts an AND condition on a field using its API name.
		 *
		 * @param fieldName Field API name
		 *
		 * @return ConditionBuilder for specifying the operator
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
			return new ConditionBuilder(this, fieldName);
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
		 * @description Starts an OR condition on a field using its API name.
		 *
		 * @param fieldName Field API name
		 *
		 * @return ConditionBuilder for specifying the operator
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
			return new ConditionBuilder(this, fieldName);
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
		 * @description Adds an ORDER BY clause (default ascending).
		 *
		 * @param fieldName Field API name to sort by
		 *
		 * @return Builder for chaining
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
		 * defaults to standard SOQL behavior (NULLS FIRST for ASC, NULLS LAST for DESC).
		 *
		 * @param fieldName Field API name to sort by
		 * @param sortDescending When true, sorts DESCENDING; otherwise ASCENDING
		 *
		 * @return Builder for chaining
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
		 * @description Adds an ORDER BY clause with a dynamic sort direction and nulls placement.
		 *
		 * @param fieldName Field API name to sort by
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
		 * Boolean isNullsLast = false;
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .orderBy('CreatedDate', isDescending, isNullsLast)
		 *     .toList();
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		global Builder orderBy(String fieldName, Boolean sortDescending, Boolean nullsLast)
		{
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
		 * @description Disables all security enforcement.
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
			sharingEnforced = null;
			auditQueue.queueSecurityMode();
			return this;
		}

		/**
		 * @description Runs the query in USER_MODE.
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
		 * @description Forces SYSTEM_MODE execution regardless of the `UserModeQueries_Enabled`
		 * feature flag. Framework-internal queries that read CMDT, framework-owned sObjects, or
		 * system-schema tables must use this method so they continue working when the subscriber's
		 * running user lacks FLS/CRUD on those objects by design.
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
		 * @description Framework-internal sibling of `withSystemMode()` that flips the
		 * USER_MODE flag without enqueuing a `BypassEvent` audit entry. Use from framework
		 * selectors (`SEL_Base.query` when `systemModeRequired() == true`) and framework-internal
		 * CMDT or custom-setting lookups (e.g., `UTIL_FeatureFlag.getCustomMetadataOrSettingValue`)
		 * where USER_MODE is structurally required because the framework is reading its own
		 * configuration. Such reads are not subscriber-facing bypasses and must not pollute the
		 * `BypassEvent` forensic trail. Public-but-not-global so subscribers cannot bind to it;
		 * application code that legitimately opts out of USER_MODE must call `withSystemMode()`
		 * so the opt-out is audited.
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
			return this;
		}

		/**
		 * @description Bypasses sharing rules using a `without sharing` proxy class.
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .bypassSharing()
		 *     .toList();
		 * ```
		 */
		global Builder bypassSharing()
		{
			bypassSharingInternal();
			auditQueue.queueSharing();
			return this;
		}

		/**
		 * @description Framework-internal sibling of `bypassSharing()` that disables the sharing
		 * proxy without enqueuing a `BypassEvent` audit entry. Use from framework-internal reads
		 * that structurally require org-wide visibility (e.g. the health check's trusted-site
		 * configuration probe, the community-nickname uniqueness scan) — these are not
		 * subscriber-facing bypasses and must not pollute the `BypassEvent` forensic trail.
		 * Public-but-not-global so subscribers cannot bind to it; application code that
		 * legitimately opts out of sharing must call `bypassSharing()` so the opt-out is audited.
		 *
		 * @return Builder for chaining
		 *
		 * @example
		 * ```apex
		 * List<CspTrustedSite> trustedSites = QRY_Builder.selectFrom(CspTrustedSite.SObjectType)
		 *     .bypassSharingInternal()
		 *     .toList();
		 * ```
		 */
		public Builder bypassSharingInternal()
		{
			sharingEnforced = false;
			return this;
		}

		/**
		 * @description Enables platform caching for this query.
		 *
		 * @param ttlSeconds Time-to-live in seconds
		 *
		 * @return Builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		 *     .condition(Account.Id).equals(accountId)
		 *     .withCache(300)
		 *     .getFirst();
		 * ```
		 */
		global Builder withCache(Integer ttlSeconds)
		{
			cacheTTL = ttlSeconds;
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
		 * @description Starts a WITH DATA CATEGORY filter for the specified data category group.
		 *
		 * @param groupName The data category group API name
		 *
		 * @return DataCategoryBuilder for operator selection
		 *
		 * @throws IllegalArgumentException if groupName is blank
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
			return new DataCategoryBuilder(this, groupName);
		}

		/**
		 * @description Suppresses performance logging for this query.
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
			parameters.userMode = userModeEnabled;
			parameters.enforceSharing = sharingEnforced;
			parameters.limitCount = maxRecords;
			parameters.cacheTTL = cacheTTL;
			parameters.lockForUpdate = lockForUpdate;
			parameters.lockForReference = lockForReference;
			parameters.lockForView = lockForView;
			parameters.includeAllRows = includeAllRows;
			parameters.suppressPerformanceLogging = suppressPerformanceLog;
			parameters.forcePerformanceLogging = forcePerformanceLog;
			parameters.customPerformanceThresholdMs = performanceThresholdMs;
			parameters.whereCondition = effectiveCondition;
			parameters.orderByFields = this.orderByFields;
			return parameters;
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
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = buildParameters(registry);
			QRY_Engine.QueryResult result = QRY_Engine.execute(params);
			lastResultCached = result.isCached;

			List<SObject> records = result.records;
			if(stripInaccessibleEnabled && !records.isEmpty())
			{
				SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, records);
				records = decision.getRecords();
			}
			return records;
		}

		/**
		 * @description Returns a Database.QueryLocator for batch processing.
		 *
		 * @return Database.QueryLocator
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
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = buildParameters(registry);
			return QRY_Engine.getQueryLocator(params);
		}

		/**
		 * @description Returns a Database.Cursor for large data set traversal.
		 *
		 * @return Database.Cursor
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
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = buildParameters(registry);
			AccessLevel accessLevel = params.userMode ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
			return Database.getCursorWithBinds(params.queryString, params.bindMap ?? new Map<String, Object>(), accessLevel);
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
		 * Use with aggregate methods like count(), sum(), avg(), min(), max() and groupBy().
		 *
		 * @return List of AggregateRow wrappers
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .count('Id')
		 *     .groupBy('Industry')
		 *     .toAggregateList();
		 * for(QRY_Builder.AggregateRow row : rows)
		 * {
		 *     System.debug(row.getString('Industry') + ': ' + row.getInteger('expr0'));
		 * }
		 * ```
		 */
		global List<AggregateRow> toAggregateList()
		{
			List<AggregateRow> rows = new List<AggregateRow>();
			for(SObject record : toList())
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
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
		 *     .sum('Amount')
		 *     .getFirstAggregate();
		 * Decimal totalAmount = row.getDecimal('expr0');
		 * ```
		 */
		global AggregateRow getFirstAggregate()
		{
			List<AggregateRow> rows = toAggregateList();
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
		 * @param randomCount Maximum number of random records to return
		 *
		 * @return List of random SObjects
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

			Integer totalCount = count();
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

			QRY_Engine.QueryResult result = QRY_Engine.execute(params);
			return result.records;
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

			List<SObject> results = toList();

			maxRecords = originalLimit;
			offsetCount = originalOffset;

			return results;
		}

		/**
		 * @description Returns the number of records that match the query criteria.
		 *
		 * @return Integer count
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
			params.userMode = userModeEnabled;
			params.enforceSharing = sharingEnforced;
			params.suppressPerformanceLogging = suppressPerformanceLog;
			params.forcePerformanceLogging = forcePerformanceLog;
			params.customPerformanceThresholdMs = performanceThresholdMs;

			return QRY_Engine.executeCount(params);
		}

		/**
		 * @description Executes a paged query and returns results with pagination metadata.
		 *
		 * @param requestedPageNumber The page number to retrieve (1-based)
		 * @param requestedPageSize Number of records per page
		 *
		 * @return Page containing records and pagination metadata
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
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = buildParameters(registry);
			params.cursorMode = QRY_Engine.CursorMode.PAGINATION;
			params.pageNumber = requestedPageNumber;
			params.pageSize = requestedPageSize;
			params.offset = (requestedPageNumber - 1) * requestedPageSize;
			params.limitCount = null;

			QRY_Engine.QueryResult result = QRY_Engine.execute(params);

			QueryPage page = new QueryPage();
			page.records = result.records;
			page.totalRecords = result.totalRecords;
			page.pageNumber = requestedPageNumber;
			page.pageSize = requestedPageSize;
			page.deletedRecords = result.deletedRecords;
			page.cursor = result.cursor;

			if(stripInaccessibleEnabled && !page.records.isEmpty())
			{
				SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, page.records);
				page.records = decision.getRecords();
			}

			return page;
		}

		/**
		 * @description Checks whether any records exist matching the query criteria.
		 *
		 * @return Boolean true if at least one record exists
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
		 * QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType).withCache(300);
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
		 * @description The condition.
		 */
		public QRY_Condition.Evaluable condition;

		/**
		 * @description Whether this is an OR condition (vs AND).
		 */
		public Boolean isOr;

		/**
		 * @description Constructor.
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
	 * @description Internal class to hold a data category filter specification.
	 */
	@TestVisible
	private class DataCategoryEntry
	{
		/**
		 * @description The data category group name.
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
		 * @description Constructor.
		 *
		 * @param categoryGroup The data category group name
		 * @param op The filtering operator
		 * @param categories The category name(s)
		 */
		public DataCategoryEntry(String categoryGroup, QRY_Generator.DataCategoryOperator op, List<String> categories)
		{
			groupName = categoryGroup;
			operator = op;
			categoryNames = categories;
		}
	}
}