// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for CTRL_MaskingAdvisor — the dead-configuration check, the object and field
 * coverage analysis (native classification with heuristic fallback), the typed and real-record masking
 * previews, the rule blast radius, and the deployment-neutral configuration generation. Pure logic is
 * exercised with in-memory CMDT records and describe data; the @AuraEnabled org-wide entry points are
 * exercised through the SEL_MaskingTarget *OverrideForTest seams and TST_Mock so no shipped configuration
 * is required.
 *
 * @see CTRL_MaskingAdvisor
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date May 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ExcessiveParameterList,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.CognitiveComplexity')
@IsTest(SeeAllData=false IsParallel=true)
private class CTRL_MaskingAdvisor_TEST
{
	/**
	 * @description The standard SecurityClassification picklist value the classification-overlay fixtures apply.
	 */
	private static final String SECURITY_CLASSIFICATION_CONFIDENTIAL = 'Confidential';

	/**
	 * @description Verifies that an active target bound to an inactive rule is flagged as an inactive-rule issue.
	 */
	@IsTest
	private static void analyzeFlagsActiveTargetWithInactiveRule()
	{
		MaskingRule__mdt inactiveRule = rule(false);
		Map<Id, MaskingRule__mdt> rulesById = new Map<Id, MaskingRule__mdt> {inactiveRule.Id => inactiveRule};
		List<MaskingTarget__mdt> targets = new List<MaskingTarget__mdt> {target('MaskAccountDescription', true, inactiveRule.Id)};

		List<CTRL_MaskingAdvisor.DTO_DeadConfiguration> findings = CTRL_MaskingAdvisor.analyzeDeadConfiguration(targets, rulesById);

		Assert.areEqual(1, findings.size(), 'an active target bound to an inactive rule masks nothing and must be flagged');
		Assert.areEqual(CTRL_MaskingAdvisor.ConfigurationIssue.INACTIVE_RULE.name(), findings[0].issueCode, 'the finding is classified as an inactive-rule issue');
		Assert.areEqual('MaskAccountDescription', findings[0].targetDeveloperName, 'the finding names the offending target');
	}

	/**
	 * @description Verifies that an active target bound to a non-existent rule is flagged as a missing-rule issue.
	 */
	@IsTest
	private static void analyzeFlagsActiveTargetWithMissingRule()
	{
		Id missingRuleId = UTIL_Random.randomId(MaskingRule__mdt.SObjectType);
		List<MaskingTarget__mdt> targets = new List<MaskingTarget__mdt> {target('MaskAccountDescription', true, missingRuleId)};

		List<CTRL_MaskingAdvisor.DTO_DeadConfiguration> findings = CTRL_MaskingAdvisor.analyzeDeadConfiguration(targets, new Map<Id, MaskingRule__mdt>());

		Assert.areEqual(1, findings.size(), 'an active target bound to a non-existent rule masks nothing and must be flagged');
		Assert.areEqual(CTRL_MaskingAdvisor.ConfigurationIssue.MISSING_RULE.name(), findings[0].issueCode, 'the finding is classified as a missing-rule issue');
	}

	/**
	 * @description Verifies that an active target with a null rule reference is flagged as a missing-rule issue.
	 */
	@IsTest
	private static void analyzeFlagsNullRuleReferenceAsMissing()
	{
		List<MaskingTarget__mdt> targets = new List<MaskingTarget__mdt> {target('MaskAccountDescription', true, null)};

		List<CTRL_MaskingAdvisor.DTO_DeadConfiguration> findings = CTRL_MaskingAdvisor.analyzeDeadConfiguration(targets, new Map<Id, MaskingRule__mdt>());

		Assert.areEqual(1, findings.size(), 'a null rule reference is treated as a missing rule');
		Assert.areEqual(CTRL_MaskingAdvisor.ConfigurationIssue.MISSING_RULE.name(), findings[0].issueCode, 'a null rule reference is reported as a missing-rule issue');
	}

	/**
	 * @description Verifies that a healthy active target and an inactive target produce no findings.
	 */
	@IsTest
	private static void analyzeIgnoresHealthyAndInactiveTargets()
	{
		MaskingRule__mdt activeRule = rule(true);
		Map<Id, MaskingRule__mdt> rulesById = new Map<Id, MaskingRule__mdt> {activeRule.Id => activeRule};
		List<MaskingTarget__mdt> targets = new List<MaskingTarget__mdt>
		{
				target('HealthyTarget', true, activeRule.Id),
				target('InactiveTarget', false, null)
		};

		List<CTRL_MaskingAdvisor.DTO_DeadConfiguration> findings = CTRL_MaskingAdvisor.analyzeDeadConfiguration(targets, rulesById);

		Assert.areEqual(0, findings.size(), 'an active target with an active rule, and an inactive target, are both healthy');
	}

	/**
	 * @description Verifies that every finding carries a resolved admin message naming the offending target.
	 */
	@IsTest
	private static void analyzeResolvesAdminMessageNamingTheTarget()
	{
		MaskingRule__mdt inactiveRule = rule(false);
		Id missingRuleId = UTIL_Random.randomId(MaskingRule__mdt.SObjectType);
		Map<Id, MaskingRule__mdt> rulesById = new Map<Id, MaskingRule__mdt> {inactiveRule.Id => inactiveRule};
		List<MaskingTarget__mdt> targets = new List<MaskingTarget__mdt>
		{
				target('InactiveRuleTarget', true, inactiveRule.Id),
				target('MissingRuleTarget', true, missingRuleId)
		};

		List<CTRL_MaskingAdvisor.DTO_DeadConfiguration> findings = CTRL_MaskingAdvisor.analyzeDeadConfiguration(targets, rulesById);

		Assert.areEqual(2, findings.size(), 'both dead targets are flagged');
		for(CTRL_MaskingAdvisor.DTO_DeadConfiguration finding : findings)
		{
			Assert.isTrue(String.isNotBlank(finding.message), 'each finding carries a resolved admin message');
			Assert.isTrue(finding.message.contains(finding.targetDeveloperName), 'the admin message names the offending target');
		}
	}

	/**
	 * @description Verifies that the org-wide entry point surfaces dead configuration seeded through the selector override seams.
	 */
	@IsTest
	private static void getDeadConfigurationsReadsOrgConfigurationViaSelectorSeams()
	{
		MaskingRule__mdt inactiveRule = rule(false);
		MaskingTarget__mdt orphanTarget = target('OrphanTarget', true, inactiveRule.Id);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'InactiveRule' => inactiveRule};
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {'OrphanTarget' => orphanTarget};

		List<CTRL_MaskingAdvisor.DTO_DeadConfiguration> findings = CTRL_MaskingAdvisor.getDeadConfigurations();

		Assert.areEqual(1, findings.size(), 'the org-wide entry point surfaces the seeded dead configuration');
		Assert.areEqual('OrphanTarget', findings[0].targetDeveloperName, 'the seeded dead target is the one surfaced');
		Assert.areEqual(CTRL_MaskingAdvisor.ConfigurationIssue.INACTIVE_RULE.name(), findings[0].issueCode, 'the surfaced finding is classified as an inactive-rule issue');
	}

	/**
	 * @description Verifies that the org-wide entry point reads shipped configuration and returns a non-null list without throwing.
	 */
	@IsTest
	private static void getDeadConfigurationsReadsShippedConfigurationAndNeverThrows()
	{
		Test.startTest();
		List<CTRL_MaskingAdvisor.DTO_DeadConfiguration> findings = CTRL_MaskingAdvisor.getDeadConfigurations();
		Test.stopTest();

		Assert.isNotNull(findings, 'the org-wide entry point returns a (possibly empty) list, never null');
	}

	/**
	 * @description Verifies the org-wide posture summary counts distinct objects with active targets, splits
	 * active targets into field-level versus object-wide, counts dead configurations, and ignores inactive targets.
	 */
	@IsTest
	private static void summarizePostureCountsObjectsFieldAndObjectWideTargetsAndDeadConfigs()
	{
		MaskingRule__mdt activeRule = rule(true);
		MaskingRule__mdt inactiveRule = rule(false);
		Map<Id, MaskingRule__mdt> rulesById = new Map<Id, MaskingRule__mdt>
		{
				activeRule.Id => activeRule,
				inactiveRule.Id => inactiveRule
		};
		List<MaskingTarget__mdt> targets = new List<MaskingTarget__mdt>
		{
				postureTarget('MaskObjectAFieldOne', 'ObjectADurable', 'ObjectADurable.FieldOne', true, activeRule.Id),
				postureTarget('MaskObjectAFieldTwo', 'ObjectADurable', 'ObjectADurable.FieldTwo', true, activeRule.Id),
				postureTarget('MaskObjectBWide', 'ObjectBDurable', null, true, activeRule.Id),
				postureTarget('MaskObjectBDead', 'ObjectBDurable', 'ObjectBDurable.FieldThree', true, inactiveRule.Id),
				postureTarget('MaskObjectCInactive', 'ObjectCDurable', 'ObjectCDurable.FieldFour', false, activeRule.Id)
		};

		CTRL_MaskingAdvisor.DTO_OrgPostureSummary summary = CTRL_MaskingAdvisor.summarizePosture(targets, rulesById);

		Assert.areEqual(2, summary.objectsWithActiveTargets, 'two distinct objects carry active targets; the inactive-target object is not counted');
		Assert.areEqual(3, summary.activeFieldTargetCount, 'three active targets bind a field (the object-wide target is excluded)');
		Assert.areEqual(1, summary.sObjectWideTargetCount, 'one active target is object-wide (no field)');
		Assert.areEqual(1, summary.deadConfigCount, 'one active target binds an inactive rule and is a dead configuration');
	}

	/**
	 * @description Verifies the posture summary reports all-zero counts for an org with no masking targets.
	 */
	@IsTest
	private static void summarizePostureReportsZeroForAnEmptyConfiguration()
	{
		CTRL_MaskingAdvisor.DTO_OrgPostureSummary summary = CTRL_MaskingAdvisor.summarizePosture(new List<MaskingTarget__mdt>(), new Map<Id, MaskingRule__mdt>());

		Assert.areEqual(0, summary.objectsWithActiveTargets, 'no targets means no objects with masking configured');
		Assert.areEqual(0, summary.activeFieldTargetCount, 'no field-level targets');
		Assert.areEqual(0, summary.sObjectWideTargetCount, 'no object-wide targets');
		Assert.areEqual(0, summary.deadConfigCount, 'no dead configurations');
	}

	/**
	 * @description Verifies the org-wide posture entry point reads configuration through the selector override seams.
	 */
	@IsTest
	private static void getOrgPostureSummaryReadsOrgConfigurationViaSelectorSeams()
	{
		MaskingRule__mdt activeRule = rule(true);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'ActiveRule' => activeRule};
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt>
		{
				'FieldTarget' => postureTarget('FieldTarget', 'ObjectADurable', 'ObjectADurable.FieldOne', true, activeRule.Id),
				'WideTarget' => postureTarget('WideTarget', 'ObjectADurable', null, true, activeRule.Id)
		};

		CTRL_MaskingAdvisor.DTO_OrgPostureSummary summary = CTRL_MaskingAdvisor.getOrgPostureSummary();

		Assert.areEqual(1, summary.objectsWithActiveTargets, 'both seeded targets are on one object');
		Assert.areEqual(1, summary.activeFieldTargetCount, 'one seeded target binds a field');
		Assert.areEqual(1, summary.sObjectWideTargetCount, 'one seeded target is object-wide');
		Assert.areEqual(0, summary.deadConfigCount, 'both seeded targets bind the active rule, so neither is dead');
	}

	/**
	 * @description Verifies the org-wide posture entry point reads shipped configuration and returns a non-null summary without throwing.
	 */
	@IsTest
	private static void getOrgPostureSummaryReadsShippedConfigurationAndNeverThrows()
	{
		Test.startTest();
		CTRL_MaskingAdvisor.DTO_OrgPostureSummary summary = CTRL_MaskingAdvisor.getOrgPostureSummary();
		Test.stopTest();

		Assert.isNotNull(summary, 'the org-wide entry point returns a summary, never null');
	}

	/**
	 * @description Verifies the org-wide inventory reducer groups active targets by object, splits active
	 * object-wide versus field targets, collects the distinct active rule labels, counts dead configurations
	 * per object, drops objects whose durable Id does not resolve, excludes objects with only inactive
	 * targets, and orders the rows by object label.
	 */
	@IsTest
	private static void getOrgPostureInventoryGroupsTargetsByObjectWithCountsAndDead()
	{
		MaskingRule__mdt activeEmail = labeledRule('MaskEmail', 'Mask Email', true);
		MaskingRule__mdt activeCard = labeledRule('MaskCreditCard', 'Mask Credit Card', true);
		MaskingRule__mdt inactiveRule = labeledRule('MaskRetired', 'Mask Retired', false);
		Map<Id, MaskingRule__mdt> rulesById = new Map<Id, MaskingRule__mdt>
		{
				activeEmail.Id => activeEmail,
				activeCard.Id => activeCard,
				inactiveRule.Id => inactiveRule
		};
		List<MaskingTarget__mdt> targets = new List<MaskingTarget__mdt>
		{
				postureTarget('AccountWideEmail', 'AccountDurable', null, true, activeEmail.Id),
				postureTarget('AccountWideCard', 'AccountDurable', null, true, activeCard.Id),
				postureTarget('AccountFieldEmail', 'AccountDurable', 'AccountDurable.FieldOne', true, activeEmail.Id),
				postureTarget('AccountFieldDead', 'AccountDurable', 'AccountDurable.FieldTwo', true, inactiveRule.Id),
				postureTarget('ContactFieldCard', 'ContactDurable', 'ContactDurable.FieldThree', true, activeCard.Id),
				postureTarget('LeadInactive', 'LeadDurable', 'LeadDurable.FieldFour', false, activeEmail.Id),
				postureTarget('CaseWideUnresolved', 'CaseDurable', null, true, activeCard.Id),
				postureTarget('OpportunityFieldMissing', 'OpportunityDurable', 'OpportunityDurable.FieldFive', true, null)
		};
		Map<String, String> apiNameByDurableId = new Map<String, String> {'AccountDurable' => 'Account', 'ContactDurable' => 'Contact', 'OpportunityDurable' => 'Opportunity'};
		Map<String, String> labelByDurableId = new Map<String, String> {'AccountDurable' => 'Account', 'ContactDurable' => 'Contact', 'OpportunityDurable' => 'Opportunity'};

		List<CTRL_MaskingAdvisor.DTO_ObjectMaskingInventory> inventory = CTRL_MaskingAdvisor.summarizeInventory(targets, rulesById, apiNameByDurableId, labelByDurableId);

		Assert.areEqual(3, inventory.size(), 'three objects carry active resolvable targets; the inactive-only object and the unresolved-durable-Id object are excluded');

		CTRL_MaskingAdvisor.DTO_ObjectMaskingInventory account = inventory[0];
		Assert.areEqual('Account', account.objectApiName, 'rows are ordered by label, so Account sorts before Contact');
		Assert.areEqual('Account', account.objectLabel, 'the row carries the resolved object label');
		Assert.areEqual(2, account.objectWideTargetCount, 'Account has two active object-wide targets');
		Assert.areEqual(2, account.fieldTargetCount, 'Account has two active field targets (the dead one still counts as an active field target)');
		Assert.areEqual(1, account.deadCount, 'Account has one dead configuration (active target bound to an inactive rule)');
		Assert.areEqual(
				new List<String> {'Mask Credit Card', 'Mask Email'},
				account.ruleLabels,
				'distinct active rule labels are listed alphabetically; the inactive rule label is excluded'
		);

		CTRL_MaskingAdvisor.DTO_ObjectMaskingInventory contact = inventory[1];
		Assert.areEqual('Contact', contact.objectApiName, 'Contact sorts after Account');
		Assert.areEqual(0, contact.objectWideTargetCount, 'Contact has no object-wide targets');
		Assert.areEqual(1, contact.fieldTargetCount, 'Contact has one active field target');
		Assert.areEqual(0, contact.deadCount, 'Contact has no dead configurations');
		Assert.areEqual(new List<String> {'Mask Credit Card'}, contact.ruleLabels, 'Contact lists its single active rule label');

		CTRL_MaskingAdvisor.DTO_ObjectMaskingInventory opportunity = inventory[2];
		Assert.areEqual('Opportunity', opportunity.objectApiName, 'Opportunity sorts after Contact');
		Assert.areEqual(0, opportunity.objectWideTargetCount, 'Opportunity has no object-wide targets');
		Assert.areEqual(1, opportunity.fieldTargetCount, 'the missing-rule target still counts as an active field target');
		Assert.areEqual(1, opportunity.deadCount, 'an active target with no rule is a dead configuration');
		Assert.areEqual(new List<String>(), opportunity.ruleLabels, 'a missing-rule target contributes no rule label');
	}

	/**
	 * @description Verifies the org-wide inventory entry point reads targets through the selector override
	 * seams and resolves an object durable Id to its API name and label via the EntityDefinition selector.
	 */
	@IsTest
	private static void getOrgPostureInventoryResolvesObjectIdentityViaSelectorSeams()
	{
		// A standard object's EntityDefinition DurableId is its API name (only custom objects carry a
		// 01I-style durable Id), so seeding the target with 'Account' resolves through the real
		// findByDurableIds selector path — exercising durable-Id-to-identity resolution without an inline
		// EntityDefinition query.
		final String accountDurableId = 'Account';
		MaskingRule__mdt activeRule = labeledRule('MaskEmail', 'Mask Email', true);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'MaskEmail' => activeRule};
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt>
		{
				'AccountWide' => postureTarget('AccountWide', accountDurableId, null, true, activeRule.Id),
				'BlankObjectType' => postureTarget('BlankObjectType', null, null, true, activeRule.Id)
		};

		Test.startTest();
		List<CTRL_MaskingAdvisor.DTO_ObjectMaskingInventory> inventory = CTRL_MaskingAdvisor.getOrgPostureInventory();
		Test.stopTest();

		Assert.areEqual(1, inventory.size(), 'the resolvable active target yields one row; the blank-SObjectType target is excluded');
		Assert.areEqual('Account', inventory[0].objectApiName, 'the durable Id resolves to the Account API name');
		Assert.isTrue(String.isNotBlank(inventory[0].objectLabel), 'the row carries the resolved Account label');
		Assert.areEqual(1, inventory[0].objectWideTargetCount, 'the seeded target is object-wide');
		Assert.areEqual(0, inventory[0].fieldTargetCount, 'no field-level targets were seeded');
		Assert.areEqual(0, inventory[0].deadCount, 'the seeded target binds an active rule, so it is not dead');
		Assert.areEqual(new List<String> {'Mask Email'}, inventory[0].ruleLabels, 'the active rule label is listed');
	}

	/**
	 * @description Verifies the org-wide inventory entry point reads shipped configuration and returns a non-null list without throwing.
	 */
	@IsTest
	private static void getOrgPostureInventoryReadsShippedConfigurationAndNeverThrows()
	{
		Test.startTest();
		List<CTRL_MaskingAdvisor.DTO_ObjectMaskingInventory> inventory = CTRL_MaskingAdvisor.getOrgPostureInventory();
		Test.stopTest();

		Assert.isNotNull(inventory, 'the org-wide inventory entry point returns a (possibly empty) list, never null');
	}

	/**
	 * @description Verifies that the object picker returns selectable objects, each carrying an API name and label.
	 */
	@IsTest
	private static void listObjectsReturnsSelectableObjectOptions()
	{
		List<CTRL_MaskingAdvisor.DTO_ObjectOption> options = CTRL_MaskingAdvisor.listObjects();

		Assert.isFalse(options.isEmpty(), 'an org exposes customizable objects to choose from');
		for(CTRL_MaskingAdvisor.DTO_ObjectOption option : options)
		{
			Assert.isTrue(String.isNotBlank(option.apiName), 'each option carries an API name');
			Assert.isTrue(String.isNotBlank(option.label), 'each option carries a label');
		}
	}

	/**
	 * @description Verifies that the object picker marks custom objects so the console can scope the
	 * custom-object coverage scan to them, leaving standard objects unmarked.
	 */
	@IsTest
	private static void listObjectsMarksCustomObjectsAsCustom()
	{
		List<EntityDefinition> entities = new List<EntityDefinition>
		{
				(EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
						.withOverride(EntityDefinition.QualifiedApiName, 'Account')
						.withOverride(EntityDefinition.Label, 'Account')
						.withoutInsertion()
						.build(),
				(EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
						.withOverride(EntityDefinition.QualifiedApiName, 'CustomerFeedback__c')
						.withOverride(EntityDefinition.Label, 'Customer Feedback')
						.withoutInsertion()
						.build()
		};
		TST_Mock.register(EntityDefinition.SObjectType, entities);

		List<CTRL_MaskingAdvisor.DTO_ObjectOption> options = CTRL_MaskingAdvisor.listObjects();

		Assert.areEqual(2, options.size(), 'both mocked entities surface as options');
		Assert.areEqual(false, optionFor(options, 'Account').isCustom, 'a standard object is not marked custom');
		Assert.areEqual(true, optionFor(options, 'CustomerFeedback__c').isCustom, 'a __c object is marked custom');
	}

	/**
	 * @description Verifies that the object picker carries each object's namespace prefix, so the coverage
	 * scan can default to the subscriber's own (un-namespaced) custom objects and treat managed-package
	 * objects — which can number in the hundreds in orgs with large AppExchange footprints — as an
	 * explicit opt-in.
	 */
	@IsTest
	private static void listObjectsCarriesNamespacePrefixForManagedPackageObjects()
	{
		List<EntityDefinition> entities = new List<EntityDefinition>
		{
				(EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
						.withOverride(EntityDefinition.QualifiedApiName, 'CustomerFeedback__c')
						.withOverride(EntityDefinition.Label, 'Customer Feedback')
						.withoutInsertion()
						.build(),
				(EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
						.withOverride(EntityDefinition.QualifiedApiName, 'FSL__WorkOrderExtension__c')
						.withOverride(EntityDefinition.Label, 'Work Order Extension')
						.withOverride(EntityDefinition.NamespacePrefix, 'FSL')
						.withoutInsertion()
						.build()
		};
		TST_Mock.register(EntityDefinition.SObjectType, entities);

		List<CTRL_MaskingAdvisor.DTO_ObjectOption> options = CTRL_MaskingAdvisor.listObjects();

		Assert.isNull(optionFor(options, 'CustomerFeedback__c').namespacePrefix, 'a subscriber-owned object carries no namespace prefix');
		Assert.areEqual('FSL', optionFor(options, 'FSL__WorkOrderExtension__c').namespacePrefix, 'a managed-package object carries its namespace prefix');
		Assert.areEqual(true, optionFor(options, 'FSL__WorkOrderExtension__c').isCustom, 'a managed-package custom object is still marked custom');
	}

	/**
	 * @description Verifies that strong sensitive-identifier names and matching contact types are rated high confidence.
	 * Covers each new domain added to HIGH_CONFIDENCE_NAME_PATTERNS — locale (BSN/Aadhaar), healthcare
	 * (MRN/NPI), PCI sensitive authentication data (CVV), banking ISO (SWIFT), telecom (IMEI) — to
	 * regression-guard the expanded baseline.
	 */
	@IsTest
	private static void heuristicFlagsStrongIdentifierNamesAsHigh()
	{
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('Customer_SSN__c', DisplayType.STRING), 'SSN name is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('PassportNumber__c', DisplayType.STRING), 'passport name is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('PersonalEmail', DisplayType.EMAIL), 'email field is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('CustomerBSN__c', DisplayType.STRING), 'Netherlands BSN is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('AadhaarNumber__c', DisplayType.STRING), 'India Aadhaar is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('PatientMRN__c', DisplayType.STRING), 'Healthcare MRN is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('ProviderNpiNumber__c', DisplayType.STRING), 'Healthcare NPI is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('CardCVV__c', DisplayType.STRING), 'PCI CVV is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('BankSwiftCode__c', DisplayType.STRING), 'Banking SWIFT code is high');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH, CTRL_MaskingAdvisor.evaluateHeuristic('DeviceIMEI__c', DisplayType.STRING), 'Telecom IMEI is high');
	}

	/**
	 * @description Verifies that email- and phone-typed fields with neutral names are rated medium confidence.
	 */
	@IsTest
	private static void heuristicFlagsTypedContactFieldsAsMediumWhenNameIsNeutral()
	{
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM, CTRL_MaskingAdvisor.evaluateHeuristic('Contact_Point__c', DisplayType.EMAIL), 'email type is medium');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM, CTRL_MaskingAdvisor.evaluateHeuristic('Work_Line__c', DisplayType.PHONE), 'phone type is medium');
	}

	/**
	 * @description Verifies that domain-specific compound name patterns added to the MEDIUM tier
	 * (insurance policy/claim numbers, driver license, VAT, banking transfer, travel programme,
	 * biometric) route through evaluateHeuristic at MEDIUM confidence.
	 */
	@IsTest
	private static void heuristicFlagsRegulatedIndustryNamesAsMedium()
	{
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM,
						CTRL_MaskingAdvisor.evaluateHeuristic('InsurancePolicyNumber__c', DisplayType.STRING),
						'insurance policy number is medium'
				);
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM,
						CTRL_MaskingAdvisor.evaluateHeuristic('WarrantyClaimNumber__c', DisplayType.STRING),
						'claim number is medium'
				);
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM,
						CTRL_MaskingAdvisor.evaluateHeuristic('CustomerDlNumber__c', DisplayType.STRING),
						'driver license number is medium'
				);
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM,
						CTRL_MaskingAdvisor.evaluateHeuristic('CompanyVatNumber__c', DisplayType.STRING),
						'VAT number is medium'
				);
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM,
						CTRL_MaskingAdvisor.evaluateHeuristic('WireNumber__c', DisplayType.STRING),
						'banking wire number is medium'
				);
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM,
						CTRL_MaskingAdvisor.evaluateHeuristic('FrequentFlyerId__c', DisplayType.STRING),
						'frequent flyer programme id is medium'
				);
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM,
						CTRL_MaskingAdvisor.evaluateHeuristic('BiometricSignature__c', DisplayType.STRING),
						'biometric marker is medium'
				);
	}

	/**
	 * @description Verifies that weak, false-positive-prone substrings are rated low confidence, and
	 * confirms that the generic `card` substring is intentionally NOT flagged on its own — that
	 * pattern was removed from LOW because the HIGH-tier compound patterns (creditcard, cardnumber,
	 * cvv, cardlast4, maskedpan, etc.) cover the actually-sensitive cases, and standalone `card`
	 * false-positives on common non-sensitive field names like BusinessCardTheme__c.
	 */
	@IsTest
	private static void heuristicFlagsWeakSubstringsAsLow()
	{
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.LOW, CTRL_MaskingAdvisor.evaluateHeuristic('SecretSauce__c', DisplayType.STRING), 'secret is low');
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.LOW,
						CTRL_MaskingAdvisor.evaluateHeuristic('PaymentGatewayApiKey__c', DisplayType.STRING),
						'api key credential is low'
				);
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.LOW, CTRL_MaskingAdvisor.evaluateHeuristic('UserPasswordHash__c', DisplayType.STRING), 'password credential is low');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.LOW, CTRL_MaskingAdvisor.evaluateHeuristic('MothersMaidenName__c', DisplayType.STRING), 'KBA maiden name is low');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.LOW, CTRL_MaskingAdvisor.evaluateHeuristic('CardLast4__c', DisplayType.STRING), 'PCI truncated PAN is low');
		Assert.isNull
				(
						CTRL_MaskingAdvisor.evaluateHeuristic('BusinessCardTheme__c', DisplayType.STRING),
						'generic card substring no longer fires standalone — covered by HIGH compound patterns'
				);
	}

	/**
	 * @description Verifies that neutral fields and a null name produce no heuristic match.
	 */
	@IsTest
	private static void heuristicReturnsNullForNeutralFields()
	{
		Assert.isNull(CTRL_MaskingAdvisor.evaluateHeuristic('AnnualRevenue', DisplayType.CURRENCY), 'neutral not flagged');
		Assert.isNull(CTRL_MaskingAdvisor.evaluateHeuristic(null, DisplayType.STRING), 'null name not flagged');
	}

	/**
	 * @description Verifies that field analysis returns rows with classification availability, heuristics, and applied rules.
	 */
	@IsTest
	private static void describeFieldsReturnsRowsWithHeuristics()
	{
		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');

		Assert.isTrue(analysis.classificationAvailable, 'FieldDefinition is readable in this org');
		Assert.isFalse(analysis.fields.isEmpty(), 'Account exposes fields');

		CTRL_MaskingAdvisor.DTO_FieldRow phoneRow = rowFor(analysis, Account.Phone);
		Assert.isNotNull(phoneRow, 'Account exposes a Phone field');
		Assert.areEqual('PHONE', phoneRow.type, 'the field type is surfaced');
		Assert.isFalse(phoneRow.isClassified, 'Account.Phone carries no native classification in this org');
		Assert.areEqual(CTRL_MaskingAdvisor.HeuristicConfidence.HIGH.name(), phoneRow.heuristicConfidence, 'phone field is high-confidence');
		Assert.isTrue(phoneRow.appliedRules.isEmpty(), 'no masking target is wired to Account.Phone in this org');
	}

	/**
	 * @description Verifies that a native classification overlay marks a field classified and suppresses the heuristic.
	 */
	@IsTest
	private static void describeFieldsOverlaysNativeClassification()
	{
		registerConfidentialFieldOverlay(Account.Description, 'PII');

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');

		CTRL_MaskingAdvisor.DTO_FieldRow descriptionRow = rowFor(analysis, Account.Description);
		Assert.isTrue(descriptionRow.isClassified, 'Description carries a native classification from the overlay');
		Assert.areEqual(SECURITY_CLASSIFICATION_CONFIDENTIAL, descriptionRow.securityClassification, 'the native SecurityClassification is surfaced');
		Assert.isNull(descriptionRow.heuristicConfidence, 'a classified field needs no heuristic flag');
	}

	/**
	 * @description Verifies that an unreadable FieldDefinition query degrades gracefully to heuristic-only mode.
	 */
	@IsTest
	private static void describeFieldsDegradesToHeuristicWhenClassificationUnreadable()
	{
		TST_Mock.throwsException(FieldDefinition.SObjectType, 'Simulated FieldDefinition denial');

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');

		Assert.isFalse(analysis.classificationAvailable, 'a FieldDefinition read failure degrades to heuristic mode');
		Assert.isFalse(analysis.fields.isEmpty(), 'fields are still enumerated via describe in heuristic mode');
		Assert.areEqual(
				CTRL_MaskingAdvisor.HeuristicConfidence.HIGH.name(),
				rowFor(analysis, Account.Phone).heuristicConfidence,
				'heuristics still run when classification is unavailable'
		);
	}

	/**
	 * @description Verifies that an active target on a specific field surfaces as that field's applied rule.
	 */
	@IsTest
	private static void describeFieldsActiveFieldTargetAppearsInAppliedRules()
	{
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {activeTargetFor('Account', 'Account.Phone')});

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');

		List<CTRL_MaskingAdvisor.DTO_AppliedRule> applied = rowFor(analysis, Account.Phone).appliedRules;
		Assert.areEqual(1, applied.size(), 'an active target on Account.Phone is surfaced as one applied rule');
		Assert.isTrue(applied[0].isActive, 'the applied rule reflects the target active state');
	}

	/**
	 * @description Verifies that a blank-field active target surfaces in the analysis object-wide rules.
	 */
	@IsTest
	private static void describeFieldsBlankFieldTargetAppearsInObjectWideRules()
	{
		final String accountObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);

		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {activeTargetFor(accountObjectName, null)});

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields(accountObjectName);

		Assert.areEqual(1, analysis.objectWideRules.size(), 'a blank-field active target is surfaced as one object-wide rule');
		Assert.isTrue(analysis.objectWideRules[0].isActive, 'the object-wide rule reflects the target active state');
	}

	/**
	 * @description Verifies that an unresolvable object name yields no field rows.
	 */
	@IsTest
	private static void describeFieldsReturnsEmptyForUnknownObject()
	{
		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('NotARealObject__c');

		Assert.isTrue(analysis.fields.isEmpty(), 'an unresolvable object yields no field rows');
	}

	/**
	 * @description Verifies that coverage assessment flags an uncovered object whose fields carry a native
	 * classification or a high-confidence heuristic signal, reporting it as requiring attention.
	 */
	@IsTest
	private static void assessObjectCoverageFlagsSensitiveFieldsWithNoActiveMasking()
	{
		registerConfidentialFieldOverlay(Account.Description, 'PII');
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectCoverageAssessment assessment =
				CTRL_MaskingAdvisor.assessObjectCoverage(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));

		Assert.isFalse(assessment.hasActiveMasking, 'no active target exists for the object');
		Assert.isTrue(assessment.requiresAttention, 'sensitive fields with no masking require attention');
		Assert.areEqual(UTIL_SObjectDescribe.getDescribe(Account.SObjectType).getDescribe().getLabel(), assessment.objectLabel, 'the object label travels with the assessment');
		Assert.isNotNull(flaggedRowFor(assessment, Account.Description), 'the natively classified field is flagged');
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.SENSITIVITY_SENSITIVE,
						flaggedRowFor(assessment, Account.Description).sensitivityLevel,
						'a classified field is rated sensitive'
				);
		Assert.isNotNull(flaggedRowFor(assessment, Account.Phone), 'the high-confidence heuristic field is flagged');
		for(CTRL_MaskingAdvisor.DTO_FlaggedField flagged : assessment.flaggedFields)
		{
			Assert.areNotEqual
					(
							CTRL_MaskingAdvisor.SENSITIVITY_NOT_SENSITIVE,
							flagged.sensitivityLevel,
							'only sensitive and possibly-sensitive fields are flagged'
					);
		}
	}

	/**
	 * @description Verifies coverage assessment flags an object whose only uncovered likely-sensitive fields
	 * are PossiblySensitive (no Sensitive field) as requiring attention — the broadened bar that matches the
	 * on-demand scan, so the Health Check card and the scan name the same objects. A LogEntry's Fingerprint
	 * field rates PossiblySensitive (a biometric-name heuristic) and is its only flagged field.
	 */
	@IsTest
	private static void assessObjectCoverageFlagsPossiblySensitiveOnlyObjectAsRequiringAttention()
	{
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectCoverageAssessment assessment =
				CTRL_MaskingAdvisor.assessObjectCoverage(UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType));

		Assert.isFalse(assessment.flaggedFields.isEmpty(), 'the possibly-sensitive fingerprint field is flagged');
		Assert.isTrue(assessment.requiresAttention, 'an object whose only uncovered likely-sensitive fields are possibly sensitive requires attention, matching the scan bar');
		for(CTRL_MaskingAdvisor.DTO_FlaggedField flagged : assessment.flaggedFields)
		{
			Assert.areEqual('PossiblySensitive', flagged.sensitivityLevel, 'no flagged field is Sensitive — so requiring attention proves the broadened possibly-sensitive bar');
		}
	}

	/**
	 * @description Verifies that the coverage scan marks flagged Long Text Area fields — the high-risk
	 * unmasked free-text blind spot — so the console can call them out among the scan results.
	 */
	@IsTest
	private static void assessObjectCoverageMarksLongTextAreaFlaggedFields()
	{
		registerConfidentialFieldOverlay(Account.Description, 'PII');
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectCoverageAssessment assessment =
				CTRL_MaskingAdvisor.assessObjectCoverage(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));

		Assert.isTrue(flaggedRowFor(assessment, Account.Description).isLongTextArea, 'a flagged Long Text Area field is marked');
		Assert.isFalse(flaggedRowFor(assessment, Account.Phone).isLongTextArea, 'a flagged phone field is not a Long Text Area');
	}

	/**
	 * @description Verifies that an active object-wide target counts as coverage, so an already-masked object
	 * (for example a framework object on a stock install) is never flagged by the scan.
	 */
	@IsTest
	private static void assessObjectCoverageReportsActiveObjectWideMaskingAsCovered()
	{
		final String accountObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {activeTargetFor(accountObjectName, null)});

		CTRL_MaskingAdvisor.DTO_ObjectCoverageAssessment assessment = CTRL_MaskingAdvisor.assessObjectCoverage(accountObjectName);

		Assert.isTrue(assessment.hasActiveMasking, 'an active object-wide target counts as masking coverage');
		Assert.isFalse(assessment.requiresAttention, 'a covered object requires no attention');
		Assert.isTrue(assessment.flaggedFields.isEmpty(), 'a covered object flags no fields');
	}

	/**
	 * @description Verifies that an active field-level target counts as coverage for the whole object.
	 */
	@IsTest
	private static void assessObjectCoverageReportsActiveFieldMaskingAsCovered()
	{
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {activeTargetFor('Account', 'Account.Phone')});

		CTRL_MaskingAdvisor.DTO_ObjectCoverageAssessment assessment =
				CTRL_MaskingAdvisor.assessObjectCoverage(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));

		Assert.isTrue(assessment.hasActiveMasking, 'an active field-level target counts as masking coverage');
		Assert.isFalse(assessment.requiresAttention, 'a covered object requires no attention');
		Assert.isTrue(assessment.flaggedFields.isEmpty(), 'a covered object flags no fields');
	}

	/**
	 * @description Verifies that an inactive target is not coverage — sensitive fields behind a dormant
	 * target still require attention.
	 */
	@IsTest
	private static void assessObjectCoverageIgnoresInactiveTargetsAsCoverage()
	{
		final String accountObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {appliedTarget('DormantCover', accountObjectName, null, false, rule(true))});

		CTRL_MaskingAdvisor.DTO_ObjectCoverageAssessment assessment = CTRL_MaskingAdvisor.assessObjectCoverage(accountObjectName);

		Assert.isFalse(assessment.hasActiveMasking, 'an inactive target is not masking coverage');
		Assert.isTrue(assessment.requiresAttention, 'sensitive fields behind an inactive target still require attention');
	}

	/**
	 * @description Verifies that an unresolvable object name yields a safe, empty assessment.
	 */
	@IsTest
	private static void assessObjectCoverageEchoesUnknownObjectAsEmptyAssessment()
	{
		CTRL_MaskingAdvisor.DTO_ObjectCoverageAssessment assessment = CTRL_MaskingAdvisor.assessObjectCoverage('NotARealObject__c');

		Assert.areEqual('NotARealObject__c', assessment.objectApiName, 'the requested name echoes back');
		Assert.isFalse(assessment.hasActiveMasking, 'an unresolvable object reports no masking');
		Assert.isFalse(assessment.requiresAttention, 'an unresolvable object requires no attention');
		Assert.isTrue(assessment.flaggedFields.isEmpty(), 'an unresolvable object flags no fields');
	}

	/**
	 * @description Verifies that the bounded coverage summary flags an uncovered own custom object whose
	 * field carries a native classification, with no candidates left unassessed.
	 */
	@IsTest
	private static void summarizeCustomObjectCoverageFlagsUncoveredSensitiveObject()
	{
		final String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		TST_Mock.register(EntityDefinition.SObjectType, new List<EntityDefinition>
		{
				entityRow(apiCallObjectName, 'API Call', null),
				entityRow('Account', 'Account', null),
				entityRow('FSL__WorkOrderExtension__c', 'Work Order Extension', 'FSL')
		});
		registerConfidentialFieldOverlay(ApiCall__c.Request__c);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_CustomObjectCoverageSummary summary = CTRL_MaskingAdvisor.summarizeCustomObjectCoverage();

		Assert.areEqual(1, summary.assessedObjectCount, 'only the own custom object is a candidate');
		Assert.areEqual(0, summary.unassessedObjectCount, 'one candidate fits within the per-run bound');
		Assert.areEqual(new List<String> {apiCallObjectName}, summary.objectsRequiringAttention, 'the uncovered sensitive object requires attention');
	}

	/**
	 * @description Verifies that an object covered by an active target is assessed but never reported
	 * as requiring attention.
	 */
	@IsTest
	private static void summarizeCustomObjectCoverageSkipsCoveredObjects()
	{
		final String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		TST_Mock.register(EntityDefinition.SObjectType, new List<EntityDefinition> {entityRow(apiCallObjectName, 'API Call', null)});
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {activeTargetFor(apiCallObjectName, null)});

		CTRL_MaskingAdvisor.DTO_CustomObjectCoverageSummary summary = CTRL_MaskingAdvisor.summarizeCustomObjectCoverage();

		Assert.areEqual(1, summary.assessedObjectCount, 'a covered candidate is still assessed');
		Assert.isTrue(summary.objectsRequiringAttention.isEmpty(), 'an actively masked object requires no attention');
	}

	/**
	 * @description Verifies that assessments stop at the per-run bound and the remainder is counted,
	 * not silently dropped. Uses the ten resolvable framework custom objects (labelled to sort first)
	 * to genuinely fill every assessment slot, with two overflow candidates behind them.
	 */
	@IsTest
	private static void summarizeCustomObjectCoverageBoundsAssessmentsAndCountsOverflow()
	{
		List<SObjectType> frameworkObjects = new List<SObjectType>
		{
				ApiCall__c.SObjectType, ApiIssue__c.SObjectType, ApiRuntimeSwitch__c.SObjectType,
				AsyncChainExecution__c.SObjectType, Foobar__c.SObjectType, LogEntry__c.SObjectType,
				LogSetting__c.SObjectType, LoginFrequency__c.SObjectType, ScheduleSetting__c.SObjectType,
				ScheduledJob__c.SObjectType
		};
		List<EntityDefinition> entities = new List<EntityDefinition>();
		for(Integer index = 0; index < frameworkObjects.size(); index++)
		{
			entities.add(entityRow(UTIL_SObjectDescribe.getObjectNameFromType(frameworkObjects[index]), 'A' + index, null));
		}
		entities.add(entityRow('OverflowPlaceholderOne__c', 'Z1', null));
		entities.add(entityRow('OverflowPlaceholderTwo__c', 'Z2', null));
		TST_Mock.register(EntityDefinition.SObjectType, entities);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_CustomObjectCoverageSummary summary = CTRL_MaskingAdvisor.summarizeCustomObjectCoverage();

		Assert.areEqual(CTRL_MaskingAdvisor.MAXIMUM_OBJECTS_ASSESSED_PER_HEALTH_CHECK, summary.assessedObjectCount, 'assessments stop at the per-run bound');
		Assert.areEqual(2, summary.unassessedObjectCount, 'candidates beyond the bound are counted, not assessed');
	}

	/**
	 * @description Verifies that unresolvable candidates never consume assessment slots — a real offender
	 * stays inside the assessed window even when unresolvable rows sort ahead of it, so a stale
	 * EntityDefinition row can never hide a genuine gap behind the bound.
	 */
	@IsTest
	private static void summarizeCustomObjectCoverageDoesNotSpendSlotsOnUnresolvableObjects()
	{
		final String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		List<EntityDefinition> entities = new List<EntityDefinition>();
		for(Integer index = 0; index < CTRL_MaskingAdvisor.MAXIMUM_OBJECTS_ASSESSED_PER_HEALTH_CHECK; index++)
		{
			entities.add(entityRow('UnresolvablePlaceholder' + index + '__c', 'A' + index, null));
		}
		entities.add(entityRow(apiCallObjectName, 'Z Real Object', null));
		TST_Mock.register(EntityDefinition.SObjectType, entities);
		registerConfidentialFieldOverlay(ApiCall__c.Request__c);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_CustomObjectCoverageSummary summary = CTRL_MaskingAdvisor.summarizeCustomObjectCoverage();

		Assert.areEqual(1, summary.assessedObjectCount, 'only the resolvable object consumes an assessment slot');
		Assert.areEqual(CTRL_MaskingAdvisor.MAXIMUM_OBJECTS_ASSESSED_PER_HEALTH_CHECK, summary.unassessedObjectCount, 'unresolvable candidates count as unchecked');
		Assert.areEqual(new List<String> {apiCallObjectName}, summary.objectsRequiringAttention, 'the real offender is not pushed out by unresolvable rows');
	}

	/**
	 * @description Verifies that standard objects and managed-package objects are never candidates for
	 * the health-check sweep — the console's on-demand scan handles those on explicit request.
	 */
	@IsTest
	private static void summarizeCustomObjectCoverageIgnoresStandardAndManagedPackageObjects()
	{
		TST_Mock.register(EntityDefinition.SObjectType, new List<EntityDefinition>
		{
				entityRow('Account', 'Account', null),
				entityRow('FSL__WorkOrderExtension__c', 'Work Order Extension', 'FSL')
		});
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_CustomObjectCoverageSummary summary = CTRL_MaskingAdvisor.summarizeCustomObjectCoverage();

		Assert.areEqual(0, summary.assessedObjectCount, 'standard and managed-package objects are not candidates');
		Assert.areEqual(0, summary.unassessedObjectCount, 'nothing remains unassessed when there are no candidates');
		Assert.isTrue(summary.objectsRequiringAttention.isEmpty(), 'no candidates means nothing requires attention');
	}

	/**
	 * @description Verifies that the regulated-field inventory projects a natively classified field into a
	 * row carrying its type, classification, compliance group, and sensitivity rating.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryProjectsClassifiedFieldRow()
	{
		registerConfidentialFieldOverlay(Account.Description, 'PII');
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));

		CTRL_MaskingAdvisor.DTO_FieldInventoryRow row = inventoryRowFor(inventory, Account.Description);
		Assert.isNotNull(row, 'a natively classified field appears in the inventory');
		Assert.areEqual(SECURITY_CLASSIFICATION_CONFIDENTIAL, row.securityClassification, 'the native classification is projected');
		Assert.areEqual('PII', row.complianceGroup, 'the native compliance group is projected');
		Assert.areEqual(CTRL_MaskingAdvisor.SENSITIVITY_SENSITIVE, row.sensitivityLevel, 'a classified field is rated sensitive');
		Assert.isNotNull(row.fieldType, 'the field display type travels with the row');
	}

	/**
	 * @description Verifies that the inventory flags Long Text Area fields (the common unmasked free-text
	 * blind spot) and leaves shorter regulated fields unflagged.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryFlagsLongTextAreaFields()
	{
		registerConfidentialFieldOverlay(Account.Description);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));

		Assert.isTrue(inventoryRowFor(inventory, Account.Description).isLongTextArea, 'a Long Text Area field is flagged');
		Assert.isFalse(inventoryRowFor(inventory, Account.Phone).isLongTextArea, 'a phone field is not a Long Text Area');
	}

	/**
	 * @description Verifies that fields rated NotSensitive are excluded from the regulated-field inventory.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryExcludesNonSensitiveFields()
	{
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));

		Assert.isNull(inventoryRowFor(inventory, Account.NumberOfEmployees), 'a non-sensitive field is not in the regulated inventory');
	}

	/**
	 * @description Verifies that the inventory lists a regulated field even when an active object-wide target
	 * covers it, marking it masked today — unlike the coverage assessment, the inventory never short-circuits
	 * on existing masking because its purpose is a full regulated-field census including covered fields.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryListsFieldsRegardlessOfActiveMasking()
	{
		final String accountObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {activeTargetFor(accountObjectName, null)});

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory = CTRL_MaskingAdvisor.getRegulatedFieldInventory(accountObjectName);

		CTRL_MaskingAdvisor.DTO_FieldInventoryRow row = inventoryRowFor(inventory, Account.Phone);
		Assert.isNotNull(row, 'a regulated field is listed even when masking already covers it');
		Assert.isTrue(row.maskedToday, 'an active object-wide target marks the field masked today');
	}

	/**
	 * @description Verifies that a regulated field with no active masking is reported as not masked today.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryReportsUnmaskedFieldsAsNotMaskedToday()
	{
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));

		Assert.isFalse(inventoryRowFor(inventory, Account.Phone).maskedToday, 'a field with no active target is not masked today');
	}

	/**
	 * @description Verifies that history tracking is recommended only for fields rated Sensitive (regulated
	 * data warranting a change-audit trail), not for fields rated only PossiblySensitive.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryRecommendsHistoryTrackingForSensitiveFieldsOnly()
	{
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory accountInventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));
		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory contactInventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(Contact.SObjectType));

		Assert.isTrue(inventoryRowFor(accountInventory, Account.Phone).historyTrackingRecommended, 'a sensitive field recommends history tracking');
		Assert.isFalse(inventoryRowFor(contactInventory, Contact.MailingStreet).historyTrackingRecommended, 'a possibly-sensitive field does not');
	}

	/**
	 * @description Verifies that the inventory carries the advisor's recommended masking rule (developer name
	 * and label) for a field a rule matches.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryCarriesRecommendedRule()
	{
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(Contact.SObjectType));

		CTRL_MaskingAdvisor.DTO_FieldInventoryRow row = inventoryRowFor(inventory, Contact.MailingStreet);
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_ADDRESS, row.recommendedRuleDeveloperName, 'the address rule is recommended for a street field');
		Assert.isNotNull(row.recommendedRuleLabel, 'the recommended rule label travels with the row');
	}

	/**
	 * @description Verifies the heuristic no longer fires on an accidental cross-word substring: `ClassName__c`
	 * tokenises to `class`/`name`, neither a sensitive-identifier token, so the `ssn` pattern hidden inside
	 * `claSSNAme` must not rate it sensitive. Regression guard for the token-aware matcher — the export
	 * previously rated an Apex class-name field Sensitive and recommended SSN masking for it.
	 */
	@IsTest
	private static void heuristicDoesNotFireOnAccidentalCrossWordSubstring()
	{
		Assert.isNull(CTRL_MaskingAdvisor.evaluateHeuristic('ClassName__c', DisplayType.STRING), 'a class-name field carries no sensitive-identifier token');
		Assert.isNull(CTRL_MaskingAdvisor.evaluateHeuristic('ClassName', DisplayType.STRING), 'the bare class-name token is not a sensitive-identifier match');
	}

	/**
	 * @description Verifies the token-aware heuristic still flags a sensitive identifier glued into a single
	 * un-separated token — `ssnvalue__c`, `customerssn__c`, `medicarenumber__c` carry no camelCase or
	 * underscore boundary, so the pattern lives inside one token and must still rate HIGH. Guards against a
	 * false-negative regression where token-boundary matching would silently drop a regulated field that the
	 * org named without separators.
	 */
	@IsTest
	private static void heuristicFlagsSensitivePatternGluedIntoSingleToken()
	{
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.HIGH,
						CTRL_MaskingAdvisor.evaluateHeuristic('ssnvalue__c', DisplayType.STRING),
						'an un-separated ssn field is still high'
				);
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.HIGH,
						CTRL_MaskingAdvisor.evaluateHeuristic('customerssn__c', DisplayType.STRING),
						'an ssn suffix glued to a single token is still high'
				);
		Assert.areEqual
				(
						CTRL_MaskingAdvisor.HeuristicConfidence.HIGH,
						CTRL_MaskingAdvisor.evaluateHeuristic('medicarenumber__c', DisplayType.STRING),
						'a medicare identifier glued into one token is still high'
				);
	}

	/**
	 * @description Verifies the resolver prefers the field's TYPE concept over a longer name substring: an
	 * EMAIL-typed `EmailAddress` field (whose name contains both the `email` and the longer `address` stem)
	 * recommends the email rule, not the postal-address rule. The export previously recommended "Mask Postal
	 * Addresses" for an email field because the longer `address` stem won the primary slot.
	 */
	@IsTest
	private static void recommendationPrefersFieldTypeConceptOverLongerNameMatch()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt>
		{
				labeledRule(SEL_MaskingRule.RULE_MASK_ADDRESS, 'Mask Postal Addresses', true),
				labeledRule(SEL_MaskingRule.RULE_MASK_EMAIL, 'Mask Email Addresses', true)
		};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('EmailAddress', DisplayType.EMAIL, candidates);

		Assert.areEqual(SEL_MaskingRule.RULE_MASK_EMAIL, recommended?.DeveloperName, 'an email-typed field recommends the email rule over the longer address-stem match');
	}

	/**
	 * @description Verifies a PHONE-typed field's primary recommendation is deterministic regardless of the
	 * candidate order — both phone rules concept-match a phone field, so the resolver must always surface the
	 * same primary (the international rule) rather than echoing whichever candidate happened to sort first. The
	 * export previously recommended US masking on one phone field and international on another in the same org.
	 */
	@IsTest
	private static void recommendationForPhoneFieldIsDeterministicAcrossCandidateOrder()
	{
		MaskingRule__mdt international = labeledRule(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL, 'Mask International Phone Numbers', true);
		MaskingRule__mdt unitedStates = labeledRule(SEL_MaskingRule.RULE_MASK_PHONE_US, 'Mask US Phone Numbers', true);

		MaskingRule__mdt fromOneOrder = CTRL_MaskingAdvisor.resolveRecommendedRule('MobilePhone', DisplayType.PHONE, new List<MaskingRule__mdt> {international, unitedStates});
		MaskingRule__mdt fromReversedOrder = CTRL_MaskingAdvisor.resolveRecommendedRule('MobilePhone', DisplayType.PHONE, new List<MaskingRule__mdt> {unitedStates, international});

		Assert.areEqual(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL, fromOneOrder?.DeveloperName, 'the international phone rule is the deterministic primary');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL, fromReversedOrder?.DeveloperName, 'candidate order does not change the phone primary');
	}

	/**
	 * @description Verifies a mobile-named phone field (no `phone` token, resolved through the field-name
	 * synonym fallback) recommends the international phone rule — consistent with `phone`-named fields —
	 * rather than the US rule. The export previously recommended US masking on a `ContactMobile` field while
	 * every `phone`-named field got international.
	 */
	@IsTest
	private static void recommendationForMobileNamedPhoneFieldIsInternational()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt>
		{
				ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL, true),
				ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, true)
		};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('ContactMobile', DisplayType.PHONE, candidates);

		Assert.areEqual
				(
						SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL,
						recommended?.DeveloperName,
						'a mobile-named phone field recommends the international rule, consistent with phone-named fields'
				);
	}

	/**
	 * @description Verifies, through the real inventory path, that a package object whose only text fields are
	 * an Apex class name and a scheduler name yields no regulated-field row for the class-name field — the
	 * token-aware heuristic no longer mis-rates `ClassName__c` as Sensitive nor recommends SSN masking for it.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryExcludesAccidentalIdentifierSubstringFields()
	{
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(ScheduledJob__c.SObjectType));

		Assert.isNull(inventoryRowFor(inventory, ScheduledJob__c.ClassName__c), 'an Apex class-name field is not a regulated-field row');
	}

	/**
	 * @description Verifies that the inventory echoes the requested object's API name and resolved label.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryEchoesObjectApiNameAndLabel()
	{
		final String accountObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory = CTRL_MaskingAdvisor.getRegulatedFieldInventory(accountObjectName);

		Assert.areEqual(accountObjectName, inventory.objectApiName, 'the requested object api name is echoed');
		Assert.areEqual
				(
						UTIL_SObjectDescribe.getDescribe(Account.SObjectType).getDescribe().getLabel(),
						inventory.objectLabel,
						'the resolved object label travels with the inventory'
				);
	}

	/**
	 * @description Verifies that an active field-level target marks only its own field masked today, leaving
	 * other regulated fields on the same object reported as not masked.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryMarksOnlyTheFieldLevelTargetFieldMaskedToday()
	{
		final String accountObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
		final String phoneFieldReference = accountObjectName + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(Account.Phone);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {activeTargetFor(accountObjectName, phoneFieldReference)});

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory = CTRL_MaskingAdvisor.getRegulatedFieldInventory(accountObjectName);

		Assert.isTrue(inventoryRowFor(inventory, Account.Phone).maskedToday, 'the field-level target marks its own field masked today');
		Assert.isFalse(inventoryRowFor(inventory, Account.Fax).maskedToday, 'a regulated field with no target of its own is not masked today');
	}

	/**
	 * @description Verifies that the inventory still lists heuristic-rated regulated fields when native
	 * classification is unreadable, degrading gracefully without error.
	 */
	@IsTest
	private static void getRegulatedFieldInventorySurvivesHeuristicOnlyMode()
	{
		TST_Mock.throwsException(FieldDefinition.SObjectType, 'Simulated FieldDefinition denial');
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory =
				CTRL_MaskingAdvisor.getRegulatedFieldInventory(UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType));

		Assert.isNotNull(inventoryRowFor(inventory, Account.Phone), 'a heuristic-rated field is inventoried even without native classification');
	}

	/**
	 * @description Verifies that an unresolvable object name yields a safe, empty inventory with the api name
	 * echoed and a null label.
	 */
	@IsTest
	private static void getRegulatedFieldInventoryReturnsEmptyForUnresolvableObject()
	{
		CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory = CTRL_MaskingAdvisor.getRegulatedFieldInventory('NotARealObject__c');

		Assert.areEqual('NotARealObject__c', inventory.objectApiName, 'the requested api name is echoed even when unresolvable');
		Assert.isNull(inventory.objectLabel, 'an unresolvable object has no label');
		Assert.isTrue(inventory.rows.isEmpty(), 'an unresolvable object yields no inventory rows');
	}

	/**
	 * @description Verifies that a resolvable field returns a populated masking preview without errors.
	 */
	@IsTest
	private static void previewTypedReturnsMaskingResultForResolvableField()
	{
		CTRL_MaskingAdvisor.DTO_MaskPreview preview = CTRL_MaskingAdvisor.previewTyped('Account', 'Phone', '', '555-123-4567');

		Assert.isNotNull(preview, 'a resolvable field yields a preview');
		Assert.isNotNull(preview.maskedValue, 'the masked value is populated');
		Assert.isFalse(preview.hadErrors, 'a clean preview reports no errors');
	}

	/**
	 * @description Verifies that an unresolvable field or object yields a null preview.
	 */
	@IsTest
	private static void previewTypedReturnsNullForUnresolvableField()
	{
		Assert.isNull(CTRL_MaskingAdvisor.previewTyped('Account', 'NotARealField__c', '', 'x'), 'an unresolvable field yields no preview');
		Assert.isNull(CTRL_MaskingAdvisor.previewTyped('NotARealObject__c', 'Anything', '', 'x'), 'an unresolvable object yields no preview');
	}

	/**
	 * @description Verifies that `previewWithRule` redacts a value using a named dormant rule even when
	 * no active MaskingTarget wires that rule to the field — the preview a reviewer relies on before
	 * activating a rule. Mirrors the live stock-config case (`MaskPhoneUS` on `Contact.HomePhone`).
	 */
	@IsTest
	private static void previewWithRuleRedactsDormantRuleWithNoActiveTarget()
	{
		MaskingRule__mdt phoneRule = ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, false);
		phoneRule.Mode__c = SEL_MaskingRule.MODE_REGEX;
		phoneRule.Pattern__c = '\\d{3}-\\d{3}-\\d{4}';
		phoneRule.Replacement__c = '[PHONE_REDACTED]';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {SEL_MaskingRule.RULE_MASK_PHONE_US => phoneRule};

		CTRL_MaskingAdvisor.DTO_MaskPreview preview = CTRL_MaskingAdvisor.previewWithRule('Contact', 'HomePhone', SEL_MaskingRule.RULE_MASK_PHONE_US, '415-555-1234');

		Assert.isNotNull(preview, 'a resolvable field and rule yield a preview');
		Assert.areEqual('[PHONE_REDACTED]', preview.maskedValue, 'the dormant phone rule redacts the value with no active target');
		Assert.areEqual(1, preview.matchedRuleDeveloperNames.size(), 'the single named rule is recorded as matched');
	}

	/**
	 * @description Verifies `previewWithRule` returns null when the field cannot be resolved or the
	 * named rule does not exist — the two guard paths before the engine seam is touched.
	 */
	@IsTest
	private static void previewWithRuleReturnsNullForUnresolvableFieldOrRule()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>();

		Assert.isNull
				(
						CTRL_MaskingAdvisor.previewWithRule('Contact', 'HomePhone', 'NoSuchRule', '415-555-1234'),
						'an unresolvable rule yields no preview'
				);
		Assert.isNull
				(
						CTRL_MaskingAdvisor.previewWithRule('NotARealObject__c', 'Anything', SEL_MaskingRule.RULE_MASK_PHONE_US, 'x'),
						'an unresolvable object yields no preview'
				);
	}

	/**
	 * @description Verifies `previewWithRule` flags a JsonKey-mode rule with `expectsJsonInput = true`, so
	 * the console can explain that a correct no-op on a non-JSON scalar (the rule only redacts JSON keys)
	 * is expected behaviour rather than a broken rule.
	 */
	@IsTest
	private static void previewWithRuleFlagsJsonKeyRuleAsExpectingJsonInput()
	{
		MaskingRule__mdt secretRule = ruleWithName(SEL_MaskingRule.RULE_MASK_SECRET_KEYS, false);
		secretRule.Mode__c = SEL_MaskingRule.MODE_JSON_KEY;
		secretRule.Pattern__c = '(?i)secret';
		secretRule.Replacement__c = '***';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {SEL_MaskingRule.RULE_MASK_SECRET_KEYS => secretRule};

		CTRL_MaskingAdvisor.DTO_MaskPreview preview = CTRL_MaskingAdvisor.previewWithRule('Contact', 'Description', SEL_MaskingRule.RULE_MASK_SECRET_KEYS, 'a plain scalar value');

		Assert.isNotNull(preview, 'a resolvable field and JsonKey rule yield a preview');
		Assert.isTrue(preview.expectsJsonInput, 'a JsonKey-mode rule expects JSON input, so a scalar no-op is expected');
		Assert.areEqual('a plain scalar value', preview.maskedValue, 'the JsonKey rule no-ops on a non-JSON scalar — the result the expectsJsonInput hint explains');
	}

	/**
	 * @description Verifies `previewWithRule` leaves `expectsJsonInput = false` for a non-JsonKey rule, so
	 * the JSON-input hint only appears for the rules that actually require a JSON payload.
	 */
	@IsTest
	private static void previewWithRuleDoesNotFlagRegexRuleAsExpectingJsonInput()
	{
		MaskingRule__mdt phoneRule = ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, false);
		phoneRule.Mode__c = SEL_MaskingRule.MODE_REGEX;
		phoneRule.Pattern__c = '\\d{3}-\\d{3}-\\d{4}';
		phoneRule.Replacement__c = '[PHONE_REDACTED]';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {SEL_MaskingRule.RULE_MASK_PHONE_US => phoneRule};

		CTRL_MaskingAdvisor.DTO_MaskPreview preview = CTRL_MaskingAdvisor.previewWithRule('Contact', 'HomePhone', SEL_MaskingRule.RULE_MASK_PHONE_US, '415-555-1234');

		Assert.isNotNull(preview, 'a resolvable field and Regex rule yield a preview');
		Assert.isFalse(preview.expectsJsonInput, 'a Regex-mode rule does not expect JSON input');
	}

	/**
	 * @description Verifies that each sampled non-blank value is masked and blank values are skipped.
	 */
	@IsTest
	private static void sampleMaskedMasksEachSampledValue()
	{
		List<SObject> accounts = new List<SObject>
		{
				TST_Builder.of(Account.SObjectType).withOverride(Account.Phone, '555-000-1111').withoutInsertion().build(),
				TST_Builder.of(Account.SObjectType).withOverride(Account.Phone, '555-000-2222').withoutInsertion().build(),
				TST_Builder.of(Account.SObjectType).withOverride(Account.Phone, '').withoutInsertion().build()
		};
		TST_Mock.register(Account.SObjectType, accounts);

		List<CTRL_MaskingAdvisor.DTO_MaskSample> samples = CTRL_MaskingAdvisor.sampleMasked('Account', 'Phone', '');

		Assert.areEqual(2, samples.size(), 'blank values are skipped, not sampled');
		for(CTRL_MaskingAdvisor.DTO_MaskSample sample : samples)
		{
			Assert.isTrue(String.isNotBlank(sample.sourceValue), 'each sample carries the source value');
			Assert.isNotNull(sample.maskedValue, 'each sample carries a masked value');
			Assert.isFalse(sample.hadErrors, 'a clean sample reports no errors');
		}
	}

	/**
	 * @description Verifies that an unresolvable field yields no samples.
	 */
	@IsTest
	private static void sampleMaskedReturnsEmptyForUnresolvableField()
	{
		Assert.isTrue(CTRL_MaskingAdvisor.sampleMasked('Account', 'NotARealField__c', '').isEmpty(), 'an unresolvable field yields no samples');
	}

	/**
	 * @description Verifies that the blast radius lists only the active targets bound to the given rule.
	 */
	@IsTest
	private static void blastRadiusListsActiveTargetsReferencingTheRule()
	{
		MaskingRule__mdt maskSsnRule = TST_Factory.newMaskingRule(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => 'MaskSsn',
				MaskingRule__mdt.IsActive__c => true
		});
		Id otherRuleId = UTIL_Random.randomId(MaskingRule__mdt.SObjectType);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'MaskSsn' => maskSsnRule};
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt>
		{
				'ActiveOne' => target('ActiveOne', true, maskSsnRule.Id),
				'ActiveTwo' => target('ActiveTwo', true, maskSsnRule.Id),
				'InactiveOne' => target('InactiveOne', false, maskSsnRule.Id),
				'OtherRuleTarget' => target('OtherRuleTarget', true, otherRuleId)
		};

		CTRL_MaskingAdvisor.DTO_BlastRadius radius = CTRL_MaskingAdvisor.getBlastRadius('MaskSsn');

		Assert.areEqual('MaskSsn', radius.ruleDeveloperName, 'the radius echoes the rule it describes');
		Assert.areEqual(2, radius.activeTargetDeveloperNames.size(), 'only active targets bound to the rule count');
		Assert.isTrue(radius.activeTargetDeveloperNames.contains('ActiveOne'), 'the first active target is listed');
		Assert.isTrue(radius.activeTargetDeveloperNames.contains('ActiveTwo'), 'the second active target is listed');
	}

	/**
	 * @description Verifies that an unknown rule has an empty blast radius.
	 */
	@IsTest
	private static void blastRadiusReturnsEmptyForUnknownRule()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>();
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt>();

		CTRL_MaskingAdvisor.DTO_BlastRadius radius = CTRL_MaskingAdvisor.getBlastRadius('NoSuchRule');

		Assert.isTrue(radius.activeTargetDeveloperNames.isEmpty(), 'an unknown rule has no blast radius');
	}

	/**
	 * @description Verifies that generation produces the target metadata file, package manifest, and readme.
	 */
	@IsTest
	private static void generateConfigurationBuildsTargetPackageAndReadme()
	{
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(
				targetDecision('MaskAccountPhone', 'Mask Account Phone', 'MaskPhone', 'Account', 'Phone', ''),
				new List<String>());

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		String targetFile = bundle.files.get(targetBundlePath('MaskAccountPhone'));
		Assert.isNotNull(targetFile, 'the target metadata file is generated');
		Assert.isTrue(targetFile.contains('<label>Mask Account Phone</label>'), 'the label is rendered');
		Assert.isTrue(targetFile.contains(fieldRow(SEL_MaskingTarget.FIELD_SOBJECT_TYPE)), 'the SObjectType field row is rendered');
		Assert.isTrue(targetFile.contains('xsi:type="xsd:boolean">true</value>'), 'the target is rendered active');
		Assert.isNotNull(bundle.files.get('metadata/package.xml'), 'the package manifest is generated');
		Assert.isNotNull(bundle.files.get('README.md'), 'the readme is generated');
	}

	/**
	 * @description Verifies that an empty generation request (no targets, no rules to activate) emits a
	 * README that substitutes the NoMembers label into the members-list placeholder, so an admin who
	 * submits an empty bundle sees a recognisable "none" marker instead of an empty trailing value.
	 */
	@IsTest
	private static void generateConfigurationEmitsNoMembersReadmeWhenBundleIsEmpty()
	{
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = new CTRL_MaskingAdvisor.DTO_GenerationRequest();
		request.targets = new List<CTRL_MaskingAdvisor.DTO_TargetDecision>();
		request.rulesToActivate = new List<String>();

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		String readmeContent = bundle.files.get('README.md');
		Assert.isNotNull(readmeContent, 'the readme is generated even for an empty bundle');
		Assert.isTrue(readmeContent.contains(System.Label.DataMaskingAdvisor_Readme_NoMembers), 'the empty members list renders via the NoMembers label');
	}

	/**
	 * @description Verifies that a blank field renders as an xsi:nil value in the generated target.
	 */
	@IsTest
	private static void generateConfigurationRendersBlankFieldAsNil()
	{
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(targetDecision('MaskAccountWide', 'Mask Account', 'MaskAll', 'Account', '', ''), new List<String>());

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		String targetFile = bundle.files.get(targetBundlePath('MaskAccountWide'));
		Assert.isTrue(targetFile.contains(fieldRow(SEL_MaskingTarget.FIELD_FIELD)), 'the Field__c row is present');
		Assert.isTrue(targetFile.contains('xsi:nil="true"'), 'a blank field renders as xsi:nil');
	}

	/**
	 * @description Verifies that the generated target label is XML-escaped.
	 */
	@IsTest
	private static void generateConfigurationEscapesLabel()
	{
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(targetDecision('MaskEscaped', 'A & B <C>', 'MaskX', 'Account', 'Name', ''), new List<String>());

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		String targetFile = bundle.files.get(targetBundlePath('MaskEscaped'));
		Assert.isTrue(targetFile.contains('<label>A &amp; B &lt;C&gt;</label>'), 'the label is XML-escaped');
	}

	/**
	 * @description Verifies that rule activation preserves a shipped rule's label and falls back to the developer name for an unshipped rule.
	 */
	@IsTest
	private static void generateConfigurationActivatesShippedAndUnshippedRules()
	{
		MaskingRule__mdt shipped = TST_Factory.newMaskingRule(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => 'MaskPhone',
				MaskingRule__mdt.MasterLabel => 'Mask Phone',
				MaskingRule__mdt.IsActive__c => false
		});
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'MaskPhone' => shipped};
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(
				targetDecision('MaskAccountPhone', 'Mask', 'MaskPhone', 'Account', 'Phone', ''),
				new List<String> {'MaskPhone', 'DormantRule'});

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		String shippedFile = bundle.files.get(ruleBundlePath('MaskPhone'));
		String dormantFile = bundle.files.get(ruleBundlePath('DormantRule'));
		Assert.isTrue(shippedFile.contains('<label>Mask Phone</label>'), 'a shipped rule keeps its master label');
		Assert.isTrue(dormantFile.contains('<label>DormantRule</label>'), 'an unshipped rule falls back to its developer name');
		Assert.isTrue(shippedFile.contains('xsi:type="xsd:boolean">true</value>'), 'the rule is activated');
		String ruleStem = SEL_MaskingRule.OBJECT_NAME.removeEnd(CTRL_MaskingAdvisor.CUSTOM_METADATA_SUFFIX);
		Assert.isTrue(bundle.files.get('metadata/package.xml').contains(ruleStem + '.MaskPhone'), 'the rule is listed in the manifest');
	}

	/**
	 * @description Verifies that a null target label renders as an empty label element.
	 */
	@IsTest
	private static void generateConfigurationRendersNullLabelAsEmpty()
	{
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(targetDecision('MaskNullLabel', null, 'MaskX', 'Account', 'Name', ''), new List<String>());

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		Assert.isTrue(bundle.files.get(targetBundlePath('MaskNullLabel')).contains('<label></label>'), 'a null label renders as an empty label');
	}

	/**
	 * @description Verifies that the JSON entry point deserializes the request and builds the bundle.
	 */
	@IsTest
	private static void generateConfigurationFromJsonBuildsBundle()
	{
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(targetDecision('MaskAccountPhone', 'Mask', 'MaskPhone', 'Account', 'Phone', ''), new List<String>());

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(JSON.serialize(request));

		Assert.isNotNull(bundle.files.get(targetBundlePath('MaskAccountPhone')), 'the JSON entry point builds the bundle');
	}

	/**
	 * @description Verifies that blank JSON input yields an empty bundle.
	 */
	@IsTest
	private static void generateConfigurationFromBlankJsonReturnsEmptyBundle()
	{
		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration('');

		Assert.isTrue(bundle.files.isEmpty(), 'blank input yields an empty bundle');
		Assert.isNull(bundle.zipBase64, 'a blank input yields no zip payload (field is omitted from the JSON response)');
	}

	/**
	 * @description Verifies that generation populates `zipBase64` with a base64-encoded zip archive that
	 * round-trips back through `Compression.ZipReader` to the exact same file entries (paths and bodies)
	 * the LWC previews via `files`. The single-archive shape lets the LWC issue one anchor download
	 * containing every artifact, in lieu of asking the admin to copy-paste each file in turn.
	 */
	@IsTest
	private static void generateConfigurationPopulatesZipBase64WithEveryFile()
	{
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(
				targetDecision('MaskAccountPhone', 'Mask Account Phone', 'MaskPhone', 'Account', 'Phone', ''),
				new List<String> {'DormantRule'});

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		Assert.isNotNull(bundle.zipBase64, 'zipBase64 is populated when files exist');
		Assert.isTrue(String.isNotBlank(bundle.zipBase64), 'zipBase64 is a non-empty base64 string when files exist');
		Compression.ZipReader reader = new Compression.ZipReader(EncodingUtil.base64Decode(bundle.zipBase64));
		for(String path : bundle.files.keySet())
		{
			Assert.areEqual(bundle.files.get(path), reader.extract(path).toString(), 'zip entry "' + path + '" round-trips to the same body served via `files`');
		}
	}

	/**
	 * @description Verifies that when the rule being referenced is package-owned (a non-blank
	 * `NamespacePrefix`), the generated bundle qualifies that rule everywhere it is named — the target's
	 * `Rule__c` value, the activation file name, and the manifest member — so the bundle deploys against a
	 * managed subscriber org, where a bare developer name resolves to no such packaged record. The dev org
	 * cannot reproduce the managed-deploy failure directly (it has no namespace), so the rule is injected
	 * through the selector seam carrying a fictional namespace — deliberately not the running package's, which
	 * is blank here — so the test proves the generator qualifies by the rule's *own* `NamespacePrefix` rather
	 * than any ambient or hardcoded namespace.
	 */
	@IsTest
	private static void generateConfigurationNamespaceQualifiesPackagedRuleReferences()
	{
		String ruleNamespace = (UTIL_System.getManagedPackageNamespace() ?? '') + 'pkg';
		String qualified = ruleNamespace + UTIL_String.DOUBLE_UNDERSCORE + SEL_MaskingRule.RULE_MASK_PHONE_US;
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				qualified => buildNamespacedRule(SEL_MaskingRule.RULE_MASK_PHONE_US, 'Mask US Phone Numbers', ruleNamespace)
		};
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(
				targetDecision('MaskAccountPhone', 'Mask', SEL_MaskingRule.RULE_MASK_PHONE_US, 'Account', 'Phone', ''),
				new List<String> {SEL_MaskingRule.RULE_MASK_PHONE_US});

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		String targetFile = bundle.files.get(targetBundlePath('MaskAccountPhone'));
		Assert.isTrue(targetFile.contains('>' + qualified + '</value>'), 'the target Rule reference is namespace-qualified');
		String activationFile = bundle.files.get(ruleBundlePath(qualified));
		Assert.isNotNull(activationFile, 'the activation file is keyed by the namespace-qualified rule name');
		Assert.isTrue(activationFile.contains('<label>Mask US Phone Numbers</label>'), 'the activation preserves the packaged rule label');
		String ruleStem = SEL_MaskingRule.OBJECT_NAME.removeEnd(CTRL_MaskingAdvisor.CUSTOM_METADATA_SUFFIX);
		Assert.isTrue(bundle.files.get('metadata/package.xml').contains(ruleStem + '.' + qualified), 'the manifest member is namespace-qualified');
	}

	/**
	 * @description Verifies that when a foreign package or subscriber authors a rule sharing a packaged rule's
	 * developer name, the generator binds and activates the package-owned record — never the foreign same-named
	 * one. The package-owned rule is modelled with the running package namespace and the foreign rule with a
	 * guaranteed-distinct one, so the package-owned record wins deterministically regardless of selector
	 * iteration order in every packaging context (managed, unmanaged, or rebuilt under a new namespace). The
	 * winning activation is identified by its label so the assertion never bakes in a namespace.
	 */
	@IsTest
	private static void generateConfigurationPrefersPackageOwnedRuleOnDeveloperNameCollision()
	{
		String packageNamespace = UTIL_System.getManagedPackageNamespace() ?? '';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				'packageOwned' => buildNamespacedRule(SEL_MaskingRule.RULE_MASK_ADDRESS, 'Package Owned Rule', packageNamespace),
				'foreign' => buildNamespacedRule(SEL_MaskingRule.RULE_MASK_ADDRESS, 'Foreign Same-Named Rule', packageNamespace + 'subscriber')
		};
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = requestWith(
				targetDecision('MaskAccountAddress', 'Mask', SEL_MaskingRule.RULE_MASK_ADDRESS, 'Account', 'BillingStreet', ''),
				new List<String> {SEL_MaskingRule.RULE_MASK_ADDRESS});

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(request);

		String activation = findRuleActivationFile(bundle);
		Assert.isNotNull(activation, 'a rule activation file is generated');
		Assert.isTrue(activation.contains('<label>Package Owned Rule</label>'), 'the package-owned rule wins the developer-name collision in every namespace context');
		Assert.isFalse(activation.contains('Foreign Same-Named Rule'), 'the foreign same-named rule is not the one activated');
	}

	/**
	 * @description Verifies that the recommendation resolver returns `null` for a blank field API name —
	 * there is no signal to match against, so the row carries no recommendation.
	 */
	@IsTest
	private static void resolveRecommendedRuleReturnsNullForBlankFieldName()
	{
		Assert.isNull
				(
						CTRL_MaskingAdvisor.resolveRecommendedRule(UTIL_String.EMPTY, DisplayType.PHONE, new List<MaskingRule__mdt> {ruleWithName('MaskPhone', true)}),
						'a blank field API name yields no recommendation'
				);
	}

	/**
	 * @description Verifies that the recommendation resolver returns `null` when the candidate list is
	 * empty — no rules to match against, no recommendation.
	 */
	@IsTest
	private static void resolveRecommendedRuleReturnsNullForEmptyCandidates()
	{
		Assert.isNull(CTRL_MaskingAdvisor.resolveRecommendedRule('Phone', DisplayType.PHONE, new List<MaskingRule__mdt>()), 'an empty candidate list yields no recommendation');
	}

	/**
	 * @description Verifies that the recommendation resolver returns `null` when no candidate stem
	 * substring-matches the field's API name.
	 */
	@IsTest
	private static void resolveRecommendedRuleReturnsNullWhenNoStemMatches()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, true)};

		Assert.isNull(CTRL_MaskingAdvisor.resolveRecommendedRule('Phone', DisplayType.PHONE, candidates), 'a non-matching candidate stem yields no recommendation');
	}

	/**
	 * @description Verifies that the recommendation resolver picks an active rule over a dormant rule
	 * with the same stem — the admin should see a healthy recommendation before being told to activate
	 * something.
	 */
	@IsTest
	private static void resolveRecommendedRulePicksActiveOverDormantAtSameStem()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt>
		{
				ruleWithName('MaskPhone', false),
				ruleWithName('MaskPhone', true)
		};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('Phone', DisplayType.PHONE, candidates);

		Assert.isNotNull(recommended, 'a matching active candidate is recommended');
		Assert.areEqual(true, recommended.IsActive__c, 'the active candidate wins over a dormant duplicate at the same stem');
	}

	/**
	 * @description Verifies that the recommendation resolver prefers a longer stem match over a shorter
	 * stem match — more specific is more useful.
	 */
	@IsTest
	private static void resolveRecommendedRulePrefersLongerStemMatch()
	{
		List<MaskingRule__mdt> sortedCandidates = new List<MaskingRule__mdt>
		{
				ruleWithName('MaskAccountPhone', true),
				ruleWithName('MaskPhone', true)
		};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('AccountPhone', DisplayType.PHONE, sortedCandidates);

		Assert.areEqual('MaskAccountPhone', recommended.DeveloperName, 'the longer stem (more specific) wins over a shorter stem');
	}

	/**
	 * @description Verifies that the recommendation resolver returns the only dormant match when no
	 * active candidate matches — the row will display "will be activated" so the admin sees the
	 * trade-off before committing.
	 */
	@IsTest
	private static void resolveRecommendedRuleReturnsDormantWhenNoActiveCandidateMatches()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName('MaskPhone', false)};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('Phone', DisplayType.PHONE, candidates);

		Assert.isNotNull(recommended, 'a dormant candidate is still returned when no active alternative exists');
		Assert.areEqual(false, recommended.IsActive__c, 'the dormant candidate is the one returned');
	}

	/**
	 * @description Verifies that the resolver matches rules without a `Mask` prefix by their full
	 * lowercased developer name — extension authors are not forced into the framework's naming
	 * convention to participate.
	 */
	@IsTest
	private static void resolveRecommendedRuleMatchesRulesWithoutMaskPrefix()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName('Phone', true)};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('PhoneNumber', DisplayType.PHONE, candidates);

		Assert.isNotNull(recommended, 'a rule without a Mask prefix still participates in recommendations');
		Assert.areEqual('Phone', recommended.DeveloperName, 'the full developer name acts as the stem when there is no Mask prefix');
	}

	/**
	 * @description Verifies the resolver does NOT recommend a rule on a non-text-shaped field type (a
	 * Boolean) even when its name substring-matches a rule stem — the over-match guard. `MaskEmail`
	 * previously landed on `HasOptedOutOfEmail` (a checkbox), which a compliance reviewer would distrust.
	 */
	@IsTest
	private static void resolveRecommendedRuleSkipsBooleanFieldType()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, false)};

		Assert.isNull
				(
						CTRL_MaskingAdvisor.resolveRecommendedRule('HasOptedOutOfEmail', DisplayType.BOOLEAN, candidates),
						'a Boolean field gets no recommendation even when its name substring-matches a rule stem'
				);
	}

	/**
	 * @description Verifies the resolver does NOT recommend a rule on a DateTime field — the
	 * `EmailBouncedDate` over-match the resolver previously produced.
	 */
	@IsTest
	private static void resolveRecommendedRuleSkipsDateTimeFieldType()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, false)};

		Assert.isNull
				(
						CTRL_MaskingAdvisor.resolveRecommendedRule('EmailBouncedDate', DisplayType.DATETIME, candidates),
						'a DateTime field gets no recommendation even when its name substring-matches a rule stem'
				);
	}

	/**
	 * @description Verifies the resolver still recommends a rule on a matching text-shaped field type
	 * (an Email field) — the type gate admits the types the framework can actually mask.
	 */
	@IsTest
	private static void resolveRecommendedRuleRecommendsOnTextShapedFieldType()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, false)};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('Email', DisplayType.EMAIL, candidates);

		Assert.isNotNull(recommended, 'an Email-type field matching the email rule stem is recommended');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_EMAIL, recommended.DeveloperName, 'the email rule is the recommendation on an Email field');
	}

	/**
	 * @description Verifies that a null field type skips the type gate, so the resolver still matches on
	 * name alone for callers that do not supply a type.
	 */
	@IsTest
	private static void resolveRecommendedRuleWithNullFieldTypeSkipsTypeGate()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName('MaskPhone', true)};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('Phone', null, candidates);

		Assert.isNotNull(recommended, 'a null field type skips the type gate and matches on name alone');
		Assert.areEqual('MaskPhone', recommended.DeveloperName, 'the name match still resolves when no type is supplied');
	}

	/**
	 * @description Verifies the stem alias lets the shipped `MaskPhoneUS` rule (stem `phoneus`, which no
	 * phone field name contains) recommend on a standard phone field — the under-match fix. The shipped
	 * developer name is exercised directly; older tests only used the synthetic `MaskPhone`.
	 */
	@IsTest
	private static void resolveRecommendedRuleAliasesMaskPhoneUsToPhoneField()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, false)};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('HomePhone', DisplayType.PHONE, candidates);

		Assert.isNotNull(recommended, 'MaskPhoneUS recommends on a phone field via the phoneus->phone stem alias');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_PHONE_US, recommended.DeveloperName, 'the shipped phone rule is the recommendation');
	}

	/**
	 * @description Verifies the stem helper aliases the shipped `MaskPhoneUS` developer name to `phone`.
	 */
	@IsTest
	private static void ruleStemAliasesMaskPhoneUsToPhone()
	{
		Assert.areEqual('phone', CTRL_MaskingAdvisor.resolveRuleStem(SEL_MaskingRule.RULE_MASK_PHONE_US), 'MaskPhoneUS stems to the phone alias');
	}

	/**
	 * @description Verifies the stem helper aliases the shipped `MaskPhoneInternational` developer name to
	 * `phone`, so the international phone rule reaches a standard phone field (whose name contains neither
	 * `phoneinternational` nor `phoneus`) the same way `MaskPhoneUS` does.
	 */
	@IsTest
	private static void ruleStemAliasesMaskPhoneInternationalToPhone()
	{
		Assert.areEqual('phone', CTRL_MaskingAdvisor.resolveRuleStem(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL), 'MaskPhoneInternational stems to the phone alias');
	}

	/**
	 * @description Verifies the stem alias lets the shipped `MaskPaymentCard` rule (stem `paymentcard`,
	 * which a card field's tokens never contain as a run) recommend on a `CreditCard__c`-named field —
	 * the successor must reach every field the rule it replaces reached.
	 */
	@IsTest
	private static void resolveRecommendedRuleRecommendsPaymentCardRuleOnCreditCardField()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, true)};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('CreditCard__c', DisplayType.STRING, candidates);

		Assert.isNotNull(recommended, 'MaskPaymentCard recommends on a CreditCard__c field via the paymentcard->card stem alias');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, recommended.DeveloperName, 'the payment-card rule is the recommendation');
	}

	/**
	 * @description Verifies the payment-card rule also reaches an underscore-tokenised `Card_Number__c`
	 * field via the card stem alias — recommendation parity with the credit-card rule it replaces.
	 */
	@IsTest
	private static void resolveRecommendedRuleRecommendsPaymentCardRuleOnCardNumberField()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, true)};

		MaskingRule__mdt recommended = CTRL_MaskingAdvisor.resolveRecommendedRule('Card_Number__c', DisplayType.STRING, candidates);

		Assert.isNotNull(recommended, 'MaskPaymentCard recommends on a Card_Number__c field via the card stem alias');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, recommended.DeveloperName, 'the payment-card rule is the recommendation');
	}

	/**
	 * @description Verifies the stem helper aliases both card-rule generations to the `card` concept, so
	 * each reaches card-named fields whose tokens never contain `paymentcard` or `creditcard` as a run.
	 */
	@IsTest
	private static void ruleStemAliasesBothCardRuleGenerationsToCard()
	{
		Assert.areEqual('card', CTRL_MaskingAdvisor.resolveRuleStem(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD), 'MaskPaymentCard stems to the card alias');
		Assert.areEqual('card', CTRL_MaskingAdvisor.resolveRuleStem(SEL_MaskingRule.RULE_MASK_CREDIT_CARD), 'MaskCreditCard stems to the card alias');
	}

	/**
	 * @description Verifies the maskability gate makes the over-match impossible end-to-end: the
	 * text-shaped Email field still gets its recommendation, while the Boolean `HasOptedOutOfEmail`
	 * field — which name-substring-matches the email rule stem — is absent from the analysis entirely,
	 * so it can never be recommended a masking rule.
	 */
	@IsTest
	private static void describeFieldsExcludesNonTextShapedFieldFromOutput()
	{
		MaskingRule__mdt emailRule = ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, false);
		emailRule.MasterLabel = 'Mask Email Addresses';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {SEL_MaskingRule.RULE_MASK_EMAIL => emailRule};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');
		CTRL_MaskingAdvisor.DTO_FieldRow emailRow = rowFor(analysis, Contact.Email);

		Assert.isNotNull(emailRow, 'the text-shaped Email field row is present on Contact');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_EMAIL, emailRow.recommendedRuleDeveloperName, 'the Email field (text-shaped) gets the email recommendation');
		Assert.isNull(rowFor(analysis, Contact.HasOptedOutOfEmail), 'the Boolean opt-out field is excluded from the analysis by the maskability gate');
	}

	/**
	 * @description Verifies the maskability gate restricts `describeFields` output to fields the framework
	 * can actually mask: every returned row is a text-shaped type, and Id / audit-stamp / Boolean / Date /
	 * Reference fields are absent — while representative text fields remain. Keeps the "Other" bucket free
	 * of un-maskable noise.
	 */
	@IsTest
	private static void describeFieldsExcludesSystemAuditAndNonTextFields()
	{
		Set<String> recommendableTypes = new Set<String> {'STRING', 'TEXTAREA', 'URL', 'EMAIL', 'PHONE', 'ENCRYPTEDSTRING'};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Assert.isFalse(analysis.fields.isEmpty(), 'Contact still exposes maskable text fields');
		for(CTRL_MaskingAdvisor.DTO_FieldRow row : analysis.fields)
		{
			Assert.isTrue(recommendableTypes.contains(row.type), 'every analyzed field is a maskable text-shaped type, found ' + row.type + ' on ' + row.apiName);
		}

		Assert.isNull(rowFor(analysis, Contact.Id), 'the Id field is excluded');
		Assert.isNull(rowFor(analysis, Contact.CreatedDate), 'an audit datetime field is excluded');
		Assert.isNull(rowFor(analysis, Contact.CreatedById), 'an audit reference field is excluded');
		Assert.isNull(rowFor(analysis, Contact.IsDeleted), 'a Boolean system field is excluded');
		Assert.isNull(rowFor(analysis, Contact.Birthdate), 'a native Date field is excluded');
		Assert.isNull(rowFor(analysis, Contact.AccountId), 'a Reference field is excluded');

		Assert.isNotNull(rowFor(analysis, Contact.Email), 'the Email text field remains');
		Assert.isNotNull(rowFor(analysis, Contact.LastName), 'the LastName text field remains');
	}

	/**
	 * @description Verifies the maskability gate also excludes text-typed fields Salesforce controls under
	 * the hood — the read-only `CaseNumber` auto-number passes the text-type gate but the engine can never
	 * write it, so it is absent from the analysis, while the writable `Subject` text field remains. Stops
	 * the advisor recommending masking on a field the engine would silently skip.
	 */
	@IsTest
	private static void describeFieldsExcludesSystemManagedReadOnlyFields()
	{
		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Case');

		Assert.isNull(rowFor(analysis, Case.CaseNumber), 'the auto-number CaseNumber field is excluded as system-managed');
		Assert.isNotNull(rowFor(analysis, Case.Subject), 'the writable Subject text field remains in the analysis');
	}

	/**
	 * @description Verifies `describeFields` recommends the shipped `MaskPhoneUS` rule on a standard
	 * phone field via the stem alias — the under-match fix, end-to-end.
	 */
	@IsTest
	private static void describeFieldsRecommendsMaskPhoneUsOnPhoneFieldViaAlias()
	{
		MaskingRule__mdt phoneRule = ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, false);
		phoneRule.MasterLabel = 'Mask US Phone Numbers';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {SEL_MaskingRule.RULE_MASK_PHONE_US => phoneRule};

		CTRL_MaskingAdvisor.DTO_FieldRow row = rowFor(CTRL_MaskingAdvisor.describeFields('Contact'), Contact.HomePhone);

		Assert.isNotNull(row, 'the HomePhone field row is present on Contact');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_PHONE_US, row.recommendedRuleDeveloperName, 'the shipped phone rule is recommended on a phone field via the alias');
		Assert.areEqual(false, row.recommendedRuleIsActive, 'the dormant phone rule is surfaced as will-be-activated');
		Assert.areEqual(
				new Set<String> {SEL_MaskingRule.RULE_MASK_PHONE_US},
				recommendedRuleNames(row),
				'with only the US rule registered it is the sole pre-selected recommendation'
		);
	}

	/**
	 * @description Verifies the multi-mask pre-selection: a phone field concept-matches BOTH shipped phone
	 * rules — the US rule (stem `phoneus`) and the international rule (stem `phoneinternational`) — each via
	 * the `phone` stem alias, so both are surfaced as pre-ticked Field-level candidates rather than just one.
	 */
	@IsTest
	private static void describeFieldsRecommendsBothPhoneRulesOnPhoneFieldViaAlias()
	{
		MaskingRule__mdt phoneUs = ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, false);
		phoneUs.MasterLabel = 'Mask US Phone Numbers';
		MaskingRule__mdt phoneInternational = ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL, false);
		phoneInternational.MasterLabel = 'Mask International Phone Numbers';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_PHONE_US => phoneUs,
				SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL => phoneInternational
		};

		CTRL_MaskingAdvisor.DTO_FieldRow row = rowFor(CTRL_MaskingAdvisor.describeFields('Contact'), Contact.HomePhone);

		Assert.isNotNull(row, 'the HomePhone field row is present on Contact');
		Set<String> recommended = recommendedRuleNames(row);
		Assert.areEqual(2, recommended.size(), 'a phone field pre-selects both shipped phone rules');
		Assert.isTrue(recommended.contains(SEL_MaskingRule.RULE_MASK_PHONE_US), 'the US phone rule is one of the recommendations');
		Assert.isTrue(recommended.contains(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL), 'the international phone rule is the other recommendation');
		Assert.isTrue(recommended.contains(row.recommendedRuleDeveloperName), 'the singular primary recommendation is one of the matched phone rules');
	}

	/**
	 * @description Verifies multi-mask pre-selection stays NARROW: a single-concept field (an email field)
	 * pre-selects only its own concept rule, never the unscoped phone rules that are merely type-applicable to
	 * it — guarding against over-selecting every type-applicable rule onto a field.
	 */
	@IsTest
	private static void describeFieldsDoesNotOverSelectUnrelatedRulesOnSingleConceptField()
	{
		MaskingRule__mdt phoneUs = ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, false);
		MaskingRule__mdt phoneInternational = ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL, false);
		MaskingRule__mdt email = ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, false);
		email.MasterLabel = 'Mask Email Addresses';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_PHONE_US => phoneUs,
				SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL => phoneInternational,
				SEL_MaskingRule.RULE_MASK_EMAIL => email
		};

		CTRL_MaskingAdvisor.DTO_FieldRow row = rowFor(CTRL_MaskingAdvisor.describeFields('Contact'), Contact.Email);

		Assert.isNotNull(row, 'the Email field row is present on Contact');
		Set<String> recommended = recommendedRuleNames(row);
		Assert.areEqual(1, recommended.size(), 'a single-concept email field pre-selects exactly one rule');
		Assert.isTrue(
				recommended.contains(SEL_MaskingRule.RULE_MASK_EMAIL),
				'only the email rule is pre-selected on an email field — the unscoped phone rules are not over-selected'
		);
	}

	/**
	 * @description Verifies that the stem helper strips a leading `Mask` prefix and lowercases the
	 * remainder. Pure logic — no dependencies.
	 */
	@IsTest
	private static void ruleStemStripsLeadingMaskPrefixAndLowercases()
	{
		Assert.areEqual('phone', CTRL_MaskingAdvisor.resolveRuleStem('MaskPhone'), 'a Mask prefix is stripped and the remainder lowercased');
	}

	/**
	 * @description Verifies that the stem helper returns the lowercased full developer name when there
	 * is no `Mask` prefix — the rule participates in matching under its full name.
	 */
	@IsTest
	private static void ruleStemReturnsLowercasedFullNameWithoutMaskPrefix()
	{
		Assert.areEqual('phone', CTRL_MaskingAdvisor.resolveRuleStem('Phone'), 'a rule without a Mask prefix uses its full lowercased name as the stem');
	}

	/**
	 * @description Verifies that the stem helper returns empty for a blank developer name so the
	 * resolver can short-circuit cleanly without throwing.
	 */
	@IsTest
	private static void ruleStemReturnsEmptyForBlankInput()
	{
		Assert.areEqual('', CTRL_MaskingAdvisor.resolveRuleStem(null), 'a null developer name yields an empty stem');
		Assert.areEqual('', CTRL_MaskingAdvisor.resolveRuleStem(''), 'a blank developer name yields an empty stem');
	}

	/**
	 * @description Verifies that `describeFields` populates the recommendation triple on a row whose
	 * field name substring-matches a candidate rule's stem. Active candidate is reflected as
	 * `recommendedRuleIsActive = true`.
	 */
	@IsTest
	private static void describeFieldsPopulatesRecommendationForMatchingActiveRule()
	{
		MaskingRule__mdt phoneRule = ruleWithName('MaskPhone', true);
		phoneRule.MasterLabel = 'Mask Phone';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'MaskPhone' => phoneRule};

		CTRL_MaskingAdvisor.DTO_FieldRow row = rowFor(CTRL_MaskingAdvisor.describeFields('Account'), Account.Phone);

		Assert.isNotNull(row, 'the Phone field row is present on Account');
		Assert.areEqual('MaskPhone', row.recommendedRuleDeveloperName, 'the matching rule is recommended');
		Assert.areEqual('Mask Phone', row.recommendedRuleLabel, 'the recommended rule label is surfaced for display');
		Assert.areEqual(true, row.recommendedRuleIsActive, 'the active flag reflects the rule state');
	}

	/**
	 * @description Verifies that `describeFields` reflects the dormant-rule case so the LWC can render
	 * the inline `will be activated` chip and route into the Generate-Bundle modal correctly.
	 */
	@IsTest
	private static void describeFieldsPopulatesRecommendationForMatchingDormantRule()
	{
		MaskingRule__mdt phoneRule = ruleWithName('MaskPhone', false);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'MaskPhone' => phoneRule};

		CTRL_MaskingAdvisor.DTO_FieldRow row = rowFor(CTRL_MaskingAdvisor.describeFields('Account'), Account.Phone);

		Assert.areEqual('MaskPhone', row.recommendedRuleDeveloperName, 'the dormant rule is still recommended');
		Assert.areEqual(false, row.recommendedRuleIsActive, 'the active flag is false for a dormant recommendation');
	}

	/**
	 * @description Verifies that a row with no matching candidate carries `null` for every
	 * recommendation field — the LWC shows the "review manually" copy and disables Add-to-bundle.
	 */
	@IsTest
	private static void describeFieldsLeavesRecommendationNullWhenNoCandidateMatches()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {SEL_MaskingRule.RULE_MASK_EMAIL => ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, true)};

		CTRL_MaskingAdvisor.DTO_FieldRow row = rowFor(CTRL_MaskingAdvisor.describeFields('Account'), Account.Phone);

		Assert.isNull(row.recommendedRuleDeveloperName, 'no candidate stem matches Phone so the recommendation is null');
		Assert.isNull(row.recommendedRuleLabel, 'the recommended-rule label stays null');
		Assert.isNull(row.recommendedRuleIsActive, 'the active flag stays null');
	}

	/**
	 * @description Verifies the field-name synonym map resolves address-shaped field names (street,
	 * postal code) to `MaskAddress` even though none of them contains the rule's `address` stem — the
	 * widened-matching path that closes the under-match for fields the substring-stem match misses.
	 */
	@IsTest
	private static void resolveRecommendedRuleMatchesAddressSynonyms()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_ADDRESS, false)};

		String street = CTRL_MaskingAdvisor.resolveRecommendedRule('MailingStreet', DisplayType.TEXTAREA, candidates)?.DeveloperName;
		String billing = CTRL_MaskingAdvisor.resolveRecommendedRule('BillingStreet', DisplayType.STRING, candidates)?.DeveloperName;
		String postal = CTRL_MaskingAdvisor.resolveRecommendedRule('MailingPostalCode', DisplayType.STRING, candidates)?.DeveloperName;

		Assert.areEqual(SEL_MaskingRule.RULE_MASK_ADDRESS, street, 'MailingStreet maps to MaskAddress via the street synonym');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_ADDRESS, billing, 'BillingStreet maps to MaskAddress via the street synonym');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_ADDRESS, postal, 'MailingPostalCode maps to MaskAddress via the postalcode synonym');
	}

	/**
	 * @description Verifies a `Fax` phone field resolves the international phone rule via the `fax` synonym —
	 * the field name carries no `phone` stem, so only the synonym map reaches the rule, and the fax/mobile/cell
	 * synonyms resolve to the same international primary as `phone`-named fields for cross-field consistency.
	 */
	@IsTest
	private static void resolveRecommendedRuleMatchesFaxToPhoneRuleViaSynonym()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL, false)};

		String fax = CTRL_MaskingAdvisor.resolveRecommendedRule('Fax', DisplayType.PHONE, candidates)?.DeveloperName;

		Assert.areEqual(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL, fax, 'Fax maps to the international phone rule via the fax synonym, consistent with phone-named fields');
	}

	/**
	 * @description Verifies the synonym lookup resolves to the framework's own rule, never a
	 * subscriber-authored rule that shares the developer name. With two `MaskAddress` rules in play — the
	 * package's own (no namespace, matching the running dev-org context) and a subscriber's (`acme`
	 * namespace) — `MailingStreet` resolves to the package-owned rule via the namespace-aware lookup.
	 */
	@IsTest
	private static void synonymResolvesPackageOwnedRuleNotSubscriberSameName()
	{
		MaskingRule__mdt ourRule = ruleWithName(SEL_MaskingRule.RULE_MASK_ADDRESS, false);
		ourRule.MasterLabel = 'Mask Postal Addresses';
		MaskingRule__mdt subscriberRule = subscriberOwnedAddressRule();
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				'packageOwned' => ourRule,
				'subscriberOwned' => subscriberRule
		};

		CTRL_MaskingAdvisor.DTO_FieldRow row = rowFor(CTRL_MaskingAdvisor.describeFields('Contact'), Contact.MailingStreet);

		Assert.areEqual(SEL_MaskingRule.RULE_MASK_ADDRESS, row.recommendedRuleDeveloperName, 'MailingStreet still resolves a MaskAddress rule via the synonym');
		Assert.areEqual('Mask Postal Addresses', row.recommendedRuleLabel, 'resolves the package-owned rule, not the subscriber same-name rule');
	}

	/**
	 * @description Verifies the namespace-ownership gate deterministically, independent of candidate
	 * iteration order: with the subscriber's same-named (`acme`) `MaskAddress` placed FIRST in the
	 * candidate list, the synonym still resolves the package-owned rule. Asserts the gate (not luck of
	 * map order) is what selects the framework's own rule — removing `isPackageOwnedRule` would let the
	 * first-listed subscriber rule win and fail this assertion every run.
	 */
	@IsTest
	private static void resolveRecommendedRulePrefersPackageOwnedRuleOverSubscriberSameName()
	{
		MaskingRule__mdt ourRule = ruleWithName(SEL_MaskingRule.RULE_MASK_ADDRESS, false);
		ourRule.MasterLabel = 'Mask Postal Addresses';
		MaskingRule__mdt subscriberRule = subscriberOwnedAddressRule();

		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {subscriberRule, ourRule};

		MaskingRule__mdt resolved = CTRL_MaskingAdvisor.resolveRecommendedRule('MailingStreet', DisplayType.STRING, candidates);

		Assert.isNotNull(resolved, 'the synonym resolves a MaskAddress rule for MailingStreet');
		Assert.areEqual('Mask Postal Addresses', resolved.MasterLabel, 'the package-owned rule is chosen even when the subscriber same-name rule iterates first');
	}

	/**
	 * @description Verifies the namespace-ownership comparison in both the unmanaged (blank package
	 * namespace) and managed (non-blank package namespace) contexts — the managed branch a no-namespace
	 * dev org never reaches at runtime — so a subscriber's differently-namespaced same-named rule is never
	 * treated as package-owned in either context.
	 */
	@IsTest
	private static void namespaceMatchesRunningPackageCoversManagedAndUnmanagedContexts()
	{
		Assert.isTrue(CTRL_MaskingAdvisor.namespaceMatchesRunningPackage('', ''), 'unmanaged: a blank-namespace rule is owned by the unmanaged package');
		Assert.isFalse(CTRL_MaskingAdvisor.namespaceMatchesRunningPackage('', 'acme'), 'unmanaged: a subscriber-namespaced rule is not package-owned');
		Assert.isTrue(CTRL_MaskingAdvisor.namespaceMatchesRunningPackage('kern', 'kern'), 'managed: a rule in the package namespace is owned');
		Assert.isFalse(CTRL_MaskingAdvisor.namespaceMatchesRunningPackage('kern', 'acme'), 'managed: a subscriber-namespaced same-name rule is not package-owned');
	}

	/**
	 * @description Verifies a candidate rule with a blank developer name (and therefore no stem) is
	 * skipped by the resolver rather than matching every field — the real rule still resolves. Guards the
	 * defensive blank-stem branch in the candidate loop.
	 */
	@IsTest
	private static void resolveRecommendedRuleSkipsCandidateWithBlankDeveloperName()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt>
		{
				ruleWithName('', true),
				ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, true)
		};

		MaskingRule__mdt resolved = CTRL_MaskingAdvisor.resolveRecommendedRule('Email', DisplayType.EMAIL, candidates);

		Assert.areEqual(SEL_MaskingRule.RULE_MASK_EMAIL, resolved.DeveloperName, 'a candidate with a blank developer name has no stem and is skipped; the real rule still resolves');
	}

	/**
	 * @description Verifies a synonym never fires on a non-recommendable type — a Boolean field whose
	 * name contains the `fax` synonym is type-gated before any synonym lookup runs.
	 */
	@IsTest
	private static void resolveRecommendedRuleSkipsSynonymOnNonRecommendableType()
	{
		List<MaskingRule__mdt> candidates = new List<MaskingRule__mdt> {ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, false)};

		Assert.isNull(CTRL_MaskingAdvisor.resolveRecommendedRule('FaxOptOut__c', DisplayType.BOOLEAN, candidates), 'a Boolean field is type-gated even though fax is a synonym');
	}

	/**
	 * @description Verifies `describeFields` recommends `MaskAddress` on a standard `MailingStreet`
	 * field via the synonym map — the under-match fix end-to-end through the analysis surface.
	 */
	@IsTest
	private static void describeFieldsRecommendsMaskAddressOnMailingStreetViaSynonym()
	{
		MaskingRule__mdt addressRule = ruleWithName(SEL_MaskingRule.RULE_MASK_ADDRESS, false);
		addressRule.MasterLabel = 'Mask Postal Addresses';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {SEL_MaskingRule.RULE_MASK_ADDRESS => addressRule};

		CTRL_MaskingAdvisor.DTO_FieldRow row = rowFor(CTRL_MaskingAdvisor.describeFields('Contact'), Contact.MailingStreet);

		Assert.isNotNull(row, 'the MailingStreet field row is present on Contact');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_ADDRESS, row.recommendedRuleDeveloperName, 'MailingStreet is recommended MaskAddress via the street synonym');
	}

	/**
	 * @description Verifies `describeFields` surfaces, per field, the developer names of every rule whose
	 * type scope admits the field's `DisplayType` — an unscoped rule applies to any text-shaped field,
	 * while a STRING/TEXTAREA-scoped rule applies to a TEXTAREA field but not an EMAIL field — and that
	 * the analysis carries a rule catalogue (label + category from rule metadata) for the picker.
	 */
	@IsTest
	private static void describeFieldsExposesApplicableRulesPerFieldAndCatalogue()
	{
		MaskingRule__mdt emailRule = ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, true);
		emailRule.MasterLabel = 'Mask Email Addresses';
		emailRule.Category__c = 'Contact';
		emailRule.Mode__c = 'Regex';
		MaskingRule__mdt cardRule = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		cardRule.MasterLabel = 'Mask Credit Card Numbers';
		cardRule.Category__c = 'Payment';
		cardRule.ApplicableFieldTypes__c = 'STRING;TEXTAREA;ENCRYPTEDSTRING';
		MaskingRule__mdt uncategorizedRule = ruleWithName('MaskTitle', false);
		uncategorizedRule.MasterLabel = 'Mask Titles';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_EMAIL => emailRule,
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => cardRule,
				'MaskTitle' => uncategorizedRule
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Assert.isNotNull(analysis.rules, 'the analysis carries the rule catalogue');
		Map<String, CTRL_MaskingAdvisor.DTO_RuleOption> optionByName = new Map<String, CTRL_MaskingAdvisor.DTO_RuleOption>();
		for(CTRL_MaskingAdvisor.DTO_RuleOption option : analysis.rules)
		{
			optionByName.put(option.developerName, option);
		}
		Assert.areEqual('Contact', optionByName.get(SEL_MaskingRule.RULE_MASK_EMAIL).category, 'the catalogue surfaces each rule category from the CMDT field');
		Assert.areEqual('Mask Email Addresses', optionByName.get(SEL_MaskingRule.RULE_MASK_EMAIL).label, 'the catalogue surfaces each rule label');
		Assert.isNull(optionByName.get('MaskTitle').category, 'an uncategorized rule (subscriber-created, or unpopulated on upgrade) surfaces a null category without breaking');

		CTRL_MaskingAdvisor.DTO_FieldRow emailRow = rowFor(analysis, Contact.Email);
		Assert.isTrue(emailRow.applicableRuleDeveloperNames.contains(SEL_MaskingRule.RULE_MASK_EMAIL), 'an unscoped rule applies to the EMAIL field');
		Assert.isFalse(emailRow.applicableRuleDeveloperNames.contains(SEL_MaskingRule.RULE_MASK_CREDIT_CARD), 'a STRING/TEXTAREA-scoped rule does not apply to an EMAIL field');

		CTRL_MaskingAdvisor.DTO_FieldRow descriptionRow = rowFor(analysis, Contact.Description);
		Assert.isTrue(descriptionRow.applicableRuleDeveloperNames.contains(SEL_MaskingRule.RULE_MASK_CREDIT_CARD), 'a STRING/TEXTAREA-scoped rule applies to a TEXTAREA field');
		Assert.isTrue(descriptionRow.applicableRuleDeveloperNames.contains(SEL_MaskingRule.RULE_MASK_EMAIL), 'an unscoped rule also applies to a TEXTAREA field');
	}

	/**
	 * @description Verifies `describeFields` drops a superseded rule from the catalogue and the
	 * recommendation candidates: when an untuned active successor names an untuned predecessor (the
	 * supersession verdict passes), the predecessor would only duplicate the successor in the picker,
	 * so the catalogue carries the successor alone.
	 */
	@IsTest
	private static void describeFieldsExcludesSupersededRuleFromCatalogue()
	{
		MaskingRule__mdt predecessor = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		MaskingRule__mdt successor = successorOf(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, predecessor);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => predecessor,
				SEL_MaskingRule.RULE_MASK_PAYMENT_CARD => successor
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Set<String> catalogueNames = new Set<String>();
		for(CTRL_MaskingAdvisor.DTO_RuleOption option : analysis.rules)
		{
			catalogueNames.add(option.developerName);
		}
		Assert.isTrue(catalogueNames.contains(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD), 'the successor stays in the catalogue');
		Assert.isFalse(catalogueNames.contains(SEL_MaskingRule.RULE_MASK_CREDIT_CARD), 'the superseded predecessor is dropped from the catalogue');
	}

	/**
	 * @description Verifies a named-but-not-superseded predecessor stays in the catalogue and carries the
	 * supersession annotation: when either generation is tuned the verdict fails (the predecessor still
	 * masks, so hiding it would misstate the configuration), but the successor still NAMES it via
	 * `Replaces__c`, so the admin is steered to the successor by label. The successor itself is never
	 * annotated.
	 */
	@IsTest
	private static void describeFieldsAnnotatesTunedPredecessorInCatalogue()
	{
		MaskingRule__mdt predecessor = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		MaskingRule__mdt successor = successorOf(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, predecessor);
		successor.MasterLabel = 'Mask Payment Card Numbers';
		successor.ReplacesFingerprint__c = 'predecessor-tuned-away';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => predecessor,
				SEL_MaskingRule.RULE_MASK_PAYMENT_CARD => successor
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Map<String, CTRL_MaskingAdvisor.DTO_RuleOption> optionByName = optionsByName(analysis);
		Assert.isTrue(optionByName.containsKey(SEL_MaskingRule.RULE_MASK_CREDIT_CARD), 'a tuned predecessor is annotated, never hidden');
		Assert.isNotNull(optionByName.get(SEL_MaskingRule.RULE_MASK_CREDIT_CARD).supersededByLabel, 'the predecessor option carries the supersession annotation');
		Assert.isTrue(optionByName.get(SEL_MaskingRule.RULE_MASK_CREDIT_CARD).supersededByLabel.contains('Mask Payment Card Numbers'), 'the annotation names the successor by label');
		Assert.isNull(optionByName.get(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD).supersededByLabel, 'the successor option is never annotated');
	}

	/**
	 * @description Verifies the annotation tolerates a case-mismatched `Replaces__c`: platform developer
	 * names are case-insensitive (the verdict engine pairs them with ==), so the annotation map hop must
	 * not silently miss when an org-local successor types the predecessor's name in a different case —
	 * in the tuned-predecessor state, the exact state the annotation exists for.
	 */
	@IsTest
	private static void describeFieldsAnnotatesPredecessorNamedWithDifferentCase()
	{
		MaskingRule__mdt predecessor = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		MaskingRule__mdt successor = successorOf(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, predecessor);
		successor.MasterLabel = 'Mask Payment Card Numbers';
		successor.Replaces__c = SEL_MaskingRule.RULE_MASK_CREDIT_CARD.toLowerCase();
		successor.ReplacesFingerprint__c = 'predecessor-tuned-away';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => predecessor,
				SEL_MaskingRule.RULE_MASK_PAYMENT_CARD => successor
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Assert.isNotNull
				(
						optionsByName(analysis).get(SEL_MaskingRule.RULE_MASK_CREDIT_CARD).supersededByLabel,
						'a case-mismatched Replaces__c still annotates the predecessor — names are case-insensitive on platform'
				);
	}

	/**
	 * @description Verifies the catalogue filter keys the verdict set with namespace-QUALIFIED names in
	 * every org context. Blank-prefix fixtures cannot pin this (qualified and bare keying coincide in
	 * the unmanaged dev org), so a fully foreign-prefixed qualifying pair is used: the verdict set then
	 * carries `acme.`-qualified names and a bare-DeveloperName filter keying would fail this test in
	 * every context — the resume-doc trap for this task.
	 */
	@IsTest
	private static void describeFieldsExcludesSupersededRuleUnderForeignNamespacePrefix()
	{
		MaskingRule__mdt predecessor = prefixedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, 'acme', null);
		MaskingRule__mdt successor = prefixedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, 'acme', SEL_MaskingRule.RULE_MASK_CREDIT_CARD);
		successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => predecessor,
				SEL_MaskingRule.RULE_MASK_PAYMENT_CARD => successor
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Map<String, CTRL_MaskingAdvisor.DTO_RuleOption> optionByName = optionsByName(analysis);
		Assert.isFalse(optionByName.containsKey(SEL_MaskingRule.RULE_MASK_CREDIT_CARD), 'the foreign-prefixed superseded predecessor is dropped — the filter keys qualified names');
		Assert.isTrue(optionByName.containsKey(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD), 'the foreign-prefixed successor stays in the catalogue');
	}

	/**
	 * @description Verifies applied rows bound to a superseded rule are annotated, never filtered: the
	 * field target and the object-wide target both still surface (their bindings actively mask until the
	 * admin rebinds them), each carrying the supersession annotation that names the successor.
	 */
	@IsTest
	private static void describeFieldsAnnotatesAppliedRowsBoundToSupersededRule()
	{
		MaskingRule__mdt predecessor = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		predecessor.MasterLabel = 'Mask Credit Card Numbers';
		MaskingRule__mdt successor = successorOf(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, predecessor);
		successor.MasterLabel = 'Mask Payment Card Numbers';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => predecessor,
				SEL_MaskingRule.RULE_MASK_PAYMENT_CARD => successor
		};
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>
		{
				appliedTarget('MaskAccountPhoneCard', 'Account', 'Account.Phone', true, predecessor),
				appliedTarget('MaskAccountWideCard', 'Account', null, true, predecessor)
		});

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');

		CTRL_MaskingAdvisor.DTO_AppliedRule fieldApplied = appliedRuleByTarget(rowFor(analysis, Account.Phone).appliedRules, 'MaskAccountPhoneCard');
		Assert.isNotNull(fieldApplied, 'a field target bound to a superseded rule still surfaces');
		Assert.isNotNull(fieldApplied.supersededByLabel, 'the field-bound applied row carries the supersession annotation');
		Assert.isTrue(fieldApplied.supersededByLabel.contains('Mask Payment Card Numbers'), 'the applied-row annotation names the successor by label');

		CTRL_MaskingAdvisor.DTO_AppliedRule objectWideApplied = appliedRuleByTarget(analysis.objectWideRules, 'MaskAccountWideCard');
		Assert.isNotNull(objectWideApplied, 'an object-wide target bound to a superseded rule still surfaces');
		Assert.isNotNull(objectWideApplied.supersededByLabel, 'the object-wide applied row carries the supersession annotation');
	}

	/**
	 * @description Verifies the annotation is namespace-scoped: a foreign-namespace successor naming the
	 * packaged rule's DeveloperName via `Replaces__c` never annotates the packaged rule — cross-namespace
	 * supersession is never legal, so the named rule is keyed under the namer's own prefix.
	 */
	@IsTest
	private static void describeFieldsDoesNotAnnotateAcrossNamespaces()
	{
		MaskingRule__mdt packagedRule = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		MaskingRule__mdt foreignSuccessor = (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, SEL_MaskingRule.RULE_MASK_PAYMENT_CARD)
				.withOverride(MaskingRule__mdt.MasterLabel, 'Subscriber Payment Rule')
				.withOverride(MaskingRule__mdt.NamespacePrefix, 'acme')
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withOverride(MaskingRule__mdt.Replaces__c, SEL_MaskingRule.RULE_MASK_CREDIT_CARD)
				.withoutInsertion(true)
				.build();
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => packagedRule,
				SEL_MaskingRule.RULE_MASK_PAYMENT_CARD => foreignSuccessor
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Assert.isNull
				(
						optionsByName(analysis).get(SEL_MaskingRule.RULE_MASK_CREDIT_CARD).supersededByLabel,
						'a foreign-namespace successor naming the same DeveloperName never annotates the packaged rule'
				);
	}

	/**
	 * @description Verifies a rule naming itself via `Replaces__c` is never annotated — mirroring the
	 * verdict engine's self-supersession guard, so a misconfigured record cannot label itself superseded.
	 */
	@IsTest
	private static void describeFieldsDoesNotAnnotateSelfReplacingRule()
	{
		MaskingRule__mdt selfReplacer = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		selfReplacer.Replaces__c = SEL_MaskingRule.RULE_MASK_CREDIT_CARD;
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {SEL_MaskingRule.RULE_MASK_CREDIT_CARD => selfReplacer};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Assert.isNull
				(
						optionsByName(analysis).get(SEL_MaskingRule.RULE_MASK_CREDIT_CARD).supersededByLabel,
						'a rule naming itself via Replaces__c is never annotated as superseded by itself'
				);
	}

	/**
	 * @description Verifies `describeFields` computes the match-strength band per the pinned decision
	 * table: a direct or alias stem match on a reinforcing type (EMAIL/PHONE) is Strong, a stem match on
	 * a generic STRING type is Moderate, a synonym match is Moderate, and a field with no rule match is
	 * Weak. Also confirms an email-typed email-named field is PII.
	 */
	@IsTest
	private static void describeFieldsComputesMatchStrengthBand()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_EMAIL => ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, false),
				SEL_MaskingRule.RULE_MASK_PHONE_US => ruleWithName(SEL_MaskingRule.RULE_MASK_PHONE_US, false),
				'MaskTitle' => ruleWithName('MaskTitle', false),
				SEL_MaskingRule.RULE_MASK_ADDRESS => ruleWithName(SEL_MaskingRule.RULE_MASK_ADDRESS, false)
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Assert.areEqual('Strong', rowFor(analysis, Contact.Email).matchStrength, 'direct stem on reinforcing EMAIL type is Strong');
		Assert.areEqual('Strong', rowFor(analysis, Contact.HomePhone).matchStrength, 'alias stem on reinforcing PHONE type is Strong');
		Assert.areEqual('Moderate', rowFor(analysis, Contact.Title).matchStrength, 'direct stem on generic STRING type is Moderate');
		Assert.areEqual('Moderate', rowFor(analysis, Contact.MailingStreet).matchStrength, 'a synonym match is Moderate');
		Assert.areEqual('Weak', rowFor(analysis, Contact.Department).matchStrength, 'no rule match is Weak');
		Assert.areEqual('Sensitive', rowFor(analysis, Contact.Email).sensitivityLevel, 'email-typed email-named field is Sensitive');
		Assert.areEqual('PossiblySensitive', rowFor(analysis, Contact.MailingStreet).sensitivityLevel, 'recommended-but-unflagged is PossiblySensitive, never NotSensitive');
		Assert.areEqual('NotSensitive', rowFor(analysis, Contact.Department).sensitivityLevel, 'no rule and no heuristic is NotSensitive');
		Assert.isFalse(rowFor(analysis, Contact.Department).likelyMiss, 'a NotSensitive plain-text field is not flagged as a likely miss');
	}

	/**
	 * @description Verifies the sensitivity-level mapping: a native classification or a HIGH heuristic is
	 * Sensitive; a MEDIUM/LOW heuristic, or any recommended field with no heuristic signal, is
	 * PossiblySensitive (recommending masking is itself a signal, so a recommended field is never
	 * NotSensitive); a field with no signal and no recommendation is NotSensitive.
	 */
	@IsTest
	private static void sensitivityLevelMapsHeuristicTierClassificationAndRecommendation()
	{
		CTRL_MaskingAdvisor.HeuristicConfidence high = CTRL_MaskingAdvisor.HeuristicConfidence.HIGH;
		CTRL_MaskingAdvisor.HeuristicConfidence medium = CTRL_MaskingAdvisor.HeuristicConfidence.MEDIUM;
		CTRL_MaskingAdvisor.HeuristicConfidence low = CTRL_MaskingAdvisor.HeuristicConfidence.LOW;

		Assert.areEqual('Sensitive', CTRL_MaskingAdvisor.resolveSensitivityLevel(false, high, false), 'HIGH heuristic -> Sensitive');
		Assert.areEqual('PossiblySensitive', CTRL_MaskingAdvisor.resolveSensitivityLevel(false, medium, false), 'MEDIUM heuristic -> PossiblySensitive');
		Assert.areEqual('PossiblySensitive', CTRL_MaskingAdvisor.resolveSensitivityLevel(false, low, false), 'LOW heuristic -> PossiblySensitive (still a flag)');
		Assert.areEqual('NotSensitive', CTRL_MaskingAdvisor.resolveSensitivityLevel(false, null, false), 'no signal, no recommendation -> NotSensitive');
		Assert.areEqual('Sensitive', CTRL_MaskingAdvisor.resolveSensitivityLevel(true, null, false), 'native classification -> Sensitive');
		Assert.areEqual
				(
						'PossiblySensitive',
						CTRL_MaskingAdvisor.resolveSensitivityLevel(false, null, true),
						'recommended but no heuristic -> PossiblySensitive (never NotSensitive)'
				);
	}

	/**
	 * @description Verifies the likely-miss flag: a NotSensitive field whose type structurally signals
	 * sensitivity (the type-reinforcing EMAIL/PHONE/URL/ENCRYPTEDSTRING set) is a likely miss worth a
	 * second look; a NotSensitive plain-text field is not; and an already-surfaced Sensitive or
	 * PossiblySensitive field is never a miss regardless of type.
	 */
	@IsTest
	private static void likelyMissFlagsNotSensitiveTypeReinforcingFields()
	{
		Assert.isTrue(CTRL_MaskingAdvisor.likelyMiss('NotSensitive', DisplayType.URL), 'NotSensitive URL field is a likely miss');
		Assert.isTrue(CTRL_MaskingAdvisor.likelyMiss('NotSensitive', DisplayType.ENCRYPTEDSTRING), 'NotSensitive encrypted field is a likely miss');
		Assert.isFalse(CTRL_MaskingAdvisor.likelyMiss('NotSensitive', DisplayType.STRING), 'NotSensitive plain text is not a likely miss');
		Assert.isFalse(CTRL_MaskingAdvisor.likelyMiss('NotSensitive', DisplayType.TEXTAREA), 'NotSensitive long text is not a likely miss');
		Assert.isFalse(CTRL_MaskingAdvisor.likelyMiss('Sensitive', DisplayType.URL), 'an already-Sensitive field is surfaced, not a miss');
		Assert.isFalse(CTRL_MaskingAdvisor.likelyMiss('PossiblySensitive', DisplayType.EMAIL), 'a PossiblySensitive field is surfaced, not a miss');
	}

	/**
	 * @description Verifies the type→synthetic-example map returns a representative input only for the
	 * well-defined-shape recommendable types (EMAIL/PHONE/URL) and null for the undefined-shape text
	 * types (STRING/TEXTAREA/ENCRYPTEDSTRING) and any non-recommendable type — so the advisor only
	 * auto-shows an inline example where a single synthetic value is self-evidently correct.
	 */
	@IsTest
	private static void exampleInputForTypeReturnsSyntheticValueForWellDefinedShapesOnly()
	{
		Assert.areEqual('jane@example.com', CTRL_MaskingAdvisor.exampleInputForType(DisplayType.EMAIL), 'an EMAIL field gets the synthetic email example');
		Assert.areEqual('+1 (555) 015-0100', CTRL_MaskingAdvisor.exampleInputForType(DisplayType.PHONE), 'a PHONE field gets the synthetic US phone example');
		Assert.areEqual('https://user:pass@example.com/account', CTRL_MaskingAdvisor.exampleInputForType(DisplayType.URL), 'a URL field gets the synthetic basic-auth URL example');
		Assert.isNull(CTRL_MaskingAdvisor.exampleInputForType(DisplayType.STRING), 'a STRING field has no single representative shape');
		Assert.isNull(CTRL_MaskingAdvisor.exampleInputForType(DisplayType.TEXTAREA), 'a TEXTAREA field has no single representative shape');
		Assert.isNull(CTRL_MaskingAdvisor.exampleInputForType(DisplayType.ENCRYPTEDSTRING), 'an ENCRYPTEDSTRING field can hold any shape, so it routes to Try a value');
		Assert.isNull(CTRL_MaskingAdvisor.exampleInputForType(DisplayType.CURRENCY), 'a non-recommendable type gets no synthetic example');
	}

	/**
	 * @description Verifies `describeFields` precomputes the inline before→after example for a recommended
	 * EMAIL field: the synthetic email input and the engine's true masking of it under the recommended
	 * rule, computed server-side so the console needs no client call or JS regex for the default example.
	 */
	@IsTest
	private static void describeFieldsPrecomputesInlineExampleForRecommendedEmailField()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_EMAIL => regexRule(SEL_MaskingRule.RULE_MASK_EMAIL, false, '\\S+@\\S+\\.\\S+', '[EMAIL_REDACTED]')
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		CTRL_MaskingAdvisor.DTO_FieldRow emailRow = rowFor(analysis, Contact.Email);
		Assert.areEqual('jane@example.com', emailRow.exampleInput, 'the EMAIL field carries the synthetic email input');
		Assert.areEqual('[EMAIL_REDACTED]', emailRow.exampleOutput, 'the example output is the engine masking of the synthetic input under the recommended rule');
		Assert.areNotEqual(emailRow.exampleInput, emailRow.exampleOutput, 'a recommended rule that fires transforms the example');
	}

	/**
	 * @description Verifies the precomputed example for a recommended PHONE field is the engine's
	 * redaction of the synthetic US phone number — the high-value transforming demo the console shows
	 * inline without a round-trip.
	 */
	@IsTest
	private static void describeFieldsPrecomputesRedactionExampleForRecommendedPhoneField()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_PHONE_US => regexRule(SEL_MaskingRule.RULE_MASK_PHONE_US, false, '[-+() 0-9]{10,}', '[PHONE_REDACTED]')
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		CTRL_MaskingAdvisor.DTO_FieldRow phoneRow = rowFor(analysis, Contact.HomePhone);
		Assert.areEqual('+1 (555) 015-0100', phoneRow.exampleInput, 'the PHONE field carries the synthetic US phone input');
		Assert.areEqual('[PHONE_REDACTED]', phoneRow.exampleOutput, 'the phone rule redacts the synthetic phone to the redaction token');
	}

	/**
	 * @description Verifies the precomputed example for a recommended URL field is the engine's redaction
	 * of the synthetic basic-auth URL — confirming the type→sample→engine path works for URL-shaped fields.
	 */
	@IsTest
	private static void describeFieldsPrecomputesRedactionExampleForRecommendedUrlField()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				'MaskWebsite' => regexRule('MaskWebsite', false, 'https?://\\S+', '[URL_REDACTED]')
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');

		CTRL_MaskingAdvisor.DTO_FieldRow websiteRow = rowFor(analysis, Account.Website);
		Assert.areEqual('https://user:pass@example.com/account', websiteRow.exampleInput, 'the URL field carries the synthetic basic-auth URL input');
		Assert.areEqual('[URL_REDACTED]', websiteRow.exampleOutput, 'the URL rule redacts the synthetic URL to the redaction token');
	}

	/**
	 * @description Verifies `describeFields` leaves both example fields null for an undefined-shape
	 * recommendable type — no single synthetic value represents free text, so a STRING/TEXTAREA row routes
	 * to Try a value instead of a fabricated example, even when a rule is recommended on it.
	 */
	@IsTest
	private static void describeFieldsLeavesInlineExampleNullForUndefinedShapeType()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				'MaskDescription' => regexRule('MaskDescription', false, '.+', '[REDACTED]')
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		CTRL_MaskingAdvisor.DTO_FieldRow descriptionRow = rowFor(analysis, Contact.Description);
		Assert.isNull(descriptionRow.exampleInput, 'a TEXTAREA field has no synthetic example input');
		Assert.isNull(descriptionRow.exampleOutput, 'with no example input there is no example output, even when a rule is recommended');

		CTRL_MaskingAdvisor.DTO_FieldRow titleRow = rowFor(analysis, Contact.Title);
		Assert.isNull(titleRow.exampleInput, 'a STRING field has no synthetic example input');
		Assert.isNull(titleRow.exampleOutput, 'a STRING field carries no example output');
	}

	/**
	 * @description Verifies a recommendable well-defined-shape field with no recommended rule carries the
	 * synthetic example input but a null example output — there is a representative value to show, but no
	 * rule to transform it, so the console renders Try a value rather than a before→after.
	 */
	@IsTest
	private static void describeFieldsSetsExampleInputButNullOutputWhenNoRuleRecommended()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>();

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		CTRL_MaskingAdvisor.DTO_FieldRow emailRow = rowFor(analysis, Contact.Email);
		Assert.areEqual('jane@example.com', emailRow.exampleInput, 'the EMAIL field still carries the synthetic input from its type');
		Assert.isNull(emailRow.exampleOutput, 'with no recommended rule there is nothing to transform, so the output is null');
	}

	/**
	 * @description Verifies `describeFields` surfaces, per field, every masking target wired to that field —
	 * active **and** inactive — as `appliedRules`, so the console can render existing coverage and offer a
	 * disable / re-enable diff. The active and inactive field targets on `Account.Phone` both surface with
	 * their target developer name, the target's own active state, the resolved rule label, and the preserved
	 * caller-class. Rule metadata resolves through `getAllRulesById` (the override seam here).
	 */
	@IsTest
	private static void describeFieldsReturnsAppliedRulesIncludingInactiveFieldTargets()
	{
		MaskingRule__mdt cardRule = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		cardRule.MasterLabel = 'Mask Credit Card Numbers';
		MaskingRule__mdt secretRule = ruleWithName(SEL_MaskingRule.RULE_MASK_SECRET_KEYS, true);
		secretRule.MasterLabel = 'Mask Secret Keys';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => cardRule,
				SEL_MaskingRule.RULE_MASK_SECRET_KEYS => secretRule
		};
		MaskingTarget__mdt activeTarget = appliedTarget('MaskAccountPhoneCard', 'Account', 'Account.Phone', true, cardRule);
		activeTarget.CallerClass__c = 'SVC_Billing';
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>
		{
				activeTarget,
				appliedTarget('MaskAccountPhoneSecret', 'Account', 'Account.Phone', false, secretRule)
		});

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');
		CTRL_MaskingAdvisor.DTO_FieldRow phoneRow = rowFor(analysis, Account.Phone);

		Assert.areEqual(2, phoneRow.appliedRules.size(), 'both the active and inactive field targets surface as applied rules');
		CTRL_MaskingAdvisor.DTO_AppliedRule activeApplied = appliedRuleByTarget(phoneRow.appliedRules, 'MaskAccountPhoneCard');
		CTRL_MaskingAdvisor.DTO_AppliedRule inactiveApplied = appliedRuleByTarget(phoneRow.appliedRules, 'MaskAccountPhoneSecret');
		Assert.isTrue(activeApplied.isActive, 'the active target is surfaced as active');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, activeApplied.ruleDeveloperName, 'the applied rule developer name is resolved');
		Assert.areEqual('Mask Credit Card Numbers', activeApplied.ruleLabel, 'the applied rule label is resolved');
		Assert.areEqual('SVC_Billing', activeApplied.callerClass, 'the target caller-class scope is preserved for re-emit');
		Assert.areEqual(true, activeApplied.ruleIsActive, 'the bound rule own active state travels with the applied row');
		Assert.isFalse(inactiveApplied.isActive, 'the inactive target is surfaced as inactive so the advisor can offer re-enable');
		Assert.areEqual('Mask Secret Keys', inactiveApplied.ruleLabel, 'the inactive applied rule label is resolved');
		Assert.areEqual(true, inactiveApplied.ruleIsActive, 'ruleIsActive is the rule own IsActive__c, not the target state — the console must not style an active rule inactive');
	}

	/**
	 * @description Verifies applied-rule metadata resolves through `getRuleById` — the selector's
	 * transaction rule cache, primed from the mock target's `Rule__r` — and that a target whose rule cannot
	 * be resolved still surfaces, carrying the target developer name and active state, with null rule
	 * metadata so the configuration-health surfacing can flag it without the chip renderer throwing. The
	 * orphan (null-rule) target is registered **first** deliberately: `getRuleById` short-circuits on a null
	 * Id, so resolving it never disturbs the cache before the second target's rule resolves.
	 */
	@IsTest
	private static void describeFieldsAppliedRuleResolvesViaSidecarAndToleratesUnresolvableRule()
	{
		MaskingRule__mdt cardRule = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		cardRule.MasterLabel = 'Mask Credit Card Numbers';
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>
		{
				appliedTarget('MaskAccountFaxOrphan', 'Account', 'Account.Fax', true, null),
				appliedTarget('MaskAccountPhoneSidecar', 'Account', 'Account.Phone', true, cardRule)
		});

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');

		CTRL_MaskingAdvisor.DTO_AppliedRule sidecarApplied = appliedRuleByTarget(rowFor(analysis, Account.Phone).appliedRules, 'MaskAccountPhoneSidecar');
		Assert.areEqual(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, sidecarApplied.ruleDeveloperName, 'the rule developer name resolves via the mock-primed rule cache');
		Assert.areEqual('Mask Credit Card Numbers', sidecarApplied.ruleLabel, 'the rule label resolves even though the orphan target was processed first');

		CTRL_MaskingAdvisor.DTO_AppliedRule orphanApplied = appliedRuleByTarget(rowFor(analysis, Account.Fax).appliedRules, 'MaskAccountFaxOrphan');
		Assert.isNull(orphanApplied.ruleDeveloperName, 'a target whose rule cannot be resolved surfaces with null rule metadata');
		Assert.isTrue(orphanApplied.isActive, 'the target itself is still surfaced as active');
	}

	/**
	 * @description Verifies `describeFields` surfaces the object's object-wide masking targets (Field__c
	 * blank), active and inactive, as `objectWideRules` on the analysis, and resolves an absolute
	 * `newRuleSetupUrl` — rooted at the org domain (the Health Check pattern) with the dynamically-resolved
	 * `MaskingRule__mdt` key prefix (never a hardcoded prefix) and namespace-aware object name — pointing at
	 * the New-Masking-Rule Setup page.
	 */
	@IsTest
	private static void describeFieldsExposesObjectWideRulesAndNewRuleSetupUrl()
	{
		MaskingRule__mdt cardRule = ruleWithName(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true);
		cardRule.MasterLabel = 'Mask Credit Card Numbers';
		MaskingRule__mdt secretRule = ruleWithName(SEL_MaskingRule.RULE_MASK_SECRET_KEYS, true);
		secretRule.MasterLabel = 'Mask Secret Keys';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_CREDIT_CARD => cardRule,
				SEL_MaskingRule.RULE_MASK_SECRET_KEYS => secretRule
		};
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>
		{
				appliedTarget('MaskAccountWideCard', 'Account', null, true, cardRule),
				appliedTarget('MaskAccountWideCardTwo', 'Account', null, true, cardRule),
				appliedTarget('MaskAccountWideSecret', 'Account', null, false, secretRule)
		});

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Account');

		Assert.areEqual(3, analysis.objectWideRules.size(), 'all object-wide targets (active and inactive) surface');
		Integer activeWideCount = 0;
		for(CTRL_MaskingAdvisor.DTO_AppliedRule applied : analysis.objectWideRules)
		{
			if(applied.isActive == true)
			{
				activeWideCount += 1;
			}
		}
		Assert.areEqual(2, activeWideCount, 'two of the three object-wide targets are active');

		String keyPrefix = UTIL_SObjectDescribe.getDescribe(MaskingRule__mdt.SObjectType).getDescribe().keyPrefix;
		Assert.isTrue(String.isNotBlank(analysis.newRuleSetupUrl), 'the analysis carries the new-rule setup url');
		Assert.isTrue(analysis.newRuleSetupUrl.startsWith(Url.getOrgDomainUrl().toExternalForm()), 'the setup url is absolute, rooted at the org domain like the health check');
		Assert.isTrue(analysis.newRuleSetupUrl.contains(keyPrefix), 'the setup url embeds the dynamically resolved MaskingRule key prefix');
		Assert.isTrue(analysis.newRuleSetupUrl.contains('sObjectName%3D' + SEL_MaskingRule.OBJECT_NAME), 'the setup url targets the MaskingRule metadata type');
	}

	/**
	 * @description Verifies the rule catalogue carries each rule's applicable field types — a scoped rule
	 * lists its `ApplicableFieldTypes__c` split, trimmed, and upper-cased, while an unscoped (blank) rule
	 * lists an empty collection meaning it applies to any text-shaped field.
	 */
	@IsTest
	private static void describeFieldsRuleCatalogueCarriesApplicableFieldTypes()
	{
		MaskingRule__mdt scopedRule = ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, true);
		scopedRule.MasterLabel = 'Mask Email Addresses';
		scopedRule.ApplicableFieldTypes__c = 'EMAIL;PHONE';
		MaskingRule__mdt unscopedRule = ruleWithName('MaskTitle', true);
		unscopedRule.MasterLabel = 'Mask Titles';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_EMAIL => scopedRule,
				'MaskTitle' => unscopedRule
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Map<String, CTRL_MaskingAdvisor.DTO_RuleOption> optionByName = new Map<String, CTRL_MaskingAdvisor.DTO_RuleOption>();
		for(CTRL_MaskingAdvisor.DTO_RuleOption option : analysis.rules)
		{
			optionByName.put(option.developerName, option);
		}
		Assert.areEqual
				(
						new List<String> {DisplayType.EMAIL.name(), DisplayType.PHONE.name()},
						optionByName.get(SEL_MaskingRule.RULE_MASK_EMAIL).applicableFieldTypes,
						'a scoped rule lists its applicable field types upper-cased'
				);
		Assert.isTrue(optionByName.get('MaskTitle').applicableFieldTypes.isEmpty(), 'an unscoped rule lists no applicable field types (applies to all text-shaped)');
	}

	/**
	 * @description Verifies the rule catalogue carries each rule's description from its CMDT
	 * `Description__c` so the rule-detail popup can show "what it masks", and that a rule with no
	 * description surfaces a null without breaking.
	 */
	@IsTest
	private static void describeFieldsRuleCatalogueCarriesDescription()
	{
		MaskingRule__mdt describedRule = ruleWithName(SEL_MaskingRule.RULE_MASK_EMAIL, true);
		describedRule.MasterLabel = 'Mask Email Addresses';
		describedRule.Description__c = 'Redacts the local-part of an email address while preserving the domain.';
		MaskingRule__mdt blankRule = ruleWithName('MaskTitle', true);
		blankRule.MasterLabel = 'Mask Titles';
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				SEL_MaskingRule.RULE_MASK_EMAIL => describedRule,
				'MaskTitle' => blankRule
		};

		CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis = CTRL_MaskingAdvisor.describeFields('Contact');

		Map<String, CTRL_MaskingAdvisor.DTO_RuleOption> optionByName = new Map<String, CTRL_MaskingAdvisor.DTO_RuleOption>();
		for(CTRL_MaskingAdvisor.DTO_RuleOption option : analysis.rules)
		{
			optionByName.put(option.developerName, option);
		}
		Assert.areEqual
				(
						'Redacts the local-part of an email address while preserving the domain.',
						optionByName.get(SEL_MaskingRule.RULE_MASK_EMAIL).description,
						'the catalogue surfaces each rule description from the CMDT field'
				);
		Assert.isNull(optionByName.get('MaskTitle').description, 'a rule with no description surfaces a null description without breaking');
	}

	/**
	 * @description Verifies a target decision flagged inactive emits a disabled `MaskingTarget__mdt`
	 * (`IsActive__c = false`) — the disable half of the diff package an admin deploys to turn masking off
	 * for a field without deleting the target.
	 */
	@IsTest
	private static void generateConfigurationEmitsDisabledTargetWhenDecisionInactive()
	{
		CTRL_MaskingAdvisor.DTO_TargetDecision decision = targetDecision('MaskAccountPhoneDisable', 'Disable Account Phone', 'MaskPhone', 'Account', 'Phone', '');
		decision.isActive = false;

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(requestWith(decision, new List<String>()));

		String targetFile = bundle.files.get(targetBundlePath('MaskAccountPhoneDisable'));
		Assert.isTrue(targetFile.contains(fieldRow(SEL_MaskingTarget.FIELD_IS_ACTIVE)), 'the IsActive__c row is rendered');
		Assert.isTrue(targetFile.contains('xsi:type="xsd:boolean">false</value>'), 'an inactive decision emits a disabled target');
	}

	/**
	 * @description Verifies a target decision with a null `isActive` defaults to an active target — the
	 * create / re-enable case stays active, so only an explicit `false` disables. Guards that the diff
	 * default is active, not a compatibility accident.
	 */
	@IsTest
	private static void generateConfigurationDefaultsTargetActiveWhenIsActiveNull()
	{
		CTRL_MaskingAdvisor.DTO_TargetDecision decision = targetDecision('MaskAccountPhoneDefault', 'Default Account Phone', 'MaskPhone', 'Account', 'Phone', '');

		CTRL_MaskingAdvisor.DTO_Bundle bundle = CTRL_MaskingAdvisor.generateConfiguration(requestWith(decision, new List<String>()));

		String targetFile = bundle.files.get(targetBundlePath('MaskAccountPhoneDefault'));
		Assert.isTrue(targetFile.contains('xsi:type="xsd:boolean">true</value>'), 'a null isActive defaults the target active');
	}

	/**
	 * @description Builds a named in-memory `MaskingRule__mdt` via TST_Factory so resolver tests can
	 * exercise the substring-matching contract without seeding shipped configuration. The fixture is
	 * stamped with the running package namespace so the package-ownership gate
	 * (`namespaceMatchesRunningPackage`) treats it as a framework-owned rule in both the unmanaged dev
	 * org (blank namespace) and the managed subscriber context (`kern`) — mirroring the `NamespacePrefix`
	 * real packaged rules carry once installed. Without it the gate filters the fixture out under a
	 * managed namespace and the synonym path resolves to null.
	 *
	 * @param developerName The rule developer name.
	 * @param active Whether the rule is active.
	 *
	 * @return The in-memory, package-owned rule with the given name and active flag.
	 */
	private static MaskingRule__mdt ruleWithName(String developerName, Boolean active)
	{
		return TST_Factory.newMaskingRule(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => developerName,
				MaskingRule__mdt.IsActive__c => active,
				MaskingRule__mdt.NamespacePrefix => UTIL_System.getManagedPackageNamespace()
		});
	}

	/**
	 * @description Builds the in-memory active successor of the given predecessor: names it via
	 * `Replaces__c` in the package's own namespace and carries both qualifying fingerprints (the
	 * predecessor's live fingerprint as `ReplacesFingerprint__c`, its own as `ShippedFingerprint__c`),
	 * so the supersession verdict passes. A test needing a non-qualifying pair overwrites a
	 * fingerprint after building.
	 *
	 * @param developerName The successor rule developer name.
	 * @param predecessor The predecessor rule the successor replaces.
	 *
	 * @return The in-memory qualifying successor rule.
	 */
	private static MaskingRule__mdt successorOf(String developerName, MaskingRule__mdt predecessor)
	{
		MaskingRule__mdt successor = ruleWithName(developerName, true);
		successor.Replaces__c = predecessor.DeveloperName;
		successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);
		return successor;
	}

	/**
	 * @description Builds an in-memory active rule under an explicit foreign namespace prefix — the
	 * shape the qualified-keying pins need, because blank-prefix fixtures cannot distinguish qualified
	 * from bare keying. Built through `TST_Builder` (the scenario sets `NamespacePrefix`) and left
	 * uninserted since custom metadata cannot be DML-inserted.
	 *
	 * @param developerName The rule developer name.
	 * @param namespacePrefix The foreign namespace prefix.
	 * @param replaces The predecessor developer name the rule replaces, or null.
	 *
	 * @return The in-memory prefixed rule.
	 */
	private static MaskingRule__mdt prefixedRule(String developerName, String namespacePrefix, String replaces)
	{
		TST_Builder.Builder builder = TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, developerName)
				.withOverride(MaskingRule__mdt.MasterLabel, developerName)
				.withOverride(MaskingRule__mdt.NamespacePrefix, namespacePrefix)
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withoutInsertion(true);
		if(replaces != null)
		{
			builder = builder.withOverride(MaskingRule__mdt.Replaces__c, replaces);
		}
		return (MaskingRule__mdt)builder.build();
	}

	/**
	 * @description Builds the subscriber-owned, `acme`-namespaced counterpart of the package's `MaskAddress`
	 * rule used by the namespace-ownership tests — the same developer name as the framework's own rule but a
	 * different `NamespacePrefix`, so the package-ownership gate must tell them apart. Built through
	 * `TST_Builder` rather than `TST_Factory` because the scenario sets `NamespacePrefix`, and left uninserted
	 * since custom metadata cannot be DML-inserted.
	 *
	 * @return The in-memory subscriber-owned, same-named, inactive `MaskAddress` rule.
	 */
	private static MaskingRule__mdt subscriberOwnedAddressRule()
	{
		return (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, SEL_MaskingRule.RULE_MASK_ADDRESS)
				.withOverride(MaskingRule__mdt.MasterLabel, 'Subscriber Custom Rule')
				.withOverride(MaskingRule__mdt.NamespacePrefix, 'acme')
				.withOverride(MaskingRule__mdt.IsActive__c, false)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Builds an in-memory, dormant `MaskingRule__mdt` carrying an explicit `NamespacePrefix`, so
	 * the generation tests can exercise how a package-owned (namespaced) rule is qualified in the deployable
	 * bundle. Built through `TST_Builder` rather than `TST_Factory` because the scenario sets the read-only
	 * `NamespacePrefix`, and left uninserted since custom metadata cannot be DML-inserted.
	 *
	 * @param developerName The bare rule developer name the subscriber requests.
	 * @param label The rule master label, preserved on the activation record.
	 * @param namespacePrefix The owning package namespace, or blank for an unmanaged/subscriber-owned rule.
	 *
	 * @return The in-memory, dormant rule stamped with the given namespace.
	 */
	private static MaskingRule__mdt buildNamespacedRule(String developerName, String label, String namespacePrefix)
	{
		return (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, developerName)
				.withOverride(MaskingRule__mdt.MasterLabel, label)
				.withOverride(MaskingRule__mdt.NamespacePrefix, namespacePrefix)
				.withOverride(MaskingRule__mdt.IsActive__c, false)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Builds an in-memory Regex `MaskingRule__mdt` with a real pattern and replacement so a
	 * precompute test can assert the engine's true transformation of a synthetic example value. The
	 * developer name's stem still drives which field the rule recommends on.
	 *
	 * @param developerName The rule developer name.
	 * @param active Whether the rule is active.
	 * @param pattern The regex pattern the rule applies.
	 * @param replacement The replacement token.
	 *
	 * @return The in-memory Regex rule.
	 */
	private static MaskingRule__mdt regexRule(String developerName, Boolean active, String pattern, String replacement)
	{
		MaskingRule__mdt rule = ruleWithName(developerName, active);
		rule.Mode__c = SEL_MaskingRule.MODE_REGEX;
		rule.Pattern__c = pattern;
		rule.Replacement__c = replacement;
		return rule;
	}

	/**
	 * @description Builds an in-memory MaskingRule__mdt (mock Id) with the given active flag, via TST_Factory.
	 *
	 * @param active Whether the rule is active.
	 *
	 * @return The in-memory rule with a mock Id.
	 */
	private static MaskingRule__mdt rule(Boolean active)
	{
		return TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.IsActive__c => active});
	}

	/**
	 * @description Builds an in-memory MaskingRule__mdt (mock Id) with the given developer name, master label,
	 * and active flag, via TST_Factory, so org-wide inventory tests can assert on the distinct rule labels.
	 *
	 * @param developerName The rule developer name.
	 * @param masterLabel The rule label the inventory surfaces.
	 * @param active Whether the rule is active.
	 *
	 * @return The in-memory rule with the given name, label, and active flag.
	 */
	private static MaskingRule__mdt labeledRule(String developerName, String masterLabel, Boolean active)
	{
		return TST_Factory.newMaskingRule(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => developerName,
				MaskingRule__mdt.MasterLabel => masterLabel,
				MaskingRule__mdt.IsActive__c => active
		});
	}

	/**
	 * @description Builds an in-memory MaskingTarget__mdt (mock Id) with the given developer name, active flag,
	 * and rule reference, via TST_Factory. A null rule reference is left unset.
	 *
	 * @param developerName The target developer name.
	 * @param active Whether the target is active.
	 * @param ruleId The referenced rule Id, or null for no rule reference.
	 *
	 * @return The in-memory target with a mock Id.
	 */
	private static MaskingTarget__mdt target(String developerName, Boolean active, Id ruleId)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.DeveloperName => developerName,
				MaskingTarget__mdt.IsActive__c => active
		};
		if(ruleId != null)
		{
			overrides.put(MaskingTarget__mdt.Rule__c, ruleId);
		}
		return TST_Factory.newMaskingTarget(overrides);
	}

	/**
	 * @description Builds a target decision DTO from the given field-to-rule choices.
	 *
	 * @param developerName The target developer name.
	 * @param label The target label.
	 * @param rule The rule developer name the target binds to.
	 * @param sObjectType The SObject API name the target applies to.
	 * @param field The field API name to mask, or blank for SObject-wide scope.
	 * @param callerClass The caller-class scope, or blank for all callers.
	 *
	 * @return The populated target decision.
	 */
	private static CTRL_MaskingAdvisor.DTO_TargetDecision targetDecision(String developerName, String label, String rule, String sObjectType, String field, String callerClass)
	{
		CTRL_MaskingAdvisor.DTO_TargetDecision decision = new CTRL_MaskingAdvisor.DTO_TargetDecision();
		decision.developerName = developerName;
		decision.label = label;
		decision.ruleDeveloperName = rule;
		decision.sObjectType = sObjectType;
		decision.field = field;
		decision.callerClass = callerClass;
		return decision;
	}

	/**
	 * @description Builds a generation request wrapping a single target decision and the rules to activate.
	 *
	 * @param decision The target decision to include.
	 * @param rulesToActivate The developer names of dormant rules to activate.
	 *
	 * @return The populated generation request.
	 */
	private static CTRL_MaskingAdvisor.DTO_GenerationRequest requestWith(CTRL_MaskingAdvisor.DTO_TargetDecision decision, List<String> rulesToActivate)
	{
		CTRL_MaskingAdvisor.DTO_GenerationRequest request = new CTRL_MaskingAdvisor.DTO_GenerationRequest();
		request.targets = new List<CTRL_MaskingAdvisor.DTO_TargetDecision> {decision};
		request.rulesToActivate = rulesToActivate;
		return request;
	}

	/**
	 * @description Builds an active masking target, wired to an active rule, for the given SObject and field durable Id.
	 *
	 * @param sObjectApiName The SObject API name the target applies to.
	 * @param fieldDurableId The field durable Id to mask, or null for SObject-wide scope.
	 *
	 * @return The in-memory active target with its active rule populated.
	 */
	private static MaskingTarget__mdt activeTargetFor(String sObjectApiName, String fieldDurableId)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.DeveloperName => 'CoverTarget',
				MaskingTarget__mdt.IsActive__c => true,
				MaskingTarget__mdt.SObjectType__c => sObjectApiName
		};
		if(fieldDurableId != null)
		{
			overrides.put(MaskingTarget__mdt.Field__c, fieldDurableId);
		}
		return TST_Factory.newMaskingTarget(overrides, rule(true));
	}

	/**
	 * @description Builds an in-memory MaskingTarget__mdt (mock Id) for posture tests, with an object durable
	 * Id, an optional field durable Id (null for object-wide scope), an active flag, and an optional rule Id.
	 *
	 * @param developerName The target developer name.
	 * @param sObjectDurableId The `SObjectType__c` durable Id the target applies to.
	 * @param fieldDurableId The `Field__c` durable Id to mask, or null for object-wide scope.
	 * @param active Whether the target is active.
	 * @param ruleId The referenced rule Id, or null for no rule reference.
	 *
	 * @return The in-memory target with a mock Id.
	 */
	private static MaskingTarget__mdt postureTarget(String developerName, String sObjectDurableId, String fieldDurableId, Boolean active, Id ruleId)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.DeveloperName => developerName,
				MaskingTarget__mdt.IsActive__c => active,
				MaskingTarget__mdt.SObjectType__c => sObjectDurableId
		};
		if(fieldDurableId != null)
		{
			overrides.put(MaskingTarget__mdt.Field__c, fieldDurableId);
		}
		if(ruleId != null)
		{
			overrides.put(MaskingTarget__mdt.Rule__c, ruleId);
		}
		return TST_Factory.newMaskingTarget(overrides);
	}

	/**
	 * @description Builds the namespace-aware bundle path of a generated `MaskingTarget__mdt` record, so
	 * generation assertions hold whether the package is unmanaged (`MaskingTarget`) or managed
	 * (`kern__MaskingTarget`) — the controller builds the same stem from `SEL_MaskingTarget.OBJECT_NAME`.
	 *
	 * @param developerName The target developer name.
	 *
	 * @return The relative bundle path of the target's `.md-meta.xml`.
	 */
	private static String targetBundlePath(String developerName)
	{
		return 'metadata/customMetadata/' + SEL_MaskingTarget.OBJECT_NAME.removeEnd(CTRL_MaskingAdvisor.CUSTOM_METADATA_SUFFIX) + '.' + developerName + '.md-meta.xml';
	}

	/**
	 * @description Builds the namespace-aware bundle path of a generated `MaskingRule__mdt` activation record.
	 *
	 * @param developerName The rule developer name.
	 *
	 * @return The relative bundle path of the rule's `.md-meta.xml`.
	 */
	private static String ruleBundlePath(String developerName)
	{
		return 'metadata/customMetadata/' + SEL_MaskingRule.OBJECT_NAME.removeEnd(CTRL_MaskingAdvisor.CUSTOM_METADATA_SUFFIX) + '.' + developerName + '.md-meta.xml';
	}

	/**
	 * @description Returns the body of the single rule-activation file in a generated bundle, located by the
	 * `MaskingRule__mdt` object stem so the lookup holds under any namespace (`MaskingRule.<name>` unmanaged,
	 * `kern__MaskingRule.<name>` managed) without the test having to assume the activated rule's deploy name.
	 *
	 * @param bundle The generated bundle.
	 *
	 * @return The rule-activation file body, or null when the bundle activates no rule.
	 */
	private static String findRuleActivationFile(CTRL_MaskingAdvisor.DTO_Bundle bundle)
	{
		String ruleStem = SEL_MaskingRule.OBJECT_NAME.removeEnd(CTRL_MaskingAdvisor.CUSTOM_METADATA_SUFFIX);
		for(String path : bundle.files.keySet())
		{
			if(path.contains('/' + ruleStem + '.'))
			{
				return bundle.files.get(path);
			}
		}
		return null;
	}

	/**
	 * @description Builds the `<field>` row fragment for a namespace-aware CMDT field API name, so field-row
	 * assertions hold under any namespace (the field is `IsActive__c` unmanaged, `kern__IsActive__c` managed).
	 *
	 * @param fieldApiName The namespace-aware field API name (e.g. `SEL_MaskingTarget.FIELD_IS_ACTIVE`).
	 *
	 * @return The `<field>…</field>` fragment.
	 */
	private static String fieldRow(String fieldApiName)
	{
		return '<field>' + fieldApiName + '</field>';
	}

	/**
	 * @description Finds the object-picker option for an API name, or null when absent.
	 *
	 * @param options The options returned by `listObjects`.
	 * @param apiName The API name to find.
	 *
	 * @return The matching option, or null.
	 */
	private static CTRL_MaskingAdvisor.DTO_ObjectOption optionFor(List<CTRL_MaskingAdvisor.DTO_ObjectOption> options, String apiName)
	{
		for(CTRL_MaskingAdvisor.DTO_ObjectOption option : options)
		{
			if(option.apiName == apiName)
			{
				return option;
			}
		}
		return null;
	}

	/**
	 * @description Builds an in-memory EntityDefinition row for the selectable-objects seam.
	 *
	 * @param qualifiedApiName The object API name.
	 * @param label The object label.
	 * @param namespacePrefix The managed-package namespace prefix, or null for a subscriber-owned object.
	 *
	 * @return The in-memory EntityDefinition row.
	 */
	private static EntityDefinition entityRow(String qualifiedApiName, String label, String namespacePrefix)
	{
		TST_Builder.Builder builder = TST_Builder.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.QualifiedApiName, qualifiedApiName)
				.withOverride(EntityDefinition.Label, label);
		if(namespacePrefix != null)
		{
			builder = builder.withOverride(EntityDefinition.NamespacePrefix, namespacePrefix);
		}
		return (EntityDefinition)builder.withoutInsertion().build();
	}

	/**
	 * @description Registers a FieldDefinition classification-overlay mock marking the given field
	 * Confidential with no compliance group.
	 *
	 * @param field The field token the overlay classifies.
	 */
	private static void registerConfidentialFieldOverlay(SObjectField field)
	{
		registerConfidentialFieldOverlay(field, null);
	}

	/**
	 * @description Registers a FieldDefinition classification-overlay mock marking the given field
	 * Confidential, optionally tagging a compliance group. The overlay name derives from the field
	 * token so it matches in any namespace context.
	 *
	 * @param field The field token the overlay classifies.
	 * @param complianceGroup The compliance group tag, or null for none.
	 */
	private static void registerConfidentialFieldOverlay(SObjectField field, String complianceGroup)
	{
		TST_Builder.Builder builder = TST_Builder.of(FieldDefinition.SObjectType)
				.withOverride(FieldDefinition.QualifiedApiName, UTIL_SObjectDescribe.getCachedFieldName(field))
				.withOverride(FieldDefinition.SecurityClassification, SECURITY_CLASSIFICATION_CONFIDENTIAL);
		if(complianceGroup != null)
		{
			builder = builder.withOverride(FieldDefinition.ComplianceGroup, complianceGroup);
		}
		TST_Mock.register(FieldDefinition.SObjectType, builder.withoutInsertion().build());
	}

	/**
	 * @description Finds the flagged-field entry for a field token, or null when the field is not flagged.
	 *
	 * @param assessment The coverage assessment to search.
	 * @param field The field token to find.
	 *
	 * @return The matching flagged field, or null.
	 */
	private static CTRL_MaskingAdvisor.DTO_FlaggedField flaggedRowFor(CTRL_MaskingAdvisor.DTO_ObjectCoverageAssessment assessment, SObjectField field)
	{
		String fieldApiName = UTIL_SObjectDescribe.getCachedFieldName(field);
		for(CTRL_MaskingAdvisor.DTO_FlaggedField flagged : assessment.flaggedFields)
		{
			if(flagged.fieldApiName.equalsIgnoreCase(fieldApiName))
			{
				return flagged;
			}
		}
		return null;
	}

	/**
	 * @description Finds the regulated-field inventory row for a field token, or null when the field is not
	 * in the inventory.
	 *
	 * @param inventory The object field inventory to search.
	 * @param field The field token to find.
	 *
	 * @return The matching inventory row, or null.
	 */
	private static CTRL_MaskingAdvisor.DTO_FieldInventoryRow inventoryRowFor(CTRL_MaskingAdvisor.DTO_ObjectFieldInventory inventory, SObjectField field)
	{
		String fieldApiName = UTIL_SObjectDescribe.getCachedFieldName(field);
		for(CTRL_MaskingAdvisor.DTO_FieldInventoryRow row : inventory.rows)
		{
			if(row.fieldApiName.equalsIgnoreCase(fieldApiName))
			{
				return row;
			}
		}
		return null;
	}

	/**
	 * @description Builds an in-memory `MaskingTarget__mdt` (mock Id) wired to a field or applied object-wide,
	 * for the existing-coverage `appliedRules` / `objectWideRules` tests. `SObjectType__c` carries the api
	 * name (the mock-path match key); a null `fieldReference` is object-wide scope; a null `rule` leaves the
	 * target rule-less so the unresolvable-rule path can be exercised.
	 *
	 * @param developerName The target developer name.
	 * @param sObjectApiName The SObject api name the target applies to (mock-path match key).
	 * @param fieldReference The `Object.Field` reference to mask, or null for object-wide scope.
	 * @param active Whether the target is active.
	 * @param rule The rule the target references, or null for a rule-less target.
	 *
	 * @return The in-memory target.
	 */
	private static MaskingTarget__mdt appliedTarget(String developerName, String sObjectApiName, String fieldReference, Boolean active, MaskingRule__mdt rule)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.DeveloperName => developerName,
				MaskingTarget__mdt.IsActive__c => active,
				MaskingTarget__mdt.SObjectType__c => sObjectApiName
		};
		if(fieldReference != null)
		{
			overrides.put(MaskingTarget__mdt.Field__c, fieldReference);
		}
		return rule == null ? TST_Factory.newMaskingTarget(overrides) : TST_Factory.newMaskingTarget(overrides, rule);
	}

	/**
	 * @description Returns the applied rule with the given target developer name, or null when none matches.
	 *
	 * @param appliedRules The applied rules to search.
	 * @param targetDeveloperName The target developer name to find.
	 *
	 * @return The matching applied rule, or null when absent.
	 */
	private static CTRL_MaskingAdvisor.DTO_AppliedRule appliedRuleByTarget(List<CTRL_MaskingAdvisor.DTO_AppliedRule> appliedRules, String targetDeveloperName)
	{
		for(CTRL_MaskingAdvisor.DTO_AppliedRule applied : appliedRules)
		{
			if(applied.targetDeveloperName == targetDeveloperName)
			{
				return applied;
			}
		}
		return null;
	}

	/**
	 * @description Returns the field row for the given field token, or null when the analysis has no such
	 * row. Takes an `SObjectField` (not a string) so the field reference is compile-checked against the
	 * schema rather than a hardcoded API name.
	 *
	 * @param analysis The field analysis to search.
	 * @param field The field token to find.
	 *
	 * @return The matching field row, or null when absent.
	 */
	private static CTRL_MaskingAdvisor.DTO_FieldRow rowFor(CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis, SObjectField field)
	{
		String apiName = UTIL_SObjectDescribe.getCachedFieldName(field);
		for(CTRL_MaskingAdvisor.DTO_FieldRow row : analysis.fields)
		{
			if(row.apiName.equalsIgnoreCase(apiName))
			{
				return row;
			}
		}
		return null;
	}

	/**
	 * @description Maps a catalogue's options by rule developer name for direct option assertions.
	 *
	 * @param analysis The field analysis whose catalogue to index.
	 *
	 * @return The catalogue options keyed by developer name.
	 */
	private static Map<String, CTRL_MaskingAdvisor.DTO_RuleOption> optionsByName(CTRL_MaskingAdvisor.DTO_FieldAnalysis analysis)
	{
		Map<String, CTRL_MaskingAdvisor.DTO_RuleOption> optionByName = new Map<String, CTRL_MaskingAdvisor.DTO_RuleOption>();
		for(CTRL_MaskingAdvisor.DTO_RuleOption option : analysis.rules)
		{
			optionByName.put(option.developerName, option);
		}
		return optionByName;
	}

	/**
	 * @description Collects a field row's pre-selected recommended-rule developer names into a set, so a
	 * multi-mask assertion can check membership without depending on the (unspecified, equal-stem-length)
	 * ordering between two concept-matched rules.
	 *
	 * @param row The field row.
	 *
	 * @return The developer names of the row's recommended rules.
	 */
	private static Set<String> recommendedRuleNames(CTRL_MaskingAdvisor.DTO_FieldRow row)
	{
		Set<String> names = new Set<String>();
		for(CTRL_MaskingAdvisor.DTO_RecommendedRule recommended : row.recommendedRules)
		{
			names.add(recommended.developerName);
		}
		return names;
	}
}