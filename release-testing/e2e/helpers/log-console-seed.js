// SPDX-License-Identifier: Apache-2.0
// The Log Console's shaped seed: one story told by two anonymous-Apex scripts, run in this order. Anonymous Apex
// refuses a script over 32,000 characters, so the whole-action rows live in a second script. The first script's
// clear also removes the second script's rows, so the order matters: the first always runs first.
const path = require('path');
const {runApexScript} = require('./sf-cli');

const SCRIPTS_DIRECTORY = path.join(__dirname, '..', '..', 'scripts');
const SHAPED_SEED_TIMEOUT_MILLISECONDS = 300_000;
// Each script and the debug line it prints once its rows are in. The trailing space keeps the first script's line
// apart from the second's, which starts with the same words.
const SHAPED_SEED_SCRIPTS = [
	{path: path.join(SCRIPTS_DIRECTORY, 'seed-log-console.apex'), marker: 'SEED_LOG_CONSOLE '},
	{path: path.join(SCRIPTS_DIRECTORY, 'seed-log-console-actions.apex'), marker: 'SEED_LOG_CONSOLE_ACTIONS '}
];

/**
 * @description Runs the shaped seed's scripts in order, and stops at the first one that does not report its rows.
 *
 * @param {object} options `timeout`, the milliseconds each script may take.
 *
 * @returns {{raw: string, results: object[]}} Every script's output joined, and each script's parsed result in order.
 */
function runShapedSeed({timeout = SHAPED_SEED_TIMEOUT_MILLISECONDS} = {})
{
	const results = [];
	for(const script of SHAPED_SEED_SCRIPTS)
	{
		const result = runApexScript(script.path, {timeout});
		if(!result.results.some((line) => line.message.includes(script.marker)))
		{
			throw new Error(`${path.basename(script.path)} did not report ${script.marker.trim()}, so its rows were not seeded`);
		}
		results.push(result);
	}
	return {raw: results.map((result) => result.raw).join('\n'), results};
}

module.exports = {SHAPED_SEED_SCRIPTS, runShapedSeed};
