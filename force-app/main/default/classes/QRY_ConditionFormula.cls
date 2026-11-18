// SPDX-License-Identifier: Apache-2.0
/**
 * @description Translates QRY_Condition.Evaluable trees into FormulaEval-compatible
 * expression strings. Used by the mock filtering system to evaluate query conditions
 * against in-memory records via UTIL_FormulaFilter.
 *
 * Returns null when the condition tree contains unsupported elements (relationship
 * field traversals, INCLUDES/EXCLUDES operators, unknown Evaluable implementations),
 * signalling the caller to skip filtering and return all mocks.
 *
 * A formula cannot compare a picklist field with text as it is. So the translator looks up each field on the object
 * the query reads, and puts a picklist field inside TEXT(), which gives its value as text:
 * - TEXT() is used for equals, not equals, IN, NOT IN, a search for text in the field, and a check that the field is
 *   blank.
 * - Greater than and less than on a picklist field are not written as a formula, so they return null.
 *
 * A multi-select picklist field holds several values in one. A check that it is blank, or not blank, is written with
 * the field as it is. Any other condition on it returns null.
 *
 * A formula can hold at most 3,900 characters, and a formula with many comparisons takes long to check, so a long IN
 * or NOT IN list does not always fit in one formula. splitToFit splits such lists into shorter lists, one copy of the
 * condition for each, so the caller can filter with each copy and combine the results.
 *
 * @see QRY_Condition
 * @see QRY_Engine
 * @see QRY_ConditionFormula_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, November 2026
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
	 * @description The most characters one formula built here may have. Salesforce refuses a formula longer than 3,900
	 * characters; this limit stays 100 below that, so a small difference in how the platform counts never makes a formula
	 * fail. A test may lower it to split short lists. Internal seam, used only by QRY_ConditionFormula_TEST and
	 * QRY_Engine_TEST: it lets a test split a list short enough to also be checked as one formula, and compare the two.
	 */
	@TestVisible
	private static Integer maximumFormulaLength = 3800;

	/**
	 * @description The most comparisons one formula built here may have. Each comparison checks one value, such as one
	 * value of an IN list, against one field. A date and time value that is checked for equal or not equal is written as
	 * two comparisons, so it counts two. Salesforce builds a formula of 181 short comparisons, the most that fit in
	 * maximumFormulaLength characters. This limit is lower so that the time a formula takes stays small: checking one
	 * formula of 80 comparisons against 200 mock records takes about 60 milliseconds of processing time, and a formula of
	 * 160 comparisons about 110.
	 */
	@TestVisible
	private static final Integer MAXIMUM_COMPARISONS_PER_FORMULA = 80;

	/**
	 * @description The most formulas splitToFit plans for one condition. Planning stops at the next formula, so a very
	 * long list costs little time before it is given up.
	 */
	@TestVisible
	private static final Integer MAXIMUM_FORMULAS_PER_READ = 50;

	/**
	 * @description The parentheses around the formula of one IN or NOT IN list.
	 */
	private static final Integer LIST_PARENTHESES_LENGTH = 2;

	/**
	 * @description The pattern a date and time is written in, in GMT, inside DATETIMEVALUE. The letters are lower case
	 * where they must be: in an Apex pattern, upper-case YYYY means the year a week belongs to, and DD the day of the year.
	 */
	private static final String DATETIME_PATTERN = 'yyyy-MM-dd HH:mm:ss';

	/**
	 * @description How many formulas the running call to splitToFit has planned so far.
	 */
	private static Integer formulasPlanned = 0;

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
	 * @description The greater-than and less-than comparisons. On a picklist field they are not written as a formula, so
	 * a mocked read with one of them returns every mock.
	 */
	private static final Set<QRY_Condition.Operator> ORDER_OPERATORS = new Set<QRY_Condition.Operator>
	{
			QRY_Condition.Operator.GREATER_THAN,
			QRY_Condition.Operator.LESS_THAN,
			QRY_Condition.Operator.GREATER_THAN_OR_EQUAL_TO,
			QRY_Condition.Operator.LESS_THAN_OR_EQUAL_TO
	};

	/**
	 * @description Converts a condition tree into a FormulaEval-compatible expression string.
	 *
	 * @param condition The condition tree to translate
	 * @param objectType The object the condition reads. Its fields tell which ones are picklists. When it is null, or does
	 * not know a field, that field is written as it is.
	 *
	 * @return The formula expression string, or null if the condition contains unsupported elements
	 */
	public static String toFormula(QRY_Condition.Evaluable condition, SObjectType objectType)
	{
		if(condition == null)
		{
			return null;
		}

		return translateCondition(condition, objectType);
	}

	/**
	 * @description Plans how to check a condition with formulas that each have at most maximumFormulaLength characters
	 * and at most MAXIMUM_COMPARISONS_PER_FORMULA comparisons. When the formula of the whole condition fits, the plan is
	 * that one formula. When it does not fit, the condition is split at one IN or NOT IN list. Each part is a copy of the
	 * condition in which that list keeps only some of its values, in their order, and every other condition stays the
	 * same. A part that is still too large is split again. The condition you pass is not changed.
	 *
	 * How a list is chosen: the characters left once every other condition is counted are shared between the lists that
	 * have more than one value, and so are the comparisons left. A list smaller than an equal share keeps all its values
	 * and leaves the rest of its share to the other lists. Every larger list gets an equal share of what is left. The
	 * first list, from left to right, that is larger than its share of characters or of comparisons is split into lists
	 * that each fit in both shares. Equal shares keep the number of formulas low when two long lists must both be split.
	 *
	 * A record matches the whole IN condition when it matches any part, and the whole NOT IN condition when it matches
	 * every part. This holds wherever the list sits. A NOT condition, which turns a match into a miss, cannot be written
	 * as a formula: this method returns null for it, so a list inside a NOT is never split.
	 *
	 * @param condition The condition to plan.
	 * @param objectType The object the condition reads, as for toFormula.
	 *
	 * @return The plan, or null when the condition cannot be written as a formula, when the plan would need more than
	 * MAXIMUM_FORMULAS_PER_READ formulas, or when a part is still too large with one value left in each list (for
	 * example because one value alone is too long, or the condition has no list to split).
	 */
	public static ConditionPart splitToFit(QRY_Condition.Evaluable condition, SObjectType objectType)
	{
		String formula = toFormula(condition, objectType);
		if(formula == null)
		{
			return null;
		}

		formulasPlanned = 0;
		return planPart(condition, formula, objectType);
	}

	/**
	 * @description Plans one part of a condition: one formula when it fits, otherwise the part split at one of its lists.
	 * Counts each formula planned and stops as soon as there are too many, so a very large condition costs little.
	 *
	 * @param condition The part to plan.
	 * @param formula The formula of the whole part.
	 * @param objectType The object the condition reads.
	 *
	 * @return The plan of the part, or null when there are too many formulas or the part cannot be made to fit.
	 */
	private static ConditionPart planPart(QRY_Condition.Evaluable condition, String formula, SObjectType objectType)
	{
		Integer comparisonCount = countComparisons(condition);
		if(formula.length() <= maximumFormulaLength && comparisonCount <= MAXIMUM_COMPARISONS_PER_FORMULA)
		{
			formulasPlanned++;
			if(formulasPlanned > MAXIMUM_FORMULAS_PER_READ)
			{
				return null;
			}
			ConditionPart part = new ConditionPart(condition);
			part.formula = formula;
			part.formulaCount = 1;
			return part;
		}

		List<QRY_Condition.SetCondition> lists = new List<QRY_Condition.SetCondition>();
		collectListsToShare(condition, lists);
		List<Integer> listLengths = new List<Integer>();
		List<Integer> listSizes = new List<Integer>();
		Integer allListsLength = 0;
		Integer allListsSize = 0;
		for(QRY_Condition.SetCondition setCondition : lists)
		{
			Integer listLength = translateSetCondition(setCondition, objectType).length();
			listLengths.add(listLength);
			allListsLength += listLength;
			Integer listSize = countComparisons(setCondition);
			listSizes.add(listSize);
			allListsSize += listSize;
		}

		Integer shareLength = findShare(listLengths, maximumFormulaLength - (formula.length() - allListsLength));
		Integer shareSize = findShare(listSizes, MAXIMUM_COMPARISONS_PER_FORMULA - (comparisonCount - allListsSize));
		for(Integer index = 0; index < lists.size(); index++)
		{
			if(listLengths[index] > shareLength || listSizes[index] > shareSize)
			{
				return splitPart(new ConditionPart(condition), lists[index], shareLength, shareSize, objectType);
			}
		}

		return null;
	}

	/**
	 * @description Splits a part at one list into smaller parts whose list fits in the given number of characters and
	 * comparisons, and plans each smaller part.
	 *
	 * @param part The part to split. Its condition holds the list.
	 * @param longList The list to split.
	 * @param shareLength The most characters the formula of each shorter list may have. A value too long for it gets a
	 * list of its own.
	 * @param shareSize The most comparisons each shorter list may have. Each shorter list holds at least one value, even
	 * when that value alone is longer, or counts more comparisons, than the share allows.
	 * @param objectType The object the condition reads.
	 *
	 * @return The part, now holding the smaller parts in the order of the values, or null when a smaller part cannot be
	 * planned.
	 */
	private static ConditionPart splitPart(ConditionPart part, QRY_Condition.SetCondition longList, Integer shareLength, Integer shareSize, SObjectType objectType)
	{
		part.isMatchedByAnyPart = longList.operator == QRY_Condition.Operator.IN_X;
		for(List<Object> someValues : splitValues(longList, shareLength, shareSize, objectType))
		{
			QRY_Condition.SetCondition shortList = new QRY_Condition.SetCondition(longList.field, longList.operator, someValues);
			QRY_Condition.Evaluable smallerCondition = replaceList(part.condition, longList, shortList);
			ConditionPart smallerPart = planPart(smallerCondition, toFormula(smallerCondition, objectType), objectType);
			if(smallerPart == null)
			{
				return null;
			}
			part.parts.add(smallerPart);
			part.formulaCount += smallerPart.formulaCount;
		}
		return part;
	}

	/**
	 * @description Splits the values of a list into groups, in order, so that the formula of each group has at most the
	 * given number of characters and the group has at most the given number of comparisons. Each group holds at least one
	 * value, even when that value alone is longer, or counts more comparisons, than the share allows.
	 *
	 * @param longList The list whose values to split.
	 * @param shareLength The most characters the formula of each group may have.
	 * @param shareSize The most comparisons each group may have.
	 * @param objectType The object the condition reads.
	 *
	 * @return The groups of values, in the order of the values.
	 */
	private static List<List<Object>> splitValues(QRY_Condition.SetCondition longList, Integer shareLength, Integer shareSize, SObjectType objectType)
	{
		String joiner = findJoiner(longList.operator);
		String fieldReference = writeFieldReference(longList.field, longList.operator, false, objectType);
		List<List<Object>> groupsOfValues = new List<List<Object>>();
		List<Object> someValues = new List<Object>();
		Integer someValuesLength = LIST_PARENTHESES_LENGTH;
		Integer someValuesComparisons = 0;
		for(Object value : longList.values)
		{
			Integer valueLength = translateSetValue(fieldReference, longList.operator, value).length();
			Integer valueComparisons = countValueComparisons(value);
			Boolean isGroupFull = someValuesLength + joiner.length() + valueLength > shareLength || someValuesComparisons + valueComparisons > shareSize;
			if(!someValues.isEmpty() && isGroupFull)
			{
				groupsOfValues.add(someValues);
				someValues = new List<Object>();
				someValuesLength = LIST_PARENTHESES_LENGTH;
				someValuesComparisons = 0;
			}
			someValuesLength += (someValues.isEmpty() ? 0 : joiner.length()) + valueLength;
			someValuesComparisons += valueComparisons;
			someValues.add(value);
		}
		groupsOfValues.add(someValues);
		return groupsOfValues;
	}

	/**
	 * @description Works out how much of a limit each long list may use: characters, or comparisons. The lists are taken
	 * from smallest to largest. A list that is no larger than an equal share of what is still left keeps all its values,
	 * and its size is taken from what is left. What is then left is shared equally by the remaining lists.
	 *
	 * @param listSizes The size of each list: the length of its formula, or its number of comparisons.
	 * @param space What is left for all the lists once every other condition is counted. It can be zero or less.
	 *
	 * @return The most each remaining list may use. A list larger than this must be split. When every list fits, the
	 * whole space, since no list must be split for this limit.
	 */
	private static Integer findShare(List<Integer> listSizes, Integer space)
	{
		List<Integer> sortedSizes = listSizes.clone();
		sortedSizes.sort();
		Integer spaceLeft = space;
		Integer listsLeft = sortedSizes.size();
		for(Integer listSize : sortedSizes)
		{
			if(listSize * listsLeft > spaceLeft)
			{
				break;
			}
			spaceLeft -= listSize;
			listsLeft--;
		}

		return listsLeft == 0 ? space : spaceLeft / listsLeft;
	}

	/**
	 * @description Counts the comparisons in the formula of a condition: one for each value of an IN or NOT IN list, and
	 * one for each other condition. A date and time value that is checked for equal or not equal is written as two
	 * comparisons, so it counts two.
	 *
	 * @param condition The condition to count. It can be written as a formula.
	 *
	 * @return The number of comparisons.
	 */
	private static Integer countComparisons(QRY_Condition.Evaluable condition)
	{
		if(condition instanceof QRY_Condition.SetCondition)
		{
			Integer comparisonCount = 0;
			for(Object value : ((QRY_Condition.SetCondition)condition).values)
			{
				comparisonCount += countValueComparisons(value);
			}
			return comparisonCount;
		}
		if(condition instanceof QRY_Condition.ConditionGroup)
		{
			Integer comparisonCount = 0;
			for(QRY_Condition.Evaluable child : ((QRY_Condition.ConditionGroup)condition).conditions)
			{
				comparisonCount += countComparisons(child);
			}
			return comparisonCount;
		}

		QRY_Condition.FieldCondition fieldCondition = condition instanceof QRY_Condition.FieldCondition ? (QRY_Condition.FieldCondition)condition : null;
		Boolean isEqualityCheck = fieldCondition?.operator == QRY_Condition.Operator.EQUALS || fieldCondition?.operator == QRY_Condition.Operator.NOT_EQUALS;
		return isEqualityCheck ? countValueComparisons(fieldCondition.value) : 1;
	}

	/**
	 * @description Counts the comparisons written for one value that is checked for equal or not equal: two for a date and
	 * time, which writeComparison writes as at or after the start of its second and before the next second, and one for
	 * any other value.
	 *
	 * @param value The value.
	 *
	 * @return The number of comparisons.
	 */
	private static Integer countValueComparisons(Object value)
	{
		return isDatetimeWithTime(value) ? 2 : 1;
	}

	/**
	 * @description Checks whether a value is a date and time. Apex says a date is also a date and time when asked with
	 * instanceof, so a date is left out by name.
	 *
	 * @param value The value to check. It can be null.
	 *
	 * @return True when the value is a date and time and not a date.
	 */
	private static Boolean isDatetimeWithTime(Object value)
	{
		return value instanceof Datetime && !(value instanceof Date);
	}

	/**
	 * @description Collects, from left to right, the IN and NOT IN lists of a condition that have more than one value,
	 * since only those can be split.
	 *
	 * @param condition The condition to search.
	 * @param lists The list the found lists are added to.
	 */
	private static void collectListsToShare(QRY_Condition.Evaluable condition, List<QRY_Condition.SetCondition> lists)
	{
		if(condition instanceof QRY_Condition.SetCondition)
		{
			QRY_Condition.SetCondition setCondition = (QRY_Condition.SetCondition)condition;
			Boolean isInOrNotIn = setCondition.operator == QRY_Condition.Operator.IN_X || setCondition.operator == QRY_Condition.Operator.NOT_IN;
			Boolean hasValuesToSplit = setCondition.values != null && setCondition.values.size() > 1;
			if(isInOrNotIn && hasValuesToSplit)
			{
				lists.add(setCondition);
			}
		}
		else if(condition instanceof QRY_Condition.ConditionGroup)
		{
			for(QRY_Condition.Evaluable child : ((QRY_Condition.ConditionGroup)condition).conditions)
			{
				collectListsToShare(child, lists);
			}
		}
	}

	/**
	 * @description Copies a condition with one list put in the place of another. Every AND and OR group in the condition
	 * is copied, also the groups that do not hold the list; the conditions inside the groups that are not groups
	 * themselves are shared with the original. The original is not changed.
	 *
	 * @param condition The condition to copy.
	 * @param longList The list to take out.
	 * @param shortList The list to put in its place.
	 *
	 * @return The copy; the short list when the condition is the long list; or the condition itself when it is neither a
	 * group nor the long list.
	 */
	private static QRY_Condition.Evaluable replaceList(QRY_Condition.Evaluable condition, QRY_Condition.SetCondition longList, QRY_Condition.SetCondition shortList)
	{
		if(condition === longList)
		{
			return shortList;
		}
		if(condition instanceof QRY_Condition.ConditionGroup)
		{
			QRY_Condition.ConditionGroup copy = condition instanceof QRY_Condition.OrCondition
					? (QRY_Condition.ConditionGroup)new QRY_Condition.OrCondition()
					: (QRY_Condition.ConditionGroup)new QRY_Condition.AndCondition();
			for(QRY_Condition.Evaluable child : ((QRY_Condition.ConditionGroup)condition).conditions)
			{
				copy.add(replaceList(child, longList, shortList));
			}
			return copy;
		}

		return condition;
	}

	/**
	 * @description A plan for checking a condition, or one part of it, with formulas that fit. A part either has one
	 * formula, or it is split into smaller parts at one IN or NOT IN list.
	 */
	public inherited sharing class ConditionPart
	{
		/**
		 * @description The condition of this part.
		 */
		public QRY_Condition.Evaluable condition {get; private set;}

		/**
		 * @description The formula that checks this part, or null when the part is split into smaller parts.
		 */
		public String formula {get; private set;}

		/**
		 * @description The smaller parts, one for each group of values from the split list, in the order of the values.
		 * Empty when the part has one formula.
		 */
		public List<ConditionPart> parts {get; private set;}

		/**
		 * @description True when the split list is an IN list: a record matches this part when it matches any smaller
		 * part. False for a NOT IN list: a record matches this part only when it matches every smaller part. Null when the
		 * part is not split.
		 */
		public Boolean isMatchedByAnyPart {get; private set;}

		/**
		 * @description How many formulas this part needs, its smaller parts included.
		 */
		public Integer formulaCount {get; private set;}

		/**
		 * @description Creates a part with no formula and no smaller parts yet.
		 *
		 * @param condition The condition of this part.
		 */
		private ConditionPart(QRY_Condition.Evaluable condition)
		{
			this.condition = condition;
			parts = new List<ConditionPart>();
			formulaCount = 0;
		}
	}

	/**
	 * @description Dispatches condition translation based on the concrete type.
	 *
	 * @param condition The condition to translate
	 * @param objectType The object the condition reads.
	 *
	 * @return The formula string or null if unsupported
	 */
	private static String translateCondition(QRY_Condition.Evaluable condition, SObjectType objectType)
	{
		if(condition instanceof QRY_Condition.FieldCondition)
		{
			return translateFieldCondition((QRY_Condition.FieldCondition)condition, objectType);
		}
		if(condition instanceof QRY_Condition.SetCondition)
		{
			return translateSetCondition((QRY_Condition.SetCondition)condition, objectType);
		}
		if(condition instanceof QRY_Condition.AndCondition)
		{
			return translateGroup((QRY_Condition.ConditionGroup)condition, '&&', objectType);
		}
		if(condition instanceof QRY_Condition.OrCondition)
		{
			return translateGroup((QRY_Condition.ConditionGroup)condition, '||', objectType);
		}

		return null;
	}

	/**
	 * @description Translates a FieldCondition into a formula expression.
	 *
	 * @param condition The field condition
	 * @param objectType The object the condition reads.
	 *
	 * @return The formula string or null if the field path is unsupported
	 */
	private static String translateFieldCondition(QRY_Condition.FieldCondition condition, SObjectType objectType)
	{
		String field = condition.field;

		if(field == null || field.contains('.'))
		{
			return null;
		}

		QRY_Condition.Operator operator = condition.operator;
		Object value = condition.value;
		Boolean isBlankCheck = value == null && (operator == QRY_Condition.Operator.EQUALS || operator == QRY_Condition.Operator.NOT_EQUALS);
		String fieldReference = writeFieldReference(field, operator, isBlankCheck, objectType);
		if(fieldReference == null)
		{
			return null;
		}

		if(isBlankCheck)
		{
			return operator == QRY_Condition.Operator.EQUALS ? 'ISBLANK(' + fieldReference + ')' : 'NOT(ISBLANK(' + fieldReference + '))';
		}

		String formulaValue = formatValue(value);
		if(formulaValue == null)
		{
			return null;
		}

		if(operator == QRY_Condition.Operator.LIKE_X)
		{
			return translateLike(fieldReference, value);
		}

		return writeComparison(fieldReference, operator, value, formulaValue);
	}

	/**
	 * @description Writes one comparison of a field with a value. A date and time is compared at whole seconds, as the
	 * database does: the database keeps no milliseconds, so it treats every time inside one second as the start of that
	 * second. The value is already written without its milliseconds (see formatValue). The record's own time still has
	 * its milliseconds, so the comparison is written against the start of the value's second and the start of the next
	 * second. For example, at or before the value becomes before the next second, and equals becomes at or after the
	 * value and before the next second. The record is never changed. A date without a time is compared as it is: Apex
	 * says a date is also a date and time when asked with instanceof, so the check leaves dates out by name.
	 *
	 * @param fieldReference How the formula reads the field, from writeFieldReference.
	 * @param operator The comparison: equals, not equals, greater than, greater than or equal to, less than, or less than or
	 * equal to.
	 * @param value The value to compare with. It is not null.
	 * @param formulaValue The value as formatValue writes it.
	 *
	 * @return The comparison.
	 */
	private static String writeComparison(String fieldReference, QRY_Condition.Operator operator, Object value, String formulaValue)
	{
		if(!isDatetimeWithTime(value))
		{
			return fieldReference + ' ' + OPERATOR_MAP.get(operator) + ' ' + formulaValue;
		}

		String nextSecond = formatValue(((Datetime)value).addSeconds(1));
		String insideTheSecond = '(' + fieldReference + ' >= ' + formulaValue + ' && ' + fieldReference + ' < ' + nextSecond + ')';
		switch on operator
		{
			when EQUALS
			{
				return insideTheSecond;
			}
			when NOT_EQUALS
			{
				return 'NOT' + insideTheSecond;
			}
			when LESS_THAN_OR_EQUAL_TO
			{
				return fieldReference + ' < ' + nextSecond;
			}
			when GREATER_THAN
			{
				return fieldReference + ' >= ' + nextSecond;
			}
			when else
			{
				return fieldReference + ' ' + OPERATOR_MAP.get(operator) + ' ' + formulaValue;
			}
		}
	}

	/**
	 * @description Writes how a formula reads a field of the record. A picklist field is put inside TEXT(), which gives
	 * its value as text, because a formula cannot compare a picklist field with text as it is. Any other field, and a
	 * field the object does not know, is read as it is.
	 *
	 * A multi-select picklist field holds several values in one. A check that it is blank, or not blank, reads the field
	 * as it is. Any other comparison on it is not written as a formula.
	 *
	 * @param field The name of the field.
	 * @param operator The comparison the condition makes.
	 * @param isBlankCheck True when the condition checks that the field is blank, or is not blank.
	 * @param objectType The object the condition reads. It can be null.
	 *
	 * @return How the formula reads the field, or null when the comparison is not written as a formula: a comparison on
	 * a multi-select picklist field that is not a blank check, and greater than or less than on a picklist field.
	 */
	private static String writeFieldReference(String field, QRY_Condition.Operator operator, Boolean isBlankCheck, SObjectType objectType)
	{
		SObjectField fieldToken = UTIL_SObjectDescribe.getDescribe(objectType)?.getField(field);
		DisplayType fieldType = UTIL_SObjectDescribe.getCachedFieldDescribe(fieldToken)?.getType();

		if(fieldType == DisplayType.MULTIPICKLIST)
		{
			return isBlankCheck ? RECORD_PREFIX + field : null;
		}
		if(fieldType == DisplayType.PICKLIST && ORDER_OPERATORS.contains(operator))
		{
			return null;
		}

		return fieldType == DisplayType.PICKLIST ? 'TEXT(' + RECORD_PREFIX + field + ')' : RECORD_PREFIX + field;
	}

	/**
	 * @description Translates a LIKE condition into a CONTAINS formula expression.
	 * Only supports the %value% pattern (contains). Other LIKE patterns return null.
	 *
	 * In a LIKE pattern a backslash makes the next character plain text: containsLiteral writes a backslash as two
	 * backslashes, and a percent sign or an underscore with a backslash in front. These escapes are undone first, so the
	 * formula looks for the text itself. A percent sign or an underscore without a backslash in the middle of the pattern
	 * stands for any characters in a real query, which CONTAINS cannot express. It is searched for as plain text, so
	 * contains('ACME_West') finds a mock named ACME_West and not one named ACMEXWest.
	 *
	 * @param fieldReference How the formula reads the field, from writeFieldReference.
	 * @param value The LIKE pattern value
	 *
	 * @return The CONTAINS formula or null if the pattern is not a simple contains
	 */
	private static String translateLike(String fieldReference, Object value)
	{
		if(!(value instanceof String))
		{
			return null;
		}

		String pattern = (String)value;

		if(pattern.startsWith('%') && pattern.endsWith('%') && pattern.length() > 2)
		{
			String searchValue = removeLikeEscapes(pattern.substring(1, pattern.length() - 1));
			return searchValue == null ? null : 'CONTAINS(' + fieldReference + ', "' + escapeFormulaString(searchValue) + '")';
		}

		return null;
	}

	/**
	 * @description Turns the middle of a LIKE pattern back into the plain text it looks for. A backslash followed by any
	 * character stands for that character. Every other character, a percent sign or an underscore too, stays as it is.
	 *
	 * @param likeText The pattern without its first and last percent sign.
	 *
	 * @return The plain text, or null when the pattern ends in a lone backslash (which makes the last percent sign plain
	 * text, so the pattern is not a search for text anywhere in the field).
	 */
	private static String removeLikeEscapes(String likeText)
	{
		List<String> plainCharacters = new List<String>();
		for(Integer index = 0; index < likeText.length(); index++)
		{
			String character = likeText.substring(index, index + 1);
			if(character == '\\')
			{
				index++;
				if(index == likeText.length())
				{
					return null;
				}
				plainCharacters.add(likeText.substring(index, index + 1));
			}
			else
			{
				plainCharacters.add(character);
			}
		}

		return String.join(plainCharacters, '');
	}

	/**
	 * @description Translates a SetCondition (IN/NOT IN) into a formula expression.
	 *
	 * @param condition The set condition
	 * @param objectType The object the condition reads.
	 *
	 * @return The formula string or null if the operator is unsupported
	 */
	private static String translateSetCondition(QRY_Condition.SetCondition condition, SObjectType objectType)
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

		String fieldReference = writeFieldReference(field, operator, false, objectType);
		if(condition.builder != null || fieldReference == null)
		{
			return null;
		}

		List<String> parts = new List<String>();
		for(Object value : condition.values)
		{
			String part = translateSetValue(fieldReference, operator, value);
			if(part == null)
			{
				return null;
			}
			parts.add(part);
		}

		return '(' + String.join(parts, findJoiner(operator)) + ')';
	}

	/**
	 * @description Translates one value of an IN or NOT IN list into a comparison: equal for IN, not equal for NOT IN.
	 *
	 * @param fieldReference How the formula reads the field, from writeFieldReference.
	 * @param operator IN_X or NOT_IN.
	 * @param value The value to compare with.
	 *
	 * @return The comparison, or null when the value has a type a formula cannot hold.
	 */
	private static String translateSetValue(String fieldReference, QRY_Condition.Operator operator, Object value)
	{
		String formulaValue = formatValue(value);
		if(formulaValue == null)
		{
			return null;
		}

		QRY_Condition.Operator comparison = operator == QRY_Condition.Operator.IN_X ? QRY_Condition.Operator.EQUALS : QRY_Condition.Operator.NOT_EQUALS;
		return writeComparison(fieldReference, comparison, value, formulaValue);
	}

	/**
	 * @description Finds the text that joins the comparisons of an IN or NOT IN list: or for IN, and for NOT IN.
	 *
	 * @param operator IN_X or NOT_IN.
	 *
	 * @return The joining text, with a space on each side.
	 */
	private static String findJoiner(QRY_Condition.Operator operator)
	{
		return operator == QRY_Condition.Operator.IN_X ? ' || ' : ' && ';
	}

	/**
	 * @description Translates a condition group (AND/OR) into a formula expression.
	 *
	 * @param conditionGroup The condition group
	 * @param separator The logical operator string (&& or ||)
	 * @param objectType The object the condition reads.
	 *
	 * @return The formula string or null if any child condition is unsupported
	 */
	private static String translateGroup(QRY_Condition.ConditionGroup conditionGroup, String separator, SObjectType objectType)
	{
		if(conditionGroup.conditions == null || conditionGroup.conditions.isEmpty())
		{
			return null;
		}

		List<String> parts = new List<String>();
		for(QRY_Condition.Evaluable child : conditionGroup.conditions)
		{
			String childFormula = translateCondition(child, objectType);
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
	 * @description Formats a value for use in a formula expression. A date and time is written as
	 * DATETIMEVALUE("yyyy-MM-dd HH:mm:ss"), with the time in GMT. The formula engine reads that text as GMT, whatever
	 * time zone the running user has. The text holds whole seconds only, so the milliseconds of the value are left out.
	 * Both sides are compared at whole seconds, as the database does: writeComparison compares the record's time as if
	 * its milliseconds were left out too.
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
			return 'DATETIMEVALUE("' + ((Datetime)value).formatGmt(DATETIME_PATTERN) + '")';
		}

		return null;
	}

	/**
	 * @description Escapes a string for a formula: each backslash becomes two backslashes first, then each double quote
	 * gets a backslash in front, so a value that ends in a backslash or holds a quote stays one string in the formula.
	 *
	 * @param value The string to escape
	 *
	 * @return The escaped string
	 */
	private static String escapeFormulaString(String value)
	{
		return value.replace('\\', '\\\\').replace('"', '\\"');
	}
}