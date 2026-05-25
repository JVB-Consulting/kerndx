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

## Recognition

We credit reporters in the security advisory unless anonymity is requested. We do not currently offer a paid bug bounty.
