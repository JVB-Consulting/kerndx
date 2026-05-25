// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for moduleNavigation LWC module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, May 2026
 */
import initialiseNavigationModule, {
	STANDARD_RECORD_PAGE_PAGE_REFERENCE_TYPE, VIEW_ACTION_NAME, getStandardRecordPageReference, initialiseRedirectToRecordPage, initialiseGenerateRecordPageURL
} from 'c/moduleNavigation';

describe('moduleNavigation', () =>
{
	describe('constants', () =>
	{
		it('should export STANDARD_RECORD_PAGE_PAGE_REFERENCE_TYPE', () =>
		{
			expect(STANDARD_RECORD_PAGE_PAGE_REFERENCE_TYPE).toBe('standard__recordPage');
		});

		it('should export VIEW_ACTION_NAME', () =>
		{
			expect(VIEW_ACTION_NAME).toBe('view');
		});
	});

	describe('getStandardRecordPageReference', () =>
	{
		it('should create page reference for record ID', () =>
		{
			const recordId = '001xx000003ABCD';
			const result = getStandardRecordPageReference(recordId);

			expect(result).toEqual({
				type: 'standard__recordPage', attributes: {
					recordId: '001xx000003ABCD', actionName: 'view'
				}
			});
		});

		it('should handle different record ID formats', () =>
		{
			const recordId = '003xx000004EFGH';
			const result = getStandardRecordPageReference(recordId);

			expect(result.attributes.recordId).toBe('003xx000004EFGH');
		});
	});

	describe('initialiseRedirectToRecordPage', () =>
	{
		it('should add redirectToRecordPage method to component', () =>
		{
			const mockComponent = {
				navigationHandler: jest.fn()
			};

			initialiseRedirectToRecordPage(mockComponent);

			expect(typeof mockComponent.redirectToRecordPage).toBe('function');
		});

		it('should call navigationHandler with correct page reference', () =>
		{
			const mockComponent = {
				navigationHandler: jest.fn()
			};

			initialiseRedirectToRecordPage(mockComponent);
			mockComponent.redirectToRecordPage('001xx000003ABCD');

			expect(mockComponent.navigationHandler).toHaveBeenCalledWith({
				type: 'standard__recordPage', attributes: {
					recordId: '001xx000003ABCD', actionName: 'view'
				}
			});
		});
	});

	describe('initialiseGenerateRecordPageURL', () =>
	{
		it('should add generateRecordPageURL method to component', () =>
		{
			const mockComponent = {
				generateUrlHandler: jest.fn()
			};

			initialiseGenerateRecordPageURL(mockComponent);

			expect(typeof mockComponent.generateRecordPageURL).toBe('function');
		});

		it('should call generateUrlHandler with correct page reference', () =>
		{
			const mockUrl = '/lightning/r/Account/001xx000003ABCD/view';
			const mockComponent = {
				generateUrlHandler: jest.fn().mockReturnValue(mockUrl)
			};

			initialiseGenerateRecordPageURL(mockComponent);
			const result = mockComponent.generateRecordPageURL('001xx000003ABCD');

			expect(mockComponent.generateUrlHandler).toHaveBeenCalledWith({
				type: 'standard__recordPage', attributes: {
					recordId: '001xx000003ABCD', actionName: 'view'
				}
			});
			expect(result).toBe(mockUrl);
		});

		it('should return result from generateUrlHandler', () =>
		{
			const expectedUrl = '/custom/path';
			const mockComponent = {
				generateUrlHandler: jest.fn().mockReturnValue(expectedUrl)
			};

			initialiseGenerateRecordPageURL(mockComponent);
			const result = mockComponent.generateRecordPageURL('003xx000004EFGH');

			expect(result).toBe(expectedUrl);
		});
	});

	describe('initialiseNavigationModule (default export)', () =>
	{
		it('should add both navigation methods to component', () =>
		{
			const mockComponent = {
				navigationHandler: jest.fn(), generateUrlHandler: jest.fn()
			};

			initialiseNavigationModule(mockComponent);

			expect(typeof mockComponent.redirectToRecordPage).toBe('function');
			expect(typeof mockComponent.generateRecordPageURL).toBe('function');
		});

		it('should allow both methods to work correctly', () =>
		{
			const mockComponent = {
				navigationHandler: jest.fn(), generateUrlHandler: jest.fn().mockReturnValue('/test/url')
			};

			initialiseNavigationModule(mockComponent);

			// Test redirect
			mockComponent.redirectToRecordPage('001xx');
			expect(mockComponent.navigationHandler).toHaveBeenCalled();

			// Test URL generation
			const url = mockComponent.generateRecordPageURL('001xx');
			expect(mockComponent.generateUrlHandler).toHaveBeenCalled();
			expect(url).toBe('/test/url');
		});
	});
});
