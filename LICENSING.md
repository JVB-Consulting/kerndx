# Using KernDX: what the licence allows

KernDX is open source under the Apache License 2.0. Versions 1.10 and earlier were published under the Business Source
License 1.1, and each becomes Apache 2.0 no later than four years after it was first published.

You can use KernDX for anything: in production, in your own Salesforce orgs, in the orgs you build for your clients, and
inside products you sell. You can read, copy and change all of the code. You do not need to ask us or pay us.

The licence asks one main thing in return. When you give a copy to someone else, changed or not, pass the licence on:

- include the licence text, the [`LICENSE`](./LICENSE) file;
- include the KernDX notice, the short block at the top of [`NOTICES.md`](./NOTICES.md), above the marked line. The rest
  of that file lists files that come from other open-source projects, each with its own requirements. If you ship any of
  the files it lists, keep their entries too;
- keep the copyright and attribution notices that are already in the files (for example the "Adapted from" lines and
  the modifications copyright lines);
- in each file you change, add a note that says you changed it ([Renaming the namespace](#renaming-the-namespace) shows
  the one exception).

This page explains the licence in plain words, with examples. It describes the licence from version 1.11 onwards; see
[Earlier versions](#earlier-versions) for 1.10 and before. It is guidance, not part of the licence: the
[`LICENSE`](./LICENSE) file is what governs, and if the two ever seem to differ, `LICENSE` wins.

## Can I use it?

| What you want to do | Allowed? | Why |
|---|---|---|
| Install KernDX in your own Salesforce orgs and run it in production | Yes | The Apache License 2.0 allows any use, including commercial and production use. |
| As a consultancy or integrator, install KernDX in a client's org and build on it, charging for your services | Yes | The licence puts no limit on charging for your work. |
| As a managed-services provider, run and support a client's org that uses KernDX | Yes | Same reason: you may charge for running and supporting it. |
| Build your own app or package on KernDX and sell it | Yes | Any product is allowed, including one that does what KernDX does. Pass the licence and the notice on, and give your product its own name (see [The KernDX name](#the-kerndx-name)). |
| Give away a free product built on KernDX | Yes | The same rules apply whether you charge or not. |
| Copy and change the code, for testing, learning or your own use | Yes | The licence lets you copy, change and build on the code. If you share a changed copy, mark the files you changed. |

## Earlier versions

Versions 1.11 and later are under the Apache License 2.0. Versions 1.10 and earlier were published under the Business
Source License 1.1 (BSL). Each of them becomes Apache 2.0 no later than four years after it was first published. Until
then, the BSL text in that version's own `LICENSE` file governs it.

Each version has its own date: the date it was first publicly distributed, normally the date of its
[GitHub release](https://github.com/JVB-Consulting/kerndx/releases) (GitHub shows it in UTC). For example, a version
first published on 13 October 2026 becomes Apache 2.0 no later than 13 October 2030.

## Is any of the code under a different licence?

Yes, three parts:

- **The CI pipeline tooling** under `pipeline/` is under the MIT License, a short permissive open-source licence. Its
  terms are in [`pipeline/LICENSE`](./pipeline/LICENSE).
- **The ESLint plugin** under `scanner/eslint-plugin-kerndx/` is under the MIT License too. Its terms are in
  [`scanner/eslint-plugin-kerndx/LICENSE`](./scanner/eslint-plugin-kerndx/LICENSE).
- **Files that come from other open-source projects** stay under their original licences (Apache 2.0, MIT, BSD 3-Clause
  or ISC). [`NOTICES.md`](./NOTICES.md) lists each file, the project it comes from, its licence and its copyright
  holders. If you copy or share these files, keep their notices.

`NOTICES.md` also credits files adapted from a public-domain (CC0) project. Those files are under the Apache License 2.0
like the rest of KernDX.

## Renaming the namespace

KernDX comes with a tool, `bin/swap-namespace.js`, that renames the `kern` namespace to one of your own. When you share
a renamed copy, the Apache License alone would ask you to add a note to every renamed file saying you changed it (section
4(b) of the licence).
Because that note adds nothing for a rename, JVB Consulting, as the copyright holder, gives you an extra permission, on
top of the Apache License 2.0:

- **Which files it covers:** every file in a KernDX release whose copyright JVB Consulting holds. It does not cover files
  that come from other open-source projects, because JVB Consulting does not own them. `NOTICES.md` lists those files;
  the list shows where the line falls, but ownership is what decides it.
- **Which change it covers:** only the rename that `bin/swap-namespace.js` makes, that is the namespace prefix and the
  names the tool builds from it. No other edit.
- **The condition:** your copy keeps a README that says the code is KernDX, says that `bin/swap-namespace.js` renamed the
  namespace from `kern` to yours, and links to `LICENSE` and `NOTICES.md`. The README the tool writes says exactly this,
  so keep it. If you keep your own README instead (the tool's `--keep-readme` option), it must say the same.

When all three hold, you do not need a change note in each renamed file. Any other change to one of these files still
needs the note, as the Apache License asks.

The files from other projects are outside this permission, because only their own authors could give it. If you share
a renamed copy that changes any of them, each one needs what its own licence asks. For example, `UTIL_Comparators.cls`
comes from an Apache-licensed project, so a changed copy of it needs a note in the file saying you changed it.
`NOTICES.md` lists these files and points to what each upstream licence requires.

## The KernDX name

The licence covers the code, not the KernDX name or logo (section 6 of the Apache License). If you publish a fork or a
rebranded copy, give it your own name. Saying that it is "built from KernDX" is fine.

## Questions

If something here is unclear, or your plans are not covered by this page, contact <jason@jvb-consulting.io>.
