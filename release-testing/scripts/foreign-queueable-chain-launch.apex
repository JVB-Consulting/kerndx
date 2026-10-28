// Chain launch from a trigger inside a Queueable. See RUNBOOK.md, "Chain launch from a trigger inside a Queueable".
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}, with the Queued Marker Writer fixture package (namespace kerndxqa) installed after
// Kern and release-testing/fixtures/foreign-queueable-subscriber/ deployed.
//
// Starts three queueable jobs. Each saves one Queued Marker, whose trigger action starts a two-step chain named after
// the marker:
//   - OtherPackageQueueableChain: saved by the fixture package's own queueable job.
//   - SubscriberQueueableChain: saved by the subscriber's own queueable job.
//   - ChainStepChain: saved by the first step (QueuedMarkerWriterStep) of the two-step chain ChainStepParentChain, so
//     the second chain is started from inside the first one.
// On 1.9.0-4 all three fail, because the platform refuses the queueable depth reads to any trigger fired inside a
// queueable job.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/foreign-queueable-chain-launch.apex
//   (wait about 60 seconds for the jobs and the chains)
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/foreign-queueable-chain-launch-verify.apex

Id otherPackageJobId = kerndxqa.QueuedMarkerWriter.enqueueMarker('OtherPackageQueueableChain');
Id subscriberJobId = System.enqueueJob(new SubscriberQueuedMarkerWriter('SubscriberQueueableChain'));
String parentRunId = kern.UTIL_AsyncChain.newChain('ChainStepParentChain')
		.then(new QueuedMarkerWriterStep())
		.then(new QueuedMarkerChainLauncher.MarkerStep())
		.execute();
System.debug('foreign-queueable launch: other package job ' + otherPackageJobId + ', subscriber job ' + subscriberJobId
		+ ', chain step parent run ' + parentRunId);
