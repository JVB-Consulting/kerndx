// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Collection utilities for LWC — grouping, lookup, and filtering operations
 * on arrays of plain objects.
 *
 * @author Jason van Beukering
 *
 * @date June 2021, February 2024, March 2026
 */

/**
 * @description Groups an array of objects by a key field into a lookup object.
 * When multiple objects share the same key, they are collected into an array.
 * Objects missing the key field are placed in an `undefined` bucket.
 *
 * @param {Object[]} items - Source array of objects
 * @param {string} keyField - Property name whose value becomes the lookup key
 * @returns {Object<string, Object|Object[]>} Keyed lookup (single object per key, or array when duplicates exist)
 *
 * @example
 * convertObjectArrayToObject([{id: '001', name: 'A'}, {id: '002', name: 'B'}], 'id')
 * // => {'001': {id: '001', name: 'A'}, '002': {id: '002', name: 'B'}, undefined: []}
 */
export function convertObjectArrayToObject(items, keyField)
{
	const lookup = {undefined: []};

	for(const item of items)
	{
		if(!(keyField in item))
		{
			lookup.undefined.push(item);
			continue;
		}

		const key = item[keyField];
		const existing = lookup[key];

		if(existing === undefined)
		{
			lookup[key] = item;
		}
		else if(Array.isArray(existing))
		{
			existing.push(item);
		}
		else
		{
			lookup[key] = [
				existing,
				item
			];
		}
	}

	return lookup;
}

/**
 * @description Retrieves objects from a keyed map in the order specified by an ID list.
 * Returns `undefined` for any ID not present in the map.
 *
 * @param {Object<string, *>} objectMap - Map keyed by ID
 * @param {string[]} idList - Ordered list of IDs to retrieve
 * @returns {*[]} Objects in the same order as `idList`
 */
export function extractListOfObjectsById(objectMap, idList)
{
	return idList.map((id) => objectMap[id]);
}

/**
 * @description Filters an array to only include objects whose ID field value appears
 * in the provided inclusion list. Original array order is preserved.
 *
 * @param {Object[]} objectList - Source array to filter
 * @param {*[]} idList - Values to include
 * @param {string} idField - Property name containing the ID value
 * @returns {Object[]} Filtered array
 */
export function filterObjectListById(objectList, idList, idField)
{
	const idSet = new Set(idList);
	return objectList.filter((item) => idSet.has(item[idField]));
}