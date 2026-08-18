// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Generic confirmation dialogue for the Chain Monitor's operator actions (retry,
 *              restart, clear stalled, suspend, resume). The caller passes pre-interpolated
 *              strings for the title, body, and button labels plus the confirm button's variant
 *              — 'brand' for the recovery actions, 'destructive' for suspend, carrying the
 *              validated prototype's per-action decision — and the modal closes with one of
 *              {action: 'confirm'} | {action: 'cancel'}.
 *
 * @author Jason van Beukering
 *
 * @date August 2026
 */
/* eslint-disable-next-line kerndx/enforce-component-naming */
import LightningModal from 'lightning/modal';
import {api} from 'lwc';

export default class ChainActionConfirmModal extends LightningModal
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
	 * @description Label for the confirm button.
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

	/**
	 * @description Variant of the confirm button: 'brand' or 'destructive'.
	 *
	 * @type {string}
	 */
	@api confirmVariant = 'brand';

	handleConfirm()
	{
		this.close(/** @type {*} */({action: 'confirm'}));
	}

	handleCancel()
	{
		this.close(/** @type {*} */({action: 'cancel'}));
	}
}