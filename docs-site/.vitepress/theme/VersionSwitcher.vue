<!-- SPDX-License-Identifier: BUSL-1.1 -->
<script setup>
import {withBase} from 'vitepress';

// Documentation version selector. One entry today (Kern 1.1 → site root); future
// releases add options that point at their own /X.Y/ base path, and this becomes a
// real dropdown with no re-plumbing. Sits at the top of the sidebar (the layout the
// prototype validated).
const versions = [{label: 'Kern 1.1', value: '/', latest: true}];
const current = versions[0];

function onChange(e)
{
	const v = e.target.value;
	if(v)
	{
		location.href = withBase(v);
	}
}
</script>

<template>
	<div class="version-switcher">
		<span class="version-switcher__caption">Version</span>
		<span class="version-switcher__chip">
			<select
				class="version-switcher__select"
				:value="current.value"
				aria-label="Documentation version"
				@change="onChange"
			>
				<option v-for="v in versions" :key="v.value" :value="v.value">{{ v.label }}</option>
			</select>
			<span v-if="current.latest" class="version-switcher__badge">LATEST</span>
		</span>
	</div>
</template>
