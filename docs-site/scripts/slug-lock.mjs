// SPDX-License-Identifier: BUSL-1.1
import {readFile} from 'node:fs/promises';

// Pure diff: returns { added, removedWithoutRedirect }.
export function diffSlugs(lockedSlugs, currentSlugs, redirects)
{
	const cur = new Set(currentSlugs);
	const locked = new Set(lockedSlugs);
	const added = [...cur].filter(s => !locked.has(s)).sort();
	const removedWithoutRedirect = [...locked]
	.filter(s => !cur.has(s))
	.filter(s => !Object.hasOwn(redirects, s))
	.sort();
	return {added, removedWithoutRedirect};
}

// Reads slugs.lock.json (tolerating absence on first run) and redirects.json.
export async function loadLock(lockPath, redirectsPath)
{
	let locked = [];
	try
	{
		locked = JSON.parse(await readFile(lockPath, 'utf8')).slugs || [];
	}
	catch
	{
		locked = [];
	}
	const redirects = JSON.parse(await readFile(redirectsPath, 'utf8'));
	return {locked, redirects};
}
