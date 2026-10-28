// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Shared helpers for the ScheduledJob__c editor, editor-modal and detail components and the
 *              job runner card: resolves a human-readable timezone name from an IANA sid key, parses a
 *              DTO_NameValues JSON string into a plain key-value map, and renders an instant in the reader's
 *              own Salesforce locale and time zone.
 *
 * @author Jason van Beukering
 *
 * @date July 2026, October 2026
 */
import LOCALE from '@salesforce/i18n/locale';
import TIME_ZONE from '@salesforce/i18n/timeZone';

/**
 * @description Returns a human-readable timezone name from an IANA TimeZoneSidKey
 * using the browser's Intl.DateTimeFormat API.
 *
 * @param {string} timezoneSidKey The IANA timezone ID (e.g. Africa/Johannesburg).
 *
 * @returns {string} The display name, or the raw SidKey as fallback.
 */
export function getTimezoneDisplayName(timezoneSidKey)
{
	try
	{
		return new Intl.DateTimeFormat('en', {timeZone: timezoneSidKey, timeZoneName: 'long'})
		.formatToParts(new Date())
		.find((part) => part.type === 'timeZoneName').value;
	}
	catch
	{
		return timezoneSidKey;
	}
}

/**
 * @description Parses a DTO_NameValues JSON string into a plain object. An empty or malformed
 * string yields an empty map so a bad Parameters__c value never breaks rendering.
 *
 * @param {string} attributeString The serialized DTO_NameValues JSON.
 *
 * @returns {Object} Key-value map of parsed attributes.
 */
export function parseAttributes(attributeString)
{
	if(!attributeString)
	{
		return {};
	}

	try
	{
		const parsed = JSON.parse(attributeString);
		return parsed.nameValueMap || {};
	}
	catch
	{
		return {};
	}
}

/**
 * @description Renders an instant in the reader's own Salesforce locale and time zone, so a date on the page
 * reads the same way as the record's own date fields wherever the browser happens to be set.
 *
 * @param {string} value The instant as the record holds it, which may be absent.
 *
 * @returns {string} The instant to show, or an empty string when there is none to show or it cannot be read.
 */
export function formatInstant(value)
{
	if(!value)
	{
		return '';
	}

	try
	{
		return new Intl.DateTimeFormat(LOCALE.replace('_', '-'), {timeZone: TIME_ZONE, dateStyle: 'medium', timeStyle: 'short'}).format(new Date(value));
	}
	catch
	{
		return '';
	}
}