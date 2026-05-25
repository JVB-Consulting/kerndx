// SPDX-License-Identifier: BUSL-1.1
/**
 * @description LWC component that implements a fully reusable SLDS modal dialog.
 * Provides programmatic show/hide methods, ESC-key accessibility, dynamic slot
 * handling, configurable width, directional footer styles, and an optional
 * close icon. Emits a `close` event whenever the modal is dismissed.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, May 2026
 */
import {LightningElement, api} from 'lwc';

/**
 * @description Key code string for Escape key, used for accessibility-compliant dismissal.
 * @type {string}
 */
const ESCAPE_KEY_CODE = 'Escape';

/**
 * @description Builds a space-separated CSS class string from a base class and an array
 * of conditional class entries. Each entry is a `[className, condition]` tuple; the class
 * is included only when the condition is truthy.
 * @param {string} base - Always-present CSS class(es)
 * @param {Array<[string, boolean]>} conditionals - Tuples of [className, shouldInclude]
 * @returns {string} Composed class string
 */
function buildClassString(base, ...conditionals)
{
	const parts = [base];
	for(const [className, condition] of conditionals)
	{
		if(condition)
		{
			parts.push(className);
		}
	}
	return parts.join(' ');
}

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class Modal extends LightningElement
{
	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Title displayed in the modal header.
	 * If no title is provided, the header will render compact.
	 * @type {string}
	 */
	@api title;

	/**
	 * @description Hides the close icon in the modal header when set to true.
	 * Useful for modal flows where closing must be controlled externally.
	 * @type {boolean}
	 */
	@api hideCloseIcon;

	/**
	 * @description SLDS modal width modifier (e.g., "small", "medium", "large", "x-large").
	 * This maps to the SLDS class: slds-modal_{width}.
	 * @type {string}
	 */
	@api width;

	/**
	 * @description Enables the SLDS directional footer style when true.
	 * Directional footers position actions left/right with SLDS styling.
	 * @type {boolean}
	 */
	@api isDirectional;

	// ── Internal State ───────────────────────────────────────────────────

	/**
	 * @description Indicates visibility of the modal.
	 * Managed internally but can be toggled via `show()` or `hide()` public API.
	 * @type {boolean}
	 */
	isVisible = false;

	/**
	 * @description Tracks whether a footer slot has been populated with content.
	 * Controls the conditional rendering of the modal footer container.
	 * @type {boolean}
	 */
	footerSlotPopulated = false;

	/**
	 * @description Bound reference to the escape key listener for cleanup during disconnect.
	 * @type {Function}
	 */
	escapeKeyListener;

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Indicates if the close icon should be rendered.
	 * @returns {boolean}
	 */
	get showCloseIcon()
	{
		return !this.hideCloseIcon;
	}

	/**
	 * @description Computes full modal container classes based on width and visibility.
	 * @returns {string}
	 */
	get modalClass()
	{
		return buildClassString('slds-modal slds-fade-in-open', [
			'slds-modal_' + this.width,
			Boolean(this.width)
		], [
			'slds-hide',
			!this.isVisible
		]);
	}

	/**
	 * @description Computes the header styling class.
	 * If no title is provided, a compact SLDS header style is applied.
	 * @returns {string}
	 */
	get headerClass()
	{
		return buildClassString('slds-modal__header', [
			'slds-modal__header--empty',
			!this.title
		]);
	}

	/**
	 * @description Computes footer styling classes, including directional footer layout.
	 * Footer is hidden if no footer slot content is detected.
	 * @returns {string}
	 */
	get footerClass()
	{
		return buildClassString('slds-modal__footer', [
			'slds-hide',
			!this.footerSlotPopulated
		], [
			'slds-modal__footer_directional',
			Boolean(this.isDirectional)
		]);
	}

	/**
	 * @description Computes the backdrop class, controlling its visibility.
	 * @returns {string}
	 */
	get backdropClass()
	{
		return buildClassString('slds-backdrop slds-backdrop--open', [
			'slds-hide',
			!this.isVisible
		]);
	}

	// ── Public API ───────────────────────────────────────────────────────

	/**
	 * @description Public method used by parent components to open the modal.
	 */
	@api show()
	{
		this.isVisible = true;
	}

	/**
	 * @description Public method used by parent components to hide the modal.
	 */
	@api hide()
	{
		this.isVisible = false;
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Lifecycle hook executed when the component is inserted
	 * into the DOM. Registers a global ESC key listener to support
	 * accessibility-compliant modal dismissal.
	 */
	connectedCallback()
	{
		this.escapeKeyListener = ({code}) =>
		{
			if(this.isVisible && code === ESCAPE_KEY_CODE)
			{
				this.handleCloseModal();
			}
		};

		window.addEventListener('keyup', this.escapeKeyListener);
	}

	/**
	 * @description Lifecycle hook executed when the component is removed
	 * from the DOM. Cleans up the ESC key listener.
	 */
	disconnectedCallback()
	{
		window.removeEventListener('keyup', this.escapeKeyListener);
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Handles close icon click or ESC key press.
	 * Hides the modal and dispatches a `close` event to the parent.
	 */
	handleCloseModal()
	{
		this.hide();
		this.dispatchEvent(new CustomEvent('close'));
	}

	/**
	 * @description Triggered when the tagline slot receives content.
	 * Unhides the tagline container in the modal header.
	 */
	handleSlotTaglineChange()
	{
		const taglineEl = this.template.querySelector('header>p');
		taglineEl.classList.remove('slds-hide');
	}

	/**
	 * @description Triggered when the footer slot receives content.
	 * Enables rendering of the modal footer section.
	 */
	handleSlotFooterChange()
	{
		this.footerSlotPopulated = true;
	}
}