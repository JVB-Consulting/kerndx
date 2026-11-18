// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for bypassSharing() when it is the only mode call on a query. Such a query reads rows the
 * running user does not own, but it still checks what the user may read. It removes the fields the user cannot read.
 *
 * It refuses a query that filters, sorts or groups on such a field, or that reads through an object or a lookup the
 * user cannot read. When the setting that runs queries in user mode is off, it keeps every field instead.
 *
 * The tests are kept apart from QRY_Builder_TEST because one class with all the tests grew too large for the code
 * inspections to check it.
 *
 * Most tests save Foobar__c rows, an object of this package. Some tests save Account, Contact, Lead, Event and Event
 * invitee records. Before each Account, Contact, Lead or Event save the test switches off the KernDX validation rules
 * on that object. Salesforce allows no triggers on Event invitee records, so no KernDX rule runs on them.
 *
 * An org's own Salesforce validation rules, required fields, duplicate rules, Flows or triggers on these objects still
 * run, and can make such a test fail in that org.
 *
 * @see QRY_Builder
 * @see QRY_Builder_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date November 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.CognitiveComplexity')
private class QRY_BuilderBypassSharing_TEST
{
	/**
	 * @description Company name given to the admin user created in the test setup. It is unique to this class, so
	 * getTestAdmin can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'QRY_BuilderBypassSharing_TEST-admin';

	/**
	 * @description API name of the Foobar__c name field. The tests use it to select and filter by name and to
	 * check that the name appears in the query text the builder produces.
	 */
	private static final String FIELD_NAME = SEL_Foobar.FIELD_NAME;

	/**
	 * @description Start of the name under which the audit record for a query that skips the permission checks is
	 * looked up. The tests add the object name to it to find that record.
	 */
	private static final String SECURITY_MODE_AUDIT_PREFIX = 'security-mode:';

	/**
	 * @description Start of the name under which the audit record for a query that skips record sharing is looked
	 * up. The tests add the object name to it to find that record.
	 */
	private static final String SHARING_AUDIT_PREFIX = 'sharing:';

	/**
	 * @description Start of the name under which the audit record for a query that calls withSystemMode() is looked up.
	 * The tests add the object name to it to find that record.
	 */
	private static final String SYSTEM_MODE_AUDIT_PREFIX = 'system-mode:';

	/**
	 * @description A phone number the tests use. A test gives it to a record it saves, such as an account, a contact or
	 * a Foobar__c row, or uses it as the value of a filter on a phone field.
	 */
	private static final String TEST_PHONE_NUMBER = '555-0100';

	/**
	 * @description Length in minutes given to each Event the TYPEOF tests build. An Event that is not an all-day
	 * event needs a length and a start time.
	 */
	private static final Integer EVENT_DURATION_MINUTES = 30;

	/**
	 * @description The longitude the distance tests use with every latitude.
	 */
	private static final Decimal DISTANCE_LONGITUDE = 10;

	/**
	 * @description The distance, in miles, the distance tests compare with.
	 */
	private static final Integer DISTANCE_LIMIT_MILES = 5;

	/**
	 * @description The number of hours in a day. Every hour of the day is less than it, so a condition on it matches all rows.
	 */
	private static final Integer HOURS_IN_A_DAY = 24;

	/**
	 * @description The object permission the restricted user gets on Foobar__c in the sharing bypass tests: read only,
	 * never View All, so record sharing still hides the rows the test administrator owns.
	 */
	private static final List<SObjectField> READ_PERMISSIONS = new List<SObjectField> {ObjectPermissions.PermissionsRead};

	/**
	 * @description A TYPEOF field written as plain text that reads the Name and the Phone of an Account parent, and
	 * the Name of any other parent. Every user can read the Name of a record, so the sharing bypass test can show that
	 * the parent came back while its Phone was removed.
	 */
	private static final String TYPEOF_ACCOUNT_NAME_AND_PHONE = 'TYPEOF What WHEN Account THEN Name, Phone ELSE Name END';

	/**
	 * @description A TYPEOF field written as plain text that leaves out THEN after the type. The builder cannot read
	 * which fields it selects.
	 */
	private static final String TYPEOF_WITHOUT_THEN = 'TYPEOF What WHEN Account Name END';

	/**
	 * @description A TYPEOF field written as plain text whose WHEN branch names an object the org does not have. The
	 * builder cannot check that object.
	 */
	private static final String TYPEOF_UNKNOWN_TYPE = 'TYPEOF What WHEN NoSuchObject THEN Name END';

	/**
	 * @description A TYPEOF field written as plain text whose relationship is not a lookup of an Event. The builder
	 * cannot check which lookup it reads.
	 */
	private static final String TYPEOF_UNKNOWN_RELATIONSHIP = 'TYPEOF NoSuchRelationship WHEN Account THEN Name END';

	/**
	 * @description The name of this package's query builder class without the package namespace, such as QRY_Builder.
	 * A name with a namespace has a dot in it, and the builder refuses such a TYPEOF before it looks for the object.
	 */
	private static final String QUERY_BUILDER_CLASS_NAME = QRY_Builder.class.getName().contains(UTIL_String.DOT)
			? QRY_Builder.class.getName().substringAfterLast(UTIL_String.DOT) : QRY_Builder.class.getName();

	/**
	 * @description A TYPEOF field written as plain text whose WHEN branch names an Apex class, this package's query
	 * builder, and not an object. The class name has no namespace, so the builder looks for an object of that name and
	 * finds none.
	 */
	private static final String TYPEOF_APEX_CLASS_TYPE = 'TYPEOF What WHEN ' + QUERY_BUILDER_CLASS_NAME + ' THEN Name END';

	/**
	 * @description A TYPEOF field written as plain text whose WHEN branch names the standard object Location. Location is
	 * also the name of a system Apex type, but the builder must still find the object and check it.
	 */
	private static final String TYPEOF_LOCATION_NAME = 'TYPEOF What WHEN Location THEN Name END';

	/**
	 * @description The name of the standard object Location. The tests take the object from this name while they run, so
	 * that the package does not depend on an object that some orgs may not have.
	 */
	private static final String LOCATION_OBJECT_NAME = 'Location';

	/**
	 * @description Selected texts with a dot in the wrong place: one dot, two dots, Subject with a dot after it, Subject
	 * with a dot before it, and What..Name with two dots together. They are not a field name or a path, so the builder
	 * cannot check them.
	 */
	private static final List<String> SELECTED_TEXTS_WITH_A_MISPLACED_DOT = new List<String>
	{
			UTIL_String.DOT,
			UTIL_String.DOT + UTIL_String.DOT,
			UTIL_SObjectDescribe.getCachedFieldName(Event.Subject) + UTIL_String.DOT,
			UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(Event.Subject),
			buildRelationshipPath(Event.WhatId, UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(Schema.Name.Name))
	};

	/**
	 * @description A field and a TYPEOF field written together as one plain text. SOQL reads both, but the builder reads
	 * a TYPEOF only when it is a text of its own.
	 */
	private static final String SUBJECT_AND_TYPEOF = 'Subject, TYPEOF What WHEN Account THEN Name END';

	/**
	 * @description A TYPEOF field written as plain text whose WHEN Account branch reads the name of the profile of the
	 * owner of the account, a path through two parent records.
	 */
	private static final String TYPEOF_ACCOUNT_OWNER_PROFILE_NAME = 'TYPEOF What WHEN Account THEN Owner.Profile.Name ELSE Name END';

	/**
	 * @description A TYPEOF field written as plain text whose ELSE branch reads the name of the record type of the related
	 * record, through the record type field of the shared Name record.
	 */
	private static final String TYPEOF_ELSE_RECORD_TYPE_NAME = 'TYPEOF What WHEN Account THEN Name ELSE RecordType.Name END';

	/**
	 * @description A TYPEOF on Who with two WHEN branches: Contact first, then Lead.
	 */
	private static final String TYPEOF_CONTACT_THEN_LEAD = 'TYPEOF Who WHEN Contact THEN Name WHEN Lead THEN Name END';

	/**
	 * @description A TYPEOF on Who with only the Contact branch: the same text as TYPEOF_CONTACT_THEN_LEAD without the
	 * Lead branch.
	 */
	private static final String TYPEOF_CONTACT_ONLY = 'TYPEOF Who WHEN Contact THEN Name END';

	/**
	 * @description A child relationship name that no object has. A test adds a child query under this name to a query
	 * of a Foobar__c row.
	 */
	private static final String UNKNOWN_CHILD_RELATIONSHIP = 'NoSuchChildren';

	/**
	 * @description The name the aggregate test gives to the highest value that MAX() reads.
	 */
	private static final String HIGHEST_VALUE_ALIAS = 'highestValue';

	/**
	 * @description The SOQL function that reads the highest value of a field.
	 */
	private static final String MAX_FUNCTION = 'MAX';

	/**
	 * @description Child relationships that Salesforce gives every account, besides Events. A test reads each of them
	 * in a child query as a Standard User.
	 */
	private static final List<String> STANDARD_ACCOUNT_CHILD_RELATIONSHIPS = new List<String>
	{
			'Histories', 'Feeds', 'Shares', 'Notes', 'AttachedContentDocuments', 'ActivityHistories', 'OpenActivities', 'Tasks', 'ProcessInstances'
	};

	/**
	 * @description For the activity child relationships of an account, whether the child query sorts on ActivityDate
	 * from the latest date down. For a user without administrator permissions, Salesforce reads these relationships in
	 * user mode only with a LIMIT and this sort, ActivityDate and then LastModifiedDate from the latest down.
	 */
	private static final Map<String, Boolean> ACTIVITY_DATE_DESCENDING_BY_RELATIONSHIP = new Map<String, Boolean>
	{
			'ActivityHistories' => true,
			'OpenActivities' => false
	};

	/**
	 * @description The highest LIMIT Salesforce allows on a child query of the activity child relationships of an
	 * account, for a user without administrator permissions.
	 */
	private static final Integer ACTIVITY_CHILD_QUERY_LIMIT = 500;

	/**
	 * @description The child relationship from an account to its contacts.
	 */
	private static final String CHILD_CONTACTS_RELATIONSHIP = 'Contacts';

	/**
	 * @description The child relationship from a user to approval submissions. The describe of User lists this name
	 * twice in some orgs, for two lookups of an approval submission that point to a user.
	 */
	private static final String CHILD_APPROVAL_SUBMISSIONS_RELATIONSHIP = 'ApprovalSubmissions';

	/**
	 * @description A child query of the Events of a record, such as an account or a Foobar__c row, written as plain
	 * text in the selected fields. It reads the name of the record each Event is related to. The builder cannot check
	 * a child query written as text.
	 */
	private static final String EVENTS_CHILD_QUERY_TEXT = '(SELECT Id, What.Name FROM Events)';

	/**
	 * @description The SOQL function that reads the label of a picklist value, in the language of the running user.
	 */
	private static final String TO_LABEL_FUNCTION = 'toLabel';

	/**
	 * @description The SOQL function that reads the distance between a location field and a fixed point.
	 */
	private static final String DISTANCE_FUNCTION = 'DISTANCE';

	/**
	 * @description The second and third values of a DISTANCE() function: the fixed point and the unit, kilometres.
	 */
	private static final String DISTANCE_POINT_AND_UNIT = 'GEOLOCATION(1,2), \'km\'';

	/**
	 * @description The bracket that opens the values of a SOQL function.
	 */
	private static final String OPENING_BRACKET = '(';

	/**
	 * @description The bracket that closes the values of a SOQL function.
	 */
	private static final String CLOSING_BRACKET = ')';

	/**
	 * @description The name a test gives to the label that toLabel() reads in a selected field.
	 */
	private static final String SHOWN_LABEL_ALIAS = 'shownLabel';

	/**
	 * @description The name of the child relationship from a record to its Events, such as from a contact, an account
	 * or a Foobar__c row.
	 */
	private static final String CHILD_EVENTS_RELATIONSHIP = 'Events';

	/**
	 * @description The start of the name of the permission set that gives a test user read access to one field, such as
	 * the Related To field of an Event. A random ending keeps each name unique.
	 */
	private static final String FIELD_READ_PERMISSION_SET_PREFIX = 'FieldRead';

	/**
	 * @description How many random letters and digits end the name of a permission set a test saves.
	 */
	private static final Integer PERMISSION_SET_NAME_RANDOM_LENGTH = 12;

	/**
	 * @description Alias given to the count of rows in each group that the sharing bypass tests read as totals.
	 */
	private static final String ROW_COUNT_ALIAS = 'rowCount';

	/**
	 * @description The name of the Foobar__c child relationship of the Lookup__c field, without the package namespace.
	 * A test adds the namespace of the running code to it before it reads the child rows.
	 */
	private static final String CHILD_FOOBARS_RELATIONSHIP = 'Foobars__r';

	/**
	 * @description The name of the LoginFrequency__c child relationship of a User, through the User__c field, without the
	 * package namespace. A test adds the namespace of the running code to it before it reads the child rows.
	 */
	private static final String CHILD_LOGIN_FREQUENCIES_RELATIONSHIP = 'AW_LoginFrequencies__r';

	/**
	 * @description The total number of logins a test puts on the LoginFrequency__c row it saves, and uses as the value
	 * of a filter on that field.
	 */
	private static final Decimal TOTAL_LOGIN_COUNT = 3;

	/**
	 * @description The most rows the paged read of the sharing bypass tests asks for. One page holds the one seeded row.
	 */
	private static final Integer BYPASS_PAGE_SIZE = 10;

	/**
	 * @description The most parent records a SOQL field path may pass through.
	 */
	private static final Integer MAXIMUM_PARENT_LEVELS = 5;

	/**
	 * @description A relationship name that Foobar__c does not have.
	 */
	private static final String UNKNOWN_RELATIONSHIP = 'NoSuchParent__r';

	/**
	 * @description The read terminal that returns the rows as a list. The refusal messages name it.
	 */
	private static final String TERMINAL_TO_LIST = 'toList';

	/**
	 * @description The read terminal that returns the number of rows.
	 */
	private static final String TERMINAL_COUNT = 'count';

	/**
	 * @description The read terminal that says whether any row matches.
	 */
	private static final String TERMINAL_EXISTS = 'exists';

	/**
	 * @description The read terminal that returns a query locator, which a batch job reads later. The refusal message names it.
	 */
	private static final String TERMINAL_TO_QUERY_LOCATOR = 'toQueryLocator';

	/**
	 * @description The read terminal that returns a cursor, which a later transaction can read. The refusal message names it.
	 */
	private static final String TERMINAL_TO_CURSOR = 'toCursor';

	/**
	 * @description The read terminal that returns the totals of a grouped query. The refusal message names it.
	 */
	private static final String TERMINAL_TO_AGGREGATE_LIST = 'toAggregateList';

	/**
	 * @description The read terminal that returns the first total of a grouped query. The refusal message names it.
	 */
	private static final String TERMINAL_GET_FIRST_AGGREGATE = 'getFirstAggregate';

	/**
	 * @description The read terminal that returns one page of rows. The refusal message names it.
	 */
	private static final String TERMINAL_GET_PAGE = 'getPage';

	/**
	 * @description The read terminal that returns rows picked at random. The refusal message names it.
	 */
	private static final String TERMINAL_GET_RANDOM_ITEMS = 'getRandomItems';

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction.
	 */
	@TestSetup
	private static void setupTestAdmin()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Iterates a locator in the current transaction and counts the rows it yields.
	 *
	 * @param locator The locator under test.
	 *
	 * @return The number of rows iterated.
	 */
	private static Integer countLocatorRows(Database.QueryLocator locator)
	{
		Integer rows = 0;
		Database.QueryLocatorIterator locatorIterator = locator.iterator();
		while(locatorIterator.hasNext())
		{
			locatorIterator.next();
			rows++;
		}
		return rows;
	}

	/**
	 * @description With the UserModeQueries_Enabled flag off, a query with no mode call runs in system mode: no object or
	 * field permission is checked. bypassSharing() alone then reads the row another user owns and keeps every field,
	 * the hidden Email__c field included. A cursor and a query locator are not refused either, and each reaches the row.
	 * When stripInaccessible() is added, the same read still removes the field the running user cannot read.
	 */
	@IsTest
	private static void bypassSharingAloneWithTheQueryFlagOffKeepsEveryField()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true, false);

		List<SObject> rows;
		List<SObject> strippedRows;
		Integer cursorRows;
		Integer locatorRows;
		System.runAs(restricted)
		{
			rows = newRowQuery(row.Id).addField(Foobar__c.Email__c).bypassSharing().toList();
			strippedRows = newRowQuery(row.Id).addField(Foobar__c.Email__c).bypassSharing().stripInaccessible().toList();
			cursorRows = countCursorRows(newRowQuery(row.Id).bypassSharing().toCursor());
			locatorRows = countLocatorRows(newRowQuery(row.Id).bypassSharing().toQueryLocator());
		}

		Assert.areEqual(1, rows.size(), 'Expected the read to reach the row the test administrator owns');
		Assert.areEqual(row.Email__c, rows[0].get(Foobar__c.Email__c), 'Expected the row to keep the email, because the flag is off and no field is checked');
		Assert.areEqual(1, strippedRows.size(), 'Expected the read with stripInaccessible() to reach the row too');
		Assert.isFalse(strippedRows[0].isSet(Foobar__c.Email__c), 'Expected stripInaccessible() to remove the email the user cannot read, even with the flag off');
		Assert.areEqual(1, cursorRows, 'Expected the cursor to be opened and to reach the row');
		Assert.areEqual(1, locatorRows, 'Expected the query locator to be opened and to reach the row');
	}

	/**
	 * @description bypassSharing() alone leaves exactly one audit entry for skipping record sharing, and none for system
	 * mode. An audit entry is the log record the framework writes when a safety check is turned off. Under the default
	 * user mode the read may run in system mode inside the framework to skip sharing, but the field checks stay, so
	 * nothing about system mode is recorded.
	 */
	@IsTest
	private static void bypassSharingAloneWritesOneSharingAuditEntry()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		Test.startTest();
		newFoobarNameQuery().bypassSharing().toList();
		Test.stopTest();

		String objectName = String.valueOf(Foobar__c.SObjectType);
		Assert.areEqual(1, UTIL_BypassAudit_TEST.countSavedRollupOccurrences(UTIL_BypassAudit.SURFACE_QUERY,
				SHARING_AUDIT_PREFIX + objectName), 'Expected exactly one audit entry for skipping record sharing');
		Assert.areEqual(0, UTIL_BypassAudit_TEST.countSavedRollupOccurrences(UTIL_BypassAudit.SURFACE_QUERY,
				SYSTEM_MODE_AUDIT_PREFIX + objectName), 'Expected no audit entry for system mode, because no field check was turned off');
		Assert.areEqual(0, UTIL_BypassAudit_TEST.countSavedRollupOccurrences(UTIL_BypassAudit.SURFACE_QUERY,
				SECURITY_MODE_AUDIT_PREFIX + objectName), 'Expected no audit entry for turning off every check');
	}

	/**
	 * @description bypassSharing() alone, under the default user mode, reads a row that another user owns. User mode
	 * means the query runs with the running user's object and field permissions. The restricted user may read
	 * Foobar__c records, but Foobar__c records are private and the test administrator owns the row, so only the bypass
	 * can make it visible.
	 */
	@IsTest
	private static void bypassSharingAloneReadsARowOwnedByAnotherUser()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> rows;
		System.runAs(restricted)
		{
			rows = newRowQuery(row.Id).bypassSharing().toList();
		}

		Assert.areEqual(1, rows.size(), 'Expected bypassSharing() to read the row the test administrator owns');
		Assert.areEqual(row.Id, rows[0].Id, 'Expected the row read to be the administrator\'s row');
	}

	/**
	 * @description bypassSharing() alone reads the row another user owns, but removes the Email__c field, which the
	 * running user cannot read. The field is selected on purpose. The same holds with and without stripInaccessible(),
	 * because the bypass keeps the field checks of user mode.
	 */
	@IsTest
	private static void bypassSharingAloneRemovesAFieldTheUserCannotRead()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> plainRows;
		List<SObject> strippedRows;
		System.runAs(restricted)
		{
			plainRows = newRowQuery(row.Id).addField(Foobar__c.Email__c).bypassSharing().toList();
			strippedRows = newRowQuery(row.Id).addField(Foobar__c.Email__c).bypassSharing().stripInaccessible().toList();
		}

		for(List<SObject> rows : new List<List<SObject>> {plainRows, strippedRows})
		{
			Assert.areEqual(1, rows.size(), 'Expected the read to reach the row the test administrator owns');
			Assert.areEqual(row.Name, rows[0].get(Foobar__c.Name), 'Expected the row to keep the name, which the user can read');
			Assert.isFalse(rows[0].isSet(Foobar__c.Email__c), 'Expected the email, which the user cannot read, to be removed from the row');
		}
	}

	/**
	 * @description bypassSharing() alone counts the row another user owns: count() is one and exists() is true. A count
	 * returns a number, so there is no field to remove.
	 */
	@IsTest
	private static void bypassSharingAloneCountsRowsOwnedByAnotherUser()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		Integer rowCount;
		Boolean rowExists;
		System.runAs(restricted)
		{
			rowCount = newRowQuery(row.Id).bypassSharing().count();
			rowExists = newRowQuery(row.Id).bypassSharing().exists();
		}

		Assert.areEqual(1, rowCount, 'Expected count() to include the row the test administrator owns');
		Assert.isTrue(rowExists, 'Expected exists() to find the row the test administrator owns');
	}

	/**
	 * @description bypassSharing() alone refuses toQueryLocator(), under the default user mode and under withUserMode().
	 * A batch job reads a query locator later, so the framework cannot remove the fields the user cannot read from what
	 * it returns. The refusal names the method and says to add withSystemMode(), and no query runs. A refused read also
	 * writes no audit entry. An audit entry is the log record the framework writes when a safety check is turned off.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAQueryLocator()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		System.runAs(restricted)
		{
			for(QRY_Builder.Builder query : new List<QRY_Builder.Builder> {newRowQuery(row.Id).bypassSharing(), newRowQuery(row.Id).withUserMode().bypassSharing()})
			{
				Integer queriesBefore = UTIL_Limits.soqlQueries().used();
				try
				{
					Object answer = runTerminal(query, TERMINAL_TO_QUERY_LOCATOR);
					Assert.fail('Expected the query to be refused; it returned ' + describeAnswer(answer));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Expected the refusal. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
					Assert.areEqual(buildBypassRefusalMessage(TERMINAL_TO_QUERY_LOCATOR), error.getMessage(), 'Expected the message to name toQueryLocator and say what to do');
					Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read to run no query');
				}
			}
		}
		Test.stopTest();

		String objectName = String.valueOf(Foobar__c.SObjectType);
		Assert.areEqual(0, UTIL_BypassAudit_TEST.countSavedRollupOccurrences(UTIL_BypassAudit.SURFACE_QUERY,
				SHARING_AUDIT_PREFIX + objectName), 'Expected no audit entry for skipping record sharing, because the read was refused');
		Assert.areEqual(0, UTIL_BypassAudit_TEST.countSavedRollupOccurrences(UTIL_BypassAudit.SURFACE_QUERY,
				SYSTEM_MODE_AUDIT_PREFIX + objectName), 'Expected no audit entry for system mode, because the read was refused');
	}

	/**
	 * @description bypassSharing() alone refuses toCursor(), under the default user mode and under withUserMode(). A
	 * later transaction can read a cursor, so the framework cannot remove the fields the user cannot read from what it
	 * returns. The refusal names the method and says to add withSystemMode(), and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesACursor()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		System.runAs(restricted)
		{
			for(QRY_Builder.Builder query : new List<QRY_Builder.Builder> {newRowQuery(row.Id).bypassSharing(), newRowQuery(row.Id).withUserMode().bypassSharing()})
			{
				Integer queriesBefore = UTIL_Limits.soqlQueries().used();
				try
				{
					Object answer = runTerminal(query, TERMINAL_TO_CURSOR);
					Assert.fail('Expected the query to be refused; it returned ' + describeAnswer(answer));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Expected the refusal. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
					Assert.areEqual(buildBypassRefusalMessage(TERMINAL_TO_CURSOR), error.getMessage(), 'Expected the message to name toCursor and say what to do');
					Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read to run no query');
				}
			}
		}
	}

	/**
	 * @description bypassSharing() alone reads a page that holds the row another user owns, without the Email__c field
	 * the user cannot read. getPage opens a cursor inside, but it removes the hidden fields from the rows it returns,
	 * so it is not refused. It does not hand that cursor back, because rows read later from it would keep the hidden
	 * field: the cursor is null, and the total and the paging values are still right.
	 */
	@IsTest
	private static void bypassSharingAloneGetPageReadsAnotherUsersRowWithoutTheHiddenField()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		QRY_Builder.QueryPage page;
		System.runAs(restricted)
		{
			page = newRowQuery(row.Id).addField(Foobar__c.Email__c).bypassSharing().getPage(1, BYPASS_PAGE_SIZE);
		}

		Assert.areEqual(1, page.records.size(), 'Expected the page to hold the row the test administrator owns');
		Assert.areEqual(row.Id, page.records[0].Id, 'Expected the page to hold the administrator\'s row');
		Assert.isFalse(page.records[0].isSet(Foobar__c.Email__c), 'Expected the email, which the user cannot read, to be removed from the row');
		Assert.isNull(page.cursor, 'Expected no cursor, because rows read later from it would keep the hidden field');
		Assert.areEqual(1, page.totalRecords, 'Expected the total to count the one row');
		Assert.areEqual(1, page.pageNumber, 'Expected the page number asked for');
		Assert.areEqual(BYPASS_PAGE_SIZE, page.pageSize, 'Expected the page size asked for');
		Assert.areEqual(1, page.totalPages, 'Expected one page in total');
		Assert.isFalse(page.hasMorePages, 'Expected no page after the only page');
		Assert.isFalse(page.hasPriorPages, 'Expected no page before the first page');
	}

	/**
	 * @description bypassSharing() alone removes a hidden field read through a parent. The child row selects the email
	 * of its parent through the Lookup__c relationship. Both rows are owned by the test administrator. The child comes
	 * back, and its parent carries no email value.
	 */
	@IsTest
	private static void bypassSharingAloneRemovesAHiddenFieldReadThroughAParent()
	{
		User restricted = insertRestrictedReader();
		Foobar__c parent = insertRowOwnedByAdmin(null);
		Foobar__c child = insertRowOwnedByAdmin(parent.Id);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> rows;
		System.runAs(restricted)
		{
			rows = newRowQuery(child.Id).relatedField(buildParentEmailPath()).bypassSharing().toList();
		}

		Assert.areEqual(1, rows.size(), 'Expected the read to reach the child row the test administrator owns');
		SObject parentRow = rows[0].getSObject(Foobar__c.Lookup__c);
		Assert.isNotNull(parentRow, 'Expected the child to come back with its parent, because only the hidden field is removed');
		Assert.areEqual(parent.Id, parentRow.Id, 'Expected the parent to be the row the child points to');
		Assert.isFalse(parentRow.isSet(Foobar__c.Email__c), 'Expected the parent email, which the user cannot read, to be removed');
	}

	/**
	 * @description bypassSharing() alone removes a hidden field inside a TYPEOF field. TYPEOF picks which parent fields
	 * to read by the type of parent an Event points to, and it reaches the query as plain text. The user may read
	 * Account records and every Account field except Phone, and may read the Related To field of an Event, which
	 * points to the parent. An Event that points to an Account comes back with that Account as its parent. The
	 * Account carries its Name, and no Phone.
	 */
	@IsTest
	private static void bypassSharingAloneRemovesAHiddenFieldInATypeofBranch()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Account.SObjectType},
						READ_PERMISSIONS,
						Account.Phone
				);
		grantReadOnEventRelatedTo(restricted);
		Account parentAccount;
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			parentAccount = insertAccountBypassingValidation(new Map<SObjectField, Object>
			{
					Account.Name => UTIL_Random.randomName(),
					Account.Phone => TEST_PHONE_NUMBER
			});
			linkedEvent = insertEventBypassingValidation(new Map<SObjectField, Object>
			{
					Event.WhatId => parentAccount.Id,
					Event.ActivityDateTime => Datetime.now(),
					Event.DurationInMinutes => EVENT_DURATION_MINUTES
			});
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> rows;
		System.runAs(restricted)
		{
			rows = QRY_Builder.selectFrom(Event.SObjectType)
					.fields(new List<SObjectField> {Event.Id})
					.addField(TYPEOF_ACCOUNT_NAME_AND_PHONE)
					.condition(Event.Id).equals(linkedEvent.Id)
					.bypassSharing()
					.toList();
		}

		Assert.areEqual(1, rows.size(), 'Expected the read to reach the Event the test administrator owns');
		SObject parent = ((Event)rows[0]).What;
		Assert.isNotNull(parent, 'Expected the Event to come back with its parent, because the user may read the Related To field');
		Assert.areEqual(parentAccount.Id, parent.Id, 'Expected the parent to be the Account the Event points to');
		Assert.areEqual(parentAccount.Name, parent.get(Account.Name), 'Expected the parent to carry its Name, which every user can read');
		Assert.isFalse(parent.isSet(Account.Phone), 'Expected the Account Phone, which the user cannot read, to be removed');
	}

	/**
	 * @description bypassSharing() alone removes a hidden field from the rows of a child subquery. A subquery reads the
	 * child rows of each row, here through the Lookup__c relationship, and selects Email__c. The child query filters
	 * and sorts on Name, and the parent query keeps only rows whose owner is in a query inside isIn() on active
	 * users. The user may read every field those filters and sorts use, so the read is not refused. The parent and its
	 * child come back, and no child row carries an email.
	 */
	@IsTest
	private static void bypassSharingAloneRemovesAHiddenFieldInAChildSubquery()
	{
		User restricted = insertRestrictedReader();
		Foobar__c parent = insertRowOwnedByAdmin(null);
		Foobar__c child = insertRowOwnedByAdmin(parent.Id);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String childRelationship = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_FOOBARS_RELATIONSHIP;

		List<SObject> rows;
		System.runAs(restricted)
		{
			QRY_Builder.Builder childQuery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.Name, Foobar__c.Email__c})
					.condition(Foobar__c.Name).equals(child.Name)
					.orderBy(Foobar__c.Name);
			QRY_Builder.Builder activeUsers = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<SObjectField> {User.Id})
					.condition(User.IsActive).equals(true);
			rows = newRowQuery(parent.Id).condition(Foobar__c.OwnerId).isIn(activeUsers).subselect(childQuery, childRelationship).bypassSharing().toList();
		}

		Assert.areEqual(1, rows.size(), 'Expected the read to reach the parent row the test administrator owns');
		List<SObject> children = rows[0].getSObjects(childRelationship);
		Assert.areEqual(1, children?.size(), 'Expected the parent to come back with its one child row');
		Assert.areEqual(child.Id, children[0].Id, 'Expected the child row to be the administrator\'s child row');
		Assert.isFalse(children[0].isSet(Foobar__c.Email__c), 'Expected the child email, which the user cannot read, to be removed');
	}

	/**
	 * @description bypassSharing() alone refuses an aggregate read, under the default user mode and under withUserMode().
	 * An aggregate read returns totals and group values, and the framework cannot remove a hidden field from those. The
	 * refusal holds on every read of the same grouped query: toAggregateList(), getFirstAggregate(), toList(), count(),
	 * exists(), getPage() and getRandomItems(). Each names its method, and no query runs. exists() is built on count(),
	 * so its message names count.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAnAggregateRead()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		List<String> terminals = new List<String>
		{
				TERMINAL_TO_AGGREGATE_LIST, TERMINAL_GET_FIRST_AGGREGATE, TERMINAL_TO_LIST, TERMINAL_COUNT, TERMINAL_EXISTS, TERMINAL_GET_PAGE,
				TERMINAL_GET_RANDOM_ITEMS
		};

		System.runAs(restricted)
		{
			for(Boolean explicitUserMode : new List<Boolean> {false, true})
			{
				for(String terminal : terminals)
				{
					QRY_Builder.Builder query = explicitUserMode ? newGroupedQuery(row.Name).withUserMode().bypassSharing() : newGroupedQuery(row.Name).bypassSharing();
					String namedMethod = terminal == TERMINAL_EXISTS ? TERMINAL_COUNT : terminal;
					Integer queriesBefore = UTIL_Limits.soqlQueries().used();
					try
					{
						Object answer = runTerminal(query, terminal);
						Assert.fail('Expected the query to be refused on ' + terminal + '; it returned ' + describeAnswer(answer));
					}
					catch(Exception error)
					{
						Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class,
								'Expected the refusal on ' + terminal + '. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
						Assert.areEqual(buildBypassRefusalMessage(namedMethod), error.getMessage(), 'Expected the message to name ' + namedMethod + ' and say what to do');
						Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read on ' + terminal + ' to run no query');
					}
				}
			}
		}
	}

	/**
	 * @description bypassSharing() alone refuses a user who cannot read the object at all. The Standard User profile gives
	 * no access to Foobar__c. count(), exists() and toList() are each refused with the message that names the object,
	 * and no query runs. Inner queries are checked the same way, for a user who may read Foobar__c and User but not
	 * ApiIssue__c or LoginFrequency__c. A Foobar__c read whose owner must be in an ApiIssue__c query is refused with the
	 * message that names ApiIssue__c. A User read with a child query on LoginFrequency__c is refused with the message
	 * that names LoginFrequency__c.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAUserWithoutObjectRead()
	{
		User noAccessUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String expectedMessage = String.format(System.Label.QueryBuilder_BypassSharingObject_NotReadable,
				new List<Object> {UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType)});
		String loginFrequencies = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_LOGIN_FREQUENCIES_RELATIONSHIP;
		Map<String, String> expectedMessagesByCase = new Map<String, String>
		{
				'query inside isIn' => String.format(System.Label.QueryBuilder_BypassSharingObject_NotReadable,
						new List<Object> {UTIL_SObjectDescribe.getObjectNameFromType(ApiIssue__c.SObjectType)}),
				'child query' => String.format(System.Label.QueryBuilder_BypassSharingObject_NotReadable,
						new List<Object> {UTIL_SObjectDescribe.getObjectNameFromType(LoginFrequency__c.SObjectType)})
		};

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(ApiIssue__c.SObjectType), 'Expected the user to have no read on ApiIssue__c');
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(LoginFrequency__c.SObjectType), 'Expected the user to have no read on LoginFrequency__c');
			Assert.isTrue(UTIL_SObjectDescribe.isObjectAccessible(User.SObjectType), 'Expected the user to be able to read User');
			QRY_Builder.Builder issueCreators = QRY_Builder.selectFrom(ApiIssue__c.SObjectType).fields(new List<SObjectField> {ApiIssue__c.CreatedById});
			QRY_Builder.Builder frequencies = QRY_Builder.selectFrom(LoginFrequency__c.SObjectType).fields(new List<SObjectField> {LoginFrequency__c.Id});
			Map<String, QRY_Builder.Builder> queriesByCase = new Map<String, QRY_Builder.Builder>
			{
					'query inside isIn' => newRowQuery(row.Id).condition(Foobar__c.OwnerId).isIn(issueCreators).bypassSharing(),
					'child query' => QRY_Builder.selectFrom(User.SObjectType)
							.fields(new List<SObjectField> {User.Name})
							.condition(User.Id).equals(UserInfo.getUserId())
							.subselect(frequencies, loginFrequencies)
							.bypassSharing()
			};
			for(String testCase : queriesByCase.keySet())
			{
				Integer queriesBefore = UTIL_Limits.soqlQueries().used();
				try
				{
					Object answer = runTerminal(queriesByCase.get(testCase), TERMINAL_TO_LIST);
					Assert.fail('Expected the query to be refused for the ' + testCase + '; it returned ' + describeAnswer(answer));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, QueryException.class,
							'Expected the refusal for the ' + testCase + '. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
					Assert.areEqual(expectedMessagesByCase.get(testCase), error.getMessage(), 'Expected the message to name the object of the ' + testCase);
					Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read to run no query, for the ' + testCase);
				}
			}
		}

		System.runAs(noAccessUser)
		{
			for(String terminal : new List<String> {TERMINAL_COUNT, TERMINAL_EXISTS, TERMINAL_TO_LIST})
			{
				QRY_Builder.Builder query = newRowQuery(row.Id).bypassSharing();
				Integer queriesBefore = UTIL_Limits.soqlQueries().used();
				try
				{
					Object answer = runTerminal(query, terminal);
					Assert.fail('Expected the query to be refused on ' + terminal + '; it returned ' + describeAnswer(answer));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, QueryException.class, 'Expected the refusal on ' + terminal + '. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
					Assert.areEqual(expectedMessage, error.getMessage(), 'Expected the message to name the object the user cannot read, on ' + terminal);
					Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read on ' + terminal + ' to run no query');
				}
			}
		}
	}

	/**
	 * @description bypassSharing() alone refuses a filter on a field the user cannot read. The rows a filter returns tell
	 * the user something about the field, even when the field is removed from the rows. The filter on Email__c is
	 * refused on toList() and on count(), and also when it sits inside a group of conditions joined by OR, when it
	 * matches a list of values with isIn(), when it sits inside a NOT condition, and when it is written as text after
	 * the object name, such as Foobar__c.Email__c. A query inside isIn() and a child query added with subselect() are
	 * checked the same way: a filter on Email__c in either one is refused too. A query inside isIn() is also refused
	 * when it selects a field the user cannot read, because the values of that field decide which rows come back: a
	 * User read whose Id must be in the User__c values of LoginFrequency__c is refused for a user who cannot read
	 * User__c. The message names the field, and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAFilterOnAFieldTheUserCannotRead()
	{
		User restricted = insertRestrictedReader();
		User cannotReadTrackedUser = TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_STANDARD_USER,
				new List<SObjectType> {LoginFrequency__c.SObjectType}, READ_PERMISSIONS, LoginFrequency__c.User__c);
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String expectedMessage = buildFieldRefusalMessage(Foobar__c.Email__c);
		String emailAfterObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType) + UTIL_String.DOT
				+ UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c);
		String childRelationship = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_FOOBARS_RELATIONSHIP;

		System.runAs(restricted)
		{
			QRY_Builder.Builder ownersOfTheEmail = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.OwnerId})
					.condition(Foobar__c.Email__c).equals(row.Email__c);
			QRY_Builder.Builder childrenWithTheEmail = newFoobarNameQuery().condition(Foobar__c.Email__c).equals(row.Email__c);
			Map<String, QRY_Builder.Builder> queriesByCase = new Map<String, QRY_Builder.Builder>
			{
					'filter read with toList' => newFoobarNameQuery().condition(Foobar__c.Email__c).equals(row.Email__c).bypassSharing(),
					'filter read with count' => newFoobarNameQuery().condition(Foobar__c.Email__c).equals(row.Email__c).bypassSharing(),
					'filter inside an OR group' => newFoobarNameQuery().addCondition(newEmailOrNameGroup(row)).bypassSharing(),
					'filter on a list of values' => newFoobarNameQuery().condition(Foobar__c.Email__c).isIn(new List<Object> {row.Email__c}).bypassSharing(),
					'filter inside a NOT condition' => newFoobarNameQuery().addCondition(newNotEmailCondition(row)).bypassSharing(),
					'filter written after the object name' => newFoobarNameQuery().condition(emailAfterObjectName).equals(row.Email__c).bypassSharing(),
					'filter inside a query inside isIn' => QRY_Builder.selectFrom(User.SObjectType)
							.fields(new List<SObjectField> {User.Name})
							.condition(User.Id).isIn(ownersOfTheEmail)
							.bypassSharing(),
					'filter inside a child query' => newRowQuery(row.Id).subselect(childrenWithTheEmail, childRelationship).bypassSharing()
			};
			Map<String, String> terminalsByCase = new Map<String, String>
			{
					'filter read with toList' => TERMINAL_TO_LIST,
					'filter read with count' => TERMINAL_COUNT,
					'filter inside an OR group' => TERMINAL_TO_LIST,
					'filter on a list of values' => TERMINAL_TO_LIST,
					'filter inside a NOT condition' => TERMINAL_TO_LIST,
					'filter written after the object name' => TERMINAL_TO_LIST,
					'filter inside a query inside isIn' => TERMINAL_TO_LIST,
					'filter inside a child query' => TERMINAL_TO_LIST
			};
			for(String testCase : queriesByCase.keySet())
			{
				Integer queriesBefore = UTIL_Limits.soqlQueries().used();
				try
				{
					Object answer = runTerminal(queriesByCase.get(testCase), terminalsByCase.get(testCase));
					Assert.fail('Expected the query to be refused for the ' + testCase + '; it returned ' + describeAnswer(answer));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class,
							'Expected the refusal for the ' + testCase + '. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
					Assert.areEqual(expectedMessage, error.getMessage(), 'Expected the message to name the field, for the ' + testCase);
					Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read to run no query, for the ' + testCase);
				}
			}
		}

		System.runAs(cannotReadTrackedUser)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(LoginFrequency__c.User__c), 'Expected the user to have no read on User__c');
			QRY_Builder.Builder trackedUsers = QRY_Builder.selectFrom(LoginFrequency__c.SObjectType).fields(new List<SObjectField> {LoginFrequency__c.User__c});
			QRY_Builder.Builder query = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<SObjectField> {User.Name})
					.condition(User.Id).isIn(trackedUsers)
					.bypassSharing();
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			try
			{
				Object answer = runTerminal(query, TERMINAL_TO_LIST);
				Assert.fail('Expected the query to be refused for the field selected inside isIn(); it returned ' + describeAnswer(answer));
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class,
						'Expected the refusal for the field selected inside isIn(). Actual: ' + error.getTypeName() + ': ' + error.getMessage());
				Assert.areEqual(buildFieldRefusalMessage(LoginFrequency__c.User__c), error.getMessage(), 'Expected the message to name the field selected inside isIn()');
				Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read to run no query, for the field selected inside isIn()');
			}
		}
	}

	/**
	 * @description bypassSharing() alone refuses a sort on a field the user cannot read. The order of the rows tells the
	 * user something about the field, even when the field is removed from the rows. The sort is refused when it is
	 * given as a field token and when it is given as text in each way the query accepts: with spaces around it, with
	 * a direction, as the second item of a list, with a direction and a place for blank values in lower case, and
	 * after the object name, such as Foobar__c.Email__c. A sort on Email__c in a child query added with subselect()
	 * is refused too. The message names the field, and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesASortOnAFieldTheUserCannotRead()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String email = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c);
		String name = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name);
		String childRelationship = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_FOOBARS_RELATIONSHIP;

		System.runAs(restricted)
		{
			Map<String, QRY_Builder.Builder> queriesByCase = new Map<String, QRY_Builder.Builder>
			{
					'sort given as a field token' => newRowQuery(row.Id).orderBy(Foobar__c.Email__c).bypassSharing(),
					'sort text with spaces around it' => newRowQuery(row.Id).orderBy('  ' + email + ' ').bypassSharing(),
					'sort text with a direction' => newRowQuery(row.Id).orderBy(email + ' DESC').bypassSharing(),
					'sort text as the second item of a list' => newRowQuery(row.Id).orderBy(name + ', ' + email).bypassSharing(),
					'sort text with a direction and nulls last in lower case' => newRowQuery(row.Id).orderBy(email + '  desc   nulls last').bypassSharing(),
					'sort text after the object name' => newRowQuery(row.Id)
							.orderBy(UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType) + UTIL_String.DOT + email)
							.bypassSharing(),
					'sort inside a child query' => newRowQuery(row.Id).subselect(newFoobarNameQuery().orderBy(email + ' ASC'), childRelationship).bypassSharing()
			};
			for(String testCase : queriesByCase.keySet())
			{
				Integer queriesBefore = UTIL_Limits.soqlQueries().used();
				try
				{
					Object answer = runTerminal(queriesByCase.get(testCase), TERMINAL_TO_LIST);
					Assert.fail('Expected the query to be refused for the ' + testCase + '; it returned ' + describeAnswer(answer));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class,
							'Expected the refusal for the ' + testCase + '. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
					Assert.areEqual(buildFieldRefusalMessage(Foobar__c.Email__c), error.getMessage(), 'Expected the message to name the field, for the ' + testCase);
					Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read to run no query, for the ' + testCase);
				}
			}
		}
	}

	/**
	 * @description bypassSharing() alone refuses a grouping on a field the user cannot read. A grouping returns every
	 * value of the field. The query is an aggregate read, so it is refused as every aggregate read is, before the field
	 * names are checked: the message names toAggregateList and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAGroupingOnAFieldTheUserCannotRead()
	{
		User restricted = insertRestrictedReader();
		insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		System.runAs(restricted)
		{
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(Foobar__c.Id, ROW_COUNT_ALIAS)
					.groupBy(Foobar__c.Email__c)
					.bypassSharing();
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			try
			{
				Object answer = runTerminal(query, TERMINAL_TO_AGGREGATE_LIST);
				Assert.fail('Expected the query to be refused; it returned ' + describeAnswer(answer));
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Expected the refusal. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
				Assert.areEqual(buildBypassRefusalMessage(TERMINAL_TO_AGGREGATE_LIST), error.getMessage(), 'Expected the message for an aggregate read');
				Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read to run no query');
			}
		}
	}

	/**
	 * @description Records a known limit of bypassSharing() alone: a filter in your own condition class still runs, even
	 * on a parent field the user cannot read. The framework cannot read the field names inside such a condition. The
	 * rows can therefore tell the user something about the field, and a developer must not filter on it that way under
	 * the bypass. The read here filters on the parent's email in a condition written as plain text. It returns the child
	 * row, without the child's own email.
	 */
	@IsTest
	private static void bypassSharingAloneStillRunsYourOwnConditionOnAFieldTheUserCannotRead()
	{
		User restricted = insertRestrictedReader();
		Foobar__c parent = insertRowOwnedByAdmin(null);
		Foobar__c child = insertRowOwnedByAdmin(parent.Id);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String filterText = buildParentEmailPath() + ' = \'' + String.escapeSingleQuotes(parent.Email__c) + '\'';

		List<SObject> rows;
		System.runAs(restricted)
		{
			rows = newRowQuery(child.Id).addField(Foobar__c.Email__c).addCondition(new TextFilter(filterText)).bypassSharing().toList();
		}

		Assert.areEqual(1, rows.size(), 'Expected the filter on the parent email to run and return the child row');
		Assert.areEqual(child.Id, rows[0].Id, 'Expected the row to be the child row');
		Assert.isFalse(rows[0].isSet(Foobar__c.Email__c), 'Expected the child email, which the user cannot read, to be removed');
	}

	/**
	 * @description bypassSharing() alone refuses a date function around a field the user cannot read, such as
	 * CALENDAR_YEAR(Datetime__c) = 2026. The rows a date function returns tell the user something about the field. The
	 * user may read Foobar__c and every field except Datetime__c. The filter is refused when the function is written as
	 * text, in lower case with spaces, and around convertTimezone. It is refused for each date function from
	 * QRY_Function, in condition(), andCondition() and orCondition(). A sort on a date function is refused too: from
	 * QRY_Function, in either direction, and as text with a direction, or as the second item of a list. A child query
	 * that sorts on a date function, and a query inside isIn() that filters on one, are refused the same way. The
	 * message names the field, and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesADateFunctionOnAFieldTheUserCannotRead()
	{
		User restricted = insertReaderWithOneHiddenField(Foobar__c.Datetime__c);
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String dateTimeField = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Datetime__c);
		Integer year = Date.today().year();
		String childRelationship = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_FOOBARS_RELATIONSHIP;

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Foobar__c.Datetime__c), 'Expected the user to have no read on Datetime__c');
			QRY_Builder.Builder ownersByYear = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.OwnerId})
					.condition(QRY_Function.calendarYear(Foobar__c.Datetime__c)).equals(year);
			Map<String, QRY_Builder.Builder> queriesByCase = new Map<String, QRY_Builder.Builder>
			{
					'date function written as text' => newRowQuery(row.Id).andCondition('CALENDAR_YEAR(' + dateTimeField + ')').equals(year).bypassSharing(),
					'date function in lower case with spaces' => newRowQuery(row.Id).andCondition('calendar_year( ' + dateTimeField + ' )').equals(year).bypassSharing(),
					'date function around convertTimezone' => newRowQuery(row.Id)
							.andCondition('HOUR_IN_DAY(convertTimezone(' + dateTimeField + '))')
							.lessThan(HOURS_IN_A_DAY)
							.bypassSharing(),
					'date function in andCondition' => newRowQuery(row.Id).andCondition(QRY_Function.fiscalYear(Foobar__c.Datetime__c)).equals(year).bypassSharing(),
					'date function in orCondition' => newRowQuery(row.Id).orCondition(QRY_Function.fiscalYear(Foobar__c.Datetime__c)).equals(year).bypassSharing(),
					'sort on a date function' => newRowQuery(row.Id).orderBy(QRY_Function.calendarMonth(Foobar__c.Datetime__c)).bypassSharing(),
					'sort on a date function, descending' => newRowQuery(row.Id).orderBy(QRY_Function.calendarMonth(Foobar__c.Datetime__c), true).bypassSharing(),
					'sort text on a date function with a direction' => newRowQuery(row.Id).orderBy('DAY_IN_WEEK(' + dateTimeField + ') DESC NULLS LAST').bypassSharing(),
					'sort text with a date function as the second item' => newRowQuery(row.Id).orderBy(FIELD_NAME + ', WEEK_IN_YEAR(' + dateTimeField + ')').bypassSharing(),
					'sort on a date function in a child query' => newRowQuery(row.Id)
							.subselect(newFoobarNameQuery().orderBy(QRY_Function.calendarYear(Foobar__c.Datetime__c)), childRelationship)
							.bypassSharing(),
					'date function in a query inside isIn' => QRY_Builder.selectFrom(User.SObjectType)
							.fields(new List<SObjectField> {User.Name})
							.condition(User.Id).isIn(ownersByYear)
							.bypassSharing()
			};
			Map<String, QRY_Function> functionsByName = newDateFunctions(Foobar__c.Datetime__c);
			for(String functionName : functionsByName.keySet())
			{
				queriesByCase.put('date function ' + functionName, newRowQuery(row.Id).andCondition(functionsByName.get(functionName)).equals(year).bypassSharing());
			}
			assertEveryQueryIsRefused(queriesByCase, buildFieldRefusalMessage(Foobar__c.Datetime__c));
		}
	}

	/**
	 * @description bypassSharing() alone refuses toLabel() around a field the user cannot read. toLabel() compares or
	 * sorts by the translated label of a picklist value, which tells the user what the value is. The user may read
	 * Foobar__c and every field except Picklist__c. A filter on toLabel(Picklist__c) is refused, also in other letter
	 * case and with spaces, and so is a sort on it with a direction, and a filter on it in a child query. The message
	 * names the field, and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesToLabelOnAFieldTheUserCannotRead()
	{
		User restricted = insertReaderWithOneHiddenField(Foobar__c.Picklist__c);
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String picklist = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Picklist__c);
		String childRelationship = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_FOOBARS_RELATIONSHIP;

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Foobar__c.Picklist__c), 'Expected the user to have no read on Picklist__c');
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'filter on toLabel' => newRowQuery(row.Id).andCondition('toLabel(' + picklist + ')').equals(row.Name).bypassSharing(),
					'filter on toLabel in upper case with spaces' => newRowQuery(row.Id).andCondition('TOLABEL( ' + picklist + ' )').equals(row.Name).bypassSharing(),
					'sort on toLabel with a direction' => newRowQuery(row.Id).orderBy('toLabel(' + picklist + ') DESC').bypassSharing(),
					'filter on toLabel in a child query' => newRowQuery(row.Id)
							.subselect(newFoobarNameQuery().condition('toLabel(' + picklist + ')').equals(row.Name), childRelationship)
							.bypassSharing()
			}, buildFieldRefusalMessage(Foobar__c.Picklist__c));
		}
	}

	/**
	 * @description bypassSharing() alone refuses DISTANCE() on a location field the user cannot read. The rows a distance
	 * filter or sort returns tell the user where the location is. The user may read Foobar__c and every field except
	 * Geolocation__c. A filter on the distance is refused in miles and in kilometres from QRY_Function, and as text with
	 * spaces. A sort on the distance from QRY_Function is refused, and so is a sort text that lists the distance after
	 * Name, with a direction: the commas inside the distance do not split it. The message names the field, and no query
	 * runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesADistanceOnAFieldTheUserCannotRead()
	{
		User restricted = insertReaderWithOneHiddenField(Foobar__c.Geolocation__c);
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		QRY_Function distanceInMiles = QRY_Function.distanceInMiles(Foobar__c.Geolocation__c, DISTANCE_LONGITUDE, DISTANCE_LONGITUDE);
		String distanceText = 'DISTANCE( ' + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Geolocation__c) + ', GEOLOCATION(1,2), \'km\')';

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Foobar__c.Geolocation__c), 'Expected the user to have no read on Geolocation__c');
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'distance in miles' => newRowQuery(row.Id).andCondition(distanceInMiles).lessThan(DISTANCE_LIMIT_MILES).bypassSharing(),
					'distance in kilometres' => newRowQuery(row.Id)
							.andCondition(QRY_Function.distanceInKilometers(Foobar__c.Geolocation__c, Location.newInstance(DISTANCE_LONGITUDE, DISTANCE_LONGITUDE)))
							.lessThan(DISTANCE_LIMIT_MILES)
							.bypassSharing(),
					'distance written as text with spaces' => newRowQuery(row.Id).andCondition(distanceText).lessThan(DISTANCE_LIMIT_MILES).bypassSharing(),
					'sort on a distance' => newRowQuery(row.Id).orderBy(distanceInMiles).bypassSharing(),
					'sort text with a distance after Name' => newRowQuery(row.Id).orderBy(FIELD_NAME + ', ' + distanceText + ' DESC').bypassSharing()
			}, buildFieldRefusalMessage(Foobar__c.Geolocation__c));
		}
	}

	/**
	 * @description bypassSharing() alone refuses a path through parent records to a field the user cannot read, such as
	 * Lookup__r.Email__c. The rows tell the user something about the parent's email. The user may read every Foobar__c
	 * field except Email__c. The filter is refused through one parent, through two, through five (the most SOQL allows),
	 * in lower case, and after the object name. It is refused with the relationship written without the package
	 * namespace too, as code inside the package may write it; in an org without a namespace that path is the same as
	 * the first. A sort on the path is refused, and so is the path in a child query and in a query inside isIn(). The
	 * message names the path as it is written, and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAPathToAFieldTheUserCannotRead()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String parentEmail = buildParentEmailPath();
		String relationship = UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Lookup__c).getRelationshipName() + UTIL_String.DOT;
		String twoParentsEmail = relationship + parentEmail;
		String fiveParentsEmail = relationship.repeat(MAXIMUM_PARENT_LEVELS - 1) + parentEmail;
		String parentEmailWithoutNamespace = parentEmail.removeStart(UTIL_System.getManagedPackageNamespacePrefix());
		String childRelationship = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_FOOBARS_RELATIONSHIP;

		System.runAs(restricted)
		{
			QRY_Builder.Builder ownersByParentEmail = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.OwnerId})
					.condition(parentEmail).equals(row.Email__c);
			Map<String, QRY_Builder.Builder> queriesByCase = new Map<String, QRY_Builder.Builder>
			{
					'path through one parent' => newRowQuery(row.Id).andCondition(parentEmail).equals(row.Email__c).bypassSharing(),
					'path through two parents' => newRowQuery(row.Id).andCondition(twoParentsEmail).equals(row.Email__c).bypassSharing(),
					'path through five parents' => newRowQuery(row.Id).andCondition(fiveParentsEmail).equals(row.Email__c).bypassSharing(),
					'path in lower case' => newRowQuery(row.Id).andCondition(parentEmail.toLowerCase()).equals(row.Email__c).bypassSharing(),
					'path without the package namespace on the relationship' => newRowQuery(row.Id)
							.andCondition(parentEmailWithoutNamespace)
							.equals(row.Email__c)
							.bypassSharing(),
					'path after the object name' => newRowQuery(row.Id)
							.andCondition(UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType) + UTIL_String.DOT + parentEmail)
							.equals(row.Email__c)
							.bypassSharing(),
					'sort on a path' => newRowQuery(row.Id).orderBy(parentEmail + ' DESC').bypassSharing(),
					'path in a child query' => newRowQuery(row.Id).subselect(newFoobarNameQuery().condition(parentEmail).equals(row.Email__c), childRelationship).bypassSharing(),
					'path in a query inside isIn' => QRY_Builder.selectFrom(User.SObjectType)
							.fields(new List<SObjectField> {User.Name})
							.condition(User.Id).isIn(ownersByParentEmail)
							.bypassSharing()
			};
			Map<String, String> messagesByCase = new Map<String, String>
			{
					'path through two parents' => buildPathRefusalMessage(twoParentsEmail),
					'path through five parents' => buildPathRefusalMessage(fiveParentsEmail),
					'path in lower case' => buildPathRefusalMessage(parentEmail.toLowerCase()),
					'path without the package namespace on the relationship' => buildPathRefusalMessage(parentEmailWithoutNamespace)
			};
			for(String testCase : queriesByCase.keySet())
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder> {testCase => queriesByCase.get(testCase)},
						messagesByCase.get(testCase) ?? buildPathRefusalMessage(parentEmail));
			}
		}
	}

	/**
	 * @description bypassSharing() alone refuses a path through a lookup the user cannot read, even when the last field is
	 * one the user can read. The user may read every Foobar__c field except Lookup__c, the lookup to the parent. A filter
	 * on Lookup__r.Name and a sort on it are refused. The value of the lookup decides which parent the name comes from,
	 * so the rows would tell the user something about the lookup. The message names the path, and no query runs. A read
	 * that selects Lookup__r.Id or Lookup__r.Name is refused with the message that names the lookup and the path. So is
	 * a read that selects the label of a picklist of the parent through toLabel(), with the message that names the path
	 * inside the function, and a read that selects the distance from the location of the parent: DISTANCE() reads more
	 * than one value, and its first value is the field. getPage() and getRandomItems() refuse the selected path as
	 * toList() does.
	 *
	 * The same selected paths in user mode, without bypassSharing(), on a row the user owns, are refused by Salesforce.
	 * The same row read in user mode without the path comes back, so each of these refusals is caused by the path.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAPathThroughALookupTheUserCannotRead()
	{
		User restricted = insertReaderWithOneHiddenField(Foobar__c.Lookup__c);
		Foobar__c row = insertRowOwnedByAdmin(null);
		Foobar__c ownRow;
		System.runAs(getTestAdmin())
		{
			ownRow = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, UTIL_Random.randomName())
					.withOverride(Foobar__c.Lookup__c, row.Id)
					.withOverride(Foobar__c.OwnerId, restricted.Id)
					.build();
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String parentName = buildRelationshipPath(Foobar__c.Lookup__c, FIELD_NAME);
		String parentId = buildRelationshipPath(Foobar__c.Lookup__c, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Id));
		String parentPicklist = buildRelationshipPath(Foobar__c.Lookup__c, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Picklist__c));
		String parentLabel = TO_LABEL_FUNCTION + OPENING_BRACKET + parentPicklist + CLOSING_BRACKET + UTIL_String.SPACE + SHOWN_LABEL_ALIAS;
		String parentLocation = buildRelationshipPath(Foobar__c.Lookup__c, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Geolocation__c));
		String parentDistance = DISTANCE_FUNCTION + OPENING_BRACKET + parentLocation + UTIL_String.COMMA + UTIL_String.SPACE + DISTANCE_POINT_AND_UNIT
				+ CLOSING_BRACKET;

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Foobar__c.Lookup__c), 'Expected the user to have no read on Lookup__c');
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'filter through the lookup' => newRowQuery(row.Id).andCondition(parentName).equals(row.Name).bypassSharing(),
					'sort through the lookup' => newRowQuery(row.Id).orderBy(parentName).bypassSharing()
			}, buildPathRefusalMessage(parentName));
			for(String selectedPath : new List<String> {parentId, parentName})
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
				{
						'selected ' + selectedPath => newRowQuery(ownRow.Id).addField(selectedPath).bypassSharing()
				}, buildLookupRefusalMessage(Foobar__c.Lookup__c, selectedPath));
				assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
				{
						'selected ' + selectedPath => newRowQuery(ownRow.Id).addField(selectedPath).withUserMode()
				}, newRowQuery(ownRow.Id).withUserMode());
			}
			for(String terminal : new List<String> {TERMINAL_GET_PAGE, TERMINAL_GET_RANDOM_ITEMS})
			{
				assertReadIsRefused('selected ' + parentName + ' read with ' + terminal, newRowQuery(ownRow.Id).addField(parentName).bypassSharing(), terminal,
						UTIL_Exceptions.IllegalStateException.class, buildLookupRefusalMessage(Foobar__c.Lookup__c, parentName));
			}
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'selected ' + parentLabel => newRowQuery(ownRow.Id).addField(parentLabel).bypassSharing()
			}, buildLookupRefusalMessage(Foobar__c.Lookup__c, parentPicklist));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'selected ' + parentDistance => newRowQuery(ownRow.Id).addField(parentDistance).bypassSharing()
			}, buildLookupRefusalMessage(Foobar__c.Lookup__c, parentLocation));
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'selected ' + parentLabel => newRowQuery(ownRow.Id).addField(parentLabel).withUserMode(),
					'selected ' + parentDistance => newRowQuery(ownRow.Id).addField(parentDistance).withUserMode()
			}, newRowQuery(ownRow.Id).withUserMode());
		}
	}

	/**
	 * @description bypassSharing() alone checks only the selected fields that the query really reads. The user may read
	 * every Foobar__c field except Lookup__c, the lookup to the parent. A query that selects every field with
	 * selectAllFields() reads only the fields of Foobar__c, so a path added with addField() is not in the query and is
	 * not checked: the row comes back. A list of fields with an empty entry in it reads the row too, because an empty
	 * entry is not a field and the query leaves it out.
	 *
	 * In user mode, on a row the user owns, the read with the empty entry comes back too. Salesforce refuses the read of
	 * every field, because it holds Lookup__c, which the user cannot read. bypassSharing() alone removes such a hidden
	 * field of the queried object from the rows instead.
	 */
	@IsTest
	private static void bypassSharingAloneChecksOnlyTheSelectedFieldsTheQueryReads()
	{
		User restricted = insertReaderWithOneHiddenField(Foobar__c.Lookup__c);
		Foobar__c parent = insertRowOwnedByAdmin(null);
		Foobar__c row = insertRowOwnedByAdmin(parent.Id);
		Foobar__c ownRow;
		System.runAs(getTestAdmin())
		{
			ownRow = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, UTIL_Random.randomName())
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.withOverride(Foobar__c.OwnerId, restricted.Id)
					.build();
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String parentName = buildRelationshipPath(Foobar__c.Lookup__c, FIELD_NAME);

		List<String> emptyEntry = new List<String> {FIELD_NAME, null};
		List<SObject> allFieldRows;
		List<SObject> emptyEntryRows;
		List<SObject> userModeEmptyEntryRows;
		System.runAs(restricted)
		{
			allFieldRows = newRowQuery(row.Id).selectAllFields().addField(parentName).bypassSharing().toList();
			emptyEntryRows = newRowQuery(row.Id).fields(emptyEntry).bypassSharing().toList();
			userModeEmptyEntryRows = newRowQuery(ownRow.Id).fields(emptyEntry).withUserMode().toList();
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'read of every field' => newRowQuery(ownRow.Id).selectAllFields().addField(parentName).withUserMode()
			}, newRowQuery(ownRow.Id).withUserMode());
		}

		Assert.areEqual(1, allFieldRows.size(), 'Expected the read of every field to return the row, since the query does not read the added path');
		Assert.areEqual(row.Id, allFieldRows[0].Id, 'Expected the row to be the child row');
		Assert.isFalse(allFieldRows[0].isSet(Foobar__c.Lookup__c), 'Expected Lookup__c, which the user cannot read, to be removed from the row');
		Assert.areEqual(1, emptyEntryRows.size(), 'Expected the read with an empty entry in the field list to return the row');
		Assert.areEqual(1, userModeEmptyEntryRows.size(), 'Expected user mode to return the row read with an empty entry in the field list');
	}

	/**
	 * @description bypassSharing() alone reads through functions and paths the user can read. The user may read every
	 * Foobar__c field except Email__c. The child row is read with a filter on the parent's name through Lookup__r, a
	 * filter on CALENDAR_YEAR(CreatedDate), a sort on the parent's name and a filter that the owner has a user name. The
	 * owner lookup can point to a user or to a queue, so SOQL reads it through a shared Name record, and the user can
	 * read the user name of that record. The child row comes back.
	 */
	@IsTest
	private static void bypassSharingAloneReadsThroughFunctionsAndPathsTheUserCanRead()
	{
		User restricted = insertRestrictedReader();
		Foobar__c parent = insertRowOwnedByAdmin(null);
		Foobar__c child = insertRowOwnedByAdmin(parent.Id);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String parentName = UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Lookup__c).getRelationshipName() + UTIL_String.DOT + FIELD_NAME;
		String ownerUserName = UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.OwnerId).getRelationshipName() + UTIL_String.DOT
				+ UTIL_SObjectDescribe.getCachedFieldName(User.Username);
		List<SObjectType> ownerTypes = UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.OwnerId).getReferenceTo();
		Assert.isTrue(ownerTypes.contains(Group.SObjectType) && ownerTypes.contains(User.SObjectType), 'Expected the owner to point to a user or a queue');
		Assert.isNull(UTIL_SObjectDescribe.getDescribe(Group.SObjectType).getField(UTIL_SObjectDescribe.getCachedFieldName(User.Username)),
				'Expected a queue to have no user name field');

		List<SObject> rows;
		System.runAs(restricted)
		{
			rows = newRowQuery(child.Id)
					.andCondition(parentName).equals(parent.Name)
					.andCondition(QRY_Function.calendarYear(Foobar__c.CreatedDate)).equals(Date.today().year())
					.andCondition(ownerUserName).isNotNull()
					.orderBy(parentName + ' DESC')
					.bypassSharing()
					.toList();
		}

		Assert.areEqual(1, rows.size(), 'Expected the read to reach the child row the test administrator owns');
		Assert.areEqual(child.Id, rows[0].Id, 'Expected the row to be the child row');
	}

	/**
	 * @description bypassSharing() alone reads a field of the shared Name record even when the related object hides the
	 * field of the same name. SOQL reads the WhoId lookup of an Event, which points to a contact or to a lead, through a
	 * shared Name record. Its Phone is not the phone of the contact, so a field permission on the contact phone does not
	 * hide it. The user may read accounts, contacts and leads, and every field of them except the phone of a contact, and
	 * may read the WhoId lookup of an Event. The user owns the Event. A filter that Who.Phone is empty and a filter on
	 * Who.LastName each read the Event, with bypassSharing() and in user mode without it, because Salesforce checks only
	 * the lookup and the field of the Name record.
	 */
	@IsTest
	private static void bypassSharingAloneReadsANameRecordFieldThatTheRelatedObjectHides()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Account.SObjectType, Contact.SObjectType, Lead.SObjectType},
						READ_PERMISSIONS,
						Contact.Phone
				);
		grantReadOnEventField(restricted, Event.WhoId);
		String lastName = UTIL_Random.randomName();
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			Contact person = insertContactBypassingValidation(new Map<SObjectField, Object>
			{
					Contact.LastName => lastName,
					Contact.Phone => TEST_PHONE_NUMBER
			});
			linkedEvent = insertEventOwnedBy(restricted.Id, null, person.Id);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String personPhone = buildRelationshipPath(Event.WhoId, UTIL_SObjectDescribe.getCachedFieldName(Contact.Phone));
		String personLastName = buildRelationshipPath(Event.WhoId, UTIL_SObjectDescribe.getCachedFieldName(Contact.LastName));

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Contact.Phone), 'Expected the user to have no read on the phone of a contact');
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				List<SObject> phoneRows = applyAccess(newEventQuery(linkedEvent.Id).andCondition(personPhone).isNull(), isSharingBypassed).toList();
				List<SObject> lastNameRows = applyAccess(newEventQuery(linkedEvent.Id).andCondition(personLastName).equals(lastName), isSharingBypassed).toList();
				Assert.areEqual(1, phoneRows.size(), 'Expected the filter on the phone of the Name record to read the Event, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(linkedEvent.Id, phoneRows[0].Id, 'Expected the row to be the Event that points to the contact');
				Assert.areEqual(1, lastNameRows.size(), 'Expected the filter on the last name of the contact to read the Event, sharing bypassed: ' + isSharingBypassed);
			}
		}
	}

	/**
	 * @description bypassSharing() alone refuses a path through a parent object the user cannot read, with the message
	 * that names the object. The read runs without the user's object permissions, so a filter on the phone of the
	 * account would tell the user which account has that phone. The user may read contacts and every contact field
	 * except the phone, and has a field permission on the phone of an account, but cannot read accounts. The platform
	 * then reports the account lookup of a contact and the phone of an account as unreadable, field permission or not.
	 * A filter on Account.Phone and a sort on it are refused with the message that names Account, and no query runs. A
	 * filter on Account.Name is refused the same way: the account lookup of a contact can point only to an account, so
	 * Salesforce reads the name from the account itself, not from a shared Name record. A read that selects Account.Id
	 * or Account.Name is refused too, and the same read in user mode, without bypassSharing(), is refused by Salesforce
	 * on a contact the user owns.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAPathThroughAParentObjectTheUserCannotRead()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Contact.SObjectType},
						READ_PERMISSIONS,
						Contact.Phone
				);
		grantReadOnField(restricted, Account.SObjectType, Account.Phone);
		Contact person;
		System.runAs(getTestAdmin())
		{
			Account parentAccount = insertAccountBypassingValidation(new Map<SObjectField, Object>());
			person = insertContactBypassingValidation(new Map<SObjectField, Object>
			{
					Contact.AccountId => parentAccount.Id,
					Contact.OwnerId => restricted.Id
			});
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String accountPhone = buildRelationshipPath(Contact.AccountId, UTIL_SObjectDescribe.getCachedFieldName(Account.Phone));
		String accountName = buildRelationshipPath(Contact.AccountId, UTIL_SObjectDescribe.getCachedFieldName(Account.Name));
		String accountId = buildRelationshipPath(Contact.AccountId, UTIL_SObjectDescribe.getCachedFieldName(Account.Id));

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(Account.SObjectType), 'Expected the user to have no read on Account');
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Contact.AccountId), 'Expected the platform to report the account lookup unreadable without read on Account');
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Account.Phone), 'Expected the platform to report the phone unreadable without read on Account');
			Assert.isFalse(UTIL_SObjectDescribe.getCachedFieldDescribe(Contact.AccountId).isNamePointing(), 'Expected the account lookup of a contact not to use the Name record');
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'filter on the phone of the account' => newContactQuery().condition(accountPhone).equals(TEST_PHONE_NUMBER).bypassSharing(),
					'sort on the phone of the account' => newContactQuery().orderBy(accountPhone).bypassSharing(),
					'filter on the name of the account' => newContactQuery().condition(accountName).equals(UTIL_Random.randomName()).bypassSharing()
			}, QueryException.class, buildObjectRefusalMessage(Account.SObjectType));
			QRY_Builder.Builder userModeControl = newContactQuery().condition(Contact.Id).equals(person.Id).withUserMode();
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'filter on the name of the account' => newContactQuery().condition(Contact.Id).equals(person.Id)
							.andCondition(accountName).equals(UTIL_Random.randomName())
							.withUserMode()
			}, userModeControl);
			for(String selectedPath : new List<String> {accountId, accountName})
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
				{
						'selected ' + selectedPath => newContactQuery().addField(selectedPath).condition(Contact.Id).equals(person.Id).bypassSharing()
				}, QueryException.class, buildObjectRefusalMessage(Account.SObjectType));
				assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
				{
						'selected ' + selectedPath => newContactQuery().addField(selectedPath).condition(Contact.Id).equals(person.Id).withUserMode()
				}, userModeControl);
			}
		}
	}

	/**
	 * @description bypassSharing() alone refuses a filter and a sort on a hidden field of a parent the user can read.
	 * The user may read accounts and contacts, and every field of them except the Type of an account. The account lookup
	 * of a contact can point only to an account, so Salesforce reads Account.Type from the account itself. The shared
	 * Name record, which SOQL uses for a lookup that can point to more than one object, also has a field called Type,
	 * and the user can read that one. A filter on Account.Type and a sort on it are refused with the message that names
	 * the path, and no query runs. The same filter and sort in user mode, without bypassSharing(), on a contact the user
	 * owns, are refused by Salesforce, and the same contact read without them comes back.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAHiddenFieldOfAParentTheUserCanRead()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Account.SObjectType, Contact.SObjectType},
						READ_PERMISSIONS,
						Account.Type
				);
		Contact person;
		System.runAs(getTestAdmin())
		{
			Account parentAccount = insertAccountBypassingValidation(new Map<SObjectField, Object> {Account.OwnerId => restricted.Id});
			person = insertContactBypassingValidation(new Map<SObjectField, Object>
			{
					Contact.AccountId => parentAccount.Id,
					Contact.OwnerId => restricted.Id
			});
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String accountType = buildRelationshipPath(Contact.AccountId, UTIL_SObjectDescribe.getCachedFieldName(Account.Type));

		System.runAs(restricted)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Contact.AccountId), 'Expected the user to be able to read the account lookup of a contact');
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Account.Type), 'Expected the user to have no read on the Type of an account');
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Schema.Name.Type), 'Expected the user to be able to read the Type of the Name record');
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'filter on the type of the account' => newContactQuery().condition(accountType).equals(UTIL_Random.randomName()).bypassSharing(),
					'sort on the type of the account' => newContactQuery().orderBy(accountType).bypassSharing()
			}, buildPathRefusalMessage(accountType));
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'filter on the type of the account' => newContactQuery().condition(Contact.Id).equals(person.Id)
							.andCondition(accountType).equals(UTIL_Random.randomName())
							.withUserMode(),
					'sort on the type of the account' => newContactQuery().condition(Contact.Id).equals(person.Id).orderBy(accountType).withUserMode()
			}, newContactQuery().condition(Contact.Id).equals(person.Id).withUserMode());
		}
	}

	/**
	 * @description bypassSharing() alone reads a path through a lookup that can point to more than one object, even when
	 * the user cannot read the object of the related record. The WhoId lookup of an Event points to a contact or to a
	 * lead, and SOQL reads it through a shared Name record. The user may read contacts and every contact field except the
	 * phone, and the WhoId lookup of an Event, but cannot read leads. The user owns an Event whose WhoId points to a lead
	 * the test administrator owns. A filter on Who.LastName equal to the last name of the lead reads the Event, with
	 * bypassSharing() and in user mode without it: Salesforce checks the lookup and the field of the Name record, and not
	 * the Lead object. With bypassSharing() the same filter covers every Event in the org, so it can tell the user the
	 * name of any lead that has an Event.
	 */
	@IsTest
	private static void bypassSharingAloneReadsAPathThatCanPointToAnObjectTheUserCannotRead()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Contact.SObjectType},
						READ_PERMISSIONS,
						Contact.Phone
				);
		grantReadOnEventField(restricted, Event.WhoId);
		String lastName = UTIL_Random.randomName();
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			Lead prospect = insertLeadBypassingValidation(new Map<SObjectField, Object> {Lead.LastName => lastName});
			linkedEvent = insertEventOwnedBy(restricted.Id, null, prospect.Id);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String personLastName = buildRelationshipPath(Event.WhoId, UTIL_SObjectDescribe.getCachedFieldName(Lead.LastName));

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(Lead.SObjectType), 'Expected the user to have no read on Lead');
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				List<SObject> rows = applyAccess(newEventQuery(linkedEvent.Id).andCondition(personLastName).equals(lastName), isSharingBypassed).toList();
				Assert.areEqual(1, rows.size(), 'Expected the filter on the last name of the lead to read the Event, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(linkedEvent.Id, rows[0].Id, 'Expected the row to be the Event that points to the lead');
			}
		}
	}

	/**
	 * @description bypassSharing() alone checks only the lookup and the field of the shared Name record for the Type and
	 * the Name of a record that a lookup to more than one object points to. SOQL reads What.Type and What.Name from a
	 * shared Name record: What.Type is the object of the related record, such as Account, and not the Type field of an
	 * account. The user may read accounts and every account field except Type, and the WhatId lookup of an Event, but no
	 * other object an Event can be related to. The user owns an Event that points to an account. A filter on What.Type
	 * and a filter on What.Name each read the Event, with bypassSharing() and in user mode without it. A read that
	 * selects What.Type, What.Name and What.Id returns their values, because the user can read the WhatId lookup.
	 */
	@IsTest
	private static void bypassSharingAloneFiltersOnAndSelectsTheTypeAndNameOfTheRelatedRecord()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Account.SObjectType},
						READ_PERMISSIONS,
						Account.Type
				);
		grantReadOnEventRelatedTo(restricted);
		Account parent;
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			parent = insertAccountBypassingValidation(new Map<SObjectField, Object> {Account.Name => UTIL_Random.randomName()});
			linkedEvent = insertEventOwnedBy(restricted.Id, parent.Id, null);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String accountTypeName = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
		String relatedType = buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Account.Type));
		String relatedName = buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Account.Name));
		String relatedId = buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Account.Id));

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Account.Type), 'Expected the user to have no read on the Type of an account');
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				List<SObject> typeRows = applyAccess(newEventQuery(linkedEvent.Id).andCondition(relatedType).equals(accountTypeName), isSharingBypassed).toList();
				List<SObject> nameRows = applyAccess(newEventQuery(linkedEvent.Id).andCondition(relatedName).equals(parent.Name), isSharingBypassed).toList();
				List<SObject> selectedRows = applyAccess(newEventQuery(linkedEvent.Id).fields(new List<String> {relatedType, relatedName, relatedId}),
						isSharingBypassed).toList();
				Assert.areEqual(1, typeRows.size(), 'Expected the filter on the type of the related record to read the Event, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(linkedEvent.Id, typeRows[0].Id, 'Expected the row to be the Event that points to the account');
				Assert.areEqual(1, nameRows.size(), 'Expected the filter on the name of the related record to read the Event, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(1, selectedRows.size(), 'Expected the read that selects the related record to return the Event, sharing bypassed: ' + isSharingBypassed);
				SObject related = ((Event)selectedRows[0]).What;
				Assert.areEqual(parent.Id, related?.Id, 'Expected the Event to come back with the Id of the account, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(parent.Name, related.get(UTIL_SObjectDescribe.getCachedFieldName(Account.Name)),
						'Expected the Event to come back with the name of the account, sharing bypassed: ' + isSharingBypassed);
			}
		}
	}

	/**
	 * @description bypassSharing() alone still needs read access to the lookup for the Type or the Id of a record that a
	 * lookup to more than one object points to. The user may read accounts but not the WhatId lookup of an Event. The
	 * Event is related to a Foobar__c row. A filter on What.Type or on What.Id is refused with the message that names
	 * the path, and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesTheTypeOfTheRelatedRecordWithoutReadOnTheLookup()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Account.SObjectType},
						READ_PERMISSIONS,
						Account.Type
				);
		Foobar__c relatedRow = insertRowOwnedByAdmin(null);
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			linkedEvent = insertEventBypassingValidation(new Map<SObjectField, Object>
			{
					Event.WhatId => relatedRow.Id,
					Event.ActivityDateTime => Datetime.now(),
					Event.DurationInMinutes => EVENT_DURATION_MINUTES
			});
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String relationship = UTIL_SObjectDescribe.getCachedFieldDescribe(Event.WhatId).getRelationshipName() + UTIL_String.DOT;
		String relatedType = relationship + UTIL_SObjectDescribe.getCachedFieldName(Account.Type);
		String relatedId = relationship + UTIL_SObjectDescribe.getCachedFieldName(Account.Id);

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the user to have no read on the WhatId lookup of an Event');
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'filter on the type of the related record' => newEventQuery(linkedEvent.Id)
							.andCondition(relatedType).equals(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType)).bypassSharing()
			}, buildPathRefusalMessage(relatedType));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'filter on the id of the related record' => newEventQuery(linkedEvent.Id)
							.andCondition(relatedId).equals(linkedEvent.WhatId).bypassSharing()
			}, buildPathRefusalMessage(relatedId));
		}
	}

	/**
	 * @description bypassSharing() alone does not check a path through more than five parent records, because SOQL
	 * refuses such a query. The user may read every Foobar__c field except Email__c. A filter on a path through six
	 * parents to Email__c is not refused by the builder: the query runs and SOQL refuses it with its own QueryException.
	 */
	@IsTest
	private static void bypassSharingAloneLeavesAPathThroughMoreThanFiveParentsToSoql()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String relationship = UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Lookup__c).getRelationshipName() + UTIL_String.DOT;
		String sixParentsEmail = relationship.repeat(MAXIMUM_PARENT_LEVELS) + buildParentEmailPath();

		System.runAs(restricted)
		{
			try
			{
				List<SObject> rows = newRowQuery(row.Id).andCondition(sixParentsEmail).equals(row.Email__c).bypassSharing().toList();
				Assert.fail('Expected SOQL to refuse a path through six parents; it returned ' + rows.size() + ' rows');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected SOQL to refuse the path. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
				Assert.areNotEqual(buildPathRefusalMessage(sixParentsEmail), error.getMessage(), 'Expected the refusal to come from SOQL, not from the builder');
			}
		}
	}

	/**
	 * @description bypassSharing() alone reads an Event through a filter on the name of its related record, even when the
	 * running user cannot read the object of that record. The user is a Standard User, who cannot read Foobar__c, and owns
	 * an Event whose Related To field points to a Foobar__c row the test administrator owns. Saving that Event shows that
	 * an Event can be related to a Foobar__c row. SOQL reads What.Name from a shared Name record, and Salesforce checks
	 * only the WhatId lookup and the Name field of that record, not the Foobar__c object. So the filter on What.Name reads
	 * the Event with bypassSharing(), and the same filter reads it in user mode without bypassSharing().
	 */
	@IsTest
	private static void bypassSharingAloneFiltersOnTheNameOfARecordOnAnObjectTheUserCannotRead()
	{
		User reader = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		Foobar__c relatedRow = insertRowOwnedByAdmin(null);
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			linkedEvent = insertEventOwnedBy(reader.Id, relatedRow.Id, null);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String relatedName = buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name));

		System.runAs(reader)
		{
			assertStandardUserReadsTheLookupButNotFoobar();
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				List<SObject> rows = applyAccess(newEventQuery(linkedEvent.Id).andCondition(relatedName).equals(relatedRow.Name), isSharingBypassed).toList();
				Assert.areEqual(1, rows.size(), 'Expected the filter on the name of the Foobar__c row to read the Event, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(linkedEvent.Id, rows[0].Id, 'Expected the row to be the Event that points to the Foobar__c row');
			}
		}
	}

	/**
	 * @description bypassSharing() alone counts the Events that a filter on the name of the related record finds, even
	 * when the running user cannot read the object of that record. The user is a Standard User, who cannot read
	 * Foobar__c, and owns an Event related to a Foobar__c row the test administrator owns. With a filter on What.Name
	 * equal to the name of that row, count() is one and exists() is true, with bypassSharing() and in user mode without it.
	 */
	@IsTest
	private static void bypassSharingAloneCountsThroughTheNameOfARecordOnAnObjectTheUserCannotRead()
	{
		User reader = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		Foobar__c relatedRow = insertRowOwnedByAdmin(null);
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			linkedEvent = insertEventOwnedBy(reader.Id, relatedRow.Id, null);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String relatedName = buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name));

		System.runAs(reader)
		{
			assertStandardUserReadsTheLookupButNotFoobar();
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				Integer total = applyAccess(newEventQuery(linkedEvent.Id).andCondition(relatedName).equals(relatedRow.Name), isSharingBypassed).count();
				Boolean isFound = applyAccess(newEventQuery(linkedEvent.Id).andCondition(relatedName).equals(relatedRow.Name), isSharingBypassed).exists();
				Assert.areEqual(1, total, 'Expected count() to find the Event, sharing bypassed: ' + isSharingBypassed);
				Assert.isTrue(isFound, 'Expected exists() to find the Event, sharing bypassed: ' + isSharingBypassed);
			}
		}
	}

	/**
	 * @description bypassSharing() alone reads a child query that selects, or filters on, the name of a related record on
	 * an object the user cannot read. The user is a Standard User, who cannot read Foobar__c, and owns a contact with
	 * one Event. The Event is about the contact and is related to a Foobar__c row the test administrator owns. A contact
	 * query with a child query of its Events that only selects What.Name returns the Event with the name of the row. The
	 * same child query with a filter on What.Name returns it too. Each read gives the same answer with bypassSharing()
	 * and in user mode without it.
	 */
	@IsTest
	private static void bypassSharingAloneReadsAChildQueryThroughTheNameOfARecordOnAnObjectTheUserCannotRead()
	{
		User reader = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		Foobar__c relatedRow = insertRowOwnedByAdmin(null);
		Contact person;
		System.runAs(getTestAdmin())
		{
			person = insertContactBypassingValidation(new Map<SObjectField, Object> {Contact.OwnerId => reader.Id});
			insertEventOwnedBy(reader.Id, relatedRow.Id, person.Id);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String relatedName = buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name));

		System.runAs(reader)
		{
			assertStandardUserReadsTheLookupButNotFoobar();
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				Map<String, QRY_Builder.Builder> childQueriesByCase = new Map<String, QRY_Builder.Builder>
				{
						'child query that selects the name' => QRY_Builder.selectFrom(Event.SObjectType).fields(new List<String> {relatedName}),
						'child query that filters on the name' => QRY_Builder.selectFrom(Event.SObjectType)
								.fields(new List<String> {relatedName})
								.condition(relatedName)
								.equals(relatedRow.Name)
				};
				for(String testCase : childQueriesByCase.keySet())
				{
					List<SObject> rows = applyAccess(newContactQuery()
							.condition(Contact.Id).equals(person.Id)
							.subselect(childQueriesByCase.get(testCase), CHILD_EVENTS_RELATIONSHIP), isSharingBypassed).toList();
					Assert.areEqual(1, rows.size(), 'Expected the contact to come back for the ' + testCase + ', sharing bypassed: ' + isSharingBypassed);
					List<SObject> events = rows[0].getSObjects(CHILD_EVENTS_RELATIONSHIP);
					Assert.areEqual(1, events?.size(), 'Expected the contact to come back with its Event for the ' + testCase + ', sharing bypassed: ' + isSharingBypassed);
					Assert.areEqual(relatedRow.Name, events[0].getSObject(Event.WhatId)?.get(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name)),
							'Expected the Event to carry the name of the Foobar__c row for the ' + testCase + ', sharing bypassed: ' + isSharingBypassed);
				}
			}
		}
	}

	/**
	 * @description bypassSharing() alone refuses a read that selects a related record through a lookup the user cannot
	 * read. The user may read accounts and contacts, but not the WhatId and WhoId lookups of an Event, and owns an Event
	 * related to an account and to a contact. A read that selects What.Name, What.Type or What.Id, or Who.Name, is
	 * refused with the message that names the lookup and the path, and no query runs. So is a TYPEOF on What, whose
	 * message names the relationship, and What.Name written with the object name in front, as Event.What.Name. An
	 * account query whose child query of Events is written as text in the selected fields is refused with the message
	 * that says the builder cannot check that text. A filter on What.Name and a sort on it are refused with the message
	 * that names the path. count() and exists() still answer when the query selects What.Name, because the query they
	 * run selects no fields. The same Event reads in user mode, without bypassSharing(), give the same answers:
	 * Salesforce refuses each read, and counts the Event. The Event read in user mode without the path comes back, so
	 * each of these refusals is caused by the path.
	 *
	 * A child query finds its rows through their lookup to the parent. An account query with a child query of Events
	 * that selects only the Id is refused with the message that names WhatId and the relationship, and so are Events in
	 * a child query of contacts, through WhoId. Salesforce refuses both in user mode. The account comes back without them.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesASelectedPathThroughALookupTheUserCannotRead()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Account.SObjectType, Contact.SObjectType},
						READ_PERMISSIONS,
						Account.Type
				);
		Event linkedEvent = insertEventWithAccountAndContact(restricted);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String whatRelationship = UTIL_SObjectDescribe.getCachedFieldDescribe(Event.WhatId).getRelationshipName();
		Map<String, SObjectField> lookupsByPath = new Map<String, SObjectField>
		{
				buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Account.Name)) => Event.WhatId,
				buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Account.Type)) => Event.WhatId,
				buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Account.Id)) => Event.WhatId,
				buildRelationshipPath(Event.WhoId, UTIL_SObjectDescribe.getCachedFieldName(Contact.Name)) => Event.WhoId
		};
		String relatedName = buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Account.Name));
		String relatedNameAfterObject = UTIL_SObjectDescribe.getObjectNameFromType(Event.SObjectType) + UTIL_String.DOT + relatedName;
		lookupsByPath.put(relatedNameAfterObject, Event.WhatId);

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the user to have no read on the WhatId lookup of an Event');
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Event.WhoId), 'Expected the user to have no read on the WhoId lookup of an Event');
			QRY_Builder.Builder eventControl = newEventQuery(linkedEvent.Id).withUserMode();
			for(String selectedPath : lookupsByPath.keySet())
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
				{
						'selected ' + selectedPath => newEventQuery(linkedEvent.Id).addField(selectedPath).bypassSharing()
				}, buildLookupRefusalMessage(lookupsByPath.get(selectedPath), selectedPath));
				assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
				{
						'selected ' + selectedPath => newEventQuery(linkedEvent.Id).addField(selectedPath).withUserMode()
				}, eventControl);
			}
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'TYPEOF on the related record' => newEventQuery(linkedEvent.Id).addField(TYPEOF_ACCOUNT_NAME_AND_PHONE).bypassSharing()
			}, buildLookupRefusalMessage(Event.WhatId, whatRelationship));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'child query written as text' => newAccountQuery(linkedEvent.WhatId).addField(EVENTS_CHILD_QUERY_TEXT).bypassSharing()
			}, buildSelectedTextRefusalMessage(EVENTS_CHILD_QUERY_TEXT));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'filter on the name of the related record' => newEventQuery(linkedEvent.Id).andCondition(relatedName).equals(UTIL_Random.randomName()).bypassSharing(),
					'sort on the name of the related record' => newEventQuery(linkedEvent.Id).orderBy(relatedName).bypassSharing()
			}, buildPathRefusalMessage(relatedName));
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'TYPEOF on the related record' => newEventQuery(linkedEvent.Id).addField(TYPEOF_ACCOUNT_NAME_AND_PHONE).withUserMode(),
					'filter on the name of the related record' => newEventQuery(linkedEvent.Id).andCondition(relatedName).equals(UTIL_Random.randomName()).withUserMode(),
					'sort on the name of the related record' => newEventQuery(linkedEvent.Id).orderBy(relatedName).withUserMode()
			}, eventControl);
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				Integer total = applyAccess(newEventQuery(linkedEvent.Id).addField(relatedName), isSharingBypassed).count();
				Boolean isFound = applyAccess(newEventQuery(linkedEvent.Id).addField(relatedName), isSharingBypassed).exists();
				Assert.areEqual(1, total, 'Expected count() to find the Event though the query selects What.Name, sharing bypassed: ' + isSharingBypassed);
				Assert.isTrue(isFound, 'Expected exists() to find the Event though the query selects What.Name, sharing bypassed: ' + isSharingBypassed);
			}
			String eventId = UTIL_SObjectDescribe.getCachedFieldName(Event.Id);
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'child query of Events' => newAccountEventsQuery(linkedEvent.WhatId, eventId).bypassSharing()
			}, buildLookupRefusalMessage(Event.WhatId, CHILD_EVENTS_RELATIONSHIP));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'Events in a child query of contacts' => newAccountContactEventsQuery(linkedEvent.WhatId).bypassSharing()
			}, buildLookupRefusalMessage(Event.WhoId, CHILD_EVENTS_RELATIONSHIP));
			Assert.areEqual(1, newAccountQuery(linkedEvent.WhatId).bypassSharing().toList().size(), 'Expected the account read without a child query to return the account');
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'child query of Events' => newAccountEventsQuery(linkedEvent.WhatId, eventId).withUserMode(),
					'Events in a child query of contacts' => newAccountContactEventsQuery(linkedEvent.WhatId).withUserMode()
			}, newAccountQuery(linkedEvent.WhatId).withUserMode());
		}
	}

	/**
	 * @description bypassSharing() alone refuses a child query through a lookup the user cannot read: its rows would
	 * show the value of that lookup. The user may read every Foobar__c field except Lookup__c and owns a row with one
	 * child row. A child query of its Foobars__r rows that selects only the Id is refused with the message that names
	 * Lookup__c and the relationship, written with the package namespace or without it. A relationship Foobar__c does
	 * not have is refused with the message that says the builder cannot check it. No query runs, and the row read
	 * without a child query comes back. Salesforce refuses both child queries in user mode.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAChildQueryThroughALookupTheUserCannotRead()
	{
		User restricted = insertReaderWithOneHiddenField(Foobar__c.Lookup__c);
		Foobar__c parentRow;
		System.runAs(getTestAdmin())
		{
			parentRow = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.OwnerId, restricted.Id).build();
		}
		insertRowOwnedByAdmin(parentRow.Id);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String namespacedFoobars = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_FOOBARS_RELATIONSHIP;

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Foobar__c.Lookup__c), 'Expected the user to have no read on Lookup__c');
			Assert.areEqual(1, newRowQuery(parentRow.Id).bypassSharing().toList().size(), 'Expected the row read without a child query to return the row');
			for(String relationshipName : new List<String> {namespacedFoobars, CHILD_FOOBARS_RELATIONSHIP})
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
				{
						'child query of ' + relationshipName => newRowChildrenQuery(parentRow.Id, relationshipName).bypassSharing()
				}, buildLookupRefusalMessage(Foobar__c.Lookup__c, relationshipName));
			}
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'unknown relationship' => newRowChildrenQuery(parentRow.Id, UNKNOWN_RELATIONSHIP).bypassSharing()
			}, buildSelectedTextRefusalMessage(UNKNOWN_RELATIONSHIP));
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'child query of ' + namespacedFoobars => newRowChildrenQuery(parentRow.Id, namespacedFoobars).withUserMode(),
					'unknown relationship' => newRowChildrenQuery(parentRow.Id, UNKNOWN_RELATIONSHIP).withUserMode()
			}, newRowQuery(parentRow.Id).withUserMode());
		}
	}

	/**
	 * @description bypassSharing() alone checks a child query as the object its relationship reads, not the object its
	 * builder was made for. The child query is built for User, filters on User__c and is added as the LoginFrequencies of
	 * a user, so SOQL reads LoginFrequency__c rows with it. A user who may read User but not LoginFrequency__c asks for
	 * their own user record with that child query. The read is refused with the message that names LoginFrequency__c, and no query runs. The same
	 * read built for LoginFrequency__c is refused by Salesforce in user mode, while the user read without the child
	 * query comes back.
	 *
	 * count() reads no child rows, but it still checks the object of a child query: a count of the user with a child
	 * query built for LoginFrequency__c and added as its LoginFrequencies is refused with the message that names
	 * LoginFrequency__c, and no query runs.
	 */
	@IsTest
	private static void bypassSharingAloneChecksAChildQueryAsTheObjectItsRelationshipReads()
	{
		User restricted = insertRestrictedReader();
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String loginFrequencies = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_LOGIN_FREQUENCIES_RELATIONSHIP;

		System.runAs(restricted)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isObjectAccessible(User.SObjectType), 'Expected the user to be able to read User');
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(LoginFrequency__c.SObjectType), 'Expected the user to have no read on LoginFrequency__c');
			QRY_Builder.Builder childBuiltForUser = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<SObjectField> {User.Id})
					.condition(UTIL_SObjectDescribe.getCachedFieldName(LoginFrequency__c.User__c)).equals(restricted.Id);
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'child built for User' => newUserQuery(restricted.Id).subselect(childBuiltForUser, loginFrequencies).bypassSharing()
			}, QueryException.class, buildObjectRefusalMessage(LoginFrequency__c.SObjectType));
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'child built for LoginFrequency__c' => newUserQuery(restricted.Id)
							.subselect(newLoginFrequencyQuery().condition(LoginFrequency__c.User__c).equals(restricted.Id), loginFrequencies)
							.withUserMode()
			}, newUserQuery(restricted.Id).withUserMode());
			assertReadIsRefused('count with a child built for LoginFrequency__c', newUserQuery(restricted.Id).subselect(newLoginFrequencyQuery(), loginFrequencies)
					.bypassSharing(), TERMINAL_COUNT, QueryException.class, buildObjectRefusalMessage(LoginFrequency__c.SObjectType));
		}
	}

	/**
	 * @description bypassSharing() alone refuses a child query that selects a path through a hidden lookup when the
	 * lookup behind the child relationship is readable. The user may read accounts, contacts and the WhoId lookup of an
	 * Event, but not WhatId, and owns an account, a contact of that account and an Event about the contact. A contact
	 * query whose child query of Events selects What.Name is refused with the message that names WhatId and the path,
	 * with or without selectAllFields(), and no query runs. So is the same child query built for Account: it is checked
	 * as the Events it reads, not as an account. The same child query that selects only the Id comes back with the
	 * Event. Salesforce refuses the path in user mode and answers without it, so the path causes the refusal.
	 *
	 * An account query with a child query of its contacts, and inside it a child query of their Events, comes back with
	 * the account, the contact and the Event, with bypassSharing() and in user mode. So a child query inside a child
	 * query is read when the user can read WhoId.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAPathInAChildQueryThroughAnotherLookupTheUserCannotRead()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_MINIMUM_ACCESS, new List<SObjectType> {Account.SObjectType, Contact.SObjectType},
				READ_PERMISSIONS, Account.Type);
		grantReadOnEventField(restricted, Event.WhoId);
		Event linkedEvent = insertEventWithAccountAndContact(restricted);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String relatedName = buildRelationshipPath(Event.WhatId, UTIL_SObjectDescribe.getCachedFieldName(Account.Name));
		String eventId = UTIL_SObjectDescribe.getCachedFieldName(Event.Id);

		System.runAs(restricted)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Event.WhoId), 'Expected the user to be able to read the WhoId lookup of an Event');
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the user to have no read on the WhatId lookup of an Event');
			QRY_Builder.Builder childBuiltForAccount = QRY_Builder.selectFrom(Account.SObjectType).fields(new List<String> {relatedName});
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'path in a child query' => newContactEventsQuery(linkedEvent.WhoId, relatedName).bypassSharing(),
					'path in a child query with selectAllFields()' => newContactEventsQuery(linkedEvent.WhoId, relatedName).selectAllFields().bypassSharing(),
					'path in a child query built for Account' => newContactQuery().condition(Contact.Id).equals(linkedEvent.WhoId)
							.subselect(childBuiltForAccount, CHILD_EVENTS_RELATIONSHIP)
							.bypassSharing()
			}, buildLookupRefusalMessage(Event.WhatId, relatedName));
			List<SObject> rows = newContactEventsQuery(linkedEvent.WhoId, eventId).bypassSharing().toList();
			Assert.areEqual(1, rows.size(), 'Expected the contact to come back');
			Assert.areEqual(1, rows[0].getSObjects(CHILD_EVENTS_RELATIONSHIP)?.size(), 'Expected the contact to come back with its Event');
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'path in a child query' => newContactEventsQuery(linkedEvent.WhoId, relatedName).withUserMode()
			}, newContactEventsQuery(linkedEvent.WhoId, eventId).withUserMode());
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				List<SObject> accountRows = applyAccess(newAccountContactEventsQuery(linkedEvent.WhatId), isSharingBypassed).toList();
				Assert.areEqual(1, accountRows.size(), 'Expected the account to come back, sharing bypassed: ' + isSharingBypassed);
				List<SObject> contactRows = accountRows[0].getSObjects(CHILD_CONTACTS_RELATIONSHIP);
				Assert.areEqual(1, contactRows?.size(), 'Expected the account to come back with its contact, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(1, contactRows[0].getSObjects(CHILD_EVENTS_RELATIONSHIP)?.size(),
						'Expected the contact to come back with its Event in the child query of contacts, sharing bypassed: ' + isSharingBypassed);
			}
		}
	}

	/**
	 * @description count() and exists() with bypassSharing() alone answer for a query with a child query, even when the
	 * user cannot read the lookup behind the child relationship, or when the parent object has no child relationship of
	 * that name. The query that counts the rows has no child query, so Salesforce answers it in user mode too. The user
	 * may read Foobar__c, but not the WhatId lookup of an Event, and owns a Foobar__c row with an Event related to it. A
	 * Foobar__c query with a child query of its Events, and a Foobar__c query with a child query added under a name a
	 * Foobar__c row does not have, each count one row and find it, with bypassSharing() and in user mode. The Foobar__c
	 * query with the child query of Events is still refused when it reads the rows.
	 */
	@IsTest
	private static void bypassSharingAloneCountsWithAChildQueryTheCountDoesNotRead()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_MINIMUM_ACCESS, new List<SObjectType> {Foobar__c.SObjectType}, READ_PERMISSIONS,
				Foobar__c.Email__c);
		Foobar__c ownRow;
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			ownRow = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.OwnerId, restricted.Id).build();
			linkedEvent = insertEventOwnedBy(restricted.Id, ownRow.Id, null);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the user to have no read on the WhatId lookup of an Event');
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				for(String relationshipName : new List<String> {CHILD_EVENTS_RELATIONSHIP, UNKNOWN_CHILD_RELATIONSHIP})
				{
					Integer total = applyAccess(newRowChildEventsQuery(linkedEvent.WhatId, relationshipName), isSharingBypassed).count();
					Boolean isFound = applyAccess(newRowChildEventsQuery(linkedEvent.WhatId, relationshipName), isSharingBypassed).exists();
					Assert.areEqual(1, total, 'Expected count() to find the Foobar__c row with a child query of ' + relationshipName + ', sharing bypassed: '
							+ isSharingBypassed);
					Assert.isTrue(isFound, 'Expected exists() to find the Foobar__c row with a child query of ' + relationshipName + ', sharing bypassed: '
							+ isSharingBypassed);
				}
			}
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'child query of Events' => newRowChildEventsQuery(linkedEvent.WhatId, CHILD_EVENTS_RELATIONSHIP).bypassSharing()
			}, buildLookupRefusalMessage(Event.WhatId, CHILD_EVENTS_RELATIONSHIP));
		}
	}

	/**
	 * @description bypassSharing() alone reads a child relationship name written in each way SOQL accepts it: with the
	 * parent object in front, as Account.Events, with spaces around it, and in other letters, as events. The test
	 * administrator owns an account with one Event related to it, and reads the account with its Event under each name,
	 * with bypassSharing() and in user mode. A user who may read accounts and contacts, but not the WhatId lookup of an
	 * Event, owns another such account. For that user each name is refused with the message that names WhatId and the
	 * name without the spaces around it, and no query runs. Salesforce refuses each name in user mode, while the account
	 * read without the child query comes back.
	 */
	@IsTest
	private static void bypassSharingAloneReadsAChildRelationshipNameWrittenAsSoqlAcceptsIt()
	{
		User admin = getTestAdmin();
		User restricted = TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_MINIMUM_ACCESS, new List<SObjectType> {Account.SObjectType, Contact.SObjectType},
				READ_PERMISSIONS, Account.Type);
		Event adminEvent = insertEventWithAccountAndContact(admin);
		Event restrictedEvent = insertEventWithAccountAndContact(restricted);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		List<String> relationshipNames = new List<String>
		{
				UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType) + UTIL_String.DOT + CHILD_EVENTS_RELATIONSHIP,
				UTIL_String.SPACE + CHILD_EVENTS_RELATIONSHIP + UTIL_String.SPACE,
				CHILD_EVENTS_RELATIONSHIP.toLowerCase()
		};

		System.runAs(admin)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the test administrator to be able to read the WhatId lookup of an Event');
			for(String relationshipName : relationshipNames)
			{
				for(Boolean isSharingBypassed : new List<Boolean> {true, false})
				{
					List<SObject> rows = applyAccess(newAccountChildEventsQuery(adminEvent.WhatId, relationshipName), isSharingBypassed).toList();
					Assert.areEqual(1, rows.size(), 'Expected the account to come back for the name "' + relationshipName + '", sharing bypassed: ' + isSharingBypassed);
					Assert.areEqual(1, rows[0].getSObjects(CHILD_EVENTS_RELATIONSHIP)?.size(),
							'Expected the account to come back with its Event for the name "' + relationshipName + '", sharing bypassed: ' + isSharingBypassed);
				}
			}
		}
		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the user to have no read on the WhatId lookup of an Event');
			for(String relationshipName : relationshipNames)
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
				{
						'child query of "' + relationshipName + '"' => newAccountChildEventsQuery(restrictedEvent.WhatId, relationshipName).bypassSharing()
				}, buildLookupRefusalMessage(Event.WhatId, relationshipName.trim()));
				assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
				{
						'child query of "' + relationshipName + '"' => newAccountChildEventsQuery(restrictedEvent.WhatId, relationshipName).withUserMode()
				}, newAccountQuery(restrictedEvent.WhatId).withUserMode());
			}
		}
	}

	/**
	 * @description bypassSharing() alone checks the filter of a child query on the object its relationship reads, not
	 * on the object its builder was made for, nor on the object of the parent query. The parent query reads the user's
	 * own user record. The child relationship LoginFrequencies of a user reads LoginFrequency__c rows. The user may read
	 * LoginFrequency__c, but not its TotalLoginCount__c, and owns a LoginFrequency__c row that points to the user.
	 *
	 * A child query built for User that filters on TotalLoginCount__c, added as the LoginFrequencies of the user, is
	 * refused with the message that names TotalLoginCount__c, and no query runs. User has no TotalLoginCount__c field, so
	 * a check on User would let the read run.
	 *
	 * Salesforce refuses the same filter in user mode on a child query built for LoginFrequency__c, while the user read
	 * without the child query comes back. The two child queries give the same SOQL, because SOQL names the relationship
	 * and not the object the builder was made for.
	 *
	 * The count() read with the child query built for LoginFrequency__c that filters on TotalLoginCount__c is refused the
	 * same way, so count() also checks the filter of a child query.
	 *
	 * The other way round: a child query built for ApiIssue__c, which the user cannot read, added as the
	 * LoginFrequencies of the user and selecting only the Id, reads the user record with its LoginFrequency__c row, with
	 * bypassSharing() and in user mode.
	 */
	@IsTest
	private static void bypassSharingAloneChecksTheFilterOfAChildQueryOnTheObjectItsRelationshipReads()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_STANDARD_USER, new List<SObjectType> {LoginFrequency__c.SObjectType},
				READ_PERMISSIONS, LoginFrequency__c.TotalLoginCount__c);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(LoginFrequency__c.SObjectType)
					.withOverride(LoginFrequency__c.User__c, restricted.Id)
					.withOverride(LoginFrequency__c.OwnerId, restricted.Id)
					.withOverride(LoginFrequency__c.TotalLoginCount__c, TOTAL_LOGIN_COUNT)
					.build();
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String loginFrequencies = UTIL_System.getManagedPackageNamespacePrefix() + CHILD_LOGIN_FREQUENCIES_RELATIONSHIP;

		System.runAs(restricted)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isObjectAccessible(LoginFrequency__c.SObjectType), 'Expected the user to be able to read LoginFrequency__c');
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(LoginFrequency__c.User__c), 'Expected the user to be able to read the User__c of a LoginFrequency__c row');
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(LoginFrequency__c.TotalLoginCount__c),
					'Expected the user to have no read on the TotalLoginCount__c of a LoginFrequency__c row');
			Assert.isNull(UTIL_SObjectDescribe.getDescribe(User.SObjectType).getField(UTIL_SObjectDescribe.getCachedFieldName(LoginFrequency__c.TotalLoginCount__c)),
					'Expected User to have no field of the same name, so a check on User finds nothing to refuse');
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(ApiIssue__c.SObjectType), 'Expected the user to have no read on ApiIssue__c');
			QRY_Builder.Builder childBuiltForUser = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<SObjectField> {User.Id})
					.condition(UTIL_SObjectDescribe.getCachedFieldName(LoginFrequency__c.TotalLoginCount__c)).equals(TOTAL_LOGIN_COUNT);
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'filter of a child built for User' => newUserQuery(restricted.Id).subselect(childBuiltForUser, loginFrequencies).bypassSharing()
			}, buildFieldRefusalMessage(LoginFrequency__c.TotalLoginCount__c));
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'filter of a child built for LoginFrequency__c' => newUserQuery(restricted.Id)
							.subselect(newLoginFrequencyQuery().condition(LoginFrequency__c.TotalLoginCount__c).equals(TOTAL_LOGIN_COUNT), loginFrequencies)
							.withUserMode()
			}, newUserQuery(restricted.Id).withUserMode());
			assertReadIsRefused('count with a filter of a child built for LoginFrequency__c', newUserQuery(restricted.Id)
					.subselect(newLoginFrequencyQuery().condition(LoginFrequency__c.TotalLoginCount__c).equals(TOTAL_LOGIN_COUNT), loginFrequencies).bypassSharing(),
					TERMINAL_COUNT, UTIL_Exceptions.IllegalStateException.class, buildFieldRefusalMessage(LoginFrequency__c.TotalLoginCount__c));
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				QRY_Builder.Builder childBuiltForApiIssue = QRY_Builder.selectFrom(ApiIssue__c.SObjectType).fields(new List<SObjectField> {ApiIssue__c.Id});
				List<SObject> rows = applyAccess(newUserQuery(restricted.Id).subselect(childBuiltForApiIssue, loginFrequencies), isSharingBypassed).toList();
				Assert.areEqual(1, rows.size(), 'Expected the user record to come back with a child built for ApiIssue__c, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(1, rows[0].getSObjects(loginFrequencies)?.size(),
						'Expected the user record to come back with its LoginFrequency__c row, sharing bypassed: ' + isSharingBypassed);
			}
		}
	}

	/**
	 * @description bypassSharing() alone reads a child query through a relationship name that the parent object lists
	 * more than once, for two lookups that point to it. The describe of User lists ApprovalSubmissions twice in some
	 * orgs, through two lookups of an approval submission. The test proves something only in an org where it does: the
	 * test administrator, who can read every lookup behind that name, reads their own user record with a child query of
	 * ApprovalSubmissions that selects only the Id, with bypassSharing() and in user mode, and each read returns the
	 * user. In an org where the describe of User does not list the name twice, the test reads nothing and proves
	 * nothing.
	 */
	@IsTest
	private static void bypassSharingAloneReadsAChildRelationshipNameListedMoreThanOnce()
	{
		User admin = getTestAdmin();
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		System.runAs(admin)
		{
			List<ChildRelationship> relationshipsOfName = new List<ChildRelationship>();
			for(ChildRelationship relationship : UTIL_SObjectDescribe.getDescribe(User.SObjectType).getDescribe().getChildRelationships())
			{
				if(relationship.getRelationshipName() == CHILD_APPROVAL_SUBMISSIONS_RELATIONSHIP)
				{
					relationshipsOfName.add(relationship);
				}
			}
			if(relationshipsOfName.size() < 2)
			{
				return;
			}
			SObjectType childType = relationshipsOfName[0].getChildSObject();
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				QRY_Builder.Builder childQuery = QRY_Builder.selectFrom(childType).fields(new List<String> {UTIL_SObjectDescribe.getCachedFieldName(User.Id)});
				List<SObject> rows = applyAccess(QRY_Builder.selectFrom(User.SObjectType)
						.fields(new List<SObjectField> {User.Id})
						.condition(User.Id).equals(admin.Id)
						.subselect(childQuery, CHILD_APPROVAL_SUBMISSIONS_RELATIONSHIP), isSharingBypassed).toList();
				Assert.areEqual(1, rows.size(), 'Expected the user to come back with a child query of ' + CHILD_APPROVAL_SUBMISSIONS_RELATIONSHIP + ', listed '
						+ relationshipsOfName.size() + ' times, sharing bypassed: ' + isSharingBypassed);
			}
		}
	}

	/**
	 * @description bypassSharing() alone never returns the value of an aggregate function written as selected text over
	 * a field the user cannot read. An aggregate function, such as MAX(), reads one value from many rows. The user may
	 * read Foobar__c but not its Phone__c, and owns a Foobar__c row with a phone number. A read that selects
	 * MAX(Phone__c) as text throws the exception Salesforce gives when it is asked to remove hidden fields from
	 * aggregate rows, and nothing comes back.
	 */
	@IsTest
	private static void bypassSharingAloneNeverReturnsAnAggregateFunctionWrittenAsSelectedText()
	{
		User restricted = insertReaderWithOneHiddenField(Foobar__c.Phone__c);
		Foobar__c ownRow;
		System.runAs(getTestAdmin())
		{
			ownRow = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.OwnerId, restricted.Id)
					.withOverride(Foobar__c.Phone__c, TEST_PHONE_NUMBER)
					.build();
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String highestPhone = MAX_FUNCTION + OPENING_BRACKET + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Phone__c) + CLOSING_BRACKET + UTIL_String.SPACE
				+ HIGHEST_VALUE_ALIAS;

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Foobar__c.Phone__c), 'Expected the user to have no read on the Phone__c of a Foobar__c row');
			List<SObject> rows;
			try
			{
				rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.fields(new List<String> {highestPhone})
						.condition(Foobar__c.Id).equals(ownRow.Id)
						.bypassSharing()
						.toList();
				Assert.fail('Expected the read of ' + highestPhone + ' to throw; it returned ' + rows.size() + ' rows');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, InvalidParameterValueException.class,
						'Expected the read of ' + highestPhone + ' to throw. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
			}
		}
	}

	/**
	 * @description bypassSharing() alone answers a child query of a standard child relationship of an account as user
	 * mode does. The user is a Standard User who owns an account. For each relationship in
	 * STANDARD_ACCOUNT_CHILD_RELATIONSHIPS that the describe of Account lists, an account query with a child query of
	 * that name that selects only the Id is read in user mode and with bypassSharing() alone. Both reads must answer
	 * and return the account. A name the describe does not list is left out. The describe must list at least one of
	 * the names, so that the test cannot pass without reading anything. Any error a read throws fails the test.
	 *
	 * ActivityHistories and OpenActivities are read with a LIMIT of 500 and a sort on ActivityDate and LastModifiedDate.
	 * For a user without administrator permissions, Salesforce reads them in user mode only in that form. Without it,
	 * user mode stops the read with an error that a test cannot catch, while bypassSharing() alone reads them.
	 */
	@IsTest
	private static void bypassSharingAloneAnswersTheStandardChildQueriesOfAnAccountAsUserModeDoes()
	{
		User reader = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		Account ownAccount;
		System.runAs(getTestAdmin())
		{
			ownAccount = insertAccountBypassingValidation(new Map<SObjectField, Object> {Account.OwnerId => reader.Id});
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		Map<String, SObjectType> childTypesByName = new Map<String, SObjectType>();
		for(ChildRelationship relationship : UTIL_SObjectDescribe.getDescribe(Account.SObjectType).getDescribe().getChildRelationships())
		{
			childTypesByName.put(relationship.getRelationshipName(), relationship.getChildSObject());
		}
		String idName = UTIL_SObjectDescribe.getCachedFieldName(Account.Id);

		System.runAs(reader)
		{
			Assert.isFalse(newAccountQuery(ownAccount.Id).withUserMode().toList().isEmpty(), 'Expected the user mode read of the account alone to return it');
			Integer listedCount = 0;
			for(String relationshipName : STANDARD_ACCOUNT_CHILD_RELATIONSHIPS)
			{
				SObjectType childType = childTypesByName.get(relationshipName);
				if(childType == null)
				{
					continue;
				}
				listedCount++;
				for(Boolean isSharingBypassed : new List<Boolean> {true, false})
				{
					QRY_Builder.Builder childQuery = QRY_Builder.selectFrom(childType).fields(new List<String> {idName});
					Boolean isActivityDateDescending = ACTIVITY_DATE_DESCENDING_BY_RELATIONSHIP.get(relationshipName);
					if(isActivityDateDescending != null)
					{
						childQuery.withLimit(ACTIVITY_CHILD_QUERY_LIMIT)
								.orderBy(UTIL_SObjectDescribe.getCachedFieldName(ActivityHistory.ActivityDate), isActivityDateDescending)
								.orderBy(UTIL_SObjectDescribe.getCachedFieldName(ActivityHistory.LastModifiedDate), true);
					}
					List<Account> rows = applyAccess(newAccountQuery(ownAccount.Id).subselect(childQuery, relationshipName), isSharingBypassed).toList();
					Assert.areEqual(1, rows.size(), 'Expected the read of the account with its child query of ' + relationshipName
							+ ' to return the account, sharing bypassed: ' + isSharingBypassed);
				}
			}
			Assert.isTrue(listedCount > 0, 'Expected the describe of Account to list at least one of ' + STANDARD_ACCOUNT_CHILD_RELATIONSHIPS);
		}
	}

	/**
	 * @description bypassSharing() alone refuses selected text it cannot check, even for a user who can read every
	 * object and field involved. The user is the test administrator, who owns a Foobar__c row with one Event related to
	 * it. A Foobar__c query whose child query of Events is written as text in the selected fields, and an Event query
	 * that selects a field and a TYPEOF together in one text, are each refused with the message that says the builder
	 * cannot check the text, and no query runs. Kern is stricter than user mode here: the same reads in user mode,
	 * without bypassSharing(), return the Foobar__c row with its Event and the Event.
	 *
	 * Selected texts with a dot in the wrong place are refused with the same message, and no query runs: one dot, two
	 * dots, Subject with a dot after it, Subject with a dot before it, and What..Name. A TYPEOF whose WHEN branch names
	 * an Apex class and not an object is refused the same way. User mode refuses these too.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesSelectedTextItCannotCheckForAUserWhoCanReadEverything()
	{
		User admin = getTestAdmin();
		Foobar__c relatedRow = insertRowOwnedByAdmin(null);
		Event linkedEvent;
		System.runAs(admin)
		{
			linkedEvent = insertEventOwnedBy(admin.Id, relatedRow.Id, null);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		System.runAs(admin)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the test administrator to be able to read the WhatId lookup of an Event');
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'child query written as text' => newRowQuery(linkedEvent.WhatId).addField(EVENTS_CHILD_QUERY_TEXT).bypassSharing()
			}, buildSelectedTextRefusalMessage(EVENTS_CHILD_QUERY_TEXT));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'field and TYPEOF in one text' => newEventQuery(linkedEvent.Id).addField(SUBJECT_AND_TYPEOF).bypassSharing()
			}, buildSelectedTextRefusalMessage(SUBJECT_AND_TYPEOF));
			Map<String, QRY_Builder.Builder> userModeQueriesByCase = new Map<String, QRY_Builder.Builder>();
			for(String selectedText : SELECTED_TEXTS_WITH_A_MISPLACED_DOT)
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
				{
						'text with a misplaced dot: ' + selectedText => newEventQuery(linkedEvent.Id).addField(selectedText).bypassSharing()
				}, buildSelectedTextRefusalMessage(selectedText));
				userModeQueriesByCase.put('text with a misplaced dot: ' + selectedText, newEventQuery(linkedEvent.Id).addField(selectedText).withUserMode());
			}
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'TYPEOF whose WHEN names an Apex class' => newEventQuery(linkedEvent.Id).addField(TYPEOF_APEX_CLASS_TYPE).bypassSharing()
			}, buildSelectedTextRefusalMessage(TYPEOF_APEX_CLASS_TYPE));
			userModeQueriesByCase.put('TYPEOF whose WHEN names an Apex class', newEventQuery(linkedEvent.Id).addField(TYPEOF_APEX_CLASS_TYPE).withUserMode());
			assertUserModeRefusesEveryQuery(userModeQueriesByCase, newEventQuery(linkedEvent.Id).withUserMode());
			List<SObject> foobarRows = newRowQuery(linkedEvent.WhatId).addField(EVENTS_CHILD_QUERY_TEXT).withUserMode().toList();
			List<SObject> eventRows = newEventQuery(linkedEvent.Id).addField(SUBJECT_AND_TYPEOF).withUserMode().toList();
			Assert.areEqual(1, foobarRows.size(), 'Expected user mode to read the Foobar__c row with the child query written as text');
			Assert.areEqual(1, foobarRows[0].getSObjects(CHILD_EVENTS_RELATIONSHIP)?.size(), 'Expected user mode to read the Event of the Foobar__c row');
			Assert.areEqual(1, eventRows.size(), 'Expected user mode to read the Event with a field and a TYPEOF in one text');
		}
	}

	/**
	 * @description bypassSharing() alone refuses a TYPEOF field whose WHEN branch names an object the user cannot read.
	 * TYPEOF picks which fields of the related record to read by its object, and reaches the query as plain text. The
	 * user may read contacts and the WhatId lookup of an Event, but not accounts, and owns an Event related to a
	 * Foobar__c row the test administrator owns. The WHEN Account branch is checked by its object, whatever the Event
	 * points to. A TYPEOF with a WHEN Account branch is refused with the message that names Account,
	 * and the same read in user mode, without bypassSharing(), is refused by Salesforce, while the Event read without
	 * the TYPEOF comes back. The user may read WhoId, but not leads: a TYPEOF on Who whose second WHEN branch names
	 * Lead is refused with the message that names Lead, in user mode too. The same TYPEOF without the Lead branch reads
	 * the Event, with bypassSharing() and in user mode, so the Lead branch causes the refusal. A TYPEOF text the builder
	 * cannot read, because THEN is missing, a TYPEOF that names an object the org does not have, and a TYPEOF on a
	 * relationship an Event does not have, are refused with the message that says the builder cannot check the
	 * selected text. No query runs.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesATypeofWithATypeTheUserCannotRead()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Contact.SObjectType},
						READ_PERMISSIONS,
						Contact.Phone
				);
		grantReadOnEventRelatedTo(restricted);
		grantReadOnEventField(restricted, Event.WhoId);
		Foobar__c relatedRow = insertRowOwnedByAdmin(null);
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			linkedEvent = insertEventOwnedBy(restricted.Id, relatedRow.Id, null);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		System.runAs(restricted)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the user to be able to read the WhatId lookup of an Event');
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(Account.SObjectType), 'Expected the user to have no read on Account');
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Event.WhoId), 'Expected the user to be able to read WhoId');
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(Lead.SObjectType), 'Expected the user to have no read on Lead');
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'TYPEOF with an Account branch' => newEventQuery(linkedEvent.Id).addField(TYPEOF_ACCOUNT_NAME_AND_PHONE).bypassSharing()
			}, QueryException.class, buildObjectRefusalMessage(Account.SObjectType));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'second branch' => newEventQuery(linkedEvent.Id).addField(TYPEOF_CONTACT_THEN_LEAD).bypassSharing()
			}, QueryException.class, buildObjectRefusalMessage(Lead.SObjectType));
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'TYPEOF with an Account branch' => newEventQuery(linkedEvent.Id).addField(TYPEOF_ACCOUNT_NAME_AND_PHONE).withUserMode()
			}, newEventQuery(linkedEvent.Id).withUserMode());
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'second branch' => newEventQuery(linkedEvent.Id).addField(TYPEOF_CONTACT_THEN_LEAD).withUserMode()
			}, newEventQuery(linkedEvent.Id).addField(TYPEOF_CONTACT_ONLY).withUserMode());
			Assert.areEqual(1, newEventQuery(linkedEvent.Id).addField(TYPEOF_CONTACT_ONLY).bypassSharing().toList().size(),
					'Expected the TYPEOF on Who with only the Contact branch to read the Event');
			for(String typeofText : new List<String> {TYPEOF_WITHOUT_THEN, TYPEOF_UNKNOWN_TYPE, TYPEOF_UNKNOWN_RELATIONSHIP})
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
				{
						typeofText => newEventQuery(linkedEvent.Id).addField(typeofText).bypassSharing()
				}, buildSelectedTextRefusalMessage(typeofText));
			}
		}
	}

	/**
	 * @description bypassSharing() alone checks a TYPEOF whose WHEN branch names Location like any other object.
	 * Location is a standard object, and also the name of a system Apex type. The user may read contacts and the WhatId
	 * lookup of an Event, but not Location, and owns an Event related to a Foobar__c row the test administrator owns. For
	 * this user, the read is refused with the message that names Location, and Salesforce refuses the same read in user
	 * mode. The test administrator can read Location, and the same read comes back with the Event, with bypassSharing()
	 * and in user mode. The test takes Location from the list of all objects while it runs, so that the package does not
	 * depend on an object that some orgs may not have. The stored describes are cleared before each read, so the builder
	 * finds Location from its name alone.
	 */
	@IsTest
	private static void bypassSharingAloneChecksATypeofWhoseWhenNamesLocationLikeAnyObject()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Contact.SObjectType},
						READ_PERMISSIONS,
						Contact.Phone
				);
		grantReadOnEventRelatedTo(restricted);
		User admin = getTestAdmin();
		Foobar__c relatedRow = insertRowOwnedByAdmin(null);
		Event linkedEvent;
		System.runAs(admin)
		{
			linkedEvent = insertEventOwnedBy(restricted.Id, relatedRow.Id, null);
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		SObjectType locationType = Schema.getGlobalDescribe().get(LOCATION_OBJECT_NAME);
		Assert.isNotNull(locationType, 'Expected this org to have the Location object');

		System.runAs(restricted)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected the user to be able to read the WhatId lookup of an Event');
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(locationType), 'Expected the user to have no read on Location');
			String expectedMessage = buildObjectRefusalMessage(locationType);
			UTIL_SObjectDescribe.flushCache();
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'TYPEOF with a Location branch' => newEventQuery(linkedEvent.Id).addField(TYPEOF_LOCATION_NAME).bypassSharing()
			}, QueryException.class, expectedMessage);
			assertUserModeRefusesEveryQuery(new Map<String, QRY_Builder.Builder>
			{
					'TYPEOF with a Location branch' => newEventQuery(linkedEvent.Id).addField(TYPEOF_LOCATION_NAME).withUserMode()
			}, newEventQuery(linkedEvent.Id).withUserMode());
		}

		System.runAs(admin)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isObjectAccessible(locationType), 'Expected the test administrator to be able to read Location');
			UTIL_SObjectDescribe.flushCache();
			List<SObject> rows = newEventQuery(linkedEvent.Id).addField(TYPEOF_LOCATION_NAME).bypassSharing().toList();
			Assert.areEqual(1, rows.size(), 'Expected the TYPEOF with a Location branch to read the Event for a user who can read Location');
			Assert.areEqual(1, newEventQuery(linkedEvent.Id).addField(TYPEOF_LOCATION_NAME).withUserMode().toList().size(),
					'Expected the same TYPEOF read in user mode to read the Event for a user who can read Location');
		}
	}

	/**
	 * @description bypassSharing() alone refuses a read of the profile, the role or the record type of the shared Name
	 * record when the running user cannot read that field of the Name record. SOQL reads a lookup that can point to more
	 * than one object, such as What, Who or Owner on an Event, through a shared Name record. For a Minimum Access user,
	 * Salesforce marks its ProfileId, UserRoleId and RecordTypeId as not readable. The user may read accounts, contacts
	 * and record types, and the WhatId and WhoId lookups of an Event, and owns the Event. Each of these is refused, and
	 * no query runs:
	 * - a sort on each of the three fields through What, Who and Owner, with the message that names the path;
	 * - a sort on What.RecordType.Name, with the same message, because the record type field of the Name record is
	 *   hidden;
	 * - a read that selects What.RecordType.Name, with the message that names that field and the path;
	 * - a sort on, or a read that selects, Owner.Profile.Name or Owner.UserRole.Name, with the message that names
	 *   Profile or UserRole, objects the user cannot read;
	 * - a TYPEOF on What whose WHEN Account branch selects Owner.Profile.Name, with the message that names Profile;
	 * - a TYPEOF on What whose ELSE branch selects RecordType.Name, with the message that names the record type field of
	 *   the Name record and the path.
	 *
	 * A read that selects Owner.ProfileId, Owner.UserRoleId, What.ProfileId or What.RecordTypeId is not refused: the
	 * Event comes back, and the field the user cannot read is removed from the related record, as for any hidden last
	 * field of a path.
	 *
	 * The same reads in user mode, without bypassSharing(), are refused by Salesforce, the four selected fields
	 * included, while the Event read without the path comes back.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesTheUserFieldsOfTheNameRecordForAMinimumAccessUser()
	{
		User restricted = insertActivityReader(SEL_Profile.PROFILE_MINIMUM_ACCESS);
		Event linkedEvent = insertEventWithAccountAndContact(restricted);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String recordTypeName = buildRelationshipPath(Event.WhatId, buildRelationshipPath(Schema.Name.RecordTypeId, UTIL_SObjectDescribe.getCachedFieldName(RecordType.Name)));
		String profileName = buildRelationshipPath(Event.OwnerId, buildRelationshipPath(User.ProfileId, UTIL_SObjectDescribe.getCachedFieldName(Profile.Name)));
		String roleName = buildRelationshipPath(Event.OwnerId, buildRelationshipPath(User.UserRoleId, UTIL_SObjectDescribe.getCachedFieldName(UserRole.Name)));
		String elseRecordTypeName = buildRelationshipPath(Schema.Name.RecordTypeId, UTIL_SObjectDescribe.getCachedFieldName(RecordType.Name));
		List<String> userFieldPaths = buildNameRecordUserFieldPaths(true);

		System.runAs(restricted)
		{
			for(SObjectField nameRecordField : new List<SObjectField> {Schema.Name.ProfileId, Schema.Name.UserRoleId, Schema.Name.RecordTypeId})
			{
				Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(nameRecordField),
						'Expected a Minimum Access user to have no read on ' + UTIL_SObjectDescribe.getCachedFieldName(nameRecordField) + ' of the Name record');
			}
			QRY_Builder.Builder eventControl = newEventQuery(linkedEvent.Id).withUserMode();
			for(String path : userFieldPaths)
			{
				assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
				{
						'sort on ' + path => newEventQuery(linkedEvent.Id).orderBy(path).bypassSharing()
				}, buildPathRefusalMessage(path));
			}
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'sort on ' + recordTypeName => newEventQuery(linkedEvent.Id).orderBy(recordTypeName).bypassSharing()
			}, buildPathRefusalMessage(recordTypeName));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'selected ' + recordTypeName => newEventQuery(linkedEvent.Id).addField(recordTypeName).bypassSharing()
			}, buildLookupRefusalMessage(Schema.Name.RecordTypeId, recordTypeName));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'sort on ' + profileName => newEventQuery(linkedEvent.Id).orderBy(profileName).bypassSharing(),
					'selected ' + profileName => newEventQuery(linkedEvent.Id).addField(profileName).bypassSharing(),
					'TYPEOF that selects ' + profileName => newEventQuery(linkedEvent.Id).addField(TYPEOF_ACCOUNT_OWNER_PROFILE_NAME).bypassSharing()
			}, QueryException.class, buildObjectRefusalMessage(Profile.SObjectType));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'sort on ' + roleName => newEventQuery(linkedEvent.Id).orderBy(roleName).bypassSharing(),
					'selected ' + roleName => newEventQuery(linkedEvent.Id).addField(roleName).bypassSharing()
			}, QueryException.class, buildObjectRefusalMessage(UserRole.SObjectType));
			assertEveryQueryIsRefused(new Map<String, QRY_Builder.Builder>
			{
					'TYPEOF that selects ' + elseRecordTypeName + ' after ELSE' => newEventQuery(linkedEvent.Id).addField(TYPEOF_ELSE_RECORD_TYPE_NAME).bypassSharing()
			}, buildLookupRefusalMessage(Schema.Name.RecordTypeId, elseRecordTypeName));
			Map<String, QRY_Builder.Builder> userModeQueriesByCase = new Map<String, QRY_Builder.Builder>
			{
					'sort on ' + recordTypeName => newEventQuery(linkedEvent.Id).orderBy(recordTypeName).withUserMode(),
					'selected ' + recordTypeName => newEventQuery(linkedEvent.Id).addField(recordTypeName).withUserMode(),
					'sort on ' + profileName => newEventQuery(linkedEvent.Id).orderBy(profileName).withUserMode(),
					'selected ' + profileName => newEventQuery(linkedEvent.Id).addField(profileName).withUserMode(),
					'sort on ' + roleName => newEventQuery(linkedEvent.Id).orderBy(roleName).withUserMode(),
					'selected ' + roleName => newEventQuery(linkedEvent.Id).addField(roleName).withUserMode(),
					'TYPEOF that selects ' + profileName => newEventQuery(linkedEvent.Id).addField(TYPEOF_ACCOUNT_OWNER_PROFILE_NAME).withUserMode(),
					'TYPEOF that selects ' + elseRecordTypeName + ' after ELSE' => newEventQuery(linkedEvent.Id).addField(TYPEOF_ELSE_RECORD_TYPE_NAME).withUserMode()
			};
			for(String path : userFieldPaths)
			{
				userModeQueriesByCase.put('sort on ' + path, newEventQuery(linkedEvent.Id).orderBy(path).withUserMode());
			}
			List<SObjectField> hiddenFieldLookups = new List<SObjectField> {Event.OwnerId, Event.OwnerId, Event.WhatId, Event.WhatId};
			List<SObjectField> hiddenNameRecordFields = new List<SObjectField> {Schema.Name.ProfileId, Schema.Name.UserRoleId, Schema.Name.ProfileId, Schema.Name.RecordTypeId};
			for(Integer index = 0; index < hiddenFieldLookups.size(); index++)
			{
				String path = buildRelationshipPath(hiddenFieldLookups[index], UTIL_SObjectDescribe.getCachedFieldName(hiddenNameRecordFields[index]));
				List<SObject> rows = newEventQuery(linkedEvent.Id).addField(path).bypassSharing().toList();
				Assert.areEqual(1, rows.size(), 'Expected the read that selects ' + path + ' to return the Event');
				SObject relatedRecord = rows[0].getSObject(hiddenFieldLookups[index]);
				Assert.isTrue(relatedRecord == null || !relatedRecord.isSet(hiddenNameRecordFields[index]),
						'Expected ' + path + ', which the user cannot read, to be removed from the row. Actual related record: ' + relatedRecord);
				userModeQueriesByCase.put('selected ' + path, newEventQuery(linkedEvent.Id).addField(path).withUserMode());
			}
			assertUserModeRefusesEveryQuery(userModeQueriesByCase, eventControl);
		}
	}

	/**
	 * @description bypassSharing() alone reads the profile, the role and the record type of the shared Name record for a
	 * Standard User, for whom Salesforce marks those fields of the Name record as readable. The user owns an Event related
	 * to an account and to a contact. A sort on ProfileId, UserRoleId and RecordTypeId through What and Who, on ProfileId
	 * and UserRoleId through Owner, and on What.RecordType.Name, Owner.Profile.Name and Owner.UserRole.Name each reads the
	 * Event, with bypassSharing() and in user mode without it. The record type of the owner is read only as a selected
	 * field: a filter or a sort on it fails inside the database in every mode, with an error no code can catch.
	 *
	 * A read that selects Owner.ProfileId returns the Event with the profile of the owner, in both modes.
	 */
	@IsTest
	private static void bypassSharingAloneReadsTheUserFieldsOfTheNameRecordForAStandardUser()
	{
		User reader = insertActivityReader(SEL_Profile.PROFILE_STANDARD_USER);
		Event linkedEvent = insertEventWithAccountAndContact(reader);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		List<String> paths = buildNameRecordUserFieldPaths(false);
		paths.add(buildRelationshipPath(Event.WhatId, buildRelationshipPath(Schema.Name.RecordTypeId, UTIL_SObjectDescribe.getCachedFieldName(RecordType.Name))));
		paths.add(buildRelationshipPath(Event.OwnerId, buildRelationshipPath(User.ProfileId, UTIL_SObjectDescribe.getCachedFieldName(Profile.Name))));
		paths.add(buildRelationshipPath(Event.OwnerId, buildRelationshipPath(User.UserRoleId, UTIL_SObjectDescribe.getCachedFieldName(UserRole.Name))));
		String ownerRecordType = buildRelationshipPath(Event.OwnerId, UTIL_SObjectDescribe.getCachedFieldName(Schema.Name.RecordTypeId));
		String ownerProfile = buildRelationshipPath(Event.OwnerId, UTIL_SObjectDescribe.getCachedFieldName(Schema.Name.ProfileId));
		Assert.isNotNull(reader.ProfileId, 'Expected the saved user to carry its profile');

		System.runAs(reader)
		{
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected a Standard User to be able to read the WhatId lookup of an Event');
			for(SObjectField nameRecordField : new List<SObjectField> {Schema.Name.ProfileId, Schema.Name.UserRoleId, Schema.Name.RecordTypeId})
			{
				Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(nameRecordField),
						'Expected a Standard User to be able to read ' + UTIL_SObjectDescribe.getCachedFieldName(nameRecordField) + ' of the Name record');
			}
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				for(String path : paths)
				{
					List<SObject> rows = applyAccess(newEventQuery(linkedEvent.Id).orderBy(path), isSharingBypassed).toList();
					Assert.areEqual(1, rows.size(), 'Expected the sort on ' + path + ' to read the Event, sharing bypassed: ' + isSharingBypassed);
				}
				List<SObject> selectedRows = applyAccess(newEventQuery(linkedEvent.Id).addField(ownerRecordType), isSharingBypassed).toList();
				Assert.areEqual(1, selectedRows.size(), 'Expected the read that selects the record type of the owner to return the Event, sharing bypassed: '
						+ isSharingBypassed);
				List<SObject> profileRows = applyAccess(newEventQuery(linkedEvent.Id).addField(ownerProfile), isSharingBypassed).toList();
				Assert.areEqual(1, profileRows.size(), 'Expected the read that selects ' + ownerProfile + ' to return the Event, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(reader.ProfileId, profileRows[0].getSObject(Event.OwnerId)?.get(Schema.Name.ProfileId),
						'Expected the read that selects ' + ownerProfile + ' to return the profile of the owner, sharing bypassed: ' + isSharingBypassed);
			}
		}
	}

	/**
	 * @description bypassSharing() alone filters and sorts on the name of an Event invitee on an object the user cannot
	 * read. An Event invitee row points to its person through the Relation lookup, which can point to a contact, a lead
	 * or a user, so SOQL reads it through a shared Name record. The user may read contacts and the WhatId and WhoId
	 * lookups of an Event, but not leads, and owns an Event whose invitee is a lead the test administrator owns. A filter
	 * on Relation.Name and a sort on it each read the invitee row, with bypassSharing() and in user mode without it.
	 */
	@IsTest
	private static void bypassSharingAloneFiltersOnTheNameOfAnInviteeOnAnObjectTheUserCannotRead()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Contact.SObjectType},
						READ_PERMISSIONS,
						Contact.Phone
				);
		grantReadOnEventField(restricted, Event.WhatId);
		grantReadOnEventField(restricted, Event.WhoId);
		EventRelation invitee;
		System.runAs(getTestAdmin())
		{
			Lead prospect = insertLeadBypassingValidation(new Map<SObjectField, Object> {Lead.LastName => UTIL_Random.randomName()});
			Event linkedEvent = insertEventOwnedBy(restricted.Id, null, null);
			invitee = insertEventRelation(new Map<SObjectField, Object>
			{
					EventRelation.EventId => linkedEvent.Id,
					EventRelation.RelationId => prospect.Id
			});
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String inviteeName = buildRelationshipPath(EventRelation.RelationId, UTIL_SObjectDescribe.getCachedFieldName(Lead.Name));

		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(Lead.SObjectType), 'Expected the user to have no read on Lead');
			Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(EventRelation.RelationId), 'Expected the user to be able to read the Relation lookup of an invitee');
			for(Boolean isSharingBypassed : new List<Boolean> {true, false})
			{
				List<SObject> filterRows = applyAccess(newInviteeQuery(invitee.Id).andCondition(inviteeName).isNotNull(), isSharingBypassed).toList();
				List<SObject> sortRows = applyAccess(newInviteeQuery(invitee.Id).orderBy(inviteeName), isSharingBypassed).toList();
				Assert.areEqual(1, filterRows.size(), 'Expected the filter on the name of the invitee to read the row, sharing bypassed: ' + isSharingBypassed);
				Assert.areEqual(invitee.Id, filterRows[0].Id, 'Expected the row to be the invitee row of the lead');
				Assert.areEqual(1, sortRows.size(), 'Expected the sort on the name of the invitee to read the row, sharing bypassed: ' + isSharingBypassed);
			}
		}
	}

	/**
	 * @description bypassSharing() alone leaves a path through a relationship that Foobar__c does not have to SOQL. The
	 * builder looks for the relationship among every lookup of the object, finds none, and does not refuse the path:
	 * the query runs and SOQL refuses it with its own QueryException.
	 */
	@IsTest
	private static void bypassSharingAloneLeavesAPathThroughAnUnknownRelationshipToSoql()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String unknownPath = UNKNOWN_RELATIONSHIP + UTIL_String.DOT + FIELD_NAME;

		System.runAs(restricted)
		{
			try
			{
				List<SObject> rows = newRowQuery(row.Id).andCondition(unknownPath).equals(row.Name).bypassSharing().toList();
				Assert.fail('Expected SOQL to refuse a path through an unknown relationship; it returned ' + rows.size() + ' rows');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected SOQL to refuse the path. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
				Assert.areNotEqual(buildPathRefusalMessage(unknownPath), error.getMessage(), 'Expected the refusal to come from SOQL, not from the builder');
			}
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Switches off the KernDX validation rules on Account for the rest of the test, then saves one
	 * Account. An org can add its own KernDX rules, such as a required phone number. The switch covers only those
	 * rules. An org's own Salesforce validation rules, required fields, duplicate rules, Flows and triggers on Account
	 * still run, and can make the save fail.
	 *
	 * @param fieldValues The field values the Account needs, by field. An empty map saves an Account with the default
	 * values.
	 *
	 * @return The saved Account
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static Account insertAccountBypassingValidation(Map<SObjectField, Object> fieldValues)
	{
		UTIL_ValidationRule.bypassObject(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));
		return (Account)TST_Builder.of(Account.SObjectType).withOverrides(fieldValues).build();
	}

	/**
	 * @description Switches off the KernDX validation rules on Contact for the rest of the test, then saves one
	 * contact. The switch covers only the KernDX rules. An org's own Salesforce validation rules, required fields,
	 * duplicate rules, Flows and triggers on Contact still run, and can make the save fail.
	 *
	 * @param fieldValues The field values the contact needs, by field. An empty map saves a contact with the default
	 * values.
	 *
	 * @return The saved contact
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static Contact insertContactBypassingValidation(Map<SObjectField, Object> fieldValues)
	{
		UTIL_ValidationRule.bypassObject(UTIL_SObjectDescribe.getObjectNameFromType(Contact.SObjectType));
		return (Contact)TST_Builder.of(Contact.SObjectType).withOverrides(fieldValues).build();
	}

	/**
	 * @description Switches off the KernDX validation rules on Lead for the rest of the test, then saves one lead. The
	 * switch covers only the KernDX rules. An org's own Salesforce validation rules, required fields, duplicate rules,
	 * Flows and triggers on Lead still run, and can make the save fail.
	 *
	 * @param fieldValues The field values the lead needs, by field. An empty map saves a lead with the default values.
	 *
	 * @return The saved lead
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static Lead insertLeadBypassingValidation(Map<SObjectField, Object> fieldValues)
	{
		UTIL_ValidationRule.bypassObject(UTIL_SObjectDescribe.getObjectNameFromType(Lead.SObjectType));
		return (Lead)TST_Builder.of(Lead.SObjectType).withOverrides(fieldValues).build();
	}

	/**
	 * @description Switches off the KernDX validation rules on Event for the rest of the test, then saves one Event. The
	 * switch covers only the KernDX rules. An org's own Salesforce validation rules, required fields, Flows and triggers
	 * on Event still run, and can make the save fail.
	 *
	 * @param fieldValues The field values the Event needs, by field, such as its start time and its length.
	 *
	 * @return The saved Event
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static Event insertEventBypassingValidation(Map<SObjectField, Object> fieldValues)
	{
		UTIL_ValidationRule.bypassObject(UTIL_SObjectDescribe.getObjectNameFromType(Event.SObjectType));
		return (Event)TST_Builder.of(Event.SObjectType).withOverrides(fieldValues).build();
	}

	/**
	 * @description Saves one row of EventRelation, the object that holds the invitees of an Event. Salesforce allows no
	 * triggers or validation rules on this object, so no KernDX rule runs on the save and there is nothing to switch
	 * off. The save is kept here so the one standard-object write it makes sits in one place.
	 *
	 * @param fieldValues The field values the invitee row needs, by field: the Event and the person invited.
	 *
	 * @return The saved invitee row
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static EventRelation insertEventRelation(Map<SObjectField, Object> fieldValues)
	{
		return (EventRelation)TST_Builder.of(EventRelation.SObjectType).withOverrides(fieldValues).build();
	}

	/**
	 * @description Gives a user read access to the Related To field of an Event, the field that points to the record
	 * the Event is about.
	 *
	 * @param user The user who gets the access.
	 */
	private static void grantReadOnEventRelatedTo(User user)
	{
		grantReadOnEventField(user, Event.WhatId);
	}

	/**
	 * @description Gives a user read access to one field of an Event. Event access does not come from an object
	 * permission, so a permission set cannot list the Event object. It can still grant one of its fields. The method
	 * saves a permission set with that one field permission and assigns it to the user.
	 *
	 * @param user The user who gets the access.
	 * @param eventField The Event field the user may read, such as WhatId or WhoId.
	 */
	private static void grantReadOnEventField(User user, SObjectField eventField)
	{
		grantReadOnField(user, Event.SObjectType, eventField);
	}

	/**
	 * @description Gives a user read access to one field, and nothing else. The method saves a permission set with that
	 * one field permission and assigns it to the user. It gives no object permission.
	 *
	 * @param user The user who gets the access.
	 * @param objectType The object that holds the field.
	 * @param field The field the user may read.
	 */
	private static void grantReadOnField(User user, SObjectType objectType, SObjectField field)
	{
		String permissionSetName = FIELD_READ_PERMISSION_SET_PREFIX + UTIL_Random.randomAlphanumeric(PERMISSION_SET_NAME_RANDOM_LENGTH);
		SObjectType fieldPermissionsType = new FieldPermissions().getSObjectType();
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(objectType);
		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			PermissionSet permissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
					.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(PermissionSet.SObjectType).getCreatableRequiredFields()))
					.withOverride(PermissionSet.Name, permissionSetName)
					.withOverride(PermissionSet.Label, permissionSetName)
					.build();
			TST_Builder.of(fieldPermissionsType)
					.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(fieldPermissionsType).getCreatableRequiredFields()))
					.withOverrides(new Map<SObjectField, Object>
					{
							FieldPermissions.ParentId => permissionSet.Id,
							FieldPermissions.SobjectType => objectName,
							FieldPermissions.Field => objectName + '.' + UTIL_SObjectDescribe.getCachedFieldName(field),
							FieldPermissions.PermissionsRead => true
					})
					.build();
			TST_Factory.createPermissionSetAssignments(new List<User> {user}, permissionSet.Id);
		}
	}

	/**
	 * @description Saves a Standard User who may read Foobar__c records and every Foobar__c field except Email__c. The
	 * Standard User profile gives no access to Foobar__c, so the user has only what this method grants. The user has no
	 * View All, so record sharing hides the rows the test administrator owns.
	 *
	 * @return The saved user
	 */
	private static User insertRestrictedReader()
	{
		return insertReaderWithOneHiddenField(Foobar__c.Email__c);
	}

	/**
	 * @description Saves a Standard User who may read Foobar__c records and every Foobar__c field except one. The user
	 * has no View All, so record sharing hides the rows the test administrator owns.
	 *
	 * @param hiddenField The one Foobar__c field the user cannot read
	 *
	 * @return The saved user
	 */
	private static User insertReaderWithOneHiddenField(SObjectField hiddenField)
	{
		return TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_STANDARD_USER, new List<SObjectType> {Foobar__c.SObjectType}, READ_PERMISSIONS, hiddenField);
	}

	/**
	 * @description Runs each query with toList() and checks that the builder refuses it before any query runs, with
	 * the message that names a field the running user cannot read.
	 *
	 * @param queriesByCase The queries to run, by the name of the case each one tests
	 * @param expectedMessage The message each refusal must carry
	 */
	private static void assertEveryQueryIsRefused(Map<String, QRY_Builder.Builder> queriesByCase, String expectedMessage)
	{
		assertEveryQueryIsRefused(queriesByCase, UTIL_Exceptions.IllegalStateException.class, expectedMessage);
	}

	/**
	 * @description Runs each query with toList() and checks that the builder refuses it before any query runs, with
	 * the given kind of exception and message.
	 *
	 * @param queriesByCase The queries to run, by the name of the case each one tests
	 * @param exceptionType The kind of exception each refusal must be
	 * @param expectedMessage The message each refusal must carry
	 */
	private static void assertEveryQueryIsRefused(Map<String, QRY_Builder.Builder> queriesByCase, Type exceptionType, String expectedMessage)
	{
		for(String testCase : queriesByCase.keySet())
		{
			assertReadIsRefused(testCase, queriesByCase.get(testCase), TERMINAL_TO_LIST, exceptionType, expectedMessage);
		}
	}

	/**
	 * @description Runs one read terminal of a query and checks that the builder refuses it before any query runs, with
	 * the given kind of exception and message.
	 *
	 * @param testCase The name of the case, shown in the messages
	 * @param query The query to run
	 * @param terminal The name of the terminal method to call, one of the TERMINAL constants
	 * @param exceptionType The kind of exception the refusal must be
	 * @param expectedMessage The message the refusal must carry
	 */
	private static void assertReadIsRefused(String testCase, QRY_Builder.Builder query, String terminal, Type exceptionType, String expectedMessage)
	{
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		try
		{
			Object answer = runTerminal(query, terminal);
			Assert.fail('Expected the query to be refused for the ' + testCase + '; it returned ' + describeAnswer(answer));
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, exceptionType,
					'Expected the refusal for the ' + testCase + '. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
			Assert.areEqual(expectedMessage, error.getMessage(), 'Expected the message to name the field or the object, for the ' + testCase);
			Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected the refused read to run no query, for the ' + testCase);
		}
	}

	/**
	 * @description Builds each date function QRY_Function offers around one field, by its SOQL name.
	 *
	 * @param field The date or date and time field the functions read
	 *
	 * @return The thirteen date functions, by name
	 */
	private static Map<String, QRY_Function> newDateFunctions(SObjectField field)
	{
		return new Map<String, QRY_Function>
		{
				'CALENDAR_MONTH' => QRY_Function.calendarMonth(field),
				'CALENDAR_QUARTER' => QRY_Function.calendarQuarter(field),
				'CALENDAR_YEAR' => QRY_Function.calendarYear(field),
				'DAY_IN_MONTH' => QRY_Function.dayInMonth(field),
				'DAY_IN_WEEK' => QRY_Function.dayInWeek(field),
				'DAY_IN_YEAR' => QRY_Function.dayInYear(field),
				'DAY_ONLY' => QRY_Function.dayOnly(field),
				'FISCAL_MONTH' => QRY_Function.fiscalMonth(field),
				'FISCAL_QUARTER' => QRY_Function.fiscalQuarter(field),
				'FISCAL_YEAR' => QRY_Function.fiscalYear(field),
				'HOUR_IN_DAY' => QRY_Function.hourInDay(field),
				'WEEK_IN_MONTH' => QRY_Function.weekInMonth(field),
				'WEEK_IN_YEAR' => QRY_Function.weekInYear(field)
		};
	}

	/**
	 * @description Starts an Event query that selects the Id field and reads only the Event with the given Id.
	 *
	 * @param eventId The Id of the Event to read
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newEventQuery(Id eventId)
	{
		return QRY_Builder.selectFrom(Event.SObjectType).fields(new List<SObjectField> {Event.Id}).condition(Event.Id).equals(eventId);
	}

	/**
	 * @description Starts an account query that reads one account and its Events, through a child query that selects one
	 * path of each Event.
	 *
	 * @param accountId The Id of the account to read
	 * @param selectedPath The path the child query selects, such as What.Name
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newAccountEventsQuery(Id accountId, String selectedPath)
	{
		return newAccountQuery(accountId).subselect(QRY_Builder.selectFrom(Event.SObjectType).fields(new List<String> {selectedPath}), CHILD_EVENTS_RELATIONSHIP);
	}

	/**
	 * @description Starts an account query that reads one account and its Events, through a child query that selects
	 * only the Id, added under the given relationship name.
	 *
	 * @param accountId The Id of the account to read
	 * @param relationshipName The child relationship name, as written, such as Events
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newAccountChildEventsQuery(Id accountId, String relationshipName)
	{
		return newAccountQuery(accountId).subselect(QRY_Builder.selectFrom(Event.SObjectType).fields(new List<SObjectField> {Event.Id}), relationshipName);
	}

	/**
	 * @description Starts an account query that selects the Id field and reads only the account with the given Id.
	 *
	 * @param accountId The Id of the account to read
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newAccountQuery(Id accountId)
	{
		return QRY_Builder.selectFrom(Account.SObjectType).fields(new List<SObjectField> {Account.Id}).condition(Account.Id).equals(accountId);
	}

	/**
	 * @description Starts a query of one account, its contacts and their Events, each selecting only the Id.
	 *
	 * @param accountId The Id of the account to read
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newAccountContactEventsQuery(Id accountId)
	{
		QRY_Builder.Builder eventQuery = QRY_Builder.selectFrom(Event.SObjectType).fields(new List<SObjectField> {Event.Id});
		return newAccountQuery(accountId).subselect(newContactQuery().subselect(eventQuery, CHILD_EVENTS_RELATIONSHIP), CHILD_CONTACTS_RELATIONSHIP);
	}

	/**
	 * @description Starts a query of one contact and its Events, whose child query selects one path.
	 *
	 * @param contactId The Id of the contact to read
	 * @param selectedPath The path the child query selects, such as What.Name
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newContactEventsQuery(Id contactId, String selectedPath)
	{
		return newContactQuery().condition(Contact.Id).equals(contactId)
				.subselect(QRY_Builder.selectFrom(Event.SObjectType).fields(new List<String> {selectedPath}), CHILD_EVENTS_RELATIONSHIP);
	}

	/**
	 * @description Starts an Event invitee query that selects the Id field and reads only the invitee row with the given
	 * Id.
	 *
	 * @param inviteeId The Id of the invitee row to read
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newInviteeQuery(Id inviteeId)
	{
		return QRY_Builder.selectFrom(EventRelation.SObjectType)
				.fields(new List<SObjectField> {EventRelation.Id})
				.condition(EventRelation.Id).equals(inviteeId);
	}

	/**
	 * @description Checks, as the running user, what the tests of a Standard User rely on: the profile lets the user read
	 * the WhatId lookup of an Event, and gives no access to Foobar__c. In another org the test then fails here, with a
	 * clear message, and not later on the behaviour it tests.
	 */
	private static void assertStandardUserReadsTheLookupButNotFoobar()
	{
		Assert.isTrue(UTIL_SObjectDescribe.isFieldAccessible(Event.WhatId), 'Expected a Standard User to be able to read the WhatId lookup of an Event');
		Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(Foobar__c.SObjectType), 'Expected the user to have no read on Foobar__c');
	}

	/**
	 * @description Saves an Event that a given user owns, after it switches off the KernDX validation rules on Event.
	 * The caller runs it as the test administrator.
	 *
	 * @param ownerId The user who owns the Event
	 * @param whatId The record the Event is related to, or null
	 * @param whoId The contact or lead the Event is about, or null
	 *
	 * @return The saved Event
	 */
	private static Event insertEventOwnedBy(Id ownerId, Id whatId, Id whoId)
	{
		return insertEventBypassingValidation(new Map<SObjectField, Object>
		{
				Event.OwnerId => ownerId,
				Event.WhatId => whatId,
				Event.WhoId => whoId,
				Event.ActivityDateTime => Datetime.now(),
				Event.DurationInMinutes => EVENT_DURATION_MINUTES
		});
	}

	/**
	 * @description Saves, as the test administrator, an account and a contact of that account that a given user owns,
	 * and an Event the user owns that is related to the account and is about the contact.
	 *
	 * @param owner The user who owns the three records
	 *
	 * @return The saved Event
	 */
	private static Event insertEventWithAccountAndContact(User owner)
	{
		Event linkedEvent;
		System.runAs(getTestAdmin())
		{
			Account parentAccount = insertAccountBypassingValidation(new Map<SObjectField, Object> {Account.OwnerId => owner.Id});
			Contact person = insertContactBypassingValidation(new Map<SObjectField, Object>
			{
					Contact.OwnerId => owner.Id,
					Contact.AccountId => parentAccount.Id
			});
			linkedEvent = insertEventOwnedBy(owner.Id, parentAccount.Id, person.Id);
		}
		return linkedEvent;
	}

	/**
	 * @description Saves a user of the given profile who may read accounts and contacts, and every field of them except
	 * the Type of an account, and who may read the WhatId and WhoId lookups of an Event.
	 *
	 * @param profileName The profile of the user, such as Minimum Access or Standard User
	 *
	 * @return The saved user
	 */
	private static User insertActivityReader(String profileName)
	{
		User reader = TST_Factory.insertUserWithOneHiddenField(profileName, new List<SObjectType> {Account.SObjectType, Contact.SObjectType}, READ_PERMISSIONS,
				Account.Type);
		grantReadOnEventField(reader, Event.WhatId);
		grantReadOnEventField(reader, Event.WhoId);
		return reader;
	}

	/**
	 * @description Ends a query with the access a paired test compares: bypassSharing(), which ignores record sharing
	 * and keeps the user's object and field checks, or withUserMode() without bypassSharing(), which runs the query in
	 * user mode, so Salesforce applies the user's permissions and record sharing.
	 *
	 * @param query The query to end
	 * @param isSharingBypassed True for bypassSharing(); false for withUserMode()
	 *
	 * @return The same query, for chaining
	 */
	private static QRY_Builder.Builder applyAccess(QRY_Builder.Builder query, Boolean isSharingBypassed)
	{
		return isSharingBypassed ? query.bypassSharing() : query.withUserMode();
	}

	/**
	 * @description Runs each query with toList() and checks that Salesforce refuses it with a QueryException. The queries
	 * run in user mode, so the refusal comes from Salesforce and its message is not checked. First it runs a control
	 * query: the same read in user mode without the path under test, which must return a row. So a refusal cannot come
	 * from record sharing hiding the row or from a mistake in the rest of the query.
	 *
	 * @param queriesByCase The queries to run, by the name of the case each one tests
	 * @param controlQuery The same read in user mode without the path under test
	 */
	private static void assertUserModeRefusesEveryQuery(Map<String, QRY_Builder.Builder> queriesByCase, QRY_Builder.Builder controlQuery)
	{
		Assert.isFalse(controlQuery.toList().isEmpty(), 'Expected the user mode read without the path to return the row the user can see');
		for(String testCase : queriesByCase.keySet())
		{
			try
			{
				Object answer = runTerminal(queriesByCase.get(testCase), TERMINAL_TO_LIST);
				Assert.fail('Expected user mode to refuse the ' + testCase + '; it returned ' + describeAnswer(answer));
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class,
						'Expected Salesforce to refuse the ' + testCase + ' in user mode. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Builds a path through a lookup: the relationship name of the lookup, a dot, and the rest of the path.
	 *
	 * @param lookupField The lookup the path goes through, such as Event.WhatId
	 * @param restOfPath The field or path after the relationship, such as Name
	 *
	 * @return The path, such as What.Name
	 */
	private static String buildRelationshipPath(SObjectField lookupField, String restOfPath)
	{
		return UTIL_SObjectDescribe.getCachedFieldDescribe(lookupField).getRelationshipName() + UTIL_String.DOT + restOfPath;
	}

	/**
	 * @description Builds the paths to the profile, the role and the record type of the shared Name record through the
	 * What, Who and Owner lookups of an Event.
	 *
	 * @param isOwnerRecordTypeIncluded Whether to add the record type of the owner. A filter or a sort on it fails inside
	 * the database for a user who can read it, so only a user who cannot read it gets it.
	 *
	 * @return The paths, such as What.ProfileId
	 */
	private static List<String> buildNameRecordUserFieldPaths(Boolean isOwnerRecordTypeIncluded)
	{
		List<String> paths = new List<String>();
		for(SObjectField lookupField : new List<SObjectField> {Event.WhatId, Event.WhoId, Event.OwnerId})
		{
			paths.add(buildRelationshipPath(lookupField, UTIL_SObjectDescribe.getCachedFieldName(Schema.Name.ProfileId)));
			paths.add(buildRelationshipPath(lookupField, UTIL_SObjectDescribe.getCachedFieldName(Schema.Name.UserRoleId)));
			if(lookupField != Event.OwnerId || isOwnerRecordTypeIncluded)
			{
				paths.add(buildRelationshipPath(lookupField, UTIL_SObjectDescribe.getCachedFieldName(Schema.Name.RecordTypeId)));
			}
		}
		return paths;
	}

	/**
	 * @description Starts a contact query that selects the Id field.
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newContactQuery()
	{
		return QRY_Builder.selectFrom(Contact.SObjectType).fields(new List<SObjectField> {Contact.Id});
	}

	/**
	 * @description Starts a user query that selects the Id field and reads only the user with the given Id.
	 *
	 * @param userId The Id of the user to read
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newUserQuery(Id userId)
	{
		return QRY_Builder.selectFrom(User.SObjectType).fields(new List<SObjectField> {User.Id}).condition(User.Id).equals(userId);
	}

	/**
	 * @description Starts a LoginFrequency__c query that selects the Id field.
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newLoginFrequencyQuery()
	{
		return QRY_Builder.selectFrom(LoginFrequency__c.SObjectType).fields(new List<SObjectField> {LoginFrequency__c.Id});
	}

	/**
	 * @description Starts a query of one Foobar__c row and its Events, through a child query that selects only the Id,
	 * added under the given relationship name.
	 *
	 * @param rowId The Id of the row to read
	 * @param relationshipName The child relationship name, as written, such as Events
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newRowChildEventsQuery(Id rowId, String relationshipName)
	{
		return newRowQuery(rowId).subselect(QRY_Builder.selectFrom(Event.SObjectType).fields(new List<SObjectField> {Event.Id}), relationshipName);
	}

	/**
	 * @description Saves, as the test administrator, one Foobar__c row with a random name and a random email. The email
	 * is in lower case, because the platform saves part of an email in lower case and a test compares the saved value
	 * with the one it sent. Foobar__c records are private, so another user cannot see the row through record sharing.
	 *
	 * @param parentId The Id the Lookup__c field of the row points to, or null for a row with no parent
	 *
	 * @return The saved row
	 */
	private static Foobar__c insertRowOwnedByAdmin(Id parentId)
	{
		Foobar__c row;
		System.runAs(getTestAdmin())
		{
			row = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, UTIL_Random.randomName())
					.withOverride(Foobar__c.Email__c, UTIL_Random.randomEmail().toLowerCase())
					.withOverride(Foobar__c.Lookup__c, parentId)
					.build();
		}
		return row;
	}

	/**
	 * @description Starts a Foobar__c query that selects the Name field and reads only the row with the given Id.
	 *
	 * @param rowId The Id of the row to read
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newRowQuery(Id rowId)
	{
		return newFoobarNameQuery().condition(Foobar__c.Id).equals(rowId);
	}

	/**
	 * @description Starts a query of one Foobar__c row and its child rows, whose child query selects only the Id.
	 *
	 * @param rowId The Id of the row to read
	 * @param relationshipName The child relationship, as written
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newRowChildrenQuery(Id rowId, String relationshipName)
	{
		return newRowQuery(rowId).subselect(QRY_Builder.selectFrom(Foobar__c.SObjectType).fields(new List<SObjectField> {Foobar__c.Id}), relationshipName);
	}

	/**
	 * @description Starts a grouped Foobar__c query: one group for each name, with the count of rows in the group under
	 * ROW_COUNT_ALIAS. It reads only the rows with the given name.
	 *
	 * @param name The name of the rows to count
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newGroupedQuery(String name)
	{
		return QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.count(Foobar__c.Id, ROW_COUNT_ALIAS)
				.groupBy(Foobar__c.Name)
				.condition(Foobar__c.Name).equals(name);
	}

	/**
	 * @description Runs one read terminal of a query, chosen by its method name, and returns what it gave back.
	 *
	 * @param query The query to run
	 * @param terminal The name of the terminal method to call, one of the TERMINAL constants
	 *
	 * @return The rows, number, Boolean, query locator, cursor, page or totals the terminal returned
	 */
	private static Object runTerminal(QRY_Builder.Builder query, String terminal)
	{
		if(terminal == TERMINAL_COUNT)
		{
			return query.count();
		}
		if(terminal == TERMINAL_EXISTS)
		{
			return query.exists();
		}
		if(terminal == TERMINAL_TO_QUERY_LOCATOR)
		{
			return query.toQueryLocator();
		}
		if(terminal == TERMINAL_TO_CURSOR)
		{
			return query.toCursor();
		}
		if(terminal == TERMINAL_TO_AGGREGATE_LIST)
		{
			return query.toAggregateList();
		}
		if(terminal == TERMINAL_GET_FIRST_AGGREGATE)
		{
			return query.getFirstAggregate();
		}
		if(terminal == TERMINAL_GET_PAGE)
		{
			return query.getPage(1, BYPASS_PAGE_SIZE);
		}
		if(terminal == TERMINAL_GET_RANDOM_ITEMS)
		{
			return query.getRandomItems(1);
		}
		return query.toList();
	}

	/**
	 * @description Describes what a read terminal returned, for the message of a test that expected the read to be
	 * refused. A list is described by its size.
	 *
	 * @param answer What the terminal returned
	 *
	 * @return A short description of the answer
	 */
	private static String describeAnswer(Object answer)
	{
		if(answer instanceof List<SObject>)
		{
			return ((List<SObject>)answer).size() + ' rows';
		}
		if(answer instanceof List<QRY_Builder.AggregateRow>)
		{
			return ((List<QRY_Builder.AggregateRow>)answer).size() + ' groups';
		}
		return String.valueOf(answer);
	}

	/**
	 * @description Builds the message the builder gives when it refuses a read that cannot remove hidden fields and runs
	 * with bypassSharing() alone.
	 *
	 * @param terminal The name of the terminal method the message must name
	 *
	 * @return The expected message
	 */
	private static String buildBypassRefusalMessage(String terminal)
	{
		return String.format(System.Label.QueryBuilder_BypassSharingRead_NeedsSystemMode, new List<Object> {terminal});
	}

	/**
	 * @description Builds the message the builder gives when bypassSharing() alone would filter or sort on a field the
	 * running user cannot read.
	 *
	 * @param field The field the message must name
	 *
	 * @return The expected message
	 */
	private static String buildFieldRefusalMessage(SObjectField field)
	{
		return buildPathRefusalMessage(UTIL_SObjectDescribe.getCachedFieldName(field));
	}

	/**
	 * @description Builds the message the builder gives when bypassSharing() alone would filter or sort through a path
	 * the running user cannot read.
	 *
	 * @param fieldPath The path the message must name, as the query writes it
	 *
	 * @return The expected message
	 */
	private static String buildPathRefusalMessage(String fieldPath)
	{
		return String.format(System.Label.QueryBuilder_BypassSharingField_NotReadable, new List<Object> {fieldPath});
	}

	/**
	 * @description Builds the message the builder gives when bypassSharing() alone would read an object, or pass
	 * through a parent object, that the running user cannot read.
	 *
	 * @param objectType The object the message must name
	 *
	 * @return The expected message
	 */
	private static String buildObjectRefusalMessage(SObjectType objectType)
	{
		return String.format(System.Label.QueryBuilder_BypassSharingObject_NotReadable, new List<Object> {UTIL_SObjectDescribe.getObjectNameFromType(objectType)});
	}

	/**
	 * @description Builds the message the builder gives when bypassSharing() alone would select a path through a lookup
	 * the running user cannot read. The message names the lookup with its object, such as Event.WhatId.
	 *
	 * @param lookupField The lookup the message must name
	 * @param selectedPath The selected path the message must name, as the query writes it
	 *
	 * @return The expected message
	 */
	private static String buildLookupRefusalMessage(SObjectField lookupField, String selectedPath)
	{
		DescribeFieldResult lookupDescribe = UTIL_SObjectDescribe.getCachedFieldDescribe(lookupField);
		String lookupName = UTIL_SObjectDescribe.getObjectNameFromType(lookupDescribe.getSObjectType()) + UTIL_String.DOT + lookupDescribe.getName();
		return String.format(System.Label.QueryBuilder_BypassSharingLookup_NotReadable, new List<Object> {lookupName, selectedPath});
	}

	/**
	 * @description Builds the message the builder gives when bypassSharing() alone cannot check a selected text, such as
	 * a child query written as text.
	 *
	 * @param selectedText The selected text the message must name, as the query writes it
	 *
	 * @return The expected message
	 */
	private static String buildSelectedTextRefusalMessage(String selectedText)
	{
		return String.format(System.Label.QueryBuilder_BypassSharingSelectedText_NotCheckable, new List<Object> {selectedText});
	}

	/**
	 * @description Builds the path from a Foobar__c row to the email of its parent, through the Lookup__c relationship,
	 * from the field tokens, so the path carries the package namespace where there is one.
	 *
	 * @return The path, such as Lookup__r.Email__c
	 */
	private static String buildParentEmailPath()
	{
		return UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Lookup__c).getRelationshipName() + '.' + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c);
	}

	/**
	 * @description Builds a group of two conditions joined by OR: the email of the row, or its name.
	 *
	 * @param row The row whose email and name the conditions match
	 *
	 * @return The group of conditions
	 */
	private static QRY_Condition.OrCondition newEmailOrNameGroup(Foobar__c row)
	{
		QRY_Condition.OrCondition emailOrName = new QRY_Condition.OrCondition();
		emailOrName.add(new QRY_Condition.FieldCondition(Foobar__c.Email__c, QRY_Condition.Operator.EQUALS, row.Email__c));
		emailOrName.add(new QRY_Condition.FieldCondition(Foobar__c.Name, QRY_Condition.Operator.EQUALS, row.Name));
		return emailOrName;
	}

	/**
	 * @description Builds a NOT condition around a filter on the row's email, so the filter keeps every row whose email
	 * is not the row's own.
	 *
	 * @param row The row whose email the filter uses.
	 *
	 * @return The NOT condition.
	 */
	private static QRY_Condition.NotCondition newNotEmailCondition(Foobar__c row)
	{
		return new QRY_Condition.NotCondition(new QRY_Condition.FieldCondition(Foobar__c.Email__c, QRY_Condition.Operator.EQUALS, row.Email__c));
	}

	/**
	 * @description Starts a Foobar__c query that selects only the Name field.
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newFoobarNameQuery()
	{
		return QRY_Builder.selectFrom(Foobar__c.SObjectType).fields(new List<SObjectField> {Foobar__c.Name});
	}

	/**
	 * @description Drains a cursor in the current transaction and counts the rows it yields.
	 *
	 * @param probeCursor The cursor to drain.
	 *
	 * @return The fetched row count.
	 */
	private static Integer countCursorRows(Database.Cursor probeCursor)
	{
		Integer total = probeCursor.getNumRecords();
		return total == 0 ? 0 : probeCursor.fetch(0, total).size();
	}

	/**
	 * @description A condition written the way your own code can write one: it gives the query its filter as plain text.
	 * The builder cannot see which fields the text uses.
	 */
	private inherited sharing class TextFilter implements QRY_Condition.Evaluable
	{
		/**
		 * @description The filter, as it is written into the WHERE clause.
		 */
		private final String filterText;

		/**
		 * @description Keeps the filter text.
		 *
		 * @param filterText The filter, as it is written into the WHERE clause
		 */
		public TextFilter(String filterText)
		{
			this.filterText = filterText;
		}

		/**
		 * @description Returns the filter text unchanged.
		 *
		 * @return The filter text
		 */
		public String toSoql()
		{
			return filterText;
		}

		/**
		 * @description Returns the filter text unchanged. The text is already written in full, so the options change
		 * nothing.
		 *
		 * @param options The options for writing the query text
		 *
		 * @return The filter text
		 */
		public String toSoql(QRY_Condition.SoqlOptions options)
		{
			return filterText;
		}
	}
}
