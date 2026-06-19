#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Namespace-swap script for KernDX release clones. Rewrites the
 *              working tree from the `kern` namespace to a subscriber-chosen
 *              namespace (Path 2 — repackage under your own namespace). Runs
 *              once per clone; refuses re-execution after the
 *              .namespace-origin.json marker is written. See bin/README.md
 *              for usage.
 * @author Kern Framework
 * @date May 2026
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const RESERVED = new Set(['kern', 'kernx', 'kdx', 'kerndx', 'sf', 'sfdx', 'salesforce', 'test', 'admin', 'system']);

/**
 * @description Validates a target namespace string and derives its
 *              camelCase + PascalCase forms.
 * @param {string} input - Target namespace.
 * @return {{camel: string, pascal: string}}
 * @throws {Error} On length, format, or reserved-name violations.
 */
function validateNamespace(input)
{
	if(typeof input !== 'string' || input.length === 0 || input.length > 15)
	{
		throw new Error(`Invalid namespace: '${input}'. Must be 1-15 alphanumeric chars starting with a letter.`);
	}
	if(!/^[a-zA-Z][a-zA-Z0-9]*$/.test(input))
	{
		throw new Error(`Invalid namespace: '${input}'. Must start with a letter and contain only alphanumeric chars.`);
	}
	if(RESERVED.has(input.toLowerCase()))
	{
		throw new Error(`Namespace '${input}' is reserved (kern, kernx, kdx, kerndx, sf, sfdx, salesforce, test, admin, system are blocked).`);
	}
	const camel = input;
	const pascal = input.charAt(0).toUpperCase() + input.slice(1);
	return {camel, pascal};
}

/**
 * @description Checks whether the working-copy root has already been
 *              swapped. Presence of `.namespace-origin.json` is the
 *              definitive marker.
 * @param {string} workingCopyRoot
 */
function detectAlreadySwapped(workingCopyRoot)
{
	return fs.existsSync(path.join(workingCopyRoot, '.namespace-origin.json'));
}

/**
 * @description Walks force-app/ once and discovers compound tokens
 *              (kernSomething, KernSomething) from file/dir names. Returns
 *              the token set plus a `deriveRules(targets)` builder that
 *              emits case-preserving substitution rules sorted longest-
 *              first (compound rules before the base `kern__` rule).
 * @param {string} workingCopyRoot
 */
function buildInventory(workingCopyRoot)
{
	const compoundTokens = new Set();
	const matches = [];

	function walk(dir)
	{
		if(!fs.existsSync(dir)) return;
		for(const entry of fs.readdirSync(dir, {withFileTypes: true}))
		{
			const full = path.join(dir, entry.name);
			const base = path.basename(entry.name, path.extname(entry.name));
			if(/kern/i.test(base))
			{
				const match = base.match(/^(kern|Kern)([A-Z][a-zA-Z0-9]*)?/);
				if(match && match[2]) compoundTokens.add(`${match[1]}${match[2]}`);
				matches.push(full);
			}
			if(entry.isDirectory()) walk(full);
		}
	}
	walk(path.join(workingCopyRoot, 'force-app'));

	return {
		compoundTokens: [...compoundTokens],
		matchedPaths: matches,
		deriveRules(targets)
		{
			const baseRules = [
				{from: 'kern__', to: `${targets.camel}__`},
				{from: 'kern.', to: `${targets.camel}.`},
				{from: "'kern'", to: `'${targets.camel}'`},
				{from: '"kern"', to: `"${targets.camel}"`},
				// LWC cross-namespace imports: `import {X} from 'kern/moduleName'`
				// (or double-quoted). Required for subscriber LWCs that import
				// kern-published modules — release-testing/subscriber/lwc/*
				// uses this pattern. Without these rules the swap leaves
				// `from 'kern/...'` intact and the subsequent managed-package
				// deploy fails with "No MODULE named markup://kern:..." because
				// the subscriber org has the swapped namespace installed.
				{from: "'kern/", to: `'${targets.camel}/`},
				{from: '"kern/', to: `"${targets.camel}/`},
				// Custom-element prefix used by kern-* LWC component naming
				// docs and sample HTML snippets. Literal substring match —
				// no over-match risk because the trailing dash makes the
				// pattern specific to that idiom.
				{from: 'kern-', to: `${targets.camel}-`},
				// Sample path used in subscriber-facing docs. Same reason:
				// literal substring match, no regex.
				{from: '/tmp/kern-', to: `/tmp/${targets.camel}-`}
			];
			const compoundRules = [...compoundTokens].map(t =>
			{
				if(t[0] === 'k') return {from: t, to: targets.camel + t.slice(4)};
				return {from: t, to: targets.pascal + t.slice(4)};
			});
			return [...compoundRules, ...baseRules];
		}
	};
}

const REPLACEMENT_CAP = 10000;

/**
 * @description Applies rule-set substitutions to file content, tracking
 *              total replacements. Hard-fails over the 10000 cap
 *              (catches regex drift where a pattern silently matches prose).
 * @param {string} content
 * @param {{from: string, to: string}[]} rules
 * @return {{text: string, replacements: number}}
 * @throws {Error} When replacement count exceeds REPLACEMENT_CAP.
 */
function applyContentSubstitutions(content, rules)
{
	let text = content;
	let replacements = 0;
	const perRule = {};
	for(const rule of rules)
	{
		const before = text;
		text = text.split(rule.from).join(rule.to);
		const safeCount = before.split(rule.from).length - 1;
		replacements += safeCount;
		if(safeCount > 0)
		{
			perRule[rule.from] = (perRule[rule.from] || 0) + safeCount;
		}
	}
	if(replacements > REPLACEMENT_CAP)
	{
		throw new Error(`File exceeded 10000 replacements (${replacements}) — regex drift suspected, aborting swap.`);
	}
	return {text, replacements, perRule};
}

const BINARY_EXTENSIONS = new Set([
	'.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.zip', '.pdf',
	'.woff', '.woff2', '.ttf', '.otf', '.eot', '.asset', '.resource'
]);

function isLikelyUtf8(buf) { try { return !buf.includes(0); } catch(e) { return false; } }

/**
 * @description Phase 5 of the swap script. Whole-working-tree staging,
 *              content substitution + filesystem renames inside staging,
 *              marker file written into staging, journal-tracked rename-A
 *              and rename-B with automatic rollback on partial failure.
 *              Lockfile prevents parallel execution.
 * @param {string} workingCopyRoot - Absolute path to the bundle's working tree.
 * @param {string} targetNamespace - The chosen subscriber namespace.
 * @param {{dryRun?: boolean}} opts
 */
/**
 * @description Generates a short, factual README stub for subscribers after
 *              swap. Replaces the swap-transformed kern README so subscribers
 *              don't ship a doc that reads like the KernDX framework project's
 *              own README. The --keep-readme flag opts out.
 * @param {string} namespaceCamel - The subscriber's target namespace (camel).
 * @return {string} Markdown content for README.md.
 */
function buildReadmeStub(namespaceCamel)
{
	return `# ${namespaceCamel}

This project was built from [KernDX](https://github.com/JVB-Consulting/kerndx) under the \`${namespaceCamel}\` namespace via \`bin/swap-namespace.js\`.

## Documentation

See [\`docs/\`](./docs/) for the rebranded framework guides:

- [\`docs/Installation.md\`](./docs/Installation.md) — post-swap setup
- [\`docs/Code Conventions - Guide.md\`](./docs/Code%20Conventions%20-%20Guide.md) — canonical code conventions
- [\`docs/README.md\`](./docs/README.md) — full documentation index

## License

KernDX is BSL 1.1 source-available (four-year clock to Apache 2.0). See [\`LICENSE\`](./LICENSE).
`;
}

function executeSwap(workingCopyRoot, targetNamespace, opts)
{
	opts = opts || {};
	if(detectAlreadySwapped(workingCopyRoot))
	{
		throw new Error('Tree already swapped — re-extract from the original zip to swap to a different namespace.');
	}

	const lockPath = path.join(workingCopyRoot, '.namespace-swap.lock');
	if(fs.existsSync(lockPath))
	{
		const pid = fs.readFileSync(lockPath, 'utf8').trim();
		throw new Error(`Another swap is in progress (PID ${pid}). If no longer running, remove ${lockPath} and retry.`);
	}
	fs.writeFileSync(lockPath, String(process.pid));

	try
	{
		const targets = validateNamespace(targetNamespace);
		const inventory = buildInventory(workingCopyRoot);
		const rules = inventory.deriveRules(targets);

		const stagingDir = path.join(workingCopyRoot, '.swap-staging', 'working-tree');
		fs.rmSync(path.join(workingCopyRoot, '.swap-staging'), {recursive: true, force: true});
		fs.mkdirSync(stagingDir, {recursive: true});

		const auditFiles = [], auditRenames = [], auditSkipped = [];
		const auditPerRule = {};

		function copyAndTransform(srcRel)
		{
			const src = path.join(workingCopyRoot, srcRel);
			const dst = path.join(stagingDir, srcRel);
			const stat = fs.statSync(src);
			if(stat.isDirectory())
			{
				fs.mkdirSync(dst, {recursive: true});
				for(const entry of fs.readdirSync(src))
				{
					// Skip swap-machinery, npm-managed dependency tree, and git
					// metadata. Subscribers who ran `npm ci` before the swap
					// would otherwise see dependency JS rewritten in place
					// (kern → <target>) — wasteful AND potentially corrupting.
					if(['.swap-staging', '.swap-rollback', '.namespace-swap.lock', 'node_modules', '.git'].includes(entry)) continue;
					copyAndTransform(path.join(srcRel, entry));
				}
				return;
			}
			const ext = path.extname(srcRel).toLowerCase();
			if(BINARY_EXTENSIONS.has(ext))
			{
				fs.mkdirSync(path.dirname(dst), {recursive: true});
				fs.copyFileSync(src, dst);
				auditSkipped.push({path: srcRel, reason: 'binary'});
				return;
			}
			const buf = fs.readFileSync(src);
			if(!isLikelyUtf8(buf))
			{
				fs.mkdirSync(path.dirname(dst), {recursive: true});
				fs.copyFileSync(src, dst);
				auditSkipped.push({path: srcRel, reason: 'non-utf8'});
				return;
			}
			const result = applyContentSubstitutions(buf.toString('utf8'), rules);
			fs.mkdirSync(path.dirname(dst), {recursive: true});
			fs.writeFileSync(dst, result.text);
			if(result.replacements > 0) auditFiles.push({path: srcRel, replacements: result.replacements});
			for(const [rule, n] of Object.entries(result.perRule || {}))
			{
				auditPerRule[rule] = (auditPerRule[rule] || 0) + n;
			}
		}

		for(const entry of fs.readdirSync(workingCopyRoot))
		{
			if(['.swap-staging', '.swap-rollback', '.namespace-swap.lock', '.namespace-origin.json', 'node_modules', '.git'].includes(entry)) continue;
			copyAndTransform(entry);
		}

		function renamePathsBottomUp(dir)
		{
			for(const entry of fs.readdirSync(dir, {withFileTypes: true}))
			{
				const full = path.join(dir, entry.name);
				if(entry.isDirectory()) renamePathsBottomUp(full);
				if(/kern/i.test(entry.name))
				{
					let newName = entry.name;
					for(const rule of rules)
					{
						// Salesforce CMDT records under release-testing/subscriber/
						// use the `kern__TypeName.recordName.md-meta.xml` filename
						// convention — the namespaced CMDT type IS encoded in the
						// filename. The `kern__` rule MUST apply to filenames so
						// these records deploy under the swapped namespace.
						if(rule.from === 'kern__') newName = newName.split(rule.from).join(rule.to);
						else if(/^[A-Z]/.test(rule.from)) newName = newName.split(rule.from).join(rule.to);
						else if(/^[a-z]/.test(rule.from) && !rule.from.includes('.') && !rule.from.includes('_') && !rule.from.includes('/') && !rule.from.includes("'") && !rule.from.includes('"')) newName = newName.split(rule.from).join(rule.to);
					}
					if(newName !== entry.name)
					{
						const newFull = path.join(dir, newName);
						fs.renameSync(full, newFull);
						auditRenames.push({from: path.relative(stagingDir, full), to: path.relative(stagingDir, newFull)});
					}
				}
			}
		}
		renamePathsBottomUp(stagingDir);

		const sfdxTemplate = path.join(stagingDir, 'sfdx-project.template.json');
		if(fs.existsSync(sfdxTemplate))
		{
			const content = JSON.parse(fs.readFileSync(sfdxTemplate, 'utf8'));
			content.namespace = targets.camel;
			fs.writeFileSync(path.join(stagingDir, 'sfdx-project.json'), JSON.stringify(content, null, 2) + '\n');
			fs.unlinkSync(sfdxTemplate);
			auditRenames.push({from: 'sfdx-project.template.json', to: 'sfdx-project.json'});
		}
		const pkgPath = path.join(stagingDir, 'package.json');
		if(fs.existsSync(pkgPath))
		{
			const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
			if(pkg.name === 'salesforce-app') { pkg.name = targets.camel; fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n'); }
		}

		const marker = {
			original_namespace: 'kern',
			swap_target: targets.camel,
			swapped_at: new Date().toISOString(),
			swap_script_version: '1.0.0'
		};
		fs.writeFileSync(path.join(stagingDir, '.namespace-origin.json'), JSON.stringify(marker, null, 2) + '\n');

		if(opts.dryRun) return {dryRun: true, audit: {files: auditFiles, renames: auditRenames, skipped: auditSkipped}};

		const rollbackDir = path.join(workingCopyRoot, '.swap-rollback', 'working-tree-backup');
		fs.mkdirSync(path.join(workingCopyRoot, '.swap-rollback'), {recursive: true});
		const journalPath = path.join(workingCopyRoot, '.swap-rollback', 'journal.log');
		fs.writeFileSync(journalPath, '');

		const stagingEntries = fs.readdirSync(stagingDir);
		// Files moved out of workingCopyRoot during renameA. Normally equals
		// stagingEntries, but includes sfdx-project.template.json if the
		// original is still in workingCopyRoot (the swap renamed the template
		// staging-side into sfdx-project.json + deleted the template from
		// staging, so without this extra entry the original template would
		// survive in workingCopyRoot post-swap).
		const renameAEntries = [...stagingEntries];
		if(fs.existsSync(path.join(workingCopyRoot, 'sfdx-project.template.json')) && !stagingEntries.includes('sfdx-project.template.json'))
		{
			renameAEntries.push('sfdx-project.template.json');
		}
		const completedRenameA = [];
		try
		{
			for(const entry of renameAEntries)
			{
				const src = path.join(workingCopyRoot, entry);
				const dst = path.join(rollbackDir, entry);
				if(fs.existsSync(src))
				{
					fs.mkdirSync(rollbackDir, {recursive: true});
					fs.renameSync(src, dst);
					fs.appendFileSync(journalPath, `renameA ${entry}\n`);
					completedRenameA.push(entry);
				}
			}
			const completedRenameB = [];
			try
			{
				for(const entry of stagingEntries)
				{
					fs.renameSync(path.join(stagingDir, entry), path.join(workingCopyRoot, entry));
					fs.appendFileSync(journalPath, `renameB ${entry}\n`);
					completedRenameB.push(entry);
				}
			}
			catch(errB)
			{
				for(const entry of completedRenameB.reverse())
				{
					try { fs.renameSync(path.join(workingCopyRoot, entry), path.join(stagingDir, entry)); } catch(e) {}
				}
				for(const entry of completedRenameA.reverse())
				{
					try { fs.renameSync(path.join(rollbackDir, entry), path.join(workingCopyRoot, entry)); } catch(e) {}
				}
				throw new Error(`Rename-B failed and was rolled back. Original tree restored. Cause: ${errB.message}`);
			}
		}
		catch(errA)
		{
			for(const entry of completedRenameA.reverse())
			{
				try { fs.renameSync(path.join(rollbackDir, entry), path.join(workingCopyRoot, entry)); } catch(e) {}
			}
			throw new Error(`Rename-A failed and was rolled back. Original tree restored. Cause: ${errA.message}`);
		}

		fs.rmSync(path.join(workingCopyRoot, '.swap-staging'), {recursive: true, force: true});
		fs.rmSync(path.join(workingCopyRoot, '.swap-rollback'), {recursive: true, force: true});

		const readmePath = path.join(workingCopyRoot, 'README.md');
		const readmeReplaced = !opts.keepReadme && fs.existsSync(readmePath);
		if(readmeReplaced)
		{
			fs.writeFileSync(readmePath, buildReadmeStub(targets.camel));
		}

		// Per-rule residual counts — surfaces which substitution rules
		// actually fired (and how often). Useful for diagnosing "did the
		// kern- rule catch anything?" without parsing the JSON audit.
		const perRuleLines = Object.entries(auditPerRule)
			.sort((a, b) => b[1] - a[1])
			.map(([rule, n]) => `  ${String(n).padStart(6)}  ${rule}`)
			.join('\n');
		const perRuleBlock = perRuleLines
			? `\nPer-rule replacement counts (sorted by frequency):\n${perRuleLines}\n`
			: '\nPer-rule replacement counts: (no rules fired)\n';

		fs.writeFileSync(path.join(workingCopyRoot, '.namespace-swap.log'),
			`Swap to '${targets.camel}' complete.\nFiles touched: ${auditFiles.length}\nRenames: ${auditRenames.length}\nSkipped binaries: ${auditSkipped.length}\nREADME stub: ${readmeReplaced ? 'replaced' : 'kept'}\n${perRuleBlock}`);
		fs.writeFileSync(path.join(workingCopyRoot, '.namespace-swap.json'),
			JSON.stringify({swap_target: targets.camel, files: auditFiles, renames: auditRenames, skipped: auditSkipped, per_rule_replacements: auditPerRule, readme_replaced: readmeReplaced}, null, 2) + '\n');

		return {audit: {files: auditFiles, renames: auditRenames, skipped: auditSkipped, perRule: auditPerRule, readmeReplaced}};
	}
	finally
	{
		if(fs.existsSync(lockPath)) fs.unlinkSync(lockPath);
	}
}

module.exports = {validateNamespace, detectAlreadySwapped, buildInventory, applyContentSubstitutions, executeSwap, buildReadmeStub};

if(require.main === module)
{
	const args = process.argv.slice(2);
	const target = args.find(a => !a.startsWith('--'));
	const dryRun = args.includes('--dry-run');
	const keepReadme = args.includes('--keep-readme');
	if(!target) { console.error('Usage: node bin/swap-namespace.js <namespace> [--dry-run] [--keep-readme]'); process.exit(1); }
	try
	{
		const result = executeSwap(process.cwd(), target, {dryRun, keepReadme});
		console.log(`Swap to '${target}' complete.`);
		if(result && result.audit && result.audit.readmeReplaced)
		{
			console.log(`README.md replaced with subscriber stub. Pass --keep-readme to preserve your own README on a future swap.`);
		}
		if(!dryRun)
		{
			console.log('');
			console.log('Next steps:');
			console.log('  1. git init && git add -A && git commit -m "rebrand to ' + target + '"');
			console.log('  2. sf package create --name "<YourPackageName>" --package-type "Managed" --path "force-app" --target-dev-hub <DevHub>');
			console.log('  3. node scripts/build-package.js --package "<YourPackageName>" --no-resync');
			console.log('');
			console.log('See docs/Installation.md "Path 2: Repackage Under Your Own Namespace" for full walkthrough.');
			console.log('Do NOT run `sf package version create` directly — it skips the namespace-prefix injection step.');
		}
	}
	catch(err) { console.error(err.message); process.exit(1); }
}
