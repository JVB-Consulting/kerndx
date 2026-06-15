// =============================================================================
// Section 66b: Log-Fingerprint Flood Control — subscriber API (Verify)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
//
// Verification half of the section-66 launch + verify split. Section 66 published
// (via the global `kern.LOG_Builder...withFingerprint` API):
//   - 5 identical FLOOD_KEY entries  -> expect 1 detail + 1 rollup (count 5)
//   - 1 OTHER_KEY entry              -> expect 1 detail + 1 rollup (count 1)
//   - 1 OVERSIZED_KEY (>200 chars)   -> expect hashed fingerprint + breadcrumb
//   - 1 SPOOF_KEY ('bypass:' prefix) -> expect hashed (NO verbatim detail:bypass:)
//   - 1 PLAIN entry (no fingerprint) -> expect ordinary row, blank Fingerprint__c
// and persisted a `kern__Foobar__c` handoff row carrying the raw keys + the
// run-stamped `ClassMethod__c` marker + the flood count + expected total rows.
//
// This script reads the handoff, polls `kern__LogEntry__c` for the expected rows
// (scoped by the run-stamped marker + emitting user + TODAY), asserts the
// detail/rollup flood-control shape, then deletes its rows + handoff. Poll
// budget: 60s nominal, effectively bounded by the 8000ms CPU-spin guard (~4
// intervals); the runner's 30s pre-wait absorbs normal delivery latency.
//
// Emitting-user scoping uses kern__UserId__c, NOT CreatedById: persisted log rows
// are CreatedBy the Automated Process user (platform-event trigger), while the
// emitting user is captured into kern__UserId__c (see section-50b FRAMEWORK
// FINDING A37).
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-66b-log-fingerprint-verify.apex
// Prerequisites: section-66 launched in this org within the last few minutes,
//   with >= ~10-30s elapsed for platform-event delivery.
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

final Integer POLL_BUDGET_MS = 60000;
final Integer POLL_INTERVAL_MS = 2000;

String markerPattern = '';
String launchUserId = null;

try
{
	List<kern__Foobar__c> handoffRows =
	[
			SELECT Id,
					Name,
					kern__TextAreaLong__c
			FROM kern__Foobar__c
			WHERE Name LIKE 'Section66Fingerprint_%'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	if(handoffRows.isEmpty())
	{
		System.debug('FAIL: 66b — no Section66Fingerprint_% handoff row found; was section-66 launched first?');
	}
	else
	{
		Map<String, Object> handoff =
				(Map<String, Object>)JSON.deserializeUntyped(handoffRows[0].kern__TextAreaLong__c);

		String markerPrefix = (String)handoff.get('markerPrefix');
		String floodKey = (String)handoff.get('floodKey');
		String otherKey = (String)handoff.get('otherKey');
		String oversizedKey = (String)handoff.get('oversizedKey');
		String spoofKey = (String)handoff.get('spoofKey');
		Integer floodEmits = (Integer)handoff.get('floodEmits');
		Integer expectedTotalRows = (Integer)handoff.get('expectedTotalRows');
		launchUserId = (String)handoff.get('launchUserId');
		markerPattern = markerPrefix + '%';

		final String DETAIL_FLOOD = 'detail:' + floodKey;
		final String ROLLUP_FLOOD_PREFIX = 'rollup:' + floodKey + ':';
		final String DETAIL_OTHER = 'detail:' + otherKey;
		final String ROLLUP_OTHER_PREFIX = 'rollup:' + otherKey + ':';
		final String DETAIL_SPOOF_VERBATIM = 'detail:' + spoofKey;

		// Poll until all expected rows persist (PE delivery latency) or budget elapses.
		Long pollStartMs = System.currentTimeMillis();
		Long pollElapsedMs = 0;
		Integer persistedCount = 0;
		while(pollElapsedMs < POLL_BUDGET_MS && persistedCount < expectedTotalRows)
		{
			persistedCount =
			[
					SELECT COUNT()
					FROM kern__LogEntry__c
					WHERE kern__ClassMethod__c LIKE :markerPattern
					AND kern__UserId__c = :launchUserId
					AND CreatedDate = TODAY
			];
			if(persistedCount >= expectedTotalRows)
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

		System.debug('Section 66b: polled ' + pollElapsedMs + 'ms; persistedCount='
				+ persistedCount + '/' + expectedTotalRows + ' (marker=' + markerPrefix + ')');

		List<kern__LogEntry__c> rows =
		[
				SELECT kern__Fingerprint__c,
						kern__OccurrenceCount__c,
						kern__Message__c,
						kern__ClassMethod__c,
						kern__ContextData__c
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c LIKE :markerPattern
				AND kern__UserId__c = :launchUserId
				AND CreatedDate = TODAY
		];

		// Classify the run's rows in Apex (Fingerprint__c is an exact key; the
		// oversized/spoof keys are stored hashed so they are matched via context).
		List<kern__LogEntry__c> floodDetail = new List<kern__LogEntry__c>();
		List<kern__LogEntry__c> floodRollup = new List<kern__LogEntry__c>();
		List<kern__LogEntry__c> otherDetail = new List<kern__LogEntry__c>();
		List<kern__LogEntry__c> otherRollup = new List<kern__LogEntry__c>();
		Integer spoofVerbatimCount = 0;
		Integer plainCount = 0;
		kern__LogEntry__c oversizedRow = null;

		for(kern__LogEntry__c row : rows)
		{
			String fingerprint = row.kern__Fingerprint__c;
			if(String.isBlank(fingerprint))
			{
				plainCount++;
				continue;
			}
			if(fingerprint == DETAIL_FLOOD)
			{
				floodDetail.add(row);
			}
			else if(fingerprint.startsWith(ROLLUP_FLOOD_PREFIX))
			{
				floodRollup.add(row);
			}
			else if(fingerprint == DETAIL_OTHER)
			{
				otherDetail.add(row);
			}
			else if(fingerprint.startsWith(ROLLUP_OTHER_PREFIX))
			{
				otherRollup.add(row);
			}
			if(fingerprint == DETAIL_SPOOF_VERBATIM)
			{
				spoofVerbatimCount++;
			}
			// Oversized: stored fingerprint is the SHA-256 hash; reconcile via the
			// 'fingerprintSource' breadcrumb in the ContextData envelope.
			if(String.isNotBlank(row.kern__ContextData__c) && fingerprint.startsWith('detail:'))
			{
				Object envelopeObject = JSON.deserializeUntyped(row.kern__ContextData__c);
				if(envelopeObject instanceof Map<String, Object>)
				{
					Object contextObject = ((Map<String, Object>)envelopeObject).get('contextData');
					if(contextObject instanceof Map<String, Object>
							&& oversizedKey.equals(((Map<String, Object>)contextObject).get('fingerprintSource')))
					{
						oversizedRow = row;
					}
				}
			}
		}

		// 66b-a: flood presence invariant — 5 occurrences -> exactly 1 detail row.
		if(floodDetail.size() == 1)
		{
			System.debug('PASS: 66b-a — 5 identical fingerprints collapsed to a single detail row');
		}
		else
		{
			System.debug('FAIL: 66b-a — expected 1 detail row for flood key, got ' + floodDetail.size());
		}

		// 66b-b: rollup occurrence count — single rollup row carries the total (5).
		if(floodRollup.size() == 1 && floodRollup[0].kern__OccurrenceCount__c == floodEmits)
		{
			System.debug('PASS: 66b-b — rollup OccurrenceCount__c = ' + floodEmits + ' (5 occurrences rolled into 1 counter)');
		}
		else
		{
			String observedCount = floodRollup.isEmpty() ? 'n/a' : String.valueOf(floodRollup[0].kern__OccurrenceCount__c);
			System.debug('FAIL: 66b-b — expected 1 rollup row with OccurrenceCount__c=' + floodEmits
					+ ', got ' + floodRollup.size() + ' rollup row(s), count=' + observedCount);
		}

		// 66b-c: detail rows carry no count (OccurrenceCount__c lives only on rollups).
		if(floodDetail.size() == 1 && floodDetail[0].kern__OccurrenceCount__c == null)
		{
			System.debug('PASS: 66b-c — detail row carries null OccurrenceCount__c (count lives on the rollup row)');
		}
		else
		{
			System.debug('FAIL: 66b-c — detail row OccurrenceCount__c expected null; floodDetail.size()='
					+ floodDetail.size());
		}

		// 66b-d: flood-control economy — 5 would-be rows reduced to exactly 2.
		Integer floodRowTotal = floodDetail.size() + floodRollup.size();
		if(floodDetail.size() == 1 && floodRollup.size() == 1 && floodRowTotal == 2)
		{
			System.debug('PASS: 66b-d — flood control reduced ' + floodEmits
					+ ' occurrences to ' + floodRowTotal + ' rows (1 detail + 1 rollup)');
		}
		else
		{
			System.debug('FAIL: 66b-d — expected 2 rows (1 detail + 1 rollup) for ' + floodEmits
					+ ' flood emits, got ' + floodRowTotal);
		}

		// 66b-e: distinct key -> its own detail + rollup, OccurrenceCount__c = 1.
		Boolean otherShape = otherDetail.size() == 1
				&& otherRollup.size() == 1
				&& otherRollup[0].kern__OccurrenceCount__c == 1;
		if(otherShape)
		{
			System.debug('PASS: 66b-e — distinct fingerprint produced its own detail + rollup (OccurrenceCount__c = 1)');
		}
		else
		{
			System.debug('FAIL: 66b-e — distinct key shape wrong: detail=' + otherDetail.size()
					+ ' rollup=' + otherRollup.size());
		}

		// 66b-f: oversized key -> hashed fingerprint + reconcilable breadcrumb.
		Boolean oversizedHashed = oversizedRow != null
				&& oversizedRow.kern__Fingerprint__c != ('detail:' + oversizedKey);
		if(oversizedHashed)
		{
			System.debug('PASS: 66b-f — oversized key stored hashed (' + oversizedRow.kern__Fingerprint__c
					+ ') and reconcilable via fingerprintSource breadcrumb');
		}
		else
		{
			System.debug('FAIL: 66b-f — oversized key not hashed/reconcilable; breadcrumb row '
					+ (oversizedRow == null ? 'not found' : 'matched verbatim'));
		}

		// 66b-g: anti-spoofing — reserved-prefix subscriber key is hashed, never stored verbatim.
		if(spoofVerbatimCount == 0)
		{
			System.debug('PASS: 66b-g — reserved-prefix subscriber key hashed; no verbatim detail:bypass: row stored');
		}
		else
		{
			System.debug('FAIL: 66b-g — found ' + spoofVerbatimCount
					+ ' verbatim detail:bypass: row(s) from subscriber input (spoofing not prevented)');
		}

		// 66b-h: regression — plain (un-fingerprinted) entry persists with blank Fingerprint__c.
		if(plainCount >= 1)
		{
			System.debug('PASS: 66b-h — plain entry persisted with blank Fingerprint__c (fingerprinting is opt-in)');
		}
		else
		{
			System.debug('FAIL: 66b-h — plain entry not found; normal logging regressed');
		}
	}
}
catch(Exception scenarioError)
{
	System.debug('FAIL: 66b — ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

// Cleanup — delete this run's log rows (marker scope catches detail, rollup, and
// hashed rows alike since buildRow copies ClassMethod__c onto every row) + the
// handoff. Non-fatal: a cleanup failure must not fail the verification result.
try
{
	if(String.isNotBlank(markerPattern) && launchUserId != null)
	{
		List<kern__LogEntry__c> residualRows =
		[
				SELECT Id
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c LIKE :markerPattern
				AND kern__UserId__c = :launchUserId
				AND CreatedDate = TODAY
				LIMIT 9000
		];
		if(!residualRows.isEmpty())
		{
			delete residualRows;
			System.debug('Cleanup: deleted ' + residualRows.size() + ' section-66 kern__LogEntry__c row(s)');
		}
	}

	List<kern__Foobar__c> residualHandoff =
	[
			SELECT Id
			FROM kern__Foobar__c
			WHERE Name LIKE 'Section66Fingerprint_%'
			AND CreatedDate = TODAY
			AND CreatedById = :UserInfo.getUserId()
			LIMIT 9000
	];
	if(!residualHandoff.isEmpty())
	{
		delete residualHandoff;
		System.debug('Cleanup: deleted ' + residualHandoff.size() + ' Section66Fingerprint_% handoff row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug('66b cleanup warning: ' + cleanupError.getMessage());
}

System.debug('Section 66b (Verify): complete');
