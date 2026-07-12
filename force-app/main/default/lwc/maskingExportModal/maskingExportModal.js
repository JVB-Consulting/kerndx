// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Export-package dialog for the Data Masking Advisor, built on lightning/modal
 * (LightningModal) so the chrome and the WCAG focus-trap come from the platform. It presents the export as
 * a diff: a one-line change summary, a package-contents list grouped Add · Re-enable · Disable (each row a
 * scope glyph, the field → rule, and a verb tag), an optional package-name chip, then two deploy paths —
 * a live org-alias input that fills the Salesforce CLI command (with Copy), and the zip download.
 *
 * It renders NO on-screen metadata XML: the controller already generated the zip, and the caller performs
 * the actual download once this dialog resolves. The displayed CLI command mirrors the deploy line shipped
 * in the bundle's own README so the two instructions never diverge.
 *
 * Resolution contract: Download closes with `{action:'download'}`; Close closes with `null`; the platform
 * header dismiss (the modal's X) closes with `undefined`. Callers treat any non-download result as "do not
 * download".
 *
 * @author Jason van Beukering
 * @date June 2026, July 2026
 */
import {api} from 'lwc';
import LightningModal from 'lightning/modal';
import {copyToClipBoard} from 'c/utilitySystem';
import TITLE from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Title';
import DOWNLOAD from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Download';
import CANCEL from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Cancel';
import CHANGE_SUMMARY_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_ChangeSummary_Singular';
import CHANGE_SUMMARY_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_ChangeSummary_Plural';
import PACKAGE_HEADING from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_PackageHeading';
import NO_CHANGES from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_NoChanges';
import VERB_ADD_LABEL from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Verb_Add';
import VERB_DISABLE_LABEL from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Verb_Disable';
import VERB_REENABLE_LABEL from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Verb_ReEnable';
import OBJECT_WIDE_TAG from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_ObjectWideTag';
import DEPLOY_CLI_INTRO from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Deploy_CliIntro';
import DEPLOY_OTHER_TOOLS_NOTE from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Deploy_OtherToolsNote';
import DEPLOY_COMMAND from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Deploy_Command';
import DEPLOY_ALIAS_PLACEHOLDER from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Deploy_AliasPlaceholder';
import ORG_ALIAS_LABEL from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_OrgAlias_Label';
import ORG_ALIAS_PLACEHOLDER from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_OrgAlias_Placeholder';
import DEPLOY_COMMAND_ARIA from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Deploy_CommandAriaLabel';
import COPY from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Copy';
import COPIED from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_Copied';

// The diff verbs, in the order the contents list groups them (Add, then Re-enable, then Disable). The
// values double as the per-row `data-verb` CSS keys, so they match the keys the advisor tags targets with.
const VERB_ADD = 'add';
const VERB_DISABLE = 'disable';
const VERB_REENABLE = 're-enable';
// Scope marker on each grouped diff row: an object-wide target (blank field) versus a field-level target.
const SCOPE_OBJECT = 'O';
// Decorative scope glyphs (aria-hidden in the template); the row's accessible content is its text.
const GLYPH_OBJECT_WIDE = '🌐';
const GLYPH_FIELD = '📍';

/**
 * @description Static label strings the template renders, grouped so the markup reads `{labels.x}`.
 * @type {Object<string, string>}
 */
const LABELS = {
	title: TITLE,
	download: DOWNLOAD,
	cancel: CANCEL,
	packageHeading: PACKAGE_HEADING,
	noChanges: NO_CHANGES,
	objectWideTag: OBJECT_WIDE_TAG,
	deployCliIntro: DEPLOY_CLI_INTRO,
	deployOtherToolsNote: DEPLOY_OTHER_TOOLS_NOTE,
	orgAliasLabel: ORG_ALIAS_LABEL,
	orgAliasPlaceholder: ORG_ALIAS_PLACEHOLDER,
	deployCommandAriaLabel: DEPLOY_COMMAND_ARIA
};

export default class MaskingExportModal extends LightningModal
{
	/**
	 * @description API name of the analyzed object, interpolated into the change summary.
	 * @type {string}
	 */
	@api objectApiName;

	/**
	 * @description Optional package file name to display as a chip (the caller supplies the resolved name).
	 * Blank or absent renders no chip — the file name is informational, not required to confirm.
	 * @type {string}
	 */
	@api fileName;

	/**
	 * @description The create half of the diff — display rows `{scope, fieldLabel, ruleLabel}` for new
	 * targets the package will add.
	 * @type {Array<Object>}
	 */
	@api addRows;

	/**
	 * @description The disable half of the diff — display rows for existing targets the package will turn off.
	 * @type {Array<Object>}
	 */
	@api disableRows;

	/**
	 * @description The re-enable half of the diff — display rows for inactive targets the package will turn
	 * back on.
	 * @type {Array<Object>}
	 */
	@api reEnableRows;

	/**
	 * @description The org alias typed into the deploy-command input; interpolated live into the command.
	 * @type {string}
	 */
	aliasValue = '';

	/**
	 * @description True once the command has been copied, flipping the Copy button label until the alias
	 * changes.
	 * @type {boolean}
	 */
	copied = false;

	/**
	 * @description Static label strings for the template.
	 * @returns {Object<string, string>}
	 */
	get labels()
	{
		return LABELS;
	}

	/**
	 * @description Count of create rows.
	 * @returns {number}
	 */
	get addCount()
	{
		return (this.addRows || []).length;
	}

	/**
	 * @description Count of disable rows.
	 * @returns {number}
	 */
	get disableCount()
	{
		return (this.disableRows || []).length;
	}

	/**
	 * @description Count of re-enable rows.
	 * @returns {number}
	 */
	get reEnableCount()
	{
		return (this.reEnableRows || []).length;
	}

	/**
	 * @description Total changes the package applies (create + disable + re-enable).
	 * @returns {number}
	 */
	get totalChanges()
	{
		return this.addCount + this.disableCount + this.reEnableCount;
	}

	/**
	 * @description True when the diff carries at least one change (gates the contents list vs the empty row).
	 * @returns {boolean}
	 */
	get hasChanges()
	{
		return this.totalChanges > 0;
	}

	/**
	 * @description The interpolated change summary — singular for a one-change package, plural (total +
	 * object + add/disable/re-enable breakdown) otherwise.
	 * @returns {string}
	 */
	get summaryText()
	{
		const add = String(this.addCount);
		const disable = String(this.disableCount);
		const reEnable = String(this.reEnableCount);
		if(this.totalChanges === 1)
		{
			return CHANGE_SUMMARY_SINGULAR.replace('{0}', this.objectApiName).replace('{1}', add).replace('{2}', disable).replace('{3}', reEnable);
		}
		return CHANGE_SUMMARY_PLURAL
		.replace('{0}', String(this.totalChanges))
		.replace('{1}', this.objectApiName)
		.replace('{2}', add)
		.replace('{3}', disable)
		.replace('{4}', reEnable);
	}

	/**
	 * @description The contents-list heading with the total change count interpolated.
	 * @returns {string}
	 */
	get packageHeadingText()
	{
		return PACKAGE_HEADING.replace('{0}', String(this.totalChanges));
	}

	/**
	 * @description The grouped diff decorated for rendering — Add rows, then Re-enable, then Disable. Each
	 * row carries a stable key, its scope flags + glyph, the field/rule text, and the verb + verb label.
	 * @returns {Array<Object>}
	 */
	get contentsRows()
	{
		const rows = [];
		let index = 0;
		const collect = (list, verb, verbLabel) =>
		{
			(list || []).forEach((row) =>
			{
				const isObjectWide = row.scope === SCOPE_OBJECT;
				rows.push({
					key: verb + '-' + index++,
					isField: !isObjectWide,
					isObjectWide,
					glyph: isObjectWide ? GLYPH_OBJECT_WIDE : GLYPH_FIELD,
					fieldLabel: row.fieldLabel,
					ruleLabel: row.ruleLabel,
					verb,
					verbLabel
				});
			});
		};
		collect(this.addRows, VERB_ADD, VERB_ADD_LABEL);
		collect(this.reEnableRows, VERB_REENABLE, VERB_REENABLE_LABEL);
		collect(this.disableRows, VERB_DISABLE, VERB_DISABLE_LABEL);
		return rows;
	}

	/**
	 * @description The Salesforce CLI deploy command with the typed alias (or the placeholder when blank)
	 * filled in. The command body mirrors the bundle README's own deploy line.
	 * @returns {string}
	 */
	get deployCommand()
	{
		const alias = this.aliasValue && this.aliasValue.trim() ? this.aliasValue.trim() : DEPLOY_ALIAS_PLACEHOLDER;
		return DEPLOY_COMMAND.replace('{0}', alias);
	}

	/**
	 * @description The Copy button label — "Copied" immediately after a copy, otherwise the copy prompt.
	 * @returns {string}
	 */
	get copyButtonLabel()
	{
		return this.copied ? COPIED : COPY;
	}

	/**
	 * @description True when a non-blank package file name was supplied, gating the package chip.
	 * @returns {boolean}
	 */
	get hasFileName()
	{
		return !!(this.fileName && this.fileName.trim());
	}

	/**
	 * @description Records the typed org alias (re-filling the command via the getter) and re-arms the Copy
	 * button so the admin copies the updated command.
	 * @param {CustomEvent} event - The lightning-input change event carrying the new value in detail.
	 */
	handleAliasChange(event)
	{
		this.aliasValue = event.detail.value;
		this.copied = false;
	}

	/**
	 * @description Copies the resolved deploy command to the clipboard and flips the button label to
	 * confirm — only once the copy actually succeeded. A failed copy (Clipboard API and its
	 * temporary-input fallback both failing) leaves the button re-armed so the admin can retry.
	 */
	async handleCopyCommand()
	{
		this.copied = false;
		try
		{
			await copyToClipBoard(this.deployCommand);
			this.copied = true;
		}
		catch
		{
			// copyToClipBoard already logged the failure; the button stays re-armed for a retry.
		}
	}

	/**
	 * @description Resolves the dialog with the download action.
	 */
	handleDownload()
	{
		this.close({action: 'download'});
	}

	/**
	 * @description Dismisses the dialog without downloading.
	 */
	handleCancel()
	{
		this.close(null);
	}
}