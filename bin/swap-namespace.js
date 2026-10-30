#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
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
				// Obfuscated stack frame a subscriber org renders for every run
				// of managed-package code, e.g. `(kern)`. Tests and ApexDoc pair
				// it with the quoted namespace literal, which the 'kern' rule
				// rewrites; without this rule the frame stays under the old
				// namespace and those tests fail in the subscriber's build.
				{from: '(kern)', to: `(${targets.camel})`},
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

This code is KernDX, licensed under the Apache License 2.0. \`bin/swap-namespace.js\` renamed its namespace from \`kern\` to \`${namespaceCamel}\`. This README is the notice of that change.

See [\`LICENSE\`](./LICENSE) for the licence text, and [\`NOTICES.md\`](./NOTICES.md) for the files that come from other open-source projects and their own notice requirements.
`;
}

const VERIFIED_EXTENSIONS = new Set(['.cls', '.trigger', '.xml', '.js', '.html']);
const STARTING_TREE = ['force-app', 'sfdx-project.template.json'];

/**
 * @description Writes a path the way git and the audit files want it, whatever system produced it.
 * @param {string} filePath - A path that may use backslashes.
 * @returns {string} The same path with forward slashes.
 */
function toForwardSlashes(filePath)
{
	return filePath.replace(/\\/g, '/');
}

/**
 * @description Names what a folder lacks to be the top folder of a KernDX clone.
 * @param {string} workingCopyRoot - The folder the command was run from.
 * @returns {string[]} The missing names; empty when the folder is a clone.
 */
function checkStartingTree(workingCopyRoot)
{
	return STARTING_TREE.filter(name => !fs.existsSync(path.join(workingCopyRoot, name)));
}

/**
 * @description Builds the pattern that finds a leftover reference to a namespace. Built from the marker's own
 *              recorded namespace rather than a literal, so the swap rewriting this script's own source cannot
 *              corrupt the pattern. No escaping is needed: namespaces are validated alphanumeric elsewhere, so
 *              they carry no regex metacharacters.
 * @param {string} originalNamespace - The namespace the tree was swapped from.
 * @returns {RegExp} A pattern matching any of the four leftover forms for that namespace.
 */
function leftoverReferencePattern(originalNamespace)
{
	return new RegExp(`${originalNamespace}\\.|${originalNamespace}__|'${originalNamespace}/|"${originalNamespace}/`);
}

/**
 * @description Reports whether a swap happened and whether any reference to the original namespace is left in
 *              force-app. Reads only; writes nothing.
 * @param {string} workingCopyRoot - The top folder of the clone.
 * @returns {{swapped: boolean, marker: Object|null, leftovers: Array<{path: string, line: number, text: string}>}} The report.
 * @throws {Error} When the marker names no original namespace.
 */
function verifySwap(workingCopyRoot)
{
	const markerPath = path.join(workingCopyRoot, '.namespace-origin.json');
	if(!fs.existsSync(markerPath))
	{
		return {swapped: false, marker: null, leftovers: []};
	}
	const marker = JSON.parse(fs.readFileSync(markerPath, 'utf8'));
	if(typeof marker.original_namespace !== 'string' || marker.original_namespace.length === 0)
	{
		throw new Error('The marker .namespace-origin.json names no original namespace, so the tree cannot be verified. Run the swap again from a fresh clone.');
	}
	const leftoverReference = leftoverReferencePattern(marker.original_namespace);
	const leftovers = [];
	function walk(directory)
	{
		if(!fs.existsSync(directory))
		{
			return;
		}
		for(const entry of fs.readdirSync(directory, {withFileTypes: true}))
		{
			const full = path.join(directory, entry.name);
			if(entry.isDirectory())
			{
				walk(full);
			}
			else if(VERIFIED_EXTENSIONS.has(path.extname(entry.name).toLowerCase()))
			{
				fs.readFileSync(full, 'utf8').split('\n').forEach((text, index) =>
				{
					if(leftoverReference.test(text))
					{
						leftovers.push({path: toForwardSlashes(path.relative(workingCopyRoot, full)), line: index + 1, text: text.trim()});
					}
				});
			}
		}
	}
	walk(path.join(workingCopyRoot, 'force-app'));
	return {swapped: true, marker, leftovers};
}

/**
 * @description The next steps printed after a swap: one command per line, pasteable into any terminal.
 * @param {string} target - The namespace the tree was swapped to.
 * @returns {string} The text to print.
 */
function nextStepsText(target)
{
	return [
		'',
		'Next steps. Run each line on its own, from this folder:',
		'  git add -A',
		`  git commit -m "rebrand to ${target}"`,
		'  sf package create --name "YourPackageName" --package-type "Managed" --path "force-app" --target-dev-hub YourDevHubAlias',
		'  node scripts/build-package.js --package "YourPackageName" --dev-org YourDevHubAlias --no-resync',
		'',
		'Replace YourPackageName and YourDevHubAlias with your own. The build needs --dev-org: without it, it looks for a Dev Hub called DevHub.',
		'See docs/Installation.md "Path 2: Repackage Under Your Own Namespace" for the full walkthrough.',
		'Do NOT run `sf package version create` directly: it skips the step that adds your namespace prefix.'
	].join('\n');
}

/**
 * @description The codes an operating system reports when another program is holding a file the swap needs, whether
 *              it is reading that file, replacing it or moving it.
 */
const FILE_IN_USE_CODES = new Set(['EPERM', 'EBUSY', 'EACCES']);

/**
 * @description Builds the message a failed swap shows. A failure caused by another program holding a file open gains
 *              a sentence naming that file and saying what to close; any other failure keeps its own message.
 * @param {Error} failure - What the swap threw, carrying the operating system's code and path when it has them.
 * @returns {string} The message to show the reader.
 */
function buildFailureMessage(failure)
{
	if(!FILE_IN_USE_CODES.has(failure.code))
	{
		return failure.message;
	}
	const heldPath = failure.path ?? failure.dest;
	const namesTheFile = heldPath ? ` Something has this open: ${heldPath}.` : '';
	// A reader whose original files are sitting in the rollback folder must put those back first: running the command
	// again while they are there is the one instruction that would make things worse.
	const whatToDoNext = failure.originalsLeftBehind
		? ' Close editors and terminals that are open inside the project, then move your original files back.'
		: ' Close editors and terminals that are open inside the project, then run the command again.';
	return `${failure.message}${namesTheFile}${whatToDoNext}`;
}

/**
 * @description Reports whether the rollback folder still holds files belonging to the reader. Read from the disk
 *              rather than from anything the run remembers, because a run that could not put a file back, and a run
 *              started after one of those, both see the same folder.
 * @param {string} workingCopyRoot - The top folder of the clone.
 * @returns {boolean} True when the rollback folder holds anything at all.
 */
function rollbackHoldsOriginals(workingCopyRoot)
{
	const backupDirectory = path.join(workingCopyRoot, '.swap-rollback', 'working-tree-backup');
	try
	{
		return fs.readdirSync(backupDirectory).length > 0;
	}
	catch
	{
		// No folder to read means nothing of the reader's is in it. Anything else the swap cannot see into, it treats
		// as holding files: a folder it cannot list is a folder it must not delete.
		return fs.existsSync(backupDirectory);
	}
}

/**
 * @description Removes a folder the swap itself made, and says what the reader needs to hear when it will not go.
 * @param {string} folder - The folder to remove.
 * @returns {string} Empty when the folder is gone, otherwise a sentence naming it.
 */
function removeSwapFolder(folder)
{
	try
	{
		fs.rmSync(folder, {recursive: true, force: true});
		return '';
	}
	catch
	{
		return ` The folder ${folder} could not be removed: delete it by hand.`;
	}
}

/**
 * @description Moves a set of entries back where they came from, one by one, and reports whether every one arrived.
 *              An entry that will not move is left where it is: the caller tells the reader about it.
 * @param {string[]} entries - The names to move, in the order to move them.
 * @param {string} fromDirectory - The folder holding them now.
 * @param {string} toDirectory - The folder they belong in.
 * @returns {boolean} True when every entry was moved back.
 */
function moveEntriesBack(entries, fromDirectory, toDirectory)
{
	let allMoved = true;
	for(const entry of entries)
	{
		try
		{
			fs.renameSync(path.join(fromDirectory, entry), path.join(toDirectory, entry));
		}
		catch
		{
			allMoved = false;
		}
	}
	return allMoved;
}

/**
 * @description Builds the failure thrown when one of the swap's two move passes could not finish. It says either that
 *              the original tree is back in place or where the original files were left, and it carries the operating
 *              system's code and path so the message can name what is holding the file.
 * @param {string} passName - The name of the move pass that failed, as the reader sees it.
 * @param {Error} cause - What the move pass threw.
 * @param {{originalsReturned: boolean, everythingReturned: boolean}} unwind - What the unwind managed to put back:
 *              whether every original file reached the project again, and whether that also cleared out everything
 *              the swap had written into it.
 * @param {string} rollbackDirectory - Where the swap keeps the original files while it runs.
 * @returns {Error} The failure to throw.
 */
function buildMoveFailure(passName, cause, unwind, rollbackDirectory)
{
	let message;
	if(unwind.everythingReturned)
	{
		message = `${passName} failed and was rolled back. Original tree restored. Cause: ${cause.message}`;
	}
	else if(unwind.originalsReturned)
	{
		message = `${passName} failed and your original files are back in place, but the swap`
			+ ` could not take back everything it had written. Compare this folder with your clone`
			+ ` before running the command again. Cause: ${cause.message}`;
	}
	else
	{
		message = `${passName} failed and the tree could not be put back.`
			+ ` Your original files are in ${rollbackDirectory}: move them back yourself. Cause: ${cause.message}`;
	}
	return Object.assign(new Error(message), {code: cause.code, path: cause.path, originalsLeftBehind: !unwind.originalsReturned});
}

function executeSwap(workingCopyRoot, targetNamespace, opts)
{
	opts = opts || {};
	if(detectAlreadySwapped(workingCopyRoot))
	{
		throw new Error('Tree already swapped — re-extract from the original zip to swap to a different namespace.');
	}

	// The lock speaks before the rollback folder: while another run is going, the files in that folder are that run's
	// doing and the reader must leave them where they are.
	const lockPath = path.join(workingCopyRoot, '.namespace-swap.lock');
	if(fs.existsSync(lockPath))
	{
		const pid = fs.readFileSync(lockPath, 'utf8').trim();
		throw new Error(`Another swap is in progress (PID ${pid}). If no longer running, remove ${lockPath} and retry.`);
	}

	if(rollbackHoldsOriginals(workingCopyRoot))
	{
		const backupDirectory = path.join(workingCopyRoot, '.swap-rollback', 'working-tree-backup');
		throw new Error(`A previous swap left your original files in ${backupDirectory}: move them back first, then run the command again.`);
	}

	// Last of the four, because a swapped tree, a tree another run is working on and a tree whose files are in the
	// rollback folder all look like a folder that was never a clone, and each of those has its own answer.
	const missing = checkStartingTree(workingCopyRoot);
	if(missing.length > 0)
	{
		throw new Error(`This folder has no ${missing.join(' and no ')}. Run the command from the top folder of your clone of the KernDX `
			+ `repository, the one that holds bin, force-app and sfdx-project.template.json.`);
	}

	// A run only ever removes the lock file it wrote itself, so a run that could not write one leaves another run's
	// lock alone.
	let lockWritten = false;

	try
	{
		fs.writeFileSync(lockPath, String(process.pid));
		lockWritten = true;
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
				auditSkipped.push({path: toForwardSlashes(srcRel), reason: 'binary'});
				return;
			}
			const buf = fs.readFileSync(src);
			if(!isLikelyUtf8(buf))
			{
				fs.mkdirSync(path.dirname(dst), {recursive: true});
				fs.copyFileSync(src, dst);
				auditSkipped.push({path: toForwardSlashes(srcRel), reason: 'non-utf8'});
				return;
			}
			const result = applyContentSubstitutions(buf.toString('utf8'), rules);
			fs.mkdirSync(path.dirname(dst), {recursive: true});
			fs.writeFileSync(dst, result.text);
			if(result.replacements > 0) auditFiles.push({path: toForwardSlashes(srcRel), replacements: result.replacements});
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
						else if(/^[a-z]/.test(rule.from) && !rule.from.includes('.') && !rule.from.includes('_')
							&& !rule.from.includes('/') && !rule.from.includes("'") && !rule.from.includes('"'))
							newName = newName.split(rule.from).join(rule.to);
					}
					if(newName !== entry.name)
					{
						const newFull = path.join(dir, newName);
						fs.renameSync(full, newFull);
						auditRenames.push({from: toForwardSlashes(path.relative(stagingDir, full)), to: toForwardSlashes(path.relative(stagingDir, newFull))});
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
					// Counted the moment it moves, before the journal is written: an entry the unwind does not know
					// about is an original file nothing would bring home.
					completedRenameA.push(entry);
					fs.appendFileSync(journalPath, `renameA ${entry}\n`);
				}
			}
		}
		catch(errorA)
		{
			const originalsReturned = moveEntriesBack([...completedRenameA].reverse(), rollbackDir, workingCopyRoot);
			throw buildMoveFailure('Rename-A', errorA, {originalsReturned, everythingReturned: originalsReturned}, rollbackDir);
		}

		const completedRenameB = [];
		try
		{
			for(const entry of stagingEntries)
			{
				fs.renameSync(path.join(stagingDir, entry), path.join(workingCopyRoot, entry));
				completedRenameB.push(entry);
				fs.appendFileSync(journalPath, `renameB ${entry}\n`);
			}
		}
		catch(errorB)
		{
			// The swapped entries go back to staging first, so the originals have somewhere to land. One that will
			// not go back stays in the project, which is why it counts towards what the reader is told.
			const stagingReturned = moveEntriesBack([...completedRenameB].reverse(), workingCopyRoot, stagingDir);
			const originalsReturned = moveEntriesBack([...completedRenameA].reverse(), rollbackDir, workingCopyRoot);
			throw buildMoveFailure('Rename-B', errorB, {originalsReturned, everythingReturned: originalsReturned && stagingReturned}, rollbackDir);
		}

		// The tree is swapped from here on. A folder the swap made and cannot take away is worth a sentence, and
		// nothing more: throwing here would undo a finished swap in the reader's mind.
		let couldNotRemove = removeSwapFolder(path.join(workingCopyRoot, '.swap-staging'));
		couldNotRemove += removeSwapFolder(path.join(workingCopyRoot, '.swap-rollback'));

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
			`Swap to '${targets.camel}' complete.\nFiles touched: ${auditFiles.length}\nRenames: ${auditRenames.length}\n`
				+ `Skipped binaries: ${auditSkipped.length}\nREADME stub: ${readmeReplaced ? 'replaced' : 'kept'}\n${perRuleBlock}`);
		fs.writeFileSync(path.join(workingCopyRoot, '.namespace-swap.json'),
			JSON.stringify(
				{
					swap_target: targets.camel,
					files: auditFiles,
					renames: auditRenames,
					skipped: auditSkipped,
					per_rule_replacements: auditPerRule,
					readme_replaced: readmeReplaced
				}, null, 2) + '\n');

		return {audit: {files: auditFiles, renames: auditRenames, skipped: auditSkipped, perRule: auditPerRule, readmeReplaced}, couldNotRemove};
	}
	catch(failure)
	{
		// The staging copy is derived from the tree and always goes. The rollback folder goes only when the disk says
		// it holds nothing of the reader's, whether this run put files there or an earlier one did.
		let couldNotRemove = removeSwapFolder(path.join(workingCopyRoot, '.swap-staging'));
		if(!rollbackHoldsOriginals(workingCopyRoot))
		{
			couldNotRemove += removeSwapFolder(path.join(workingCopyRoot, '.swap-rollback'));
		}
		failure.message = buildFailureMessage(failure) + couldNotRemove;
		throw failure;
	}
	finally
	{
		if(lockWritten && fs.existsSync(lockPath)) fs.unlinkSync(lockPath);
	}
}

module.exports = {
	validateNamespace,
	detectAlreadySwapped,
	buildInventory,
	applyContentSubstitutions,
	executeSwap,
	buildReadmeStub,
	toForwardSlashes,
	checkStartingTree,
	verifySwap,
	nextStepsText
};

if(require.main === module)
{
	const args = process.argv.slice(2);
	if(args.includes('--verify'))
	{
		try
		{
			const report = verifySwap(process.cwd());
			if(!report.swapped)
			{
				console.error('This tree has not been swapped yet: there is no .namespace-origin.json here.');
				process.exit(2);
			}
			console.log(`Swapped: ${JSON.stringify(report.marker)}`);
			if(report.leftovers.length === 0)
			{
				console.log('No reference to the original namespace is left in force-app.');
				process.exit(0);
			}
			console.error(`${report.leftovers.length} reference(s) to the original namespace are left. The first ${Math.min(10, report.leftovers.length)}:`);
			report.leftovers.slice(0, 10).forEach(leftover => console.error(`  ${leftover.path}:${leftover.line}  ${leftover.text}`));
			console.error('The swap aims to handle every case, so please report these: they point to a gap in the script.');
			process.exit(1);
		}
		catch(err)
		{
			console.error(err.message);
			process.exit(2);
		}
	}
	const target = args.find(a => !a.startsWith('--'));
	const dryRun = args.includes('--dry-run');
	const keepReadme = args.includes('--keep-readme');
	if(!target) { console.error('Usage: node bin/swap-namespace.js YourNamespace [--dry-run] [--keep-readme]   or   node bin/swap-namespace.js --verify'); process.exit(1); }
	try
	{
		const result = executeSwap(process.cwd(), target, {dryRun, keepReadme});
		console.log(`Swap to '${target}' complete.`);
		if(result && result.couldNotRemove)
		{
			console.log(result.couldNotRemove.trim());
		}
		if(result && result.audit && result.audit.readmeReplaced)
		{
			console.log(`README.md replaced with subscriber stub. Pass --keep-readme to preserve your own README on a future swap.`);
		}
		if(!dryRun)
		{
			console.log(nextStepsText(target));
		}
	}
	catch(err) { console.error(err.message); process.exit(1); }
}
