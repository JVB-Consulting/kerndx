// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Suppressed component — extends LightningElement with justified eslint-disable.
 * Used by release-testing scanner validation (RUNBOOK §2.3d).
 */
import {LightningElement} from 'lwc';

// eslint-disable-next-line kerndx/use-component-builder -- scanner test: validates suppression works
export default class ScannerTestSuppressed extends LightningElement
{
}