// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Datatable that supports custom row types. Extends `LightningDatatable`
 * and registers a set of built-in column types (richText, image, iconColumn,
 * progressColumn) when the module loads, and again on connect, merging any additional
 * types passed via the `@api types` property. The merge reaches tables created later on the
 * page, not the table that passed the types.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, October 2026
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
 * @description Built-in column types registered automatically when the module loads and when a table connects.
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

/**
 * @description Turns a list of column types into the map that `LightningDatatable` reads, keyed by type name.
 * @param {CustomRowType[]} columnTypes - The column types to turn into map entries
 * @returns {Object<string, {template: Object, typeAttributes: string[]}>} The column types keyed by name
 */
function toCustomTypeMap(columnTypes)
{
	return Object.fromEntries(columnTypes.map((columnType) => [
		columnType.name,
		{template: columnType.template, typeAttributes: columnType.typeAttributes ?? columnType.attributes}
	]));
}

export default class CustomDataTable extends LightningDatatable
{
	//noinspection JSUnusedGlobalSymbols
	/**
	 * @description The column types the table can show. The built-in types are added when the module loads,
	 * because `LightningDatatable` reads this map when a table is created, before it is added to the page.
	 */
	static customTypes = toCustomTypeMap(BUILT_IN_COLUMN_TYPES);

	/**
	 * @description More column types from the component that uses this table. They are added to the shared
	 * static `customTypes` map when the table connects. By then `LightningDatatable` has already copied that map
	 * for this table, so these types reach tables created later on the page, not this one. To give a table its
	 * own column types, extend this component with a subclass that declares its own static `customTypes`
	 * (see `customDataTable` in `LWC - Guide.md`).
	 * @type {CustomRowType[]}
	 */
	@api types = [];

	/**
	 * @description Adds the built-in column types and the types passed through `types` to the shared static
	 * `customTypes` map. `LightningDatatable` copied that map when this table was created, before this runs,
	 * so the change does not reach this table. It reaches only tables created later on the page.
	 */
	connectedCallback()
	{
		const allTypes = [
			...BUILT_IN_COLUMN_TYPES,
			...this.types
		];

		Object.assign(CustomDataTable.customTypes, toCustomTypeMap(allTypes));
	}
}