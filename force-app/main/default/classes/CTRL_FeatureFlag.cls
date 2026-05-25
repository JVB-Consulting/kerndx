// SPDX-License-Identifier: BUSL-1.1
/**
 * @description LWC bridge to `UTIL_FeatureFlag.isEnabled(String)` for the running user. Exposes
 * a single `@AuraEnabled(cacheable=true)` method so subscriber LWCs can branch on feature flag
 * state without hand-rolling per-component controller wrappers. Pair with the `c/featureFlag`
 * LWC utility module (`isFlagEnabled(flagName)`) for the idiomatic call site.
 *
 * @see UTIL_FeatureFlag
 * @see CTRL_FeatureFlag_TEST
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date May 2026
 *
 * @since 1.0
 *
 * @example
 * ```javascript
 * import {isFlagEnabled} from 'c/featureFlag';
 * const enabled = await isFlagEnabled('NewCheckout_Enabled');
 * ```
 */
public with sharing class CTRL_FeatureFlag
{
	/**
	 * @description Returns whether the supplied feature flag is enabled for the running user.
	 * Resolves through `UTIL_FeatureFlag.isEnabled(String)` so the same evaluation chain that
	 * Apex consumers see (`SEL_FeatureFlag.activeFlags` cache → strategies → result-on-no-match)
	 * is applied for LWC consumers too.
	 *
	 * Annotated `cacheable=true` so the LWC `@wire` adapter can serve cached responses keyed by
	 * `(user session, flagName)` — direct cross-user contamination is not a risk because the LDS
	 * cache key includes the user session. However, when an admin grants or revokes a permission
	 * set that flips a flag's strategy match for a user, the user's LWC client continues to serve
	 * the previously-cached value until either page reload OR the wire adapter fires with new
	 * parameters (it doesn't — `flagName` is constant). Subscribers must not use the LWC bridge
	 * for client-side authorization gates that need to react to runtime permission changes within
	 * a session; Apex enforcement is the authoritative authorization layer. The bridge is
	 * appropriate for UX-shaping decisions (which panel to render, hint chip visibility).
	 *
	 * @param flagName The DeveloperName of the `FeatureFlag__mdt` record to evaluate.
	 *
	 * @return `true` when the flag resolves to enabled for the running user; `false` otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```javascript
	 * import isEnabled from '@salesforce/apex/CTRL_FeatureFlag.isEnabled';
	 * const result = await isEnabled({flagName: 'NewCheckout_Enabled'});
	 * ```
	 */
	@AuraEnabled(Cacheable=true)
	public static Boolean isEnabled(String flagName)
	{
		return UTIL_FeatureFlag.isEnabled(flagName);
	}
}