// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Shared helpers for the ScheduledJob__c editor, editor-modal and detail components:
 *              resolves a human-readable timezone name from an IANA sid key, and parses a
 *              DTO_NameValues JSON string into a plain key-value map.
 *
 * @author Jason van Beukering
 *
 * @date July 2026
 */

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
		let parsed = JSON.parse(attributeString);
		return parsed.nameValueMap || {};
	}
	catch
	{
		return {};
	}
}