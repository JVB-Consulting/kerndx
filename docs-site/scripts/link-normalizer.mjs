// SPDX-License-Identifier: BUSL-1.1
import path from 'node:path';

function splitAnchor(href)
{
	const i = href.indexOf('#');
	return i === -1 ? [
		href,
		''
	] : [
		href.slice(0, i),
		href.slice(i + 1)
	];
}

// Resolve a single href. currentRelDir = POSIX dir of the source file relative to
// docs root ('' for top-level). Returns { href, resolved }.
export function normalizeLink(rawHref, currentRelDir, slugMap)
{
	if(/^(https?:|mailto:|tel:|#|\/)/i.test(rawHref))
	{
		return {href: rawHref, resolved: true};
	}
	const [pathPart, anchor] = splitAnchor(rawHref);
	if(!/\.md$/i.test(pathPart))
	{
		return {href: rawHref, resolved: true};
	}
	let decoded;
	try
	{
		decoded = decodeURIComponent(pathPart);
	}
	catch
	{
		decoded = pathPart;
	}
	const targetRel = path.posix.normalize(path.posix.join(currentRelDir, decoded)).replace(/^(\.\/)+/, '');
	const slug = slugMap.get(targetRel);
	if(slug === undefined)
	{
		return {href: rawHref, resolved: false};
	}
	// A directory-index target (…/index.md) has page id "…/index" in VitePress, so a link
	// to "/slug" (no trailing slash) is flagged dead — the checker only appends "index"
	// when the URL ends in "/". Emit the trailing slash for index pages.
	const isIndexTarget = /(^|\/)index\.md$/i.test(targetRel);
	let url = slug === '' ? '/' : `/${slug}`;
	if(isIndexTarget && slug !== '')
	{
		url += '/';
	}
	return {href: anchor ? `${url}#${anchor}` : url, resolved: true};
}

// Rewrite every []() inline markdown link AND every [id]: url reference definition in a
// body. relPath = source file path relative to docs root. Returns { content,
// unresolved: [rawHref,…] }.
export function rewriteLinks(body, relPath, slugMap)
{
	const currentRelDir = path.posix.dirname(relPath) === '.' ? '' : path.posix.dirname(relPath);
	const unresolved = [];
	let content = body.replace(/\]\(([^)\s]+)(\s+"[^"]*")?\)/g, (whole, href, title = '') =>
	{
		const r = normalizeLink(href, currentRelDir, slugMap);
		if(!r.resolved)
		{
			unresolved.push(href);
			return whole;
		}
		return `](${r.href}${title})`;
	});
	// Reference-style link definitions: a line like `[id]: path "optional title"`.
	content = content.replace(/^(\s*\[[^\]]+\]:\s*)(\S+)([ \t]+"[^"]*")?\s*$/gm, (whole, lead, href, title = '') =>
	{
		const r = normalizeLink(href, currentRelDir, slugMap);
		if(!r.resolved)
		{
			unresolved.push(href);
			return whole;
		}
		return `${lead}${r.href}${title}`;
	});
	return {content, unresolved};
}
