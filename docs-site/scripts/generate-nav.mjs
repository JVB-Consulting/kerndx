// SPDX-License-Identifier: BUSL-1.1
// Builds the VitePress sidebar from the page list. Pure; no filesystem access.

const PREFIX_GROUPS = [
	{test: n => n.startsWith('fast start'), group: 'Fast Starts'},
	{test: n => n.startsWith('strategic guide'), group: 'Strategic Guides'},
	{test: n => n.endsWith('guide'), group: 'Guides'}
];

const AREA_ORDER = [
	'apex',
	'objects',
	'events',
	'metadata'
];
const TYPE_RANK = {class: 0, interface: 1, enum: 2};

function normalize(name)
{
	return name.toLowerCase().replace(/[\s_-]+/g, ' ').trim();
}

// Returns { group, subgroup } for a page.
export function groupForPage(page)
{
	if(page.relPath.startsWith('reference/'))
	{
		// Every page under reference/ belongs to API Reference. With an area segment
		// (reference/<area>/<file>) it sub-groups by that area; the bare reference/index.md
		// landing page has no area, so it becomes a top-level API Reference item rather than
		// leaking into Getting Started.
		const m = page.relPath.match(/^reference\/([^/]+)\//);
		return {group: 'API Reference', subgroup: m ? m[1] : null};
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

function orderCompare(a, b)
{
	const oa = a.frontmatter?.order, ob = b.frontmatter?.order;
	if(oa != null && ob != null)
	{
		return oa - ob;
	}
	if(oa != null)
	{
		return -1;
	}
	if(ob != null)
	{
		return 1;
	}
	return (a.frontmatter?.title || a.title || '').localeCompare(b.frontmatter?.title || b.title || '');
}

// The area landing page (reference/<area>/index.md). It sorts first in its
// subgroup so the section overview surfaces at the top rather than sinking in
// among the classes (an untyped index would otherwise fall to apexCompare's
// unknown-type rank).
function isAreaIndex(page)
{
	return /(^|\/)index\.md$/i.test(page.relPath);
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

	const TOP_ORDER = [
		'Getting Started',
		'Release Notes',
		'Fast Starts',
		'Guides',
		'Strategic Guides',
		'API Reference'
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
			const areaNames = [...bucket.subgroups.keys()].sort((a, b) =>
			{
				const ia = AREA_ORDER.indexOf(a), ib = AREA_ORDER.indexOf(b);
				return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib) || a.localeCompare(b);
			});
			for(const area of areaNames)
			{
				const cmp = area === 'apex' ? apexCompare : orderCompare;
				const ordered = bucket.subgroups.get(area).slice().sort((a, b) =>
						(isAreaIndex(a) ? 0 : 1) - (isAreaIndex(b) ? 0 : 1) || cmp(a, b));
					items.push({text: area, collapsed: true, items: ordered.map(link)});
			}
		}
		sidebar.push({text: name, collapsed: name === 'API Reference', items});
	}
	return sidebar;
}
