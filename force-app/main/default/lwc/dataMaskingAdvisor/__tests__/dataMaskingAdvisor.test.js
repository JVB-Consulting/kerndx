// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the dataMaskingAdvisor LWC coverage area. Covers object selection via
 *              the "＋ Add object" grouped dialog (and "← All objects" back to the landing),
 *              the configuration-health and object-wide-coverage banners, the heuristic-only-mode
 *              notice, the summary strip, and the smart list — Ready / Needs review / Other
 *              sections whose rows render a masking cell of checkbox chips (read-only object-wide
 *              context + tickable field-level rules and candidates). A ticked chip means "masked /
 *              active after deploy"; the export is the diff of those desired states (create / disable /
 *              re-enable). Also covers the sensitivity badge + signal band, the reclassify dialog /
 *              override / revert, and the per-object session draft.
 *
 * @author Jason van Beukering
 * @date May 2026, June 2026
 */
import {createElement} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import DataMaskingAdvisor from 'c/dataMaskingAdvisor';
import {mockCallControllerMethod, mockShowSuccessToast, mockShowWarningToast, mockNavigate} from 'c/componentBuilder';
import listObjects from '@salesforce/apex/CTRL_MaskingAdvisor.listObjects';
import getDeadConfigurations from '@salesforce/apex/CTRL_MaskingAdvisor.getDeadConfigurations';
import describeFields from '@salesforce/apex/CTRL_MaskingAdvisor.describeFields';
import generateConfiguration from '@salesforce/apex/CTRL_MaskingAdvisor.generateConfiguration';
import getOrgPostureSummary from '@salesforce/apex/CTRL_MaskingAdvisor.getOrgPostureSummary';
import getOrgPostureInventory from '@salesforce/apex/CTRL_MaskingAdvisor.getOrgPostureInventory';
import assessObjectCoverage from '@salesforce/apex/CTRL_MaskingAdvisor.assessObjectCoverage';

jest.mock('@salesforce/apex/CTRL_MaskingAdvisor.listObjects', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_MaskingAdvisor.getDeadConfigurations', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_MaskingAdvisor.describeFields', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_MaskingAdvisor.generateConfiguration', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_MaskingAdvisor.getOrgPostureSummary', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_MaskingAdvisor.getOrgPostureInventory', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_MaskingAdvisor.assessObjectCoverage', () => ({default: jest.fn()}), {virtual: true});

jest.mock('@salesforce/messageChannel/Component__c', () => ({default: {}}), {virtual: true});

// The reclassify Review dialog is opened programmatically (LightningModal.open). Stub it with a
// resolvable spy so a test can drive the Apply ({level}) / Cancel (null) result per the dialog's
// resolution contract, without pulling the real dialog's label tree into this suite.
const mockMaskingReviewDialogOpen = jest.fn().mockResolvedValue(null);
jest.mock('c/maskingReviewDialog', () => ({
	__esModule: true, default: {open: (...args) => mockMaskingReviewDialogOpen(...args)}
}), {virtual: true});

// The Export-package confirm dialog is opened programmatically too. Stub it with a resolvable spy so a
// test can drive its resolution contract (Download {action:'download'} / Cancel null / dismiss undefined)
// without pulling the real modal's label tree into this suite.
const mockMaskingExportModalOpen = jest.fn().mockResolvedValue(null);
jest.mock('c/maskingExportModal', () => ({
	__esModule: true, default: {open: (...args) => mockMaskingExportModalOpen(...args)}
}), {virtual: true});

// The "＋ Add object" grouped search dialog is opened programmatically (LightningModal.open). Stub it with a
// resolvable spy so a test can drive its resolution contract (picked api name / null on Close) and assert
// the universe + scan + masked-set props it receives, without pulling the real dialog's label tree in.
const mockMaskingAddObjectDialogOpen = jest.fn().mockResolvedValue(null);
jest.mock('c/maskingAddObjectDialog', () => ({
	__esModule: true, default: {open: (...args) => mockMaskingAddObjectDialogOpen(...args)}
}), {virtual: true});

// The regulated-field inventory export dialog is opened programmatically (LightningModal.open). Stub it with
// a resolvable spy so a test can assert the scope-source props it receives without pulling the real dialog's
// label tree (or its per-object Apex fetch) into this suite.
const mockMaskingInventoryExportDialogOpen = jest.fn().mockResolvedValue(null);
jest.mock('c/maskingInventoryExportDialog', () => ({
	__esModule: true, default: {open: (...args) => mockMaskingInventoryExportDialogOpen(...args)}
}), {virtual: true});

// The rule-detail popup is opened programmatically (LightningModal.open). Stub it with a resolvable spy so
// a test can drive its resolution contract ({wantActive} from Done / {wantActive, action:'manageSetup'} /
// undefined on dismiss) without pulling the real popup's label tree into this suite.
const mockMaskingRuleDetailOpen = jest.fn().mockResolvedValue(undefined);
jest.mock('c/maskingRuleDetail', () => ({
	__esModule: true, default: {open: (...args) => mockMaskingRuleDetailOpen(...args)}
}), {virtual: true});

// The add-rule menu is opened programmatically too. Stub it so a test can drive its resolution contract
// ({pickedRuleDeveloperName} / {action:'createRule'} / undefined) without its label tree.
const mockMaskingAddRuleMenuOpen = jest.fn().mockResolvedValue(undefined);
jest.mock('c/maskingAddRuleMenu', () => ({
	__esModule: true, default: {open: (...args) => mockMaskingAddRuleMenuOpen(...args)}
}), {virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_CardTitle', () => ({default: 'Data Masking Advisor'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RefreshAltText', () => ({default: 'Refresh masking analysis'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ScopeBanner_Body',
		() => ({default: 'Masking redacts sensitive values as they flow through framework paths — debug logs, outbound API callouts, async jobs, and platform events. It does not encrypt data at rest or change what is stored on your records.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_DeadConfigBanner_Heading', () => ({default: 'Configuration health'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_DeadConfigBanner_Summary_Singular', () => ({default: '1 active masking target is currently masking nothing.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_DeadConfigBanner_Summary_Plural', () => ({default: '{0} active masking targets are currently masking nothing.'}),
		{virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Heading', () => ({default: 'Coverage advisor'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_Button', () => ({default: '＋ Add object'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObject_BackToAllObjects', () => ({default: '← All objects'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_InventoryExport_OpenButton', () => ({default: '⤓ Export field inventory'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Other_LowConfidenceMatch_Tag', () => ({default: 'Low-confidence match'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_HeuristicOnly_Notice',
		() => ({default: 'Running in heuristic-only mode — native field classification could not be read in this org.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Empty_Heading', () => ({default: 'Pick an object to begin'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Empty_Body',
		() => ({default: 'Choose an object above to see which of its fields would benefit from a masking rule on framework paths.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Error_LoadFailed',
		() => ({default: 'Could not load fields for this object. Try again, or pick a different object.'}), {virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Table_Column_Field', () => ({default: 'Field'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Table_Column_Sensitivity', () => ({default: 'Sensitivity'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Table_Column_MaskingRules', () => ({default: 'Masking rules'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_HeuristicTier_High', () => ({default: 'Heuristic — high confidence'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_HeuristicTier_Medium', () => ({default: 'Heuristic — medium confidence'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_HeuristicTier_Low', () => ({default: 'Heuristic — low confidence'}), {virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Section_Ready_Guidance',
		() => ({default: 'These fields match a masking rule and are pre-selected. Untick any you want to leave out, then export the package.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Section_ManualReview_NoRuleNote', () => ({default: 'No template rule matches {0}.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Section_Other_Heading', () => ({default: 'All other fields ({0})'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Section_Other_Summary',
		() => ({default: 'Fields not recommended for masking. Likely misses are listed first. Use the badge to mask one anyway.'}), {virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_Sensitivity_Sensitive', () => ({default: 'Sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Sensitivity_PossiblySensitive', () => ({default: 'Possibly Sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Sensitivity_NotSensitive', () => ({default: 'Not Sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_SignalBand_Weak', () => ({default: 'Weak'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_SignalBand_Moderate', () => ({default: 'Moderate'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_SignalBand_Strong', () => ({default: 'Strong'}), {virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_Summary_Ready', () => ({default: '{0} ready'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Summary_ToReview', () => ({default: '{0} to review'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Summary_Other', () => ({default: '{0} other'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Section_ReadyToMask_Heading', () => ({default: 'Ready to mask ({0})'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ExportPackageButton_Label', () => ({default: 'Export package'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ExportModal_FileName', () => ({default: 'masking-configuration.zip'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Posture_Heading', () => ({default: 'Org-wide masking posture'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Posture_AsConfiguredNote',
		() => ({default: 'These counts reflect the masking targets configured in this org, not a scan of every field.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Posture_ObjectsWithMasking', () => ({default: 'Objects with masking configured'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Posture_DeadConfigurations', () => ({default: 'Dead configurations'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Inventory_Heading', () => ({default: 'Objects with masking'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Inventory_CountMeta', () => ({default: '{0} object-wide · {1} field-level'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Inventory_DeadSuffix', () => ({default: '{0} dead'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Inventory_Footer', () => ({default: 'Click an object to review its fields.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Posture_BarelyMasked_Note',
		() => ({default: 'Almost nothing is masked in this org yet. Pick an object to review its fields and start configuring masking.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Section_NeedsReview_Heading', () => ({default: 'Needs review ({0})'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Section_NeedsReview_Guidance',
		() => ({default: 'Ambiguous classifications. Add a rule to mask one, or open the badge to reclassify it.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Other_Reason_NoSignal', () => ({default: 'No sensitivity signal detected.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Other_Reason_TypeSuggests', () => ({default: 'This field type often holds sensitive data, but no rule matched its name.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_OtherToggle_MissesOnly_Label', () => ({default: 'Show likely misses only'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Other_RowCap_Note', () => ({default: 'Showing the first {0} of {1} fields. Turn on Show likely misses only to narrow the list.'}),
		{virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_ReviewBadge_AssistiveText', () => ({default: 'Review classification for {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Marker_MarkedNotSensitive', () => ({default: 'Marked not sensitive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Marker_AddedManually', () => ({default: 'Added manually'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RevertOverride_Label', () => ({default: 'Revert'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_RevertOverride_AriaLabel', () => ({default: 'Revert the change to {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Summary_Changes', () => ({default: '{0} changes'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Reclassify_Toast_Other', () => ({default: '{0} marked not sensitive.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Reclassify_Toast_Reverted', () => ({default: 'Reverted the change to {0}.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Reclassify_Toast_Ready', () => ({default: '{0} added to the masking package.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Reclassify_Toast_Review', () => ({default: '{0} flagged for review. Add a rule to include it.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ClearDraft_Label', () => ({default: 'Clear draft'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Draft_SaveFailed_Warning',
		() => ({default: 'Your changes can\'t be saved in this browser, so they\'ll be lost if you reload. Export now to keep them.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Draft_Cleared_Toast', () => ({default: 'Draft cleared.'}), {virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_MaskingCell_ObjectWideLine_Label', () => ({default: 'Object-wide'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_MaskingCell_FieldLevelLine_Label', () => ({default: 'Field-level'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Chip_Flag_WillDisable', () => ({default: 'will disable'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Chip_Flag_WillEnable', () => ({default: 'will enable'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Chip_Flag_ToAdd', () => ({default: 'to add'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Chip_Toggle_AriaLabel', () => ({default: 'Mask with {0} after deploy'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Chip_InactiveSuffix', () => ({default: 'inactive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Chip_SupersededFlag', () => ({default: 'superseded'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRule_Label', () => ({default: 'Add rule'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddObjectWideRule_Label', () => ({default: 'Add object-wide rule'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_AppliesTo', () => ({default: 'Applies to {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_NoFieldMatch_Warning', () => ({default: 'Won\'t match any field on this object yet'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Text', () => ({default: 'Text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_LongText', () => ({default: 'Long Text Area'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Url', () => ({default: 'URL'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Email', () => ({default: 'Email'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_Phone', () => ({default: 'Phone'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_EncryptedText', () => ({default: 'Encrypted Text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_FieldType_AnyText', () => ({default: 'Any text field'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Heading_Active_Singular', () => ({default: '{0} is masked object-wide by 1 active rule'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Heading_Active_Plural', () => ({default: '{0} is masked object-wide by {1} active rules'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Heading_None', () => ({default: '{0} has no object-wide masking yet'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Banner_ShowDetail', () => ({default: 'Show detail'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_Banner_HideDetail', () => ({default: 'Hide detail'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Note_Active',
		() => ({default: 'These rules run on every field, redacting only the patterns they match. Untick one to disable it across the object.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Note_None',
		() => ({default: 'An object-wide rule runs on every field of this object, redacting only the pattern it matches.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Heading', () => ({default: 'Configuration health'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Summary_ObjectWideInactive_Singular', () => ({default: '1 object-wide rule inactive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Summary_ObjectWideInactive_Plural', () => ({default: '{0} object-wide rules inactive'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Summary_DeadFieldTargets_Singular', () => ({default: '1 field target masking nothing'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Summary_DeadFieldTargets_Plural', () => ({default: '{0} field targets masking nothing'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Detail_ObjectWideInactive_Singular',
		() => ({default: '1 object-wide rule is configured across every field but masking nothing. Re-enable it in the object-wide banner below, or remove it in Setup.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Detail_ObjectWideInactive_Plural',
		() => ({default: '{0} object-wide rules are configured across every field but masking nothing. Re-enable them in the object-wide banner below, or remove them in Setup.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Detail_DeadFieldTarget', () => ({default: 'Field-level rule {0} on this object is masking nothing.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_NoChangesQueued_Note',
		() => ({default: 'No changes queued. Tick a candidate to add masking, or untick an existing rule to disable it.'}), {virtual: true});

jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Heading', () => ({default: 'Custom objects without masking'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Intro',
		() => ({default: 'Your own custom objects can hold the same kind of sensitive data the framework masks by default — emails, phone numbers, free-text bodies — but masking only covers them once you configure it.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_PopulationNote', () => ({default: 'You have {0} custom objects of your own.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_PopulationNote_ManagedClause',
		() => ({default: '{0} more come from managed packages — they belong to the package vendor and are excluded unless you opt in below.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_HowItWorks',
		() => ({default: 'The scan runs the advisor’s field analysis on each object, a few at a time, and lists the ones with likely-sensitive fields and no masking. You can cancel at any point and keep what was found. Nothing changes in your org.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_IncludeManaged_Label', () => ({default: 'Include managed-package objects ({0} from installed packages)'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_ScanButton', () => ({default: 'Scan {0} custom objects'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_NoCandidates', () => ({default: 'You have no custom objects of your own to scan.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Scanning', () => ({default: 'Scanning {0} — {1} of {2}'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_InFlightNote', () => ({default: '{0} checks at a time'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Cancel', () => ({default: 'Cancel'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Rescan', () => ({default: 'Scan again'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Summary',
		() => ({default: 'Scanned {0} custom objects · {1} need attention · {2} likely-sensitive fields with no masking'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_PartialNote', () => ({default: 'Scan cancelled after {0} of {1} objects — results below are partial.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_NoMaskingPill', () => ({default: 'No masking configured'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_FlaggedFooter', () => ({default: 'Click an object to review its fields and export a masking package for it.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_EmptyState', () => ({default: 'No custom object shows likely-sensitive fields without masking.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_CleanNote', () => ({default: '{0} other custom objects show no likely-sensitive fields.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_LongTextSuffix', () => ({default: 'long text'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Provenance',
		() => ({default: 'Flagged by the custom-object scan — {0} likely-sensitive fields below have no masking.'}), {virtual: true});
jest.mock('@salesforce/label/c.DataMaskingAdvisor_CoverageScan_BackToScan', () => ({default: 'Back to scan results'}), {virtual: true});

const MOCK_OBJECTS = [
	{apiName: 'Account', label: 'Account'},
	{apiName: 'Contact', label: 'Contact'},
	{apiName: 'Lead', label: 'Lead'}
];

const MOCK_DEAD_CONFIG = [
	{
		targetDeveloperName: 'Account_Email_Mask',
		issueCode: 'INACTIVE_RULE',
		message: 'Masking target "Account_Email_Mask" points to an inactive rule, so it is currently masking nothing.'
	},
	{
		targetDeveloperName: 'Contact_Phone_Mask',
		issueCode: 'MISSING_RULE',
		message: 'Masking target "Contact_Phone_Mask" points to a rule that no longer exists, so it is currently masking nothing.'
	}
];

const NEW_RULE_SETUP_URL = '/lightning/setup/CustomMetadata/page?address=%2Fm08%2Fe%3FsObjectName%3DMaskingRule__mdt';

// The rule catalogue carried on the analysis (developerName/label/category/mode/isActive/applicableFieldTypes).
// Mask_Secret is JSON-only (TEXTAREA), so it skips a URL field; Mask_Generic lists no applicable types, so it
// applies to every text-shaped field; Mask_Street is dormant (isActive false), so a target binding it must
// activate it on deploy.
const MOCK_RULE_CATALOGUE = [
	{
		developerName: 'Mask_Card', label: 'Mask Credit Card', category: 'Payment', mode: 'CreditCard', isActive: true, applicableFieldTypes: [
			'STRING',
			'TEXTAREA',
			'URL',
			'EMAIL',
			'PHONE'
		], description: 'Redacts card-shaped numbers.'
	},
	{
		developerName: 'Mask_Secret',
		label: 'Mask Secret Keys',
		category: 'Credentials',
		mode: 'JsonKey',
		isActive: true,
		applicableFieldTypes: ['TEXTAREA'],
		description: 'Redacts secret-looking JSON keys.'
	},
	{
		developerName: 'Mask_SSN', label: 'Mask SSN', category: 'Identity', mode: 'Regex', isActive: true, applicableFieldTypes: [
			'STRING',
			'TEXTAREA'
		], description: 'Redacts US social security numbers.'
	},
	{developerName: 'Mask_Street', label: 'Mask Street', category: '', mode: 'Regex', isActive: false, applicableFieldTypes: ['STRING'], description: 'Redacts street addresses.'},
	{
		developerName: 'Mask_Phone', label: 'Mask Phone', category: 'Contact', mode: 'Regex', isActive: false, applicableFieldTypes: [
			'STRING',
			'PHONE'
		], description: 'Redacts phone numbers.'
	},
	{
		developerName: 'Mask_Generic',
		label: 'Mask Generic',
		category: 'General',
		mode: 'Regex',
		isActive: true,
		applicableFieldTypes: [],
		description: 'Redacts generic sensitive text.'
	}
];

// Two active object-wide rules (Card on every type, Secret on long text only) + one inactive (Phone).
const MOCK_OBJECT_WIDE_RULES = [
	{targetDeveloperName: 'OW_Card', ruleDeveloperName: 'Mask_Card', ruleLabel: 'Mask Credit Card', isActive: true, callerClass: ''},
	{targetDeveloperName: 'OW_Secret', ruleDeveloperName: 'Mask_Secret', ruleLabel: 'Mask Secret Keys', isActive: true, callerClass: ''},
	{targetDeveloperName: 'OW_Phone', ruleDeveloperName: 'Mask_Phone', ruleLabel: 'Mask Phone', isActive: false, callerClass: 'BillingService'}
];

function field(overrides)
{
	const row = {
		apiName: 'Field__c',
		label: 'Field',
		type: 'STRING',
		isClassified: false,
		securityClassification: null,
		complianceGroup: null,
		heuristicConfidence: null,
		recommendedRuleDeveloperName: null,
		recommendedRuleLabel: null,
		recommendedRuleIsActive: null,
		applicableRuleDeveloperNames: [],
		appliedRules: [],
		sensitivityLevel: 'NotSensitive',
		matchStrength: 'Weak',
		likelyMiss: false, ...overrides
	};
	// Mirror the controller's DTO_FieldRow: the singular recommended* fields are recommendedRules[0]. A
	// fixture that sets only the singular fields gets a one-element recommendedRules so it matches the real
	// payload shape; a fixture exercising multi-mask pre-selection passes recommendedRules explicitly.
	if(row.recommendedRules === undefined)
	{
		row.recommendedRules =
				row.recommendedRuleDeveloperName ? [{developerName: row.recommendedRuleDeveloperName, label: row.recommendedRuleLabel, isActive: row.recommendedRuleIsActive}] : [];
	}
	return row;
}

// Primary fixture exercising every chip origin + section:
//   Email     — Ready, candidate chip (Mask_Generic, ticked) + object-wide context (Card on EMAIL).
//   SSN__c    — Ready, an active applied chip (Mask_SSN) + an inactive applied chip (Mask_Street, ⚠).
//   Notes__c  — Needs review (classified, no rule); object-wide context Card + Secret (both apply to TEXTAREA).
//   ProfileUrl__c — Other (likely miss URL); object-wide context Card only (Secret is JSON-only).
//   Nickname__c   — Other (plain text, no signal).
const MOCK_ANALYSIS_MIXED = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: MOCK_OBJECT_WIDE_RULES, fields: [
		field({
			apiName: 'Email',
			label: 'Email',
			type: 'EMAIL',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_Generic',
			recommendedRuleLabel: 'Mask Generic',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong'
		}),
		field({
			apiName: 'SSN__c',
			label: 'SSN',
			type: 'STRING',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_SSN',
			recommendedRuleLabel: 'Mask SSN',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong',
			appliedRules: [
				{targetDeveloperName: 'T_SSN', ruleDeveloperName: 'Mask_SSN', ruleLabel: 'Mask SSN', isActive: true, callerClass: ''},
				{targetDeveloperName: 'T_Street', ruleDeveloperName: 'Mask_Street', ruleLabel: 'Mask Street', isActive: false, callerClass: 'LegacyLoader'}
			]
		}),
		field({apiName: 'Notes__c', label: 'Notes', type: 'TEXTAREA', isClassified: true, sensitivityLevel: 'Sensitive', matchStrength: 'Weak'}),
		field({apiName: 'ProfileUrl__c', label: 'Profile URL', type: 'URL', sensitivityLevel: 'NotSensitive', matchStrength: 'Weak', likelyMiss: true}),
		field({apiName: 'Nickname__c', label: 'Nickname', type: 'STRING', sensitivityLevel: 'NotSensitive', matchStrength: 'Weak'})
	]
};

// A reconciliation fixture: CardField__c (STRING) is recommended Mask_Card, which is already active
// object-wide on STRING — the duplicate candidate must be suppressed. Covered__c is recommended Mask_SSN,
// which is already an active field target — also suppressed.
const MOCK_ANALYSIS_RECONCILE = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: MOCK_OBJECT_WIDE_RULES, fields: [
		field({
			apiName: 'CardField__c',
			label: 'Card Field',
			type: 'STRING',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_Card',
			recommendedRuleLabel: 'Mask Credit Card',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong'
		}),
		field({
			apiName: 'Covered__c',
			label: 'Covered',
			type: 'STRING',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_SSN',
			recommendedRuleLabel: 'Mask SSN',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong',
			appliedRules: [
				{targetDeveloperName: 'T_Cov', ruleDeveloperName: 'Mask_SSN', ruleLabel: 'Mask SSN', isActive: true, callerClass: ''}
			]
		})
	]
};

// A multi-mask fixture: Phone (PHONE) concept-matches BOTH the US and the international phone rule, so the
// row carries two recommendedRules — each must pre-tick as its own candidate chip and become its own create.
const MOCK_ANALYSIS_MULTI_MASK = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, objectWideRules: [], rules: [
		{developerName: 'Mask_PhoneUS', label: 'Mask US Phone Numbers', category: 'Contact', mode: 'Regex', isActive: false, applicableFieldTypes: [], description: 'US phone'},
		{
			developerName: 'Mask_PhoneIntl',
			label: 'Mask International Phone Numbers',
			category: 'Contact',
			mode: 'Regex',
			isActive: false,
			applicableFieldTypes: [],
			description: 'International phone'
		}
	], fields: [
		field({
			apiName: 'Phone',
			label: 'Phone',
			type: 'PHONE',
			recommendedRuleDeveloperName: 'Mask_PhoneUS',
			recommendedRuleLabel: 'Mask US Phone Numbers',
			recommendedRuleIsActive: false,
			recommendedRules: [
				{developerName: 'Mask_PhoneUS', label: 'Mask US Phone Numbers', isActive: false},
				{developerName: 'Mask_PhoneIntl', label: 'Mask International Phone Numbers', isActive: false}
			],
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong'
		})
	]
};

// An object with no object-wide masking at all (drives the "has no object-wide masking yet" banner).
const MOCK_ANALYSIS_NO_OBJECT_WIDE = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [], fields: [
		field({
			apiName: 'SSN__c',
			label: 'SSN',
			type: 'STRING',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_SSN',
			recommendedRuleLabel: 'Mask SSN',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong'
		})
	]
};

// A single inactive object-wide rule (singular health-summary path) and no dead field targets.
const MOCK_ANALYSIS_ONE_INACTIVE_OW = {
	classificationAvailable: true,
	newRuleSetupUrl: NEW_RULE_SETUP_URL,
	rules: MOCK_RULE_CATALOGUE,
	objectWideRules: [{targetDeveloperName: 'OW_Phone', ruleDeveloperName: 'Mask_Phone', ruleLabel: 'Mask Phone', isActive: false, callerClass: ''}],
	fields: [
		field({
			apiName: 'SSN__c',
			label: 'SSN',
			type: 'STRING',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_SSN',
			recommendedRuleLabel: 'Mask SSN',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong'
		})
	]
};

// Two inactive object-wide rules + two dead field targets — exercises the plural health summaries + detail.
const MOCK_ANALYSIS_HEALTH_PLURAL = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [
		{targetDeveloperName: 'OW_Phone', ruleDeveloperName: 'Mask_Phone', ruleLabel: 'Mask Phone', isActive: false, callerClass: ''},
		{targetDeveloperName: 'OW_Street', ruleDeveloperName: 'Mask_Street', ruleLabel: 'Mask Street', isActive: false, callerClass: ''}
	], fields: [
		field({
			apiName: 'A__c', label: 'A', type: 'STRING', isClassified: true, sensitivityLevel: 'Sensitive', matchStrength: 'Strong', appliedRules: [
				{targetDeveloperName: 'T_A', ruleDeveloperName: 'Mask_SSN', ruleLabel: 'Mask SSN', isActive: false, callerClass: ''}
			]
		}),
		field({
			apiName: 'B__c', label: 'B', type: 'STRING', isClassified: true, sensitivityLevel: 'Sensitive', matchStrength: 'Strong', appliedRules: [
				{targetDeveloperName: 'T_B', ruleDeveloperName: 'Mask_Card', ruleLabel: 'Mask Credit Card', isActive: false, callerClass: ''}
			]
		})
	]
};

// One active object-wide rule (none inactive) + one dead field target — health banner shows the dead
// summary only, and the object-wide detail line is suppressed.
const MOCK_ANALYSIS_DEAD_ONLY = {
	classificationAvailable: true,
	newRuleSetupUrl: NEW_RULE_SETUP_URL,
	rules: MOCK_RULE_CATALOGUE,
	objectWideRules: [{targetDeveloperName: 'OW_Card', ruleDeveloperName: 'Mask_Card', ruleLabel: 'Mask Credit Card', isActive: true, callerClass: ''}],
	fields: [
		field({
			apiName: 'C__c', label: 'C', type: 'STRING', isClassified: true, sensitivityLevel: 'Sensitive', matchStrength: 'Strong', appliedRules: [
				{targetDeveloperName: 'T_C', ruleDeveloperName: 'Mask_SSN', ruleLabel: 'Mask SSN', isActive: false, callerClass: ''}
			]
		})
	]
};

// A dormant-rule candidate: Gap__c is recommended Mask_Street (isActive false) and has no applied rule —
// ticking its candidate must list Mask_Street once in rulesToActivate.
const MOCK_ANALYSIS_DORMANT = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [], fields: [
		field({
			apiName: 'Gap__c',
			label: 'Gap',
			type: 'STRING',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_Street',
			recommendedRuleLabel: 'Mask Street',
			recommendedRuleIsActive: false,
			sensitivityLevel: 'PossiblySensitive',
			matchStrength: 'Moderate'
		})
	]
};

// Object-wide rules exercising the type filter edges: Mask_Generic lists no applicable types (applies to
// every field), and Mask_Unknown is absent from the rule catalogue (must be skipped as a context chip).
const MOCK_ANALYSIS_OW_TYPES = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [
		{targetDeveloperName: 'OW_Gen', ruleDeveloperName: 'Mask_Generic', ruleLabel: 'Mask Generic', isActive: true, callerClass: ''},
		{targetDeveloperName: 'OW_Missing', ruleDeveloperName: 'Mask_Unknown', ruleLabel: 'Mask Unknown', isActive: true, callerClass: ''}
	], fields: [
		field({
			apiName: 'F1__c',
			label: 'F1',
			type: 'URL',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_SSN',
			recommendedRuleLabel: 'Mask SSN',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong'
		})
	]
};

// An object with only EMAIL + PHONE fields and no object-wide rules — exercises the add-object-wide menu's
// applicable-types line and the no-match warning: a TEXTAREA-only rule (Mask_Secret) matches no field here,
// while Mask_Phone (matches PHONE) and Mask_Generic (all text-shaped) do not warn.
const MOCK_ANALYSIS_ADD_TYPES = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [], fields: [
		field({apiName: 'Email', label: 'Email', type: 'EMAIL', isClassified: true, sensitivityLevel: 'Sensitive', matchStrength: 'Strong'}),
		field({apiName: 'Phone__c', label: 'Phone', type: 'PHONE', sensitivityLevel: 'PossiblySensitive', matchStrength: 'Moderate'})
	]
};

// A minimal analysis (raw, not via field()) that omits objectWideRules, newRuleSetupUrl, and per-field
// appliedRules — exercises the defensive fallbacks for a sparse controller response.
const MOCK_ANALYSIS_MINIMAL = {
	classificationAvailable: true, fields: [
		{
			apiName: 'Bare__c',
			label: 'Bare',
			type: 'STRING',
			isClassified: true,
			heuristicConfidence: null,
			recommendedRuleDeveloperName: 'Mask_SSN',
			recommendedRuleLabel: 'Mask SSN',
			recommendedRuleIsActive: true,
			recommendedRules: [{developerName: 'Mask_SSN', label: 'Mask SSN', isActive: true}],
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong',
			likelyMiss: false
		}
	]
};

// A MEDIUM-confidence heuristic flag with no template rule — routes to Needs review.
const MOCK_ANALYSIS_MEDIUM = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [], fields: [
		field({apiName: 'Region__c', label: 'Region', type: 'STRING', heuristicConfidence: 'MEDIUM', sensitivityLevel: 'PossiblySensitive', matchStrength: 'Moderate'})
	]
};

// A LOW-confidence heuristic match now lands in All other fields, tagged and floated above the rest (the
// standalone toggle is retired). A Ready anchor (SSN__c), a likely-miss URL, and a plain row exercise the
// Other ordering: low-confidence match first, then likely-miss, then alphabetical.
const MOCK_ANALYSIS_LOW = {
	classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [], fields: [
		field({
			apiName: 'SSN__c',
			label: 'SSN',
			type: 'STRING',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_SSN',
			recommendedRuleLabel: 'Mask SSN',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong'
		}),
		field({apiName: 'CardNickname__c', label: 'Card Nickname', type: 'STRING', heuristicConfidence: 'LOW', sensitivityLevel: 'PossiblySensitive', matchStrength: 'Weak'}),
		field({apiName: 'Aaa_Profile__c', label: 'Aaa Profile', type: 'URL', sensitivityLevel: 'NotSensitive', matchStrength: 'Weak', likelyMiss: true}),
		field({apiName: 'Zzz_Note__c', label: 'Zzz Note', type: 'STRING', sensitivityLevel: 'NotSensitive', matchStrength: 'Weak', likelyMiss: false})
	]
};

const MOCK_ANALYSIS_HEURISTIC_ONLY = {
	classificationAvailable: false, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [], fields: [
		field({apiName: 'SSN__c', label: 'SSN', type: 'STRING', heuristicConfidence: 'HIGH', sensitivityLevel: 'Sensitive', matchStrength: 'Weak'})
	]
};

// A large maskable-Other set to exercise the row cap: missCount likely-miss URL rows (sort first) followed
// by nonMissCount plain-text non-miss rows. No object-wide rules so context chips never appear.
function buildLargeOtherAnalysis(missCount, nonMissCount)
{
	const fields = [];
	for(let index = 0; index < missCount; index += 1)
	{
		fields.push(field({apiName: `Miss_${index}__c`, label: `Miss ${index}`, type: 'URL', sensitivityLevel: 'NotSensitive', matchStrength: 'Weak', likelyMiss: true}));
	}
	for(let index = 0; index < nonMissCount; index += 1)
	{
		fields.push(field({apiName: `Plain_${index}__c`, label: `Plain ${index}`, type: 'STRING', sensitivityLevel: 'NotSensitive', matchStrength: 'Weak', likelyMiss: false}));
	}
	return {classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [], fields};
}

// The default export bundle a test gets back from generateConfiguration ('QUJD' decodes to 'ABC'). A test
// can pass `generate` (a value or a function of the params) to vary it — e.g. `() => undefined` to model a
// swallowed controller failure.
const STUB_BUNDLE = {files: {'README.md': '# masking'}, zipBase64: 'QUJD'};

const STUB_POSTURE = {objectsWithActiveTargets: 3, activeFieldTargetCount: 5, sObjectWideTargetCount: 2, deadConfigCount: 1};

const STUB_INVENTORY = [
	{
		objectApiName: 'ApiCall__c', objectLabel: 'API Call', ruleLabels: [
			'Mask Credit Card',
			'Mask Secret Keys'
		], objectWideTargetCount: 2, fieldTargetCount: 0, deadCount: 1
	},
	{objectApiName: 'Contact', objectLabel: 'Contact', ruleLabels: ['Mask Email'], objectWideTargetCount: 0, fieldTargetCount: 4, deadCount: 0}
];

// Object lists for the custom-object coverage scan: one standard, three own custom objects, one
// managed-package custom object. The scan candidate population is the own custom objects by default.
const MOCK_SCAN_OBJECTS = [
	{apiName: 'Account', label: 'Account', isCustom: false, namespacePrefix: null},
	{apiName: 'CustomerFeedback__c', label: 'Customer Feedback', isCustom: true, namespacePrefix: null},
	{apiName: 'SupportTranscript__c', label: 'Support Transcript', isCustom: true, namespacePrefix: null},
	{apiName: 'DeliveryRoute__c', label: 'Delivery Route', isCustom: true, namespacePrefix: null},
	{apiName: 'blng__PaymentGatewayLog__c', label: 'Payment Gateway Log', isCustom: true, namespacePrefix: 'blng'}
];

// Per-object assessments the assessObjectCoverage mock returns. Two own custom objects require
// attention (one with a Long Text Area flagged field), one is clean, and the managed object — only
// scanned when managed objects are opted in — also requires attention.
const SCAN_ASSESSMENTS = {
	CustomerFeedback__c: {
		objectApiName: 'CustomerFeedback__c', objectLabel: 'Customer Feedback', hasActiveMasking: false, requiresAttention: true, flaggedFields: [
			{fieldApiName: 'CustomerEmail__c', fieldLabel: 'Customer Email', sensitivityLevel: 'Sensitive', isLongTextArea: false},
			{fieldApiName: 'FeedbackBody__c', fieldLabel: 'Feedback Body', sensitivityLevel: 'PossiblySensitive', isLongTextArea: true}
		]
	},
	SupportTranscript__c: {
		objectApiName: 'SupportTranscript__c', objectLabel: 'Support Transcript', hasActiveMasking: false, requiresAttention: true, flaggedFields: [
			{fieldApiName: 'TranscriptBody__c', fieldLabel: 'Transcript Body', sensitivityLevel: 'Sensitive', isLongTextArea: true}
		]
	},
	DeliveryRoute__c: {objectApiName: 'DeliveryRoute__c', objectLabel: 'Delivery Route', hasActiveMasking: false, requiresAttention: false, flaggedFields: []},
	'blng__PaymentGatewayLog__c': {
		objectApiName: 'blng__PaymentGatewayLog__c', objectLabel: 'Payment Gateway Log', hasActiveMasking: false, requiresAttention: true, flaggedFields: [
			{fieldApiName: 'blng__GatewayResponse__c', fieldLabel: 'Gateway Response', sensitivityLevel: 'Sensitive', isLongTextArea: true}
		]
	}
};

function cleanAssessment(apiName)
{
	return {objectApiName: apiName, objectLabel: apiName, hasActiveMasking: false, requiresAttention: false, flaggedFields: []};
}

function defaultAssess(apiName)
{
	return SCAN_ASSESSMENTS[apiName] || cleanAssessment(apiName);
}

function configureApex({
	objects = MOCK_OBJECTS,
	dead = MOCK_DEAD_CONFIG,
	analysis = MOCK_ANALYSIS_MIXED,
	generate = STUB_BUNDLE,
	posture = STUB_POSTURE,
	inventory = STUB_INVENTORY,
	assess = defaultAssess
} = {})
{
	mockCallControllerMethod.mockImplementation(async(apexFn, params) =>
	{
		if(apexFn === listObjects)
		{
			return objects;
		}
		if(apexFn === assessObjectCoverage)
		{
			return assess(params.objectApiName);
		}
		if(apexFn === getDeadConfigurations)
		{
			return dead;
		}
		if(apexFn === describeFields)
		{
			return analysis;
		}
		if(apexFn === generateConfiguration)
		{
			return typeof generate === 'function' ? generate(params) : generate;
		}
		if(apexFn === getOrgPostureSummary)
		{
			return typeof posture === 'function' ? posture(params) : posture;
		}
		if(apexFn === getOrgPostureInventory)
		{
			return typeof inventory === 'function' ? inventory(params) : inventory;
		}
		return {};
	});
}

// Flushes the microtask queue a few times so an awaited Apex mock resolves and LWC re-renders.
async function flush()
{
	await Promise.resolve();
	await Promise.resolve();
	await Promise.resolve();
}

async function createAdvisor(options = {})
{
	configureApex(options);
	const element = createElement('c-data-masking-advisor', {is: DataMaskingAdvisor});
	document.body.appendChild(element);
	await flush();
	await flush();
	return element;
}

// Selects an object the way the UI now does it: the "＋ Add object" button opens the grouped dialog
// (stubbed) which resolves the picked api name. When a field screen is already showing, first click
// "← All objects" so the landing's add-object entry is back, mirroring the real switch-object flow.
async function selectObject(element, apiName)
{
	const back = element.shadowRoot.querySelector('[data-testid="back-to-all-objects"]');
	if(back)
	{
		back.click();
		await flush();
	}
	mockMaskingAddObjectDialogOpen.mockResolvedValueOnce(apiName);
	element.shadowRoot.querySelector('[data-testid="add-object-button"]').click();
	await flush();
	await flush();
	await flush();
}

function rowByApi(element, apiName)
{
	return Array.from(element.shadowRoot.querySelectorAll('[data-api-name]'))
	.find((node) => node.dataset.apiName === apiName && (node.dataset.testid === 'field-row' || node.dataset.testid === 'manual-review-row' || node.dataset.testid
			=== 'other-field-row'));
}

// The tickable field-level chip span for a given rule in a given row.
function fieldChip(element, apiName, ruleDeveloperName)
{
	const row = rowByApi(element, apiName);
	return Array.from(row.querySelectorAll('[data-testid="field-chip"]')).find((chip) => chip.dataset.rule === ruleDeveloperName);
}

// The object-wide banner chip span for a given rule.
function objectWideChip(element, ruleDeveloperName)
{
	return Array.from(element.shadowRoot.querySelectorAll('[data-testid="object-wide-chip"]')).find((chip) => chip.dataset.rule === ruleDeveloperName);
}

function toggleChip(chip)
{
	const box = chip.querySelector('[data-toggle-key]');
	box.dispatchEvent(new CustomEvent('change'));
}

function textOf(element, testId)
{
	const node = element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
	return node ? node.textContent : null;
}

function expandObjectWideBanner(element)
{
	element.shadowRoot.querySelector('[data-testid="object-wide-banner-toggle"]').click();
}

async function selectMixed(element)
{
	await selectObject(element, 'Account');
}

function cleanup()
{
	while(document.body.firstChild)
	{
		document.body.removeChild(document.body.firstChild);
	}
	jest.restoreAllMocks();
	jest.clearAllMocks();
	window.sessionStorage.clear();
}

describe('c-data-masking-advisor — mount + bootstrap', () =>
{
	afterEach(cleanup);

	it('calls listObjects and getDeadConfigurations on connectedCallback', async() =>
	{
		const element = await createAdvisor();
		expect(mockCallControllerMethod).toHaveBeenCalledWith(listObjects);
		expect(mockCallControllerMethod).toHaveBeenCalledWith(getDeadConfigurations);
		expect(element).toBeTruthy();
	});

	it('renders the "＋ Add object" button on the landing instead of a flat picker', async() =>
	{
		const element = await createAdvisor();
		expect(element.shadowRoot.querySelector('[data-testid="add-object-button"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="object-picker"]')).toBeNull();
	});

	it('opens the add-object dialog seeded with the object universe, scan results, and masked api names', async() =>
	{
		const element = await createAdvisor();
		element.shadowRoot.querySelector('[data-testid="add-object-button"]').click();
		await flush();

		expect(mockMaskingAddObjectDialogOpen).toHaveBeenCalledTimes(1);
		const props = mockMaskingAddObjectDialogOpen.mock.calls[0][0];
		expect(props.objectOptions).toHaveLength(MOCK_OBJECTS.length);
		expect(Array.isArray(props.flaggedObjects)).toBe(true);
		expect(Array.isArray(props.maskedApiNames)).toBe(true);
	});

	it('returns focus to the "＋ Add object" button when the dialog is dismissed', async() =>
	{
		mockMaskingAddObjectDialogOpen.mockResolvedValueOnce(null);
		const element = await createAdvisor();
		const trigger = element.shadowRoot.querySelector('[data-testid="add-object-button"]');
		trigger.click();
		await flush();
		await flush();

		expect(element.shadowRoot.activeElement).toBe(trigger);
	});

	it('renders the "⤓ Export field inventory" button on the landing', async() =>
	{
		const element = await createAdvisor();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-button"]')).not.toBeNull();
	});

	it('keeps the export button reachable even when the org-wide posture fails to load', async() =>
	{
		const element = await createAdvisor({posture: null});
		expect(element.shadowRoot.querySelector('[data-testid="posture-summary"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="inventory-export-button"]')).not.toBeNull();
	});

	it('opens the inventory export dialog seeded with the object universe and the masked api names', async() =>
	{
		const element = await createAdvisor();
		element.shadowRoot.querySelector('[data-testid="inventory-export-button"]').click();
		await flush();

		expect(mockMaskingInventoryExportDialogOpen).toHaveBeenCalledTimes(1);
		const props = mockMaskingInventoryExportDialogOpen.mock.calls[0][0];
		expect(props.objectOptions).toHaveLength(MOCK_OBJECTS.length);
		expect(Array.isArray(props.maskedApiNames)).toBe(true);
	});

	it('returns focus to the export button when the inventory dialog is dismissed', async() =>
	{
		mockMaskingInventoryExportDialogOpen.mockResolvedValueOnce(null);
		const element = await createAdvisor();
		const trigger = element.shadowRoot.querySelector('[data-testid="inventory-export-button"]');
		trigger.click();
		await flush();
		await flush();

		expect(element.shadowRoot.activeElement).toBe(trigger);
	});

	it('renders the scope-banner paragraph at the top of the card', async() =>
	{
		const element = await createAdvisor();
		expect(textOf(element, 'scope-banner')).toContain('does not encrypt data at rest');
	});

	it('shows the org-wide posture summary (not the smart list) before any object is picked', async() =>
	{
		const element = await createAdvisor();
		expect(element.shadowRoot.querySelector('[data-testid="posture-summary"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="summary-strip"]')).toBeNull();
	});
});

describe('c-data-masking-advisor — dead-config banner', () =>
{
	afterEach(cleanup);

	it('renders the warning banner with one list item per finding', async() =>
	{
		const element = await createAdvisor();
		expect(element.shadowRoot.querySelector('[data-testid="dead-config-banner"]')).not.toBeNull();
		expect(element.shadowRoot.querySelectorAll('[data-testid="dead-config-item"]')).toHaveLength(MOCK_DEAD_CONFIG.length);
	});

	it('does NOT render the banner when there are no findings', async() =>
	{
		const element = await createAdvisor({dead: []});
		expect(element.shadowRoot.querySelector('[data-testid="dead-config-banner"]')).toBeNull();
	});

	it('uses the singular summary copy when exactly one finding is returned', async() =>
	{
		const element = await createAdvisor({dead: [MOCK_DEAD_CONFIG[0]]});
		expect(element.shadowRoot.querySelector('[data-testid="dead-config-banner"] p').textContent).toContain('1 active masking target is');
	});

	it('swallows a getDeadConfigurations failure without breaking the rest of the component', async() =>
	{
		mockCallControllerMethod.mockImplementation(async(apexFn) =>
		{
			if(apexFn === listObjects)
			{
				return MOCK_OBJECTS;
			}
			if(apexFn === getDeadConfigurations)
			{
				throw new Error('boom');
			}
			if(apexFn === getOrgPostureSummary)
			{
				return STUB_POSTURE;
			}
			return {};
		});
		const element = createElement('c-data-masking-advisor', {is: DataMaskingAdvisor});
		document.body.appendChild(element);
		await flush();
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="dead-config-banner"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="add-object-button"]')).not.toBeNull();
	});
});

describe('c-data-masking-advisor — object selection → describeFields', () =>
{
	afterEach(cleanup);

	it('calls describeFields with the picked object api name', async() =>
	{
		const element = await createAdvisor();
		await selectObject(element, 'Account');
		expect(mockCallControllerMethod).toHaveBeenCalledWith(describeFields, {objectApiName: 'Account'});
	});

	it('shows the heuristic-only-mode notice when classificationAvailable === false', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_HEURISTIC_ONLY});
		await selectObject(element, 'Account');
		expect(element.shadowRoot.querySelector('[data-testid="heuristic-only-notice"]')).not.toBeNull();
	});

	it('does NOT show the heuristic-only-mode notice when classificationAvailable === true', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="heuristic-only-notice"]')).toBeNull();
	});

	it('returns to the posture landing (no error, smart list hidden) via "← All objects"', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="summary-strip"]')).not.toBeNull();
		element.shadowRoot.querySelector('[data-testid="back-to-all-objects"]').click();
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="summary-strip"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="posture-summary"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="coverage-advisor-error"]')).toBeNull();
	});

	it('renders the load-failed error box when describeFields throws', async() =>
	{
		mockCallControllerMethod.mockImplementation(async(apexFn) =>
		{
			if(apexFn === listObjects)
			{
				return MOCK_OBJECTS;
			}
			if(apexFn === getDeadConfigurations)
			{
				return [];
			}
			if(apexFn === getOrgPostureSummary)
			{
				return STUB_POSTURE;
			}
			if(apexFn === describeFields)
			{
				throw new Error('describe failed');
			}
			return {};
		});
		const element = createElement('c-data-masking-advisor', {is: DataMaskingAdvisor});
		document.body.appendChild(element);
		await flush();
		await flush();
		await selectObject(element, 'Account');
		expect(element.shadowRoot.querySelector('[data-testid="coverage-advisor-error"]')).not.toBeNull();
	});
});

describe('c-data-masking-advisor — low-confidence retag', () =>
{
	afterEach(cleanup);

	it('retires the standalone low-confidence toggle', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_LOW});
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="low-confidence-toggle"]')).toBeNull();
	});

	it('tags a low-confidence match and floats it to the top of All other fields', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_LOW});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		const otherRows = Array.from(element.shadowRoot.querySelectorAll('[data-testid="other-field-row"]')).map((row) => row.dataset.apiName);
		expect(otherRows).toEqual([
			'CardNickname__c',
			'Aaa_Profile__c',
			'Zzz_Note__c'
		]);
		// The low-confidence match carries the tag; a plain Other row does not.
		expect(rowByApi(element, 'CardNickname__c').querySelector('[data-testid="low-confidence-tag"]')).not.toBeNull();
		expect(rowByApi(element, 'Zzz_Note__c').querySelector('[data-testid="low-confidence-tag"]')).toBeNull();
	});
});

describe('c-data-masking-advisor — summary strip + sections', () =>
{
	afterEach(cleanup);

	it('renders the ready / to-review / other stats from the real section counts', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(textOf(element, 'summary-ready')).toBe('2 ready');
		expect(textOf(element, 'summary-to-review')).toBe('1 to review');
		expect(textOf(element, 'summary-other')).toBe('2 other');
	});

	it('renders the Ready and Needs-review sections, with Other collapsed by default', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="section-ready"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="section-manual-review"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="section-other"]')).not.toBeNull();
		expect(rowByApi(element, 'ProfileUrl__c')).toBeUndefined();
	});

	it('expands the Other section to show its rows likely-misses first', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		const otherRows = Array.from(element.shadowRoot.querySelectorAll('[data-testid="other-field-row"]')).map((row) => row.dataset.apiName);
		expect(otherRows).toEqual([
			'ProfileUrl__c',
			'Nickname__c'
		]);
	});

	it('routes a MEDIUM-confidence heuristic-flagged field into Needs review', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_MEDIUM});
		await selectMixed(element);
		expect(rowByApi(element, 'Region__c').dataset.testid).toBe('manual-review-row');
	});

	it('collapses the Needs-review rows when its toggle is clicked', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(rowByApi(element, 'Notes__c')).not.toBeUndefined();
		element.shadowRoot.querySelector('[data-testid="section-manual-review-toggle"]').click();
		await flush();
		expect(rowByApi(element, 'Notes__c')).toBeUndefined();
	});
});

describe('c-data-masking-advisor — Other card scale', () =>
{
	afterEach(cleanup);

	it('caps the rendered Other rows on the full sorted set, surfaces a cap note, and keeps the counter at the full count', async() =>
	{
		const element = await createAdvisor({analysis: buildLargeOtherAnalysis(150, 120)});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		expect(element.shadowRoot.querySelectorAll('[data-testid="other-field-row"]')).toHaveLength(200);
		expect(element.shadowRoot.querySelector('[data-testid="other-row-cap-note"]')).not.toBeNull();
		expect(textOf(element, 'summary-other')).toBe('270 other');
	});

	it('caps on the filtered render source: misses-only renders just the likely misses with no cap note', async() =>
	{
		const element = await createAdvisor({analysis: buildLargeOtherAnalysis(40, 300)});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		element.shadowRoot.querySelector('[data-testid="other-misses-toggle"]').dispatchEvent(new CustomEvent('change', {detail: {checked: true}}));
		await flush();
		expect(element.shadowRoot.querySelectorAll('[data-testid="other-field-row"]')).toHaveLength(40);
		expect(element.shadowRoot.querySelector('[data-testid="other-row-cap-note"]')).toBeNull();
		expect(textOf(element, 'summary-other')).toBe('340 other');
	});

	it('does NOT render the cap note for a small Other set', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="other-row-cap-note"]')).toBeNull();
	});
});

describe('c-data-masking-advisor — sensitivity badge + signal band', () =>
{
	afterEach(cleanup);

	it('renders the Sensitive badge with its display label and variant token on a Ready row', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		const badge = rowByApi(element, 'SSN__c').querySelector('[data-testid="sensitivity-badge"]');
		expect(badge.dataset.sensitivity).toBe('Sensitive');
		expect(badge.textContent).toContain('Sensitive');
	});

	it('renders a Strong signal band with three lit bars', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		const band = rowByApi(element, 'SSN__c').querySelector('[data-testid="signal-band"]');
		expect(band.dataset.signal).toBe('Strong');
		expect(Array.from(band.querySelectorAll('.dma-conf__bar')).filter((bar) => bar.dataset.lit === 'true')).toHaveLength(3);
	});

	it('renders a Weak signal band with one lit bar on a Needs-review row', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		const band = rowByApi(element, 'Notes__c').querySelector('[data-testid="signal-band"]');
		expect(band.dataset.signal).toBe('Weak');
		expect(Array.from(band.querySelectorAll('.dma-conf__bar')).filter((bar) => bar.dataset.lit === 'true')).toHaveLength(1);
	});
});

describe('c-data-masking-advisor — masking cell chips', () =>
{
	afterEach(cleanup);

	it('renders an active applied chip ticked and an inactive applied chip unticked with the inactive glyph', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		const activeChip = fieldChip(element, 'SSN__c', 'Mask_SSN');
		expect(activeChip.dataset.origin).toBe('active');
		expect(activeChip.dataset.desired).toBe('true');
		expect(activeChip.querySelector('.dma-chip__box').checked).toBe(true);
		const inactiveChip = fieldChip(element, 'SSN__c', 'Mask_Street');
		expect(inactiveChip.dataset.origin).toBe('inactive');
		expect(inactiveChip.dataset.desired).toBe('false');
		expect(inactiveChip.querySelector('.dma-chip__glyph').textContent).toBe('⚠');
	});

	it('renders a recommendation as a ticked candidate chip', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		const chip = fieldChip(element, 'Email', 'Mask_Generic');
		expect(chip.dataset.origin).toBe('candidate');
		expect(chip.dataset.desired).toBe('true');
		expect(chip.querySelector('.dma-chip__flag').textContent).toBe('to add');
	});

	it('pre-ticks every concept-matched recommended rule as its own candidate chip (a phone field offers both phone rules)', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_MULTI_MASK});
		await selectObject(element, 'Account');
		const usChip = fieldChip(element, 'Phone', 'Mask_PhoneUS');
		const intlChip = fieldChip(element, 'Phone', 'Mask_PhoneIntl');
		expect(usChip.dataset.origin).toBe('candidate');
		expect(usChip.dataset.desired).toBe('true');
		expect(intlChip.dataset.origin).toBe('candidate');
		expect(intlChip.dataset.desired).toBe('true');
		expect(Array.from(rowByApi(element, 'Phone').querySelectorAll('[data-testid="field-chip"]')).map((chip) => chip.dataset.rule)).toEqual(expect.arrayContaining([
			'Mask_PhoneUS',
			'Mask_PhoneIntl'
		]));
	});

	it('exports a create target plus an activation for each pre-ticked phone candidate', async() =>
	{
		const captured = [];
		const element = await createAdvisor({
			analysis: MOCK_ANALYSIS_MULTI_MASK, generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectObject(element, 'Account');
		expect(textOf(element, 'summary-changes')).toBe('2 changes');
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		expect(captured[0].targets.map((target) => target.ruleDeveloperName)).toEqual(expect.arrayContaining([
			'Mask_PhoneUS',
			'Mask_PhoneIntl'
		]));
		captured[0].targets.forEach((target) => expect(target.isActive).toBe(true));
		expect(captured[0].rulesToActivate).toEqual(expect.arrayContaining([
			'Mask_PhoneUS',
			'Mask_PhoneIntl'
		]));
	});

	it('renders object-wide context chips filtered to the field type (a JSON-only rule skips a URL field)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		const urlContext = Array.from(rowByApi(element, 'ProfileUrl__c').querySelectorAll('[data-testid="object-wide-context-chip"]')).map((chip) => chip.dataset.rule);
		expect(urlContext).toEqual(['Mask_Card']);
		const notesContext = Array.from(rowByApi(element, 'Notes__c').querySelectorAll('[data-testid="object-wide-context-chip"]')).map((chip) => chip.dataset.rule);
		expect(notesContext).toEqual([
			'Mask_Card',
			'Mask_Secret'
		]);
	});

	it('suppresses a recommendation candidate already covered by an active object-wide rule or an active field target', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_RECONCILE});
		await selectMixed(element);
		expect(fieldChip(element, 'CardField__c', 'Mask_Card')).toBeUndefined();
		expect(Array.from(rowByApi(element, 'CardField__c').querySelectorAll('[data-testid="field-chip"]'))).toHaveLength(0);
		expect(Array.from(rowByApi(element, 'Covered__c').querySelectorAll('[data-testid="field-chip"]')).map((chip) => chip.dataset.rule)).toEqual(['Mask_SSN']);
	});

	it('toggling a chip flips its desired state and the summary changes count, and re-ticking clears it', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		// MIXED already has one change: Email's recommended Mask_Generic candidate is pre-ticked (a create).
		expect(textOf(element, 'summary-changes')).toBe('1 changes');
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('false');
		expect(textOf(element, 'summary-changes')).toBe('2 changes');
		// Re-tick the same chip to exercise the toggle-off (clear) path.
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('true');
		expect(textOf(element, 'summary-changes')).toBe('1 changes');
	});

	it('shows an object-wide rule with no type restriction on every field, and skips one whose rule is not in the catalogue', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_OW_TYPES});
		await selectMixed(element);
		const ctx = Array.from(rowByApi(element, 'F1__c').querySelectorAll('[data-testid="object-wide-context-chip"]')).map((chip) => chip.dataset.rule);
		expect(ctx).toEqual(['Mask_Generic']);
	});

	it('tolerates an analysis without object-wide rules, setup url, or per-field applied rules', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_MINIMAL});
		await selectMixed(element);
		expect(rowByApi(element, 'Bare__c')).not.toBeUndefined();
		expect(fieldChip(element, 'Bare__c', 'Mask_SSN').dataset.origin).toBe('candidate');
	});
});

describe('c-data-masking-advisor — object-wide coverage banner', () =>
{
	afterEach(cleanup);

	it('summarizes the active object-wide rules and renders the active + inactive chips when expanded', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(textOf(element, 'object-wide-banner-heading')).toBe('Account is masked object-wide by 2 active rules');
		expandObjectWideBanner(element);
		await flush();
		expect(objectWideChip(element, 'Mask_Card').dataset.origin).toBe('active');
		expect(objectWideChip(element, 'Mask_Phone').dataset.origin).toBe('inactive');
	});

	it('renders the banner even when the object has no object-wide rules, with the "none yet" heading + note', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_NO_OBJECT_WIDE});
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="object-wide-banner"]')).not.toBeNull();
		expect(textOf(element, 'object-wide-banner-heading')).toBe('Account has no object-wide masking yet');
		expandObjectWideBanner(element);
		await flush();
		expect(textOf(element, 'object-wide-banner-note')).toContain('object-wide rule runs on every field');
	});

	it('uses the singular heading when exactly one active object-wide rule masks the object', async() =>
	{
		const element = await createAdvisor({analysis: {...MOCK_ANALYSIS_NO_OBJECT_WIDE, objectWideRules: [MOCK_OBJECT_WIDE_RULES[0]]}});
		await selectMixed(element);
		expect(textOf(element, 'object-wide-banner-heading')).toBe('Account is masked object-wide by 1 active rule');
	});

	it('unticking an active object-wide chip drives a disable change', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();
		toggleChip(objectWideChip(element, 'Mask_Card'));
		await flush();
		expect(objectWideChip(element, 'Mask_Card').dataset.desired).toBe('false');
		expect(objectWideChip(element, 'Mask_Card').querySelector('.dma-chip__flag').textContent).toBe('will disable');
		// MIXED starts at 1 change (Email candidate); disabling Card adds a second.
		expect(textOf(element, 'summary-changes')).toBe('2 changes');
	});
});

describe('c-data-masking-advisor — configuration-health banner', () =>
{
	afterEach(cleanup);

	it('summarizes inactive object-wide rules + dead field targets and expands to detail', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		const heading = textOf(element, 'health-banner-heading');
		expect(heading).toContain('1 object-wide rule inactive');
		expect(heading).toContain('1 field target masking nothing');
		element.shadowRoot.querySelector('[data-testid="health-banner-toggle"]').click();
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="health-object-wide-detail"]')).not.toBeNull();
		expect(element.shadowRoot.querySelectorAll('[data-testid="health-dead-detail"]')).toHaveLength(1);
	});

	it('does NOT render the health banner when there are no inactive object-wide rules or dead targets', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_NO_OBJECT_WIDE});
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="health-banner"]')).toBeNull();
	});

	it('uses the singular object-wide detail line when exactly one object-wide rule is inactive', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_ONE_INACTIVE_OW});
		await selectMixed(element);
		expect(textOf(element, 'health-banner-heading')).toContain('1 object-wide rule inactive');
		element.shadowRoot.querySelector('[data-testid="health-banner-toggle"]').click();
		await flush();
		expect(textOf(element, 'health-object-wide-detail')).toContain('1 object-wide rule is configured');
		expect(element.shadowRoot.querySelector('[data-testid="health-dead-detail"]')).toBeNull();
	});

	it('uses plural object-wide + dead summaries and a plural object-wide detail line', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_HEALTH_PLURAL});
		await selectMixed(element);
		const heading = textOf(element, 'health-banner-heading');
		expect(heading).toContain('2 object-wide rules inactive');
		expect(heading).toContain('2 field targets masking nothing');
		element.shadowRoot.querySelector('[data-testid="health-banner-toggle"]').click();
		await flush();
		expect(textOf(element, 'health-object-wide-detail')).toContain('2 object-wide rules are configured');
		expect(element.shadowRoot.querySelectorAll('[data-testid="health-dead-detail"]')).toHaveLength(2);
	});

	it('shows only the dead-target summary + detail when no object-wide rule is inactive', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_DEAD_ONLY});
		await selectMixed(element);
		expect(textOf(element, 'health-banner-heading')).toContain('1 field target masking nothing');
		element.shadowRoot.querySelector('[data-testid="health-banner-toggle"]').click();
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="health-object-wide-detail"]')).toBeNull();
		expect(element.shadowRoot.querySelectorAll('[data-testid="health-dead-detail"]')).toHaveLength(1);
	});
});

describe('c-data-masking-advisor — export package (diff)', () =>
{
	afterEach(cleanup);

	it('disables the Export button when no changes are queued and shows the no-changes note', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_RECONCILE});
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="export-package-button"]').disabled).toBe(true);
		expect(element.shadowRoot.querySelector('[data-testid="no-changes-note"]')).not.toBeNull();
	});

	it('enables the Export button once a candidate is ticked (the recommendation defaults ticked)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="export-package-button"]').disabled).toBe(false);
		expect(element.shadowRoot.querySelector('[data-testid="no-changes-note"]')).toBeNull();
	});

	it('emits a create decision for a ticked candidate with a generated developer name', async() =>
	{
		const captured = [];
		const element = await createAdvisor({
			analysis: MOCK_ANALYSIS_NO_OBJECT_WIDE, generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		const request = captured[0];
		const create = request.targets.find((target) => target.ruleDeveloperName === 'Mask_SSN');
		expect(create.isActive).toBe(true);
		expect(create.field).toBe('SSN__c');
		expect(create.developerName).toBe('Mask_Account_SSN_Mask_SSN');
	});

	it('emits a disable decision carrying the existing developer name + caller class when an active chip is unticked', async() =>
	{
		const captured = [];
		const element = await createAdvisor({
			generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		const disable = captured[0].targets.find((target) => target.developerName === 'T_SSN');
		expect(disable.isActive).toBe(false);
		expect(disable.ruleDeveloperName).toBe('Mask_SSN');
		expect(disable.field).toBe('SSN__c');
	});

	it('emits a re-enable decision when an inactive field chip is ticked', async() =>
	{
		const captured = [];
		const element = await createAdvisor({
			generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_Street'));
		await flush();
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		const reEnable = captured[0].targets.find((target) => target.developerName === 'T_Street');
		expect(reEnable.isActive).toBe(true);
		expect(reEnable.callerClass).toBe('LegacyLoader');
	});

	it('lists a dormant bound rule once in rulesToActivate when its candidate is ticked', async() =>
	{
		const captured = [];
		const element = await createAdvisor({
			analysis: MOCK_ANALYSIS_DORMANT, generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		expect(captured[0].rulesToActivate).toEqual(['Mask_Street']);
	});

	it('emits a disable decision for an unticked active object-wide chip carrying its developer name', async() =>
	{
		const captured = [];
		const element = await createAdvisor({
			generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();
		toggleChip(objectWideChip(element, 'Mask_Card'));
		await flush();
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		const disable = captured[0].targets.find((target) => target.developerName === 'OW_Card');
		expect(disable.isActive).toBe(false);
		expect(disable.field).toBe('');
	});

	it('emits a re-enable decision for a ticked inactive object-wide chip', async() =>
	{
		const captured = [];
		const element = await createAdvisor({
			generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();
		toggleChip(objectWideChip(element, 'Mask_Phone'));
		await flush();
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		const reEnable = captured[0].targets.find((target) => target.developerName === 'OW_Phone');
		expect(reEnable.isActive).toBe(true);
		expect(reEnable.field).toBe('');
		expect(reEnable.callerClass).toBe('BillingService');
	});

	it('opens the export modal with grouped add/disable/re-enable contents', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_Street'));
		await flush();
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		const opened = mockMaskingExportModalOpen.mock.calls[0][0];
		expect(opened.objectApiName).toBe('Account');
		expect(opened.fileName).toBe('masking-configuration.zip');
		expect(opened.addRows).toEqual(expect.arrayContaining([{scope: 'F', fieldLabel: 'Email', ruleLabel: 'Mask Generic'}]));
		expect(opened.disableRows).toEqual(expect.arrayContaining([{scope: 'F', fieldLabel: 'SSN', ruleLabel: 'Mask SSN'}]));
		expect(opened.reEnableRows).toEqual(expect.arrayContaining([{scope: 'F', fieldLabel: 'SSN', ruleLabel: 'Mask Street'}]));
	});

	it('does not open the modal when generation returns no bundle', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_NO_OBJECT_WIDE, generate: () => undefined});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		expect(mockMaskingExportModalOpen).not.toHaveBeenCalled();
	});

	it('downloads the bundle as an application/zip blob when the modal resolves download', async() =>
	{
		mockMaskingExportModalOpen.mockResolvedValueOnce({action: 'download'});
		const created = [];
		const realCreate = document.createElement.bind(document);
		jest.spyOn(document, 'createElement').mockImplementation((tag) =>
		{
			const node = realCreate(tag);
			if(tag === 'a')
			{
				node.click = jest.fn();
				created.push(node);
			}
			return node;
		});
		const blobSpy = jest.fn().mockReturnValue('blob:url');
		window.URL.createObjectURL = blobSpy;
		const revokeSpy = jest.fn();
		window.URL.revokeObjectURL = revokeSpy;
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_NO_OBJECT_WIDE});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		expect(created[0].click).toHaveBeenCalled();
		expect(revokeSpy).toHaveBeenCalledWith('blob:url');
		expect(created[0].download).toBe('masking-configuration.zip');
		expect(blobSpy).toHaveBeenCalled();
	});

	it('does not download when the modal is cancelled (null)', async() =>
	{
		mockMaskingExportModalOpen.mockResolvedValueOnce(null);
		const blobSpy = jest.fn().mockReturnValue('blob:url');
		window.URL.createObjectURL = blobSpy;
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_NO_OBJECT_WIDE});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		expect(blobSpy).not.toHaveBeenCalled();
	});

	it('truncates an over-long target developer name to the 40-character metadata limit', async() =>
	{
		const longField = field({
			apiName: 'A_Very_Long_Custom_Field_Name_That_Exceeds__c',
			label: 'Long',
			type: 'STRING',
			isClassified: true,
			recommendedRuleDeveloperName: 'Mask_Generic',
			recommendedRuleLabel: 'Mask Generic',
			recommendedRuleIsActive: true,
			sensitivityLevel: 'Sensitive',
			matchStrength: 'Strong'
		});
		const analysis = {classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: MOCK_RULE_CATALOGUE, objectWideRules: [], fields: [longField]};
		const captured = [];
		const element = await createAdvisor({
			analysis, generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		expect(captured[0].targets[0].developerName.length).toBeLessThanOrEqual(40);
	});
});

describe('c-data-masking-advisor — open the reclassify dialog', () =>
{
	afterEach(cleanup);

	it('opens the Review dialog from a Ready row sensitivity badge with the field effective props', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		rowByApi(element, 'SSN__c').querySelector('[data-testid="sensitivity-badge"]').click();
		await flush();
		expect(mockMaskingReviewDialogOpen).toHaveBeenCalledWith(expect.objectContaining({fieldApiName: 'SSN__c', objectApiName: 'Account', sensitivityLevel: 'Sensitive'}));
	});

	it('opens the Review dialog from an Other row badge with the type-derived reason', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		rowByApi(element, 'ProfileUrl__c').querySelector('[data-testid="sensitivity-badge"]').click();
		await flush();
		expect(mockMaskingReviewDialogOpen)
		.toHaveBeenCalledWith(expect.objectContaining({fieldApiName: 'ProfileUrl__c', reason: expect.stringContaining('often holds sensitive data')}));
	});

	it('makes no change when the Review dialog is cancelled (null)', async() =>
	{
		mockMaskingReviewDialogOpen.mockResolvedValueOnce(null);
		const element = await createAdvisor();
		await selectMixed(element);
		rowByApi(element, 'SSN__c').querySelector('[data-testid="sensitivity-badge"]').click();
		await flush();
		expect(rowByApi(element, 'SSN__c').querySelector('[data-testid="override-marker"]')).toBeNull();
	});
});

describe('c-data-masking-advisor — reclassify override + revert', () =>
{
	afterEach(cleanup);

	it('moves a downgraded Ready row to Other, marks it, unticks its candidate, and bumps the changes summary', async() =>
	{
		mockMaskingReviewDialogOpen.mockResolvedValue({level: 'NotSensitive'});
		const element = await createAdvisor();
		await selectMixed(element);
		// Email is Ready with a ticked Mask_Generic candidate.
		rowByApi(element, 'Email').querySelector('[data-testid="sensitivity-badge"]').click();
		await flush();
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		const row = rowByApi(element, 'Email');
		expect(row.dataset.testid).toBe('other-field-row');
		expect(row.querySelector('[data-testid="override-marker"]').textContent).toContain('Marked not sensitive');
		expect(fieldChip(element, 'Email', 'Mask_Generic').dataset.desired).toBe('false');
		expect(mockShowSuccessToast).toHaveBeenCalled();
	});

	it('reverts a downgraded row back to Ready and re-ticks its candidate', async() =>
	{
		mockMaskingReviewDialogOpen.mockResolvedValue({level: 'NotSensitive'});
		const element = await createAdvisor();
		await selectMixed(element);
		rowByApi(element, 'Email').querySelector('[data-testid="sensitivity-badge"]').click();
		await flush();
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		rowByApi(element, 'Email').querySelector('[data-testid="revert-override"]').click();
		await flush();
		const row = rowByApi(element, 'Email');
		expect(row.dataset.testid).toBe('field-row');
		expect(fieldChip(element, 'Email', 'Mask_Generic').dataset.desired).toBe('true');
	});

	it('promotes an Other row to Needs review with an "added manually" marker', async() =>
	{
		mockMaskingReviewDialogOpen.mockResolvedValue({level: 'Sensitive'});
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		rowByApi(element, 'Nickname__c').querySelector('[data-testid="sensitivity-badge"]').click();
		await flush();
		const row = rowByApi(element, 'Nickname__c');
		expect(row.dataset.testid).toBe('manual-review-row');
		expect(row.querySelector('[data-testid="override-marker"]').textContent).toContain('Added manually');
	});

	it('preserves the candidate exclusion state when an already-downgraded field is re-applied', async() =>
	{
		mockMaskingReviewDialogOpen.mockResolvedValue({level: 'NotSensitive'});
		const element = await createAdvisor();
		await selectMixed(element);
		// Untick Email's candidate first, then downgrade twice; the revert must restore the unticked state.
		toggleChip(fieldChip(element, 'Email', 'Mask_Generic'));
		await flush();
		rowByApi(element, 'Email').querySelector('[data-testid="sensitivity-badge"]').click();
		await flush();
		mockMaskingReviewDialogOpen.mockResolvedValue({level: 'PossiblySensitive'});
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		// Re-applying a different override keeps the captured pre-state; revert restores the unticked candidate.
		rowByApi(element, 'Email').querySelector('[data-testid="revert-override"]').click();
		await flush();
		expect(fieldChip(element, 'Email', 'Mask_Generic').dataset.desired).toBe('false');
	});

	it('ignores a reclassify request for an unknown field without opening the dialog', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		// Point a real badge at a field that is not in the rendered set, so handleReview finds no row.
		const badge = rowByApi(element, 'SSN__c').querySelector('[data-testid="sensitivity-badge"]');
		badge.dataset.apiName = 'Ghost__c';
		badge.click();
		await flush();
		expect(mockMaskingReviewDialogOpen).not.toHaveBeenCalled();
	});

	it('promotes a Ready row (with a recommendation) and keeps it Ready with an "added manually" marker', async() =>
	{
		mockMaskingReviewDialogOpen.mockResolvedValue({level: 'Sensitive'});
		const element = await createAdvisor();
		await selectMixed(element);
		rowByApi(element, 'Email').querySelector('[data-testid="sensitivity-badge"]').click();
		await flush();
		const row = rowByApi(element, 'Email');
		expect(row.dataset.testid).toBe('field-row');
		expect(row.querySelector('[data-testid="override-marker"]').textContent).toContain('Added manually');
	});
});

describe('c-data-masking-advisor — session draft (sessionStorage)', () =>
{
	afterEach(cleanup);

	function storedDraft(objectApiName)
	{
		return JSON.parse(window.sessionStorage.getItem(`kern-masking-draft:${objectApiName}`));
	}

	it('persists a chip toggle to the per-object draft key', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		const draft = storedDraft('Account');
		expect(draft.version).toBe(4);
		expect(draft.disabled['F|SSN__c|Mask_SSN']).toBe(true);
	});

	it('restores a chip toggle from a pre-existing draft on object load', async() =>
	{
		window.sessionStorage.setItem('kern-masking-draft:Account', JSON.stringify(
				{version: 4, overrides: {}, selectionBefore: {}, disabled: {'F|SSN__c|Mask_SSN': true}, enabled: {}, excluded: {}, addedFieldRules: {}, addedObjectWideRules: []}));
		const element = await createAdvisor();
		await selectMixed(element);
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('false');
	});

	it('restores a reclassify override from a draft', async() =>
	{
		window.sessionStorage.setItem('kern-masking-draft:Account', JSON.stringify({
			version: 4,
			overrides: {Email: {level: 'NotSensitive', source: 'downgraded'}},
			selectionBefore: {Email: {}},
			disabled: {},
			enabled: {},
			excluded: {'F|Email|Mask_Generic': true}
		}));
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		expect(rowByApi(element, 'Email').dataset.testid).toBe('other-field-row');
	});

	it('restores a draft missing the optional desired-state maps without error', async() =>
	{
		window.sessionStorage.setItem('kern-masking-draft:Account',
				JSON.stringify({version: 4, overrides: {Email: {level: 'NotSensitive', source: 'downgraded'}}, selectionBefore: {}}));
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		expect(rowByApi(element, 'Email').dataset.testid).toBe('other-field-row');
	});

	it('drops a stale override for a field the org no longer has and restores only present fields', async() =>
	{
		window.sessionStorage.setItem('kern-masking-draft:Account', JSON.stringify({
			version: 4,
			overrides: {Ghost__c: {level: 'NotSensitive', source: 'downgraded'}, Email: {level: 'NotSensitive', source: 'downgraded'}},
			selectionBefore: {Email: {}},
			disabled: {},
			enabled: {},
			excluded: {},
			addedFieldRules: {},
			addedObjectWideRules: []
		}));
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-other-toggle"]').click();
		await flush();
		expect(rowByApi(element, 'Email').dataset.testid).toBe('other-field-row');
		expect(rowByApi(element, 'Ghost__c')).toBeUndefined();
	});

	it('ignores a draft written by an incompatible version and falls back to the seeded state', async() =>
	{
		window.sessionStorage.setItem('kern-masking-draft:Account', JSON.stringify({version: 1, disabled: {'F|SSN__c|Mask_SSN': true}}));
		const element = await createAdvisor();
		await selectMixed(element);
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('true');
	});

	it('degrades to the seeded state (no warning) when the draft cannot be read', async() =>
	{
		jest.spyOn(Object.getPrototypeOf(window.sessionStorage), 'getItem').mockImplementationOnce(() =>
		{
			throw new Error('blocked');
		});
		const element = await createAdvisor();
		await selectMixed(element);
		expect(mockShowWarningToast).not.toHaveBeenCalled();
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('true');
	});

	it('warns once (not per edit) and keeps working in memory when the draft cannot be saved', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		jest.spyOn(Object.getPrototypeOf(window.sessionStorage), 'setItem').mockImplementation(() =>
		{
			throw new Error('quota');
		});
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_Street'));
		await flush();
		expect(mockShowWarningToast).toHaveBeenCalledTimes(1);
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('false');
	});

	it('shows the Clear draft action only once a draft change exists, and clears it', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="clear-draft-button"]')).toBeNull();
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="clear-draft-button"]')).not.toBeNull();
		element.shadowRoot.querySelector('[data-testid="clear-draft-button"]').click();
		await flush();
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('true');
		expect(window.sessionStorage.getItem('kern-masking-draft:Account')).toBeNull();
	});

	it('tolerates a blocked store on Clear draft (in-memory reset still applies)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		jest.spyOn(Object.getPrototypeOf(window.sessionStorage), 'removeItem').mockImplementationOnce(() =>
		{
			throw new Error('blocked');
		});
		element.shadowRoot.querySelector('[data-testid="clear-draft-button"]').click();
		await flush();
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('true');
	});

	it('keeps each object\'s draft under its own key so switching away and back restores it', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		await selectObject(element, 'Contact');
		await selectObject(element, 'Account');
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('false');
	});
});

describe('c-data-masking-advisor — org-wide posture (landing)', () =>
{
	afterEach(cleanup);

	it('renders exactly the two headline posture tiles (objects masked and dead configurations)', async() =>
	{
		const element = await createAdvisor();
		expect(textOf(element, 'posture-objects-count')).toBe('3');
		expect(textOf(element, 'posture-dead-count')).toBe('1');
		expect(element.shadowRoot.querySelector('[data-testid="posture-field-targets"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="posture-object-wide"]')).toBeNull();
	});

	it('shows the barely-masked finding when no active masking targets exist', async() =>
	{
		const element = await createAdvisor({posture: {objectsWithActiveTargets: 0, activeFieldTargetCount: 0, sObjectWideTargetCount: 0, deadConfigCount: 0}});
		expect(element.shadowRoot.querySelector('[data-testid="posture-barely-masked"]')).not.toBeNull();
	});

	it('hides the barely-masked finding when at least one active target exists', async() =>
	{
		const element = await createAdvisor();
		expect(element.shadowRoot.querySelector('[data-testid="posture-barely-masked"]')).toBeNull();
	});

	it('hides the posture summary once an object is selected and drills into the smart list', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(element.shadowRoot.querySelector('[data-testid="posture-summary"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="summary-strip"]')).not.toBeNull();
	});

	it('degrades to the pick-an-object hint when the posture summary fails to load', async() =>
	{
		const element = await createAdvisor({posture: () => undefined});
		expect(element.shadowRoot.querySelector('[data-testid="posture-summary"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="coverage-empty"]')).not.toBeNull();
	});

	it('renders a drillable inventory row per masked object with its applied-rule chips and counts', async() =>
	{
		const element = await createAdvisor();
		const rows = element.shadowRoot.querySelectorAll('[data-testid="inventory-row"]');
		expect(rows.length).toBe(2);

		const apiCallRow = Array.from(rows).find((node) => node.dataset.apiName === 'ApiCall__c');
		expect(apiCallRow.textContent).toContain('API Call');
		expect(apiCallRow.querySelectorAll('.dma-rule-chip').length).toBe(2);
		expect(apiCallRow.textContent).toContain('Mask Credit Card');

		const meta = apiCallRow.querySelector('.dma-inv-row__meta');
		expect(meta.textContent).toContain('2 object-wide');
		expect(meta.textContent).toContain('0 field-level');
		expect(apiCallRow.querySelector('.dma-inv-dead').textContent).toContain('1 dead');
	});

	it('drills into an object preselected when its inventory row is clicked', async() =>
	{
		const element = await createAdvisor();
		const apiCallRow = Array.from(element.shadowRoot.querySelectorAll('[data-testid="inventory-row"]')).find((node) => node.dataset.apiName === 'ApiCall__c');

		apiCallRow.click();
		await flush();
		await flush();

		expect(mockCallControllerMethod).toHaveBeenCalledWith(describeFields, {objectApiName: 'ApiCall__c'});
		expect(element.shadowRoot.querySelector('[data-testid="posture-summary"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="summary-strip"]')).not.toBeNull();
	});

	it('keeps the landing tiles and hides the inventory when the inventory load fails', async() =>
	{
		const element = await createAdvisor({inventory: () => undefined});
		expect(element.shadowRoot.querySelector('[data-testid="inventory"]')).toBeNull();
		expect(textOf(element, 'posture-objects-count')).toBe('3');
	});
});

describe('c-data-masking-advisor — rule-detail popup', () =>
{
	afterEach(cleanup);

	// Clicks the rule-name detail button inside a chip span and lets the awaited popup settle.
	async function openDetail(chip)
	{
		chip.querySelector('[data-testid="chip-detail"]').click();
		await flush();
	}

	it('opens the popup populated from the rule catalogue and the chip state (C1)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);

		await openDetail(fieldChip(element, 'Email', 'Mask_Generic'));

		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({
			ruleLabel: 'Mask Generic',
			ruleDeveloperName: 'Mask_Generic',
			ruleDescription: 'Redacts generic sensitive text.',
			applicableFieldTypes: [],
			origin: 'candidate',
			scope: 'F',
			objectApiName: 'Account',
			fieldApiName: 'Email',
			desired: true
		}));
	});

	it('opens an existing active field chip seeded active (C1)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);

		await openDetail(fieldChip(element, 'SSN__c', 'Mask_SSN'));

		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({
			ruleDeveloperName: 'Mask_SSN', origin: 'active', scope: 'F', fieldApiName: 'SSN__c', desired: true
		}));
	});

	it('opens an object-wide context chip read-only with a representative test field (C1)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);

		const contextChip = Array.from(rowByApi(element, 'Notes__c').querySelectorAll('[data-testid="object-wide-context-chip"]'))
		.find((chip) => chip.dataset.rule === 'Mask_Card');
		contextChip.click();
		await flush();

		const opened = mockMaskingRuleDetailOpen.mock.calls[0][0];
		expect(opened.origin).toBe('context');
		expect(opened.scope).toBe('O');
		expect(opened.objectApiName).toBe('Account');
		expect(typeof opened.fieldApiName).toBe('string');
		expect(opened.fieldApiName.length).toBeGreaterThan(0);
	});

	it('opens an object-wide banner chip with object scope (C1)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();

		await openDetail(objectWideChip(element, 'Mask_Card'));

		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({
			ruleDeveloperName: 'Mask_Card', origin: 'active', scope: 'O', desired: true
		}));
	});

	it('folds a flipped desired state from the popup back into the inline chip (C3)', async() =>
	{
		mockMaskingRuleDetailOpen.mockResolvedValueOnce({wantActive: false});
		const element = await createAdvisor();
		await selectMixed(element);

		await openDetail(fieldChip(element, 'SSN__c', 'Mask_SSN'));

		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('false');
	});

	it('leaves the chip unchanged when the popup resolves the same desired state (C3)', async() =>
	{
		mockMaskingRuleDetailOpen.mockResolvedValueOnce({wantActive: true});
		const element = await createAdvisor();
		await selectMixed(element);

		await openDetail(fieldChip(element, 'SSN__c', 'Mask_SSN'));

		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('true');
	});

	it('does not toggle a read-only context chip even if a desired state comes back (C3)', async() =>
	{
		mockMaskingRuleDetailOpen.mockResolvedValueOnce({wantActive: false});
		const element = await createAdvisor();
		await selectMixed(element);

		const contextChip = Array.from(rowByApi(element, 'Notes__c').querySelectorAll('[data-testid="object-wide-context-chip"]'))
		.find((chip) => chip.dataset.rule === 'Mask_Card');
		contextChip.click();
		await flush();

		// The active object-wide Mask_Card banner chip is unaffected by the context-chip popup.
		expandObjectWideBanner(element);
		await flush();
		expect(objectWideChip(element, 'Mask_Card').dataset.desired).toBe('true');
	});

	it('navigates to Setup when the popup resolves a manage-setup action (C5)', async() =>
	{
		mockMaskingRuleDetailOpen.mockResolvedValueOnce({wantActive: true, action: 'manageSetup'});
		const element = await createAdvisor();
		await selectMixed(element);

		await openDetail(fieldChip(element, 'SSN__c', 'Mask_SSN'));

		expect(mockNavigate).toHaveBeenCalledWith({type: 'standard__webPage', attributes: {url: '/lightning/setup/CustomMetadata/home'}});
	});

	it('does nothing when the popup is dismissed (C1)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);

		await openDetail(fieldChip(element, 'SSN__c', 'Mask_SSN'));

		expect(mockNavigate).not.toHaveBeenCalled();
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('true');
	});

	it('tests an object-wide chip against the first loaded field when no field matches its type (C1)', async() =>
	{
		const analysis = {
			classificationAvailable: true,
			newRuleSetupUrl: NEW_RULE_SETUP_URL,
			rules: MOCK_RULE_CATALOGUE,
			objectWideRules: [{targetDeveloperName: 'OW_Secret', ruleDeveloperName: 'Mask_Secret', ruleLabel: 'Mask Secret Keys', isActive: true, callerClass: ''}],
			fields: [field({apiName: 'Name__c', label: 'Name', type: 'STRING', isClassified: true, sensitivityLevel: 'Sensitive', matchStrength: 'Strong'})]
		};
		const element = await createAdvisor({analysis});
		await selectObject(element, 'Account');
		expandObjectWideBanner(element);
		await flush();

		await openDetail(objectWideChip(element, 'Mask_Secret'));

		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({ruleDeveloperName: 'Mask_Secret', fieldApiName: 'Name__c'}));
	});

	it('passes an empty test field for an object-wide chip when the object has no listable fields (C1)', async() =>
	{
		const analysis = {
			classificationAvailable: true,
			newRuleSetupUrl: NEW_RULE_SETUP_URL,
			rules: MOCK_RULE_CATALOGUE,
			objectWideRules: [{targetDeveloperName: 'OW_Card', ruleDeveloperName: 'Mask_Card', ruleLabel: 'Mask Credit Card', isActive: true, callerClass: ''}],
			fields: []
		};
		const element = await createAdvisor({analysis});
		await selectObject(element, 'Account');
		expandObjectWideBanner(element);
		await flush();

		await openDetail(objectWideChip(element, 'Mask_Card'));

		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({ruleDeveloperName: 'Mask_Card', fieldApiName: ''}));
	});

	it('falls back to the applied row metadata for an object-wide rule absent from the catalogue (C1)', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_OW_TYPES});
		await selectObject(element, 'Account');
		expandObjectWideBanner(element);
		await flush();

		await openDetail(objectWideChip(element, 'Mask_Unknown'));

		// The applied row is the authoritative source when the catalogue misses: its resolved label wins
		// over the raw developer name, and the rule-active state comes from the row's ruleIsActive (absent
		// here — a dead rule — so the pill stays off).
		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({
			ruleLabel: 'Mask Unknown', ruleDeveloperName: 'Mask_Unknown', applicableFieldTypes: [], ruleActive: false
		}));
	});
});

describe('c-data-masking-advisor — supersession annotations', () =>
{
	afterEach(cleanup);

	const SSN_ANNOTATION = 'Superseded by Mask Identity Numbers. Rebind those objects first.';
	const CARD_ANNOTATION = 'Superseded by Mask Payment Card Numbers. Rebind those objects first.';

	it('titles and flags an annotated applied chip and threads the annotation into the popup (C2)', async() =>
	{
		// The controller annotates the catalogue option AND the applied rows from the same map — the
		// fixture mirrors that. The chip reads its OWN applied row (never another namespace's catalogue twin).
		const analysis = {
			...MOCK_ANALYSIS_MIXED,
			rules: MOCK_RULE_CATALOGUE.map((rule) => (rule.developerName === 'Mask_SSN' ? {...rule, supersededByLabel: SSN_ANNOTATION} : rule)),
			fields: MOCK_ANALYSIS_MIXED.fields.map((row) => (row.apiName === 'SSN__c' ? {
				...row, appliedRules: row.appliedRules.map((applied) => (applied.ruleDeveloperName === 'Mask_SSN' ? {...applied, supersededByLabel: SSN_ANNOTATION} : applied))
			} : row))
		};
		const element = await createAdvisor({analysis});
		await selectMixed(element);

		const chip = fieldChip(element, 'SSN__c', 'Mask_SSN');
		const detailButton = chip.querySelector('[data-testid="chip-detail"]');
		expect(detailButton.title).toBe(SSN_ANNOTATION);
		expect(chip.querySelector('[data-testid="chip-superseded-flag"]')).not.toBeNull();

		detailButton.click();
		await flush();
		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({supersededByLabel: SSN_ANNOTATION}));
	});

	it('falls back to the applied-row annotation and metadata when the superseded rule is no longer in the catalogue (C2)', async() =>
	{
		const analysis = {
			...MOCK_ANALYSIS_MIXED,
			rules: MOCK_RULE_CATALOGUE.filter((rule) => rule.developerName !== 'Mask_SSN'),
			fields: MOCK_ANALYSIS_MIXED.fields.map((row) => (row.apiName === 'SSN__c' ? {
				...row, appliedRules: [
					{
						targetDeveloperName: 'T_SSN',
						ruleDeveloperName: 'Mask_SSN',
						ruleLabel: 'Mask SSN',
						isActive: true,
						callerClass: '',
						ruleIsActive: true,
						supersededByLabel: SSN_ANNOTATION
					}
				]
			} : row))
		};
		const element = await createAdvisor({analysis});
		await selectMixed(element);

		const detailButton = fieldChip(element, 'SSN__c', 'Mask_SSN').querySelector('[data-testid="chip-detail"]');
		expect(detailButton.title).toBe(SSN_ANNOTATION);

		detailButton.click();
		await flush();
		// The popup must not degrade for a catalogue-dropped rule: the applied row supplies the label,
		// the rule's own active state, and the annotation.
		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({
			ruleLabel: 'Mask SSN', ruleActive: true, supersededByLabel: SSN_ANNOTATION
		}));
	});

	it('titles an annotated object-wide banner chip and threads its annotation into the popup (C2)', async() =>
	{
		// A tuned predecessor stays catalogued; the controller annotates its catalogue option and its
		// applied rows from the same map, so the fixture annotates both.
		const analysis = {
			...MOCK_ANALYSIS_MIXED,
			rules: MOCK_RULE_CATALOGUE.map((rule) => (rule.developerName === 'Mask_Card' ? {...rule, supersededByLabel: CARD_ANNOTATION} : rule)),
			objectWideRules: MOCK_OBJECT_WIDE_RULES.map((rule) => (rule.targetDeveloperName === 'OW_Card' ? {...rule, supersededByLabel: CARD_ANNOTATION} : rule))
		};
		const element = await createAdvisor({analysis});
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();

		const bannerChip = objectWideChip(element, 'Mask_Card');
		const detailButton = bannerChip.querySelector('[data-testid="chip-detail"]');
		expect(detailButton.title).toBe(CARD_ANNOTATION);
		expect(bannerChip.querySelector('[data-testid="chip-superseded-flag"]')).not.toBeNull();

		detailButton.click();
		await flush();
		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({supersededByLabel: CARD_ANNOTATION}));
	});

	it('renders no chip title, no flag, and threads no annotation for an unannotated rule (C2)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);

		const chip = fieldChip(element, 'SSN__c', 'Mask_SSN');
		const detailButton = chip.querySelector('[data-testid="chip-detail"]');
		expect(detailButton.title).toBe('');
		expect(chip.querySelector('[data-testid="chip-superseded-flag"]')).toBeNull();

		detailButton.click();
		await flush();
		expect(mockMaskingRuleDetailOpen.mock.calls[0][0].supersededByLabel).toBeFalsy();
	});

	it('keeps the raw developer name and inactive styling for a dead rule whose applied row resolved no metadata (C2)', async() =>
	{
		// A dead binding (orphaned rule) has no catalogue entry AND a metadata-less applied row: the
		// popup falls all the way back to the developer name with the pill off and no annotation.
		const analysis = {
			...MOCK_ANALYSIS_MIXED, objectWideRules: [
				...MOCK_OBJECT_WIDE_RULES,
				{targetDeveloperName: 'OW_Ghost', ruleDeveloperName: 'Mask_Ghost', ruleLabel: null, isActive: true, callerClass: ''}
			]
		};
		const element = await createAdvisor({analysis});
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();

		objectWideChip(element, 'Mask_Ghost').querySelector('[data-testid="chip-detail"]').click();
		await flush();

		expect(mockMaskingRuleDetailOpen).toHaveBeenCalledWith(expect.objectContaining({
			ruleLabel: 'Mask_Ghost', ruleActive: false, supersededByLabel: ''
		}));
	});

	it('carries a catalogue annotation into the add-rule menu options (C2)', async() =>
	{
		const analysis = {
			...MOCK_ANALYSIS_MIXED, rules: MOCK_RULE_CATALOGUE.map((rule) => (rule.developerName === 'Mask_Generic' ? {...rule, supersededByLabel: SSN_ANNOTATION} : rule))
		};
		const element = await createAdvisor({analysis});
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();

		element.shadowRoot.querySelector('[data-testid="add-object-wide-rule"]').click();
		await flush();

		const options = mockMaskingAddRuleMenuOpen.mock.calls[0][0].options;
		expect(options.find((option) => option.value === 'Mask_Generic').superseded).toBe(SSN_ANNOTATION);
		expect(options.find((option) => option.value === 'Mask_Street').superseded).toBe('');
	});
});

describe('c-data-masking-advisor — add-rule menus', () =>
{
	afterEach(cleanup);

	it('opens the field add-rule menu with type-matching rules not already on the field (C4)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);

		rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]').click();
		await flush();

		const opened = mockMaskingAddRuleMenuOpen.mock.calls[0][0];
		expect(opened.menuScope).toBe('field');
		expect(opened.objectApiName).toBe('Account');
		expect(opened.fieldLabel).toBe('SSN');
		const values = opened.options.map((option) => option.value);
		expect(values).toContain('Mask_Phone');
		expect(values).toContain('Mask_Generic');
		expect(values).not.toContain('Mask_SSN');
		expect(values).not.toContain('Mask_Street');
		expect(values).not.toContain('Mask_Card');
		expect(values).not.toContain('Mask_Secret');
	});

	it('adds a ticked field-level candidate chip when a rule is picked (C4)', async() =>
	{
		mockMaskingAddRuleMenuOpen.mockResolvedValueOnce({pickedRuleDeveloperName: 'Mask_Phone'});
		const element = await createAdvisor();
		await selectMixed(element);

		rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]').click();
		await flush();

		const chip = fieldChip(element, 'SSN__c', 'Mask_Phone');
		expect(chip).not.toBeUndefined();
		expect(chip.dataset.origin).toBe('candidate');
		expect(chip.dataset.desired).toBe('true');
	});

	it('opens the object-wide add-rule menu with rules not already applied object-wide (C4)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();

		element.shadowRoot.querySelector('[data-testid="add-object-wide-rule"]').click();
		await flush();

		const opened = mockMaskingAddRuleMenuOpen.mock.calls[0][0];
		expect(opened.menuScope).toBe('object');
		const values = opened.options.map((option) => option.value);
		expect(values).toContain('Mask_SSN');
		expect(values).toContain('Mask_Street');
		expect(values).toContain('Mask_Generic');
		expect(values).not.toContain('Mask_Card');
		expect(values).not.toContain('Mask_Secret');
		expect(values).not.toContain('Mask_Phone');
	});

	it('shows each object-wide add option its applicable types and warns when a rule matches no field on the object', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_ADD_TYPES});
		await selectObject(element, 'Account');
		expandObjectWideBanner(element);
		await flush();

		element.shadowRoot.querySelector('[data-testid="add-object-wide-rule"]').click();
		await flush();

		const byValue = Object.fromEntries(mockMaskingAddRuleMenuOpen.mock.calls[0][0].options.map((option) => [
			option.value,
			option
		]));
		// Mask_Secret is TEXTAREA-only; this object has only EMAIL + PHONE fields → applicable-types line plus warning.
		expect(byValue.Mask_Secret.appliesTo).toContain('Long Text Area');
		expect(byValue.Mask_Secret.warning).toBeTruthy();
		// Mask_Phone matches the PHONE field → applicable-types line, no warning.
		expect(byValue.Mask_Phone.appliesTo).toContain('Phone');
		expect(byValue.Mask_Phone.warning).toBeFalsy();
		// Mask_Generic applies to every text-shaped field → never warned, reads "Any text field".
		expect(byValue.Mask_Generic.appliesTo).toContain('Any text field');
		expect(byValue.Mask_Generic.warning).toBeFalsy();
	});

	it('includes an applicable-types line on field add options without a warning', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);

		rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]').click();
		await flush();

		const options = mockMaskingAddRuleMenuOpen.mock.calls[0][0].options;
		expect(options.length).toBeGreaterThan(0);
		options.forEach((option) =>
		{
			expect(option.appliesTo).toBeTruthy();
			expect(option.warning).toBeFalsy();
		});
	});

	it('adds a ticked object-wide candidate chip when a rule is picked (C4)', async() =>
	{
		mockMaskingAddRuleMenuOpen.mockResolvedValueOnce({pickedRuleDeveloperName: 'Mask_SSN'});
		const element = await createAdvisor();
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();

		element.shadowRoot.querySelector('[data-testid="add-object-wide-rule"]').click();
		await flush();

		const chip = objectWideChip(element, 'Mask_SSN');
		expect(chip).not.toBeUndefined();
		expect(chip.dataset.origin).toBe('candidate');
		expect(chip.dataset.desired).toBe('true');
	});

	it('emits a create decision for a ticked object-wide candidate, activating a dormant bound rule (C4)', async() =>
	{
		const captured = [];
		mockMaskingAddRuleMenuOpen.mockResolvedValueOnce({pickedRuleDeveloperName: 'Mask_Street'});
		const element = await createAdvisor({
			generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();
		element.shadowRoot.querySelector('[data-testid="add-object-wide-rule"]').click();
		await flush();

		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();

		const request = captured[0];
		const create = request.targets.find((target) => target.ruleDeveloperName === 'Mask_Street');
		expect(create.isActive).toBe(true);
		expect(create.field).toBe('');
		expect(create.developerName).toBe('Mask_Account_Mask_Street');
		expect(request.rulesToActivate).toContain('Mask_Street');
	});

	it('navigates to the resolved new-rule setup url from the create-custom-rule footer (C4/C5)', async() =>
	{
		mockMaskingAddRuleMenuOpen.mockResolvedValueOnce({action: 'createRule'});
		const element = await createAdvisor();
		await selectMixed(element);

		rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]').click();
		await flush();

		expect(mockNavigate).toHaveBeenCalledWith({type: 'standard__webPage', attributes: {url: NEW_RULE_SETUP_URL}});
	});

	it('persists admin-added candidates across a draft round-trip (C4)', async() =>
	{
		mockMaskingAddRuleMenuOpen.mockResolvedValueOnce({pickedRuleDeveloperName: 'Mask_Phone'});
		const element = await createAdvisor();
		await selectMixed(element);
		rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]').click();
		await flush();

		const reopened = await createAdvisor();
		await selectMixed(reopened);

		expect(fieldChip(reopened, 'SSN__c', 'Mask_Phone')).not.toBeUndefined();
	});

	it('ignores an add-rule request for a field that is not in the rendered set (C4)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		// Point a real Add-rule button at a field that is not rendered, so the handler finds no row.
		const button = rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]');
		button.dataset.apiName = 'Ghost__c';
		button.click();
		await flush();
		expect(mockMaskingAddRuleMenuOpen).not.toHaveBeenCalled();
	});

	it('opens the add-rule menu for a field that still has a recommendation candidate (C4)', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);

		rowByApi(element, 'Email').querySelector('[data-testid="add-rule"]').click();
		await flush();

		expect(mockMaskingAddRuleMenuOpen.mock.calls[0][0].menuScope).toBe('field');
	});

	it('adds an added rule only once when picked twice (C4)', async() =>
	{
		mockMaskingAddRuleMenuOpen.mockResolvedValue({pickedRuleDeveloperName: 'Mask_Phone'});
		const element = await createAdvisor();
		await selectMixed(element);
		const button = () => rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]');
		button().click();
		await flush();
		button().click();
		await flush();

		const phoneChips = Array.from(rowByApi(element, 'SSN__c').querySelectorAll('[data-testid="field-chip"]')).filter((chip) => chip.dataset.rule === 'Mask_Phone');
		expect(phoneChips).toHaveLength(1);
	});

	it('adds an object-wide rule only once when picked twice (C4)', async() =>
	{
		mockMaskingAddRuleMenuOpen.mockResolvedValue({pickedRuleDeveloperName: 'Mask_SSN'});
		const element = await createAdvisor();
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();
		const button = () => element.shadowRoot.querySelector('[data-testid="add-object-wide-rule"]');
		button().click();
		await flush();
		button().click();
		await flush();

		const ssnChips = Array.from(element.shadowRoot.querySelectorAll('[data-testid="object-wide-chip"]')).filter((chip) => chip.dataset.rule === 'Mask_SSN');
		expect(ssnChips).toHaveLength(1);
	});

	it('clears a stale excluded flag so a freshly added rule seeds ticked (C4)', async() =>
	{
		window.sessionStorage.setItem('kern-masking-draft:Account', JSON.stringify({
			version: 4, overrides: {}, selectionBefore: {}, disabled: {}, enabled: {}, excluded: {'F|SSN__c|Mask_Phone': true}, addedFieldRules: {}, addedObjectWideRules: []
		}));
		mockMaskingAddRuleMenuOpen.mockResolvedValueOnce({pickedRuleDeveloperName: 'Mask_Phone'});
		const element = await createAdvisor();
		await selectMixed(element);

		rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]').click();
		await flush();

		expect(fieldChip(element, 'SSN__c', 'Mask_Phone').dataset.desired).toBe('true');
	});

	it('drops admin-added candidates for a field the org no longer has on draft restore (C4)', async() =>
	{
		window.sessionStorage.setItem('kern-masking-draft:Account', JSON.stringify({
			version: 4,
			overrides: {},
			selectionBefore: {},
			disabled: {},
			enabled: {},
			excluded: {},
			addedFieldRules: {Ghost__c: ['Mask_SSN'], SSN__c: ['Mask_Phone']},
			addedObjectWideRules: []
		}));
		const element = await createAdvisor();
		await selectMixed(element);

		expect(fieldChip(element, 'SSN__c', 'Mask_Phone')).not.toBeUndefined();
		expect(rowByApi(element, 'Ghost__c')).toBeUndefined();
	});

	it('opens the add-rule menu for a field whose analysis row carries no applied rules (C4)', async() =>
	{
		const element = await createAdvisor({analysis: MOCK_ANALYSIS_MINIMAL});
		await selectMixed(element);

		rowByApi(element, 'Bare__c').querySelector('[data-testid="add-rule"]').click();
		await flush();

		expect(mockMaskingAddRuleMenuOpen.mock.calls[0][0].menuScope).toBe('field');
	});

	it('uses a rule mode, then blank, as the menu subtitle line when a rule has no description (C4)', async() =>
	{
		const analysis = {
			classificationAvailable: true, newRuleSetupUrl: NEW_RULE_SETUP_URL, rules: [
				{developerName: 'Mask_ModeOnly', label: 'Mode Only', category: '', mode: 'Regex', isActive: true, applicableFieldTypes: []},
				{developerName: 'Mask_Bare', label: 'Bare Rule', category: '', mode: '', isActive: true, applicableFieldTypes: []}
			], objectWideRules: [], fields: [field({apiName: 'X__c', label: 'X', type: 'STRING', isClassified: true, sensitivityLevel: 'Sensitive', matchStrength: 'Strong'})]
		};
		const element = await createAdvisor({analysis});
		await selectObject(element, 'Account');
		expandObjectWideBanner(element);
		await flush();

		element.shadowRoot.querySelector('[data-testid="add-object-wide-rule"]').click();
		await flush();

		const subtitleByValue = Object.fromEntries(mockMaskingAddRuleMenuOpen.mock.calls[0][0].options.map((option) => [
			option.value,
			option.subtitle
		]));
		expect(subtitleByValue.Mask_ModeOnly).toBe('Regex');
		expect(subtitleByValue.Mask_Bare).toBe('');
	});

	it('does not duplicate an added rule that already runs on the field as a candidate (C4)', async() =>
	{
		// A restored draft adds Mask_SSN to SSN__c, but Mask_SSN is already an active applied target there.
		window.sessionStorage.setItem('kern-masking-draft:Account', JSON.stringify({
			version: 4, overrides: {}, selectionBefore: {}, disabled: {}, enabled: {}, excluded: {}, addedFieldRules: {SSN__c: ['Mask_SSN']}, addedObjectWideRules: []
		}));
		const element = await createAdvisor();
		await selectMixed(element);

		const ssnChips = Array.from(rowByApi(element, 'SSN__c').querySelectorAll('[data-testid="field-chip"]')).filter((chip) => chip.dataset.rule === 'Mask_SSN');
		expect(ssnChips).toHaveLength(1);
		expect(ssnChips[0].dataset.origin).toBe('active');
	});

	it('does not duplicate an added object-wide rule that is already an existing object-wide target (C4)', async() =>
	{
		// A restored draft adds Mask_Card object-wide, but Mask_Card is already an active object-wide target there.
		window.sessionStorage.setItem('kern-masking-draft:Account', JSON.stringify({
			version: 4, overrides: {}, selectionBefore: {}, disabled: {}, enabled: {}, excluded: {}, addedFieldRules: {}, addedObjectWideRules: ['Mask_Card']
		}));
		const captured = [];
		const element = await createAdvisor({
			generate: (params) =>
			{
				captured.push(JSON.parse(params.requestJson));
				return STUB_BUNDLE;
			}
		});
		await selectMixed(element);
		expandObjectWideBanner(element);
		await flush();

		// Exactly one Mask_Card chip (the existing active target), not a colliding candidate duplicate.
		const cardChips = Array.from(element.shadowRoot.querySelectorAll('[data-testid="object-wide-chip"]')).filter((chip) => chip.dataset.rule === 'Mask_Card');
		expect(cardChips).toHaveLength(1);
		expect(cardChips[0].dataset.origin).toBe('active');

		// The export queues no create for Mask_Card — it already runs as an active object-wide target.
		element.shadowRoot.querySelector('[data-testid="export-package-button"]').click();
		await flush();
		expect(captured[0].targets.filter((target) => target.ruleDeveloperName === 'Mask_Card')).toHaveLength(0);
	});
});

describe('c-data-masking-advisor — accessibility + refresh', () =>
{
	afterEach(cleanup);

	it('re-describes the selected object and preserves the draft on refresh', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		// A draft edit: untick the existing-active SSN rule so it queues a disable.
		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();
		const describeCallsBefore = mockCallControllerMethod.mock.calls.filter(([apexFn]) => apexFn === describeFields).length;

		element.shadowRoot.querySelector('[data-testid="refresh-button"]').click();
		await flush();
		await flush();

		const describeCallsAfter = mockCallControllerMethod.mock.calls.filter(([apexFn]) => apexFn === describeFields).length;
		expect(describeCallsAfter).toBe(describeCallsBefore + 1);
		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('false');
	});

	it('reloads the org-wide reads without describing when refreshed on the landing (no object selected)', async() =>
	{
		const element = await createAdvisor();
		await flush();
		const describeCallsBefore = mockCallControllerMethod.mock.calls.filter(([apexFn]) => apexFn === describeFields).length;
		const postureCallsBefore = mockCallControllerMethod.mock.calls.filter(([apexFn]) => apexFn === getOrgPostureSummary).length;

		element.shadowRoot.querySelector('[data-testid="refresh-button"]').click();
		await flush();
		await flush();

		// No object is selected, so the refresh reloads posture/inventory but never re-describes.
		expect(mockCallControllerMethod.mock.calls.filter(([apexFn]) => apexFn === describeFields).length).toBe(describeCallsBefore);
		expect(mockCallControllerMethod.mock.calls.filter(([apexFn]) => apexFn === getOrgPostureSummary).length).toBe(postureCallsBefore + 1);
	});

	it('keeps the summary live-region node mounted and only mutates its text as the change count moves', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		const liveRegion = element.shadowRoot.querySelector('[data-testid="summary-strip"]');
		const before = liveRegion.textContent;

		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();

		expect(element.shadowRoot.querySelector('[data-testid="summary-strip"]')).toBe(liveRegion);
		expect(liveRegion.textContent).not.toBe(before);
	});

	it('gives each posture tile a combined assistive label', async() =>
	{
		const element = await createAdvisor();
		await flush();
		expect(element.shadowRoot.querySelector('[data-testid="posture-objects"] .slds-assistive-text').textContent).toContain('3');
		expect(element.shadowRoot.querySelector('[data-testid="posture-dead"] .slds-assistive-text').textContent).toContain('1');
	});

	it('returns focus to the add-rule trigger when the menu closes', async() =>
	{
		mockMaskingAddRuleMenuOpen.mockResolvedValueOnce(null);
		const element = await createAdvisor();
		await selectMixed(element);
		const trigger = rowByApi(element, 'SSN__c').querySelector('[data-testid="add-rule"]');
		trigger.click();
		await flush();

		expect(element.shadowRoot.activeElement).toBe(trigger);
	});
});

// Returns own custom-object options for the bulk concurrency/cancel scans (none in SCAN_ASSESSMENTS,
// so they all assess clean).
function manyOwnCustomObjects(count)
{
	return Array.from({length: count}, (ignored, index) => ({apiName: `Bulk${index}__c`, label: `Bulk ${index}`, isCustom: true, namespacePrefix: null}));
}

// An assessObjectCoverage stand-in whose calls stay pending until resolved by the test, so the scan's
// running state and concurrency cap can be observed deterministically.
function deferredAssess()
{
	const calls = [];
	return {
		calls, fn(apiName)
		{
			return new Promise((resolve) =>
			{
				calls.push({apiName, resolve: () => resolve(defaultAssess(apiName))});
			});
		}
	};
}

// Resolves every pending deferred assessment in order, draining backfilled calls until the scan settles.
async function drainScan(deferred)
{
	for(let index = 0; index < deferred.calls.length; index++)
	{
		deferred.calls[index].resolve();
		await flush();
	}
}

async function runScan(element)
{
	element.shadowRoot.querySelector('[data-testid="coverage-scan-button"]').click();
	await flush();
	await flush();
}

function coverageRows(element)
{
	return Array.from(element.shadowRoot.querySelectorAll('[data-testid="coverage-flagged-row"]'));
}

describe('c-data-masking-advisor — custom-object coverage scan', () =>
{
	afterEach(cleanup);

	it('renders the scan section idle with the own-object population note, managed clause, and scan button', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});

		expect(textOf(element, 'coverage-scan-heading')).toContain('Custom objects without masking');
		expect(textOf(element, 'coverage-population-note')).toContain('3');
		expect(textOf(element, 'coverage-managed-clause')).toContain('1');
		expect(textOf(element, 'coverage-scan-button')).toContain('Scan 3 custom objects');
		const toggle = element.shadowRoot.querySelector('[data-testid="coverage-managed-toggle"]');
		expect(toggle).not.toBeNull();
		expect(toggle.checked).toBe(false);
	});

	it('shows a no-custom-objects note instead of a scan button when the org has none of its own', async() =>
	{
		const element = await createAdvisor({objects: [{apiName: 'Account', label: 'Account', isCustom: false, namespacePrefix: null}]});

		expect(element.shadowRoot.querySelector('[data-testid="coverage-no-candidates"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-button"]')).toBeNull();
	});

	it('assesses only the own custom objects — not standard or managed-package objects — when scanned', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});

		await runScan(element);

		expect(mockCallControllerMethod).toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'CustomerFeedback__c'});
		expect(mockCallControllerMethod).toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'SupportTranscript__c'});
		expect(mockCallControllerMethod).toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'DeliveryRoute__c'});
		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'Account'});
		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'blng__PaymentGatewayLog__c'});
	});

	it('renders a flagged row per object requiring attention, with its flagged-field chips', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});

		await runScan(element);

		const rows = coverageRows(element);
		expect(rows).toHaveLength(2);
		const apiNames = rows.map((row) => row.dataset.apiName).sort();
		expect(apiNames).toEqual([
			'CustomerFeedback__c',
			'SupportTranscript__c'
		]);
		const feedbackRow = rows.find((row) => row.dataset.apiName === 'CustomerFeedback__c');
		const chips = feedbackRow.querySelectorAll('[data-testid="coverage-flagged-field"]');
		expect(chips).toHaveLength(2);
	});

	it('summarises the scan as objects assessed, objects needing attention, and flagged fields', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});

		await runScan(element);

		const summary = textOf(element, 'coverage-scan-summary');
		expect(summary).toContain('Scanned 3');
		expect(summary).toContain('2 need attention');
		expect(summary).toContain('3 likely-sensitive fields');
	});

	it('marks Long Text Area flagged fields and leaves shorter fields unmarked', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});

		await runScan(element);

		const transcriptRow = coverageRows(element).find((row) => row.dataset.apiName === 'SupportTranscript__c');
		expect(transcriptRow.querySelector('[data-testid="coverage-flagged-field"]').textContent).toContain('long text');
		const feedbackRow = coverageRows(element).find((row) => row.dataset.apiName === 'CustomerFeedback__c');
		const emailChip = Array.from(feedbackRow.querySelectorAll('[data-testid="coverage-flagged-field"]')).find((chip) => chip.textContent.includes('Customer Email'));
		expect(emailChip.textContent).not.toContain('long text');
	});

	it('notes the other custom objects that show no likely-sensitive fields', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});

		await runScan(element);

		expect(textOf(element, 'coverage-clean-note')).toContain('1');
	});

	it('shows an all-clear empty state when no object needs attention', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS, assess: cleanAssessment});

		await runScan(element);

		expect(element.shadowRoot.querySelector('[data-testid="coverage-empty-state"]')).not.toBeNull();
		expect(coverageRows(element)).toHaveLength(0);
	});

	it('includes managed-package objects and resets to idle when the opt-in toggle is turned on', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});
		await runScan(element);
		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-summary"]')).not.toBeNull();

		element.shadowRoot.querySelector('[data-testid="coverage-managed-toggle"]').dispatchEvent(new CustomEvent('change'));
		await flush();

		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-summary"]')).toBeNull();
		expect(textOf(element, 'coverage-scan-button')).toContain('Scan 4 custom objects');

		await runScan(element);
		expect(mockCallControllerMethod).toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'blng__PaymentGatewayLog__c'});
		expect(coverageRows(element)).toHaveLength(3);
	});

	it('shows running progress with the in-flight note and a cancel button while a scan is in flight', async() =>
	{
		const deferred = deferredAssess();
		const element = await createAdvisor({objects: manyOwnCustomObjects(10), assess: deferred.fn});

		element.shadowRoot.querySelector('[data-testid="coverage-scan-button"]').click();
		await flush();

		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-progress"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-cancel"]')).not.toBeNull();
		expect(textOf(element, 'coverage-scan-progress')).toContain('of 10');
		expect(textOf(element, 'coverage-scan-progress')).toContain('4 checks at a time');
		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-button"]')).toBeNull();

		await drainScan(deferred);
	});

	it('runs at most four assessments concurrently, backfilling as each completes', async() =>
	{
		const deferred = deferredAssess();
		const element = await createAdvisor({objects: manyOwnCustomObjects(10), assess: deferred.fn});

		element.shadowRoot.querySelector('[data-testid="coverage-scan-button"]').click();
		await flush();
		expect(deferred.calls).toHaveLength(4);

		deferred.calls[0].resolve();
		await flush();
		expect(deferred.calls).toHaveLength(5);

		await drainScan(deferred);
		expect(deferred.calls).toHaveLength(10);
	});

	it('keeps the partial results and pulls no new work when a scan is cancelled', async() =>
	{
		const deferred = deferredAssess();
		const element = await createAdvisor({objects: manyOwnCustomObjects(10), assess: deferred.fn});

		element.shadowRoot.querySelector('[data-testid="coverage-scan-button"]').click();
		await flush();
		element.shadowRoot.querySelector('[data-testid="coverage-scan-cancel"]').click();
		await flush();
		await drainScan(deferred);

		expect(deferred.calls).toHaveLength(4);
		expect(textOf(element, 'coverage-partial-note')).toContain('4 of 10');
	});

	it('skips an object whose assessment fails and finishes the rest of the scan', async() =>
	{
		const element = await createAdvisor({
			objects: MOCK_SCAN_OBJECTS, assess: (apiName) =>
			{
				if(apiName === 'CustomerFeedback__c')
				{
					throw new Error('assessment failed');
				}
				return defaultAssess(apiName);
			}
		});

		await runScan(element);

		const apiNames = coverageRows(element).map((row) => row.dataset.apiName);
		expect(apiNames).toContain('SupportTranscript__c');
		expect(apiNames).not.toContain('CustomerFeedback__c');
		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-summary"]')).not.toBeNull();
	});

	it('flags an object whose only likely-sensitive fields are possibly-sensitive', async() =>
	{
		const objects = [{apiName: 'CustomerNote__c', label: 'Customer Note', isCustom: true, namespacePrefix: null}];
		const assess = () => ({
			objectApiName: 'CustomerNote__c', objectLabel: 'Customer Note', hasActiveMasking: false, requiresAttention: false, flaggedFields: [
				{fieldApiName: 'NoteBody__c', fieldLabel: 'Note Body', sensitivityLevel: 'PossiblySensitive', isLongTextArea: true}
			]
		});

		const element = await createAdvisor({objects, assess});
		await runScan(element);

		const rows = coverageRows(element);
		expect(rows).toHaveLength(1);
		expect(rows[0].dataset.apiName).toBe('CustomerNote__c');
	});

	it('reports the in-flight note as the population size when it is below the concurrency cap', async() =>
	{
		const deferred = deferredAssess();
		const element = await createAdvisor({objects: manyOwnCustomObjects(2), assess: deferred.fn});

		element.shadowRoot.querySelector('[data-testid="coverage-scan-button"]').click();
		await flush();

		expect(textOf(element, 'coverage-scan-progress')).toContain('2 checks at a time');

		await drainScan(deferred);
	});

	it('re-runs the scan from the done state when Scan again is clicked', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});
		await runScan(element);
		mockCallControllerMethod.mockClear();

		element.shadowRoot.querySelector('[data-testid="coverage-rescan"]').click();
		await flush();
		await flush();

		expect(mockCallControllerMethod).toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'CustomerFeedback__c'});
		expect(coverageRows(element)).toHaveLength(2);
	});

	it('drills into a flagged object with a scan provenance banner', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});
		await runScan(element);

		coverageRows(element).find((row) => row.dataset.apiName === 'CustomerFeedback__c').click();
		await flush();
		await flush();

		expect(mockCallControllerMethod).toHaveBeenCalledWith(describeFields, {objectApiName: 'CustomerFeedback__c'});
		const banner = element.shadowRoot.querySelector('[data-testid="coverage-provenance"]');
		expect(banner).not.toBeNull();
		expect(banner.textContent).toContain('Flagged by the custom-object scan');
		expect(banner.textContent).toContain('2');
	});

	it('returns to the landing with the scan results intact from the provenance banner', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});
		await runScan(element);
		coverageRows(element).find((row) => row.dataset.apiName === 'CustomerFeedback__c').click();
		await flush();
		await flush();

		element.shadowRoot.querySelector('[data-testid="coverage-back-to-scan"]').click();
		await flush();

		expect(element.shadowRoot.querySelector('[data-testid="coverage-provenance"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-summary"]')).not.toBeNull();
		expect(coverageRows(element)).toHaveLength(2);
	});
});

describe('c-data-masking-advisor — Health Check deep-link auto-scan', () =>
{
	// The Health Check "Custom-Object Masking Coverage" card deep-links here with a scan-request page
	// state so the coverage scan it summarised runs on arrival instead of leaving the admin to press
	// "Scan N" again. The page reference arrives via the CurrentPageReference wire, so each test mounts
	// first and then emits, then clears the adapter afterwards so the flag never leaks into another suite.
	afterEach(() =>
	{
		CurrentPageReference.emit(undefined);
		cleanup();
	});

	function feedbackAssessmentCount()
	{
		return mockCallControllerMethod.mock.calls
		.filter((call) => call[0] === assessObjectCoverage && call[1] && call[1].objectApiName === 'CustomerFeedback__c').length;
	}

	async function arriveWith(pageReference, options = {objects: MOCK_SCAN_OBJECTS})
	{
		const element = await createAdvisor(options);
		CurrentPageReference.emit(pageReference);
		await flush();
		await flush();
		return element;
	}

	it('auto-runs the coverage scan on arrival when the deep-link requests it', async() =>
	{
		const element = await arriveWith({state: {c__scan: '1'}});

		expect(mockCallControllerMethod).toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'CustomerFeedback__c'});
		expect(coverageRows(element)).toHaveLength(2);
		expect(textOf(element, 'coverage-scan-summary')).toContain('Scanned 3');
	});

	it('auto-runs via connectedCallback when the request arrives before the objects finish loading', async() =>
	{
		// Production ordering: the page-reference wire can deliver the scan request while listObjects is
		// still pending. The wire's own surfaceScanIfRequested then finds no candidates and holds back, so
		// only connectedCallback's post-loadObjects call can start the scan — this proves that fallback path.
		let resolveObjects;
		configureApex({
			objects: new Promise((resolve) =>
			{
				resolveObjects = resolve;
			})
		});
		const element = createElement('c-data-masking-advisor', {is: DataMaskingAdvisor});
		document.body.appendChild(element);
		await flush();

		CurrentPageReference.emit({state: {c__scan: '1'}});
		await flush();
		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(assessObjectCoverage, expect.anything());

		resolveObjects(MOCK_SCAN_OBJECTS);
		await flush();
		await flush();
		await flush();

		expect(mockCallControllerMethod).toHaveBeenCalledWith(assessObjectCoverage, {objectApiName: 'CustomerFeedback__c'});
		expect(coverageRows(element)).toHaveLength(2);
	});

	it('does not auto-run the scan when the page reference carries no state', async() =>
	{
		const element = await arriveWith({});

		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(assessObjectCoverage, expect.anything());
		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-summary"]')).toBeNull();
		expect(textOf(element, 'coverage-scan-button')).toContain('Scan 3 custom objects');
	});

	it('does not auto-run the scan when the scan-request flag is not the expected value', async() =>
	{
		const element = await arriveWith({state: {c__scan: '0'}});

		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(assessObjectCoverage, expect.anything());
		expect(element.shadowRoot.querySelector('[data-testid="coverage-scan-summary"]')).toBeNull();
	});

	it('does not auto-run when the org has no custom objects of its own to scan', async() =>
	{
		const element = await arriveWith({state: {c__scan: '1'}}, {objects: [{apiName: 'Account', label: 'Account', isCustom: false, namespacePrefix: null}]});

		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(assessObjectCoverage, expect.anything());
		expect(element.shadowRoot.querySelector('[data-testid="coverage-no-candidates"]')).not.toBeNull();
	});

	it('auto-runs the scan only once even if the page reference re-emits the request', async() =>
	{
		await arriveWith({state: {c__scan: '1'}});

		CurrentPageReference.emit({state: {c__scan: '1'}});
		await flush();
		await flush();

		expect(feedbackAssessmentCount()).toBe(1);
	});

	it('does not auto-run on arrival when the admin already started a scan manually', async() =>
	{
		const element = await createAdvisor({objects: MOCK_SCAN_OBJECTS});
		await runScan(element);

		CurrentPageReference.emit({state: {c__scan: '1'}});
		await flush();
		await flush();

		expect(feedbackAssessmentCount()).toBe(1);
	});
});

describe('c-data-masking-advisor — derived-row memoisation', () =>
{
	afterEach(cleanup);

	// Replaces a fixture property with a counting getter so a test can observe whether the component
	// re-reads the raw analysis data (the decorate + export-diff cascade) on a given render.
	function countReads(target, propertyName)
	{
		const counter = {reads: 0};
		const value = target[propertyName];
		Object.defineProperty(target, propertyName, {
			configurable: true, enumerable: true, get()
			{
				counter.reads += 1;
				return value;
			}
		});
		return counter;
	}

	it('does not recompute the decorated field list or the export diff on a re-render that changes none of their inputs', async() =>
	{
		const analysis = JSON.parse(JSON.stringify(MOCK_ANALYSIS_MIXED));
		const ssnRow = analysis.fields.find((row) => row.apiName === 'SSN__c');
		const activeApplied = ssnRow.appliedRules.find((applied) => applied.isActive);
		const element = await createAdvisor({analysis});
		await selectMixed(element);

		// heuristicConfidence is read only by the row-decorate walk; the active applied rule's
		// ruleDeveloperName is read by the decorate chips and the export-diff walk. Neither may run again
		// for a pure view flip (a card open/close), which changes none of the derived-data inputs.
		const heuristicConfidenceReads = countReads(ssnRow, 'heuristicConfidence');
		const appliedRuleNameReads = countReads(activeApplied, 'ruleDeveloperName');

		element.shadowRoot.querySelector('[data-testid="section-manual-review-toggle"]').click();
		await flush();

		expect(heuristicConfidenceReads.reads).toBe(0);
		expect(appliedRuleNameReads.reads).toBe(0);
	});

	it('still applies a chip toggle after a view-only re-render has warmed the derived-data path', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		element.shadowRoot.querySelector('[data-testid="section-manual-review-toggle"]').click();
		await flush();

		toggleChip(fieldChip(element, 'SSN__c', 'Mask_SSN'));
		await flush();

		expect(fieldChip(element, 'SSN__c', 'Mask_SSN').dataset.desired).toBe('false');
		expect(textOf(element, 'summary-changes')).toBe('2 changes');
	});

	it('recomputes the decorated field list when a new object analysis arrives', async() =>
	{
		const element = await createAdvisor();
		await selectMixed(element);
		expect(rowByApi(element, 'Email')).not.toBeUndefined();

		configureApex({analysis: MOCK_ANALYSIS_NO_OBJECT_WIDE});
		await selectObject(element, 'ApiCall__c');

		expect(rowByApi(element, 'SSN__c')).not.toBeUndefined();
		expect(rowByApi(element, 'Email')).toBeUndefined();
	});
});
