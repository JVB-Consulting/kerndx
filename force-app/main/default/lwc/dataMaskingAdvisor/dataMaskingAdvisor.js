// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Data Masking Advisor coverage area: object picker, configuration-health and
 *              object-wide-coverage banners, a heuristic-only-mode notice, a summary strip, and the
 *              smart list — a Ready-to-mask card, a collapsible Needs-review card, and a
 *              collapsible Other card. Each field renders a masking cell of checkbox chips: the
 *              object-wide rules that apply to it (read-only context) and its own field-level rules
 *              plus candidates (tickable). A ticked chip means "masked / active after you deploy this
 *              package"; the export is the diff of those desired states against the org — create,
 *              disable, and re-enable. An administrator reconciles recommendations against existing
 *              masking and assembles a single deployable masking configuration for framework paths.
 *
 * @author Jason van Beukering
 *
 * @date May 2026, June 2026
 */
import {wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import {ComponentBuilder} from 'c/componentBuilder';
import MaskingReviewDialog from 'c/maskingReviewDialog';
import MaskingExportModal from 'c/maskingExportModal';
import MaskingRuleDetail from 'c/maskingRuleDetail';
import MaskingAddRuleMenu from 'c/maskingAddRuleMenu';
import MaskingAddObjectDialog from 'c/maskingAddObjectDialog';
import MaskingInventoryExportDialog from 'c/maskingInventoryExportDialog';
import {friendlyFieldTypes} from 'c/maskingFieldTypeLabels';
import listObjects from '@salesforce/apex/CTRL_MaskingAdvisor.listObjects';
import getDeadConfigurations from '@salesforce/apex/CTRL_MaskingAdvisor.getDeadConfigurations';
import describeFields from '@salesforce/apex/CTRL_MaskingAdvisor.describeFields';
import generateConfiguration from '@salesforce/apex/CTRL_MaskingAdvisor.generateConfiguration';
import getOrgPostureSummary from '@salesforce/apex/CTRL_MaskingAdvisor.getOrgPostureSummary';
import getOrgPostureInventory from '@salesforce/apex/CTRL_MaskingAdvisor.getOrgPostureInventory';
import assessObjectCoverage from '@salesforce/apex/CTRL_MaskingAdvisor.assessObjectCoverage';
import CARD_TITLE from '@salesforce/label/c.DataMaskingAdvisor_CardTitle';
import REFRESH_ALT_TEXT from '@salesforce/label/c.DataMaskingAdvisor_RefreshAltText';
import SCOPE_BANNER_BODY from '@salesforce/label/c.DataMaskingAdvisor_ScopeBanner_Body';
import DEAD_CONFIG_HEADING from '@salesforce/label/c.DataMaskingAdvisor_DeadConfigBanner_Heading';
import DEAD_CONFIG_SUMMARY_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_DeadConfigBanner_Summary_Singular';
import DEAD_CONFIG_SUMMARY_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_DeadConfigBanner_Summary_Plural';
import COVERAGE_HEADING from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Heading';
import ADD_OBJECT_BUTTON from '@salesforce/label/c.DataMaskingAdvisor_AddObject_Button';
import ADD_OBJECT_BACK from '@salesforce/label/c.DataMaskingAdvisor_AddObject_BackToAllObjects';
import INVENTORY_EXPORT_BUTTON from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_OpenButton';
import HEURISTIC_ONLY_NOTICE from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_HeuristicOnly_Notice';
import EMPTY_HEADING from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Empty_Heading';
import EMPTY_BODY from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Empty_Body';
import ERROR_LOAD_FAILED from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Error_LoadFailed';
import COLUMN_FIELD from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Table_Column_Field';
import COLUMN_SENSITIVITY from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Table_Column_Sensitivity';
import COLUMN_MASKING_RULES from '@salesforce/label/c.DataMaskingAdvisor_Table_Column_MaskingRules';
import HEURISTIC_TIER_HIGH from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_HeuristicTier_High';
import HEURISTIC_TIER_MEDIUM from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_HeuristicTier_Medium';
import HEURISTIC_TIER_LOW from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_HeuristicTier_Low';
import SECTION_READY_HEADING from '@salesforce/label/c.DataMaskingAdvisor_Section_ReadyToMask_Heading';
import SECTION_READY_GUIDANCE from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Section_Ready_Guidance';
import SECTION_REVIEW_HEADING from '@salesforce/label/c.DataMaskingAdvisor_Section_NeedsReview_Heading';
import SECTION_REVIEW_GUIDANCE from '@salesforce/label/c.DataMaskingAdvisor_Section_NeedsReview_Guidance';
import SECTION_REVIEW_NO_RULE_NOTE from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Section_ManualReview_NoRuleNote';
import SECTION_OTHER_HEADING from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Section_Other_Heading';
import SECTION_OTHER_SUMMARY from '@salesforce/label/c.DataMaskingAdvisor_CoverageAdvisor_Section_Other_Summary';
import EXPORT_PACKAGE_LABEL from '@salesforce/label/c.DataMaskingAdvisor_ExportPackageButton_Label';
import EXPORT_FILE_NAME from '@salesforce/label/c.DataMaskingAdvisor_ExportModal_FileName';
import POSTURE_HEADING from '@salesforce/label/c.DataMaskingAdvisor_Posture_Heading';
import POSTURE_AS_CONFIGURED_NOTE from '@salesforce/label/c.DataMaskingAdvisor_Posture_AsConfiguredNote';
import POSTURE_OBJECTS_WITH_MASKING from '@salesforce/label/c.DataMaskingAdvisor_Posture_ObjectsWithMasking';
import POSTURE_DEAD_CONFIGURATIONS from '@salesforce/label/c.DataMaskingAdvisor_Posture_DeadConfigurations';
import INVENTORY_HEADING from '@salesforce/label/c.DataMaskingAdvisor_Inventory_Heading';
import INVENTORY_COUNT_META from '@salesforce/label/c.DataMaskingAdvisor_Inventory_CountMeta';
import INVENTORY_DEAD_SUFFIX from '@salesforce/label/c.DataMaskingAdvisor_Inventory_DeadSuffix';
import INVENTORY_FOOTER from '@salesforce/label/c.DataMaskingAdvisor_Inventory_Footer';
import POSTURE_BARELY_MASKED_NOTE from '@salesforce/label/c.DataMaskingAdvisor_Posture_BarelyMasked_Note';
import OTHER_REASON_NO_SIGNAL from '@salesforce/label/c.DataMaskingAdvisor_Other_Reason_NoSignal';
import OTHER_REASON_TYPE_SUGGESTS from '@salesforce/label/c.DataMaskingAdvisor_Other_Reason_TypeSuggests';
import OTHER_LOW_CONFIDENCE_TAG from '@salesforce/label/c.DataMaskingAdvisor_Other_LowConfidenceMatch_Tag';
import OTHER_MISSES_ONLY_LABEL from '@salesforce/label/c.DataMaskingAdvisor_OtherToggle_MissesOnly_Label';
import OTHER_ROW_CAP_NOTE from '@salesforce/label/c.DataMaskingAdvisor_Other_RowCap_Note';
import SUMMARY_READY from '@salesforce/label/c.DataMaskingAdvisor_Summary_Ready';
import SUMMARY_TO_REVIEW from '@salesforce/label/c.DataMaskingAdvisor_Summary_ToReview';
import SUMMARY_OTHER from '@salesforce/label/c.DataMaskingAdvisor_Summary_Other';
import SENSITIVITY_SENSITIVE from '@salesforce/label/c.DataMaskingAdvisor_Sensitivity_Sensitive';
import SENSITIVITY_POSSIBLY from '@salesforce/label/c.DataMaskingAdvisor_Sensitivity_PossiblySensitive';
import SENSITIVITY_NOT from '@salesforce/label/c.DataMaskingAdvisor_Sensitivity_NotSensitive';
import SIGNAL_BAND_WEAK from '@salesforce/label/c.DataMaskingAdvisor_SignalBand_Weak';
import SIGNAL_BAND_MODERATE from '@salesforce/label/c.DataMaskingAdvisor_SignalBand_Moderate';
import SIGNAL_BAND_STRONG from '@salesforce/label/c.DataMaskingAdvisor_SignalBand_Strong';
import REVIEW_BADGE_ASSISTIVE from '@salesforce/label/c.DataMaskingAdvisor_ReviewBadge_AssistiveText';
import MARKER_MARKED_NOT_SENSITIVE from '@salesforce/label/c.DataMaskingAdvisor_Marker_MarkedNotSensitive';
import MARKER_ADDED_MANUALLY from '@salesforce/label/c.DataMaskingAdvisor_Marker_AddedManually';
import REVERT_OVERRIDE_LABEL from '@salesforce/label/c.DataMaskingAdvisor_RevertOverride_Label';
import REVERT_OVERRIDE_ARIA from '@salesforce/label/c.DataMaskingAdvisor_RevertOverride_AriaLabel';
import SUMMARY_CHANGES from '@salesforce/label/c.DataMaskingAdvisor_Summary_Changes';
import RECLASSIFY_TOAST_OTHER from '@salesforce/label/c.DataMaskingAdvisor_Reclassify_Toast_Other';
import RECLASSIFY_TOAST_REVERTED from '@salesforce/label/c.DataMaskingAdvisor_Reclassify_Toast_Reverted';
import RECLASSIFY_TOAST_READY from '@salesforce/label/c.DataMaskingAdvisor_Reclassify_Toast_Ready';
import RECLASSIFY_TOAST_REVIEW from '@salesforce/label/c.DataMaskingAdvisor_Reclassify_Toast_Review';
import DRAFT_SAVE_FAILED_WARNING from '@salesforce/label/c.DataMaskingAdvisor_Draft_SaveFailed_Warning';
import CLEAR_DRAFT_LABEL from '@salesforce/label/c.DataMaskingAdvisor_ClearDraft_Label';
import DRAFT_CLEARED_TOAST from '@salesforce/label/c.DataMaskingAdvisor_Draft_Cleared_Toast';
import MASKING_CELL_OBJECT_WIDE_LINE from '@salesforce/label/c.DataMaskingAdvisor_MaskingCell_ObjectWideLine_Label';
import MASKING_CELL_FIELD_LEVEL_LINE from '@salesforce/label/c.DataMaskingAdvisor_MaskingCell_FieldLevelLine_Label';
import CHIP_FLAG_WILL_DISABLE from '@salesforce/label/c.DataMaskingAdvisor_Chip_Flag_WillDisable';
import CHIP_FLAG_WILL_ENABLE from '@salesforce/label/c.DataMaskingAdvisor_Chip_Flag_WillEnable';
import CHIP_FLAG_TO_ADD from '@salesforce/label/c.DataMaskingAdvisor_Chip_Flag_ToAdd';
import CHIP_TOGGLE_ARIA_TEMPLATE from '@salesforce/label/c.DataMaskingAdvisor_Chip_Toggle_AriaLabel';
import CHIP_INACTIVE_SUFFIX from '@salesforce/label/c.DataMaskingAdvisor_Chip_InactiveSuffix';
import CHIP_SUPERSEDED_FLAG from '@salesforce/label/c.DataMaskingAdvisor_Chip_SupersededFlag';
import ADD_RULE_LABEL from '@salesforce/label/c.DataMaskingAdvisor_AddRule_Label';
import ADD_OBJECT_WIDE_RULE_LABEL from '@salesforce/label/c.DataMaskingAdvisor_AddObjectWideRule_Label';
import ADD_RULE_MENU_APPLIES_TO from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_AppliesTo';
import ADD_RULE_MENU_NO_FIELD_MATCH_WARNING from '@salesforce/label/c.DataMaskingAdvisor_AddRuleMenu_NoFieldMatch_Warning';
import OBJECT_WIDE_HEADING_ACTIVE_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Heading_Active_Singular';
import OBJECT_WIDE_HEADING_ACTIVE_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Heading_Active_Plural';
import OBJECT_WIDE_HEADING_NONE from '@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Heading_None';
import BANNER_SHOW_DETAIL from '@salesforce/label/c.DataMaskingAdvisor_Banner_ShowDetail';
import BANNER_HIDE_DETAIL from '@salesforce/label/c.DataMaskingAdvisor_Banner_HideDetail';
import OBJECT_WIDE_NOTE_ACTIVE from '@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Note_Active';
import OBJECT_WIDE_NOTE_NONE from '@salesforce/label/c.DataMaskingAdvisor_ObjectWideBanner_Note_None';
import HEALTH_HEADING from '@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Heading';
import HEALTH_SUMMARY_OBJECT_WIDE_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Summary_ObjectWideInactive_Singular';
import HEALTH_SUMMARY_OBJECT_WIDE_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Summary_ObjectWideInactive_Plural';
import HEALTH_SUMMARY_DEAD_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Summary_DeadFieldTargets_Singular';
import HEALTH_SUMMARY_DEAD_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Summary_DeadFieldTargets_Plural';
import HEALTH_DETAIL_OBJECT_WIDE_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Detail_ObjectWideInactive_Singular';
import HEALTH_DETAIL_OBJECT_WIDE_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Detail_ObjectWideInactive_Plural';
import HEALTH_DETAIL_DEAD_FIELD_TARGET from '@salesforce/label/c.DataMaskingAdvisor_HealthBanner_Detail_DeadFieldTarget';
import NO_CHANGES_QUEUED_NOTE from '@salesforce/label/c.DataMaskingAdvisor_NoChangesQueued_Note';
import COVERAGE_SCAN_HEADING from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Heading';
import COVERAGE_SCAN_INTRO from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Intro';
import COVERAGE_SCAN_POPULATION_NOTE from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_PopulationNote';
import COVERAGE_SCAN_POPULATION_MANAGED_CLAUSE from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_PopulationNote_ManagedClause';
import COVERAGE_SCAN_HOW_IT_WORKS from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_HowItWorks';
import COVERAGE_SCAN_INCLUDE_MANAGED_LABEL from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_IncludeManaged_Label';
import COVERAGE_SCAN_BUTTON from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_ScanButton';
import COVERAGE_SCAN_NO_CANDIDATES from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_NoCandidates';
import COVERAGE_SCAN_SCANNING from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Scanning';
import COVERAGE_SCAN_IN_FLIGHT_NOTE from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_InFlightNote';
import COVERAGE_SCAN_CANCEL from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Cancel';
import COVERAGE_SCAN_RESCAN from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Rescan';
import COVERAGE_SCAN_SUMMARY from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Summary';
import COVERAGE_SCAN_PARTIAL_NOTE from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_PartialNote';
import COVERAGE_SCAN_NO_MASKING_PILL from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_NoMaskingPill';
import COVERAGE_SCAN_FLAGGED_FOOTER from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_FlaggedFooter';
import COVERAGE_SCAN_EMPTY_STATE from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_EmptyState';
import COVERAGE_SCAN_CLEAN_NOTE from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_CleanNote';
import COVERAGE_SCAN_LONG_TEXT_SUFFIX from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_LongTextSuffix';
import COVERAGE_SCAN_PROVENANCE from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_Provenance';
import COVERAGE_SCAN_BACK_TO_SCAN from '@salesforce/label/c.DataMaskingAdvisor_CoverageScan_BackToScan';

const HEURISTIC_LOW = 'LOW';
const HEURISTIC_HIGH = 'HIGH';
const HEURISTIC_MEDIUM = 'MEDIUM';
// The three smart-list sections a field can land in. A field's section is resolved in decorateRow and
// the section getters filter on it, so a reclassify override can re-section a row deterministically.
const SECTION_READY = 'ready';
const SECTION_REVIEW = 'review';
const SECTION_OTHER = 'other';
// A reclassify to Not Sensitive downgrades a field (→ Other); any other level promotes it (→ Ready when a
// rule can be assigned, else Needs review). The override's source records which way the field was moved so
// the marker, section, and toast each read from one place.
const LEVEL_NOT_SENSITIVE = 'NotSensitive';
const OVERRIDE_DOWNGRADED = 'downgraded';
const OVERRIDE_PROMOTED = 'promoted';
// A rule chip's origin: an existing active target, an existing inactive target, or a not-yet-created
// candidate (a recommendation or an admin-added rule). The origin sets the chip's default ticked state
// (desiredActive) and which desired-state map a toggle writes to. A context chip is a read-only
// object-wide rule shown on a field — it opens the detail popup but carries no toggle.
const ORIGIN_ACTIVE = 'active';
const ORIGIN_INACTIVE = 'inactive';
const ORIGIN_CANDIDATE = 'candidate';
const ORIGIN_CONTEXT = 'context';
// Chip-key scopes: a field-level target (keyed by field api name + rule) or an object-wide target
// (keyed by rule alone, with an empty field segment).
const SCOPE_FIELD = 'F';
const SCOPE_OBJECT = 'O';
// The three diff verbs the export package groups its contents by. They double as the chip-tag CSS keys
// the export modal colours each row with, so the values are stable display keys (the visible verb text is
// a Custom Label rendered modal-side), not internal jargon.
const VERB_ADD = 'add';
const VERB_DISABLE = 'disable';
const VERB_REENABLE = 're-enable';
// Salesforce Setup home for Custom Metadata, where the rule-detail popup's Manage-in-Setup link lands so
// an admin can deactivate a rule or open its target. A fixed, prefix-free Setup route (unlike the
// New-Masking-Rule address, which embeds the dynamically resolved key prefix from the controller).
const MANAGE_SETUP_PATH = '/lightning/setup/CustomMetadata/home';
// The reclassify overrides + the three desired-state maps persist to a per-object sessionStorage key so
// the work survives a reload for the export → inspect → fix → re-export loop. The draft is delta-only
// (overrides + the desired toggles, never the field DTOs) and tab-scoped — it is never written
// server-side.
const DRAFT_KEY_PREFIX = 'kern-masking-draft:';
const DRAFT_VERSION = 4;
// Cap on the rendered Other rows so an object with hundreds of unrecommended fields still paints fast.
// The full count is always shown in the counter + summary strip; only the rendered table is capped.
const OTHER_ROW_CAP = 200;

// The custom-object coverage scan runs this many assessObjectCoverage calls concurrently, keeping the
// on-demand sweep responsive without issuing every per-object describe at once.
const SCAN_CONCURRENCY = 4;
const SCAN_IDLE = 'idle';
const SCAN_RUNNING = 'running';
const SCAN_DONE = 'done';
const SCAN_CANCELLED = 'cancelled';
// The Health Check "Custom-Object Masking Coverage" card deep-links here carrying this page-state flag so
// the coverage scan it summarised runs on arrival rather than leaving the admin to press "Scan N" again.
const ADVISOR_SCAN_STATE_KEY = 'c__scan';
const ADVISOR_SCAN_STATE_VALUE = '1';
// The export builds one CustomMetadata MaskingTarget record per created chip; its developer name is
// Mask_<object>[_<field>]_<rule>, each segment reduced to the CustomMetadata identifier grammar (a
// leading letter, then only letters, digits, and single underscores) and capped at the 40-character
// developer-name limit so the generated bundle always deploys, even for long object/field/rule api
// names.
const TARGET_DEVELOPER_NAME_PREFIX = 'Mask_';
const MAX_DEVELOPER_NAME_LENGTH = 40;
// Base36 characters reserved to disambiguate a truncated developer name. A long object api name can leave
// only a few characters of field/rule budget, so two chips sharing that prefix would otherwise truncate
// to the same name and one target would be silently dropped from the bundle; a short hash suffix keyed on
// the full field+rule pair keeps each generated target unique.
const DEVELOPER_NAME_HASH_LENGTH = 6;

/**
 * @description Maps each stable sensitivity-level key (the engine literal carried in the DTO) to its
 * display badge label. The keys are themselves the styling contract: the template emits them as data-*
 * attributes and the stylesheet keys off them, so no CSS class names live in JavaScript. The backend
 * always emits one of the three sensitivity levels, so every row resolves to a badge label.
 * @type {Object<string, string>}
 */
const SENSITIVITY_BADGE_LABELS = {Sensitive: SENSITIVITY_SENSITIVE, PossiblySensitive: SENSITIVITY_POSSIBLY, NotSensitive: SENSITIVITY_NOT};

/**
 * @description Maps each stable match-strength band key to its display label. The backend always emits
 * one of the three bands, so every row resolves to a signal-band label.
 * @type {Object<string, string>}
 */
const SIGNAL_BAND_LABELS = {Weak: SIGNAL_BAND_WEAK, Moderate: SIGNAL_BAND_MODERATE, Strong: SIGNAL_BAND_STRONG};

/**
 * @description Numeric rank per match-strength band — how many of the three signal bars light up for a
 * row.
 * @type {Object<string, number>}
 */
const SIGNAL_BAND_RANK = {Weak: 1, Moderate: 2, Strong: 3};

/**
 * @description The three signal-bar slot indexes; each lights when its index is below the row's band
 * rank.
 * @type {Array<number>}
 */
const SIGNAL_BAR_INDEXES = [
	0,
	1,
	2
];

export default class DataMaskingAdvisor extends ComponentBuilder('controller', 'notification', 'navigation')
{
	/**
	 * @description The object picker's options ({Id, Name}), one per selectable triggerable object.
	 * @type {Array<Object>}
	 */
	objectOptions = [];

	/**
	 * @description The org-wide dead-configuration findings (masking targets masking nothing), shown in the
	 * landing dead-config banner.
	 * @type {Array<Object>}
	 */
	deadConfigFindings = [];

	/**
	 * @description The org-wide masking posture summary (as-configured target counts) shown on the Review
	 * landing view. Null until loaded, and stays null if the load fails — the landing then degrades to the
	 * pick-an-object hint.
	 * @type {Object}
	 */
	postureSummary = null;

	/**
	 * @description The org-wide masking inventory (one entry per masked object) shown on the Review landing
	 * beneath the two posture tiles. Empty until loaded, and stays empty if the load fails — the landing
	 * then shows the tiles without a drill-down list.
	 * @type {Array<Object>}
	 */
	inventoryRows = [];

	/**
	 * @description The api name of the object currently being analyzed, or null on the landing view.
	 * @type {string}
	 */
	selectedObject = null;

	/**
	 * @description The selected object's analyzed field rows from describeFields (the raw DTOs, decorated
	 * for render by decorateRow).
	 * @type {Array<Object>}
	 */
	fieldRows = [];

	/**
	 * @description The object-wide masking targets on the selected object (active + inactive), carried on
	 * the describeFields analysis.
	 * @type {Array<Object>}
	 */
	objectWideRules = [];

	/**
	 * @description The dynamically resolved New-Masking-Rule Setup address, carried on the describeFields
	 * analysis. Null until an object loads (and if the analysis carried none).
	 * @type {string}
	 */
	newRuleSetupUrl = null;

	/**
	 * @description Whether native data-classification metadata was available for the analysis; false drives
	 * the heuristic-only-mode notice.
	 * @type {boolean}
	 */
	classificationAvailable = true;

	/**
	 * @description True once an object's fields have loaded at least once, gating the smart list and the
	 * heuristic-only notice.
	 * @type {boolean}
	 */
	hasLoadedFields = false;

	/**
	 * @description Set when a describe fails so the smart list yields to the load-error banner.
	 * @type {boolean}
	 */
	hasFieldLoadError = false;

	/**
	 * @description Whether the Needs-review card is expanded (open by default).
	 * @type {boolean}
	 */
	manualReviewExpanded = true;

	/**
	 * @description Whether the Other card is expanded (collapsed by default).
	 * @type {boolean}
	 */
	otherExpanded = false;

	/**
	 * @description Whether the Other card is narrowed to likely-miss rows only.
	 * @type {boolean}
	 */
	otherMissesOnly = false;

	/**
	 * @description Whether the configuration-health banner is expanded (collapsed by default).
	 * @type {boolean}
	 */
	healthOpen = false;

	/**
	 * @description Whether the object-wide-coverage banner is expanded (collapsed by default).
	 * @type {boolean}
	 */
	bannerOpen = false;

	/**
	 * @description The analysis rule catalogue indexed by developer name, so each row resolves its chip
	 * labels, categories, applicable field types, and dormancy with a map lookup.
	 * @type {Object<string, Object>}
	 */
	rulesByDeveloperName = {};

	/**
	 * @description Existing-active chips the admin unticked (→ disable on deploy), keyed by chip key. Part
	 * of the desired "active after deploy" state: a chip is ticked unless its key sits in the map opposing
	 * its origin's default, and the export package is the diff of these against the org's current state.
	 * @type {Object<string, boolean>}
	 */
	desiredDisabled = {};

	/**
	 * @description Existing-inactive chips the admin ticked (→ re-enable on deploy), keyed by chip key.
	 * @type {Object<string, boolean>}
	 */
	desiredEnabled = {};

	/**
	 * @description Candidate chips the admin unticked (→ never created), keyed by chip key.
	 * @type {Object<string, boolean>}
	 */
	desiredExcluded = {};

	/**
	 * @description Admin-added candidate field rules, mapping a field api name to the rule developer names
	 * added to it. Kept apart from the recommendation so a revert/clear restores the seed; feeds the
	 * candidate chips and persists in the draft.
	 * @type {Object<string, Array<string>>}
	 */
	addedFieldRules = {};

	/**
	 * @description Admin-added object-wide candidate rule developer names. Kept apart from the
	 * recommendation so a revert/clear restores the seed; feeds the candidate chips and persists.
	 * @type {Array<string>}
	 */
	addedObjectWideRules = [];

	/**
	 * @description Reclassify overrides keyed by field api name: {level, source}. Forces a field's
	 * classification and re-sections it in place.
	 * @type {Object<string, Object>}
	 */
	overrideByApiName = {};

	/**
	 * @description Per overridden field, its candidate chips' prior excluded state captured on the first
	 * override so a revert restores it exactly.
	 * @type {Object<string, Object>}
	 */
	selectionBeforeOverride = {};

	/**
	 * @description Set once a draft write fails so the "changes can't be saved" warning is shown once, not
	 * per edit.
	 * @type {boolean}
	 */
	draftSaveWarned = false;

	/**
	 * @description The custom-object coverage scan's lifecycle: idle, running, done, or cancelled. Drives
	 * which of the scan section's states the landing renders.
	 * @type {string}
	 */
	scanStatus = SCAN_IDLE;

	/**
	 * @description True once the Health Check deep-link's page state has been read and carried the
	 * scan-request flag. Combined with a non-empty candidate list and an idle scan status, this drives the
	 * coverage scan on arrival.
	 * @type {boolean}
	 */
	scanRequestedByDeepLink = false;

	/**
	 * @description The objects the last scan flagged — those carrying at least one likely-sensitive field
	 * (Sensitive or Possibly Sensitive) with no active masking — each with its flagged fields ({apiName,
	 * objectLabel, flaggedFields}). Preserved while drilling into a flagged object so the back link returns
	 * to the results.
	 * @type {Array<Object>}
	 */
	scanResults = [];

	/**
	 * @description How many candidate objects the running (or finished) scan has assessed so far — the
	 * numerator of the progress count and the basis of the assessed/clean summary counts.
	 * @type {number}
	 */
	scanAssessedCount = 0;

	/**
	 * @description The running scan's progress ({index, total, name}): objects assessed, the population
	 * total, and the object currently being assessed.
	 * @type {Object}
	 */
	scanProgress = {index: 0, total: 0, name: ''};

	/**
	 * @description Whether managed-package custom objects are opted into the scan population. Off by default
	 * so a large AppExchange footprint never buries the subscriber's own coverage gaps.
	 * @type {boolean}
	 */
	includeManaged = false;

	/**
	 * @description Set when the administrator cancels a running scan; the worker pool stops pulling new
	 * objects and the partial results are kept.
	 * @type {boolean}
	 */
	scanCancelRequested = false;

	/**
	 * @description True when the current object was opened from a scan flagged row, so its screen shows the
	 * scan provenance banner and a link back to the results.
	 * @type {boolean}
	 */
	fromScan = false;

	/**
	 * @description Static label strings the template renders, grouped so the markup reads `{labels.x}`.
	 * @type {Object<string, string>}
	 */
	labels = {
		cardTitle: CARD_TITLE,
		refreshAltText: REFRESH_ALT_TEXT,
		scopeBannerBody: SCOPE_BANNER_BODY,
		deadConfigHeading: DEAD_CONFIG_HEADING,
		coverageHeading: COVERAGE_HEADING,
		addObjectButton: ADD_OBJECT_BUTTON,
		addObjectBack: ADD_OBJECT_BACK,
		inventoryExportButton: INVENTORY_EXPORT_BUTTON,
		heuristicOnlyNotice: HEURISTIC_ONLY_NOTICE,
		emptyHeading: EMPTY_HEADING,
		emptyBody: EMPTY_BODY,
		errorLoadFailed: ERROR_LOAD_FAILED,
		lowConfidenceMatchTag: OTHER_LOW_CONFIDENCE_TAG,
		columnField: COLUMN_FIELD,
		columnSensitivity: COLUMN_SENSITIVITY,
		columnMaskingRules: COLUMN_MASKING_RULES,
		sectionReadyGuidance: SECTION_READY_GUIDANCE,
		sectionReviewGuidance: SECTION_REVIEW_GUIDANCE,
		sectionOtherSummary: SECTION_OTHER_SUMMARY,
		exportPackageLabel: EXPORT_PACKAGE_LABEL,
		otherMissesOnlyLabel: OTHER_MISSES_ONLY_LABEL,
		revertOverride: REVERT_OVERRIDE_LABEL,
		clearDraft: CLEAR_DRAFT_LABEL,
		postureHeading: POSTURE_HEADING,
		postureAsConfiguredNote: POSTURE_AS_CONFIGURED_NOTE,
		postureObjectsWithMasking: POSTURE_OBJECTS_WITH_MASKING,
		postureDeadConfigurations: POSTURE_DEAD_CONFIGURATIONS,
		inventoryHeading: INVENTORY_HEADING,
		inventoryFooter: INVENTORY_FOOTER,
		postureBarelyMaskedNote: POSTURE_BARELY_MASKED_NOTE,
		maskingCellObjectWideLine: MASKING_CELL_OBJECT_WIDE_LINE,
		maskingCellFieldLevelLine: MASKING_CELL_FIELD_LEVEL_LINE,
		addRule: ADD_RULE_LABEL,
		addObjectWideRule: ADD_OBJECT_WIDE_RULE_LABEL,
		chipSupersededFlag: CHIP_SUPERSEDED_FLAG,
		objectWideHeadingNone: OBJECT_WIDE_HEADING_NONE,
		objectWideNoteActive: OBJECT_WIDE_NOTE_ACTIVE,
		objectWideNoteNone: OBJECT_WIDE_NOTE_NONE,
		healthHeading: HEALTH_HEADING,
		noChangesQueued: NO_CHANGES_QUEUED_NOTE,
		coverageScanHeading: COVERAGE_SCAN_HEADING,
		coverageScanIntro: COVERAGE_SCAN_INTRO,
		coverageScanHowItWorks: COVERAGE_SCAN_HOW_IT_WORKS,
		coverageScanNoCandidates: COVERAGE_SCAN_NO_CANDIDATES,
		coverageScanCancel: COVERAGE_SCAN_CANCEL,
		coverageScanRescan: COVERAGE_SCAN_RESCAN,
		coverageScanNoMaskingPill: COVERAGE_SCAN_NO_MASKING_PILL,
		coverageScanFlaggedFooter: COVERAGE_SCAN_FLAGGED_FOOTER,
		coverageScanEmptyState: COVERAGE_SCAN_EMPTY_STATE,
		coverageScanBackToScan: COVERAGE_SCAN_BACK_TO_SCAN
	};

	/**
	 * @description Whether the org has any dead-configuration findings, gating the landing dead-config
	 * banner.
	 * @returns {boolean}
	 */
	get hasDeadConfig()
	{
		return this.deadConfigFindings.length > 0;
	}

	/**
	 * @description The dead-config banner summary line, singular or count-substituted plural.
	 * @returns {string}
	 */
	get deadConfigSummary()
	{
		const count = this.deadConfigFindings.length;
		if(count === 1)
		{
			return DEAD_CONFIG_SUMMARY_SINGULAR;
		}
		return DEAD_CONFIG_SUMMARY_PLURAL.replace('{0}', String(count));
	}

	/**
	 * @description True once fields have loaded but native classification was unavailable, driving the
	 * heuristic-only-mode notice.
	 * @returns {boolean}
	 */
	get isHeuristicOnlyMode()
	{
		return this.hasLoadedFields && this.classificationAvailable === false;
	}

	/**
	 * @description Whether the pick-an-object empty hint shows (no object selected).
	 * @returns {boolean}
	 */
	get showEmptyHint()
	{
		return !this.selectedObject;
	}

	/**
	 * @description Whether the org-wide posture summary has loaded. It renders on the Review landing (no
	 * object selected) once loaded; a failed load leaves it null so the landing falls back to the
	 * pick-an-object hint rather than a blank.
	 * @returns {boolean}
	 */
	get hasPosture()
	{
		return this.postureSummary !== null;
	}

	/**
	 * @description True when the org has no active masking targets at all (field-level or object-wide) —
	 * drives the "almost nothing masked yet" finding so the stock-config posture reads as a finding, not a
	 * blank. Only evaluated by the template inside the hasPosture guard, so postureSummary is non-null here.
	 * @returns {boolean}
	 */
	get postureNothingMasked()
	{
		return (this.postureSummary.activeFieldTargetCount + this.postureSummary.sObjectWideTargetCount) === 0;
	}

	/**
	 * @description The combined assistive label for the objects-with-masking posture tile, so a screen
	 * reader hears "{n} object(s) with masking configured" as one phrase rather than a bare number then its
	 * caption. Read only inside the hasPosture guard, so postureSummary is non-null here.
	 * @returns {string}
	 */
	get postureObjectsAriaLabel()
	{
		return String(this.postureSummary.objectsWithActiveTargets) + ' ' + this.labels.postureObjectsWithMasking;
	}

	/**
	 * @description The combined assistive label for the dead-configurations posture tile. Read only inside
	 * the hasPosture guard, so postureSummary is non-null here.
	 * @returns {string}
	 */
	get postureDeadAriaLabel()
	{
		return String(this.postureSummary.deadConfigCount) + ' ' + this.labels.postureDeadConfigurations;
	}

	/**
	 * @description True when the org-wide inventory has at least one masked object to drill into; gates the
	 * inventory list that sits under the two posture tiles on the landing.
	 * @returns {boolean}
	 */
	get hasInventory()
	{
		return this.inventoryRows.length > 0;
	}

	/**
	 * @description Api names of the objects that already have active masking (the masked inventory), used to
	 * tag rows "Masked" in the add-object dialog. Null-safe — the inventory read can be absent before it
	 * resolves.
	 * @returns {Array<string>}
	 */
	get maskedObjectApiNames()
	{
		return (Array.isArray(this.inventoryRows) ? this.inventoryRows : []).map((row) => row.objectApiName);
	}

	/**
	 * @description Shapes each inventory row for the template: display-only applied-rule chips, a "N
	 * object-wide · M field-level" meta line, and a separate dead-count suffix rendered only when the object
	 * has dead targets.
	 * @returns {Array<Object>}
	 */
	get decoratedInventory()
	{
		return this.inventoryRows.map((row) => ({
			objectApiName: row.objectApiName,
			objectLabel: row.objectLabel,
			ruleChips: row.ruleLabels.map((label) => ({key: row.objectApiName + '|' + label, label})),
			metaText: INVENTORY_COUNT_META.replace('{0}', String(row.objectWideTargetCount)).replace('{1}', String(row.fieldTargetCount)),
			hasDead: row.deadCount > 0,
			deadText: INVENTORY_DEAD_SUFFIX.replace('{0}', String(row.deadCount))
		}));
	}

	/**
	 * @description Decorates and sections every field. Low-confidence (single weak heuristic signal) matches
	 * are no longer hidden — they fall to All other fields tagged and floated to the top. No user column
	 * sort: Ready / Needs review keep the describe order; Other sorts itself low-confidence then
	 * likely-misses first.
	 * @returns {Array<Object>}
	 */
	get decoratedRows()
	{
		return this.fieldRows.map((row) => this.decorateRow(row));
	}

	/**
	 * @description The Ready-to-mask rows: each decorated row whose resolved section is Ready (a row with a
	 * recommended rule). A reclassify override can move a row between sections — see decorateRow.
	 * @returns {Array<Object>}
	 */
	get readyRows()
	{
		return this.decoratedRows.filter((row) => row.section === SECTION_READY);
	}

	/**
	 * @description The Needs-review rows: each decorated row whose resolved section is Needs review (a
	 * flagged row with no rule).
	 * @returns {Array<Object>}
	 */
	get manualReviewRows()
	{
		return this.decoratedRows.filter((row) => row.section === SECTION_REVIEW);
	}

	/**
	 * @description The Other rows: each decorated row whose resolved section is Other (everything not Ready
	 * or Needs review).
	 * @returns {Array<Object>}
	 */
	get otherRows()
	{
		return this.decoratedRows.filter((row) => row.section === SECTION_OTHER);
	}

	/**
	 * @description The Other rows sorted so the fields worth a second look surface above the rest of the
	 * noise — by rank, then alphabetical by api name within a rank.
	 * @returns {Array<Object>}
	 */
	get otherRowsSorted()
	{
		return this.otherRows.slice().sort((left, right) => this.otherRank(left) - this.otherRank(right) || left.apiName.localeCompare(right.apiName));
	}

	/**
	 * @description The Other rows to render: the sorted rows, optionally narrowed to likely misses. The
	 * counter + summary strip stay on the full Other count regardless.
	 * @returns {Array<Object>}
	 */
	get otherRenderSource()
	{
		if(this.otherMissesOnly)
		{
			return this.otherRowsSorted.filter((row) => row.likelyMiss === true);
		}
		return this.otherRowsSorted;
	}

	/**
	 * @description The Other rows actually painted — the render source capped at OTHER_ROW_CAP so an object
	 * with hundreds of unrecommended fields still renders fast.
	 * @returns {Array<Object>}
	 */
	get otherRowsRendered()
	{
		return this.otherRenderSource.slice(0, OTHER_ROW_CAP);
	}

	/**
	 * @description Whether the Other render source exceeds the row cap, so the "showing N of M" note shows.
	 * @returns {boolean}
	 */
	get isOtherCapped()
	{
		return this.otherRenderSource.length > OTHER_ROW_CAP;
	}

	/**
	 * @description The capped-rows note naming the cap and the full render-source count.
	 * @returns {string}
	 */
	get otherCapNote()
	{
		return OTHER_ROW_CAP_NOTE.replace('{0}', String(OTHER_ROW_CAP)).replace('{1}', String(this.otherRenderSource.length));
	}

	/**
	 * @description Whether the Ready card has any rows.
	 * @returns {boolean}
	 */
	get hasReadyRows()
	{
		return this.readyRows.length > 0;
	}

	/**
	 * @description Whether the Needs-review card has any rows.
	 * @returns {boolean}
	 */
	get hasManualReviewRows()
	{
		return this.manualReviewRows.length > 0;
	}

	/**
	 * @description Whether the Other card has any rows.
	 * @returns {boolean}
	 */
	get hasOtherRows()
	{
		return this.otherRows.length > 0;
	}

	/**
	 * @description The summary-strip Ready segment, with the Ready row count substituted.
	 * @returns {string}
	 */
	get summaryReadyText()
	{
		return SUMMARY_READY.replace('{0}', String(this.readyRows.length));
	}

	/**
	 * @description The summary-strip to-review segment, with the Needs-review row count substituted.
	 * @returns {string}
	 */
	get summaryToReviewText()
	{
		return SUMMARY_TO_REVIEW.replace('{0}', String(this.manualReviewRows.length));
	}

	/**
	 * @description The summary-strip Other segment, with the Other row count substituted.
	 * @returns {string}
	 */
	get summaryOtherText()
	{
		return SUMMARY_OTHER.replace('{0}', String(this.otherRows.length));
	}

	/**
	 * @description The export package size (create + disable + re-enable), read from the single
	 * computeExportDiff walk. Drives the "→ N changes" summary segment, the Export button's enablement, and
	 * the count badge.
	 * @returns {number}
	 */
	get exportChangeCount()
	{
		return this.computeExportDiff().targets.length;
	}

	/**
	 * @description Whether the export diff carries at least one change.
	 * @returns {boolean}
	 */
	get hasExportChanges()
	{
		return this.exportChangeCount > 0;
	}

	/**
	 * @description The summary-strip changes segment, with the export change count substituted.
	 * @returns {string}
	 */
	get summaryChangesText()
	{
		return SUMMARY_CHANGES.replace('{0}', String(this.exportChangeCount));
	}

	/**
	 * @description Whether any draft state exists — a reclassify override or any desired-state toggle or
	 * admin-added rule — so the Clear-draft affordance shows and the admin can always reset to the seeded
	 * recommendations.
	 * @returns {boolean}
	 */
	get hasDraftState()
	{
		return Object.keys(this.overrideByApiName).length > 0 || Object.keys(this.desiredDisabled).length > 0 || Object.keys(this.desiredEnabled).length > 0 || Object.keys(
				this.desiredExcluded).length > 0 || Object.keys(this.addedFieldRules).length > 0 || this.addedObjectWideRules.length > 0;
	}

	/**
	 * @description The Ready card heading with its row count substituted.
	 * @returns {string}
	 */
	get readySectionHeading()
	{
		return SECTION_READY_HEADING.replace('{0}', String(this.readyRows.length));
	}

	/**
	 * @description The Needs-review card heading with its row count substituted.
	 * @returns {string}
	 */
	get manualReviewSectionHeading()
	{
		return SECTION_REVIEW_HEADING.replace('{0}', String(this.manualReviewRows.length));
	}

	/**
	 * @description The Other card heading with its row count substituted.
	 * @returns {string}
	 */
	get otherSectionHeading()
	{
		return SECTION_OTHER_HEADING.replace('{0}', String(this.otherRows.length));
	}

	/**
	 * @description The Needs-review card's aria-expanded string.
	 * @returns {string}
	 */
	get manualReviewAriaExpanded()
	{
		return this.manualReviewExpanded ? 'true' : 'false';
	}

	/**
	 * @description The Other card's aria-expanded string.
	 * @returns {string}
	 */
	get otherAriaExpanded()
	{
		return this.otherExpanded ? 'true' : 'false';
	}

	/**
	 * @description The object-wide-coverage banner's aria-expanded string.
	 * @returns {string}
	 */
	get bannerAriaExpanded()
	{
		return this.bannerOpen ? 'true' : 'false';
	}

	/**
	 * @description The configuration-health banner's aria-expanded string.
	 * @returns {string}
	 */
	get healthAriaExpanded()
	{
		return this.healthOpen ? 'true' : 'false';
	}

	/**
	 * @description Whether the Export button is disabled — true until the diff has at least one create /
	 * disable / re-enable.
	 * @returns {boolean}
	 */
	get exportButtonDisabled()
	{
		return !this.hasExportChanges;
	}

	/**
	 * @description The active object-wide targets on the selected object.
	 * @returns {Array<Object>}
	 */
	get activeObjectWideRules()
	{
		return this.objectWideRules.filter((rule) => rule.isActive);
	}

	/**
	 * @description The inactive object-wide targets on the selected object (masking nothing) — the
	 * configuration-health input.
	 * @returns {Array<Object>}
	 */
	get inactiveObjectWideRules()
	{
		return this.objectWideRules.filter((rule) => rule.isActive === false);
	}

	/**
	 * @description The object-wide banner heading: how many active object-wide rules mask the object, or
	 * that it has none.
	 * @returns {string}
	 */
	get objectWideBannerHeading()
	{
		const activeCount = this.activeObjectWideRules.length;
		if(activeCount === 0)
		{
			return this.labels.objectWideHeadingNone.replace('{0}', this.selectedObject);
		}
		if(activeCount === 1)
		{
			return OBJECT_WIDE_HEADING_ACTIVE_SINGULAR.replace('{0}', this.selectedObject);
		}
		return OBJECT_WIDE_HEADING_ACTIVE_PLURAL.replace('{0}', this.selectedObject).replace('{1}', String(activeCount));
	}

	/**
	 * @description The object-wide banner's show/hide-detail toggle label, by open state.
	 * @returns {string}
	 */
	get objectWideBannerToggleLabel()
	{
		return this.bannerOpen ? BANNER_HIDE_DETAIL : BANNER_SHOW_DETAIL;
	}

	/**
	 * @description The object-wide banner note, by whether the object has active object-wide rules.
	 * @returns {string}
	 */
	get objectWideBannerNote()
	{
		return this.activeObjectWideRules.length > 0 ? this.labels.objectWideNoteActive : this.labels.objectWideNoteNone;
	}

	/**
	 * @description The tickable object-wide chips rendered in the expanded banner: active (🌐, ticked),
	 * inactive (⚠, unticked), and admin-added candidates (🌐, ticked). The existing chips carry the
	 * underlying target's developer name and caller class so the export diff can re-emit a disabled /
	 * re-enabled record without re-querying; a candidate has no target yet, so the diff creates one.
	 * @returns {Array<Object>}
	 */
	get objectWideBannerChips()
	{
		const chips = [];
		this.activeObjectWideRules.forEach((rule) =>
		{
			chips.push(this.objectWideChip(rule, ORIGIN_ACTIVE));
		});
		this.inactiveObjectWideRules.forEach((rule) =>
		{
			chips.push(this.objectWideChip(rule, ORIGIN_INACTIVE));
		});
		// Skip an added candidate already running as a real object-wide target (active or inactive) — a
		// cross-session create can leave a stale entry whose candidate chip would collide with the existing
		// chip's key and emit a duplicate create. Mirrors the field-level reconciliation in fieldCandidatesFor.
		const existingObjectWideRules = new Set(this.objectWideRules.map((rule) => rule.ruleDeveloperName));
		this.addedObjectWideRules.forEach((developerName) =>
		{
			if(existingObjectWideRules.has(developerName))
			{
				return;
			}
			const rule = this.rulesByDeveloperName[developerName];
			if(rule)
			{
				chips.push(this.objectWideCandidateChip(rule));
			}
		});
		return chips;
	}

	/**
	 * @description The field-level targets across the object that are masking nothing (an inactive applied
	 * target).
	 * @returns {Array<Object>}
	 */
	get deadFieldTargets()
	{
		const dead = [];
		this.fieldRows.forEach((row) =>
		{
			(row.appliedRules || []).forEach((applied) =>
			{
				if(applied.isActive === false)
				{
					dead.push({key: row.apiName + '|' + applied.ruleDeveloperName, fieldLabel: row.label, ruleLabel: applied.ruleLabel});
				}
			});
		});
		return dead;
	}

	/**
	 * @description Whether the configuration-health banner has any findings (inactive object-wide rules or
	 * dead field targets).
	 * @returns {boolean}
	 */
	get hasHealthFindings()
	{
		return this.inactiveObjectWideRules.length > 0 || this.deadFieldTargets.length > 0;
	}

	/**
	 * @description Whether the object has any dead (inactive applied) field targets.
	 * @returns {boolean}
	 */
	get hasDeadFieldTargets()
	{
		return this.deadFieldTargets.length > 0;
	}

	/**
	 * @description Whether the "no changes queued" hint shows — true whenever the export diff is empty, so a
	 * freshly loaded object that matches the org state reads as "nothing to deploy" rather than an
	 * enabled-looking export.
	 * @returns {boolean}
	 */
	get showNoChangesNote()
	{
		return !this.hasExportChanges;
	}

	/**
	 * @description The configuration-health banner heading — "Configuration health — N object-wide rules
	 * inactive · M field targets masking nothing".
	 * @returns {string}
	 */
	get healthBannerHeading()
	{
		const parts = [];
		const inactiveCount = this.inactiveObjectWideRules.length;
		if(inactiveCount === 1)
		{
			parts.push(HEALTH_SUMMARY_OBJECT_WIDE_SINGULAR);
		}
		else if(inactiveCount > 1)
		{
			parts.push(HEALTH_SUMMARY_OBJECT_WIDE_PLURAL.replace('{0}', String(inactiveCount)));
		}
		const deadCount = this.deadFieldTargets.length;
		if(deadCount === 1)
		{
			parts.push(HEALTH_SUMMARY_DEAD_SINGULAR);
		}
		else if(deadCount > 1)
		{
			parts.push(HEALTH_SUMMARY_DEAD_PLURAL.replace('{0}', String(deadCount)));
		}
		return this.labels.healthHeading + ' — ' + parts.join(' · ');
	}

	/**
	 * @description The configuration-health banner's show/hide-detail toggle label, by open state.
	 * @returns {string}
	 */
	get healthBannerToggleLabel()
	{
		return this.healthOpen ? BANNER_HIDE_DETAIL : BANNER_SHOW_DETAIL;
	}

	/**
	 * @description The inactive-object-wide-rules detail line, singular or plural; null when there are none.
	 * @returns {string}
	 */
	get healthObjectWideDetail()
	{
		const count = this.inactiveObjectWideRules.length;
		if(count === 0)
		{
			return null;
		}
		return count === 1 ? HEALTH_DETAIL_OBJECT_WIDE_SINGULAR : HEALTH_DETAIL_OBJECT_WIDE_PLURAL.replace('{0}', String(count));
	}

	/**
	 * @description One detail line per dead field target, naming the rule that is masking nothing.
	 * @returns {Array<Object>}
	 */
	get healthDeadFieldDetails()
	{
		return this.deadFieldTargets.map((target) => ({key: target.key, text: HEALTH_DETAIL_DEAD_FIELD_TARGET.replace('{0}', target.ruleLabel)}));
	}

	/**
	 * @description The per-object sessionStorage key the draft persists under (one entry per object).
	 * @returns {string}
	 */
	get draftKey()
	{
		return DRAFT_KEY_PREFIX + this.selectedObject;
	}

	/**
	 * @description The rules addable object-wide: every catalogue rule not already an object-wide target
	 * (active or inactive) or candidate. Each option carries its applicable-types line and, for a rule whose
	 * types match no field currently on the object, a warning that it won't mask anything here yet —
	 * object-wide rules run on every field, so it stays offered (a matching field could be added later).
	 * @returns {Array<Object>}
	 */
	get addObjectWideOptions()
	{
		const present = new Set([
			...this.objectWideRules.map((rule) => rule.ruleDeveloperName),
			...this.addedObjectWideRules
		]);
		return Object.values(this.rulesByDeveloperName)
		.filter((rule) => !present.has(rule.developerName))
		.map((rule) => this.toAddOption(rule, this.objectWideWarningFor(rule)));
	}

	/**
	 * @description The objects the coverage scan will assess: the subscriber's own custom objects, plus
	 * managed-package custom objects when opted in. Standard objects are never scan candidates.
	 * @returns {Array<Object>}
	 */
	get scanCandidates()
	{
		return this.objectOptions.filter((option) => option.isCustom && (this.includeManaged || !option.namespacePrefix));
	}

	/**
	 * @description How many of the subscriber's own (un-namespaced) custom objects exist — the default scan
	 * population, shown in the idle population note.
	 * @returns {number}
	 */
	get ownCustomObjectCount()
	{
		return this.objectOptions.filter((option) => option.isCustom && !option.namespacePrefix).length;
	}

	/**
	 * @description How many custom objects come from managed packages — the opt-in count shown in the
	 * managed-package clause and toggle.
	 * @returns {number}
	 */
	get managedCustomObjectCount()
	{
		return this.objectOptions.filter((option) => option.isCustom && option.namespacePrefix).length;
	}

	/**
	 * @description Whether any managed-package custom objects exist, gating the opt-in clause and toggle so
	 * neither renders in an org with no installed-package data model.
	 * @returns {boolean}
	 */
	get hasManagedCustomObjects()
	{
		return this.managedCustomObjectCount > 0;
	}

	/**
	 * @description Whether the current population has anything to scan, gating the scan button against the
	 * no-custom-objects note.
	 * @returns {boolean}
	 */
	get hasScanCandidates()
	{
		return this.scanCandidates.length > 0;
	}

	/**
	 * @description Whether the scan section is idle (no scan started or a managed-toggle reset).
	 * @returns {boolean}
	 */
	get isScanIdle()
	{
		return this.scanStatus === SCAN_IDLE;
	}

	/**
	 * @description Whether a scan is currently in flight, driving the progress state.
	 * @returns {boolean}
	 */
	get isScanRunning()
	{
		return this.scanStatus === SCAN_RUNNING;
	}

	/**
	 * @description Whether a scan finished on its own, driving the full summary.
	 * @returns {boolean}
	 */
	get isScanDone()
	{
		return this.scanStatus === SCAN_DONE;
	}

	/**
	 * @description Whether a scan was cancelled, driving the partial-results note.
	 * @returns {boolean}
	 */
	get isScanCancelled()
	{
		return this.scanStatus === SCAN_CANCELLED;
	}

	/**
	 * @description Whether scan results (complete or partial) should render — true once a scan has finished
	 * or been cancelled.
	 * @returns {boolean}
	 */
	get scanShowResults()
	{
		return this.isScanDone || this.isScanCancelled;
	}

	/**
	 * @description The idle population note: how many own custom objects the subscriber has.
	 * @returns {string}
	 */
	get scanPopulationNote()
	{
		return COVERAGE_SCAN_POPULATION_NOTE.replace('{0}', String(this.ownCustomObjectCount));
	}

	/**
	 * @description The managed-package clause of the idle population note (shown only when such objects
	 * exist): how many more come from managed packages and why they are excluded by default.
	 * @returns {string}
	 */
	get scanManagedClause()
	{
		return COVERAGE_SCAN_POPULATION_MANAGED_CLAUSE.replace('{0}', String(this.managedCustomObjectCount));
	}

	/**
	 * @description The managed-package opt-in toggle label, carrying the managed-object count.
	 * @returns {string}
	 */
	get scanIncludeManagedLabel()
	{
		return COVERAGE_SCAN_INCLUDE_MANAGED_LABEL.replace('{0}', String(this.managedCustomObjectCount));
	}

	/**
	 * @description The scan button label, carrying the current population total.
	 * @returns {string}
	 */
	get scanButtonLabel()
	{
		return COVERAGE_SCAN_BUTTON.replace('{0}', String(this.scanCandidates.length));
	}

	/**
	 * @description The running progress line: the object being assessed and how far through the population.
	 * @returns {string}
	 */
	get scanProgressText()
	{
		const position = Math.min(this.scanProgress.index + 1, this.scanProgress.total);
		return COVERAGE_SCAN_SCANNING.replace('{0}', this.scanProgress.name).replace('{1}', String(position)).replace('{2}', String(this.scanProgress.total));
	}

	/**
	 * @description The running progress's in-flight note — how many objects are assessed at a time.
	 * @returns {string}
	 */
	get scanInFlightNote()
	{
		return COVERAGE_SCAN_IN_FLIGHT_NOTE.replace('{0}', String(Math.min(SCAN_CONCURRENCY, this.scanProgress.total)));
	}

	/**
	 * @description The inline width style for the progress bar fill, as a percentage of the population.
	 * @returns {string}
	 */
	get scanProgressBarStyle()
	{
		const percent = this.scanProgress.total > 0 ? Math.round((this.scanProgress.index / this.scanProgress.total) * 100) : 0;
		return `width: ${percent}%;`;
	}

	/**
	 * @description How many scanned objects require attention — the flagged-object count.
	 * @returns {number}
	 */
	get scanNeedsAttentionCount()
	{
		return this.scanResults.length;
	}

	/**
	 * @description The total likely-sensitive fields with no masking across all flagged objects.
	 * @returns {number}
	 */
	get scanFlaggedFieldCount()
	{
		return this.scanResults.reduce((total, result) => total + result.flaggedFields.length, 0);
	}

	/**
	 * @description How many assessed objects showed no likely-sensitive fields — the clean-object count.
	 * @returns {number}
	 */
	get scanCleanCount()
	{
		return this.scanAssessedCount - this.scanResults.length;
	}

	/**
	 * @description The completed-scan summary line: objects assessed, objects needing attention, and flagged
	 * fields.
	 * @returns {string}
	 */
	get scanSummaryText()
	{
		return COVERAGE_SCAN_SUMMARY.replace('{0}', String(this.scanAssessedCount)).replace('{1}', String(this.scanNeedsAttentionCount))
		.replace('{2}', String(this.scanFlaggedFieldCount));
	}

	/**
	 * @description The cancelled-scan note: how many of the population were assessed before cancellation.
	 * @returns {string}
	 */
	get scanPartialNote()
	{
		return COVERAGE_SCAN_PARTIAL_NOTE.replace('{0}', String(this.scanAssessedCount)).replace('{1}', String(this.scanProgress.total));
	}

	/**
	 * @description Whether a finished scan left a clean-object footnote to show (some flagged, some clean).
	 * @returns {boolean}
	 */
	get showScanCleanNote()
	{
		return this.isScanDone && this.scanResults.length > 0 && this.scanCleanCount > 0;
	}

	/**
	 * @description The clean-object footnote: how many other custom objects showed no likely-sensitive
	 * fields.
	 * @returns {string}
	 */
	get scanCleanNote()
	{
		return COVERAGE_SCAN_CLEAN_NOTE.replace('{0}', String(this.scanCleanCount));
	}

	/**
	 * @description Whether the scan flagged at least one object, gating the flagged rows against the
	 * all-clear empty state.
	 * @returns {boolean}
	 */
	get scanHasFlagged()
	{
		return this.scanResults.length > 0;
	}

	/**
	 * @description The flagged objects shaped for the template: each with its api name, label, and field
	 * chips whose text carries a Long Text Area suffix when applicable.
	 * @returns {Array<Object>}
	 */
	get scanFlaggedRows()
	{
		return this.scanResults.map((result) => ({
			apiName: result.apiName, objectLabel: result.objectLabel, flaggedFields: result.flaggedFields.map((field) => ({
				key: field.fieldApiName,
				text: field.isLongTextArea ? `${field.fieldLabel} · ${COVERAGE_SCAN_LONG_TEXT_SUFFIX}` : field.fieldLabel,
				sensitivityLevel: field.sensitivityLevel
			}))
		}));
	}

	/**
	 * @description Whether the selected object was opened from a scan flagged row, gating its provenance
	 * banner.
	 * @returns {boolean}
	 */
	get showScanProvenance()
	{
		return this.fromScan && Boolean(this.selectedObject);
	}

	/**
	 * @description The provenance banner text: how many likely-sensitive fields the scan flagged on the
	 * object now open.
	 * @returns {string}
	 */
	get scanProvenanceText()
	{
		const count = this.scanResults.find((result) => result.apiName === this.selectedObject)?.flaggedFields.length ?? 0;
		return COVERAGE_SCAN_PROVENANCE.replace('{0}', String(count));
	}

	/**
	 * @description The sort weight for an Other row: a low-confidence heuristic match (a single weak
	 * positive signal) ranks above a likely miss (a sensitive-looking type the resolver left unflagged),
	 * which ranks above plain unflagged fields.
	 * @param {Object} row A decorated Other row.
	 * @returns {number}
	 */
	otherRank(row)
	{
		if(row.isLowConfidenceMatch)
		{
			return 0;
		}
		return row.likelyMiss ? 1 : 2;
	}

	/**
	 * @description Builds a tickable object-wide candidate chip from an admin-added rule (no existing target
	 * yet).
	 * @param {Object} rule The catalogue rule ({developerName, label, ...}).
	 * @returns {Object}
	 */
	objectWideCandidateChip(rule)
	{
		const key = this.chipKey(SCOPE_OBJECT, '', rule.developerName);
		const desired = this.desiredActive(ORIGIN_CANDIDATE, key);
		return {
			key,
			ruleDeveloperName: rule.developerName,
			ruleLabel: rule.label,
			targetDeveloperName: '',
			callerClass: '',
			origin: ORIGIN_CANDIDATE,
			scope: SCOPE_OBJECT,
			field: '',
			desired,
			glyph: '🌐',
			flag: this.changeFlag(ORIGIN_CANDIDATE, desired),
			ariaLabel: this.chipAria(rule.label, ORIGIN_CANDIDATE),
			supersededByLabel: rule.supersededByLabel || ''
		};
	}

	/**
	 * @description Builds a tickable object-wide chip from an existing target (active or inactive).
	 * @param {Object} rule The existing object-wide target ({ruleDeveloperName, ruleLabel,
	 * targetDeveloperName, callerClass, ...}).
	 * @param {string} origin The chip origin (active / inactive).
	 * @returns {Object}
	 */
	objectWideChip(rule, origin)
	{
		const key = this.chipKey(SCOPE_OBJECT, '', rule.ruleDeveloperName);
		const desired = this.desiredActive(origin, key);
		return {
			key,
			ruleDeveloperName: rule.ruleDeveloperName,
			ruleLabel: rule.ruleLabel,
			targetDeveloperName: rule.targetDeveloperName,
			callerClass: rule.callerClass,
			origin,
			scope: SCOPE_OBJECT,
			field: '',
			desired,
			glyph: origin === ORIGIN_INACTIVE ? '⚠' : '🌐',
			flag: this.changeFlag(origin, desired),
			ariaLabel: this.chipAria(rule.ruleLabel, origin),
			supersededByLabel: rule.supersededByLabel || ''
		};
	}

	/**
	 * @description Starts (or restarts) the custom-object coverage scan.
	 * @returns {Promise}
	 */
	handleScan()
	{
		return this.startScan();
	}

	/**
	 * @description Cancels a running scan: the worker pool stops pulling new objects and keeps the partial
	 * results.
	 */
	handleCancelScan()
	{
		this.scanCancelRequested = true;
	}

	/**
	 * @description Toggles managed-package objects into or out of the scan population and resets the scan to
	 * idle, since the population the prior results reflected has changed.
	 */
	handleToggleManaged()
	{
		this.includeManaged = !this.includeManaged;
		this.resetScan();
	}

	/**
	 * @description Resets the scan to its idle state, discarding any prior results and progress.
	 */
	resetScan()
	{
		this.scanStatus = SCAN_IDLE;
		this.scanResults = [];
		this.scanAssessedCount = 0;
		this.scanProgress = {index: 0, total: 0, name: ''};
		this.scanCancelRequested = false;
	}

	/**
	 * @description Runs the coverage scan over the candidate objects with a bounded worker pool: at most
	 * SCAN_CONCURRENCY assessObjectCoverage calls are in flight at once, progress ticks per object, and the
	 * objects carrying likely-sensitive fields with no masking accumulate into the results. A cancellation
	 * stops the pool from pulling new objects while keeping whatever was already assessed.
	 * @returns {Promise}
	 */
	async startScan()
	{
		this.resetScan();
		const candidates = this.scanCandidates;
		const total = candidates.length;
		this.scanProgress = {index: 0, total, name: candidates.length > 0 ? candidates[0].Name : ''};
		this.scanStatus = SCAN_RUNNING;

		const results = [];
		let cursor = 0;
		const worker = async() =>
		{
			while(cursor < total && !this.scanCancelRequested)
			{
				const candidate = candidates[cursor];
				cursor += 1;
				this.scanProgress = {index: this.scanAssessedCount, total, name: candidate.Name};
				let assessment;
				try
				{
					// eslint-disable-next-line no-await-in-loop -- deliberate pacing: objects are assessed sequentially so the scan stays cancellable and reports per-object progress
					assessment = await this.callControllerMethod(assessObjectCoverage, {objectApiName: candidate.Id});
				}
				catch
				{
					assessment = null;
				}
				this.scanAssessedCount += 1;
				this.scanProgress = {index: this.scanAssessedCount, total, name: candidate.Name};
				if(assessment && assessment.flaggedFields && assessment.flaggedFields.length > 0)
				{
					results.push({apiName: assessment.objectApiName, objectLabel: assessment.objectLabel, flaggedFields: assessment.flaggedFields});
					this.scanResults = [...results];
				}
			}
		};

		const workerCount = Math.min(SCAN_CONCURRENCY, total);
		await Promise.all(Array.from({length: workerCount}, () => worker()));
		this.scanStatus = this.scanCancelRequested ? SCAN_CANCELLED : SCAN_DONE;
	}

	/**
	 * @description Drills into a flagged object from a scan result row, marking the navigation as scan-sourced
	 * so the object's screen shows the provenance banner. The scan results are preserved for the back link.
	 * @param {Event} event The flagged-row click, carrying the object api name in its dataset.
	 * @returns {Promise}
	 */
	async handleScanRowClick(event)
	{
		await this.handleObjectChange({detail: {selectedId: event.currentTarget.dataset.apiName}});
		this.fromScan = true;
	}

	/**
	 * @description Returns from a scan-sourced object screen to the landing, where the scan results still
	 * render.
	 * @returns {Promise}
	 */
	handleBackToScan()
	{
		return this.handleObjectChange({detail: {selectedId: null}});
	}

	/**
	 * @description Opens the "＋ Add object" grouped search dialog over the loaded object universe, the scan's
	 * flagged objects, and the masked-object api names, then describes whichever object the admin picks. The
	 * dialog resolves the picked api name (or null on Close); only a non-null pick drives a selection, so
	 * dismissing leaves the landing untouched. Replaces the old flat 800+ object combobox. Focus returns to
	 * the trigger when the dialog closes without a pick (when a pick is made the trigger unmounts, so the
	 * isConnected guard in restoreFocus makes it a no-op).
	 * @param {Event} event The "＋ Add object" button click, whose currentTarget is the focus-return trigger.
	 * @returns {Promise}
	 */
	async handleOpenAddObject(event)
	{
		const trigger = event.currentTarget;
		const selectedApiName = await MaskingAddObjectDialog.open({
			size: 'small', objectOptions: this.objectOptions, flaggedObjects: this.scanResults, maskedApiNames: this.maskedObjectApiNames
		});
		if(selectedApiName)
		{
			await this.handleObjectChange({detail: {selectedId: selectedApiName}});
		}
		this.restoreFocus(trigger);
	}

	/**
	 * @description Opens the regulated-field inventory export dialog over the loaded object universe and the
	 * masked-object api names — the dialog derives the custom / masked / all export scopes from those, fetches
	 * the chosen scope's per-object inventory itself, and downloads the file. The dialog changes nothing in
	 * the org, so there is nothing to apply on close; focus returns to the trigger.
	 * @param {Event} event The "⤓ Export field inventory" button click, whose currentTarget is the
	 * focus-return trigger.
	 * @returns {Promise}
	 */
	async handleOpenInventoryExport(event)
	{
		const trigger = event.currentTarget;
		await MaskingInventoryExportDialog.open({size: 'medium', objectOptions: this.objectOptions, maskedApiNames: this.maskedObjectApiNames});
		this.restoreFocus(trigger);
	}

	/**
	 * @description Returns from a selected object's screen to the posture landing, clearing the selection the
	 * same way handleObjectChange does for an empty pick. This is the field screen's "← All objects" path now
	 * that the standing picker (which also cleared the selection) is gone.
	 * @returns {Promise}
	 */
	handleBackToLanding()
	{
		return this.handleObjectChange({detail: {selectedId: null}});
	}

	/**
	 * @description Reads the current page reference. The Health Check "Custom-Object Masking Coverage" card
	 * navigates here with a scan-request state ({c__scan: '1'}); capturing it lets the landing auto-run the
	 * coverage scan on arrival so the admin sees the objects the card named rather than a fresh "Scan N"
	 * prompt. Reactive, so a later in-app navigation that adds the flag still requests the scan.
	 * @param {Object} pageReference The current page reference, or undefined before navigation resolves.
	 */
	@wire(CurrentPageReference) captureScanRequest(pageReference)
	{
		this.scanRequestedByDeepLink = pageReference?.state?.[ADVISOR_SCAN_STATE_KEY] === ADVISOR_SCAN_STATE_VALUE;
		this.surfaceScanIfRequested();
	}

	/**
	 * @description Runs the coverage scan when the deep-link requested it and there are candidates to scan.
	 * Called from both the page-reference wire and connectedCallback so it fires whichever order the two
	 * resolve — an empty candidate list (objects not loaded yet, or the org has none of its own) simply
	 * holds it back until the next call. Gated on the idle status, which startScan leaves synchronously
	 * before its first await, so the two callers racing, a re-emit, or a manual scan already under way never
	 * start a second scan.
	 */
	surfaceScanIfRequested()
	{
		if(this.scanRequestedByDeepLink && this.scanStatus === SCAN_IDLE && this.scanCandidates.length > 0)
		{
			this.startScan();
		}
	}

	/**
	 * @description Loads the landing reads on mount: the object universe, dead configurations, the posture
	 * summary, and the posture inventory. Once the objects are loaded it surfaces the deep-link coverage
	 * scan if the Health Check card requested one, so the scan runs alongside the remaining landing reads.
	 */
	async connectedCallback()
	{
		this.isLoading = true;
		await this.loadObjects();
		this.surfaceScanIfRequested();
		await this.loadDeadConfigurations();
		await this.loadPosture();
		await this.loadPostureInventory();
		this.isLoading = false;
	}

	/**
	 * @description Loads the selectable objects into the picker options ({Id, Name}).
	 */
	async loadObjects()
	{
		const objects = await this.callControllerMethod(listObjects);
		this.objectOptions = objects.map((option) => ({Id: option.apiName, Name: option.label, isCustom: option.isCustom, namespacePrefix: option.namespacePrefix}));
	}

	/**
	 * @description Loads the org-wide dead-configuration findings; a failure degrades to an empty list so
	 * the landing still renders.
	 */
	async loadDeadConfigurations()
	{
		try
		{
			this.deadConfigFindings = await this.callControllerMethod(getDeadConfigurations);
		}
		catch
		{
			this.deadConfigFindings = [];
		}
	}

	/**
	 * @description Loads the org-wide posture summary for the Review landing view. The framework swallows a
	 * controller failure (returns undefined), so the summary stays null and the landing degrades to the
	 * pick-an-object hint rather than rendering a blank or broken posture.
	 */
	async loadPosture()
	{
		this.postureSummary = await this.callControllerMethod(getOrgPostureSummary) || null;
	}

	/**
	 * @description Loads the org-wide inventory (one row per masked object) shown beneath the posture tiles.
	 * A failed load leaves the list empty so the landing still renders the tiles.
	 */
	async loadPostureInventory()
	{
		this.inventoryRows = await this.callControllerMethod(getOrgPostureInventory) || [];
	}

	/**
	 * @description Drills into a masked object from its inventory row, reusing the object-change path so the
	 * object opens preselected with its session draft restored. The base lookup display is not updated; the
	 * analysis loads regardless.
	 * @param {Event} event The inventory-row click, carrying the object api name in its dataset.
	 * @returns {Promise}
	 */
	handleInventoryRowClick(event)
	{
		return this.handleObjectChange({detail: {selectedId: event.currentTarget.dataset.apiName}});
	}

	/**
	 * @description Handles an object selection (from the add-object dialog, a scan-flagged row, or an
	 * inventory row): resets the prior object's per-object and desired-state maps, then describes the newly
	 * selected object (or clears the rows when the selection is cleared back to the landing).
	 * @param {Object} event The selection change ({detail: {selectedId}}).
	 */
	async handleObjectChange(event)
	{
		const objectApiName = event.detail.selectedId;
		this.selectedObject = objectApiName;
		this.fromScan = false;
		this.hasFieldLoadError = false;
		this.manualReviewExpanded = true;
		this.otherExpanded = false;
		this.otherMissesOnly = false;
		this.healthOpen = false;
		this.bannerOpen = false;
		this.objectWideRules = [];
		this.newRuleSetupUrl = null;
		this.desiredDisabled = {};
		this.desiredEnabled = {};
		this.desiredExcluded = {};
		this.addedFieldRules = {};
		this.addedObjectWideRules = [];
		this.overrideByApiName = {};
		this.selectionBeforeOverride = {};
		this.draftSaveWarned = false;
		if(!objectApiName)
		{
			this.fieldRows = [];
			this.hasLoadedFields = false;
			return;
		}
		this.isLoading = true;
		await this.describeSelectedObject();
		this.isLoading = false;
	}

	/**
	 * @description Re-runs the org-wide reads (objects, dead configurations, posture, inventory) and, when
	 * an object is selected, re-describes it — preserving the session draft by restoring it after the
	 * re-describe, the same order handleObjectChange uses. The desired-state maps are deliberately not reset
	 * (unlike an object change) so the admin's in-progress edits survive a refresh.
	 */
	async handleRefresh()
	{
		this.isLoading = true;
		await this.loadObjects();
		await this.loadDeadConfigurations();
		await this.loadPosture();
		await this.loadPostureInventory();
		if(this.selectedObject)
		{
			await this.describeSelectedObject();
		}
		this.isLoading = false;
	}

	/**
	 * @description Describes the selected object and restores its session draft. Used by both the object
	 * picker (after it resets the prior object's state) and the refresh button (which preserves the current
	 * state). A controller failure clears the rows and raises the load-error banner.
	 */
	async describeSelectedObject()
	{
		try
		{
			const analysis = await this.callControllerMethod(describeFields, {objectApiName: this.selectedObject});
			this.fieldRows = analysis.fields;
			this.objectWideRules = analysis.objectWideRules || [];
			this.newRuleSetupUrl = analysis.newRuleSetupUrl || null;
			this.rulesByDeveloperName = this.indexRulesByDeveloperName(analysis.rules);
			this.classificationAvailable = analysis.classificationAvailable !== false;
			this.hasLoadedFields = true;
			this.restoreDraft();
		}
		catch
		{
			this.fieldRows = [];
			this.hasFieldLoadError = true;
		}
	}

	/**
	 * @description Toggles the Needs-review card open/closed.
	 */
	handleToggleManualReview()
	{
		this.manualReviewExpanded = !this.manualReviewExpanded;
	}

	/**
	 * @description Toggles the Other card open/closed.
	 */
	handleToggleOther()
	{
		this.otherExpanded = !this.otherExpanded;
	}

	/**
	 * @description Toggles the object-wide-coverage banner open/closed.
	 */
	handleToggleBanner()
	{
		this.bannerOpen = !this.bannerOpen;
	}

	/**
	 * @description Toggles the configuration-health banner open/closed.
	 */
	handleToggleHealth()
	{
		this.healthOpen = !this.healthOpen;
	}

	/**
	 * @description Narrows or widens the Other card to likely-miss rows only.
	 * @param {Event} event The toggle change ({detail: {checked}}).
	 */
	handleOtherMissesToggle(event)
	{
		this.otherMissesOnly = event.detail.checked === true;
	}

	/**
	 * @description The stable key for a rule chip: scope (F field-level / O object-wide), the field api name
	 * (blank for object-wide), and the rule developer name. It is both the dedupe key and the toggle target.
	 * @param {string} scope The chip scope (F / O).
	 * @param {string} field The field api name (blank for object-wide).
	 * @param {string} ruleDeveloperName The rule developer name.
	 * @returns {string}
	 */
	chipKey(scope, field, ruleDeveloperName)
	{
		return scope + '|' + field + '|' + ruleDeveloperName;
	}

	/**
	 * @description The accessible label for a chip's checkbox. The scope/state glyph is decorative
	 * (aria-hidden), so an inactive ("masking nothing") chip folds that state into its checkbox name —
	 * otherwise a screen-reader user would hear only the rule name and miss that the target is currently
	 * dead.
	 * @param {string} ruleLabel The rule's display label.
	 * @param {string} origin The chip origin (active / inactive / candidate).
	 * @returns {string}
	 */
	chipAria(ruleLabel, origin)
	{
		const base = CHIP_TOGGLE_ARIA_TEMPLATE.replace('{0}', ruleLabel);
		return origin === ORIGIN_INACTIVE ? base + ' — ' + CHIP_INACTIVE_SUFFIX : base;
	}

	/**
	 * @description Whether a chip is ticked ("active after deploy"), by origin: an existing-active chip is
	 * ticked unless the admin disabled it; an existing-inactive chip is unticked unless the admin re-enabled
	 * it; a candidate is ticked unless the admin excluded it.
	 * @param {string} origin The chip origin (active / inactive / candidate).
	 * @param {string} key The chip key.
	 * @returns {boolean}
	 */
	desiredActive(origin, key)
	{
		if(origin === ORIGIN_ACTIVE)
		{
			return !this.desiredDisabled[key];
		}
		if(origin === ORIGIN_INACTIVE)
		{
			return Boolean(this.desiredEnabled[key]);
		}
		return !this.desiredExcluded[key];
	}

	/**
	 * @description The package verb a chip's desired state implies, shown as a chip hint: an unticked active
	 * chip will disable, a ticked inactive chip will re-enable, a ticked candidate will be added; anything
	 * else is a no-op and shows no hint.
	 * @param {string} origin The chip origin (active / inactive / candidate).
	 * @param {boolean} desired The chip's desired ticked state.
	 * @returns {string}
	 */
	changeFlag(origin, desired)
	{
		if(origin === ORIGIN_ACTIVE && !desired)
		{
			return CHIP_FLAG_WILL_DISABLE;
		}
		if(origin === ORIGIN_INACTIVE && desired)
		{
			return CHIP_FLAG_WILL_ENABLE;
		}
		if(origin === ORIGIN_CANDIDATE && desired)
		{
			return CHIP_FLAG_TO_ADD;
		}
		return '';
	}

	/**
	 * @description Flips a chip's desired state. A toggle writes to the map opposing the origin's default —
	 * disabling an active chip, enabling an inactive one, excluding a candidate — so re-ticking simply
	 * clears the entry.
	 * @param {string} origin The chip origin (active / inactive / candidate).
	 * @param {string} key The chip key.
	 */
	toggleDesired(origin, key)
	{
		const map = this.desiredMapFor(origin);
		const next = {...map};
		if(next[key])
		{
			delete next[key];
		}
		else
		{
			next[key] = true;
		}
		this.assignDesiredMap(origin, next);
	}

	/**
	 * @description The desired-state map a chip origin writes to (disabled / enabled / excluded).
	 * @param {string} origin The chip origin (active / inactive / candidate).
	 * @returns {Object<string, boolean>}
	 */
	desiredMapFor(origin)
	{
		if(origin === ORIGIN_ACTIVE)
		{
			return this.desiredDisabled;
		}
		if(origin === ORIGIN_INACTIVE)
		{
			return this.desiredEnabled;
		}
		return this.desiredExcluded;
	}

	/**
	 * @description Reassigns the desired-state map for a chip origin (a fresh object reference so the
	 * template re-renders).
	 * @param {string} origin The chip origin (active / inactive / candidate).
	 * @param {Object<string, boolean>} next The next map.
	 */
	assignDesiredMap(origin, next)
	{
		if(origin === ORIGIN_ACTIVE)
		{
			this.desiredDisabled = next;
			return;
		}
		if(origin === ORIGIN_INACTIVE)
		{
			this.desiredEnabled = next;
			return;
		}
		this.desiredExcluded = next;
	}

	/**
	 * @description Toggles a chip from its inline checkbox. The origin + key live on data-* attributes so no
	 * CSS class names or rule developer names need to round-trip through the DOM.
	 * @param {Event} event The checkbox change, carrying toggleOrigin + toggleKey in its dataset.
	 */
	handleChipToggle(event)
	{
		this.toggleDesired(event.currentTarget.dataset.toggleOrigin, event.currentTarget.dataset.toggleKey);
		this.persistDraft();
	}

	/**
	 * @description Returns keyboard focus to the element that opened a modal once it closes, so a keyboard /
	 * screen-reader user lands back on the chip, badge, or button they invoked rather than at the top of the
	 * document. A trigger that re-rendered away while the modal was open (a toggled chip, a row that
	 * re-sectioned) is no longer connected, so it is skipped and the platform's own focus fallback applies.
	 * @param {Element} trigger The element that opened the modal.
	 */
	restoreFocus(trigger)
	{
		if(trigger.isConnected)
		{
			trigger.focus();
		}
	}

	/**
	 * @description Opens the rule-detail popup for the clicked chip, seeded from the rule catalogue + the
	 * chip's current desired state, so the popup opens reflecting the inline chip. On close it folds the
	 * popup's desired state back into the chip (a managed chip whose state changed is toggled, keeping the
	 * popup checkbox and the inline chip in lockstep) and, for the Manage-in-Setup action, navigates to
	 * Setup. A read-only context chip (an object-wide rule shown on a field) carries no toggle, so its state
	 * is left untouched. Focus returns to the clicked chip on close.
	 * @param {Event} event The chip click, carrying the detail origin / key / scope / field / rule in its
	 * dataset.
	 */
	async handleChipDetail(event)
	{
		const trigger = event.currentTarget;
		const dataset = trigger.dataset;
		const origin = dataset.detailOrigin;
		const key = dataset.detailKey || '';
		const ruleDeveloperName = dataset.rule;
		const scope = dataset.detailScope;
		const field = dataset.detailField || '';
		const catalogued = this.rulesByDeveloperName[ruleDeveloperName];
		// A rule the supersession verdict dropped from the catalogue can still back applied chips; its own
		// applied row is then the authoritative metadata source, so the popup never styles an active rule
		// inactive or degrades its label to the raw developer name.
		const appliedFallback = catalogued ? null : this.appliedRowFor(field, ruleDeveloperName);
		const rule = catalogued || {};
		const managed = origin !== ORIGIN_CONTEXT;
		const desired = managed ? this.desiredActive(origin, key) : true;
		const result = await MaskingRuleDetail.open({
			size: 'small',
			ruleLabel: rule.label || (appliedFallback && appliedFallback.ruleLabel) || ruleDeveloperName,
			ruleDeveloperName,
			ruleDescription: rule.description,
			ruleActive: catalogued ? rule.isActive === true : Boolean(appliedFallback && appliedFallback.ruleIsActive === true),
			applicableFieldTypes: rule.applicableFieldTypes || [],
			origin,
			scope,
			objectApiName: this.selectedObject,
			fieldApiName: field || this.representativeFieldFor(ruleDeveloperName),
			desired,
			supersededByLabel: rule.supersededByLabel || (appliedFallback && appliedFallback.supersededByLabel) || ''
		});
		// The header dismiss resolves undefined — treat it as "no change", but still return focus to the chip.
		if(result)
		{
			if(managed && result.wantActive !== desired)
			{
				this.toggleDesired(origin, key);
				this.persistDraft();
			}
			if(result.action === 'manageSetup')
			{
				this.navigateToManageSetup();
			}
		}
		this.restoreFocus(trigger);
	}

	/**
	 * @description The raw applied row backing a chip whose rule has left the catalogue (a fully
	 * superseded rule): the same field's applied target for the rule, else the object-wide target bound
	 * to it. The row carries the authoritative label, rule-active state, and supersession annotation the
	 * controller resolved for that exact binding — scoped to the chip's own context, never a global scan,
	 * so a same-named rule in another namespace is consulted no more than the pre-existing bare-name chip
	 * identity already does.
	 * @param {string} fieldApiName The chip's field api name, or blank for an object-wide chip.
	 * @param {string} ruleDeveloperName The rule developer name.
	 * @returns {?Object} The applied row, or undefined when the rule backs no binding here.
	 */
	appliedRowFor(fieldApiName, ruleDeveloperName)
	{
		const row = this.fieldRows.find((candidate) => candidate.apiName === fieldApiName);
		const fieldApplied = row ? row.appliedRules.find((applied) => applied.ruleDeveloperName === ruleDeveloperName) : null;
		return fieldApplied || this.objectWideRules.find((applied) => applied.ruleDeveloperName === ruleDeveloperName);
	}

	/**
	 * @description The field the rule-detail popup runs its sample-value test against for an object-wide
	 * chip (which has no field of its own): the first loaded field whose type the rule admits, else the
	 * first field, else blank — the preview then degrades to a failure note rather than throwing.
	 * @param {string} ruleDeveloperName The rule developer name.
	 * @returns {string}
	 */
	representativeFieldFor(ruleDeveloperName)
	{
		const match = this.fieldRows.find((row) => this.ruleAppliesToType(ruleDeveloperName, row.type));
		if(match)
		{
			return match.apiName;
		}
		return this.fieldRows.length > 0 ? this.fieldRows[0].apiName : '';
	}

	/**
	 * @description Opens Salesforce Setup's Custom Metadata home so an admin can deactivate a rule or open
	 * its target — the advisor never turns protection off for them. A fixed Setup route, navigated through
	 * the framework navigation capability rather than a raw link.
	 */
	navigateToManageSetup()
	{
		this.navigate({type: 'standard__webPage', attributes: {url: MANAGE_SETUP_PATH}});
	}

	/**
	 * @description Opens the Add-rule menu for the clicked field, listing the rules that fit its type and
	 * are not already present. Picking one ticks it as a field-level candidate; the Create-a-custom-rule
	 * footer navigates to Setup. Focus returns to the Add-rule button on close.
	 * @param {Event} event The Add-rule click, carrying the field api name in its dataset.
	 */
	async handleAddFieldRule(event)
	{
		const trigger = event.currentTarget;
		const apiName = trigger.dataset.apiName;
		const row = this.decoratedRows.find((candidate) => candidate.apiName === apiName);
		if(!row)
		{
			return;
		}
		const result = await MaskingAddRuleMenu.open({
			size: 'small', menuScope: 'field', objectApiName: this.selectedObject, fieldLabel: row.label, options: this.addRuleOptionsFor(row)
		});
		this.applyAddMenuResult(result, (developerName) => this.addFieldRule(apiName, developerName));
		this.restoreFocus(trigger);
	}

	/**
	 * @description Opens the Add-object-wide-rule menu, listing the rules not already applied object-wide.
	 * Picking one ticks it as an object-wide candidate; the Create-a-custom-rule footer navigates to Setup.
	 * Focus returns to the Add-object-wide-rule button on close.
	 * @param {Event} event The Add-object-wide-rule click.
	 */
	async handleAddObjectWideRule(event)
	{
		const trigger = event.currentTarget;
		const result = await MaskingAddRuleMenu.open({
			size: 'small', menuScope: 'object', objectApiName: this.selectedObject, options: this.addObjectWideOptions
		});
		this.applyAddMenuResult(result, (developerName) => this.addObjectWideRule(developerName));
		this.restoreFocus(trigger);
	}

	/**
	 * @description Applies an Add-rule menu result: a picked rule is added through the supplied adder; a
	 * create-rule action navigates to the New-Masking-Rule Setup page; a dismiss does nothing.
	 * @param {Object} result The menu resolution ({pickedRuleDeveloperName} or {action:'createRule'} or
	 * null).
	 * @param {Function} addRule The adder invoked with a picked rule developer name.
	 */
	applyAddMenuResult(result, addRule)
	{
		if(!result)
		{
			return;
		}
		if(result.action === 'createRule')
		{
			this.navigateToCreateRule();
			return;
		}
		if(result.pickedRuleDeveloperName)
		{
			addRule(result.pickedRuleDeveloperName);
		}
	}

	/**
	 * @description Adds a rule as a field-level candidate (idempotent), clearing any stale excluded flag so
	 * the new chip is ticked, and persists the draft.
	 * @param {string} apiName The field api name.
	 * @param {string} ruleDeveloperName The rule developer name to add.
	 */
	addFieldRule(apiName, ruleDeveloperName)
	{
		const existing = this.addedFieldRules[apiName] || [];
		if(existing.indexOf(ruleDeveloperName) > -1)
		{
			return;
		}
		this.addedFieldRules = {
			...this.addedFieldRules, [apiName]: [
				...existing,
				ruleDeveloperName
			]
		};
		this.clearExcluded(this.chipKey(SCOPE_FIELD, apiName, ruleDeveloperName));
		this.persistDraft();
	}

	/**
	 * @description Adds a rule as an object-wide candidate (idempotent), clearing any stale excluded flag,
	 * and persists.
	 * @param {string} ruleDeveloperName The rule developer name to add.
	 */
	addObjectWideRule(ruleDeveloperName)
	{
		if(this.addedObjectWideRules.indexOf(ruleDeveloperName) > -1)
		{
			return;
		}
		this.addedObjectWideRules = [
			...this.addedObjectWideRules,
			ruleDeveloperName
		];
		this.clearExcluded(this.chipKey(SCOPE_OBJECT, '', ruleDeveloperName));
		this.persistDraft();
	}

	/**
	 * @description Clears a chip key from the excluded map so a freshly added candidate seeds ticked even if
	 * the same key was excluded earlier in the session.
	 * @param {string} key The chip key.
	 */
	clearExcluded(key)
	{
		if(this.desiredExcluded[key])
		{
			const next = {...this.desiredExcluded};
			delete next[key];
			this.desiredExcluded = next;
		}
	}

	/**
	 * @description Navigates to the New-Masking-Rule Setup page resolved by the controller (never a
	 * hard-coded prefix); does nothing if the analysis carried no address.
	 */
	navigateToCreateRule()
	{
		if(this.newRuleSetupUrl)
		{
			this.navigate({type: 'standard__webPage', attributes: {url: this.newRuleSetupUrl}});
		}
	}

	/**
	 * @description The rules addable to a field: every catalogue rule whose type scope admits the field and
	 * that is not already running on it (applied, active object-wide on the type) or already a candidate.
	 * Each option carries its label, a short description, and a confirmatory applicable-types line; the menu
	 * already only lists type-matching rules, so a field option never warns.
	 * @param {Object} row The decorated field row.
	 * @returns {Array<Object>}
	 */
	addRuleOptionsFor(row)
	{
		const present = new Set([
			...(row.appliedRules || []).map((applied) => applied.ruleDeveloperName),
			...this.activeObjectWideRules.filter((rule) => this.ruleAppliesToType(rule.ruleDeveloperName, row.type)).map((rule) => rule.ruleDeveloperName),
			...this.fieldCandidatesFor(row).map((candidate) => candidate.developerName)
		]);
		return Object.values(this.rulesByDeveloperName)
		.filter((rule) => this.ruleAppliesToType(rule.developerName, row.type) && !present.has(rule.developerName))
		.map((rule) => this.toAddOption(rule, ''));
	}

	/**
	 * @description The no-match warning for an object-wide add option: set when a rule's applicable types
	 * match no field currently on the object. A rule with no applicable types runs on every text-shaped
	 * field, so it never warns; a typed rule warns only when the object carries none of its types today.
	 * @param {Object} rule The catalogue rule.
	 * @returns {string}
	 */
	objectWideWarningFor(rule)
	{
		// The catalogue always carries applicableFieldTypes (an empty list ⇒ applies to every text-shaped
		// field), the same assumption ruleAppliesToType makes — an empty list never warns.
		const ruleTypes = rule.applicableFieldTypes;
		if(ruleTypes.length === 0)
		{
			return '';
		}
		const fieldTypes = new Set(this.fieldRows.map((row) => row.type));
		const matchesAField = ruleTypes.some((type) => fieldTypes.has(type));
		return matchesAField ? '' : ADD_RULE_MENU_NO_FIELD_MATCH_WARNING;
	}

	/**
	 * @description Maps a catalogue rule to an Add-rule menu option: its label, a short subtitle (its
	 * description, else its mode), the friendly applicable-types line, any caller-supplied no-match
	 * warning, and the supersession annotation a named-as-replaced rule carries — so the menu steers
	 * the admin to the successor before they bind the older generation.
	 * @param {Object} rule The catalogue rule.
	 * @param {string} warning The no-match warning, or blank.
	 * @returns {Object}
	 */
	toAddOption(rule, warning)
	{
		return {
			value: rule.developerName,
			label: rule.label,
			subtitle: rule.description || rule.mode || '',
			appliesTo: ADD_RULE_MENU_APPLIES_TO.replace('{0}', friendlyFieldTypes(rule.applicableFieldTypes)),
			warning,
			superseded: rule.supersededByLabel || ''
		};
	}

	/**
	 * @description Walks every chip's desired state and emits the masking-configuration diff: a ticked
	 * candidate → create (new active field target), an unticked existing-active chip → disable (the target
	 * re-emitted with IsActive false), a ticked existing-inactive chip → re-enable. A dormant recommendation
	 * bound by a created target is collected into rulesToActivate so the bundle activates exactly the rules
	 * it binds.
	 * @returns {{targets: Array<Object>, rulesToActivate: Array<string>}}
	 */
	computeExportDiff()
	{
		const targets = [];
		const activate = new Set();
		this.decoratedRows.forEach((row) =>
		{
			(row.appliedRules || []).forEach((applied) =>
			{
				const key = this.chipKey(SCOPE_FIELD, row.apiName, applied.ruleDeveloperName);
				if(applied.isActive)
				{
					if(!this.desiredActive(ORIGIN_ACTIVE, key))
					{
						targets.push(this.taggedTarget(this.existingTargetDecision(applied, row.apiName, false), VERB_DISABLE, row.label));
					}
				}
				else if(this.desiredActive(ORIGIN_INACTIVE, key))
				{
					targets.push(this.taggedTarget(this.existingTargetDecision(applied, row.apiName, true), VERB_REENABLE, row.label));
				}
			});
			this.fieldCandidatesFor(row).forEach((candidate) =>
			{
				const key = this.chipKey(SCOPE_FIELD, row.apiName, candidate.developerName);
				if(this.desiredActive(ORIGIN_CANDIDATE, key))
				{
					targets.push(this.taggedTarget({
						developerName: this.targetDeveloperNameFor(row.apiName, candidate.developerName),
						label: candidate.label,
						ruleDeveloperName: candidate.developerName,
						sObjectType: this.selectedObject,
						field: row.apiName,
						callerClass: '',
						isActive: true
					}, VERB_ADD, row.label));
					// A dormant bound rule must be activated by the bundle, or its new target masks nothing.
					if(candidate.isActive === false)
					{
						activate.add(candidate.developerName);
					}
				}
			});
		});
		this.objectWideBannerChips.forEach((chip) =>
		{
			if(chip.origin === ORIGIN_ACTIVE && !this.desiredActive(ORIGIN_ACTIVE, chip.key))
			{
				targets.push(this.taggedTarget(this.existingObjectWideDecision(chip, false), VERB_DISABLE, ''));
			}
			else if(chip.origin === ORIGIN_INACTIVE && this.desiredActive(ORIGIN_INACTIVE, chip.key))
			{
				targets.push(this.taggedTarget(this.existingObjectWideDecision(chip, true), VERB_REENABLE, ''));
			}
			else if(chip.origin === ORIGIN_CANDIDATE && this.desiredActive(ORIGIN_CANDIDATE, chip.key))
			{
				// A ticked object-wide candidate becomes a new active object-wide target (blank field).
				targets.push(this.taggedTarget({
					developerName: this.targetDeveloperNameFor('', chip.ruleDeveloperName),
					label: chip.ruleLabel,
					ruleDeveloperName: chip.ruleDeveloperName,
					sObjectType: this.selectedObject,
					field: '',
					callerClass: '',
					isActive: true
				}, VERB_ADD, ''));
				// A dormant bound rule must be activated by the bundle, or its new target masks nothing.
				const rule = this.rulesByDeveloperName[chip.ruleDeveloperName];
				if(rule && rule.isActive === false)
				{
					activate.add(chip.ruleDeveloperName);
				}
			}
		});
		return {targets, rulesToActivate: [...activate]};
	}

	/**
	 * @description A disable / re-enable decision for an existing field target: its own developer name,
	 * rule, caller class, and field are preserved verbatim; only IsActive flips.
	 * @param {Object} applied The existing applied target.
	 * @param {string} fieldApiName The field api name.
	 * @param {boolean} isActive The flipped active state.
	 * @returns {Object}
	 */
	existingTargetDecision(applied, fieldApiName, isActive)
	{
		return {
			developerName: applied.targetDeveloperName,
			label: applied.ruleLabel,
			ruleDeveloperName: applied.ruleDeveloperName,
			sObjectType: this.selectedObject,
			field: fieldApiName,
			callerClass: applied.callerClass || '',
			isActive
		};
	}

	/**
	 * @description A disable / re-enable decision for an existing object-wide target (blank field).
	 * @param {Object} chip The existing object-wide chip.
	 * @param {boolean} isActive The flipped active state.
	 * @returns {Object}
	 */
	existingObjectWideDecision(chip, isActive)
	{
		return {
			developerName: chip.targetDeveloperName,
			label: chip.ruleLabel,
			ruleDeveloperName: chip.ruleDeveloperName,
			sObjectType: this.selectedObject,
			field: '',
			callerClass: chip.callerClass || '',
			isActive
		};
	}

	/**
	 * @description Tags a bare target decision with the display-only verb (add / disable / re-enable) and
	 * the field's friendly label, so the export modal can group and render the row without re-deriving which
	 * half of the diff produced it. The tags never cross the @AuraEnabled boundary — toTargetDecision strips
	 * them.
	 * @param {Object} decision The bare target decision.
	 * @param {string} verb The diff verb (add / disable / re-enable).
	 * @param {string} fieldLabel The field's friendly label (blank for object-wide).
	 * @returns {Object}
	 */
	taggedTarget(decision, verb, fieldLabel)
	{
		return {...decision, verb, fieldLabel};
	}

	/**
	 * @description Projects a tagged diff target back to the bare DTO_TargetDecision the controller
	 * deserializes, dropping the display-only verb / fieldLabel tags so they never reach Apex.
	 * @param {Object} target The tagged diff target.
	 * @returns {Object}
	 */
	toTargetDecision(target)
	{
		return {
			developerName: target.developerName,
			label: target.label,
			ruleDeveloperName: target.ruleDeveloperName,
			sObjectType: target.sObjectType,
			field: target.field,
			callerClass: target.callerClass,
			isActive: target.isActive
		};
	}

	/**
	 * @description Buckets the tagged diff targets into the modal's three package-contents groups. Each
	 * display row carries only what the modal renders: scope (field vs object-wide, derived from the blank
	 * field segment), the field's friendly label, and the rule label.
	 * @param {Array<Object>} targets The tagged diff targets.
	 * @returns {{addRows: Array<Object>, disableRows: Array<Object>, reEnableRows: Array<Object>}}
	 */
	toExportDiffGroups(targets)
	{
		const groups = {addRows: [], disableRows: [], reEnableRows: []};
		targets.forEach((target) =>
		{
			const row = {scope: target.field ? SCOPE_FIELD : SCOPE_OBJECT, fieldLabel: target.fieldLabel || '', ruleLabel: target.label};
			if(target.verb === VERB_DISABLE)
			{
				groups.disableRows.push(row);
			}
			else if(target.verb === VERB_REENABLE)
			{
				groups.reEnableRows.push(row);
			}
			else
			{
				groups.addRows.push(row);
			}
		});
		return groups;
	}

	/**
	 * @description Builds the deployment-neutral masking-configuration package from the export diff and
	 * hands it — together with the diff grouped Add / Disable / Re-enable for the package-contents list — to
	 * the platform-chrome export dialog. A single computeExportDiff walk feeds both the controller request
	 * (bare decisions) and the modal groups (display rows). A diff with no changes does nothing (the button
	 * is disabled). A failed generation surfaces its own framework toast and returns nothing, so the dialog
	 * never opens on a missing bundle. The session draft is left intact deliberately (only the explicit
	 * Clear draft action purges it), preserving the export → inspect → fix → re-export loop.
	 * @param {Event} event The Export-button click.
	 */
	async handleExport(event)
	{
		const trigger = event.currentTarget;
		// The Export button is disabled while the diff is empty, so the diff always carries at least one target.
		const diff = this.computeExportDiff();
		const request = {targets: diff.targets.map((target) => this.toTargetDecision(target)), rulesToActivate: diff.rulesToActivate};
		const bundle = await this.callControllerMethod(generateConfiguration, {requestJson: JSON.stringify(request)});
		if(!bundle)
		{
			return;
		}
		const groups = this.toExportDiffGroups(diff.targets);
		const result = await MaskingExportModal.open({
			size: 'medium',
			objectApiName: this.selectedObject,
			fileName: EXPORT_FILE_NAME,
			addRows: groups.addRows,
			disableRows: groups.disableRows,
			reEnableRows: groups.reEnableRows
		});
		// Download closes with {action:'download'}; Cancel (null) and the header dismiss (undefined) are both
		// "do not download". The dialog never performs the download itself — the caller owns it.
		if(result?.action === 'download')
		{
			this.downloadBundle(bundle);
		}
		this.restoreFocus(trigger);
	}

	/**
	 * @description Decodes the bundle's base64 zip into a Blob and triggers a one-click browser download of
	 * the single deployable archive. The anchor is transient — created, clicked, and discarded — so it never
	 * enters the document or the accessibility tree.
	 * @param {Object} bundle The generated bundle ({zipBase64}).
	 */
	downloadBundle(bundle)
	{
		const bytes = Uint8Array.from(atob(bundle.zipBase64), (character) => character.charCodeAt(0));
		const objectUrl = window.URL.createObjectURL(new Blob([bytes], {type: 'application/zip'}));
		const anchor = document.createElement('a');
		anchor.href = objectUrl;
		anchor.download = EXPORT_FILE_NAME;
		anchor.click();
		// The anchor-download read is synchronous, so the object URL can be freed immediately rather than
		// leaking for the page's lifetime.
		window.URL.revokeObjectURL(objectUrl);
	}

	/**
	 * @description The CustomMetadata developer name for a created field target: Mask_<object>_<field>_<rule>,
	 * each part reduced to the identifier grammar, capped at the 40-character limit. Short names pass through
	 * verbatim; an over-long name is truncated and gets a short hash suffix keyed on the field+rule pair so
	 * two long fields (or two rules on one field) sharing a prefix never collide onto one name (which would
	 * silently drop a target from the bundle). The result always starts with a letter, carries only single
	 * underscores, and never ends in one.
	 * @param {string} fieldApiName The field api name (blank for an object-wide target).
	 * @param {string} ruleDeveloperName The rule developer name.
	 * @returns {string}
	 */
	targetDeveloperNameFor(fieldApiName, ruleDeveloperName)
	{
		// A blank field (an object-wide target) drops the field segment so the name carries no doubled
		// underscore (Mask_<object>_<rule>); a field target keeps all three (Mask_<object>_<field>_<rule>).
		const segments = [this.toIdentifierPart(this.selectedObject)];
		const fieldSegment = this.toIdentifierPart(fieldApiName);
		if(fieldSegment)
		{
			segments.push(fieldSegment);
		}
		segments.push(this.toIdentifierPart(ruleDeveloperName));
		const composite = TARGET_DEVELOPER_NAME_PREFIX + segments.join('_');
		if(composite.length <= MAX_DEVELOPER_NAME_LENGTH)
		{
			return composite;
		}
		const suffix = '_' + this.shortHash(fieldApiName + '|' + ruleDeveloperName);
		return composite.substring(0, MAX_DEVELOPER_NAME_LENGTH - suffix.length).replace(/_+$/, '') + suffix;
	}

	/**
	 * @description A short, stable, non-negative base36 hash of a string, used only to disambiguate
	 * truncated developer names. Modular arithmetic keeps it positive and within the safe-integer range
	 * without bitwise ops.
	 * @param {string} value The string to hash.
	 * @returns {string}
	 */
	shortHash(value)
	{
		let hash = 0;
		for(let index = 0; index < value.length; index += 1)
		{
			hash = (hash * 31 + value.charCodeAt(index)) % 2147483647;
		}
		return hash.toString(36).slice(0, DEVELOPER_NAME_HASH_LENGTH);
	}

	/**
	 * @description Reduces an object, field, or rule api name to a CustomMetadata identifier fragment: drops
	 * the trailing custom suffix (__c and friends), maps every other non-alphanumeric run to a single
	 * underscore, and trims edge underscores so the assembled name carries no doubled or leading/trailing
	 * ones.
	 * @param {string} apiName The api name to reduce.
	 * @returns {string}
	 */
	toIdentifierPart(apiName)
	{
		return apiName
		.replace(/__[a-z]+$/i, '')
		.replace(/[^A-Za-z0-9]+/g, '_')
		.replace(/^_+|_+$/g, '');
	}

	/**
	 * @description Opens the Review dialog for the row whose badge was clicked, seeded with the row's
	 * current (effective) classification, signal band, type, and reason, and applies the chosen level on
	 * Apply. Focus returns to the clicked badge on close (when the row has not re-sectioned away under it).
	 * @param {Event} event The badge click, carrying the field api name in its dataset.
	 */
	async handleReview(event)
	{
		const trigger = event.currentTarget;
		const apiName = trigger.dataset.apiName;
		const row = this.decoratedRows.find((candidate) => candidate.apiName === apiName);
		if(!row)
		{
			return;
		}
		const result = await MaskingReviewDialog.open({
			size: 'small',
			fieldLabel: row.label,
			fieldApiName: row.apiName,
			objectApiName: this.selectedObject,
			sensitivityLevel: row.sensitivityLevel,
			matchStrength: row.matchStrength,
			fieldType: row.type,
			reason: row.dialogReason
		});
		// Cancel resolves null and the header dismiss resolves undefined — both are "no change".
		if(result)
		{
			this.applyOverride(row, result.level);
		}
		this.restoreFocus(trigger);
	}

	/**
	 * @description Records a reclassify override for a field and re-sections it in place. A downgrade to Not
	 * Sensitive moves the field to Other and unticks its candidate chips (so a not-sensitive field is never
	 * newly masked); a promote moves it to Ready (when it has a recommendation candidate) or Needs review,
	 * and re-ticks any candidate the admin had excluded. The field's candidate chips' prior excluded state
	 * is captured on the first override so a revert can restore it exactly.
	 * @param {Object} row The decorated field row.
	 * @param {string} level The chosen sensitivity level.
	 */
	applyOverride(row, level)
	{
		const candidateKeys = this.fieldCandidatesFor(row).map((candidate) => this.chipKey(SCOPE_FIELD, row.apiName, candidate.developerName));
		// Capture the prior excluded state only on the FIRST override of a field, so re-applying a
		// reclassification never overwrites the state a revert must restore.
		if(!this.overrideByApiName[row.apiName])
		{
			const before = {};
			candidateKeys.forEach((key) =>
			{
				before[key] = Boolean(this.desiredExcluded[key]);
			});
			this.selectionBeforeOverride = {...this.selectionBeforeOverride, [row.apiName]: before};
		}
		const downgrade = level === LEVEL_NOT_SENSITIVE;
		const source = downgrade ? OVERRIDE_DOWNGRADED : OVERRIDE_PROMOTED;
		this.overrideByApiName = {...this.overrideByApiName, [row.apiName]: {level, source}};
		const nextExcluded = {...this.desiredExcluded};
		candidateKeys.forEach((key) =>
		{
			// A downgrade excludes the field's candidates from the package; a promote includes them.
			if(downgrade)
			{
				nextExcluded[key] = true;
			}
			else
			{
				delete nextExcluded[key];
			}
		});
		this.desiredExcluded = nextExcluded;
		this.showSuccessToast(this.reclassifyToastFor(row, downgrade));
		this.persistDraft();
	}

	/**
	 * @description The success toast for a reclassification: a downgrade reads "marked not sensitive", a
	 * promote that lands the field in Ready reads "added to the package", and a promote with no
	 * recommendation reads "flagged for review".
	 * @param {Object} row The decorated field row.
	 * @param {boolean} downgrade Whether the reclassification was a downgrade.
	 * @returns {string}
	 */
	reclassifyToastFor(row, downgrade)
	{
		if(downgrade)
		{
			return RECLASSIFY_TOAST_OTHER.replace('{0}', row.label);
		}
		if(row.recommendedRuleDeveloperName)
		{
			return RECLASSIFY_TOAST_READY.replace('{0}', row.label);
		}
		return RECLASSIFY_TOAST_REVIEW.replace('{0}', row.label);
	}

	/**
	 * @description Reverts an in-place reclassification: drops the override (restoring the field to its
	 * original section) and restores its candidate chips' prior excluded state.
	 * @param {Event} event The Revert click, carrying the field api name + label in its dataset.
	 */
	handleRevert(event)
	{
		const apiName = event.currentTarget.dataset.apiName;
		// A field always has a captured pre-state once it carries an override (applyOverride / restoreDraft set
		// both together), and the Revert affordance only renders for an overridden field.
		const before = this.selectionBeforeOverride[apiName];
		const nextOverride = {...this.overrideByApiName};
		delete nextOverride[apiName];
		this.overrideByApiName = nextOverride;
		const nextBefore = {...this.selectionBeforeOverride};
		delete nextBefore[apiName];
		this.selectionBeforeOverride = nextBefore;
		const nextExcluded = {...this.desiredExcluded};
		Object.keys(before).forEach((key) =>
		{
			if(before[key])
			{
				nextExcluded[key] = true;
			}
			else
			{
				delete nextExcluded[key];
			}
		});
		this.desiredExcluded = nextExcluded;
		this.showSuccessToast(RECLASSIFY_TOAST_REVERTED.replace('{0}', event.currentTarget.dataset.label));
		this.persistDraft();
	}

	/**
	 * @description Persists the reclassify overrides + the three desired-state maps + admin-added candidates
	 * (delta-only — never the field DTOs) to this object's sessionStorage key. A write failure (quota,
	 * private mode, blocked storage) falls back to in-memory state and surfaces a one-time non-blocking
	 * warning so the admin knows a reload will lose the work, rather than silently configuring chips that
	 * vanish.
	 */
	persistDraft()
	{
		const draft = {
			version: DRAFT_VERSION,
			overrides: this.overrideByApiName,
			selectionBefore: this.selectionBeforeOverride,
			disabled: this.desiredDisabled,
			enabled: this.desiredEnabled,
			excluded: this.desiredExcluded,
			addedFieldRules: this.addedFieldRules,
			addedObjectWideRules: this.addedObjectWideRules
		};
		try
		{
			window.sessionStorage.setItem(this.draftKey, JSON.stringify(draft));
		}
		catch
		{
			if(!this.draftSaveWarned)
			{
				this.showWarningToast(DRAFT_SAVE_FAILED_WARNING);
				this.draftSaveWarned = true;
			}
		}
	}

	/**
	 * @description Restores a saved draft for the loaded object: overrides are re-applied (only for fields
	 * still present), each present field's prior excluded state is restored verbatim (so a post-reload
	 * revert is faithful), and the three desired-state maps + added candidates are restored. A read/parse
	 * failure, or a draft written by an incompatible version, degrades silently to the seeded (all-default)
	 * state.
	 */
	restoreDraft()
	{
		try
		{
			const raw = window.sessionStorage.getItem(this.draftKey);
			if(!raw)
			{
				return;
			}
			const draft = JSON.parse(raw);
			if(draft.version !== DRAFT_VERSION)
			{
				return;
			}
			const knownApiNames = new Set(this.fieldRows.map((row) => row.apiName));
			const nextOverride = {};
			const nextBefore = {};
			Object.keys(draft.overrides).forEach((apiName) =>
			{
				// A stale draft can name a field this org no longer has — skip it rather than crash on a
				// missing describe row.
				if(!knownApiNames.has(apiName))
				{
					return;
				}
				const stored = draft.overrides[apiName];
				nextOverride[apiName] = {level: stored.level, source: stored.source};
				nextBefore[apiName] = draft.selectionBefore[apiName] || {};
			});
			this.overrideByApiName = nextOverride;
			this.selectionBeforeOverride = nextBefore;
			this.desiredDisabled = draft.disabled || {};
			this.desiredEnabled = draft.enabled || {};
			this.desiredExcluded = draft.excluded || {};
			// Restore admin-added candidates, dropping any naming a field this org no longer has.
			const restoredAddedFieldRules = {};
			Object.keys(draft.addedFieldRules || {}).forEach((apiName) =>
			{
				if(knownApiNames.has(apiName))
				{
					restoredAddedFieldRules[apiName] = draft.addedFieldRules[apiName];
				}
			});
			this.addedFieldRules = restoredAddedFieldRules;
			this.addedObjectWideRules = draft.addedObjectWideRules || [];
		}
		catch
		{
			// A missing/blocked store, malformed JSON, or a draft shape this version can't read: degrade to seed.
		}
	}

	/**
	 * @description Discards the saved draft: drops every reclassification + desired-state toggle, restoring
	 * the seeded recommendations, and removes the stored key. The key is removed deliberately here — it is
	 * never wiped on export, so the export → inspect → fix loop keeps the admin's work until they choose to
	 * clear it.
	 */
	handleClearDraft()
	{
		this.overrideByApiName = {};
		this.selectionBeforeOverride = {};
		this.desiredDisabled = {};
		this.desiredEnabled = {};
		this.desiredExcluded = {};
		this.addedFieldRules = {};
		this.addedObjectWideRules = [];
		try
		{
			window.sessionStorage.removeItem(this.draftKey);
		}
		catch
		{
			// A blocked store has nothing to remove; the in-memory reset above already cleared the draft.
		}
		this.showSuccessToast(DRAFT_CLEARED_TOAST);
	}

	/**
	 * @description Decorates a raw field DTO for render: its heuristic tier label, effective (override-aware)
	 * sensitivity, signal bars, masking chips (object-wide context + field-level), resolved section, reason
	 * line, and low-confidence tagging. An override forces the field's classification: a downgrade
	 * re-sections to Other, a promote to Ready (when it has a recommendation) else Needs review. A
	 * low-confidence heuristic match falls to Other tagged in place of the generic reason line.
	 * @param {Object} row The raw field DTO.
	 * @returns {Object}
	 */
	decorateRow(row)
	{
		const heuristicTierLabel = this.heuristicTierLabelFor(row.heuristicConfidence);
		const override = this.overrideByApiName[row.apiName] || null;
		// An override forces the field's classification: a downgrade re-sections to Other, a promote to
		// Ready (when it has a recommendation) else Needs review.
		const effectiveSensitivityLevel = override ? override.level : row.sensitivityLevel;
		const hasRecommendation = Boolean(row.recommendedRuleDeveloperName);
		const signalBandRank = SIGNAL_BAND_RANK[row.matchStrength];
		// A low-confidence heuristic match (a single weak signal) no longer flags a field into Needs review —
		// it falls to All other fields, where it is tagged and floated to the top. A natively classified field,
		// or a HIGH/MEDIUM heuristic tier, still flags.
		const lowConfidence = row.heuristicConfidence === HEURISTIC_LOW;
		const isFlagged = row.isClassified === true || (Boolean(heuristicTierLabel) && !lowConfidence);
		const section = this.sectionFor(override, hasRecommendation, isFlagged);
		// A low-confidence match that lands in Other carries the low-confidence tag in place of the generic
		// reason line, so the field reads as a weak positive signal rather than "no signal at all".
		const isLowConfidenceMatch = lowConfidence && section === SECTION_OTHER;
		const otherReason = isLowConfidenceMatch ? OTHER_LOW_CONFIDENCE_TAG : (row.likelyMiss ? OTHER_REASON_TYPE_SUGGESTS : OTHER_REASON_NO_SIGNAL);
		const objectWideContextChips = this.objectWideContextChipsFor(row);
		const fieldChips = this.fieldChipsFor(row);
		return {
			...row,
			heuristicTierLabel,
			sensitivityLevel: effectiveSensitivityLevel,
			sensitivityBadgeLabel: SENSITIVITY_BADGE_LABELS[effectiveSensitivityLevel],
			signalBandLabel: SIGNAL_BAND_LABELS[row.matchStrength],
			signalBars: SIGNAL_BAR_INDEXES.map((index) => ({key: index, lit: index < signalBandRank})),
			reviewBadgeAssistiveText: REVIEW_BADGE_ASSISTIVE.replace('{0}', row.label),
			revertAriaLabel: REVERT_OVERRIDE_ARIA.replace('{0}', row.label),
			hasRecommendation,
			section,
			markerLabel: this.markerLabelFor(override),
			objectWideContextChips,
			hasObjectWideContextChips: objectWideContextChips.length > 0,
			fieldChips,
			otherReason,
			isLowConfidenceMatch,
			showReason: (section === SECTION_REVIEW || section === SECTION_OTHER) && !isLowConfidenceMatch,
			reasonText: section === SECTION_REVIEW ? SECTION_REVIEW_NO_RULE_NOTE.replace('{0}', row.apiName) : otherReason,
			dialogReason: this.dialogReasonFor(section, row, otherReason)
		};
	}

	/**
	 * @description A row with a recommended rule is Ready; a flagged row with no rule needs review;
	 * everything else is Other. An override re-sections the field regardless of its original signals: a
	 * downgrade sends it to Other, a promote to Ready when it has a recommendation, else to Needs review.
	 * @param {Object} override The field's reclassify override, or null.
	 * @param {boolean} hasRecommendation Whether the field has a recommended rule.
	 * @param {boolean} isFlagged Whether the field is flagged sensitive.
	 * @returns {string}
	 */
	sectionFor(override, hasRecommendation, isFlagged)
	{
		if(override)
		{
			if(override.source === OVERRIDE_DOWNGRADED)
			{
				return SECTION_OTHER;
			}
			return hasRecommendation ? SECTION_READY : SECTION_REVIEW;
		}
		if(hasRecommendation)
		{
			return SECTION_READY;
		}
		return isFlagged ? SECTION_REVIEW : SECTION_OTHER;
	}

	/**
	 * @description The in-place marker a reclassified field carries: a promote reads "added manually", a
	 * downgrade reads "marked not sensitive", and a field with no override carries none.
	 * @param {Object} override The field's reclassify override, or null.
	 * @returns {string}
	 */
	markerLabelFor(override)
	{
		if(!override)
		{
			return null;
		}
		return override.source === OVERRIDE_PROMOTED ? MARKER_ADDED_MANUALLY : MARKER_MARKED_NOT_SENSITIVE;
	}

	/**
	 * @description The reason text the Review dialog shows in its optional "why" row: the no-rule note for a
	 * Needs-review row, the type-derived reason for an Other row, and nothing for a Ready row.
	 * @param {string} section The row's resolved section.
	 * @param {Object} row The raw field DTO.
	 * @param {string} otherReason The Other-section reason line.
	 * @returns {string}
	 */
	dialogReasonFor(section, row, otherReason)
	{
		if(section === SECTION_REVIEW)
		{
			return SECTION_REVIEW_NO_RULE_NOTE.replace('{0}', row.apiName);
		}
		if(section === SECTION_OTHER)
		{
			return otherReason;
		}
		return '';
	}

	/**
	 * @description The read-only object-wide context chips shown on a field's Object-wide line: the active
	 * object-wide rules whose applicable field types include this field's type (an empty type list ⇒ applies
	 * to all the text-shaped fields the advisor lists). They surface "this field already inherits these" —
	 * the tickable object-wide chips live in the banner, not per-field.
	 * @param {Object} row The raw field DTO.
	 * @returns {Array<Object>}
	 */
	objectWideContextChipsFor(row)
	{
		return this.activeObjectWideRules
		.filter((rule) => this.ruleAppliesToType(rule.ruleDeveloperName, row.type))
		.map((rule) => ({
			key: row.apiName + '|ow|' + rule.ruleDeveloperName,
			ruleDeveloperName: rule.ruleDeveloperName,
			ruleLabel: rule.ruleLabel,
			origin: ORIGIN_CONTEXT,
			scope: SCOPE_OBJECT,
			field: row.apiName,
			ctx: rule.ruleDeveloperName,
			supersededByLabel: rule.supersededByLabel || ''
		}));
	}

	/**
	 * @description The tickable field-level chips: this field's applied targets (active 📍 / inactive ⚠)
	 * followed by its candidates (recommendation + admin-added) as candidate chips, each carrying its
	 * desired state and change-flag hint.
	 * @param {Object} row The raw field DTO.
	 * @returns {Array<Object>}
	 */
	fieldChipsFor(row)
	{
		const chips = (row.appliedRules || []).map((applied) =>
		{
			const origin = applied.isActive ? ORIGIN_ACTIVE : ORIGIN_INACTIVE;
			const key = this.chipKey(SCOPE_FIELD, row.apiName, applied.ruleDeveloperName);
			const desired = this.desiredActive(origin, key);
			return {
				key,
				ruleDeveloperName: applied.ruleDeveloperName,
				ruleLabel: applied.ruleLabel,
				origin,
				scope: SCOPE_FIELD,
				field: row.apiName,
				desired,
				glyph: origin === ORIGIN_INACTIVE ? '⚠' : '📍',
				flag: this.changeFlag(origin, desired),
				ariaLabel: this.chipAria(applied.ruleLabel, origin),
				supersededByLabel: applied.supersededByLabel || ''
			};
		});
		this.fieldCandidatesFor(row).forEach((candidate) =>
		{
			const key = this.chipKey(SCOPE_FIELD, row.apiName, candidate.developerName);
			const desired = this.desiredActive(ORIGIN_CANDIDATE, key);
			chips.push({
				key,
				ruleDeveloperName: candidate.developerName,
				ruleLabel: candidate.label,
				origin: ORIGIN_CANDIDATE,
				scope: SCOPE_FIELD,
				field: row.apiName,
				desired,
				glyph: '📍',
				flag: this.changeFlag(ORIGIN_CANDIDATE, desired),
				ariaLabel: this.chipAria(candidate.label, ORIGIN_CANDIDATE),
				supersededByLabel: (this.rulesByDeveloperName[candidate.developerName] || {}).supersededByLabel || ''
			});
		});
		return chips;
	}

	/**
	 * @description The field's candidate rules ({developerName, label, isActive}): every concept-matched
	 * recommended rule (a phone field offers both the US and the international phone rule) plus any rules the
	 * admin added via the Add-rule menu, each surfaced only when that rule is not already running on the
	 * field — neither an existing field target (active or inactive) nor an active object-wide rule that
	 * applies to the field's type. This is the reconciliation that stops the advisor offering masking that
	 * already runs. Each recommendation carries its own label and dormancy; an added rule resolves them from
	 * the rule catalogue.
	 * @param {Object} row The raw field DTO.
	 * @returns {Array<Object>}
	 */
	fieldCandidatesFor(row)
	{
		const appliedDeveloperNames = new Set((row.appliedRules || []).map((applied) => applied.ruleDeveloperName));
		const objectWideDeveloperNames = new Set(this.activeObjectWideRules
		.filter((rule) => this.ruleAppliesToType(rule.ruleDeveloperName, row.type))
		.map((rule) => rule.ruleDeveloperName));
		const candidates = [];
		// Each concept-matched recommendation pre-ticks as its own candidate, except one already running on the
		// field (an existing target or an active object-wide rule of the field's type). The controller always
		// emits recommendedRules (a possibly-empty array of distinct rules), so no guard or de-dup is needed
		// before the admin-added rules below.
		row.recommendedRules.forEach((recommendation) =>
		{
			if(!appliedDeveloperNames.has(recommendation.developerName) && !objectWideDeveloperNames.has(recommendation.developerName))
			{
				candidates.push({developerName: recommendation.developerName, label: recommendation.label, isActive: recommendation.isActive});
			}
		});
		(this.addedFieldRules[row.apiName] || []).forEach((developerName) =>
		{
			// Skip a rule already running on the field, the recommendation already listed, or a duplicate add.
			if(appliedDeveloperNames.has(developerName) || objectWideDeveloperNames.has(developerName) || candidates.some((candidate) => candidate.developerName === developerName))
			{
				return;
			}
			const rule = this.rulesByDeveloperName[developerName];
			if(rule)
			{
				candidates.push({developerName: rule.developerName, label: rule.label, isActive: rule.isActive});
			}
		});
		return candidates;
	}

	/**
	 * @description Whether a rule applies to a field type: its applicable field types include the type, or
	 * the rule lists no applicable types (⇒ applies to every text-shaped field the advisor surfaces).
	 * @param {string} ruleDeveloperName The rule developer name.
	 * @param {string} fieldType The field type literal.
	 * @returns {boolean}
	 */
	ruleAppliesToType(ruleDeveloperName, fieldType)
	{
		const rule = this.rulesByDeveloperName[ruleDeveloperName];
		if(!rule)
		{
			return false;
		}
		// The catalogue always carries applicableFieldTypes (an empty list ⇒ applies to every text-shaped field).
		const types = rule.applicableFieldTypes;
		return types.length === 0 || types.indexOf(fieldType) > -1;
	}

	/**
	 * @description Indexes the analysis rule catalogue by developer name so each row resolves its chip
	 * labels, categories, applicable field types, and dormancy with a map lookup rather than a scan.
	 * @param {Array<Object>} rules The analysis rule catalogue.
	 * @returns {Object<string, Object>}
	 */
	indexRulesByDeveloperName(rules)
	{
		const byDeveloperName = {};
		(rules || []).forEach((rule) =>
		{
			byDeveloperName[rule.developerName] = rule;
		});
		return byDeveloperName;
	}

	/**
	 * @description Maps a heuristic-confidence literal to its display tier label (High / Medium / Low), or
	 * null when there is no heuristic signal.
	 * @param {string} value The heuristic-confidence literal.
	 * @returns {string}
	 */
	heuristicTierLabelFor(value)
	{
		if(value === HEURISTIC_HIGH)
		{
			return HEURISTIC_TIER_HIGH;
		}
		if(value === HEURISTIC_MEDIUM)
		{
			return HEURISTIC_TIER_MEDIUM;
		}
		if(value === HEURISTIC_LOW)
		{
			return HEURISTIC_TIER_LOW;
		}
		return null;
	}
}