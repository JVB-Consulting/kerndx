<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
// OVERRIDE of VitePress 1.6.4's default-theme VPDocOutlineItem, aliased in .vitepress/config.mjs.
//
// Why: on the largest guides, "On this page" listed every main heading and every sub-heading. The
// eight largest guides have 72 to 104 entries there (measured on the latest tree when this file was
// written), so the list ran far below the screen and a reader could not see where the section they
// were reading sat in the page. On a page whose frontmatter has `outlineOpens: true`
// (scripts/prepare.mjs writes it on those eight guides), the list now shows the main headings and
// opens only the sub-headings of the section being read. One button above the list shows every
// heading, and shows main headings again. Every other page renders exactly as stock.
//
// Why this component and not VPDocAsideOutline: this is the list itself, and VPDocAsideOutline is
// the component that runs VitePress's own scroll tracking (useActiveAnchor). That tracking calls
// activateLink(location.hash) from its onUpdated hook, so state kept in VPDocAsideOutline would
// re-render it and move the active entry back to the URL's anchor. State kept here re-renders only
// this list. The mobile "On this page" menu also uses this component, without `root`, and is stock.
//
// The section being read comes from VitePress, not from a second scroll tracker: useActiveAnchor
// puts the class `active` on the link of the heading being read, and a MutationObserver here reads
// that class. That is why the sub-headings of a closed section stay in the page, hidden with
// v-show: VitePress can only mark a link it can find. When it marks a hidden one, its section opens.
//
// When the reader moves to another page, VitePress removes `active` from the old entry after the
// new list is drawn, even when that entry was just taken out of the list. The observer still sees
// that change: the browser keeps watching a removed node until it next reports changes to the
// observer, and VitePress's update runs before that report. So a main heading with the same link
// on both pages does not stay open by mistake (checked in scripts/render-smoke.test.mjs).
//
// Accessibility follows the rule in VPSidebarItem.vue: one control per header. A heading is only
// its link; the one extra control is the button, a real <button> with aria-expanded. Hidden
// sub-headings are display: none, so Tab skips them, and focus is drawn on links and the button.
// A section stays open while keyboard focus is inside it, even when scrolling makes another
// section the one being read, so focus is never lost to a hidden link.
//
// "Show all headings" stays on when the reader moves to another page in the same visit, on
// purpose: it is the reader's own choice, the button text and aria-expanded always show it, and
// reloading the page turns it off.
//
// This leans on VitePress 1.6.4 internals and must be re-checked at each upgrade: the `active`
// class and the `outline-link` class, the marker position useActiveAnchor sets (link offsetTop + 39)
// and the `.content` / `.outline-marker` markup of VPDocAsideOutline. The button sits above the
// list, so the marker is moved down by the button's 32 px in the unscoped style at the end of this
// file. Checked by "On this page" in scripts/render-smoke.test.mjs and by scripts/site-audit.mjs.
import { useData } from 'vitepress'
import { computed, nextTick, ref, watch } from 'vue'

interface OutlineHeader {
  title: string
  link: string
  children?: OutlineHeader[]
}

const props = defineProps<{
  headers: OutlineHeader[]
  root?: boolean
}>()

const { frontmatter } = useData()

// Main headings with the section being read opened: only for the aside's own list on a page that
// asks for it.
const opensBySection = computed(() => props.root === true && frontmatter.value.outlineOpens === true)

const showAll = ref(false)
const currentSection = ref<string | null>(null)
// The main heading whose section holds keyboard focus, so that section is not hidden under it.
const focusedSection = ref<string | null>(null)
const list = ref<HTMLElement>()

function onClick({ target: el }: Event) {
  const id = (el as HTMLAnchorElement).href!.split('#')[1]
  const heading = document.getElementById(decodeURIComponent(id))
  heading?.focus({ preventScroll: true })
}

function containsLink(header: OutlineHeader, link: string): boolean {
  return header.link === link || (header.children ?? []).some((child) => containsLink(child, link))
}

// The main heading whose section holds the link VitePress marked as being read.
function syncCurrentSection() {
  const href = list.value?.querySelector('a.outline-link.active')?.getAttribute('href') ?? null
  currentSection.value = href === null ? null : props.headers.find((header) => containsLink(header, href))?.link ?? null
}

// The main heading of the section that holds this element, or null for a main heading itself.
function sectionOf(element: EventTarget | null): string | null {
  const section = (element as HTMLElement | null)?.closest?.('.section-headings')
  return section?.parentElement?.querySelector(':scope > a.outline-link')?.getAttribute('href') ?? null
}

function onFocusIn({ target }: FocusEvent) {
  focusedSection.value = sectionOf(target)
}

function onFocusOut({ relatedTarget }: FocusEvent) {
  if (!list.value?.contains(relatedTarget as Node | null)) {
    focusedSection.value = null
  }
}

// Opening or closing a section moves the links below it, and VitePress only places its marker
// when the reader scrolls. Place it again with VitePress's own sum, so both agree.
function placeMarker() {
  const active = list.value?.querySelector<HTMLElement>('a.outline-link.active')
  const marker = list.value?.parentElement?.querySelector<HTMLElement>('.outline-marker')
  if (active && marker && active.offsetParent) {
    marker.style.top = active.offsetTop + 39 + 'px'
  }
}

function toggleShowAll() {
  showAll.value = !showAll.value
}

// Any change to which sections are open moves the links, so the marker is placed again.
watch([showAll, currentSection, focusedSection], () => nextTick(placeMarker))

// A new page brings a new list of headings. A focused link that is taken out of the list may not
// send focusout, so work out again which section holds focus once the new list is drawn.
watch(
  () => props.headers,
  () =>
    nextTick(() => {
      const focused = document.activeElement
      focusedSection.value = list.value?.contains(focused) ? sectionOf(focused) : null
    })
)

watch(list, (element, _previous, onCleanup) => {
  if (!element) {
    return
  }
  const observer = new MutationObserver(syncCurrentSection)
  observer.observe(element, { subtree: true, attributes: true, attributeFilter: ['class'] })
  syncCurrentSection()
  onCleanup(() => observer.disconnect())
})
</script>

<template>
  <template v-if="opensBySection">
    <button
      type="button"
      class="outline-toggle"
      aria-controls="kern-outline-list"
      :aria-expanded="showAll ? 'true' : 'false'"
      @click="toggleShowAll"
    >
      {{ showAll ? 'Show main headings' : 'Show all headings' }}
    </button>
    <ul id="kern-outline-list" ref="list" class="VPDocOutlineItem root" @focusin="onFocusIn" @focusout="onFocusOut">
      <li v-for="{ children, link, title } in headers" :key="link">
        <a class="outline-link" :href="link" @click="onClick" :title="title">{{ title }}</a>
        <div v-if="children?.length" v-show="showAll || link === currentSection || link === focusedSection" class="section-headings">
          <VPDocOutlineItem :headers="children" />
        </div>
      </li>
    </ul>
  </template>
  <ul v-else class="VPDocOutlineItem" :class="root ? 'root' : 'nested'">
    <li v-for="{ children, link, title } in headers" :key="link">
      <a class="outline-link" :href="link" @click="onClick" :title="title">{{ title }}</a>
      <template v-if="children?.length">
        <VPDocOutlineItem :headers="children" />
      </template>
    </li>
  </ul>
</template>

<style scoped>
.root {
  position: relative;
  z-index: 1;
}

.nested {
  padding-right: 16px;
  padding-left: 16px;
}

.outline-link {
  display: block;
  line-height: 32px;
  font-size: 14px;
  font-weight: 400;
  color: var(--vp-c-text-2);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  transition: color 0.5s;
}

.outline-link:hover,
.outline-link.active {
  color: var(--vp-c-text-1);
  transition: color 0.25s;
}

.outline-link.nested {
  padding-left: 13px;
}

/* One row tall (32 px with its margin), so the marker offset below stays a whole row. */
.outline-toggle {
  display: block;
  height: 28px;
  margin-bottom: 4px;
  padding: 0 8px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  line-height: 26px;
  color: var(--vp-c-text-1);
  background-color: var(--vp-c-bg-soft);
  cursor: pointer;
  transition: border-color 0.25s, color 0.25s;
}

.outline-toggle:hover {
  border-color: var(--vp-c-brand-1);
  color: var(--vp-c-brand-1);
}

.outline-link:focus-visible,
.outline-toggle:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: -2px;
  border-radius: 4px;
}
</style>

<style>
/* The button above the list moves every link down one row, but VitePress places the marker from
   each link's offset inside the list. Move the marker down by the same row. */
.VPDocAsideOutline .content:has(> .outline-toggle) > .outline-marker {
  margin-top: 32px;
}
</style>
