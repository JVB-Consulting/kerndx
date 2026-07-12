// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the utilityScheduledJob LWC utility module.
 *
 * @author Jason van Beukering
 *
 * @date July 2026
 */
import {getTimezoneDisplayName, parseAttributes} from 'c/utilityScheduledJob';

describe('getTimezoneDisplayName', () =>
{
	it('resolves a valid IANA sid key to a human-readable long name', () =>
	{
		let result = getTimezoneDisplayName('America/New_York');
		// The exact long name is locale/runtime dependent, so assert it resolved to
		// something other than the raw id rather than pinning a brittle exact string.
		expect(typeof result).toBe('string');
		expect(result).not.toBe('America/New_York');
	});

	it('falls back to the raw sid key when Intl cannot format the zone', () =>
	{
		expect(getTimezoneDisplayName('Totally/Bogus_Zone')).toBe('Totally/Bogus_Zone');
	});
});

describe('parseAttributes', () =>
{
	it('returns an empty map for an empty string', () =>
	{
		expect(parseAttributes('')).toEqual({});
	});

	it('returns an empty map for a null argument', () =>
	{
		expect(parseAttributes(null)).toEqual({});
	});

	it('parses the nameValueMap out of a valid DTO_NameValues JSON string', () =>
	{
		let result = parseAttributes('{"nameValueMap":{"objectName":"LogEntry__c","minimumNumberOfDays":"30"}}');
		expect(result).toEqual({objectName: 'LogEntry__c', minimumNumberOfDays: '30'});
	});

	it('falls back to an empty map when the parsed JSON omits nameValueMap', () =>
	{
		expect(parseAttributes('{"unexpected":true}')).toEqual({});
	});

	it('returns an empty map when the string is not valid JSON', () =>
	{
		expect(parseAttributes('{not valid json')).toEqual({});
	});
});
