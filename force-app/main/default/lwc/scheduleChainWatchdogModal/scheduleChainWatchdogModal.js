// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Confirmation dialogue for the Health Check "Schedule Chain Watchdog" one-click flow.
 *              States what the one active scheduled job will do, offers a schedule picklist with the
 *              recommended hourly default, and closes with {action: 'confirm', cronExpression} or
 *              {action: 'cancel'}.
 *
 * @author Jason van Beukering
 *
 * @date July 2026
 */
/* eslint-disable-next-line kerndx/enforce-component-naming */
import LightningModal from 'lightning/modal';
import {api} from 'lwc';
import MODAL_TITLE from '@salesforce/label/c.HealthCheck_ChainWatchdog_ModalTitle';
import MODAL_SUBTITLE from '@salesforce/label/c.HealthCheck_ChainWatchdog_ModalSubtitle';
import SCHEDULE_OPTIONS from '@salesforce/label/c.HealthCheck_ChainWatchdog_ScheduleOptions';
import DEFAULTS_NOTE from '@salesforce/label/c.HealthCheck_ChainWatchdog_DefaultsNote';
import CREATE_BUTTON from '@salesforce/label/c.HealthCheck_ChainWatchdog_CreateButton';
import SCHEDULE_FIELD_LABEL from '@salesforce/label/c.ScheduledJob_Schedule';
import CANCEL_BUTTON from '@salesforce/label/c.ScheduledJob_Cancel';

export default class ScheduleChainWatchdogModal extends LightningModal
{
	/**
	 * @description The watchdog schedule proposal from CTRL_HealthCheck.getChainWatchdogProposal.
	 *              Carries the recommended cronExpression this dialogue preselects.
	 *
	 * @type {Object}
	 */
	@api proposal;

	/**
	 * @description The cron expression the schedule picklist currently holds; initialised from the
	 *              proposal and returned on confirm.
	 *
	 * @type {string}
	 */
	selectedCronExpression = '';

	/** @description Template-bound Custom Labels for the dialogue body and footer. */
	labels = {
		title: MODAL_TITLE, subtitle: MODAL_SUBTITLE, schedule: SCHEDULE_FIELD_LABEL, defaultsNote: DEFAULTS_NOTE, create: CREATE_BUTTON, cancel: CANCEL_BUTTON
	};

	/**
	 * @description Parses the pipe-delimited custom label into an array of combobox options.
	 *
	 * @return {Array<{label: string, value: string}>} Schedule picklist options.
	 */
	get scheduleOptions()
	{
		return SCHEDULE_OPTIONS.split('|').map((token) =>
		{
			const [label, value] = token.split('=');
			return {label, value};
		});
	}

	/**
	 * @description Preselects the proposal's recommended cron expression, falling back to the first
	 *              schedule option when no proposal (or no cron) was supplied.
	 */
	connectedCallback()
	{
		this.selectedCronExpression = this.proposal?.cronExpression ?? this.scheduleOptions[0].value;
	}

	/**
	 * @description Tracks the schedule the picklist currently holds.
	 *
	 * @param {CustomEvent} event The combobox change event carrying the chosen cron expression.
	 */
	handleScheduleChange(event)
	{
		this.selectedCronExpression = event.detail.value;
	}

	/** @description Closes the dialogue confirming creation, handing the chosen cron to the caller. */
	handleCreate()
	{
		this.close(/** @type {*} */({action: 'confirm', cronExpression: this.selectedCronExpression}));
	}

	/** @description Closes the dialogue without creating anything. */
	handleCancel()
	{
		this.close(/** @type {*} */({action: 'cancel'}));
	}
}
