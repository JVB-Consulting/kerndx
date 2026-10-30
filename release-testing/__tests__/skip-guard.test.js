// SPDX-License-Identifier: Apache-2.0
const namespace = {prefix: 'kern__'};
jest.mock('../e2e/helpers/sf-namespace', () => ({namespacePrefix: () => namespace.prefix}));
const {skipUnlessPackaged, INSTALLED_PACKAGE_ONLY_KINDS} = require('../e2e/helpers/skip-guard');

describe('skipUnlessPackaged', () =>
{
	it('lets a journey run on an org with the package installed', () =>
	{
		const test = {skip: jest.fn()};
		skipUnlessPackaged(test, 'masked stack frames');
		expect(test.skip).toHaveBeenCalledWith(false, 'Only the installed package shows this: masked stack frames');
	});

	it('skips it on the development org, saying why', () =>
	{
		namespace.prefix = '';
		const test = {skip: jest.fn()};
		skipUnlessPackaged(test, 'the upgrade leg');
		expect(test.skip).toHaveBeenCalledWith(true, 'Only the installed package shows this: the upgrade leg');
		expect(INSTALLED_PACKAGE_ONLY_KINDS).toHaveLength(5);
	});
});
