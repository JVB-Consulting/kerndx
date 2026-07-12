// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

import fieldLocalTime from '@salesforce/label/c.EventMonitor_Field_LocalTime';
import fieldChannel from '@salesforce/label/c.EventMonitor_Field_Channel';
import fieldType from '@salesforce/label/c.EventMonitor_Field_Type';
import fieldReplayId from '@salesforce/label/c.EventMonitor_Field_ReplayId';
import fieldPayload from '@salesforce/label/c.EventMonitor_Field_Payload';
import viewDetailsTitle from '@salesforce/label/c.EventMonitor_ViewDetails_Title';
import viewTable from '@salesforce/label/c.EventUsageMetrics_View_Table';
import viewTimeline from '@salesforce/label/c.EventMonitor_View_Timeline';

/**
 * @description Column definitions for the events data table.
 * @type {Array<Object>}
 *
 * @date March 2026, May 2026
 */
export const TABLE_COLUMNS = [
	{
		label: fieldLocalTime, fieldName: 'timeLabel', type: 'text', initialWidth: 180
	},
	{
		label: fieldChannel, fieldName: 'channel', type: 'text', initialWidth: 200
	},
	{
		label: fieldType, fieldName: 'type', type: 'text', initialWidth: 200
	},
	{
		label: fieldReplayId, fieldName: 'replayId', type: 'text', initialWidth: 100
	},
	{label: fieldPayload, fieldName: 'payload', type: 'text'},
	{
		label: ' ', type: 'button-icon', initialWidth: 50, typeAttributes: {
			iconName: 'utility:zoomin', name: 'view', title: viewDetailsTitle
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
			{label: viewTable, value: VIEW_MODE_TABLE, iconName: 'utility:table'},
			{label: viewTimeline, value: VIEW_MODE_TIMELINE, iconName: 'utility:metrics'}
		];