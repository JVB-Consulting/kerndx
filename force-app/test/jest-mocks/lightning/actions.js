// SPDX-License-Identifier: Apache-2.0
/**
 * @description Global Jest mock for lightning/actions, which sfdx-lwc-jest does not stub. A quick action dispatches
 *              CloseActionScreenEvent to close its screen; here it is a plain 'close' event the tests can read.
 */
export class CloseActionScreenEvent extends CustomEvent
{
	constructor()
	{
		super('close');
	}
}
