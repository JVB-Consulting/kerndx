// SPDX-License-Identifier: Apache-2.0
/**
 * @description Jest unit tests for chainActionConfirmModal LWC component. Prototype harness per
 *              chainAbortModal.test.js: handler shapes are asserted on the class prototype and
 *              invoked with a plain context carrying close: jest.fn(); the template's rendering is
 *              covered by the Playwright leg.
 *
 * @author Jason van Beukering
 * @date August 2026, October 2026
 */

describe('c-chain-action-confirm-modal', () =>
{
	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const ChainActionConfirmModal = require('c/chainActionConfirmModal').default;
			expect(ChainActionConfirmModal).toBeDefined();
			expect(typeof ChainActionConfirmModal).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const ChainActionConfirmModal = require('c/chainActionConfirmModal').default;
		const prototype = ChainActionConfirmModal.prototype;

		it.each([
			['title'],
			['body'],
			['confirmLabel'],
			['cancelLabel'],
			['confirmVariant']
		])('has @api %s property', (propertyName) =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, propertyName);
			expect(descriptor).toBeDefined();
		});

		it('has handleConfirm method', () =>
		{
			expect(typeof prototype.handleConfirm).toBe('function');
		});

		it('has handleCancel method', () =>
		{
			expect(typeof prototype.handleCancel).toBe('function');
		});
	});

	describe('instance behavior', () =>
	{
		const ChainActionConfirmModal = require('c/chainActionConfirmModal').default;
		const prototype = ChainActionConfirmModal.prototype;

		const createMockContext = (overrides = {}) =>
		{
			return {
				title: '', body: '', confirmLabel: '', cancelLabel: '', confirmVariant: 'brand', close: jest.fn(), ...overrides
			};
		};

		describe('handleConfirm', () =>
		{
			it('calls close with action confirm', () =>
			{
				let context = createMockContext();
				prototype.handleConfirm.call(context);
				expect(context.close).toHaveBeenCalledWith({action: 'confirm'});
			});
		});

		describe('handleCancel', () =>
		{
			it('calls close with action cancel', () =>
			{
				let context = createMockContext();
				prototype.handleCancel.call(context);
				expect(context.close).toHaveBeenCalledWith({action: 'cancel'});
			});
		});
	});

	// A single construction test (createElement, no rendered-DOM assertions beyond the footer test
	// hooks) runs the @api field initializers so the component's default state is exercised; the
	// full template rendering and click flow are covered by the Playwright leg.
	describe('construction', () =>
	{
		it('defaults the four string @api fields to empty strings and the confirm variant to brand', () =>
		{
			const {createElement} = require('lwc');
			const ChainActionConfirmModal = require('c/chainActionConfirmModal').default;
			let element = createElement('c-chain-action-confirm-modal', {is: ChainActionConfirmModal});
			document.body.appendChild(element);

			expect(element.title).toBe('');
			expect(element.body).toBe('');
			expect(element.confirmLabel).toBe('');
			expect(element.cancelLabel).toBe('');
			expect(element.confirmVariant).toBe('brand');

			document.body.removeChild(element);
		});
	});
});
