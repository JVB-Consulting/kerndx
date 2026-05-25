// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for utilityLogger LWC utility module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, May 2026
 */

		// Mock the Apex method - create a trackable function
const mockPersistLogs = jest.fn().mockResolvedValue(undefined);
jest.mock('@salesforce/apex/CTRL_Logger.persistLogs', () =>
{
	return {
		__esModule: true, default: (...args) => mockPersistLogs(...args)
	};
}, {virtual: true});

// Note: c/utilityRandom is not mocked because sfdx-lwc-jest resolves it to the real module.
// Tests should verify behavior without relying on specific UUID values.

// Store original console methods
const originalConsole = {
	log: console.log, warn: console.warn, error: console.error, group: console.group, groupEnd: console.groupEnd
};

// Import after mocks are set up
import utilityLogger, {
	LogLevel, startCorrelation, endCorrelation, getCorrelationId, debug, info, warn, error, startTimer, withCorrelation, _flushLogs
} from 'c/utilityLogger';

describe('utilityLogger', () =>
{
	let mockPerformanceNow;
	let performanceTime;

	beforeEach(() =>
	{
		// Reset mocks
		jest.clearAllMocks();
		mockPersistLogs.mockReset();
		mockPersistLogs.mockResolvedValue(undefined);

		// Mock console methods
		console.log = jest.fn();
		console.warn = jest.fn();
		console.error = jest.fn();
		console.group = jest.fn();
		console.groupEnd = jest.fn();

		// Mock performance.now
		performanceTime = 0;
		mockPerformanceNow = jest.spyOn(performance, 'now').mockImplementation(() => performanceTime);

		// Reset module state by ending any active correlation
		// This is a workaround since module state persists between tests
		if(getCorrelationId())
		{
			endCorrelation();
		}
	});

	afterEach(() =>
	{
		// Restore console methods
		console.log = originalConsole.log;
		console.warn = originalConsole.warn;
		console.error = originalConsole.error;
		console.group = originalConsole.group;
		console.groupEnd = originalConsole.groupEnd;

		// Restore performance.now
		mockPerformanceNow.mockRestore();
	});

	describe('LogLevel', () =>
	{
		it('should have correct log level values', () =>
		{
			expect(LogLevel.DEBUG).toBe('DEBUG');
			expect(LogLevel.INFO).toBe('INFO');
			expect(LogLevel.WARN).toBe('WARN');
			expect(LogLevel.ERROR).toBe('ERROR');
		});

		it('should be frozen (immutable)', () =>
		{
			expect(Object.isFrozen(LogLevel)).toBe(true);
		});
	});

	describe('default export', () =>
	{
		it('should expose all public functions', () =>
		{
			expect(utilityLogger.LogLevel).toBeDefined();
			expect(utilityLogger.startCorrelation).toBe(startCorrelation);
			expect(utilityLogger.endCorrelation).toBe(endCorrelation);
			expect(utilityLogger.getCorrelationId).toBe(getCorrelationId);
			expect(utilityLogger.debug).toBe(debug);
			expect(utilityLogger.info).toBe(info);
			expect(utilityLogger.warn).toBe(warn);
			expect(utilityLogger.error).toBe(error);
			expect(utilityLogger.startTimer).toBe(startTimer);
			expect(utilityLogger.withCorrelation).toBe(withCorrelation);
		});
	});

	describe('debug', () =>
	{
		it('should log debug message to console', () =>
		{
			debug('Test debug message');
			expect(console.log).toHaveBeenCalledWith('[DEBUG] Test debug message', {});
		});

		it('should log debug message with data', () =>
		{
			debug('Debug with data', {key: 'value'});
			expect(console.log).toHaveBeenCalledWith('[DEBUG] Debug with data', {key: 'value'});
		});
	});

	describe('info', () =>
	{
		it('should log info message to console', () =>
		{
			info('Test info message');
			expect(console.log).toHaveBeenCalledWith('[INFO] Test info message', {});
		});

		it('should log info message with data', () =>
		{
			info('Info with data', {userId: '123'});
			expect(console.log).toHaveBeenCalledWith('[INFO] Info with data', {userId: '123'});
		});
	});

	describe('warn', () =>
	{
		it('should log warning message to console', () =>
		{
			warn('Test warning message');
			expect(console.warn).toHaveBeenCalledWith('[WARN] Test warning message', {});
		});

		it('should log warning message with data', () =>
		{
			warn('Warning with data', {attempt: 2});
			expect(console.warn).toHaveBeenCalledWith('[WARN] Warning with data', {attempt: 2});
		});
	});

	describe('error', () =>
	{
		it('should log error message to console', () =>
		{
			error('Test error message');
			expect(console.error).toHaveBeenCalledWith('[ERROR] Test error message', {});
		});

		it('should log error message with data object', () =>
		{
			error('Error with data', {code: 500});
			expect(console.error).toHaveBeenCalledWith('[ERROR] Error with data', {code: 500});
		});

		it('should extract message and stack from Error object', () =>
		{
			const testError = new Error('Something went wrong');
			testError.stack = 'Error: Something went wrong\n    at test.js:1:1';
			error('Caught exception', testError);
			expect(console.error).toHaveBeenCalledWith('[ERROR] Caught exception', {
				errorMessage: 'Something went wrong', errorStack: testError.stack
			});
		});

		it('should flush logs immediately on error', async() =>
		{
			error('Critical failure');

			await Promise.resolve();

			expect(mockPersistLogs).toHaveBeenCalledTimes(1);
			const entries = JSON.parse(mockPersistLogs.mock.calls[0][0].entriesJson);
			expect(entries).toHaveLength(1);
			expect(entries[0].level).toBe('ERROR');
			expect(entries[0].message).toBe('Critical failure');
		});
	});

	describe('startTimer', () =>
	{
		it('should return timer object with stop method', () =>
		{
			const timer = startTimer('testOperation');
			expect(timer).toBeDefined();
			expect(typeof timer.stop).toBe('function');
		});

		it('should measure elapsed time', () =>
		{
			performanceTime = 0;
			const timer = startTimer('fetchData');

			// Simulate 150ms elapsed
			performanceTime = 150;
			const duration = timer.stop();

			expect(duration).toBe(150);
			expect(console.log).toHaveBeenCalledWith('[DEBUG] [PERF] fetchData: 150ms', {operationName: 'fetchData', durationMs: 150});
		});

		it('should include additional data in stop', () =>
		{
			performanceTime = 0;
			const timer = startTimer('loadAccounts');

			performanceTime = 200;
			timer.stop({count: 25});

			expect(console.log).toHaveBeenCalledWith('[DEBUG] [PERF] loadAccounts: 200ms', {operationName: 'loadAccounts', durationMs: 200, count: 25});
		});

		it('should round duration to nearest millisecond', () =>
		{
			performanceTime = 0;
			const timer = startTimer('operation');

			performanceTime = 123.789;
			const duration = timer.stop();

			expect(duration).toBe(124);
		});
	});

	describe('correlation tracking', () =>
	{
		describe('startCorrelation', () =>
		{
			it('should generate and return correlation ID', () =>
			{
				const correlationId = startCorrelation('Test Action');
				expect(correlationId).toBeDefined();
				expect(typeof correlationId).toBe('string');
				expect(correlationId.length).toBeGreaterThan(0);
			});

			it('should set current correlation ID', () =>
			{
				const correlationId = startCorrelation('Test Action');
				expect(getCorrelationId()).toBe(correlationId);
			});

			it('should log start message', () =>
			{
				startCorrelation('Save Record');
				expect(console.log).toHaveBeenCalledWith('[INFO] [Save Record] Started', expect.any(Object));
			});

			it('should include context in logs', () =>
			{
				startCorrelation('Update Account', {accountId: '001xx'});
				expect(console.log).toHaveBeenCalled();
			});
		});

		describe('endCorrelation', () =>
		{
			it('should log completion with duration', () =>
			{
				performanceTime = 0;
				startCorrelation('Load Data');

				performanceTime = 500;
				endCorrelation();

				expect(console.log).toHaveBeenCalledWith('[INFO] [Load Data] Completed in 500ms', expect.objectContaining({durationMs: 500}));
			});

			it('should clear correlation ID', () =>
			{
				startCorrelation('Action');
				expect(getCorrelationId()).not.toBeNull();

				endCorrelation();
				expect(getCorrelationId()).toBeNull();
			});

			it('should include result data in log', () =>
			{
				performanceTime = 0;
				startCorrelation('Save');

				performanceTime = 100;
				endCorrelation({success: true, recordId: '001xx'});

				expect(console.log).toHaveBeenCalledWith('[INFO] [Save] Completed in 100ms', expect.objectContaining({
					success: true, recordId: '001xx'
				}));
			});

			it('should flush logs to server', async() =>
			{
				startCorrelation('Action');
				endCorrelation();

				// Wait for async flush to complete
				await Promise.resolve();

				expect(mockPersistLogs).toHaveBeenCalledWith({
					entriesJson: expect.any(String)
				});
			});

			it('should do nothing if no correlation active', () =>
			{
				// Ensure no correlation is active
				expect(getCorrelationId()).toBeNull();

				endCorrelation();

				// Should not throw and should not call persist
				expect(mockPersistLogs).not.toHaveBeenCalled();
			});
		});

		describe('getCorrelationId', () =>
		{
			it('should return null when no correlation active', () =>
			{
				expect(getCorrelationId()).toBeNull();
			});

			it('should return current ID when correlation active', () =>
			{
				const correlationId = startCorrelation('Test');
				expect(getCorrelationId()).toBe(correlationId);
				endCorrelation();
			});
		});
	});

	describe('withCorrelation', () =>
	{
		it('should wrap async function with correlation', async() =>
		{
			const asyncFn = jest.fn().mockResolvedValue('result');

			performanceTime = 0;
			const result = await withCorrelation('Fetch Data', asyncFn);
			performanceTime = 100;

			expect(result).toBe('result');
			expect(asyncFn).toHaveBeenCalledWith(expect.any(String));
			// Verify the correlation ID is a valid UUID-like string
			const passedCorrelationId = asyncFn.mock.calls[0][0];
			expect(passedCorrelationId.length).toBeGreaterThan(0);
		});

		it('should pass context to correlation', async() =>
		{
			const asyncFn = jest.fn().mockResolvedValue('ok');

			await withCorrelation('Save', asyncFn, {recordType: 'Account'});

			expect(asyncFn).toHaveBeenCalled();
		});

		it('should end correlation with success on completion', async() =>
		{
			const asyncFn = jest.fn().mockResolvedValue('done');

			await withCorrelation('Operation', asyncFn);

			// Check that completion was logged with success
			expect(console.log).toHaveBeenCalledWith(expect.stringContaining('Completed'), expect.objectContaining({success: true}));
		});

		it('should end correlation with failure on error', async() =>
		{
			const testError = new Error('Test error');
			const asyncFn = jest.fn().mockRejectedValue(testError);

			await expect(withCorrelation('Failing Op', asyncFn)).rejects.toThrow('Test error');

			// Check error was logged
			expect(console.error).toHaveBeenCalledWith(expect.stringContaining('[Failing Op] Failed'), expect.any(Object));

			// Check correlation ended with failure
			expect(console.log).toHaveBeenCalledWith(expect.stringContaining('Completed'), expect.objectContaining({success: false}));
		});

		it('should re-throw errors from async function', async() =>
		{
			const asyncFn = jest.fn().mockRejectedValue(new Error('Original error'));

			await expect(withCorrelation('Action', asyncFn)).rejects.toThrow('Original error');
		});

		it('should clear correlation ID after completion', async() =>
		{
			await withCorrelation('Action', async() => 'done');

			expect(getCorrelationId()).toBeNull();
		});

		it('should clear correlation ID after error', async() =>
		{
			const asyncFn = jest.fn().mockRejectedValue(new Error('fail'));

			try
			{
				await withCorrelation('Action', asyncFn);
			}
			catch
			{
				// Expected
			}

			expect(getCorrelationId()).toBeNull();
		});
	});

	describe('log persistence', () =>
	{
		it('should buffer logs and persist on endCorrelation', async() =>
		{
			startCorrelation('Action');
			info('Step 1');
			info('Step 2');
			debug('Debug info');
			endCorrelation();

			// Wait for async flush to complete
			await Promise.resolve();

			expect(mockPersistLogs).toHaveBeenCalledTimes(1);
			const entries = JSON.parse(mockPersistLogs.mock.calls[0][0].entriesJson);
			// start + step1 + step2 + debug + completion = 5 entries
			expect(entries.length).toBe(5);
		});

		it('should handle persistence failure gracefully', async() =>
		{
			mockPersistLogs.mockRejectedValue(new Error('Network error'));

			startCorrelation('Action');
			info('Test message');
			endCorrelation();

			// Wait for promise rejection to be handled
			await new Promise(resolve => setTimeout(resolve, 10));

			// Should log fallback to console
			expect(console.error).toHaveBeenCalledWith('[utilityLogger] Server persistence failed:', expect.any(Error));
			expect(console.group).toHaveBeenCalledWith('[utilityLogger] Buffered entries:');
			expect(console.groupEnd).toHaveBeenCalled();
		});

		it('should handle persistence failure with entries lacking correlationId', async() =>
		{
			mockPersistLogs.mockRejectedValue(new Error('Network error'));

			// Log without starting a correlation - entry will have null correlationId
			info('Standalone message');

			// Use _flushLogs to trigger the persist (normally would happen via endCorrelation)
			_flushLogs();

			// Wait for promise rejection to be handled
			await new Promise(resolve => setTimeout(resolve, 10));

			// Should log fallback to console with 'no-correlation' for null correlationId
			// This tests line 299: entry.correlationId || 'no-correlation'
			// INFO level maps to console.log (via getConsoleMethod)
			expect(console.error).toHaveBeenCalledWith('[utilityLogger] Server persistence failed:', expect.any(Error));
			expect(console.log).toHaveBeenCalledWith(expect.stringContaining('no-correlation'), expect.any(String));
		});

		it('should not persist empty log buffer', async() =>
		{
			// End correlation without starting one (buffer should be empty)
			endCorrelation();

			// Wait for any potential async operations
			await Promise.resolve();

			expect(mockPersistLogs).not.toHaveBeenCalled();
		});
	});

	describe('log entry structure', () =>
	{
		it('should include timestamp in log entries', async() =>
		{
			startCorrelation('Action');
			endCorrelation();

			await Promise.resolve();

			const entries = JSON.parse(mockPersistLogs.mock.calls[0][0].entriesJson);
			entries.forEach(entry =>
			{
				expect(entry.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
			});
		});

		it('should include level in log entries', async() =>
		{
			startCorrelation('Action');
			debug('debug');
			info('info');
			warn('warn');
			error('error');
			endCorrelation();

			await Promise.resolve();

			const entries = JSON.parse(mockPersistLogs.mock.calls[0][0].entriesJson);
			const levels = entries.map(e => e.level);
			expect(levels).toContain('DEBUG');
			expect(levels).toContain('INFO');
			expect(levels).toContain('WARN');
			expect(levels).toContain('ERROR');
		});

		it('should include correlation ID in log entries', async() =>
		{
			const correlationId = startCorrelation('Action');
			info('Correlated message');
			endCorrelation();

			await Promise.resolve();

			const entries = JSON.parse(mockPersistLogs.mock.calls[0][0].entriesJson);
			entries.forEach(entry =>
			{
				expect(entry.correlationId).toBe(correlationId);
			});
		});

		it('should have null correlation ID for logs outside correlation', async() =>
		{
			// Log without correlation
			info('Standalone message');

			// Start and end correlation to flush
			startCorrelation('Flush');
			endCorrelation();

			await Promise.resolve();

			const entries = JSON.parse(mockPersistLogs.mock.calls[0][0].entriesJson);
			// First entry should have null correlationId
			expect(entries[0].correlationId).toBeNull();
		});
	});

	describe('_flushLogs (test utility)', () =>
	{
		it('should export _flushLogs function', () =>
		{
			expect(typeof _flushLogs).toBe('function');
			expect(typeof utilityLogger._flushLogs).toBe('function');
		});

		it('should handle empty buffer gracefully', async() =>
		{
			// Ensure no active correlation and buffer is empty
			if(getCorrelationId())
			{
				endCorrelation();
				await Promise.resolve();
			}
			mockPersistLogs.mockClear();

			// Call flush with empty buffer - should return early without calling persistLogs
			_flushLogs();
			await Promise.resolve();

			// persistLogs should NOT be called when buffer is empty
			expect(mockPersistLogs).not.toHaveBeenCalled();
		});
	});

});

/*
 * The @lwc/jest-transformer rewrites `import persistLogs from '@salesforce/apex/...'`
 * into a try/catch. If the require succeeds the catch is never entered, leaving
 * the catch's `global.__lwcJestMock_persistLogs || function...` binary expression
 * with both branches uncovered. The two tests below force the catch to run —
 * once with the global pre-populated (LHS truthy) and once without (RHS wins) —
 * so every generated branch fires exactly once.
 */
describe('utilityLogger apex-stub fallback (jest-transformer catch block)', () =>
{
	afterEach(() =>
	{
		jest.resetModules();
		delete global.__lwcJestMock_persistLogs;
	});

	it('uses the pre-set global.__lwcJestMock_persistLogs when present', () =>
	{
		const fallback = jest.fn().mockResolvedValue(undefined);
		global.__lwcJestMock_persistLogs = fallback;

		let loaded;
		jest.isolateModules(() =>
		{
			jest.doMock('@salesforce/apex/CTRL_Logger.persistLogs', () =>
			{
				throw new Error('forced require failure');
			}, {virtual: true});
			loaded = require('c/utilityLogger');
		});

		expect(loaded).toBeDefined();
		expect(typeof loaded.info).toBe('function');
		expect(global.__lwcJestMock_persistLogs).toBe(fallback);
	});

	it('generates the stub function when the global is empty', () =>
	{
		delete global.__lwcJestMock_persistLogs;

		let loaded;
		jest.isolateModules(() =>
		{
			jest.doMock('@salesforce/apex/CTRL_Logger.persistLogs', () =>
			{
				throw new Error('forced require failure');
			}, {virtual: true});
			loaded = require('c/utilityLogger');
		});

		expect(loaded).toBeDefined();
		expect(typeof global.__lwcJestMock_persistLogs).toBe('function');
	});
});
