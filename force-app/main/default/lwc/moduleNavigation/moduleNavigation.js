// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Navigation module for the ComponentBuilder framework. Provides record page
 * redirection and URL generation via the Lightning NavigationMixin.
 *
 * @author Jason van Beukering
 *
 * @date February 2022, May 2026
 */

		// ── Constants ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

export const STANDARD_RECORD_PAGE_PAGE_REFERENCE_TYPE = 'standard__recordPage';
export const VIEW_ACTION_NAME = 'view';

// ── Internal Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Builds a PageReference object for a standard record page view.
 *
 * @param {string} recordId The ID of the record to navigate to
 * @returns {Object} A Lightning PageReference descriptor
 */
export const getStandardRecordPageReference = (recordId) => ({
	type: STANDARD_RECORD_PAGE_PAGE_REFERENCE_TYPE, attributes: {recordId, actionName: VIEW_ACTION_NAME}
});

// ── Module Initialisers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Wires the `redirectToRecordPage` method onto a component instance.
 * Navigates directly to the specified record's detail page.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialiseRedirectToRecordPage = function(component)
{
	/** @param {string} recordId */
	component.redirectToRecordPage = function(recordId)
	{
		component.navigationHandler(getStandardRecordPageReference(recordId));
	};
};

/**
 * @description Wires the `generateRecordPageURL` method onto a component instance.
 * Returns a promise resolving to the URL for a record's detail page.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export const initialiseGenerateRecordPageURL = function(component)
{
	/** @param {string} recordId */
	component.generateRecordPageURL = function(recordId)
	{
		return component.generateUrlHandler(getStandardRecordPageReference(recordId));
	};
};

// ── Default Export ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Activates the navigation module on a BaseComponent instance,
 * wiring both `redirectToRecordPage` and `generateRecordPageURL`.
 *
 * @param {Object} component The BaseComponent instance to enhance
 */
export default function initialiseNavigationModule(component)
{
	initialiseRedirectToRecordPage(component);
	initialiseGenerateRecordPageURL(component);
}