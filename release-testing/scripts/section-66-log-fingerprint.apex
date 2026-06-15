// =============================================================================
// Section 66: Log-Fingerprint Flood Control — subscriber API (Launch)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
//
// Verifies the subscriber-facing flood-control feature shipped in 1.1: when a
// subscriber attaches a stable grouping key via the GLOBAL
// `kern.LOG_Builder.build()...withFingerprint(key)` API, repeated identical
// entries collapse at persist time into a single `detail:<key>` sample row plus
// a per-UTC-day `rollup:<key>:<yyyyMMdd>` counter (`OccurrenceCount__c`) instead
// of flooding `kern__LogEntry__c` with one row per occurrence.
//
// SCOPE vs section-65: section-65 proves the FRAMEWORK-internal consumer (bypass
// audit, which subscribers cannot call directly). THIS section proves the
// SUBSCRIBER-facing contract — the documented global `withFingerprint` API that
// a subscriber sprinkles through their own service / handler code.
//
// LAUNCH + VERIFY SPLIT (mirrors section-50 / section-34): `kern__LogEntry__c`
// rows are persisted asynchronously by the `LogEntryEvent__e` platform-event
// subscriber (`TRG_PersistLogEntry`), which does NOT run until THIS publishing
// transaction commits — i.e. after `sf apex run` exits. A single script cannot
// observe its own fingerprinted rows. This launch script publishes the events +
// persists a handoff row; section-66b reads the handoff ~30s later and asserts
// the persisted detail/rollup shape.
//
// RUN ISOLATION: every key carries a per-run stamp (currentTimeMillis) so
// concurrent or repeated runs never collide. The verify script + this script's
// keys are reconciled through a tagged `kern__Foobar__c` handoff row
// (Name='Section66Fingerprint_<runStamp>') carrying the raw keys, the run-stamped
// `ClassMethod__c` marker, the flood count, and the expected total row count.
//
// Run (two stages, ~30s apart for PE delivery):
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-66-log-fingerprint.apex
//   (wait ~10-60s for LogEntryEvent__e delivery + TRG_PersistLogEntry persistence)
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-66b-log-fingerprint-verify.apex
//
// Prerequisites (subscriber org defaults satisfy all):
//   - kern managed package 1.1+ installed (the build under test must contain the
//     withFingerprint API + kern__Fingerprint__c / kern__OccurrenceCount__c fields)
//   - kern__LogSetting__c.IsEnabled__c = true, LogLevelThreshold__c = DEBUG/INFO,
//     ClassFilter__c blank (so INFO entries pass the loggable allowlist)
//   - Platform-event daily quota headroom >= ~10
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

// Allow the framework's log entries to publish in the script context (mirrors
// section-65 / section-16). Without this the engine suppresses publication.
kern.LOG_Builder.ignoreTestMode = true;

final String RUN_STAMP = String.valueOf(System.currentTimeMillis());
final String MARKER_PREFIX = 'LOG_TestSection66_' + RUN_STAMP;
final String HANDOFF_NAME = 'Section66Fingerprint_' + RUN_STAMP;

// Stable per-run grouping keys (NOT per-occurrence data — the same key on every
// flood emit is the whole point; per-occurrence keys would defeat grouping).
final String FLOOD_KEY = 'kerntest-fp-' + RUN_STAMP + '-flood';
final String OTHER_KEY = 'kerntest-fp-' + RUN_STAMP + '-other';

// Oversized key (> 200 chars) — the framework SHA-256 hashes it and records the
// original under ContextData__c 'fingerprintSource' so it stays reconcilable.
String oversizedPadding = '';
for(Integer index = 0; index < 23; index++)
{
	oversizedPadding += '0123456789';
}
final String OVERSIZED_KEY = 'kerntest-fp-' + RUN_STAMP + '-' + oversizedPadding;

// Spoof key — a subscriber attempting to forge a framework `bypass:` audit
// fingerprint. The reserved prefix must be SHA-256 hashed (anti-spoofing) so no
// verbatim `detail:bypass:...` row from subscriber input is ever stored.
final String SPOOF_KEY = 'bypass:' + RUN_STAMP + '-spoof';

final Integer FLOOD_EMITS = 5;
// 4 fingerprinted keys -> 4 detail + 4 rollup rows; + 1 plain (no-fingerprint) row.
final Integer EXPECTED_TOTAL_ROWS = (4 * 2) + 1;

try
{
	// FLOOD: same key, 5 occurrences -> expect exactly 1 detail row + 1 rollup
	// row carrying OccurrenceCount__c = 5 (the flood-control headline).
	for(Integer index = 0; index < FLOOD_EMITS; index++)
	{
		kern.LOG_Builder.build()
				.info('Section66 flood occurrence ' + index)
				.withFingerprint(FLOOD_KEY)
				.emitAt(MARKER_PREFIX + '.flood');
	}

	// DISTINCT: a different key -> its own detail + rollup, OccurrenceCount__c = 1.
	kern.LOG_Builder.build()
			.info('Section66 distinct key')
			.withFingerprint(OTHER_KEY)
			.emitAt(MARKER_PREFIX + '.other');

	// OVERSIZED: > 200 chars -> hashed fingerprint + 'fingerprintSource' breadcrumb.
	kern.LOG_Builder.build()
			.info('Section66 oversized key')
			.withFingerprint(OVERSIZED_KEY)
			.emitAt(MARKER_PREFIX + '.oversized');

	// SPOOF: reserved 'bypass:' prefix from a subscriber -> hashed (anti-spoofing).
	kern.LOG_Builder.build()
			.info('Section66 reserved-prefix spoof attempt')
			.withFingerprint(SPOOF_KEY)
			.emitAt(MARKER_PREFIX + '.spoof');

	// PLAIN: no fingerprint -> ordinary row with blank Fingerprint__c. Regression
	// guard that fingerprinting is opt-in and does not alter normal logging.
	kern.LOG_Builder.build()
			.info('Section66 plain entry (no fingerprint)')
			.emitAt(MARKER_PREFIX + '.plain');

	System.debug('PASS: 66-launch-emit — ' + (FLOOD_EMITS + 3)
			+ ' fingerprinted + 1 plain entries published without governor breach (marker='
			+ MARKER_PREFIX + ')');

	Map<String, Object> handoff = new Map<String, Object>
	{
			'runStamp' => RUN_STAMP,
			'markerPrefix' => MARKER_PREFIX,
			'floodKey' => FLOOD_KEY,
			'otherKey' => OTHER_KEY,
			'oversizedKey' => OVERSIZED_KEY,
			'spoofKey' => SPOOF_KEY,
			'floodEmits' => FLOOD_EMITS,
			'expectedTotalRows' => EXPECTED_TOTAL_ROWS,
			'launchUserId' => UserInfo.getUserId(),
			'launchCompletedAtMs' => System.currentTimeMillis()
	};

	kern__Foobar__c handoffRow = new kern__Foobar__c
			(
					Name = HANDOFF_NAME,
					kern__TextAreaLong__c = JSON.serialize(handoff)
			);
	insert handoffRow;

	System.debug('PASS: 66-launch-handoff — handoff row persisted (' + HANDOFF_NAME
			+ '). Run section-66b after ~10-60s for persistence verification.');
}
catch(Exception scenarioError)
{
	System.debug('FAIL: 66-launch — ' + scenarioError.getMessage() + '\n'
			+ scenarioError.getStackTraceString());
}

System.debug('Section 66 (Launch): complete');
