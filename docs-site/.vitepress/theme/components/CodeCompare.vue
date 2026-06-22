<!-- SPDX-License-Identifier: BUSL-1.1 -->
<!-- Before/after code comparison for the KernDX landing tour. The two code panes are
     filled from named slots so the snippets are authored as real ```apex fences in
     home.md — VitePress renders them through the site's shiki Apex theme + Copy button.

     Layout (depth-ledger redesign): two equal-height, side-by-side code panes with a
     pain-vs-relief tint (Plain Apex = warm/red, KernDX = green), then a FULL-WIDTH
     "depth ledger" band beneath them. The band opens with a receipt-style total
     ("You wrote {wrote} · you got {caps} capabilities you didn't write") and groups the
     capabilities into categories (slotted via #ledger as .kl-cat blocks). Every
     capability is a raw <a class="kl-ledger-chip"> deep-link to the exact guide section —
     the proof mechanism. A grounded CTA row closes the card; the "why" stays in a
     <details>. All colours are --vp-c-* tokens, so the card themes light/dark. -->
<template>
	<div ref="root" class="kl-compare">
		<div class="kl-ctitle">
			<span>{{ title }}</span>
			<a v-if="link" class="kl-clink" :href="link">{{ linkText }}</a>
		</div>
		<div class="kl-panes">
			<div class="kl-pane before">
				<p class="kl-plabel">Plain Apex <span class="kl-tag">you maintain this</span></p>
				<div class="kl-slot vp-doc"><slot name="before" /></div>
			</div>
			<div class="kl-pane after">
				<p class="kl-plabel">KernDX <span v-if="wrote" class="kl-tag">{{ wrote }}</span></p>
				<div class="kl-slot vp-doc"><slot name="after" /></div>
			</div>
		</div>
		<div v-if="$slots.ledger" class="kl-ledger">
			<div class="kl-ledger-top">
				<div>
					<p class="kl-ledger-eyebrow">The depth ledger</p>
					<p class="kl-ledger-sub">What you also got — without typing it. Every line links to its guide section.</p>
				</div>
				<p class="kl-total">You wrote <span class="n">{{ wrote }}</span> <span class="sep">·</span> you got <span class="n">{{ caps }}</span> capabilities you didn't write</p>
			</div>
			<div class="kl-cats"><slot name="ledger" /></div>
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
	linkText: {type: String, default: 'Read the guide →'},
	// The receipt total: "You wrote {wrote} · you got {caps} capabilities you didn't write".
	// `wrote` is an authored per-panel string (e.g. "5 lines", "0 lines of Apex", "1-line
	// trigger") so the contrast stays honest for declarative panels too; `caps` is the count
	// of .kl-ledger-chip links in this card (asserted == actual by tmp/verify-ledger-counts.js).
	wrote: {type: String, default: ''},
	caps: {type: [Number, String], default: ''}
});

// Progressive disclosure: the "why" accordion is collapsed on desktop, open on mobile
// (it's short and readability beats density on a phone). Set once on mount.
const root = ref(null);
onMounted(() =>
{
	if(typeof window !== 'undefined' && window.matchMedia('(max-width: 760px)').matches)
	{
		root.value?.querySelector('details.kl-why')?.setAttribute('open', '');
	}
});
</script>

<style scoped>
.kl-compare{ border: 1px solid var(--vp-c-divider); border-radius: 14px; overflow: hidden; margin: 0 0 22px; background: var(--vp-c-bg); }
.kl-ctitle{ display: flex; justify-content: space-between; align-items: center; gap: 14px; flex-wrap: wrap; padding: 13px 20px; font-weight: 700; background: var(--vp-c-bg-soft); border-bottom: 1px solid var(--vp-c-divider); }
.kl-clink{ font-size: .8rem; font-weight: 600; color: var(--vp-c-brand-1); white-space: nowrap; text-decoration: none; }
.kl-clink:hover{ text-decoration: underline; }

/* ── Equal-height, side-by-side code panes with a pain-vs-relief tint ── */
.kl-panes{ display: grid; grid-template-columns: 1fr 1fr; }
.kl-pane{ padding: 16px 18px; min-width: 0; display: flex; flex-direction: column; }
.kl-pane.before{ border-right: 1px solid var(--vp-c-divider); }
.kl-plabel{ font-size: .68rem; font-weight: 800; letter-spacing: .05em; text-transform: uppercase; margin: 0 0 10px; display: flex; align-items: center; gap: 8px; }
.kl-pane.before .kl-plabel{ color: var(--vp-c-red-1); }
.kl-pane.after .kl-plabel{ color: var(--vp-c-green-1); }
.kl-tag{ font-size: .6rem; font-weight: 700; letter-spacing: 0; text-transform: none; padding: 2px 8px; border-radius: 999px; color: var(--vp-c-text-2); background: var(--vp-c-bg-soft); border: 1px solid var(--vp-c-divider); }
.kl-slot{ flex: 1; display: flex; flex-direction: column; }
.kl-slot :deep(div[class*="language-"]){ margin: 0; border-radius: 8px; flex: 1; }
.kl-slot :deep(div[class*="language-"] pre){ padding: 14px 16px; height: 100%; }
.kl-slot :deep(div[class*="language-"] code){ font-size: .82rem; line-height: 1.5; tab-size: 3; -moz-tab-size: 3; }
.kl-slot :deep(div[class*="language-"] > span.lang){ display: none; }
.kl-slot :deep(div[class*="language-"] > button.copy){ opacity: .55; }
.kl-slot :deep(div[class*="language-"]:hover > button.copy){ opacity: 1; }

/* ── The depth-ledger band: full-width, beneath both panes ── */
.kl-ledger{ padding: 20px 22px 18px; border-top: 2px solid var(--vp-c-brand-1); background: var(--vp-c-bg-alt); }
.kl-ledger-top{ display: flex; align-items: baseline; justify-content: space-between; gap: 18px; flex-wrap: wrap; padding-bottom: 14px; border-bottom: 1px dashed var(--vp-c-divider); margin-bottom: 18px; }
.kl-ledger-eyebrow{ font-size: .62rem; letter-spacing: .14em; text-transform: uppercase; color: var(--vp-c-brand-1); font-weight: 800; margin: 0 0 4px; }
.kl-ledger-sub{ font-size: .8rem; color: var(--vp-c-text-2); margin: 0; max-width: 460px; }
/* Signature: the receipt total, in the code mono so it reads as a tally. */
.kl-total{ font-family: var(--vp-font-family-mono); font-size: .92rem; font-weight: 600; color: var(--vp-c-text-1); margin: 0; white-space: nowrap; }
.kl-total .n{ color: var(--vp-c-brand-1); font-weight: 700; }
.kl-total .sep{ color: var(--vp-c-divider); margin: 0 8px; }

.kl-cats{ display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 10px 26px; }
/* .kl-cat blocks + headings are slotted from home.md; reach them with :deep. */
.kl-cats :deep(.kl-cat){ min-width: 0; break-inside: avoid; }
.kl-cats :deep(.kl-cat-h){ font-size: .64rem; letter-spacing: .07em; text-transform: uppercase; font-weight: 800; color: var(--vp-c-text-1); margin: 6px 0 7px; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.kl-cats :deep(.kl-cat-h[data-marquee])::after{ content: attr(data-marquee); font-size: .58rem; font-weight: 700; letter-spacing: 0; text-transform: none; color: var(--vp-c-brand-1); background: var(--vp-c-brand-soft); border-radius: 999px; padding: 1px 8px; }

/* Capability lines: raw <a class="kl-ledger-chip"> deep-links, rendered as ledger rows. */
.kl-cats :deep(.kl-ledger-chip){ display: flex; align-items: flex-start; gap: 8px; text-decoration: none; color: var(--vp-c-text-1); font-size: .78rem; line-height: 1.42; padding: 5px 0; border-bottom: 1px dotted transparent; transition: color .12s, border-color .12s; }
.kl-cats :deep(.kl-ledger-chip)::before{ content: "✓"; color: var(--vp-c-green-1); font-weight: 700; flex: 0 0 auto; }
.kl-cats :deep(.kl-ledger-chip)::after{ content: "→"; color: var(--vp-c-brand-1); font-weight: 700; opacity: .45; margin-left: auto; flex: 0 0 auto; padding-left: 8px; }
.kl-cats :deep(.kl-cat .kl-ledger-chip:first-of-type){ font-weight: 600; }
.kl-cats :deep(.kl-ledger-chip:hover){ color: var(--vp-c-brand-1); border-bottom-color: var(--vp-c-brand-soft); }
.kl-cats :deep(.kl-ledger-chip:hover)::after{ opacity: 1; }

/* ── "Why the right is better" ── */
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
	.kl-total{ white-space: normal; font-size: .84rem; }
	.kl-cats{ grid-template-columns: 1fr; gap: 4px; }
}
</style>
