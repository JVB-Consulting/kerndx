// SPDX-License-Identifier: Apache-2.0
// The "Methods by task" table on a class reference page: the methods of the class sorted into
// groups by what you want to do, each group linked to a worked example in a guide when one
// exists. A group with no worked example says so with exampleLink: null. Pure; no filesystem access.
//
// The reference generator copies ApexDoc into Markdown and keeps no tag of its own on a method,
// so a group comes from the method name. The rules are tried in order and the first match wins;
// a name that no rule matches goes to "Other". The alphabetical method list on the page is left
// as it is, so every existing anchor keeps working.

import {slugifyHeading} from './anchor-normalizer.mjs';
import {pathForTarget} from './reference-links.mjs';

const SELECTORS_GUIDE = 'Selectors - Guide';
const OTHER = 'Other';

// The groups of QRY_Builder.Builder, in the order the table shows them. `names` lists whole
// method names; `prefix` matches the start of a name, for example "asMap" or "toCursor".
// "Count and total" is tried before "Sort and limit" so that orderByCount counts. An exampleLink
// may name a `secondHeading` on the same page, for a group whose methods two sections explain.
const QUERY_BUILDER_GROUPS = Object.freeze([
	{
		group: 'Choose fields',
		names: ['fields', 'fieldSet', 'addField', 'addFields', 'addFieldSet', 'relatedField', 'relatedFields', 'selectAllFields', 'subselect', 'getDefaultFields'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'SELECT and FROM'}
	},
	{
		group: 'Filter records',
		names: ['condition', 'andCondition', 'orCondition', 'addCondition', 'allRows', 'usingScope', 'withDataCategory'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'WHERE Conditions'}
	},
	{
		group: 'Sort and limit',
		names: ['orderBy', 'ascending', 'descending', 'nullsFirst', 'nullsLast', 'withLimit', 'withOffset'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'ORDER BY and LIMIT'}
	},
	{
		group: 'Count and total',
		names: ['count', 'countDistinct', 'sum', 'avg', 'min', 'max', 'groupBy', 'grouping', 'rollup', 'cube', 'orderByCount'],
		prefix: /^having[A-Z]/,
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Aggregate Functions'}
	},
	{
		group: 'Run the query',
		names: ['getFirst', 'getFirstAggregate', 'getPage', 'getRandomItem', 'getRandomItems', 'exists'],
		prefix: /^(?:to(?!Soql$)|as)[A-Z]/,
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Result Transformation'}
	},
	{
		group: 'Security and row locking',
		names: ['bypassSharing', 'withSharing', 'withSystemMode', 'withUserMode', 'withoutSecurity', 'stripInaccessible', 'forUpdate', 'forView', 'forReference'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Security & Row Locking'}
	},
	{
		group: OTHER,
		names: [],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Caching Queries', secondHeading: 'Query Performance Logging'}
	}
]);

// The order in which the tried rules are matched against a name (see the note on the list).
const MATCH_ORDER = Object.freeze(['Count and total', 'Choose fields', 'Filter records', 'Sort and limit', 'Run the query', 'Security and row locking']);

const UTILITIES_GUIDE = 'Utilities - Guide';
const WEB_SERVICES_GUIDE = 'Web Services - Guide';
const DML_GUIDE = 'DML - Guide';
const OUTBOUND_FAST_START = 'Fast Start - Outbound APIs';
const RESILIENCE_GUIDE = 'Resilience - Guide';

// The groups of the other classes. Each method of today is named in one group, so no rule
// overlaps another and the groups are tried in table order. The last group, Other, holds no
// method today: it catches a method added later, until someone gives it a group.
const DESCRIBE_GROUPS = Object.freeze([
	{
		group: 'Find an object',
		names: ['getDescribe', 'getSObjectType', 'getSObjectTypeById', 'getSObjectTypeByName', 'getObjectNameFromId', 'getObjectNameFromType', 'getGlobalDescribe', 'getRawGlobalDescribe'],
		exampleLink: {page: UTILITIES_GUIDE, heading: 'Global Describe Operations', secondHeading: 'Helper Methods'}
	},
	{
		group: 'Read fields and field sets',
		names: [
			'getField', 'getFields', 'getFieldsMap', 'getFieldDescribe', 'getFieldName', 'getCachedFieldDescribe', 'getCachedFieldName', 'getNameField', 'getAllFieldNames',
			'getSObjectFieldNames', 'extractValidObjectFieldNames', 'getObjectFieldMap', 'getObjectFieldReferenceMap', 'getNestableFieldNames', 'getFieldSetsMap'
		],
		exampleLink: {page: UTILITIES_GUIDE, heading: 'Field Operations', secondHeading: 'Field Set Operations'}
	},
	{
		// No guide has a worked example for picklists or record types, so the row has no link.
		group: 'Read picklists and record types',
		names: ['getPicklistValues', 'getPicklistValuesByRecordType', 'getPicklistEntries', 'getPicklistEntriesMap', 'getDefaultPicklistValue', 'getDefaultRecordType', 'getRecordTypeByDeveloperName', 'isRecordTypeAvailable'],
		exampleLink: null
	},
	{
		group: 'Check the org and free memory',
		names: ['isPersonAccountEnabled', 'flushCache'],
		exampleLink: {page: UTILITIES_GUIDE, heading: 'Helper Methods', secondHeading: 'Cache Management'}
	},
	{group: OTHER, names: [], exampleLink: {page: UTILITIES_GUIDE, heading: 'Metadata Introspection (UTIL_SObjectDescribe)'}}
]);

const REQUEST_BUILDER_GROUPS = Object.freeze([
	{
		group: 'Build the request',
		names: ['credential', 'method', 'path', 'pathParam', 'queryParam', 'header', 'headers', 'body', 'timeout'],
		exampleLink: {page: OUTBOUND_FAST_START, heading: 'Builder Features'}
	},
	{
		group: 'Send it and read the answer',
		names: ['send', 'asString', 'asMap', 'deserialize'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'UTIL_HttpClient (Fluent HTTP Client)', secondHeading: 'Status code is 0'}
	},
	{
		group: 'Retry, or stop calling a failing system',
		names: ['withRetry', 'withExponentialBackoff', 'retryOn', 'withCircuitBreaker', 'onFailure'],
		exampleLink: {page: RESILIENCE_GUIDE, heading: 'Per-Call Overrides with UTIL_HttpClient'}
	},
	{
		group: 'Hand the call to your own handler class',
		names: ['invoke', 'withParameter', 'withParameters', 'withTriggeringRecord'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'UTIL_HttpClient (Fluent HTTP Client)', secondHeading: 'How do I find the calls made for one record?'}
	},
	{
		group: 'Test the call, or set its IDs and logging',
		names: ['withMockResponse', 'skipLogging', 'withCorrelationId', 'withIdempotencyKey'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Mock Mode and API_MockFactory'}
	},
	{
		// No guide has a worked example for these methods, so the row has no link.
		group: 'Replace words in the request or answer body',
		names: ['replaceRequestToken', 'replaceRequestTokens', 'replaceResponseToken', 'replaceResponseTokens'],
		exampleLink: null
	},
	{group: OTHER, names: [], exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'UTIL_HttpClient (Fluent HTTP Client)'}}
]);

const OUTBOUND_GROUPS = Object.freeze([
	{
		group: 'Gather the data before the call',
		names: ['configure', 'getRequiredInputs', 'prepareRequest'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Minimal Implementation', secondHeading: 'Complete Real-World Example: REST POST with DML'}
	},
	{
		group: 'Shape the request',
		names: [
			'getWebServiceEndPoint', 'getHttpMethod', 'getQueryParameters', 'setHeaders', 'getAuthorisationToken', 'getEncoding', 'getTimeout', 'getBody',
			'getRequestReplacementTokens', 'createRequest'
		],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Outbound-Specific Methods (API_Outbound)'}
	},
	{
		group: 'Read the answer',
		names: ['parseResponse', 'getResponseBody', 'getResponseReplacementTokens', 'hasArrayResponse'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'getResponseBody()', secondHeading: 'getResponseReplacementTokens()'}
	},
	{
		group: 'Retry a failed call',
		names: ['createRetryStrategy', 'getRetryableStatusCodes', 'getRetryableExceptionTypes'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Custom Retry Strategies', secondHeading: 'Failures and retries'}
	},
	{
		group: 'Switch the call off',
		names: ['isDisabled'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Disabling APIs'}
	},
	{
		// No guide has a worked example for the save hooks, so the row has no link.
		group: 'Run your own code when the save starts or ends',
		names: ['onCommitWorkStarting'],
		exampleLink: null
	},
	{group: OTHER, names: [], exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Building Outbound APIs'}}
]);

// Every UTIL_Limits method has its worked example in the one section of the guide on this class.
const LIMITS_EXAMPLE = Object.freeze({page: UTILITIES_GUIDE, heading: 'UTIL_Limits'});

const LIMITS_GROUPS = Object.freeze([
	{
		group: 'Queries, searches and cursors',
		names: [
			'soqlQueries', 'soqlQueryRows', 'soqlQueryLocatorRows', 'aggregateQueries', 'soslQueries', 'apexCursors', 'apexCursorRows', 'fetchCallsOnApexCursor',
			'apexPaginationCursors', 'apexPaginationCursorRows'
		],
		exampleLink: LIMITS_EXAMPLE
	},
	{group: 'Saves and published events', names: ['dmlStatements', 'dmlRows', 'publishImmediateDml'], exampleLink: LIMITS_EXAMPLE},
	{group: 'Callouts, email and push notifications', names: ['callouts', 'emailInvocations', 'mobilePushApexCalls'], exampleLink: LIMITS_EXAMPLE},
	{group: 'Background jobs', names: ['queueableJobs', 'futureCalls'], exampleLink: LIMITS_EXAMPLE},
	{group: 'CPU time and memory', names: ['cpuTime', 'heapSize'], exampleLink: LIMITS_EXAMPLE},
	{group: 'Every limit at once', names: ['snapshot', 'toDebugString'], exampleLink: LIMITS_EXAMPLE},
	{group: OTHER, names: [], exampleLink: LIMITS_EXAMPLE}
]);

const SELECTOR_GROUPS = Object.freeze([
	{
		group: 'Find records by Id or by a field',
		names: ['findById', 'findByIdOrThrow', 'findByField', 'findByFields', 'findFirstByField', 'findFirstByFields'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'findById', secondHeading: 'findByField'}
	},
	{
		group: 'Read every record the selector covers',
		names: ['toList', 'getFirst', 'getRandomItem', 'count', 'exists', 'toQueryLocator'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Existence Checks', secondHeading: 'QueryLocator for Batch Apex'}
	},
	{
		group: 'Set up your selector',
		names: ['getFields', 'getFieldPaths', 'systemModeRequired'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Custom Selector Classes', secondHeading: 'Switching a selector, or the whole framework, to system mode'}
	},
	{
		group: 'Cache every read',
		names: ['cacheScope', 'cacheTimeToLiveSeconds'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Caching every read from a selector'}
	},
	{group: OTHER, names: [], exampleLink: {page: SELECTORS_GUIDE, heading: 'Layer 2: SEL_Base'}}
]);

const CONDITION_GROUPS = Object.freeze([
	{
		group: 'Compare with one value',
		names: ['equals', 'notEquals', 'greaterThan', 'greaterThanOrEquals', 'lessThan', 'lessThanOrEquals', 'isNull', 'isNotNull'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Query with Single Condition'}
	},
	{
		group: 'Match a list of values, or the results of another query',
		names: ['isIn', 'isInStrict', 'notInSet', 'notInSetStrict', 'notIn'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Using IN Operator with Collection', secondHeading: 'Semi-Join Subqueries'}
	},
	{
		group: 'Match part of a text',
		names: ['contains', 'startsWith', 'endsWith'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'String Pattern Matching', secondHeading: 'Searching for text a person typed'}
	},
	{
		group: 'Filter a multi-select picklist',
		names: ['includes', 'includesStrict', 'excludes', 'excludesStrict'],
		exampleLink: {page: SELECTORS_GUIDE, heading: 'Multi-Picklist Field Filtering'}
	},
	{group: OTHER, names: [], exampleLink: {page: SELECTORS_GUIDE, heading: 'WHERE Conditions'}}
]);

const INBOUND_GROUPS = Object.freeze([
	{
		group: 'Read the request',
		names: ['configure', 'getHttpMethod', 'getEncoding', 'parseRequest'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Minimal Inbound Example', secondHeading: 'Reading a request header'}
	},
	{
		group: 'Do the work',
		names: ['processRequest', 'onSuccess'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'processRequest()', secondHeading: 'onSuccess()'}
	},
	{
		group: 'Answer the caller, or report a failure',
		names: ['updateCallResult', 'updateResponseDTO', 'writeResponse', 'handleError'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'writeResponse()', secondHeading: 'When a request fails'}
	},
	{
		group: 'Switch the API off',
		names: ['isDisabled'],
		exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Disabling APIs'}
	},
	{
		// No guide has a worked example for the save hooks, so the row has no link.
		group: 'Run your own code when the save starts or ends',
		names: ['onCommitWorkStarting', 'onCommitWorkFinishing'],
		exampleLink: null
	},
	{group: OTHER, names: [], exampleLink: {page: WEB_SERVICES_GUIDE, heading: 'Building Inbound APIs'}}
]);

const DML_GROUPS = Object.freeze([
	{
		group: 'Register records and save them',
		names: ['newTransaction', 'doInsert', 'doUpdate', 'doUpsert', 'doDelete', 'doUndelete', 'execute', 'async'],
		exampleLink: {page: DML_GUIDE, heading: 'Transactional DML Pattern (DML_Builder)', secondHeading: 'Mixed Operations and Rollback'}
	},
	{
		group: 'Handle records that fail to save',
		names: ['allowPartial', 'expectRefusal', 'withRetryOnLock', 'suppressExceptions', 'suppressLogging'],
		exampleLink: {page: DML_GUIDE, heading: 'Logging a refusal you expect below ERROR', secondHeading: 'Retrying When Another Transaction Holds the Row'}
	},
	{
		group: 'Choose security and sharing',
		names: ['withUserMode', 'withSystemMode', 'bypassSharing'],
		exampleLink: {page: DML_GUIDE, heading: 'Operation-Level Sharing', secondHeading: 'Access Mode (USER_MODE / SYSTEM_MODE)'}
	},
	{group: OTHER, names: [], exampleLink: {page: DML_GUIDE, heading: 'Transactional DML Pattern (DML_Builder)'}}
]);

// One class's grouping: its groups in table order, and the order in which their rules are
// tried against a method name. Other is never tried: a name no rule matches goes there.
function classGrouping(groups, matchOrder = groups.map(g => g.group).filter(name => name !== OTHER))
{
	return Object.freeze({groups, matchOrder: Object.freeze(matchOrder)});
}

// The classes that have a "Methods by task" table, by page file name without .md.
export const GROUPS_BY_CLASS = Object.freeze({
	'QRY_Builder.Builder': classGrouping(QUERY_BUILDER_GROUPS, MATCH_ORDER),
	'UTIL_SObjectDescribe': classGrouping(DESCRIBE_GROUPS),
	'UTIL_HttpClient.RequestBuilder': classGrouping(REQUEST_BUILDER_GROUPS),
	'API_Outbound': classGrouping(OUTBOUND_GROUPS),
	'UTIL_Limits': classGrouping(LIMITS_GROUPS),
	'SEL_Base': classGrouping(SELECTOR_GROUPS),
	'QRY_Builder.ConditionBuilder': classGrouping(CONDITION_GROUPS),
	'API_Inbound': classGrouping(INBOUND_GROUPS),
	'DML_Builder': classGrouping(DML_GROUPS)
});

// The group names of QRY_Builder.Builder, in table order.
export const GROUP_NAMES = Object.freeze(QUERY_BUILDER_GROUPS.map(g => g.group));

function groupNameFor({groups, matchOrder}, name)
{
	for(const groupName of matchOrder)
	{
		const rule = groups.find(r => r.group === groupName);
		if(rule && (rule.names.includes(name) || rule.prefix?.test(name)))
		{
			return groupName;
		}
	}
	return OTHER;
}

// The methods of a class sorted into groups: [{group, members, exampleLink}], in table order,
// with each method in exactly one group and the methods of a group kept in the order given.
// A group with no method is left out. A class with no grouping gets an empty list. A group whose
// exampleLink is null gets an empty object, which has no page: the build reads exampleLink.page
// on every group, finds no such page and leaves the cell empty.
export function groupMembers(className, members)
{
	const grouping = Object.hasOwn(GROUPS_BY_CLASS, className) ? GROUPS_BY_CLASS[className] : null;
	if(!grouping)
	{
		return [];
	}
	const membersByGroup = new Map(grouping.groups.map(r => [r.group, []]));
	for(const name of members)
	{
		membersByGroup.get(groupNameFor(grouping, name)).push(name);
	}
	return grouping.groups
	.filter(r => membersByGroup.get(r.group).length)
	.map(r => ({group: r.group, members: membersByGroup.get(r.group), exampleLink: {...r.exampleLink}}));
}

// The method names of a class page, in page order, each once: the "###" headings of the
// "## Methods" section. Constructors and properties have their own sections and are not read.
export function methodNamesOf(body)
{
	const start = body.search(/^## Methods[ \t]*$/m);
	if(start === -1)
	{
		return [];
	}
	const rest = body.slice(start).replace(/^## Methods[^\n]*\n/, '');
	const end = rest.search(/^## /m);
	const section = end === -1 ? rest : rest.slice(0, end);
	return [...new Set([...section.matchAll(/^### (\S+)[ \t]*$/gm)].map(m => m[1]))];
}

// The "Worked example" cell: a link to the heading, then a link to the second heading on the
// same page when the group has one (Other holds both the caching and the performance-logging
// methods). A null exampleLink, or one with no page, gives an empty cell.
function exampleCell(exampleLink)
{
	if(!exampleLink?.page)
	{
		return '';
	}
	const target = pathForTarget(exampleLink.page);
	const headings = exampleLink.secondHeading ? [exampleLink.heading, exampleLink.secondHeading] : [exampleLink.heading];
	return headings.map(heading => `[${heading}](${target}#${slugifyHeading(heading)})`).join(', ');
}

// The "Methods by task" section for a list of groups: one row per group, each method linked to
// its detail on the same page. An empty list gives no section. A group whose exampleLink is
// null gets an empty "Worked example" cell.
export function renderGroupTable(groups)
{
	if(!groups.length)
	{
		return '';
	}
	const rows = groups.map(({group, members, exampleLink}) =>
	{
		const methods = members.map(name => `[\`${name}\`](#${slugifyHeading(name)})`).join(' ');
		return `| **${group}** | ${methods} | ${exampleCell(exampleLink)} |`;
	});
	return [
		'## Methods by task',
		'',
		'Find a method by what you want to do. A group links to a worked example when a guide has one. Every method is described in the full list below.',
		'',
		'| Group | Methods | Worked example |',
		'|-------|---------|----------------|',
		...rows,
		''
	].join('\n');
}

// The page body with the section placed straight before "## Methods". A body with no method
// list, or an empty section, is returned as it was.
export function insertGroupTable(body, table)
{
	if(!table)
	{
		return body;
	}
	return body.replace(/^## Methods[ \t]*$/m, (heading) => `${table}\n${heading}`);
}
