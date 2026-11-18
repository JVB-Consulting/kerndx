// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs the "Copy this first" sample at the top of the LWC guide. The sample component sits in
 *              fixtures/myComponent exactly as the guide prints it, and the first test checks that the two still
 *              match. The other tests build the component on the real componentBuilder (not the shared mock that
 *              jest.config.js maps `c/componentBuilder` to), so they show what the sample really does: it calls the
 *              Apex method with the record, and shows a success toast only when the call gives back the saved
 *              record's Id. When the call fails, only the error toast appears. The toast text comes from a custom
 *              label in the reader's own org, so this test gives that label a stand-in text.
 *
 *              The guide imports the module as `kern/componentBuilder`, the name it has in an org where KernDX is
 *              installed. This test points that name at the real module in this folder.
 *
 * @author your.name@company.com
 *
 * @date November 2026
 */
import {createElement} from 'lwc';
import saveRecord from '@salesforce/apex/MyController.saveRecord';
import RECORD_SAVED from '@salesforce/label/c.MyComponent_RecordSaved';
import MyComponent from './fixtures/myComponent/myComponent';

const fs = require('fs');
const path = require('path');

jest.mock('kern/componentBuilder', () => jest.requireActual('../componentBuilder.js'), {virtual: true});
jest.mock('@salesforce/apex/MyController.saveRecord', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/label/c.MyComponent_RecordSaved', () => ({default: 'Record saved successfully'}), {virtual: true});

const GUIDE_PATH = path.join(__dirname, '..', '..', '..', '..', '..', '..', 'docs', 'LWC - Guide.md');
const SAMPLE_PATH = path.join(__dirname, 'fixtures', 'myComponent', 'myComponent.js');
const BLOCK_HEADING = '## Copy this first';
const TOAST_EVENT_NAME = 'lightning__showtoast';
const SAVED_RECORD_ID = '001000000000001AAA';
const SAVE_ERROR_MESSAGE = 'The record could not be saved.';

/**
 * @description Reads a text file with every Windows line break (\r\n) turned into a plain one (\n). A Windows
 *              checkout of the repository can save the files with Windows line breaks, and the comparison is about
 *              the code, not about how the lines end.
 * @param {string} filePath The file to read.
 * @returns {string} The text of the file, with plain line breaks only.
 */
function readTextFile(filePath)
{
	return fs.readFileSync(filePath, 'utf8').replace(/\r\n/g, '\n');
}

/**
 * @description Finds the first JavaScript code block under the "Copy this first" heading in the text of the LWC guide.
 * @param {string} guide The text of the guide, with plain line breaks only.
 * @returns {string} The code in that block, with a line break at the end as in a source file, or an empty string when
 *                   the guide has no such block.
 */
function findGuideSample(guide)
{
	const afterHeading = guide.slice(guide.indexOf(BLOCK_HEADING));
	const match = afterHeading.match(/```javascript\n([\s\S]*?)```/);

	return match ? match[1] : '';
}

/**
 * @description Reads the first JavaScript code block under the "Copy this first" heading of the LWC guide.
 * @returns {string} The code in that block, with a line break at the end as in a source file.
 */
function readGuideSample()
{
	return findGuideSample(readTextFile(GUIDE_PATH));
}

/**
 * @description Puts the sample component on the page and clicks its Save button.
 * @param {function(Event): void} onToast Receives each toast event the component sends.
 * @returns {Promise<void>} Resolves once the save has finished.
 */
async function clickSave(onToast)
{
	const element = createElement('c-my-component', {is: MyComponent});
	element.addEventListener(TOAST_EVENT_NAME, onToast);
	document.body.appendChild(element);

	element.shadowRoot.querySelector('button').click();

	await Promise.resolve();
	await Promise.resolve();
}

describe('LWC guide: Copy this first', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}

		jest.clearAllMocks();
	});

	it('matches the sample the guide prints', () =>
	{
		expect(readTextFile(SAMPLE_PATH)).toBe(readGuideSample());
	});

	it('finds the same sample when the guide and the sample file have Windows line breaks', () =>
	{
		const toWindowsLineBreaks = (text) => text.replace(/\r?\n/g, '\r\n');
		const readFileSync = fs.readFileSync;
		const spy = jest.spyOn(fs, 'readFileSync').mockImplementation((filePath, encoding) => toWindowsLineBreaks(readFileSync(filePath, encoding)));

		try
		{
			const sample = readGuideSample();

			expect(sample).toContain('export default class MyComponent');
			expect(sample).not.toContain('\r');
			expect(readTextFile(SAMPLE_PATH)).toBe(sample);
		}
		finally
		{
			spy.mockRestore();
		}
	});

	it('calls the Apex method with the record and then shows a success toast', async() =>
	{
		saveRecord.mockResolvedValue(SAVED_RECORD_ID);
		const toasts = [];

		await clickSave((event) => toasts.push(event.detail));

		expect(saveRecord).toHaveBeenCalledTimes(1);
		expect(saveRecord).toHaveBeenCalledWith({record: undefined});
		expect(toasts).toHaveLength(1);
		expect(toasts[0]).toEqual(expect.objectContaining({message: RECORD_SAVED, variant: 'success'}));
	});

	it('shows only the error toast, and no success toast, when the Apex call fails', async() =>
	{
		saveRecord.mockRejectedValue({body: {message: SAVE_ERROR_MESSAGE}});
		const toasts = [];

		await clickSave((event) => toasts.push(event.detail));

		expect(saveRecord).toHaveBeenCalledTimes(1);
		expect(toasts).toHaveLength(1);
		expect(toasts[0]).toEqual(expect.objectContaining({message: SAVE_ERROR_MESSAGE, variant: 'error'}));
		expect(toasts).not.toContainEqual(expect.objectContaining({variant: 'success'}));
	});
});
