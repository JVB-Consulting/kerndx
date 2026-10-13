// SPDX-License-Identifier: BUSL-1.1
// Part 4 of the exploration: the sequences. The moves, the random sessions, the hostile orders and the
// three probes.
'use strict';

const {
	STATE_KEY_ACTION, STATE_KEY_CHAIN, STATE_KEY_STAMP, DEFAULT_LEVELS, DEFAULT_PRESET_MINUTES, RANGE_PRESETS, RANDOM_MULTIPLIER, RANDOM_MODULUS,
	RANDOM_WARM_UP_TURNS, MESSAGE_EXCERPT_LENGTH, SESSION_VIEWPORT, SHORT_POLL_MILLISECONDS, MOVE_NAME_COLUMN, PINS_COLUMN, NAVIGATION_SETTLE_MILLISECONDS,
	MONITOR_LAUNCHED_UNDER
} = require('./constants');
const {ACTION_CHECKOUT, CHAIN_NOTIFY, ACTION_NIGHTLY, ACTION_LEGACY, UNKNOWN_ID, NOTIFY_CHAIN_NAME, prefixed} = require('./shaped-seed');
const {consoleEntry, monitorEntry, samePins, HistoryTape, freshSession, openedActionSession, pinnedRunSession, followHistoryStep, shortId, describePins}
		= require('./model');
const {addressKeys, formatKeys, runChecks} = require('./checks');
const {getInstanceUrl, ensureAuthenticated} = require('../helpers/sf-auth');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {waitForPageLoad} = require('../helpers/sf-navigation');

// A small seeded generator (the Lehmer one), so a run replays its moves exactly from the printed
// seed. The numbers only have to be varied and repeatable, never unguessable.
function createRandom(seed)
{
	let state = (seed % RANDOM_MODULUS) || 1;
	const next = () =>
	{
		state = (state * RANDOM_MULTIPLIER) % RANDOM_MODULUS;
		return state / RANDOM_MODULUS;
	};
	// A few turns before the first move, so a small seed does not start the walk on a thin part of the
	// sequence.
	for(let turn = 0; turn < RANDOM_WARM_UP_TURNS; turn++)
	{
		next();
	}
	return next;
}

async function settleConsole(logConsole)
{
	await logConsole.root().waitFor({state: 'visible', timeout: 60_000}).catch(() =>
	{
	});
	await logConsole.waitForListSettled();
}

async function settleMonitor(context)
{
	await context.monitor.getListPanel().waitFor({state: 'visible', timeout: 60_000}).catch(() =>
	{
	});
	await context.page.waitForTimeout(NAVIGATION_SETTLE_MILLISECONDS);
	await waitForSpinnerGone(context.page);
}

async function settleFor(context, entry)
{
	if(entry.kind === 'console')
	{
		await settleConsole(context.logConsole);
		return;
	}
	await settleMonitor(context);
}

/**
 * @description Opens the Log Console from its tab under the open timer: the sign-in (a fresh page's frontdoor
 *              login) happens before the timer starts, the timer stops when the list has rendered, and the usual
 *              settle follows untimed so the walk behaves as it did.
 * @param {Object} context The run context.
 */
async function openConsoleTimed(context)
{
	await ensureAuthenticated(context.page);
	const timer = context.timing.openTimer();
	await context.logConsole.navigateUntilRendered();
	timer.stop('console');
	await context.logConsole.waitForListSettled();
}

/**
 * @description Opens the Chain Monitor from its tab under the open timer, the same way.
 * @param {Object} context The run context.
 */
async function openMonitorTimed(context)
{
	await ensureAuthenticated(context.page);
	const timer = context.timing.openTimer();
	await context.monitor.navigateUntilRendered();
	timer.stop('monitor');
	await settleMonitor(context);
}

// Every move the walk can make. `available` keeps a move from being chosen where it makes no sense
// (a chip with no banner on screen, a Back with nothing behind); `run` performs it on the screen and
// records what it did to the history tape and the session state.
const MOVES = [
	{
		name: 'pinCheckoutAction',
		available: (context) => context.tape.current().kind === 'console',
		run: (context) => pinActionById(context, ACTION_CHECKOUT)
	},
	{
		name: 'pinNightlyAction',
		available: (context) => context.tape.current().kind === 'console',
		run: (context) => pinActionById(context, ACTION_NIGHTLY)
	},
	{
		name: 'pinLegacyAction',
		available: (context) => context.tape.current().kind === 'console',
		run: (context) => pinActionById(context, ACTION_LEGACY)
	},
	{
		name: 'clickChip',
		available: (context) => context.tape.current().kind === 'console' && Boolean(context.tape.current().action),
		run: (context) => clickChip(context)
	},
	{
		name: 'pasteFailedChain',
		available: (context) => context.tape.current().kind === 'console',
		run: (context) => pasteChain(context, CHAIN_NOTIFY)
	},
	{
		name: 'pasteUnknownId',
		available: (context) => context.tape.current().kind === 'console',
		run: (context) => pasteUnknownId(context)
	},
	{
		name: 'handoffViaOpenTheChains',
		available: (context) => context.tape.current().kind === 'console' && [ACTION_CHECKOUT, ACTION_NIGHTLY].includes(context.tape.current().action),
		run: (context) => handoffViaOpenTheChains(context)
	},
	{
		name: 'handoffViaViewLogs',
		available: () => true,
		run: (context) => handoffViaViewLogs(context)
	},
	{
		name: 'back',
		available: (context) => context.tape.canGoBack(),
		run: (context) => historyStep(context, 'back')
	},
	{
		name: 'forward',
		available: (context) => context.tape.canGoForward(),
		run: (context) => historyStep(context, 'forward')
	},
	{
		name: 'reload',
		available: () => true,
		run: (context) => reloadPage(context)
	},
	{
		name: 'removeChainPill',
		available: (context) => context.tape.current().kind === 'console' && Boolean(context.tape.current().chain),
		run: (context) => removeChainPill(context)
	},
	{
		name: 'removeActionPill',
		available: (context) => context.tape.current().kind === 'console' && Boolean(context.tape.current().action),
		run: (context) => removeActionPill(context)
	},
	{
		name: 'clearAll',
		available: (context) => context.tape.current().kind === 'console',
		run: (context) => clearAll(context)
	},
	{
		name: 'switchView',
		available: (context) => context.tape.current().kind === 'console',
		run: (context) => switchView(context)
	},
	{
		name: 'changeRangePreset',
		available: (context) => context.tape.current().kind === 'console',
		run: (context) => changeRangePreset(context)
	},
	{
		name: 'openConsoleFresh',
		available: (context) => context.tape.current().kind === 'monitor',
		run: (context) => openConsoleFresh(context)
	}
];

async function pinActionById(context, action)
{
	await context.logConsole.search(action);
	const entry = consoleEntry(action);
	if(!samePins(context.tape.current(), entry))
	{
		context.tape.push(entry);
	}
	openedActionSession(context.session, action);
	return `pinned ${shortId(action)} from the search box`;
}

async function clickChip(context)
{
	const chips = context.logConsole.actionChips();
	const count = await chips.count();
	if(count === 0)
	{
		return 'no chips on screen (nothing done)';
	}
	const index = Math.floor(context.random() * count);
	const chain = await chips.nth(index).getAttribute('data-correlation-id');
	await chips.nth(index).click();
	await context.logConsole.waitForListSettled();
	const entry = consoleEntry(context.tape.current().action, chain);
	if(!samePins(context.tape.current(), entry))
	{
		context.tape.push(entry);
	}
	// Narrowing a pinned action leaves the view, the levels and the range exactly as they were.
	return `narrowed to chip ${index + 1} of ${count} (${shortId(chain)})`;
}

async function pasteChain(context, chain)
{
	await context.logConsole.search(chain);
	const entry = consoleEntry(null, chain);
	if(!samePins(context.tape.current(), entry))
	{
		context.tape.push(entry);
	}
	// A pasted chain id pins the run alone, the way a chain key alone in the address does: any pinned
	// action goes and the run's opening state is set, which is the state a refresh on the pushed address
	// would reproduce. No window, because a pasted id carries none.
	pinnedRunSession(context.session, null, null);
	return `pasted the chain id ${shortId(chain)}`;
}

async function pasteUnknownId(context)
{
	await context.logConsole.search(UNKNOWN_ID);
	context.session.searchTerm = UNKNOWN_ID;
	return 'pasted an id no row carries';
}

async function handoffViaOpenTheChains(context)
{
	const action = context.tape.current().action;
	await context.logConsole.openChainsButton().click();
	await waitForPageLoad(context.page);
	context.tape.push(monitorEntry(action));
	await settleMonitor(context);
	const button = context.monitor.getShowActionLogsButton();
	const reachable = await button.waitFor({state: 'visible', timeout: 30_000}).then(() => true, () => false);
	if(!reachable)
	{
		context.session.trusted = false;
		return 'the monitor never offered Show the action\'s logs (nothing done)';
	}
	await button.click();
	await waitForPageLoad(context.page);
	context.tape.push(consoleEntry(action));
	await settleConsole(context.logConsole);
	openedActionSession(context.session, action);
	return `handed off to the monitor and back on ${shortId(action)}`;
}

async function handoffViaViewLogs(context)
{
	// Whether going to the monitor's URL adds a history entry or rewrites the one the browser is on
	// (which is what a navigation to the very same URL does) is measured rather than assumed: the
	// browser's own history length says which happened, and the tape follows it. Chrome caps that
	// length at 50, so past the cap the measurement reads as a rewrite; a session never gets there.
	const lengthBefore = await context.page.evaluate(() => window.history.length).catch(() => null);
	await openMonitorTimed(context);
	const lengthAfter = await context.page.evaluate(() => window.history.length).catch(() => null);
	const pushed = lengthBefore === null || lengthAfter === null || lengthAfter > lengthBefore;
	if(pushed)
	{
		context.tape.push(monitorEntry());
	}
	else
	{
		context.tape.replace(monitorEntry());
	}
	await context.monitor.setNameSearch(NOTIFY_CHAIN_NAME);
	const rowCount = await context.monitor.getRowCount();
	if(rowCount === 0)
	{
		context.session.trusted = false;
		return `the monitor listed no ${NOTIFY_CHAIN_NAME} row (nothing done)`;
	}
	await context.monitor.selectRow(0);
	await context.monitor.getViewLogsButton().click();
	await waitForPageLoad(context.page);
	await settleConsole(context.logConsole);
	// The pin the link owes, taken from the run's own recorded bounds rather than from the address the
	// checks are about to read: an address that arrives without its window, or with the wrong one, has
	// to disagree with the model instead of defining it.
	const owed = context.oracle.notifyRunWindow;
	context.tape.push(consoleEntry(null, CHAIN_NOTIFY, owed ? owed.start : null));
	pinnedRunSession(context.session, owed ? owed.start : null, owed ? owed.end : null);
	return `followed View logs on ${NOTIFY_CHAIN_NAME} (the run's window ${owed ? 'is known from its row' : 'is unknown: the run row has no start'})`;
}

async function historyStep(context, direction)
{
	const from = context.tape.current();
	const to = direction === 'back' ? context.tape.goBack() : context.tape.goForward();
	if(direction === 'back')
	{
		await context.page.goBack();
	}
	else
	{
		await context.page.goForward();
	}
	await settleFor(context, to);
	followHistoryStep(context.session, from, to, false);
	return `${direction} to ${describePins(to)}`;
}

async function reloadPage(context)
{
	const entry = context.tape.current();
	await context.page.reload();
	await settleFor(context, entry);
	followHistoryStep(context.session, entry, entry, true);
	return `reloaded on ${describePins(entry)}`;
}

async function removeChainPill(context)
{
	await context.logConsole.removeCorrelation();
	const entry = context.tape.current();
	context.tape.replace(consoleEntry(entry.action, null, null));
	// Removing the chain pill touches neither the range nor the levels.
	return 'closed the chain pill';
}

async function removeActionPill(context)
{
	await context.logConsole.removeAction();
	context.tape.replace(consoleEntry());
	context.session.levels = [...DEFAULT_LEVELS];
	return 'closed the action pill';
}

async function clearAll(context)
{
	await context.logConsole.clearAll();
	context.tape.replace(consoleEntry());
	context.session.levels = [...DEFAULT_LEVELS];
	context.session.range = {kind: 'preset', minutes: DEFAULT_PRESET_MINUTES};
	context.session.searchTerm = '';
	return 'cleared everything';
}

async function switchView(context)
{
	const next = context.session.view === 'entries' ? 'problems' : 'entries';
	await context.logConsole.switchView(next);
	context.session.view = next;
	return `switched to the ${next} view`;
}

async function changeRangePreset(context)
{
	const preset = RANGE_PRESETS[Math.floor(context.random() * RANGE_PRESETS.length)];
	await context.logConsole.selectDateRange(preset.label);
	context.session.range = {kind: 'preset', minutes: preset.minutes};
	return `changed the range to ${preset.label}`;
}

async function openConsoleFresh(context)
{
	await openConsoleTimed(context);
	context.tape.push(consoleEntry());
	const fresh = freshSession();
	context.session.view = fresh.view;
	context.session.levels = fresh.levels;
	context.session.range = fresh.range;
	context.session.searchTerm = '';
	context.session.trusted = true;
	return 'opened the console fresh from its tab';
}

/**
 * @description Runs one move by name and checks the screen against the model afterwards. A move that
 *              throws is itself a finding: the walk carries on from wherever the screen ended up.
 * @param {Object} context The run context.
 * @param {string} sessionName The session's name, for the findings table.
 * @param {number} step The step number inside the session.
 * @param {Object} move The move to run.
 * @returns {Promise<void>}
 */
async function runStep(context, sessionName, step, move)
{
	let detail = '';
	try
	{
		detail = await move.run(context);
	}
	catch(failure)
	{
		await context.ledger.report(context, {
			session: sessionName, step, move: move.name, check: 'move-failed', expected: 'the move completes',
			observed: String(failure.message || failure).replace(/\s+/g, ' ').slice(0, MESSAGE_EXCERPT_LENGTH), pins: context.tape.current()
		});
		context.session.trusted = false;
		await settleFor(context, context.tape.current()).catch(() =>
		{
		});
	}
	const pins = context.tape.current();
	// A read that throws (a context destroyed by a navigation still settling, a locator detached under
	// it) is a finding of its own, never the end of the walk: everything after this step — the rest of
	// the session, the hostile orders, the probes, the widths — is worth more than one unreadable screen.
	let findings = [];
	try
	{
		findings = await runChecks(context, pins, context.session);
	}
	catch(failure)
	{
		findings = [{
			check: 'check-failed', expected: 'the checks can read the screen',
			observed: String(failure.message || failure).replace(/\s+/g, ' ').slice(0, MESSAGE_EXCERPT_LENGTH)
		}];
		context.session.trusted = false;
	}
	const status = findings.length === 0 ? 'ok' : `${findings.length} finding(s)`;
	console.log(`  ${sessionName}/${String(step).padStart(2, '0')} ${move.name.padEnd(MOVE_NAME_COLUMN)} ${describePins(pins).padEnd(PINS_COLUMN)} ${status}`
			+ `${detail ? ` — ${detail}` : ''}`);
	for(const finding of findings)
	{
		await context.ledger.report(context, {session: sessionName, step, move: move.name, pins, ...finding});
	}
}

async function runRandomSession(context, sessionName, steps)
{
	await openConsoleTimed(context);
	context.tape = new HistoryTape(consoleEntry());
	context.session = freshSession();
	console.log(`\n${sessionName}: ${steps} random steps at ${SESSION_VIEWPORT.width}px`);
	for(let step = 1; step <= steps; step++)
	{
		const available = MOVES.filter((move) => move.available(context));
		const move = available[Math.floor(context.random() * available.length)];
		await runStep(context, sessionName, step, move);
	}
}

// The hostile orders the design names, each written out rather than drawn at random.
async function runHostileSequences(context)
{
	console.log('\nH: the hostile orders');
	const byName = (name) => MOVES.find((move) => move.name === name);

	// A hand-off, then an in-place pin, then Back twice: the pin's entry, then the run's, then the monitor's.
	await openConsoleTimed(context);
	context.tape = new HistoryTape(consoleEntry());
	context.session = freshSession();
	const handoffThenPin = ['handoffViaViewLogs', 'pinCheckoutAction', 'back', 'back'];
	for(let index = 0; index < handoffThenPin.length; index++)
	{
		await runStep(context, 'H1', index + 1, byName(handoffThenPin[index]));
	}

	// A reload between every pair of moves of a ten-move random walk.
	await openConsoleTimed(context);
	context.tape = new HistoryTape(consoleEntry());
	context.session = freshSession();
	let step = 0;
	for(let pair = 0; pair < 10; pair++)
	{
		const available = MOVES.filter((move) => move.available(context) && move.name !== 'reload');
		const move = available[Math.floor(context.random() * available.length)];
		step++;
		await runStep(context, 'H2', step, move);
		step++;
		await runStep(context, 'H2', step, byName('reload'));
	}

	// Forward after a clear: two pins, Back onto the first, clear it, then Forward onto the second.
	await openConsoleTimed(context);
	context.tape = new HistoryTape(consoleEntry());
	context.session = freshSession();
	const forwardAfterClear = ['pinCheckoutAction', 'pinNightlyAction', 'back', 'clearAll', 'forward'];
	for(let index = 0; index < forwardAfterClear.length; index++)
	{
		await runStep(context, 'H3', index + 1, byName(forwardAfterClear[index]));
	}

	// A chip under an action reached by Back, which drops what was ahead.
	await openConsoleTimed(context);
	context.tape = new HistoryTape(consoleEntry());
	context.session = freshSession();
	const chipAfterBack = ['pinCheckoutAction', 'clickChip', 'back', 'clickChip', 'forward'];
	for(let index = 0; index < chipAfterBack.length; index++)
	{
		const move = byName(chipAfterBack[index]);
		if(!move.available(context))
		{
			console.log(`  H4/${String(index + 1).padStart(2, '0')} ${move.name} unavailable in ${describePins(context.tape.current())}`);
			continue;
		}
		await runStep(context, 'H4', index + 1, move);
	}
}

/**
 * @description Probe 1: an identical re-pin. Three kinds — a chip for the chain already narrowed to,
 *              a pasted id of the action already pinned, a pasted id of the chain already pinned —
 *              each followed by one Back. Whether Back leaves the screen as it was (a duplicate
 *              history entry the platform did not coalesce) or undoes the previous drill-in (it did)
 *              is recorded either way; the ruling is the controller's.
 * @param {Object} context The run context.
 */
async function probeIdenticalRepin(context)
{
	console.log('\nP1: an identical re-pin');
	const cases = [
		{
			name: 'chip already narrowed to',
			setUp: async() =>
			{
				await context.logConsole.search(ACTION_CHECKOUT);
				const chip = context.logConsole.actionChips().first();
				const chain = await chip.getAttribute('data-correlation-id');
				await chip.click();
				await context.logConsole.waitForListSettled();
				return {action: ACTION_CHECKOUT, chain};
			},
			repeat: async() =>
			{
				await context.logConsole.actionChips().first().click();
				await context.logConsole.waitForListSettled();
			},
			coalesced: 'the whole action (Back undid the narrowing)',
			duplicated: 'the chain still narrowed (Back popped a duplicate entry)'
		},
		{
			name: 'pasted id of the pinned action',
			setUp: async() =>
			{
				await context.logConsole.search(ACTION_CHECKOUT);
				return {action: ACTION_CHECKOUT, chain: null};
			},
			repeat: () => context.logConsole.search(ACTION_CHECKOUT),
			coalesced: 'nothing pinned (Back undid the pin)',
			duplicated: 'the action still pinned (Back popped a duplicate entry)'
		},
		{
			name: 'pasted id of the pinned chain',
			setUp: async() =>
			{
				await context.logConsole.search(CHAIN_NOTIFY);
				return {action: null, chain: CHAIN_NOTIFY};
			},
			repeat: () => context.logConsole.search(CHAIN_NOTIFY),
			coalesced: 'nothing pinned (Back undid the pin)',
			duplicated: 'the chain still pinned (Back popped a duplicate entry)'
		}
	];
	for(const probe of cases)
	{
		await openConsoleTimed(context);
		const pinned = await probe.setUp();
		await probe.repeat();
		const afterRepeat = addressKeys(context.page);
		await context.page.goBack();
		await settleConsole(context.logConsole);
		const afterBack = addressKeys(context.page);
		const stillPinned = (afterBack[STATE_KEY_ACTION] || null) === pinned.action && (afterBack[STATE_KEY_CHAIN] || null) === pinned.chain;
		const outcome = stillPinned ? probe.duplicated : probe.coalesced;
		console.log(`  P1 ${probe.name}: after the re-pin [${formatKeys(afterRepeat)}], Back left [${formatKeys(afterBack)}] — ${outcome}`);
		// The row is a note either way: what Back does after an identical re-pin is recorded for the
		// record, not held against the run, so a clean walk still exits zero.
		await context.ledger.report(context, {
			session: 'P1', step: cases.indexOf(probe) + 1, move: `re-pin: ${probe.name}`, check: 'identical-re-pin',
			expected: 'recorded either way for a ruling', observed: `Back left ${formatKeys(afterBack)} — ${outcome}`,
			pins: consoleEntry(pinned.action, pinned.chain), informational: true
		});
	}
}

/**
 * @description Probe 2: Back onto a scoped Chain Monitor. From the monitor kept to the checkout
 *              action, Show the action's logs and then Back: the scope pill and the Launched under
 *              column have to be back as they were.
 * @param {Object} context The run context.
 */
async function probeBackOntoScopedMonitor(context)
{
	console.log('\nP2: Back onto a scoped Chain Monitor');
	const scopedUrl = `${getInstanceUrl()}/lightning/n/${prefixed('ChainMonitor')}?${STATE_KEY_ACTION}=${ACTION_CHECKOUT}&${STATE_KEY_STAMP}=${Date.now()}`;
	await context.page.goto(scopedUrl, {waitUntil: 'domcontentloaded'});
	await settleMonitor(context);
	const pillBefore = await context.monitor.getActionPill().innerText().catch(() => '');
	const columnsBefore = await context.monitor.getColumnLabels();
	const launchedBefore = await context.monitor.getLaunchedUnderValues();
	await context.monitor.getShowActionLogsButton().click();
	await waitForPageLoad(context.page);
	await settleConsole(context.logConsole);
	const consoleKeys = addressKeys(context.page);
	await context.page.goBack();
	await settleMonitor(context);
	const pillAfter = await context.monitor.getActionPill().innerText().catch(() => '');
	const columnsAfter = await context.monitor.getColumnLabels();
	const launchedAfter = await context.monitor.getLaunchedUnderValues();
	const same = pillBefore.trim() === pillAfter.trim() && columnsBefore.join('|') === columnsAfter.join('|')
			&& launchedBefore.join('|') === launchedAfter.join('|');
	console.log(`  P2 console arrived with [${formatKeys(consoleKeys)}]; monitor pill "${pillAfter.trim().replace(/\s+/g, ' ')}", `
			+ `columns [${columnsAfter.join(', ')}], launched under [${launchedAfter.join(', ')}]`);
	await context.ledger.report(context, {
		session: 'P2', step: 1, move: 'back onto the scoped monitor', check: same ? 'monitor-scope-restored-note' : 'monitor-scope-restored',
		expected: `pill "${pillBefore.trim()}" columns [${columnsBefore.join(', ')}] launched [${launchedBefore.join(', ')}]`,
		observed: `pill "${pillAfter.trim()}" columns [${columnsAfter.join(', ')}] launched [${launchedAfter.join(', ')}]`,
		pins: monitorEntry(ACTION_CHECKOUT), informational: same
	});
	if(!columnsAfter.includes(MONITOR_LAUNCHED_UNDER))
	{
		await context.ledger.report(context, {
			session: 'P2', step: 2, move: 'back onto the scoped monitor', check: 'monitor-launched-under-column',
			expected: `the ${MONITOR_LAUNCHED_UNDER} column while scoped`, observed: `[${columnsAfter.join(', ')}]`, pins: monitorEntry(ACTION_CHECKOUT)
		});
	}
}

/**
 * @description Probe 3: the pre-mount action path. A reload on an address that carries the action,
 *              and on one that carries the action beside a chip-listed chain: one summary read, one
 *              list read, and no resolver read for a chain the banner already names.
 * @param {Object} context The run context.
 */
async function probePreMountReads(context)
{
	console.log('\nP3: the server reads a pre-mount address costs');
	const cases = [
		{name: 'action alone', state: `${STATE_KEY_ACTION}=${ACTION_CHECKOUT}`, expectResolver: 0},
		{name: 'action beside a chip-listed chain', state: `${STATE_KEY_ACTION}=${ACTION_CHECKOUT}&${STATE_KEY_CHAIN}=${CHAIN_NOTIFY}`, expectResolver: 0}
	];
	for(const probe of cases)
	{
		const url = `${getInstanceUrl()}/lightning/n/${context.logConsole.tabApiName()}?${probe.state}`;
		context.apexCalls.clear();
		await context.page.goto(url, {waitUntil: 'domcontentloaded'});
		await settleConsole(context.logConsole);
		await context.page.waitForTimeout(SHORT_POLL_MILLISECONDS);
		const counts = {
			getActionSummary: context.apexCalls.get('getActionSummary') || 0,
			getLogEntries: context.apexCalls.get('getLogEntries') || 0,
			getLogProblems: context.apexCalls.get('getLogProblems') || 0,
			resolveSearchId: context.apexCalls.get('resolveSearchId') || 0,
			// The ribbon reads under two names: the entries view counts entries, the problems view problems.
			ribbon: (context.apexCalls.get('getEntrySummary') || 0) + (context.apexCalls.get('getLogSummary') || 0)
		};
		const listReads = counts.getLogEntries + counts.getLogProblems;
		console.log(`  P3 ${probe.name}: summary=${counts.getActionSummary} list=${listReads} (entries ${counts.getLogEntries}, problems ${counts.getLogProblems})`
				+ ` resolver=${counts.resolveSearchId} ribbon=${counts.ribbon}`);
		const asExpected = counts.getActionSummary === 1 && listReads === 1 && counts.resolveSearchId === probe.expectResolver;
		await context.ledger.report(context, {
			session: 'P3', step: cases.indexOf(probe) + 1, move: `reload on ${probe.name}`, check: asExpected ? 'pre-mount-reads-note' : 'pre-mount-reads',
			expected: `summary=1 list=1 resolver=${probe.expectResolver}`,
			observed: `summary=${counts.getActionSummary} list=${listReads} resolver=${counts.resolveSearchId} ribbon=${counts.ribbon}`,
			pins: consoleEntry(ACTION_CHECKOUT, probe.state.includes(STATE_KEY_CHAIN) ? CHAIN_NOTIFY : null),
			informational: asExpected
		});
	}
}

module.exports = {
	createRandom,
	settleConsole,
	settleMonitor,
	settleFor,
	openConsoleTimed,
	openMonitorTimed,
	MOVES,
	runStep,
	runRandomSession,
	runHostileSequences,
	probeIdenticalRepin,
	probeBackOntoScopedMonitor,
	probePreMountReads
};
