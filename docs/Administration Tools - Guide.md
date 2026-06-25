---
group: "Getting Started"
navOrder: 1
title: "Administration Tools"
---

# Administration Tools

## What problem does this solve?

Running and troubleshooting a Salesforce integration usually means cobbling together your own tooling: Postman for callouts, throwaway anonymous Apex, a CometD client to watch streaming events, and a hand-written audit to find sensitive fields. Most teams build or wire together that kit themselves, and then maintain it.

KernDX gives you four ready-made consoles in the **Kern** app instead. You fire inbound and outbound API calls from a form, watch events and async jobs arrive on a live timeline, and scan your objects for sensitive data, all without leaving the org.

They are for the admins, developers, and reviewers who run and troubleshoot a KernDX org day to day. Turn to them when you want to exercise or observe something that is normally invisible or fiddly to set up by hand.

## Mental model

Think of these consoles as the instrument panel on a dashboard. The engine (your integrations, events, and async jobs) runs the same with or without them, but the panel lets you see what is happening and prod it safely: send a test signal, watch a reading move, and find the warning lights, all without opening the bonnet.

## Use this when
- You want to test a real Apex callout or inbound endpoint without Postman, throwaway anonymous Apex, or leftover test data.
- You need to watch platform events, Change Data Capture, or a custom channel arrive live, with the full payload, rather than standing up your own streaming client.
- A multi-step async job has failed and you need to see which step broke and how far it got.
- You want to find likely-sensitive fields and turn them into a deployable masking configuration, instead of auditing by hand.

## Don't use this when
- The built-in Salesforce tools already cover your need. For a quick one-off callout the Developer Console or a REST client is enough, and the platform's Streaming Monitor and standard debug logs handle simple cases. Use the native option when it is sufficient; it is less to learn.
- You are not running a KernDX org. These consoles observe and exercise KernDX integrations, events, and async chains.

## The four consoles

These walkthroughs reflect the current released version of KernDX.

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
