// Runbook section 89: close the circuit breaker of the RetryLiveGet handler, or only read its state.
//
// Token:
//   __ACTION__  reset: close the breaker (as section 84b's clean-up does), then print its state. read: print its state
//               only. The driver runs reset and then read, in a second transaction, to prove the breaker stayed closed.
//
// The breaker counts the failed sends of section 89's calls, and an open breaker would refuse the next section's sends.
// Prints one line: SECTION89 BREAKER circuit=<name> state=<CLOSED, OPEN or HALF_OPEN>.
//
// Run: sf apex run -o <org alias> -f <rendered copy with the token replaced> --json > <file>
final String ACTION = '__ACTION__';
final String CIRCUIT = API_RetryLiveGet.class.getName();

if(ACTION == 'reset')
{
	kern.UTIL_CircuitBreaker.monitor(CIRCUIT).reset();
}
System.debug('SECTION89 BREAKER circuit=' + CIRCUIT + ' state=' + kern.UTIL_CircuitBreaker.monitor(CIRCUIT).getState());
