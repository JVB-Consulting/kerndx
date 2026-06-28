// SPDX-License-Identifier: BUSL-1.1
'use strict';

// scripts/lib/metrics-counts.js
//
// Shared source-tree counters for object + field metrics in
// docs/Strategic Guide - Metrics.md. Factored out of
// validate-strategic-metrics.js so the validator (and any future
// source-derived drift guard) share one implementation of "how do we count
// custom objects, custom metadata types, platform events, and custom fields".
//
// Pure fs traversal, no I/O beyond reading directory listings — trivially
// unit-testable against a temp repo.

const fs = require('node:fs');
const path = require('node:path');

/**
 * @description Lists the immediate subdirectory names under
 * force-app/main/default/objects (each is one SObject definition).
 *
 * @param {string} repoRoot
 * @return {Array<string>}
 */
function listObjectDirs(repoRoot)
{
	const objectsDir = path.join(repoRoot, 'force-app', 'main', 'default', 'objects');
	if(!fs.existsSync(objectsDir))
	{
		return [];
	}
	return fs.readdirSync(objectsDir, {withFileTypes: true})
	.filter(entry => entry.isDirectory())
	.map(entry => entry.name);
}

/**
 * @description Counts object dirs whose name ends with the given suffix
 * (`__c` custom objects, `__mdt` custom metadata types, `__e` platform events).
 *
 * @param {string} repoRoot
 * @param {string} suffix
 * @return {number}
 */
function countObjectsBySuffix(repoRoot, suffix)
{
	return listObjectDirs(repoRoot).filter(name => name.endsWith(suffix)).length;
}

function countCustomObjects(repoRoot)
{
	return countObjectsBySuffix(repoRoot, '__c');
}

function countCmdtTypes(repoRoot)
{
	return countObjectsBySuffix(repoRoot, '__mdt');
}

function countPlatformEvents(repoRoot)
{
	return countObjectsBySuffix(repoRoot, '__e');
}

/**
 * @description Counts `*.field-meta.xml` files under every object's `fields/`
 * directory, broken down by parent object suffix.
 *
 * @param {string} repoRoot
 * @return {{total: number, customObject: number, customMetadata: number, platformEvent: number}}
 */
function countCustomFields(repoRoot)
{
	const objectsDir = path.join(repoRoot, 'force-app', 'main', 'default', 'objects');
	const result = {total: 0, customObject: 0, customMetadata: 0, platformEvent: 0};
	for(const name of listObjectDirs(repoRoot))
	{
		const fieldsDir = path.join(objectsDir, name, 'fields');
		if(!fs.existsSync(fieldsDir))
		{
			continue;
		}
		const count = fs.readdirSync(fieldsDir).filter(file => file.endsWith('.field-meta.xml')).length;
		result.total += count;
		if(name.endsWith('__c'))
		{
			result.customObject += count;
		}
		else if(name.endsWith('__mdt'))
		{
			result.customMetadata += count;
		}
		else if(name.endsWith('__e'))
		{
			result.platformEvent += count;
		}
	}
	return result;
}

module.exports = {
	listObjectDirs,
	countObjectsBySuffix,
	countCustomObjects,
	countCmdtTypes,
	countPlatformEvents,
	countCustomFields
};
