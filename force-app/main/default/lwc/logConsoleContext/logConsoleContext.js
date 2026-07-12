// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Shared execution-context (Quiddity) display mapping for the Log Console. The raw enum
 * value stays the filter, sort and wire value; only the displayed text comes from a Custom Label. The
 * console list and the correlation chain strip both read this single source, so the friendly context
 * names never drift between the two surfaces.
 *
 * @author Jason van Beukering
 *
 * @date June 2026
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