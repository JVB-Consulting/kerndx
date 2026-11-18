// SPDX-License-Identifier: Apache-2.0
//
// Reads where an old link to a moved heading should go. It needs nothing from the browser or from
// VitePress, so the unit tests can load it (scripts/moved-target.test.mjs); movedAnchors.mjs uses it.

/**
 * Returns the new place of the heading named by the address's `#id`, or null when it did not move.
 *
 * @param {object} frontmatter the page's frontmatter
 * @param {string} hash the address's hash, with its leading `#`
 * @returns {string|null} the new place, as `/<page-route>#<id>`
 */
export function movedTargetFor(frontmatter, hash)
{
	const moved = frontmatter?.movedAnchors;
	if(!moved || typeof moved !== 'object' || !hash || hash.length < 2)
	{
		return null;
	}
	let id;
	try
	{
		id = decodeURIComponent(hash.slice(1));
	}
	catch
	{
		id = hash.slice(1);
	}
	return Object.hasOwn(moved, id) && typeof moved[id] === 'string' ? moved[id] : null;
}
