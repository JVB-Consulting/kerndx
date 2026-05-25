// SPDX-License-Identifier: BUSL-1.1
jest.mock('child_process', () => ({
	execSync: jest.fn()
}));

const fs = require('fs');
const path = require('path');
const os = require('os');
const {execSync} = require('child_process');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');

jest.spyOn(fs, 'existsSync');
jest.spyOn(fs, 'mkdirSync').mockImplementation(() =>
{
});
jest.spyOn(fs, 'readdirSync');
jest.spyOn(fs, 'unlinkSync').mockImplementation(() =>
{
});
jest.spyOn(fs, 'copyFileSync').mockImplementation(() =>
{
});
jest.spyOn(fs, 'writeFileSync').mockImplementation(() =>
{
});
jest.spyOn(fs, 'statSync');
jest.spyOn(fs, 'rmSync').mockImplementation(() =>
{
});

const {
	deployCmdtState,
	getAvailableStates,
	NamedOrgNotFoundError,
	isNamedOrgNotFoundError,
	FIXTURES_DIR,
	STAGING_DIR
} = require('../runner/cmdt-deployer');

describe('deployCmdtState', () =>
{
	beforeEach(() =>
	{
		jest.clearAllMocks();
	});

	it('should throw when state directory does not exist', () =>
	{
		fs.existsSync.mockReturnValue(false);
		expect(() => deployCmdtState('nonexistent')).toThrow('CMDT state directory not found');
	});

	it('should clear existing CMDT files before copying', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readdirSync
		.mockReturnValueOnce(['old-file.xml'])
		.mockReturnValueOnce(['new-file.xml']);
		execSync.mockReturnValue(JSON.stringify({status: 0}));

		deployCmdtState('section3-state-a');

		expect(fs.unlinkSync).toHaveBeenCalledWith(expect.stringContaining('old-file.xml'));
	});

	it('should copy state fixture files to deploy directory', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readdirSync
		.mockReturnValueOnce([])
		.mockReturnValueOnce(['kern__FeatureFlag.EnableAccountTriggers.md-meta.xml']);
		execSync.mockReturnValue(JSON.stringify({status: 0}));

		deployCmdtState('section3-state-a');

		expect(fs.copyFileSync).toHaveBeenCalledWith(expect.stringContaining('section3-state-a'), expect.stringContaining('customMetadata'));
	});

	it('should call sf deploy with correct arguments', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readdirSync.mockReturnValue([]);
		execSync.mockReturnValue(JSON.stringify({status: 0}));

		deployCmdtState('baseline');

		expect(execSync).toHaveBeenCalledWith(expect.stringContaining(`sf project deploy start -o ${getSubscriberOrgAlias()}`), expect.objectContaining({cwd: STAGING_DIR}));
	});

	it('should throw when deploy fails', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readdirSync.mockReturnValue([]);
		execSync.mockReturnValue(JSON.stringify({status: 1, result: {status: 'Failed'}}));

		expect(() => deployCmdtState('section3-state-a')).toThrow('CMDT deploy failed');
	});

	it('should accept successful deploy with result.status Succeeded', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readdirSync.mockReturnValue([]);
		execSync.mockReturnValue(JSON.stringify({status: 1, result: {status: 'Succeeded'}}));

		expect(() => deployCmdtState('section3-state-a')).not.toThrow();
	});

	it('should create deploy directory recursively', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readdirSync.mockReturnValue([]);
		execSync.mockReturnValue(JSON.stringify({status: 0}));

		deployCmdtState('baseline');

		expect(fs.mkdirSync).toHaveBeenCalledWith(expect.stringContaining('customMetadata'), {recursive: true});
	});
});

describe('getAvailableStates', () =>
{
	it('should return directory names from fixtures dir', () =>
	{
		fs.readdirSync.mockReturnValue([
			'section3-state-a',
			'baseline',
			'README.md'
		]);
		fs.statSync.mockImplementation((p) =>
		{
			return {isDirectory: () => !p.endsWith('.md')};
		});

		const states = getAvailableStates();

		expect(states).toContain('section3-state-a');
		expect(states).toContain('baseline');
		expect(states).not.toContain('README.md');
	});
});

describe('FIXTURES_DIR', () =>
{
	it('should point to cmdt-states directory', () =>
	{
		expect(FIXTURES_DIR).toContain('cmdt-states');
	});
});

describe('STAGING_DIR', () =>
{
	it('should be under home directory, not /tmp', () =>
	{
		expect(STAGING_DIR).toContain(os.homedir());
		expect(STAGING_DIR).not.toContain('/tmp');
	});
});

// ─────────────────────────────────────────────────────────────────────────────
// F.B.3 — NamedOrgNotFoundError + isNamedOrgNotFoundError
// ─────────────────────────────────────────────────────────────────────────────

describe('isNamedOrgNotFoundError', () =>
{
	it('matches "No AuthInfo found for name"', () =>
	{
		expect(isNamedOrgNotFoundError('Error: No AuthInfo found for name MyOrg')).toBe(true);
	});

	it('matches "No authenticated found for alias"', () =>
	{
		expect(isNamedOrgNotFoundError('No authenticated found for alias MyOrg')).toBe(true);
	});

	it('matches "No org configuration found for name"', () =>
	{
		expect(isNamedOrgNotFoundError('No org configuration found for name MyOrg')).toBe(true);
	});

	it('matches the bare error code NamedOrgNotFound', () =>
	{
		expect(isNamedOrgNotFoundError('{"name":"NamedOrgNotFound","message":"..."}')).toBe(true);
	});

	it('returns false for unrelated errors', () =>
	{
		expect(isNamedOrgNotFoundError('Connection timeout')).toBe(false);
		expect(isNamedOrgNotFoundError('Deploy failed: insufficient permissions')).toBe(false);
	});

	it('returns false for empty/null input', () =>
	{
		expect(isNamedOrgNotFoundError('')).toBe(false);
		expect(isNamedOrgNotFoundError(null)).toBe(false);
		expect(isNamedOrgNotFoundError(undefined)).toBe(false);
	});
});

describe('NamedOrgNotFoundError', () =>
{
	it('is an Error subclass with name + orgAlias properties', () =>
	{
		const err = new NamedOrgNotFoundError('MyOrg', 'underlying');
		expect(err).toBeInstanceOf(Error);
		expect(err.name).toBe('NamedOrgNotFoundError');
		expect(err.orgAlias).toBe('MyOrg');
	});

	it('embeds the alias in the remediation message', () =>
	{
		const err = new NamedOrgNotFoundError('MyOrg', 'underlying');
		expect(err.message).toContain('MyOrg');
		expect(err.message).toContain('sf org login web --alias MyOrg');
		expect(err.message).toContain('sf alias set MyOrg=');
		expect(err.message).toContain('SF_SUBSCRIBER_ORG_ALIAS');
	});
});

describe('deployCmdtState — NamedOrgNotFoundError path', () =>
{
	beforeEach(() =>
	{
		jest.clearAllMocks();
	});

	it('throws NamedOrgNotFoundError when sf reports unknown org alias', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readdirSync.mockReturnValue([]);
		const err = new Error('Command failed: sf project deploy start');
		err.stderr = 'Error: No AuthInfo found for name MyOrg';
		err.stdout = '';
		execSync.mockImplementation(() => { throw err; });

		expect(() => deployCmdtState('baseline')).toThrow(NamedOrgNotFoundError);
	});

	it('re-throws other sf failures verbatim (no false-positive name match)', () =>
	{
		fs.existsSync.mockReturnValue(true);
		fs.readdirSync.mockReturnValue([]);
		const err = new Error('Command failed: sf project deploy start');
		err.stderr = 'Error: Connection timeout';
		err.stdout = '';
		execSync.mockImplementation(() => { throw err; });

		expect(() => deployCmdtState('baseline')).toThrow('Command failed');
		expect(() => deployCmdtState('baseline')).not.toThrow(NamedOrgNotFoundError);
	});
});
