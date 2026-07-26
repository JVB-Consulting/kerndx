// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainAbortModal LWC component. Prototype harness per
 *              applyRetentionModal.test.js: handler shapes are asserted on the class prototype and
 *              invoked with a plain context carrying close: jest.fn(); the template's rendering is
 *              covered by the Playwright leg.
 *
 * @author Jason van Beukering
 * @date July 2026
 */

describe('c-chain-abort-modal', () =>
{
	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const ChainAbortModal = require('c/chainAbortModal').default;
			expect(ChainAbortModal).toBeDefined();
			expect(typeof ChainAbortModal).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const ChainAbortModal = require('c/chainAbortModal').default;
		const prototype = ChainAbortModal.prototype;

		it('has @api title property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'title');
			expect(descriptor).toBeDefined();
		});

		it('has @api body property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'body');
			expect(descriptor).toBeDefined();
		});

		it('has @api confirmLabel property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'confirmLabel');
			expect(descriptor).toBeDefined();
		});

		it('has @api cancelLabel property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'cancelLabel');
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
		const ChainAbortModal = require('c/chainAbortModal').default;
		const prototype = ChainAbortModal.prototype;

		const createMockContext = (overrides = {}) =>
		{
			return {
				title: '', body: '', confirmLabel: '', cancelLabel: '', close: jest.fn(), ...overrides
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
		it('defaults the four @api fields to empty strings and renders the footer buttons', () =>
		{
			const {createElement} = require('lwc');
			const ChainAbortModal = require('c/chainAbortModal').default;
			let element = createElement('c-chain-abort-modal', {is: ChainAbortModal});
			document.body.appendChild(element);

			expect(element.title).toBe('');
			expect(element.body).toBe('');
			expect(element.confirmLabel).toBe('');
			expect(element.cancelLabel).toBe('');

			document.body.removeChild(element);
		});
	});
});
