// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {resolvePackageVersion} from './package-version.mjs';

test('resolvePackageVersion picks the highest Kern@ alias and its 04t', () =>
{
	const sfdx = {
		packageAliases: {
			'Kern@1.0.0-121': '04tAAA', 'Kern@1.1.0-4': '04tBBB', 'Kern@1.1.0-10': '04tCCC', 'SomeOther@2.0': '04tZZZ'
		}
	};
	assert.deepEqual(resolvePackageVersion(sfdx), {version: '1.1.0-10', subscriberPackageVersionId: '04tCCC'});
});

test('resolvePackageVersion orders numerically, not lexically (10 > 9)', () =>
{
	const sfdx = {packageAliases: {'Kern@1.1.0-9': '04tNINE', 'Kern@1.1.0-10': '04tTEN'}};
	assert.equal(resolvePackageVersion(sfdx).version, '1.1.0-10');
});

test('resolvePackageVersion throws when no Kern@ alias exists', () =>
{
	assert.throws(() => resolvePackageVersion({packageAliases: {'Foo@1.0': 'x'}}), /No Kern@/);
	assert.throws(() => resolvePackageVersion({}), /No Kern@/);
});
