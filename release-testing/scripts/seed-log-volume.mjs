// SPDX-License-Identifier: BUSL-1.1

/**
 * Log Console VOLUME seed — 120,000 back-dated `LogEntry__c` rows with a realistic shape.
 *
 * WHAT: generates a deterministic, realistic log corpus (business-hours curve over the last N days,
 * a heavy-tailed vocabulary of 40 class/method signatures, correlated multi-hop transactions, and a
 * fingerprinted `detail:` / `rollup:` layer) and loads it through Bulk API 2.0 in chunks.
 *
 * WHY: the release orgs only ever held a few thousand shaped e2e rows, so the Log Console was never
 * exercised at subscriber scale. Defects that only volume shows (paging, ribbon degradation, the
 * 100,000-row Apex pagination-cursor ceiling) are invisible below this size.
 *
 * PREREQUISITES:
 *   - Audit-field back-dating enabled in the target org (RUNBOOK Phase 1.4: the two-step audit-fields
 *     deploy plus the `KernE2EAuditFieldAccess` permission set). Without it every `CreatedDate`
 *     silently falls to "now" and the whole corpus lands in one minute — the script detects this,
 *     reports it loudly and exits non-zero.
 *   - Enough data storage: a `LogEntry__c` row costs about 2 KB, so 120,000 rows need about 245 MB.
 *   - Node 22.22.3 and an authenticated `sf` CLI. No third-party dependencies.
 *
 * NAMESPACE-ROBUST: the prefix is probed from the org (`kern__` on a managed subscriber org, empty on
 * an unmanaged developer org) and every field name is built from it. Nothing is hardcoded.
 *
 * DETERMINISM: every value is drawn from the `--seed` generator, so a re-run against the same window
 * anchor rebuilds the identical corpus. The anchor is the current minute (the rows have to be recent),
 * so runs started in different minutes differ in their absolute timestamps and in the day buckets the
 * `rollup:` counters land on — the shape, the mix and the counts stay the same.
 *
 * TEARDOWN MARKER: every generated row carries a `TransactionId__c` that starts with `seed-volume-`,
 * and every generated fingerprint contains `seed-volume-`. `--teardown` removes exactly those rows,
 * plus the chain executions and marker records left by `seed-chain-scenarios.sh`.
 *
 * Usage:
 *   node release-testing/scripts/seed-log-volume.mjs --dry-run --rows 2000
 *   node release-testing/scripts/seed-log-volume.mjs --org YourSubscriberOrgAlias --rows 120000 --days 30
 *   node release-testing/scripts/seed-log-volume.mjs --org YourSubscriberOrgAlias --teardown
 *
 * Exits 1 on a bulk-job failure, on a failed back-dating probe, or on a duplicate fingerprint.
 */

import {execFileSync} from 'node:child_process';
import {mkdirSync, writeFileSync, readFileSync, existsSync, unlinkSync, statSync} from 'node:fs';
import path from 'node:path';

const DEFAULT_ORGANISATION_ALIAS = 'YourSubscriberOrgAlias';
const DEFAULT_ROW_COUNT = 120000;
const DEFAULT_WINDOW_DAYS = 30;
const DEFAULT_CHUNK_SIZE = 40000;
const DEFAULT_RANDOM_SEED = 1;
const DEFAULT_OUTPUT_DIRECTORY = 'tmp/release-1.7.0/seed';
const DEFAULT_TIME_ZONE = 'America/Los_Angeles';

const SEED_MARKER = 'seed-volume-';
const SIGNATURE_BASE_PREFIX = `${SEED_MARKER}sig-`;
// SOQL treats a bare underscore as a single-character wildcard, so the marker escapes it. The doubled
// backslash survives the Apex string literal the generated teardown script wraps the query in.
const CHAIN_NAME_MARKER = 'Seed\\\\_%';
const FOOBAR_NAME_PATTERNS = ['Chain Test %', 'Subscriber Recovery Marker %'];
const CHAIN_SEED_STATE_FILE = 'chain-seed-state.json';

const BULK_IMPORT_WAIT_MINUTES = 30;
const BULK_EXPORT_WAIT_MINUTES = 10;
const BULK_DELETE_WAIT_MINUTES = 30;
const SALESFORCE_COMMAND_BUFFER_BYTES = 512 * 1024 * 1024;

// Correlated multi-hop transactions as a share of the whole corpus, and the hop count they span.
const CORRELATED_ROW_SHARE = 0.06;
const MINIMUM_HOPS_PER_CORRELATION = 3;
const MAXIMUM_HOPS_PER_CORRELATION = 8;
const MINIMUM_ROLLUP_DAYS_PER_SIGNATURE = 5;
const MAXIMUM_ROLLUP_DAYS_PER_SIGNATURE = 25;
const MINIMUM_OCCURRENCE_COUNT = 3;
const MAXIMUM_OCCURRENCE_COUNT = 900;
const STACK_TRACE_SHARE_OF_ERRORS = 0.6;
const RECORD_IDENTIFIER_SHARE = 0.15;
const MINIMUM_DURATION_MILLISECONDS = 5;
const MAXIMUM_DURATION_MILLISECONDS = 4000;

// Local-clock activity curve: index is the hour of day in the org user's timezone.
const HOUR_OF_DAY_WEIGHTS = [1, 1, 1, 1, 1, 2, 4, 9, 20, 28, 30, 28, 22, 26, 28, 26, 22, 16, 9, 5, 4, 3, 2, 1];
const WEEKEND_ACTIVITY_FACTOR = 0.22;

const LEVEL_WEIGHTS = [{level: 'ERROR', weight: 12}, {level: 'WARN', weight: 18}, {level: 'INFO', weight: 45}, {level: 'DEBUG', weight: 25}];

const EXECUTION_EVENT_WEIGHTS = [
	{value: 'SYNCHRONOUS', weight: 30},
	{value: 'QUEUEABLE', weight: 22},
	{value: 'BATCH_APEX', weight: 18},
	{value: 'REST', weight: 8},
	{value: 'AURA', weight: 7},
	{value: 'SCHEDULED', weight: 6},
	{value: 'FUTURE', weight: 5},
	{value: 'ANONYMOUS', weight: 2},
	{value: 'TRANSACTION_FINALIZER_QUEUEABLE', weight: 2}
];

// The vocabulary. Heavy-tailed within each level: the first entries of a level fire far more often
// than the last. Every entry is one class/method signature a real Salesforce org would produce.
const SIGNATURES = [
	{
		level: 'ERROR', className: 'OrderService', methodName: 'commitWork',
		lineNumber: 77, exceptionType: 'System.DmlException',
		shortMessage: 'Insert failed: FIELD_CUSTOM_VALIDATION_EXCEPTION',
		message: 'Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, Ship date cannot precede the order date'
	},
	{
		level: 'ERROR', className: 'PaymentGateway', methodName: 'capture',
		lineNumber: 64, exceptionType: 'System.CalloutException',
		shortMessage: 'Read timed out',
		message: 'Read timed out after 10000ms calling the payment gateway endpoint /v1/charges'
	},
	{
		level: 'ERROR', className: 'AccountTriggerHandler', methodName: 'handleAfterUpdate',
		lineNumber: 142, exceptionType: 'System.NullPointerException',
		shortMessage: 'Attempt to de-reference a null object',
		message: 'Attempt to de-reference a null object while recalculating the parent account rollup'
	},
	{
		level: 'ERROR', className: 'LedgerJob', methodName: 'post',
		lineNumber: 301, exceptionType: 'System.DmlException',
		shortMessage: 'UNABLE_TO_LOCK_ROW',
		message: 'UNABLE_TO_LOCK_ROW, unable to obtain exclusive access to this record while posting the ledger batch'
	},
	{
		level: 'ERROR', className: 'InvoiceBatch', methodName: 'execute',
		lineNumber: 210, exceptionType: 'System.LimitException',
		shortMessage: 'Apex CPU time limit exceeded',
		message: 'Apex CPU time limit exceeded while pricing the invoice chunk'
	},
	{
		level: 'ERROR', className: 'IntegrationService', methodName: 'push',
		lineNumber: 144, exceptionType: 'System.CalloutException',
		shortMessage: 'Unexpected end of file from server',
		message: 'Unexpected end of file from server while pushing the account delta to the middleware'
	},
	{
		level: 'ERROR', className: 'PricingClient', methodName: 'quote',
		lineNumber: 58, exceptionType: 'System.JSONException',
		shortMessage: 'Unexpected character in pricing response',
		message: 'Unexpected character (\'<\') at position 0 — the pricing service answered with an HTML error page'
	},
	{
		level: 'ERROR', className: 'SyncScheduler', methodName: 'run',
		lineNumber: 276, exceptionType: 'System.QueryException',
		shortMessage: 'List has no rows for assignment to SObject',
		message: 'List has no rows for assignment to SObject while resolving the sync configuration record'
	},
	{
		level: 'ERROR', className: 'CartController', methodName: 'checkout',
		lineNumber: 91, exceptionType: 'System.SecurityException',
		shortMessage: 'Insufficient access rights on cross-reference id',
		message: 'Insufficient access rights on cross-reference id while attaching the contract to the cart'
	},
	{
		level: 'ERROR', className: 'NotificationService', methodName: 'dispatch',
		lineNumber: 47, exceptionType: 'System.EmailException',
		shortMessage: 'SINGLE_EMAIL_LIMIT_EXCEEDED',
		message: 'SINGLE_EMAIL_LIMIT_EXCEEDED — the daily single-email allocation was exhausted before the dispatch finished'
	},
	{
		level: 'ERROR', className: 'EntitlementResolver', methodName: 'resolve',
		lineNumber: 133, exceptionType: 'System.TypeException',
		shortMessage: 'Invalid id for the entitlement lookup',
		message: 'Invalid id: the entitlement key held a 15-character value where an 18-character id was expected'
	},
	{
		level: 'ERROR', className: 'WarehouseAllocator', methodName: 'allocate',
		lineNumber: 188, exceptionType: 'System.DmlException',
		shortMessage: 'STORAGE_LIMIT_EXCEEDED',
		message: 'STORAGE_LIMIT_EXCEEDED while writing the allocation ledger — the org is over its data allocation'
	},

	{
		level: 'WARN', className: 'InventoryService', methodName: 'reserve',
		lineNumber: 210, exceptionType: null,
		shortMessage: 'Low stock, partial reserve',
		message: 'Low stock: reserved 8 of the 12 requested units and flagged the shortfall for the next replenishment run'
	},
	{
		level: 'WARN', className: 'AccountTriggerHandler', methodName: 'recalculateRollups',
		lineNumber: 88, exceptionType: null,
		shortMessage: 'Query exceeded the soft time budget',
		message: 'Rollup query took 4200ms against a 2000ms soft budget; consider narrowing the selector field list'
	},
	{
		level: 'WARN', className: 'IntegrationService', methodName: 'push',
		lineNumber: 151, exceptionType: null,
		shortMessage: 'Throttled by the downstream API',
		message: 'Throttled by the downstream API (HTTP 429); the retry strategy scheduled another attempt'
	},
	{
		level: 'WARN', className: 'PaymentGateway', methodName: 'retry',
		lineNumber: 45, exceptionType: null,
		shortMessage: 'Retry scheduled after a gateway 503',
		message: 'The gateway answered 503; a retry was scheduled with the configured exponential backoff'
	},
	{
		level: 'WARN', className: 'DiscountEngine', methodName: 'apply',
		lineNumber: 140, exceptionType: null,
		shortMessage: 'Discount exceeds the threshold, capped',
		message: 'The requested 35% discount exceeds the 20% approval threshold and was capped at 20%'
	},
	{
		level: 'WARN', className: 'AddressValidator', methodName: 'validate',
		lineNumber: 62, exceptionType: null,
		shortMessage: 'Address only partially matched',
		message: 'The address service returned a partial match; the street line was accepted but the postcode was corrected'
	},
	{
		level: 'WARN', className: 'DocumentRenderer', methodName: 'render',
		lineNumber: 118, exceptionType: null,
		shortMessage: 'Template fell back to the default locale',
		message: 'No template exists for the requested locale; the renderer fell back to the org default locale'
	},
	{
		level: 'WARN', className: 'FeatureFlagService', methodName: 'evaluate',
		lineNumber: 29, exceptionType: null,
		shortMessage: 'Feature flag missing, defaulting to off',
		message: 'No feature-flag record exists for the requested key; the evaluation defaulted to off'
	},
	{
		level: 'WARN', className: 'UsageMeter', methodName: 'record',
		lineNumber: 74, exceptionType: null,
		shortMessage: 'Metering event arrived out of order',
		message: 'A metering event arrived with a timestamp behind the last recorded sample and was reordered on write'
	},

	{
		level: 'INFO', className: 'OrderService', methodName: 'processFulfilment',
		lineNumber: 151, exceptionType: null,
		shortMessage: 'Fulfilment completed',
		message: 'Fulfilment completed: the order was allocated, packed and handed to the carrier integration'
	},
	{
		level: 'INFO', className: 'CartController', methodName: 'checkout',
		lineNumber: 44, exceptionType: null,
		shortMessage: 'Checkout completed',
		message: 'Checkout completed and the confirmation email was queued for the buyer'
	},
	{
		level: 'INFO', className: 'IntegrationService', methodName: 'sync',
		lineNumber: 33, exceptionType: null,
		shortMessage: 'Integration sync completed',
		message: 'Integration sync completed; the middleware acknowledged every record in the delta'
	},
	{
		level: 'INFO', className: 'PaymentGateway', methodName: 'capture',
		lineNumber: 60, exceptionType: null,
		shortMessage: 'Payment captured',
		message: 'Payment captured and the settlement reference was written back to the order'
	},
	{
		level: 'INFO', className: 'InvoiceBatch', methodName: 'finish',
		lineNumber: 265, exceptionType: null,
		shortMessage: 'Invoice batch finished',
		message: 'Invoice batch finished; every chunk was priced and the summary notification was sent'
	},
	{
		level: 'INFO', className: 'SyncScheduler', methodName: 'run',
		lineNumber: 12, exceptionType: null,
		shortMessage: 'Nightly sync scheduled',
		message: 'Nightly sync scheduled for the configured window and the previous run was archived'
	},
	{
		level: 'INFO', className: 'NotificationService', methodName: 'dispatch',
		lineNumber: 40, exceptionType: null,
		shortMessage: 'Notification queued',
		message: 'Notification queued for delivery through the configured channel'
	},
	{
		level: 'INFO', className: 'LedgerJob', methodName: 'post',
		lineNumber: 295, exceptionType: null,
		shortMessage: 'Ledger posting complete',
		message: 'Ledger posting complete; the period balance was recalculated and locked'
	},
	{
		level: 'INFO', className: 'WarehouseAllocator', methodName: 'allocate',
		lineNumber: 180, exceptionType: null,
		shortMessage: 'Stock allocated',
		message: 'Stock allocated from the nearest warehouse with capacity and the pick list was generated'
	},
	{
		level: 'INFO', className: 'EntitlementResolver', methodName: 'resolve',
		lineNumber: 128, exceptionType: null,
		shortMessage: 'Entitlement resolved',
		message: 'Entitlement resolved from the active service contract and cached for the transaction'
	},
	{
		level: 'INFO', className: 'ContractRenewal', methodName: 'renew',
		lineNumber: 71, exceptionType: null,
		shortMessage: 'Contract renewed',
		message: 'Contract renewed for a further twelve months and the renewal opportunity was created'
	},
	{
		level: 'INFO', className: 'AccountMergeService', methodName: 'merge',
		lineNumber: 96, exceptionType: null,
		shortMessage: 'Accounts merged',
		message: 'Accounts merged; child records were reparented and the losing record was archived'
	},

	{
		level: 'DEBUG', className: 'OrderService', methodName: 'buildPayload',
		lineNumber: 39, exceptionType: null,
		shortMessage: 'Payload assembled',
		message: 'Payload assembled for the fulfilment call with the resolved shipping and tax lines'
	},
	{
		level: 'DEBUG', className: 'TriggerDispatcher', methodName: 'run',
		lineNumber: 58, exceptionType: null,
		shortMessage: 'Dispatching AfterUpdate actions',
		message: 'Dispatching AfterUpdate actions for the configured trigger action list'
	},
	{
		level: 'DEBUG', className: 'QueryCache', methodName: 'lookup',
		lineNumber: 22, exceptionType: null,
		shortMessage: 'Cache hit',
		message: 'Cache hit for the request-scoped describe lookup; no round trip was needed'
	},
	{
		level: 'DEBUG', className: 'PricingClient', methodName: 'quote',
		lineNumber: 51, exceptionType: null,
		shortMessage: 'Pricing request prepared',
		message: 'Pricing request prepared with the customer price book and the negotiated rate card'
	},
	{
		level: 'DEBUG', className: 'AddressValidator', methodName: 'normalise',
		lineNumber: 55, exceptionType: null,
		shortMessage: 'Address normalised',
		message: 'Address normalised to the postal standard before the validation callout'
	},
	{
		level: 'DEBUG', className: 'DocumentRenderer', methodName: 'render',
		lineNumber: 104, exceptionType: null,
		shortMessage: 'Merge fields resolved',
		message: 'Merge fields resolved against the record context before the document was rendered'
	},
	{
		level: 'DEBUG', className: 'UsageMeter', methodName: 'record',
		lineNumber: 68, exceptionType: null,
		shortMessage: 'Usage sample recorded',
		message: 'Usage sample recorded against the current billing period'
	}
];

// Frames appended below a signature's own frame so error stacks read like a real call graph.
const CALLER_FRAMES = [
	{className: 'TriggerDispatcher', methodName: 'run', lineNumber: 58},
	{className: 'OrderService', methodName: 'processFulfilment', lineNumber: 151},
	{className: 'OrderFulfilmentQueueable', methodName: 'execute', lineNumber: 42},
	{className: 'IntegrationService', methodName: 'sync', lineNumber: 33},
	{className: 'InvoiceBatch', methodName: 'execute', lineNumber: 210},
	{className: 'SyncScheduler', methodName: 'run', lineNumber: 12},
	{className: 'CartController', methodName: 'checkout', lineNumber: 44},
	{className: 'LedgerJob', methodName: 'post', lineNumber: 295}
];

const CSV_COLUMNS = [
	'LogLevel__c',
	'ShortMessage__c',
	'Message__c',
	'ClassMethod__c',
	'Origin__c',
	'Source__c',
	'LineNumber__c',
	'ExceptionType__c',
	'StackTrace__c',
	'ExecutionEvent__c',
	'TransactionId__c',
	'CorrelationId__c',
	'ParentTransactionId__c',
	'UserId__c',
	'DurationMs__c',
	'Fingerprint__c',
	'OccurrenceCount__c',
	'RecordId__c'
];

const AUDIT_COLUMNS = ['CreatedDate', 'LastModifiedDate'];

/**
 * Reads a CLI flag in either `--name=value` or `--name value` form.
 * @param {string} name - Flag name without the leading dashes.
 * @param {string|boolean} fallback - Value when the flag is absent.
 * @returns {string|boolean}
 */
function readFlag(name, fallback)
{
	const index = process.argv.findIndex((argument) => argument === `--${name}` || argument.startsWith(`--${name}=`));
	if(index === -1)
	{
		return fallback;
	}
	const argument = process.argv[index];
	if(argument.includes('='))
	{
		return argument.split('=').slice(1).join('=');
	}
	const next = process.argv[index + 1];
	if(next === undefined || next.startsWith('--'))
	{
		return true;
	}
	return next;
}

/**
 * Reads a numeric CLI flag.
 * @param {string} name - Flag name without the leading dashes.
 * @param {number} fallback - Value when the flag is absent or unparseable.
 * @returns {number}
 */
function readNumericFlag(name, fallback)
{
	const raw = readFlag(name, null);
	if(raw === null || raw === true)
	{
		return fallback;
	}
	const parsed = Number.parseInt(String(raw), 10);
	return Number.isFinite(parsed) ? parsed : fallback;
}

/**
 * Deterministic 32-bit pseudo-random generator, so the same `--seed` always builds the same corpus.
 * @param {number} seed - Starting state.
 * @returns {function(): number} Generator returning a float in [0, 1).
 */
function createRandom(seed)
{
	let state = seed >>> 0;
	return function next()
	{
		state = (state + 0x6d2b79f5) >>> 0;
		let value = Math.imul(state ^ (state >>> 15), 1 | state);
		value = (value + Math.imul(value ^ (value >>> 7), 61 | value)) ^ value;
		return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
	};
}

/**
 * Picks an index from a cumulative weight table.
 * @param {number[]} cumulative - Ascending cumulative weights.
 * @param {number} sample - Float in [0, 1).
 * @returns {number} The chosen index.
 */
function pickWeightedIndex(cumulative, sample)
{
	const target = sample * cumulative[cumulative.length - 1];
	let low = 0;
	let high = cumulative.length - 1;
	while(low < high)
	{
		const middle = (low + high) >> 1;
		if(cumulative[middle] <= target)
		{
			low = middle + 1;
		}
		else
		{
			high = middle;
		}
	}
	return low;
}

/**
 * Builds the ascending cumulative table for a list of weights.
 * @param {number[]} weights - Raw weights.
 * @returns {number[]} Cumulative weights.
 */
function buildCumulative(weights)
{
	const cumulative = [];
	let running = 0;
	for(const weight of weights)
	{
		running += weight;
		cumulative.push(running);
	}
	return cumulative;
}

/**
 * Runs an `sf` command, writing its raw output to a log file and returning the parsed JSON.
 * Never pipes the command, so the exit code stays the command's own.
 * @param {string[]} commandArguments - Arguments after the `sf` binary.
 * @param {string|null} logPath - File to receive the raw output, or null to skip logging.
 * @returns {object} The parsed JSON payload.
 */
function runSalesforceCommand(commandArguments, logPath)
{
	let output = '';
	let failure = null;
	try
	{
		output = execFileSync('sf', commandArguments, {encoding: 'utf8', maxBuffer: SALESFORCE_COMMAND_BUFFER_BYTES});
	}
	catch(error)
	{
		output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
		failure = error;
	}
	if(logPath)
	{
		writeFileSync(logPath, output, 'utf8');
	}
	let parsed = null;
	try
	{
		parsed = JSON.parse(output);
	}
	catch(parseError)
	{
		parsed = null;
	}
	if(parsed === null)
	{
		throw new Error(`sf ${commandArguments.join(' ')} produced no JSON. Raw output:\n${output.slice(0, 4000)}`);
	}
	if(failure && parsed.status !== 0)
	{
		throw new Error(`sf ${commandArguments.join(' ')} failed with status ${parsed.status}: ${parsed.message ?? 'no message'}`);
	}
	return parsed;
}

/**
 * Runs a SOQL query against the org and returns its records.
 * @param {string} organisationAlias - Target org alias.
 * @param {string} soql - The query.
 * @param {boolean} useToolingApi - Whether to run against the Tooling API.
 * @returns {{records: object[], totalSize: number}}
 */
function query(organisationAlias, soql, useToolingApi)
{
	const commandArguments = ['data', 'query', '-o', organisationAlias, '-q', soql, '--json'];
	if(useToolingApi)
	{
		commandArguments.push('--use-tooling-api');
	}
	const parsed = runSalesforceCommand(commandArguments, null);
	return {records: parsed.result?.records ?? [], totalSize: parsed.result?.totalSize ?? 0};
}

/**
 * Probes the managed-package namespace prefix of the target org.
 * @param {string} organisationAlias - Target org alias.
 * @returns {string} `kern__` on a managed subscriber org, an empty string on an unmanaged org.
 */
function resolveNamespacePrefix(organisationAlias)
{
	const result = query(organisationAlias, 'SELECT NamespacePrefix FROM ApexClass WHERE Name = \'UTIL_AsyncChain\' LIMIT 1', true);
	const prefix = result.records[0]?.NamespacePrefix;
	return prefix ? `${prefix}__` : '';
}

/**
 * Resolves the running user's 18-character id and timezone, which every seeded row is attributed to.
 * @param {string} organisationAlias - Target org alias.
 * @returns {{userId: string, timeZone: string, username: string}}
 */
function resolveSeedUser(organisationAlias)
{
	const display = runSalesforceCommand(['org', 'display', '-o', organisationAlias, '--json'], null);
	const username = display.result?.username;
	if(!username)
	{
		throw new Error(`Could not read the username of org ${organisationAlias}`);
	}
	const escaped = username.replace(/'/g, '\\\'');
	const result = query(organisationAlias, `SELECT Id, TimeZoneSidKey FROM User WHERE Username = '${escaped}' LIMIT 1`, false);
	const record = result.records[0];
	if(!record)
	{
		throw new Error(`Could not resolve a User record for ${username}`);
	}
	return {userId: record.Id, timeZone: record.TimeZoneSidKey || DEFAULT_TIME_ZONE, username};
}

/**
 * Builds one weighted bucket per hour of the seeding window. Weight follows the org user's local
 * clock, so weekday business hours carry far more rows than nights and weekends.
 * @param {number} windowDays - How many days back the corpus spreads.
 * @param {string} timeZone - IANA timezone of the seeding user.
 * @param {number} anchorMilliseconds - End of the window (exclusive).
 * @returns {{startMilliseconds: number[], cumulative: number[]}}
 */
function buildHourBuckets(windowDays, timeZone, anchorMilliseconds)
{
	const formatter = new Intl.DateTimeFormat('en-US', {timeZone, hour: 'numeric', hour12: false, weekday: 'short'});
	const totalHours = windowDays * 24;
	const startMilliseconds = [];
	const weights = [];
	for(let index = 0; index < totalHours; index++)
	{
		const bucketStart = anchorMilliseconds - (totalHours - index) * 3600000;
		const parts = formatter.formatToParts(new Date(bucketStart));
		const hour = Number.parseInt(parts.find((part) => part.type === 'hour').value, 10) % 24;
		const weekday = parts.find((part) => part.type === 'weekday').value;
		const isWeekend = weekday === 'Sat' || weekday === 'Sun';
		startMilliseconds.push(bucketStart);
		weights.push(HOUR_OF_DAY_WEIGHTS[hour] * (isWeekend ? WEEKEND_ACTIVITY_FACTOR : 1));
	}
	return {startMilliseconds, cumulative: buildCumulative(weights)};
}

/**
 * Draws a timestamp from the activity curve.
 * @param {{startMilliseconds: number[], cumulative: number[]}} buckets - The hourly curve.
 * @param {function(): number} random - Deterministic generator.
 * @returns {number} Milliseconds since the epoch.
 */
function drawTimestamp(buckets, random)
{
	const bucket = pickWeightedIndex(buckets.cumulative, random());
	return buckets.startMilliseconds[bucket] + Math.floor(random() * 3600000);
}

/**
 * Builds the heavy-tailed per-level signature pools and their cumulative weight tables.
 * @returns {object} Pools keyed by level.
 */
function buildSignaturePools()
{
	const pools = {};
	for(const {level} of LEVEL_WEIGHTS)
	{
		const members = [];
		SIGNATURES.forEach((signature, signatureIndex) =>
		{
			if(signature.level === level)
			{
				members.push({signature, signatureIndex});
			}
		});
		const weights = members.map((member, rank) => 1 / Math.pow(rank + 1, 1.1));
		pools[level] = {members, cumulative: buildCumulative(weights)};
	}
	return pools;
}

/**
 * Draws a duration in milliseconds with a long right tail: most calls are fast, a few are very slow.
 * @param {function(): number} random - Deterministic generator.
 * @returns {number} Duration in milliseconds.
 */
function drawDuration(random)
{
	const span = Math.log(MAXIMUM_DURATION_MILLISECONDS / MINIMUM_DURATION_MILLISECONDS);
	return Math.round(MINIMUM_DURATION_MILLISECONDS * Math.exp(Math.pow(random(), 1.6) * span));
}

/**
 * Builds an Apex-shaped stack trace of three to six frames rooted at the failing signature.
 * @param {object} signature - The signature that raised.
 * @param {function(): number} random - Deterministic generator.
 * @returns {string} A newline-separated stack trace.
 */
function buildStackTrace(signature, random)
{
	const frameCount = 3 + Math.floor(random() * 4);
	const frames = [`Class.${signature.className}.${signature.methodName}: line ${signature.lineNumber}, column 1`];
	let cursor = Math.floor(random() * CALLER_FRAMES.length);
	while(frames.length < frameCount)
	{
		const frame = CALLER_FRAMES[cursor % CALLER_FRAMES.length];
		frames.push(`Class.${frame.className}.${frame.methodName}: line ${frame.lineNumber}, column 1`);
		cursor++;
	}
	return frames.join('\n');
}

/**
 * Builds a plausible 18-character custom-object record id.
 * @param {function(): number} random - Deterministic generator.
 * @returns {string} The record id.
 */
function buildRecordIdentifier(random)
{
	const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
	let identifier = 'a0H5g00000';
	while(identifier.length < 18)
	{
		identifier += alphabet[Math.floor(random() * alphabet.length)];
	}
	return identifier;
}

/**
 * The UTC day bucket the framework encodes into a `rollup:` fingerprint.
 * @param {number} milliseconds - Timestamp.
 * @returns {string} `yyyyMMdd` in UTC.
 */
function toUtcDayBucket(milliseconds)
{
	return new Date(milliseconds).toISOString().slice(0, 10).replace(/-/g, '');
}

/**
 * Renders a timestamp as the ISO-8601 UTC form Bulk API 2.0 accepts.
 * @param {number} milliseconds - Timestamp.
 * @returns {string} For example `2026-07-20T14:03:11.000Z`.
 */
function toIsoUtc(milliseconds)
{
	return new Date(milliseconds).toISOString();
}

/**
 * Builds one plain forensic row from a drawn signature.
 * @param {object} options - Draw inputs.
 * @returns {object} The row.
 */
function buildForensicRow(options)
{
	const {signature, level, createdMilliseconds, transactionIdentifier, userId, random} = options;
	const row = {
		LogLevel__c: level,
		ShortMessage__c: signature.shortMessage,
		Message__c: signature.message,
		ClassMethod__c: `${signature.className}.${signature.methodName}`,
		Origin__c: 'APEX',
		Source__c: signature.className,
		LineNumber__c: signature.lineNumber,
		ExceptionType__c: signature.exceptionType ?? '',
		StackTrace__c: '',
		ExecutionEvent__c: '',
		TransactionId__c: transactionIdentifier,
		CorrelationId__c: '',
		ParentTransactionId__c: '',
		UserId__c: userId,
		DurationMs__c: drawDuration(random),
		Fingerprint__c: '',
		OccurrenceCount__c: '',
		RecordId__c: '',
		CreatedDate: createdMilliseconds,
		LastModifiedDate: createdMilliseconds
	};
	if(signature.exceptionType && random() < STACK_TRACE_SHARE_OF_ERRORS)
	{
		row.StackTrace__c = buildStackTrace(signature, random);
	}
	if(random() < RECORD_IDENTIFIER_SHARE)
	{
		row.RecordId__c = buildRecordIdentifier(random);
	}
	return row;
}

/**
 * Generates the whole corpus: plain forensic rows, correlated multi-hop transactions, and the
 * fingerprinted `detail:` / `rollup:` layer.
 * @param {object} options - Generation inputs.
 * @returns {{rows: object[], statistics: object}}
 */
function generateRows(options)
{
	const {rowCount, windowDays, randomSeed, timeZone, userId, anchorMilliseconds} = options;
	const random = createRandom(randomSeed);
	const buckets = buildHourBuckets(windowDays, timeZone, anchorMilliseconds);
	const pools = buildSignaturePools();
	const levelCumulative = buildCumulative(LEVEL_WEIGHTS.map((entry) => entry.weight));
	const executionEventCumulative = buildCumulative(EXECUTION_EVENT_WEIGHTS.map((entry) => entry.weight));
	const rows = [];
	const fingerprints = new Set();
	const statistics = {plain: 0, correlated: 0, correlationGroups: 0, detail: 0, rollup: 0, byLevel: {}};

	/**
	 * Draws a weighted execution context.
	 * @returns {string} The picklist value.
	 */
	function drawExecutionEvent()
	{
		return EXECUTION_EVENT_WEIGHTS[pickWeightedIndex(executionEventCumulative, random())].value;
	}

	/**
	 * Draws a level then a heavy-tailed signature inside that level.
	 * @returns {{level: string, signature: object, signatureIndex: number}}
	 */
	function drawSignature()
	{
		const level = LEVEL_WEIGHTS[pickWeightedIndex(levelCumulative, random())].level;
		const pool = pools[level];
		const member = pool.members[pickWeightedIndex(pool.cumulative, random())];
		return {level, signature: member.signature, signatureIndex: member.signatureIndex};
	}

	/**
	 * Records a row and its level tally.
	 * @param {object} row - The row to keep.
	 */
	function keep(row)
	{
		if(row.Fingerprint__c)
		{
			if(fingerprints.has(row.Fingerprint__c))
			{
				throw new Error(`Duplicate Fingerprint__c generated: ${row.Fingerprint__c}. Fingerprint__c is a unique external id, so the bulk load would fail.`);
			}
			fingerprints.add(row.Fingerprint__c);
		}
		statistics.byLevel[row.LogLevel__c] = (statistics.byLevel[row.LogLevel__c] ?? 0) + 1;
		rows.push(row);
	}

	// ---- The fingerprinted layer: one detail: sample per signature plus per-day rollup: counters. ----
	SIGNATURES.forEach((signature, signatureIndex) =>
	{
		const base = `${SIGNATURE_BASE_PREFIX}${signatureIndex}`;
		const firstSeenMilliseconds = drawTimestamp(buckets, random);
		const detailRow = buildForensicRow({
			signature,
			level: signature.level,
			createdMilliseconds: firstSeenMilliseconds,
			transactionIdentifier: `${SEED_MARKER}detail-${signatureIndex}`,
			userId,
			random
		});
		detailRow.ExecutionEvent__c = drawExecutionEvent();
		detailRow.Fingerprint__c = `detail:${base}`;
		keep(detailRow);
		statistics.detail++;

		const activeDayCount = MINIMUM_ROLLUP_DAYS_PER_SIGNATURE
				+ Math.floor(random() * (MAXIMUM_ROLLUP_DAYS_PER_SIGNATURE - MINIMUM_ROLLUP_DAYS_PER_SIGNATURE + 1));
		const usedDayBuckets = new Set();
		for(let attempt = 0; attempt < activeDayCount * 3 && usedDayBuckets.size < activeDayCount; attempt++)
		{
			const occurredMilliseconds = drawTimestamp(buckets, random);
			const dayBucket = toUtcDayBucket(occurredMilliseconds);
			if(usedDayBuckets.has(dayBucket))
			{
				continue;
			}
			usedDayBuckets.add(dayBucket);
			const occurrenceCount = MINIMUM_OCCURRENCE_COUNT
					+ Math.floor(Math.pow(random(), 2.2) * (MAXIMUM_OCCURRENCE_COUNT - MINIMUM_OCCURRENCE_COUNT));
			const lastOccurrenceMilliseconds = Math.min(occurredMilliseconds + Math.floor(random() * 12 * 3600000), anchorMilliseconds);
			keep({
				LogLevel__c: signature.level,
				ShortMessage__c: '',
				Message__c: '',
				ClassMethod__c: '',
				// The counter carries its detail sample's attribution, the way the trigger writes it.
				Origin__c: 'APEX',
				Source__c: signature.className,
				LineNumber__c: '',
				ExceptionType__c: '',
				StackTrace__c: '',
				ExecutionEvent__c: '',
				TransactionId__c: `${SEED_MARKER}rollup-${signatureIndex}-${dayBucket}`,
				CorrelationId__c: '',
				ParentTransactionId__c: '',
				UserId__c: '',
				DurationMs__c: '',
				Fingerprint__c: `rollup:${base}:${dayBucket}`,
				OccurrenceCount__c: occurrenceCount,
				RecordId__c: '',
				CreatedDate: occurredMilliseconds,
				LastModifiedDate: lastOccurrenceMilliseconds
			});
			statistics.rollup++;
		}
	});

	// ---- Correlated multi-hop transactions: a shared CorrelationId__c and a parent chain of hops. ----
	const correlatedTarget = Math.round(rowCount * CORRELATED_ROW_SHARE);
	let correlationIndex = 0;
	while(statistics.correlated < correlatedTarget && rows.length < rowCount)
	{
		const hopCount = MINIMUM_HOPS_PER_CORRELATION
				+ Math.floor(random() * (MAXIMUM_HOPS_PER_CORRELATION - MINIMUM_HOPS_PER_CORRELATION + 1));
		const correlationIdentifier = `${SEED_MARKER}corr-${correlationIndex}`;
		const executionEvent = drawExecutionEvent();
		let hopMilliseconds = drawTimestamp(buckets, random);
		for(let hop = 0; hop < hopCount && rows.length < rowCount; hop++)
		{
			const drawn = drawSignature();
			const row = buildForensicRow({
				signature: drawn.signature,
				level: drawn.level,
				createdMilliseconds: hopMilliseconds,
				transactionIdentifier: `${SEED_MARKER}${correlationIndex}-txn-${hop}`,
				userId,
				random
			});
			row.ExecutionEvent__c = hop === 0 ? executionEvent : drawExecutionEvent();
			row.CorrelationId__c = correlationIdentifier;
			if(hop > 0)
			{
				row.ParentTransactionId__c = `${SEED_MARKER}${correlationIndex}-txn-${hop - 1}`;
			}
			keep(row);
			statistics.correlated++;
			hopMilliseconds += 1000 + Math.floor(random() * 45000);
		}
		statistics.correlationGroups++;
		correlationIndex++;
	}

	// ---- The bulk of the corpus: plain forensic rows with a null fingerprint and no correlation. ----
	let plainIndex = 0;
	while(rows.length < rowCount)
	{
		const drawn = drawSignature();
		const row = buildForensicRow({
			signature: drawn.signature,
			level: drawn.level,
			createdMilliseconds: drawTimestamp(buckets, random),
			transactionIdentifier: `${SEED_MARKER}${plainIndex}`,
			userId,
			random
		});
		row.ExecutionEvent__c = drawExecutionEvent();
		keep(row);
		statistics.plain++;
		plainIndex++;
	}

	rows.sort((left, right) => left.CreatedDate - right.CreatedDate);
	return {rows, statistics};
}

/**
 * Escapes one CSV field per RFC 4180.
 * @param {string|number} value - Raw value.
 * @returns {string} The escaped field.
 */
function escapeCsvField(value)
{
	const text = value === null || value === undefined ? '' : String(value);
	if(text.includes(',') || text.includes('"') || text.includes('\n') || text.includes('\r'))
	{
		return `"${text.replace(/"/g, '""')}"`;
	}
	return text;
}

/**
 * Renders rows as a Bulk API 2.0 CSV chunk.
 * @param {object[]} rows - Rows to render.
 * @param {string} namespacePrefix - Field-name prefix.
 * @returns {string} The CSV text, LF line endings, trailing newline.
 */
function renderCsv(rows, namespacePrefix)
{
	const header = [...CSV_COLUMNS.map((column) => `${namespacePrefix}${column}`), ...AUDIT_COLUMNS].join(',');
	const lines = [header];
	for(const row of rows)
	{
		const fields = CSV_COLUMNS.map((column) => escapeCsvField(row[column]));
		fields.push(escapeCsvField(toIsoUtc(row.CreatedDate)));
		fields.push(escapeCsvField(toIsoUtc(row.LastModifiedDate)));
		lines.push(fields.join(','));
	}
	return `${lines.join('\n')}\n`;
}

/**
 * Writes the corpus out as numbered CSV chunks.
 * @param {object[]} rows - The whole corpus.
 * @param {object} options - Output options.
 * @returns {string[]} Chunk file paths in load order.
 */
function writeChunks(rows, options)
{
	const {chunkSize, namespacePrefix, outputDirectory} = options;
	const chunkPaths = [];
	for(let start = 0, chunkNumber = 1; start < rows.length; start += chunkSize, chunkNumber++)
	{
		const chunkPath = path.join(outputDirectory, `seed-log-volume-chunk-${String(chunkNumber).padStart(2, '0')}.csv`);
		writeFileSync(chunkPath, renderCsv(rows.slice(start, start + chunkSize), namespacePrefix), 'utf8');
		chunkPaths.push(chunkPath);
	}
	return chunkPaths;
}

/**
 * Loads one CSV chunk through Bulk API 2.0 and reports the job outcome.
 * @param {string} organisationAlias - Target org alias.
 * @param {string} sObjectName - Fully-prefixed object API name.
 * @param {string} chunkPath - CSV to load.
 * @param {string} logPath - File to receive the raw command output.
 * @returns {{jobId: string, processed: number, failed: number, state: string}}
 */
function importChunk(organisationAlias, sObjectName, chunkPath, logPath)
{
	const parsed = runSalesforceCommand([
		'data', 'import', 'bulk',
		'--sobject', sObjectName,
		'--file', chunkPath,
		'--line-ending', 'LF',
		'--wait', String(BULK_IMPORT_WAIT_MINUTES),
		'-o', organisationAlias,
		'--json'
	], logPath);
	const result = parsed.result ?? {};
	return {
		jobId: result.jobId ?? 'unknown',
		processed: Number(result.processedRecords ?? 0),
		succeeded: Number(result.successfulRecords ?? 0),
		failed: Number(result.failedRecords ?? 0),
		state: parsed.status === 0 ? 'JobComplete' : 'Failed'
	};
}

/**
 * The SOQL predicate that isolates every row this script created.
 * @param {string} namespacePrefix - Field-name prefix.
 * @returns {string} The WHERE clause body.
 */
function buildSeedPredicate(namespacePrefix)
{
	return `${namespacePrefix}TransactionId__c LIKE '${SEED_MARKER}%' OR ${namespacePrefix}Fingerprint__c LIKE '%${SEED_MARKER}%'`;
}

/**
 * Reads back the seeded corpus and proves the audit-field back-dating actually stuck.
 * @param {string} organisationAlias - Target org alias.
 * @param {string} namespacePrefix - Field-name prefix.
 * @param {number} windowDays - The requested spread in days.
 * @returns {{seededCount: number, totalCount: number, oldestCreatedDate: string|null, backDated: boolean, byLevel: object}}
 */
function verifySeed(organisationAlias, namespacePrefix, windowDays)
{
	const objectName = `${namespacePrefix}LogEntry__c`;
	const predicate = buildSeedPredicate(namespacePrefix);
	const seededCount = query(organisationAlias, `SELECT COUNT() FROM ${objectName} WHERE ${predicate}`, false).totalSize;
	const totalCount = query(organisationAlias, `SELECT COUNT() FROM ${objectName}`, false).totalSize;
	const oldest = query(organisationAlias, `SELECT CreatedDate FROM ${objectName} WHERE ${predicate} ORDER BY CreatedDate ASC LIMIT 1`, false);
	const oldestCreatedDate = oldest.records[0]?.CreatedDate ?? null;
	const levelRows = query(
		organisationAlias,
		`SELECT ${namespacePrefix}LogLevel__c logLevel, COUNT(Id) rowCount FROM ${objectName} WHERE ${predicate} GROUP BY ${namespacePrefix}LogLevel__c`,
		false
	).records;
	const byLevel = {};
	for(const record of levelRows)
	{
		byLevel[record.logLevel ?? '(none)'] = Number(record.rowCount);
	}
	const ageDays = oldestCreatedDate ? (Date.now() - Date.parse(oldestCreatedDate)) / 86400000 : 0;
	return {seededCount, totalCount, oldestCreatedDate, backDated: ageDays >= windowDays - 1, byLevel, oldestAgeDays: ageDays};
}

/**
 * Deletes every seeded log row through Bulk API 2.0, in chunks, and reports what went.
 * @param {object} options - Teardown inputs.
 * @returns {{removed: number, jobs: object[]}}
 */
function teardownLogRows(options)
{
	const {organisationAlias, namespacePrefix, outputDirectory, chunkSize} = options;
	const objectName = `${namespacePrefix}LogEntry__c`;
	const predicate = buildSeedPredicate(namespacePrefix);
	const before = query(organisationAlias, `SELECT COUNT() FROM ${objectName} WHERE ${predicate}`, false).totalSize;
	if(before === 0)
	{
		return {removed: 0, jobs: [], before: 0, after: 0};
	}
	const exportPath = path.join(outputDirectory, 'teardown-seed-volume-ids.csv');
	if(existsSync(exportPath))
	{
		unlinkSync(exportPath);
	}
	runSalesforceCommand([
		'data', 'export', 'bulk',
		'-q', `SELECT Id FROM ${objectName} WHERE ${predicate}`,
		'--output-file', exportPath,
		'--result-format', 'csv',
		'--line-ending', 'LF',
		'--wait', String(BULK_EXPORT_WAIT_MINUTES),
		'-o', organisationAlias,
		'--json'
	], path.join(outputDirectory, 'teardown-export.json'));

	// `sf data export bulk` writes CRLF regardless of --line-ending, so normalise before re-chunking:
	// a stray carriage return makes the delete job reject the file with a LineEnding ClientInputError.
	const exported = readFileSync(exportPath, 'utf8').replace(/\r/g, '').split('\n').filter((line) => line.trim().length > 0);
	const header = exported.shift();
	const jobs = [];
	for(let start = 0, chunkNumber = 1; start < exported.length; start += chunkSize, chunkNumber++)
	{
		const chunkPath = path.join(outputDirectory, `teardown-seed-volume-ids-${String(chunkNumber).padStart(2, '0')}.csv`);
		writeFileSync(chunkPath, `${[header, ...exported.slice(start, start + chunkSize)].join('\n')}\n`, 'utf8');
		const parsed = runSalesforceCommand([
			'data', 'delete', 'bulk',
			'--sobject', objectName,
			'--file', chunkPath,
			'--line-ending', 'LF',
			'--wait', String(BULK_DELETE_WAIT_MINUTES),
			'-o', organisationAlias,
			'--json'
		], path.join(outputDirectory, `teardown-delete-${String(chunkNumber).padStart(2, '0')}.json`));
		const result = parsed.result ?? {};
		jobs.push({
			jobId: result.jobId ?? 'unknown',
			processed: Number(result.processedRecords ?? 0),
			succeeded: Number(result.successfulRecords ?? 0),
			failed: Number(result.failedRecords ?? 0),
			state: parsed.status === 0 ? 'JobComplete' : 'Failed'
		});
	}
	const after = query(organisationAlias, `SELECT COUNT() FROM ${objectName} WHERE ${predicate}`, false).totalSize;
	return {removed: before - after, jobs, before, after};
}

/**
 * Removes the chain executions and marker records left by `seed-chain-scenarios.sh`. Only marker
 * records created at or after the recorded chain-seed start time are touched, so the e2e battery's
 * own `Foobar__c` rows survive.
 * @param {object} options - Teardown inputs.
 * @returns {{chainsRemoved: number, markersRemoved: number, since: string|null, skippedMarkers: boolean}}
 */
function teardownChainScenarios(options)
{
	const {organisationAlias, namespacePrefix, outputDirectory, since} = options;
	const chainObject = `${namespacePrefix}AsyncChainExecution__c`;
	const foobarObject = `${namespacePrefix}Foobar__c`;
	const namePatterns = FOOBAR_NAME_PATTERNS.map((pattern) => `Name LIKE '${pattern}'`).join(' OR ');
	const apexLines = [
		`List<SObject> chains = Database.query('SELECT Id FROM ${chainObject} WHERE ${namespacePrefix}ChainName__c LIKE \\'${CHAIN_NAME_MARKER}\\' LIMIT 9000');`,
		'if(!chains.isEmpty())',
		'{',
		'\tdelete chains;',
		'}',
		'Integer markerCount = 0;'
	];
	if(since)
	{
		apexLines.push(
			`Datetime seedStart = (Datetime)JSON.deserialize('"${since}"', Datetime.class);`,
			`List<SObject> markers = Database.query('SELECT Id FROM ${foobarObject} WHERE (${namePatterns}) AND CreatedDate >= :seedStart LIMIT 9000');`,
			'markerCount = markers.size();',
			'if(!markers.isEmpty())',
			'{',
			'\tdelete markers;',
			'}'
		);
	}
	apexLines.push('System.debug(\'TEARDOWN_SEED chains=\' + chains.size() + \' markers=\' + markerCount);');
	const apexPath = path.join(outputDirectory, 'teardown-chain-scenarios.apex');
	writeFileSync(apexPath, `${apexLines.join('\n')}\n`, 'utf8');
	const logPath = path.join(outputDirectory, 'teardown-chain-scenarios.json');
	const parsed = runSalesforceCommand(['apex', 'run', '-o', organisationAlias, '-f', apexPath, '--json'], logPath);
	const logs = parsed.result?.logs ?? '';
	const match = logs.match(/TEARDOWN_SEED chains=(\d+) markers=(\d+)/);
	return {
		chainsRemoved: match ? Number(match[1]) : 0,
		markersRemoved: match ? Number(match[2]) : 0,
		since: since ?? null,
		skippedMarkers: !since
	};
}

/**
 * Reads the start time the chain seeder recorded, so marker teardown never reaches older rows.
 * @param {string} outputDirectory - Where the seeders write their evidence.
 * @returns {string|null} An ISO-8601 timestamp, or null when no chain seed ran.
 */
function readChainSeedStart(outputDirectory)
{
	const explicit = readFlag('since', null);
	if(explicit && explicit !== true)
	{
		return String(explicit);
	}
	const statePath = path.join(outputDirectory, CHAIN_SEED_STATE_FILE);
	if(!existsSync(statePath))
	{
		return null;
	}
	try
	{
		return JSON.parse(readFileSync(statePath, 'utf8')).startedAt ?? null;
	}
	catch(error)
	{
		return null;
	}
}

/**
 * Entry point.
 * @returns {void}
 */
function main()
{
	const organisationAlias = String(readFlag('org', process.env.SF_SUBSCRIBER_ORG_ALIAS || DEFAULT_ORGANISATION_ALIAS));
	const outputDirectory = String(readFlag('output-directory', DEFAULT_OUTPUT_DIRECTORY));
	const rowCount = readNumericFlag('rows', DEFAULT_ROW_COUNT);
	const windowDays = readNumericFlag('days', DEFAULT_WINDOW_DAYS);
	const chunkSize = readNumericFlag('chunk', DEFAULT_CHUNK_SIZE);
	const randomSeed = readNumericFlag('seed', DEFAULT_RANDOM_SEED);
	const isDryRun = readFlag('dry-run', false) !== false;
	const isTeardown = readFlag('teardown', false) !== false;

	mkdirSync(outputDirectory, {recursive: true});
	const startedAtMilliseconds = Date.now();
	const namespacePrefix = resolveNamespacePrefix(organisationAlias);
	console.log(`Org ${organisationAlias} — namespace prefix '${namespacePrefix}'`);

	if(isTeardown)
	{
		const logResult = teardownLogRows({organisationAlias, namespacePrefix, outputDirectory, chunkSize});
		const chainResult = teardownChainScenarios({
			organisationAlias,
			namespacePrefix,
			outputDirectory,
			since: readChainSeedStart(outputDirectory)
		});
		console.log('');
		console.log('=== Teardown ===');
		console.log(`Seeded log rows before : ${logResult.before}`);
		console.log(`Seeded log rows after  : ${logResult.after}`);
		for(const job of logResult.jobs)
		{
			console.log(`  delete job ${job.jobId} state=${job.state} processed=${job.processed} succeeded=${job.succeeded} failed=${job.failed}`);
		}
		console.log(`Chain executions removed : ${chainResult.chainsRemoved}`);
		const markerScope = chainResult.skippedMarkers
				? '(skipped — no chain-seed start time; pass --since <iso>)'
				: `(created on or after ${chainResult.since})`;
		console.log(`Marker records removed   : ${chainResult.markersRemoved} ${markerScope}`);
		if(logResult.after !== 0)
		{
			console.error(`TEARDOWN INCOMPLETE: ${logResult.after} seeded log rows remain.`);
			process.exit(1);
		}
		console.log(`Wall time: ${Math.round((Date.now() - startedAtMilliseconds) / 1000)}s`);
		return;
	}

	const seedUser = resolveSeedUser(organisationAlias);
	console.log(`Seeding as ${seedUser.username} (${seedUser.userId}), timezone ${seedUser.timeZone}`);

	const anchorMilliseconds = Math.floor(startedAtMilliseconds / 60000) * 60000;
	const {rows, statistics} = generateRows({
		rowCount,
		windowDays,
		randomSeed,
		timeZone: seedUser.timeZone,
		userId: seedUser.userId,
		anchorMilliseconds
	});
	const chunkPaths = writeChunks(rows, {chunkSize, namespacePrefix, outputDirectory});

	console.log('');
	console.log('=== Generated ===');
	console.log(`Rows                : ${rows.length}`);
	console.log(`  plain forensic    : ${statistics.plain}`);
	console.log(`  correlated hops   : ${statistics.correlated} across ${statistics.correlationGroups} correlations`);
	console.log(`  detail: samples   : ${statistics.detail}`);
	console.log(`  rollup: counters  : ${statistics.rollup}`);
	console.log(`Levels              : ${Object.entries(statistics.byLevel).map(([level, count]) => `${level} ${count}`).join(', ')}`);
	console.log(`Window              : ${windowDays} days back from ${toIsoUtc(anchorMilliseconds)}`);
	console.log(`Chunks              : ${chunkPaths.length}`);
	for(const chunkPath of chunkPaths)
	{
		console.log(`  ${chunkPath} (${Math.round(statSync(chunkPath).size / 1024)} KB)`);
	}

	if(isDryRun)
	{
		console.log('');
		console.log('Dry run — nothing was loaded. Inspect the CSV chunks above, then re-run without --dry-run.');
		return;
	}

	// Fingerprint__c is a unique external id, so a second seed run on top of an un-torn-down first one
	// would fail mid-job and leave a half-loaded corpus. Refuse before any data moves.
	const existing = query(
		organisationAlias,
		`SELECT COUNT() FROM ${namespacePrefix}LogEntry__c WHERE ${buildSeedPredicate(namespacePrefix)}`,
		false
	).totalSize;
	if(existing > 0)
	{
		console.error('');
		console.error(`REFUSING TO LOAD: ${existing} rows from an earlier seed run are still in ${organisationAlias}.`);
		console.error(`Run \`node release-testing/scripts/seed-log-volume.mjs --org ${organisationAlias} --teardown\` first.`);
		process.exit(1);
	}

	console.log('');
	console.log('=== Bulk load ===');
	const jobs = [];
	for(let index = 0; index < chunkPaths.length; index++)
	{
		const logPath = path.join(outputDirectory, `seed-log-volume-import-${String(index + 1).padStart(2, '0')}.json`);
		const job = importChunk(organisationAlias, `${namespacePrefix}LogEntry__c`, chunkPaths[index], logPath);
		jobs.push(job);
		console.log(`chunk ${index + 1}/${chunkPaths.length}  job ${job.jobId}  state=${job.state}  processed=${job.processed}  succeeded=${job.succeeded}  failed=${job.failed}`);
		if(job.failed > 0 || job.state !== 'JobComplete')
		{
			console.error(`Bulk job ${job.jobId} did not complete cleanly. Inspect ${logPath} and \`sf data bulk results --job-id ${job.jobId} -o ${organisationAlias}\`.`);
			process.exit(1);
		}
	}

	const verification = verifySeed(organisationAlias, namespacePrefix, windowDays);
	console.log('');
	console.log('=== Verification ===');
	console.log(`Seeded rows in org  : ${verification.seededCount}`);
	console.log(`All log rows in org : ${verification.totalCount}`);
	console.log(`Oldest seeded row   : ${verification.oldestCreatedDate} (${verification.oldestAgeDays.toFixed(1)} days old)`);
	console.log(`Levels in org       : ${Object.entries(verification.byLevel).map(([level, count]) => `${level} ${count}`).join(', ')}`);
	console.log(`Wall time           : ${Math.round((Date.now() - startedAtMilliseconds) / 1000)}s`);

	if(!verification.backDated)
	{
		console.error('');
		console.error('AUDIT BACK-DATING FAILED: the oldest seeded row is not close to the requested window, so every row landed at "now".');
		console.error('Apply the RUNBOOK Phase 1.4 recipe (two separate deploys, then assign KernE2EAuditFieldAccess), tear this run down, and seed again.');
		process.exit(1);
	}
}

main();
