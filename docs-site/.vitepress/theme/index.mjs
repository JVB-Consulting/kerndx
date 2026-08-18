// SPDX-License-Identifier: BUSL-1.1
import {defineAsyncComponent, h} from 'vue';
import DefaultTheme from 'vitepress/theme';
import './custom.css';
import VersionSwitcher from './VersionSwitcher.vue';
import VersionBanner from './VersionBanner.vue';
import Breadcrumb from './Breadcrumb.vue';
import KernLanding from './components/KernLanding.vue';
import CodeCompare from './components/CodeCompare.vue';
import HeroLoop from './components/HeroLoop.vue';
import StillShot from './components/StillShot.vue';

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
			'doc-before': () => h(Breadcrumb)
		});
	},
	enhanceApp({app, router})
	{
		// Global components for the layout:page home tour (prepare.mjs emits <KernLanding />
		// from home.md; the examples slot holds <CodeCompare> blocks wrapping ```apex fences).
		app.component('KernLanding', KernLanding);
		app.component('CodeCompare', CodeCompare);
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
			const run = () => setTimeout(tagOverloadCounts, 0);
			const orig = router.onAfterRouteChange;
			router.onAfterRouteChange = (to) =>
			{
				orig?.(to);
				run();
			};
			run();
		}
	}
};
