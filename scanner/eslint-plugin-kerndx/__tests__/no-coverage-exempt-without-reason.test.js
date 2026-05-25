// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const {RuleTester} = require('eslint');
const rule = require('../rules/no-coverage-exempt-without-reason');

const ruleTester = new RuleTester({parserOptions: {ecmaVersion: 2022, sourceType: 'module'}});

test('no-coverage-exempt-without-reason', () => {
	ruleTester.run('no-coverage-exempt-without-reason', rule, {
	valid: [
		{
			code: '// kern-coverage-exempt: platform limit on async callback timing\nconst value = 1;',
			name: 'valid exemption with sufficient platform-limitation reason'
		},
		{
			code: '// regular comment\nconst value = 1;',
			name: 'unrelated comment is ignored'
		},
		{
			code: '// kern-coverage-exempt: unreachable under System.LimitException only\nconst value = 1;',
			name: 'valid exemption citing System.LimitException'
		},
		{
			code: '/* kern-coverage-exempt: block comments are not matched */\nconst value = 1;',
			name: 'block comments are not matched (line rule only)'
		},
		{
			code: '// kern-coverage-exempt: LMS adapter mock is async, covers branch\nconst value = 1;',
			name: 'reason exceeding 15 chars passes'
		}
	],

	invalid: [
		{
			code: '// kern-coverage-exempt:\nconst value = 1;',
			name: 'empty reason is flagged',
			errors: [{messageId: 'empty'}]
		},
		{
			code: '// kern-coverage-exempt: too short\nconst value = 1;',
			name: 'reason under 15 chars is flagged',
			errors: [{messageId: 'tooShort', data: {min: '15', length: '9'}}]
		},
		{
			code: '// kern-coverage-exempt: hard to test even with mocks\nconst value = 1;',
			name: '"hard to test" phrase is blocklisted',
			errors: [{messageId: 'blocked', data: {reason: 'hard to test even with mocks', match: 'hard to test'}}]
		},
		{
			code: '// kern-coverage-exempt: this is tricky to reproduce\nconst value = 1;',
			name: '"tricky" is blocklisted',
			errors: [{messageId: 'blocked', data: {reason: 'this is tricky to reproduce', match: 'tricky'}}]
		},
		{
			code: '// kern-coverage-exempt: TODO revisit when platform ships\nconst value = 1;',
			name: '"TODO" is blocklisted (case-insensitive)',
			errors: [{messageId: 'blocked', data: {reason: 'TODO revisit when platform ships', match: 'todo'}}]
		},
		{
			code: '// kern-coverage-exempt: FIXME before next release\nconst value = 1;',
			name: '"FIXME" is blocklisted',
			errors: [{messageId: 'blocked', data: {reason: 'FIXME before next release', match: 'fixme'}}]
		},
		{
			code: '// kern-coverage-exempt: will revisit later this quarter\nconst value = 1;',
			name: '"later" is blocklisted',
			errors: [{messageId: 'blocked', data: {reason: 'will revisit later this quarter', match: 'later'}}]
		},
		{
			code: '// kern-coverage-exempt: xxx placeholder for now\nconst value = 1;',
			name: '"xxx" is blocklisted',
			errors: [{messageId: 'blocked', data: {reason: 'xxx placeholder for now', match: 'xxx'}}]
		},
		{
			code: '// kern-coverage-exempt: temporary hack around SObject limit\nconst value = 1;',
			name: '"hack" is blocklisted',
			errors: [{messageId: 'blocked', data: {reason: 'temporary hack around SObject limit', match: 'hack'}}]
		},
		{
			code: '//   kern-coverage-exempt   :   \nconst value = 1;',
			name: 'loose whitespace with empty reason is flagged',
			errors: [{messageId: 'empty'}]
		}
	]
	});
});
