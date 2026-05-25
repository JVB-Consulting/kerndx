// SPDX-License-Identifier: BUSL-1.1
/**
 * @file featureFlag.js
 * @module c/featureFlag
 *
 * @description LWC bridge to `UTIL_FeatureFlag.isEnabled(String)` via the cacheable
 * `CTRL_FeatureFlag.isEnabled` controller. Exposes a single async helper so subscriber
 * LWCs can branch on feature-flag state with the same evaluation chain Apex consumers
 * see (`SEL_FeatureFlag.activeFlags` cache → strategies → result-on-no-match).
 *
 * @author Jason van Beukering
 *
 * @date May 2026
 *
 * @group Feature Flags
 *
 * @example
 * import {isFlagEnabled} from 'c/featureFlag';
 *
 * async connectedCallback()
 * {
 *     this.checkoutEnabled = await isFlagEnabled('NewCheckout_Enabled');
 * }
 *
 * @exports isFlagEnabled
 */

import isEnabled from '@salesforce/apex/CTRL_FeatureFlag.isEnabled';

/**
 * @description Resolves to `true` when the named feature flag is enabled for the running
 * user; resolves to `false` otherwise. Errors from the controller propagate so callers
 * can fall back to a safe default explicitly via `try/catch` or `.catch()`.
 *
 * The bridge resolves through `CTRL_FeatureFlag.isEnabled` (`@AuraEnabled(cacheable=true)`)
 * so the LDS cache may serve stale results after a permission-set assignment / revocation
 * flips a flag's strategy match for the running user. The cache invalidates on page reload
 * but not on `@wire` re-fire (parameter is constant). Use this for UX-shaping decisions
 * (panel visibility, hint chips); do NOT use for client-side authorization gates that
 * must react to runtime permission changes within a session — Apex enforcement is the
 * authoritative authorization layer.
 *
 * @param {string} flagName The DeveloperName of the FeatureFlag__mdt record to evaluate
 * @returns {Promise<boolean>} Resolved flag state for the running user
 *
 * @example
 * const enabled = await isFlagEnabled('NewCheckout_Enabled');
 * if(enabled) { showNewCheckout(); }
 */
export const isFlagEnabled = (flagName) => isEnabled({flagName});