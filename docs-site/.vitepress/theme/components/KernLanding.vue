<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- KernDX home-page landing tour. Rendered from home.md (layout:page) inside
     the real VitePress frame (navbar, search, theme toggle, left sidebar). Styling uses the
     site's --vp-c-* tokens so it inherits the bronze brand + light/dark. The side-by-side
     code examples are NOT in this component: they're authored as ```apex fences in home.md
     and passed in via the #examples slot (so they get the site's shiki Apex highlighting +
     a Copy button). Positioning: KernDX is a LIBRARY OF FRAMEWORKS for Apex & LWC, not a single
     framework. The credibility strip below shows the verified counts (global API classes,
     production classes, LWC components, Apex test count, plus the 100%/95% coverage policy).
     The strip numbers, the version badge and the API version are data-driven: scripts/prepare.mjs reads them
     from THIS tree's docs/Strategic Guide - Metrics.md and emits them as
     .vitepress/landing.generated.mjs, so the latest landing shows the live figures and a
     frozen version line shows the numbers it shipped with. scripts/validate-landing-metrics.js
     guards that the Metrics doc still exposes those rows on npm run docs:validate. -->
<script setup>
// Per-build landing facts — version label + credibility-strip figures — emitted by
// scripts/prepare.mjs from this version tree's Metrics doc. See the header comment above.
// resolve() makes an internal link base-aware for THIS version tree (so a frozen line stays
// in its own tree, not the latest one) and applies the build-time fallback in landing.links
// (absent page → home, absent anchor → page top) so the shared landing never points an older
// version at content it never had. Wrap every internal landing link with the resolve helper
// (see the install and fast-start links in the template below).
//
// Two layouts. The current front page (home.md) fills the #features slot: a jump list of every
// feature ("What you get on day one"), then one "The same task" section of examples in groups
// (FeatureGroup.vue, the first open), then the job table, renamed "Pick your path". The front pages
// of the frozen versions (docs-versions/<X.Y>/home.md) fill #examples and #examplesMore instead, and
// keep their older layout: the day-one links to the Fast Starts, the job table, then the examples
// with a "Show 5 more examples" fold. Both render with this one component, because a frozen version
// is built with the latest theme.
import {withBase} from 'vitepress';
import {onBeforeUnmount, onMounted, ref, useSlots} from 'vue';
import landing from '../../landing.generated.mjs';
import {openClosedGroupsAround, scrollToElement, showHashTarget} from '../movedAnchors.mjs';

const resolve = (href) => withBase(landing.links?.[href] ?? href);

const hasFeatures = Boolean(useSlots().features);

// How long a block the reader jumped to keeps its outline, so the eye finds it.
const JUMP_OUTLINE_MS = 1400;

const examplesSection = ref(null);
const allOpen = ref(false);

// The groups of examples in the "The same task" section.
const groups = () => examplesSection.value?.querySelectorAll('details.kl-group') ?? [];

// "Expand all" reads "Collapse all" once every group is open.
function updateExpandAll()
{
	const list = [...groups()];
	allOpen.value = list.length > 0 && list.every(group => group.open);
}

// Opens every group, or closes every group when all are open.
function toggleAllGroups()
{
	const open = !allOpen.value;
	groups().forEach(group =>
	{
		group.open = open;
	});
	updateExpandAll();
}

// Takes the reader to an example: opens its group, scrolls to it and outlines it for a moment. The
// address takes the example's #id in place of the current entry, as a jump inside the page.
function jumpTo(hash)
{
	const element = document.getElementById(decodeURIComponent(hash.slice(1)));
	if(!element)
	{
		return;
	}
	window.history.replaceState(window.history.state, '', hash);
	openClosedGroupsAround(element);
	window.requestAnimationFrame(() =>
	{
		scrollToElement(element);
		element.classList.add('kl-jumped');
		window.setTimeout(() => element.classList.remove('kl-jumped'), JUMP_OUTLINE_MS);
	});
}

// The jump list's links and each group's "Back to all features" link. Their containers carry the
// vp-raw class, so VitePress leaves these clicks to this handler: the address is replaced, not added
// to the history. The back link sits at the top of an open group's body, outside its heading; the
// click still stops here so it never reaches the group's own toggle.
function onExamplesClick(event)
{
	const link = event.target instanceof Element ? event.target.closest('a.kl-index-link, a.kl-back') : null;
	if(!link || event.button !== 0 || event.ctrlKey || event.shiftKey || event.altKey || event.metaKey)
	{
		return;
	}
	event.preventDefault();
	event.stopPropagation();
	jumpTo(link.getAttribute('href'));
}

// A link from another page, an old guide address sent here, or the Back and Forward buttons can
// name an example inside a closed group. Open the group, then show the example.
const onHashChange = () => showHashTarget(window.location.hash);

onMounted(() =>
{
	if(!hasFeatures)
	{
		return;
	}
	updateExpandAll();
	showHashTarget(window.location.hash);
	window.addEventListener('hashchange', onHashChange);
});

onBeforeUnmount(() => window.removeEventListener('hashchange', onHashChange));
</script>

<template>
	<main class="kern-landing">

		<!-- Hero -->
		<header class="kl-hero">
			<div class="kl-wrap">
				<div class="kl-badges">
					<span class="kl-badge brand" data-spec-id="badge-version">{{ landing.version }}</span>
					<span class="kl-badge" data-spec-id="badge-license">Apache 2.0</span>
					<span class="kl-badge" data-spec-id="badge-api">API {{ landing.apiVersion }}</span>
				</div>
				<h1 data-spec-id="hero-headline">Every Salesforce framework your team keeps rebuilding, in one Apex &amp; LWC library.</h1>
				<p class="kl-sub" data-spec-id="hero-subline">Spend your team on the features that move the business, not on rebuilding the trigger framework, logging, security, and the rest of the plumbing every Salesforce org writes anyway. One managed package with the safe behaviour on automatically, open source on GitHub.</p>
				<p class="kl-depth" data-spec-id="hero-depth">You write the line you expect. You get the depth you didn't: the safe behaviour on automatically, with logging, performance, and traceability built in.</p>
				<p class="kl-durability" data-spec-id="hero-durability">Built to stay consistent after years of changes and dozens of contributors.</p>
				<div class="kl-cta-row">
					<a class="kl-cta primary" :href="resolve('/installation')" data-spec-id="cta-install">Install KernDX →</a>
					<a class="kl-cta ghost" :href="resolve('/fast-starts')" data-spec-id="cta-fast-starts">Browse the Fast Starts</a>
					<a class="kl-cta ghost" :href="resolve('/ai-agent-instructions')" data-spec-id="cta-ai-assistant">AI context</a>
					<a class="kl-cta ghost" :href="resolve('/administration-tools-guide')" data-spec-id="cta-admin-tools">See the admin tools in action →</a>
				</div>
			</div>
		</header>

		<!-- Credibility strip (thin, directly under the hero) -->
		<section class="kl-strip-section">
			<div class="kl-wrap">
				<div class="kl-strip" data-spec-id="credibility-strip">
					<div class="m" data-spec-id="strip-global"><b>{{ landing.globalApiClasses }}</b><span>global API classes</span></div>
					<div class="m" data-spec-id="strip-classes"><b>{{ landing.productionClasses }}</b><span>production classes</span></div>
					<div class="m" data-spec-id="strip-lwc"><b>{{ landing.lwcComponents }}</b><span>LWC components</span></div>
					<div class="m" data-spec-id="strip-coverage"><b>100%</b><span>Apex coverage · {{ landing.apexTestsLabel }} tests</span></div>
				</div>
			</div>
		</section>

		<!-- What it prevents -->
		<section class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="what-it-prevents">What it prevents</h2>
				<p class="kl-headline">What happens when…</p>
				<div class="kl-callout" data-spec-id="failure-modes">
					<ul>
						<li data-spec-id="failure-trigger-drift">the trigger framework you copied into fifteen orgs has drifted in all fifteen, and the bug only reproduces in the one you didn't touch?</li>
						<li data-spec-id="failure-fls-bypass">a query runs in system mode, skips the user's field permissions, and the security reviewer asks you to prove it didn't, with no single place to look?</li>
						<li data-spec-id="failure-slow-tests">a clean deploy finishes before the test suite that's supposed to guard it does, so the suite stops being a gate and starts being a formality?</li>
						<li data-spec-id="failure-ai-apex">the AI assistant writes Apex that compiles, passes review, and ignores every naming and bypass rule your team agreed on last quarter?</li>
					</ul>
					<p class="kl-resolve"><strong>KernDX makes each one hard to reach</strong>: permissions on by default, one trigger path every org shares, every shortcut logged with the reason it was taken, and a standards file your AI assistant actually reads before it writes.</p>
				</div>
			</div>
		</section>

		<!-- Why it exists (origin — grounded in the Architecture guide's design thesis) -->
		<section class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="why-it-exists">Why it exists</h2>
				<p class="kl-headline">An accelerator you own, not a product you rent.</p>
				<div class="kl-origin" data-spec-id="origin-story">
					<p>Most enterprise Salesforce orgs spend three to five years rebuilding the same foundations: selectors, trigger handling, logging, web services, async, masking, and field-level security (FLS) enforcement. They take on tech debt at every layer. The aim of KernDX is to skip the rebuild cycle, not pay to rent your way around it.</p>
					<p>KernDX is the integrated package those teams would have built with the budget and design discipline upfront: one library of frameworks for Apex and Lightning Web Components (LWC), plus the onboarding docs, continuous-integration (CI) tooling, and enforced defaults (permissions on by default, audit-logged bypasses, a coverage gate run on every release) that keep those guarantees true after a dozen contributors.</p>
					<p data-spec-id="origin-ownership">And the architecture stays yours. The source is public under the Apache License 2.0, so you can read it, fork it, deploy it unmanaged, or repackage it under your own namespace. No black box and no lock-in: if you ever move off the managed package, the framework stays in your org as your code, not a vendor's.</p>
				</div>
			</div>
		</section>

			<!-- What you get on day one: one line per feature, grouped as the examples are. Each line
			     opens its example below, in its group. -->
			<section v-if="hasFeatures" id="jump-to-a-feature" class="kl-section" @click="onExamplesClick">
				<div class="kl-wrap">
					<h2 class="kl-eyebrow" id="whats-in-the-box">What you get on day one</h2>
					<p class="kl-headline">One install. The whole stack.</p>
					<p class="kl-lead">Each name opens its example below: the plain Salesforce way on the left, the KernDX way on the right. The guide for each feature is linked from its example.</p>
					<div class="kl-index vp-raw" data-spec-id="day-one">
						<div><h3>Read and save data</h3>
							<ul>
								<li><a class="kl-index-link" href="#selectors">Selectors</a> <span>every read in user mode, paged past 2,000 rows</span></li>
								<li><a class="kl-index-link" href="#saving-records">Saving records</a> <span>related records in one all-or-nothing save</span></li>
								<li><a class="kl-index-link" href="#dtos">DTOs</a> <span>JSON in and out through typed classes</span></li>
								<li><a class="kl-index-link" href="#security">Encryption and sharing</a> <span>one call to encrypt, sharing chosen per read</span></li>
								<li><a class="kl-index-link" href="#data-masking">Data masking</a> <span>card numbers and keys removed from logs</span></li>
							</ul>
						</div>
						<div><h3>Automate</h3>
							<ul>
								<li><a class="kl-index-link" href="#triggers">Triggers</a> <span>one trigger per object, actions set in metadata</span></li>
								<li><a class="kl-index-link" href="#validation">Validation rules</a> <span>log a rule's failures before it blocks saves</span></li>
								<li><a class="kl-index-link" href="#async-chains">Background chains</a> <span>steps that recover from a crash</span></li>
								<li><a class="kl-index-link" href="#scheduled-jobs">Scheduled jobs</a> <span>timed and tuned from a record</span></li>
								<li><a class="kl-index-link" href="#flow-actions">Flow actions</a> <span>callouts, flags and logs, ready to drag in</span></li>
								<li><a class="kl-index-link" href="#feature-flags">Feature flags</a> <span>switch code on for a pilot group, no deployment</span></li>
							</ul>
						</div>
						<div><h3>Integrate</h3>
							<ul>
								<li><a class="kl-index-link" href="#outbound-calls">Outbound services</a> <span>one service class every caller and Flow shares</span></li>
								<li><a class="kl-index-link" href="#resilient-callouts">Resilient callouts</a> <span>retry, breaker and a test mock on a single call</span></li>
								<li><a class="kl-index-link" href="#inbound-apis">Inbound APIs</a> <span>a replayed request answered with HTTP 409</span></li>
								<li><a class="kl-index-link" href="#logging">Logging</a> <span>errors that survive a rollback</span></li>
							</ul>
						</div>
						<div><h3>Build, test and run</h3>
							<ul>
								<li><a class="kl-index-link" href="#lwc">Lightning web components</a> <span>toasts and navigation in one call</span></li>
								<li><a class="kl-index-link" href="#test-data">Test data and mocks</a> <span>200 records in one line, or none at all</span></li>
								<li><a class="kl-index-link" href="#code-scanning">Code scanning</a> <span>PMD and ESLint rules that know KernDX</span></li>
								<li><a class="kl-index-link" href="#cache">Platform Cache</a> <span>a cache that never breaks the call</span></li>
								<li><a class="kl-index-link" href="#consoles">Admin consoles</a> <span>find what failed, from a screen</span></li>
								<li><a class="kl-index-link" href="#ai-assisted-development">AI coding standards</a> <span>rules your AI assistant reads</span></li>
							</ul>
						</div>
					</div>
					<div class="kl-optin" data-spec-id="opt-in">
						<p><strong>Take only what you need.</strong> Every layer is opt-in: you can install KernDX for logging and the Log Console alone, and leave every existing trigger, query and class as it is.</p>
						<p>Two parts lean on others. The code-scanning rules expect the other layers: they flag inline SOQL, hand-written DML, <code>System.debug</code>, raw <code>Http</code> calls and plain <code>Schedulable</code> classes, but they only report until you set a severity threshold. A Flow callout action needs one outbound service class to call.</p>
					</div>
				</div>
			</section>

			<!-- The same task, with and without KernDX: every example, in four groups (from home.md) -->
			<section v-if="hasFeatures" id="the-same-task" ref="examplesSection" class="kl-section" @click="onExamplesClick" @toggle.capture="updateExpandAll">
				<div class="kl-wrap">
					<h2 class="kl-eyebrow" id="the-same-task-heading">The same task, with and without KernDX</h2>
					<p class="kl-headline">You write the line you expect. You get the depth you didn't.</p>
					<p class="kl-lead">Plain Salesforce on the left, KernDX on the right. The KernDX samples use the managed package's <code>kern.</code> prefix, and every read in them goes through a selector.</p>
					<div class="kl-group-tools vp-raw"><button id="kl-expand-all" type="button" :aria-expanded="String(allOpen)" @click.stop="toggleAllGroups">{{ allOpen ? 'Collapse all' : 'Expand all' }}</button></div>
					<slot name="features" />
				</div>
			</section>

			<!-- What you get on day one — the whole stack in one install (the frozen versions' layout) -->
			<section v-if="!hasFeatures" class="kl-section">
				<div class="kl-wrap">
					<h2 class="kl-eyebrow" id="whats-in-the-box">What you get on day one</h2>
					<p class="kl-headline">One install. The whole stack.</p>
					<p class="kl-lead">Nothing to assemble. Every layer ships in the one package, each one ready to switch on when you reach for it.</p>
					<div class="kl-stack" data-spec-id="day-one">
						<a :href="resolve('/fast-start-trigger-actions#tier-1-build-it-5-minutes')" data-spec-id="day-one-triggers">Trigger framework</a>
						<a :href="resolve('/fast-start-selectors#tier-1-see-it-work-2-minutes')" data-spec-id="day-one-selectors">Selectors &amp; queries</a>
						<a :href="resolve('/fast-start-dml#tier-1-see-it-work-2-minutes')" data-spec-id="day-one-dml">Secure DML &amp; transactions</a>
						<a :href="resolve('/fast-start-logging#tier-1-see-it-work-2-minutes')" data-spec-id="day-one-logging">Rollback-safe logging</a>
						<a :href="resolve('/fast-start-async-processing#tier-1-see-it-work')" data-spec-id="day-one-async">Async orchestration</a>
						<a :href="resolve('/fast-start-scheduled-jobs#tier-1-see-it-work-10-minutes')" data-spec-id="day-one-scheduling">Scheduled jobs &amp; job runner</a>
						<a :href="resolve('/fast-start-inbound-apis#tier-1-see-it-work-2-minutes')" data-spec-id="day-one-inbound">Inbound REST</a>
						<a :href="resolve('/fast-start-outbound-apis#tier-1-see-it-work-2-minutes')" data-spec-id="day-one-outbound">Outbound HTTP client</a>
						<a :href="resolve('/fast-start-feature-flags#tier-1-see-it-work-2-minutes')" data-spec-id="day-one-flags">Feature flags</a>
						<a :href="resolve('/fast-start-custom-validations#tier-1-see-it-work-5-minutes')" data-spec-id="day-one-validation">Validation framework</a>
						<a :href="resolve('/fast-start-data-masking#rule-modes')" data-spec-id="day-one-masking">Data masking</a>
						<a :href="resolve('/fast-start-code-scanning#pmd-rule-reference')" data-spec-id="day-one-pmd">PMD rulesets</a>
						<a :href="resolve('/fast-start-code-scanning#eslint-rule-reference')" data-spec-id="day-one-eslint">ESLint plugin</a>
						<a :href="resolve('/ai-agent-instructions#coding-standards')" data-spec-id="day-one-ai">AI coding standards</a>
					</div>
				</div>
			</section>

		<!-- The job table: one row per job, with the page to try it, learn it and look up a method. On the
		     current front page it comes after the examples, as "Pick your path". -->
		<section :id="hasFeatures ? 'pick-your-path' : undefined" class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="what-do-you-need-to-do">{{ hasFeatures ? 'Pick your path' : 'What do you need to do?' }}</h2>
				<p class="kl-lead" data-spec-id="jobs-new">New to KernDX? <a :href="resolve('/from-plain-apex-to-kerndx')">From Plain Apex to KernDX</a> shows the Apex you already write next to the KernDX version. Deciding whether to use it? Start with <a :href="resolve('/strategic-guide-overview')">Why KernDX</a>.</p>
				<div class="kl-jobs" data-spec-id="job-table">
					<table role="table">
						<thead role="rowgroup">
							<tr role="row"><th scope="col" role="columnheader">I need to</th><th scope="col" role="columnheader">Try it in minutes</th><th scope="col" role="columnheader">Learn it properly</th><th scope="col" role="columnheader">Look up a method</th></tr>
						</thead>
						<tbody role="rowgroup">
							<tr role="row"><th scope="row" role="rowheader">Query records<span>SOQL, selectors, counts and totals</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-selectors')">Fast Start: Selectors</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/selectors-guide')">Selectors guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/qry-builder')">QRY_Builder</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Save records<span>Insert, update, upsert, delete, unit of work</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-dml')">Fast Start: DML</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/dml-guide')">DML guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/dml-builder')">DML_Builder</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Run code on a trigger<span>Logic before and after a save</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-trigger-actions')">Fast Start: Trigger Actions</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/triggers-guide')">Triggers guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/trg-base')">TRG_Base</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Log what happened<span>Instead of System.debug</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-logging')">Fast Start: Logging</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/logging-guide')">Logging guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/log-builder')">LOG_Builder</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Run work in the background<span>Queueable jobs in steps</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-async-processing')">Fast Start: Async Processing</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/async-processing-guide')">Async Processing guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/util-asyncchain')">UTIL_AsyncChain</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Call another system<span>HTTP callouts and retries</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-outbound-apis')">Fast Start: Outbound APIs</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/web-services-guide')">Web Services guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/util-httpclient')">UTIL_HttpClient</a>, <a :href="resolve('/reference/apex/api-outbound')">API_Outbound</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Run a scheduled job<span>Schedulable and the job runner</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-scheduled-jobs')">Fast Start: Scheduled Jobs</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/async-processing-guide#scheduler-framework')">Async Processing guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/sched-base')">SCHED_Base</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Validate records<span>Rules that stop bad data</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-custom-validations')">Fast Start: Custom Validations</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/validation-guide')">Validation guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/util-validationrule')">UTIL_ValidationRule</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Control who can see records<span>Sharing, field security and user mode</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-security')">Fast Start: Security</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/security-guide')">Security guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/qry-builder-builder')">QRY_Builder.Builder</a>, <a :href="resolve('/reference/apex/util-sharing')">UTIL_Sharing</a></td></tr>
							<tr role="row"><th scope="row" role="rowheader">Test my code<span>Test data and pretend query results</span></th><td role="cell" data-label="Try it in minutes"><a :href="resolve('/fast-start-test-data')">Fast Start: Test Data</a></td><td role="cell" data-label="Learn it properly"><a :href="resolve('/test-data-guide')">Test Data guide</a></td><td role="cell" data-label="Look up a method"><a :href="resolve('/reference/apex/tst-builder')">TST_Builder</a>, <a :href="resolve('/reference/apex/tst-mock')">TST_Mock</a></td></tr>
						</tbody>
					</table>
				</div>
			</div>
		</section>

		<!-- The same task, with and without KernDX (the frozen versions' layout: examples come from home.md
		     as ```apex fences, the last five behind a fold) -->
		<section v-if="!hasFeatures" class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="the-same-task">The same task, with and without KernDX</h2>
				<p class="kl-headline">You write the line you expect. You get the depth you didn't.</p>
				<p class="kl-lead">Plain Apex on the left, KernDX on the right. Under each KernDX snippet is a list of <em>what you also got, without typing it</em>: the security, logging, performance, and correlation the framework added for free. Every item links to the guide section that proves it.</p>
				<slot name="examples" />
				<details class="kl-secmore" data-spec-id="examples-show-more">
					<summary><span class="kl-secmore-c">Show 5 more examples</span><span class="kl-secmore-o">Show fewer examples</span></summary>
					<div class="kl-secmore-body"><slot name="examplesMore" /></div>
				</details>
			</div>
		</section>

		<!-- Built for AI-assisted development (surfaced early — it's the differentiator). The jump list's
		     "AI coding standards" line lands here. -->
		<section id="ai-assisted-development" class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="built-for-ai">Built for AI-assisted development</h2>
				<p class="kl-headline">Your AI assistant gets the standards before it writes.</p>
				<p class="kl-lead">KernDX ships its AI context as plain files in the public repo, with nothing to install, so Claude, Cursor, Copilot, or Gemini generate Apex and LWC that follow the framework (the naming, the secure defaults, the audited-bypass rule) instead of inventing their own.</p>
				<div class="kl-agentic">
					<p class="kl-def" data-spec-id="agentic-definition">KernDX is a library of Salesforce frameworks for Apex and LWC, open source under the Apache License 2.0. It is one managed package (namespace <code>kern</code>, API {{ landing.apiVersion }}). It covers trigger handling, secure queries and saves, structured logging, background-job orchestration, scheduled jobs on a shared job runner, inbound and outbound REST, no-code feature flags and validation, and write-time data masking, plus the CI tooling (PMD rulesets, an ESLint plugin, secret scanning, and coverage gates).</p>
					<div class="kl-usage" data-spec-id="agentic-usage">
						<p class="kl-usage-title">What ships, and how to wire it up</p>
						<ol>
							<li><a :href="resolve('/agents')"><strong>AGENTS.md</strong></a> sits at the repo root: the tool-neutral on-ramp that Claude Code, Cursor, Codex, and Cline read first. It orients your assistant and points it at the conventions and the full reference.</li>
							<li><a :href="resolve('/ai-agent-instructions')"><strong>AI Agent Instructions</strong></a> is the complete code-generation reference. Copy it into the rules file your tool auto-loads (<code>AGENTS.md</code>, <code>CLAUDE.md</code>, or <code>.cursorrules</code>), or reference it so a <code>git pull</code> keeps it current.</li>
							<li>From then on your assistant writes framework-correct Apex and LWC: the right namespace prefix, FLS-enforced reads and writes, the naming rules, and the audited-bypass pattern, instead of reinventing them.</li>
						</ol>
					</div>
					<p class="kl-files" data-spec-id="agentic-llms">AGENTS.md · /llms.txt · Code Conventions Guide · PMD + ESLint rules</p>
					<p class="kl-foot-note" data-spec-id="agentic-enforcement">Those same standards ship as PMD rulesets and an ESLint plugin, so what the assistant follows is also enforced where you already work: inline in VS Code or IntelliJ / Illuminated Cloud, and gated on every pull request in CI.</p>
					<a class="kl-cta primary" :href="resolve('/ai-agent-instructions')" data-spec-id="agentic-cta">Open the AI Agent Instructions →</a>
				</div>
			</div>
		</section>

		<!-- Ideas worth taking (cards link to the design rationale in the guides) -->
		<section class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="ideas-worth-taking">Ideas worth taking</h2>
				<p class="kl-headline">Worth reading even if you never adopt KernDX.</p>
				<p class="kl-lead">These are design decisions, not feature names, so take the ideas with you. Each links to the guide that explains the thinking. The source is public under the Apache License 2.0.</p>
				<div class="kl-cards">
					<a class="kl-card" :href="resolve('/fast-start-inbound-apis#idempotency')" data-spec-id="steal-idempotency"><h3>Why a &lsquo;safe to retry&rsquo; key isn't enough</h3><p>If a retry shows up carrying different data than the first try, KernDX rejects it instead of replaying the old result, so a changed request can't silently overwrite the original.</p><span class="go">Read the decision →</span></a>
					<a class="kl-card" :href="resolve('/logging-guide#logging-inside-platform-event-change-event-triggers')" data-spec-id="steal-self-trigger-log"><h3>Why a logging tool must avoid logging about itself</h3><p>When the thing recording events is itself event-driven, naively logging its own activity loops forever. KernDX detects that case and writes the record directly.</p><span class="go">Read the decision →</span></a>
					<a class="kl-card" :href="resolve('/selectors-guide#handle-null-and-empty-collections')" data-spec-id="steal-empty-filter"><h3>Why an empty filter should match nothing, not everything</h3><p>An empty &ldquo;only include these&rdquo; list should return nothing; an empty &ldquo;exclude these&rdquo; list, everything. Getting that right stops a filter bug from quietly scanning your whole table.</p><span class="go">Read the decision →</span></a>
					<a class="kl-card" :href="resolve('/data-masking-guide#modes')" data-spec-id="steal-luhn-mask"><h3>Why hiding card numbers takes more than pattern-matching</h3><p>Plenty of 16-digit numbers aren't credit cards. KernDX matches the shape loosely, then runs the card-number checksum, so real cards get hidden while order numbers and dates are left alone.</p><span class="go">Read the decision →</span></a>
					<a class="kl-card" :href="resolve('/code-conventions-guide#type-resolution')" data-spec-id="steal-type-resolution"><h3>Why the framework looks for your version of a class first</h3><p>It checks your project for a class before falling back to its own, so &ldquo;write your own and it wins&rdquo; becomes a built-in way to customise behaviour, with nothing to register.</p><span class="go">Read the decision →</span></a>
					<a class="kl-card" :href="resolve('/feature-flags-guide#evaluation-order')" data-spec-id="steal-flag-firewall"><h3>Why feature flags decide like an access list</h3><p>Each rule can answer yes, no, or &ldquo;not my call&rdquo;, and that third answer is what lets you stack &ldquo;block these, then allow those&rdquo; rules in order without them fighting.</p><span class="go">Read the decision →</span></a>
				</div>
			</div>
		</section>

		<!-- How a request flows — multiple entry points, one secure core, optional snap-ins -->
		<section class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="how-it-flows">How a request flows</h2>
				<p class="kl-headline">Many ways in. One secure core. Optional layers.</p>
				<p class="kl-lead">An LWC call, a DML save, a trigger, a REST endpoint, a batch job: any of them starts the same way. The core transaction is always there; the rest snap in only when your code uses them, and one tracking ID (the correlation ID) ties whichever layers ran into a single trace.</p>
				<div class="kl-flow" data-spec-id="flow-diagram">
					<div class="kl-flow-row" data-spec-id="flow-entries">
						<span class="kl-flow-label">Any entry point</span>
						<div class="kl-chips">
							<span class="kl-chip">LWC / Aura</span>
							<span class="kl-chip">Apex service</span>
							<span class="kl-chip">Trigger</span>
							<span class="kl-chip">REST endpoint</span>
							<span class="kl-chip">Batch / Scheduled</span>
						</div>
					</div>
					<div class="kl-flow-down"><span class="kl-kernid" data-spec-id="flow-kernid">8f14e45f-…</span> follows everything below</div>
					<div class="kl-core" data-spec-id="flow-core">
						<span class="kl-core-tag">Always runs</span>
						<span class="kl-core-name">The KernDX core transaction</span>
						<div class="kl-core-parts">
							<span>🔒 Security &amp; FLS</span>
							<span>Query · QRY_Builder / SEL_Base</span>
							<span>DML · DML_Builder</span>
							<span>📦 Atomic save</span>
							<span>🧵 Correlation ID</span>
						</div>
					</div>
					<div class="kl-flow-down muted">only the layers your code actually uses</div>
					<div class="kl-flow-row" data-spec-id="flow-snapins">
						<span class="kl-flow-label">Optional snap-ins</span>
						<div class="kl-chips">
							<span class="kl-chip opt">⚙️ Async · UTIL_AsyncChain</span>
							<span class="kl-chip opt">🌐 Outbound REST · UTIL_HttpClient</span>
							<span class="kl-chip opt">📝 Telemetry · LOG_Builder</span>
						</div>
					</div>
				</div>
				<p class="kl-flow-foot">Adopt one layer today (just the query library, say) and snap in the trigger framework or the async chain the day you need it. The correlation ID makes whatever ran traceable as one request, and every chain it launches keeps a link back to it.</p>
			</div>
		</section>

		<!-- What's different by default (honest competitor framing + link to the full guide) -->
		<section class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="whats-different">Already using fflib, Trigger Actions, or rolling your own?</h2>
				<p class="kl-headline">What's different by default.</p>
				<div class="kl-bydefault" data-spec-id="by-default">
					<ul>
						<li><strong>Security is enforced on reads and writes</strong>, with an audit entry written when a call opts out through the builders, triggers or validation rules.</li>
						<li><strong>One integrated package</strong>: triggers, queries, transactions, logging, REST, async, and masking share one model, instead of you wiring separate libraries together.</li>
						<li><strong>100% Apex coverage and PMD-clean</strong>, enforced on every build, not aspirational.</li>
					</ul>
					<a class="kl-cta ghost" :href="resolve('/strategic-guide-choosing-a-framework')" data-spec-id="by-default-link">Full capability-by-capability comparison →</a>
				</div>
				<p class="kl-foot-note" data-spec-id="by-default-honesty">Honest about scope: where another library has something KernDX does not, the guide names it, capability by capability. For example, <code>nebula-logger</code> offers a choice of how each log is saved, all seven log levels, a retention date per log entry or scenario, and Big Object archiving. <code>fflib-mocks</code> can check how a mock was called and with what (behaviour verification).</p>
			</div>
		</section>

		<!-- Adopt at your own pace -->
		<section class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="adopt-at-your-pace">Adopt at your own pace</h2>
				<p class="kl-headline">Not all-or-nothing.</p>
				<p class="kl-lead">No rip-and-replace, and nothing you take all at once, which is what makes it low-risk to bring into an existing program. A typical path in: the query library first, then secure DML, then the trigger framework, adding async, masking, and the AI standards whenever you reach for them. Each layer stands alone, so adoption stays incremental and reversible.</p>
				<div class="kl-assess" data-spec-id="self-assessment">
						<div class="kl-col yes" data-spec-id="assess-worth"><h3>A fit if…</h3>
							<ul>
								<li>more than one developer works in the org</li>
								<li>AI is writing more of your Apex</li>
								<li>consistency is getting expensive</li>
								<li>onboarding a contributor takes too long</li>
								<li>you need security you can show a reviewer</li>
							</ul>
						</div>
						<div class="kl-col maybe" data-spec-id="assess-not-needed"><h3>Not needed if…</h3>
							<ul>
								<li>your org has no Apex and none planned</li>
							</ul>
						</div>
					</div>
					<p class="kl-foot-note" data-spec-id="assess-already-running">Already running another framework? That is a cost to weigh, not a reason on its own. Staying has costs too, such as wiring separate libraries together or safety checks that can be switched off without a record. Moving has the cost of the migration. The <a :href="resolve('/strategic-guide-choosing-a-framework')">capability-by-capability comparison</a> sets out both.</p>
					<p class="kl-foot-note" data-spec-id="adopt-unmanaged">Can't install a managed package, or would rather not? Because the source is available, you can deploy KernDX straight into your org as unmanaged code (no namespace, no Dev Hub), or repackage it under your own namespace. Installed unmanaged, its code counts toward your org's 6 MB Apex limit, and you update it by redeploying the source. There's a way in for every org.</p>
			</div>
		</section>

		<!-- Get started -->
		<section class="kl-section">
			<div class="kl-wrap">
				<h2 class="kl-eyebrow" id="get-started">Get started</h2>
				<p class="kl-headline">Three ways in.</p>
				<div class="kl-paths" data-spec-id="install-paths">
					<a class="kl-path" :href="resolve('/installation')" data-spec-id="path-install"><b>Install the package</b><span>Add <code>kern</code> at {{ landing.version }} to your org. Swap it in within days.</span></a>
					<a class="kl-path" :href="resolve('/installation')" data-spec-id="path-repackage"><b>Repackage under your own name</b><span>Build KernDX into your own package, as your code.</span></a>
					<a class="kl-path" :href="resolve('/installation')" data-spec-id="path-ci"><b>CI tooling only</b><span>PMD rulesets + ESLint plugin that flag violations inline in VS Code or IntelliJ / Illuminated Cloud and gate them in CI, with no framework code.</span></a>
				</div>
			</div>
		</section>

		<!-- Sticky install CTA -->
		<a class="kl-sticky" :href="resolve('/installation')" data-spec-id="sticky-install">Install KernDX <span>{{ landing.version }}</span></a>

	</main>
</template>

<style scoped>
.kern-landing{ --kl-green: var(--vp-c-green-1); --kl-red: var(--vp-c-red-1); }
.kern-landing :where(h1,h2,h3,h4){ font-weight: 700; letter-spacing: -.01em; line-height: 1.2; }
/* Wider content column so the landing spreads into the space the right-hand "On this page"
   menu would occupy on a doc-layout page (the home is layout:page, so that aside is absent).
   Full-width visual blocks — the code panels, cards grid, metrics strip, flow — use the extra
   width; prose blocks below keep their own readable max-width so lines don't run too long. */
.kl-wrap{ max-width: 1280px; margin: 0 auto; padding: 0 24px; }
/* Prose-bearing boxes stay at a comfortable measure inside the wider column. */
.kl-callout, .kl-bydefault{ max-width: 860px; }
.kl-agentic{ max-width: 900px; }

.kl-section{ padding: 56px 0; border-bottom: 1px solid var(--vp-c-divider); }
.kl-section:last-child{ border-bottom: 0; }
/* The section eyebrow is the section heading (<h2>) — a clean document outline, styled
   as the small uppercase label. */
.kl-eyebrow{ font-size: .8rem; font-weight: 700; letter-spacing: .07em; text-transform: uppercase; color: var(--vp-c-brand-1); margin: 0 0 12px; }
/* The big section statement is a <p> (the <h2> is the eyebrow above), so it needs the
   heading font treatment set explicitly. */
.kl-headline{ font-size: 1.9rem; font-weight: 700; letter-spacing: -.01em; line-height: 1.2; margin: 0 0 10px; }
.kl-lead{ color: var(--vp-c-text-2); max-width: 64ch; margin: 0 0 26px; font-size: 1.02rem; }

/* Hero */
.kl-hero{ padding: 64px 0 52px; background: radial-gradient(1100px 380px at 78% -10%, var(--vp-c-brand-soft), transparent 60%); border-bottom: 1px solid var(--vp-c-divider); }
.kl-badges{ display: flex; flex-wrap: wrap; gap: 8px; margin: 0 0 22px; }
.kl-badge{ font-size: .7rem; font-weight: 600; padding: .2rem .5rem; border-radius: 5px; background: var(--vp-c-bg-soft); border: 1px solid var(--vp-c-divider); color: var(--vp-c-text-2); }
.kl-badge.brand{ background: var(--vp-c-brand-soft); border-color: transparent; color: var(--vp-c-brand-1); }
.kl-hero h1{ font-size: 2.7rem; line-height: 1.08; letter-spacing: -.02em; margin: 0 0 18px; max-width: 22ch; }
.kl-sub{ font-size: 1.12rem; color: var(--vp-c-text-1); max-width: 62ch; margin: 0 0 12px; }
.kl-depth{ font-size: 1.02rem; font-weight: 600; color: var(--vp-c-brand-1); max-width: 60ch; margin: 0 0 12px; }
.kl-durability{ font-size: .98rem; color: var(--vp-c-text-2); max-width: 60ch; margin: 0 0 26px; }

/* Section-level "Show 5 more examples" collapse (wraps the bottom-5 CodeCompare panels) */
.kl-secmore{ margin: 8px 0 0; }
.kl-secmore > summary{ list-style: none; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 9px; box-sizing: border-box; width: 100%; font-size: .98rem; font-weight: 700; color: var(--vp-c-brand-1); border: 1px dashed var(--vp-c-divider); border-radius: 12px; padding: 14px 20px; user-select: none; transition: border-color .15s, background .15s; }
.kl-secmore > summary::-webkit-details-marker{ display: none; }
.kl-secmore > summary::before{ content: "▸"; }
.kl-secmore[open] > summary::before{ content: "▾"; }
.kl-secmore > summary:hover{ border-color: var(--vp-c-brand-1); background: var(--vp-c-brand-soft); }
.kl-secmore > summary .kl-secmore-o{ display: none; }
.kl-secmore[open] > summary .kl-secmore-c{ display: none; }
.kl-secmore[open] > summary .kl-secmore-o{ display: inline; }
.kl-secmore-body{ margin-top: 22px; }
.kl-cta-row{ display: flex; flex-wrap: wrap; gap: 12px; }
.kl-cta{ display: inline-flex; align-items: center; gap: .4rem; font-weight: 600; font-size: .95rem; padding: .7rem 1.15rem; border-radius: 9px; border: 1px solid var(--vp-c-brand-1); text-decoration: none; transition: background .15s; }
.kl-cta.primary{ background: var(--vp-c-brand-1); color: var(--vp-c-white); }
.kl-cta.primary:hover{ background: var(--vp-c-brand-2); }
.kl-cta.ghost{ background: transparent; color: var(--vp-c-brand-1); }
.kl-cta.ghost:hover{ background: var(--vp-c-brand-soft); }

/* Credibility strip */
.kl-strip-section{ padding: 22px 0; border-bottom: 1px solid var(--vp-c-divider); }
.kl-strip{ display: flex; flex-wrap: wrap; border: 1px solid var(--vp-c-divider); border-radius: 12px; overflow: hidden; background: var(--vp-c-bg-soft); }
.kl-strip .m{ flex: 1 1 0; min-width: 150px; padding: 16px 22px; border-right: 1px solid var(--vp-c-divider); }
.kl-strip .m:last-child{ border-right: 0; }
.kl-strip b{ display: block; font-size: 1.55rem; color: var(--vp-c-brand-1); line-height: 1.1; }
.kl-strip span{ font-size: .82rem; color: var(--vp-c-text-2); }

/* Callout */
.kl-callout{ background: var(--vp-c-bg-soft); border: 1px solid var(--vp-c-divider); border-left: 4px solid var(--vp-c-brand-1); border-radius: 10px; padding: 22px 26px; }
.kl-callout ul{ margin: 0; padding-left: 1.1rem; }
.kl-callout li{ margin: .55rem 0; color: var(--vp-c-text-1); }
.kl-resolve{ margin: 18px 0 0; color: var(--vp-c-text-1); }

/* Cards */
.kl-cards{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
.kl-card{ border: 1px solid var(--vp-c-divider); border-left: 3px solid var(--vp-c-brand-1); border-radius: 10px; background: var(--vp-c-bg-soft); padding: 18px 20px; display: flex; flex-direction: column; gap: 8px; text-decoration: none; color: var(--vp-c-text-1); }
.kl-card:hover{ background: var(--vp-c-brand-soft); }
.kl-card h3{ margin: 0; font-size: 1rem; }
.kl-card p{ margin: 0; color: var(--vp-c-text-2); font-size: .9rem; }
.kl-card .go{ margin-top: auto; font-size: .8rem; font-weight: 600; color: var(--vp-c-brand-1); }

/* Flow — multi-entry, secure core, optional snap-ins */
.kl-flow{ border: 1px solid var(--vp-c-divider); border-radius: 14px; background: var(--vp-c-bg-soft); padding: 22px; }
.kl-flow-row{ display: flex; flex-direction: column; gap: 10px; }
.kl-flow-label{ font-size: .72rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--vp-c-text-2); }
.kl-chips{ display: flex; flex-wrap: wrap; gap: 8px; }
.kl-chip{ font-family: var(--vp-font-family-mono); font-size: .82rem; font-weight: 600; padding: .35rem .7rem; border-radius: 8px; background: var(--vp-c-bg); border: 1px solid var(--vp-c-divider); color: var(--vp-c-text-1); }
.kl-chip.opt{ border-style: dashed; color: var(--vp-c-text-2); background: transparent; }
.kl-flow-down{ display: flex; align-items: center; gap: 8px; justify-content: center; padding: 14px 0; font-size: .85rem; color: var(--vp-c-text-2); }
.kl-flow-down.muted{ color: var(--vp-c-text-2); font-style: italic; }
.kl-kernid{ font-family: var(--vp-font-family-mono); font-size: .8rem; font-weight: 700; color: var(--vp-c-brand-1); background: var(--vp-c-brand-soft); border-radius: 6px; padding: .15rem .5rem; }
.kl-core{ border: 1px solid var(--vp-c-brand-1); border-radius: 12px; background: var(--vp-c-bg); padding: 16px 20px; display: flex; flex-direction: column; gap: 5px; position: relative; }
.kl-core-tag{ position: absolute; top: -10px; left: 16px; font-size: .64rem; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; background: var(--vp-c-brand-1); color: var(--vp-c-white); padding: .12rem .5rem; border-radius: 5px; }
.kl-core-name{ font-family: var(--vp-font-family-mono); font-weight: 700; font-size: .92rem; color: var(--vp-c-brand-1); }
.kl-core-note{ font-size: .85rem; color: var(--vp-c-text-2); }
.kl-flow-foot{ color: var(--vp-c-text-2); font-style: italic; margin: 20px 0 0; max-width: 66ch; }
.kl-core-parts{ display: flex; flex-wrap: wrap; gap: 8px; margin-top: 8px; }
.kl-core-parts span{ font-size: .8rem; font-weight: 600; padding: .3rem .6rem; border-radius: 7px; background: var(--vp-c-brand-soft); color: var(--vp-c-brand-1); }
/* Light mode only: brand-1 bronze on the bronze-soft badge backgrounds sits just under WCAG AA;
   deepen to brand-2 in light (dark already clears it, and brand-2 is the lighter accent there). */
html:not(.dark) .kl-kernid,
html:not(.dark) .kl-core-parts span{ color: var(--vp-c-brand-2); }

/* The job table. Wide screens get four columns. On a phone (640px and narrower, below) each row
   becomes a card: the job is the heading and each link starts with its column name, so nothing
   sits off screen. The role attributes in the markup keep it a table for screen readers, because
   some browsers stop treating a table as a table once its parts are display: block. */
.kl-jobs{ overflow-x: auto; }
.kl-jobs table{ border-collapse: collapse; width: 100%; font-size: .92rem; }
.kl-jobs th, .kl-jobs td{ text-align: left; vertical-align: top; padding: .6rem .8rem; border-bottom: 1px solid var(--vp-c-divider); }
.kl-jobs thead th{ font-size: .8rem; text-transform: uppercase; letter-spacing: .05em; color: var(--vp-c-text-2); }
.kl-jobs tbody th span{ display: block; font-weight: 400; color: var(--vp-c-text-2); font-size: .85rem; }
.kl-jobs a{ color: var(--vp-c-brand-1); }
@media (max-width: 640px){
	.kl-jobs{ overflow-x: visible; }
	.kl-jobs table, .kl-jobs tbody, .kl-jobs tr, .kl-jobs th, .kl-jobs td{ display: block; }
	.kl-jobs thead{ position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }
	.kl-jobs tbody tr{ border: 1px solid var(--vp-c-divider); border-radius: 10px; background: var(--vp-c-bg-soft); padding: .75rem .9rem; margin: 0 0 .75rem; }
	.kl-jobs tbody th, .kl-jobs td{ border-bottom: 0; padding: .2rem 0; }
	.kl-jobs tbody th{ font-size: 1rem; padding-bottom: .45rem; }
	.kl-jobs td::before{ content: attr(data-label) ": "; font-weight: 600; color: var(--vp-c-text-2); }
}

/* "What you get on day one" — capability chips */
.kl-stack{ display: flex; flex-wrap: wrap; gap: 10px; }
.kl-stack a{ display: inline-flex; align-items: center; gap: 7px; font-size: .9rem; font-weight: 600; padding: .45rem .85rem; border: 1px solid var(--vp-c-divider); border-radius: 8px; background: var(--vp-c-bg-soft); color: var(--vp-c-text-1); text-decoration: none; transition: background .15s, border-color .15s, color .15s; }
.kl-stack a:hover{ background: var(--vp-c-brand-soft); border-color: var(--vp-c-brand-1); color: var(--vp-c-brand-1); }
.kl-stack a::before{ content: ""; flex: none; width: 6px; height: 6px; border-radius: 50%; background: var(--vp-c-brand-1); }

/* "What you get on day one" on the current front page: one line per feature, in four groups; each
   name is a link to its example. */
.kl-index{ display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 14px 30px; }
.kl-index > div{ min-width: 0; }
.kl-index h3{ font-size: .78rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--vp-c-text-2); margin: 0 0 6px; }
.kl-index ul{ list-style: none; margin: 0; padding: 0; }
.kl-index li{ padding: 3px 0; font-size: .9rem; line-height: 1.45; }
.kl-index a{ font-weight: 600; color: var(--vp-c-brand-1); text-decoration: none; }
.kl-index a:hover{ text-decoration: underline; }
.kl-index li span{ color: var(--vp-c-text-2); }
.kl-optin{ margin: 22px 0 0; padding: 12px 16px; border: 1px solid var(--vp-c-divider); border-radius: 10px; background: var(--vp-c-bg-soft); font-size: .92rem; color: var(--vp-c-text-1); max-width: 860px; }
.kl-optin code{ font-size: .85em; }
.kl-optin p{ margin: 0; }
.kl-optin p + p{ margin-top: 8px; }
/* "Expand all" over the groups of examples */
.kl-group-tools{ display: flex; justify-content: flex-end; margin: 0 0 6px; font-size: .88rem; }
.kl-group-tools button{ padding: 0; border: 0; background: none; font: inherit; color: var(--vp-c-brand-1); font-weight: 600; cursor: pointer; }
.kl-group-tools button:hover{ text-decoration: underline; }
@media (max-width: 820px){
	.kl-index{ grid-template-columns: minmax(0, 1fr); }
	.kl-index li{ padding: 0; }
	.kl-index a{ display: inline-flex; align-items: center; min-height: 44px; padding-right: 6px; }
	.kl-index li span{ display: block; margin: -10px 0 6px; }
	.kl-group-tools button{ display: inline-flex; align-items: center; min-height: 44px; }
}

/* Origin */
.kl-origin{ border-left: 3px solid var(--vp-c-brand-1); padding-left: 18px; max-width: 70ch; }
.kl-origin p{ margin: 0; color: var(--vp-c-text-1); font-size: 1.02rem; line-height: 1.65; }
.kl-origin p + p{ margin-top: 16px; }

/* What's different by default */
.kl-bydefault{ border: 1px solid var(--vp-c-divider); border-radius: 12px; background: var(--vp-c-bg-soft); padding: 22px 26px; }
.kl-bydefault ul{ margin: 0 0 18px; padding-left: 1.1rem; }
.kl-bydefault li{ margin: .5rem 0; color: var(--vp-c-text-1); }
.kl-bydefault strong{ color: var(--vp-c-brand-1); }
.kl-foot-note{ margin: 16px 0 0; font-size: .88rem; color: var(--vp-c-text-2); font-style: italic; max-width: 66ch; }

/* Self-assessment */
.kl-assess{ display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
.kl-col{ border: 1px solid var(--vp-c-divider); border-radius: 12px; padding: 20px 22px; background: var(--vp-c-bg-soft); }
.kl-col.yes{ border-top: 3px solid var(--kl-green); }
.kl-col.maybe{ border-top: 3px solid var(--vp-c-text-3); }
.kl-col h3{ margin: 0 0 12px; font-size: 1.02rem; }
.kl-col ul{ margin: 0; padding-left: 1.05rem; }
.kl-col li{ margin: .4rem 0; color: var(--vp-c-text-2); font-size: .92rem; }

/* Agentic */
.kl-agentic{ background: var(--vp-c-bg-soft); border: 1px solid var(--vp-c-divider); border-radius: 12px; padding: 24px 26px; }
.kl-def{ font-size: .92rem; color: var(--vp-c-text-2); border-left: 3px solid var(--vp-c-brand-1); padding-left: 16px; margin: 0 0 18px; }
.kl-files{ font-family: var(--vp-font-family-mono); font-size: .82rem; color: var(--vp-c-text-2); margin: 0 0 16px; }

/* AI-usage steps ("wiring it up takes one step") */
.kl-usage{ margin: 0 0 18px; }
.kl-usage-title{ font-size: .82rem; font-weight: 700; letter-spacing: .04em; text-transform: uppercase; color: var(--vp-c-text-2); margin: 0 0 8px; }
.kl-usage ol{ margin: 0; padding-left: 1.2rem; }
.kl-usage li{ margin: .45rem 0; color: var(--vp-c-text-2); font-size: .92rem; line-height: 1.55; }
.kl-usage strong{ color: var(--vp-c-brand-1); }
.kl-usage code{ font-size: .85em; }
.kl-usage a{ color: var(--vp-c-brand-1); text-decoration: none; }
.kl-usage a:hover{ text-decoration: underline; }

/* Install paths */
.kl-paths{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
.kl-path{ border: 1px solid var(--vp-c-divider); border-radius: 10px; padding: 16px; font-size: .88rem; display: flex; flex-direction: column; gap: 6px; text-decoration: none; color: var(--vp-c-text-1); }
.kl-path:hover{ background: var(--vp-c-bg-soft); }
.kl-path b{ color: var(--vp-c-brand-1); }
.kl-path span{ color: var(--vp-c-text-2); }

/* Sticky install CTA */
.kl-sticky{ position: fixed; bottom: 22px; right: 22px; z-index: 20; display: inline-flex; align-items: center; gap: .45rem; font-weight: 700; font-size: .9rem; padding: .65rem 1.05rem; border-radius: 999px; background: var(--vp-c-brand-1); color: var(--vp-c-white); text-decoration: none; box-shadow: 0 6px 20px rgba(0,0,0,.18); }
.kl-sticky span{ font-weight: 500; opacity: .92; font-size: .8rem; }
.kl-sticky:hover{ background: var(--vp-c-brand-2); }

/* Dark mode: the brand bronze is LIGHT there (#d6a875 — tuned for links/accents), so white
   text on the filled-bronze surfaces (the Install buttons + the flow "Always" tag) washes out
   to ~2.2 contrast. Use dark text on those surfaces in dark mode (~8:1 against the light
   bronze). Light mode is untouched: white on the dark bronze (#8a623c) already passes. */
.dark .kl-cta.primary,
.dark .kl-sticky,
.dark .kl-core-tag{ color: var(--vp-c-bg); }

/* Mobile */
@media (max-width: 760px){
	.kl-hero h1{ font-size: 2rem; }
	.kl-headline{ font-size: 1.55rem; }
	.kl-cards, .kl-paths{ grid-template-columns: 1fr; }
	.kl-assess{ grid-template-columns: 1fr; }
	.kl-strip .m{ flex-basis: 100%; border-right: 0; border-bottom: 1px solid var(--vp-c-divider); }
	.kl-strip .m:last-child{ border-bottom: 0; }
	.kl-sticky{ display: none; }
}
</style>

<!-- Unscoped: the landing is layout:page, but the theme still reserves the doc-sidebar
     gutter (.VPContent.has-sidebar → 272px left padding) and renders the sidebar. On the
     landing we want full width — it reads as a product page and gives the side-by-side
     code panes the room they need (no horizontal scroll). Scoped to the kl-landing-page
     pageClass so every other page keeps its sidebar. -->
<style>
.kl-landing-page .VPSidebar{ display: none !important; }
.kl-landing-page .VPContent.has-sidebar{ padding-left: 0 !important; }
</style>
