// SPDX-License-Identifier: Apache-2.0
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
