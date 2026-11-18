// SPDX-License-Identifier: Apache-2.0
// The steps of runbook section 89 in order, and the clean-up that always follows once anything on the org has changed.
// Each step prints one `SECTION89 <step> PASS|FAIL|BLOCKED|INTERRUPTED <reason>` line and its measured values; the run
// ends with `SECTION89 RESULT PASS|FAIL|BLOCKED`.
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const lines = require('./probe-lines');
const scripts = require('./probe-scripts');
const checks = require('./checks');
const {InterruptedError, pollUntil, waitUntil} = require('./poll');

const SECONDS = 1_000;
const MINUTES = 60 * SECONDS;
// The state gate reads twice, this far apart, as the probe's README says.
const GATE_INTERVAL_MILLISECONDS = 2 * MINUTES;
// The probe's README waits at most 20 minutes for a quiet org with elastic limits off.
const GATE_TIME_LIMIT_MILLISECONDS = 20 * MINUTES;
// Every poll reads the org this often while it waits (the rule is every 30 to 60 seconds).
const POLL_INTERVAL_MILLISECONDS = 45 * SECONDS;
const FAST_POLL_INTERVAL_MILLISECONDS = 30 * SECONDS;
// Filler jobs that do nothing end in a minute or two; a slow queue can take longer. The spend waits this long.
const SPEND_TIME_LIMIT_MILLISECONDS = 10 * MINUTES;
// The first job of the chainable launch waits one minute, and a delayed Queueable can start some minutes late.
const NEXT_HOP_TIME_LIMIT_MILLISECONDS = 10 * MINUTES;
// Log entries land seconds after their transaction, through a platform event.
const LOG_TIME_LIMIT_MILLISECONDS = 3 * MINUTES;
// A flow's scheduled path can start several minutes after its time, and the handler's own retry adds a minute and a
// second scheduled path.
const RETRY_TIME_LIMIT_MILLISECONDS = 15 * MINUTES;
// The watchdog's schedule fires on the next minute boundary at least a minute out, and a scheduled job can start late.
const WATCHDOG_TIME_LIMIT_MILLISECONDS = 10 * MINUTES;
// Section 84's log cleanup runs this long after the last reset, so the reset's own log entry has landed.
const LOG_CLEANUP_WAIT_MILLISECONDS = 30 * SECONDS;
// The dry run's watchdog schedule fires this far out, so it is stopped long before it fires.
const DRY_RUN_SCHEDULE_SECONDS = 600;
// A clean-up action whose `sf` command a Ctrl-C stopped runs once more (on Windows, where Ctrl-C reaches the command).
const CLEAN_UP_ROUNDS = 2;
// The exit code a Windows console Ctrl-C gives the command it ends (0xC000013A); the signal is then empty.
const WINDOWS_CTRL_C_EXIT_CODE = 3_221_225_786;
const FILLER_CLASS = 'ElasticProbeFiller';
const SUBSCRIBER_CLASSES = ['API_RetryLiveGet', 'AccountArchiveProcessor'];
const BREAKER_CLASS = 'API_RetryLiveGet';
const FRAMEWORK_CLASS = 'UTIL_AdaptiveAsynchronousProcessor';
const PROBE_CLASS_PATTERN = 'ElasticProbe%';
const WATCHDOG_SCHEDULE_NAME = 'Elastic Probe Outbound Retry Watchdog';
const DRY_RUN_CRON_ID = '08e000000000000AAA';
const DRY_RUN_JOB_ID = '707000000000000AAA';
// What abort-probe-jobs.apex takes in place of a job id: every job of Kern's adaptive processor that has not ended.
const EVERY_PROCESSOR_JOB = 'all';
// What abort-probe-jobs.apex takes when the run launched no chain: no job of the processor, only the probe's own jobs.
const NO_PROCESSOR_JOB = 'none';
const BLOCKED_ADVICE = 'SECTION89 GUARD Let those calls finish (or use a fresh org), then run section 89 again. Nothing on the org was changed.';

/**
 * @description Thrown by a step whose failure leaves nothing for the later steps to do: the run goes to the clean-up.
 */
class StopError extends Error
{
	/**
	 * @description Builds the error.
	 *
	 * @param {string} message Why the run stops.
	 */
	constructor(message)
	{
		super(message);
		this.name = 'StopError';
	}
}

/**
 * @description A value as it is printed in a VALUE line.
 *
 * @param {*} value The value.
 *
 * @returns {string}
 */
function formatValue(value)
{
	return value instanceof Date ? value.toISOString() : String(value);
}

/**
 * @description Records one step's outcome and prints its line and its values.
 *
 * @param {object} context The run.
 * @param {string} step The step's name, such as `89a`.
 * @param {string} status PASS, FAIL, BLOCKED or INTERRUPTED.
 * @param {string} reason Why, in a few words.
 * @param {object} [values] The measured values the results file records.
 */
function report(context, step, status, reason, values = {})
{
	context.steps.push({step, status, reason, values});
	context.log(`SECTION89 ${step} ${status} ${reason}`);
	const printable = Object.entries(values).filter(([, value]) => value !== undefined && value !== null);
	if(printable.length > 0)
	{
		context.log(`SECTION89 VALUES ${step} ${printable.map(([key, value]) => `${key}=${formatValue(value)}`).join(' ')}`);
	}
}

/**
 * @description Reports a step from a check's outcome.
 *
 * @param {object} context The run.
 * @param {string} step The step's name.
 * @param {object} result The check's outcome `{pass, reasons, values}`.
 * @param {string} passReason What the step proved.
 *
 * @returns {boolean} Whether the step passed.
 */
function reportCheck(context, step, result, passReason)
{
	report(context, step, result.pass ? 'PASS' : 'FAIL', result.pass ? passReason : result.reasons.join('; '), result.values);
	return result.pass;
}

/**
 * @description Adds to a failed check that its wait ran out of time, so the line says the evidence never came.
 *
 * @param {object} result The check's outcome `{pass, reasons, values}`.
 * @param {object} poll What the wait returned `{done}`.
 * @param {number} timeLimit The wait's time limit, in milliseconds.
 *
 * @returns {object} The same outcome.
 */
function noteTimeOut(result, poll, timeLimit)
{
	if(!poll.done && !result.pass && timeLimit > 0)
	{
		result.reasons.unshift(`still not there after ${timeLimit / MINUTES} minutes`);
	}
	return result;
}

/**
 * @description Why an `sf` command counts as stopped by Ctrl-C, or null when it does not. It does when it ended by
 * SIGINT, or with the exit code Windows gives a command a console Ctrl-C ended (there the signal is empty), or when it
 * ended by another signal or failed after a Ctrl-C was seen. A command its time limit stopped, with no Ctrl-C, is not.
 * In the last round of a clean-up action (`lastCleanUpRound`), a Ctrl-C seen earlier no longer counts, so a command
 * that fails there gives its own reason.
 *
 * @param {object} outcome The command's outcome `{exitCode, signal, success, file}`, or the error a failed query threw.
 * @param {object} [signal] The run's `{interrupted, ctrlCSeen, lastCleanUpRound}`.
 * @param {boolean} failed Whether the command failed.
 *
 * @returns {string|null}
 */
// noinspection FunctionWithMultipleReturnPointsJS
function findCtrlCStop(outcome, signal, failed)
{
	if(outcome?.signal === 'SIGINT' || (outcome?.signal && signal?.interrupted))
	{
		return `the sf command was stopped by ${outcome.signal}`;
	}
	if(outcome?.exitCode === WINDOWS_CTRL_C_EXIT_CODE)
	{
		return `the sf command was stopped by Ctrl-C (exit code ${WINDOWS_CTRL_C_EXIT_CODE})`;
	}
	if(hasCtrlCThatCounts(signal) && (outcome?.signal || failed))
	{
		return `the sf command ${outcome?.signal ? `was stopped by ${outcome.signal}` : 'failed'} after Ctrl-C (exit code ${outcome?.exitCode ?? 'unknown'}`
			+ `${outcome?.file ? `; see ${outcome.file}` : ''})`;
	}
	return null;
}

/**
 * @description Whether a Ctrl-C counts against a command that ended by a signal or failed: the run was interrupted, or
 * a Ctrl-C was seen and the clean-up is not in its last round.
 *
 * @param {object} [signal] The run's `{interrupted, ctrlCSeen, lastCleanUpRound}`.
 *
 * @returns {boolean}
 */
function hasCtrlCThatCounts(signal)
{
	return Boolean((signal?.ctrlCSeen && !signal.lastCleanUpRound) || signal?.interrupted);
}

/**
 * @description Makes every `sf` command of the run stop the run when Ctrl-C stopped it (see findCtrlCStop): such a
 * command throws InterruptedError, and no new command starts after Ctrl-C until the clean-up.
 *
 * @param {object} context The run; its `org` is replaced by a watched copy.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function watchCommands(context)
{
	const org = context.org;
	if(org.commandsWatched)
	{
		return;
	}
	const before = () =>
	{
		if(context.signal?.interrupted && !context.signal.cleaningUp)
		{
			throw new InterruptedError('stopped by Ctrl-C');
		}
	};
	const after = (outcome, failed = outcome?.success === false) =>
	{
		const stop = findCtrlCStop(outcome, context.signal, failed);
		if(stop)
		{
			throw new InterruptedError(stop);
		}
		return outcome;
	};
	const watch = (method) => (...parameters) =>
	{
		before();
		return after(method(...parameters));
	};
	context.org = {
		...org,
		commandsWatched: true,
		runApex: watch(org.runApex),
		deploy: watch(org.deploy),
		deleteSource: watch(org.deleteSource),
		retrieve: org.retrieve ? watch(org.retrieve) : undefined,
		query: (...parameters) =>
		{
			before();
			try
			{
				return org.query(...parameters);
			}
			catch(failure)
			{
				after(failure, true);
				throw failure;
			}
		}
	};
}

/**
 * @description Runs one of the section's scripts and returns its debug lines; a script that fails stops the step.
 *
 * @param {object} context The run.
 * @param {string} script A key of the script table.
 * @param {string} label A name for the script copy and its answer file.
 * @param {object} [values] The script's tokens.
 *
 * @returns {string[]}
 */
function runScript(context, script, label, values = {})
{
	const apex = scripts.renderScript(script, {values, namespace: context.namespace});
	const result = context.org.runApex(apex, label);
	if(!result.success)
	{
		throw new Error(`${label} failed: ${result.compileProblem || result.exceptionMessage || `exit code ${result.exitCode}`} (see ${result.file})`);
	}
	return result.debugLines;
}

/**
 * @description Runs read-budget.apex and returns what it printed, parsed.
 *
 * @param {object} context The run.
 * @param {string} label A name for the answer file.
 *
 * @returns {object}
 */
function readBudget(context, label)
{
	context.readCount = (context.readCount ?? 0) + 1;
	return lines.parseReadBudget(runScript(context, 'readBudget', `${label}-${context.readCount}`));
}

/**
 * @description Finds the org's namespace for Kern and the subscriber classes the org lacks.
 *
 * @param {object} context The run; its `namespace` and `missingClasses` are set.
 */
function findOrgShape(context)
{
	const frameworkRows = context.org.query(`SELECT NamespacePrefix FROM ApexClass WHERE Name = '${FRAMEWORK_CLASS}'`, 'namespace');
	if(frameworkRows.length === 0)
	{
		throw new StopError(`Kern is not on the org: no class ${FRAMEWORK_CLASS}`);
	}
	context.namespace = frameworkRows[0].NamespacePrefix ?? '';
	const names = [...SUBSCRIBER_CLASSES, FILLER_CLASS].map((name) => `'${name}'`).join(', ');
	const present = context.org.query(`SELECT Name FROM ApexClass WHERE NamespacePrefix = null AND Name IN (${names})`, 'subscriber-classes').map((row) => row.Name);
	context.missingClasses = [...SUBSCRIBER_CLASSES, FILLER_CLASS].filter((name) => !present.includes(name));
}

/**
 * @description The outbound calls on the org, other than the run's own, that wait to be sent or retried.
 *
 * @param {object} context The run.
 * @param {string} label A name for the answer file.
 *
 * @returns {object[]} `{id, status}` per call.
 */
function readForeignCalls(context, label)
{
	const prefix = context.namespace ? `${context.namespace}__` : '';
	const soql = `SELECT Id, ${prefix}Status__c FROM ${prefix}ApiCall__c WHERE ${prefix}Direction__c = 'Outbound' `
		+ `AND ${prefix}Status__c IN ('Queued', 'Retry', 'Retrying')`;
	const records = context.org.query(soql, label).map((row) => ({id: row.Id, status: row[`${prefix}Status__c`]}));
	return checks.findForeignCalls(records, context.state.ownCallIds);
}

/**
 * @description The org guard, before anything changes: no other outbound call may wait to be sent, because the lower
 * allowance and the watchdog pass reach every call of the org.
 *
 * @param {object} context The run.
 *
 * @returns {boolean} Whether the run may go on.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function guardBeforeStart(context)
{
	const foreign = readForeignCalls(context, 'guard');
	if(foreign.length > 0)
	{
		report(context, 'GUARD', 'BLOCKED', foreign.map((call) => `${call.id}:${call.status}`).join(' '));
		context.log(BLOCKED_ADVICE);
		return false;
	}
	report(context, 'GUARD', 'PASS', 'no other outbound call waits at Queued, Retry or Retrying');
	return true;
}

/**
 * @description The state gate: two reads two minutes apart, again until they agree and nothing runs, or 20 minutes pass.
 *
 * @param {object} context The run.
 * @param {number} timeLimit How long to keep trying, in milliseconds (0 for one pair of reads).
 */
async function runStateGate(context, timeLimit = GATE_TIME_LIMIT_MILLISECONDS)
{
	// Every read of the gate, in order: each pair compares the newest read with the one before it.
	const reads = [readBudget(context, '89a-gate')];
	context.state.runStart = reads[0].budget?.time;
	const result = await pollUntil({
		read: async() =>
		{
			await context.clock.sleep(GATE_INTERVAL_MILLISECONDS);
			const second = readBudget(context, '89a-gate');
			const gate = checks.checkGate(reads.at(-1), second);
			reads.push(second);
			return gate;
		},
		isDone: (gate) => gate.pass,
		intervalMilliseconds: 0,
		timeLimitMilliseconds: timeLimit,
		clock: context.clock
	});
	const gate = noteTimeOut(result.value, result, timeLimit);
	if(!reportCheck(context, '89a', gate, 'two reads two minutes apart agree and nothing of the probe runs') && !context.dryRun)
	{
		throw new StopError('the org is not quiet');
	}
	context.state.used = gate.values.used;
	context.state.maximum = gate.values.maximum;
}

/**
 * @description Builds the temporary project the settings and the probe classes are deployed from (never the repository).
 *
 * @param {object} context The run; its `projectDirectory` is set.
 */
function buildProject(context)
{
	const directory = fs.mkdtempSync(path.join(context.temporaryDirectory ?? os.tmpdir(), 'kern-section-89-'));
	fs.mkdirSync(path.join(directory, 'force-app', 'main', 'default', 'classes'), {recursive: true});
	fs.mkdirSync(path.join(directory, 'force-app', 'main', 'default', 'settings'), {recursive: true});
	fs.writeFileSync(path.join(directory, 'sfdx-project.json'),
		JSON.stringify({packageDirectories: [{path: 'force-app', default: true}], name: 'KernSection89', sourceApiVersion: '68.0'}));
	fs.writeFileSync(path.join(directory, '.forceignore'), '**/__tests__/**\n');
	context.projectDirectory = directory;
	writeProbeClass(context, FILLER_CLASS, scripts.readFillerClass());
}

/**
 * @description Writes one of the probe's classes into the temporary project.
 *
 * @param {object} context The run.
 * @param {string} name The class.
 * @param {{source: string, metadata: string}} probeClass Its source and metadata file.
 */
function writeProbeClass(context, name, probeClass)
{
	const directory = path.join(context.projectDirectory, 'force-app', 'main', 'default', 'classes');
	fs.writeFileSync(path.join(directory, `${name}.cls`), probeClass.source);
	fs.writeFileSync(path.join(directory, `${name}.cls-meta.xml`), probeClass.metadata);
}

/**
 * @description Writes a settings file into the temporary project and deploys it.
 *
 * @param {object} context The run.
 * @param {string} text The settings file.
 * @param {string} label A name for the answer file.
 *
 * @returns {boolean} Whether the deploy succeeded.
 */
function deploySettings(context, text, label)
{
	fs.writeFileSync(settingsFile(context), text);
	return context.org.deploy(context.projectDirectory, 'Settings:Apex', label).success;
}

/**
 * @description Where the Apex settings file lives in the temporary project.
 *
 * @param {object} context The run.
 *
 * @returns {string}
 */
function settingsFile(context)
{
	return path.join(context.projectDirectory, 'force-app', 'main', 'default', 'settings', 'Apex.settings-meta.xml');
}

/**
 * @description Reads the org's Apex settings back: retrieves them into the temporary project and reads the file.
 *
 * @param {object} context The run.
 * @param {string} label A name for the answer file.
 *
 * @returns {{override: number|null, elastic: boolean|null}}
 */
function readSettingsFromOrg(context, label)
{
	const file = settingsFile(context);
	fs.rmSync(file, {force: true});
	const retrieved = context.org.retrieve(context.projectDirectory, 'Settings:Apex', label);
	if(!retrieved.success || !fs.existsSync(file))
	{
		throw new Error(`the settings could not be read back (${retrieved.message || 'no settings file came back'}; see ${retrieved.file})`);
	}
	return scripts.readApexSettings(fs.readFileSync(file, 'utf8'));
}

/**
 * @description Deploys the filler job class the spend script queues.
 *
 * @param {object} context The run.
 */
function deployFiller(context)
{
	context.state.fillerDeployed = true;
	const deployed = context.org.deploy(context.projectDirectory, `ApexClass:${FILLER_CLASS}`, 'filler-deploy');
	if(!deployed.success)
	{
		report(context, 'SETUP', 'FAIL', `the ${FILLER_CLASS} deploy failed: ${deployed.message} (see ${deployed.file})`);
		throw new StopError('the filler class is not on the org');
	}
	report(context, 'SETUP', 'PASS', `${FILLER_CLASS} deployed from a temporary project`);
}

/**
 * @description 89b: lowers the allowance to the used count plus 10.
 *
 * @param {object} context The run.
 */
function lowerAllowance(context)
{
	context.state.plan = checks.planAllowance(context.state.used);
	context.state.lowered = true;
	const deployed = deploySettings(context, scripts.renderLoweredSettings(context.state.plan.allowance), '89b-settings');
	const read = readBudget(context, '89b-lowered');
	if(!reportCheck(context, '89b', checks.checkLowered(deployed, read, context.state.plan.allowance), `the allowance reads ${context.state.plan.allowance}`))
	{
		throw new StopError('the allowance could not be lowered');
	}
}

/**
 * @description Spends the allowance until a number of places is left.
 *
 * @param {object} context The run.
 * @param {number} leave How many places to leave.
 * @param {string} label A name for the answer files.
 *
 * @returns {object} The spend, parsed.
 */
function spendTo(context, leave, label)
{
	return lines.parseSpend(runScript(context, 'spendBudget', label, {__LEAVE__: leave, __BATCH__: 50}));
}

/**
 * @description 89c: spends the allowance until one place is left and waits for the filler jobs to end. Salesforce may
 * count a filler job only once it runs, so a read taken while jobs still wait can show too many places left: the step
 * spends again only when no job is waiting or running and more than one place is left (the rolling 24 hours freed one).
 *
 * @param {object} context The run.
 */
async function spendToLaunchLine(context)
{
	let queued = spendTo(context, checks.LEAVE_BEFORE_LAUNCH, '89c-spend').queued ?? 0;
	const result = await pollUntil({
		read: () =>
		{
			const read = readBudget(context, '89c-spent');
			if(read.gate?.liveJobs === 0 && read.budget && read.budget.remaining > checks.LEAVE_BEFORE_LAUNCH)
			{
				queued += spendTo(context, checks.LEAVE_BEFORE_LAUNCH, '89c-spend-again').queued ?? 0;
			}
			return read;
		},
		isDone: (read) => checks.checkSpentToLaunchLine(read).pass,
		intervalMilliseconds: POLL_INTERVAL_MILLISECONDS,
		timeLimitMilliseconds: SPEND_TIME_LIMIT_MILLISECONDS,
		clock: context.clock
	});
	const outcome = noteTimeOut(checks.checkSpentToLaunchLine(result.value), result, SPEND_TIME_LIMIT_MILLISECONDS);
	outcome.values = {...outcome.values, queued, planned: context.state.plan.firstSpend};
	if(!reportCheck(context, '89c', outcome, `spent until ${checks.LEAVE_BEFORE_LAUNCH} place is left and every filler job ended`))
	{
		throw new StopError('the allowance could not be spent to the launch line');
	}
}

/**
 * @description The step between 89c and 89d: a chainable launch whose first job is accepted and whose second job,
 * started from the first job's Finalizer at the limit, is refused and logged with the items it did not reach. Step 89c
 * left one place, and no filler job is queued after the launch: the chain's first job takes that last place, at once
 * when Salesforce counts a job as soon as it is queued, or when the job runs when Salesforce counts a job only then.
 * The read straight after the launch tells which (see checks.checkPlacesLeftAfterLaunch). Any other count fails the
 * step and stops the run before the chain's first job runs, with nothing more spent.
 *
 * @param {object} context The run.
 */
// noinspection FunctionWithMultipleReturnPointsJS
async function runRefusedNextHop(context)
{
	const state = context.state;
	// Until the launch's answer is read, the clean-up stops every waiting job of the processor, not one job by its id.
	state.chainJobId = EVERY_PROCESSOR_JOB;
	const launch = lines.parseLauncher(runScript(context, 'launchAdaptiveProcessor', '89c-hop-launch', {
		__ITEMS__: checks.LAUNCH_ITEMS, __DELAY__: 1, __RUNS__: 1, __STRATEGY__: 'chainable', __JOB_SIZE__: checks.LAUNCH_JOB_SIZE
	}));
	state.chainJobId = launch.jobId;
	if(launch.jobId)
	{
		state.probeJobIds.push(launch.jobId);
	}
	const isChainStarted = launch.accepted && checks.isProcessorQueueable(launch);
	if(!isChainStarted)
	{
		reportCheck(context, '89c-hop', checks.checkNextHop(launch, readBudget(context, '89c-hop-refused'), context.state.runStart), '');
		return;
	}
	const afterLaunch = checks.checkPlacesLeftAfterLaunch(readBudget(context, '89c-hop-after-launch'), launch.jobId);
	if(afterLaunch.values.countsWhen === checks.COUNTED_WHEN_NOT_MEASURED)
	{
		context.log(`SECTION89 89c-hop The chain's first job had already left the queue (${afterLaunch.values.firstJobStatusAfterLaunch}) by the read `
			+ 'after the launch, so when Salesforce counts a job was not measured; the step goes on.');
	}
	if(!afterLaunch.pass)
	{
		afterLaunch.reasons.push('nothing was spent after the launch, and the run goes to the clean-up');
		reportCheck(context, '89c-hop', {...afterLaunch, values: {...afterLaunch.values, firstJobId: launch.jobId}}, '');
		throw new StopError('the places left after the launch do not prove that the chain\'s next job will be refused');
	}
	const result = await pollUntil({
		read: () => readBudget(context, '89c-hop-wait'),
		isDone: (read) => checks.isNextHopSettled(read, launch.jobId, context.state.runStart),
		intervalMilliseconds: FAST_POLL_INTERVAL_MILLISECONDS,
		timeLimitMilliseconds: NEXT_HOP_TIME_LIMIT_MILLISECONDS,
		clock: context.clock
	});
	const outcome = noteTimeOut(checks.checkNextHop(launch, result.value, context.state.runStart), result, NEXT_HOP_TIME_LIMIT_MILLISECONDS);
	outcome.values = {...outcome.values, ...afterLaunch.values};
	if(!outcome.pass)
	{
		// The next job was not refused as planned, so the count straight after the launch proves nothing about it.
		delete outcome.values.countsWhen;
	}
	reportCheck(context, '89c-hop', outcome, 'the first job ran and Completed; its next job was refused at the 24-hour limit and logged with the second and third Accounts');
}

/**
 * @description Whether the save of 89d passed and left a call with a retry time, so the run can follow that call.
 *
 * @param {object} saved The outcome of the save.
 *
 * @returns {boolean}
 */
function hasCallToFollow(saved)
{
	return saved.pass && Boolean(saved.values.callId && saved.values.nextRetry);
}

/**
 * @description 89d: saves one call at Queued at the limit, then reads it a minute later with the Flow action's warning.
 * When a place is left before the save (the rolling 24 hours freed one), it first spends to 0 and, as 89c does, waits
 * until no filler job waits or runs and no place is left: Salesforce may count a filler job only once it runs.
 *
 * @param {object} context The run.
 */
// noinspection FunctionWithMultipleReturnPointsJS
async function saveQueuedCallAtLimit(context)
{
	const before = readBudget(context, '89d-before');
	if(before.budget && before.budget.remaining > 0)
	{
		const queued = spendTo(context, 0, '89d-spend').queued ?? 0;
		const result = await pollUntil({
			read: () => readBudget(context, '89d-spent'),
			isDone: (read) => checks.checkSpentToLimit(read).pass,
			intervalMilliseconds: POLL_INTERVAL_MILLISECONDS,
			timeLimitMilliseconds: SPEND_TIME_LIMIT_MILLISECONDS,
			clock: context.clock
		});
		const spent = noteTimeOut(checks.checkSpentToLimit(result.value), result, SPEND_TIME_LIMIT_MILLISECONDS);
		if(!spent.pass)
		{
			spent.reasons.push('a place was left before the save and the spend did not use it, so no call was saved');
			reportCheck(context, '89d', {...spent, values: {...spent.values, remainingBefore: before.budget.remaining, queued}}, '');
			return;
		}
	}
	const insert = lines.parseInsert(runScript(context, 'insertOutboundCall', '89d-insert', {__MODE__: 'queued'}));
	const saved = checks.checkQueuedInsert(insert);
	if(saved.values.callId)
	{
		context.state.ownCallIds.push(saved.values.callId);
		context.state.firstCall = saved.values;
	}
	if(!hasCallToFollow(saved))
	{
		reportCheck(context, '89d', saved, '');
		return;
	}
	await context.clock.sleep(FAST_POLL_INTERVAL_MILLISECONDS);
	const result = await pollUntil({
		read: () => readBudget(context, '89d-waiting'),
		isDone: (read) => checks.findFlowActionWarnings(read, insert.start.time).length > 0,
		intervalMilliseconds: FAST_POLL_INTERVAL_MILLISECONDS,
		timeLimitMilliseconds: LOG_TIME_LIMIT_MILLISECONDS,
		clock: context.clock
	});
	const waiting = noteTimeOut(checks.checkQueuedWaiting(result.value, saved.values.callId, saved.values.nextRetry, insert.start.time), result,
		LOG_TIME_LIMIT_MILLISECONDS);
	reportCheck(context, '89d', {pass: waiting.pass, reasons: waiting.reasons, values: {...saved.values, ...waiting.values}},
		'the save succeeded; the call waits at Retry with its retry time, the refused-start text and no issue; the Flow action warned once');
}

/**
 * @description 89e: puts the allowance back with a blank override, and checks the call has not moved.
 *
 * @param {object} context The run.
 */
function restoreAllowance(context)
{
	const deployed = deploySettings(context, scripts.renderRestoreSettings(), '89e-settings');
	context.state.restored = deployed;
	const read = readBudget(context, '89e-restored');
	const first = context.state.firstCall;
	const result = checks.checkRestored(deployed, read, context.state.maximum, first?.callId ?? null, first?.nextRetry ?? null);
	context.state.restoredAt = result.values.restoredAt;
	reportCheck(context, '89e', result, 'the licensed maximum is back and the call still waits for its retry time');
}

/**
 * @description 89f: waits for the call's retry time and follows the two sends until the call ends.
 *
 * @param {object} context The run.
 */
// noinspection FunctionWithMultipleReturnPointsJS
async function followRetry(context)
{
	const first = context.state.firstCall;
	if(!first?.callId || !first.nextRetry || !context.state.restoredAt)
	{
		report(context, '89f', 'FAIL', 'skipped: 89d saved no call with a retry time, or 89e did not read back');
		return;
	}
	await waitUntil(first.nextRetry.getTime(), context.clock);
	const result = await pollUntil({
		read: () => readBudget(context, '89f-retry'),
		isDone: (read) => checks.isRetrySettled(read, first.callId),
		intervalMilliseconds: POLL_INTERVAL_MILLISECONDS,
		timeLimitMilliseconds: RETRY_TIME_LIMIT_MILLISECONDS,
		clock: context.clock
	});
	reportCheck(context, '89f', noteTimeOut(checks.checkRetrySent(result.value, first.callId, context.state.restoredAt, first.nextRetry), result,
		RETRY_TIME_LIMIT_MILLISECONDS), 'two send jobs, one per due time, both Completed; the call ended Failed with one retry; every issue Open and not marked');
}

/**
 * @description 89g: the org guard again, then one call left at Retrying and one pass of the outbound retry watchdog.
 *
 * @param {object} context The run.
 */
// noinspection FunctionWithMultipleReturnPointsJS
async function runWatchdogPass(context)
{
	const foreign = readForeignCalls(context, '89g-guard');
	if(foreign.length > 0)
	{
		report(context, '89g', 'BLOCKED', foreign.map((call) => `${call.id}:${call.status}`).join(' '));
		context.log('SECTION89 89g Another outbound call appeared during the run, so the watchdog pass was not run. Run section 89 again on a quiet org.');
		return;
	}
	const insert = lines.parseInsert(runScript(context, 'insertOutboundCall', '89g-insert', {__MODE__: 'retrying'}));
	const saved = checks.checkRetryingInsert(insert);
	if(saved.values.callId)
	{
		context.state.ownCallIds.push(saved.values.callId);
	}
	if(!saved.pass)
	{
		reportCheck(context, '89g', saved, '');
		return;
	}
	context.state.scheduleAttempted = true;
	const schedule = lines.parseScheduleOnce(runScript(context, 'scheduleOnce', '89g-schedule', {__JOB__: 'outboundWatchdog', __THRESHOLD__: 1, __SECONDS__: 0}));
	context.state.cronId = schedule?.cronId ?? null;
	const scheduledAt = insert.start.time;
	const runStart = context.state.runStart;
	const result = await pollUntil({
		read: () => readBudget(context, '89g-swept'),
		isDone: (read) => checks.isWatchdogSettled(read, saved.values.callId, scheduledAt, runStart),
		intervalMilliseconds: POLL_INTERVAL_MILLISECONDS,
		timeLimitMilliseconds: WATCHDOG_TIME_LIMIT_MILLISECONDS,
		clock: context.clock
	});
	const outcome = noteTimeOut(checks.checkWatchdog(result.value, saved.values.callId, context.state.firstCall?.callId ?? null, scheduledAt, runStart), result,
		WATCHDOG_TIME_LIMIT_MILLISECONDS);
	outcome.values = {secondCallId: saved.values.callId, cronId: context.state.cronId, ...outcome.values};
	reportCheck(context, '89g', outcome, 'the watchdog marked the call Failed with the lost-job text, one marked issue, one warning; the ended call untouched');
}

/**
 * @description Runs one clean-up action, and keeps its failure as a reason instead of stopping the clean-up. An action
 * whose `sf` command a Ctrl-C stopped runs once more. In that last round a command that fails after a Ctrl-C keeps its
 * own reason (the script's error or what it read back), and the reason then ends with "after a Ctrl-C".
 *
 * @param {object} context The run.
 * @param {string[]} reasons Where a failure is kept.
 * @param {string} name The action.
 * @param {Function} action The action; it returns a reason when what it read back is wrong.
 */
// noinspection FunctionWithMultipleReturnPointsJS
async function attempt(context, reasons, name, action)
{
	const signal = context.signal ?? {};
	for(let round = 1; round <= CLEAN_UP_ROUNDS; round++)
	{
		const lastRound = round === CLEAN_UP_ROUNDS;
		const afterCtrlC = round > 1 && signal.ctrlCSeen ? ', after a Ctrl-C' : '';
		signal.lastCleanUpRound = lastRound;
		try
		{
			const reason = await action();
			if(reason)
			{
				reasons.push(`${name}: ${reason}${afterCtrlC}`);
			}
			return;
		}
		catch(failure)
		{
			if(!(failure instanceof InterruptedError) || lastRound)
			{
				reasons.push(`${name}: ${failure.message}${failure instanceof InterruptedError ? '' : afterCtrlC}`);
				return;
			}
		}
		finally
		{
			signal.lastCleanUpRound = false;
		}
	}
}

/**
 * @description Stops every schedule of the outbound retry watchdog that the probe made, found by its name, then reads
 * again in a second transaction.
 *
 * @param {object} context The run.
 * @param {string} label A name for the answer files.
 *
 * @returns {{reason: string|null, aborted: number|null}} The reason names each schedule still there, with its id.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function stopSchedulesByName(context, label)
{
	const swept = lines.parseScheduleSweep(runScript(context, 'abortSchedulesByName', `${label}-abort`, {__ACTION__: 'abort'}));
	const read = lines.parseScheduleSweep(runScript(context, 'abortSchedulesByName', `${label}-read`, {__ACTION__: 'read'}));
	if(!read.printed)
	{
		return {reason: 'the read after the stop printed no SECTION89 SCHEDULES line', aborted: swept.aborted};
	}
	const left = read.left.map((schedule) => `${schedule.id} (${schedule.name})`);
	return {reason: left.length > 0 ? `still scheduled: ${left.join(', ')}` : null, aborted: swept.aborted};
}

/**
 * @description Stops the jobs the run left waiting, so none runs after the clean-up or while its class is deleted:
 * every job of a probe class (such as a filler job) that has not ended, and of Kern's adaptive processor the chain's
 * first job by its id, or every job of the processor that has not ended when there is no id (in --restore-only, or
 * when the launch's answer was lost). A job at Queued, Holding or Preparing is aborted; a second transaction then reads
 * each job again. The ids found are kept for the clean-up's last read.
 *
 * @param {object} context The run.
 *
 * @returns {string|null} Each job that has not ended, named with its id, or null.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function stopProbeJobs(context)
{
	const state = context.state;
	const tokens = (action) => ({__JOB_ID__: state.chainJobId ?? NO_PROCESSOR_JOB, __ACTION__: action});
	const stopped = lines.parseStoppedJobs(runScript(context, 'abortProbeJobs', '89h-stop-probe-jobs-abort', tokens('abort')));
	state.stoppedJobs = (state.stoppedJobs ?? 0) + (stopped.aborted ?? 0);
	const read = lines.parseStoppedJobs(runScript(context, 'abortProbeJobs', '89h-stop-probe-jobs-read', tokens('read')));
	for(const job of [...stopped.jobs, ...read.jobs].filter((candidate) => !state.probeJobIds.includes(candidate.id)))
	{
		state.probeJobIds.push(job.id);
	}
	if(!read.printed)
	{
		return 'the read after the stop printed no PROBE STOP JOBS line';
	}
	if(state.chainJobId && state.chainJobId !== EVERY_PROCESSOR_JOB && !read.jobs.some((job) => lines.isSameId(job.id, state.chainJobId)))
	{
		return `the chain's first job ${state.chainJobId} has no job row, so its end cannot be read`;
	}
	const left = read.jobs.filter((job) => checks.LIVE_JOB_STATUSES.includes(job.status))
		.map((job) => `${job.id} (${job.className ? `${job.className} ` : ''}${job.status})`);
	return left.length > 0 || read.left > 0 ? `not ended: ${left.join(', ') || `${read.left} job(s)`}` : null;
}

/**
 * @description Stops the watchdog's schedules by name as a step of its own, for a run that could not read the schedule's
 * id or could not confirm the stop by id. A schedule still there fails the step, named with its id.
 *
 * @param {object} context The run.
 * @param {string} step The step's name.
 * @param {string} label A name for the answer files.
 */
async function runScheduleStopByName(context, step, label)
{
	context.state.scheduleFallbackDone = true;
	const reasons = [];
	let aborted = null;
	await attempt(context, reasons, 'stop by name', () =>
	{
		const stopped = stopSchedulesByName(context, label);
		aborted = stopped.aborted;
		return stopped.reason;
	});
	context.state.scheduleStopped = reasons.length === 0;
	report(context, step, reasons.length === 0 ? 'PASS' : 'FAIL', reasons.length === 0 ? `no ${WATCHDOG_SCHEDULE_NAME} schedule is left` : reasons.join('; '),
		{aborted});
}

/**
 * @description Puts the allowance back for --restore-only and reads it back: the settings are retrieved first, the
 * restore settings (a blank override, never 0) are deployed only when an override or elastic limits are set, and the
 * settings are retrieved again.
 *
 * @param {object} context The run.
 * @param {string[]} notes Where a skipped deploy is noted.
 *
 * @returns {string|null} What is wrong, or null.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function restoreSettingsWithReadBack(context, notes)
{
	const before = readSettingsFromOrg(context, '89h-settings-before');
	if(before.override === null && before.elastic !== true)
	{
		notes.push('the allowance override was already blank');
		return null;
	}
	if(!deploySettings(context, scripts.renderRestoreSettings(), '89h-settings'))
	{
		return 'the settings deploy failed';
	}
	const after = readSettingsFromOrg(context, '89h-settings-after');
	return after.override === null && after.elastic !== true ? null : `the settings read back override=${after.override} elastic=${after.elastic}`;
}

/**
 * @description Deletes every probe class on the org whose source the probe holds, and reads back that none is left.
 *
 * @param {object} context The run.
 *
 * @returns {string|null} What is left, or null.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function removeProbeClasses(context)
{
	const classesQuery = `SELECT Id, Name FROM ApexClass WHERE Name LIKE '${PROBE_CLASS_PATTERN}'`;
	const failed = [];
	for(const name of context.org.query(classesQuery, '89h-classes-present').map((row) => row.Name))
	{
		const probeClass = scripts.readProbeClass(name);
		if(!probeClass)
		{
			continue;
		}
		writeProbeClass(context, name, probeClass);
		if(!context.org.deleteSource(context.projectDirectory, `ApexClass:${name}`, `89h-delete-${name}`).success)
		{
			failed.push(name);
		}
	}
	const left = context.org.query(classesQuery, '89h-classes-left').map((row) => row.Name);
	if(left.length === 0)
	{
		return null;
	}
	return `${left.length} probe class(es) left: ${left.join(', ')}${failed.length > 0 ? ` (the delete failed for ${failed.join(', ')})` : ''}`;
}

/**
 * @description Whether a read shows a probe schedule, or an outbound call waiting to be sent or retried. A read with no
 * PROBE GATE line counts as showing one, because it cannot show that none is left.
 *
 * @param {object} read A read-budget read.
 *
 * @returns {boolean}
 */
function hasProbeScheduleOrPendingCall(read)
{
	return read.gate?.probeSchedules !== 0 || read.gate?.pendingCalls !== 0;
}

/**
 * @description 89h: puts the org back, whatever happened before: first it stops the jobs the run left waiting (the
 * chain's first job and the filler jobs), then it puts back the allowance, the probe's rows and schedules, the circuit
 * breaker, the section's log entries and the probe classes, each read back. Its last read fails on any job of the probe
 * that has not ended.
 *
 * @param {object} context The run.
 */
async function cleanUp(context)
{
	const reasons = [];
	const notes = [];
	const state = context.state;
	if(state.chainJobId || state.fillerDeployed)
	{
		await attempt(context, reasons, 'stop the probe jobs', () => stopProbeJobs(context));
	}
	if(state.restoreOnly)
	{
		await attempt(context, reasons, 'restore the allowance', () => restoreSettingsWithReadBack(context, notes));
	}
	else if(state.lowered && !state.restored)
	{
		await attempt(context, reasons, 'restore the allowance', () =>
		{
			state.restored = deploySettings(context, scripts.renderRestoreSettings(), '89h-settings');
			return state.restored ? null : 'the settings deploy failed';
		});
	}
	await attempt(context, reasons, 'probe clean-up', () =>
	{
		const leftovers = checks.findLeftovers(lines.parseLeft(runScript(context, 'cleanUp', '89h-clean-up', {__KEEP__: 'none'})));
		return leftovers.length > 0 ? `left ${leftovers.join(' ')}` : null;
	});
	if(state.scheduleAttempted || state.restoreOnly)
	{
		await attempt(context, reasons, 'stop the watchdog schedule', () =>
		{
			let confirmed = false;
			if(state.cronId)
			{
				try
				{
					confirmed = runScript(context, 'abortSchedule', '89h-abort-schedule', {__CRON_ID__: state.cronId}).join(' ').includes(' left=0');
				}
				catch(failure)
				{
					if(failure instanceof InterruptedError)
					{
						throw failure;
					}
				}
			}
			return confirmed ? null : stopSchedulesByName(context, '89h-schedules').reason;
		});
	}
	if(context.missingClasses?.includes(BREAKER_CLASS))
	{
		notes.push(`breaker skipped: the org has no ${BREAKER_CLASS}, so no breaker of it was used`);
	}
	else
	{
		await attempt(context, reasons, 'reset the circuit breaker', () =>
		{
			runScript(context, 'circuitBreaker', '89h-breaker-reset', {__ACTION__: 'reset'});
			const answer = runScript(context, 'circuitBreaker', '89h-breaker-read', {__ACTION__: 'read'}).join(' ');
			return answer.includes('state=CLOSED') ? null : `the breaker is not closed: ${answer}`;
		});
	}
	await attempt(context, reasons, 'section 84 log cleanup', async() =>
	{
		await context.clock.sleep(LOG_CLEANUP_WAIT_MILLISECONDS);
		const result = context.org.runApex(scripts.renderScript('logCleanup', {namespace: context.namespace}), '89h-log-cleanup');
		const passed = result.debugLines.some((line) => line.startsWith('SECTION84 PASS 84-log-cleanup'));
		return result.success && passed ? null : `exit code ${result.exitCode}, ${result.debugLines.join(' ') || result.exceptionMessage}`;
	});
	if(state.fillerDeployed || state.restoreOnly)
	{
		await attempt(context, reasons, 'remove the probe classes', () => removeProbeClasses(context));
	}
	let finalMaximum = null;
	await attempt(context, reasons, 'final read', () =>
	{
		const read = readBudget(context, '89h-after');
		finalMaximum = read.budget?.maximum ?? null;
		const wrong = [];
		if(state.maximum !== undefined && read.budget?.maximum !== state.maximum)
		{
			wrong.push(`maximum=${read.budget?.maximum}, not ${state.maximum}`);
		}
		if(hasProbeScheduleOrPendingCall(read))
		{
			wrong.push(`probeSchedules=${read.gate?.probeSchedules} pendingCalls=${read.gate?.pendingCalls}`);
		}
		const liveJobs = checks.findLiveProbeJobs(read, state.probeJobIds);
		if(liveJobs.length > 0)
		{
			wrong.push(`probe jobs not ended: ${liveJobs.map((job) => `${job.id} (${job.className} ${job.status})`).join(', ')}`);
		}
		return wrong.length > 0 ? wrong.join(', ') : null;
	});
	if(context.projectDirectory)
	{
		fs.rmSync(context.projectDirectory, {recursive: true, force: true});
	}
	report(context, '89h', reasons.length === 0 ? 'PASS' : 'FAIL', reasons.length === 0
		? 'the probe jobs have ended; the allowance, the rows, the schedules, the breaker, the log entries and the probe classes are back as they were'
		: reasons.join('; '),
	{maximum: finalMaximum, stoppedJobs: state.stoppedJobs, notes: notes.join('; ') || null});
}

/**
 * @description The dry run, for an org whose allowance cannot be lowered: every script compiled with its tokens filled
 * (each stops before its first statement, so nothing runs or is saved), the settings files rendered, and the watchdog's
 * schedule made and stopped at once. When the schedule's id cannot be read or its stop cannot be confirmed, every
 * watchdog schedule of the probe is stopped by name and read again.
 *
 * @param {object} context The run.
 */
async function runDryRunChecks(context)
{
	const compileList = [
		['spendBudget', {__LEAVE__: checks.LEAVE_BEFORE_LAUNCH, __BATCH__: 50}],
		['spendBudget', {__LEAVE__: 0, __BATCH__: 50}],
		['launchAdaptiveProcessor', {__ITEMS__: checks.LAUNCH_ITEMS, __DELAY__: 1, __RUNS__: 1, __STRATEGY__: 'chainable', __JOB_SIZE__: checks.LAUNCH_JOB_SIZE}],
		['insertOutboundCall', {__MODE__: 'queued'}],
		['insertOutboundCall', {__MODE__: 'retrying'}],
		['scheduleOnce', {__JOB__: 'outboundWatchdog', __THRESHOLD__: 1, __SECONDS__: 0}],
		['cleanUp', {__KEEP__: 'none'}],
		['circuitBreaker', {__ACTION__: 'reset'}],
		['circuitBreaker', {__ACTION__: 'read'}],
		['abortSchedule', {__CRON_ID__: DRY_RUN_CRON_ID}],
		['abortSchedulesByName', {__ACTION__: 'abort'}],
		['abortProbeJobs', {__JOB_ID__: DRY_RUN_JOB_ID, __ACTION__: 'abort'}],
		['logCleanup', {}],
		['readBudget', {}]
	];
	const failures = [];
	compileList.forEach(([script, values], index) =>
	{
		const label = `dry-compile-${String(index + 1).padStart(2, '0')}-${script}`;
		const apex = scripts.renderScript(script, {values, namespace: context.namespace, dryRun: true, missingClasses: context.missingClasses});
		const result = context.org.runApex(apex, label);
		if(!scripts.isDryRunStop(result))
		{
			failures.push(`${label}: ${result.compileProblem || result.exceptionMessage}`);
		}
	});
	report(context, 'DRY-COMPILE', failures.length === 0 ? 'PASS' : 'FAIL', failures.length === 0
		? `${compileList.length} scripts compiled with their tokens filled and stopped before their first statement` : failures.join('; '),
	{namespace: context.namespace || 'none', standIns: context.missingClasses.join(',') || 'none'});
	const allowance = checks.planAllowance(context.state.used ?? 0).allowance;
	const lowered = scripts.renderLoweredSettings(allowance);
	const restore = scripts.renderRestoreSettings();
	const settingsReady = lowered.includes(`<asyncApexExecutionsOverride>${allowance}</asyncApexExecutionsOverride>`) && restore.includes('xsi:nil="true"');
	report(context, 'DRY-SETTINGS', settingsReady ? 'PASS' : 'FAIL', settingsReady
		? `the lowered settings name ${allowance} and the restore settings leave the override blank (not deployed)` : 'a settings file did not render');
	context.state.scheduleAttempted = true;
	const schedule = lines.parseScheduleOnce(runScript(context, 'scheduleOnce', 'dry-schedule', {__JOB__: 'outboundWatchdog', __THRESHOLD__: 1,
		__SECONDS__: DRY_RUN_SCHEDULE_SECONDS}));
	context.state.cronId = schedule?.cronId ?? null;
	const answer = schedule ? runScript(context, 'abortSchedule', 'dry-abort-schedule', {__CRON_ID__: schedule.cronId}).join(' ') : '';
	const stopped = answer.includes('aborted=true') && answer.includes(' left=0');
	context.state.scheduleStopped = stopped;
	report(context, 'DRY-WATCHDOG', stopped ? 'PASS' : 'FAIL', stopped ? 'the outbound retry watchdog was scheduled and stopped before it fired'
		: `the schedule was not made and stopped: ${answer || 'no PROBE SCHEDULE ONCE line'}`, {cronId: schedule?.cronId, name: schedule?.name});
	if(!stopped)
	{
		await runScheduleStopByName(context, 'SCHEDULE-STOP', 'dry-schedules');
	}
}

/**
 * @description Runs section 89, or its dry run, and returns the result. The clean-up runs in the finally path once
 * anything on the org has changed, also after a failure or an interrupt.
 *
 * @param {object} context `{org, clock, log, dryRun, signal, temporaryDirectory}`.
 *
 * @returns {Promise<string>} PASS, FAIL or BLOCKED.
 */
async function runSection(context)
{
	context.steps = [];
	context.state = {ownCallIds: [], probeJobIds: []};
	watchCommands(context);
	let blocked = false;
	try
	{
		context.currentStep = 'SETUP';
		findOrgShape(context);
		requireSubscriberClasses(context);
		context.currentStep = 'GUARD';
		blocked = !guardBeforeStart(context);
		if(!blocked)
		{
			context.currentStep = '89a';
			await runStateGate(context, context.dryRun ? 0 : GATE_TIME_LIMIT_MILLISECONDS);
			await runStepsAfterGate(context);
		}
	}
	catch(failure)
	{
		reportFailure(context, failure);
	}
	finally
	{
		if(!blocked)
		{
			await putBackAfterSection(context);
		}
	}
	return checks.decideResult(context.steps);
}

/**
 * @description Stops the run before anything changes when the org lacks one of the subscriber classes the full run
 * needs. The dry run goes on without them: it compiles stand-ins instead.
 *
 * @param {object} context The run, with its `missingClasses` read.
 */
function requireSubscriberClasses(context)
{
	const missing = context.missingClasses.filter((name) => SUBSCRIBER_CLASSES.includes(name));
	if(!context.dryRun && missing.length > 0)
	{
		report(context, 'SETUP', 'FAIL', `the org lacks ${missing.join(', ')} (Phase 1.4)`);
		throw new StopError('the subscriber classes are missing');
	}
}

/**
 * @description Runs the steps after the state gate, in order: the dry run's checks, or every step of the full run
 * (89b to 89g).
 *
 * @param {object} context The run.
 */
async function runStepsAfterGate(context)
{
	if(context.dryRun)
	{
		context.currentStep = 'DRY-RUN';
		await runDryRunChecks(context);
	}
	else
	{
		await runFullSteps(context);
	}
}

/**
 * @description Runs every step of the full run after the state gate, in order: the set-up of the probe project and its
 * filler class, then 89b to 89g.
 *
 * @param {object} context The run.
 */
async function runFullSteps(context)
{
	const steps = [
		['SETUP', () =>
		{
			buildProject(context);
			deployFiller(context);
		}],
		['89b', lowerAllowance],
		['89c', spendToLaunchLine],
		['89c-hop', runRefusedNextHop],
		['89d', saveQueuedCallAtLimit],
		['89e', restoreAllowance],
		['89f', followRetry],
		['89g', runWatchdogPass]
	];
	for(const [name, runStep] of steps)
	{
		context.currentStep = name;
		await runStep(context);
	}
}

/**
 * @description Records the failure that stopped the run: a Ctrl-C as INTERRUPTED at the current step, a planned stop as
 * STOP, and anything else as ERROR.
 *
 * @param {object} context The run.
 * @param {Error} failure What stopped it.
 */
function reportFailure(context, failure)
{
	if(failure instanceof InterruptedError)
	{
		report(context, context.currentStep, 'INTERRUPTED', `stopped by Ctrl-C (${failure.message}); the org is put back next if anything on it changed`);
	}
	else
	{
		report(context, failure instanceof StopError ? 'STOP' : 'ERROR', 'FAIL', failure.message);
	}
}

/**
 * @description Puts the org back once anything on it has changed: the clean-up (89h) after a full run, or, after a dry
 * run, a stop by name of the watchdog's schedules when their stop was not confirmed.
 *
 * @param {object} context The run.
 */
async function putBackAfterSection(context)
{
	const state = context.state;
	const changed = state.fillerDeployed || state.lowered || state.scheduleAttempted || state.ownCallIds.length > 0;
	if(changed)
	{
		context.signal.cleaningUp = true;
		// ctrlCSeen stays set, so a clean-up command that a Ctrl-C stopped on Windows still runs once more.
		context.signal.interrupted = false;
		if(context.dryRun)
		{
			if(!state.scheduleStopped && !state.scheduleFallbackDone)
			{
				await runScheduleStopByName(context, 'SCHEDULE-STOP', 'dry-schedules-again');
			}
		}
		else
		{
			await cleanUp(context);
		}
	}
}

/**
 * @description --restore-only: runs only the clean-up (89h), on an org where an earlier run was stopped or killed. It
 * needs nothing from that run: it reads Kern's namespace from the org, stops every job of Kern's adaptive processor and of
 * a probe class still at Queued, Holding or Preparing (so the org must run nothing else of the processor's class), puts
 * the allowance back (a blank override) and reads the settings back, stops every probe schedule, removes the probe's
 * rows and classes, resets the circuit breaker and runs the section 84 log cleanup, each read back.
 *
 * @param {object} context `{org, clock, log, signal, temporaryDirectory}`.
 *
 * @returns {Promise<string>} PASS or FAIL.
 */
// noinspection FunctionWithMultipleReturnPointsJS
async function runRestoreOnly(context)
{
	context.steps = [];
	context.state = {ownCallIds: [], probeJobIds: [], restoreOnly: true, chainJobId: EVERY_PROCESSOR_JOB};
	watchCommands(context);
	context.signal.cleaningUp = true;
	context.currentStep = '89h';
	try
	{
		findOrgShape(context);
		buildProject(context);
	}
	catch(failure)
	{
		report(context, '89h', 'FAIL', `the clean-up could not start: ${failure.message}`);
		return checks.decideResult(context.steps);
	}
	await cleanUp(context);
	return checks.decideResult(context.steps);
}

module.exports = {
	runSection, runRestoreOnly, report, findOrgShape, guardBeforeStart, readForeignCalls, runStateGate, cleanUp, runDryRunChecks, findCtrlCStop, StopError, BLOCKED_ADVICE,
	WINDOWS_CTRL_C_EXIT_CODE,
	GATE_INTERVAL_MILLISECONDS, GATE_TIME_LIMIT_MILLISECONDS, SPEND_TIME_LIMIT_MILLISECONDS, NEXT_HOP_TIME_LIMIT_MILLISECONDS, LOG_TIME_LIMIT_MILLISECONDS,
	RETRY_TIME_LIMIT_MILLISECONDS, WATCHDOG_TIME_LIMIT_MILLISECONDS, LOG_CLEANUP_WAIT_MILLISECONDS, FILLER_CLASS
};
