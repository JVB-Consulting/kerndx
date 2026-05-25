// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for notice LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcNotice from 'c/notice';

describe('c-notice', () =>
{
	afterEach(() =>
	{
		// Clean up DOM after each test
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
	});

	describe('rendering', () =>
	{
		it('should render component successfully', () =>
		{
			const element = createElement('c-notice', {
				is: LwcNotice
			});
			document.body.appendChild(element);

			expect(element.tagName.toLowerCase()).toBe('c-notice');
			expect(element.shadowRoot).not.toBeNull();
			expect(element.shadowRoot.childElementCount).toBeGreaterThan(0);
		});

		it('should render lightning-icon with info icon', () =>
		{
			const element = createElement('c-notice', {
				is: LwcNotice
			});
			document.body.appendChild(element);

			const icon = element.shadowRoot.querySelector('lightning-icon');
			expect(icon).toBeTruthy();
			expect(icon.iconName).toBe('utility:info');
			expect(icon.size).toBe('small');
			expect(icon.alternativeText).toBe('Info icon');
		});

		it('should render slot for content', () =>
		{
			const element = createElement('c-notice', {
				is: LwcNotice
			});
			document.body.appendChild(element);

			const slot = element.shadowRoot.querySelector('slot');
			expect(slot).toBeTruthy();
		});

		it('should have SLDS media container structure', () =>
		{
			const element = createElement('c-notice', {
				is: LwcNotice
			});
			document.body.appendChild(element);

			const mediaContainer = element.shadowRoot.querySelector('.slds-media');
			expect(mediaContainer).toBeTruthy();
			expect(mediaContainer.classList.contains('slds-media_center')).toBe(true);

			const figure = element.shadowRoot.querySelector('.slds-media__figure');
			expect(figure).toBeTruthy();

			const body = element.shadowRoot.querySelector('.slds-media__body');
			expect(body).toBeTruthy();
		});
	});
});
