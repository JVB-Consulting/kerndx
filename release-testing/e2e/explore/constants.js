// SPDX-License-Identifier: BUSL-1.1
// The exploration's constants: the paths it reads and writes, the console's own address keys and
// defaults, the widths, the generator's numbers, the polling allowances and the column sets built from
// the shipped labels. Every module of the exploration reads from here; nothing here reads the org.
'use strict';

const path = require('path');
const {readShippedLabelValues} = require('../lib/shipped-labels');
const {authPathsFor} = require('../helpers/auth-paths');

const E2E_DIRECTORY = path.join(__dirname, '..');
const REPOSITORY_ROOT = path.join(E2E_DIRECTORY, '..', '..');
const TEARDOWN_SCRIPT = path.join(E2E_DIRECTORY, '..', 'scripts', 'teardown-log-console.apex');
// The run's own org folder, so an exploration never reads the session of a run against another org.
const AUTH_STATE_PATH = authPathsFor().statePath;
const OUTPUT_DIRECTORY = path.join(REPOSITORY_ROOT, 'tmp', 'plan166');
const SCREENSHOT_DIRECTORY = path.join(OUTPUT_DIRECTORY, 'exploration');
const FINDINGS_PATH = path.join(OUTPUT_DIRECTORY, 'exploration-findings.md');
const TIMINGS_PATH = path.join(OUTPUT_DIRECTORY, 'timings.json');

// The margin the Chain Monitor widens a run's log window by on either side (chainMonitorDetail.js
// LOG_WINDOW_MARGIN_MILLISECONDS), so the exploration can work out the window a View logs hand-off
// owes from the run's own recorded bounds rather than from the address it is checking.
const RUN_WINDOW_MARGIN_MILLISECONDS = 60_000;

// The console's own address keys (logConsole.js HANDOFF_STATE_KEYS).
const STATE_KEY_ACTION = 'c__rootCorrelationId';
const STATE_KEY_CHAIN = 'c__correlationId';
const STATE_KEY_WINDOW_START = 'c__windowStart';
const STATE_KEY_WINDOW_END = 'c__windowEnd';
const STATE_KEY_STAMP = 'c__viewLogsAt';
const CONSOLE_STATE_KEYS = [STATE_KEY_ACTION, STATE_KEY_CHAIN, STATE_KEY_WINDOW_START, STATE_KEY_WINDOW_END, STATE_KEY_STAMP];

// The console's own level and range defaults (logConsole.js), mirrored so the model can say which
// rows a state should be showing.
const ALL_LEVELS = ['ERROR', 'WARN', 'INFO', 'DEBUG'];
const DEFAULT_LEVELS = ['ERROR', 'WARN'];
const ACTION_OPENING_LEVELS = ['ERROR', 'WARN', 'INFO'];
const DEFAULT_PRESET_MINUTES = 1440;
const WIDEST_PRESET_MINUTES = 43_200;
const ACTION_RANGE_MARGIN_MILLISECONDS = 60_000;
const PAGE_SIZE = 50;
// A row this close to either end of the modelled window makes the expected count a coin toss between
// the model's window and the console's (the console measures an action's lifetime from its chain runs,
// the model from its entries), so such a state is left unchecked instead of reported.
const BOUNDARY_GUARD_MILLISECONDS = 15_000;

// The rolling range presets a step may switch to, with the minutes each one means.
const RANGE_PRESETS = [
	{label: 'Last 15 minutes', minutes: 15},
	{label: 'Last hour', minutes: 60},
	{label: 'Last 4 hours', minutes: 240},
	{label: 'Last 24 hours', minutes: 1440},
	{label: 'Last 7 days', minutes: 10_080},
	{label: 'Last 30 days', minutes: 43_200}
];

// The widths the design names, and the three breakpoints they bracket.
const WIDTHS = [1440, 1281, 1280, 1279, 1024, 821, 820, 819, 768, 767, 400];
const VIEWPORT_HEIGHT = 900;
const COMPACT_MAXIMUM_WIDTH = 1280;
const OVERLAY_MAXIMUM_WIDTH = 820;
const SIDE_BY_SIDE_MINIMUM_WIDTH = 768;
const TOOLBAR_LINE_ALLOWANCE = 2;

// The seeded generator's own two numbers, and the ceiling a fresh seed is drawn under.
const RANDOM_MULTIPLIER = 16_807;
const RANDOM_MODULUS = 2_147_483_647;
const RANDOM_WARM_UP_TURNS = 12;
const SEED_CEILING = 1_000_000_000;
const MESSAGE_EXCERPT_LENGTH = 160;
const NOISE_EXCERPT_LENGTH = 200;
// An uncaught error's frames, logged beside its message; long enough for the component and the two or
// three frames under it.
const STACK_EXCERPT_LENGTH = 600;
const NOISE_LINES_PRINTED = 20;
const MINUTE_MILLISECONDS = 60_000;

const SESSION_COUNT = 3;
const STEPS_PER_SESSION = 40;
// The whole shaped walk by default; --phases narrows it (a smoke run of one phase before the full one). The volume
// phase walks a load the driver laid down and runs only with its manifest.
const SHAPED_PHASES = ['sessions', 'hostile', 'probes', 'widths'];
const VOLUME_PHASE = 'volume';
const ALL_PHASES = [...SHAPED_PHASES, VOLUME_PHASE];
// The Chain Monitor's page size (chainMonitorList.js PAGE_SIZE): its page label names pages, never a run total.
const MONITOR_PAGE_SIZE = 20;
// Where a volume walk writes unless told otherwise.
const VOLUME_OUTPUT_DIRECTORY = path.join(REPOSITORY_ROOT, 'tmp', 'consoles-at-volume', 'exploration');
const SESSION_VIEWPORT = {width: 1440, height: VIEWPORT_HEIGHT};
// The browser context's clock: what the console's presets and custom range are entered in.
const BROWSER_TIMEZONE = 'America/Los_Angeles';
const MAXIMUM_SCREENSHOTS = 40;
const POLL_TIMEOUT_MILLISECONDS = 5000;
const POLL_INTERVAL_MILLISECONDS = 400;
const SHORT_POLL_MILLISECONDS = 2000;
// A list load answers slower than a pill appears, so the row count is given longer to settle.
const LIST_EXTRA_POLL_MILLISECONDS = 3000;
const MOVE_NAME_COLUMN = 24;
const PINS_COLUMN = 52;
// What the process exits with when the command line itself is wrong: told apart from 1 (there were
// findings) and 0 (there were none), neither of which is true of a run that never started.
const USAGE_EXIT_CODE = 2;
const RESIZE_SETTLE_MILLISECONDS = 900;
const NAVIGATION_SETTLE_MILLISECONDS = 1500;

// The two performance budgets a volume walk is judged against at the 75th percentile: from a
// navigation to a settled list, and one in-page read from its request to its response. The command
// line may move either.
const DEFAULT_PAGE_OPEN_BUDGET_MILLISECONDS = 3000;
const DEFAULT_IN_PAGE_READ_BUDGET_MILLISECONDS = 1000;

// The controller methods the read-count probe watches for in the page's request bodies.
const COUNTED_CONTROLLER_METHODS = ['getActionSummary', 'getLogEntries', 'getLogProblems', 'resolveSearchId', 'getLogSummary', 'getEntrySummary'];
// The Chain Monitor's controller methods, timed beside the console's (CTRL_ChainMonitor).
const MONITOR_CONTROLLER_METHODS = ['getChainExecutions', 'getChainDetail', 'getStepTimeline', 'getChainLogEntries'];

// A console error worth a finding: the rest of what Lightning logs (analytics, unrelated 404s,
// deprecation notes) is counted as noise and printed once at the end rather than reported per step.
const NOTABLE_CONSOLE_ERROR = /(logConsole|log-console|chainMonitor|chain-monitor|LWC component|Cannot read|is not a function|NavigationMixin|Unhandled)/i;

const labelValues = readShippedLabelValues();
// The four column sets the design fixes, built from the shipped label values rather than retyped.
const ENTRY_COLUMNS_FULL = ['ColLogNumber', 'ColTime', 'ColLevel', 'ColMessage', 'ColSource', 'ColContext', 'ColChain'].map((name) => labelValues[`LogConsole_${name}`]);
const ENTRY_COLUMNS_COMPACT = ['ColTime', 'ColLevel', 'ColMessage', 'ColChain'].map((name) => labelValues[`LogConsole_${name}`]);
const PROBLEM_COLUMNS_FULL = ['ColLogNumber', 'ColLevel', 'ColProblem', 'ColSource', 'ColContext', 'ColCount', 'ColLastSeen']
.map((name) => labelValues[`LogConsole_${name}`]);
const PROBLEM_COLUMNS_COMPACT = ['ColLevel', 'ColProblem', 'ColCount', 'ColLastSeen'].map((name) => labelValues[`LogConsole_${name}`]);
const MONITOR_COLUMNS_FULL = ['ChainName', 'Status', 'ColumnProgress', 'Started', 'Duration'].map((name) => labelValues[`ChainMonitor_${name}`]);
const MONITOR_COLUMNS_COMPACT = ['ChainName', 'Status', 'Started'].map((name) => labelValues[`ChainMonitor_${name}`]);
const MONITOR_LAUNCHED_UNDER = labelValues.ChainMonitor_LaunchedUnder;

module.exports = {
	REPOSITORY_ROOT,
	TEARDOWN_SCRIPT,
	AUTH_STATE_PATH,
	OUTPUT_DIRECTORY,
	SCREENSHOT_DIRECTORY,
	FINDINGS_PATH,
	TIMINGS_PATH,
	RUN_WINDOW_MARGIN_MILLISECONDS,
	STATE_KEY_ACTION,
	STATE_KEY_CHAIN,
	STATE_KEY_WINDOW_START,
	STATE_KEY_WINDOW_END,
	STATE_KEY_STAMP,
	CONSOLE_STATE_KEYS,
	ALL_LEVELS,
	DEFAULT_LEVELS,
	ACTION_OPENING_LEVELS,
	DEFAULT_PRESET_MINUTES,
	WIDEST_PRESET_MINUTES,
	ACTION_RANGE_MARGIN_MILLISECONDS,
	PAGE_SIZE,
	BOUNDARY_GUARD_MILLISECONDS,
	RANGE_PRESETS,
	WIDTHS,
	VIEWPORT_HEIGHT,
	COMPACT_MAXIMUM_WIDTH,
	OVERLAY_MAXIMUM_WIDTH,
	SIDE_BY_SIDE_MINIMUM_WIDTH,
	TOOLBAR_LINE_ALLOWANCE,
	RANDOM_MULTIPLIER,
	RANDOM_MODULUS,
	RANDOM_WARM_UP_TURNS,
	SEED_CEILING,
	MESSAGE_EXCERPT_LENGTH,
	NOISE_EXCERPT_LENGTH,
	STACK_EXCERPT_LENGTH,
	NOISE_LINES_PRINTED,
	MINUTE_MILLISECONDS,
	SESSION_COUNT,
	STEPS_PER_SESSION,
	SHAPED_PHASES,
	VOLUME_PHASE,
	ALL_PHASES,
	MONITOR_PAGE_SIZE,
	VOLUME_OUTPUT_DIRECTORY,
	SESSION_VIEWPORT,
	BROWSER_TIMEZONE,
	MAXIMUM_SCREENSHOTS,
	POLL_TIMEOUT_MILLISECONDS,
	POLL_INTERVAL_MILLISECONDS,
	SHORT_POLL_MILLISECONDS,
	LIST_EXTRA_POLL_MILLISECONDS,
	MOVE_NAME_COLUMN,
	PINS_COLUMN,
	USAGE_EXIT_CODE,
	RESIZE_SETTLE_MILLISECONDS,
	NAVIGATION_SETTLE_MILLISECONDS,
	DEFAULT_PAGE_OPEN_BUDGET_MILLISECONDS,
	DEFAULT_IN_PAGE_READ_BUDGET_MILLISECONDS,
	COUNTED_CONTROLLER_METHODS,
	MONITOR_CONTROLLER_METHODS,
	NOTABLE_CONSOLE_ERROR,
	labelValues,
	ENTRY_COLUMNS_FULL,
	ENTRY_COLUMNS_COMPACT,
	PROBLEM_COLUMNS_FULL,
	PROBLEM_COLUMNS_COMPACT,
	MONITOR_COLUMNS_FULL,
	MONITOR_COLUMNS_COMPACT,
	MONITOR_LAUNCHED_UNDER
};
