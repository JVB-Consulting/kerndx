<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- A passive "you're on an older version" notice. It renders ONLY on a frozen (non-latest)
     version tree, so the reader of /1.1/ docs knows they're not on the current version and can
     jump to it. On the latest tree it renders nothing. Mounted in the layout-top slot so it
     shows on every page of a frozen tree, including the landing. Pairs with the VersionSwitcher
     (top nav) and reinforces the SEO intent (frozen pages are noindex + canonicalise to latest). -->
<script setup>
import {computed, ref, watch, onMounted, onBeforeUnmount} from 'vue';
import {useRoute} from 'vitepress';
import versions from '../versions.generated.mjs';
import {logicalPath, currentVersion, resolveTargetUrl, toRouteSet} from '../../scripts/version-routing.mjs';

// '/' on the latest build, '/X.Y/' on a frozen tree — the same signal the switcher uses.
const base = import.meta.env.BASE_URL;
const current = currentVersion(versions, base);
const latest = versions.find((v) => v.latest);
const show = computed(() => Boolean(current) && Boolean(latest) && !current.latest);

// The link opens the page the reader is on in the latest tree, or the latest home when that page
// is gone there. `target="_self"` makes it a full page load: the router of this frozen app would
// otherwise resolve the latest tree's URL inside its own base and render its 404.
const href = ref(latest?.base ?? '/');
const route = useRoute();
let latestRoutes = null;
async function pointAtLatestPage()
{
	latestRoutes ??= fetch(`${latest.base}routes.json`)
	.then(r => (r.ok ? r.json() : null))
	.then(toRouteSet)
	.catch(() => null);
	const logical = logicalPath(window.location.pathname, current.base);
	href.value = resolveTargetUrl(latest, logical, await latestRoutes);
}

// From 960px the theme's nav is fixed, and it and the content sit below a layout-top block only
// when the block's height is published as --vp-layout-top-height; without it the nav covers the
// banner. The banner is pinned there too and its height measured (the text can wrap). Below 960px
// the nav scrolls with the page, so the banner stays in the page flow and publishes nothing.
const root = ref(null);
let resizeObserver = null;
let desktop = null;
function publishHeight()
{
	if(desktop.matches)
	{
		document.documentElement.style.setProperty('--vp-layout-top-height', `${root.value.offsetHeight}px`);
	}
	else
	{
		document.documentElement.style.removeProperty('--vp-layout-top-height');
	}
}

onMounted(() =>
{
	if(!show.value)
	{
		return;
	}
	desktop = window.matchMedia('(min-width: 960px)');
	desktop.addEventListener('change', publishHeight);
	publishHeight();
	resizeObserver = new ResizeObserver(publishHeight);
	resizeObserver.observe(root.value);
	pointAtLatestPage();
	watch(() => route.path, pointAtLatestPage);
});

onBeforeUnmount(() =>
{
	resizeObserver?.disconnect();
	desktop?.removeEventListener('change', publishHeight);
	document.documentElement.style.removeProperty('--vp-layout-top-height');
});
</script>

<template>
	<div v-if="show" ref="root" class="version-banner" role="note">
		<span class="version-banner__text">
			You're reading the KernDX <strong>{{ current.label }}</strong> documentation, which isn't the latest version.
		</span>
		<a class="version-banner__cta" :href="href" target="_self">Go to the latest docs →</a>
	</div>
</template>

<style scoped>
.version-banner{
	display: flex;
	flex-wrap: wrap;
	align-items: center;
	justify-content: center;
	gap: 6px 14px;
	padding: 8px 16px;
	font-size: .85rem;
	text-align: center;
	color: var(--vp-c-text-1);
	/* The soft tint is translucent; the page background under it keeps scrolled text from showing through. */
	background: linear-gradient(var(--vp-c-warning-soft), var(--vp-c-warning-soft)), var(--vp-c-bg);
	border-bottom: 1px solid var(--vp-c-divider);
}
@media (min-width: 960px){
	.version-banner{
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: var(--vp-z-index-layout-top);
	}
}
.version-banner__text{ color: var(--vp-c-text-2); }
.version-banner__text strong{ color: var(--vp-c-text-1); }
.version-banner__cta{
	font-weight: 600;
	color: var(--vp-c-brand-1);
	text-decoration: none;
	white-space: nowrap;
}
.version-banner__cta:hover{ text-decoration: underline; }
</style>
