# Workstation Setup Skill

## Purpose
Provide a clone-time, AI-guided setup flow for Pop!_OS (COSMIC) that can adapt to different hardware and user preferences.

## Trigger Commands
- `/workstation`
- `/workstation-setup`
- `/linux-setup`
- `/configure-workstation`
- `/drives`

## Core Rule
If the repo does not unambiguously define a choice, the agent should ask questions before applying state changes. Drive layout is always treated as a confirmation step.

## Agent Execution Flow

### Phase 1: Preflight and hardware context
Run:

```bash
cd <repo-directory>
./scripts/full-setup.sh --check
./scripts/full-setup.sh --hardware
```

Artifacts produced for AI decisions:
- `logs/hardware/hardware-report-latest.json`
- `logs/hardware/hardware-report-latest.txt`

### Phase 2: Guided configuration (question-first)
Run:

```bash
./scripts/agent-configure.sh --guided
```

This asks for:
1. Setup profile (`full|gaming|dev|minimal`)
2. Install mode (`fresh|dualboot|existing-pop`)
3. Drive mapping (OS, games, storage, backup)
4. Mount points
5. Optional Fusion 360 + cloud setup intent

Answers are saved to:
- `config/deployment.local.env`

Optional fstab proposal:
- `logs/hardware/fstab-plan-<timestamp>.txt`

### Phase 3: Provision software
Use the selected profile:

```bash
source config/defaults.env
test -f config/deployment.local.env && source config/deployment.local.env
./scripts/full-setup.sh --profile "${DEPLOY_PROFILE:-full}"
```

### Phase 4: Validate result
Run:

```bash
./scripts/post-install-check.sh
./scripts/full-setup.sh --verify
```

## Drive-layout decision policy
Before writing mount config, the agent should confirm:
- Which disk/partition should be `/mnt/games`
- Whether to mount `/mnt/storage` and `/mnt/backups` now
- Whether this is fresh install vs dual boot

If the user does not answer, safe defaults are:
- Do not modify `/etc/fstab`
- Create mount directories only
- Continue package/software provisioning

## Fast paths

### Non-interactive automation
```bash
./scripts/agent-configure.sh --non-interactive --preset dual-disk
source config/defaults.env
test -f config/deployment.local.env && source config/deployment.local.env
./scripts/full-setup.sh --profile "${DEPLOY_PROFILE:-full}"
./scripts/post-install-check.sh
```

### Full workstation
```bash
./scripts/agent-configure.sh --guided
source config/defaults.env
test -f config/deployment.local.env && source config/deployment.local.env
./scripts/full-setup.sh --profile "${DEPLOY_PROFILE:-full}"
./scripts/post-install-check.sh
```

### Gaming only
```bash
./scripts/full-setup.sh --profile gaming
./scripts/post-install-check.sh
```

### Dev only
```bash
./scripts/full-setup.sh --profile dev
./scripts/post-install-check.sh
```
