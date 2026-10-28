---
navOrder: 96
---

# Documentation Site - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Publishing a searchable documentation site for their team straight from their clone of this repository
- **DevOps / Release Engineers** - Wiring the site into GitHub Pages, with either a GitHub-hosted URL or a custom domain

---

## Overview

This repository ships with a complete, self-hosting documentation site: the guides, Fast Starts, and full API reference you are reading now, built as a fast, searchable static site. The same pipeline that publishes it for KernDX works unchanged in **your** clone: enable it and your team gets its own copy of the documentation at a URL you control, rebuilt automatically every time you pull a new release or add your own pages.

Publishing is controlled entirely by three repository variables. No code changes are required.

| Variable | Value | Purpose |
| --- | --- | --- |
| `ENABLE_DOCS_DEPLOY` | `true` | Master switch. Unset, the workflow only *builds* the site as a quality gate and never deploys. |
| `DOCS_BASE` | `/<repo-name>/` or unset | URL base path. Set it for a GitHub-hosted project URL; leave it unset for a custom domain served at the root. |
| `DOCS_CNAME` | `docs.example.com` or unset | Custom domain to register with GitHub Pages. Leave unset for a GitHub-hosted URL. |

The site is generated from this repository's `docs/` folder and `README.md` by the `docs-site/` project, and built/deployed by the `docs` workflow in `.github/workflows/docs.yml`. The build enforces a strict quality gate (zero dead links, render smoke-test) before anything deploys.

## Prerequisites

- Your clone of this repository pushed to GitHub, with GitHub Actions enabled (forks: Actions must be enabled once under the repository's **Actions** tab).
- Repository admin access.
- The `gh` CLI authenticated (`gh auth login`), or use the GitHub web console paths given alongside each command.

Every step below is a copy-paste command. Replace `YourOrg/YourRepo` (and for custom domains, `docs.example.com`) with your values.

## Option A: Publish at your GitHub Pages URL

The fastest path. Your site appears at `https://YourOrg.github.io/YourRepo/`.

```shell
gh api -X POST repos/YourOrg/YourRepo/pages -f build_type=workflow

gh variable set ENABLE_DOCS_DEPLOY --repo YourOrg/YourRepo --body true
gh variable set DOCS_BASE --repo YourOrg/YourRepo --body "/YourRepo/"

gh workflow run docs.yml --repo YourOrg/YourRepo
```

Console equivalent: **Settings → Pages → Source: GitHub Actions**, then **Settings → Secrets and variables → Actions → Variables** to add the two variables, then **Actions → docs → Run workflow**.

> The trailing and leading slashes in `DOCS_BASE` matter: `/YourRepo/`, exactly. A wrong base is the most common cause of a deployed site with broken styling.

## Option B: Publish on a custom domain

Serve the site at a domain you own, like `docs.example.com`.

**1. DNS.** At your DNS provider, create a CNAME record pointing your subdomain at your GitHub Pages hostname:

```
docs.example.com  CNAME  YourOrg.github.io.
```

Verify propagation before continuing (an agent can poll this), with the command for your computer:

**Windows (Command Prompt)**

```bat
nslookup -type=CNAME docs.example.com
```

**macOS or Linux**

```bash
dig +short docs.example.com CNAME
```

Expected output: your GitHub Pages hostname, `YourOrg.github.io`, which nslookup prints after `canonical name =` (a Mac adds a trailing dot).

**2. Enable publishing.** Same as Option A, but set the domain instead of a base path (the site is served at the domain root, so `DOCS_BASE` stays unset):

```shell
gh api -X POST repos/YourOrg/YourRepo/pages -f build_type=workflow

gh variable set ENABLE_DOCS_DEPLOY --repo YourOrg/YourRepo --body true
gh variable set DOCS_CNAME --repo YourOrg/YourRepo --body docs.example.com

gh workflow run docs.yml --repo YourOrg/YourRepo
```

The first deploy writes a `CNAME` file into the site, which registers the custom domain with GitHub Pages automatically.

**3. HTTPS.** Once GitHub has provisioned the TLS certificate (usually minutes, occasionally up to an hour), enforce HTTPS:

```shell
gh api -X PUT repos/YourOrg/YourRepo/pages -f cname=docs.example.com -F https_enforced=true
```

Console equivalent: **Settings → Pages → Enforce HTTPS** (the checkbox becomes available when the certificate is ready).

## Verify the deploy

Find the latest docs run and its ID:

```shell
gh run list --repo YourOrg/YourRepo --workflow docs.yml --limit 1
```

Watch that run, replacing `YourRunId` with the ID the list printed:

```shell
gh run watch --repo YourOrg/YourRepo YourRunId
```

Then ask the site for its headers:

```shell
curl -sI https://YourSiteUrl/
```

A healthy deploy shows the `build` job green (the strict gate), the `deploy` job green, and the `curl` output with a first line that shows the status code `200`. Then spot-check in a browser: the home page, one guide, one API reference page, and search.

## Keeping the site current

Every push to your default branch that touches `docs/`, `README.md`, release notes, or the site pipeline rebuilds and redeploys automatically, including when you pull in a new KernDX release. No manual steps after the one-time setup.

## Adding your own pages

Drop Markdown files into `docs/` and push: each becomes a page with a clean URL, appears in the sidebar, and is indexed by search automatically. (Search indexes prose only: fenced code is left out of the index on every page, and an API reference page contributes only the text above its first member section, its heading and summary, so the index a reader downloads on their first search stays small.) File naming controls sidebar grouping:

- Names ending in " - Guide" land under **Guides**
- Names starting with "Fast Start - " land under **Fast Starts**
- Anything else lands under **Getting Started**

Internal links between pages are plain relative Markdown links (`[Selectors](Selectors%20-%20Guide.md)`); the build resolves them and fails loudly on any link that points nowhere, so a broken link never ships.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Workflow runs but the deploy job is skipped | `ENABLE_DOCS_DEPLOY` unset or not exactly `true`, or the run came from a pull request (PRs never deploy) | Set the variable, then re-run via push or **Run workflow** |
| Site deploys but styling/assets are broken | `DOCS_BASE` does not match the URL the site is served from | GitHub URL → `/YourRepo/`; custom domain → unset the variable |
| Custom domain shows "pending" or certificate errors | DNS not yet propagated, or certificate still provisioning | Confirm the `nslookup` or `dig` output, wait, then enforce HTTPS |
| Workflow never starts | Actions disabled (common on fresh forks) | Enable workflows under the **Actions** tab |
| Pages URL returns 404 right after a green deploy | Pages propagation lag | Wait a minute and retry |
| Build job fails | The strict gate caught a real problem (usually a dead link in an added page) | Open the failed `build` step log; fix the link it names |
