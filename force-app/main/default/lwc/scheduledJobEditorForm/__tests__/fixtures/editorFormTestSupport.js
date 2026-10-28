// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Support shared by the Jest suites of the scheduled job form and of the two editors built on it. It
 *              lives under __tests__/fixtures, the folder the Jest configuration leaves out of the test run, so it
 *              can be imported by a suite without being one.
 *
 * @author Jason van Beukering
 *
 * @date October 2026
 */
/* global __dirname */
const fs = require('fs');
const path = require('path');

/**
 * @description The shipped text of the ClassNameNotSchedulable label, which the mock below resolves the label to. The
 *              name starts with "mock" so a jest.mock factory may read it; it is test copy, not text a subscriber sees.
 *
 * @type {string}
 */
		// eslint-disable-next-line kerndx/no-hardcoded-user-text
const mockClassNameNotSchedulableText = 'No class named {0} can be scheduled. Check the spelling, that the class is deployed to this org, and that it implements Schedulable.';

/**
 * @description The shipped text of the ScheduleWithTimezone label, which the mock below resolves the label to.
 *
 * @type {string}
 */
		// eslint-disable-next-line kerndx/no-hardcoded-user-text
const mockScheduleWithTimezoneText = 'Schedule ({0})';

/**
 * @description The fields a form holds when it is ready to save: a name, a class and a valid expression.
 *
 * @type {Object}
 */
export const READY_TO_SAVE = {schedulerName: 'Job', className: 'SCHED_Test', cronExpression: '0 0 12 * * ?'};

/**
 * @description Registers the virtual modules both editors import and the suites program: the four Apex methods of
 *              the shared form, the record fields it reads, and the two labels whose shipped text the assertions
 *              read. Call it before either component is required.
 */
export function registerScheduledJobFormMocks()
{
	jest.mock('@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses', () => ({default: jest.fn()}), {virtual: true});
	jest.mock('@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions', () => ({default: jest.fn()}), {virtual: true});
	jest.mock('@salesforce/apex/CTRL_ScheduledJob.getUserTimezone', () => ({default: jest.fn()}), {virtual: true});
	jest.mock('@salesforce/apex/CTRL_ScheduledJob.saveRecord', () => ({default: jest.fn()}), {virtual: true});

	jest.mock('@salesforce/schema/ScheduledJob__c.SchedulerName__c', () => ({default: 'ScheduledJob__c.SchedulerName__c'}), {virtual: true});
	jest.mock('@salesforce/schema/ScheduledJob__c.ClassName__c', () => ({default: 'ScheduledJob__c.ClassName__c'}), {virtual: true});
	jest.mock('@salesforce/schema/ScheduledJob__c.CronExpression__c', () => ({default: 'ScheduledJob__c.CronExpression__c'}), {virtual: true});
	jest.mock('@salesforce/schema/ScheduledJob__c.IsActive__c', () => ({default: 'ScheduledJob__c.IsActive__c'}), {virtual: true});
	jest.mock('@salesforce/schema/ScheduledJob__c.Description__c', () => ({default: 'ScheduledJob__c.Description__c'}), {virtual: true});
	jest.mock('@salesforce/schema/ScheduledJob__c.Parameters__c', () => ({default: 'ScheduledJob__c.Parameters__c'}), {virtual: true});
	jest.mock('@salesforce/schema/ScheduledJob__c.Timezone__c', () => ({default: 'ScheduledJob__c.Timezone__c'}), {virtual: true});

	// The two labels resolve to their shipped text so the heading's interpolation and the refusal under the class
	// field can be asserted as a subscriber reads them, rather than as the default 'c.X' stub.
	jest.mock('@salesforce/label/c.ScheduledJob_ScheduleWithTimezone', () => ({default: mockScheduleWithTimezoneText}), {virtual: true});
	jest.mock('@salesforce/label/c.ScheduledJob_ClassNameNotSchedulable', () => ({default: mockClassNameNotSchedulableText}), {virtual: true});
}

/**
 * @description The refusal the class field shows for a class name that cannot be scheduled.
 *
 * @param {string} className The refused class name.
 *
 * @return {string} The sentence with the class name filled in.
 */
export function classNameNotSchedulable(className)
{
	return mockClassNameNotSchedulableText.replace('{0}', className);
}

/**
 * @description Saves from a headless context built on a form ready to save, and returns that context for assertions on
 *              what the save sent and what followed it.
 *
 * @param {Object} prototype The component class prototype whose handleSave runs.
 * @param {Function} createMockContext The suite's context factory.
 * @param {Object} overrides State the test sets on top of the ready-to-save fields.
 * @param {boolean} hasParameterDefinitions Whether the context reports parameters to serialise.
 *
 * @return {Promise<Object>} The context the save ran on.
 */
export async function saveFrom(prototype, createMockContext, overrides = {}, hasParameterDefinitions = false)
{
	let context = createMockContext({...READY_TO_SAVE, ...overrides});
	Object.defineProperty(context, 'hasParameterDefinitions', {get: () => hasParameterDefinitions});
	Object.defineProperty(context, 'isCreateMode', {get: () => !context.recordId});
	await prototype.handleSave.call(context);
	return context;
}

/**
 * @description Lets pending promises settle, one microtask tick per iteration.
 *
 * @return {Promise<void>} Resolves after five ticks.
 */
export async function flushPromises()
{
	for(let index = 0; index < 5; index++)
	{
		// eslint-disable-next-line no-await-in-loop -- flush one microtask tick per iteration
		await Promise.resolve();
	}
}

/**
 * @description Finds a property's descriptor on a class prototype or on any class it extends, so a member the shared
 *              form declares is found through the editor built on it.
 *
 * @param {Object} prototype The component class prototype to start from.
 * @param {string} name The property name.
 *
 * @return {(PropertyDescriptor|undefined)} The descriptor, or undefined when no class in the chain declares it.
 */
export function findPropertyDescriptor(prototype, name)
{
	for(let current = prototype; current; current = Object.getPrototypeOf(current))
	{
		let descriptor = Object.getOwnPropertyDescriptor(current, name);

		if(descriptor)
		{
			return descriptor;
		}
	}

	return undefined;
}

/**
 * @description Reads a component bundle's template as text, for assertions on how the template is wired.
 *
 * @param {string} bundleName The bundle folder name, which is also the template's file name.
 *
 * @return {string} The template source.
 */
export function readBundleTemplate(bundleName)
{
	return fs.readFileSync(path.resolve(__dirname, '..', '..', '..', bundleName, bundleName + '.html'), 'utf8');
}

/**
 * @description Builds the plain context a prototype method is called on in a headless test: the shared form's state
 *              at its defaults, the shared form's save-path members as the real methods, so a call runs the real
 *              path, and the loaders as stubs the test programs.
 *
 * @param {Object} prototype The component class prototype whose real members the context borrows.
 * @param {Object} overrides State and stubs the test sets.
 *
 * @return {Object} The context.
 */
export function createFormContext(prototype, overrides = {})
{
	return {
		recordId: 'a00000000000001',
		schedulerName: '',
		className: '',
		classNameError: '',
		recordClassName: '',
		cronExpression: '',
		isActive: false,
		description: '',
		classOptions: [],
		parameterDefinitions: null,
		parameterValues: {},
		cronIsValid: true,
		isSaving: false,
		userTimezone: '',
		lastLoadedClassName: undefined,
		parameterRequestNumber: 0,
		applyRecord: prototype.applyRecord,
		buildSaveRequest: prototype.buildSaveRequest,
		completeSave: prototype.completeSave,
		reportSaveFailure: prototype.reportSaveFailure,
		loadParameterDefinitions: jest.fn(),
		loadSchedulableClasses: jest.fn().mockResolvedValue(),
		loadUserTimezone: jest.fn().mockResolvedValue(), ...overrides
	};
}
