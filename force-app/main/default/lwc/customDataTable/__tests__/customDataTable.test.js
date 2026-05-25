// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for customDataTable LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */
import {createElement} from 'lwc';
import LwcCustomDataTable from 'c/customDataTable';

describe('c-custom-data-table', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
		// Reset static customTypes between tests
		LwcCustomDataTable.customTypes = {};
	});

	async function flushPromises()
	{
		return new Promise((resolve) => setTimeout(resolve, 0));
	}

	function createComponent(props = {})
	{
		const element = createElement('c-custom-data-table', {is: LwcCustomDataTable});
		Object.assign(element, props);
		document.body.appendChild(element);
		return element;
	}

	describe('initialization', () =>
	{
		it('creates component successfully', async() =>
		{
			const element = createComponent();
			await flushPromises();

			expect(element).not.toBeNull();
		});

		it('extends LightningDatatable', () =>
		{
			// LwcCustomDataTable should be a subclass that registers custom types
			expect(LwcCustomDataTable.customTypes).toBeDefined();
		});
	});

	describe('default custom types', () =>
	{
		it('registers richText type on connected', async() =>
		{
			createComponent();
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.richText).toBeDefined();
		});

		it('registers image type on connected', async() =>
		{
			createComponent();
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.image).toBeDefined();
		});

		it('registers iconColumn type on connected', async() =>
		{
			createComponent();
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.iconColumn).toBeDefined();
		});

		it('registers progressColumn type on connected', async() =>
		{
			createComponent();
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.progressColumn).toBeDefined();
		});

		it('image type has imgUrl attribute', async() =>
		{
			createComponent();
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.image.typeAttributes).toContain('imgUrl');
		});

		it('iconColumn type has alternativeText and iconName attributes', async() =>
		{
			createComponent();
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.iconColumn.typeAttributes).toContain('alternativeText');
			expect(LwcCustomDataTable.customTypes.iconColumn.typeAttributes).toContain('iconName');
		});

		it('progressColumn type has value attribute', async() =>
		{
			createComponent();
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.progressColumn.typeAttributes).toContain('value');
		});
	});

	describe('@api types property', () =>
	{
		it('accepts custom types array', async() =>
		{
			const customType = {
				name: 'myCustomType', template: null, attributes: ['customAttr']
			};
			const element = createComponent({types: [customType]});
			await flushPromises();

			expect(element.types).toEqual([customType]);
		});

		it('registers custom types on connected', async() =>
		{
			const customType = {
				name: 'myCustomType', template: null, attributes: ['customAttr']
			};
			createComponent({types: [customType]});
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.myCustomType).toBeDefined();
		});

		it('custom type has correct typeAttributes', async() =>
		{
			const customType = {
				name: 'testType', template: null, attributes: [
					'attr1',
					'attr2'
				]
			};
			createComponent({types: [customType]});
			await flushPromises();

			expect(LwcCustomDataTable.customTypes.testType.typeAttributes).toEqual([
				'attr1',
				'attr2'
			]);
		});

		it('merges custom types with default types', async() =>
		{
			const customType = {
				name: 'additionalType', template: null, attributes: []
			};
			createComponent({types: [customType]});
			await flushPromises();

			// Both default and custom types should exist
			expect(LwcCustomDataTable.customTypes.richText).toBeDefined();
			expect(LwcCustomDataTable.customTypes.additionalType).toBeDefined();
		});
	});

	describe('static customTypes', () =>
	{
		it('is shared across all instances', async() =>
		{
			const customType = {
				name: 'sharedType', template: null, attributes: []
			};
			createComponent({types: [customType]});
			await flushPromises();

			// Create second instance
			const secondElement = createComponent();
			await flushPromises();

			// Type registered by first instance should be accessible
			expect(LwcCustomDataTable.customTypes.sharedType).toBeDefined();
			expect(secondElement).not.toBeNull();
		});
	});
});
