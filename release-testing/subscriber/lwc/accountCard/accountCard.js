// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';
import getAccount from '@salesforce/apex/CTRL_AccountCard.getAccount';
import LOAD_FAILED from '@salesforce/label/c.AccountCard_LoadFailed';
import {api} from 'lwc';

/**
 * @description Displays the name and industry of a single Account. Loads data through the
 * KernDX controller module and raises a toast on failure.
 *
 * @author your.name@company.com
 *
 * @date February 2026
 */
export default class AccountCard extends ComponentBuilder('notification', 'controller')
{
	/** @description The Id of the Account to display. Set by the record page or parent component. */
	@api recordId;

	/** @description The loaded Account record. */
	account;

	async connectedCallback()
	{
		try
		{
			this.account = await this.callControllerMethod(getAccount, {accountId: this.recordId});
		}
		catch(error)
		{
			this.consoleError(error, 'accountCard.connectedCallback');
			this.showErrorToast(LOAD_FAILED);
		}
	}
}
