// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Condition infrastructure for building complex SOQL WHERE clauses.
 * Use these classes with QRY_Builder.addCondition() for compound conditions
 * that cannot be expressed with the fluent API alone (e.g., grouped OR conditions).
 *
 * **VISIBILITY**: `global` for subscriber access.
 * - Evaluable interface: base type for all conditions
 * - Operator enum and constants: comparison operators
 * - FieldCondition: field comparisons (=, !=, <, >, LIKE, etc.)
 * - OrCondition/AndCondition: grouping conditions
 *
 * @see QRY_Builder
 * @see QRY_Condition_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * QRY_Condition.Evaluable condition = new QRY_Condition.OrCondition()
 *     .add(new QRY_Condition.FieldCondition(Account.Industry).equals('Tech'))
 *     .add(new QRY_Condition.FieldCondition(Account.Industry).equals('Finance'));
 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
 *     .addCondition(condition)
 *     .toList();
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.ExcessiveClassLength,PMD.ExcessivePublicCount,PMD.NcssTypeCount,PMD.AvoidGlobalModifier')
global inherited sharing class QRY_Condition
{
	/**
	 * @description Default options used for SOQL generation.
	 */
	public static final SoqlOptions DEFAULT_OPTIONS = new SoqlOptions();

	// Private operator shortcuts (workaround for Apex limitation: enum values cannot be referenced from instance methods of inner classes)
	private static final Operator EQUALS = Operator.EQUALS;
	private static final Operator NOT_EQUALS = Operator.NOT_EQUALS;
	private static final Operator LESS_THAN = Operator.LESS_THAN;
	private static final Operator LESS_THAN_OR_EQUAL_TO = Operator.LESS_THAN_OR_EQUAL_TO;
	private static final Operator GREATER_THAN = Operator.GREATER_THAN;
	private static final Operator GREATER_THAN_OR_EQUAL_TO = Operator.GREATER_THAN_OR_EQUAL_TO;
	private static final Operator LIKE_X = Operator.LIKE_X;
	private static final Operator IN_X = Operator.IN_X;
	private static final Operator NOT_IN = Operator.NOT_IN;
	private static final Operator INCLUDES = Operator.INCLUDES;
	private static final Operator EXCLUDES = Operator.EXCLUDES;

	/**
	 * @description Maps each Operator enum value to its SOQL keyword or symbol.
	 */
	private static final Map<Operator, String> OPERATOR_SYNTAX = new Map<Operator, String>
	{
			Operator.EQUALS => '=',
			Operator.NOT_EQUALS => '!=',
			Operator.LESS_THAN => '<',
			Operator.LESS_THAN_OR_EQUAL_TO => '<=',
			Operator.GREATER_THAN => '>',
			Operator.GREATER_THAN_OR_EQUAL_TO => '>=',
			Operator.LIKE_X => 'LIKE',
			Operator.IN_X => 'IN',
			Operator.NOT_IN => 'NOT IN',
			Operator.INCLUDES => 'INCLUDES',
			Operator.EXCLUDES => 'EXCLUDES'
	};

	/**
	 * @description Operators that compare a field against a single scalar value (FieldCondition).
	 */
	private static final Set<Operator> SCALAR_OPERATORS = new Set<Operator>
	{
			Operator.EQUALS,
			Operator.NOT_EQUALS,
			Operator.LESS_THAN,
			Operator.LESS_THAN_OR_EQUAL_TO,
			Operator.GREATER_THAN,
			Operator.GREATER_THAN_OR_EQUAL_TO,
			Operator.LIKE_X
	};

	/**
	 * @description Operators that compare a field against a collection of values (SetCondition).
	 */
	private static final Set<Operator> COLLECTION_OPERATORS = new Set<Operator>
	{
			Operator.IN_X,
			Operator.NOT_IN,
			Operator.INCLUDES,
			Operator.EXCLUDES
	};

	/**
	 * @description SOQL comparison operators used to build query conditions.
	 *
	 * | Operator                 | SOQL     | Description                    |
	 * |--------------------------|----------|--------------------------------|
	 * | EQUALS                   | =        | Equal to                       |
	 * | NOT_EQUALS               | !=       | Not equal to                   |
	 * | LESS_THAN                | <        | Less than                      |
	 * | LESS_THAN_OR_EQUAL_TO    | <=       | Less than or equal to          |
	 * | GREATER_THAN             | >        | Greater than                   |
	 * | GREATER_THAN_OR_EQUAL_TO | >=       | Greater than or equal to       |
	 * | LIKE_X                   | LIKE     | Pattern matching               |
	 * | IN_X                     | IN       | Value in set                   |
	 * | NOT_IN                   | NOT IN   | Value not in set               |
	 * | INCLUDES                 | INCLUDES | Multi-select picklist includes |
	 * | EXCLUDES                 | EXCLUDES | Multi-select picklist excludes |
	 *
	 * @since 1.0
	 */
	global enum Operator
	{
		/**
		 * @description Equal to (=)
		 */
		EQUALS,
		/**
		 * @description Multi-select picklist excludes
		 */
		EXCLUDES,
		/**
		 * @description Greater than (>)
		 */
		GREATER_THAN,
		/**
		 * @description Greater than or equal to (>=)
		 */
		GREATER_THAN_OR_EQUAL_TO,
		/**
		 * @description Multi-select picklist includes
		 */
		INCLUDES,
		/**
		 * @description Value in set (IN)
		 */
		IN_X,
		/**
		 * @description Less than (<)
		 */
		LESS_THAN,
		/**
		 * @description Less than or equal to (<=)
		 */
		LESS_THAN_OR_EQUAL_TO,
		/**
		 * @description Pattern matching (LIKE)
		 */
		LIKE_X,
		/**
		 * @description Not equal to (!=)
		 */
		NOT_EQUALS,
		/**
		 * @description Value not in set (NOT IN)
		 */
		NOT_IN
	}

	/**
	 * @description Options for SOQL generation.
	 *
	 * @since 1.0
	 */
	global class SoqlOptions
	{
		/**
		 * @description Whether to escape single quotes in string values.
		 */
		public Boolean escapeSingleQuotes = true;

		/**
		 * @description Whether to automatically add wildcards to LIKE operator strings.
		 */
		public Boolean wildcardStringsInLikeOperators = false;
	}

	/**
	 * @description Interface for condition classes. Pass to QRY_Builder.addCondition().
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * interface value = instance.Evaluable;
	 * ```
	 */
	global virtual interface Evaluable
	{
		/**
		 * @description Converts the condition to a SOQL query string.
		 *
		 * @return A valid SOQL query string.
		 */
		String toSoql();

		/**
		 * @description Converts the condition to a SOQL query string using specific options.
		 *
		 * @param options The SOQL options for customization.
		 *
		 * @return A valid SOQL query string.
		 */
		String toSoql(SoqlOptions options);
	}

	/**
	 * @description Interface for conditions that support bind variable generation.
	 */
	public interface BindAware
	{
		/**
		 * @description Converts the condition to a SOQL string with bind variable references.
		 *
		 * @param registry The bind registry to register values in.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		String toSoql(QRY_BindRegistry registry);

		/**
		 * @description Converts the condition to a SOQL string with bind variable references and options.
		 *
		 * @param registry The bind registry to register values in.
		 * @param options The SOQL options for customization.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		String toSoql(QRY_BindRegistry registry, SoqlOptions options);
	}

	/**
	 * @description Interface for condition containers that support adding nested conditions.
	 * Extends Evaluable so groups can be passed to QRY_Builder.addCondition().
	 *
	 * @since 1.0
	 */
	global interface Nestable extends Evaluable
	{
		/**
		 * @description Adds a condition to this group.
		 *
		 * @param condition The condition to add.
		 *
		 * @return The updated Nestable with the new condition added.
		 *
		 * @since 1.0
		 */
		Nestable add(Evaluable condition);
	}

	/**
	 * @description Converts an Operator enum to its string equivalent used in SOQL queries.
	 *
	 * @param operator The Operator enum to convert
	 *
	 * @return The corresponding string representation
	 */
	public static String operatorToString(Operator operator)
	{
		return OPERATOR_SYNTAX.get(operator);
	}

	/**
	 * @description Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(
	 *     'Status__c', QRY_Condition.Operator.EQUALS, 'Active'
	 * );
	 * ```
	 */
	global virtual class FieldCondition implements Evaluable, BindAware
	{
		/**
		 * @description The field that the condition applies to.
		 */
		public String field {get; private set;}

		/**
		 * @description The operator for the condition.
		 */
		public Operator operator {get; private set;}

		/**
		 * @description The value to compare against the field.
		 */
		public Object value {get; private set;}

		/**
		 * @description Default constructor for FieldCondition.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public FieldCondition()
		{
		}

		/**
		 * @description Constructor for FieldCondition with a specified field.
		 *
		 * @param fieldName The field to apply the condition to.
		 */
		public FieldCondition(String fieldName)
		{
			this.field(fieldName);
		}

		/**
		 * @description Constructor for FieldCondition with a specified SObjectField.
		 *
		 * @param objectField The ObjectField to apply the condition to.
		 */
		public FieldCondition(SObjectField objectField)
		{
			this.field(objectField);
		}

		/**
		 * @description Constructor for FieldCondition with a specified field and value.
		 *
		 * @param fieldName The field to apply the condition to.
		 * @param fieldValue The value to compare against the field.
		 */
		public FieldCondition(String fieldName, Object fieldValue)
		{
			this(fieldName, EQUALS, fieldValue);
		}

		/**
		 * @description Constructor for FieldCondition with a specified field and value.
		 *
		 * @param objectField The field to apply the condition to.
		 * @param fieldValue The value to compare against the field.
		 */
		public FieldCondition(SObjectField objectField, Object fieldValue)
		{
			this(objectField, EQUALS, fieldValue);
		}

		/**
		 * @description Constructor for FieldCondition with a specified field, operator, and value.
		 *
		 * @param fieldName The field to apply the condition to.
		 * @param fieldOperator The operator for the condition.
		 * @param fieldValue The value to compare against the field.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition('myName', new Operator(), 'value');
		 * ```
		 */
		global FieldCondition(String fieldName, Operator fieldOperator, Object fieldValue)
		{
			this.field(fieldName);
			if(fieldOperator != null)
			{
				this.setOperation(fieldOperator, fieldValue);
			}
		}

		/**
		 * @description Constructor for FieldCondition with a specified field, operator, and value.
		 *
		 * @param objectField The field to apply the condition to.
		 * @param fieldOperator The operator for the condition.
		 * @param fieldValue The value to compare against the field.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition(Account.Name, new Operator(), 'value');
		 * ```
		 */
		global FieldCondition(SObjectField objectField, Operator fieldOperator, Object fieldValue)
		{
			this.field(objectField);
			if(fieldOperator != null)
			{
				this.setOperation(fieldOperator, fieldValue);
			}
		}

		/**
		 * @description Sets the field for the condition.
		 *
		 * @param objectField The SObjectField to use for the condition.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		public FieldCondition field(SObjectField objectField)
		{
			return field(UTIL_SObjectDescribe.getCachedFieldName(objectField));
		}

		/**
		 * @description Sets the field for the condition.
		 *
		 * @param fieldName The field to apply the condition to.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		public FieldCondition field(String fieldName)
		{
			if(String.isBlank(fieldName))
			{
				throw new IllegalArgumentException('The field name provided is empty');
			}
			this.field = fieldName.trim();
			return this;
		}

		/**
		 * @description Sets the condition to be an EQUALS comparison.
		 *
		 * @param compareValue The value to compare against the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		@SuppressWarnings('PMD.OverrideBothEqualsAndHashcode,ApexEqualsHashCodeNotPaired')
		public FieldCondition equals(Object compareValue)
		{
			return setOperation(EQUALS, compareValue);
		}

		/**
		 * @description Sets the condition to be a NOT_EQUALS comparison.
		 *
		 * @param compareValue The value to compare against the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		public FieldCondition notEquals(Object compareValue)
		{
			return setOperation(NOT_EQUALS, compareValue);
		}

		/**
		 * @description Sets the condition to be a LESS_THAN comparison.
		 *
		 * @param compareValue The value to compare against the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		public FieldCondition lessThan(Object compareValue)
		{
			return setOperation(LESS_THAN, compareValue);
		}

		/**
		 * @description Sets the condition to be a LESS_THAN_OR_EQUAL_TO comparison.
		 *
		 * @param compareValue The value to compare against the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		public FieldCondition lessThanOrEqualTo(Object compareValue)
		{
			return setOperation(LESS_THAN_OR_EQUAL_TO, compareValue);
		}

		/**
		 * @description Sets the condition to be a GREATER_THAN comparison.
		 *
		 * @param compareValue The value to compare against the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		public FieldCondition greaterThan(Object compareValue)
		{
			return setOperation(GREATER_THAN, compareValue);
		}

		/**
		 * @description Sets the condition to be a GREATER_THAN_OR_EQUAL_TO comparison.
		 *
		 * @param compareValue The value to compare against the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		public FieldCondition greaterThanOrEqualTo(Object compareValue)
		{
			return setOperation(GREATER_THAN_OR_EQUAL_TO, compareValue);
		}

		/**
		 * @description Sets the condition to be a LIKE comparison.
		 *
		 * @param compareValue The value to compare against the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		public FieldCondition likeX(Object compareValue)
		{
			return setOperation(LIKE_X, compareValue);
		}

		/**
		 * @description Sets the operator and value for the condition.
		 *
		 * @param fieldOperator The operator for the condition.
		 * @param fieldValue The value to compare against the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 */
		private FieldCondition setOperation(Operator fieldOperator, Object fieldValue)
		{
			if(!SCALAR_OPERATORS.contains(fieldOperator))
			{
				throw new IllegalArgumentException('illegal operator: ' + fieldOperator);
			}
			this.operator = fieldOperator;
			this.value = fieldValue;
			return this;
		}

		/**
		 * @description Converts the field condition to a SOQL string representation.
		 *
		 * @return The SOQL representation of the condition.
		 */
		public String toSoql()
		{
			return toSoql(DEFAULT_OPTIONS);
		}

		/**
		 * @description Converts the field condition to a SOQL string representation.
		 *
		 * @param options SOQL options to apply.
		 *
		 * @return The SOQL representation of the condition.
		 */
		public String toSoql(SoqlOptions options)
		{
			Object manipulated = applyLikeWildcards(value, options);
			return field + UTIL_String.SPACE + operatorToString(operator) + UTIL_String.SPACE + toLiteral(manipulated, options);
		}

		/**
		 * @description Converts the condition to a SOQL string with bind variable references.
		 *
		 * @param registry The bind registry to register values in.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		public String toSoql(QRY_BindRegistry registry)
		{
			return toSoql(registry, DEFAULT_OPTIONS);
		}

		/**
		 * @description Converts the condition to a SOQL string with bind variable references and options.
		 *
		 * @param registry The bind registry to register values in.
		 * @param options The SOQL options for customization.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		public String toSoql(QRY_BindRegistry registry, SoqlOptions options)
		{
			Object manipulated = applyLikeWildcards(value, options);
			String valueString = getBindOrLiteral(manipulated, registry, options);
			return field + UTIL_String.SPACE + operatorToString(operator) + UTIL_String.SPACE + valueString;
		}

		/**
		 * @description Applies wildcard characters to LIKE operator values when configured.
		 *
		 * @param fieldValue The value to potentially wrap with wildcards.
		 * @param options The SOQL options.
		 *
		 * @return The value with wildcards if applicable, otherwise unchanged.
		 */
		private Object applyLikeWildcards(Object fieldValue, SoqlOptions options)
		{
			if
			(
					fieldValue != null &&
					fieldValue instanceof String &&
					operator == LIKE_X &&
					options.wildcardStringsInLikeOperators
			)
			{
				return UTIL_String.wrapWith(((String)fieldValue), '%');
			}
			return fieldValue;
		}

		/**
		 * @description Determines whether a value should be bound or kept as a literal.
		 *
		 * @param bindValue The value to evaluate
		 * @param registry The bind registry for registering bind values
		 * @param options The SOQL options for formatting literals
		 *
		 * @return The bind reference (:b1) or literal string
		 */
		private String getBindOrLiteral(Object bindValue, QRY_BindRegistry registry, SoqlOptions options)
		{
			if(bindValue == null)
			{
				return 'null';
			}

			if(bindValue instanceof Evaluable)
			{
				return ((Evaluable)bindValue).toSoql(options);
			}

			return registry.register(bindValue);
		}
	}

	/**
	 * @description Represents a condition with a field, operator, and set of values for IN/NOT IN/INCLUDES/EXCLUDES.
	 */
	@SuppressWarnings('PMD.CyclomaticComplexity')
	public inherited sharing class SetCondition implements Evaluable, BindAware
	{
		/**
		 * @description The field name that this condition applies to.
		 */
		public String field {get; private set;}

		/**
		 * @description The operator to be used in the condition.
		 */
		public Operator operator {get; private set;}

		/**
		 * @description The list of values to be compared against the field.
		 */
		public List<Object> values {get; private set;}

		/**
		 * @description The SOQL builder instance used for generating subqueries.
		 */
		public QRY_Generator builder {get; private set;}

		/**
		 * @description Default constructor.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public SetCondition()
		{
		}

		/**
		 * @description Constructor to initialize with a specific field.
		 *
		 * @param fieldName The field name for the condition.
		 */
		public SetCondition(String fieldName)
		{
			this.field(fieldName);
		}

		/**
		 * @description Constructor to initialize with a specific field, operator, and collection of values.
		 *
		 * @param fieldName The field name for the condition.
		 * @param fieldOperator The SOQL operator to apply.
		 * @param fieldValue The collection of values to compare against.
		 */
		public SetCondition(String fieldName, Operator fieldOperator, Object fieldValue)
		{
			this.field(fieldName);
			String className = UTIL_System.getRuntimeTypeName(fieldValue);

			if(className?.startsWith('Set<') == true)
			{
				this.setOperation(fieldOperator, new List<Object>((Set<Object>)fieldValue));
			}
			else if(className?.startsWith('List<') == true)
			{
				this.setOperation(fieldOperator, (List<Object>)fieldValue);
			}
			else
			{
				throw new IllegalArgumentException('Illegal argument: value provided is not a collection');
			}
		}

		/**
		 * @description Constructor for SetCondition with a field name, operator, and list of values.
		 *
		 * @param fieldName The field name for the condition.
		 * @param fieldOperator The operator to apply.
		 * @param fieldValues The list of values to use in the condition.
		 */
		public SetCondition(String fieldName, Operator fieldOperator, List<Object> fieldValues)
		{
			this.field(fieldName);
			this.setOperation(fieldOperator, fieldValues);
		}

		/**
		 * @description Constructor for SetCondition with a field name, operator, and set of values.
		 *
		 * @param fieldName The field name for the condition.
		 * @param fieldOperator The operator to apply.
		 * @param fieldValues The set of values to use in the condition.
		 */
		public SetCondition(String fieldName, Operator fieldOperator, Set<Object> fieldValues)
		{
			this.field(fieldName);
			this.setOperation(fieldOperator, new List<Object>(fieldValues));
		}

		/**
		 * @description Constructor for SetCondition with a field name, operator, and SOQL builder.
		 *
		 * @param fieldName The field name for the condition.
		 * @param fieldOperator The operator to apply.
		 * @param queryBuilder The SOQL builder to use for generating the subquery.
		 */
		public SetCondition(String fieldName, Operator fieldOperator, QRY_Generator queryBuilder)
		{
			this.field(fieldName);
			this.setOperation(fieldOperator, queryBuilder);
		}

		/**
		 * @description Sets the field for the condition.
		 *
		 * @param fieldName The api name of the field.
		 *
		 * @return Current setCondition.
		 */
		public SetCondition field(String fieldName)
		{
			if(String.isBlank(fieldName))
			{
				throw new IllegalArgumentException('Illegal argument: field is empty');
			}
			this.field = fieldName?.trim();
			return this;
		}

		/**
		 * @description Method to include specific values in a set operation.
		 *
		 * @param fieldValues The values to include in the condition.
		 *
		 * @return The SetCondition instance for method chaining.
		 */
		public SetCondition includes(List<Object> fieldValues)
		{
			return setOperation(INCLUDES, fieldValues);
		}

		/**
		 * @description Method to exclude specific values in a set operation.
		 *
		 * @param fieldValues The values to exclude from the condition.
		 *
		 * @return The SetCondition instance for method chaining.
		 */
		public SetCondition excludes(List<Object> fieldValues)
		{
			return setOperation(EXCLUDES, fieldValues);
		}

		/**
		 * @description Set the operation for 'IN' condition with a list of values.
		 *
		 * @param fieldValues The values to compare in the 'IN' operation.
		 *
		 * @return The SetCondition instance.
		 */
		public SetCondition inX(List<Object> fieldValues)
		{
			return setOperation(IN_X, fieldValues);
		}

		/**
		 * @description Set the operation for 'NOT IN' condition with a list of values.
		 *
		 * @param fieldValues The values to compare in the 'NOT IN' operation.
		 *
		 * @return The SetCondition instance.
		 */
		public SetCondition notIn(List<Object> fieldValues)
		{
			return setOperation(NOT_IN, fieldValues);
		}

		/**
		 * @description Sets the SOQL builder for INCLUDES subquery.
		 *
		 * @param queryBuilder The SOQL builder to use.
		 *
		 * @return The SetCondition instance for method chaining.
		 */
		public SetCondition includes(QRY_Generator queryBuilder)
		{
			return setOperation(INCLUDES, queryBuilder);
		}

		/**
		 * @description Sets the SOQL builder for EXCLUDES subquery.
		 *
		 * @param queryBuilder The SOQL builder to use.
		 *
		 * @return The SetCondition instance for method chaining.
		 */
		public SetCondition excludes(QRY_Generator queryBuilder)
		{
			return setOperation(EXCLUDES, queryBuilder);
		}

		/**
		 * @description Sets the SOQL builder for IN subquery.
		 *
		 * @param queryBuilder The SOQL builder to use.
		 *
		 * @return The SetCondition instance for method chaining.
		 */
		public SetCondition inX(QRY_Generator queryBuilder)
		{
			return setOperation(IN_X, queryBuilder);
		}

		/**
		 * @description Sets the SOQL builder for NOT IN subquery.
		 *
		 * @param queryBuilder The SOQL builder to use.
		 *
		 * @return The SetCondition instance for method chaining.
		 */
		public SetCondition notIn(QRY_Generator queryBuilder)
		{
			return setOperation(NOT_IN, queryBuilder);
		}

		/**
		 * @description Method to set the operator for the condition with values.
		 *
		 * @param fieldOperator The operator to use in the condition.
		 * @param fieldValues The list of values to use.
		 *
		 * @return The SetCondition instance.
		 */
		private SetCondition setOperation(Operator fieldOperator, List<Object> fieldValues)
		{
			if(fieldValues == null || fieldValues.isEmpty())
			{
				throw new IllegalArgumentException('illegal argument: values is empty');
			}
			this.values = fieldValues;
			return setOperator(fieldOperator);
		}

		/**
		 * @description Method to set the operator for the condition with a builder.
		 *
		 * @param fieldOperator The operator to use in the condition.
		 * @param queryBuilder The builder to use.
		 *
		 * @return The SetCondition instance.
		 */
		private SetCondition setOperation(Operator fieldOperator, QRY_Generator queryBuilder)
		{
			if(queryBuilder == null)
			{
				throw new IllegalArgumentException('illegal argument: builder is null');
			}
			this.builder = queryBuilder;
			return setOperator(fieldOperator);
		}

		/**
		 * @description Sets the operator and validates it.
		 *
		 * @param fieldOperator The operator to set.
		 *
		 * @return The SetCondition instance.
		 */
		private SetCondition setOperator(Operator fieldOperator)
		{
			if(!COLLECTION_OPERATORS.contains(fieldOperator))
			{
				throw new IllegalArgumentException('illegal operator: ' + fieldOperator);
			}
			this.operator = fieldOperator;
			return this;
		}

		/**
		 * @description Converts the SetCondition to a valid SOQL string.
		 *
		 * @return The SOQL string representation of the condition.
		 */
		public String toSoql()
		{
			return toSoql(DEFAULT_OPTIONS);
		}

		/**
		 * @description Converts the SetCondition to a valid SOQL string with options.
		 *
		 * @param options SOQL options to customize the output.
		 *
		 * @return The SOQL string representation of the condition.
		 */
		public String toSoql(SoqlOptions options)
		{
			if(operator == null)
			{
				throw new UTIL_Exceptions.IllegalStateException
						(
								'Illegal state! One of the following operations must be invoked on SetCondition prior to invoke toSoql(): (includes|excludes|in|notIn)'
						);
			}

			String insideParams = null;

			if(builder == null)
			{
				insideParams = UTIL_String.join(toLiteralList(values), UTIL_String.COMMA);
			}
			else
			{
				insideParams = builder.toSoql(DEFAULT_OPTIONS);
			}

			return field + UTIL_String.SPACE + operatorToString(operator) + ' (' + insideParams + ')';
		}

		/**
		 * @description Converts the condition to a SOQL string with bind variable references.
		 *
		 * @param registry The bind registry to register values in.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		public String toSoql(QRY_BindRegistry registry)
		{
			return toSoql(registry, DEFAULT_OPTIONS);
		}

		/**
		 * @description Converts the condition to a SOQL string with bind variable references and options.
		 *
		 * @param registry The bind registry to register values in.
		 * @param options The SOQL options for customization.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		public String toSoql(QRY_BindRegistry registry, SoqlOptions options)
		{
			if(operator == null)
			{
				throw new UTIL_Exceptions.IllegalStateException
						(
								'Illegal state! One of the following operations must be invoked on SetCondition prior to invoke toSoql(): (includes|excludes|in|notIn)'
						);
			}

			if(builder != null)
			{
				String subQuery = builder.toSoql(registry, DEFAULT_OPTIONS);
				return field + UTIL_String.SPACE + operatorToString(operator) + ' (' + subQuery + ')';
			}

			Boolean canBind = isBindableCollection(values) && operator != INCLUDES && operator != EXCLUDES;

			if(!canBind)
			{
				String insideParams = UTIL_String.join(toLiteralList(values), UTIL_String.COMMA);
				return field + UTIL_String.SPACE + operatorToString(operator) + ' (' + insideParams + ')';
			}

			Object bindValue = getTypedCollection(values);
			String bindRef = registry.registerCollection(bindValue);
			return field + UTIL_String.SPACE + operatorToString(operator) + UTIL_String.SPACE + bindRef;
		}

		/**
		 * @description Determines if a collection can be safely bound in Database.queryWithBinds.
		 *
		 * @param collection The collection to check for bindability.
		 *
		 * @return True if the collection can be safely bound.
		 */
		private Boolean isBindableCollection(List<Object> collection)
		{
			Boolean hasId = false;
			Boolean hasString = false;
			Boolean hasSObject = false;

			for(Object element : collection)
			{
				if(element == null)
				{
					continue;
				}

				if(element instanceof SObject)
				{
					hasSObject = true;
				}
				else
				{
					String typeName = UTIL_System.getRuntimeTypeName(element);
					if('Id'.equalsIgnoreCase(typeName))
					{
						hasId = true;
					}
					else if('String'.equalsIgnoreCase(typeName))
					{
						hasString = true;
					}
					else
					{
						return false;
					}
				}

				if(hasSObject && (hasId || hasString))
				{
					return false;
				}
				if(hasId && hasString)
				{
					return false;
				}
			}

			return hasId || hasString || hasSObject;
		}

		/**
		 * @description Casts a generic List<Object> to a strict List<Id>, List<String>, or List<SObject>.
		 * Checks the list's runtime type first to avoid the Id/String ambiguity that occurs when
		 * sampling individual elements (Apex `instanceof Id` returns true for any 15/18-char String).
		 *
		 * @param inputList The original list of values.
		 *
		 * @return The strictly typed list.
		 */
		private Object getTypedCollection(List<Object> inputList)
		{
			String listTypeName = UTIL_System.getRuntimeTypeName(inputList);

			if(listTypeName == 'List<String>' || listTypeName == 'List<Id>')
			{
				return inputList;
			}

			Object sample = null;
			for(Object itemValue : inputList)
			{
				if(itemValue != null)
				{
					sample = itemValue;
					break;
				}
			}

			if(sample instanceof SObject)
			{
				List<SObject> castList = new List<SObject>();
				for(Object itemValue : inputList)
				{
					castList.add((SObject)itemValue);
				}
				return castList;
			}

			if('Id'.equalsIgnoreCase(UTIL_System.getRuntimeTypeName(sample)))
			{
				List<Id> castList = new List<Id>();
				for(Object itemValue : inputList)
				{
					castList.add((Id)itemValue);
				}
				return castList;
			}

			List<String> castList = new List<String>();
			for(Object itemValue : inputList)
			{
				castList.add((String)itemValue);
			}
			return castList;
		}
	}

	/**
	 * @description Abstract base class for condition groups (AND/OR).
	 */
	public abstract class ConditionGroup implements Nestable, BindAware
	{
		/**
		 * @description The list of conditions in this group.
		 */
		public List<Evaluable> conditions {get; private set;}

		/**
		 * @description The separator (AND/OR) used to combine conditions.
		 */
		private final String separator;

		/**
		 * @description Constructor for initializing a new ConditionGroup.
		 *
		 * @param groupSeparator The separator (AND/OR) used to combine conditions.
		 */
		public ConditionGroup(String groupSeparator)
		{
			this.separator = groupSeparator;
			this.conditions = new List<Evaluable>();
		}

		/**
		 * @description Adds a new condition to the current group.
		 *
		 * @param condition The condition to add.
		 *
		 * @return The current Nestable with the added condition.
		 */
		public virtual Nestable add(Evaluable condition)
		{
			if(condition != null)
			{
				this.conditions.add(condition);
			}
			return this;
		}

		/**
		 * @description Converts the condition group to a SOQL string.
		 *
		 * @return A valid SOQL query string.
		 */
		public virtual String toSoql()
		{
			return toSoql(DEFAULT_OPTIONS);
		}

		/**
		 * @description Converts the condition group to a SOQL string using specific options.
		 *
		 * @param options The SOQL options for customization.
		 *
		 * @return A valid SOQL query string.
		 */
		public virtual String toSoql(SoqlOptions options)
		{
			List<String> soqlParts = new List<String>();

			if(conditions != null)
			{
				for(Evaluable condition : conditions)
				{
					String conditionSoql = condition.toSoql(options);
					if(String.isNotBlank(conditionSoql))
					{
						soqlParts.add(conditionSoql);
					}
				}
			}

			return joinConditions(soqlParts);
		}

		/**
		 * @description Converts the condition group to a SOQL string with bind variables.
		 *
		 * @param registry The bind registry to register values in.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		public String toSoql(QRY_BindRegistry registry)
		{
			return toSoql(registry, DEFAULT_OPTIONS);
		}

		/**
		 * @description Converts the condition group to a SOQL string with bind variables and options.
		 *
		 * @param registry The bind registry to register values in.
		 * @param options The SOQL options for customization.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		public String toSoql(QRY_BindRegistry registry, SoqlOptions options)
		{
			List<String> soqlParts = new List<String>();

			if(conditions != null)
			{
				for(Evaluable condition : conditions)
				{
					String conditionSoql = getConditionSoql(condition, registry, options);
					if(String.isNotBlank(conditionSoql))
					{
						soqlParts.add(conditionSoql);
					}
				}
			}

			return joinConditions(soqlParts);
		}

		/**
		 * @description Joins condition SOQL parts with the group separator, wrapped in parentheses.
		 *
		 * @param soqlParts The list of condition SOQL strings.
		 *
		 * @return The joined SOQL string, or empty if no parts.
		 */
		private String joinConditions(List<String> soqlParts)
		{
			if(soqlParts.isEmpty())
			{
				return UTIL_String.EMPTY;
			}
			return '(' + String.join(soqlParts, UTIL_String.SPACE + separator + UTIL_String.SPACE) + ')';
		}

		/**
		 * @description Helper method to get SOQL string from a condition.
		 *
		 * @param condition The condition to convert.
		 * @param registry The bind registry.
		 * @param options The SOQL options.
		 *
		 * @return The SOQL string for the condition.
		 */
		private String getConditionSoql(Evaluable condition, QRY_BindRegistry registry, SoqlOptions options)
		{
			if(condition instanceof BindAware)
			{
				return ((BindAware)condition).toSoql(registry, options);
			}
			return condition.toSoql(options);
		}
	}

	/**
	 * @description Represents a SOQL "AND" condition group.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Condition.AndCondition group = new QRY_Condition.AndCondition();
	 * group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
	 * group.add(new QRY_Condition.FieldCondition('Type__c', QRY_Condition.Operator.EQUALS, 'Customer'));
	 * ```
	 */
	global inherited sharing class AndCondition extends ConditionGroup
	{
		/**
		 * @description Constructor for creating an AND condition group.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.AndCondition instance = new QRY_Condition.AndCondition();
		 * ```
		 */
		global AndCondition()
		{
			super('AND');
		}

		/**
		 * @description Adds a condition to this AND group.
		 *
		 * @param condition The condition to add.
		 *
		 * @return The current Nestable with the added condition.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.AndCondition group = new QRY_Condition.AndCondition();
		 * group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
		 * group.add(new QRY_Condition.FieldCondition('Type__c', QRY_Condition.Operator.EQUALS, 'Customer'));
		 * ```
		 */
		global override Nestable add(Evaluable condition)
		{
			return super.add(condition);
		}
	}

	/**
	 * @description Represents a SOQL "OR" condition group.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Condition.OrCondition group = new QRY_Condition.OrCondition();
	 * group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
	 * group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Pending'));
	 * ```
	 */
	global inherited sharing class OrCondition extends ConditionGroup
	{
		/**
		 * @description Constructor for creating an OR condition group.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.OrCondition instance = new QRY_Condition.OrCondition();
		 * ```
		 */
		global OrCondition()
		{
			super('OR');
		}

		/**
		 * @description Adds a condition to this OR group.
		 *
		 * @param condition The condition to add.
		 *
		 * @return The current Nestable with the added condition.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.OrCondition group = new QRY_Condition.OrCondition();
		 * group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
		 * group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Pending'));
		 * ```
		 */
		global override Nestable add(Evaluable condition)
		{
			return super.add(condition);
		}
	}

	/**
	 * @description Represents a SOQL "NOT" condition.
	 */
	public inherited sharing class NotCondition implements Evaluable, BindAware
	{
		/**
		 * @description The condition to be negated in the SOQL query.
		 */
		public Evaluable condition {get; private set;}

		/**
		 * @description Default constructor for NotCondition.
		 */
		public NotCondition()
		{
			this(null);
		}

		/**
		 * @description Constructor for NotCondition with a specified condition to negate.
		 *
		 * @param innerCondition The condition to negate.
		 */
		public NotCondition(Evaluable innerCondition)
		{
			this.condition = innerCondition;
		}

		/**
		 * @description Adds a condition to be negated by this NotCondition.
		 *
		 * @param innerCondition The condition to negate.
		 *
		 * @return The NotCondition instance.
		 */
		public NotCondition add(Evaluable innerCondition)
		{
			this.condition = innerCondition;
			return this;
		}

		/**
		 * @description Converts the NOT condition to a SOQL string representation.
		 *
		 * @return The SOQL representation of the NOT condition.
		 */
		public String toSoql()
		{
			return toSoql(DEFAULT_OPTIONS);
		}

		/**
		 * @description Converts the NOT condition to a SOQL string representation.
		 *
		 * @param options The SOQL options to apply.
		 *
		 * @return The SOQL representation of the NOT condition.
		 */
		public String toSoql(SoqlOptions options)
		{
			String soql = UTIL_String.EMPTY;

			if(condition != null)
			{
				soql += '(NOT ' + condition.toSoql(options) + ')';
			}

			return soql;
		}

		/**
		 * @description Converts the NOT condition to a SOQL string with bind variable references.
		 *
		 * @param registry The bind registry to register values in.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		public String toSoql(QRY_BindRegistry registry)
		{
			return toSoql(registry, DEFAULT_OPTIONS);
		}

		/**
		 * @description Converts the NOT condition to a SOQL string with bind variable references and options.
		 *
		 * @param registry The bind registry to register values in.
		 * @param options The SOQL options for customization.
		 *
		 * @return A SOQL condition string with bind variable references.
		 */
		public String toSoql(QRY_BindRegistry registry, SoqlOptions options)
		{
			String soql = UTIL_String.EMPTY;

			if(condition != null)
			{
				String innerSoql;
				if(condition instanceof BindAware)
				{
					innerSoql = ((BindAware)condition).toSoql(registry, options);
				}
				else
				{
					innerSoql = condition.toSoql(options);
				}
				soql += '(NOT ' + innerSoql + ')';
			}

			return soql;
		}
	}

	/**
	 * @description Converts a value to its SOQL literal representation.
	 *
	 * @param value The value to convert.
	 * @param options The SOQL options to apply (e.g., escapeSingleQuotes).
	 *
	 * @return The SOQL literal string.
	 */
	public static String toLiteral(Object value, SoqlOptions options)
	{
		return convertToLiteral(value, options);
	}

	/**
	 * @description Converts a list of values to their SOQL literal representations.
	 *
	 * @param values The list of values to convert.
	 *
	 * @return List of SOQL literal strings.
	 */
	public static List<String> toLiteralList(List<Object> values)
	{
		List<String> literals = new List<String>();
		for(Object value : values)
		{
			literals.add(convertToLiteral(value, DEFAULT_OPTIONS));
		}
		return literals;
	}

	/**
	 * @description Internal method to convert a single value to SOQL literal format.
	 *
	 * @param value The value to convert.
	 * @param options The SOQL options to apply.
	 *
	 * @return The SOQL literal string.
	 */
	@SuppressWarnings('PMD.CyclomaticComplexity')
	private static String convertToLiteral(Object value, SoqlOptions options)
	{
		if(value == null)
		{
			return 'NULL';
		}
		if(value instanceof String || value instanceof Id)
		{
			String stringValue = (String)value;
			if(options?.escapeSingleQuotes != false)
			{
				stringValue = String.escapeSingleQuotes(stringValue);
			}
			return '\'' + stringValue + '\'';
		}
		if(value instanceof Boolean)
		{
			return String.valueOf(value).toUpperCase();
		}
		if(value instanceof Integer || value instanceof Long || value instanceof Decimal || value instanceof Double)
		{
			return String.valueOf(value);
		}
		if(value instanceof Date)
		{
			return UTIL_Date.toIso8601((Date)value);
		}
		if(value instanceof Datetime)
		{
			return UTIL_Date.toIso8601((Datetime)value);
		}
		if(value instanceof SObject)
		{
			Id recordId = ((SObject)value).Id;
			return recordId == null ? 'NULL' : '\'' + recordId + '\'';
		}
		if(value instanceof Evaluable)
		{
			return ((Evaluable)value).toSoql(options);
		}
		throw new IllegalArgumentException
				(
						'Unsupported literal type: ' + UTIL_System.getRuntimeTypeName(value) +
						'. Supported types: String, Id, Boolean, Integer, Long, Decimal, Double, Date, Datetime, SObject, Evaluable.'
				);
	}

	/**
	 * @description Units of time for SOQL date literals.
	 *
	 * @since 1.0
	 */
	global enum UnitOfTime
	{
		/**
		 * @description Day unit (LAST_N_DAYS, NEXT_N_DAYS, etc.)
		 */
		DAY,

		/**
		 * @description Fiscal quarter unit (LAST_N_FISCAL_QUARTERS, etc.)
		 */
		FISCAL_QUARTER,

		/**
		 * @description Fiscal year unit (LAST_N_FISCAL_YEARS, etc.)
		 */
		FISCAL_YEAR,

		/**
		 * @description Month unit (THIS_MONTH, LAST_MONTH - not supported with N)
		 */
		MONTH,

		/**
		 * @description Quarter unit (LAST_N_QUARTERS, etc.)
		 */
		QUARTER,

		/**
		 * @description Week unit (THIS_WEEK, LAST_WEEK - not supported with N)
		 */
		WEEK,

		/**
		 * @description Year unit (LAST_N_YEARS, etc.)
		 */
		YEAR
	}

	/**
	 * @description Provides SOQL date literal values for use in QRY_Builder conditions.
	 * Implements Evaluable so date literals can be passed as condition values
	 * to FieldCondition and through the QRY_Builder fluent API.
	 *
	 * Date literals are special SOQL keywords (TODAY, LAST_N_DAYS:30, etc.) that represent
	 * relative date/time ranges and cannot be expressed as bind variables.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Records created in the last 30 days
	 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .condition('CreatedDate').equals(new QRY_Condition.DateLiteral().lastNDays(30))
	 *     .toList();
	 * // Records created today
	 * List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .condition('CreatedDate').equals(new QRY_Condition.DateLiteral().today())
	 *     .toList();
	 * ```
	 */
	global inherited sharing class DateLiteral implements Evaluable
	{
		/**
		 * @description The SOQL date literal string.
		 */
		private String literal = null;

		/**
		 * @description Converts this date literal to its SOQL representation.
		 *
		 * @return The SOQL date literal string (e.g., 'TODAY', 'LAST_N_DAYS:30')
		 */
		public String toSoql()
		{
			return literal;
		}

		/**
		 * @description Converts this date literal to its SOQL representation with options.
		 *
		 * @param options SOQL options (not used for date literals)
		 *
		 * @return The SOQL date literal string
		 */
		public String toSoql(SoqlOptions options)
		{
			return literal;
		}

		/**
		 * @description Sets the date literal to YESTERDAY.
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().yesterday()
		 * ```
		 */
		global DateLiteral yesterday()
		{
			literal = 'YESTERDAY';
			return this;
		}

		/**
		 * @description Sets the date literal to TODAY.
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().today()
		 * ```
		 */
		global DateLiteral today()
		{
			literal = 'TODAY';
			return this;
		}

		/**
		 * @description Sets the date literal to TOMORROW.
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().tomorrow()
		 * ```
		 */
		global DateLiteral tomorrow()
		{
			literal = 'TOMORROW';
			return this;
		}

		/**
		 * @description Sets the date literal to a THIS_* value for the given unit.
		 *
		 * @param unit The unit of time
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.MONTH)
		 * new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.DAY)  // returns TODAY
		 * ```
		 */
		global DateLiteral thisUnit(UnitOfTime unit)
		{
			if(unit == UnitOfTime.DAY)
			{
				return today();
			}
			literal = 'THIS_' + unit.name();
			return this;
		}

		/**
		 * @description Sets the date literal to LAST_90_DAYS.
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().last90Days()
		 * ```
		 */
		global DateLiteral last90Days()
		{
			return last(90, UnitOfTime.DAY);
		}

		/**
		 * @description Sets the date literal to NEXT_90_DAYS.
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().next90Days()
		 * ```
		 */
		global DateLiteral next90Days()
		{
			return next(90, UnitOfTime.DAY);
		}

		/**
		 * @description Sets the date literal to LAST_N_DAYS:n.
		 *
		 * @param numberOfDays The number of days
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().lastNDays(30)
		 * ```
		 */
		global DateLiteral lastNDays(Integer numberOfDays)
		{
			return last(numberOfDays, UnitOfTime.DAY);
		}

		/**
		 * @description Sets the date literal to NEXT_N_DAYS:n.
		 *
		 * @param numberOfDays The number of days
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().nextNDays(60)
		 * ```
		 */
		global DateLiteral nextNDays(Integer numberOfDays)
		{
			return next(numberOfDays, UnitOfTime.DAY);
		}

		/**
		 * @description Sets the date literal to LAST_* for a given unit (e.g., LAST_QUARTER).
		 *
		 * @param unit The unit of time
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().last(QRY_Condition.UnitOfTime.QUARTER)
		 * ```
		 */
		global DateLiteral last(UnitOfTime unit)
		{
			return last(1, unit);
		}

		/**
		 * @description Sets the date literal to NEXT_* for a given unit (e.g., NEXT_QUARTER).
		 *
		 * @param unit The unit of time
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().next(QRY_Condition.UnitOfTime.QUARTER)
		 * ```
		 */
		global DateLiteral next(UnitOfTime unit)
		{
			return next(1, unit);
		}

		/**
		 * @description Sets the date literal to LAST_N_*:n.
		 *
		 * @param numberOfUnits The number of units
		 * @param unit The unit of time
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().last(4, QRY_Condition.UnitOfTime.QUARTER)
		 * ```
		 */
		global DateLiteral last(Integer numberOfUnits, UnitOfTime unit)
		{
			literal = 'LAST_' + toUnitAndAmount(numberOfUnits, unit);
			return this;
		}

		/**
		 * @description Sets the date literal to NEXT_N_*:n.
		 *
		 * @param numberOfUnits The number of units
		 * @param unit The unit of time
		 *
		 * @return The DateLiteral instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new QRY_Condition.DateLiteral().next(2, QRY_Condition.UnitOfTime.FISCAL_YEAR)
		 * ```
		 */
		global DateLiteral next(Integer numberOfUnits, UnitOfTime unit)
		{
			literal = 'NEXT_' + toUnitAndAmount(numberOfUnits, unit);
			return this;
		}

		/**
		 * @description Converts unit and amount to the SOQL date literal suffix.
		 *
		 * @param numberOfUnits The number of units
		 * @param unit The unit of time
		 *
		 * @return The formatted suffix (e.g., 'N_DAYS:30', 'QUARTER', '90_DAYS')
		 */
		private String toUnitAndAmount(Integer numberOfUnits, UnitOfTime unit)
		{
			if(numberOfUnits < 0)
			{
				throw new IllegalArgumentException('numberOfUnits cannot be negative');
			}

			if(numberOfUnits == 90 && unit == UnitOfTime.DAY)
			{
				return '90_DAYS';
			}

			if(numberOfUnits == 1 && unit != UnitOfTime.DAY)
			{
				return unit.name();
			}

			if(unit == UnitOfTime.WEEK || unit == UnitOfTime.MONTH)
			{
				throw new IllegalArgumentException('N_WEEKS and N_MONTHS are not supported by SOQL');
			}

			return 'N_' + unit.name() + 'S:' + numberOfUnits;
		}
	}

	/**
	 * @description A condition that always evaluates to false, returning no records.
	 * Used internally when collection-based conditions (IN, INCLUDES) receive
	 * empty or null input to ensure no records are returned instead of silently
	 * dropping the WHERE clause.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Condition.Evaluable falseCondition = new QRY_Condition.FalseCondition();
	 * String soql = falseCondition.toSoql();
	 * Assert.areEqual('Id = null', soql, 'Should generate an impossible condition');
	 * ```
	 */
	public class FalseCondition implements Evaluable
	{
		/**
		 * @description Returns SOQL that always evaluates to false.
		 *
		 * @return A SOQL string that matches no records
		 */
		public String toSoql()
		{
			return toSoql(DEFAULT_OPTIONS);
		}

		/**
		 * @description Returns SOQL that always evaluates to false with options.
		 *
		 * @param options SOQL options (not used for false conditions)
		 *
		 * @return A SOQL string that matches no records
		 */
		public String toSoql(SoqlOptions options)
		{
			return 'Id = null';
		}
	}
}