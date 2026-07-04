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
 * @date July 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
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
import timelineTransaction from '@salesforce/label/c.LogConsole_TimelineTransaction';
import timelineTransactions from '@salesforce/label/c.LogConsole_TimelineTransactions';
import timelineEntry from '@salesforce/label/c.LogConsole_TimelineEntry';
import timelineEntries from '@salesforce/label/c.LogConsole_TimelineEntries';
import timelineErrorIn from '@salesforce/label/c.LogConsole_TimelineErrorIn';
import timelineAsync from '@salesforce/label/c.LogConsole_TimelineAsync';
import timelineFrom from '@salesforce/label/c.LogConsole_TimelineFrom';
import timelineGap from '@salesforce/label/c.LogConsole_TimelineGap';
import timelineCapOfTotal from '@salesforce/label/c.LogConsole_TimelineCapOfTotal';
import timelineCapTruncated from '@salesforce/label/c.LogConsole_TimelineCapTruncated';
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
import detailsHeading from '@salesforce/label/c.LogConsole_DetailsHeading';
import limitsHeading from '@salesforce/label/c.LogConsole_LimitsHeading';
import limitsOnlyUsed from '@salesforce/label/c.LogConsole_LimitsOnlyUsed';
import noLimits from '@salesforce/label/c.LogConsole_NoLimits';
import noStackTrace from '@salesforce/label/c.LogConsole_NoStackTrace';
import copy from '@salesforce/label/c.LogConsole_Copy';
import copied from '@salesforce/label/c.LogConsole_Copied';
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

const EMPHASISED_OCCURRENCE_THRESHOLD = 200;
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

export default class LogConsoleDetail extends ComponentBuilder('notification')
{
	@api view = 'problems';
	@api occurrenceCount = null;

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
		detailsHeading,
		limitsHeading,
		limitsOnlyUsed,
		noLimits,
		noStackTrace,
		copy,
		copied,
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
		legendDebug,
		legendInfo,
		legendWarning,
		legendError,
		legendOpened,
		timelineNoFocusDetail,
		timelineLoadingFocus,
		timelineFocusLoadFailed
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
	 * @description The "Class.method:line" source location for the opened entry. Gated behind `hasDetail` in
	 * the template, so `currentDetail` is always populated here.
	 * @returns {string}
	 */
	get sourceLabel()
	{
		return this.currentDetail.methodLine ? `${this.currentDetail.className}.${this.currentDetail.methodLine}` : this.currentDetail.className;
	}

	get hasStackTrace()
	{
		return !!this.currentDetail.stackTrace;
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
	 * @description Whether the opened entry carries a message body, gating the Overview message code block so a
	 * blank message shows a muted placeholder instead of an empty dark panel. Gated behind `hasDetail`.
	 * @returns {boolean}
	 */
	get hasMessage()
	{
		return !!this.currentDetail.message;
	}

	get hasLimits()
	{
		return this.currentDetail.limitBars.length > 0;
	}

	get limitRows()
	{
		return this.currentDetail.limitBars.map((bar) => ({
			key: bar.name, name: bar.name, used: bar.used, maximum: bar.maximum, percentage: bar.percentage, level: bar.level, barStyle: `width: ${Math.min(bar.percentage, 100)}%;`
		}));
	}

	/**
	 * @description The first-seen instant as epoch milliseconds for `lightning-relative-date-time`, which
	 * does not accept the ISO-8601 string an Apex Datetime arrives as. Gated behind `hasDetail`.
	 * @returns {number|null}
	 */
	get firstSeenValue()
	{
		return this.currentDetail.firstSeen ? new Date(this.currentDetail.firstSeen).getTime() : null;
	}

	get lastSeenValue()
	{
		return this.currentDetail.lastSeen ? new Date(this.currentDetail.lastSeen).getTime() : null;
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

	get legendItems()
	{
		return [
			{key: 'DEBUG', dotClass: 'dot d-DEBUG', text: legendDebug},
			{key: 'INFO', dotClass: 'dot d-INFO', text: legendInfo},
			{key: 'WARN', dotClass: 'dot d-WARN', text: legendWarning},
			{key: 'ERROR', dotClass: 'dot d-ERROR', text: legendError},
			{key: 'self', dotClass: 'dot d-self', text: legendOpened}
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
				crumb: parent ? timelineFrom.replace('{0}', contextLabel(parent.executionEvent)) : null,
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

	get capRowText()
	{
		if(this.traceTruncated)
		{
			return timelineCapTruncated.replace('{0}', String(this.shownTransactionCount));
		}
		return timelineCapOfTotal.replace('{0}', String(TRANSACTION_CAP)).replace('{1}', String(this.transactionModel.transactions.length));
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
		transactions.forEach((transaction) =>
		{
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
	 * @description A duration label ("Ns" / "Nm Ns") for a transaction's span.
	 * @param {number} seconds Whole seconds.
	 * @returns {string}
	 */
	durationLabel(seconds)
	{
		if(seconds < SECONDS_PER_MINUTE)
		{
			return offsetSeconds.replace('{0}', String(seconds)).replace('+', '');
		}
		if(seconds < SECONDS_PER_HOUR)
		{
			const minutes = Math.floor(seconds / SECONDS_PER_MINUTE);
			const remainder = seconds % SECONDS_PER_MINUTE;
			const minutePart = offsetMinutes.replace('{0}', String(minutes)).replace('+', '');
			return remainder ? `${minutePart} ${offsetSeconds.replace('{0}', String(remainder)).replace('+', '')}` : minutePart;
		}
		const hours = Math.floor(seconds / SECONDS_PER_HOUR);
		const wholeMinutes = Math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE);
		const hoursPart = offsetHours.replace('{0}', String(hours)).replace('+', '');
		const minutesPart = offsetMinutes.replace('{0}', String(wholeMinutes)).replace('+', '');
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
		const source = node.methodLine ? `${node.className}.${node.methodLine}` : node.className;
		return {
			key: node.id,
			entryId: node.id,
			level: node.level,
			nodeLabel: node.level,
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
		// The header "Open record" opens the standard record page for the opened entry.
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

	async handleCopyMessage()
	{
		await copyToClipBoard(this.currentDetail.message);
		this.showSuccessToast(this.label.copied);
	}

	async handleCopyStack()
	{
		await copyToClipBoard(this.currentDetail.stackTrace);
		this.showSuccessToast(this.label.copied);
	}
}
