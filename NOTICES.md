KernDX

Copyright 2026 JVB Consulting

KernDX is licensed under the Apache License, Version 2.0; see the `LICENSE` file.

*End of the NOTICE statement. The block above is the KernDX NOTICE statement
(Apache License 2.0, §4(d)), the part you reproduce when you share KernDX.
What follows is the inventory of third-party files, each with its own
notice requirements.*

---

# Third-Party Notices

KernDX includes source code derived from third-party open-source projects,
and one third-party library shipped as published, with its licence notice added at the top.
This file enumerates those upstream projects, their licenses, and copyright
holders, per Apache License 2.0 §4 (a–d), the MIT License attribution
requirement, the BSD 3-Clause attribution requirement, and the ISC License
attribution requirement, plus voluntary attribution for CC0-1.0 derivatives
where the upstream license imposes no requirement. Each of these files keeps
its upstream license, and each derived source file also carries an
SPDX-License-Identifier header.

For each upstream project below: the project name, its canonical URL, its
license, the copyright holder(s) we can establish from the upstream source
(or "undetermined" with a pointer to the upstream URL where the original
notice would have lived), and the list of KernDX source files derived from
it.

Full license texts are shipped at:

  - `LICENSES/Apache-2.0.txt` — canonical Apache License, Version 2.0
    (downloaded from <https://www.apache.org/licenses/LICENSE-2.0.txt>)
  - `LICENSES/MIT.txt` — canonical MIT License (Expat form)
  - `LICENSES/BSD-3-Clause.txt` — canonical BSD 3-Clause License
  - `LICENSES/ISC.txt` — the ISC License as published by d3
    (downloaded from <https://raw.githubusercontent.com/d3/d3/v7.9.0/LICENSE>)

The Apache License 2.0 text under which the rest of KernDX is licensed is in
the root `LICENSE` file. The pipeline tooling under `pipeline/` is under the
MIT License (see `pipeline/LICENSE`), and so is the ESLint plugin under
`scanner/eslint-plugin-kerndx/` (see `scanner/eslint-plugin-kerndx/LICENSE`).

The Apache-2.0, MIT, BSD-3-Clause, and ISC files enumerated below each
remain under their upstream license and keep their upstream notices. The
CC0-1.0 derivative files are public-domain dedications upstream and have
been relicensed under the Apache License 2.0 alongside the rest of KernDX
(CC0-1.0 permits this); they are listed here for transparency and author
credit, not because their licensing diverges from the framework default.

---

## Apache License 2.0 derivatives

### apex-lang

- **Upstream URL:** [code.google.com/p/apex-lang](https://code.google.com/p/apex-lang/)
  (Google Code; archived 2016 — upstream is no longer maintained or
  accessible through the original hosting. GitHub mirrors of the source
  exist but no single canonical mirror has been adopted by the community.)
- **License:** Apache License, Version 2.0 — full text at
  `LICENSES/Apache-2.0.txt` (also available at
  [apache.org/licenses/LICENSE-2.0](https://www.apache.org/licenses/LICENSE-2.0)).
- **Copyright holder:** Undetermined — the upstream Google Code repository
  hosted the project's original `NOTICE` and copyright file, but the
  archive's accessible artifacts no longer carry an explicit copyright
  holder line that we can quote verbatim. Per Apache 2.0 §4(b) we preserve
  the attribution "Adapted from apex-lang" in each derived file's header
  and use "Copyright (c) apex-lang contributors (see upstream URL)" as the
  copyright line.
- **Upstream NOTICE file:** Unrecoverable — the Google Code archive
  (read-only since 2015, dark since 2016) does not surface a separate
  `NOTICE` file for the project at its archived artifacts. Per Apache 2.0
  §4(d) we are obliged to preserve any upstream `NOTICE` contents we can
  obtain; we cannot obtain them here. If the original notice surfaces from
  another mirror or archive in future, append its contents to this file.
- **Derived KernDX files (19, all under `force-app/main/default/classes/`):**

  | File | Companion test |
  |------|----------------|
  | `UTIL_Boolean.cls` | `UTIL_Boolean_TEST.cls` |
  | `UTIL_Character.cls` | `UTIL_Character_TEST.cls` |
  | `UTIL_Comparators.cls` | `UTIL_Comparators_TEST.cls` |
  | `UTIL_Email.cls` | — |
  | `UTIL_List.cls` | `UTIL_List_TEST.cls` |
  | `UTIL_Map.cls` | `UTIL_Map_TEST.cls` |
  | `UTIL_NumberRange.cls` | `UTIL_NumberRange_TEST.cls` |
  | `UTIL_Random.cls` | `UTIL_Random_TEST.cls` |
  | `UTIL_Set.cls` | `UTIL_Set_TEST.cls` |
  | `UTIL_String.cls` | `UTIL_String_TEST.cls` |

### apex-trigger-actions-framework

- **Upstream URL:** [github.com/mitchspano/apex-trigger-actions-framework](https://github.com/mitchspano/apex-trigger-actions-framework)
- **License:** Apache License, Version 2.0 — full text at
  `LICENSES/Apache-2.0.txt` (also available at
  [apache.org/licenses/LICENSE-2.0](https://www.apache.org/licenses/LICENSE-2.0)).
- **Copyright holder:** Copyright 2020 Google LLC (and Copyright 2024 Google
  LLC on `UTIL_FormulaFilter.cls`); preserved verbatim in each derived file's
  header per Apache 2.0 §4(b).
- **Upstream NOTICE file:** None — verified 2026-05-21 that the upstream repo
  does not ship a `NOTICE` file at either `master` or `main` branch (HTTP
  404 on both `https://raw.githubusercontent.com/mitchspano/apex-trigger-actions-framework/master/NOTICE`
  and `.../main/NOTICE`). Per Apache 2.0 §4(d), if upstream ships no NOTICE,
  no NOTICE preservation is required of derivative works.
- **Derived KernDX files (8, all under `force-app/main/default/classes/`):**

  | File | Companion test |
  |------|----------------|
  | `FLOW_CheckTriggerBypassed.cls` | `FLOW_CheckTriggerBypassed_TEST.cls` |
  | `IF_Trigger.cls` | — |
  | `TRG_Base.cls` | `TRG_Base_TEST.cls` |
  | `TRG_Dispatcher.cls` | `TRG_Dispatcher_TEST.cls` |
  | `UTIL_FormulaFilter.cls` | — |

---

## MIT License derivatives

### ApexLogger (by Mike Lockett)

- **Upstream URL:** [github.com/mlockett/ApexLogger](https://github.com/mlockett/ApexLogger)
- **License:** MIT License — full text at `LICENSES/MIT.txt` (also available
  at [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)).
- **Copyright holder:** Copyright (c) Mike Lockett 2024 (preserved verbatim
  in each derived file's header per MIT §1).
- **Derived KernDX files (4, all under `force-app/main/default/classes/`):**

  | File | Companion test |
  |------|----------------|
  | `LOG_Builder.cls` | `LOG_Builder_TEST.cls` |
  | `LOG_Engine.cls` | `LOG_Engine_TEST.cls` |

### SObjectIndex (by Aidan Harding / Nebula Consulting)

- **Upstream URL:** [bitbucket.org/aidan_harding/sobjectindex](https://bitbucket.org/aidan_harding/sobjectindex/src/master/)
- **License:** MIT License — full text at `LICENSES/MIT.txt` (also available
  at [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)).
- **Copyright holder:** Copyright (c) 2018 Aidan Harding, Nebula Consulting
  (preserved verbatim in each derived file's header per MIT §1).
- **Derived KernDX files (2, all under `force-app/main/default/classes/`):**

  | File | Companion test |
  |------|----------------|
  | `MAP_SObject.cls` | `MAP_SObject_TEST.cls` |

### JsonPath / jsonparse (by open-force)

- **Upstream URL:** [github.com/open-force/jsonparse](https://github.com/open-force/jsonparse)
- **License:** MIT License — full text at `LICENSES/MIT.txt` (also available
  at [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)).
- **Copyright holder:** Copyright (c) 2018 open-force (preserved verbatim in
  each derived file's header per MIT §1).
- **Derived KernDX files (2, all under `force-app/main/default/classes/`):**

  | File | Companion test |
  |------|----------------|
  | `UTIL_JsonPath.cls` | `UTIL_JsonPath_TEST.cls` |

---

## BSD 3-Clause License derivatives

### Apex-Util (by capeterson) — predecessor of FinancialForce apex-common / fflib

- **Upstream URL:** [github.com/capeterson/Apex-Util](https://github.com/capeterson/Apex-Util)
  (Carlos Peterson's pre-FinancialForce work; later absorbed and renamed
  inside `FinancialForce/apex-common`, which `fflib_SObjectDescribe` and
  `fflib_SObjectUnitOfWork` carry forward today. The KernDX derivative
  files were lifted from the predecessor BSD-licensed source and
  preserve the original `Copyright (c), FinancialForce.com, inc` block
  in each file header per the BSD 3-Clause attribution requirement.)
- **License:** BSD 3-Clause License — full text at
  `LICENSES/BSD-3-Clause.txt` (also available at
  [opensource.org/licenses/BSD-3-Clause](https://opensource.org/licenses/BSD-3-Clause)).
  BSD 3-Clause is not unilaterally relicensable, so these files remain
  under BSD 3-Clause rather than the framework-default Apache 2.0.
- **Copyright holder:** Copyright (c), FinancialForce.com, inc (since renamed
  Certinia). Preserved verbatim in each derived file's header per the BSD
  3-Clause attribution requirement.
- **Upstream NOTICE file:** None — BSD 3-Clause requires copyright notice
  preservation in source + binary but does not require a separate `NOTICE`
  file. The copyright block in each derived file's header satisfies §1.
- **Positioning note:** KernDX rejects the fflib Selector / Domain /
  Application *layering pattern* (subscriber code should extend
  `kern.SEL_Base` / `kern.TRG_Base` / `kern.DML_Builder`, not
  `fflib_SObjectSelector` / `fflib_SObjectDomain` / `fflib_Application`).
  The 4 utility files below — describe-cache + transactional DML — come
  from the same BSD lineage that became `fflib_SObjectDescribe` and
  `fflib_SObjectUnitOfWork`. They are reused for the same engineering
  reason the broader Apex ecosystem reuses them: the underlying describe
  + unit-of-work mechanics are well-trodden and don't differentiate.
- **Derived KernDX files (4, all under `force-app/main/default/classes/`):**

  | File | Companion test |
  |------|----------------|
  | `UTIL_SObjectDescribe.cls` | `UTIL_SObjectDescribe_TEST.cls` |
  | `DML_Transaction.cls` | `DML_Transaction_TEST.cls` |

---

## ISC License derivatives

### d3 (by Mike Bostock)

- **Upstream URL:** [github.com/d3/d3](https://github.com/d3/d3) (version
  v7.9.0; license at [github.com/d3/d3/blob/v7.9.0/LICENSE](https://github.com/d3/d3/blob/v7.9.0/LICENSE),
  read 2026-10-29).
- **License:** ISC License: full text, with its copyright line, at
  `LICENSES/ISC.txt` (a byte copy of the upstream `LICENSE` file).
- **Copyright holder:** Copyright 2010-2023 Mike Bostock (the minified file
  keeps this line in its first comment, and the comment KernDX adds above it
  carries the full ISC text).
- **Upstream NOTICE file:** None: verified 2026-10-29 that the upstream
  repo ships no `NOTICE` file at tag `v7.9.0` (HTTP 404 on
  `https://raw.githubusercontent.com/d3/d3/v7.9.0/NOTICE`). The ISC License
  requires only that the copyright notice and the permission notice appear
  in all copies.
- **Changes made:** A comment at the top of the file holding the ISC
  copyright and permission notice, so every installed copy carries it. The
  upstream minified build below it is unchanged.
- **Why it is still in the package:** KernDX no longer uses d3. It stays in
  the package only until Salesforce enables its removal: removing a
  component from a released second-generation package needs a Partner
  Support case, and deleting the file from source first breaks every
  package build. The change that deletes `d3.js` deletes this entry and
  `LICENSES/ISC.txt` with it.
- **Shipped KernDX files (1, under `force-app/main/default/staticresources/`):**

  | File | Companion test |
  |------|----------------|
  | `d3.js` | — |

---

## Public Domain (CC0-1.0) derivatives

### streaming-monitor (by Philippe Ozil)

- **Upstream URL:** [github.com/pozil/streaming-monitor](https://github.com/pozil/streaming-monitor)
- **License:** Creative Commons Zero v1.0 Universal (CC0-1.0) — full text at
  `LICENSES/CC0-1.0.txt` (also in the upstream LICENSE.md file, and at
  [creativecommons.org/publicdomain/zero/1.0](https://creativecommons.org/publicdomain/zero/1.0/)).
  CC0-1.0 is a public-domain dedication that waives all copyright and
  related rights. The kern derivative files are therefore relicensed under
  the Apache License 2.0 alongside the rest of KernDX and are covered by
  the root `LICENSE` file.
- **Original author:** Philippe Ozil (Salesforce). His original tool is free
  on the AppExchange (listing `a0N3A00000FYEEWUA5`). CC0-1.0 explicitly waives
  the right to require attribution, so none of the credit below is a licence
  obligation — we credit him because it is the right thing to do. The credit is
  preserved as a header line in each derived file and, for reader visibility,
  in the developer guides and the public README.
- **Upstream NOTICE file:** None — verified 2026-05-21 that the upstream
  repo (default branch `master`) ships only the LICENSE.md file at the
  canonical top-level path. No NOTICE, NOTICE.txt, NOTICES.md, or COPYRIGHT
  file exists anywhere in the repository tree. CC0-1.0 imposes no NOTICE
  preservation requirement on derivatives.
- **Derived KernDX LWC components (11, all under `force-app/main/default/lwc/`):**

  | Component | Files marked (production + `__tests__/`) |
  |-----------|------------------------------------------|
  | `streamingActions/` | 7 (1 .js + 5 .html + 1 .css + 1 test) |
  | `streamingEventFilters/` | 4 (1 .js + 1 .html + 1 .css + 1 test) |
  | `streamingEvents/` | 6 (2 .js + 2 .html + 1 .css + 1 test) |
  | `streamingEventsHeader/` | 3 (1 .js + 1 .html + 1 test) |
  | `streamingMonitor/` | 4 (1 .js + 1 .html + 1 .css + 1 test) |
  | `streamingSidebar/` | 4 (1 .js + 1 .html + 1 .css + 1 test) |
  | `streamingSubscriptions/` | 4 (1 .js + 1 .html + 1 .css + 1 test) |
  | `streamingTimeline/` | 4 (1 .js + 1 .html + 1 .css + 1 test) |
  | `streamingUsageFilters/` | 4 (1 .js + 1 .html + 1 .css + 1 test) |
  | `streamingUsageMetrics/` | 4 (1 .js + 1 .html + 1 .css + 1 test) |
  | `utilityStreaming/` | 2 (1 .js + 1 test) |

  Each file's header carries `SPDX-License-Identifier: Apache-2.0` (the
  kern-relicensed identifier), the upstream credit line, the "Adapted
  from streaming-monitor" attribution, and the modifications copyright.

  The `orgLimits/` LWC is intentionally **not** listed here: it is an original
  KernDX rebuild (a native SLDS card grid, no D3, no shared code) and says so in
  its own header. Only the org-limits *view concept* traces to the upstream tool.

- **Derived KernDX Apex classes (all under `force-app/main/default/classes/`):**

  | File | Scope of derivation |
  |------|---------------------|
  | `CTRL_EventMonitor.cls` | Full — the Streaming Monitor controller (channel discovery, event publishing, org limits, usage metrics) is adapted from his `StreamingMonitorController`. |
  | `CTRL_EventMonitor_TEST.cls` | Full — companion test, structured after his `StreamingMonitorControllerTest`. |
  | `SEL_EntityDefinition.cls` | Partial — only the streaming channel-discovery query methods (`getAllStandardPlatformEvents`, `getAllCustomPlatformEvents`, `getAllChangeCaptureEvents`) derive from his controller's inline SOQL; the masking and framework selector methods are original KernDX work. Its header scopes the credit accordingly. |

  As with the LWC components, each carries `SPDX-License-Identifier: Apache-2.0`
  and an upstream credit line.

---

## How this file is maintained

- A license-audit script in the KernDX maintainer toolchain walks every
  source file in the codebase and detects per-file licensing signals (SPDX
  tags, inline license boilerplate, "Adapted from" headers, copyright
  lines). Its output is the source-of-truth for this file's enumeration.
  If a new derivative file is added, the audit surfaces it; this file is
  updated to match before the next sync.
- This file is the only list of the derived files, so there is no second
  list to drift from it. It carries the upstream URLs and citations you
  can use to follow each file back to its original source.
- A build-time mirror gate enforces that every staged source
  file carries an SPDX identifier matching one of the expected tags
  (`Apache-2.0`, `MIT`, `BSD-3-Clause`); the files enumerated here are the
  only MIT / BSD-3-Clause files, and the only files under an upstream
  Apache-2.0 license, in the framework source tree outside of `pipeline/`
  and `scanner/eslint-plugin-kerndx/`.
