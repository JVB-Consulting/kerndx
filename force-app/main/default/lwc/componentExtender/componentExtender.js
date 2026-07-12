// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Module activation engine for the ComponentBuilder framework. Maps module
 * identifiers to their initialiser functions and wires them onto a BaseComponent instance.
 *
 * @author Jason van Beukering
 *
 * @date February 2022, May 2026
 */
// noinspection JSUnusedGlobalSymbols

import initialiseControllerModule from 'c/moduleController';
import initialiseFlowNavigationModule from 'c/moduleFlowNavigation';
import initialiseLightningMessageModule from 'c/moduleLightningMessageService';
import initialiseNavigationModule from 'c/moduleNavigation';
import initialiseNotificationModule from 'c/moduleNotification';

/** @description Sentinel value requesting every available module (duplicated from componentBuilder to avoid circular dependency). */
const ALL_MODULES = 'all';

/** @description Error guidance when an unrecognised module identifier is supplied. */
		// Developer-only invariant: thrown at class-composition time for a bad module identifier —
		// never reachable from subscriber interaction.
		// eslint-disable-next-line kerndx/no-hardcoded-user-text
const INVALID_INITIALISATION_ERROR = 'Verify that the module identifiers passed to ComponentBuilder are valid';

// ── Module Registry ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Maps each module identifier to its initialiser function.
 * @type {Readonly<Map<string, function(Object): void>>}
 * @private
 */
const MODULE_INITIALISERS = new Map([
	[
		'navigation',
		initialiseNavigationModule
	],
	[
		'notification',
		initialiseNotificationModule
	],
	[
		'lightning-message',
		initialiseLightningMessageModule
	],
	[
		'controller',
		initialiseControllerModule
	],
	[
		'flow-navigation',
		initialiseFlowNavigationModule
	]
]);

// ── Public API ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Convenience entry point for activating modules on an existing component
 * instance. Deduplicates the requested identifiers before delegating to {@link activateModules}.
 *
 * @param {Object} component The component instance to enhance
 * @param {...('all'|'navigation'|'notification'|'lightning-message'|'controller'|'flow-navigation')} requestedModules
 *     Module identifiers to activate
 *
 * @example
 * import {componentExtender} from 'c/componentExtender';
 * componentExtender(this, 'navigation', 'controller');
 */
export function componentExtender(component, ...requestedModules)
{
	const uniqueModules = new Set(requestedModules);
	const resolved = uniqueModules.has(ALL_MODULES) ? [ALL_MODULES] : [...uniqueModules];
	activateModules(component, resolved);
}

/**
 * @description Activates the specified modules on a component instance by invoking each
 * module's initialiser function. When 'all' is included, every registered module is activated.
 *
 * @param {Object} component The component instance to enhance
 * @param {('all'|'navigation'|'notification'|'lightning-message'|'controller'|'flow-navigation')[]} moduleIdentifiers
 *     Resolved list of module identifiers to activate
 * @throws {Error} When an unrecognised module identifier is encountered
 */
export function activateModules(component, moduleIdentifiers)
{
	for(const identifier of moduleIdentifiers)
	{
		if(identifier === ALL_MODULES)
		{
			activateAllModules(component);
			return;
		}

		const initialiser = MODULE_INITIALISERS.get(identifier);

		if(!initialiser)
		{
			// Developer-only invariant: composition-time failure for a bad module identifier.
			// eslint-disable-next-line kerndx/no-hardcoded-user-text
			throw new Error(`Invalid initialisation value: '${identifier}'. ${INVALID_INITIALISATION_ERROR}.`);
		}

		initialiser(component);
	}
}

/**
 * @description Activates every registered module on the component.
 *
 * @param {Object} component The component instance to enhance
 * @private
 */
function activateAllModules(component)
{
	for(const initialiser of MODULE_INITIALISERS.values())
	{
		initialiser(component);
	}
}