// SPDX-License-Identifier: BUSL-1.1
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
const APEX_PREFIX_DOMAIN = {
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
				items.push({text: domain, collapsed: true, items: ordered.map(link)});
			}
		}
		sidebar.push({text: name, collapsed: name === 'API Reference', items});
	}
	return sidebar;
}
