// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Factory that produces a BaseComponent subclass wired with the requested
 * module capabilities. Accepts one or more module identifiers and returns a class
 * constructor with those modules activated.
 *
 * @author Jason van Beukering
 *
 * @date February 2022, May 2026
 */
import BaseComponent from 'c/baseComponent';
import {activateModules} from 'c/componentExtender';

/** @description Sentinel value requesting every available module. */
		// noinspection JSUnusedGlobalSymbols - exported for external use
export const ALL_MODULES = 'all';

/** @description Error guidance when an unrecognised module identifier is supplied. */
		// noinspection JSUnusedGlobalSymbols - exported for external use
		// Developer-only invariant: thrown at class-composition time for a bad module identifier —
		// never reachable from subscriber interaction.
		// eslint-disable-next-line kerndx/no-hardcoded-user-text
export const INVALID_INITIALISATION_ERROR = 'Verify that the module identifiers passed to ComponentBuilder are valid';

/**
 * @description Creates a dynamic subclass of BaseComponent with the specified modules activated.
 *
 * @param {...('all'|'navigation'|'notification'|'lightning-message'|'controller'|'flow-navigation')} requestedModules
 *     One or more module identifiers to activate on the returned class.
 * @returns {typeof BaseComponent} A class constructor extending BaseComponent with the requested modules.
 * @constructor
 *
 * @example
 * export default class MyComponent extends ComponentBuilder('notification'){}
 * export default class MyComponent extends ComponentBuilder('notification', 'controller'){}
 * export default class MyComponent extends ComponentBuilder('all'){}
 */
		// noinspection JSUnusedGlobalSymbols - exported factory function
		// @ts-ignore - Dynamic class factory pattern with rest parameters
export const ComponentBuilder = (...requestedModules) => class extends BaseComponent
		{
			constructor()
			{
				super();
				const uniqueModules = new Set(requestedModules);
				// @ts-ignore - Set iteration produces strings, BaseComponent expects specific literals
				this.functionality = uniqueModules.has(ALL_MODULES) ? [ALL_MODULES] : [...uniqueModules];
				// @ts-ignore - functionality array validated at runtime
				activateModules(this, this.functionality);
			}
		};