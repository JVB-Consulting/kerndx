---
group: "Getting Started"
navOrder: 1
title: "Administration Tools"
---

# Administration Tools

KernDX ships four operational consoles in the **Kern** app for exercising integrations, watching events and async work in real time, and finding sensitive data. They are for the admins, developers, and reviewers who run and troubleshoot a KernDX org day to day. Teams usually build or wire together this kind of tooling themselves. Here it comes with the package.

_These walkthroughs reflect the current released version of KernDX._

<div class="admin-tools-glance">
<a href="#api-test-harness">API Test Harness</a>
<a href="#streaming-event-monitor">Streaming Event Monitor</a>
<a href="#chain-monitor">Chain Monitor</a>
<a href="#data-masking-advisor">Data Masking Advisor</a>
</div>

## API Test Harness

Fire inbound **and** outbound API calls from a form, with mocking and Safe Mode rollback built in.

Exercise a real Apex integration without Postman, throwaway anonymous Apex, or leftover test data. Safe Mode rolls back every database write. Mocking returns canned responses, so you can test a callout with no live endpoint.

<HeroLoop src="/recordings/api-harness.webm" mp4="/recordings/api-harness.mp4" poster="/recordings/api-harness-poster.jpg" caption="Run an outbound call, then an inbound one, with Safe Mode and Mocking built in." guide="/web-services-guide" guideLabel="Web Services Guide">

[Watch this walkthrough on the live docs site](https://docs.jvb-consulting.io/administration-tools-guide#api-test-harness) · [Read the full write-up in the Web Services Guide](https://docs.jvb-consulting.io/web-services-guide#api-test-harness-lwc-and-tab)

</HeroLoop>

## Streaming Event Monitor

Subscribe to platform events, Change Data Capture, and custom channels, then watch messages land on a live timeline. Publish test events from the same screen.

See event-driven work that's normally invisible without standing up your own streaming infrastructure (a CometD client) or a separate subscriber app. Publish an event and watch it arrive the moment it's sent, with its full payload.

<HeroLoop src="/recordings/streaming-monitor.webm" mp4="/recordings/streaming-monitor.mp4" poster="/recordings/streaming-monitor-poster.jpg" caption="Subscribe to a channel, publish an event, and watch it arrive." guide="/lwc-guide" guideLabel="LWC Guide">

[Watch this walkthrough on the live docs site](https://docs.jvb-consulting.io/administration-tools-guide#streaming-event-monitor) · [Read the full write-up in the LWC Guide](https://docs.jvb-consulting.io/lwc-guide#streamingmonitor-event-monitoring)

</HeroLoop>

## Chain Monitor

Follow an async chain step by step: each step's status, timing, and any error on one timeline.

When a multi-step async job fails, the platform barely tells you which step broke or how far it got. The Chain Monitor lays out every step and shows exactly where it stopped.

<HeroLoop src="/recordings/chain-monitor.webm" mp4="/recordings/chain-monitor.mp4" poster="/recordings/chain-monitor-poster.jpg" caption="Open a failed run and see exactly which step broke, and why." guide="/lwc-guide#chain-monitor-components" guideLabel="LWC Guide">

[Watch this walkthrough on the live docs site](https://docs.jvb-consulting.io/administration-tools-guide#chain-monitor) · [Read the full write-up in the LWC Guide](https://docs.jvb-consulting.io/lwc-guide#chain-monitor-components) · [Async chains in the Async Processing Guide](https://docs.jvb-consulting.io/async-processing-guide#monitoring-async-chain-failures)

</HeroLoop>

## Data Masking Advisor

Scan your objects for sensitive fields, see what's already masked, and build a deployable masking configuration.

Skip the manual audit and hand-written rules: the advisor finds likely-sensitive fields for you and assembles a masking package you can deploy, so those fields are redacted as records are written.

<HeroLoop src="/recordings/masking-advisor.webm" mp4="/recordings/masking-advisor.mp4" poster="/recordings/masking-advisor-poster.jpg" caption="Scan for sensitive fields, then drill into an object to see what to mask." guide="/data-masking-guide" guideLabel="Data Masking Guide">

[Watch this walkthrough on the live docs site](https://docs.jvb-consulting.io/administration-tools-guide#data-masking-advisor) · [Read the full write-up in the Data Masking Guide](https://docs.jvb-consulting.io/data-masking-guide#the-data-masking-advisor)

</HeroLoop>
