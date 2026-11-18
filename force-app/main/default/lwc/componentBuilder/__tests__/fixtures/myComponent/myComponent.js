import {ComponentBuilder} from 'kern/componentBuilder';
import saveRecord from '@salesforce/apex/MyController.saveRecord';
import RECORD_SAVED from '@salesforce/label/c.MyComponent_RecordSaved';

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	async handleSave()
	{
		const recordId = await this.callControllerMethod(saveRecord, {record: this.record});
		if(recordId)
		{
			this.showSuccessToast(RECORD_SAVED);
		}
	}
}
