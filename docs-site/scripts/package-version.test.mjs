// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {resolvePackageVersion, latestDocLine, resolveVersionList} from './package-version.mjs';

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

test('latestDocLine is the highest PROMOTED line, not the in-dev versionNumber', () =>
{
	// master is on 1.3.0.NEXT but only 1.2 is released → latest docs line is 1.2.
	const sfdx = {
		packageDirectories: [{versionNumber: '1.3.0.NEXT'}],
		packageAliases: {'Kern@1.1.0-11': '04tA', 'Kern@1.2.0-1': '04tB'}
	};
	assert.equal(latestDocLine(sfdx), '1.2');
});

test('latestDocLine advances once a higher line is released', () =>
{
	const sfdx = {packageAliases: {'Kern@1.2.0-1': '04tB', 'Kern@1.3.0-1': '04tC'}};
	assert.equal(latestDocLine(sfdx), '1.3');
});

test('latestDocLine throws when no Kern@ alias exists', () =>
{
	assert.throws(() => latestDocLine({packageAliases: {'Foo@1.0': 'x'}}), /No Kern@/);
});

test('resolveVersionList with no frozen trees lists only the latest released line at /', () =>
{
	const sfdx = {packageAliases: {'Kern@1.2.0-1': '04tB'}};
	assert.deepEqual(resolveVersionList(sfdx, []), [
		{line: '1.2', label: '1.2', base: '/', latest: true}
	]);
});

test('resolveVersionList puts latest first, then frozen lines newest-first under /X.Y/', () =>
{
	// After 1.3 ships: latest is 1.3 at /, and 1.2 + 1.1 are frozen.
	const sfdx = {packageAliases: {'Kern@1.3.0-1': '04tC'}};
	assert.deepEqual(resolveVersionList(sfdx, ['1.1', '1.2']), [
		{line: '1.3', label: '1.3', base: '/', latest: true},
		{line: '1.2', label: '1.2', base: '/1.2/', latest: false},
		{line: '1.1', label: '1.1', base: '/1.1/', latest: false}
	]);
});

test('resolveVersionList drops the latest line from the frozen set and ignores junk dirs', () =>
{
	// A line equal to latest (e.g. 1.2 frozen while 1.2 is still latest) is excluded so the
	// switcher never offers /1.2/ alongside the / it already serves.
	const sfdx = {packageAliases: {'Kern@1.2.0-1': '04tB'}};
	const list = resolveVersionList(sfdx, ['1.2', '1.1', 'draft', '1.1']);
	assert.deepEqual(list.map(v => v.line), ['1.2', '1.1']);
});

test('resolveVersionList orders minors numerically (1.10 above 1.9)', () =>
{
	const sfdx = {packageAliases: {'Kern@2.0.0-1': '04tD'}};
	const list = resolveVersionList(sfdx, ['1.9', '1.10']);
	assert.deepEqual(list.map(v => v.line), ['2.0', '1.10', '1.9']);
});
