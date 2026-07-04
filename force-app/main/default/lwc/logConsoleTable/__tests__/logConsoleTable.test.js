// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for logConsoleTable LWC component
 * @author Jason van Beukering
 * @date June 2026
 */
import {createElement} from 'lwc';
import LogConsoleTable from 'c/logConsoleTable';

const LEVEL_COLUMN = {label: 'Level', fieldName: 'level', type: 'logLevel', typeAttributes: {level: {fieldName: 'level'}}};
const PROBLEM_ROWS = [
	{id: '001', level: 'ERROR'},
	{id: '002', level: 'WARN'},
	{id: '003', level: 'INFO'},
	{id: '004', level: 'DEBUG'}
];

function createComponent(props = {})
{
	const element = createElement('c-log-console-table', {is: LogConsoleTable});
	Object.assign(element, props);
	document.body.appendChild(element);
	return element;
}

describe('c-log-console-table', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	describe('initialization', () =>
	{
		it('creates the component successfully', async() =>
		{
			const element = createComponent();
			await Promise.resolve();

			expect(element).not.toBeNull();
		});

		it('renders the supplied columns and data', async() =>
		{
			const element = createComponent({columns: [LEVEL_COLUMN], data: PROBLEM_ROWS});
			await Promise.resolve();

			expect(element.columns).toEqual([LEVEL_COLUMN]);
			expect(element.data).toEqual(PROBLEM_ROWS);
		});
	});

	describe('logLevel custom cell type', () =>
	{
		it('extends LightningDatatable with a customTypes registry', () =>
		{
			expect(LogConsoleTable.customTypes).toBeDefined();
		});

		it('registers the logLevel severity-badge type', () =>
		{
			expect(LogConsoleTable.customTypes.logLevel).toBeDefined();
			expect(LogConsoleTable.customTypes.logLevel.template).toBeDefined();
		});

		it('forwards the level value to the badge template', () =>
		{
			expect(LogConsoleTable.customTypes.logLevel.typeAttributes).toContain('level');
		});

		it('uses the standard cell layout so severity aligns with built-in columns', () =>
		{
			expect(LogConsoleTable.customTypes.logLevel.standardCellLayout).toBe(true);
		});
	});
});
