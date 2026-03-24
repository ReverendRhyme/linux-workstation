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
ansible-playbook --syntax-check -i ansible/inventory.yml ansible/site.yml
ansible-lint ansible/
yamllint .
pre-commit run --all-files
```

## Commit Guidance

- Keep commits focused and descriptive.
- Mention the user impact in the commit body.
- For behavior changes, update docs in the same PR.

## Legacy Scripts

The repository is Ansible-first. Legacy helper scripts under `scripts/modules/` and older validation helpers are retained for reference/migration only unless explicitly called out in an issue.
