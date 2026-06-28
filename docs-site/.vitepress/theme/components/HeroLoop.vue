<!-- SPDX-License-Identifier: BUSL-1.1 -->
<script setup>
import {ref, onMounted, onBeforeUnmount, nextTick} from 'vue';
import {withBase} from 'vitepress';

const props = defineProps({
	src: {type: String, default: ''},        // VP9 WebM (primary)
	mp4: {type: String, default: ''},         // H.264 MP4 fallback (iOS Safari / older browsers)
	poster: {type: String, default: ''},
	caption: {type: String, default: ''},
	guide: {type: String, default: ''},       // internal href to the full guide
	guideLabel: {type: String, default: ''}   // short label shown in muted text after the link
});

const videoEl = ref(null);
const lightboxOpen = ref(false);
const lightboxCloseEl = ref(null);
const reducedMotion = ref(false); // resolved on mount; gates lightbox autoplay so reduced-motion users get a still
let observer = null;
let lastFocused = null;

function prefersReducedMotion()
{
	return typeof window !== 'undefined'
		&& typeof window.matchMedia === 'function'
		&& window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

// Full-screen lightbox: the inline loop is capped at 960px so the tool UI text is small. Clicking
// opens a large, scrubable copy (with controls) over a dark backdrop so you can read it. Esc or a
// backdrop click closes it; while open we lock body scroll so the page behind doesn't move.
function openLightbox()
{
	if(typeof document !== 'undefined')
	{
		lastFocused = document.activeElement;
		document.body.style.overflow = 'hidden';
	}
	lightboxOpen.value = true;
	// Move focus into the dialog so keyboard users start inside it (Esc/controls reachable).
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
	// Return focus to whatever opened the lightbox (the inline loop / Expand button).
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
	reducedMotion.value = prefersReducedMotion();
	const el = videoEl.value;
	if(!el)
	{
		return;
	}
	// Reduced-motion: never autoplay; the poster stays as the still frame.
	if(prefersReducedMotion())
	{
		el.removeAttribute('autoplay');
		el.pause();
		return;
	}
	// Lazy: play only while scrolled into view (saves mobile battery + data).
	if(typeof IntersectionObserver === 'undefined')
	{
		el.play && el.play().catch(() => {});
		return;
	}
	observer = new IntersectionObserver((entries) =>
	{
		for(const entry of entries)
		{
			if(entry.isIntersecting)
			{
				el.play && el.play().catch(() => {});
			}
			else
			{
				el.pause && el.pause();
			}
		}
	}, {threshold: 0.25});
	observer.observe(el);
});

onBeforeUnmount(() =>
{
	if(typeof document !== 'undefined')
	{
		document.removeEventListener('keydown', onKeydown);
		document.body.style.overflow = '';
	}
	if(observer)
	{
		observer.disconnect();
		observer = null;
	}
});
</script>

<template>
	<figure class="hero-loop">
		<div class="hero-loop__frame">
			<video
				ref="videoEl"
				class="hero-loop__video"
				:poster="withBase(poster)"
				:aria-label="caption || 'KernDX admin tool walkthrough'"
				muted
				loop
				playsinline
				preload="none"
				autoplay
				@click="openLightbox"
			>
				<source v-if="src" :src="withBase(src)" type="video/webm" />
				<source v-if="mp4" :src="withBase(mp4)" type="video/mp4" />
			</video>
			<button type="button" class="hero-loop__expand" aria-label="Expand to full screen" @click="openLightbox">
				<span aria-hidden="true">⤢</span> Expand
			</button>
		</div>
		<figcaption v-if="caption || guide" class="hero-loop__meta" :class="{'has-guide': !!guide}">
			<span v-if="caption" class="hero-loop__cap">{{ caption }}</span>
			<a v-if="guide" class="hero-loop__guide" :href="withBase(guide)">Read the full write-up →<span v-if="guideLabel" class="hero-loop__guide-tgt"> ({{ guideLabel }})</span></a>
		</figcaption>

		<Teleport to="body">
			<div v-if="lightboxOpen" class="hero-loop-lightbox" role="dialog" aria-modal="true" :aria-label="caption || 'KernDX admin tool walkthrough'" @click.self="closeLightbox">
				<button ref="lightboxCloseEl" type="button" class="hero-loop-lightbox__close" aria-label="Close" @click="closeLightbox">✕</button>
				<video
					class="hero-loop-lightbox__video"
					:poster="withBase(poster)"
					muted
					loop
					playsinline
					preload="none"
					:autoplay="!reducedMotion"
					controls
				>
					<source v-if="src" :src="withBase(src)" type="video/webm" />
					<source v-if="mp4" :src="withBase(mp4)" type="video/mp4" />
				</video>
				<p v-if="caption" class="hero-loop-lightbox__cap">{{ caption }}</p>
			</div>
		</Teleport>
	</figure>
</template>

<style scoped>
/* The <video> carries aspect-ratio + width:100% and is always in the DOM, so the browser
   reserves its box from first paint (before the poster/sources fetch) — no cumulative layout
   shift when the lazy media resolves. */
.hero-loop{ margin: 1.6rem 0 2.6rem; }
.hero-loop__frame{ position: relative; max-width: 960px; margin: 0 auto; }
.hero-loop__video{
	display: block;
	width: 100%;
	aspect-ratio: 16 / 9;
	height: auto;
	border: 1px solid var(--vp-c-divider);
	border-radius: 10px;
	background: var(--vp-c-bg-soft);
	cursor: zoom-in;
	box-shadow: 0 1px 3px rgba(0, 0, 0, .06);
}
/* Discoverable "expand" affordance so the full-screen view isn't hidden behind a guess. */
.hero-loop__expand{
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
.hero-loop__frame:hover .hero-loop__expand,
.hero-loop__expand:focus-visible{ opacity: 1; }
@media (hover: none){ .hero-loop__expand{ opacity: 1; } }
/* Tight meta row under the loop: caption left, guide link right (stacks on mobile). */
.hero-loop__meta{
	max-width: 960px;
	margin: .6rem auto 0;
}
.hero-loop__meta.has-guide{
	display: flex;
	justify-content: space-between;
	align-items: baseline;
	gap: 16px;
}
.hero-loop__meta:not(.has-guide){ text-align: center; }
.hero-loop__cap{ font-size: .83rem; color: var(--vp-c-text-2); }
.hero-loop__guide{ font-size: .86rem; font-weight: 600; color: var(--vp-c-brand-1); text-decoration: none; white-space: nowrap; }
.hero-loop__guide:hover{ text-decoration: underline; }
.hero-loop__guide-tgt{ font-size: .72rem; font-weight: 400; color: var(--vp-c-text-2); }
@media (max-width: 640px){
	.hero-loop__meta.has-guide{ flex-direction: column; align-items: flex-start; gap: 5px; }
	.hero-loop__guide{ white-space: normal; }
}

/* Full-screen lightbox (teleported to <body> so the content column never clips it). */
.hero-loop-lightbox{
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
.hero-loop-lightbox__video{
	max-width: 96vw;
	max-height: 86vh;
	width: auto;
	height: auto;
	border-radius: 10px;
	box-shadow: 0 12px 48px rgba(0, 0, 0, .5);
	background: #000;
}
.hero-loop-lightbox__cap{
	margin: 0;
	color: rgba(255, 255, 255, .82);
	font-size: .9rem;
	text-align: center;
}
.hero-loop-lightbox__close{
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
.hero-loop-lightbox__close:hover{ background: rgba(255, 255, 255, .26); }
</style>
