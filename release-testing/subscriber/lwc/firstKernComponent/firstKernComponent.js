// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class FirstKernComponent extends ComponentBuilder('notification')
{
	handleClick()
	{
		this.showSuccessToast('It works!');
	}
}
