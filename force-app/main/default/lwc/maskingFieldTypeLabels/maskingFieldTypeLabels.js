// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Shared field-type label helper for the Data Masking Advisor LWCs. Maps a masking rule's
 *              upper-cased field-type literals (MaskingRule__mdt.ApplicableFieldTypes__c) to friendly
 *              display names and renders the comma-joined "applies to" line — an empty type list reads
 *              "Any text field" because the rule then applies to every text-shaped field. One source of
 *              truth so the rule-detail popup and the add-rule menu always agree on the wording.
 *
 * @author Jason van Beukering
 *
 * @date June 2026
 */
import FIELD_TYPE_TEXT from '@salesforce/label/c.DataMaskingAdvisor_FieldType_Text';
import FIELD_TYPE_LONG_TEXT from '@salesforce/label/c.DataMaskingAdvisor_FieldType_LongText';
import FIELD_TYPE_URL from '@salesforce/label/c.DataMaskingAdvisor_FieldType_Url';
import FIELD_TYPE_EMAIL from '@salesforce/label/c.DataMaskingAdvisor_FieldType_Email';
import FIELD_TYPE_PHONE from '@salesforce/label/c.DataMaskingAdvisor_FieldType_Phone';
import FIELD_TYPE_ENCRYPTED from '@salesforce/label/c.DataMaskingAdvisor_FieldType_EncryptedText';
import FIELD_TYPE_ANY from '@salesforce/label/c.DataMaskingAdvisor_FieldType_AnyText';

/**
 * @description Friendly display name per masking-rule field-type literal. Types not listed fall back to the
 * raw literal so a future engine type still renders rather than vanishing.
 * @type {Object<string, string>}
 */
const FIELD_TYPE_LABELS = {
	STRING: FIELD_TYPE_TEXT, TEXTAREA: FIELD_TYPE_LONG_TEXT, URL: FIELD_TYPE_URL, EMAIL: FIELD_TYPE_EMAIL, PHONE: FIELD_TYPE_PHONE, ENCRYPTEDSTRING: FIELD_TYPE_ENCRYPTED
};

/**
 * @description The friendly display name for a single field-type literal, falling back to the raw literal so
 * a future engine type still renders rather than vanishing. A blank type returns an empty string.
 * @param {string} type The upper-cased field-type literal (for example `EMAIL`, `TEXTAREA`).
 * @returns {string}
 */
export function friendlyFieldType(type)
{
	if(!type)
	{
		return '';
	}
	return FIELD_TYPE_LABELS[type] || type;
}

/**
 * @description The friendly field-type names a rule applies to, comma-joined. An unscoped rule (no
 * applicable types) reads "Any text field" because it runs on every text-shaped field.
 * @param {Array<string>} types The rule's upper-cased applicable field-type literals.
 * @returns {string}
 */
export function friendlyFieldTypes(types)
{
	const list = types || [];
	if(list.length === 0)
	{
		return FIELD_TYPE_ANY;
	}
	return list.map((type) => friendlyFieldType(type)).join(', ');
}