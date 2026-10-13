// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Holds a recursive file watcher on a folder until it is killed, the way an editor with the project open
 *              does, and keeps a status file saying which process it is and how many file events it has been handed,
 *              so a later step can prove it was watching while the work it watched was running. Used only by the
 *              Windows workflow, to find out whether that stops the namespace swap.
 *              Usage: node scripts/hold-file-watcher.js <folder> [status file]
 */
'use strict';

const fs = require('fs');

/**
 * @description How often the running count is written out. A swap hands the watcher an event for every one of
 *              thousands of files, so the count is flushed on a timer instead: a watcher that wrote its own status
 *              file on every event would slow down the very thing it is there to observe.
 */
const STATUS_FLUSH_MILLISECONDS = 250;

/**
 * @description How long the process stays alive between ticks when it has nothing else to do.
 */
const KEEP_ALIVE_MILLISECONDS = 60000;

const folder = process.argv[2];
const statusFile = process.argv[3];
let eventsSeen = 0;

/**
 * @description Writes which process is watching, what it is watching and how many events it has seen so far. Does
 *              nothing when no status file was named, so the watcher can still be run with a folder alone.
 * @returns {void}
 */
function writeStatus()
{
	if(!statusFile)
	{
		return;
	}
	try
	{
		fs.writeFileSync(statusFile, JSON.stringify({processId: process.pid, folder, eventsSeen}) + '\n');
	}
	catch
	{
		// Something holding the status file for a moment, a scanner for instance, must not end the watch: the next
		// tick writes the count again.
	}
}

fs.watch(folder, {recursive: true}, () =>
{
	eventsSeen++;
});
writeStatus();
console.log(`watching ${folder}`);
if(statusFile)
{
	setInterval(writeStatus, STATUS_FLUSH_MILLISECONDS);
}
setInterval(() => {}, KEEP_ALIVE_MILLISECONDS);
