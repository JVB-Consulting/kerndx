// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate LWC naming violation — missing domain prefix.
 * Used to validate kerndx/enforce-component-naming ESLint rule.
 *
 * Expected violations:
 * - kerndx/enforce-component-naming (x1: no domain prefix, should be ordReturnWizard)
 * - kerndx/use-component-builder (x1: extends LightningElement)
 */
import {LightningElement} from 'lwc';

export default class ReturnWizard extends LightningElement
{
}
