// SPDX-License-Identifier: Apache-2.0
//
// Sends an old link to a heading that moved to another page on to the heading's new place.
//
// A guide lists its moved headings in its `movedAnchors` frontmatter: the old heading id, and the
// place it moved to (`/<page-route>#<id>`). When the page opens, or its address changes to another
// `#id`, and that id is listed, the reader is taken to the new place. The address is replaced, not
// added to the history, so the Back button never returns to the old address (which would send the
// reader forward again). The new place opens after the scroll VitePress plans for the old id, so
// that scroll cannot move the new page. With scripts off the old id still exists on the guide, on an
// empty element inside the stub section that links to the new place (prepare.mjs puts it there).
//
// The new place can sit inside a closed <details>, such as a closed group of examples on the front
// page. Then the group is opened first and the page scrolls to the new place once it can be seen
// (showHashTarget). The front page uses the same helpers for its own links (KernLanding.vue).
import {getScrollOffset, withBase} from 'vitepress';
import {movedTargetFor} from './movedTarget.mjs';

/**
 * Opens every closed <details> that holds the element, the element itself included, so it can be
 * seen.
 *
 * @param {Element} element the element to show
 * @returns {boolean} true when a closed <details> was opened
 */
export function openClosedGroupsAround(element)
{
	let opened = false;
	for(let group = element.closest('details'); group; group = group.parentElement?.closest('details'))
	{
		if(!group.open)
		{
			group.open = true;
			opened = true;
		}
	}
	return opened;
}

/**
 * Scrolls the page so the element's top sits just under the top bar, where VitePress puts a heading
 * it scrolls to.
 *
 * @param {Element} element the element to scroll to
 */
export function scrollToElement(element)
{
	const padding = parseInt(window.getComputedStyle(element).paddingTop, 10) || 0;
	window.scrollTo(0, window.scrollY + element.getBoundingClientRect().top - getScrollOffset() + padding);
}

/**
 * Shows the element the address's `#id` names when it sits inside a closed <details>: opens it, then
 * scrolls to the element. The scroll waits for a timer and then a frame, so it comes after any scroll
 * VitePress has already planned for the address (that scroll was worked out while the element could
 * not be seen). When nothing had to be opened, nothing is done: VitePress scrolls to the element
 * itself.
 *
 * @param {string} hash the address's hash, with its leading `#`
 * @returns {boolean} true when a closed <details> was opened
 */
export function showHashTarget(hash)
{
	if(!hash || hash.length < 2)
	{
		return false;
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
	const element = document.getElementById(id);
	if(!element || !openClosedGroupsAround(element))
	{
		return false;
	}
	window.setTimeout(() => window.requestAnimationFrame(() => scrollToElement(element)));
	return true;
}

/**
 * Starts watching for old links on every page. Call it once, in the browser, from enhanceApp.
 *
 * @param {object} router the VitePress router
 * @returns {function(): void} the check, to run after each page change
 */
export function watchMovedAnchors(router)
{
	const follow = () =>
	{
		const target = movedTargetFor(router.route.data?.frontmatter, window.location.hash);
		if(target === null)
		{
			return;
		}
		const href = withBase(target);
		// Replace the old address first, so the router does not add a new history entry for the new one.
		window.history.replaceState(window.history.state, '', href);
		// VitePress scrolls to the old id's element on a frame. If the new page opened first, that late
		// scroll would move it, and a reader sent to the top of a whole page would land part way down.
		// When this check runs, VitePress may not have asked for that frame yet: after a link on another
		// page, it asks once the page has rendered. A timer runs only after that work is done, so the
		// frame asked for inside it comes after VitePress's on every path. The browser runs frame
		// callbacks in the order they were asked for, so the new place opens last. When the new place sits
		// in a closed group, the group is opened and the page scrolls to it once it can be seen.
		window.setTimeout(() => window.requestAnimationFrame(async() =>
		{
			await router.go(href);
			showHashTarget(window.location.hash);
		}));
	};
	window.addEventListener('hashchange', follow);
	return follow;
}
