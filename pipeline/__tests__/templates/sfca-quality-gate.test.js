// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { renderTemplate } = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'sfca-quality-gate.yml.eta');
const VIEWS = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows');

test('sfca-quality-gate renders for subscriber-equivalent config', () => {
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['build', 'main'],
		packageDirs: ['unpackaged/main/default'],
		nodeVersion: '20',
		ciAdapterName: 'gearset',
		runsOn: 'ubuntu-latest',
		slack: { enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL', suppress_on_pr_title_prefix: '[E2E]' },
		ruleSelector: 'pmd,flow,eslint',
	}, { views: VIEWS });

	assert.match(rendered, /name: sfca-quality-gate/);
	assert.match(rendered, /branches:.*build.*main/);
	assert.match(rendered, /forcedotcom\/run-code-analyzer@v2/);
	assert.match(rendered, /classify-ref/);
	assert.match(rendered, /SLACK_WEBHOOK_URL/);
});

test('sfca-quality-gate without slack omits Slack steps', () => {
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'],
		packageDirs: ['force-app/main/default'],
		nodeVersion: '20',
		ciAdapterName: 'none',
		runsOn: 'ubuntu-latest',
		slack: { enabled: false },
		ruleSelector: 'pmd,flow,eslint',
	}, { views: VIEWS });

	assert.doesNotMatch(rendered, /SLACK_WEBHOOK_URL/);
	assert.doesNotMatch(rendered, /slack-payload/);
});

test('sfca-quality-gate count counts files that survive [-f] filter (not raw diff lines)', () => {
	// Regression L9: delete-only PRs had count>0 (deletes in diff) but TARGETS="",
	// causing SFCA to fail with "workspace not found". Count must reflect files
	// that still exist on HEAD, so the next-step `count > 0` guard is honest.
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'],
		packageDirs: ['force-app/main/default'],
		nodeVersion: '20',
		ciAdapterName: 'none',
		runsOn: 'ubuntu-latest',
		slack: { enabled: false },
		ruleSelector: 'pmd,flow,eslint',
	}, { views: VIEWS });

	assert.match(rendered, /COUNT=\$\(\(COUNT \+ 1\)\)/);
	assert.match(rendered, /after filtering deletes/);
	assert.doesNotMatch(rendered, /COUNT=\$\(wc -l/);
});

test('sfca-quality-gate uses explicit merge-base for PR diff', () => {
	// Regression: prior template used `origin/$BASE...HEAD` (three-dot) which
	// silently returned 0 files in GH Actions because the redirect operator
	// landed on its own line, separated from the diff command. Switching to
	// explicit merge-base + two-dot diff and continuing every line with a
	// backslash fixes both problems and emits diagnostic SHAs.
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'],
		packageDirs: ['force-app/main/default'],
		nodeVersion: '20',
		ciAdapterName: 'none',
		runsOn: 'ubuntu-latest',
		slack: { enabled: false },
		ruleSelector: 'pmd,flow,eslint',
	}, { views: VIEWS });

	assert.match(rendered, /BASE_SHA=\$\(git merge-base "\$BASE_REF" HEAD\)/);
	assert.match(rendered, /HEAD_SHA=\$\(git rev-parse HEAD\)/);
	assert.match(rendered, /git diff --name-only "\$BASE_SHA" "\$HEAD_SHA" --/);
	assert.doesNotMatch(rendered, /origin\/.*\.\.\.HEAD/);
});

test('sfca-quality-gate blocks on sev1 OR sev2 (not sev1 alone)', () => {
	// Regression: PMD priority-1 rules (KernDX framework rules) map to
	// SFCA sev2 (High), not sev1 (Critical). A sev1-only gate would never
	// block KernDX rule violations. Verify the gate matches both severities.
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'],
		packageDirs: ['force-app/main/default'],
		nodeVersion: '20',
		ciAdapterName: 'none',
		runsOn: 'ubuntu-latest',
		slack: { enabled: false },
		ruleSelector: 'pmd,flow,eslint',
	}, { views: VIEWS });

	assert.match(rendered, /num-sev1-violations-in-changed-files > 0/);
	assert.match(rendered, /num-sev2-violations-in-changed-files > 0/);
	assert.match(rendered, /critical \+ \$\{SEV2\} high severity/);
});

test('sfca-quality-gate diff command ends with proper redirect (no orphan)', () => {
	// Regression: the rendered shell snippet must place `> changed-files.txt`
	// on a continuation line after a trailing `\`, not on a standalone line
	// (which would silently truncate the file to empty). Verify by extracting
	// the diff block + checking every non-trailing line ends with `\`.
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'],
		packageDirs: ['force-app/main/default', 'src-shared'],
		nodeVersion: '20',
		ciAdapterName: 'none',
		runsOn: 'ubuntu-latest',
		slack: { enabled: false },
		ruleSelector: 'pmd,flow,eslint',
	}, { views: VIEWS });

	const start = rendered.indexOf('git diff --name-only');
	const end = rendered.indexOf('changed-files.txt', start);
	assert.ok(start !== -1 && end !== -1, 'diff block must exist');
	const block = rendered.slice(start, end + 'changed-files.txt'.length);
	const lines = block.split('\n');
	for (let i = 0; i < lines.length - 1; i++)
	{
		const line = lines[i].trimEnd();
		assert.ok(line.endsWith('\\'), `line ${i} must end with backslash continuation: ${JSON.stringify(line)}`);
	}
	assert.match(lines[lines.length - 1], /^\s*> changed-files\.txt\s*$/);
});
