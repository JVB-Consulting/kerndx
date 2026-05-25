// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Compliant component — extends ComponentBuilder instead of LightningElement.
 * Used by release-testing scanner validation (RUNBOOK §2.3d).
 */
import {ComponentBuilder} from 'c/componentBuilder';

export default class ScannerTestCompliant extends ComponentBuilder('notification')
{
}