// SPDX-License-Identifier: Apache-2.0
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import * as methodGroups from './method-groups.mjs';
import {extractHeadingIds, slugifyHeading} from './anchor-normalizer.mjs';
import {parseFrontmatter} from './frontmatter.mjs';
import {buildSitePlan} from './prepare.mjs';

const {GROUP_NAMES, GROUPS_BY_CLASS = {}, groupMembers, insertGroupTable, methodNamesOf, renderGroupTable} = methodGroups;
const DOCS = fileURLToPath(new URL('../../docs', import.meta.url));
const BUILDER = 'QRY_Builder.Builder';
const BUILDER_REL = `reference/apex/${BUILDER}.md`;
const BUILDER_OUT = 'reference/apex/qry-builder-builder.md';
const BUILDER_RAW = readFileSync(`${DOCS}/${BUILDER_REL}`, 'utf8');
const GUIDE_NAMES = ['Selectors - Guide', 'Fast Start - Selectors'];

function realPages()
{
	return [
		...GUIDE_NAMES.map(name => ({relPath: `${name}.md`, raw: readFileSync(`${DOCS}/${name}.md`, 'utf8')})),
		{relPath: BUILDER_REL, raw: BUILDER_RAW}
	];
}

function plan(docInputs, extra = {})
{
	return buildSitePlan({docInputs, readme: null, agents: null, mirrorExcluded: new Set(), locked: [], redirects: {}, searchCases: [], ...extra});
}

function builderContent(extra)
{
	// Without the `head` line that links the page's Markdown copy, so that this test reads the page as it was.
	return plan(realPages(), extra).writes.find(w => w.outRel === BUILDER_OUT).content.replace(/^head: .*\n/m, '');
}

test('the method names are read from the method detail of the page', () =>
{
	const names = methodNamesOf(parseFrontmatter(BUILDER_RAW).content);
	assert.ok(names.length > 70, `only ${names.length} methods found`);
	assert.ok(names.includes('condition') && names.includes('toList') && names.includes('withSystemMode'));
	assert.ok(!names.includes('Builder()'), 'a constructor is not a method');
	assert.ok(!names.includes('objectType'), 'a property is not a method');
	assert.equal(new Set(names).size, names.length, 'each method is listed once');
});

test('every QRY_Builder.Builder method lands in one group', () =>
{
	const names = methodNamesOf(parseFrontmatter(BUILDER_RAW).content);
	const groups = groupMembers(BUILDER, names);
	const placed = groups.flatMap(g => g.members);
	assert.deepEqual([...placed].sort(), [...names].sort());
	assert.equal(new Set(placed).size, placed.length, 'no method is in two groups');
	assert.deepEqual(groups.map(g => g.group), GROUP_NAMES.filter(name => groups.some(g => g.group === name)));
	const groupOf = name => groups.find(g => g.members.includes(name)).group;
	assert.equal(groupOf('fields'), 'Choose fields');
	assert.equal(groupOf('andCondition'), 'Filter records');
	assert.equal(groupOf('orderBy'), 'Sort and limit');
	assert.equal(groupOf('withLimit'), 'Sort and limit');
	assert.equal(groupOf('orderByCount'), 'Count and total');
	assert.equal(groupOf('havingSumOf'), 'Count and total');
	assert.equal(groupOf('toAggregateList'), 'Run the query');
	assert.equal(groupOf('getFirst'), 'Run the query');
	assert.equal(groupOf('withSystemMode'), 'Security and row locking');
	assert.equal(groupOf('toSoql'), 'Other');
});

test('the security and row locking group holds exactly its nine methods, and Other the remaining seven', () =>
{
	const names = methodNamesOf(parseFrontmatter(BUILDER_RAW).content);
	const groups = groupMembers(BUILDER, names);
	const membersOf = label => groups.find(g => g.group === label).members.slice().sort();
	assert.deepEqual(membersOf('Security and row locking'), [
		'bypassSharing', 'forReference', 'forUpdate', 'forView', 'stripInaccessible', 'withSharing', 'withSystemMode', 'withUserMode', 'withoutSecurity'
	]);
	assert.deepEqual(membersOf('Other'), [
		'forcePerformanceLogging', 'isCached', 'logPerformanceIfSlowerThan', 'suppressPerformanceLogging', 'toSoql', 'withCache', 'withoutCache'
	]);
	assert.deepEqual(GROUP_NAMES.slice(-2), ['Security and row locking', 'Other']);
});

test('the worked examples are the guide headings for each group', () =>
{
	const groups = groupMembers(BUILDER, methodNamesOf(parseFrontmatter(BUILDER_RAW).content));
	const headingOf = label => groups.find(g => g.group === label).exampleLink.heading;
	assert.equal(headingOf('Run the query'), 'Result Transformation');
	assert.equal(headingOf('Security and row locking'), 'Security & Row Locking');
	assert.equal(headingOf('Other'), 'Caching Queries');
	assert.equal(groups.find(g => g.group === 'Other').exampleLink.secondHeading, 'Query Performance Logging');
});

test('a new method falls into Other', () =>
{
	const groups = groupMembers(BUILDER, ['condition', 'aBrandNewMethod']);
	assert.deepEqual(groups.map(g => [g.group, g.members]), [['Filter records', ['condition']], ['Other', ['aBrandNewMethod']]]);
});

test('a class with no grouping gets no groups', () =>
{
	assert.deepEqual(groupMembers('QRY_Builder', ['selectFrom']), []);
	assert.deepEqual(groupMembers(BUILDER, []), []);
});

test('each group links a real anchor', () =>
{
	const idsByPage = new Map(GUIDE_NAMES.map(name => [
		name,
		new Set(extractHeadingIds(parseFrontmatter(readFileSync(`${DOCS}/${name}.md`, 'utf8')).content))
	]));
	const groups = groupMembers(BUILDER, [...methodNamesOf(parseFrontmatter(BUILDER_RAW).content)]);
	assert.equal(groups.length, GROUP_NAMES.length, 'every group has a method');
	for(const {group, exampleLink} of groups)
	{
		assert.ok(idsByPage.has(exampleLink.page), `${group} links an unknown page ${exampleLink.page}`);
		assert.ok(idsByPage.get(exampleLink.page).has(slugifyHeading(exampleLink.heading)), `${group}: no heading "${exampleLink.heading}"`);
		if(exampleLink.secondHeading)
		{
			assert.ok(idsByPage.get(exampleLink.page).has(slugifyHeading(exampleLink.secondHeading)), `${group}: no heading "${exampleLink.secondHeading}"`);
		}
	}
});

test('the table is short, in plain words, with each method linked to its detail', () =>
{
	const groups = groupMembers(BUILDER, ['condition', 'andCondition', 'toList']);
	const table = renderGroupTable(groups);
	assert.equal(table, [
		'## Methods by task',
		'',
		'Find a method by what you want to do. A group links to a worked example when a guide has one. Every method is described in the full list below.',
		'',
		'| Group | Methods | Worked example |',
		'|-------|---------|----------------|',
		'| **Filter records** | [`condition`](#condition) [`andCondition`](#andcondition) | [WHERE Conditions](/selectors-guide#where-conditions) |',
		'| **Run the query** | [`toList`](#tolist) | [Result Transformation](/selectors-guide#result-transformation) |',
		''
	].join('\n'));
	assert.ok(!table.includes('—'));
	assert.equal(renderGroupTable([]), '');
});

test('the Other row links both the caching and the performance-logging examples', () =>
{
	const table = renderGroupTable(groupMembers(BUILDER, ['withCache']));
	assert.ok(table.includes('| **Other** | [`withCache`](#withcache) | '
		+ '[Caching Queries](/selectors-guide#caching-queries), [Query Performance Logging](/selectors-guide#query-performance-logging) |'), table);
});

test('the table goes straight before the method list', () =>
{
	const body = '# A\n\nText\n\n---\n\n## Methods\n\n| x |\n';
	assert.equal(insertGroupTable(body, '## T\n\nRow\n'), '# A\n\nText\n\n---\n\n## T\n\nRow\n\n## Methods\n\n| x |\n');
	assert.equal(insertGroupTable(body, ''), body);
	assert.equal(insertGroupTable('# A\n\nNo methods\n', '## T\n'), '# A\n\nNo methods\n');
});

test('alphabetical detail and anchors stay', () =>
{
	const content = builderContent();
	const before = plan(realPages(), {frozen: true}).writes.find(w => w.outRel === BUILDER_OUT).content;
	const beforeIds = extractHeadingIds(before);
	const afterIds = new Set(extractHeadingIds(content));
	for(const id of beforeIds)
	{
		assert.ok(afterIds.has(id), `anchor #${id} is gone`);
	}
	const methodsAt = content.indexOf('\n## Methods\n');
	assert.ok(content.indexOf('## Methods by task') < methodsAt, 'the group table is above the method list');
	assert.ok(content.slice(methodsAt).startsWith(before.slice(before.indexOf('\n## Methods\n'))), 'the method list and detail are unchanged');
	for(const [, anchor] of content.slice(0, methodsAt).matchAll(/\]\(#([^)]+)\)/g))
	{
		assert.ok(afterIds.has(anchor), `the table links #${anchor}, which is not on the page`);
	}
});

test('the build adds the table to QRY_Builder.Builder only, and never to a frozen tree', () =>
{
	assert.ok(builderContent().includes('| **Count and total** |'));
	assert.ok(!builderContent({frozen: true}).includes('Methods by task'));
	const r = plan([...realPages(), {relPath: 'reference/apex/QRY_Builder.md', raw: readFileSync(`${DOCS}/reference/apex/QRY_Builder.md`, 'utf8')}]);
	assert.ok(!r.writes.find(w => w.outRel === 'reference/apex/qry-builder.md').content.includes('Methods by task'));
	assert.deepEqual(r.unresolvedAnchors.filter(a => a.startsWith(BUILDER_OUT)), []);
});

test('QRY_Builder.Builder groups are unchanged', () =>
{
	const selectors = 'Selectors - Guide';
	assert.deepEqual(GROUPS_BY_CLASS[BUILDER], {
		groups: [
			{
				group: 'Choose fields',
				names: ['fields', 'fieldSet', 'addField', 'addFields', 'addFieldSet', 'relatedField', 'relatedFields', 'selectAllFields', 'subselect', 'getDefaultFields'],
				exampleLink: {page: selectors, heading: 'SELECT and FROM'}
			},
			{
				group: 'Filter records',
				names: ['condition', 'andCondition', 'orCondition', 'addCondition', 'allRows', 'usingScope', 'withDataCategory'],
				exampleLink: {page: selectors, heading: 'WHERE Conditions'}
			},
			{
				group: 'Sort and limit',
				names: ['orderBy', 'ascending', 'descending', 'nullsFirst', 'nullsLast', 'withLimit', 'withOffset'],
				exampleLink: {page: selectors, heading: 'ORDER BY and LIMIT'}
			},
			{
				group: 'Count and total',
				names: ['count', 'countDistinct', 'sum', 'avg', 'min', 'max', 'groupBy', 'grouping', 'rollup', 'cube', 'orderByCount'],
				prefix: /^having[A-Z]/,
				exampleLink: {page: selectors, heading: 'Aggregate Functions'}
			},
			{
				group: 'Run the query',
				names: ['getFirst', 'getFirstAggregate', 'getPage', 'getRandomItem', 'getRandomItems', 'exists'],
				prefix: /^(?:to(?!Soql$)|as)[A-Z]/,
				exampleLink: {page: selectors, heading: 'Result Transformation'}
			},
			{
				group: 'Security and row locking',
				names: ['bypassSharing', 'withSharing', 'withSystemMode', 'withUserMode', 'withoutSecurity', 'stripInaccessible', 'forUpdate', 'forView', 'forReference'],
				exampleLink: {page: selectors, heading: 'Security & Row Locking'}
			},
			{
				group: 'Other',
				names: [],
				exampleLink: {page: selectors, heading: 'Caching Queries', secondHeading: 'Query Performance Logging'}
			}
		],
		matchOrder: ['Count and total', 'Choose fields', 'Filter records', 'Sort and limit', 'Run the query', 'Security and row locking']
	});
	assert.deepEqual(GROUP_NAMES, GROUPS_BY_CLASS[BUILDER].groups.map(g => g.group));
});

// The eight more classes with a "Methods by task" table, and for each the group of one method
// on its page, to show the groups read the way the method's description says.
const MORE_CLASSES = Object.freeze([
	{className: 'UTIL_SObjectDescribe', sample: ['getPicklistValues', 'Read picklists and record types']},
	{className: 'UTIL_HttpClient.RequestBuilder', sample: ['withExponentialBackoff', 'Retry, or stop calling a failing system']},
	{className: 'API_Outbound', sample: ['getRetryableStatusCodes', 'Retry a failed call']},
	{className: 'UTIL_Limits', sample: ['queueableJobs', 'Background jobs']},
	{className: 'SEL_Base', sample: ['findFirstByFields', 'Find records by Id or by a field']},
	{className: 'QRY_Builder.ConditionBuilder', sample: ['includesStrict', 'Filter a multi-select picklist']},
	{className: 'API_Inbound', sample: ['writeResponse', 'Answer the caller, or report a failure']},
	{className: 'DML_Builder', sample: ['withRetryOnLock', 'Handle records that fail to save']}
]);

const EXAMPLE_PAGES = new Map();

function headingIdsOf(page)
{
	if(!EXAMPLE_PAGES.has(page))
	{
		EXAMPLE_PAGES.set(page, new Set(extractHeadingIds(parseFrontmatter(readFileSync(`${DOCS}/${page}.md`, 'utf8')).content)));
	}
	return EXAMPLE_PAGES.get(page);
}

function methodNamesOfClass(className)
{
	return methodNamesOf(parseFrontmatter(readFileSync(`${DOCS}/reference/apex/${className}.md`, 'utf8')).content);
}

for(const {className, sample: [sampleMethod, sampleGroup]} of MORE_CLASSES)
{
	test(`every ${className} method lands in one group`, () =>
	{
		const names = methodNamesOfClass(className);
		assert.ok(names.length > 10, `only ${names.length} methods found`);
		const groups = groupMembers(className, names);
		const placed = groups.flatMap(g => g.members);
		assert.deepEqual([...placed].sort(), [...names].sort());
		assert.equal(new Set(placed).size, placed.length, 'no method is in two groups');
		assert.ok(groups.length >= 3 && groups.length <= 6, `${groups.length} groups`);
		assert.ok(!groups.some(g => g.group === 'Other'), 'every method of today has a named group');
		assert.equal(groups.find(g => g.members.includes(sampleMethod)).group, sampleGroup);
		const ruleNames = GROUPS_BY_CLASS[className].groups.flatMap(r => r.names);
		assert.deepEqual(ruleNames.filter(name => !names.includes(name)), [], 'every listed name is a method on the page');
	});

	test(`each ${className} group links a real anchor, or says it has no worked example`, () =>
	{
		for(const rule of GROUPS_BY_CLASS[className].groups)
		{
			const {group, exampleLink} = rule;
			assert.ok(Object.hasOwn(rule, 'exampleLink'), `${className} ${group}: the group must give a link, or null for no worked example`);
			if(exampleLink === null)
			{
				continue;
			}
			const ids = headingIdsOf(exampleLink.page);
			for(const heading of [exampleLink.heading, exampleLink.secondHeading].filter(Boolean))
			{
				const id = slugifyHeading(heading);
				assert.ok(ids.has(id), `${className} ${group}: no heading "${heading}" on ${exampleLink.page}`);
				assert.ok(!ids.has(`${id}-1`), `${className} ${group}: "${heading}" is on ${exampleLink.page} more than once`);
			}
		}
	});
}

test('the build adds a table to each of the eight pages, and every link in it resolves', () =>
{
	const pages = [...new Set(MORE_CLASSES.flatMap(({className}) => GROUPS_BY_CLASS[className].groups.filter(g => g.exampleLink).map(g => g.exampleLink.page)))];
	const docInputs = [
		...pages.map(page => ({relPath: `${page}.md`, raw: readFileSync(`${DOCS}/${page}.md`, 'utf8')})),
		...MORE_CLASSES.map(({className}) => ({relPath: `reference/apex/${className}.md`, raw: readFileSync(`${DOCS}/reference/apex/${className}.md`, 'utf8')}))
	];
	const r = plan(docInputs);
	const tables = r.writes.filter(w => w.outRel.startsWith('reference/apex/') && w.content.includes('## Methods by task'));
	assert.equal(tables.length, MORE_CLASSES.length);
	const outRels = tables.map(w => w.outRel);
	assert.deepEqual(r.unresolvedAnchors.filter(a => outRels.some(outRel => a.startsWith(outRel))), []);
	const unlinked = new Set(MORE_CLASSES.flatMap(({className}) => GROUPS_BY_CLASS[className].groups.filter(g => g.exampleLink === null).map(g => g.group)));
	for(const {outRel, content} of tables)
	{
		const table = content.slice(content.indexOf('## Methods by task'), content.indexOf('\n## Methods\n'));
		for(const line of table.split('\n').filter(row => row.startsWith('| **')))
		{
			const group = line.match(/^\| \*\*(.+?)\*\* \|/)[1];
			if(unlinked.has(group))
			{
				assert.match(line, /\) \| {2}\|$/, `${outRel} ${group}: a group with no worked example has an empty last cell`);
			}
			else
			{
				assert.match(line, /\]\(\/[^)]+#[^)]+\) \|$/, `${outRel} ${group}: the row has no worked example`);
			}
		}
		assert.ok(!table.includes(']()') && !table.includes('](#)') && !table.includes('undefined'), `${outRel}: a broken link`);
	}
});

test('only the groups with no worked example in any guide have no link', () =>
{
	const unlinked = Object.entries(GROUPS_BY_CLASS)
	.flatMap(([className, {groups}]) => groups.filter(g => g.exampleLink === null).map(g => [className, g.group]));
	assert.deepEqual(unlinked, [
		['UTIL_SObjectDescribe', 'Read picklists and record types'],
		['UTIL_HttpClient.RequestBuilder', 'Replace words in the request or answer body'],
		['API_Outbound', 'Run your own code when the save starts or ends'],
		['API_Inbound', 'Run your own code when the save starts or ends']
	]);
});

test('switching an API off and the save hooks are two groups', () =>
{
	const groupOf = (className, name) => groupMembers(className, methodNamesOfClass(className)).find(g => g.members.includes(name)).group;
	assert.equal(groupOf('API_Outbound', 'isDisabled'), 'Switch the call off');
	assert.equal(groupOf('API_Outbound', 'onCommitWorkStarting'), 'Run your own code when the save starts or ends');
	assert.equal(groupOf('API_Inbound', 'isDisabled'), 'Switch the API off');
	assert.equal(groupOf('API_Inbound', 'onCommitWorkStarting'), 'Run your own code when the save starts or ends');
	assert.equal(groupOf('API_Inbound', 'onCommitWorkFinishing'), 'Run your own code when the save starts or ends');
	assert.equal(groupOf('UTIL_HttpClient.RequestBuilder', 'withMockResponse'), 'Test the call, or set its IDs and logging');
	assert.equal(groupOf('UTIL_HttpClient.RequestBuilder', 'replaceResponseTokens'), 'Replace words in the request or answer body');
});

test('a group with no worked example is shown with an empty cell, never a broken link', () =>
{
	const table = renderGroupTable(groupMembers('UTIL_SObjectDescribe', ['getPicklistValues']));
	assert.ok(table.includes('| **Read picklists and record types** | [`getPicklistValues`](#getpicklistvalues) |  |'), table);
	assert.ok(!table.includes(']('.concat('/')), table);
	const page = 'UTIL_SObjectDescribe';
	const content = plan([
		{relPath: 'Utilities - Guide.md', raw: readFileSync(`${DOCS}/Utilities - Guide.md`, 'utf8')},
		{relPath: `reference/apex/${page}.md`, raw: readFileSync(`${DOCS}/reference/apex/${page}.md`, 'utf8')}
	]).writes.find(w => w.outRel === 'reference/apex/util-sobjectdescribe.md').content;
	const row = content.split('\n').find(line => line.startsWith('| **Read picklists and record types** |'));
	assert.ok(row, 'the group is shown');
	assert.ok(row.endsWith(') |  |') && !row.includes('utilities-guide'), row);
});

test('a new method of one of the eight classes falls into Other', () =>
{
	const groups = groupMembers('DML_Builder', ['doInsert', 'aBrandNewMethod']);
	assert.deepEqual(groups.map(g => [g.group, g.members]), [['Register records and save them', ['doInsert']], ['Other', ['aBrandNewMethod']]]);
});

test('a worked example on a page that is not built is left out, never linked dead', () =>
{
	const content = plan([{relPath: BUILDER_REL, raw: BUILDER_RAW}]).writes.find(w => w.outRel === BUILDER_OUT).content;
	assert.ok(content.includes('| **Filter records** |'));
	assert.ok(!content.includes('/selectors-guide'));
});
