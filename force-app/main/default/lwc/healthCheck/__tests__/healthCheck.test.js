// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for healthCheck LWC component
 * @author Jason van Beukering
 * @date February 2026, May 2026
 */
import {createElement} from 'lwc';
import HealthCheck from 'c/healthCheck';
import {mockCallControllerMethod, mockShowSuccessToast} from 'c/componentBuilder';

const mockModalOpen = jest.fn().mockResolvedValue('confirmed');
jest.mock('c/classTypeResolverSetupModal', () => ({
	__esModule: true, default: {open: (...args) => mockModalOpen(...args)}
}), {virtual: true});

const mockApplyRetentionModalOpen = jest.fn().mockResolvedValue({action: 'cancel'});
jest.mock('c/applyRetentionModal', () => ({
	__esModule: true, default: {open: (...args) => mockApplyRetentionModalOpen(...args)}
}), {virtual: true});

const MOCK_PROPOSALS = [
	{
		objectApiName: 'kern__LogEntry__c',
		objectLabel: 'Log Entry',
		recordCount: 100,
		retentionDays: 90,
		schedulerName: 'Purge Log Entries',
		schedulerClassName: 'SCHED_PurgeRecords',
		cronExpression: '0 0 2 * * ?'
	},
	{
		objectApiName: 'kern__ApiCall__c',
		objectLabel: 'API Call',
		recordCount: 50,
		retentionDays: 30,
		schedulerName: 'Purge API Calls',
		schedulerClassName: 'SCHED_PurgeRecords',
		cronExpression: '0 0 2 * * ?'
	}
];

const mockGetRetentionProposals = jest.fn().mockResolvedValue(MOCK_PROPOSALS);
jest.mock('@salesforce/apex/CTRL_HealthCheck.getRetentionProposals', () => ({default: (...args) => mockGetRetentionProposals(...args)}), {virtual: true});

const mockApplyRetentionRecommendations = jest.fn().mockResolvedValue([
	'a00xx00000001',
	'a00xx00000002'
]);
jest.mock('@salesforce/apex/CTRL_HealthCheck.applyRetentionRecommendations', () => ({default: (...args) => mockApplyRetentionRecommendations(...args)}), {virtual: true});

const mockScheduledJobEditorModalOpen = jest.fn().mockResolvedValue('a00xx00000002');
jest.mock('c/scheduledJobEditorModal', () => ({
	__esModule: true, default: {open: (...args) => mockScheduledJobEditorModalOpen(...args)}
}), {virtual: true});

jest.mock('@salesforce/label/c.HealthCheck_CardTitle', () => ({default: 'Health Check'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_RefreshAltText', () => ({default: 'Refresh health checks'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_AllPassHeading', () => ({default: 'All systems operational.'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_AllPassMultipleChecks', () => ({default: '{0} checks passed.'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_AllPassSingleCheck', () => ({default: '1 check passed.'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_PassingPrefix', () => ({default: 'Passing:'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_ActionRequiredHeadline', () => ({default: 'Action required — {0} failing, {1} {2}'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_ReviewRecommendedHeadline', () => ({default: 'Review recommended — {0} {1}'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_CheckName', () => ({default: 'Data Retention'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ApplyButton', () => ({default: 'Apply Recommended Retention'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_CustomizeLink', () => ({default: 'Customize each job →'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ModalTitle', () => ({default: 'Apply Recommended Retention'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ModalSubtitle', () => ({default: 'Review {0} scheduled purge jobs.'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_FirstRunWarning', () => ({default: 'First run may delete significant data.'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_CreateButton', () => ({default: 'Create {0} jobs'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_SuccessToast', () => ({default: 'Created {0} scheduled jobs.'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_SetUpButton', () => ({default: 'Set up →'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_ConfiguredPill', () => ({default: 'Configured'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_CustomizeBackLink', () => ({default: '← Back to one-click apply'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_CustomizingHeadline', () => ({default: 'Data Retention — customizing {0} jobs'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_DataRetention_CustomizingHelp',
		() => ({default: 'Each Set up button opens the scheduled job editor with recommended defaults prefilled. Tweak anything before saving.'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_FailSection_Heading', () => ({default: 'Action required'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_WarnSection_Heading', () => ({default: 'Review recommended'}), {virtual: true});

const MOCK_RESULTS = [
	{name: 'Organisation Cache', status: 'Pass', detail: 'Organisation Cache is allocated to the kern.Library partition.', actionLabel: null, priority: 10},
	{name: 'Session Cache', status: 'Pass', detail: 'Session Cache is allocated to the kern.Library partition.', actionLabel: null, priority: 20},
	{name: 'Trusted Site', status: 'Pass', detail: 'Trusted URL is configured for https://example.my.salesforce.com.', actionLabel: null, priority: 30},
	{name: 'Class Type Resolver', status: 'Pass', detail: 'A class type resolver is configured and working.', actionLabel: null, priority: 40},
	{name: 'Data Retention', status: 'Pass', detail: 'Scheduled purge jobs are configured for framework data objects.', actionLabel: null, priority: 50}
];

const MOCK_RESULTS_WITH_FAILURE = [
	{
		name: 'Organisation Cache',
		status: 'Fail',
		detail: 'Allocate Organisation Cache to the kern.Library partition (Setup > Platform Cache > Edit).',
		actionLabel: null,
		priority: 10
	},
	{name: 'Session Cache', status: 'Pass', detail: 'Session Cache is allocated to the kern.Library partition.', actionLabel: null, priority: 20},
	{
		name: 'Trusted Site',
		status: 'Fail',
		detail: 'Add a Trusted URL for https://example.my.salesforce.com (Setup > Trusted URLs > New Trusted URL).',
		actionLabel: null,
		priority: 30
	},
	{
		name: 'Class Type Resolver',
		status: 'Warn',
		detail: 'A class type resolver is configured but the referenced class could not be found. Check that the class is deployed and accessible.',
		actionLabel: 'Setup',
		priority: 40
	},
	{name: 'Data Retention', status: 'Pass', detail: 'Scheduled purge jobs are configured for framework data objects.', actionLabel: null, priority: 50}
];

const MOCK_RESULTS_WITH_WARNING = [
	{name: 'Organisation Cache', status: 'Pass', detail: 'Organisation Cache is allocated to the kern.Library partition.', actionLabel: null, priority: 10},
	{
		name: 'Session Cache', status: 'Warn', detail: 'Allocate Session Cache to the kern.Library partition (Setup > Platform Cache > Edit).', actionLabel: null, priority: 20
	},
	{name: 'Trusted Site', status: 'Pass', detail: 'Trusted URL is configured for https://example.my.salesforce.com.', actionLabel: null, priority: 30},
	{name: 'Class Type Resolver', status: 'Pass', detail: 'A class type resolver is configured and working.', actionLabel: null, priority: 40},
	{name: 'Data Retention', status: 'Pass', detail: 'Scheduled purge jobs are configured for framework data objects.', actionLabel: null, priority: 50}
];

const MOCK_RESULTS_WITH_RESOLVER_WARN = [
	{name: 'Organisation Cache', status: 'Pass', detail: 'Organisation Cache is allocated to the kern.Library partition.', actionLabel: null, priority: 10},
	{name: 'Session Cache', status: 'Pass', detail: 'Session Cache is allocated to the kern.Library partition.', actionLabel: null, priority: 20},
	{name: 'Trusted Site', status: 'Pass', detail: 'Trusted URL is configured for https://example.my.salesforce.com.', actionLabel: null, priority: 30},
	{
		name: 'Class Type Resolver',
		status: 'Warn',
		detail: 'No class type resolver is configured. A resolver is needed so the package can find your custom Apex classes.',
		actionLabel: 'Setup',
		priority: 40
	},
	{name: 'Data Retention', status: 'Pass', detail: 'Scheduled purge jobs are configured for framework data objects.', actionLabel: null, priority: 50}
];

const MOCK_RESULTS_WITH_RETENTION_WARN = [
	{name: 'Organisation Cache', status: 'Pass', detail: 'Organisation Cache is allocated to the kern.Library partition.', actionLabel: null, priority: 10},
	{name: 'Session Cache', status: 'Pass', detail: 'Session Cache is allocated to the kern.Library partition.', actionLabel: null, priority: 20},
	{name: 'Trusted Site', status: 'Pass', detail: 'Trusted URL is configured for https://example.my.salesforce.com.', actionLabel: null, priority: 30},
	{name: 'Class Type Resolver', status: 'Pass', detail: 'A class type resolver is configured and working.', actionLabel: null, priority: 40},
	{
		name: 'Data Retention',
		status: 'Warn',
		detail: 'No data retention configured for Log Entry, API Call, API Issue, Async Chain Execution.',
		actionLabel: 'Scheduled Jobs',
		priority: 50,
		recordCounts: [
			{objectName: 'Log Entry', recordCount: 8200},
			{objectName: 'API Call', recordCount: 1100},
			{objectName: 'API Issue', recordCount: 45},
			{objectName: 'Async Chain Execution', recordCount: 300}
		]
	}
];

describe('c-health-check', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function createComponent(mockData = MOCK_RESULTS)
	{
		mockCallControllerMethod.mockResolvedValue(mockData);

		const element = createElement('c-health-check', {
			is: HealthCheck
		});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		return element;
	}

	it('should render all-pass scoped notification when every check passes', async() =>
	{
		const element = await createComponent();

		const allPassBanner = element.shadowRoot.querySelector('[data-testid="health-check-all-pass"]');
		expect(allPassBanner).toBeTruthy();
		expect(allPassBanner.classList.contains('slds-scoped-notification')).toBe(true);
		expect(allPassBanner.classList.contains('slds-theme_success')).toBe(true);
		expect(allPassBanner.getAttribute('role')).toBe('status');

		const mixedBanner = element.shadowRoot.querySelector('[data-testid="health-check-mixed"]');
		expect(mixedBanner).toBeNull();
	});

	it('should show result count in all-pass banner copy', async() =>
	{
		const element = await createComponent();

		const allPassBanner = element.shadowRoot.querySelector('[data-testid="health-check-all-pass"]');
		expect(allPassBanner.textContent).toContain('5 checks passed');
	});

	it('should pluralise single check correctly in all-pass banner copy', async() =>
	{
		const element = await createComponent([
			{name: 'Organisation Cache', status: 'Pass', detail: 'Organisation Cache is allocated to the kern.Library partition.', actionLabel: null}
		]);

		const allPassBanner = element.shadowRoot.querySelector('[data-testid="health-check-all-pass"]');
		expect(allPassBanner.textContent).toContain('1 check passed');
		expect(allPassBanner.textContent).not.toContain('1 checks');
	});

	it('should render mixed status bar when any check fails', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_FAILURE);

		const mixedBanner = element.shadowRoot.querySelector('[data-testid="health-check-mixed"]');
		expect(mixedBanner).toBeTruthy();
		expect(mixedBanner.getAttribute('role')).toBe('alert');

		const headline = element.shadowRoot.querySelector('[data-testid="health-check-headline"]');
		expect(headline.textContent).toContain('Action required');
		expect(headline.textContent).toContain('2 failing');
		expect(headline.textContent).toContain('1 warning');
		expect(headline.textContent).not.toContain('warnings');
	});

	it('should render mixed status bar when only warnings are present', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_WARNING);

		const mixedBanner = element.shadowRoot.querySelector('[data-testid="health-check-mixed"]');
		expect(mixedBanner).toBeTruthy();

		const headline = element.shadowRoot.querySelector('[data-testid="health-check-headline"]');
		expect(headline.textContent).toContain('Review recommended');
		expect(headline.textContent).toContain('1 warning');
		expect(headline.textContent).not.toContain('warnings');
	});

	it('should render passing chips for checks that are confirmed healthy', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_FAILURE);

		const passingChips = element.shadowRoot.querySelectorAll('[data-testid="health-check-passing-chip"]');
		expect(passingChips).toHaveLength(2);
		expect(passingChips[0].textContent).toContain('Session Cache');
		expect(passingChips[1].textContent).toContain('Data Retention');
	});

	it('should render multiple passing chips when only one check is broken', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_WARNING);

		const passingChips = element.shadowRoot.querySelectorAll('[data-testid="health-check-passing-chip"]');
		expect(passingChips).toHaveLength(4);
	});

	it('should not render the passing row when every check is broken', async() =>
	{
		const element = await createComponent([
			{name: 'Organisation Cache', status: 'Fail', detail: 'Allocate...', actionLabel: null},
			{name: 'Session Cache', status: 'Fail', detail: 'Allocate...', actionLabel: null},
			{name: 'Trusted Site', status: 'Fail', detail: 'Add a Trusted URL...', actionLabel: null}
		]);

		const passingChips = element.shadowRoot.querySelectorAll('[data-testid="health-check-passing-chip"]');
		expect(passingChips).toHaveLength(0);
	});

	it('should render action items list with failing and warning checks only', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_FAILURE);

		const items = element.shadowRoot.querySelectorAll('[data-testid="health-check-item"]');
		expect(items).toHaveLength(3);

		const names = element.shadowRoot.querySelectorAll('[data-testid="health-check-name"]');
		expect(names[0].textContent).toBe('Organisation Cache');
		expect(names[1].textContent).toBe('Trusted Site');
		expect(names[2].textContent).toBe('Class Type Resolver');
	});

	it('should render detail text on action items', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_FAILURE);

		const details = element.shadowRoot.querySelectorAll('[data-testid="health-check-detail"]');
		expect(details[0].textContent).toContain('Allocate Organisation Cache');
	});

	it('should render inline Setup button when an action item has actionLabel', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RESOLVER_WARN);

		const actionButtons = element.shadowRoot.querySelectorAll('lightning-button[data-name]');
		expect(actionButtons).toHaveLength(1);
		expect(actionButtons[0].label).toBe('Setup');
		expect(actionButtons[0].dataset.name).toBe('Class Type Resolver');
		// Setup button uses SLDS default neutral variant — no brand variant override
	});

	it('should not render action items list when every check passes', async() =>
	{
		const element = await createComponent(MOCK_RESULTS);

		const items = element.shadowRoot.querySelectorAll('[data-testid="health-check-item"]');
		expect(items).toHaveLength(0);
	});

	it('should not render anything before the Apex call resolves with data', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(undefined);

		const element = createElement('c-health-check', {
			is: HealthCheck
		});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		const allPassBanner = element.shadowRoot.querySelector('[data-testid="health-check-all-pass"]');
		const mixedBanner = element.shadowRoot.querySelector('[data-testid="health-check-mixed"]');
		expect(allPassBanner).toBeNull();
		expect(mixedBanner).toBeNull();
	});

	it('should refresh results when refresh button is clicked in all-pass banner', async() =>
	{
		const element = await createComponent();

		mockCallControllerMethod.mockResolvedValue(MOCK_RESULTS_WITH_FAILURE);

		const refresh = element.shadowRoot.querySelector('[data-testid="health-check-refresh"]');
		refresh.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		const mixedBanner = element.shadowRoot.querySelector('[data-testid="health-check-mixed"]');
		expect(mixedBanner).toBeTruthy();
		expect(mockCallControllerMethod).toHaveBeenCalledTimes(2);
	});

	it('should refresh results when refresh button is clicked in mixed banner', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_FAILURE);

		mockCallControllerMethod.mockResolvedValue(MOCK_RESULTS);

		const refresh = element.shadowRoot.querySelector('[data-testid="health-check-refresh"]');
		refresh.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		const allPassBanner = element.shadowRoot.querySelector('[data-testid="health-check-all-pass"]');
		expect(allPassBanner).toBeTruthy();
	});

	it('should render action item rows with correct status icons', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_FAILURE);

		const items = element.shadowRoot.querySelectorAll('[data-testid="health-check-item"]');
		const firstIcon = items[0].querySelector('lightning-icon');
		expect(firstIcon.iconName).toBe('utility:error');
		expect(firstIcon.variant).toBe('error');

		const warnIcon = items[2].querySelector('lightning-icon');
		expect(warnIcon.iconName).toBe('utility:warning');
		expect(warnIcon.variant).toBe('warning');
	});

	it('should open the class type resolver setup modal when the Setup button is clicked', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RESOLVER_WARN);

		const actionButton = element.shadowRoot.querySelector('lightning-button[data-name]');
		actionButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		expect(mockModalOpen).toHaveBeenCalledWith(expect.objectContaining({size: 'medium'}));
	});

	it('should re-run health checks after the setup modal closes', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RESOLVER_WARN);

		mockCallControllerMethod.mockClear();
		mockCallControllerMethod.mockResolvedValue(MOCK_RESULTS);

		const actionButton = element.shadowRoot.querySelector('lightning-button[data-name]');
		actionButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockCallControllerMethod).toHaveBeenCalled();
	});

	it('should render data retention warning as an action item when unconfigured', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const items = element.shadowRoot.querySelectorAll('[data-testid="health-check-item"]');
		expect(items).toHaveLength(1);

		const names = element.shadowRoot.querySelectorAll('[data-testid="health-check-name"]');
		expect(names[0].textContent).toBe('Data Retention');

		const details = element.shadowRoot.querySelectorAll('[data-testid="health-check-detail"]');
		expect(details[0].textContent).toContain('No data retention configured for');
	});

	it('should render data retention as a passing chip when configured', async() =>
	{
		const element = await createComponent(MOCK_RESULTS);

		const allPassBanner = element.shadowRoot.querySelector('[data-testid="health-check-all-pass"]');
		expect(allPassBanner).toBeTruthy();
		expect(allPassBanner.textContent).toContain('5 checks passed');
	});

	it('should pluralise warnings in headline when multiple warnings exist', async() =>
	{
		const multipleWarnings = [
			{name: 'Organisation Cache', status: 'Pass', detail: 'Pass', actionLabel: null},
			{name: 'Session Cache', status: 'Warn', detail: 'Warn', actionLabel: null},
			{name: 'Trusted Site', status: 'Pass', detail: 'Pass', actionLabel: null},
			{name: 'Class Type Resolver', status: 'Warn', detail: 'Warn', actionLabel: 'Setup'},
			{name: 'Data Retention', status: 'Warn', detail: 'Warn', actionLabel: 'Scheduled Jobs'}
		];
		const element = await createComponent(multipleWarnings);

		const headline = element.shadowRoot.querySelector('[data-testid="health-check-headline"]');
		expect(headline.textContent).toContain('3 warnings');
	});

	it('should render dual retention actions (Apply + Customize) on data retention warning', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		expect(applyButton).toBeTruthy();
		expect(applyButton.label).toBe('Apply Recommended Retention');
		expect(applyButton.variant).toBeUndefined();

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		expect(customizeLink).toBeTruthy();
		expect(customizeLink.label).toBe('Customize each job →');
		expect(customizeLink.variant).toBe('base');

		const legacyRetentionButton = element.shadowRoot.querySelector('lightning-button[data-name="Data Retention"]');
		expect(legacyRetentionButton).toBeNull();
	});

	it('should still render legacy single button for non-retention action items', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RESOLVER_WARN);

		const legacyButton = element.shadowRoot.querySelector('lightning-button[data-name="Class Type Resolver"]');
		expect(legacyButton).toBeTruthy();
		expect(legacyButton.label).toBe('Setup');

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		expect(applyButton).toBeNull();
	});

	it('should open applyRetentionModal with proposals payload when Apply button clicked', async() =>
	{
		mockApplyRetentionModalOpen.mockResolvedValueOnce({action: 'cancel'});
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		applyButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockGetRetentionProposals).toHaveBeenCalled();
		expect(mockApplyRetentionModalOpen).toHaveBeenCalledWith(expect.objectContaining({
			size: 'medium',
			proposals: MOCK_PROPOSALS,
			title: 'Apply Recommended Retention',
			subtitle: 'Review 2 scheduled purge jobs.',
			firstRunWarning: 'First run may delete significant data.',
			confirmButtonLabel: 'Create 2 jobs',
			customizeLinkLabel: 'Customize each job →'
		}));
	});

	it('should apply recommendations and show success toast when modal confirms', async() =>
	{
		mockApplyRetentionModalOpen.mockResolvedValueOnce({action: 'confirm', proposals: MOCK_PROPOSALS});
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		mockCallControllerMethod.mockClear();
		mockCallControllerMethod.mockResolvedValue(MOCK_RESULTS);

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		applyButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockApplyRetentionRecommendations).toHaveBeenCalledWith({
			proposalsJson: JSON.stringify(MOCK_PROPOSALS)
		});
		expect(mockShowSuccessToast).toHaveBeenCalledWith('Created 2 scheduled jobs.');
		expect(mockCallControllerMethod).toHaveBeenCalled();
	});

	it('should flip to customize mode when modal resolves with customize action', async() =>
	{
		mockApplyRetentionModalOpen.mockResolvedValueOnce({action: 'customize'});
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		applyButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const sublist = element.shadowRoot.querySelector('[data-testid="retention-sublist"]');
		expect(sublist).toBeTruthy();
		expect(mockApplyRetentionRecommendations).not.toHaveBeenCalled();
		expect(mockShowSuccessToast).not.toHaveBeenCalled();
	});

	it('should do nothing when modal resolves with cancel action', async() =>
	{
		mockApplyRetentionModalOpen.mockResolvedValueOnce({action: 'cancel'});
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		mockCallControllerMethod.mockClear();

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		applyButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockApplyRetentionRecommendations).not.toHaveBeenCalled();
		expect(mockShowSuccessToast).not.toHaveBeenCalled();
		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	it('should do nothing when modal resolves with null', async() =>
	{
		mockApplyRetentionModalOpen.mockResolvedValueOnce(null);
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		mockCallControllerMethod.mockClear();

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		applyButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockApplyRetentionRecommendations).not.toHaveBeenCalled();
		expect(mockShowSuccessToast).not.toHaveBeenCalled();
		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	it('should flip to customize mode when customize link is clicked directly', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const sublist = element.shadowRoot.querySelector('[data-testid="retention-sublist"]');
		expect(sublist).toBeTruthy();
	});

	it('should hide Apply and Customize buttons when customize mode is active', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		const customizeButton = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		expect(applyButton).toBeNull();
		expect(customizeButton).toBeNull();

		const sublist = element.shadowRoot.querySelector('[data-testid="retention-sublist"]');
		expect(sublist).toBeTruthy();
	});

	it('should render one retention sub-row per proposal in customize mode', async() =>
	{
		mockApplyRetentionModalOpen.mockResolvedValueOnce({action: 'customize'});
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		applyButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const subRows = element.shadowRoot.querySelectorAll('[data-testid="retention-sub-row"]');
		expect(subRows).toHaveLength(2);
		expect(subRows[0].textContent).toContain('Log Entry');
		expect(subRows[0].textContent).toContain('100');
		expect(subRows[0].textContent).toContain('90');
		expect(subRows[1].textContent).toContain('API Call');
	});

	it('should render a primary Set Up button per sub-row with object api name', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const setUpButtons = element.shadowRoot.querySelectorAll('[data-testid="set-up-button"]');
		expect(setUpButtons).toHaveLength(2);
		expect(setUpButtons[0].label).toBe('Set up →');
		expect(setUpButtons[0].variant).toBeUndefined();
		expect(setUpButtons[0].dataset.objectApiName).toBe('kern__LogEntry__c');
		expect(setUpButtons[1].dataset.objectApiName).toBe('kern__ApiCall__c');
	});

	it('should render back-to-apply base link in the customize-mode header', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const backLink = element.shadowRoot.querySelector('[data-testid="back-to-apply-link"]');
		expect(backLink).toBeTruthy();
		expect(backLink.label).toBe('← Back to one-click apply');
		expect(backLink.variant).toBe('base');

		const customizeBlock = element.shadowRoot.querySelector('.retention-customize-block');
		expect(customizeBlock).toBeTruthy();
		const headline = customizeBlock.querySelector('[data-testid="customize-headline"]');
		const sublist = customizeBlock.querySelector('[data-testid="retention-sublist"]');
		expect(headline).toBeTruthy();
		expect(sublist).toBeTruthy();
		const headlineRow = headline.parentElement;
		expect(headlineRow.contains(backLink)).toBe(true);
		expect(sublist.contains(backLink)).toBe(false);
	});

	it('should render customize-mode headline with the interpolated proposal count', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const headline = element.shadowRoot.querySelector('[data-testid="customize-headline"]');
		expect(headline).toBeTruthy();
		expect(headline.textContent).toContain('Data Retention — customizing 2 jobs');
	});

	it('should render customize-mode help copy', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const help = element.shadowRoot.querySelector('[data-testid="customize-help"]');
		expect(help).toBeTruthy();
		expect(help.textContent).toContain('Each Set up button opens the scheduled job editor');
	});

	const largeRecordCount = 1234;

	describe.each([
		[
			'pluralises when count is greater than one',
			5,
			'5 records',
			'5 record '
		],
		[
			'singular when count is exactly one',
			1,
			'1 record',
			'1 records'
		],
		[
			'formats thousands separators for large counts',
			largeRecordCount,
			'1,234 records',
			null
		]
	])('sub-row record-count label: %s', (_label, recordCount, expectedContained, notExpected) =>
	{
		it('renders with correct grammar and formatting', async() =>
		{
			mockGetRetentionProposals.mockResolvedValueOnce([
				{
					objectApiName: 'kern__LogEntry__c',
					objectLabel: 'Log Entry',
					recordCount,
					retentionDays: 90,
					schedulerName: 'Purge Log Entries',
					schedulerClassName: 'SCHED_PurgeRecords',
					cronExpression: '0 0 2 * * ?'
				}
			]);
			const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

			const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
			customizeLink.dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();
			await Promise.resolve();
			await Promise.resolve();

			const subRow = element.shadowRoot.querySelector('[data-testid="retention-sub-row"]');
			expect(subRow.textContent).toContain(expectedContained);

			if(notExpected)
			{
				expect(subRow.textContent).not.toContain(notExpected);
			}
		});
	});

	it('should not render the original name/detail paragraphs for the retention row in customize mode', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const names = element.shadowRoot.querySelectorAll('[data-testid="health-check-name"]');
		const details = element.shadowRoot.querySelectorAll('[data-testid="health-check-detail"]');
		expect(names).toHaveLength(0);
		expect(details).toHaveLength(0);
	});

	it('should open scheduledJobEditorModal with prefill and lockedFields when Set Up is clicked', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const setUpButtons = element.shadowRoot.querySelectorAll('[data-testid="set-up-button"]');
		setUpButtons[0].dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockScheduledJobEditorModalOpen).toHaveBeenCalledWith(expect.objectContaining({
			size: 'medium', prefill: expect.objectContaining({
				schedulerName: 'Purge Log Entries',
				className: MOCK_PROPOSALS[0].schedulerClassName,
				cronExpression: '0 0 2 * * ?',
				isActive: true,
				parameterValues: {objectName: 'kern__LogEntry__c', minimumNumberOfDays: '90'}
			}), lockedFields: [
				'objectName',
				'className'
			]
		}));
	});

	describe.each([
		[
			'bare class name (non-namespaced org)',
			'SCHED_PurgeRecords'
		],
		[
			'managed-package namespace',
			'kern.SCHED_PurgeRecords'
		],
		[
			'rebranded subscriber namespace',
			'acme.SCHED_PurgeRecords'
		]
	])('set-up opens the editor with any schedulerClassName Apex supplies (%s)', (_label, schedulerClassName) =>
	{
		it('forwards the Apex-supplied class name verbatim into the prefill payload', async() =>
		{
			mockScheduledJobEditorModalOpen.mockClear();
			mockGetRetentionProposals.mockResolvedValueOnce([
				{
					objectApiName: 'kern__LogEntry__c',
					objectLabel: 'Log Entry',
					recordCount: 100,
					retentionDays: 90,
					schedulerName: 'Purge Log Entries',
					schedulerClassName,
					cronExpression: '0 0 2 * * ?'
				}
			]);

			const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

			const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
			customizeLink.dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();
			await Promise.resolve();
			await Promise.resolve();

			const setUpButton = element.shadowRoot.querySelector('[data-testid="set-up-button"]');
			setUpButton.dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();
			await Promise.resolve();
			await Promise.resolve();

			expect(mockScheduledJobEditorModalOpen).toHaveBeenCalledTimes(1);
			const openArgs = mockScheduledJobEditorModalOpen.mock.calls[0][0];
			expect(openArgs.prefill.className).toBe(schedulerClassName);
		});
	});

	it('should re-run health checks and reload proposals after editor modal closes', async() =>
	{
		mockScheduledJobEditorModalOpen.mockResolvedValueOnce('a00xx00000002');
		mockGetRetentionProposals.mockResolvedValueOnce(MOCK_PROPOSALS);
		mockGetRetentionProposals.mockResolvedValueOnce([MOCK_PROPOSALS[1]]);

		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		mockCallControllerMethod.mockClear();
		mockCallControllerMethod.mockResolvedValue(MOCK_RESULTS_WITH_RETENTION_WARN);

		const setUpButton = element.shadowRoot.querySelector('[data-testid="set-up-button"]');
		setUpButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockCallControllerMethod).toHaveBeenCalled();
		expect(mockGetRetentionProposals).toHaveBeenCalledTimes(2);

		const subRows = element.shadowRoot.querySelectorAll('[data-testid="retention-sub-row"]');
		expect(subRows).toHaveLength(1);
		expect(subRows[0].textContent).toContain('API Call');
	});

	it('should flip customize mode off when proposals reload empty after editor closes', async() =>
	{
		mockScheduledJobEditorModalOpen.mockResolvedValueOnce('a00xx00000002');
		mockGetRetentionProposals.mockResolvedValueOnce(MOCK_PROPOSALS);
		mockGetRetentionProposals.mockResolvedValueOnce([]);

		mockCallControllerMethod.mockResolvedValue(MOCK_RESULTS_WITH_RETENTION_WARN);

		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValue(MOCK_RESULTS);

		const setUpButton = element.shadowRoot.querySelector('[data-testid="set-up-button"]');
		setUpButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const sublist = element.shadowRoot.querySelector('[data-testid="retention-sublist"]');
		expect(sublist).toBeNull();
	});

	it('should return to dual-button view when back-to-apply link is clicked', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const backLink = element.shadowRoot.querySelector('[data-testid="back-to-apply-link"]');
		backLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		const sublist = element.shadowRoot.querySelector('[data-testid="retention-sublist"]');
		expect(sublist).toBeNull();

		const applyButton = element.shadowRoot.querySelector('[data-testid="apply-retention-button"]');
		expect(applyButton).toBeTruthy();
	});

	it('should not open editor modal when set-up is clicked for an unknown object api name', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const setUpButton = element.shadowRoot.querySelector('[data-testid="set-up-button"]');
		setUpButton.dataset.objectApiName = 'kern__Unknown__c';
		setUpButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockScheduledJobEditorModalOpen).not.toHaveBeenCalled();
	});

	it('should not refetch proposals when setCustomizeMode is turned off', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RETENTION_WARN);

		const customizeLink = element.shadowRoot.querySelector('[data-testid="customize-retention-link"]');
		customizeLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockGetRetentionProposals).toHaveBeenCalledTimes(1);

		const backLink = element.shadowRoot.querySelector('[data-testid="back-to-apply-link"]');
		backLink.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		expect(mockGetRetentionProposals).toHaveBeenCalledTimes(1);
	});

	it('should show only unconfigured objects when some retention jobs exist', async() =>
	{
		const partialRetention = [
			{name: 'Organisation Cache', status: 'Pass', detail: 'Organisation Cache is allocated.', actionLabel: null},
			{name: 'Session Cache', status: 'Pass', detail: 'Session Cache is allocated.', actionLabel: null},
			{name: 'Trusted Site', status: 'Pass', detail: 'Trusted URL is configured.', actionLabel: null},
			{name: 'Class Type Resolver', status: 'Pass', detail: 'Resolver is configured.', actionLabel: null},
			{
				name: 'Data Retention',
				status: 'Warn',
				detail: 'No data retention configured for API Call, API Issue, Async Chain Execution.',
				actionLabel: 'Scheduled Jobs',
				recordCounts: [
					{objectName: 'API Call', recordCount: 500},
					{objectName: 'API Issue', recordCount: 120},
					{objectName: 'Async Chain Execution', recordCount: 80}
				]
			}
		];
		const element = await createComponent(partialRetention);

		const items = element.shadowRoot.querySelectorAll('[data-testid="health-check-item"]');
		expect(items).toHaveLength(1);

		const details = element.shadowRoot.querySelectorAll('[data-testid="health-check-detail"]');
		expect(details[0].textContent).toContain('API Call');
		expect(details[0].textContent).not.toContain('Log Entry');

		const passingChips = element.shadowRoot.querySelectorAll('[data-testid="health-check-passing-chip"]');
		expect(passingChips).toHaveLength(4);
	});

	it('should render fail items inside the Action required section', async() =>
	{
		const failOnly = [
			{name: 'Organisation Cache', status: 'Pass', detail: 'Organisation Cache is allocated.', actionLabel: null, priority: 10},
			{name: 'Session Cache', status: 'Pass', detail: 'Session Cache is allocated.', actionLabel: null, priority: 20},
			{name: 'Trusted Site', status: 'Pass', detail: 'Trusted URL is configured.', actionLabel: null, priority: 30},
			{
				name: 'Class Type Resolver',
				status: 'Fail',
				detail: 'A class type resolver is configured but the referenced class could not be found.',
				actionLabel: 'Setup',
				priority: 40
			},
			{name: 'Data Retention', status: 'Pass', detail: 'Scheduled purge jobs are configured.', actionLabel: null, priority: 50}
		];
		const element = await createComponent(failOnly);

		const failSection = element.shadowRoot.querySelector('[data-testid="fail-section"]');
		expect(failSection).toBeTruthy();

		const heading = failSection.querySelector('h3');
		expect(heading.textContent).toBe('Action required');

		const names = failSection.querySelectorAll('[data-testid="health-check-name"]');
		expect(names).toHaveLength(1);
		expect(names[0].textContent).toBe('Class Type Resolver');

		const warnSection = element.shadowRoot.querySelector('[data-testid="warn-section"]');
		expect(warnSection).toBeNull();
	});

	it('should render warn items inside the Review recommended section', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_RESOLVER_WARN);

		const warnSection = element.shadowRoot.querySelector('[data-testid="warn-section"]');
		expect(warnSection).toBeTruthy();

		const heading = warnSection.querySelector('h3');
		expect(heading.textContent).toBe('Review recommended');

		const names = warnSection.querySelectorAll('[data-testid="health-check-name"]');
		expect(names).toHaveLength(1);
		expect(names[0].textContent).toBe('Class Type Resolver');

		const failSection = element.shadowRoot.querySelector('[data-testid="fail-section"]');
		expect(failSection).toBeNull();
	});

	it('should render Fail section above Warn section when both severities present', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_FAILURE);

		const failSection = element.shadowRoot.querySelector('[data-testid="fail-section"]');
		const warnSection = element.shadowRoot.querySelector('[data-testid="warn-section"]');
		expect(failSection).toBeTruthy();
		expect(warnSection).toBeTruthy();

		const position = failSection.compareDocumentPosition(warnSection);
		expect(position & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
	});

	it('should not render Fail section when no fail items', async() =>
	{
		const element = await createComponent(MOCK_RESULTS_WITH_WARNING);

		const failSection = element.shadowRoot.querySelector('[data-testid="fail-section"]');
		expect(failSection).toBeNull();

		const warnSection = element.shadowRoot.querySelector('[data-testid="warn-section"]');
		expect(warnSection).toBeTruthy();
	});

	it('should not render Warn section when no warn items', async() =>
	{
		const failOnly = [
			{name: 'Organisation Cache', status: 'Pass', detail: 'Organisation Cache is allocated.', actionLabel: null, priority: 10},
			{
				name: 'Trusted Site', status: 'Fail', detail: 'Add a Trusted URL.', actionLabel: null, priority: 30
			},
			{name: 'Class Type Resolver', status: 'Pass', detail: 'Resolver is configured.', actionLabel: null, priority: 40},
			{name: 'Data Retention', status: 'Pass', detail: 'Scheduled purge jobs are configured.', actionLabel: null, priority: 50}
		];
		const element = await createComponent(failOnly);

		const failSection = element.shadowRoot.querySelector('[data-testid="fail-section"]');
		expect(failSection).toBeTruthy();

		const warnSection = element.shadowRoot.querySelector('[data-testid="warn-section"]');
		expect(warnSection).toBeNull();
	});

	it('should sort fail items by priority ascending', () =>
	{
		const prototype = HealthCheck.prototype;
		const context = {
			results: [
				{name: 'Class Type Resolver', failed: true, warned: false, actionLabel: 'Setup', priority: 40},
				{name: 'Organisation Cache', failed: true, warned: false, actionLabel: null, priority: 10}
			]
		};

		const items = Object.getOwnPropertyDescriptor(prototype, 'failItems').get.call(context);

		expect(items).toHaveLength(2);
		expect(items[0].name).toBe('Organisation Cache');
		expect(items[0].priority).toBe(10);
		expect(items[1].name).toBe('Class Type Resolver');
		expect(items[1].priority).toBe(40);
	});

	it('should sort warn items by priority ascending', () =>
	{
		const prototype = HealthCheck.prototype;
		const context = {
			results: [
				{name: 'Data Retention', failed: false, warned: true, actionLabel: 'Scheduled Jobs', priority: 50},
				{name: 'Session Cache', failed: false, warned: true, actionLabel: null, priority: 20}
			]
		};

		const items = Object.getOwnPropertyDescriptor(prototype, 'warnItems').get.call(context);

		expect(items).toHaveLength(2);
		expect(items[0].name).toBe('Session Cache');
		expect(items[0].priority).toBe(20);
		expect(items[1].name).toBe('Data Retention');
		expect(items[1].priority).toBe(50);
	});

	it('should fall back to Number.MAX_SAFE_INTEGER when priority is undefined', () =>
	{
		const prototype = HealthCheck.prototype;
		const context = {
			results: [
				{name: 'No Priority', failed: true, warned: false, actionLabel: null},
				{name: 'Has Priority', failed: true, warned: false, actionLabel: null, priority: 30},
				{name: 'Warn No Priority', failed: false, warned: true, actionLabel: null},
				{name: 'Warn Has Priority', failed: false, warned: true, actionLabel: null, priority: 15}
			]
		};

		const failItems = Object.getOwnPropertyDescriptor(prototype, 'failItems').get.call(context);
		const warnItems = Object.getOwnPropertyDescriptor(prototype, 'warnItems').get.call(context);

		expect(failItems[0].name).toBe('Has Priority');
		expect(failItems[1].name).toBe('No Priority');
		expect(warnItems[0].name).toBe('Warn Has Priority');
		expect(warnItems[1].name).toBe('Warn No Priority');
	});
});
