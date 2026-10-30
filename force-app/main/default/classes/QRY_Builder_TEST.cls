// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for QRY_Builder adapter class.
 * Verifies the QRY_Builder API correctly delegates to the underlying UTIL_Query infrastructure.
 *
 * @see QRY_Builder
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.CognitiveComplexity')
private class QRY_Builder_TEST
{
	/**
	 * @description Company name given to the admin user created in the test setup. It is unique to this class, so
	 * getTestAdmin can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'QRY_Builder_TEST-admin';
	/**
	 * @description Name stamped on the Foobar__c rows seeded for the tests that read through the query cache, so
	 * a cached read can be limited to those rows by name.
	 */
	private static final String CACHE_PROBE_NAME = 'Cache probe';
	/**
	 * @description Number of Foobar__c rows each owner gets in the cached-read tests. A read that may see the rows
	 * must return this many; a read that may not must return fewer.
	 */
	private static final Integer CACHE_PROBE_ROWS = 3;
	/**
	 * @description How long, in seconds, the cached-read tests ask the query cache to keep a result: five minutes,
	 * far longer than a test runs, so a stored result cannot expire between two reads in one test. Whether the
	 * second read may be served that result is what each test checks.
	 */
	private static final Integer CACHE_PROBE_TTL_SECONDS = 300;
	/**
	 * @description A longer time-to-live, an hour, for the tests that ask for durable Platform Cache storage.
	 */
	private static final Integer DURABLE_PROBE_TTL_SECONDS = 3600;
	/**
	 * @description Name stamped on the Foobar__c rows seeded for the cursor sharing probe.
	 */
	private static final String CURSOR_PROBE_NAME = 'Cursor probe';
	/**
	 * @description Number of admin-owned Foobar__c rows the cursor sharing probe seeds.
	 */
	private static final Integer CURSOR_PROBE_ROWS = 3;
	/**
	 * @description API name of the Foobar__c date field. The tests use it to check the query text the builder
	 * produces when a date function is used for grouping or ordering.
	 */
	private static final String FIELD_DATE = SEL_Foobar.FIELD_DATE;
	/**
	 * @description API name of the Foobar__c email field. The tests use it to check that the field appears in,
	 * or is left out of, the query text the builder produces.
	 */
	private static final String FIELD_EMAIL = SEL_Foobar.FIELD_EMAIL;
	/**
	 * @description The name of the record Id field, for the tests that pass a field to the builder as text, for
	 * example to count rows or to filter on the result of an inner query.
	 */
	private static final String FIELD_ID = 'Id';
	/**
	 * @description API name of the Foobar__c lookup field. The tests use it where a field holding a record Id is
	 * needed, such as building a map of rows keyed by that Id.
	 */
	private static final String FIELD_LOOKUP = SEL_Foobar.FIELD_LOOKUP;
	/**
	 * @description API name of the Foobar__c name field. The tests use it to select and filter by name and to
	 * check that the name appears in the query text the builder produces.
	 */
	private static final String FIELD_NAME = SEL_Foobar.FIELD_NAME;
	/**
	 * @description API name of the Foobar__c decimal number field. The tests use it to check the ordering part of
	 * the query text the builder produces.
	 */
	private static final String FIELD_NUMBER_DECIMAL = SEL_Foobar.FIELD_DECIMAL;
	/**
	 * @description API name of the Foobar__c whole number field. The tests use it to check the greater than and
	 * less than comparisons in the query text the builder produces.
	 */
	private static final String FIELD_NUMBER_INTEGER = SEL_Foobar.FIELD_INTEGER;
	/**
	 * @description API name of the Foobar__c picklist field. The tests use it where a field with a small set of
	 * values is needed, such as matching against a list of values or counting distinct values.
	 */
	private static final String FIELD_PICKLIST = SEL_Foobar.FIELD_PICKLIST;
	/**
	 * @description API name of the Foobar__c text field. The tests use it to check the text comparisons (equals,
	 * starts with, ends with, in a list) in the query text the builder produces.
	 */
	private static final String FIELD_TEXT = SEL_Foobar.FIELD_TEXT;
	/**
	 * @description API name of the Foobar__c text area field. The tests use it to check the not equals and the
	 * is empty comparisons in the query text the builder produces.
	 */
	private static final String FIELD_TEXTAREA = SEL_Foobar.FIELD_TEXT_AREA;
	/**
	 * @description Number of rows the probe batch receives in one chunk. It is larger than the number of rows
	 * seeded, so the batch sees every row in a single chunk.
	 */
	private static final Integer LOCATOR_PROBE_BATCH_SIZE = 200;
	/**
	 * @description Name stamped on the Foobar__c rows seeded for the tests that read through a query locator.
	 */
	private static final String LOCATOR_PROBE_NAME = 'Locator probe';
	/**
	 * @description Number of Foobar__c rows the query locator tests seed. A locator that may see the rows must
	 * deliver exactly this many.
	 */
	private static final Integer LOCATOR_PROBE_ROWS = 3;
	/**
	 * @description API name of the Foobar__c object, used to check that the query text the builder produces reads
	 * from the right object.
	 */
	private static final String OBJECT_NAME = SEL_Foobar.OBJECT_NAME;
	/**
	 * @description Page size for the cached paging test. It is smaller than PAGING_PROBE_ROWS, so the rows spread
	 * over more than one page and a page size can never be mistaken for the total.
	 */
	private static final Integer PAGING_PROBE_PAGE_SIZE = 2;
	/**
	 * @description Number of rows the cached paging test seeds. Every page must report this as the total number of
	 * records, however many rows the page itself holds.
	 */
	private static final Integer PAGING_PROBE_ROWS = 5;
	/**
	 * @description The permission set that gives a Standard User read access to Foobar__c, so a user-mode read by
	 * that user runs instead of failing on object access.
	 */
	private static final String READ_ONLY_PERMISSION_SET = 'ReadOnly';
	/**
	 * @description Company name of the restricted user the user-mode sharing test creates, so the test can tell that
	 * user apart from the test admin.
	 */
	private static final String RESTRICTED_USER_COMPANY = 'QRY_Builder_TEST-restricted';
	/**
	 * @description Name stamped on the Foobar__c rows seeded for the row-query sharing probe.
	 */
	private static final String ROW_SHARING_PROBE_NAME = 'Row sharing probe';
	/**
	 * @description Number of admin-owned Foobar__c rows the row-query sharing probe seeds.
	 */
	private static final Integer ROW_SHARING_PROBE_ROWS = 3;
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
	 * @description Name stamped on the Foobar__c rows seeded for the test that checks withoutSecurity.
	 */
	private static final String WAIVER_PROBE_NAME = 'Waiver probe';
	/**
	 * @description Page size the withoutSecurity test asks for. It is larger than WAIVER_PROBE_ROWS, so one page
	 * can hold every seeded row.
	 */
	private static final Integer WAIVER_PROBE_PAGE_SIZE = 10;
	/**
	 * @description Number of Foobar__c rows the withoutSecurity test seeds as the admin. A user who does not own
	 * them must still get this many back from every way of running the query.
	 */
	private static final Integer WAIVER_PROBE_ROWS = 3;
	/**
	 * @description Alias the aggregate mock tests give the count, and the key of the registered rows that holds it.
	 */
	private static final String MOCK_TOTAL_ALIAS = 'total';
	/**
	 * @description Total held by the registered aggregate rows. It differs from every real count in these tests, so
	 * an answer from the registered rows is told apart from an answer from the database.
	 */
	private static final Integer MOCK_TOTAL = 4;
	/**
	 * @description Total held by the rows that a second setAggregateMock call sets. It differs from MOCK_TOTAL, so the
	 * rows of the first call are told apart from the rows of the second.
	 */
	private static final Integer REPLACEMENT_MOCK_TOTAL = 9;
	/**
	 * @description Name of the read the error must point to when a mocked aggregate query is read as records.
	 */
	private static final String AGGREGATE_READ_HINT = 'toAggregateList';
	/**
	 * @description Name of the method the error must point to when an aggregate query finds record mocks only.
	 */
	private static final String REGISTER_AGGREGATE_ROWS_HINT = 'registerAggregateRows';
	/**
	 * @description The record reads that must refuse a mocked aggregate query. Each name is a method of
	 * QRY_Builder.Builder; readMockedAggregateQueryAsRecords runs the one it is given.
	 */
	private static final List<String> RECORD_READS = new List<String> {'toList', 'getFirst', 'getPage', 'getRandomItems', 'asMap'};
	/**
	 * @description Page size the record-read test asks getPage for.
	 */
	private static final Integer MOCK_PAGE_SIZE = 10;
	/**
	 * @description Alias registered in mixed case, to prove an alias is matched without regard to case.
	 */
	private static final String MIXED_CASE_ALIAS = 'Count_Id';
	/**
	 * @description Alias read back in a test that never registered it.
	 */
	private static final String MISSPELT_ALIAS = 'totl';
	/**
	 * @description A value written over a registered row after it was read, to prove the row read earlier kept its own copy.
	 */
	private static final Integer CHANGED_TOTAL = 9;
	/**
	 * @description Key of the registered row that holds a whole number written as an Integer.
	 */
	private static final String INTEGER_KEY = 'a';
	/**
	 * @description Key of the registered row that holds a whole number written as a Decimal.
	 */
	private static final String DECIMAL_KEY = 'b';
	/**
	 * @description Key of the registered row that holds a whole number written as a Long.
	 */
	private static final String LONG_KEY = 'c';
	/**
	 * @description Value held under INTEGER_KEY.
	 */
	private static final Integer INTEGER_VALUE = 3;
	/**
	 * @description Value held under DECIMAL_KEY.
	 */
	private static final Decimal DECIMAL_VALUE = 2.0;
	/**
	 * @description Value held under LONG_KEY.
	 */
	private static final Long LONG_VALUE = 5L;
	/**
	 * @description Key of the registered row that holds a whole number written as a Double.
	 */
	private static final String DOUBLE_KEY = 'd';
	/**
	 * @description Value held under DOUBLE_KEY. It is declared as a Double, so the row really holds a Double.
	 */
	private static final Double DOUBLE_VALUE = 6.0;
	/**
	 * @description Key of the registered row that holds a number with a fraction.
	 */
	private static final String FRACTION_KEY = 'e';
	/**
	 * @description Value held under FRACTION_KEY. It is not a whole number, so getInteger must refuse it as a real
	 * row does.
	 */
	private static final Decimal FRACTION_VALUE = 2.5;
	/**
	 * @description A TYPEOF field written as plain text. TYPEOF picks which parent fields to read by the type of
	 * parent the Event points to: Phone and Industry for an Account, Amount for an Opportunity, and Name for any
	 * other type.
	 */
	private static final String TYPEOF_CLAUSE = 'TYPEOF What WHEN Account THEN Phone, Industry WHEN Opportunity THEN Amount ELSE Name END';
	/**
	 * @description Phone number given to the Account that an Event points to, so a test can find it again on the
	 * parent the query brings back.
	 */
	private static final String PARENT_PHONE = '555-0100';
	/**
	 * @description The industry given to each Account a test saves. Some orgs that install the package have their own
	 * rule that an Account needs an industry, so a saved Account carries one.
	 */
	private static final String ACCOUNT_INDUSTRY = 'Technology';
	/**
	 * @description Length in minutes given to each Event the TYPEOF tests build. An Event that is not an all-day
	 * event needs a length and a start time.
	 */
	private static final Integer EVENT_DURATION_MINUTES = 30;
	/**
	 * @description Name of the Custom Label that holds the message for a text the builder refuses where it expects a field
	 * name. The message names the method that refused the text.
	 */
	private static final String FIELD_NAME_REFUSED_LABEL = 'QueryBuilder_FieldName_NotAllowed';
	/**
	 * @description A data category group name the data category tests use where the group name is valid.
	 */
	private static final String CATEGORY_GROUP = 'Geography__c';
	/**
	 * @description A data category name the data category tests use where the category name is valid.
	 */
	private static final String CATEGORY_NAME = 'USA__c';
	/**
	 * @description Name of the relationship from an Account to its Contacts, used to read the Contacts of each Account in
	 * one query.
	 */
	private static final String CONTACTS_RELATIONSHIP = 'Contacts';
	/**
	 * @description Alias given to the sum that the aggregate selection tests build.
	 */
	private static final String SUM_ALIAS = 'total';
	/**
	 * @description Number of Foobar__c rows the tests about crafted field names save. One more row is saved and then
	 * deleted where a test needs a deleted row.
	 */
	private static final Integer CRAFTED_TEXT_PROBE_ROWS = 3;
	/**
	 * @description A latitude that Apex writes with an exponent, 1E-7, when it turns the number into text.
	 */
	private static final Decimal LATITUDE_IN_EXPONENT_FORM = 0.0000001;
	/**
	 * @description A latitude that Apex writes with its trailing zeros, 45.000000000000, when it turns the number into text.
	 */
	private static final Decimal LATITUDE_WITH_TRAILING_ZEROS = 45.000000000000;
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
	 * @description The length of a very long crafted text. Without a length limit, a pattern that reads a text this long
	 * stops the transaction with an error no code can catch.
	 */
	private static final Integer VERY_LONG_TEXT_LENGTH = 300000;
	/**
	 * @description The number of sort items in a long crafted sort list. Without a check of one item at a time, a pattern
	 * that reads a list this long fails with a stack overflow.
	 */
	private static final Integer MANY_SORT_ITEMS = 300;
	/**
	 * @description The number of dotted names in a long crafted field path. Without a length limit, a pattern that reads a
	 * path this long fails with a stack overflow.
	 */
	private static final Integer MANY_DOTTED_NAMES = 1000;
	/**
	 * @description The most fields an ORDER BY clause takes.
	 */
	private static final Integer MOST_SORT_ITEMS = 32;
	/**
	 * @description A field path that reaches five parent records, the most a query may reach: from a Foobar__c record to
	 * the user who created it, that user's profile, and so on.
	 */
	private static final String FIVE_PARENT_PATH = 'CreatedBy.Profile.CreatedBy.Profile.CreatedBy.Name';
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
	 * @description The start of the name of the permission set that gives a test user read access to the Related To
	 * field of an Event. A random ending keeps each name unique.
	 */
	private static final String EVENT_RELATED_TO_PERMISSION_SET_PREFIX = 'EventRelatedToRead';
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
	 * @description The most rows the paged read of the sharing bypass tests asks for. One page holds the one seeded row.
	 */
	private static final Integer BYPASS_PAGE_SIZE = 10;
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
	 * @description The builder method that receives each crafted text, so a test can say which method had to refuse it.
	 */
	private static final Map<CraftedEntry, String> ENTRY_METHOD_NAMES = new Map<CraftedEntry, String>
	{
			CraftedEntry.CONDITION => 'condition',
			CraftedEntry.CONDITION_WITHOUT_OPERATOR => 'condition',
			CraftedEntry.AND_CONDITION => 'andCondition',
			CraftedEntry.OR_CONDITION => 'orCondition',
			CraftedEntry.ORDER_BY => 'orderBy',
			CraftedEntry.ORDER_BY_DESCENDING => 'orderBy',
			CraftedEntry.ORDER_BY_DESCENDING_NULLS_FIRST => 'orderBy',
			CraftedEntry.GROUP_BY => 'groupBy',
			CraftedEntry.COUNT => 'count',
			CraftedEntry.COUNT_DISTINCT => 'countDistinct',
			CraftedEntry.GROUPING => 'grouping',
			CraftedEntry.DATA_CATEGORY_GROUP => 'withDataCategory',
			CraftedEntry.DATA_CATEGORY_BUILDER => 'DataCategoryBuilder',
			CraftedEntry.AT => 'at',
			CraftedEntry.AT_LIST => 'at',
			CraftedEntry.ABOVE => 'above',
			CraftedEntry.ABOVE_LIST => 'above',
			CraftedEntry.BELOW => 'below',
			CraftedEntry.BELOW_LIST => 'below',
			CraftedEntry.EITHER_SIDE => 'aboveOrBelow',
			CraftedEntry.EITHER_SIDE_LIST => 'aboveOrBelow',
			CraftedEntry.RELATED_FIELD => 'relatedField',
			CraftedEntry.RELATED_FIELDS => 'relatedFields',
			CraftedEntry.SUBSELECT => 'subselect',
			CraftedEntry.IS_IN => 'SetCondition',
			CraftedEntry.NOT_IN => 'SetCondition'
	};
	/**
	 * @description The builder methods whose query cannot run on this org, because it has no objects that take data
	 * categories. For these the tests read the query text only.
	 */
	private static final Set<CraftedEntry> TEXT_ONLY_ENTRIES = new Set<CraftedEntry>
	{
			CraftedEntry.DATA_CATEGORY_GROUP,
			CraftedEntry.DATA_CATEGORY_BUILDER,
			CraftedEntry.AT,
			CraftedEntry.AT_LIST,
			CraftedEntry.ABOVE,
			CraftedEntry.ABOVE_LIST,
			CraftedEntry.BELOW,
			CraftedEntry.BELOW_LIST,
			CraftedEntry.EITHER_SIDE,
			CraftedEntry.EITHER_SIDE_LIST
	};

	/**
	 * @description Rows the cross-transaction queueable fetch saw through its cursor; static so the in-test
	 * synchronous queueable run can report back to the asserting method.
	 */
	private static Integer cursorRowsSeenInQueueable = -1;

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
	 * @description Tests that count() honours the sharing bypass it advertises, and not merely the sharing
	 * context it happens to be called from. A count is the natural way to size a query before deciding
	 * whether to issue it, and a bypassed count that silently enforced sharing would report FEWER rows than
	 * the bypassed query it is sizing — the dangerous direction, because the caller then proceeds believing
	 * the query is smaller than it is. Foobar__c is Private OWD, so rows owned by the test admin are
	 * genuinely invisible to another user; system mode is applied to both counts so CRUD/FLS is waived and
	 * record sharing is the only variable left.
	 */
	@IsTest
	private static void countHonoursTheSharingBypassItAdvertises()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Sharing probe')
					.withCount(3)
					.buildList();
		}

		Integer enforcedCount;
		Integer bypassedCount;

		Test.startTest();
		System.runAs(restricted)
		{
			enforcedCount = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().count();
			bypassedCount = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().bypassSharing().count();
		}
		Test.stopTest();

		Assert.areEqual(0, enforcedCount,
				'With sharing enforced the other user sees none of the admin-owned private rows — system mode waives CRUD and FLS, never record sharing');
		Assert.areEqual(3, bypassedCount,
				'A bypassed count must reach every row, exactly as a bypassed row query does; 0 here would mean count() drops the sharing dial and undersizes what it measures');
	}

	/**
	 * @description Tests that withSystemMode() alone does not span record sharing on the row-query path, the
	 * path subscribers reach through toList(), getFirst() and SEL_Base.findById. System mode waives object and
	 * field permissions only; record sharing is a separate dial, so a system-mode read of another user's rows
	 * returns nothing rather than failing loudly, which is the quiet failure and the reason this needs its own test.
	 * Foobar__c is Private OWD, so rows owned by the test admin are genuinely invisible to another user. The
	 * bypassed read is the positive control: it proves the empty result is record sharing rather than a seed
	 * that never landed. The class declares no sharing keyword, which is the common subscriber shape, so the
	 * unbroken inherited sharing chain resolves to with sharing and enforcement is observed by default.
	 */
	@IsTest
	private static void systemModeAloneDoesNotSpanSharingOnRowQuery()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, ROW_SHARING_PROBE_NAME)
					.withCount(ROW_SHARING_PROBE_ROWS)
					.buildList();
		}

		List<SObject> enforcedRows;
		List<SObject> bypassedRows;

		Test.startTest();
		System.runAs(restricted)
		{
			enforcedRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toList();
			bypassedRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().bypassSharing().toList();
		}
		Test.stopTest();

		Assert.areEqual(0, enforcedRows.size(),
				'System mode alone waives CRUD and FLS but never record sharing, so the other user reads none of the admin-owned private rows');
		Assert.areEqual(ROW_SHARING_PROBE_ROWS, bypassedRows.size(),
				'The bypassed read is the positive control: it must return every seeded row, proving the empty result above is sharing and not a missing seed');
	}

	/**
	 * @description Tests that toQueryLocator() honours the sharing bypass it advertises when the locator is
	 * iterated in the same transaction. Foobar__c is Private OWD, so rows owned by the test admin are genuinely
	 * invisible to another user; system mode is applied to both locators so object and field permissions are
	 * waived and record sharing is the only variable left. The explicit withSharing() dial is set too, so
	 * the with-sharing arm can never be routed through the without-sharing proxy unnoticed.
	 */
	@IsTest
	private static void queryLocatorHonoursTheSharingBypassItAdvertises()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, LOCATOR_PROBE_NAME)
					.withCount(LOCATOR_PROBE_ROWS)
					.buildList();
		}

		Integer enforcedRows;
		Integer bypassedRows;
		Integer withSharingRows;

		Test.startTest();
		System.runAs(restricted)
		{
			enforcedRows = countLocatorRows(QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toQueryLocator());
			bypassedRows = countLocatorRows(QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().bypassSharing().toQueryLocator());
			withSharingRows = countLocatorRows(QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().withSharing().toQueryLocator());
		}
		Test.stopTest();

		Assert.areEqual(0, enforcedRows, 'With sharing enforced the other user iterates none of the admin-owned private rows');
		Assert.areEqual(LOCATOR_PROBE_ROWS, bypassedRows,
				'A bypassed locator must reach every row, exactly as a bypassed row query does; 0 here means toQueryLocator() drops the sharing dial');
		Assert.areEqual(0, withSharingRows,
				'With sharing explicitly enforced the other user iterates none of the admin-owned private rows; more than 0 means the '
				+ 'withSharing() arm of toQueryLocator() is not dispatching through WithSharingExecutor');
	}

	/**
	 * @description Tests that a bypassed locator still spans sharing when a real batch job retrieves its rows.
	 * The batch class is declared with sharing and runs as the restricted user, so the only thing that can let
	 * it see the admin-owned rows is the sharing dial the locator was built with.
	 */
	@IsTest
	private static void queryLocatorBypassSurvivesBatchRetrieval()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, LOCATOR_PROBE_NAME)
					.withCount(LOCATOR_PROBE_ROWS)
					.buildList();
		}

		QRY_LocatorProbeBatch_TEST.rowsSeen = 0;
		System.runAs(restricted)
		{
			Test.startTest();
			Database.executeBatch(new QRY_LocatorProbeBatch_TEST(true), LOCATOR_PROBE_BATCH_SIZE);
			Test.stopTest();
		}

		Assert.areEqual(LOCATOR_PROBE_ROWS, QRY_LocatorProbeBatch_TEST.rowsSeen,
				'A with-sharing batch run by the restricted user must still receive every row through a bypassed locator');
	}

	/**
	 * @description The inverse of queryLocatorBypassSurvivesBatchRetrieval, proving the batch measurement can
	 * fail: without the bypass the same batch sees nothing.
	 */
	@IsTest
	private static void queryLocatorWithoutBypassSeesNothingInBatch()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, LOCATOR_PROBE_NAME)
					.withCount(LOCATOR_PROBE_ROWS)
					.buildList();
		}

		QRY_LocatorProbeBatch_TEST.rowsSeen = 0;
		System.runAs(restricted)
		{
			Test.startTest();
			Database.executeBatch(new QRY_LocatorProbeBatch_TEST(false), LOCATOR_PROBE_BATCH_SIZE);
			Test.stopTest();
		}

		Assert.areEqual(0, QRY_LocatorProbeBatch_TEST.rowsSeen,
				'Without the bypass a with-sharing batch run by the restricted user sees none of the admin-owned private rows');
	}

	/**
	 * @description The positive control for the batch measurement: the owner runs the batch with no bypass and
	 * the counter must see every row, proving the instrument observes batch-delivered rows before the bypass
	 * tests are read as evidence of anything.
	 */
	@IsTest
	private static void queryLocatorBatchCounterObservesOwnerRows()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, LOCATOR_PROBE_NAME)
					.withCount(LOCATOR_PROBE_ROWS)
					.buildList();

			QRY_LocatorProbeBatch_TEST.rowsSeen = 0;
			Test.startTest();
			Database.executeBatch(new QRY_LocatorProbeBatch_TEST(false), LOCATOR_PROBE_BATCH_SIZE);
			Test.stopTest();
		}

		Assert.areEqual(LOCATOR_PROBE_ROWS, QRY_LocatorProbeBatch_TEST.rowsSeen,
				'The owner must see every seeded row through the batch; 0 here means the counter is not observing batch execution and the bypass measurements cannot be trusted');
	}

	/**
	 * @description Tests that toCursor() honours the sharing dial it advertises when the cursor is drained in
	 * the same transaction. Foobar__c is Private OWD, so rows owned by the test admin are genuinely invisible
	 * to another user; system mode is applied to every cursor so object and field permissions are waived and
	 * record sharing is the only variable left. The explicit withSharing() dial is set too, so the
	 * with-sharing arm can never be routed through the without-sharing proxy unnoticed.
	 */
	@IsTest
	private static void cursorHonoursTheSharingBypassItAdvertises()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CURSOR_PROBE_NAME)
					.withCount(CURSOR_PROBE_ROWS)
					.buildList();
		}

		Integer enforcedRows;
		Integer bypassedRows;
		Integer withSharingRows;

		Test.startTest();
		System.runAs(restricted)
		{
			enforcedRows = countCursorRows(QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toCursor());
			bypassedRows = countCursorRows(QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().bypassSharing().toCursor());
			withSharingRows = countCursorRows(QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().withSharing().toCursor());
		}
		Test.stopTest();

		Assert.areEqual(0, enforcedRows, 'With sharing enforced the other user fetches none of the admin-owned private rows');
		Assert.areEqual(CURSOR_PROBE_ROWS, bypassedRows,
				'A bypassed cursor must reach every row, exactly as a bypassed row query does; 0 here means toCursor() drops the sharing dial');
		Assert.areEqual(0, withSharingRows,
				'With sharing explicitly enforced the other user fetches none of the admin-owned private rows; more than 0 means the '
				+ 'withSharing() arm of toCursor() is not dispatching through WithSharingExecutor');
	}

	/**
	 * @description Tests that a bypassed cursor still spans sharing when a later transaction drains it. The
	 * queueable is declared with sharing and runs as the restricted user, so the only thing that can let it
	 * fetch the admin-owned rows is the sharing dial the cursor was created under.
	 */
	@IsTest
	private static void cursorBypassSurvivesCrossTransactionFetch()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CURSOR_PROBE_NAME)
					.withCount(CURSOR_PROBE_ROWS)
					.buildList();
		}

		cursorRowsSeenInQueueable = -1;
		System.runAs(restricted)
		{
			Database.Cursor probeCursor = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().bypassSharing().toCursor();
			Test.startTest();
			System.enqueueJob(new CursorProbeFetchJob(probeCursor));
			Test.stopTest();
		}

		Assert.areEqual(CURSOR_PROBE_ROWS, cursorRowsSeenInQueueable,
				'A with-sharing queueable run by the restricted user must still fetch every row through a bypassed cursor');
	}

	/**
	 * @description The inverse of cursorBypassSurvivesCrossTransactionFetch, proving the queueable measurement
	 * can fail: without the bypass the same queueable fetches nothing.
	 */
	@IsTest
	private static void cursorWithoutBypassSeesNothingInQueueable()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CURSOR_PROBE_NAME)
					.withCount(CURSOR_PROBE_ROWS)
					.buildList();
		}

		cursorRowsSeenInQueueable = -1;
		System.runAs(restricted)
		{
			Database.Cursor probeCursor = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toCursor();
			Test.startTest();
			System.enqueueJob(new CursorProbeFetchJob(probeCursor));
			Test.stopTest();
		}

		Assert.areEqual(0, cursorRowsSeenInQueueable,
				'Without the bypass a with-sharing queueable run by the restricted user fetches none of the admin-owned private rows');
	}

	/**
	 * @description The positive control for the queueable measurement: the owner drains their own cursor with
	 * no bypass and the counter must see every row, proving the instrument observes queueable-fetched rows
	 * before the bypass tests are read as evidence of anything.
	 */
	@IsTest
	private static void cursorQueueableFetchPositiveControlOwnerSeesRows()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CURSOR_PROBE_NAME)
					.withCount(CURSOR_PROBE_ROWS)
					.buildList();

			cursorRowsSeenInQueueable = -1;
			Database.Cursor probeCursor = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toCursor();
			Test.startTest();
			System.enqueueJob(new CursorProbeFetchJob(probeCursor));
			Test.stopTest();

			Assert.areEqual(CURSOR_PROBE_ROWS, cursorRowsSeenInQueueable,
					'The owner must see every row through the queueable fetch, or the instrument observes nothing and the bypass tests prove nothing');
		}
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
	 * @description Tests that the query builder constructs a basic SOQL query with SELECT, FROM, and WHERE clauses.
	 */
	@IsTest
	private static void buildsBasicQueryWithSelectFromAndWhere()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.Name})
					.condition(Foobar__c.Name).equals('Test Foobar')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('FROM ' + OBJECT_NAME), 'Should contain FROM clause');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME + ' = \'Test Foobar\''), 'Should contain WHERE clause');
		}
	}

	/**
	 * @description Tests that onlyFields replaces a previously seeded field selection instead of
	 * appending to it, so a query can project narrower than a selector's defaults.
	 */
	@IsTest
	private static void replacesSeededFieldSelectionWithOnlyFields()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.Text__c, Foobar__c.Email__c})
					.onlyFields(new List<SObjectField> {Foobar__c.Name})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME), 'Should contain the replacement field');
			Assert.isFalse(soql.containsIgnoreCase(FIELD_TEXT), 'Seeded Text__c must be replaced, not kept');
			Assert.isFalse(soql.containsIgnoreCase(FIELD_EMAIL), 'Seeded Email__c must be replaced, not kept');
		}
	}

	/**
	 * @description Tests that the query builder handles complex conditions with AND and OR logic.
	 */
	@IsTest
	private static void buildsComplexConditionsWithAndOrLogic()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Text__c).equals('TestValue')
					.andCondition(Foobar__c.TextArea__c).notEquals('Other')
					.orCondition(Foobar__c.Email__c).isNotNull()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT + ' = \'TestValue\''), 'Should have equals');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXTAREA + ' != \'Other\''), 'Should have not equals');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_EMAIL + ' != NULL'), 'Should have email not null condition');
			Assert.isTrue(soql.containsIgnoreCase(' OR '), 'Should have OR operator');
		}
	}

	/**
	 * @description Tests that the query builder adds ORDER BY and LIMIT clauses correctly.
	 */
	@IsTest
	private static void buildsQueryWithOrderByAndLimit()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.NumberDecimal__c).descending()
					.withLimit(10)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NUMBER_DECIMAL + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('LIMIT 10'), 'Should limit');
		}
	}

	/**
	 * @description Tests that the condition builder supports all comparison operators.
	 */
	@IsTest
	private static void conditionBuilderSupportsAllOperators()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			query.condition(Foobar__c.Name).contains('Test')
					.andCondition(Foobar__c.Picklist__c).isIn(new Set<Object> {'Option1', 'Option2'})
					.andCondition(Foobar__c.Text__c).isIn(new List<Object> {'Value1'})
					.andCondition(Foobar__c.NumberInteger__c).greaterThan(100)
					.andCondition(Foobar__c.NumberInteger__c).lessThan(1000)
					.andCondition(Foobar__c.NumberInteger__c).greaterThanOrEquals(101)
					.andCondition(Foobar__c.NumberInteger__c).lessThanOrEquals(999)
					.andCondition(Foobar__c.TextArea__c).isNull()
					.andCondition(Foobar__c.Email__c).isNotNull()
					.andCondition(Foobar__c.Text__c).startsWith('Start')
					.andCondition(Foobar__c.Text__c).endsWith('End')
					.andCondition(Foobar__c.Lookup__c).notInSet(new Set<Object> {UserInfo.getUserId()});

			String soql = query.toSoql();
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME + ' LIKE \'%Test%\''), 'Contains mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_PICKLIST + ' IN (\'Option1\',\'Option2\')'), 'IN set mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT + ' IN (\'Value1\')'), 'IN list mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NUMBER_INTEGER + ' > 100'), 'Greater than mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NUMBER_INTEGER + ' < 1000'), 'Less than mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NUMBER_INTEGER + ' >= 101'), 'Greater equals mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NUMBER_INTEGER + ' <= 999'), 'Less equals mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXTAREA + ' = NULL'), 'Is null mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_EMAIL + ' != NULL'), 'Is not null mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT + ' LIKE \'Start%\''), 'Starts with mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT + ' LIKE \'%End\''), 'Ends with mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_LOOKUP + ' NOT IN'), 'Not in mismatch');
		}
	}

	/**
	 * @description Tests that toList() executes the query and returns results.
	 */
	@IsTest
	private static void toListExecutesQuery()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.toList();

			Assert.areEqual(1, results.size(), 'Should return inserted record');
		}
	}

	/**
	 * @description Tests that getFirst() returns a single record.
	 */
	@IsTest
	private static void getFirstReturnsSingleRecord()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			SObject result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.getFirst();

			Assert.isNotNull(result, 'Should return record');
			Assert.areEqual(record.Id, result.Id, 'Should return correct record');
		}
	}

	/**
	 * @description Tests that getFirst() returns null when no records match.
	 */
	@IsTest
	private static void getFirstReturnsNullWhenNoMatch()
	{
		System.runAs(getTestAdmin())
		{
			SObject result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals('NonExistent_' + System.currentTimeMillis())
					.getFirst();

			Assert.isNull(result, 'Should return null when no match');
		}
	}

	/**
	 * @description Tests that count() returns the correct record count.
	 */
	@IsTest
	private static void countReturnsRecordCount()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(3);

			Integer count = QRY_Builder.selectFrom(Foobar__c.SObjectType).count();

			Assert.isTrue(count >= 3, 'Should count at least inserted records');
		}
	}

	/**
	 * @description Tests that exists() returns true when records exist.
	 */
	@IsTest
	private static void existsReturnsTrueWhenRecordsExist()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Boolean exists = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.exists();

			Assert.isTrue(exists, 'Should return true when record exists');
		}
	}

	/**
	 * @description Tests that exists() returns false when no records exist.
	 */
	@IsTest
	private static void existsReturnsFalseWhenNoRecords()
	{
		System.runAs(getTestAdmin())
		{
			Boolean exists = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals('NonExistent_' + System.currentTimeMillis())
					.exists();

			Assert.isFalse(exists, 'Should return false when no match');
		}
	}

	/**
	 * @description Tests that asMap() returns results as Map<Id, SObject>.
	 */
	@IsTest
	private static void asMapReturnsIdMap()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Map<Id, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.asMap();

			Assert.isTrue(resultMap.containsKey(record.Id), 'Map should contain record Id');
		}
	}

	/**
	 * @description Tests that asIdSet() returns a Set of record Ids.
	 */
	@IsTest
	private static void asIdSetReturnsIdSet()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<Id> idSet = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.asIdSet();

			Assert.isTrue(idSet.contains(record.Id), 'Set should contain record Id');
		}
	}

	/**
	 * @description Tests that asIdList() returns a List of record Ids.
	 */
	@IsTest
	private static void asIdListReturnsIdList()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<Id> idList = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.asIdList();

			Assert.isTrue(idList.contains(record.Id), 'List should contain record Id');
		}
	}

	/**
	 * @description Tests that asMapById(SObjectField) returns a Map keyed by the specified Id field.
	 */
	@IsTest
	private static void asMapByIdReturnsMapKeyedByField()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			Test.startTest();
			Map<Id, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Id).equals(child.Id)
					.asMapById(Foobar__c.Lookup__c);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one entry keyed by parent Id');
			Assert.isTrue(resultMap.containsKey(parent.Id), 'Map should contain parent Id as key');
			Assert.areEqual(child.Id, resultMap.get(parent.Id).Id, 'Value should be the child record');
		}
	}

	/**
	 * @description Tests that asMapById(String) returns a Map keyed by the specified Id field name.
	 */
	@IsTest
	private static void asMapByIdStringReturnsMapKeyedByFieldName()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			Test.startTest();
			Map<Id, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Id).equals(child.Id)
					.asMapById(FIELD_LOOKUP);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one entry keyed by parent Id');
			Assert.isTrue(resultMap.containsKey(parent.Id), 'Map should contain parent Id as key from string overload');
		}
	}

	/**
	 * @description Tests that asMapById returns an empty map when the query yields no results.
	 */
	@IsTest
	private static void asMapByIdReturnsEmptyMapWhenNoResults()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.asMapById(Foobar__c.Lookup__c);
			Test.stopTest();

			Assert.isTrue(resultMap.isEmpty(), 'Map should be empty when no results match');
		}
	}

	/**
	 * @description Tests that asMapByString(SObjectField) returns a Map keyed by the specified String field.
	 * Uses Name field because Foobar__c.Text__c is overwritten by TRG_SetFoobarDefaults during inserts in test context.
	 */
	@IsTest
	private static void asMapByStringReturnsMapKeyedByField()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Name, 'UniqueName-AAA')
					.build();

			Test.startTest();
			Map<String, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Id).equals(record.Id)
					.asMapByString(Foobar__c.Name);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one entry');
			Assert.isTrue(resultMap.containsKey('UniqueName-AAA'), 'Map should contain string key with preserved casing');
			Assert.areEqual(record.Id, resultMap.get('UniqueName-AAA').Id, 'Value should be the inserted record');
		}
	}

	/**
	 * @description Tests that asMapByString(String) returns a Map keyed by the specified field name.
	 */
	@IsTest
	private static void asMapByStringStringReturnsMapKeyedByFieldName()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Name, 'UniqueName-BBB')
					.build();

			Test.startTest();
			Map<String, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Id).equals(record.Id)
					.asMapByString(FIELD_NAME);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one entry from string overload');
			Assert.isTrue(resultMap.containsKey('UniqueName-BBB'), 'Map should contain string key from string overload');
		}
	}

	/**
	 * @description Tests that asMapByString returns an empty map when the query yields no results.
	 */
	@IsTest
	private static void asMapByStringReturnsEmptyMapWhenNoResults()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<String, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.asMapByString(Foobar__c.Name);
			Test.stopTest();

			Assert.isTrue(resultMap.isEmpty(), 'Map should be empty when no results match');
		}
	}

	/**
	 * @description Tests that asGroupedMapById(SObjectField) groups records by an Id field, preserving duplicates.
	 */
	@IsTest
	private static void asGroupedMapByIdReturnsGroupedMap()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c childOne = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();
			Foobar__c childTwo = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			Test.startTest();
			Map<Id, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Id).isIn(new List<Object> {childOne.Id, childTwo.Id})
					.asGroupedMapById(Foobar__c.Lookup__c);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one group for parent Id');
			Assert.areEqual(2, resultMap.get(parent.Id).size(), 'Group should contain both child records');
		}
	}

	/**
	 * @description Tests that asGroupedMapById(String) groups records by an Id field name.
	 */
	@IsTest
	private static void asGroupedMapByIdStringReturnsGroupedMap()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c childOne = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();
			Foobar__c childTwo = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			Test.startTest();
			Map<Id, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Id).isIn(new List<Object> {childOne.Id, childTwo.Id})
					.asGroupedMapById(FIELD_LOOKUP);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one group from string overload');
			Assert.areEqual(2, resultMap.get(parent.Id).size(), 'Group should contain both child records');
		}
	}

	/**
	 * @description Tests that asGroupedMapById returns an empty map when the query yields no results.
	 */
	@IsTest
	private static void asGroupedMapByIdReturnsEmptyMapWhenNoResults()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.asGroupedMapById(Foobar__c.Lookup__c);
			Test.stopTest();

			Assert.isTrue(resultMap.isEmpty(), 'Map should be empty when no results match');
		}
	}

	/**
	 * @description Tests that asGroupedMapByString(SObjectField) groups records by a String field, preserving duplicates.
	 * Uses Name field because Foobar__c.Text__c is overwritten by TRG_SetFoobarDefaults during inserts in test context.
	 */
	@IsTest
	private static void asGroupedMapByStringReturnsGroupedMap()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyA').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyA').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyB').build();

			Test.startTest();
			Map<String, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Name).isIn(new List<Object> {'GroupKeyA', 'GroupKeyB'})
					.asGroupedMapByString(Foobar__c.Name);
			Test.stopTest();

			Assert.areEqual(2, resultMap.size(), 'Map should contain two groups');
			Assert.areEqual(2, resultMap.get('GroupKeyA').size(), 'GroupKeyA should contain two records');
			Assert.areEqual(1, resultMap.get('GroupKeyB').size(), 'GroupKeyB should contain one record');
		}
	}

	/**
	 * @description Tests that asGroupedMapByString(String) groups records by a String field name.
	 */
	@IsTest
	private static void asGroupedMapByStringStringReturnsGroupedMap()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyC').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyC').build();

			Test.startTest();
			Map<String, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Name).equals('GroupKeyC')
					.asGroupedMapByString(FIELD_NAME);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one group from string overload');
			Assert.areEqual(2, resultMap.get('GroupKeyC').size(), 'GroupKeyC should contain two records');
		}
	}

	/**
	 * @description Tests that asGroupedMapByString returns an empty map when the query yields no results.
	 */
	@IsTest
	private static void asGroupedMapByStringReturnsEmptyMapWhenNoResults()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<String, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.asGroupedMapByString(Foobar__c.Name);
			Test.stopTest();

			Assert.isTrue(resultMap.isEmpty(), 'Map should be empty when no results match');
		}
	}

	/**
	 * @description Tests that getPage() returns paginated results.
	 */
	@IsTest
	private static void getPageReturnsPaginatedResults()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);

			QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(1, 2);

			Assert.areEqual(2, result.records.size(), 'Should return 2 records per page');
			Assert.isTrue(result.totalRecords >= 5, 'Should have at least 5 total records');
			Assert.areEqual(1, result.pageNumber, 'Should be page 1');
			Assert.areEqual(2, result.pageSize, 'Page size should be 2');
			Assert.isTrue(result.hasMorePages, 'Should have more pages');
			Assert.isFalse(result.hasPriorPages, 'First page should not have prior pages');
			Assert.isNotNull(result.cursor, 'PaginationCursor should be populated');
			Assert.isNotNull(result.deletedRecords, 'deletedRecords should be populated');
		}
	}

	/**
	 * @description Tests that Page.totalPages is calculated correctly.
	 */
	@IsTest
	private static void pageContainsTotalPages()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(10);

			QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(1, 3);

			Assert.isTrue(result.totalPages >= 4, 'Should calculate total pages (10/3 = 4)');
		}
	}

	/**
	 * @description Tests that getPage() still serves a correct page when the matching set is larger than the
	 * platform's pagination-cursor ceiling. Opening a pagination cursor over such a set throws a governor
	 * exception at cursor creation, which Apex cannot catch, so the read has to be diverted to a standard
	 * cursor BEFORE the cursor is opened. The ceiling is lowered rather than the data grown so that the real
	 * bounded count and the real standard cursor both run, on the real getPage() path.
	 */
	@IsTest
	private static void getPageServesOversizedResultSetsFromAStandardCursor()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);
			QRY_Engine.paginationCursorRowLimitOverride = 3;

			QRY_Builder.QueryPage firstPage = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(1, 2);

			QRY_Builder.QueryPage lastPage = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(3, 2);

			Assert.areEqual(2, firstPage.records.size(), 'First page should hold a full page of records');
			Assert.areEqual(5, firstPage.totalRecords, 'Total should be the true match count, not the guard bound');
			Assert.areEqual(3, firstPage.totalPages, 'Five records at two per page is three pages');
			Assert.isTrue(firstPage.hasMorePages, 'Page one of three has more pages');
			Assert.isFalse(firstPage.hasPriorPages, 'Page one has no prior pages');
			Assert.isNull(firstPage.cursor, 'No pagination cursor exists once the read is diverted');
			Assert.areEqual(0, firstPage.deletedRecords, 'A standard cursor cannot report deleted records');

			Assert.areEqual(1, lastPage.records.size(), 'Last page should hold the one remaining record');
			Assert.areEqual(5, lastPage.totalRecords, 'Every page should report the same true total');
			Assert.isFalse(lastPage.hasMorePages, 'Page three of three has no more pages');
			Assert.isTrue(lastPage.hasPriorPages, 'Page three has prior pages');
			Assert.isNull(lastPage.cursor, 'No pagination cursor exists once the read is diverted');
		}
	}

	/**
	 * @description Tests that a matching set sitting exactly ON the ceiling still gets a pagination cursor.
	 * The platform rejects the cursor only ABOVE the ceiling, so a guard that diverted at equality would
	 * cost every caller its cursor and its deleted-record count one row too early.
	 */
	@IsTest
	private static void getPageKeepsItsCursorWhenTheMatchCountEqualsTheCeiling()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(3);
			QRY_Engine.paginationCursorRowLimitOverride = 3;

			QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(1, 2);

			Assert.areEqual(2, page.records.size(), 'Should hold a full page of records');
			Assert.areEqual(3, page.totalRecords, 'Should report the true total');
			Assert.isNotNull(page.cursor, 'A set exactly at the ceiling is still cursor-eligible');
		}
	}

	/**
	 * @description Tests that the guard counts the population the page query actually matches, not the whole
	 * object. Five rows exist and the ceiling is three, so a guard that dropped the WHERE clause would divert
	 * this read even though only two rows match — the page would silently lose its cursor.
	 */
	@IsTest
	private static void getPageGuardCountsOnlyTheRowsTheQueryMatches()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.NumberInteger__c, 20)
					.withCount(3)
					.buildList();
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.NumberInteger__c, 10)
					.withCount(2)
					.buildList();
			QRY_Engine.paginationCursorRowLimitOverride = 3;

			QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.NumberInteger__c).equals(10)
					.getPage(1, 5);

			Assert.areEqual(2, page.records.size(), 'Should return only the rows the condition matches');
			Assert.areEqual(2, page.totalRecords, 'Total should count only the rows the condition matches');
			Assert.isNotNull(page.cursor, 'A guard ignoring the WHERE clause would see five rows and divert this read');
		}
	}

	/**
	 * @description Tests that the guard respects a visibility scope. Five rows exist and the ceiling is
	 * three, but only two belong to the running user, so a guard that dropped USING SCOPE would count the
	 * other three and divert a read that the platform would have served from a pagination cursor.
	 */
	@IsTest
	private static void getPageGuardCountsOnlyTheRowsInScope()
	{
		User otherOwner = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);

		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.OwnerId, otherOwner.Id)
					.withCount(3)
					.buildList();
			TST_Builder.of(Foobar__c.SObjectType)
					.withCount(2)
					.buildList();
			QRY_Engine.paginationCursorRowLimitOverride = 3;

			QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.usingScope(QRY_Builder.Scope.MINE)
					.getPage(1, 5);

			Assert.areEqual(2, page.records.size(), 'Should return only the rows the running user owns');
			Assert.areEqual(2, page.totalRecords, 'Total should count only the rows in scope');
			Assert.isNotNull(page.cursor, 'A guard ignoring the scope would see four rows and divert this read');
		}
	}

	/**
	 * @description Tests that the guard counts deleted rows whenever the page asks for them. This is the one
	 * direction that matters: a guard blind to ALL ROWS would undercount, wave the read through, and let the
	 * platform kill the transaction on a set it cannot open a pagination cursor over. Two live rows and three
	 * deleted ones sit either side of a ceiling of three, so the same object answers both ways.
	 */
	@IsTest
	private static void getPageGuardCountsDeletedRowsWhenThePageAsksForThem()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = TST_Factory.insertFoobars(5);
			delete new List<Foobar__c> {foobars[0], foobars[1], foobars[2]};
			QRY_Engine.paginationCursorRowLimitOverride = 3;

			// The ALL ROWS read runs first: it is diverted, so it claims no pagination rows and leaves the
			// live-only read the same headroom it would have had on its own.
			QRY_Builder.QueryPage withDeleted = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.allRows()
					.getPage(1, 5);

			QRY_Builder.QueryPage liveOnly = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getPage(1, 5);

			Assert.areEqual(2, liveOnly.totalRecords, 'Two rows survive the delete');
			Assert.isNotNull(liveOnly.cursor, 'Two rows sit under the ceiling, so this page keeps its cursor');

			Assert.areEqual(5, withDeleted.totalRecords, 'ALL ROWS should see the deleted rows too');
			Assert.isNull(withDeleted.cursor, 'Counting the deleted rows takes this page over the ceiling');
		}
	}

	/**
	 * @description Tests that the row allowance is spent per TRANSACTION, not per read. Every pagination
	 * cursor claims its whole result set out of one shared allowance, so a second paged read in the same
	 * transaction has only what the first one left. Sizing each read against the full ceiling would let the
	 * second one open a cursor the platform then refuses, which is the failure this guard exists to prevent.
	 */
	@IsTest
	private static void getPageDivertsOnceTheTransactionHasSpentItsCursorRows()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);
			QRY_Engine.paginationCursorRowLimitOverride = 5;

			QRY_Builder.QueryPage firstRead = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getPage(1, 2);

			QRY_Builder.QueryPage secondRead = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getPage(1, 2);

			Assert.areEqual(5, firstRead.totalRecords, 'The first read should see every row');
			Assert.isNotNull(firstRead.cursor, 'The first read fits the whole allowance');

			Assert.areEqual(5, secondRead.totalRecords, 'The diverted read should still report the true total');
			Assert.areEqual(2, secondRead.records.size(), 'The diverted read should still return a full page');
			Assert.isNull(secondRead.cursor, 'The first cursor claimed the allowance, leaving the second read none');
		}
	}

	/**
	 * @description Tests the last tier: a plain LIMIT/OFFSET query, used when the transaction can open
	 * neither kind of cursor. It needs no cursor at all, so it still answers where both pools are spent, and
	 * the page it returns has to be indistinguishable from a cursor's apart from the missing cursor itself.
	 */
	@IsTest
	private static void getPageFallsBackToAPlainQueryWhenNoCursorCanBeOpened()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);
			QRY_Engine.paginationCursorRowLimitOverride = 3;
			QRY_Engine.standardCursorLimitOverride = 0;

			QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(2, 2);

			Assert.areEqual(2, page.records.size(), 'The plain query should return a full page');
			Assert.areEqual(5, page.totalRecords, 'The separate count should report the true total');
			Assert.areEqual(3, page.totalPages, 'Five records at two per page is three pages');
			Assert.isTrue(page.hasMorePages, 'Page two of three has more pages');
			Assert.isTrue(page.hasPriorPages, 'Page two has prior pages');
			Assert.isNull(page.cursor, 'No cursor was opened, so none can be handed back');
			Assert.areEqual(0, page.deletedRecords, 'A plain query cannot report deleted records');
		}
	}

	/**
	 * @description Tests that a builder-level LIMIT keeps a query on its pagination cursor even when the
	 * unlimited matching set would exceed the row allowance — the bounded guard count stops at the LIMIT, so
	 * a query that can never claim more rows than it is allowed is never diverted, and the page's total is
	 * the LIMIT, not the matching set.
	 */
	@IsTest
	private static void getPageKeepsTheCursorWhenABuilderLimitStaysUnderTheAllowance()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);
			QRY_Engine.paginationCursorRowLimitOverride = 3;

			QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withLimit(2)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(1, 2);

			Assert.isNotNull(page.cursor, 'A LIMIT under the allowance should keep the pagination cursor');
			Assert.areEqual(2, page.totalRecords, 'The total is the LIMIT, not the five matching rows');
			Assert.areEqual(2, page.records.size(), 'The page holds the limited rows');
		}
	}

	/**
	 * @description Tests that a builder-level LIMIT withholds the plain tier: a cursor applies the LIMIT
	 * across the whole result set and a per-page LIMIT cannot reproduce that, so with both cursor pools
	 * spent the page is refused with the typed capacity error rather than answered differently.
	 */
	@IsTest
	private static void getPageWithholdsThePlainTierForABuilderLimit()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);
			QRY_Engine.paginationCursorRowLimitOverride = 0;
			QRY_Engine.standardCursorLimitOverride = 0;

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withLimit(4).getPage(1, 2);
				Assert.fail('With both cursor pools spent, a LIMITed page has no tier left and should be refused');
			}
			catch(UTIL_Exceptions.IllegalStateException expected)
			{
				Assert.isTrue(expected.getMessage().contains('no cursor capacity left'), 'The error should say the capacity is spent, got: ' + expected.getMessage());
			}
		}
	}

	/**
	 * @description Tests that an aggregate page never reaches the plain tier: a LIMIT/OFFSET aggregate is
	 * legal SOQL, but its total would count base rows rather than groups — a served-but-wrong page — so with
	 * both cursor pools spent the aggregate page is refused with the typed capacity error instead.
	 */
	@IsTest
	private static void getPageWithholdsThePlainTierForAnAggregatePage()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);
			QRY_Engine.paginationCursorRowLimitOverride = 0;
			QRY_Engine.standardCursorLimitOverride = 0;

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).groupBy(Foobar__c.Text__c).getPage(1, 2);
				Assert.fail('An aggregate page with no cursor available should be refused, never served with a base-row total');
			}
			catch(UTIL_Exceptions.IllegalStateException expected)
			{
				Assert.isTrue(expected.getMessage().contains('no cursor capacity left'), 'The error should say the capacity is spent, got: ' + expected.getMessage());
			}
		}
	}

	/**
	 * @description Tests that a page too deep for the plain tier is refused with a clear, catchable error
	 * rather than a governor exception the caller cannot intercept. SOQL OFFSET stops at 2,000 rows, so once
	 * both cursor pools are spent there is genuinely nothing left that can reach page 1,002.
	 */
	@IsTest
	private static void getPageFailsClearlyWhenThePageIsBeyondEveryTier()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);
			QRY_Engine.paginationCursorRowLimitOverride = 3;
			QRY_Engine.standardCursorLimitOverride = 0;

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).getPage(1002, 2);
				Assert.fail('A page past the OFFSET cap with no cursor available should be refused');
			}
			catch(UTIL_Exceptions.IllegalStateException expected)
			{
				Assert.isTrue(expected.getMessage().contains('no cursor capacity left'), 'The error should say the capacity is spent, got: ' + expected.getMessage());
			}
		}
	}

	/**
	 * @description Tests that getPage() rejects a page larger than any cursor will fetch. Catching it at the
	 * API boundary names the cap; letting it through produces a platform error partway into the read that
	 * says nothing about which argument was wrong.
	 */
	@IsTest
	private static void getPageRejectsAPageLargerThanACursorWillFetch()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).getPage(1, 2001);
				Assert.fail('A page size above the cursor fetch cap should be rejected');
			}
			catch(IllegalArgumentException expected)
			{
				Assert.areEqual('Page size must be between 1 and 2000 records.', expected.getMessage(), 'The error should name the cap');
			}
		}
	}

	/**
	 * @description Tests that getPage() rejects page coordinates it cannot turn into an offset. A page number
	 * below one produces a negative offset, and a page size below one asks for no records at all.
	 */
	@IsTest
	private static void getPageRejectsPageCoordinatesBelowOne()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).getPage(0, 25);
				Assert.fail('A page number below one should be rejected');
			}
			catch(IllegalArgumentException expected)
			{
				Assert.areEqual('Page number must be 1 or greater.', expected.getMessage(), 'The error should name the page number');
			}

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).getPage(1, 0);
				Assert.fail('A page size below one should be rejected');
			}
			catch(IllegalArgumentException expected)
			{
				Assert.areEqual('Page size must be between 1 and 2000 records.', expected.getMessage(), 'The error should name the range');
			}
		}
	}

	/**
	 * @description Tests that setMock() and clearMocks() work correctly.
	 */
	@IsTest
	private static void mockingWorksCorrectly()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> mockRecords = TST_Factory.newFoobars(3);
			for(Foobar__c mockRecord : mockRecords)
			{
				mockRecord.Name = 'Mock Record';
			}

			QRY_Builder.setMock(Foobar__c.SObjectType, mockRecords);

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();

			Assert.areEqual(3, results.size(), 'Should return mock records');
			Assert.areEqual('Mock Record', ((Foobar__c)results[0]).Name, 'Should have mock name');

			QRY_Builder.clearMocks();

			List<SObject> afterClear = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();

			Assert.areEqual(0, afterClear.size(), 'Should return no records after clearing mocks');
		}
	}

	/**
	 * @description Tests that QRY_Builder.setMockException delegates to QRY_Engine.setMockException
	 * and that the registered exception fires on a query against that SObjectType.
	 */
	@IsTest
	private static void shouldDelegateSetMockExceptionToQryEngine()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.setMockException(Foobar__c.SObjectType, new QueryException('Pass-through failure'));

			Assert.isNotNull
					(
							QRY_Engine.getMockException(Foobar__c.SObjectType),
							'QRY_Builder.setMockException should register the exception on QRY_Engine'
					);

			Test.startTest();
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
				Assert.fail('Should throw the registered QueryException via pass-through');
			}
			catch(QueryException error)
			{
				Assert.areEqual
						(
								'Pass-through failure',
								error.getMessage(),
								'Pass-through should preserve the exception instance'
						);
			}
			Test.stopTest();

			QRY_Engine.clearMocks();
		}
	}

	/**
	 * @description Tests that an aggregate-scoped mock exception fires for a builder aggregate query but
	 * leaves a row query against the same SObjectType running for real — proving the builder stamps the
	 * aggregate flag onto its parameters and the engine scopes the throw to it.
	 */
	@IsTest
	private static void shouldScopeMockAggregateExceptionToAggregateQueries()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Engine.setMockAggregateException(Foobar__c.SObjectType, new QueryException('Aggregate-only failure'));

			Test.startTest();
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, 'total').groupBy(Foobar__c.Name).toAggregateList();
				Assert.fail('Should throw the registered aggregate exception for a builder aggregate query');
			}
			catch(QueryException error)
			{
				Assert.areEqual('Aggregate-only failure', error.getMessage(), 'The aggregate query should rethrow the registered instance');
			}

			List<SObject> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
			Assert.areEqual(0, rows.size(), 'A row query against the same SObjectType should execute for real');
			Test.stopTest();

			QRY_Engine.clearMocks();
		}
	}

	/**
	 * @description Tests that addCondition with QRY_Condition works.
	 */
	@IsTest
	private static void addConditionWithQryConditionWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			QRY_Condition.OrCondition orCondition = new QRY_Condition.OrCondition();
			orCondition.add(new QRY_Condition.FieldCondition('Name', QRY_Condition.Operator.EQUALS, record.Name));
			orCondition.add(new QRY_Condition.FieldCondition('Name', QRY_Condition.Operator.EQUALS, 'Other Record'));

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addCondition(orCondition)
					.toList();

			Assert.isFalse(results.isEmpty(), 'Should find records with OR condition');
		}
	}

	/**
	 * @description Tests that isIn() with SObject records works correctly.
	 */
	@IsTest
	private static void isInWithSObjectRecordsWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isIn(new List<SObject> {parent})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isTrue(resultIds.contains(child.Id), 'Should find child record');
		}
	}

	/**
	 * @description Tests that isIn() with field extraction works correctly.
	 */
	@IsTest
	private static void isInWithFieldExtractionWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(new List<SObject> {record}, Foobar__c.Id)
					.toList();

			Assert.areEqual(1, results.size(), 'Should find record by extracted field');
		}
	}

	/**
	 * @description Tests that notInSet() with SObject records works correctly.
	 */
	@IsTest
	private static void notInSetWithSObjectRecordsWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c excluded = TST_Factory.insertFoobar();
			Foobar__c included = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new List<SObject> {excluded})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(excluded.Id), 'Should not contain excluded record');
			Assert.isTrue(resultIds.contains(included.Id), 'Should contain included record');
		}
	}

	/**
	 * @description Tests that notInSet() with field extraction works correctly.
	 */
	@IsTest
	private static void notInSetWithFieldExtractionWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c excluded = TST_Factory.insertFoobar();
			Foobar__c included = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new List<SObject> {excluded}, Foobar__c.Id)
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(excluded.Id), 'Should not contain excluded record');
			Assert.isTrue(resultIds.contains(included.Id), 'Should contain included record');
		}
	}

	/**
	 * @description Tests that isInStrict() throws exception for empty list.
	 */
	@IsTest
	private static void isInStrictThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Name).isInStrict(new List<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict() throws exception for empty set.
	 */
	@IsTest
	private static void isInStrictThrowsForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Name).isInStrict(new Set<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict() with SObjects throws exception for empty list.
	 */
	@IsTest
	private static void isInStrictSObjectsThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Lookup__c).isInStrict(new List<SObject>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty SObject list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict() with field extraction throws exception for empty list.
	 */
	@IsTest
	private static void isInStrictFieldExtractionThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Id).isInStrict(new List<SObject>(), Foobar__c.Id)
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list with field extraction');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict(List<Object>) works with valid data.
	 */
	@IsTest
	private static void isInStrictListObjectSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isInStrict(new List<Object> {record.Id})
					.toList();

			Assert.areEqual(1, results.size(), 'Should find record');
		}
	}

	/**
	 * @description Tests that isInStrict(Set<Object>) works with valid data.
	 */
	@IsTest
	private static void isInStrictSetObjectSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isInStrict(new Set<Object> {record.Id})
					.toList();

			Assert.areEqual(1, results.size(), 'Should find record');
		}
	}

	/**
	 * @description Tests that isInStrict(List<SObject>) works with valid data.
	 */
	@IsTest
	private static void isInStrictListSObjectSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isInStrict(new List<SObject> {parent})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isTrue(resultIds.contains(child.Id), 'Should find child record');
		}
	}

	/**
	 * @description Tests that isInStrict(List<SObject>, SObjectField) works with valid data.
	 */
	@IsTest
	private static void isInStrictListSObjectFieldSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isInStrict(new List<SObject> {record}, Foobar__c.Id)
					.toList();

			Assert.areEqual(1, results.size(), 'Should find record');
		}
	}

	/**
	 * @description Tests that notInSet(Set<Object>) works correctly.
	 */
	@IsTest
	private static void notInSetWithSetObjectWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c excluded = TST_Factory.insertFoobar();
			Foobar__c included = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new Set<Object> {excluded.Id})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(excluded.Id), 'Should exclude record');
			Assert.isTrue(resultIds.contains(included.Id), 'Should include other record');
		}
	}

	/**
	 * @description Tests that notInSet(List<Object>) works correctly.
	 */
	@IsTest
	private static void notInSetWithListObjectWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c excluded = TST_Factory.insertFoobar();
			Foobar__c included = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new List<Object> {excluded.Id})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(excluded.Id), 'Should exclude record');
			Assert.isTrue(resultIds.contains(included.Id), 'Should include other record');
		}
	}

	/**
	 * @description Tests that notInSetStrict() throws exception for empty list.
	 */
	@IsTest
	private static void notInSetStrictThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Name).notInSetStrict(new List<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict() throws exception for empty set.
	 */
	@IsTest
	private static void notInSetStrictThrowsForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Name).notInSetStrict(new Set<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict() with SObjects throws exception for empty list.
	 */
	@IsTest
	private static void notInSetStrictSObjectsThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Lookup__c).notInSetStrict(new List<SObject>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty SObject list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict() with field extraction throws exception for empty list.
	 */
	@IsTest
	private static void notInSetStrictFieldExtractionThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Id).notInSetStrict(new List<SObject>(), Foobar__c.Id)
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list with field extraction');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that includes() works for multi-picklist fields.
	 */
	@IsTest
	private static void includesWorksForMultiPicklist()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes(new List<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('INCLUDES'), 'Should contain INCLUDES');
		}
	}

	/**
	 * @description Tests that includes() with Set works for multi-picklist fields.
	 */
	@IsTest
	private static void includesWithSetWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes(new Set<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('INCLUDES'), 'Should contain INCLUDES');
		}
	}

	/**
	 * @description Tests that includesStrict() throws exception for empty list.
	 */
	@IsTest
	private static void includesStrictThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Picklist__c).includesStrict(new List<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that includesStrict() throws exception for empty set.
	 */
	@IsTest
	private static void includesStrictThrowsForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Picklist__c).includesStrict(new Set<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that includesStrict() with List succeeds for valid values.
	 */
	@IsTest
	private static void includesStrictListSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includesStrict(new List<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('INCLUDES'), 'Should contain INCLUDES');
		}
	}

	/**
	 * @description Tests that includesStrict() with Set succeeds for valid values.
	 */
	@IsTest
	private static void includesStrictSetSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includesStrict(new Set<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('INCLUDES'), 'Should contain INCLUDES');
		}
	}

	/**
	 * @description Tests that excludes() works for multi-picklist fields.
	 */
	@IsTest
	private static void excludesWorksForMultiPicklist()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes(new List<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('EXCLUDES'), 'Should contain EXCLUDES');
		}
	}

	/**
	 * @description Tests that excludes() with Set works for multi-picklist fields.
	 */
	@IsTest
	private static void excludesWithSetWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes(new Set<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('EXCLUDES'), 'Should contain EXCLUDES');
		}
	}

	/**
	 * @description Tests that excludesStrict() throws exception for empty list.
	 */
	@IsTest
	private static void excludesStrictThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Picklist__c).excludesStrict(new List<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that excludesStrict() throws exception for empty set.
	 */
	@IsTest
	private static void excludesStrictThrowsForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Picklist__c).excludesStrict(new Set<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that excludesStrict() with List succeeds for valid values.
	 */
	@IsTest
	private static void excludesStrictListSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludesStrict(new List<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('EXCLUDES'), 'Should contain EXCLUDES');
		}
	}

	/**
	 * @description Tests that excludesStrict() with Set succeeds for valid values.
	 */
	@IsTest
	private static void excludesStrictSetSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludesStrict(new Set<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('EXCLUDES'), 'Should contain EXCLUDES');
		}
	}

	/**
	 * @description Tests that equals() with SObject record works correctly.
	 */
	@IsTest
	private static void equalsWithSObjectRecordWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).equals(parent)
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isTrue(resultIds.contains(child.Id), 'Should find child record');
		}
	}

	/**
	 * @description Tests that notEquals() with SObject record works correctly.
	 */
	@IsTest
	private static void notEqualsWithSObjectRecordWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c childWithParent = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();
			Foobar__c childWithoutParent = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notEquals(parent)
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(childWithParent.Id), 'Should not contain child with parent');
			Assert.isTrue(resultIds.contains(childWithoutParent.Id), 'Should contain child without parent');
		}
	}

	/**
	 * @description A time-to-live on the one-argument form asks for the most durable safe storage.
	 */
	@IsTest
	private static void withCacheTimeToLiveRequestsAutomaticScope()
	{
		QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType).withCache(CACHE_PROBE_TTL_SECONDS);

		Assert.areEqual(UTIL_Cache.Scope.AUTO, query.cacheScope, 'A time-to-live should request the AUTO scope');
		Assert.areEqual(CACHE_PROBE_TTL_SECONDS, query.cacheTTL, 'The time-to-live should be kept');
	}

	/**
	 * @description A null time-to-live on the one-argument form still requests nothing, as before 1.8.
	 */
	@IsTest
	private static void withCacheNullRequestsNothing()
	{
		QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType).withCache(null);

		Assert.isNull(query.cacheScope, 'A null time-to-live should request no caching');
		Assert.isNull(query.cacheTTL, 'A null time-to-live should stay null');
	}

	/**
	 * @description The transaction scope is a request even without a time-to-live, and reaches the engine.
	 */
	@IsTest
	private static void withCacheTransactionScopeReachesParameters()
	{
		QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType).withCache(UTIL_Cache.Scope.IN_TRANSACTION, null);

		QRY_Engine.QueryParameters parameters = query.buildParameters(new QRY_BindRegistry());

		Assert.areEqual(UTIL_Cache.Scope.IN_TRANSACTION, parameters.cacheScope, 'The scope should reach the engine');
		Assert.isNull(parameters.cacheTTL, 'No time-to-live was given');
	}

	/**
	 * @description The last caching call wins, in either order.
	 */
	@IsTest
	private static void lastCachingCallWins()
	{
		QRY_Builder.Builder switchedOff = QRY_Builder.selectFrom(Foobar__c.SObjectType).withCache(UTIL_Cache.Scope.ORG, DURABLE_PROBE_TTL_SECONDS).withoutCache();
		QRY_Builder.Builder switchedOn = QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutCache().withCache(UTIL_Cache.Scope.ORG, DURABLE_PROBE_TTL_SECONDS);

		Assert.isNull(switchedOff.cacheScope, 'withoutCache() after withCache should clear the scope');
		Assert.isNull(switchedOff.cacheTTL, 'withoutCache() should clear the time-to-live');
		Assert.areEqual(UTIL_Cache.Scope.ORG, switchedOn.cacheScope, 'withCache after withoutCache() should set the scope');
		Assert.areEqual(DURABLE_PROBE_TTL_SECONDS, switchedOn.cacheTTL, 'withCache after withoutCache() should set the time-to-live');
	}

	/**
	 * @description Tests that withCache() enables caching.
	 */
	@IsTest
	private static void withCacheEnablesCaching()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.withCache(300);

			List<SObject> results = query.toList();

			Assert.areEqual(1, results.size(), 'Should return record');
		}
	}

	/**
	 * @description Tests that HAVING conditions work with aggregates: havingCount writes the HAVING text COUNT(Id) > 0
	 * exactly, and the query runs and returns the saved row's group. The builder writes this text itself and passes it on
	 * as a field name, so the check on field names must accept it unchanged.
	 */
	@IsTest
	private static void havingConditionsWorkWithAggregates()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Name)
					.havingCount().greaterThan(0);
			List<AggregateResult> results = query.toList();

			Assert.areEqual('(COUNT(' + FIELD_ID + ') > 0)', query.toSoql().substringAfter(' HAVING '), 'Expected the HAVING text to stay as it is');
			Assert.isTrue(results.size() >= 1, 'Should return grouped results');
		}
	}

	/**
	 * @description Tests that havingSumOf writes the HAVING text SUM(field name) > 0 exactly, and that the query runs and
	 * returns the one group of the one saved row. The builder writes this text itself and passes it on as a field name, so the
	 * check on field names must accept it unchanged.
	 */
	@IsTest
	private static void havingSumOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.NumberInteger__c, 1).build();
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.sum(Foobar__c.NumberInteger__c)
					.groupBy(Foobar__c.Picklist__c)
					.havingSumOf(Foobar__c.NumberInteger__c).greaterThan(0);

			Assert.areEqual('(SUM(' + FIELD_NUMBER_INTEGER + ') > 0)', query.toSoql().substringAfter(' HAVING '), 'Expected the HAVING text to stay as it is');
			Assert.areEqual(1, query.toList().size(), 'Expected the query to run and return the one group');
		}
	}

	/**
	 * @description Tests that havingAvgOf writes the HAVING text AVG(field name) > 0 exactly, and that the query runs and
	 * returns the one group of the one saved row. The builder writes this text itself and passes it on as a field name, so the
	 * check on field names must accept it unchanged.
	 */
	@IsTest
	private static void havingAvgOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.NumberInteger__c, 1).build();
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.avg(Foobar__c.NumberInteger__c)
					.groupBy(Foobar__c.Picklist__c)
					.havingAvgOf(Foobar__c.NumberInteger__c).greaterThan(0);

			Assert.areEqual('(AVG(' + FIELD_NUMBER_INTEGER + ') > 0)', query.toSoql().substringAfter(' HAVING '), 'Expected the HAVING text to stay as it is');
			Assert.areEqual(1, query.toList().size(), 'Expected the query to run and return the one group');
		}
	}

	/**
	 * @description Tests that havingMinOf writes the HAVING text MIN(field name) > 0 exactly, and that the query runs and
	 * returns the one group of the one saved row. The builder writes this text itself and passes it on as a field name, so the
	 * check on field names must accept it unchanged.
	 */
	@IsTest
	private static void havingMinOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.NumberInteger__c, 1).build();
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.min(Foobar__c.NumberInteger__c)
					.groupBy(Foobar__c.Picklist__c)
					.havingMinOf(Foobar__c.NumberInteger__c).greaterThan(0);

			Assert.areEqual('(MIN(' + FIELD_NUMBER_INTEGER + ') > 0)', query.toSoql().substringAfter(' HAVING '), 'Expected the HAVING text to stay as it is');
			Assert.areEqual(1, query.toList().size(), 'Expected the query to run and return the one group');
		}
	}

	/**
	 * @description Tests that havingMaxOf writes the HAVING text MAX(field name) > 0 exactly, and that the query runs and
	 * returns the one group of the one saved row. The builder writes this text itself and passes it on as a field name, so the
	 * check on field names must accept it unchanged.
	 */
	@IsTest
	private static void havingMaxOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.NumberInteger__c, 1).build();
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.max(Foobar__c.NumberInteger__c)
					.groupBy(Foobar__c.Picklist__c)
					.havingMaxOf(Foobar__c.NumberInteger__c).greaterThan(0);

			Assert.areEqual('(MAX(' + FIELD_NUMBER_INTEGER + ') > 0)', query.toSoql().substringAfter(' HAVING '), 'Expected the HAVING text to stay as it is');
			Assert.areEqual(1, query.toList().size(), 'Expected the query to run and return the one group');
		}
	}

	/**
	 * @description Tests that havingCountOf writes the HAVING text COUNT(Id) > 0 exactly, and that the query runs and
	 * returns the one group of the one saved row. The builder writes this text itself and passes it on as a field name, so
	 * the check on field names must accept it unchanged.
	 */
	@IsTest
	private static void havingCountOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Picklist__c)
					.havingCountOf(Foobar__c.Id).greaterThan(0);

			Assert.areEqual('(COUNT(' + FIELD_ID + ') > 0)', query.toSoql().substringAfter(' HAVING '), 'Expected the HAVING text to stay as it is');
			Assert.areEqual(1, query.toList().size(), 'Expected the query to run and return the one group');
		}
	}

	/**
	 * @description Tests that aliased aggregate overloads accumulate into one SELECT: COUNT,
	 * COUNT_DISTINCT, SUM, AVG, MIN and MAX render together, each under its caller-supplied alias,
	 * alongside the GROUP BY.
	 */
	@IsTest
	private static void aliasedAggregatesRenderInOneQuery()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(Foobar__c.Id, 'rowTotal')
					.countDistinct(Foobar__c.Name, 'distinctNames')
					.sum(Foobar__c.NumberInteger__c, 'integerTotal')
					.avg(Foobar__c.NumberInteger__c, 'integerMean')
					.min(Foobar__c.CreatedDate, 'firstSeen')
					.max(Foobar__c.CreatedDate, 'lastSeen')
					.groupBy(Foobar__c.Picklist__c)
					.toSoql();

			Assert.isTrue(soql.contains('COUNT(Id) rowTotal'), 'Should render the aliased COUNT');
			Assert.isTrue(soql.contains('COUNT_DISTINCT(Name) distinctNames'), 'Should render the aliased COUNT_DISTINCT in the same SELECT');
			String integerFieldName = Foobar__c.NumberInteger__c.getDescribe().getName();
			Assert.isTrue(soql.contains('SUM(' + integerFieldName + ') integerTotal'), 'Should render the aliased SUM in the same SELECT');
			Assert.isTrue(soql.contains('AVG(' + integerFieldName + ') integerMean'), 'Should render the aliased AVG in the same SELECT');
			Assert.isTrue(soql.contains('MIN(CreatedDate) firstSeen'), 'Should render the aliased MIN in the same SELECT');
			Assert.isTrue(soql.contains('MAX(CreatedDate) lastSeen'), 'Should render the aliased MAX in the same SELECT');
			Assert.isTrue(soql.containsIgnoreCase('GROUP BY'), 'Should keep the GROUP BY clause');
		}
	}

	/**
	 * @description Tests that orderByCount renders an aggregate ordering (ORDER BY COUNT(field) DESC/ASC),
	 * the SOQL form for ranking grouped rows by size, and that both queries run. The builder writes COUNT(Id) itself and
	 * passes it on as a sort text, so the check on sort texts must accept it unchanged.
	 */
	@IsTest
	private static void orderByCountRendersAggregateOrdering()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();
			QRY_Builder.Builder descendingQuery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(Foobar__c.Id, 'rowTotal')
					.groupBy(Foobar__c.Picklist__c)
					.orderByCount(Foobar__c.Id, true);
			QRY_Builder.Builder ascendingQuery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(Foobar__c.Id, 'rowTotal')
					.groupBy(Foobar__c.Picklist__c)
					.orderByCount(Foobar__c.Id, false);
			String descending = descendingQuery.toSoql();
			String ascending = ascendingQuery.toSoql();

			Assert.isTrue(descending.endsWith('ORDER BY COUNT(Id) DESC'), 'Expected true to sort by the count, largest first');
			Assert.isTrue(ascending.endsWith('ORDER BY COUNT(Id) ASC'), 'Expected false to sort by the count, smallest first');
			Assert.areEqual(1, descendingQuery.toList().size(), 'Expected the query sorted by the count, largest first, to run');
			Assert.areEqual(1, ascendingQuery.toList().size(), 'Expected the query sorted by the count, smallest first, to run');
		}
	}

	/**
	 * @description Tests that aliased aggregates execute end-to-end over real rows: one query folds the
	 * row count and the earliest CreatedDate per group, ranks the groups largest-first via orderByCount,
	 * and caps at the top group — each value read back by its alias on the AggregateRow.
	 */
	@IsTest
	private static void aliasedAggregatesFoldOverRealRows()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'AggregateAlpha').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'AggregateAlpha').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'AggregateBeta').build();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(Foobar__c.Id, 'rowTotal')
					.min(Foobar__c.CreatedDate, 'firstSeen')
					.groupBy(Foobar__c.Name)
					.orderByCount(Foobar__c.Id, true)
					.withLimit(1)
					.toAggregateList();

			Assert.areEqual(1, rows.size(), 'The limit should cap the ranked groups at the top one');
			Assert.areEqual('AggregateAlpha', rows[0].getString('Name'), 'The largest group should rank first under orderByCount descending');
			Assert.areEqual(2, rows[0].getInteger('rowTotal'), 'The aliased COUNT should fold the two Alpha rows');
			Assert.isNotNull(rows[0].get('firstSeen'), 'The aliased MIN should fold in the same query');
		}
	}

	/**
	 * @description Tests that a malformed aggregate alias fails at the call site — the builder validates
	 * before recording the selection, so a bad alias can never reach the generated SOQL.
	 */
	@IsTest
	private static void malformedAggregateAliasThrowsAtCallSite()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, 'bad alias');
				Assert.fail('A malformed alias should throw at the call site');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
				Assert.isTrue(error.getMessage().contains('alias'), 'The error should name the alias rule');
			}
		}
	}

	/**
	 * @description Tests that the alias of a selected QRY_Function is validated by the same bare-identifier
	 * rule as the aliased aggregates, so no explicit-alias entry point concatenates raw caller text into
	 * the SELECT clause.
	 */
	@IsTest
	private static void malformedFunctionProjectionAliasThrows()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).addField(QRY_Function.calendarMonth(Foobar__c.CreatedDate), 'closeMonth, Name');
				Assert.fail('Expected a malformed alias on a selected function to throw at the call site');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
				Assert.isTrue(error.getMessage().contains('alias'), 'The error should name the alias rule');
			}
		}
	}

	/**
	 * @description Tests that orderByCount rejects a null field at the call site — the alternative is
	 * malformed 'ORDER BY COUNT(null)' SOQL that only fails at query time.
	 */
	@IsTest
	private static void orderByCountNullFieldThrows()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).orderByCount(null, true);
				Assert.fail('A null orderByCount field should throw at the call site');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that a field-less COUNT() cannot be combined with aliased aggregate selections —
	 * SOQL allows COUNT() only as the sole SELECT entry, so the build fails fast instead of dying at
	 * query time with an opaque parser error.
	 */
	@IsTest
	private static void fieldlessCountWithAliasedAggregatesThrowsOnBuild()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.count((String)null)
						.max(Foobar__c.CreatedDate, 'lastSeen')
						.toSoql();
				Assert.fail('A field-less COUNT() combined with aliased selections should throw at build time');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that a duplicate aggregate alias is rejected when the query builds — SOQL treats
	 * aliases case-insensitively, so a case-variant duplicate counts as a collision.
	 */
	@IsTest
	private static void duplicateAggregateAliasThrowsOnBuild()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.count(Foobar__c.Id, 'rowTotal')
						.min(Foobar__c.CreatedDate, 'ROWTOTAL')
						.groupBy(Foobar__c.Picklist__c)
						.toSoql();
				Assert.fail('A duplicate aggregate alias should throw when the query builds');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
				Assert.isTrue(error.getMessage().contains('alias'), 'The error should name the alias rule');
			}
		}
	}

	/**
	 * @description Tests that aliased aggregates combine with HAVING over real rows: the platform itself
	 * validates the combined query shape, and only groups passing the HAVING floor return.
	 */
	@IsTest
	private static void aliasedAggregatesHonourHavingOverRealRows()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'AggregateAlpha').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'AggregateAlpha').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'AggregateBeta').build();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(Foobar__c.Id, 'rowTotal')
					.min(Foobar__c.CreatedDate, 'firstSeen')
					.groupBy(Foobar__c.Name)
					.havingCountOf(Foobar__c.Id).greaterThan(1)
					.toAggregateList();

			Assert.areEqual(1, rows.size(), 'Only the group passing the HAVING floor should return');
			Assert.areEqual('AggregateAlpha', rows[0].getString('Name'), 'The multi-row group should pass the HAVING floor');
			Assert.areEqual(2, rows[0].getInteger('rowTotal'), 'The aliased COUNT should fold the two Alpha rows');
		}
	}

	/**
	 * @description Tests that surrounding whitespace on an explicit alias is trimmed rather than
	 * rejected. SOQL ignores padding around an alias, so a padded alias that worked before validation
	 * existed keeps working, for both the aggregate and the selected-function entry points.
	 */
	@IsTest
	private static void aliasPaddingIsTrimmedNotRejected()
	{
		System.runAs(getTestAdmin())
		{
			String aggregateSoql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(Foobar__c.Id, ' rowTotal ')
					.groupBy(Foobar__c.Picklist__c)
					.toSoql();
			String projectionSoql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.calendarMonth(Foobar__c.CreatedDate), ' closeMonth ')
					.count('Id')
					.groupBy(QRY_Function.calendarMonth(Foobar__c.CreatedDate))
					.toSoql();

			Assert.isTrue(aggregateSoql.contains('COUNT(Id) rowTotal'), 'The aggregate alias should render trimmed');
			Assert.isTrue(projectionSoql.contains('CALENDAR_MONTH(CreatedDate) closeMonth'), 'Expected the alias of the selected function to render trimmed');
		}
	}

	/**
	 * @description Tests countDistinct() aggregate method.
	 */
	@IsTest
	private static void countDistinctWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<AggregateResult> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.countDistinct(Foobar__c.Picklist__c)
					.toList();

			Assert.isFalse(results.isEmpty(), 'COUNT_DISTINCT query should return results');
		}
	}

	/**
	 * @description Tests countDistinct() aggregate method with String field name.
	 */
	@IsTest
	private static void countDistinctWithStringFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<AggregateResult> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.countDistinct(FIELD_PICKLIST)
					.toList();

			Assert.isFalse(results.isEmpty(), 'COUNT_DISTINCT with String field should return results');
		}
	}

	/**
	 * @description Tests that semi-join subquery works with isIn(), and records its query text: an inner query that
	 * selects one field name is written as Id IN (SELECT OwnerId FROM ...). The check on the inner query's selected
	 * field must accept this text unchanged. Only the test admin owns a Foobar__c row, and a second user owns none, so
	 * the query must return the test admin and nobody else.
	 * Uses Foobar__c/User to avoid same-object subquery limitation.
	 */
	@IsTest
	private static void semiJoinSubqueryWorks()
	{
		TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		User owner = getTestAdmin();
		System.runAs(owner)
		{
			TST_Factory.insertFoobar();

			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'OwnerId'});

			QRY_Builder.Builder query = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<String> {'Name'})
					.condition(FIELD_ID).isIn(subquery);
			List<SObject> results = query.toList();

			Assert.areEqual('SELECT Name FROM User WHERE Id IN (SELECT OwnerId FROM ' + OBJECT_NAME + ')', query.toSoql(), 'Expected the semi-join text to stay as it is');
			Assert.areEqual(1, results.size(), 'Expected the semi-join to return only the user who owns the Foobar__c row');
			Assert.areEqual(owner.Id, results[0].Id, 'Expected the semi-join to return the test admin, who owns the Foobar__c row');
		}
	}

	/**
	 * @description Tests that anti-join subquery works with notIn(). Only the test admin owns a Foobar__c row, and a
	 * second user owns none. Of these two users, the query must return the second user and leave out the test admin.
	 * Uses Foobar__c/User to avoid same-object subquery limitation.
	 */
	@IsTest
	private static void antiJoinSubqueryWorks()
	{
		User userWithoutRows = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		User owner = getTestAdmin();
		System.runAs(owner)
		{
			TST_Factory.insertFoobar();

			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'OwnerId'});

			QRY_Builder.Builder query = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<String> {'Name'})
					.condition(FIELD_ID).notIn(subquery)
					.condition(User.IsActive).equals(true);
			List<SObject> results = query.toList();

			Assert.areEqual
					(
							'SELECT Name FROM User WHERE (Id NOT IN (SELECT OwnerId FROM ' + OBJECT_NAME + ') AND IsActive = TRUE)',
							query.toSoql(),
							'Expected the anti-join text to stay as it is'
					);
			Set<Id> returnedSeededUserIds = new Set<Id>();
			for(SObject row : results)
			{
				returnedSeededUserIds.add(row.Id);
			}
			returnedSeededUserIds.retainAll(new Set<Id> {owner.Id, userWithoutRows.Id});
			Assert.areEqual
					(
							new Set<Id> {userWithoutRows.Id},
							returnedSeededUserIds,
							'Expected the anti-join to return the user who owns no Foobar__c row and to leave out the test admin'
					);
		}
	}

	/**
	 * @description Tests that relatedFields() adds parent field paths.
	 */
	@IsTest
	private static void relatedFieldsAddsParentPaths()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.relatedFields(new List<String> {'Lookup__r.Name'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Lookup__r.Name'), 'Should contain related field path');
		}
	}

	/**
	 * @description Tests that toCursor() returns a database cursor.
	 */
	@IsTest
	private static void toCursorReturnsDatabaseCursor()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Database.Cursor cursor = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals(record.Name)
					.toCursor();

			Assert.isNotNull(cursor, 'Should return database cursor');
		}
	}

	/**
	 * @description Tests that custom selector with getDefaultOrderBy works.
	 */
	@IsTest
	private static void customSelectorWithDefaultOrderByWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<QRY_Generator.OrderBy> orderBy = new OrderedSelector().getDefaultOrderBy();

			Assert.isNotNull(orderBy, 'Should return default order by');
		}
	}

	/**
	 * @description Tests that custom selector extending Builder works.
	 */
	@IsTest
	private static void customSelectorExtendsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<Foobar__c> results = new FoobarSelector().findByName(record.Name);

			Assert.isTrue(results.size() >= 1, 'Custom selector should work');
		}
	}

	/**
	 * @description Example custom selector extending QRY_Builder.Builder.
	 */
	private class FoobarSelector extends QRY_Builder.Builder
	{
		/**
		 * @description Constructs the selector for Foobar__c.
		 */
		public FoobarSelector()
		{
			super(Foobar__c.SObjectType);
		}

		/**
		 * @description Returns default fields for this selector.
		 *
		 * @return Set of field API names
		 */
		public override Set<String> getDefaultFields()
		{
			return new Set<String> {FIELD_ID, 'Name'};
		}

		/**
		 * @description Finds records by name.
		 *
		 * @param recordName The record name to filter by
		 *
		 * @return List of matching Foobar__c records
		 */
		@SuppressWarnings('PMD.UnnecessaryCast')
		public List<Foobar__c> findByName(String recordName)
		{
			return condition(Foobar__c.Name).equals(recordName).toList();
		}
	}

	/**
	 * @description Selector with default ordering.
	 */
	private class OrderedSelector extends QRY_Builder.Builder
	{
		/**
		 * @description Constructs the selector.
		 */
		public OrderedSelector()
		{
			super(Foobar__c.SObjectType);
		}

		/**
		 * @description Returns default order by for this selector.
		 *
		 * @return List of OrderBy clauses
		 */
		public override List<QRY_Generator.OrderBy> getDefaultOrderBy()
		{
			return new List<QRY_Generator.OrderBy> {new QRY_Generator.OrderBy('Name')};
		}
	}

	/**
	 * @description Selector with base condition.
	 */
	private class FilteredSelector extends QRY_Builder.Builder
	{
		/**
		 * @description Constructs the selector.
		 */
		public FilteredSelector()
		{
			super(Foobar__c.SObjectType);
		}

		/**
		 * @description Returns base condition applied to all queries.
		 *
		 * @return Condition filtering by name
		 */
		public override QRY_Condition.Evaluable getBaseCondition()
		{
			return new QRY_Condition.FieldCondition(Foobar__c.Name, QRY_Condition.Operator.NOT_EQUALS, null);
		}
	}

	/**
	 * @description Tests that custom selector with getBaseCondition works.
	 */
	@IsTest
	private static void customSelectorWithBaseConditionWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = new FilteredSelector()
					.condition(Foobar__c.Name).equals(record.Name)
					.toList();

			Assert.isFalse(results.isEmpty(), 'Should return filtered results');
		}
	}

	/**
	 * @description Tests that base getDefaultOrderBy returns null.
	 */
	@IsTest
	private static void baseGetDefaultOrderByReturnsNull()
	{
		System.runAs(getTestAdmin())
		{
			List<QRY_Generator.OrderBy> orderBy = new FoobarSelector().getDefaultOrderBy();

			Assert.isNull(orderBy, 'Base implementation should return null');
		}
	}

	/**
	 * @description Tests that custom selector with limit and offset works.
	 */
	@IsTest
	private static void customSelectorWithLimitAndOffsetWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);

			List<SObject> results = new FoobarSelector()
					.withLimit(2)
					.withOffset(1)
					.toList();

			Assert.areEqual(2, results.size(), 'Should return 2 records with offset');
		}
	}

	/**
	 * @description Tests that isIn() with null set adds a false condition.
	 */
	@IsTest
	private static void isInWithNullSetAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).isIn((Set<Object>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null set');
		}
	}

	/**
	 * @description Tests that isIn() with empty set adds a false condition.
	 */
	@IsTest
	private static void isInWithEmptySetAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).isIn(new Set<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty set');
		}
	}

	/**
	 * @description Tests that isIn() with null list adds a false condition.
	 */
	@IsTest
	private static void isInWithNullListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).isIn((List<Object>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null list');
		}
	}

	/**
	 * @description Tests that isIn() with empty list adds a false condition.
	 */
	@IsTest
	private static void isInWithEmptyListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).isIn(new List<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty list');
		}
	}

	/**
	 * @description Tests that isIn() with null SObject list adds a false condition.
	 */
	@IsTest
	private static void isInWithNullSObjectListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isIn((List<SObject>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null SObject list');
		}
	}

	/**
	 * @description Tests that isIn() with empty SObject list adds a false condition.
	 */
	@IsTest
	private static void isInWithEmptySObjectListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isIn(new List<SObject>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty SObject list');
		}
	}

	/**
	 * @description Tests that isIn() with SObject list containing only nulls adds a false condition.
	 */
	@IsTest
	private static void isInWithAllNullSObjectsAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isIn(records)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when only null records');
		}
	}

	/**
	 * @description Tests that isIn() with field extraction on null list adds a false condition.
	 */
	@IsTest
	private static void isInWithFieldExtractionNullListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn((List<SObject>)null, Foobar__c.Id)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null list');
		}
	}

	/**
	 * @description Tests that isIn() with field extraction on empty list adds a false condition.
	 */
	@IsTest
	private static void isInWithFieldExtractionEmptyListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(new List<SObject>(), Foobar__c.Id)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty list');
		}
	}

	/**
	 * @description Tests that isIn() with field extraction on all-null list adds a false condition.
	 */
	@IsTest
	private static void isInWithFieldExtractionAllNullAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(records, Foobar__c.Id)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when only null records');
		}
	}

	/**
	 * @description Tests that isIn() with empty set combined with another condition
	 * includes the false condition in SOQL, preventing silent query expansion.
	 */
	@IsTest
	private static void isInWithEmptySetAndOtherConditionAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Text__c).equals('Test')
					.andCondition(Foobar__c.Picklist__c).isIn(new Set<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition for empty isIn');
			Assert.isTrue(soql.containsIgnoreCase('= \'Test\''), 'Should still contain the other condition');
		}
	}

	/**
	 * @description Tests that notInSet() with null set returns builder without error.
	 */
	@IsTest
	private static void notInSetWithNullSetReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).notInSet((Set<Object>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when null set');
		}
	}

	/**
	 * @description Tests that notInSet() with empty set returns builder without error.
	 */
	@IsTest
	private static void notInSetWithEmptySetReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).notInSet(new Set<Object>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when empty set');
		}
	}

	/**
	 * @description Tests that notInSet() with null list returns builder without error.
	 */
	@IsTest
	private static void notInSetWithNullListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).notInSet((List<Object>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when null list');
		}
	}

	/**
	 * @description Tests that notInSet() with empty list returns builder without error.
	 */
	@IsTest
	private static void notInSetWithEmptyListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).notInSet(new List<Object>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when empty list');
		}
	}

	/**
	 * @description Tests that notInSet() with null SObject list returns builder without error.
	 */
	@IsTest
	private static void notInSetWithNullSObjectListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSet((List<SObject>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when null SObject list');
		}
	}

	/**
	 * @description Tests that notInSet() with empty SObject list returns builder without error.
	 */
	@IsTest
	private static void notInSetWithEmptySObjectListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSet(new List<SObject>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when empty SObject list');
		}
	}

	/**
	 * @description Tests that notInSet() with SObject list containing only nulls returns builder.
	 */
	@IsTest
	private static void notInSetWithAllNullSObjectsReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSet(records)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when only null records');
		}
	}

	/**
	 * @description Tests that notInSet() with field extraction on null list returns builder.
	 */
	@IsTest
	private static void notInSetWithFieldExtractionNullListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet((List<SObject>)null, Foobar__c.Id)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when null list');
		}
	}

	/**
	 * @description Tests that notInSet() with field extraction on empty list returns builder.
	 */
	@IsTest
	private static void notInSetWithFieldExtractionEmptyListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new List<SObject>(), Foobar__c.Id)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when empty list');
		}
	}

	/**
	 * @description Tests that notInSet() with field extraction on all-null list returns builder.
	 */
	@IsTest
	private static void notInSetWithFieldExtractionAllNullReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(records, Foobar__c.Id)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when only null records');
		}
	}

	/**
	 * @description Tests that includes() with null list adds a false condition.
	 */
	@IsTest
	private static void includesWithNullListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes((List<Object>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null list');
		}
	}

	/**
	 * @description Tests that includes() with empty list adds a false condition.
	 */
	@IsTest
	private static void includesWithEmptyListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes(new List<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty list');
		}
	}

	/**
	 * @description Tests that includes() with null set adds a false condition.
	 */
	@IsTest
	private static void includesWithNullSetAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes((Set<Object>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null set');
		}
	}

	/**
	 * @description Tests that includes() with empty set adds a false condition.
	 */
	@IsTest
	private static void includesWithEmptySetAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes(new Set<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty set');
		}
	}

	/**
	 * @description Tests that excludes() with null list returns builder without error.
	 */
	@IsTest
	private static void excludesWithNullListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes((List<Object>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('EXCLUDES'), 'Should not contain EXCLUDES when null list');
		}
	}

	/**
	 * @description Tests that excludes() with empty list returns builder without error.
	 */
	@IsTest
	private static void excludesWithEmptyListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes(new List<Object>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('EXCLUDES'), 'Should not contain EXCLUDES when empty list');
		}
	}

	/**
	 * @description Tests that excludes() with null set returns builder without error.
	 */
	@IsTest
	private static void excludesWithNullSetReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes((Set<Object>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('EXCLUDES'), 'Should not contain EXCLUDES when null set');
		}
	}

	/**
	 * @description Tests that excludes() with empty set returns builder without error.
	 */
	@IsTest
	private static void excludesWithEmptySetReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes(new Set<Object>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('EXCLUDES'), 'Should not contain EXCLUDES when empty set');
		}
	}

	/**
	 * @description Tests that QueryPage.totalPages returns 1 when pageSize is null.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneWhenPageSizeNull()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 10;
			page.pageSize = null;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is null');
		}
	}

	/**
	 * @description Tests that QueryPage.totalPages returns 1 when pageSize is 0.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneWhenPageSizeZero()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 10;
			page.pageSize = 0;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is 0');
		}
	}

	/**
	 * @description Tests that isInStrict with SObjects containing only nulls throws exception.
	 */
	@IsTest
	private static void isInStrictWithAllNullSObjectsThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Lookup__c).isInStrict(records)
						.toList();
				Assert.fail('Should throw for list with only null records');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict with field extraction containing only nulls throws exception.
	 */
	@IsTest
	private static void isInStrictFieldExtractionAllNullsThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Id).isInStrict(records, Foobar__c.Id)
						.toList();
				Assert.fail('Should throw for list with only null records');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict with SObjects containing only nulls throws exception.
	 */
	@IsTest
	private static void notInSetStrictWithAllNullSObjectsThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Lookup__c).notInSetStrict(records)
						.toList();
				Assert.fail('Should throw for list with only null records');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict with field extraction containing only nulls throws exception.
	 */
	@IsTest
	private static void notInSetStrictFieldExtractionAllNullsThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Id).notInSetStrict(records, Foobar__c.Id)
						.toList();
				Assert.fail('Should throw for list with only null records');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests addFields with SObjectField list.
	 */
	@IsTest
	private static void addFieldsWithSObjectFieldListWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields(new List<SObjectField> {Foobar__c.Name, Foobar__c.Text__c})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME), 'Should contain Name field');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT), 'Should contain Text field');
		}
	}

	/**
	 * @description Tests addFields with String list.
	 */
	@IsTest
	private static void addFieldsWithStringListWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields(new List<String> {'Name', SEL_Foobar.FIELD_TEXT})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME), 'Should contain Name field');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT), 'Should contain Text field');
		}
	}

	/**
	 * @description Tests addField with SObjectField.
	 */
	@IsTest
	private static void addFieldWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Email__c)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_EMAIL), 'Should contain Email field');
		}
	}

	/**
	 * @description Tests addField with String.
	 */
	@IsTest
	private static void addFieldWithStringWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(SEL_Foobar.FIELD_EMAIL)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_EMAIL), 'Should contain Email field');
		}
	}

	/**
	 * @description A TYPEOF field given to addField as text reaches the query exactly as it was written. The builder
	 * does not change its words, its order or its case.
	 */
	@IsTest
	private static void typeOfTextPathRendersTheClauseAsWritten()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Event.SObjectType)
					.fields(new List<SObjectField> {Event.Id, Event.Subject})
					.addField(TYPEOF_CLAUSE)
					.toSoql();

			Assert.isTrue(soql.contains(TYPEOF_CLAUSE), 'Expected the query to hold the TYPEOF field exactly as written, but got: ' + soql);
		}
	}

	/**
	 * @description A TYPEOF field read in user mode brings back the fields of the parent the Event points to. User
	 * mode means the query runs with the running user's object and field permissions. One Event points to an Account
	 * and one Event has no parent. Both come back. The parent of the first is an Account that carries its Phone
	 * (readAccountPhone checks the parent's type). The second Event has no parent.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void typeOfTextPathReadsParentFieldsInUserMode()
	{
		System.runAs(getTestAdmin())
		{
			Account parentAccount = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Phone, PARENT_PHONE)
					.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
					.build();
			Event linkedEvent = (Event)TST_Builder.of(Event.SObjectType)
					.withOverride(Event.WhatId, parentAccount.Id)
					.withOverride(Event.ActivityDateTime, Datetime.now())
					.withOverride(Event.DurationInMinutes, EVENT_DURATION_MINUTES)
					.build();
			Event unlinkedEvent = (Event)TST_Builder.of(Event.SObjectType)
					.withOverride(Event.ActivityDateTime, Datetime.now())
					.withOverride(Event.DurationInMinutes, EVENT_DURATION_MINUTES)
					.build();

			List<SObject> rows = QRY_Builder.selectFrom(Event.SObjectType)
					.fields(new List<SObjectField> {Event.Id, Event.Subject})
					.addField(TYPEOF_CLAUSE)
					.condition(Event.Id).isIn(new List<SObject> {linkedEvent, unlinkedEvent})
					.withUserMode()
					.toList();

			Map<Id, SObject> rowsById = new Map<Id, SObject>(rows);
			Assert.areEqual(new Set<Id> {linkedEvent.Id, unlinkedEvent.Id}, rowsById.keySet(), 'Expected the query to return both Events');

			SObject parent = ((Event)rowsById.get(linkedEvent.Id)).What;
			Assert.areEqual(PARENT_PHONE, readAccountPhone(parent), 'Expected the parent of the linked Event to be an Account that carries its Phone');
			Assert.isNull(((Event)rowsById.get(unlinkedEvent.Id)).What, 'Expected the Event without a parent to come back with no parent');
		}
	}

	/**
	 * @description A TYPEOF query answered by a test mock returns the mock rows as they were registered. The mock
	 * Event carries an Account as its parent, and the parent comes back with its Id and its Phone.
	 */
	@IsTest
	private static void typeOfTextPathReturnsMockRowsUntouched()
	{
		System.runAs(getTestAdmin())
		{
			Account parentAccount = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Phone, PARENT_PHONE)
					.withoutInsertion(true)
					.build();
			Event mockEvent = (Event)TST_Builder.of(Event.SObjectType)
					.withOverride(Event.WhatId, parentAccount.Id)
					.withOverride(Event.ActivityDateTime, Datetime.now())
					.withOverride(Event.DurationInMinutes, EVENT_DURATION_MINUTES)
					.withoutInsertion(true)
					.build();
			mockEvent.putSObject(UTIL_SObjectDescribe.getCachedFieldDescribe(Event.WhatId).getRelationshipName(), parentAccount);
			TST_Mock.register(Event.SObjectType, mockEvent);

			List<SObject> rows = QRY_Builder.selectFrom(Event.SObjectType)
					.fields(new List<SObjectField> {Event.Id, Event.Subject})
					.addField(TYPEOF_CLAUSE)
					.withUserMode()
					.toList();

			Assert.areEqual(1, rows.size(), 'Expected the query to return the one mock Event');
			Event row = (Event)rows[0];
			Assert.areEqual(mockEvent.Id, row.Id, 'Expected the row to be the mock Event');
			Assert.areEqual(parentAccount.Id, row.What?.Id, 'Expected the parent to come back with the Id it was registered with');
			Assert.areEqual(PARENT_PHONE, readAccountPhone(row.What), 'Expected the mock Event to keep its Account parent and the parent Phone');
		}
	}

	/**
	 * @description A TYPEOF query with withCache is answered from the cache the second time it runs. The first read
	 * goes to the database and isCached reports false. A result read in user mode is kept in memory for the rest of the
	 * transaction, so the second read comes from that memory, not from Platform Cache. isCached reports true, and the
	 * parent fields are still there.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void typeOfTextPathIsServedFromTheCacheOnTheSecondRead()
	{
		System.runAs(getTestAdmin())
		{
			Account parentAccount = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Phone, PARENT_PHONE)
					.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
					.build();
			Event linkedEvent = (Event)TST_Builder.of(Event.SObjectType)
					.withOverride(Event.WhatId, parentAccount.Id)
					.withOverride(Event.ActivityDateTime, Datetime.now())
					.withOverride(Event.DurationInMinutes, EVENT_DURATION_MINUTES)
					.build();

			QRY_Builder.Builder query = QRY_Builder.selectFrom(Event.SObjectType)
					.fields(new List<SObjectField> {Event.Id, Event.Subject})
					.addField(TYPEOF_CLAUSE)
					.condition(Event.Id).equals(linkedEvent.Id)
					.withUserMode()
					.withCache(CACHE_PROBE_TTL_SECONDS);

			query.toList();
			Boolean firstReadCached = query.isCached();
			List<SObject> secondRows = query.toList();

			Assert.isFalse(firstReadCached, 'Expected the first read to go to the database');
			Assert.isTrue(query.isCached(), 'Expected the second read to come from the cache');
			Assert.areEqual(1, secondRows.size(), 'Expected the cached read to return the one Event');
			Assert.areEqual(PARENT_PHONE, readAccountPhone(((Event)secondRows[0]).What), 'Expected the cached row to keep its Account parent and the parent Phone');
		}
	}

	/**
	 * @description Tests selectAllFields method.
	 */
	@IsTest
	private static void selectAllFieldsWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.selectAllFields()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME), 'Should contain Name field');
			Assert.isTrue(soql.containsIgnoreCase('CreatedDate'), 'Should contain CreatedDate field');
			Assert.isTrue(soql.containsIgnoreCase('LastModifiedDate'), 'Should contain LastModifiedDate field');
		}
	}

	/**
	 * @description Tests relatedField with single string.
	 */
	@IsTest
	private static void relatedFieldWithStringSingle()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.relatedField('Owner.Name')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Owner.Name'), 'Should contain related field');
		}
	}

	/**
	 * @description Tests withOffset method.
	 */
	@IsTest
	private static void withOffsetWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withOffset(10)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('OFFSET 10'), 'Should contain OFFSET clause');
		}
	}

	/**
	 * @description Tests withUserMode method.
	 */
	@IsTest
	private static void withUserModeWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.withUserMode()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with user mode');
		}
	}

	/**
	 * @description Flag disabled: new Builder defaults to SYSTEM_MODE.
	 */
	@IsTest
	private static void shouldDefaultToSystemModeWhenFlagDisabled()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true, false);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			Assert.isFalse(builder.userModeEnabled, 'Builder must default to SYSTEM_MODE when UserModeQueries_Enabled is disabled');
		}
	}

	/**
	 * @description Flag enabled: new Builder defaults to USER_MODE.
	 */
	@IsTest
	private static void shouldDefaultToUserModeWhenFlagEnabled()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			Assert.isTrue(builder.userModeEnabled, 'Builder must default to USER_MODE when UserModeQueries_Enabled is enabled');
		}
	}

	/**
	 * @description .withSystemMode() overrides a flag-driven USER_MODE default.
	 */
	@IsTest
	private static void shouldLetWithSystemModeOverrideFlag()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode();

			Assert.isFalse(builder.userModeEnabled, '.withSystemMode() must force SYSTEM_MODE regardless of flag');
		}
	}

	/**
	 * @description .withUserMode() overrides a flag-driven SYSTEM_MODE default.
	 */
	@IsTest
	private static void shouldLetWithUserModeOverrideFlag()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true, false);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).withUserMode();

			Assert.isTrue(builder.userModeEnabled, '.withUserMode() must force USER_MODE regardless of flag');
		}
	}

	/**
	 * @description Last explicit access-mode call wins (chained overrides).
	 */
	@IsTest
	private static void shouldRespectLastAccessModeCall()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true, false);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).withUserMode().withSystemMode();

			Assert.isFalse(builder.userModeEnabled, 'Last access-mode call (.withSystemMode) must win');
		}
	}

	/**
	 * @description Tests stripInaccessible method.
	 */
	@IsTest
	private static void stripInaccessibleWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.stripInaccessible()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with strip inaccessible');
		}
	}

	/**
	 * @description Tests withSharing method.
	 */
	@IsTest
	private static void withSharingWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.withSharing()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with sharing');
		}
	}

	/**
	 * @description Tests bypassSharing method.
	 */
	@IsTest
	private static void bypassSharingWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.bypassSharing()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with bypass sharing');
		}
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
	 * @description withSystemMode() with bypassSharing() turns off both the field checks and record sharing. The row
	 * another user owns comes back with the hidden Email__c field. When stripInaccessible() is added, the same read
	 * removes the field the running user cannot read.
	 */
	@IsTest
	private static void systemModeWithBypassSharingKeepsEveryField()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> keptRows;
		List<SObject> strippedRows;
		System.runAs(restricted)
		{
			keptRows = newRowQuery(row.Id).addField(Foobar__c.Email__c).withSystemMode().bypassSharing().toList();
			strippedRows = newRowQuery(row.Id).addField(Foobar__c.Email__c).withSystemMode().bypassSharing().stripInaccessible().toList();
		}

		Assert.areEqual(1, keptRows.size(), 'Expected the read to reach the row the test administrator owns');
		Assert.areEqual(row.Email__c, keptRows[0].get(Foobar__c.Email__c), 'Expected the row to keep the email, because system mode checks no field');
		Assert.areEqual(1, strippedRows.size(), 'Expected the read with stripInaccessible() to reach the row too');
		Assert.isFalse(strippedRows[0].isSet(Foobar__c.Email__c), 'Expected stripInaccessible() to remove the email the user cannot read');
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
		Assert.areEqual(1, countBypassAuditEntries(SHARING_AUDIT_PREFIX + objectName), 'Expected exactly one audit entry for skipping record sharing');
		Assert.areEqual(0, countBypassAuditEntries(SYSTEM_MODE_AUDIT_PREFIX + objectName), 'Expected no audit entry for system mode, because no field check was turned off');
		Assert.areEqual(0, countBypassAuditEntries(SECURITY_MODE_AUDIT_PREFIX + objectName), 'Expected no audit entry for turning off every check');
	}

	/**
	 * @description withSharing() alone, under the default user mode, reads none of the rows another user owns. The
	 * restricted user may read Foobar__c records, so the empty result comes from record sharing, not from a refusal.
	 */
	@IsTest
	private static void withSharingAloneUnderUserModeReadsNoOtherOwnersRow()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> rows;
		System.runAs(restricted)
		{
			rows = newRowQuery(row.Id).withSharing().toList();
		}

		Assert.areEqual(0, rows.size(), 'Expected record sharing to hide the row the test administrator owns');
	}

	/**
	 * @description withSystemMode() with bypassSharing(), in either order, still opens a query locator and a cursor and
	 * each reaches the row another user owns. A batch job reads a query locator later, and a later transaction can read
	 * a cursor, so the framework cannot remove hidden fields from what they return. With system mode the caller has
	 * already turned off the field checks, so these reads stay open. For the same reason a page read with getPage()
	 * still hands back its pagination cursor.
	 */
	@IsTest
	private static void systemModeWithBypassSharingStillOpensALocatorAndACursor()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		Integer locatorRowsSystemModeFirst;
		Integer locatorRowsBypassFirst;
		Integer cursorRowsSystemModeFirst;
		Integer cursorRowsBypassFirst;
		QRY_Builder.QueryPage page;
		System.runAs(restricted)
		{
			locatorRowsSystemModeFirst = countLocatorRows(newRowQuery(row.Id).withSystemMode().bypassSharing().toQueryLocator());
			locatorRowsBypassFirst = countLocatorRows(newRowQuery(row.Id).bypassSharing().withSystemMode().toQueryLocator());
			cursorRowsSystemModeFirst = countCursorRows(newRowQuery(row.Id).withSystemMode().bypassSharing().toCursor());
			cursorRowsBypassFirst = countCursorRows(newRowQuery(row.Id).bypassSharing().withSystemMode().toCursor());
			page = newRowQuery(row.Id).withSystemMode().bypassSharing().getPage(1, BYPASS_PAGE_SIZE);
		}

		Assert.areEqual(1, page.records.size(), 'Expected the page to hold the row the test administrator owns');
		Assert.isNotNull(page.cursor, 'Expected the page read in system mode to keep its pagination cursor');

		Assert.areEqual(1, locatorRowsSystemModeFirst, 'Expected the query locator to reach the row when withSystemMode() comes first');
		Assert.areEqual(1, locatorRowsBypassFirst, 'Expected the query locator to reach the row when bypassSharing() comes first');
		Assert.areEqual(1, cursorRowsSystemModeFirst, 'Expected the cursor to return the row when withSystemMode() comes first');
		Assert.areEqual(1, cursorRowsBypassFirst, 'Expected the cursor to return the row when bypassSharing() comes first');
	}

	/**
	 * @description withSystemMode() with bypassSharing(), in either order, still reads totals of a grouped query. The
	 * group of the row another user owns comes back from toAggregateList() and from getFirstAggregate(), with a count of
	 * one.
	 */
	@IsTest
	private static void systemModeWithBypassSharingStillReadsTotals()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<QRY_Builder.AggregateRow> groups = new List<QRY_Builder.AggregateRow>();
		System.runAs(restricted)
		{
			groups.addAll(newGroupedQuery(row.Name).withSystemMode().bypassSharing().toAggregateList());
			groups.addAll(newGroupedQuery(row.Name).bypassSharing().withSystemMode().toAggregateList());
			groups.add(newGroupedQuery(row.Name).withSystemMode().bypassSharing().getFirstAggregate());
			groups.add(newGroupedQuery(row.Name).bypassSharing().withSystemMode().getFirstAggregate());
		}

		Assert.areEqual(4, groups.size(), 'Expected one group from each of the four reads');
		for(QRY_Builder.AggregateRow total : groups)
		{
			Assert.isNotNull(total, 'Expected getFirstAggregate() to return the group');
			Assert.areEqual(row.Name, total.getString(FIELD_NAME), 'Expected the group of the row the test administrator owns');
			Assert.areEqual(1, total.getInteger(ROW_COUNT_ALIAS), 'Expected the group to count the one row');
		}
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
		Assert.areEqual(0, countBypassAuditEntries(SHARING_AUDIT_PREFIX + objectName), 'Expected no audit entry for skipping record sharing, because the read was refused');
		Assert.areEqual(0, countBypassAuditEntries(SYSTEM_MODE_AUDIT_PREFIX + objectName), 'Expected no audit entry for system mode, because the read was refused');
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
	 * @description getRandomItems removes the fields the user cannot read when stripInaccessible() is on. The read runs
	 * in system mode with sharing bypassed and selects Email__c, which the running user cannot read. The row comes back
	 * without it.
	 */
	@IsTest
	private static void getRandomItemsRemovesFieldsTheUserCannotRead()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> rows;
		System.runAs(restricted)
		{
			rows = newRowQuery(row.Id).withSystemMode().bypassSharing().stripInaccessible().addField(Foobar__c.Email__c).getRandomItems(1);
		}

		Assert.areEqual(1, rows.size(), 'Expected getRandomItems to return the row the test administrator owns');
		Assert.isFalse(rows[0].isSet(Foobar__c.Email__c), 'Expected stripInaccessible() to remove the email, which the user cannot read');
	}

	/**
	 * @description bypassSharing() with an explicit withUserMode(), in either order, reads the row another user owns.
	 * The order of the calls does not change the result.
	 */
	@IsTest
	private static void bypassSharingWithExplicitUserModeReadsAnotherUsersRowInEitherOrder()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> userModeFirstRows;
		List<SObject> bypassFirstRows;
		System.runAs(restricted)
		{
			userModeFirstRows = newRowQuery(row.Id).withUserMode().bypassSharing().toList();
			bypassFirstRows = newRowQuery(row.Id).bypassSharing().withUserMode().toList();
		}

		Assert.areEqual(1, userModeFirstRows.size(), 'Expected the read to reach the administrator\'s row when withUserMode() comes first');
		Assert.areEqual(1, bypassFirstRows.size(), 'Expected the read to reach the administrator\'s row when bypassSharing() comes first');
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
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
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
			parentAccount = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Name, UTIL_Random.randomName())
					.withOverride(Account.Phone, PARENT_PHONE)
					.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
					.build();
			linkedEvent = (Event)TST_Builder.of(Event.SObjectType)
					.withOverride(Event.WhatId, parentAccount.Id)
					.withOverride(Event.ActivityDateTime, Datetime.now())
					.withOverride(Event.DurationInMinutes, EVENT_DURATION_MINUTES)
					.build();
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
	 * @description Records a known limit of bypassSharing() alone: a filter on a parent field the user cannot read still
	 * runs. The framework checks only the names of fields that belong to the queried object, so it does not check a
	 * relationship path such as Lookup__r.Email__c, or a condition written as plain text. The rows can therefore tell
	 * the user something about such a field, and a developer must not filter on it under the bypass. Both reads here
	 * filter on the parent's email, once as a path and once as plain text. Each returns the child row, without the
	 * child's own email.
	 */
	@IsTest
	private static void bypassSharingAloneStillFiltersThroughARelationshipPathTheUserCannotRead()
	{
		User restricted = insertRestrictedReader();
		Foobar__c parent = insertRowOwnedByAdmin(null);
		Foobar__c child = insertRowOwnedByAdmin(parent.Id);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);
		String parentEmailPath = buildParentEmailPath();
		String filterText = parentEmailPath + ' = \'' + String.escapeSingleQuotes(parent.Email__c) + '\'';

		List<SObject> pathRows;
		List<SObject> textRows;
		System.runAs(restricted)
		{
			pathRows = newRowQuery(child.Id).addField(Foobar__c.Email__c).andCondition(parentEmailPath).equals(parent.Email__c).bypassSharing().toList();
			textRows = newRowQuery(child.Id).addField(Foobar__c.Email__c).addCondition(new TextFilter(filterText)).bypassSharing().toList();
		}

		for(List<SObject> rows : new List<List<SObject>> {pathRows, textRows})
		{
			Assert.areEqual(1, rows.size(), 'Expected the filter on the parent email to run and return the child row');
			Assert.areEqual(child.Id, rows[0].Id, 'Expected the row to be the child row');
			Assert.isFalse(rows[0].isSet(Foobar__c.Email__c), 'Expected the child email, which the user cannot read, to be removed');
		}
	}

	/**
	 * @description The last sharing call wins. bypassSharing() followed by withSharing() reads none of the rows another
	 * user owns, and it is an ordinary read again: toQueryLocator() and toCursor() are not refused, and they also reach
	 * no row of another owner. withSharing() followed by bypassSharing() reads the row.
	 */
	@IsTest
	private static void bypassSharingThenWithSharingReadsNoOtherOwnersRow()
	{
		User restricted = insertRestrictedReader();
		Foobar__c row = insertRowOwnedByAdmin(null);
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> sharingLastRows;
		List<SObject> bypassLastRows;
		Integer sharingLastLocatorRows;
		Integer sharingLastCursorRows;
		System.runAs(restricted)
		{
			sharingLastRows = newRowQuery(row.Id).bypassSharing().withSharing().toList();
			bypassLastRows = newRowQuery(row.Id).withSharing().bypassSharing().toList();
			sharingLastLocatorRows = countLocatorRows(newRowQuery(row.Id).bypassSharing().withSharing().toQueryLocator());
			sharingLastCursorRows = countCursorRows(newRowQuery(row.Id).bypassSharing().withSharing().toCursor());
		}

		Assert.areEqual(0, sharingLastLocatorRows, 'Expected the query locator, with withSharing() last, to reach no row of another owner');
		Assert.areEqual(0, sharingLastCursorRows, 'Expected the cursor, with withSharing() last, to return no row of another owner');
		Assert.areEqual(0, sharingLastRows.size(), 'Expected withSharing(), called last, to hide the row the test administrator owns');
		Assert.areEqual(1, bypassLastRows.size(), 'Expected bypassSharing(), called last, to read the row the test administrator owns');
	}

	/**
	 * @description Tests withoutSecurity method.
	 */
	@IsTest
	private static void withoutSecurityWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.withUserMode()
					.withoutSecurity()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record after reset security');
		}
	}

	/**
	 * @description Tests forUpdate method.
	 */
	@IsTest
	private static void forUpdateWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.forUpdate()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('FOR UPDATE'), 'Should contain FOR UPDATE');
		}
	}

	/**
	 * @description Tests forReference method.
	 */
	@IsTest
	private static void forReferenceWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.forReference()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('FOR REFERENCE'), 'Should contain FOR REFERENCE');
		}
	}

	/**
	 * @description Tests forView method.
	 */
	@IsTest
	private static void forViewWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.forView()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('FOR VIEW'), 'Should contain FOR VIEW');
		}
	}

	/**
	 * @description Tests allRows method.
	 */
	@IsTest
	private static void allRowsWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.allRows()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ALL ROWS'), 'Should contain ALL ROWS');
		}
	}

	/**
	 * @description Tests ascending method for ORDER BY.
	 */
	@IsTest
	private static void ascendingWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name).ascending()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
		}
	}

	/**
	 * @description Tests nullsFirst method for ORDER BY.
	 */
	@IsTest
	private static void nullsFirstWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name).nullsFirst()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should have NULLS FIRST');
		}
	}

	/**
	 * @description Tests nullsLast method for ORDER BY.
	 */
	@IsTest
	private static void nullsLastWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name).nullsLast()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should have NULLS LAST');
		}
	}

	/**
	 * @description Tests orderBy with SObjectField and sortDescending flag ascending.
	 */
	@IsTest
	private static void orderByFieldWithDescendingFalseWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name, false)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should default to NULLS FIRST');
		}
	}

	/**
	 * @description Tests orderBy with SObjectField and sortDescending flag descending.
	 */
	@IsTest
	private static void orderByFieldWithDescendingTrueWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name, true)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should default to NULLS LAST for DESC');
		}
	}

	/**
	 * @description Tests orderBy with SObjectField, sortDescending, and nullsLast flags.
	 */
	@IsTest
	private static void orderByFieldWithDescendingAndNullsLastWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name, true, true)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should have NULLS LAST');
		}
	}

	/**
	 * @description Tests orderBy with SObjectField, ascending direction, and nullsFirst.
	 */
	@IsTest
	private static void orderByFieldWithAscendingAndNullsFirstWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name, false, false)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should have NULLS FIRST');
		}
	}

	/**
	 * @description Tests orderBy with String field name and sortDescending flag ascending.
	 */
	@IsTest
	private static void orderByStringWithDescendingFalseWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME, false)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should default to NULLS FIRST');
		}
	}

	/**
	 * @description Tests orderBy with String field name and sortDescending flag descending.
	 */
	@IsTest
	private static void orderByStringWithDescendingTrueWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME, true)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should default to NULLS LAST for DESC');
		}
	}

	/**
	 * @description Tests orderBy with String field name, sortDescending, and nullsLast flags.
	 */
	@IsTest
	private static void orderByStringWithDescendingAndNullsLastWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME, true, true)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should have NULLS LAST');
		}
	}

	/**
	 * @description Tests orderBy with String field name, ascending direction, and nullsFirst.
	 */
	@IsTest
	private static void orderByStringWithAscendingAndNullsFirstWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME, false, false)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should have NULLS FIRST');
		}
	}

	/**
	 * @description Tests asValueSet with SObjectField.
	 */
	@IsTest
	private static void asValueSetWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<Object> values = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Text__c)
					.condition(Foobar__c.Id).equals(record.Id)
					.asValueSet(Foobar__c.Text__c);

			Assert.isFalse(values.isEmpty(), 'Should return values');
		}
	}

	/**
	 * @description Tests asValueSet with String field name.
	 */
	@IsTest
	private static void asValueSetWithStringWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<Object> values = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(FIELD_TEXT)
					.condition(Foobar__c.Id).equals(record.Id)
					.asValueSet(FIELD_TEXT);

			Assert.isFalse(values.isEmpty(), 'Should return values');
		}
	}

	/**
	 * @description Tests asStringSet with SObjectField.
	 */
	@IsTest
	private static void asStringSetWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<String> values = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Text__c)
					.condition(Foobar__c.Id).equals(record.Id)
					.asStringSet(Foobar__c.Text__c);

			Assert.isFalse(values.isEmpty(), 'Should return values');
		}
	}

	/**
	 * @description Tests asStringSet with String field name.
	 */
	@IsTest
	private static void asStringSetWithStringWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<String> values = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(FIELD_TEXT)
					.condition(Foobar__c.Id).equals(record.Id)
					.asStringSet(FIELD_TEXT);

			Assert.isFalse(values.isEmpty(), 'Should return values');
		}
	}

	/**
	 * @description Tests isCached method.
	 */
	@IsTest
	private static void isCachedWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id);

			query.toList();

			Assert.isFalse(query.isCached(), 'Should not be cached on first execution');
		}
	}

	/**
	 * @description Tests toQueryLocator method.
	 */
	@IsTest
	private static void toQueryLocatorWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Database.QueryLocator locator = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals(record.Name)
					.toQueryLocator();

			Assert.isNotNull(locator, 'Should return query locator');
		}
	}

	/**
	 * @description Tests getRandomItem method with mock.
	 */
	@IsTest
	private static void getRandomItemWorks()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> mockRecords = new List<Foobar__c>
			{
					TST_Factory.newFoobarWithName('Random Test')
			};
			QRY_Builder.setMock(Foobar__c.SObjectType, mockRecords);

			SObject random = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals('Random Test')
					.getRandomItem();

			Assert.isNotNull(random, 'Should return random item');

			QRY_Builder.clearMocks();
		}
	}

	/**
	 * @description Tests getRandomItems method with mock.
	 */
	@IsTest
	private static void getRandomItemsWorks()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> mockRecords = new List<Foobar__c>();
			for(Integer i = 0; i < 3; i++)
			{
				mockRecords.add(TST_Factory.newFoobarWithName('Random Items Test ' + i));
			}
			QRY_Builder.setMock(Foobar__c.SObjectType, mockRecords);

			List<SObject> randoms = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).contains('Random Items Test')
					.getRandomItems(3);

			Assert.isFalse(randoms.isEmpty(), 'Should return random items');

			QRY_Builder.clearMocks();
		}
	}

	/**
	 * @description Tests getRandomItems with null count returns empty list.
	 */
	@IsTest
	private static void getRandomItemsWithNullCountReturnsEmpty()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getRandomItems(null);

			Assert.isTrue(result.isEmpty(), 'Should return empty list for null count');
		}
	}

	/**
	 * @description Tests getRandomItems with zero count returns empty list.
	 */
	@IsTest
	private static void getRandomItemsWithZeroCountReturnsEmpty()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getRandomItems(0);

			Assert.isTrue(result.isEmpty(), 'Should return empty list for zero count');
		}
	}

	/**
	 * @description Tests getRandomItem returns null when no records.
	 */
	@IsTest
	private static void getRandomItemReturnsNullWhenNoRecords()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.setMock(Foobar__c.SObjectType, new List<Foobar__c>());

			SObject random = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals('NonExistent')
					.getRandomItem();

			Assert.isNull(random, 'Should return null when no records');

			QRY_Builder.clearMocks();
		}
	}

	/**
	 * @description Tests getRandomItems with real data exercises cursor-based fetch.
	 */
	@IsTest
	private static void getRandomItemsWorksWithCursorFetch()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(3);

			List<SObject> result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getRandomItems(2);

			Assert.isFalse(result.isEmpty(), 'Should return random items via cursor');
			Assert.isTrue(result.size() <= 2, 'Should not exceed requested count');
		}
	}

	/**
	 * @description Tests subselect method.
	 */
	@IsTest
	private static void subselectWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder childQuery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'Name'});

			String soql = QRY_Builder.selectFrom(Account.SObjectType)
					.fields(new List<String> {'Name'})
					.subselect(childQuery, 'Contacts')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT') && soql.containsIgnoreCase('FROM Account'), 'Should contain main query');
		}
	}

	/**
	 * @description Tests groupBy with SObjectField.
	 */
	@IsTest
	private static void groupByWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Picklist__c)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('GROUP BY'), 'Should contain GROUP BY clause');
		}
	}

	/**
	 * @description Tests groupBy with String field name.
	 */
	@IsTest
	private static void groupByWithStringFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(FIELD_PICKLIST)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('GROUP BY'), 'Should contain GROUP BY clause');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_PICKLIST), 'Should contain field name');
		}
	}

	/**
	 * @description Tests multi-field GROUP BY.
	 */
	@IsTest
	private static void groupByMultipleFieldsWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.groupBy(FIELD_TEXT)
					.count(FIELD_ID)
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY ' + FIELD_PICKLIST + ', ' + FIELD_TEXT), 'Should contain multi-field GROUP BY');
		}
	}

	/**
	 * @description Tests GROUP BY ROLLUP.
	 */
	@IsTest
	private static void groupByRollupWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.groupBy(FIELD_TEXT)
					.count(FIELD_ID)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY ROLLUP(' + FIELD_PICKLIST + ', ' + FIELD_TEXT + ')'), 'Should contain GROUP BY ROLLUP');
		}
	}

	/**
	 * @description Tests GROUP BY CUBE.
	 */
	@IsTest
	private static void groupByCubeWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.groupBy(FIELD_TEXT)
					.count(FIELD_ID)
					.cube()
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY CUBE(' + FIELD_PICKLIST + ', ' + FIELD_TEXT + ')'), 'Should contain GROUP BY CUBE');
		}
	}

	/**
	 * @description Tests GROUPING() function in SELECT with String field name.
	 */
	@IsTest
	private static void groupingFunctionWithStringWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.grouping(FIELD_PICKLIST)
					.count(FIELD_ID)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUPING(' + FIELD_PICKLIST + ')'), 'Should contain GROUPING function');
		}
	}

	/**
	 * @description Tests GROUPING() function in SELECT with SObjectField token.
	 */
	@IsTest
	private static void groupingFunctionWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(Foobar__c.Picklist__c)
					.grouping(Foobar__c.Picklist__c)
					.count(FIELD_ID)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUPING('), 'Should contain GROUPING function with SObjectField');
		}
	}

	/**
	 * @description Tests combined ROLLUP with GROUPING and aggregate.
	 */
	@IsTest
	private static void groupByRollupWithGroupingAndAggregateWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.groupBy(FIELD_TEXT)
					.grouping(FIELD_PICKLIST)
					.grouping(FIELD_TEXT)
					.sum(Foobar__c.NumberDecimal__c)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY ROLLUP('), 'Should contain ROLLUP');
			Assert.isTrue(soql.contains('GROUPING(' + FIELD_PICKLIST + ')'), 'Should contain GROUPING for picklist');
			Assert.isTrue(soql.contains('GROUPING(' + FIELD_TEXT + ')'), 'Should contain GROUPING for text');
			Assert.isTrue(soql.containsIgnoreCase('SUM('), 'Should contain SUM aggregate');
		}
	}

	/**
	 * @description Tests orderBy with String field name.
	 */
	@IsTest
	private static void orderByWithStringFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME).ascending()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort by string field ascending');
		}
	}

	/**
	 * @description Tests ascending/descending/nullsFirst/nullsLast with empty orderByFields.
	 */
	@IsTest
	private static void orderByModifiersIgnoredWhenEmpty()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.ascending()
					.descending()
					.nullsFirst()
					.nullsLast();

			String soql = query.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('ORDER BY'), 'Should not contain ORDER BY when no fields');
		}
	}

	/**
	 * @description Tests fields with null SObjectField list.
	 */
	@IsTest
	private static void fieldsWithNullSObjectFieldListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields((List<SObjectField>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT Id'), 'Should default to Id field');
		}
	}

	/**
	 * @description Tests fields with null String list.
	 */
	@IsTest
	private static void fieldsWithNullStringListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields((List<String>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT Id'), 'Should default to Id field');
		}
	}

	/**
	 * @description Tests addFields with null SObjectField list.
	 */
	@IsTest
	private static void addFieldsWithNullSObjectFieldListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields((List<SObjectField>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests addFields with null String list.
	 */
	@IsTest
	private static void addFieldsWithNullStringListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields((List<String>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests addField with null SObjectField.
	 */
	@IsTest
	private static void addFieldWithNullSObjectFieldHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField((SObjectField)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests addField with blank String.
	 */
	@IsTest
	private static void addFieldWithBlankStringHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField('')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests relatedField with blank String.
	 */
	@IsTest
	private static void relatedFieldWithBlankStringHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.relatedField('')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests relatedFields with null list.
	 */
	@IsTest
	private static void relatedFieldsWithNullListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.relatedFields(null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests usingScope method.
	 */
	@IsTest
	private static void usingScopeWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.usingScope(QRY_Builder.Scope.EVERYTHING)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('USING SCOPE everything'), 'Should contain USING SCOPE clause');
		}
	}

	/**
	 * @description Tests usingScope with all scope values.
	 */
	@IsTest
	private static void usingScopeAllValuesWork()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isTrue(QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.MINE).toSoql().containsIgnoreCase('SCOPE mine'), 'MINE scope');
			Assert.isTrue
					(
							QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.MY_TERRITORY).toSoql().containsIgnoreCase('SCOPE my_territory'),
							'MY_TERRITORY scope'
					);
			Assert.isTrue
					(
							QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.MY_TEAM_TERRITORY).toSoql().containsIgnoreCase('SCOPE my_team_territory'),
							'MY_TEAM_TERRITORY scope'
					);
			Assert.isTrue(QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.TEAM).toSoql().containsIgnoreCase('SCOPE team'), 'TEAM scope');
			Assert.isTrue(QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.DELEGATED).toSoql().containsIgnoreCase('SCOPE delegated'), 'DELEGATED scope');
		}
	}

	/**
	 * @description Tests withDataCategory().at() with a single category, and records the whole query text, so that the
	 * check on group and category names keeps a valid name unchanged.
	 */
	@IsTest
	private static void withDataCategoryAtSingleFilter()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').at('USA__c')
					.toSoql();

			Assert.areEqual('SELECT Id FROM ' + OBJECT_NAME + ' WITH DATA CATEGORY Geography__c AT USA__c', soql, 'Expected the data category text to stay as it is');
		}
	}

	/**
	 * @description Tests withDataCategory().at() with multiple categories, and records the whole query text, so that the
	 * check on group and category names keeps a list of valid names unchanged.
	 */
	@IsTest
	private static void withDataCategoryAtMultipleCategories()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').at(new List<String> {'USA__c', 'Canada__c'})
					.toSoql();

			Assert.areEqual
					(
							'SELECT Id FROM ' + OBJECT_NAME + ' WITH DATA CATEGORY Geography__c AT (USA__c, Canada__c)',
							soql,
							'Expected the list of categories to stay as it is'
					);
		}
	}

	/**
	 * @description Tests withDataCategory().above() operator.
	 */
	@IsTest
	private static void withDataCategoryAboveSingleFilter()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').above('USA__c')
					.toSoql();

			Assert.isTrue(soql.contains('Geography__c ABOVE USA__c'), 'Should contain ABOVE operator');
		}
	}

	/**
	 * @description Tests withDataCategory().below() operator.
	 */
	@IsTest
	private static void withDataCategoryBelowSingleFilter()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Product__c').below('Electronics__c')
					.toSoql();

			Assert.isTrue(soql.contains('Product__c BELOW Electronics__c'), 'Should contain BELOW operator');
		}
	}

	/**
	 * @description Tests withDataCategory().above() with multiple categories.
	 */
	@IsTest
	private static void withDataCategoryAboveMultipleCategories()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').above(new List<String> {'USA__c', 'Canada__c'})
					.toSoql();

			Assert.isTrue(soql.contains('Geography__c ABOVE (USA__c, Canada__c)'), 'Should contain ABOVE with parenthesized categories');
		}
	}

	/**
	 * @description Tests withDataCategory().aboveOrBelow() operator.
	 */
	@IsTest
	private static void withDataCategoryAboveOrBelowSingleFilter()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Audience__c').aboveOrBelow('External')
					.toSoql();

			Assert.isTrue(soql.contains('Audience__c ABOVE_OR_BELOW External'), 'Should contain ABOVE_OR_BELOW operator');
		}
	}

	/**
	 * @description Tests withDataCategory().below() with multiple categories.
	 */
	@IsTest
	private static void withDataCategoryBelowMultipleCategories()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Product__c').below(new List<String> {'Electronics__c', 'Clothing__c'})
					.toSoql();

			Assert.isTrue(soql.contains('Product__c BELOW (Electronics__c, Clothing__c)'), 'Should contain BELOW with parenthesized categories');
		}
	}

	/**
	 * @description Tests withDataCategory().aboveOrBelow() with multiple categories.
	 */
	@IsTest
	private static void withDataCategoryAboveOrBelowMultipleCategories()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Audience__c').aboveOrBelow(new List<String> {'External', 'Internal'})
					.toSoql();

			Assert.isTrue(soql.contains('Audience__c ABOVE_OR_BELOW (External, Internal)'), 'Should contain ABOVE_OR_BELOW with parenthesized categories');
		}
	}

	/**
	 * @description Tests multiple data category groups joined with AND.
	 */
	@IsTest
	private static void withDataCategoryMultipleGroups()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').at('USA__c')
					.withDataCategory('Product__c').below('Electronics__c')
					.toSoql();

			Assert.isTrue(soql.contains('WITH DATA CATEGORY Geography__c AT USA__c AND Product__c BELOW Electronics__c'),
					'Should contain multiple groups joined with AND');
		}
	}

	/**
	 * @description Tests withDataCategory throws on blank group name.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnBlankGroupName()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory('');
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests withDataCategory().at() throws on blank category name.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnBlankCategoryName()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory('Geography__c').at('');
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests withDataCategory().at() throws on empty category list.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnEmptyCategoryList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory('Geography__c').at(new List<String>());
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests withDataCategory().at() throws on null category list.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnNullCategoryList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory('Geography__c').at((List<String>)null);
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests withDataCategory throws on duplicate group.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnDuplicateGroup()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.withDataCategory('Geography__c').at('USA__c')
						.withDataCategory('Geography__c').below('Canada__c');
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
				Assert.isTrue(error.getMessage().contains('already been added'), 'Should mention duplicate group');
			}
		}
	}

	/**
	 * @description Tests duplicate group detection is case-insensitive.
	 */
	@IsTest
	private static void withDataCategoryDuplicateGroupIsCaseInsensitive()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.withDataCategory('Geography__c').at('USA__c')
						.withDataCategory('geography__c').below('Canada__c');
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests data category filters chain with conditions and ordering.
	 */
	@IsTest
	private static void withDataCategoryChainsWithConditions()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField('Title')
					.condition('PublishStatus').equals('Online')
					.withDataCategory('Geography__c').at('USA__c')
					.orderBy('Title').ascending()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('WHERE'), 'Should contain WHERE clause');
			Assert.isTrue(soql.contains('WITH DATA CATEGORY'), 'Should contain WITH DATA CATEGORY clause');
			Assert.isTrue(soql.containsIgnoreCase('ORDER BY'), 'Should contain ORDER BY clause');

			Integer whereIndex = soql.indexOf('WHERE');
			Integer dataCategoryIndex = soql.indexOf('WITH DATA CATEGORY');
			Integer orderByIndex = soql.toUpperCase().indexOf('ORDER BY');

			Assert.isTrue(whereIndex < dataCategoryIndex, 'WHERE should come before WITH DATA CATEGORY');
			Assert.isTrue(dataCategoryIndex < orderByIndex, 'WITH DATA CATEGORY should come before ORDER BY');
		}
	}

	/**
	 * @description Tests stripInaccessible with getPage.
	 */
	@IsTest
	private static void stripInaccessibleWithGetPageWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);

			QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.stripInaccessible()
					.getPage(1, 3);

			Assert.areEqual(3, result.records.size(), 'Should return records with strip inaccessible');
		}
	}

	/**
	 * @description Tests QueryPage totalPages returns 1 when pageSize is null.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneForNullPageSize()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 100;
			page.pageSize = null;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is null');
		}
	}

	/**
	 * @description Tests QueryPage totalPages returns 1 when pageSize is zero.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneForZeroPageSize()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 100;
			page.pageSize = 0;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is zero');
		}
	}

	/**
	 * @description Tests QueryPage totalPages returns 1 when pageSize is negative.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneForNegativePageSize()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 100;
			page.pageSize = -5;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is negative');
		}
	}

	/**
	 * @description Tests notInSetStrict with List of Objects succeeds for valid values.
	 */
	@IsTest
	private static void notInSetStrictListObjectsWorksForValidValues()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).notInSetStrict(new List<Object> {'Test1', 'Test2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NOT IN'), 'Should contain NOT IN clause');
		}
	}

	/**
	 * @description Tests notInSetStrict with Set of Objects succeeds for valid values.
	 */
	@IsTest
	private static void notInSetStrictSetObjectsWorksForValidValues()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).notInSetStrict(new Set<Object> {'Test1', 'Test2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NOT IN'), 'Should contain NOT IN clause');
		}
	}

	/**
	 * @description Tests notInSetStrict with List of SObjects with mixed null and valid records.
	 */
	@IsTest
	private static void notInSetStrictSObjectsWithMixedNullsWorks()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = new List<Foobar__c>
			{
					null,
					TST_Factory.newFoobarWithMockId(),
					null,
					TST_Factory.newFoobarWithMockId()
			};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSetStrict(records)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NOT IN'), 'Should contain NOT IN clause');
		}
	}

	/**
	 * @description Tests notInSetStrict with List of SObjects and explicit field extraction.
	 */
	@IsTest
	private static void notInSetStrictSObjectsWithFieldExtractionWorks()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = new List<Foobar__c>
			{
					TST_Factory.newFoobarWithMockId(),
					TST_Factory.newFoobarWithMockId()
			};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSetStrict(records, Foobar__c.Id)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NOT IN'), 'Should contain NOT IN clause');
		}
	}

	/**
	 * @description Tests subquery with limit in semi-join.
	 */
	@IsTest
	private static void semiJoinSubqueryWithLimitWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {SEL_Foobar.FIELD_LOOKUP})
					.withLimit(10);

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('LIMIT 10'), 'Should contain LIMIT in subquery');
		}
	}

	/**
	 * @description Tests subquery with offset in semi-join.
	 */
	@IsTest
	private static void semiJoinSubqueryWithOffsetWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {SEL_Foobar.FIELD_LOOKUP})
					.withOffset(5);

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('OFFSET 5'), 'Should contain OFFSET in subquery');
		}
	}

	/**
	 * @description Tests subquery with selectAllFields in semi-join.
	 */
	@IsTest
	private static void semiJoinSubqueryWithSelectAllFieldsWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.selectAllFields();

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should contain subquery');
			Assert.isTrue(soql.containsIgnoreCase('Id IN'), 'Should contain IN clause');
		}
	}

	/**
	 * @description Tests OR condition with trailing AND conditions adds final andGroup to orGroup.
	 */
	@IsTest
	private static void orConditionWithTrailingAndConditionsWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(SEL_Foobar.FIELD_TEXT).equals('Value1')
					.orCondition(SEL_Foobar.FIELD_EMAIL).equals('test@test.com')
					.andCondition(SEL_Foobar.FIELD_PHONE).equals('12345')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('OR'), 'Should contain OR');
			Assert.isTrue(soql.containsIgnoreCase(SEL_Foobar.FIELD_PHONE), 'Should contain trailing condition');
		}
	}

	/**
	 * @description Tests subquery with Foobar__c self-lookup and limit.
	 */
	@IsTest
	private static void semiJoinSubqueryWithFoobarLookupWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {SEL_Foobar.FIELD_LOOKUP})
					.withLimit(10)
					.withOffset(5);

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'Name'})
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('LIMIT 10'), 'Should contain LIMIT');
			Assert.isTrue(soql.containsIgnoreCase('OFFSET 5'), 'Should contain OFFSET');
		}
	}

	/**
	 * @description Tests fieldSet method with string name.
	 */
	@IsTest
	private static void fieldSetWithStringNameWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fieldSet(SEL_Foobar.FIELDSET_AUDIT)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('CreatedDate'), 'Should contain CreatedDate from fieldset');
		}
	}

	/**
	 * @description Tests fieldSet method with Schema.FieldSet.
	 */
	@IsTest
	private static void fieldSetWithSchemaFieldSetWorks()
	{
		System.runAs(getTestAdmin())
		{
			FieldSet aFieldSet = SObjectType.Foobar__c.fieldSets.getMap().get(SEL_Foobar.FIELDSET_AUDIT);

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fieldSet(aFieldSet)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('CreatedDate'), 'Should contain CreatedDate from fieldset');
		}
	}

	/**
	 * @description Tests that suppressPerformanceLogging sets the flag on the builder.
	 */
	@IsTest
	private static void suppressPerformanceLoggingSetsFlag()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.suppressPerformanceLogging();

			Assert.isTrue(builder.suppressPerformanceLog, 'suppressPerformanceLog should be true');
			Assert.isFalse(builder.forcePerformanceLog, 'forcePerformanceLog should be false');
		}
	}

	/**
	 * @description Tests that forcePerformanceLogging sets the flag on the builder.
	 */
	@IsTest
	private static void forcePerformanceLoggingSetsFlag()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.forcePerformanceLogging();

			Assert.isTrue(builder.forcePerformanceLog, 'forcePerformanceLog should be true');
			Assert.isFalse(builder.suppressPerformanceLog, 'suppressPerformanceLog should be false');
		}
	}

	/**
	 * @description Tests that logPerformanceIfSlowerThan sets the threshold.
	 */
	@IsTest
	private static void logPerformanceIfSlowerThanSetsThreshold()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.logPerformanceIfSlowerThan(500);

			Assert.areEqual(500, builder.performanceThresholdMs, 'performanceThresholdMs should be 500');
			Assert.isFalse(builder.suppressPerformanceLog, 'suppressPerformanceLog should be false');
			Assert.isFalse(builder.forcePerformanceLog, 'forcePerformanceLog should be false');
		}
	}

	/**
	 * @description Tests that performance settings are passed through to QueryParameters.
	 */
	@IsTest
	private static void passesPerformanceSettingsToParameters()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.suppressPerformanceLogging();

			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = builder.buildParameters(registry);

			Assert.isTrue(params.suppressPerformanceLogging, 'suppressPerformanceLogging should be passed through');
			Assert.isFalse(params.forcePerformanceLogging, 'forcePerformanceLogging should be passed through');
			Assert.isNull(params.customPerformanceThresholdMs, 'customPerformanceThresholdMs should be null');
		}
	}

	/**
	 * @description Tests end-to-end query execution with performance logging integration.
	 */
	@IsTest
	private static void executesQueryWithPerformanceLogging()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c testRecord = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(testRecord.Id)
					.suppressPerformanceLogging()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with performance logging configured');
		}
	}

	/**
	 * @description Tests that getSObjectType returns the SObjectType set on the builder.
	 */
	@IsTest
	private static void getSObjectTypeReturnsConfiguredType()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			Assert.areEqual(Foobar__c.SObjectType, builder.objectType, 'Should return Foobar__c SObjectType');
		}
	}

	/**
	 * @description Tests full QRY_Builder path with mixed bind condition and DateLiteral condition.
	 */
	@IsTest
	private static void shouldExecuteQueryWithBindAndDateLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c testRecord = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {FIELD_NAME})
					.condition(Foobar__c.Id).equals(testRecord.Id)
					.condition('CreatedDate').equals(new QRY_Condition.DateLiteral().today())
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record matching both bind and date literal');
			Assert.areEqual(testRecord.Id, results[0].Id, 'Should return correct record');
		}
	}

	/**
	 * @description Tests that the builder can be used as an IF_Queryable reference.
	 */
	@IsTest
	private static void builderImplementsQueryableInterface()
	{
		System.runAs(getTestAdmin())
		{
			IF_Queryable queryable = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			Assert.isNotNull(queryable.toList(), 'Should return list via interface');
			Assert.areEqual(0, queryable.count(), 'Should return count via interface');
			Assert.isFalse(queryable.exists(), 'Should return exists via interface');
		}
	}

	/**
	 * @description Tests that toAggregateList returns AggregateRow wrappers with typed accessors.
	 */
	@IsTest
	private static void toAggregateListReturnsWrappedResults()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Name)
					.toAggregateList();

			Assert.isFalse(rows.isEmpty(), 'Should return aggregate rows');
			Assert.isNotNull(rows[0].getInteger('count_Id'), 'Should return count as Integer');
			Assert.isNotNull(rows[0].getString(FIELD_NAME), 'Should return grouped field as String');
			Assert.isNotNull(rows[0].get('count_Id'), 'Should return raw Object value');
		}
	}

	/**
	 * @description Tests that QRY_Builder.setAggregateMock makes an aggregate query return the rows it was given, and
	 * that setting null for the type removes them, so the next aggregate query reads the database again.
	 */
	@IsTest
	private static void setAggregateMockAnswersAggregateQueries()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();
			QRY_Builder.setAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>> {new Map<String, Object> {MOCK_TOTAL_ALIAS => MOCK_TOTAL}});

			QRY_Builder.AggregateRow mockedRow = QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, MOCK_TOTAL_ALIAS).getFirstAggregate();
			Assert.areEqual(MOCK_TOTAL, mockedRow.getInteger(MOCK_TOTAL_ALIAS), 'Expected the registered row to answer the aggregate query');

			QRY_Builder.setAggregateMock(Foobar__c.SObjectType, null);

			QRY_Builder.AggregateRow realRow = QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, MOCK_TOTAL_ALIAS).getFirstAggregate();
			Assert.areEqual(1, realRow.getInteger(MOCK_TOTAL_ALIAS), 'Expected the database count of the one stored row once the mock is removed');
		}
	}

	/**
	 * @description Tests that a second QRY_Builder.setAggregateMock call replaces the rows set earlier for the type, as
	 * setMock replaces records, so an aggregate query returns only the rows of the second call.
	 * TST_Mock.registerAggregateRows adds to the rows instead.
	 */
	@IsTest
	private static void setAggregateMockReplacesTheRowsSetEarlier()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.setAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>> {new Map<String, Object> {MOCK_TOTAL_ALIAS => MOCK_TOTAL}});
			QRY_Builder.setAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>> {new Map<String, Object> {MOCK_TOTAL_ALIAS => REPLACEMENT_MOCK_TOTAL}});

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, MOCK_TOTAL_ALIAS).toAggregateList();

			Assert.areEqual(1, rows.size(), 'Expected only the rows of the second call');
			Assert.areEqual(REPLACEMENT_MOCK_TOTAL, rows[0].getInteger(MOCK_TOTAL_ALIAS), 'Expected the row of the second call to answer');
		}
	}

	/**
	 * @description Tests that every way of reading records refuses an aggregate query that registered rows answered,
	 * and points to toAggregateList. A real run of the same query would return AggregateResult rows, so returning no
	 * records would hide the mistake. No Foobar__c row is stored, so the table is empty: getRandomItems must refuse
	 * the query before it counts the rows, or it would return an empty list without an error.
	 */
	@IsTest
	private static void shouldThrowWhenAMockedAggregateQueryIsReadAsRecords()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.setAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>> {new Map<String, Object> {MOCK_TOTAL_ALIAS => MOCK_TOTAL}});

			for(String recordRead : RECORD_READS)
			{
				try
				{
					readMockedAggregateQueryAsRecords(recordRead);
					Assert.fail('Expected ' + recordRead + ' to refuse a mocked aggregate query');
				}
				catch(Exception error)
				{
					String message = error.getMessage();
					Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Expected ' + recordRead + ' to throw IllegalStateException: ' + message);
					Assert.isTrue(message.contains(AGGREGATE_READ_HINT), 'Expected the error from ' + recordRead + ' to name toAggregateList: ' + message);
				}
			}
		}
	}

	/**
	 * @description Tests that getRandomItems still reads records for a query without aggregate functions, when
	 * aggregate rows are registered for the same object type. Aggregate rows only answer aggregate queries, so this
	 * query reads the one stored row from the database.
	 */
	@IsTest
	private static void getRandomItemsReadsRecordsWhenOnlyAggregateRowsAreRegistered()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c storedRow = TST_Factory.insertFoobar();
			QRY_Builder.setAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>> {new Map<String, Object> {MOCK_TOTAL_ALIAS => MOCK_TOTAL}});

			List<SObject> items = QRY_Builder.selectFrom(Foobar__c.SObjectType).getRandomItems(1);

			Assert.areEqual(1, items.size(), 'Expected the row query to read the one stored row');
			Assert.areEqual(storedRow.Id, items[0].Id, 'Expected the stored row to be returned');
		}
	}

	/**
	 * @description Tests that a registered row matches an alias without regard to case, as a real AggregateResult does,
	 * and that a row already read keeps its own copy of the values when the registered map is changed afterwards.
	 */
	@IsTest
	private static void aggregateRowMatchesAliasesWithoutRegardToCase()
	{
		System.runAs(getTestAdmin())
		{
			Map<String, Object> registeredValues = new Map<String, Object> {MIXED_CASE_ALIAS => MOCK_TOTAL};

			QRY_Builder.AggregateRow row = readMockedAggregateRow(registeredValues);
			registeredValues.put(MIXED_CASE_ALIAS, CHANGED_TOTAL);

			Assert.areEqual(MOCK_TOTAL, row.getInteger(MIXED_CASE_ALIAS.toLowerCase()), 'Expected the lower-case alias to read the registered value');
			Assert.areEqual(MOCK_TOTAL, row.get(MIXED_CASE_ALIAS.toUpperCase()), 'Expected the upper-case alias to read the registered value');
		}
	}

	/**
	 * @description Tests that reading an alias the registered row does not hold throws IllegalArgumentException that
	 * names the alias and the aliases the row does hold, as a real AggregateResult throws on an unknown alias. A null
	 * would hide a spelling mistake in the test.
	 */
	@IsTest
	private static void aggregateRowThrowsForAnAliasThatWasNotSet()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.AggregateRow row = readMockedAggregateRow(new Map<String, Object> {MOCK_TOTAL_ALIAS => MOCK_TOTAL});

			try
			{
				row.getInteger(MISSPELT_ALIAS);
				Assert.fail('Expected an alias that was not set to be refused');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected IllegalArgumentException: ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains(MISSPELT_ALIAS), 'Expected the error to name the alias that was read: ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains(MOCK_TOTAL_ALIAS), 'Expected the error to name the alias that was set: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that an alias registered with a null value reads as null from every getter, without an error,
	 * as a real sum over no rows does.
	 */
	@IsTest
	private static void aggregateRowReturnsNullForAKeyHoldingNull()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.AggregateRow row = readMockedAggregateRow(new Map<String, Object> {MOCK_TOTAL_ALIAS => null});

			Assert.isNull(row.get(MOCK_TOTAL_ALIAS), 'Expected get to return null');
			Assert.isNull(row.getDecimal(MOCK_TOTAL_ALIAS), 'Expected getDecimal to return null');
			Assert.isNull(row.getInteger(MOCK_TOTAL_ALIAS), 'Expected getInteger to return null');
			Assert.isNull(row.getLong(MOCK_TOTAL_ALIAS), 'Expected getLong to return null');
			Assert.isNull(row.getString(MOCK_TOTAL_ALIAS), 'Expected getString to return null');
			Assert.isNull(row.getId(MOCK_TOTAL_ALIAS), 'Expected getId to return null');
			Assert.isNull(row.getDate(MOCK_TOTAL_ALIAS), 'Expected getDate to return null');
		}
	}

	/**
	 * @description Tests that the number getters of a registered row convert a whole number between Integer, Long,
	 * Double and Decimal, so a test may write a whole number in any of these types. A number with a fraction is not
	 * cut down to a whole number: getInteger refuses it with a TypeException, as a real row does, and getDecimal reads
	 * it unchanged. getDate accepts only a Date.
	 */
	@IsTest
	private static void aggregateRowConvertsNumbersBetweenTypes()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.AggregateRow row = readMockedAggregateRow(new Map<String, Object>
			{
					INTEGER_KEY => INTEGER_VALUE,
					DECIMAL_KEY => DECIMAL_VALUE,
					LONG_KEY => LONG_VALUE,
					DOUBLE_KEY => DOUBLE_VALUE,
					FRACTION_KEY => FRACTION_VALUE
			});

			Long integerValueAsLong = INTEGER_VALUE;

			Assert.areEqual(Decimal.valueOf(INTEGER_VALUE), row.getDecimal(INTEGER_KEY), 'Expected an Integer to be read as a Decimal');
			Assert.areEqual(DECIMAL_VALUE.intValue(), row.getInteger(DECIMAL_KEY), 'Expected a whole Decimal to be read as an Integer');
			Assert.areEqual(integerValueAsLong, row.getLong(INTEGER_KEY), 'Expected an Integer to be read as a Long');
			Assert.areEqual(LONG_VALUE.intValue(), row.getInteger(LONG_KEY), 'Expected a Long to be read as an Integer');
			Assert.areEqual(DOUBLE_VALUE.intValue(), row.getInteger(DOUBLE_KEY), 'Expected a whole Double to be read as an Integer');
			Assert.areEqual(DOUBLE_VALUE.longValue(), row.getLong(DOUBLE_KEY), 'Expected a whole Double to be read as a Long');
			Assert.areEqual(Decimal.valueOf(DOUBLE_VALUE), row.getDecimal(DOUBLE_KEY), 'Expected a Double to be read as a Decimal');
			Assert.areEqual(FRACTION_VALUE, row.getDecimal(FRACTION_KEY), 'Expected a number with a fraction to be read unchanged as a Decimal');
			try
			{
				row.getInteger(FRACTION_KEY);
				Assert.fail('Expected getInteger to refuse a number with a fraction');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, TypeException.class, 'Expected TypeException for a number with a fraction: ' + error.getMessage());
			}
			try
			{
				row.getDate(INTEGER_KEY);
				Assert.fail('Expected getDate to refuse a number');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, TypeException.class, 'Expected TypeException: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that getId on a registered row accepts only an Id. A number is refused with the same
	 * TypeException a real row throws, as getDate refuses a number.
	 */
	@IsTest
	private static void aggregateRowGetIdRefusesAValueThatIsNotAnId()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.AggregateRow row = readMockedAggregateRow(new Map<String, Object> {INTEGER_KEY => INTEGER_VALUE});

			try
			{
				row.getId(INTEGER_KEY);
				Assert.fail('Expected getId to refuse a number');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, TypeException.class, 'Expected TypeException: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that a registered row with two aliases that differ only in case, such as Total and total, is
	 * refused with an IllegalArgumentException that names both. A real aggregate row cannot hold both, because a query
	 * cannot use the same alias twice. Keeping only one of the values would let a test pass that no real query could
	 * produce.
	 */
	@IsTest
	private static void aggregateRowRefusesAliasesThatDifferOnlyInCase()
	{
		System.runAs(getTestAdmin())
		{
			String capitalisedAlias = MOCK_TOTAL_ALIAS.capitalize();

			try
			{
				readMockedAggregateRow(new Map<String, Object> {capitalisedAlias => MOCK_TOTAL, MOCK_TOTAL_ALIAS => CHANGED_TOTAL});
				Assert.fail('Expected a row with two aliases that differ only in case to be refused');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected IllegalArgumentException: ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains(capitalisedAlias), 'Expected the error to name the alias ' + capitalisedAlias + ': ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains(MOCK_TOTAL_ALIAS), 'Expected the error to name the alias ' + MOCK_TOTAL_ALIAS + ': ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that an aggregate query on a type that has record mocks but no aggregate rows throws
	 * IllegalStateException that names TST_Mock.registerAggregateRows. Record mocks never answer an aggregate query.
	 */
	@IsTest
	private static void shouldThrowWhenRecordMocksExistButNoAggregateRows()
	{
		System.runAs(getTestAdmin())
		{
			TST_Mock.register(Foobar__c.SObjectType, TST_Factory.getFoobarBuilder().withoutInsertion(true).buildList());

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, MOCK_TOTAL_ALIAS).toAggregateList();
				Assert.fail('Expected an aggregate query with record mocks only to be refused');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Expected IllegalStateException: ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains(REGISTER_AGGREGATE_ROWS_HINT), 'Expected the error to name registerAggregateRows: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Runs a count grouped by name on Foobar__c and reads the result through the specified record read.
	 * The tests call it after registering aggregate rows, so the read meets the mocked aggregate result.
	 *
	 * @param recordRead The name of the QRY_Builder.Builder method to read with, one of RECORD_READS.
	 */
	private static void readMockedAggregateQueryAsRecords(String recordRead)
	{
		QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, MOCK_TOTAL_ALIAS).groupBy(Foobar__c.Name);
		switch on recordRead
		{
			when 'toList'
			{
				builder.toList();
			}
			when 'getFirst'
			{
				builder.getFirst();
			}
			when 'getPage'
			{
				builder.getPage(1, MOCK_PAGE_SIZE);
			}
			when 'getRandomItems'
			{
				builder.getRandomItems(1);
			}
			when else
			{
				builder.asMap();
			}
		}
	}

	/**
	 * @description Registers one aggregate row for Foobar__c through QRY_Builder.setAggregateMock and reads it back
	 * through getFirstAggregate.
	 *
	 * @param values The row to register: each key is an alias, each value what it holds.
	 *
	 * @return The row the aggregate query returned.
	 */
	private static QRY_Builder.AggregateRow readMockedAggregateRow(Map<String, Object> values)
	{
		QRY_Builder.setAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>> {values});
		return QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, MOCK_TOTAL_ALIAS).getFirstAggregate();
	}

	/**
	 * @description Tests that getFirstAggregate returns a single AggregateRow for scalar aggregates.
	 */
	@IsTest
	private static void getFirstAggregateReturnsSingleRow()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.NumberInteger__c, 10)
					.build();

			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.sum(Foobar__c.NumberInteger__c)
					.getFirstAggregate();

			Assert.isNotNull(row, 'Should return aggregate row');
			Assert.isNotNull(row.getDecimal('sum_' + SEL_Foobar.FIELD_INTEGER), 'Should return SUM as Decimal');
		}
	}

	/**
	 * @description Tests that getFirstAggregate returns null when GROUP BY yields no results.
	 */
	@IsTest
	private static void getFirstAggregateReturnsNullForEmptyResults()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Name)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.getFirstAggregate();

			Assert.isNull(row, 'Should return null when no results');
		}
	}

	/**
	 * @description Tests that AggregateRow getDate returns a Date value from MIN aggregate.
	 */
	@IsTest
	private static void aggregateRowGetDateReturnsDateValue()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Date__c, Date.today())
					.build();

			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.min(Foobar__c.Date__c)
					.getFirstAggregate();

			Assert.isNotNull(row, 'Should return aggregate row');
			Assert.areEqual(Date.today(), row.getDate('min_' + Foobar__c.Date__c.getDescribe().getName()), 'Should return Date value');
		}
	}

	/**
	 * @description Tests that AggregateRow getId returns an Id value from a grouped field.
	 */
	@IsTest
	private static void aggregateRowGetIdReturnsIdValue()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy('CreatedById')
					.toAggregateList();

			Assert.isFalse(rows.isEmpty(), 'Should return aggregate rows');
			Assert.isNotNull(rows[0].getId('CreatedById'), 'Should return Id value');
		}
	}

	/**
	 * @description Tests that AggregateRow getLong returns a Long value from a COUNT aggregate.
	 */
	@IsTest
	private static void aggregateRowGetLongReturnsLongValue()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.getFirstAggregate();

			Assert.isNotNull(row, 'Should return aggregate row');
			Assert.isNotNull(row.getLong('count_Id'), 'Should return count as Long');
		}
	}

	/**
	 * @description Tests that getLong returns null for a null aggregate value.
	 */
	@IsTest
	private static void aggregateRowGetLongReturnsNullForNullValue()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.sum(Foobar__c.NumberInteger__c)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.getFirstAggregate();

			Assert.isNotNull(row, 'Should return aggregate row even with no matches');
			Assert.isNull(row.getLong('sum_' + Foobar__c.NumberInteger__c.getDescribe().getName()), 'Should return null for null aggregate');
		}
	}

	/**
	 * @description Tests that registerMockContextClass via QRY_Builder delegates to QRY_Engine.
	 */
	@IsTest
	private static void registerMockContextClassViaBuilderEnablesFiltering()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c matchingMock = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.NumberInteger__c, 10)
					.withoutInsertion(true).build();
			Foobar__c nonMatchingMock = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.NumberInteger__c, 20)
					.withoutInsertion(true).build();

			QRY_Builder.registerMockContextClass(Foobar__c.SObjectType, UTIL_FormulaContext.FoobarContext.class.getName());
			QRY_Builder.setMock(Foobar__c.SObjectType, new List<Foobar__c> {matchingMock, nonMatchingMock});

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.NumberInteger__c).equals(10)
					.toList();

			Assert.areEqual(1, results.size(), 'Should filter mocks using registered context class');
		}
	}

	/**
	 * @description Tests that a subquery with a WHERE condition generates correct SOQL.
	 */
	@IsTest
	private static void semiJoinSubqueryWithConditionWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.OwnerId)
					.condition(Foobar__c.Name).equals('Test');

			String soql = QRY_Builder.selectFrom(User.SObjectType)
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('WHERE'), 'Should contain WHERE in subquery');
			Assert.isTrue(soql.containsIgnoreCase('Id IN'), 'Should contain IN clause');
		}
	}

	/**
	 * @description Tests that isIn(records, field) matches rows on a Date key field. A source record whose key is blank does
	 * not break the query, and it does not match a stored row whose Date is blank either.
	 */
	@IsTest
	private static void isInRecordsMatchesDateKeyField()
	{
		System.runAs(getTestAdmin())
		{
			Date firstDate = Date.newInstance(2026, 3, 1);
			Date secondDate = Date.newInstance(2026, 3, 2);
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, secondDate, Date.newInstance(2026, 3, 3), null});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, secondDate, null});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Date__c).isIn(sources, Foobar__c.Date__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id, stored[1].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected the two rows whose Date matches a source record');
		}
	}

	/**
	 * @description Tests that notInSet(records, field) excludes rows on a Date key field.
	 */
	@IsTest
	private static void notInSetRecordsExcludesDateKeyField()
	{
		System.runAs(getTestAdmin())
		{
			Date firstDate = Date.newInstance(2026, 3, 1);
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, Date.newInstance(2026, 3, 2)});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Date__c).notInSet(sources, Foobar__c.Date__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[1].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row whose Date is not in the source records');
		}
	}

	/**
	 * @description Tests that isIn(records, field) matches rows on a Datetime key field.
	 */
	@IsTest
	private static void isInRecordsMatchesDatetimeKeyField()
	{
		System.runAs(getTestAdmin())
		{
			Datetime firstMoment = Datetime.newInstanceGmt(2026, 3, 1, 9, 30, 0);
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Datetime__c, new List<Object> {firstMoment, Datetime.newInstanceGmt(2026, 3, 1, 10, 30, 0)});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Datetime__c, new List<Object> {firstMoment});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Datetime__c).isIn(sources, Foobar__c.Datetime__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected the row whose Datetime matches the source record');
		}
	}

	/**
	 * @description Tests that isIn(records, field) matches rows on an Integer-style number key field.
	 */
	@IsTest
	private static void isInRecordsMatchesIntegerKeyField()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.NumberInteger__c, new List<Object> {7, 8, 9});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.NumberInteger__c, new List<Object> {7, 9});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.NumberInteger__c).isIn(sources, Foobar__c.NumberInteger__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id, stored[2].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected the two rows whose number matches');
		}
	}

	/**
	 * @description Tests that isIn(records, field) matches rows on a Decimal key field holding a large whole number.
	 */
	@IsTest
	private static void isInRecordsMatchesDecimalKeyField()
	{
		System.runAs(getTestAdmin())
		{
			Decimal largeValue = Decimal.valueOf('123456789012');
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.NumberDecimal__c, new List<Object> {largeValue, 5});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.NumberDecimal__c, new List<Object> {largeValue});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.NumberDecimal__c).isIn(sources, Foobar__c.NumberDecimal__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected the row whose Decimal matches');
		}
	}

	/**
	 * @description Tests that isIn(records, field) matches rows on a fractional key field holding a very small value, which
	 * Apex renders in scientific notation when it turns the Decimal into text.
	 */
	@IsTest
	private static void isInRecordsMatchesSmallFractionalKeyField()
	{
		System.runAs(getTestAdmin())
		{
			Decimal smallValue = Decimal.valueOf('0.000000001');
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Percent__c, new List<Object> {smallValue, 0.5});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Percent__c, new List<Object> {smallValue});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Percent__c).isIn(sources, Foobar__c.Percent__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected the row whose small fractional value matches');
		}
	}

	/**
	 * @description Tests that isIn(records, field) matches rows on a checkbox key field.
	 */
	@IsTest
	private static void isInRecordsMatchesBooleanKeyField()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Checkbox__c, new List<Object> {true, false});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Checkbox__c, new List<Object> {true});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Checkbox__c).isIn(sources, Foobar__c.Checkbox__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row whose checkbox is ticked');
		}
	}

	/**
	 * @description Tests that whole numbers given as Decimal values, such as 7.0, match rows on a number field with no
	 * decimal places.
	 */
	@IsTest
	private static void isInValueListMatchesWholeDecimalsOnAnIntegerField()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.NumberInteger__c, new List<Object> {7, 8, 9});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.NumberInteger__c).isIn(new List<Object> {7.0, 9.0})
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id, stored[2].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected the rows holding 7 and 9');
		}
	}

	/**
	 * @description Tests that a list of counts after havingCountOf works whether the count is given as 2 or as 2.0. A count
	 * column accepts only a bound list of Integer values, so both forms must be bound as Integer values.
	 */
	@IsTest
	private static void havingCountListBindsAsIntegers()
	{
		System.runAs(getTestAdmin())
		{
			Date sharedDate = Date.newInstance(2026, 3, 1);
			Date singleDate = Date.newInstance(2026, 3, 2);
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {sharedDate, sharedDate, singleDate});

			List<QRY_Builder.AggregateRow> integerRows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Date__c)
					.condition(Foobar__c.Id).isIn(stored)
					.havingCountOf(Foobar__c.Id).isIn(new List<Object> {2})
					.toAggregateList();
			List<QRY_Builder.AggregateRow> wholeDecimalRows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Date__c)
					.condition(Foobar__c.Id).isIn(stored)
					.havingCountOf(Foobar__c.Id).isIn(new List<Object> {2.0})
					.toAggregateList();

			String dateAlias = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Date__c);
			Assert.areEqual(1, integerRows.size(), 'Expected one group with two rows when the count is given as 2');
			Assert.areEqual(sharedDate, integerRows[0].getDate(dateAlias), 'Expected the group of the shared date');
			Assert.areEqual(1, wholeDecimalRows.size(), 'Expected one group with two rows when the count is given as 2.0');
			Assert.areEqual(sharedDate, wholeDecimalRows[0].getDate(dateAlias), 'Expected the group of the shared date');
		}
	}

	/**
	 * @description Tests that a count list holding a number too large for an Integer makes the query fail with the
	 * platform's QueryException.
	 */
	@IsTest
	private static void havingCountListAboveIntegerRangeThrowsQueryException()
	{
		System.runAs(getTestAdmin())
		{
			Long firstNumberAboveIntegerRange = 2147483648L;
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {Date.newInstance(2026, 3, 1)});
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Date__c)
					.condition(Foobar__c.Id).isIn(stored)
					.havingCountOf(Foobar__c.Id).isIn(new List<Object> {firstNumberAboveIntegerRange});

			try
			{
				query.toAggregateList();
				Assert.fail('Expected a query error for a count above the Integer range');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected the platform query error: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that a list of years compared with CALENDAR_YEAR of a date field returns the rows of that year. The
	 * CALENDAR_YEAR column accepts only a bound list of Integer values.
	 */
	@IsTest
	private static void calendarYearListBindsAsIntegers()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {Date.newInstance(2026, 3, 1), Date.newInstance(2025, 3, 1)});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(QRY_Function.calendarYear(Foobar__c.Date__c)).isIn(new List<Object> {2026})
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row dated in 2026');
		}
	}

	/**
	 * @description Tests that a list of whole numbers after havingSumOf finds the group whose sum is in the list, whether
	 * the number is given as 7 or as 7.0. Both forms are bound as a list of Integer values, and a SUM column accepts that
	 * list.
	 */
	@IsTest
	private static void havingSumListOfWholeNumbersFindsTheMatchingGroup()
	{
		System.runAs(getTestAdmin())
		{
			Date sharedDate = Date.newInstance(2026, 3, 1);
			Date singleDate = Date.newInstance(2026, 3, 2);
			List<Foobar__c> stored = new List<Foobar__c>
			{
					(Foobar__c)TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, sharedDate).withOverride(Foobar__c.NumberInteger__c, 3).build(),
					(Foobar__c)TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, sharedDate).withOverride(Foobar__c.NumberInteger__c, 4).build(),
					(Foobar__c)TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, singleDate).withOverride(Foobar__c.NumberInteger__c, 5).build()
			};

			List<QRY_Builder.AggregateRow> integerRows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Date__c)
					.condition(Foobar__c.Id).isIn(stored)
					.havingSumOf(Foobar__c.NumberInteger__c).isIn(new List<Object> {7})
					.toAggregateList();
			List<QRY_Builder.AggregateRow> wholeDecimalRows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Date__c)
					.condition(Foobar__c.Id).isIn(stored)
					.havingSumOf(Foobar__c.NumberInteger__c).isIn(new List<Object> {7.0})
					.toAggregateList();

			String dateAlias = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Date__c);
			Assert.areEqual(1, integerRows.size(), 'Expected one group whose sum is 7 when the sum is given as 7');
			Assert.areEqual(sharedDate, integerRows[0].getDate(dateAlias), 'Expected the group of the shared date');
			Assert.areEqual(1, wholeDecimalRows.size(), 'Expected one group whose sum is 7 when the sum is given as 7.0');
			Assert.areEqual(sharedDate, wholeDecimalRows[0].getDate(dateAlias), 'Expected the group of the shared date');
		}
	}

	/**
	 * @description Tests that isIn(records, field) matches nothing when every source record has a blank key, even though a
	 * stored row also has a blank key.
	 */
	@IsTest
	private static void isInRecordsWithOnlyBlankKeysMatchesNothing()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {Date.newInstance(2026, 3, 1), null});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {null});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Date__c).isIn(sources, Foobar__c.Date__c)
					.toList();

			Assert.isTrue(matched.isEmpty(), 'Expected no rows when every source record has a blank key: ' + matched);
		}
	}

	/**
	 * @description Tests that notInSet(records, field) keeps a source record with a blank key: the row matching the other
	 * source is left out, and so is the stored row whose field is blank.
	 */
	@IsTest
	private static void notInSetRecordsWithABlankKeyLeavesOutBlankRows()
	{
		System.runAs(getTestAdmin())
		{
			Date firstDate = Date.newInstance(2026, 3, 1);
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, Date.newInstance(2026, 3, 2), null});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, null});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Date__c).notInSet(sources, Foobar__c.Date__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[1].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row with the second date');
		}
	}

	/**
	 * @description Tests that notInSet(records, field) still adds a NOT IN condition when every source record has a blank
	 * key, so only the stored rows whose field has a value come back.
	 */
	@IsTest
	private static void notInSetRecordsWithOnlyBlankKeysReturnsRowsWithAValue()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {Date.newInstance(2026, 3, 1), null});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {null});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Date__c).notInSet(sources, Foobar__c.Date__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row whose date is set');
		}
	}

	/**
	 * @description Tests that isInStrict(records, field) ignores a source record with a blank key, in the same way as
	 * isIn(records, field): it does not match the stored row whose key is blank.
	 */
	@IsTest
	private static void isInStrictRecordsSkipsBlankKeys()
	{
		System.runAs(getTestAdmin())
		{
			Date firstDate = Date.newInstance(2026, 3, 1);
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, null});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, null});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Date__c).isInStrict(sources, Foobar__c.Date__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row matching the first date');
		}
	}

	/**
	 * @description Tests that notInSetStrict(records, field) keeps a source record with a blank key, in the same way as
	 * notInSet(records, field): the row matching the other source is left out, and so is the stored row whose field is
	 * blank.
	 */
	@IsTest
	private static void notInSetStrictRecordsWithABlankKeyLeavesOutBlankRows()
	{
		System.runAs(getTestAdmin())
		{
			Date firstDate = Date.newInstance(2026, 3, 1);
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, Date.newInstance(2026, 3, 2), null});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {firstDate, null});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Date__c).notInSetStrict(sources, Foobar__c.Date__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[1].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row with the second date');
		}
	}

	/**
	 * @description Tests that isInStrict(records, field) throws an error when every source record has a blank key, because
	 * no record gives a value to match.
	 */
	@IsTest
	private static void isInStrictRecordsWithOnlyBlankKeysThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {null, null});

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).condition(Foobar__c.Date__c).isInStrict(sources, Foobar__c.Date__c);
				Assert.fail('Expected an IllegalArgumentException when every source record has a blank key');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got: ' + error);
				Assert.areEqual('Records list contains no valid records', error.getMessage(), 'Expected the message that says no record has a value');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict(records, field) does not throw when every source record has a blank key. It
	 * adds a NOT IN condition over the blank keys, so only the stored rows whose field has a value come back.
	 */
	@IsTest
	private static void notInSetStrictRecordsWithOnlyBlankKeysReturnsRowsWithAValue()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> stored = insertFoobarsWith(Foobar__c.Date__c, new List<Object> {Date.newInstance(2026, 3, 1), null});
			List<Foobar__c> sources = buildUnsavedFoobarsWith(Foobar__c.Date__c, new List<Object> {null, null});

			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(stored)
					.condition(Foobar__c.Date__c).notInSetStrict(sources, Foobar__c.Date__c)
					.toList();

			Assert.areEqual(new Set<Id> {stored[0].Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row whose date is set');
		}
	}

	/**
	 * @description Tests that HAVING values reach the engine as bind variables: the query text carries a bind reference and
	 * the value travels only in the bind map, so a value can never change the query's shape.
	 */
	@IsTest
	private static void havingValuesAreBoundNotPasted()
	{
		System.runAs(getTestAdmin())
		{
			String hostileValue = '0\' OR COUNT(Id) > \'0';
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Name)
					.havingSumOf(Foobar__c.NumberInteger__c).greaterThan(5)
					.havingCount().equals(hostileValue)
					.havingCount().isIn(new List<Object> {'1', hostileValue});

			QRY_Engine.QueryParameters parameters = query.buildParameters(new QRY_BindRegistry());

			String havingClause = parameters.queryString.substringAfter('HAVING ');
			String sumReference = 'SUM(' + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.NumberInteger__c) + ') > :bv';
			Assert.isTrue(havingClause.contains(sumReference), 'Expected the SUM value as a bind reference: ' + havingClause);
			Assert.isFalse(parameters.queryString.contains('OR COUNT(Id)'), 'Expected the hostile value to stay out of the query text: ' + parameters.queryString);
			Assert.isTrue(parameters.bindMap.values().contains(5), 'Expected the SUM value in the bind map');
			Assert.isTrue(parameters.bindMap.values().contains(hostileValue), 'Expected the hostile value verbatim in the bind map');
			Assert.isTrue(parameters.bindMap.values().contains(new List<String> {'1', hostileValue}), 'Expected the IN values bound as one text list');
		}
	}

	/**
	 * @description Tests that a list mixing an Id and text, which is written into the query as literals rather than bound,
	 * keeps a hostile text value inside its quotes: it matches only the row whose Name is exactly that text.
	 */
	@IsTest
	private static void mixedLiteralListKeepsHostileTextQuoted()
	{
		System.runAs(getTestAdmin())
		{
			String hostileName = 'a\\\' OR Name != \'';
			Foobar__c target = (Foobar__c)TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, hostileName).build();
			Foobar__c bystander = (Foobar__c)TST_Factory.getFoobarBuilder().build();

			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(new List<Foobar__c> {target, bystander})
					.condition(Foobar__c.Name).isIn(new List<Object> {bystander.Id, hostileName});

			String nameClause = query.buildParameters(new QRY_BindRegistry()).queryString.substringAfter('Name IN ');
			String expectedLiterals = '(\'' + bystander.Id + '\',\'' + String.escapeSingleQuotes(hostileName) + '\')';
			Assert.isTrue(nameClause.startsWith(expectedLiterals), 'Expected the mixed list as escaped literals: ' + nameClause);

			List<Foobar__c> matched = query.toList();

			Assert.areEqual(new Set<Id> {target.Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected only the row whose Name is the hostile text');
		}
	}

	/**
	 * @description Tests that a HAVING condition with a bound number value runs and filters groups.
	 */
	@IsTest
	private static void havingBoundValueFiltersGroups()
	{
		System.runAs(getTestAdmin())
		{
			Date smallGroupDate = Date.newInstance(2026, 3, 1);
			Date largeGroupDate = Date.newInstance(2026, 3, 2);
			List<Foobar__c> stored = new List<Foobar__c>
			{
					(Foobar__c)TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, smallGroupDate).withOverride(Foobar__c.NumberInteger__c, 3).build(),
					(Foobar__c)TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, largeGroupDate).withOverride(Foobar__c.NumberInteger__c, 40).build()
			};

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Date__c)
					.condition(Foobar__c.Id).isIn(stored)
					.havingSumOf(Foobar__c.NumberInteger__c).greaterThan(10)
					.toAggregateList();

			Assert.areEqual(1, rows.size(), 'Expected only the group whose SUM exceeds the bound value');
			Assert.areEqual(largeGroupDate, rows[0].getDate(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Date__c)), 'Expected the group of the row holding 40');
		}
	}

	/**
	 * @description Inserts one Foobar__c per value, with the given field set to that value.
	 *
	 * @param field The field to set
	 * @param values One value per record
	 *
	 * @return The inserted records, in the order of the values
	 */
	private static List<Foobar__c> insertFoobarsWith(SObjectField field, List<Object> values)
	{
		List<Foobar__c> records = new List<Foobar__c>();
		for(Object value : values)
		{
			records.add((Foobar__c)TST_Factory.getFoobarBuilder().withOverride(field, value).build());
		}
		return records;
	}

	/**
	 * @description Builds one uncommitted Foobar__c per value, with the given field set to that value.
	 *
	 * @param field The field to set
	 * @param values One value per record
	 *
	 * @return The uncommitted records, in the order of the values
	 */
	private static List<Foobar__c> buildUnsavedFoobarsWith(SObjectField field, List<Object> values)
	{
		List<Foobar__c> records = new List<Foobar__c>();
		for(Object value : values)
		{
			records.add((Foobar__c)TST_Factory.getFoobarBuilder().withOverride(field, value).withoutInsertion().build());
		}
		return records;
	}

	/**
	 * @description Proves that every method that starts a condition refuses a text that is not a field name. Each text
	 * would change which rows the query returns: one adds an OR that matches every row, one closes the group of
	 * conditions and opens a new one (also in system mode with sharing bypassed), and one carries its own quoted value.
	 * The query runs against real rows, so a text that is let through shows how many rows it returned. A refused text
	 * must raise an IllegalArgumentException that names the method, and must leave the query text as it was. One case
	 * calls condition without an operator, to prove the refusal comes at that call and not later. A very long dotted
	 * path must get the same refusal, not a stack overflow. Two cases put a LIMIT or an OR around a date function on
	 * convertTimezone, which is allowed on its own.
	 */
	@IsTest
	private static void shouldRefuseCraftedTextInEveryConditionEntry()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> rows = seedFoobarRows(CRAFTED_TEXT_PROBE_ROWS);
			String noMatch = UTIL_Random.randomUUID();
			String widening = FIELD_ID + ' != null OR ' + FIELD_NAME;
			String unclosedHourOfCreation = 'HOUR_IN_DAY(convertTimezone(' + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.CreatedDate) + ')';

			List<CraftedCase> cases = new List<CraftedCase>
			{
					new CraftedCase(CraftedEntry.CONDITION, 'a text that adds an OR matching every row', newFoobarNameQuery(), widening)
							.withComparedValue(noMatch),
					new CraftedCase(CraftedEntry.CONDITION_WITHOUT_OPERATOR, 'the text at the call itself, before an operator is chosen', newFoobarNameQuery(), widening),
					new CraftedCase
							(
									CraftedEntry.CONDITION,
									'a text that closes the group of conditions and opens a new one',
									newFoobarNameQuery().condition(Foobar__c.Name).equals(rows[0].Name),
									FIELD_ID + ' != null) OR (' + FIELD_NAME
							)
							.withComparedValue(rows[1].Name),
					new CraftedCase
							(
									CraftedEntry.CONDITION,
									'a text that closes the group of conditions, in system mode with sharing bypassed',
									newFoobarNameQuery().withSystemMode().bypassSharing().condition(Foobar__c.Name).equals(rows[0].Name),
									FIELD_ID + ' != null) OR (' + FIELD_ID + ' != null OR ' + FIELD_NAME
							)
							.withComparedValue(noMatch),
					new CraftedCase
							(
									CraftedEntry.CONDITION,
									'a text that carries its own quoted value',
									newFoobarNameQuery(),
									FIELD_NAME + ' = \'' + rows[1].Name + '\' OR ' + FIELD_NAME
							)
							.withComparedValue(noMatch),
					new CraftedCase(CraftedEntry.AND_CONDITION, 'a text that adds an OR matching every row', newFoobarNameQuery(), widening)
							.withComparedValue(noMatch),
					new CraftedCase(CraftedEntry.OR_CONDITION, 'a text that adds an OR matching every row', newFoobarNameQuery(), widening)
							.withComparedValue(noMatch),
					new CraftedCase
							(
									CraftedEntry.CONDITION_WITHOUT_OPERATOR,
									'a very long dotted field path that ends with ALL ROWS',
									newFoobarNameQuery(),
									'a.'.repeat(MANY_DOTTED_NAMES) + 'a ALL ROWS'
							),
					new CraftedCase(CraftedEntry.CONDITION, 'a LIMIT inside a date function around convertTimezone', newFoobarNameQuery(), unclosedHourOfCreation + ' LIMIT 1)')
							.withComparedValue(noMatch),
					new CraftedCase
							(
									CraftedEntry.CONDITION,
									'an OR after a date function around convertTimezone',
									newFoobarNameQuery(),
									unclosedHourOfCreation + ') OR ' + FIELD_ID + ' != null'
							)
							.withComparedValue(noMatch)
			};

			for(CraftedCase craftedCase : cases)
			{
				String methodName = ENTRY_METHOD_NAMES.get(craftedCase.entry);
				String soqlBefore = craftedCase.query.toSoql();
				try
				{
					applyCraftedText(craftedCase);
					Assert.fail('Expected ' + methodName + ' to refuse ' + craftedCase.caseName + '; ' + describeQueryRun(craftedCase));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCase.caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name ' + methodName + ' for ' + craftedCase.caseName);
					Assert.areEqual(soqlBefore, craftedCase.query.toSoql(), 'Expected the refused text to leave the query unchanged for ' + craftedCase.caseName);
				}
			}
		}
	}

	/**
	 * @description Proves that the condition method refuses a text that is not a field name even when the test has
	 * registered mock rows for the object. With mock rows, no query reaches the database: the rows are filtered in
	 * memory. The check must still run, so that a mocked unit test also catches a text that would change the query.
	 */
	@IsTest
	private static void shouldRefuseCraftedConditionTextEvenWhenTheQueryIsMocked()
	{
		System.runAs(getTestAdmin())
		{
			TST_Mock.register(Foobar__c.SObjectType, TST_Factory.getFoobarBuilder().withoutInsertion(true).withCount(CRAFTED_TEXT_PROBE_ROWS).buildList());
			CraftedCase craftedCase = new CraftedCase
					(
							CraftedEntry.CONDITION,
							'a text that adds an OR matching every mock row',
							newFoobarNameQuery(),
							FIELD_ID + ' != null OR ' + FIELD_NAME
					)
					.withComparedValue(UTIL_Random.randomUUID());
			String soqlBefore = craftedCase.query.toSoql();

			try
			{
				applyCraftedText(craftedCase);
				Assert.fail('Expected condition to refuse ' + craftedCase.caseName + '; ' + describeQueryRun(craftedCase));
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCase.caseName + ', got: ' + error);
				Assert.areEqual(buildRefusalMessage('condition'), error.getMessage(), 'Expected the message to name condition');
				Assert.areEqual(soqlBefore, craftedCase.query.toSoql(), 'Expected the refused text to leave the query unchanged');
			}
		}
	}

	/**
	 * @description Proves that the three orderBy methods refuse a sort text that adds more than a sort order: ALL ROWS
	 * (which also reads deleted rows, so one deleted row is saved), a LIMIT, or a LIMIT with an OFFSET. It also proves
	 * that the two methods that add the direction themselves refuse a text whose last item already has a direction:
	 * the query would read DESC DESC. A very long text and a long list of sort items must get the same refusal, not an
	 * error no code can catch or a stack overflow. Each refused text must raise an IllegalArgumentException that names
	 * orderBy and must leave the query text as it was.
	 */
	@IsTest
	private static void shouldRefuseCraftedSortText()
	{
		System.runAs(getTestAdmin())
		{
			seedFoobarRowsWithOneDeleted();

			List<CraftedCase> cases = new List<CraftedCase>
			{
					new CraftedCase(CraftedEntry.ORDER_BY, 'ALL ROWS, which also reads deleted rows', newFoobarNameQuery(), FIELD_NAME + ' ALL ROWS'),
					new CraftedCase(CraftedEntry.ORDER_BY, 'a LIMIT clause', newFoobarNameQuery(), FIELD_NAME + ' LIMIT 1'),
					new CraftedCase(CraftedEntry.ORDER_BY, 'a direction followed by LIMIT and OFFSET', newFoobarNameQuery(), FIELD_NAME + ' DESC LIMIT 1 OFFSET 1'),
					new CraftedCase(CraftedEntry.ORDER_BY_DESCENDING, 'a LIMIT clause before the direction', newFoobarNameQuery(), FIELD_NAME + ' LIMIT 1'),
					new CraftedCase(CraftedEntry.ORDER_BY_DESCENDING_NULLS_FIRST, 'a LIMIT clause before the direction', newFoobarNameQuery(), FIELD_NAME + ' LIMIT 1'),
					new CraftedCase(CraftedEntry.ORDER_BY_DESCENDING, 'a sort item that already has a direction', newFoobarNameQuery(), FIELD_NAME + ' DESC'),
					new CraftedCase(CraftedEntry.ORDER_BY, 'a very long text that ends with ALL ROWS', newFoobarNameQuery(), 'a'.repeat(VERY_LONG_TEXT_LENGTH) + ' ALL ROWS'),
					new CraftedCase
							(
									CraftedEntry.ORDER_BY,
									'a long list of sort items whose last item ends with ALL ROWS',
									newFoobarNameQuery(),
									(FIELD_NAME + ', ').repeat(MANY_SORT_ITEMS) + FIELD_NAME + ' ALL ROWS'
							)
			};

			for(CraftedCase craftedCase : cases)
			{
				String methodName = ENTRY_METHOD_NAMES.get(craftedCase.entry);
				String soqlBefore = craftedCase.query.toSoql();
				try
				{
					applyCraftedText(craftedCase);
					Assert.fail('Expected ' + methodName + ' to refuse ' + craftedCase.caseName + '; ' + describeQueryRun(craftedCase));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCase.caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name ' + methodName + ' for ' + craftedCase.caseName);
					Assert.areEqual(soqlBefore, craftedCase.query.toSoql(), 'Expected the refused text to leave the query unchanged for ' + craftedCase.caseName);
				}
			}
		}
	}

	/**
	 * @description Proves that groupBy refuses a group text that adds more than field names: ALL ROWS (which also reads
	 * deleted rows, so one deleted row is saved), an ORDER BY with a LIMIT, a list whose second item is not a field
	 * name, and a LIMIT in a query that counts rows. In that last query the group text is also copied into the SELECT
	 * list. Each refused text must raise an IllegalArgumentException that names groupBy and must leave the query text
	 * as it was.
	 */
	@IsTest
	private static void shouldRefuseCraftedGroupText()
	{
		System.runAs(getTestAdmin())
		{
			seedFoobarRowsWithOneDeleted();

			List<CraftedCase> cases = new List<CraftedCase>
			{
					new CraftedCase(CraftedEntry.GROUP_BY, 'ALL ROWS, which also reads deleted rows', newFoobarNameQuery(), FIELD_NAME + ' ALL ROWS'),
					new CraftedCase
							(
									CraftedEntry.GROUP_BY,
									'an ORDER BY with a LIMIT',
									newFoobarNameQuery(),
									FIELD_NAME + ' ORDER BY ' + FIELD_NAME + ' DESC LIMIT 2'
							),
					new CraftedCase(CraftedEntry.GROUP_BY, 'a list whose second item is crafted', newFoobarNameQuery(), FIELD_NAME + ', ' + FIELD_ID + ' ALL ROWS'),
					new CraftedCase
							(
									CraftedEntry.GROUP_BY,
									'a LIMIT in a query that counts rows',
									QRY_Builder.selectFrom(Foobar__c.SObjectType).count(FIELD_ID),
									FIELD_NAME + ' LIMIT 1'
							)
			};

			for(CraftedCase craftedCase : cases)
			{
				String methodName = ENTRY_METHOD_NAMES.get(craftedCase.entry);
				String soqlBefore = craftedCase.query.toSoql();
				try
				{
					applyCraftedText(craftedCase);
					Assert.fail('Expected ' + methodName + ' to refuse ' + craftedCase.caseName + '; ' + describeQueryRun(craftedCase));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCase.caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name ' + methodName + ' for ' + craftedCase.caseName);
					Assert.areEqual(soqlBefore, craftedCase.query.toSoql(), 'Expected the refused text to leave the query unchanged for ' + craftedCase.caseName);
				}
			}
		}
	}

	/**
	 * @description Proves that count, countDistinct and grouping refuse a text that is not a field name: one that
	 * closes the function and adds a FROM clause, and one that adds ALL ROWS. The aggregate selection that the builder
	 * keeps for an aliased sum must refuse the same texts when it is created. First, the test proves that a blank name
	 * still gives COUNT() and runs, because a blank name is how a caller counts every row.
	 */
	@IsTest
	private static void shouldRefuseCraftedAggregateFieldText()
	{
		System.runAs(getTestAdmin())
		{
			seedFoobarRows(CRAFTED_TEXT_PROBE_ROWS);
			for(String blankName : new List<String> {null, UTIL_String.EMPTY})
			{
				QRY_Builder.Builder countQuery = QRY_Builder.selectFrom(Foobar__c.SObjectType).count(blankName);
				Assert.areEqual('SELECT COUNT() FROM ' + OBJECT_NAME, countQuery.toSoql(), 'Expected a blank name to count every row');
				Assert.areEqual(CRAFTED_TEXT_PROBE_ROWS, countQuery.count(), 'Expected the query that counts every row to run and count the saved rows');
			}

			Map<String, String> craftedTexts = new Map<String, String>
			{
					'a text that closes the function and adds a FROM clause' => FIELD_NAME + ') FROM ' + OBJECT_NAME + ' WHERE (' + FIELD_NAME,
					'ALL ROWS' => FIELD_NAME + ' ALL ROWS'
			};
			List<CraftedCase> cases = new List<CraftedCase>();
			for(String caseName : craftedTexts.keySet())
			{
				String craftedText = craftedTexts.get(caseName);
				cases.add(new CraftedCase(CraftedEntry.COUNT, caseName, QRY_Builder.selectFrom(Foobar__c.SObjectType), craftedText));
				cases.add(new CraftedCase(CraftedEntry.COUNT_DISTINCT, caseName, QRY_Builder.selectFrom(Foobar__c.SObjectType), craftedText));
				cases.add(new CraftedCase(CraftedEntry.GROUPING, caseName, QRY_Builder.selectFrom(Foobar__c.SObjectType).groupBy(Foobar__c.Name).count(FIELD_ID), craftedText));
			}

			for(CraftedCase craftedCase : cases)
			{
				String methodName = ENTRY_METHOD_NAMES.get(craftedCase.entry);
				String soqlBefore = craftedCase.query.toSoql();
				try
				{
					applyCraftedText(craftedCase);
					Assert.fail('Expected ' + methodName + ' to refuse ' + craftedCase.caseName + '; ' + describeQueryRun(craftedCase));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCase.caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name ' + methodName + ' for ' + craftedCase.caseName);
					Assert.areEqual(soqlBefore, craftedCase.query.toSoql(), 'Expected the refused text to leave the query unchanged for ' + craftedCase.caseName);
				}
			}

			for(String caseName : craftedTexts.keySet())
			{
				try
				{
					QRY_Builder.AggregateSelection selection = new QRY_Builder.AggregateSelection(QRY_Generator.Aggregate.SUM, craftedTexts.get(caseName), SUM_ALIAS);
					Assert.fail('Expected AggregateSelection to refuse ' + caseName + '; it kept the field text ' + selection.fieldName);
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage('AggregateSelection'), error.getMessage(), 'Expected the message to name AggregateSelection for ' + caseName);
				}
			}
		}
	}

	/**
	 * @description Proves that every data category method refuses a group name or a category name that adds more
	 * than a name: withDataCategory and the public DataCategoryBuilder constructor for the group, and at, above,
	 * below and aboveOrBelow, with one name and with a list, for the category. This org has no object that takes data
	 * categories, so the test reads the query text only. Each refused name must raise an IllegalArgumentException that
	 * names the method and must leave the query text as it was. Last, a crafted name added to the caller's list after the
	 * list was checked, by at or by the generator's data category filter, must not reach the query.
	 */
	@IsTest
	private static void shouldRefuseCraftedDataCategoryNames()
	{
		System.runAs(getTestAdmin())
		{
			String craftedGroup = CATEGORY_GROUP + ' AT ' + CATEGORY_NAME + ' ORDER BY ' + FIELD_NAME + ' LIMIT 1 X';
			String craftedCategory = CATEGORY_NAME + ' LIMIT 1';
			String groupCase = 'a group name followed by a category and an ORDER BY';
			String categoryCase = 'a category name followed by a LIMIT';

			List<CraftedCase> cases = new List<CraftedCase>
			{
					new CraftedCase(CraftedEntry.DATA_CATEGORY_GROUP, groupCase, QRY_Builder.selectFrom(Foobar__c.SObjectType), craftedGroup),
					new CraftedCase(CraftedEntry.DATA_CATEGORY_BUILDER, groupCase, QRY_Builder.selectFrom(Foobar__c.SObjectType), craftedGroup)
			};
			for(CraftedEntry entry : new List<CraftedEntry>
			{
					CraftedEntry.AT,
					CraftedEntry.AT_LIST,
					CraftedEntry.ABOVE,
					CraftedEntry.ABOVE_LIST,
					CraftedEntry.BELOW,
					CraftedEntry.BELOW_LIST,
					CraftedEntry.EITHER_SIDE,
					CraftedEntry.EITHER_SIDE_LIST
			})
			{
				cases.add(new CraftedCase(entry, categoryCase + ' (' + entry.name() + ')', QRY_Builder.selectFrom(Foobar__c.SObjectType), craftedCategory));
			}

			for(CraftedCase craftedCase : cases)
			{
				String methodName = ENTRY_METHOD_NAMES.get(craftedCase.entry);
				String soqlBefore = craftedCase.query.toSoql();
				try
				{
					applyCraftedText(craftedCase);
					Assert.fail('Expected ' + methodName + ' to refuse ' + craftedCase.caseName + '; ' + describeQueryRun(craftedCase));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCase.caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name ' + methodName + ' for ' + craftedCase.caseName);
					Assert.areEqual(soqlBefore, craftedCase.query.toSoql(), 'Expected the refused text to leave the query unchanged for ' + craftedCase.caseName);
				}
			}

			List<String> builderNames = new List<String> {CATEGORY_NAME};
			QRY_Builder.Builder listQuery = QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory(CATEGORY_GROUP).at(builderNames);
			String listQueryBefore = listQuery.toSoql();
			builderNames.add(craftedCategory);
			Assert.areEqual(listQueryBefore, listQuery.toSoql(), 'Expected a category name added to the list after at to stay out of the query');

			List<String> filterNames = new List<String> {CATEGORY_NAME};
			QRY_Generator.DataCategoryFilter filter = new QRY_Generator.DataCategoryFilter(CATEGORY_GROUP, QRY_Generator.DataCategoryOperator.AT, filterNames);
			filterNames.add(craftedCategory);
			Assert.areEqual(CATEGORY_GROUP + ' AT ' + CATEGORY_NAME, filter.toSoql(), 'Expected a category name added to the list after the filter is made to stay out of it');
		}
	}

	/**
	 * @description Proves that relatedField and relatedFields refuse a parent field text that holds a second field, and
	 * that subselect refuses a relationship name followed by a WHERE clause. Each refused text must raise an
	 * IllegalArgumentException that names the method and must leave the query text as it was.
	 */
	@IsTest
	private static void shouldRefuseCraftedRelatedFieldAndRelationshipName()
	{
		System.runAs(getTestAdmin())
		{
			seedFoobarRows(CRAFTED_TEXT_PROBE_ROWS);
			String twoFields = 'Owner.Name, ' + FIELD_ID;
			String accountQueryCase = 'a relationship name followed by a WHERE clause';

			List<CraftedCase> cases = new List<CraftedCase>
			{
					new CraftedCase(CraftedEntry.RELATED_FIELD, 'a text that holds a second field', newFoobarNameQuery(), twoFields),
					new CraftedCase(CraftedEntry.RELATED_FIELDS, 'a text that holds a second field', newFoobarNameQuery(), twoFields),
					new CraftedCase
							(
									CraftedEntry.SUBSELECT,
									accountQueryCase,
									QRY_Builder.selectFrom(Account.SObjectType).fields(new List<SObjectField> {Account.Name}),
									CONTACTS_RELATIONSHIP + ' WHERE ' + UTIL_SObjectDescribe.getCachedFieldName(Contact.LastName) + ' != null'
							)
			};

			for(CraftedCase craftedCase : cases)
			{
				String methodName = ENTRY_METHOD_NAMES.get(craftedCase.entry);
				String soqlBefore = craftedCase.query.toSoql();
				try
				{
					applyCraftedText(craftedCase);
					Assert.fail('Expected ' + methodName + ' to refuse ' + craftedCase.caseName + '; ' + describeQueryRun(craftedCase));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCase.caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name ' + methodName + ' for ' + craftedCase.caseName);
					Assert.areEqual(soqlBefore, craftedCase.query.toSoql(), 'Expected the refused text to leave the query unchanged for ' + craftedCase.caseName);
				}
			}
		}
	}

	/**
	 * @description Proves that isIn and notIn refuse an inner query whose selected text is not one field name. The
	 * inner query's select list is written inside the outer WHERE clause, so such a text can swap the filter the code
	 * meant ("Accounts that have a Contact") for another one ("Accounts that have an Opportunity, whose owner also owns
	 * a Contact"). Account A has a Contact; Account B has an Opportunity and no Contact. The refusal must come at the
	 * isIn or notIn call itself, before any query runs: the check runs when the inner query is stored.
	 */
	@IsTest
	private static void shouldRefuseCraftedSelectTextInASemiJoinSubquery()
	{
		System.runAs(getTestAdmin())
		{
			List<String> accountNames = seedAccountWithContactAndAccountWithOpportunity();
			String ownerField = UTIL_SObjectDescribe.getCachedFieldName(Account.OwnerId);
			String craftedSelect = UTIL_SObjectDescribe.getCachedFieldName(Contact.AccountId) + ' FROM ' + String.valueOf(Opportunity.SObjectType)
					+ ') AND ' + ownerField + ' IN (SELECT ' + ownerField;

			List<CraftedCase> cases = new List<CraftedCase>
			{
					new CraftedCase(CraftedEntry.IS_IN, 'a select text that swaps the inner query (A is expected)', newAccountQuery(accountNames), craftedSelect),
					new CraftedCase(CraftedEntry.NOT_IN, 'a select text that swaps the inner query (B is expected)', newAccountQuery(accountNames), craftedSelect)
			};

			for(CraftedCase craftedCase : cases)
			{
				String methodName = ENTRY_METHOD_NAMES.get(craftedCase.entry);
				String soqlBefore = craftedCase.query.toSoql();
				try
				{
					applyCraftedText(craftedCase);
					Assert.fail('Expected ' + methodName + ' to refuse ' + craftedCase.caseName + ' at the call itself; ' + describeQueryRun(craftedCase));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCase.caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name ' + methodName + ' for ' + craftedCase.caseName);
					Assert.areEqual(soqlBefore, craftedCase.query.toSoql(), 'Expected the refused text to leave the query unchanged for ' + craftedCase.caseName);
				}
			}
		}
	}

	/**
	 * @description Records the query text the builder writes today for every field name shape that released code may
	 * pass as text, and proves each query runs and returns the number of saved rows or groups it should. The shapes
	 * are: a plain name, a name that can carry the package namespace, a parent field path one and two steps away, a name with spaces around it, a date function from
	 * QRY_Function, a date function written as text, a sort text with a direction and a nulls order, a list of sort
	 * items, a list of group fields, toLabel on a picklist, a date function around convertTimezone in a condition and in
	 * GROUP BY, and a field path that reaches five parent records. With spaces around it, the name is trimmed in a
	 * condition but kept as given in ORDER BY and GROUP BY. The text must not change when the builder starts to check
	 * field names. A sort list of 32 items, the most ORDER BY takes, keeps its text too; it is not run. The toLabel case
	 * in ORDER BY records that the platform refuses it today.
	 */
	@IsTest
	private static void shouldKeepTheQueryTextForReleasedFieldNameShapes()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> rows = seedFoobarRows(CRAFTED_TEXT_PROBE_ROWS);
			String value = rows[0].Name;
			String createdDate = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.CreatedDate);
			String padded = '  ' + FIELD_NAME + '  ';
			String ownerName = 'Owner.Name';
			String profileName = 'CreatedBy.Profile.Name';
			Integer year = Datetime.now().yearGmt();
			String picklistLabel = UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Picklist__c).getPicklistValues()[0].getLabel();
			String toLabelText = 'toLabel(' + FIELD_PICKLIST + ')';
			String selectName = 'SELECT ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;
			String selectText = 'SELECT ' + FIELD_TEXT + ' FROM ' + OBJECT_NAME;
			String countAndGroup = 'SELECT COUNT(Id) count_Id, ';
			String quotedValue = ' = \'' + value + '\'';
			String hourOfCreation = 'HOUR_IN_DAY(convertTimezone(' + createdDate + '))';

			Map<String, QRY_Builder.Builder> queries = new Map<String, QRY_Builder.Builder>();
			Map<String, String> expectedTexts = new Map<String, String>();

			queries.put('a plain name in condition', newFoobarNameQuery().condition(FIELD_NAME).equals(value));
			expectedTexts.put('a plain name in condition', selectName + ' WHERE ' + FIELD_NAME + quotedValue);
			queries.put('a plain name in orderBy', newFoobarNameQuery().orderBy(FIELD_NAME));
			expectedTexts.put('a plain name in orderBy', selectName + ' ORDER BY ' + FIELD_NAME);
			queries.put('a plain name in groupBy', newFoobarNameQuery().groupBy(FIELD_NAME));
			expectedTexts.put('a plain name in groupBy', selectName + ' GROUP BY ' + FIELD_NAME);

			queries.put('a namespaced name in condition', newFoobarNameQuery().condition(FIELD_TEXT).equals(value));
			expectedTexts.put('a namespaced name in condition', selectName + ' WHERE ' + FIELD_TEXT + quotedValue);
			queries.put('a namespaced name in orderBy', newFoobarNameQuery().orderBy(FIELD_TEXT));
			expectedTexts.put('a namespaced name in orderBy', selectName + ' ORDER BY ' + FIELD_TEXT);
			queries.put('a namespaced name in groupBy', QRY_Builder.selectFrom(Foobar__c.SObjectType).fields(new List<SObjectField> {Foobar__c.Text__c}).groupBy(FIELD_TEXT));
			expectedTexts.put('a namespaced name in groupBy', selectText + ' GROUP BY ' + FIELD_TEXT);

			queries.put('a parent field path in condition', newFoobarNameQuery().condition(ownerName).equals(value));
			expectedTexts.put('a parent field path in condition', selectName + ' WHERE ' + ownerName + quotedValue);
			queries.put('a parent field path in orderBy', newFoobarNameQuery().orderBy(ownerName));
			expectedTexts.put('a parent field path in orderBy', selectName + ' ORDER BY ' + ownerName);
			queries.put('a two step parent field path in condition', newFoobarNameQuery().condition(profileName).equals(value));
			expectedTexts.put('a two step parent field path in condition', selectName + ' WHERE ' + profileName + quotedValue);
			queries.put('a two step parent field path in orderBy', newFoobarNameQuery().orderBy(profileName));
			expectedTexts.put('a two step parent field path in orderBy', selectName + ' ORDER BY ' + profileName);

			queries.put('a name with spaces around it in condition', newFoobarNameQuery().condition(padded).equals(value));
			expectedTexts.put('a name with spaces around it in condition', selectName + ' WHERE ' + FIELD_NAME + quotedValue);
			queries.put('a name with spaces around it in orderBy', newFoobarNameQuery().orderBy(padded));
			expectedTexts.put('a name with spaces around it in orderBy', selectName + ' ORDER BY ' + padded);
			queries.put('a name with spaces around it in groupBy', newFoobarNameQuery().groupBy(padded));
			expectedTexts.put('a name with spaces around it in groupBy', selectName + ' GROUP BY ' + padded);

			queries.put('a date function from QRY_Function in condition', newFoobarNameQuery().condition(QRY_Function.calendarYear(Foobar__c.CreatedDate)).equals(year));
			expectedTexts.put('a date function from QRY_Function in condition', selectName + ' WHERE CALENDAR_YEAR(' + createdDate + ') = ' + year);
			queries.put('a date function from QRY_Function in groupBy and orderBy', QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(QRY_Function.dayOnly(Foobar__c.CreatedDate)).count(FIELD_ID).orderBy(QRY_Function.dayOnly(Foobar__c.CreatedDate)));
			expectedTexts.put('a date function from QRY_Function in groupBy and orderBy', countAndGroup + 'DAY_ONLY(' + createdDate + ') FROM ' + OBJECT_NAME
					+ ' GROUP BY DAY_ONLY(' + createdDate + ') ORDER BY DAY_ONLY(' + createdDate + ')');
			queries.put('a date function from QRY_Function in groupBy', QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(QRY_Function.calendarYear(Foobar__c.CreatedDate)).count(FIELD_ID));
			expectedTexts.put('a date function from QRY_Function in groupBy', countAndGroup + 'CALENDAR_YEAR(' + createdDate + ') FROM ' + OBJECT_NAME
					+ ' GROUP BY CALENDAR_YEAR(' + createdDate + ')');
			queries.put('a date function written as text in condition', newFoobarNameQuery().condition('CALENDAR_YEAR(' + createdDate + ')').equals(year));
			expectedTexts.put('a date function written as text in condition', selectName + ' WHERE CALENDAR_YEAR(' + createdDate + ') = ' + year);
			queries.put('a date function written as text in groupBy', QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy('calendar_year(' + createdDate + ')').count(FIELD_ID));
			expectedTexts.put('a date function written as text in groupBy', countAndGroup + 'calendar_year(' + createdDate + ') FROM ' + OBJECT_NAME
					+ ' GROUP BY calendar_year(' + createdDate + ')');

			queries.put('a sort text with a direction', newFoobarNameQuery().orderBy(FIELD_NAME + ' DESC'));
			expectedTexts.put('a sort text with a direction', selectName + ' ORDER BY ' + FIELD_NAME + ' DESC');
			queries.put('a sort text with a direction and a nulls order', newFoobarNameQuery().orderBy(FIELD_NAME + ' asc NULLS LAST'));
			expectedTexts.put('a sort text with a direction and a nulls order', selectName + ' ORDER BY ' + FIELD_NAME + ' asc NULLS LAST');
			queries.put('a list of sort items', newFoobarNameQuery().orderBy(FIELD_NAME + ' DESC, ' + createdDate));
			expectedTexts.put('a list of sort items', selectName + ' ORDER BY ' + FIELD_NAME + ' DESC, ' + createdDate);
			queries.put('a list of sort items before the direction', newFoobarNameQuery().orderBy(FIELD_NAME + ', ' + FIELD_TEXT, true));
			expectedTexts.put('a list of sort items before the direction', selectName + ' ORDER BY ' + FIELD_NAME + ', ' + FIELD_TEXT + ' DESC NULLS LAST');
			queries.put('a list of sort items before the direction and nulls order', newFoobarNameQuery().orderBy(FIELD_NAME + ' DESC, ' + FIELD_TEXT, false, true));
			expectedTexts.put('a list of sort items before the direction and nulls order', selectName + ' ORDER BY ' + FIELD_NAME + ' DESC, ' + FIELD_TEXT + ' ASC NULLS LAST');

			queries.put('a list of group fields', newFoobarNameQuery().groupBy(FIELD_NAME + ', ' + FIELD_TEXT));
			expectedTexts.put('a list of group fields', selectName + ' GROUP BY ' + FIELD_NAME + ', ' + FIELD_TEXT);
			queries.put('a list of group fields with a count', QRY_Builder.selectFrom(Foobar__c.SObjectType).groupBy(FIELD_NAME + ', ' + FIELD_TEXT).count(FIELD_ID));
			expectedTexts.put('a list of group fields with a count', countAndGroup + FIELD_NAME + ', ' + FIELD_TEXT + ' FROM ' + OBJECT_NAME
					+ ' GROUP BY ' + FIELD_NAME + ', ' + FIELD_TEXT);

			queries.put('toLabel on a picklist in condition', newFoobarNameQuery().condition(toLabelText).equals(picklistLabel));
			expectedTexts.put('toLabel on a picklist in condition', selectName + ' WHERE ' + toLabelText + ' = \'' + picklistLabel + '\'');

			queries.put('a date function around convertTimezone in condition', newFoobarNameQuery().condition(hourOfCreation).lessThan(HOURS_IN_A_DAY));
			expectedTexts.put('a date function around convertTimezone in condition', selectName + ' WHERE ' + hourOfCreation + ' < ' + HOURS_IN_A_DAY);
			queries.put('a date function around convertTimezone in groupBy', QRY_Builder.selectFrom(Foobar__c.SObjectType).groupBy(hourOfCreation).count(FIELD_ID));
			expectedTexts.put('a date function around convertTimezone in groupBy', countAndGroup + hourOfCreation + ' FROM ' + OBJECT_NAME + ' GROUP BY ' + hourOfCreation);
			queries.put('a field path that reaches five parent records in condition', newFoobarNameQuery().condition(FIVE_PARENT_PATH).equals(value));
			expectedTexts.put('a field path that reaches five parent records in condition', selectName + ' WHERE ' + FIVE_PARENT_PATH + quotedValue);

			String picklistValue = UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Picklist__c).getPicklistValues()[0].getValue();
			Integer rowsWithTheLabel = 0;
			for(Foobar__c row : rows)
			{
				rowsWithTheLabel += row.Picklist__c == picklistValue ? 1 : 0;
			}

			// While a test runs, a trigger gives every saved Foobar__c row the same Text__c value, so no row has the name as
			// its Text__c value and all rows fall into one group.
			Map<String, Integer> expectedRowCounts = new Map<String, Integer>
			{
					'a plain name in condition' => 1,
					'a namespaced name in condition' => 0,
					'a namespaced name in groupBy' => 1,
					'a parent field path in condition' => 0,
					'a two step parent field path in condition' => 0,
					'a name with spaces around it in condition' => 1,
					'a date function from QRY_Function in groupBy and orderBy' => 1,
					'a date function from QRY_Function in groupBy' => 1,
					'a date function written as text in groupBy' => 1,
					'toLabel on a picklist in condition' => rowsWithTheLabel,
					'a date function around convertTimezone in groupBy' => 1,
					'a field path that reaches five parent records in condition' => 0
			};

			for(String caseName : queries.keySet())
			{
				QRY_Builder.Builder query = queries.get(caseName);
				Integer expectedRowCount = expectedRowCounts.get(caseName) ?? CRAFTED_TEXT_PROBE_ROWS;
				Assert.areEqual(expectedTexts.get(caseName), query.toSoql(), 'Expected the query text for ' + caseName + ' to stay as it is');
				Assert.areEqual(expectedRowCount, query.toList().size(), 'Expected the query for ' + caseName + ' to run and return ' + expectedRowCount + ' rows');
			}

			String longestSortList = (FIVE_PARENT_PATH + ' DESC NULLS LAST, ').repeat(MOST_SORT_ITEMS - 1) + FIVE_PARENT_PATH + ' ASC NULLS FIRST';
			Assert.areEqual
					(
							selectName + ' ORDER BY ' + longestSortList,
							newFoobarNameQuery().orderBy(longestSortList).toSoql(),
							'Expected the query text for a list of the most sort items ORDER BY takes to stay as it is'
					);

			QRY_Builder.Builder toLabelOrderQuery = newFoobarNameQuery().orderBy(toLabelText);
			Assert.areEqual(selectName + ' ORDER BY ' + toLabelText, toLabelOrderQuery.toSoql(), 'Expected the query text for toLabel on a picklist in orderBy to stay as it is');
			try
			{
				toLabelOrderQuery.toList();
				Assert.fail('Expected the platform to refuse toLabel on a picklist in orderBy: ' + toLabelOrderQuery.toSoql());
			}
			catch(QueryException error)
			{
				Assert.isTrue(error.getMessage().contains('Invalid aggregate function'), 'Expected the platform to refuse toLabel here, got: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Records the query text the builder writes for a distance from QRY_Function, for each way Apex writes
	 * a number: with trailing zeros (45.000000000000) and with an exponent (1E-7), in a condition and in the sort order,
	 * and proves the query runs. Salesforce does not read the exponent form, so a number such as 0.0000001 must be
	 * written as plain digits. A latitude of null is written as null, and the platform refuses that query when it runs.
	 * That refusal is kept: the builder does not refuse the null itself. Last, a distance typed by hand with spaces just
	 * inside its round brackets keeps its text and runs.
	 */
	@IsTest
	private static void shouldKeepTheQueryTextForDistanceCoordinatesInEveryNumberForm()
	{
		System.runAs(getTestAdmin())
		{
			String address = UTIL_SObjectDescribe.getCachedFieldName(Account.BillingAddress);
			String selectAccountName = 'SELECT ' + UTIL_SObjectDescribe.getCachedFieldName(Account.Name) + ' FROM ' + String.valueOf(Account.SObjectType);

			QRY_Builder.Builder trailingZerosQuery = QRY_Builder.selectFrom(Account.SObjectType)
					.fields(new List<SObjectField> {Account.Name})
					.condition(QRY_Function.distanceInMiles(Account.BillingAddress, LATITUDE_WITH_TRAILING_ZEROS, DISTANCE_LONGITUDE)).lessThan(DISTANCE_LIMIT_MILES)
					.orderBy(QRY_Function.distanceInMiles(Account.BillingAddress, LATITUDE_WITH_TRAILING_ZEROS, DISTANCE_LONGITUDE));
			Assert.areEqual
					(
							selectAccountName + ' WHERE DISTANCE(' + address + ', GEOLOCATION(45.000000000000,10), \'mi\') < 5 ORDER BY DISTANCE('
							+ address + ', GEOLOCATION(45.000000000000,10), \'mi\')',
							trailingZerosQuery.toSoql(),
							'Expected the trailing zeros to be written as Apex writes them'
					);
			Assert.areEqual(0, trailingZerosQuery.toList().size(), 'Expected the distance query with trailing zeros to run and find no accounts, because the test has none');

			QRY_Builder.Builder nullQuery = QRY_Builder.selectFrom(Account.SObjectType)
					.fields(new List<SObjectField> {Account.Name})
					.condition(QRY_Function.distanceInMiles(Account.BillingAddress, null, DISTANCE_LONGITUDE)).lessThan(DISTANCE_LIMIT_MILES);
			Assert.areEqual
					(
							selectAccountName + ' WHERE DISTANCE(' + address + ', GEOLOCATION(null,10), \'mi\') < 5',
							nullQuery.toSoql(),
							'Expected a null latitude to be written as null'
					);
			try
			{
				nullQuery.toList();
				Assert.fail('Expected the platform to refuse a null latitude when the query runs');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected the platform QueryException for a null latitude, got: ' + error);
			}

			QRY_Builder.Builder exponentQuery = QRY_Builder.selectFrom(Account.SObjectType)
					.fields(new List<SObjectField> {Account.Name})
					.condition(QRY_Function.distanceInMiles(Account.BillingAddress, LATITUDE_IN_EXPONENT_FORM, DISTANCE_LONGITUDE)).lessThan(DISTANCE_LIMIT_MILES)
					.orderBy(QRY_Function.distanceInMiles(Account.BillingAddress, LATITUDE_IN_EXPONENT_FORM, DISTANCE_LONGITUDE));
			Assert.areEqual
					(
							selectAccountName + ' WHERE DISTANCE(' + address + ', GEOLOCATION(0.0000001,10), \'mi\') < 5 ORDER BY DISTANCE('
							+ address + ', GEOLOCATION(0.0000001,10), \'mi\')',
							exponentQuery.toSoql(),
							'Expected a number that Apex writes with an exponent to be written as plain digits'
					);
			Assert.areEqual(0, exponentQuery.toList().size(), 'Expected the distance query with a very small latitude to run and find no accounts, because the test has none');

			String spacedDistance = 'DISTANCE( ' + address + ', GEOLOCATION( ' + DISTANCE_LONGITUDE + ',' + DISTANCE_LONGITUDE + ' ), \'mi\' )';
			QRY_Builder.Builder spacedQuery = QRY_Builder.selectFrom(Account.SObjectType)
					.fields(new List<SObjectField> {Account.Name})
					.condition(spacedDistance).lessThan(DISTANCE_LIMIT_MILES);
			Assert.areEqual
					(
							selectAccountName + ' WHERE ' + spacedDistance + ' < ' + DISTANCE_LIMIT_MILES,
							spacedQuery.toSoql(),
							'Expected a distance typed by hand with spaces inside the brackets to keep its text'
					);
			Assert.areEqual(0, spacedQuery.toList().size(), 'Expected the distance query typed by hand with spaces inside the brackets to run and find no accounts');
		}
	}

	/**
	 * @description Reads the Phone of a parent record when the parent is an Account. A switch on type does not accept a
	 * relationship field such as Event.What directly, so the parent comes in as an SObject.
	 *
	 * @param parent The parent record a TYPEOF query brought back, or null
	 *
	 * @return The Phone of the Account, or null when the parent is not an Account or is null
	 */
	private static String readAccountPhone(SObject parent)
	{
		String parentPhone;
		switch on parent
		{
			when Account account
			{
				parentPhone = account.Phone;
			}
		}
		return parentPhone;
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
	 * @description Gives a user read access to the Related To field of an Event, the field that points to the record
	 * the Event is about. Event access does not come from an object permission, so a permission set cannot list the
	 * Event object. It can still grant one of its fields. The method saves a permission set with that one field
	 * permission and assigns it to the user.
	 *
	 * @param user The user who gets the access.
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void grantReadOnEventRelatedTo(User user)
	{
		String permissionSetName = EVENT_RELATED_TO_PERMISSION_SET_PREFIX + UTIL_Random.randomAlphanumeric(PERMISSION_SET_NAME_RANDOM_LENGTH);
		SObjectType fieldPermissionsType = new FieldPermissions().getSObjectType();
		String eventObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Event.SObjectType);
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
							FieldPermissions.SobjectType => eventObjectName,
							FieldPermissions.Field => eventObjectName + '.' + UTIL_SObjectDescribe.getCachedFieldName(Event.WhatId),
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
		return TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_STANDARD_USER, new List<SObjectType> {Foobar__c.SObjectType}, READ_PERMISSIONS, Foobar__c.Email__c);
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
		return String.format(System.Label.QueryBuilder_BypassSharingField_NotReadable, new List<Object> {UTIL_SObjectDescribe.getCachedFieldName(field)});
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
	 * @description Counts the bypass audit events written for a query (the query surface) whose target matches the given
	 * value. The log merges events that are the same into one detail row, and keeps how many there were on a rollup
	 * row. So this method adds up the count on each matching rollup row. Two events that are the same give 2, not 1.
	 *
	 * @param target The bypass audit target to count, for example sharing: followed by the object name
	 *
	 * @return The number of matching events
	 */
	private static Integer countBypassAuditEntries(String target)
	{
		String rollupBypassPrefix = TRG_PersistLogEntry.PREFIX_ROLLUP + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		Integer entryCount = 0;
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(entry.Fingerprint__c?.startsWith(rollupBypassPrefix) == true
					&& target.equals(context?.get(UTIL_BypassAudit.CONTEXT_TARGET))
					&& UTIL_BypassAudit.SURFACE_QUERY.equals(context?.get(UTIL_BypassAudit.CONTEXT_SURFACE)))
			{
				entryCount += entry.OccurrenceCount__c?.intValue() ?? 0;
			}
		}
		return entryCount;
	}

	/**
	 * @description Builds the message the builder gives when it refuses a text where it expects a field name. The
	 * label is read by its name, with the package namespace, and the method name is put into it.
	 *
	 * @param methodName The method the message must name
	 *
	 * @return The expected message
	 */
	private static String buildRefusalMessage(String methodName)
	{
		return String.format(System.Label.get(UTIL_System.getManagedPackageNamespace(), FIELD_NAME_REFUSED_LABEL), new List<Object> {methodName});
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
	 * @description Starts an Account query that selects the Name field and reads only the Accounts with the given names.
	 *
	 * @param accountNames The names of the Accounts the query may return
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newAccountQuery(List<String> accountNames)
	{
		return QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.Name).isIn((List<Object>)accountNames);
	}

	/**
	 * @description Saves Foobar__c rows, each with its own random name.
	 *
	 * @param rowCount How many rows to save
	 *
	 * @return The saved rows
	 */
	private static List<Foobar__c> seedFoobarRows(Integer rowCount)
	{
		List<Object> names = new List<Object>();
		for(Integer index = 0; index < rowCount; index++)
		{
			names.add(UTIL_Random.randomUUID());
		}
		return TST_Factory.getFoobarBuilder().withCycle(Foobar__c.Name, names).withCount(rowCount).buildList();
	}

	/**
	 * @description Saves the usual number of Foobar__c rows for the crafted text tests, plus one more row that is then
	 * deleted. A query that also reads deleted rows returns one row more than a normal query.
	 */
	private static void seedFoobarRowsWithOneDeleted()
	{
		List<Foobar__c> rows = seedFoobarRows(CRAFTED_TEXT_PROBE_ROWS + 1);
		DML_Builder.newTransaction().doDelete(rows[CRAFTED_TEXT_PROBE_ROWS]).execute();
	}

	/**
	 * @description Saves Account A with one Contact, and Account B with one Opportunity and no Contact. The names start
	 * with A or B so that a failure message shows which Account a query returned. Both Accounts carry a phone number
	 * and an industry.
	 *
	 * @return The names of Account A and Account B, in that order
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static List<String> seedAccountWithContactAndAccountWithOpportunity()
	{
		Account accountWithContact = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, 'A ' + UTIL_Random.randomUUID())
				.withOverride(Account.Phone, PARENT_PHONE)
				.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
				.build();
		Account accountWithOpportunity = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, 'B ' + UTIL_Random.randomUUID())
				.withOverride(Account.Phone, PARENT_PHONE)
				.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
				.build();
		TST_Builder.of(Contact.SObjectType).withOverride(Contact.AccountId, accountWithContact.Id).build();
		TST_Builder.of(Opportunity.SObjectType).withOverride(Opportunity.AccountId, accountWithOpportunity.Id).build();
		return new List<String> {accountWithContact.Name, accountWithOpportunity.Name};
	}

	/**
	 * @description Passes the crafted text of a case to the builder method the case names, on the query of the case.
	 *
	 * @param craftedCase The case to apply
	 */
	private static void applyCraftedText(CraftedCase craftedCase)
	{
		QRY_Builder.Builder query = craftedCase.query;
		String text = craftedCase.craftedText;
		switch on craftedCase.entry
		{
			when CONDITION
			{
				query.condition(text).equals(craftedCase.comparedValue);
			}
			when CONDITION_WITHOUT_OPERATOR
			{
				query.condition(text);
			}
			when AND_CONDITION
			{
				query.andCondition(text).equals(craftedCase.comparedValue);
			}
			when OR_CONDITION
			{
				query.orCondition(text).equals(craftedCase.comparedValue);
			}
			when ORDER_BY
			{
				query.orderBy(text);
			}
			when ORDER_BY_DESCENDING
			{
				query.orderBy(text, true);
			}
			when ORDER_BY_DESCENDING_NULLS_FIRST
			{
				query.orderBy(text, true, false);
			}
			when GROUP_BY
			{
				query.groupBy(text);
			}
			when COUNT
			{
				query.count(text);
			}
			when COUNT_DISTINCT
			{
				query.countDistinct(text);
			}
			when GROUPING
			{
				query.grouping(text);
			}
			when DATA_CATEGORY_GROUP
			{
				query.withDataCategory(text).at(CATEGORY_NAME);
			}
			when DATA_CATEGORY_BUILDER
			{
				new QRY_Builder.DataCategoryBuilder(query, text).at(CATEGORY_NAME);
			}
			when AT
			{
				query.withDataCategory(CATEGORY_GROUP).at(text);
			}
			when AT_LIST
			{
				query.withDataCategory(CATEGORY_GROUP).at(new List<String> {text});
			}
			when ABOVE
			{
				query.withDataCategory(CATEGORY_GROUP).above(text);
			}
			when ABOVE_LIST
			{
				query.withDataCategory(CATEGORY_GROUP).above(new List<String> {text});
			}
			when BELOW
			{
				query.withDataCategory(CATEGORY_GROUP).below(text);
			}
			when BELOW_LIST
			{
				query.withDataCategory(CATEGORY_GROUP).below(new List<String> {text});
			}
			when EITHER_SIDE
			{
				query.withDataCategory(CATEGORY_GROUP).aboveOrBelow(text);
			}
			when EITHER_SIDE_LIST
			{
				query.withDataCategory(CATEGORY_GROUP).aboveOrBelow(new List<String> {text});
			}
			when RELATED_FIELD
			{
				query.relatedField(text);
			}
			when RELATED_FIELDS
			{
				query.relatedFields(new List<String> {text});
			}
			when SUBSELECT
			{
				query.subselect(QRY_Builder.selectFrom(Contact.SObjectType).fields(new List<SObjectField> {Contact.LastName}), text);
			}
			when IS_IN
			{
				query.condition(FIELD_ID).isIn(QRY_Builder.selectFrom(Contact.SObjectType).fields(new List<String> {text}));
			}
			when NOT_IN
			{
				query.condition(FIELD_ID).notIn(QRY_Builder.selectFrom(Contact.SObjectType).fields(new List<String> {text}));
			}
		}
	}

	/**
	 * @description Says what happened after the builder accepted a crafted text: how many rows the query returned
	 * and their names, with the query text, or the error the query raised. Where the query cannot run on this org, it
	 * gives the query text only. It never raises an error itself, so that a test can put its answer in a failure
	 * message.
	 *
	 * @param craftedCase The case whose query to run
	 *
	 * @return A sentence that says what the query did
	 */
	private static String describeQueryRun(CraftedCase craftedCase)
	{
		try
		{
			if(TEXT_ONLY_ENTRIES.contains(craftedCase.entry))
			{
				return 'the call was accepted and the query text is: ' + craftedCase.query.toSoql();
			}
			List<SObject> rows = craftedCase.query.toList();
			List<String> rowNames = new List<String>();
			for(SObject row : rows)
			{
				rowNames.add(String.valueOf(row.getPopulatedFieldsAsMap().get(FIELD_NAME)));
			}
			return 'the call was accepted, and the query ran and returned ' + rows.size() + ' rows ' + rowNames + ': ' + craftedCase.query.toSoql();
		}
		catch(Exception error)
		{
			return 'the call was accepted, and the query then failed with ' + error.getTypeName() + ': ' + error.getMessage();
		}
	}

	/**
	 * @description Tests that `withSystemMode` emits a `query` bypass audit entry recording
	 * the system-mode target. Validates the framework-wide bypass audit floor: query reads
	 * that opt out of USER_MODE-by-default leave a forensic trail.
	 *
	 * @see QRY_Builder.Builder.withSystemMode
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnWithSystemMode()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toList();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('system-mode:' + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'withSystemMode should emit an object-qualified bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_QUERY, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be query');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `systemModeInternal` flips USER_MODE off WITHOUT enqueuing a
	 * bypass audit entry. The framework-internal channel is the path used by `SEL_Base.query`
	 * for `systemModeRequired() == true` selectors and by `UTIL_FeatureFlag` CMDT/setting
	 * lookups. None of these are subscriber-facing bypasses, so they must not pollute the
	 * `BypassEvent` forensic trail. Without this contract, every framework-internal config
	 * read would emit a noise audit entry on every operation.
	 *
	 * @see QRY_Builder.Builder.systemModeInternal
	 * @see SEL_Base.query
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditOnSystemModeInternal()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).systemModeInternal();
		builder.toList();
		Test.stopTest();

		Assert.isFalse(builder.userModeEnabled, 'systemModeInternal should flip userModeEnabled to false');
		Assert.isNull(findBypassAuditContext('system-mode:' + String.valueOf(Foobar__c.SObjectType)),
				'systemModeInternal must not emit a bypass audit entry');
	}

	/**
	 * @description Tests that `bypassSharing` emits a `query` bypass audit entry recording
	 * the sharing target.
	 *
	 * @see QRY_Builder.Builder.bypassSharing
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnBypassSharing()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).bypassSharing().toList();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext(SHARING_AUDIT_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'bypassSharing should emit an object-qualified bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_QUERY, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be query');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `bypassSharingInternal` disables the sharing proxy WITHOUT enqueuing
	 * a bypass audit entry. The framework-internal channel is the path used by framework reads
	 * that structurally require org-wide visibility (the health check's trusted-site probe, the
	 * community-nickname uniqueness scan). None of these are subscriber-facing bypasses, so they
	 * must not pollute the `BypassEvent` forensic trail.
	 *
	 * @see QRY_Builder.Builder.bypassSharingInternal
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditOnBypassSharingInternal()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).bypassSharingInternal();
		builder.toList();
		Test.stopTest();

		Assert.isFalse(builder.sharingEnforced, 'bypassSharingInternal should flip sharingEnforced to false');
		Assert.isNull(findBypassAuditContext(SHARING_AUDIT_PREFIX + String.valueOf(Foobar__c.SObjectType)),
				'bypassSharingInternal must not emit a bypass audit entry');
	}

	/**
	 * @description Tests that `withoutSecurity` emits a `query` bypass audit entry recording
	 * the security-mode target; the sharing note the same call now queues is proved by
	 * withoutSecurityEmitsBothBypassAuditNotes.
	 *
	 * @see QRY_Builder.Builder.withoutSecurity
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnWithoutSecurity()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutSecurity().toList();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext(SECURITY_MODE_AUDIT_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'withoutSecurity should emit an object-qualified bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_QUERY, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be query');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that withoutSecurity() is the full waiver its name and its documentation promise: on
	 * the row, count and locator terminals it reaches rows the running user cannot see through sharing, while
	 * withSystemMode() alone still reaches none of them (the object-and-field-only call, the alternative that
	 * keeps sharing).
	 */
	@IsTest
	private static void withoutSecurityWaivesSharingOnEveryTerminal()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, WAIVER_PROBE_NAME)
					.withCount(WAIVER_PROBE_ROWS)
					.buildList();
		}

		Integer waivedRows;
		Integer waivedCount;
		Integer waivedLocatorRows;
		Integer waivedPageRows;
		SObject waivedFirst;
		Integer systemModeRows;
		SObject systemModeFirst;

		Test.startTest();
		System.runAs(restricted)
		{
			waivedRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutSecurity().toList().size();
			waivedCount = QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutSecurity().count();
			waivedLocatorRows = countLocatorRows(QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutSecurity().toQueryLocator());
			waivedPageRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutSecurity().getPage(1, WAIVER_PROBE_PAGE_SIZE).records.size();
			waivedFirst = QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutSecurity().getFirst();
			systemModeRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toList().size();
			systemModeFirst = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().getFirst();
		}
		Test.stopTest();

		Assert.areEqual(WAIVER_PROBE_ROWS, waivedRows, 'withoutSecurity() must reach every row on toList(); '
				+ 'fewer means sharing is still applied under a name that promises no security');
		Assert.areEqual(WAIVER_PROBE_ROWS, waivedCount, 'withoutSecurity() must reach every row on count()');
		Assert.areEqual(WAIVER_PROBE_ROWS, waivedLocatorRows, 'withoutSecurity() must reach every row on toQueryLocator()');
		Assert.areEqual(WAIVER_PROBE_ROWS, waivedPageRows, 'withoutSecurity() must reach every row on getPage()');
		Assert.isNotNull(waivedFirst, 'withoutSecurity() must reach a row on getFirst()');
		Assert.areEqual(0, systemModeRows, 'withSystemMode() alone keeps record sharing: the row query returns nothing the user cannot see, and no exception either');
		Assert.isNull(systemModeFirst, 'withSystemMode() alone keeps record sharing on getFirst() too');
	}

	/**
	 * @description Tests that one withoutSecurity() call leaves both audit notes, so the forensic trail records
	 * that the mode AND the sharing dial were set by a single call.
	 */
	@IsTest
	private static void withoutSecurityEmitsBothBypassAuditNotes()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutSecurity().toList();
		Test.stopTest();

		Map<String, Object> securityModeContext = findBypassAuditContext(SECURITY_MODE_AUDIT_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Map<String, Object> sharingContext = findBypassAuditContext(SHARING_AUDIT_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(securityModeContext, 'withoutSecurity() should emit the object-qualified security-mode audit entry');
		Assert.isNotNull(sharingContext, 'withoutSecurity() should also emit the object-qualified sharing-bypass audit entry');
	}

	/**
	 * @description Tests that the latched `setBypassReason` flows into a query-side bypass audit
	 * entry, proving the cross-surface reason latch works through the query emission path.
	 *
	 * @see QRY_Builder.Builder.withSystemMode
	 * @see UTIL_BypassAudit.setBypassReason
	 */
	@IsTest
	private static void shouldRespectBypassReasonLatchOnQuerySystemMode()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.setBypassReason('Customer data migration');

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toList();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('system-mode:' + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'withSystemMode should emit an object-qualified bypass audit entry');
		Assert.areEqual('Customer data migration', context.get(UTIL_BypassAudit.CONTEXT_REASON), 'Latched reason should appear in query bypass audit context');
	}

	/**
	 * @description Locates the most-recent bypass audit entry whose `target` context value matches
	 * the supplied target and returns its parsed inner context map. Returns `null` when no audit
	 * entry exists for the target. Helper used by the bypass-audit tests so each assertion focuses
	 * on the audit shape, not the JSON envelope or filter logic.
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The inner context map for the matching audit entry, or `null` if none exists.
	 */
	private static Map<String, Object> findBypassAuditContext(String target)
	{
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null
					&& target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET))
					&& UTIL_BypassAudit.SURFACE_QUERY.equals(context.get(UTIL_BypassAudit.CONTEXT_SURFACE)))
			{
				return context;
			}
		}
		return null;
	}

	/**
	 * @description Verifies groupBy(QRY_Function) renders the date-function expression into GROUP BY,
	 * and that a grouped function with no aliased entry in SELECT is still echoed into SELECT (a grouped
	 * expression is only skipped when an aliased copy is already selected).
	 */
	@IsTest
	private static void groupByFunctionRendersIntoGroupByClause()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY CALENDAR_MONTH(' + FIELD_DATE + ')'), 'groupBy(QRY_Function) should render the expression into GROUP BY');
			Assert.isTrue(soql.contains('count_Id, CALENDAR_MONTH(' + FIELD_DATE + ')'), 'A grouped function with no aliased entry should still be echoed into SELECT');
		}
	}

	/**
	 * @description Verifies the canonical bucket-and-aggregate query renders the function exactly once
	 * in SELECT, under its explicit alias. This proves addField(QRY_Function, alias) selects the
	 * expression, and the aggregate clause skips the GROUP BY echo that would repeat it.
	 */
	@IsTest
	private static void addFieldAndGroupByFunctionEmitItOnce()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.calendarMonth(Foobar__c.Date__c), 'dateBucket')
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toSoql();

			String selectClause = soql.substringBetween('SELECT ', ' FROM');
			String expectedSelect = 'COUNT(Id) count_Id, CALENDAR_MONTH(' + FIELD_DATE + ') dateBucket';
			Assert.areEqual(expectedSelect, selectClause, 'Expected a function that is both grouped and selected to appear once in SELECT, under its alias');
			Assert.isTrue(soql.contains('GROUP BY CALENDAR_MONTH(' + FIELD_DATE + ')'), 'GROUP BY should retain the bare function expression');
		}
	}

	/**
	 * @description Regression guard: a plain grouped field with no separate aliased entry in the field list is still
	 * echoed into SELECT: it is not treated as a duplicate.
	 */
	@IsTest
	private static void plainFieldGroupingStillEchoesIntoSelect()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(FIELD_PICKLIST)
					.toSoql();

			Assert.isTrue(soql.contains('count_Id, ' + FIELD_PICKLIST), 'Plain grouped field must still echo into SELECT');
			Assert.isTrue(soql.contains('GROUP BY ' + FIELD_PICKLIST), 'GROUP BY should contain the plain field');
		}
	}

	/**
	 * @description Regression guard: a GROUPING() expression is still emitted alongside the echoed
	 * grouped field: neither is treated as a duplicate.
	 */
	@IsTest
	private static void shouldStillEmitGroupingExpressionAlongsideItsGroupedField()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(FIELD_PICKLIST)
					.grouping(FIELD_PICKLIST)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUPING(' + FIELD_PICKLIST + ')'), 'GROUPING() expression must still be emitted');
			Assert.isTrue(soql.contains('count_Id, ' + FIELD_PICKLIST), 'Grouped field must still echo alongside GROUPING()');
		}
	}

	/**
	 * @description Verifies orderBy(QRY_Function) renders the date-function expression into ORDER BY,
	 * ascending (no direction keyword emitted by default).
	 */
	@IsTest
	private static void orderByFunctionAscendingRendersExpression()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.orderBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toSoql();

			Assert.isTrue(soql.contains('ORDER BY CALENDAR_MONTH(' + FIELD_DATE + ')'), 'orderBy(QRY_Function) should render the expression into ORDER BY');
			Assert.isFalse(soql.contains('CALENDAR_MONTH(' + FIELD_DATE + ') DESC'), 'Ascending order should not emit DESC');
		}
	}

	/**
	 * @description Verifies orderBy(QRY_Function, true) renders the date-function expression into ORDER
	 * BY with a DESC direction.
	 */
	@IsTest
	private static void orderByFunctionDescendingRendersDescending()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.orderBy(QRY_Function.calendarMonth(Foobar__c.Date__c), true)
					.toSoql();

			Assert.isTrue(soql.contains('ORDER BY CALENDAR_MONTH(' + FIELD_DATE + ') DESC'), 'orderBy(QRY_Function, true) should render DESC');
		}
	}

	/**
	 * @description End-to-end: buckets seeded records by calendar month, ascending, and reads back the
	 * bucket and the per-bucket count through the typed AggregateRow getters.
	 */
	@IsTest
	private static void dateBucketReportReturnsCountsPerCalendarMonth()
	{
		System.runAs(getTestAdmin())
		{
			for(Integer i = 0; i < 3; i++)
			{
				TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 10 + i)).build();
			}
			for(Integer i = 0; i < 2; i++)
			{
				TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 6, 10 + i)).build();
			}

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.calendarMonth(Foobar__c.Date__c), 'closeMonth')
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.orderBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toAggregateList();

			Assert.areEqual(2, rows.size(), 'Should return one bucket per calendar month');
			Assert.areEqual(3, rows[0].getInteger('closeMonth'), 'First bucket (ascending) should be March');
			Assert.areEqual(3, rows[0].getInteger('count_Id'), 'March bucket should count three records');
			Assert.areEqual(6, rows[1].getInteger('closeMonth'), 'Second bucket should be June');
			Assert.areEqual(2, rows[1].getInteger('count_Id'), 'June bucket should count two records');
		}
	}

	/**
	 * @description End-to-end: dayOnly truncates a datetime to a Date bucket, read back via getDate
	 * (the read-back outlier). Two identical instants bucket together regardless of time zone.
	 */
	@IsTest
	private static void dayOnlyBucketReadsBackAsDate()
	{
		System.runAs(getTestAdmin())
		{
			// Seed two identical instants and one distinct instant: identical instants resolve to the
			// same DAY_ONLY date in any time zone, so the bucket counts are independent of the org/user TZ.
			Datetime marchInstant = Datetime.newInstanceGmt(2026, 3, 15, 12, 0, 0);
			Datetime juneInstant = Datetime.newInstanceGmt(2026, 6, 20, 12, 0, 0);
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Datetime__c, marchInstant).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Datetime__c, marchInstant).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Datetime__c, juneInstant).build();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.dayOnly(Foobar__c.Datetime__c), 'theDay')
					.count(FIELD_ID)
					.groupBy(QRY_Function.dayOnly(Foobar__c.Datetime__c))
					.toAggregateList();

			Assert.areEqual(2, rows.size(), 'dayOnly should produce two day buckets');
			Map<Date, Integer> dayToCount = new Map<Date, Integer>();
			for(QRY_Builder.AggregateRow row : rows)
			{
				Date bucketDay = row.getDate('theDay');
				Assert.isNotNull(bucketDay, 'dayOnly bucket should read back as a Date');
				dayToCount.put(bucketDay, row.getInteger('count_Id'));
			}
			Assert.areEqual(2, dayToCount.size(), 'Should be two distinct day buckets');
			Assert.isTrue(dayToCount.values().contains(2), 'The two identical instants should bucket together with count two');
		}
	}

	/**
	 * @description End-to-end: the date-bucket report runs under USER_MODE and still returns buckets,
	 * confirming the function wrapper is transparent to field-level-security enforcement.
	 */
	@IsTest
	private static void calendarMonthBucketsUnderUserModeReturnBuckets()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 10)).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 11)).build();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.calendarMonth(Foobar__c.Date__c), 'closeMonth')
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.withUserMode()
					.toAggregateList();

			Assert.areEqual(1, rows.size(), 'Should return one calendar-month bucket under USER_MODE');
			Assert.areEqual(3, rows[0].getInteger('closeMonth'), 'Bucket should be March');
			Assert.areEqual(2, rows[0].getInteger('count_Id'), 'Both records should be counted under USER_MODE');
		}
	}

	/**
	 * @description End-to-end: a SELECT + GROUP BY date-bucket query with no aggregate returns the
	 * distinct date buckets and reads back via the explicit alias.
	 */
	@IsTest
	private static void distinctCalendarMonthsReadBackWithoutAggregate()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 10)).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 11)).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 6, 5)).build();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					// empty fields() drops the default Id from the selected fields so a GROUP BY with no aggregate is valid SOQL
					.fields(new List<SObjectField>())
					.addField(QRY_Function.calendarMonth(Foobar__c.Date__c), 'bucket')
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.orderBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toAggregateList();

			Assert.areEqual(2, rows.size(), 'Should return distinct calendar-month buckets without an aggregate');
			Assert.areEqual(3, rows[0].getInteger('bucket'), 'First bucket should be March');
			Assert.areEqual(6, rows[1].getInteger('bucket'), 'Second bucket should be June');
		}
	}

	/**
	 * @description Asserts condition(QRY_Function) seats a geolocation DISTANCE expression on the
	 * left-hand side of a WHERE comparison, so a proximity filter renders DISTANCE(...) < 5.
	 */
	@IsTest
	private static void proximityConditionRendersDistanceOnWhereLhs()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Account.SObjectType)
					.condition(QRY_Function.distanceInKilometers(Account.BillingAddress, 37.775, -122.418)).lessThan(5)
					.toSoql();

			Assert.isTrue
					(
							soql.containsIgnoreCase('DISTANCE(BillingAddress, GEOLOCATION(37.775,-122.418), \'km\') < 5'),
							'WHERE clause should place the DISTANCE function on the LHS of the comparison'
					);
		}
	}

	/**
	 * @description Locks the zero-builder-change ORDER BY claim: the new distance factory routes
	 * through the existing orderBy(QRY_Function) overload, so nearest-first ordering renders
	 * ORDER BY DISTANCE(...) ASC using only pre-existing builder methods.
	 */
	@IsTest
	private static void proximityOrderByRendersNearestFirst()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Account.SObjectType)
					.orderBy(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).ascending()
					.toSoql();

			Assert.isTrue
					(
							soql.containsIgnoreCase('ORDER BY DISTANCE(BillingAddress, GEOLOCATION(37.775,-122.418), \'mi\') ASC'),
							'orderBy(QRY_Function) should render nearest-first with no builder change'
					);
		}
	}

	/**
	 * @description Asserts the andCondition/orCondition function overloads mirror the SObjectField
	 * parity path, seating additional DISTANCE expressions on the LHS of AND and OR comparisons.
	 */
	@IsTest
	private static void proximityConditionsChainWithAndOrParity()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Account.SObjectType)
					.condition(QRY_Function.distanceInKilometers(Account.BillingAddress, 37.775, -122.418)).lessThan(5)
					.andCondition(QRY_Function.distanceInKilometers(Account.ShippingAddress, 40.7, -73.9)).greaterThan(1)
					.orCondition(QRY_Function.distanceInMiles(Account.BillingAddress, 51.5, -0.12)).lessThan(10)
					.toSoql();

			Assert.isTrue
					(
							soql.containsIgnoreCase('DISTANCE(BillingAddress, GEOLOCATION(37.775,-122.418), \'km\') < 5'),
							'condition(QRY_Function) seats the first DISTANCE on the WHERE LHS'
					);
			Assert.isTrue
					(
							soql.containsIgnoreCase('DISTANCE(ShippingAddress, GEOLOCATION(40.7,-73.9), \'km\') > 1'),
							'andCondition(QRY_Function) should seat its DISTANCE on the LHS'
					);
			Assert.isTrue
					(
							soql.containsIgnoreCase('DISTANCE(BillingAddress, GEOLOCATION(51.5,-0.12), \'mi\') < 10'),
							'orCondition(QRY_Function) should seat its DISTANCE on the LHS'
					);
			Assert.isTrue(soql.containsIgnoreCase(' OR '), 'orCondition(QRY_Function) should introduce an OR');
		}
	}

	/**
	 * @description Executes a proximity query end-to-end through toList() so the bind-registry render
	 * path (DISTANCE(...) < :bind) is proven to be valid, executable SOQL rather than only the literal
	 * toSoql() form. Runs without security so the assertion is about SOQL executability, not field-level
	 * access, and asserts an empty result in the data-free test context.
	 */
	@IsTest
	private static void proximityConditionExecutesAsValidSoql()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> nearby = QRY_Builder.selectFrom(Account.SObjectType)
					.withoutSecurity()
					.condition(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).lessThan(10)
					.orderBy(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).ascending()
					.toList();

			Assert.areEqual(0, nearby.size(), 'The bind-rendered DISTANCE query must execute as valid SOQL and return no rows in the data-free test context');
		}
	}

	/**
	 * @description Tests that a bypassed SYSTEM_MODE result stored in the cache is never served to a later call
	 * that asked for sharing to be enforced. Same SOQL, same binds, inside the TTL: the only difference is the
	 * sharing dial, which is the shape of a shared selector one caller bypasses for an administrator console and
	 * another calls with sharing enforced from a user-facing path.
	 */
	@IsTest
	private static void cachedBypassedResultIsNeverServedToASharingEnforcedCaller()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CACHE_PROBE_NAME)
					.withCount(CACHE_PROBE_ROWS)
					.buildList();
		}

		Integer bypassedRows;
		Integer enforcedRows;

		Test.startTest();
		System.runAs(getTestAdmin())
		{
			bypassedRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().bypassSharing().withCache(CACHE_PROBE_TTL_SECONDS).toList().size();
		}
		System.runAs(restricted)
		{
			enforcedRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().withSharing().withCache(CACHE_PROBE_TTL_SECONDS).toList().size();
		}
		Test.stopTest();

		Assert.areEqual(CACHE_PROBE_ROWS, bypassedRows, 'The bypassed read stores every row');
		Assert.areEqual(0, enforcedRows, 'The sharing-enforced read must not be served the bypassed rows from the cache; 3 here is a disclosure through the cache key');
	}

	/**
	 * @description Tests that a cached result produced with sharing explicitly enforced is keyed per user: the
	 * owner stores every row, and another user running the identical sharing-enforced query inside the TTL is
	 * served that user's own population instead of the owner's cached rows.
	 */
	@IsTest
	private static void cachedSharingAppliedResultIsKeyedPerUser()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CACHE_PROBE_NAME)
					.withCount(CACHE_PROBE_ROWS)
					.buildList();
		}

		Integer ownerRows;
		Integer otherUserRows;

		Test.startTest();
		System.runAs(getTestAdmin())
		{
			ownerRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().withSharing().withCache(CACHE_PROBE_TTL_SECONDS).toList().size();
		}
		System.runAs(restricted)
		{
			otherUserRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().withSharing().withCache(CACHE_PROBE_TTL_SECONDS).toList().size();
		}
		Test.stopTest();

		Assert.areEqual(CACHE_PROBE_ROWS, ownerRows, 'The owner reaches every row with sharing enforced');
		Assert.areEqual(0, otherUserRows, 'Another user running the identical sharing-enforced query must see none of the owner\'s rows; 3 here means the cache served the '
				+ 'owner\'s sharing-enforced result, so the key lost its user segment');
	}

	/**
	 * @description Tests that the same user's read with sharing explicitly enforced is never served rows a
	 * without-sharing caller read under inherited sharing: the inherited-dial read is not cached at all, so the
	 * enforced lookup finds nothing, which also covers two inherited-dial callers with different class sharing.
	 */
	@IsTest
	private static void cachedInheritedSharingResultIsNeverServedToTheSameUserEnforcingSharing()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CACHE_PROBE_NAME)
					.withCount(CACHE_PROBE_ROWS)
					.buildList();
		}

		Integer inheritedRows;
		Integer enforcedRows;

		Test.startTest();
		System.runAs(restricted)
		{
			inheritedRows = new WithoutSharingCachedReader().countRows();
			enforcedRows = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().withSharing().withCache(CACHE_PROBE_TTL_SECONDS).toList().size();
		}
		Test.stopTest();

		Assert.areEqual(CACHE_PROBE_ROWS, inheritedRows, 'Under inherited sharing from a without-sharing caller the user reaches every row');
		Assert.areEqual(0, enforcedRows, 'The same user asking for sharing to be enforced must not be served the unshared rows from the cache; 3 here means an inherited-dial '
				+ 'read was cached or the key does not carry the sharing dial');
	}

	/**
	 * @description Tests that an inherited-dial cached read is never served across caller sharing postures:
	 * the same user runs the identical query with caching from a without-sharing class and then from a
	 * with-sharing class, both leaving the sharing setting to the calling class, and each must receive its
	 * own class's population. Serving the second read from the first read's cache entry would hand a
	 * sharing-enforced caller every row a without-sharing caller saw, which is why a read whose sharing the
	 * engine cannot see is not cached at all.
	 */
	@IsTest
	private static void inheritedDialCachedReadIsNeverServedAcrossCallerSharingPostures()
	{
		User restricted = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CACHE_PROBE_NAME)
					.withCount(CACHE_PROBE_ROWS)
					.buildList();
		}

		Integer withoutSharingRows;
		Integer withSharingRows;

		Test.startTest();
		System.runAs(restricted)
		{
			withoutSharingRows = new WithoutSharingCachedReader().countRows();
			withSharingRows = new WithSharingCachedReader().countRows();
		}
		Test.stopTest();

		Assert.areEqual(CACHE_PROBE_ROWS, withoutSharingRows, 'From a without-sharing caller the user reaches every row under inherited sharing');
		Assert.areEqual(0, withSharingRows,
				'From a with-sharing caller the same user must see none of the unshared rows; ' + CACHE_PROBE_ROWS + ' here means an inherited-dial '
				+ 'read was cached and served across caller sharing postures');
	}

	/**
	 * @description Tests that a user-mode cached read with sharing left inherited applies the running user's sharing,
	 * even from a without-sharing class, and that the memory hit returns the same rows as the miss. Foobar__c is
	 * Private, so the restricted user reaches only the rows it owns; the admin's rows must appear in neither read,
	 * and the hit must run no query. The admin runs the identical read first in the same transaction, so the
	 * restricted user's first read must miss: the in-memory key carries the running user, and a key without it would
	 * serve the admin's six rows.
	 */
	@IsTest
	private static void userModeInheritedSharingAppliesRunningUsersSharing()
	{
		User restricted = TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, RESTRICTED_USER_COMPANY, READ_ONLY_PERMISSION_SET);
		Set<Id> restrictedRowIds = seedRestrictedAndAdminRows(restricted, new Set<Id>());
		WithoutSharingUserModeCachedReader reader = new WithoutSharingUserModeCachedReader();

		Set<Id> missRowIds;
		Set<Id> hitRowIds;
		Integer hitQueries;

		Test.startTest();
		System.runAs(getTestAdmin())
		{
			reader.readRows();
		}
		System.runAs(restricted)
		{
			missRowIds = new Map<Id, SObject>(reader.readRows()).keySet();
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			hitRowIds = new Map<Id, SObject>(reader.readRows()).keySet();
			hitQueries = UTIL_Limits.soqlQueries().used() - queriesBefore;
		}
		Test.stopTest();

		Assert.areEqual(restrictedRowIds, missRowIds, 'The miss should return exactly the rows the restricted user owns');
		Assert.areEqual(restrictedRowIds, hitRowIds, 'The memory hit should return exactly the rows the restricted user owns');
		Assert.areEqual(0, hitQueries, 'The repeat should be served from memory');
	}

	/**
	 * @description Tests that a system-mode transaction-scope read with sharing bypassed is never served to the same
	 * user's identical read with sharing enforced. Foobar__c is Private: the bypassed read reaches all six rows, and
	 * the enforced read must run its own query and return only the three rows the restricted user owns. Only the
	 * sharing segment of the in-memory key tells the two reads apart.
	 */
	@IsTest
	private static void inMemoryKeySeparatesSharingSettings()
	{
		User restricted = TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, RESTRICTED_USER_COMPANY, READ_ONLY_PERMISSION_SET);
		Set<Id> allRowIds = new Set<Id>();
		Set<Id> restrictedRowIds = seedRestrictedAndAdminRows(restricted, allRowIds);

		Set<Id> bypassedRowIds;
		Set<Id> enforcedRowIds;
		Integer enforcedQueries;

		Test.startTest();
		System.runAs(restricted)
		{
			WithoutSharingSystemModeTransactionReader reader = new WithoutSharingSystemModeTransactionReader();
			bypassedRowIds = new Map<Id, SObject>(reader.readBypassingSharing()).keySet();
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			enforcedRowIds = new Map<Id, SObject>(reader.readWithSharing()).keySet();
			enforcedQueries = UTIL_Limits.soqlQueries().used() - queriesBefore;
		}
		Test.stopTest();

		Assert.areEqual(CACHE_PROBE_ROWS * 2, allRowIds.size(), 'Both owners\' rows should be seeded');
		Assert.areEqual(allRowIds, bypassedRowIds, 'The bypassed read should return exactly every seeded row');
		Assert.areEqual(restrictedRowIds, enforcedRowIds, 'The enforced read should return exactly the rows the restricted user owns');
		Assert.areEqual(1, enforcedQueries, 'The enforced read should run its own query, never take the bypassed result');
	}

	/**
	 * @description Seeds, as the test admin, cache-probe rows owned by the restricted user and as many owned by the
	 * admin.
	 *
	 * @param restricted The user who owns the first set of rows.
	 * @param allRowIds Receives the ids of every seeded row, both owners'.
	 *
	 * @return The ids of the rows the restricted user owns.
	 */
	private static Set<Id> seedRestrictedAndAdminRows(User restricted, Set<Id> allRowIds)
	{
		Set<Id> restrictedRowIds;
		System.runAs(getTestAdmin())
		{
			restrictedRowIds = new Map<Id, SObject>(TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CACHE_PROBE_NAME)
					.withOverride(Foobar__c.OwnerId, restricted.Id)
					.withCount(CACHE_PROBE_ROWS)
					.buildList()).keySet();
			allRowIds.addAll(restrictedRowIds);
			allRowIds.addAll(new Map<Id, SObject>(TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CACHE_PROBE_NAME)
					.withCount(CACHE_PROBE_ROWS)
					.buildList()).keySet());
		}
		return restrictedRowIds;
	}

	/**
	 * @description Tests that a paged read with caching requested returns each page's own rows and the true
	 * total, including when the same page is re-fetched inside the TTL. A cache hit can only restore the record
	 * list, never the total or the cursor, so a re-fetched page would come back with the page size as its total;
	 * the engine therefore leaves cursor-backed reads out of the cache altogether.
	 */
	@IsTest
	private static void pagedReadWithCacheReturnsEachPageAndTheTrueTotal()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, CACHE_PROBE_NAME)
					.withCount(PAGING_PROBE_ROWS)
					.buildList();

			Test.startTest();
			QRY_Builder.QueryPage firstFetch = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withSystemMode()
					.withSharing()
					.orderBy(Foobar__c.Id)
					.withCache(CACHE_PROBE_TTL_SECONDS)
					.getPage(1, PAGING_PROBE_PAGE_SIZE);
			QRY_Builder.QueryPage refetchedFirstPage = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withSystemMode()
					.withSharing()
					.orderBy(Foobar__c.Id)
					.withCache(CACHE_PROBE_TTL_SECONDS)
					.getPage(1, PAGING_PROBE_PAGE_SIZE);
			QRY_Builder.QueryPage secondPage = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withSystemMode()
					.withSharing()
					.orderBy(Foobar__c.Id)
					.withCache(CACHE_PROBE_TTL_SECONDS)
					.getPage(2, PAGING_PROBE_PAGE_SIZE);
			Test.stopTest();

			Set<Id> firstPageIds = new Map<Id, SObject>(firstFetch.records).keySet();
			Set<Id> secondPageIds = new Map<Id, SObject>(secondPage.records).keySet();

			Assert.areEqual(PAGING_PROBE_PAGE_SIZE, firstFetch.records.size(), 'Page one carries a full page');
			Assert.areEqual(PAGING_PROBE_ROWS, firstFetch.totalRecords, 'Page one reports the true total, not the page size');
			Assert.areEqual(PAGING_PROBE_ROWS, refetchedFirstPage.totalRecords, 'Re-fetching page one inside the TTL must still report the true total; the page size here '
					+ 'means a cursor read was served a cached entry that cannot carry the total');
			Assert.areEqual(PAGING_PROBE_PAGE_SIZE, secondPage.records.size(), 'Page two carries a full page');
			Assert.isFalse(firstPageIds.containsAll(secondPageIds) && secondPageIds.containsAll(firstPageIds), 'Page two must be a different slice from page one');
			Assert.areEqual(PAGING_PROBE_ROWS, secondPage.totalRecords, 'Page two reports the true total, not the page size');
		}
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
	 * @description With-sharing queueable that drains a cursor in its own transaction and reports the row
	 * count through the static counter, following the QRY_LocatorProbeBatch_TEST instrument precedent. A
	 * queueable may be an inner class (only Database.Batchable demands a top-level one), and a queueable is
	 * the platform's documented cross-transaction consumer for Apex cursors. A test probe this small needs
	 * no Finalizer.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	private with sharing class CursorProbeFetchJob implements Queueable
	{
		/**
		 * @description The cursor the test opened. The job reads all of its rows in its own transaction, to show
		 * what a cursor delivers after it is handed to another transaction.
		 */
		private final Database.Cursor probeCursor;

		/**
		 * @description Captures the cursor the asserting test created.
		 *
		 * @param probeCursor The cursor to drain in the queueable's transaction.
		 */
		public CursorProbeFetchJob(Database.Cursor probeCursor)
		{
			this.probeCursor = probeCursor;
		}

		/**
		 * @description Drains the cursor and records how many rows the fetch returned.
		 *
		 * @param context The queueable context.
		 */
		public void execute(QueueableContext context)
		{
			Integer total = probeCursor.getNumRecords();
			cursorRowsSeenInQueueable = total == 0 ? 0 : probeCursor.fetch(0, total).size();
		}
	}

	/**
	 * @description A without-sharing caller for the cache-key tests: a query run through it under inherited
	 * sharing reaches every row, which is the population a sharing-enforced read by the same user must never be
	 * served from the cache.
	 */
	private without sharing class WithoutSharingCachedReader
	{
		/**
		 * @description Runs the cache-probe query under this class's sharing with caching on.
		 *
		 * @return The number of rows returned.
		 */
		public Integer countRows()
		{
			return QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().withCache(CACHE_PROBE_TTL_SECONDS).toList().size();
		}
	}

	/**
	 * @description The with-sharing counterpart of WithoutSharingCachedReader: the identical inherited-dial
	 * cached read issued from a with-sharing class, which must never be served the without-sharing
	 * population the same user just cached.
	 */
	private with sharing class WithSharingCachedReader
	{
		/**
		 * @description Runs the cache-probe query under this class's sharing with caching on.
		 *
		 * @return The number of rows returned.
		 */
		public Integer countRows()
		{
			return QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().withCache(CACHE_PROBE_TTL_SECONDS).toList().size();
		}
	}

	/**
	 * @description A without-sharing caller of a user-mode cached read with sharing left inherited: the class would
	 * reach every row, but user mode applies the running user's sharing, so the read returns only that user's rows.
	 */
	private without sharing class WithoutSharingUserModeCachedReader
	{
		/**
		 * @description Runs the cache-probe query in user mode, with sharing left inherited and caching on.
		 *
		 * @return The rows returned.
		 */
		public List<SObject> readRows()
		{
			return QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withUserMode()
					.condition(Foobar__c.Name).equals(CACHE_PROBE_NAME)
					.withCache(CACHE_PROBE_TTL_SECONDS)
					.toList();
		}
	}

	/**
	 * @description A without-sharing caller of two system-mode transaction-scope reads of the cache-probe rows that
	 * differ only in their sharing setting, so the in-memory key's sharing segment is the only thing between them.
	 */
	private without sharing class WithoutSharingSystemModeTransactionReader
	{
		/**
		 * @description Runs the cache-probe query in system mode with sharing bypassed, kept in memory for the transaction.
		 *
		 * @return The rows returned.
		 */
		public List<SObject> readBypassingSharing()
		{
			return buildProbeRead().bypassSharing().toList();
		}

		/**
		 * @description Runs the cache-probe query in system mode with sharing enforced, kept in memory for the transaction.
		 *
		 * @return The rows returned.
		 */
		public List<SObject> readWithSharing()
		{
			return buildProbeRead().withSharing().toList();
		}

		/**
		 * @description Builds the system-mode, transaction-scope cache-probe read both methods share.
		 *
		 * @return The builder.
		 */
		private QRY_Builder.Builder buildProbeRead()
		{
			return QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withSystemMode()
					.condition(Foobar__c.Name).equals(CACHE_PROBE_NAME)
					.withCache(UTIL_Cache.Scope.IN_TRANSACTION, null);
		}
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

	/**
	 * @description The builder call that receives a crafted text in a test. Each value names one call; applyCraftedText
	 * makes it.
	 */
	private enum CraftedEntry
	{
		/**
		 * @description condition(text) followed by equals, with the value of the case.
		 */
		CONDITION,
		/**
		 * @description condition(text) alone, with no operator after it.
		 */
		CONDITION_WITHOUT_OPERATOR,
		/**
		 * @description andCondition(text) followed by equals, with the value of the case.
		 */
		AND_CONDITION,
		/**
		 * @description orCondition(text) followed by equals, with the value of the case.
		 */
		OR_CONDITION,
		/**
		 * @description orderBy(text), which writes the text as the sort order.
		 */
		ORDER_BY,
		/**
		 * @description orderBy(text, true), which adds DESC NULLS LAST after the text.
		 */
		ORDER_BY_DESCENDING,
		/**
		 * @description orderBy(text, true, false), which adds DESC NULLS FIRST after the text.
		 */
		ORDER_BY_DESCENDING_NULLS_FIRST,
		/**
		 * @description groupBy(text).
		 */
		GROUP_BY,
		/**
		 * @description count(text).
		 */
		COUNT,
		/**
		 * @description countDistinct(text).
		 */
		COUNT_DISTINCT,
		/**
		 * @description grouping(text).
		 */
		GROUPING,
		/**
		 * @description withDataCategory(text), followed by at with a valid category.
		 */
		DATA_CATEGORY_GROUP,
		/**
		 * @description The DataCategoryBuilder constructor with the text as the group, followed by at with a valid category.
		 */
		DATA_CATEGORY_BUILDER,
		/**
		 * @description at(text) after withDataCategory with a valid group.
		 */
		AT,
		/**
		 * @description at with a list that holds the text, after withDataCategory with a valid group.
		 */
		AT_LIST,
		/**
		 * @description above(text) after withDataCategory with a valid group.
		 */
		ABOVE,
		/**
		 * @description above with a list that holds the text, after withDataCategory with a valid group.
		 */
		ABOVE_LIST,
		/**
		 * @description below(text) after withDataCategory with a valid group.
		 */
		BELOW,
		/**
		 * @description below with a list that holds the text, after withDataCategory with a valid group.
		 */
		BELOW_LIST,
		/**
		 * @description aboveOrBelow(text) after withDataCategory with a valid group. It is not called ABOVE_OR_BELOW,
		 * because Apex keeps that word for queries.
		 */
		EITHER_SIDE,
		/**
		 * @description aboveOrBelow with a list that holds the text, after withDataCategory with a valid group.
		 */
		EITHER_SIDE_LIST,
		/**
		 * @description relatedField(text).
		 */
		RELATED_FIELD,
		/**
		 * @description relatedFields with a list that holds the text.
		 */
		RELATED_FIELDS,
		/**
		 * @description subselect with a Contact query and the text as the relationship name.
		 */
		SUBSELECT,
		/**
		 * @description condition on Id followed by isIn with a Contact query whose only selected text is the text.
		 */
		IS_IN,
		/**
		 * @description condition on Id followed by notIn with a Contact query whose only selected text is the text.
		 */
		NOT_IN
	}

	/**
	 * @description One crafted text for a test: the builder call that receives it, a short name for failure messages,
	 * and the query it is given to. Each case has its own query, so one case cannot change another.
	 */
	private inherited sharing class CraftedCase
	{
		/**
		 * @description The builder call that receives the text.
		 */
		public final CraftedEntry entry;
		/**
		 * @description A short description of the text, used in failure messages.
		 */
		public final String caseName;
		/**
		 * @description The query the text is given to. It may already hold valid parts, such as a first condition.
		 */
		public final QRY_Builder.Builder query;
		/**
		 * @description The text that is not a field name.
		 */
		public final String craftedText;
		/**
		 * @description The value a condition compares with, for the condition calls.
		 */
		public Object comparedValue;

		/**
		 * @description Creates a case.
		 *
		 * @param entry The builder call that receives the text
		 * @param caseName A short description of the text
		 * @param query The query the text is given to
		 * @param craftedText The text that is not a field name
		 */
		public CraftedCase(CraftedEntry entry, String caseName, QRY_Builder.Builder query, String craftedText)
		{
			this.entry = entry;
			this.caseName = caseName;
			this.query = query;
			this.craftedText = craftedText;
		}

		/**
		 * @description Sets the value a condition compares with.
		 *
		 * @param value The value
		 *
		 * @return This case, so the call can be chained
		 */
		public CraftedCase withComparedValue(Object value)
		{
			comparedValue = value;
			return this;
		}
	}
}