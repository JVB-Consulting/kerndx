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
