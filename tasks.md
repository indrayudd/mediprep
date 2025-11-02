# Build Plan — MediPrep (Gemma 3 1B IT)

These phases assume a 5-hour implementation window and build on the existing Gemma 3 1B IT integration already running in the Flutter app.

## Phase 1 — Core Scaffolding (Hour 0–1)
- [ ] Confirm Gemma 3 1B IT model install path and warm-up on target device; document any missing assets.
- [ ] Stub command routing structure (placeholder CLI entry points) mirroring the spec’s folder/visit flows.
- [ ] Define SQLite schema for folders, visits, and questions; add migration bootstrap script.

## Phase 2 — Folder & Visit Workflows (Hour 1–2)
- [ ] Implement CRUD helpers for folders/visits and wire them into CLI commands (`list`, `search`, `view`, `add`).
- [ ] Ensure visit creation flow captures all required fields and persists them atomically.
- [ ] Add unit smoke tests for datastore helpers (happy path + basic validation).

## Phase 3 — Gemma Question Generation (Hour 2–3)
- [ ] Wrap the existing Gemma 3 1B IT session in a reusable Dart service exposed to the CLI layer.
- [ ] Implement five-question generation pipeline using visit context; include retry/backoff on empty output.
- [ ] Persist generated questions and expose delete/undo/add flows in the CLI.

## Phase 4 — Notes, Summaries, and Storage (Hour 3–4)
- [ ] Add mechanisms to record or paste visit notes, storing raw transcripts linked to visits.
- [ ] Use Gemma 3 1B IT to summarize transcripts; store summaries alongside raw notes.
- [ ] Organize visit assets (audio/text) under deterministic per-visit directories.

## Phase 5 — Polish & Verification (Hour 4–5)
- [ ] Harden input validation, error reporting, and model failure messaging.
- [ ] Add scripted end-to-end run (sample data) to demo the CLI workflow.
- [ ] Update documentation with setup steps, Gemma model requirements, and CLI usage guide.
