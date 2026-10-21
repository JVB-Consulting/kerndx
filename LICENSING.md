# Using KernDX: what the licence allows

KernDX is free to use, including in production, in your own Salesforce orgs and in the orgs you build for your clients.
It is published under the Business Source License 1.1 (BSL), a source-available licence: you can read, copy and change
all of the code, and the main thing it rules out is selling KernDX itself, or something built to compete with it, as a
product. Four years after each version is first published, that version becomes open source under the Apache License
2.0.

This page explains the licence in plain words, with examples. It describes the licence from version 1.9 onwards; each
earlier version keeps the licence it was published with. It is guidance, not part of the licence: the
[`LICENSE`](./LICENSE) file is what governs, and if the two ever seem to differ, `LICENSE` wins.

## Can I use it?

| What you want to do | Allowed? | Why |
|---|---|---|
| Install KernDX in your own Salesforce orgs and run it in production | Yes | The licence says so in words: installing and using it in a Salesforce org as a subscriber is permitted production use. |
| As a consultancy or integrator, install KernDX in a client's org and build on it, charging for your services | Yes | The client's org uses KernDX as a subscriber. Your paid services are not a software product, so they are not a competitive offering. The licence's mention of paid support applies only to support sold with a competing product. |
| As a managed-services provider, run and support a client's org that uses KernDX | Yes | Same reason: the org uses KernDX as a subscriber, and support for it is a service, not a competing product. |
| Build your own app or package on KernDX and sell it | Yes, unless your app is paid and does much of what KernDX itself does (for example, a competing framework, or a product built mainly on KernDX's logging or masking) | The licence only restricts a paid product that significantly overlaps with the capabilities of KernDX. An app that uses KernDX to do something different does not. |
| Give away a free product built on KernDX | Yes | The licence says that products not provided on a paid basis are not competitive. |
| Copy and change the code, for testing, learning or your own use | Yes | The licence lets you copy, modify and make derivative works. Modified copies stay under the same licence, with the same rules for production use. |
| Sell KernDX itself, or a Salesforce framework built from it, to others as a hosted or embedded product | No, not under this licence | This is the competing use the licence excludes. Contact us about other arrangements. |

## When does a version become open source?

Each version has its own date. A version becomes available under the Apache License 2.0 four years after the date it
was first publicly distributed, normally the date of its
[GitHub release](https://github.com/JVB-Consulting/kerndx/releases) (GitHub shows it in UTC). For example, a version
first published on 13 October 2026 becomes Apache 2.0 on 13 October 2030. Versions published
later convert later, each on its own date.

## Is any of the code under a different licence?

Yes, two parts:

- **The CI pipeline tooling** under `pipeline/` is under the MIT License, a permissive open-source licence. Its terms
  are in [`pipeline/LICENSE`](./pipeline/LICENSE).
- **Files derived from other open-source projects** stay under their original licences (Apache 2.0, MIT or BSD
  3-Clause). [`NOTICES.md`](./NOTICES.md) lists each file, the project it comes from and its copyright holders, and
  each of those files names its licence in its header. If you copy or redistribute them, keep their notices.

`NOTICES.md` also credits files adapted from a public-domain (CC0) project. Those files are under the BSL like the
rest of KernDX.

## Is the BSL an open-source licence?

No. It is a source-available licence: everything is public and you may change it, but the competing-product
restriction above means it does not meet the Open Source Initiative's definition. Each version becomes open source on
its own date, as described above.

## Need something the licence doesn't cover?

If your plans fall outside this page, for example offering a product that competes with KernDX, contact
<jason@jvb-consulting.io> about other licensing arrangements.
