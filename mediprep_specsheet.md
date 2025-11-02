# MediPrep App Specification Sheet (5-Hour CLI Implementation Plan)

### Project Overview
MediPrep is a command-line–based prototype designed to help patients prepare for doctor visits by capturing appointment details, generating AI-based question lists, and recording summarized visit notes. The MVP will be built entirely via CLI tools (Python, Gemini CLI, SQLite) and will not depend on external APIs or UI frameworks.

---

## 1. Core Concept
**Goal:** Deliver a fully functional CLI app in 5 hours that:
- Lets users create, view, and manage medical visit records.
- Generates intelligent questions using a lightweight, local AI model.
- Records and summarizes visit notes.
- Runs fully offline.

---

## 2. Core Features (CLI Equivalents)

### **1. Folder Management (Page 1 Equivalent)**
- Command: `list-folders`
- Lists all illness folders (each with patient name, illness, doctor, hospital, last modified date, number of visits).
- Search using: `search-folders [keyword]`
- Sort using flags: `--sort=newest`, `--sort=oldest`, `--sort=visits`
- Create new visit: `add-visit`

**Data:** Stored in SQLite (`folders` table).

---

### **2. Folder Detail View (Page 2 Equivalent)**
- Command: `view-folder [folder_id]`
- Shows folder metadata and list of all visits.
- Each visit shows: visit ID, date, title, number of questions.
- Return to main view: `back`

**Data:** Stored in `visits` table, linked to folder via `folder_id`.

---

### **3. Visit Type Selection (Page 3)**
- CLI prompt after `add-visit`:
  ```
  Is this a first-time visit or a follow-up?
  1. First-time
  2. Follow-up
  ```
  Input `1` → new folder (Page 6 equivalent).
  Input `2` → attach to existing folder (Page 4 equivalent).

---

### **4. Folder Selection for Follow-up (Page 4)**
- Command: `select-folder`
- Lists all folders; user picks one by index.
- Then auto-navigates to visit creation flow.

---

### **5. Create New Visit (Page 6)**
- Command: `create-visit`
- CLI prompts for inputs:
  ```
  Visit Name:
  Visit Date (YYYY-MM-DD):
  Doctor Name:
  Hospital Name:
  Illness Type:
  Description:
  ```
- Optional: `--attach [file_path]` to include a file.
- Saves record in SQLite and triggers AI question generation.

---

### **6. Generate Questions (Page 8)**
- Command auto-runs after creating a visit.
- Reads illness name and uses local dataset/AI model to generate 5 context-based questions.
- Displays them as a numbered list with options:
  ```
  [1] Delete Question
  [2] Undo Delete
  [3] Add Custom Question
  [4] Record Answers
  [5] Exit
  ```
- For recording, uses CLI mic input (or text input fallback).

---

## 3. AI & Data Components

### **AI Model (Offline)**
- Type: Small pre-downloaded text model (GPT4All or Mistral-7B-instruct via local inference).
- Usage:
  - Generate 5 illness-related questions.
  - Summarize visit transcript.
- Data never leaves the device.

### **Dataset (JSON Example)**
```json
{
  "flu": [
    "How long should I take rest?",
    "Do I need antibiotics?",
    "What symptoms should I monitor?",
    "Can I return to work or school soon?",
    "What home remedies can help my recovery?"
  ]
}
```

---

## 4. Technical Specifications

| Component | Technology | Description |
|------------|-------------|-------------|
| **Language** | Python 3 | CLI and logic scripting |
| **Database** | SQLite | Store folders, visits, and transcripts |
| **AI Engine** | GPT4All (local inference) | Offline question and summary generation |
| **Transcription** | OpenAI Whisper CLI (offline) | Speech-to-text recording conversion |
| **Audio Recording** | Python `sounddevice` or OS mic utility | Record answers locally |
| **Storage** | Local file system + SQLite | Secure offline persistence |

---

## 5. 5-Hour Build Plan

### **Hour 1: Project Setup & Database Schema**
- Initialize Python project & virtual environment.
- Create `folders`, `visits`, and `questions` tables in SQLite.
- Define folder & visit CRUD commands.
- Test basic folder creation and listing.

### **Hour 2: Command Routing & CLI Flow**
- Build CLI structure using `argparse` or `click`.
- Implement `list-folders`, `search`, `sort`, `add-visit`, `view-folder`.
- Test data navigation between folder and visit views.

### **Hour 3: Question Generation & Data Handling**
- Load mock JSON dataset.
- Implement illness-based question generation logic.
- Add options for deleting, undoing, and adding manual questions.
- Display all outputs cleanly in CLI tables.

### **Hour 4: Recording & Summary Integration**
- Integrate `sounddevice` for simple voice input.
- Store `.wav` files under visit directories.
- Use Whisper CLI for transcription.
- Use GPT4All CLI for summarizing transcript text.
- Store both full and summary transcripts in database.

### **Hour 5: Final Polish, Testing, and Demo Prep**
- Add error handling and input validation.
- Add CLI color formatting for clean UX (`colorama` or `rich`).
- Test all flows end-to-end.
- Prepare a demo walkthrough script.

**Deliverable:** Fully functional CLI prototype with offline AI, audio, and data storage.

---

## 6. Expected Output
A sleek, command-line productivity app that enables patients to:
- Log and manage visit details offline.
- Generate and customize AI-driven doctor questions.
- Record and summarize visit conversations.
- Retrieve and search all visit data seamlessly from the terminal.

**Tagline:** “MediPrep — Be prepared, every visit.”

