---
navOrder: 2
title: "Set Up Your Computer"
---

# Set Up Your Computer

**What this is:** the one-time setup every guide on this site assumes, and the answers to what goes wrong with a
computer rather than with a guide. **Why it exists:** so each guide can start at its first step, and so a failure
that belongs to your machine is answered once, here. **Who should read it:** anyone about to follow a Fast Start or
the install guide for the first time. Come back to "If something went wrong" whenever a guide's Common Issues
section sends you here.

## Table of Contents

<details>
<summary>Expand</summary>

1. [What you need](#what-you-need)
2. [Use Command Prompt on Windows](#use-command-prompt-on-windows)
   - [In Visual Studio Code](#in-visual-studio-code)
   - [In a JetBrains IDE](#in-a-jetbrains-ide)
   - [On a Mac or Linux](#on-a-mac-or-linux)
3. [Log in to your org](#log-in-to-your-org)
4. [Work from your project's top folder](#work-from-your-projects-top-folder)
5. [Check you are ready](#check-you-are-ready)
6. [If something went wrong](#if-something-went-wrong)
   - [VS Code opened PowerShell, not Command Prompt](#vs-code-opened-powershell-not-command-prompt)
   - [npm says running scripts is disabled on this system](#npm-says-running-scripts-is-disabled-on-this-system)
   - [sf is not recognized, or command not found](#sf-is-not-recognized-or-command-not-found)
   - [The CLI has no login for your alias](#the-cli-has-no-login-for-your-alias)
   - [Nothing to deploy, or a stray force-app folder appeared](#nothing-to-deploy-or-a-stray-force-app-folder-appeared)
   - [The deploy reports a conflict](#the-deploy-reports-a-conflict)
   - [Node is the wrong version](#node-is-the-wrong-version)

</details>

## What you need

Three tools, each installed the way its maker describes. Install them in this order, then close and reopen your
terminal so it can find them.

1. **Node.js**, version 22 ([the download page](https://nodejs.org/en/download)). Every script that comes with KernDX
   runs on it, and the Salesforce CLI can install through it.
2. **Git** ([the download page](https://git-scm.com/downloads)). On Windows the installer is called Git for
   Windows; accept its defaults.
3. **The Salesforce CLI** ([the install page](https://developer.salesforce.com/tools/salesforcecli)). Take the
   installer for your system, or install it with npm once Node is in place.

**In the terminal**, to install the CLI with npm:

```shell
npm install -g @salesforce/cli
```

You should see npm finish without an error line. Then check that the CLI answers:

```shell
sf version
```

You should see a line that starts with `@salesforce/cli/`.

## Use Command Prompt on Windows

Every command on this site runs as written in **Command Prompt** on Windows and in the terminal a Mac or Linux
opens by default. Windows has a second terminal, PowerShell, and most editors open that one unless told otherwise.
Most commands still work there, but not all, and its rules for quotes differ, so the guides promise Command Prompt
and nothing else. One line tells you which terminal you are in:

**Windows (Command Prompt)**

```bat
ver
```

**macOS or Linux**

```bash
uname -sr
```

You should see a Windows version line such as `Microsoft Windows [Version 10.0.26100.33438]`, or on a Mac a line
that starts with `Darwin`, on Linux, a line that names the Linux kernel and its version. If Windows answers that `ver` is not
recognized, you are in PowerShell: the first entry under "If something went wrong" says what to do.

### In Visual Studio Code

VS Code opens PowerShell in its built-in terminal unless you tell it otherwise. Two ways to get Command Prompt, both
from VS Code's own page on [terminal profiles](https://code.visualstudio.com/docs/terminal/profiles):

- **For this one terminal:** on the Terminal panel, click the small arrow beside the plus sign and choose
  **Command Prompt**.
- **For good:** open the Command Palette (F1), run **Terminal: Select Default Profile**, and choose
  **Command Prompt**. Every new terminal then opens in Command Prompt, in your project's top folder.

### In a JetBrains IDE

IntelliJ IDEA and its siblings also open PowerShell on Windows. Open **Settings**, then **Tools**, then
**Terminal**, and set **Shell path** to `cmd.exe`, as JetBrains' page on the
[terminal emulator](https://www.jetbrains.com/help/idea/terminal-emulator.html) describes. New terminal tabs then
open in Command Prompt.

### On a Mac or Linux

The built-in terminal of any editor already runs your system's own shell. There is nothing to change.

## Log in to your org

**In the terminal**, replacing `YourOrgAlias` with any short name you like (the guides use it in every command):

```shell
sf org login web --alias YourOrgAlias
```

A browser window opens. Log in there, allow the CLI when Salesforce asks, and close the window when it says you
can. Then confirm the CLI remembers the org:

```shell
sf org list
```

You should see your alias in the list.

## Work from your project's top folder

Every command in every guide runs from the folder that holds `sfdx-project.json`. In VS Code and in a JetBrains
IDE the built-in terminal opens there when the project is open. No project yet? Create an empty one.

**In the terminal:**

```shell
sf project generate --name my-kerndx-project
```

You should see the folder created, with `sfdx-project.json` inside it. Move into it before you run anything else:

```shell
cd my-kerndx-project
```

## Check you are ready

Every Fast Start sends you here before its first step. Run this check once, so a guide's first step is never the
first time you find a problem: first the terminal line under "Use Command Prompt on Windows" above, then these
three.

**In the terminal:**

```shell
sf version
```

```shell
sf org display -o YourOrgAlias
```

```shell
sf package installed list -o YourOrgAlias
```

You should see a version line that starts with `@salesforce/cli/`, then a table of your org's details with your
alias in its `Alias` row, then a table of installed packages with a row whose `Package Name` is `Kern` and whose
`Namespace` is `kern`. If any of the three does not, "If something went wrong" below has the answer.

## If something went wrong

Each entry says what you saw, why it happened, and what to do. The guides' own Common Issues sections send you here
for anything about your computer rather than about the guide.

### VS Code opened PowerShell, not Command Prompt

The line you type on starts with the letters PS, short for PowerShell, and the `ver` check answers with this:

```text
ver : The term 'ver' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```

(PowerShell 7 words it "not recognized as a name of a cmdlet, function, script file, or executable program".)
VS Code opens PowerShell unless told otherwise. Some commands on this site fail there, and on a fresh machine `npm`
does not run at all (the next entry). Switch this terminal, or make Command Prompt the default for good, as
"In Visual Studio Code" above describes; in a JetBrains IDE set the shell path as "In a JetBrains IDE" describes.
Then run the guide's step again.

### `npm` says running scripts is disabled on this system

```text
npm : File C:\Program Files\nodejs\npm.ps1 cannot be loaded because running scripts is disabled on
this system. For more information, see about_Execution_Policies at https:/go.microsoft.com/fwlink/?LinkID=135170.
```

You are in PowerShell on a machine whose policy blocks scripts, and on Windows `npm` itself is a script.
Do not change the policy. Open Command Prompt and run the same line there; it runs unchanged.

### `sf` is not recognized, or command not found

The CLI is not installed, or the terminal was open before the install finished and does not know about it yet.
Close every terminal window, open a new one, and try again:

```shell
sf version
```

Still nothing? Install the CLI from [its install page](https://developer.salesforce.com/tools/salesforcecli) and
open a new terminal afterwards.

### The CLI has no login for your alias

The CLI has no login under the alias the command named. List what it knows:

```shell
sf org list
```

If your org is missing, log in again with the line under "Log in to your org", using the same alias the guide's
commands use.

### Nothing to deploy, or a stray `force-app` folder appeared

The command ran below or outside your project's top folder, so the new files did not land in the project's
`force-app` folder. Delete the stray `force-app` folder, move to the folder that holds `sfdx-project.json`, and start the step again.

### The deploy reports a conflict

Your org tracks source changes and something in it differs from your project's copy, usually because the same
class was edited in the org. Look at what the message names; when your project's copy is the one you want, deploy
it over the org's:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:YourClassName" --ignore-conflicts
```

### Node is the wrong version

A script that comes with KernDX refused to run, or `npm ci` complained about the Node version. What to do depends on
where you are.

**In a checkout of the framework**, the project's `.nvmrc` names the version it needs. Switch to that version:

**Windows (Command Prompt)**

```bat
nvm use 22.22.3
```

**macOS or Linux**

```bash
nvm use
```

You should see the version confirmed. No `nvm` on your machine? Install the Node version the file names from
[Node's download page](https://nodejs.org/en/download).

**In a project of your own** (one where you installed the CI tooling, or one you generated), there is no `.nvmrc`.
Switch to Node 22, the version "What you need" names:

```shell
nvm use 22.22.3
```

You should see the version confirmed. If nvm says that version is not installed, install it with nvm first, then
run this step again. No `nvm` on your machine? Install that version from
[Node's download page](https://nodejs.org/en/download).

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Set%20Up%20Your%20Computer) which step and what you saw.
