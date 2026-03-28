## Summary
- 

## Change Type
- [ ] Feature
- [ ] Bug fix
- [ ] Docs
- [ ] Refactor
- [ ] CI/automation

## Validation
- [ ] `bash -n scripts/popos-auto.sh scripts/full-setup.sh scripts/agent-configure.sh`
- [ ] `ansible-playbook --syntax-check -i ansible/inventory.yml ansible/site.yml`
- [ ] `python3 scripts/linux/validate-migration-context.py --all-contexts --context-root migration/context`
- [ ] `./scripts/linux/check-migration-allowlist.sh --all`

## Migration/Fusion Safety
- [ ] No raw or sensitive migration files are committed
- [ ] Fusion provider is native-first when Fusion is required (`codeberg-script` + `bottles` fallback)
- [ ] No archived Fusion installer URLs were introduced

## Notes for Reviewers
- 
