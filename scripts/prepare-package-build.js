#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Build preparation script for Kern managed package.
 * Adds namespace prefixes to source files for managed package builds.
 *
 * Usage:
 *   node scripts/prepare-package-build.js           # Add namespace prefixes
 *   node scripts/prepare-package-build.js --dry-run # Preview changes without modifying
 *   node scripts/prepare-package-build.js --verbose # Show detailed output
 *
 * @author Kern Framework
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
	SFDX_PROJECT_FILE: 'sfdx-project.json',
	SOURCE_DIR: 'force-app/main/default',

	// Custom metadata types and their class reference fields (use dot notation: Namespace.ClassName)
	// Note: ClassTypeResolver is excluded - it supports non-namespaced class references
	METADATA_CLASS_FIELDS: {
		TriggerAction: ['ApexClassName__c', 'EntryCriteriaContextClassName__c'],
		ApiSetting: ['ClassName__c'],
		ApiDataMask: ['ClassName__c'],
		FeatureFlagStrategy: ['CustomHandler__c'],
		ValidationRule: ['ContextClassName__c'],
		ValidationRuleGroup: ['ContextClassName__c']
	},

	// Custom metadata types with object/field reference fields (use double underscore: Namespace__Name)
	METADATA_OBJECT_FIELDS: {
		ApiCredential: ['NamedCredential__c'],
		FieldSetGroup: ['DefaultActiveSections__c', 'FieldSetApiNames__c']
	},

	// FlexiPage properties that need object namespace prefixes
	FLEXIPAGE_OBJECT_PROPERTIES: ['objectApiName', 'fieldSetApiName'],

	// FlexiPage properties with embedded object references (key=value format)
	FLEXIPAGE_EMBEDDED_OBJECT_PROPERTIES: ['controllerSearchParameters'],

	// LWC properties with apex:// type references
	LWC_APEX_TYPE_PATTERN: /type="apex:\/\//,

	// LWC JS tab API names that need Namespace__ prefix for standard__navItemPage navigation
	LWC_TAB_API_NAMES: ['ApiTestHarness', 'StreamingEventMonitor', 'ChainMonitor'],

	// Flow files that need namespace prefixing for managed package field resolution
	FLOW_FILES: [
		'InvokeOutboundApiCall.flow-meta.xml',
		'ResetOutboundApiCall.flow-meta.xml',
		'RetryOutboundApiCall.flow-meta.xml'
	]
};

// ============================================================================
// Namespace Functions
// ============================================================================

/**
 * @description Checks if a class name needs a namespace prefix.
 * @param {string} value - The class name to check.
 * @param {string} namespace - The namespace to check for.
 * @returns {boolean} True if prefix is needed.
 */
function needsClassPrefix(value, namespace)
{
	if (!value || typeof value !== 'string')
	{
		return false;
	}
	// Already has a namespace (contains dot)
	if (value.includes('.'))
	{
		return false;
	}
	// Is an object reference (contains double underscore)
	if (value.includes('__'))
	{
		return false;
	}
	return true;
}

/**
 * @description Checks if an object name needs a namespace prefix.
 * @param {string} value - The object name to check.
 * @param {string} namespace - The namespace to check for.
 * @returns {boolean} True if prefix is needed.
 */
function needsObjectPrefix(value, namespace)
{
	if (!value || typeof value !== 'string')
	{
		return false;
	}
	// Must be a custom object (ends with __c)
	if (!value.endsWith('__c'))
	{
		return false;
	}
	// Already has namespace prefix
	if (value.startsWith(namespace + '__'))
	{
		return false;
	}
	// Check if it's already namespaced (has __ before the __c)
	const withoutSuffix = value.slice(0, -3);
	if (withoutSuffix.includes('__'))
	{
		return false;
	}
	return true;
}

/**
 * @description Checks if an API name needs a namespace prefix.
 * These are names like fieldset names or named credentials that get Namespace__ prefix.
 * @param {string} value - The API name to check.
 * @param {string} namespace - The namespace to check for.
 * @returns {boolean} True if prefix is needed.
 */
function needsApiNamePrefix(value, namespace)
{
	if (!value || typeof value !== 'string')
	{
		return false;
	}
	// Already has namespace prefix
	if (value.startsWith(namespace + '__'))
	{
		return false;
	}
	// Already contains __ (some other namespace or custom suffix)
	if (value.includes('__'))
	{
		return false;
	}
	return true;
}

/**
 * @description Adds namespace prefix to a class name.
 * @param {string} value - The class name.
 * @param {string} namespace - The namespace to add.
 * @returns {string} The namespaced class name.
 */
function addClassNamespace(value, namespace)
{
	if (!needsClassPrefix(value, namespace))
	{
		return value;
	}
	return `${namespace}.${value}`;
}

/**
 * @description Adds namespace prefix to an object name.
 * @param {string} value - The object name.
 * @param {string} namespace - The namespace to add.
 * @returns {string} The namespaced object name.
 */
function addObjectNamespace(value, namespace)
{
	if (!needsObjectPrefix(value, namespace))
	{
		return value;
	}
	return `${namespace}__${value}`;
}

/**
 * @description Adds namespace prefix to an API name.
 * @param {string} value - The API name.
 * @param {string} namespace - The namespace to add.
 * @returns {string} The namespaced API name.
 */
function addApiNamespace(value, namespace)
{
	if (!needsApiNamePrefix(value, namespace))
	{
		return value;
	}
	return `${namespace}__${value}`;
}

// ============================================================================
// Metadata Type Detection
// ============================================================================

/**
 * @description Extracts the metadata type from a filename.
 * @param {string} filename - The filename (e.g., 'TriggerAction.Foobar_BeforeInsert.md-meta.xml').
 * @returns {string|null} The metadata type or null.
 */
function getMetadataTypeFromFilename(filename)
{
	const basename = path.basename(filename);
	const dotIndex = basename.indexOf('.');
	if (dotIndex === -1)
	{
		return null;
	}
	return basename.substring(0, dotIndex);
}

// ============================================================================
// XML Transformation Functions
// ============================================================================

/**
 * @description Transforms class references in custom metadata content.
 * @param {string} content - The XML content.
 * @param {string} namespace - The namespace to add.
 * @param {string[]} fields - The field names to transform.
 * @returns {{content: string, changes: string[]}} The transformed content and list of changes.
 */
function transformCustomMetadataContent(content, namespace, fields)
{
	const changes = [];
	let result = content;

	for (const field of fields)
	{
		// Pattern to match: <field>FieldName</field> followed by <value xsi:type="xsd:string">ClassName</value>
		const regex = new RegExp(
			`(<field>${field}</field>\\s*<value\\s+xsi:type="xsd:string">)([^<]+)(</value>)`,
			'g'
		);

		result = result.replace(regex, (match, prefix, className, suffix) =>
		{
			if (needsClassPrefix(className, namespace))
			{
				const newClassName = addClassNamespace(className, namespace);
				changes.push(`${field}: ${className} -> ${newClassName}`);
				return prefix + newClassName + suffix;
			}
			return match;
		});
	}

	return { content: result, changes };
}

/**
 * @description Transforms FlexiPage content (object and API name reference properties).
 * Handles both custom objects (ending in __c) and API names (like fieldset names).
 * @param {string} content - The XML content.
 * @param {string} namespace - The namespace to add.
 * @param {string[]} propertyNames - The property names to transform.
 * @param {string[]} embeddedPropertyNames - Property names with embedded object refs (key=value format).
 * @returns {{content: string, changes: string[]}} The transformed content and list of changes.
 */
function transformFlexiPageContent(content, namespace, propertyNames, embeddedPropertyNames = [])
{
	const changes = [];
	let result = content;

	// Remove conditional formatting sections (not supported in managed packages)
	const conditionalFormatRegex = /\s*<fieldInstanceProperties>\s*<name>conditionalFormatRuleset<\/name>\s*<value>[^<]*<\/value>\s*<\/fieldInstanceProperties>/g;
	const conditionalMatches = result.match(conditionalFormatRegex);
	if (conditionalMatches)
	{
		result = result.replace(conditionalFormatRegex, '');
		changes.push(`Removed ${conditionalMatches.length} conditionalFormatRuleset section(s)`);
	}

	for (const propertyName of propertyNames)
	{
		// Pattern to match: <name>propertyName</name> followed by <value>ObjectName</value>
		const regex = new RegExp(
			`(<name>${propertyName}</name>\\s*<value>)([^<]+)(</value>)`,
			'g'
		);

		result = result.replace(regex, (match, prefix, value, suffix) =>
		{
			// Check for custom object (ends with __c)
			if (value.endsWith('__c') && needsObjectPrefix(value, namespace))
			{
				const newValue = addObjectNamespace(value, namespace);
				changes.push(`${propertyName}: ${value} -> ${newValue}`);
				return prefix + newValue + suffix;
			}
			// Check for API name (fieldset names, etc.)
			if (!value.endsWith('__c') && needsApiNamePrefix(value, namespace))
			{
				const newValue = addApiNamespace(value, namespace);
				changes.push(`${propertyName}: ${value} -> ${newValue}`);
				return prefix + newValue + suffix;
			}
			return match;
		});
	}

	// Handle properties with embedded object references (key=value format)
	for (const propertyName of embeddedPropertyNames)
	{
		const regex = new RegExp(
			`(<name>${propertyName}</name>\\s*<value>)([^<]+)(</value>)`,
			'g'
		);

		result = result.replace(regex, (match, prefix, value, suffix) =>
		{
			// Parse key=value pairs and transform object references
			let modified = false;
			const newValue = value.replace(/(\w+)=(\w+__c)\b/g, (kvMatch, key, objectName) =>
			{
				if (needsObjectPrefix(objectName, namespace))
				{
					modified = true;
					return `${key}=${addObjectNamespace(objectName, namespace)}`;
				}
				return kvMatch;
			});

			if (modified)
			{
				changes.push(`${propertyName}: ${value} -> ${newValue}`);
				return prefix + newValue + suffix;
			}
			return match;
		});
	}

	return { content: result, changes };
}

/**
 * @description Transforms custom metadata API name reference fields.
 * Handles fieldset names, named credentials, and other API names that need Namespace__ prefix.
 * @param {string} content - The XML content.
 * @param {string} namespace - The namespace to add.
 * @param {string[]} fields - The field names to transform.
 * @returns {{content: string, changes: string[]}} The transformed content and list of changes.
 */
function transformCustomMetadataObjectFields(content, namespace, fields)
{
	const changes = [];
	let result = content;

	for (const field of fields)
	{
		// Pattern to match field value
		const regex = new RegExp(
			`(<field>${field}</field>\\s*<value\\s+xsi:type="xsd:string">)([^<]+)(</value>)`,
			'g'
		);

		result = result.replace(regex, (match, prefix, value, suffix) =>
		{
			// Handle comma-separated values (like FieldSetApiNames__c)
			const parts = value.split(',');
			let modified = false;
			const newParts = parts.map(part =>
			{
				// Handle colon-separated mappings (like MappingList__c: fieldName:ApiName__c)
				if (part.includes(':'))
				{
					const [key, apiName] = part.split(':');
					// API names in mappings that end with __c are objects
					if (apiName.endsWith('__c') && needsObjectPrefix(apiName, namespace))
					{
						modified = true;
						return `${key}:${addObjectNamespace(apiName, namespace)}`;
					}
					return part;
				}
				// Simple value - treat as API name needing Namespace__ prefix
				if (needsApiNamePrefix(part, namespace))
				{
					modified = true;
					return addApiNamespace(part, namespace);
				}
				return part;
			});

			if (modified)
			{
				const newValue = newParts.join(',');
				changes.push(`${field}: transformed`);
				return prefix + newValue + suffix;
			}
			return match;
		});
	}

	return { content: result, changes };
}

/**
 * @description Transforms LWC meta file content (apex:// type references).
 * @param {string} content - The XML content.
 * @param {string} namespace - The namespace to add.
 * @returns {{content: string, changes: string[]}} The transformed content and list of changes.
 */
function transformLwcMetaContent(content, namespace)
{
	const changes = [];
	let result = content;

	// Pattern to match: type="apex://ClassName" or type="apex://Namespace.ClassName" or type="apex://ClassName[]"
	// Captures both namespaced and non-namespaced class names for idempotency checking
	const regex = /(type="apex:\/\/)([A-Za-z][A-Za-z0-9_.]*[A-Za-z0-9_])(\[\])?(")/g;

	result = result.replace(regex, (match, prefix, className, arraySuffix, quote) =>
	{
		// Skip if already namespaced (contains a dot)
		if (className.includes('.'))
		{
			return match;
		}
		const newClassName = `${namespace}.${className}`;
		changes.push(`apex type: ${className} -> ${newClassName}`);
		return prefix + newClassName + (arraySuffix || '') + quote;
	});

	return { content: result, changes };
}

/**
 * @description Transforms LWC JS file content (tab API name references in navigation calls).
 * @param {string} content - The JS content.
 * @param {string} namespace - The namespace to add.
 * @param {string[]} tabApiNames - The tab API names to prefix.
 * @returns {{content: string, changes: string[]}} The transformed content and list of changes.
 */
function transformLwcJsContent(content, namespace, tabApiNames)
{
	const changes = [];
	let result = content;

	for (const tabName of tabApiNames)
	{
		// Match apiName: 'TabName', apiName: "TabName", or launchTarget: 'TabName' in
		// navigation calls. Both inline apiName literals and data-driven tools arrays
		// (as used by kernHome.js) need their tab references prefixed for subscriber
		// navigation to resolve.
		const regex = new RegExp(`((?:apiName|launchTarget):\\s*['"])${tabName}(['"])`, 'g');

		result = result.replace(regex, (match, prefix, quote) =>
		{
			const newName = `${namespace}__${tabName}`;
			changes.push(`tab reference: ${tabName} -> ${newName}`);
			return `${prefix}${newName}${quote}`;
		});
	}

	return { content: result, changes };
}

/**
 * @description Transforms flow content by adding namespace prefixes to custom field,
 * object, and apex action references. Before-save and after-save record-triggered flows
 * in managed packages do not automatically resolve field names without the namespace prefix.
 * @param {string} content - The XML content.
 * @param {string} namespace - The namespace to add.
 * @returns {{content: string, changes: string[]}} The transformed content and list of changes.
 */
function transformFlowContent(content, namespace)
{
	const changes = [];
	let result = content;

	// $Record.FieldName__c references (in assignToReference, elementReference, etc.)
	result = result.replace(/(\$Record\.)([A-Za-z][A-Za-z0-9_]*__c)/g, (match, prefix, fieldName) =>
	{
		if (needsObjectPrefix(fieldName, namespace))
		{
			const newFieldName = addObjectNamespace(fieldName, namespace);
			changes.push(`$Record field: ${fieldName} -> ${newFieldName}`);
			return prefix + newFieldName;
		}
		return match;
	});

	// <field>FieldName__c</field> (in filters and inputAssignments)
	result = result.replace(/(<field>)([A-Za-z][A-Za-z0-9_]*__c)(<\/field>)/g, (match, prefix, fieldName, suffix) =>
	{
		if (needsObjectPrefix(fieldName, namespace))
		{
			const newFieldName = addObjectNamespace(fieldName, namespace);
			changes.push(`filter/field: ${fieldName} -> ${newFieldName}`);
			return prefix + newFieldName + suffix;
		}
		return match;
	});

	// <object>ObjectName__c</object>
	result = result.replace(/(<object>)([A-Za-z][A-Za-z0-9_]*__c)(<\/object>)/g, (match, prefix, objectName, suffix) =>
	{
		if (needsObjectPrefix(objectName, namespace))
		{
			const newObjectName = addObjectNamespace(objectName, namespace);
			changes.push(`object: ${objectName} -> ${newObjectName}`);
			return prefix + newObjectName + suffix;
		}
		return match;
	});

	// <recordField>FieldName__c</recordField> (scheduled path record fields)
	result = result.replace(/(<recordField>)([A-Za-z][A-Za-z0-9_]*__c)(<\/recordField>)/g, (match, prefix, fieldName, suffix) =>
	{
		if (needsObjectPrefix(fieldName, namespace))
		{
			const newFieldName = addObjectNamespace(fieldName, namespace);
			changes.push(`recordField: ${fieldName} -> ${newFieldName}`);
			return prefix + newFieldName + suffix;
		}
		return match;
	});

	// Apex action references within <actionCalls> blocks
	result = result.replace(/<actionCalls>([\s\S]*?)<\/actionCalls>/g, (block) =>
	{
		if (!block.includes('<actionType>apex</actionType>'))
		{
			return block;
		}

		let newBlock = block;

		// Prefix <actionName>
		newBlock = newBlock.replace(/(<actionName>)([A-Za-z]\w+)(<\/actionName>)/, (match, prefix, name, suffix) =>
		{
			if (!name.includes('__'))
			{
				const newName = `${namespace}__${name}`;
				changes.push(`apex action: ${name} -> ${newName}`);
				return prefix + newName + suffix;
			}
			return match;
		});

		// Prefix <nameSegment>
		newBlock = newBlock.replace(/(<nameSegment>)([A-Za-z]\w+)(<\/nameSegment>)/, (match, prefix, name, suffix) =>
		{
			if (!name.includes('__'))
			{
				const newName = `${namespace}__${name}`;
				changes.push(`nameSegment: ${name} -> ${newName}`);
				return prefix + newName + suffix;
			}
			return match;
		});

		return newBlock;
	});

	return { content: result, changes };
}

// ============================================================================
// File Operations
// ============================================================================

/**
 * @description Reads the namespace from sfdx-project.json.
 * @param {string} projectRoot - The project root directory.
 * @returns {string} The namespace.
 */
function readNamespace(projectRoot)
{
	const sfdxProjectPath = path.join(projectRoot, CONFIG.SFDX_PROJECT_FILE);
	const content = fs.readFileSync(sfdxProjectPath, 'utf8');
	const project = JSON.parse(content);
	return project.namespace;
}

/**
 * @description Gets all files matching a pattern in a directory.
 * @param {string} dir - The directory to search.
 * @param {string} extension - The file extension to match.
 * @returns {string[]} Array of file paths.
 */
function getFiles(dir, extension)
{
	if (!fs.existsSync(dir))
	{
		return [];
	}
	return fs.readdirSync(dir)
		.filter(file => file.endsWith(extension))
		.map(file => path.join(dir, file));
}

/**
 * @description Recursively gets all files matching a pattern in a directory.
 * @param {string} dir - The directory to search.
 * @param {string} extension - The file extension to match.
 * @returns {string[]} Array of file paths.
 */
function getFilesRecursive(dir, extension)
{
	if (!fs.existsSync(dir))
	{
		return [];
	}

	let results = [];
	const items = fs.readdirSync(dir, { withFileTypes: true });

	for (const item of items)
	{
		const fullPath = path.join(dir, item.name);
		if (item.isDirectory())
		{
			results = results.concat(getFilesRecursive(fullPath, extension));
		}
		else if (item.name.endsWith(extension))
		{
			results.push(fullPath);
		}
	}

	return results;
}

/**
 * @description Normalizes whitespace in content for comparison.
 * Removes all whitespace differences to compare actual content.
 * @param {string} content - The content to normalize.
 * @returns {string} Content with normalized whitespace.
 */
function normalizeWhitespace(content)
{
	return content.replace(/\s+/g, ' ').trim();
}

/**
 * @description Gets the committed version of a file from git.
 * @param {string} filePath - The file path (absolute or relative).
 * @returns {string|null} The committed content or null if not in git.
 */
function getGitVersion(filePath)
{
	try
	{
		// Convert absolute path to relative path for git
		const relativePath = path.relative(process.cwd(), filePath);
		return execSync(`git show HEAD:"${relativePath}"`, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
	}
	catch (e)
	{
		return null;
	}
}

/**
 * @description Writes content to file, restoring git formatting if content matches.
 * If the transformed content matches the git version (ignoring whitespace),
 * uses the git version to preserve original formatting.
 * @param {string} filePath - The file path.
 * @param {string} content - The transformed content.
 */
function writeFileWithGitFormatting(filePath, content)
{
	const gitContent = getGitVersion(filePath);

	if (gitContent && normalizeWhitespace(content) === normalizeWhitespace(gitContent))
	{
		// Content matches git version, use git's formatting
		fs.writeFileSync(filePath, gitContent, 'utf8');
	}
	else
	{
		// Content differs or not in git, write as-is
		fs.writeFileSync(filePath, content, 'utf8');
	}
}

// ============================================================================
// Transformation Processors
// ============================================================================

/**
 * @description Processes custom metadata files.
 * @param {string} sourceDir - The source directory.
 * @param {string} namespace - The namespace.
 * @param {boolean} dryRun - Whether to skip actual modifications.
 * @param {boolean} verbose - Whether to show detailed output.
 * @returns {{modified: number, skipped: number}} Counts of modified and skipped files.
 */
function processCustomMetadata(sourceDir, namespace, dryRun, verbose)
{
	const customMetadataDir = path.join(sourceDir, 'customMetadata');
	const files = getFiles(customMetadataDir, '.md-meta.xml');
	let modified = 0;
	let skipped = 0;

	console.log('\nCustom Metadata:');

	for (const file of files)
	{
		const metadataType = getMetadataTypeFromFilename(file);
		const classFields = CONFIG.METADATA_CLASS_FIELDS[metadataType];
		const objectFields = CONFIG.METADATA_OBJECT_FIELDS[metadataType];

		if (!classFields && !objectFields)
		{
			continue;
		}

		let content = fs.readFileSync(file, 'utf8');
		let allChanges = [];

		// Transform class reference fields
		if (classFields)
		{
			const { content: newContent, changes } = transformCustomMetadataContent(content, namespace, classFields);
			content = newContent;
			allChanges = allChanges.concat(changes);
		}

		// Transform object reference fields
		if (objectFields)
		{
			const { content: newContent, changes } = transformCustomMetadataObjectFields(content, namespace, objectFields);
			content = newContent;
			allChanges = allChanges.concat(changes);
		}

		const basename = path.basename(file);
		if (allChanges.length > 0)
		{
			console.log(`  + ${basename}`);
			for (const change of allChanges)
			{
				console.log(`    - ${change}`);
			}
			if (!dryRun)
			{
				writeFileWithGitFormatting(file, content);
			}
			modified++;
		}
		else if (verbose)
		{
			console.log(`  o ${basename} (already prefixed)`);
			skipped++;
		}
	}

	if (modified === 0 && skipped === 0)
	{
		console.log('  (no files to process)');
	}

	return { modified, skipped };
}

/**
 * @description Processes FlexiPage files.
 * @param {string} sourceDir - The source directory.
 * @param {string} namespace - The namespace.
 * @param {boolean} dryRun - Whether to skip actual modifications.
 * @param {boolean} verbose - Whether to show detailed output.
 * @returns {{modified: number, skipped: number}} Counts of modified and skipped files.
 */
function processFlexiPages(sourceDir, namespace, dryRun, verbose)
{
	const flexipagesDir = path.join(sourceDir, 'flexipages');
	const files = getFiles(flexipagesDir, '.flexipage-meta.xml');
	let modified = 0;
	let skipped = 0;

	console.log('\nFlexiPages:');

	for (const file of files)
	{
		const content = fs.readFileSync(file, 'utf8');
		const { content: newContent, changes } = transformFlexiPageContent(
			content,
			namespace,
			CONFIG.FLEXIPAGE_OBJECT_PROPERTIES,
			CONFIG.FLEXIPAGE_EMBEDDED_OBJECT_PROPERTIES
		);

		const basename = path.basename(file);
		if (changes.length > 0)
		{
			console.log(`  + ${basename}`);
			for (const change of changes)
			{
				console.log(`    - ${change}`);
			}
			if (!dryRun)
			{
				writeFileWithGitFormatting(file, newContent);
			}
			modified++;
		}
		else if (verbose)
		{
			console.log(`  o ${basename} (no controller references or already prefixed)`);
			skipped++;
		}
	}

	if (modified === 0 && skipped === 0)
	{
		console.log('  (no files to process)');
	}

	return { modified, skipped };
}

/**
 * @description Processes LWC meta files (apex:// type references).
 * @param {string} sourceDir - The source directory.
 * @param {string} namespace - The namespace.
 * @param {boolean} dryRun - Whether to skip actual modifications.
 * @param {boolean} verbose - Whether to show detailed output.
 * @returns {{modified: number, skipped: number}} Counts of modified and skipped files.
 */
function processLwcMeta(sourceDir, namespace, dryRun, verbose)
{
	const lwcDir = path.join(sourceDir, 'lwc');
	const files = getFilesRecursive(lwcDir, '.js-meta.xml');
	let modified = 0;
	let skipped = 0;

	console.log('\nLWC Meta Files (apex:// types):');

	for (const file of files)
	{
		const content = fs.readFileSync(file, 'utf8');

		// Only process files that contain apex:// references
		if (!content.includes('apex://'))
		{
			continue;
		}

		const { content: newContent, changes } = transformLwcMetaContent(content, namespace);

		const basename = path.basename(file);
		const componentName = path.basename(path.dirname(file));
		const displayName = `${componentName}/${basename}`;

		if (changes.length > 0)
		{
			console.log(`  + ${displayName}`);
			for (const change of changes)
			{
				console.log(`    - ${change}`);
			}
			if (!dryRun)
			{
				writeFileWithGitFormatting(file, newContent);
			}
			modified++;
		}
		else if (verbose)
		{
			console.log(`  o ${displayName} (already prefixed)`);
			skipped++;
		}
	}

	if (modified === 0 && skipped === 0)
	{
		console.log('  (no files to process)');
	}

	return { modified, skipped };
}

/**
 * @description Processes LWC JS files for tab API name references.
 * @param {string} sourceDir - The source directory.
 * @param {string} namespace - The namespace.
 * @param {boolean} dryRun - Whether to skip actual modifications.
 * @param {boolean} verbose - Whether to show detailed output.
 * @returns {{modified: number, skipped: number}} Counts of modified and skipped files.
 */
function processLwcJs(sourceDir, namespace, dryRun, verbose)
{
	const lwcDir = path.join(sourceDir, 'lwc');
	const files = getFilesRecursive(lwcDir, '.js');
	let modified = 0;
	let skipped = 0;

	console.log('\nLWC JS Files (tab API names):');

	for (const file of files)
	{
		// Skip test files and meta files
		if (file.includes('__tests__') || file.endsWith('.js-meta.xml'))
		{
			continue;
		}

		const content = fs.readFileSync(file, 'utf8');

		// Only process files that contain standard__navItemPage
		if (!content.includes('standard__navItemPage'))
		{
			continue;
		}

		const { content: newContent, changes } = transformLwcJsContent(content, namespace, CONFIG.LWC_TAB_API_NAMES);

		const basename = path.basename(file);
		const componentName = path.basename(path.dirname(file));
		const displayName = `${componentName}/${basename}`;

		if (changes.length > 0)
		{
			console.log(`  + ${displayName}`);
			for (const change of changes)
			{
				console.log(`    - ${change}`);
			}
			if (!dryRun)
			{
				writeFileWithGitFormatting(file, newContent);
			}
			modified++;
		}
		else if (verbose)
		{
			console.log(`  o ${displayName} (already prefixed)`);
			skipped++;
		}
	}

	if (modified === 0 && skipped === 0)
	{
		console.log('  (no files to process)');
	}

	return { modified, skipped };
}

/**
 * @description Processes flow files that need namespace prefixes for managed package field resolution.
 * @param {string} sourceDir - The source directory.
 * @param {string} namespace - The namespace.
 * @param {boolean} dryRun - Whether to skip actual modifications.
 * @param {boolean} verbose - Whether to show detailed output.
 * @returns {{modified: number, skipped: number}} Counts of modified and skipped files.
 */
function processFlows(sourceDir, namespace, dryRun, verbose)
{
	const flowsDir = path.join(sourceDir, 'flows');
	let modified = 0;
	let skipped = 0;

	console.log('\nFlows (field namespace prefixes):');

	for (const filename of CONFIG.FLOW_FILES)
	{
		const file = path.join(flowsDir, filename);

		if (!fs.existsSync(file))
		{
			if (verbose)
			{
				console.log(`  - ${filename} (not found, skipping)`);
			}
			continue;
		}

		const content = fs.readFileSync(file, 'utf8');
		const { content: newContent, changes } = transformFlowContent(content, namespace);

		if (changes.length > 0)
		{
			console.log(`  + ${filename}`);
			for (const change of changes)
			{
				console.log(`    - ${change}`);
			}
			if (!dryRun)
			{
				writeFileWithGitFormatting(file, newContent);
			}
			modified++;
		}
		else if (verbose)
		{
			console.log(`  o ${filename} (already prefixed)`);
			skipped++;
		}
	}

	if (modified === 0 && skipped === 0)
	{
		console.log('  (no files to process)');
	}

	return { modified, skipped };
}

// ============================================================================
// Main Entry Point
// ============================================================================

/**
 * @description Main function to run the build preparation.
 * @param {Object} options - Command options.
 * @param {boolean} options.dryRun - Whether to skip actual modifications.
 * @param {boolean} options.verbose - Whether to show detailed output.
 * @param {string} options.projectRoot - The project root directory.
 */
function main(options = {})
{
	const { dryRun = false, verbose = false, projectRoot = process.cwd() } = options;

	console.log('Kern Build Preparation');
	console.log('=============================');

	if (dryRun)
	{
		console.log('(DRY RUN - no files will be modified)\n');
	}

	// Read namespace
	const namespace = readNamespace(projectRoot);
	console.log(`Namespace: ${namespace}`);

	const sourceDir = path.join(projectRoot, CONFIG.SOURCE_DIR);

	// Process all file types
	const results = {
		customMetadata: processCustomMetadata(sourceDir, namespace, dryRun, verbose),
		flexiPages: processFlexiPages(sourceDir, namespace, dryRun, verbose),
		lwcMeta: processLwcMeta(sourceDir, namespace, dryRun, verbose),
		lwcJs: processLwcJs(sourceDir, namespace, dryRun, verbose),
		flows: processFlows(sourceDir, namespace, dryRun, verbose)
	};

	// Summary
	const totalModified = results.customMetadata.modified +
		results.flexiPages.modified +
		results.lwcMeta.modified +
		results.lwcJs.modified +
		results.flows.modified;
	const totalSkipped = results.customMetadata.skipped +
		results.flexiPages.skipped +
		results.lwcMeta.skipped +
		results.lwcJs.skipped +
		results.flows.skipped;

	console.log('\n=============================');
	console.log(`Summary: ${totalModified} files modified, ${totalSkipped} files skipped (already prefixed)`);

	if (dryRun && totalModified > 0)
	{
		console.log('\nRun without --dry-run to apply changes.');
	}

	return { totalModified, totalSkipped };
}

// ============================================================================
// CLI Handling
// ============================================================================

if (require.main === module)
{
	const args = process.argv.slice(2);
	const dryRun = args.includes('--dry-run');
	const verbose = args.includes('--verbose');

	main({ dryRun, verbose });
}

// ============================================================================
// Exports for Testing
// ============================================================================

module.exports = {
	needsClassPrefix,
	needsObjectPrefix,
	needsApiNamePrefix,
	addClassNamespace,
	addObjectNamespace,
	addApiNamespace,
	getMetadataTypeFromFilename,
	transformCustomMetadataContent,
	transformCustomMetadataObjectFields,
	transformFlexiPageContent,
	transformLwcMetaContent,
	transformLwcJsContent,
	transformFlowContent,
	normalizeWhitespace,
	getGitVersion,
	writeFileWithGitFormatting,
	readNamespace,
	main,
	CONFIG
};
