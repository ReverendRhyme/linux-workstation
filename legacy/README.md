# Legacy Scripts

These scripts predate the Ansible-first automation strategy. They are kept
for reference but are not used by the active provisioning path
(`popos-auto.sh` -> `full-setup.sh` -> `ansible-playbook`).

- `core/` -- Shared bash libraries (logging, utils, validation)
- `modules/` -- Per-category installer functions

To use the canonical automation, run `./scripts/popos-auto.sh` or
`./scripts/full-setup.sh --profile <name>`.
