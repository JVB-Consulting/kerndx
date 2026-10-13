// SPDX-License-Identifier: BUSL-1.1
// Part 5 of the exploration: the widths, on both consoles.
'use strict';

const {
	STATE_KEY_ACTION, STATE_KEY_STAMP, WIDTHS, VIEWPORT_HEIGHT, COMPACT_MAXIMUM_WIDTH, OVERLAY_MAXIMUM_WIDTH, SIDE_BY_SIDE_MINIMUM_WIDTH,
	TOOLBAR_LINE_ALLOWANCE, SESSION_VIEWPORT, RESIZE_SETTLE_MILLISECONDS, labelValues, ENTRY_COLUMNS_FULL, ENTRY_COLUMNS_COMPACT, PROBLEM_COLUMNS_FULL,
	PROBLEM_COLUMNS_COMPACT, MONITOR_COLUMNS_FULL, MONITOR_COLUMNS_COMPACT, MONITOR_LAUNCHED_UNDER
} = require('./constants');
const {ACTION_CHECKOUT, prefixed} = require('./shaped-seed');
const {consoleEntry, monitorEntry} = require('./model');
const {poll} = require('./checks');
const {settleMonitor, openConsoleTimed} = require('./moves');
const {getInstanceUrl} = require('../helpers/sf-auth');

async function sweepConsoleWidths(context)
{
	console.log('\nW1: the Log Console at every width');
	for(const view of ['entries', 'problems'])
	{
		const fullSet = view === 'entries' ? ENTRY_COLUMNS_FULL : PROBLEM_COLUMNS_FULL;
		const compactSet = view === 'entries' ? ENTRY_COLUMNS_COMPACT : PROBLEM_COLUMNS_COMPACT;
		for(const drawerOpen of [false, true])
		{
			await context.page.setViewportSize(SESSION_VIEWPORT);
			await openConsoleTimed(context);
			await context.logConsole.switchView(view);
			if(drawerOpen)
			{
				if(await context.logConsole.getRowCount() === 0)
				{
					console.log(`  W1 ${view} with the drawer open: the list had no row to open, so the compact sets were not read`);
					await context.ledger.report(context, {
						session: 'W1', step: 0, move: `${view} view, drawer open`, check: 'console-columns-unread',
						expected: 'a row to open the drawer on', observed: 'the list was empty, so no width was read with the drawer open',
						pins: consoleEntry()
					});
					continue;
				}
				await context.logConsole.selectRow(0);
			}
			for(const width of WIDTHS)
			{
				await context.page.setViewportSize({width, height: VIEWPORT_HEIGHT});
				await context.page.waitForTimeout(RESIZE_SETTLE_MILLISECONDS);
				const compactExpected = drawerOpen && width <= COMPACT_MAXIMUM_WIDTH;
				const expected = compactExpected ? compactSet : fullSet;
				const columns = await poll(() => context.logConsole.getColumnLabels(), (labels) => labels.join('|') === expected.join('|'));
				console.log(`  W1 ${view} drawer=${drawerOpen ? 'open' : 'shut'} ${String(width).padStart(4)}px -> [${columns.value.join(', ')}]`);
				if(!columns.ok)
				{
					await context.ledger.report(context, {
						session: 'W1', step: width, move: `${view} view, drawer ${drawerOpen ? 'open' : 'shut'}`, check: 'console-columns',
						expected: `[${expected.join(', ')}]`, observed: `[${columns.value.join(', ')}]`, pins: consoleEntry()
					});
				}
				if(drawerOpen)
				{
					const backExpected = width <= OVERLAY_MAXIMUM_WIDTH;
					const back = await poll(() => context.logConsole.backToListButton().isVisible().catch(() => false), (visible) => visible === backExpected);
					if(!back.ok)
					{
						await context.ledger.report(context, {
							session: 'W1', step: width, move: `${view} view, drawer open`, check: 'back-to-the-list',
							expected: backExpected ? `"${labelValues.LogConsole_BackToList}" is offered` : 'no way-back button', observed: `visible=${back.value}`,
							pins: consoleEntry()
						});
					}
				}
			}
		}
	}
}

async function sweepMonitorWidths(context)
{
	console.log('\nW2: the Chain Monitor at every width');
	const scopes = [
		{name: 'unscoped', url: () => `${getInstanceUrl()}/lightning/n/${prefixed('ChainMonitor')}`, scoped: false},
		{
			name: 'scoped to the checkout action',
			url: () => `${getInstanceUrl()}/lightning/n/${prefixed('ChainMonitor')}?${STATE_KEY_ACTION}=${ACTION_CHECKOUT}&${STATE_KEY_STAMP}=${Date.now()}`,
			scoped: true
		}
	];
	for(const scope of scopes)
	{
		await context.page.setViewportSize(SESSION_VIEWPORT);
		await context.page.goto(scope.url(), {waitUntil: 'domcontentloaded'});
		await settleMonitor(context);
		const rows = await context.monitor.getRowCount();
		if(rows > 0)
		{
			await context.monitor.selectRow(0);
		}
		for(const width of WIDTHS)
		{
			await context.page.setViewportSize({width, height: VIEWPORT_HEIGHT});
			await context.page.waitForTimeout(RESIZE_SETTLE_MILLISECONDS);
			const base = width <= COMPACT_MAXIMUM_WIDTH ? MONITOR_COLUMNS_COMPACT : MONITOR_COLUMNS_FULL;
			const expected = scope.scoped ? [...base, MONITOR_LAUNCHED_UNDER] : base;
			const columns = await poll(() => context.monitor.getColumnLabels(), (labels) => labels.join('|') === expected.join('|'));
			console.log(`  W2 ${scope.name} ${String(width).padStart(4)}px -> [${columns.value.join(', ')}]`);
			if(!columns.ok)
			{
				await context.ledger.report(context, {
					session: 'W2', step: width, move: `monitor list, ${scope.name}`, check: 'monitor-columns',
					expected: `[${expected.join(', ')}]`, observed: `[${columns.value.join(', ')}]`, pins: monitorEntry(scope.scoped ? ACTION_CHECKOUT : null)
				});
			}
			// The two halves of the split row: side by side from the tablet width up, stacked below it. A
			// check that cannot measure its halves says so out loud, because a silent skip reads exactly
			// like a check that passed.
			const boxes = await context.monitor.getSplitPanelBoxes();
			if(boxes.length !== 2 || !boxes[0] || !boxes[1])
			{
				console.log(`  W2 ${scope.name} ${String(width).padStart(4)}px -> the split row gave ${boxes.length} measurable half/halves, so the stacking was not read`);
				await context.ledger.report(context, {
					session: 'W2', step: width, move: `monitor panels, ${scope.name}`, check: 'monitor-stacking-unread',
					expected: 'two measurable halves of the split row', observed: `${boxes.filter((box) => box).length} of ${boxes.length} halves had a box`,
					pins: monitorEntry(scope.scoped ? ACTION_CHECKOUT : null)
				});
			}
			else
			{
				const sideBySide = boxes[1].x > boxes[0].x + 1;
				const stacked = boxes[1].y >= (boxes[0].y + boxes[0].height) - 2;
				const shouldBeSideBySide = width >= SIDE_BY_SIDE_MINIMUM_WIDTH;
				if(shouldBeSideBySide ? !sideBySide : !stacked)
				{
					await context.ledger.report(context, {
						session: 'W2', step: width, move: `monitor panels, ${scope.name}`, check: 'monitor-stacking',
						expected: shouldBeSideBySide ? 'the list and the detail side by side' : 'the detail below the list',
						observed: `list ${JSON.stringify(boxes[0])} detail ${JSON.stringify(boxes[1])}`, pins: monitorEntry(scope.scoped ? ACTION_CHECKOUT : null)
					});
				}
			}
			// Every toolbar button's words on one line: a box taller than two line heights has wrapped.
			// The toolbar lives in the detail pane, so it needs a selected row; without one, or with no
			// button to measure, the check reports that it could not run rather than passing quietly.
			const toolbarButtons = rows > 0 ? await context.monitor.getToolbarButtons().count() : 0;
			if(toolbarButtons === 0)
			{
				console.log(`  W2 ${scope.name} ${String(width).padStart(4)}px -> no toolbar button to measure (${rows} row(s) listed), so the wrapping was not read`);
				await context.ledger.report(context, {
					session: 'W2', step: width, move: `monitor toolbar, ${scope.name}`, check: 'monitor-toolbar-unread',
					expected: 'a selected run whose toolbar buttons can be measured', observed: `${rows} row(s) listed, ${toolbarButtons} toolbar button(s)`,
					pins: monitorEntry(scope.scoped ? ACTION_CHECKOUT : null)
				});
			}
			else
			{
				const wrapped = await context.monitor.getToolbarButtons().evaluateAll((buttons, allowance) => buttons.filter((button) =>
				{
					const styles = window.getComputedStyle(button);
					const lineHeight = Number.parseFloat(styles.lineHeight) || Number.parseFloat(styles.fontSize) * 1.4 || 20;
					return button.getBoundingClientRect().height > lineHeight * allowance;
				}).map((button) => `${(button.innerText || '').trim().replace(/\s+/g, ' ')} (${Math.round(button.getBoundingClientRect().height)}px)`),
				TOOLBAR_LINE_ALLOWANCE);
				if(wrapped.length > 0)
				{
					await context.ledger.report(context, {
						session: 'W2', step: width, move: `monitor toolbar, ${scope.name}`, check: 'monitor-toolbar-one-line',
						expected: 'every toolbar button\'s words on one line', observed: wrapped.join('; '), pins: monitorEntry(scope.scoped ? ACTION_CHECKOUT : null)
					});
				}
			}
		}
	}
}

module.exports = {sweepConsoleWidths, sweepMonitorWidths};
