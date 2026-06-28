<!-- SPDX-License-Identifier: BUSL-1.1 -->
<!--
  A guide screenshot with a caption beneath it and a click-to-expand lightbox — the still-image
  counterpart of HeroLoop, so screenshots and walkthrough videos behave the same way. The inline
  image is width-capped so the page reads cleanly; clicking it (or the Expand affordance) opens a
  large copy over a dark backdrop so the tool UI is legible. Esc or a backdrop click closes it.

  Any markdown passed as slot content is intentionally NOT rendered on the docs site (the component
  draws the image itself). It exists only so the raw-GitHub markdown view — which ignores this custom
  tag — still shows a "View this screenshot" fallback link to the live image. Same degradation
  contract as HeroLoop's dual-link lines.
-->
<script setup>
import {ref, onMounted, onBeforeUnmount, nextTick} from 'vue';
import {withBase} from 'vitepress';

const props = defineProps({
	src: {type: String, default: ''},
	alt: {type: String, default: ''},
	caption: {type: String, default: ''}
});

const lightboxOpen = ref(false);
const lightboxCloseEl = ref(null);
let lastFocused = null;

function openLightbox()
{
	if(typeof document !== 'undefined')
	{
		lastFocused = document.activeElement;
		document.body.style.overflow = 'hidden';
	}
	lightboxOpen.value = true;
	nextTick(() =>
	{
		lightboxCloseEl.value && lightboxCloseEl.value.focus && lightboxCloseEl.value.focus();
	});
}

function closeLightbox()
{
	lightboxOpen.value = false;
	if(typeof document !== 'undefined')
	{
		document.body.style.overflow = '';
	}
	if(lastFocused && lastFocused.focus)
	{
		lastFocused.focus();
	}
	lastFocused = null;
}

function onKeydown(event)
{
	if(event.key === 'Escape' && lightboxOpen.value)
	{
		closeLightbox();
	}
}

onMounted(() =>
{
	if(typeof document !== 'undefined')
	{
		document.addEventListener('keydown', onKeydown);
	}
});

onBeforeUnmount(() =>
{
	if(typeof document !== 'undefined')
	{
		document.removeEventListener('keydown', onKeydown);
		document.body.style.overflow = '';
	}
});
</script>

<template>
	<figure class="still-shot">
		<div class="still-shot__frame">
			<img
				class="still-shot__img"
				:src="withBase(src)"
				:alt="alt || caption"
				loading="lazy"
				@click="openLightbox"
			/>
			<button type="button" class="still-shot__expand" aria-label="Expand to full screen" @click="openLightbox">
				<span aria-hidden="true">⤢</span> Expand
			</button>
		</div>
		<figcaption v-if="caption" class="still-shot__cap">{{ caption }}</figcaption>

		<Teleport to="body">
			<div v-if="lightboxOpen" class="still-lightbox" role="dialog" aria-modal="true" :aria-label="alt || caption || 'Screenshot'" @click.self="closeLightbox">
				<button ref="lightboxCloseEl" type="button" class="still-lightbox__close" aria-label="Close" @click="closeLightbox">✕</button>
				<img class="still-lightbox__img" :src="withBase(src)" :alt="alt || caption" />
				<p v-if="caption" class="still-lightbox__cap">{{ caption }}</p>
			</div>
		</Teleport>
	</figure>
</template>

<style scoped>
.still-shot{ margin: 1.6rem 0 2.2rem; }
.still-shot__frame{ position: relative; max-width: 960px; margin: 0 auto; }
.still-shot__img{
	display: block;
	width: 100%;
	height: auto;
	border: 1px solid var(--vp-c-divider);
	border-radius: 10px;
	background: var(--vp-c-bg-soft);
	cursor: zoom-in;
	box-shadow: 0 1px 3px rgba(0, 0, 0, .06);
}
/* Discoverable "expand" affordance, matching HeroLoop. */
.still-shot__expand{
	position: absolute;
	top: 10px;
	right: 10px;
	display: inline-flex;
	align-items: center;
	gap: 5px;
	font-size: .76rem;
	font-weight: 600;
	color: #fff;
	background: rgba(20, 20, 20, .62);
	border: 0;
	border-radius: 7px;
	padding: 5px 10px;
	cursor: zoom-in;
	opacity: 0;
	transition: opacity .18s ease;
}
.still-shot__frame:hover .still-shot__expand,
.still-shot__expand:focus-visible{ opacity: 1; }
@media (hover: none){ .still-shot__expand{ opacity: 1; } }
.still-shot__cap{
	max-width: 960px;
	margin: .6rem auto 0;
	text-align: center;
	font-size: .83rem;
	color: var(--vp-c-text-2);
}

/* Full-screen lightbox (teleported to <body> so the content column never clips it). */
.still-lightbox{
	position: fixed;
	inset: 0;
	z-index: 2147483000;
	display: flex;
	flex-direction: column;
	align-items: center;
	justify-content: center;
	gap: 14px;
	padding: 3vmin;
	background: rgba(15, 15, 17, .9);
	backdrop-filter: blur(3px);
}
.still-lightbox__img{
	max-width: 96vw;
	max-height: 86vh;
	width: auto;
	height: auto;
	border-radius: 10px;
	box-shadow: 0 12px 48px rgba(0, 0, 0, .5);
	background: #000;
}
.still-lightbox__cap{
	margin: 0;
	color: rgba(255, 255, 255, .82);
	font-size: .9rem;
	text-align: center;
	max-width: 80ch;
}
.still-lightbox__close{
	position: absolute;
	top: 16px;
	right: 18px;
	width: 40px;
	height: 40px;
	font-size: 1.1rem;
	color: #fff;
	background: rgba(255, 255, 255, .14);
	border: 1px solid rgba(255, 255, 255, .25);
	border-radius: 50%;
	cursor: pointer;
}
.still-lightbox__close:hover{ background: rgba(255, 255, 255, .26); }
</style>
