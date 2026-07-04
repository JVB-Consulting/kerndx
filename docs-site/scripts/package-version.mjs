// SPDX-License-Identifier: BUSL-1.1
// Resolve the highest released package version + its subscriber id from a parsed
// sfdx-project.json. The docs site feeds these into the public-README synthesizer so the
// home page shows real install commands (version + 04t) instead of placeholders.
//
// Pure: takes the already-parsed object, returns { version, subscriberPackageVersionId }.
// Mirrors scripts/manifest-lib.js resolveVersion (the canonical resolver), kept self-
// contained here because the docs site builds with its own dependency tree, separate from
// the repo's CJS tooling. Throws when no Kern@X.Y.Z-N alias exists.
export function resolvePackageVersion(sfdx)
{
	const aliases = (sfdx && sfdx.packageAliases) || {};
	const numbered = Object.entries(aliases)
	.map(([key, id]) =>
	{
		const m = key.match(/^Kern@(\d+)\.(\d+)\.(\d+)-(\d+)$/);
		return m ? {
			version: `${m[1]}.${m[2]}.${m[3]}-${m[4]}`,
			id,
			sortKey: [
				+m[1],
				+m[2],
				+m[3],
				+m[4]
			]
		} : null;
	})
	.filter(Boolean);
	if(numbered.length === 0)
	{
		throw new Error('No Kern@X.Y.Z-N packageAliases found in sfdx-project.json');
	}
	numbered.sort((a, b) =>
	{
		for(let i = 0; i < 4; i++)
		{
			if(a.sortKey[i] !== b.sortKey[i])
			{
				return b.sortKey[i] - a.sortKey[i];
			}
		}
		return 0;
	});
	return {version: numbered[0].version, subscriberPackageVersionId: numbered[0].id};
}

// The "latest" docs tree at / is the highest PROMOTED/released package line — the one that
// has actually been pushed to the mirror that serves the site — NOT the in-development
// versionNumber. The mirror only ever holds released content, so a version is "latest" only
// once it is promoted and synced (e.g. while master is on 1.3.0.NEXT but only 1.2 is
// released, latest is "1.2"; "1.3" appears here only after 1.3 ships). The highest Kern@
// alias is the build-time proxy for "latest released" (the release dance adds the alias as
// part of promoting + pushing). Throws (via resolvePackageVersion) when no alias exists.
export function latestDocLine(sfdx)
{
	const {version} = resolvePackageVersion(sfdx);   // highest Kern@X.Y.Z-N alias, e.g. "1.2.0-1"
	const m = version.match(/^(\d+)\.(\d+)\./);
	return `${m[1]}.${m[2]}`;
}

// Newer minor line first (1.3 before 1.2 before 1.1). Inputs are validated "X.Y" strings.
function compareLinesDescending(a, b)
{
	const [aMajor, aMinor] = a.split('.').map(Number);
	const [bMajor, bMinor] = b.split('.').map(Number);
	return (bMajor - aMajor) || (bMinor - aMinor);
}

// Build the version-switcher list. The latest line (from versionNumber) always heads the
// list at base "/"; each frozen line that has a committed snapshot follows under "/X.Y/",
// newest first. frozenLines is the set of docs-versions/<line>/ directories that exist
// (Phase 1 has none → the list is just [latest]; Phase 2 adds 1.2 and 1.1). The frozen set,
// not the package aliases, is the deploy-truth: a line only appears once a tree is built for
// it, so the switcher can never offer a 404. Pre-release "-N" build numbers never appear.
export function resolveVersionList(sfdx, frozenLines = [])
{
	const latest = latestDocLine(sfdx);
	const list = [{line: latest, label: latest, base: '/', latest: true}];
	const frozen = [...new Set(frozenLines)]
	.filter(line => /^\d+\.\d+$/.test(line) && line !== latest);
	frozen.sort(compareLinesDescending);
	for(const line of frozen)
	{
		list.push({line, label: line, base: `/${line}/`, latest: false});
	}
	return list;
}
