# Agent guidance

This is a personal dotfiles repository. Optimize for simple configuration, readable scripts, and easy maintenance by one person.

## Keep changes small

- Make the smallest change that fulfills the request. Keep unrelated cleanup separate.
- Prefer existing configuration options and direct code. Keep one-off logic local; introduce abstractions or dependencies only when the current task needs them.
- Build for the environments this repository actually supports. Add portability, fallback behavior, and configurability only for a concrete requirement.
- Keep tooling lightweight. Add automation or process only when requested or needed to solve a recurring problem.
- For configuration and styling, prefer syntax checks, rendered diffs, and focused manual verification. Documentation-only edits need a diff review.
- For scripts and application code, run relevant existing tests. Add tests only for meaningful behavior or recurring bugs; automated tests and coverage targets are not required for every change.

## Commit messages and PR titles

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `<type>[optional scope][!]: <description>`.

- Use `feat` for new behavior, `fix` for corrections, and `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `style`, `chore`, or `revert` as appropriate.
- Write a short, imperative description beginning with a lowercase word, without a trailing period. Add a scope only when it clarifies the affected area.
- Mark breaking changes with `!` and explain the required migration in a `BREAKING CHANGE:` footer.
- Example: `fix(whkd): correct launcher shortcut`.

## Branches and PR bodies

Use these repository conventions:

- New work branches: `<type>/<short-kebab-case-description>`, using the types above. Example: `fix/launcher-shortcut`.
- Keep each PR focused on one coherent change. Its title follows the commit format above.
- When writing or updating a PR body, follow [.github/pull_request_template.md](.github/pull_request_template.md) for section contents, validation reporting, issue links, and the shorter format for small changes.
