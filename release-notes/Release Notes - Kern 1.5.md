# Kern 1.5 Release Notes

**Builds on:** [Kern 1.4 Release Notes](./Release%20Notes%20-%20Kern%201.4.md), [Kern 1.3 Release Notes](./Release%20Notes%20-%20Kern%201.3.md), [Kern 1.2 Release Notes](./Release%20Notes%20-%20Kern%201.2.md), [Kern 1.1 Release
Notes](./Release%20Notes%20-%20Kern%201.1.md), and the [Kern 1.0 Feature Reference](./Release%20Notes%20-%20Kern%201.0.md), which together remain the full reference for
everything 1.5 carries forward.
**Platform:** Salesforce API 67.0 (Summer '26), unchanged from 1.4 · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** the build is validated and end-to-end testing of the change has passed. The package version id and release tag below are published with the release.

> **What's new since 1.4:** one fix. The Streaming Monitor's Change Data Capture list now shows standard change events again (such as `AccountChangeEvent`), not just the ones for
> your custom objects, and every channel is now labelled so you can tell standard and custom apart at a glance.
>
> **Why 1.5 for a single fix:** KernDX publishes each release as a new minor version, so a standalone fix ships as the next minor rather than a patch. 1.5 carries this streaming fix
> and nothing else.
>
> **Safe to upgrade:** 1.5 is **backward-compatible**. The Apex API and the metadata surface are purely additive: no global member is removed or changed, no object, field, tab, or
> permission changes, and the two new Custom Labels only add to what shipped in 1.4. Upgrading from 1.4 is the standard package upgrade with no migration steps. For the per-build
> log, see the [CHANGELOG](../CHANGELOG.md).

---

## Change Data Capture: standard change events are back in the Streaming Monitor

**Who it's for:** admins and developers using the Streaming Monitor.

The Streaming Monitor lets you subscribe to Salesforce's live event channels and watch events arrive. One of those channel types is Change Data Capture (CDC), Salesforce's stream
of record-change events, one message each time a record is created, updated, deleted, or undeleted.

Before 1.5, the monitor's CDC list showed only the change events for your custom objects. The standard ones, like `AccountChangeEvent` and `ContactChangeEvent`, were missing, so
you could not subscribe to them from the monitor. The cause was in how the list was built: it looked for standard change events under a publisher that no record on the platform
actually uses (every change event, standard and custom, is registered the same way), so the standard channels were never found. 1.5 replaces that with a single lookup that returns
both, and the standard channels are back in the list.

While making that fix, the channels are now grouped and labelled. Each entry reads **Standard: _name_** or **Custom: _name_**, so you can see at a glance which is which. The labels
come from Custom Labels, so you can translate them, and the value the monitor subscribes to is unchanged.

### Credit

KernDX's Streaming Monitor is adapted from Philippe Ozil's [Streaming Monitor](https://github.com/pozil/streaming-monitor), which he released to the public domain under CC0-1.0,
rebuilt to follow KernDX conventions. If you want the monitor on its own, without the framework, install his instead: it is [free on the
AppExchange](https://appexchange.salesforce.com/appxListingDetail?listingId=a0N3A00000FYEEWUA5) and it is the better choice for that.

## Upgrading & compatibility

1.5 is a **backward-compatible** release. The Apex API and metadata surface are purely additive: zero global members removed or changed, no object, field, permission-set, tab, or
app changes, Custom Labels strictly added (two new, none removed or renamed), and the platform baseline is unchanged (Summer '26, API 67.0). Upgrading from 1.4 is the standard
package upgrade with no migration steps, and there are no behaviour changes to note beyond the fix described above.

Everything in the [Kern 1.4 Release Notes](./Release%20Notes%20-%20Kern%201.4.md) and earlier still applies; 1.5 changes only what is on this page.
