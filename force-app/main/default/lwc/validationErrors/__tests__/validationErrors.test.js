// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for validationErrors LWC component
 * @author Jason van Beukering
 * @date January 2026, May 2026
 */
import {createElement} from 'lwc';
import LwcValidationErrors from 'c/validationErrors';

describe('validationErrors', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
	});

	/**
	 * @description Helper function to create the component
	 * @param {Object} props - Properties to set on the component
	 * @returns {HTMLElement} The created element
	 */
	function createComponent(props = {})
	{
		const element = createElement('c-validation-errors', {
			is: LwcValidationErrors
		});

		Object.assign(element, props);
		document.body.appendChild(element);
		return element;
	}

	/**
	 * @description Helper to wait for DOM updates
	 * @returns {Promise}
	 */
	async function flushPromises()
	{
		return Promise.resolve();
	}

	describe('rendering with no data', () =>
	{
		it('should render without errors when no data provided', async() =>
		{
			const element = createComponent();
			await flushPromises();

			expect(element.shadowRoot.querySelector('.slds-box')).toBeNull();
		});

		it('should render nothing when errors and warnings are empty arrays', async() =>
		{
			const element = createComponent({
				errors: [], warnings: []
			});
			await flushPromises();

			expect(element.shadowRoot.querySelector('.slds-box')).toBeNull();
		});

		it('should handle null errors gracefully', async() =>
		{
			const element = createComponent({
				errors: null, warnings: null
			});
			await flushPromises();

			expect(element.shadowRoot.querySelector('.slds-box')).toBeNull();
		});

		it('should handle undefined errors gracefully', async() =>
		{
			const element = createComponent({
				errors: undefined, warnings: undefined
			});
			await flushPromises();

			expect(element.shadowRoot.querySelector('.slds-box')).toBeNull();
		});
	});

	describe('rendering errors', () =>
	{
		it('should render error section when errors exist', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Test error', ruleName: 'TestRule'}]
			});
			await flushPromises();

			const errorBox = element.shadowRoot.querySelector('.slds-theme_error');
			expect(errorBox).not.toBeNull();
		});

		it('should display error message in list', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Account name is required', ruleName: 'RequireName'}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('Account name is required');
		});

		it('should display multiple errors', async() =>
		{
			const element = createComponent({
				errors: [
					{message: 'Error 1', ruleName: 'Rule1'},
					{message: 'Error 2', ruleName: 'Rule2'},
					{message: 'Error 3', ruleName: 'Rule3'}
				]
			});
			await flushPromises();

			const listItems = element.shadowRoot.querySelectorAll('.slds-theme_error li');
			expect(listItems.length).toBe(3);
		});

		it('should display custom error title', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Test', ruleName: 'Test'}], errorTitle: 'Custom Error Title'
			});
			await flushPromises();

			const title = element.shadowRoot.querySelector('.slds-theme_error h2');
			expect(title.textContent).toBe('Custom Error Title');
		});

		it('should use default error title', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Test', ruleName: 'Test'}]
			});
			await flushPromises();

			const title = element.shadowRoot.querySelector('.slds-theme_error h2');
			expect(title.textContent).toBe('Validation Errors');
		});
	});

	describe('rendering warnings', () =>
	{
		it('should render warning section when warnings exist', async() =>
		{
			const element = createComponent({
				warnings: [{message: 'Test warning', ruleName: 'TestRule'}]
			});
			await flushPromises();

			const warningBox = element.shadowRoot.querySelector('.slds-theme_warning');
			expect(warningBox).not.toBeNull();
		});

		it('should display warning message in list', async() =>
		{
			const element = createComponent({
				warnings: [{message: 'Consider adding a description', ruleName: 'SuggestDescription'}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_warning li');
			expect(listItem.textContent).toBe('Consider adding a description');
		});

		it('should display custom warning title', async() =>
		{
			const element = createComponent({
				warnings: [{message: 'Test', ruleName: 'Test'}], warningTitle: 'Custom Warning Title'
			});
			await flushPromises();

			const title = element.shadowRoot.querySelector('.slds-theme_warning h2');
			expect(title.textContent).toBe('Custom Warning Title');
		});
	});

	describe('rendering both errors and warnings', () =>
	{
		it('should render both sections when both exist', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error message', ruleName: 'ErrorRule'}], warnings: [{message: 'Warning message', ruleName: 'WarningRule'}]
			});
			await flushPromises();

			const errorBox = element.shadowRoot.querySelector('.slds-theme_error');
			const warningBox = element.shadowRoot.querySelector('.slds-theme_warning');
			expect(errorBox).not.toBeNull();
			expect(warningBox).not.toBeNull();
		});

		it('should only render error section when no warnings', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error', ruleName: 'Rule'}], warnings: []
			});
			await flushPromises();

			const errorBox = element.shadowRoot.querySelector('.slds-theme_error');
			const warningBox = element.shadowRoot.querySelector('.slds-theme_warning');
			expect(errorBox).not.toBeNull();
			expect(warningBox).toBeNull();
		});

		it('should only render warning section when no errors', async() =>
		{
			const element = createComponent({
				errors: [], warnings: [{message: 'Warning', ruleName: 'Rule'}]
			});
			await flushPromises();

			const errorBox = element.shadowRoot.querySelector('.slds-theme_error');
			const warningBox = element.shadowRoot.querySelector('.slds-theme_warning');
			expect(errorBox).toBeNull();
			expect(warningBox).not.toBeNull();
		});
	});

	describe('field name display', () =>
	{
		it('should show field name when showFieldNames is true', async() =>
		{
			const element = createComponent({
				errors: [{message: 'is required', fieldName: 'Name', ruleName: 'Rule'}], showFieldNames: true
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('Name: is required');
		});

		it('should not show field name when showFieldNames is false', async() =>
		{
			const element = createComponent({
				errors: [{message: 'is required', fieldName: 'Name', ruleName: 'Rule'}], showFieldNames: false
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('is required');
		});

		it('should handle missing field name gracefully', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Page level error', ruleName: 'Rule'}], showFieldNames: true
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('Page level error');
		});
	});

	describe('rule name display', () =>
	{
		it('should show rule name when showRuleNames is true', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error occurred', ruleName: 'Account_Validation'}], showRuleNames: true
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('Error occurred [Account_Validation]');
		});

		it('should not show rule name when showRuleNames is false', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error occurred', ruleName: 'Account_Validation'}], showRuleNames: false
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('Error occurred');
		});
	});

	describe('shadow mode indicator', () =>
	{
		it('should show SHADOW prefix for shadow mode errors', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Would fail', ruleName: 'Rule', isShadowMode: true}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('[SHADOW] Would fail');
		});

		it('should not show SHADOW prefix when not in shadow mode', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Real error', ruleName: 'Rule', isShadowMode: false}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('Real error');
		});
	});

	describe('combined formatting', () =>
	{
		it('should combine field name, message, rule name, and shadow mode', async() =>
		{
			const element = createComponent({
				errors: [
					{
						message: 'cannot be blank', fieldName: 'Name', ruleName: 'RequireName', isShadowMode: true
					}
				], showFieldNames: true, showRuleNames: true
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('[SHADOW] Name: cannot be blank [RequireName]');
		});
	});

	describe('content visibility (via DOM)', () =>
	{
		it('should show error section when errors exist', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error', ruleName: 'Rule'}]
			});
			await flushPromises();

			// hasErrors returns true - verified via DOM
			expect(element.shadowRoot.querySelector('.slds-theme_error')).not.toBeNull();
		});

		it('should not show error section when no errors', async() =>
		{
			const element = createComponent({
				errors: []
			});
			await flushPromises();

			// hasErrors returns false - verified via DOM
			expect(element.shadowRoot.querySelector('.slds-theme_error')).toBeNull();
		});

		it('should show warning section when warnings exist', async() =>
		{
			const element = createComponent({
				warnings: [{message: 'Warning', ruleName: 'Rule'}]
			});
			await flushPromises();

			// hasWarnings returns true - verified via DOM
			expect(element.shadowRoot.querySelector('.slds-theme_warning')).not.toBeNull();
		});

		it('should not show warning section when no warnings', async() =>
		{
			const element = createComponent({
				warnings: []
			});
			await flushPromises();

			// hasWarnings returns false - verified via DOM
			expect(element.shadowRoot.querySelector('.slds-theme_warning')).toBeNull();
		});

		it('should show content when errors exist', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error', ruleName: 'Rule'}]
			});
			await flushPromises();

			// hasContent returns true - verified via DOM
			expect(element.shadowRoot.querySelector('.slds-box')).not.toBeNull();
		});

		it('should show content when warnings exist', async() =>
		{
			const element = createComponent({
				warnings: [{message: 'Warning', ruleName: 'Rule'}]
			});
			await flushPromises();

			// hasContent returns true - verified via DOM
			expect(element.shadowRoot.querySelector('.slds-box')).not.toBeNull();
		});

		it('should not show any content when nothing exists', async() =>
		{
			const element = createComponent({
				errors: [], warnings: []
			});
			await flushPromises();

			// hasContent returns false - verified via DOM
			expect(element.shadowRoot.querySelector('.slds-box')).toBeNull();
		});
	});

	describe('edge cases', () =>
	{
		it('should handle error with empty message', async() =>
		{
			const element = createComponent({
				errors: [{message: '', ruleName: 'Rule'}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('');
		});

		it('should handle error without message property', async() =>
		{
			const element = createComponent({
				errors: [{ruleName: 'Rule'}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('');
		});

		it('should generate unique keys for list items', async() =>
		{
			const element = createComponent({
				errors: [
					{message: 'Error 1', ruleName: 'Rule1'},
					{message: 'Error 2', ruleName: 'Rule2'}
				]
			});
			await flushPromises();

			const listItems = element.shadowRoot.querySelectorAll('.slds-theme_error li');
			expect(listItems.length).toBe(2);
			// Keys are internal, but items should render correctly
		});

		it('should handle error without ruleName property', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error without rule name'}]
			});
			await flushPromises();

			// Should render without error, using 'unknown' as fallback key
			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.textContent).toBe('Error without rule name');
		});
	});

	describe('click-to-navigate functionality', () =>
	{
		it('should apply clickable-error class when fieldName exists', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error with field', fieldName: 'TestField__c', ruleName: 'Rule1'}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.classList.contains('clickable-error')).toBe(true);
		});

		it('should not apply clickable-error class when fieldName is missing', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error without field', ruleName: 'Rule1'}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.classList.contains('clickable-error')).toBe(false);
		});

		it('should dispatch fieldclick event when error with fieldName is clicked', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error with field', fieldName: 'TestField__c', ruleName: 'Rule1'}]
			});
			await flushPromises();

			const handler = jest.fn();
			element.addEventListener('fieldclick', handler);

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			listItem.click();
			await flushPromises();

			expect(handler).toHaveBeenCalledTimes(1);
			expect(handler.mock.calls[0][0].detail.fieldName).toBe('TestField__c');
		});

		it('should not dispatch fieldclick event when error without fieldName is clicked', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error without field', ruleName: 'Rule1'}]
			});
			await flushPromises();

			const handler = jest.fn();
			element.addEventListener('fieldclick', handler);

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			listItem.click();
			await flushPromises();

			expect(handler).not.toHaveBeenCalled();
		});

		it('should store fieldName in data attribute', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error with field', fieldName: 'TestField__c', ruleName: 'Rule1'}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(listItem.dataset.fieldName).toBe('TestField__c');
		});

		it('should apply clickable-error class to warnings with fieldName', async() =>
		{
			const element = createComponent({
				warnings: [{message: 'Warning with field', fieldName: 'TestField__c', ruleName: 'Rule1'}]
			});
			await flushPromises();

			const listItem = element.shadowRoot.querySelector('.slds-theme_warning li');
			expect(listItem.classList.contains('clickable-error')).toBe(true);
		});
	});

	describe('focusField method', () =>
	{
		it('should scroll and focus element when found by data-id selector', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error', fieldName: 'TestField', ruleName: 'Rule'}]
			});
			await flushPromises();

			const mockInput = document.createElement('input');
			mockInput.setAttribute('data-id', 'TestField');
			mockInput.scrollIntoView = jest.fn();
			mockInput.focus = jest.fn();
			document.body.appendChild(mockInput);

			// Trigger focusField via the component's internal method
			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			listItem.click();
			await flushPromises();

			expect(mockInput.scrollIntoView).toHaveBeenCalledWith({behavior: 'smooth', block: 'center'});
			expect(mockInput.focus).toHaveBeenCalled();

			document.body.removeChild(mockInput);
		});

		it('should scroll and focus element when found by name selector', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error', fieldName: 'NamedField', ruleName: 'Rule'}]
			});
			await flushPromises();

			const mockInput = document.createElement('input');
			mockInput.setAttribute('name', 'NamedField');
			mockInput.scrollIntoView = jest.fn();
			mockInput.focus = jest.fn();
			document.body.appendChild(mockInput);

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			listItem.click();
			await flushPromises();

			expect(mockInput.scrollIntoView).toHaveBeenCalledWith({behavior: 'smooth', block: 'center'});
			expect(mockInput.focus).toHaveBeenCalled();

			document.body.removeChild(mockInput);
		});

		it('should scroll and focus element when found by data-field selector', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error', fieldName: 'DataField', ruleName: 'Rule'}]
			});
			await flushPromises();

			const mockInput = document.createElement('div');
			mockInput.setAttribute('data-field', 'DataField');
			mockInput.scrollIntoView = jest.fn();
			mockInput.focus = jest.fn();
			document.body.appendChild(mockInput);

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			listItem.click();
			await flushPromises();

			expect(mockInput.scrollIntoView).toHaveBeenCalledWith({behavior: 'smooth', block: 'center'});
			expect(mockInput.focus).toHaveBeenCalled();

			document.body.removeChild(mockInput);
		});

		it('should not throw when no matching element found', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error', fieldName: 'NonExistent', ruleName: 'Rule'}]
			});
			await flushPromises();

			// Click should not throw when no matching element exists
			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			expect(() => listItem.click()).not.toThrow();
		});

		it('should scroll element without focus when focus is not a function', async() =>
		{
			const element = createComponent({
				errors: [{message: 'Error', fieldName: 'NoFocusField', ruleName: 'Rule'}]
			});
			await flushPromises();

			const mockDiv = document.createElement('div');
			mockDiv.setAttribute('data-id', 'NoFocusField');
			mockDiv.scrollIntoView = jest.fn();
			// div.focus is already undefined/not a function in this context
			delete mockDiv.focus;
			document.body.appendChild(mockDiv);

			const listItem = element.shadowRoot.querySelector('.slds-theme_error li');
			listItem.click();
			await flushPromises();

			expect(mockDiv.scrollIntoView).toHaveBeenCalledWith({behavior: 'smooth', block: 'center'});

			document.body.removeChild(mockDiv);
		});
	});
});
