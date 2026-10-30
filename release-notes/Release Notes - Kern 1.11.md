# Kern 1.11 Release Notes

**Platform:** Salesforce API 68.0 (Winter '27) · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** released. Kern 1.11.0-1 is the production-installable 1.11 line.

## The headlines

> **What you need to do after the upgrade**
>
> Most of 1.11 works when you upgrade, with nothing to do. Check these, in case one applies to you:
>
> 1. **If you copied a `kern.QRY_Builder` example that reads totals with `toList()`:** change it to `toAggregateList()`. In a
>    test that registers aggregate rows, `toList()` throws. [Details](#other-changes)
> 2. **If a test of yours checks the exact text of a Health Check or query builder message:** update the text it expects. Six
>    messages have plainer wording. [Details](#other-changes)
> 3. **If you want the new wording on two fields:** an upgrade keeps the earlier help text on API Call Status and API Setting
>    Mocking Enabled. An administrator can edit it in Setup. [Details](#other-changes)
> 4. **If you want the new Kern app description:** an upgrade keeps the earlier text. An administrator can edit it in Setup, in
>    App Manager. [Details](#other-changes)
> 5. **If your Jest tests use `jest.mock('c/...')` or `jest.mock('lightning/...')`:** add the ESLint rule
>    `kerndx/no-jest-mock-component-module` to your lint setup to find the mocks that can stop working.
>    [Details](#a-code-scanning-check-for-jest-mocks-that-stop-working)

**KernDX is now open source under the Apache License 2.0.** Nothing changes in how you install or use KernDX. If you pass a
copy on, include the licence, as the last point below says.

- From 1.11, KernDX is under the Apache License 2.0, an open-source licence approved by the Open Source Initiative (OSI). It
  carries a patent grant: everyone who contributes code gives you a licence to any of their patents that code uses.
- You can use KernDX for anything, including inside a product you sell that does what KernDX does. The limit on competing
  products that the earlier licence had is gone.
- Versions 1.10 and earlier keep the licence they were published with, the Business Source License 1.1. Each becomes Apache 2.0
  no later than four years after it was first published.
- When you give a copy to someone else, pass the licence on: include the `LICENSE` file and the KernDX notice at the top of
  `NOTICES.md`, and mark each file you changed.

Read more: [what the licence allows, in plain words](../LICENSING.md).

## Turn a feature flag off in a test

**New: `kern.TST_Factory.newDisabledFeatureFlag(String flagName)` turns a feature flag off for the rest of a test.** Use it to
test the code a flag turns off, including for a flag your org ships switched on.

- Until now a test could turn a flag on but had no way to turn one off. A flag your org ships on stayed on in every test,
  unless you deleted or switched off the real record.
- After the call, `kern.UTIL_FeatureFlag.isEnabled(flagName)` returns `false` in that test, whatever the deployed record says.

Read more: [Testing the Disabled Path](../docs/Feature%20Flags%20-%20Guide.md#testing-the-disabled-path) in the Feature Flags
guide.

## Fixes

**Nothing to do for any of these.** Each fix applies when you upgrade.

- **`kern.DML_Builder.TransactionResult.getFailureCount()` no longer ends the transaction.** A save that
  `suppressExceptions()` turned into a failed result could end the whole transaction when you asked it how many records
  failed, if the error came from Apex code rather than from the platform. It now returns a number: every record in the save
  counts as failed, because the whole save was rolled back. An error the platform raised still returns its own row count.
- **A masking rule in JsonKey mode (one that masks the value under a named JSON key) finds a long key name in a long value.**
  The quick check that decides whether a long JSON value can hold a key your rule names missed a key name longer than 64
  characters when it crossed one of the points where the value is split for searching, so the value under it was not masked.
  Key names up to 512 characters are now always found. The shipped rules match key names of at most 13 characters, so this
  matters only for a rule of your own.
- **Clearing the create form also clears what it would save.** The form emptied its fields on screen but kept the values
  behind them, so a cleared form could still save them.
- **The scheduled job editor window opens for an admin who cannot read the job runner fields.** An admin whose permission set
  was made before 1.10 cannot see Execution Mode, Run Priority or Overlap Policy, and the window failed to load for them. It
  now opens, and saving keeps the job's stored values for those three fields.
- **For that admin, the window checks the cron expression with Salesforce's own scheduling rules,** because it cannot tell
  whether the job runs on the job runner. If the job does, the window can refuse a minutes pattern such as `*/15` that the job
  runner accepts. When the job saves, the server still checks the expression with the rules for the way the job runs.
- **The cron editor refuses a day name it does not know.** It accepted names such as `XYZ`, `MON,XYZ`, `XYZ-ABC` and `XYZ#1`,
  and the weekly picker loaded a range the checker refuses, such as `6-2`. An unknown day name is now refused wherever it
  stands, and the picker loads only an expression the checker accepts.

## The pipeline command line

**New: `kerndx init --answers-file <path>` sets up the pipeline without asking questions,** so a CI job or a script can run
it. The file holds the same answers the questions ask for, as JSON.

- Every answer is checked before anything is written. A file is either accepted, and gives exactly what the questions would
  for the same choices, or refused with a message that names the file and the answer.
- `init` now builds every file first and writes them only when all of them built, so a bad answer leaves your repository as
  it was.

Read more: [running `init` without questions](../pipeline/README.md#install) in the pipeline README.

## A code-scanning check for Jest mocks that stop working

**New: the KernDX ESLint plugin's `kerndx/no-jest-mock-component-module` rule flags `jest.mock('c/...')` and
`jest.mock('lightning/...')` in your Jest tests.** Such a mock can silently stop replacing the module when an earlier test
file in the same Jest worker has loaded the real one. The test then checks a mock nothing calls: it can fail at random, or
pass while checking nothing.

- The ESLint snippet in the pipeline bundle's install guide (`INSTALL-PIPELINE.md`) adds the rule as a warning, so your lint
  does not fail on tests you already have. Add it the same way to your own ESLint configuration. Fix the tests it flags,
  then raise it to `error` if you want.
- To fix a flagged test, watch the real module with `jest.spyOn`, check what the component sends out instead of what the
  mock received, or map the module to a mock file with `moduleNameMapper` in your Jest configuration.

Read more: [Code Scanning](../docs/Code%20Scanning%20-%20Guide.md) guide.

## Other changes

- **Plainer wording in Health Check, query errors and two help texts.** The three Health Check messages about API mocking, the
  query builder's message for a field name it refuses, its two messages about reading without sharing, and the help text of
  API Call Status and API Setting Mocking Enabled now say the same things in plainer words. If you compare Health Check output
  or these messages with earlier text, expect the new wording. The two help texts change on a new install only: an upgrade
  does not change a field's help text, so an upgraded org keeps the earlier help text on those two fields. If you want the
  new text, an administrator can edit the help text in Setup: API Call Status under Object Manager, API Call, and Mocking
  Enabled under Custom Metadata Types, API Setting.

- **A new logo for the Kern app, on a new install.** A new install shows a warm-white K on a flat deep copper square, and the
  docs site's tab icon matches it. The old copper gradient made the K hard to read in its light corner (a contrast of 2.5 to
  1); the new logo reads at 8.9 to 1. An upgrade does not replace the app's logo, so an org that upgrades from an earlier
  version keeps the copper gradient. Nothing to do.

- **The Kern app's description names KernDX, on a new install.** In the App Launcher it reads "Monitor API calls, review
  logs, manage scheduled jobs, and configure KernDX." instead of ending "configure the Kern framework". An upgrade does not
  change the app's description, so an upgraded org keeps the earlier text. If you want the new text, an administrator can
  edit the Kern app's description in Setup, in App Manager.

- **The query builder's aggregate examples now use `toAggregateList()`.** Thirteen examples in the `kern.QRY_Builder`
  reference read totals and grouped results with `toList()` into a `List<AggregateResult>`. That is not how the builder
  reads them: in a test that registers aggregate rows, `toList()` throws. The examples now call `toAggregateList()` and read
  each value from a `kern.QRY_Builder.AggregateRow` by its alias, for example `rows[0].getInteger('count_Id')`. If you
  copied one of the old examples, change it the same way.

- **The bundled d3 file now carries its licence notice.** The package still contains the d3 charting library as a static
  resource, although nothing in KernDX loads it any more. d3's licence asks that its copyright line and permission notice
  appear in every copy; earlier packages kept only the copyright line. From 1.11 the file opens with the full notice. Nothing
  to do.

- **The KernDX ESLint plugin now carries its licence text.** The plugin under `scanner/eslint-plugin-kerndx/` is under the
  MIT License, like the pipeline, but it shipped without the licence text. It now has its own `LICENSE` file, and
  the pipeline bundle includes the MIT text of both the pipeline and the plugin. [`LICENSING.md`](../LICENSING.md) says which
  licence covers which part. Nothing to do.
