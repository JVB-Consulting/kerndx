// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const yaml = require('js-yaml');
const pc = require('picocolors');
const {createSession} = require('../lib/prompts.js');
const {renderTemplate} = require('../lib/scaffold.js');
const {hashContent} = require('../lib/hash.js');
const {renderPmdRuleset} = require('../lib/render-pmd-ruleset.js');

const TEMPLATES_DIR = path.join(__dirname, '..', 'templates');
const HUSKY_LINE = './.kerndx-pipeline/bin/kerndx preflight';
const HUSKY_MARKER = '# kerndx-pipeline:preflight';

const WORKFLOW_TEMPLATES = {
	'sfca-quality-gate': 'sfca-quality-gate.yml.eta',
	'secret-scan': 'secret-scan.yml.eta',
	'naming-validation': 'naming-validation.yml.eta',
	'auto-assign': 'auto-assign.yml.eta',
	'pr-ready-to-merge': 'pr-ready-to-merge.yml.eta',
	'ingress-bypass-alert': 'ingress-bypass-alert.yml.eta',
	'release-bypass-alert': 'release-bypass-alert.yml.eta',
	'release-review-assigned': 'release-review-assigned.yml.eta',
	'scanner-parity': 'scanner-parity.yml.eta',
	'validate-reviewers-json': 'validate-reviewers-json.yml.eta'
};

async function collectAnswers(sessionOpts = {})
{
	const session = await createSession(sessionOpts);
	try
	{
		const rawDirs = await session.askText('Package directories (comma-separated) [force-app/main/default]: ');
		const package_dirs_raw = rawDirs.split(',').map(s => s.trim()).filter(Boolean);
		const package_dirs = package_dirs_raw.length === 0 ? ['force-app/main/default'] : package_dirs_raw;

		const framework_package = await session.askYesNo('Does this repo build on the KernDX managed package / framework?', true);

		const ciAdapterName = await session.askChoice('CI tool:', [
			'gearset',
			'copado',
			'autorabit',
			'devops-center',
			'none',
			'custom'
		]);
		const ci_adapter = {name: ciAdapterName};
		if(ciAdapterName === 'copado' || ciAdapterName === 'autorabit')
		{
			const ok = await session.askYesNo(`The "${ciAdapterName}" adapter is experimental. Add experimental: true?`, true);
			if(ok)
			{
				ci_adapter.experimental = true;
			}
			else
			{
				throw new Error('Cannot continue with experimental adapter without acknowledgment');
			}
		}

		const mainBranch = (await session.askText('Main / production branch [main]: ')) || 'main';
		const otherProtectedRaw = await session.askText('Other protected branches (comma-separated, or empty): ');
		const otherProtected = otherProtectedRaw.split(',').map(s => s.trim()).filter(Boolean);
		const releaseRaw = await session.askText('Release branches (get the stricter release gate; comma-separated, or empty): ');
		const releaseBranches = releaseRaw.split(',').map(s => s.trim()).filter(Boolean);
		const branches = {
			main: mainBranch, ingress: [
				mainBranch,
				...otherProtected
			], protected: [...new Set([
				mainBranch,
				...otherProtected,
				...releaseBranches
			])], release: releaseBranches
		};

		const naming = {enabled: await session.askYesNo('Enforce naming standards on Apex/Flows/Objects?', false)};

		const slack = {enabled: await session.askYesNo('Enable Slack notifications?', false)};
		if(slack.enabled)
		{
			slack.webhook_env_var = (await session.askText('Slack webhook env var [SLACK_WEBHOOK_URL]: ')) || 'SLACK_WEBHOOK_URL';
		}

		const workflows = {
			runs_on: 'ubuntu-latest',
			auto_assign_reviewer: await session.askYesNo('Opt-in: auto-assign-reviewer workflow?', false),
			pr_ready_to_merge: await session.askYesNo('Opt-in: pr-ready-to-merge ping?', false),
			ingress_bypass_alert: await session.askYesNo('Opt-in: ingress-bypass-alert?', false),
			release_bypass_alert: await session.askYesNo('Opt-in: release-bypass-alert?', false),
			release_review_assigned: await session.askYesNo('Opt-in: release-review-assigned?', false),
			scanner_parity: await session.askYesNo('Opt-in: scanner-parity drift check?', false),
			validate_reviewers_json: await session.askYesNo('Opt-in: validate-reviewers-json?', false)
		};

		return {package_dirs, framework_package, ci_adapter, branches, naming, slack, workflows};
	}
	finally
	{
		session.close();
	}
}

function writeFileWithDirs(filePath, content)
{
	fs.mkdirSync(path.dirname(filePath), {recursive: true});
	fs.writeFileSync(filePath, content);
}

function appendHuskyHook()
{
	const hookPath = '.husky/pre-push';
	if(fs.existsSync(hookPath))
	{
		const existing = fs.readFileSync(hookPath, 'utf-8');
		if(existing.includes(HUSKY_MARKER) || existing.includes(HUSKY_LINE))
		{
			return {mode: 'already-installed', content: existing};
		}
		const appended = existing.replace(/\s*$/, '\n') + `\n${HUSKY_MARKER}\n${HUSKY_LINE}\n`;
		fs.writeFileSync(hookPath, appended, {mode: 0o755});
		return {mode: 'appended', content: appended};
	}
	const tmplPath = path.join(TEMPLATES_DIR, 'husky', 'pre-push.eta');
	const tmpl = renderTemplate(tmplPath, {});
	fs.mkdirSync('.husky', {recursive: true});
	fs.writeFileSync(hookPath, tmpl, {mode: 0o755});
	return {mode: 'created', content: tmpl};
}

function scaffoldCodeAnalyzerYml(usesFramework = true)
{
	const target = 'code-analyzer.yml';
	if(fs.existsSync(target))
	{
		return {mode: 'preserved', path: target};
	}
	const tmplPath = path.join(TEMPLATES_DIR, 'code-analyzer.yml.eta');
	const rendered = renderTemplate(tmplPath, {usesFramework});
	fs.writeFileSync(target, rendered);
	return {mode: 'created', path: target, content: rendered, ruleset: usesFramework ? 'kerndx-pmd-ruleset.xml' : 'kerndx-hygiene-ruleset.xml'};
}

function rerenderSubscriberNamingRuleset(configRecord, {shippedXmlPath} = {})
{
	const shippedXml = shippedXmlPath || path.resolve(__dirname, '..', '..', '..', 'scanner', 'subscriber-naming-pmd-ruleset.xml');
	if(!fs.existsSync(shippedXml))
	{
		return {mode: 'skipped', reason: 'shipped ruleset not present in pipeline distribution', path: shippedXml};
	}
	const rendered = renderPmdRuleset(configRecord);
	const previous = fs.readFileSync(shippedXml, 'utf-8');
	if(previous === rendered)
	{
		return {mode: 'unchanged', path: shippedXml};
	}
	fs.writeFileSync(shippedXml, rendered);
	return {mode: 'rerendered', path: shippedXml, content: rendered};
}

async function runInit({answers = null, interactive = true} = {})
{
	if(!answers && interactive)
	{
		answers = await collectAnswers();
	}
	if(!answers)
	{
		throw new Error('runInit requires either answers or interactive: true');
	}

	const filesWritten = {};

	// Default true when absent: pre-existing configs and answer sets predate the
	// framework question and were always scaffolded with the full ruleset.
	const usesFramework = answers.framework_package !== false;

	const configRecord = {
		package_dirs: answers.package_dirs, framework_package: usesFramework, ci_adapter: answers.ci_adapter, branches: answers.branches
	};
	if(answers.naming)
	{
		configRecord.naming = answers.naming;
	}
	// Schema places slack under notifications.slack; in-process answers carry
	// it as a top-level slack object. Translate at persistence so a subsequent
	// `upgrade` round-trip preserves Slack settings instead of stripping them.
	if(answers.slack && answers.slack.enabled)
	{
		configRecord.notifications = configRecord.notifications || {};
		configRecord.notifications.slack = answers.slack;
	}
	if(answers.workflows)
	{
		configRecord.workflows = answers.workflows;
	}

	const configYaml = yaml.dump(configRecord);
	writeFileWithDirs('.kerndx/config.yml', configYaml);
	filesWritten['.kerndx/config.yml'] = hashContent(configYaml);

	const codeAnalyzerResult = scaffoldCodeAnalyzerYml(usesFramework);
	const pmdRulesetResult = rerenderSubscriberNamingRuleset(configRecord);
	if(pmdRulesetResult.mode === 'rerendered')
	{
		filesWritten[pmdRulesetResult.path] = hashContent(pmdRulesetResult.content);
	}

	const workflowData = {
		ingressBranches: answers.branches.ingress,
		protectedBranches: answers.branches.protected,
		// branches.release is the explicit answer from init's release-branch
		// question; the protected-minus-ingress fallback keeps configs written
		// before that question existed working unchanged.
		releaseBranches: answers.branches.release || answers.branches.protected.filter(b => !answers.branches.ingress.includes(b)),
		packageDirs: answers.package_dirs,
		nodeVersion: '20',
		runsOn: (answers.workflows && answers.workflows.runs_on) || 'ubuntu-latest',
		ciAdapterName: answers.ci_adapter.name,
		slack: answers.slack || {enabled: false},
		ruleSelector: 'pmd,flow,eslint',
		requiredChecks: [
			'Static Code Analysis',
			'Secret Scan',
			...(answers.naming && answers.naming.enabled ? ['Naming Validation'] : [])
		],
		bypassActors: [],
		reviewers: {configFile: '.github/reviewers.json', schemaFile: '.github/reviewers.schema.json'}, // Fallback Slack subteam ID used by release-review-assigned when
		// .github/reviewers.json doesn't define `teams['release-admins']`.
		// Subscribers can override via answers/config when needed.
		codeownersTeamSlackId: (answers.codeowners_team_slack_id) || ''
	};

	const toScaffold = [
		'sfca-quality-gate',
		'secret-scan'
	];
	if(answers.naming && answers.naming.enabled)
	{
		toScaffold.push('naming-validation');
	}
	for(const [key, optIn] of Object.entries(answers.workflows || {}))
	{
		if(key === 'runs_on')
		{
			continue;
		}
		const wfName = key.replace(/_/g, '-');
		if(optIn && WORKFLOW_TEMPLATES[wfName])
		{
			toScaffold.push(wfName);
		}
	}

	for(const name of toScaffold)
	{
		const tmplPath = path.join(TEMPLATES_DIR, 'workflows', WORKFLOW_TEMPLATES[name]);
		const rendered = renderTemplate(tmplPath, workflowData, {views: path.dirname(tmplPath)});
		const out = `.github/workflows/${name}.yml`;
		writeFileWithDirs(out, rendered);
		filesWritten[out] = hashContent(rendered);
	}

	// Branch-protection rulesets: the next-steps output points `gh ruleset
	// create` at these files, so they must actually land on disk. The release
	// gate only makes sense when a protected branch exists beyond the ingress
	// set; otherwise its include list would be empty and the ruleset inert.
	const rulesetsToScaffold = ['ingress-gate'];
	if(workflowData.releaseBranches.length > 0)
	{
		rulesetsToScaffold.push('release-gate');
	}
	const rulesetsWritten = [];
	const rulesetsPreserved = [];
	for(const name of rulesetsToScaffold)
	{
		const out = `.kerndx/rulesets/${name}.json`;
		// Preserve an existing file, like code-analyzer.yml above: a user may
		// have hand-authored it (earlier releases printed the gh command
		// without ever writing the file), and an unconditional overwrite on
		// upgrade would destroy their bypass actors / required checks.
		if(fs.existsSync(out))
		{
			rulesetsPreserved.push(out);
			continue;
		}
		const tmplPath = path.join(TEMPLATES_DIR, 'rulesets', `${name}.json.eta`);
		const rendered = renderTemplate(tmplPath, workflowData, {views: path.dirname(tmplPath)});
		writeFileWithDirs(out, rendered);
		filesWritten[out] = hashContent(rendered);
		rulesetsWritten.push(out);
	}

	const huskyResult = appendHuskyHook();
	if(huskyResult.mode !== 'already-installed')
	{
		filesWritten['.husky/pre-push'] = hashContent(huskyResult.content);
	}

	const manifest = {
		version: require('../../package.json').version, scaffolded_at: new Date().toISOString(), files: filesWritten
	};
	writeFileWithDirs('.kerndx/manifest.json', JSON.stringify(manifest, null, 2));

	console.log(pc.green('\nScaffold complete.'));
	if(codeAnalyzerResult.mode === 'created')
	{
		console.log(pc.dim(`  Scaffolded code-analyzer.yml (references the bundled ${codeAnalyzerResult.ruleset})`));
	}
	else if(codeAnalyzerResult.mode === 'preserved')
	{
		const expectedRuleset = usesFramework ? 'kerndx-pmd-ruleset.xml' : 'kerndx-hygiene-ruleset.xml';
		console.log(pc.dim(`  Existing code-analyzer.yml preserved (verify it references .kerndx-pipeline/scanner/${expectedRuleset})`));
	}
	if(pmdRulesetResult.mode === 'rerendered')
	{
		console.log(pc.dim('  Regenerated subscriber-naming-pmd-ruleset.xml from .kerndx/config.yml (naming.domains/brands/apex_layers)'));
	}
	else if(pmdRulesetResult.mode === 'unchanged')
	{
		console.log(pc.dim('  subscriber-naming-pmd-ruleset.xml matches defaults (no custom naming config detected)'));
	}
	console.log('\nNext steps:');
	console.log('  npm install                                          # wire husky');
	if(answers.slack && answers.slack.enabled)
	{
		console.log(`  gh secret set ${answers.slack.webhook_env_var || 'SLACK_WEBHOOK_URL'}`);
	}
	for(const out of rulesetsWritten)
	{
		console.log(`  gh ruleset create -F ${out}`);
	}
	for(const out of rulesetsPreserved)
	{
		console.log(pc.dim(`  (${out} already exists — preserved; apply it with: gh ruleset create -F ${out})`));
	}
	if(!rulesetsToScaffold.includes('release-gate'))
	{
		console.log(pc.dim('  (release-gate skipped: no release branches configured)'));
	}
	console.log('  git add . && git commit -m "chore: scaffold kerndx pipeline"');
}

module.exports = {runInit, collectAnswers, appendHuskyHook, scaffoldCodeAnalyzerYml, rerenderSubscriberNamingRuleset};
