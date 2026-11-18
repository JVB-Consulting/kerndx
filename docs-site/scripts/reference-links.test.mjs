// SPDX-License-Identifier: Apache-2.0
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {
	CLASS_OVERRIDES, allLinkTargets, insertLinkLine, isApexClassPage, linksForClass, pathForTarget, renderLinkLine
} from './reference-links.mjs';
import {buildSitePlan} from './prepare.mjs';

const DOCS = fileURLToPath(new URL('../../docs', import.meta.url));
const APEX_DIR = `${DOCS}/reference/apex`;

// The pages the build makes from the real docs folder: the top-level guides and the Apex reference.
function realDocInputs()
{
	const top = readdirSync(DOCS).filter(f => f.endsWith('.md')).map(f => ({relPath: f, raw: readFileSync(`${DOCS}/${f}`, 'utf8')}));
	const apex = readdirSync(APEX_DIR).filter(f => f.endsWith('.md')).map(f => ({relPath: `reference/apex/${f}`, raw: readFileSync(`${APEX_DIR}/${f}`, 'utf8')}));
	return [...top, ...apex];
}

function plan(docInputs, extra = {})
{
	return buildSitePlan({docInputs, readme: null, agents: null, mirrorExcluded: new Set(), locked: [], redirects: {}, searchCases: [], ...extra});
}

const CLASS_PAGE = '---\ntitle: "QRY_Builder"\ntype: class\n---\n\n# QRY_Builder\n\n**Class** · Group: `Query Infrastructure`\n\n<div class="apex-member">\n\nSummary.\n\n</div>\n\n---\n\n## Methods\n';
const GUIDE_PAGES = ['Fast Start - Selectors.md', 'Selectors - Guide.md'].map(relPath => ({relPath, raw: '# Page\n'}));

test('QRY_Builder links Selectors', () =>
{
	assert.deepEqual(linksForClass('QRY_Builder'), {fastStart: 'Fast Start - Selectors', guide: 'Selectors - Guide'});
});

test('QRY_Builder.Builder uses its outer class', () =>
{
	assert.deepEqual(linksForClass('QRY_Builder.Builder'), linksForClass('QRY_Builder'));
	assert.deepEqual(linksForClass('UTIL_AsyncChain.ChainBuilder'), linksForClass('UTIL_AsyncChain'));
});

test('UTIL_AsyncChain links Async Processing', () =>
{
	assert.deepEqual(linksForClass('UTIL_AsyncChain'), {fastStart: 'Fast Start - Async Processing', guide: 'Async Processing - Guide'});
});

test('UTIL_HttpClient links Web Services', () =>
{
	assert.equal(linksForClass('UTIL_HttpClient').guide, 'Web Services - Guide');
	assert.equal(linksForClass('UTIL_HttpClient').fastStart, 'Fast Start - Outbound APIs');
});

test('a UTIL_ class with no override links the Utilities guide only', () =>
{
	assert.deepEqual(linksForClass('UTIL_Date'), {guide: 'Utilities - Guide'});
});

test('a FLOW_ class with no match has no line', () =>
{
	assert.deepEqual(linksForClass('FLOW_GetPicklistValues'), {});
	assert.deepEqual(linksForClass('FLOW_SomethingNew'), {});
	assert.equal(renderLinkLine(linksForClass('FLOW_SomethingNew')), '');
});

test('a class with an unknown prefix has no line', () =>
{
	assert.deepEqual(linksForClass('ZZZ_Weird'), {});
	assert.deepEqual(linksForClass('NoPrefix'), {});
});

test('a class the framework never teaches is left without a line', () =>
{
	for(const name of ['PROC_UpdateFields', 'TRG_ApiCall', 'IF_Queryable', 'CTRL_TableDataSource'])
	{
		assert.deepEqual(linksForClass(name), {}, name);
	}
});

test('the line is short, in plain words and holds no em-dash', () =>
{
	const line = renderLinkLine(linksForClass('QRY_Builder'));
	assert.equal(line, 'Learn it: [Fast Start - Selectors](/fast-start-selectors) and [Selectors guide](/selectors-guide)');
	assert.ok(!line.includes('—'));
	assert.equal(renderLinkLine({guide: 'Utilities - Guide'}), 'Learn it: [Utilities guide](/utilities-guide)');
});

test('the line goes after the heading and the kind line, before the first section', () =>
{
	const out = insertLinkLine('# QRY_Builder\n\n**Class** · Group: `X`\n\n<div>\n\nText\n\n</div>\n\n## Methods\n', 'Learn it: [A](/a)');
	assert.equal(out, '# QRY_Builder\n\n**Class** · Group: `X`\n\nLearn it: [A](/a)\n\n<div>\n\nText\n\n</div>\n\n## Methods\n');
	assert.equal(insertLinkLine('# Title\n\nText\n', 'Learn it: [A](/a)'), '# Title\n\nLearn it: [A](/a)\n\nText\n');
	assert.equal(insertLinkLine('# Title\n', ''), '# Title\n');
});

test('only Apex class pages get a line; object, event and metadata pages are left out', () =>
{
	assert.equal(isApexClassPage('reference/apex/QRY_Builder.md'), true);
	assert.equal(isApexClassPage('reference/apex/QRY_Builder.Builder.md'), true);
	assert.equal(isApexClassPage('reference/apex/index.md'), false);
	assert.equal(isApexClassPage('reference/objects/ApiCall__c.md'), false);
	assert.equal(isApexClassPage('reference/events/LogEntryEvent__e.md'), false);
	assert.equal(isApexClassPage('reference/metadata/Setting__mdt.md'), false);
	assert.equal(isApexClassPage('Selectors - Guide.md'), false);
});

test('the build adds the line to a class page and leaves an object page as it was', () =>
{
	const objectPage = '# ApiCall__c\n\n**Object**\n\nText\n';
	const r = plan([
		...GUIDE_PAGES,
		{relPath: 'reference/apex/QRY_Builder.md', raw: CLASS_PAGE},
		{relPath: 'reference/objects/ApiCall__c.md', raw: objectPage}
	]);
	const classContent = r.writes.find(w => w.outRel === 'reference/apex/qry-builder.md').content;
	assert.ok(classContent.includes('**Class** · Group: `Query Infrastructure`\n\nLearn it: [Fast Start - Selectors](/fast-start-selectors) and [Selectors guide](/selectors-guide)\n\n<div'));
	assert.ok(classContent.indexOf('Learn it:') < classContent.indexOf('## Methods'));
	const objectContent = r.writes.find(w => w.outRel === 'reference/objects/apicall-c.md').content.replace(/^---\nhead: .*\n---\n/, '');
	assert.equal(objectContent, objectPage);
});

test('frozen builds add nothing', () =>
{
	const input = [...GUIDE_PAGES, {relPath: 'reference/apex/QRY_Builder.md', raw: CLASS_PAGE}];
	const frozen = plan(input, {frozen: true}).writes.find(w => w.outRel === 'reference/apex/qry-builder.md').content;
	assert.ok(!frozen.includes('Learn it'));
	const latest = plan(input).writes.find(w => w.outRel === 'reference/apex/qry-builder.md').content;
	assert.ok(latest.includes('Learn it'));
});

test('a target that is not built is left out, never linked dead', () =>
{
	const guideOnly = plan([{relPath: 'Selectors - Guide.md', raw: '# Page\n'}, {relPath: 'reference/apex/QRY_Builder.md', raw: CLASS_PAGE}]);
	const content = guideOnly.writes.find(w => w.outRel === 'reference/apex/qry-builder.md').content;
	assert.ok(content.includes('\nLearn it: [Selectors guide](/selectors-guide)\n'));
	assert.ok(!content.includes('fast-start-selectors'));
	const neither = plan([{relPath: 'reference/apex/QRY_Builder.md', raw: CLASS_PAGE}]);
	assert.ok(!neither.writes.find(w => w.outRel === 'reference/apex/qry-builder.md').content.includes('Learn it'));
});

test('every target in the table is a real page', () =>
{
	const built = plan(realDocInputs());
	const slugs = new Set(built.pages.map(p => p.slug));
	assert.ok(allLinkTargets().length > 0);
	for(const target of allLinkTargets())
	{
		assert.ok(slugs.has(pathForTarget(target).slice(1)), `${target} is not a built page`);
	}
});

test('every override is a real class page', () =>
{
	const classes = new Set(readdirSync(APEX_DIR).filter(f => f.endsWith('.md')).map(f => f.replace(/\.md$/, '')));
	for(const name of Object.keys(CLASS_OVERRIDES))
	{
		assert.ok(classes.has(name), `${name} has no page in docs/reference/apex`);
	}
});

test('every link on a real class page leads to a built page', () =>
{
	const built = plan(realDocInputs());
	const slugs = new Set(built.pages.map(p => p.slug));
	let withLine = 0;
	for(const {outRel, content} of built.writes.filter(w => w.outRel.startsWith('reference/apex/') && !w.outRel.endsWith('index.md')))
	{
		const line = content.split('\n').find(l => l.startsWith('Learn it: '));
		if(!line)
		{
			continue;
		}
		withLine++;
		for(const [, href] of line.matchAll(/\]\((\/[^)]+)\)/g))
		{
			assert.ok(slugs.has(href.slice(1)), `${outRel} links to ${href}`);
		}
	}
	assert.ok(withLine > 100, `only ${withLine} class pages got a line`);
});
