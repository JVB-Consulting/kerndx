// SPDX-License-Identifier: BUSL-1.1
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const scanner = require('../scan-hardcoded-user-text');

const LWC_DIR = path.resolve(__dirname, '..', '..', 'force-app', 'main', 'default', 'lwc');
const fileIn = (bundle) => path.join(LWC_DIR, bundle, `${bundle}.html`);

test('isBinding recognises a whole-value binding only', () =>
{
	assert.equal(scanner.isBinding('{count}'), true);
	assert.equal(scanner.isBinding('  {label.title}  '), true);
	assert.equal(scanner.isBinding('Showing {count}'), false);
	assert.equal(scanner.isBinding('{a} {b}'), false);
});

test('isTokenShaped skips icon / css / url / format tokens', () =>
{
	assert.equal(scanner.isTokenShaped('utility:refresh'), true);
	assert.equal(scanner.isTokenShaped('slds-var-p-around_small'), true);
	assert.equal(scanner.isTokenShaped('https://example.com'), true);
	assert.equal(scanner.isTokenShaped('M/d/yyyy'), true, 'a real date format is a token');
	assert.equal(scanner.isTokenShaped('Local Time'), false);
	// A word made only of date-format letters must NOT be mistaken for a format token.
	assert.equal(scanner.isTokenShaped('Days'), false);
	assert.equal(scanner.isTokenShaped('Add'), false);
});

test('hasDisplayText ignores bindings, entities and glyphs', () =>
{
	assert.equal(scanner.hasDisplayText('Local Time'), true);
	assert.equal(scanner.hasDisplayText('Showing {count} events'), true);
	assert.equal(scanner.hasDisplayText('{label.title}'), false);
	assert.equal(scanner.hasDisplayText('&middot;'), false);
	assert.equal(scanner.hasDisplayText('—'), false);
});

test('isUserFacingValue', () =>
{
	assert.equal(scanner.isUserFacingValue('Channel'), true);
	assert.equal(scanner.isUserFacingValue('PushTopic event'), true);
	assert.equal(scanner.isUserFacingValue(''), false);
	assert.equal(scanner.isUserFacingValue('{recordId}'), false);
	assert.equal(scanner.isUserFacingValue('utility:refresh'), false);
});

test('scanHtml flags attributes and text nodes, not bindings or empty alt', () =>
{
	const html = [
		'<template>',
		'  <lightning-card title="Streaming Monitor">',
		'    <h2>Subscriptions</h2>',
		'    <span>{count} events</span>',
		'    <lightning-input label="Channel"></lightning-input>',
		'    <lightning-input label={dynamicLabel}></lightning-input>',
		'    <img alt="" />',
		'    <lightning-button-icon alternative-text="Unsubscribe"></lightning-button-icon>',
		'  </lightning-card>',
		'</template>'
	].join('\n');

	const found = scanner.scanHtml(html, fileIn('streamingMonitor'));
	const texts = found.map((violation) => violation.text).sort();

	assert.ok(texts.includes('Streaming Monitor'), 'flags the card title attribute');
	assert.ok(texts.includes('Subscriptions'), 'flags a single-word heading text node');
	assert.ok(texts.includes('Channel'), 'flags a static label attribute');
	assert.ok(texts.includes('Unsubscribe'), 'flags alternative-text');
	assert.ok(found.some((violation) => /events/.test(violation.text)), 'flags the text after a binding');

	assert.ok(!found.some((violation) => violation.text === ''), 'does not flag empty decorative alt');
	assert.ok(!found.some((violation) => /dynamicLabel/.test(violation.text)), 'does not flag a bound label');

	const altViolation = found.find((violation) => violation.text === 'Unsubscribe');
	assert.equal(altViolation.kind, 'html-attr-alternative-text');
});

test('scanHtml flags lightning message-toggle / message-when attributes', () =>
{
	const html = [
		'<template>',
		'  <lightning-input message-toggle-active="Active" message-toggle-inactive="Inactive" message-when-value-missing="Enter a value"></lightning-input>',
		'</template>'
	].join('\n');
	const texts = scanner.scanHtml(html, fileIn('scheduledJobEditor')).map((violation) => violation.text).sort();

	assert.deepEqual(texts, [
		'Active',
		'Enter a value',
		'Inactive'
	]);
});

test('scanHtml flags words that are only date-format letters (not format tokens)', () =>
{
	const html = [
		'<template>',
		'  <lightning-input label="Days"></lightning-input>',
		'  <lightning-button label="Add"></lightning-button>',
		'</template>'
	].join('\n');
	const texts = scanner.scanHtml(html, fileIn('cronExpressionEditor')).map((violation) => violation.text);

	assert.ok(texts.includes('Days'), 'flags Days');
	assert.ok(texts.includes('Add'), 'flags Add');
});

test('scanHtml <!-- i18n-allow --> is line-precise', () =>
{
	// Marker alone on its line suppresses the NEXT line only.
	const aboveMarker = [
		'<template>',
		'  <!-- i18n-allow -->',
		'  <pre>PushTopic pushTopic = new PushTopic();</pre>',
		'  <h2>Real Heading Here</h2>',
		'</template>'
	].join('\n');
	const above = scanner.scanHtml(aboveMarker, fileIn('streamingActions'));

	assert.ok(!above.some((violation) => /PushTopic/.test(violation.text)), 'the line after a lone marker is suppressed');
	assert.ok(above.some((violation) => violation.text === 'Real Heading Here'), 'a violation two lines below the marker is NOT suppressed');

	// An inline marker suppresses only its own line, never the following line.
	const inlineMarker = [
		'<template>',
		'  <pre>SELECT sample here</pre> <!-- i18n-allow -->',
		'  <h2>Next Line Heading</h2>',
		'</template>'
	].join('\n');
	const inline = scanner.scanHtml(inlineMarker, fileIn('streamingActions'));

	assert.ok(!inline.some((violation) => /SELECT/.test(violation.text)), 'the inline-marked line itself is suppressed');
	assert.ok(inline.some((violation) => violation.text === 'Next Line Heading'), 'the line after an inline marker is NOT suppressed');
});

test('scanMeta flags only targetConfig property defaults', () =>
{
	const meta = [
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">',
		'  <masterLabel>Validation Errors</masterLabel>',
		'  <targetConfigs>',
		'    <targetConfig targets="lightning__FlowScreen">',
		'      <property name="title" type="String" default="Validation Errors" />',
		'      <property name="collapsed" type="Boolean" default="false" />',
		'    </targetConfig>',
		'  </targetConfigs>',
		'</LightningComponentBundle>'
	].join('\n');

	const found = scanner.scanMeta(meta, path.join(LWC_DIR, 'validationErrors', 'validationErrors.js-meta.xml'));
	const texts = found.map((violation) => violation.text);

	assert.deepEqual(texts, ['Validation Errors'], 'flags the String default, not masterLabel or the boolean default');
	assert.equal(found[0].kind, 'meta-targetconfig-default');
});

test('severityOf stages by swept area, holding alternative-text at warn', () =>
{
	const swept = new Set(['scheduledJobEditor']);
	const sweptText = {filePath: path.join(LWC_DIR, 'scheduledJobEditor', 'x.html'), kind: 'html-text'};
	const unsweptText = {filePath: path.join(LWC_DIR, 'streamingMonitor', 'x.html'), kind: 'html-text'};
	const sweptAlt = {filePath: path.join(LWC_DIR, 'scheduledJobEditor', 'x.html'), kind: 'html-attr-alternative-text'};

	assert.equal(scanner.severityOf(sweptText, swept), 'error');
	assert.equal(scanner.severityOf(unsweptText, swept), 'warn');
	assert.equal(scanner.severityOf(sweptAlt, swept), 'warn');
});
