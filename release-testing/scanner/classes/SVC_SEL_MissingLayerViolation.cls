// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate subscriber naming violation — has domain prefix but double-layer
 * (SVC is domain AND layer here, SEL is layer, so SVC_SEL_ looks valid but is actually
 * Domain_Layer_ already). This class tests that the naming regex correctly parses segments.
 *
 * This class IS valid — SVC (domain) + SEL (layer) + MissingLayerViolation (name).
 * Used as a compliant control alongside actual violations.
 */
public with sharing class SVC_SEL_MissingLayerViolation
{
}
