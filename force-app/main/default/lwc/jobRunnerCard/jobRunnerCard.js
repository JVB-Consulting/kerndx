// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The job runner card Health Check renders beneath the readiness banner: whether the runner is
 *              active, how often it checks for due jobs and at what slot cost, who its jobs run as, the slot
 *              breakdown, and the actions. Presentational: the parent loads the status and handles the actions
 *              this card fires.
 *
 * @author Jason van Beukering
 *
 * @date September 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {formatTemplateString} from 'c/utilityString';
import {formatInstant} from 'c/utilityScheduledJob';
import CARD_TITLE from '@salesforce/label/c.HealthCheck_JobRunner_CardTitle';
import INACTIVE from '@salesforce/label/c.HealthCheck_JobRunner_Inactive';
import ACTIVE_SUMMARY from '@salesforce/label/c.HealthCheck_JobRunner_ActiveSummary';
import ACTIVATOR from '@salesforce/label/c.HealthCheck_JobRunner_Activator';
import ACTIVATOR_INACTIVE_BADGE from '@salesforce/label/c.HealthCheck_JobRunner_ActivatorInactiveBadge';
import ACTIVATOR_ADVICE from '@salesforce/label/c.HealthCheck_JobRunner_ActivatorAdvice';
import SLOTS from '@salesforce/label/c.HealthCheck_JobRunner_Capacity_Slots';
import ACTIVATE_BUTTON from '@salesforce/label/c.HealthCheck_JobRunner_ActivateButton';
import REPAIR_BUTTON from '@salesforce/label/c.HealthCheck_JobRunner_RepairButton';
import DEACTIVATE_BUTTON from '@salesforce/label/c.HealthCheck_JobRunner_DeactivateButton';
import LAST_CHECK from '@salesforce/label/c.HealthCheck_JobRunner_LastCheck';

export default class JobRunnerCard extends ComponentBuilder()
{
	/**
	 * @description The job runner status the parent read from CTRL_HealthCheck.getJobRunnerStatus.
	 *              Everything this card shows is read from it.
	 *
	 * @type {Object}
	 */
	@api status;

	/** @description Template-bound Custom Labels for the card title, the badge, the advice and the buttons. */
	labels = {
		cardTitle: CARD_TITLE,
		activatorAdvice: ACTIVATOR_ADVICE,
		activatorInactiveBadge: ACTIVATOR_INACTIVE_BADGE,
		activate: ACTIVATE_BUTTON,
		repair: REPAIR_BUTTON,
		deactivate: DEACTIVATE_BUTTON
	};

	/**
	 * @description Whether a job runner is active in this org.
	 *
	 * @return {boolean} True when the status says the runner is active.
	 */
	get isActive()
	{
		return this.status?.isActive === true;
	}

	/**
	 * @description Whether the person looking at the card may change the job runner.
	 *
	 * @return {boolean} True when the status says this user holds the Manage Job Runner permission.
	 */
	get canManage()
	{
		return this.status?.canManage === true;
	}

	/**
	 * @description The card's one-line summary: how often an active runner checks for due jobs and what
	 *              that costs in scheduled-job slots, or the sentence that says no runner is active.
	 *
	 * @return {string} The summary sentence.
	 */
	get summary()
	{
		return this.isActive ? formatTemplateString(ACTIVE_SUMMARY, [
			this.status.checkIntervalMinutes,
			this.status.slotCost
		]) : INACTIVE;
	}

	/**
	 * @description The line naming the user the runner's jobs run as, empty when no user is recorded.
	 *              Read only for an active runner, which always has a status.
	 *
	 * @return {string} The activator sentence, or an empty string.
	 */
	get activator()
	{
		return this.status.activatorName ? formatTemplateString(ACTIVATOR, [this.status.activatorName]) : '';
	}

	/**
	 * @description Whether the user an active runner runs its jobs as is no longer an active user, which
	 *              stops the runner's checks and earns the badge beside the activator line.
	 *
	 * @return {boolean} True when the runner is active and its user is inactive.
	 */
	get isActivatorInactive()
	{
		return this.isActive && this.status.isActivatorActive === false;
	}

	/**
	 * @description The line naming when the runner last checked for due jobs, in the reader's own time
	 *              zone and format, empty until a first check is recorded. Read only for an active
	 *              runner, which always has a status.
	 *
	 * @return {string} The last-check sentence, or an empty string.
	 */
	get lastCheck()
	{
		return this.status.lastCheckAt ? formatTemplateString(LAST_CHECK, [formatInstant(this.status.lastCheckAt)]) : '';
	}

	/**
	 * @description The org's scheduled-job slot breakdown: how many of the 100 are in use, and how they
	 *              split between the job runner, Scheduled Job records on their own slot, and everything else. Read
	 *              only for an active runner, which always has a status.
	 *
	 * @return {string} The slot breakdown sentence.
	 */
	get slots()
	{
		return formatTemplateString(SLOTS, [
			this.status.totalScheduledApexSlots ?? 0,
			this.status.jobRunnerSlots ?? 0,
			this.status.ownModeSlots ?? 0,
			this.status.otherSlots ?? 0
		]);
	}

	/**
	 * @description Whether to show the advice on which user to activate the runner as, which only helps
	 *              before a runner is active.
	 *
	 * @return {boolean} True when no runner is active.
	 */
	get showAdvice()
	{
		return !this.isActive;
	}

	/**
	 * @description Whether to offer Activate: only to a user who may manage the runner, and only while
	 *              no runner is active.
	 *
	 * @return {boolean} True when the Activate button belongs on the card.
	 */
	get showActivate()
	{
		return this.canManage && !this.isActive;
	}

	/**
	 * @description Whether to offer Repair and Deactivate: only to a user who may manage the runner, and
	 *              only while one is active.
	 *
	 * @return {boolean} True when both buttons belong on the card.
	 */
	get showRepairAndDeactivate()
	{
		return this.canManage && this.isActive;
	}

	/** @description Asks the parent to activate the job runner. */
	handleActivate()
	{
		this.dispatchEvent(new CustomEvent('activate'));
	}

	/** @description Asks the parent to replace the job runner's scheduled jobs. */
	handleRepair()
	{
		this.dispatchEvent(new CustomEvent('repair'));
	}

	/** @description Asks the parent to deactivate the job runner. */
	handleDeactivate()
	{
		this.dispatchEvent(new CustomEvent('deactivate'));
	}
}
