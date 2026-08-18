// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Datatable for the Log Console list views. Extends `LightningDatatable`
 * to register three isolated custom cell types: `logLevel` renders a severity badge
 * (colour is the one allowed colour axis in the list and is driven only by the log
 * level), `logNumber` links a row to its own record or, for a grouped problem that owns
 * none, marks the cell as grouped, and `problemName` marks a problem a developer tagged
 * in code. Inheriting the base datatable provides row focus, keyboard cell navigation
 * and `aria-sort` for free.
 *
 * @author Jason van Beukering
 *
 * @date June 2026, August 2026
 */
import LightningDatatable from 'lightning/datatable';
import levelBadge from './levelBadge.html';
import logNumberLink from './logNumberLink.html';
import problemName from './problemName.html';

export default class LogConsoleTable extends LightningDatatable
{
	//noinspection JSUnusedGlobalSymbols
	/**
	 * @description Custom cell types for this datatable. Held in this subclass's own
	 * static so the registration is isolated and cannot leak into other
	 * `LightningDatatable` subclasses. `logLevel` forwards the row's level to the
	 * severity-badge template; `logNumber` renders a link to the row's own record, a
	 * pill for a grouped problem that owns none, or a muted stand-in when a row with a
	 * record carries no number; `problemName` renders the message and marks a problem a
	 * developer tagged in code.
	 */
	static customTypes = {
		logLevel: {template: levelBadge, standardCellLayout: true, typeAttributes: ['level']},
		logNumber: {
			template: logNumberLink, standardCellLayout: true, typeAttributes: [
				'recordUrl',
				'isGrouped'
			]
		},
		problemName: {
			template: problemName, standardCellLayout: true, typeAttributes: [
				'isTagged',
				'taggedLabel'
			]
		}
	};
}