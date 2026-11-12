# Burst draft editing implementation plan

**Goal:** Let creators edit unsent drafts and retain safe transaction recovery.
**Architecture:** Existing Flutter create/review screens consume authenticated backend draft read/update endpoints. Atomic backend guards and a pre-broadcast lock prevent edits after submission starts.
**Tech stack:** Flutter/Dart, Actix/Rust, SQLx SQLite/PostgreSQL.
**Spec:** `docs/superpowers/specs/2026-11-12-burst-draft-editing-design.md`

## Tasks

- [x] Backend: add draft read/update and pre-broadcast lock endpoints using the spec contract; share existing validation and transaction generation. Add focused database tests before implementation.
- [x] App: add API methods and restore/edit fields in the existing create form. Persist uncertain edit requests; keep the old prepared response until successful replacement. Route editable drafts to the form and locked drafts to recovery.
- [x] Submission: reserve the backend campaign after approval and before broadcast; preserve unknown local journal semantics. Test refusal prevents broadcasts.
- [x] Verify affected tests/static analysis, review integrated changes, regenerate both knowledge graphs, and document rollout order.

## Review focus

Unknown submissions must never become editable. Stale saves must not overwrite another revision. Timeouts must retain both old recovery and exact retry payloads. Asset restoration must not silently select another token. Backend changes must remain compatible with existing read/recovery paths.

## Verification results

- Flutter: 147 Burst tests passed with `burst_theme_test.dart` excluded. The full run exposed three unrelated invariant-red assertions in that file; the unchanged theme from Git HEAD reproduces the same failure. Five fee-total assertions were updated to include sponsorship and an explicit base-unit network estimate, and now pass.
- Flutter static analysis passed for affected source files and tests. UI static audit found no violations.
- Backend: `cargo check --tests -q` passed. Two focused Rust database tests importing the actual production guard module passed through a small harness. The monolithic server test executable exceeded available memory; no claim is made that the full backend test suite ran.
- Independent review found and then cleared two issues: PostgreSQL stale-reference submission races and replay of superseded preparation keys. The backend now serializes and revalidates submission references and retains durable historical request keys.
- Both knowledge graphs rebuilt. Changed-file formatting and whitespace checks passed.
- Rollout order and migration are documented in `docs/burst-draft-editing.md` in both repositories. No deployment or live transaction performed. Live PostgreSQL concurrency and RPC integration remain environment checks.
