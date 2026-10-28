// SPDX-License-Identifier: BUSL-1.1
// The one record of a load run: what was asked, what each stage did, every id later stages and the exploration need.
const fs = require('fs');
const path = require('path');

const MANIFEST_VERSION = 1;
const STAGES = [
	'preflight',
	'launch',
	'drain',
	'operate',
	'verify'
];
// The id alphabet: hexadecimal letters only, so an id is UUID-shaped (the Log Console's search resolves it) and never
// forms a digit run (the payment-card masking target rewrites 13 to 19 digits, hyphens included). The same rule as
// SubscriberChainSteps.volumeRunId; a test in each place pins the shape.
const ID_ALPHABET = 'abcdef';
const RUN_TOKEN_LENGTH = 8;
const SHORT_WIDTH = 4;
const LONG_WIDTH = 12;
const KINDS = {action: 'aaaa', reconciliationRun: 'bbbb', smallActionRun: 'cccc', waveRun: 'dddd', stalledRow: 'eeee'};
const VOLUME_ID_SHAPE = /^[a-f]{8}-[a-f]{4}-[a-f]{4}-[a-f]{4}-[a-f]{12}$/;

/**
 * @description An eight-letter token for one run.
 *
 * @param {Function} [random] A source of numbers in [0, 1), default Math.random.
 *
 * @returns {string}
 */
function newRunToken(random = Math.random)
{
	let token = '';
	for(let index = 0; index < RUN_TOKEN_LENGTH; index++)
	{
		token += ID_ALPHABET[Math.min(ID_ALPHABET.length - 1, Math.floor(random() * ID_ALPHABET.length))];
	}
	return token;
}

/**
 * @description A number in base 6 spelled in the id alphabet, left-padded with `a` to the width.
 *
 * @param {number} value The number, zero or more.
 * @param {number} width The letters to fill.
 *
 * @returns {string}
 */
function letterOrdinal(value, width)
{
	let remaining = value;
	let text = '';
	do
	{
		text = ID_ALPHABET[remaining % ID_ALPHABET.length] + text;
		remaining = Math.floor(remaining / ID_ALPHABET.length);
	}
	while(remaining > 0);
	return text.padStart(width, ID_ALPHABET[0]);
}

/**
 * @description A harness id: `<token>-<kind>-<first>-<second>-<ordinal>` in the 8-4-4-4-12 tracking-id shape.
 *
 * @param {string} kind One of KINDS.
 * @param {string} runToken The run's eight-letter token.
 * @param {number} first The first number (a root or action ordinal).
 * @param {number} second The second number (a depth or launch index).
 * @param {number} ordinal The ordinal within the first two.
 *
 * @returns {string}
 */
function mintVolumeId(kind, runToken, first, second, ordinal)
{
	return `${runToken}-${kind}-${letterOrdinal(first, SHORT_WIDTH)}-${letterOrdinal(second, SHORT_WIDTH)}-${letterOrdinal(ordinal, LONG_WIDTH)}`;
}

/**
 * @description A fresh manifest for a run, with every collection empty and no stage recorded.
 *
 * @param {object} run `{mode, size, runToken, org, startedAt, shape}`.
 *
 * @returns {object}
 */
function createManifest({mode, size, runToken, org, startedAt, shape})
{
	return {
		version: MANIFEST_VERSION,
		mode,
		size,
		runToken,
		org,
		startedAt,
		shape,
		stages: {},
		actions: [],
		roots: [],
		synthesized: {chainRows: 0, logRows: 0, stalledRows: [], startedStepRows: []},
		operatorWave: {retries: [], restarts: [], aborts: [], killSwitch: null, deadJobStalls: [], stallProbes: []},
		watchdog: null,
		batches: [],
		drainRate: null
	};
}

/**
 * @description The manifest at a path, or null when there is none.
 *
 * @param {string} filePath The manifest file.
 *
 * @returns {object|null}
 */
function readManifest(filePath)
{
	if(!fs.existsSync(filePath))
	{
		return null;
	}
	return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

/**
 * @description Writes the manifest atomically: to a sibling file first, then renamed into place.
 *
 * @param {string} filePath The manifest file.
 * @param {object} manifest The manifest.
 */
function writeManifest(filePath, manifest)
{
	fs.mkdirSync(path.dirname(filePath), {recursive: true});
	const temporary = `${filePath}.writing`;
	fs.writeFileSync(temporary, `${JSON.stringify(manifest, null, '\t')}\n`, 'utf8');
	fs.renameSync(temporary, filePath);
}

/**
 * @description Records a stage's outcome with the instant it finished.
 *
 * @param {object} manifest The manifest.
 * @param {string} stage One of STAGES.
 * @param {object} record The stage's record; `ok: false` with a `reason` marks a failure.
 *
 * @returns {object} The manifest.
 */
function recordStage(manifest, stage, record)
{
	if(!STAGES.includes(stage))
	{
		throw new Error(`Unknown stage ${stage}`);
	}
	manifest.stages[stage] = {...record, finishedAt: new Date().toISOString()};
	return manifest;
}

/**
 * @description Whether a stage finished and did not fail.
 *
 * @param {object} manifest The manifest, possibly null.
 * @param {string} stage One of STAGES.
 *
 * @returns {boolean}
 */
function isStageDone(manifest, stage)
{
	return Boolean(manifest?.stages?.[stage]?.finishedAt) && manifest.stages[stage].ok !== false;
}

/**
 * @description Refuses to continue a run whose mode, size or org differ from the manifest's.
 *
 * @param {object} manifest The manifest.
 * @param {object} options `{mode, size, alias}` as asked on the command line.
 */
function assertSameRun(manifest, {mode, size, alias})
{
	if(manifest.mode !== mode)
	{
		throw new Error(`The manifest is a ${manifest.mode} run; this command asked for mode ${mode}. Run teardown or pick another output directory.`);
	}
	if(Number(manifest.size) !== Number(size))
	{
		throw new Error(`The manifest is a size ${manifest.size} run; this command asked for size ${size}. Run teardown or pick another output directory.`);
	}
	const foreign = describeForeignManifest(manifest, {alias});
	if(foreign)
	{
		throw new Error(foreign);
	}
}

/**
 * @description Why a manifest does not belong to the org a command targets, or null when it does. A manifest belongs
 * to another org when it names another alias, or when it names this alias but recorded another run user: the alias
 * was then pointed at a new org and the org the manifest was written on is gone. Teardown reads the manifest's ids,
 * so running it against the wrong org fails or touches the wrong rows. The manifest is never deleted for the
 * operator: it may hold a staged run on another org that is still alive and that a later teardown needs.
 *
 * @param {object|null} manifest The manifest on disk, or null when there is none.
 * @param {object} target `{alias, userId, manifestPath, unreachable}`: the org the command targets, the id of the user
 *                        it signs in as when known, where the manifest lives, and the reason the org could not be reached
 *                        when that is why the user id is unknown.
 *
 * @returns {string|null}
 */
function describeForeignManifest(manifest, {alias, userId, manifestPath, unreachable})
{
	if(!manifest?.org || alias === undefined)
	{
		return null;
	}
	const recorded = manifest.org.alias;
	const where = manifestPath ? ` at ${manifestPath}` : '';
	const archive = `Archive the manifest before you go on: move it out of the way, for example to manifest-${manifest.runToken}-${recorded}.json in the same folder. `
		+ `It is not deleted for you, because it may hold a staged run on org ${recorded} that a later teardown on that org needs.`;
	if(recorded !== alias)
	{
		return `The manifest${where} belongs to org ${recorded}, but this command targets org ${alias} (SF_SUBSCRIBER_ORG_ALIAS or --org). ${archive}`;
	}
	if(unreachable)
	{
		return `The manifest${where} belongs to org ${recorded}, and that org could not be reached (${unreachable}); it may have been deleted. ${archive}`;
	}
	if(userId && manifest.org.userId && manifest.org.userId !== userId)
	{
		return `The manifest${where} belongs to an earlier org named ${recorded} (run user ${manifest.org.userId}), but the alias ${alias} now opens another org `
			+ `(run user ${userId}); the org the manifest was written on no longer exists. ${archive}`;
	}
	return null;
}

/**
 * @description One stage's line for the screen: its outcome, when it finished, and why it failed if it did.
 *
 * @param {string} stage The stage name.
 * @param {object} [record] The stage's record, absent when it has not run.
 *
 * @returns {string}
 */
function describeStage(stage, record)
{
	if(!record)
	{
		return `  ${stage}: not run`;
	}
	const reason = record.reason ? `; ${record.reason}` : '';
	const reused = record.reused ? ' (reused)' : '';
	return `  ${stage}: ${record.ok === false ? 'FAILED' : 'ok'} at ${record.finishedAt}${reason}${reused}`;
}

/**
 * @description The manifest as one screen: the run, every stage with its outcome and reason, the counts and the rate.
 *
 * @param {object|null} manifest The manifest, or null when there is none.
 * @param {string} filePath Where it was looked for.
 *
 * @returns {string}
 */
function describeManifest(manifest, filePath)
{
	if(!manifest)
	{
		return `No manifest at ${filePath}; nothing has run here.`;
	}
	const {org, operatorWave, watchdog, drainRate, synthesized} = manifest;
	const lines = [
		`${manifest.mode} run, size ${manifest.size}, token ${manifest.runToken}, org ${org.alias} [${org.namespacePrefix || 'no namespace'}], `
			+ `started ${manifest.startedAt}`
	];
	for(const stage of STAGES)
	{
		lines.push(describeStage(stage, manifest.stages[stage]));
	}
	const synthesizedActions = manifest.actions.filter((action) => action.synthesized).length;
	lines.push(`  actions ${manifest.actions.length} (${synthesizedActions} synthesized), roots ${manifest.roots.length}, `
			+ `synthesized rows ${synthesized.chainRows} chains and ${synthesized.logRows} entries`);
	const watchdogText = watchdog && watchdog.scheduled ? `scheduled at ${watchdog.scheduledAt}` : 'not scheduled';
	lines.push(`  wave: ${operatorWave.retries.length} retries, ${operatorWave.restarts.length} restarts, ${operatorWave.aborts.length} aborts, `
			+ `${operatorWave.deadJobStalls.length} dead-job stalls; watchdog ${watchdogText}`);
	// A manifest written before the started-step rows existed has no list for them.
	const startedStepRows = synthesized.startedStepRows || [];
	lines.push(`  synthesized Stalled rows: ${synthesized.stalledRows.length} screen-fixture Stalled rows and ${startedStepRows.length} started-step Stalled rows`);
	const rateText = drainRate ? `${drainRate.jobsPerMinute} jobs per minute, peak active ${drainRate.peak.active}, peak holding ${drainRate.peak.holding}` : 'not measured';
	lines.push(`  drain rate: ${rateText}${manifest.tornDownAt ? `; torn down ${manifest.tornDownAt}` : ''}`);
	return lines.join('\n');
}

module.exports = {
	MANIFEST_VERSION,
	STAGES,
	KINDS,
	VOLUME_ID_SHAPE,
	newRunToken,
	letterOrdinal,
	mintVolumeId,
	createManifest,
	readManifest,
	writeManifest,
	recordStage,
	isStageDone,
	assertSameRun,
	describeForeignManifest,
	describeManifest
};
