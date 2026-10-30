// SPDX-License-Identifier: Apache-2.0
// Steps the journeys that sign a second user in share: the first password change, and cleanup steps that never hide
// the journey's own failure.
const {expect} = require('@playwright/test');
const {randomUUID} = require('crypto');

// A form still loading can drop typed keys, so a journey types its new user's first password at most this many times.
const CHANGE_PASSWORD_ATTEMPTS = 3;
// The Change Your Password button enables within moments of the last key; a longer wait only delays a retype.
const PASSWORD_BUTTON_WAIT_MILLISECONDS = 5_000;

// The fields of the Change Your Password form, each with the element where the form writes what is wrong with it.
const CHANGE_PASSWORD_FIELDS = [
	{label: 'New Password', input: 'input#newpassword', message: '#newpassword-message'},
	{label: 'Confirm New Password', input: 'input#confirmpassword', message: '#confirmpassword-message'},
	{label: 'Answer', input: 'input#answer', message: '#answer-message'}
];

// Clears and types each field of the Change Your Password form key by key, and returns what was typed, in field order.
async function typeChangePasswordFields(page, password)
{
	const typedValues = [password, password, randomUUID()];
	for(const [index, field] of CHANGE_PASSWORD_FIELDS.entries())
	{
		await page.locator(field.input).fill('');
		await page.locator(field.input).pressSequentially(typedValues[index]);
	}
	return typedValues;
}

// Types a new password and answer key by key: the Change Your Password form checks its rules on each key and only then
// enables its button, so the fields are typed again while the button stays disabled.
async function typeNewPassword(page, changePassword, password, attemptsLeft)
{
	await typeChangePasswordFields(page, password);
	const enabled = await expect(changePassword).toBeEnabled({timeout: PASSWORD_BUTTON_WAIT_MILLISECONDS}).then(() => true, () => false);
	if(!enabled && attemptsLeft > 1)
	{
		await typeNewPassword(page, changePassword, password, attemptsLeft - 1);
	}
}

// Says which Change Your Password field the form still rejects: a field the form marks as invalid, or one that does not
// hold what was typed, with the form's own words about it. The typed values themselves are never written out.
async function describeInvalidFields(page, typedValues)
{
	const findings = [];
	const allMessages = [];
	for(const [index, field] of CHANGE_PASSWORD_FIELDS.entries())
	{
		const input = page.locator(field.input);
		if(await input.count() === 0)
		{
			findings.push(`${field.label} is not on the page`);
			continue;
		}
		const value = await input.inputValue();
		const describedBy = (await input.getAttribute('aria-describedby')) || '';
		const messageIds = [...new Set([field.message.slice(1), ...describedBy.split(/\s+/).filter(Boolean)])];
		const texts = [];
		for(const id of messageIds)
		{
			texts.push(...(await page.locator(`[id="${id}"]`).allTextContents()).map((text) => text.replace(/\s+/g, ' ').trim()).filter(Boolean));
		}
		const pageSays = texts.length > 0 ? `the page says "${texts.join(' / ')}"` : 'the page shows no message';
		allMessages.push(`${field.label}: ${pageSays}`);
		const markedInvalid = (await input.getAttribute('aria-invalid')) === 'true' || /error/i.test(describedBy);
		const typedDiffers = value !== typedValues[index];
		if(markedInvalid || typedDiffers)
		{
			const holds = typedDiffers ? `holds ${value.length} of the ${typedValues[index]?.length ?? 0} characters typed` : 'holds what was typed';
			findings.push(`${field.label} is still invalid (it ${holds}; ${pageSays})`);
		}
	}
	return findings.length > 0 ? findings.join('; ') : `no field is marked invalid (${allMessages.join('; ')})`;
}

// Fills the Change Your Password form and presses Change Password. The form can disable its button again after it read
// as enabled, so the press waits for the button to be enabled and stable right before it, and the whole fill and press is
// tried at most CHANGE_PASSWORD_ATTEMPTS times. When every try fails, the error says which field the form still rejects.
async function submitNewPassword(page, changePassword, password)
{
	let typedValues = [];
	for(let attempt = 1; attempt <= CHANGE_PASSWORD_ATTEMPTS; attempt++)
	{
		typedValues = await typeChangePasswordFields(page, password);
		const enabled = await expect(changePassword).toBeEnabled({timeout: PASSWORD_BUTTON_WAIT_MILLISECONDS}).then(() => true, () => false);
		if(enabled && await changePassword.click({timeout: PASSWORD_BUTTON_WAIT_MILLISECONDS}).then(() => true, () => false))
		{
			return;
		}
	}
	throw new Error(`Change Your Password did not accept the form after ${CHANGE_PASSWORD_ATTEMPTS} attempts: ${await describeInvalidFields(page, typedValues)}`);
}

// Builds a journey's cleanup step runner: each step runs whatever happened before it, and a failure is reported under
// the journey's part name and never hides the journey's own.
function cleanupStepRunner(partName)
{
	return async function runCleanupStep(step)
	{
		try
		{
			await step();
		}
		catch(cleanupFailure)
		{
			console.warn(`[${partName}] cleanup step failed: ${cleanupFailure.message}`);
		}
	};
}

module.exports = {CHANGE_PASSWORD_ATTEMPTS, cleanupStepRunner, submitNewPassword, typeNewPassword};
