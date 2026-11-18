// SPDX-License-Identifier: Apache-2.0
// Pure version-switch routing helpers — no DOM, no fetch, no VitePress imports — so the
// switcher's path logic unit-tests under `node --test` like the rest of docs-site/scripts.
// The VersionSwitcher.vue shell supplies the live location and the fetched route set; these
// functions decide where a version switch lands.

// Drop a leading and trailing slash. '/fast-starts/triggers/' → 'fast-starts/triggers'.
function trimSlashes(value)
{
	return String(value || '').replace(/^\/+|\/+$/g, '');
}

// Strip the active version base from a pathname, yielding the version-agnostic logical page
// path with no surrounding slashes. Under base '/1.2/', '/1.2/fast-starts/triggers' →
// 'fast-starts/triggers' and the tree home '/1.2/' → ''. Under base '/', '/installation' →
// 'installation' and '/' → ''.
export function logicalPath(pathname, base)
{
	const baseNoTrailing = String(base || '/').replace(/\/+$/, '');   // '/1.2' or '' for root
	let p = String(pathname || '');
	if(baseNoTrailing && (p === baseNoTrailing || p.startsWith(`${baseNoTrailing}/`)))
	{
		p = p.slice(baseNoTrailing.length);
	}
	return trimSlashes(p);
}

// Find the version object whose base matches the active VitePress base. Falls back to the
// flagged latest, then the first entry, then null — so a build with an unexpected base still
// renders a sane current selection rather than crashing.
export function currentVersion(versions, base)
{
	const list = Array.isArray(versions) ? versions : [];
	const wanted = base || '/';
	return list.find(v => v.base === wanted)
		|| list.find(v => v.latest)
		|| list[0]
		|| null;
}

// Resolve the destination URL for switching to targetVersion while viewing `logical`.
// routeSet is the Set of normalised logical paths that exist in the target tree, or null
// when it could not be loaded. The tree home ('') always exists; any page confirmed present
// keeps the reader on the same page; anything absent or unconfirmed falls back to the target
// tree's home, so a switch can never land on a 404.
export function resolveTargetUrl(targetVersion, logical, routeSet)
{
	const base = targetVersion.base;
	const lp = trimSlashes(logical);
	if(lp === '')
	{
		return base;
	}
	if(routeSet && routeSet.has(lp))
	{
		return base + lp;
	}
	return base;
}

// The site publishes the current docs at the base and a few older versions under /X.Y/. A link
// into an older version that is no longer published (such as /1.3/selectors-guide) should open
// the same page in the current docs (/selectors-guide). Given the address the reader asked for,
// this returns that current address, or null when the address is not inside a removed version:
// a published older version, the current docs, and every other address are left alone. A page
// that no longer exists in the current docs then gets the site's normal "page not found".
//
// The function is written without any outside helper on purpose: removedVersionRedirectScript
// copies its source text into the "page not found" page, where it runs on its own.
export function removedVersionTarget(pathname, publishedLines, base)
{
	const siteBase = String(base || '/').replace(/\/*$/, '/');
	const path = String(pathname || '');
	if(!path.startsWith(siteBase) && path !== siteBase.replace(/\/$/, ''))
	{
		return null;
	}
	const rest = path.slice(siteBase.length);
	const match = /^(\d+\.\d+)(\/.*)?$/.exec(rest);
	if(!match || (publishedLines || []).includes(match[1]))
	{
		return null;
	}
	return siteBase + (match[2] || '/').replace(/^\/+/, '');
}

// The inline script for the site's "page not found" page. GitHub Pages serves that page for
// every address it has no file for, so this is where a link into a removed version is caught
// and sent on to the current page. The address's query and #section are kept.
export function removedVersionRedirectScript(publishedLines, base)
{
	return `(function(){var target=(${removedVersionTarget.toString()})(location.pathname,${JSON.stringify(publishedLines)},${JSON.stringify(base)});`
		+ 'if(target!==null){location.replace(target+location.search+location.hash);}})();';
}

// Normalise a raw routes.json array (logical slugs) into a lookup Set. Non-arrays → null,
// signalling "could not confirm", which resolveTargetUrl treats as a home fallback.
export function toRouteSet(routes)
{
	if(!Array.isArray(routes))
	{
		return null;
	}
	return new Set(routes.map(trimSlashes));
}
