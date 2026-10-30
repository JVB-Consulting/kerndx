// SPDX-License-Identifier: Apache-2.0
import {ComponentBuilder} from 'kern/componentBuilder';

export default class FirstKernComponent extends ComponentBuilder('notification')
{
	handleClick()
	{
		this.showSuccessToast('It works!');
	}
}
