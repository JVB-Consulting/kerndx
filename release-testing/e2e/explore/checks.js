// SPDX-License-Identifier: Apache-2.0
// Part 3 of the exploration: the checks run after every step, and the seed's own totals checked before
// the first one.
'use strict';

const {
	STATE_KEY_ACTION, STATE_KEY_CHAIN, STATE_KEY_WINDOW_START, STATE_KEY_WINDOW_END, STATE_KEY_STAMP, CONSOLE_STATE_KEYS, PAGE_SIZE,
	POLL_TIMEOUT_MILLISECONDS, POLL_INTERVAL_MILLISECONDS, SHORT_POLL_MILLISECONDS, LIST_EXTRA_POLL_MILLISECONDS, MESSAGE_EXCERPT_LENGTH,
	NOISE_EXCERPT_LENGTH, STACK_EXCERPT_LENGTH, NOTABLE_CONSOLE_ERROR, labelValues
} = require('./constants');
const {ACTION_CHECKOUT, ACTION_NIGHTLY, ACTION_LEGACY, CHAIN_NAMES, CHECKOUT_SENTENCE_FRAGMENT, LEGACY_SENTENCE, EXPECTED_CHIP_COUNT, DOCUMENTED_ROW_TOTALS}
		= require('./shaped-seed');
const {consoleEntry, rowsUnderPins, expectedRowCount, shortId} = require('./model');

/**
 * @description Compares the rows the seed actually laid down with the totals the seed script
 *              documents, before a single move is made. A mismatch is a finding and the walk still
 *              runs: every later row-count check reads the same rows, so knowing the fixtures are off
 *              is what tells a reader whether to believe those checks.
 * @param {Object} oracle The rows read from the database.
 * @returns {Array} One finding per total that does not match.
 */
function checkSeedTotals(oracle)
{
	const findingsFound = [];
	for(const total of DOCUMENTED_ROW_TOTALS)
	{
		const matching = rowsUnderPins(consoleEntry(total.action, total.chain), oracle);
		const count = matching === null ? null : matching.length;
		if(count !== total.rows)
		{
			findingsFound.push({
				session: 'SEED', step: DOCUMENTED_ROW_TOTALS.indexOf(total) + 1, move: 'the shaped seed', check: 'seed-totals',
				expected: `${total.rows} rows for ${total.name}`, observed: count === null ? 'the oracle could not match the state' : `${count} rows`,
				pins: consoleEntry(total.action, total.chain)
			});
		}
	}
	return findingsFound;
}

/**
 * @description Reads the screen until it matches, and settles on the FIRST match: a check that agrees
 *              costs one read and returns at once, and only a check that disagrees waits out the
 *              timeout. That is what lets a load or a rewrite still in flight pass without a false
 *              finding, and it is also why a state that flickers through the expected value would be
 *              accepted — the walk is looking for states that never arrive, not for transient ones.
 * @param {Function} read Reads the value from the screen.
 * @param {Function} matches Whether a value is the one the model expects.
 * @param {number} timeout How long to keep reading before giving up.
 * @returns {Promise<Object>} The last value read, and whether it matched.
 */
async function poll(read, matches, timeout = POLL_TIMEOUT_MILLISECONDS)
{
	const deadline = Date.now() + timeout;
	let value = await read();
	while(!matches(value) && Date.now() < deadline)
	{
		await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MILLISECONDS));
		value = await read();
	}
	return {value, ok: matches(value)};
}

// The console's own keys in the address bar, whichever side of the fragment the platform put them on.
function addressKeys(page)
{
	const url = new URL(page.url());
	const keys = {};
	const collect = (params) =>
	{
		for(const key of CONSOLE_STATE_KEYS)
		{
			const value = params.get(key);
			if(value)
			{
				keys[key] = value;
			}
		}
	};
	collect(url.searchParams);
	if(url.hash.includes('?'))
	{
		collect(new URLSearchParams(url.hash.slice(url.hash.indexOf('?') + 1)));
	}
	return keys;
}

function addressMatchesPins(keys, pins)
{
	if(keys[STATE_KEY_STAMP])
	{
		return false;
	}
	if((keys[STATE_KEY_ACTION] || null) !== pins.action || (keys[STATE_KEY_CHAIN] || null) !== pins.chain)
	{
		return false;
	}
	if(pins.window)
	{
		// The same instant written two ways is the same window: the model's copy comes from the run row
		// through Date, the address's from the monitor, and a trailing-zeros difference is not a finding.
		return sameInstant(keys[STATE_KEY_WINDOW_START], pins.window);
	}
	return !keys[STATE_KEY_WINDOW_START] && !keys[STATE_KEY_WINDOW_END];
}

function sameInstant(left, right)
{
	if(left === right)
	{
		return true;
	}
	const leftTime = Date.parse(left);
	const rightTime = Date.parse(right);
	return !Number.isNaN(leftTime) && !Number.isNaN(rightTime) && leftTime === rightTime;
}

function formatKeys(keys)
{
	const parts = Object.entries(keys).map(([key, value]) => `${key.replace('c__', '')}=${value.length > 12 ? shortId(value) : value}`);
	return parts.length ? parts.join(' ') : 'no console keys';
}

// A monitor entry is not the console's address to keep: the monitor's scope arrives by navigation and
// its own stamp is its business, so only the page and the scope pill are read on one.
async function checkMonitorScreen(context, pins)
{
	const findings = [];
	const onMonitor = await poll(() => Promise.resolve(context.page.url().includes('ChainMonitor')), (value) => value === true, SHORT_POLL_MILLISECONDS);
	if(!onMonitor.ok)
	{
		findings.push({check: 'monitor-page', expected: 'the Chain Monitor', observed: context.page.url().split('?')[0]});
	}
	const scoped = await poll(() => context.monitor.getActionPill().count(), (count) => (pins.action ? count > 0 : count === 0));
	if(!scoped.ok)
	{
		findings.push({
			check: 'monitor-scope-pill', expected: pins.action ? 'the scope pill is on' : 'no scope pill', observed: `${scoped.value} pill(s)`
		});
	}
	return findings;
}

// The address is the record of the pins (§2.1 rules 1 to 4, invariants 1 and 3).
async function checkAddress(context, pins)
{
	const address = await poll(() => addressKeys(context.page), (keys) => addressMatchesPins(keys, pins));
	if(address.ok)
	{
		return [];
	}
	const wanted = `${pins.action ? `action=${shortId(pins.action)} ` : ''}${pins.chain ? `chain=${shortId(pins.chain)} ` : ''}`
			+ `${pins.window ? 'windowStart=set ' : ''}no stamp`;
	return [{check: 'address', expected: wanted.trim(), observed: formatKeys(address.value)}];
}

// The two pills: each on screen exactly when its pin is set, and the chain's named whenever the seed
// knows the run behind it.
async function checkPills(context, pins)
{
	const findings = [];
	const actionPill = await poll(() => context.logConsole.actionPill().count(), (count) => (pins.action ? count > 0 : count === 0));
	if(!actionPill.ok)
	{
		findings.push({
			check: 'action-pill', expected: pins.action ? 'the action pill is on' : 'no action pill', observed: `${actionPill.value} pill(s)`
		});
	}
	const chainPill = await poll(() => context.logConsole.correlationPill().count(), (count) => (pins.chain ? count > 0 : count === 0));
	if(!chainPill.ok)
	{
		findings.push({
			check: 'chain-pill', expected: pins.chain ? 'the chain pill is on' : 'no chain pill', observed: `${chainPill.value} pill(s)`
		});
		return findings;
	}
	if(pins.chain && CHAIN_NAMES[pins.chain])
	{
		const wording = new RegExp(`^Chain: ${CHAIN_NAMES[pins.chain]} · CHAIN-\\d+`);
		const named = await poll(() => context.logConsole.correlationPill().innerText().catch(() => ''), (text) => wording.test(text.trim()));
		if(!named.ok)
		{
			findings.push({
				check: 'chain-pill-name', expected: `Chain: ${CHAIN_NAMES[pins.chain]} · CHAIN-n`, observed: named.value.trim().replace(/\s+/g, ' ')
			});
		}
	}
	return findings;
}

// The banner: on screen exactly while an action is pinned, carrying the seed's own counts for the
// checkout action, the legacy sentence for the legacy one, and one chip per chain.
async function checkBanner(context, pins)
{
	const findings = [];
	const banner = await poll(() => context.logConsole.actionBannerSentence().count(), (count) => (pins.action ? count > 0 : count === 0));
	if(!banner.ok)
	{
		return [{check: 'banner', expected: pins.action ? 'the action banner is on' : 'no action banner', observed: `${banner.value} banner(s)`}];
	}
	if(!pins.action)
	{
		return findings;
	}
	const sentence = (await context.logConsole.actionBannerSentence().innerText().catch(() => '')).trim().replace(/\s+/g, ' ');
	if(pins.action === ACTION_CHECKOUT && !sentence.includes(CHECKOUT_SENTENCE_FRAGMENT))
	{
		findings.push({check: 'banner-sentence', expected: CHECKOUT_SENTENCE_FRAGMENT, observed: sentence});
	}
	if(pins.action === ACTION_LEGACY && sentence !== LEGACY_SENTENCE)
	{
		findings.push({check: 'banner-sentence', expected: LEGACY_SENTENCE, observed: sentence});
	}
	if(pins.action === ACTION_NIGHTLY && sentence.length === 0)
	{
		findings.push({check: 'banner-sentence', expected: 'a sentence for the nightly action', observed: 'empty'});
	}
	const chips = await poll(() => context.logConsole.actionChips().count(), (count) => count === EXPECTED_CHIP_COUNT[pins.action]);
	if(!chips.ok)
	{
		findings.push({check: 'banner-chips', expected: `${EXPECTED_CHIP_COUNT[pins.action]} chips`, observed: `${chips.value} chips`});
	}
	return findings;
}

// The rows the state should hold, and the position line and pager that describe them. A state the
// model cannot put a number on is counted as stood down rather than guessed at.
async function checkRowsAndPosition(context, pins, session)
{
	const expected = expectedRowCount(pins, session, context.oracle);
	if(expected === null)
	{
		context.skippedCountChecks++;
		return [];
	}
	const rows = await poll(() => context.logConsole.getRowCount(), (count) => count === expected, POLL_TIMEOUT_MILLISECONDS + LIST_EXTRA_POLL_MILLISECONDS);
	if(!rows.ok)
	{
		return [{check: 'row-count', expected: `${expected} rows`, observed: `${rows.value} rows`}];
	}
	if(expected === 0)
	{
		const empty = await poll(() => context.logConsole.emptyState().count(), (count) => count > 0);
		return empty.ok ? [] : [{check: 'empty-state', expected: 'the empty state for a state with no rows', observed: 'no empty state'}];
	}
	if(expected > PAGE_SIZE)
	{
		return [];
	}
	const findings = [];
	const expectedPosition = labelValues.LogConsole_EntriesPosition.replace('{0}', '1').replace('{1}', String(expected)).replace('{2}', String(expected));
	const position = await poll(() => context.logConsole.positionLine().innerText().catch(() => ''), (text) => text.trim() === expectedPosition);
	if(!position.ok)
	{
		findings.push({check: 'position-line', expected: expectedPosition, observed: position.value.trim()});
	}
	const pages = await poll(() => context.logConsole.pageNumberButtons().count(), (count) => count === 1);
	if(!pages.ok)
	{
		findings.push({check: 'page-numbers', expected: 'one page', observed: `${pages.value} page buttons`});
	}
	return findings;
}

// Whatever the browser itself complained about since the last check. An uncaught error is always a
// finding; a console error is one when it names either console, and noise otherwise.
function collectBrowserComplaints(context)
{
	const findings = context.pageErrors.splice(0)
	.map((error) =>
	{
		// The stack goes to the run log rather than into the table: a findings row is one line, and the
		// frames are long. The message stays the row, so the table reads as it always has.
		if(error.stack)
		{
			console.log(`     page-error stack: ${error.stack.replace(/\s+/g, ' ').slice(0, STACK_EXCERPT_LENGTH)}`);
		}
		return {check: 'page-error', expected: 'no uncaught error', observed: error.message.replace(/\s+/g, ' ').slice(0, MESSAGE_EXCERPT_LENGTH)};
	});
	for(const message of context.consoleErrors.splice(0))
	{
		if(NOTABLE_CONSOLE_ERROR.test(message))
		{
			findings.push({
				check: 'console-error', expected: 'no console error from either console', observed: message.replace(/\s+/g, ' ').slice(0, MESSAGE_EXCERPT_LENGTH)
			});
			continue;
		}
		context.consoleNoise.push(message.replace(/\s+/g, ' ').slice(0, NOISE_EXCERPT_LENGTH));
	}
	return findings;
}

/**
 * @description Every check the design's rules allow on this state, each a named function returning
 *              the findings it has. Nothing throws: a state that disagrees is reported and the walk
 *              carries on.
 * @param {Object} context The run context (the page, the page objects, the oracle, the error log).
 * @param {Object} pins The history entry the model says the reader is on.
 * @param {Object} session The console's session state.
 * @returns {Promise<Array>} The findings, each with a check name, what was expected and what showed.
 */
async function runChecks(context, pins, session)
{
	if(pins.kind === 'monitor')
	{
		return [...await checkMonitorScreen(context, pins), ...collectBrowserComplaints(context)];
	}
	return [
		...await checkAddress(context, pins),
		...await checkPills(context, pins),
		...await checkBanner(context, pins),
		...await checkRowsAndPosition(context, pins, session),
		...collectBrowserComplaints(context)
	];
}

module.exports = {
	checkSeedTotals,
	poll,
	addressKeys,
	addressMatchesPins,
	sameInstant,
	formatKeys,
	checkMonitorScreen,
	checkAddress,
	checkPills,
	checkBanner,
	checkRowsAndPosition,
	collectBrowserComplaints,
	runChecks
};
