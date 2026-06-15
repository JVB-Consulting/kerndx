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

const DEFAULT_CONFIG = {
	/** Directory containing guide docs */
	docsDir: './docs',

	/** Directory containing Apex class files */
	classesDir: './force-app/main/default/classes',

	/** Directory containing reference docs */
	referenceDir: './docs/reference/apex',

	/** File patterns to include */
	includePattern: /- Guide\.md$|Strategic Guide\.md$|AI Agent Instructions\.md$|Installation\.md$|Start Here\.md$|README\.md$|Glossary\.md$|Personas\.md$|^Fast Start/,

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
 * Parses code blocks from Markdown content
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

		if(!inBlock && /^```(\w*)/.test(line))
		{
			const lang = line.match(/^```(\w*)/)[1] || '';
			currentBlock = {lang, code: '', startLine: lineNum, endLine: lineNum};
			inBlock = true;
		}
		else if(inBlock && /^```\s*$/.test(line))
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
		if(link.href.startsWith('http://') || link.href.startsWith('https://'))
		{
			continue;
		}
		if(link.href.startsWith('#'))
		{
			continue;
		}

		let targetPath = link.href.split('#')[0];
		targetPath = decodeURIComponent(targetPath);
		const resolved = path.resolve(fileDir, targetPath);

		if(!fsModule.existsSync(resolved))
		{
			issues.push({
				file: filePath, line: link.line, severity: 'error', check: 'link', message: `Broken link: ${link.href}`
			});
		}
	}

	return issues;
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
 * Validates that Kern class references in code blocks exist in the codebase
 * @param {string} content - File content
 * @param {string} filePath - File path for reporting
 * @param {Set<string>} classIndex - Set of known class names
 * @returns {Array<{file: string, line: number, severity: string, check: string, message: string}>}
 */
function checkClassReferences(content, filePath, classIndex)
{
	const issues = [];

	if(!classIndex || classIndex.size === 0)
	{
		return issues;
	}

	const codeBlocks = parseCodeBlocks(content);
	const classRefRegex = /\b([A-Z]{2,}[A-Z0-9]*_[A-Za-z]\w*)\b/g;
	const reported = new Set();

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
				const ref = match[1];

				if(ref.endsWith('__c') || ref.endsWith('__mdt') || ref.endsWith('__e') || ref.endsWith('__r') || ref.endsWith('__b') || ref.endsWith('__x'))
				{
					continue;
				}

				const prefix = ref.split('_')[0] + '_';
				if(!KERN_PREFIXES.has(prefix))
				{
					continue;
				}

				if(ref.includes('_TEST'))
				{
					continue;
				}

				const reportKey = `${filePath}:${ref}`;
				if(reported.has(reportKey))
				{
					continue;
				}

				if(!classIndex.has(ref))
				{
					reported.add(reportKey);
					issues.push({
						file: filePath, line: block.startLine + i + 1, severity: 'warning', check: 'class-ref', message: `Unknown class reference: ${ref}`
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
	'npm:test:perf:report'
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
		'.planning'
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

// Committed Apex artifacts that back the Fast Start fences live here.
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
 *   - the no-op `SeeAllData=false` default (artifacts state it explicitly; the
 *     teaching fence omits it — behaviourally identical)
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
		.replace(/\bSeeAllData\s*=\s*false\b,?/g, '')
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
 * apexCodeLines (comments, indentation, formatter spacing, SeeAllData=false).
 *
 * Only runs on `Fast Start - *.md` docs. A named file with no committed
 * counterpart is skipped (that is a gate-wiring concern, not a parity concern).
 *
 * @param {string} content - Markdown content
 * @param {string} filePath - File path (for error reporting + Fast Start gate)
 * @param {string} repoRoot - Source repo root
 * @param {Object} [fsModule=fs] - File system module (for testing)
 * @returns {Array} Issue objects (check: 'fence-file-parity')
 */
function checkFenceFileParity(content, filePath, repoRoot, fsModule = fs)
{
	if(!/^Fast Start - .+\.md$/.test(path.basename(filePath)))
	{
		return [];
	}

	const issues = [];
	const blocks = parseCodeBlocks(content);
	const lines = content.split('\n');

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
		const committedPath = path.join(repoRoot, FAST_START_CLASS_DIR, basename);
		if(!fsModule.existsSync(committedPath))
		{
			continue;
		}

		const fence = blocks.find(b => b.startLine > proseLine && (b.startLine - proseLine) <= FENCE_PROSE_MAX_GAP);
		if(!fence)
		{
			continue;
		}

		const fenceLines = apexCodeLines(fence.code);
		const fileKeys = new Set(apexCodeLines(fsModule.readFileSync(committedPath, 'utf8')).map(l => l.key));

		const unbacked = fenceLines.find(l => !fileKeys.has(l.key));
		if(!unbacked)
		{
			continue;
		}

		issues.push({
			file: filePath,
			line: fence.startLine,
			severity: 'error',
			check: 'fence-file-parity',
			message: `code fence teaches a line not backed by committed reference ${FAST_START_CLASS_DIR}/${basename} (the artifact may add to the fence, but must contain everything in it); unbacked line: \`${unbacked.text}\``
		});
	}

	return issues;
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
		let allIssues = [];

		this.log.info('docs:validate \u2014 Documentation Validation\n');
		this.log.info(`Checking ${files.length} files...\n`);

		const repoRoot = path.resolve(this.config.docsDir, '..');
		const allFileContents = [];
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
				...checkClassReferences(content, filePath, classIndex),
				...checkLineLength(content, filePath),
				...checkTableAlignment(content, filePath),
				...checkProseFileRefs(content, filePath, repoRoot, this.fs, this.config.proseRefAllowlist),
				...checkFenceFileParity(content, filePath, repoRoot, this.fs)
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
	checkFenceFileParity,
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
