// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Confirmation dialogue for the Health Check "Apply Recommended Retention" flow.
 *              Shows each proposed ScheduledJob__c with an inline schedule picklist and closes
 *              with one of {action: 'confirm', proposals} | {action: 'customize'} | {action: 'cancel'}.
 *              The modal owns a working copy of the proposals so user edits do not mutate the
 *              caller's array.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026
 */
/* eslint-disable-next-line kerndx/enforce-component-naming */
import LightningModal from 'lightning/modal';
import {api} from 'lwc';
import SCHEDULE_OPTIONS from '@salesforce/label/c.HealthCheck_DataRetention_ScheduleOptions';

export default class ApplyRetentionModal extends LightningModal
{
	/**
	 * @description The retention proposals to render, one row per target SObject. Each entry carries
	 *              objectApiName, objectLabel, recordCount, retentionDays, schedulerName, and
	 *              cronExpression.
	 *
	 * @type {Array<Object>}
	 */
	@api proposals = [];

	/**
	 * @description Modal header title.
	 *
	 * @type {string}
	 */
	@api title = '';

	/**
	 * @description Pre-interpolated subtitle shown above the proposal table.
	 *
	 * @type {string}
	 */
	@api subtitle = '';

	/**
	 * @description Warning text shown below the proposal table regarding first-run deletion behaviour.
	 *
	 * @type {string}
	 */
	@api firstRunWarning = '';

	/**
	 * @description Pre-interpolated label for the confirm button.
	 *
	 * @type {string}
	 */
	@api confirmButtonLabel = '';

	/**
	 * @description Label for the customize escape hatch link.
	 *
	 * @type {string}
	 */
	@api customizeLinkLabel = '';

	/**
	 * @description Working copy of proposals cloned on construction so caller's array is not mutated.
	 *              Per-row cron edits from the schedule picklist mutate only this array.
	 *
	 * @type {Array<Object>}
	 */
	workingProposals = [];

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

	connectedCallback()
	{
		this.workingProposals = (this.proposals || []).map((proposal) => ({...proposal}));
	}

	/**
	 * @description Handles a change on any row's schedule picklist and updates the matching row's
	 *              cronExpression on the working copy.
	 *
	 * @param {Object} event The combobox change event carrying target.dataset.objectApiName and detail.value.
	 */
	handleCronChange(event)
	{
		const objectApiName = event.target.dataset.objectApiName;
		const value = event.detail.value;
		this.workingProposals = this.workingProposals.map((proposal) =>
		{
			if(proposal.objectApiName === objectApiName)
			{
				return {...proposal, cronExpression: value};
			}
			return proposal;
		});
	}

	handleConfirm()
	{
		this.close(/** @type {*} */({action: 'confirm', proposals: this.workingProposals}));
	}

	handleCustomize()
	{
		this.close(/** @type {*} */({action: 'customize'}));
	}

	handleCancel()
	{
		this.close(/** @type {*} */({action: 'cancel'}));
	}
}