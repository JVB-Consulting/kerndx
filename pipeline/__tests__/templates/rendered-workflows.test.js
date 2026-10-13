// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const yaml = require('js-yaml');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const WORKFLOWS_DIR = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows');
const PARTIALS_DIR = path.join(WORKFLOWS_DIR, '_partials');
const UNTRUSTED_EXPRESSIONS = [
	'${{ github.head_ref }}',
	'${{ github.event.pull_request.title }}'
];
// Slack payload text must never carry a value a pull request author controls;
// the payload steps build it in script code from the event payload instead.
const UNTRUSTED_PAYLOAD_FRAGMENTS = [
	'pull_request.title',
	'head_ref',
	'pr_title'
];
// The only `with:` inputs allowed to span lines: a script body and a JSON
// payload block. Every other input is a single value, so a line break inside
// it means the template folded a blank line into the value. A folded scalar
// keeps one trailing line break, which the action runtime trims away.
const MULTILINE_INPUTS = [
	'script',
	'payload'
];

function configuration(slackEnabled)
{
	return {
		ingressBranches: ['main'],
		protectedBranches: [
			'main',
			'release'
		],
		releaseBranches: ['release'],
		packageDirs: ['force-app/main/default'],
		nodeVersion: '22',
		runsOn: 'ubuntu-latest',
		ciAdapterName: 'none',
		slack: slackEnabled ? {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL', suppress_on_pr_title_prefix: '[E2E]'} : {enabled: false},
		ruleSelector: 'pmd,flow,eslint',
		requiredChecks: [
			'Static Code Analysis',
			'Secret Scan'
		],
		bypassActors: [],
		reviewers: {configFile: '.github/reviewers.json', schemaFile: '.github/reviewers.schema.json'},
		codeownersTeamSlackId: 'S0000000000'
	};
}

function render(name, slackEnabled)
{
	return renderTemplate(path.join(WORKFLOWS_DIR, name), configuration(slackEnabled), {views: WORKFLOWS_DIR});
}

function collectRunBlocks(node, found = [])
{
	if(Array.isArray(node))
	{
		node.forEach(child => collectRunBlocks(child, found));
	}
	else if(node && typeof node === 'object')
	{
		for(const [key, value] of Object.entries(node))
		{
			if(key === 'run' && typeof value === 'string')
			{
				found.push(value);
			}
			else
			{
				collectRunBlocks(value, found);
			}
		}
	}
	return found;
}

function collectSteps(parsed)
{
	const steps = [];
	for(const job of Object.values(parsed.jobs))
	{
		for(const step of job.steps || [])
		{
			steps.push(step);
		}
	}
	return steps;
}

function collectWithInputs(parsed)
{
	const inputs = [];
	for(const step of collectSteps(parsed))
	{
		for(const [key, value] of Object.entries(step.with || {}))
		{
			inputs.push({step: step.name || step.uses, key, value});
		}
	}
	return inputs;
}

const templates = fs.readdirSync(WORKFLOWS_DIR).filter(name => name.endsWith('.yml.eta')).sort();
const partials = fs.readdirSync(PARTIALS_DIR).filter(name => name.endsWith('.eta')).sort().map(name => path.join('_partials', name));

test('every workflow template is found', () =>
{
	assert.ok(templates.length >= 10, `expected at least 10 workflow templates, found ${templates.length}`);
	assert.ok(partials.length >= 2, `expected at least 2 partials, found ${partials.length}`);
});

for(const slackEnabled of [
	true,
	false
])
{
	const mode = slackEnabled ? 'on' : 'off';
	for(const name of templates)
	{
		test(`${name} renders valid YAML with Slack ${mode} and keeps untrusted values out of run blocks`, () =>
		{
			const rendered = render(name, slackEnabled);
			const parsed = yaml.load(rendered);

			assert.ok(parsed && typeof parsed === 'object', `${name} did not parse to a mapping`);
			assert.ok(parsed.jobs && Object.keys(parsed.jobs).length > 0, `${name} has no jobs`);
			for(const block of collectRunBlocks(parsed))
			{
				for(const expression of UNTRUSTED_EXPRESSIONS)
				{
					assert.ok(!block.includes(expression), `${name} puts ${expression} inside a run block`);
				}
			}
		});

		test(`${name} with Slack ${mode} renders every single-line action input on one line`, () =>
		{
			const parsed = yaml.load(render(name, slackEnabled));
			for(const {step, key, value} of collectWithInputs(parsed))
			{
				if(MULTILINE_INPUTS.includes(key) || typeof value !== 'string')
				{
					continue;
				}
				assert.ok(!value.trimEnd().includes('\n'), `${name} step "${step}" input "${key}" contains a line break: ${JSON.stringify(value)}`);
			}
		});

		test(`${name} with Slack ${mode} renders without doubled blank lines and ends with one line break`, () =>
		{
			const rendered = render(name, slackEnabled);
			assert.doesNotMatch(rendered, /\n\n\n/, `${name} renders two blank lines in a row`);
			assert.match(rendered, /[^\n]\n$/, `${name} does not end with exactly one line break`);
		});

		test(`${name} with Slack ${mode} keeps runs-on on its own line`, () =>
		{
			assert.match(render(name, slackEnabled), /runs-on: ubuntu-latest\n\s+\S/);
		});
	}
}

for(const name of templates)
{
	test(`${name} renders no Slack action or webhook secret when Slack is off`, () =>
	{
		const rendered = render(name, false);

		assert.doesNotMatch(rendered, /secrets\.(SLACK|undefined)/);
		assert.doesNotMatch(rendered, /slack-github-action/);
		assert.doesNotMatch(rendered, /webhook/);
	});

	test(`${name} keeps pull request titles and branch names out of Slack payload text when Slack is on`, () =>
	{
		const parsed = yaml.load(render(name, true));
		for(const {step, key, value} of collectWithInputs(parsed))
		{
			if(key !== 'payload' || typeof value !== 'string')
			{
				continue;
			}
			for(const fragment of UNTRUSTED_PAYLOAD_FRAGMENTS)
			{
				assert.ok(!value.includes(fragment), `${name} step "${step}" pastes ${fragment} into its Slack payload`);
			}
		}
	});
}

const PAYLOAD_BUILDERS = {
	'auto-assign.yml.eta': [
		'reviewer_payload',
		'backprom_payload'
	],
	'release-review-assigned.yml.eta': ['release_payload'],
	'pr-ready-to-merge.yml.eta': ['ready_payload']
};

for(const [name, stepIds] of Object.entries(PAYLOAD_BUILDERS))
{
	test(`${name} builds its Slack payloads with JSON.stringify and hands them over as step outputs`, () =>
	{
		const rendered = render(name, true);
		const parsed = yaml.load(rendered);
		const steps = collectSteps(parsed);

		assert.match(rendered, /secrets\.SLACK_WEBHOOK_URL/);
		assert.equal(rendered.match(/JSON\.stringify\(payload\)/g).length, stepIds.length);
		assert.doesNotMatch(rendered, /payload: \|/);
		for(const stepId of stepIds)
		{
			const builder = steps.find(step => step.id === stepId);
			assert.ok(builder, `${name} has no step with id ${stepId}`);
			assert.match(builder.uses, /^actions\/github-script@/);
			assert.match(builder.with.script, /replace\(\/\[<>&\]\/g, ''\)/);
			const sender = steps.find(step => step.with && step.with.payload === `\${{ steps.${stepId}.outputs.payload }}`);
			assert.ok(sender, `${name} has no Slack step reading steps.${stepId}.outputs.payload`);
			assert.equal(sender.if, builder.if, `${name} runs the ${stepId} builder and its Slack step under different conditions`);
		}
	});
}

test('every workflow action reference is pinned to a full commit SHA with its release in a comment', () =>
{
	let references = 0;
	for(const name of templates.concat(partials))
	{
		const text = fs.readFileSync(path.join(WORKFLOWS_DIR, name), 'utf8');
		for(const match of text.matchAll(/uses:\s*(\S+)(.*)/g))
		{
			references++;
			assert.match(match[1], /@[0-9a-f]{40}$/, `${name} has an unpinned action: ${match[1]}`);
			assert.match(match[2], /^ # v\d+\.\d+\.\d+$/, `${name} pins ${match[1]} without a release comment`);
		}
	}
	assert.ok(references >= 10, `expected at least 10 action references across the templates, found ${references}`);
});

test('the bootstrap partial and scanner-parity run Node 22', () =>
{
	for(const name of [
		'_partials/_classify-ref.eta',
		'scanner-parity.yml.eta'
	])
	{
		const text = fs.readFileSync(path.join(WORKFLOWS_DIR, name), 'utf8');
		assert.match(text, /node-version: "22"/, `${name} does not pin Node 22`);
		assert.doesNotMatch(text, /node-version: "20"/, `${name} still pins Node 20`);
	}
});

test('release-review-assigned renders a complete branch filter with and without release branches', () =>
{
	const rendered = render('release-review-assigned.yml.eta', true);
	assert.match(rendered, /base branch is one of: release\n/);
	assert.match(rendered, /&& \(github\.event\.pull_request\.base\.ref == 'release'\)/);

	const withoutReleaseBranches = renderTemplate(path.join(WORKFLOWS_DIR, 'release-review-assigned.yml.eta'), {...configuration(true), releaseBranches: []}, {views: WORKFLOWS_DIR});
	assert.doesNotMatch(withoutReleaseBranches, /one of: \n/);
	assert.match(withoutReleaseBranches, /base branch is one of: \(none configured\)\n/);
	assert.doesNotMatch(withoutReleaseBranches, /&& \(\)/, 'an empty release-branch list renders an empty expression group');
	assert.match(withoutReleaseBranches, /&& \(false\)/);
});
