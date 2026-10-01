# Agent guidance

This is a personal dotfiles repository. Optimize for simple configuration, readable scripts, and
easy maintenance by one person.

## Keep changes small

- Make the smallest change that fulfills the request. Keep unrelated cleanup separate.
- Prefer existing configuration options and direct code. Keep one-off logic local; introduce abstractions or dependencies only when the current task needs them.
- Build for the environments this repository actually supports. Add portability, fallback behavior, and configurability only for a concrete requirement.
- Keep tooling lightweight. Add automation or process only when requested or needed to solve a recurring problem.

## Documentation

- Treat `README.md` as the front door: a short purpose statement, supported environments, essential setup cautions, the bootstrap entry point, and links to task guides. Aim for roughly one screen or two (about 60 lines, excluding the command); trim or move detail before expanding it.
- Do not turn any README into a detailed product description, feature catalogue, changelog, or implementation report. Put usage and shortcuts in `docs/`, Windows behavior and recovery beside `system/windows/`. A directory README should orient readers and link to its detailed guides.
- Update the guide that owns the changed behavior. Change the root README only when setup, supported environments, the repository layout, or navigation changes; routine feature work belongs in the relevant guide.
- Write for a person completing a task: descriptive headings, short paragraphs, ordered steps for procedures, and tables for shortcuts or comparisons. Lead with the action and expected result; keep command prerequisites, caveats, and recovery details beside the command they affect.
- Keep each fact in one authoritative guide and link to it elsewhere. Preserve setup warnings and recovery instructions when moving content.
- Keep task plans, questionnaires, progress reports, research reports, and session notes outside the tracked repository. Delete completed plan files rather than renaming them into permanent documentation. Retain useful guides describing the current setup; write enduring rationale beside the behavior it explains.
- Before finishing documentation changes, review the diff and check relative links and heading anchors, including links from moved files.

## Validation

- Default to syntax checks, rendered diffs, and focused manual verification for dotfiles and scripts. Use the preview for styling, layout, icons, and animations. Documentation-only edits need a diff review.
- Keep Canopy's automated suite small and focused on costly regressions: launcher reliability and shutdown, correct monitor targeting, failed or denied Windows-setting changes, and hotkey timeouts.
- Run the relevant retained tests when changing those behaviors. Add a test only for a concrete regression that is difficult to check manually; reuse existing fixtures and keep machine interactions mocked or isolated.
- Prefer representative behavior checks over exhaustive combinations or assertions about implementation details. Coverage targets and a new test for every change are unnecessary.

## Commit messages and PR titles

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `<type>[optional
scope][!]: <description>`.

- Use `feat` for new behavior, `fix` for corrections, and `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `style`, `chore`, or `revert` as appropriate.
- Write a short, imperative description beginning with a lowercase word, without a trailing period. Add a scope only when it clarifies the affected area.
- Mark breaking changes with `!` and explain the required migration in a `BREAKING CHANGE:` footer.
- Example: `fix(whkd): correct launcher shortcut`.

## Branches and PR bodies

Use these repository conventions:

- New work branches: `<type>/<short-kebab-case-description>`, using the types above. Example: `fix/launcher-shortcut`.
- Keep each PR focused on one coherent change. Its title follows the commit format above.
- When writing or updating a PR body, follow [.github/pull_request_template.md](.github/pull_request_template.md) for section contents, validation reporting, issue links, and the shorter format for small changes.
