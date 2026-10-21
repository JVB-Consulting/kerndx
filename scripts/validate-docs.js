#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Documentation Validation Script
 *
 * Validates developer and strategic guide Markdown files against framework
 * conventions, checking for broken links, anti-patterns in code examples,
 * old naming conventions, missing sharing declarations, TOC consistency,
 * code fence language tags, and class reference validity.
 *
 * @author Kern Framework
 * @version 1.0.0
 *
 * @example
 * ```bash
 * npm run docs:validate
 * ```
 */

const fs = require('fs');
const path = require('path');
const {execSync, spawnSync} = require('child_process');
const os = require('os');

// ─────────────────────────────────────────────────────────────────────────────
// Constants & Configuration
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description The guide file names the distribution manifest's blacklist keeps under `docs/`: the guides that never
 *              ship. Read when the manifest is present; a published clone has no manifest and gets an empty list.
 * @param {string} manifestPath - The manifest's path.
 * @returns {string[]} File names relative to `docs/`, in manifest order.
 */
function internalDocsFrom(manifestPath)
{
	if(!fs.existsSync(manifestPath))
	{
		return [];
	}
	const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
	return (manifest.blacklist_assertions || [])
		.filter(entry => /^docs\/[^/*]+\.md$/.test(entry))
		.map(entry => entry.slice('docs/'.length));
}

const DEFAULT_CONFIG = {
	/** Directory containing guide docs */
	docsDir: './docs',

	/** Directory containing Apex class files */
	classesDir: './force-app/main/default/classes',

	/** Directory containing reference docs */
	referenceDir: './docs/reference/apex',

	/** File patterns to include */
	includePattern: /- Guide\.md$|^Strategic Guide - |AI Agent Instructions\.md$|Installation\.md$|Start Here\.md$|README\.md$|Glossary\.md$|Personas\.md$|^Fast Start/,

	/**
	 * Guides that never reach a subscriber, so the shipped-document checks skip them: the guides the distribution
	 * manifest's blacklist keeps under `docs/` because they name and score competitors. The manifest never ships, so
	 * a published clone skips nothing, which is right: those guides are not there either. Every other
	 * `Strategic Guide - *.md` ships and is scanned here.
	 */
	internalDocs: internalDocsFrom(path.join(__dirname, '..', 'distribution', 'public-mirror-manifest.json')),

	/** File patterns to exclude */
	excludePattern: /^$/,

	/** Files to exclude from --fix-toc (special structure) */
	fixTocExcludePattern: null,

	/** Additional files outside docsDir to validate */
	extraFiles: ['./README.md'],

	/** Additional directories to scan (all .md files included) */
	extraDirs: [
		'./research',
		'./standards',
		'./release-notes'
	]
};

/** Standard Salesforce types that should not be flagged as missing classes */
const SF_STANDARD_TYPES = new Set([
	'System',
	'Database',
	'Schema',
	'Test',
	'Math',
	'Limits',
	'UserInfo',
	'JSON',
	'String',
	'Integer',
	'Boolean',
	'Decimal',
	'Double',
	'Long',
	'Date',
	'Datetime',
	'Time',
	'Blob',
	'Id',
	'Object',
	'Type',
	'Enum',
	'List',
	'Set',
	'Map',
	'SObject',
	'Account',
	'Contact',
	'Case',
	'Lead',
	'Opportunity',
	'Task',
	'Event',
	'User',
	'Profile',
	'PermissionSet',
	'ContentVersion',
	'ContentDocument',
	'Attachment',
	'EmailMessage',
	'HttpRequest',
	'HttpResponse',
	'Http',
	'RestRequest',
	'RestResponse',
	'RestContext',
	'Messaging',
	'Approval',
	'Auth',
	'ConnectApi',
	'ApexPages',
	'PageReference',
	'SelectOption',
	'Savepoint',
	'TriggerOperation',
	'FlowDefinition',
	'EntityDefinition',
	'FieldDefinition',
	'DescribeSObjectResult',
	'DescribeFieldResult',
	'SObjectField',
	'SObjectType',
	'FieldSet',
	'FieldSetMember',
	'AggregateResult',
	'QueryLocator',
	'BatchableContext',
	'SchedulableContext',
	'QueueableContext',
	'FinalizerContext',
	'Assert',
	'Exception',
	'DmlException',
	'QueryException',
	'NullPointerException',
	'IllegalArgumentException',
	'TypeException',
	'MathException',
	'CalloutException',
	'AsyncException',
	'LimitException',
	'Callable',
	'Schedulable',
	'Queueable',
	'Batchable',
	'Finalizer',
	'Comparable',
	'Iterable',
	'Iterator',
	'StubProvider',
	'InstallHandler',
	'UninstallHandler',
	'Cache',
	'OrgCachePartition',
	'SessionCachePartition',
	'Trigger',
	'Process',
	'Flow',
	'Metadata',
	'FeatureManagement',
	'Network',
	'Site',
	'Community',
	'EventBus',
	'Platform',
	'Quiddity',
	'Request',
	'CustomMetadataType',
	'PlatformEvent',
	'InvocableMethod',
	'InvocableVariable',
	'AuraEnabled',
	'IsTest',
	'TestVisible',
	'SuppressWarnings',
	'JsonAccess',
	'RestResource',
	'HttpGet',
	'HttpPost',
	'HttpPut',
	'HttpPatch',
	'HttpDelete',
	'NamespaceAccessible',
	'RemoteAction',
	'Crypto',
	'EncodingUtil',
	'Url',
	'Pattern',
	'Matcher',
	'AsyncOperation',
	'FlexQueue',
	'OrgLimits',
	'AccessLevel',
	'SecurityEnforced',
	'StripInaccessible',
	'ApplicationReadWriteMode',
	'StatusCode',
	'CTRL',
	'LWC'
]);

/** Kern framework prefixes that should exist in the codebase */
const KERN_PREFIXES = new Set([
	'API_',
	'BATCH_',
	'DML_',
	'DTO_',
	'FLOW_',
	'IF_',
	'LOG_',
	'MAP_',
	'QRY_',
	'REST_',
	'SCHED_',
	'SEL_',
	'SVC_',
	'TRG_',
	'TST_',
	'UTIL_'
]);

/**
 * `kern.`-qualified references that are intentionally unresolvable.
 *
 * File-scoped, so the same identifier still errors anywhere else. Add ONLY with a one-line
 * justification — an entry here is a claim that the reference is deliberately not callable.
 */
const KERN_CLASS_REF_EXCEPTIONS = [
	// Deliberate "// WRONG" counter-example: prefixing your OWN subscriber class.
	{file: 'docs/AI Agent Instructions.md', ref: 'API_CreateOrder'},
	// Quoted runtime error string ("Invalid type: kern.SEL_Accounts") in the callout that
	// explains why the prefix rule exists.
	{file: 'docs/Fast Start - Selectors.md', ref: 'SEL_Accounts'},
	// Bypass-KEY string for the framework's internal flow runner, not a callable type.
	// TRG_InvokeFlow is `public` (no reference page) by design.
	{file: 'docs/Triggers - Guide.md', ref: 'TRG_InvokeFlow'}
];

/**
 * `Class.member` references that are intentionally unreachable.
 *
 * File-scoped like the class list, so the same reference still errors anywhere else. Every entry
 * carries a written `reason` — an entry here is a claim that the doc deliberately names something
 * a subscriber cannot compile, which needs a stated justification, not a silent suppression.
 */
const KERN_MEMBER_REF_EXCEPTIONS = [
	{
		file: 'release-notes/Release Notes - Kern 1.0.md',
		ref: 'API_Base.enterSafeMode',
		reason: 'Historical release note: describes the API surface as it stood at that release; frozen at publication, never edited retroactively.'
	},
	{
		file: 'release-notes/Release Notes - Kern 1.0.md',
		ref: 'UTIL_String.isValidCardNumber',
		reason: 'Historical release note: describes the API surface as it stood at that release; frozen at publication, never edited retroactively.'
	}
];

/**
 * Member tokens that are really file extensions (`DML_Builder.md`, `SCHED_PurgeRecords.class`).
 * Naming a file is not a claim that the name compiles, so those matches never resolve.
 */
const FILE_NAME_MEMBER_TOKENS = new Set(['md', 'cls', 'trigger', 'class', 'js']);

/**
 * `Class.member` and `Outer.Inner.member` tokens. Group 1 is the type, optionally carrying one
 * inner-type segment; group 2 is the member. A trailing `*` is allowed so a wildcard roster is
 * seen and reported rather than silently skipped.
 */
const MEMBER_REF_PATTERN = /(?:\bkern\.)?\b([A-Z]{2,}[A-Z0-9]*_[A-Za-z]\w*(?:\.[A-Z]\w*)?)\.([A-Za-z_][\w*]*)\b/g;

// Copied from scripts/lib/boundary-gate-lint.js rather than required from it: that module pulls
// in the agent-eval scorer, and this validator has to run in a checkout that carries the docs and
// scripts alone. Keep the three patterns in step with their source.
const GLOBAL_TYPE_PATTERN = /^\s*(?:@\w+(?:\([^)]*\))?\s+)*global\s+(?:(?:virtual|abstract|with sharing|without sharing|inherited sharing)\s+)*(class|interface|enum)\s+(\w+)/i;
const GLOBAL_MEMBER_PATTERN =
	/^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:global|webservice)\s+(?:(?:static|virtual|abstract|override|final|transient|protected)\s+)*[\w.<>,\s\[\]]+?\s(\w+)\s*[({=;]/i;
const GLOBAL_CONSTRUCTOR_PATTERN = /^\s*(?:@\w+(?:\([^)]*\))?\s+)*global\s+(\w+)\s*\(/i;

/** Any top-level or inner type declaration, whatever its visibility. */
const TYPE_DECLARATION_PATTERN = /^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:global|public|private|protected)\s+[\w\s]*\b(?:class|interface|enum)\s+\w+/i;

// ─────────────────────────────────────────────────────────────────────────────
// Logging
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Creates a logger with coloured output
 * @param {boolean} [silent=false] - If true, suppress output
 * @returns {Object} Logger object
 */
function createLogger(silent = false)
{
	const noop = () =>
	{
	};
	if(silent)
	{
		return {info: noop, success: noop, warn: noop, error: noop, file: noop, issue: noop};
	}
	return {
		info: (msg) => console.log(`\x1b[36m[validate]\x1b[0m ${msg}`),
		success: (msg) => console.log(`\x1b[32m[validate]\x1b[0m ${msg}`),
		warn: (msg) => console.log(`\x1b[33m[validate]\x1b[0m ${msg}`),
		error: (msg) => console.error(`\x1b[31m[validate]\x1b[0m ${msg}`),
		file: (msg) => console.log(`\n\x1b[1m${msg}\x1b[0m`),
		issue: (line, severity, check, message) =>
		{
			const color = severity === 'error' ? '\x1b[31m' : '\x1b[33m';
			const lineStr = `L${line}`.padEnd(6);
			const sevStr = severity.padEnd(8);
			console.log(`  ${lineStr} ${color}${sevStr}\x1b[0m [${check}]  ${message}`);
		}
	};
}

// ─────────────────────────────────────────────────────────────────────────────
// Markdown Parsers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Parses code blocks from Markdown content.
 *
 * Both the opening and the closing fence marker tolerate leading whitespace, so fences nested
 * under list items are parsed like column-0 fences (un-anchoring only the opener would leave a
 * block permanently open and blind every downstream check). This is deliberately NOT a full
 * CommonMark fence parser — leading-whitespace tolerance on backtick fences is the whole scope.
 *
 * @param {string} content - Markdown content
 * @returns {Array<{lang: string, code: string, startLine: number, endLine: number}>}
 */
function parseCodeBlocks(content)
{
	const blocks = [];
	const lines = content.split('\n');
	let inBlock = false;
	let currentBlock = null;

	for(let i = 0; i < lines.length; i++)
	{
		const line = lines[i];
		const lineNum = i + 1;

		if(!inBlock && /^[ \t]*```(\w*)/.test(line))
		{
			const lang = line.match(/^[ \t]*```(\w*)/)[1] || '';
			currentBlock = {lang, code: '', startLine: lineNum, endLine: lineNum};
			inBlock = true;
		}
		else if(inBlock && /^[ \t]*```\s*$/.test(line))
		{
			currentBlock.endLine = lineNum;
			blocks.push(currentBlock);
			currentBlock = null;
			inBlock = false;
		}
		else if(inBlock)
		{
			currentBlock.code += (currentBlock.code ? '\n' : '') + line;
		}
	}

	return blocks;
}

/**
 * Parses headings from Markdown content (skips headings inside code blocks)
 * @param {string} content - Markdown content
 * @returns {Array<{level: number, text: string, line: number}>}
 */
function parseHeadings(content)
{
	const headings = [];
	const lines = content.split('\n');
	let inCodeBlock = false;

	for(let i = 0; i < lines.length; i++)
	{
		const line = lines[i];
		const lineNum = i + 1;

		if(/^```/.test(line))
		{
			inCodeBlock = !inCodeBlock;
			continue;
		}

		if(!inCodeBlock && /^#{1,6}\s+/.test(line))
		{
			const match = line.match(/^(#{1,6})\s+(.*)/);
			if(match)
			{
				headings.push({
					level: match[1].length, text: match[2].trim(), line: lineNum
				});
			}
		}
	}

	return headings;
}

/**
 * Parses TOC entries from Markdown content
 * @param {string} content - Markdown content
 * @returns {Array<{text: string, anchor: string, line: number}>}
 */
function parseTocEntries(content)
{
	const entries = [];
	const lines = content.split('\n');
	let inToc = false;
	let inCodeBlock = false;

	for(let i = 0; i < lines.length; i++)
	{
		const line = lines[i];
		const lineNum = i + 1;

		if(/^```/.test(line))
		{
			inCodeBlock = !inCodeBlock;
			continue;
		}

		if(inCodeBlock)
		{
			continue;
		}

		if(/^##\s+Table of Contents/i.test(line))
		{
			inToc = true;
			continue;
		}

		if(inToc)
		{
			if(/^---/.test(line) || (/^##\s+/.test(line) && !/^##\s+Table of Contents/i.test(line)))
			{
				break;
			}

			const linkMatch = line.match(/\[([^\]]+)\]\(#([^)]+)\)/);
			if(linkMatch)
			{
				entries.push({
					text: linkMatch[1], anchor: linkMatch[2], line: lineNum
				});
			}
		}
	}

	return entries;
}

/**
 * Parses all Markdown links from content (excludes code blocks)
 * @param {string} content - Markdown content
 * @returns {Array<{text: string, href: string, line: number}>}
 */
function parseLinks(content)
{
	const links = [];
	const lines = content.split('\n');
	let inCodeBlock = false;

	for(let i = 0; i < lines.length; i++)
	{
		const line = lines[i];
		const lineNum = i + 1;

		if(/^```/.test(line))
		{
			inCodeBlock = !inCodeBlock;
			continue;
		}

		if(inCodeBlock)
		{
			continue;
		}

		const linkRegex = /\[([^\]]*)\]\(([^)]+)\)/g;
		let match;
		while((match = linkRegex.exec(line)) !== null)
		{
			links.push({text: match[1], href: match[2], line: lineNum});
		}
		// A badge is an image inside a link, `[![alt](image)](target)`; the pattern above sees only the image, so the
		// link around it is read here.
		const badgeRegex = /\[!\[([^\]]*)\]\([^)]*\)\]\(([^)]+)\)/g;
		while((match = badgeRegex.exec(line)) !== null)
		{
			links.push({text: match[1], href: match[2], line: lineNum});
		}
	}

	return links;
}

/**
 * Converts a heading to a GitHub-compatible anchor slug
 * @param {string} heading - Heading text
 * @param {Map<string, number>} [slugCounts] - Tracks duplicate slugs for disambiguation
 * @returns {string} Anchor slug
 */
function githubSlug(heading, slugCounts)
{
	let slug = heading
	.toLowerCase()
	.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
	.replace(/<[^>]+>/g, '')
	.replace(/[^\w\s-]/g, '')
	.replace(/\s/g, '-')
	.replace(/^-|-$/g, '');

	if(slugCounts)
	{
		const count = slugCounts.get(slug) || 0;
		slugCounts.set(slug, count + 1);
		if(count > 0)
		{
			slug = `${slug}-${count}`;
		}
	}

	return slug;
}

// ─────────────────────────────────────────────────────────────────────────────
// Check Functions
// ─────────────────────────────────────────────────────────────────────────────

/** Maximum allowed line length for prose (outside code blocks) */
const MAX_LINE_LENGTH = 180;

/** The top folder of this checkout, where a link into the public repository is checked */
const REPOSITORY_ROOT = path.resolve(__dirname, '..');

/** How a guide links to a file in the public repository, so the documentation site can follow the link too */
const PUBLIC_REPOSITORY_FILE_PREFIX = 'https://github.com/JVB-Consulting/kerndx/blob/main/';

/**
 * Checks for lines exceeding the maximum allowed length (outside code blocks)
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkLineLength(content, filePath)
{
	const issues = [];
	const lines = content.split('\n');
	const codeBlocks = parseCodeBlocks(content);
	const codeLineRanges = codeBlocks.map(b => [
		b.startLine,
		b.endLine
	]);

	for(let i = 0; i < lines.length; i++)
	{
		const lineNum = i + 1;
		const line = lines[i];

		if(line.length <= MAX_LINE_LENGTH)
		{
			continue;
		}

		const inCodeBlock = codeLineRanges.some(([start, end]) => lineNum >= start && lineNum <= end);
		if(inCodeBlock)
		{
			continue;
		}

		if(/^\|/.test(line))
		{
			continue;
		}

		issues.push({
			file: filePath, line: lineNum, severity: 'warning', check: 'line-length', message: `Line exceeds ${MAX_LINE_LENGTH} characters (${line.length})`
		});
	}

	return issues;
}

/**
 * Checks that all rows in each Markdown table have consistent column widths
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkTableAlignment(content, filePath)
{
	const issues = [];
	const lines = content.split('\n');
	const codeBlocks = parseCodeBlocks(content);
	const codeLineRanges = codeBlocks.map(b => [
		b.startLine,
		b.endLine
	]);
	const tables = [];
	let currentTable = null;

	for(let i = 0; i < lines.length; i++)
	{
		const lineNum = i + 1;
		const line = lines[i];

		const inCodeBlock = codeLineRanges.some(([start, end]) => lineNum >= start && lineNum <= end);
		if(inCodeBlock)
		{
			if(currentTable)
			{
				tables.push(currentTable);
				currentTable = null;
			}
			continue;
		}

		if(/^\|/.test(line) && /\|$/.test(line.trimEnd()))
		{
			if(!currentTable)
			{
				currentTable = {startLine: lineNum, rows: []};
			}
			currentTable.rows.push({line: lineNum, text: line});
		}
		else
		{
			if(currentTable)
			{
				tables.push(currentTable);
				currentTable = null;
			}
		}
	}

	if(currentTable)
	{
		tables.push(currentTable);
	}

	for(const table of tables)
	{
		if(table.rows.length < 2)
		{
			continue;
		}

		const columnWidths = [];
		for(const row of table.rows)
		{
			const cells = row.text.split('|').slice(1, -1);
			const widths = cells.map(c => c.length);

			if(columnWidths.length === 0)
			{
				columnWidths.push(...widths);
			}
			else if(widths.length === columnWidths.length)
			{
				for(let c = 0; c < widths.length; c++)
				{
					if(widths[c] !== columnWidths[c])
					{
						issues.push({
							file: filePath,
							line: row.line,
							severity: 'warning',
							check: 'table-align',
							message: `Table column ${c + 1} width (${widths[c]}) differs from header (${columnWidths[c]})`
						});
						break;
					}
				}
			}
		}
	}

	return issues;
}

/**
 * Validates relative file links exist on disk
 * @param {string} content - File content
 * @param {string} filePath - Absolute path of the file being checked
 * @param {Object} [fsModule=fs] - File system module (for testing)
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkLinks(content, filePath, fsModule = fs)
{
	const issues = [];
	const links = parseLinks(content);
	const fileDir = path.dirname(filePath);

	for(const link of links)
	{
		// A guide that the documentation site also renders links to a repository file by its address in the public
		// repository; that file is in this checkout too, so it is checked here like a relative link.
		const inPublicRepository = link.href.startsWith(PUBLIC_REPOSITORY_FILE_PREFIX);
		if(!inPublicRepository && (link.href.startsWith('http://') || link.href.startsWith('https://')))
		{
			continue;
		}
		if(link.href.startsWith('#'))
		{
			continue;
		}

		let targetPath = (inPublicRepository ? link.href.slice(PUBLIC_REPOSITORY_FILE_PREFIX.length) : link.href).split('#')[0];
		targetPath = decodeURIComponent(targetPath);
		const resolved = inPublicRepository ? path.resolve(REPOSITORY_ROOT, targetPath) : path.resolve(fileDir, targetPath);

		if(!fsModule.existsSync(resolved))
		{
			issues.push({
				file: filePath, line: link.line, severity: 'error', check: 'link', message: `Broken link: ${link.href}`
			});
			continue;
		}

		const anchor = link.href.includes('#') ? link.href.slice(link.href.indexOf('#') + 1) : '';
		if(anchor && resolved.endsWith('.md') && !findHeadingSlugs(fsModule.readFileSync(resolved, 'utf-8')).has(decodeURIComponent(anchor)))
		{
			issues.push({
				file: filePath, line: link.line, severity: 'error', check: 'link', message: `Broken anchor: ${link.href} (no heading in ${targetPath} has that anchor)`
			});
		}
	}

	return issues;
}

/**
 * Lists the anchors a Markdown file's headings get on GitHub, so a link to `file.md#anchor` can be checked.
 * @param {string} content - Markdown content of the target file
 * @returns {Set<string>} the anchor of every heading, a repeated heading numbered as GitHub numbers it
 */
function findHeadingSlugs(content)
{
	const slugCounts = new Map();
	return new Set(parseHeadings(content).map(heading => githubSlug(heading.text, slugCounts)));
}

/**
 * Detects anti-patterns in Apex code blocks
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkAntiPatterns(content, filePath)
{
	const issues = [];
	const codeBlocks = parseCodeBlocks(content);

	const patterns = [
		{regex: /new\s+UTIL_HttpClient\s*\(/, message: 'Use static factories: UTIL_HttpClient.get()/post()/put()/del()/patch()'},
		{regex: /System\.debug\s*\(/, message: 'Use LOG_Builder instead of System.debug()'},
		{regex: /\[\s*SELECT\s/i, message: 'Use SEL_*/QRY_Builder instead of inline SOQL'},
		{regex: /^\s*(insert|update|delete|upsert)\s+\w/, message: 'Use DML_Builder instead of bare DML'},
		{regex: /System\.Assert/, message: 'Use Assert.* instead of System.Assert*'},
		{regex: /newQueryFactory|fflib_/, message: 'Wrong framework: use Kern patterns, not fflib'},
		{regex: /extends\s+LightningElement/, message: 'Use ComponentBuilder instead of LightningElement'}
	];

	for(const block of codeBlocks)
	{
		if(block.lang !== 'apex')
		{
			continue;
		}

		const codeLines = block.code.split('\n');
		for(let i = 0; i < codeLines.length; i++)
		{
			const codeLine = codeLines[i];
			const trimmed = codeLine.trimStart();

			if(trimmed.startsWith('//') || trimmed.startsWith('*'))
			{
				continue;
			}

			for(const pattern of patterns)
			{
				if(pattern.regex.test(codeLine))
				{
					issues.push({
						file: filePath, line: block.startLine + i + 1, severity: 'warning', check: 'anti-pattern', message: pattern.message
					});
				}
			}
		}
	}

	return issues;
}

/**
 * Detects old naming conventions in code blocks
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkOldNaming(content, filePath)
{
	const issues = [];
	const codeBlocks = parseCodeBlocks(content);

	const patterns = [
		{regex: /\bDAL_DataFactory\b/, message: 'DAL_DataFactory renamed to TST_Factory'},
		{regex: /\bDAL_(?!DataFactory)[A-Z]/, message: 'Old data access prefix DAL_ (renamed)'},
		{regex: /\bTRA_[A-Z]/, message: 'Old trigger prefix TRA_ (now TRG_)'},
		{regex: /\bINVO_[A-Z]/, message: 'Old invocable prefix INVO_ (now FLOW_)'},
		{regex: /\bURL_[A-Z]/, message: 'Old REST prefix URL_ (now REST_)'}
	];

	for(const block of codeBlocks)
	{
		if(block.lang !== 'apex' && block.lang !== 'javascript' && block.lang !== 'js')
		{
			continue;
		}

		const codeLines = block.code.split('\n');
		for(let i = 0; i < codeLines.length; i++)
		{
			const codeLine = codeLines[i];

			for(const pattern of patterns)
			{
				if(pattern.regex.test(codeLine))
				{
					const lowerLine = codeLine.toLowerCase();
					const isContextual = lowerLine.includes('renamed') || lowerLine.includes('previously') || lowerLine.includes('was called') || lowerLine.includes('formerly');

					issues.push({
						file: filePath, line: block.startLine + i + 1, severity: isContextual ? 'warning' : 'error', check: 'old-naming', message: pattern.message
					});
				}
			}
		}
	}

	return issues;
}

/**
 * Checks that class declarations in Apex code blocks have explicit sharing declarations
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkSharingDeclarations(content, filePath)
{
	const issues = [];
	const codeBlocks = parseCodeBlocks(content);
	const classRegex = /\bclass\s+(\w+)/;
	const sharingRegex = /\b(with\s+sharing|without\s+sharing|inherited\s+sharing)\b/;

	for(const block of codeBlocks)
	{
		if(block.lang !== 'apex')
		{
			continue;
		}

		const codeLines = block.code.split('\n');
		for(let i = 0; i < codeLines.length; i++)
		{
			const codeLine = codeLines[i];
			const trimmed = codeLine.trimStart();

			if(trimmed.startsWith('//') || trimmed.startsWith('*'))
			{
				continue;
			}

			if(/\.class\.getName\(\)/.test(codeLine))
			{
				continue;
			}

			if(/@IsTest/.test(codeLine) || (i > 0 && /@IsTest/.test(codeLines[i - 1])))
			{
				continue;
			}

			const classMatch = classRegex.exec(codeLine);
			if(classMatch)
			{
				const className = classMatch[1];

				if(!sharingRegex.test(codeLine))
				{
					const prevLine = i > 0 ? codeLines[i - 1] : '';
					if(/@IsTest/.test(prevLine))
					{
						continue;
					}

					issues.push({
						file: filePath, line: block.startLine + i + 1, severity: 'warning', check: 'sharing', message: `Missing sharing declaration: class ${className}`
					});
				}
			}
		}
	}

	return issues;
}

/**
 * Validates TOC completeness and anchor correctness
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkToc(content, filePath)
{
	const issues = [];
	const headings = parseHeadings(content);
	const tocEntries = parseTocEntries(content);

	const contentHeadings = headings.filter(h => h.level >= 2 && h.level <= 4 && h.text !== 'Table of Contents');

	let firstH2Found = false;
	for(const heading of contentHeadings)
	{
		if(heading.level === 2)
		{
			firstH2Found = true;
		}
		else if(!firstH2Found && heading.level > 2)
		{
			issues.push({
				file: filePath, line: heading.line, severity: 'warning', check: 'toc', message: `H${heading.level} "${heading.text}" appears before any H2 — likely should be H2`
			});
		}
	}

	if(contentHeadings.length <= 3)
	{
		return issues;
	}

	if(tocEntries.length === 0)
	{
		issues.push({
			file: filePath, line: 1, severity: 'warning', check: 'toc', message: 'Document has >3 sections but no Table of Contents'
		});
		return issues;
	}

	const slugCounts = new Map();
	const headingSlugs = new Map();
	for(const heading of contentHeadings)
	{
		const slug = githubSlug(heading.text, slugCounts);
		headingSlugs.set(slug, heading);
	}

	const tocAnchors = new Set();
	for(const entry of tocEntries)
	{
		tocAnchors.add(entry.anchor);

		if(!headingSlugs.has(entry.anchor))
		{
			issues.push({
				file: filePath, line: entry.line, severity: 'error', check: 'toc', message: `Orphaned TOC entry: "${entry.text}" (anchor #${entry.anchor} has no matching heading)`
			});
		}
	}

	for(const [slug, heading] of headingSlugs)
	{
		if(!tocAnchors.has(slug))
		{
			if(heading.level <= 3)
			{
				issues.push({
					file: filePath, line: heading.line, severity: 'warning', check: 'toc', message: `Heading not in TOC: "${heading.text}" (H${heading.level})`
				});
			}
		}
	}

	return issues;
}

/**
 * Flags code blocks without language tags
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkCodeFenceLanguages(content, filePath)
{
	const issues = [];
	const codeBlocks = parseCodeBlocks(content);

	for(const block of codeBlocks)
	{
		if(!block.lang)
		{
			let suggestion = '';
			const code = block.code;

			if(/\bclass\s+\w+|public\s+|private\s+|global\s+|@\w+/.test(code))
			{
				suggestion = ' (likely: apex)';
			}
			else if(/\bfunction\s+|const\s+|let\s+|import\s+|require\s*\(/.test(code))
			{
				suggestion = ' (likely: javascript)';
			}
			else if(/\bSELECT\s+|FROM\s+|WHERE\s+/i.test(code))
			{
				suggestion = ' (likely: sql or soql)';
			}
			else if(/<\w+[>\s/]/.test(code))
			{
				suggestion = ' (likely: html or xml)';
			}
			else if(/^\s*(sf|sfdx|npm|node|git|cd|mkdir)\s/m.test(code))
			{
				suggestion = ' (likely: bash)';
			}

			issues.push({
				file: filePath, line: block.startLine, severity: 'warning', check: 'code-fence', message: `Code block without language tag${suggestion}`
			});
		}
	}

	return issues;
}

/**
 * Scans PROSE for `kern.`-qualified class references.
 *
 * Only inline code spans are inspected, and only `kern.`-qualified tokens are reported, so an
 * ordinary mention of a class name in a sentence never fires. This is the whole false-positive
 * control, and it is why prose can be scanned at ERROR severity at all.
 *
 * Prose matters because the rosters that drift live there, not in apex fences. It deliberately
 * does NOT try to expand shorthand rosters (`` `kern.UTIL_String` / `Date` / `Number` ``): deriving
 * `UTIL_Number` from a bare `Date` requires guessing that the separator means "same stem", and
 * ordinary prose such as `` `kern.DML_Builder` / `Database` `` would then fabricate a
 * `kern.DML_Database` that appears nowhere and fail CI on it. Spell rosters out instead — one
 * fully-qualified name per entry is greppable by this scan and by a human.
 *
 * @param {string} content - File content
 * @param {function(string, boolean, number): void} record - Callback: (ref, qualified, line)
 * @returns {void}
 */
function scanProseClassReferences(content, record)
{
	const text = maskNonProseContent(content);
	const lineOf = buildLineResolver(text);
	const spanRegex = /`([^`\n]+)`/g;
	const qualifiedRegex = /\bkern\.([A-Z]{2,}[A-Z0-9]*_[A-Za-z]\w*)\b/g;
	let spanMatch;

	while((spanMatch = spanRegex.exec(text)) !== null)
	{
		let match;
		qualifiedRegex.lastIndex = 0;

		while((match = qualifiedRegex.exec(spanMatch[1])) !== null)
		{
			record(match[1], true, lineOf(spanMatch.index));
		}
	}
}

/**
 * Blanks everything that is not prose, keeping the line count intact.
 *
 * Fenced blocks are masked line-for-line so reported line numbers stay accurate. Backtick and
 * tilde fences both count, and the marker tolerates leading whitespace — the same anchor rule
 * parseCodeBlocks uses, so a fence body is masked here exactly when its lines are scanned as code
 * there. (Indented fences were once invisible to BOTH passes: parseCodeBlocks anchored its fence
 * regexes at column 0, so a list-nested ```apex fence opened no block and its body was scanned by
 * neither the code-block pass nor the prose pass. Both ends were un-anchored together — opener AND
 * closer — because un-anchoring only the opener leaves a block permanently open and blinds every
 * downstream check.)
 *
 * HTML comments are blanked in place, newlines preserved: they carry retired names on purpose.
 *
 * @param {string} content - Markdown content
 * @returns {string} The content with fences and HTML comments blanked
 */
function maskNonProseContent(content)
{
	const masked = [];
	let fenceMarker = '';

	for(const line of content.split('\n'))
	{
		const marker = /^[ \t]*(`{3,}|~{3,})/.exec(line);

		if(fenceMarker)
		{
			masked.push('');
			if(marker && marker[1][0] === fenceMarker[0] && marker[1].length >= fenceMarker.length)
			{
				fenceMarker = '';
			}
			continue;
		}

		if(marker)
		{
			fenceMarker = marker[1];
			masked.push('');
			continue;
		}

		masked.push(line);
	}

	return masked.join('\n').replace(/<!--[\s\S]*?-->/g, comment => comment.replace(/[^\n]/g, ' '));
}

/**
 * Builds an offset → line-number resolver over one text, in a single indexing pass, so a scan of
 * a large file stays linear rather than counting newlines per match.
 *
 * @param {string} text - The text the offsets index into
 * @returns {function(number): number} Offset → 1-based line number
 */
function buildLineResolver(text)
{
	const lineStarts = [0];
	for(let i = 0; i < text.length; i++)
	{
		if(text[i] === '\n')
		{
			lineStarts.push(i + 1);
		}
	}

	return (offset) =>
	{
		let low = 0;
		let high = lineStarts.length - 1;
		while(low < high)
		{
			const mid = Math.ceil((low + high) / 2);
			if(lineStarts[mid] <= offset)
			{
				low = mid;
			}
			else
			{
				high = mid - 1;
			}
		}
		return low + 1;
	};
}

/**
 * Validates Kern class references, in two tiers.
 *
 * A `kern.`-qualified reference names the framework's released public API, so it is resolved
 * against the generated reference pages ONLY (`globalIndex`) and a miss is an ERROR — a class
 * that exists in force-app but is declared `public` cannot be named by a subscriber, and
 * resolving it through the source tree is exactly how `kern.UTIL_Set` shipped undetected.
 *
 * A bare reference is usually a subscriber-authored example class, so it stays lenient: it is
 * resolved against the union index and a miss is a WARNING.
 *
 * Qualified references are scanned in prose as well as in apex fences, because the rosters that
 * drift most (`kern.UTIL_String` | `kern.UTIL_Date` | ...) live in prose. Bare identifiers in
 * prose are never reported, which is what keeps the false-positive rate at zero.
 *
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @param {Set<string>} classIndex - Union of source classes and reference pages (lenient tier)
 * @param {Set<string>} globalIndex - Reference pages only (strict tier); omit to disable it
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkClassReferences(content, filePath, classIndex, globalIndex = null)
{
	const issues = [];

	if(!classIndex || classIndex.size === 0)
	{
		return issues;
	}

	// No reference pages available (e.g. a partial clone) → strict tier off, behaviour unchanged.
	const strict = globalIndex && globalIndex.size > 0 ? globalIndex : null;
	const normalisedPath = filePath.split(path.sep).join('/');
	const reported = new Set();

	const isAllowlisted = (ref) => KERN_CLASS_REF_EXCEPTIONS.some(
		entry => entry.ref === ref && (normalisedPath === entry.file || normalisedPath.endsWith(`/${entry.file}`))
	);

	const record = (ref, qualified, line) =>
	{
		if(ref.endsWith('__c') || ref.endsWith('__mdt') || ref.endsWith('__e') || ref.endsWith('__r') || ref.endsWith('__b') || ref.endsWith('__x'))
		{
			return;
		}

		const prefix = ref.split('_')[0] + '_';
		if(!KERN_PREFIXES.has(prefix) || ref.includes('_TEST'))
		{
			return;
		}

		// Qualified and bare misses carry different messages and severities, so they key
		// separately — but only when the strict tier is live. With it off both forms fall through
		// to the identical lenient warning, and keying them apart would double-report one name.
		const strictQualified = qualified && Boolean(strict);
		const reportKey = `${filePath}:${strictQualified ? 'kern.' : ''}${ref}`;
		if(reported.has(reportKey))
		{
			return;
		}

		if(strictQualified)
		{
			if(isAllowlisted(ref) || strict.has(ref))
			{
				return;
			}

			reported.add(reportKey);
			issues.push({
				file: filePath, line, severity: 'error', check: 'class-ref',
				message: `Unknown framework class reference: kern.${ref} — no docs/reference/apex/${ref}.md page, so it is not subscriber-callable`
			});
			return;
		}

		if(!classIndex.has(ref))
		{
			reported.add(reportKey);
			issues.push({file: filePath, line, severity: 'warning', check: 'class-ref', message: `Unknown class reference: ${ref}`});
		}
	};

	const codeBlocks = parseCodeBlocks(content);
	const classRefRegex = /(\bkern\.)?\b([A-Z]{2,}[A-Z0-9]*_[A-Za-z]\w*)\b/g;

	for(const block of codeBlocks)
	{
		if(block.lang !== 'apex')
		{
			continue;
		}

		const codeLines = block.code.split('\n');
		for(let i = 0; i < codeLines.length; i++)
		{
			const codeLine = codeLines[i];
			const trimmed = codeLine.trimStart();

			if(trimmed.startsWith('//') || trimmed.startsWith('*'))
			{
				continue;
			}

			let match;
			classRefRegex.lastIndex = 0;
			while((match = classRefRegex.exec(codeLine)) !== null)
			{
				record(match[2], Boolean(match[1]), block.startLine + i + 1);
			}
		}
	}

	// Prose is scanned only for the strict tier. With no reference pages there is nothing to
	// resolve a qualified name against, and the 3-argument call form must stay byte-compatible.
	if(strict)
	{
		scanProseClassReferences(content, record);
	}

	return issues;
}

/**
 * Collects `Class.member` tokens from one stretch of text.
 *
 * File-name tokens are dropped here rather than at the call sites, so every scanner treats
 * `DML_Builder.md` the same way: as a file, never as a member.
 *
 * @param {string} text - The text to scan
 * @returns {Array<{typeName: string, member: string, index: number}>} Tokens, with their offsets
 */
function collectMemberTokens(text)
{
	const tokens = [];
	let match;

	MEMBER_REF_PATTERN.lastIndex = 0;
	while((match = MEMBER_REF_PATTERN.exec(text)) !== null)
	{
		if(FILE_NAME_MEMBER_TOKENS.has(match[2]))
		{
			continue;
		}

		tokens.push({typeName: match[1], member: match[2], index: match.index});
	}

	return tokens;
}

/**
 * Collects the offset ranges of Markdown link targets, so a path inside `](...)` is never read as
 * a member reference.
 *
 * @param {string} text - The text to scan
 * @returns {Array<Array<number>>} `[start, end)` offset pairs
 */
function collectLinkTargetRanges(text)
{
	const ranges = [];
	const linkRegex = /]\(([^)\n]*)\)/g;
	let match;

	while((match = linkRegex.exec(text)) !== null)
	{
		ranges.push([match.index + 2, match.index + 2 + match[1].length]);
	}

	return ranges;
}

/**
 * Builds the message a member miss reports.
 *
 * @param {string} typeName - The type carrying the member
 * @param {string} member - The member as written
 * @returns {string} The issue message
 */
function memberRefMessage(typeName, member)
{
	return `Unknown framework member reference: ${typeName}.${member} — not on docs/reference/apex/${typeName}.md, `
		+ 'so a managed-package reader cannot compile it; spell the literal or describe the behaviour instead';
}

/**
 * Tests one reference against the file-scoped member allowlist.
 *
 * @param {string} ref - `Class.member` as written
 * @param {string} normalisedPath - The file path, forward-slashed
 * @returns {boolean} True when this file may name this reference
 */
function isMemberRefAllowlisted(ref, normalisedPath)
{
	return KERN_MEMBER_REF_EXCEPTIONS.some(
		entry => entry.ref === ref && (normalisedPath === entry.file || normalisedPath.endsWith(`/${entry.file}`))
	);
}

/**
 * Validates that every `Class.member` a doc names is published on that class's reference page.
 *
 * The check reports ONLY what it can resolve with certainty: a type that HAS a reference page,
 * naming a member that page does not carry. A type without a page is left entirely to
 * checkClassReferences — a subscriber-authored example class, a `public` framework internal and a
 * typo are indistinguishable at the member level, and a false positive here would cost more than
 * the miss. Everything else — file names, link targets, unindexed types — passes.
 *
 * Apex fences and inline code spans are scanned; bare prose is not, for the same reason the class
 * check leaves it alone.
 *
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @param {Map<string, Set<string>>} memberIndex - Type name → published member names
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function scanMemberReferences(content, filePath, memberIndex)
{
	const issues = [];

	// No reference pages available (e.g. a partial clone) → the check is off, as for classes.
	if(!memberIndex || memberIndex.size === 0)
	{
		return issues;
	}

	const normalisedPath = filePath.split(path.sep).join('/');
	const reported = new Set();

	const record = (token, line) =>
	{
		const members = memberIndex.get(token.typeName);
		const ref = `${token.typeName}.${token.member}`;

		// A wildcard roster (`SEL_MaskingRule.RULE_MASK_*`) never resolves, which is the point:
		// the stem is stripped only so an exact member spelled with one is still matched.
		if(!members || members.has(token.member.replace(/\*+$/, '')) || reported.has(ref) || isMemberRefAllowlisted(ref, normalisedPath))
		{
			return;
		}

		reported.add(ref);
		issues.push({
			file: filePath, line, severity: 'error', check: 'member-ref',
			message: memberRefMessage(token.typeName, token.member)
		});
	};

	for(const block of parseCodeBlocks(content))
	{
		if(block.lang !== 'apex')
		{
			continue;
		}

		const codeLines = block.code.split('\n');
		for(let i = 0; i < codeLines.length; i++)
		{
			const trimmed = codeLines[i].trimStart();

			if(trimmed.startsWith('//') || trimmed.startsWith('*'))
			{
				continue;
			}

			for(const token of collectMemberTokens(codeLines[i]))
			{
				record(token, block.startLine + i + 1);
			}
		}
	}

	scanProseMemberReferences(content, record);

	return issues;
}

/**
 * Scans PROSE for `Class.member` references.
 *
 * Only inline code spans are inspected — the same false-positive control scanProseClassReferences
 * relies on — and a token inside a Markdown link target is skipped, because a path is not a claim
 * that the name compiles.
 *
 * @param {string} content - File content
 * @param {function({typeName: string, member: string, index: number}, number): void} record
 * @returns {void}
 */
function scanProseMemberReferences(content, record)
{
	const text = maskNonProseContent(content);
	const lineOf = buildLineResolver(text);
	const linkRanges = collectLinkTargetRanges(text);
	const spanRegex = /`([^`\n]+)`/g;
	let spanMatch;

	while((spanMatch = spanRegex.exec(text)) !== null)
	{
		for(const token of collectMemberTokens(spanMatch[1]))
		{
			const offset = spanMatch.index + 1 + token.index;

			if(linkRanges.some(([start, end]) => offset >= start && offset < end))
			{
				continue;
			}

			record(token, lineOf(spanMatch.index));
		}
	}
}

/**
 * Decides whether a file's FIRST type declaration is `global`.
 *
 * ApexDoc on a `public` class never reaches a subscriber, so only global classes are scanned.
 * Comments are stripped first so prose naming a declaration cannot be mistaken for one.
 *
 * @param {string} content - Apex class source
 * @returns {boolean} True when the file declares a global type
 */
function declaresGlobalType(content)
{
	const stripped = content.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
	const declaration = stripped.split('\n').find(line => TYPE_DECLARATION_PATTERN.test(line));

	return Boolean(declaration) && GLOBAL_TYPE_PATTERN.test(declaration);
}

/**
 * Collects the `/** ... *\/` block ranges of one Apex file.
 *
 * @param {Array<string>} lines - The file's lines
 * @returns {Array<{startIndex: number, endIndex: number}>} Zero-based, inclusive line ranges
 */
function collectApexDocBlocks(lines)
{
	const blocks = [];
	let startIndex = -1;

	for(let i = 0; i < lines.length; i++)
	{
		if(startIndex === -1 && lines[i].trimStart().startsWith('/**'))
		{
			startIndex = i;
		}

		if(startIndex > -1 && lines[i].includes('*/'))
		{
			blocks.push({startIndex, endIndex: i});
			startIndex = -1;
		}
	}

	return blocks;
}

/**
 * Decides whether a doc block documents subscriber-visible surface: the next real line after it
 * is a global type, a global or webservice member, or a global constructor.
 *
 * @param {Array<string>} lines - The file's lines
 * @param {number} endIndex - Zero-based index of the block's closing line
 * @returns {boolean} True when the documented member is part of the global surface
 */
function documentsGlobalSurface(lines, endIndex)
{
	for(let i = endIndex + 1; i < lines.length; i++)
	{
		const trimmed = lines[i].trim();

		if(trimmed === '' || /^@\w+/.test(trimmed))
		{
			continue;
		}

		return GLOBAL_TYPE_PATTERN.test(lines[i]) || GLOBAL_MEMBER_PATTERN.test(lines[i]) || GLOBAL_CONSTRUCTOR_PATTERN.test(lines[i]);
	}

	return false;
}

/**
 * Renders a path relative to the repository root when it sits inside it, for reporting.
 *
 * @param {string} absolutePath - The path to render
 * @returns {string} A forward-slashed, repo-relative path where possible
 */
function toRepoRelativePath(absolutePath)
{
	const root = `${process.cwd()}${path.sep}`;
	const relative = absolutePath.startsWith(root) ? absolutePath.slice(root.length) : absolutePath;

	return relative.split(path.sep).join('/');
}

/**
 * Validates the member references in ApexDoc on the released global surface.
 *
 * ApexDoc on a global member IS shipped documentation — the generator copies it onto the
 * reference page — so a comment naming an unreachable member leaks exactly the same defect a
 * guide would. Scanning the source rather than the generated pages makes the leak fail at commit
 * time instead of at the next generator run.
 *
 * @param {string} classesDir - Path to the Apex classes directory
 * @param {Map<string, Set<string>>} memberIndex - Type name → published member names
 * @param {Object} [fsModule=fs] - File system module (for testing)
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkApexDocMemberReferences(classesDir, memberIndex, fsModule = fs)
{
	const issues = [];

	if(!memberIndex || memberIndex.size === 0 || !fsModule.existsSync(classesDir))
	{
		return issues;
	}

	for(const file of fsModule.readdirSync(classesDir))
	{
		if(!file.endsWith('.cls'))
		{
			continue;
		}

		const content = fsModule.readFileSync(path.join(classesDir, file), 'utf8');

		if(!declaresGlobalType(content))
		{
			continue;
		}

		const reportPath = toRepoRelativePath(path.join(classesDir, file));
		const lines = content.split('\n');
		const reported = new Set();

		for(const block of collectApexDocBlocks(lines))
		{
			if(!documentsGlobalSurface(lines, block.endIndex))
			{
				continue;
			}

			for(let i = block.startIndex; i <= block.endIndex; i++)
			{
				for(const token of collectMemberTokens(lines[i]))
				{
					const members = memberIndex.get(token.typeName);
					const ref = `${token.typeName}.${token.member}`;

					if(!members || members.has(token.member.replace(/\*+$/, '')) || reported.has(ref) || isMemberRefAllowlisted(ref, reportPath))
					{
						continue;
					}

					reported.add(ref);
					issues.push({
						file: reportPath, line: i + 1, severity: 'error', check: 'apexdoc-member-ref',
						message: memberRefMessage(token.typeName, token.member)
					});
				}
			}
		}
	}

	return issues;
}

/**
 * Builds an index of known class names from the classes directory and reference docs
 * @param {string} classesDir - Path to Apex classes directory
 * @param {string} referenceDir - Path to reference docs directory
 * @param {Object} [fsModule=fs] - File system module (for testing)
 * @returns {Set<string>} Set of known class names
 */
/**
 * Cross-doc check: every `Kern@X.Y.Z-N` reference across the doc set should
 * agree on the latest version (or live in an allowlisted file that names a
 * historical release intentionally — CHANGELOG.md, release-notes/, etc.).
 *
 * Flagged refs are emitted as issues against the file/line where they
 * appear. Highest semver wins; everything else is "stale, please update".
 *
 * @param {{filePath: string, content: string}[]} fileContents
 * @param {RegExp[]} [allowedPathPatterns] — file paths matching ANY pattern
 *   are exempt (e.g. release notes per build, CHANGELOG).
 * @return {{filePath: string, line: number, severity: string, check: string, message: string}[]}
 */
function checkCrossDocVersionConsistency(fileContents, allowedPathPatterns = [])
{
	const versionRefs = new Map();
	const versionRe = /Kern@(\d+\.\d+\.\d+-\d+)/g;

	for(const {filePath, content} of fileContents)
	{
		if(allowedPathPatterns.some(re => re.test(filePath)))
		{
			continue;
		}
		const lines = content.split('\n');
		for(let i = 0; i < lines.length; i++)
		{
			const line = lines[i];
			let m;
			versionRe.lastIndex = 0;
			while((m = versionRe.exec(line)) !== null)
			{
				const v = m[1];
				if(!versionRefs.has(v))
				{
					versionRefs.set(v, []);
				}
				versionRefs.get(v).push({filePath, line: i + 1});
			}
		}
	}

	if(versionRefs.size <= 1)
	{
		return [];
	}

	const compareVersion = (a, b) =>
	{
		const pa = a.split(/[.-]/).map(Number);
		const pb = b.split(/[.-]/).map(Number);
		for(let i = 0; i < Math.max(pa.length, pb.length); i++)
		{
			const da = pa[i] || 0, db = pb[i] || 0;
			if(da !== db)
			{
				return da - db;
			}
		}
		return 0;
	};
	const sorted = [...versionRefs.keys()].sort(compareVersion);
	const latest = sorted[sorted.length - 1];

	const issues = [];
	for(const [version, refs] of versionRefs)
	{
		if(version === latest)
		{
			continue;
		}
		for(const ref of refs)
		{
			issues.push({
				filePath: ref.filePath,
				line: ref.line,
				severity: 'error',
				check: 'cross-doc-version',
				message: `Stale "Kern@${version}" — other docs say "Kern@${latest}". Update or move to release-notes/CHANGELOG.`
			});
		}
	}
	return issues;
}

/**
 * Builds the index of SUBSCRIBER-CALLABLE class names — the generated reference pages only.
 *
 * A page under docs/reference/apex/ exists if and only if the type is part of the released
 * global surface, so page-existence is the only reliable proof that `kern.<Name>` compiles in a
 * subscriber org. A class present in force-app but declared `public` is invisible to subscribers,
 * which is why buildClassIndex (the lenient, union index) must not be used for `kern.`-qualified
 * references.
 *
 * @param {string} referenceDir - Absolute path to docs/reference/apex
 * @param {object} fsModule - Injectable fs for testing
 * @returns {Set<string>} Top-level and inner type names carrying a reference page
 */
function buildGlobalClassIndex(referenceDir, fsModule = fs)
{
	const index = new Set();

	if(fsModule.existsSync(referenceDir))
	{
		const files = fsModule.readdirSync(referenceDir);
		for(const file of files)
		{
			if(file.endsWith('.md'))
			{
				const name = file.slice(0, -3);
				index.add(name);
				index.add(name.split('.')[0]);
			}
		}
	}

	return index;
}

/**
 * Reads one generated reference page's member headings.
 *
 * Every `### name` heading is a member; the subset sitting under `## Methods` is tracked
 * separately because only methods fold into the outer class. A constructor heading drops its
 * argument list, and Markdown escapes are stripped.
 *
 * @param {string} content - The page's Markdown
 * @returns {{members: Set<string>, methods: Set<string>}} All member names, and the methods among them
 */
function parseReferencePageMembers(content)
{
	const members = new Set();
	const methods = new Set();
	let section = '';

	for(const line of content.split('\n'))
	{
		const sectionHeading = /^##\s+(.+?)\s*$/.exec(line);

		if(sectionHeading)
		{
			section = sectionHeading[1];
			continue;
		}

		const heading = /^###\s+(.+?)\s*$/.exec(line);

		if(heading)
		{
			const member = heading[1].replace(/\\/g, '').split('(')[0].trim();
			members.add(member);

			if(section === 'Methods')
			{
				methods.add(member);
			}
		}
	}

	return {members, methods};
}

/**
 * Builds the index of PUBLISHED members, keyed by the type that carries them.
 *
 * A `### name` heading on a generated reference page is the proof that a member is part of the
 * released global surface — the generator writes one heading per global member — so a member the
 * page does not carry cannot be compiled by a subscriber. Constructor headings drop their
 * argument list, and an overload set collapses to the one name it shares.
 *
 * An inner-type page (`Outer.Inner.md`) contributes `Inner` to `Outer`'s set as well, because
 * `Outer.Inner` is itself a member reference a doc may make, and so do that page's METHODS: the
 * guides name a fluent step by the type that starts the chain, and that method is published. Its
 * fields and enum values do not fold — they never compile through the outer type name — and the
 * fold happens only when the outer class has a page of its own.
 *
 * @param {string} referenceDir - Absolute path to docs/reference/apex
 * @param {Object} [fsModule=fs] - File system module (for testing)
 * @returns {Map<string, Set<string>>} Type name → the member names its page publishes
 */
function buildGlobalMemberIndex(referenceDir, fsModule = fs)
{
	const index = new Map();

	if(!fsModule.existsSync(referenceDir))
	{
		return index;
	}

	const methodsByPage = new Map();

	for(const file of fsModule.readdirSync(referenceDir))
	{
		if(!file.endsWith('.md') || file === 'index.md')
		{
			continue;
		}

		const name = file.slice(0, -3);
		const page = parseReferencePageMembers(fsModule.readFileSync(path.join(referenceDir, file), 'utf8'));

		index.set(name, page.members);
		methodsByPage.set(name, page.methods);
	}

	// Second pass, over the collected headings only (no page is read twice): an inner type folds
	// into its outer class. The guides name a fluent step by the type that starts the chain
	// (`QRY_Builder.withUserMode()` for a method published on QRY_Builder.Builder), and that member
	// IS on the released surface — so resolving it only against the outer page would report house
	// style as a defect. Only METHODS fold: an enum value or a field named on the outer type
	// (`API_Base.GET`) does not compile, and must keep failing. The fold also requires the outer
	// page to exist, because inventing a key from an inner page alone would give that class a
	// partial member set and turn every other member of it into a false positive.
	for(const [name, methods] of methodsByPage)
	{
		const separator = name.indexOf('.');
		const outer = separator > -1 ? index.get(name.slice(0, separator)) : null;

		if(!outer)
		{
			continue;
		}

		outer.add(name.slice(separator + 1).split('.')[0]);

		for(const method of methods)
		{
			outer.add(method);
		}
	}

	return index;
}

function buildClassIndex(classesDir, referenceDir, fsModule = fs)
{
	const index = new Set();

	if(fsModule.existsSync(classesDir))
	{
		const files = fsModule.readdirSync(classesDir);
		for(const file of files)
		{
			if(file.endsWith('.cls'))
			{
				index.add(file.replace('.cls', ''));
			}
		}
	}

	if(fsModule.existsSync(referenceDir))
	{
		const files = fsModule.readdirSync(referenceDir);
		for(const file of files)
		{
			if(file.endsWith('.md'))
			{
				index.add(file.replace('.md', ''));
			}
		}
	}

	return index;
}

// ─────────────────────────────────────────────────────────────────────────────
// TOC Generation
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Extracts display text from a heading, stripping markdown links and backticks
 * @param {string} heading - Raw heading text
 * @returns {string} Clean display text
 */
function extractHeadingText(heading)
{
	return heading
	.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
	.replace(/\*\*([^*]+)\*\*/g, '$1')
	.replace(/\*([^*]+)\*/g, '$1')
	.replace(/`/g, '');
}

/**
 * Determines whether an H4 heading should be excluded from the TOC.
 * Excludes numbered best practices and implementation steps; keeps named
 * patterns, subsystems, algorithms, and anything with navigational value.
 * @param {string} text - Heading text (after extractHeadingText)
 * @returns {boolean} True if the H4 should be excluded
 */
function shouldExcludeH4(text)
{
	if(/^\d+\.\s/.test(text) && !/^\d+\.\s+(CLOSED|OPEN|HALF_OPEN|Using|Manual)/.test(text))
	{
		return true;
	}
	if(/^Step\s+\d/i.test(text))
	{
		return true;
	}
	return false;
}

/**
 * Generates a standardised TOC from headings: numbered H2, indented H3/H4
 * @param {Array<{level: number, text: string}>} headings - Parsed headings (H2-H4, excluding TOC heading)
 * @returns {{lines: string[], h4Removed: number}}
 */
function generateToc(headings)
{
	const slugCounts = new Map();
	const tocLines = [];
	let h2Counter = 0;
	let h4Removed = 0;
	let h3Indent = '   ';

	for(const heading of headings)
	{
		const cleanText = extractHeadingText(heading.text);
		const slug = githubSlug(heading.text, slugCounts);

		if(heading.level === 2)
		{
			h2Counter++;
			h3Indent = ' '.repeat(String(h2Counter).length + 2);
			tocLines.push(`${h2Counter}. [${cleanText}](#${slug})`);
		}
		else if(heading.level === 3)
		{
			tocLines.push(`${h3Indent}- [${cleanText}](#${slug})`);
		}
		else if(heading.level === 4)
		{
			if(shouldExcludeH4(cleanText))
			{
				h4Removed++;
			}
			else
			{
				const h4Indent = ' '.repeat(h3Indent.length + 2);
				tocLines.push(`${h4Indent}- [${cleanText}](#${slug})`);
			}
		}
	}

	return {lines: tocLines, h4Removed};
}

/**
 * Rewrites the TOC in a Markdown file using the standard format
 * @param {string} content - File content
 * @param {Array<{level: number, text: string}>} headings - Parsed headings
 * @returns {{content: string, changed: boolean, h4Removed: number}} Updated content and metadata
 */
function rewriteToc(content, headings)
{
	const lines = content.split('\n');
	let tocStartLine = -1;
	let tocEndLine = -1;

	for(let i = 0; i < lines.length; i++)
	{
		if(/^##\s+Table of Contents/i.test(lines[i]))
		{
			tocStartLine = i;
		}
		if(tocStartLine >= 0 && tocEndLine < 0 && i > tocStartLine + 1)
		{
			if(/^---/.test(lines[i]) || (/^##\s+/.test(lines[i]) && !/Table of Contents/.test(lines[i])))
			{
				tocEndLine = i;
				break;
			}
		}
	}

	if(tocStartLine < 0)
	{
		return {content, changed: false, h4Removed: 0};
	}
	if(tocEndLine < 0)
	{
		tocEndLine = lines.length;
	}

	const contentHeadings = headings.filter(h => h.level >= 2 && h.level <= 4 && h.text !== 'Table of Contents');
	const {lines: tocLines, h4Removed} = generateToc(contentHeadings);

	const beforeToc = lines.slice(0, tocStartLine + 1);
	const afterToc = lines.slice(tocEndLine);
	const newContent = [
		...beforeToc,
		'',
		'<details>',
		'<summary>Expand</summary>',
		'',
		...tocLines,
		'',
		'</details>',
		'',
		...afterToc
	].join('\n');

	return {content: newContent, changed: newContent !== content, h4Removed};
}

// ─────────────────────────────────────────────────────────────────────────────
// Prose File-Reference Check — source + release-time validation
// ─────────────────────────────────────────────────────────────────────────────

// Shared extractor — same heuristics + skip rules on both sides. See
// scripts/lib/doc-claim-extractor.js.
const docClaimExtractor = require('./lib/doc-claim-extractor');
const {checkStepShape, checkSurfaces, checkRoster} = require('./lib/guide-step-shape');

// Source-side allowlist — intentionally tiny. The extractor's built-in skip
// rules (SUBSCRIBER_APEX_RE, FAST_START_RE, TUTORIAL_APEX_RE, ...) already
// cover the high-volume categories. This list is for the remaining cases
// that don't fit a generalizable pattern. Add with a one-line justification.
const DEFAULT_PROSE_REF_ALLOWLIST = [
	// `(e.g., scanner/myorg-naming-pmd-ruleset.xml)` — copy-this-file
	// instruction in Code Scanning - Guide.md §"Building Org-Specific Rules".
	'scanner/myorg-naming-pmd-ruleset.xml',
	// `(e.g., package.xml)` — Salesforce-standard filename referenced in
	// Strategic Guide - Operations.md as the canonical metadata manifest.
	'package.xml',
	// Fast Start tutorial-example classes: subscriber creates these in their
	// own org. Bare `Layer_Name.cls` (no Domain prefix) doesn't match the
	// extractor's SUBSCRIBER_APEX_RE pattern, so explicit allowlist.
	'SEL_Accounts.cls',
	'SEL_Accounts_TEST.cls',
	'TRG_AccountSetDefaults.cls',
	'TRG_AccountSetDefaults_TEST.cls',
	// Synthesized at release time; not in the source tree.
	'sfdx-project.template.json',
	// Release-time provenance file referenced from Installation.md.
	'RELEASE-PROVENANCE.json',
	// Bundled inside the pipeline-flavor distribution zip (INSTALL-PIPELINE.md
	// at the zip's root); referenced from Installation.md Path 3. Not in the
	// source tree — generated by scripts/build-distribution.js at zip-build time.
	'INSTALL-PIPELINE.md',
	// `<Class>` placeholder in Code Conventions reference path example.
	'docs/reference/apex/ClassName.md',
	// E2E Testing Guide example/placeholder file names.
	'pattern:release-testing/e2e/**/partN-*',
	'pattern:release-testing/e2e/**/feature-area*',
	'pattern:partN-*.spec.js',
	'pattern:feature-area*',
	'pattern:health-check*',
	// Playwright session-state files: runtime-generated by
	// release-testing/e2e/global-setup.js. Never committed (release manifest
	// blacklist + root .gitignore prevent ship). Referenced in Fast Start -
	// E2E Testing.md troubleshooting ("delete and regenerate").
	'pattern:release-testing/e2e/.auth/**',
	// Recognizable AI-context-file naming convention referenced in
	// docs/Installation.md §"Project Template".
	'CLAUDE.md',
	// npm scripts referenced in docs/Strategic Guide - Personas.md
	// §"Operational discipline" as evidence of operational rigor.
	'npm:test:load:extended',
	'npm:test:perf:report',
	// `CONTRIBUTING.md` — synthesized into the published repository at sync time;
	// never present in this source repo, legitimately referenced by shipped guides.
	'CONTRIBUTING.md'
];

let _sourceFileIndex = null;

function buildSourceFileIndex(repoRoot, fsModule)
{
	if(_sourceFileIndex && _sourceFileIndex.root === repoRoot)
	{
		return _sourceFileIndex.index;
	}
	const byBasename = new Map();
	const SKIP_DIRS = new Set([
		'node_modules',
		'.git',
		'tmp',
		'.planning',
		// evidence/ is internal research (mirror-blacklisted, never shipped) and its git-excluded _repos/ clones
		// satisfied lookups by accident; nothing under it may satisfy a shipped-doc source claim
		'evidence'
	]);
	(function walk(d)
	{
		const entries = fsModule.readdirSync(d, {withFileTypes: true});
		for(const entry of entries)
		{
			if(SKIP_DIRS.has(entry.name))
			{
				continue;
			}
			const full = path.join(d, entry.name);
			if(entry.isDirectory())
			{
				walk(full);
			}
			else if(entry.isFile())
			{
				if(!byBasename.has(entry.name))
				{
					byBasename.set(entry.name, []);
				}
				byBasename.get(entry.name).push(path.relative(repoRoot, full));
			}
		}
	})(repoRoot);
	_sourceFileIndex = {root: repoRoot, index: byBasename};
	return byBasename;
}

function loadSourcePackageScripts(repoRoot, fsModule)
{
	const pkgPath = path.join(repoRoot, 'package.json');
	if(!fsModule.existsSync(pkgPath))
	{
		return null;
	}
	try
	{
		const pkg = JSON.parse(fsModule.readFileSync(pkgPath, 'utf8'));
		return new Set(Object.keys(pkg.scripts || {}));
	}
	catch(_e)
	{
		return null;
	}
}

/**
 * Core checker — returns the flat list of unresolved claims in the given
 * markdown content. Shape: {line, type, claim}. Used by both the source-side
 * `docs:validate` per-file check AND the release-time validator.
 *
 * @param {string} content - Markdown content
 * @param {string} treeRoot - Root of the file tree to resolve refs against
 * @param {Object} fsModule - File system module (for testing)
 * @param {string[]} [allowlist] - Allowlist entries (defaults to DEFAULT_PROSE_REF_ALLOWLIST)
 * @returns {Array<{line: number, type: string, claim: string}>}
 */
function findUnresolvedClaims(content, treeRoot, fsModule, allowlist)
{
	const unresolved = [];
	const allowSet = new Set(allowlist || DEFAULT_PROSE_REF_ALLOWLIST);
	const npmScripts = loadSourcePackageScripts(treeRoot, fsModule);
	const fileIndex = buildSourceFileIndex(treeRoot, fsModule);
	const claims = docClaimExtractor.extractClaims(content);

	for(const claim of claims)
	{
		if(docClaimExtractor.isAllowlisted(claim, allowSet))
		{
			continue;
		}

		if(claim.type === 'npm-script')
		{
			if(npmScripts === null)
			{
				continue;
			}
			if(!npmScripts.has(claim.ref))
			{
				unresolved.push({line: claim.line, type: 'npm-script', claim: 'npm run ' + claim.ref});
			}
			continue;
		}

		const absPath = path.join(treeRoot, claim.ref);
		if(fsModule.existsSync(absPath))
		{
			continue;
		}
		try
		{
			const decoded = decodeURIComponent(claim.ref);
			if(decoded !== claim.ref && fsModule.existsSync(path.join(treeRoot, decoded)))
			{
				continue;
			}
		}
		catch(_e)
		{ /* invalid encoding */
		}
		if(!claim.ref.includes('/') && fileIndex.has(claim.ref))
		{
			continue;
		}

		unresolved.push({line: claim.line, type: claim.type, claim: claim.ref});
	}

	return unresolved;
}

/**
 * Source-side check — wraps findUnresolvedClaims in the docs:validate
 * issue shape ({file, line, severity, check, message}).
 *
 * @param {string} content - Markdown content
 * @param {string} filePath - File path (for error reporting)
 * @param {string} repoRoot - Source repo root
 * @param {Object} fsModule - File system module (for testing)
 * @param {string[]} [allowlist] - Allowlist entries
 * @returns {Array} Issue objects
 */
function checkProseFileRefs(content, filePath, repoRoot, fsModule, allowlist)
{
	const unresolved = findUnresolvedClaims(content, repoRoot, fsModule, allowlist);
	return unresolved.map(u => ({
		file: filePath,
		line: u.line,
		severity: 'error',
		check: 'prose-file-ref',
		message: u.type === 'npm-script' ? `npm script not found in package.json: \`${u.claim}\`` : `${u.type} reference not found in source: \`${u.claim}\``
	}));
}

// The committed Apex classes and triggers that back a guide's code fences live here.
const FAST_START_CLASS_DIR = 'release-testing/subscriber/classes';

// Lines that introduce a full-file code fence the reader copies verbatim.
// Each captures the named file (basename resolved against FAST_START_CLASS_DIR).
const FENCE_FILE_PROSE_PATTERNS = [
	/create a new file named `([^`]+\.(?:cls|trigger))`/i,
	/copy this code exactly as is into `([^`]+\.(?:cls|trigger))`/i,
	/(?:^|\s)create `([^`]+\.(?:cls|trigger))`/i
];

// Max line gap between the "create this file" prose and its fence. Guards
// against pairing the prose with a distant, unrelated fence when the immediate
// full-file fence is absent.
const FENCE_PROSE_MAX_GAP = 12;

// A one-line text fence naming the Apex file the step shape asks the reader to fill. Any name: when a file of that name
// is committed under FAST_START_CLASS_DIR, the fence that follows is compared with it; otherwise the reader creates the
// file and nothing is compared.
const STEP_PATH_FENCE = /^force-app\/main\/default\/(?:classes|triggers)\/([A-Za-z0-9_]+\.(?:cls|trigger))$/;

/**
 * Truncates a line at its first `//` line comment, honouring single-quoted
 * Apex strings so a `//` inside a literal (e.g. `'https://example.com'`) is
 * not mistaken for a comment.
 *
 * @param {string} line - One source line
 * @returns {string} The line up to (not including) a real `//` comment
 */
function stripInlineApexComment(line)
{
	let inString = false;
	for(let i = 0; i < line.length; i++)
	{
		const c = line[i];
		if(inString)
		{
			if(c === '\\')
			{
				i++;
				continue;
			}
			if(c === '\'')
			{
				inString = false;
			}
			continue;
		}
		if(c === '\'')
		{
			inString = true;
			continue;
		}
		if(c === '/' && line[i + 1] === '/')
		{
			return line.slice(0, i);
		}
	}
	return line;
}

/**
 * Reduces an Apex/trigger source body to its comparable code lines for
 * subset-parity. Each line becomes a whitespace-free key plus its readable
 * text. The reductions strip everything that legitimately differs between a
 * teaching fence and its committed-and-hardened artifact:
 *   - block comments (ApexDoc headers, incl. SPDX `// …` and `@date` lines)
 *     and `//` line/trailing comments
 *   - the no-op `seeAllData=false` default, in any letter case (artifacts state
 *     it explicitly; the teaching fence omits it — behaviourally identical)
 *   - ALL whitespace (indentation + the IDE formatter's continuation spacing,
 *     which touches the committed .cls but never the markdown fence)
 *   - Allman brace style: a lone `{` the formatter drops onto its own line in
 *     the committed .cls is re-attached to the previous line, so it matches a
 *     fence that writes `…{` inline (e.g. `new Map<String, String>{`)
 *   - `global` vs `public`: a documented, context-dependent visibility choice,
 *     not copied logic. The Fast Starts teach `global` (the managed package
 *     resolves the class at runtime with no extra setup); the release-testing
 *     artifacts use `public` with the harness's Type Resolver. The "Why
 *     global?" callouts present these as equivalent alternatives.
 *   - a trigger's event list: explicitly the reader's choice ("declare the
 *     events you need"), whereas the shared release-testing trigger handles
 *     every event. Compared on trigger name + object, not the event set.
 *   - blank / comment-only lines
 *
 * @param {string} source - Raw source body
 * @returns {Array<{key: string, text: string}>} Non-empty code lines
 */
function apexCodeLines(source)
{
	const withoutBlockComments = source
	.replace(/\r\n/g, '\n')
	.replace(/\/\*[\s\S]*?\*\//g, '')
	.replace(/\n[ \t]*\{/g, ' {');
	const out = [];
	for(const raw of withoutBlockComments.split('\n'))
	{
		const text = stripInlineApexComment(raw).trim();
		const key = text
		.replace(/^global(\s)/, 'public$1')
		.replace(/^(trigger\s+\w+\s+on\s+\w+\s*\()[^)]*\)/i, '$1)')
		.replace(/\bseeAllData\s*=\s*false\b,?/gi, '')
		.replace(/\s+/g, '');
		if(key.length > 0)
		{
			out.push({key, text});
		}
	}
	return out;
}

/**
 * Fast Start fence↔file parity (subset model). Each Fast Start doc tells the
 * reader to create an Apex file and shows the body in the next code fence; the
 * repo also commits that file under release-testing/subscriber/classes/ as a
 * compile-and-test-backed reference. The committed artifact is deliberately a
 * hardened SUPERSET of the teaching fence — it may carry extra test methods,
 * validation-rule bypasses, and explicit annotations the lean fence omits.
 *
 * So the contract is subset, not equality: every code line a reader copies
 * from the fence must be backed by the committed artifact. The check errors
 * only when the fence teaches a code line the artifact does not contain (the
 * reader would be copying untested/divergent code), after the normalisation in
 * apexCodeLines (comments, indentation, formatter spacing, seeAllData=false).
 *
 * The old "create this file" wording is read only in `Fast Start - *.md` docs. The step shape is read in every guide:
 * a one-line `text` fence naming an Apex file, followed by the code fence. A named file with no committed
 * counterpart is skipped (the reader creates it, so there is nothing to compare).
 *
 * @param {string} content - Markdown content
 * @param {string} filePath - File path (for error reporting + Fast Start gate)
 * @param {string} repoRoot - Source repo root
 * @param {Object} [fsModule=fs] - File system module (for testing)
 * @returns {Array} Issue objects (check: 'fence-file-parity')
 */
function checkFenceFileParity(content, filePath, repoRoot, fsModule = fs)
{
	const issues = [];
	const blocks = parseCodeBlocks(content);
	const lines = /^Fast Start - .+\.md$/.test(path.basename(filePath)) ? content.split('\n') : [];

	for(let i = 0; i < lines.length; i++)
	{
		let named = null;
		for(const re of FENCE_FILE_PROSE_PATTERNS)
		{
			const m = lines[i].match(re);
			if(m)
			{
				named = m[1];
				break;
			}
		}
		if(!named)
		{
			continue;
		}

		const proseLine = i + 1;
		const basename = path.basename(named);
		const fence = blocks.find(b => b.startLine > proseLine && (b.startLine - proseLine) <= FENCE_PROSE_MAX_GAP);
		if(!fence)
		{
			continue;
		}

		issues.push(...compareFenceWithCommittedFile(fence, basename, filePath, repoRoot, fsModule));
	}

	for(let index = 0; index < blocks.length - 1; index++)
	{
		const pathMatch = blocks[index].lang === 'text' ? blocks[index].code.trim().match(STEP_PATH_FENCE) : null;
		const fence = blocks[index + 1];
		if(!pathMatch || (fence.startLine - blocks[index].endLine) > FENCE_PROSE_MAX_GAP)
		{
			continue;
		}

		issues.push(...compareFenceWithCommittedFile(fence, pathMatch[1], filePath, repoRoot, fsModule));
	}

	return issues;
}

/**
 * Compares one teaching fence with the committed release-testing file of that name, as the subset contract in
 * checkFenceFileParity describes. Returns no issue when the file is not committed.
 *
 * @param {Object} fence - The code block the reader copies
 * @param {string} basename - The committed file's name
 * @param {string} filePath - File path (for error reporting)
 * @param {string} repoRoot - Source repo root
 * @param {Object} fsModule - File system module
 * @returns {Array} At most one issue (check: 'fence-file-parity')
 */
function compareFenceWithCommittedFile(fence, basename, filePath, repoRoot, fsModule)
{
	const committedPath = path.join(repoRoot, FAST_START_CLASS_DIR, basename);
	if(!fsModule.existsSync(committedPath))
	{
		return [];
	}

	const fileKeys = new Set(apexCodeLines(fsModule.readFileSync(committedPath, 'utf8')).map(l => l.key));
	const unbacked = apexCodeLines(fence.code).find(l => !fileKeys.has(l.key));
	if(!unbacked)
	{
		return [];
	}

	return [{
		file: filePath,
		line: fence.startLine,
		severity: 'error',
		check: 'fence-file-parity',
		message: `code fence teaches a line not backed by committed reference ${FAST_START_CLASS_DIR}/${basename} `
			+ `(the artifact may add to the fence, but must contain everything in it); unbacked line: \`${unbacked.text}\``
	}];
}

/**
 * Walks every *.md file in `mirrorDir`, runs the shared findUnresolvedClaims
 * against the tree, and returns a flat deterministically-sorted violation
 * list. Consumed by the release build pipeline.
 *
 * @param {string} mirrorDir - Path to the staged release artifact
 * @param {string[]} allowlist - manifest.doc_claim_allowlist entries
 * @returns {Array<{file: string, line: number, type: string, claim: string}>}
 */
function validateReleaseDocs(mirrorDir, allowlist)
{
	const violations = [];
	const mdFiles = [];
	(function walk(d)
	{
		for(const entry of fs.readdirSync(d, {withFileTypes: true}))
		{
			if(entry.name === 'node_modules' || entry.name === '.git')
			{
				continue;
			}
			const full = path.join(d, entry.name);
			if(entry.isDirectory())
			{
				walk(full);
			}
			else if(entry.isFile() && entry.name.endsWith('.md'))
			{
				mdFiles.push(full);
			}
		}
	})(mirrorDir);

	for(const mdFile of mdFiles)
	{
		const relFile = path.relative(mirrorDir, mdFile);
		const content = fs.readFileSync(mdFile, 'utf8');
		const unresolved = findUnresolvedClaims(content, mirrorDir, fs, allowlist);
		for(const u of unresolved)
		{
			violations.push({file: relFile, line: u.line, type: u.type, claim: u.claim});
		}
	}

	violations.sort((a, b) =>
	{
		if(a.file !== b.file)
		{
			return a.file < b.file ? -1 : 1;
		}
		if(a.line !== b.line)
		{
			return a.line - b.line;
		}
		return a.claim < b.claim ? -1 : 1;
	});

	return violations;
}

/**
 * @description Checks that the "is it released" lines agree with the record of promoted versions
 *              (`release-testing/released-versions.json`, written by `scripts/promote-package.js`). For each
 *              recorded version from the promote script's `FIRST_CHECKED_VERSION` on, the release note of its
 *              minor line must have a `**Release status:**` line that opens with "released." and names the build,
 *              with no pre-release wording or build-number placeholder left. Notes for older versions are
 *              published history and are not checked. And the newest recorded version must be the one CLAUDE.md's Package status sentence names as the
 *              released line. A release note for a minor with no recorded version is not checked. The record
 *              never ships to the published repository, so there the check finds nothing to do.
 * @param {string} repoRoot - The repository root.
 * @param {Object} [fsModule] - File system module (for testing).
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>} One error per problem.
 */
function checkReleaseStatus(repoRoot, fsModule = fs)
{
	const recordPath = path.join(repoRoot, 'release-testing', 'released-versions.json');
	if(!fsModule.existsSync(recordPath))
	{
		return [];
	}
	// Loaded only here: the published repository ships this file but neither the record nor the promote script.
	const releaseStatus = require('./promote-package');
	const entries = releaseStatus.readReleasedVersions(recordPath, fsModule);
	const issues = [];
	const error = (file, line, message) => issues.push({file, line, severity: 'error', check: 'release-status', message});

	for(const entry of entries.filter(recorded => releaseStatus.isCheckedVersion(recorded.version)))
	{
		const notePath = releaseStatus.releaseNotePath(entry.version);
		if(!fsModule.existsSync(path.join(repoRoot, notePath)))
		{
			error(releaseStatus.RECORD_RELATIVE_PATH, 1, `${entry.version} is recorded as released, but ${notePath} does not exist`);
			continue;
		}
		const {line, problems} = releaseStatus.findReleaseStatusProblems(fsModule.readFileSync(path.join(repoRoot, notePath), 'utf8'), entry.version);
		for(const problem of problems)
		{
			error(notePath, line, problem);
		}
	}

	const claudePath = path.join(repoRoot, 'CLAUDE.md');
	const newest = releaseStatus.findNewestEntry(entries);
	if(newest && fsModule.existsSync(claudePath))
	{
		const named = releaseStatus.readReleasedLineFromClaude(fsModule.readFileSync(claudePath, 'utf8'));
		if(!named)
		{
			error('CLAUDE.md', 1, `has no "**Package status:** Kern X.Y.Z-N is the released line" sentence; the newest released version is ${newest.version}`);
		}
		else if(named.version !== newest.version)
		{
			error('CLAUDE.md', named.line, `**Package status:** names ${named.version} as the released line, but the newest released version in ${releaseStatus.RECORD_RELATIVE_PATH} is ${newest.version}`);
		}
	}
	return issues;
}

// ─────────────────────────────────────────────────────────────────────────────
// DocsValidator Class
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Orchestrates documentation validation
 */
class DocsValidator
{
	/**
	 * @param {Object} [options] - Configuration options
	 * @param {string} [options.docsDir] - Directory containing guide docs
	 * @param {string} [options.classesDir] - Directory containing Apex classes
	 * @param {string} [options.referenceDir] - Directory containing reference docs
	 * @param {RegExp} [options.includePattern] - File include pattern
	 * @param {RegExp} [options.excludePattern] - File exclude pattern
	 * @param {string[]} [options.overrideFiles] - Explicit file paths (bypasses discovery)
	 * @param {boolean} [options.silent] - Suppress logging
	 * @param {Object} [options.fs] - File system module (for testing)
	 */
	constructor(options = {})
	{
		this.config = {...DEFAULT_CONFIG, ...options};
		this.log = createLogger(options.silent);
		this.fs = options.fs || fs;
	}

	/**
	 * Resolves the list of files to validate.
	 * If overrideFiles is set, returns those files directly (bypasses discovery).
	 * @returns {string[]} Absolute file paths
	 */
	getFiles()
	{
		if(this.config.overrideFiles && this.config.overrideFiles.length > 0)
		{
			return this.config.overrideFiles
			.map(f => path.resolve(f))
			.filter(f => this.fs.existsSync(f));
		}

		const docsDir = path.resolve(this.config.docsDir);

		if(!this.fs.existsSync(docsDir))
		{
			return [];
		}

		const files = this.fs.readdirSync(docsDir);
		const docFiles = files
		.filter(f => f.endsWith('.md'))
		.filter(f => this.config.includePattern.test(f))
		.filter(f => !this.config.excludePattern.test(f))
		.filter(f => !(this.config.internalDocs || []).includes(f))
		.sort()
		.map(f => path.join(docsDir, f));

		const extraFiles = (this.config.extraFiles || [])
		.map(f => path.resolve(f))
		.filter(f => this.fs.existsSync(f));

		const extraDirFiles = [];
		for(const dir of (this.config.extraDirs || []))
		{
			const dirPath = path.resolve(dir);
			if(this.fs.existsSync(dirPath))
			{
				const dirFiles = this.fs.readdirSync(dirPath)
				.filter(f => f.endsWith('.md'))
				.sort()
				.map(f => path.join(dirPath, f));
				extraDirFiles.push(...dirFiles);
			}
		}

		return [
			...docFiles,
			...extraFiles,
			...extraDirFiles
		];
	}

	/**
	 * Runs all validation checks on all target files
	 * @returns {{issues: Array, summary: {files: number, errors: number, warnings: number, duration: number}}}
	 */
	validate()
	{
		const startTime = Date.now();
		const files = this.getFiles();
		const classIndex = buildClassIndex(path.resolve(this.config.classesDir), path.resolve(this.config.referenceDir), this.fs);
		const globalClassIndex = buildGlobalClassIndex(path.resolve(this.config.referenceDir), this.fs);
		const globalMemberIndex = buildGlobalMemberIndex(path.resolve(this.config.referenceDir), this.fs);
		let allIssues = [];

		this.log.info('docs:validate \u2014 Documentation Validation\n');
		this.log.info(`Checking ${files.length} files...\n`);

		const repoRoot = path.resolve(this.config.docsDir, '..');
		const allFileContents = [];
		const stepShapeRoster = JSON.parse(this.fs.readFileSync(path.join(__dirname, 'step-shaped-guides.json'), 'utf8'));
		const platformPairs = JSON.parse(this.fs.readFileSync(path.join(__dirname, 'platform-specific-blocks.json'), 'utf8'));
		for(const filePath of files)
		{
			const content = this.fs.readFileSync(filePath, 'utf8');
			allFileContents.push({filePath, content});
			const fileName = path.relative(path.resolve(this.config.docsDir), filePath);
			const fileIssues = [
				...checkLinks(content, filePath, this.fs),
				...checkAntiPatterns(content, filePath),
				...checkOldNaming(content, filePath),
				...checkSharingDeclarations(content, filePath),
				...checkToc(content, filePath),
				...checkCodeFenceLanguages(content, filePath),
				...checkClassReferences(content, filePath, classIndex, globalClassIndex),
				...scanMemberReferences(content, filePath, globalMemberIndex),
				...checkLineLength(content, filePath),
				...checkTableAlignment(content, filePath),
				...checkProseFileRefs(content, filePath, repoRoot, this.fs, this.config.proseRefAllowlist),
				...checkFenceFileParity(content, filePath, repoRoot, this.fs),
				...checkStepShape(content, path.relative(repoRoot, filePath).split(path.sep).join('/'), {roster: stepShapeRoster, allowList: platformPairs})
			];

			fileIssues.sort((a, b) => a.line - b.line);

			if(fileIssues.length > 0)
			{
				this.log.file(`docs/${fileName}`);
				for(const issue of fileIssues)
				{
					this.log.issue(issue.line, issue.severity, issue.check, issue.message);
				}
			}

			allIssues = allIssues.concat(fileIssues);
		}

		const stepShapeIo = {
			exists: relative => this.fs.existsSync(path.join(repoRoot, relative)),
			read: relative => this.fs.readFileSync(path.join(repoRoot, relative), 'utf8'),
			generated: fs.existsSync(path.join(__dirname, 'build-distribution.js'))
				? {'INSTALL-PIPELINE.md': () => require('./build-distribution').synthInstallPipeline({version: '1.0.0-117'})}
				: {},
			note: line => this.log.info(line)
		};
		const stepShapeIssues = [...checkSurfaces(stepShapeRoster, platformPairs, stepShapeIo), ...checkRoster(stepShapeRoster, platformPairs, stepShapeIo)];
		for(const issue of stepShapeIssues)
		{
			this.log.file(issue.file);
			this.log.issue(issue.line, issue.severity, issue.check, issue.message);
		}
		allIssues = allIssues.concat(stepShapeIssues);

		// Cross-file check: every Kern@X.Y.Z-N reference across the doc set
		// should agree. CHANGELOG + release-notes are exempt because they
		// legitimately name historical versions.
		const crossDocAllowed = this.config.crossDocVersionAllowedPatterns || [
			/\/CHANGELOG\.md$/i,
			/\/release-notes\//i,
			/Release Notes -/i
		];
		const crossDocIssues = checkCrossDocVersionConsistency(allFileContents, crossDocAllowed);
		if(crossDocIssues.length > 0)
		{
			const grouped = new Map();
			for(const issue of crossDocIssues)
			{
				if(!grouped.has(issue.filePath))
				{
					grouped.set(issue.filePath, []);
				}
				grouped.get(issue.filePath).push(issue);
			}
			for(const [filePath, issues] of grouped)
			{
				const fileName = path.relative(path.resolve(this.config.docsDir), filePath);
				this.log.file(`docs/${fileName}`);
				for(const issue of issues)
				{
					this.log.issue(issue.line, issue.severity, issue.check, issue.message);
				}
			}
			allIssues = allIssues.concat(crossDocIssues);
		}

		// Release status: every promoted version's release note must say it is released, and CLAUDE.md
		// must name the newest one. A run on named files only checks those files, so it skips this. The check
		// reads its own files from disk (the record, the notes, CLAUDE.md), not the scanned doc set.
		if(!this.config.overrideFiles || this.config.overrideFiles.length === 0)
		{
			const releaseStatusIssues = checkReleaseStatus(repoRoot);
			for(const issue of releaseStatusIssues)
			{
				this.log.file(issue.file);
				this.log.issue(issue.line, issue.severity, issue.check, issue.message);
			}
			allIssues = allIssues.concat(releaseStatusIssues);
		}

		// Source-side leg of the member check: ApexDoc on a global member is copied onto the
		// reference page verbatim, so it ships to subscribers and is held to the same bar.
		const apexDocIssues = checkApexDocMemberReferences(path.resolve(this.config.classesDir), globalMemberIndex, this.fs);
		this.reportApexDocIssues(apexDocIssues);
		allIssues = allIssues.concat(apexDocIssues);

		const duration = Date.now() - startTime;
		const errors = allIssues.filter(i => i.severity === 'error').length;
		const warnings = allIssues.filter(i => i.severity === 'warning').length;

		return {
			issues: allIssues, summary: {
				files: files.length, errors, warnings, duration
			}
		};
	}

	/**
	 * Prints the ApexDoc member issues, grouped by the class file that carries them. Those issues
	 * come from the source tree rather than a scanned doc, so they are reported after the per-file
	 * pass under their own headings.
	 *
	 * @param {Array<{file: string, line: number, severity: string, check: string, message: string}>} issues
	 * @returns {void}
	 */
	reportApexDocIssues(issues)
	{
		const grouped = new Map();

		for(const issue of issues)
		{
			if(!grouped.has(issue.file))
			{
				grouped.set(issue.file, []);
			}
			grouped.get(issue.file).push(issue);
		}

		for(const [classFile, classIssues] of grouped)
		{
			this.log.file(classFile);
			for(const issue of classIssues)
			{
				this.log.issue(issue.line, issue.severity, issue.check, issue.message);
			}
		}
	}

	/**
	 * Standardises TOCs across all target files
	 * @returns {{filesChanged: number, totalH4Removed: number}}
	 */
	fixTocs()
	{
		const allFiles = this.getFiles();
		const fixExclude = this.config.fixTocExcludePattern;
		const files = allFiles.filter(f => !fixExclude || !fixExclude.test(path.basename(f)));
		let filesChanged = 0;
		let totalH4Removed = 0;

		this.log.info('docs:validate --fix-toc \u2014 TOC Standardisation\n');
		this.log.info(`Processing ${files.length} files (${allFiles.length - files.length} excluded)...\n`);

		for(const filePath of files)
		{
			const content = this.fs.readFileSync(filePath, 'utf8');
			const headings = parseHeadings(content);
			const result = rewriteToc(content, headings);
			const fileName = path.relative(path.resolve(this.config.docsDir), filePath);

			if(result.changed)
			{
				this.fs.writeFileSync(filePath, result.content);
				filesChanged++;
				totalH4Removed += result.h4Removed;
				this.log.success(`  ${fileName} (${result.h4Removed} H4 entries removed)`);
			}
			else
			{
				this.log.info(`  ${fileName} (no changes)`);
			}
		}

		this.log.info('');
		this.log.success(`Done: ${filesChanged} files updated, ${totalH4Removed} H4 entries removed`);

		return {filesChanged, totalH4Removed};
	}

	/**
	 * Formats the validation summary as a string
	 * @param {{summary: {files: number, errors: number, warnings: number, duration: number}}} result
	 * @returns {string}
	 */
	formatReport(result)
	{
		const {files, errors, warnings, duration} = result.summary;
		const time = (duration / 1000).toFixed(2);
		return `\nSummary: ${warnings} warnings, ${errors} errors in ${files} files (${time}s)`;
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Fast Start Gate (subscriber-org validation)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Mapping of Fast Start doc topic (lower-kebab) to: doc filename, DEMO class
 * basename, and wave assignment. Source of truth for --fast-start-gate flags.
 */
const FAST_START_TOPICS = [
	{topic: 'selectors', doc: 'Fast Start - Selectors.md', demo: 'FastStart_Selectors_DEMO', wave: 1},
	{topic: 'dml', doc: 'Fast Start - DML.md', demo: 'FastStart_DML_DEMO', wave: 1},
	{topic: 'test-data', doc: 'Fast Start - Test Data.md', demo: 'FastStart_TestData_DEMO', wave: 1},
	{topic: 'logging', doc: 'Fast Start - Logging.md', demo: 'FastStart_Logging_DEMO', wave: 1},
	{topic: 'feature-flags', doc: 'Fast Start - Feature Flags.md', demo: 'FastStart_FeatureFlag_DEMO', wave: 1},
	{topic: 'outbound-apis', doc: 'Fast Start - Outbound APIs.md', demo: 'FastStart_OutboundAPI_DEMO', wave: 1},
	{topic: 'inbound-apis', doc: 'Fast Start - Inbound APIs.md', demo: 'FastStart_InboundAPI_DEMO', wave: 2},
	{topic: 'trigger-actions', doc: 'Fast Start - Trigger Actions.md', demo: 'FastStart_TriggerAction_DEMO', wave: 2},
	{topic: 'validations', doc: 'Fast Start - Custom Validations.md', demo: 'FastStart_Validation_DEMO', wave: 2},
	{topic: 'async', doc: 'Fast Start - Async Processing.md', demo: 'FastStart_AsyncChain_DEMO', wave: 2},
	{topic: 'scheduled-jobs', doc: 'Fast Start - Scheduled Jobs.md', demo: 'FastStart_ScheduledJob_DEMO', wave: 2},
	{topic: 'e2e-testing', doc: 'Fast Start - E2E Testing.md', demo: 'FastStart_E2E_DEMO', wave: 2},
	{topic: 'code-scanning', doc: 'Fast Start - Code Scanning.md', demo: 'FastStart_Scanner_DEMO', wave: 2, noTestClass: true}
];

/** Subscriber test org alias — matches release-testing/RUNBOOK.md.
 *  Deferred so `docs:validate` (which doesn't talk to any org) works in
 *  subscriber clones without SF_SUBSCRIBER_ORG_ALIAS set. The fast-start
 *  gate path that actually deploys to an org calls getFastStartOrg() at
 *  invocation time and gets the env-var-required behavior. */
const {getSubscriberOrgAlias} = require('../release-testing/runner/subscriber-config');

function getFastStartOrg()
{
	return getSubscriberOrgAlias();
}

/** Subscriber project root (namespace-free sfdx-project.json) */
const FAST_START_STAGING_ROOT = path.join('/tmp', 'kern-subscriber');

/** Source location of FastStart_* artifacts (subscriber-context files) */
const FAST_START_SOURCE_ROOT = path.resolve('./release-testing/subscriber');

/** Source location of Tier 1 anonymous Apex scripts */
const FAST_START_SCRIPTS_ROOT = path.resolve('./release-testing/scripts');

/**
 * Looks up a topic record by topic string. Throws with a helpful message if unknown.
 * @param {string} topic - lower-kebab-case topic key
 * @returns {Object} record from FAST_START_TOPICS
 */
function fastStartLookup(topic)
{
	const record = FAST_START_TOPICS.find(t => t.topic === topic);
	if(!record)
	{
		const valid = FAST_START_TOPICS.map(t => t.topic).join(', ');
		throw new Error(`Unknown fast-start topic '${topic}'. Valid topics: ${valid}`);
	}
	return record;
}

/**
 * Stages FastStart_<Topic>* artifacts from release-testing/subscriber/ into
 * /tmp/kern-subscriber/force-app/main/default/ so they can be deployed to the
 * subscriber org without conflicting with the project's namespaced source tree.
 * @param {Object} record - topic record from FAST_START_TOPICS
 * @param {Object} log - logger
 * @returns {string[]} relative paths copied (empty if no artifacts found)
 */
function stageFastStartArtifacts(record, log)
{
	const stagingForceApp = path.join(FAST_START_STAGING_ROOT, 'force-app', 'main', 'default');
	if(!fs.existsSync(FAST_START_STAGING_ROOT))
	{
		throw new Error(`Staging root missing: ${FAST_START_STAGING_ROOT}. Provision with release-testing/RUNBOOK.md Phase 1.`);
	}
	for(const sub of [
		'classes',
		'customMetadata',
		'flows',
		'lwc',
		'triggers'
	])
	{
		fs.mkdirSync(path.join(stagingForceApp, sub), {recursive: true});
	}

	// Clear ALL existing FastStart_* artifacts from staging so each iteration only
	// deploys files for the current topic. This prevents one topic's bad files from
	// poisoning subsequent iterations' deploys (the cascade trap).
	for(const sub of [
		'classes',
		'customMetadata',
		'flows',
		'lwc',
		'triggers'
	])
	{
		const dir = path.join(stagingForceApp, sub);
		if(!fs.existsSync(dir))
		{
			continue;
		}
		for(const entry of fs.readdirSync(dir))
		{
			if(/^FastStart_/i.test(entry) || /^kern__\w+\.FastStart_/i.test(entry))
			{
				const full = path.join(dir, entry);
				const stat = fs.statSync(full);
				if(stat.isDirectory())
				{
					fs.rmSync(full, {recursive: true, force: true});
				}
				else
				{
					fs.unlinkSync(full);
				}
			}
		}
	}

	const copied = [];
	// Per-topic CMDT-filename patterns. Files in release-testing/subscriber/customMetadata/
	// follow Salesforce convention: kern__<CmdtType>.<RecordDeveloperName>.md-meta.xml
	const topicShortName = record.demo.replace(/_DEMO$/, '');
	const cmdtPatterns = {
		'feature-flags': /^kern__FeatureFlag\.FastStart_/i,
		'outbound-apis': /^kern__(ApiSetting|ApiCredential|ApiMock)\.FastStart_/i,
		'inbound-apis': /^kern__(ApiSetting|ApiMock)\.FastStart_/i,
		'trigger-actions': /^kern__(TriggerSetting|TriggerAction)\.FastStart_/i,
		'validations': /^kern__(ValidationRule|ValidationRuleGroup)\.FastStart_/i,
		'async': /^kern__AsynchronousJobSetting\.FastStart_/i
	};
	const cmdtPattern = cmdtPatterns[record.topic] || new RegExp(`^kern__\\w+\\.${topicShortName}\\.`, 'i');

	const buckets = [
		{src: path.join(FAST_START_SOURCE_ROOT, 'classes'), pattern: new RegExp(`^${record.demo}(_TEST)?\\.(cls|cls-meta\\.xml)$`), dst: path.join(stagingForceApp, 'classes')},
		{src: path.join(FAST_START_SOURCE_ROOT, 'customMetadata'), pattern: cmdtPattern, dst: path.join(stagingForceApp, 'customMetadata')},
		{
			src: path.join(FAST_START_SOURCE_ROOT, 'triggers'),
			pattern: new RegExp(`^${topicShortName}.*\\.(trigger|trigger-meta\\.xml)$`, 'i'),
			dst: path.join(stagingForceApp, 'triggers')
		}
	];

	for(const bucket of buckets)
	{
		if(!fs.existsSync(bucket.src))
		{
			continue;
		}
		const entries = fs.readdirSync(bucket.src).filter(f => bucket.pattern.test(f));
		for(const entry of entries)
		{
			fs.copyFileSync(path.join(bucket.src, entry), path.join(bucket.dst, entry));
			copied.push(path.relative(FAST_START_STAGING_ROOT, path.join(bucket.dst, entry)));
		}
	}

	if(log)
	{
		log.info(`Staged ${copied.length} artifact(s) for ${record.demo}`);
	}
	return copied;
}

/**
 * Deploys a staged subset to the subscriber org. Throws on deploy failure.
 * @param {Object} log - logger
 * @returns {{success: boolean, output: string}}
 */
function deployFastStartStaging(log)
{
	const org = getFastStartOrg();
	const cmd = `sf project deploy start -o ${org} -d force-app/main/default --ignore-conflicts --json`;
	if(log)
	{
		log.info(`Deploying staged artifacts to ${org}...`);
	}
	const result = spawnSync('bash', [
		'-lc',
		cmd
	], {cwd: FAST_START_STAGING_ROOT, encoding: 'utf8', maxBuffer: 50 * 1024 * 1024});
	const output = (result.stdout || '') + (result.stderr || '');
	if(result.status !== 0)
	{
		return {success: false, output};
	}
	return {success: true, output};
}

/**
 * Runs Apex tests for the given DEMO_TEST class against the subscriber org and
 * parses the JSON result. Returns {success, testsPassed, testsFailed, coveragePct,
 * coverageDetail, raw}.
 * @param {string} demoClass - DEMO class basename (e.g. "FastStart_Selectors_DEMO")
 * @param {Object} log - logger
 */
function runDemoTest(demoClass, log)
{
	const testClass = `${demoClass}_TEST`;
	const org = getFastStartOrg();
	const cmd = `sf apex run test -o ${org} --tests ${testClass} --code-coverage --synchronous --result-format json --wait 10`;
	if(log)
	{
		log.info(`Running ${testClass} on ${org}...`);
	}
	const result = spawnSync('bash', [
		'-lc',
		cmd
	], {encoding: 'utf8', maxBuffer: 50 * 1024 * 1024});
	const stdout = result.stdout || '';

	let parsed = null;
	try
	{
		parsed = JSON.parse(stdout);
	}
	catch(e)
	{
		return {success: false, testsPassed: 0, testsFailed: 0, coveragePct: 0, raw: stdout, error: `JSON parse failed: ${e.message}`};
	}

	const summary = parsed.result?.summary || parsed.summary || {};
	const tests = parsed.result?.tests || parsed.tests || [];
	const coverageEntries = parsed.result?.coverage?.coverage || parsed.result?.codecoverage || [];

	const testsPassed = parseInt(summary.passing || tests.filter(t => t.Outcome === 'Pass').length, 10) || 0;
	const testsFailed = parseInt(summary.failing || tests.filter(t => t.Outcome === 'Fail').length, 10) || 0;

	const demoCoverage = coverageEntries.find(c =>
	{
		const name = (c.name || c.ApexClassOrTriggerName || '').replace(/^kern__/, '');
		return name === demoClass;
	});
	let coveragePct = 0;
	if(demoCoverage)
	{
		if(typeof demoCoverage.coveredPercent === 'number')
		{
			coveragePct = demoCoverage.coveredPercent;
		}
		else if(demoCoverage.totalLines)
		{
			coveragePct = (demoCoverage.totalCovered / demoCoverage.totalLines) * 100;
		}
		else if(demoCoverage.NumLinesCovered != null && demoCoverage.NumLinesUncovered != null)
		{
			const total = demoCoverage.NumLinesCovered + demoCoverage.NumLinesUncovered;
			coveragePct = total > 0 ? (demoCoverage.NumLinesCovered / total) * 100 : 0;
		}
	}

	const success = testsFailed === 0 && testsPassed > 0 && coveragePct >= 100;
	return {success, testsPassed, testsFailed, coveragePct, coverageDetail: demoCoverage, raw: stdout};
}

/**
 * Runs Tier 1 anonymous Apex script for a topic if present. Treats stderr-pattern
 * "Execution failed|FATAL|EXCEPTION" as a failure signal.
 * @param {string} topic
 * @param {Object} log
 * @returns {{ran: boolean, success: boolean, output: string}}
 */
function runFastStartAnonScript(topic, log)
{
	const scriptPath = path.join(FAST_START_SCRIPTS_ROOT, `fast-start-${topic}.apex`);
	if(!fs.existsSync(scriptPath))
	{
		return {ran: false, success: true, output: ''};
	}
	const cmd = `sf apex run -o ${getFastStartOrg()} -f '${scriptPath}'`;
	if(log)
	{
		log.info(`Running anonymous Apex: ${path.basename(scriptPath)}`);
	}
	const result = spawnSync('bash', [
		'-lc',
		`${cmd} 2>&1`
	], {encoding: 'utf8', maxBuffer: 50 * 1024 * 1024});
	const output = result.stdout || '';
	const failed = /Execution failed|FATAL_ERROR|EXCEPTION_THROWN/.test(output);
	return {ran: true, success: !failed && result.status === 0, output};
}

/**
 * Runs the fast-start-gate on a single topic.
 * Exit-code contract: 0 pass, 1 test/coverage fail, 2 deploy fail,
 * 3 anonymous Apex fail, 4 structural validate fail.
 */
function fastStartGateDoc(topic, options, log)
{
	const record = fastStartLookup(topic);
	log.file(`Fast Start Gate — ${record.doc} → ${record.demo} (Wave ${record.wave})`);

	const docPath = path.join('docs', record.doc);
	if(!fs.existsSync(docPath))
	{
		log.error(`Doc not found: ${docPath}`);
		return {exitCode: 4, topic, reason: 'doc-missing'};
	}

	// Step 1: structural validation (reuse existing checks).
	const validator = new DocsValidator({overrideFiles: [docPath], silent: true});
	const structural = validator.validate();
	const structuralErrors = structural.summary.errors;
	if(structuralErrors > 0 && !options.allowStructuralWarnings)
	{
		log.error(`Structural check failed: ${structuralErrors} error(s)`);
		for(const issue of structural.issues.filter(i => i.severity === 'error'))
		{
			log.issue(issue.line, issue.severity, issue.check, issue.message);
		}
		return {exitCode: 4, topic, reason: 'structural', structuralErrors};
	}
	log.success(`Structural check passed (${structural.summary.warnings} warnings, ${structuralErrors} errors)`);

	if(options.extractOnly)
	{
		log.info('Extract-only mode: skipping deploy/test.');
		return {exitCode: 0, topic, reason: 'extract-only'};
	}

	// Step 2: stage + deploy.
	stageFastStartArtifacts(record, log);
	const deploy = deployFastStartStaging(log);
	if(!deploy.success)
	{
		log.error('Deploy failed:');
		log.error(deploy.output.slice(0, 2000));
		return {exitCode: 2, topic, reason: 'deploy', output: deploy.output};
	}
	log.success('Deploy succeeded.');

	// Step 3: run DEMO_TEST (skipped for topics with no test class — e.g. code-scanning DEMO is deliberately violating).
	let test = null;
	if(record.noTestClass)
	{
		log.info(`(No DEMO_TEST class for this topic by design — skipping test step.)`);
	}
	else
	{
		test = runDemoTest(record.demo, log);
		if(!test.success)
		{
			log.error(`Test/coverage fail: ${test.testsPassed} pass / ${test.testsFailed} fail / ${test.coveragePct.toFixed(1)}% coverage on ${record.demo}`);
			return {exitCode: 1, topic, reason: 'test-coverage', test};
		}
		log.success(`Tests passed: ${test.testsPassed}/${test.testsPassed} · coverage ${test.coveragePct.toFixed(1)}%`);
	}

	// Step 4: anonymous Apex script (Tier 1).
	const anon = runFastStartAnonScript(topic, log);
	if(anon.ran && !anon.success)
	{
		log.error('Tier 1 anonymous Apex failed:');
		log.error(anon.output.slice(0, 2000));
		return {exitCode: 3, topic, reason: 'anon-apex', anon};
	}
	if(anon.ran)
	{
		log.success('Tier 1 anonymous Apex clean.');
	}
	else
	{
		log.info('(No Tier 1 anonymous Apex script for this topic.)');
	}

	return {exitCode: 0, topic, reason: 'pass', test, anon};
}

/**
 * Runs the gate across a set of topics and reports per-doc + aggregate status.
 * @param {Object[]} topics - records from FAST_START_TOPICS
 * @param {Object} options
 * @param {Object} log
 */
function fastStartGateMulti(topics, options, log)
{
	const results = [];
	let worstExit = 0;
	for(const t of topics)
	{
		const r = fastStartGateDoc(t.topic, options, log);
		results.push(r);
		if(r.exitCode > worstExit)
		{
			worstExit = r.exitCode;
		}
	}

	log.file('Fast Start Gate — Summary');
	for(const r of results)
	{
		const marker = r.exitCode === 0 ? '\x1b[32m✓\x1b[0m' : '\x1b[31m✗\x1b[0m';
		const detail = r.exitCode === 0 ? (r.test ? `${r.test.testsPassed} pass · ${r.test.coveragePct.toFixed(1)}% coverage` : `deploy-only (no _TEST by design)`) : `${r.reason}`;
		console.log(`  ${marker} ${r.topic.padEnd(20)} ${detail}`);
	}

	return {exitCode: worstExit, results};
}

/**
 * Entry point dispatched from main() when --fast-start-gate is present.
 */
function fastStartGate(flags, fileArgs)
{
	const log = createLogger(false);
	const options = {
		extractOnly: flags.includes('--extract-only'), allowStructuralWarnings: !flags.includes('--strict-structural')
	};

	// Re-parse argv from scratch so we correctly read positional values that
	// follow --doc / --wave even when other --flags also appear in the list.
	const rawArgs = process.argv.slice(2);
	const positionalAfter = (flagName) =>
	{
		const idx = rawArgs.indexOf(flagName);
		if(idx < 0)
		{
			return null;
		}
		const next = rawArgs[idx + 1];
		if(!next || next.startsWith('--'))
		{
			return null;
		}
		return next;
	};

	if(flags.includes('--full'))
	{
		return fastStartGateMulti(FAST_START_TOPICS, options, log);
	}

	if(flags.includes('--wave'))
	{
		const waveArg = positionalAfter('--wave') || fileArgs[0];
		const waveNum = parseInt(waveArg, 10);
		if(!waveNum || (waveNum !== 1 && waveNum !== 2))
		{
			log.error('--wave requires 1 or 2');
			return {exitCode: 4};
		}
		return fastStartGateMulti(FAST_START_TOPICS.filter(t => t.wave === waveNum), options, log);
	}

	if(flags.includes('--doc'))
	{
		const topic = positionalAfter('--doc') || fileArgs[0];
		if(!topic)
		{
			log.error('--doc requires a topic key');
			return {exitCode: 4};
		}
		const r = fastStartGateDoc(topic, options, log);
		return {exitCode: r.exitCode, results: [r]};
	}

	log.error('--fast-start-gate requires one of: --doc <topic>, --wave <n>, --full');
	log.info(`Valid topics: ${FAST_START_TOPICS.map(t => t.topic).join(', ')}`);
	return {exitCode: 4};
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI Entry Point
// ─────────────────────────────────────────────────────────────────────────────

function main()
{
	const args = process.argv.slice(2);
	const flags = args.filter(a => a.startsWith('--'));
	const fileArgs = args.filter(a => !a.startsWith('--'));
	const options = fileArgs.length > 0 ? {overrideFiles: fileArgs} : {};

	if(flags.includes('--fix-toc'))
	{
		const validator = new DocsValidator(options);
		validator.fixTocs();
		return;
	}

	if(flags.includes('--fast-start-gate'))
	{
		const result = fastStartGate(flags, fileArgs);
		process.exit(result.exitCode);
	}

	const validator = new DocsValidator(options);
	const result = validator.validate();
	const report = validator.formatReport(result);

	if(result.summary.errors > 0)
	{
		validator.log.error(report);
		process.exit(1);
	}
	else
	{
		validator.log.success(report);
	}
}

if(require.main === module)
{
	main();
}

// ─────────────────────────────────────────────────────────────────────────────
// Exports for Testing
// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
	DocsValidator,
	internalDocsFrom,
	createLogger,
	parseCodeBlocks,
	parseHeadings,
	parseTocEntries,
	parseLinks,
	githubSlug,
	extractHeadingText,
	shouldExcludeH4,
	generateToc,
	rewriteToc,
	checkLinks,
	checkAntiPatterns,
	checkOldNaming,
	checkProseFileRefs,
	checkCrossDocVersionConsistency,
	checkReleaseStatus,
	checkFenceFileParity,
	checkStepShape,
	findUnresolvedClaims,
	validateReleaseDocs,
	DEFAULT_PROSE_REF_ALLOWLIST,
	checkSharingDeclarations,
	checkToc,
	checkCodeFenceLanguages,
	checkClassReferences,
	checkLineLength,
	checkTableAlignment,
	buildClassIndex,
	buildGlobalClassIndex,
	buildGlobalMemberIndex,
	scanProseClassReferences,
	scanMemberReferences,
	checkApexDocMemberReferences,
	KERN_CLASS_REF_EXCEPTIONS,
	KERN_MEMBER_REF_EXCEPTIONS,
	DEFAULT_CONFIG,
	MAX_LINE_LENGTH,
	SF_STANDARD_TYPES,
	KERN_PREFIXES,
	FAST_START_TOPICS,
	getFastStartOrg,
	fastStartLookup,
	fastStartGate,
	fastStartGateDoc,
	fastStartGateMulti,
	stageFastStartArtifacts,
	deployFastStartStaging,
	runDemoTest,
	runFastStartAnonScript
};
