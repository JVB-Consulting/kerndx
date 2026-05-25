// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Utility class for validating and sending emails within the Salesforce platform.
 * Includes a unicode-aware email validation pattern and a two-step deliverability detection mechanism.
 *
 * @see UTIL_Email_TEST
 *
 * @author Jason van Beukering
 *
 * @group Email
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * Boolean valid = UTIL_Email.isValidEmailAddress('user@example.com');
 * UTIL_Email.sendEmail(new List<String>{'admin@example.com'}, 'Alert', 'System notification body', false, null);
 * UTIL_Email.DeliverabilityAccessLevel level = UTIL_Email.getEmailDeliverabilityAccessLevel();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.AvoidBooleanMethodParameters')
global inherited sharing class UTIL_Email
{
	/**
	 * @description Unicode-aware pattern for email validation. Accepts international characters.
	 */
	private static final Pattern DEFAULT_EMAIL_PATTERN = Pattern.compile('^[\\p{L}\\p{N}_.+-]+@[\\p{L}\\p{N}-]+(?:\\.[\\p{L}\\p{N}-]{2,})+$');

	/**
	 * @description Substring marker used to detect the "No access" option in the settings page HTML.
	 */
	private static final String NO_ACCESS_MARKER = ' selected="selected">No access</option>';

	/**
	 * @description Lookup from settings-page label to typed enum value.
	 */
	private static final Map<String, DeliverabilityAccessLevel> LABEL_TO_LEVEL = new Map<String, DeliverabilityAccessLevel>
	{
			'All email' => DeliverabilityAccessLevel.ALL_EMAIL,
			'No access' => DeliverabilityAccessLevel.NO_ACCESS,
			'System email only' => DeliverabilityAccessLevel.SYSTEM_EMAIL_ONLY
	};

	/**
	 * @description When set to true in a test method, forces the deliverability check to take the
	 * exception path so the fallback HTML-parsing logic can be covered.
	 */
	@TestVisible
	private static Boolean forceEmailCapacityException = false;

	/**
	 * @description Enum representing the three possible email deliverability settings in a Salesforce org.
	 *
	 * @since 1.0
	 */
	global enum DeliverabilityAccessLevel
	{
		/**
		 * @description All outbound email — user-initiated and Apex — is permitted.
		 */
		ALL_EMAIL,
		/**
		 * @description No outbound email is permitted.
		 */
		NO_ACCESS,
		/**
		 * @description Only system-generated email (e.g., password resets) is permitted.
		 */
		SYSTEM_EMAIL_ONLY
	}

	/**
	 * @description Checks whether the supplied address matches the default email pattern.
	 *
	 * @param address The address to validate.
	 *
	 * @return True when the address is syntactically valid.
	 *
	 * @since 1.0
	 */
	global static Boolean isValidEmailAddress(String address)
	{
		if(String.isBlank(address))
		{
			return false;
		}
		return DEFAULT_EMAIL_PATTERN.matcher(address).matches();
	}

	/**
	 * @description Convenience inverse of {@link #isValidEmailAddress(String)}.
	 *
	 * @param address The address to validate.
	 *
	 * @return True when the address is invalid.
	 *
	 * @since 1.0
	 */
	global static Boolean isNotValidEmailAddress(String address)
	{
		return !isValidEmailAddress(address);
	}

	/**
	 * @description Determines the org's current email deliverability access level.
	 * First attempts a capacity reservation; if that throws, falls back to parsing the
	 * email-admin settings page to extract the selected option.
	 *
	 * @return The detected DeliverabilityAccessLevel. Defaults to NO_ACCESS on failure.
	 *
	 * @since 1.0
	 */
	global static DeliverabilityAccessLevel getEmailDeliverabilityAccessLevel()
	{
		try
		{
			if(forceEmailCapacityException)
			{
				throw new EmailException('Forced capacity failure for test coverage');
			}
			Messaging.reserveSingleEmailCapacity(1);
			return DeliverabilityAccessLevel.ALL_EMAIL;
		}
		catch(Exception caught)
		{
			LOG_Builder.build().error('Deliverability probe failed: ' + caught.getMessage())
					.at(UTIL_Email.class.getName() + '/getEmailDeliverabilityAccessLevel').emit();

			PageReference settingsPage = new PageReference('/email-admin/editOrgEmailSettings.apexp');
			String html = Test.isRunningTest() ? NO_ACCESS_MARKER : settingsPage.getContent().toString().replace(UTIL_String.LF, UTIL_String.EMPTY);
			String selected = html.substringBetween(' selected="selected">', '</option>');
			return LABEL_TO_LEVEL.get(selected) ?? DeliverabilityAccessLevel.NO_ACCESS;
		}
	}

	/**
	 * @description Internal send method that assembles and dispatches a SingleEmailMessage.
	 *
	 * @param toAddresses Recipient addresses. Exits silently when null or empty.
	 * @param subject Email subject.
	 * @param body Body content.
	 * @param isHtml True to set HTML body, false for plain text.
	 * @param fileAttachments Optional file attachments.
	 *
	 * @since 1.0
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.ValidateCrudFlsEmailMessageWhoIdWhatId')
	global static void sendEmail(List<String> toAddresses, String subject, String body, Boolean isHtml, List<Messaging.EmailFileAttachment> fileAttachments)
	{
		if(toAddresses == null || toAddresses.isEmpty())
		{
			return;
		}

		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
		message.setToAddresses(toAddresses);
		message.setSubject(subject);
		message.setSaveAsActivity(false);
		message.setBccSender(false);
		message.setUseSignature(false);

		if(isHtml)
		{
			message.setHtmlBody(body);
		}
		else
		{
			message.setPlainTextBody(body);
		}

		if(fileAttachments != null && !fileAttachments.isEmpty())
		{
			message.setFileAttachments(fileAttachments);
		}

		Messaging.sendEmail(new List<Messaging.SingleEmailMessage> {message}, !Test.isRunningTest());
	}
}