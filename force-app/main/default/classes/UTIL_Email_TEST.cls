// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Validates UTIL_Email behaviour: address validation, deliverability detection,
 * and email dispatch.
 *
 * @see UTIL_Email
 *
 * @author Jason van Beukering
 *
 * @group Email
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_Email_TEST
{
	/**
	 * @description Assertion label for valid address checks.
	 */
	private static final String EXPECTED_VALID = 'Address should pass validation';
	/**
	 * @description Assertion label for invalid address checks.
	 */
	private static final String EXPECTED_INVALID = 'Address should fail validation';
	/**
	 * @description Assertion label for successful dispatch.
	 */
	private static final String EXPECTED_DISPATCHED = 'Email invocation count should increase';
	/**
	 * @description Assertion label when dispatch is skipped.
	 */
	private static final String EXPECTED_NOT_DISPATCHED = 'Email invocation count should remain unchanged';

	/**
	 * @description Verifies the default pattern accepts standard and international addresses.
	 */
	@IsTest
	private static void shouldAcceptValidAddresses()
	{
		Assert.isTrue(UTIL_Email.isValidEmailAddress('user@domain.co'), EXPECTED_VALID);
		Assert.isTrue(UTIL_Email.isValidEmailAddress('José.blah@españa.es'), EXPECTED_VALID);
	}

	/**
	 * @description Verifies the default pattern rejects malformed addresses and blanks.
	 */
	@IsTest
	private static void shouldRejectInvalidAddresses()
	{
		Assert.isTrue(UTIL_Email.isNotValidEmailAddress('  '), EXPECTED_INVALID);
		Assert.isTrue(UTIL_Email.isNotValidEmailAddress('user'), EXPECTED_INVALID);
		Assert.isTrue(UTIL_Email.isNotValidEmailAddress('user@'), EXPECTED_INVALID);
		Assert.isTrue(UTIL_Email.isNotValidEmailAddress('user@d'), EXPECTED_INVALID);
		Assert.isTrue(UTIL_Email.isNotValidEmailAddress('user@d.x'), EXPECTED_INVALID);
		Assert.isTrue(UTIL_Email.isNotValidEmailAddress(null), EXPECTED_INVALID);
	}

	/**
	 * @description Verifies sendEmail dispatches correctly for both HTML and plain text.
	 */
	@IsTest
	private static void shouldSendEmail()
	{
		List<String> to = new List<String> {'recipient@domain.com'};
		Integer baseline = UTIL_Limits.emailInvocations().used();

		UTIL_Email.sendEmail(to, 'Subject', '<p>Body</p>', true, null);
		Assert.areEqual(baseline + 1, UTIL_Limits.emailInvocations().used(), EXPECTED_DISPATCHED);

		UTIL_Email.sendEmail(to, 'Subject', 'Plain text body', false, null);
		Assert.areEqual(baseline + 2, UTIL_Limits.emailInvocations().used(), EXPECTED_DISPATCHED);
	}

	/**
	 * @description Verifies sendEmail attaches files when provided.
	 */
	@IsTest
	private static void shouldSendEmailWithAttachments()
	{
		List<String> to = new List<String> {'recipient@domain.com'};
		Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
		attachment.setFileName('test.txt');
		attachment.setBody(Blob.valueOf('content'));
		Integer baseline = UTIL_Limits.emailInvocations().used();

		UTIL_Email.sendEmail(to, 'Subject', 'Body', false, new List<Messaging.EmailFileAttachment> {attachment});

		Assert.areEqual(baseline + 1, UTIL_Limits.emailInvocations().used(), EXPECTED_DISPATCHED);
	}

	/**
	 * @description Verifies dispatch is skipped for null and empty recipient lists.
	 */
	@IsTest
	private static void shouldSkipWhenRecipientsAbsent()
	{
		Integer baseline = UTIL_Limits.emailInvocations().used();

		UTIL_Email.sendEmail(null, 'Subject', 'Body', false, null);
		Assert.areEqual(baseline, UTIL_Limits.emailInvocations().used(), EXPECTED_NOT_DISPATCHED);

		UTIL_Email.sendEmail(new List<String>(), 'Subject', 'Body', false, null);
		Assert.areEqual(baseline, UTIL_Limits.emailInvocations().used(), EXPECTED_NOT_DISPATCHED);
	}

	/**
	 * @description Verifies the deliverability probe and the forced-exception fallback path.
	 */
	@IsTest
	private static void shouldDetectDeliverabilityLevel()
	{
		Test.startTest();

		UTIL_Email.DeliverabilityAccessLevel natural = UTIL_Email.getEmailDeliverabilityAccessLevel();
		Assert.isNotNull(natural, 'Natural probe should return a value');

		UTIL_Email.forceEmailCapacityException = true;
		UTIL_Email.DeliverabilityAccessLevel fallback = UTIL_Email.getEmailDeliverabilityAccessLevel();
		Assert.areEqual(UTIL_Email.DeliverabilityAccessLevel.NO_ACCESS, fallback, 'Fallback in test context should return NO_ACCESS');

		Test.stopTest();
	}
}