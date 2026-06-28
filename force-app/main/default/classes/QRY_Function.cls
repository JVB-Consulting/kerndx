// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Typed SOQL function expressions for use in the query builder's SELECT, GROUP BY, WHERE
 * and ORDER BY clauses: the date-part functions (CALENDAR_MONTH, DAY_IN_MONTH, FISCAL_QUARTER, ...) and
 * the geolocation DISTANCE function. One static factory per function; the returned value is an immutable
 * carrier that resolves its wrapped field name once and renders to a finished SOQL expression, so the
 * builder can project, group, filter and sort by the same expression from a single source without
 * hand-spelling raw SOQL.
 *
 * Use the factories with the matching `QRY_Builder.Builder` overloads: `addField`, `groupBy` and
 * `orderBy` to bucket records by a date part for reporting, and `condition` (WHERE) together with the
 * geolocation distance factories for proximity filtering and nearest-first ordering.
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
	 * @description Single private helper that composes a geolocation DISTANCE expression for a fixed
	 * unit literal, resolving the field's API name exactly once (so a namespaced custom geolocation
	 * field renders one identical expression in WHERE and ORDER BY) and rendering the SOQL
	 * DISTANCE(field, GEOLOCATION(lat,lon), 'unit') form. Each named factory passes its own hardcoded
	 * unit, so the supplied literal is always one SOQL accepts and no runtime validation is needed.
	 *
	 * @param field The geolocation or compound address field to measure distance from.
	 * @param latitude The latitude of the reference point.
	 * @param longitude The longitude of the reference point.
	 * @param unit The distance unit literal supplied by the named factory ('mi' or 'km').
	 */
	private QRY_Function(SObjectField field, Decimal latitude, Decimal longitude, String unit)
	{
		this.expression = 'DISTANCE(' + UTIL_SObjectDescribe.getCachedFieldName(field) + ', GEOLOCATION(' + latitude + ',' + longitude + '), \'' + unit + '\')';
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
	 * @description Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring
	 * the straight-line distance in statute miles from each record to a fixed reference point. Use it for
	 * proximity filtering and nearest-first ordering (field service, store locator, dispatch). Renders
	 * DISTANCE(field, GEOLOCATION(latitude,longitude), 'mi'). Place it on the WHERE side with
	 * `QRY_Builder.Builder.condition(QRY_Function)` and on the sort side with the existing
	 * `orderBy(QRY_Function)` overload (ascending is nearest-first).
	 *
	 * @param field The geolocation (or compound address) field to measure from.
	 * @param latitude The latitude of the reference point, in degrees.
	 * @param longitude The longitude of the reference point, in degrees.
	 *
	 * @return A QRY_Function carrying DISTANCE(field, GEOLOCATION(latitude,longitude), 'mi').
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .condition(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).lessThan(10)
	 *     .orderBy(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).ascending()
	 *     .toList();
	 * ```
	 */
	global static QRY_Function distanceInMiles(SObjectField field, Decimal latitude, Decimal longitude)
	{
		return new QRY_Function(field, latitude, longitude, 'mi');
	}

	/**
	 * @description Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring
	 * the straight-line distance in statute miles to a `System.Location` reference point. Convenience
	 * overload of `distanceInMiles(SObjectField, Decimal, Decimal)` for callers that already hold a Location
	 * (for example a user's current position). Renders the identical
	 * DISTANCE(field, GEOLOCATION(latitude,longitude), 'mi') form.
	 *
	 * @param field The geolocation (or compound address) field to measure from.
	 * @param location The reference point to measure distance to.
	 *
	 * @return A QRY_Function carrying DISTANCE(field, GEOLOCATION(latitude,longitude), 'mi').
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * System.Location origin = System.Location.newInstance(37.775, -122.418);
	 * QRY_Function nearest = QRY_Function.distanceInMiles(Account.BillingAddress, origin);
	 * ```
	 */
	global static QRY_Function distanceInMiles(SObjectField field, System.Location location)
	{
		return distanceInMiles(field, location.getLatitude(), location.getLongitude());
	}

	/**
	 * @description Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring
	 * the straight-line distance in kilometres from each record to a fixed reference point. Use it for
	 * proximity filtering and nearest-first ordering (field service, store locator, dispatch). Renders
	 * DISTANCE(field, GEOLOCATION(latitude,longitude), 'km'). Place it on the WHERE side with
	 * `QRY_Builder.Builder.condition(QRY_Function)` and on the sort side with the existing
	 * `orderBy(QRY_Function)` overload (ascending is nearest-first).
	 *
	 * @param field The geolocation (or compound address) field to measure from.
	 * @param latitude The latitude of the reference point, in degrees.
	 * @param longitude The longitude of the reference point, in degrees.
	 *
	 * @return A QRY_Function carrying DISTANCE(field, GEOLOCATION(latitude,longitude), 'km').
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
	 *     .condition(QRY_Function.distanceInKilometers(Account.BillingAddress, 37.775, -122.418)).lessThan(16)
	 *     .orderBy(QRY_Function.distanceInKilometers(Account.BillingAddress, 37.775, -122.418)).ascending()
	 *     .toList();
	 * ```
	 */
	global static QRY_Function distanceInKilometers(SObjectField field, Decimal latitude, Decimal longitude)
	{
		return new QRY_Function(field, latitude, longitude, 'km');
	}

	/**
	 * @description Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring
	 * the straight-line distance in kilometres to a `System.Location` reference point. Convenience
	 * overload of `distanceInKilometers(SObjectField, Decimal, Decimal)` for callers that already hold a
	 * Location (for example a user's current position). Renders the identical
	 * DISTANCE(field, GEOLOCATION(latitude,longitude), 'km') form.
	 *
	 * @param field The geolocation (or compound address) field to measure from.
	 * @param location The reference point to measure distance to.
	 *
	 * @return A QRY_Function carrying DISTANCE(field, GEOLOCATION(latitude,longitude), 'km').
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * System.Location origin = System.Location.newInstance(37.775, -122.418);
	 * QRY_Function nearest = QRY_Function.distanceInKilometers(Account.BillingAddress, origin);
	 * ```
	 */
	global static QRY_Function distanceInKilometers(SObjectField field, System.Location location)
	{
		return distanceInKilometers(field, location.getLatitude(), location.getLongitude());
	}

	/**
	 * @description Returns the finished SOQL function expression with no alias (e.g.
	 * CALENDAR_MONTH(CloseDate) or DISTANCE(BillingAddress, GEOLOCATION(37.775,-122.418), 'mi')).
	 * Package-visible: consumed by `QRY_Builder` when rendering the function into the SELECT, GROUP BY,
	 * WHERE and ORDER BY clauses; intentionally not part of the global API.
	 *
	 * @return The SOQL expression string.
	 */
	public String toExpression()
	{
		return this.expression;
	}
}