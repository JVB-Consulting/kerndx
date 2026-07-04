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
 * @date February 2026, July 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.ExcessiveClassLength')
public inherited sharing class QRY_Generator
{
	/**
	 * @description Constant defining the separator for fields in the SELECT clause.
	 */
	@TestVisible
	private static final String FIELD_SEPARATOR = UTIL_String.COMMA + UTIL_String.SPACE;

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
	 * @description Static constants for inner enum values — required because Apex prohibits
	 * referencing inner enum static fields from outer-class instance methods.
	 */
	private static final LockMode LOCK_FOR_UPDATE = LockMode.FOR_UPDATE;
	private static final LockMode LOCK_FOR_REFERENCE = LockMode.FOR_REFERENCE;
	private static final LockMode LOCK_FOR_VIEW = LockMode.FOR_VIEW;

	/**
	 * @description Flag indicating whether all describable fields should be included.
	 */
	private Boolean includeAllFields = false;

	/**
	 * @description The aggregate function to use.
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
	 *
	 * @date July 2026
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
	 *
	 * @date July 2026
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
	 * @description The WHERE condition.
	 */
	private QRY_Condition.Evaluable whereCondition;

	/**
	 * @description The HAVING condition.
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
	 * @description The USING SCOPE value.
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
	 * @description Default constructor.
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
	 * @description Sets the object to query.
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
	 * @description Sets the object to query.
	 *
	 * @param objectApiName The object API name.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator fromObject(String objectApiName)
	{
		this.objectName = objectApiName;
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
	 */
	public QRY_Generator fromX(String objectApiName)
	{
		return fromObject(objectApiName);
	}

	/**
	 * @description Sets the WHERE condition.
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
	 * @description Sets the HAVING condition.
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
	 * @param orderBy The order by specification.
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
	 * @description Adds a field to the GROUP BY clause. Call multiple times for multi-field grouping.
	 *
	 * @param fieldName The field to group by.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator groupBy(String fieldName)
	{
		if(String.isNotBlank(fieldName))
		{
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
	 */
	public QRY_Generator grouping(String fieldName)
	{
		if(String.isNotBlank(fieldName))
		{
			selectFields.add('GROUPING(' + fieldName + ')');
		}
		return this;
	}

	/**
	 * @description Sets the LIMIT.
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
	 * @description Sets the OFFSET.
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
	 * @description Sets the USING SCOPE.
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
	 * @description Adds a WITH DATA CATEGORY filter.
	 *
	 * @param filter The data category filter specification.
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
		this.aggregateFunction = Aggregate.COUNT;
		this.aggregateField = null;
		return this;
	}

	/**
	 * @description Sets a COUNT aggregate on a specific field.
	 *
	 * @param fieldName The field to count.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectCount(String fieldName)
	{
		this.aggregateFunction = Aggregate.COUNT;
		this.aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets an AVG aggregate.
	 *
	 * @param fieldName The field to average.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectAvg(String fieldName)
	{
		this.aggregateFunction = Aggregate.AVG;
		this.aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets a SUM aggregate.
	 *
	 * @param fieldName The field to sum.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectSum(String fieldName)
	{
		this.aggregateFunction = Aggregate.SUM;
		this.aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets a MIN aggregate.
	 *
	 * @param fieldName The field to find minimum.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectMin(String fieldName)
	{
		this.aggregateFunction = Aggregate.MIN;
		this.aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets a MAX aggregate.
	 *
	 * @param fieldName The field to find maximum.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectMax(String fieldName)
	{
		this.aggregateFunction = Aggregate.MAX;
		this.aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Sets a COUNT_DISTINCT aggregate.
	 *
	 * @param fieldName The field to count distinct values.
	 *
	 * @return The current generator for method chaining.
	 */
	public QRY_Generator selectCountDistinct(String fieldName)
	{
		this.aggregateFunction = Aggregate.COUNT_DISTINCT;
		this.aggregateField = fieldName;
		return this;
	}

	/**
	 * @description Adds an explicitly aliased aggregate selection to the SELECT clause. Unlike the single
	 * legacy aggregate (selectCount/selectSum/...), selections accumulate, so one query can fold several
	 * aggregates (e.g. COUNT(Id) plus MIN and MAX of CreatedDate) and read each back by its alias. The
	 * alias is validated as a bare identifier so a caller-supplied alias can never smuggle SOQL into the
	 * clause; the field name is expected to be describe-derived by the caller.
	 *
	 * @param aggregate The aggregate function to apply.
	 * @param fieldName The field to aggregate; must not be blank.
	 * @param alias The result alias to read the value back by; must be a bare identifier, unique across
	 * the aggregate selections.
	 *
	 * @return This generator for chaining.
	 *
	 * @throws IllegalArgumentException if fieldName is blank, the alias is not a bare identifier, or the
	 * alias duplicates an earlier aggregate selection.
	 *
	 * @date July 2026
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
	 * QRY_Function projection alias. Surrounding whitespace is trimmed rather than rejected — SOQL
	 * itself ignores padding around an alias, so padding must not break a caller that worked before
	 * validation existed.
	 *
	 * @param alias The alias to validate.
	 *
	 * @return The validated alias, trimmed of surrounding whitespace.
	 *
	 * @throws IllegalArgumentException if the alias is blank or not a bare identifier.
	 *
	 * @date July 2026
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
	 * @description Builds the SELECT clause.
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

		List<String> distinctFields = distinctFieldsMap.values();
		distinctFields.sort();

		return String.join(distinctFields, FIELD_SEPARATOR);
	}

	/**
	 * @description Converts a field object to string.
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
	 * (e.g. GROUPING(...) or a date-function projection). A GROUP BY expression that is also projected
	 * under an explicit alias is echoed only once — the aliased projection wins — so a date function
	 * grouped and projected together is not emitted twice. A field-less COUNT() is rejected here when
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
	 * @description Determines whether a GROUP BY expression is already projected in SELECT under an
	 * explicit alias (i.e. a SELECT field of the form "<expression> <alias>"). When it is, echoing the
	 * bare GROUP BY expression into SELECT would duplicate it, because the parenthesised-projection pass
	 * re-adds the aliased form. A plain grouped field with no separate aliased projection returns false,
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
	 * @description Builds the USING SCOPE clause.
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
	 * @description Builds the WHERE clause.
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
	 * @description Builds the HAVING clause.
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
	 * @description Gets SOQL string from a condition.
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
	 * @description Builds the ORDER BY clause.
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
	 * @description Builds the WITH DATA CATEGORY clause.
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
	 * @description Represents an ORDER BY specification.
	 */
	public class OrderBy
	{
		/**
		 * @description The field to order by.
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
		 * @description Constructor with field name.
		 *
		 * @param fieldName The field to order by.
		 */
		public OrderBy(String fieldName)
		{
			this.field = fieldName;
		}

		/**
		 * @description Constructor with SObjectField.
		 *
		 * @param objectField The field to order by.
		 */
		public OrderBy(SObjectField objectField)
		{
			this.field = UTIL_SObjectDescribe.getCachedFieldName(objectField);
		}

		/**
		 * @description Sets ascending order.
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
		 * @description Sets descending order.
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
		 * @description Sets nulls first.
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
		 * @description Sets nulls last.
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
		 * @description The data category group name.
		 */
		private final String groupName;

		/**
		 * @description The filtering operator.
		 */
		private final DataCategoryOperator operator;

		/**
		 * @description The category name(s).
		 */
		private final List<String> categoryNames;

		/**
		 * @description Constructs a DataCategoryFilter.
		 *
		 * @param groupName The data category group name.
		 * @param operator The filtering operator.
		 * @param categoryNames The category name(s).
		 */
		public DataCategoryFilter(String groupName, DataCategoryOperator operator, List<String> categoryNames)
		{
			this.groupName = groupName;
			this.operator = operator;
			this.categoryNames = categoryNames;
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
		 * @description Returns the group name for this filter.
		 *
		 * @return The group name.
		 */
		public String getGroupName()
		{
			return groupName;
		}
	}
}