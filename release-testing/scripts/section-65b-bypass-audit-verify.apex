// =============================================================================
// Section 65b: Framework-Wide Bypass Audit — Verify
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
//
// Verification half of the section-65 launch + verify split. Section 65
// exercised the four global bypass surfaces and persisted a `kern__Foobar__c`
// handoff row carrying the verification window start + the emitting user.
//
// This script reads the handoff, polls `kern__LogEntry__c` for the BypassEvent
// rows the launch emitted, then asserts:
//   65a — trigger-object surface emission (object-qualified key
//         `trigger-object|Account`, unchanged target shape)
//   65b — query surface: object-qualified target `system-mode:Account` with
//         `object` context naming the queried object (operation=query asserted
//         only on a fresh detail row — see ROLLUP CONTEXT)
//   65c — query surface: object-qualified target `sharing:Account`
//   65d — dml surface: object-qualified target `system-mode:Account`; when this
//         window holds a fresh `detail:bypass:` row for the key, additionally
//         asserts operation=insert + submitted rowCount=1 (rollup-only windows
//         relax to target/object presence — see ROLLUP CONTEXT)
//   65e — validation surface emission (object-qualified key
//         `validation|object:Account`, unchanged target shape)
//   65g — flood control: `detail:bypass:` / `rollup:bypass:` fingerprint rows
//
// POLL BUDGET: 60s nominal, effectively bounded by the 8000ms CPU-spin guard
// (~4 intervals); the runner's 30s pre-wait absorbs normal platform-event
// delivery latency, so the in-script poll only covers the tail.
//
// ROLLUP CONTEXT: all anonymous Apex resolves to caller `AnonymousBlock`, so
// bypass fingerprints collide ACROSS suite sections (e.g. section 35g emits the
// same `dml|system-mode:Account` identity earlier in a full Phase 2 run). A
// flood-control rollup bump keeps the FIRST occurrence's context, so a
// rollup-only window must not assert operation/rowCount — those values belong
// to whichever emission created the rollup row. The `detailKeys` set tracks
// which surface|target keys landed a fresh detail row in THIS window; only
// those get the full operation-context assertion. Target/object presence is
// asserted either way — the object-qualified fingerprint itself is the
// qualified-target contract, and a `system-mode:Account` rollup can only ever
// have been created by an object-qualified emission.
//
// Window scoping uses LastModifiedDate, not CreatedDate: under flood control a
// re-run in the same org increments the existing rollup rows (bumping
// LastModifiedDate) rather than inserting fresh detail rows. Emitting-user
// scoping uses kern__UserId__c, NOT CreatedById: persisted log rows are
// CreatedBy the Automated Process user (platform-event trigger) — section-50b
// FRAMEWORK FINDING A37.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-65b-bypass-audit-verify.apex
// Prerequisites: section-65 launched in this org within the last few minutes,
//   with >= ~10-30s elapsed for platform-event delivery. NOTE: this verify
//   CONSUMES the handoff row — after a failed verify, re-launch section-65
//   before retrying.
// =============================================================================

final Integer POLL_BUDGET_MS = 60000;
final Integer POLL_INTERVAL_MS = 2000;

try
{
	List<kern__Foobar__c> handoffRows =
	[
			SELECT Id,
					Name,
					kern__TextAreaLong__c
			FROM kern__Foobar__c
			WHERE Name LIKE 'Section65BypassAudit_%'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	if(handoffRows.isEmpty())
	{
		System.debug('FAIL: 65b-verify — no Section65BypassAudit_% handoff row found; was section-65 launched first?');
	}
	else
	{
		Map<String, Object> handoff = (Map<String, Object>)JSON.deserializeUntyped(handoffRows[0].kern__TextAreaLong__c);
		Datetime windowStart = Datetime.newInstance(Long.valueOf(String.valueOf(handoff.get('windowStartMs'))));
		String launchUserId = (String)handoff.get('launchUserId');

		Map<String, Map<String, Object>> contextBySurfaceAndTarget = new Map<String, Map<String, Object>>();
		Set<String> detailKeys = new Set<String>();
		Integer auditCount = 0;
		Integer detailRows = 0;
		Integer rollupRows = 0;

		// Poll until every expected shape persists (PE delivery latency) or budget elapses.
		Long pollStartMs = System.currentTimeMillis();
		Long pollElapsedMs = 0;
		Boolean allLanded = false;
		while(pollElapsedMs < POLL_BUDGET_MS && !allLanded)
		{
			contextBySurfaceAndTarget = new Map<String, Map<String, Object>>();
			detailKeys = new Set<String>();
			auditCount = 0;
			detailRows = 0;
			rollupRows = 0;

			// Long-Text fields like ContextData__c cannot be filtered with SOQL LIKE —
			// pull the window and classify in Apex.
			for(kern__LogEntry__c entry :
			[
					SELECT kern__ContextData__c,
							kern__Fingerprint__c
					FROM kern__LogEntry__c
					WHERE LastModifiedDate >= :windowStart
					AND kern__UserId__c = :launchUserId
					ORDER BY LastModifiedDate DESC
					LIMIT 500
			])
			{
				if(String.isBlank(entry.kern__ContextData__c))
				{
					continue;
				}
				Map<String, Object> envelope = (Map<String, Object>)JSON.deserializeUntyped(entry.kern__ContextData__c);
				Map<String, Object> context = (Map<String, Object>)envelope.get('contextData');
				if(context == null || !'BypassEvent'.equals(context.get('category')))
				{
					continue;
				}
				auditCount++;
				Boolean isDetailRow = entry.kern__Fingerprint__c != null
						&& entry.kern__Fingerprint__c.startsWith('detail:bypass:');
				if(isDetailRow)
				{
					detailRows++;
				}
				if(entry.kern__Fingerprint__c != null && entry.kern__Fingerprint__c.startsWith('rollup:bypass:'))
				{
					rollupRows++;
				}
				String surface = (String)context.get('surface');
				if(String.isBlank(surface))
				{
					continue;
				}
				String key = surface + '|' + (String)context.get('target');
				if(isDetailRow)
				{
					detailKeys.add(key);
				}
				// Iteration is LastModifiedDate DESC — keep the FIRST (newest) context
				// seen per key; an unconditional put would let the OLDEST row in the
				// window win and assert stale context.
				if(!contextBySurfaceAndTarget.containsKey(key))
				{
					contextBySurfaceAndTarget.put(key, context);
				}
			}

			allLanded = contextBySurfaceAndTarget.containsKey('trigger-object|Account')
					&& contextBySurfaceAndTarget.containsKey('validation|object:Account')
					&& contextBySurfaceAndTarget.containsKey('query|system-mode:Account')
					&& contextBySurfaceAndTarget.containsKey('query|sharing:Account')
					&& contextBySurfaceAndTarget.containsKey('dml|system-mode:Account')
					&& (detailRows > 0 || rollupRows > 0);
			if(allLanded)
			{
				break;
			}

			Long spinUntilMs = System.currentTimeMillis() + POLL_INTERVAL_MS;
			while(System.currentTimeMillis() < spinUntilMs && Limits.getCpuTime() < 8000)
			{
				Math.sqrt(2.0);
			}
			pollElapsedMs = System.currentTimeMillis() - pollStartMs;
			if(Limits.getCpuTime() >= 8000)
			{
				break;
			}
		}

		System.debug('Section 65b: polled ' + pollElapsedMs + 'ms; ' + auditCount + ' bypass audit entries in window'
				+ ' (' + detailRows + ' detail, ' + rollupRows + ' rollup); fresh detail keys: ' + detailKeys);

		// Test 65a: trigger-surface emission landed with its object target — keying on
		// surface|target (not surface alone) so the launch preamble's CLEAR_ALL
		// emissions cannot mask a missing Account-targeted emission.
		if(contextBySurfaceAndTarget.containsKey('trigger-object|Account'))
		{
			System.debug('PASS: 65a — trigger-object surface emission landed (target Account)');
		}
		else
		{
			System.debug('FAIL: 65a — missing trigger-object surface emission for target Account');
		}

		// Test 65b: the system-mode query entry is object-qualified — target names the
		// queried object and the context names the object, so an admin can tell WHICH
		// read ran under the bypass rather than only that "a query somewhere" did.
		// operation=query is asserted only on a fresh detail row (ROLLUP CONTEXT above).
		Map<String, Object> systemModeQuery = contextBySurfaceAndTarget.get('query|system-mode:Account');
		Boolean systemModeQueryLanded = systemModeQuery != null
				&& 'Account'.equals(systemModeQuery.get('object'));
		if(systemModeQueryLanded && detailKeys.contains('query|system-mode:Account'))
		{
			if('query'.equals(systemModeQuery.get('operation')))
			{
				System.debug('PASS: 65b — system-mode query audit is object-qualified (system-mode:Account, operation=query, fresh detail row)');
			}
			else
			{
				System.debug('FAIL: 65b — fresh system-mode query detail row carries wrong operation: ' + systemModeQuery.get('operation'));
			}
		}
		else if(systemModeQueryLanded)
		{
			System.debug('PASS: 65b — system-mode query audit is object-qualified (system-mode:Account; rollup-only window, operation not asserted)');
		}
		else
		{
			System.debug('FAIL: 65b — missing object-qualified system-mode query audit entry');
		}

		// Test 65c: the sharing-bypass query entry carries the object-qualified target + object context
		Map<String, Object> sharingQuery = contextBySurfaceAndTarget.get('query|sharing:Account');
		if(sharingQuery != null && 'Account'.equals(sharingQuery.get('object')))
		{
			System.debug('PASS: 65c — sharing-bypass query audit is object-qualified (sharing:Account)');
		}
		else
		{
			System.debug('FAIL: 65c — missing object-qualified sharing-bypass query audit entry');
		}

		// Test 65d: the system-mode DML entry is object-qualified. The verb + submitted
		// row count (recorded at terminal time, before the DML outcome is known) are
		// asserted only when THIS window landed a fresh detail row for the key — a
		// rollup-only window carries the FIRST occurrence's context, which may belong
		// to an earlier same-fingerprint emission elsewhere in the suite (section 35g).
		Map<String, Object> systemModeDml = contextBySurfaceAndTarget.get('dml|system-mode:Account');
		Boolean systemModeDmlLanded = systemModeDml != null
				&& 'Account'.equals(systemModeDml.get('object'));
		if(systemModeDmlLanded && detailKeys.contains('dml|system-mode:Account'))
		{
			if('insert'.equals(systemModeDml.get('operation'))
					&& '1'.equals(String.valueOf(systemModeDml.get('rowCount'))))
			{
				System.debug('PASS: 65d — system-mode DML audit is object-qualified with verb and submitted row count (insert, 1 row, fresh detail row)');
			}
			else
			{
				System.debug('FAIL: 65d — fresh system-mode DML detail row carries wrong operation context (operation='
						+ systemModeDml.get('operation') + ', rowCount=' + systemModeDml.get('rowCount') + ')');
			}
		}
		else if(systemModeDmlLanded)
		{
			System.debug('PASS: 65d — system-mode DML audit is object-qualified (system-mode:Account; rollup-only window, operation/rowCount not asserted)');
		}
		else
		{
			System.debug('FAIL: 65d — missing object-qualified system-mode DML audit entry');
		}

		// Test 65e: validation-surface emission landed with its object target — same
		// surface|target keying rationale as 65a.
		if(contextBySurfaceAndTarget.containsKey('validation|object:Account'))
		{
			System.debug('PASS: 65e — validation surface emission landed (target object:Account)');
		}
		else
		{
			System.debug('FAIL: 65e — missing validation surface emission for target object:Account');
		}

		// Test 65g: Flood control — bypass audit rides the log-fingerprint grouping, so a
		// novel bypass identity persists as a `detail:bypass:` row and repeats roll up into
		// windowed `rollup:bypass:` counters instead of flooding the log table.
		if(detailRows > 0 || rollupRows > 0)
		{
			System.debug('PASS: 65g — flood control active (' + detailRows + ' detail, ' + rollupRows + ' rollup rows)');
		}
		else
		{
			System.debug('FAIL: 65g — no fingerprinted audit rows; flood control not wired');
		}
	}
}
catch(Exception scenarioError)
{
	System.debug('FAIL: 65b-verify — ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

// Cleanup — consume this run's handoff (plus any strays from this user) so
// re-runs read a fresh window. Non-fatal: a cleanup failure must not fail the
// verification result. Scoped to CreatedById so a concurrent run by another
// user keeps its own handoff.
try
{
	List<kern__Foobar__c> residualHandoff =
	[
			SELECT Id
			FROM kern__Foobar__c
			WHERE Name LIKE 'Section65BypassAudit_%'
			AND CreatedById = :UserInfo.getUserId()
			LIMIT 9000
	];
	if(!residualHandoff.isEmpty())
	{
		delete residualHandoff;
		System.debug('Cleanup: deleted ' + residualHandoff.size() + ' Section65BypassAudit_% handoff row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug('65b cleanup warning: ' + cleanupError.getMessage());
}

System.debug('Section 65b (verify): complete');
