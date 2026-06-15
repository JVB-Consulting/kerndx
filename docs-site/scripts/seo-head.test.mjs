// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildStructuredData, seoHeadEntries, OG_IMAGE} from './seo-head.mjs';

const HOST = 'https://docs.jvb-consulting.io';

test('buildStructuredData emits an Organization + WebSite graph sitewide', () =>
{
	const sd = buildStructuredData({title: 'KernDX', url: `${HOST}/`, hostname: HOST, isHome: true});
	assert.equal(sd['@context'], 'https://schema.org');
	const types = sd['@graph'].map((n) => n['@type']);
	assert.deepEqual(types, ['Organization', 'WebSite']);
	const site = sd['@graph'].find((n) => n['@type'] === 'WebSite');
	assert.equal(site.name, 'KernDX');
	assert.equal(site.url, `${HOST}/`);
	assert.equal(site.publisher['@id'], `${HOST}/#organization`);
});

test('buildStructuredData adds a TechArticle on non-home pages, linked to the WebSite', () =>
{
	const url = `${HOST}/reference/qry-builder`;
	const sd = buildStructuredData({title: 'QRY_Builder | KernDX', description: 'Fluent SOQL.', url, hostname: HOST, isHome: false});
	const article = sd['@graph'].find((n) => n['@type'] === 'TechArticle');
	assert.ok(article, 'TechArticle present');
	assert.equal(article.headline, 'QRY_Builder | KernDX');
	assert.equal(article.url, url);
	assert.equal(article.description, 'Fluent SOQL.');
	assert.equal(article.isPartOf['@id'], `${HOST}/#website`);
});

test('buildStructuredData omits an absent description (no null/undefined leakage)', () =>
{
	const sd = buildStructuredData({title: 'X | KernDX', url: `${HOST}/x`, hostname: HOST, isHome: false});
	const article = sd['@graph'].find((n) => n['@type'] === 'TechArticle');
	assert.ok(!('description' in article) || typeof article.description === 'string');
	// survives a JSON round-trip with no literal "undefined"
	assert.ok(!JSON.stringify(sd).includes('undefined'));
});

test('seoHeadEntries includes an absolute-https og:image + dimensions + twitter:image', () =>
{
	const entries = seoHeadEntries({title: 'KernDX', url: `${HOST}/`, hostname: HOST, isHome: true});
	const og = entries.find((e) => e[0] === 'meta' && e[1].property === 'og:image');
	assert.equal(og[1].content, `${HOST}/${OG_IMAGE}`);
	assert.match(og[1].content, /^https:\/\//);
	assert.ok(entries.some((e) => e[1].property === 'og:image:width'));
	assert.ok(entries.some((e) => e[1].property === 'og:image:height'));
	assert.ok(entries.some((e) => e[0] === 'meta' && e[1].name === 'twitter:image' && e[1].content === `${HOST}/${OG_IMAGE}`));
});

test('seoHeadEntries adds og:site_name, og:locale, and a parseable JSON-LD script', () =>
{
	const entries = seoHeadEntries({title: 'KernDX', url: `${HOST}/`, hostname: HOST, isHome: true});
	assert.ok(entries.some((e) => e[1].property === 'og:site_name' && e[1].content === 'KernDX'));
	assert.ok(entries.some((e) => e[1].property === 'og:locale' && e[1].content === 'en_US'));
	const ld = entries.find((e) => e[0] === 'script' && e[1].type === 'application/ld+json');
	assert.ok(ld, 'json-ld script present');
	const parsed = JSON.parse(ld[2]);
	assert.equal(parsed['@context'], 'https://schema.org');
});
