#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Converts IcApexDoc HTML to Enterprise-Ready Markdown
 *
 * Produces clean documentation suitable for:
 * - Developer portals and wikis
 * - AI agents and code assistants
 * - GitHub/GitLab rendering
 *
 * @author Kern Framework
 * @version 3.21.0
 */

/**
 * @typedef {import('cheerio').CheerioAPI} CheerioAPI
 * @typedef {import('cheerio').Cheerio<import('cheerio').Element>} CheerioElement
 */

const fs = require('fs');
const path = require('path');
const glob = require('glob');
const cheerio = require('cheerio');

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const MAX_SUMMARY_LENGTH = 150;
const TRUNCATED_SUMMARY_LENGTH = 147;

const APEX_MODIFIERS = [
	'global',
	'public',
	'private',
	'protected',
	'static',
	'final',
	'virtual',
	'abstract',
	'override',
	'transient',
	'testmethod'
];

const DOC_TYPE_SUFFIXES = {
	'_cls': 'class', '_object': 'sobject', '_trigger': 'trigger', '_enum': 'enum', '_interface': 'interface'
};

const CATEGORY_INFO = {
	apex: {title: 'Apex Classes', description: 'Core Apex classes, utilities, and services'},
	objects: {title: 'Custom Objects', description: 'Custom SObjects in the package'},
	metadata: {title: 'Custom Metadata Types', description: 'Configuration and settings metadata'},
	events: {title: 'Platform Events', description: 'Asynchronous event definitions'}
};

const FIELD_ATTRIBUTE_ORDER = [
	'Data Type',
	'Required',
	'Unique',
	'External ID',
	'Formula',
	'Default Value'
];

const CONFIG = {
	inputDir: path.join(__dirname, '../apexdoc'),
	outputDir: path.join(__dirname, '../docs/reference'),
	skipFiles: [
		'index.html',
		'help.html',
		'classes.html',
		'enums.html',
		'interfaces.html',
		'triggers.html',
		'sobjects.html',
		'groups.html',
		'index-all.html'
	],
	skipPatterns: [
		/_group\.html$/,
		/^kern\./
	]
};

// ─────────────────────────────────────────────────────────────────────────────
// Shared Helper Functions
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Extract See Also links from elements containing "See Also:" bold tags
 * @param {CheerioAPI} cheerioApi - Cheerio API instance
 * @param {CheerioElement} container - Container element to search within
 * @param {string} cleanName - Clean name for link fixing
 * @returns {Array<{text: string, href: string}>}
 */
function extractSeeAlsoLinks(cheerioApi, container, cleanName)
{
	const seeAlso = [];
	container.find('b:contains("See Also:")').each((k, el) =>
	{
		const nextTable = cheerioApi(el).next('table');
		if(nextTable.length)
		{
			nextTable.find('a').each((l, link) =>
			{
				const href = cheerioApi(link).attr('href') || '';
				const text = cheerioApi(link).text().trim();
				if(text)
				{
					seeAlso.push({text, href: fixLink(href, cleanName)});
				}
			});
		}
	});
	return seeAlso;
}

/**
 * Extract example code from HTML, preserving multiple code blocks with their languages.
 * IMPORTANT: Process raw HTML string BEFORE cheerio mangles it (cheerio breaks code blocks
 * when they contain <p/> tags, transforming them into </code><p>...</p><code> structure).
 *
 * @param {string} divHtml - HTML content to search (raw, not cheerio-processed)
 * @returns {string} Markdown-formatted example or empty string
 */
function extractExampleFromHtml(divHtml)
{
	const exampleMatch = divHtml.match(/<b>Example:<\/b>[\s\S]*?<table>([\s\S]*?)<\/table>/i);
	if(!exampleMatch)
	{
		return '';
	}

	// Extract the td content directly with regex to avoid cheerio mangling
	const tdMatch = exampleMatch[1].match(/<td[^>]*>([\s\S]*?)<\/td>/i);
	if(!tdMatch)
	{
		return '';
	}

	// Get raw HTML content before cheerio can break it
	let html = tdMatch[1];
	if(!html)
	{
		return '';
	}

	// Replace <p/> with newline BEFORE any parsing (IcApexDoc uses <p/> for blank lines in code)
	html = html.replace(/<p\s*\/?>/gi, '\n');

	// Process each <pre><code> block, preserving language
	// Note: IcApexDoc may put </code> and </pre> on separate lines
	const parts = [];
	const codeBlockRegex = /<pre><code(?:\s+class="language-(\w+)")?>([\s\S]*?)<\/code>\s*<\/pre>/gi;

	let lastIndex = 0;
	let match;

	while((match = codeBlockRegex.exec(html)) !== null)
	{
		// Get text before this code block
		const textBefore = html.substring(lastIndex, match.index).trim();
		if(textBefore)
		{
			// Clean up the text - decode entities and remove tags
			const cleanText = htmlToMarkdown(textBefore, false).trim();
			if(cleanText)
			{
				parts.push(cleanText);
			}
		}

		// Extract language and code
		const language = match[1] || 'apex';
		const code = match[2]
		.replace(/&quot;/g, '"')
		.replace(/&amp;/g, '&')
		.replace(/&lt;/g, '<')
		.replace(/&gt;/g, '>')
		.replace(/&#39;/g, '\'')
		.trim();

		parts.push('```' + language + '\n' + code + '\n```');

		lastIndex = match.index + match[0].length;
	}

	// Get any remaining text after last code block
	const textAfter = html.substring(lastIndex).trim();
	if(textAfter)
	{
		const cleanText = htmlToMarkdown(textAfter, false).trim();
		if(cleanText)
		{
			parts.push(cleanText);
		}
	}

	// If no code blocks found, fall back to simple text extraction
	if(parts.length === 0)
	{
		// Use cheerio only for simple cases without code blocks
		const exampleTable = cheerio.load(`<table>${exampleMatch[1]}</table>`);
		const preCode = exampleTable('pre code');
		if(preCode.length)
		{
			return preCode.text().trim();
		}
		const pre = exampleTable('pre');
		const td = exampleTable('td').first();
		return pre.length ? pre.text().trim() : td.text().trim();
	}

	return parts.join('\n\n');
}

/**
 * Remove metadata sections from cloned element for description extraction
 * @param {CheerioElement} clone - Cloned cheerio element
 * @param {Array<string>} sections - Section names to remove (e.g., 'See Also:', 'Example:')
 */
function removeMetadataSections(clone, sections)
{
	sections.forEach(section =>
	{
		// noinspection JSUnresolvedReference - nextUntil/addBack are valid Cheerio/jQuery methods
		clone.find(`b:contains("${section}")`).nextUntil('b').addBack().remove();
	});
	clone.find('table').remove();
}

/**
 * Extract basic member information (shared initialization for detail extraction)
 * @param {CheerioAPI} cheerioApi - Cheerio API instance
 * @param {CheerioElement} member - Member element
 * @returns {{id: string, sigDiv: cheerio.Cheerio, signature: string, contentDiv: cheerio.Cheerio}}
 */
// noinspection JSValidateJSDoc
function extractBasicMemberInfo(cheerioApi, member)
{
	const id = cheerioApi(member).attr('id') || '';
	const sigDiv = cheerioApi(member).find('.signature');
	const signature = normalizeSignature(sigDiv.text());
	const contentDiv = cheerioApi(member).find('> div').not('.signature');
	return {id, sigDiv, signature, contentDiv};
}

/**
 * Extract type with link from signature div
 * @param {CheerioAPI} cheerioApi - Cheerio API instance
 * @param {CheerioElement} sigDiv - Signature div element
 * @param {string} cleanName - Clean name for link fixing
 * @returns {string} Type with Markdown link or empty string
 */
function extractTypeLink(cheerioApi, sigDiv, cleanName)
{
	const typeLink = sigDiv.find('a').first();
	if(typeLink.length)
	{
		return linkToMarkdown(cheerioApi, typeLink, cleanName);
	}
	return '';
}

/**
 * Extract modifiers from text using known Apex modifier keywords
 * @param {string} fullText - Full text to extract from
 * @returns {{modifiers: string, remainingWords: string[]}}
 */
function extractModifiers(fullText)
{
	const words = fullText.split(/\s+/);
	const modifierParts = [];
	let startIndex = 0;

	for(const word of words)
	{
		if(APEX_MODIFIERS.includes(word.toLowerCase()))
		{
			modifierParts.push(word);
			startIndex++;
		}
		else
		{
			// noinspection BreakStatementJS - Valid control flow: exit loop once non-modifier word found
			break;
		}
	}

	return {
		modifiers: modifierParts.join(' '), remainingWords: words.slice(startIndex)
	};
}

// ─────────────────────────────────────────────────────────────────────────────
// Text Processing Functions
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Convert email-style author to Title Case name
 * @param {string} authorString - Author string (email or name)
 * @returns {string} Formatted author name
 */
// noinspection FunctionWithMultipleReturnPointsJS
function formatAuthorName(authorString)
{
	if(!authorString)
	{
		return '';
	}

	const authors = authorString.split(/[,;]\s*/);
	const formatted = authors.map(author =>
	{
		let name = author.trim();
		if(name.includes('@'))
		{
			name = name.split('@')[0];
		}
		name = name.replace(/[._]/g, ' ');
		return name.split(' ')
		.map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
		.join(' ');
	});

	return formatted.join(', ');
}

/**
 * Fix links: convert .html to .md, preserve Salesforce docs
 * Also handles cross-category links for objects, metadata, events
 * @param {string} href - Original href
 * @param {string} cleanName - Clean name for self-reference detection
 * @returns {string} Fixed link
 */
// noinspection FunctionWithMultipleReturnPointsJS,OverlyComplexFunctionJS
function fixLink(href, cleanName = '')
{
	if(!href)
	{
		return '';
	}

	// Keep Salesforce documentation links
	if(href.includes('salesforce.com') || href.includes('developer.salesforce'))
	{
		return href;
	}

	// Remove ./ prefix
	let fixed = href;
	if(fixed.startsWith('./'))
	{
		fixed = fixed.substring(2);
	}

	// Extract anchor if present (GFM converts heading anchors to lowercase)
	let anchor = '';
	const anchorIndex = fixed.indexOf('#');
	if(anchorIndex >= 0)
	{
		anchor = fixed.substring(anchorIndex).toLowerCase();
		fixed = fixed.substring(0, anchorIndex);
	}

	// Handle object links
	if(fixed.includes('_object.html'))
	{
		const objName = fixed.replace(/_object\.html.*$/, '');

		// Self-referential link - just use anchor
		if(cleanName && objName === cleanName && anchor)
		{
			return anchor;
		}

		// Route to proper category based on suffix
		if(objName.includes('__mdt'))
		{
			return `../metadata/${objName}.md${anchor}`;
		}
		if(objName.includes('__e'))
		{
			return `../events/${objName}.md${anchor}`;
		}
		if(objName.includes('__c'))
		{
			return `../objects/${objName}.md${anchor}`;
		}
		return `${objName}.md${anchor}`;
	}

	// Check for self-referential class links
	const classMatch = fixed.match(/^(.+?)_(cls|enum|interface|trigger)\.html$/);
	if(classMatch)
	{
		const className = classMatch[1];
		if(cleanName && className === cleanName && anchor)
		{
			return anchor;
		}
	}

	// Convert class links
	fixed = fixed
	.replace(/_cls\.html/g, '.md')
	.replace(/_enum\.html/g, '.md')
	.replace(/_interface\.html/g, '.md')
	.replace(/_trigger\.html/g, '.md')
	.replace(/\.html/g, '.md');

	return fixed + anchor;
}

/**
 * Normalize signature whitespace - removes extra spaces around parentheses
 * @param {string} sig - Signature string
 * @returns {string} Normalized signature
 */
function normalizeSignature(sig)
{
	return sig
	.replace(/\s+/g, ' ')
	.replace(/\(\s+/g, '(')
	.replace(/\s+\)/g, ')')
	.replace(/\s+,/g, ',')
	.trim();
}

/**
 * Convert HTML to Markdown and normalize whitespace
 * @param {string} text - HTML text to convert
 * @param {boolean} preserveStructure - If true, preserve lists and paragraphs as Markdown
 * @returns {string} Markdown text
 */
// noinspection FunctionWithMultipleReturnPointsJS
function htmlToMarkdown(text, preserveStructure = false)
{
	if(!text)
	{
		return '';
	}

	let result = text
	.replace(/<code[^>]*>([^<]*)<\/code>/gi, '`$1`')
	.replace(/<b>([^<]*)<\/b>/gi, '**$1**')
	.replace(/<strong>([^<]*)<\/strong>/gi, '**$1**')
	.replace(/<i>([^<]*)<\/i>/gi, '*$1*')
	.replace(/<em>([^<]*)<\/em>/gi, '*$1*');

	if(preserveStructure)
	{
		result = result
		.replace(/<ul[^>]*>/gi, '\n')
		.replace(/<\/ul>/gi, '\n')
		.replace(/<ol[^>]*>/gi, '\n')
		.replace(/<\/ol>/gi, '\n')
		.replace(/<li[^>]*>/gi, '- ')
		.replace(/<\/li>/gi, '\n')
		.replace(/<p[^>]*>/gi, '\n\n')
		.replace(/<\/p>/gi, '\n')
		.replace(/<br\s*\/?>/gi, '\n');
	}
	else
	{
		result = result
		.replace(/<\/?p[^>]*>/gi, ' ')
		.replace(/<br\s*\/?>/gi, ' ')
		.replace(/<\/?[uo]l[^>]*>/gi, ' ')
		.replace(/<\/?li[^>]*>/gi, ' ');
	}

	result = result
	.replace(/<[^>]+>/g, ' ')
	.replace(/&nbsp;/g, ' ')
	.replace(/&quot;/g, '"')
	.replace(/&amp;/g, '&')
	.replace(/&lt;/g, '<')
	.replace(/&gt;/g, '>')
	.replace(/&#39;/g, '\'')
	.replace(/&ndash;/g, '-')
	.replace(/&mdash;/g, '—');

	if(preserveStructure)
	{
		result = result
		.replace(/ +/g, ' ')
		.replace(/\n +/g, '\n')
		.replace(/ +\n/g, '\n')
		.replace(/\n{3,}/g, '\n\n')
		.trim();
	}
	else
	{
		result = result.replace(/\s+/g, ' ').trim();
	}

	return result;
}

/**
 * Convert an HTML link element to Markdown, preserving Salesforce doc links
 * @param {CheerioAPI} cheerioApi - Cheerio API (conventionally named $)
 * @param {CheerioElement} linkElement - Link element
 * @param {string} cleanName - Clean name for link fixing
 * @returns {string} Markdown link
 */
// noinspection FunctionWithMultipleReturnPointsJS,JSValidateJSDoc
function linkToMarkdown(cheerioApi, linkElement, cleanName = '')
{
	const href = cheerioApi(linkElement).attr('href') || '';
	const text = cheerioApi(linkElement).text().trim();

	if(!text)
	{
		return '';
	}

	const fixedHref = fixLink(href, cleanName);
	return fixedHref ? `[${text}](${fixedHref})` : text;
}

// ─────────────────────────────────────────────────────────────────────────────
// Type Extraction Functions
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Serialize a table cell's contents to Markdown in document order, preserving
 * every type as a link and every literal character (angle brackets, commas,
 * parameter names) verbatim. Replaces fragile raw-HTML regex rewriting, which
 * collided on substring type names (SObject within SObjectField) and lost
 * nested generics / multi-parameter content.
 *
 * Angle brackets are emitted decoded (bare `<`/`>`); the docs-site materializer
 * (docs-site/scripts/markdown-safety.mjs) escapes them for VitePress rendering.
 *
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {CheerioElement} node - Element whose contents to serialize
 * @param {string} cleanName - Clean name for self-link resolution
 * @param {{skipAnchors: number}} [state] - Mutable counter of leading <a> elements to
 *   drop (used to omit the method-name link when serializing a parameter list)
 * @returns {string} Markdown serialization of the node's contents
 */
function serializeTypeCell(cheerioApi, node, cleanName = '', state)
{
	const ctx = state || {skipAnchors: 0};
	let out = '';
	cheerioApi(node).contents().each((i, child) =>
	{
		if(child.type === 'text')
		{
			out += child.data || '';
		}
		else if(child.type === 'tag' && child.name === 'a')
		{
			if(ctx.skipAnchors > 0)
			{
				ctx.skipAnchors -= 1;
				return;
			}
			const text = cheerioApi(child).text().trim();
			const fixedHref = fixLink(cheerioApi(child).attr('href') || '', cleanName);
			out += fixedHref && text ? `[${text}](${fixedHref})` : text;
		}
		else if(child.type === 'tag')
		{
			// <code>, <b>, <div>, ... — descend, keeping inner text (brackets, commas).
			out += serializeTypeCell(cheerioApi, child, cleanName, ctx);
		}
	});
	return out;
}

/**
 * Remove Markdown link syntax, leaving the link text: `[List](url)` -> `List`.
 * @param {string} md - Markdown string
 * @returns {string} Plain text
 */
function stripMarkdownLinks(md)
{
	return md.replace(/\[([^\]]+)]\([^)]*\)/g, '$1');
}

/**
 * Extract a member's type from a summary cell, preserving generics and links.
 * "global static Map<Id, List<SObject>>" -> modifiers="global static",
 * typeWithLink="[Map](..)<[Id](..), [List](..)<[SObject](..)>>".
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {CheerioElement} cell - Table cell element
 * @param {string} cleanName - Clean name for link fixing
 * @returns {{modifiers: string, type: string, typeWithLink: string, full: string}}
 */
// noinspection JSValidateJSDoc
function extractTypeWithLink(cheerioApi, cell, cleanName = '')
{
	const fullText = cheerioApi(cell).text().trim().replace(/\s+/g, ' ');
	const {modifiers} = extractModifiers(fullText);

	const serialized = serializeTypeCell(cheerioApi, cell, cleanName).replace(/\s+/g, ' ').trim();

	let typeWithLink = serialized;
	if(modifiers)
	{
		const escaped = modifiers.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
		typeWithLink = serialized.replace(new RegExp(`^${escaped}\\s*`), '');
	}

	const type = stripMarkdownLinks(typeWithLink) || fullText;

	return {
		modifiers, type, typeWithLink, full: modifiers ? `${modifiers} ${typeWithLink}` : typeWithLink
	};
}

// ─────────────────────────────────────────────────────────────────────────────
// Metadata Extraction Functions
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Determine document type and clean name from file name
 * @param {string} fileName - File name without extension
 * @returns {{docType: string, cleanName: string}}
 */
function parseDocumentType(fileName)
{
	for(const [suffix, docType] of Object.entries(DOC_TYPE_SUFFIXES))
	{
		if(fileName.endsWith(suffix))
		{
			return {
				docType, cleanName: fileName.replace(new RegExp(`${suffix}$`), '')
			};
		}
	}
	return {docType: 'class', cleanName: fileName};
}

/**
 * Determine category from clean name
 * @param {string} cleanName - Clean name
 * @returns {string} Category
 */
function determineCategory(cleanName)
{
	if(cleanName.includes('__mdt'))
	{
		return 'metadata';
	}
	if(cleanName.includes('__e'))
	{
		return 'events';
	}
	if(cleanName.includes('__c'))
	{
		return 'objects';
	}
	return 'apex';
}

/**
 * Extract metadata from IcApexDoc HTML
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} filePath - File path
 * @returns {Object} Metadata object
 */
// noinspection FunctionTooLongJS,OverlyComplexFunctionJS,JSValidateJSDoc
function extractMetadata(cheerioApi, filePath)
{
	const fileName = path.basename(filePath, '.html');
	const {docType, cleanName} = parseDocumentType(fileName);

	// Get title
	const titleRaw = cheerioApi('#TopLevelDeclaration h2').first().text() || cleanName;
	const title = titleRaw
	.replace(/^(Class|Interface|Enum|Trigger|SObject)\s+/, '')
	.replace(/`/g, '')
	.trim();

	// Get class description - extract first paragraph before any embedded documentation headers
	let description = '';
	let extendedDescription = '';
	const memberDiv = cheerioApi('#TopLevelDeclarationMember > div').not('.signature');
	if(memberDiv.length)
	{
		const divHtml = memberDiv.html() || '';
		const metadataPattern = /<b>(Author|Group|Date|Since|See Also):/i;
		const parts = divHtml.split(metadataPattern);

		if(parts.length > 0)
		{
			let descHtml = parts[0];

			// Check for embedded documentation headers (<h2>, <h3>) which indicate extended documentation
			// IcApexDoc converts ApexDoc markdown (## Headers) to HTML h2/h3 tags
			const htmlHeaderMatch = descHtml.match(/<h[23][^>]*>/i);
			if(htmlHeaderMatch)
			{
				// Split at the first h2/h3 header
				const beforeHeader = descHtml.substring(0, htmlHeaderMatch.index);
				const afterHeader = descHtml.substring(htmlHeaderMatch.index);

				// Extract clean description from first part
				const tempDoc = cheerio.load(`<div>${beforeHeader.replace(/<br\s*\/?>/gi, ' ')}</div>`);
				description = tempDoc('div').text().trim().replace(/\s+/g, ' ');

				// Preserve extended documentation with markdown structure
				// Convert HTML back to markdown format
				extendedDescription = afterHeader
				.replace(/<h2[^>]*>/gi, '\n## ')
				.replace(/<\/h2>/gi, '\n\n')
				.replace(/<h3[^>]*>/gi, '\n### ')
				.replace(/<\/h3>/gi, '\n\n')
				.replace(/<p\s*\/?>/gi, '\n\n')
				.replace(/<\/p>/gi, '\n')
				.replace(/<br\s*\/?>/gi, '\n')
				.replace(/<pre><code[^>]*>/gi, '\n```apex\n')
				.replace(/<\/code><\/pre>/gi, '\n```\n')
				.replace(/<ul[^>]*>/gi, '\n')
				.replace(/<\/ul>/gi, '\n')
				.replace(/<li[^>]*>/gi, '- ')
				.replace(/<\/li>/gi, '\n')
				.replace(/<code[^>]*>([^<]*)<\/code>/gi, '`$1`')
				.replace(/<b>([^<]*)<\/b>/gi, '**$1**')
				.replace(/<[^>]+>/g, '')
				.replace(/&nbsp;/g, ' ')
				.replace(/&amp;/g, '&')
				.replace(/&lt;/g, '<')
				.replace(/&gt;/g, '>')
				.replace(/&quot;/g, '"')
				.replace(/&#39;/g, '\'')
				.replace(/\n{3,}/g, '\n\n')
				.trim();
			}
			else
			{
				// Check if description contains markdown-style formatting (bold headers, code blocks, lists)
				// These are indicated by <b>Title:</b> followed by code blocks or lists
				const hasMarkdownFormatting = descHtml.includes('<pre><code') || (descHtml.includes('<b>') && (descHtml.includes('<ul') || descHtml.includes('</code></pre>')));

				if(hasMarkdownFormatting)
				{
					// Strip Example section from description (it's extracted separately as metadata.example)
					// Pattern: <b>Example:</b> followed by <table>...</table>
					let descHtmlWithoutExample = descHtml.replace(/<b>Example:<\/b>\s*<table>[\s\S]*?<\/table>/gi, '');

					// Convert HTML to markdown, preserving structure
					description = descHtmlWithoutExample
					.replace(/<h2[^>]*>/gi, '\n## ')
					.replace(/<\/h2>/gi, '\n\n')
					.replace(/<h3[^>]*>/gi, '\n### ')
					.replace(/<\/h3>/gi, '\n\n')
					.replace(/<p\s*\/?>/gi, '\n\n')
					.replace(/<\/p>/gi, '\n')
					.replace(/<br\s*\/?>/gi, '\n')
					.replace(/<pre><code[^>]*>/gi, '\n```apex\n')
					.replace(/<\/code>\s*<\/pre>/gi, '\n```\n')
					.replace(/<ul[^>]*>/gi, '\n')
					.replace(/<\/ul>/gi, '\n')
					.replace(/<li[^>]*>/gi, '- ')
					.replace(/<\/li>/gi, '\n')
					.replace(/<code[^>]*>([^<]*)<\/code>/gi, '`$1`')
					.replace(/<b>([^<]*)<\/b>/gi, '**$1**')
					.replace(/<[^>]+>/g, '')
					.replace(/&nbsp;/g, ' ')
					.replace(/&amp;/g, '&')
					.replace(/&lt;/g, '<')
					.replace(/&gt;/g, '>')
					.replace(/&quot;/g, '"')
					.replace(/&#39;/g, '\'')
					.replace(/\n{3,}/g, '\n\n')
					.trim();
				}
				else
				{
					// Simple text extraction for plain descriptions
					const tempDoc = cheerio.load(`<div>${descHtml.replace(/<br\s*\/?>/gi, ' ')}</div>`);
					description = tempDoc('div').text().trim().replace(/\s+/g, ' ');
				}
			}
		}
	}

	// Alternative description extraction
	if(!description)
	{
		const topDiv = cheerioApi('#TopLevelDeclarationMember').find('> div').not('.signature').first();
		if(topDiv.length)
		{
			const html = topDiv.html() || '';
			const match = html.match(/^([\s\S]*?)<b>/i);
			if(match)
			{
				const tempDoc = cheerio.load(`<div>${match[1]}</div>`);
				description = tempDoc('div').text().trim().replace(/\s+/g, ' ');
			}
		}
	}

	// Extract author
	let author = '';
	cheerioApi('b:contains("Author:")').each((i, el) =>
	{
		const nextTable = cheerioApi(el).next('table');
		if(nextTable.length)
		{
			author = nextTable.find('td').last().text().trim();
		}
	});

	// Extract group
	let group = '';
	let groupLink = '';
	cheerioApi('b:contains("Group:")').each((i, el) =>
	{
		const nextTable = cheerioApi(el).next('table');
		if(nextTable.length)
		{
			const groupAnchor = nextTable.find('a').first();
			if(groupAnchor.length)
			{
				group = groupAnchor.text().trim();
				groupLink = fixLink(groupAnchor.attr('href') || '', cleanName);
			}
			else
			{
				group = nextTable.find('td').last().text().trim();
			}
		}
	});

	// Extract date
	let date = '';
	cheerioApi('b:contains("Date:")').each((i, el) =>
	{
		const nextTable = cheerioApi(el).next('table');
		if(nextTable.length)
		{
			date = nextTable.find('td').last().text().trim();
		}
	});

	// Extract since — class-level only. The class declaration renders first on the page and its
	// members follow, each potentially carrying its own "Since:" label. Take the FIRST "Since:"
	// (the class's own) rather than the last, so a member introduced in a later version does not
	// overwrite the class's introduction version. Member-level since is extracted separately.
	// Keep only the first line of the cell: a class header may carry free text (e.g. a Coverage
	// Note) after @since, which ic-apexdoc renders into the same cell as the version.
	let since = '';
	const classSinceLabel = cheerioApi('b:contains("Since:")').first();
	if(classSinceLabel.length)
	{
		const nextTable = classSinceLabel.next('table');
		if(nextTable.length)
		{
			since = nextTable.find('td').last().text().trim().split(/\r?\n/)[0].trim();
		}
	}

	// Extract @see references using shared helper
	const seeAlso = extractSeeAlsoLinks(cheerioApi, cheerioApi('#TopLevelDeclarationMember'), cleanName);

	// Extract class-level @example
	let example = '';
	const memberDivHtml = memberDiv.html() || '';
	if(memberDivHtml.includes('<b>Example:</b>'))
	{
		example = extractExampleFromHtml(memberDivHtml);
	}

	// Extract known derived types
	const derivedTypes = [];
	cheerioApi('.inheritance').each((i, el) =>
	{
		// noinspection JSUnresolvedReference - nextAll is a valid Cheerio/jQuery method
		cheerioApi(el).nextAll('a').each((j, link) =>
		{
			const href = cheerioApi(link).attr('href') || '';
			const text = cheerioApi(link).text().trim();
			if(text && !cheerioApi(link).parent().is('.inheritance'))
			{
				derivedTypes.push({text, href: fixLink(href, cleanName)});
			}
		});
	});

	const category = determineCategory(cleanName);

	return {
		fileName, cleanName, title, description, extendedDescription, example, author, group, groupLink, date, since, seeAlso, derivedTypes, category, docType
	};
}

/**
 * Extract signature from the declaration, preserving extends/implements links
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} cleanName - Clean name for link fixing
 * @returns {{text: string|null, extendsInfo: Object|null, implementsInfo: Array}}
 */
// noinspection FunctionWithMultipleReturnPointsJS,JSValidateJSDoc
function extractSignature(cheerioApi, cleanName = '')
{
	const sigDiv = cheerioApi('#TopLevelDeclaration .signature').first();
	if(!sigDiv.length)
	{
		return {text: null, extendsInfo: null, implementsInfo: []};
	}

	const sig = sigDiv.text().trim().replace(/\s+/g, ' ');

	// Extract extends link
	let extendsInfo = null;
	const extendsLink = sigDiv.find('a').filter((i, el) =>
	{
		const prevText = cheerioApi(el).parent().text();
		return prevText.includes('extends');
	}).first();

	if(extendsLink.length)
	{
		const href = extendsLink.attr('href') || '';
		const text = extendsLink.text().trim();
		if(text)
		{
			extendsInfo = {name: text, href: fixLink(href, cleanName)};
		}
	}

	// Extract implements links
	const implementsInfo = [];
	sigDiv.find('a').each((i, el) =>
	{
		const fullHtml = sigDiv.html() || '';
		const linkHtml = cheerioApi.html(el);
		const beforeLink = fullHtml.substring(0, fullHtml.indexOf(linkHtml));
		if(beforeLink.includes('implements'))
		{
			const href = cheerioApi(el).attr('href') || '';
			const text = cheerioApi(el).text().trim();
			if(text)
			{
				implementsInfo.push({name: text, href: fixLink(href, cleanName)});
			}
		}
	});

	return {text: sig, extendsInfo, implementsInfo};
}

// ─────────────────────────────────────────────────────────────────────────────
// Members Summary Extraction
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Build the members summary section with proper type links
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} cleanName - Clean name
 * @returns {{properties: Array, methods: Array, fields: Array, innerClasses: Array}}
 */
// noinspection FunctionWithMultipleReturnPointsJS,FunctionTooLongJS,JSValidateJSDoc
function buildMembersSummary(cheerioApi, cleanName)
{
	const summaryTable = cheerioApi('#Summary table');
	if(!summaryTable.length)
	{
		return {properties: [], methods: [], fields: [], innerClasses: []};
	}

	const properties = [];
	const methods = [];
	const fields = [];
	const innerClasses = [];

	summaryTable.find('tbody tr').each((i, tr) =>
	{
		const cells = cheerioApi(tr).find('td');
		if(cells.length < 4)
		{
			return;
		}

		const iconImg = cheerioApi(cells[0]).find('img');
		const iconAlt = iconImg.attr('alt') || '';
		const typeInfo = extractTypeWithLink(cheerioApi, cells[1], cleanName);
		const nameCell = cheerioApi(cells[2]);
		const descText = cheerioApi(cells[3]).text().trim().replace(/\s+/g, ' ');

		const nameLink = nameCell.find('a').first();
		const href = fixLink(nameLink.attr('href') || '', cleanName);
		const methodName = nameLink.text().trim().replace(/[`*]/g, '');

		let fullSignature = methodName;

		// Serialize the name cell's parameter list in document order, dropping the
		// leading method-name anchor so only "(params)" remains. The DOM walk keeps
		// every type linked and every parameter intact (the old per-link HTML regex
		// collided on substring type names and destroyed nested/multi-param content).
		const params = serializeTypeCell(cheerioApi, cells[2], cleanName, {skipAnchors: 1})
		.replace(/\s+/g, ' ')
		.trim();
		const parenIndex = params.indexOf('(');
		if(parenIndex >= 0)
		{
			fullSignature = normalizeSignature(methodName + params.substring(parenIndex));
		}

		const member = {name: methodName, fullSignature, typeInfo, description: descText, href};

		// Categorize member based on icon
		const iconLower = iconAlt.toLowerCase();
		if(iconLower.includes('property'))
		{
			properties.push(member);
		}
		else if(iconLower.includes('method'))
		{
			methods.push(member);
		}
		else if(iconLower.includes('field'))
		{
			fields.push(member);
		}
		else if(iconLower.includes('class'))
		{
			innerClasses.push(member);
		}
		else if(fullSignature.includes('('))
		{
			methods.push(member);
		}
		else
		{
			properties.push(member);
		}
	});

	return {properties, methods, fields, innerClasses};
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Extraction Functions
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Extract detailed property information
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} cleanName - Clean name
 * @returns {Array} Property details
 */
// noinspection JSValidateJSDoc
function extractPropertyDetails(cheerioApi, cleanName)
{
	const details = [];

	cheerioApi('#members_properties .member').each((i, member) =>
	{
		const {id, sigDiv, signature, contentDiv} = extractBasicMemberInfo(cheerioApi, member);
		let description = '';
		let seeAlso = [];

		contentDiv.each((j, div) =>
		{
			const clone = cheerioApi(div).clone();
			seeAlso = extractSeeAlsoLinks(cheerioApi, clone, cleanName);
			removeMetadataSections(clone, ['See Also:']);

			const text = clone.text().trim();
			if(text && !description)
			{
				description = text;
			}
		});

		const typeWithLink = extractTypeLink(cheerioApi, sigDiv, cleanName);
		details.push({id, signature, description, seeAlso, typeWithLink});
	});

	return details;
}

/**
 * Extract detailed enum constant or field information (shared logic)
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} cleanName - Clean name
 * @param {string} selector - CSS selector for members
 * @returns {Array} Details array
 */
// noinspection JSValidateJSDoc
function extractMemberDetailsWithExample(cheerioApi, cleanName, selector)
{
	const details = [];

	cheerioApi(selector).each((i, member) =>
	{
		const {id, sigDiv, signature, contentDiv} = extractBasicMemberInfo(cheerioApi, member);
		let description = '';
		let seeAlso = [];
		let example = '';
		let since = '';

		contentDiv.each((j, div) =>
		{
			const clone = cheerioApi(div).clone();
			const divHtml = cheerioApi(div).html() || '';

			example = example || extractExampleFromHtml(divHtml);
			seeAlso = seeAlso.length ? seeAlso : extractSeeAlsoLinks(cheerioApi, clone, cleanName);

			if(!since)
			{
				const sinceMatch = divHtml.match(/<b>Since:<\/b>[\s\S]*?<table>([\s\S]*?)<\/table>/i);
				if(sinceMatch)
				{
					const sinceTable = cheerio.load(`<table>${sinceMatch[1]}</table>`);
					since = sinceTable('td').last().text().trim();
				}
			}

			removeMetadataSections(clone, [
				'See Also:',
				'Example:',
				'Since:'
			]);

			const text = clone.text().trim();
			if(text && !description)
			{
				description = text;
			}
		});

		const typeWithLink = extractTypeLink(cheerioApi, sigDiv, cleanName);
		details.push({id, signature, description, seeAlso, since, example, typeWithLink});
	});

	return details;
}

/**
 * Extract detailed enum constant information
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} cleanName - Clean name
 * @returns {Array} Enum constant details
 */
// noinspection JSValidateJSDoc
function extractEnumConstantDetails(cheerioApi, cleanName)
{
	return extractMemberDetailsWithExample(cheerioApi, cleanName, '#members_enum_constants .member');
}

/**
 * Extract detailed field/constant information
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} cleanName - Clean name
 * @returns {Array} Field details
 */
// noinspection JSValidateJSDoc
function extractFieldDetails(cheerioApi, cleanName)
{
	return extractMemberDetailsWithExample(cheerioApi, cleanName, '#members_fields .member');
}

/**
 * Extract detailed SObject field information (custom objects/metadata)
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} cleanName - Clean name
 * @returns {Array} SObject field details
 */
// noinspection JSValidateJSDoc
function extractSObjectFieldDetails(cheerioApi, cleanName)
{
	const details = [];

	cheerioApi('#members_sobject_fields .member').each((i, member) =>
	{
		const id = cheerioApi(member).attr('id') || '';
		const sigDiv = cheerioApi(member).find('.signature');
		const signature = normalizeSignature(sigDiv.text());
		const memberHtml = cheerioApi(member).html() || '';

		// Extract description
		let description = '';
		const contentDiv = cheerioApi(member).find('> div').not('.signature');
		contentDiv.each((j, div) =>
		{
			if(description)
			{
				return;
			}
			const divHtml = cheerioApi(div).html() || '';
			const beforeAttrs = divHtml.split(/<h4>Field Attributes<\/h4>/i)[0];
			if(beforeAttrs)
			{
				description = htmlToMarkdown(beforeAttrs, false);
			}
		});

		// Extract Field Attributes
		const fieldAttributes = {};
		const attrMatch = memberHtml.match(/<h4>Field Attributes<\/h4>[\s\S]*?<table[^>]*>([\s\S]*?)<\/table>/i);
		if(attrMatch)
		{
			const attrTable = cheerio.load(`<table>${attrMatch[1]}</table>`);
			attrTable('tr').each((k, tr) =>
			{
				const cells = attrTable(tr).find('td');
				if(cells.length >= 2)
				{
					const attrName = attrTable(cells[0]).text().trim().replace(/:$/, '');
					const attrValueCell = attrTable(cells[1]);
					const codeEl = attrValueCell.find('code');
					const attrValue = codeEl.length ? codeEl.text().trim() : attrValueCell.text().trim();
					if(attrName && attrValue)
					{
						fieldAttributes[attrName] = attrValue;
					}
				}
			});
		}

		// Extract Picklist Values
		const picklistValues = [];
		const picklistMatch = memberHtml.match(/<h4>Picklist Values<\/h4>[\s\S]*?<table[^>]*>([\s\S]*?)<\/table>/i);
		if(picklistMatch)
		{
			const picklistTable = cheerio.load(`<table>${picklistMatch[1]}</table>`);
			picklistTable('tr').each((k, tr) =>
			{
				const cells = picklistTable(tr).find('td');
				if(cells.length >= 3)
				{
					const apiName = picklistTable(cells[0]).text().trim();
					if(apiName && apiName !== 'API Name')
					{
						const label = picklistTable(cells[1]).text().trim();
						const active = picklistTable(cells[2]).text().trim().toLowerCase() === 'true';
						picklistValues.push({apiName, label, active});
					}
				}
			});
		}

		const typeWithLink = extractTypeLink(cheerioApi, sigDiv, cleanName);
		details.push({id, signature, description, fieldAttributes, picklistValues, typeWithLink});
	});

	return details;
}

/**
 * Extract detailed method information
 * @param {CheerioAPI} cheerioApi - Cheerio API
 * @param {string} cleanName - Clean name
 * @returns {Array} Method details
 */
// noinspection FunctionTooLongJS,OverlyComplexFunctionJS,JSValidateJSDoc
function extractMethodDetails(cheerioApi, cleanName)
{
	const details = [];

	// icapexdoc emits constructors in a separate `#members_constructors`
	// section. Without this selector, constructor summary rows in the methods
	// table (emitted by buildMembersSummary) link to anchors like #Builder
	// that never get a corresponding `### Builder` detail section, producing
	// dead links the anchor-resolution check catches.
	cheerioApi('#members_constructors .member, #members_methods .member').each((i, member) =>
	{
		const id = cheerioApi(member).attr('id') || '';
		const sigDiv = cheerioApi(member).find('.signature');
		const signature = normalizeSignature(sigDiv.text());

		// Extract parameter type links from signature
		const parameterTypes = [];
		const sigHtml = sigDiv.html() || '';

		const methodNameMatch = sigHtml.match(/<b>([^<]+)<\/b>\s*\(/);
		if(methodNameMatch)
		{
			const methodNameEnd = sigHtml.indexOf(methodNameMatch[0]) + methodNameMatch[0].length;
			const paramsSection = sigHtml.substring(methodNameEnd);

			const paramsDoc = cheerio.load(`<div>${paramsSection}</div>`);
			paramsDoc('a').each((j, link) =>
			{
				const href = paramsDoc(link).attr('href') || '';
				const text = paramsDoc(link).text().trim();
				if(text)
				{
					parameterTypes.push({name: text, href: fixLink(href, cleanName)});
				}
			});
		}

		const memberHtml = cheerioApi(member).html() || '';

		// Extract Parameters
		const parameters = [];
		const paramMatch = memberHtml.match(/<b>Parameters:<\/b>[\s\S]*?<table>([\s\S]*?)<\/table>/i);
		if(paramMatch)
		{
			const paramTable = cheerio.load(`<table>${paramMatch[1]}</table>`);
			paramTable('tr').each((k, tr) =>
			{
				const td = paramTable(tr).find('td').last();
				const paramText = td.text().trim();
				const paramParts = paramText.split(/\s+[–\-:]\s+/);
				if(paramParts.length >= 2)
				{
					parameters.push({
						name: paramParts[0].replace(/`/g, '').replace(/^code/, '').trim(), description: paramParts.slice(1).join(' - ').trim()
					});
				}
				else if(paramText)
				{
					const codeMatch = paramText.match(/^`?(\w+)`?\s*[-–:]\s*(.+)$/);
					if(codeMatch)
					{
						parameters.push({name: codeMatch[1], description: codeMatch[2]});
					}
					else
					{
						parameters.push({name: '', description: paramText});
					}
				}
			});
		}

		// Extract Returns
		let returns = '';
		const returnMatch = memberHtml.match(/<b>Returns:<\/b>[\s\S]*?<table>([\s\S]*?)<\/table>/i);
		if(returnMatch)
		{
			const returnTable = cheerio.load(`<table>${returnMatch[1]}</table>`);
			returns = htmlToMarkdown(returnTable('td').last().html() || '', false);
		}

		// Extract Exceptions
		const exceptions = [];
		const exceptionMatch = memberHtml.match(/<b>Exceptions:<\/b>[\s\S]*?<table>([\s\S]*?)<\/table>/i);
		if(exceptionMatch)
		{
			const exceptionTable = cheerio.load(`<table>${exceptionMatch[1]}</table>`);
			exceptionTable('tr').each((k, tr) =>
			{
				const td = exceptionTable(tr).find('td').last();
				const exceptionLink = td.find('a');
				let exceptionType = '';
				let exceptionTypeLink = '';

				if(exceptionLink.length)
				{
					exceptionType = exceptionLink.text().trim();
					exceptionTypeLink = fixLink(exceptionLink.attr('href') || '', cleanName);
				}

				const exceptionText = td.text().trim();
				const descParts = exceptionText.split(/\s+[–\-:]\s+/);
				const exceptionDesc = descParts.length >= 2 ? descParts.slice(1).join(' - ').trim() : '';

				if(exceptionType || exceptionDesc)
				{
					exceptions.push({type: exceptionType, typeLink: exceptionTypeLink, description: exceptionDesc});
				}
			});
		}

		// Extract Since
		let since = '';
		const sinceMatch = memberHtml.match(/<b>Since:<\/b>[\s\S]*?<table>([\s\S]*?)<\/table>/i);
		if(sinceMatch)
		{
			const sinceTable = cheerio.load(`<table>${sinceMatch[1]}</table>`);
			since = sinceTable('td').last().text().trim();
		}

		// Extract Example
		const example = extractExampleFromHtml(memberHtml);

		// Extract See Also
		const seeAlso = [];
		const seeMatch = memberHtml.match(/<b>See Also:<\/b>[\s\S]*?<table>([\s\S]*?)<\/table>/i);
		if(seeMatch)
		{
			const seeTable = cheerio.load(`<table>${seeMatch[1]}</table>`);
			seeTable('a').each((k, link) =>
			{
				const href = seeTable(link).attr('href') || '';
				const text = seeTable(link).text().trim();
				if(text)
				{
					seeAlso.push({text, href: fixLink(href, cleanName)});
				}
			});
		}

		// Get description
		let description = '';
		const contentDiv = cheerioApi(member).find('> div').not('.signature');
		contentDiv.each((j, div) =>
		{
			if(description)
			{
				return;
			}
			const divHtml = cheerioApi(div).html() || '';
			const cleanHtml = divHtml.replace(/^(<br\s*\/?>)+/gi, '');
			const beforeParams = cleanHtml.split(/<b>(Parameters|Returns|See Also|Exceptions|Example|Since):/i)[0];
			if(beforeParams)
			{
				description = htmlToMarkdown(beforeParams, true);
			}
		});

		// Extract return type with link
		let returnTypeWithLink = '';
		if(methodNameMatch)
		{
			const methodNameStart = sigHtml.indexOf(methodNameMatch[0]);
			if(methodNameStart > 0)
			{
				const beforeMethodName = sigHtml.substring(0, methodNameStart);
				const returnTypePart = cheerio.load(`<div>${beforeMethodName}</div>`);
				const returnTypeLink = returnTypePart('a').last();

				if(returnTypeLink.length)
				{
					const href = returnTypeLink.attr('href') || '';
					const text = returnTypeLink.text().trim();
					if(text && text.toLowerCase() !== 'void')
					{
						const fixedHref = fixLink(href, cleanName);
						returnTypeWithLink = fixedHref ? `[${text}](${fixedHref})` : text;
					}
				}
			}
		}

		details.push({
			id, signature, description, parameters, parameterTypes, returns, exceptions, since, example, seeAlso, returnTypeWithLink
		});
	});

	return details;
}

// ─────────────────────────────────────────────────────────────────────────────
// Markdown Generation Functions
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Generate YAML front matter
 * @param {Object} metadata - Metadata object
 * @param {string} formattedAuthor - Formatted author name
 * @returns {string} YAML front matter
 */
function generateFrontMatter(metadata, formattedAuthor)
{
	let md = '---\n';
	md += `title: "${metadata.title}"\n`;
	md += `type: ${metadata.docType}\n`;
	// Scope the reference-only card / heading-accent styling: VitePress applies
	// `frontmatter.pageClass` as a class on the doc container, so the theme CSS
	// can target `.reference` without affecting hand-written pages.
	md += 'pageClass: reference\n';
	if(metadata.description)
	{
		const escapedDesc = metadata.description.replace(/"/g, '\\"').replace(/\n/g, ' ').substring(0, 200);
		md += `description: "${escapedDesc}"\n`;
	}
	if(formattedAuthor)
	{
		md += `author: "${formattedAuthor}"\n`;
	}
	if(metadata.group)
	{
		md += `group: "${metadata.group}"\n`;
	}
	if(metadata.date)
	{
		md += `date: "${metadata.date}"\n`;
	}
	if(metadata.since)
	{
		md += `since: "${metadata.since}"\n`;
	}
	md += `category: ${metadata.category}\n`;
	md += '---\n\n';
	return md;
}

/**
 * Generate header section (title, badges, signature, extends/implements)
 * @param {Object} metadata - Metadata object
 * @param {Object} signatureInfo - Signature information
 * @returns {string} Header Markdown
 */
function generateHeader(metadata, signatureInfo)
{
	let md = `# ${metadata.title}\n\n`;

	// Metadata badges
	const badges = [];
	if(metadata.docType)
	{
		badges.push(`**${metadata.docType.charAt(0).toUpperCase() + metadata.docType.slice(1)}**`);
	}
	if(metadata.group)
	{
		badges.push(`Group: \`${metadata.group}\``);
	}
	if(badges.length > 0)
	{
		md += badges.join(' · ') + '\n\n';
	}

	// Class header card — the SAME `apex-member` card the method details use, so the top
	// of the page is visually cohesive with the members below instead of a run of loose
	// bold-label lines. The deeper "Usage Patterns" narrative (extendedDescription) stays
	// a full-width section after the card. Per-version `Since` is intentionally dropped:
	// with a single published doc version every type is "since 1.0", so the label carries
	// no information.
	md += '<div class="apex-member apex-class">\n\n';

	// Signature
	if(signatureInfo.text)
	{
		md += '```apex\n' + signatureInfo.text + '\n```\n\n';
	}

	// Extends
	if(signatureInfo.extendsInfo)
	{
		const ext = signatureInfo.extendsInfo;
		md += ext.href ? `**Extends:** [${ext.name}](${ext.href})\n\n` : `**Extends:** ${ext.name}\n\n`;
	}

	// Implements
	if(signatureInfo.implementsInfo && signatureInfo.implementsInfo.length > 0)
	{
		const impls = signatureInfo.implementsInfo.map(impl => impl.href ? `[${impl.name}](${impl.href})` : impl.name);
		md += `**Implements:** ${impls.join(', ')}\n\n`;
	}

	// Derived types
	if(metadata.derivedTypes.length > 0)
	{
		md += '**Known Derived Types:** ';
		md += metadata.derivedTypes.map(d => d.href ? `[${d.text}](${d.href})` : d.text).join(', ') + '\n\n';
	}

	// Description
	if(metadata.description)
	{
		md += metadata.description + '\n\n';
	}

	// Example (quick start; the deeper Usage Patterns section follows the card)
	if(metadata.example)
	{
		md += '**Example**\n\n' + metadata.example + '\n\n';
	}

	// See Also
	if(metadata.seeAlso.length > 0)
	{
		md += '**See Also:** ';
		md += metadata.seeAlso.map(s => s.href ? `[${s.text}](${s.href})` : s.text).join(', ') + '\n\n';
	}

	md += '</div>\n\n';

	// Usage Patterns narrative (extendedDescription) — a full-width section below the
	// header card, not crammed into it.
	if(metadata.extendedDescription)
	{
		md += metadata.extendedDescription + '\n\n';
	}

	md += '---\n\n';
	return md;
}

/**
 * Generate members summary tables
 * @param {Object} options - Generation options
 * @param {Object} options.membersSummary - Members summary
 * @param {Object} options.metadata - Metadata
 * @param {Object} options.signatureInfo - Signature info
 * @param {Array} options.enumConstantDetails - Enum constant details
 * @param {Array} options.propertyDetails - Property details
 * @param {Array} options.fieldDetails - Field details
 * @param {Array} options.sobjectFieldDetails - SObject field details
 * @returns {string} Summary Markdown
 */
// noinspection FunctionTooLongJS,OverlyComplexFunctionJS - Complex HTML to Markdown generation
function generateMembersSummary(options)
{
	const {membersSummary, metadata, signatureInfo, enumConstantDetails, propertyDetails, fieldDetails, sobjectFieldDetails} = options;
	let md = '';

	// Properties/Values Summary
	if(membersSummary.properties.length > 0)
	{
		const isEnum = metadata.docType === 'enum' || signatureInfo.text?.includes('enum ');
		const sectionTitle = isEnum ? 'Values' : 'Properties';
		const columnHeader = isEnum ? 'Value' : 'Property';

		md += `## ${sectionTitle}\n\n`;
		md += `| ${columnHeader} | Description |\n`;
		md += '|----------|-------------|\n';
		membersSummary.properties.forEach(p =>
		{
			const hasEnumDetail = enumConstantDetails.some(e => e.id === p.name);
			const hasPropertyDetail = propertyDetails.some(pd => pd.id === p.name);
			const hasDetail = hasEnumDetail || hasPropertyDetail;

			let nameLink;
			if(hasDetail)
			{
				nameLink = `[${p.name}](#${p.name.toLowerCase()})`;
			}
			else if(p.href)
			{
				nameLink = `[${p.name}](${p.href})`;
			}
			else
			{
				nameLink = p.name;
			}

			const typePart = p.typeInfo.full || p.typeInfo.type || '';
			const fullProperty = typePart ? `${typePart} ${nameLink}` : nameLink;
			md += `| ${fullProperty} | ${p.description} |\n`;
		});
		md += '\n';
	}

	// Fields/Constants Summary
	if(membersSummary.fields.length > 0)
	{
		const allAreConstants = membersSummary.fields.every(f =>
		{
			const mods = (f.typeInfo.modifiers || '').toLowerCase();
			return mods.includes('static') && mods.includes('final');
		});

		const sectionTitle = allAreConstants ? 'Constants' : 'Fields';
		const columnHeader = allAreConstants ? 'Constant' : 'Field';

		md += `## ${sectionTitle}\n\n`;
		md += `| ${columnHeader} | Description |\n`;
		md += '|-------|-------------|\n';
		membersSummary.fields.forEach(f =>
		{
			const hasDetail = fieldDetails.some(fd => fd.id === f.name) || sobjectFieldDetails.some(sf => sf.id === f.name);
			const nameLink = hasDetail ? `[${f.name}](#${f.name.toLowerCase()})` : f.name;
			const typePart = f.typeInfo.full || f.typeInfo.type || '';
			const fullField = typePart ? `${typePart} ${nameLink}` : nameLink;
			md += `| ${fullField} | ${f.description} |\n`;
		});
		md += '\n';
	}

	// Methods Summary
	if(membersSummary.methods.length > 0)
	{
		md += '## Methods\n\n';
		md += '| Method | Description |\n';
		md += '|--------|-------------|\n';
		membersSummary.methods.forEach(m =>
		{
			const methodNameLink = m.href ? `[${m.name}](${m.href})` : m.name;
			const paramsStart = m.fullSignature.indexOf('(');
			const paramsWithTypes = paramsStart >= 0 ? m.fullSignature.substring(paramsStart) : '';
			const returnPart = m.typeInfo.full || m.typeInfo.type || '';
			const fullMethod = returnPart ? `${returnPart} ${methodNameLink}${paramsWithTypes}` : `${methodNameLink}${paramsWithTypes}`;
			md += `| ${fullMethod} | ${m.description} |\n`;
		});
		md += '\n';
	}

	// Inner Classes Summary
	if(membersSummary.innerClasses.length > 0)
	{
		md += '## Inner Classes\n\n';
		md += '| Class | Description |\n';
		md += '|-------|-------------|\n';
		membersSummary.innerClasses.forEach(c =>
		{
			const nameLink = c.href ? `[${c.name}](${c.href})` : c.name;
			md += `| ${nameLink} | ${c.description} |\n`;
		});
		md += '\n';
	}

	return md;
}

/**
 * Generate property details section
 * @param {Array} propertyDetails - Property details
 * @returns {string} Details Markdown
 */
function generatePropertyDetails(propertyDetails)
{
	if(propertyDetails.length === 0)
	{
		return '';
	}

	let md = '---\n\n## Property Details\n\n';

	propertyDetails.forEach(p =>
	{
		md += `### ${p.id}\n\n`;
		md += '```apex\n' + p.signature + '\n```\n\n';
		if(p.typeWithLink)
		{
			md += `**Type:** ${p.typeWithLink}\n\n`;
		}
		if(p.description)
		{
			md += p.description + '\n\n';
		}
		if(p.seeAlso.length > 0)
		{
			md += '**See Also:** ' + p.seeAlso.map(s => s.href ? `[${s.text}](${s.href})` : s.text).join(', ') + '\n\n';
		}
	});

	return md;
}

/**
 * Generate enum value details section
 * @param {Array} enumConstantDetails - Enum constant details
 * @returns {string} Details Markdown
 */
function generateEnumValueDetails(enumConstantDetails)
{
	if(enumConstantDetails.length === 0)
	{
		return '';
	}

	let md = '---\n\n## Value Details\n\n';

	enumConstantDetails.forEach(e =>
	{
		md += `### ${e.id}\n\n`;
		if(e.signature)
		{
			md += '```apex\n' + e.signature + '\n```\n\n';
		}
		if(e.description)
		{
			md += e.description + '\n\n';
		}
		if(e.example)
		{
			md += '**Example**\n\n' + e.example + '\n\n';
		}
		if(e.seeAlso && e.seeAlso.length > 0)
		{
			md += '**See Also:** ' + e.seeAlso.map(s => s.href ? `[${s.text}](${s.href})` : s.text).join(', ') + '\n\n';
		}
	});

	return md;
}

/**
 * Escape a raw value for safe inclusion in a single GitHub-flavored-markdown
 * table cell: pipes become `\|`, and newlines / runs of whitespace collapse to
 * a single space (a GFM table cell cannot contain raw line breaks).
 * @param {*} value - Raw cell content
 * @returns {string} Escaped, single-line cell content
 */
function escapeTableCell(value)
{
	return String(value === null || value === undefined ? '' : value)
		.replace(/\r?\n/g, ' ')
		.replace(/\s+/g, ' ')
		.replace(/\|/g, '\\|')
		.trim();
}

/**
 * Wrap one member's body in the single minimal HTML element the reference theme
 * keys its "titled card" styling off (`<div class="apex-member">`). This wrapper
 * is the ONLY HTML emitted into the generated markdown — everything inside stays
 * pure markdown (fence, tables, bold labels, links) so the committed `.md` is
 * still clearly human-readable on GitHub and in editors.
 * @param {string} inner - Pure-markdown body for one method/overload
 * @returns {string} Inner markdown wrapped in the card element
 */
function wrapApexMember(inner)
{
	return '<div class="apex-member">\n\n' + inner + '</div>\n\n';
}

/**
 * Render a single method overload's body (signature block, description,
 * parameters table, returns line, throws table, example, see-also). Overloads of
 * the same name share one `###` heading emitted by the caller; this returns only
 * the per-overload body, wrapped in the `apex-member` card element.
 *
 * Output is pure markdown apart from the one card wrapper. Parameters/Throws are
 * GFM tables (the biggest scannability win); Returns is a single labeled line
 * (`**Returns** <type> — <prose>`); field labels drop their trailing colon so the
 * theme can style them as subheads. Per-overload `since` is intentionally not
 * emitted: with a single doc version every member is "since 1.0", so the
 * class-level Since (rendered once near the page title) carries it.
 * @param {Object} m - Method detail object (id, signature, description, parameters, etc.)
 * @returns {string} Markdown for the overload body (card-wrapped)
 */
// noinspection FunctionWithMultipleLoopsJS - Iterates over parameters and exceptions
function renderMethodOverload(m)
{
	let md = '```apex\n' + m.signature + '\n```\n\n';

	if(m.description)
	{
		md += m.description + '\n\n';
	}

	if(m.parameters.length > 0)
	{
		md += '**Parameters**\n\n';
		md += '| Parameter | Type | Description |\n';
		md += '|-----------|------|-------------|\n';
		m.parameters.forEach((param, idx) =>
		{
			const typeInfo = m.parameterTypes && m.parameterTypes[idx];
			let typeCell = '';
			if(typeInfo && typeInfo.href)
			{
				typeCell = `[${escapeTableCell(typeInfo.name)}](${typeInfo.href})`;
			}
			else if(typeInfo && typeInfo.name)
			{
				typeCell = escapeTableCell(typeInfo.name);
			}
			const nameCell = param.name ? `\`${escapeTableCell(param.name)}\`` : '';
			md += `| ${nameCell} | ${typeCell} | ${escapeTableCell(param.description)} |\n`;
		});
		md += '\n';
	}

	// Returns → one labeled line; an em-dash separates the type link from the
	// prose. No line for void (neither returns prose nor a linkable type).
	if(m.returns || m.returnTypeWithLink)
	{
		if(m.returnTypeWithLink && m.returns)
		{
			md += `**Returns** ${m.returnTypeWithLink} — ${m.returns}\n\n`;
		}
		else if(m.returnTypeWithLink)
		{
			md += `**Returns** ${m.returnTypeWithLink}\n\n`;
		}
		else
		{
			md += `**Returns** ${m.returns}\n\n`;
		}
	}

	if(m.exceptions && m.exceptions.length > 0)
	{
		md += '**Throws**\n\n';
		md += '| Exception | Description |\n';
		md += '|-----------|-------------|\n';
		m.exceptions.forEach(exc =>
		{
			const typeStr = exc.typeLink ? `[${escapeTableCell(exc.type)}](${exc.typeLink})` : escapeTableCell(exc.type || 'Exception');
			md += `| ${typeStr} | ${escapeTableCell(exc.description)} |\n`;
		});
		md += '\n';
	}

	if(m.example)
	{
		md += '**Example**\n\n' + m.example + '\n\n';
	}

	if(m.seeAlso.length > 0)
	{
		md += '**See Also** ' + m.seeAlso.map(s => s.href ? `[${s.text}](${s.href})` : s.text).join(', ') + '\n\n';
	}

	return wrapApexMember(md);
}

/**
 * Generate method details section with parameters, return types, and exceptions
 * @param {Array<Object>} methodDetails - Array of method detail objects containing id, signature, description, parameters, etc.
 * @returns {string} Markdown string with method details section
 */
// noinspection FunctionWithMultipleLoopsJS - Iterates over methods and their parameters/exceptions
function generateMethodDetails(methodDetails)
{
	if(methodDetails.length === 0)
	{
		return '';
	}

	let md = '---\n\n## Method Details\n\n';

	// Group overloads by method name so the right-rail "On this page" outline lists
	// each name once. Each overload keeps its own signature block + parameters /
	// returns beneath the shared heading. Summary-table links target `#name`, which
	// now resolves to this single heading rather than an arbitrary `-1` duplicate.
	const groups = [];
	const groupIndex = new Map();
	methodDetails.forEach(m =>
	{
		const name = m.id.split('(')[0];
		if(!groupIndex.has(name))
		{
			groupIndex.set(name, groups.length);
			groups.push({name, overloads: []});
		}
		groups[groupIndex.get(name)].overloads.push(m);
	});

	groups.forEach(group =>
	{
		md += `### ${group.name}\n\n`;
		group.overloads.forEach(m =>
		{
			md += renderMethodOverload(m);
		});
	});

	return md;
}

/**
 * Generate field/constant details section
 * @param {Array} fieldDetails - Field details
 * @param {Object} membersSummary - Members summary (for constant detection)
 * @returns {string} Details Markdown
 */
function generateFieldDetails(fieldDetails, membersSummary)
{
	if(fieldDetails.length === 0)
	{
		return '';
	}

	const allAreConstants = membersSummary.fields.every(f =>
	{
		const mods = (f.typeInfo.modifiers || '').toLowerCase();
		return mods.includes('static') && mods.includes('final');
	});
	const detailSectionTitle = allAreConstants ? 'Constant Details' : 'Field Details';

	let md = '---\n\n## ' + detailSectionTitle + '\n\n';

	fieldDetails.forEach(f =>
	{
		md += `### ${f.id}\n\n`;
		md += '```apex\n' + f.signature + '\n```\n\n';
		if(f.typeWithLink)
		{
			md += `**Type:** ${f.typeWithLink}\n\n`;
		}
		if(f.description)
		{
			md += f.description + '\n\n';
		}
		if(f.example)
		{
			md += '**Example**\n\n' + f.example + '\n\n';
		}
		if(f.seeAlso.length > 0)
		{
			md += '**See Also:** ' + f.seeAlso.map(s => s.href ? `[${s.text}](${s.href})` : s.text).join(', ') + '\n\n';
		}
	});

	return md;
}

/**
 * Generate SObject field details section
 * @param {Array<Object>} sobjectFieldDetails - Array of SObject field detail objects with attributes and picklist values
 * @returns {string} Markdown string with SObject field details section including attribute tables and picklist values
 */
// noinspection FunctionWithMultipleLoopsJS - Iterates over fields, attributes, and picklist values
function generateSObjectFieldDetails(sobjectFieldDetails)
{
	if(sobjectFieldDetails.length === 0)
	{
		return '';
	}

	let md = '---\n\n## Field Details\n\n';

	sobjectFieldDetails.forEach(f =>
	{
		md += `### ${f.id}\n\n`;
		md += '```apex\n' + f.signature + '\n```\n\n';

		if(f.description)
		{
			md += f.description + '\n\n';
		}

		// Field Attributes table
		if(Object.keys(f.fieldAttributes).length > 0)
		{
			md += '**Field Attributes:**\n\n';
			md += '| Attribute | Value |\n';
			md += '|-----------|-------|\n';

			const orderedAttrs = [];
			FIELD_ATTRIBUTE_ORDER.forEach(attr =>
			{
				if(f.fieldAttributes[attr] !== undefined)
				{
					orderedAttrs.push(attr);
				}
			});
			Object.keys(f.fieldAttributes).forEach(attr =>
			{
				if(!orderedAttrs.includes(attr))
				{
					orderedAttrs.push(attr);
				}
			});

			orderedAttrs.forEach(attr =>
			{
				let value = f.fieldAttributes[attr];
				if(attr === 'Formula')
				{
					value = `\`${value}\``;
				}
				md += `| ${attr} | ${value} |\n`;
			});
			md += '\n';
		}

		// Picklist Values table
		if(f.picklistValues.length > 0)
		{
			md += '**Picklist Values:**\n\n';
			md += '| API Name | Label | Active |\n';
			md += '|----------|-------|--------|\n';
			f.picklistValues.forEach(pv =>
			{
				md += `| \`${pv.apiName}\` | ${pv.label} | ${pv.active ? 'Yes' : 'No'} |\n`;
			});
			md += '\n';
		}
	});

	return md;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Conversion Function
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Generate the Markdown content for a file
 * @param {string} filePath - Path to HTML file
 * @returns {Object|null} Metadata or null if skipped
 */
// noinspection FunctionWithMultipleReturnPointsJS,FunctionTooLongJS,OverlyComplexFunctionJS,FunctionWithMultipleLoopsJS
function convertFile(filePath)
{
	let html = fs.readFileSync(filePath, 'utf8');

	// Pre-process HTML to fix <p/> inside code blocks before cheerio mangles it.
	// IcApexDoc uses <p/> to represent blank lines in @example blocks, but cheerio
	// incorrectly "fixes" this by breaking the code block: </code><p>...</p><code>
	// We replace <p/> with a placeholder that survives cheerio, then restore later.
	html = html.replace(/<pre><code([^>]*)>([\s\S]*?)<\/code>\s*<\/pre>/gi, (match, attrs, content) =>
	{
		// Replace <p/> with actual newlines inside code blocks
		const fixedContent = content.replace(/<p\s*\/?>/gi, '\n');
		return `<pre><code${attrs}>${fixedContent}</code></pre>`;
	});

	// noinspection LocalVariableNamingConventionJS - $ is Cheerio convention
	const $ = cheerio.load(html);

	if(!$('#TopLevelDeclaration').length)
	{
		return null;
	}

	const metadata = extractMetadata($, filePath);
	const signatureInfo = extractSignature($, metadata.cleanName);
	const formattedAuthor = formatAuthorName(metadata.author);
	const membersSummary = buildMembersSummary($, metadata.cleanName);
	const propertyDetails = extractPropertyDetails($, metadata.cleanName);
	const fieldDetails = extractFieldDetails($, metadata.cleanName);
	const enumConstantDetails = extractEnumConstantDetails($, metadata.cleanName);
	const methodDetails = extractMethodDetails($, metadata.cleanName);
	const sobjectFieldDetails = extractSObjectFieldDetails($, metadata.cleanName);

	// Fill in missing method descriptions
	if(membersSummary.methods.length > 0 && methodDetails.length > 0)
	{
		const descriptionMap = new Map();
		methodDetails.forEach(m =>
		{
			if(m.description)
			{
				let summary = htmlToMarkdown(m.description);
				const sentenceEnd = summary.match(/[.!?](\s|$)/);
				if(sentenceEnd)
				{
					summary = summary.substring(0, sentenceEnd.index + 1);
				}
				if(summary.length > MAX_SUMMARY_LENGTH)
				{
					summary = summary.substring(0, TRUNCATED_SUMMARY_LENGTH) + '...';
				}
				descriptionMap.set(m.id, summary);
			}
		});

		membersSummary.methods.forEach(m =>
		{
			if(!m.description || m.description === '&nbsp;')
			{
				const methodName = m.name;
				for(const [id, desc] of descriptionMap)
				{
					if(id === methodName || id.startsWith(methodName + '('))
					{
						const idParams = id.includes('(') ? id.substring(id.indexOf('(')) : '';
						const mParams = m.fullSignature.includes('(') ? m.fullSignature.substring(m.fullSignature.indexOf('(')) : '';

						const idParamCount = (idParams.match(/,/g) || []).length + (idParams.includes('(') && !idParams.includes('()') ? 1 : 0);
						const mParamCount = (mParams.match(/,/g) || []).length + (mParams.includes('(') && !mParams.includes('()') ? 1 : 0);

						if(idParamCount === mParamCount)
						{
							m.description = desc;
							// noinspection BreakStatementJS - Valid control flow: stop searching once match found
							break;
						}
					}
				}
			}
		});
	}

	// Qualify inner class exception references in method @throws
	if(membersSummary.innerClasses.length > 0)
	{
		const innerClassNames = new Set(membersSummary.innerClasses.map(c => c.name));
		methodDetails.forEach(method =>
		{
			method.exceptions.forEach(ex =>
			{
				if(ex.typeLink && ex.typeLink.endsWith('.md') && !ex.typeLink.slice(0, -3).includes('.'))
				{
					const unqualifiedName = ex.typeLink.replace('.md', '');
					if(innerClassNames.has(unqualifiedName))
					{
						ex.typeLink = `${metadata.cleanName}.${ex.typeLink}`;
					}
				}
			});
		});
	}

	// Build Markdown document
	let md = generateFrontMatter(metadata, formattedAuthor);
	md += generateHeader(metadata, signatureInfo);
	md += generateMembersSummary({membersSummary, metadata, signatureInfo, enumConstantDetails, propertyDetails, fieldDetails, sobjectFieldDetails});
	md += generatePropertyDetails(propertyDetails);
	md += generateEnumValueDetails(enumConstantDetails);
	md += generateMethodDetails(methodDetails);
	md += generateFieldDetails(fieldDetails, membersSummary);
	md += generateSObjectFieldDetails(sobjectFieldDetails);

	// Write file
	const categoryDir = path.join(CONFIG.outputDir, metadata.category);
	if(!fs.existsSync(categoryDir))
	{
		fs.mkdirSync(categoryDir, {recursive: true});
	}

	const outputName = metadata.cleanName + '.md';
	const outputPath = path.join(categoryDir, outputName);
	fs.writeFileSync(outputPath, md);

	console.log(`  ✅ ${metadata.cleanName}`);

	return {...metadata, outputName, formattedAuthor};
}

// ─────────────────────────────────────────────────────────────────────────────
// Index Generation
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Generate index files
 * @param {Array} allMetadata - All metadata
 */
// noinspection FunctionTooLongJS,FunctionWithMultipleLoopsJS - Generates category and master indexes
function generateIndexes(allMetadata)
{
	const categories = {};

	allMetadata.forEach(meta =>
	{
		if(!categories[meta.category])
		{
			categories[meta.category] = [];
		}
		categories[meta.category].push(meta);
	});

	// Generate category indexes
	Object.entries(categories).forEach(([category, items]) =>
	{
		items.sort((a, b) => a.title.localeCompare(b.title));

		const info = CATEGORY_INFO[category] || {title: category, description: ''};

		let content = `# ${info.title}\n\n`;
		content += `> ${info.description}\n\n`;
		content += `**${items.length} items** in this category.\n\n`;
		content += '---\n\n';

		// Group by @group annotation
		const byGroup = {};
		items.forEach(item =>
		{
			const group = item.group || 'Other';
			if(!byGroup[group])
			{
				byGroup[group] = [];
			}
			byGroup[group].push(item);
		});

		// noinspection FunctionWithMultipleReturnPointsJS
		const sortedGroups = Object.keys(byGroup).sort((a, b) =>
		{
			if(a === 'Other')
			{
				return 1;
			}
			if(b === 'Other')
			{
				return -1;
			}
			return a.localeCompare(b);
		});

		sortedGroups.forEach(groupName =>
		{
			const groupItems = byGroup[groupName];
			content += `## ${groupName}\n\n`;
			content += '| Name | Description |\n';
			content += '|------|-------------|\n';

			groupItems.forEach(item =>
			{
				const desc = (item.description || '').substring(0, 100).replace(/\|/g, '\\|').replace(/\n/g, ' ');
				content += `| [${item.title}](${item.outputName}) | ${desc} |\n`;
			});
			content += '\n';
		});

		const indexPath = path.join(CONFIG.outputDir, category, 'index.md');
		fs.writeFileSync(indexPath, content);
		console.log(`  📑 ${category}/index.md (${items.length} items)`);
	});

	// Generate master index
	const masterIndexPath = path.join(CONFIG.outputDir, 'index.md');
	generateMasterIndex(categories, masterIndexPath);
}

/**
 * Framework area definitions for the master index.
 * Maps @group values to display info and highlighted core classes.
 */
const FRAMEWORK_AREAS = [
	{
		group: 'Query Infrastructure',
		title: 'Query Infrastructure',
		description: 'Fluent SOQL builder, bind registry, conditions, and query engine. Use `QRY_Builder` for 95% of queries.',
		highlights: [
			'QRY_Builder',
			'QRY_Condition'
		]
	},
	{
		group: 'Selectors',
		title: 'Selectors',
		description: 'Object-specific query classes that extend `SEL_Base`. Define default fields and provide type-safe record retrieval via `findById()`, `findByField()`, and custom query methods.',
		highlights: ['SEL_Base']
	},
	{
		group: 'DML',
		title: 'DML and Unit of Work',
		description: 'Transactional DML with dependency management, partial success handling, and sharing enforcement. Use `DML_Builder.newTransaction()` for all DML operations.',
		highlights: [
			'DML_Builder',
			'DML_Transaction'
		]
	},
	{
		group: 'Triggers',
		title: 'Trigger Framework',
		description: 'Metadata-driven trigger dispatch. Configure trigger actions via `TriggerAction__mdt` custom metadata. Extend `TRG_Base` and implement `IF_Trigger` event interfaces.',
		highlights: [
			'TRG_Dispatcher',
			'TRG_Base',
			'IF_Trigger'
		]
	},
	{
		group: 'Web Services',
		title: 'Web Services',
		description: 'REST integration framework with automatic retry, circuit breaking, and queue-based processing. Configure endpoints via `ApiSetting__mdt`.',
		highlights: [
			'API_Outbound',
			'API_Inbound',
			'API_OutboundMock',
			'API_OutboundTestHelper'
		]
	},
	{
		group: 'Data Transfer Objects',
		title: 'Data Transfer Objects',
		description: 'Base classes for JSON and XML serialization. All DTOs extend `DTO_JsonBase` and support automatic population from SObject records.',
		highlights: [
			'DTO_JsonBase',
			'DTO_Base',
			'DTO_NameValues'
		]
	},
	{
		group: 'Logging',
		title: 'Logging',
		description: 'Platform event-based async logging with correlation IDs, structured context, and configurable filtering.',
		highlights: ['LOG_Builder']
	},
	{
		group: 'Feature Flags',
		title: 'Feature Flags',
		description: 'Runtime feature toggling with custom metadata configuration and pluggable evaluation strategies.',
		highlights: ['UTIL_FeatureFlag']
	},
	{
		group: 'Resilience',
		title: 'Resilience Patterns',
		description: 'Circuit breaker, retry strategies (linear, exponential), and platform cache management for fault-tolerant integrations.',
		highlights: [
			'UTIL_CircuitBreaker',
			'UTIL_Retry',
			'UTIL_Cache'
		]
	},
	{
		group: 'Async Processing',
		title: 'Async Processing',
		description: 'Adaptive async job launching that automatically selects the optimal execution strategy (batch, queueable, future).',
		highlights: [
			'UTIL_AsynchronousJobLauncher',
			'UTIL_AdaptiveAsynchronousProcessor'
		]
	},
	{
		group: 'Utilities',
		title: 'Utilities',
		description: 'Common utilities for strings, dates, numbers, collections, security, encryption, and system reflection.',
		highlights: [
			'UTIL_String',
			'UTIL_Date',
			'UTIL_Number',
			'UTIL_List',
			'UTIL_Map',
			'UTIL_Set',
			'UTIL_Security'
		]
	},
	{
		group: 'Controllers', title: 'Controllers', description: 'Aura and LWC server-side controllers for UI components.', highlights: []
	},
	{
		group: 'Schedulables', title: 'Schedulables', description: 'Configurable scheduled jobs with metadata-driven scheduling and batch size control.', highlights: []
	},
	{
		group: 'Bulk DML', title: 'Bulk DML', description: 'Batch processors for high-volume field updates and aggregation operations.', highlights: []
	},
	{
		group: 'Testing',
		title: 'Testing',
		description: 'Test data factories, mock builders, and test helpers. Use `TST_Builder` for record creation and `TST_Mock` for DML-free query interception.',
		highlights: [
			'TST_Builder',
			'TST_Factory',
			'TST_Mock'
		]
	}
];

/**
 * Generate auto-generated master index file with TOC, framework area sections, and core class links.
 * @param {Object} categories - Categories object with items per category
 * @param {string} masterIndexPath - Path to master index file
 */
// noinspection FunctionTooLongJS - Master index generation requires building multiple sections
function generateMasterIndex(categories, masterIndexPath)
{
	const apexItems = categories.apex || [];

	// Group apex items by @group
	const groupedApex = {};
	apexItems.forEach(item =>
	{
		const group = item.group || 'Uncategorized';
		if(!groupedApex[group])
		{
			groupedApex[group] = [];
		}
		groupedApex[group].push(item);
	});

	// Sort items within each group alphabetically
	Object.values(groupedApex).forEach(items => items.sort((a, b) => a.cleanName.localeCompare(b.cleanName)));

	let totalCount = 0;
	Object.values(categories).forEach(items =>
	{
		totalCount += items.length;
	});

	let md = '# KernDX API Reference\n\n';
	md += '> Auto-generated documentation for the KernDX Framework\n\n';
	md += '---\n\n';

	// Table of Contents
	md += '## Table of Contents\n\n';
	md += '1. [Overview](#overview)\n';
	md += '2. [Quick Links by Use Case](#quick-links-by-use-case)\n';
	md += '3. [Apex Classes](#apex-classes)\n';

	FRAMEWORK_AREAS.forEach(area =>
	{
		if(groupedApex[area.group]?.length > 0)
		{
			const anchor = area.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
			md += `   - [${area.title}](#${anchor})\n`;
		}
	});

	// Add any groups not in FRAMEWORK_AREAS
	Object.keys(groupedApex).forEach(group =>
	{
		if(!FRAMEWORK_AREAS.find(a => a.group === group))
		{
			const anchor = group.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
			md += `   - [${group}](#${anchor})\n`;
		}
	});

	if(categories.objects?.length > 0)
	{
		md += '4. [Custom Objects](#custom-objects)\n';
	}
	if(categories.events?.length > 0)
	{
		md += '5. [Platform Events](#platform-events)\n';
	}
	if(categories.metadata?.length > 0)
	{
		md += '6. [Custom Metadata Types](#custom-metadata-types)\n';
	}

	md += '\n---\n\n';

	// Overview
	md += '## Overview\n\n';
	md += `This reference contains **${totalCount} documented items** across the following categories:\n\n`;
	md += '| Category | Items | Description | Browse |\n';
	md += '|----------|-------|-------------|--------|\n';

	Object.entries(categories).forEach(([cat, items]) =>
	{
		const info = CATEGORY_INFO[cat] || {title: cat, description: ''};
		md += `| **${info.title}** | ${items.length} | ${info.description} | [Browse All](${cat}/index.md) |\n`;
	});

	md += '\n---\n\n';

	// Quick Links by Use Case
	md += '## Quick Links by Use Case\n\n';
	md += '### I Need To...\n\n';
	md += '| Use Case | Primary Class | Related Classes |\n';
	md += '|----------|---------------|-----------------|\n';

	const useCases = [
		{use: 'Build SOQL queries', primary: 'QRY_Builder', related: ['QRY_Condition']},
		{use: 'Simple record lookup', primary: 'SEL_Base', related: []},
		{
			use: 'Create trigger actions', primary: 'TRG_Dispatcher', related: [
				'TRG_Base',
				'IF_Trigger'
			]
		},
		{
			use: 'Make REST API calls', primary: 'API_Outbound', related: [
				'API_OutboundMock',
				'DTO_JsonBase'
			]
		},
		{use: 'Handle inbound APIs', primary: 'API_Inbound', related: []},
		{use: 'Transactional DML', primary: 'DML_Builder', related: ['DML_Transaction']},
		{use: 'Log application events', primary: 'LOG_Builder', related: []},
		{
			use: 'Create test data', primary: 'TST_Builder', related: [
				'TST_Factory',
				'TST_Mock'
			]
		},
		{use: 'Check feature flags', primary: 'UTIL_FeatureFlag', related: []},
		{use: 'Implement circuit breaker', primary: 'UTIL_CircuitBreaker', related: ['UTIL_Retry']},
		{use: 'Work with strings', primary: 'UTIL_String', related: []},
		{use: 'Work with dates', primary: 'UTIL_Date', related: []},
		{
			use: 'Work with collections', primary: 'UTIL_List', related: [
				'UTIL_Map',
				'UTIL_Set'
			]
		}
	];

	useCases.forEach(uc =>
	{
		const primaryExists = apexItems.find(i => i.cleanName === uc.primary);
		const primaryLink = primaryExists ? `[${uc.primary}](apex/${uc.primary}.md)` : uc.primary;
		const relatedLinks = uc.related
		.map(r =>
		{
			const exists = apexItems.find(i => i.cleanName === r);
			return exists ? `[${r}](apex/${r}.md)` : r;
		})
		.join(', ');
		md += `| **${uc.use}** | ${primaryLink} | ${relatedLinks || '-'} |\n`;
	});

	md += '\n---\n\n';

	// Apex Classes by Framework Area
	md += '## Apex Classes\n\n';

	FRAMEWORK_AREAS.forEach(area =>
	{
		const items = groupedApex[area.group];
		if(!items || items.length === 0)
		{
			return;
		}

		md += `### ${area.title}\n\n`;
		md += `${area.description}\n\n`;

		// Highlighted core classes first
		if(area.highlights.length > 0)
		{
			const existingHighlights = area.highlights.filter(h => items.find(i => i.cleanName === h));
			if(existingHighlights.length > 0)
			{
				md += '| Class | Description |\n';
				md += '|-------|-------------|\n';

				existingHighlights.forEach(h =>
				{
					const item = items.find(i => i.cleanName === h);
					const desc = item.description ? truncateDescription(item.description) : '';
					md += `| [${h}](apex/${h}.md) | ${desc} |\n`;
				});

				// Remaining non-highlighted, non-test classes
				const remaining = items.filter(i => !area.highlights.includes(i.cleanName) && !i.cleanName.endsWith('_TEST'));
				if(remaining.length > 0)
				{
					remaining.forEach(item =>
					{
						const desc = item.description ? truncateDescription(item.description) : '';
						md += `| [${item.cleanName}](apex/${item.cleanName}.md) | ${desc} |\n`;
					});
				}

				md += '\n';
			}
		}
		else
		{
			// No highlights - list all non-test classes
			const nonTest = items.filter(i => !i.cleanName.endsWith('_TEST'));
			if(nonTest.length > 0)
			{
				md += '| Class | Description |\n';
				md += '|-------|-------------|\n';
				nonTest.forEach(item =>
				{
					const desc = item.description ? truncateDescription(item.description) : '';
					md += `| [${item.cleanName}](apex/${item.cleanName}.md) | ${desc} |\n`;
				});
				md += '\n';
			}
		}
	});

	// Any remaining groups not in FRAMEWORK_AREAS
	Object.entries(groupedApex).forEach(([group, items]) =>
	{
		if(FRAMEWORK_AREAS.find(a => a.group === group))
		{
			return;
		}

		md += `### ${group}\n\n`;
		const nonTest = items.filter(i => !i.cleanName.endsWith('_TEST'));
		if(nonTest.length > 0)
		{
			md += '| Class | Description |\n';
			md += '|-------|-------------|\n';
			nonTest.forEach(item =>
			{
				const desc = item.description ? truncateDescription(item.description) : '';
				md += `| [${item.cleanName}](apex/${item.cleanName}.md) | ${desc} |\n`;
			});
			md += '\n';
		}
	});

	md += '---\n\n';

	// Non-apex categories
	const nonApexSections = [
		{key: 'objects', title: 'Custom Objects'},
		{key: 'events', title: 'Platform Events'},
		{key: 'metadata', title: 'Custom Metadata Types'}
	];

	nonApexSections.forEach(section =>
	{
		const items = categories[section.key];
		if(!items || items.length === 0)
		{
			return;
		}

		md += `## ${section.title}\n\n`;
		md += `| ${section.key === 'events' ? 'Event' : section.key === 'metadata' ? 'Metadata' : 'Object'} | Description |\n`;
		md += '|--------|-------------|\n';
		items.sort((a, b) => a.cleanName.localeCompare(b.cleanName)).forEach(item =>
		{
			const desc = item.description ? truncateDescription(item.description) : '';
			md += `| [${item.cleanName}](${section.key}/${item.cleanName}.md) | ${desc} |\n`;
		});
		md += '\n---\n\n';
	});

	md += `*Generated from IcApexDoc*\n`;

	fs.writeFileSync(masterIndexPath, md);
	console.log(`  📑 index.md (master)`);
}

/**
 * Truncate a description to a reasonable length for index tables.
 * @param {string} desc - Full description text
 * @returns {string} Truncated description
 */
function truncateDescription(desc)
{
	if(!desc)
	{
		return '';
	}
	// Take first sentence
	const sentenceEnd = desc.match(/[.!?](\s|$)/);
	let result = sentenceEnd ? desc.substring(0, sentenceEnd.index + 1) : desc;
	if(result.length > 120)
	{
		result = result.substring(0, 117) + '...';
	}
	return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Execution
// ─────────────────────────────────────────────────────────────────────────────

// Only run if executed directly (not imported)
if(require.main === module)
{
	console.log('╔════════════════════════════════════════════════════════════╗');
	console.log('║   IcApexDoc → Enterprise Markdown Converter v3.21.0       ║');
	console.log('╚════════════════════════════════════════════════════════════╝\n');

	if(!fs.existsSync(CONFIG.inputDir))
	{
		console.error(`❌ Input not found: ${CONFIG.inputDir}`);
		console.log('   Run IcApexDoc in IntelliJ first.');
		process.exit(1);
	}

	// Clean up output directory
	if(fs.existsSync(CONFIG.outputDir))
	{
		console.log('🧹 Cleaning output directory...');

		const legacyIndexFiles = glob.sync(path.join(CONFIG.outputDir, '**/_index.md'));
		legacyIndexFiles.forEach(f =>
		{
			fs.unlinkSync(f);
			console.log(`  Removed legacy: ${path.relative(CONFIG.outputDir, f)}`);
		});

		const existingMdFiles = glob.sync(path.join(CONFIG.outputDir, '**/*.md'));
		existingMdFiles.forEach(f => fs.unlinkSync(f));
		console.log(`  Removed ${existingMdFiles.length} existing .md files\n`);
	}

	const htmlFiles = glob.sync(path.join(CONFIG.inputDir, '*.html'))
	.filter(f => !CONFIG.skipFiles.includes(path.basename(f)))
	.filter(f => !CONFIG.skipPatterns.some(p => p.test(path.basename(f))));

	console.log(`📂 Found ${htmlFiles.length} HTML files\n`);
	console.log('Converting...\n');

	const results = [];
	let errorCount = 0;

	htmlFiles.forEach(file =>
	{
		try
		{
			const result = convertFile(file);
			if(result)
			{
				results.push(result);
			}
		}
		catch(err)
		{
			console.error(`  ❌ ${path.basename(file)}: ${err.message}`);
			errorCount++;
		}
	});

	console.log('\nGenerating indexes...\n');
	generateIndexes(results);

	console.log('\n╔════════════════════════════════════════════════════════════╗');
	console.log(`║   ✨ Complete: ${results.length} files converted                        ║`);
	if(errorCount > 0)
	{
		console.log(`║   ⚠️  ${errorCount} errors encountered                                  ║`);
	}
	console.log('╚════════════════════════════════════════════════════════════╝\n');

	console.log(`Output: ${CONFIG.outputDir}/`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Exports for Testing
// ─────────────────────────────────────────────────────────────────────────────

// noinspection JSUnusedGlobalSymbols - Exported for external unit testing
module.exports = {
	// Text processing
	formatAuthorName,
	fixLink,
	normalizeSignature,
	htmlToMarkdown,
	extractModifiers,
	parseDocumentType,
	determineCategory, // HTML extraction helpers
	extractExampleFromHtml,
	removeMetadataSections,
	extractSeeAlsoLinks,
	extractBasicMemberInfo,
	extractTypeLink,
	linkToMarkdown,
	extractSignature, // Main extraction functions
	extractMetadata,
	buildMembersSummary,
	extractPropertyDetails,
	extractEnumConstantDetails,
	extractMethodDetails,
	extractFieldDetails,
	extractSObjectFieldDetails,
	extractMemberDetailsWithExample,
	extractTypeWithLink, // Markdown generation
	generateFrontMatter,
	generateHeader,
	generateMembersSummary,
	generatePropertyDetailsMd: generatePropertyDetails,
	generateEnumValueDetailsMd: generateEnumValueDetails,
	generateMethodDetailsMd: generateMethodDetails,
	generateFieldDetailsMd: generateFieldDetails,
	generateSObjectFieldDetailsMd: generateSObjectFieldDetails, // Main functions
	convertFile,
	generateIndexes, // Constants
	CONFIG,
	APEX_MODIFIERS,
	MAX_SUMMARY_LENGTH,
	TRUNCATED_SUMMARY_LENGTH,
	DOC_TYPE_SUFFIXES,
	CATEGORY_INFO,
	FIELD_ATTRIBUTE_ORDER
};
