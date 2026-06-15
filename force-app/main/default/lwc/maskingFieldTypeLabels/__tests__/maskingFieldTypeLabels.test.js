// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the maskingFieldTypeLabels shared helper — friendlyFieldTypes maps a
 *              masking rule's upper-cased field-type literals to friendly display names, comma-joined, with
 *              an empty list reading "Any text field" and an unknown literal falling back to itself.
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {friendlyFieldType, friendlyFieldTypes} from 'c/maskingFieldTypeLabels';

jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Text', () => ({default: 'Text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_LongText', () => ({default: 'Long Text Area'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Url', () => ({default: 'URL'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Email', () => ({default: 'Email'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Phone', () => ({default: 'Phone'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_EncryptedText', () => ({default: 'Encrypted Text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_AnyText', () => ({default: 'Any text field'}), {virtual: true});

describe('c-masking-field-type-labels — friendlyFieldTypes', () =>
{
	it('reads "Any text field" for an empty type list', () =>
	{
		expect(friendlyFieldTypes([])).toBe('Any text field');
	});

	it('reads "Any text field" when no type list is supplied', () =>
	{
		expect(friendlyFieldTypes(null)).toBe('Any text field');
		expect(friendlyFieldTypes(undefined)).toBe('Any text field');
	});

	it('maps each known type literal to its friendly name, comma-joined in order', () =>
	{
		expect(friendlyFieldTypes([
			'STRING',
			'TEXTAREA',
			'URL',
			'EMAIL',
			'PHONE',
			'ENCRYPTEDSTRING'
		])).toBe('Text, Long Text Area, URL, Email, Phone, Encrypted Text');
	});

	it('falls back to the raw literal for a type with no friendly mapping', () =>
	{
		expect(friendlyFieldTypes([
			'STRING',
			'SOMETHING_NEW'
		])).toBe('Text, SOMETHING_NEW');
	});
});

describe('c-masking-field-type-labels — friendlyFieldType', () =>
{
	it('maps a known type literal to its friendly name', () =>
	{
		expect(friendlyFieldType('EMAIL')).toBe('Email');
		expect(friendlyFieldType('TEXTAREA')).toBe('Long Text Area');
	});

	it('falls back to the raw literal for a type with no friendly mapping', () =>
	{
		expect(friendlyFieldType('SOMETHING_NEW')).toBe('SOMETHING_NEW');
	});

	it('returns an empty string for a blank or missing type', () =>
	{
		expect(friendlyFieldType('')).toBe('');
		expect(friendlyFieldType(null)).toBe('');
		expect(friendlyFieldType(undefined)).toBe('');
	});
});
