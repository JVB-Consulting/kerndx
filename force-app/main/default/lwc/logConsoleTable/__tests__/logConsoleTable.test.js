// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for logConsoleTable LWC component
 * @author Jason van Beukering
 * @date June 2026, September 2026
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

	describe('logNumber custom cell type', () =>
	{
		it('registers a type that can render a row with no record behind it', () =>
		{
			// The standard url type renders an empty cell when the href is null, which is what a grouped
			// problem always is: it is folded at read time and owns no LogEntry__c to link to.
			expect(LogConsoleTable.customTypes.logNumber).toBeDefined();
			expect(LogConsoleTable.customTypes.logNumber.template).toBeDefined();
			expect(LogConsoleTable.customTypes.logNumber.standardCellLayout).toBe(true);
		});

		it('forwards the record link, keeping the number itself as the cell value', () =>
		{
			expect(LogConsoleTable.customTypes.logNumber.typeAttributes).toContain('recordUrl');
		});

		it('forwards whether the row was grouped, which is what the cell renders instead of a number', () =>
		{
			// A cell template reads nothing but its own value and its type attributes, so the one thing that
			// tells a grouped row from a row whose number is genuinely missing has to travel as one of them.
			expect(LogConsoleTable.customTypes.logNumber.typeAttributes).toContain('isGrouped');
		});
	});

	describe('problemName custom cell type', () =>
	{
		it('registers the type that marks a tagged problem', () =>
		{
			expect(LogConsoleTable.customTypes.problemName).toBeDefined();
			expect(LogConsoleTable.customTypes.problemName.template).toBeDefined();
			expect(LogConsoleTable.customTypes.problemName.standardCellLayout).toBe(true);
		});

		it('takes both the per-row flag and the constant pill text', () =>
		{
			// The flag varies per row; the text does not, so it is passed once on the column rather than
			// copied onto every row of the page.
			expect(LogConsoleTable.customTypes.problemName.typeAttributes).toContain('isTagged');
			expect(LogConsoleTable.customTypes.problemName.typeAttributes).toContain('taggedLabel');
		});
	});

	describe('writerSource custom cell type', () =>
	{
		it('registers the type that names the writer behind a row', () =>
		{
			expect(LogConsoleTable.customTypes.writerSource).toBeDefined();
			expect(LogConsoleTable.customTypes.writerSource.template).toBeDefined();
			expect(LogConsoleTable.customTypes.writerSource.standardCellLayout).toBe(true);
		});

		it('takes the origin label, which is the one part of the cell the value itself cannot carry', () =>
		{
			// The cell value is the writer's location, one string. Who wrote it is a second fact about the same
			// row, and a cell template reads nothing but its value and its type attributes, so it travels as one.
			expect(LogConsoleTable.customTypes.writerSource.typeAttributes).toContain('originLabel');
		});
	});

	describe('custom type isolation', () =>
	{
		it('keeps every registration on this subclass, so none leaks to other datatables', () =>
		{
			// eslint-disable-next-line no-prototype-builtins
			expect(LogConsoleTable.hasOwnProperty('customTypes')).toBe(true);
			expect(Object.keys(LogConsoleTable.customTypes).sort()).toEqual([
				'logLevel',
				'logNumber',
				'problemName',
				'writerSource'
			]);
		});
	});
});
