# MediPrep App Specification

_Last updated: current development state_

## Architecture Overview
- **Framework:** Flutter (Material design) with Provider for app-wide state.
- **State store:** `VisitRepository` hydrates from a JSON file managed by `LocalVisitStore`. All folder/visit mutations go through repository APIs to keep data sorted and persisted.
- **Models:**
  - `VisitFolder`: patient metadata, doctor/hospital, timestamps, and ordered list of `VisitRecord`s.
  - `VisitRecord`: visit title, date, notes, generated/custom questions, attachments, recordings, timestamps.
  - `RecordingMeta`, `QuestionNote`, `VisitAttachment`, etc. capture visit assets.

## Home Screen
- Shows searchable list of folders (patient + condition). Search covers patient, condition, doctor, and hospital fields.
- FAB launches `VisitFormScreen` for creating a new visit (optionally a new folder).
- Each folder card includes a three-dot menu:
  - **Edit:** opens a sheet to update patient, condition, doctor, hospital.
  - **Delete:** asks for confirmation, then permanently removes the folder and all visits via `deleteFolder`.
- Tapping a card opens `FolderDetailScreen`.

## Folder Detail Screen
- Header displays patient summary and quick chips for doctor/hospital.
- List of visits ordered by date with contextual menu per visit:
  - **Edit:** sheet to change title, date (date picker), and description. Persists with `updateVisitDetails`.
  - **Delete:** confirmation dialog; removal uses `deleteVisit`.
- App bar menu mirrors folder edit/delete actions for quick access.
- FAB creates a new visit preselecting the folder.

## Visit Creation & Question Generation
- `VisitFormScreen` guides through selecting/creating a folder and entering visit info.
- After submission, `QuestionGenerationScreen`:
  - Streams LLM output (Gemma) into numbered questions.
  - Parses text, strips numbering artifacts, rejects blank/“s” tokens, limits to 15.
  - Allows manual question additions via bottom sheet.
  - Allows removing any generated/manual question inline; removed prompts are tracked so they do not reappear when saving.
  - Provides regen + save controls. Saving persists folder/visit, questions, and navigates to visit detail.

## Visit Detail Screen
- Shows visit summary, questions, recordings, attachments, and notes.
- “Add more” question button presents a bottom sheet (overlay detaches/re-attaches to avoid UI overlap).
- Each question card has a remove icon that updates repository via `updateQuestions`.
- Recording section lists `RecordingMeta` entries with play buttons that route through the overlay controller.

## Recording Overlay & Audio UX
- `RecordingOverlayController` is a global ChangeNotifier:
  - Manages recording + playback state, session metadata, waveform amplitude, timers, and audio player.
  - Enforces one active session. Recording/playing is scoped to a visit; other screens only show top banners.
  - Banner behavior per `recording behaviour.md`: red while recording, blue while playing; tapping jumps to owning visit.
  - Floating bottom panel only renders for the visit owning the active recording or playback.
  - Panel includes waveform/elapsed timer, playback progress bar, ±5s skip, replay control, close button, and a red circular record button (iOS style).
  - Banner “Stop” button terminates the active session.
  - “Add More” detaches overlay while the sheet is open to prevent overlap, then re-attaches.

## Recording List
- `RecordingListSection` renders cards with metadata and play icons. Tapping play uses the overlay; UI guards against `setState` after dispose.

## Model Management
- `HomeScreen`, folder, visit, and question screens expose a cog icon to change the LLM (except “First-time visit” card which uses sparkles as requested).
- Model selection persists through `ModelPreferences`; `ModelSetupScreen` handles initial onboarding.

## Data Persistence & Sorting
- Repository keeps `_folders` sorted by `updatedAt` descending after every mutation.
- Visit lists are sorted by `visitDate` descending to show most recent first.
- All CRUD paths notify listeners and call `_persist()` to save JSON asynchronously.

## Deletion & Editing UX Best Practices
- All destructive actions are confirmed via `AlertDialog`.
- Snackbar feedback follows success/failure of edits/deletes.
- Edit sheets reuse shared widgets for consistent styling, form validation, safe areas, and CTA combos (Cancel/Save).

## Recording Behaviour Summary
1. **Within owning visit:** panel shows full controls during recording or playback.
2. **Other visits:** overlay hidden; only banner shows to indicate cross-visit activity.
3. **Starting new record while another visit is playing:** pressing record handles stop + start flow automatically.
4. **Completion while viewing another visit:** banner disappears, base record widget reappears.

## Files & Modules of Interest
- `lib/main.dart` – bootstraps providers, shared navigator/messenger keys, wraps app in `RecordingOverlayHost`.
- `lib/widgets/recording_overlay.dart` – entire recording UI/controller logic.
- `lib/screens/visit_detail_screen.dart` – integrates overlay config, question removal, recording list.
- `lib/screens/question_generation_screen.dart` – handles LLM stream, parsing, manual edits.
- `lib/screens/home_screen.dart`, `lib/screens/folder_detail_screen.dart` – folder/visit management, new edit/delete menus.
- `lib/widgets/edit_sheets.dart` – shared edit sheets for folders and visits.

This document reflects the latest behaviour implemented during the recent bugfix and UX iteration pass. Keep it updated alongside future feature work.
