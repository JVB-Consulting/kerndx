// SPDX-License-Identifier: Apache-2.0
/**
 * @description Destructive confirmation dialogue for aborting an async chain execution. The caller
 *              passes pre-interpolated strings for the title, body, and button labels, and the
 *              modal closes with one of {action: 'confirm'} | {action: 'cancel'}.
 *
 * @author Jason van Beukering
 *
 * @date July 2026, October 2026
 */
import LightningModal from 'lightning/modal';
import {api} from 'lwc';

export default class ChainAbortModal extends LightningModal
{
	/**
	 * @description Modal header title.
	 *
	 * @type {string}
	 */
	@api title = '';

	/**
	 * @description Pre-interpolated confirmation body text.
	 *
	 * @type {string}
	 */
	@api body = '';

	/**
	 * @description Label for the destructive confirm button.
	 *
	 * @type {string}
	 */
	@api confirmLabel = '';

	/**
	 * @description Label for the cancel button.
	 *
	 * @type {string}
	 */
	@api cancelLabel = '';

	handleConfirm()
	{
		this.close(/** @type {*} */({action: 'confirm'}));
	}

	handleCancel()
	{
		this.close(/** @type {*} */({action: 'cancel'}));
	}
}