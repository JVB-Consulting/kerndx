// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate subscriber name-length violation — exceeds 40-character limit.
 * Used to validate SubscriberApexNameLength PMD rule.
 *
 * Expected violations:
 * - SubscriberApexNameLength (x1: 42 characters, exceeds 40-char limit)
 * - (Also passes SubscriberApexClassNaming since the pattern is valid)
 */
public with sharing class ORD_CTRL_VeryLongClassNameThatExceedsLimit
{
}
