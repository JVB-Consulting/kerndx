// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Confirmation dialogue for the Data Masking Advisor "Generate bundle" flow. Appears only
 *              when the staged bundle would activate one or more dormant masking rules. Lists each
 *              dormant rule with its current blast radius (existing active targets), restates the
 *              framework-path masking scope, and requires an explicit acknowledgment before the
 *              admin can generate the deployable configuration.
 *
 *              Built on lightning/modal (LightningModal) for the native focus-trap and focus
 *              management the inline SLDS modal lacked: focus is trapped inside the dialog, Escape
 *              closes it, and focus is restored to the trigger on close — all provided by the base
 *              class, not hand-rolled here. Closes with {action: 'confirm'} or {action: 'cancel'};
 *              an Escape dismissal resolves the modal with undefined, which the caller treats as a
 *              cancel.
 *
 * @author Jason van Beukering
 *
 * @date May 2026
 */
/* eslint-disable-next-line kerndx/enforce-component-naming */
import LightningModal from 'lightning/modal';
import {api} from 'lwc';

export default class GenerateBundleModal extends LightningModal
{
	/**
	 * @description Modal header text. Pre-resolved from a CustomLabel by the caller.
	 *
	 * @type {string}
	 */
	@api heading = '';

	/**
	 * @description Lead paragraph explaining that generating the bundle activates dormant rules.
	 *              Pre-interpolated (singular/plural) by the caller.
	 *
	 * @type {string}
	 */
	@api leadParagraph = '';

	/**
	 * @description One row per dormant rule that will be activated. Each entry is
	 *              {key: string, message: string}, with message already interpolated from the
	 *              shipped per-rule CustomLabel (rule label + existing-active-target count).
	 *
	 * @type {Array<{key: string, message: string}>}
	 */
	@api dormantRuleRows = [];

	/**
	 * @description The framework-path masking scope statement, surfaced verbatim from the shipped
	 *              scope-honesty CustomLabel so the admin is reminded the bundle masks on framework
	 *              paths only — not org-wide and not encryption-at-rest.
	 *
	 * @type {string}
	 */
	@api scopeBody = '';

	/**
	 * @description Label for the acknowledgment checkbox that gates the Confirm button.
	 *
	 * @type {string}
	 */
	@api acknowledgeLabel = '';

	/**
	 * @description Label for the confirm button.
	 *
	 * @type {string}
	 */
	@api confirmLabel = '';

	/**
	 * @description Label for the cancel button.
	 *
	 * @type {string}
	 */
	@api cancelLabel = '';

	/**
	 * @description Whether the admin has acknowledged that the listed rules will be activated.
	 *              Confirm stays disabled until this is true.
	 *
	 * @type {boolean}
	 */
	acknowledged = false;

	/**
	 * @description Gates the Confirm button on an explicit acknowledgment.
	 *
	 * @return {boolean} true while the acknowledgment checkbox is unchecked.
	 */
	get confirmDisabled()
	{
		return this.acknowledged !== true;
	}

	/**
	 * @description Tracks the acknowledgment checkbox state.
	 *
	 * @param {Object} event The lightning-input change event carrying detail.checked.
	 */
	handleAcknowledgeChange(event)
	{
		this.acknowledged = event.detail.checked === true;
	}

	/**
	 * @description Confirms the activation and bundle generation, returning control to the caller.
	 *              Enforces the acknowledgment gate in code (not only via the disabled button) so the
	 *              dialogue cannot resolve to confirm until the admin has acknowledged.
	 */
	handleConfirm()
	{
		if(this.confirmDisabled)
		{
			return;
		}
		this.close(/** @type {*} */({action: 'confirm'}));
	}

	/**
	 * @description Dismisses the dialogue without generating, returning control to the caller.
	 */
	handleCancel()
	{
		this.close(/** @type {*} */({action: 'cancel'}));
	}
}