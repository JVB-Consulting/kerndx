// SPDX-License-Identifier: Apache-2.0
// Builds the VitePress sidebar from the page list. Pure; no filesystem access.

const PREFIX_GROUPS = [
	{test: n => n.startsWith('fast start'), group: 'Fast Starts'},
	{test: n => n.startsWith('strategic guide'), group: 'Strategic Guides'},
	{test: n => n.endsWith('guide'), group: 'Guides'}
];

// API Reference groups into prefix/domain folders (mirrors the IDE project tree
// and the KernDX naming convention) rather than a flat A–Z list of 238 classes.
// Each apex class maps to a domain by its TRG_/SEL_/UTIL_… prefix; custom objects,
// events, and metadata become their own folders.
export const APEX_PREFIX_DOMAIN = {
	TRG_: 'Triggers',
	QRY_: 'Query & Selectors',
	SEL_: 'Query & Selectors',
	DML_: 'DML & Unit of Work',
	API_: 'APIs & Services',
	REST_: 'APIs & Services',
	SVC_: 'APIs & Services',
	LOG_: 'Logging',
	PROC_: 'Async & Scheduling',
	SCHED_: 'Async & Scheduling',
	FLOW_: 'Flow Actions',
	DTO_: 'Data Transfer Objects',
	MAP_: 'Data Transfer Objects',
	UTIL_: 'Utilities',
	CTRL_: 'Controllers',
	TST_: 'Testing',
	IF_: 'Interfaces'
};
const AREA_DOMAIN = {objects: 'Custom Objects', events: 'Platform Events', metadata: 'Custom Metadata Types'};
// Domain folder order — daily-driver first ("soonest × oftenest"), lookup/meta last.
const REFERENCE_SUBGROUP_ORDER = [
	'Triggers',
	'Query & Selectors',
	'DML & Unit of Work',
	'APIs & Services',
	'Logging',
	'Async & Scheduling',
	'Flow Actions',
	'Data Transfer Objects',
	'Utilities',
	'Controllers',
	'Testing',
	'Interfaces',
	'Custom Objects',
	'Platform Events',
	'Custom Metadata Types',
	'Other'
];
const TYPE_RANK = {class: 0, interface: 1, enum: 2};

// The domain folder for a reference page, from its area + filename prefix.
function referenceDomain(area, fileBase)
{
	if(area === 'apex')
	{
		const m = fileBase.match(/^([A-Za-z0-9]+_)/);
		return (m && APEX_PREFIX_DOMAIN[m[1]]) || 'Other';
	}
	return AREA_DOMAIN[area] || area;
}

function normalize(name)
{
	return name.toLowerCase().replace(/[\s_-]+/g, ' ').trim();
}

// Returns { group, subgroup } for a page.
export function groupForPage(page)
{
	if(page.relPath.startsWith('reference/'))
	{
		// Every page under reference/ belongs to API Reference. A class/record page
		// (reference/<area>/<file>) sub-groups into its prefix/domain folder; the master
		// landing (reference/index.md) and the per-area landings (reference/<area>/index.md)
		// have no domain, so they become top-level API Reference items (the "Overview /
		// Browse" links) rather than leaking into Getting Started.
		const m = page.relPath.match(/^reference\/([^/]+)\/(.+)$/);
		if(!m)
		{
			// master reference/index.md → top-level "Overview" link
			return {group: 'API Reference', subgroup: null};
		}
		const area = m[1];
		const fileBase = m[2].replace(/\.md$/i, '');
		if(/^index$/i.test(fileBase))
		{
			// The apex landing stays a top-level link (apex fans out into many domain
			// folders, with no single "apex" folder to lead); object/event/metadata
			// landings lead their own single folder instead of duplicating as a separate
			// top-level link.
			return {group: 'API Reference', subgroup: area === 'apex' ? null : (AREA_DOMAIN[area] || area)};
		}
		return {group: 'API Reference', subgroup: referenceDomain(area, fileBase)};
	}
	if(page.frontmatter && page.frontmatter.group)
	{
		return {group: page.frontmatter.group, subgroup: null};
	}
	const base = normalize(page.relPath.replace(/\.md$/i, '').split('/').pop());
	for(const rule of PREFIX_GROUPS)
	{
		if(rule.test(base))
		{
			return {group: rule.group, subgroup: null};
		}
	}
	return {group: 'Getting Started', subgroup: null};
}

function link(page)
{
	return {text: page.frontmatter?.title || page.title, link: page.slug === '' ? '/' : `/${page.slug}`};
}

// The filename (no extension) of a reference page — e.g. 'UTIL_SObjectDescribe.FieldListBuilder'
// for reference/apex/UTIL_SObjectDescribe.FieldListBuilder.md. Empty for non-reference pages.
function refFileBase(page)
{
	const m = page.relPath.match(/^reference\/[^/]+\/(.+)\.md$/i);
	return m ? m[1] : '';
}

// Within an apex domain folder, nest each inner class (an `Outer.Inner` page) under its
// `Outer` parent so the sidebar mirrors the Apex class hierarchy instead of listing the
// outer class and every inner class as flat alphabetical siblings (e.g. IF_Trigger's eight
// inner interfaces, or each FLOW_ action's DTO_Request/DTO_Response pair). Inner classes are
// shown by their short name under the parent. An inner class whose outer class has no page of
// its own stays a top-level sibling. Non-apex domains (object/event/metadata names have no
// dots) pass straight through. `ordered` is the already-sorted page list for the domain.
function nestInnerClasses(ordered)
{
	const byFileBase = new Map();
	for(const p of ordered)
	{
		const fb = refFileBase(p);
		if(fb)
		{
			byFileBase.set(fb, p);
		}
	}

	const isApexInner = p => /^reference\/apex\//i.test(p.relPath) && refFileBase(p).includes('.');
	const outerOf = p => { const fb = refFileBase(p); return fb.slice(0, fb.indexOf('.')); };
	const nestable = p => isApexInner(p) && byFileBase.has(outerOf(p));

	const childrenByOuter = new Map();
	for(const p of ordered)
	{
		if(nestable(p))
		{
			const key = outerOf(p);
			if(!childrenByOuter.has(key))
			{
				childrenByOuter.set(key, []);
			}
			childrenByOuter.get(key).push(p);
		}
	}

	const out = [];
	for(const p of ordered)
	{
		if(nestable(p))
		{
			continue;   // rendered as a child of its outer class below
		}
		const kids = childrenByOuter.get(refFileBase(p));
		if(kids && kids.length)
		{
			const prefixLen = refFileBase(p).length + 1;
			out.push({
				...link(p), collapsed: true, items: kids.map(k => ({text: refFileBase(k).slice(prefixLen), link: k.slug === '' ? '/' : `/${k.slug}`}))
			});
		}
		else
		{
			out.push(link(p));
		}
	}
	return out;
}

// A reference landing page (index.md). When one sits inside a domain folder
// (object/event/metadata area landings), it sorts first so the overview leads.
function isIndexPage(page)
{
	return /(^|\/)index\.md$/i.test(page.relPath);
}

function apexCompare(a, b)
{
	const ra = TYPE_RANK[a.frontmatter?.type] ?? 9;
	const rb = TYPE_RANK[b.frontmatter?.type] ?? 9;
	if(ra !== rb)
	{
		return ra - rb;
	}
	return (a.title || '').localeCompare(b.title || '');
}

function alphaTitle(a, b)
{
	return (a.frontmatter?.title || a.title || '').localeCompare(b.frontmatter?.title || b.title || '');
}

// Within-section order: `navOrder` (the "soonest × oftenest" IA convention — see
// docs/Code Conventions - Guide.md) wins, then the legacy `order` field, then alpha.
function orderCompare(a, b)
{
	const oa = a.frontmatter?.navOrder ?? a.frontmatter?.order;
	const ob = b.frontmatter?.navOrder ?? b.frontmatter?.order;
	if(oa != null && ob != null)
	{
		return (oa - ob) || alphaTitle(a, b);
	}
	if(oa != null)
	{
		return -1;
	}
	if(ob != null)
	{
		return 1;
	}
	return alphaTitle(a, b);
}

export function generateSidebar(pages)
{
	const visible = pages.filter(p => !(p.frontmatter && p.frontmatter.draft));
	const groups = new Map();        // group -> { items: [], subgroups: Map }
	for(const page of visible)
	{
		const {group, subgroup} = groupForPage(page);
		if(!groups.has(group))
		{
			groups.set(group, {items: [], subgroups: new Map()});
		}
		const bucket = groups.get(group);
		if(subgroup)
		{
			if(!bucket.subgroups.has(subgroup))
			{
				bucket.subgroups.set(subgroup, []);
			}
			bucket.subgroups.get(subgroup).push(page);
		}
		else
		{
			bucket.items.push(page);
		}
	}

	// F-shape section order ("soonest × oftenest"): first-contact + daily-driver, then
	// depth, then lookup, then evaluation, with the record (Release Notes) last.
	const TOP_ORDER = [
		'Getting Started',
		'Fast Starts',
		'Guides',
		'API Reference',
		'Strategic Guides',
		'Release Notes'
	];
	const groupNames = [...groups.keys()].sort((a, b) =>
	{
		const ia = TOP_ORDER.indexOf(a), ib = TOP_ORDER.indexOf(b);
		if(ia !== -1 || ib !== -1)
		{
			return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib);
		}
		return a.localeCompare(b);
	});

	const sidebar = [];
	for(const name of groupNames)
	{
		const bucket = groups.get(name);
		const items = bucket.items.slice().sort(orderCompare).map(link);
		if(bucket.subgroups.size)
		{
			const domainNames = [...bucket.subgroups.keys()].sort((a, b) =>
			{
				const ia = REFERENCE_SUBGROUP_ORDER.indexOf(a), ib = REFERENCE_SUBGROUP_ORDER.indexOf(b);
				return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib) || a.localeCompare(b);
			});
			for(const domain of domainNames)
			{
				// Index/landing first; then apexCompare ranks class→interface→enum then
				// alpha (for object/event/metadata pages with no such type it degrades to
				// alpha), so it is safe for every reference domain folder.
				const ordered = bucket.subgroups.get(domain).slice().sort((a, b) =>
					(isIndexPage(a) ? 0 : 1) - (isIndexPage(b) ? 0 : 1) || apexCompare(a, b));
				items.push({text: domain, collapsed: true, items: nestInnerClasses(ordered)});
			}
		}
		sidebar.push({text: name, collapsed: name === 'API Reference', items});
	}
	return sidebar;
}

// ── Areas ────────────────────────────────────────────────────────────────────
// The latest docs are split into five areas, one per top-menu item, and each area has its own
// sidebar. Frozen version trees (/1.x/) keep the single sidebar from generateSidebar() above.

// The top menu of the latest docs, in reading order. Each item opens the first page of its area.
export const TOP_MENU = [
	{text: 'Why KernDX', link: '/'},
	{text: 'Get Started', link: '/installation'},
	{text: 'Fast Starts', link: '/fast-starts'},
	{text: 'Guides', link: '/triggers-guide'},
	{text: 'Reference', link: '/reference/'}
];

// The top menu of a frozen tree: as it was before the Guides area, so it links only to pages
// that the older tree has.
export const FROZEN_TOP_MENU = TOP_MENU.filter(item => item.text !== 'Guides');

// The areas, in top-menu order.
export const AREAS = ['why', 'get-started', 'fast-starts', 'guides', 'reference'];

const AREA_MENU_TITLE = {why: 'Why KernDX', 'get-started': 'Get Started', 'fast-starts': 'Fast Starts', guides: 'Guides'};

// Get Started pages, by normalized file name. The Glossary is a Strategic Guide by name and
// Code Conventions a guide by name, but a new reader needs both early, so they sit here. The
// Administration Tools guide is not here: it is a developer guide, so it is in Guides.
const GET_STARTED_PAGES = new Set([
	'installation',
	'set up your computer',
	'from plain apex to kerndx',
	'strategic guide glossary',
	'code conventions guide',
	'readme',
	'agents',
	'ai agent instructions'
]);

// The area a page matches, or null when no rule places it.
function matchArea(page)
{
	const chosen = page.frontmatter?.area;
	if(chosen != null)
	{
		if(!AREAS.includes(chosen))
		{
			throw new Error(`${page.relPath} has area "${chosen}" in its frontmatter; use one of ${AREAS.join(', ')}`);
		}
		return chosen;
	}
	if(page.relPath.startsWith('reference/') || page.relPath.startsWith('release-notes/'))
	{
		return 'reference';
	}
	const base = normalize(page.relPath.replace(/\.md$/i, '').split('/').pop());
	if(GET_STARTED_PAGES.has(base))
	{
		return 'get-started';
	}
	if(base.startsWith('strategic guide'))
	{
		return 'why';
	}
	if(base.startsWith('fast start'))
	{
		return 'fast-starts';
	}
	if(base.endsWith('guide'))
	{
		return 'guides';
	}
	return null;
}

// The area a page belongs to. Throws for a page that no rule places, so a new page cannot ship
// without a menu: name it like the pages of its area, or give it an `area` in its frontmatter.
export function areaForPage(page)
{
	const area = matchArea(page);
	if(!area)
	{
		throw new Error(`${page.relPath} belongs to no docs area. Add "area: <one of ${AREAS.join(', ')}>" to its frontmatter, `
				+ 'or add it to the rules in scripts/generate-nav.mjs');
	}
	return area;
}

// True when the page is a developer guide, the only kind of page that gets "Reference for this
// page". Does not throw for a page in no area: generateSidebarAreas reports that.
export function isGuidePage(page)
{
	return matchArea(page) === 'guides';
}

// The path VitePress looks a page's sidebar up by: its source path under src/, with a leading slash.
function routePath(page)
{
	if(page.slug === '')
	{
		return '/index.md';
	}
	return /(^|\/)index\.md$/i.test(page.relPath) ? `/${page.slug}/index.md` : `/${page.slug}.md`;
}

// The sidebar for a path, chosen the way VitePress chooses it: the key with the most path
// segments that the path starts with wins, and keys with the same number of segments are tried
// in the order they were written.
export function sidebarForPath(sidebars, path)
{
	const key = sidebarKeyFor(Object.keys(sidebars), path);
	return key === undefined ? [] : sidebars[key];
}

function sidebarKeyFor(keys, path)
{
	return [...keys].sort((a, b) => b.split('/').length - a.split('/').length).find(key => path.startsWith(key));
}

function commonPrefix(paths)
{
	let prefix = paths[0] ?? '';
	for(const p of paths)
	{
		while(!p.startsWith(prefix))
		{
			prefix = prefix.slice(0, -1);
		}
	}
	return prefix;
}

function menuLink(page)
{
	return {text: page.frontmatter?.navLabel || page.frontmatter?.title || page.title, link: page.slug === '' ? '/' : `/${page.slug}`};
}

function areaMenu(area, pages)
{
	if(area === 'reference')
	{
		// The API tree and the release notes, both open: on a reference page they are the whole menu.
		return generateSidebar(pages).map(group => ({...group, collapsed: false}));
	}
	return [{text: AREA_MENU_TITLE[area], items: pages.slice().sort(orderCompare).map(menuLink)}];
}

// The area menus in a compact form: `menus` holds each area's sidebar once, and `paths` maps a
// sidebar key to the area whose menu it shows. Inline site data ships on every page, so writing
// the API tree once instead of once per key is what keeps it inside the artifact audit's budget.
// The theme turns this back into a VitePress path-keyed sidebar with expandSidebarAreas().
//
// Keys are as few as possible: each area gets the prefix its pages share (for example
// "/fast-start"), the guides take the catch-all "/", and a page that a shorter key would send to
// the wrong menu gets its own exact key. The home page shows the Why KernDX menu.
export function generateSidebarAreas(pages)
{
	const visible = pages.filter(p => !(p.frontmatter && p.frontmatter.draft));
	const pagesByArea = new Map();
	const routes = [];
	for(const page of visible)
	{
		const area = areaForPage(page);
		if(!pagesByArea.has(area))
		{
			pagesByArea.set(area, []);
		}
		pagesByArea.get(area).push(page);
		routes.push([routePath(page), area]);
	}
	const menus = {};
	for(const area of AREAS)
	{
		if(pagesByArea.has(area))
		{
			menus[area] = areaMenu(area, pagesByArea.get(area));
		}
	}
	if(menus.why && !routes.some(([route]) => route === '/index.md'))
	{
		routes.push(['/index.md', 'why']);
	}
	const fallback = menus.guides ? 'guides' : Object.keys(menus)[0];
	if(!fallback)
	{
		return {menus, paths: {}};
	}

	const prefixKeys = {};
	for(const area of Object.keys(menus))
	{
		if(area === fallback)
		{
			continue;
		}
		const prefix = commonPrefix(routes.filter(([route, a]) => a === area && route !== '/index.md').map(([route]) => route));
		if(prefix.length > 1 && !(prefix in prefixKeys))
		{
			prefixKeys[prefix] = area;
		}
	}
	const exactKeys = {};
	for(const [route, area] of routes)
	{
		const key = sidebarKeyFor([...Object.keys(prefixKeys), '/'], route);
		if((key === '/' ? fallback : prefixKeys[key]) !== area)
		{
			exactKeys[route] = area;
		}
	}
	// Exact keys first, so that they win over a prefix with the same number of path segments.
	const paths = {...exactKeys, ...prefixKeys, '/': fallback};
	for(const [route, area] of routes)
	{
		if(paths[sidebarKeyFor(Object.keys(paths), route)] !== area)
		{
			throw new Error(`Sidebar keys send ${route} to the wrong menu; expected the ${area} menu`);
		}
	}
	return {menus, paths};
}

// The VitePress path-keyed sidebar from the compact form. Every key of an area shares one menu.
export function expandSidebarAreas({menus, paths})
{
	return Object.fromEntries(Object.entries(paths).map(([key, area]) => [key, menus[area]]));
}

// The site data with the latest tree's compact menus (`themeConfig.sidebarAreas`) expanded into
// the path-keyed `themeConfig.sidebar` that VitePress reads. It builds a new object and never
// changes the one it is given, because the dev server gives the theme read-only site data. It
// returns the same object when there is nothing to do: a frozen tree has no `sidebarAreas`, and
// data that already has a `sidebar` was expanded before.
export function withExpandedSidebar(siteData)
{
	const themeConfig = siteData?.themeConfig;
	if(!themeConfig?.sidebarAreas || themeConfig.sidebar)
	{
		return siteData;
	}
	return {...siteData, themeConfig: {...themeConfig, sidebar: expandSidebarAreas(themeConfig.sidebarAreas)}};
}

// The path-keyed sidebar of the latest docs: each key maps to the menu of the area it belongs to.
export function generateSidebars(pages)
{
	return expandSidebarAreas(generateSidebarAreas(pages));
}

// The most a "Reference for this page" group lists.
export const REFERENCE_LINK_LIMIT = 5;

// The most used classes of a guide, for its "Reference for this page" group: the Apex reference
// pages its body links to most, the most linked first (a tie keeps the one linked first). `body`
// is the page's markdown after links were turned into site paths, and `slugs` maps each Apex
// reference page's slug to its title.
//
// A guide may choose its own list with `referenceLinks: "QRY_Builder, SEL_Base"` in its
// frontmatter, or none with `referenceLinks: ""`. A name that is no reference page fails the build.
export function referenceLinksFor(page, slugs)
{
	const toLink = slug => ({text: slugs.get(slug), link: `/${slug}`});
	const chosen = page.frontmatter?.referenceLinks;
	if(chosen != null)
	{
		const slugByTitle = new Map([...slugs].map(([slug, title]) => [title, slug]));
		return String(chosen).split(',').map(name => name.trim()).filter(Boolean).map(name =>
		{
			if(!slugByTitle.has(name))
			{
				throw new Error(`${page.relPath} lists "${name}" in referenceLinks, but no Apex reference page has that name`);
			}
			return toLink(slugByTitle.get(name));
		});
	}
	const counts = new Map();
	for(const m of (page.body || '').matchAll(/\]\(\/(reference\/apex\/[^)#?\s]+)/g))
	{
		if(slugs.has(m[1]))
		{
			counts.set(m[1], (counts.get(m[1]) ?? 0) + 1);
		}
	}
	// A Map keeps the order in which each slug was first linked, and sort() is stable.
	return [...counts].sort((a, b) => b[1] - a[1]).slice(0, REFERENCE_LINK_LIMIT).map(([slug]) => toLink(slug));
}
