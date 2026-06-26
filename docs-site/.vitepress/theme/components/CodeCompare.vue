<!-- SPDX-License-Identifier: BUSL-1.1 -->
<!-- Before/after code comparison for the KernDX landing tour. The two code panes are
     filled from named slots so the snippets are authored as real ```apex fences in
     home.md — VitePress renders them through the site's shiki Apex theme + Copy button.

     Layout (depth-ledger redesign, refined): two equal-height, side-by-side code panes
     labelled "Plain Apex / Manual" vs "KernDX / Included" (restrained pills, no pane
     fills). Beneath them a FULL-WIDTH "depth ledger" band whose gold-tinted head pairs the
     eyebrow with a HERO METRIC badge ("{wrote} → {caps} capabilities you didn't write").
     Then the capabilities, grouped into categories (slotted via #ledger as .kl-cat blocks,
     each .kl-cat-h carrying a data-cat so the component prefixes a category icon). Every
     capability is a raw <a class="kl-ledger-chip"> deep-link rendered as a bold title +
     one scannable description line; exactly one per card carries .hero (★, highlighted).
     A renamed "What's actually happening" <details> stays collapsed (desktop AND mobile).
     All colours are --vp-c-* tokens, so the card themes light/dark. -->
<template>
	<div class="kl-compare">
		<div class="kl-ctitle">
			<span>{{ title }}</span>
			<a v-if="link" class="kl-clink" :href="link">{{ linkText }}</a>
		</div>
		<div class="kl-panes">
			<div class="kl-pane before">
				<p class="kl-plabel">Plain Apex <span class="kl-pill manual">Manual</span></p>
				<div class="kl-slot vp-doc"><slot name="before" /></div>
			</div>
			<div class="kl-pane after">
				<p class="kl-plabel">KernDX <span class="kl-pill incl">Included</span></p>
				<div class="kl-slot vp-doc"><slot name="after" /></div>
			</div>
		</div>
		<div v-if="$slots.ledger" class="kl-ledger">
			<div class="kl-ledger-head">
				<p class="kl-ledger-eyebrow">What you also get</p>
				<p class="kl-metric">
					<template v-if="writeLead">
						<span class="n">{{ writeLead.num }}</span><span class="u">{{ writeLead.unit }}</span>
					</template>
					<span v-else class="phrase">{{ wrote }}</span>
					<span class="to">→</span>
					<span class="n">{{ caps }}</span><span class="u">capabilities you didn't write</span>
				</p>
			</div>
			<div class="kl-cats"><slot name="ledger" /></div>
		</div>
		<details v-if="$slots.why" class="kl-why">
			<summary>What's actually happening</summary>
			<div class="kl-why-body"><slot name="why" /></div>
		</details>
	</div>
</template>

<script setup>
import {computed} from 'vue';

const props = defineProps({
	title: {type: String, default: ''},
	link: {type: String, default: ''},
	linkText: {type: String, default: 'Read the guide →'},
	// The hero metric: "{wrote} → {caps} capabilities you didn't write".
	// `wrote` is an authored per-panel string. When it is a clean "<number> <word>"
	// (e.g. "5 lines") the number is enlarged and the word shown small; when it is a
	// phrase ("1 handler + a checkbox", "a 1-line trigger") it renders at normal weight,
	// so the contrast stays honest for declarative panels too. `caps` is the count of
	// .kl-ledger-chip links in this card (asserted == actual by the ledger-count check).
	wrote: {type: String, default: ''},
	caps: {type: [Number, String], default: ''}
});

// Enlarge the leading number only for a simple "<n> <word>" (e.g. "5 lines"); a phrase
// (anything with punctuation or a non-numeric lead) renders whole, at normal weight.
const writeLead = computed(() =>
{
	const match = /^(\d+)\s+([A-Za-z]+)$/.exec(String(props.wrote).trim());
	return match ? {num: match[1], unit: match[2]} : null;
});
</script>

<style scoped>
.kl-compare{ border: 1px solid var(--vp-c-divider); border-radius: 14px; overflow: hidden; margin: 0 0 22px; background: var(--vp-c-bg); }
.kl-ctitle{ display: flex; justify-content: space-between; align-items: center; gap: 14px; flex-wrap: wrap; padding: 13px 20px; font-weight: 700; background: var(--vp-c-bg-soft); border-bottom: 1px solid var(--vp-c-divider); }
.kl-clink{ font-size: .8rem; font-weight: 600; color: var(--vp-c-brand-1); white-space: nowrap; text-decoration: none; }
.kl-clink:hover{ text-decoration: underline; }

/* ── Equal-height, side-by-side code panes (restrained labels, no pane fills) ── */
.kl-panes{ display: grid; grid-template-columns: 1fr 1fr; }
.kl-pane{ padding: 16px 18px; min-width: 0; display: flex; flex-direction: column; }
.kl-pane.before{ border-right: 1px solid var(--vp-c-divider); }
.kl-plabel{ font-size: .68rem; font-weight: 800; letter-spacing: .05em; text-transform: uppercase; margin: 0 0 10px; display: flex; align-items: center; gap: 8px; }
.kl-pane.before .kl-plabel{ color: var(--vp-c-red-1); }
.kl-pane.after .kl-plabel{ color: var(--vp-c-green-1); }
/* Restrained Manual / Included pills — contrast without aggressive red/green fills. */
.kl-pill{ font-size: .58rem; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; padding: 2px 8px; border-radius: 5px; border: 1px solid var(--vp-c-divider); }
.kl-pill.manual{ color: var(--vp-c-red-1); background: transparent; }
.kl-pill.incl{ color: var(--vp-c-green-1); background: var(--vp-c-brand-soft); border-color: transparent; }
/* Light mode only: the green on the bronze-soft pill fill is a hair under WCAG AA; deepen it
   slightly (dark already clears it). */
html:not(.dark) .kl-pill.incl{ color: #15704a; }
.kl-slot{ flex: 1; display: flex; flex-direction: column; }
.kl-slot :deep(div[class*="language-"]){ margin: 0; border-radius: 8px; flex: 1; }
.kl-slot :deep(div[class*="language-"] pre){ padding: 14px 16px; height: 100%; }
/* Wrap long lines instead of scrolling sideways (devs dislike horizontal scroll on a
   landing). The full-width landing keeps panes wide enough that few lines wrap. */
.kl-slot :deep(div[class*="language-"] code){ font-size: .78rem; line-height: 1.5; tab-size: 3; -moz-tab-size: 3; white-space: pre-wrap; overflow-wrap: break-word; }
.kl-slot :deep(div[class*="language-"] > span.lang){ display: none; }
.kl-slot :deep(div[class*="language-"] > button.copy){ opacity: .55; }
.kl-slot :deep(div[class*="language-"]:hover > button.copy){ opacity: 1; }

/* ── The depth-ledger band: full-width, beneath both panes ── */
.kl-ledger{ border-top: 2px solid var(--vp-c-brand-1); background: var(--vp-c-bg-alt); }
/* Gold-tinted "value unlocked" head: eyebrow + hero metric badge on one row. */
.kl-ledger-head{ display: flex; align-items: center; gap: 18px; flex-wrap: wrap; padding: 13px 22px; border-bottom: 1px solid var(--vp-c-divider); background: linear-gradient(180deg, var(--vp-c-brand-soft), transparent 75%); }
.kl-ledger-eyebrow{ font-size: .62rem; letter-spacing: .16em; text-transform: uppercase; color: var(--vp-c-brand-1); font-weight: 800; margin: 0; white-space: nowrap; }
/* Hero metric — compact bordered badge (the band's visual anchor). */
.kl-metric{ display: inline-flex; align-items: baseline; gap: 8px; margin: 0 0 0 auto; border: 1px solid var(--vp-c-brand-1); border-radius: 10px; padding: 6px 14px; background: var(--vp-c-brand-soft); font-family: var(--vp-font-family-mono); }
.kl-metric .n{ font-weight: 800; font-size: 1.7rem; line-height: 1; color: var(--vp-c-brand-1); }
.kl-metric .u{ font-size: .74rem; color: var(--vp-c-text-2); font-weight: 600; }
.kl-metric .phrase{ font-size: .95rem; color: var(--vp-c-text-1); font-weight: 700; }
.kl-metric .to{ font-size: 1.1rem; color: var(--vp-c-text-3); font-weight: 700; margin: 0 2px; }

.kl-cats{ display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 4px 26px; padding: 10px 22px 16px; }
/* .kl-cat blocks + headings are slotted from home.md; reach them with :deep. */
.kl-cats :deep(.kl-cat){ min-width: 0; break-inside: avoid; }
.kl-cats :deep(.kl-cat-h){ font-size: .64rem; letter-spacing: .07em; text-transform: uppercase; font-weight: 800; color: var(--vp-c-text-1); margin: 12px 0 5px; display: flex; align-items: center; gap: 7px; }
/* Category icon, prefixed from a data-cat token authored on the heading in home.md. */
.kl-cats :deep(.kl-cat-h)::before{ font-size: .9rem; line-height: 1; }
.kl-cats :deep(.kl-cat-h[data-cat="reliability"])::before{ content: "🛡️"; }
.kl-cats :deep(.kl-cat-h[data-cat="governance"])::before{ content: "⚖️"; }
.kl-cats :deep(.kl-cat-h[data-cat="observability"])::before{ content: "👁️"; }
.kl-cats :deep(.kl-cat-h[data-cat="performance"])::before{ content: "⚡"; }
.kl-cats :deep(.kl-cat-h[data-cat="testing"])::before{ content: "🧪"; }

/* Capability lines: raw <a class="kl-ledger-chip"> with a bold title + one description line.
   Grid so the ✓/★ marker sits left (spanning both rows), title stacks over description, and
   the → sits right — without needing a wrapper element around the two text spans in home.md. */
.kl-cats :deep(.kl-ledger-chip){ display: grid; grid-template-columns: auto 1fr auto; column-gap: 9px; text-decoration: none; color: var(--vp-c-text-1); padding: 6px 0; border-bottom: 1px dotted transparent; transition: color .12s, border-color .12s; }
.kl-cats :deep(.kl-ledger-chip)::before{ content: "✓"; color: var(--vp-c-green-1); font-weight: 700; grid-column: 1; grid-row: 1 / span 2; line-height: 1.35; }
.kl-cats :deep(.kl-ledger-chip)::after{ content: "→"; color: var(--vp-c-brand-1); font-weight: 700; opacity: .4; grid-column: 3; grid-row: 1 / span 2; align-self: center; padding-left: 8px; }
.kl-cats :deep(.kl-chip-t){ grid-column: 2; grid-row: 1; font-weight: 700; font-size: .8rem; color: var(--vp-c-text-1); line-height: 1.35; }
.kl-cats :deep(.kl-chip-d){ grid-column: 2; grid-row: 2; font-size: .75rem; color: var(--vp-c-text-2); line-height: 1.4; margin-top: 1px; }
.kl-cats :deep(.kl-ledger-chip:hover){ border-bottom-color: var(--vp-c-brand-soft); }
.kl-cats :deep(.kl-ledger-chip:hover)::after{ opacity: 1; }
/* The one hero capability per card: ★ marker + highlighted row. */
.kl-cats :deep(.kl-ledger-chip.hero){ background: var(--vp-c-brand-soft); border-radius: 9px; padding: 8px 11px; margin: 1px 0 5px; border-bottom: 0; }
.kl-cats :deep(.kl-ledger-chip.hero)::before{ content: "★"; color: var(--vp-c-brand-1); font-size: .95rem; }
.kl-cats :deep(.kl-ledger-chip.hero .kl-chip-t){ font-size: .85rem; }
/* The hero chip's bronze-soft fill drops its muted (text-2) description just under WCAG AA;
   use the primary text colour on the highlighted chip only. */
.kl-cats :deep(.kl-ledger-chip.hero .kl-chip-d){ color: var(--vp-c-text-1); }

/* ── "What's actually happening" — collapsed on desktop AND mobile ── */
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
	.kl-ledger-head{ gap: 10px; }
	.kl-metric{ margin-left: 0; }
	.kl-cats{ grid-template-columns: 1fr; gap: 4px; }
}
</style>
