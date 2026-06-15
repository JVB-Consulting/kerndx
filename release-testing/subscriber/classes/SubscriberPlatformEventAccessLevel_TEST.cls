// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber proof of the Summer '26 (API 67) platform-event AccessLevel contract that
 * the framework's logging and event-monitoring paths depend on. These tests use `System.runAs`
 * (only available in @IsTest context) to impersonate a Standard User who holds no kern managed-package
 * permission sets — and therefore no create access to `kern__LogEntryEvent__e` — then exercise the two
 * `EventBus.publishWithAccessLevel` pins the v67 uplift introduced:
 *
 * - SYSTEM_MODE always-emit. LOG_Engine publishes `LogEntryEvent__e` via
 *   `EventBus.publishWithAccessLevel(events, AccessLevel.SYSTEM_MODE)`, so a low-permission user's log
 *   entry must still publish and persist even though they cannot create the event object themselves.
 *   Guards the always-emit pins that keep the framework audit trail flowing for every user.
 * - USER_MODE publish enforcement. `CTRL_EventMonitor.publishCustomPlatformEvent` publishes via
 *   `EventBus.publishWithAccessLevel(event, AccessLevel.USER_MODE)` and throws on `!success`, so the
 *   same low-permission user must be DENIED a USER_MODE publish of the very same event — proving the
 *   access level actually enforces create permission (and is the reason the logging path pins
 *   SYSTEM_MODE).
 *
 * The two halves are mutually validating: the same Standard User is denied a USER_MODE publish of
 * `kern__LogEntryEvent__e` (so they genuinely lack create) yet a `kern.LOG_Builder` entry emitted within
 * that same low-permission runAs scope still persists end-to-end — which is only possible because the
 * logging path publishes in SYSTEM_MODE. (The persisted entry is located by its unique ClassMethod
 * stamp, not the user id, which the framework stamps at buffer-flush time — see
 * `lowPermUserLogBuilderEntryPersistsEndToEnd`.)
 *
 * This runtime-enforcement layer is what anonymous Apex cannot reach (`System.runAs` is test-only); the
 * anonymous-Apex sections 16/65 cover the synchronous `LOG_Builder` surface, and `CTRL_EventMonitor_TEST`
 * covers the `@AuraEnabled` publisher itself.
 *
 * @see kern.LOG_Builder
 * @see kern.CTRL_EventMonitor
 *
 * @author Jason van Beukering
 *
 * @group Security
 *
 * @date June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=false)
private class SubscriberPlatformEventAccessLevel_TEST
{
	/**
	 * @description ClassMethod stamp identifying this suite's low-permission `LOG_Builder` emission so
	 * the persisted entry can be located unambiguously.
	 */
	private static final String EMIT_AT = 'SubscriberPlatformEventAccessLevel.systemModeEmit';

	/**
	 * @description Message text the low-permission SYSTEM_MODE emission carries.
	 */
	private static final String EMIT_MESSAGE = 'Low-permission system-mode log entry';

	/**
	 * @description INFO log level literal as persisted on `kern__LogEntry__c.kern__LogLevel__c`.
	 */
	private static final String LOG_LEVEL_INFO = 'INFO';

	/**
	 * @description The test-running user holds create on `kern__LogEntryEvent__e`, so a USER_MODE publish
	 * of it must succeed — the positive half of the v67 USER_MODE publish contract that
	 * `CTRL_EventMonitor.publishCustomPlatformEvent` relies on.
	 */
	@IsTest
	private static void userModePublishSucceedsForPermittedUser()
	{
		Test.startTest();

		Database.SaveResult saveResult = EventBus.publishWithAccessLevel(newProbeEvent(), AccessLevel.USER_MODE);

		Test.stopTest();

		Assert.isTrue(saveResult.isSuccess(), 'A permitted user should publish kern__LogEntryEvent__e in USER_MODE');
	}

	/**
	 * @description A Standard User with no kern permission sets lacks create on `kern__LogEntryEvent__e`,
	 * so a USER_MODE publish must be denied — proving `AccessLevel.USER_MODE` actually enforces create
	 * permission (the enforcement `CTRL_EventMonitor` depends on, and the reason the logging path pins
	 * SYSTEM_MODE). A denial may surface as either `!isSuccess()` or a thrown access exception.
	 */
	@IsTest
	private static void userModePublishDeniedForLowPermUser()
	{
		User standardUser = createStandardUser();
		Boolean denied = false;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				Database.SaveResult saveResult = EventBus.publishWithAccessLevel(newProbeEvent(), AccessLevel.USER_MODE);
				denied = !saveResult.isSuccess();
			}
			catch(Exception accessError)
			{
				denied = true;
			}
		}

		Test.stopTest();

		Assert.isTrue(denied, 'A low-permission user without kern__LogEntryEvent__e create should be denied a USER_MODE publish');
	}

	/**
	 * @description The same low-permission Standard User must still publish `kern__LogEntryEvent__e` in
	 * SYSTEM_MODE — the always-emit guarantee at the publish-API level that LOG_Engine relies on so
	 * logging works for every user irrespective of their CRUD.
	 */
	@IsTest
	private static void systemModePublishSucceedsForLowPermUser()
	{
		User standardUser = createStandardUser();
		Boolean succeeded = false;

		Test.startTest();

		System.runAs(standardUser)
		{
			Database.SaveResult saveResult = EventBus.publishWithAccessLevel(newProbeEvent(), AccessLevel.SYSTEM_MODE);
			succeeded = saveResult.isSuccess();
		}

		Test.stopTest();

		Assert.isTrue(succeeded, 'A low-permission user should still publish kern__LogEntryEvent__e in SYSTEM_MODE (always-emit)');
	}

	/**
	 * @description End-to-end SYSTEM_MODE always-emit: an entry emitted through `kern.LOG_Builder` while
	 * running as a low-permission Standard User is published (the framework pins SYSTEM_MODE) and
	 * persisted to `kern__LogEntry__c` across platform-event delivery — guarding the LOG_Engine
	 * always-emit pins end-to-end on a real v67 org. The entry is located by its unique ClassMethod
	 * stamp (the framework stamps `kern__UserId__c` at buffer-flush time, not emit time, so it is not a
	 * reliable locator here); the low-permission user's own access differential is proven directly by
	 * `userModePublishDeniedForLowPermUser` + `systemModePublishSucceedsForLowPermUser`.
	 */
	@IsTest
	private static void lowPermUserLogBuilderEntryPersistsEndToEnd()
	{
		User standardUser = createStandardUser();

		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		System.runAs(standardUser)
		{
			kern.LOG_Builder.build().info(EMIT_MESSAGE).at(EMIT_AT).emit();
		}

		Test.getEventBus().deliver();
		Test.stopTest();

		List<kern__LogEntry__c> entries =
		[
				SELECT kern__LogLevel__c,
						kern__Message__c
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c = :EMIT_AT
		];

		Assert.isFalse(entries.isEmpty(), 'A low-permission user\'s LOG_Builder entry should persist via SYSTEM_MODE always-emit');
		Assert.areEqual(LOG_LEVEL_INFO, entries[0].kern__LogLevel__c, 'The persisted entry should be the INFO entry that was emitted');
		Assert.areEqual(EMIT_MESSAGE, entries[0].kern__Message__c, 'The persisted entry should carry the emitted message');
	}

	/**
	 * @description Builds a minimally-populated `kern__LogEntryEvent__e` for the publish-contract tests
	 * so the framework's persisting subscriber processes a well-formed event on delivery.
	 *
	 * @return A `kern__LogEntryEvent__e` carrying an INFO payload.
	 */
	private static kern__LogEntryEvent__e newProbeEvent()
	{
		return new kern__LogEntryEvent__e(
				kern__LogLevel__c = LOG_LEVEL_INFO,
				kern__Message__c = EMIT_MESSAGE,
				kern__ClassMethod__c = EMIT_AT
		);
	}

	/**
	 * @description Creates a Standard User with no kern managed-package permission sets (so no
	 * `kern__LogEntryEvent__e` create). The test context never commits this user beyond the
	 * `System.runAs` scope.
	 *
	 * @return The Standard User instance.
	 */
	private static User createStandardUser()
	{
		Profile standardProfile =
		[
				SELECT Id
				FROM Profile
				WHERE Name = 'Standard User'
				LIMIT 1
		];
		String suffix = String.valueOf(Crypto.getRandomInteger()).right(8);
		User user = new User
				(
						FirstName = 'Access',
						LastName = 'LevelProbe',
						Email = 'access-level-probe-' + suffix + '@kerndx.test',
						Username = 'access-level-probe-' + suffix + '@kerndx.test.invalid',
						Alias = 'alp' + suffix.right(3),
						TimeZoneSidKey = 'America/New_York',
						LocaleSidKey = 'en_US',
						EmailEncodingKey = 'UTF-8',
						LanguageLocaleKey = 'en_US',
						ProfileId = standardProfile.Id
				);
		insert User;
		return User;
	}
}
