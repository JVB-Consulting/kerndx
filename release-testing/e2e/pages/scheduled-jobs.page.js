// SPDX-License-Identifier: BUSL-1.1
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForListView, waitForRecordPage, waitForSpinnerGone, waitForToastMessage, dismissToast} = require('../helpers/wait-helpers');

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

	async fillJobForm({name, className, cron, isActive = true, parameters = {}})
	{
		const editor = this.page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: 15_000});

		if(name)
		{
			await editor.locator('[data-testid="scheduler-name"] input').fill(name);
		}
		if(className)
		{
			await this.selectSchedulableClass(editor, className);
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
		await description.waitFor({state: 'visible', timeout: 15_000});
		return description.textContent();
	}

	async getScheduleHeading()
	{
		const detail = await this.getDetailComponent();
		const heading = detail.locator('[data-testid="schedule-heading"]');
		await heading.waitFor({state: 'visible', timeout: 15_000}).catch(() =>
		{
		});
		return heading.textContent().catch(() => '');
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
		await modal.waitFor({state: 'hidden', timeout: 15_000}).catch(() =>
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
		await combobox.waitFor({state: 'visible', timeout: 15_000});

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
