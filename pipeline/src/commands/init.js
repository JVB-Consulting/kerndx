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
const {ADAPTERS} = require('../adapters/index.js');

const TEMPLATES_DIR = path.join(__dirname, '..', 'templates');
const DEFAULT_SLACK_WEBHOOK_ENVIRONMENT_VARIABLE = 'SLACK_WEBHOOK_URL';
const HUSKY_LINE = 'node .kerndx-pipeline/bin/kerndx preflight';
const HUSKY_MARKER = '# kerndx-pipeline:preflight';
const HUSKY_HOOK_PATH = '.husky/pre-push';
const HUSKY_HOOK_FILE_MODE = 0o755;

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

// Config keys under `workflows:` (config-schema.json) and the template each
// opt-in scaffolds. The key and the template name do not always agree
// (auto_assign_reviewer renders auto-assign), so the mapping is explicit.
const WORKFLOW_OPT_INS = {
	auto_assign_reviewer: 'auto-assign',
	pr_ready_to_merge: 'pr-ready-to-merge',
	ingress_bypass_alert: 'ingress-bypass-alert',
	release_bypass_alert: 'release-bypass-alert',
	release_review_assigned: 'release-review-assigned',
	scanner_parity: 'scanner-parity',
	validate_reviewers_json: 'validate-reviewers-json'
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
			slack.webhook_env_var = (await session.askText('Slack webhook env var [SLACK_WEBHOOK_URL]: ')) || DEFAULT_SLACK_WEBHOOK_ENVIRONMENT_VARIABLE;
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

// True for a set of answers written as a JSON object: not a list, not text and not null.
function isAnswerObject(value)
{
	return value !== null && typeof value === 'object' && !Array.isArray(value);
}

// True for true or false.
function isBoolean(value)
{
	return typeof value === 'boolean';
}

// True for text that is more than spaces.
function isNonBlankText(value)
{
	return typeof value === 'string' && value.trim() !== '';
}

// True for a list in which every entry is text that is more than spaces. The list may be empty.
function isTextList(value)
{
	return Array.isArray(value) && value.every(isNonBlankText);
}

// True for a list of one or more entries, each text that is more than spaces.
function isNonEmptyTextList(value)
{
	return isTextList(value) && value.length > 0;
}

// True for text that holds a quote character. The workflows put some answers inside quotes, so a quote in the answer would end them early.
function containsQuote(value)
{
	return /['"]/.test(value);
}

// True for text, empty or not, that holds no quote character.
function isTextWithoutQuote(value)
{
	return typeof value === 'string' && !containsQuote(value);
}

// True when the file gives an optional answer but the value is the wrong kind. An answer the file leaves out is never wrong.
function isGivenWithWrongKind(value, isRightKind)
{
	return value !== undefined && !isRightKind(value);
}

// True for a name that starts or ends with a space, or holds a comma. The questions trim each answer and split a list on commas,
// so a file may not give a name the questions would have changed.
function isNameTheQuestionsWouldChange(value)
{
	return typeof value === 'string' && (value !== value.trim() || value.includes(','));
}

// Refuses a name, or a list of names, that the questions would have trimmed or split. A value of the wrong kind is left to the other checks.
function checkNamesAreUnchangedByQuestions(value, filePath, key)
{
	const names = Array.isArray(value) ? value : [value];
	if(names.some(isNameTheQuestionsWouldChange))
	{
		throw createAnswersError(filePath, key, 'names that must not start or end with a space or hold a comma, because the questions trim each answer and split a list on commas');
	}
}

// True for a runner label made only of letters, digits, dots, underscores and dashes.
function isRunnerLabel(value)
{
	return typeof value === 'string' && /^[A-Za-z0-9._-]+$/.test(value);
}

// Makes the error for an answer the file leaves out or gives the wrong kind of value. It names the file and the key.
function createAnswersError(filePath, key, expected)
{
	return new Error(`The answers file ${filePath} needs ${key}: ${expected}`);
}

// package_dirs: a list of one or more folder names, none with a quote, because the workflows put each folder in quotes.
// This check also refuses a file whose JSON is not a set of answers at all.
function checkPackageDirectories(answers, filePath)
{
	if(!isAnswerObject(answers) || !isNonEmptyTextList(answers.package_dirs))
	{
		throw createAnswersError(filePath, 'package_dirs', 'a list of one or more package folders, such as ["force-app/main/default"]');
	}
	if(answers.package_dirs.some(containsQuote))
	{
		throw createAnswersError(filePath, 'package_dirs', 'folder names without a quote character (\' or "), because the workflows put each folder in quotes');
	}
	checkNamesAreUnchangedByQuestions(answers.package_dirs, filePath, 'package_dirs');
}

// ci_adapter.name: one of the CI tools the questions offer. An experimental tool also needs ci_adapter.experimental set to true,
// as the questions ask the user to confirm it.
function checkCiAdapter(answers, filePath)
{
	const ciAdapter = answers.ci_adapter;
	if(!isAnswerObject(ciAdapter) || !Object.hasOwn(ADAPTERS, ciAdapter.name))
	{
		throw createAnswersError(filePath, 'ci_adapter.name', `the CI tool, one of ${Object.keys(ADAPTERS).map((name) => `"${name}"`).join(', ')}`);
	}
	if(ADAPTERS[ciAdapter.name].experimental && ciAdapter.experimental !== true)
	{
		throw createAnswersError(filePath, 'ci_adapter.experimental', `true, to confirm the "${ciAdapter.name}" adapter, which is experimental`);
	}
}

// branches: main is required. ingress and protected, when given, are lists of one or more branch names; release, when given, is a list
// that may be empty. A list left out is filled in the way the questions build it.
function checkBranches(answers, filePath)
{
	const branches = answers.branches;
	if(!isAnswerObject(branches) || !isNonBlankText(branches.main))
	{
		throw createAnswersError(filePath, 'branches.main', 'the name of the main branch, such as "main"');
	}
	checkNamesAreUnchangedByQuestions(branches.main, filePath, 'branches.main');
	const listChecks = {ingress: isNonEmptyTextList, protected: isNonEmptyTextList, release: isTextList};
	for(const [key, isRightKind] of Object.entries(listChecks))
	{
		if(isGivenWithWrongKind(branches[key], isRightKind))
		{
			throw createAnswersError(filePath, `branches.${key}`, 'a list of branch names, such as ["main"]');
		}
		checkNamesAreUnchangedByQuestions(branches[key], filePath, `branches.${key}`);
	}
	branches.ingress ??= [branches.main];
	branches.protected ??= [...new Set([branches.main, ...branches.ingress, ...(branches.release || [])])];
}

// slack, when given: a set of answers. enabled is true or false. When Slack is on, webhook_env_var is the name of the secret that holds
// the webhook, and the default name is filled in when it is left out. suppress_on_pr_title_prefix is text without a quote, because the
// workflow puts it in quotes.
function checkSlack(answers, filePath)
{
	const slack = answers.slack;
	if(isGivenWithWrongKind(slack, isAnswerObject))
	{
		throw createAnswersError(filePath, 'slack', 'a set of answers, such as {"enabled": false}');
	}
	if(isGivenWithWrongKind(slack?.enabled, isBoolean))
	{
		throw createAnswersError(filePath, 'slack.enabled', 'true or false');
	}
	if(slack?.enabled === true && slack.webhook_env_var === undefined)
	{
		slack.webhook_env_var = DEFAULT_SLACK_WEBHOOK_ENVIRONMENT_VARIABLE;
	}
	if(slack?.enabled === true && !isNonBlankText(slack.webhook_env_var))
	{
		throw createAnswersError(filePath, 'slack.webhook_env_var',
			`the name of the secret that holds the Slack webhook, such as "${DEFAULT_SLACK_WEBHOOK_ENVIRONMENT_VARIABLE}"`);
	}
	if(isGivenWithWrongKind(slack?.suppress_on_pr_title_prefix, isTextWithoutQuote))
	{
		throw createAnswersError(filePath, 'slack.suppress_on_pr_title_prefix', 'text without a quote character, such as "chore(deps)"');
	}
}

// naming, when given: a set of answers whose enabled answer, when given, is true or false.
function checkNaming(answers, filePath)
{
	const naming = answers.naming;
	if(isGivenWithWrongKind(naming, isAnswerObject))
	{
		throw createAnswersError(filePath, 'naming', 'a set of answers, such as {"enabled": false}');
	}
	if(isGivenWithWrongKind(naming?.enabled, isBoolean))
	{
		throw createAnswersError(filePath, 'naming.enabled', 'true or false');
	}
}

// workflows, when given: a set of answers. runs_on, when given, is the name of the runner, and each opt-in, when given, is true or false.
function checkWorkflows(answers, filePath)
{
	const workflows = answers.workflows;
	if(isGivenWithWrongKind(workflows, isAnswerObject))
	{
		throw createAnswersError(filePath, 'workflows', 'a set of answers, such as {"runs_on": "ubuntu-latest"}');
	}
	if(isGivenWithWrongKind(workflows?.runs_on, isRunnerLabel))
	{
		throw createAnswersError(filePath, 'workflows.runs_on',
			'the runner label, made only of letters, digits, dots, underscores and dashes, such as "ubuntu-latest", because the workflows use it as it is');
	}
	for(const key of Object.keys(WORKFLOW_OPT_INS))
	{
		if(isGivenWithWrongKind(workflows?.[key], isBoolean))
		{
			throw createAnswersError(filePath, `workflows.${key}`, 'true or false');
		}
	}
}

// The remaining answers, when given: framework_package is true or false, and codeowners_team_slack_id is text without a quote,
// because the workflow puts it in quotes.
function checkRemainingAnswers(answers, filePath)
{
	if(isGivenWithWrongKind(answers.framework_package, isBoolean))
	{
		throw createAnswersError(filePath, 'framework_package', 'true or false');
	}
	if(isGivenWithWrongKind(answers.codeowners_team_slack_id, isTextWithoutQuote))
	{
		throw createAnswersError(filePath, 'codeowners_team_slack_id', 'the Slack team ID as text without a quote character, such as "S0123ABCD"');
	}
}

// True for text that holds a line break (\n or \r).
function containsLineBreak(value)
{
	return /[\r\n]/.test(value);
}

// The text answers that go into the config file and the workflows, each as a pair of key and value. The value is text, a list of text,
// or undefined when the file leaves the answer out. branches.protected comes after the branch lists it may be built from,
// so an error names the answer the file gave.
function listTextAnswers(answers)
{
	return [
		['package_dirs', answers.package_dirs],
		['branches.main', answers.branches.main],
		['branches.ingress', answers.branches.ingress],
		['branches.release', answers.branches.release],
		['branches.protected', answers.branches.protected],
		['workflows.runs_on', answers.workflows?.runs_on],
		['slack.webhook_env_var', answers.slack?.webhook_env_var],
		['slack.suppress_on_pr_title_prefix', answers.slack?.suppress_on_pr_title_prefix],
		['codeowners_team_slack_id', answers.codeowners_team_slack_id]
	];
}

// Each text answer is on one line. The questions read one line at a time, so only a file can give a line break,
// and a line break inside a workflow value would break the workflow file.
function checkLineBreaks(answers, filePath)
{
	for(const [key, value] of listTextAnswers(answers))
	{
		const texts = Array.isArray(value) ? value : [value];
		if(texts.some((text) => typeof text === 'string' && containsLineBreak(text)))
		{
			throw createAnswersError(filePath, key, 'text on one line, without a line break');
		}
	}
}

// Reads the text of the answers file and parses it as JSON. Each error names the file.
function parseAnswersFile(filePath)
{
	let text;
	try
	{
		text = fs.readFileSync(filePath, 'utf-8');
	}
	catch(e)
	{
		throw new Error(`Cannot read the answers file ${filePath}: ${e.message}`);
	}
	try
	{
		return JSON.parse(text);
	}
	catch(e)
	{
		throw new Error(`The answers file ${filePath} is not valid JSON: ${e.message}`);
	}
}

// Reads the answers for `init --answers-file` from a JSON file, in the same shape collectAnswers returns.
// It checks every answer before anything is written, fills in the answers the questions would fill in, and every error names the file and the key.
function readAnswersFile(filePath)
{
	const answers = parseAnswersFile(filePath);
	checkPackageDirectories(answers, filePath);
	checkCiAdapter(answers, filePath);
	checkBranches(answers, filePath);
	checkSlack(answers, filePath);
	checkNaming(answers, filePath);
	checkWorkflows(answers, filePath);
	checkRemainingAnswers(answers, filePath);
	checkLineBreaks(answers, filePath);
	return answers;
}

// In check mode (`init --check`) nothing is written: each file init would write is listed by its path instead.
function reportWouldWrite(filePath)
{
	console.log(`  would write ${filePath}`);
}

// Writes one file that init has rendered, a {path, contents, fileMode} object, and makes its folder first. fileMode, when given, sets the
// permissions of a file that does not exist yet. In check mode it prints the path instead and writes nothing.
function writeOrReportOutput(output, check)
{
	if(check)
	{
		reportWouldWrite(output.path);
	}
	else
	{
		fs.mkdirSync(path.dirname(output.path), {recursive: true});
		fs.writeFileSync(output.path, output.contents, output.fileMode === undefined ? undefined : {mode: output.fileMode});
	}
}

// Works out the pre-push hook init would leave, without writing it: the hook as it is when it already runs preflight ('already-installed'),
// the existing hook with the preflight line added ('appended'), or a new hook from the template ('created').
function renderHuskyHook()
{
	if(fs.existsSync(HUSKY_HOOK_PATH))
	{
		const existing = fs.readFileSync(HUSKY_HOOK_PATH, 'utf-8');
		if(existing.includes(HUSKY_MARKER) || existing.includes(HUSKY_LINE))
		{
			return {mode: 'already-installed', content: existing};
		}
		const appended = existing.replace(/\s*$/, '\n') + `\n${HUSKY_MARKER}\n${HUSKY_LINE}\n`;
		return {mode: 'appended', content: appended};
	}
	const tmplPath = path.join(TEMPLATES_DIR, 'husky', 'pre-push.eta');
	return {mode: 'created', content: renderTemplate(tmplPath, {})};
}

// Works out code-analyzer.yml without writing it. An existing file is kept as it is ('preserved'); otherwise the template is rendered
// with the ruleset that fits the repo ('created').
function renderCodeAnalyzerYml(usesFramework)
{
	const target = 'code-analyzer.yml';
	if(fs.existsSync(target))
	{
		return {mode: 'preserved', path: target};
	}
	const tmplPath = path.join(TEMPLATES_DIR, 'code-analyzer.yml.eta');
	const rendered = renderTemplate(tmplPath, {usesFramework});
	return {mode: 'created', path: target, content: rendered, ruleset: usesFramework ? 'kerndx-pmd-ruleset.xml' : 'kerndx-hygiene-ruleset.xml'};
}

// Works out the subscriber naming ruleset from the naming answers without writing it. It throws when the naming answers are not valid.
function renderSubscriberNamingRuleset(configRecord, {shippedXmlPath} = {})
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
	return {mode: 'rerendered', path: shippedXml, content: rendered};
}

// Builds what init saves in .kerndx/config.yml from the answers.
function buildConfigRecord(answers, usesFramework)
{
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
	return configRecord;
}

// Builds the values the workflow and ruleset templates read from the answers.
function buildWorkflowData(answers)
{
	return {
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
}

// Lists the workflows init scaffolds: the two that always run, naming validation when naming is on, and each opt-in answered yes.
function listWorkflowsToScaffold(answers)
{
	const toScaffold = [
		'sfca-quality-gate',
		'secret-scan'
	];
	if(answers.naming && answers.naming.enabled)
	{
		toScaffold.push('naming-validation');
	}
	for(const [key, wfName] of Object.entries(WORKFLOW_OPT_INS))
	{
		if(answers.workflows && answers.workflows[key] === true)
		{
			toScaffold.push(wfName);
		}
	}
	return toScaffold;
}

// Renders each workflow init scaffolds, without writing it, and returns the files.
function renderWorkflows(answers, workflowData)
{
	return listWorkflowsToScaffold(answers).map((name) =>
	{
		const tmplPath = path.join(TEMPLATES_DIR, 'workflows', WORKFLOW_TEMPLATES[name]);
		return {path: `.github/workflows/${name}.yml`, contents: renderTemplate(tmplPath, workflowData, {views: path.dirname(tmplPath)})};
	});
}

// Renders the branch-protection rulesets without writing them. It returns the files to write, the paths of those files,
// the paths of the existing rulesets it keeps, and the names of every ruleset init scaffolds.
function renderRulesets(workflowData)
{
	// Branch-protection rulesets: the next-steps output points `gh ruleset
	// create` at these files, so they must actually land on disk. The release
	// gate only makes sense when a protected branch exists beyond the ingress
	// set; otherwise its include list would be empty and the ruleset inert.
	const rulesetsToScaffold = ['ingress-gate'];
	if(workflowData.releaseBranches.length > 0)
	{
		rulesetsToScaffold.push('release-gate');
	}
	const outputs = [];
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
		outputs.push({path: out, contents: renderTemplate(tmplPath, workflowData, {views: path.dirname(tmplPath)})});
	}
	return {outputs, rulesetsWritten: outputs.map((output) => output.path), rulesetsPreserved, rulesetsToScaffold};
}

// Renders every file init writes, in the order it writes them, and writes none of them. A render that fails throws here, before
// anything is on disk. It returns the files, each a {path, contents, fileMode} object, and what the summary after the write reports.
function renderOutputs(answers)
{
	const outputs = [];
	const manifestFiles = {};
	const addOutput = (output, isListedInManifest) =>
	{
		outputs.push(output);
		if(isListedInManifest)
		{
			manifestFiles[output.path] = hashContent(output.contents);
		}
	};

	// Default true when absent: pre-existing configs and answer sets predate the
	// framework question and were always scaffolded with the full ruleset.
	const usesFramework = answers.framework_package !== false;
	const configRecord = buildConfigRecord(answers, usesFramework);
	addOutput({path: '.kerndx/config.yml', contents: yaml.dump(configRecord)}, true);

	const codeAnalyzerResult = renderCodeAnalyzerYml(usesFramework);
	if(codeAnalyzerResult.mode === 'created')
	{
		addOutput({path: codeAnalyzerResult.path, contents: codeAnalyzerResult.content}, false);
	}
	const pmdRulesetResult = renderSubscriberNamingRuleset(configRecord);
	if(pmdRulesetResult.mode === 'rerendered')
	{
		addOutput({path: pmdRulesetResult.path, contents: pmdRulesetResult.content}, true);
	}

	const workflowData = buildWorkflowData(answers);
	const workflows = renderWorkflows(answers, workflowData);
	const rulesets = renderRulesets(workflowData);
	[...workflows, ...rulesets.outputs].forEach((output) => addOutput(output, true));

	const huskyResult = renderHuskyHook();
	if(huskyResult.mode !== 'already-installed')
	{
		addOutput({path: HUSKY_HOOK_PATH, contents: huskyResult.content, fileMode: HUSKY_HOOK_FILE_MODE}, true);
	}

	const manifest = {
		version: require('../../package.json').version, scaffolded_at: new Date().toISOString(), files: manifestFiles
	};
	addOutput({path: '.kerndx/manifest.json', contents: JSON.stringify(manifest, null, 2)}, false);

	return {
		outputs, usesFramework, codeAnalyzerResult, pmdRulesetResult, rulesetsWritten: rulesets.rulesetsWritten, rulesetsPreserved: rulesets.rulesetsPreserved,
		rulesetsToScaffold: rulesets.rulesetsToScaffold
	};
}

async function runInit({answers = null, interactive = true, check = false} = {})
{
	if(!answers && interactive)
	{
		answers = await collectAnswers();
	}
	if(!answers)
	{
		throw new Error('runInit requires either answers or interactive: true');
	}

	// Every file is rendered before the first one is written, so a render that fails leaves nothing on disk.
	const {outputs, usesFramework, codeAnalyzerResult, pmdRulesetResult, rulesetsWritten, rulesetsPreserved, rulesetsToScaffold} = renderOutputs(answers);
	outputs.forEach((output) => writeOrReportOutput(output, check));

	if(check)
	{
		// The "would write" lines above are the whole answer; the summary and next steps below describe files that do not exist yet.
		console.log(pc.green('\nCheck only: no files were written. The paths above are the files init would write.'));
		return;
	}

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

module.exports = {runInit, collectAnswers, readAnswersFile, renderSubscriberNamingRuleset};
