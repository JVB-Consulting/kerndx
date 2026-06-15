// SPDX-License-Identifier: MIT
'use strict';

/**
 * Build regex patterns from naming config.
 * Patterns are constructed at engine init; reused across all file checks.
 *
 * @param {object} config - Naming configuration from .kerndx/config.yml
 * @param {string[]} config.domains - Allowlisted domain prefixes (e.g. ['SLS', 'ORD'])
 * @param {string[]} config.brands - Optional brand segment values (e.g. ['ACM'])
 * @param {string[]} config.flow_types - Allowlisted Flow type suffixes (e.g. ['BS', 'AS'])
 * @param {string[]} config.apex_layers - Allowlisted Apex layer prefixes (e.g. ['SEL', 'TRG'])
 * @param {object} config.length_limits - Max length by artifact type
 * @param {number} config.length_limits.apex - Max Apex class name length
 * @param {number} config.length_limits.flow - Max Flow API name length
 * @param {string} [config.field_prefix_rule] - When to require field prefix ('cross-domain-only' default)
 * @returns {object} Compiled patterns and derived config values
 */
function buildPatterns(config)
{
	const domainGroup = config.domains.join('|');
	const brandGroup = config.brands && config.brands.length > 0 ? config.brands.join('|') : null;
	const flowTypeGroup = config.flow_types.join('|');
	const apexLayerGroup = config.apex_layers.join('|');

	// Flow: Domain_[Brand_]Object_Type_Action
	const brandSegment = brandGroup ? `(?:(?:${brandGroup})_)?` : '';
	const flowPattern = new RegExp(`^(?:${domainGroup})_${brandSegment}[A-Z][a-zA-Z0-9]+_(?:${flowTypeGroup})_[A-Z][a-zA-Z0-9]+$`);

	// Object: Domain_[Brand_]Name__c
	const objectPattern = new RegExp(`^(?:${domainGroup})_${brandSegment}[A-Z][a-zA-Z0-9]+__c$`);

	// Apex: Domain_[Brand_]Layer_Name[_TEST]
	const apexPattern = apexLayerGroup ? new RegExp(`^(?:${domainGroup})_${brandSegment}(?:${apexLayerGroup})_[A-Z][a-zA-Z0-9]+(?:_TEST)?$`)
			: new RegExp(`^(?:${domainGroup})_${brandSegment}[A-Z][a-zA-Z0-9]+(?:_TEST)?$`);

	return {
		flow: flowPattern,
		object: objectPattern,
		apex: apexPattern,
		domains: new Set(config.domains),
		brands: new Set(config.brands || []),
		lengthLimits: config.length_limits,
		fieldPrefixRule: config.field_prefix_rule || 'cross-domain-only'
	};
}

module.exports = {buildPatterns};
