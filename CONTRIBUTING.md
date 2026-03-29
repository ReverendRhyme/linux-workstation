# Contributing

Thanks for contributing to `linux-workstation`.

## Ground Rules

- Prefer Ansible roles/modules for system configuration changes.
- Use shell scripts for orchestration only.
- Keep changes idempotent and safe to re-run.
- Do not commit local secrets or machine-specific local env files.

## Local Setup

```bash
python3 -m venv .venv-lint
.venv-lint/bin/pip install ansible ansible-lint yamllint pre-commit
pre-commit install
```

## Validation Before PR

```bash
bash -n scripts/full-setup.sh scripts/popos-auto.sh scripts/agent-configure.sh scripts/hardware-report.sh
bash -n scripts/linux/import-migration-context.sh scripts/linux/check-migration-allowlist.sh scripts/linux/btrfs-snapshot-loop.sh scripts/linux/run-baremetal-test-loop.sh scripts/linux/install-baremetal-loop-resume-service.sh
python3 scripts/linux/validate-migration-context.py --help
python3 scripts/linux/validate-migration-context.py --all-contexts --context-root migration/context
ansible-playbook --syntax-check -i ansible/inventory.yml ansible/site.yml
ansible-lint ansible/
yamllint .
./scripts/linux/check-migration-allowlist.sh --all
pre-commit run --all-files
```

## Commit Guidance

- Keep commits focused and descriptive.
- Mention the user impact in the commit body.
- For behavior changes, update docs in the same PR.

## Legacy Scripts

The repository is Ansible-first. Legacy helper scripts under `legacy/modules/` and legacy shared helpers under `legacy/core/` are retained for reference/migration only unless explicitly called out in an issue.
