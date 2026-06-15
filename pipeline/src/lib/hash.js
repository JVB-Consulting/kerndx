// SPDX-License-Identifier: MIT
'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');

/**
 * Compute SHA-256 of the given content after LF-normalization (strip \r).
 * This neutralizes Git's core.autocrlf on Windows so a file checked out as
 * CRLF hashes identically to the LF version that init wrote.
 *
 * @param {string|Buffer} content - File content to hash.
 * @returns {string} Hex-encoded SHA-256 digest.
 */
function hashContent(content)
{
	const buf = Buffer.isBuffer(content) ? content : Buffer.from(content, 'utf8');
	const normalized = buf.toString('utf8').replace(/\r/g, '');
	return crypto.createHash('sha256').update(normalized, 'utf8').digest('hex');
}

/**
 * Read a file from disk and return its LF-normalized SHA-256 hash.
 *
 * @param {string} filePath - Absolute or relative path to the file.
 * @returns {string} Hex-encoded SHA-256 digest.
 */
function hashFile(filePath)
{
	return hashContent(fs.readFileSync(filePath));
}

module.exports = {hashContent, hashFile};
