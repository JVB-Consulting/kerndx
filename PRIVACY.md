# Privacy Policy

**The short version: KernDX never sends your data to us.** The framework runs entirely inside your Salesforce org, the same way code your own team writes does. There is no telemetry (usage tracking that reports back to the maker), no licence server, no analytics, and no "phone home" of any kind, in any component. We built it that way on purpose, and this page explains exactly what that means.

This policy covers everything KernDX ships: the managed package, the source in this repository, the standalone CI tooling, and the documentation site. It is published by JVB Consulting, the maker of KernDX. Your use of KernDX itself is governed by the [licence](./LICENSE).

## What data does the framework touch?

Whatever records your org's code and configuration pass through it. Queries, saves, triggers, validations, logging, and data masking all operate on your org's data, inside your org, under your org's security model.

Everything the framework produces (log records, configuration, audit entries) is stored as ordinary Salesforce records in your org. You can query them, export them, or delete them at any time. They are yours.

Data masking deserves a special mention: it exists to *remove* sensitive values at write time, so adopting it reduces the personal data your org holds rather than adding to it.

## Does anything ever leave my org?

Only when you tell it to. The outbound HTTP framework calls the endpoints you configure in your own org's settings and named credentials. KernDX contacts no destination of its own: the only addresses it ships belong to the two example services below, and they run only if your code calls them.

Two shipped reference integrations are worth naming plainly. The first, `API_GetPwndPasswords`, is an optional example service that checks whether a password appears in the free [Pwned Passwords](https://haveibeenpwned.com/API/v3#PwnedPasswords) breach dataset. It runs only if your code calls it, and it sends only the first five characters of the password's SHA-1 hash, never the password itself, so the service cannot learn what was checked.

The second, `API_PostExample`, is a demonstration service that sends a test request to `jsonplaceholder.typicode.com`, a free public test API, so you can see an outbound call working. It too runs only if your code, or an admin using the API Test Harness, calls it.

The CI tooling runs in your own pipeline and reports only to destinations you configure (for example, your own Slack webhook). Nothing in the package, the CI tooling, or the build scripts contacts JVB Consulting.

KernDX ships its AI-assistant context (such as `AGENTS.md`) as plain files in this repository. It does not call or embed any AI service. If you use an AI assistant with KernDX, that assistant's data handling is governed by your agreement with its vendor, not by this policy.

## What does JVB Consulting ever receive?

- **From the package: nothing.** We cannot see your org, your data, your logs, or even whether you are running KernDX at all.
- **If you email support** (`jason@jvb-consulting.io`), we receive your email address and whatever you choose to include. We use it to answer you, and for nothing else.
- **If you open a GitHub issue**, that issue is public, like any GitHub issue. Please keep org data out of reproduction steps; the [security policy](./SECURITY.md) covers private disclosure.
- **If you grant us login access** to your org for a support engagement, you do that through Salesforce's own grant-login-access feature, scoped and revocable by you at any time. We never have standing access.

Salesforce, as the platform provider, knows which packages are installed in your org, as it does for every managed package. That visibility is part of your agreement with Salesforce, not with us.

## What about the documentation site and this repository?

The documentation site is a static site with no analytics and no tracking scripts, and its search runs entirely in your browser. It is hosted on GitHub Pages, and this repository is hosted on GitHub, so GitHub's ordinary hosting logs apply when you browse or clone, governed by the [GitHub Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement).

## Do you share or sell any information?

No. We do not sell, lease, share, monetise, or build profiles from customer data, and we derive no benchmarks or patterns from it. We hold none to share: the framework's design keeps your data in your org, and the support channel gives us only what you send.

## How do I revoke access or delete data?

- **The framework:** uninstall the package through Salesforce Setup, the standard managed-package uninstall.
- **Framework records** (logs, configuration, audit entries): they are ordinary records in your org. Delete them whenever you choose.
- **On our side:** there is nothing to delete, because nothing was collected. If you have emailed support and want that correspondence deleted, ask and we will.

## Where does this leave GDPR and CCPA?

KernDX does not change your data-protection position. Data it processes stays inside your Salesforce org, so installing it adds no new recipient of personal data and no new cross-border transfer. If your privacy team asks what the package transmits, the answer they need is: nothing, and that is verifiable in the public source in this repository.

## Changes to this policy

This policy is versioned in git alongside the code. Every release freezes it at a tag, so you can always see the exact policy that shipped with the version you run, and the full history of every change.

## Contact

`jason@jvb-consulting.io`
