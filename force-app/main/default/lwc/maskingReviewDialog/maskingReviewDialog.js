// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Badge-as-reclassify Review dialog for the Data Masking Advisor, built on
 * lightning/modal (LightningModal) so the modal chrome and the WCAG focus-trap come from the
 * platform rather than hand-authored markup. It shows the advisor's current classification and
 * signal band, an optional "why" reason, generic type-based "may contain" hints (never real data
 * sampling), and a radio group for setting the sensitivity level. It resolves only the chosen
 * level — assigning a masking rule on a promotion is the caller's job, not the dialog's.
 *
 * Resolution contract: Apply closes with `{level}` (one of the sensitivity literals); Cancel closes
 * with `null`; the platform header dismiss (the modal's X) closes with `undefined`. Callers treat
 * any non-`{level}` result as "no change".
 *
 * @author Jason van Beukering
 * @date May 2026, June 2026
 */
import {api} from 'lwc';
import LightningModal from 'lightning/modal';
import SENSITIVITY_SENSITIVE from '@salesforce/label/c.DataMaskingAdvisor_Sensitivity_Sensitive';
import SENSITIVITY_POSSIBLY from '@salesforce/label/c.DataMaskingAdvisor_Sensitivity_PossiblySensitive';
import SENSITIVITY_NOT from '@salesforce/label/c.DataMaskingAdvisor_Sensitivity_NotSensitive';
import BAND_WEAK from '@salesforce/label/c.DataMaskingAdvisor_SignalBand_Weak';
import BAND_MODERATE from '@salesforce/label/c.DataMaskingAdvisor_SignalBand_Moderate';
import BAND_STRONG from '@salesforce/label/c.DataMaskingAdvisor_SignalBand_Strong';
import TITLE from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_Title';
import CLASSIFICATION_HEADING from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_ClassificationHeading';
import SIGNAL_SUFFIX from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_SignalSuffix';
import WHY_HEADING from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_WhyHeading';
import SET_CLASSIFICATION_HEADING from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_SetClassificationHeading';
import MAY_CONTAIN_HEADING from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContainHeading';
import FOOTER_NOTE from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_FooterNote';
import CANCEL from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_Cancel';
import APPLY from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_Apply';
import MAY_CONTAIN_TEXT from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Text';
import MAY_CONTAIN_URL from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Url';
import MAY_CONTAIN_PICKLIST from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Picklist';
import MAY_CONTAIN_DATE from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Date';
import MAY_CONTAIN_ADDRESS from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Address';
import MAY_CONTAIN_DEFAULT from '@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Default';

/**
 * @description Static strings the template renders, grouped so the markup reads `{labels.x}`.
 * @type {Object<string, string>}
 */
const LABELS = {
	title: TITLE,
	classificationHeading: CLASSIFICATION_HEADING,
	whyHeading: WHY_HEADING,
	setClassificationHeading: SET_CLASSIFICATION_HEADING,
	mayContainHeading: MAY_CONTAIN_HEADING,
	footerNote: FOOTER_NOTE,
	cancel: CANCEL,
	apply: APPLY
};

/**
 * @description Display label for each sensitivity literal (the stable key → user-facing text).
 * @type {Object<string, string>}
 */
const SENSITIVITY_LABELS = {
	NotSensitive: SENSITIVITY_NOT, PossiblySensitive: SENSITIVITY_POSSIBLY, Sensitive: SENSITIVITY_SENSITIVE
};

/**
 * @description Display label for each match-strength band literal.
 * @type {Object<string, string>}
 */
const BAND_LABELS = {
	Weak: BAND_WEAK, Moderate: BAND_MODERATE, Strong: BAND_STRONG
};

/**
 * @description Pipe-delimited "may contain" hint set per field DisplayType. Types not listed fall
 * back to the default set. The hints are generic by type — the dialog never samples real data.
 * @type {Object<string, string>}
 */
const MAY_CONTAIN_BY_TYPE = {
	STRING: MAY_CONTAIN_TEXT,
	TEXTAREA: MAY_CONTAIN_TEXT,
	URL: MAY_CONTAIN_URL,
	PICKLIST: MAY_CONTAIN_PICKLIST,
	MULTIPICKLIST: MAY_CONTAIN_PICKLIST,
	DATE: MAY_CONTAIN_DATE,
	DATETIME: MAY_CONTAIN_DATE,
	ADDRESS: MAY_CONTAIN_ADDRESS
};

export default class MaskingReviewDialog extends LightningModal
{
	/**
	 * @description The field's display label, shown in the dialog subhead.
	 * @type {string}
	 */
	@api fieldLabel;

	/**
	 * @description The field's API name, shown as `object.field` in the subhead.
	 * @type {string}
	 */
	@api fieldApiName;

	/**
	 * @description The analyzed object's API name, shown as `object.field` in the subhead.
	 * @type {string}
	 */
	@api objectApiName;

	/**
	 * @description The field's current sensitivity level — one of `NotSensitive` / `PossiblySensitive`
	 * / `Sensitive`. Seeds the radio selection.
	 * @type {string}
	 */
	@api sensitivityLevel;

	/**
	 * @description The field's match-strength band — `Weak` / `Moderate` / `Strong`. Rendered as the
	 * read-only signal indicator; blank renders no signal.
	 * @type {string}
	 */
	@api matchStrength;

	/**
	 * @description The field's DisplayType, used to choose the generic "may contain" hint set.
	 * @type {string}
	 */
	@api fieldType;

	/**
	 * @description Optional reason the field was flagged (supplied by the analysis). The Why row
	 * renders only when this is non-blank.
	 * @type {string}
	 */
	@api reason;

	/**
	 * @description The pending radio selection. Seeded from `sensitivityLevel` once at mount (each
	 * modal open mounts a fresh instance, so it intentionally does not track post-mount
	 * `sensitivityLevel` changes) and resolved as `{level}` on Apply.
	 * @type {string}
	 */
	selectedLevel;

	/**
	 * @description Static label strings for the template.
	 * @returns {Object<string, string>}
	 */
	get labels()
	{
		return LABELS;
	}

	/**
	 * @description `object.field` reference shown in the subhead.
	 * @returns {string}
	 */
	get fieldReference()
	{
		return `${this.objectApiName}.${this.fieldApiName}`;
	}

	/**
	 * @description The radio options — least-to-most sensitive, bound to the stable literals.
	 * @returns {Array<{label: string, value: string}>}
	 */
	get levelOptions()
	{
		return [
			{label: SENSITIVITY_NOT, value: 'NotSensitive'},
			{label: SENSITIVITY_POSSIBLY, value: 'PossiblySensitive'},
			{label: SENSITIVITY_SENSITIVE, value: 'Sensitive'}
		];
	}

	/**
	 * @description Display text for the field's current classification.
	 * @returns {string}
	 */
	get classificationDisplay()
	{
		return SENSITIVITY_LABELS[this.sensitivityLevel] || '';
	}

	/**
	 * @description True when a recognized match-strength band is present to render.
	 * @returns {boolean}
	 */
	get hasSignal()
	{
		return !!BAND_LABELS[this.matchStrength];
	}

	/**
	 * @description The "{band} signal" text, e.g. "Weak signal".
	 * @returns {string}
	 */
	get signalText()
	{
		return `${BAND_LABELS[this.matchStrength]} ${SIGNAL_SUFFIX}`;
	}

	/**
	 * @description True when a non-blank reason was supplied.
	 * @returns {boolean}
	 */
	get hasReason()
	{
		return !!(this.reason && this.reason.trim());
	}

	/**
	 * @description The generic "may contain" hints for the field's type, as renderable items keyed
	 * by position (so duplicate hint text never collides in the template iteration).
	 * @returns {Array<{key: number, value: string}>}
	 */
	get mayContainItems()
	{
		const source = MAY_CONTAIN_BY_TYPE[this.fieldType] || MAY_CONTAIN_DEFAULT;
		return source.split('|').map((hint, index) => ({key: index, value: hint}));
	}

	/**
	 * @description Seeds the pending selection from the current sensitivity level at mount.
	 */
	connectedCallback()
	{
		this.selectedLevel = this.sensitivityLevel;
	}

	/**
	 * @description Updates the pending selection when the user picks a different level.
	 * @param {CustomEvent} event
	 */
	handleLevelChange(event)
	{
		this.selectedLevel = event.detail.value;
	}

	/**
	 * @description Resolves the dialog with the chosen level.
	 */
	handleApply()
	{
		this.close({level: this.selectedLevel});
	}

	/**
	 * @description Dismisses the dialog without a result.
	 */
	handleCancel()
	{
		this.close(null);
	}
}