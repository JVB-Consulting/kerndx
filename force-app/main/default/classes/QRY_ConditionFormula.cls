// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Translates QRY_Condition.Evaluable trees into FormulaEval-compatible
 * expression strings. Used by the mock filtering system to evaluate query conditions
 * against in-memory records via UTIL_FormulaFilter.
 *
 * Returns null when the condition tree contains unsupported elements (relationship
 * field traversals, INCLUDES/EXCLUDES operators, unknown Evaluable implementations),
 * signalling the caller to skip filtering and return all mocks.
 *
 * @see QRY_Condition
 * @see QRY_Engine
 * @see QRY_ConditionFormula_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class QRY_ConditionFormula
{
	/**
	 * @description Prefix used by FormulaEval to reference the current record's fields.
	 */
	@TestVisible
	private static final String RECORD_PREFIX = 'newRecord.';

	/**
	 * @description Maps QRY_Condition operators to their FormulaEval equivalents.
	 */
	private static final Map<QRY_Condition.Operator, String> OPERATOR_MAP = new Map<QRY_Condition.Operator, String>
	{
			QRY_Condition.Operator.EQUALS => '=',
			QRY_Condition.Operator.NOT_EQUALS => '<>',
			QRY_Condition.Operator.GREATER_THAN => '>',
			QRY_Condition.Operator.LESS_THAN => '<',
			QRY_Condition.Operator.GREATER_THAN_OR_EQUAL_TO => '>=',
			QRY_Condition.Operator.LESS_THAN_OR_EQUAL_TO => '<='
	};

	/**
	 * @description Converts a condition tree into a FormulaEval-compatible expression string.
	 *
	 * @param condition The condition tree to translate
	 *
	 * @return The formula expression string, or null if the condition contains unsupported elements
	 */
	public static String toFormula(QRY_Condition.Evaluable condition)
	{
		if(condition == null)
		{
			return null;
		}

		return translateCondition(condition);
	}

	/**
	 * @description Dispatches condition translation based on the concrete type.
	 *
	 * @param condition The condition to translate
	 *
	 * @return The formula string or null if unsupported
	 */
	private static String translateCondition(QRY_Condition.Evaluable condition)
	{
		if(condition instanceof QRY_Condition.FieldCondition)
		{
			return translateFieldCondition((QRY_Condition.FieldCondition)condition);
		}
		if(condition instanceof QRY_Condition.SetCondition)
		{
			return translateSetCondition((QRY_Condition.SetCondition)condition);
		}
		if(condition instanceof QRY_Condition.AndCondition)
		{
			return translateGroup((QRY_Condition.ConditionGroup)condition, '&&');
		}
		if(condition instanceof QRY_Condition.OrCondition)
		{
			return translateGroup((QRY_Condition.ConditionGroup)condition, '||');
		}

		return null;
	}

	/**
	 * @description Translates a FieldCondition into a formula expression.
	 *
	 * @param condition The field condition
	 *
	 * @return The formula string or null if the field path is unsupported
	 */
	private static String translateFieldCondition(QRY_Condition.FieldCondition condition)
	{
		String field = condition.field;

		if(field == null || field.contains('.'))
		{
			return null;
		}

		QRY_Condition.Operator operator = condition.operator;
		Object value = condition.value;

		if(operator == QRY_Condition.Operator.EQUALS && value == null)
		{
			return 'ISBLANK(' + RECORD_PREFIX + field + ')';
		}
		if(operator == QRY_Condition.Operator.NOT_EQUALS && value == null)
		{
			return 'NOT(ISBLANK(' + RECORD_PREFIX + field + '))';
		}

		String formulaValue = formatValue(value);
		if(formulaValue == null)
		{
			return null;
		}

		if(operator == QRY_Condition.Operator.LIKE_X)
		{
			return translateLike(field, value);
		}

		return RECORD_PREFIX + field + ' ' + OPERATOR_MAP.get(operator) + ' ' + formulaValue;
	}

	/**
	 * @description Translates a LIKE condition into a CONTAINS formula expression.
	 * Only supports the %value% pattern (contains). Other LIKE patterns return null.
	 *
	 * @param field The field name
	 * @param value The LIKE pattern value
	 *
	 * @return The CONTAINS formula or null if the pattern is not a simple contains
	 */
	private static String translateLike(String field, Object value)
	{
		if(!(value instanceof String))
		{
			return null;
		}

		String pattern = (String)value;

		if(pattern.startsWith('%') && pattern.endsWith('%') && pattern.length() > 2)
		{
			String searchValue = pattern.substring(1, pattern.length() - 1);
			return 'CONTAINS(' + RECORD_PREFIX + field + ', "' + escapeFormulaString(searchValue) + '")';
		}

		return null;
	}

	/**
	 * @description Translates a SetCondition (IN/NOT IN) into a formula expression.
	 *
	 * @param condition The set condition
	 *
	 * @return The formula string or null if the operator is unsupported
	 */
	private static String translateSetCondition(QRY_Condition.SetCondition condition)
	{
		String field = condition.field;

		if(field == null || field.contains('.'))
		{
			return null;
		}

		QRY_Condition.Operator operator = condition.operator;

		if(operator == QRY_Condition.Operator.INCLUDES || operator == QRY_Condition.Operator.EXCLUDES)
		{
			return null;
		}

		if(condition.builder != null)
		{
			return null;
		}

		List<Object> values = condition.values;

		String comparisonOp;
		String joiner;

		if(operator == QRY_Condition.Operator.IN_X)
		{
			comparisonOp = '=';
			joiner = ' || ';
		}
		else
		{
			comparisonOp = '<>';
			joiner = ' && ';
		}

		List<String> parts = new List<String>();
		for(Object value : values)
		{
			String formulaValue = formatValue(value);
			if(formulaValue == null)
			{
				return null;
			}
			parts.add(RECORD_PREFIX + field + ' ' + comparisonOp + ' ' + formulaValue);
		}

		return '(' + String.join(parts, joiner) + ')';
	}

	/**
	 * @description Translates a condition group (AND/OR) into a formula expression.
	 *
	 * @param conditionGroup The condition group
	 * @param separator The logical operator string (&& or ||)
	 *
	 * @return The formula string or null if any child condition is unsupported
	 */
	private static String translateGroup(QRY_Condition.ConditionGroup conditionGroup, String separator)
	{
		if(conditionGroup.conditions == null || conditionGroup.conditions.isEmpty())
		{
			return null;
		}

		List<String> parts = new List<String>();
		for(QRY_Condition.Evaluable child : conditionGroup.conditions)
		{
			String childFormula = translateCondition(child);
			if(childFormula == null)
			{
				return null;
			}
			parts.add('(' + childFormula + ')');
		}

		if(parts.size() == 1)
		{
			return parts[0];
		}

		return '(' + String.join(parts, ' ' + separator + ' ') + ')';
	}

	/**
	 * @description Formats a value for use in a formula expression.
	 *
	 * @param value The value to format
	 *
	 * @return The formatted value string or null if the type is unsupported
	 */
	@SuppressWarnings('PMD.CyclomaticComplexity')
	private static String formatValue(Object value)
	{
		if(value == null)
		{
			return null;
		}
		if(value instanceof String || value instanceof Id)
		{
			return '"' + escapeFormulaString(String.valueOf(value)) + '"';
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
			Date dateValue = (Date)value;
			return 'DATE(' + dateValue.year() + ', ' + dateValue.month() + ', ' + dateValue.day() + ')';
		}
		if(value instanceof Datetime)
		{
			return 'DATETIMEVALUE("' + UTIL_Date.toIso8601((Datetime)value) + '")';
		}

		return null;
	}

	/**
	 * @description Escapes special characters in a string for formula expressions.
	 *
	 * @param value The string to escape
	 *
	 * @return The escaped string
	 */
	private static String escapeFormulaString(String value)
	{
		return value.replace('"', '\\"');
	}
}