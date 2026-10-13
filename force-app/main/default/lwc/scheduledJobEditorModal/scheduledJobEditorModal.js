// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Modal dialog for creating and editing ScheduledJob__c records. Extends LightningModal
 *              to provide a standard Salesforce modal experience with fixed header/footer and scrollable
 *              body, and renders the shared scheduled job form in it. Opened programmatically via static
 *              .open() from Health Check, which may prefill the form and lock fields.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, October 2026
 */
import LightningModal from 'lightning/modal';
import {api, wire} from 'lwc';
import {getRecord} from 'lightning/uiRecordApi';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {reduceErrors} from 'c/utilitySystem';
import {ScheduledJobEditorForm, SCHEDULED_JOB_FORM_FIELDS, SCHEDULED_JOB_FORM_LABELS} from 'c/scheduledJobEditorForm';
import LOAD_RECORD_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_LoadRecordFailed';
import SUCCESS_TOAST_TITLE from '@salesforce/label/c.ScheduledJobEditorModal_SuccessToastTitle';
import CREATED from '@salesforce/label/c.ScheduledJob_Created';
import SAVED from '@salesforce/label/c.ScheduledJob_Saved';

export default class ScheduledJobEditorModal extends ScheduledJobEditorForm(LightningModal)
{
	/**
	 * @description The ScheduledJob__c record to edit; when omitted, the modal creates one. The shared form declares
	 *              and reads it since 1.8; it stays declared here because a managed package keeps every public
	 *              property it released.
	 *
	 * @type {string}
	 */
	@api recordId;

	/**
	 * @description Optional create-mode payload used to pre-populate the form when no recordId is supplied.
	 *              Supported keys: schedulerName, className, cronExpression, isActive, description, parameterValues.
	 *
	 * @type {Object}
	 */
	@api prefill;

	/**
	 * @description Field names that render read-only, forwarded to the form inputs when the customize flow opens the
	 *              modal. The shared form declares and reads it since 1.8; it stays declared here because a managed
	 *              package keeps every public property it released.
	 *
	 * @type {string[]}
	 */
	@api lockedFields = [];

	// Named `labels` (plural, matching every other Kern modal): a field named `label` would
	// shadow LightningModal's inherited string `label` property with an object, which crashes
	// the platform's modal aria bookkeeping (label.trim()) and unmounts the modal mid-open.
	labels = SCHEDULED_JOB_FORM_LABELS;

	/**
	 * @description Message rendered in the modal's inline error region. Toasts dispatched while a
	 *              LightningModal is open are swallowed by the overlay, so save/load failures surface
	 *              here instead. Empty when there is no error to show.
	 *
	 * @type {string}
	 */
	errorMessage = '';

	/**
	 * @description Whether the inline error region should render.
	 *
	 * @return {boolean} True when an error message is waiting to be shown.
	 */
	get hasErrorMessage()
	{
		return Boolean(this.errorMessage);
	}

	/**
	 * @description Whether the class-name combobox should be disabled because `className` appears in lockedFields.
	 *              Used by the customize-path flow, which locks both the target object parameter and the scheduler
	 *              class to prevent the user from changing the retention scheduler selection.
	 *
	 * @return {boolean} True when the combobox should render disabled.
	 */
	get isClassNameLocked()
	{
		let lockedNames = Array.isArray(this.lockedFields) ? this.lockedFields : [];
		return lockedNames.indexOf('className') !== -1;
	}

	/**
	 * @description Reads what the shared form reads, then fills a new record's form from the prefill, when given.
	 */
	connectedCallback()
	{
		super.connectedCallback();

		if(!this.recordId && this.prefill)
		{
			let prefill = this.prefill;

			this.schedulerName = prefill.schedulerName || this.schedulerName;
			this.className = prefill.className || this.className;
			this.cronExpression = prefill.cronExpression || this.cronExpression;

			if(prefill.isActive !== undefined && prefill.isActive !== null)
			{
				this.isActive = prefill.isActive === true;
			}

			if(prefill.description)
			{
				this.description = prefill.description;
			}

			if(prefill.parameterValues && typeof prefill.parameterValues === 'object')
			{
				this.parameterValues = {...prefill.parameterValues};
			}

			if(prefill.className)
			{
				this.lastLoadedClassName = prefill.className;
				this.loadParameterDefinitions(prefill.className);
			}
		}
	}

	@wire(getRecord, {recordId: '$recordId', fields: SCHEDULED_JOB_FORM_FIELDS}) wiredRecord({data, error})
	{
		if(data)
		{
			this.applyRecord(data);
			this.errorMessage = '';
		}

		if(error)
		{
			this.errorMessage = reduceErrors(error) || LOAD_RECORD_FAILED_LABEL;
		}
	}

	/**
	 * @description Reads the class's parameters as the shared form does. A locked class name shows as a read-only input
	 *              with no message of its own, so its refusal also goes to the modal's error region, or Save would be disabled
	 *              with no reason given. That region is cleared on success and kept for load and save failures.
	 *
	 * @param {string} className The class name, picked, typed or prefilled.
	 *
	 * @return {Promise<boolean>} True when the class was accepted, false when the name was refused.
	 */
	async loadParameterDefinitions(className)
	{
		let isAccepted = await super.loadParameterDefinitions(className);

		if(isAccepted)
		{
			this.errorMessage = '';
		}
		else if(this.isClassNameLocked)
		{
			this.errorMessage = this.classNameError;
		}

		return isAccepted;
	}

	/**
	 * @description Keeps the modal open while the shared save path runs, and clears a previous failure first.
	 *
	 * @return {Promise<void>} Resolves once the save has completed or failed.
	 */
	async handleSave()
	{
		this.disableClose = true;
		this.errorMessage = '';

		try
		{
			await super.handleSave();
		}
		finally
		{
			this.disableClose = false;
		}
	}

	/**
	 * @description Says the record was created or saved, then closes the modal with the saved record's id.
	 *
	 * @param {string} savedRecordId The id of the record that was saved.
	 */
	completeSave(savedRecordId)
	{
		this.dispatchEvent(new ShowToastEvent({
			title: SUCCESS_TOAST_TITLE, message: this.isCreateMode ? CREATED : SAVED, variant: 'success'
		}));

		// Release the close guard BEFORE invoking close(): LightningModal silently ignores close()
		// while disableClose is true, leaving the modal open and blocking the parent refresh.
		this.disableClose = false;
		this.close(savedRecordId);
	}

	/**
	 * @description Shows a failed save inside the modal: a toast dispatched while the modal stays open is
	 *              swallowed by the overlay and the admin never sees it.
	 *
	 * @param {string} message What went wrong.
	 */
	reportSaveFailure(message)
	{
		this.errorMessage = message;
	}

	handleCancel()
	{
		this.close(null);
	}
}
