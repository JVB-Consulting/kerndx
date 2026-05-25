// SPDX-License-Identifier: BUSL-1.1
import {LightningElement} from 'lwc';
import {formatTemplateString, COMMA, SPACE, convertToSentenceCase, insertCharacterAtInterval} from 'kern/utilityString';
import {reduceErrors, sortBy, flattenObject} from 'kern/utilitySystem';
import {getRandomNumericString, getRandomAlphaString, generateUUID} from 'kern/utilityRandom';
import {convertObjectArrayToObject, filterObjectListById} from 'kern/utilityArray';
import utilityLogger from 'kern/utilityLogger';

export default class SubscriberUtilityTest extends LightningElement
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	runTests()
	{
		const checks = [];

		checks.push(...this.testUtilityString());
		checks.push(...this.testUtilitySystem());
		checks.push(...this.testUtilityRandom());
		checks.push(...this.testUtilityArray());
		checks.push(...this.testUtilityLoggerApi());

		this.results = checks.map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}

	testUtilityString()
	{
		const checks = [];

		const formatted = formatTemplateString('Hello {0}, welcome to {1}', [
			'World',
			'Kern'
		]);
		checks.push({name: 'formatTemplateString', pass: formatted === 'Hello World, welcome to Kern'});

		checks.push({name: 'COMMA constant', pass: COMMA === ','});
		checks.push({name: 'SPACE constant', pass: SPACE === ' '});

		const sentence = convertToSentenceCase('hello world. goodbye world.');
		checks.push({name: 'convertToSentenceCase', pass: sentence.startsWith('Hello')});

		const inserted = insertCharacterAtInterval('1234567890', 4, '-');
		checks.push({name: 'insertCharacterAtInterval', pass: inserted === '1234-5678-90'});

		return checks;
	}

	testUtilitySystem()
	{
		const checks = [];

		const reduced = reduceErrors([{message: 'Test error'}]);
		checks.push({name: 'reduceErrors', pass: reduced.includes('Test error')});

		const comparator = sortBy('name', 1);
		const sorted = [
			{name: 'B'},
			{name: 'A'}
		].sort(comparator);
		checks.push({name: 'sortBy', pass: sorted[0].name === 'A'});

		const flat = flattenObject({a: {b: 1, c: {d: 2}}});
		checks.push({name: 'flattenObject', pass: flat['a.b'] === 1 && flat['a.c.d'] === 2});

		return checks;
	}

	testUtilityRandom()
	{
		const checks = [];

		const numeric = getRandomNumericString(8);
		checks.push({name: 'getRandomNumericString', pass: numeric.length === 8 && /^\d+$/.test(numeric)});

		const alpha = getRandomAlphaString(10);
		checks.push({name: 'getRandomAlphaString', pass: alpha.length === 10 && /^[A-Za-z]+$/.test(alpha)});

		const uuid = generateUUID();
		const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
		checks.push({name: 'generateUUID', pass: uuidPattern.test(uuid)});

		return checks;
	}

	testUtilityArray()
	{
		const checks = [];

		const items = [
			{id: '001', name: 'A'},
			{id: '002', name: 'B'},
			{id: '003', name: 'C'}
		];
		const lookup = convertObjectArrayToObject(items, 'id');
		checks.push({name: 'convertObjectArrayToObject', pass: lookup['001']?.name === 'A' && lookup['002']?.name === 'B'});

		const filtered = filterObjectListById(items, [
			'001',
			'003'
		], 'id');
		checks.push({name: 'filterObjectListById', pass: filtered.length === 2 && filtered[0].name === 'A'});

		return checks;
	}

	testUtilityLoggerApi()
	{
		const checks = [];

		checks.push({name: 'logger.info', pass: typeof utilityLogger.info === 'function'});
		checks.push({name: 'logger.error', pass: typeof utilityLogger.error === 'function'});
		checks.push({name: 'logger.warn', pass: typeof utilityLogger.warn === 'function'});
		checks.push({name: 'logger.debug', pass: typeof utilityLogger.debug === 'function'});
		checks.push({name: 'logger.withCorrelation', pass: typeof utilityLogger.withCorrelation === 'function'});
		checks.push({name: 'logger.startTimer', pass: typeof utilityLogger.startTimer === 'function'});

		return checks;
	}

	async testLoggerPersistence()
	{
		utilityLogger.info('Subscriber LWC logger persistence test');
	}
}
