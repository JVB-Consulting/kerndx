<!-- SPDX-License-Identifier: BUSL-1.1 -->
<!-- A passive "you're on an older version" notice. It renders ONLY on a frozen (non-latest)
     version tree, so the reader of /1.1/ docs knows they're not on the current version and can
     jump to it. On the latest tree it renders nothing. Mounted in the layout-top slot so it
     shows on every page of a frozen tree, including the landing. Pairs with the VersionSwitcher
     (top nav) and reinforces the SEO intent (frozen pages are noindex + canonicalise to latest). -->
<script setup>
import {computed} from 'vue';
import versions from '../versions.generated.mjs';
import {currentVersion} from '../../scripts/version-routing.mjs';

// '/' on the latest build, '/X.Y/' on a frozen tree — the same signal the switcher uses.
const base = import.meta.env.BASE_URL;
const current = currentVersion(versions, base);
const latest = versions.find((v) => v.latest);
const show = computed(() => Boolean(current) && Boolean(latest) && !current.latest);
</script>

<template>
	<div v-if="show" class="version-banner" role="note">
		<span class="version-banner__text">
			You're reading the KernDX <strong>{{ current.label }}</strong> documentation, which isn't the latest version.
		</span>
		<a class="version-banner__cta" :href="latest.base">Go to the latest docs →</a>
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
	background: var(--vp-c-warning-soft, var(--vp-c-yellow-soft));
	border-bottom: 1px solid var(--vp-c-divider);
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
