// SPDX-License-Identifier: Apache-2.0
// Removes a run's rows by its manifest and proves nothing survives. Never a runbook step: a release org is discarded;
// this is for the development org, before a re-run.
const {fillNamespaceTokens} = require('../../e2e/helpers/sf-namespace');
const {renderTemplate, apexStringList} = require('./apex-templates');

const MAXIMUM_PASSES = 20;
const COUNTS = /chainRows=(\d+) logRows=(\d+)/;
const ABORTED = /aborted=(\d+)/;
const DEFAULT_WATCHDOG_PREFIX = 'Consoles At Volume Watchdog';

/**
 * @description The rows the watchdog acted on: the synthesized Stalled rows of both kinds and the dead-job stalls. Its
 * log entries for them carry only the row's id.
 *
 * @param {object} manifest The manifest.
 *
 * @returns {string[]}
 */
function watchedRowIds(manifest)
{
	const synthesized = manifest.synthesized || {};
	const deadJobStalls = manifest.operatorWave?.deadJobStalls || [];
	return [...(synthesized.stalledRows || []), ...(synthesized.startedStepRows || []), ...deadJobStalls.map((stall) => stall.executionId)];
}

/**
 * @description One deleting pass over the run's rows.
 *
 * @param {object} context The stage context.
 * @param {number} pass The pass number, for the script's label.
 *
 * @returns {{chainRows: number, logRows: number}|null} What survived, or null when the script printed no count.
 */
function deleteOnce(context, pass)
{
	const {manifest, salesforce} = context;
	const values = {
		__ACTION_IDS__: apexStringList(manifest.actions.map((action) => action.id)), __RUN_TOKEN__: manifest.runToken, __WATCHED_ROW_IDS__: apexStringList(watchedRowIds(manifest))
	};
	const result = salesforce.runApex(fillNamespaceTokens(renderTemplate('teardown.apex', values), manifest.org.namespacePrefix), `teardown-${pass}`);
	const match = (result.debugLines.find((line) => line.startsWith('VOLUME_TEARDOWN')) || '').match(COUNTS);
	return match ? {chainRows: Number(match[1]), logRows: Number(match[2])} : null;
}

/**
 * @description Aborts the run's watchdog jobs and returns how many.
 *
 * @param {object} context The stage context.
 *
 * @returns {number}
 */
function unscheduleWatchdog(context)
{
	const {manifest, salesforce} = context;
	const prefix = manifest.watchdog ? manifest.watchdog.jobNamePrefix : DEFAULT_WATCHDOG_PREFIX;
	const apex = fillNamespaceTokens(renderTemplate('unschedule-watchdog.apex', {__JOB_NAME_PREFIX__: prefix}), manifest.org.namespacePrefix);
	const result = salesforce.runApex(apex, 'teardown-watchdog');
	const match = (result.debugLines.find((line) => line.startsWith('VOLUME_WATCHDOG')) || '').match(ABORTED);
	return match ? Number(match[1]) : 0;
}

/**
 * @description The teardown: deletes until nothing survives, aborts the watchdog jobs, records when.
 *
 * @param {object} context `{manifest, salesforce, log}`.
 *
 * @returns {Promise<object>} The manifest, with `stages.teardown` failed when rows survived.
 */
async function run(context)
{
	const {manifest, log} = context;
	let passes = 0;
	let surviving = {chainRows: -1, logRows: -1};
	while(passes < MAXIMUM_PASSES && (surviving.chainRows !== 0 || surviving.logRows !== 0))
	{
		passes++;
		surviving = deleteOnce(context, passes) || surviving;
		log(`teardown: pass ${passes}, ${surviving.chainRows} chain rows and ${surviving.logRows} log rows remain`);
	}
	const watchdogJobsAborted = unscheduleWatchdog(context);
	manifest.tornDownAt = new Date().toISOString();
	manifest.teardown = {passes, survivingChainRows: surviving.chainRows, survivingLogRows: surviving.logRows, watchdogJobsAborted};
	if(surviving.chainRows !== 0 || surviving.logRows !== 0)
	{
		manifest.stages.teardown = {ok: false, reason: `${surviving.chainRows} chain rows and ${surviving.logRows} log rows survived ${passes} passes`};
	}
	return manifest;
}

module.exports = {run};
