// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * @description The static checks that keep a shipped guide in the step shape: every terminal block is written in the
 *              portable command subset or is one half of a labelled Windows and macOS pair on the allow-list, no
 *              PowerShell or lookalike fence, every step says where to act and what the reader should see, no
 *              command sits inside a sentence, every step reference resolves, and headings nest. The module reads
 *              only the content it is given and returns issues in the docs validator's own shape.
 */

const TOOL_NAMES = new Set(['sf', 'npm', 'npx', 'node', 'git', 'nvm', 'powershell']);
const ACTION_LANGUAGES = new Set(['shell', 'bat', 'bash', 'apex', 'xml', 'json', 'javascript', 'html', 'css', 'soql', 'yaml']);
const REFUSED_LANGUAGES = new Set(['powershell', 'sh', 'zsh', 'cmd', 'batch', 'console', 'dos', 'pwsh', 'ps', 'ps1', 'terminal', 'command', 'shell-session', 'bash-session']);
const UNIX_ONLY_TOOLS = new Set([
	'ls', 'cat', 'grep', 'find', 'jq', 'cp', 'mv', 'rm', 'chmod', 'sed', 'awk', 'head', 'tail', 'unzip', 'dig', 'which', 'touch', 'source', 'sudo', 'less', 'diff'
]);
const WINDOWS_LABEL = '**Windows (Command Prompt)**';
const OTHER_LABEL = '**macOS or Linux**';
const WHERE_LABEL = /\*\*(?:\d+\. )?In (?:the terminal|your editor|Salesforce)\*\*/;
const STEP_HEADING = /^Step (\d+(?:\.\d+)?)\b/;
const STEP_REFERENCE = /\bStep (\d+(?:\.\d+)?)\b/g;
const INLINE_SPAN = /`([^`\n]+)`/g;
const FAQ_LINK = /Something went wrong\? See \[(?:Common Issues, Step \d+(?:\.\d+)?|Common Issues|Troubleshooting)]\(#[^)]+\)/;
const SHARED_PAGE_LINK = /]\(Set%20Up%20Your%20Computer\.md/;
const STILL_STUCK = /Still stuck\? \[Tell us]\(https:\/\/github\.com\//;
const FAQ_HEADING = 'Common Issues';
const FAQ_HEADINGS = new Set([FAQ_HEADING, 'Troubleshooting']);
const STEP_SHAPED_GUIDE = /^docs\/(?:Installation\.md$|Fast Start - )/;
const READINESS_HEADING = 'Before you start';
const READINESS_LINK = /]\(Set%20Up%20Your%20Computer\.md#check-you-are-ready\)/;
const FENCE_OPEN = /^[ \t]*```([^\s`]*)/;
const FENCE_CLOSE = /^[ \t]*```\s*$/;
const HEADING = /^(#{1,6})[ \t]+(.+?)[ \t]*$/;

/**
 * @description The one place a shell block may print --ignore-conflicts: the shared page's failure entry that gives
 *              the flag as the remedy for a conflict.
 */
const IGNORE_CONFLICTS_ENTRY = {surface: 'docs/Set Up Your Computer.md', heading: 'The deploy reports a conflict'};

/**
 * @description The command forms the portable subset bans, each with the words the message uses for it. A form with
 *              an allowedUnder names the one surface and heading where it may appear.
 */
const BANNED_FORMS = [
	{name: '--target-org, where the one spelling is -o YourOrgAlias', test: line => /(?:^|\s)--target-org(?=[\s=]|$)/.test(line)},
	{
		name: '--ignore-conflicts, which only the conflict entry on Set Up Your Computer gives',
		test: line => /(?:^|\s)--ignore-conflicts(?=\s|$)/.test(line),
		allowedUnder: IGNORE_CONFLICTS_ENTRY
	},
	{name: 'a line continuation', test: line => /\\$/.test(line)},
	{name: 'a double ampersand', test: line => line.includes('&&')},
	{name: 'a subshell', test: line => /\$\(/.test(line) || /^\(/.test(line.trim())},
	{name: 'an export', test: line => /^export /.test(line.trim())},
	{name: 'a heredoc', test: line => /<<-?\s*['"]?[A-Za-z_]+/.test(line)},
	{name: 'a single quote', test: line => line.includes('\'')},
	{name: 'a percent sign, dollar sign or backtick', test: line => /[%$`]/.test(line)},
	{name: 'a leading ./', test: line => line.trim().startsWith('./')},
	{name: 'an angle-bracket placeholder', test: line => /<[A-Za-z][A-Za-z-]*>/.test(line)},
	{name: 'a comment line', test: line => line.trim().startsWith('#')},
	{name: 'a tab character', test: line => line.includes('\t')},
	{name: 'a Unix-only tool', test: line => UNIX_ONLY_TOOLS.has(line.trim().split(/\s+/)[0])}
];

/**
 * @description Splits a guide into its fenced blocks, its prose lines and its headings, reading a fence's whole
 *              info string in lower case, so a lookalike language such as shell-session is seen whole and Shell
 *              reads as shell. Windows line endings read as Unix ones.
 * @param {string} content - The guide's markdown.
 * @returns {{lines: string[], blocks: object[], prose: object[], headings: object[]}} The parts, each line numbered from 1.
 */
function parseDocument(content)
{
	const lines = content.replace(/\r\n/g, '\n').split('\n');
	const blocks = [];
	const prose = [];
	const headings = [];
	let open = null;
	for(let index = 0; index < lines.length; index++)
	{
		const line = lines[index];
		const lineNumber = index + 1;
		if(open === null)
		{
			const fence = FENCE_OPEN.exec(line);
			if(fence)
			{
				open = {language: fence[1].toLowerCase(), startLine: lineNumber, endLine: lineNumber, body: []};
				continue;
			}
			const heading = HEADING.exec(line);
			if(heading)
			{
				headings.push({line: lineNumber, level: heading[1].length, text: heading[2]});
			}
			prose.push({line: lineNumber, text: line});
			continue;
		}
		if(FENCE_CLOSE.test(line))
		{
			open.endLine = lineNumber;
			blocks.push(open);
			open = null;
			continue;
		}
		open.body.push(line);
	}
	return {lines, blocks, prose, headings};
}

/**
 * @description The command lines of a block: every non-empty line.
 * @param {object} block - A parsed block.
 * @returns {string[]} The lines, untrimmed.
 */
function commandLinesOf(block)
{
	return block.body.filter(line => line.trim() !== '');
}

/**
 * @description The nearest non-blank prose line above a block, or an empty string when there is none.
 * @param {object} document - The parsed guide.
 * @param {object} block - The block.
 * @returns {string} That line's text, trimmed.
 */
function labelAbove(document, block)
{
	for(let index = block.startLine - 2; index >= 0; index--)
	{
		const text = document.lines[index].trim();
		if(text !== '')
		{
			return text;
		}
	}
	return '';
}

/**
 * @description The text of the nearest heading above a block, or an empty string when there is none.
 * @param {object} document - The parsed guide.
 * @param {object} block - The block.
 * @returns {string} That heading's text.
 */
function headingAbove(document, block)
{
	const above = document.headings.filter(heading => heading.line < block.startLine);
	return above.length > 0 ? above[above.length - 1].text : '';
}

/**
 * @description Runs the checks that apply to any surface with terminal blocks: the fence languages, the portable
 *              subset and the labelled pairs.
 * @param {object} document - The parsed content.
 * @param {string} surface - The repo-relative name the allow-list uses for it.
 * @param {object} allowList - The allow-list file's content.
 * @param {Function} issue - Records one finding: issue(line, check, message).
 */
function checkBlocks(document, surface, allowList, issue)
{
	const pairRows = (allowList.pairs || []).filter(row => row.guide === surface);
	const consumedAsSecondHalf = new Set();
	document.blocks.forEach((block, index) =>
	{
		const language = block.language;
		if(language === 'powershell')
		{
			issue(block.startLine, 'step-shape/powershell', 'PowerShell is tested, never promised: rewrite this block as a portable shell block, or as a Windows and macOS pair');
			return;
		}
		if(REFUSED_LANGUAGES.has(language) || /^(?:shell|bat|bash)[-_]/.test(language))
		{
			issue(block.startLine, 'step-shape/fence', `a \`${language}\` fence is not a terminal block the proof runs; fence it shell, bat or bash`);
			return;
		}
		if(language === 'shell')
		{
			const heading = headingAbove(document, block);
			for(const line of commandLinesOf(block))
			{
				for(const form of BANNED_FORMS)
				{
					const allowed = form.allowedUnder && form.allowedUnder.surface === surface && form.allowedUnder.heading === heading;
					if(!allowed && form.test(line))
					{
						issue(block.startLine, 'step-shape/portable', `the shell block's line \`${line.trim()}\` uses ${form.name}, which the portable command subset bans`);
					}
				}
			}
			return;
		}
		if(language === 'bat')
		{
			const partner = document.blocks[index + 1];
			const windowsCommand = (commandLinesOf(block)[0] || '').trim();
			const labelled = labelAbove(document, block) === WINDOWS_LABEL && partner && partner.language === 'bash' && labelAbove(document, partner) === OTHER_LABEL;
			if(!labelled)
			{
				issue(block.startLine, 'step-shape/pair', `a bat block must sit under ${WINDOWS_LABEL} with a bash block under ${OTHER_LABEL} as the next block`);
				return;
			}
			consumedAsSecondHalf.add(partner.startLine);
			const otherCommand = (commandLinesOf(partner)[0] || '').trim();
			const row = pairRows.find(candidate => candidate.windows === windowsCommand && candidate.other === otherCommand);
			if(!row)
			{
				issue(block.startLine, 'step-shape/pair', `the pair \`${windowsCommand}\` / \`${otherCommand}\` has no row in scripts/platform-specific-blocks.json`
					+ ` for ${surface}; add one with its reason, or find a portable form`);
			}
			return;
		}
		if(language === 'bash' && !consumedAsSecondHalf.has(block.startLine))
		{
			issue(block.startLine, 'step-shape/pair', `a bash block must be the second half of a labelled pair under ${OTHER_LABEL};`
				+ ' a command every reader runs goes in a shell block');
		}
	});
}

/**
 * @description The range every heading owns: from the heading to the next heading of the same or a higher level.
 * @param {object} document - The parsed guide.
 * @param {number} index - The heading's position in document.headings.
 * @returns {{startLine: number, endLine: number}} The range, inclusive.
 */
function rangeOfHeading(document, index)
{
	const heading = document.headings[index];
	const next = document.headings.slice(index + 1).find(candidate => candidate.level <= heading.level);
	return {startLine: heading.line, endLine: next ? next.line - 1 : document.lines.length};
}

/**
 * @description The regions the step checks apply to: every section at heading level three or deeper that holds an
 *              action block, outside the failure FAQ or troubleshooting section, because the readiness check and the
 *              reference parts of a guide are not steps.
 * @param {object} document - The parsed guide.
 * @returns {object[]} Regions as {heading, startLine, endLine}.
 */
function actionRegions(document)
{
	const faqRanges = document.headings.map((heading, index) => (FAQ_HEADINGS.has(heading.text) ? rangeOfHeading(document, index) : null)).filter(Boolean);
	const insideFaq = line => faqRanges.some(range => line >= range.startLine && line <= range.endLine);
	const regions = [];
	document.headings.forEach((heading, index) =>
	{
		if(heading.level < 3 || insideFaq(heading.line))
		{
			return;
		}
		const range = rangeOfHeading(document, index);
		const holdsAnAction = document.blocks.some(block => block.startLine > range.startLine && block.startLine <= range.endLine && ACTION_LANGUAGES.has(block.language));
		if(holdsAnAction)
		{
			regions.push({heading, ...range});
		}
	});
	return regions;
}

/**
 * @description Checks each action region of a step-shaped guide: a where-label above every action block, a
 *              "You should see" when a command runs, and the one line that points at the failure FAQ.
 * @param {object} document - The parsed guide.
 * @param {Function} issue - Records one finding.
 */
function checkSteps(document, issue)
{
	for(const region of actionRegions(document))
	{
		const name = `"${region.heading.text}"`;
		const proseInRegion = document.prose.filter(line => line.line > region.startLine && line.line <= region.endLine);
		const blocksInRegion = document.blocks.filter(block => block.startLine > region.startLine && block.startLine <= region.endLine);
		for(const block of blocksInRegion.filter(candidate => ACTION_LANGUAGES.has(candidate.language)))
		{
			const labelBefore = proseInRegion.some(line => line.line < block.startLine && WHERE_LABEL.test(line.text));
			if(!labelBefore)
			{
				issue(block.startLine, 'step-shape/where', `${name}: this block has no where-label above it (**In the terminal**, **In your editor** or **In Salesforce**)`);
			}
		}
		const runsACommand = blocksInRegion.some(block => block.language === 'shell' || block.language === 'bat' || block.language === 'bash');
		if(!runsACommand)
		{
			continue;
		}
		if(!proseInRegion.some(line => line.text.includes('You should see')))
		{
			issue(region.startLine, 'step-shape/you-should-see', `${name} runs a command but never says "You should see"`);
		}
		if(!proseInRegion.some(line => FAQ_LINK.test(line.text)))
		{
			issue(region.startLine, 'step-shape/faq-link', `${name} runs a command but does not end with "Something went wrong? See [Common Issues, Step N](#...)"`
				+ ' (or [Troubleshooting](#...) in the install guide)');
		}
	}
}

/**
 * @description Checks a Fast Start opens with a "Before you start" that links to the shared page's readiness check,
 *              and ends with the failure FAQ in its shape.
 * @param {object} document - The parsed guide.
 * @param {Function} issue - Records one finding.
 */
function checkReadinessAndFaq(document, issue)
{
	const firstStep = document.headings.find(heading => STEP_HEADING.test(heading.text));
	const readiness = document.headings.find(heading => heading.level === 2 && heading.text === READINESS_HEADING);
	const readinessEnd = readiness ? (document.headings.find(heading => heading.line > readiness.line && heading.level <= 2) || {line: document.lines.length + 1}).line : 0;
	const linksToTheCheck = readiness !== undefined && document.prose.some(line => line.line > readiness.line && line.line < readinessEnd && READINESS_LINK.test(line.text));
	if(!readiness || (firstStep && readiness.line > firstStep.line) || !linksToTheCheck)
	{
		issue(1, 'step-shape/readiness', `a Fast Start opens with "## ${READINESS_HEADING}" before its first step, linking to the readiness check on Set Up Your Computer`
			+ ' (Set%20Up%20Your%20Computer.md#check-you-are-ready)');
	}
	const faq = document.headings.find(heading => heading.level === 2 && heading.text === FAQ_HEADING);
	if(!faq)
	{
		issue(1, 'step-shape/faq', `a Fast Start ends with "## ${FAQ_HEADING}", the failure FAQ`);
		return;
	}
	const faqEnd = (document.headings.find(heading => heading.line > faq.line && heading.level <= 2) || {line: document.lines.length + 1}).line;
	const faqProse = document.prose.filter(line => line.line > faq.line && line.line < faqEnd && line.text.trim() !== '');
	const firstParagraph = faqProse.slice(0, 3).map(line => line.text).join(' ');
	if(!SHARED_PAGE_LINK.test(firstParagraph))
	{
		issue(faq.line, 'step-shape/faq', 'the failure FAQ opens with the link to Set Up Your Computer for trouble with the computer itself');
	}
	const lastLine = faqProse[faqProse.length - 1];
	if(!lastLine || !STILL_STUCK.test(lastLine.text))
	{
		issue(faq.line, 'step-shape/faq', 'the failure FAQ ends with "Still stuck? [Tell us](...)" linking to the public repository\'s issue form');
	}
}

/**
 * @description Flags a command written inside a sentence: an inline code span that starts with a tool name and
 *              carries arguments, unless the roster lists that exact text as a mention.
 * @param {object} document - The parsed guide.
 * @param {string[]} mentions - Exact span texts allowed as mentions.
 * @param {Function} issue - Records one finding.
 */
function checkInlineCommands(document, mentions, issue)
{
	const allowed = new Set(mentions || []);
	for(const line of document.prose)
	{
		for(const match of line.text.matchAll(INLINE_SPAN))
		{
			const text = match[1].trim();
			const words = text.split(/\s+/);
			if(TOOL_NAMES.has(words[0]) && words.length > 1 && !allowed.has(text))
			{
				issue(line.line, 'step-shape/inline-command', `\`${text}\` is a command inside a sentence; give it its own block, or list it under "mentions"`
					+ ' in scripts/step-shaped-guides.json if the sentence only names it');
			}
		}
	}
}

/**
 * @description Checks every "Step N" or "Step N.M" in prose names a heading of this document with that number.
 * @param {object} document - The parsed guide.
 * @param {Function} issue - Records one finding.
 */
function checkStepReferences(document, issue)
{
	const numbers = new Set(document.headings.map(heading => (STEP_HEADING.exec(heading.text) || [])[1]).filter(Boolean));
	for(const line of document.prose)
	{
		const withoutSpans = line.text.replace(INLINE_SPAN, '');
		for(const match of withoutSpans.matchAll(STEP_REFERENCE))
		{
			if(!numbers.has(match[1]))
			{
				issue(line.line, 'step-shape/step-reference', `"Step ${match[1]}" names no heading in this document`);
			}
		}
	}
}

/**
 * @description Checks headings nest: no skipped level, no two siblings with the same text under one parent, no
 *              heading that repeats its parent's text.
 * @param {object} document - The parsed guide.
 * @param {Function} issue - Records one finding.
 */
function checkHeadingNesting(document, issue)
{
	const stack = [];
	for(const heading of document.headings)
	{
		while(stack.length > 0 && stack[stack.length - 1].level >= heading.level)
		{
			stack.pop();
		}
		const parent = stack[stack.length - 1];
		if(parent && heading.level > parent.level + 1)
		{
			issue(heading.line, 'step-shape/heading-level', `"${heading.text}" skips from level ${parent.level} to ${heading.level}`);
		}
		if(parent && parent.text === heading.text)
		{
			issue(heading.line, 'step-shape/heading-repeat', `"${heading.text}" repeats its parent heading's text`);
		}
		if(parent && parent.children.has(heading.text))
		{
			issue(heading.line, 'step-shape/heading-duplicate', `"${heading.text}" appears twice under "${parent.text}"`);
		}
		if(parent)
		{
			parent.children.add(heading.text);
		}
		stack.push({level: heading.level, text: heading.text, children: new Set()});
	}
}

/**
 * @description Runs every check over one guide. Findings are errors for a rostered guide and warnings otherwise.
 * @param {string} content - The guide's markdown.
 * @param {string} repoRelativePath - The guide's path from the repository root, as the roster spells it.
 * @param {object} options - {roster, allowList}.
 * @returns {object[]} Issues in the docs validator's shape.
 */
function checkStepShape(content, repoRelativePath, options)
{
	const roster = options.roster || {guides: [], mentions: []};
	const severity = (roster.guides || []).includes(repoRelativePath) ? 'error' : 'warning';
	const issues = [];
	const issue = (line, check, message) => issues.push({file: repoRelativePath, line, severity, check, message});
	const document = parseDocument(content);
	checkBlocks(document, repoRelativePath, options.allowList || {pairs: []}, issue);
	if(STEP_SHAPED_GUIDE.test(repoRelativePath))
	{
		checkSteps(document, issue);
	}
	if(/^docs\/Fast Start - /.test(repoRelativePath))
	{
		checkReadinessAndFaq(document, issue);
	}
	checkInlineCommands(document, roster.mentions, issue);
	checkStepReferences(document, issue);
	checkHeadingNesting(document, issue);
	return issues.sort((first, second) => first.line - second.line);
}

/**
 * @description Runs the block checks over the roster's extra surfaces: the files named, and the generated texts the
 *              caller can produce. A surface that is absent is noted, never failed, because some do not ship, and a
 *              surface the roster's exceptions name is skipped until it is rewritten.
 * @param {object} roster - The roster file's content.
 * @param {object} allowList - The allow-list file's content.
 * @param {object} io - {exists(path), read(path), generated: {name: () => string}, note(line)}.
 * @returns {object[]} Issues, every one an error.
 */
function checkSurfaces(roster, allowList, io)
{
	const issues = [];
	const excepted = new Set((roster.exceptions || []).map(exception => exception.guide));
	for(const surface of roster.surfaces || [])
	{
		const name = surface.file || surface.generated;
		if(excepted.has(name))
		{
			continue;
		}
		let content = null;
		if(surface.file && io.exists(surface.file))
		{
			content = io.read(surface.file);
		}
		else if(surface.generated && io.generated && io.generated[surface.generated])
		{
			content = io.generated[surface.generated]();
		}
		if(content === null)
		{
			if(io.note)
			{
				io.note(`step-shape: surface ${name} is not in this tree, skipped`);
			}
			continue;
		}
		const issue = (line, check, message) => issues.push({file: name, line, severity: 'error', check, message});
		checkBlocks(parseDocument(content), name, allowList, issue);
	}
	return issues;
}

/**
 * @description Checks the roster and the allow-list stay true: every rostered guide exists, and every allow-list
 *              row names a pair some guide still prints (a dead row fails, so rows remove themselves). A row whose
 *              guide is a generated surface is read from its generator; a row whose guide is neither is skipped.
 * @param {object} roster - The roster file's content.
 * @param {object} allowList - The allow-list file's content.
 * @param {object} io - {exists(path), read(path), generated: {name: () => string}}.
 * @returns {object[]} Issues, every one an error.
 */
function checkRoster(roster, allowList, io)
{
	const generators = io.generated || {};
	const issues = [];
	for(const guide of roster.guides || [])
	{
		if(!io.exists(guide))
		{
			issues.push({
				file: 'scripts/step-shaped-guides.json', line: 1, severity: 'error', check: 'step-shape/roster', message: `the roster names ${guide}, which does not exist`
			});
		}
	}
	for(const row of (allowList.pairs || []))
	{
		let content = null;
		if(io.exists(row.guide))
		{
			content = io.read(row.guide);
		}
		else if(generators[row.guide])
		{
			content = generators[row.guide]();
		}
		if(content === null)
		{
			continue;
		}
		const document = parseDocument(content);
		const printed = document.blocks.some(block => block.language === 'bat' && (commandLinesOf(block)[0] || '').trim() === row.windows);
		if(!printed)
		{
			issues.push({
				file: 'scripts/platform-specific-blocks.json', line: 1, severity: 'error', check: 'step-shape/roster',
				message: `the allow-list row \`${row.windows}\` for ${row.guide} matches no bat block; remove the dead row`
			});
		}
	}
	return issues;
}

module.exports = {checkStepShape, checkSurfaces, checkRoster, parseDocument, BANNED_FORMS, REFUSED_LANGUAGES};
