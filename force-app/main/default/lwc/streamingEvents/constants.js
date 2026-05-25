// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Column definitions for the events data table.
 * @type {Array<Object>}
 */
export const TABLE_COLUMNS = [
	{
		label: 'Local Time', fieldName: 'timeLabel', type: 'text', initialWidth: 180
	},
	{
		label: 'Channel', fieldName: 'channel', type: 'text', initialWidth: 200
	},
	{
		label: 'Type', fieldName: 'type', type: 'text', initialWidth: 200
	},
	{
		label: 'Replay Id', fieldName: 'replayId', type: 'text', initialWidth: 100
	},
	{label: 'Payload', fieldName: 'payload', type: 'text'},
	{
		label: ' ', type: 'button-icon', initialWidth: 50, typeAttributes: {
			iconName: 'utility:zoomin', name: 'view', title: 'Click to View Details'
		}
	}
];

/**
 * @description Default event data structure used when no event is selected.
 * @type {Object}
 */
export const DEFAULT_EVENT_DATA = {
	time: '', channel: '', replayId: '', payload: ''
};

/**
 * @description View mode constant for table display.
 * @type {string}
 */
export const VIEW_MODE_TABLE = 'table';

/**
 * @description View mode constant for timeline display.
 * @type {string}
 */
export const VIEW_MODE_TIMELINE = 'timeline';

/**
 * @description Available view mode options with labels and icons.
 * @type {Array<Object>}
 */
		// noinspection JSUnusedGlobalSymbols
export const VIEW_MODES = [
			{label: 'Table', value: VIEW_MODE_TABLE, iconName: 'utility:table'},
			{label: 'Timeline', value: VIEW_MODE_TIMELINE, iconName: 'utility:metrics'}
		];