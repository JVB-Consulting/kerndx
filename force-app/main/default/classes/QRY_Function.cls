// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Typed SOQL date-function expressions (CALENDAR_MONTH, DAY_IN_MONTH, FISCAL_QUARTER, ...)
 * for use in the query builder's SELECT, GROUP BY and ORDER BY clauses. One static factory per
 * function; the returned value is an immutable carrier that resolves its wrapped field name once and
 * renders to a finished SOQL expression, so the builder can project, group and sort by the same date
 * part from a single source without hand-spelling raw SOQL.
 *
 * Use the factories with the matching `QRY_Builder.Builder` overloads — `addField`, `groupBy` and
 * `orderBy` — to bucket records by a date part for reporting.
 *
 * @see QRY_Builder
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date June 2026
 *
 * @since 1.1
 *
 * @example
 * ```apex
 * List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
 *     .addField(QRY_Function.calendarMonth(Opportunity.CloseDate), 'closeMonth')
 *     .count('Id')
 *     .groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
 *     .orderBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
 *     .toAggregateList();
 * for(QRY_Builder.AggregateRow row : rows)
 * {
 *     Integer month = row.getInteger('closeMonth');
 *     Integer total = row.getInteger('count_Id');
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class QRY_Function
{
	/**
	 * @description The finished SOQL expression, resolved once at construction (e.g. CALENDAR_MONTH(CloseDate)).
	 */
	private final String expression;

	/**
	 * @description Builds the immutable carrier, resolving the field's API name exactly once so that
	 * every clause the builder renders this into shares one identical expression string (guarding
	 * against a SELECT/GROUP BY desync for a namespaced custom date field).
	 *
	 * @param soqlToken The SOQL date-function keyword (e.g. CALENDAR_MONTH).
	 * @param field The field to wrap in the date function.
	 */
	private QRY_Function(String soqlToken, SObjectField field)
	{
		this.expression = soqlToken + '(' + UTIL_SObjectDescribe.getCachedFieldName(field) + ')';
	}

	/**
	 * @description Wraps a date/datetime field in CALENDAR_MONTH (1–12 in the calendar year).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying CALENDAR_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function calendarMonth(SObjectField field)
	{
		return new QRY_Function('CALENDAR_MONTH', field);
	}

	/**
	 * @description Wraps a date/datetime field in CALENDAR_QUARTER (1–4 in the calendar year).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying CALENDAR_QUARTER(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.calendarQuarter(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function calendarQuarter(SObjectField field)
	{
		return new QRY_Function('CALENDAR_QUARTER', field);
	}

	/**
	 * @description Wraps a date/datetime field in CALENDAR_YEAR (the four-digit calendar year).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying CALENDAR_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.calendarYear(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function calendarYear(SObjectField field)
	{
		return new QRY_Function('CALENDAR_YEAR', field);
	}

	/**
	 * @description Wraps a date/datetime field in DAY_IN_MONTH (1–31).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying DAY_IN_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.dayInMonth(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function dayInMonth(SObjectField field)
	{
		return new QRY_Function('DAY_IN_MONTH', field);
	}

	/**
	 * @description Wraps a date/datetime field in DAY_IN_WEEK (1 for Sunday through 7 for Saturday).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying DAY_IN_WEEK(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.dayInWeek(Opportunity.CreatedDate))
	 * ```
	 */
	global static QRY_Function dayInWeek(SObjectField field)
	{
		return new QRY_Function('DAY_IN_WEEK', field);
	}

	/**
	 * @description Wraps a date/datetime field in DAY_IN_YEAR (1–366).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying DAY_IN_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.dayInYear(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function dayInYear(SObjectField field)
	{
		return new QRY_Function('DAY_IN_YEAR', field);
	}

	/**
	 * @description Wraps a datetime field in DAY_ONLY, returning the date with the time component
	 * dropped. Read back with `AggregateRow.getDate(alias)`, not `getInteger` — DAY_ONLY yields a
	 * Date, unlike the other date functions which yield an Integer date part.
	 *
	 * @param field The datetime field to truncate to a date.
	 *
	 * @return A QRY_Function carrying DAY_ONLY(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .addField(QRY_Function.dayOnly(Opportunity.CreatedDate), 'createdOn')
	 * // ... row.getDate('createdOn')
	 * ```
	 */
	global static QRY_Function dayOnly(SObjectField field)
	{
		return new QRY_Function('DAY_ONLY', field);
	}

	/**
	 * @description Wraps a date/datetime field in FISCAL_MONTH (1–12 within the org's fiscal year).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying FISCAL_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.fiscalMonth(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function fiscalMonth(SObjectField field)
	{
		return new QRY_Function('FISCAL_MONTH', field);
	}

	/**
	 * @description Wraps a date/datetime field in FISCAL_QUARTER (1–4 within the org's fiscal year).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying FISCAL_QUARTER(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.fiscalQuarter(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function fiscalQuarter(SObjectField field)
	{
		return new QRY_Function('FISCAL_QUARTER', field);
	}

	/**
	 * @description Wraps a date/datetime field in FISCAL_YEAR (the org's fiscal year).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying FISCAL_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.fiscalYear(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function fiscalYear(SObjectField field)
	{
		return new QRY_Function('FISCAL_YEAR', field);
	}

	/**
	 * @description Wraps a datetime field in HOUR_IN_DAY (0–23, in the running user's time zone).
	 *
	 * @param field The datetime field to bucket.
	 *
	 * @return A QRY_Function carrying HOUR_IN_DAY(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.hourInDay(Opportunity.CreatedDate))
	 * ```
	 */
	global static QRY_Function hourInDay(SObjectField field)
	{
		return new QRY_Function('HOUR_IN_DAY', field);
	}

	/**
	 * @description Wraps a date/datetime field in WEEK_IN_MONTH (1–6).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying WEEK_IN_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.weekInMonth(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function weekInMonth(SObjectField field)
	{
		return new QRY_Function('WEEK_IN_MONTH', field);
	}

	/**
	 * @description Wraps a date/datetime field in WEEK_IN_YEAR (1–53).
	 *
	 * @param field The date or datetime field to bucket.
	 *
	 * @return A QRY_Function carrying WEEK_IN_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * .groupBy(QRY_Function.weekInYear(Opportunity.CloseDate))
	 * ```
	 */
	global static QRY_Function weekInYear(SObjectField field)
	{
		return new QRY_Function('WEEK_IN_YEAR', field);
	}

	/**
	 * @description Returns the finished SOQL date-function expression with no alias
	 * (e.g. CALENDAR_MONTH(CloseDate)). Package-visible: consumed by `QRY_Builder` when rendering the
	 * function into the SELECT, GROUP BY and ORDER BY clauses; intentionally not part of the global API.
	 *
	 * @return The SOQL expression string.
	 */
	public String toExpression()
	{
		return this.expression;
	}
}