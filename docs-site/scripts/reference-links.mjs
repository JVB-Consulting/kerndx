// SPDX-License-Identifier: Apache-2.0
// The "Learn it" line on each Apex reference page: one short line that links the class to its Fast
// Start and its developer guide. Pure; no filesystem access.
//
// The filename prefix of a class gives a default (see DOMAIN_LINKS), and CLASS_OVERRIDES corrects
// the classes that a prefix points at the wrong guide, or that no guide teaches. A class with no
// true Fast Start or guide gets no line at all, never a wrong one.

import {APEX_PREFIX_DOMAIN} from './generate-nav.mjs';
import {slugForPath} from './slug.mjs';

const TRIGGERS = Object.freeze({fastStart: 'Fast Start - Trigger Actions', guide: 'Triggers - Guide'});
const SELECTORS = Object.freeze({fastStart: 'Fast Start - Selectors', guide: 'Selectors - Guide'});
const DML = Object.freeze({fastStart: 'Fast Start - DML', guide: 'DML - Guide'});
const LOGGING = Object.freeze({fastStart: 'Fast Start - Logging', guide: 'Logging - Guide'});
const TEST_DATA = Object.freeze({fastStart: 'Fast Start - Test Data', guide: 'Test Data - Guide'});
const INBOUND = Object.freeze({fastStart: 'Fast Start - Inbound APIs', guide: 'Web Services - Guide'});
const OUTBOUND = Object.freeze({fastStart: 'Fast Start - Outbound APIs', guide: 'Web Services - Guide'});
const ASYNC = Object.freeze({fastStart: 'Fast Start - Async Processing', guide: 'Async Processing - Guide'});
const SCHEDULED = Object.freeze({fastStart: 'Fast Start - Scheduled Jobs', guide: 'Async Processing - Guide'});
const RESILIENCE = Object.freeze({fastStart: 'Fast Start - Resilience', guide: 'Resilience - Guide'});
const FEATURE_FLAGS = Object.freeze({fastStart: 'Fast Start - Feature Flags', guide: 'Feature Flags - Guide'});
const VALIDATION = Object.freeze({fastStart: 'Fast Start - Custom Validations', guide: 'Validation - Guide'});
const ASYNC_GUIDE = Object.freeze({guide: 'Async Processing - Guide'});
const WEB_SERVICES_GUIDE = Object.freeze({guide: 'Web Services - Guide'});
const DTOS_GUIDE = Object.freeze({guide: 'DTOs - Guide'});
const UTILITIES_GUIDE = Object.freeze({guide: 'Utilities - Guide'});
const VALIDATION_GUIDE = Object.freeze({guide: 'Validation - Guide'});
const SECURITY_GUIDE = Object.freeze({guide: 'Security - Guide'});
const TRIGGERS_GUIDE = Object.freeze({guide: 'Triggers - Guide'});
const LOGGING_GUIDE = Object.freeze({guide: 'Logging - Guide'});
const NONE = Object.freeze({});

// What a class gets from the sidebar domain of its prefix (APEX_PREFIX_DOMAIN). A domain that is
// not listed here (Flow Actions, Controllers, Interfaces) has no default.
const DOMAIN_LINKS = Object.freeze({
	'Triggers': TRIGGERS,
	'Query & Selectors': SELECTORS,
	'DML & Unit of Work': DML,
	'APIs & Services': WEB_SERVICES_GUIDE,
	'Logging': LOGGING,
	'Async & Scheduling': SCHEDULED,
	'Data Transfer Objects': DTOS_GUIDE,
	'Utilities': UTILITIES_GUIDE,
	'Testing': TEST_DATA
});

// The classes whose prefix default is wrong, or that need their own answer. The key is the outer
// class name; an inner class uses its outer class. Each value names the target pages (by file
// name, without .md). NONE means that no Fast Start or guide teaches the class, so it has no line.
export const CLASS_OVERRIDES = Object.freeze({
	// APIs & Services: a Web Services page, with the Fast Start for the side (in or out) it serves.
	API_Dispatcher: INBOUND,
	API_Inbound: INBOUND,
	API_InboundTestHelper: INBOUND,
	REST_Echo: INBOUND,
	API_Outbound: OUTBOUND,
	API_OutboundTestHelper: OUTBOUND,
	API_MockFactory: OUTBOUND,
	// The Omnistudio helper is described in the Utilities guide, not in a Web Services page.
	SVC_Omnistudio: UTILITIES_GUIDE,

	// Async and scheduling: the built-in jobs are explained in the Async Processing guide only.
	// The Fast Start teaches how to write your own job.
	SCHED_ChainWatchdog: ASYNC_GUIDE,
	SCHED_DeactivateUsers: ASYNC_GUIDE,
	SCHED_JobRunner: ASYNC_GUIDE,
	SCHED_PerformBatchedCallouts: ASYNC_GUIDE,
	SCHED_ProcessLoginHistory: ASYNC_GUIDE,
	SCHED_PurgeRecords: ASYNC_GUIDE,
	// These two bulk processors are not in any guide.
	PROC_ExecuteDML: NONE,
	PROC_UpdateFields: NONE,

	// Queries: the call log selector belongs to the Web Services story.
	SEL_ApiCall: WEB_SERVICES_GUIDE,

	// Triggers: the framework's own object triggers are not taught by the trigger guides, which
	// show how to write your own. The two that serve a feature are filed with that feature.
	TRG_ApiCall: NONE,
	TRG_ApiIssue: NONE,
	TRG_AsyncChainExecution: NONE,
	TRG_BatchApexErrorEvent: NONE,
	TRG_ScheduledJob: NONE,
	TRG_ExecuteValidationRules: VALIDATION,
	TRG_LogEntryEvent: LOGGING_GUIDE,

	// Flow actions have no default: each goes to the guide that explains the feature it serves.
	FLOW_BypassTrigger: TRIGGERS_GUIDE,
	FLOW_CheckTriggerBypassed: TRIGGERS_GUIDE,
	FLOW_BypassValidation: VALIDATION_GUIDE,
	FLOW_ClearValidationBypass: VALIDATION_GUIDE,
	FLOW_ExecuteValidationRules: VALIDATION_GUIDE,
	FLOW_CallApi: OUTBOUND,
	FLOW_CallApiAsync: WEB_SERVICES_GUIDE,
	FLOW_RetryApiIssues: WEB_SERVICES_GUIDE,
	FLOW_CheckFeatureFlag: FEATURE_FLAGS,
	FLOW_CheckObjectPermissions: {guide: 'DML - Guide'},
	FLOW_LoggerStart: LOGGING_GUIDE,
	FLOW_LoggerLog: LOGGING_GUIDE,
	FLOW_LoggerEnd: LOGGING_GUIDE,
	FLOW_WriteLog: LOGGING_GUIDE,
	FLOW_SendEmail: UTILITIES_GUIDE,
	FLOW_GetPicklistValues: NONE,

	// Interfaces have no default: each goes to the guide of the feature it belongs to.
	IF_Async: ASYNC_GUIDE,
	IF_Chain: ASYNC_GUIDE,
	IF_Schedulable: ASYNC_GUIDE,
	IF_Search: {guide: 'LWC - Guide'},
	IF_Trigger: TRIGGERS,
	IF_Queryable: NONE,
	IF_TableDataSource: NONE,

	// Data transfer objects: these two serve another feature.
	DTO_FlowValidationError: VALIDATION_GUIDE,
	DTO_ScheduledParameterDefinition: SCHEDULED,
	MAP_SObject: UTILITIES_GUIDE,

	// Testing: this mock stands in for a Flow in trigger action tests.
	TST_InvokeFlowMock: TRIGGERS,

	// Utilities: the name starts with UTIL_, but these belong to another feature.
	UTIL_AsyncChain: ASYNC,
	UTIL_AsynchronousJobLauncher: ASYNC_GUIDE,
	UTIL_BulkUpdates: {guide: 'DML - Guide'},
	UTIL_CircuitBreaker: RESILIENCE,
	UTIL_Retry: RESILIENCE,
	UTIL_HttpClient: OUTBOUND,
	UTIL_FeatureFlag: FEATURE_FLAGS,
	UTIL_FormulaContext: VALIDATION_GUIDE,
	UTIL_ValidationRule: VALIDATION,
	UTIL_ValidationTestHelper: VALIDATION,
	UTIL_SObjectBuilderDefaultProvider: {guide: 'Test Data - Guide'},
	UTIL_SessionEncryption: SECURITY_GUIDE,
	UTIL_Sharing: SECURITY_GUIDE
});

// The file name of a class page without the extension, cut at the first dot: the outer class.
function outerClassName(fileBase)
{
	const dot = fileBase.indexOf('.');
	return dot === -1 ? fileBase : fileBase.slice(0, dot);
}

// The Fast Start and guide for a class page, as the names of the target pages (without .md).
// Either key may be missing; an empty object means that the page gets no line. `fileBase` is the
// page file name without .md, for example "QRY_Builder" or "QRY_Builder.Builder".
export function linksForClass(fileBase)
{
	const outer = outerClassName(fileBase);
	if(Object.hasOwn(CLASS_OVERRIDES, outer))
	{
		return {...CLASS_OVERRIDES[outer]};
	}
	const prefix = outer.match(/^([A-Za-z0-9]+_)/)?.[1];
	return {...(DOMAIN_LINKS[APEX_PREFIX_DOMAIN[prefix]] ?? NONE)};
}

// Every page name that a table entry can point at, so a test can check each is a real page.
export function allLinkTargets()
{
	const entries = [...Object.values(DOMAIN_LINKS), ...Object.values(CLASS_OVERRIDES)];
	return [...new Set(entries.flatMap(links => [links.fastStart, links.guide].filter(Boolean)))].sort();
}

// The site path of a target page.
export function pathForTarget(name)
{
	return `/${slugForPath(`${name}.md`)}`;
}

function guideLabel(name)
{
	return `${name.replace(/ - Guide$/, '')} guide`;
}

// The line for a page: "Learn it: [Fast Start - Selectors](/fast-start-selectors) and
// [Selectors guide](/selectors-guide)". Empty when the class has neither.
export function renderLinkLine(links)
{
	const parts = [];
	if(links.fastStart)
	{
		parts.push(`[${links.fastStart}](${pathForTarget(links.fastStart)})`);
	}
	if(links.guide)
	{
		parts.push(`[${guideLabel(links.guide)}](${pathForTarget(links.guide)})`);
	}
	return parts.length ? `Learn it: ${parts.join(' and ')}` : '';
}

// The page body with the line placed straight after the heading and the line that names the kind
// of page (for example "**Class** · Group: ..."), before the declaration. A body with no heading
// is returned as it was.
export function insertLinkLine(body, line)
{
	if(!line)
	{
		return body;
	}
	return body.replace(/^(#[ \t]+[^\n]*\n\n(?:\*\*[^\n]*\n\n)?)/m, (opening) => `${opening}${line}\n\n`);
}

// True for a page that gets a line: a class, interface or enum page of the Apex reference. The
// area landing page, and the object, event and custom metadata pages, do not.
export function isApexClassPage(relPath)
{
	return /^reference\/apex\/(?!index\.md$)[^/]+\.md$/i.test(relPath);
}
