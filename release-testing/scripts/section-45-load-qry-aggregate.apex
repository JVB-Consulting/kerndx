/**
 * Section 45 (extended-load Phase 2): Load Test — QRY_Builder aggregate cardinality
 *
 * Stresses kern.QRY_Builder.toAggregateList() with high-cardinality groupBy on a
 * Text field, plus .rollup() and a 2-axis .cube() variant. Returns AggregateRow
 * wrappers and verifies the wrapper's get/getInteger accessors at scale.
 *
 * SPEC vs ACTUAL — cardinality field choice:
 *   Spec assumed groupBy on kern__Picklist__c. Pre-flight survey found:
 *   1) kern__Picklist__c is restricted to 3 values (Hot/Warm/Cold) — too few for the
 *      "1,000 distinct values" target.
 *   2) kern__NumberInteger__c (Number(3,0)) is NOT a groupable SOQL field (
 *      `field 'kern__NumberInteger__c' can not be grouped in a query call`).
 *   3) kern__Text__c (Text(255)) IS groupable and supports unbounded distinct values.
 *   Adopted: Text__c as the high-cardinality groupBy axis with 1,000 distinct synthetic
 *   values (e.g. 'Bucket-0042-<runStamp>').
 *
 * SPEC vs ACTUAL — count() overload:
 *   Spec showed `.count(Foobar__c.Id)`. Framework only exposes
 *   `Builder count(String fieldName)` (+ no-arg terminal `Integer count()`). Used
 *   `.count('Id')` (matches section-15j and section-53g pattern). Resulting alias
 *   is 'count_Id'. The unaliased `.grouping(field)` produces SELECT GROUPING() and
 *   Salesforce auto-aliases as 'expr0' (per Task 1.2 / section-53g finding,
 *   commit 2e641db). See pending tracker item #14 (SObjectField overloads on
 *   AggregateRow + Builder.count) which will add token-based variants in a future PR.
 *
 * SPEC vs ACTUAL — cube axes / row limit:
 *   Spec mentioned cube on `Picklist__c × Checkbox__c (or RecordType.Name)`. With the
 *   1,000-distinct primary axis, a `cube(1000 × 2)` query would exceed the 2,000 SOQL
 *   aggregate row limit (1,000 + 1,000 axis-A subtotals + 2 axis-B subtotals + 1 grand
 *   total = ~2,003). To keep a meaningful 2-axis cube while staying within the limit,
 *   the cube test runs on a separate axis pair: kern__Picklist__c (3) × kern__Checkbox__c (2)
 *   over the same 5,000-record dataset (each record carries cycled Picklist + Checkbox
 *   values). Expected cube cardinality = 6 leaves + 3 picklist subtotals + 2 checkbox
 *   subtotals + 1 grand total = 12 rows (verified empirically in pre-flight).
 *
 * BEHAVIOUR ASSERTIONS (hard gate):
 *   - Plain groupBy returns exactly DISTINCT_TEXT_VALUES rows (1000)
 *   - Rollup returns DISTINCT_TEXT_VALUES + 1 rows (1001) — exactly one row with grouping flag = 1
 *   - Rollup grand-total row's count_Id equals BATCH_TOTAL (5000)
 *   - Cube returns expected 12 rows (3*2 leaves + 3 picklist subtotals + 2 checkbox subtotals + 1 grand)
 *   - Cube grand-total (both axes null) row's count_Id equals BATCH_TOTAL (5000)
 *   - Every AggregateRow.getInteger('count_Id') and (where applicable) getInteger('expr0')
 *     accessor returns non-null
 *
 * PERF METRICS (soft gate, harvested by Phase 2.6):
 *   wallMs, cpuMs, soqlCount, heapBytesPeak, rowsReturned, allocationsApprox
 *   — emitted as PERF_ROW: lines (one System.debug per metric)
 *
 * Run-isolation: self-contained. All inserted Foobar__c rows are deleted in cleanup
 * (filtered by Name LIKE the run-stamped tag).
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - kern__Foobar__c trigger has no configured TriggerAction__mdt (verified — empty),
 *     so dispatcher fires but does no per-record work; pure DML cost only
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-45-load-qry-aggregate.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <30 seconds (5,000 DML inserts in 5 batches, 3 aggregate queries,
 * 1 bulk delete bounded at 9,000 rows).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 45 (extended-load Phase 2): Load Test — QRY_Builder aggregate cardinality ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP = String.valueOf(Datetime.now().getTime());
final String NAME_TAG = 'LoadAggregate45-' + RUN_STAMP;
final Integer BATCH_TOTAL = 5000;
final Integer DISTINCT_TEXT_VALUES = 1000;
final Integer RECORDS_PER_BATCH = 1000;
final Integer BATCH_COUNT = 5;
final List<String> PICKLIST_VALUES = new List<String> {'Hot', 'Warm', 'Cold'};

// Build the 1,000 distinct text bucket values once and reuse across all 5 batches.
List<Object> textBucketValues = new List<Object>();
for(Integer index = 0; index < DISTINCT_TEXT_VALUES; index++)
{
	textBucketValues.add('Bucket-' + String.valueOf(index).leftPad(4, '0') + '-' + RUN_STAMP);
}
Assert.areEqual(DISTINCT_TEXT_VALUES, textBucketValues.size(), 'Setup invariant: bucket-value list must have ' + DISTINCT_TEXT_VALUES + ' entries');

// Insert BATCH_TOTAL records in BATCH_COUNT batches of RECORDS_PER_BATCH each.
// Each batch cycles all 1,000 text bucket values exactly once. Across 5 batches each
// bucket receives exactly 5 records. Picklist + Checkbox cycle independently to give
// the cube test natural 2-axis distribution.
List<Object> picklistCycle = new List<Object> {(Object)PICKLIST_VALUES[0], (Object)PICKLIST_VALUES[1], (Object)PICKLIST_VALUES[2]};
List<Object> checkboxCycle = new List<Object> {(Object)true, (Object)false};

try
{
	for(Integer batchIndex = 0; batchIndex < BATCH_COUNT; batchIndex++)
	{
		Object batchObj = kern.TST_Builder.of(kern__Foobar__c.SObjectType)
				.withCount(RECORDS_PER_BATCH)
				.withCycle(kern__Foobar__c.kern__Text__c, textBucketValues)
				.withCycle(kern__Foobar__c.kern__Picklist__c, picklistCycle)
				.withCycle(kern__Foobar__c.kern__Checkbox__c, checkboxCycle)
				.withOverride(kern__Foobar__c.Name, NAME_TAG)
				.buildList();
		List<SObject> batchRecords = (List<SObject>)batchObj;
		Assert.areEqual(RECORDS_PER_BATCH, batchRecords.size(), 'Setup invariant: batch ' + batchIndex + ' must have inserted ' + RECORDS_PER_BATCH + ' records');
	}

	Integer persistedCount =
	[
			SELECT COUNT()
			FROM kern__Foobar__c
			WHERE Name = :NAME_TAG
	];
	Assert.areEqual(BATCH_TOTAL, persistedCount, 'Setup invariant: ' + BATCH_TOTAL + ' Foobar__c records must be persisted before measurement. Got: ' + persistedCount);
}
catch(Exception setupError)
{
	System.debug(LoggingLevel.ERROR, '45 SETUP FAIL: ' + setupError.getMessage() + '\n' + setupError.getStackTraceString());
	throw setupError;
}

// Capture pre-run governor baselines (measurement window covers all 3 aggregate queries).
Long startWallMs = System.currentTimeMillis();
Long startCpuMs = Limits.getCpuTime();
Integer startSoqlCount = Limits.getQueries();
Long startHeapBytes = Limits.getHeapSize();

try
{
	// Query 1 — plain high-cardinality groupBy on Text__c
	List<kern.QRY_Builder.AggregateRow> plainRows = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.condition(kern__Foobar__c.Name).equals(NAME_TAG)
			.groupBy(kern__Foobar__c.kern__Text__c)
			.count('Id')
			.toAggregateList();

	Assert.areEqual(DISTINCT_TEXT_VALUES, plainRows.size(),
			'45-Q1: plain groupBy on Text__c (1000 distinct values × 5 records each) must return exactly '
			+ DISTINCT_TEXT_VALUES + ' rows. Got: ' + plainRows.size());

	Integer plainTotalCount = 0;
	for(kern.QRY_Builder.AggregateRow row : plainRows)
	{
		Integer rowCount = row.getInteger('count_Id');
		Assert.isNotNull(rowCount, '45-Q1: every AggregateRow.getInteger(count_Id) must return non-null');
		plainTotalCount += rowCount;
	}
	Assert.areEqual(BATCH_TOTAL, plainTotalCount,
			'45-Q1: sum of count_Id across all groups must equal total inserted (' + BATCH_TOTAL + '). Got: ' + plainTotalCount);

	// Query 2 — rollup on Text__c with grouping flag for grand-total detection
	List<kern.QRY_Builder.AggregateRow> rollupRows = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.condition(kern__Foobar__c.Name).equals(NAME_TAG)
			.groupBy(kern__Foobar__c.kern__Text__c)
			.grouping(kern__Foobar__c.kern__Text__c)
			.count('Id')
			.rollup()
			.toAggregateList();

	Assert.areEqual(DISTINCT_TEXT_VALUES + 1, rollupRows.size(),
			'45-Q2: ROLLUP must add exactly 1 grand-total row to the data rows. Expected '
			+ (DISTINCT_TEXT_VALUES + 1) + '. Got: ' + rollupRows.size());

	Integer rollupSubtotalRowCount = 0;
	Integer rollupGrandTotalCount = 0;
	Integer rollupDataRowCount = 0;
	for(kern.QRY_Builder.AggregateRow row : rollupRows)
	{
		Integer groupingFlag = row.getInteger('expr0');
		Assert.isNotNull(groupingFlag, '45-Q2: every rollup row must expose a non-null expr0 (grouping flag)');
		Integer rowCount = row.getInteger('count_Id');
		Assert.isNotNull(rowCount, '45-Q2: every rollup row must expose a non-null count_Id');
		if(groupingFlag == 1)
		{
			rollupSubtotalRowCount++;
			rollupGrandTotalCount = rowCount;
		}
		else
		{
			rollupDataRowCount++;
		}
	}
	Assert.areEqual(1, rollupSubtotalRowCount, '45-Q2: ROLLUP must emit exactly 1 subtotal row (grand total) with expr0=1');
	Assert.areEqual(DISTINCT_TEXT_VALUES, rollupDataRowCount, '45-Q2: ROLLUP must emit ' + DISTINCT_TEXT_VALUES + ' data rows with expr0=0');
	Assert.areEqual(BATCH_TOTAL, rollupGrandTotalCount, '45-Q2: ROLLUP grand-total count_Id must equal ' + BATCH_TOTAL + '. Got: ' + rollupGrandTotalCount);

	// Query 3 — cube on Picklist × Checkbox (small-axis pair to stay under the 2,000 row aggregate limit)
	List<kern.QRY_Builder.AggregateRow> cubeRows = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.condition(kern__Foobar__c.Name).equals(NAME_TAG)
			.groupBy(kern__Foobar__c.kern__Picklist__c)
			.groupBy(kern__Foobar__c.kern__Checkbox__c)
			.count('Id')
			.cube()
			.toAggregateList();

	// Expected: 3 × 2 = 6 leaves (Hot/Warm/Cold × true/false), 3 picklist subtotals, 2 checkbox subtotals, 1 grand total = 12 rows
	final Integer EXPECTED_CUBE_ROWS = 12;
	Assert.areEqual(EXPECTED_CUBE_ROWS, cubeRows.size(),
			'45-Q3: CUBE on Picklist (3 vals) × Checkbox (2 vals) must return exactly '
			+ EXPECTED_CUBE_ROWS + ' rows (6 leaves + 3 + 2 + 1). Got: ' + cubeRows.size());

	Integer leafCellCount = 0;
	Integer leafSum = 0;
	Integer picklistSubtotalCount = 0;
	Integer checkboxSubtotalCount = 0;
	Integer cubeGrandTotal = 0;
	Boolean foundCubeGrandTotal = false;
	for(kern.QRY_Builder.AggregateRow row : cubeRows)
	{
		Object picklistValue = row.get('kern__Picklist__c');
		Object checkboxValue = row.get('kern__Checkbox__c');
		Integer rowCount = row.getInteger('count_Id');
		Assert.isNotNull(rowCount, '45-Q3: every cube row must expose a non-null count_Id');
		if(picklistValue == null && checkboxValue == null)
		{
			foundCubeGrandTotal = true;
			cubeGrandTotal = rowCount;
		}
		else if(picklistValue != null && checkboxValue == null)
		{
			picklistSubtotalCount++;
		}
		else if(picklistValue == null && checkboxValue != null)
		{
			checkboxSubtotalCount++;
		}
		else
		{
			leafCellCount++;
			leafSum += rowCount;
		}
	}
	Assert.areEqual(6, leafCellCount, '45-Q3: CUBE must emit 6 leaf cells (Picklist × Checkbox combinations)');
	Assert.areEqual(3, picklistSubtotalCount, '45-Q3: CUBE must emit 3 picklist subtotal rows (Hot/Warm/Cold totals)');
	Assert.areEqual(2, checkboxSubtotalCount, '45-Q3: CUBE must emit 2 checkbox subtotal rows (true/false totals)');
	Assert.isTrue(foundCubeGrandTotal, '45-Q3: CUBE must emit a grand total row (both axes null)');
	Assert.areEqual(BATCH_TOTAL, cubeGrandTotal, '45-Q3: CUBE grand total count_Id must equal ' + BATCH_TOTAL + '. Got: ' + cubeGrandTotal);
	Assert.areEqual(BATCH_TOTAL, leafSum, '45-Q3: sum of cube leaf cells must equal ' + BATCH_TOTAL + '. Got: ' + leafSum);

	// Capture post-run governor metrics
	Long wallMs = System.currentTimeMillis() - startWallMs;
	Long cpuMs = Limits.getCpuTime() - startCpuMs;
	Integer soqlCount = Limits.getQueries() - startSoqlCount;
	Long heapBytesPeak = Limits.getHeapSize() - startHeapBytes;
	Integer rowsReturned = plainRows.size() + rollupRows.size() + cubeRows.size();
	// AggregateRow wrapper allocation approximation: each row holds a private final
	// AggregateResult plus 7 typed accessor methods (get, getDecimal, getInteger,
	// getLong, getString, getDouble, getDate). Approx allocations = rows × 7.
	Integer allocationsApprox = rowsReturned * 7;

	// PERF_ROW emission (one System.debug per metric, harvested by Task 2.6 perf-history harvester)
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 45, 'metric' => 'wallMs', 'value' => wallMs}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 45, 'metric' => 'cpuMs', 'value' => cpuMs}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 45, 'metric' => 'soqlCount', 'value' => soqlCount}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 45, 'metric' => 'heapBytesPeak', 'value' => heapBytesPeak}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 45, 'metric' => 'rowsReturned', 'value' => rowsReturned}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 45, 'metric' => 'allocationsApprox', 'value' => allocationsApprox}));

	System.debug(LoggingLevel.INFO,
			'45 PASS: 3 queries on ' + BATCH_TOTAL + ' rows. '
			+ 'plain=' + plainRows.size() + ' rows, rollup=' + rollupRows.size() + ' rows (1 grand-total),'
			+ ' cube=' + cubeRows.size() + ' rows (6 leaves + 5 subtotals + 1 grand-total). '
			+ 'wall=' + wallMs + 'ms cpu=' + cpuMs + 'ms soql=' + soqlCount
			+ ' heap=' + heapBytesPeak + ' bytes rowsReturned=' + rowsReturned + ' allocApprox=' + allocationsApprox);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '45 FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('45: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — delete every Foobar__c row tagged by this run (bounded at 9,000 to stay under the 10K DML row governor).
kern.TRG_Base.clearAllBypasses();
try
{
	List<kern__Foobar__c> residualRows =
	[
			SELECT Id
			FROM kern__Foobar__c
			WHERE Name = :NAME_TAG
			LIMIT 9000
	];
	if(!residualRows.isEmpty())
	{
		delete residualRows;
		System.debug(LoggingLevel.INFO, 'Cleanup: deleted ' + residualRows.size() + ' kern__Foobar__c row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug(LoggingLevel.WARN, '45 cleanup warning (Foobar__c delete failed): ' + cleanupError.getMessage());
}

// Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 45: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 45 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 45 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 45 COMPLETE: All scenarios passed ===');
}
