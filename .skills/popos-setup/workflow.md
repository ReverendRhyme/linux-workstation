# Pop!_OS Setup Skill

## Purpose
Automate setup of a freshly installed Pop!_OS (COSMIC) machine after repository clone.

## Trigger
- `/popos-setup`

## Required behavior
If drive layout, install mode, or mount targets are ambiguous, ask the user before making mount-related decisions.

## Execution flow

### One-command path (recommended)
```bash
cd <repo-directory>
./scripts/popos-auto.sh
```

This wrapper handles guided configuration, profile provisioning, and verification.

For unattended provisioning:

```bash
./scripts/popos-auto.sh --non-interactive --preset dual-disk
```

### 1) Pre-check
```bash
cd <repo-directory>
./scripts/full-setup.sh --check
```

### 2) Build hardware context for decision making
```bash
./scripts/full-setup.sh --hardware
```

Primary artifact for AI decisions:
- `logs/hardware/hardware-report-latest.json`

### 3) Guided configuration
```bash
./scripts/agent-configure.sh --guided
```

This saves decisions to:
- `config/deployment.local.env`

### 4) Provision selected profile
```bash
source ./config/defaults.env
test -f ./config/deployment.local.env && source ./config/deployment.local.env
./scripts/full-setup.sh --profile "${DEPLOY_PROFILE:-full}"
```

### 5) Verify
```bash
./scripts/post-install-check.sh
./scripts/full-setup.sh --verify
```

## Dry-run mode
Before execution, show the planned actions:

```bash
./scripts/popos-auto.sh --dry-run
```
