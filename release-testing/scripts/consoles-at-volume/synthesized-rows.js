// SPDX-License-Identifier: Apache-2.0
// Staged mode's volume: the engine's own rows, cloned. After the engine share drains, the rows and forensic entries
// under the engine actions are read back and re-keyed under new ids, new times and new actions, then written through
// the Bulk API. Nothing here knows the shape of a step log, a failure message or a category: what the engine wrote is
// what the clones carry. Every clone is marked synthesized in the manifest; every id is a harness id (D8).
const fs = require('fs');
const path = require('path');
const {mintVolumeId, letterOrdinal, KINDS, VOLUME_ID_SHAPE, recordStage} = require('./manifest');

const CHAIN_COLUMNS = [
	'ChainName__c',
	'Status__c',
	'CorrelationId__c',
	'LaunchCorrelationId__c',
	'RootCorrelationId__c',
	'CurrentStepName__c',
	'TotalSteps__c',
	'CompletedSteps__c',
	'StartedAt__c',
	'CompletedAt__c',
	'DurationMs__c',
	'StepLog__c',
	'ContextData__c',
	'InitialContextData__c',
	'FailureCategory__c',
	'ErrorMessage__c',
	'AllowRestart__c'
];
const LOG_COLUMNS = [
	'LogLevel__c',
	'ShortMessage__c',
	'Message__c',
	'ClassMethod__c',
	'Origin__c',
	'Source__c',
	'LineNumber__c',
	'ExceptionType__c',
	'StackTrace__c',
	'ExecutionEvent__c',
	'TransactionId__c',
	'ParentTransactionId__c',
	'CorrelationId__c',
	'RootCorrelationId__c',
	'UserId__c',
	'DurationMs__c'
];
const AUDIT_COLUMNS = [
	'CreatedDate',
	'LastModifiedDate'
];
const TIME_COLUMNS = [
	'StartedAt__c',
	'CompletedAt__c',
	'CreatedDate',
	'LastModifiedDate'
];
const TEXT_COLUMNS = [
	'ShortMessage__c',
	'Message__c',
	'ContextData__c',
	'InitialContextData__c'
];
const ID_COLUMNS = [
	'CorrelationId__c',
	'LaunchCorrelationId__c',
	'RootCorrelationId__c'
];
const CHUNK_ROWS = 5000;
const MINUTE = 60_000;
const ROOT_SPACING = 10 * MINUTE;
const SMALL_ACTION_SPACING = 2 * MINUTE;
const SMALL_ACTION_OFFSET = 1;
const SHORT_WIDTH = 4;
const CHUNK_NUMBER_WIDTH = 2;
// The `second` segment of a harness id given to an engine-minted row in a clone (a SubscriberNestedChild): the
// highest four-letter value, `ffff`, which no launch index or depth reaches. At 3 it collided with a clone's own
// launch index 3 (eight DUPLICATE_VALUE rejects on the first live fill, 2026-09-24).
const ENGINE_MINTED_SECOND = 1295;
const SMALL_ACTION_KINDS = [
	'orders',
	'imports',
	'nightly',
	'nested',
	'handlers'
];

/**
 * @description A record with its field names bare of the org's prefix and without the CLI's attributes.
 *
 * @param {object} record The record as the CLI returned it.
 * @param {string} fieldPrefix The org's field prefix.
 *
 * @returns {object}
 */
function bare(record, fieldPrefix)
{
	const row = {};
	for(const [key, value] of Object.entries(record))
	{
		if(key !== 'attributes')
		{
			row[key.startsWith(fieldPrefix) ? key.slice(fieldPrefix.length) : key] = value;
		}
	}
	return row;
}

/**
 * @description The five segments of a harness id.
 *
 * @param {string} id The id.
 *
 * @returns {{token: string, kind: string, first: string, second: string, ordinal: string}}
 */
function segments(id)
{
	const [token, kind, first, second, ordinal] = id.split('-');
	return {token, kind, first, second, ordinal};
}

/**
 * @description Exemplar id to clone id: a harness id keeps every segment but `first`; an engine-minted id gets a
 * harness id with `second` 3 and a counter, so a clone never shares an id with its exemplar or another clone.
 *
 * @param {object[]} rows The exemplar's rows.
 * @param {object[]} entries The exemplar's entries.
 * @param {object} target `runToken` and the clone's `first` segment.
 *
 * @returns {Map<string, string>}
 */
function buildIdMap(rows, entries, {runToken, first})
{
	const map = new Map();
	let engineMinted = 0;
	const runKind = rows.length > 0 && VOLUME_ID_SHAPE.test(rows[0].CorrelationId__c) ? segments(rows[0].CorrelationId__c).kind : KINDS.smallActionRun;
	const rowIds = rows.flatMap((row) => ID_COLUMNS.map((column) => row[column]));
	const entryIds = entries.flatMap((entry) => [
		entry.CorrelationId__c,
		entry.RootCorrelationId__c
	]);
	for(const id of [
		...rowIds,
		...entryIds
	].filter(Boolean))
	{
		if(map.has(id))
		{
			continue;
		}
		if(VOLUME_ID_SHAPE.test(id) && id.startsWith(`${runToken}-`))
		{
			const {kind, second, ordinal} = segments(id);
			map.set(id, `${runToken}-${kind}-${letterOrdinal(first, SHORT_WIDTH)}-${second}-${ordinal}`);
		}
		else
		{
			map.set(id, mintVolumeId(runKind, runToken, first, ENGINE_MINTED_SECOND, engineMinted));
			engineMinted += 1;
		}
	}
	return map;
}

/**
 * @description Text with every mapped id replaced by its clone id.
 *
 * @param {string} text The text.
 * @param {Map<string, string>} map The id map.
 *
 * @returns {string}
 */
function remapText(text, map)
{
	let result = text;
	for(const [from, to] of map)
	{
		if(result.includes(from))
		{
			result = result.split(from).join(to);
		}
	}
	return result;
}

/**
 * @description An instant shifted by a number of milliseconds, or the value as it was when blank.
 *
 * @param {string} iso The instant.
 * @param {number} shiftMilliseconds The shift.
 *
 * @returns {string}
 */
function shifted(iso, shiftMilliseconds)
{
	return iso ? new Date(Date.parse(iso) + shiftMilliseconds).toISOString() : iso;
}

/**
 * @description One record cloned: ids mapped, ids inside text mapped, times shifted, blanks emptied.
 *
 * @param {object} record The exemplar record.
 * @param {string[]} columns The columns to carry.
 * @param {Map<string, string>} map The id map.
 * @param {number} shiftMilliseconds The time shift.
 *
 * @returns {object}
 */
function cloneRecord(record, columns, map, shiftMilliseconds)
{
	const clone = {};
	for(const column of [
		...columns,
		...AUDIT_COLUMNS
	])
	{
		let value = record[column];
		if(typeof value === 'string' && map.has(value))
		{
			value = map.get(value);
		}
		else if(TEXT_COLUMNS.includes(column) && typeof value === 'string')
		{
			value = remapText(value, map);
		}
		else if(TIME_COLUMNS.includes(column))
		{
			value = shifted(value, shiftMilliseconds);
		}
		clone[column] = value === null || value === undefined ? '' : value;
	}
	return clone;
}

/**
 * @description The exemplar's entries cloned, each distinct transaction given its own synthetic transaction id.
 *
 * @param {object[]} entries The exemplar's entries.
 * @param {Map<string, string>} map The id map.
 * @param {number} shiftMilliseconds The time shift.
 * @param {string} runToken The run's token.
 * @param {number} cloneOrdinal The clone's ordinal, for the transaction ids.
 *
 * @returns {object[]}
 */
function cloneEntries(entries, map, shiftMilliseconds, runToken, cloneOrdinal)
{
	const transactions = new Map();
	for(const entry of entries)
	{
		if(!transactions.has(entry.TransactionId__c))
		{
			transactions.set(entry.TransactionId__c, `synth-${runToken}-${letterOrdinal(cloneOrdinal, SHORT_WIDTH)}-${letterOrdinal(transactions.size, SHORT_WIDTH)}`);
		}
	}
	return entries.map((entry) =>
	{
		const clone = cloneRecord(entry, LOG_COLUMNS, map, shiftMilliseconds);
		clone.TransactionId__c = transactions.get(entry.TransactionId__c);
		// A parent inside the clone maps with it; one outside (the exemplar's own tree) would point a reader at another run.
		clone.ParentTransactionId__c = transactions.get(entry.ParentTransactionId__c) || '';
		return clone;
	});
}

/**
 * @description The tie the first journey needs: the children of one parent start in the same second.
 *
 * @param {object[]} chainRows The cloned rows, changed in place.
 */
function tieSiblings(chainRows)
{
	const earliest = new Map();
	for(const row of chainRows)
	{
		const current = earliest.get(row.LaunchCorrelationId__c);
		if(!current || row.StartedAt__c < current)
		{
			earliest.set(row.LaunchCorrelationId__c, row.StartedAt__c);
		}
	}
	for(const row of chainRows)
	{
		row.StartedAt__c = earliest.get(row.LaunchCorrelationId__c);
		row.CreatedDate = row.StartedAt__c;
	}
}

/**
 * @description One engine-written root tree, re-keyed under another root ordinal, under the same action. The tree's
 * entries are those under its runs' correlations plus the root's own launch entry, which the engine writes under the
 * action and which names the root's id (UTIL_AsyncChain announceLaunch).
 *
 * @param {object} clone `{exemplar, runToken, fromRootOrdinal, toRootOrdinal, actionId, timeShiftMilliseconds}`.
 *
 * @returns {{chainRows: object[], logRows: object[]}}
 */
function cloneReconciliationRoot({exemplar, runToken, fromRootOrdinal, toRootOrdinal, actionId, timeShiftMilliseconds})
{
	const fromFirst = letterOrdinal(fromRootOrdinal, SHORT_WIDTH);
	const tree = exemplar.rows.filter((row) => VOLUME_ID_SHAPE.test(row.CorrelationId__c) && segments(row.CorrelationId__c).first === fromFirst);
	const treeIds = new Set(tree.map((row) => row.CorrelationId__c));
	// The engine's launch line names the run before its final period, so the id is looked for inside the text.
	const namesTreeRun = (entry) => entry.CorrelationId__c === actionId && [...treeIds].some((id) => String(entry.ShortMessage__c).includes(id));
	const entries = exemplar.entries.filter((entry) => treeIds.has(entry.CorrelationId__c) || namesTreeRun(entry));
	const map = buildIdMap(tree, entries, {runToken, first: toRootOrdinal});
	map.set(actionId, actionId);
	const chainRows = tree.map((row) => cloneRecord(row, CHAIN_COLUMNS, map, timeShiftMilliseconds));
	tieSiblings(chainRows);
	return {chainRows, logRows: cloneEntries(entries, map, timeShiftMilliseconds, runToken, toRootOrdinal)};
}

/**
 * @description One engine-written small action, re-keyed under another ordinal as its own action.
 *
 * @param {object} clone `{exemplar, runToken, toOrdinal, timeShiftMilliseconds}`.
 *
 * @returns {{chainRows: object[], logRows: object[], action: object}}
 */
function cloneSmallAction({exemplar, runToken, toOrdinal, timeShiftMilliseconds})
{
	const first = toOrdinal + SMALL_ACTION_OFFSET;
	const map = buildIdMap(exemplar.rows, exemplar.entries, {runToken, first});
	const actionId = map.get(exemplar.action.id) || mintVolumeId(KINDS.action, runToken, first, 0, 0);
	map.set(exemplar.action.id, actionId);
	const chainRows = exemplar.rows.map((row) => cloneRecord(row, CHAIN_COLUMNS, map, timeShiftMilliseconds));
	const logRows = cloneEntries(exemplar.entries, map, timeShiftMilliseconds, runToken, first);
	const {kind, expected, launches, retryCandidates, restartCandidates} = exemplar.action;
	const action = {id: actionId, kind, ordinal: toOrdinal, expected, synthesized: true, clonedFrom: exemplar.action.id, launches, retryCandidates, restartCandidates};
	return {chainRows, logRows, action};
}

/**
 * @description The engine-written rows and forensic entries under the engine actions, field names bare of the prefix.
 *
 * @param {object} salesforce The org door.
 * @param {object} manifest The manifest.
 *
 * @returns {{reconciliation: object, smallActions: object[]}}
 */
function readExemplars(salesforce, manifest)
{
	const prefix = manifest.org.namespacePrefix;
	const field = (name) => `${prefix}${name}`;
	const engineActions = manifest.actions.filter((action) => !action.synthesized && (action.kind === 'reconciliation' || SMALL_ACTION_KINDS.includes(action.kind)));
	const ids = engineActions.map((action) => `'${action.id}'`).join(', ');
	const chainSoql = `SELECT ${CHAIN_COLUMNS.map(field).join(', ')}, CreatedDate, LastModifiedDate FROM ${field('AsyncChainExecution__c')} `
			+ `WHERE ${field('RootCorrelationId__c')} IN (${ids})`;
	const rows = salesforce.query(chainSoql).records.map((record) => bare(record, prefix));
	const logSoql = `SELECT ${LOG_COLUMNS.map(field).join(', ')}, CreatedDate, LastModifiedDate FROM ${field('LogEntry__c')} `
			+ `WHERE ${field('RootCorrelationId__c')} IN (${ids}) AND ${field('OccurrenceCount__c')} = null`;
	const entries = salesforce.query(logSoql).records.map((record) => bare(record, prefix));
	const under = (id) => ({rows: rows.filter((row) => row.RootCorrelationId__c === id), entries: entries.filter((entry) => entry.RootCorrelationId__c === id)});
	const reconciliation = engineActions.find((action) => action.kind === 'reconciliation');
	return {
		reconciliation: {actionId: reconciliation.id, ...under(reconciliation.id)},
		smallActions: engineActions.filter((action) => action.kind !== 'reconciliation').map((action) => ({action, ...under(action.id)}))
	};
}

/**
 * @description A value as a CSV field, quoted when it holds a comma, a quote or a line break.
 *
 * @param {*} value The value.
 *
 * @returns {string}
 */
function escapeCsvField(value)
{
	const text = value === null || value === undefined ? '' : String(value);
	return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/**
 * @description Rows as a CSV file with the custom columns prefixed for the org.
 *
 * @param {object[]} rows The rows.
 * @param {string[]} columns The custom columns.
 * @param {string} fieldPrefix The org's field prefix.
 *
 * @returns {string}
 */
function renderCsv(rows, columns, fieldPrefix)
{
	const header = [
		...columns.map((column) => `${fieldPrefix}${column}`),
		...AUDIT_COLUMNS
	].join(',');
	const lines = rows.map((row) => [
		...columns,
		...AUDIT_COLUMNS
	].map((column) => escapeCsvField(row[column])).join(','));
	return `${[
		header,
		...lines
	].join('\n')}\n`;
}

/**
 * @description Chain rows as CSV.
 *
 * @param {object[]} rows The rows.
 * @param {string} fieldPrefix The org's field prefix.
 *
 * @returns {string}
 */
function renderChainCsv(rows, fieldPrefix)
{
	return renderCsv(rows, CHAIN_COLUMNS, fieldPrefix);
}

/**
 * @description Log rows as CSV.
 *
 * @param {object[]} rows The rows.
 * @param {string} fieldPrefix The org's field prefix.
 *
 * @returns {string}
 */
function renderLogCsv(rows, fieldPrefix)
{
	return renderCsv(rows, LOG_COLUMNS, fieldPrefix);
}

/**
 * @description Rows in slices of a size.
 *
 * @param {Array} rows The rows.
 * @param {number} size The slice size.
 *
 * @returns {Array[]}
 */
function chunk(rows, size)
{
	const chunks = [];
	for(let start = 0; start < rows.length; start += size)
	{
		chunks.push(rows.slice(start, start + size));
	}
	return chunks;
}

/**
 * @description Writes the rows as CSV chunks under the output directory and imports each through the Bulk API.
 *
 * @param {object} context The stage context.
 * @param {object[]} rows The rows.
 * @param {Function} render The CSV renderer for the rows' object.
 * @param {string} sobjectName The object, bare of the prefix.
 * @param {string} label The file name stem.
 *
 * @returns {object[]} One import result per chunk.
 */
function importRows(context, rows, render, sobjectName, label)
{
	const directory = path.join(context.options.outputDirectory, 'synthesized');
	fs.mkdirSync(directory, {recursive: true});
	return chunk(rows, CHUNK_ROWS).map((slice, index) =>
	{
		const filePath = path.join(directory, `${label}-${String(index + 1).padStart(CHUNK_NUMBER_WIDTH, '0')}.csv`);
		fs.writeFileSync(filePath, render(slice, context.manifest.org.namespacePrefix), 'utf8');
		const result = context.salesforce.importCsv(`${context.manifest.org.namespacePrefix}${sobjectName}`, filePath);
		context.log(`synthesize: ${label} chunk ${index + 1}: ${result.succeeded} in, ${result.failed} failed (job ${result.jobId})`);
		return result;
	});
}

/**
 * @description The clones of the engine's root tree, one per root the engine did not run.
 *
 * @param {object} manifest The manifest.
 * @param {object} exemplar The reconciliation exemplar.
 * @param {object} reconciliation The reconciliation action's record.
 *
 * @returns {{chainRows: object[], logRows: object[]}}
 */
function cloneRoots(manifest, exemplar, reconciliation)
{
	const chainRows = [];
	const logRows = [];
	for(let rootOrdinal = reconciliation.engineRoots; rootOrdinal < reconciliation.roots; rootOrdinal++)
	{
		const clone = cloneReconciliationRoot({
			exemplar, runToken: manifest.runToken, fromRootOrdinal: 0, toRootOrdinal: rootOrdinal, actionId: reconciliation.id, timeShiftMilliseconds: -rootOrdinal * ROOT_SPACING
		});
		chainRows.push(...clone.chainRows);
		logRows.push(...clone.logRows);
	}
	return {chainRows, logRows};
}

/**
 * @description The clones of the engine's small actions, one per planned action the engine did not run, each from
 * the engine action with the same launch signature.
 *
 * @param {object} manifest The manifest.
 * @param {object} shape The scaled shape.
 * @param {object[]} exemplars The small-action exemplars.
 *
 * @returns {{chainRows: object[], logRows: object[], actions: object[]}}
 */
function cloneSmallActions(manifest, shape, exemplars)
{
	const signature = (launches) => JSON.stringify(launches);
	const chainRows = [];
	const logRows = [];
	const actions = [];
	for(const planned of shape.expected.smallActions.slice(shape.smallActions.engineCount))
	{
		const exemplar = exemplars.find((candidate) => signature(candidate.action.launches) === signature(planned.launches));
		if(!exemplar)
		{
			throw new Error(`No engine-written small action matches the planned launches ${signature(planned.launches)}; a staged run needs its twelve engine actions `
					+ '(raise --size, or run full mode).');
		}
		const clone = cloneSmallAction({exemplar, runToken: manifest.runToken, toOrdinal: planned.ordinal, timeShiftMilliseconds: -(planned.ordinal + 1) * SMALL_ACTION_SPACING});
		chainRows.push(...clone.chainRows);
		logRows.push(...clone.logRows);
		actions.push({...clone.action, kind: planned.kind});
	}
	return {chainRows, logRows, actions};
}

/**
 * @description Fills a staged run to the full shape with clones of the engine's own rows and records what was written.
 *
 * @param {object} context `{options, salesforce, shape, manifest, log}`.
 *
 * @returns {Promise<object>} The manifest; the launch stage is recorded failed when an import rejected rows.
 */
async function synthesize(context)
{
	const {manifest, shape, salesforce} = context;
	const exemplars = readExemplars(salesforce, manifest);
	const reconciliation = manifest.actions.find((action) => action.kind === 'reconciliation');
	const roots = cloneRoots(manifest, exemplars.reconciliation, reconciliation);
	const smallActions = cloneSmallActions(manifest, shape, exemplars.smallActions);
	const chainRows = [
		...roots.chainRows,
		...smallActions.chainRows
	];
	const logRows = [
		...roots.logRows,
		...smallActions.logRows
	];
	const chainResults = importRows(context, chainRows, renderChainCsv, 'AsyncChainExecution__c', 'chains');
	const results = [
		...chainResults,
		...importRows(context, logRows, renderLogCsv, 'LogEntry__c', 'entries')
	];
	const failedJobs = results.filter((result) => result.failed > 0 || !result.completed);
	manifest.actions.push(...smallActions.actions);
	reconciliation.synthesizedRoots = reconciliation.roots - reconciliation.engineRoots;
	manifest.synthesized = {
		chainRows: chainRows.length,
		logRows: logRows.length,
		stalledRows: manifest.synthesized.stalledRows || [],
		startedStepRows: manifest.synthesized.startedStepRows || [],
		jobs: results.map((result) => result.jobId),
		clonedFrom: {reconciliationRoot: 0, smallActions: [...new Set(smallActions.actions.map((action) => action.clonedFrom))]}
	};
	if(failedJobs.length > 0)
	{
		const jobs = failedJobs.map((result) => `job ${result.jobId} failed ${result.failed}${result.raw ? ` (the CLI said: ${result.raw})` : ''}`).join('; ');
		return recordStage(manifest, 'launch', {ok: false, reason: `Bulk import rejected rows: ${jobs}. Read the job's failed-records file, run teardown, run again.`});
	}
	return manifest;
}

module.exports = {
	CHAIN_COLUMNS,
	LOG_COLUMNS,
	ENGINE_MINTED_SECOND,
	readExemplars,
	buildIdMap,
	cloneReconciliationRoot,
	cloneSmallAction,
	renderChainCsv,
	renderLogCsv,
	escapeCsvField,
	chunk,
	synthesize
};
