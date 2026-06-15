// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the maskingReviewDialog LWC — the badge-as-reclassify Review
 *              dialog built on lightning/modal (LightningModal). The base modal supplies the
 *              chrome + focus-trap; this dialog renders the classification + signal band, an
 *              optional Why row, generic type-based "may contain" hints (never real data), and a
 *              radio group bound to the exact sensitivity literals. Apply resolves {level}; Cancel
 *              resolves null. Verified via real DOM rendering with the global lightning/modal mock
 *              (whose close() is a shared jest.fn).
 *
 * @author Jason van Beukering
 * @date May 2026, June 2026
 */
import {createElement} from 'lwc';
import {mockClose} from 'lightning/modal';
import MaskingReviewDialog from 'c/maskingReviewDialog';

jest.mock('@salesforce/label/c.DataMaskingAdvisor_Sensitivity_Sensitive', () => ({default: 'Sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Sensitivity_PossiblySensitive', () => ({default: 'Possibly Sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Sensitivity_NotSensitive', () => ({default: 'Not Sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_SignalBand_Weak', () => ({default: 'Weak'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_SignalBand_Moderate', () => ({default: 'Moderate'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_SignalBand_Strong', () => ({default: 'Strong'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_Title', () => ({default: 'Review field'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_ClassificationHeading', () => ({default: 'Advisor classification'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_SignalSuffix', () => ({default: 'signal'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_WhyHeading', () => ({default: 'Why'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_SetClassificationHeading', () => ({default: 'Set classification'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContainHeading', () => ({default: 'Fields of this kind may contain'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_FooterNote', () => ({default: 'Session-only — this moves the field and is included in the export package.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_Cancel', () => ({default: 'Cancel'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_Apply', () => ({default: 'Apply'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Text', () => ({default: 'Names|Phone numbers|Addresses|Free-form notes'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Url', () => ({default: 'Profile photos or document links'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Picklist', () => ({default: 'Predefined category values'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Date', () => ({default: 'Dates of birth or personal events'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Address', () => ({default: 'Street, city, postal code'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewDialog_MayContain_Default', () => ({default: 'Structured field values'}), {virtual: true});

/**
 * @description Mounts a maskingReviewDialog with the supplied properties and returns the element.
 * @param {Object} [props] - @api property overrides applied before append.
 * @returns {HTMLElement}
 */
function createDialog(props = {})
{
	const element = createElement('c-masking-review-dialog', {is: MaskingReviewDialog});
	element.fieldLabel = props.fieldLabel === undefined ? 'Mailing Street' : props.fieldLabel;
	element.fieldApiName = props.fieldApiName === undefined ? 'MailingStreet' : props.fieldApiName;
	element.objectApiName = props.objectApiName === undefined ? 'Contact' : props.objectApiName;
	element.sensitivityLevel = props.sensitivityLevel === undefined ? 'PossiblySensitive' : props.sensitivityLevel;
	element.matchStrength = props.matchStrength === undefined ? 'Moderate' : props.matchStrength;
	element.fieldType = props.fieldType === undefined ? 'STRING' : props.fieldType;
	if(props.reason !== undefined)
	{
		element.reason = props.reason;
	}
	document.body.appendChild(element);
	return element;
}

/**
 * @description Flushes the LWC microtask render queue.
 * @returns {Promise<void>}
 */
function flush()
{
	return Promise.resolve();
}

afterEach(() =>
{
	while(document.body.firstChild)
	{
		document.body.removeChild(document.body.firstChild);
	}
	jest.clearAllMocks();
});

describe('c-masking-review-dialog', () =>
{
	describe('classification picker', () =>
	{
		it('renders a radio group whose options are exactly the three sensitivity literals', async() =>
		{
			const element = createDialog();
			await flush();

			const radio = element.shadowRoot.querySelector('lightning-radio-group');
			expect(radio).not.toBeNull();
			expect(radio.options.map((option) => option.value)).toEqual([
				'NotSensitive',
				'PossiblySensitive',
				'Sensitive'
			]);
			expect(radio.options.map((option) => option.label)).toEqual([
				'Not Sensitive',
				'Possibly Sensitive',
				'Sensitive'
			]);
		});

		it('initializes the radio selection to the current sensitivity level', async() =>
		{
			const element = createDialog({sensitivityLevel: 'Sensitive'});
			await flush();
			expect(element.shadowRoot.querySelector('lightning-radio-group').value).toBe('Sensitive');
		});
	});

	describe('classification + signal display', () =>
	{
		it('shows the current classification display text and the signal band', async() =>
		{
			const element = createDialog({sensitivityLevel: 'PossiblySensitive', matchStrength: 'Weak'});
			await flush();

			expect(element.shadowRoot.querySelector('[data-testid="classification-display"]').textContent).toBe('Possibly Sensitive');
			expect(element.shadowRoot.querySelector('[data-testid="signal-band"]').textContent).toBe('Weak signal');
		});

		it('shows no classification text for an unrecognized level', async() =>
		{
			const element = createDialog({sensitivityLevel: 'Bogus'});
			await flush();
			expect(element.shadowRoot.querySelector('[data-testid="classification-display"]').textContent.trim()).toBe('');
		});

		it('renders no signal band when match strength is blank', async() =>
		{
			const element = createDialog({matchStrength: ''});
			await flush();
			expect(element.shadowRoot.querySelector('[data-testid="signal-band"]')).toBeNull();
		});
	});

	describe('may-contain hints', () =>
	{
		it('renders the text-type hint list for a STRING field', async() =>
		{
			const element = createDialog({fieldType: 'STRING'});
			await flush();

			const items = [...element.shadowRoot.querySelectorAll('[data-testid="may-contain-item"]')].map((node) => node.textContent);
			expect(items).toEqual([
				'Names',
				'Phone numbers',
				'Addresses',
				'Free-form notes'
			]);
		});

		it('renders a different hint list for a DATE field', async() =>
		{
			const element = createDialog({fieldType: 'DATE'});
			await flush();

			const items = [...element.shadowRoot.querySelectorAll('[data-testid="may-contain-item"]')].map((node) => node.textContent);
			expect(items).toEqual(['Dates of birth or personal events']);
		});

		it('renders the default hint list for an unmapped field type', async() =>
		{
			const element = createDialog({fieldType: 'REFERENCE'});
			await flush();

			const items = [...element.shadowRoot.querySelectorAll('[data-testid="may-contain-item"]')].map((node) => node.textContent);
			expect(items).toEqual(['Structured field values']);
		});
	});

	describe('why row', () =>
	{
		it('shows the reason when one is provided', async() =>
		{
			const element = createDialog({reason: 'Field name matches a sensitive pattern.'});
			await flush();

			const why = element.shadowRoot.querySelector('[data-testid="why-row"]');
			expect(why).not.toBeNull();
			expect(why.textContent).toContain('Field name matches a sensitive pattern.');
		});

		it('omits the why row when no reason is provided', async() =>
		{
			const element = createDialog();
			await flush();
			expect(element.shadowRoot.querySelector('[data-testid="why-row"]')).toBeNull();
		});
	});

	describe('resolution', () =>
	{
		it('resolves {level} with the chosen level on Apply', async() =>
		{
			const element = createDialog({sensitivityLevel: 'PossiblySensitive'});
			await flush();

			const radio = element.shadowRoot.querySelector('lightning-radio-group');
			radio.dispatchEvent(new CustomEvent('change', {detail: {value: 'Sensitive'}}));
			await flush();
			expect(radio.value).toBe('Sensitive');

			element.shadowRoot.querySelector('[data-testid="apply-button"]').click();

			expect(mockClose).toHaveBeenCalledTimes(1);
			expect(mockClose).toHaveBeenCalledWith({level: 'Sensitive'});
		});

		it('resolves the unchanged level on Apply when nothing was changed', async() =>
		{
			const element = createDialog({sensitivityLevel: 'NotSensitive'});
			await flush();

			element.shadowRoot.querySelector('[data-testid="apply-button"]').click();

			expect(mockClose).toHaveBeenCalledWith({level: 'NotSensitive'});
		});

		it('resolves null on Cancel', async() =>
		{
			const element = createDialog();
			await flush();

			element.shadowRoot.querySelector('[data-testid="cancel-button"]').click();

			expect(mockClose).toHaveBeenCalledTimes(1);
			expect(mockClose).toHaveBeenCalledWith(null);
		});
	});

	describe('chrome', () =>
	{
		it('renders the modal header, footer note, and both action buttons', async() =>
		{
			const element = createDialog();
			await flush();

			expect(element.shadowRoot.querySelector('lightning-modal-header')).not.toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="footer-note"]').textContent)
			.toContain('Session-only');
			expect(element.shadowRoot.querySelector('[data-testid="apply-button"]')).not.toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="cancel-button"]')).not.toBeNull();
		});

		it('renders the field label and object.field reference in the subhead', async() =>
		{
			const element = createDialog({fieldLabel: 'Mailing Street', objectApiName: 'Contact', fieldApiName: 'MailingStreet'});
			await flush();

			const subhead = element.shadowRoot.querySelector('.review__subhead').textContent;
			expect(subhead).toContain('Mailing Street');
			expect(subhead).toContain('Contact.MailingStreet');
		});
	});
});
