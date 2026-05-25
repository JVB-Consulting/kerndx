// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate violations — extends LightningElement instead of ComponentBuilder,
 * and uses console.log instead of ComponentBuilder's consoleLog.
 * Used by release-testing scanner validation (RUNBOOK §2.3d).
 *
 * Expected violations:
 * - kerndx/use-component-builder (x1: extends LightningElement)
 * - kerndx/no-console-log (x3: console.log, window.console.warn, globalThis.console.error)
 */
import {LightningElement} from 'lwc';

export default class ScannerTestViolation extends LightningElement
{
	connectedCallback()
	{
		console.log('Should use this.consoleLog() from ComponentBuilder');
		window.console.warn('window.console bypass should also be caught');
		globalThis.console.error('globalThis.console bypass should also be caught');
	}
}