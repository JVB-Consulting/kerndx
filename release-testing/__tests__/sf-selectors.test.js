// SPDX-License-Identifier: BUSL-1.1
const selectors = require('../e2e/helpers/sf-selectors');

describe('sf-selectors', () =>
{
	it('should export toast selectors', () =>
	{
		expect(selectors.TOAST).toBeDefined();
		expect(selectors.TOAST_SUCCESS).toBeDefined();
		expect(selectors.TOAST_ERROR).toBeDefined();
		expect(selectors.TOAST_MESSAGE).toBeDefined();
		expect(selectors.TOAST_CLOSE).toBeDefined();
	});

	it('should export spinner selector', () =>
	{
		expect(selectors.SPINNER).toBeDefined();
		expect(selectors.SPINNER).toContain('spinner');
	});

	it('should export modal selectors', () =>
	{
		expect(selectors.MODAL).toBeDefined();
		expect(selectors.MODAL_FOOTER).toBeDefined();
	});

	it('should export list view selectors', () =>
	{
		expect(selectors.LIST_VIEW).toBeDefined();
		expect(selectors.LIST_VIEW_RECORDS).toBeDefined();
	});

	it('should export record page selectors', () =>
	{
		expect(selectors.RECORD_HEADER).toBeDefined();
		expect(selectors.RECORD_DETAIL).toBeDefined();
		expect(selectors.RECORD_TAB).toBeDefined();
	});

	it('should export navigation selectors', () =>
	{
		expect(selectors.NAV_BAR).toBeDefined();
		expect(selectors.NAV_BAR_ITEM).toBeDefined();
	});

	it('should export component selectors', () =>
	{
		expect(selectors.COMBOBOX_OPTION).toBeDefined();
		expect(selectors.DATATABLE_ROW).toBeDefined();
	});

	it('should have all selectors as non-empty strings', () =>
	{
		for(const [key, value] of Object.entries(selectors))
		{
			expect(typeof value).toBe('string');
			expect(value.length).toBeGreaterThan(0);
		}
	});
});
