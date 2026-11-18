// SPDX-License-Identifier: Apache-2.0
// Turns the elastic limits probe's scripts, and this section's own, into the Apex the driver sends: the tokens a
// script names in its header are filled, `kern.` and `kern__` are rewritten for the org's namespace, and in a dry run
// the script is made to stop before its first statement, so it is compiled and nothing in it runs.
'use strict';
const fs = require('fs');
const path = require('path');

const REPOSITORY_ROOT = path.resolve(__dirname, '..', '..', '..');
const PROBE_DIRECTORY = path.join(REPOSITORY_ROOT, 'release-testing', 'scripts', 'elastic-limits-probe');
const SECTION_DIRECTORY = __dirname;
const LOG_CLEANUP_SCRIPT = path.join(REPOSITORY_ROOT, 'release-testing', 'scripts', 'section-84-outbound-retry-live-log-cleanup.apex');
const PACKAGE_NAMESPACE = 'kern';
const TOKEN = /__[A-Z][A-Z_]+__/g;
const APEX_NAMESPACE_REFERENCE = /\bkern\./g;
const FIELD_NAMESPACE_REFERENCE = /\bkern__/g;
const DRY_RUN_MARKER = 'SECTION89 DRY RUN compiled';
// The first statement of a dry-run script. A condition the compiler cannot decide keeps the rest of the script reachable.
const DRY_RUN_STOP = `if(Datetime.now() != null)\n{\n\tthrow new IllegalArgumentException('${DRY_RUN_MARKER}');\n}\n`;
// Classes a script needs that a dry-run org may not have: each stands in only for compiling and never runs.
const STAND_INS = {
	API_RetryLiveGet: 'public class API_RetryLiveGet\n{\n}\n',
	AccountArchiveProcessor: 'public class AccountArchiveProcessor implements kern.IF_Async.Processable\n{\n\tpublic void execute(List<Object> items)\n\t{\n\t}\n}\n',
	ElasticProbeFiller: 'public class ElasticProbeFiller implements Queueable\n{\n\tpublic void execute(QueueableContext context)\n\t{\n\t}\n}\n'
};

const SCRIPT_FILES = {
	readBudget: path.join(PROBE_DIRECTORY, 'read-budget.apex'),
	spendBudget: path.join(PROBE_DIRECTORY, 'spend-budget.apex'),
	insertOutboundCall: path.join(PROBE_DIRECTORY, 'insert-outbound-call.apex'),
	launchAdaptiveProcessor: path.join(PROBE_DIRECTORY, 'launch-adaptive-processor.apex'),
	scheduleOnce: path.join(PROBE_DIRECTORY, 'schedule-once.apex'),
	cleanUp: path.join(PROBE_DIRECTORY, 'clean-up.apex'),
	logCleanup: LOG_CLEANUP_SCRIPT,
	circuitBreaker: path.join(SECTION_DIRECTORY, 'circuit-breaker.apex'),
	abortSchedule: path.join(SECTION_DIRECTORY, 'abort-schedule.apex'),
	abortSchedulesByName: path.join(SECTION_DIRECTORY, 'abort-schedules-by-name.apex'),
	abortProbeJobs: path.join(SECTION_DIRECTORY, 'abort-probe-jobs.apex')
};

/**
 * @description Rewrites the package's `kern.` and `kern__` references for the org's namespace: kept on a namespaced
 * install, renamed on a copy installed under another namespace, removed on a copy with no namespace.
 *
 * @param {string} apex The script.
 * @param {string} namespace The org's namespace for Kern, or '' when Kern has none there.
 *
 * @returns {string}
 */
// noinspection FunctionWithMultipleReturnPointsJS
function applyNamespace(apex, namespace)
{
	if(namespace === PACKAGE_NAMESPACE)
	{
		return apex;
	}
	return apex.replace(APEX_NAMESPACE_REFERENCE, namespace ? `${namespace}.` : '').replace(FIELD_NAMESPACE_REFERENCE, namespace ? `${namespace}__` : '');
}

/**
 * @description A script's text with its tokens filled. Every token the text carries must be given a value.
 *
 * @param {string} text The script.
 * @param {object} values Token (such as `__MODE__`) to value.
 * @param {string} name The script's name, for the error.
 *
 * @returns {string}
 */
function fillTokens(text, values, name)
{
	let filled = text;
	for(const [token, value] of Object.entries(values))
	{
		filled = filled.split(token).join(String(value));
	}
	const unfilled = [...new Set(filled.match(TOKEN) || [])];
	if(unfilled.length > 0)
	{
		throw new Error(`${name} still carries ${unfilled.join(', ')}`);
	}
	return filled;
}

/**
 * @description Makes a script stop before its first statement, and adds a stand-in for each class it names that the org
 * lacks, so the org compiles it and nothing in it runs or is saved.
 *
 * @param {string} apex The filled script.
 * @param {string[]} missingClasses The subscriber classes the org does not have.
 *
 * @returns {string}
 */
function makeDryRun(apex, missingClasses)
{
	const standIns = missingClasses.filter((name) => STAND_INS[name] && new RegExp(`\\b${name}\\b`).test(apex)).map((name) => STAND_INS[name]);
	return `${DRY_RUN_STOP}${apex}\n${standIns.join('')}`;
}

/**
 * @description The Apex to send for one script. Its lines always end in a plain line break (\n), also when a Windows
 * checkout saved the script file with Windows line breaks (\r\n), so the driver sends the same Apex on every machine.
 *
 * @param {string} script A key of SCRIPT_FILES.
 * @param {object} [options] `values` (tokens), `namespace` (default 'kern'), `dryRun`, `missingClasses` (for a dry run).
 *
 * @returns {string}
 */
function renderScript(script, {values = {}, namespace = PACKAGE_NAMESPACE, dryRun = false, missingClasses = []} = {})
{
	const file = SCRIPT_FILES[script];
	if(!file)
	{
		throw new Error(`No script named ${script}`);
	}
	const apex = fillTokens(fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n'), values, script);
	return applyNamespace(dryRun ? makeDryRun(apex, missingClasses) : apex, namespace);
}

/**
 * @description Whether a dry-run script compiled and then stopped where the dry run stops it.
 *
 * @param {object} outcome The outcome of running it: `{compiled, compileProblem, exceptionMessage}`.
 *
 * @returns {boolean}
 */
function isDryRunStop(outcome)
{
	return outcome.compiled === true && !outcome.compileProblem && String(outcome.exceptionMessage ?? '').includes(DRY_RUN_MARKER);
}

/**
 * @description The probe's Apex settings file with the allowance set to a number: the probe's `settings-1c` file with
 * its override replaced.
 *
 * @param {number} allowance The 24-hour allowance of background Apex jobs to set.
 *
 * @returns {string}
 */
function renderLoweredSettings(allowance)
{
	if(!Number.isInteger(allowance) || allowance < 1)
	{
		throw new Error(`An allowance must be a whole number of at least 1, not ${allowance}`);
	}
	const text = fs.readFileSync(path.join(PROBE_DIRECTORY, 'settings-1c', 'Apex.settings-meta.xml'), 'utf8');
	return text.replace(/<asyncApexExecutionsOverride>\d+<\/asyncApexExecutionsOverride>/, `<asyncApexExecutionsOverride>${allowance}</asyncApexExecutionsOverride>`);
}

/**
 * @description The probe's settings file that puts the allowance back (a blank override, never 0).
 *
 * @returns {string}
 */
function renderRestoreSettings()
{
	return fs.readFileSync(path.join(PROBE_DIRECTORY, 'settings-restore', 'Apex.settings-meta.xml'), 'utf8');
}

/**
 * @description The source of one of the probe's classes and its metadata file, from the probe's `classes/` folder.
 *
 * @param {string} name The class, such as `ElasticProbeFiller`.
 *
 * @returns {{source: string, metadata: string}|null} Null when the probe has no class of that name.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function readProbeClass(name)
{
	const directory = path.join(PROBE_DIRECTORY, 'classes');
	const source = path.join(directory, `${name}.cls`);
	if(!/^\w+$/.test(name) || !fs.existsSync(source))
	{
		return null;
	}
	return {source: fs.readFileSync(source, 'utf8'), metadata: fs.readFileSync(path.join(directory, `${name}.cls-meta.xml`), 'utf8')};
}

/**
 * @description The source of the filler job class the spend script queues, and its metadata file.
 *
 * @returns {{source: string, metadata: string}}
 */
function readFillerClass()
{
	return readProbeClass('ElasticProbeFiller');
}

/**
 * @description What an Apex settings file says about the allowance: the override, and whether elastic limits are on.
 *
 * @param {string} text The settings file.
 *
 * @returns {{override: number|null, elastic: boolean|null}} `override` is null when it is blank or missing (no
 *          override, so the licensed maximum holds); `elastic` is null when the file does not say.
 */
function readApexSettings(text)
{
	const override = String(text ?? '').match(/<asyncApexExecutionsOverride>\s*(\d+)\s*<\/asyncApexExecutionsOverride>/);
	const elastic = String(text ?? '').match(/<enableAsyncApexElasticExecutions>\s*(true|false)\s*<\/enableAsyncApexElasticExecutions>/);
	return {override: override ? Number(override[1]) : null, elastic: elastic ? elastic[1] === 'true' : null};
}

module.exports = {
	SCRIPT_FILES, STAND_INS, DRY_RUN_MARKER, applyNamespace, fillTokens, makeDryRun, renderScript, isDryRunStop, renderLoweredSettings,
	renderRestoreSettings, readFillerClass, readProbeClass, readApexSettings
};
