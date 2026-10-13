# Kern 1.4 Release Notes

**Builds on:** [Kern 1.3 Release Notes](./Release%20Notes%20-%20Kern%201.3.md), [Kern 1.2 Release Notes](./Release%20Notes%20-%20Kern%201.2.md), [Kern 1.1 Release
Notes](./Release%20Notes%20-%20Kern%201.1.md), and the [Kern 1.0 Feature Reference](./Release%20Notes%20-%20Kern%201.0.md), which together remain the full reference for
everything 1.4 carries forward.
**Platform:** Salesforce API 67.0 (Summer '26), unchanged from 1.3 · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** the 1.4 feature set is complete, the build is validated, and end-to-end testing has passed. The package version id and release tag below are published with
the release.

> **What's new since 1.3**, grouped by capability and ordered by impact. 1.4 is a quality release: it makes the framework's user interface translatable end to end, and it fixes a
> set of correctness defects found by a systematic sweep of every Lightning component, headlined by an async-chain fix for a defect that could mark a healthy chain as Failed.
>
> **Safe to upgrade:** 1.4 is **backward-compatible**. The Apex API and the metadata surface are purely additive: no global member is removed or changed in signature, no object,
> field, tab, or permission changes, and the 359 new Custom Labels only add to what shipped in 1.3. A handful of deliberate behaviour changes are worth a read before you upgrade;
> they are summarised under [Upgrading & compatibility](#upgrading--compatibility). For the per-build log, see the CHANGELOG.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [At a glance](#at-a-glance)
2. [Translate the framework's UI: display strings are now Custom Labels](#translate-the-frameworks-ui-display-strings-are-now-custom-labels)
3. [Async chains: no more spurious failures from long step logs](#async-chains-no-more-spurious-failures-from-long-step-logs)
4. [Chain Monitor: live refresh in every deploy, not just managed installs](#chain-monitor-live-refresh-in-every-deploy-not-just-managed-installs)
5. [Record forms: failed saves are reported, explicit values survive](#record-forms-failed-saves-are-reported-explicit-values-survive)
6. [Silent failures eliminated across the admin screens](#silent-failures-eliminated-across-the-admin-screens)
7. [Streaming Monitor: the event timeline no longer depends on D3](#streaming-monitor-the-event-timeline-no-longer-depends-on-d3)
8. [Lookups: harder to break, easier to trust](#lookups-harder-to-break-easier-to-trust)
9. [Scheduled Jobs editor: defaults count, stale parameters pruned](#scheduled-jobs-editor-defaults-count-stale-parameters-pruned)
10. [Smaller fixes](#smaller-fixes)
11. [Upgrading & compatibility](#upgrading--compatibility)

</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Translatable UI](#translate-the-frameworks-ui-display-strings-are-now-custom-labels)** | Admins · International teams | Display strings across 26 component bundles now come from Custom Labels, ready for Translation Workbench |
| 2 | **[Async-chain failure fix](#async-chains-no-more-spurious-failures-from-long-step-logs)** | Developers · Admins | A continue-on-error chain no longer flips to Failed just because its accumulated step messages grew long |
| 3 | **[Chain Monitor live refresh](#chain-monitor-live-refresh-in-every-deploy-not-just-managed-installs)** | Admins · Developers | Real-time refresh now works in unmanaged and renamed-namespace deploys, and only chain events trigger it |
| 4 | **[Record forms you can trust](#record-forms-failed-saves-are-reported-explicit-values-survive)** | Admins · End users | A blocked save now shows an error instead of looking saved; explicit 0, false, and empty values persist as-is |
| 5 | **[No more silent failures](#silent-failures-eliminated-across-the-admin-screens)** | Admins | Clipboard copies, retention updates, and scheduled-job saves report their failures instead of pretending success |
| 6 | **[Native SVG event timeline](#streaming-monitor-the-event-timeline-no-longer-depends-on-d3)** | Admins | The Streaming Monitor timeline no longer blanks out when a chart library fails to load |
| 7 | **[Lookup hardening](#lookups-harder-to-break-easier-to-trust)** | Admins · End users | An unconfigured lookup works instead of dying on the first keystroke; values with `=` round-trip intact |
| 8 | **[Scheduled Jobs editor fixes](#scheduled-jobs-editor-defaults-count-stale-parameters-pruned)** | Admins | Required parameters with defaults count as satisfied, and switching classes no longer saves stale parameters |

---

## Translate the framework's UI: display strings are now Custom Labels

**Who it's for:** administrators of international orgs, and any team that wants to reword the framework's messages.

Before 1.4, roughly half of the framework's on-screen text was hardcoded English: toasts, dialog titles, placeholders, empty states, validation messages, error text. You could
not translate it through Translation Workbench and you could not reword it. Now the display strings across 26 component bundles come from Custom Labels, with the build checks
keeping new hardcoded text out of them: the package ships 898 labels, 359 more than 1.3, and repeated one-word atoms (Save, Cancel, Yes, No, and their kin) were consolidated so
each translates once.

English rendering is byte-identical to 1.3, with one small registered exception: three developer-documentation links inside the Streaming Monitor's register tab moved into rich
text and now open in the current tab rather than a new one (the rich-text component drops link target attributes). One category is not converted yet: image alternative text (the
description a screen reader announces for an image) still ships as fixed English text, and the bundled scanner flags hardcoded alternative text as a warning rather than an error.

To translate, open Translation Workbench, pick your language, and filter labels by the `kern` namespace. Labels group by component category, so translating one screen at a time
is practical.

## Async chains: no more spurious failures from long step logs

**Who it's for:** developers running multi-step async chains; admins reading the Chain Monitor.

A defect shipped since 1.2 could mark a healthy chain as **Failed**: a continue-on-error chain accumulates per-step failure messages into its step log, and once that JSON outgrew
the `StepLog__c` field it was silently cut short into invalid JSON; the next step's read then failed and took the chain's status with it. 1.4 fixes it end to end: persisted
per-step failure messages are capped (full text still reaches the step's log entry, so nothing is lost from the searchable log), the step log is never truncated into invalid
JSON, and a chain whose step list could never fit is rejected up front, before any state changes, instead of dying midway.

## Chain Monitor: live refresh in every deploy, not just managed installs

**Who it's for:** admins and developers watching chains run; teams on the unmanaged or renamed-namespace install paths.

The Chain Monitor's real-time refresh subscribed to a streaming channel with a hardcoded `kern__` prefix, so in an unmanaged or renamed-namespace deploy it silently never
refreshed. It now resolves your org's actual namespace at runtime before subscribing, verified live in a no-namespace org. Two adjacent fixes ride along: refreshes now fire only
for chain-execution events instead of every record-bearing log event in the org, and navigating away mid-subscribe can no longer leak a subscription that keeps querying from a
dead component.

## Record forms: failed saves are reported, explicit values survive

**Who it's for:** anyone using the framework's record create and edit forms.

Three fixes to the create/edit form component. A save rejected by a validation rule, field-level security, or a record lock previously showed nothing: the form looked saved when
it was not. Every failure now produces exactly one error toast, and success is only signalled on success (a failed create previously could toast success and emit a created event
with no record). And explicit falsy values (`0`, `false`, empty string) now survive both display and save instead of falling back to a default or the record's previous value.

## Silent failures eliminated across the admin screens

**Who it's for:** admins working in the framework's consoles.

A sweep of every component removed the places where a failure looked like success: copy-to-clipboard now reports when the copy did not happen (previously some screens showed
"Copied" regardless), health-check retention updates surface their errors, the Scheduled Jobs editor shows save and load failures inline in the dialog, and duplicate error toasts
from one failure are deduplicated.

## Streaming Monitor: the event timeline no longer depends on D3

**Who it's for:** admins using the Streaming Monitor.

The event timeline was drawn with the D3 charting library loaded from a static resource, and when that load failed the chart rendered blank. The timeline is now native SVG with
no external library: same interactions, no load-order flake, and its text is translatable like everything else. One visual change to know about: axis ticks now sit on clean
epoch-aligned steps rather than D3's chosen intervals. The `d3.js` static resource still ships in the package for now (removing a released component requires a Salesforce process
that is underway); nothing uses it.

## Lookups: harder to break, easier to trust

**Who it's for:** admins configuring lookups; anyone typing into one.

A search lookup dropped onto a page without its Search Parameters property configured threw an error on the first keystroke and never searched again; it now simply searches
without extra parameters. Parameter values containing `=` (filter expressions, encoded values) were truncated at the second `=`; only the first now separates key from value. The
base lookup also picked up a set of correctness fixes: keyboard navigation stays inside the filtered list, the empty state waits for the search to settle instead of flashing
early, and record labels render safely when field tokens overlap.

## Scheduled Jobs editor: defaults count, stale parameters pruned

**Who it's for:** admins scheduling framework jobs.

Required parameters that carry only their default value now count as satisfied and persist with the job (previously the editor demanded a manual re-entry of values it already
had). Switching the job's Apex class no longer carries the previous class's parameters into the save. The job detail card now shows loading and error states instead of going
quietly blank.

## Smaller fixes

- **Template strings with `$` render verbatim.** A substituted value containing `$` patterns (currency, regex fragments) no longer corrupts the surrounding message text.
- **Streaming components clean up after themselves.** Resize listeners, timers, and download blob URLs are released on teardown; the Flow footer unsubscribes its message channel.
- **Cross-component polish.** Render-purity and teardown fixes across the portfolio: no component mutates state or opens dropdowns during render, and debounce timers clear on
  disconnect.

## Upgrading & compatibility

1.4 is a **backward-compatible** release. The Apex API and metadata surface are purely additive: zero global members removed or changed, no object, field, permission-set, tab, or
app changes, Custom Labels strictly added (359 new, none removed or renamed), and the platform baseline is unchanged (Summer '26, API 67.0). Upgrading from 1.3 is the standard
package upgrade with no migration steps.

**Behaviour changes to note on upgrade** (deliberate, reviewed, none affect compiled code):

- **Client-side logging is quieter by default and flushes sooner.** The LWC logger's browser-console mirroring is now off by default (call `setConsoleMirroring(true)` to
  re-enable it while debugging), and buffered info/warn/debug entries auto-flush once 20 accumulate, so client activity reaches `LogEntry__c` more promptly. Expect somewhat more
  log records from busy client sessions.
- **Async chains fail fast on impossible step lists, and persisted step messages are capped.** `execute()` now rejects a chain whose step list can never fit the step log before
  anything runs, and per-step failure messages persisted to `StepLog__c` cap at 255 characters. If you parse `StepLog__c` JSON for full failure text, read the step's log entry
  instead; the full message lands there.
- **Chain Monitor refresh is scoped.** The monitor re-queries only on chain-execution events now, not on every record-bearing log event in the org. Strictly narrower; nothing to
  do unless you relied on unrelated events refreshing the view.
- **Timeline axis ticks changed shape.** The Streaming Monitor timeline's axis ticks are epoch-aligned steps now (see the timeline section above).
- **Three documentation links open in the current tab.** In the Streaming Monitor's register tab, developer-doc links that moved into rich text no longer force a new tab.

### Known issue: the Log Console's date presets follow the browser clock

Unchanged from 1.3: the Log Console's date-range presets compute their windows from the browser's clock rather than the org's time zone, so entries near a window boundary can
appear in the adjacent preset when the two clocks disagree. A fix is queued; absolute date filters are unaffected.
