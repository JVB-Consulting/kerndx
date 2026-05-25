// SPDX-License-Identifier: MIT
'use strict';
const path = require('node:path');
const fs = require('node:fs');
const { Eta } = require('eta');

function renderTemplate(templatePath, data, { views } = {})
{
	const eta = new Eta({
		views: views || path.dirname(templatePath),
		cache: false,
		autoEscape: false,
		useWith: true,
		tags: ['<%', '%>'],
	});
	const tmplContent = fs.readFileSync(templatePath, 'utf-8');
	return eta.renderString(tmplContent, data);
}

module.exports = { renderTemplate };
