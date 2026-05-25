// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Global Jest mock for lightning/modal (LightningModal).
 *              Provides a base class with static open() and instance close() methods.
 */
import {LightningElement, api} from 'lwc';

export const mockClose = jest.fn().mockResolvedValue(undefined);

export default class LightningModal extends LightningElement
{
	static open = jest.fn().mockResolvedValue(undefined);

	@api close = mockClose;
}
