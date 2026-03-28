# OpenCode Skills

Custom skills for provisioning a Linux workstation from this repository.

## Available Skills

### `/workstation` or `/linux-setup`
Complete Pop!_OS workstation provisioning.

**What it does:**
1. System readiness check
2. Ansible bootstrap (all software)
3. Drive configuration
4. Gaming setup
5. CAD/3D design setup
6. 3D printing setup
7. Cloud storage setup
8. COSMIC desktop config
9. Development tools
10. Security setup
11. Verification

**Usage:**
```
/workstation
```

### `/configure-workstation`
Guided question-first configuration before provisioning.

**What it does:**
1. Generates hardware report
2. Prompts for profile, install mode, and drive layout
3. Saves deployment answers for reuse
4. Optionally generates fstab proposal

**Usage:**
```
/configure-workstation
```

### `/popos-setup`
Dedicated end-to-end Pop!_OS (COSMIC) setup automation.

**What it does:**
1. Runs system pre-check
2. Generates hardware report
3. Runs guided configuration prompts
4. Provisions selected profile
5. Runs verification checks

**Usage:**
```
/popos-setup
```

Equivalent local command:
```bash
./scripts/popos-auto.sh
```

### `/game-setup`
Gaming-focused setup for Steam, Epic, GOG, and mod management.

**What it does:**
1. Bootstrap gaming stack
2. Steam + Proton configuration
3. Heroic Games Launcher
4. MangoHud + Gamemode
5. Vortex mod manager
6. Discord

**Usage:**
```
/game-setup
```

## How Skills Work

When you invoke a skill, the AI agent:
1. Loads the skill workflow
2. Asks clarifying questions when repo defaults are ambiguous
3. Executes the setup scripts
4. Handles any errors or prompts
5. Verifies the installation

## Manual Setup

If you prefer to run things step-by-step:

```bash
cd <repo-directory>
./scripts/agent-configure.sh --guided
./scripts/full-setup.sh --check    # Check system
source ./config/defaults.env
test -f ./config/deployment.local.env && source ./config/deployment.local.env
./scripts/full-setup.sh --profile "${DEPLOY_PROFILE:-full}"
./scripts/full-setup.sh --verify    # Verify
```

## Prerequisites

Before running any skill:
1. Pop!_OS with COSMIC installed
2. Clone this repo: `git clone <your-fork-url>`
3. Have sudo access
4. Internet connection

## Repository

<your-repository-url>
