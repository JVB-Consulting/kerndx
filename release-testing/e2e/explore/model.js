// SPDX-License-Identifier: Apache-2.0
// Part 2 of the exploration: the state model. The history tape, the console's own session state, and
// the rows a pinned state should be showing.
'use strict';

const {
	ALL_LEVELS, DEFAULT_LEVELS, ACTION_OPENING_LEVELS, DEFAULT_PRESET_MINUTES, WIDEST_PRESET_MINUTES, ACTION_RANGE_MARGIN_MILLISECONDS,
	BOUNDARY_GUARD_MILLISECONDS, MINUTE_MILLISECONDS
} = require('./constants');
const {ACTION_CHAINS} = require('./shaped-seed');

// One history entry: which screen it is, and what the console has pinned on it.
function consoleEntry(action = null, chain = null, window = null)
{
	return {kind: 'console', action, chain, window};
}

function monitorEntry(action = null)
{
	return {kind: 'monitor', action, chain: null, window: null};
}

// Whether two history entries record the same screen with the same pins. An in-place pin that repeats
// what the address already records writes nothing, so it is no new stop in the reader's journey and the
// tape must not invent one: a Back after it goes back to where the pin before it came from.
function samePins(entry, other)
{
	return entry.kind === other.kind && entry.action === other.action && entry.chain === other.chain && entry.window === other.window;
}

// The script's own record of the browser's history: the entries it has pushed, and where in them the
// reader stands. A push after a Back drops what was ahead, the way the browser's own stack does.
class HistoryTape
{
	constructor(entry)
	{
		this.entries = [entry];
		this.index = 0;
	}

	current()
	{
		return this.entries[this.index];
	}

	push(entry)
	{
		this.entries = this.entries.slice(0, this.index + 1);
		this.entries.push(entry);
		this.index = this.entries.length - 1;
	}

	replace(entry)
	{
		this.entries[this.index] = entry;
	}

	canGoBack()
	{
		return this.index > 0;
	}

	canGoForward()
	{
		return this.index < this.entries.length - 1;
	}

	goBack()
	{
		this.index--;
		return this.current();
	}

	goForward()
	{
		this.index++;
		return this.current();
	}
}

// What the console holds beside its pins: the view being looked at, the levels that are on, the date
// range and the search term. `trusted` says whether the model still knows all four; when it does not,
// the row-count and position checks stand down while the address, the pills and the banner carry on.
function freshSession()
{
	return {view: 'problems', levels: [...DEFAULT_LEVELS], range: {kind: 'preset', minutes: DEFAULT_PRESET_MINUTES}, searchTerm: '', trusted: true};
}

// Opening an action switches ERROR, WARN and INFO on and leaves DEBUG as the reader had it, which is
// what the console does (openAction), so the model keeps DEBUG when it was already on.
function openedActionSession(session, action)
{
	const keepsDebug = session.levels.includes('DEBUG');
	session.view = 'entries';
	session.levels = keepsDebug ? [...ACTION_OPENING_LEVELS, 'DEBUG'] : [...ACTION_OPENING_LEVELS];
	session.range = {kind: 'lifetime', action};
	session.searchTerm = '';
	session.trusted = true;
}

function pinnedRunSession(session, windowStart, windowEnd)
{
	session.view = 'entries';
	session.levels = [...ALL_LEVELS];
	session.range = windowStart ? {kind: 'window', start: windowStart, end: windowEnd || null} : {kind: 'preset', minutes: WIDEST_PRESET_MINUTES};
	session.searchTerm = '';
	session.trusted = true;
}

/**
 * @description Follows the session state across a Back, a Forward or a reload. A reload is a fresh
 *              mount, so the address alone decides everything. A Back or a Forward may reach a live
 *              console (which changes only what differs) or a remount (which re-pins from the
 *              address); where the two would leave the console differently the session is marked
 *              untrusted and only the pins are checked.
 * @param {Object} session The session state to update in place.
 * @param {Object} from The entry the reader was on.
 * @param {Object} to The entry the reader lands on.
 * @param {boolean} isRemount Whether the step is a reload, which always remounts.
 */
function followHistoryStep(session, from, to, isRemount)
{
	if(to.kind !== 'console')
	{
		session.trusted = false;
		return;
	}
	if(to.action)
	{
		const sameAction = !isRemount && from.kind === 'console' && from.action === to.action;
		const rangeAlreadyLifetime = session.range.kind === 'lifetime' && session.range.action === to.action;
		const levelsAlreadyOpening = ACTION_OPENING_LEVELS.every((level) => session.levels.includes(level)) && session.levels.length === ACTION_OPENING_LEVELS.length;
		if(sameAction && !(rangeAlreadyLifetime && levelsAlreadyOpening && session.view === 'entries' && !session.searchTerm))
		{
			// A live console narrows or widens without touching the range, the levels or the view; a
			// remount would set all three. The two readings differ, so the count stands down.
			session.trusted = false;
			return;
		}
		openedActionSession(session, to.action);
		return;
	}
	if(to.chain)
	{
		pinnedRunSession(session, to.window, null);
		return;
	}
	if(isRemount)
	{
		const fresh = freshSession();
		session.view = fresh.view;
		session.levels = fresh.levels;
		session.range = fresh.range;
		session.searchTerm = '';
		session.trusted = true;
		return;
	}
	// Nothing pinned on a live console: the range stays whatever it was and the levels depend on which
	// pill went away, and the count of an unpinned console is the whole org's anyway.
	session.trusted = false;
}

function modelledWindow(range, oracle)
{
	const now = Date.now();
	if(range.kind === 'preset')
	{
		return {start: now - (range.minutes * MINUTE_MILLISECONDS), end: now + MINUTE_MILLISECONDS};
	}
	if(range.kind === 'lifetime')
	{
		const span = oracle.actionSpans[range.action];
		return span ? {start: span.first - ACTION_RANGE_MARGIN_MILLISECONDS, end: span.last + ACTION_RANGE_MARGIN_MILLISECONDS} : null;
	}
	if(range.kind === 'window')
	{
		const start = Date.parse(range.start);
		const end = range.end ? Date.parse(range.end) : now;
		return Number.isNaN(start) || Number.isNaN(end) ? null : {start, end};
	}
	return null;
}

function rowsUnderPins(pins, oracle)
{
	if(pins.action && pins.chain)
	{
		return (ACTION_CHAINS[pins.action] || []).includes(pins.chain) ? oracle.rows.filter((row) => row.correlation === pins.chain) : null;
	}
	if(pins.action)
	{
		return oracle.rows.filter((row) => row.root === pins.action || row.correlation === pins.action);
	}
	if(pins.chain)
	{
		return oracle.rows.filter((row) => row.correlation === pins.chain);
	}
	return null;
}

/**
 * @description How many rows the list should be showing in this state, or null when the model cannot
 *              say (the problems view, a search term in the box, nothing pinned, a state whose range
 *              or levels the model lost track of, or a row sitting on the window's edge).
 * @param {Object} pins The history entry's pins.
 * @param {Object} session The console's session state.
 * @param {Object} oracle The seeded rows read from the database.
 * @returns {number|null} The expected row count, or null when it is not knowable.
 */
function expectedRowCount(pins, session, oracle)
{
	if(!session.trusted || session.view !== 'entries' || session.searchTerm)
	{
		return null;
	}
	const candidates = rowsUnderPins(pins, oracle);
	if(!candidates)
	{
		return null;
	}
	const window = modelledWindow(session.range, oracle);
	if(!window)
	{
		return null;
	}
	const onTheEdge = candidates.some((row) => Math.abs(row.createdAt - window.start) < BOUNDARY_GUARD_MILLISECONDS
			|| Math.abs(row.createdAt - window.end) < BOUNDARY_GUARD_MILLISECONDS);
	if(onTheEdge)
	{
		return null;
	}
	return candidates.filter((row) => session.levels.includes(row.level) && row.createdAt >= window.start && row.createdAt <= window.end).length;
}

function shortId(id)
{
	return id ? `…${id.slice(-4)}` : '-';
}

function describePins(pins)
{
	return `${pins.kind}(action=${shortId(pins.action)} chain=${shortId(pins.chain)} window=${pins.window ? 'set' : '-'})`;
}

module.exports = {
	consoleEntry,
	monitorEntry,
	samePins,
	HistoryTape,
	freshSession,
	openedActionSession,
	pinnedRunSession,
	followHistoryStep,
	modelledWindow,
	rowsUnderPins,
	expectedRowCount,
	shortId,
	describePins
};
