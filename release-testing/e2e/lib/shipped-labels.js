// SPDX-License-Identifier: Apache-2.0
// The shipped Custom Label values, read straight from source metadata.
//
// Both prototype gap-finders (gap-finder-chain-monitor.js and specs/gap-finder-log-console.spec.js)
// judge deployed copy against the label file rather than against a hardcoded string, so the reader
// lives here once instead of being duplicated in each of them.
//
// This directory is deliberately NOT `helpers/`: jest collects coverage from
// release-testing/e2e/helpers/**, and a module only ever loaded by Playwright would land there as a
// permanent zero-coverage file. Nothing here matches jest's testMatch either, so `npm run test:unit`
// never picks it up.
const fs = require('fs');
const path = require('path');

const LABELS_PATH = path.join(__dirname, '..', '..', '..', 'force-app', 'main', 'default', 'labels', 'CustomLabels.labels-meta.xml');

function decodeXmlEntities(value)
{
	return value.replace(/&apos;/g, '\'').replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
}

/**
 * @description Every Custom Label in the package, keyed by API name, with XML entities decoded so a
 *              value compares byte-for-byte against the text a browser renders.
 * @returns {Object<string, string>}
 */
function readShippedLabelValues()
{
	const labelsXml = fs.readFileSync(LABELS_PATH, 'utf8');
	const values = {};
	for(const match of labelsXml.matchAll(/<fullName>([^<]+)<\/fullName>[\s\S]*?<value>([^<]*)<\/value>/g))
	{
		values[match[1]] = decodeXmlEntities(match[2]);
	}
	return values;
}

module.exports = {readShippedLabelValues};
