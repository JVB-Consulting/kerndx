// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const path = require('path');

const RESULTS_DIR = path.join(__dirname, '..', 'results');
const CURRENT_RUN_PATH = path.join(RESULTS_DIR, 'current-run.json');

function compile(version)
{
	if(!fs.existsSync(CURRENT_RUN_PATH))
	{
		console.error('No current-run.json found. Run Phase 2 and 3 first.');
		process.exit(1);
	}

	const data = JSON.parse(fs.readFileSync(CURRENT_RUN_PATH, 'utf8'));
	const outputPath = path.join(RESULTS_DIR, `${version}.md`);

	let md = `# KernDX Release Test Results — ${version}\n\n`;
	md += `**Test Date:** ${data.testDate || new Date().toISOString().split('T')[0]}\n`;
	md += `**Package Version ID:** ${data.subscriberPackageVersionId || 'N/A'}\n`;
	if(data.apiVersion)
	{
		md += `**Platform / API Version:** ${data.apiVersion}\n`;
	}
	md += '\n';

	md += '## Phase 2 — Automated Tests\n\n';
	md += '### Apex Scripts\n\n';
	md += '| Section | Result | Score | Notes |\n';
	md += '|---------|--------|-------|-------|\n';

	if(data.phase2?.scripts)
	{
		const sorted = Object.entries(data.phase2.scripts).sort((a, b) =>
		{
			const numA = parseInt(a[0].replace('section-', ''));
			const numB = parseInt(b[0].replace('section-', ''));
			return numA - numB;
		});

		for(const [key, val] of sorted)
		{
			md += `| ${key} | ${val.result} | ${val.score || ''} | ${val.notes || ''} |\n`;
		}
	}

	md += '\n### Test Classes\n\n';
	if(data.phase2?.testClasses)
	{
		const tc = data.phase2.testClasses;
		md += `- **Result:** ${tc.result}\n`;
		md += `- **Passed:** ${tc.passed}\n`;
		md += `- **Failed:** ${tc.failed}\n`;
		md += `- **Coverage:** ${tc.coverage}\n`;
	}

	md += '\n### Scanner\n\n';
	if(data.phase2?.scanner)
	{
		md += `- **PMD Violations:** ${data.phase2.scanner.violations}\n`;
	}
	if(data.phase2?.eslint)
	{
		md += `- **ESLint Fixture Violations:** ${data.phase2.eslint.fixtureViolations}\n`;
		md += `- **ESLint Framework Violations:** ${data.phase2.eslint.frameworkViolations}\n`;
	}

	md += '\n## Phase 3 — Visual Tests\n\n';

	const partNames = {
		1: 'App Home & Core Pages',
		2: 'API Results, Config & Login',
		3: 'Subscriber LWC & Account Integration',
		4: 'Scheduler Execution',
		5: 'Streaming — Setup & Subscribe',
		6: 'Streaming — Advanced & Cleanup',
		7: 'Async Chain Orchestration',
		8: 'Chain Monitor UI'
	};

	const partKeys = Object.keys(data.phase3 || {})
	.filter(key => /^part\d+$/.test(key))
	.sort((a, b) => parseInt(a.slice(4)) - parseInt(b.slice(4)));

	for(const partKey of partKeys)
	{
		const i = parseInt(partKey.slice(4));
		const partData = data.phase3[partKey];
		if(!partData)
		{
			continue;
		}

		md += `### Part ${i}: ${partNames[i] || 'Additional Checks'}\n\n`;
		md += '| # | Check | Result | Notes |\n';
		md += '|---|-------|--------|-------|\n';

		const sorted = Object.entries(partData).sort((a, b) =>
		{
			const numA = parseInt(a[0].replace('V', ''));
			const numB = parseInt(b[0].replace('V', ''));
			return numA - numB;
		});

		for(const [check, val] of sorted)
		{
			md += `| ${check} | ${val.result} | ${val.notes || ''} |\n`;
		}
		md += '\n';
	}

	if(data.extendedLoad)
	{
		md += '## Extended Load\n\n';
		md += `- **Status:** ${data.extendedLoad.status}\n`;
		if(data.extendedLoad.notes)
		{
			md += `- **Notes:** ${data.extendedLoad.notes}\n`;
		}
		md += '\n';
	}

	md += '## Verdict\n\n';

	const allPhase2Pass = data.phase2?.scripts && Object.values(data.phase2.scripts).every(s => s.result === 'PASS') && data.phase2?.testClasses?.result === 'PASS';

	const allPhase3Pass = data.phase3 && Object.values(data.phase3).every(part => typeof part === 'object' && Object.values(part).every(v => v.result === 'PASS'));

	const overall = allPhase2Pass && allPhase3Pass ? 'ALL PASS' : 'FAIL';
	md += `**Overall:** ${overall}\n`;

	if(data.phase3Automated)
	{
		md += '\n*Phase 3 visual tests were executed via Playwright automation.*\n';
	}

	fs.writeFileSync(outputPath, md, 'utf8');
	console.log(`Results compiled to ${outputPath}`);
	return outputPath;
}

if(require.main === module)
{
	const version = process.argv[2];
	if(!version)
	{
		console.error('Usage: node result-compiler.js <version>');
		console.error('Example: node result-compiler.js 1.0.0-53');
		process.exit(1);
	}
	compile(version);
}

module.exports = {compile};
