#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * Trigger-action flow-reference scanner.
 *
 * Validates that every TriggerAction__mdt CMDT record whose FlowName__c is
 * populated points at a flow that:
 *
 *   1. Exists in the dispatching dev org (FlowDefinitionView lookup by ApiName)
 *   2. Is active (FlowDefinitionView.IsActive = true)
 *   3. Declares the variable contract the runtime dispatcher requires:
 *      - For non-record-triggered flows (TriggerType is not RecordAfterSave /
 *        RecordBeforeSave): a SObject variable named `record` typed to the
 *        SObjectType resolved through TriggerSetting__mdt.SObjectType__c, with
 *        isInput=true AND isOutput=true.
 *      - Update-context CMDT rows (Event = "Before Update" / "After Update")
 *        also require a `recordPrior` SObject variable (input-only is fine).
 *
 * Flow-action rows are identified by `FlowName__c` non-blank (since the
 * MutuallyExclusiveTarget validation rule guarantees ApexClassName and
 * FlowName are never both populated on the same row).
 *
 * The scanner uses standard SOQL for FlowDefinitionView (Tooling API does not
 * expose this entity at API 66) and Tooling API for the Flow.Metadata payload
 * batched via WHERE Id IN(...).
 *
 * Permission gate:
 *   The scan probes COUNT(FlowDefinitionView) before executing the main check.
 *   If the count is zero AND the local force-app/main/default/flows directory
 *   contains *.flow-meta.xml files, the scanner exits with an actionable error
 *   prompting the operator to grant the running user `Manage Flow`.
 *
 * Usage:
 *   node scripts/scan-flow-references.js
 *   node scripts/scan-flow-references.js --org SomeOtherAlias
 *
 * Exits 0 on clean, 1 on any violation.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const {execFileSync} = require('child_process');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const CMDT_DIR = path.join(PROJECT_ROOT, 'force-app/main/default/customMetadata');
const FLOW_DIR = path.join(PROJECT_ROOT, 'force-app/main/default/flows');

const {getDevOrgAlias} = require('./dev-org-config');

const RECORD_TRIGGERED_TYPES = new Set(['RecordAfterSave', 'RecordBeforeSave']);
const UPDATE_EVENTS = new Set(['Before Update', 'After Update']);
const DEFAULT_ORG = getDevOrgAlias();

function parseCliOptions(argv)
{
	const options = {org: DEFAULT_ORG};
	for(let index = 0; index < argv.length; index++)
	{
		if(argv[index] === '--org' && argv[index + 1])
		{
			options.org = argv[index + 1];
			index++;
		}
	}
	return options;
}

function extractFieldValue(xml, fieldName)
{
	const escapedName = fieldName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
	const blockPattern = new RegExp(`<values>\\s*<field>${escapedName}</field>\\s*([\\s\\S]*?)</values>`, 'm');
	const blockMatch = blockPattern.exec(xml);
	if(!blockMatch) { return null; }
	const inner = blockMatch[1];
	if(/<value\s+xsi:nil="true"\s*\/?>/i.test(inner)) { return null; }
	const valueMatch = /<value[^>]*>([\s\S]*?)<\/value>/.exec(inner);
	if(!valueMatch) { return null; }
	return valueMatch[1].trim();
}

function parseTriggerActionFile(filePath)
{
	const xml = fs.readFileSync(filePath, 'utf8');
	const flowName = extractFieldValue(xml, 'FlowName__c');
	if(!flowName) { return null; }
	const cmdtName = path.basename(filePath, '.md-meta.xml').replace(/^TriggerAction\./, '');
	return {
		cmdtName,
		filePath,
		flowName,
		triggerSetting: extractFieldValue(xml, 'TriggerSetting__c'),
		event: extractFieldValue(xml, 'Event__c')
	};
}

function loadTriggerActionRecords()
{
	if(!fs.existsSync(CMDT_DIR)) { return []; }
	const records = [];
	const files = fs.readdirSync(CMDT_DIR).filter((name) => name.startsWith('TriggerAction.') && name.endsWith('.md-meta.xml'));
	for(const file of files)
	{
		const record = parseTriggerActionFile(path.join(CMDT_DIR, file));
		if(record) { records.push(record); }
	}
	return records;
}

function loadTriggerSettingMap()
{
	if(!fs.existsSync(CMDT_DIR)) { return {}; }
	const map = {};
	const files = fs.readdirSync(CMDT_DIR).filter((name) => name.startsWith('TriggerSetting.') && name.endsWith('.md-meta.xml'));
	for(const file of files)
	{
		const xml = fs.readFileSync(path.join(CMDT_DIR, file), 'utf8');
		const developerName = path.basename(file, '.md-meta.xml').replace(/^TriggerSetting\./, '');
		const sobjectType = extractFieldValue(xml, 'SObjectType__c');
		if(sobjectType) { map[developerName] = sobjectType; }
	}
	return map;
}

function localFlowFilesExist()
{
	if(!fs.existsSync(FLOW_DIR)) { return false; }
	return fs.readdirSync(FLOW_DIR).some((name) => name.endsWith('.flow-meta.xml'));
}

function runSoql(query, options)
{
	const args = ['data', 'query', '-q', query, '-o', options.org, '--json'];
	if(options.useToolingApi) { args.push('--use-tooling-api'); }
	let stdout;
	try
	{
		stdout = execFileSync('sf', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']});
	}
	catch(spawnError)
	{
		const stderrText = (spawnError.stderr && spawnError.stderr.toString()) || '';
		const stdoutText = (spawnError.stdout && spawnError.stdout.toString()) || '';
		const detail = (stderrText || stdoutText || spawnError.message || '').trim();
		throw new Error(`Failed to run 'sf data query' against org '${options.org}'. Verify 'sf' is on PATH, the org alias resolves, and the user is authenticated. Underlying error: ${detail}`);
	}
	let parsed;
	try
	{
		parsed = JSON.parse(stdout);
	}
	catch(parseError)
	{
		throw new Error(`SF CLI returned a response that was not valid JSON for query: ${query}\nResponse: ${stdout}`);
	}
	if(parsed.status !== 0)
	{
		throw new Error(`SF CLI returned non-zero status for query: ${query}\n${stdout}`);
	}
	return parsed.result;
}

function runProbeSentinel(options, deps)
{
	const queryRunner = (deps && deps.queryRunner) || runSoql;
	const flowFilesPresent = (deps && typeof deps.localFlowFilesExist === 'function') ? deps.localFlowFilesExist() : localFlowFilesExist();
	const result = queryRunner('SELECT COUNT() FROM FlowDefinitionView', {org: options.org});
	const totalSize = typeof result.totalSize === 'number' ? result.totalSize : 0;
	if(totalSize === 0 && flowFilesPresent)
	{
		return {
			ok: false,
			message: "Scanner cannot see any flows in the dev org. Either (a) the running user is missing the 'Manage Flow' user permission (assign it via the Kern Administrator permset, a sysadmin profile, or a custom permset that grants Manage Flow), or (b) the dev org has no flows deployed. Re-run after granting permissions or deploying flows."
		};
	}
	return {ok: true};
}

function buildExistenceQueryPlan(records)
{
	const flowNames = new Set();
	for(const record of records)
	{
		if(record.flowName) { flowNames.add(record.flowName); }
	}
	if(flowNames.size === 0) { return null; }
	const inClause = [...flowNames]
		.map((name) => `'${name.replace(/'/g, "\\'")}'`)
		.join(',');
	return {
		flowNames: [...flowNames],
		soql: `SELECT Id, ApiName, IsActive, ActiveVersionId, TriggerType, NamespacePrefix FROM FlowDefinitionView WHERE NamespacePrefix = NULL AND ApiName IN (${inClause})`
	};
}

function buildMetadataQuery(activeVersionIds)
{
	if(activeVersionIds.length === 0) { return null; }
	const inClause = activeVersionIds.map((id) => `'${id}'`).join(',');
	return `SELECT Id, Metadata FROM Flow WHERE Id IN (${inClause})`;
}

function validateVariableContract(record, flow, version, sobjectType)
{
	const errors = [];
	const metadata = (version && version.Metadata) || {};
	const variables = Array.isArray(metadata.variables) ? metadata.variables : [];
	const recordVariable = variables.find((variable) => variable.name === 'record');
	if(!recordVariable)
	{
		errors.push(`TriggerAction '${record.cmdtName}': flow '${record.flowName}' is missing required variable 'record: ${sobjectType}' (in/out). Either fix the flow declaration or correct the CMDT row's FlowName__c.`);
		return errors;
	}
	const recordType = recordVariable.objectType || recordVariable.dataType;
	if(recordVariable.dataType !== 'SObject' || recordVariable.objectType !== sobjectType)
	{
		errors.push(`TriggerAction '${record.cmdtName}': flow '${record.flowName}' variable 'record' has type '${recordVariable.dataType}/${recordType}' but TriggerSetting requires '${sobjectType}'.`);
		return errors;
	}
	if(!recordVariable.isInput || !recordVariable.isOutput)
	{
		errors.push(`TriggerAction '${record.cmdtName}': flow '${record.flowName}' variable 'record' must be both input and output (isInput=true, isOutput=true). Found isInput=${Boolean(recordVariable.isInput)}, isOutput=${Boolean(recordVariable.isOutput)}.`);
	}
	if(UPDATE_EVENTS.has(record.event))
	{
		const priorVariable = variables.find((variable) => variable.name === 'recordPrior');
		if(!priorVariable || priorVariable.dataType !== 'SObject' || priorVariable.objectType !== sobjectType || !priorVariable.isInput)
		{
			errors.push(`TriggerAction '${record.cmdtName}': flow '${record.flowName}' is missing required variable 'recordPrior: ${sobjectType}' (input). Update-context flow actions must accept the prior record snapshot.`);
		}
	}
	return errors;
}

function scan(options, deps)
{
	const queryRunner = (deps && deps.queryRunner) || runSoql;
	const triggerActions = (deps && typeof deps.loadTriggerActionRecords === 'function') ? deps.loadTriggerActionRecords() : loadTriggerActionRecords();
	if(triggerActions.length === 0)
	{
		return {ok: true, scannedCount: 0, errors: []};
	}
	const probe = runProbeSentinel(options, {queryRunner, localFlowFilesExist: deps && deps.localFlowFilesExist});
	if(!probe.ok)
	{
		return {ok: false, scannedCount: triggerActions.length, errors: [probe.message]};
	}
	const triggerSettings = (deps && typeof deps.loadTriggerSettingMap === 'function') ? deps.loadTriggerSettingMap() : loadTriggerSettingMap();
	const errors = [];
	const plan = buildExistenceQueryPlan(triggerActions);
	const existenceResult = plan
		? queryRunner(plan.soql, {org: options.org})
		: {records: []};
	const flowsByName = {};
	for(const flow of (existenceResult.records || []))
	{
		flowsByName[flow.ApiName] = flow;
	}
	const activeFlowsNeedingMetadata = [];
	for(const record of triggerActions)
	{
		if(!record.flowName)
		{
			errors.push(`TriggerAction '${record.cmdtName}': missing FlowName__c value. Set FlowName__c to the API name of the flow to invoke.`);
			continue;
		}
		const flow = flowsByName[record.flowName];
		if(!flow)
		{
			errors.push(`TriggerAction '${record.cmdtName}': flow '${record.flowName}' does not exist in dev org. Either deploy the flow or remove the CMDT record.`);
			continue;
		}
		if(!flow.IsActive)
		{
			errors.push(`TriggerAction '${record.cmdtName}': flow '${record.flowName}' is inactive. Activate the flow or remove the CMDT record.`);
			continue;
		}
		if(RECORD_TRIGGERED_TYPES.has(flow.TriggerType))
		{
			continue;
		}
		const sobjectType = record.triggerSetting ? triggerSettings[record.triggerSetting] : null;
		if(!sobjectType)
		{
			errors.push(`TriggerAction '${record.cmdtName}': cannot resolve TriggerSetting '${record.triggerSetting}' to an SObjectType. Verify the TriggerSetting CMDT record exists and declares SObjectType__c.`);
			continue;
		}
		activeFlowsNeedingMetadata.push({record, flow, sobjectType});
	}
	const versionIds = [...new Set(activeFlowsNeedingMetadata.map((entry) => entry.flow.ActiveVersionId).filter(Boolean))];
	const metadataQuery = buildMetadataQuery(versionIds);
	const versionsById = {};
	if(metadataQuery)
	{
		const metadataResult = queryRunner(metadataQuery, {org: options.org, useToolingApi: true});
		for(const version of (metadataResult.records || []))
		{
			versionsById[version.Id] = version;
		}
	}
	for(const {record, flow, sobjectType} of activeFlowsNeedingMetadata)
	{
		const version = versionsById[flow.ActiveVersionId];
		if(!version)
		{
			errors.push(`TriggerAction '${record.cmdtName}': could not load metadata for flow '${record.flowName}' (active version ${flow.ActiveVersionId}). The Tooling API returned no rows; verify the CI user has Manage Flow.`);
			continue;
		}
		errors.push(...validateVariableContract(record, flow, version, sobjectType));
	}
	return {ok: errors.length === 0, scannedCount: triggerActions.length, errors};
}

function main()
{
	const options = parseCliOptions(process.argv.slice(2));
	const result = scan(options);
	if(result.ok)
	{
		console.log(`✓ Scanned ${result.scannedCount} flow-action CMDT records — no flow-reference violations.`);
		process.exit(0);
	}
	console.error(`✗ Flow-reference scan failed (${result.errors.length} violation(s)):\n`);
	for(const message of result.errors)
	{
		console.error(`  - ${message}`);
	}
	console.error('\nEvery TriggerAction__mdt row with FlowName__c populated must point at an active flow that declares the required variable contract. This protects subscribers from runtime System.UnexpectedException errors that abort the entire trigger transaction.');
	process.exit(1);
}

module.exports = {
	parseCliOptions,
	parseTriggerActionFile,
	loadTriggerActionRecords,
	loadTriggerSettingMap,
	localFlowFilesExist,
	runProbeSentinel,
	buildExistenceQueryPlan,
	buildMetadataQuery,
	validateVariableContract,
	scan,
	main
};

if(require.main === module)
{
	main();
}
