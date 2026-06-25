// SPDX-License-Identifier: BUSL-1.1
// Capture-time motion polish: a synthetic cursor, click ripple, and zoom-to-region overlay
// injected into the page so silent hero-loop recordings read clearly. Headless Playwright
// draws no real cursor, so we render one. Injected via addInitScript so it survives Lightning
// client-side navigations, and re-injected into the current document on install.

const OVERLAY_SCRIPT = `(() => {
	if (window.__kernCaptureOverlay) { return; }
	window.__kernCaptureOverlay = true;
	const style = document.createElement('style');
	style.textContent = '#kern-cap-cursor{position:fixed;z-index:2147483647;width:22px;height:22px;margin:-11px 0 0 -11px;border-radius:50%;border:2px solid rgba(20,20,20,.85);background:rgba(255,255,255,.35);box-shadow:0 0 0 2px rgba(255,255,255,.6);pointer-events:none;left:-100px;top:-100px;transition:left .45s cubic-bezier(.25,.1,.25,1),top .45s cubic-bezier(.25,.1,.25,1);}'
		+ '.kern-cap-pulse{position:fixed;z-index:2147483646;width:14px;height:14px;margin:-7px 0 0 -7px;border-radius:50%;background:rgba(0,112,210,.45);pointer-events:none;animation:kern-cap-pulse .6s ease-out forwards;}'
		+ '@keyframes kern-cap-pulse{from{transform:scale(.4);opacity:.9}to{transform:scale(3.2);opacity:0}}'
		+ '.kern-cap-zoom{transition:transform .5s ease;}' ;
	document.documentElement.appendChild(style);
	const cur = document.createElement('div');
	cur.id = 'kern-cap-cursor';
	document.documentElement.appendChild(cur);
	window.__kernCaptureMove = (x, y) => { cur.style.left = x + 'px'; cur.style.top = y + 'px'; };
	window.__kernCapturePulse = (x, y) => {
		const p = document.createElement('div');
		p.className = 'kern-cap-pulse';
		p.style.left = x + 'px'; p.style.top = y + 'px';
		document.documentElement.appendChild(p);
		setTimeout(() => { p.remove(); }, 700);
	};
})();`;

async function installOverlay(page)
{
	await page.addInitScript(OVERLAY_SCRIPT);
	await page.evaluate(OVERLAY_SCRIPT).catch(() => {});
}

// A brief, deliberate pause so the viewer can absorb a state change before the next beat.
async function settle(page, ms = 400)
{
	await page.waitForTimeout(ms);
}

// Wait until an element's box stops moving (two identical samples) BEFORE we draw the cursor
// at it — this is the cursor/UI-transition sync guard. Lightning modals, dropdowns and toasts
// animate into place; sampling once would land the synthetic cursor on a stale position.
async function waitForStable(page, selector, {interval = 120, timeout = 5000} = {})
{
	const loc = page.locator(selector).first();
	let prev = null;
	const deadline = Date.now() + timeout;
	while(Date.now() < deadline)
	{
		const box = await loc.boundingBox().catch(() => null);
		if(box && prev && Math.abs(box.x - prev.x) < 1 && Math.abs(box.y - prev.y) < 1)
		{
			return box;
		}
		prev = box;
		await page.waitForTimeout(interval);
	}
	return prev;
}

function center(box)
{
	return box ? {x: box.x + (box.width / 2), y: box.y + (box.height / 2)} : null;
}

async function moveCursorTo(page, selector)
{
	// Settle the target, measure it once stable, move the real mouse + the synthetic cursor,
	// then wait out the cursor's 0.45s CSS transition so it has visibly arrived before any click.
	const c = center(await waitForStable(page, selector));
	if(!c)
	{
		return;
	}
	await page.mouse.move(c.x, c.y);
	await page.evaluate(([x, y]) => window.__kernCaptureMove && window.__kernCaptureMove(x, y), [c.x, c.y]);
	await page.waitForTimeout(550);
}

async function pulseAt(page, selector)
{
	// Re-measure right before the ripple in case the element nudged during the cursor move.
	const c = center(await page.locator(selector).first().boundingBox().catch(() => null));
	if(!c)
	{
		return;
	}
	await page.evaluate(([x, y]) => window.__kernCapturePulse && window.__kernCapturePulse(x, y), [c.x, c.y]);
	await page.waitForTimeout(320);
}

async function clickWithPolish(page, selector)
{
	await moveCursorTo(page, selector);
	await pulseAt(page, selector);
	await page.locator(selector).first().click();
	await settle(page); // let the UI react before the choreography moves on
}

// Zoom is OPTIONAL and off by default in the choreographies (a review flagged zoom as reading
// "tutorial-ish" rather than premium). Kept here for opt-in use; the default loops rely on the
// cursor + pulse + the UI's own motion (progress bars, badge flips, events landing).
async function zoomTo(page, selector, scale = 1.08)
{
	await page.evaluate(([sel, s]) =>
	{
		const el = document.querySelector(sel);
		if(el)
		{
			el.classList.add('kern-cap-zoom');
			el.style.transformOrigin = 'center';
			el.style.transform = 'scale(' + s + ')';
		}
	}, [selector, scale]);
	await page.waitForTimeout(550);
}

async function resetZoom(page, selector)
{
	await page.evaluate((sel) =>
	{
		const el = document.querySelector(sel);
		if(el)
		{
			el.style.transform = '';
		}
	}, selector);
	await page.waitForTimeout(450);
}

module.exports = {installOverlay, settle, waitForStable, moveCursorTo, pulseAt, clickWithPolish, zoomTo, resetZoom};
