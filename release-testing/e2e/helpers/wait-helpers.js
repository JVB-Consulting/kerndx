// SPDX-License-Identifier: BUSL-1.1
const {SPINNER, TOAST, TOAST_MESSAGE} = require('./sf-selectors');

async function waitForSpinnerGone(page, timeout = 15_000)
{
	try
	{
		await page.locator(SPINNER).first().waitFor({state: 'visible', timeout: 2000});
		await page.locator(SPINNER).first().waitFor({state: 'hidden', timeout});
	}
	catch
	{
		// Spinner may not appear at all
	}
}

async function waitForToast(page, timeout = 15_000)
{
	await page.locator(TOAST).first().waitFor({state: 'visible', timeout});
}

async function waitForToastMessage(page, expectedText, timeout = 15_000)
{
	const toast = page.locator(TOAST_MESSAGE).first();
	await toast.waitFor({state: 'visible', timeout});
	if(expectedText)
	{
		await page.waitForFunction((text) =>
		{
			const el = document.querySelector('div.toastContainer span.toastMessage, div.toastContainer .slds-notify__content');
			return el && el.textContent.includes(text);
		}, expectedText, {timeout});
	}
}

async function dismissToast(page)
{
	const closeBtn = page.locator('div.toastContainer lightning-button-icon.toastClose button');
	if(await closeBtn.isVisible().catch(() => false))
	{
		await closeBtn.click();
	}
}

async function waitForRecordPage(page, timeout = 30_000)
{
	await page.locator(
			'records-lwc-highlights-panel, records-highlights2, records-lwc-record-layout, flexipage-record-home-template-desktop2, force-record-layout-section, lightning-tabset')
	.first()
	.waitFor({state: 'visible', timeout});
}

async function waitForListView(page, timeout = 30_000)
{
	await page.locator('lightning-list-view-table, lst-list-view-manager-header, force-list-view-manager-presented')
	.first()
	.waitFor({state: 'attached', timeout});
	await waitForSpinnerGone(page);
}

async function waitForModal(page, timeout = 15_000)
{
	await page.locator('section.slds-modal, div.slds-modal, lightning-modal')
	.first()
	.waitFor({state: 'visible', timeout});
}

async function pollUntil(page, conditionFn, {interval = 5000, timeout = 120_000, message = 'Condition not met'} = {})
{
	const start = Date.now();
	while(Date.now() - start < timeout)
	{
		const result = await conditionFn();
		if(result)
		{
			return result;
		}
		await page.waitForTimeout(interval);
	}
	throw new Error(`pollUntil timed out: ${message}`);
}

module.exports = {
	waitForSpinnerGone, waitForToast, waitForToastMessage, dismissToast, waitForRecordPage, waitForListView, waitForModal, pollUntil
};
