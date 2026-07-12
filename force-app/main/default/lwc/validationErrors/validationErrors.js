// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Component for displaying validation errors and warnings from the Validation Framework.
 * Use in Screen Flows after calling FLOW_ExecuteValidationRules to display user-friendly error messages.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, May 2026
 */
import ERROR_TITLE from '@salesforce/label/c.ValidationErrors_ErrorTitle';
import WARNING_TITLE from '@salesforce/label/c.ValidationErrors_WarningTitle';
import {api, LightningElement} from 'lwc';

// ── Constants ────────────────────────────────────────────────────────────

/**
 * @description Severity constant for errors
 * @type {string}
 */
const SEVERITY_ERROR = 'Error';

/**
 * @description Severity constant for warnings
 * @type {string}
 */
const SEVERITY_WARNING = 'Warning';

/**
 * @description Ordered selector templates used by `focusField` to locate a form element
 * in the parent DOM. Each template contains a `{0}` placeholder replaced with the field
 * API name at runtime.
 * @type {string[]}
 */
const FIELD_FOCUS_SELECTORS = [
	'[data-id="{0}"]',
	'[name="{0}"]',
	'[data-field="{0}"]',
	'lightning-input[data-id="{0}"]',
	'lightning-combobox[data-id="{0}"]',
	'lightning-textarea[data-id="{0}"]'
];

// ── Helper Functions ─────────────────────────────────────────────────────

/**
 * @description Composes a display message from an error object by assembling parts in
 * order: shadow indicator, field name prefix, message body, and rule name suffix.
 * @param {Object} error - The error object
 * @param {boolean} showFieldNames - Whether to prepend the field name
 * @param {boolean} showRuleNames - Whether to append the rule name
 * @returns {string} Formatted display message
 */
function composeDisplayMessage(error, showFieldNames, showRuleNames)
{
	if(!error?.message)
	{
		return '';
	}

	const parts = [];

	if(error.isShadowMode)
	{
		parts.push('[SHADOW]');
	}
	if(showFieldNames && error.fieldName)
	{
		parts.push(`${error.fieldName}:`);
	}
	parts.push(error.message);
	if(showRuleNames && error.ruleName)
	{
		parts.push(`[${error.ruleName}]`);
	}

	return parts.join(' ');
}

/**
 * @description Builds a display item for a single error/warning, including a unique key,
 * formatted message, and the CSS class for the list item element.
 * @param {Object} error - Raw error object
 * @param {string} severity - 'Error' or 'Warning'
 * @param {number} index - Position in the list, used for key generation
 * @param {boolean} showFieldNames - Whether field names are visible
 * @param {boolean} showRuleNames - Whether rule names are visible
 * @returns {Object} Display item with key, message, and CSS class
 */
function buildDisplayItem(error, severity, index, showFieldNames, showRuleNames)
{
	const hasFieldLink = Boolean(error.fieldName);
	return {
		key: `${severity}-${index}-${error.ruleName || 'unknown'}`,
		message: composeDisplayMessage(error, showFieldNames, showRuleNames),
		ruleName: error.ruleName,
		fieldName: error.fieldName,
		isShadowMode: error.isShadowMode || false,
		listItemClass: resolveListItemClass(severity, hasFieldLink)
	};
}

/**
 * @description Resolves the CSS class string for an error/warning list item based on
 * severity and whether the item links to a field.
 * @param {string} severity - 'Error' or 'Warning'
 * @param {boolean} hasFieldLink - Whether the item has a navigable field
 * @returns {string} CSS class string
 */
function resolveListItemClass(severity, hasFieldLink)
{
	const baseClass = severity === SEVERITY_ERROR ? 'slds-text-color_inverse' : '';
	return hasFieldLink ? `${baseClass} clickable-error`.trim() : baseClass;
}

// ── Component ────────────────────────────────────────────────────────────

// noinspection JSUnusedGlobalSymbols - LWC framework uses these
// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class ValidationErrors extends LightningElement
{
	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Array of error objects to display. Each object should have: message, fieldName (optional), severity, ruleName
	 * @type {Array}
	 */
	@api errors = [];

	/**
	 * @description Array of warning objects to display. Same structure as errors.
	 * @type {Array}
	 */
	@api warnings = [];

	/**
	 * @description Title for the errors section
	 * @type {string}
	 */
	@api errorTitle = ERROR_TITLE;

	/**
	 * @description Title for the warnings section
	 * @type {string}
	 */
	@api warningTitle = WARNING_TITLE;

	/**
	 * @description Whether to show rule names (for debugging)
	 * @type {boolean}
	 */
	@api showRuleNames = false;

	// ── Internal State ───────────────────────────────────────────────────

	/**
	 * @description Whether to show field names with error messages. Default is true (achieved via getter).
	 * @type {boolean}
	 */
	fieldNamesVisibility;

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Whether to show field names with error messages. Defaults to true when not explicitly set to false.
	 * @type {boolean}
	 */
	@api get showFieldNames()
	{
		return this.fieldNamesVisibility !== false;
	}

	set showFieldNames(value)
	{
		this.fieldNamesVisibility = value;
	}

	/**
	 * @description Returns true if there are errors to display
	 * @returns {boolean}
	 */
	get hasErrors()
	{
		return this.displayErrors?.length > 0;
	}

	/**
	 * @description Returns true if there are warnings to display
	 * @returns {boolean}
	 */
	get hasWarnings()
	{
		return this.displayWarnings?.length > 0;
	}

	/**
	 * @description Returns true if there is any content to display
	 * @returns {boolean}
	 */
	get hasContent()
	{
		return this.hasErrors || this.hasWarnings;
	}

	/**
	 * @description Processes errors array for display, adding unique keys
	 * @returns {Array}
	 */
	get displayErrors()
	{
		return this.processErrorsForDisplay(this.errors, SEVERITY_ERROR);
	}

	/**
	 * @description Processes warnings array for display, adding unique keys
	 * @returns {Array}
	 */
	get displayWarnings()
	{
		return this.processErrorsForDisplay(this.warnings, SEVERITY_WARNING);
	}

	// ── Methods ──────────────────────────────────────────────────────────

	/**
	 * @description Processes an array of errors for display
	 * @param {Array} errorArray - The errors to process
	 * @param {string} severity - The severity level
	 * @returns {Array} Processed array with display properties
	 */
	// noinspection FunctionWithMultipleReturnPointsJS - Early return for guard clause is clearer
	processErrorsForDisplay(errorArray, severity)
	{
		if(!errorArray || !Array.isArray(errorArray))
		{
			return [];
		}

		return errorArray.map((error, index) => buildDisplayItem(error, severity, index, this.showFieldNames, this.showRuleNames));
	}

	/**
	 * @description Handles click on error message to navigate to the associated field
	 * @param {Event} event - Click event from the error list item
	 */
	handleErrorClick(event)
	{
		const fieldName = event.currentTarget.dataset.fieldName;
		if(!fieldName)
		{
			return;
		}

		this.dispatchEvent(new CustomEvent('fieldclick', {
			detail: {fieldName}, bubbles: true, composed: true
		}));

		this.focusField(fieldName);
	}

	/**
	 * @description Attempts to focus on a field by name using various selectors
	 * @param {string} fieldName - API name of the field to focus
	 */
	focusField(fieldName)
	{
		const selectors = FIELD_FOCUS_SELECTORS.map((template) => template.replace('{0}', fieldName));

		for(const selector of selectors)
		{
			// eslint-disable-next-line @lwc/lwc/no-document-query -- must reach outside shadow DOM to focus fields in parent Flow
			const element = document.querySelector(selector);
			if(element)
			{
				element.scrollIntoView({behavior: 'smooth', block: 'center'});
				element.focus?.();
				break;
			}
		}
	}
}