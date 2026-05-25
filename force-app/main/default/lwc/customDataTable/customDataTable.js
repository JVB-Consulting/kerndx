// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Datatable that supports custom row types. Extends `LightningDatatable`
 * and registers a set of built-in column types (richText, image, iconColumn,
 * progressColumn) on connect, merging any additional types passed via the `@api types`
 * property.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, May 2026
 */
import LightningDatatable from 'lightning/datatable';
import {api} from 'lwc';
import iconColumn from './iconColumn.html';
import imageColumn from './imageColumn.html';
import progressColumn from './progressIndicator.html';
import richTextColumnType from './richTextcolumnType.html';

/**
 * @description Holds the definition of a custom column type: its name, HTML template
 * reference, and an optional list of attribute names forwarded to the template.
 */
class CustomRowType
{
	/** @description Unique column type identifier used as key in customTypes. */
	name;

	/** @description HTML template rendered for cells of this type. */
	template;

	/** @description Attribute names passed through from column config to the template. */
	typeAttributes = [];

	/**
	 * @description Creates a new CustomRowType definition.
	 * @param {string} name - Unique type identifier
	 * @param {Object} template - HTML template module
	 * @param {string[]} typeAttributes - Forwarded attribute names
	 */
	constructor(name, template, typeAttributes)
	{
		this.name = name;
		this.template = template;
		this.typeAttributes = typeAttributes;
	}
}

/**
 * @description Built-in column types registered automatically when the component connects.
 * @type {CustomRowType[]}
 */
const BUILT_IN_COLUMN_TYPES = [
	new CustomRowType('richText', richTextColumnType),
	new CustomRowType('image', imageColumn, ['imgUrl']),
	new CustomRowType('iconColumn', iconColumn, [
		'alternativeText',
		'iconName'
	]),
	new CustomRowType('progressColumn', progressColumn, ['value'])
];

export default class CustomDataTable extends LightningDatatable
{
	//noinspection JSUnusedGlobalSymbols
	static customTypes = {};

	/**
	 * @description Additional custom row types supplied by the consumer. Merged with
	 * built-in types during `connectedCallback`.
	 * @type {CustomRowType[]}
	 */
	@api types = [];

	/**
	 * @description Registers both built-in and consumer-supplied column types into
	 * the static `customTypes` map consumed by the LightningDatatable framework.
	 */
	connectedCallback()
	{
		const allTypes = [
			...BUILT_IN_COLUMN_TYPES,
			...this.types
		];

		Object.assign(CustomDataTable.customTypes, Object.fromEntries(allTypes.map((columnType) => [
			columnType.name,
			{template: columnType.template, typeAttributes: columnType.typeAttributes ?? columnType.attributes}
		])));
	}
}