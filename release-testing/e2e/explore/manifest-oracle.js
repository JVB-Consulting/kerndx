// SPDX-License-Identifier: Apache-2.0
// The oracle of a volume walk: the manifest says what to count, the database says how many, at check time (I5).
'use strict';

const fs = require('fs');
const {soqlQuery} = require('../helpers/sf-cli');
const {namespacePrefix} = require('../helpers/sf-namespace');

// The engine-written small-action kinds whose ids the console's search resolves (every harness id is UUID-shaped
// from the letters a to f, D8).
const ENGINE_KINDS_WITH_SEARCHABLE_IDS = ['orders', 'imports', 'nightly', 'nested', 'handlers'];
// The reconciliation's chain names by depth: the root, then one name per level below it; the last is the leaf.
const LEAF_DEPTH = 3;

/**
 * @description A field or object API name with the org's namespace prefix.
 * @param {string} name The bare API name.
 * @returns {string} The prefixed name.
 */
function field(name)
{
	return `${namespacePrefix()}${name}`;
}

/**
 * @description The chain run object's API name.
 * @returns {string} The prefixed object name.
 */
function chainObject()
{
	return field('AsyncChainExecution__c');
}

/**
 * @description The log entry object's API name.
 * @returns {string} The prefixed object name.
 */
function entryObject()
{
	return field('LogEntry__c');
}

/**
 * @description Values quoted for a SOQL IN list.
 * @param {Array<string>} values The values.
 * @returns {string} The quoted, comma-separated list.
 */
function quoted(values)
{
	return values.map((value) => `'${value}'`).join(', ');
}

/**
 * @description Runs a COUNT(Id) query and reads its number.
 * @param {string} query The query.
 * @returns {number} The count.
 */
function countOf(query)
{
	return Number(soqlQuery(query)[0].expr0);
}

/**
 * @description Reads the load's manifest and returns the oracle the walk asks: the reconciliation action, an
 *              engine-written action whose id the search resolves, and readers that go to the database when called.
 * @param {string} manifestPath The manifest written by the volume driver.
 * @returns {Object} The oracle.
 */
function readManifestOracle(manifestPath)
{
	const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
	const reconciliation = manifest.actions.find((action) => action.kind === 'reconciliation');
	const searchableAction = manifest.actions.find((action) => !action.synthesized && ENGINE_KINDS_WITH_SEARCHABLE_IDS.includes(action.kind));
	const runToken = manifest.runToken;
	// The oldest run of that name under the action: the engine wrote its rows before the staged fill cloned them, so
	// the oldest carries a launcher the monitor can resolve.
	const runByDepth = (depth) => soqlQuery(`SELECT ${field('CorrelationId__c')} FROM ${chainObject()} WHERE ${field('RootCorrelationId__c')} = '${reconciliation.id}'`
			+ ` AND ${field('ChainName__c')} = '${reconciliation.chainNames[depth]}' ORDER BY CreatedDate ASC LIMIT 1`)[0][field('CorrelationId__c')];
	const restartClone = () =>
	{
		const row = soqlQuery(`SELECT ${field('CorrelationId__c')}, ${field('SourceExecution__c')} FROM ${chainObject()} WHERE ${field('SourceExecution__c')} != null`
				+ ` AND ${field('RootCorrelationId__c')} LIKE '${runToken}-%' ORDER BY CreatedDate ASC LIMIT 1`)[0];
		return {correlationId: row[field('CorrelationId__c')], sourceExecutionId: row[field('SourceExecution__c')]};
	};
	return {
		manifest,
		actions: manifest.actions,
		reconciliation,
		searchableAction,
		runToken,
		searchableRun: () => runByDepth(LEAF_DEPTH),
		runByDepth,
		restartClone
	};
}

/**
 * @description The WHERE clause a run filter means, over the chain run object.
 * @param {Object} filter The action id, statuses, a name fragment, a chain id or a run token.
 * @returns {string} The clause with its leading space, or an empty string for no filter.
 */
function whereClause({actionId, statuses, nameContains, chainId, token, restartable, chainName})
{
	const parts = [];
	if(token)
	{
		// Every row the load wrote, by its token alone: the action ids all start with it (D8).
		parts.push(`${field('RootCorrelationId__c')} LIKE '${token}-%'`);
	}
	if(actionId)
	{
		parts.push(`${field('RootCorrelationId__c')} = '${actionId}'`);
	}
	if(chainId)
	{
		parts.push(`${field('CorrelationId__c')} = '${chainId}'`);
	}
	if(statuses && statuses.length > 0)
	{
		parts.push(`${field('Status__c')} IN (${quoted(statuses)})`);
	}
	if(nameContains)
	{
		// An underscore is a LIKE wildcard; escaped, the fragment matches itself only (the plan's known risk).
		parts.push(`${field('ChainName__c')} LIKE '%${nameContains.replace(/_/g, '\\_')}%'`);
	}
	if(chainName)
	{
		parts.push(`${field('ChainName__c')} = '${chainName}'`);
	}
	if(restartable !== undefined)
	{
		parts.push(`${field('AllowRestart__c')} = ${restartable}`);
	}
	return parts.length > 0 ? ` WHERE ${parts.join(' AND ')}` : '';
}

/**
 * @description How many runs match the filter, asked of the database now.
 * @param {Object} filter The run filter.
 * @returns {number} The count.
 */
function countRuns(filter)
{
	return countOf(`SELECT COUNT(Id) FROM ${chainObject()}${whereClause(filter)}`);
}

/**
 * @description The WHERE clause an entry filter means: under a chain, else under an action (as its root or as
 *              its own correlation), the plain rows by default or the rolled-up ones, narrowed by level, origin,
 *              window and the start of the message.
 * @param {Object} filter The entry filter.
 * @returns {string} The clause without its WHERE.
 */
function entryClause({actionId, chainId, windowStart, windowEnd, levels, origins, messageStartsWith, rolledUp = false})
{
	const parts = [];
	if(chainId)
	{
		parts.push(`${field('CorrelationId__c')} = '${chainId}'`);
	}
	else if(actionId)
	{
		parts.push(`(${field('RootCorrelationId__c')} = '${actionId}' OR ${field('CorrelationId__c')} = '${actionId}')`);
	}
	parts.push(`${field('OccurrenceCount__c')} ${rolledUp ? '!= null' : '= null'}`);
	if(levels && levels.length > 0)
	{
		parts.push(`${field('LogLevel__c')} IN (${quoted(levels)})`);
	}
	if(origins && origins.length > 0)
	{
		parts.push(`${field('Origin__c')} IN (${quoted(origins)})`);
	}
	if(windowStart)
	{
		parts.push(`CreatedDate >= ${new Date(windowStart).toISOString()}`);
	}
	if(windowEnd)
	{
		parts.push(`CreatedDate <= ${new Date(windowEnd).toISOString()}`);
	}
	if(messageStartsWith)
	{
		parts.push(`${field('ShortMessage__c')} LIKE '${messageStartsWith}%'`);
	}
	return parts.join(' AND ');
}

/**
 * @description How many log entries match the filter, asked of the database now.
 * @param {Object} filter The entry filter.
 * @returns {number} The count.
 */
function countEntries(filter)
{
	return countOf(`SELECT COUNT(Id) FROM ${entryObject()} WHERE ${entryClause(filter)}`);
}

/**
 * @description Every matching entry's record id in the order the console lists them (newest first), with Name
 *              as the tiebreak the screen lacks. The console keys a plain row on the entry's id.
 * @param {Object} filter The entry filter.
 * @returns {Array<string>} The record ids in order.
 */
function entryKeys(filter)
{
	return soqlQuery(`SELECT Id FROM ${entryObject()} WHERE ${entryClause(filter)} ORDER BY CreatedDate DESC, Name DESC`).map((row) => row.Id);
}

/**
 * @description When an action's runs started first and ended last: the span its custom range is set to.
 * @param {string} actionId The action id.
 * @returns {Object} `first` and `last` as the database returns them.
 */
function runsSpan(actionId)
{
	const row = soqlQuery(`SELECT MIN(${field('StartedAt__c')}), MAX(${field('CompletedAt__c')}) FROM ${chainObject()} WHERE ${field('RootCorrelationId__c')} = '${actionId}'`)[0];
	return {first: row.expr0, last: row.expr1};
}

/**
 * @description Every matching run's record id in the order the monitor sorts, with Name as the tiebreak the
 *              screen lacks. The monitor keys its rows on the record id, so these are what the screen's keys are
 *              compared with.
 * @param {Object} filter The run filter plus `sortField` and `sortDescending`.
 * @returns {Array<string>} The record ids in order.
 */
function runKeys({actionId, statuses, token, nameContains, sortField, sortDescending})
{
	const direction = sortDescending ? 'DESC' : 'ASC';
	return soqlQuery(`SELECT Id FROM ${chainObject()}${whereClause({actionId, statuses, token, nameContains})} ORDER BY ${field(sortField)} ${direction}, Name ${direction}`)
	.map((row) => row.Id);
}

/**
 * @description The sort field's value of each listed row, so a screen order can be checked with ties allowed.
 * @param {string} sortField The bare field API name.
 * @param {Array<string>} ids The record ids on screen.
 * @returns {Map<string, *>} The value by record id.
 */
function sortValuesByKey(sortField, ids)
{
	const values = new Map();
	if(ids.length === 0)
	{
		return values;
	}
	for(const row of soqlQuery(`SELECT Id, ${field(sortField)} FROM ${chainObject()} WHERE Id IN (${quoted(ids)})`))
	{
		values.set(row.Id, row[field(sortField)]);
	}
	return values;
}

/**
 * @description One run matching the filter, the oldest; null when none is left.
 * @param {Object} filter The run filter.
 * @returns {Object|null} The run's record `id`, `name`, `correlationId`, `totalSteps` and `allowRestart` (the restart the
 *                        chain declared at launch), or null.
 */
function findRun(filter)
{
	const query = `SELECT Id, Name, ${field('CorrelationId__c')}, ${field('TotalSteps__c')}, ${field('AllowRestart__c')} FROM ${chainObject()}${whereClause(filter)}`
			+ ' ORDER BY CreatedDate ASC LIMIT 1';
	const row = soqlQuery(query)[0];
	return row
			? {
				id: row.Id, name: row.Name, correlationId: row[field('CorrelationId__c')], totalSteps: row[field('TotalSteps__c')],
				allowRestart: row[field('AllowRestart__c')] === true
			}
			: null;
}

/**
 * @description A run's Name by its record id, for a launcher the screen names by number.
 * @param {string} recordId The record id.
 * @returns {string|null} The Name, or null when no row has that id.
 */
function runName(recordId)
{
	const row = soqlQuery(`SELECT Name FROM ${chainObject()} WHERE Id = '${recordId}'`)[0];
	return row ? row.Name : null;
}

module.exports = {readManifestOracle, countRuns, countEntries, entryKeys, runsSpan, runKeys, sortValuesByKey, findRun, runName, field};
