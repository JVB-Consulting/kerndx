// SPDX-License-Identifier: BUSL-1.1
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {chromium} = require('@playwright/test');
const {installOverlay, moveCursorTo, pulseAt} = require('./capture-overlay');

test('installOverlay injects a synthetic cursor and can move + pulse it', async () =>
{
	const browser = await chromium.launch();
	try
	{
		const page = await browser.newPage();
		await page.setContent('<button id="b" style="position:absolute;left:200px;top:160px;width:120px;height:40px">Go</button>');
		await installOverlay(page);
		const hasCursor = await page.evaluate(() => !!document.getElementById('kern-cap-cursor'));
		assert.ok(hasCursor, 'cursor element injected');
		await moveCursorTo(page, '#b');
		const moved = await page.evaluate(() =>
		{
			const c = document.getElementById('kern-cap-cursor');
			return parseInt(c.style.left, 10) > 0;
		});
		assert.ok(moved, 'cursor moved toward the target');
		await pulseAt(page, '#b');
		// pulse element is transient; just assert no throw and the API resolved.
		assert.ok(true);
	}
	finally
	{
		await browser.close();
	}
});
