// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Displays post-install health check results with pass/warn/fail status,
 * action buttons, and passing chips. Automatically runs checks on load and supports refresh.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, June 2026
 */
import {ComponentBuilder} from 'c/componentBuilder';
import ClassTypeResolverSetupModal from 'c/classTypeResolverSetupModal';
import ApplyRetentionModal from 'c/applyRetentionModal';
import ScheduledJobEditorModal from 'c/scheduledJobEditorModal';
import runHealthChecks from '@salesforce/apex/CTRL_HealthCheck.runHealthChecks';
import getRetentionProposals from '@salesforce/apex/CTRL_HealthCheck.getRetentionProposals';
import applyRetentionRecommendations from '@salesforce/apex/CTRL_HealthCheck.applyRetentionRecommendations';
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

const PARAMETER_OBJECT_NAME = 'objectName';
const PARAMETER_MINIMUM_DAYS = 'minimumNumberOfDays';
const DATA_MASKING_ADVISOR_TAB = 'DataMaskingAdvisor';
// The custom-object coverage card deep-links into the advisor carrying this page-state flag so the advisor
// auto-runs the coverage scan on arrival rather than leaving the admin to press "Scan N" again.
const ADVISOR_SCAN_STATE_KEY = 'c__scan';
const ADVISOR_SCAN_STATE_VALUE = '1';

export default class HealthCheck extends ComponentBuilder('controller', 'notification', 'navigation')
{
	results = [];
	hasResults = false;
	allPassed = false;
	hasFailures = false;
	isCustomizeMode = false;
	retentionProposals = [];

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
		warnSectionHeading: WARN_SECTION_HEADING
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
			return ACTION_REQUIRED_HEADLINE.replace('{0}', failCount).replace('{1}', warnCount).replace('{2}', warnCount === 1 ? 'warning' : 'warnings');
		}
		return REVIEW_RECOMMENDED_HEADLINE.replace('{0}', warnCount).replace('{1}', warnCount === 1 ? 'warning' : 'warnings');
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

		const data = await this.callControllerMethod(runHealthChecks);

		if(data)
		{
			this.results = data.map((item) => ({
				...item,
				passed: item.status === 'Pass',
				warned: item.status === 'Warn',
				failed: item.status === 'Fail',
				isDataRetention: item.name === CHECK_DATA_RETENTION,
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

		await ClassTypeResolverSetupModal.open({size: 'medium'});

		await this.runChecks();
	}

	/**
	 * @description Opens the Apply Recommended Retention modal after fetching proposals from Apex.
	 *              Dispatches to confirm (apply + toast + refresh), customize (flip mode), or cancel (no-op)
	 *              based on the modal's resolved action.
	 *
	 * @return {Promise<void>} Resolves after the full apply-or-customize flow completes.
	 */
	async handleApplyRetention()
	{
		const proposals = await getRetentionProposals();
		const result = await ApplyRetentionModal.open({
			size: 'medium',
			proposals,
			title: MODAL_TITLE,
			subtitle: MODAL_SUBTITLE.replace('{0}', proposals.length),
			firstRunWarning: FIRST_RUN_WARNING,
			confirmButtonLabel: CREATE_BUTTON.replace('{0}', proposals.length),
			customizeLinkLabel: CUSTOMIZE_LINK
		});

		if(result?.action === 'confirm')
		{
			const insertedIds = await applyRetentionRecommendations({
				proposalsJson: JSON.stringify(result.proposals)
			});
			await this.runChecks();
			this.showSuccessToast(SUCCESS_TOAST.replace('{0}', insertedIds.length));
		}
		else if(result?.action === 'customize')
		{
			this.setCustomizeMode(true);
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
			size: 'medium', prefill: {
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
		catch(error)
		{
			this.showErrorToast('Failed to refresh retention proposals');
			return;
		}

		if(this.retentionProposals.length === 0)
		{
			this.isCustomizeMode = false;
		}
	}

	/**
	 * @description Toggles customize mode. When enabling, fetches the current retention
	 *              proposals so sub-rows render with fresh data. When disabling, leaves
	 *              the cached list in place (the sub-row template unmounts anyway).
	 *
	 * @param {boolean} enabled Whether customize mode should be on.
	 *
	 * @return {Promise<void>} Resolves after the optional proposal fetch completes.
	 */
	async setCustomizeMode(enabled)
	{
		if(enabled)
		{
			this.retentionProposals = this.decorateProposals(await getRetentionProposals());
		}

		this.isCustomizeMode = enabled;
	}

	/**
	 * @description Decorates each retention proposal with a view-model field that renders
	 *              the record count with correct singular/plural grammar and locale-aware
	 *              thousands separators. Returns a new array; does not mutate its input.
	 *
	 * @param {object[]} proposals The raw proposal list returned from the Apex controller.
	 *
	 * @return {object[]} A decorated copy where each proposal has `recordCountLabel` added.
	 */
	decorateProposals(proposals)
	{
		if(!Array.isArray(proposals))
		{
			return [];
		}

		return proposals.map((proposal) => ({
			...proposal, recordCountLabel: this.formatRecordCountLabel(proposal.recordCount)
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
			return '1 record';
		}

		return numericCount.toLocaleString() + ' records';
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