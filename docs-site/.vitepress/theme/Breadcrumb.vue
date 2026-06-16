<!-- SPDX-License-Identifier: BUSL-1.1 -->
<script setup>
import {computed} from 'vue';
import {useData, withBase} from 'vitepress';

// A breadcrumb for reference pages only (pageClass: reference), derived from the
// page's relativePath: reference/<area>/<file> → Reference / <Area> / <Title>.
// Rendered above the H1 via the default theme's doc-before slot; it gives the deep
// auto-generated reference pages an "up" path and a clear sense of place.
const {page, frontmatter} = useData();

const AREA_LABEL = {apex: 'Apex', objects: 'Custom Objects', events: 'Platform Events', metadata: 'Custom Metadata Types'};

const crumbs = computed(() =>
{
	if(frontmatter.value.pageClass !== 'reference')
	{
		return [];
	}
	const parts = page.value.relativePath.replace(/\.md$/, '').split('/');
	const out = [{text: 'Reference', link: '/reference/'}];
	if(parts.length >= 3)
	{
		out.push({text: AREA_LABEL[parts[1]] || parts[1], link: null});
	}
	out.push({text: frontmatter.value.title || page.value.title, link: null});
	return out;
});
</script>

<template>
	<nav v-if="crumbs.length" class="ref-breadcrumb" aria-label="Breadcrumb">
		<template v-for="(c, i) in crumbs" :key="i">
			<a v-if="c.link" class="ref-breadcrumb__link" :href="withBase(c.link)">{{ c.text }}</a>
			<span v-else class="ref-breadcrumb__current">{{ c.text }}</span>
			<span v-if="i < crumbs.length - 1" class="ref-breadcrumb__sep" aria-hidden="true">/</span>
		</template>
	</nav>
</template>
