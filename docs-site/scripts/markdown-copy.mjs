// SPDX-License-Identifier: Apache-2.0
// The Markdown copy of a page, served for AI agents beside the page itself. A page at /selectors-guide
// has its copy at /selectors-guide.md. The copy is the page's Markdown as written, with its links already
// pointing at site pages: no frontmatter, no HTML comments, and none of the changes the site makes so
// that VitePress can render the page (escaped angle brackets, container blocks for <details>).
//
// The text reaches the copy after the "Learn it:" line and the "Methods by task" table have been added to
// the page, so the copy shows the same lines the reader sees. Frozen version trees get no copies.

const FENCE_OR_CODE_SPAN = /(```[\s\S]*?```|`[^`\n]*`)/g;
const FIRST_HEADING = /^#\s+\S/m;

// The path of a page's copy, relative to the site root.
export function markdownCopyPath(slug)
{
	return `${slug}.md`;
}

// The head entry that tells a browser or a crawler where the page's copy is. `base` is the deploy base
// ('/' for the latest tree). VitePress does not put the base on head links written in frontmatter.
export function markdownCopyHeadEntry(slug, base = '/')
{
	return [
		'link',
		{rel: 'alternate', type: 'text/markdown', href: `${base}${markdownCopyPath(slug)}`}
	];
}

// Removes HTML comments from prose. They are invisible on GitHub and on the site, so the copy must not
// show them either. Comments inside a code block or a code span are code, and stay.
export function stripHtmlComments(markdown)
{
	return markdown
	.split(FENCE_OR_CODE_SPAN)
	.map((segment, index) => (index % 2 === 1 ? segment : segment.replace(/<!--[\s\S]*?-->/g, '')))
	.join('');
}

// The text of one page's copy. A page whose Markdown has no top-level heading (its title lives in
// frontmatter) gets that title as its first line, so a copy always says what page it is.
export function renderMarkdownCopy({markdown, title})
{
	const text = stripHtmlComments(markdown).replace(/^\s*\n/, '').replace(/\s+$/, '');
	const titled = FIRST_HEADING.test(text) || !title ? text : `# ${title}\n\n${text}`;
	return `${titled}\n`;
}
