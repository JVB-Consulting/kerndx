// SPDX-License-Identifier: BUSL-1.1
import {createElement} from 'lwc';
import AccountCard from 'c/accountCard';

// Mock the managed-package base class. ComponentBuilder(...) must return a real class
// extending LightningElement, with the framework methods this component calls stubbed.
// Assign the stubs in the constructor, NOT as class fields: class fields on a
// LightningElement subclass make the LWC compiler inject a decorator-registration
// helper, and Jest's mock-factory hoist guard rejects that out-of-scope reference.
jest.mock('kern/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		const {LightningElement} = require('lwc');
		return class extends LightningElement
		{
			constructor()
			{
				super();
				this.callControllerMethod = jest.fn().mockResolvedValue({Name: 'Acme', Industry: 'Technology'});
				this.showErrorToast = jest.fn();
				this.consoleError = jest.fn();
			}
		};
	})
}), {virtual: true});

// The Apex import is also not resolvable in Jest — mock it too.
jest.mock('@salesforce/apex/CTRL_AccountCard.getAccount', () => ({default: jest.fn()}), {virtual: true});

// Custom Label imports resolve to their dev value in Jest, but mock to keep the test self-contained.
jest.mock('@salesforce/label/c.AccountCard_LoadFailed', () => ({default: 'Could not load the account.'}), {virtual: true});

describe('c-account-card', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	it('renders the loaded account name', async() =>
	{
		const element = createElement('c-account-card', {is: AccountCard});
		element.recordId = '001000000000001';
		document.body.appendChild(element);

		// Let connectedCallback's awaited controller call resolve.
		await Promise.resolve();
		await Promise.resolve();

		const text = element.shadowRoot.textContent;
		expect(text).toContain('Acme');
		expect(text).toContain('Technology');
	});
});
