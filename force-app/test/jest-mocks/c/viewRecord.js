// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Global Jest mock for viewRecord LWC module.
 */
import {LightningElement, api} from 'lwc';

export default class MockViewRecord extends LightningElement
{
	@api recordId;
	@api fieldSetDeveloperName;
	@api fields;
}
