// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for utilityGenerator LWC utility module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, October 2026
 */
import {counter, arrayGenerator} from 'c/utilityGenerator';

/** @description The most values a test reads from a counter, so a counter that never stops fails the test instead of hanging it. */
const MOST_VALUES_READ = 10;

/** @description A max with a fraction, for a counter that leaves the max out. */
const MAX_WITH_FRACTION = 3.5;

/** @description A max with a fraction, for a counter that includes the max. */
const INCLUDED_MAX_WITH_FRACTION = 2.5;

/**
 * @description Reads the values a generator gives, up to a fixed number.
 * @param {Generator} generator - The generator to read.
 * @returns {Array<*>} The values read, at most MOST_VALUES_READ of them.
 */
function readValues(generator)
{
	const values = [];
	let step = generator.next();
	while(!step.done && values.length < MOST_VALUES_READ)
	{
		values.push(step.value);
		step = generator.next();
	}
	return values;
}

describe('counter', () =>
{
	describe('basic counting', () =>
	{
		it('should count from 0 indefinitely by default', () =>
		{
			const gen = counter();
			expect(gen.next().value).toBe(0);
			expect(gen.next().value).toBe(1);
			expect(gen.next().value).toBe(2);
			expect(gen.next().value).toBe(3);
		});

		it('should count from specified initial value', () =>
		{
			const gen = counter(5);
			expect(gen.next().value).toBe(5);
			expect(gen.next().value).toBe(6);
			expect(gen.next().value).toBe(7);
		});

		it('should count from negative initial value', () =>
		{
			const gen = counter(-3);
			expect(gen.next().value).toBe(-3);
			expect(gen.next().value).toBe(-2);
			expect(gen.next().value).toBe(-1);
			expect(gen.next().value).toBe(0);
		});
	});

	describe('with max value (exclusive)', () =>
	{
		it('should stop before max value by default', () =>
		{
			const gen = counter(0, 3);
			const values = [...gen];
			expect(values).toEqual([
				0,
				1,
				2
			]);
		});

		it('should handle max value equal to initial', () =>
		{
			const gen = counter(5, 5);
			const values = [...gen];
			expect(values).toEqual([]);
		});

		it('should handle negative range', () =>
		{
			const gen = counter(-2, 1);
			const values = [...gen];
			expect(values).toEqual([
				-2,
				-1,
				0
			]);
		});
	});

	describe('with max value (inclusive)', () =>
	{
		it('should include max value when includeFinalValue is true', () =>
		{
			const gen = counter(0, 3, true);
			const values = [...gen];
			expect(values).toEqual([
				0,
				1,
				2,
				3
			]);
		});

		it('should include single value when max equals initial', () =>
		{
			const gen = counter(5, 5, true);
			const values = [...gen];
			expect(values).toEqual([5]);
		});
	});

	describe('edge cases', () =>
	{
		it('should return null on completion', () =>
		{
			const gen = counter(0, 2);
			gen.next(); // 0
			gen.next(); // 1
			const final = gen.next(); // done
			expect(final.done).toBe(true);
			expect(final.value).toBe(null);
		});

		it('stops below a max that has a fraction', () =>
		{
			expect(readValues(counter(0, MAX_WITH_FRACTION))).toEqual([
				0,
				1,
				2,
				3
			]);
		});

		it('stops below a max that has a fraction when the max is included', () =>
		{
			expect(readValues(counter(0, INCLUDED_MAX_WITH_FRACTION, true))).toEqual([
				0,
				1,
				2
			]);
		});

		it.each([
			[
				'not a number',
				Number.NaN
			],
			[
				'infinity',
				Number.POSITIVE_INFINITY
			]
		])('counts without end when the max is %s', (maxKind, max) =>
		{
			const gen = counter(0, max);
			expect(gen.next().value).toBe(0);
			expect(gen.next().value).toBe(1);
			expect(gen.next().done).toBe(false);
		});
	});
});

describe('arrayGenerator', () =>
{
	describe('ascending iteration', () =>
	{
		it('should iterate through array from beginning', () =>
		{
			const gen = arrayGenerator([
				'a',
				'b',
				'c'
			]);
			const values = [...gen];
			expect(values).toEqual([
				'a',
				'b',
				'c'
			]);
		});

		it('should start from specified index', () =>
		{
			const gen = arrayGenerator([
				'a',
				'b',
				'c',
				'd'
			], 1);
			const values = [...gen];
			expect(values).toEqual([
				'b',
				'c',
				'd'
			]);
		});

		it('should handle negative initial index', () =>
		{
			const gen = arrayGenerator([
				'a',
				'b',
				'c',
				'd'
			], -2);
			const values = [...gen];
			expect(values).toEqual([
				'c',
				'd'
			]);
		});
	});

	describe('descending iteration', () =>
	{
		it('should iterate in reverse from end', () =>
		{
			const gen = arrayGenerator([
				'a',
				'b',
				'c'
			], -1, false);
			const values = [...gen];
			expect(values).toEqual([
				'c',
				'b',
				'a'
			]);
		});

		it('should start from specified index going backwards', () =>
		{
			const gen = arrayGenerator([
				'a',
				'b',
				'c',
				'd'
			], 2, false);
			const values = [...gen];
			expect(values).toEqual([
				'c',
				'b',
				'a'
			]);
		});
	});

	describe('edge cases', () =>
	{
		it('should handle empty array', () =>
		{
			const gen = arrayGenerator([]);
			const values = [...gen];
			expect(values).toEqual([]);
		});

		it('should handle single element array', () =>
		{
			const gen = arrayGenerator(['only']);
			const values = [...gen];
			expect(values).toEqual(['only']);
		});

		it('should return null on completion', () =>
		{
			const gen = arrayGenerator(['a']);
			gen.next(); // 'a'
			const final = gen.next();
			expect(final.done).toBe(true);
			expect(final.value).toBe(null);
		});

		it('should handle array with various types', () =>
		{
			const gen = arrayGenerator([
				1,
				'two',
				{three: 3},
				[4]
			]);
			const values = [...gen];
			expect(values).toEqual([
				1,
				'two',
				{three: 3},
				[4]
			]);
		});

		it('should handle array with falsy values', () =>
		{
			const gen = arrayGenerator([
				1,
				0,
				2,
				false,
				3,
				'',
				4
			]);
			const values = [...gen];
			expect(values).toEqual([
				1,
				0,
				2,
				false,
				3,
				'',
				4
			]);
		});

		it('should handle array starting with zero', () =>
		{
			const gen = arrayGenerator([
				0,
				1,
				2
			]);
			const values = [...gen];
			expect(values).toEqual([
				0,
				1,
				2
			]);
		});

		it('should handle out of bounds initial index', () =>
		{
			const gen = arrayGenerator([
				'a',
				'b',
				'c'
			], 10);
			const values = [...gen];
			expect(values).toEqual([]);
		});

		it('should handle negative index beyond array length', () =>
		{
			const gen = arrayGenerator([
				'a',
				'b'
			], -5);
			const values = [...gen];
			expect(values).toEqual([]);
		});
	});
});
