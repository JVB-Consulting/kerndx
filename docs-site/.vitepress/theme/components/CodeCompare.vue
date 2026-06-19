<!-- SPDX-License-Identifier: BUSL-1.1 -->
<!-- Before/after code comparison for the KernDX landing tour. The two code
     panes are filled from named slots so the snippets can be authored as real ```apex
     fences in home.md — VitePress then renders them through the site's own shiki Apex
     theme and adds the Copy button, exactly like every other code block on the site.
     The "why it's better" prose sits in a <details> accordion (collapsed on desktop to
     cut density, force-opened on mobile for readability). -->
<template>
	<div ref="root" class="kl-compare">
		<div class="kl-ctitle">
			<span>{{ title }}</span>
			<a v-if="link" class="kl-clink" :href="link">{{ linkText }}</a>
		</div>
		<div class="kl-panes">
			<div class="kl-pane before"><p class="kl-plabel">Plain Apex</p><div class="kl-slot vp-doc"><slot name="before" /></div></div>
			<div class="kl-pane after"><p class="kl-plabel">KernDX</p><div class="kl-slot vp-doc"><slot name="after" /></div></div>
		</div>
		<details class="kl-why">
			<summary>Why the right is better</summary>
			<div class="kl-why-body"><slot name="why" /></div>
		</details>
	</div>
</template>

<script setup>
import {ref, onMounted} from 'vue';

defineProps({
	title: {type: String, default: ''},
	link: {type: String, default: ''},
	linkText: {type: String, default: 'Fast Start →'}
});

// Progressive disclosure: collapsed on desktop, open on mobile (the "why" is short and
// readability beats density on a phone). We set the attribute once on mount.
const root = ref(null);
onMounted(() =>
{
	if(typeof window !== 'undefined' && window.matchMedia('(max-width: 760px)').matches)
	{
		root.value?.querySelector('details')?.setAttribute('open', '');
	}
});
</script>

<style scoped>
.kl-compare{ border: 1px solid var(--vp-c-divider); border-radius: 12px; overflow: hidden; margin: 0 0 22px; background: var(--vp-c-bg); }
.kl-ctitle{ display: flex; justify-content: space-between; align-items: center; gap: 14px; flex-wrap: wrap; padding: 12px 18px; font-weight: 700; background: var(--vp-c-bg-soft); border-bottom: 1px solid var(--vp-c-divider); }
.kl-clink{ font-size: .8rem; font-weight: 600; color: var(--vp-c-brand-1); white-space: nowrap; text-decoration: none; }
.kl-clink:hover{ text-decoration: underline; }
.kl-panes{ display: grid; grid-template-columns: 1fr 1fr; }
.kl-pane{ padding: 16px 18px; min-width: 0; }
.kl-pane.before{ border-right: 1px solid var(--vp-c-divider); }
.kl-plabel{ font-size: .68rem; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; margin: 0 0 10px; }
.kl-pane.before .kl-plabel{ color: var(--vp-c-red-1); }
.kl-pane.after .kl-plabel{ color: var(--vp-c-green-1); }

/* Each slot is wrapped in `vp-doc` (see the template) so the VitePress-rendered ```apex
   block inside it gets the site's NATIVE code-block treatment — the <pre> scrolls on
   overflow (instead of spilling over and overlapping the other pane) and the Copy button
   is positioned/sized/clickable. The landing is `layout: page`, which has no `.vp-doc`
   wrapper of its own, so VitePress's `.vp-doc [class*=language-]` code CSS is otherwise
   absent here — the copy button computed to 0×0 and the <pre> to overflow-x:visible. The
   rules below only trim the block to fit the narrow side-by-side columns and keep the copy
   affordance visible rather than hover-only (it's a landing page — copy should be obvious). */
.kl-slot :deep(div[class*="language-"]){ margin: 0; border-radius: 8px; }
.kl-slot :deep(div[class*="language-"] pre){ padding: 14px 16px; }
.kl-slot :deep(div[class*="language-"] code){ font-size: .82rem; line-height: 1.5; tab-size: 3; -moz-tab-size: 3; }
.kl-slot :deep(div[class*="language-"] > span.lang){ display: none; }
.kl-slot :deep(div[class*="language-"] > button.copy){ opacity: .55; }
.kl-slot :deep(div[class*="language-"]:hover > button.copy){ opacity: 1; }

.kl-why{ border-top: 1px solid var(--vp-c-divider); background: var(--vp-c-bg-alt); }
.kl-why > summary{ cursor: pointer; list-style: none; padding: 12px 18px; font-size: .85rem; font-weight: 600; color: var(--vp-c-brand-1); user-select: none; }
.kl-why > summary::-webkit-details-marker{ display: none; }
.kl-why > summary::after{ content: ' →'; }
.kl-why[open] > summary::after{ content: ' ↓'; }
.kl-why > summary:hover{ background: var(--vp-c-bg-soft); }
.kl-why-body{ padding: 0 18px 16px; font-size: .92rem; color: var(--vp-c-text-1); max-width: 860px; }
.kl-why-body :deep(p){ margin: 0; }
.kl-why-body :deep(b), .kl-why-body :deep(strong){ color: var(--vp-c-green-1); }
.kl-why-body :deep(code){ font-size: .85em; }

@media (max-width: 760px){
	.kl-panes{ grid-template-columns: 1fr; }
	.kl-pane.before{ border-right: 0; border-bottom: 1px solid var(--vp-c-divider); }
}
</style>
