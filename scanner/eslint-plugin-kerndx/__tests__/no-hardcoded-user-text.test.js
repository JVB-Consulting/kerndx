// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const {RuleTester} = require('eslint');
const rule = require('../rules/no-hardcoded-user-text');

const ruleTester = new RuleTester({parserOptions: {ecmaVersion: 2022, sourceType: 'module'}});

test('no-hardcoded-user-text', () =>
{
	ruleTester.run('no-hardcoded-user-text', rule, {
		valid: [
			// --- Labels are the sanctioned source of user text ---
			{
				code: 'import LABEL from \'@salesforce/label/c.ScheduledJob_SaveFailed\';', name: 'a Custom Label import is not flagged'
			},
			{
				code: 'this.showErrorToast(SAVE_FAILED_LABEL);', name: 'a label variable passed to a toast is allowed'
			},
			{
				code: 'this.showSuccessToast(formatTemplateString(SAVED_LABEL, [count]));', name: 'formatTemplateString of a label is allowed'
			},
			// --- No literal to flag ---
			{
				code: 'this.showErrorToast(reduceErrors(error));', name: 'a reduced-error variable is allowed'
			},
			{
				code: 'throw new Error(errorMessage);', name: 'throwing a variable message is allowed'
			},
			// --- Exempt contexts: logs, events, DOM plumbing, format tokens ---
			{
				code: 'utilityLogger.error(\'Failed to load blank platform event\', {objectName});', name: 'a multi-word logger message is not user-facing'
			},
			{
				code: 'this.consoleLog(\'rendered the streaming table now\');', name: 'a ComponentBuilder console message is not user-facing'
			},
			{
				code: 'this.dispatchEvent(new CustomEvent(\'subscribeall\'));', name: 'a CustomEvent name is not user-facing'
			},
			{
				code: 'SUCCESS_TOAST.replace(\'{0}\', insertedIds.length);', name: 'a {0} format token in replace() is not user-facing'
			},
			{
				code: 'element.setAttribute(\'data-mode\', \'table\');', name: 'a data-attribute plumbing value is not user-facing'
			},
			// --- Token-shaped literals are never display copy ---
			{
				code: 'const icon = \'utility:refresh\';', name: 'an SLDS icon token is not display text'
			},
			{
				code: 'const css = \'slds-var-p-around_small\';', name: 'an SLDS class token is not display text'
			},
			{
				code: 'import {formatTemplateString} from \'c/utilityString\';', name: 'a module specifier is not display text'
			},
			{
				code: 'const fmt = \'M/d/yyyy h:mm a\';', name: 'a date/time format token is not display text'
			},
			// --- Space-separated CSS class lists are not display copy ---
			{
				code: 'const css = \'slds-modal slds-fade-in-open\';', name: 'an SLDS class list (hyphenated tokens) is not display text'
			},
			{
				code: 'const dot = \'icon-dot icon-dot_active\';', name: 'an all-hyphenated class list is not display text'
			},
			{
				code: 'const row = {rowClass: isFocused ? \'tent focused\' : \'tent\'};', name: 'a *Class property value (even plain-word) is not display text'
			},
			{
				code: 'const c = buildClassString(\'slds-modal slds-fade-in-open\', modifiers);', name: 'a class-string builder argument is not display text'
			},
			// --- Non-display multi-word strings (comparisons, plumbing, lookups) ---
			{
				code: 'if (this.status === \'In Progress\') { work(); }', name: 'an equality comparison against a picklist value is not display text'
			},
			{
				code: 'const payload = {detail: \'the user did something here\'};', name: 'a plumbing (detail) property value is not display text'
			},
			{
				code: 'element.innerHTML = \'Some Rendered Markup Here\';', name: 'an innerHTML assignment is not display text'
			},
			{
				code: 'cache.get(\'some cache key value\');', name: 'a Map.get lookup key is not display text'
			},
			// --- Single-word literals are ambiguous (enum/variant/api) — the heuristic leaves them to the sweep ---
			{
				code: 'const variant = \'error\';', name: 'a single-word literal is not flagged by the heuristic'
			},
			{
				code: 'this.dispatchEvent(new ShowToastEvent({title, message, variant: \'error\', mode: \'sticky\'}));',
				name: 'variable title/message + enum variant/mode are allowed'
			}
		],

		invalid: [
			// --- Toast sinks ---
			{
				code: 'this.showSuccessToast(\'Execution completed successfully\');', name: 'a hardcoded success-toast message is caught', errors: [{messageId: 'hardcodedInSink'}]
			},
			{
				code: 'this.showErrorToast(\'Failed to copy to clipboard\');', name: 'a hardcoded error-toast message is caught', errors: [{messageId: 'hardcodedInSink'}]
			},
			{
				code: 'this.showErrorToast(reduceErrors(error) || \'Failed to load record\');',
				name: 'a hardcoded fallback inside a || is caught',
				errors: [{messageId: 'hardcodedInSink'}]
			},
			{
				code: 'this.showSuccessToast(this.isCreateMode ? \'Scheduled job created\' : \'Scheduled job saved\');',
				name: 'both branches of a ternary toast arg are caught',
				errors: [
					{messageId: 'hardcodedInSink'},
					{messageId: 'hardcodedInSink'}
				]
			},
			{
				code: 'this.dispatchEvent(new ShowToastEvent({title: \'Warning\', message: \'Something happened here\', variant: \'warning\'}));',
				name: 'hardcoded ShowToastEvent title and message are caught',
				errors: [
					{messageId: 'hardcodedInSink'},
					{messageId: 'hardcodedInSink'}
				]
			},
			{
				code: 'throw new Error(\'Something bad happened while saving\');', name: 'a hardcoded thrown Error message is caught', errors: [{messageId: 'hardcodedInSink'}]
			},
			{
				code: 'this.showErrorToast(`Failed to save ${recordName}`);', name: 'an interpolated toast template literal is caught', errors: [{messageId: 'hardcodedInSink'}]
			},
			{
				code: 'const mode = \'Read-only mode\';', name: 'a hyphenated compound display phrase is caught by the heuristic', errors: [{messageId: 'hardcodedDisplayText'}]
			},
			// --- Display-text heuristic (const / getter feeding a template binding) ---
			{
				code: 'const WAITING = \'Waiting for events to arrive\';',
				name: 'a multi-word display const is caught by the heuristic',
				errors: [{messageId: 'hardcodedDisplayText'}]
			},
			{
				code: 'class Editor { get cardTitle() { return \'New Scheduled Job\'; } }',
				name: 'a multi-word getter display string is caught by the heuristic',
				errors: [{messageId: 'hardcodedDisplayText'}]
			},
			{
				code: 'this.emptyStateMessage = \'No events displayed. Try changing your filters.\';',
				name: 'a multi-word display assignment is caught by the heuristic',
				errors: [{messageId: 'hardcodedDisplayText'}]
			}
		]
	});
});
