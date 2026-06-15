// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Rule-detail popup for the Data Masking Advisor, built on lightning/modal
 * (LightningModal) so the modal chrome and the WCAG focus-trap come from the platform. It explains a
 * single masking rule a chip represents — what it redacts, a live "test this rule" against a sample
 * value, the field types it fits, and where it is applied — and, for a rule the admin can include or
 * exclude (an existing field target or a candidate), a "masked / active after deploy" checkbox that
 * mirrors the inline chip. It never changes the org: it resolves the chip's desired state back to the
 * caller, which folds it into the export diff.
 *
 * Resolution contract: closes with `{wantActive}` (the chip's desired "active after deploy" state) from
 * the Done button; closes with `{wantActive, action:'manageSetup'}` from the Manage-in-Setup link so the
 * caller can navigate to Setup; the platform header dismiss (the modal's X) closes with `undefined`,
 * which the caller treats as "no change". A read-only rule (an object-wide rule shown on a field) carries
 * no checkbox, so its `wantActive` echoes the seed unchanged.
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {api} from 'lwc';
import LightningModal from 'lightning/modal';
import previewWithRule from '@salesforce/apex/CTRL_MaskingAdvisor.previewWithRule';
import PILL_ACTIVE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Pill_Active';
import PILL_INACTIVE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Pill_Inactive';
import PILL_NOT_APPLIED from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Pill_NotApplied';
import WHAT_IT_MASKS_HEADING from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_WhatItMasks_Heading';
import NO_DESCRIPTION from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_NoDescription';
import TEST_HEADING from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_TestThisRule_Heading';
import TEST_PROMPT from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Test_Prompt';
import APPLIES_TO_HEADING from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AppliesTo_Heading';
import WHERE_HEADING from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_Heading';
import WHERE_FIELD_LEVEL from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_FieldLevel';
import WHERE_OBJECT_WIDE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_ObjectWide';
import WHERE_FIELD_CANDIDATE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_FieldCandidate';
import WHERE_OBJECT_WIDE_CANDIDATE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_ObjectWideCandidate';
import WHERE_MASKING_NOTHING from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Where_MaskingNothingSuffix';
import MASKED_AFTER_DEPLOY_LABEL from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_MaskedAfterDeploy_Label';
import AFTER_STAYS_MASKED from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_StaysMasked';
import AFTER_DISABLED from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_Disabled';
import AFTER_REENABLED from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_Reenabled';
import AFTER_STAYS_INACTIVE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_StaysInactive';
import AFTER_ADDED from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_Added';
import AFTER_NOT_ADDED from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_AfterDeploy_NotAdded';
import CANDIDATE_NOTE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Candidate_Note';
import OBJECT_WIDE_MANAGED_NOTE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_ObjectWideManaged_Note';
import MANAGE_IN_SETUP_LINK from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_ManageInSetup_Link';
import DONE from '@salesforce/label/c.DataMaskingAdvisor_RuleDetail_Done';
import TEST_BUTTON from '@salesforce/label/c.DataMaskingAdvisor_Example_TryButton_Label';
import TEST_INPUT_PLACEHOLDER from '@salesforce/label/c.DataMaskingAdvisor_Example_TryInput_Placeholder';
import TEST_INPUT_ARIA from '@salesforce/label/c.DataMaskingAdvisor_Example_TryInput_AriaLabel';
import TEST_NO_CHANGE from '@salesforce/label/c.DataMaskingAdvisor_Example_NoChange_Note';
import TEST_FAILED from '@salesforce/label/c.DataMaskingAdvisor_Example_PreviewFailed_Note';
import TEST_JSON_HINT from '@salesforce/label/c.DataMaskingAdvisor_Example_JsonHint_Note';
import {friendlyFieldTypes} from 'c/maskingFieldTypeLabels';

// A chip's origin sets the pill, the where-line, and which "after deploy" note shows: an existing active
// target, an existing inactive target, a not-yet-created candidate, or a read-only object-wide rule shown
// on a field (context). The first three are managed — they carry the masked-after-deploy checkbox.
const ORIGIN_ACTIVE = 'active';
const ORIGIN_INACTIVE = 'inactive';
const ORIGIN_CANDIDATE = 'candidate';
// A chip's scope: a field-level rule (where-line names object.field) or an object-wide rule (object only).
const SCOPE_OBJECT = 'O';
// The resolution action the Manage-in-Setup link carries so the caller can navigate to Salesforce Setup.
const ACTION_MANAGE_SETUP = 'manageSetup';

/**
 * @description Static label strings the template renders, grouped so the markup reads `{labels.x}`.
 * @type {Object<string, string>}
 */
const LABELS = {
	whatItMasksHeading: WHAT_IT_MASKS_HEADING,
	testHeading: TEST_HEADING,
	appliesToHeading: APPLIES_TO_HEADING,
	whereHeading: WHERE_HEADING,
	maskedAfterDeployLabel: MASKED_AFTER_DEPLOY_LABEL,
	candidateNote: CANDIDATE_NOTE,
	objectWideManagedNote: OBJECT_WIDE_MANAGED_NOTE,
	manageInSetup: MANAGE_IN_SETUP_LINK,
	done: DONE,
	testButton: TEST_BUTTON,
	testInputPlaceholder: TEST_INPUT_PLACEHOLDER,
	testInputAria: TEST_INPUT_ARIA
};

export default class MaskingRuleDetail extends LightningModal
{
	/**
	 * @description The rule's display label, shown as the modal title.
	 * @type {string}
	 */
	@api ruleLabel;

	/**
	 * @description The rule's developer name, used to run the sample-value test against the rule.
	 * @type {string}
	 */
	@api ruleDeveloperName;

	/**
	 * @description The rule's plain-language description (`MaskingRule__mdt.Description__c`). Blank renders
	 * the no-description fallback.
	 * @type {string}
	 */
	@api ruleDescription;

	/**
	 * @description Whether the underlying rule is itself active. Drives the "Active" pill's on-state for an
	 * applied or read-only rule.
	 * @type {boolean}
	 */
	@api ruleActive;

	/**
	 * @description The upper-cased field-type literals the rule fits (empty means any text-shaped field),
	 * mapped to friendly names in the Applies-to row.
	 * @type {Array<string>}
	 */
	@api applicableFieldTypes;

	/**
	 * @description The chip's origin — `active` / `inactive` / `candidate` (managed, carry the checkbox) or
	 * `context` (a read-only object-wide rule shown on a field).
	 * @type {string}
	 */
	@api origin;

	/**
	 * @description The chip's scope — `F` field-level (where-line names object.field) or `O` object-wide.
	 * @type {string}
	 */
	@api scope;

	/**
	 * @description The analyzed object's API name, shown in the where-line and used to run the test.
	 * @type {string}
	 */
	@api objectApiName;

	/**
	 * @description The field API name the test runs against — the chip's own field for a field-level rule,
	 * or a representative applicable field the caller chose for an object-wide rule.
	 * @type {string}
	 */
	@api fieldApiName;

	/**
	 * @description The chip's current desired "active after deploy" state, seeding the checkbox so the
	 * popup opens reflecting the inline chip.
	 * @type {boolean}
	 */
	@api desired;

	/**
	 * @description The supersession annotation for this rule — set when another rule's `Replaces__c`
	 * names it — rendered as a note under the status pill so the admin is steered to the successor.
	 * Blank renders nothing.
	 * @type {string}
	 */
	@api supersededByLabel;

	/**
	 * @description The pending desired "active after deploy" state, seeded from `desired` at mount and
	 * resolved back to the caller on close. A read-only rule never mutates it.
	 * @type {boolean}
	 */
	wantActive;

	/**
	 * @description The sample value typed into the test input.
	 * @type {string}
	 */
	testValue = '';

	/**
	 * @description The rendered test result: `showMasked` toggles the before→after example; `message`
	 * carries the prompt / no-change / JSON-hint / failure line. Both blank until the first test.
	 * @type {{showMasked: boolean, before: string, after: string, message: string}}
	 */
	preview = {showMasked: false, before: '', after: '', message: ''};

	/**
	 * @description Static label strings for the template.
	 * @returns {Object<string, string>}
	 */
	get labels()
	{
		return LABELS;
	}

	/**
	 * @description The "what it masks" text — the rule's description, or the fallback when it has none.
	 * @returns {string}
	 */
	get descriptionText()
	{
		return this.ruleDescription && this.ruleDescription.trim() ? this.ruleDescription : NO_DESCRIPTION;
	}

	/**
	 * @description Whether the rule is one the admin can include or exclude (an existing target or a
	 * candidate) — those carry the masked-after-deploy checkbox; a read-only object-wide context rule
	 * does not.
	 * @returns {boolean}
	 */
	get isManaged()
	{
		return this.origin === ORIGIN_ACTIVE || this.origin === ORIGIN_INACTIVE || this.origin === ORIGIN_CANDIDATE;
	}

	/**
	 * @description True for a not-yet-created candidate rule.
	 * @returns {boolean}
	 */
	get isCandidate()
	{
		return this.origin === ORIGIN_CANDIDATE;
	}

	/**
	 * @description The status pill text: a candidate is "Not applied", an inactive target is "Inactive",
	 * anything else is "Active".
	 * @returns {string}
	 */
	get pillText()
	{
		if(this.isCandidate)
		{
			return PILL_NOT_APPLIED;
		}
		if(this.origin === ORIGIN_INACTIVE)
		{
			return PILL_INACTIVE;
		}
		return PILL_ACTIVE;
	}

	/**
	 * @description Whether the status pill renders in its on (active) styling — only for an applied or
	 * read-only rule whose underlying rule is itself active.
	 * @returns {boolean}
	 */
	get pillActive()
	{
		return this.origin !== ORIGIN_INACTIVE && this.origin !== ORIGIN_CANDIDATE && this.ruleActive === true;
	}

	/**
	 * @description The friendly field-type names the rule applies to, comma-joined. An unscoped rule (no
	 * applicable types) reads "Any text field".
	 * @returns {string}
	 */
	get appliesToText()
	{
		return friendlyFieldTypes(this.applicableFieldTypes);
	}

	/**
	 * @description The where-applied line: object-wide names just the object, field-level names
	 * object.field, a candidate reads as a candidate, and an inactive target appends "currently masking
	 * nothing".
	 * @returns {string}
	 */
	get whereText()
	{
		const objectWide = this.scope === SCOPE_OBJECT;
		let line;
		if(this.isCandidate)
		{
			line = objectWide ? WHERE_OBJECT_WIDE_CANDIDATE.replace('{0}', this.objectApiName) : WHERE_FIELD_CANDIDATE.replace('{0}', this.objectApiName)
			.replace('{1}', this.fieldApiName);
		}
		else
		{
			line = objectWide ? WHERE_OBJECT_WIDE.replace('{0}', this.objectApiName) : WHERE_FIELD_LEVEL.replace('{0}', this.objectApiName).replace('{1}', this.fieldApiName);
		}
		return this.origin === ORIGIN_INACTIVE ? line + ' — ' + WHERE_MASKING_NOTHING : line;
	}

	/**
	 * @description The live "after deploy" note for the checkbox, by origin and the pending desired state.
	 * @returns {string}
	 */
	get afterDeployNote()
	{
		if(this.origin === ORIGIN_ACTIVE)
		{
			return this.wantActive ? AFTER_STAYS_MASKED : AFTER_DISABLED;
		}
		if(this.origin === ORIGIN_INACTIVE)
		{
			return this.wantActive ? AFTER_REENABLED : AFTER_STAYS_INACTIVE;
		}
		return this.wantActive ? AFTER_ADDED : AFTER_NOT_ADDED;
	}

	/**
	 * @description Whether the footer shows the Manage-in-Setup link — for every rule except a candidate
	 * (a candidate shows the "created on deploy" note instead).
	 * @returns {boolean}
	 */
	get showManageInSetup()
	{
		return !this.isCandidate;
	}

	/**
	 * @description Whether the footer shows the candidate "created on deploy" note.
	 * @returns {boolean}
	 */
	get showCandidateNote()
	{
		return this.isCandidate;
	}

	/**
	 * @description Whether the body shows the read-only "managed object-wide" note — only for a context
	 * rule the admin manages from the object-wide banner, not here.
	 * @returns {boolean}
	 */
	get showObjectWideManagedNote()
	{
		return !this.isManaged;
	}

	/**
	 * @description Seeds the pending desired state from the chip's current state at mount.
	 */
	connectedCallback()
	{
		this.wantActive = this.desired === true;
	}

	/**
	 * @description Flips the pending desired state when the admin toggles the masked-after-deploy checkbox.
	 * @param {Event} event
	 */
	handleCheckboxChange(event)
	{
		this.wantActive = event.target.checked === true;
	}

	/**
	 * @description Tracks the sample value as the admin types.
	 * @param {Event} event
	 */
	handleTestInput(event)
	{
		this.testValue = event.target.value;
	}

	/**
	 * @description Runs the sample value against the rule and renders the result: a masked before→after, a
	 * no-change note, a JSON-payload hint, or a failure note. An empty value just prompts. The preview is a
	 * read-only computation — it never writes to the org.
	 */
	async handleRunTest()
	{
		if(!this.testValue)
		{
			this.preview = {showMasked: false, before: '', after: '', message: TEST_PROMPT};
			return;
		}
		try
		{
			const result = await previewWithRule({
				objectApiName: this.objectApiName, fieldApiName: this.fieldApiName, ruleDeveloperName: this.ruleDeveloperName, value: this.testValue
			});
			this.preview = this.toPreview(result);
		}
		catch(error)
		{
			this.preview = {showMasked: false, before: '', after: '', message: TEST_FAILED};
		}
	}

	/**
	 * @description Maps a preview DTO into the rendered test result: a null result or a rule that failed is
	 * a failure note; a changed value is a masked before→after; an unchanged JSON-keyed rule hints for a
	 * JSON payload; any other unchanged value is a no-change note.
	 * @param {Object} result The preview DTO from the controller.
	 * @returns {{showMasked: boolean, before: string, after: string, message: string}}
	 */
	toPreview(result)
	{
		if(!result || (result.failedRuleDeveloperNames && result.failedRuleDeveloperNames.length > 0))
		{
			return {showMasked: false, before: '', after: '', message: TEST_FAILED};
		}
		if(result.maskedValue !== this.testValue)
		{
			return {showMasked: true, before: this.testValue, after: result.maskedValue, message: ''};
		}
		if(result.expectsJsonInput === true)
		{
			return {showMasked: false, before: '', after: '', message: TEST_JSON_HINT};
		}
		return {showMasked: false, before: '', after: '', message: TEST_NO_CHANGE};
	}

	/**
	 * @description Closes the popup, resolving the chip's pending desired state so the caller can fold it
	 * into the export diff.
	 */
	handleDone()
	{
		this.close({wantActive: this.wantActive});
	}

	/**
	 * @description Closes the popup carrying both the desired state and a Manage-in-Setup action, so the
	 * caller applies the toggle and then navigates to Salesforce Setup.
	 */
	handleManageInSetup()
	{
		this.close({wantActive: this.wantActive, action: ACTION_MANAGE_SETUP});
	}
}