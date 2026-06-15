// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The regulated-field inventory export dialog for the Data Masking Advisor, built on
 * lightning/modal (LightningModal) so the chrome and the WCAG focus-trap come from the platform. The
 * administrator picks a scope — their own custom objects, the objects that already have masking, or every
 * object — and a format (CSV or JSON), and the dialog builds a spreadsheet-ready census of every field that
 * holds (or likely holds) regulated data: what it is, how it is classified, whether masking covers it today,
 * and where history tracking is worth turning on.
 *
 * The dialog owns the whole export because a LightningModal cannot raise events back to its opener mid-life
 * (it communicates only through close(result)) — so to preview a scope and re-preview when the scope changes
 * it must do the work itself. It fetches the chosen scope's inventory one object per call through a bounded
 * concurrency pool (getRegulatedFieldInventory), keeping each describe within a single transaction's limits
 * the way the on-demand coverage scan does, caches the result per scope so switching back never re-fetches,
 * shows a live preview of the first rows plus the true row count, and assembles + downloads the file
 * client-side. The "All objects" scope is gated behind a confirm step because it can mean hundreds of
 * per-object calls. Previewing changes nothing in the org.
 *
 * @author Jason van Beukering
 * @date June 2026
 */
import {api} from 'lwc';
import LightningModal from 'lightning/modal';
import {friendlyFieldType} from 'c/maskingFieldTypeLabels';
import getRegulatedFieldInventory from '@salesforce/apex/CTRL_MaskingAdvisor.getRegulatedFieldInventory';
import FORMAT_NOTE from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FormatNote';
import MASKED_SCOPE_NOTE from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_MaskedScopeNote';
import SENSITIVE_ONLY from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_SensitiveOnly';
import FILTERED_EMPTY_STATE from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FilteredEmptyState';
import TITLE from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Title';
import INTRO from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Intro';
import SCOPE_HEADING from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ScopeHeading';
import SCOPE_CUSTOM from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Scope_Custom';
import SCOPE_MASKED from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Scope_Masked';
import SCOPE_ALL from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Scope_All';
import OBJECT_COUNT_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ObjectCount_Singular';
import OBJECT_COUNT_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ObjectCount_Plural';
import FORMAT_HEADING from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FormatHeading';
import FORMAT_CSV_LABEL from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Format_Csv';
import FORMAT_JSON_LABEL from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Format_Json';
import COLUMNS_HEADING_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ColumnsHeading_Singular';
import COLUMNS_HEADING_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_ColumnsHeading_Plural';
import MORE_ROWS_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_MoreRows_Singular';
import MORE_ROWS_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_MoreRows_Plural';
import COLUMN_OBJECT from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_Object';
import COLUMN_FIELD from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_Field';
import COLUMN_FIELD_TYPE from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_FieldType';
import COLUMN_LONG_TEXT_AREA from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_LongTextArea';
import COLUMN_SECURITY_CLASSIFICATION from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_SecurityClassification';
import COLUMN_COMPLIANCE_GROUP from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_ComplianceGroup';
import COLUMN_SENSITIVITY from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_Sensitivity';
import COLUMN_RECOMMENDED_RULE from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_RecommendedRule';
import COLUMN_MASKED_TODAY from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_MaskedToday';
import COLUMN_HISTORY from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Column_HistoryTrackingRecommended';
import CELL_YES from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Cell_Yes';
import CELL_NO from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Cell_No';
import CELL_EMPTY from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Cell_Empty';
import BUILDING_PROGRESS from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Building_Progress';
import CONFIRM_BODY from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_AllScope_ConfirmBody';
import CONFIRM_BUTTON from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_AllScope_ConfirmButton';
import EMPTY_STATE from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_EmptyState';
import PARTIAL_FAILURE_SINGULAR from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_PartialFailure_Singular';
import PARTIAL_FAILURE_PLURAL from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_PartialFailure_Plural';
import DOWNLOAD_BUTTON from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_DownloadButton';
import CLOSE from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_Close';
import FILE_NAME_CSV from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FileName_Csv';
import FILE_NAME_JSON from '@salesforce/label/c.DataMaskingAdvisor_InventoryExport_FileName_Json';
import SENSITIVITY_SENSITIVE from '@salesforce/label/c.DataMaskingAdvisor_Sensitivity_Sensitive';
import SENSITIVITY_POSSIBLY from '@salesforce/label/c.DataMaskingAdvisor_Sensitivity_PossiblySensitive';

// Scope and format option values, doubling as the radio-group values and the per-scope cache keys.
const SCOPE_CUSTOM_VALUE = 'custom';
const SCOPE_MASKED_VALUE = 'masked';
const SCOPE_ALL_VALUE = 'all';
const FORMAT_CSV_VALUE = 'csv';
const FORMAT_JSON_VALUE = 'json';
// Per-scope fetch status: a confirm gate (All only), an in-flight fetch, or a loaded result.
const STATUS_NEEDS_CONFIRM = 'needsConfirm';
const STATUS_FETCHING = 'fetching';
const STATUS_READY = 'ready';
// At most this many getRegulatedFieldInventory calls are in flight at once, keeping each describe in its own
// transaction the way the coverage scan's pool does.
const EXPORT_CONCURRENCY = 4;
// How many preview rows to render before the "… N more rows" note takes over.
const PREVIEW_SAMPLE_SIZE = 4;
// A leading UTF-8 byte-order mark so Excel reads the file as UTF-8 and renders accented labels correctly,
// and CRLF line breaks so the CSV is strict RFC 4180. The mark is built with fromCharCode (not a literal
// character) so it survives editors and formatters that would silently strip an invisible BOM byte.
const CSV_BYTE_ORDER_MARK = String.fromCharCode(0xFEFF);
const CSV_LINE_BREAK = '\r\n';
// Lightning Web Security's URL.createObjectURL distortion rejects a Blob typed text/csv ("Unsupported MIME
// type") and throws, which would abort the download before the anchor is clicked. The generic octet-stream
// type is on its allowlist; the anchor's download attribute still names the file .csv, so spreadsheets open
// it by extension regardless of the Blob's MIME type. Do not change this back to text/csv.
const CSV_BLOB_MIME_TYPE = 'application/octet-stream';
// Raw sensitivity level → display label. The inventory only carries the two regulated levels; an unmapped
// value falls through to its raw form rather than rendering blank.
const SENSITIVITY_LABELS = {Sensitive: SENSITIVITY_SENSITIVE, PossiblySensitive: SENSITIVITY_POSSIBLY};
// The high-confidence regulated level — the sole level kept when the "Sensitive fields only" filter is on.
const SENSITIVITY_LEVEL_SENSITIVE = 'Sensitive';

/**
 * @description Static label strings the template renders, grouped so the markup reads `{labels.x}`.
 * @type {Object<string, string>}
 */
const LABELS = {
	title: TITLE,
	intro: INTRO,
	scopeHeading: SCOPE_HEADING,
	formatHeading: FORMAT_HEADING,
	formatNote: FORMAT_NOTE,
	maskedScopeNote: MASKED_SCOPE_NOTE,
	sensitiveOnly: SENSITIVE_ONLY,
	filteredEmptyState: FILTERED_EMPTY_STATE,
	confirmButton: CONFIRM_BUTTON,
	emptyState: EMPTY_STATE,
	close: CLOSE
};

export default class MaskingInventoryExportDialog extends LightningModal
{
	/**
	 * @description The full selectable-object universe — option rows `{Id, Name, isCustom, namespacePrefix}`
	 * the caller already loaded. The custom scope = own un-namespaced custom objects; the all scope = every
	 * row.
	 * @type {Array<Object>}
	 */
	@api objectOptions = [];

	/**
	 * @description Api names of the objects that already have active masking — the masked scope's population.
	 * @type {Array<string>}
	 */
	@api maskedApiNames = [];

	/**
	 * @description The selected export scope (custom | masked | all). Custom is the default — it is the
	 * subscriber's own data and the smallest, fastest scope.
	 * @type {string}
	 */
	selectedScope = SCOPE_CUSTOM_VALUE;

	/**
	 * @description The selected export format (csv | json). CSV is the default for spreadsheet use.
	 * @type {string}
	 */
	selectedFormat = FORMAT_CSV_VALUE;

	/**
	 * @description When true, the preview, counts, and downloaded file are narrowed to the high-confidence
	 * Sensitive rows, hiding the lower-confidence PossiblySensitive ones. Off by default so the export is
	 * complete until the administrator deliberately narrows it.
	 * @type {boolean}
	 */
	sensitiveOnly = false;

	/**
	 * @description Per-scope fetch result, keyed by scope value: `{rows, failedCount}`. Caching means
	 * switching back to a loaded scope never re-fetches.
	 * @type {Object<string, Object>}
	 */
	cache = {};

	/**
	 * @description Per-scope status (needsConfirm | fetching | ready), keyed by scope value. Keyed (not a
	 * single shared field) so a fetch that finishes after the user has moved on updates only its own scope.
	 * @type {Object<string, string>}
	 */
	statusByScope = {};

	/**
	 * @description Per-scope fetch progress `{done, total}`, keyed by scope value, so the progress bar shown
	 * for the selected scope never reflects another scope's in-flight fetch.
	 * @type {Object<string, Object>}
	 */
	progressByScope = {};

	/**
	 * @description Static label strings for the template.
	 * @returns {Object<string, string>}
	 */
	get labels()
	{
		return LABELS;
	}

	/**
	 * @description The api names of the custom scope — own un-namespaced custom objects from the universe.
	 * @returns {Array<string>}
	 */
	get customApiNames()
	{
		return this.objectOptions.filter((option) => option.isCustom && !option.namespacePrefix).map((option) => option.Id);
	}

	/**
	 * @description The api names of the all scope — every object in the universe.
	 * @returns {Array<string>}
	 */
	get allApiNames()
	{
		return this.objectOptions.map((option) => option.Id);
	}

	/**
	 * @description The scope radio-group options, each labelled with its object count.
	 * @returns {Array<Object>}
	 */
	get scopeOptions()
	{
		return [
			{label: this.scopeLabel(SCOPE_CUSTOM, this.customApiNames.length), value: SCOPE_CUSTOM_VALUE},
			{label: this.scopeLabel(SCOPE_MASKED, this.maskedApiNames.length), value: SCOPE_MASKED_VALUE},
			{label: this.scopeLabel(SCOPE_ALL, this.allApiNames.length), value: SCOPE_ALL_VALUE}
		];
	}

	/**
	 * @description The format radio-group options.
	 * @returns {Array<Object>}
	 */
	get formatOptions()
	{
		return [
			{label: FORMAT_CSV_LABEL, value: FORMAT_CSV_VALUE},
			{label: FORMAT_JSON_LABEL, value: FORMAT_JSON_VALUE}
		];
	}

	/**
	 * @description The selected scope's status (needsConfirm | fetching | ready), or undefined in the brief
	 * window before the scope's first status is recorded — connectedCallback / handleScopeChange set it
	 * synchronously, so the three status booleans below all read false (nothing renders) only in that gap.
	 * @returns {string}
	 */
	get currentStatus()
	{
		return this.statusByScope[this.selectedScope];
	}

	/**
	 * @description True while the selected scope's inventory is being fetched.
	 * @returns {boolean}
	 */
	get isFetching()
	{
		return this.currentStatus === STATUS_FETCHING;
	}

	/**
	 * @description True when the selected scope (All) is waiting on the confirm step before fetching.
	 * @returns {boolean}
	 */
	get needsConfirm()
	{
		return this.currentStatus === STATUS_NEEDS_CONFIRM;
	}

	/**
	 * @description True once the selected scope's inventory has loaded.
	 * @returns {boolean}
	 */
	get isReady()
	{
		return this.currentStatus === STATUS_READY;
	}

	/**
	 * @description True once the masked scope is loaded — its note explains why object-wide-masked objects
	 * contribute few per-field rows, so a near-empty result does not read as broken.
	 * @returns {boolean}
	 */
	get showMaskedScopeNote()
	{
		return this.isReady && this.selectedScope === SCOPE_MASKED_VALUE;
	}

	/**
	 * @description The loaded rows for the selected scope. Only read once the scope is ready — the preview,
	 * counts, and download are all gated on isReady — so the cache entry is always present here.
	 * @returns {Array<Object>}
	 */
	get currentRows()
	{
		return this.cache[this.selectedScope].rows;
	}

	/**
	 * @description The rows the preview, counts, and download actually render — the loaded rows, narrowed to
	 * the Sensitive level when the sensitive-only filter is on. Every consumer (preview, columns, counts, CSV,
	 * JSON) reads this so the filter governs the whole export from one place.
	 * @returns {Array<Object>}
	 */
	get displayRows()
	{
		return this.sensitiveOnly ? this.currentRows.filter((row) => row.sensitivityLevel === SENSITIVITY_LEVEL_SENSITIVE) : this.currentRows;
	}

	/**
	 * @description True once the scope is loaded and holds at least one row the sensitive-only filter would
	 * remove (a non-Sensitive row) — the filter control shows only when it has something to do. Read from the
	 * unfiltered rows so the control never disappears when the filter empties the table, leaving the
	 * administrator unable to clear it.
	 * @returns {boolean}
	 */
	get canFilterSensitive()
	{
		return this.isReady && this.currentRows.some((row) => row.sensitivityLevel !== SENSITIVITY_LEVEL_SENSITIVE);
	}

	/**
	 * @description The number of regulated-field rows the export currently shows (after the sensitive-only
	 * filter).
	 * @returns {number}
	 */
	get rowCount()
	{
		return this.displayRows.length;
	}

	/**
	 * @description True once the scope is loaded and holds no regulated fields AND nothing was skipped — so a
	 * scope where every object failed to analyze shows the skipped-objects note instead of a misleading
	 * "no regulated fields" all-clear.
	 * @returns {boolean}
	 */
	get isEmpty()
	{
		return this.isReady && this.currentRows.length === 0 && !this.hasPartialFailure;
	}

	/**
	 * @description True when the scope does hold regulated fields but the sensitive-only filter has removed
	 * every one — so a distinct "no Sensitive fields, clear the filter" note shows instead of the scope-level
	 * "no regulated fields" empty state, which would misread the filtered-out fields as absent.
	 * @returns {boolean}
	 */
	get isFilteredEmpty()
	{
		return this.isReady && this.sensitiveOnly && this.currentRows.length > 0 && this.displayRows.length === 0;
	}

	/**
	 * @description True once the scope is loaded and the export shows at least one (filtered) row — the preview
	 * shows.
	 * @returns {boolean}
	 */
	get hasRows()
	{
		return this.isReady && this.rowCount > 0;
	}

	/**
	 * @description The columns heading with the true row count interpolated (singular / plural).
	 * @returns {string}
	 */
	get rowCountText()
	{
		return this.format(this.rowCount === 1 ? COLUMNS_HEADING_SINGULAR : COLUMNS_HEADING_PLURAL, this.rowCount);
	}

	/**
	 * @description The columns that render for the loaded scope: every always-on column plus each droppable
	 * column at least one loaded row fills. Computed from the loaded rows so the column set reflects the data.
	 * @returns {Array<Object>}
	 */
	get activeColumns()
	{
		const rows = this.displayRows;
		return this.columnDescriptors().filter((column) => !column.droppable || rows.some((row) => column.value(row) !== ''));
	}

	/**
	 * @description The active columns' header labels, in order, for the preview table head.
	 * @returns {Array<Object>}
	 */
	get columnHeaders()
	{
		return this.activeColumns.map((column) => ({key: column.key, label: column.label}));
	}

	/**
	 * @description The first PREVIEW_SAMPLE_SIZE rows decorated for the preview table: one cell per active
	 * column in order, an absent droppable value rendered as the empty placeholder. The field type is its
	 * friendly label, booleans are Yes/No, and the sensitivity level is its display label.
	 * @returns {Array<Object>}
	 */
	get previewRows()
	{
		const columns = this.activeColumns;
		return this.displayRows.slice(0, PREVIEW_SAMPLE_SIZE).map((row) => ({
			key: `${row.objectApiName}|${row.fieldApiName}`, cells: columns.map((column) => ({key: column.key, value: column.value(row) || CELL_EMPTY}))
		}));
	}

	/**
	 * @description True when the loaded scope has more rows than the preview shows.
	 * @returns {boolean}
	 */
	get hasMoreRows()
	{
		return this.rowCount > PREVIEW_SAMPLE_SIZE;
	}

	/**
	 * @description The "… N more rows" note (singular / plural) for the rows beyond the preview.
	 * @returns {string}
	 */
	get moreRowsText()
	{
		const remainder = this.rowCount - PREVIEW_SAMPLE_SIZE;
		return this.format(remainder === 1 ? MORE_ROWS_SINGULAR : MORE_ROWS_PLURAL, remainder);
	}

	/**
	 * @description True when some objects in the loaded scope failed to analyze and were skipped.
	 * @returns {boolean}
	 */
	get hasPartialFailure()
	{
		return (this.cache[this.selectedScope]?.failedCount || 0) > 0;
	}

	/**
	 * @description The partial-failure note (singular / plural) naming how many objects were skipped.
	 * @returns {string}
	 */
	get partialFailureText()
	{
		const failed = this.cache[this.selectedScope].failedCount;
		return this.format(failed === 1 ? PARTIAL_FAILURE_SINGULAR : PARTIAL_FAILURE_PLURAL, failed);
	}

	/**
	 * @description The progress note ("Analyzing X of N objects…") for the in-flight fetch.
	 * @returns {string}
	 */
	get progressText()
	{
		const progress = this.progressByScope[this.selectedScope];
		return this.format(BUILDING_PROGRESS, progress.done, progress.total);
	}

	/**
	 * @description The All-scope confirm body with the all-object count interpolated.
	 * @returns {string}
	 */
	get confirmText()
	{
		return this.format(CONFIRM_BODY, this.allApiNames.length);
	}

	/**
	 * @description The download button label with the selected format interpolated.
	 * @returns {string}
	 */
	get downloadLabel()
	{
		return this.format(DOWNLOAD_BUTTON, this.selectedFormat.toUpperCase());
	}

	/**
	 * @description True while the download button is disabled — no loaded rows to write.
	 * @returns {boolean}
	 */
	get downloadDisabled()
	{
		return !this.hasRows;
	}

	/**
	 * @description Kicks off the default (custom) scope's fetch as soon as the dialog mounts.
	 */
	connectedCallback()
	{
		this.ensureScopeLoaded(this.selectedScope);
	}

	/**
	 * @description The api names belonging to the given scope — masked uses the masked set, all uses the whole
	 * universe, and any other scope (custom) uses the own un-namespaced custom objects.
	 * @param {string} scope - The scope (custom | masked | all).
	 * @returns {Array<string>}
	 */
	apiNamesFor(scope)
	{
		if(scope === SCOPE_MASKED_VALUE)
		{
			return this.maskedApiNames;
		}
		if(scope === SCOPE_ALL_VALUE)
		{
			return this.allApiNames;
		}
		return this.customApiNames;
	}

	/**
	 * @description Composes a scope option label as "<scope> — <N object(s)>".
	 * @param {string} base - The scope's base label.
	 * @param {number} count - The scope's object count.
	 * @returns {string}
	 */
	scopeLabel(base, count)
	{
		return `${base} — ${this.format(count === 1 ? OBJECT_COUNT_SINGULAR : OBJECT_COUNT_PLURAL, count)}`;
	}

	/**
	 * @description The ordered column descriptors — each carries its header label, the cell value it derives
	 * from a row (the CSV/preview string, blank for an absent value), and whether it is droppable. A droppable
	 * column (the two native-classification columns and the recommended rule) is omitted from the preview and
	 * the CSV when every loaded row leaves it blank, so an org with no native data classification does not
	 * export a wall of empty cells. Every non-droppable column — object, field, type, long-text-area,
	 * sensitivity, masked-today, history — always renders.
	 * @returns {Array<Object>}
	 */
	columnDescriptors()
	{
		return [
			{key: 'object', label: COLUMN_OBJECT, value: (row) => row.objectApiName, droppable: false},
			{key: 'field', label: COLUMN_FIELD, value: (row) => row.fieldApiName, droppable: false},
			{key: 'fieldType', label: COLUMN_FIELD_TYPE, value: (row) => friendlyFieldType(row.fieldType), droppable: false},
			{key: 'longTextArea', label: COLUMN_LONG_TEXT_AREA, value: (row) => this.yesNo(row.isLongTextArea), droppable: false},
			{key: 'securityClassification', label: COLUMN_SECURITY_CLASSIFICATION, value: (row) => row.securityClassification || '', droppable: true},
			{key: 'complianceGroup', label: COLUMN_COMPLIANCE_GROUP, value: (row) => row.complianceGroup || '', droppable: true},
			{key: 'sensitivity', label: COLUMN_SENSITIVITY, value: (row) => this.sensitivityLabel(row.sensitivityLevel), droppable: false},
			{key: 'recommendedRule', label: COLUMN_RECOMMENDED_RULE, value: (row) => row.recommendedRuleLabel || '', droppable: true},
			{key: 'maskedToday', label: COLUMN_MASKED_TODAY, value: (row) => this.yesNo(row.maskedToday), droppable: false},
			{key: 'historyTrackingRecommended', label: COLUMN_HISTORY, value: (row) => this.yesNo(row.historyTrackingRecommended), droppable: false}
		];
	}

	/**
	 * @description Maps a boolean to its Yes/No cell label.
	 * @param {boolean} value - The flag.
	 * @returns {string}
	 */
	yesNo(value)
	{
		return value ? CELL_YES : CELL_NO;
	}

	/**
	 * @description Maps a raw sensitivity level to its display label, falling back to the raw value.
	 * @param {string} level - The raw sensitivity level.
	 * @returns {string}
	 */
	sensitivityLabel(level)
	{
		return SENSITIVITY_LABELS[level] || level;
	}

	/**
	 * @description Ensures the scope's inventory is loaded: a cached or in-flight scope is left alone, the
	 * All scope first shows its confirm gate, and any other scope is fetched.
	 * @param {string} scope - The scope to load.
	 */
	ensureScopeLoaded(scope)
	{
		if(this.cache[scope] || this.statusByScope[scope] === STATUS_FETCHING)
		{
			return;
		}
		if(scope === SCOPE_ALL_VALUE)
		{
			this.statusByScope = {...this.statusByScope, [scope]: STATUS_NEEDS_CONFIRM};
			return;
		}
		this.startFetch(scope);
	}

	/**
	 * @description Fetches a scope's inventory one object per call through a bounded worker pool, accumulating
	 * the denormalized rows and the count of objects that failed, then caches the result and marks the scope
	 * ready. An empty scope is cached immediately with no calls.
	 * @param {string} scope - The scope to fetch.
	 * @returns {Promise}
	 */
	async startFetch(scope)
	{
		const apiNames = this.apiNamesFor(scope);
		this.statusByScope = {...this.statusByScope, [scope]: STATUS_FETCHING};
		this.progressByScope = {...this.progressByScope, [scope]: {done: 0, total: apiNames.length}};

		const rows = [];
		let failedCount = 0;
		let cursor = 0;
		const worker = async() =>
		{
			while(cursor < apiNames.length)
			{
				const apiName = apiNames[cursor];
				cursor += 1;
				try
				{
					// eslint-disable-next-line no-await-in-loop -- deliberate pacing: objects are fetched sequentially so the export reports per-object progress without flooding Apex
					const inventory = await getRegulatedFieldInventory({objectApiName: apiName});
					(inventory?.rows || []).forEach((row) => rows.push({...row, objectApiName: inventory.objectApiName}));
				}
				catch(error)
				{
					failedCount += 1;
				}
				const progress = this.progressByScope[scope];
				this.progressByScope = {...this.progressByScope, [scope]: {done: progress.done + 1, total: progress.total}};
			}
		};

		const workerCount = Math.min(EXPORT_CONCURRENCY, apiNames.length);
		await Promise.all(Array.from({length: workerCount}, () => worker()));
		this.cache = {...this.cache, [scope]: {rows, failedCount}};
		this.statusByScope = {...this.statusByScope, [scope]: STATUS_READY};
	}

	/**
	 * @description Interpolates positional `{0}`, `{1}`… placeholders in a label with the supplied arguments.
	 * @param {string} template - The label template.
	 * @param {...*} args - The replacement values, in order.
	 * @returns {string}
	 */
	format(template, ...args)
	{
		// Function replacement (not a string) so a value containing $-patterns is inserted literally rather
		// than interpreted by String.replace.
		return args.reduce((text, argument, index) => text.replace(`{${index}}`, () => String(argument)), template);
	}

	/**
	 * @description Records the picked scope and loads it (cached scopes render instantly; All shows confirm).
	 * @param {CustomEvent} event - The scope radio-group's change event carrying the value in detail.
	 */
	handleScopeChange(event)
	{
		this.selectedScope = event.detail.value;
		this.ensureScopeLoaded(this.selectedScope);
	}

	/**
	 * @description Records the picked format; the preview is format-independent so nothing re-fetches.
	 * @param {CustomEvent} event - The format radio-group's change event carrying the value in detail.
	 */
	handleFormatChange(event)
	{
		this.selectedFormat = event.detail.value;
	}

	/**
	 * @description Records the sensitive-only filter toggle; the preview and download are pure functions of the
	 * loaded rows, so the change re-renders without re-fetching.
	 * @param {CustomEvent} event - The checkbox change event; the new state is on event.target.checked.
	 */
	handleSensitiveOnlyChange(event)
	{
		this.sensitiveOnly = event.target.checked;
	}

	/**
	 * @description Starts the All-scope fetch the confirm step was gating.
	 */
	handleConfirm()
	{
		this.startFetch(SCOPE_ALL_VALUE);
	}

	/**
	 * @description Assembles the loaded scope's rows into the selected format and triggers a one-click
	 * download. The modal stays open so the administrator can switch format or scope and download again.
	 */
	handleDownload()
	{
		const file = this.selectedFormat === FORMAT_JSON_VALUE ? this.buildJson() : this.buildCsv();
		// The anchor is transient — created, clicked, and discarded — so it never enters the document or the
		// accessibility tree, mirroring the advisor's masking-package download path.
		const objectUrl = window.URL.createObjectURL(new Blob([file.body], {type: file.mime}));
		const anchor = document.createElement('a');
		anchor.href = objectUrl;
		anchor.download = file.name;
		anchor.click();
		// The anchor-download read is synchronous, so the URL can be freed immediately. The dialog stays open
		// and can download repeatedly, so not freeing would leak one object URL per click for the page's life.
		window.URL.revokeObjectURL(objectUrl);
	}

	/**
	 * @description Builds the CSV file: a UTF-8 BOM, then the active columns' human headers followed by one
	 * escaped row per field, joined with CRLF and ending in a trailing CRLF (strict RFC 4180). The field type
	 * is its friendly label, the rule and sensitivity their display labels, and the booleans Yes/No — the
	 * human-readable counterpart to the raw-schema JSON. Columns blank across every row are omitted.
	 * @returns {Object} `{name, mime, body}`.
	 */
	buildCsv()
	{
		const columns = this.activeColumns;
		const header = columns.map((column) => this.escapeCsv(column.label)).join(',');
		const lines = this.displayRows.map((row) => columns.map((column) => this.escapeCsv(column.value(row))).join(','));
		const body = `${CSV_BYTE_ORDER_MARK}${[
			header,
			...lines
		].join(CSV_LINE_BREAK)}${CSV_LINE_BREAK}`;
		return {name: FILE_NAME_CSV, mime: CSV_BLOB_MIME_TYPE, body};
	}

	/**
	 * @description Builds the JSON file: one object per field keyed by the stable camelCase schema, the
	 * sensitivity level and recommended-rule developer name kept raw (null when absent).
	 * @returns {Object} `{name, mime, body}`.
	 */
	buildJson()
	{
		const records = this.displayRows.map((row) => ({
			objectApiName: row.objectApiName,
			fieldApiName: row.fieldApiName,
			fieldType: row.fieldType,
			isLongTextArea: row.isLongTextArea,
			securityClassification: row.securityClassification ?? null,
			complianceGroup: row.complianceGroup ?? null,
			sensitivityLevel: row.sensitivityLevel,
			recommendedRule: row.recommendedRuleDeveloperName ?? null,
			maskedToday: row.maskedToday,
			historyTrackingRecommended: row.historyTrackingRecommended
		}));
		return {name: FILE_NAME_JSON, mime: 'application/json', body: JSON.stringify(records, null, 2)};
	}

	/**
	 * @description Escapes one already-stringified CSV cell (the column descriptors render an absent value as
	 * an empty string before this runs). A cell whose first character a spreadsheet treats as a formula
	 * trigger (`= + - @`, tab, carriage return) is prefixed with a single quote so an admin-authored value
	 * (for example a masking-rule label) cannot execute as a formula when the file is opened in Excel or
	 * Sheets — CSV formula-injection defense. Finally a value carrying a comma, quote, or newline is wrapped
	 * in quotes with its own quotes doubled (RFC 4180).
	 * @param {string} value - The cell value (already an empty string when absent).
	 * @returns {string}
	 */
	escapeCsv(value)
	{
		let text = String(value);
		if(/^[=+\-@\t\r]/.test(text))
		{
			text = `'${text}`;
		}
		// Wrap on a carriage return as well as a newline: the rows now join with CRLF, so a lone CR inside a
		// value would otherwise be read as a row break and tear the row apart.
		return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
	}

	/**
	 * @description Dismisses the dialog.
	 */
	handleClose()
	{
		this.close(null);
	}
}
