# Harness adoption plan

The harness was installed in **adopt** mode. Existing `AGENTS.md` / `CLAUDE.md`
were preserved; sidecars were written as `AGENTS.harness.md`, etc.

## Checklist

- [ ] Diff `AGENTS.md` vs `AGENTS.harness.md`; merge ToC entries
- [ ] Verify `docs/` does not collide with existing docs directory
- [ ] Decide which linters in `.harness/linters/` apply to this stack
- [ ] Pick MCP base set in `.harness/mcp/servers.json`
- [ ] Remove `AGENTS.harness.md` sidecars once merged
