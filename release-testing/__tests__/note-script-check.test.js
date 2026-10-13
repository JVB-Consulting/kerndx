// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const os = require('os');
const path = require('path');
const {NOTE_SCRIPTS, findNoteScript, compareNoteScripts, main} = require('../runner/note-script-check');

const NOTE = [
	'# Release note',
	'',
	'### Repair the rows',
	'',
	'Save the script below.',
	'',
	'```shell',
	'sf apex run --file repair.apex -o YourOrgAlias',
	'```',
	'',
	'```apex',
	'// Repairs the rows.',
	'update rows;',
	'```',
	'',
	'### Something else',
	'',
	'```apex',
	'delete rows;',
	'```',
	''
].join('\n');

/**
 * @description Writes a note and one pack copy into a fresh folder, as the check reads them from the repository.
 *
 * @param {string} copyText The pack copy's text.
 *
 * @returns {{root: string, notePath: string, scripts: Array<{copy: string, heading: string}>}} The check's options.
 */
function writeFixture(copyText)
{
	const root = fs.mkdtempSync(path.join(os.tmpdir(), 'note-script-check-'));
	fs.writeFileSync(path.join(root, 'note.md'), NOTE, 'utf8');
	fs.writeFileSync(path.join(root, 'repair.apex'), copyText, 'utf8');
	return {root, notePath: 'note.md', scripts: [{copy: 'repair.apex', heading: 'Repair the rows'}]};
}

describe('findNoteScript', () =>
{
	it('returns the one apex block under the heading, with a closing line ending, and skips the shell block', () =>
	{
		expect(findNoteScript(NOTE, 'Repair the rows')).toBe('// Repairs the rows.\nupdate rows;\n');
	});

	it('stops at the next heading, so a later section\'s block is never taken', () =>
	{
		expect(findNoteScript(NOTE, 'Something else')).toBe('delete rows;\n');
	});

	it('names a missing heading and a section without exactly one apex block', () =>
	{
		expect(() => findNoteScript(NOTE, 'Not there')).toThrow('the note has no heading "Not there"');
		expect(() => findNoteScript(NOTE, 'Release note')).toThrow('holds 0 apex blocks, expected 1');
		const twoScripts = NOTE.replace('### Something else', 'More text.');
		expect(() => findNoteScript(twoScripts, 'Repair the rows')).toThrow('holds 2 apex blocks, expected 1');
	});
});

describe('compareNoteScripts and main', () =>
{
	it('passes a copy that matches the note byte for byte, also when the copy has Windows line endings', () =>
	{
		const lines = [];
		expect(main({...writeFixture('// Repairs the rows.\r\nupdate rows;\r\n'), log: (line) => lines.push(line)})).toBe(0);
		expect(lines).toEqual(['SAME repair.apex: matches the note']);
	});

	it('fails a copy that drifted and names the first line that differs', () =>
	{
		const lines = [];
		expect(main({...writeFixture('// Repairs the rows.\nupsert rows;\n'), log: (line) => lines.push(line)})).toBe(1);
		expect(lines).toEqual(['DIFFERENT repair.apex: differs from the note from line 2']);
	});

	it('fails a copy without its closing line ending, since the pack saves the block as a whole file', () =>
	{
		expect(compareNoteScripts(writeFixture('// Repairs the rows.\nupdate rows;'))[0]).toMatchObject({same: false});
	});

	it('fails, rather than throws, when the copy is missing', () =>
	{
		const options = writeFixture('');
		fs.unlinkSync(path.join(options.root, 'repair.apex'));
		expect(compareNoteScripts(options)[0]).toMatchObject({same: false, detail: expect.stringContaining('ENOENT')});
	});

	it('finds every pack copy matching the 1.8 release note in this repository', () =>
	{
		const results = compareNoteScripts();
		expect(results.map((result) => result.copy)).toEqual(NOTE_SCRIPTS.map((pair) => pair.copy));
		expect(results.filter((result) => !result.same)).toEqual([]);
	});

	it('prints with the console when no log is given', () =>
	{
		const printed = jest.spyOn(console, 'log').mockImplementation(() => {});
		try
		{
			expect(main(writeFixture('// Repairs the rows.\nupdate rows;\n'))).toBe(0);
			expect(printed).toHaveBeenCalledWith('SAME repair.apex: matches the note');
		}
		finally
		{
			printed.mockRestore();
		}
	});
});
