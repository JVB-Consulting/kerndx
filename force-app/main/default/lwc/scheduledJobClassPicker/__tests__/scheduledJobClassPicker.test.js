// SPDX-License-Identifier: Apache-2.0
/**
 * @description Jest unit tests for the scheduledJobClassPicker LWC component: what it suggests, the name it emits for a
 *              picked or typed class, the keyboard, and the error under the field.
 *
 * @author Jason van Beukering
 * @date October 2026
 */
import {createElement} from 'lwc';
import ScheduledJobClassPicker, {findListedClassName} from 'c/scheduledJobClassPicker';

const LISTED_NAMES = [
	'kern.SCHED_DeactivateUsers',
	'kern.SCHED_PurgeRecords',
	'SCHED_SubscriberJob'
];
const OPTIONS = LISTED_NAMES.map((name) => ({label: name, value: name}));
const UNLISTED_NAME = 'FastStart_ScheduledJob_DEMO';
const REFUSAL = 'No class named SCHED_NoSuchClass can be scheduled.';

function createPicker(properties = {})
{
	const element = createElement('c-scheduled-job-class-picker', {is: ScheduledJobClassPicker});
	Object.assign(element, {label: 'Class Name', placeholder: 'Type or select a class...', options: OPTIONS}, properties);
	document.body.appendChild(element);
	return element;
}

function inputOf(element)
{
	return element.shadowRoot.querySelector('input[role="combobox"]');
}

function suggestionsOf(element)
{
	return Array.from(element.shadowRoot.querySelectorAll('[role="option"]'));
}

function suggestedNames(element)
{
	return suggestionsOf(element).map((option) => option.dataset.value);
}

async function typeInto(element, text)
{
	const input = inputOf(element);
	input.value = text;
	input.dispatchEvent(new CustomEvent('input'));
	await Promise.resolve();
}

async function press(element, key)
{
	const event = new KeyboardEvent('keydown', {key, cancelable: true});
	inputOf(element).dispatchEvent(event);
	await Promise.resolve();
	return event;
}

async function leave(element, relatedTarget = null)
{
	const event = new CustomEvent('focusout');
	Object.defineProperty(event, 'relatedTarget', {value: relatedTarget});
	element.shadowRoot.querySelector('.slds-form-element').dispatchEvent(event);
	await Promise.resolve();
}

function listenForClassChange(element)
{
	const handler = jest.fn();
	element.addEventListener('classchange', handler);
	return handler;
}

describe('c-scheduled-job-class-picker', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
	});

	describe('findListedClassName', () =>
	{
		it.each([
			[
				'a listed name in another letter case',
				'KERN.sched_purgerecords',
				'kern.SCHED_PurgeRecords'
			],
			[
				'an unprefixed name that one listed name prefixes',
				'sched_purgerecords',
				'kern.SCHED_PurgeRecords'
			],
			[
				'an unprefixed listed name, before any prefixed one',
				'sched_subscriberjob',
				'SCHED_SubscriberJob'
			],
			[
				'an unlisted name, trimmed',
				`  ${UNLISTED_NAME}  `,
				UNLISTED_NAME
			],
			[
				'an unlisted prefixed name',
				'acme.SCHED_PurgeRecords',
				'acme.SCHED_PurgeRecords'
			],
			[
				'blank text',
				'   ',
				''
			],
			[
				'no text at all',
				undefined,
				''
			]
		])('returns the name to send for %s', (_case, typedName, expected) =>
		{
			expect(findListedClassName(typedName, LISTED_NAMES)).toBe(expected);
		});

		it('keeps an unprefixed name that two listed names prefix', () =>
		{
			expect(findListedClassName('SCHED_Job', [
				'kern.SCHED_Job',
				'acme.SCHED_Job'
			])).toBe('SCHED_Job');
		});
	});

	describe('rendering', () =>
	{
		it('shows the label, the placeholder and a required marker when required', () =>
		{
			const element = createPicker({required: true});
			expect(element.shadowRoot.querySelector('label').textContent).toContain('Class Name');
			expect(element.shadowRoot.querySelector('abbr.slds-required')).not.toBeNull();
			expect(inputOf(element).placeholder).toBe('Type or select a class...');
			expect(inputOf(element).getAttribute('aria-required')).toBe('true');
		});

		it('shows no required marker when not required', () =>
		{
			const element = createPicker();
			expect(element.shadowRoot.querySelector('abbr.slds-required')).toBeNull();
			expect(inputOf(element).getAttribute('aria-required')).toBe('false');
		});

		it('suggests every listed class when opened with nothing typed', async() =>
		{
			const element = createPicker();
			inputOf(element).click();
			await Promise.resolve();
			expect(suggestedNames(element)).toEqual(LISTED_NAMES);
			expect(element.shadowRoot.querySelector('.slds-combobox').classList).toContain('slds-is-open');
			expect(inputOf(element).getAttribute('aria-expanded')).toBe('true');
			expect(inputOf(element).getAttribute('aria-haspopup')).toBe('listbox');
			expect(inputOf(element).hasAttribute('aria-activedescendant')).toBe(false);
		});

		it('suggests every listed class while the text is the chosen name', async() =>
		{
			const element = createPicker({value: 'kern.SCHED_PurgeRecords'});
			inputOf(element).click();
			await Promise.resolve();
			expect(inputOf(element).value).toBe('kern.SCHED_PurgeRecords');
			expect(suggestedNames(element)).toEqual(LISTED_NAMES);
		});

		it('narrows the suggestions to names holding the typed text, in any letter case', async() =>
		{
			const element = createPicker();
			await typeInto(element, 'PURGE');
			expect(suggestedNames(element)).toEqual(['kern.SCHED_PurgeRecords']);
		});

		it('keeps the list closed when nothing matches', async() =>
		{
			const element = createPicker();
			await typeInto(element, 'zzz');
			expect(suggestedNames(element)).toEqual([]);
			expect(element.shadowRoot.querySelector('.slds-combobox').classList).not.toContain('slds-is-open');
		});

		it('shows the error under the field and marks the field invalid', () =>
		{
			const element = createPicker({errorMessage: REFUSAL});
			expect(element.shadowRoot.querySelector('[data-testid="class-name-error"]').textContent).toBe(REFUSAL);
			expect(element.shadowRoot.querySelector('.slds-form-element').classList).toContain('slds-has-error');
			expect(inputOf(element).getAttribute('aria-invalid')).toBe('true');
		});

		it('marks the field valid without an error', () =>
		{
			const element = createPicker();
			expect(element.shadowRoot.querySelector('.slds-form-element').classList).not.toContain('slds-has-error');
			expect(inputOf(element).getAttribute('aria-invalid')).toBe('false');
		});

		it('ignores options that are not a list, and options without a value', async() =>
		{
			const element = createPicker({options: 'not a list'});
			inputOf(element).click();
			await Promise.resolve();
			expect(suggestedNames(element)).toEqual([]);
			element.options = [
				null,
				{label: 'no value'},
				...OPTIONS
			];
			await Promise.resolve();
			expect(suggestedNames(element)).toEqual(LISTED_NAMES);
			expect(element.options).toEqual(OPTIONS);
		});

		it('shows an empty field for a missing value', () =>
		{
			const element = createPicker({value: null});
			expect(element.value).toBe('');
			expect(inputOf(element).value).toBe('');
		});
	});

	describe('committing a name', () =>
	{
		it('emits the picked suggestion, keeps the focus in the field and closes the list', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			inputOf(element).click();
			await Promise.resolve();
			const mouseDown = new CustomEvent('mousedown', {cancelable: true});
			element.shadowRoot.querySelector('[data-value="kern.SCHED_DeactivateUsers"]').dispatchEvent(mouseDown);
			await Promise.resolve();
			expect(mouseDown.defaultPrevented).toBe(true);
			expect(classChange).toHaveBeenCalledTimes(1);
			expect(classChange.mock.calls[0][0].detail.value).toBe('kern.SCHED_DeactivateUsers');
			expect(element.value).toBe('kern.SCHED_DeactivateUsers');
			expect(inputOf(element).getAttribute('aria-expanded')).toBe('false');
		});

		it('keeps the focus in the field and emits nothing when the list itself is pressed', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			await typeInto(element, 'sched');
			const mouseDown = new CustomEvent('mousedown', {cancelable: true});
			element.shadowRoot.querySelector('[role="listbox"]').dispatchEvent(mouseDown);
			await Promise.resolve();
			expect(mouseDown.defaultPrevented).toBe(true);
			expect(classChange).not.toHaveBeenCalled();
			expect(inputOf(element).value).toBe('sched');
		});

		it('emits a typed name the list does not show, trimmed, on Enter', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			await typeInto(element, `  ${UNLISTED_NAME} `);
			const enter = await press(element, 'Enter');
			expect(enter.defaultPrevented).toBe(true);
			expect(classChange.mock.calls[0][0].detail.value).toBe(UNLISTED_NAME);
			expect(inputOf(element).value).toBe(UNLISTED_NAME);
		});

		it('emits the typed name in the list spelling when focus leaves the field', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			await typeInto(element, 'sched_deactivateusers');
			await leave(element);
			expect(classChange.mock.calls[0][0].detail.value).toBe('kern.SCHED_DeactivateUsers');
		});

		it('emits nothing while focus stays inside the field', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			await typeInto(element, 'sched');
			await leave(element, inputOf(element));
			expect(classChange).not.toHaveBeenCalled();
		});

		it('emits nothing when the name is the current one, and tidies the text', async() =>
		{
			const element = createPicker({value: 'kern.SCHED_PurgeRecords'});
			const classChange = listenForClassChange(element);
			await typeInto(element, ' kern.SCHED_PurgeRecords ');
			await leave(element);
			expect(classChange).not.toHaveBeenCalled();
			expect(inputOf(element).value).toBe('kern.SCHED_PurgeRecords');
		});

		it('emits an empty name when the text is cleared', async() =>
		{
			const element = createPicker({value: 'kern.SCHED_PurgeRecords'});
			const classChange = listenForClassChange(element);
			await typeInto(element, '');
			await leave(element);
			expect(classChange.mock.calls[0][0].detail.value).toBe('');
		});
	});

	describe('keyboard', () =>
	{
		it('moves down the suggestions and picks the highlighted one on Enter', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			await press(element, 'ArrowDown');
			await press(element, 'ArrowDown');
			expect(inputOf(element).getAttribute('aria-activedescendant')).toBe(suggestionsOf(element)[1].id);
			expect(suggestionsOf(element)[1].getAttribute('aria-selected')).toBe('true');
			expect(suggestionsOf(element)[0].getAttribute('aria-selected')).toBe('false');
			await press(element, 'Enter');
			expect(classChange.mock.calls[0][0].detail.value).toBe('kern.SCHED_PurgeRecords');
		});

		it('starts from the last suggestion on ArrowUp and stops at the first', async() =>
		{
			const element = createPicker();
			await press(element, 'ArrowUp');
			expect(suggestionsOf(element)[2].getAttribute('aria-selected')).toBe('true');
			await press(element, 'ArrowUp');
			await press(element, 'ArrowUp');
			await press(element, 'ArrowUp');
			expect(suggestionsOf(element)[0].getAttribute('aria-selected')).toBe('true');
		});

		it('highlights nothing when nothing matches, and Enter takes the typed text', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			await typeInto(element, 'zzz');
			await press(element, 'ArrowDown');
			expect(inputOf(element).hasAttribute('aria-activedescendant')).toBe(false);
			await press(element, 'Enter');
			expect(classChange.mock.calls[0][0].detail.value).toBe('zzz');
		});

		it('closes the list on Escape without taking the text', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			await typeInto(element, 'sched');
			await press(element, 'Escape');
			expect(inputOf(element).getAttribute('aria-expanded')).toBe('false');
			expect(classChange).not.toHaveBeenCalled();
			expect(inputOf(element).value).toBe('sched');
		});

		it('takes the typed text, not a highlighted suggestion, once the list is closed', async() =>
		{
			const element = createPicker();
			const classChange = listenForClassChange(element);
			await typeInto(element, 'purge');
			await press(element, 'ArrowDown');
			await press(element, 'Escape');
			await press(element, 'Enter');
			expect(classChange.mock.calls[0][0].detail.value).toBe('purge');
		});

		it('leaves other keys to the input', async() =>
		{
			const element = createPicker();
			const event = await press(element, 'a');
			expect(event.defaultPrevented).toBe(false);
		});
	});
});
