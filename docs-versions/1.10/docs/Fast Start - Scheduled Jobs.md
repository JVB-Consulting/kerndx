---
navOrder: 40
---

# Fast Start - Scheduled Jobs

**Framework:** KernDX | **Total time:** ~25 minutes

**What this is:** A way to run your own Apex class on a schedule (every hour, every night, every Monday) where the schedule is a record you edit, not code you deploy. **Why it exists:** Salesforce's own scheduling is set up in code or in a one-off screen, so changing when a job runs, pausing it, or seeing whether its last run worked usually means a developer and a deployment. With a record, an admin changes the time, switches the job off or reads its last outcome on one page. **Who should follow this:** developers writing background jobs that run on a timer, and the admins who look after them. **When to use it:** any job that must run on a schedule and that you want to change by editing a record, with no deployment. Put it on the job runner when it must run more often than once an hour, or when your org is short of scheduled-job slots (Salesforce allows 100 in total).

What you'll build in one line: a job a record runs every hour, first on a scheduled job of its own, then on the job
runner, where you run it on demand and read how each run went.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A job class with one switch, Fail on purpose, a Scheduled Job record that runs it every hour,
and a paired test class with 100% coverage. Along the way you move the job onto the job runner, run it now, and open
the log entry a failed run leaves.

**Success looks like:** The record shows Outcome Succeeded after a run, a failed run's View log opens its log entry,
and the test class passes.

## Before you start

Open your terminal in your project's top folder, the one that holds `sfdx-project.json`; on Windows that terminal is
Command Prompt. Run the four-line check on [Set Up Your Computer](Set%20Up%20Your%20Computer.md#check-you-are-ready)
once: it proves your terminal, the CLI, your login and the KernDX package, and answers what goes wrong. Done that
today? Carry on. Work in a sandbox or a scratch org, never production. Every command below writes `YourOrgAlias`
where your org's alias goes: the name you gave it when you logged in.

Your user also needs access to the Kern app's Scheduled Jobs tab and to Health Check; an administrator has both. Step 3
gives you the job runner permission set.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Before you start](#before-you-start)
2. [How It Works](#how-it-works)
3. [Tier 1: See It Work (~10 minutes)](#tier-1-see-it-work-10-minutes)
    - [Step 1: Create the job class](#step-1-create-the-job-class)
    - [Step 2: Schedule it with a record](#step-2-schedule-it-with-a-record)
4. [Tier 2: Move It onto the Job Runner (~10 minutes)](#tier-2-move-it-onto-the-job-runner-10-minutes)
    - [Step 3: Give yourself the job runner permission set](#step-3-give-yourself-the-job-runner-permission-set)
    - [Step 4: Activate the job runner](#step-4-activate-the-job-runner)
    - [Step 5: Put the job on the runner](#step-5-put-the-job-on-the-runner)
    - [Step 6: Run it now and read the outcome](#step-6-run-it-now-and-read-the-outcome)
    - [Step 7: See a failed run and its log entry](#step-7-see-a-failed-run-and-its-log-entry)
    - [Step 8: Write and run the test](#step-8-write-and-run-the-test)
5. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
    - [Step 9: Switch the job off](#step-9-switch-the-job-off)
    - [Clean up](#clean-up)
6. [Common Issues](#common-issues)
    - [Step 1: Create the job class](#step-1-create-the-job-class-1)
    - [Step 2: Schedule it with a record](#step-2-schedule-it-with-a-record-1)
    - [Step 3: Give yourself the job runner permission set](#step-3-give-yourself-the-job-runner-permission-set-1)
    - [Step 4: Activate the job runner](#step-4-activate-the-job-runner-1)
    - [Step 5: Put the job on the runner](#step-5-put-the-job-on-the-runner-1)
    - [Step 6: Run it now and read the outcome](#step-6-run-it-now-and-read-the-outcome-1)
    - [Step 7: See a failed run and its log entry](#step-7-see-a-failed-run-and-its-log-entry-1)
    - [Step 8: Write and run the test](#step-8-write-and-run-the-test-1)
    - [Step 9: Switch the job off](#step-9-switch-the-job-off-1)
    - [Clean up](#clean-up-1)
7. [What You Now Know](#what-you-now-know)
8. [Next Steps](#next-steps)

</details>

---

## How It Works

You write the job as an ordinary Apex class. A record then says which class runs, when, and where, and the framework
does the scheduling whenever you save that record. Here are the pieces you'll work with:

| Component                    | Role                                                                                                                          |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| `kern.SCHED_Base`            | The base your class extends: it declares the parameters the job takes, and reads their values with the right type             |
| `kern__ScheduledJob__c`      | The record: which class runs, when, whether it is switched on, and where it runs                                              |
| The Scheduled Jobs editor    | New and Edit on the record: suggests your classes and takes a name you type, stamps your time zone, and previews the next run |
| The job runner               | A few platform scheduled jobs that start every job set to run on it; you switch it on from the Kern Home tab                  |
| Kern Job Runner Management   | The permission set that lets you put jobs on the runner and run them now                                                      |

A job runs in one of two places. On a scheduled job of its own, it runs at most once an hour and uses one of the org's
100 scheduled-job slots. On the job runner, it may run as often as every five minutes and uses no slot of its own: the
runner's few slots are shared by every job you put on it.

---

## Tier 1: See It Work (~10 minutes)

### Step 1: Create the job class

Build a job class with one switch, Fail on purpose, that makes a run fail so you can see what a failure looks like
later. You create an empty class with one command, paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name FastStart_ScheduledJob_DEMO --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `FastStart_ScheduledJob_DEMO`: the
class, ending in `.cls`, and its companion, ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/FastStart_ScheduledJob_DEMO.cls
```

> **Why `global`?** The framework finds `FastStart_ScheduledJob_DEMO` by name at runtime, and marking it `global` lets
> it do that with no extra setup. A `public` class works too, once your org registers a Type Resolver class
> (how the framework finds the Apex classes in your namespace: you tell it where to look). The Kern home page
> health check provides the code, or see
> [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

```apex
/**
 * @description A scheduled job for the Fast Start - Scheduled Jobs guide. A ScheduledJob__c record runs it on a
 * schedule, on a scheduled job of its own or on the job runner. Its one parameter, Fail on purpose, makes a run throw,
 * so you can see a failed run and the log entry it leaves.
 *
 * The class is global so the managed package can create it from its name, and it declares no constructor: the
 * framework can only use the constructor Apex provides when none is declared.
 *
 * @see FastStart_ScheduledJob_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date October 2026
 */
global inherited sharing class FastStart_ScheduledJob_DEMO extends kern.SCHED_Base
{
	/**
	 * @description Name of the switch that makes a run fail on purpose.
	 */
	public static final String PARAMETER_FAIL_ON_PURPOSE = 'failOnPurpose';

	/**
	 * @description Label the Scheduled Jobs editor shows beside the switch.
	 */
	private static final String LABEL_FAIL_ON_PURPOSE = 'Fail on purpose';

	/**
	 * @description What a run that fails on purpose throws, and what its log entry says.
	 */
	public static final String FAILED_ON_PURPOSE_MESSAGE = 'FastStart_ScheduledJob_DEMO failed on purpose, because Fail on purpose is switched on.';

	/**
	 * @description Declares the one parameter, which the editor shows as a switch, off unless you switch it on.
	 *
	 * @return The parameter definitions.
	 */
	public override List<kern.DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<kern.DTO_ScheduledParameterDefinition>
		{
				kern.DTO_ScheduledParameterDefinition.of(PARAMETER_FAIL_ON_PURPOSE, LABEL_FAIL_ON_PURPOSE).asBoolean().withDefault(String.valueOf(false))
		};
	}

	/**
	 * @description Runs the job. It does nothing unless Fail on purpose is on; then it throws, so the run is recorded
	 * as Failed.
	 *
	 * @param context The scheduling context the platform or the job runner passes in.
	 */
	public void execute(SchedulableContext context)
	{
		if(getBooleanParameter(PARAMETER_FAIL_ON_PURPOSE))
		{
			throw new FailedOnPurposeException(FAILED_ON_PURPOSE_MESSAGE);
		}
	}

	/**
	 * @description Thrown by a run that fails on purpose.
	 */
	public class FailedOnPurposeException extends Exception
	{
	}
}
```

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_ScheduledJob_DEMO"
```

You should see `Status: Succeeded`, with `FastStart_ScheduledJob_DEMO` listed as created.

**Key patterns:**

- `extends kern.SCHED_Base` makes the class schedulable and gives it typed parameters
- `getParameterDefinitions()` declares the job's parameters; the editor draws a field for each, here the Fail on
  purpose switch
- `execute()` runs the job, and reads each parameter with a typed getter such as `getBooleanParameter()`
- Declare no constructor: the framework creates the job from its class name on every run, and from inside the
  package it can only use the constructor Apex provides when you declare none

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-job-class-1).

### Step 2: Schedule it with a record

A Scheduled Job record runs your class. Saving it schedules the class; you never call the platform's scheduling
yourself.

**In Salesforce**, open the App Launcher, then **Kern**, then **Scheduled Jobs**, then **New**, and save with these
values:

| Field                                  | API name                                   | Value                                                                    |
|----------------------------------------|--------------------------------------------|--------------------------------------------------------------------------|
| Scheduler Name                         | `kern__SchedulerName__c`                   | `Fast Start demo job`                                                    |
| Class Name                             | `kern__ClassName__c`                       | `FastStart_ScheduledJob_DEMO` (type it, or pick it from the suggestions) |
| Active                                 | `kern__IsActive__c`                        | on                                                                       |
| Execution mode                         | `kern__ExecutionMode__c`                   | Its own scheduled job                                                    |
| Schedule (your time zone), mode Custom | `kern__CronExpression__c`                  | `0 0 * * * ?`                                                            |
| Fail on purpose                        | a parameter, kept in `kern__Parameters__c` | off                                                                      |

The Schedule value is a cron expression: a short pattern of seconds, minutes, hours, days and months. `0 0 * * * ?`
means at minute 0 of every hour. Fail on purpose appears once the editor has checked the class name.

You should see the record page, with Scheduled Job Id filled in: the platform's scheduled job exists, and the job will
run at the top of every hour.

The time zone is yours: the editor stamps it on the record, so there is nothing to set.

Something went wrong? See [Common Issues, Step 2](#step-2-schedule-it-with-a-record-1).

---

## Tier 2: Move It onto the Job Runner (~10 minutes)

### Step 3: Give yourself the job runner permission set

Putting a job on the runner, and running it now, needs the Kern Job Runner Management permission set.

**In the terminal**, assign the permission set to yourself:

```shell
sf org assign permset -n kern__JobRunnerManagement -o YourOrgAlias
```

You should see a `Permsets Assigned` table with one row: your username and `kern__JobRunnerManagement`.

On an unmanaged deploy the set's name is `JobRunnerManagement`, without the prefix (see the namespace note above).

Something went wrong? See [Common Issues, Step 3](#step-3-give-yourself-the-job-runner-permission-set-1).

### Step 4: Activate the job runner

The runner is a few platform scheduled jobs that check for due jobs at a fixed interval. You switch it on once for the
whole org.

**In Salesforce**, open the App Launcher, then **Kern**, then the **Kern Home** tab. On the **Job runner** card, press
**Activate**, choose **Every 15 minutes (4 slots)** in **Check for due jobs**, and press **Activate** to confirm.

You should see the card say that the runner checks for due jobs every 15 minutes, using 4 of the org's 100
scheduled-job slots.

The choice decides what the runner costs: every hour uses one slot, every 30 minutes two, every 15 minutes four, every
10 minutes six, every 5 minutes twelve. Every job you then put on the runner is free.

Jobs on the runner run as the user who activated it. Here that is you, which is fine for trying it out. In production,
activate it as an integration user that holds the Kern Job Runner Management set and the access every job needs, never
as yourself.

Something went wrong? See [Common Issues, Step 4](#step-4-activate-the-job-runner-1).

### Step 5: Put the job on the runner

**In Salesforce**, go back to your Scheduled Job record and reload the page: the permission set from Step 3 reaches
only a page opened after it was assigned. Press **Edit**, set **Execution mode** to **Job runner**, and press **Save**.

You should see Runs on: Job runner, and a Next run time in your time zone at the next top of the hour, the first check
on or after the job's scheduled time. The job's own platform scheduled job is gone: it no longer uses a slot.

Something went wrong? See [Common Issues, Step 5](#step-5-put-the-job-on-the-runner-1).

### Step 6: Run it now and read the outcome

**In Salesforce**, on the record page, press **Run now**.

You should see a message that the job was started. After a few seconds, refresh the page: Last run is filled in and
Outcome reads Succeeded.

Run now runs the job as you, straight away, without moving its next run.

Something went wrong? See [Common Issues, Step 6](#step-6-run-it-now-and-read-the-outcome-1).

### Step 7: See a failed run and its log entry

**In Salesforce**, on the record page, press **Edit**, switch **Fail on purpose** on, and press **Save**. Press
**Run now**, wait a few seconds, then refresh the page.

You should see Outcome read Failed, with **View log** beside it. View log opens the run's log entry, whose message is
`FastStart_ScheduledJob_DEMO failed on purpose, because Fail on purpose is switched on.`

**In Salesforce**, press **Edit**, switch **Fail on purpose** off, and press **Save**.

A failed run's details are always in its log entry. View log appears only for a failed or parked run, because a run
that succeeded has nothing to read.

Something went wrong? See [Common Issues, Step 7](#step-7-see-a-failed-run-and-its-log-entry-1).

### Step 8: Write and run the test

The first test saves a record and checks that it scheduled your class; the other two check the switch. You create the
empty class with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name FastStart_ScheduledJob_DEMO_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `FastStart_ScheduledJob_DEMO_TEST`:
the class, ending in `.cls`, and its companion, ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/FastStart_ScheduledJob_DEMO_TEST.cls
```

```apex
/**
 * @description Tests for FastStart_ScheduledJob_DEMO: a record schedules it and its run does not fail, the switch makes
 * a run fail with the message its log entry shows, and the editor gets one switch, off by default.
 *
 * @see FastStart_ScheduledJob_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class FastStart_ScheduledJob_DEMO_TEST
{
	/**
	 * @description Name of the record the test saves, apart from the one you made in the guide.
	 */
	private static final String TEST_JOB_NAME = 'Fast Start Scheduled Job Test';

	/**
	 * @description Every hour, on the hour.
	 */
	private static final String EVERY_HOUR = '0 0 * * * ?';

	/**
	 * @description How many parameters the job declares.
	 */
	private static final Integer DECLARED_PARAMETER_COUNT = 1;

	/**
	 * @description Verifies that an active record schedules the class, and that the run Test.stopTest() makes does not
	 * fail with the switch off.
	 */
	@IsTest
	private static void shouldScheduleFromARecordAndRunWithoutFailing()
	{
		Test.startTest();
		kern__ScheduledJob__c job = (kern__ScheduledJob__c)kern.TST_Builder.of(kern__ScheduledJob__c.SObjectType)
				.withOverride(kern__ScheduledJob__c.kern__SchedulerName__c, TEST_JOB_NAME)
				.withOverride(kern__ScheduledJob__c.kern__ClassName__c, FastStart_ScheduledJob_DEMO.class.getName())
				.withOverride(kern__ScheduledJob__c.kern__CronExpression__c, EVERY_HOUR)
				.withOverride(kern__ScheduledJob__c.kern__IsActive__c, true)
				.build();
		Test.stopTest();

		kern__ScheduledJob__c saved = (kern__ScheduledJob__c)kern.QRY_Builder.selectFrom(kern__ScheduledJob__c.SObjectType)
				.fields(new List<SObjectField> {kern__ScheduledJob__c.kern__ScheduledJobId__c})
				.condition(kern__ScheduledJob__c.Id).equals(job.Id)
				.getFirst();

		Assert.isNotNull(saved.kern__ScheduledJobId__c, 'The record scheduled the class: the platform job id is stored');
	}

	/**
	 * @description Verifies that a run with Fail on purpose switched on throws, with the message its log entry shows.
	 */
	@IsTest
	private static void shouldFailWhenAskedToFailOnPurpose()
	{
		FastStart_ScheduledJob_DEMO job = new FastStart_ScheduledJob_DEMO();
		job.setParameterValues(new kern.DTO_NameValues(new Map<String, String> {FastStart_ScheduledJob_DEMO.PARAMETER_FAIL_ON_PURPOSE => String.valueOf(true)}));

		try
		{
			job.execute(null);
			Assert.fail('A run asked to fail on purpose must throw');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, FastStart_ScheduledJob_DEMO.FailedOnPurposeException.class, 'Incorrect exception type');
			Assert.areEqual(FastStart_ScheduledJob_DEMO.FAILED_ON_PURPOSE_MESSAGE, error.getMessage(), 'The message is the one View log shows');
		}
	}

	/**
	 * @description Verifies that the job declares one switch, off by default, which the editor draws as a toggle.
	 */
	@IsTest
	private static void shouldDeclareOneSwitchThatIsOffByDefault()
	{
		List<kern.DTO_ScheduledParameterDefinition> definitions = new FastStart_ScheduledJob_DEMO().getParameterDefinitions();

		Assert.areEqual(DECLARED_PARAMETER_COUNT, definitions.size(), 'The job declares one parameter');
		Assert.areEqual(FastStart_ScheduledJob_DEMO.PARAMETER_FAIL_ON_PURPOSE, definitions[0].name, 'The parameter is the switch');
		Assert.areEqual(kern.DTO_ScheduledParameterDefinition.DataType.FLAG.name(), definitions[0].dataType, 'The editor draws a FLAG parameter as a toggle');
		Assert.areEqual(String.valueOf(false), definitions[0].defaultValue, 'The switch is off unless you switch it on');
	}
}
```

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_ScheduledJob_DEMO_TEST"
```

You should see `Status: Succeeded`, with `FastStart_ScheduledJob_DEMO_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t FastStart_ScheduledJob_DEMO_TEST --code-coverage --synchronous --result-format human
```

You should see 3 tests passing and 100% coverage on `FastStart_ScheduledJob_DEMO`: all three tests show `Pass`, the
summary line `Outcome` reads `Passed`, and the coverage table shows `FastStart_ScheduledJob_DEMO` at `100%`.

> **Why `Test.startTest() / Test.stopTest()` around the insert?** Saving the record schedules the class, and in a
> test a scheduled job only runs when `Test.stopTest()` is reached. Wrapping the insert makes the job run once, right
> there, so the test proves a run with the switch off does not fail. The test class is not parallel
> (`isParallel=false`) because scheduling a job from a record cannot happen in a parallel test.

Something went wrong? See [Common Issues, Step 8](#step-8-write-and-run-the-test-1).

---

## Tier 3: Production Patterns (~5 minutes)

**Parameters:** the editor builds the job's form from `getParameterDefinitions()`, one field per parameter, and
`execute()` reads each value with a typed getter. Add a parameter in code and the form shows it the next time the
record is edited; nobody has to edit raw text.

**Run priority and Overlap policy:** two fields a job on the runner adds. Run priority decides which job starts first
when several are due at the same check: lower numbers first, blank last. Overlap policy decides what happens when a run
is due while the previous one is still running: Skip (the default) records the run as Skipped, Allow starts it anyway.

**Who the jobs run as:** every job on the runner runs as the user who activated the runner. Run now runs as whoever
presses it. Give the activating integration user the access every job on the runner needs.

**Health Check:** three readings watch the runner. **Job Runner** says whether it has checked for due jobs recently,
whether all its scheduled jobs are still there, and whether the user it runs as is still active. **Jobs Waiting for
the Job Runner** says whether a job is set to run on a runner that is not there. **Job Runner Capacity** says how many
of the org's scheduled-job slots are in use, and whether the last check started every job that was due.

**Time zone:** the editor stamps `kern__Timezone__c` with your time zone when you save. A record made any other way, for
example by a script or a step after installation, must set `kern__Timezone__c` itself, or on the runner its hours are
read as UTC.

For how runs are timed, missed runs and daylight saving, see
[Running many jobs on one job runner](Async%20Processing%20-%20Guide.md#running-many-jobs-on-one-job-runner).

### Step 9: Switch the job off

**In Salesforce**, on the record page, press **Edit**, switch **Active** off, and press **Save**.

You should see the record stay, with nothing scheduled: switching a job off is how you remove it. Deleting the record
needs the Kern Administrator permission set; you can leave it.

Something went wrong? See [Common Issues, Step 9](#step-9-switch-the-job-off-1).

### Clean up

If you built this example only to try the framework, remove the two classes after Step 9, so no active job names a
class that is gone.

**In the terminal**, delete the two classes:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:FastStart_ScheduledJob_DEMO_TEST" -m "ApexClass:FastStart_ScheduledJob_DEMO" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes. The command deletes the
files from your project too.

Optionally, **in Salesforce**, open the **Kern Home** tab in the Kern app and press **Deactivate** on the **Job
runner** card, if you activated the runner only for this guide.

Something went wrong? See [Common Issues](#clean-up-1).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 1: Create the job class

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

### Step 2: Schedule it with a record

#### Your class is not in the list: type its name

The editor keeps its list of classes for up to eight hours, so a class deployed since the list was stored is not
suggested yet. Type `FastStart_ScheduledJob_DEMO` into Class Name and leave the field: the editor checks the name you
typed and accepts it.

#### The field says no class of that name can be scheduled

Under Class Name you see `No class named FastStart_ScheduledJob_DEMO can be scheduled. Check the spelling, that the
class is deployed to this org, and that it implements Schedulable.` The causes you can reach in this guide:

- The name is misspelt. Any letter case works, but every letter must be there.
- Step 1's deploy did not succeed. Run it again and check it prints `Status: Succeeded`.
- The class is `public` and your org has no Type Resolver (see the "Why `global`?" note in Step 1).
- The class declares a constructor. Remove it.
- The class does not extend `kern.SCHED_Base`, which is what makes it schedulable.

#### Save stays greyed out

Scheduler Name, Class Name and a valid schedule are all needed before you can save, and a class name the editor
refused keeps Save closed too. Fill in the missing value, or fix the class name as the entry above shows.

### Step 3: Give yourself the job runner permission set

#### The permission set is not found

On an unmanaged deploy its name is `JobRunnerManagement`, without the prefix.

### Step 4: Activate the job runner

#### There is no Activate button

A runner is already active, so the card offers Deactivate and Repair instead; carry on with Step 5. Or you cannot open
Health Check: activating needs Health Check access, which the permission set does not give. Ask an administrator for it.

### Step 5: Put the job on the runner

#### Execution mode is greyed out

Under it you see `You need the Manage Job Runner permission to put a job on the job runner.` The permission set is
missing, or the page was open before Step 3 assigned it. Run Step 3, then reload the page.

#### The save is refused: "Only a user with the Manage Job Runner permission can put a job on the job runner..."

The full message is `Only a user with the Manage Job Runner permission can put a job on the job runner or change the
class or parameters of a job that is on it.` You do not hold the permission set: go back to Step 3.

### Step 6: Run it now and read the outcome

#### Run now is not shown

Run now shows only for an active job on the runner, to a user who may manage the runner. The job is switched off, it
is not on the runner (Step 5), or you lack the permission set or opened the page before it was assigned: run Step 3,
then reload the page.

#### Run now answers that the job runner is switched off

Run now answers `The job runner is switched off, so Run now cannot start this job.` This is not about Step 4: the job
runner has been switched off for the whole org through its feature flag, which stops every job on the runner without
deleting anything. Activating the runner again does not change it. An administrator turns the flag back on: open Setup,
then Custom Metadata Types, then **Feature Flag**, then **Manage Feature Flags**, open **Scheduled Job Runner**, check
that **Is Active** and **Is Enabled By Default** are both checked, and save. See
[Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md) for how flags work.

#### Outcome reads Parked or Skipped

Reason, under Outcome, says why in a fixed sentence. A parked job is tried again a day later, or sooner after you edit
its schedule, time zone, execution mode or Active switch.

### Step 7: See a failed run and its log entry

#### Outcome reads Failed with another message

Press View log: the log entry names the exception the run threw.

### Step 8: Write and run the test

#### The test class will not deploy, or the test fails on the insert, naming `FastStart_ScheduledJob_DEMO`

Step 1's class is not in your org, so the test class cannot compile against it, or the record the test saves is
refused because its class cannot be found. Run Step 1's deploy again and check it prints `Status: Succeeded`, then
deploy and run the test again.

### Step 9: Switch the job off

#### The save is refused on the class name

The class was deleted while the job was still switched on, and the job runner checks the class on every save. Deploy
the class again (Step 1), switch the job off, then clean up.

### Clean up

#### The delete is refused because the class has jobs scheduled

The job is still on a scheduled job of its own, so Salesforce will not delete its class. Switch it off (Step 9) and run
the command again.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Scheduled%20Jobs) which step and what you saw.

## What You Now Know

- **`kern.SCHED_Base`** is the base your job extends; declare its parameters in `getParameterDefinitions()` and read
  them with typed getters in `execute()`
- **A `kern__ScheduledJob__c` record** schedules a class, either on a scheduled job of its own (at most hourly, one
  slot) or on the job runner (as often as every five minutes, no slot of its own)
- **The Scheduled Jobs editor** suggests your classes, takes a class name you type, and stamps your time zone on the
  record
- **The job runner** is switched on from the Kern Home tab; putting jobs on it needs the Kern Job Runner Management
  permission set, and in production an integration user activates it
- **Run now** starts a job on the runner straight away; **Outcome** shows how the last run went, and a failed run's
  **View log** opens its log entry
- **Switching a job off** is how you remove it; delete its class only after that

---

## Next Steps

- [The scheduler in depth](Async%20Processing%20-%20Guide.md#scheduler-framework)
- [Running many jobs on one job runner](Async%20Processing%20-%20Guide.md#running-many-jobs-on-one-job-runner)
- [Async chains](Fast%20Start%20-%20Async%20Processing.md)
- [Logging and the Log Console](Fast%20Start%20-%20Logging.md)
- [`SCHED_Base` API](reference/apex/SCHED_Base.md)
