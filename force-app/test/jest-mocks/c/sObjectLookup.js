// SPDX-License-Identifier: Apache-2.0
/**
 * @description Global Jest mock for sObjectLookup LWC module.
 */
import {LightningElement, api} from 'lwc';

export default class MockSObjectLookup extends LightningElement
{
	@api objectApiName;
	@api fieldApiName;
	@api iconName;
}
