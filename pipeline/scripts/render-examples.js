#!/usr/bin/env node
// SPDX-License-Identifier: MIT
'use strict';

/**
 * @description Re-renders examples/workflows/*.yml from the workflow templates
 *              with the vanilla "subscriber init" configuration the examples
 *              README describes. `npm run render-examples` in pipeline/ writes
 *              the files; the examples test imports `renderExample` to prove
 *              each committed copy equals a fresh render.
 *
 * @author Kern Framework
 * @date October 2026
 */

const path = require('node:path');
const fs = require('node:fs');
const {renderTemplate} = require('../src/lib/scaffold.js');

const TEMPLATES_DIR = path.join(__dirname, '..', 'src', 'templates', 'workflows');
const EXAMPLES_DIR = path.join(__dirname, '..', '..', 'examples', 'workflows');

const EXAMPLE_CONFIGURATION = {
	ingressBranches: ['main'],
	protectedBranches: ['main'],
	releaseBranches: [],
	packageDirs: ['force-app/main/default'],
	nodeVersion: '22',
	runsOn: 'ubuntu-latest',
	ciAdapterName: 'none',
	slack: {enabled: false},
	ruleSelector: 'pmd,flow,eslint',
	requiredChecks: [
		'Static Code Analysis',
		'Naming Validation'
	],
	bypassActors: [],
	reviewers: {configFile: '.github/reviewers.json', schemaFile: '.github/reviewers.schema.json'},
	codeownersTeamSlackId: ''
};

function listExamples()
{
	return fs.readdirSync(EXAMPLES_DIR).filter(entry => entry.endsWith('.yml')).sort();
}

function renderExample(fileName)
{
	const templatePath = path.join(TEMPLATES_DIR, `${fileName}.eta`);
	return renderTemplate(templatePath, EXAMPLE_CONFIGURATION, {views: TEMPLATES_DIR});
}

function renderExamples()
{
	for(const fileName of listExamples())
	{
		fs.writeFileSync(path.join(EXAMPLES_DIR, fileName), renderExample(fileName));
		console.log('rendered', fileName);
	}
}

if(require.main === module)
{
	renderExamples();
}

module.exports = {EXAMPLES_DIR, EXAMPLE_CONFIGURATION, listExamples, renderExample, renderExamples};
