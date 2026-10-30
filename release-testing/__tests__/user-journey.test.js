// SPDX-License-Identifier: Apache-2.0
jest.mock('@playwright/test', () => ({expect: jest.fn()}));

const {expect: playwrightExpect} = require('@playwright/test');
const {CHANGE_PASSWORD_ATTEMPTS, cleanupStepRunner, typeNewPassword} = require('../e2e/helpers/user-journey');

const PASSWORD = 'Example-password-1';

/**
 * @description A page whose three password form fields record what was typed into them.
 *
 * @returns {{page: object, typed: string[]}}
 */
function recordingPage()
{
	const typed = [];
	const page = {
		locator: (selector) => ({
			fill: jest.fn(async() => {}),
			pressSequentially: jest.fn(async(text) => typed.push(`${selector}=${text}`))
		})
	};
	return {page, typed};
}

/**
 * @description Answers the button check in turn: true for an enabled button, false for one still disabled.
 *
 * @param {boolean[]} answers One answer per check.
 */
function buttonEnabledAnswers(answers)
{
	const queue = [...answers];
	playwrightExpect.mockImplementation(() => ({toBeEnabled: () => (queue.shift() ? Promise.resolve() : Promise.reject(new Error('still disabled')))}));
}

describe('the first password change', () =>
{
	afterEach(() => playwrightExpect.mockReset());

	it('types the password twice and an answer once when the button enables at the first try', async() =>
	{
		const {page, typed} = recordingPage();
		buttonEnabledAnswers([true]);

		await typeNewPassword(page, {}, PASSWORD, CHANGE_PASSWORD_ATTEMPTS);

		expect(typed).toHaveLength(3);
		expect(typed[0]).toBe(`input#newpassword=${PASSWORD}`);
		expect(typed[1]).toBe(`input#confirmpassword=${PASSWORD}`);
		expect(typed[2]).toMatch(/^input#answer=/);
		expect(playwrightExpect).toHaveBeenCalledTimes(1);
	});

	it('types the fields again while the button stays disabled, and stops after the last attempt', async() =>
	{
		const {page, typed} = recordingPage();
		buttonEnabledAnswers([false, false, false, false]);

		await typeNewPassword(page, {}, PASSWORD, CHANGE_PASSWORD_ATTEMPTS);

		expect(playwrightExpect).toHaveBeenCalledTimes(CHANGE_PASSWORD_ATTEMPTS);
		expect(typed).toHaveLength(3 * CHANGE_PASSWORD_ATTEMPTS);
	});
});

describe('the cleanup step runner', () =>
{
	it('runs a step and reports a failing one under the part name without throwing', async() =>
	{
		const warning = jest.spyOn(console, 'warn').mockImplementation(() => {});
		const runCleanupStep = cleanupStepRunner('part2');
		const step = jest.fn(async() => {});

		await runCleanupStep(step);
		await expect(runCleanupStep(() =>
		{
			throw new Error('delete refused');
		})).resolves.toBeUndefined();

		expect(step).toHaveBeenCalledTimes(1);
		expect(warning).toHaveBeenCalledWith('[part2] cleanup step failed: delete refused');
		warning.mockRestore();
	});
});
