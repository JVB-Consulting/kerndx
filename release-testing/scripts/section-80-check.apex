// Section 80 — one job runner check, launched twice in parallel from the shell.
// The check is reached through the Schedulable interface the runner's global class implements: that is the
// reach a subscriber has, and it is the same entry the platform scheduler uses.
((Schedulable) new kern.SCHED_JobRunner()).execute(null);
