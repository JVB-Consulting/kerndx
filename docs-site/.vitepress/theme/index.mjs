// SPDX-License-Identifier: BUSL-1.1
import {h} from 'vue';
import DefaultTheme from 'vitepress/theme';
import './custom.css';
import VersionSwitcher from './VersionSwitcher.vue';
import Breadcrumb from './Breadcrumb.vue';
import KernLanding from './components/KernLanding.vue';
import CodeCompare from './components/CodeCompare.vue';
import HeroLoop from './components/HeroLoop.vue';

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
			'sidebar-nav-before': () => h(VersionSwitcher),
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
		if(typeof window === 'undefined')
		{
			return;
		}
		const run = () => setTimeout(tagOverloadCounts, 0);
		const orig = router.onAfterRouteChange;
		router.onAfterRouteChange = (to) =>
		{
			orig?.(to);
			run();
		};
		run();
	}
};
