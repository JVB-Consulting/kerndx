// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const yaml = require('js-yaml');
const {EXAMPLES_DIR, EXAMPLE_CONFIGURATION, listExamples, renderExample} = require('../../scripts/render-examples.js');

// The pre-rendered examples live beside the pipeline in the framework
// repository; a distribution bundle ships the pipeline alone, so the checks
// are skipped when the directory is absent.
const examplesPresent = fs.existsSync(EXAMPLES_DIR);

test('the examples directory holds the nine shipped workflows', {skip: !examplesPresent}, () =>
{
	assert.equal(listExamples().length, 9);
});

test('the examples are rendered with Slack off and Node 22, as the examples README says', () =>
{
	assert.equal(EXAMPLE_CONFIGURATION.slack.enabled, false);
	assert.equal(EXAMPLE_CONFIGURATION.nodeVersion, '22');
	assert.deepEqual(EXAMPLE_CONFIGURATION.ingressBranches, ['main']);
	assert.deepEqual(EXAMPLE_CONFIGURATION.packageDirs, ['force-app/main/default']);
});

for(const fileName of examplesPresent ? listExamples() : [])
{
	test(`examples/workflows/${fileName} equals a fresh render of its template`, () =>
	{
		// A Windows checkout gives the committed file CRLF line endings; the generator writes LF.
		const committed = fs.readFileSync(path.join(EXAMPLES_DIR, fileName), 'utf8').replace(/\r\n/g, '\n');
		const rendered = renderExample(fileName);

		assert.equal(committed, rendered, `${fileName} differs from the generator's output; run \`npm run render-examples\` in pipeline/`);
		assert.ok(yaml.load(rendered).jobs, `${fileName} does not parse to a workflow with jobs`);
		assert.doesNotMatch(rendered, /webhook|secrets\.SLACK|slack-github-action/, `${fileName} references Slack although the examples render with Slack off`);
	});
}
