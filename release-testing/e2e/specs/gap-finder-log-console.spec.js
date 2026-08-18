// SPDX-License-Identifier: BUSL-1.1
// Log Console prototype gap-finder (AGENTS.md lever 2): proves every `data-spec-id` frozen in the
// two validated Log Console prototypes round-trips into the DEPLOYED Log Console with matching
// visible text. The prototypes are the spec (internal design artifacts; a checkout without them
// passes its own copies via GAP_FINDER_CONSOLE_PROTOTYPE / GAP_FINDER_TIMELINE_PROTOTYPE):
//   - the console redesign prototype (console shell, list, ribbon, drawer header / Overview /
//     Stack trace / Context)
//   - the timeline prototype (drawer Timeline tab)
//
// Ids fall into three buckets, following the PLAN-138 chain-monitor precedent:
//  - DOM ids: located as `[data-spec-id]` across the console/drawer states that can render them.
//    A state that a live org cannot reach without fixtures is seeded and torn down by this spec.
//  - Copy-checked ids: the deployed text is compared byte-for-byte against the SHIPPED Custom Label
//    value, so a label edit that never reaches the DOM (or vice versa) fails the gate. Platform
//    components that render their own chrome (comboboxes, inputs, the datatable) are checked with
//    `contains` instead of equality, because the host element's text carries the label plus the
//    component's own furniture.
//  - Deferred ids: prototype elements carrying `data-spec-deferred` (the Phase 2 provenance pills)
//    are skipped entirely — they are a decision NOT to ship yet, not a gap.
//
// A separate, NON-fatal copy-drift report compares each prototype's own frozen copy against the
// shipped label. Drift there is a finding for the maintainer (which side is right is a UX call),
// not a build break; the fatal gate is the round-trip itself.
//
// Run (after deploying logConsole + logConsoleDetail):
//   SF_SUBSCRIBER_ORG_ALIAS=YourDevOrgAlias \
//     npx playwright test --config release-testing/e2e/gap-finder.config.js
const fs = require('fs');
const path = require('path');
const {test, expect} = require('@playwright/test');
const LogConsolePage = require('../pages/log-console.page');
const {executeAnonymousApex} = require('../helpers/sf-cli');
const {namespacePrefix} = require('../helpers/sf-namespace');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {readShippedLabelValues} = require('../lib/shipped-labels');

const SPEC_ROOT = path.join(__dirname, '..', '..', '..');
const PROTOTYPE_PATHS = {
	console: process.env.GAP_FINDER_CONSOLE_PROTOTYPE || path.join(SPEC_ROOT, 'plans', 'superpowers', 'specs', '2026-06-30-log-console-redesign-prototype.html'),
	timeline: process.env.GAP_FINDER_TIMELINE_PROTOTYPE || path.join(SPEC_ROOT, 'plans', 'superpowers', 'specs', '2026-07-01-log-console-timeline-prototype.html')
};

// Seed markers. Every seeded row carries one of these prefixes so teardown is exact.
const MARKER = 'gapfinder-';
const TRACE_CORRELATION = `${MARKER}corr-trace`;
const CAP_CORRELATION = `${MARKER}corr-cap`;
const RECURRING_MESSAGE = 'Spec parity recurring warning';
const RECURRING_OCCURRENCES = 3;
const TRACE_TERMINAL_MESSAGE = 'Spec parity trace capture';
const CAP_HOP_MESSAGE = 'Spec parity cap hop 01';
// The drawer marks a hop with a "gap before this hop" note at 30 seconds; the seed opens a real
// window rather than back-dating CreatedDate, which this org does not permit on insert.
const GAP_WINDOW_MS = 35_000;
// The timeline caps its detailed view at 30 transactions, so the cap row needs more than that.
const CAP_TRANSACTION_COUNT = 32;
// Wall time allowed for a focused hop's on-demand detail to load and render its focus card.
const FOCUS_LOAD_SETTLE_MS = 2500;
// Report column widths, so the id table lines up regardless of the longest id.
const REPORT_STATUS_COLUMN_WIDTH = 9;
const REPORT_ID_COLUMN_WIDTH = 32;

// Decorative glyphs a prototype uses to stand in for an SLDS icon; they are not copy. Punctuation
// (including em dashes) is deliberately NOT in this set — a dash is wording, and stripping it would
// hide real copy drift.
const DECORATION = /[↳→←⟳⌕▤⋯×⧉⚠⏱▸]/g;

function normaliseCopy(value)
{
	return (value || '').replace(DECORATION, ' ').replace(/\s+/g, ' ').trim();
}

/**
 * @description The frozen spec ids, and the ids explicitly deferred out of this phase, read from
 *              both prototypes. Deferred ids are returned separately so the report can name them
 *              rather than silently dropping them.
 */
function readFrozenSpecIds()
{
	const ids = new Set();
	const deferred = [];
	for(const [surface, prototypePath] of Object.entries(PROTOTYPE_PATHS))
	{
		const markup = fs.readFileSync(prototypePath, 'utf8');
		for(const match of markup.matchAll(/data-spec-id="([^"]+)"/g))
		{
			ids.add(match[1]);
		}
		for(const match of markup.matchAll(/data-spec-deferred="([^"]+)"/g))
		{
			deferred.push(`${surface}:${match[1]}`);
		}
	}
	return {ids: [...ids].sort(), deferred};
}

/**
 * @description Each annotated element's own literal copy, where the prototype writes it inline.
 *              Elements whose text is interpolated (`${...}`) carry no frozen copy and are left
 *              out of the copy-drift comparison.
 */
function readPrototypeCopy()
{
	const copy = {};
	for(const prototypePath of Object.values(PROTOTYPE_PATHS))
	{
		const markup = fs.readFileSync(prototypePath, 'utf8');
		for(const match of markup.matchAll(/data-spec-id="([^"]+)"[^>]*>([^<]*)</g))
		{
			const text = match[2];
			if(!text.trim() || text.includes('${'))
			{
				continue;
			}
			copy[match[1]] ??= text;
		}
	}
	return copy;
}

// The expectation table. `state` names the console/drawer state the id is checked in; `mode` is
// how its visible text is judged: 'exact' against the shipped label, 'contains' for a platform
// component whose host carries extra chrome, 'nonempty' for run-time values, 'presence' for
// structural containers. `count` asserts a repeated id renders the expected number of elements.
const EXPECTATIONS = {
	// ---- console shell (2026-06-30 prototype) ----
	'console-title': {state: 'console', mode: 'exact', label: 'LogConsole_Title'},
	'date-range-control': {state: 'console', mode: 'contains', label: 'LogConsole_DateRange'},
	'refresh-action': {state: 'console', mode: 'exact', label: 'LogConsole_Refresh'},
	'view-eyebrow': {state: 'console', mode: 'exact', label: 'LogConsole_ViewGroupLabel'},
	'view-toggle-problems': {state: 'console', mode: 'exact', label: 'LogConsole_ViewProblems'},
	'view-toggle-entries': {state: 'console', mode: 'exact', label: 'LogConsole_ViewEntries'},
	'levels-eyebrow': {state: 'console', mode: 'exact', label: 'LogConsole_LevelsGroupLabel'},
	'level-toggle': {state: 'console', mode: 'exact', text: 'ERROR', count: 4},
	'context-eyebrow': {state: 'console', mode: 'exact', label: 'LogConsole_ContextGroupLabel'},
	'context-filter': {state: 'console', mode: 'presence'},
	'search-input': {state: 'console', mode: 'presence'},
	'clear-all-action': {state: 'console', mode: 'exact', label: 'LogConsole_ClearAll'},
	'summary-ribbon': {state: 'console', mode: 'presence'},
	'summary-total-card': {state: 'console', mode: 'contains', label: 'LogConsole_TotalOccurrences'},
	'summary-level-card': {state: 'console', mode: 'nonempty'},
	'summary-top-sources': {state: 'console', mode: 'contains', label: 'LogConsole_TopSources'},
	'top-source-row': {state: 'console', mode: 'nonempty'},
	'entry-list': {state: 'console', mode: 'columns'},
	// ---- custom date range ----
	'custom-range-from-date': {state: 'customRange', mode: 'contains', label: 'LogConsole_FromDate'},
	'custom-range-from-time': {state: 'customRange', mode: 'contains', label: 'LogConsole_FromTime'},
	'custom-range-to-date': {state: 'customRange', mode: 'contains', label: 'LogConsole_ToDate'},
	'custom-range-to-time': {state: 'customRange', mode: 'contains', label: 'LogConsole_ToTime'},
	// ---- drawer opened on a grouped problem ----
	'detail-level-badge': {state: 'problemDrawer', mode: 'exact', text: 'WARN'},
	'detail-log-number': {state: 'problemDrawer', mode: 'nonempty'},
	'detail-count-pill': {state: 'problemDrawer', mode: 'nonempty'},
	'detail-close': {state: 'problemDrawer', mode: 'presence'},
	'detail-heading': {state: 'problemDrawer', mode: 'exact', text: RECURRING_MESSAGE},
	'detail-seen-line': {state: 'problemDrawer', mode: 'contains', label: 'LogConsole_FirstSeen'},
	'detail-action-open-record': {state: 'problemDrawer', mode: 'exact', label: 'LogConsole_ActionOpenRecord'},
	'detail-action-view-occurrences': {state: 'problemDrawer', mode: 'exact', label: 'LogConsole_ViewOccurrences'},
	'detail-tab-overview': {state: 'problemDrawer', mode: 'tab', label: 'LogConsole_TabOverview'},
	'detail-tab-stack': {state: 'problemDrawer', mode: 'tab', label: 'LogConsole_TabStackTrace'},
	'detail-tab-context': {state: 'problemDrawer', mode: 'tab', label: 'LogConsole_TabContext'},
	'detail-tab-timeline': {state: 'problemDrawer', mode: 'tab', label: 'LogConsole_TabTimeline'},
	'message-card': {state: 'problemDrawer', mode: 'nonempty'},
	'message-caption': {state: 'problemDrawer', mode: 'nonempty'},
	'message-text': {state: 'problemDrawer', mode: 'nonempty'},
	'details-grid': {state: 'problemDrawer', mode: 'metagrid'},
	'details-source': {state: 'problemDrawer', mode: 'exact', text: 'SpecParityProbe.recurring:21'},
	'details-user': {state: 'problemDrawer', mode: 'nonempty'},
	// The Stack trace empty state is a title + hint pair (the Context tab's shape), so the container
	// carries both strings and is matched with `contains`.
	'stack-empty': {state: 'problemStack', mode: 'contains', label: 'LogConsole_NoStackTrace'},
	'stack-hint': {state: 'problemStack', mode: 'contains', text: 'SpecParityProbe.recurring:21'},
	'context-empty': {state: 'problemContext', mode: 'contains', label: 'LogConsole_NoContext'},
	'context-hint': {state: 'problemContext', mode: 'exact', label: 'LogConsole_NoContextHint'},
	'timeline-note': {state: 'problemTimeline', mode: 'exact', label: 'LogConsole_TimelineStandalone'},
	// ---- drawer opened on the correlated, chain-registered trace ----
	'detail-action-open-chain': {state: 'traceOverview', mode: 'exact', label: 'LogConsole_ActionOpenChain'},
	// The correlation cell carries the id plus the copy affordance's assistive text, so `contains`.
	'details-correlation': {state: 'traceOverview', mode: 'contains', text: TRACE_CORRELATION},
	'stack-code': {state: 'traceStack', mode: 'nonempty'},
	'context-code': {state: 'traceContext', mode: 'nonempty'},
	'timeline-title': {state: 'traceTimeline', mode: 'contains', label: 'LogConsole_TimelineTitle'},
	'timeline-open-chain': {state: 'traceTimeline', mode: 'contains', label: 'LogConsole_ActionOpenChain'},
	'timeline-overview-label': {state: 'traceTimeline', mode: 'exact', label: 'LogConsole_TimelineOverview'},
	'timeline-overview-stat': {state: 'traceTimeline', mode: 'nonempty'},
	'timeline-all-levels': {state: 'traceTimeline', mode: 'exact', label: 'LogConsole_TimelineAllLevels'},
	'timeline-minimap': {state: 'traceTimeline', mode: 'presence'},
	'minimap-segment': {state: 'traceTimeline', mode: 'nonempty'},
	'timeline-legend': {state: 'traceTimeline', mode: 'nonempty'},
	'timeline-groups': {state: 'traceTimeline', mode: 'presence'},
	'transaction-head': {state: 'traceTimeline', mode: 'nonempty'},
	'transaction-crumb': {state: 'traceTimeline', mode: 'nonempty'},
	'timeline-gap-note': {state: 'traceTimeline', mode: 'contains', text: 'gap before this hop'},
	'timeline-entry': {state: 'traceTimeline', mode: 'nonempty'},
	'timeline-focus-card': {state: 'traceTimeline', mode: 'nonempty'},
	// ---- drawer opened on the capped trace ----
	'timeline-cap-row': {state: 'capTimeline', mode: 'contains', text: 'Showing the first'},
	'cap-open-chain': {state: 'capTimeline', mode: 'contains', label: 'LogConsole_ActionOpenChain'}
};

const results = new Map();
const copyDrift = [];

// A verdict of FOUND is sticky: an id proven in one state must not be downgraded by a later state
// where the surface that carries it is not on screen (a tab that has since been switched away from).
function record(specId, status, note = '')
{
	if(results.get(specId)?.status === 'FOUND')
	{
		return;
	}
	results.set(specId, {status, note});
}

// An expectation naming a label the package does not ship resolves to `undefined`, and an undefined
// expectation certifies nothing: `normaliseCopy(undefined)` is '' and every string contains ''. A
// typo in the table must be reported as a gap rather than pass vacuously.
function unknownLabelNote(expectation, labelValues)
{
	return expectation.label && labelValues[expectation.label] === undefined ? `label ${expectation.label} is not in the shipped Custom Labels` : null;
}

function prefixed(apiName)
{
	return `${namespacePrefix()}${apiName}`;
}

// ---- fixtures ---------------------------------------------------------------------------------

function buildEntry(fields)
{
	const assignments = Object.entries(fields)
	.map(([field, value]) => `row.put('${prefixed(field)}', ${value});`)
	.join('\n\t\t');
	return `\n\t\trow = leType.newSObject();\n\t\t${assignments}\n\t\trows.add(row);\n`;
}

function seedApexHeader()
{
	return `
		SObjectType leType = Schema.getGlobalDescribe().get('${prefixed('LogEntry__c')}');
		List<SObject> rows = new List<SObject>();
		SObject row;
		String me = UserInfo.getUserId();
	`;
}

/**
 * @description Phase one: the recurring problem the grouped view folds, the first hop of the
 *              correlated trace, the whole capped trace, and the two registered chain records the
 *              Open in Chain Monitor gate reads.
 *
 *              The problem summary is driven exclusively by the windowed `rollup:` counter rows and
 *              their `detail:` sample (CTRL_LogConsole.resolveScopedRollups), so the recurring
 *              problem is seeded as that pair — a set of plain forensic rows never surfaces there.
 */
function seedPhaseOneApex()
{
	let apex = seedApexHeader();
	apex += buildEntry({
		Fingerprint__c: `'detail:${MARKER}recurring'`,
		LogLevel__c: '\'WARN\'',
		ShortMessage__c: `'${RECURRING_MESSAGE}'`,
		Message__c: `'${RECURRING_MESSAGE} body'`,
		ClassMethod__c: '\'SpecParityProbe.recurring\'',
		LineNumber__c: '21',
		ExecutionEvent__c: '\'SYNCHRONOUS\'',
		TransactionId__c: `'${MARKER}recurring-detail'`,
		UserId__c: 'me'
	});
	apex += buildEntry({
		Fingerprint__c: `'rollup:${MARKER}recurring:' + Datetime.now().formatGmt('yyyyMMdd')`,
		LogLevel__c: '\'WARN\'',
		OccurrenceCount__c: String(RECURRING_OCCURRENCES),
		TransactionId__c: `'${MARKER}recurring-rollup'`
	});
	// The first trace hop names a parent that is NOT part of the loaded trace, so the drawer must
	// still render the generic out-of-trace breadcrumb.
	apex += buildEntry({
		LogLevel__c: '\'DEBUG\'',
		ShortMessage__c: '\'Spec parity trace start\'',
		ClassMethod__c: '\'SpecParityProbe.submit\'',
		LineNumber__c: '10',
		ExecutionEvent__c: '\'AURA\'',
		CorrelationId__c: `'${TRACE_CORRELATION}'`,
		TransactionId__c: `'${MARKER}trace-0'`,
		ParentTransactionId__c: `'${MARKER}trace-external'`,
		UserId__c: 'me'
	});
	for(let hop = 0; hop < CAP_TRANSACTION_COUNT; hop++)
	{
		const number = String(hop + 1).padStart(2, '0');
		apex += buildEntry({
			LogLevel__c: '\'WARN\'',
			ShortMessage__c: `'Spec parity cap hop ${number}'`,
			ClassMethod__c: `'SpecParityProbe.capHop${number}'`,
			LineNumber__c: String(100 + hop),
			ExecutionEvent__c: hop % 2 === 0 ? '\'QUEUEABLE\'' : '\'TRANSACTION_FINALIZER_QUEUEABLE\'',
			CorrelationId__c: `'${CAP_CORRELATION}'`,
			TransactionId__c: `'${MARKER}cap-${number}'`,
			ParentTransactionId__c: hop === 0 ? 'null' : `'${MARKER}cap-${String(hop).padStart(2, '0')}'`,
			UserId__c: 'me'
		});
	}
	return `${apex}
		insert rows;
		SObjectType chainType = Schema.getGlobalDescribe().get('${prefixed('AsyncChainExecution__c')}');
		List<SObject> chains = new List<SObject>();
		for(String correlation : new List<String>{'${TRACE_CORRELATION}', '${CAP_CORRELATION}'})
		{
			SObject chain = chainType.newSObject();
			chain.put('${prefixed('ChainName__c')}', 'Spec Parity Probe');
			chain.put('${prefixed('Status__c')}', 'Failed');
			chain.put('${prefixed('CorrelationId__c')}', correlation);
			chain.put('${prefixed('TotalSteps__c')}', 3);
			chain.put('${prefixed('CompletedSteps__c')}', 1);
			chain.put('${prefixed('StartedAt__c')}', Datetime.now());
			chains.add(chain);
		}
		insert chains;
		System.debug('GAPFINDER_SEED_PHASE_ONE rows=' + rows.size());
	`;
}

/**
 * @description Phase two, run after a real gap window: the hop that must earn the "gap before this
 *              hop" marker, and the terminal error hop carrying a stack trace and context JSON.
 */
function seedPhaseTwoApex()
{
	const contextJson = '{"contextData":{"orderId":"a0H5g000004ZkLmEAK","amount":249.00,"gateway":"stripe","attempt":3}}';
	const stackTrace = 'System.CalloutException: Read timed out\\n  at SpecParityProbe.capture(SpecParityProbe.cls:64)';
	let apex = seedApexHeader();
	apex += buildEntry({
		LogLevel__c: '\'WARN\'',
		ShortMessage__c: '\'Spec parity trace reserve\'',
		Message__c: '\'Partial reserve: 8 of 12 units\'',
		ClassMethod__c: '\'SpecParityProbe.reserve\'',
		LineNumber__c: '42',
		ExecutionEvent__c: '\'QUEUEABLE\'',
		CorrelationId__c: `'${TRACE_CORRELATION}'`,
		TransactionId__c: `'${MARKER}trace-1'`,
		ParentTransactionId__c: `'${MARKER}trace-0'`,
		ContextData__c: '\'{"contextData":{"sku":"WIDGET-8821","requested":12,"reserved":8}}\'',
		UserId__c: 'me'
	});
	apex += buildEntry({
		LogLevel__c: '\'ERROR\'',
		ShortMessage__c: `'${TRACE_TERMINAL_MESSAGE}'`,
		Message__c: '\'Read timed out after 10000ms calling the payment gateway\'',
		ExceptionType__c: '\'System.CalloutException\'',
		StackTrace__c: `'${stackTrace}'`,
		ClassMethod__c: '\'SpecParityProbe.capture\'',
		LineNumber__c: '64',
		ExecutionEvent__c: '\'TRANSACTION_FINALIZER_QUEUEABLE\'',
		CorrelationId__c: `'${TRACE_CORRELATION}'`,
		TransactionId__c: `'${MARKER}trace-2'`,
		ParentTransactionId__c: `'${MARKER}trace-1'`,
		ContextData__c: `'${contextJson}'`,
		Limits__c: '\'\\nSOQL Queries: 32 of 100\\nCPU Time: 4200 of 10000\''
	});
	return `${apex}
		insert rows;
		System.debug('GAPFINDER_SEED_PHASE_TWO rows=' + rows.size());
	`;
}

function teardownApex()
{
	return `
		List<SObject> seeded = Database.query('SELECT Id FROM ${prefixed('LogEntry__c')}'
				+ ' WHERE ${prefixed('CorrelationId__c')} LIKE \\'${MARKER}%\\' OR ${prefixed('TransactionId__c')} LIKE \\'${MARKER}%\\''
				+ ' OR ${prefixed('Fingerprint__c')} LIKE \\'%${MARKER}%\\'');
		if(!seeded.isEmpty())
		{
			delete seeded;
		}
		List<SObject> seededChains = Database.query('SELECT Id FROM ${prefixed('AsyncChainExecution__c')}'
				+ ' WHERE ${prefixed('CorrelationId__c')} LIKE \\'${MARKER}%\\'');
		if(!seededChains.isEmpty())
		{
			delete seededChains;
		}
		System.debug('GAPFINDER_TEARDOWN entries=' + seeded.size() + ' chains=' + seededChains.size());
	`;
}

// ---- checks -----------------------------------------------------------------------------------

// The expectation table's own guard, and the self-test for `unknownLabelNote`: a pure source check
// that needs no org, so a mistyped label name is caught before a browser is ever launched instead of
// being certified by an empty expectation at run time.
test('every expectation names a shipped Custom Label', () =>
{
	const labelValues = readShippedLabelValues();
	const unknown = Object.entries(EXPECTATIONS)
	.map(([specId, expectation]) => ({specId, note: unknownLabelNote(expectation, labelValues)}))
	.filter((entry) => entry.note !== null)
	.map((entry) => `${entry.specId}: ${entry.note}`);
	expect(unknown, 'expectations whose label name is not in the shipped label file').toEqual([]);
});

test.describe.serial('Log Console prototype gap-finder', () =>
{
	const frozen = readFrozenSpecIds();
	const labelValues = readShippedLabelValues();
	const prototypeCopy = readPrototypeCopy();

	test.beforeAll(async() =>
	{
		executeAnonymousApex(teardownApex(), {timeout: 120_000});
		const phaseOne = executeAnonymousApex(seedPhaseOneApex(), {timeout: 120_000});
		expect(phaseOne, 'Phase-one seed should report GAPFINDER_SEED_PHASE_ONE').toContain('GAPFINDER_SEED_PHASE_ONE');
		// A real wait, not a back-dated CreatedDate: this org does not permit audit-field
		// back-dating on insert, and the gap marker is computed from CreatedDate deltas.
		await new Promise((resolve) => setTimeout(resolve, GAP_WINDOW_MS));
		const phaseTwo = executeAnonymousApex(seedPhaseTwoApex(), {timeout: 120_000});
		expect(phaseTwo, 'Phase-two seed should report GAPFINDER_SEED_PHASE_TWO').toContain('GAPFINDER_SEED_PHASE_TWO');
	});

	test.afterAll(() =>
	{
		// GAPFINDER_KEEP_FIXTURES=1 leaves the seeded rows behind so a failing run can be inspected
		// in the org; the next run's beforeAll clears them first, so it is safe to forget.
		if(process.env.GAPFINDER_KEEP_FIXTURES !== '1')
		{
			executeAnonymousApex(teardownApex(), {timeout: 120_000});
		}
	});

	test('every frozen data-spec-id round-trips into the deployed Log Console', async({page}) =>
	{
		const logConsole = new LogConsolePage(page);
		const root = () => page.locator('.log-console').first();
		const spec = (specId) => root().locator(`[data-spec-id="${specId}"]`);

		/**
		 * @description Judges one spec id against the state currently on screen and records the
		 *              verdict. Never throws: a single unreachable id must not hide the rest of
		 *              the inventory, exactly as the chain-monitor gap-finder does.
		 */
		async function check(specId)
		{
			const expectation = EXPECTATIONS[specId];
			const unknownLabel = unknownLabelNote(expectation, labelValues);
			if(unknownLabel)
			{
				record(specId, 'MISSING', unknownLabel);
				return;
			}
			const locator = spec(specId);
			try
			{
				await locator.first().waitFor({state: 'visible', timeout: 15_000});
				if(expectation.count)
				{
					const found = await locator.count();
					if(found !== expectation.count)
					{
						record(specId, 'MISSING', `expected ${expectation.count} elements, found ${found}`);
						return;
					}
				}
				const expectedText = expectation.label ? labelValues[expectation.label] : expectation.text;
				const actual = normaliseCopy(await locator.first().textContent());
				if(expectation.mode === 'exact' && actual !== normaliseCopy(expectedText))
				{
					record(specId, 'MISSING', `text mismatch: expected "${expectedText}", got "${actual}"`);
					return;
				}
				if(expectation.mode === 'contains' && !actual.includes(normaliseCopy(expectedText)))
				{
					record(specId, 'MISSING', `text mismatch: "${actual}" does not contain "${expectedText}"`);
					return;
				}
				if((expectation.mode === 'nonempty' || expectation.mode === 'exact' || expectation.mode === 'contains') && actual === '')
				{
					record(specId, 'MISSING', 'rendered empty text');
					return;
				}
				record(specId, 'FOUND', expectation.mode === 'presence' ? '' : `text verified (${expectation.mode})`);
			}
			catch
			{
				record(specId, 'MISSING', 'not visible in the expected state');
			}
		}

		// The tab strip is rendered by lightning-tabset away from the annotated <lightning-tab>,
		// so a tab id is proven by BOTH: the annotated element exists, and a tab with the shipped
		// label is on screen.
		async function checkTab(specId)
		{
			const unknownLabel = unknownLabelNote(EXPECTATIONS[specId], labelValues);
			if(unknownLabel)
			{
				record(specId, 'MISSING', unknownLabel);
				return;
			}
			const expectedLabel = labelValues[EXPECTATIONS[specId].label];
			try
			{
				await spec(specId).first().waitFor({state: 'attached', timeout: 15_000});
				const tab = root().getByRole('tab', {name: expectedLabel, exact: true}).first();
				await tab.waitFor({state: 'visible', timeout: 15_000});
				record(specId, 'FOUND', `tab header "${expectedLabel}" verified`);
			}
			catch
			{
				record(specId, 'MISSING', `no tab header matching the shipped label "${expectedLabel}"`);
			}
		}

		// The datatable owns its own header markup, so the column SET is the round-trip: every
		// shipped column label the prototype froze must be on screen in the annotated table.
		async function checkColumns(specId, expectedColumns)
		{
			try
			{
				await spec(specId).first().waitFor({state: 'visible', timeout: 15_000});
				const headerText = await spec(specId).first().locator('thead').first().innerText();
				const missing = expectedColumns.filter((column) => !headerText.includes(column));
				record(specId, missing.length === 0 ? 'FOUND' : 'MISSING',
						missing.length === 0 ? `column set verified (${expectedColumns.length} columns)` : `columns absent: ${missing.join(', ')}`);
			}
			catch
			{
				record(specId, 'MISSING', 'the annotated list table never rendered');
			}
		}

		// The Details grid is a key/value grid; the round-trip is that every shipped key label the
		// prototype froze is rendered inside the annotated grid.
		async function checkMetagrid(specId)
		{
			const keys = [
				'LogConsole_MetaLogNumber',
				'LogConsole_MetaSource',
				'LogConsole_MetaContext',
				'LogConsole_MetaUser',
				'LogConsole_MetaCorrelation',
				'LogConsole_MetaTransaction',
				'LogConsole_MetaParentTransaction'
			].map((labelName) => labelValues[labelName]);
			try
			{
				await spec(specId).first().waitFor({state: 'visible', timeout: 15_000});
				const gridText = await spec(specId).first().innerText();
				const missing = keys.filter((key) => !gridText.includes(key));
				record(specId, missing.length === 0 ? 'FOUND' : 'MISSING',
						missing.length === 0 ? `all ${keys.length} detail rows verified` : `rows absent: ${missing.join(', ')}`);
			}
			catch
			{
				record(specId, 'MISSING', 'the annotated details grid never rendered');
			}
		}

		async function checkState(state)
		{
			for(const [specId, expectation] of Object.entries(EXPECTATIONS))
			{
				if(expectation.state !== state)
				{
					continue;
				}
				if(expectation.mode === 'tab')
				{
					await checkTab(specId);
				}
				else if(expectation.mode === 'metagrid')
				{
					await checkMetagrid(specId);
				}
				else if(expectation.mode === 'columns')
				{
					await checkColumns(specId, [
						labelValues.LogConsole_ColLogNumber,
						labelValues.LogConsole_ColLevel,
						labelValues.LogConsole_ColProblem,
						labelValues.LogConsole_ColSource,
						labelValues.LogConsole_ColContext,
						labelValues.LogConsole_ColCount,
						labelValues.LogConsole_ColLastSeen
					]);
				}
				else
				{
					await check(specId);
				}
			}
		}

		async function openFirstRowFor(term, view)
		{
			await logConsole.navigate();
			if(view === 'entries')
			{
				await logConsole.switchView('entries');
			}
			await logConsole.search(term);
			expect(await logConsole.getRowCount(), `the ${term} fixture should list at least one row`).toBeGreaterThan(0);
			await logConsole.selectRow(0);
			await logConsole.detailPanel().waitFor({state: 'visible', timeout: 30_000});
		}

		// ---- state 1: the console shell, default problem-summary view -------------------------
		await logConsole.navigate();
		await checkState('console');

		// ---- state 2: the custom date range ---------------------------------------------------
		await logConsole.selectDateRange(labelValues.LogConsole_RangeCustom);
		await checkState('customRange');
		await logConsole.selectDateRange(labelValues.LogConsole_Range24h);

		// ---- state 3: the drawer on a grouped problem -----------------------------------------
		// Each tab is its own state: lightning-tabset hides the panes it is not showing, so an id
		// may only be judged while its own tab is active.
		await openFirstRowFor(RECURRING_MESSAGE, 'problems');
		await checkState('problemDrawer');
		await logConsole.openDrawerTab(labelValues.LogConsole_TabStackTrace);
		await checkState('problemStack');
		await logConsole.openDrawerTab(labelValues.LogConsole_TabContext);
		await checkState('problemContext');
		await logConsole.openDrawerTab(labelValues.LogConsole_TabTimeline);
		await checkState('problemTimeline');

		// ---- state 4: the drawer on the correlated, chain-registered trace ---------------------
		await openFirstRowFor(TRACE_TERMINAL_MESSAGE, 'entries');
		await checkState('traceOverview');
		await logConsole.openDrawerTab(labelValues.LogConsole_TabStackTrace);
		await checkState('traceStack');
		await logConsole.openDrawerTab(labelValues.LogConsole_TabContext);
		await checkState('traceContext');
		await logConsole.openDrawerTab(labelValues.LogConsole_TabTimeline);
		// Focusing a hop that is not the opened entry exercises the on-demand focus load, which is
		// the interaction the timeline prototype froze.
		const otherHop = spec('timeline-entry').filter({hasText: 'Spec parity trace reserve'}).first();
		if(await otherHop.isVisible().catch(() => false))
		{
			await otherHop.click();
			await page.waitForTimeout(FOCUS_LOAD_SETTLE_MS);
		}
		await checkState('traceTimeline');

		// ---- state 5: the drawer on the capped trace ------------------------------------------
		await openFirstRowFor(CAP_HOP_MESSAGE, 'entries');
		await logConsole.openDrawerTab(labelValues.LogConsole_TabTimeline);
		await checkState('capTimeline');

		// ---- copy drift: the prototype's own frozen copy against the shipped label -------------
		for(const [specId, expectation] of Object.entries(EXPECTATIONS))
		{
			const frozenText = prototypeCopy[specId];
			if(!expectation.label || frozenText === undefined)
			{
				continue;
			}
			const shipped = labelValues[expectation.label];
			if(normaliseCopy(frozenText) !== normaliseCopy(shipped))
			{
				copyDrift.push(`${specId}: prototype "${normaliseCopy(frozenText)}" vs shipped "${shipped}"`);
			}
		}

		// ---- report ---------------------------------------------------------------------------
		const lines = [
			'',
			'Log Console gap-finder — frozen data-spec-id round-trip',
			'======================================================='
		];
		const missing = [];
		for(const specId of frozen.ids)
		{
			const result = results.get(specId) ?? {status: 'MISSING', note: 'no check implemented for this id'};
			if(result.status === 'MISSING')
			{
				missing.push(`${specId} (${result.note})`);
			}
			lines.push(`${result.status.padEnd(REPORT_STATUS_COLUMN_WIDTH)} ${specId.padEnd(REPORT_ID_COLUMN_WIDTH)} ${result.note}`);
		}
		lines.push('');
		lines.push(`${frozen.ids.length - missing.length}/${frozen.ids.length} ids verified against instance ${getInstanceUrl()}`);
		lines.push(`deferred (skipped by design): ${frozen.deferred.length} element(s) — ${[...new Set(frozen.deferred)].join(', ')}`);
		lines.push(copyDrift.length === 0 ? 'copy drift: none' : `copy drift (non-fatal, ${copyDrift.length}):`);
		copyDrift.forEach((drift) => lines.push(`  ${drift}`));
		// eslint-disable-next-line no-console -- the gap-finder's whole output is this report
		process.stdout.write(`${lines.join('\n')}\n`);

		expect(missing, `spec ids that did not round-trip into the deployed console:\n  ${missing.join('\n  ')}`).toEqual([]);
	});
});
