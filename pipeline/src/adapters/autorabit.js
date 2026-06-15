// SPDX-License-Identifier: MIT
'use strict';
// Source: AutoRABIT Knowledge Base — Branching Strategy & CI/CD Pipeline
//   (https://knowledgebase.autorabit.com/product-guides/arm/troubleshoot/best-practices/branching-strategy-and-ci-cd-pipeline)
//   + Version Control Best Practices. Retrieved 2026-05-15 via Phase 0.3.
// See pipeline/docs/adapters/_autorabit-source.md for the full snapshot + design rationale.
//
// Status: EXPERIMENTAL (requires `experimental: true` ack) — but Phase 0.3 finding is that
// AutoRABIT has NO PR-interception convention. It performs direct merges via its CI/CD UI
// (merge types: "Entire Branch", "Single Revision", "Commit Label", "Release Label"). No
// branch prefix exists for the gate to skip on, so this adapter is effectively `none`.
//
// Shipped as a named adapter so subscribers can declare `ci_adapter: { name: autorabit }`
// for discoverability. Future revisions may add subscriber-specific skip patterns via the
// `custom` adapter shape if AutoRABIT subscribers report patterns we missed.

const none = require('./none.js');

function build(_adapterConfig, _branches)
{
	const inner = none.build();
	return {...inner, name: 'autorabit'};
}

module.exports = {build};
