// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Datatable for the Log Console list views. Extends `LightningDatatable`
 * to register a single isolated `logLevel` custom cell type that renders a severity
 * badge. Colour is the one allowed colour axis in the list and is driven only by the
 * log level. Inheriting the base datatable provides row focus, keyboard cell
 * navigation and `aria-sort` for free.
 *
 * @author Jason van Beukering
 *
 * @date June 2026
 */
import LightningDatatable from 'lightning/datatable';
import levelBadge from './levelBadge.html';

export default class LogConsoleTable extends LightningDatatable
{
	//noinspection JSUnusedGlobalSymbols
	/**
	 * @description Custom cell types for this datatable. Held in this subclass's own
	 * static so the registration is isolated and cannot leak into other
	 * `LightningDatatable` subclasses. `logLevel` forwards the row's level to the
	 * severity-badge template.
	 */
	static customTypes = {
		logLevel: {template: levelBadge, standardCellLayout: true, typeAttributes: ['level']}
	};
}
