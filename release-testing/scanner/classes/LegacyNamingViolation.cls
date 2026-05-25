// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate subscriber naming violation — class name lacks Domain_Layer_ prefix.
 * Used to validate SubscriberApexClassNaming PMD rule.
 *
 * Expected violations:
 * - SubscriberApexClassNaming (x1: missing Domain_Layer_ prefix)
 */
public with sharing class LegacyNamingViolation
{
}
