// SPDX-License-Identifier: BUSL-1.1
/**
 * @description JavaScript generator utilities for LWC — sequential counters and
 * bidirectional array iterators.
 *
 * @author Jason van Beukering
 *
 * @date June 2021, February 2022, March 2026
 */

/**
 * @description Yields sequential integers starting from `start`. Stops at `max` when provided;
 * continues indefinitely when `max` is null.
 *
 * @param {number} [start=0] - First value in the sequence
 * @param {number|null} [max=null] - Upper bound (null for unbounded)
 * @param {boolean} [inclusive=false] - When true, the `max` value itself is yielded
 * @yields {number} The next integer in the sequence
 * @returns {Generator<number, null, void>}
 *
 * @example
 * [...counter(0, 3)]        // [0, 1, 2]
 * [...counter(1, 5, true)]  // [1, 2, 3, 4, 5]
 */
export function* counter(start = 0, max = null, inclusive = false)
{
	const hasLimit = Number.isInteger(max);
	const withinBound = inclusive ? (current) => current <= max : (current) => current < max;

	let current = start;

	while(!hasLimit || withinBound(current))
	{
		yield current;
		current++;
	}

	return null;
}

/**
 * @description Iterates through array elements from a given starting index, forward or backward.
 * Supports negative indices following the `Array.at()` convention.
 *
 * @param {Array<*>} array - Source array
 * @param {number} [startIndex=0] - Starting position (negative values count from end)
 * @param {boolean} [ascending=true] - Direction: `true` = left-to-right, `false` = right-to-left
 * @yields {*} The next element in the iteration
 * @returns {Generator<*, null, void>}
 *
 * @example
 * [...arrayGenerator(['a', 'b', 'c'])]            // ['a', 'b', 'c']
 * [...arrayGenerator(['a', 'b', 'c'], -1, false)]  // ['c', 'b', 'a']
 */
export function* arrayGenerator(array, startIndex = 0, ascending = true)
{
	if(array.length === 0)
	{
		return null;
	}

	let position = startIndex < 0 ? array.length + startIndex : startIndex;

	if(position < 0 || position >= array.length)
	{
		return null;
	}

	const step = ascending ? 1 : -1;

	while(position >= 0 && position < array.length)
	{
		yield array[position];
		position += step;
	}

	return null;
}