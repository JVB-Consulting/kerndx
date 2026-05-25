// SPDX-License-Identifier: MIT
'use strict';
// Source: Copado Solutions Documentation (https://docs.copado.com/article/uljoaxa35z-promotion-overview
//   + https://docs.copado.com/article/b7ehmqfno5-back-promotion). Retrieved 2026-05-15 via Phase 0.2.
// See pipeline/docs/adapters/_copado-source.md for the full snapshot + regex derivation.
//
// Status: EXPERIMENTAL — regex verified against Copado public documentation, not yet validated
// on a real Copado subscriber's repo. Requires `experimental: true` in .kerndx/config.yml.
//
// Verified pattern (forward AND back-promotion both use this shape in Copado):
//   promotion/<PromotionRecordName>-DeployTo<DestinationEnvironment>
//   e.g., promotion/P0001-DeployToUAT, promotion/P0042-DeployToProduction
//
// This is more aggressive than Gearset's adapter (which only matches back-promotions). The
// behavior is still correct for the gate's purpose: any `promotion/*` branch in Copado has
// already been scanned at the feature-branch stage by the prior PR, so a re-scan at the
// promotion stage is redundant.

function build(_adapterConfig, _branches) {
	const promotionRe = /^promotion\/.+-DeployTo.+$/;
	return {
		name: 'copado',
		classifyHeadRef(headRef) {
			if (promotionRe.test(headRef)) return { action: 'skip-scan', label: 'back-promotion' };
			return { action: 'full-scan', label: 'normal' };
		},
	};
}

module.exports = { build };
