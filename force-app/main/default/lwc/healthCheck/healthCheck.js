// SPDX-License-Identifier: Apache-2.0
/**
 * @description Displays post-install health check results with pass/warn/fail status,
 * action buttons, and passing chips. Automatically runs checks on load and supports refresh.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, October 2026
 */
import {ComponentBuilder} from 'c/componentBuilder';
import LightningConfirm from 'lightning/confirm';
import ClassTypeResolverSetupModal from 'c/classTypeResolverSetupModal';
import ApplyRetentionModal from 'c/applyRetentionModal';
import ScheduledJobEditorModal from 'c/scheduledJobEditorModal';
import ScheduleChainWatchdogModal from 'c/scheduleChainWatchdogModal';
import ActivateJobRunnerModal from 'c/activateJobRunnerModal';
import runHealthChecks from '@salesforce/apex/CTRL_HealthCheck.runHealthChecks';
import getRetentionProposals from '@salesforce/apex/CTRL_HealthCheck.getRetentionProposals';
import applyRetentionRecommendations from '@salesforce/apex/CTRL_HealthCheck.applyRetentionRecommendations';
import getChainWatchdogProposal from '@salesforce/apex/CTRL_HealthCheck.getChainWatchdogProposal';
import scheduleChainWatchdog from '@salesforce/apex/CTRL_HealthCheck.scheduleChainWatchdog';
import getJobRunnerStatus from '@salesforce/apex/CTRL_HealthCheck.getJobRunnerStatus';
import activateJobRunner from '@salesforce/apex/CTRL_HealthCheck.activateJobRunner';
import repairJobRunner from '@salesforce/apex/CTRL_HealthCheck.repairJobRunner';
import deactivateJobRunner from '@salesforce/apex/CTRL_HealthCheck.deactivateJobRunner';
import CARD_TITLE from '@salesforce/label/c.HealthCheck_CardTitle';
import REFRESH_ALT_TEXT from '@salesforce/label/c.HealthCheck_RefreshAltText';
import ALL_PASS_HEADING from '@salesforce/label/c.HealthCheck_AllPassHeading';
import ALL_PASS_MULTIPLE_CHECKS from '@salesforce/label/c.HealthCheck_AllPassMultipleChecks';
import ALL_PASS_SINGLE_CHECK from '@salesforce/label/c.HealthCheck_AllPassSingleCheck';
import PASSING_PREFIX from '@salesforce/label/c.HealthCheck_PassingPrefix';
import ACTION_REQUIRED_HEADLINE from '@salesforce/label/c.HealthCheck_ActionRequiredHeadline';
import REVIEW_RECOMMENDED_HEADLINE from '@salesforce/label/c.HealthCheck_ReviewRecommendedHeadline';
import CHECK_DATA_RETENTION from '@salesforce/label/c.HealthCheck_DataRetention_CheckName';
import CHECK_MASKING_POSTURE from '@salesforce/label/c.HealthCheck_MaskingPosture_CheckName';
import CHECK_CUSTOM_OBJECT_COVERAGE from '@salesforce/label/c.HealthCheck_CustomObjectCoverage_CheckName';
import CHECK_CHAIN_WATCHDOG from '@salesforce/label/c.HealthCheck_ChainWatchdog_CheckName';
import WATCHDOG_SCHEDULE_BUTTON from '@salesforce/label/c.HealthCheck_ChainWatchdog_ScheduleButton';
import WATCHDOG_CUSTOMIZE_LINK from '@salesforce/label/c.HealthCheck_ChainWatchdog_CustomizeLink';
import WATCHDOG_MODAL_TITLE from '@salesforce/label/c.HealthCheck_ChainWatchdog_ModalTitle';
import WATCHDOG_SUCCESS_TOAST from '@salesforce/label/c.HealthCheck_ChainWatchdog_SuccessToast';
import APPLY_BUTTON from '@salesforce/label/c.HealthCheck_DataRetention_ApplyButton';
import CUSTOMIZE_LINK from '@salesforce/label/c.HealthCheck_DataRetention_CustomizeLink';
import MODAL_TITLE from '@salesforce/label/c.HealthCheck_DataRetention_ModalTitle';
import MODAL_SUBTITLE from '@salesforce/label/c.HealthCheck_DataRetention_ModalSubtitle';
import FIRST_RUN_WARNING from '@salesforce/label/c.HealthCheck_DataRetention_FirstRunWarning';
import CREATE_BUTTON from '@salesforce/label/c.HealthCheck_DataRetention_CreateButton';
import SUCCESS_TOAST from '@salesforce/label/c.HealthCheck_DataRetention_SuccessToast';
import SET_UP_BUTTON from '@salesforce/label/c.HealthCheck_DataRetention_SetUpButton';
import CONFIGURED_PILL from '@salesforce/label/c.HealthCheck_DataRetention_ConfiguredPill';
import BACK_TO_APPLY_LINK from '@salesforce/label/c.HealthCheck_DataRetention_CustomizeBackLink';
import CUSTOMIZING_HEADLINE from '@salesforce/label/c.HealthCheck_DataRetention_CustomizingHeadline';
import CUSTOMIZING_HELP from '@salesforce/label/c.HealthCheck_DataRetention_CustomizingHelp';
import FAIL_SECTION_HEADING from '@salesforce/label/c.HealthCheck_FailSection_Heading';
import WARN_SECTION_HEADING from '@salesforce/label/c.HealthCheck_WarnSection_Heading';
import WARNING_SINGULAR from '@salesforce/label/c.HealthCheck_WarningSingular';
import WARNING_PLURAL from '@salesforce/label/c.HealthCheck_WarningPlural';
import REFRESH_FAILED_TOAST from '@salesforce/label/c.HealthCheck_DataRetention_RefreshFailedToast';
import RECORD_COUNT_SINGULAR from '@salesforce/label/c.HealthCheck_DataRetention_RecordCountSingular';
import RECORD_COUNT_PLURAL from '@salesforce/label/c.HealthCheck_DataRetention_RecordCountPlural';
import DAY_SUFFIX from '@salesforce/label/c.HealthCheck_DataRetention_DaySuffix';
import CLASS_TYPE_RESOLVER_MODAL_TITLE from '@salesforce/label/c.ClassTypeResolverModal_Title';
import SCHEDULED_JOB_CREATE_TITLE from '@salesforce/label/c.ScheduledJob_NewTitle';
import CHECK_JOB_RUNNER from '@salesforce/label/c.HealthCheck_JobRunner_CheckName';
import CHECK_JOB_RUNNER_ORPHANED from '@salesforce/label/c.HealthCheck_JobRunner_Orphaned_CheckName';
import CHECK_JOB_RUNNER_CAPACITY from '@salesforce/label/c.HealthCheck_JobRunner_Capacity_CheckName';
import JOB_RUNNER_CARD_TITLE from '@salesforce/label/c.HealthCheck_JobRunner_CardTitle';
import JOB_RUNNER_ACTIVATE_BUTTON from '@salesforce/label/c.HealthCheck_JobRunner_ActivateButton';
import JOB_RUNNER_REPAIR_BUTTON from '@salesforce/label/c.HealthCheck_JobRunner_RepairButton';
import JOB_RUNNER_MODAL_TITLE from '@salesforce/label/c.HealthCheck_JobRunner_ModalTitle';
import JOB_RUNNER_ACTIVATED from '@salesforce/label/c.HealthCheck_JobRunner_Activated';
import JOB_RUNNER_REPAIRED from '@salesforce/label/c.HealthCheck_JobRunner_Repaired';
import JOB_RUNNER_DEACTIVATED from '@salesforce/label/c.HealthCheck_JobRunner_Deactivated';
import JOB_RUNNER_DEACTIVATE_CONFIRM from '@salesforce/label/c.HealthCheck_JobRunner_DeactivateConfirm';
import {formatTemplateString} from 'c/utilityString';

const PARAMETER_OBJECT_NAME = 'objectName';
const PARAMETER_MINIMUM_DAYS = 'minimumNumberOfDays';
const DATA_MASKING_ADVISOR_TAB = 'DataMaskingAdvisor';
// The custom-object coverage card deep-links into the advisor carrying this page-state flag so the advisor
// auto-runs the coverage scan on arrival rather than leaving the admin to press "Scan N" again.
const ADVISOR_SCAN_STATE_KEY = 'c__scan';
const ADVISOR_SCAN_STATE_VALUE = '1';
// The three results the job runner reports. Each one carries its own remedy button instead of the generic action button.
const JOB_RUNNER_CHECK_NAMES = new Set([
	CHECK_JOB_RUNNER,
	CHECK_JOB_RUNNER_ORPHANED,
	CHECK_JOB_RUNNER_CAPACITY
]);

export default class HealthCheck extends ComponentBuilder('controller', 'notification', 'navigation')
{
	results = [];
	hasResults = false;
	allPassed = false;
	hasFailures = false;
	isCustomizeMode = false;
	retentionProposals = [];
	jobRunnerStatus;

	labels = {
		cardTitle: CARD_TITLE,
		refreshAltText: REFRESH_ALT_TEXT,
		allPassHeading: ALL_PASS_HEADING,
		passingPrefix: PASSING_PREFIX,
		applyButton: APPLY_BUTTON,
		customizeLink: CUSTOMIZE_LINK,
		setUpButton: SET_UP_BUTTON,
		configuredPill: CONFIGURED_PILL,
		backToApplyLink: BACK_TO_APPLY_LINK,
		customizingHelp: CUSTOMIZING_HELP,
		failSectionHeading: FAIL_SECTION_HEADING,
		warnSectionHeading: WARN_SECTION_HEADING,
		watchdogScheduleButton: WATCHDOG_SCHEDULE_BUTTON,
		watchdogCustomizeLink: WATCHDOG_CUSTOMIZE_LINK
	};

	/**
	 * @description Failing results sorted by ascending `priority` so the most foundational Fail sits at the
	 *              top of the Fail section. Undefined priority floats to the bottom via
	 *              `Number.MAX_SAFE_INTEGER` so a result that forgets to set priority never hijacks first slot.
	 *              `.slice()` preserves stability by not mutating the original `results` array.
	 *
	 * @return {object[]} Ordered list of failing result view-models for the Fail section.
	 */
	get failItems()
	{
		return this.results
		.filter((result) => result.failed)
		.slice()
		.sort((a, b) => (a.priority ?? Number.MAX_SAFE_INTEGER) - (b.priority ?? Number.MAX_SAFE_INTEGER));
	}

	/**
	 * @description Whether there is at least one failing result, used by the template to toggle
	 *              the Fail (Action required) section on or off.
	 *
	 * @return {boolean} True when one or more results have `failed === true`.
	 */
	get hasFailItems()
	{
		return this.failItems.length > 0;
	}

	/**
	 * @description Warning results (and any action-bearing result that isn't a hard fail) sorted by
	 *              ascending `priority` so the most foundational Warn sits at the top of the Warn section.
	 *              Undefined priority floats to the bottom via `Number.MAX_SAFE_INTEGER`.
	 *              `.slice()` preserves stability by not mutating the original `results` array.
	 *
	 * @return {object[]} Ordered list of warn/action result view-models for the Warn section.
	 */
	get warnItems()
	{
		return this.results
		.filter((result) => !result.failed && (result.warned || result.actionLabel))
		.slice()
		.sort((a, b) => (a.priority ?? Number.MAX_SAFE_INTEGER) - (b.priority ?? Number.MAX_SAFE_INTEGER));
	}

	/**
	 * @description Whether there is at least one warn or action-bearing non-fail result, used by
	 *              the template to toggle the Warn (Review recommended) section on or off.
	 *
	 * @return {boolean} True when one or more results qualify as warn-section entries.
	 */
	get hasWarnItems()
	{
		return this.warnItems.length > 0;
	}

	get passingItems()
	{
		return this.results.filter((result) => result.passed && !result.actionLabel);
	}

	get hasPassingItems()
	{
		return this.passingItems.length > 0;
	}

	get headlineLabel()
	{
		const failCount = this.results.filter((result) => result.failed).length;
		const warnCount = this.results.filter((result) => result.warned).length;
		if(failCount > 0)
		{
			return ACTION_REQUIRED_HEADLINE.replace('{0}', failCount).replace('{1}', warnCount).replace('{2}', warnCount === 1 ? WARNING_SINGULAR : WARNING_PLURAL);
		}
		return REVIEW_RECOMMENDED_HEADLINE.replace('{0}', warnCount).replace('{1}', warnCount === 1 ? WARNING_SINGULAR : WARNING_PLURAL);
	}

	get resultCountLabel()
	{
		const count = this.results.length;
		const template = count === 1 ? ALL_PASS_SINGLE_CHECK : ALL_PASS_MULTIPLE_CHECKS;
		return template.replace('{0}', count);
	}

	/**
	 * @description Customize-mode headline for the Data Retention row, with the current
	 *              proposal count interpolated into the localised template string.
	 *
	 * @return {string} The fully interpolated headline (e.g. "Data Retention — customizing 4 jobs").
	 */
	get customizingHeadline()
	{
		return CUSTOMIZING_HEADLINE.replace('{0}', this.retentionProposals.length);
	}

	async connectedCallback()
	{
		await this.runChecks();
	}

	async runChecks()
	{
		this.isLoading = true;

		// The job runner card sits beside the checks, so its status is read in the same round trip
		// rather than after it. A failed status read is toasted by callControllerMethod and leaves
		// the card showing what it last knew.
		const [data, status] = await Promise.all([
			this.callControllerMethod(runHealthChecks),
			this.callControllerMethod(getJobRunnerStatus)
		]);

		this.jobRunnerStatus = status || this.jobRunnerStatus;

		if(data)
		{
			this.results = data.map((item) => ({
				...item,
				passed: item.status === 'Pass',
				warned: item.status === 'Warn',
				failed: item.status === 'Fail',
				isDataRetention: item.name === CHECK_DATA_RETENTION,
				isChainWatchdog: item.name === CHECK_CHAIN_WATCHDOG,
				isJobRunner: JOB_RUNNER_CHECK_NAMES.has(item.name),
				jobRunnerRemedyLabel: this.getJobRunnerRemedyLabel(item.name),
				iconName: this.getIconName(item.status),
				iconVariant: this.getIconVariant(item.status)
			}));

			this.hasResults = true;
			this.allPassed = this.results.every((item) => item.passed);
			this.hasFailures = this.results.some((item) => item.failed);
		}

		this.isLoading = false;
	}

	async handleRefresh()
	{
		await this.runChecks();
	}

	/**
	 * @description Handles the generic (non-retention) action button. The masking-configuration posture and
	 *              the custom-object masking-coverage results deep-link into the Data Masking Advisor tab;
	 *              the coverage card additionally carries a scan-request page state so the advisor auto-runs
	 *              its coverage scan on arrival. Every other action-bearing result opens the class type
	 *              resolver setup modal and re-runs the checks once it closes.
	 *
	 * @param {Event} event Click event from the action button (carries data-name with the result name).
	 *
	 * @return {Promise<void>} Resolves after navigation or the resolver-modal refresh cycle completes.
	 */
	async handleAction(event)
	{
		const resultName = event.currentTarget.dataset.name;
		const requestsCoverageScan = resultName === CHECK_CUSTOM_OBJECT_COVERAGE;
		if(resultName === CHECK_MASKING_POSTURE || requestsCoverageScan)
		{
			const target = {type: 'standard__navItemPage', attributes: {apiName: DATA_MASKING_ADVISOR_TAB}};
			if(requestsCoverageScan)
			{
				target.state = {[ADVISOR_SCAN_STATE_KEY]: ADVISOR_SCAN_STATE_VALUE};
			}
			this.navigate(target);
			return;
		}

		await ClassTypeResolverSetupModal.open({size: 'medium', label: CLASS_TYPE_RESOLVER_MODAL_TITLE});

		await this.runChecks();
	}

	/**
	 * @description Opens the Apply Recommended Retention modal after fetching proposals from Apex.
	 *              Dispatches to confirm (apply + toast + refresh), customize (flip mode), or cancel (no-op)
	 *              based on the modal's resolved action. A failed proposal fetch or a failed apply is
	 *              surfaced as an error toast by callControllerMethod, and the flow stops there.
	 *
	 * @return {Promise<void>} Resolves after the full apply-or-customize flow completes.
	 */
	async handleApplyRetention()
	{
		// callControllerMethod resolves undefined after surfacing a failed fetch as an error
		// toast; without proposals there is nothing to review, so the modal stays closed.
		const proposals = await this.callControllerMethod(getRetentionProposals);

		if(!proposals)
		{
			return;
		}

		const result = await ApplyRetentionModal.open({
			size: 'medium',
			proposals,
			label: MODAL_TITLE,
			title: MODAL_TITLE,
			subtitle: MODAL_SUBTITLE.replace('{0}', proposals.length),
			firstRunWarning: FIRST_RUN_WARNING,
			confirmButtonLabel: CREATE_BUTTON.replace('{0}', proposals.length),
			customizeLinkLabel: CUSTOMIZE_LINK
		});

		if(result?.action === 'confirm')
		{
			const insertedIds = await this.callControllerMethod(applyRetentionRecommendations, {
				proposalsJson: JSON.stringify(result.proposals)
			});

			// A failed apply is surfaced as an error toast by callControllerMethod; only a
			// real result may refresh the checks and signal success.
			if(!insertedIds)
			{
				return;
			}

			await this.runChecks();
			this.showSuccessToast(SUCCESS_TOAST.replace('{0}', insertedIds.length));
		}
		else if(result?.action === 'customize')
		{
			await this.setCustomizeMode(true);
		}
	}

	/**
	 * @description Flips the component into customize mode so per-row retention sub-rows render
	 *              instead of the dual action buttons.
	 *
	 * @return {Promise<void>} Resolves after the initial proposal fetch completes.
	 */
	async handleCustomizeRetention()
	{
		await this.setCustomizeMode(true);
	}

	/**
	 * @description Returns the admin to the dual-button view by flipping customize mode off.
	 *              Does not refetch proposals — the previously loaded list fades out as the
	 *              sub-row template unmounts.
	 *
	 * @return {Promise<void>} Resolves after the flag flips (sync under the hood).
	 */
	async handleBackToApply()
	{
		await this.setCustomizeMode(false);
	}

	/**
	 * @description Opens the scheduled job editor modal pre-populated with the clicked
	 *              sub-row's proposal. After the modal closes, re-runs health checks and
	 *              reloads the retention proposal list. If no unconfigured proposals
	 *              remain, flips customize mode back off so the passing-chip row renders.
	 *
	 * @param {Event} event Click event from the set-up button (carries data-object-api-name).
	 *
	 * @return {Promise<void>} Resolves after the modal + refresh cycle completes.
	 */
	async handleSetUp(event)
	{
		const objectApiName = event.currentTarget.dataset.objectApiName;
		const proposal = this.retentionProposals.find((candidate) => candidate.objectApiName === objectApiName);

		if(!proposal)
		{
			return;
		}

		await ScheduledJobEditorModal.open({
			size: 'medium', label: SCHEDULED_JOB_CREATE_TITLE, prefill: {
				schedulerName: proposal.schedulerName, className: proposal.schedulerClassName, cronExpression: proposal.cronExpression, isActive: true, parameterValues: {
					[PARAMETER_OBJECT_NAME]: proposal.objectApiName, [PARAMETER_MINIMUM_DAYS]: String(proposal.retentionDays)
				}
			}, lockedFields: [
				PARAMETER_OBJECT_NAME,
				'className'
			]
		});

		try
		{
			await this.runChecks();
			this.retentionProposals = this.decorateProposals(await getRetentionProposals());
		}
		catch
		{
			this.showErrorToast(REFRESH_FAILED_TOAST);
			return;
		}

		if(this.retentionProposals.length === 0)
		{
			this.isCustomizeMode = false;
		}
	}

	/**
	 * @description Opens the Schedule Chain Watchdog confirmation dialogue and, on confirm, creates
	 *              the recommended scheduled job with the chosen cron. A null create result means a
	 *              watchdog was already scheduled (a stale button click): the checks still refresh so
	 *              the row flips to a passing chip, but no created toast fires.
	 *
	 * @return {Promise<void>} Resolves after the schedule-and-refresh flow completes.
	 */
	async handleScheduleWatchdog()
	{
		// callControllerMethod resolves undefined after surfacing a failed fetch as an error
		// toast; without the proposal there is nothing to confirm, so the dialogue stays closed.
		const proposal = await this.callControllerMethod(getChainWatchdogProposal);

		if(!proposal)
		{
			return;
		}

		const result = await ScheduleChainWatchdogModal.open({size: 'small', label: WATCHDOG_MODAL_TITLE, proposal});

		if(result?.action !== 'confirm')
		{
			return;
		}

		const createdId = await this.callControllerMethod(scheduleChainWatchdog, {cronExpression: result.cronExpression});

		// callControllerMethod resolves undefined after surfacing a failed create as an error toast.
		if(createdId === undefined)
		{
			return;
		}

		await this.runChecks();

		if(createdId)
		{
			this.showSuccessToast(WATCHDOG_SUCCESS_TOAST);
		}
	}

	/**
	 * @description Opens the scheduled job editor prefilled with the recommended watchdog defaults
	 *              (class locked), then re-runs the checks so a save flips the row to a passing chip.
	 *
	 * @return {Promise<void>} Resolves after the modal + refresh cycle completes.
	 */
	async handleCustomizeWatchdog()
	{
		const proposal = await this.callControllerMethod(getChainWatchdogProposal);

		if(!proposal)
		{
			return;
		}

		await ScheduledJobEditorModal.open({
			size: 'medium', label: SCHEDULED_JOB_CREATE_TITLE, prefill: {
				schedulerName: proposal.schedulerName, className: proposal.schedulerClassName, cronExpression: proposal.cronExpression, isActive: true, parameterValues: {
					[proposal.staleThresholdMinutesParameterName]: proposal.staleThresholdMinutes, [proposal.batchSizeParameterName]: proposal.batchSize
				}
			}, lockedFields: ['className']
		});

		await this.runChecks();
	}

	/**
	 * @description The button a job-runner result row offers, if any. The waiting-jobs row activates a
	 *              runner; the job runner row repairs the one the org has. The capacity row returns
	 *              null: its sentences already say what to do, and replacing scheduled jobs that are in
	 *              order would not help.
	 *
	 * @param {string} resultName The name of the job-runner result.
	 *
	 * @return {string|null} The button label, or null when the row carries no button.
	 */
	getJobRunnerRemedyLabel(resultName)
	{
		if(resultName === CHECK_JOB_RUNNER_ORPHANED)
		{
			return JOB_RUNNER_ACTIVATE_BUTTON;
		}

		if(resultName === CHECK_JOB_RUNNER)
		{
			return JOB_RUNNER_REPAIR_BUTTON;
		}

		return null;
	}

	/**
	 * @description Handles the remedy button on a job-runner result row. The waiting-jobs row means no
	 *              runner is active, so its button activates one; every other job-runner row repairs the
	 *              runner it already has.
	 *
	 * @param {Event} event Click event from the remedy button (carries data-name with the result name).
	 *
	 * @return {Promise<void>} Resolves after the activate-or-repair flow completes.
	 */
	async handleJobRunnerRemedy(event)
	{
		if(event.currentTarget.dataset.name === CHECK_JOB_RUNNER_ORPHANED)
		{
			await this.handleActivateJobRunner();
			return;
		}

		await this.handleRepairJobRunner();
	}

	/**
	 * @description Opens the Activate dialogue and, on confirm, activates the job runner at the chosen
	 *              check interval, then re-runs the checks so every job-runner row and the card follow.
	 *
	 * @return {Promise<void>} Resolves after the activate-and-refresh flow completes.
	 */
	async handleActivateJobRunner()
	{
		const result = await ActivateJobRunnerModal.open({size: 'small', label: JOB_RUNNER_MODAL_TITLE, runningUserName: this.jobRunnerStatus?.runningUserName});

		if(result?.action !== 'confirm')
		{
			return;
		}

		const status = await this.callControllerMethod(activateJobRunner, {intervalMinutes: Number(result.intervalMinutes)});

		// callControllerMethod resolves undefined after surfacing a refused activation as an error toast.
		if(!status)
		{
			return;
		}

		await this.runChecks();
		this.showSuccessToast(formatTemplateString(JOB_RUNNER_ACTIVATED, [status.checkIntervalMinutes]));
	}

	/**
	 * @description Replaces the job runner's scheduled jobs, then re-runs the checks.
	 *
	 * @return {Promise<void>} Resolves after the repair-and-refresh flow completes.
	 */
	async handleRepairJobRunner()
	{
		// Repair derives the check interval from the existing runner records; with none, the controller
		// would ask for one, so open the picker instead.
		if(!this.jobRunnerStatus || !this.jobRunnerStatus.runnerRecordCount)
		{
			await this.handleActivateJobRunner();
			return;
		}

		const status = await this.callControllerMethod(repairJobRunner);

		// callControllerMethod resolves undefined after surfacing a refused repair as an error toast.
		if(!status)
		{
			return;
		}

		await this.runChecks();
		this.showSuccessToast(JOB_RUNNER_REPAIRED);
	}

	/**
	 * @description Asks for confirmation, because deactivating stops every job set to run on the runner,
	 *              and on OK deactivates it and re-runs the checks.
	 *
	 * @return {Promise<void>} Resolves after the deactivate-and-refresh flow completes.
	 */
	async handleDeactivateJobRunner()
	{
		const confirmed = await LightningConfirm.open({message: JOB_RUNNER_DEACTIVATE_CONFIRM, label: JOB_RUNNER_CARD_TITLE, theme: 'warning'});

		if(!confirmed)
		{
			return;
		}

		const status = await this.callControllerMethod(deactivateJobRunner);

		// callControllerMethod resolves undefined after surfacing a refused deactivation as an error toast.
		if(!status)
		{
			return;
		}

		await this.runChecks();
		this.showSuccessToast(JOB_RUNNER_DEACTIVATED);
	}

	/**
	 * @description Toggles customize mode. When enabling, fetches the current retention
	 *              proposals so sub-rows render with fresh data; a failed fetch is surfaced
	 *              as an error toast by callControllerMethod and leaves the mode unchanged.
	 *              When disabling, leaves the cached list in place (the sub-row template
	 *              unmounts anyway).
	 *
	 * @param {boolean} enabled Whether customize mode should be on.
	 *
	 * @return {Promise<void>} Resolves after the optional proposal fetch completes.
	 */
	async setCustomizeMode(enabled)
	{
		if(enabled)
		{
			// callControllerMethod resolves undefined after surfacing a failed fetch as an
			// error toast; staying in the current view beats an empty customize block.
			const proposals = await this.callControllerMethod(getRetentionProposals);

			if(!proposals)
			{
				return;
			}

			this.retentionProposals = this.decorateProposals(proposals);
		}

		this.isCustomizeMode = enabled;
	}

	/**
	 * @description Decorates each retention proposal with view-model fields that render
	 *              the record count with correct singular/plural grammar and locale-aware
	 *              thousands separators, and the label-sourced retention period text.
	 *              Returns a new array; does not mutate its input.
	 *
	 * @param {object[]} proposals The raw proposal list returned from the Apex controller.
	 *
	 * @return {object[]} A decorated copy where each proposal has `recordCountLabel` and `retentionLabel` added.
	 */
	decorateProposals(proposals)
	{
		if(!Array.isArray(proposals))
		{
			return [];
		}

		return proposals.map((proposal) => ({
			...proposal, recordCountLabel: this.formatRecordCountLabel(proposal.recordCount), retentionLabel: formatTemplateString(DAY_SUFFIX, [proposal.retentionDays])
		}));
	}

	/**
	 * @description Formats a record count as a human-readable label with correct pluralization
	 *              and locale thousands separators (e.g. 1 -> "1 record", 1234 -> "1,234 records").
	 *              Non-numeric, null, or undefined counts fall through `Number(count) || 0` and
	 *              render as "0 records". Zero itself also renders as "0 records" — English
	 *              pluralizes zero, so the plural branch is correct for both cases.
	 *
	 * @param {number} count The raw record count supplied by the Apex proposal. Non-numeric,
	 *                       null, or undefined values are coerced to 0 and render as "0 records".
	 *
	 * @return {string} The formatted record-count label.
	 */
	formatRecordCountLabel(count)
	{
		const numericCount = Number(count) || 0;

		if(numericCount === 1)
		{
			return RECORD_COUNT_SINGULAR;
		}

		return formatTemplateString(RECORD_COUNT_PLURAL, [numericCount.toLocaleString()]);
	}

	getIconName(status)
	{
		if(status === 'Pass')
		{
			return 'utility:success';
		}
		if(status === 'Warn')
		{
			return 'utility:warning';
		}
		return 'utility:error';
	}

	getIconVariant(status)
	{
		if(status === 'Pass')
		{
			return 'success';
		}
		if(status === 'Warn')
		{
			return 'warning';
		}
		return 'error';
	}
}