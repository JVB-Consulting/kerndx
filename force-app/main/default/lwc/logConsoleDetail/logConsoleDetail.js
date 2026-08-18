// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tabbed detail pane for a single Log Console entry. Presentational and self-contained: it
 * renders the supplied opened-entry `DTO_LogEntryDetail` across Overview / Stack trace / Context tabs, and
 * a Timeline tab that reconstructs the correlated execution as a tree of Apex transactions from the supplied
 * `DTO_TraceEntry` nodes. Selecting a hop focuses it inside this drawer (the container's list never moves);
 * for a non-opened hop it asks the container to load that hop's full detail (`entryfocus`) and renders the
 * returned `focusedDetail` inline, so the full message, stack trace and context are one click away without
 * leaving the timeline. All row actions (close, open record, open in Chain Monitor) dispatch up to the
 * container, which owns the data.
 *
 * @author Jason van Beukering
 *
 * @date July 2026, August 2026
 */
import {api} from 'lwc';
import LOCALE from '@salesforce/i18n/locale';
import {ComponentBuilder} from 'c/componentBuilder';
import {formatCount} from 'c/utilityStreaming';
import {copyToClipBoard} from 'c/utilitySystem';
import {CONTEXT_LABEL_BY_VALUE} from 'c/logConsoleContext';

import tabOverview from '@salesforce/label/c.LogConsole_TabOverview';
import tabStackTrace from '@salesforce/label/c.LogConsole_TabStackTrace';
import tabContext from '@salesforce/label/c.LogConsole_TabContext';
import tabTimeline from '@salesforce/label/c.LogConsole_TabTimeline';
import timelineTitle from '@salesforce/label/c.LogConsole_TimelineTitle';
import timelineThisEntry from '@salesforce/label/c.LogConsole_TimelineThisEntry';
import timelineStandalone from '@salesforce/label/c.LogConsole_TimelineStandalone';
import timelineNotRegistered from '@salesforce/label/c.LogConsole_TimelineNotRegistered';
import timelineOverview from '@salesforce/label/c.LogConsole_TimelineOverview';
import timelineAllLevels from '@salesforce/label/c.LogConsole_TimelineAllLevels';
import timelineTransaction from '@salesforce/label/c.LogConsole_TimelineTransaction';
import timelineTransactions from '@salesforce/label/c.LogConsole_TimelineTransactions';
import timelineEntry from '@salesforce/label/c.LogConsole_TimelineEntry';
import timelineEntries from '@salesforce/label/c.LogConsole_TimelineEntries';
import timelineErrorIn from '@salesforce/label/c.LogConsole_TimelineErrorIn';
import timelineAsync from '@salesforce/label/c.LogConsole_TimelineAsync';
import timelineFromTransaction from '@salesforce/label/c.LogConsole_TimelineFromTransaction';
import timelineFromEarlierTransaction from '@salesforce/label/c.LogConsole_TimelineFromEarlierTransaction';
import timelineGap from '@salesforce/label/c.LogConsole_TimelineGap';
import timelineCapOfTotal from '@salesforce/label/c.LogConsole_TimelineCapOfTotal';
import timelineCapOfTotalNoChain from '@salesforce/label/c.LogConsole_TimelineCapOfTotalNoChain';
import timelineCapTruncated from '@salesforce/label/c.LogConsole_TimelineCapTruncated';
import timelineCapTruncatedNoChain from '@salesforce/label/c.LogConsole_TimelineCapTruncatedNoChain';
import timelineOpenedEntry from '@salesforce/label/c.LogConsole_TimelineOpenedEntry';
import timelineNoFocusDetail from '@salesforce/label/c.LogConsole_TimelineNoFocusDetail';
import timelineLoadingFocus from '@salesforce/label/c.LogConsole_TimelineLoadingFocus';
import timelineFocusLoadFailed from '@salesforce/label/c.LogConsole_TimelineFocusLoadFailed';
import legendDebug from '@salesforce/label/c.LogConsole_LegendDebug';
import legendInfo from '@salesforce/label/c.LogConsole_LegendInfo';
import legendWarning from '@salesforce/label/c.LogConsole_LegendWarning';
import legendError from '@salesforce/label/c.LogConsole_LegendError';
import legendOpened from '@salesforce/label/c.LogConsole_LegendOpened';
import offsetStart from '@salesforce/label/c.LogConsole_ChainStart';
import offsetSeconds from '@salesforce/label/c.LogConsole_ChainOffsetSeconds';
import offsetMinutes from '@salesforce/label/c.LogConsole_ChainOffsetMinutes';
import offsetHours from '@salesforce/label/c.LogConsole_ChainOffsetHours';
import durationSeconds from '@salesforce/label/c.LogConsole_DurationSeconds';
import durationMinutes from '@salesforce/label/c.LogConsole_DurationMinutes';
import durationHours from '@salesforce/label/c.LogConsole_DurationHours';
import detailsHeading from '@salesforce/label/c.LogConsole_DetailsHeading';
import limitsHeading from '@salesforce/label/c.LogConsole_LimitsHeading';
import limitsOnlyUsed from '@salesforce/label/c.LogConsole_LimitsOnlyUsed';
import noLimits from '@salesforce/label/c.LogConsole_NoLimits';
import noStackTrace from '@salesforce/label/c.LogConsole_NoStackTrace';
import noStackTraceHint from '@salesforce/label/c.LogConsole_NoStackTraceHint';
import noStackTraceSourceHint from '@salesforce/label/c.LogConsole_NoStackTraceSourceHint';
import copy from '@salesforce/label/c.LogConsole_Copy';
import copied from '@salesforce/label/c.LogConsole_Copied';
import copyFailed from '@salesforce/label/c.LogConsole_CopyFailed';
import close from '@salesforce/label/c.LogConsole_Close';
import actionOpenChain from '@salesforce/label/c.LogConsole_ActionOpenChain';
import actionOpenRecord from '@salesforce/label/c.LogConsole_ActionOpenRecord';
import metaLogNumber from '@salesforce/label/c.LogConsole_MetaLogNumber';
import metaSource from '@salesforce/label/c.LogConsole_MetaSource';
import metaContext from '@salesforce/label/c.LogConsole_MetaContext';
import metaUser from '@salesforce/label/c.LogConsole_MetaUser';
import metaCorrelation from '@salesforce/label/c.LogConsole_MetaCorrelation';
import metaTransaction from '@salesforce/label/c.LogConsole_MetaTransaction';
import metaParentTransaction from '@salesforce/label/c.LogConsole_MetaParentTransaction';
import firstSeen from '@salesforce/label/c.LogConsole_FirstSeen';
import lastSeen from '@salesforce/label/c.LogConsole_LastSeen';
import logged from '@salesforce/label/c.LogConsole_Logged';
import noMessage from '@salesforce/label/c.LogConsole_NoMessage';
import messageCaption from '@salesforce/label/c.LogConsole_MessageCaption';
import noContext from '@salesforce/label/c.LogConsole_NoContext';
import noContextHint from '@salesforce/label/c.LogConsole_NoContextHint';
import viewOccurrences from '@salesforce/label/c.LogConsole_ViewOccurrences';
import provenanceTagged from '@salesforce/label/c.LogConsole_ProvenanceTagged';
import actionOpenLatestOccurrence from '@salesforce/label/c.LogConsole_ActionOpenLatestOccurrence';
import derivedNoOccurrence from '@salesforce/label/c.LogConsole_DerivedNoOccurrence';
import stackUnavailable from '@salesforce/label/c.LogConsole_StackUnavailable';
import stackUnavailableHint from '@salesforce/label/c.LogConsole_StackUnavailableHint';
import taggedCountExplained from '@salesforce/label/c.LogConsole_TaggedCountExplained';
import taggedCountExplainedHint from '@salesforce/label/c.LogConsole_TaggedCountExplainedHint';
import trackProblem from '@salesforce/label/c.LogConsole_TrackProblem';
import trackProblemHint from '@salesforce/label/c.LogConsole_TrackProblemHint';
import trackProblemCaveat from '@salesforce/label/c.LogConsole_TrackProblemCaveat';
import trackProblemExceptionNote from '@salesforce/label/c.LogConsole_TrackProblemExceptionNote';
import nameSource from '@salesforce/label/c.LogConsole_NameSource';
import nameSourceHint from '@salesforce/label/c.LogConsole_NameSourceHint';
import nameSourceCaveat from '@salesforce/label/c.LogConsole_NameSourceCaveat';

const EMPHASISED_OCCURRENCE_THRESHOLD = 200;
// The wire's provenance for a problem the developer fingerprinted in code. Everything else in the problems
// view was grouped at read time.
const PROVENANCE_ROLLUP = 'rollup';
const PROVENANCE_DERIVED = 'derived';
// The placeholder the zero-config snippet tells the reader to replace. Deliberately not a real class: the
// entries it is offered for were logged without a source, so there is none to fill in.
const SOURCE_PLACEHOLDER = 'MyClass.myMethod';
// The variable name the snippet uses for an exception already in hand. A problem carrying an exception type
// was logged from a catch block, so the reader has one in scope to pass.
const CAUGHT_EXCEPTION_VARIABLE = 'caughtException';
// The one level whose LOG_Builder method also takes an Exception: error(Exception) exists, warn(Exception) and
// the rest do not, so a snippet at any other level hands the message string across even when the problem
// carries an exception type.
const LEVEL_ERROR = 'error';
// What Apex accepts inside a single-quoted literal, and how each hazard is written back. The backslash goes
// first: escaping it after the others would double the escapes just written. A raw line break cannot appear
// in an Apex literal at all, so it becomes the escape sequence rather than being dropped. A raw tab is legal
// but invisible; written as \\t it stays the same string and the pasted code shows what it holds.
const APEX_LITERAL_ESCAPES = [
	[
		/\\/g,
		'\\\\'
	],
	[
		/'/g,
		'\\\''
	],
	[
		/\r/g,
		'\\r'
	],
	[
		/\n/g,
		'\\n'
	],
	[
		/\t/g,
		'\\t'
	]
];

// Escapes a value for an Apex string literal. A log message and a class name are both free subscriber text:
// an apostrophe would end the literal, a backslash starts an escape sequence Apex may not recognise (or eats the
// closing quote when it is the last character), and a line break splits the literal across lines — each of them
// leaves the pasted snippet uncompilable, or worse, quietly altered.
function apexLiteral(value)
{
	return APEX_LITERAL_ESCAPES.reduce((text, [hazard, escaped]) => text.replace(hazard, escaped), String(value ?? ''));
}

const TAB_OVERVIEW = 'overview';
// The timeline shows at most this many transactions; beyond it, the user is pointed to the Chain Monitor.
const TRANSACTION_CAP = 30;
// When the collapsed run count exceeds this, the minimap folds whole runs of async hops into one "Async xN".
const MINIMAP_MAX_BOUNDARIES = 6;
// A hop that starts at least this many seconds after its parent ended earns a "gap before this hop" marker.
const GAP_THRESHOLD_SECONDS = 30;
const SECONDS_PER_MINUTE = 60;
const SECONDS_PER_HOUR = 3600;
// Execution contexts that count as async boundaries for the minimap's whole-run collapse.
const ASYNC_CONTEXTS = new Set([
	'QUEUEABLE',
	'TRANSACTION_FINALIZER_QUEUEABLE',
	'BATCH_APEX',
	'SCHEDULED',
	'FUTURE'
]);
const LEVEL_RANK = {DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3};
// The spoken form of each severity, for the assistive label on a timeline dot (whose visible level tag stays raw).
const LEGEND_LABEL_BY_LEVEL = {DEBUG: legendDebug, INFO: legendInfo, WARN: legendWarning, ERROR: legendError};

// The worst (highest-severity) level among the supplied levels; DEBUG when the list is empty.
function worstLevel(levels)
{
	return levels.reduce((worst, level) => (LEVEL_RANK[level] > LEVEL_RANK[worst] ? level : worst), 'DEBUG');
}

// The colour-axis status for a level: info and debug read as "fine" (OK), warning and error keep their level.
function statusOf(level)
{
	return level === 'INFO' || level === 'DEBUG' ? 'OK' : level;
}

// The friendly quiddity label for a raw execution-context value, falling back to the raw value.
function contextLabel(executionEvent)
{
	return CONTEXT_LABEL_BY_VALUE[executionEvent] || executionEvent;
}

// An instant as epoch milliseconds for `lightning-relative-date-time`, from the ISO-8601 string an Apex
// Datetime arrives as (or a number already); null stays null.
function toEpochMilliseconds(instant)
{
	return instant ? new Date(instant).getTime() : null;
}

// The "Class.method:line" source of a detail or trace node, or null when it was logged with no class. The
// class is what makes a source: the wire sends an exception's line number on its own when no class was
// recorded, and joining that to an absent class reads "undefined.64" — so a bare line is no source at all.
function sourceLabelOf(node)
{
	return node.className ? [
		node.className,
		node.methodLine
	].filter(Boolean).join('.') : null;
}

export default class LogConsoleDetail extends ComponentBuilder('notification')
{
	@api view = 'problems';
	@api occurrenceCount = null;
	/**
	 * @description When the open problem was first and last seen, as the problems list knows them: the whole
	 * group's span, folded across every occurrence. The detail cannot carry these — it describes ONE entry,
	 * and for a grouped problem that entry is the most recent occurrence, so its own timestamps would read
	 * "first seen a moment ago" for a problem two days old. Ignored in the entries view, where the entry's own
	 * time is the truth. ISO strings or epoch values, as the wire sends them.
	 * @type {string|number|null}
	 */
	@api problemFirstSeen = null;
	@api problemLastSeen = null;
	/**
	 * @description How the open problem came to exist: 'rollup' for one the developer tagged in code,
	 * 'derived' for one grouped at read time, null in the entries view. It cannot be read off the detail —
	 * both kinds open on the same DTO — so the container, which held the row, supplies it.
	 * @type {string|null}
	 */
	@api provenance = null;
	/**
	 * @description The namespace prefix a generated Apex snippet must carry to compile in this org: "kern."
	 * in a managed subscriber, empty in a no-namespace deploy. This is copy-to-compile code, so a wrong prefix
	 * hands half the audience a snippet that fails on paste.
	 * @type {string}
	 */
	@api namespacePrefix = '';

	currentDetail = null;
	currentTrace = [];
	currentFocusedDetail = null;
	transactionModel = {transactions: [], byId: {}, startMillis: 0};
	focusedEntryId = null;
	collapsedTransactionIds = new Set();
	pendingScrollTransactionId = null;
	hasFocusedHeading = false;
	activeTab = TAB_OVERVIEW;

	label = {
		tabOverview,
		tabStackTrace,
		tabContext,
		tabTimeline,
		timelineOverview,
		timelineAllLevels,
		detailsHeading,
		limitsHeading,
		limitsOnlyUsed,
		noLimits,
		noStackTrace,
		copy,
		copied,
		copyFailed,
		close,
		actionOpenChain,
		actionOpenRecord,
		metaLogNumber,
		metaSource,
		metaContext,
		metaUser,
		metaCorrelation,
		metaTransaction,
		metaParentTransaction,
		firstSeen,
		lastSeen,
		logged,
		noMessage,
		noContext,
		noContextHint,
		viewOccurrences,
		legendDebug,
		legendInfo,
		legendWarning,
		legendError,
		legendOpened,
		timelineNoFocusDetail,
		timelineLoadingFocus,
		timelineFocusLoadFailed,
		provenanceTagged,
		actionOpenLatestOccurrence,
		derivedNoOccurrence,
		stackUnavailable,
		stackUnavailableHint,
		taggedCountExplainedHint,
		trackProblem,
		trackProblemHint,
		trackProblemCaveat,
		trackProblemExceptionNote,
		nameSource,
		nameSourceHint,
		nameSourceCaveat
	};
	/**
	 * @description Whether the server truncated the correlated trace at its row cap, so the timeline flags
	 * that the full chain is only in the Chain Monitor even when fewer than the display cap of transactions
	 * are shown.
	 * @type {boolean}
	 */
	@api traceTruncated = false;

	/**
	 * @description The opened entry to render. Setting a new entry re-arms the one-shot heading focus, resets
	 * to the Overview tab, and focuses the timeline back on the opened entry.
	 * @type {Object}
	 */
	@api get detail()
	{
		return this.currentDetail;
	}

	set detail(value)
	{
		this.currentDetail = value;
		this.hasFocusedHeading = false;
		this.activeTab = TAB_OVERVIEW;
		this.focusedEntryId = value ? value.id : null;
		this.currentFocusedDetail = null;
		this.collapsedTransactionIds = new Set();
	}

	/**
	 * @description The correlated execution trace (the `DTO_TraceEntry` nodes the container loads alongside
	 * the detail). Rebuilds the transaction tree whenever it changes.
	 * @type {Array<Object>}
	 */
	@api get trace()
	{
		return this.currentTrace;
	}

	set trace(value)
	{
		this.currentTrace = value || [];
		this.transactionModel = this.buildTransactionModel(this.currentTrace);
	}

	/**
	 * @description The full detail loaded on demand for the currently focused non-opened hop, so its message,
	 * stack trace and context render inline in the timeline focus card. Null while a load is in flight or
	 * when the opened entry is focused (whose detail is already present).
	 * @type {Object}
	 */
	@api get focusedDetail()
	{
		return this.currentFocusedDetail;
	}

	set focusedDetail(value)
	{
		this.currentFocusedDetail = value || null;
	}

	get hasDetail()
	{
		return this.currentDetail != null;
	}

	get isProblemsView()
	{
		return this.view === 'problems';
	}

	get countPillClass()
	{
		return this.occurrenceCount < EMPHASISED_OCCURRENCE_THRESHOLD ? 'count-pill count-pill_low' : 'count-pill';
	}

	/**
	 * @description Whether a registered async chain shares this entry's correlation, gating the Open in Chain
	 * Monitor entry point. Reads the server-computed flag, not merely the presence of a correlation id.
	 * @returns {boolean}
	 */
	get showChainButton()
	{
		return this.currentDetail.chainExists === true;
	}

	/**
	 * @description The "Class.method:line" source location for the opened entry, or null when the entry was
	 * logged with no source. Gated behind `hasDetail` in the template, so `currentDetail` is always populated
	 * here. The class is what makes a source: an entry logged with no class still carries the exception's
	 * line number, and the wire sends that line on its own — a location that reads "undefined.64" if it is
	 * joined to a class that is not there, so a bare line is not shown as a source at all.
	 * @returns {string|null}
	 */
	get sourceLabel()
	{
		return sourceLabelOf(this.currentDetail);
	}

	// ---- provenance ----------------------------------------------------------------------------------

	get isDerivedProblem()
	{
		return this.isProblemsView && this.provenance === PROVENANCE_DERIVED;
	}

	get isTaggedProblem()
	{
		return this.isProblemsView && this.provenance === PROVENANCE_ROLLUP;
	}

	/**
	 * @description Whether every entry behind this grouped problem went away between the list being built
	 * and the row being clicked, leaving only what the grouping itself knew. The absent id is the tell: a
	 * group that resolved to an entry carries that entry's id.
	 * @returns {boolean}
	 */
	get isPurgedGroup()
	{
		return this.isDerivedProblem && !this.currentDetail.id;
	}

	/**
	 * @description Whether there is a record behind this detail to open. Only for a row that IS a record: a
	 * grouped problem opens the entry that represents it instead, under its own label, and one whose entries
	 * are gone opens nothing at all — an ungated button there navigates to /lightning/r/null/view, and a door
	 * onto nothing is worse than no door.
	 * @returns {boolean}
	 */
	get showOpenRecordButton()
	{
		return !!this.currentDetail.id && !this.isDerivedProblem;
	}

	get showOpenLatestButton()
	{
		return this.isDerivedProblem;
	}

	get openLatestDisabled()
	{
		return this.isPurgedGroup;
	}

	/**
	 * @description Whether to show the log-number chip at all. A grouped problem has no record of its own, and
	 * the chip is dropped rather than dashed: the list needs a dash because an empty table cell reads as a
	 * value that went missing, but a chip simply absent from a row of chips is not ambiguous. The number
	 * belonging to the entry the group resolved to is deliberately not shown here — this drawer heads the
	 * group, not that entry.
	 * @returns {boolean}
	 */
	get showLogNumber()
	{
		return !this.isDerivedProblem;
	}

	/**
	 * @description The heading over the note explaining a tagged problem's single entry, carrying the count
	 * the reader can see beside it.
	 * @returns {string}
	 */
	get taggedCountHeading()
	{
		// Grouped in the reader's locale, so the heading agrees with the "× 1,284" pill it sits under rather
		// than reading "count of 1284" beside it.
		return taggedCountExplained.replace('{0}', formatCount(this.occurrenceCount, LOCALE));
	}

	/**
	 * @description Whether to explain why a tagged problem shows one entry against a much larger count. Only
	 * where the discrepancy is actually visible — a count of one explains itself, and without the note an
	 * admin reasonably concludes the other occurrences were deleted, which is the most damaging wrong
	 * conclusion this console can invite.
	 * @returns {boolean}
	 */
	get showTaggedCountNote()
	{
		return this.isTaggedProblem && this.occurrenceCount > 1;
	}

	/**
	 * @description Whether this grouped problem was logged with no source at all. Everything throwing the
	 * same error is then one problem here, however many different places that is, so the useful move is to
	 * name the source rather than to tag what is still several problems wearing one name.
	 * @returns {boolean}
	 */
	get isUnattributedGroup()
	{
		return this.isDerivedProblem && !this.currentDetail.classMethod;
	}

	get showTrackBlock()
	{
		return this.isDerivedProblem && !this.isUnattributedGroup;
	}

	/**
	 * @description Whether the snippet hands the reader's own exception across, which is only true when the
	 * problem carries an exception type AND sits at the one level whose LOG_Builder method takes an Exception.
	 * Drives the note telling the reader `caughtException` is a stand-in for the variable their catch block
	 * actually holds — without it, the pasted snippet fails with "Variable does not exist".
	 * @returns {boolean}
	 */
	get snippetPassesException()
	{
		return !!this.currentDetail.exceptionType && this.currentDetail.level.toLowerCase() === LEVEL_ERROR;
	}

	/**
	 * @description The copy-to-compile Apex that turns this grouped problem into a tagged one — or, when it
	 * was logged with no source, that gives it a source to be grouped by. Built from the problem's own level,
	 * exception type and source, so it pastes into the code that logged it. The source is the raw
	 * `classMethod` the entry recorded, never the drawer's display location: that folds the exception's line
	 * number in (`capture:64`), and a line baked into `emitAt` would mis-attribute every future entry and give
	 * the fingerprint a key that moves on every deploy.
	 * @returns {string}
	 */
	get apexSnippet()
	{
		// No fallback on the level: it is one of the three fields a problem is grouped ON, so it is always there.
		const level = this.currentDetail.level.toLowerCase();
		// An exception type means this was logged from a catch block, so the reader has the exception itself in
		// scope — but only error(Exception) exists on the builder, so at any other level the message goes across
		// instead; without an exception type, the message is all the console can offer back either way.
		const thrown = this.snippetPassesException ? CAUGHT_EXCEPTION_VARIABLE : `'${apexLiteral(this.currentDetail.shortMessage)}'`;
		const head = `${this.namespacePrefix}LOG_Builder.build()\n\t.${level}(${thrown})`;
		if(this.isUnattributedGroup)
		{
			return `${head}\n\t.emitAt('${SOURCE_PLACEHOLDER}');`;
		}
		const source = apexLiteral(this.currentDetail.classMethod);
		const fingerprint = `${source}:${apexLiteral(this.currentDetail.exceptionType || this.currentDetail.level)}`;
		return `${head}\n\t.withFingerprint('${fingerprint}')\n\t.emitAt('${source}');`;
	}

	get hasStackTrace()
	{
		return !!this.currentDetail.stackTrace;
	}

	/**
	 * @description The line under the stack-trace empty state. Only an entry logged with an exception carries
	 * frames, so a DEBUG, INFO or WARN entry can never show a stack however the console is configured — which
	 * makes "no stack trace" a dead end unless it also says where the entry WAS written. When the entry recorded
	 * a source, the hint names that location so the reader has somewhere to look; with no source recorded there
	 * is nothing to point at, and the general explanation is all the drawer can stand behind.
	 * @returns {string}
	 */
	get stackTraceHint()
	{
		const source = this.sourceLabel;
		return source ? noStackTraceSourceHint.replace('{0}', source) : noStackTraceHint;
	}

	/**
	 * @description The execution context for the Details grid, under the same display name the list column
	 * uses rather than the raw stored value: AURA and "Aura / LWC" a few hundred pixels apart read as two
	 * different things. Null when the entry recorded no context, which the grid dashes.
	 * @returns {string|null}
	 */
	get contextDisplayName()
	{
		return contextLabel(this.currentDetail.executionEvent) || null;
	}

	/**
	 * @description Whether the stack pane should say there is no entry to show one FROM, rather than the
	 * shipped line saying this entry was logged without one. The distinction is the whole point: the shipped
	 * copy is a fact about an entry, and a grouped problem whose entries are gone has no entry to state it
	 * about.
	 * @returns {boolean}
	 */
	get showStackUnavailable()
	{
		return this.isPurgedGroup;
	}

	/**
	 * @description The originating user shown in the Details grid: the resolved display name, falling back
	 * to the raw stored Id when the value does not resolve to a user. Gated behind `hasDetail`.
	 * @returns {string}
	 */
	get userLabel()
	{
		return this.currentDetail.userName || this.currentDetail.userId;
	}

	/**
	 * @description Whether the entry carries the originating user's Id, so the Details grid can link the
	 * name straight to that user's record instead of showing inert text. Gated behind `hasDetail`.
	 * @returns {boolean}
	 */
	get hasUserLink()
	{
		return !!this.currentDetail.userId;
	}

	/**
	 * @description The record-page URL for the originating user, in the same relative form the console's
	 * list column uses for a log entry. Read only when `hasUserLink` gates the link on.
	 * @returns {string}
	 */
	get userRecordUrl()
	{
		return `/lightning/r/${this.currentDetail.userId}/view`;
	}

	/**
	 * @description The uppercase caption above the Overview message card: the exception type when the entry
	 * carries one, else "<LEVEL> message". Gated behind `hasDetail`.
	 * @returns {string}
	 */
	get messageCaption()
	{
		return this.currentDetail.exceptionType || messageCaption.replace('{0}', this.currentDetail.level);
	}

	/**
	 * @description Whether the entry captured request context, gating the Context tab between the JSON view
	 * with its copy affordance and the empty state that says how to capture context. Gated behind `hasDetail`.
	 * @returns {boolean}
	 */
	get hasContext()
	{
		return !!this.currentDetail.contextJson;
	}

	/**
	 * @description The term the "View occurrences" drill searches the entries view for: the class the problem
	 * was logged from, or — for a problem logged with no source, where everything throwing the same error is
	 * one problem — its message. Null when the problem offers neither, in which case there is no drill.
	 * @returns {string|null}
	 */
	get occurrencesDrillTerm()
	{
		return this.currentDetail.className || this.currentDetail.shortMessage || null;
	}

	/**
	 * @description Whether to offer the drill from this problem to the individual entries behind it: only in
	 * the grouped problems view, only once the container has supplied the occurrence count, and only when
	 * there is a term to drill on — a drill with nothing to search for would open the entries view unfiltered
	 * under a button that promised this problem's occurrences.
	 * @returns {boolean}
	 */
	get showOccurrencesButton()
	{
		return this.isProblemsView && this.occurrenceCount > 0 && !!this.occurrencesDrillTerm;
	}

	/**
	 * @description Whether the opened entry carries a message body, gating the Overview message code block so a
	 * blank message shows a muted placeholder instead of an empty dark panel. Gated behind `hasDetail`.
	 * @returns {boolean}
	 */
	get hasMessage()
	{
		return !!this.currentDetail.message;
	}

	// Null-tolerant, like every getter that reads a collection off the detail. A grouped problem whose
	// occurrences were all purged opens on a label-only detail that carries no collections at all, and reaching
	// through one of them would take the drawer down rather than simply leaving a section undrawn.
	get hasLimits()
	{
		return (this.currentDetail.limitBars?.length ?? 0) > 0;
	}

	// No null guard of its own: the template reads this only inside hasLimits, which already refuses a missing
	// list. A second guard here would be a branch nothing can reach.
	get limitRows()
	{
		return this.currentDetail.limitBars.map((bar) => ({
			key: bar.name, name: bar.name, used: bar.used, maximum: bar.maximum, percentage: bar.percentage, level: bar.level, barStyle: `width: ${Math.min(bar.percentage, 100)}%;`
		}));
	}

	/**
	 * @description The first-seen instant as epoch milliseconds for `lightning-relative-date-time`, which
	 * does not accept the ISO-8601 string an Apex Datetime arrives as. Gated behind `hasDetail`. In the
	 * problems view the PROBLEM's span wins over the detail's: the detail is one entry — for a grouped problem
	 * the most recent occurrence — so its own timestamps would say a two-day-old problem was first seen a moment
	 * ago, and a group whose entries have all been purged has no entry timestamps at all. The container holds
	 * the row and supplies the span; the entries view has no row, and the entry's own time is right there.
	 * @returns {number|null}
	 */
	get firstSeenValue()
	{
		return toEpochMilliseconds(this.isProblemsView && this.problemFirstSeen ? this.problemFirstSeen : this.currentDetail.firstSeen);
	}

	get lastSeenValue()
	{
		return toEpochMilliseconds(this.isProblemsView && this.problemLastSeen ? this.problemLastSeen : this.currentDetail.lastSeen);
	}

	// ---- timeline model ------------------------------------------------------------------------------

	get hasCorrelation()
	{
		return !!this.currentDetail.correlationId;
	}

	get hasMultipleEntries()
	{
		return this.currentTrace.length > 1;
	}

	/**
	 * @description The timeline header title: the correlation title with the id when correlated, else a
	 * "this entry" title for a standalone entry.
	 * @returns {string}
	 */
	get timelineTitle()
	{
		return this.hasCorrelation ? timelineTitle : timelineThisEntry;
	}

	get correlationId()
	{
		return this.currentDetail.correlationId;
	}

	/**
	 * @description The explanatory note under the timeline header: none when a registered chain exists, a
	 * "stands alone" note when uncorrelated, and a "correlated but not a registered chain" note otherwise.
	 * @returns {string|null}
	 */
	get timelineNote()
	{
		if(!this.hasCorrelation)
		{
			return timelineStandalone;
		}
		if(!this.showChainButton)
		{
			return timelineNotRegistered.replace('{0}', this.currentDetail.correlationId);
		}
		return null;
	}

	/**
	 * @description The overview stat line: transaction count, entry count, total span, and the errored
	 * transaction's quiddity when one errored.
	 * @returns {string}
	 */
	get overviewStat()
	{
		const transactions = this.transactionModel.transactions;
		const transactionWord = transactions.length === 1 ? timelineTransaction : timelineTransactions;
		const entryWord = this.currentTrace.length === 1 ? timelineEntry : timelineEntries;
		const span = transactions.length ? Math.max(...transactions.map((transaction) => transaction.endSeconds)) : 0;
		let stat = `${transactions.length} ${transactionWord} · ${this.currentTrace.length} ${entryWord} · ⏱ ${this.durationLabel(span)}`;
		const errored = transactions.find((transaction) => transaction.level === 'ERROR');
		if(errored)
		{
			stat += ` · ${timelineErrorIn.replace('{0}', contextLabel(errored.executionEvent))}`;
		}
		return stat;
	}

	/**
	 * @description The timeline legend: a colour swatch and its meaning. The four severities carry the
	 * level-cased class so they read as the ERROR and WARN badges do everywhere else in the console; the
	 * opened-entry swatch is not a severity and stays in sentence case. The spoken text stays as written —
	 * the casing is presentation only, so assistive technology still hears "debug", not "D-E-B-U-G".
	 * @returns {Array<Object>}
	 */
	get legendItems()
	{
		return [
			{key: 'DEBUG', dotClass: 'dot d-DEBUG', text: legendDebug, textClass: 'lgtext lgtext_level'},
			{key: 'INFO', dotClass: 'dot d-INFO', text: legendInfo, textClass: 'lgtext lgtext_level'},
			{key: 'WARN', dotClass: 'dot d-WARN', text: legendWarning, textClass: 'lgtext lgtext_level'},
			{key: 'ERROR', dotClass: 'dot d-ERROR', text: legendError, textClass: 'lgtext lgtext_level'},
			{key: 'self', dotClass: 'dot d-self', text: legendOpened, textClass: 'lgtext'}
		];
	}

	/**
	 * @description The overview minimap segments, built over the same capped transactions the detailed view
	 * shows so every segment maps to a rendered group. Consecutive same-quiddity transactions collapse into
	 * one segment; when that still leaves more than the boundary limit, whole runs of async transactions fold
	 * into a single "Async xN" segment, which keeps a long async chain (the common Queueable/finalizer case)
	 * readable.
	 * @returns {Array<Object>}
	 */
	get overviewSegments()
	{
		const transactions = this.transactionModel.transactions.slice(0, TRANSACTION_CAP);
		const fine = [];
		transactions.forEach((transaction) =>
		{
			const last = fine[fine.length - 1];
			if(last && last.executionEvent === transaction.executionEvent)
			{
				last.count += 1;
				last.level = worstLevel([
					last.level,
					transaction.level
				]);
			}
			else
			{
				fine.push({executionEvent: transaction.executionEvent, count: 1, level: transaction.level, firstId: transaction.id, isAsync: false});
			}
		});
		const runs = fine.length <= MINIMAP_MAX_BOUNDARIES ? fine : this.collapseAsyncRuns(transactions);
		return runs.map((run, index) =>
		{
			const status = statusOf(run.level);
			const runLabel = run.isAsync ? timelineAsync : contextLabel(run.executionEvent);
			return {
				key: `${run.firstId}:${index}`,
				firstId: run.firstId,
				segmentLabel: run.count > 1 ? `${runLabel} ×${run.count}` : runLabel,
				countLabel: run.count > 1 ? `${run.count} ${timelineTransactions}` : `1 ${timelineTransaction}`,
				segmentClass: `mseg s-${status}`,
				showWarnPin: run.level === 'ERROR' || run.level === 'WARN',
				showArrow: index > 0
			};
		});
	}

	/**
	 * @description The flat, time-ordered transaction groups for the detailed view, capped at the display
	 * limit. Each group carries its quiddity, offset, span, severity, entry rows, an optional "from" lineage
	 * breadcrumb, an optional gap marker, and the collapse state.
	 * @returns {Array<Object>}
	 */
	get transactionGroups()
	{
		const ordered = this.transactionModel.transactions;
		const shown = ordered.slice(0, TRANSACTION_CAP);
		return shown.map((transaction) =>
		{
			const collapsed = this.collapsedTransactionIds.has(transaction.id);
			const parent = transaction.parentId ? this.transactionModel.byId[transaction.parentId] : null;
			const entryWord = transaction.nodes.length === 1 ? timelineEntry : timelineEntries;
			const gapSeconds = parent ? transaction.offsetSeconds - parent.endSeconds : 0;
			return {
				key: transaction.id,
				transactionId: transaction.id,
				quiddityLabel: contextLabel(transaction.executionEvent),
				offsetLabel: this.offsetLabel(transaction.offsetSeconds),
				durationLabel: this.durationLabel(transaction.durationSeconds),
				level: transaction.level,
				headClass: `txnhead s-${transaction.status}`,
				badgeClass: `sbadge s-${transaction.status}`,
				chevronClass: collapsed ? 'chev' : 'chev open',
				countLabel: `${transaction.nodes.length} ${entryWord}`,
				crumb: this.lineageCrumb(transaction, parent),
				showGap: parent && gapSeconds >= GAP_THRESHOLD_SECONDS,
				gapLabel: timelineGap.replace('{0}', this.durationLabel(gapSeconds)),
				expanded: !collapsed,
				expandedAttr: String(!collapsed),
				entries: collapsed ? [] : transaction.nodes.map((node) => this.toEntryRow(node))
			};
		});
	}

	get isCapped()
	{
		return this.transactionModel.transactions.length > TRANSACTION_CAP;
	}

	get shownTransactionCount()
	{
		return Math.min(this.transactionModel.transactions.length, TRANSACTION_CAP);
	}

	get showCapRow()
	{
		return this.isCapped || this.traceTruncated;
	}

	/**
	 * @description The cap-row sentence, in the variant that matches the Chain Monitor gate: the pointer to
	 * the Chain Monitor is only part of the sentence when a registered chain exists, since the button that
	 * gets there is gated on the same flag.
	 * @returns {string}
	 */
	get capRowText()
	{
		if(this.traceTruncated)
		{
			const truncated = this.showChainButton ? timelineCapTruncated : timelineCapTruncatedNoChain;
			return truncated.replace('{0}', String(this.shownTransactionCount));
		}
		const capped = this.showChainButton ? timelineCapOfTotal : timelineCapOfTotalNoChain;
		return capped.replace('{0}', String(TRANSACTION_CAP)).replace('{1}', String(this.transactionModel.transactions.length));
	}

	/**
	 * @description The lineage breadcrumb for a transaction. A loaded parent is named by its position in the
	 * trace, which identifies the exact hop where its kind could not — sibling hops spawned by different
	 * transactions of the same kind all read alike. Position is over every loaded transaction, not the
	 * displayed slice, so a parent beyond the display cap is still named by number. A hop whose parent is not
	 * in the loaded trace at all still earns a generic pointer, so it never looks like the start of the
	 * story. A hop with no parent gets no breadcrumb.
	 *
	 * @param {Object} transaction The transaction being rendered.
	 * @param {Object|null} parent The parent transaction, when it is part of the loaded trace.
	 * @returns {string|null}
	 */
	lineageCrumb(transaction, parent)
	{
		if(parent)
		{
			return timelineFromTransaction.replace('{0}', String(parent.ordinal));
		}
		return transaction.parentId ? timelineFromEarlierTransaction : null;
	}

	/**
	 * @description Builds the transaction tree from the correlated trace: it groups the entries by their
	 * transaction, computes each transaction's quiddity, severity, offset from the first entry and span, and
	 * links each transaction to the parent that spawned it. The result feeds both the overview minimap and
	 * the flat grouped view.
	 *
	 * @param {Array<Object>} nodes The correlated trace nodes.
	 * @returns {{transactions: Array<Object>, byId: Object}}
	 */
	buildTransactionModel(nodes)
	{
		if(!nodes || nodes.length === 0)
		{
			return {transactions: [], byId: {}, startMillis: 0};
		}
		const validMillis = nodes.map((node) => this.toMillis(node.createdDate)).filter((millis) => millis > 0);
		const startMillis = validMillis.length ? Math.min(...validMillis) : 0;
		const byTransaction = {};
		nodes.forEach((node) =>
		{
			// Entries with no transaction id (e.g. an uncorrelated single entry) each stand as their own hop.
			const transactionId = node.transactionId || `entry:${node.id}`;
			if(!byTransaction[transactionId])
			{
				byTransaction[transactionId] = {id: transactionId, parentId: node.parentTransactionId || null, nodes: []};
			}
			byTransaction[transactionId].nodes.push(node);
		});
		const transactions = Object.values(byTransaction);
		transactions.forEach((transaction) =>
		{
			const offsets = transaction.nodes.map((node) => Math.round((this.toMillis(node.createdDate) - startMillis) / 1000));
			transaction.executionEvent = transaction.nodes[0].executionEvent;
			transaction.offsetSeconds = Math.min(...offsets);
			transaction.endSeconds = Math.max(...offsets);
			transaction.durationSeconds = transaction.endSeconds - transaction.offsetSeconds;
			transaction.level = worstLevel(transaction.nodes.map((node) => node.level));
			transaction.status = statusOf(transaction.level);
			transaction.hasSelf = transaction.nodes.some((node) => node.isSelf);
		});
		transactions.sort((left, right) => left.offsetSeconds - right.offsetSeconds);
		const byId = {};
		transactions.forEach((transaction, index) =>
		{
			// The 1-based position in the time-ordered list, which is how a lineage breadcrumb names its parent.
			transaction.ordinal = index + 1;
			byId[transaction.id] = transaction;
		});
		return {transactions, byId, startMillis};
	}

	toMillis(createdDate)
	{
		return createdDate ? new Date(createdDate).getTime() : 0;
	}

	/**
	 * @description A compact relative-offset label from the first entry: "start" at zero, otherwise "+Ns",
	 * "+Nm" or "+Nh" from Custom Labels so the timing reads in the viewer's language.
	 * @param {number} seconds Offset in whole seconds from the first entry.
	 * @returns {string}
	 */
	offsetLabel(seconds)
	{
		if(seconds <= 0)
		{
			return offsetStart;
		}
		if(seconds < SECONDS_PER_MINUTE)
		{
			return offsetSeconds.replace('{0}', String(seconds));
		}
		if(seconds < SECONDS_PER_HOUR)
		{
			return offsetMinutes.replace('{0}', String(Math.round(seconds / SECONDS_PER_MINUTE)));
		}
		return offsetHours.replace('{0}', String(Math.round(seconds / SECONDS_PER_HOUR)));
	}

	/**
	 * @description A duration label ("Ns" / "Nm Ns") for a transaction's span, from the duration labels
	 * rather than the offset labels: a span is not an offset, and a translation that moves the offset's
	 * leading "+" would otherwise leave it stranded inside a duration.
	 * @param {number} seconds Whole seconds.
	 * @returns {string}
	 */
	durationLabel(seconds)
	{
		if(seconds < SECONDS_PER_MINUTE)
		{
			return durationSeconds.replace('{0}', String(seconds));
		}
		if(seconds < SECONDS_PER_HOUR)
		{
			const minutes = Math.floor(seconds / SECONDS_PER_MINUTE);
			const remainder = seconds % SECONDS_PER_MINUTE;
			const minutePart = durationMinutes.replace('{0}', String(minutes));
			return remainder ? `${minutePart} ${durationSeconds.replace('{0}', String(remainder))}` : minutePart;
		}
		const hours = Math.floor(seconds / SECONDS_PER_HOUR);
		const wholeMinutes = Math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE);
		const hoursPart = durationHours.replace('{0}', String(hours));
		const minutesPart = durationMinutes.replace('{0}', String(wholeMinutes));
		return wholeMinutes ? `${hoursPart} ${minutesPart}` : hoursPart;
	}

	collapseAsyncRuns(transactions)
	{
		const runs = [];
		transactions.forEach((transaction) =>
		{
			const isAsync = ASYNC_CONTEXTS.has(transaction.executionEvent);
			const last = runs[runs.length - 1];
			if(last && last.isAsync && isAsync)
			{
				last.count += 1;
				last.level = worstLevel([
					last.level,
					transaction.level
				]);
			}
			else
			{
				runs.push({executionEvent: transaction.executionEvent, count: 1, level: transaction.level, firstId: transaction.id, isAsync});
			}
		});
		return runs;
	}

	toEntryRow(node)
	{
		const isSelf = node.id === this.currentDetail.id;
		const isFocused = node.id === this.focusedEntryId;
		const offsets = Math.round((this.toMillis(node.createdDate) - this.transactionModel.startMillis) / 1000);
		const source = sourceLabelOf(node);
		return {
			key: node.id,
			entryId: node.id,
			level: node.level,
			nodeLabel: LEGEND_LABEL_BY_LEVEL[node.level],
			nodeClass: isSelf ? `node d-${node.level} node_self` : `node d-${node.level}`,
			rowClass: isFocused ? 'tent focused' : 'tent',
			source,
			message: node.shortMessage,
			offsetLabel: this.offsetLabel(offsets),
			isSelf,
			openedMarker: isSelf ? timelineOpenedEntry : null,
			isFocused,
			focus: isFocused ? this.buildFocusCard(node, isSelf) : null
		};
	}

	/**
	 * @description The inline focus card for the focused hop: its severity and quiddity, message, and — once
	 * the on-demand detail has loaded — its full stack trace and context. The opened entry's detail is
	 * already present; a non-opened hop shows a loading state until `focusedDetail` arrives.
	 * @param {Object} node The focused trace node.
	 * @param {boolean} isSelf Whether the focused hop is the opened entry.
	 * @returns {Object}
	 */
	buildFocusCard(node, isSelf)
	{
		const loadedDetail = isSelf ? this.currentDetail : this.currentFocusedDetail;
		const typeLabel = `${node.level} · ${contextLabel(node.executionEvent)}`;
		if(loadedDetail && loadedDetail.loadFailed)
		{
			return {
				entryId: node.id,
				typeLabel,
				message: node.shortMessage,
				loading: false,
				hasStack: false,
				hasContext: false,
				showNoDetail: false,
				showOpenRecord: !isSelf,
				loadFailed: true,
				stack: null,
				context: null
			};
		}
		if(!loadedDetail)
		{
			return {
				entryId: node.id,
				typeLabel,
				message: node.shortMessage,
				loading: true,
				hasStack: false,
				hasContext: false,
				showNoDetail: false,
				showOpenRecord: false,
				loadFailed: false,
				stack: null,
				context: null
			};
		}
		const hasStack = !!loadedDetail.stackTrace;
		const hasContext = !!loadedDetail.contextJson;
		return {
			entryId: node.id,
			typeLabel,
			message: loadedDetail.message || node.shortMessage,
			loading: false,
			hasStack,
			stack: loadedDetail.stackTrace,
			hasContext,
			context: loadedDetail.contextJson,
			showNoDetail: !hasStack && !hasContext,
			showOpenRecord: !isSelf,
			loadFailed: false
		};
	}

	// ---- lifecycle + handlers -----------------------------------------------------------------------

	renderedCallback()
	{
		if(this.hasDetail && !this.hasFocusedHeading)
		{
			this.hasFocusedHeading = true;
			this.template.querySelector('[data-testid="heading"]').focus();
		}
		if(this.pendingScrollTransactionId)
		{
			const heads = this.template.querySelectorAll('[data-testid="txn-head"]');
			// Transaction ids can contain characters unsafe for an attribute CSS selector, so match by dataset.
			for(const head of heads)
			{
				if(head.dataset.transactionId === this.pendingScrollTransactionId)
				{
					head.scrollIntoView({block: 'center', behavior: 'smooth'});
					break;
				}
			}
			this.pendingScrollTransactionId = null;
		}
	}

	handleClose()
	{
		this.dispatchEvent(new CustomEvent('close'));
	}

	handleOpenRecord()
	{
		// The header's "Open record" — or, for a grouped problem, "Open latest occurrence" — opens the standard
		// record page for the entry the drawer opened on. Both buttons back onto this one handler because the
		// entry is the same kind of thing either way; only the name is truthful to what the reader clicked.
		this.dispatchEvent(new CustomEvent('openrecord', {detail: {entryId: this.currentDetail.id}}));
	}

	handleOpenFocusedRecord(event)
	{
		// The focus card's "Open record" opens the standard record page for the focused hop.
		this.dispatchEvent(new CustomEvent('openrecord', {detail: {entryId: event.currentTarget.dataset.entryId}}));
	}

	handleOpenChain()
	{
		this.dispatchEvent(new CustomEvent('navigatechain', {detail: {correlationId: this.currentDetail.correlationId}}));
	}

	handleTabActive(event)
	{
		this.activeTab = event.target.value;
	}

	handleToggleTransaction(event)
	{
		const transactionId = event.currentTarget.dataset.transactionId;
		const next = new Set(this.collapsedTransactionIds);
		if(next.has(transactionId))
		{
			next.delete(transactionId);
		}
		else
		{
			next.add(transactionId);
		}
		this.collapsedTransactionIds = next;
	}

	handleFocusHop(event)
	{
		this.focusHop(event.currentTarget.dataset.entryId);
	}

	/**
	 * @description The minimap segment jump: expand that transaction and focus its first entry, so the
	 * detailed view scrolls it into view.
	 */
	handleJumpToTransaction(event)
	{
		const transactionId = event.currentTarget.dataset.transactionId;
		const next = new Set(this.collapsedTransactionIds);
		next.delete(transactionId);
		this.collapsedTransactionIds = next;
		this.pendingScrollTransactionId = transactionId;
		const transaction = this.transactionModel.byId[transactionId];
		if(transaction && transaction.nodes.length)
		{
			this.focusHop(transaction.nodes[0].id);
		}
	}

	/**
	 * @description Focuses a hop inside the drawer without touching the container's list. When the hop is not
	 * the opened entry and its detail is not already loaded, asks the container to load it (`entryfocus`);
	 * the returned `focusedDetail` enriches the focus card. The opened entry needs no load.
	 * @param {string} entryId
	 */
	focusHop(entryId)
	{
		if(!entryId || entryId === this.focusedEntryId)
		{
			return;
		}
		this.focusedEntryId = entryId;
		if(entryId === this.currentDetail.id)
		{
			this.currentFocusedDetail = null;
			return;
		}
		this.currentFocusedDetail = null;
		this.dispatchEvent(new CustomEvent('entryfocus', {detail: {entryId}}));
	}

	handleViewOccurrences()
	{
		// The drill from a problem to the individual entries behind it, keyed on the class the problem was
		// logged from — the same handle the console's ranked-source drill searches on — or on its message when
		// it was logged with no source. Never dispatched without a term: the button is not offered then.
		this.dispatchEvent(new CustomEvent('viewoccurrences', {detail: {source: this.occurrencesDrillTerm}}));
	}

	/** @description Copies the opened entry's full message to the clipboard. */
	handleCopyMessage()
	{
		return this.copyWithFeedback(this.currentDetail.message);
	}

	/** @description Copies the opened entry's stack trace to the clipboard. */
	handleCopyStack()
	{
		return this.copyWithFeedback(this.currentDetail.stackTrace);
	}

	/** @description Copies the opened entry's captured context to the clipboard. */
	handleCopyContext()
	{
		return this.copyWithFeedback(this.currentDetail.contextJson);
	}

	/** @description Copies the opened entry's correlation id to the clipboard. */
	handleCopyCorrelation()
	{
		return this.copyWithFeedback(this.currentDetail.correlationId);
	}

	/** @description Copies the generated Apex snippet, which is the point of showing it. */
	handleCopySnippet()
	{
		return this.copyWithFeedback(this.apexSnippet);
	}

	/**
	 * @description Copies text to the clipboard, confirming with a toast only once the copy actually
	 * happened. A failed copy (Clipboard API and its temporary-input fallback both failing) surfaces an
	 * error toast instead of rejecting.
	 * @param {string} text The text to place on the clipboard.
	 * @returns {Promise<void>}
	 */
	async copyWithFeedback(text)
	{
		try
		{
			await copyToClipBoard(text);
			this.showSuccessToast(this.label.copied);
		}
		catch
		{
			// copyToClipBoard already logged the failure; tell the user the copy did not happen.
			this.showErrorToast(this.label.copyFailed);
		}
	}
}