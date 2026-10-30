// SPDX-License-Identifier: Apache-2.0
// Chain Monitor mockup gap-finder (AGENTS.md lever 2): proves every data-spec-id frozen at the
// operator-actions mockup sign-off round-trips into the DEPLOYED Chain Monitor with matching visible text.
//
// Ids fall into three buckets:
//  - DOM ids: located as data-testid attributes across the page states that can render them
//    (a Failed restartable chain for the action group and stream, a fresh stalled seed for the
//    abort action and the stream empty state, the restart clone for the lineage link, the open
//    confirm modal for the modal trio).
//  - Copy-only ids (the mockup's P9 note): platform toasts and the not-reproducible disconnected
//    state are asserted by comparing the shipped Custom Label values byte-for-byte against the
//    mockup's frozen copy.
//  - Paired ids: suspend-action and resume-action render one at a time from the kill-switch
//    state; exactly one must be present.
//
// Run (after deploying the bundles): node gap-finder-chain-monitor.js
// Target org: SF_SUBSCRIBER_ORG_ALIAS (defaults to the release subscriber org).
const fs = require('fs');
const path = require('path');
const {chromium} = require('@playwright/test');
const ChainMonitorPage = require('./pages/chain-monitor.page');
const {executeAnonymousApex, runApexScript, soqlQuery} = require('./helpers/sf-cli');
const {namespacePrefix} = require('./helpers/sf-namespace');
const {waitForSpinnerGone} = require('./helpers/wait-helpers');
const {getInstanceUrl} = require('./helpers/sf-auth');
const {authPathsFor} = require('./helpers/auth-paths');
const {runShapedSeed} = require('./helpers/log-console-seed');
const {readShippedLabelValues} = require('./lib/shipped-labels');
const {chainMonitorIds} = require('./lib/whole-action-spec-ids');

// The validated operator-actions mockup is an internal design artifact that does not ship with the
// public repository; a checkout without it passes its own copy via GAP_FINDER_MOCKUP.
const MOCKUP_PATH = process.env.GAP_FINDER_MOCKUP || '';
// The whole-action prototype draws both consoles on one page; this gap-finder owns its monitor half,
// the Log Console gap-finder the rest, and lib/whole-action-spec-ids.js holds the split.
const WHOLE_ACTION_PROTOTYPE_PATH = process.env.GAP_FINDER_WHOLE_ACTION_PROTOTYPE
		|| path.join(__dirname, '..', '..', 'plans', 'superpowers', 'specs', '2026-09-07-log-console-whole-action-prototype.html');
if(!MOCKUP_PATH)
{
	console.error('Set GAP_FINDER_MOCKUP to the path of the operator-actions mockup: the mockup does not ship with the public repository.');
	process.exit(1);
}
const AUTH_STATE_PATH = authPathsFor().statePath;

// The action-scope state reads the whole-action runs the Log Console's shaped seed lays down: the
// checkout click, its three runs (one nested) and the nightly job's restart clone.
const SHAPED_TEARDOWN_SCRIPT = path.join(__dirname, '..', 'scripts', 'teardown-log-console.apex');
const ACTION_CHECKOUT = 'e2ee2ee2-0000-4000-8000-000000000a01';
const NESTED_RUN_NAME = 'E2E Checkout Ledger';

// Copy-only ids: the shipped label value must equal the mockup's frozen copy byte-for-byte.
// action-toast covers the five action-outcome toasts (the mockup's P9 note); the disconnected
// line's frozen copy lives in the mockup's static markup rather than its COPY map.
const ACTION_TOAST_LABELS = {
	ChainMonitor_RetrySuccessToast: 'retrySuccessToast',
	ChainMonitor_RestartSuccessToast: 'restartSuccessToast',
	ChainMonitor_ClearStalledResultToast: 'clearStalledResultToast',
	ChainMonitor_SuspendedToast: 'suspendedToast',
	ChainMonitor_ResumedToast: 'resumedToast'
};

function readFrozenSpecIds()
{
	const mockup = fs.readFileSync(MOCKUP_PATH, 'utf8');
	const mockupIds = [...mockup.matchAll(/data-spec-id="([^"]+)"/g)].map((match) => match[1]);
	return [...new Set([...mockupIds, ...chainMonitorIds(WHOLE_ACTION_PROTOTYPE_PATH)])].sort();
}

// The mockup's COPY map holds the frozen action copy; single-quoted values with escaped quotes.
function readMockupCopyValues()
{
	const mockup = fs.readFileSync(MOCKUP_PATH, 'utf8');
	const copyBlock = mockup.match(/const COPY = \{([\s\S]*?)\n\t\};/)[1];
	const values = {};
	for(const match of copyBlock.matchAll(/(\w+): '((?:[^'\\]|\\.)*)'/g))
	{
		values[match[1]] = match[2].replace(/\\'/g, '\'');
	}
	const disconnectedMatch = mockup.match(/data-spec-id="log-stream-disconnected">([^<]+)</);
	values.streamDisconnected = disconnectedMatch[1];
	return values;
}

function prefixed(apiName)
{
	return `${namespacePrefix()}${apiName}`;
}

async function seedStalledChain()
{
	const executionObject = prefixed('AsyncChainExecution__c');
	const namespaceClause = namespacePrefix() ? 'NamespacePrefix = \'kern\'' : 'NamespacePrefix = NULL';
	// The permission sets go in first, in their OWN transaction: PermissionSetAssignment is a setup object, so
	// assigning one and inserting a chain in the same transaction fails with MIXED_DML_OPERATION on any org where
	// the runner is not already assigned (a fresh scratch org is exactly that case).
	executeAnonymousApex(`
		List<PermissionSet> operatorSets = [SELECT Id FROM PermissionSet WHERE Name IN ('AsyncChainAbort', 'AsyncChainRedrive', 'AsyncChainKillSwitch') AND ${namespaceClause}];
		for(PermissionSet operatorSet : operatorSets)
		{
			if([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :operatorSet.Id] == 0)
			{
				insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = operatorSet.Id);
			}
		}
	`);
	const output = executeAnonymousApex(`
		${executionObject} stalled = new ${executionObject}(
				${prefixed('ChainName__c')} = 'GapFinder_StalledSeed',
				${prefixed('Status__c')} = 'Stalled',
				${prefixed('TotalSteps__c')} = 3,
				${prefixed('CompletedSteps__c')} = 1,
				${prefixed('StartedAt__c')} = Datetime.now().addMinutes(-10),
				${prefixed('CorrelationId__c')} = 'gap-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
		);
		insert stalled;
		System.debug('CHAIN_ID:' + stalled.Id);
	`);
	return output.match(/CHAIN_ID:([a-zA-Z0-9]{15,18})/)[1];
}

async function main()
{
	const specIds = readFrozenSpecIds();
	const labelValues = readShippedLabelValues();
	const found = new Map();
	const report = (specId, status, note = '') => found.set(specId, {status, note});

	// Copy-only bucket first — pure source-to-mockup byte comparison, no browser needed.
	const mockupCopy = readMockupCopyValues();
	const toastMismatches = Object.entries(ACTION_TOAST_LABELS)
	.filter(([labelName, mockupKey]) => mockupCopy[mockupKey] === undefined || labelValues[labelName] !== mockupCopy[mockupKey])
	.map(([labelName]) => labelName);
	report('action-toast', toastMismatches.length === 0 ? 'COPY-VERIFIED' : 'MISSING',
			toastMismatches.length === 0 ? '5 labels byte-equal to the mockup copy' : `label/mockup drift: ${toastMismatches.join(', ')}`);
	const disconnectedMatches = labelValues.ChainMonitor_LogStreamDisconnected === mockupCopy.streamDisconnected;
	report('log-stream-disconnected', disconnectedMatches ? 'COPY-VERIFIED' : 'MISSING',
			disconnectedMatches ? 'label byte-equal to the mockup copy' : 'label/mockup drift: ChainMonitor_LogStreamDisconnected');

	await seedStalledChain();
	// Throws, naming the script, when either part of the seed does not report its rows: the action-scope state would have no fixtures.
	runShapedSeed();
	const failedRows = soqlQuery(`SELECT Id FROM ${prefixed('AsyncChainExecution__c')} WHERE ${prefixed('ChainName__c')} = 'E2E_RestartLineage'`
			+ ` AND ${prefixed('SourceExecution__c')} = NULL ORDER BY CreatedDate DESC LIMIT 1`);
	const cloneRows = soqlQuery(`SELECT Id FROM ${prefixed('AsyncChainExecution__c')} WHERE ${prefixed('SourceExecution__c')} != NULL ORDER BY CreatedDate DESC LIMIT 1`);

	const browser = await chromium.launch({headless: true});
	const context = await browser.newContext({storageState: AUTH_STATE_PATH, viewport: {width: 1920, height: 1080}, timezoneId: 'America/Los_Angeles'});
	const page = await context.newPage();
	const monitor = new ChainMonitorPage(page);

	// expectedText: a string compares byte-for-byte; null demands any non-empty text (for
	// per-action dynamic copy); undefined checks presence only (for structural containers).
	async function checkDom(specId, locator, expectedText)
	{
		try
		{
			await locator.first().waitFor({state: 'visible', timeout: 10000});
			const actual = ((await locator.first().textContent()) || '').trim();
			if(typeof expectedText === 'string' && actual !== expectedText)
			{
				report(specId, 'MISSING', `text mismatch: expected "${expectedText}", got "${actual}"`);
				return;
			}
			if(expectedText === null && actual === '')
			{
				report(specId, 'MISSING', 'rendered empty text');
				return;
			}
			report(specId, 'FOUND', expectedText === undefined ? '' : (expectedText === null ? 'non-empty text' : 'text verified'));
		}
		catch
		{
			report(specId, 'MISSING', 'not visible in the expected state');
		}
	}

	// State 1: the Failed restartable source chain — action group, retry/restart, ops control, stream with history.
	await monitor.navigate();
	await monitor.selectRowByChainName('E2E_RestartLineage');
	await checkDom('operations-control', monitor.getOperationsControl());
	await checkDom('operations-state-badge', monitor.getOperationsBadge());
	await checkDom('clear-stalled-action', monitor.getClearStalledButton(), labelValues.ChainMonitor_ClearStalledAction);
	const suspendVisible = await monitor.getSuspendButton().isVisible().catch(() => false);
	const resumeVisible = await monitor.getResumeButton().isVisible().catch(() => false);
	const pairedStatus = suspendVisible !== resumeVisible ? 'FOUND' : 'MISSING';
	report('suspend-action', pairedStatus, suspendVisible ? 'suspend rendered' : 'resume rendered (paired id)');
	report('resume-action', pairedStatus, resumeVisible ? 'resume rendered' : 'suspend rendered (paired id)');
	await checkDom('detail-action-group', monitor.getActionGroup());
	await checkDom('retry-action', monitor.getRetryButton(), labelValues.ChainMonitor_RetryAction);
	await checkDom('restart-action', monitor.getRestartButton(), labelValues.ChainMonitor_RestartAction);
	await checkDom('log-stream-panel', monitor.getStreamPanel());
	await checkDom('log-stream-title', monitor.getStreamTitle(), labelValues.ChainMonitor_LogStreamTitle);

	// The modal trio: open the enabled restart confirm, verify, cancel.
	if(failedRows.length > 0)
	{
		await monitor.getRestartButton().click();
		await checkDom('action-modal-title', page.locator('[data-testid="action-modal-title"]'), null);
		await checkDom('action-modal-body', monitor.getModalBody(), null);
		await checkDom('action-modal-confirm', monitor.getConfirmButton(), labelValues.ChainMonitor_RestartConfirmButton);
		await checkDom('action-modal-cancel', monitor.getCancelButton(), labelValues.ChainMonitor_ActionCancelButton);
		await monitor.getCancelButton().click();
	}
	else
	{
		for(const modalId of ['action-modal-title', 'action-modal-body', 'action-modal-confirm', 'action-modal-cancel'])
		{
			report(modalId, 'MISSING', 'no Failed restartable chain available to open the modal');
		}
	}

	// State 1b: the correlated Failed chain V116/V121 leave behind — the stream body ids, expanded
	// past the P12 default collapse (a Failed chain collapses its stream so the error keeps focus).
	await monitor.navigate();
	await monitor.selectRowByChainName('E2E_StreamSeed');
	await monitor.getStreamTitle().click();
	await checkDom('log-stream-caveat', monitor.getStreamCaveat(), labelValues.ChainMonitor_LogStreamCaveat);
	await checkDom('log-stream-entry', monitor.getStreamEntries());
	await checkDom('stream-last-event', page.locator('[data-testid="stream-last-event"]'));

	// State 2: the restart clone, read through the Launched under link, which is what carries the
	// restart lineage on a clone. A clone and the run it was restarted from share a chain name, and the
	// unscoped list has no Launched under column to tell them apart, so the clone is picked by its
	// own row key (the datatable keys rows on the execution id) and confirmed by the link's restart
	// wording, the way V136 confirms the nightly clone.
	if(cloneRows.length > 0)
	{
		await monitor.navigate();
		const rowKeys = await monitor.getRowKeys();
		const cloneIndex = rowKeys.indexOf(cloneRows[0].Id);
		let lineageSeen = false;
		if(cloneIndex >= 0)
		{
			await monitor.selectRow(cloneIndex);
			const lineage = page.locator('[data-testid="launched-under-link"]').first();
			lineageSeen = (await lineage.isVisible().catch(() => false))
					&& /^restart of /.test(((await lineage.innerText().catch(() => '')) || '').trim());
		}
		const lineageDetail = cloneIndex < 0 ? 'the restart clone is not on the first page of the list'
				: 'the clone row did not read its restart lineage';
		report('restart-lineage-link', lineageSeen ? 'FOUND' : 'MISSING',
				lineageSeen ? 'the Launched under link reads the restart' : lineageDetail);
	}
	else
	{
		report('restart-lineage-link', 'MISSING', 'no restart clone exists to render the lineage');
	}

	// State 3: the fresh stalled seed — abort action (visible on a stalled chain) and stream empty state.
	await monitor.navigate();
	await monitor.selectRowByChainName('GapFinder_StalledSeed');
	await checkDom('abort-action', monitor.getAbortButton(), labelValues.ChainMonitor_AbortAction);
	await checkDom('log-stream-empty', monitor.getStreamEmpty(), labelValues.ChainMonitor_LogStreamEmpty);

	// State 4: the action scope, reached by the deep link the Log Console sends.
	const scopedUrl = `${getInstanceUrl()}/lightning/n/${prefixed('ChainMonitor')}`
			+ `?c__rootCorrelationId=${ACTION_CHECKOUT}&c__viewLogsAt=${Date.now()}`;
	await page.goto(scopedUrl, {waitUntil: 'domcontentloaded'});
	await page.waitForTimeout(5000);
	await waitForSpinnerGone(page);
	await checkDom('monitor-action-pill', monitor.getActionPill(), null);
	await checkDom('monitor-show-action-logs', monitor.getShowActionLogsButton(), labelValues.ChainMonitor_ShowActionLogsAction);
	const headers = await monitor.getColumnHeaders();
	report('monitor-col-launched-under', headers.includes(labelValues.ChainMonitor_LaunchedUnder) ? 'FOUND' : 'MISSING',
			headers.includes(labelValues.ChainMonitor_LaunchedUnder) ? 'column header verified' : 'no Launched under header while scoped');
	await monitor.selectRowByChainName(NESTED_RUN_NAME);
	await checkDom('detail-toolbar-row', monitor.getToolbarRow());
	await checkDom('timing-grid', page.locator('[data-spec-id="timing-grid"]'));
	await checkDom('launched-under-row', monitor.getLaunchedUnderRow(), null);
	await checkDom('monitor-detail-show-action-logs', monitor.getDetailShowActionLogsButton(), labelValues.ChainMonitor_ShowActionLogsAction);

	await browser.close();

	// Cleanup: the seeded stalled row must not linger for the next clear-stalled run, and the shaped
	// whole-action fixtures leave with the script that laid them down.
	executeAnonymousApex(`
		delete [SELECT Id FROM ${prefixed('AsyncChainExecution__c')} WHERE ${prefixed('ChainName__c')} = 'GapFinder_StalledSeed'];
	`);
	runApexScript(SHAPED_TEARDOWN_SCRIPT, {timeout: 300_000});

	let missingCount = 0;
	console.log('\nChain Monitor gap-finder — frozen data-spec-id round-trip');
	console.log('==========================================================');
	for(const specId of specIds)
	{
		const result = found.get(specId) ?? {status: 'MISSING', note: 'no check implemented for this id'};
		if(result.status === 'MISSING')
		{
			missingCount++;
		}
		console.log(`${result.status.padEnd(14)} ${specId.padEnd(28)} ${result.note}`);
	}
	console.log(`\n${specIds.length - missingCount}/${specIds.length} ids verified against instance ${getInstanceUrl()}`);
	process.exit(missingCount === 0 ? 0 : 1);
}

main().catch((error) =>
{
	console.error('Gap-finder aborted:', error);
	process.exit(1);
});
