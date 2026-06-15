// SPDX-License-Identifier: BUSL-1.1
// Canonical GitHub repository URL for the docs site's "back to repo" nav link
// (the VitePress GitHub social icon). Defaults to the production mirror; the docs
// workflow derives it per-repo from the GitHub Actions context
// (github.server_url/github.repository) and passes it as REPO_URL, so a clone,
// rehearsal, or ephemeral repo links its docs site back to ITSELF rather than to
// the production mirror — the same per-repo override pattern as DOCS_BASE.
export const DEFAULT_REPO_URL = 'https://github.com/JVB-Consulting/kerndx';

export function repoUrl(env = process.env)
{
	const v = env && typeof env.REPO_URL === 'string' ? env.REPO_URL.trim() : '';
	return v || DEFAULT_REPO_URL;
}
