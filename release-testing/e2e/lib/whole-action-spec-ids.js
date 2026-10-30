// SPDX-License-Identifier: Apache-2.0
// The whole-action prototype of 2026-09-07 (the Log Console whole-action design) draws BOTH
// consoles on one page, so its data-spec-id inventory is partitioned here: the Log Console gap-finder owns one half,
// the Chain Monitor gap-finder the other, and a guard proves the two halves cover the inventory exactly, so a new id
// cannot fall between the two gates.
const fs = require('fs');

const CHAIN_MONITOR_IDS = new Set([
	'monitor-action-pill',
	'monitor-col-launched-under',
	'monitor-show-action-logs',
	'monitor-detail-show-action-logs',
	'launched-under-row',
	'detail-toolbar-row',
	'timing-grid'
]);

function readSpecIds(prototypePath)
{
	const markup = fs.readFileSync(prototypePath, 'utf8');
	return new Set([...markup.matchAll(/data-spec-id="([^"]+)"/g)].map((match) => match[1]));
}

function logConsoleIds(prototypePath)
{
	return [...readSpecIds(prototypePath)].filter((specId) => !CHAIN_MONITOR_IDS.has(specId));
}

function chainMonitorIds(prototypePath)
{
	return [...readSpecIds(prototypePath)].filter((specId) => CHAIN_MONITOR_IDS.has(specId));
}

// Every monitor id the partition names must exist in the prototype, or the partition has drifted from the artifact.
function partitionDrift(prototypePath)
{
	const present = readSpecIds(prototypePath);
	return [...CHAIN_MONITOR_IDS].filter((specId) => !present.has(specId));
}

module.exports = {CHAIN_MONITOR_IDS, logConsoleIds, chainMonitorIds, partitionDrift};
