// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Provides pre-built comparators for sorting lists of Objects and SObjects.
 * Includes comparators for primitive types and SObject fields, supporting customizable sort orders.
 *
 * @see UTIL_Comparators_TEST
 * @see Comparator
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date 2012, June 2026
 */
@SuppressWarnings('PMD.ExcessivePublicCount,PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters')
public inherited sharing class UTIL_Comparators
{
	/**
	 * @description Abstract comparator for sorting Object collections, such as integers or strings.
	 */
	public abstract class ObjectComparator implements Comparator<Object>
	{
		/**
		 * @description Determines whether the sort order is ascending (true) or descending (false).
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.sortAscending;
		 * ```
		 */
		public Boolean sortAscending;

		/**
		 * @description Compares two objects to determine their sort order.
		 * Must be implemented by child classes.
		 *
		 * @param firstObject The first object to compare.
		 * @param secondObject The second object to compare.
		 *
		 * @return Integer Returns 0 if objects are equal, 1 if firstObject is greater, or -1 if firstObject is less.
		 *
		 * @example
		 * ```apex
		 * public class CustomComparator extends UTIL_Comparators.ObjectComparator
		 * {
		 *     public override Integer compare(Object first, Object second)
		 *     {
		 *         String firstVal = (String)first;
		 *         String secondVal = (String)second;
		 *         return firstVal.compareTo(secondVal);
		 *     }
		 * }
		 * ```
		 */
		public abstract Integer compare(Object firstObject, Object secondObject);

		/**
		 * @description Default constructor, sets ascending sort order.
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.ObjectComparator instance = new UTIL_Comparators.ObjectComparator();
		 * ```
		 */
		public ObjectComparator()
		{
			sortAscending = true;
		}

		/**
		 * @description Constructor with specified sort order.
		 *
		 * @param isSortAscending Indicates the sort order (true for ascending, false for descending).
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.ObjectComparator instance = new UTIL_Comparators.ObjectComparator(true);
		 * ```
		 */
		public ObjectComparator(Boolean isSortAscending)
		{
			this();
			this.sortAscending = isSortAscending;
		}
	}

	/**
	 * @description Abstract comparator for sorting SObject collections, such as Accounts or Contacts.
	 */
	public abstract class SObjectComparator implements Comparator<SObject>
	{
		/**
		 * @description Determines whether the sort order is ascending (true) or descending (false).
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.sortAscending;
		 * ```
		 */
		public Boolean sortAscending;

		/**
		 * @description Compares two SObject records to determine their sort order.
		 * Must be implemented by child classes.
		 *
		 * @param firstRecord The first SObject record to compare.
		 * @param secondRecord The second SObject record to compare.
		 *
		 * @return Integer Returns 0 if records are equal, 1 if firstRecord is greater, or -1 if firstRecord is less.
		 *
		 * @example
		 * ```apex
		 * public class AccountRevenueComparator extends UTIL_Comparators.SObjectComparator
		 * {
		 *     public override Integer compare(SObject first, SObject second)
		 *     {
		 *         Decimal firstRevenue = (Decimal)first.get('AnnualRevenue');
		 *         Decimal secondRevenue = (Decimal)second.get('AnnualRevenue');
		 *         return firstRevenue < secondRevenue ? -1 : firstRevenue > secondRevenue ? 1 : 0;
		 *     }
		 * }
		 * ```
		 */
		public abstract Integer compare(SObject firstRecord, SObject secondRecord);

		/**
		 * @description Default constructor, sets ascending sort order.
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.SObjectComparator instance = new UTIL_Comparators.SObjectComparator();
		 * ```
		 */
		public SObjectComparator()
		{
			sortAscending = true;
		}
	}

	/**
	 * @description Comparator for sorting collections of primitive types (e.g., Boolean, Date, Integer, String).
	 */
	@SuppressWarnings('PMD.CognitiveComplexity, PMD.CyclomaticComplexity')
	public virtual class PrimitiveComparator extends ObjectComparator
	{
		/**
		 * @description Default constructor, sets ascending sort order.
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.PrimitiveComparator instance = new UTIL_Comparators.PrimitiveComparator();
		 * ```
		 */
		public PrimitiveComparator()
		{
			super();
		}

		/**
		 * @description Constructor with specified sort order.
		 *
		 * @param isSortAscending Indicates the sort order (true for ascending, false for descending).
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.PrimitiveComparator instance = new UTIL_Comparators.PrimitiveComparator(true);
		 * ```
		 */
		public PrimitiveComparator(Boolean isSortAscending)
		{
			super(isSortAscending);
		}

		/**
		 * @description Compares two primitive objects to determine their sort order.
		 *
		 * @param firstObject The first object to compare.
		 * @param secondObject The second object to compare.
		 *
		 * @return Integer Returns 0 if objects are equal, 1 if firstObject is greater, or -1 if firstObject is less.
		 *
		 * @throws IllegalArgumentException If objects are not of supported primitive types or not the same type.
		 *
		 * @example
		 * ```apex
		 * List<Object> numbers = new List<Object>{3, 1, 2};
		 * UTIL_Comparators.PrimitiveComparator comparator = new UTIL_Comparators.PrimitiveComparator(true);
		 * List<Object> sorted = UTIL_List.sort(numbers, comparator);
		 * System.debug(sorted); // Outputs: [1, 2, 3]
		 * ```
		 */
		@SuppressWarnings('ApexUnnecessaryCast,PMD.CyclomaticComplexity')
		public virtual override Integer compare(Object firstObject, Object secondObject)
		{
			Integer compareResult;

			if(firstObject == null && secondObject == null)
			{
				compareResult = 0;
			}
			else if(firstObject == null)
			{
				compareResult = -1;
			}
			else if(secondObject == null)
			{
				compareResult = 1;
			}
			else if(firstObject instanceof Boolean && secondObject instanceof Boolean)
			{
				compareResult = compare((Boolean)firstObject, (Boolean)secondObject);
			}
			else if(firstObject instanceof Date && secondObject instanceof Date)
			{
				compareResult = compare((Date)firstObject, (Date)secondObject);
			}
			else if(firstObject instanceof Datetime && secondObject instanceof Datetime)
			{
				compareResult = compare((Datetime)firstObject, (Datetime)secondObject);
			}
			else if(firstObject instanceof Integer && secondObject instanceof Integer)
			{
				compareResult = compare((Integer)firstObject, (Integer)secondObject);
			}
			else if(firstObject instanceof Long && secondObject instanceof Long)
			{
				compareResult = compare((Long)firstObject, (Long)secondObject);
			}
			else if(firstObject instanceof Double && secondObject instanceof Double)
			{
				compareResult = compare((Double)firstObject, (Double)secondObject);
			}
			else if(firstObject instanceof Time && secondObject instanceof Time)
			{
				compareResult = compare((Time)firstObject, (Time)secondObject);
			}
			else if(firstObject instanceof String && secondObject instanceof String)
			{
				compareResult = compare((String)firstObject, (String)secondObject);
			}
			else
			{
				throw new IllegalArgumentException('Both arguments must be type Boolean, Date, Datetime, Decimal, Double, Id, Integer, Long, Time, or String');
			}

			return getSortedCompareResult(compareResult, sortAscending);
		}

		/**
		 * @description Compares two Boolean values.
		 *
		 * @param firstBoolean The first Boolean to compare.
		 * @param secondBoolean The second Boolean to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstBoolean is true and secondBoolean is false, or -1 otherwise.
		 */
		@SuppressWarnings('ApexIllegalAssignment')
		private Integer compare(Boolean firstBoolean, Boolean secondBoolean)
		{
			if(!firstBoolean && secondBoolean)
			{
				return -1;
			}
			else if(firstBoolean == secondBoolean)
			{
				return 0;
			}
			else
			{
				return 1;
			}
		}

		/**
		 * @description Compares two Date values.
		 *
		 * @param firstDate The first Date to compare.
		 * @param secondDate The second Date to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstDate is later, or -1 if firstDate is earlier.
		 */
		private Integer compare(Date firstDate, Date secondDate)
		{
			if(firstDate < secondDate)
			{
				return -1;
			}
			else if(firstDate == secondDate)
			{
				return 0;
			}
			else
			{
				return 1;
			}
		}

		/**
		 * @description Compares two Datetime values.
		 *
		 * @param firstDatetime The first Datetime to compare.
		 * @param secondDatetime The second Datetime to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstDatetime is later, or -1 if firstDatetime is earlier.
		 */
		private Integer compare(Datetime firstDatetime, Datetime secondDatetime)
		{
			if(firstDatetime < secondDatetime)
			{
				return -1;
			}
			else if(firstDatetime == secondDatetime)
			{
				return 0;
			}
			else
			{
				return 1;
			}
		}

		/**
		 * @description Compares two Double values.
		 *
		 * @param firstDouble The first Double to compare.
		 * @param secondDouble The second Double to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstDouble is greater, or -1 if firstDouble is less.
		 */
		private Integer compare(Double firstDouble, Double secondDouble)
		{
			if(firstDouble < secondDouble)
			{
				return -1;
			}
			else if(firstDouble == secondDouble)
			{
				return 0;
			}
			return 1;
		}

		/**
		 * @description Compares two Integer values.
		 *
		 * @param firstInteger The first Integer to compare.
		 * @param secondInteger The second Integer to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstInteger is greater, or -1 if firstInteger is less.
		 */
		private Integer compare(Integer firstInteger, Integer secondInteger)
		{
			if(firstInteger < secondInteger)
			{
				return -1;
			}
			else if(firstInteger == secondInteger)
			{
				return 0;
			}
			return 1;
		}

		/**
		 * @description Compares two Long values.
		 *
		 * @param firstLong The first Long to compare.
		 * @param secondLong The second Long to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstLong is greater, or -1 if firstLong is less.
		 */
		private Integer compare(Long firstLong, Long secondLong)
		{
			if(firstLong < secondLong)
			{
				return -1;
			}
			else if(firstLong == secondLong)
			{
				return 0;
			}
			return 1;
		}

		/**
		 * @description Compares two String values.
		 *
		 * @param firstString The first String to compare.
		 * @param secondString The second String to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstString is lexicographically greater, or -1 if less.
		 */
		private Integer compare(String firstString, String secondString)
		{
			if(firstString < secondString)
			{
				return -1;
			}
			else if(firstString == secondString)
			{
				return 0;
			}
			return 1;
		}

		/**
		 * @description Compares two Time values by converting to strings.
		 *
		 * @param firstTime The first Time to compare.
		 * @param secondTime The second Time to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstTime is later, or -1 if firstTime is earlier.
		 */
		private Integer compare(Time firstTime, Time secondTime)
		{
			return compare(UTIL_String.EMPTY + firstTime, UTIL_String.EMPTY + secondTime);
		}
	}

	/**
	 * @description Comparator for sorting SObject collections by a specific field.
	 */
	public inherited sharing class SObjectFieldComparator extends SObjectComparator
	{
		/**
		 * @description The PrimitiveComparator used for field value comparison.
		 */
		private final PrimitiveComparator comparator;

		/**
		 * @description The field name to sort by.
		 */
		private final String sortFieldName;

		/**
		 * @description Default constructor, initializes with null field and ascending order.
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.SObjectFieldComparator instance = new UTIL_Comparators.SObjectFieldComparator();
		 * ```
		 */
		public SObjectFieldComparator()
		{
			this(null, null);
		}

		/**
		 * @description Constructor with specified sort field.
		 *
		 * @param sortFieldName The field name to sort by.
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.SObjectFieldComparator instance = new UTIL_Comparators.SObjectFieldComparator('value');
		 * ```
		 */
		public SObjectFieldComparator(String sortFieldName)
		{
			this(sortFieldName, null);
		}

		/**
		 * @description Constructor with specified sort field and order.
		 *
		 * @param sortFieldName The field name to sort by.
		 * @param isSortAscending Indicates the sort order (true for ascending, false for descending).
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.SObjectFieldComparator instance = new UTIL_Comparators.SObjectFieldComparator('value', true);
		 * ```
		 */
		public SObjectFieldComparator(String sortFieldName, Boolean isSortAscending)
		{
			super();
			this.sortFieldName = sortFieldName;
			this.sortAscending = isSortAscending;
			comparator = new PrimitiveComparator(isSortAscending);
		}

		/**
		 * @description Compares two SObject records based on the specified field.
		 *
		 * @param firstRecord The first SObject record to compare.
		 * @param secondRecord The second SObject record to compare.
		 *
		 * @return Integer Returns 0 if equal, 1 if firstRecord's field value is greater, or -1 if less.
		 *
		 * @throws IllegalArgumentException If the sort field is blank.
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = [SELECT Name FROM Account LIMIT 3];
		 * UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator('Name', true);
		 * List<SObject> sorted = UTIL_List.sort(accounts, comparator);
		 * System.debug(sorted); // Outputs: Accounts sorted by Name
		 * ```
		 */
		@SuppressWarnings('PMD.CognitiveComplexity')
		public virtual override Integer compare(SObject firstRecord, SObject secondRecord)
		{
			Integer compareResult;

			if(firstRecord == null || secondRecord == null)
			{
				if(firstRecord == null && secondRecord == null)
				{
					compareResult = 0;
				}
				else if(firstRecord == null)
				{
					compareResult = -1;
				}
				else if(secondRecord == null)
				{
					compareResult = 1;
				}

				return getSortedCompareResult(compareResult, sortAscending);
			}
			else
			{
				if(String.isBlank(sortFieldName))
				{
					throw new IllegalArgumentException('sortBy cannot be blank');
				}

				comparator.sortAscending = sortAscending;
				return comparator.compare(firstRecord.get(sortFieldName), secondRecord.get(sortFieldName));
			}
		}

		/**
		 * @description Sorts a list of SObjects by the Name field in ascending order.
		 *
		 * @param sObjectList The list of SObjects to sort.
		 *
		 * @return List<SObject> The sorted list of SObjects.
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = [SELECT Name FROM Account LIMIT 3];
		 * UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator();
		 * List<SObject> sorted = comparator.sortSObjects(accounts);
		 * System.debug(sorted); // Outputs: Accounts sorted by Name
		 * ```
		 */
		public List<SObject> sortSObjects(List<SObject> sObjectList)
		{
			return sortSObjects(sObjectList, null, null);
		}

		/**
		 * @description Sorts a list of SObjects by the specified field in ascending order.
		 *
		 * @param sObjectList The list of SObjects to sort.
		 * @param sortFieldName The field name to sort by.
		 *
		 * @return List<SObject> The sorted list of SObjects.
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = [SELECT Name FROM Account LIMIT 3];
		 * UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator();
		 * List<SObject> sorted = comparator.sortSObjects(accounts, 'Name');
		 * System.debug(sorted); // Outputs: Accounts sorted by Name
		 * ```
		 */
		public List<SObject> sortSObjects(List<SObject> sObjectList, String sortFieldName)
		{
			return sortSObjects(sObjectList, sortFieldName, null);
		}

		/**
		 * @description Sorts a list of SObjects by the Name field with specified sort order.
		 *
		 * @param sObjectList The list of SObjects to sort.
		 * @param isSortAscending The sort order (true for ascending, false for descending).
		 *
		 * @return List<SObject> The sorted list of SObjects.
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = [SELECT Name FROM Account LIMIT 3];
		 * UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator();
		 * List<SObject> sorted = comparator.sortSObjects(accounts, false);
		 * System.debug(sorted); // Outputs: Accounts sorted by Name in descending order
		 * ```
		 */
		public List<SObject> sortSObjects(List<SObject> sObjectList, Boolean isSortAscending)
		{
			return sortSObjects(sObjectList, null, isSortAscending);
		}

		/**
		 * @description Sorts a list of SObjects by the specified field and sort order.
		 *
		 * @param sObjectList The list of SObjects to sort.
		 * @param sortFieldName The field name to sort by.
		 * @param isSortAscending The sort order (true for ascending, false for descending).
		 *
		 * @return List<SObject> The sorted list of SObjects.
		 *
		 * @example
		 * ```apex
		 * List<Account> accounts = [SELECT Name FROM Account LIMIT 3];
		 * UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator();
		 * List<SObject> sorted = comparator.sortSObjects(accounts, 'Name', true);
		 * System.debug(sorted); // Outputs: Accounts sorted by Name in ascending order
		 * ```
		 */
		public List<SObject> sortSObjects(List<SObject> sObjectList, String sortFieldName, Boolean isSortAscending)
		{
			if(String.isBlank(sortFieldName))
			{
				sortFieldName = 'Name';
			}

			if(isSortAscending == null)
			{
				isSortAscending = true;
			}

			return UTIL_List.sort(sObjectList, new SObjectFieldComparator(sortFieldName, isSortAscending));
		}
	}

	/**
	 * @description Starts a fluent, type-safe sort chain with an ascending first key. Add further
	 * tie-break keys with `thenBy` or
	 * `thenByDescending`. The returned chain is itself a
	 * `System.Comparator<SObject>`, so it can be passed straight to `List.sort`.
	 *
	 * @param field The field token for the highest-priority sort key; resolved to its namespace-safe
	 * API name.
	 *
	 * @return SObjectFieldChainComparator A new chain seeded with the given field, ascending.
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * contacts.sort(UTIL_Comparators.orderBy(Contact.LastName).thenBy(Contact.FirstName));
	 * ```
	 */
	public static SObjectFieldChainComparator orderBy(SObjectField field)
	{
		return new SObjectFieldChainComparator().thenBy(field);
	}

	/**
	 * @description Starts a fluent, type-safe sort chain with a descending first key. Add further
	 * tie-break keys with `thenBy` or
	 * `thenByDescending`. The returned chain is itself a
	 * `System.Comparator<SObject>`, so it can be passed straight to `List.sort`.
	 *
	 * @param field The field token for the highest-priority sort key; resolved to its namespace-safe
	 * API name.
	 *
	 * @return SObjectFieldChainComparator A new chain seeded with the given field, descending.
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * opportunities.sort(UTIL_Comparators.orderByDescending(Opportunity.Amount).thenBy(Opportunity.Name));
	 * ```
	 */
	public static SObjectFieldChainComparator orderByDescending(SObjectField field)
	{
		return new SObjectFieldChainComparator().thenByDescending(field);
	}

	/**
	 * @description Fluent, type-safe comparator that sorts an SObject collection by several fields in
	 * priority order. Start a chain with `orderBy` or
	 * `orderByDescending`, then add further tie-break keys with `thenBy` or
	 * `thenByDescending`. Each key delegates to a `SObjectFieldComparator`, so the null
	 * handling and ascending/descending semantics are identical to single-field sorting. When two
	 * records compare equal on a key, the next key in the chain decides; the first key that produces a
	 * non-zero result wins, and records that tie on every key are treated as equal. Because the chain
	 * is itself a `SObjectComparator` (and therefore a `System.Comparator<SObject>`), it drops
	 * straight into `List.sort`.
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * accounts.sort(
	 *     UTIL_Comparators.orderBy(Account.Industry)
	 *         .thenByDescending(Account.AnnualRevenue)
	 *         .thenBy(Account.Name));
	 * ```
	 */
	public inherited sharing class SObjectFieldChainComparator extends SObjectComparator
	{
		/**
		 * @description The ordered sort keys, each a single-field comparator, evaluated in priority order.
		 */
		private final List<SObjectFieldComparator> keyComparators;

		/**
		 * @description Constructs an empty chain. Seed it with a first key through
		 * `orderBy` or `orderByDescending` rather than constructing
		 * it directly.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.SObjectFieldChainComparator chain = UTIL_Comparators.orderBy(Account.Name);
		 * ```
		 */
		private SObjectFieldChainComparator()
		{
			super();
			keyComparators = new List<SObjectFieldComparator>();
		}

		/**
		 * @description Appends an ascending sort key and returns this chain so calls can be chained.
		 *
		 * @param field The field token to sort by; resolved to its namespace-safe API name.
		 *
		 * @return SObjectFieldChainComparator This chain, with the ascending key appended.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.orderBy(Account.Industry).thenBy(Account.Name);
		 * ```
		 */
		public SObjectFieldChainComparator thenBy(SObjectField field)
		{
			return addKey(field, true);
		}

		/**
		 * @description Appends a descending sort key and returns this chain so calls can be chained.
		 *
		 * @param field The field token to sort by; resolved to its namespace-safe API name.
		 *
		 * @return SObjectFieldChainComparator This chain, with the descending key appended.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * UTIL_Comparators.orderBy(Account.Industry).thenByDescending(Account.AnnualRevenue);
		 * ```
		 */
		public SObjectFieldChainComparator thenByDescending(SObjectField field)
		{
			return addKey(field, false);
		}

		/**
		 * @description Appends a single sort key for the given field and direction, resolving the field
		 * token to its namespace-safe API name via UTIL_SObjectDescribe.getCachedFieldName.
		 *
		 * @param field The field token to sort by.
		 * @param isAscending The sort direction for this key (true ascending, false descending).
		 *
		 * @return SObjectFieldChainComparator This chain, with the key appended.
		 *
		 * @since 1.2
		 */
		private SObjectFieldChainComparator addKey(SObjectField field, Boolean isAscending)
		{
			keyComparators.add(new SObjectFieldComparator(UTIL_SObjectDescribe.getCachedFieldName(field), isAscending));
			return this;
		}

		/**
		 * @description Compares two SObject records across the chain's keys in priority order, returning
		 * the first non-zero key comparison, or 0 when every key ties.
		 *
		 * @param firstRecord The first SObject record to compare.
		 * @param secondRecord The second SObject record to compare.
		 *
		 * @return Integer Returns 0 when all keys are equal, a positive number when firstRecord sorts
		 * after secondRecord, or a negative number when it sorts before.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * Integer order = UTIL_Comparators.orderBy(Account.Industry)
		 *     .thenBy(Account.Name)
		 *     .compare(firstAccount, secondAccount);
		 * ```
		 */
		public override Integer compare(SObject firstRecord, SObject secondRecord)
		{
			for(SObjectFieldComparator keyComparator : keyComparators)
			{
				Integer keyResult = keyComparator.compare(firstRecord, secondRecord);

				if(keyResult != 0)
				{
					return keyResult;
				}
			}

			return 0;
		}
	}

	/**
	 * @description Adjusts the comparison result based on the sort order.
	 *
	 * @param compareResult The original comparison result (-1, 0, or 1).
	 * @param isSortAscending The sort order (true for ascending, false for descending).
	 *
	 * @return Integer The adjusted comparison result.
	 */
	private static Integer getSortedCompareResult(Integer compareResult, Boolean isSortAscending)
	{
		if(isSortAscending != null && !isSortAscending)
		{
			if(compareResult == -1)
			{
				return 1;
			}
			else if(compareResult == 1)
			{
				return -1;
			}
		}

		return compareResult;
	}
}