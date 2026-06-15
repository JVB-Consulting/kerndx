# Contributing to KernDX

Thank you for considering a contribution. KernDX is published here so adopters can clone, review, and learn from a transparent codebase.

## Contribution model: issues only

KernDX is single-maintainer today. To keep the framework predictable while it stabilises, **external pull requests are not supported yet**. Instead, the project relies on issues — bug reports and feature requests — to surface problems and improvements. The maintainer reviews each issue and may implement the fix; the fix then arrives here on the next release.

This policy is explicit in [Strategic Guide - Risks.md](./docs/Strategic%20Guide%20-%20Risks.md) under "Governance Model": *"Contribution policy: Internal — no external contributions accepted at this time."*

## How releases work

- Releases land on `main` as fast-forward appends tagged `vX.Y.Z-N`. `main` is **never force-pushed**.
- Each release replaces the working tree wholesale — so PR commits merged here would be replaced on the next release. The issue-first workflow is structurally required at this stage.

## What we welcome

| Contribution type | Best path |
| --- | --- |
| Bug report | Open a [GitHub issue](../../issues/new/choose) using the `Bug report` template. |
| Feature request | Open a [GitHub issue](../../issues/new/choose) using the `Feature request` template. |
| Documentation typo / clarification | Open a [GitHub issue](../../issues/new/choose) — describe the doc + the fix. The maintainer applies it. |
| Security vulnerability | **Do not open a public issue.** See [the security policy](./SECURITY.md) for the responsible-disclosure process. |
| Licensing or partnership inquiry | Email **jason@jvb-consulting.io**. |

## Why no PRs (yet)

Each release replaces the working tree, so any PR merged here would be overwritten on the next release. Until the project moves to a more interactive contribution model, the issue-first path is the supported one.

If you have a substantial change you'd like to land — a new selector pattern, a new framework module, a new doc — open an issue describing the proposal. If accepted, the maintainer schedules the implementation for an upcoming release.

## Conventions to know

If you're proposing code-level changes via an issue (or evaluating the project for fit), it helps to know the operating constraints:

- [Code conventions](./docs/Code%20Conventions%20-%20Guide.md): defines the Apex / LWC / JS style + critical rules (no inline SOQL, declare sharing, no `System.debug`, no `LightningElement` direct use, etc.).
- Per-class Apex coverage: 100%; LWC: 95% statements + branches.
- Anti-theatre test rules: ESLint plugin + PMD rules block weak assertions (`Assert.isNotNull` after `build()`, single-method test classes covering whole modules, etc.).
- [`AGENTS.md`](./AGENTS.md): the operating instructions for AI assistants generating code against the framework — they map 1:1 to the rules a human contributor would follow.

## Code of Conduct

Be respectful. Disagreement is fine; personal attacks are not. We follow the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) v2.1.

## Reporting other concerns

For anything that doesn't fit the above — licensing questions, partnership inquiries, governance concerns — email **jason@jvb-consulting.io**.
