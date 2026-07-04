<!-- SPDX-License-Identifier: BUSL-1.1 -->
<script setup>
import {ref, computed, nextTick, onMounted, onBeforeUnmount} from 'vue';
import versions from '../versions.generated.mjs';
import {logicalPath, currentVersion, resolveTargetUrl, toRouteSet} from '../../scripts/version-routing.mjs';

// Documentation version selector. The list is generated at build time
// (prepare.mjs → versions.generated.mjs): the latest line at "/" plus any frozen /X.Y/
// trees. Lives in the top nav (nav-bar-content-after) so it is visible on every page
// including the sidebar-less landing.
const base = import.meta.env.BASE_URL;          // '/' for latest, '/1.2/' for a frozen tree
const current = currentVersion(versions, base);
const hasChoices = computed(() => versions.length > 1);

const open = ref(false);
const root = ref(null);
const optionEls = ref([]);

function close()
{
	open.value = false;
}

async function openMenu()
{
	open.value = true;
	await nextTick();
	const selected = versions.findIndex(v => v.base === current.base);
	focusOption(selected >= 0 ? selected : 0);
}

function toggle()
{
	open.value ? close() : openMenu();
}

function focusOption(index)
{
	const el = optionEls.value[index];
	if(el)
	{
		el.focus();
	}
}

function moveFocus(from, delta)
{
	const next = (from + delta + versions.length) % versions.length;
	focusOption(next);
}

// The switcher's only side effect: navigate. Preserve the current page in the target tree
// when it exists there; otherwise land on that tree's home. The target's route list is
// fetched once and cached (resolved purely in version-routing.mjs).
const routeCache = new Map();
function loadRouteSet(targetBase)
{
	if(!routeCache.has(targetBase))
	{
		routeCache.set(targetBase, fetch(`${targetBase}routes.json`)
		.then(r => (r.ok ? r.json() : null))
		.then(toRouteSet)
		.catch(() => null));
	}
	return routeCache.get(targetBase);
}

async function select(version)
{
	close();
	if(version.base === current.base)
	{
		return;
	}
	const logical = logicalPath(window.location.pathname, current.base);
	if(logical === '')
	{
		window.location.href = version.base;
		return;
	}
	const routeSet = await loadRouteSet(version.base);
	window.location.href = resolveTargetUrl(version, logical, routeSet);
}

function onDocumentClick(event)
{
	if(open.value && root.value && !root.value.contains(event.target))
	{
		close();
	}
}

onMounted(() => document.addEventListener('click', onDocumentClick));
onBeforeUnmount(() => document.removeEventListener('click', onDocumentClick));
</script>

<template>
	<div ref="root" class="version-switcher" :class="{'version-switcher--open': open}">
		<!-- One version (Phase 1): a static, non-interactive chip — nothing to switch to. -->
		<span v-if="!hasChoices" class="version-switcher__static">
			<span class="version-switcher__label">{{ current.label }}</span>
			<span v-if="current.latest" class="version-switcher__badge">LATEST</span>
		</span>

		<template v-else>
			<button
				type="button"
				class="version-switcher__trigger"
				aria-haspopup="listbox"
				:aria-expanded="open ? 'true' : 'false'"
				aria-label="Select documentation version"
				@click.stop="toggle"
				@keydown.down.prevent="openMenu"
				@keydown.esc="close"
			>
				<span class="version-switcher__label">{{ current.label }}</span>
				<span v-if="current.latest" class="version-switcher__badge">LATEST</span>
				<span class="version-switcher__chevron" aria-hidden="true"></span>
			</button>
			<ul
				v-show="open"
				class="version-switcher__menu"
				role="listbox"
				aria-label="Documentation version"
			>
				<li
					v-for="(v, i) in versions"
					:key="v.base"
					ref="optionEls"
					class="version-switcher__option"
					:class="{'is-selected': v.base === current.base}"
					role="option"
					:aria-selected="v.base === current.base ? 'true' : 'false'"
					tabindex="0"
					@click="select(v)"
					@keydown.enter.prevent="select(v)"
					@keydown.space.prevent="select(v)"
					@keydown.down.prevent="moveFocus(i, 1)"
					@keydown.up.prevent="moveFocus(i, -1)"
					@keydown.esc="close"
				>
					<span class="version-switcher__option-label">
						Kern {{ v.label }}
						<span v-if="v.latest" class="version-switcher__badge">LATEST</span>
					</span>
					<span class="version-switcher__check" aria-hidden="true">✓</span>
				</li>
			</ul>
		</template>
	</div>
</template>
