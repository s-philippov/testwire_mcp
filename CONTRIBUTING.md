# Contributing

## Commit messages

This project uses
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(optional scope): <description>
```

Common types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`.

Examples:

```
feat(testwire): add timeout parameter to step()
fix(mcp): handle disconnect during hot reload
docs: update release flow in README
chore(release): publish packages
```

Melos uses these messages to generate changelogs and determine version bumps
automatically.
