<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup>
import {computed} from 'vue';
import {useData, withBase} from 'vitepress';

// "Reference for this page": the classes a guide uses most, so a reader reaches a class page in
// one click. Rendered below the sidebar menu through the default theme's sidebar-nav-after slot.
//
// The links come from the guide's own frontmatter (`referenceForPage`, written by
// scripts/prepare.mjs), never from the shared sidebar: site data is inlined into every page, so a
// list per guide there would be paid on all of them. Pages without the key, every frozen tree
// included, render nothing.
//
// Accessibility: a labelled list of plain links. There is nothing to open or close, so there is
// no button, and each row is exactly one control (the rule theme/overrides/VPSidebarItem.vue
// follows for the menu above it). Colours are theme variables, so light and dark both work.
const {frontmatter} = useData();

const links = computed(() =>
{
	const list = frontmatter.value.referenceForPage;
	return Array.isArray(list) ? list.filter(item => item && item.text && item.link) : [];
});
</script>

<template>
	<section v-if="links.length" class="reference-for-page" aria-labelledby="reference-for-page-title">
		<h2 id="reference-for-page-title" class="reference-for-page__title">Reference for this page</h2>
		<ul class="reference-for-page__list">
			<li v-for="item in links" :key="item.link">
				<a class="reference-for-page__link" :href="withBase(item.link)">{{ item.text }}</a>
			</li>
		</ul>
	</section>
</template>

<style scoped>
.reference-for-page {
	border-top: 1px solid var(--vp-c-divider);
	padding: 10px 0 24px;
}

.reference-for-page__title {
	margin: 0;
	padding: 4px 0;
	line-height: 24px;
	font-size: 14px;
	font-weight: 700;
	color: var(--vp-c-text-1);
}

.reference-for-page__list {
	margin: 0;
	padding: 0;
	list-style: none;
}

.reference-for-page__link {
	display: block;
	padding: 4px 0;
	line-height: 24px;
	font-size: 14px;
	font-weight: 500;
	color: var(--vp-c-text-2);
	overflow-wrap: anywhere;
	transition: color 0.25s;
}

.reference-for-page__link:hover {
	color: var(--vp-c-brand-1);
}

.reference-for-page__link:focus-visible {
	outline: 2px solid var(--vp-c-brand-1);
	outline-offset: 2px;
	border-radius: 4px;
}
</style>
