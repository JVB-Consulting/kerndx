// SPDX-License-Identifier: Apache-2.0
//
// The plain-language lint behind scripts/check-apexdoc-plain-language.js: finds plan vocabulary in the comments of
// Apex classes, triggers and LWC modules, and in the text the package ships in its metadata files (label values,
// field descriptions and help text, and the descriptions of custom metadata records). A plan code (I3, D11, SAR-1,
// BUG-008, PLAN-182), a reference to "the spec" or a word that belongs to the planning record ("cell", "pinned",
// "projection", "resting state", "witness", "losing writer") is never documentation: whoever installs or maintains
// the package has not read the plan. Nor is
// a word of the team's own slang ("zombie", "sidecar", "latch", "knob", "hand-off") or an em-dash used as prose
// punctuation. The rule lives in docs/Code Conventions - Guide.md (section ApexDoc, "Plain language, never the plan's words").
//
// Everything that touches git, the file system or the console is injected, so the whole module is unit-tested.

'use strict';

const {execFileSync} = require('child_process');
const {readdirSync, readFileSync, statSync} = require('fs');
const path = require('path');

const CHECKED_EXTENSIONS = ['.cls', '.trigger', '.js', '.xml'];
const METADATA_EXTENSION = '.xml';
const CHECKED_PREFIX = 'force-app/';
const SKIPPED_DIRECTORIES = new Set(['staticresources', 'node_modules']);

const EM_DASH_KIND = 'em-dash in prose; use a full stop, a comma or a colon';

/**
 * The patterns a comment, an assertion message or the text of a metadata file may not carry. Each entry names what it
 * catches, for the report line. Codes are matched with their case; words are matched whole and without regard to case.
 * "cell" and "pin" are read in Apex only: in a component or a metadata file they are the words of a table or of the Log
 * Console's pinned filters. An em-dash is a hit in a comment, an assertion message or a Jest case name; a string
 * literal on any other code line is data and is never read. "Kill switch" is the released name of a feature, so it is
 * allowed in the label and the master label of a metadata file (skipInMetadataNames) and reported everywhere else.
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
	{name: 'jargon word', pattern: /\bline of jobs\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\b(?:is not|must be) one name\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bone field path\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bnames? that start with two underscores\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bloud failure signal\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bquery interception\b/gi, apexOnly: false},
	{name: 'jargon word', pattern: /\bkill[- ]switch(?:es)?\b/gi, apexOnly: false, skipInMetadataNames: true},
	{name: EM_DASH_KIND, pattern: /—/g, apexOnly: false}
];

/**
 * An HTML tag in a comment: one of the listed tag names, opening, closing or self-closing, in any case, with or without
 * attributes. ApexDoc is plain text. Only these names count, so a generic type (List, Set, Map, Iterable, Iterator,
 * Batchable, Comparator) such as List<String>, Set<Em> or Map<Id, Account> and the words "a < b" are never a hit.
 * Text inside backticks and lines inside a code fence are not read for it.
 */
const HTML_TAG = {
	name: 'HTML tag; ApexDoc is plain text: a blank * line between paragraphs, "- " for a list item, backticks for code',
	pattern: /<\/?(?:p|br|ul|ol|li|b|i|em|strong|code|pre|a|div|span)(?:\s+[\w-]+=(?:"[^"]*"|'[^']*'|[^<>\s"']*))*\s*\/?>/gi
};

/**
 * The end of the text before a match when a generic type name sits right there, so the match is a type argument.
 * Case-sensitive: the lower-case word "list" before a tag is prose.
 */
const GENERIC_TYPE_BEFORE = /\b(?:List|Set|Map|Iterable|Iterator|Batchable|Comparator)\s*$/;
const CODE_FENCE = /^```/;
const BACKTICK_SPAN = /`[^`]*`/g;

/**
 * A line whose string literals are documentation too: an assertion's message, or a Jest case's name.
 */
const ASSERTION_LINE = /\bAssert\.|\bSystem\.assert|\b(?:it|describe|test)\(/;
const STRING_LITERAL = /'((?:\\.|[^'\\])*)'|"((?:\\.|[^"\\])*)"|`((?:\\.|[^`\\])*)`/g;

/**
 * The elements of a metadata file whose text the package ships to the people who use it, in any metadata file.
 * The opening tag may carry attributes; a tag that closes itself holds no text and is never matched.
 */
const SHIPPED_TEXT_ELEMENT = /<(description|inlineHelpText|label|shortDescription|masterLabel)(?:\s[^>]*?)?(?<!\/)>([\s\S]*?)<\/\1>/g;

/**
 * The elements that hold the name of a thing: its label and its master label.
 */
const NAME_ELEMENTS = new Set(['label', 'masterLabel']);

/**
 * The value of a custom label, read only in a labels file.
 */
const LABEL_VALUE = /<(value)(?:\s[^>]*?)?(?<!\/)>([\s\S]*?)<\/\1>/g;
const LABELS_FILE_SUFFIX = '.labels-meta.xml';

/**
 * The value of a custom metadata record's Description__c field, read only in a record file. The value must follow the
 * field name directly, so an empty value that closes itself never reaches the value of the next field.
 */
const RECORD_DESCRIPTION_VALUE = /<field>Description__c<\/field>\s*<(value)(?:\s[^>]*?)?(?<!\/)>([\s\S]*?)<\/\1>/g;
const RECORD_FILE_SUFFIX = '.md-meta.xml';

/**
 * The headings of the report, in the order they print, and the kinds of hit each one gathers.
 */
const REPORT_HEADINGS = [
	{heading: 'Plan vocabulary', kinds: ['plan code', 'spec reference', 'plan word']},
	{heading: 'Team slang', kinds: ['jargon word']},
	{heading: 'Abbreviation', kinds: ['abbreviation']},
	{heading: 'Em-dash', kinds: [EM_DASH_KIND]},
	{heading: 'HTML tag', kinds: [HTML_TAG.name]}
];

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
 * Returns every HTML tag in the comment lines of a class or trigger, as hits in the shape findPlanLanguage reports.
 * A line that starts with three backticks opens or closes a code fence, and the lines inside a fence are not read.
 * A fence never runs past a code line: a gap in the comment line numbers closes it. Text inside backticks is not read.
 */
function findHtmlTags(comments)
{
	const hits = [];
	let insideFence = false;
	let previousLine = 0;
	for(const comment of comments)
	{
		insideFence = insideFence && comment.line === previousLine + 1;
		previousLine = comment.line;
		const text = comment.text.replace(/^\*+\s?/, '').trim();
		if(CODE_FENCE.test(text))
		{
			insideFence = !insideFence;
			continue;
		}
		if(insideFence)
		{
			continue;
		}
		const prose = text.replace(BACKTICK_SPAN, '');
		HTML_TAG.pattern.lastIndex = 0;
		let match = HTML_TAG.pattern.exec(prose);
		while(match !== null)
		{
			if(!GENERIC_TYPE_BEFORE.test(prose.slice(0, match.index)))
			{
				hits.push({line: comment.line, token: match[0], kind: HTML_TAG.name, where: 'comment', text});
			}
			match = HTML_TAG.pattern.exec(prose);
		}
	}
	return hits;
}

/**
 * Returns every plan-vocabulary hit in the comments and the assertion messages of a source file: the line, the
 * matched token, what kind of token it is, where it sits (a comment or an assertion) and the text it sits in with
 * its leading stars removed. `isApex` is true for a class or trigger, false for a component module. In a class or
 * trigger an HTML tag in a comment is a hit too.
 */
function findPlanLanguage(source, isApex = true)
{
	const places = [
		...commentLines(source).map((comment) => ({...comment, where: 'comment'})),
		...assertionLiterals(source).map((literal) => ({...literal, where: 'assertion'}))
	];
	return findInPlaces(places, isApex, isApex ? findHtmlTags(commentLines(source)) : []);
}

/**
 * Replaces the XML entities a metadata file may carry with the characters they stand for, so an em-dash written as
 * &#8212; is read as an em-dash. The ampersand is decoded last, so "&amp;lt;" becomes "&lt;" and goes no further.
 */
function decodeEntities(text)
{
	return text.replace(/&#8212;|&#x2014;|&mdash;/gi, '—').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, '\'')
		.replace(/&amp;/g, '&');
}

/**
 * Returns the text a metadata file ships, one entry per line with its one-based line number: the content of every
 * description, help text, label, short description and master label element, the value of a custom label in a labels
 * file, and the value of the Description__c field in a custom metadata record file. Element names and attributes are
 * never returned, and a text that spans several lines gives one entry for each of its lines.
 */
function metadataTextLines(source, file)
{
	const patterns = [SHIPPED_TEXT_ELEMENT];
	if(file.endsWith(LABELS_FILE_SUFFIX))
	{
		patterns.push(LABEL_VALUE);
	}
	if(file.endsWith(RECORD_FILE_SUFFIX))
	{
		patterns.push(RECORD_DESCRIPTION_VALUE);
	}
	const texts = [];
	for(const pattern of patterns)
	{
		pattern.lastIndex = 0;
		let match = pattern.exec(source);
		while(match !== null)
		{
			const contentStart = match.index + match[0].length - match[2].length - `</${match[1]}>`.length;
			const firstLine = source.slice(0, contentStart).split('\n').length;
			const element = match[1];
			const textLines = match[2].split('\n');
			for(let offset = 0; offset < textLines.length; offset++)
			{
				texts.push({line: firstLine + offset, text: decodeEntities(textLines[offset].replace(/\r$/, '')), element});
			}
			match = pattern.exec(source);
		}
	}
	return texts;
}

/**
 * Returns every plan-vocabulary hit in the text a metadata file ships, in the shape findPlanLanguage reports, with
 * "metadata text" as the place. The text is read as a component's comments are: the words that only Apex may not
 * carry are allowed, and HTML tags are not looked for.
 */
function findPlanLanguageInMetadata(source, file)
{
	return findInPlaces(metadataTextLines(source, file).map((text) => ({...text, where: 'metadata text'})), false, []);
}

/**
 * Adds to `hits` every plan-vocabulary hit in the given places ({line, text, where}) and returns them sorted by line.
 * The words that only Apex may not carry are skipped when `isApex` is false.
 */
function findInPlaces(places, isApex, hits)
{
	for(const place of places)
	{
		for(const {name, pattern, apexOnly, skipInMetadataNames} of PLAN_LANGUAGE)
		{
			if((apexOnly && !isApex) || (skipInMetadataNames && NAME_ELEMENTS.has(place.element)))
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
 * True for a repository-relative path the lint reads: a class, trigger, module or metadata file under force-app.
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
 * Runs the lint for a command line and returns the exit code: 1 when any checked comment or metadata text carries plan vocabulary,
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
	const scope = everything ? 'every force-app class, trigger, module and metadata file' : `the changed lines of the files modified against ${baseReference}`;

	const report = [];
	let leftOut = 0;
	for(const {file, lines} of entries)
	{
		const extension = path.extname(file);
		const source = io.readFile(file);
		const hits = extension === METADATA_EXTENSION ? findPlanLanguageInMetadata(source, file) : findPlanLanguage(source, extension !== '.js');
		for(const hit of hits)
		{
			if(lines !== null && !lines.has(hit.line))
			{
				leftOut++;
				continue;
			}
			report.push({kind: hit.kind, text: `${file}:${hit.line}: ${hit.kind} "${hit.token}" in ${hit.where} :: ${hit.text}`});
		}
	}
	if(!everything)
	{
		const state = leftOut > 0 ? 'the tree is not clean yet (--all lists them)' : 'the unchanged lines are clean';
		io.log(`Left out ${leftOut} hit(s) already on unchanged lines of the modified files; ${state}.`);
	}
	if(report.length > 0)
	{
		io.error(`Plan vocabulary, team slang, an abbreviation, an em-dash or an HTML tag: ${report.length} hit(s) in the comments and metadata text of ${scope}; `
			+ `say it in plain words (docs/Code Conventions - Guide.md, section ApexDoc):${reportSections(report)}`);
		return 1;
	}
	io.log(`No plan vocabulary, team slang, abbreviation, em-dash or HTML tag in the comments and metadata text of ${scope} (${entries.length} file(s) read).`);
	return 0;
}

/**
 * The report's body: one heading for each kind of hit found, in the order of REPORT_HEADINGS, each naming its own
 * count and followed by its own lines. A kind with no hit prints no heading.
 */
function reportSections(report)
{
	let sections = '';
	for(const {heading, kinds} of REPORT_HEADINGS)
	{
		const lines = report.filter((entry) => kinds.includes(entry.kind)).map((entry) => entry.text);
		if(lines.length > 0)
		{
			sections += `\n${heading}: ${lines.length} hit(s)\n  ${lines.join('\n  ')}`;
		}
	}
	return sections;
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

module.exports = {
	CHECKED_PREFIX, PLAN_LANGUAGE, allFiles, assertionLiterals, commentLines, findPlanLanguage, findPlanLanguageInMetadata, isChecked, modifiedFiles,
	repositoryInputs, run
};
