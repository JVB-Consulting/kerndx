// SPDX-License-Identifier: BUSL-1.1
import {defineConfig} from 'vitepress';
import {withMermaid} from 'vitepress-plugin-mermaid';
import sidebar from './sidebar.generated.mjs';
import {repoUrl} from '../scripts/repo.mjs';
import {seoHeadEntries} from '../scripts/seo-head.mjs';

const HOSTNAME = 'https://docs.jvb-consulting.io';
const BASE = process.env.DOCS_BASE || '/';

export default withMermaid(defineConfig({
	title: 'KernDX',
	description: 'Source-available Salesforce Apex + LWC framework and library suite.',
	srcDir: 'src',
	lang: 'en-US',
	// '/' under the custom domain (mirror). A GitHub project-page deploy (e.g. the
	// ephemeral test repo) sets DOCS_BASE=/<repo>/ so assets resolve under the subpath.
	base: BASE,
	cleanUrls: true,
	ignoreDeadLinks: false,
	lastUpdated: true,
	sitemap: {hostname: HOSTNAME},
	// Sitewide head: favicon (base-aware so it resolves on both the custom domain
	// and a /<repo>/ project-page deploy) + brand theme color + author.
	head: [
		['link', {rel: 'icon', type: 'image/svg+xml', href: `${BASE}favicon.svg`}],
		['meta', {name: 'theme-color', content: '#8a623c'}],
		['meta', {name: 'author', content: 'JVB Consulting'}]
	],
	themeConfig: {
		search: {
			provider: 'local', options: {
				// The corpus is code-heavy (269 auto-generated Apex reference pages). Indexing
				// fenced code blocks pushed the local-search index well past the ~1 MB target, so
				// strip fenced code (and the noisy frontmatter) from the indexed content before
				// rendering. Prose, headings, and tables are still indexed; code is excluded.
				_render(src, env, md)
				{
					// Closing fence must use the same character as the opener AND be at least
					// as long (CommonMark). Capture the fence char (group 2) so the close is the
					// opener (\1) followed by zero-or-more of that same char (\2*) — length >=
					// opener. A bare \1 backreference (exact-length) leaves a block closed by a
					// longer fence unstripped, leaking code into the search index.
					const withoutCode = src
					.replace(/^---\n[\s\S]*?\n---\n/, '')
					.replace(/^ {0,3}(([`~])\2{2,})[\s\S]*?^ {0,3}\1\2*\s*$/gm, '');
					return md.render(withoutCode, env);
				}
			}
		}, sidebar, outline: {
			level: [
				2,
				3
			]
		}, socialLinks: [{icon: 'github', link: repoUrl()}]
	},
	markdown: {
		lineNumbers: false
	}, // Canonical + Open Graph + Twitter card per page.
	transformPageData(pageData)
	{
		const url = `${HOSTNAME}/${pageData.relativePath.replace(/(^|\/)index\.md$/, '$1').replace(/\.md$/, '')}`;
		// Resolved title: frontmatter title, else VitePress's H1-derived title. Guides carry
		// no frontmatter, so frontmatter.title is undefined for them — pageData.title is what
		// the <title> tag uses, and it is unique per page.
		const resolvedTitle = pageData.frontmatter.title || pageData.title;
		// The home page resolves to the bare site name "KernDX"; appending "| KernDX" (and,
		// below, the "{title} — KernDX, ..." description) would double it ("KernDX | KernDX",
		// "KernDX — KernDX, ..."). Special-case it to the plain site name + default description.
		const isHome = pageData.relativePath.replace(/(^|\/)index\.md$/, '$1') === '' || resolvedTitle === 'KernDX';
		const title = (!isHome && resolvedTitle) ? `${resolvedTitle} | KernDX` : 'KernDX';
		// Unique, non-empty <meta name="description"> per page. Without this, every page
		// lacking a frontmatter description inherits the site-wide default — a duplicate
		// meta-description SEO defect across 60+ pages. Two rules guarantee uniqueness:
		//   (1) no description → synthesize a title-based one (titles are unique);
		//   (2) reference (API) page WITH a description that doesn't already name its member
		//       → lead with the member name, so sibling classes (AndCondition / OrCondition)
		//         never share an identical description.
		// VitePress emits <meta name="description"> from pageData.description (top-level),
		// falling back to the site description — NOT from frontmatter.description. Setting
		// pageData.description is what actually overrides the per-page meta.
		const isReference = pageData.relativePath.startsWith('reference/');
		let desc = pageData.frontmatter.description;
		if (!desc)
		{
			desc = (resolvedTitle && !isHome)
				? `${resolvedTitle} — KernDX, a source-available Salesforce Apex and LWC framework.`
				: 'Source-available Salesforce Apex + LWC framework and library suite.';
		}
		else if (isReference && resolvedTitle && !desc.includes(resolvedTitle))
		{
			desc = `${resolvedTitle} — ${desc}`;
		}
		pageData.description = desc;
		pageData.frontmatter.head ??= [];
		pageData.frontmatter.head.push([
			'link',
			{rel: 'canonical', href: url}
		], [
			'meta',
			{property: 'og:type', content: 'website'}
		], [
			'meta',
			{property: 'og:title', content: title}
		], [
			'meta',
			{property: 'og:description', content: desc}
		], [
			'meta',
			{property: 'og:url', content: url}
		], [
			'meta',
			{name: 'twitter:card', content: 'summary_large_image'}
		], [
			'meta',
			{name: 'twitter:title', content: title}
		], [
			'meta',
			{name: 'twitter:description', content: desc}
		]);
		// Social-share image (absolute https), OG site metadata, and schema.org
		// JSON-LD (Organization + WebSite sitewide, per-page TechArticle).
		pageData.frontmatter.head.push(...seoHeadEntries({title, description: desc, url, hostname: HOSTNAME, isHome}));
	}
}));
