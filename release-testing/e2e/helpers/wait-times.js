// SPDX-License-Identifier: Apache-2.0

// How long a page object or helper waits for one element, toast or dialog to reach the state it needs. Every such wait
// uses this value; a wait that genuinely needs longer (a run that has to finish, a job that has to drain) names its own.
const ELEMENT_WAIT_MILLISECONDS = 15_000;

module.exports = {ELEMENT_WAIT_MILLISECONDS};
