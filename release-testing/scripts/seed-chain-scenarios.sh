#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Chain Monitor REALISM seed — runs seed-chain-scenarios.apex as a series of spaced batches.
#
# WHAT: substitutes the batch number and a per-run token into a temporary copy of the anonymous-Apex
# script, runs it once per batch, and waits between batches until the queueable backlog has drained.
# Thirty chains per batch and ten batches produce about three hundred executions plus the ten
# synthesized stalled rows batch one writes.
#
# WHY: a single anonymous transaction can only enqueue fifty queueables and issue a hundred and fifty
# DML statements, and a chain launch costs four DML statements and one enqueue. Batching is what keeps
# a realistic execution count reachable without tripping either ceiling or overflowing the flex queue.
#
# PREREQUISITES: the managed package installed on the target subscriber org, SubscriberChainSteps
# deployed, the AsyncChain feature flag active, and audit-field back-dating enabled (RUNBOOK Phase 1.4)
# for the synthesized stalled rows.
#
# Usage:
#   release-testing/scripts/seed-chain-scenarios.sh [--org YourSubscriberOrgAlias] [--batches 10] \
#       [--output-directory tmp/release-1.7.0/seed]
#
# Teardown (log rows, chain executions and the marker records these chains create):
#   node release-testing/scripts/seed-log-volume.mjs --org <alias> --teardown

set -euo pipefail

ORGANISATION_ALIAS="${SF_SUBSCRIBER_ORG_ALIAS:-YourSubscriberOrgAlias}"
BATCH_COUNT=10
OUTPUT_DIRECTORY="tmp/release-1.7.0/seed"
REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APEX_TEMPLATE="${REPOSITORY_ROOT}/release-testing/scripts/seed-chain-scenarios.apex"

# Queue thresholds. The immediate backlog must drain before the next batch, but delayed chains sit in
# Holding for their whole delay window, so they are counted against the flex-queue ceiling instead of
# the drain gate — otherwise a batch that seeds a delayed chain could never satisfy the wait.
MAXIMUM_ACTIVE_JOBS=10
MAXIMUM_HELD_JOBS=60
QUEUE_POLL_SECONDS=15
QUEUE_TIMEOUT_SECONDS=600

while [ $# -gt 0 ]; do
	case "$1" in
		--org)
			ORGANISATION_ALIAS="$2"
			shift 2
			;;
		--batches)
			BATCH_COUNT="$2"
			shift 2
			;;
		--output-directory)
			OUTPUT_DIRECTORY="$2"
			shift 2
			;;
		*)
			echo "Unknown argument: $1" >&2
			exit 2
			;;
	esac
done

cd "${REPOSITORY_ROOT}"
mkdir -p "${OUTPUT_DIRECTORY}"

# The token separates one seed run's correlation ids from every other run's, and it is deliberately
# ALL LETTERS. The shipped MaskingTarget Chain_All_PaymentCard masks EVERY AsyncChainExecution__c field,
# including the unique CorrelationId__c, against a 13-to-19-digit card pattern that treats hyphens as
# separators. A timestamp token turns `seed-scenario-<digits>-<batch>-<sequence>` into a long digit run,
# the platform rewrites the id to the constant redaction text, and the next chain whose id is redacted
# the same way fails on the unique index with a raw DUPLICATE_VALUE. Letters cannot form that run.
RUN_TOKEN=""
RUN_TOKEN_ALPHABET="abcdefghijklmnopqrstuvwxyz"
for _ in 1 2 3 4 5 6 7 8 9 10; do
	RUN_TOKEN="${RUN_TOKEN}${RUN_TOKEN_ALPHABET:$((RANDOM % 26)):1}"
done
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
STATE_FILE="${OUTPUT_DIRECTORY}/chain-seed-state.json"
printf '{"startedAt":"%s","org":"%s","batches":%s,"runToken":"%s"}\n' \
	"${STARTED_AT}" "${ORGANISATION_ALIAS}" "${BATCH_COUNT}" "${RUN_TOKEN}" > "${STATE_FILE}"

echo "Chain scenario seed — org ${ORGANISATION_ALIAS}, ${BATCH_COUNT} batches, run token ${RUN_TOKEN}"
echo "Run start recorded in ${STATE_FILE} (teardown scopes its marker cleanup to this time)"

# Waits until the immediate queueable backlog has drained, so the next batch never piles onto a full
# queue. Returns anyway after the timeout, with a warning, rather than stalling the whole seed.
wait_for_queue()
{
	local deadline=$(( $(date +%s) + QUEUE_TIMEOUT_SECONDS ))
	local depth_file="${OUTPUT_DIRECTORY}/queue-depth.json"
	local query="SELECT Status, COUNT(Id) jobCount FROM AsyncApexJob WHERE JobType = 'Queueable' AND Status IN ('Queued','Preparing','Processing','Holding') GROUP BY Status"
	while true; do
		sf data query -o "${ORGANISATION_ALIAS}" -q "${query}" --json > "${depth_file}" 2>&1 || true
		local counts
		counts="$(node -e '
			const fs = require("node:fs");
			let active = 0;
			let held = 0;
			try
			{
				const parsed = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
				for(const record of parsed.result?.records ?? [])
				{
					if(record.Status === "Holding")
					{
						held += Number(record.jobCount ?? 0);
					}
					else
					{
						active += Number(record.jobCount ?? 0);
					}
				}
			}
			catch(error)
			{
				active = -1;
			}
			process.stdout.write(`${active} ${held}`);
		' "${depth_file}")"
		local active_jobs="${counts% *}"
		local held_jobs="${counts#* }"
		if [ "${active_jobs}" -ge 0 ] && [ "${active_jobs}" -lt "${MAXIMUM_ACTIVE_JOBS}" ] && [ "${held_jobs}" -lt "${MAXIMUM_HELD_JOBS}" ]; then
			echo "  queue drained (active ${active_jobs}, holding ${held_jobs})"
			return 0
		fi
		if [ "$(date +%s)" -ge "${deadline}" ]; then
			echo "  WARNING: queue still busy after ${QUEUE_TIMEOUT_SECONDS}s (active ${active_jobs}, holding ${held_jobs}) — continuing anyway"
			return 0
		fi
		sleep "${QUEUE_POLL_SECONDS}"
	done
}

BATCH=1
while [ "${BATCH}" -le "${BATCH_COUNT}" ]; do
	BATCH_LABEL="$(printf '%02d' "${BATCH}")"
	BATCH_SCRIPT="${OUTPUT_DIRECTORY}/seed-chain-scenarios-batch-${BATCH_LABEL}.apex"
	BATCH_LOG="${OUTPUT_DIRECTORY}/seed-chain-scenarios-batch-${BATCH_LABEL}.json"
	sed -e "s/__BATCH__/${BATCH}/" -e "s/__RUN__/${RUN_TOKEN}/" "${APEX_TEMPLATE}" > "${BATCH_SCRIPT}"

	echo "Batch ${BATCH}/${BATCH_COUNT} — running ${BATCH_SCRIPT}"
	if ! sf apex run -o "${ORGANISATION_ALIAS}" -f "${BATCH_SCRIPT}" --json > "${BATCH_LOG}" 2>&1; then
		echo "Batch ${BATCH} FAILED — see ${BATCH_LOG}" >&2
		node -e '
			const fs = require("node:fs");
			const parsed = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
			const result = parsed.result ?? {};
			console.error(`  compiled=${result.compiled} success=${result.success}`);
			console.error(`  compileProblem=${result.compileProblem ?? ""}`);
			console.error(`  exceptionMessage=${result.exceptionMessage ?? parsed.message ?? ""}`);
		' "${BATCH_LOG}" || true
		exit 1
	fi
	node -e '
		const fs = require("node:fs");
		const parsed = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
		for(const line of (parsed.result?.logs ?? "").split("\n"))
		{
			// USER_DEBUG only: the log also echoes the script source, which contains the same token.
			if(line.includes("|USER_DEBUG|") && line.includes("SEED_CHAIN_SCENARIOS"))
			{
				console.log(`  ${line.slice(line.indexOf("SEED_CHAIN_SCENARIOS"))}`);
			}
		}
	' "${BATCH_LOG}"

	if [ "${BATCH}" -lt "${BATCH_COUNT}" ]; then
		wait_for_queue
	fi
	BATCH=$(( BATCH + 1 ))
done

echo ""
echo "All ${BATCH_COUNT} batches launched. Waiting for the last batch to settle before the count."
wait_for_queue

STATUS_FILE="${OUTPUT_DIRECTORY}/chain-seed-status.json"
NAME_FILE="${OUTPUT_DIRECTORY}/chain-seed-names.json"
NAMESPACE_FILE="${OUTPUT_DIRECTORY}/chain-seed-namespace.json"
sf data query -o "${ORGANISATION_ALIAS}" --use-tooling-api --json \
	-q "SELECT NamespacePrefix FROM ApexClass WHERE Name = 'UTIL_AsyncChain' LIMIT 1" > "${NAMESPACE_FILE}" 2>&1
NAMESPACE_PREFIX="$(node -e '
	const fs = require("node:fs");
	const parsed = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
	const prefix = parsed.result?.records?.[0]?.NamespacePrefix;
	process.stdout.write(prefix ? `${prefix}__` : "");
' "${NAMESPACE_FILE}")"

# SOQL reads a bare underscore as a single-character wildcard, so the marker escapes it. Bash collapses
# the doubled backslash to one, which is exactly what the query needs.
CHAIN_OBJECT="${NAMESPACE_PREFIX}AsyncChainExecution__c"
SEED_NAME_FILTER="${NAMESPACE_PREFIX}ChainName__c LIKE 'Seed\\_%'"
STATUS_FIELD="${NAMESPACE_PREFIX}Status__c"
NAME_FIELD="${NAMESPACE_PREFIX}ChainName__c"

sf data query -o "${ORGANISATION_ALIAS}" --json \
	-q "SELECT ${STATUS_FIELD} status, COUNT(Id) executionCount FROM ${CHAIN_OBJECT} WHERE ${SEED_NAME_FILTER} GROUP BY ${STATUS_FIELD}" \
	> "${STATUS_FILE}" 2>&1
sf data query -o "${ORGANISATION_ALIAS}" --json \
	-q "SELECT ${NAME_FIELD} chainName, ${STATUS_FIELD} status, COUNT(Id) executionCount FROM ${CHAIN_OBJECT} WHERE ${SEED_NAME_FILTER} GROUP BY ${NAME_FIELD}, ${STATUS_FIELD} ORDER BY ${NAME_FIELD}" \
	> "${NAME_FILE}" 2>&1

echo ""
echo "=== Seeded chain executions by status ==="
node -e '
	const fs = require("node:fs");
	const parsed = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
	let total = 0;
	for(const record of parsed.result?.records ?? [])
	{
		total += Number(record.executionCount ?? 0);
		console.log(`  ${String(record.status ?? "(none)").padEnd(12)} ${record.executionCount}`);
	}
	console.log(`  ${"TOTAL".padEnd(12)} ${total}`);
' "${STATUS_FILE}"

echo ""
echo "=== Seeded chain executions by name ==="
node -e '
	const fs = require("node:fs");
	const parsed = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
	for(const record of parsed.result?.records ?? [])
	{
		console.log(`  ${String(record.chainName).padEnd(30)} ${String(record.status).padEnd(12)} ${record.executionCount}`);
	}
' "${NAME_FILE}"
