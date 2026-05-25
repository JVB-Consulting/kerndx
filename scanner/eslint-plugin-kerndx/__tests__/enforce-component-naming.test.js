// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const {RuleTester} = require('eslint');
const rule = require('../rules/enforce-component-naming');

const ruleTester = new RuleTester({parserOptions: {ecmaVersion: 2022, sourceType: 'module'}});

const BRAND_OPTIONS = [{ domains: ['sls', 'ord', 'prd', 'svc', 'sub', 'mkt', 'cmn'], brands: ['Acme', 'Beta'] }];

test('enforce-component-naming with domains+brands options', () => {
	ruleTester.run('enforce-component-naming', rule, {
		valid: [
			{
				code: 'export default class OrdReturnWizard {}',
				filename: '/project/force-app/main/default/lwc/ordReturnWizard/ordReturnWizard.js',
				options: BRAND_OPTIONS,
				name: 'valid domain + feature name'
			},
			{
				code: 'export default class SvcWarrantyTimeline {}',
				filename: '/project/force-app/main/default/lwc/svcWarrantyTimeline/svcWarrantyTimeline.js',
				options: BRAND_OPTIONS,
				name: 'valid svc domain'
			},
			{
				code: 'export default class OrdAcmeCheckoutForm {}',
				filename: '/project/force-app/main/default/lwc/ordAcmeCheckoutForm/ordAcmeCheckoutForm.js',
				options: BRAND_OPTIONS,
				name: 'valid domain + Acme brand'
			},
			{
				code: 'export default class SvcBetaWarrantyPanel {}',
				filename: '/project/force-app/main/default/lwc/svcBetaWarrantyPanel/svcBetaWarrantyPanel.js',
				options: BRAND_OPTIONS,
				name: 'valid domain + Beta brand'
			},
			{
				code: 'export default class CmnHealthCheck {}',
				filename: '/project/force-app/main/default/lwc/cmnHealthCheck/cmnHealthCheck.js',
				options: BRAND_OPTIONS,
				name: 'valid cmn domain'
			},
			{
				code: 'export default class SlsQuotingTool {}',
				filename: '/project/force-app/main/default/lwc/slsQuotingTool/slsQuotingTool.js',
				options: BRAND_OPTIONS,
				name: 'valid sls domain'
			},
			{
				code: 'export default class MktCampaignDashboard {}',
				filename: '/project/force-app/main/default/lwc/mktCampaignDashboard/mktCampaignDashboard.js',
				options: BRAND_OPTIONS,
				name: 'valid mkt domain'
			},
			{
				code: 'export default class PrdCatalogBrowser {}',
				filename: '/project/force-app/main/default/lwc/prdCatalogBrowser/prdCatalogBrowser.js',
				options: BRAND_OPTIONS,
				name: 'valid prd domain'
			},
			{
				code: 'export default class SubRenewalWizard {}',
				filename: '/project/force-app/main/default/lwc/subRenewalWizard/subRenewalWizard.js',
				options: BRAND_OPTIONS,
				name: 'valid sub domain'
			},
			{
				code: 'export default class Tests {}',
				filename: '/project/force-app/main/default/lwc/__tests__/helpers.js',
				options: BRAND_OPTIONS,
				name: '__tests__ directories are skipped'
			},
			{
				code: 'const x = 1;',
				filename: '/project/scripts/util.js',
				options: BRAND_OPTIONS,
				name: 'non-LWC files are skipped'
			},
			{
				code: 'export default class MyComponent {}',
				filename: '/project/force-app/main/default/lwc/myComponent/myComponent.js',
				name: 'no options → rule is no-op (zero options = zero enforcement)'
			},
			{
				code: 'export default class DemoCustomerPortal {}',
				filename: '/project/force-app/main/default/lwc/demoCustomerPortal/demoCustomerPortal.js',
				options: [{ domains: ['demo', 'cli'] }],
				name: 'different subscriber: domains only, no brands'
			}
		],

		invalid: [
			{
				code: 'export default class ReturnWizard {}',
				filename: '/project/force-app/main/default/lwc/returnWizard/returnWizard.js',
				options: BRAND_OPTIONS,
				name: 'missing domain prefix',
				errors: [{messageId: 'badName'}]
			},
			{
				code: 'export default class OrderReturnWizard {}',
				filename: '/project/force-app/main/default/lwc/orderReturnWizard/orderReturnWizard.js',
				options: BRAND_OPTIONS,
				name: 'full domain name instead of code',
				errors: [{messageId: 'badName'}]
			},
			{
				code: 'export default class ORDReturnWizard {}',
				filename: '/project/force-app/main/default/lwc/ORDReturnWizard/ORDReturnWizard.js',
				options: BRAND_OPTIONS,
				name: 'uppercase domain prefix',
				errors: [{messageId: 'badName'}]
			},
			{
				code: 'export default class Ordacmecheckout {}',
				filename: '/project/force-app/main/default/lwc/ordacmecheckout/ordacmecheckout.js',
				options: BRAND_OPTIONS,
				name: 'all-lowercase feature name after domain',
				errors: [{messageId: 'badName'}]
			},
			{
				code: 'export default class MyComponent {}',
				filename: '/project/force-app/main/default/lwc/myComponent/myComponent.js',
				options: BRAND_OPTIONS,
				name: 'non-domain prefix',
				errors: [{messageId: 'badName'}]
			},
			{
				code: 'export default class Ord {}',
				filename: '/project/force-app/main/default/lwc/ord/ord.js',
				options: BRAND_OPTIONS,
				name: 'domain prefix only, no feature name',
				errors: [{messageId: 'badName'}]
			},
			{
				code: 'export default class OrdVeryLongComponentNameThatExceedsFortyChars {}',
				filename: '/project/force-app/main/default/lwc/ordVeryLongComponentNameThatExceedsFortyChars/ordVeryLongComponentNameThatExceedsFortyChars.js',
				options: BRAND_OPTIONS,
				name: 'component name exceeds 40-character limit',
				errors: [{messageId: 'tooLong'}]
			},
			{
				code: 'export default class DemoBadName {}',
				filename: '/project/force-app/main/default/lwc/badName/badName.js',
				options: [{ domains: ['demo', 'cli'], maxLength: 30 }],
				name: 'different subscriber: violates configured pattern',
				errors: [{messageId: 'badName'}]
			}
		]
	});
});
