// SPDX-License-Identifier: Apache-2.0
jest.mock('child_process', () => ({execFileSync: jest.fn(), spawnSync: jest.fn()}));
jest.mock('../e2e/helpers/sf-cli', () => ({soqlQuery: jest.fn()}));
jest.mock('../e2e/helpers/sf-namespace', () => ({namespacePrefix: jest.fn(() => '')}));
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');
const {readChangedPaths, selectParts, decide, main, DEFAULT_SINCE, PAGES_DIRECTORY} = require('../e2e/select-journeys');
const map = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'e2e', 'journey-map.json'), 'utf8'));

const PAGE_OBJECT_REQUIRE = /require\('\.\.\/pages\/([^']+)'\)/g;
const PAGE_OBJECT_SUFFIX = '.js';

/**
 * @description The page objects a part's spec requires that the part's `pages` do not name.
 *
 * @param {string} root The repository root.
 * @param {string} name The part's name in the map.
 * @param {object} part The part's map entry.
 *
 * @returns {string[]} One line per unmapped page object, naming the part and the page object's path.
 */
function unmappedPageObjects(root, name, part)
{
	const specText = fs.readFileSync(path.join(root, part.spec), 'utf8');
	return [...specText.matchAll(PAGE_OBJECT_REQUIRE)]
	.map(([, required]) => (required.endsWith(PAGE_OBJECT_SUFFIX) ? required : `${required}${PAGE_OBJECT_SUFFIX}`))
	.filter((page) => !part.pages.includes(page))
	.map((page) => `${name} requires ${PAGES_DIRECTORY}${page}`);
}

/**
 * @description Scripts the git answers `main` reads: the committed diff and the working tree's status.
 *
 * @param {string[]} committed The paths `git diff --name-only` returns.
 */
function scriptGit(committed)
{
	childProcess.execFileSync.mockImplementation((command, args) => (args[0] === 'diff' ? `${committed.join('\n')}\n` : ''));
}

/**
 * @description Runs `main` with the console captured, returning the exit code and every printed line.
 *
 * @param {string[]} argv The arguments after the script name.
 *
 * @returns {{exitCode: number, printed: string[]}} The exit code and the lines written to the console.
 */
function runMain(argv)
{
	const printed = [];
	const logSpy = jest.spyOn(console, 'log').mockImplementation((line) => printed.push(line));
	const errorSpy = jest.spyOn(console, 'error').mockImplementation((line) => printed.push(line));
	try
	{
		return {exitCode: main(argv), printed};
	}
	finally
	{
		logSpy.mockRestore();
		errorSpy.mockRestore();
	}
}

beforeEach(() =>
{
	childProcess.execFileSync.mockReset();
	childProcess.spawnSync.mockReset();
});

describe('the journey map', () =>
{
	it('maps every spec part it names to paths that exist, and every page object to a part', () =>
	{
		const root = path.join(__dirname, '..', '..');
		const unmapped = [];
		for(const [name, part] of Object.entries(map.parts))
		{
			expect(fs.existsSync(path.join(root, part.spec))).toBe(true);
			for(const mapped of part.paths)
			{
				expect(fs.existsSync(path.join(root, mapped))).toBe(true);
			}
			for(const page of part.pages)
			{
				expect(fs.existsSync(path.join(root, PAGES_DIRECTORY, page))).toBe(true);
			}
			unmapped.push(...unmappedPageObjects(root, name, part));
		}
		expect(unmapped).toEqual([]);
		for(const core of map.core)
		{
			expect(fs.existsSync(path.join(root, core))).toBe(true);
		}
	});
});

describe('selectParts', () =>
{
	it('picks the parts whose paths or page objects changed, with the reason', () =>
	{
		const selection = selectParts(map, ['force-app/main/default/classes/CTRL_LogConsole.cls', 'release-testing/e2e/pages/chain-monitor.page.js']);
		expect(selection.parts.sort()).toEqual(['part10-log-console', 'part12-consoles-at-volume', 'part8-chain-monitor']);
		expect(selection.reasons['part8-chain-monitor']).toEqual(['release-testing/e2e/pages/chain-monitor.page.js']);
		expect(selection.everything).toBe(false);
		expect(selection.core).toEqual([]);
	});

	it('picks everything on a core change, naming the core paths that matched, and nothing on an unrelated one', () =>
	{
		const selection = selectParts(map, ['release-testing/e2e/helpers/sf-cli.js', 'docs/Installation.md']);
		expect(selection.everything).toBe(true);
		expect(selection.core).toEqual(['release-testing/e2e/helpers/sf-cli.js']);
		expect(selectParts(map, ['docs/Installation.md']).parts).toEqual([]);
	});
});

describe('readChangedPaths and decide', () =>
{
	it('joins the commits since the ref with the working tree', () =>
	{
		const git = jest.fn((args) => (args[0] === 'diff' ? 'a.js\nb.js\n' : ' M c.js\n?? d.js\n'));
		expect(readChangedPaths({since: 'origin/master', git})).toEqual(['a.js', 'b.js', 'c.js', 'd.js']);
		expect(git).toHaveBeenCalledWith(['diff', '--name-only', 'origin/master']);
	});

	it('defaults to the remote\'s default branch, which every clone names origin/HEAD', () =>
	{
		expect(DEFAULT_SINCE).toBe('origin/HEAD');
	});

	it('names --since as the remedy when the ref does not exist', () =>
	{
		const git = jest.fn(() =>
		{
			throw new Error('fatal: bad revision \'origin/HEAD\'');
		});
		expect(() => readChangedPaths({since: 'origin/HEAD', git})).toThrow(/origin\/HEAD.*--since/s);
	});

	it('never narrows on an org with the package installed', () =>
	{
		const {namespacePrefix} = require('../e2e/helpers/sf-namespace');
		namespacePrefix.mockReturnValueOnce('other__');
		expect(decide(map, ['docs/x.md'])).toMatchObject({everything: true, reason: expect.stringMatching(/installed/)});
	});
});

describe('main', () =>
{
	it('names the core paths behind a whole-battery run, the same shape as a part\'s reasons', () =>
	{
		scriptGit(['release-testing/e2e/helpers/sf-cli.js']);
		const {exitCode, printed} = runMain(['--dry-run']);
		expect(exitCode).toBe(0);
		expect(printed).toContain('  the whole battery because release-testing/e2e/helpers/sf-cli.js');
		expect(childProcess.spawnSync).not.toHaveBeenCalled();
	});

	it('says a narrowed run still runs the parts the selected ones depend on', () =>
	{
		scriptGit(['force-app/main/default/classes/CTRL_MaskingAdvisor.cls']);
		const {printed} = runMain(['--dry-run']);
		expect(printed).toContain('select-journeys: these parts (Playwright still runs the parts they depend on first): part9-masking-advisor');
	});

	it('says why when Playwright does not start, and exits non-zero', () =>
	{
		scriptGit(['force-app/main/default/classes/CTRL_MaskingAdvisor.cls']);
		childProcess.spawnSync.mockReturnValue({status: null, error: new Error('spawn npx ENOENT')});
		const {exitCode, printed} = runMain([]);
		expect(exitCode).toBe(1);
		expect(printed).toContain('select-journeys: playwright did not start: spawn npx ENOENT');
	});
});
