#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1

const {execSync} = require('child_process');
const path = require('path');
const {getSubscriberOrgAlias} = require('./subscriber-config');

const ORG_ALIAS = getSubscriberOrgAlias();

const SCRIPTS = [
	{kind: 'apex', path: 'release-testing/scripts/load-extended/sustained-masker-soak.apex'},
	{kind: 'apex', path: 'release-testing/scripts/load-extended/sustained-logger-pe-flood.apex'},
	{kind: 'node', path: 'release-testing/scripts/load-extended/parallel-callout-burst-100.js'},
	{kind: 'node', path: 'release-testing/scripts/load-extended/parallel-cache-contention.js'}
];

console.log('=== Extended load suite ===\n');
let pass = 0, fail = 0;

for(const script of SCRIPTS)
{
	console.log(`\n--- Running ${script.path} ---`);
	try
	{
		if(script.kind === 'apex')
		{
			execSync(`sf apex run --file ${script.path} -o ${ORG_ALIAS}`, {stdio: 'inherit'});
		}
		else
		{
			execSync(`node ${script.path}`, {stdio: 'inherit'});
		}
		pass++;
	}
	catch(e)
	{
		console.error(`FAIL: ${script.path}`);
		fail++;
	}
}

console.log(`\n=== Extended load suite: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
