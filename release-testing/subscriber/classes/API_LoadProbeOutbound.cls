// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Outbound API handler for the load probe callout-storm test. Accepts a {@code failRate}
 * parameter (0-100) and simulates failures at the specified probability using
 * {@code Crypto.getRandomInteger()} — no real HTTP callout is made. Intended to be invoked via
 * UTIL_HttpClient delegation mode from {@link API_LoadProbe}.
 *
 * All responses are mock-driven: when no credential is present and {@code defaultMockBody} is set,
 * the framework automatically enables mocking for the service name. Failure simulation injects a
 * validation error proportional to {@code failRate}, causing the call to abort. The load test
 * harness uses the abort rate to verify circuit breaker and retry behavior under parallel load.
 *
 * @see API_LoadProbe
 * @see kern.UTIL_HttpClient
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date May 2026
 */
public with sharing class API_LoadProbeOutbound extends kern.API_Outbound
{
	/**
	 * @description Parameter name for the failure probability (0-100).
	 */
	@TestVisible
	static final String PARAM_FAIL_RATE = 'failRate';

	/**
	 * @description Validation error message returned when a simulated failure is triggered.
	 */
	private static final String ERROR_SIMULATED_FAILURE = 'simulated failure (load probe)';

	/**
	 * @description Initialises the handler. Sets {@code requiresTriggeringRecord = false} in
	 * {@code configure()} rather than as a field initializer, to avoid the Apex pitfall where
	 * child field initializers run after the parent constructor and can overwrite values assigned
	 * during construction.
	 *
	 * {@code defaultMockBody} drives the success-path response. When no credential override is
	 * provided and {@code defaultMockBody} is non-null, the framework activates mock mode for
	 * this service name automatically.
	 */
	public override void configure()
	{
		super.configure();
		requiresTriggeringRecord = false;
		defaultMockBody = '{"echoed":true}';
	}

	/**
	 * @description Declares {@code failRate} as a required input so the framework aborts the
	 * call early with a clear validation error if the parameter is absent or blank.
	 *
	 * @return A set containing the name of each required parameter.
	 */
	public override Set<String> getRequiredInputs()
	{
		Set<String> required = super.getRequiredInputs();
		required.add(PARAM_FAIL_RATE);
		return required;
	}

	/**
	 * @description Conditionally injects a simulated failure based on the {@code failRate}
	 * parameter. Uses {@code Crypto.getRandomInteger()} to produce a uniformly distributed
	 * random outcome: if the absolute value mod 100 is less than {@code failRate}, a
	 * "simulated failure" validation error is appended, causing the call to be aborted.
	 *
	 * @return A list of validation error messages. Empty means validation passed.
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = super.getValidationErrors();

		String failRateValue = inputs.get(PARAM_FAIL_RATE);
		Integer failRate = String.isNotBlank(failRateValue) ? Integer.valueOf(failRateValue) : 0;

		if(failRate > 0 && Math.mod(Math.abs(Crypto.getRandomInteger()), 100) < failRate)
		{
			errors.add(ERROR_SIMULATED_FAILURE);
		}

		return errors;
	}
}
