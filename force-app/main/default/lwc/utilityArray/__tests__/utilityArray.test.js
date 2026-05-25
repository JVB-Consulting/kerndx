// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for utilityArray LWC utility module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, May 2026
 */
import {convertObjectArrayToObject, extractListOfObjectsById, filterObjectListById} from 'c/utilityArray';

describe('convertObjectArrayToObject', () =>
{
	describe('basic functionality', () =>
	{
		it('should convert array to object keyed by field value', () =>
		{
			const array = [
				{id: '001', name: 'Account A'},
				{id: '002', name: 'Account B'},
				{id: '003', name: 'Account C'}
			];
			const result = convertObjectArrayToObject(array, 'id');
			expect(result['001']).toEqual({id: '001', name: 'Account A'});
			expect(result['002']).toEqual({id: '002', name: 'Account B'});
			expect(result['003']).toEqual({id: '003', name: 'Account C'});
		});

		it('should handle numeric keys', () =>
		{
			const array = [
				{index: 1, value: 'first'},
				{index: 2, value: 'second'}
			];
			const result = convertObjectArrayToObject(array, 'index');
			expect(result[1]).toEqual({index: 1, value: 'first'});
			expect(result[2]).toEqual({index: 2, value: 'second'});
		});
	});

	describe('duplicate key handling', () =>
	{
		it('should group objects with same key into array', () =>
		{
			const array = [
				{type: 'A', value: 1},
				{type: 'A', value: 2},
				{type: 'B', value: 3}
			];
			const result = convertObjectArrayToObject(array, 'type');
			expect(result.A).toEqual([
				{type: 'A', value: 1},
				{type: 'A', value: 2}
			]);
			expect(result.B).toEqual({type: 'B', value: 3});
		});

		it('should handle three or more duplicates', () =>
		{
			const array = [
				{category: 'X', id: 1},
				{category: 'X', id: 2},
				{category: 'X', id: 3}
			];
			const result = convertObjectArrayToObject(array, 'category');
			expect(result.X).toEqual([
				{category: 'X', id: 1},
				{category: 'X', id: 2},
				{category: 'X', id: 3}
			]);
		});
	});

	describe('missing field handling', () =>
	{
		it('should place objects without field in undefined list', () =>
		{
			const array = [
				{id: '001', name: 'Has ID'},
				{name: 'No ID'},
				{id: '002', name: 'Also has ID'}
			];
			const result = convertObjectArrayToObject(array, 'id');
			expect(result['001']).toEqual({id: '001', name: 'Has ID'});
			expect(result['002']).toEqual({id: '002', name: 'Also has ID'});
			expect(result.undefined).toEqual([{name: 'No ID'}]);
		});

		it('should handle all objects missing the field', () =>
		{
			const array = [
				{name: 'Object A'},
				{name: 'Object B'}
			];
			const result = convertObjectArrayToObject(array, 'id');
			expect(result.undefined).toEqual([
				{name: 'Object A'},
				{name: 'Object B'}
			]);
		});

		it('should initialize undefined list even with no missing fields', () =>
		{
			const array = [
				{id: '001', name: 'A'}
			];
			const result = convertObjectArrayToObject(array, 'id');
			expect(result.undefined).toEqual([]);
		});
	});

	describe('edge cases', () =>
	{
		it('should handle empty array', () =>
		{
			const result = convertObjectArrayToObject([], 'id');
			expect(result).toEqual({undefined: []});
		});

		it('should handle objects with undefined field value', () =>
		{
			const array = [
				{id: undefined, name: 'Has undefined ID'}
			];
			const result = convertObjectArrayToObject(array, 'id');
			// Objects with undefined field value are grouped with the undefined array
			// since their key collides with the pre-initialized undefined list
			expect(result.undefined).toEqual([{id: undefined, name: 'Has undefined ID'}]);
		});

		it('should handle objects with null field value', () =>
		{
			const array = [
				{id: null, name: 'Has null ID'}
			];
			const result = convertObjectArrayToObject(array, 'id');
			expect(result.null).toEqual({id: null, name: 'Has null ID'});
		});
	});
});

describe('extractListOfObjectsById', () =>
{
	it('should extract objects by their IDs from a map', () =>
	{
		const objectMap = {
			'001': {id: '001', name: 'A'}, '002': {id: '002', name: 'B'}, '003': {id: '003', name: 'C'}
		};
		const result = extractListOfObjectsById(objectMap, [
			'001',
			'003'
		]);
		expect(result).toEqual([
			{id: '001', name: 'A'},
			{id: '003', name: 'C'}
		]);
	});

	it('should return undefined for missing IDs', () =>
	{
		const objectMap = {
			'001': {id: '001', name: 'A'}
		};
		const result = extractListOfObjectsById(objectMap, [
			'001',
			'999'
		]);
		expect(result).toEqual([
			{id: '001', name: 'A'},
			undefined
		]);
	});

	it('should handle empty ID list', () =>
	{
		const objectMap = {
			'001': {id: '001', name: 'A'}
		};
		const result = extractListOfObjectsById(objectMap, []);
		expect(result).toEqual([]);
	});

	it('should handle empty object map', () =>
	{
		const result = extractListOfObjectsById({}, ['001']);
		expect(result).toEqual([undefined]);
	});

	it('should preserve order of ID list', () =>
	{
		const objectMap = {
			'001': {id: '001', name: 'A'}, '002': {id: '002', name: 'B'}, '003': {id: '003', name: 'C'}
		};
		const result = extractListOfObjectsById(objectMap, [
			'003',
			'001',
			'002'
		]);
		expect(result).toEqual([
			{id: '003', name: 'C'},
			{id: '001', name: 'A'},
			{id: '002', name: 'B'}
		]);
	});
});

describe('filterObjectListById', () =>
{
	it('should filter objects by ID field', () =>
	{
		const objectList = [
			{id: '001', name: 'A'},
			{id: '002', name: 'B'},
			{id: '003', name: 'C'}
		];
		const result = filterObjectListById(objectList, [
			'001',
			'003'
		], 'id');
		expect(result).toEqual([
			{id: '001', name: 'A'},
			{id: '003', name: 'C'}
		]);
	});

	it('should work with custom ID field name', () =>
	{
		const objectList = [
			{recordId: 'A1', value: 10},
			{recordId: 'B2', value: 20},
			{recordId: 'C3', value: 30}
		];
		const result = filterObjectListById(objectList, [
			'A1',
			'C3'
		], 'recordId');
		expect(result).toEqual([
			{recordId: 'A1', value: 10},
			{recordId: 'C3', value: 30}
		]);
	});

	it('should return empty array when no matches', () =>
	{
		const objectList = [
			{id: '001', name: 'A'},
			{id: '002', name: 'B'}
		];
		const result = filterObjectListById(objectList, ['999'], 'id');
		expect(result).toEqual([]);
	});

	it('should handle empty object list', () =>
	{
		const result = filterObjectListById([], ['001'], 'id');
		expect(result).toEqual([]);
	});

	it('should handle empty ID list', () =>
	{
		const objectList = [
			{id: '001', name: 'A'}
		];
		const result = filterObjectListById(objectList, [], 'id');
		expect(result).toEqual([]);
	});

	it('should preserve original order', () =>
	{
		const objectList = [
			{id: '001', name: 'A'},
			{id: '002', name: 'B'},
			{id: '003', name: 'C'}
		];
		const result = filterObjectListById(objectList, [
			'003',
			'001'
		], 'id');
		expect(result).toEqual([
			{id: '001', name: 'A'},
			{id: '003', name: 'C'}
		]);
	});
});
