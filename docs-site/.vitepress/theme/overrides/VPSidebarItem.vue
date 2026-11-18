<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
// OVERRIDE of VitePress 1.6.4's default-theme VPSidebarItem, aliased in .vitepress/config.mjs.
//
// Why: the stock component makes the group header focusable AND gives its caret role="button", so
// one interactive control sits inside another. axe reports it as `nested-interactive`, a WCAG 2.0
// Level A failure (4.1.2), on 102 nodes across essentially every page. Lighthouse's accessibility
// category does not contain that rule, so no PageSpeed run would ever have surfaced it.
//
// What it cost a keyboard user, measured on /selectors-guide before this override:
//   - 70 of 346 sidebar items had BOTH the header and its caret focusable
//   - 49 of those headers were focusable divs wrapping a link whose Enter handler returns early:
//     focus landed on them and nothing happened. Dead tab stops.
//   - the remaining 21 toggled only because the caret's event bubbled to its parent's handler
//   - Space did nothing on a role="button" header, which the ARIA button pattern requires
//
// The fix follows upstream's own suggestion in vuejs/vitepress#3517 ("either the header should not
// have a tabindex, or the header button should simply be an icon"): exactly one control per header.
// A header that has a link keeps the link for navigation and the caret for toggling, and is itself
// inert. A header with no link IS the button, and its caret becomes decorative. Space is handled
// alongside Enter.
//
// Upstream status at 2026-08-07: #3517 open since 2024-01-29 with no comments; #3804 proposes the
// structural fix (native <details>/<summary>). NOT fixed in 2.0.0-alpha.19 — the markup there is
// byte-identical. Delete this file and the alias when upstream lands a fix; the accessibility gate
// (scripts/site-audit.mjs) will tell you if that regresses.
//
// The second change from stock: a collapsed group does not render its children. Stock renders them
// all and hides them with CSS, so every page with a sidebar shipped and hydrated all 361 sidebar
// items, 290 of them inside the collapsed API Reference group. That was one 550 ms main-thread task
// on a slow phone (Lighthouse mobile, CPU x12) and failed Total Blocking Time; rendering only the 71
// visible items brought it to 200 ms. Opening a group renders its children then. The cost: closing
// a group forgets which of its subgroups were open. If this file is deleted for the upstream fix
// above, keep this behaviour: the sidebar ceiling in scripts/artifact-audit.mjs fails if it is lost.
//
// The third change: the group holding the current page is open in the server-rendered HTML too.
// Stock opens it only after mount (a watchPostEffect, which never runs on the server), and with
// collapsed groups rendering nothing that pushed every group below it down once the page started:
// Lighthouse measured the layout shift on /reference/apex/qry-builder at desktop width (CLS 0.014
// before the area menus, 0.100 after). The watchEffect below runs on the server and in the browser
// before the first render, after stock's own watchEffect, and reads only the page and the item, so
// the server HTML and the browser's first render agree and nothing moves.
import type { DefaultTheme } from 'vitepress/theme'
import { computed, watchEffect } from 'vue'
import { useData } from 'vitepress'
import { isActive } from 'vitepress/dist/client/shared.js'
import { useSidebarControl } from 'vitepress/dist/client/theme-default/composables/sidebar.js'
import VPLink from 'vitepress/dist/client/theme-default/components/VPLink.vue'

const props = defineProps<{
  item: DefaultTheme.SidebarItem
  depth: number
}>()

const {
  collapsed,
  collapsible,
  isLink,
  isActiveLink,
  hasActiveLink,
  hasChildren,
  toggle
} = useSidebarControl(computed(() => props.item))

const { page } = useData()

// Stock's isActiveLink is set only after mount, so the item's own link is checked here directly.
watchEffect(() => {
  if (hasActiveLink.value || isActive(page.value.relativePath, props.item.link)) {
    collapsed.value = false
  }
})

const sectionTag = computed(() => (hasChildren.value ? 'section' : `div`))

const linkTag = computed(() => (isLink.value ? 'a' : 'div'))

const textTag = computed(() => {
  return !hasChildren.value
    ? 'p'
    : props.depth + 2 === 7
      ? 'p'
      : `h${props.depth + 2}`
})

const itemRole = computed(() => (isLink.value ? undefined : 'button'))

const classes = computed(() => [
  [`level-${props.depth}`],
  { collapsible: collapsible.value },
  { collapsed: collapsed.value },
  { 'is-link': isLink.value },
  { 'is-active': isActiveLink.value },
  { 'has-active': hasActiveLink.value }
])

function onItemInteraction(e: MouseEvent | Event) {
  if ('key' in e) {
    const key = (e as KeyboardEvent).key
    // Stock handles Enter only. A role="button" must also respond to Space (ARIA button pattern),
    // and Space would otherwise scroll the page, so consume it when we act on it.
    if (key !== 'Enter' && key !== ' ') {
      return
    }
    if (key === ' ') {
      e.preventDefault()
    }
  }
  !props.item.link && toggle()
}

function onCaretClick() {
  props.item.link && toggle()
}
</script>

<template>
  <component :is="sectionTag" class="VPSidebarItem" :class="classes">
    <div
      v-if="item.text"
      class="item"
      :role="itemRole"
      v-on="
        !item.link && item.items
          ? { click: onItemInteraction, keydown: onItemInteraction }
          : {}
      "
      :tabindex="!item.link && item.items ? 0 : undefined"
    >
      <div class="indicator" />

      <VPLink
        v-if="item.link"
        :tag="linkTag"
        class="link"
        :href="item.link"
        :rel="item.rel"
        :target="item.target"
      >
        <component :is="textTag" class="text" v-html="item.text" />
      </VPLink>
      <component v-else :is="textTag" class="text" v-html="item.text" />

      <div
        v-if="item.collapsed != null && item.items && item.items.length"
        class="caret"
        :role="item.link ? 'button' : undefined"
        :aria-label="item.link ? 'toggle section' : undefined"
        :aria-hidden="item.link ? undefined : 'true'"
        :tabindex="item.link ? 0 : undefined"
        @click="onCaretClick"
        @keydown.enter="onCaretClick"
        @keydown.space.prevent="onCaretClick"
      >
        <span class="vpi-chevron-right caret-icon" />
      </div>
    </div>

    <div v-if="item.items && item.items.length && !collapsed" class="items">
      <template v-if="depth < 5">
        <VPSidebarItem
          v-for="i in item.items"
          :key="i.text"
          :item="i"
          :depth="depth + 1"
        />
      </template>
    </div>
  </component>
</template>

<style scoped>
.VPSidebarItem.level-0 {
  padding-bottom: 24px;
}

.VPSidebarItem.collapsed.level-0 {
  padding-bottom: 10px;
}

.item {
  position: relative;
  display: flex;
  width: 100%;
}

.VPSidebarItem.collapsible > .item {
  cursor: pointer;
}

.indicator {
  position: absolute;
  top: 6px;
  bottom: 6px;
  left: -17px;
  width: 2px;
  border-radius: 2px;
  transition: background-color 0.25s;
}

.VPSidebarItem.level-2.is-active > .item > .indicator,
.VPSidebarItem.level-3.is-active > .item > .indicator,
.VPSidebarItem.level-4.is-active > .item > .indicator,
.VPSidebarItem.level-5.is-active > .item > .indicator {
  background-color: var(--vp-c-brand-1);
}

.link {
  display: flex;
  align-items: center;
  flex-grow: 1;
}

.text {
  flex-grow: 1;
  padding: 4px 0;
  line-height: 24px;
  font-size: 14px;
  transition: color 0.25s;
}

.VPSidebarItem.level-0 .text {
  font-weight: 700;
  color: var(--vp-c-text-1);
}

.VPSidebarItem.level-1 .text,
.VPSidebarItem.level-2 .text,
.VPSidebarItem.level-3 .text,
.VPSidebarItem.level-4 .text,
.VPSidebarItem.level-5 .text {
  font-weight: 500;
  color: var(--vp-c-text-2);
}

.VPSidebarItem.level-0.is-link > .item > .link:hover .text,
.VPSidebarItem.level-1.is-link > .item > .link:hover .text,
.VPSidebarItem.level-2.is-link > .item > .link:hover .text,
.VPSidebarItem.level-3.is-link > .item > .link:hover .text,
.VPSidebarItem.level-4.is-link > .item > .link:hover .text,
.VPSidebarItem.level-5.is-link > .item > .link:hover .text {
  color: var(--vp-c-brand-1);
}

.VPSidebarItem.level-0.has-active > .item > .text,
.VPSidebarItem.level-1.has-active > .item > .text,
.VPSidebarItem.level-2.has-active > .item > .text,
.VPSidebarItem.level-3.has-active > .item > .text,
.VPSidebarItem.level-4.has-active > .item > .text,
.VPSidebarItem.level-5.has-active > .item > .text,
.VPSidebarItem.level-0.has-active > .item > .link > .text,
.VPSidebarItem.level-1.has-active > .item > .link > .text,
.VPSidebarItem.level-2.has-active > .item > .link > .text,
.VPSidebarItem.level-3.has-active > .item > .link > .text,
.VPSidebarItem.level-4.has-active > .item > .link > .text,
.VPSidebarItem.level-5.has-active > .item > .link > .text {
  color: var(--vp-c-text-1);
}

.VPSidebarItem.level-0.is-active > .item .link > .text,
.VPSidebarItem.level-1.is-active > .item .link > .text,
.VPSidebarItem.level-2.is-active > .item .link > .text,
.VPSidebarItem.level-3.is-active > .item .link > .text,
.VPSidebarItem.level-4.is-active > .item .link > .text,
.VPSidebarItem.level-5.is-active > .item .link > .text {
  color: var(--vp-c-brand-1);
}

.caret {
  display: flex;
  justify-content: center;
  align-items: center;
  margin-right: -7px;
  width: 32px;
  height: 32px;
  color: var(--vp-c-text-3);
  cursor: pointer;
  transition: color 0.25s;
  flex-shrink: 0;
}

.item:hover .caret {
  color: var(--vp-c-text-2);
}

.item:hover .caret:hover {
  color: var(--vp-c-text-1);
}

.caret-icon {
  font-size: 18px;
  /*rtl:ignore*/
  transform: rotate(90deg);
  transition: transform 0.25s;
}

.VPSidebarItem.collapsed .caret-icon {
  transform: rotate(0)/*rtl:rotate(180deg)*/;
}

.VPSidebarItem.level-1 .items,
.VPSidebarItem.level-2 .items,
.VPSidebarItem.level-3 .items,
.VPSidebarItem.level-4 .items,
.VPSidebarItem.level-5 .items {
  border-left: 1px solid var(--vp-c-divider);
  padding-left: 16px;
}
</style>
