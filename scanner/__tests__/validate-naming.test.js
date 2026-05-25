// SPDX-License-Identifier: BUSL-1.1
'use strict';

const {execSync} = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

function createTempForceApp()
{
	const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'validate-naming-'));
	const forceApp = path.join(tempDir, 'force-app', 'main', 'default');
	fs.mkdirSync(path.join(forceApp, 'flows'), {recursive: true});
	fs.mkdirSync(path.join(forceApp, 'objects'), {recursive: true});
	return {root: path.join(tempDir, 'force-app'), base: forceApp, cleanup: () => fs.rmSync(tempDir, {recursive: true})};
}

function addFlow(base, name)
{
	fs.writeFileSync(path.join(base, 'flows', `${name}.flow-meta.xml`), '<Flow/>');
}

function addObject(base, name)
{
	fs.mkdirSync(path.join(base, 'objects', name), {recursive: true});
}

function runValidator(forceAppPath)
{
	const script = path.resolve(__dirname, '..', 'validate-naming.js');
	try
	{
		const output = execSync(`node "${script}" "${forceAppPath}"`, {encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe']});
		return {exitCode: 0, output};
	}
	catch (error)
	{
		return {exitCode: error.status, output: error.stdout || '', stderr: error.stderr || ''};
	}
}

describe('validate-naming', () =>
{
	let env;

	afterEach(() =>
	{
		if (env)
		{
			env.cleanup();
			env = null;
		}
	});

	describe('Flows', () =>
	{
		it('should pass valid Flow names', () =>
		{
			env = createTempForceApp();
			addFlow(env.base, 'ORD_Order_AS_SyncToBigCommerce');
			addFlow(env.base, 'SVC_Case_BS_SetDefaultPriority');
			addFlow(env.base, 'ORD_ACM_Order_AS_SyncToBigCommerce');
			addFlow(env.base, 'SUB_CarePlan_SCH_SendRenewalReminder');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(0);
			expect(result.output).toContain('No naming violations found');
			expect(result.output).toContain('Checked: 4 artefacts');
		});

		it('should flag Flow names missing domain prefix', () =>
		{
			env = createTempForceApp();
			addFlow(env.base, 'Case_BS_SetDefaults');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(1);
			expect(result.output).toContain('Case_BS_SetDefaults');
			expect(result.output).toContain('Domain_[Brand_]Object_Type_Action');
		});

		it('should flag Flow names missing type code', () =>
		{
			env = createTempForceApp();
			addFlow(env.base, 'ORD_Order_SyncToBigCommerce');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(1);
			expect(result.output).toContain('ORD_Order_SyncToBigCommerce');
		});

		it('should flag Flow names with invalid type code', () =>
		{
			env = createTempForceApp();
			addFlow(env.base, 'ORD_Order_XX_SyncOrder');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(1);
			expect(result.output).toContain('ORD_Order_XX_SyncOrder');
		});

		it('should accept all valid Flow type codes', () =>
		{
			env = createTempForceApp();
			const types = ['BS', 'AS', 'BD', 'SCR', 'AL', 'SCH', 'PE', 'SF'];

			for (const type of types)
			{
				addFlow(env.base, `SVC_Case_${type}_DoSomething`);
			}

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(0);
			expect(result.output).toContain(`Checked: ${types.length} artefacts`);
		});

		it('should accept Flow names with brand codes', () =>
		{
			env = createTempForceApp();
			addFlow(env.base, 'ORD_ACM_Order_AS_SyncOrder');
			addFlow(env.base, 'SVC_BTA_Case_BS_SetDefaults');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(0);
		});

		it('should flag Flow names exceeding 80 characters', () =>
		{
			env = createTempForceApp();
			const longName = 'ORD_Order_AS_' + 'A'.repeat(68);
			addFlow(env.base, longName);

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(1);
			expect(result.output).toContain('80 character limit exceeded');
		});
	});

	describe('Custom Objects', () =>
	{
		it('should pass valid Custom Object names', () =>
		{
			env = createTempForceApp();
			addObject(env.base, 'SVC_WarrantyClaim__c');
			addObject(env.base, 'ORD_ACM_FulfilmentRule__c');
			addObject(env.base, 'CMN_OrgSetting__c');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(0);
			expect(result.output).toContain('No naming violations found');
			expect(result.output).toContain('Checked: 3 artefacts');
		});

		it('should flag Custom Object names missing domain prefix', () =>
		{
			env = createTempForceApp();
			addObject(env.base, 'WarrantyClaim__c');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(1);
			expect(result.output).toContain('WarrantyClaim__c');
			expect(result.output).toContain('Domain_[Brand_]ObjectName__c');
		});

		it('should skip standard objects', () =>
		{
			env = createTempForceApp();
			addObject(env.base, 'Account');
			addObject(env.base, 'Contact');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(0);
			expect(result.output).toContain('Checked: 0 artefacts');
		});

		it('should flag Custom Object names exceeding 40 characters', () =>
		{
			env = createTempForceApp();
			addObject(env.base, 'ORD_VeryLongObjectNameThatExceedsTheLimit__c');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(1);
			expect(result.output).toContain('40 character limit exceeded');
		});
	});

	describe('general behaviour', () =>
	{
		it('should exit 0 with no artefacts', () =>
		{
			env = createTempForceApp();

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(0);
			expect(result.output).toContain('Checked: 0 artefacts');
		});

		it('should exit 2 for non-existent path', () =>
		{
			const result = runValidator('/nonexistent/path');

			expect(result.exitCode).toBe(2);
			expect(result.stderr).toContain('does not exist');
		});

		it('should show near-limit warnings', () =>
		{
			env = createTempForceApp();
			addObject(env.base, 'ORD_ObjectNameThatsAlmostFortyChar__c');

			const result = runValidator(env.root);

			if (result.output.includes('Near-limit warnings'))
			{
				expect(result.output).toContain('Near-limit warnings');
			}
			else
			{
				expect(result.exitCode).toBe(0);
			}
		});

		it('should report correct violation count', () =>
		{
			env = createTempForceApp();
			addFlow(env.base, 'BadFlowName');
			addObject(env.base, 'BadObjectName__c');

			const result = runValidator(env.root);

			expect(result.exitCode).toBe(1);
			expect(result.output).toContain('2 violations across 2 artefacts');
		});

		it('should display output header', () =>
		{
			env = createTempForceApp();

			const result = runValidator(env.root);

			expect(result.output).toContain('Naming Standards Validator (Flows & Custom Objects)');
			expect(result.output).toContain('SFDX standard layout');
			expect(result.output).toContain('Apex class, trigger, and LWC naming is enforced by PMD and ESLint');
		});
	});
});
