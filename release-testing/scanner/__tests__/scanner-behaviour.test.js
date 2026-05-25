// SPDX-License-Identifier: BUSL-1.1
'use strict';

const {execSync} = require('child_process');
const path = require('path');

const RELEASE_TESTING = path.resolve(__dirname, '..', '..');
const PROJECT_ROOT = path.resolve(RELEASE_TESTING, '..');
const FIXTURE_LWC = path.resolve(RELEASE_TESTING, 'scanner', 'lwc');
const FIXTURE_NAMING = path.resolve(RELEASE_TESTING, 'scanner', 'naming-metadata');

function runESLint(targetDir)
{
	const config = path.join(FIXTURE_LWC, 'eslint.config.mjs');
	try
	{
		const output = execSync(`ESLINT_USE_FLAT_CONFIG=true npx eslint --config "${config}" "${targetDir}/**/*.js" --format json`, {
			encoding: 'utf-8', cwd: PROJECT_ROOT, stdio: [
				'pipe',
				'pipe',
				'pipe'
			]
		});
		return {exitCode: 0, results: JSON.parse(output)};
	}
	catch(error)
	{
		if(error.stdout)
		{
			try
			{
				return {exitCode: error.status, results: JSON.parse(error.stdout)};
			}
			catch(_)
			{ /* fall through */
			}
		}
		return {exitCode: error.status, output: error.stdout || '', stderr: error.stderr || ''};
	}
}

function runValidateNaming(forceAppPath)
{
	const script = path.resolve(PROJECT_ROOT, 'scanner', 'validate-naming.js');
	try
	{
		const output = execSync(`node "${script}" "${forceAppPath}"`, {
			encoding: 'utf-8', stdio: [
				'pipe',
				'pipe',
				'pipe'
			]
		});
		return {exitCode: 0, output};
	}
	catch(error)
	{
		return {exitCode: error.status, output: error.stdout || '', stderr: error.stderr || ''};
	}
}

function getViolationsForFile(results, filename)
{
	const entry = results.find(r => r.filePath.includes(filename));
	return entry ? entry.messages : [];
}

describe('Scanner behaviour (real-world fixtures)', () =>
{
	let eslintResult;

	beforeAll(() =>
	{
		eslintResult = runESLint(FIXTURE_LWC);
	});

	describe('ESLint: kerndx/no-console-log', () =>
	{
		it('should catch all three console patterns (bare, window, globalThis)', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestViolation/scannerTestViolation.js');
			const consoleViolations = msgs.filter(m => m.ruleId === 'kerndx/no-console-log');
			expect(consoleViolations.length).toBe(3);
		});

		it('should catch console.log on line 16', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestViolation/scannerTestViolation.js');
			const line16 = msgs.find(m => m.ruleId === 'kerndx/no-console-log' && m.line === 16);
			expect(line16).toBeDefined();
			expect(line16.message).toContain('console.log()');
		});

		it('should catch window.console.warn on line 17', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestViolation/scannerTestViolation.js');
			const line17 = msgs.find(m => m.ruleId === 'kerndx/no-console-log' && m.line === 17);
			expect(line17).toBeDefined();
			expect(line17.message).toContain('console.warn()');
		});

		it('should catch globalThis.console.error on line 18', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestViolation/scannerTestViolation.js');
			const line18 = msgs.find(m => m.ruleId === 'kerndx/no-console-log' && m.line === 18);
			expect(line18).toBeDefined();
			expect(line18.message).toContain('console.error()');
		});

		it('should produce zero console violations for compliant component', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestCompliant/scannerTestCompliant.js');
			const consoleViolations = msgs.filter(m => m.ruleId === 'kerndx/no-console-log');
			expect(consoleViolations.length).toBe(0);
		});
	});

	describe('ESLint: kerndx/use-component-builder', () =>
	{
		it('should catch direct LightningElement usage', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestViolation/scannerTestViolation.js');
			const violations = msgs.filter(m => m.ruleId === 'kerndx/use-component-builder');
			expect(violations.length).toBe(1);
		});

		it('should catch aliased LightningElement import', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestAliasViolation/scannerTestAliasViolation.js');
			const violations = msgs.filter(m => m.ruleId === 'kerndx/use-component-builder');
			expect(violations.length).toBe(1);
		});

		it('should allow suppression via eslint-disable', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestSuppressed/scannerTestSuppressed.js');
			const violations = msgs.filter(m => m.ruleId === 'kerndx/use-component-builder');
			expect(violations.length).toBe(0);
		});

		it('should produce zero builder violations for compliant component', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'scannerTestCompliant/scannerTestCompliant.js');
			const violations = msgs.filter(m => m.ruleId === 'kerndx/use-component-builder');
			expect(violations.length).toBe(0);
		});
	});

	describe('ESLint: kerndx/enforce-component-naming', () =>
	{
		it('should catch LWC without domain prefix', () =>
		{
			const msgs = getViolationsForFile(eslintResult.results, 'returnWizard/returnWizard.js');
			const violations = msgs.filter(m => m.ruleId === 'kerndx/enforce-component-naming');
			expect(violations.length).toBe(1);
			expect(violations[0].message).toContain('returnWizard');
		});

		it('should flag all non-domain-prefixed fixture components', () =>
		{
			const allNamingViolations = [];
			for(const entry of eslintResult.results)
			{
				for(const msg of entry.messages)
				{
					if(msg.ruleId === 'kerndx/enforce-component-naming')
					{
						allNamingViolations.push(entry.filePath);
					}
				}
			}
			expect(allNamingViolations.length).toBeGreaterThanOrEqual(1);
		});
	});

	describe('validate-naming.js: Flows', () =>
	{
		let result;

		beforeAll(() =>
		{
			result = runValidateNaming(FIXTURE_NAMING);
		});

		it('should exit 1 when violations exist', () =>
		{
			expect(result.exitCode).toBe(1);
		});

		it('should flag Flow missing domain prefix (Case_BS_SetDefaults)', () =>
		{
			expect(result.output).toContain('Case_BS_SetDefaults');
		});

		it('should flag Flow missing type code (ORD_Order_SyncToBigCommerce)', () =>
		{
			expect(result.output).toContain('ORD_Order_SyncToBigCommerce');
		});

		it('should not flag valid Flow (ORD_Order_AS_SyncToBigCommerce)', () =>
		{
			const lines = result.output.split('\n');
			const violationLines = lines.filter(l => l.includes('ORD_Order_AS_SyncToBigCommerce'));
			const isViolation = violationLines.some(l => l.includes('Expected'));
			expect(isViolation).toBe(false);
		});

		it('should not flag valid brand-prefixed Flow (SVC_EAR_Case_BS_SetDefaultPriority)', () =>
		{
			const lines = result.output.split('\n');
			const violationLines = lines.filter(l => l.includes('SVC_EAR_Case_BS_SetDefaultPriority'));
			const isViolation = violationLines.some(l => l.includes('Expected'));
			expect(isViolation).toBe(false);
		});
	});

	describe('validate-naming.js: Custom Objects', () =>
	{
		let result;

		beforeAll(() =>
		{
			result = runValidateNaming(FIXTURE_NAMING);
		});

		it('should flag object missing domain prefix (BadObjectName__c)', () =>
		{
			expect(result.output).toContain('BadObjectName__c');
		});

		it('should not flag valid custom object (SVC_WarrantyClaim__c)', () =>
		{
			const lines = result.output.split('\n');
			const violationLines = lines.filter(l => l.includes('SVC_WarrantyClaim__c'));
			const isViolation = violationLines.some(l => l.includes('Expected'));
			expect(isViolation).toBe(false);
		});

		it('should skip standard objects (Account)', () =>
		{
			const lines = result.output.split('\n');
			const accountLines = lines.filter(l => /\bAccount\b/.test(l) && l.includes('Expected'));
			expect(accountLines.length).toBe(0);
		});

		it('should not flag valid brand-prefixed object (ORD_ACM_FulfilmentRule__c)', () =>
		{
			const lines = result.output.split('\n');
			const violationLines = lines.filter(l => l.includes('ORD_ACM_FulfilmentRule__c'));
			const isViolation = violationLines.some(l => l.includes('Expected'));
			expect(isViolation).toBe(false);
		});
	});

	describe('validate-naming.js: output format', () =>
	{
		let result;

		beforeAll(() =>
		{
			result = runValidateNaming(FIXTURE_NAMING);
		});

		it('should display header', () =>
		{
			expect(result.output).toContain('Naming Standards Validator');
		});

		it('should show artefact count', () =>
		{
			expect(result.output).toMatch(/Checked: \d+ artefacts/);
		});

		it('should show violation count', () =>
		{
			expect(result.output).toMatch(/\d+ violation/);
		});

		it('should note PMD/ESLint covers other artefacts', () =>
		{
			expect(result.output).toContain('PMD and ESLint');
		});
	});
});
