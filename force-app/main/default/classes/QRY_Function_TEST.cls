// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for QRY_Function. Verifies each date-function factory renders the correct
 * SOQL token wrapping the resolved field name, and that the field name is resolved once so SELECT and
 * GROUP BY later share one identical expression even for a namespaced custom field.
 *
 * @see QRY_Function
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date June 2026
 */
@IsTest(SeeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class QRY_Function_TEST
{
	/**
	 * @description Asserts calendarMonth renders the CALENDAR_MONTH token around the resolved field name.
	 */
	@IsTest
	private static void calendarMonthRendersExpression()
	{
		Test.startTest();
		QRY_Function functionField = QRY_Function.calendarMonth(Foobar__c.CreatedDate);
		Test.stopTest();

		Assert.areEqual('CALENDAR_MONTH(CreatedDate)', functionField.toExpression(), 'Should render the SOQL date-function token wrapping the resolved field name');
	}

	/**
	 * @description Asserts every one of the thirteen date-function factories renders its SOQL token.
	 * This catalogue is the contract: each factory maps to exactly one SOQL date function.
	 */
	@IsTest
	private static void rendersEveryDateFunctionToken()
	{
		Assert.areEqual('CALENDAR_MONTH(CreatedDate)', QRY_Function.calendarMonth(Foobar__c.CreatedDate).toExpression(), 'calendarMonth');
		Assert.areEqual('CALENDAR_QUARTER(CreatedDate)', QRY_Function.calendarQuarter(Foobar__c.CreatedDate).toExpression(), 'calendarQuarter');
		Assert.areEqual('CALENDAR_YEAR(CreatedDate)', QRY_Function.calendarYear(Foobar__c.CreatedDate).toExpression(), 'calendarYear');
		Assert.areEqual('DAY_IN_MONTH(CreatedDate)', QRY_Function.dayInMonth(Foobar__c.CreatedDate).toExpression(), 'dayInMonth');
		Assert.areEqual('DAY_IN_WEEK(CreatedDate)', QRY_Function.dayInWeek(Foobar__c.CreatedDate).toExpression(), 'dayInWeek');
		Assert.areEqual('DAY_IN_YEAR(CreatedDate)', QRY_Function.dayInYear(Foobar__c.CreatedDate).toExpression(), 'dayInYear');
		Assert.areEqual('DAY_ONLY(CreatedDate)', QRY_Function.dayOnly(Foobar__c.CreatedDate).toExpression(), 'dayOnly (returns a Date, read back via getDate)');
		Assert.areEqual('FISCAL_MONTH(CreatedDate)', QRY_Function.fiscalMonth(Foobar__c.CreatedDate).toExpression(), 'fiscalMonth');
		Assert.areEqual('FISCAL_QUARTER(CreatedDate)', QRY_Function.fiscalQuarter(Foobar__c.CreatedDate).toExpression(), 'fiscalQuarter');
		Assert.areEqual('FISCAL_YEAR(CreatedDate)', QRY_Function.fiscalYear(Foobar__c.CreatedDate).toExpression(), 'fiscalYear');
		Assert.areEqual('HOUR_IN_DAY(CreatedDate)', QRY_Function.hourInDay(Foobar__c.CreatedDate).toExpression(), 'hourInDay');
		Assert.areEqual('WEEK_IN_MONTH(CreatedDate)', QRY_Function.weekInMonth(Foobar__c.CreatedDate).toExpression(), 'weekInMonth');
		Assert.areEqual('WEEK_IN_YEAR(CreatedDate)', QRY_Function.weekInYear(Foobar__c.CreatedDate).toExpression(), 'weekInYear');
	}

	/**
	 * @description Asserts the wrapped field name is resolved through the describe layer to its exact
	 * platform API name for a custom date field — the same name a namespaced/subscriber org would use.
	 * Because the name is resolved once at construction, the SELECT and GROUP BY clauses the builder
	 * later renders from this expression cannot desync.
	 */
	@IsTest
	private static void resolvesFieldNameOnceForCustomField()
	{
		String expectedExpression = 'CALENDAR_MONTH(' + SEL_Foobar.FIELD_DATE + ')';
		QRY_Function firstCarrier = QRY_Function.calendarMonth(Foobar__c.Date__c);
		QRY_Function secondCarrier = QRY_Function.calendarMonth(Foobar__c.Date__c);

		Assert.areEqual(expectedExpression, firstCarrier.toExpression(), 'Should resolve the custom field to its exact platform API name (namespace-safe)');
		Assert.areEqual
				(
						firstCarrier.toExpression(),
						secondCarrier.toExpression(),
						'Two carriers for the same field render the identical expression, so SELECT and GROUP BY cannot desync'
				);
	}

	/**
	 * @description Asserts the lat/lon distanceInMiles factory renders the SOQL DISTANCE function
	 * wrapping a GEOLOCATION reference point and the hardcoded 'mi' unit, in the exact form SOQL expects
	 * for a compound address field.
	 */
	@IsTest
	private static void distanceInMilesRendersGeolocationExpression()
	{
		QRY_Function functionField = QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418);

		Assert.areEqual
				(
						'DISTANCE(BillingAddress, GEOLOCATION(37.775,-122.418), \'mi\')',
						functionField.toExpression(),
						'distanceInMiles must render the SOQL DISTANCE/GEOLOCATION form with the \'mi\' unit'
				);
	}

	/**
	 * @description Asserts the System.Location distanceInMiles overload renders the identical
	 * DISTANCE/GEOLOCATION expression, reading the reference point's latitude and longitude from the
	 * Location and hardcoding the 'mi' unit.
	 */
	@IsTest
	private static void distanceInMilesFromLocationRendersGeolocationExpression()
	{
		System.Location origin = System.Location.newInstance(37.775, -122.418);

		QRY_Function functionField = QRY_Function.distanceInMiles(Account.BillingAddress, origin);

		Assert.areEqual
				(
						'DISTANCE(BillingAddress, GEOLOCATION(37.775,-122.418), \'mi\')',
						functionField.toExpression(),
						'The distanceInMiles System.Location overload must render the same DISTANCE/GEOLOCATION form'
				);
	}

	/**
	 * @description Asserts the lat/lon distanceInKilometers factory renders the SOQL DISTANCE function
	 * wrapping a GEOLOCATION reference point and the hardcoded 'km' unit.
	 */
	@IsTest
	private static void distanceInKilometersRendersGeolocationExpression()
	{
		QRY_Function functionField = QRY_Function.distanceInKilometers(Account.BillingAddress, 37.775, -122.418);

		Assert.areEqual
				(
						'DISTANCE(BillingAddress, GEOLOCATION(37.775,-122.418), \'km\')',
						functionField.toExpression(),
						'distanceInKilometers must render the SOQL DISTANCE/GEOLOCATION form with the \'km\' unit'
				);
	}

	/**
	 * @description Asserts the System.Location distanceInKilometers overload renders the identical
	 * DISTANCE/GEOLOCATION expression, reading the reference point's latitude and longitude from the
	 * Location and hardcoding the 'km' unit.
	 */
	@IsTest
	private static void distanceInKilometersFromLocationRendersGeolocationExpression()
	{
		System.Location origin = System.Location.newInstance(37.775, -122.418);

		QRY_Function functionField = QRY_Function.distanceInKilometers(Account.BillingAddress, origin);

		Assert.areEqual
				(
						'DISTANCE(BillingAddress, GEOLOCATION(37.775,-122.418), \'km\')',
						functionField.toExpression(),
						'The distanceInKilometers System.Location overload must render the same DISTANCE/GEOLOCATION form'
				);
	}
}