// SPDX-License-Identifier: BUSL-1.1
import {LightningElement} from 'lwc';
import utilityLogger from 'kern/utilityLogger';

export default class SubscriberLoggerTest extends LightningElement
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	async runAllTests()
	{
		const checks = [];

		checks.push(...this.testLoggerApiSurface());
		checks.push(...this.testCustomContext());
		checks.push(...this.testCorrelationLifecycle());
		checks.push(...this.testTimerApi());
		checks.push(await this.testWithCorrelation());
		checks.push(await this.testErrorWithContext());

		this.results = checks.map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}

	testLoggerApiSurface()
	{
		const checks = [];

		checks.push({name: 'info exists', pass: typeof utilityLogger.info === 'function'});
		checks.push({name: 'error exists', pass: typeof utilityLogger.error === 'function'});
		checks.push({name: 'warn exists', pass: typeof utilityLogger.warn === 'function'});
		checks.push({name: 'debug exists', pass: typeof utilityLogger.debug === 'function'});
		checks.push({name: 'startCorrelation exists', pass: typeof utilityLogger.startCorrelation === 'function'});
		checks.push({name: 'endCorrelation exists', pass: typeof utilityLogger.endCorrelation === 'function'});
		checks.push({name: 'getCorrelationId exists', pass: typeof utilityLogger.getCorrelationId === 'function'});
		checks.push({name: 'startTimer exists', pass: typeof utilityLogger.startTimer === 'function'});
		checks.push({name: 'withCorrelation exists', pass: typeof utilityLogger.withCorrelation === 'function'});
		checks.push({name: '_flushLogs exists', pass: typeof utilityLogger._flushLogs === 'function'});

		return checks;
	}

	testCustomContext()
	{
		const checks = [];

		try
		{
			utilityLogger.info('Subscriber info with context', {recordId: '001xx0000000001', componentName: 'subscriberLoggerTest'});
			checks.push({name: 'info with custom context', pass: true});
		}
		catch(e)
		{
			checks.push({name: 'info with custom context', pass: false});
		}

		try
		{
			utilityLogger.warn('Subscriber warning with context', {severity: 'medium', field: 'Industry'});
			checks.push({name: 'warn with custom context', pass: true});
		}
		catch(e)
		{
			checks.push({name: 'warn with custom context', pass: false});
		}

		try
		{
			utilityLogger.debug('Subscriber debug with context', {queryCount: 5, cacheHit: true});
			checks.push({name: 'debug with custom context', pass: true});
		}
		catch(e)
		{
			checks.push({name: 'debug with custom context', pass: false});
		}

		return checks;
	}

	testCorrelationLifecycle()
	{
		const checks = [];

		const correlationId = utilityLogger.startCorrelation('SubscriberSaveAccount', {recordType: 'Customer'});
		checks.push({name: 'startCorrelation returns ID', pass: typeof correlationId === 'string' && correlationId.length > 0});

		const activeId = utilityLogger.getCorrelationId();
		checks.push({name: 'getCorrelationId matches', pass: activeId === correlationId});

		utilityLogger.info('Processing account', {step: 'validation'});
		utilityLogger.info('Account validated', {step: 'complete'});

		utilityLogger.endCorrelation({success: true});

		const afterEnd = utilityLogger.getCorrelationId();
		checks.push({name: 'endCorrelation clears ID', pass: afterEnd === null});

		return checks;
	}

	testTimerApi()
	{
		const checks = [];

		const timer = utilityLogger.startTimer('SubscriberDataLoad');
		checks.push({name: 'startTimer returns object', pass: timer !== null && typeof timer.stop === 'function'});

		const duration = timer.stop({recordCount: 42});
		checks.push({name: 'timer.stop returns number', pass: typeof duration === 'number' && duration >= 0});

		return checks;
	}

	async testWithCorrelation()
	{
		try
		{
			const result = await utilityLogger.withCorrelation('SubscriberApexCall', async(correlationId) =>
			{
				utilityLogger.info('Inside correlated operation', {correlationId});
				return {success: true, correlationId};
			}, {context: 'subscriber-test'});

			return {name: 'withCorrelation wrapper', pass: result.success === true && typeof result.correlationId === 'string'};
		}
		catch(e)
		{
			return {name: 'withCorrelation wrapper', pass: false};
		}
	}

	async testErrorWithContext()
	{
		try
		{
			utilityLogger.error('Subscriber error with context', {errorCode: 'FIELD_CUSTOM_VALIDATION_EXCEPTION', objectType: 'Account'});
			return {name: 'error with custom context', pass: true};
		}
		catch(e)
		{
			return {name: 'error with custom context', pass: false};
		}
	}

	async testPersistence()
	{
		utilityLogger.startCorrelation('SubscriberPersistenceTest', {actionName: 'SubscriberPersistenceTest'});
		utilityLogger.info('Subscriber LWC persistence test — info level', {testSection: 'section-19', level: 'INFO'});
		utilityLogger.warn('Subscriber LWC persistence test — warn level', {testSection: 'section-19', level: 'WARN'});
		utilityLogger.error('Subscriber LWC persistence test — error level', {testSection: 'section-19', level: 'ERROR'});
		utilityLogger.debug('Subscriber LWC persistence test — debug level', {testSection: 'section-19', level: 'DEBUG'});
		utilityLogger.endCorrelation({success: true, testComplete: true});
	}
}
