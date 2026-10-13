# Security Policy

The KernDX team takes security seriously. We appreciate responsible disclosure of vulnerabilities discovered in this codebase.

## Supported versions

Only the latest `1.x` release receives security updates. Earlier versions are not patched.

| Version | Supported |
| --- | --- |
| 1.x (latest) | ✅ |
| < 1.0 | ❌ |

## Reporting a vulnerability

**Do not open a public GitHub issue.** Public issues are indexed immediately and can put adopters at risk before a fix is available.

Email vulnerability reports to **jason@jvb-consulting.io** with:

1. A description of the issue and the affected component (Apex class, LWC, metadata, build script, etc.).
2. The minimum reproduction steps (an org snapshot, an anonymous Apex snippet, or a failing test case).
3. The version of KernDX where the issue reproduces.
4. Any known mitigations.

We will acknowledge receipt within **3 business days**.

## Disclosure timeline

- **Day 0:** Report received; acknowledgement sent.
- **Day 1–14:** Triage. Severity classified (Critical / High / Medium / Low). Fix scoped.
- **Day 14–60:** Fix developed and tested against the supported release.
- **Day 60–90:** Coordinated disclosure. The fix is released; a security advisory is published on the GitHub repository describing the issue, affected versions, and the upgrade path.

Critical issues (e.g., privilege escalation, unauthenticated data exposure) may be disclosed on an accelerated schedule.

## Scope

In scope:

- Apex classes shipped under `force-app/main/default/classes/`.
- LWC components shipped under `force-app/main/default/lwc/`.
- Custom Metadata Type definitions and any default records shipped in the managed package.
- Build scripts under `scripts/` that operate on adopter source.
- The release-testing harness under `release-testing/`.

Out of scope:

- Bugs in third-party dependencies — report those upstream.
- Subscriber-specific configuration choices (e.g., a subscriber org granting overly permissive profiles).
- Salesforce platform vulnerabilities — report those via `https://trust.salesforce.com`.

## What a code scan reports, and why

If you run the Salesforce Code Analyzer with its AppExchange rule set over this repository, you will see a fixed set of findings. None of them is a vulnerability, and most are name matches. This section explains each one so you can judge it for yourself, and says what to do if you repackage the framework under your own namespace.

Every push to this repository runs that scan in continuous integration (CI). The run fails if the scan reports a finding that is not in the list of known findings, `scanner/appexchange-baseline.json`, and each finding in that list points to the part of this section that explains it.

### A Visualforce page reads the session ID

`UTIL_GetApiEnabledSessionId` is a one-line Visualforce page that reads `$Api.Session_ID`. The framework renders it once per transaction so that `UTIL_System.getApiEnabledSessionId()` can hand Apex a session that is allowed to call the platform's own APIs. `API_CallCurrentOrg` uses that session as the bearer token when your code calls a REST, Composite or Tooling endpoint in the same org.

This is an approved use. Salesforce's [Security Considerations for Session IDs](https://developer.salesforce.com/docs/atlas.en-us.secure_coding_guide.meta/secure_coding_guide/secure_coding_considerations_sessionid.htm) permits session IDs for SOAP and REST Data API calls that access org data and for Metadata API reads. The framework stays inside that boundary:

- The session ID is only ever sent to your org's own My Domain URL. It never leaves the org.
- Access to the page is granted by the `ApiSessionId` permission set. A user without it gets no session ID.
- The framework never uses the session to edit org-wide settings, Named Credentials or connected apps.

If you never call back into your own org, do not assign that permission set. If you repackage the framework and do not need calls into your own org, remove the page and `API_CallCurrentOrg` together.

### Two message channels are exposed

The `Component` and `Navigation` Lightning Message Channels are marked `isExposed`, so your own components can listen for lookup selections and send navigation instructions to the framework's flow footer. What travels on them is a selected record and a "ready" signal, nothing sensitive. The platform does not allow an exposed channel to be made private again once it has shipped, so they stay exposed. If you repackage under your own namespace and do not need that contract, set `isExposed` to false before your first release.

### Field names that look like secrets

The scanner flags any field whose name contains a word such as Key, Hash, Credential, Bypass or Encrypted. The fields it finds here hold idempotency keys, request hashes, deduplication keys, bypass switches, and the name of a Named Credential (a stored, reusable connection definition). None holds a password, token or secret, so none needs to move into protected metadata, which would also hide the value from your own admins. Released field names cannot be renamed.

### Test files for the streaming monitor

The Jest tests for the streaming monitor, under `lwc/streamingMonitor/__tests__/`, dispatch events with `bubbles` and `composed` set to true. The component itself sends its events with neither option, and its parent listens on the child tag in its own template, so in a browser no event crosses a component boundary. The scanner reads test files like any other file, so it reports each of those test events. A `__tests__` folder is never part of the package, so none of them runs in your org.

### One flow updates its own record

A run with the scanner's Recommended rule set, which is broader than the AppExchange set, also reports that `RetryOutboundApiCall` updates its own record. It is a record-triggered flow with a scheduled path: when the retry time arrives it marks the call as retrying so it is not picked up twice. Scheduled paths exist only on after-save flows, so the scanner's advice to use a before-save flow does not apply. The flow writes only to the call record it was started for, so this is about efficiency, not a security risk.

### The release-test harness breaks rules on purpose

Everything under `release-testing/` runs in a throwaway scratch org during a release. A few classes deliberately violate rules so the framework's own scanner and guards can be proven to fire. Nothing there ships in the package. Do not deploy it to a production org.

### A vendored library

The `d3` static resource is an unmodified copy of D3 under its own ISC licence. Nothing in the package loads it any more.

## Recognition

We credit reporters in the security advisory unless anonymity is requested. We do not currently offer a paid bug bounty.
