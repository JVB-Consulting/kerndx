// SPDX-License-Identifier: Apache-2.0
// The checks a load needs before it starts, each named in the manifest with what it found.
const {deployStrippedSubscriberClasses} = require('../../e2e/helpers/subscriber-deploy');
const {fillNamespaceTokens} = require('../../e2e/helpers/sf-namespace');
const {createManifest, recordStage, newRunToken} = require('./manifest');
const {renderTemplate, apexStringList} = require('./apex-templates');

const STEP_CLASSES = [
	'SubscriberChainSteps',
	'SubscriberChainSteps_TEST'
];
const STEP_MARKER = 'class FanOutStep extends';
const CHAIN_PERMISSION_SETS = [
	'AsyncChainRedrive',
	'AsyncChainAbort',
	'AsyncChainKillSwitch'
];
const AUDIT_PERMISSION_SET = 'KernE2EAuditFieldAccess';
const KILOBYTES_PER_CHAIN_ROW = 2;
const KILOBYTES_PER_LOG_ROW = 2;
// Measured on the first staged fill (2026-09-24): 2,611 entries for 566 cloned runs, about 4.6 a run.
const LOG_ROWS_PER_RUN = 5;
const KILOBYTES_PER_MEGABYTE = 1024;
const STORAGE_MARGIN = 1.1;
const INFO_POLLS = 6;
const INFO_POLL_MILLISECONDS = 5000;
const BASE_36 = 36;
const WATCHDOG = {thresholdMinutes: 3, jobNamePrefix: 'Consoles At Volume Watchdog', scheduledBy: 'operate', scheduled: false};
const PREFLIGHT_CHECKS = [
	'namespace',
	'stepClasses',
	'permissionSets',
	'infoPersists',
	'storage',
	'earlierLoad'
];

/**
 * @description The megabytes the run's rows will take, chain rows and log rows together.
 *
 * @param {object} shape The scaled shape.
 *
 * @returns {number}
 */
function projectStorageMegabytes(shape)
{
	const runs = shape.expected.reconciliation.runs + shape.expected.smallActions.reduce((sum, action) => sum + action.expected.runs, 0);
	const kilobytes = runs * KILOBYTES_PER_CHAIN_ROW + runs * LOG_ROWS_PER_RUN * KILOBYTES_PER_LOG_ROW;
	return Math.ceil(kilobytes / KILOBYTES_PER_MEGABYTE);
}

/**
 * @description Records the stage as failed with its reason and what it had checked so far.
 *
 * @param {object} manifest The manifest.
 * @param {string} reason Why the load cannot start.
 * @param {object} checks The checks so far.
 *
 * @returns {object} The manifest.
 */
function fail(manifest, reason, checks)
{
	return recordStage(manifest, 'preflight', {ok: false, reason, checks});
}

/**
 * @description Waits for a number of milliseconds.
 *
 * @param {number} milliseconds How long.
 *
 * @returns {Promise<void>}
 */
function defaultSleep(milliseconds)
{
	return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/**
 * @description The org's field prefix from its probe: the package prefix under the package, empty without.
 *
 * @param {object} salesforce The org door.
 *
 * @returns {string}
 */
function readNamespacePrefix(salesforce)
{
	const row = salesforce.query('SELECT NamespacePrefix FROM ApexClass WHERE Name = \'UTIL_AsyncChain\' LIMIT 1', {tooling: true}).records[0];
	return row && row.NamespacePrefix ? `${row.NamespacePrefix}__` : '';
}

/**
 * @description Whether the org holds the step classes with the volume steps in them.
 *
 * @param {object} salesforce The org door.
 *
 * @returns {boolean}
 */
function hasVolumeSteps(salesforce)
{
	const rows = salesforce.query('SELECT Body FROM ApexClass WHERE Name = \'SubscriberChainSteps\' LIMIT 1', {tooling: true}).records;
	return rows.length > 0 && String(rows[0].Body).includes(STEP_MARKER);
}

/**
 * @description The permission sets the run user holds among the ones the load needs; assigns the chain operator sets found missing.
 *
 * @param {object} salesforce The org door.
 * @param {string} namespacePrefix The org's field prefix.
 * @param {string} userId The run user.
 *
 * @returns {{assigned: string[], missingChainSets: string[]}}
 */
function ensurePermissionSets(salesforce, namespacePrefix, userId)
{
	const namespaceClause = namespacePrefix ? `PermissionSet.NamespacePrefix = '${namespacePrefix.slice(0, -2)}'` : 'PermissionSet.NamespacePrefix = NULL';
	const chainSetNames = CHAIN_PERMISSION_SETS.map((name) => `'${name}'`).join(', ');
	const soql = `SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = '${userId}' `
			+ `AND (PermissionSet.Name = '${AUDIT_PERMISSION_SET}' OR (${namespaceClause} AND PermissionSet.Name IN (${chainSetNames})))`;
	const assigned = salesforce.query(soql).records.map((row) => row.PermissionSet.Name);
	const missingChainSets = CHAIN_PERMISSION_SETS.filter((name) => !assigned.includes(name));
	if(missingChainSets.length > 0)
	{
		const values = {__PERMISSION_SET_NAMES__: apexStringList(missingChainSets), __NAMESPACE_CLAUSE__: namespaceClause.replace('PermissionSet.', ''), __USER_ID__: userId};
		salesforce.runApex(fillNamespaceTokens(renderTemplate('assign-permission-sets.apex', values), namespacePrefix), 'preflight-permission-sets');
	}
	return {assigned, missingChainSets};
}

/**
 * @description Emits one INFO entry and polls for it, so a threshold above INFO is found before any load.
 *
 * @param {object} salesforce The org door.
 * @param {string} namespacePrefix The org's field prefix.
 * @param {string} runToken The run's token.
 * @param {Function} sleep The wait between polls.
 *
 * @returns {Promise<boolean>}
 */
async function infoPersists(salesforce, namespacePrefix, runToken, sleep)
{
	const token = `${runToken}${Date.now().toString(BASE_36).replace(/\d/g, 'x')}`;
	salesforce.runApex(fillNamespaceTokens(renderTemplate('probe-entry.apex', {__TOKEN__: token}), namespacePrefix), 'preflight-info');
	const soql = `SELECT COUNT() FROM ${namespacePrefix}LogEntry__c WHERE ${namespacePrefix}ShortMessage__c LIKE '%${token}%'`;
	for(let poll = 0; poll < INFO_POLLS; poll++)
	{
		await sleep(INFO_POLL_MILLISECONDS);
		if(salesforce.query(soql).totalSize > 0)
		{
			return true;
		}
	}
	return false;
}

/**
 * @description Whether the manifest describes a load that verified clean, so its rows can be reused.
 *
 * @param {object|null} manifest The manifest handed in, or null.
 *
 * @returns {boolean}
 */
function isVerified(manifest)
{
	const verify = manifest?.stages?.verify;
	return Boolean(verify && verify.ok && verify.failed === 0);
}

/**
 * @description The storage check: what the run projects against what the org has left.
 *
 * @param {object} salesforce The org door.
 * @param {object} shape The scaled shape.
 * @param {string} mode The run's mode, for the message.
 *
 * @returns {{ok: boolean, text: string}} The check's line, and whether the rows fit.
 */
function checkStorage(salesforce, shape, mode)
{
	const projected = projectStorageMegabytes(shape);
	const storage = salesforce.listLimits().dataStorageMegabytes;
	if(storage.remaining < projected * STORAGE_MARGIN)
	{
		return {ok: false, text: `Not enough data storage: ${projected} MB projected for this ${mode} run, ${storage.remaining} MB of ${storage.maximum} remaining.`};
	}
	return {ok: true, text: `${projected} MB projected, ${storage.remaining} MB remaining`};
}

/**
 * @description The count of an earlier load's rows still in the org.
 *
 * @param {object} salesforce The org door.
 * @param {string} namespacePrefix The org's field prefix.
 *
 * @returns {number}
 */
function countEarlierRows(salesforce, namespacePrefix)
{
	return salesforce.query(`SELECT COUNT() FROM ${namespacePrefix}AsyncChainExecution__c WHERE ${namespacePrefix}ChainName__c LIKE 'Volume\\_%'`).totalSize;
}

/**
 * @description The preflight stage: the org's namespace, the step classes, the permission sets, INFO persistence,
 * storage headroom and an earlier load, each recorded; any refusal names what to do.
 *
 * @param {object} context `{options, salesforce, shape, manifest, log, sleep}`.
 *
 * @returns {Promise<object>} The manifest with the stage recorded.
 */
async function run(context)
{
	const {options, salesforce, shape, log} = context;
	const sleep = context.sleep || defaultSleep;
	const checks = {};
	const namespacePrefix = readNamespacePrefix(salesforce);
	checks.namespace = namespacePrefix || '(none)';
	const userId = salesforce.runUserId();
	const org = {alias: options.alias, namespacePrefix, userId};
	const manifest = context.manifest || createManifest({mode: options.mode, size: options.size, runToken: newRunToken(), org, startedAt: new Date().toISOString(), shape});
	manifest.watchdog = manifest.watchdog || {...WATCHDOG};

	const hasSteps = hasVolumeSteps(salesforce);
	if(!hasSteps && namespacePrefix)
	{
		return fail(manifest, 'SubscriberChainSteps on this org lacks the volume steps; deploy release-testing/subscriber/ as RUNBOOK Phase 1.4 says, then run again.', checks);
	}
	if(!hasSteps)
	{
		deployStrippedSubscriberClasses(STEP_CLASSES, {alias: options.alias});
		log('preflight: deployed the stripped step classes');
	}
	checks.stepClasses = hasSteps ? 'present' : 'deployed';

	const {assigned, missingChainSets} = ensurePermissionSets(salesforce, namespacePrefix, userId);
	if(!assigned.includes(AUDIT_PERMISSION_SET))
	{
		return fail(manifest, `The run user lacks ${AUDIT_PERMISSION_SET}; apply the audit-field recipe (RUNBOOK Phase 1.4) and run again.`, checks);
	}
	checks.permissionSets = missingChainSets.length > 0 ? `assigned ${missingChainSets.join(', ')}` : 'held';

	if(!await infoPersists(salesforce, namespacePrefix, manifest.runToken, sleep))
	{
		return fail(manifest, 'An INFO entry did not persist within thirty seconds; raise the org\'s log level threshold to INFO (LogSetting__c) and run again.', checks);
	}
	checks.infoPersists = 'yes';

	const storage = checkStorage(salesforce, shape, options.mode);
	if(!storage.ok)
	{
		return fail(manifest, storage.text, checks);
	}
	checks.storage = storage.text;

	const earlierRows = countEarlierRows(salesforce, namespacePrefix);
	if(earlierRows > 0 && (isVerified(context.manifest) || options.reuse))
	{
		checks.earlierLoad = `${earlierRows} rows, reused`;
		return recordStage(manifest, 'preflight', {ok: true, reused: true, checks});
	}
	if(earlierRows > 0)
	{
		return fail(manifest, `${earlierRows} rows of an earlier load are in the org with no verified manifest to reuse; run teardown first.`, checks);
	}
	checks.earlierLoad = 'none';
	return recordStage(manifest, 'preflight', {ok: true, reused: false, checks});
}

module.exports = {run, projectStorageMegabytes, PREFLIGHT_CHECKS, WATCHDOG, STEP_CLASSES};
