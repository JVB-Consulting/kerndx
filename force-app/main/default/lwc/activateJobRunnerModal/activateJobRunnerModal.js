// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Dialogue for the Health Check "Activate" action on the job runner. Asks the one
 *              question activation needs (how often the runner checks for due jobs, with the slot cost
 *              of each choice), names the user the runner's jobs will run as, and closes with
 *              {action: 'confirm', intervalMinutes} or {action: 'cancel'}.
 *
 * @author Jason van Beukering
 *
 * @date September 2026, October 2026
 */
import LightningModal from 'lightning/modal';
import {api} from 'lwc';
import {formatTemplateString} from 'c/utilityString';
import MODAL_TITLE from '@salesforce/label/c.HealthCheck_JobRunner_ModalTitle';
import MODAL_SUBTITLE from '@salesforce/label/c.HealthCheck_JobRunner_ModalSubtitle';
import CHECK_INTERVAL_LABEL from '@salesforce/label/c.HealthCheck_JobRunner_CheckFrequencyLabel';
import CHECK_INTERVAL_OPTIONS from '@salesforce/label/c.HealthCheck_JobRunner_CheckFrequencyOptions';
import RUNS_AS_NOTE from '@salesforce/label/c.HealthCheck_JobRunner_RunsAsNote';
import CONFIRM_BUTTON from '@salesforce/label/c.HealthCheck_JobRunner_ConfirmButton';
import CANCEL_BUTTON from '@salesforce/label/c.ScheduledJob_Cancel';

const DEFAULT_INTERVAL_MINUTES = '15';

export default class ActivateJobRunnerModal extends LightningModal
{
	/**
	 * @description The name of the user who is activating the runner, so the dialogue can say whose
	 *              permissions the runner's jobs will run with.
	 *
	 * @type {string}
	 */
	@api runningUserName;

	/**
	 * @description The check interval the picklist currently holds, in minutes, as the option value;
	 *              returned on confirm.
	 *
	 * @type {string}
	 */
	selectedIntervalMinutes = DEFAULT_INTERVAL_MINUTES;

	/** @description Template-bound Custom Labels for the dialogue header, body and footer. */
	labels = {
		title: MODAL_TITLE, subtitle: MODAL_SUBTITLE, checkInterval: CHECK_INTERVAL_LABEL, confirm: CONFIRM_BUTTON, cancel: CANCEL_BUTTON
	};

	/**
	 * @description Parses the pipe-delimited custom label into an array of combobox options.
	 *
	 * @return {Array<{label: string, value: string}>} Check-interval picklist options.
	 */
	get checkIntervalOptions()
	{
		return CHECK_INTERVAL_OPTIONS.split('|').map((token) =>
		{
			const [label, value] = token.split('=');
			return {label, value};
		});
	}

	/**
	 * @description The note naming the user the runner's jobs will run as. Read only when a name arrived.
	 *
	 * @return {string} The running-user sentence.
	 */
	get runsAsNote()
	{
		return formatTemplateString(RUNS_AS_NOTE, [this.runningUserName]);
	}

	/**
	 * @description Whether to show the running-user note: only when the caller supplied a name, so the
	 *              dialogue never says the jobs will run as nobody.
	 *
	 * @return {boolean} True when a running user's name arrived.
	 */
	get showRunsAsNote()
	{
		return Boolean(this.runningUserName);
	}

	/**
	 * @description Keeps the recommended fifteen-minute default preselected, falling back to the first
	 *              option when the label no longer offers it.
	 */
	connectedCallback()
	{
		if(!this.checkIntervalOptions.some((option) => option.value === this.selectedIntervalMinutes))
		{
			this.selectedIntervalMinutes = this.checkIntervalOptions[0].value;
		}
	}

	/**
	 * @description Tracks the check interval the picklist currently holds.
	 *
	 * @param {CustomEvent} event The combobox change event carrying the chosen interval in minutes.
	 */
	handleCheckIntervalChange(event)
	{
		this.selectedIntervalMinutes = event.detail.value;
	}

	/** @description Closes the dialogue confirming activation, handing the chosen interval to the caller. */
	handleConfirm()
	{
		this.close(/** @type {*} */({action: 'confirm', intervalMinutes: this.selectedIntervalMinutes}));
	}

	/** @description Closes the dialogue without activating anything. */
	handleCancel()
	{
		this.close(/** @type {*} */({action: 'cancel'}));
	}
}
