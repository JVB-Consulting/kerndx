// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for modal LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcModal from 'c/modal';

describe('c-modal', () =>
{
	let element;

	beforeEach(() =>
	{
		element = createElement('c-modal', {
			is: LwcModal
		});
		document.body.appendChild(element);
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	describe('initial state', () =>
	{
		it('should render component successfully', () =>
		{
			expect(element).toBeTruthy();
		});

		it('should be hidden by default', () =>
		{
			const modal = element.shadowRoot.querySelector('section');
			expect(modal.classList.contains('slds-hide')).toBe(true);
		});

		it('should have backdrop hidden by default', () =>
		{
			const backdrop = element.shadowRoot.querySelector('.slds-backdrop');
			expect(backdrop.classList.contains('slds-hide')).toBe(true);
		});
	});

	describe('@api title', () =>
	{
		it('should display title when provided', async() =>
		{
			element.title = 'Test Modal Title';

			await Promise.resolve();

			const titleEl = element.shadowRoot.querySelector('h2');
			expect(titleEl.textContent.trim()).toBe('Test Modal Title');
		});

		it('should apply empty header class when no title', async() =>
		{
			element.title = '';

			await Promise.resolve();

			const header = element.shadowRoot.querySelector('header');
			expect(header.classList.contains('slds-modal__header--empty')).toBe(true);
		});

		it('should not apply empty header class when title provided', async() =>
		{
			element.title = 'My Title';

			await Promise.resolve();

			const header = element.shadowRoot.querySelector('header');
			expect(header.classList.contains('slds-modal__header--empty')).toBe(false);
		});
	});

	describe('@api hideCloseIcon', () =>
	{
		it('should show close icon by default', () =>
		{
			const closeButton = element.shadowRoot.querySelector('lightning-button-icon');
			expect(closeButton).toBeTruthy();
		});

		it('should hide close icon when hideCloseIcon is true', async() =>
		{
			element.hideCloseIcon = true;

			await Promise.resolve();

			const closeButton = element.shadowRoot.querySelector('lightning-button-icon');
			expect(closeButton).toBeFalsy();
		});
	});

	describe('@api width', () =>
	{
		it('should apply width class when provided', async() =>
		{
			element.width = 'large';

			await Promise.resolve();

			const modal = element.shadowRoot.querySelector('section');
			expect(modal.classList.contains('slds-modal_large')).toBe(true);
		});

		it('should apply small width class', async() =>
		{
			element.width = 'small';

			await Promise.resolve();

			const modal = element.shadowRoot.querySelector('section');
			expect(modal.classList.contains('slds-modal_small')).toBe(true);
		});

		it('should not apply width class when not provided', () =>
		{
			const modal = element.shadowRoot.querySelector('section');
			expect(modal.className).not.toContain('slds-modal_');
		});
	});

	describe('@api isDirectional', () =>
	{
		it('should apply directional footer class when true', async() =>
		{
			element.isDirectional = true;

			await Promise.resolve();

			const footer = element.shadowRoot.querySelector('footer');
			expect(footer.classList.contains('slds-modal__footer_directional')).toBe(true);
		});

		it('should not apply directional footer class by default', () =>
		{
			const footer = element.shadowRoot.querySelector('footer');
			expect(footer.classList.contains('slds-modal__footer_directional')).toBe(false);
		});
	});

	describe('@api show()', () =>
	{
		it('should make modal visible when show() is called', async() =>
		{
			element.show();

			await Promise.resolve();

			const modal = element.shadowRoot.querySelector('section');
			expect(modal.classList.contains('slds-hide')).toBe(false);
		});

		it('should make backdrop visible when show() is called', async() =>
		{
			element.show();

			await Promise.resolve();

			const backdrop = element.shadowRoot.querySelector('.slds-backdrop');
			expect(backdrop.classList.contains('slds-hide')).toBe(false);
		});
	});

	describe('@api hide()', () =>
	{
		it('should hide modal when hide() is called', async() =>
		{
			element.show();
			await Promise.resolve();

			element.hide();
			await Promise.resolve();

			const modal = element.shadowRoot.querySelector('section');
			expect(modal.classList.contains('slds-hide')).toBe(true);
		});

		it('should hide backdrop when hide() is called', async() =>
		{
			element.show();
			await Promise.resolve();

			element.hide();
			await Promise.resolve();

			const backdrop = element.shadowRoot.querySelector('.slds-backdrop');
			expect(backdrop.classList.contains('slds-hide')).toBe(true);
		});
	});

	describe('handleCloseModal', () =>
	{
		it('should hide modal when close button clicked', async() =>
		{
			element.show();
			await Promise.resolve();

			const closeButton = element.shadowRoot.querySelector('lightning-button-icon');
			closeButton.click();
			await Promise.resolve();

			const modal = element.shadowRoot.querySelector('section');
			expect(modal.classList.contains('slds-hide')).toBe(true);
		});

		it('should dispatch close event when close button clicked', async() =>
		{
			const closeHandler = jest.fn();
			element.addEventListener('close', closeHandler);

			element.show();
			await Promise.resolve();

			const closeButton = element.shadowRoot.querySelector('lightning-button-icon');
			closeButton.click();
			await Promise.resolve();

			expect(closeHandler).toHaveBeenCalledTimes(1);
		});
	});

	describe('ESC key handling', () =>
	{
		it('should close modal on ESC key when visible', async() =>
		{
			element.show();
			await Promise.resolve();

			window.dispatchEvent(new KeyboardEvent('keyup', {code: 'Escape'}));
			await Promise.resolve();

			const modal = element.shadowRoot.querySelector('section');
			expect(modal.classList.contains('slds-hide')).toBe(true);
		});

		it('should dispatch close event on ESC key when visible', async() =>
		{
			const closeHandler = jest.fn();
			element.addEventListener('close', closeHandler);

			element.show();
			await Promise.resolve();

			window.dispatchEvent(new KeyboardEvent('keyup', {code: 'Escape'}));
			await Promise.resolve();

			expect(closeHandler).toHaveBeenCalledTimes(1);
		});

		it('should not close modal on ESC key when hidden', async() =>
		{
			const closeHandler = jest.fn();
			element.addEventListener('close', closeHandler);

			window.dispatchEvent(new KeyboardEvent('keyup', {code: 'Escape'}));
			await Promise.resolve();

			expect(closeHandler).not.toHaveBeenCalled();
		});

		it('should not close modal on other keys', async() =>
		{
			const closeHandler = jest.fn();
			element.addEventListener('close', closeHandler);

			element.show();
			await Promise.resolve();

			window.dispatchEvent(new KeyboardEvent('keyup', {code: 'Enter'}));
			await Promise.resolve();

			expect(closeHandler).not.toHaveBeenCalled();
		});
	});

	describe('slot handling', () =>
	{
		it('should show footer when footer slot has content', async() =>
		{
			const footerSlot = element.shadowRoot.querySelector('slot[name="footer"]');
			footerSlot.dispatchEvent(new CustomEvent('slotchange'));

			await Promise.resolve();

			const footer = element.shadowRoot.querySelector('footer');
			expect(footer.classList.contains('slds-hide')).toBe(false);
		});

		it('should hide footer by default', () =>
		{
			const footer = element.shadowRoot.querySelector('footer');
			expect(footer.classList.contains('slds-hide')).toBe(true);
		});

		it('should show tagline when tagline slot has content', async() =>
		{
			const taglineSlot = element.shadowRoot.querySelector('slot[name="tagline"]');
			taglineSlot.dispatchEvent(new CustomEvent('slotchange'));

			await Promise.resolve();

			const taglineP = element.shadowRoot.querySelector('header > p');
			expect(taglineP.classList.contains('slds-hide')).toBe(false);
		});
	});

	describe('disconnectedCallback', () =>
	{
		it('should remove keyup event listener on disconnect', () =>
		{
			const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');

			document.body.removeChild(element);

			expect(removeEventListenerSpy).toHaveBeenCalledWith('keyup', expect.any(Function));

			removeEventListenerSpy.mockRestore();
		});
	});

	describe('computed classes', () =>
	{
		it('should include slds-modal and slds-fade-in-open classes', () =>
		{
			const modal = element.shadowRoot.querySelector('section');
			expect(modal.classList.contains('slds-modal')).toBe(true);
			expect(modal.classList.contains('slds-fade-in-open')).toBe(true);
		});

		it('should include slds-backdrop and slds-backdrop--open classes', () =>
		{
			const backdrop = element.shadowRoot.querySelector('.slds-backdrop');
			expect(backdrop.classList.contains('slds-backdrop')).toBe(true);
			expect(backdrop.classList.contains('slds-backdrop--open')).toBe(true);
		});
	});
});
