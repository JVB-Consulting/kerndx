// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the jobRunnerCard LWC component.
 *
 * @author Jason van Beukering
 * @date September 2026
 */
import {createElement} from 'lwc';
import JobRunnerCard from 'c/jobRunnerCard';

// Restore the real English values for the bundle's labels (the default sfdx-lwc-jest stub
// resolves each to the bare string 'c.<Name>') so rendering assertions verify the shipped copy.
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_CardTitle', () => ({default: 'Job runner'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_Inactive', () => ({
	default: 'The job runner is not active. Every scheduled job uses its own platform slot.'
}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_ActiveSummary', () => ({
	default: 'Checks for due jobs every {0} minutes, using {1} of the org\'s 100 scheduled-job slots.'
}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_Activator', () => ({default: 'Runs jobs as {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_ActivatorInactiveBadge', () => ({default: 'user inactive'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_ActivatorAdvice', () => ({
	default: 'Jobs on the runner run as the user who activated it. Activate it as an integration user that holds the Manage Job Runner permission and the '
			+ 'permissions every job needs.'
}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_Capacity_Slots', () => ({
	default: '{0} of 100 scheduled-job slots are in use: {1} for the job runner, {2} for Scheduled Job records with their own slot, {3} for everything else.'
}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_LastCheck', () => ({default: 'The job runner last checked for due jobs at {0}.'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_ActivateButton', () => ({default: 'Activate'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_RepairButton', () => ({default: 'Repair'}), {virtual: true});
jest.mock('@salesforce/label/c.HealthCheck_JobRunner_DeactivateButton', () => ({default: 'Deactivate'}), {virtual: true});

const LAST_CHECK_AT = '2026-09-11T14:15:00.000Z';

const ACTIVE_STATUS = {
	isActive: true,
	checkIntervalMinutes: 15,
	slotCost: 4,
	runnerRecordCount: 4,
	liveCronTriggerCount: 4,
	activatorName: 'Integration User',
	isActivatorActive: true,
	lastCheckAt: LAST_CHECK_AT,
	totalScheduledApexSlots: 9,
	jobRunnerSlots: 4,
	ownModeSlots: 3,
	otherSlots: 2,
	waitingJobCount: 2,
	canManage: true,
	runningUserName: 'Admin'
};

const INACTIVE_STATUS = {
	...ACTIVE_STATUS, isActive: false, checkIntervalMinutes: null, slotCost: 0, runnerRecordCount: 0, liveCronTriggerCount: 0, activatorName: null, jobRunnerSlots: 0
};

describe('c-job-runner-card', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	const mount = (status) =>
	{
		const element = createElement('c-job-runner-card', {is: JobRunnerCard});
		element.status = status;
		document.body.appendChild(element);
		return element;
	};

	const readParagraphOrder = (element) =>
	{
		return [...element.shadowRoot.querySelectorAll('p[data-testid]')].map((paragraph) => paragraph.getAttribute('data-testid'));
	};

	it('renders the inactive state as the summary, the running-user advice and Activate', () =>
	{
		const element = mount(INACTIVE_STATUS);

		expect(element.shadowRoot.querySelector('[data-testid="job-runner-summary"]').textContent)
		.toBe('The job runner is not active. Every scheduled job uses its own platform slot.');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-advice"]').textContent).toContain('Jobs on the runner run as the user who activated it.');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-activate"]').label).toBe('Activate');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-activator"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-slots"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-last-check"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-repair"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-deactivate"]')).toBeNull();
	});

	it('renders the active state as the summary, the activator, the slot breakdown and the last check, with both actions', () =>
	{
		const element = mount(ACTIVE_STATUS);

		expect(readParagraphOrder(element)).toEqual([
			'job-runner-summary',
			'job-runner-activator',
			'job-runner-slots',
			'job-runner-last-check'
		]);
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-summary"]').textContent)
		.toBe('Checks for due jobs every 15 minutes, using 4 of the org\'s 100 scheduled-job slots.');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-activator"]').textContent).toContain('Runs jobs as Integration User');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-slots"]').textContent)
		.toBe('9 of 100 scheduled-job slots are in use: 4 for the job runner, 3 for Scheduled Job records with their own slot, 2 for everything else.');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-last-check"]').textContent).toContain('The job runner last checked for due jobs at');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-advice"]')).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-repair"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-deactivate"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-activate"]')).toBeNull();
	});

	it('marks an inactive activator and hides the actions without the permission', () =>
	{
		const element = mount({...ACTIVE_STATUS, isActivatorActive: false, canManage: false});

		expect(element.shadowRoot.querySelector('[data-testid="job-runner-activator"]').textContent).toContain('user inactive');
		expect(element.shadowRoot.querySelectorAll('lightning-button').length).toBe(0);
	});

	it('leaves the activator and last-check lines empty when the status carries neither', () =>
	{
		const element = mount({...ACTIVE_STATUS, activatorName: null, lastCheckAt: null});

		expect(element.shadowRoot.querySelector('[data-testid="job-runner-activator"]').textContent.trim()).toBe('');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-last-check"]').textContent).toBe('');
	});

	it('counts any slot number the status leaves out as zero', () =>
	{
		const element = mount({...ACTIVE_STATUS, totalScheduledApexSlots: null, jobRunnerSlots: null, ownModeSlots: null, otherSlots: null});

		expect(element.shadowRoot.querySelector('[data-testid="job-runner-slots"]').textContent)
		.toBe('0 of 100 scheduled-job slots are in use: 0 for the job runner, 0 for Scheduled Job records with their own slot, 0 for everything else.');
	});

	it('reads as an inactive runner with no actions when no status has arrived yet', () =>
	{
		const element = mount(undefined);

		expect(element.shadowRoot.querySelector('[data-testid="job-runner-summary"]').textContent)
		.toBe('The job runner is not active. Every scheduled job uses its own platform slot.');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-advice"]')).not.toBeNull();
		expect(element.shadowRoot.querySelectorAll('lightning-button').length).toBe(0);
	});

	it('renders the card title and the shipped button labels', () =>
	{
		const element = mount(ACTIVE_STATUS);

		expect(element.shadowRoot.querySelector('[data-testid="job-runner-card"]').title).toBe('Job runner');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-repair"]').label).toBe('Repair');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-deactivate"]').label).toBe('Deactivate');
		expect(element.shadowRoot.querySelector('[data-testid="job-runner-deactivate"]').variant).toBeUndefined();
	});

	it('fires activate, repair and deactivate', () =>
	{
		const activeElement = mount(ACTIVE_STATUS);
		const seen = [];
		const listen = (element) =>
		{
			for(const name of [
				'activate',
				'repair',
				'deactivate'
			])
			{
				element.addEventListener(name, () => seen.push(name));
			}
		};

		listen(activeElement);
		activeElement.shadowRoot.querySelector('[data-testid="job-runner-repair"]').click();
		activeElement.shadowRoot.querySelector('[data-testid="job-runner-deactivate"]').click();

		const inactiveElement = mount(INACTIVE_STATUS);
		listen(inactiveElement);
		inactiveElement.shadowRoot.querySelector('[data-testid="job-runner-activate"]').click();

		expect(seen).toEqual([
			'repair',
			'deactivate',
			'activate'
		]);
	});
});
