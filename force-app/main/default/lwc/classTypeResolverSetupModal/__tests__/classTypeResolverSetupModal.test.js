// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for classTypeResolverSetupModal LWC component.
 *
 * @author Jason van Beukering
 * @date April 2026, May 2026
 */
jest.mock('lightning/modal', () =>
{
	const lwc = require('lwc');
	return {__esModule: true, default: lwc.LightningElement};
}, {virtual: true});

jest.mock('@salesforce/label/c.ClassTypeResolverModal_SetupStep3', () => ({default: 'Register the resolver: set Class Name to {0}.'}), {virtual: true});

const mockCopyToClipBoard = jest.fn().mockResolvedValue(undefined);
jest.mock('c/utilitySystem', () => ({
	copyToClipBoard: (...args) => mockCopyToClipBoard(...args)
}), {virtual: true});

describe('c-class-type-resolver-setup-modal', () =>
{
	const ClassTypeResolverSetupModal = require('c/classTypeResolverSetupModal').default;
	const prototype = ClassTypeResolverSetupModal.prototype;
	const getGetter = (name) => Object.getOwnPropertyDescriptor(prototype, name).get;

	const createMockContext = (overrides = {}) => ({
		resolverClassName: 'ACME_ClassTypeResolver',
		resolverCopyIcon: 'utility:copy_to_clipboard',
		testCopyIcon: 'utility:copy_to_clipboard',
		close: jest.fn(),
		resetCopyIcon: prototype.resetCopyIcon,
		downloadFile: prototype.downloadFile, ...overrides
	});

	let anchorClickSpy;
	let createObjectURLSpy;
	let revokeObjectURLSpy;
	let originalCreateObjectURL;
	let originalRevokeObjectURL;

	beforeEach(() =>
	{
		anchorClickSpy = jest.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() =>
		{
		});

		originalCreateObjectURL = global.URL.createObjectURL;
		originalRevokeObjectURL = global.URL.revokeObjectURL;
		createObjectURLSpy = jest.fn().mockReturnValue('blob:mock-url');
		revokeObjectURLSpy = jest.fn();
		global.URL.createObjectURL = createObjectURLSpy;
		global.URL.revokeObjectURL = revokeObjectURLSpy;
	});

	afterEach(() =>
	{
		anchorClickSpy.mockRestore();
		global.URL.createObjectURL = originalCreateObjectURL;
		global.URL.revokeObjectURL = originalRevokeObjectURL;
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			expect(ClassTypeResolverSetupModal).toBeDefined();
			expect(typeof ClassTypeResolverSetupModal).toBe('function');
		});
	});

	describe('DOM instantiation', () =>
	{
		it('mounts without errors and runs field initialisers', async() =>
		{
			const {createElement} = require('lwc');
			const element = createElement('c-class-type-resolver-setup-modal', {is: ClassTypeResolverSetupModal});
			document.body.appendChild(element);
			await Promise.resolve();

			expect(element.tagName.toLowerCase()).toBe('c-class-type-resolver-setup-modal');
			const resolverInput = element.shadowRoot.querySelector('[data-testid="resolver-class-name"]');
			expect(resolverInput).not.toBeNull();
			expect(resolverInput.value).toBe('ACME_ClassTypeResolver');

			document.body.removeChild(element);
		});
	});

	describe('resolverClassCode getter', () =>
	{
		it('embeds the resolver class name into the generated class', () =>
		{
			const context = createMockContext({resolverClassName: 'MyResolver'});
			const code = getGetter('resolverClassCode').call(context);
			expect(code).toContain('global with sharing class MyResolver extends kern.UTIL_TypeResolver.BaseClassResolver');
			expect(code).toContain('public override Type resolveType(String className)');
			expect(code).toContain('getTypeForClassName');
		});

		it('uses the default class name when not overridden', () =>
		{
			const context = createMockContext();
			const code = getGetter('resolverClassCode').call(context);
			expect(code).toContain('class ACME_ClassTypeResolver extends');
		});
	});

	describe('setupStep3 getter', () =>
	{
		it('substitutes the resolver class name into the step 3 template', () =>
		{
			const context = createMockContext({resolverClassName: 'AcmeResolver'});
			const text = getGetter('setupStep3').call(context);
			expect(text).toContain('AcmeResolver');
			expect(text).not.toContain('{0}');
		});
	});

	describe('testClassCode getter', () =>
	{
		it('embeds the test class name with _TEST suffix', () =>
		{
			const context = createMockContext({resolverClassName: 'MyResolver'});
			const code = getGetter('testClassCode').call(context);
			expect(code).toContain('private class MyResolver_TEST');
			expect(code).toContain('shouldResolveLocalClass');
			expect(code).toContain('shouldResolveNestedClass');
			expect(code).toContain('shouldReturnNullWhenClassNotFound');
			expect(code).toContain('shouldReturnNullWhenClassNameBlank');
		});
	});

	describe('handleClassNameChange', () =>
	{
		it('updates resolverClassName from event detail', () =>
		{
			const context = createMockContext();
			prototype.handleClassNameChange.call(context, {detail: {value: 'NewName'}});
			expect(context.resolverClassName).toBe('NewName');
		});
	});

	describe('handleCopyResolver', () =>
	{
		it('copies resolver code to clipboard and flips the icon to check', async() =>
		{
			jest.useFakeTimers();
			const context = createMockContext();
			Object.defineProperty(context, 'resolverClassCode', {get: () => 'FAKE_RESOLVER_CODE'});

			await prototype.handleCopyResolver.call(context);

			expect(mockCopyToClipBoard).toHaveBeenCalledWith('FAKE_RESOLVER_CODE');
			expect(context.resolverCopyIcon).toBe('utility:check');

			jest.advanceTimersByTime(1500);
			expect(context.resolverCopyIcon).toBe('utility:copy_to_clipboard');

			jest.useRealTimers();
		});
	});

	describe('handleCopyTest', () =>
	{
		it('copies test code to clipboard and flips the icon to check', async() =>
		{
			jest.useFakeTimers();
			const context = createMockContext();
			Object.defineProperty(context, 'testClassCode', {get: () => 'FAKE_TEST_CODE'});

			await prototype.handleCopyTest.call(context);

			expect(mockCopyToClipBoard).toHaveBeenCalledWith('FAKE_TEST_CODE');
			expect(context.testCopyIcon).toBe('utility:check');

			jest.advanceTimersByTime(1500);
			expect(context.testCopyIcon).toBe('utility:copy_to_clipboard');

			jest.useRealTimers();
		});
	});

	describe('handleDownloadResolver', () =>
	{
		it('triggers a blob download with the resolver class filename', () =>
		{
			const context = createMockContext({resolverClassName: 'AcmeResolver'});
			Object.defineProperty(context, 'resolverClassCode', {get: () => 'RESOLVER_CODE'});

			prototype.handleDownloadResolver.call(context);

			expect(createObjectURLSpy).toHaveBeenCalled();
			expect(anchorClickSpy).toHaveBeenCalled();
			expect(revokeObjectURLSpy).toHaveBeenCalledWith('blob:mock-url');
		});
	});

	describe('handleDownloadTest', () =>
	{
		it('triggers a blob download with the _TEST class filename', () =>
		{
			const context = createMockContext({resolverClassName: 'AcmeResolver'});
			Object.defineProperty(context, 'testClassCode', {get: () => 'TEST_CODE'});

			prototype.handleDownloadTest.call(context);

			expect(createObjectURLSpy).toHaveBeenCalled();
			expect(anchorClickSpy).toHaveBeenCalled();
			expect(revokeObjectURLSpy).toHaveBeenCalledWith('blob:mock-url');
		});
	});

	describe('downloadFile', () =>
	{
		it('creates an anchor, clicks it, and revokes the object URL', () =>
		{
			const context = createMockContext();
			prototype.downloadFile.call(context, 'filename.cls', 'content');

			expect(createObjectURLSpy).toHaveBeenCalled();
			expect(anchorClickSpy).toHaveBeenCalled();
			expect(revokeObjectURLSpy).toHaveBeenCalledWith('blob:mock-url');
		});
	});

	describe('handleCancel', () =>
	{
		it('closes the modal with cancel result', () =>
		{
			const context = createMockContext();
			prototype.handleCancel.call(context);
			expect(context.close).toHaveBeenCalledWith('cancel');
		});
	});

	describe('handleConfirm', () =>
	{
		it('closes the modal with confirmed result', () =>
		{
			const context = createMockContext();
			prototype.handleConfirm.call(context);
			expect(context.close).toHaveBeenCalledWith('confirmed');
		});
	});

	describe('resetCopyIcon', () =>
	{
		it('sets the icon to check and resets after delay', () =>
		{
			jest.useFakeTimers();
			const context = createMockContext();

			prototype.resetCopyIcon.call(context, 'resolverCopyIcon');
			expect(context.resolverCopyIcon).toBe('utility:check');

			jest.advanceTimersByTime(1500);
			expect(context.resolverCopyIcon).toBe('utility:copy_to_clipboard');

			jest.useRealTimers();
		});

		it('clears any pending timeout before setting a new one', () =>
		{
			jest.useFakeTimers();
			const context = createMockContext();

			prototype.resetCopyIcon.call(context, 'resolverCopyIcon');
			prototype.resetCopyIcon.call(context, 'resolverCopyIcon');

			jest.advanceTimersByTime(1500);
			expect(context.resolverCopyIcon).toBe('utility:copy_to_clipboard');

			jest.useRealTimers();
		});
	});
});
