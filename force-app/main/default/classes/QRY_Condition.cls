// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Condition infrastructure for building complex SOQL WHERE clauses.
 * Use these classes with QRY_Builder.addCondition() for compound conditions
 * that cannot be expressed with the fluent API alone (e.g., grouped OR conditions).
 *
 * **VISIBILITY**: `global` so your code can use it.
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
 * @date February 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * QRY_Condition.OrCondition condition = new QRY_Condition.OrCondition();
 * condition.add(new QRY_Condition.FieldCondition(Account.Industry, QRY_Condition.Operator.EQUALS, 'Technology'));
 * condition.add(new QRY_Condition.FieldCondition(Account.Name).contains('Acme'));
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

	/**
	 * @description The smallest number an Apex Integer can hold.
	 */
	private static final Decimal SMALLEST_INTEGER = -2147483648L;

	/**
	 * @description The largest number an Apex Integer can hold.
	 */
	private static final Decimal LARGEST_INTEGER = 2147483647;

	/**
	 * @description The kind name SetCondition gives every number, whatever its Apex type (Integer, Long, Double or Decimal),
	 * so numbers of different types can share one bound list.
	 */
	private static final String NUMBER_KIND = 'Number';

	/**
	 * @description The class name a SetCondition gives in its error message when it refuses a text that is not a field
	 * name, so the developer can see which part of the query refused it.
	 */
	private static final String SET_CONDITION_NAME = 'SetCondition';

	/**
	 * @description The word that joins the conditions of an AndCondition: every condition must match.
	 */
	private static final String AND_SEPARATOR = 'AND';

	/**
	 * @description The word that joins the conditions of an OrCondition: at least one condition must match.
	 */
	private static final String OR_SEPARATOR = 'OR';

	/**
	 * @description The kind name SetCondition gives every record. A list of records is bound as a list of SObject values and
	 * matched by Id.
	 */
	private static final String RECORD_KIND = 'SObject';

	/**
	 * @description The Apex type names that SetCondition treats as one kind, NUMBER_KIND, when it decides whether a list
	 * can be bound.
	 */
	private static final Set<String> NUMBER_TYPE_NAMES = new Set<String>
	{
			Integer.class.getName(), Long.class.getName(), Decimal.class.getName(), Double.class.getName()
	};

	/**
	 * @description The Apex type names that SetCondition can bind as a list of that one type (Id, String, Date, Datetime or
	 * Boolean). A list is bound only when all its non-blank values share one of these types. Numbers are not in this set:
	 * see NUMBER_TYPE_NAMES.
	 */
	private static final Set<String> SINGLE_TYPE_BINDABLE_NAMES = new Set<String>
	{
			Id.class.getName(), String.class.getName(), Date.class.getName(), Datetime.class.getName(), Boolean.class.getName()
	};

	// Private operator shortcuts (workaround for Apex limitation: enum values cannot be referenced from instance methods of inner classes)
	/**
	 * @description Short name for the operator that matches a field equal to one value (SOQL `=`). The inner condition classes use
	 * these short names because Apex does not let their instance methods name an Operator value directly. It is also the operator
	 * a field condition gets when it is built from a field and a value alone.
	 */
	private static final Operator EQUALS = Operator.EQUALS;
	/**
	 * @description Short name for the operator that matches a field different from one value (SOQL `!=`), for use inside the inner
	 * condition classes.
	 */
	private static final Operator NOT_EQUALS = Operator.NOT_EQUALS;
	/**
	 * @description Short name for the operator that matches a field smaller than one value (SOQL `<`), for use inside the inner
	 * condition classes.
	 */
	private static final Operator LESS_THAN = Operator.LESS_THAN;
	/**
	 * @description Short name for the operator that matches a field smaller than or equal to one value (SOQL `<=`), for use inside
	 * the inner condition classes.
	 */
	private static final Operator LESS_THAN_OR_EQUAL_TO = Operator.LESS_THAN_OR_EQUAL_TO;
	/**
	 * @description Short name for the operator that matches a field larger than one value (SOQL `>`), for use inside the inner
	 * condition classes.
	 */
	private static final Operator GREATER_THAN = Operator.GREATER_THAN;
	/**
	 * @description Short name for the operator that matches a field larger than or equal to one value (SOQL `>=`), for use inside
	 * the inner condition classes.
	 */
	private static final Operator GREATER_THAN_OR_EQUAL_TO = Operator.GREATER_THAN_OR_EQUAL_TO;
	/**
	 * @description Short name for the operator that matches a text field against a pattern (SOQL `LIKE`), for use inside the inner
	 * condition classes. The pattern may hold the wildcards LIKE_MULTIPLE_CHARACTER_WILDCARD and LIKE_SINGLE_CHARACTER_WILDCARD.
	 */
	private static final Operator LIKE_X = Operator.LIKE_X;
	/**
	 * @description Short name for the operator that matches a field whose value is one of a set of values, or one of the rows a
	 * subquery returns (SOQL `IN`), for use inside the inner condition classes.
	 */
	private static final Operator IN_X = Operator.IN_X;
	/**
	 * @description Short name for the operator that matches a field whose value is none of a set of values, or none of the rows a
	 * subquery returns (SOQL `NOT IN`), for use inside the inner condition classes.
	 */
	private static final Operator NOT_IN = Operator.NOT_IN;
	/**
	 * @description Short name for the operator that matches a multi-select picklist field holding any of the given values (SOQL
	 * `INCLUDES`), for use inside the inner condition classes.
	 */
	private static final Operator INCLUDES = Operator.INCLUDES;
	/**
	 * @description Short name for the operator that matches a multi-select picklist field holding none of the given values (SOQL
	 * `EXCLUDES`), for use inside the inner condition classes.
	 */
	private static final Operator EXCLUDES = Operator.EXCLUDES;

	/**
	 * @description The SOQL LIKE escape character, which makes the character after it literal.
	 */
	private static final String LIKE_ESCAPE_CHARACTER = '\\';

	/**
	 * @description The SOQL LIKE wildcard that matches any number of characters.
	 */
	public static final String LIKE_MULTIPLE_CHARACTER_WILDCARD = '%';

	/**
	 * @description The SOQL LIKE wildcard that matches exactly one character.
	 */
	private static final String LIKE_SINGLE_CHARACTER_WILDCARD = UTIL_String.UNDERSCORE;

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
		 * @description The field holds exactly the given value (SOQL =). With a null value, the field is blank.
		 */
		EQUALS,
		/**
		 * @description Multi-select picklist excludes
		 */
		EXCLUDES,
		/**
		 * @description The field is larger than the given value (SOQL >); for a date or a time, later.
		 */
		GREATER_THAN,
		/**
		 * @description The field is equal to the given value or larger (SOQL >=); for a date or a time, the same or later.
		 */
		GREATER_THAN_OR_EQUAL_TO,
		/**
		 * @description Multi-select picklist includes
		 */
		INCLUDES,
		/**
		 * @description The field holds any one of a list of values, or any value a subquery returns (SOQL IN). The name ends in
		 * _X because IN is a reserved word in Apex.
		 */
		IN_X,
		/**
		 * @description The field is smaller than the given value (SOQL <); for a date or a time, earlier.
		 */
		LESS_THAN,
		/**
		 * @description The field is equal to the given value or smaller (SOQL <=); for a date or a time, the same or earlier.
		 */
		LESS_THAN_OR_EQUAL_TO,
		/**
		 * @description Pattern matching (LIKE)
		 */
		LIKE_X,
		/**
		 * @description The field does not hold the given value (SOQL !=). With a null value, the field has a value.
		 */
		NOT_EQUALS,
		/**
		 * @description The field holds none of a list of values, or none of the values a subquery returns (SOQL NOT IN).
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
		 *
		 * @since 1.0
		 */
		String toSoql();

		/**
		 * @description Converts the condition to a SOQL query string using specific options.
		 *
		 * @param options The SOQL options for customization.
		 *
		 * @return A valid SOQL query string.
		 *
		 * @since 1.0
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
	 * @description Escapes the three characters that carry meaning inside a SOQL LIKE pattern so the
	 * text matches literally. The escape character goes first: escaping it after the wildcards would
	 * escape the escapes this method has just added.
	 *
	 * @param textValue The text to escape. Null is returned unchanged, so a null value composes the
	 * same pattern the unescaped forms compose.
	 *
	 * @return The text with every backslash, percent sign and underscore escaped.
	 */
	private static String escapeLikeMetacharacters(String textValue)
	{
		String escaped = UTIL_String.replace(textValue, LIKE_ESCAPE_CHARACTER, LIKE_ESCAPE_CHARACTER + LIKE_ESCAPE_CHARACTER);
		escaped = UTIL_String.replace(escaped, LIKE_MULTIPLE_CHARACTER_WILDCARD, LIKE_ESCAPE_CHARACTER + LIKE_MULTIPLE_CHARACTER_WILDCARD);
		return UTIL_String.replace(escaped, LIKE_SINGLE_CHARACTER_WILDCARD, LIKE_ESCAPE_CHARACTER + LIKE_SINGLE_CHARACTER_WILDCARD);
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
		 * @description How the field is compared with the value, such as EQUALS or LIKE_X. It is null until a constructor or a
		 * method such as equals sets it.
		 */
		public Operator operator {get; private set;}

		/**
		 * @description The value to compare against the field.
		 */
		public Object value {get; private set;}

		/**
		 * @description Creates an empty condition with no field, operator or value. Set the field with field() and the
		 * comparison with a method such as equals() before the condition is written into a query.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public FieldCondition()
		{
		}

		/**
		 * @description Constructor for FieldCondition with a specified field. Pair with contains() to
		 * complete the condition, or use the field-operator-value constructor for other comparisons. The field may also be a
		 * date or distance function from QRY_Function, or toLabel around a field name. Text that comes from a page or a user
		 * must first be matched to a field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name
		 *
		 * @throws IllegalArgumentException if the text is blank or is not a field name
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.Evaluable condition = new QRY_Condition.FieldCondition('Name').contains('Acme');
		 * ```
		 */
		global FieldCondition(String fieldName)
		{
			this.field(fieldName);
		}

		/**
		 * @description Constructor for FieldCondition with a specified SObjectField. Pair with contains()
		 * to complete the condition, or use the field-operator-value constructor for other comparisons.
		 *
		 * @param objectField The ObjectField to apply the condition to.
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.Evaluable condition = new QRY_Condition.FieldCondition(Account.Name).contains('Acme');
		 * ```
		 */
		global FieldCondition(SObjectField objectField)
		{
			this.field(objectField);
		}

		/**
		 * @description Builds an EQUALS condition: the field must hold exactly the value. A null value matches records whose
		 * field is blank. A blank field name throws IllegalArgumentException.
		 *
		 * @param fieldName The field to apply the condition to.
		 * @param fieldValue The value to compare against the field.
		 */
		public FieldCondition(String fieldName, Object fieldValue)
		{
			this(fieldName, EQUALS, fieldValue);
		}

		/**
		 * @description Builds an EQUALS condition from a field token: the field must hold exactly the value. A null value
		 * matches records whose field is blank.
		 *
		 * @param objectField The field to apply the condition to.
		 * @param fieldValue The value to compare against the field.
		 */
		public FieldCondition(SObjectField objectField, Object fieldValue)
		{
			this(objectField, EQUALS, fieldValue);
		}

		/**
		 * @description Builds a condition that compares one field with one value. The field name is trimmed, and a blank name
		 * throws IllegalArgumentException. The operator must compare with a single value: IN_X, NOT_IN, INCLUDES and EXCLUDES
		 * throw IllegalArgumentException. A null operator leaves the comparison unset, for contains() or containsLiteral() to
		 * set next. When a QRY_Builder query runs, the value is passed as a bind variable, so you never escape quotes in text
		 * yourself. The field may also be a date or distance function from QRY_Function, or toLabel around a field name. Text
		 * that comes from a page or a user must first be matched to a field through a list of fields you allow.
		 *
		 * @param fieldName A field API name, such as Name or Account.Owner.Name
		 * @param fieldOperator The operator for the condition.
		 * @param fieldValue The value to compare against the field.
		 *
		 * @throws IllegalArgumentException if the field text is blank or is not a field name, or the operator compares with
		 * a list
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition('Name', QRY_Condition.Operator.EQUALS, 'Acme');
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
		 * @description Builds a condition that compares one field, given as a field token, with one value. The operator must
		 * compare with a single value: IN_X, NOT_IN, INCLUDES and EXCLUDES throw IllegalArgumentException. A null operator
		 * leaves the comparison unset, for contains() or containsLiteral() to set next. When a QRY_Builder query runs, the
		 * value is passed as a bind variable, so you never escape quotes in text yourself.
		 *
		 * @param objectField The field to apply the condition to.
		 * @param fieldOperator The operator for the condition.
		 * @param fieldValue The value to compare against the field.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition(Account.Name, QRY_Condition.Operator.EQUALS, 'Acme');
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
		 * @description Sets the field from a field token, by reading its API name from the describe cache. It replaces any field
		 * set earlier.
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
		 * @description Sets the field by API name, with spaces trimmed from both ends. It replaces any field set earlier. A
		 * blank name throws IllegalArgumentException. So does a text that is not a field name: it must be a field path such
		 * as Account.Name, a date or distance function from QRY_Function, an aggregate such as SUM(Amount), or toLabel around
		 * a field path.
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
			field = QRY_Generator.validateConditionField(fieldName, 'FieldCondition');
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
		 * @description Sets the condition to a LIKE comparison that matches the value anywhere in the
		 * field (a contains match). This differs from the raw LIKE form (the Operator.LIKE_X
		 * constructor argument), which passes your pattern through verbatim and leaves every % and _
		 * wildcard to you: contains owns the wildcards, wrapping the value in a leading and trailing %
		 * so callers never assemble '%' + value + '%' patterns by hand — the same contract as the query
		 * builder's contains().
		 *
		 * @param compareValue The text to match anywhere in the field.
		 *
		 * @return The FieldCondition instance for method chaining.
		 *
		 * @date July 2026
		 *
		 * @since 1.3
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.OrCondition textMatch = new QRY_Condition.OrCondition();
		 * textMatch.add(new QRY_Condition.FieldCondition(Account.Name).contains('Acme')); // Name LIKE '%Acme%'
		 * textMatch.add(new QRY_Condition.FieldCondition(Account.Website).contains('acme'));
		 * ```
		 */
		global virtual FieldCondition contains(String compareValue)
		{
			return setOperation(LIKE_X, LIKE_MULTIPLE_CHARACTER_WILDCARD + compareValue + LIKE_MULTIPLE_CHARACTER_WILDCARD);
		}

		/**
		 * @description Sets the condition to a LIKE comparison that matches the value literally
		 * anywhere in the field. The three characters that carry meaning inside a LIKE pattern are
		 * escaped first: % (any run of characters), _ (any single character), and \ (the escape
		 * character itself). Use this whenever the value came from a person, such as a search box, a
		 * filter or a report parameter, because contains() deliberately leaves those characters their
		 * wildcard meaning: a search for "100%" otherwise matches every value containing "100", and a
		 * search for "UTIL_HttpClient" also matches "UTILxHttpClient". Use contains() when the pattern
		 * is yours and the wildcards are wanted. The escape travels with the bound value, which is the
		 * form every QRY_Builder query executes; it is not preserved if you render the condition to a
		 * SOQL string with toSoql() and run that string yourself.
		 *
		 * @param compareValue The text to match anywhere in the field, character for character.
		 *
		 * @return The FieldCondition instance for method chaining.
		 *
		 * @since 1.7
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.OrCondition userSearch = new QRY_Condition.OrCondition();
		 * userSearch.add(new QRY_Condition.FieldCondition(Account.Name).containsLiteral(searchBoxValue));
		 * userSearch.add(new QRY_Condition.FieldCondition(Account.Website).containsLiteral(searchBoxValue));
		 * ```
		 */
		global virtual FieldCondition containsLiteral(String compareValue)
		{
			return setOperation(LIKE_X, LIKE_MULTIPLE_CHARACTER_WILDCARD + escapeLikeMetacharacters(compareValue) + LIKE_MULTIPLE_CHARACTER_WILDCARD);
		}

		/**
		 * @description Stores the comparison and the value; every comparison method goes through it. An operator that takes a
		 * list of values (IN_X, NOT_IN, INCLUDES or EXCLUDES) throws IllegalArgumentException, because SetCondition handles
		 * those.
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
		 * @description How the field is compared with the values: IN_X, NOT_IN, INCLUDES or EXCLUDES. It is null until one is
		 * set, and toSoql throws until it is.
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
		 * @description Creates an empty condition. Set the field with field() and the values with inX, notIn, includes or
		 * excludes before calling toSoql, which throws until an operator is set.
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
		 * @description Builds the condition from a set. The set is copied into a list, so a later change to the set does not
		 * change the condition. A blank field name, an empty set, or an operator other than IN_X, NOT_IN, INCLUDES or EXCLUDES
		 * throws IllegalArgumentException.
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
		 * @description Sets the field by API name, with spaces trimmed from both ends. It replaces any field set earlier. A
		 * blank name throws IllegalArgumentException. So does a text that is not a field name: it must be a field path such
		 * as Account.Name, a date or distance function from QRY_Function, an aggregate such as SUM(Amount), or toLabel around
		 * a field path.
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
			field = QRY_Generator.validateConditionField(fieldName, SET_CONDITION_NAME);
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
		 * @description Stores the values and the operator. A null or empty list throws IllegalArgumentException, so a condition
		 * never runs with nothing to compare. So does an operator other than IN_X, NOT_IN, INCLUDES or EXCLUDES.
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
		 * @description Stores a subquery as the source of the values, and the operator. A null subquery throws
		 * IllegalArgumentException. So does an operator other than IN_X, NOT_IN, INCLUDES or EXCLUDES, and so does a
		 * subquery that selects a text that is not one field path, because the subquery is written inside the outer WHERE
		 * clause. The subquery is checked again when the query text is built, in case a field was added to it after this.
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
			queryBuilder.validateSelectedFieldPaths(SET_CONDITION_NAME);
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
		 *
		 * @throws IllegalArgumentException if the subquery now selects a text that is not one field path.
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
				builder.validateSelectedFieldPaths(SET_CONDITION_NAME);
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
		 *
		 * @throws IllegalArgumentException if the subquery now selects a text that is not one field path.
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
				builder.validateSelectedFieldPaths(SET_CONDITION_NAME);
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
		 * @description Determines if a collection can be safely bound in Database.queryWithBinds. A collection can be bound
		 * when it has at least one non-blank value and all its non-blank values are of one kind: all Ids, all text, all
		 * records, all dates, all Datetime values, all true or false values, or all numbers. Numbers of different Apex types
		 * (Integer, Long, Double, Decimal) count as one kind. A list that mixes kinds, or holds only blanks, is written into
		 * the query as literals instead.
		 *
		 * @param collection The collection to check for bindability.
		 *
		 * @return True if the collection can be safely bound.
		 */
		private Boolean isBindableCollection(List<Object> collection)
		{
			String foundKind = null;

			for(Object element : collection)
			{
				if(element == null)
				{
					continue;
				}

				String elementKind = getBindableKind(element);
				if(elementKind == null)
				{
					return false;
				}
				if(foundKind != null && foundKind != elementKind)
				{
					return false;
				}
				foundKind = elementKind;
			}

			return foundKind != null;
		}

		/**
		 * @description Names the kind of a single non-blank value for binding. Every number gets the same kind, whatever its
		 * Apex type.
		 *
		 * @param element The value to check. It must not be null.
		 *
		 * @return The kind name (Id, String, Date, Datetime, Boolean, Number or SObject), or null when the value cannot be
		 * bound as part of a list.
		 */
		private String getBindableKind(Object element)
		{
			if(element instanceof SObject)
			{
				return RECORD_KIND;
			}

			String typeName = UTIL_System.getRuntimeTypeName(element);

			if(NUMBER_TYPE_NAMES.contains(typeName))
			{
				return NUMBER_KIND;
			}
			return SINGLE_TYPE_BINDABLE_NAMES.contains(typeName) ? typeName : null;
		}

		/**
		 * @description Copies a generic List<Object> into a list of one exact type, so the query can bind it. Checks the
		 * list's runtime type first to avoid the Id/String ambiguity that occurs when sampling individual elements (Apex
		 * `instanceof Id` returns true for any 15/18-char String). The first non-blank value decides the type:
		 * List<SObject>, List<Id>, List<String>, List<Date>, List<Datetime> or List<Boolean>. A list of numbers becomes a
		 * List<Integer> when every number is a whole number that fits in an Integer, and a List<Decimal> otherwise. This
		 * matters because some query columns, such as COUNT() and CALENDAR_YEAR(), accept only a list of Integer values.
		 * Blank values stay in the list as null.
		 *
		 * @param inputList The original list of values. isBindableCollection must have accepted it.
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

			String kind = sample == null ? String.class.getName() : getBindableKind(sample);

			if(kind == RECORD_KIND)
			{
				return toTypedList(inputList, new List<SObject>());
			}
			if(kind == Id.class.getName())
			{
				return toTypedList(inputList, new List<Id>());
			}
			if(kind == Date.class.getName())
			{
				return toTypedList(inputList, new List<Date>());
			}
			if(kind == Datetime.class.getName())
			{
				return toTypedList(inputList, new List<Datetime>());
			}
			if(kind == Boolean.class.getName())
			{
				return toTypedList(inputList, new List<Boolean>());
			}
			if(kind == NUMBER_KIND)
			{
				return toNumberList(inputList);
			}
			return toTypedList(inputList, new List<String>());
		}

		/**
		 * @description Adds every value of a generic list to an empty list of an exact type. Apex checks each value against
		 * the target list's type as it is added.
		 *
		 * @param inputList The values to copy.
		 * @param typedList An empty list of the exact type to fill.
		 *
		 * @return The filled typed list.
		 */
		private List<Object> toTypedList(List<Object> inputList, List<Object> typedList)
		{
			typedList.addAll(inputList);
			return typedList;
		}

		/**
		 * @description Copies a list of numbers into a List<Integer> when every non-blank number is a whole number that fits
		 * in an Integer, and into a List<Decimal> otherwise.
		 *
		 * @param inputList The numbers to copy. Blank values stay in the list as null.
		 *
		 * @return A List<Integer> or a List<Decimal>.
		 */
		private Object toNumberList(List<Object> inputList)
		{
			Boolean allFitInteger = true;
			List<Decimal> decimals = new List<Decimal>();
			for(Object itemValue : inputList)
			{
				decimals.add(toDecimal(itemValue));
				allFitInteger = allFitInteger && (itemValue == null || isWholeNumberInIntegerRange(itemValue));
			}

			if(!allFitInteger)
			{
				return decimals;
			}

			List<Integer> integers = new List<Integer>();
			for(Decimal decimalValue : decimals)
			{
				integers.add(decimalValue?.intValue());
			}
			return integers;
		}

		/**
		 * @description Checks whether a number is a whole number from -2147483648 to 2147483647, the range of an Apex
		 * Integer. A number such as 3.0 counts as whole.
		 *
		 * @param value The number to check: an Integer, Long, Double or Decimal. It must not be null.
		 *
		 * @return True when the number can be stored in an Integer without losing anything.
		 */
		private Boolean isWholeNumberInIntegerRange(Object value)
		{
			Decimal decimalValue = toDecimal(value);
			return decimalValue.stripTrailingZeros().scale() <= 0 && decimalValue >= SMALLEST_INTEGER && decimalValue <= LARGEST_INTEGER;
		}

		/**
		 * @description Turns any Apex number into a Decimal with the same value.
		 *
		 * @param value An Integer, Long, Double or Decimal, or null.
		 *
		 * @return The value as a Decimal, or null when the value is null.
		 */
		private Decimal toDecimal(Object value)
		{
			if(value instanceof Integer)
			{
				return (Integer)value;
			}
			if(value instanceof Long)
			{
				return Decimal.valueOf((Long)value);
			}
			return (Decimal)value;
		}
	}

	/**
	 * @description Abstract base class for condition groups (AND/OR).
	 */
	public abstract class ConditionGroup implements Nestable, BindAware
	{
		/**
		 * @description The conditions this group joins with its AND or OR, in the order they were added. add() leaves out a null condition.
		 */
		public List<Evaluable> conditions {get; private set;}

		/**
		 * @description The separator (AND/OR) used to combine conditions.
		 */
		private final String separator;

		/**
		 * @description Creates an empty group whose conditions are joined by AND or OR. The word may be in any letter case
		 * and is written into the query as given. Any other text is refused, so that it cannot change the query.
		 *
		 * @param groupSeparator The separator (AND/OR) used to combine conditions.
		 *
		 * @throws IllegalArgumentException if the word is not AND or OR. The message does not repeat the text.
		 */
		public ConditionGroup(String groupSeparator)
		{
			if(!AND_SEPARATOR.equalsIgnoreCase(groupSeparator) && !OR_SEPARATOR.equalsIgnoreCase(groupSeparator))
			{
				throw new IllegalArgumentException(String.format(System.Label.QueryBuilder_ConditionSeparator_NotAllowed, new List<Object> {'ConditionGroup'}));
			}
			separator = groupSeparator;
			conditions = new List<Evaluable>();
		}

		/**
		 * @description Adds a condition to the end of the group. A null condition is ignored.
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
			super(AND_SEPARATOR);
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
			super(OR_SEPARATOR);
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
		 * @description Creates a NOT condition with nothing to negate yet. Until add() sets a condition, it writes nothing into
		 * the query.
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
		if(value instanceof Integer || value instanceof Long)
		{
			return String.valueOf(value);
		}
		if(value instanceof Decimal || value instanceof Double)
		{
			return ((Decimal)value).toPlainString();
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
		 * @description Matches the whole of the day before today, with the SOQL keyword YESTERDAY. Pass the result as a
		 * condition value, for example to equals(). It replaces any date set earlier on this object.
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
		 * @description Matches the whole of today, with the SOQL keyword TODAY. Pass the result as a condition value, for
		 * example to equals(). It replaces any date set earlier on this object.
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
		 * @description Matches the whole of the day after today, with the SOQL keyword TOMORROW. Pass the result as a condition
		 * value, for example to equals(). It replaces any date set earlier on this object.
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
		 * @description Matches the current week, month, quarter, year, fiscal quarter or fiscal year, written as THIS_ and the
		 * unit name, such as THIS_MONTH. DAY gives TODAY, because SOQL has no THIS_DAY. A null unit throws a
		 * NullPointerException.
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
		 * @description Matches today and the 90 days before it, with the SOQL keyword LAST_90_DAYS. lastNDays(90)
		 * writes the same keyword.
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
		 * @description Matches the next 90 days, starting tomorrow, with the SOQL keyword NEXT_90_DAYS. nextNDays(90) writes the
		 * same keyword.
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
		 * @description Matches today and the n days before it, written as LAST_N_DAYS:n (lastNDays(30) writes
		 * LAST_N_DAYS:30). For 90 it writes LAST_90_DAYS. A negative number throws IllegalArgumentException.
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
		 * @description Matches the next n days, starting tomorrow, written as NEXT_N_DAYS:n (nextNDays(60) writes
		 * NEXT_N_DAYS:60). For 90 it writes NEXT_90_DAYS. A negative number throws IllegalArgumentException.
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