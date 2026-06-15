// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {namingPatternsFor} = require('../../src/commands/naming.js');

test('namingPatternsFor returns flow + objects globs per package dir', () =>
{
	const patterns = namingPatternsFor(['force-app/main/default']);
	assert.deepEqual(patterns, [
		'force-app/main/default/**/*.flow-meta.xml',
		'force-app/main/default/**/objects/**/*'
	]);
});

test('naming-engine integration: subscriber fixtures produce expected violations', async() =>
{
	const engine = require('../../src/naming-engine/index.js');
	const subscriberConfig = require('js-yaml').load(require('node:fs').readFileSync(path.join(__dirname, '..', 'fixtures', 'subscriber-naming', 'config.yml'), 'utf-8'));
	const files = [
		path.join(__dirname, '..', 'fixtures', 'subscriber-naming', 'flows', 'good', 'SLS_Account_BS_SetDefaults.flow-meta.xml'),
		path.join(__dirname, '..', 'fixtures', 'subscriber-naming', 'flows', 'bad', 'BadFlowNoDomain.flow-meta.xml')
	];
	const result = await engine.validate({files, config: subscriberConfig.naming});
	assert.equal(result.violations.length, 1);
	assert.match(result.violations[0].file, /BadFlowNoDomain/);
});
