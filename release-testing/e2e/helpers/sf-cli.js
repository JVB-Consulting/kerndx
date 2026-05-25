// SPDX-License-Identifier: BUSL-1.1
const {execSync, exec} = require('child_process');
const {ORG_ALIAS} = require('./sf-auth');

function runApexScript(scriptPath, {timeout = 120_000} = {})
{
	const output = execSync(`sf apex run -o ${ORG_ALIAS} -f ${scriptPath} 2>&1`, {encoding: 'utf8', timeout});
	return parseApexOutput(output);
}

function runApexScriptAsync(scriptPath, {timeout = 120_000} = {})
{
	return new Promise((resolve, reject) =>
	{
		exec(`sf apex run -o ${ORG_ALIAS} -f ${scriptPath} 2>&1`, {encoding: 'utf8', timeout}, (error, stdout) =>
		{
			if(error && !stdout)
			{
				return reject(error);
			}
			resolve(parseApexOutput(stdout || ''));
		});
	});
}

function executeAnonymousApex(apex, {timeout = 60_000} = {})
{
	const fs = require('fs');
	const path = require('path');
	const tmpFile = path.join('/tmp', `kern-e2e-${Date.now()}.apex`);
	fs.writeFileSync(tmpFile, apex, 'utf8');
	try
	{
		const output = execSync(`sf apex run -o ${ORG_ALIAS} -f "${tmpFile}" 2>&1`, {encoding: 'utf8', timeout});
		return output;
	}
	finally
	{
		fs.unlinkSync(tmpFile);
	}
}

function soqlQuery(query, {tooling = false, timeout = 30_000} = {})
{
	const toolingFlag = tooling ? '-t' : '';
	const output = execSync(`sf data query -o ${ORG_ALIAS} ${toolingFlag} -q "${query}" --json`,
			{encoding: 'utf8', timeout, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
	const clean = output.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '');
	const result = JSON.parse(clean);
	return result.result.records || [];
}

function createRecord(sobjectType, values, {timeout = 30_000} = {})
{
	const valuesStr = Object.entries(values)
	.map(([key, val]) => `${key}="${val}"`)
	.join(' ');
	const output = execSync(`sf data create record -o ${ORG_ALIAS} -s ${sobjectType} -v "${valuesStr}" --json`, {encoding: 'utf8', timeout});
	return JSON.parse(output).result;
}

function deleteRecord(sobjectType, recordId, {timeout = 30_000} = {})
{
	execSync(`sf data delete record -o ${ORG_ALIAS} -s ${sobjectType} -i ${recordId} --json`, {encoding: 'utf8', timeout});
}

function deployMetadata(sourcePath, {timeout = 120_000} = {})
{
	const output = execSync(`sf project deploy start -o ${ORG_ALIAS} -d "${sourcePath}" --ignore-conflicts --json`, {encoding: 'utf8', timeout});
	return JSON.parse(output);
}

function runTests({testLevel = 'RunLocalTests', timeout = 600_000} = {})
{
	const output = execSync(`sf apex run test -o ${ORG_ALIAS} --test-level ${testLevel} --result-format json --code-coverage --json`, {encoding: 'utf8', timeout});
	return JSON.parse(output);
}

function parseApexOutput(output)
{
	const lines = output.split('\n').filter(line => line.includes('USER_DEBUG'));
	let pass = 0;
	let fail = 0;
	const results = [];

	for(const line of lines)
	{
		const debugMatch = line.match(/USER_DEBUG\s+\[[\d|]+\]\|DEBUG\|(.+)/);
		if(!debugMatch)
		{
			continue;
		}
		const message = debugMatch[1];
		const isPassing = message.includes('PASS');
		const isFailing = message.includes('FAIL');
		if(isPassing)
		{
			pass++;
		}
		if(isFailing)
		{
			fail++;
		}
		results.push({message, pass: isPassing, fail: isFailing});
	}

	return {pass, fail, total: pass + fail, results, raw: output};
}

module.exports = {
	runApexScript, runApexScriptAsync, executeAnonymousApex, soqlQuery, createRecord, deleteRecord, deployMetadata, runTests, parseApexOutput
};
