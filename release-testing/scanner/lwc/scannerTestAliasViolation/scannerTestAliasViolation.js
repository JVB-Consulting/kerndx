// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate violation — imports LightningElement with an alias to test
 * that the scanner catches aliased imports, not just the literal name.
 * Used by release-testing scanner validation (RUNBOOK §2.3d).
 *
 * Expected violations:
 * - kerndx/use-component-builder (x1: extends aliased LightningElement)
 */
import {LightningElement as BaseElement} from 'lwc';

export default class ScannerTestAliasViolation extends BaseElement
{
}
