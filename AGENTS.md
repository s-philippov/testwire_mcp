# Agents

Instructions for AI agents working in this repository.

## Releasing

All packages use **fixed versioning** — they are always released together at
the same version.

### Steps

1. Make sure all changes are committed using
   [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
   (`feat:`, `fix:`, `refactor:`, `docs:`, etc.).

2. Run the bump script:

   ```sh
   ./scripts/bump.sh              # auto-detect from commits
   ./scripts/bump.sh patch        # force patch bump
   ./scripts/bump.sh minor        # force minor bump
   ./scripts/bump.sh major        # force major bump
   ./scripts/bump.sh 0.3.0        # force exact version
   ```

   This bumps all packages, updates changelogs, and creates a git tag.

3. Push with tags to trigger CI publish:

   ```sh
   git push --follow-tags
   ```

   The `publish.yml` workflow publishes packages to pub.dev in dependency order:
   `testwire_protocol` → `testwire` → `testwire_flutter` → `testwire_mcp`.

### Commit conventions and bump types

| Commit prefix    | Bump  | Example                     |
|------------------|-------|-----------------------------|
| `fix:`           | patch | `fix(mcp): handle disconnect` |
| `feat:`          | minor | `feat(testwire): add timeout` |
| `BREAKING CHANGE:` | major | footer in commit body       |
| `chore:` / `docs:` / `ci:` | none | `docs: update README` |
