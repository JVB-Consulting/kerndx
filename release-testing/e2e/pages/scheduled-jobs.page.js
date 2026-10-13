// SPDX-License-Identifier: BUSL-1.1
const {expect} = require('@playwright/test');
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForListView, waitForRecordPage, waitForSpinnerGone} = require('../helpers/wait-helpers');
const {ELEMENT_WAIT_MILLISECONDS} = require('../helpers/wait-times');

class ScheduledJobsPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await clickNavTab(this.page, 'Scheduled Jobs');
		await waitForListView(this.page);
	}

	async getRecordCount()
	{
		const countText = await this.page.locator('span.countSortedByFilteredBy, span.count').first().textContent().catch(() => '0');
		const match = countText.match(/(\d+)/);
		return match ? parseInt(match[1], 10) : 0;
	}

	async clickNew()
	{
		await this.page.getByRole('button', {name: 'New'}).click();
		await waitForSpinnerGone(this.page);
	}

	async fillJobForm({name, className, typedClassName, cron, isActive = true, parameters = {}, executionMode})
	{
		const editor = this.page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});

		if(name)
		{
			await editor.locator('[data-testid="scheduler-name"] input').fill(name);
		}
		if(className)
		{
			await this.selectSchedulableClass(editor, className);
		}
		if(typedClassName)
		{
			await this.typeSchedulableClass(editor, typedClassName);
		}
		if(executionMode)
		{
			// The execution-mode radio group renders one input per option; the option value is the picklist API value.
			// The input is visually hidden, so a pointer click lands beside it; a DOM click fires the group's change.
			const radio = editor.locator(`[data-testid="execution-mode"] input[value="${executionMode}"]`);
			await radio.waitFor({state: 'attached', timeout: 10_000});
			// The runner option stays disabled until the editor has read the runner's state, and a DOM click on a disabled
			// radio does nothing, so the job would save on the default mode.
			await expect(radio, `the ${executionMode} option opens to this user`).toBeEnabled({timeout: 30_000});
			await radio.evaluate((element) => element.click());
		}
		if(cron)
		{
			const customRadio = editor.getByText('Custom', {exact: true});
			await customRadio.waitFor({state: 'visible', timeout: 10_000});
			await customRadio.click();
			const cronInput = editor.locator('[data-testid="cron-custom-input"] input, input[name="customExpression"]').first();
			await cronInput.waitFor({state: 'visible', timeout: 10_000});
			await cronInput.fill(cron);
		}
		if(typeof isActive === 'boolean')
		{
			const toggle = editor.locator('[data-testid="is-active"] input[type="checkbox"]');
			const checked = await toggle.isChecked();
			if(checked !== isActive)
			{
				await toggle.click({force: true});
			}
		}
		for(const [param, value] of Object.entries(parameters))
		{
			const paramInput = editor.locator(`[data-testid="param-${param}"] input`);
			await paramInput.fill(String(value));
		}
	}

	async clickSave()
	{
		const saveBtn = this.page.locator('[data-testid="save-button"]').first();
		await saveBtn.evaluate(el => el.click());
		await waitForSpinnerGone(this.page);
	}

	async clickCancel()
	{
		const cancelBtn = this.page.locator('[data-testid="cancel-button"]').first();
		await cancelBtn.evaluate(el => el.click());
	}

	async getDetailComponent()
	{
		return this.page.locator('[data-testid="scheduled-job-detail-root"]');
	}

	async getCronDescription()
	{
		const detail = await this.getDetailComponent();
		const description = detail.locator('[data-testid="cron-description"]');
		await description.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		return description.textContent();
	}

	async getScheduleHeading()
	{
		const detail = await this.getDetailComponent();
		const heading = detail.locator('[data-testid="schedule-heading"]');
		await heading.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS}).catch(() =>
		{
		});
		return heading.textContent().catch(() => '');
	}

	/**
	 * @description Reads the cron editor's plain-English preview inside the editor (not the detail view).
	 */
	async getCronPreviewDescription()
	{
		const editor = this.page.locator('[data-testid="scheduled-job-editor-root"]');
		const preview = editor.locator('[data-testid="cron-description-preview"]').first();
		await preview.waitFor({state: 'visible', timeout: 10_000});
		return (await preview.textContent()).trim();
	}

	/**
	 * Reads the cron editor's inline validation alert. Prefers the cron editor's validation-alert test id and
	 * falls back to the alert role.
	 */
	async getCronValidationMessage()
	{
		const editor = this.page.locator('[data-testid="scheduled-job-editor-root"]');
		const alert = editor.locator('[data-testid="cron-validation-error"], .slds-alert_error[role="alert"]').first();
		await alert.waitFor({state: 'visible', timeout: 10_000});
		return (await alert.textContent()).trim();
	}

	/**
	 * @description Reads one labelled value from the detail card by its test id (detail-execution-mode, detail-next-run,
	 * detail-last-run, detail-last-run-outcome, detail-last-run-reason).
	 */
	async getDetailText(testId)
	{
		const detail = await this.getDetailComponent();
		const element = detail.locator(`[data-testid="${testId}"]`).first();
		await element.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		return (await element.textContent()).trim();
	}

	async clickRunNow()
	{
		const detail = await this.getDetailComponent();
		const button = detail.locator('[data-testid="run-now-button"]').first();
		await button.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		await button.evaluate((el) => el.click());
		await waitForSpinnerGone(this.page);
	}

	/**
	 * @description Switches a FLAG parameter of the open editor on or off.
	 */
	async setParameterToggle(editor, parameterName, checked)
	{
		const toggle = editor.locator(`[data-testid="param-${parameterName}"] input[type="checkbox"]`);
		await toggle.waitFor({state: 'attached', timeout: ELEMENT_WAIT_MILLISECONDS});
		if(await toggle.isChecked() !== checked)
		{
			await toggle.click({force: true});
		}
	}

	/**
	 * @description Opens the log entry of the record's last run through the detail view's View log button.
	 */
	async clickViewLog()
	{
		const detail = await this.getDetailComponent();
		const button = detail.locator('[data-testid="detail-last-run-log"]').first();
		await button.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		await button.click();
		await waitForRecordPage(this.page);
	}

	async openRecordById(recordId)
	{
		await this.page.goto(`${this.page.url().split('/lightning/')[0]}/lightning/r/${recordId}/view`);
		await waitForRecordPage(this.page);
	}

	async hasParameterInputs()
	{
		const editor = this.page.locator('[data-testid="scheduled-job-editor-root"]');
		const params = editor.locator('[data-testid^="param-"]');
		return (await params.count()) > 0;
	}

	async deleteCurrentRecord()
	{
		await this.page.getByRole('button', {name: 'Delete', exact: true}).click();
		const modal = this.page.locator('div.slds-modal');
		await modal.waitFor({state: 'visible', timeout: 10_000});
		await modal.getByRole('button', {name: 'Delete'}).click();
		await modal.waitFor({state: 'hidden', timeout: ELEMENT_WAIT_MILLISECONDS}).catch(() =>
		{
		});
		await waitForSpinnerGone(this.page);
	}

	async openFirstRecord()
	{
		const firstLink = this.page.locator('table tbody tr th a').first();
		await firstLink.click();
		await waitForRecordPage(this.page);
	}

	async clickEdit()
	{
		await this.page.getByRole('button', {name: 'Edit', exact: true}).click();
		await waitForSpinnerGone(this.page);
	}

	/**
	 * @description The open editor's root element.
	 */
	editor()
	{
		return this.page.locator('[data-testid="scheduled-job-editor-root"]');
	}

	/**
	 * @description Types a class name into the editor's class field and leaves the field, which is when the editor takes
	 * the name and checks it.
	 */
	async typeSchedulableClass(editor, className)
	{
		const input = editor.locator('[data-testid="class-name"] input[role="combobox"]');
		await input.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		await input.fill(className);
		await input.press('Tab');
		await waitForSpinnerGone(this.page);
	}

	/**
	 * @description The class names the class field suggests with nothing typed: the cached list.
	 */
	async listedSchedulableClasses(editor)
	{
		const input = editor.locator('[data-testid="class-name"] input[role="combobox"]');
		await input.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		await input.fill('');
		await input.click();
		const options = editor.locator('[data-testid="class-name"] [role="option"]');
		await options.first().waitFor({state: 'visible', timeout: 45_000});
		const names = (await options.allTextContents()).map((name) => name.trim());
		await input.press('Escape');
		return names;
	}

	/**
	 * @description The message under the class field, or an empty string while the name is fine.
	 */
	async getClassNameError(editor)
	{
		const message = editor.locator('[data-testid="class-name"] [data-testid="class-name-error"]');
		return ((await message.textContent()) || '').trim();
	}

	/**
	 * Selects a schedulable class from the className combobox using a robust
	 * retry pattern that tolerates cold-scratch-org timing:
	 * 1. Click the combobox button trigger (not input).
	 * 2. Poll the dropdown until ANY matching option renders (up to 45s).
	 * 3. Retry the open-click once if the dropdown closes prematurely.
	 * 4. Click the option.
	 *
	 * Substring matching ensures we find the target whether the LWC returns
	 * an unqualified name (`SCHED_PurgeRecords`) or a namespace-qualified
	 * one (`kern.SCHED_PurgeRecords`) — the subscriber org returns the latter.
	 */
	async selectSchedulableClass(editor, className)
	{
		const combobox = editor.locator('[data-testid="class-name"]');
		await combobox.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});

		const targetOption = this.page.getByRole('option', {name: new RegExp(`\\b${className}\\b`)}).first();
		const startedAt = Date.now();
		const timeoutMs = 45_000;
		let lastError = null;

		while(Date.now() - startedAt < timeoutMs)
		{
			try
			{
				const trigger = combobox.locator('button[role="combobox"], button, input').first();
				await trigger.click();
				const anyOption = this.page.getByRole('option').first();
				await anyOption.waitFor({state: 'visible', timeout: 5_000});

				const targetVisible = await targetOption.isVisible().catch(() => false);
				if(targetVisible)
				{
					await targetOption.click();
					return;
				}

				const visibleOptions = await this.page.getByRole('option').allTextContents();
				throw new Error(`"${className}" not in options. Saw: ${visibleOptions.slice(0, 10).join(', ')}`);
			}
			catch(error)
			{
				lastError = error;
				await this.page.keyboard.press('Escape').catch(() =>
				{
				});
				await this.page.waitForTimeout(2000);
			}
		}

		throw new Error(`Failed to select schedulable class "${className}" within ${timeoutMs}ms. Last error: ${lastError?.message || 'unknown'}`);
	}
}

module.exports = ScheduledJobsPage;
