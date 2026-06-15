// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {askText, askChoice, createSession} = require('../../src/lib/prompts.js');
const {Readable, Writable} = require('node:stream');

function makeStreams(input)
{
	const stdin = Readable.from([input]);
	const stdout = new Writable({
		write(_, __, cb)
		{
			cb();
		}
	});
	return {stdin, stdout};
}

test('askText reads a line and returns trimmed', async() =>
{
	const {stdin, stdout} = makeStreams('hello\n');
	const ans = await askText('? ', {stdin, stdout});
	assert.equal(ans, 'hello');
});

test('askChoice accepts an index', async() =>
{
	const {stdin, stdout} = makeStreams('2\n');
	const ans = await askChoice('? ', [
		'gearset',
		'copado',
		'none'
	], {stdin, stdout});
	assert.equal(ans, 'copado');
});

test('createSession handles many sequential prompts on a single piped stdin', async() =>
{
	const {stdin, stdout} = makeStreams('hello\n2\ny\nfinal\n');
	const session = await createSession({stdin, stdout});
	const a = await session.askText('Q1: ');
	const b = await session.askChoice('Q2: ', [
		'x',
		'y',
		'z'
	]);
	const c = await session.askYesNo('Q3?', false);
	const d = await session.askText('Q4: ');
	session.close();
	assert.equal(a, 'hello');
	assert.equal(b, 'y');
	assert.equal(c, true);
	assert.equal(d, 'final');
});

test('createSession askYesNo respects empty=default', async() =>
{
	const {stdin, stdout} = makeStreams('\n\n');
	const session = await createSession({stdin, stdout});
	const yesDefault = await session.askYesNo('?', true);
	const noDefault = await session.askYesNo('?', false);
	session.close();
	assert.equal(yesDefault, true);
	assert.equal(noDefault, false);
});
