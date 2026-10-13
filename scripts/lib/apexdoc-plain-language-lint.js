// SPDX-License-Identifier: BUSL-1.1
//
// The plain-language lint behind scripts/check-apexdoc-plain-language.js: finds plan vocabulary in the comments of
// Apex classes, triggers and LWC modules. A plan code (I3, D11, SAR-1, BUG-008, PLAN-182), a reference to "the spec"
// or a word that belongs to the planning record ("cell", "pinned", "projection", "resting state", "witness",
// "losing writer") is never documentation: whoever installs or maintains the package has not read the plan. Nor is
// a word of the team's own slang ("zombie", "sidecar", "latch", "knob", "hand-off") or an em-dash used as prose
// punctuation. The rule lives in docs/Code Conventions - Guide.md (section ApexDoc, "Plain language, never the plan's words").
//
// Everything that touches git, the file system or the console is injected, so the whole module is unit-tested.

'use strict';

const {execFileSync} = require('child_process');
const {readdirSync, readFileSync, statSync} = require('fs');
const path = require('path');

const CHECKED_EXTENSIONS = ['.cls', '.trigger', '.js'];
const CHECKED_PREFIX = 'force-app/';
const SKIPPED_DIRECTORIES = new Set(['staticresources', 'node_modules']);

/**
 * The patterns a comment or an assertion message may not carry. Each entry names what it catches, for the report
 * line. Codes are matched with their case; words are matched whole and without regard to case. "cell" and "pin" are
 * read in Apex only: in a component they are the words of a table or of the Log Console's pinned filters. An em-dash
 * is a hit in a comment, an assertion message or a Jest case name; a string literal on any other code line is data and
 * is never read.
 */
const PLAN_LANGUAGE = [
	{name: 'plan code', pattern: /\b(?:I|D)\d{1,2}\b(?!\.js)/g, apexOnly: false},
	{name: 'plan code', pattern: /\b(?:SAR|BUG|PLAN)-\d+\b/g, apexOnly: false},
	{name: 'spec reference', pattern: /\bspec(?:ification)?(?:['’]s)?\b/gi, apexOnly: false},
	{name: 'plan word', pattern: /\bcells?\b/gi, apexOnly: true},
	{name: 'plan word', pattern: /\bpin(?:s|ned)?\b/gi, apexOnly: true},
	{name: 'plan word', pattern: /\bprojections?\b/gi, apexOnly: false},
	{name: 'plan word', pattern: /\bresting state\b/gi, apexOnly: false},
	{name: 'plan word', pattern: /\bwitness(?:es)?\b/gi, apexOnly: false},
	{name: 'plan word', pattern: /\blosing writer\b/gi, apexOnly: false},
	{name: 'plan word', pattern: /\bseams?\b/gi, apexOnly: false},
	{name: 'plan word', pattern: /\bstraddl(?:e|es|ed|ing)\b/gi, apexOnly: false},
	{name: 'abbreviation', pattern: /\bUOW\b/g, apexOnly: false},
	{name: 'jargon word', pattern: /\bzombies?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bsidecars?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bfixpoints?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bbrick(?:s|ed|ing)?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\blatch(?:es|ed|ing)?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bknobs?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\begress\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bplumbing\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bpostures?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bclobber(?:s|ed|ing)?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bre-?arm(?:s|ed|ing)?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\brule universe\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\b[Tt]ier[- ]A\b/g, apexOnly: false},
	{name: 'jargon word', pattern: /\bhand-?offs?\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bunkeyed\b/gi, apexOnly: false},
	{name: 'em-dash in prose; use a full stop, a comma or a colon', pattern: /—/g, apexOnly: false}
];

/**
 * A line whose string literals are documentation too: an assertion's message, or a Jest case's name.
 */
const ASSERTION_LINE = /\bAssert\.|\bSystem\.assert|\b(?:it|describe|test)\(/;
const STRING_LITERAL = /'((?:\\.|[^'\\])*)'|"((?:\\.|[^"\\])*)"|`((?:\\.|[^`\\])*)`/g;

/**
 * A diff hunk header: the first line of the new file's part of the hunk, and how many lines it has (one when absent).
 */
const HUNK_HEADER = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/;

/**
 * Returns the text of every string literal on each assertion or Jest-case line, with its one-based line number.
 * Lines that are comments are left to commentLines.
 */
function assertionLiterals(source)
{
	const literals = [];
	const lines = source.split(/\r?\n/);
	for(let index = 0; index < lines.length; index++)
	{
		const trimmed = lines[index].trim();
		if(trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/*') || !ASSERTION_LINE.test(trimmed))
		{
			continue;
		}
		STRING_LITERAL.lastIndex = 0;
		let match = STRING_LITERAL.exec(trimmed);
		while(match !== null)
		{
			literals.push({line: index + 1, text: match[1] ?? match[2] ?? match[3]});
			match = STRING_LITERAL.exec(trimmed);
		}
	}
	return literals;
}

/**
 * Returns the comment text of each line of a source file, with its one-based line number. Block comments
 * (slash-star to star-slash) and lines that start with two slashes are comments; code is never returned. Two
 * slashes after code on the same line are not a comment, so a URL inside a string literal is never read.
 */
function commentLines(source)
{
	const lines = source.split(/\r?\n/);
	const comments = [];
	let insideBlock = false;
	for(let index = 0; index < lines.length; index++)
	{
		const trimmed = lines[index].trim();
		if(insideBlock)
		{
			const end = trimmed.indexOf('*/');
			comments.push({line: index + 1, text: end >= 0 ? trimmed.slice(0, end) : trimmed});
			insideBlock = end < 0;
			continue;
		}
		if(trimmed.startsWith('/*'))
		{
			const end = trimmed.indexOf('*/', 2);
			comments.push({line: index + 1, text: end >= 0 ? trimmed.slice(2, end) : trimmed.slice(2)});
			insideBlock = end < 0;
			continue;
		}
		if(trimmed.startsWith('//'))
		{
			comments.push({line: index + 1, text: trimmed.slice(2)});
		}
	}
	return comments;
}

/**
 * Returns every plan-vocabulary hit in the comments and the assertion messages of a source file: the line, the
 * matched token, what kind of token it is, where it sits (a comment or an assertion) and the text it sits in with
 * its leading stars removed. `isApex` is true for a class or trigger, false for a component module.
 */
function findPlanLanguage(source, isApex = true)
{
	const hits = [];
	const places = [
		...commentLines(source).map((comment) => ({...comment, where: 'comment'})),
		...assertionLiterals(source).map((literal) => ({...literal, where: 'assertion'}))
	];
	for(const place of places)
	{
		for(const {name, pattern, apexOnly} of PLAN_LANGUAGE)
		{
			if(apexOnly && !isApex)
			{
				continue;
			}
			pattern.lastIndex = 0;
			let match = pattern.exec(place.text);
			while(match !== null)
			{
				hits.push({line: place.line, token: match[0], kind: name, where: place.where, text: place.text.replace(/^\*+\s?/, '').trim()});
				match = pattern.exec(place.text);
			}
		}
	}
	return hits.sort((first, second) => first.line - second.line);
}

/**
 * True for a repository-relative path the lint reads: a class, trigger or module under force-app.
 */
function isChecked(file)
{
	return file.startsWith(CHECKED_PREFIX) && CHECKED_EXTENSIONS.includes(path.extname(file));
}

/**
 * The numbers of the lines a diff with no context lines adds or changes, read from its hunk headers
 * ("@@ -10,2 +12,3 @@" means lines 12, 13 and 14 of the new file). A hunk that only deletes ("+12,0") adds nothing.
 */
function changedLineNumbers(diffText)
{
	const numbers = new Set();
	for(const line of diffText.split('\n'))
	{
		const match = HUNK_HEADER.exec(line);
		if(match === null)
		{
			continue;
		}
		const start = Number(match[1]);
		const count = match[2] === undefined ? 1 : Number(match[2]);
		for(let offset = 0; offset < count; offset++)
		{
			numbers.add(start + offset);
		}
	}
	return numbers;
}

/**
 * The checked files git reports as added, copied or modified against a reference, plus the untracked ones, each with
 * the lines to read. For a tracked file that is the set of lines added or changed since the reference, staged or not;
 * for an untracked file it is null, which means every line. A file renamed since the reference is listed under its new
 * name as an added file, so every line of it is read. Git's own diff is used even when an external diff tool is set,
 * because the line numbers are read from its output. `runGit(arguments)` returns git's standard output; the real one
 * is injected by the script.
 */
function modifiedFiles(baseReference, runGit)
{
	const changed = new Set(runGit(['diff', '--name-only', '--no-renames', '--diff-filter=ACM', baseReference]).split('\n').filter(isChecked));
	const untracked = new Set(runGit(['ls-files', '--others', '--exclude-standard']).split('\n').filter((file) => isChecked(file) && !changed.has(file)));
	return [
		...[...changed].map((file) => ({file, lines: changedLineNumbers(runGit(['diff', '-U0', '--no-color', '--no-ext-diff', baseReference, '--', file]))})),
		...[...untracked].map((file) => ({file, lines: null}))
	];
}

/**
 * Every checked file under a directory, as repository-relative paths with forward slashes; static resources and
 * node_modules are skipped. `fileSystem` carries readdirSync and statSync so a test can point it at a temporary tree.
 */
function allFiles(directory, repositoryRoot, fileSystem)
{
	const files = [];
	for(const entry of fileSystem.readdirSync(directory))
	{
		if(SKIPPED_DIRECTORIES.has(entry))
		{
			continue;
		}
		const absolute = path.join(directory, entry);
		if(fileSystem.statSync(absolute).isDirectory())
		{
			files.push(...allFiles(absolute, repositoryRoot, fileSystem));
			continue;
		}
		const relative = path.relative(repositoryRoot, absolute).split(path.sep).join('/');
		if(isChecked(relative))
		{
			files.push(relative);
		}
	}
	return files;
}

/**
 * Runs the lint for a command line and returns the exit code: 1 when any checked comment carries plan vocabulary,
 * 0 otherwise. With --all every line of every file is read. Without it, only the lines added or changed since the
 * base reference are read (every line of an untracked file), and one line says how many hits on unchanged lines were
 * left out. `io` carries listModified(baseReference), which returns {file, lines} entries, listAll(),
 * readFile(relativePath), log(text) and error(text).
 */
function run(argumentList, io)
{
	const everything = argumentList.includes('--all');
	const baseIndex = argumentList.indexOf('--base');
	const baseReference = baseIndex >= 0 ? argumentList[baseIndex + 1] : 'HEAD';
	const entries = everything ? io.listAll().map((file) => ({file, lines: null})) : io.listModified(baseReference);
	const scope = everything ? 'every force-app class, trigger and module' : `the changed lines of the files modified against ${baseReference}`;

	const report = [];
	let leftOut = 0;
	for(const {file, lines} of entries)
	{
		const isApex = path.extname(file) !== '.js';
		for(const hit of findPlanLanguage(io.readFile(file), isApex))
		{
			if(lines !== null && !lines.has(hit.line))
			{
				leftOut++;
				continue;
			}
			report.push(`${file}:${hit.line}: ${hit.kind} "${hit.token}" in ${hit.where} :: ${hit.text}`);
		}
	}
	if(!everything)
	{
		const state = leftOut > 0 ? 'the tree is not clean yet (--all lists them)' : 'the unchanged lines are clean';
		io.log(`Left out ${leftOut} hit(s) already on unchanged lines of the modified files; ${state}.`);
	}
	if(report.length > 0)
	{
		io.error(`Plan vocabulary, team slang or an em-dash in ${report.length} comment line(s) of ${scope}; say it in plain words `
			+ `(docs/Code Conventions - Guide.md, section ApexDoc):\n  ${report.join('\n  ')}`);
		return 1;
	}
	io.log(`No plan vocabulary, team slang or em-dash in the comments of ${scope} (${entries.length} file(s) read).`);
	return 0;
}

/**
 * The real inputs for a repository root: git through execFileSync, the file system through fs, the console for output.
 */
function repositoryInputs(repositoryRoot)
{
	const runGit = (argumentList) => execFileSync('git', argumentList, {cwd: repositoryRoot, encoding: 'utf8'});
	return {
		listModified: (baseReference) => modifiedFiles(baseReference, runGit),
		listAll: () => allFiles(path.join(repositoryRoot, CHECKED_PREFIX), repositoryRoot, {readdirSync, statSync}),
		readFile: (file) => readFileSync(path.join(repositoryRoot, file), 'utf8'),
		log: (text) => console.log(text),
		error: (text) => console.error(text)
	};
}

module.exports = {CHECKED_PREFIX, PLAN_LANGUAGE, allFiles, assertionLiterals, commentLines, findPlanLanguage, isChecked, modifiedFiles, repositoryInputs, run};
