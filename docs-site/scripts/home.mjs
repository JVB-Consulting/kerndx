// SPDX-License-Identifier: BUSL-1.1
import path from 'node:path';

const REPO_BLOB = 'https://github.com/JVB-Consulting/kerndx/blob/main';
const ON_SITE = {'agents.md': '/agents'};

// Rewrites a repo-root-relative markdown body — the README home, AGENTS, or a release note —
// for use on the site. `currentDir` is the body's own directory relative to the repo root
// ('' for README/AGENTS, 'release-notes' for a release note) so `./sibling.md` and
// `../docs/x.md` resolve correctly. docs/* and release-notes/* targets become site slugs;
// any other repo file (LICENSE, CONTRIBUTING, examples/…) falls back to a GitHub blob link.
//
// docs/* keys are looked up docs-relative (matching buildSlugMap); release-notes/* keys are
// looked up with their prefix intact (so the two namespaces can't collide).
export function rewriteHomeLinks(body, slugMap, currentDir = '')
{
	// Strip local (non-remote) image/badge refs — the bundler tries to resolve them as modules
	// and the build fails (P0 spike finding). Keep remote (http/https) shields.io badges.
	body = body.replace(/!\[[^\]]*\]\((?!https?:)[^)]*\)/g, '');
	return body.replace(/\]\(([^)\s]+)(\s+"[^"]*")?\)/g, (whole, href, title = '') =>
	{
		if(/^(https?:|mailto:|tel:|#)/i.test(href))
		{
			return whole;
		}
		let decoded;
		try
		{
			decoded = decodeURIComponent(href);
		}
		catch
		{
			decoded = href;
		}
		const anchor = decoded.includes('#') ? decoded.slice(decoded.indexOf('#')) : '';
		const rawFile = anchor ? decoded.slice(0, decoded.indexOf('#')) : decoded;
		// Resolve ./ and ../ against the body's own directory; the result is repo-relative.
		const repoRel = path.posix.normalize(path.posix.join(currentDir, rawFile)).replace(/^(\.\/)+/, '');
		const toSlug = (slug) => `](${slug === '' ? '/' : '/' + slug}${anchor}${title})`;
		if(repoRel.startsWith('docs/'))
		{
			const slug = slugMap.get(repoRel.slice('docs/'.length));
			return slug !== undefined ? toSlug(slug) : `](${REPO_BLOB}/${repoRel}${anchor}${title})`;
		}
		if(repoRel.startsWith('release-notes/'))
		{
			const slug = slugMap.get(repoRel);
			return slug !== undefined ? toSlug(slug) : `](${REPO_BLOB}/${repoRel}${anchor}${title})`;
		}
		// on-site root pages (AGENTS.md -> /agents)
		const onSite = ON_SITE[path.posix.basename(repoRel).toLowerCase()];
		if(onSite)
		{
			return `](${onSite}${anchor}${title})`;
		}
		// any other repo-root file -> GitHub blob
		if(!repoRel.includes('://'))
		{
			return `](${REPO_BLOB}/${repoRel}${anchor}${title})`
		}
		return whole
	})
}
