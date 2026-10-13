// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const ApiIssuesPage = require('../pages/api-issues.page');
const StreamingMonitorPage = require('../pages/streaming-monitor.page');
const LoginFrequenciesPage = require('../pages/login-frequencies.page');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {ORG_ALIAS, getFrontdoorUrlFor, getInstanceUrl} = require('../helpers/sf-auth');
const {soqlQuery, executeAnonymousApex} = require('../helpers/sf-cli');
const {namespacePrefix, rewriteNamespaceLiterals} = require('../helpers/sf-namespace');
const {pollUntil} = require('../helpers/wait-helpers');
const {ELEMENT_WAIT_MILLISECONDS} = require('../helpers/wait-times');
const {cleanupStepRunner, submitNewPassword} = require('../helpers/user-journey');
const {execFileSync} = require('child_process');
const {randomUUID} = require('crypto');
const {env} = require('process');

// V158's outbound handler: a GET to a Named Credential that does not exist (release-testing/subscriber), so a retry
// fails at the send point and is scheduled again.
const RETRY_LIVE_SERVICE = 'API_RetryLiveGet';
// The opening of the RetryApiIssue_PermissionRequired label, mirrored: the toast a user without the permission sees.
const PERMISSION_REFUSAL_OPENING = 'You need the Retry API Issue permission';
const SEEDED_ISSUE_COUNT = 2;
// Log entries are written from a platform event after the request ends, so the cleanup waits for them to land.
const LOG_SETTLE_MILLISECONDS = 15_000;
// A new user's first sign-in, through frontdoor and the password change, takes longer than one element wait.
const SIGN_IN_WAIT_MILLISECONDS = 60_000;
// The retried call is saved once its callout has failed; the poll asks every few seconds for up to a minute.
const CALL_SAVED_WAIT_MILLISECONDS = 60_000;
const CALL_SAVED_POLL_MILLISECONDS = 3_000;
// Creating a user and reading the org through the CLI.
const SF_CLI_TIMEOUT_MILLISECONDS = 120_000;
// V158 signs a second user in, presses Retry twice and waits for log entries to land before its cleanup.
const V158_TIMEOUT_MILLISECONDS = 300_000;
// V159's service: the packaged example, a real POST to a public test API through the packaged credential, which answers
// 201; its setting allows retries. It sends a request made for a record, so every seeded issue names one. One real POST
// leaves the org per run; nothing is mocked.
const RETRY_SELECTED_SERVICE = 'API_PostExample';
const RETRY_SELECTED_ISSUE_COUNT = 3;
// The opening of the RetryApiIssues_Queued label, mirrored: two of the three are queued, the flagged one is not.
const RETRY_SELECTED_QUEUED_OPENING = `2 of ${RETRY_SELECTED_ISSUE_COUNT} selected API issues were queued`;
// The job runs in the background and sends its call after it; the poll asks every few seconds for up to two minutes.
const ISSUES_RESOLVED_WAIT_MILLISECONDS = 120_000;
// The flow modal opens after the action is chosen and the action has run.
const FLOW_MODAL_WAIT_MILLISECONDS = 60_000;
// V159 signs a second user in, runs the flow and waits for the job before its cleanup.
const V159_TIMEOUT_MILLISECONDS = 300_000;
// The subscriber's own set that grants Run Flows, deployed from release-testing/subscriber/permissionsets in Phase 1.4.
const RUN_FLOWS_PERMISSION_SET = 'SubscriberRunFlows';

// Object and field API names carry the package prefix only on the subscriber org.
function prefixed(apiName)
{
	return `${namespacePrefix()}${apiName}`;
}

// A query written with the package's literals, as the org needs it: the rewrite anonymous Apex already gets.
function forOrg(query)
{
	return rewriteNamespaceLiterals(query, namespacePrefix());
}

// A permission set query's namespace filter: the package's namespace on a subscriber org, none on the development org.
function namespaceClause(field = 'NamespacePrefix')
{
	const prefix = namespacePrefix();
	return prefix ? `${field} = '${prefix.slice(0, -2)}'` : `${field} = NULL`;
}

// One cleanup step, run whatever happened before it; a failure is reported and never hides the journey's own.
const runCleanupStep = cleanupStepRunner('part2');

// The calls of V158's service created since the journey started, by one user when an id is given, leaving out the
// call the journey seeded.
function retryLiveCalls(startedAt, createdById, seededCallId)
{
	const byUser = createdById ? ` AND CreatedById = '${createdById}'` : '';
	const notSeeded = seededCallId ? ` AND Id != '${seededCallId}'` : '';
	return soqlQuery(forOrg('SELECT Id, kern__Status__c, kern__NextRetry__c FROM kern__ApiCall__c '
			+ `WHERE kern__ServiceName__c = '${RETRY_LIVE_SERVICE}' AND CreatedDate >= ${startedAt}${byUser}${notSeeded}`));
}

// The log entries V158's service writes: its handler's, located by the service, and its circuit breaker's, which name
// the service in their message.
function retryLiveLogFilter(since)
{
	return `(kern__ClassMethod__c LIKE '%${RETRY_LIVE_SERVICE}%' OR kern__ShortMessage__c LIKE '%${RETRY_LIVE_SERVICE}%') AND ${since}`;
}

// Every row V158 leaves behind, counted: its seeded and created issues, its calls and the log entries they wrote.
function retryLiveRowsLeft(startedAt)
{
	const since = `CreatedDate >= ${startedAt}`;
	return soqlQuery(forOrg(`SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c = '${RETRY_LIVE_SERVICE}' AND ${since}`)).length
			+ retryLiveCalls(startedAt).length
			+ soqlQuery(forOrg(`SELECT Id FROM kern__LogEntry__c WHERE ${retryLiveLogFilter(since)}`)).length;
}

// Deletes V158's calls first, so no scheduled retry fires after the cleanup, then its issues and log entries.
function deleteRetryLiveRows(startedAt)
{
	const since = `CreatedDate >= ${startedAt}`;
	executeAnonymousApex(`delete [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = '${RETRY_LIVE_SERVICE}' AND ${since}];`
			+ ` delete [SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c = '${RETRY_LIVE_SERVICE}' AND ${since}];`
			+ ` delete [SELECT Id FROM kern__LogEntry__c WHERE ${retryLiveLogFilter(since)}];`);
}

// The calls of V159's service for one record created since the journey started, at one status when one is given.
function retrySelectedCalls(startedAt, recordId, status)
{
	const atStatus = status ? ` AND kern__Status__c = '${status}'` : '';
	return soqlQuery(forOrg(`SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE '%${RETRY_SELECTED_SERVICE}' `
			+ `AND kern__TriggeringRecordId__c = '${recordId}' AND CreatedDate >= ${startedAt}${atStatus}`));
}

// V159's rows only, never another journey's: the issues it seeded, the calls it saw the job complete, and the calls and
// issues of its service since it started that its resolver created or that name the resolver's record (the seeded call
// in progress). The packaged service is shared, so nothing wider is matched.
function retrySelectedFilter({startedAt, seededIssueIds, sentCallIds, resolverId})
{
	const quoted = (ids) => (ids.length ? ids.map((id) => `'${id}'`).join(',') : '\'\'');
	const service = `kern__ServiceName__c LIKE '%${RETRY_SELECTED_SERVICE}' AND CreatedDate >= ${startedAt}`;
	const byResolver = resolverId ? `(CreatedById = '${resolverId}' OR kern__TriggeringRecordId__c = '${resolverId}')` : 'Id = NULL';
	return {
		calls: `Id IN (${quoted(sentCallIds)}) OR (${service} AND ${byResolver})`,
		issues: `Id IN (${quoted(seededIssueIds)}) OR (${service} AND ${byResolver})`
	};
}

// Every row V159 leaves behind, counted.
function retrySelectedRowsLeft(rows)
{
	const filter = retrySelectedFilter(rows);
	return soqlQuery(forOrg(`SELECT Id FROM kern__ApiCall__c WHERE ${filter.calls}`)).length
			+ soqlQuery(forOrg(`SELECT Id FROM kern__ApiIssue__c WHERE ${filter.issues}`)).length;
}

// Deletes V159's calls, then its issues.
function deleteRetrySelectedRows(rows)
{
	const filter = retrySelectedFilter(rows);
	executeAnonymousApex(`delete [SELECT Id FROM kern__ApiCall__c WHERE ${filter.calls}];`
			+ ` delete [SELECT Id FROM kern__ApiIssue__c WHERE ${filter.issues}];`);
}

// Creates a Standard User holding Kern API Issue Resolver, plus the subscriber's own Run Flows set, and signs it in on a
// fresh context. The user's username, id and context are written to the holder as each exists, so the journey's cleanup
// reaches whatever was made before a failure. Users cannot be deleted, so the journey deactivates its user at the end.
async function signInNewResolver({browser, viewport, timezoneId, sfEnvironment, holder, journey})
{
	const created = JSON.parse(execFileSync('sf', ['org', 'create', 'user', '-o', ORG_ALIAS, 'profileName=Standard User', '--json'],
			{encoding: 'utf8', timeout: SF_CLI_TIMEOUT_MILLISECONDS, env: sfEnvironment}));
	holder.username = created.result.fields.username;
	holder.resolverId = created.result.fields.id;
	// Retry Selected is a flow, and the list offers it only to a user with the Run Flows permission. A managed package
	// cannot grant that permission through its own sets, so a subscriber grants it with a set of their own, as this
	// org does with SubscriberRunFlows (deployed in Phase 1.4).
	executeAnonymousApex(`User resolver = [SELECT Id FROM User WHERE Username = '${holder.username}' LIMIT 1];`
			+ ` PermissionSet resolving = [SELECT Id FROM PermissionSet WHERE Name = 'ApiIssueResolver' AND ${namespaceClause()} LIMIT 1];`
			+ ` PermissionSet runningFlows = [SELECT Id FROM PermissionSet WHERE Name = '${RUN_FLOWS_PERMISSION_SET}' AND NamespacePrefix = null LIMIT 1];`
			+ ' insert new List<PermissionSetAssignment> {new PermissionSetAssignment(AssigneeId = resolver.Id, PermissionSetId = resolving.Id),'
			+ ' new PermissionSetAssignment(AssigneeId = resolver.Id, PermissionSetId = runningFlows.Id)};');
	// An empty storage state, so no admin cookie on the Lightning domain outlives the resolver's sign-in.
	holder.context = await browser.newContext({viewport, timezoneId, storageState: {cookies: [], origins: []}});
	const resolverPage = await holder.context.newPage();
	// The harness re-signs a page in when its address looks signed out; this page must come back as the resolver.
	resolverPage.kernFrontdoorUrl = () => getFrontdoorUrlFor(holder.username);
	await resolverPage.goto(getFrontdoorUrlFor(holder.username), {waitUntil: 'domcontentloaded'});
	// A new user's first sign-in stops at Change Your Password; a random password and answer get past it, and neither is
	// needed again because the user is deactivated at the end.
	const changePassword = resolverPage.getByRole('button', {name: 'Change Password'});
	await Promise.race([
		resolverPage.waitForURL(/\/lightning\//, {timeout: SIGN_IN_WAIT_MILLISECONDS}),
		changePassword.waitFor({state: 'visible', timeout: SIGN_IN_WAIT_MILLISECONDS})
	]);
	if(await changePassword.isVisible())
	{
		await submitNewPassword(resolverPage, changePassword, `${journey}-${randomUUID()}-a1`);
		await resolverPage.waitForURL(/\/lightning\//, {timeout: SIGN_IN_WAIT_MILLISECONDS});
	}
	return resolverPage;
}

// Removes the resolver's two assignments, deactivates the user and closes its context; each step runs whatever the one
// before it did. A user row cannot be deleted, so it is deactivated after its assignments are removed.
async function retireResolver(holder)
{
	await runCleanupStep(() => holder.resolverId && executeAnonymousApex('delete [SELECT Id FROM PermissionSetAssignment '
			+ `WHERE AssigneeId = '${holder.resolverId}' AND PermissionSet.Name IN ('ApiIssueResolver', '${RUN_FLOWS_PERMISSION_SET}')];`));
	await runCleanupStep(() => holder.username
			&& executeAnonymousApex(`update new User(Id = [SELECT Id FROM User WHERE Username = '${holder.username}' LIMIT 1].Id, IsActive = false);`));
	await runCleanupStep(() => holder.context?.close());
}

// Presses Retry on one issue and checks the answer is the service's own, never the permission refusal, and that the
// retried call failed at the unreachable credential and was scheduled again.
async function retryIssueAndExpectAScheduledCall(issuesPage, {issueId, startedAt, userId, seededCallId, who})
{
	await issuesPage.openRecordById(issueId);
	const highlights = issuesPage.page.locator('records-lwc-highlights-panel, records-highlights2').first();
	await expect(highlights.getByText('External System May Have Acted').first(), `${who} sees External System May Have Acted in the highlights`)
			.toBeVisible({timeout: ELEMENT_WAIT_MILLISECONDS});
	await expect(highlights.getByText('Status', {exact: true}).first(), `${who} sees Status beside it`).toBeVisible();
	await issuesPage.clickRetry();
	const toastText = await issuesPage.readToast();
	expect(toastText, `${who}'s Retry is answered by the service, not refused for the permission`).not.toContain(PERMISSION_REFUSAL_OPENING);
	const calls = await pollUntil(issuesPage.page, () =>
	{
		const found = retryLiveCalls(startedAt, userId, seededCallId);
		return found.length > 0 ? found : null;
	}, {timeout: CALL_SAVED_WAIT_MILLISECONDS, interval: CALL_SAVED_POLL_MILLISECONDS, message: `${who}'s Retry saved a call`});
	expect(calls.length, `${who}'s Retry made one call`).toBe(1);
	expect(calls[0][prefixed('Status__c')], `${who}'s retried GET is scheduled again`).toBe('Retry');
	expect(calls[0][prefixed('NextRetry__c')], `${who}'s scheduled call carries a time`).toBeTruthy();
}

test.describe.serial('Part 2: API Results, Config & Login', () =>
{
	test('V6: Verify Echo Call Results', async({page}) =>
	{
		const records = soqlQuery('SELECT Id, kern__ServiceName__c, kern__Status__c FROM kern__ApiCall__c ORDER BY CreatedDate DESC LIMIT 1');
		expect(records.length, 'Should have API Call records').toBeGreaterThan(0);

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__ApiCall__c/${records[0].Id}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);

		await expect(page.getByText('Service Name')).toBeVisible({timeout: ELEMENT_WAIT_MILLISECONDS});
		await expect(page.getByText('Status', {exact: true})).toBeVisible();
		await expect(page.getByText('Direction')).toBeVisible();
	});

	test('V7: API Issues', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const apiIssues = new ApiIssuesPage(page);
		await apiIssues.navigate();

		const loads = await apiIssues.listViewLoads();
		expect(loads, 'API Issues list view should load').toBeTruthy();

		if(await apiIssues.hasRecords())
		{
			await apiIssues.openFirstRecord();
		}
	});

	test('V158: A user holding Kern API Issue Resolver opens an API issue, sees External System May Have Acted beside Status and presses Retry; an administrator keeps Retry',
		async({page, browser, viewport, timezoneId}) =>
		{
			test.setTimeout(V158_TIMEOUT_MILLISECONDS);
			const startedAt = new Date(Date.now() - 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');
			// The same colour-free environment the harness gives every sf call it parses (helpers/sf-cli.js).
			const sfEnvironment = {...env, FORCE_COLOR: '0', NO_COLOR: '1'};
			const holder = {};
			try
			{
				// The first issue links a failed call the administrator owns: the resolver opens it, which only the set's
				// View All Records on API Calls allows (the object is Private).
				const hashStem = randomUUID().replace(/-/g, '').slice(0, 20);
				executeAnonymousApex(`kern__ApiCall__c seededCall = new kern__ApiCall__c(kern__ServiceName__c = '${RETRY_LIVE_SERVICE}', kern__Direction__c = 'Outbound',`
						+ ' kern__Status__c = \'Failed\'); insert seededCall;'
						+ ` List<kern__ApiIssue__c> issues = new List<kern__ApiIssue__c>(); for(Integer index = 0; index < ${SEEDED_ISSUE_COUNT}; index++)`
						+ ` { issues.add(new kern__ApiIssue__c(kern__ServiceName__c = '${RETRY_LIVE_SERVICE}', kern__Status__c = 'Open', kern__Direction__c = 'Outbound',`
						+ ` kern__RequestParametersHash__c = '${hashStem}' + index, kern__ApiCall__c = index == 0 ? seededCall.Id : null)); } insert issues;`);
				const seeded = soqlQuery(forOrg('SELECT Id, kern__ApiCall__c FROM kern__ApiIssue__c '
						+ `WHERE kern__ServiceName__c = '${RETRY_LIVE_SERVICE}' AND CreatedDate >= ${startedAt} ORDER BY kern__ApiCall__c NULLS LAST, Id`));
				expect(seeded.length, 'two Open issues were seeded').toBe(SEEDED_ISSUE_COUNT);
				const seededCallId = seeded[0][prefixed('ApiCall__c')];
				expect(seededCallId, 'the first issue links the seeded call').toBeTruthy();

				// A Standard User who holds this one set and nothing else from the package; a scratch org's licences are few,
				// so a failed run must not leave one active.
				const resolverPage = await signInNewResolver({browser, viewport, timezoneId, sfEnvironment, holder, journey: 'V158'});
				const resolverIssues = new ApiIssuesPage(resolverPage);
				await retryIssueAndExpectAScheduledCall(resolverIssues,
						{issueId: seeded[0].Id, startedAt, userId: holder.resolverId, seededCallId, who: 'the resolver'});

				// The issue's call, owned by the administrator, opens for the resolver: its record page shows the service.
				await resolverIssues.openRecordById(seededCallId);
				await expect(resolverPage.getByText(RETRY_LIVE_SERVICE).first(), 'the resolver can open the issue\'s API call').toBeVisible({timeout: ELEMENT_WAIT_MILLISECONDS});

				// The administrator half names the grant it relies on first: the Kern Administrator set, which Phase 1
				// assigns on the subscriber org and the harness user holds on the development org. A fresh admins-only
				// install grants Retry through the profile instead; only the owed upgrade-leg check reads that path.
				const adminUsername = JSON.parse(execFileSync('sf', ['org', 'display', '-o', ORG_ALIAS, '--json'],
						{encoding: 'utf8', timeout: SF_CLI_TIMEOUT_MILLISECONDS, env: sfEnvironment})).result.username;
				const adminAssignment = soqlQuery(`SELECT Id, AssigneeId FROM PermissionSetAssignment WHERE Assignee.Username = '${adminUsername}' `
						+ `AND PermissionSet.Name = 'Administrator' AND ${namespaceClause('PermissionSet.NamespacePrefix')}`);
				if(adminAssignment.length === 0)
				{
					test.info().annotations.push({type: 'administrator-half', description: 'Skipped: the e2e administrator holds no Kern Administrator set'});
				}
				else
				{
					await navigateToApp(page, 'Kern');
					await retryIssueAndExpectAScheduledCall(new ApiIssuesPage(page),
							{issueId: seeded[1].Id, startedAt, userId: adminAssignment[0].AssigneeId, seededCallId, who: 'the administrator'});
				}
			}
			finally
			{
				// Each step runs whatever the one before it did, and none hides the journey's own failure. The user goes
				// first: an active one costs a licence.
				await retireResolver(holder);
				// The breaker is reset before the deletes, because the reset writes a log entry of its own.
				await runCleanupStep(() => executeAnonymousApex(`kern.UTIL_CircuitBreaker.monitor('${RETRY_LIVE_SERVICE}').reset();`));
				await runCleanupStep(() => deleteRetryLiveRows(startedAt));
				await runCleanupStep(() => new Promise((resolve) => setTimeout(resolve, LOG_SETTLE_MILLISECONDS)));
				await runCleanupStep(() => deleteRetryLiveRows(startedAt));
			}
			expect(retryLiveRowsLeft(startedAt), 'no issue, call or log entry of the journey is left').toBe(0);
		});

	test('V159: A user holding Kern API Issue Resolver and Run Flows selects three API issues on the list, presses Retry Selected, '
			+ 'reads the queued message and sees one resolve while two stay open',
		async({browser, viewport, timezoneId}) =>
		{
			test.setTimeout(V159_TIMEOUT_MILLISECONDS);
			const startedAt = new Date(Date.now() - 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');
			// The same colour-free environment the harness gives every sf call it parses (helpers/sf-cli.js).
			const sfEnvironment = {...env, FORCE_COLOR: '0', NO_COLOR: '1'};
			const holder = {};
			const seededIssueIds = [];
			const sentCallIds = [];
			try
			{
				// The resolver first: its user id is the record of the issue whose record has a call in progress.
				const resolverPage = await signInNewResolver({browser, viewport, timezoneId, sfEnvironment, holder, journey: 'V159'});

				// Three open issues of the packaged service, each for its own request: one unflagged for the administrator's
				// user record (sent and resolved), one flagged as possibly acted on (not queued), and one for the resolver's
				// user record, which has a call at Processing (queued, then skipped by the job).
				const hashStem = randomUUID().replace(/-/g, '').slice(0, 20);
				const parameters = `new kern.DTO_NameValues(new Map<String, String> {'foo' => 'V159-${hashStem}'}).serialize()`;
				// The service name as the engine keys it: the runtime type name, kern.API_PostExample on the subscriber org.
				executeAnonymousApex(`String serviceName = kern.UTIL_System.getTypeForClassName('${RETRY_SELECTED_SERVICE}').getName();`
						+ ' insert new kern__ApiCall__c(kern__ServiceName__c = serviceName, kern__Direction__c = \'Outbound\','
						+ ` kern__Status__c = 'Processing', kern__TriggeringRecordId__c = '${holder.resolverId}');`
						+ ` String parameters = ${parameters}; List<kern__ApiIssue__c> issues = new List<kern__ApiIssue__c>();`
						+ ` for(Integer index = 0; index < ${RETRY_SELECTED_ISSUE_COUNT}; index++) { issues.add(new kern__ApiIssue__c(`
						+ 'kern__ServiceName__c = serviceName, kern__Status__c = \'Open\', kern__Direction__c = \'Outbound\','
						+ ` kern__RequestParameters__c = parameters, kern__RequestParametersHash__c = '${hashStem}' + index,`
						+ ` kern__ExternalSystemMayHaveActed__c = index == 1, kern__TriggeringRecordId__c = index == 2 ? '${holder.resolverId}' : (String)UserInfo.getUserId())); }`
						+ ' insert issues;');
				const seeded = soqlQuery(forOrg('SELECT Id, Name, kern__TriggeringRecordId__c FROM kern__ApiIssue__c '
						+ `WHERE kern__RequestParametersHash__c LIKE '${hashStem}%' ORDER BY kern__RequestParametersHash__c`));
				seededIssueIds.push(...seeded.map((issue) => issue.Id));
				expect(seeded.length, 'three Open issues were seeded').toBe(RETRY_SELECTED_ISSUE_COUNT);
				const [sentIssue, flaggedIssue, openCallIssue] = seeded;
				const allIssuesView = soqlQuery(`SELECT Id FROM ListView WHERE SobjectType = '${prefixed('ApiIssue__c')}' AND DeveloperName = 'All'`);
				expect(allIssuesView.length, 'the API Issues All list view exists').toBe(1);

				await resolverPage.goto(`${getInstanceUrl()}/lightning/o/${prefixed('ApiIssue__c')}/list?filterName=${allIssuesView[0].Id}`,
						{waitUntil: 'domcontentloaded'});
				await waitForPageLoad(resolverPage);
				// Other journeys may leave issues on the list, so the list is searched for the service and each seeded row
				// is selected by its number once the search shows all three.
				const resolverIssues = new ApiIssuesPage(resolverPage);
				await resolverIssues.searchListUntilRowsShow(RETRY_SELECTED_SERVICE, seeded.map((issue) => issue.Name));
				for(const issue of seeded)
				{
					await resolverIssues.selectRow(issue.Name);
				}
				for(const issue of seeded)
				{
					await resolverIssues.expectRowSelected(issue.Name);
				}

				// The action sits in the list's overflow menu once rows are selected.
				let retrySelected = resolverPage.getByRole('button', {name: 'Retry Selected'});
				if(await retrySelected.count() === 0)
				{
					await resolverPage.getByRole('button', {name: /Show more actions|Show \d+ more actions/}).first().click();
					retrySelected = resolverPage.getByRole('menuitem', {name: 'Retry Selected'});
				}
				await expect(retrySelected.first(), 'Retry Selected is offered once rows are selected').toBeVisible({timeout: ELEMENT_WAIT_MILLISECONDS});
				await retrySelected.first().click();
				const modal = resolverPage.getByRole('dialog').filter({hasText: 'Retry Selected'});
				await expect(modal.getByText(RETRY_SELECTED_QUEUED_OPENING), 'the screen says two of the three were queued, the flagged one not')
						.toBeVisible({timeout: FLOW_MODAL_WAIT_MILLISECONDS});
				await modal.getByRole('button', {name: 'Finish'}).click();

				// The job sends one real POST, for the unflagged issue, and resolves it once the call completes.
				const sentRecordId = sentIssue[prefixed('TriggeringRecordId__c')];
				await pollUntil(resolverPage, () =>
				{
					const resolved = soqlQuery(forOrg(`SELECT Id FROM kern__ApiIssue__c WHERE Id = '${sentIssue.Id}' AND kern__Status__c = 'Resolved'`));
					return resolved.length === 1 && retrySelectedCalls(startedAt, sentRecordId, 'Completed').length > 0;
				}, {timeout: ISSUES_RESOLVED_WAIT_MILLISECONDS, interval: CALL_SAVED_POLL_MILLISECONDS, message: 'the unflagged issue reads Resolved beside a Completed call'});
				const sentCalls = retrySelectedCalls(startedAt, sentRecordId, 'Completed');
				sentCallIds.push(...sentCalls.map((call) => call.Id));
				expect(sentCalls.length, 'one call was sent and completed for the issue\'s record').toBe(1);
				const stillOpen = soqlQuery(forOrg(`SELECT Id FROM kern__ApiIssue__c WHERE Id IN ('${flaggedIssue.Id}', '${openCallIssue.Id}') AND kern__Status__c = 'Open'`));
				expect(stillOpen.length, 'the flagged issue and the issue whose record has a call in progress stay Open').toBe(2);
			}
			finally
			{
				// Each step runs whatever the one before it did, and none hides the journey's own failure. The user goes
				// first: an active one costs a licence.
				await retireResolver(holder);
				await runCleanupStep(() => deleteRetrySelectedRows({startedAt, seededIssueIds, sentCallIds, resolverId: holder.resolverId}));
			}
			expect(retrySelectedRowsLeft({startedAt, seededIssueIds, sentCallIds, resolverId: holder.resolverId}), 'no issue or call of the journey is left').toBe(0);
		});

	test('V8: Streaming Event Monitor UI', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		const hasControls = await monitor.hasInteractiveControls();
		expect(hasControls, 'Monitor should have sidebar and main content area').toBeTruthy();
	});

	test('V9: CMDT Configuration', async() =>
	{
		const expectedTypes = [
			{name: 'TriggerSetting__mdt', label: 'Trigger Setting'},
			{name: 'TriggerAction__mdt', label: 'Trigger Action'},
			{name: 'FeatureFlag__mdt', label: 'Feature Flag'},
			{name: 'ValidationRule__mdt', label: 'Validation Rule'}
		];

		for(const type of expectedTypes)
		{
			const records = soqlQuery(`SELECT Id, DeveloperName
                                       FROM kern__${type.name} LIMIT 5`);
			expect(records.length, `${type.label} should have CMDT records`).toBeGreaterThan(0);
			test.info().annotations.push({type: 'notes', description: `${type.label}: ${records.length} records`});
		}
	});

	test('V10: Login Frequencies', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const loginFreq = new LoginFrequenciesPage(page);
		await loginFreq.navigate();

		const loads = await loginFreq.listViewLoads();
		expect(loads, 'Login Frequencies list view should load without error').toBeTruthy();
	});
});
