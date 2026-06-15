// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for utilityStreaming LWC utility module
 * @author Jason van Beukering
 * @date December 2025, June 2026
 */

import {
	CHANNEL_ALL_CDC, EVT_CDC, EVT_CUSTOM_CHANNEL_CDC, EVT_CUSTOM_CHANNEL_PE, EVT_GENERIC, EVT_MONITORING, EVT_PLATFORM_EVENT, EVT_PUSH_TOPIC, EVT_STD_PLATFORM_EVENT, FILTER_ALL,
	FILTER_CUSTOM, EVENT_TYPES, PUBLISHABLE_EVENT_TYPES, getChannelPrefix, isCDCChannel, isCustomChannel, normalizeEvent, getTimeLabel, getCompactTimeLabel, formatCount, channelSort, timestampSort,
	toTitleCase
} from 'c/utilityStreaming';

describe('utilityStreaming', () =>
{
	describe('constants', () =>
	{
		it('should export CHANNEL_ALL_CDC', () =>
		{
			expect(CHANNEL_ALL_CDC).toBe('/data/ChangeEvents');
		});

		it('should export EVT_CDC', () =>
		{
			expect(EVT_CDC).toBe('ChangeDataCaptureEvent');
		});

		it('should export EVT_CUSTOM_CHANNEL_CDC', () =>
		{
			expect(EVT_CUSTOM_CHANNEL_CDC).toBe('CustomChannelCDC');
		});

		it('should export EVT_CUSTOM_CHANNEL_PE', () =>
		{
			expect(EVT_CUSTOM_CHANNEL_PE).toBe('CustomChannelPE');
		});

		it('should export EVT_GENERIC', () =>
		{
			expect(EVT_GENERIC).toBe('GenericEvent');
		});

		it('should export EVT_MONITORING', () =>
		{
			expect(EVT_MONITORING).toBe('MonitoringEvent');
		});

		it('should export EVT_PLATFORM_EVENT', () =>
		{
			expect(EVT_PLATFORM_EVENT).toBe('PlatformEvent');
		});

		it('should export EVT_PUSH_TOPIC', () =>
		{
			expect(EVT_PUSH_TOPIC).toBe('PushTopicEvent');
		});

		it('should export EVT_STD_PLATFORM_EVENT', () =>
		{
			expect(EVT_STD_PLATFORM_EVENT).toBe('StandardPlatformEvent');
		});

		it('should export FILTER_ALL', () =>
		{
			expect(FILTER_ALL).toBe('all');
		});

		it('should export FILTER_CUSTOM', () =>
		{
			expect(FILTER_CUSTOM).toBe('custom');
		});

		it('should export EVENT_TYPES array with all event types', () =>
		{
			expect(EVENT_TYPES).toBeInstanceOf(Array);
			expect(EVENT_TYPES.length).toBe(8);
		});

		it('should have label, value, and channelPrefix for each EVENT_TYPE', () =>
		{
			EVENT_TYPES.forEach((eventType) =>
			{
				expect(eventType).toHaveProperty('label');
				expect(eventType).toHaveProperty('value');
				expect(eventType).toHaveProperty('channelPrefix');
			});
		});

		it('should export PUBLISHABLE_EVENT_TYPES containing only the manually publishable types', () =>
		{
			expect(PUBLISHABLE_EVENT_TYPES).toBeInstanceOf(Array);
			expect(PUBLISHABLE_EVENT_TYPES.map((eventType) => eventType.value)).toEqual([EVT_GENERIC, EVT_PLATFORM_EVENT]);
		});

		it('should exclude platform-published and record-change event types from PUBLISHABLE_EVENT_TYPES', () =>
		{
			const publishableValues = PUBLISHABLE_EVENT_TYPES.map((eventType) => eventType.value);
			[EVT_STD_PLATFORM_EVENT, EVT_CDC, EVT_PUSH_TOPIC, EVT_MONITORING, EVT_CUSTOM_CHANNEL_PE, EVT_CUSTOM_CHANNEL_CDC].forEach((value) =>
			{
				expect(publishableValues).not.toContain(value);
			});
		});
	});

	describe('getChannelPrefix', () =>
	{
		it('should return /topic/ for PushTopicEvent', () =>
		{
			expect(getChannelPrefix(EVT_PUSH_TOPIC)).toBe('/topic/');
		});

		it('should return /u/ for GenericEvent', () =>
		{
			expect(getChannelPrefix(EVT_GENERIC)).toBe('/u/');
		});

		it('should return /event/ for StandardPlatformEvent', () =>
		{
			expect(getChannelPrefix(EVT_STD_PLATFORM_EVENT)).toBe('/event/');
		});

		it('should return /event/ for PlatformEvent', () =>
		{
			expect(getChannelPrefix(EVT_PLATFORM_EVENT)).toBe('/event/');
		});

		it('should return /data/ for ChangeDataCaptureEvent', () =>
		{
			expect(getChannelPrefix(EVT_CDC)).toBe('/data/');
		});

		it('should return /event/ for CustomChannelPE', () =>
		{
			expect(getChannelPrefix(EVT_CUSTOM_CHANNEL_PE)).toBe('/event/');
		});

		it('should return /data/ for CustomChannelCDC', () =>
		{
			expect(getChannelPrefix(EVT_CUSTOM_CHANNEL_CDC)).toBe('/data/');
		});

		it('should return /event/ for MonitoringEvent', () =>
		{
			expect(getChannelPrefix(EVT_MONITORING)).toBe('/event/');
		});

		it('should throw error for unsupported event type', () =>
		{
			expect(() => getChannelPrefix('InvalidEventType')).toThrow('Unsupported event type: InvalidEventType');
		});
	});

	describe('isCDCChannel', () =>
	{
		it('should return true for /data/ channels', () =>
		{
			expect(isCDCChannel('/data/ChangeEvents')).toBe(true);
			expect(isCDCChannel('/data/AccountChangeEvent')).toBe(true);
		});

		it('should return false for non-/data/ channels', () =>
		{
			expect(isCDCChannel('/event/MyEvent__e')).toBe(false);
			expect(isCDCChannel('/topic/MyTopic')).toBe(false);
			expect(isCDCChannel('/u/GenericChannel')).toBe(false);
		});

		it('should return false for non-string values', () =>
		{
			expect(isCDCChannel(null)).toBe(false);
			expect(isCDCChannel(undefined)).toBe(false);
			expect(isCDCChannel(123)).toBe(false);
		});
	});

	describe('isCustomChannel', () =>
	{
		it('should return true for PushTopicEvent (always custom)', () =>
		{
			expect(isCustomChannel(EVT_PUSH_TOPIC, '/topic/MyTopic')).toBe(true);
		});

		it('should return true for GenericEvent (always custom)', () =>
		{
			expect(isCustomChannel(EVT_GENERIC, '/u/MyChannel')).toBe(true);
		});

		it('should return false for StandardPlatformEvent (never custom)', () =>
		{
			expect(isCustomChannel(EVT_STD_PLATFORM_EVENT, '/event/SomeEvent')).toBe(false);
		});

		it('should return true for PlatformEvent with __e suffix', () =>
		{
			expect(isCustomChannel(EVT_PLATFORM_EVENT, '/event/MyCustomEvent__e')).toBe(true);
		});

		it('should return false for PlatformEvent without __e suffix', () =>
		{
			expect(isCustomChannel(EVT_PLATFORM_EVENT, '/event/StandardEvent')).toBe(false);
		});

		it('should return true for CDC with __ChangeEvent suffix', () =>
		{
			expect(isCustomChannel(EVT_CDC, '/data/MyObject__ChangeEvent')).toBe(true);
		});

		it('should return false for CDC without __ChangeEvent suffix', () =>
		{
			expect(isCustomChannel(EVT_CDC, '/data/AccountChangeEvent')).toBe(false);
		});

		it('should return true for CustomChannelPE (always custom)', () =>
		{
			expect(isCustomChannel(EVT_CUSTOM_CHANNEL_PE, '/event/Anything')).toBe(true);
		});

		it('should return true for CustomChannelCDC (always custom)', () =>
		{
			expect(isCustomChannel(EVT_CUSTOM_CHANNEL_CDC, '/data/Anything')).toBe(true);
		});

		it('should return false for MonitoringEvent (never custom)', () =>
		{
			expect(isCustomChannel(EVT_MONITORING, '/event/MonitoringEvent')).toBe(false);
		});

		it('should throw error for unsupported event type', () =>
		{
			expect(() => isCustomChannel('InvalidType', '/event/Test')).toThrow('Unsupported event type: InvalidType');
		});

		it('should handle non-string channel for PlatformEvent', () =>
		{
			expect(isCustomChannel(EVT_PLATFORM_EVENT, null)).toBe(false);
			expect(isCustomChannel(EVT_PLATFORM_EVENT, 123)).toBe(false);
		});

		it('should handle non-string channel for CDC', () =>
		{
			expect(isCustomChannel(EVT_CDC, null)).toBe(false);
			expect(isCustomChannel(EVT_CDC, undefined)).toBe(false);
		});
	});

	describe('normalizeEvent', () =>
	{
		it('should normalize PushTopic event', () =>
		{
			const event = {
				channel: '/topic/MyTopic', data: {
					event: {
						replayId: 123, createdDate: '2025-01-15T10:00:00.000Z', type: 'created'
					}, sobject: {
						Id: '001xx000003DGHDAA4', Name: 'Test Account'
					}
				}
			};

			const result = normalizeEvent(event);

			expect(result.channel).toBe('/topic/MyTopic');
			expect(result.replayId).toBe(123);
			expect(result.type).toBe('PushTopic: created');
			expect(result.id).toContain('123');
		});

		it('should normalize Generic event', () =>
		{
			const event = {
				channel: '/u/MyGenericChannel', data: {
					event: {
						replayId: 456, createdDate: '2025-01-15T11:00:00.000Z'
					}, payload: {message: 'Hello'}
				}
			};

			const result = normalizeEvent(event);

			expect(result.channel).toBe('/u/MyGenericChannel');
			expect(result.replayId).toBe(456);
			expect(result.type).toBe('Generic');
		});

		it('should normalize CDC event', () =>
		{
			const event = {
				channel: '/data/AccountChangeEvent', data: {
					event: {replayId: 789}, schema: 'AccountSchema', payload: {
						ChangeEventHeader: {
							entityName: 'Account', changeType: 'CREATE', commitTimestamp: 1705312800000
						}
					}
				}
			};

			const result = normalizeEvent(event);

			expect(result.channel).toBe('/data/AccountChangeEvent');
			expect(result.type).toBe('Change Event: Account CREATE');
			expect(result.id).toBe('AccountSchema789');
		});

		it('should normalize Platform Event', () =>
		{
			const event = {
				channel: '/event/MyEvent__e', data: {
					event: {replayId: 101}, payload: {
						CreatedDate: '2025-01-15T12:00:00.000Z', CustomField__c: 'value'
					}
				}
			};

			const result = normalizeEvent(event);

			expect(result.channel).toBe('/event/MyEvent__e');
			expect(result.type).toBe('Platform Event');
		});

		it('should handle event with unknown type', () =>
		{
			const event = {
				channel: '/unknown/channel', data: {
					event: {replayId: 999}, payload: {}
				}
			};

			const result = normalizeEvent(event);

			expect(result.type).toBe('Unknown Event');
		});

		it('should serialize payload to JSON string', () =>
		{
			const event = {
				channel: '/event/Test__e', data: {
					event: {replayId: 1}, payload: {key: 'value', nested: {a: 1}}
				}
			};

			const result = normalizeEvent(event);

			expect(result.payload).toBe('{"key":"value","nested":{"a":1}}');
		});

		it('should handle null payload', () =>
		{
			const event = {
				channel: '/event/Test__e', data: {
					event: {replayId: 1}
				}
			};

			const result = normalizeEvent(event);

			expect(result.payload).toBe('null');
		});

		it('should handle missing event data', () =>
		{
			const event = {};

			const result = normalizeEvent(event);

			expect(result.replayId).toBeUndefined();
			expect(result.channel).toBeUndefined();
		});
	});

	describe('getTimeLabel', () =>
	{
		it('should format Date object', () =>
		{
			const date = new Date('2025-01-15T10:30:45.000Z');
			const result = getTimeLabel(date);

			expect(result).toContain('2025');
			expect(result).toContain('01');
			expect(result).toContain('15');
		});

		it('should format epoch milliseconds', () =>
		{
			const epoch = 1736937045000; // 2025-01-15T10:30:45.000Z
			const result = getTimeLabel(epoch);

			expect(result).toContain('2025');
		});

		it('should return empty string for invalid time', () =>
		{
			expect(getTimeLabel(null)).toBe('');
			expect(getTimeLabel('invalid')).toBe('');
			expect(getTimeLabel({})).toBe('');
		});

		it('should respect provided timezone', () =>
		{
			const date = new Date('2025-01-15T10:30:45.000Z');
			const resultLA = getTimeLabel(date, 'America/Los_Angeles');
			const resultNY = getTimeLabel(date, 'America/New_York');

			// Times should be different for different timezones
			expect(resultLA).not.toBe(resultNY);
		});

		it('should handle locale parameter', () =>
		{
			const date = new Date('2025-01-15T13:30:45.000Z');
			const resultWithLocale = getTimeLabel(date, undefined, 'en_US');

			expect(resultWithLocale).toContain('2025');
		});

		it('should handle Salesforce locale format with underscore', () =>
		{
			const date = new Date('2025-01-15T13:30:45.000Z');
			const result = getTimeLabel(date, undefined, 'en_ZA');

			expect(result).toContain('2025');
		});
	});

	describe('getCompactTimeLabel', () =>
	{
		it('should render only the date for the Daily segment', () =>
		{
			const result = getCompactTimeLabel(new Date('2026-06-02T14:30:00.000Z'), 'Daily', 'UTC');

			expect(result).toBe('Jun 2');
		});

		it('should append a 24-hour time for sub-daily segments', () =>
		{
			const result = getCompactTimeLabel(new Date('2026-06-02T14:30:00.000Z'), 'Hourly', 'UTC');

			expect(result).toBe('Jun 2, 14:30');
		});

		it('should accept epoch milliseconds', () =>
		{
			const epoch = Date.UTC(2026, 5, 2, 0, 0, 0);
			const result = getCompactTimeLabel(epoch, 'Daily', 'UTC');

			expect(result).toBe('Jun 2');
		});

		it('should honour the locale 12/24-hour preference for sub-daily segments', () =>
		{
			const date = new Date('2026-06-02T14:30:00.000Z');
			const twelveHour = getCompactTimeLabel(date, 'Hourly', 'UTC', 'en_US');
			const twentyFourHour = getCompactTimeLabel(date, 'Hourly', 'UTC', 'en_ZA');

			expect(twelveHour).toMatch(/PM|AM/);
			expect(twentyFourHour).not.toMatch(/PM|AM/);
		});

		it('should return empty string for invalid input', () =>
		{
			expect(getCompactTimeLabel(null, 'Daily')).toBe('');
			expect(getCompactTimeLabel('invalid', 'Daily')).toBe('');
			expect(getCompactTimeLabel({}, 'Hourly')).toBe('');
			expect(getCompactTimeLabel(Number.NaN, 'Daily')).toBe('');
			expect(getCompactTimeLabel(new Date('not a date'), 'Daily')).toBe('');
		});

		it('should label a UTC-midnight daily bucket by its start instant in the requested zone, regardless of host timezone', () =>
		{
			// The locked product decision: bucket labels follow the USER's Salesforce timezone. A UTC
			// daily bucket starting 2026-06-06T00:00:00Z is 20:00 on Jun 5 in New York, so the
			// date-only label reads "Jun 5" for users west of UTC — the tooltip's precise times make
			// the mapping inspectable. The explicit timeZone argument makes this host-independent.
			const result = getCompactTimeLabel(new Date('2026-06-06T00:00:00.000Z'), 'Daily', 'America/New_York');

			expect(result).toBe('Jun 5');
		});

		it('should shift sub-daily labels into the requested zone, regardless of host timezone', () =>
		{
			const result = getCompactTimeLabel(new Date('2026-06-06T14:00:00.000Z'), 'Hourly', 'America/New_York');

			expect(result).toBe('Jun 6, 10:00');
		});
	});

	describe('formatCount', () =>
	{
		it('should group thousands with the default en-US locale', () =>
		{
			expect(formatCount(31000)).toBe('31,000');
			expect(formatCount(1234567)).toBe('1,234,567');
		});

		it('should leave small numbers ungrouped', () =>
		{
			expect(formatCount(0)).toBe('0');
			expect(formatCount(42)).toBe('42');
		});

		it('should honour an explicit Salesforce locale', () =>
		{
			expect(formatCount(1000, 'en_US')).toBe('1,000');
		});

		it('should return empty string for non-finite values', () =>
		{
			expect(formatCount(undefined)).toBe('');
			expect(formatCount(null)).toBe('');
			expect(formatCount('not a number')).toBe('');
			expect(formatCount(Number.NaN)).toBe('');
		});
	});

	describe('channelSort', () =>
	{
		it('should sort by channel alphabetically', () =>
		{
			const items = [
				{channel: 'charlie'},
				{channel: 'alpha'},
				{channel: 'bravo'}
			];

			items.sort(channelSort);

			expect(items[0].channel).toBe('alpha');
			expect(items[1].channel).toBe('bravo');
			expect(items[2].channel).toBe('charlie');
		});

		it('should be case-insensitive', () =>
		{
			const items = [
				{channel: 'Charlie'},
				{channel: 'alpha'},
				{channel: 'BRAVO'}
			];

			items.sort(channelSort);

			expect(items[0].channel).toBe('alpha');
			expect(items[1].channel).toBe('BRAVO');
			expect(items[2].channel).toBe('Charlie');
		});

		it('should handle missing channel property', () =>
		{
			const items = [
				{channel: 'beta'},
				{},
				{channel: 'alpha'}
			];

			items.sort(channelSort);

			expect(items[0].channel).toBeUndefined();
			expect(items[1].channel).toBe('alpha');
			expect(items[2].channel).toBe('beta');
		});

		it('should handle null items', () =>
		{
			const items = [
				{channel: 'beta'},
				null,
				{channel: 'alpha'}
			];

			items.sort(channelSort);

			// null items should sort to beginning
			expect(items[0]).toBeNull();
		});
	});

	describe('timestampSort', () =>
	{
		it('should sort by timestamp numerically', () =>
		{
			const items = [
				{timestamp: 300},
				{timestamp: 100},
				{timestamp: 200}
			];

			items.sort(timestampSort);

			expect(items[0].timestamp).toBe(100);
			expect(items[1].timestamp).toBe(200);
			expect(items[2].timestamp).toBe(300);
		});

		it('should handle missing timestamp', () =>
		{
			const items = [
				{timestamp: 200},
				{},
				{timestamp: 100}
			];

			items.sort(timestampSort);

			expect(items[0].timestamp).toBeUndefined();
			expect(items[1].timestamp).toBe(100);
			expect(items[2].timestamp).toBe(200);
		});

		it('should handle null items', () =>
		{
			const items = [
				{timestamp: 200},
				null,
				{timestamp: 100}
			];

			items.sort(timestampSort);

			expect(items[0]).toBeNull();
		});
	});

	describe('toTitleCase', () =>
	{
		it('should convert underscore-separated words to title case', () =>
		{
			expect(toTitleCase('hello_world')).toBe('Hello World');
		});

		it('should convert hyphen-separated words to title case', () =>
		{
			expect(toTitleCase('hello-world')).toBe('Hello World');
		});

		it('should handle multiple separators', () =>
		{
			expect(toTitleCase('one_two-three_four')).toBe('One Two Three Four');
		});

		it('should handle mixed case input', () =>
		{
			expect(toTitleCase('HELLO_WORLD')).toBe('Hello World');
			expect(toTitleCase('hELLO_wORLD')).toBe('Hello World');
		});

		it('should return empty string for null', () =>
		{
			expect(toTitleCase(null)).toBe('');
		});

		it('should return empty string for undefined', () =>
		{
			expect(toTitleCase(undefined)).toBe('');
		});

		it('should return empty string for empty string', () =>
		{
			expect(toTitleCase('')).toBe('');
		});

		it('should return empty string for non-string', () =>
		{
			expect(toTitleCase(123)).toBe('');
			expect(toTitleCase({})).toBe('');
		});

		it('should handle single word', () =>
		{
			expect(toTitleCase('hello')).toBe('Hello');
		});

		it('should handle already title case', () =>
		{
			expect(toTitleCase('Hello World')).toBe('Hello World');
		});
	});
});
