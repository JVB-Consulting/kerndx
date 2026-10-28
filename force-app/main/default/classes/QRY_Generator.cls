// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Internal SOQL string generator for the QRY_Builder framework.
 * Provides fluent API for building SOQL query strings with support for all standard clauses,
 * aggregates, subqueries, and parameterized queries using bind variables.
 *
 * **VISIBILITY**: Intentionally `public` (package-internal), NOT `global`.
 * This is a deliberate architectural decision:
 * - Internal implementation details should not be part of the managed package API
 * - Subscribers use QRY_Builder's fluent API which wraps this generator
 * - Keeping this internal allows future refactoring without breaking subscriber code
 *
 * @see QRY_Builder
 * @see QRY_Condition
 * @see QRY_Generator_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.ExcessiveClassLength,PMD.NcssCount,PMD.NcssTypeCount')
public inherited sharing class QRY_Generator
{
	/**
	 * @description Constant defining the separator for fields in the SELECT clause.
	 */
	@TestVisible
	private static final String FIELD_SEPARATOR = UTIL_String.COMMA + UTIL_String.SPACE;

	/**
	 * @description The rule for a field path: a name that starts with a letter and holds only letters, digits and
	 * underscores, such as Name or abc__Field__c. Names may be joined by dots to reach a parent record, such as
	 * Account.Owner.Name. A space, comma, bracket or quote never matches, so the text cannot add to the query.
	 */
	private static final String FIELD_PATH_RULE = '[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*';

	/**
	 * @description The rule for the opening round bracket of a function. Spaces may follow it, as in DISTANCE( Loc__c, ...).
	 */
	private static final String FUNCTION_OPEN_RULE = '\\(\\s*';

	/**
	 * @description The rule for the closing round bracket of a function. Spaces may come before it.
	 */
	private static final String FUNCTION_CLOSE_RULE = '\\s*\\)';

	/**
	 * @description The rule for convertTimezone around a field path, such as convertTimezone(CreatedDate). It is allowed
	 * only inside a date function, where it makes the date function use the time zone of the running user.
	 */
	private static final String CONVERT_TIMEZONE_RULE = 'convertTimezone' + FUNCTION_OPEN_RULE + FIELD_PATH_RULE + FUNCTION_CLOSE_RULE;

	/**
	 * @description The rule for a date function around a field path, such as CALENDAR_YEAR(CreatedDate), or around
	 * convertTimezone, such as HOUR_IN_DAY(convertTimezone(CreatedDate)). These are the date functions QRY_Function writes.
	 */
	private static final String DATE_FUNCTION_RULE = '(?:CALENDAR_MONTH|CALENDAR_QUARTER|CALENDAR_YEAR|DAY_IN_MONTH|DAY_IN_WEEK|DAY_IN_YEAR|DAY_ONLY'
			+ '|FISCAL_MONTH|FISCAL_QUARTER|FISCAL_YEAR|HOUR_IN_DAY|WEEK_IN_MONTH|WEEK_IN_YEAR)' + FUNCTION_OPEN_RULE
			+ '(?:' + FIELD_PATH_RULE + '|' + CONVERT_TIMEZONE_RULE + ')' + FUNCTION_CLOSE_RULE;

	/**
	 * @description The rule for one number of a distance point: an optional minus sign, digits, an optional decimal part
	 * and an optional exponent such as E-7. The word null is also allowed, because a missing number is written as null.
	 */
	private static final String COORDINATE_RULE = '(?:-?[0-9]+(?:\\.[0-9]+)?(?:[Ee][+-]?[0-9]+)?|null)';

	/**
	 * @description The rule for the distance function QRY_Function writes: DISTANCE, then in round brackets a field path,
	 * GEOLOCATION with two numbers in round brackets, and the unit 'mi' or 'km'. For example:
	 * DISTANCE(Location__c, GEOLOCATION(37.77,-122.41), 'mi').
	 */
	private static final String DISTANCE_RULE = 'DISTANCE' + FUNCTION_OPEN_RULE + FIELD_PATH_RULE + ',\\s*GEOLOCATION' + FUNCTION_OPEN_RULE + COORDINATE_RULE + ',\\s*'
			+ COORDINATE_RULE + FUNCTION_CLOSE_RULE + ',\\s*\'(?:mi|km)\'' + FUNCTION_CLOSE_RULE;

	/**
	 * @description The rule for a field expression: a field path, a date function or a distance function.
	 */
	private static final String FIELD_EXPRESSION_RULE = '(?:' + FIELD_PATH_RULE + '|' + DATE_FUNCTION_RULE + '|' + DISTANCE_RULE + ')';

	/**
	 * @description The rule for an aggregate around a field path, such as SUM(Amount) or COUNT(Id): the text the builder
	 * writes for a HAVING condition and for a sort by count.
	 */
	private static final String AGGREGATE_RULE = '(?:COUNT|COUNT_DISTINCT|SUM|AVG|MIN|MAX)' + FUNCTION_OPEN_RULE + FIELD_PATH_RULE + FUNCTION_CLOSE_RULE;

	/**
	 * @description The rule for toLabel around a field path, such as toLabel(Status), which compares or sorts by the
	 * translated label of a picklist value.
	 */
	private static final String TO_LABEL_RULE = 'toLabel' + FUNCTION_OPEN_RULE + FIELD_PATH_RULE + FUNCTION_CLOSE_RULE;

	/**
	 * @description The rule for the field side of a WHERE or HAVING condition: a field expression, an aggregate or toLabel.
	 */
	private static final String CONDITION_FIELD_RULE = '(?:' + FIELD_EXPRESSION_RULE + '|' + AGGREGATE_RULE + '|' + TO_LABEL_RULE + ')';

	/**
	 * @description The rule for one sort item: the field side of a condition, then ASC or DESC if wanted, then NULLS FIRST
	 * or NULLS LAST if wanted.
	 */
	private static final String SORT_ITEM_RULE = CONDITION_FIELD_RULE + '(?:\\s+(?:ASC|DESC))?(?:\\s+NULLS\\s+(?:FIRST|LAST))?';

	/**
	 * @description Finds a whole text that is one field path. Letter case does not matter.
	 */
	private static final Pattern FIELD_PATH_PATTERN = Pattern.compile('(?i)' + FIELD_PATH_RULE);

	/**
	 * @description Finds a whole text that is one field expression, with spaces before or after it if wanted. It checks one
	 * text and each item of a group list. Letter case does not matter.
	 */
	private static final Pattern FIELD_EXPRESSION_PATTERN = Pattern.compile('(?i)\\s*' + FIELD_EXPRESSION_RULE + '\\s*');

	/**
	 * @description Finds a whole text that is the field side of one condition, with spaces before or after it if wanted. It
	 * checks one text and the last item of a sort list that gets its direction from the caller. Letter case does not matter.
	 */
	private static final Pattern CONDITION_FIELD_PATTERN = Pattern.compile('(?i)\\s*' + CONDITION_FIELD_RULE + '\\s*');

	/**
	 * @description Finds a whole text that is one sort item, with spaces before or after it if wanted. It checks each item of
	 * a sort list. Letter case does not matter.
	 */
	private static final Pattern SORT_ITEM_PATTERN = Pattern.compile('(?i)\\s*' + SORT_ITEM_RULE + '\\s*');

	/**
	 * @description The longest field text the checks read, and the longest item of a list. A field path reaches at most five
	 * parent records, and each name has at most 40 characters, plus a namespace prefix of up to 15 characters and a suffix
	 * such as __c. That is about 370 characters; a function around the path, a direction and a nulls order add less than
	 * 100 more. A longer text is refused before a pattern reads it, because a pattern that reads a very long text can stop
	 * the whole transaction with an error no code can catch.
	 */
	private static final Integer MAXIMUM_FIELD_TEXT_LENGTH = 500;

	/**
	 * @description The longest sort list or group list the checks read: 16,000 characters, 32 times the longest item. ORDER
	 * BY takes at most 32 fields, and a real item is under 470 characters (see the field text limit above), so 32 real items
	 * and the commas between them fit. A longer list is refused before it is split into items.
	 */
	private static final Integer MAXIMUM_FIELD_LIST_LENGTH = 32 * MAXIMUM_FIELD_TEXT_LENGTH;

	/**
	 * @description Enumeration of supported SOQL Aggregate functions.
	 */
	public enum Aggregate
	{
		/**
		 * @description Calculates the average value of a numeric field.
		 */
		AVG,

		/**
		 * @description Counts the number of rows that match the query criteria.
		 */
		COUNT,

		/**
		 * @description Counts the number of distinct non-null values.
		 */
		COUNT_DISTINCT,

		/**
		 * @description Returns the maximum value of a field.
		 */
		MAX,

		/**
		 * @description Returns the minimum value of a field.
		 */
		MIN,

		/**
		 * @description Calculates the sum of a numeric field.
		 */
		SUM
	}

	/**
	 * @description Enumeration of valid SOQL scope values.
	 */
	public enum Scope
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
	 * @description Maps Scope enum values to their SOQL string representations.
	 */
	private static final Map<Scope, String> SCOPE_STRINGS = new Map<Scope, String>
	{
			Scope.MINE => 'Mine',
			Scope.MY_TERRITORY => 'My_Territory',
			Scope.MY_TEAM_TERRITORY => 'My_Team_Territory',
			Scope.TEAM => 'Team',
			Scope.DELEGATED => 'Delegated',
			Scope.EVERYTHING => 'Everything'
	};

	/**
	 * @description Enumeration of SOQL Data Category filtering selectors for the WITH DATA CATEGORY clause.
	 */
	public enum DataCategoryOperator
	{
		/**
		 * @description Matches the exact category.
		 */
		AT,

		/**
		 * @description Matches categories above the specified category in the hierarchy.
		 */
		ABOVE,

		/**
		 * @description Matches categories below the specified category in the hierarchy.
		 */
		BELOW,
		/**
		 * @description Matches categories above or below the specified category in the hierarchy.
		 */
		ABOVE_BELOW
	}

	/**
	 * @description Specifies the record-locking behaviour appended to the generated SOQL.
	 */
	private enum LockMode
	{
		/**
		 * @description Appends FOR UPDATE (pessimistic row lock).
		 */
		FOR_UPDATE,

		/**
		 * @description Appends FOR REFERENCE (registers a view-count event).
		 */
		FOR_REFERENCE,

		/**
		 * @description Appends FOR VIEW (marks records as recently viewed).
		 */
		FOR_VIEW
	}

	/**
	 * @description Static constants for inner enum values, required because Apex prohibits
	 * referencing inner enum static fields from outer-class instance methods.
	 */
	private static final LockMode LOCK_FOR_UPDATE = LockMode.FOR_UPDATE;
	/**
	 * @description Short name for LockMode.FOR_REFERENCE, which forReference stores so the generated query ends with FOR REFERENCE.
	 * The short name exists for the same reason as LOCK_FOR_UPDATE.
	 */
	private static final LockMode LOCK_FOR_REFERENCE = LockMode.FOR_REFERENCE;
	/**
	 * @description Short name for LockMode.FOR_VIEW, which forView stores so the generated query ends with FOR VIEW. The short name
	 * exists for the same reason as LOCK_FOR_UPDATE.
	 */
	private static final LockMode LOCK_FOR_VIEW = LockMode.FOR_VIEW;

	/**
	 * @description Flag indicating whether all describable fields should be included.
	 */
	private Boolean includeAllFields = false;

	/**
	 * @description The single aggregate the query selects, such as COUNT or SUM, set by selectCount and the other aggregate
	 * methods. When it is set, or an aliased aggregate is added, the SELECT clause lists aggregates instead of fields.
	 */
	private Aggregate aggregateFunction;

	/**
	 * @description The field for the aggregate function.
	 */
	private String aggregateField;

	/**
	 * @description Explicitly aliased aggregate selections ('COUNT(Field__c) myAlias'), rendered in call
	 * order after the legacy single aggregate (when one is set). Multiple selections let one query fold
	 * several aggregates (e.g. COUNT + MIN + MAX) without falling back to hand-written SOQL. Lazy-loaded
	 * on first access.
	 */
	private final List<String> aggregateSelections
	{
		get
		{
			if(aggregateSelections == null)
			{
				aggregateSelections = new List<String>();
			}
			return aggregateSelections;
		}
		private set;
	}

	/**
	 * @description Lowercased aliases already claimed by aggregate selections, so a duplicate alias is
	 * rejected when it is registered instead of surfacing as a QueryException at query time. Lowercased
	 * because SOQL treats aliases case-insensitively. Lazy-loaded on first access.
	 */
	private final Set<String> usedSelectAliases
	{
		get
		{
			if(usedSelectAliases == null)
			{
				usedSelectAliases = new Set<String>();
			}
			return usedSelectAliases;
		}
		private set;
	}

	/**
	 * @description Flag for WITH USER_MODE field-level security enforcement.
	 */
	private Boolean enforceFieldLevelSecurity = false;

	/**
	 * @description List of WITH DATA CATEGORY filters. Lazy-loaded on first access.
	 */
	private final List<DataCategoryFilter> dataCategoryFilters
	{
		get
		{
			if(dataCategoryFilters == null)
			{
				dataCategoryFilters = new List<DataCategoryFilter>();
			}
			return dataCategoryFilters;
		}
		private set;
	}

	/**
	 * @description The active record-locking mode. Null means no locking.
	 */
	private LockMode lockMode;

	/**
	 * @description Flag for ALL ROWS.
	 */
	private Boolean includeAllRows = false;

	/**
	 * @description The maximum number of records to return.
	 */
	private Integer limitCount;

	/**
	 * @description The number of records to skip.
	 */
	private Integer offsetCount;

	/**
	 * @description List of ORDER BY conditions. Lazy-loaded on first access.
	 */
	private final List<OrderBy> orderByList
	{
		get
		{
			if(orderByList == null)
			{
				orderByList = new List<OrderBy>();
			}
			return orderByList;
		}
		private set;
	}

	/**
	 * @description The one condition the WHERE clause holds; a group of conditions is one AndCondition or OrCondition. Null
	 * means the query has no WHERE clause.
	 */
	private QRY_Condition.Evaluable whereCondition;

	/**
	 * @description The one condition the HAVING clause holds, which tests the aggregate of each group. Null means the query
	 * has no HAVING clause.
	 */
	private QRY_Condition.Evaluable havingCondition;

	/**
	 * @description The SObject API name.
	 */
	private String objectName;

	/**
	 * @description The GROUP BY fields. Lazy-loaded on first access.
	 */
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
	private Boolean rollupMode = false;

	/**
	 * @description Whether to use GROUP BY CUBE.
	 */
	private Boolean cubeMode = false;

	/**
	 * @description Which set of records the query reads, written after FROM as USING SCOPE. Null means the query has no
	 * USING SCOPE clause.
	 */
	private Scope scopeValue;

	/**
	 * @description Registry for managing bind variables.
	 */
	@TestVisible
	private QRY_BindRegistry bindRegistry;

	/**
	 * @description Set of fields or subqueries in the SELECT clause.
	 */
	private final Set<Object> selectFields = new Set<Object>();

	/**
	 * @description Creates an empty generator with no object. Call fromObject before toSoql, which throws a
	 * ConfigurationException when no object is set.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	public QRY_Generator()
	{
	}

	/**
	 * @description Constructor with SObjectType.
	 *
	 * @param objectType The SObjectType to query.
	 */
	public QRY_Generator(SObjectType objectType)
	{
		this.objectName = UTIL_SObjectDescribe.getObjectNameFromType(objectType);
	}

	/**
	 * @description Specifies that all fields should be included.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectAllFields()
	{
		includeAllFields = true;
		return this;
	}

	/**
	 * @description Adds a field to the SELECT clause.
	 *
	 * @param fieldName The field API name.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator addField(String fieldName)
	{
		if(String.isNotBlank(fieldName))
		{
			selectFields.add(fieldName);
		}
		return this;
	}

	/**
	 * @description Adds a field to the SELECT clause.
	 *
	 * @param field The SObjectField.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator addField(SObjectField field)
	{
		if(field != null)
		{
			selectFields.add(field);
		}
		return this;
	}

	/**
	 * @description Adds multiple fields to the SELECT clause.
	 *
	 * @param fields List of field names.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator addFields(List<String> fields)
	{
		if(fields != null)
		{
			for(String fieldName : fields)
			{
				addField(fieldName);
			}
		}
		return this;
	}

	/**
	 * @description Adds multiple fields to the SELECT clause.
	 *
	 * @param fields Set of field names.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator addFields(Set<String> fields)
	{
		if(fields != null)
		{
			for(String fieldName : fields)
			{
				addField(fieldName);
			}
		}
		return this;
	}

	/**
	 * @description Adds a subquery to the SELECT clause.
	 *
	 * @param subquery The subquery generator.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator addSubquery(QRY_Generator subquery)
	{
		if(subquery != null)
		{
			selectFields.add(subquery);
		}
		return this;
	}

	/**
	 * @description Sets the object for the FROM clause from its token, by reading its API name from the describe cache. It
	 * replaces any object set earlier.
	 *
	 * @param objectType The SObjectType.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator fromObject(SObjectType objectType)
	{
		this.objectName = UTIL_SObjectDescribe.getObjectNameFromType(objectType);
		return this;
	}

	/**
	 * @description Sets the object for the FROM clause by API name, used exactly as given. It replaces any object set
	 * earlier. toSoql throws a ConfigurationException when the name is blank.
	 *
	 * @param objectApiName The object API name, or the name of a child relationship for an inner query.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the name is not blank and is not one name, or names joined by dots.
	 */
	public QRY_Generator fromObject(String objectApiName)
	{
		validateFieldPath(objectApiName, 'fromObject');
		objectName = objectApiName;
		return this;
	}

	/**
	 * @description Alias for addField - sets a single field to select.
	 * Primarily for builder-style construction in tests.
	 *
	 * @param fieldName The field name to select.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectX(String fieldName)
	{
		return addField(fieldName);
	}

	/**
	 * @description Alias for fromObject - sets the FROM clause.
	 * Primarily for builder-style construction in tests.
	 *
	 * @param objectApiName The object API name.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the name is not blank and is not one name, or names joined by dots.
	 */
	public QRY_Generator fromX(String objectApiName)
	{
		validateFieldPath(objectApiName, 'fromX');
		return fromObject(objectApiName);
	}

	/**
	 * @description Replaces the WHERE condition; it does not add to it. To combine several conditions, pass one AndCondition
	 * or OrCondition that holds them. Null removes the WHERE clause.
	 *
	 * @param condition The condition to apply.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator whereCondition(QRY_Condition.Evaluable condition)
	{
		this.whereCondition = condition;
		return this;
	}

	/**
	 * @description Alias for whereCondition - sets the WHERE clause.
	 * Primarily for builder-style construction in tests.
	 *
	 * @param condition The condition to apply.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator whereX(QRY_Condition.Evaluable condition)
	{
		return whereCondition(condition);
	}

	/**
	 * @description Replaces the HAVING condition; it does not add to it. To combine several conditions, pass one
	 * AndCondition or OrCondition that holds them. Null removes the HAVING clause.
	 *
	 * @param condition The condition to apply.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator havingCondition(QRY_Condition.Evaluable condition)
	{
		this.havingCondition = condition;
		return this;
	}

	/**
	 * @description Adds an ORDER BY clause.
	 *
	 * @param orderBy The ORDER BY entry to add.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator orderBy(OrderBy orderBy)
	{
		if(orderBy != null)
		{
			orderByList.add(orderBy);
		}
		return this;
	}

	/**
	 * @description Adds a field to the GROUP BY clause. Call multiple times for multi-field grouping. The text is kept as
	 * given, and a blank text is ignored.
	 *
	 * @param fieldName The field to group by, or several field expressions joined by commas.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the text is not a list of field expressions (see validateGroupList).
	 */
	public QRY_Generator groupBy(String fieldName)
	{
		if(String.isNotBlank(fieldName))
		{
			validateGroupList(fieldName, 'groupBy');
			groupByFields.add(fieldName);
		}
		return this;
	}

	/**
	 * @description Flags the GROUP BY clause as ROLLUP for subtotals.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator rollup()
	{
		this.rollupMode = true;
		this.cubeMode = false;
		return this;
	}

	/**
	 * @description Flags the GROUP BY clause as CUBE for cross-tabulation.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator cube()
	{
		this.cubeMode = true;
		this.rollupMode = false;
		return this;
	}

	/**
	 * @description Adds a GROUPING(field) expression to the SELECT clause.
	 *
	 * @param fieldName The field to wrap in GROUPING().
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the text is not one field expression (see validateFieldExpression).
	 */
	public QRY_Generator grouping(String fieldName)
	{
		if(String.isNotBlank(fieldName))
		{
			validateFieldExpression(fieldName, 'grouping');
			selectFields.add('GROUPING(' + fieldName + ')');
		}
		return this;
	}

	/**
	 * @description Writes LIMIT and this number near the end of the query. Null removes the LIMIT. The number is not
	 * checked.
	 *
	 * @param count The maximum records to return.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator limitTo(Integer count)
	{
		this.limitCount = count;
		return this;
	}

	/**
	 * @description Writes OFFSET and this number after the LIMIT, so the query skips that many rows. Null removes the
	 * OFFSET.
	 *
	 * @param count The number of records to skip.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator offset(Integer count)
	{
		this.offsetCount = count;
		return this;
	}

	/**
	 * @description Chooses which set of records the query reads, written right after FROM as USING SCOPE. It replaces any
	 * scope set earlier, and null removes the clause.
	 *
	 * @param scope The scope to use.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator usingScope(Scope scope)
	{
		this.scopeValue = scope;
		return this;
	}

	/**
	 * @description Enables WITH USER_MODE field-level security enforcement.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator withSecurityEnforced()
	{
		this.enforceFieldLevelSecurity = true;
		return this;
	}

	/**
	 * @description Adds a filter to the WITH DATA CATEGORY clause. Several filters are joined with AND, and a null filter is
	 * ignored. toSoql throws a ConfigurationException when withSecurityEnforced was also called.
	 *
	 * @param filter The data category filter to add.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator withDataCategory(DataCategoryFilter filter)
	{
		if(filter == null)
		{
			return this;
		}
		dataCategoryFilters.add(filter);
		return this;
	}

	/**
	 * @description Enables FOR UPDATE locking.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator forUpdate()
	{
		this.lockMode = LOCK_FOR_UPDATE;
		this.includeAllRows = false;
		return this;
	}

	/**
	 * @description Enables FOR REFERENCE locking.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator forReference()
	{
		this.lockMode = LOCK_FOR_REFERENCE;
		return this;
	}

	/**
	 * @description Enables FOR VIEW locking.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator forView()
	{
		this.lockMode = LOCK_FOR_VIEW;
		return this;
	}

	/**
	 * @description Enables ALL ROWS.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator allRows()
	{
		this.includeAllRows = true;
		this.lockMode = null;
		return this;
	}

	/**
	 * @description Sets a COUNT aggregate.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectCount()
	{
		aggregateFunction = Aggregate.COUNT;
		aggregateField = null;
		return this;
	}

	/**
	 * @description Sets a COUNT aggregate on a specific field.
	 *
	 * @param fieldName The field to count.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the name is not blank and is not one field path. A blank name gives COUNT().
	 */
	public QRY_Generator selectCount(String fieldName)
	{
		validateFieldPath(fieldName, 'selectCount');
		aggregateFunction = Aggregate.COUNT;
		aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets an AVG aggregate.
	 *
	 * @param fieldName The field to average.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the name is not blank and is not one field path. A blank name gives AVG().
	 */
	public QRY_Generator selectAvg(String fieldName)
	{
		validateFieldPath(fieldName, 'selectAvg');
		aggregateFunction = Aggregate.AVG;
		aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets a SUM aggregate.
	 *
	 * @param fieldName The field to sum.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the name is not blank and is not one field path. A blank name gives SUM().
	 */
	public QRY_Generator selectSum(String fieldName)
	{
		validateFieldPath(fieldName, 'selectSum');
		aggregateFunction = Aggregate.SUM;
		aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets a MIN aggregate.
	 *
	 * @param fieldName The field to find minimum.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the name is not blank and is not one field path. A blank name gives MIN().
	 */
	public QRY_Generator selectMin(String fieldName)
	{
		validateFieldPath(fieldName, 'selectMin');
		aggregateFunction = Aggregate.MIN;
		aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets a MAX aggregate.
	 *
	 * @param fieldName The field to find maximum.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the name is not blank and is not one field path. A blank name gives MAX().
	 */
	public QRY_Generator selectMax(String fieldName)
	{
		validateFieldPath(fieldName, 'selectMax');
		aggregateFunction = Aggregate.MAX;
		aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets a COUNT_DISTINCT aggregate.
	 *
	 * @param fieldName The field to count distinct values.
	 *
	 * @return The current generator for method chaining.
	 *
	 * @throws IllegalArgumentException if the name is not blank and is not one field path. A blank name gives COUNT_DISTINCT().
	 */
	public QRY_Generator selectCountDistinct(String fieldName)
	{
		validateFieldPath(fieldName, 'selectCountDistinct');
		aggregateFunction = Aggregate.COUNT_DISTINCT;
		aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Adds an explicitly aliased aggregate selection to the SELECT clause. Unlike the single
	 * legacy aggregate (selectCount/selectSum/...), selections accumulate, so one query can fold several
	 * aggregates (e.g. COUNT(Id) plus MIN and MAX of CreatedDate) and read each back by its alias. The
	 * alias is validated as a bare identifier so a caller-supplied alias can never smuggle SOQL into the
	 * clause. The field name must be one field path (see validateFieldPath) for the same reason.
	 *
	 * @param aggregate The aggregate function to apply.
	 * @param fieldName The field to aggregate; must not be blank.
	 * @param alias The result alias to read the value back by; must be a bare identifier, unique across
	 * the aggregate selections.
	 *
	 * @return This generator for chaining.
	 *
	 * @throws IllegalArgumentException if fieldName is blank or is not one field path, the alias is not a bare identifier,
	 * or the alias duplicates an earlier aggregate selection.
	 *
	 * @example
	 * ```apex
	 * generator.selectAggregate(QRY_Generator.Aggregate.COUNT, 'Id', 'rowTotal');
	 * ```
	 */
	public QRY_Generator selectAggregate(Aggregate aggregate, String fieldName, String alias)
	{
		if(String.isBlank(fieldName))
		{
			throw new IllegalArgumentException('Aggregate selection requires a field name');
		}
		validateFieldPath(fieldName, 'selectAggregate');
		String validatedAlias = validateSelectAlias(alias);
		if(!usedSelectAliases.add(validatedAlias.toLowerCase()))
		{
			throw new IllegalArgumentException('Duplicate SELECT alias: ' + validatedAlias);
		}
		aggregateSelections.add(formatAggregate(aggregate, fieldName) + UTIL_String.SPACE + validatedAlias);
		return this;
	}

	/**
	 * @description Validates a SELECT result alias as a bare identifier (a letter followed by letters,
	 * digits or underscores), so a caller-supplied alias can never carry SOQL syntax into a generated
	 * clause. Guards every explicit-alias entry point: the aliased aggregate selections and the
	 * alias of a selected QRY_Function. Surrounding whitespace is trimmed rather than rejected: SOQL
	 * itself ignores padding around an alias, so padding must not break a caller that worked before
	 * validation existed.
	 *
	 * @param alias The alias to validate.
	 *
	 * @return The validated alias, trimmed of surrounding whitespace.
	 *
	 * @throws IllegalArgumentException if the alias is blank or not a bare identifier.
	 *
	 * @example
	 * ```apex
	 * String alias = QRY_Generator.validateSelectAlias('rowTotal');
	 * ```
	 */
	public static String validateSelectAlias(String alias)
	{
		String normalizedAlias = alias?.trim();
		if(String.isBlank(normalizedAlias) || !Pattern.matches('[a-zA-Z][a-zA-Z0-9_]*', normalizedAlias))
		{
			throw new IllegalArgumentException('SELECT alias must be a bare identifier (a letter followed by letters, digits or underscores): ' + alias);
		}
		return normalizedAlias;
	}

	/**
	 * @description Checks that a text is one field path: a field API name such as Name or abc__Field__c, or names joined by
	 * dots that reach a parent record, such as Account.Owner.Name. It is used where the query needs a plain name: a COUNT
	 * field, a parent field, a relationship name, an object name and a data category name. The text is trimmed first. A
	 * blank text is given back trimmed and not checked, so each caller keeps its own rule for a blank name.
	 *
	 * @param fieldPath The text to check.
	 * @param methodName The method that received the text. The error message names it.
	 *
	 * @return The text, trimmed.
	 *
	 * @throws IllegalArgumentException if the text is not one field path or is longer than 500 characters. The message does not repeat the text.
	 *
	 * @example
	 * ```apex
	 * String fieldPath = QRY_Generator.validateFieldPath('Account.Name', 'relatedField');
	 * ```
	 */
	public static String validateFieldPath(String fieldPath, String methodName)
	{
		return matchWholeText(FIELD_PATH_PATTERN, fieldPath, methodName);
	}

	/**
	 * @description Checks that a text is one field expression: a field path, a date function around a field path such as
	 * CALENDAR_YEAR(CreatedDate) or around convertTimezone such as HOUR_IN_DAY(convertTimezone(CreatedDate)), or the
	 * distance function QRY_Function writes, such as DISTANCE(Location__c, GEOLOCATION(37.77,-122.41), 'mi'). Spaces just
	 * inside the round brackets are allowed. The text is trimmed first. A blank text is given back trimmed and not checked.
	 *
	 * @param fieldExpression The text to check.
	 * @param methodName The method that received the text. The error message names it.
	 *
	 * @return The text, trimmed.
	 *
	 * @throws IllegalArgumentException if the text is not one field expression or is longer than 500 characters. The message does not repeat the text.
	 *
	 * @example
	 * ```apex
	 * String expression = QRY_Generator.validateFieldExpression('CALENDAR_YEAR(CreatedDate)', 'grouping');
	 * ```
	 */
	public static String validateFieldExpression(String fieldExpression, String methodName)
	{
		return matchWholeText(FIELD_EXPRESSION_PATTERN, fieldExpression, methodName);
	}

	/**
	 * @description Checks that a text can be the field side of a WHERE or HAVING condition: a field expression, an
	 * aggregate around a field path such as SUM(Amount) or COUNT(Id), or toLabel around a field path such as
	 * toLabel(Status). The text is trimmed first. A blank text is given back trimmed and not checked.
	 *
	 * @param conditionField The text to check.
	 * @param methodName The method that received the text. The error message names it.
	 *
	 * @return The text, trimmed.
	 *
	 * @throws IllegalArgumentException if the text is none of these shapes or is longer than 500 characters. The message does not repeat the text.
	 *
	 * @example
	 * ```apex
	 * String field = QRY_Generator.validateConditionField('SUM(Amount)', 'havingSumOf');
	 * ```
	 */
	public static String validateConditionField(String conditionField, String methodName)
	{
		return matchWholeText(CONDITION_FIELD_PATTERN, conditionField, methodName);
	}

	/**
	 * @description Checks that a text is a list of sort items joined by commas, such as Name DESC NULLS LAST, CreatedDate.
	 * Each item is the field side of a condition, then ASC or DESC if wanted, then NULLS FIRST or NULLS LAST if wanted.
	 * Letter case and the number of spaces between words do not matter. The text is trimmed first. A blank text is given
	 * back trimmed and not checked.
	 *
	 * @param sortList The text to check.
	 * @param methodName The method that received the text. The error message names it.
	 *
	 * @return The text, trimmed.
	 *
	 * @throws IllegalArgumentException if the text is not such a list, is longer than 16,000 characters or has an item longer
	 * than 500 characters. The message does not repeat the text.
	 *
	 * @example
	 * ```apex
	 * String sortList = QRY_Generator.validateSortList('Name DESC, CreatedDate', 'orderBy');
	 * ```
	 */
	public static String validateSortList(String sortList, String methodName)
	{
		String trimmedText = sortList?.trim();
		matchEveryListItem(SORT_ITEM_PATTERN, trimmedText, methodName);
		return trimmedText;
	}

	/**
	 * @description Checks a sort list for a method that adds the direction and the nulls order itself. It is the same as
	 * validateSortList, except that the last item must have no direction and no nulls order, so the query never reads
	 * DESC DESC. For example, Name DESC, Industry passes and Name DESC does not. The text is trimmed first. A blank text is
	 * given back trimmed and not checked.
	 *
	 * @param sortList The text to check.
	 * @param methodName The method that received the text. The error message names it.
	 *
	 * @return The text, trimmed.
	 *
	 * @throws IllegalArgumentException if the text is not such a list, is longer than 16,000 characters or has an item longer
	 * than 500 characters. The message does not repeat the text.
	 *
	 * @example
	 * ```apex
	 * String sortList = QRY_Generator.validateSortListBeforeDirection('Name DESC, Industry', 'orderBy');
	 * ```
	 */
	public static String validateSortListBeforeDirection(String sortList, String methodName)
	{
		String trimmedText = sortList?.trim();
		List<String> items = matchEveryListItem(SORT_ITEM_PATTERN, trimmedText, methodName);
		if(!items.isEmpty() && !isShortTextMatching(CONDITION_FIELD_PATTERN, items[items.size() - 1]))
		{
			throw newFieldNameNotAllowedException(methodName);
		}
		return trimmedText;
	}

	/**
	 * @description Checks that a text is a list of field expressions joined by commas, such as Name, Industry, for a GROUP
	 * BY clause. An aggregate or toLabel is not allowed here. The text is trimmed first. A blank text is given back trimmed
	 * and not checked.
	 *
	 * @param groupList The text to check.
	 * @param methodName The method that received the text. The error message names it.
	 *
	 * @return The text, trimmed.
	 *
	 * @throws IllegalArgumentException if the text is not such a list, is longer than 16,000 characters or has an item longer
	 * than 500 characters. The message does not repeat the text.
	 *
	 * @example
	 * ```apex
	 * String groupList = QRY_Generator.validateGroupList('Name, Industry', 'groupBy');
	 * ```
	 */
	public static String validateGroupList(String groupList, String methodName)
	{
		String trimmedText = groupList?.trim();
		matchEveryListItem(FIELD_EXPRESSION_PATTERN, trimmedText, methodName);
		return trimmedText;
	}

	/**
	 * @description Checks that every field this query selects as text is one field path. A query used inside an IN or NOT IN
	 * condition is written inside the outer WHERE clause, so its selected text must not be able to add to that clause. A
	 * field given as a field token always passes, and an inner query in the select list is left to Salesforce, which refuses
	 * it there.
	 *
	 * @param methodName The method or class that holds this query as an inner query. The error message names it.
	 *
	 * @throws IllegalArgumentException if a selected text is not one field path. The message does not repeat the text.
	 *
	 * @example
	 * ```apex
	 * new QRY_Generator().fromObject('Contact').addField('AccountId').validateSelectedFieldPaths('SetCondition');
	 * ```
	 */
	public void validateSelectedFieldPaths(String methodName)
	{
		for(Object field : selectFields)
		{
			if(field instanceof String)
			{
				validateFieldPath((String)field, methodName);
			}
		}
	}

	/**
	 * @description Trims a text and checks that the whole of it matches a rule. A blank text is given back trimmed and not
	 * checked.
	 *
	 * @param rule The rule the whole text must match.
	 * @param text The text to check.
	 * @param methodName The method that received the text. The error message names it.
	 *
	 * @return The text, trimmed.
	 *
	 * @throws IllegalArgumentException if the text is longer than 500 characters or does not match the rule.
	 */
	private static String matchWholeText(Pattern rule, String text, String methodName)
	{
		String trimmedText = text?.trim();
		if(String.isNotBlank(trimmedText) && !isShortTextMatching(rule, trimmedText))
		{
			throw newFieldNameNotAllowedException(methodName);
		}
		return trimmedText;
	}

	/**
	 * @description Checks each item of a trimmed list of items joined by commas on its own, so that no pattern reads more
	 * than one item. A comma inside round brackets, as in DISTANCE(Loc__c, GEOLOCATION(1,2), 'mi'), stays inside its item.
	 * A blank text is not checked.
	 *
	 * @param itemRule The rule every item must match.
	 * @param trimmedText The list to check, already trimmed.
	 * @param methodName The method that received the text. The error message names it.
	 *
	 * @return The items of the list, in order, with their spaces. An empty list when the text is blank.
	 *
	 * @throws IllegalArgumentException if the text is longer than 16,000 characters, or an item is empty, is longer than 500
	 * characters or does not match the rule.
	 */
	private static List<String> matchEveryListItem(Pattern itemRule, String trimmedText, String methodName)
	{
		if(String.isBlank(trimmedText))
		{
			return new List<String>();
		}
		if(trimmedText.length() > MAXIMUM_FIELD_LIST_LENGTH)
		{
			throw newFieldNameNotAllowedException(methodName);
		}
		List<String> items = splitListItems(trimmedText);
		for(Integer index = 0; index < items.size(); index++)
		{
			if(!isShortTextMatching(itemRule, items[index]))
			{
				throw newFieldNameNotAllowedException(methodName);
			}
		}
		return items;
	}

	/**
	 * @description Splits a list at each comma that is not inside round brackets. The items keep their spaces. When the
	 * brackets do not close, the rest of the text is one item, which then fails its rule.
	 *
	 * @param text The list to split.
	 *
	 * @return The items, in order. Two commas next to each other give an empty item.
	 */
	private static List<String> splitListItems(String text)
	{
		List<String> items = new List<String>();
		Integer itemStart = 0;
		Integer pieceStart = 0;
		Integer openBrackets = 0;
		for(String piece : text.split(UTIL_String.COMMA, -1))
		{
			Integer pieceEnd = pieceStart + piece.length();
			openBrackets += piece.countMatches('(') - piece.countMatches(')');
			if(openBrackets <= 0)
			{
				items.add(text.substring(itemStart, pieceEnd));
				itemStart = pieceEnd + 1;
				openBrackets = 0;
			}
			pieceStart = pieceEnd + 1;
		}
		if(itemStart <= text.length())
		{
			items.add(text.substring(itemStart));
		}
		return items;
	}

	/**
	 * @description Checks that a text is no longer than 500 characters, not counting the spaces at its ends, and that the
	 * whole of it matches a rule. The length is checked first, so a pattern never reads a long text.
	 *
	 * @param rule The rule the whole text must match.
	 * @param text The text to check.
	 *
	 * @return True when the text is short enough and matches the rule.
	 */
	private static Boolean isShortTextMatching(Pattern rule, String text)
	{
		return text.trim().length() <= MAXIMUM_FIELD_TEXT_LENGTH && rule.matcher(text).matches();
	}

	/**
	 * @description Builds the error for a field text the checks refuse. The message names the method and does not repeat
	 * the text.
	 *
	 * @param methodName The method that received the text.
	 *
	 * @return The error to throw.
	 */
	private static IllegalArgumentException newFieldNameNotAllowedException(String methodName)
	{
		return new IllegalArgumentException(String.format(System.Label.QueryBuilder_FieldName_NotAllowed, new List<Object> {methodName}));
	}

	/**
	 * @description Formats an aggregate function expression for use in HAVING clauses.
	 *
	 * @param aggregate The aggregate function
	 * @param fieldName The field to aggregate
	 *
	 * @return Formatted string like 'SUM(Amount)'
	 */
	public static String formatAggregate(Aggregate aggregate, String fieldName)
	{
		return aggregate.name() + '(' + fieldName + ')';
	}

	/**
	 * @description Generates the SOQL query string.
	 *
	 * @return The generated SOQL string.
	 */
	public String toSoql()
	{
		return buildSoql(null, QRY_Condition.DEFAULT_OPTIONS);
	}

	/**
	 * @description Generates the SOQL query string with bind variables.
	 *
	 * @param registry The bind registry to populate.
	 *
	 * @return The generated SOQL string with bind references.
	 */
	public String toSoql(QRY_BindRegistry registry)
	{
		return buildSoql(registry, QRY_Condition.DEFAULT_OPTIONS);
	}

	/**
	 * @description Generates the SOQL query string with specified options.
	 * The options control condition rendering (e.g., escapeSingleQuotes, wildcardStringsInLikeOperators).
	 *
	 * @param options The SOQL options for rendering conditions.
	 *
	 * @return The generated SOQL string.
	 */
	public String toSoql(QRY_Condition.SoqlOptions options)
	{
		return buildSoql(null, options ?? QRY_Condition.DEFAULT_OPTIONS);
	}

	/**
	 * @description Generates the SOQL query string with bind variables and options.
	 *
	 * @param registry The bind registry to populate.
	 * @param options The SOQL options for rendering conditions.
	 *
	 * @return The generated SOQL string with bind references.
	 */
	public String toSoql(QRY_BindRegistry registry, QRY_Condition.SoqlOptions options)
	{
		return buildSoql(registry, options ?? QRY_Condition.DEFAULT_OPTIONS);
	}

	/**
	 * @description Gets the bind registry used in the last toSoql call.
	 *
	 * @return The bind registry.
	 */
	public QRY_BindRegistry getBindRegistry()
	{
		return bindRegistry;
	}

	/**
	 * @description Returns the name written after FROM: the API name of the object, or the name of a child relationship
	 * for a child query. QRY_Builder reads it to check that the running user may read the object of a query inside an
	 * IN or NOT IN condition.
	 *
	 * @return The name written after FROM, or null when no object is set.
	 */
	public String getObjectName()
	{
		return objectName;
	}

	/**
	 * @description Returns the one condition the WHERE clause holds. QRY_Builder reads it to check the fields that a
	 * query inside an IN or NOT IN condition filters on.
	 *
	 * @return The WHERE condition, or null when the query has no WHERE clause.
	 */
	public QRY_Condition.Evaluable getWhereCondition()
	{
		return whereCondition;
	}

	/**
	 * @description Returns the names of the fields the SELECT clause holds as text. QRY_Builder reads them to check the
	 * field that a query inside an IN or NOT IN condition selects. A field added as a token and a child query are not
	 * returned.
	 *
	 * @return The selected field names; an empty set when no field is selected as text.
	 */
	public Set<String> getSelectedFieldNames()
	{
		Set<String> fieldNames = new Set<String>();
		for(Object field : selectFields)
		{
			if(field instanceof String)
			{
				fieldNames.add((String)field);
			}
		}
		return fieldNames;
	}

	/**
	 * @description Internal method to build the SOQL string.
	 *
	 * @param registry Optional bind registry.
	 * @param options The SOQL options for rendering conditions.
	 *
	 * @return The generated SOQL string.
	 */
	@SuppressWarnings('PMD.NcssMethodCount')
	private String buildSoql(QRY_BindRegistry registry, QRY_Condition.SoqlOptions options)
	{
		if(registry != null)
		{
			this.bindRegistry = registry;
		}

		if(String.isBlank(objectName))
		{
			throw new UTIL_Exceptions.ConfigurationException('Object name is required. Call fromObject() before toSoql().');
		}

		List<String> parts = new List<String>();

		parts.add('SELECT ' + buildSelectClause(registry, options));
		parts.add('FROM ' + objectName);

		String scopeClause = buildScopeClause();
		if(String.isNotBlank(scopeClause))
		{
			parts.add(scopeClause);
		}

		String whereClause = buildWhereClause(registry, options);
		if(String.isNotBlank(whereClause))
		{
			parts.add(whereClause);
		}

		if(enforceFieldLevelSecurity)
		{
			parts.add('WITH USER_MODE');
		}

		String dataCategoryClause = buildDataCategoryClause();
		if(String.isNotBlank(dataCategoryClause))
		{
			if(enforceFieldLevelSecurity)
			{
				throw new UTIL_Exceptions.ConfigurationException(
						'WITH DATA CATEGORY and WITH SECURITY_ENFORCED cannot be used together. '
						+ 'Use withUserMode() for security enforcement with data category queries.'
				);
			}
			parts.add(dataCategoryClause);
		}

		if(!groupByFields.isEmpty())
		{
			String groupByContent = String.join(groupByFields, FIELD_SEPARATOR);
			if(rollupMode)
			{
				groupByContent = 'ROLLUP(' + groupByContent + ')';
			}
			else if(cubeMode)
			{
				groupByContent = 'CUBE(' + groupByContent + ')';
			}
			parts.add('GROUP BY ' + groupByContent);
		}

		String havingClause = buildHavingClause(registry, options);
		if(String.isNotBlank(havingClause))
		{
			parts.add(havingClause);
		}

		String orderByClause = buildOrderByClause();
		if(String.isNotBlank(orderByClause))
		{
			parts.add(orderByClause);
		}

		if(limitCount != null)
		{
			parts.add('LIMIT ' + limitCount);
		}

		if(offsetCount != null)
		{
			parts.add('OFFSET ' + offsetCount);
		}

		String lockClause = buildLockClause();
		if(String.isNotBlank(lockClause))
		{
			parts.add(lockClause);
		}

		if(includeAllRows)
		{
			parts.add('ALL ROWS');
		}

		return String.join(parts, UTIL_String.SPACE);
	}

	/**
	 * @description Builds the list that follows SELECT. An aggregate query gets its aggregates instead of fields. A query with
	 * no fields selects Id. Fields that differ only in case are listed once, and the list is sorted.
	 *
	 * @param registry Optional bind registry.
	 * @param options The SOQL options for rendering conditions.
	 *
	 * @return The SELECT clause content.
	 */
	private String buildSelectClause(QRY_BindRegistry registry, QRY_Condition.SoqlOptions options)
	{
		if(aggregateFunction != null || !aggregateSelections.isEmpty())
		{
			return buildAggregateClause();
		}

		if(includeAllFields)
		{
			selectFields.addAll(UTIL_Set.stringToObject(UTIL_SObjectDescribe.getAllFieldNames(objectName, false)));
		}

		if(selectFields.isEmpty())
		{
			selectFields.add('Id');
		}

		Map<String, String> distinctFieldsMap = new Map<String, String>();

		for(Object field : selectFields)
		{
			String fieldStr = convertFieldToString(field, registry, options);
			fieldStr = fieldStr?.trim();
			distinctFieldsMap.put(fieldStr?.toLowerCase(), fieldStr);
		}

		return UTIL_String.joinSorted(new Set<String>(distinctFieldsMap.values()), FIELD_SEPARATOR);
	}

	/**
	 * @description Turns one entry of the SELECT list into SOQL text. A name is used as it is, and a field token becomes its
	 * API name. A child query is written in round brackets, with its values bound when a bind registry is given.
	 *
	 * @param field The field object.
	 * @param registry Optional bind registry.
	 * @param options The SOQL options for rendering conditions in subqueries.
	 *
	 * @return The string representation.
	 */
	private static String convertFieldToString(Object field, QRY_BindRegistry registry, QRY_Condition.SoqlOptions options)
	{
		if(field instanceof String)
		{
			return (String)field;
		}
		else if(field instanceof SObjectField)
		{
			return UTIL_SObjectDescribe.getCachedFieldDescribe((SObjectField)field)?.name;
		}
		else
		{
			QRY_Generator subquery = (QRY_Generator)field;
			return '(' + (registry != null ? subquery.toSoql(registry, options) : subquery.toSoql(options)) + ')';
		}
	}

	/**
	 * @description Builds the aggregate clause. Emits the legacy single aggregate function (with its
	 * auto-alias) when one is set, then every explicitly aliased aggregate selection in call order,
	 * echoes the GROUP BY expressions into SELECT, and appends any parenthesised SELECT expressions
	 * (e.g. GROUPING(...) or a selected date function). A GROUP BY expression that is also selected
	 * under an explicit alias is echoed only once (the aliased field wins), so a date function
	 * grouped and selected together is not emitted twice. A field-less COUNT() is rejected here when
	 * aliased selections are present: SOQL allows COUNT() only as the sole SELECT entry, so the
	 * combination would otherwise fail at query time with an opaque parser error.
	 *
	 * @return The aggregate SELECT content.
	 *
	 * @throws IllegalArgumentException if a field-less COUNT() is combined with aliased selections.
	 */
	private String buildAggregateClause()
	{
		if(aggregateFunction != null && String.isBlank(aggregateField) && !aggregateSelections.isEmpty())
		{
			throw new IllegalArgumentException('A field-less ' + aggregateFunction.name()
					+ '() cannot be combined with aliased aggregate selections; aggregate a concrete field instead (e.g. COUNT(Id))');
		}
		List<String> parts = new List<String>();
		if(aggregateFunction != null)
		{
			String functionName = aggregateFunction.name();
			String fieldPart = String.isBlank(aggregateField) ? UTIL_String.EMPTY : aggregateField;
			String functionCall = functionName + '(' + fieldPart + ')';

			String alias = UTIL_String.EMPTY;
			if(String.isNotBlank(aggregateField))
			{
				alias = UTIL_String.SPACE + functionName?.toLowerCase() + '_' + aggregateField;
			}

			parts.add(functionCall + alias);
		}
		parts.addAll(aggregateSelections);

		for(String groupExpression : groupByFields)
		{
			if(!isGroupExpressionProjectedWithAlias(groupExpression))
			{
				parts.add(groupExpression);
			}
		}

		for(Object field : selectFields)
		{
			String fieldStr = String.valueOf(field);
			if(fieldStr.contains('(') && !parts.contains(fieldStr))
			{
				parts.add(fieldStr);
			}
		}

		return String.join(parts, FIELD_SEPARATOR);
	}

	/**
	 * @description Determines whether a GROUP BY expression is already in SELECT under an
	 * explicit alias (a SELECT field written as the expression, a space, then the alias). When it is, echoing the
	 * bare GROUP BY expression into SELECT would duplicate it, because the pass that adds parenthesised fields
	 * re-adds the aliased form. A plain grouped field with no separate aliased entry in the field list returns false,
	 * so its GROUP BY echo is preserved unchanged.
	 *
	 * @param groupExpression The GROUP BY expression under test (e.g. CALENDAR_MONTH(CloseDate)).
	 *
	 * @return True when a SELECT field projects this expression under an alias; false otherwise.
	 */
	private Boolean isGroupExpressionProjectedWithAlias(String groupExpression)
	{
		String aliasedPrefix = groupExpression + UTIL_String.SPACE;
		for(Object field : selectFields)
		{
			if(String.valueOf(field).startsWith(aliasedPrefix))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Writes USING SCOPE and the scope value, or returns an empty string when no scope is set.
	 *
	 * @return The USING SCOPE clause or empty string.
	 */
	private String buildScopeClause()
	{
		if(scopeValue == null)
		{
			return UTIL_String.EMPTY;
		}
		return 'USING SCOPE ' + scopeToString(scopeValue);
	}

	/**
	 * @description Converts a Scope enum to its SOQL string.
	 *
	 * @param scope The scope value.
	 *
	 * @return The SOQL string representation.
	 */
	private static String scopeToString(Scope scope)
	{
		return SCOPE_STRINGS.get(scope);
	}

	/**
	 * @description Writes WHERE and the condition. Returns an empty string when there is no condition, or when it writes no
	 * text, as an empty AndCondition does.
	 *
	 * @param registry Optional bind registry.
	 * @param options The SOQL options for rendering conditions.
	 *
	 * @return The WHERE clause or empty string.
	 */
	private String buildWhereClause(QRY_BindRegistry registry, QRY_Condition.SoqlOptions options)
	{
		if(whereCondition == null)
		{
			return UTIL_String.EMPTY;
		}

		String conditionSoql = getConditionSoql(whereCondition, registry, options);
		if(String.isBlank(conditionSoql))
		{
			return UTIL_String.EMPTY;
		}

		return 'WHERE ' + conditionSoql;
	}

	/**
	 * @description Writes HAVING and the condition. Returns an empty string when there is no condition, or when it writes no
	 * text, as an empty AndCondition does.
	 *
	 * @param registry Optional bind registry.
	 * @param options The SOQL options for rendering conditions.
	 *
	 * @return The HAVING clause or empty string.
	 */
	private String buildHavingClause(QRY_BindRegistry registry, QRY_Condition.SoqlOptions options)
	{
		if(havingCondition == null)
		{
			return UTIL_String.EMPTY;
		}

		String conditionSoql = getConditionSoql(havingCondition, registry, options);
		if(String.isBlank(conditionSoql))
		{
			return UTIL_String.EMPTY;
		}

		return 'HAVING ' + conditionSoql;
	}

	/**
	 * @description Writes a condition as SOQL text. With a registry, a condition that supports bind variables stores its
	 * values in the registry and refers to them by name. Without one, every value is written into the text.
	 *
	 * @param condition The condition.
	 * @param registry Optional bind registry.
	 * @param options The SOQL options for rendering conditions.
	 *
	 * @return The SOQL string.
	 */
	private static String getConditionSoql(QRY_Condition.Evaluable condition, QRY_BindRegistry registry, QRY_Condition.SoqlOptions options)
	{
		if(registry != null && condition instanceof QRY_Condition.BindAware)
		{
			return ((QRY_Condition.BindAware)condition).toSoql(registry, options);
		}
		return condition.toSoql(options);
	}

	/**
	 * @description Writes ORDER BY and the sort fields in the order they were added, or returns an empty string when there
	 * are none.
	 *
	 * @return The ORDER BY clause or empty string.
	 */
	private String buildOrderByClause()
	{
		if(orderByList.isEmpty())
		{
			return UTIL_String.EMPTY;
		}

		List<String> orderParts = new List<String>();
		for(OrderBy orderBy : orderByList)
		{
			orderParts.add(orderBy.toSoql());
		}

		return 'ORDER BY ' + String.join(orderParts, FIELD_SEPARATOR);
	}

	/**
	 * @description Builds the locking clause from the current LockMode.
	 *
	 * @return The locking clause or empty string when no lock is set.
	 */
	private String buildLockClause()
	{
		switch on lockMode
		{
			when FOR_UPDATE
			{
				return 'FOR UPDATE';
			}
			when FOR_REFERENCE
			{
				return 'FOR REFERENCE';
			}
			when FOR_VIEW
			{
				return 'FOR VIEW';
			}
			when else
			{
				return UTIL_String.EMPTY;
			}
		}
	}

	/**
	 * @description Writes WITH DATA CATEGORY and every filter, joined with AND, or returns an empty string when there are
	 * none.
	 *
	 * @return The WITH DATA CATEGORY clause or empty string.
	 */
	private String buildDataCategoryClause()
	{
		if(dataCategoryFilters.isEmpty())
		{
			return UTIL_String.EMPTY;
		}

		List<String> filterParts = new List<String>();
		for(DataCategoryFilter filter : dataCategoryFilters)
		{
			filterParts.add(filter.toSoql());
		}

		return 'WITH DATA CATEGORY ' + String.join(filterParts, ' AND ');
	}

	/**
	 * @description Represents one ORDER BY entry.
	 */
	public class OrderBy
	{
		/**
		 * @description The API name of the field to sort by, written into ORDER BY as given.
		 */
		private final String field;

		/**
		 * @description Whether to sort ascending.
		 */
		private Boolean ascending = true;

		/**
		 * @description Whether nulls should be first.
		 */
		private Boolean nullsFirst;

		/**
		 * @description Whether sort direction was explicitly set.
		 */
		private Boolean sortSet = false;

		/**
		 * @description Whether nulls position was explicitly set.
		 */
		private Boolean nullsSet = false;

		/**
		 * @description Sorts by this field name, used as given. No direction and no place for blank values is written until a
		 * setter asks for one, so SOQL's own default order applies. The text may also be a list of sort items (see
		 * validateSortList), which is written as given.
		 *
		 * @param fieldName The field to order by.
		 *
		 * @throws IllegalArgumentException if the text is not blank and is not a list of sort items.
		 */
		public OrderBy(String fieldName)
		{
			validateSortList(fieldName, 'OrderBy');
			field = fieldName;
		}

		/**
		 * @description Constructor with SObjectField.
		 *
		 * @param objectField The field to order by.
		 */
		public OrderBy(SObjectField objectField)
		{
			field = UTIL_SObjectDescribe.getCachedFieldName(objectField);
		}

		/**
		 * @description Writes ASC after the field, so the smallest or earliest value comes first. It replaces descending().
		 *
		 * @return This OrderBy for chaining.
		 */
		public OrderBy ascending()
		{
			this.ascending = true;
			this.sortSet = true;
			return this;
		}

		/**
		 * @description Writes DESC after the field, so the largest or latest value comes first. It replaces ascending().
		 *
		 * @return This OrderBy for chaining.
		 */
		public OrderBy descending()
		{
			this.ascending = false;
			this.sortSet = true;
			return this;
		}

		/**
		 * @description Writes NULLS FIRST, so records whose field is blank come first. It replaces nullsLast().
		 *
		 * @return This OrderBy for chaining.
		 */
		public OrderBy nullsFirst()
		{
			this.nullsFirst = true;
			this.nullsSet = true;
			return this;
		}

		/**
		 * @description Writes NULLS LAST, so records whose field is blank come last. It replaces nullsFirst().
		 *
		 * @return This OrderBy for chaining.
		 */
		public OrderBy nullsLast()
		{
			this.nullsFirst = false;
			this.nullsSet = true;
			return this;
		}

		/**
		 * @description Generates the SOQL ORDER BY string.
		 *
		 * @return The ORDER BY string.
		 */
		public String toSoql()
		{
			String result = field;

			if(sortSet)
			{
				result += ascending ? ' ASC' : ' DESC';
			}

			if(nullsSet)
			{
				result += nullsFirst ? ' NULLS FIRST' : ' NULLS LAST';
			}

			return result;
		}

		/**
		 * @description Returns the field name for this ORDER BY clause.
		 *
		 * @return The field name.
		 */
		public String getField()
		{
			return field;
		}

		/**
		 * @description Returns whether this ORDER BY clause sorts in ascending order.
		 *
		 * @return True if ascending, false if descending.
		 */
		public Boolean isAscending()
		{
			return ascending;
		}

	}

	/**
	 * @description Represents a single WITH DATA CATEGORY filter for one data category group.
	 */
	public class DataCategoryFilter
	{
		/**
		 * @description The API name of the data category group, written into the filter as given.
		 */
		private final String groupName;

		/**
		 * @description How the categories are matched: AT, ABOVE, BELOW, or ABOVE_BELOW, which is written as ABOVE_OR_BELOW.
		 */
		private final DataCategoryOperator operator;

		/**
		 * @description The category name(s).
		 */
		private final List<String> categoryNames;

		/**
		 * @description Holds the values as given, after it checks that the group name and each category name is one name
		 * (see validateFieldPath). It keeps its own copy of the category list, so a name the caller adds to the list later is
		 * never written unchecked. One category is written on its own, and several are written in round brackets.
		 *
		 * @param groupName The data category group name.
		 * @param operator The filtering operator.
		 * @param categoryNames The category name(s).
		 *
		 * @throws IllegalArgumentException if the group name or a category name is not blank and is not one name.
		 */
		public DataCategoryFilter(String groupName, DataCategoryOperator operator, List<String> categoryNames)
		{
			validateFieldPath(groupName, 'DataCategoryFilter');
			for(String categoryName : categoryNames ?? new List<String>())
			{
				validateFieldPath(categoryName, 'DataCategoryFilter');
			}
			this.groupName = groupName;
			this.operator = operator;
			this.categoryNames = categoryNames?.clone();
		}

		/**
		 * @description Generates the SOQL data category filter string.
		 *
		 * @return The data category filter string (e.g., "Geography__c AT USA__c").
		 */
		public String toSoql()
		{
			String operatorString = operator == DataCategoryOperator.ABOVE_BELOW
					? 'ABOVE_OR_BELOW'
					: operator.name();

			if(categoryNames.size() == 1)
			{
				return groupName + UTIL_String.SPACE + operatorString + UTIL_String.SPACE + categoryNames[0];
			}
			return groupName + UTIL_String.SPACE + operatorString + ' (' + String.join(categoryNames, FIELD_SEPARATOR) + ')';
		}

		/**
		 * @description Returns the API name of the data category group, as given to the constructor.
		 *
		 * @return The group name.
		 */
		public String getGroupName()
		{
			return groupName;
		}
	}
}