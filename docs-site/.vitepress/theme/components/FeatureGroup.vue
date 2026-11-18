<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- One group of examples on the front page ("Read and save data", "Automate", ...): a <details>
     the reader opens and closes, with the group name, a short list of what is inside, and a link back
     to the list of all features. The examples (<CodeCompare> blocks) come in through the default
     slot from home.md. The first group is written with `open`, so it starts open; the others start
     closed. The front page's script opens a closed group when a link or an old guide address points
     at an example inside it (see KernLanding.vue and movedAnchors.mjs). -->
<template>
	<details :id="id || undefined" class="kl-group" :open="open || undefined">
		<summary class="vp-raw">
			<span class="kl-group-t">{{ title }}</span>
			<span class="kl-group-s">{{ summary }}</span>
		</summary>
		<div class="kl-group-body">
			<!-- Outside the summary: a link inside a summary is a control inside a control, which screen
			     readers cannot reach on its own (axe nested-interactive). -->
			<p class="kl-group-back vp-raw"><a class="kl-back" href="#jump-to-a-feature">Back to all features ↑</a></p>
			<slot />
		</div>
	</details>
</template>

<script setup>
defineProps({
	// The group's id, such as group-automate.
	id: {type: String, default: ''},
	// The group name, such as "Automate".
	title: {type: String, default: ''},
	// What the group holds, such as "6 examples: triggers, validation rules, ...".
	summary: {type: String, default: ''},
	// Whether the group starts open.
	open: {type: Boolean, default: false}
});
</script>

<style scoped>
.kl-group{ border-top: 1px solid var(--vp-c-divider); padding: 4px 0; }
.kl-group:last-of-type{ border-bottom: 1px solid var(--vp-c-divider); }
.kl-group > summary{ cursor: pointer; list-style: none; display: flex; flex-wrap: wrap; gap: 6px 14px; align-items: baseline; padding: 14px 0; user-select: none; }
.kl-group > summary::-webkit-details-marker{ display: none; }
.kl-group > summary::before{ content: "▸"; color: var(--vp-c-brand-1); width: 12px; }
.kl-group[open] > summary::before{ content: "▾"; }
.kl-group-t{ font-weight: 700; font-size: 1.15rem; color: var(--vp-c-text-1); }
.kl-group-s{ color: var(--vp-c-text-2); font-size: .9rem; }
.kl-group-back{ display: flex; justify-content: flex-end; margin: 0 0 6px; }
.kl-back{ font-size: .82rem; font-weight: 500; color: var(--vp-c-brand-1); text-decoration: none; }
.kl-back:hover{ text-decoration: underline; }
.kl-group-body{ padding: 6px 0 10px; }

@media (max-width: 820px){
	.kl-group > summary{ align-items: center; min-height: 44px; }
	.kl-back{ display: inline-flex; align-items: center; min-height: 44px; }
}
</style>
