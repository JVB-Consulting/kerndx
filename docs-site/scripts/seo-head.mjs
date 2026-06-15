// SPDX-License-Identifier: BUSL-1.1

// Builds the social-share + structured-data head entries layered on top of the
// per-page canonical / OG / Twitter meta in .vitepress/config.mjs. Kept as a
// pure, testable helper (like meta-description.mjs) so the schema.org graph and
// the absolute-https image URLs are covered by unit tests rather than asserted
// only through a full VitePress build.

export const OG_IMAGE = 'og-image.png';
const IMAGE_WIDTH = '1280';
const IMAGE_HEIGHT = '640';
const SITE_NAME = 'KernDX';
const SITE_DESCRIPTION = 'Source-available Salesforce Apex + LWC framework and library suite.';

// schema.org JSON-LD graph: a sitewide Organization + WebSite, plus a per-page
// TechArticle on every non-home page (linked back to the WebSite). Gives search
// engines explicit entity understanding + rich-result eligibility.
export function buildStructuredData({title, description, url, hostname, isHome})
{
	const organization = {
		'@type': 'Organization',
		'@id': `${hostname}/#organization`,
		name: 'JVB Consulting',
		url: `${hostname}/`,
		logo: `${hostname}/${OG_IMAGE}`
	};
	const website = {
		'@type': 'WebSite',
		'@id': `${hostname}/#website`,
		name: SITE_NAME,
		url: `${hostname}/`,
		description: SITE_DESCRIPTION,
		publisher: {'@id': `${hostname}/#organization`}
	};
	const graph = [organization, website];
	if(!isHome && title)
	{
		const article = {
			'@type': 'TechArticle',
			headline: title,
			url,
			isPartOf: {'@id': `${hostname}/#website`},
			publisher: {'@id': `${hostname}/#organization`}
		};
		if(description)
		{
			article.description = description;
		}
		graph.push(article);
	}
	return {'@context': 'https://schema.org', '@graph': graph};
}

// VitePress head entries (the [tag, attrs, innerHTML?] form) for the social
// image, OG site metadata, and the JSON-LD script. Layered on top of the OG /
// Twitter text tags already emitted by transformPageData.
export function seoHeadEntries({title, description, url, hostname, isHome})
{
	const image = `${hostname}/${OG_IMAGE}`;
	const structuredData = buildStructuredData({title, description, url, hostname, isHome});
	return [
		['meta', {property: 'og:site_name', content: SITE_NAME}],
		['meta', {property: 'og:locale', content: 'en_US'}],
		['meta', {property: 'og:image', content: image}],
		['meta', {property: 'og:image:width', content: IMAGE_WIDTH}],
		['meta', {property: 'og:image:height', content: IMAGE_HEIGHT}],
		['meta', {name: 'twitter:image', content: image}],
		['script', {type: 'application/ld+json'}, JSON.stringify(structuredData)]
	];
}
