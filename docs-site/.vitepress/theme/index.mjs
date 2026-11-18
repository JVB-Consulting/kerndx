// SPDX-License-Identifier: Apache-2.0
import {defineAsyncComponent, h, watch} from 'vue';
import DefaultTheme from 'vitepress/theme';
import './custom.css';
import VersionSwitcher from './VersionSwitcher.vue';
import VersionBanner from './VersionBanner.vue';
import Breadcrumb from './Breadcrumb.vue';
import ReferenceForPage from './ReferenceForPage.vue';
import {withExpandedSidebar} from '../../scripts/generate-nav.mjs';
import KernLanding from './components/KernLanding.vue';
import CodeCompare from './components/CodeCompare.vue';
import FeatureGroup from './components/FeatureGroup.vue';
import HeroLoop from './components/HeroLoop.vue';
import StillShot from './components/StillShot.vue';
import {watchMovedAnchors} from './movedAnchors.mjs';

// Reference-page render-layer enhancement: a method whose name heading is followed
// by more than one `.apex-member` card has overloads. We tag the heading with the
// count so CSS can show a muted "N overloads" badge — a visual cue only, kept out of
// the committed markdown (which stays clean). Runs client-side after each navigation.
function tagOverloadCounts()
{
	if(typeof document === 'undefined')
	{
		return;
	}
	const doc = document.querySelector('.reference .vp-doc');
	if(!doc)
	{
		return;
	}
	for(const h3 of doc.querySelectorAll('h3'))
	{
		let count = 0;
		let el = h3.nextElementSibling;
		while(el && el.classList && el.classList.contains('apex-member'))
		{
			count++;
			el = el.nextElementSibling;
		}
		if(count > 1)
		{
			h3.setAttribute('data-overloads', String(count));
		}
		else
		{
			h3.removeAttribute('data-overloads');
		}
	}
}

export default {
	extends: DefaultTheme,
	Layout()
	{
		return h(DefaultTheme.Layout, null, {
			// Top nav (not the sidebar) so the switcher shows on every page including the
			// sidebar-less landing — one consistent location.
			'nav-bar-content-after': () => h(VersionSwitcher),
			// Above the whole layout so the "older version" notice shows on every page of a
			// frozen tree (the banner self-gates: it renders nothing on the latest tree).
			'layout-top': () => h(VersionBanner),
			'doc-before': () => h(Breadcrumb),
			// A guide's "Reference for this page" group, below the sidebar menu. It reads the
			// guide's own frontmatter and renders nothing on any other page.
			'sidebar-nav-after': () => h(ReferenceForPage)
		});
	},
	enhanceApp({app, router, siteData})
	{
		// The latest tree's area menus arrive compact (config.mjs explains why). Here they are
		// expanded into the path-keyed sidebar VitePress reads. A frozen tree has no sidebarAreas,
		// and its flat sidebar is left as it is.
		//
		// Why the site data is replaced, not changed in place. `siteData` is VitePress's own
		// shallowRef of the site data (siteDataRef in vitepress/dist/client/app/data.js, passed in
		// by createApp in app/index.js). Two things in VitePress 1.6.4 rule out writing a sidebar
		// into the object it holds:
		// - On the dev server the object is wrapped with Vue's readonly(), so the write is dropped
		//   with a warning and the page shows no sidebar.
		// - The page data reads the site data through a computed (initData in data.js), which has
		//   already run once before this hook. A change inside the object is not seen by it.
		// Giving the ref a new object fixes both: a shallowRef tells everything that reads it when
		// its value is replaced. This hook runs before the first page is loaded and rendered, on
		// the server (app/ssr.js) and in the browser, so both render with the expanded sidebar.
		// When the dev server reloads the site data it replaces the ref's value with a compact one
		// again, so a watch in the browser expands that too.
		const expandSidebar = () =>
		{
			siteData.value = withExpandedSidebar(siteData.value);
		};
		expandSidebar();
		// Global components for the layout:page home tour (prepare.mjs emits <KernLanding />
		// from home.md; the examples slot holds <CodeCompare> blocks wrapping ```apex fences, and the
		// features slot holds them in <FeatureGroup> groups).
		app.component('KernLanding', KernLanding);
		app.component('CodeCompare', CodeCompare);
		app.component('FeatureGroup', FeatureGroup);
		app.component('HeroLoop', HeroLoop);
		app.component('StillShot', StillShot);
		// Mermaid, registered lazily. The markdown transform in config.mjs emits <Mermaid> for a
		// ```mermaid fence, and defineAsyncComponent means the chunk is only fetched by a page that
		// actually contains one — exactly one page in this corpus does. Upstream's plugin instead
		// splices a STATIC import into VitePress's client entry, which put 624 KB of diagram code
		// on all 326 pages.
		//
		// Component registrations are deliberately unconditional and above the browser-only block
		// below. They must run during SSR too, or the diagram page renders nothing server-side
		// while the render gate still passes on the client — a failure that is invisible until
		// someone views source. Keeping the browser-only work inside an `if` rather than behind an
		// early `return` is what stops that from depending on statement order.
		app.component('Mermaid', defineAsyncComponent(() => import('vitepress-plugin-mermaid/Mermaid.vue')));
		if(typeof window !== 'undefined')
		{
			watch(siteData, expandSidebar, {flush: 'sync'});
			const run = () => setTimeout(tagOverloadCounts, 0);
			// An old link to a heading that moved to another page goes on to its new place (movedAnchors.mjs).
			const followMovedAnchor = watchMovedAnchors(router);
			const orig = router.onAfterRouteChange;
			router.onAfterRouteChange = (to) =>
			{
				orig?.(to);
				run();
				followMovedAnchor();
			};
			run();
		}
	}
};
