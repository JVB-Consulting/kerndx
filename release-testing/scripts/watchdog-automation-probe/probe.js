#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
/**
 * Watchdog automation probe: does one ordinary flow or Apex trigger on chain run records stop the chain watchdog?
 *
 * What it proves. The chain watchdog recovers stuck chain runs in one scheduled job and keeps a small reserve of
 * queries before each run it recovers. A subscriber's flow or Apex trigger on the chain run object runs inside the
 * watchdog's own saves and spends queries from the same limit of 100. The probe seeds 50 stuck runs, lets the real
 * scheduled watchdog run once, and reads what that one pass did: how many runs it restarted, ended Failed, parked for a
 * later pass or left untouched, how many queries its log entries show, and whether the scheduled job failed. It runs
 * this for each kind of automation (none, a flow with one Get Records, an Apex trigger with one query) and for each
 * recovery path:
 *   - failed:  the stuck step is not safe to run twice, so the watchdog ends the run Failed (one save per run);
 *   - restart: the stuck step is marked safe to run twice, so the watchdog restarts the run (two saves per run).
 *
 * Where to run it. A scratch org with the Kern package installed and no other Stalled chain runs (the watchdog would
 * spend its queries on them too). The running user needs the package's Administrator permission set; `prepare`
 * assigns it. Kern 1.11 is the version this probe was first run on. Kern 1.12 adds the stall time field
 * (StalledAt__c); the seed sets it and the reader prints it when the org has it. The first run on a 1.12 candidate is
 * the first time the probe meets 1.12: read its output with that in mind.
 *
 * Arguments:
 *   node probe.js <command> --org <alias> [--path failed|restart] [--kind none|flow|trigger] [--label <name>]
 *                 [--namespace <prefix>|none] [--work <folder>] [--check-only]
 *   --org        the org alias (required).
 *   --path       seed only: failed or restart.
 *   --kind       automation only: which automation is on afterwards. none switches both off.
 *   --label      pass, wait, read: a name for the pass. pass defaults to the next number; wait and read default to
 *                the latest pass.
 *   --namespace  the package namespace. By default it is read from the org (the namespace of SCHED_ChainWatchdog);
 *                none means the framework is deployed without a namespace.
 *   --work       where the probe keeps its state and every sf output. Default: tmp/watchdog-automation-probe/<org>
 *                under the repository root (git-ignored).
 *   --check-only automation only: validate the deploys without changing the org (sf --dry-run).
 *
 * Commands:
 *   prepare     reads the namespace, assigns the Administrator permission set if missing, says whether the org has
 *               the stall time field, and counts Stalled chain runs that are not the probe's.
 *   automation  switches the flow and the trigger so that only --kind is on. Each switch is one metadata deploy:
 *                 flow on:     sf project deploy start --metadata-dir <work>/stage/flow-on     -o <org> --wait 3
 *                 flow off:    sf project deploy start --metadata-dir <work>/stage/flow-off    -o <org> --wait 3
 *                 trigger on:  sf project deploy start --metadata-dir <work>/stage/trigger-on  -o <org> --wait 3
 *                 trigger off: sf project deploy start --metadata-dir <work>/stage/trigger-off -o <org> --wait 3
 *               The stage folders are copies of metadata/ in this folder with the namespace filled in. Flow off is
 *               a FlowDefinition with activeVersionNumber 0; trigger off is the trigger with status Inactive. Never
 *               deploy this folder with --source-dir: that writes the org's source tracking for the repository.
 *   seed        deletes the probe's earlier rows, then inserts 50 stuck runs for --path (seed-stuck-runs.apex).
 *   pass        takes a snapshot of the probe's rows (Id, RunKey__c, CurrentJobId__c) and schedules the real
 *               watchdog once, 75 seconds out (../consoles-at-volume/templates/schedule-watchdog-once.apex,
 *               stale threshold 0 minutes, batch 50). The snapshot is what the reader compares against, so a second
 *               pass on the same rows counts only what that pass changed.
 *   wait        polls the pass's scheduled job (AsyncApexJob by CronTriggerId) every 20 seconds for up to three and
 *               a half minutes. Run it again if the job has not finished.
 *   read        waits until two minutes after the job finished (log entries arrive late, through a platform event),
 *               then runs read-outcome.apex for the pass and prints its lines.
 *   clear       deletes the probe's rows (root correlation id WatchdogAutomationProbe).
 *   tidy        switches both automations off and deletes the probe's rows. The flow and the trigger stay in the
 *               org, inactive, and do nothing. The watchdog's log entries stay.
 *
 * Order of a full run (ten passes):
 *   prepare
 *   automation --kind none;    seed --path failed; pass; wait; read;    seed --path restart; pass; wait; read
 *   automation --kind flow;    seed --path failed; pass; wait; read; pass; wait; read
 *                              seed --path restart; pass; wait; read; pass; wait; read
 *   automation --kind trigger; the same four passes as with the flow
 *   tidy
 * The second pass on the same rows shows whether the watchdog gets further on the next run or meets the same runs again.
 *
 * What to record for each pass: the job id, its Status and ExtendedStatus (PROBE_JOB), the counts (PROBE_OUTCOME),
 * the reasons (PROBE_REASON), the Queueables queued since the pass (PROBE_QUEUEABLES), the log sources
 * (PROBE_LOG_SOURCE), the highest query count and its limits line (PROBE_MOST_QUERIES), and any ERROR entry. A job that
 * failed with System.LimitException shows it only in Status and ExtendedStatus; its NumberOfErrors stays 0.
 *
 * Time. Every sf call waits at most three minutes. A deploy usually finishes in under a minute, but automation and
 * tidy can run two deploys; an agent starts those in the background.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const {spawnSync} = require('child_process');

const probeFolder = __dirname;
const repositoryRoot = path.resolve(probeFolder, '..', '..', '..');
const scheduleTemplate = path.join(probeFolder, '..', 'consoles-at-volume', 'templates', 'schedule-watchdog-once.apex');
const probeCorrelationId = 'WatchdogAutomationProbe';
const flowName = 'WatchdogProbe_ReadOnSave';
const triggerName = 'WatchdogProbeReadOnSave';
const finishedJobStatuses = ['Completed', 'Failed', 'Aborted'];
const jobPollMilliseconds = 20 * 1000;
const jobWaitMilliseconds = 210 * 1000;
const logArrivalMilliseconds = 120 * 1000;

/**
 * @description Prints the message and stops the probe with exit code 1.
 *
 * @param {string} message What went wrong.
 *
 * @returns {never}
 */
function fail(message)
{
	console.error('probe: ' + message);
	process.exit(1);
}

/**
 * @description Waits without using the processor, for the given time.
 *
 * @param {number} milliseconds How long to wait.
 */
function sleep(milliseconds)
{
	Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

/**
 * @description Reads the command and its options from the command line. Stops the probe when an option has no value
 * or --org is missing.
 *
 * @param {string[]} argv The command line after the script name.
 *
 * @returns {object} The command and one property for each option given.
 */
function readArguments(argv)
{
	const options = {command: argv[0]};
	for(let index = 1; index < argv.length; index++)
	{
		const name = argv[index];
		if(!name.startsWith('--'))
		{
			fail('unexpected argument ' + name);
		}
		if(name === '--check-only')
		{
			options.checkOnly = true;
			continue;
		}
		const value = argv[index + 1];
		if(value === undefined || value.startsWith('--'))
		{
			fail(name + ' needs a value');
		}
		options[name.slice(2)] = value;
		index++;
	}
	if(!options.org)
	{
		fail('--org <alias> is required');
	}
	return options;
}

/**
 * @description Creates the work folder and loads the probe's saved state from it, or starts an empty state.
 *
 * @param {object} options The options read from the command line.
 *
 * @returns {object} The org alias, the work folder, the state file's path and the state.
 */
function createContext(options)
{
	const work = path.resolve(options.work || path.join(repositoryRoot, 'tmp', 'watchdog-automation-probe', options.org));
	fs.mkdirSync(work, {recursive: true});
	const context = {org: options.org, work, statePath: path.join(work, 'state.json')};
	context.state = fs.existsSync(context.statePath) ? JSON.parse(fs.readFileSync(context.statePath, 'utf8')) : {passes: {}, passOrder: []};
	return context;
}

/**
 * @description Writes the probe's state to the state file in the work folder.
 *
 * @param {object} context The probe's context.
 */
function saveState(context)
{
	fs.writeFileSync(context.statePath, JSON.stringify(context.state, null, 2));
}

/**
 * @description Runs one sf command with --json, keeps its output in the work folder and returns the parsed output.
 * Stops the probe when sf cannot start or gives no JSON.
 *
 * @param {object} context The probe's context.
 * @param {string} label The name of the output file, without the extension.
 * @param {string[]} args The sf arguments, without --json.
 *
 * @returns {object} The parsed JSON that sf printed.
 */
function runSf(context, label, args)
{
	const outputPath = path.join(context.work, label + '.json');
	const result = spawnSync('sf', args.concat(['--json']), {encoding: 'utf8', maxBuffer: 64 * 1024 * 1024});
	if(result.error)
	{
		return fail('sf ' + args.slice(0, 2).join(' ') + ' could not start: ' + result.error.message);
	}
	fs.writeFileSync(outputPath, result.stdout || '');
	try
	{
		return JSON.parse(result.stdout);
	}
	catch(error)
	{
		return fail('sf ' + args.slice(0, 2).join(' ') + ' gave no JSON (exit ' + result.status + '); stderr: ' + result.stderr);
	}
}

/**
 * @description Runs a SOQL query in the org and returns its records. Stops the probe when the query fails.
 *
 * @param {object} context The probe's context.
 * @param {string} label The name of the output file, without the extension.
 * @param {string} soql The query.
 *
 * @returns {object[]} The records the query found.
 */
function query(context, label, soql)
{
	const parsed = runSf(context, label, ['data', 'query', '-o', context.org, '-q', soql]);
	if(parsed.status !== 0)
	{
		fail('query ' + label + ' failed: ' + parsed.message);
	}
	return parsed.result.records;
}

/**
 * @description Fills the namespace tokens in a text: __APEX_NAMESPACE__ becomes the class prefix (for example kern.)
 * and __NAMESPACE__ the field prefix (for example kern__). Both become empty when there is no namespace.
 *
 * @param {string} text The text with the tokens.
 * @param {string} namespace The package namespace, or an empty string.
 *
 * @returns {string} The text with the tokens filled.
 */
function fillNamespace(text, namespace)
{
	return text
		.split('__APEX_NAMESPACE__')
		.join(namespace ? namespace + '.' : '')
		.split('__NAMESPACE__')
		.join(namespace ? namespace + '__' : '');
}

/**
 * @description Runs anonymous Apex in the org after filling the namespace tokens, and returns its debug lines. Stops
 * the probe when the Apex does not compile or throws.
 *
 * @param {object} context The probe's context.
 * @param {string} label The name of the Apex and output files, without the extension.
 * @param {string} source The anonymous Apex, with namespace tokens.
 *
 * @returns {string[]} The text of each debug line, in order.
 */
function runApex(context, label, source)
{
	const apexPath = path.join(context.work, label + '.apex');
	fs.writeFileSync(apexPath, fillNamespace(source, context.state.namespace));
	const parsed = runSf(context, label, ['apex', 'run', '-o', context.org, '-f', apexPath]);
	const result = parsed.result || parsed.data || {};
	if(!result.success)
	{
		fail(
			'anonymous Apex ' + label + ' failed: compiled=' + result.compiled + ' problem=' + result.compileProblem + ' exception=' +
				result.exceptionMessage + '\n' + result.exceptionStackTrace
		);
	}
	return (result.logs || '')
		.split('\n')
		.filter((line) => line.includes('|USER_DEBUG|'))
		.map((line) => line.replace(/^.*\|DEBUG\|/, ''));
}

/**
 * @description Stops the probe when prepare has not saved the namespace yet.
 *
 * @param {object} context The probe's context.
 */
function requireNamespace(context)
{
	if(context.state.namespace === undefined)
	{
		fail('run prepare first');
	}
}

/**
 * @description Saves the namespace, assigns the package's Administrator permission set when it is missing, and
 * prints whether the org has the stall time field and how many other Stalled chain runs it has.
 *
 * @param {object} context The probe's context.
 * @param {object} options The options read from the command line.
 */
function prepare(context, options)
{
	if(options.namespace)
	{
		context.state.namespace = options.namespace === 'none' ? '' : options.namespace;
	}
	else
	{
		const classes = query(context, 'prepare-namespace', "SELECT NamespacePrefix FROM ApexClass WHERE Name = 'SCHED_ChainWatchdog'");
		if(classes.length !== 1)
		{
			fail('found ' + classes.length + ' SCHED_ChainWatchdog classes; pass --namespace');
		}
		context.state.namespace = classes[0].NamespacePrefix || '';
	}
	saveState(context);
	const namespaceClause = context.state.namespace ? "NamespacePrefix = '" + context.state.namespace + "'" : 'NamespacePrefix = NULL';
	const lines = runApex(
		context,
		'prepare',
		[
			"List<PermissionSet> administratorSets = [SELECT Id FROM PermissionSet WHERE Name = 'Administrator' AND " + namespaceClause + '];',
			"if(administratorSets.isEmpty()) { throw new IllegalArgumentException('The package Administrator permission set is not in this org'); }",
			'Integer held = [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :administratorSets[0].Id];',
			'if(held == 0) { insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = administratorSets[0].Id); }',
			"System.debug('PROBE_PREPARE administratorAssigned=' + (held == 0 ? 'now' : 'already'));",
			"Boolean hasStalledAtField = false;",
			'for(String fieldName : __NAMESPACE__AsyncChainExecution__c.SObjectType.getDescribe().fields.getMap().keySet())',
			"{ hasStalledAtField = hasStalledAtField || fieldName.equalsIgnoreCase('__NAMESPACE__StalledAt__c'); }",
			"System.debug('PROBE_PREPARE stalledAtField=' + hasStalledAtField);",
			'Integer otherStalled = [SELECT COUNT() FROM __NAMESPACE__AsyncChainExecution__c WHERE __NAMESPACE__Status__c = \'Stalled\'',
			"	AND __NAMESPACE__RootCorrelationId__c != '" + probeCorrelationId + "'];",
			"System.debug('PROBE_PREPARE otherStalledRuns=' + otherStalled);"
		].join('\n')
	);
	console.log('namespace=' + (context.state.namespace || '(none)'));
	console.log(lines.join('\n'));
	if(lines.some((line) => /otherStalledRuns=[1-9]/.test(line)))
	{
		console.log('WARNING: the org has Stalled chain runs that are not the probe\'s; the watchdog spends queries on them too.');
	}
}

/**
 * @description Reads whether the probe's flow and trigger exist in the org and whether each is active.
 *
 * @param {object} context The probe's context.
 *
 * @returns {{flowExists: boolean, flowActive: boolean, triggerExists: boolean, triggerActive: boolean}}
 */
function readAutomationState(context)
{
	const flows = query(context, 'automation-flow-state', "SELECT ApiName, IsActive FROM FlowDefinitionView WHERE ApiName = '" + flowName + "'");
	const triggers = query(context, 'automation-trigger-state', "SELECT Name, Status FROM ApexTrigger WHERE Name = '" + triggerName + "'");
	return {
		flowExists: flows.length > 0,
		flowActive: flows.length > 0 && flows[0].IsActive === true,
		triggerExists: triggers.length > 0,
		triggerActive: triggers.length > 0 && triggers[0].Status === 'Active'
	};
}

/**
 * @description Copies one metadata package from this folder to the work folder, with the namespace filled in.
 *
 * @param {object} context The probe's context.
 * @param {string} packageName The folder under metadata/, for example flow-on.
 *
 * @returns {string} The path of the copy.
 */
function stageMetadata(context, packageName)
{
	const source = path.join(probeFolder, 'metadata', packageName);
	const target = path.join(context.work, 'stage', packageName);
	fs.rmSync(target, {recursive: true, force: true});
	const copyFolder = (from, to) =>
	{
		fs.mkdirSync(to, {recursive: true});
		for(const entry of fs.readdirSync(from, {withFileTypes: true}))
		{
			const fromPath = path.join(from, entry.name);
			const toPath = path.join(to, entry.name);
			if(entry.isDirectory())
			{
				copyFolder(fromPath, toPath);
			}
			else
			{
				fs.writeFileSync(toPath, fillNamespace(fs.readFileSync(fromPath, 'utf8'), context.state.namespace));
			}
		}
	};
	copyFolder(source, target);
	return target;
}

/**
 * @description Deploys one metadata package to the org from its staged copy. Stops the probe when the deploy does not
 * succeed.
 *
 * @param {object} context The probe's context.
 * @param {string} packageName The folder under metadata/, for example flow-on.
 * @param {boolean} checkOnly True to validate the deploy without changing the org.
 */
function deployMetadata(context, packageName, checkOnly)
{
	const stagePath = stageMetadata(context, packageName);
	const args = ['project', 'deploy', 'start', '--metadata-dir', stagePath, '-o', context.org, '--wait', '3'];
	if(checkOnly)
	{
		args.push('--dry-run');
	}
	const parsed = runSf(context, 'deploy-' + packageName + (checkOnly ? '-check' : ''), args);
	const result = parsed.result || parsed.data || {};
	console.log('deploy ' + packageName + (checkOnly ? ' (check only)' : '') + ': id=' + result.id + ' status=' + result.status);
	if(parsed.status !== 0 || result.success !== true)
	{
		fail('deploy ' + packageName + ' did not succeed: ' + (parsed.message || JSON.stringify(result.details && result.details.componentFailures)));
	}
}

/**
 * @description Switches the flow and the trigger so that only the given kind of automation is on.
 *
 * @param {object} context The probe's context.
 * @param {string} kind none, flow or trigger.
 * @param {boolean} checkOnly True to validate the deploys without changing the org.
 */
function switchAutomation(context, kind, checkOnly)
{
	if(!['none', 'flow', 'trigger'].includes(kind))
	{
		fail('--kind must be none, flow or trigger');
	}
	const before = readAutomationState(context);
	console.log('before: ' + JSON.stringify(before));
	if(kind === 'flow' && !before.flowActive)
	{
		deployMetadata(context, 'flow-on', checkOnly);
	}
	if(kind !== 'flow' && before.flowActive)
	{
		deployMetadata(context, 'flow-off', checkOnly);
	}
	if(kind === 'trigger' && !before.triggerActive)
	{
		deployMetadata(context, 'trigger-on', checkOnly);
	}
	if(kind !== 'trigger' && before.triggerActive)
	{
		deployMetadata(context, 'trigger-off', checkOnly);
	}
	console.log('after: ' + JSON.stringify(readAutomationState(context)));
}

/**
 * @description Deletes the probe's chain run rows (the rows with the probe's root correlation id).
 *
 * @param {object} context The probe's context.
 */
function clearRows(context)
{
	const lines = runApex(
		context,
		'clear-' + Date.now(),
		[
			"List<__NAMESPACE__AsyncChainExecution__c> rows = [SELECT Id FROM __NAMESPACE__AsyncChainExecution__c WHERE __NAMESPACE__RootCorrelationId__c = '" +
				probeCorrelationId +
				"'];",
			'delete rows;',
			"System.debug('PROBE_DELETED rows=' + rows.size());"
		].join('\n')
	);
	console.log(lines.join('\n'));
}

/**
 * @description Deletes the probe's earlier rows, then inserts 50 stuck runs for the given recovery path.
 *
 * @param {object} context The probe's context.
 * @param {string} seedPath failed or restart.
 */
function seed(context, seedPath)
{
	if(!['failed', 'restart'].includes(seedPath))
	{
		fail('--path must be failed or restart');
	}
	clearRows(context);
	const source = fs.readFileSync(path.join(probeFolder, 'seed-stuck-runs.apex'), 'utf8').split('__PATH__').join(seedPath);
	const lines = runApex(context, 'seed-' + seedPath + '-' + Date.now(), source);
	const seededCount = lines.filter((line) => line.startsWith('PROBE_SEED id=')).length;
	context.state.seedPath = seedPath;
	saveState(context);
	console.log('seeded=' + seededCount);
	console.log(lines[lines.length - 1]);
}

/**
 * @description Reads the probe's rows and returns them as one text: Id, RunKey__c and CurrentJobId__c of each row.
 *
 * @param {object} context The probe's context.
 * @param {string} label The pass name, used in the output file name.
 *
 * @returns {string} One entry per row, separated by semicolons; empty when there are no rows.
 */
function takeSnapshot(context, label)
{
	const records = query(
		context,
		'snapshot-' + label,
		fillNamespace(
			'SELECT Id, __NAMESPACE__RunKey__c, __NAMESPACE__CurrentJobId__c FROM __NAMESPACE__AsyncChainExecution__c WHERE __NAMESPACE__RootCorrelationId__c = \'' +
				probeCorrelationId +
				"' ORDER BY Id",
			context.state.namespace
		)
	);
	const runKeyField = fillNamespace('__NAMESPACE__RunKey__c', context.state.namespace);
	const jobIdField = fillNamespace('__NAMESPACE__CurrentJobId__c', context.state.namespace);
	return records.map((record) => record.Id + '=' + (record[runKeyField] || '') + '=' + (record[jobIdField] || '')).join(';');
}

/**
 * @description Takes a snapshot of the probe's rows and schedules the real watchdog to run once, then saves the pass.
 *
 * @param {object} context The probe's context.
 * @param {string} label The name of the pass.
 */
function schedulePass(context, label)
{
	const seeded = takeSnapshot(context, label);
	if(!seeded)
	{
		fail('no probe rows to run a pass on; run seed first');
	}
	const since = new Date(Date.now() - 5000).toISOString().replace(/\.\d+Z$/, 'Z');
	const jobName = 'Watchdog automation probe ' + label + ' ' + Date.now();
	const source = fs
		.readFileSync(scheduleTemplate, 'utf8')
		.split('__THRESHOLD_MINUTES__')
		.join('0')
		.split('__JOB_NAME__')
		.join(jobName);
	const lines = runApex(context, 'schedule-' + label, source);
	const line = lines.find((entry) => entry.startsWith('VOLUME_PROBE')) || '';
	const match = line.match(/watchdog=(\S+) fireAt=(\S+)/);
	if(!match)
	{
		fail('the schedule script printed no job id');
	}
	context.state.passes[label] = {seedPath: context.state.seedPath, seeded, rowCount: seeded.split(';').length, cronId: match[1], fireAt: match[2], since, jobName};
	context.state.passOrder.push(label);
	saveState(context);
	console.log('pass=' + label + ' path=' + context.state.seedPath + ' rows=' + seeded.split(';').length + ' cron=' + match[1] + ' fireAt=' + match[2]);
}

/**
 * @description Finds a saved pass by name, or the latest pass when no name is given. Stops the probe when there is no
 * such pass.
 *
 * @param {object} context The probe's context.
 * @param {string} [label] The name of the pass.
 *
 * @returns {{passLabel: string, pass: object}}
 */
function findPass(context, label)
{
	const passLabel = label || context.state.passOrder[context.state.passOrder.length - 1];
	const pass = passLabel && context.state.passes[passLabel];
	if(!pass)
	{
		fail('no pass named ' + passLabel);
	}
	return {passLabel, pass};
}

/**
 * @description Reads the scheduled job that a pass started.
 *
 * @param {object} context The probe's context.
 * @param {string} passLabel The name of the pass.
 * @param {object} pass The saved pass.
 *
 * @returns {object|null} The AsyncApexJob record, or null when the job has not started yet.
 */
function readJob(context, passLabel, pass)
{
	const jobs = query(
		context,
		'job-' + passLabel,
		"SELECT Id, Status, ExtendedStatus, NumberOfErrors, CompletedDate FROM AsyncApexJob WHERE CronTriggerId = '" + pass.cronId + "'"
	);
	return jobs.length > 0 ? jobs[0] : null;
}

/**
 * @description Checks the pass's job every 20 seconds until it has finished, for up to three and a half minutes.
 *
 * @param {object} context The probe's context.
 * @param {string} [label] The name of the pass; the latest pass when not given.
 */
function waitForJob(context, label)
{
	const {passLabel, pass} = findPass(context, label);
	const deadline = Date.now() + jobWaitMilliseconds;
	for(;;)
	{
		const job = readJob(context, passLabel, pass);
		const summary = job
			? job.Id + ' status=' + job.Status + ' errors=' + job.NumberOfErrors + ' extended=' + job.ExtendedStatus + ' completed=' + job.CompletedDate
			: 'no job yet for cron ' + pass.cronId;
		if(job && finishedJobStatuses.includes(job.Status))
		{
			console.log('finished: ' + summary);
			return;
		}
		if(Date.now() + jobPollMilliseconds > deadline)
		{
			console.log('not finished yet: ' + summary + '; run wait again');
			return;
		}
		sleep(jobPollMilliseconds);
	}
}

/**
 * @description Waits until two minutes after the pass's job finished, then runs read-outcome.apex for the pass and
 * prints its lines. Stops the probe when the job has not finished.
 *
 * @param {object} context The probe's context.
 * @param {string} [label] The name of the pass; the latest pass when not given.
 */
function readOutcome(context, label)
{
	const {passLabel, pass} = findPass(context, label);
	const job = readJob(context, passLabel, pass);
	if(!job || !finishedJobStatuses.includes(job.Status))
	{
		fail('the job for pass ' + passLabel + ' has not finished; run wait first');
	}
	const waitLeft = new Date(job.CompletedDate).getTime() + logArrivalMilliseconds - Date.now();
	if(waitLeft > 0)
	{
		console.log('waiting ' + Math.ceil(waitLeft / 1000) + ' seconds for the log entries to arrive');
		sleep(waitLeft);
	}
	const source = fs
		.readFileSync(path.join(probeFolder, 'read-outcome.apex'), 'utf8')
		.split('__SEEDED__')
		.join(pass.seeded)
		.split('__CRON_ID__')
		.join(pass.cronId)
		.split('__SINCE__')
		.join(pass.since);
	const lines = runApex(context, 'read-' + passLabel, source);
	fs.writeFileSync(path.join(context.work, 'read-' + passLabel + '.txt'), lines.join('\n') + '\n');
	console.log('pass=' + passLabel + ' path=' + pass.seedPath);
	console.log(lines.join('\n'));
}

/**
 * @description Reads the command line and runs the command it names.
 */
function main()
{
	const options = readArguments(process.argv.slice(2));
	const context = createContext(options);
	if(options.command === 'prepare')
	{
		prepare(context, options);
		return;
	}
	requireNamespace(context);
	if(options.command === 'automation')
	{
		switchAutomation(context, options.kind, options.checkOnly === true);
	}
	else if(options.command === 'seed')
	{
		seed(context, options.path);
	}
	else if(options.command === 'pass')
	{
		schedulePass(context, options.label || 'pass' + (context.state.passOrder.length + 1));
	}
	else if(options.command === 'wait')
	{
		waitForJob(context, options.label);
	}
	else if(options.command === 'read')
	{
		readOutcome(context, options.label);
	}
	else if(options.command === 'clear')
	{
		clearRows(context);
	}
	else if(options.command === 'tidy')
	{
		switchAutomation(context, 'none', false);
		clearRows(context);
	}
	else
	{
		fail('unknown command ' + options.command + '; see the comment at the top of probe.js');
	}
}

main();
