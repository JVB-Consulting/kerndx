// SPDX-License-Identifier: Apache-2.0
/**
 * @description Shared display mapping for the Log Console: the execution context (Quiddity) a request ran
 * under, the origin choices the Origin filter offers, the label each stored origin shows under, and the
 * marker a problem written under more than one origin carries. The raw enum value stays the filter, sort
 * and wire value; only the displayed text comes from a Custom Label. The console list, the detail drawer
 * and the correlation chain strip all read this single source, so the friendly names never drift between
 * the surfaces.
 *
 * @author Jason van Beukering
 *
 * @date June 2026, October 2026
 */
import contextBatchApex from '@salesforce/label/c.LogConsole_ContextBatchApex';
import contextQueueable from '@salesforce/label/c.LogConsole_ContextQueueable';
import contextQueueableFinalizer from '@salesforce/label/c.LogConsole_ContextQueueableFinalizer';
import contextScheduled from '@salesforce/label/c.LogConsole_ContextScheduled';
import contextFuture from '@salesforce/label/c.LogConsole_ContextFuture';
import contextAura from '@salesforce/label/c.LogConsole_ContextAura';
import contextRest from '@salesforce/label/c.LogConsole_ContextRest';
import contextSynchronous from '@salesforce/label/c.LogConsole_ContextSynchronous';
import contextAnonymous from '@salesforce/label/c.LogConsole_ContextAnonymous';
import originFramework from '@salesforce/label/c.LogConsole_OriginFramework';
import originApex from '@salesforce/label/c.LogConsole_OriginApex';
import originFlow from '@salesforce/label/c.LogConsole_OriginFlow';
import originComponent from '@salesforce/label/c.LogConsole_OriginComponent';
import originMixed from '@salesforce/label/c.LogConsole_OriginMixed';

// Readable execution-context (Quiddity) display names, sourced from Custom Labels.
export const CONTEXT_CHOICES = [
	{value: 'BATCH_APEX', label: contextBatchApex},
	{value: 'QUEUEABLE', label: contextQueueable},
	{value: 'TRANSACTION_FINALIZER_QUEUEABLE', label: contextQueueableFinalizer},
	{value: 'SCHEDULED', label: contextScheduled},
	{value: 'FUTURE', label: contextFuture},
	{value: 'AURA', label: contextAura},
	{value: 'REST', label: contextRest},
	{value: 'SYNCHRONOUS', label: contextSynchronous},
	{value: 'ANONYMOUS', label: contextAnonymous}
];

// Lookup from raw Quiddity value to its friendly label, used to render the displayed context name.
export const CONTEXT_LABEL_BY_VALUE = Object.fromEntries(CONTEXT_CHOICES.map((choice) => [
	choice.value,
	choice.label
]));

// The value the problems fold returns for a signature written under more than one origin; a display value only.
export const ORIGIN_MIXED = 'MIXED';

// Who wrote an entry, as the Origin filter offers it and the badge names it.
export const ORIGIN_CHOICES = [
	{value: 'FRAMEWORK', label: originFramework},
	{value: 'APEX', label: originApex},
	{value: 'FLOW', label: originFlow},
	{value: 'COMPONENT', label: originComponent}
];

// Lookup from a stored origin value (or MIXED) to its friendly label.
export const ORIGIN_LABEL_BY_VALUE = Object.fromEntries(ORIGIN_CHOICES.map((choice) => [
	choice.value,
	choice.label
]).concat([
	[
		ORIGIN_MIXED,
		originMixed
	]
]));
