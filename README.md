# MediPrep

MediPrep is an offline-first, on-device app that helps patients prepare for medical visits and keep a structured record of everything that was discussed. It turns a visit into a repeatable workflow: generate focused questions before the appointment, capture answers and recordings during the visit, and store outcomes in a single, searchable place.

## Why I built this

Many patients leave appointments with unanswered questions or realize too late what they should have asked. Studies consistently show that patients ask only a small number of questions during clinical encounters and that gaps are larger for patients with lower health literacy. That is the gap MediPrep is built to close: helping patients arrive prepared, ask better questions, and keep a reliable record of the answers.

Supporting evidence:
- A survey commissioned by Wolters Kluwer Health found that 66% of patients still have questions after a healthcare visit, and 19% develop new questions after the appointment.
- In outpatient consultations, patients ask far fewer questions than clinicians (about 3 vs 15 on average).
- Patients with limited health literacy ask fewer questions than those with adequate health literacy.

## What the app does

- Creates visit folders by patient and condition.
- Generates visit-specific questions on-device.
- Lets users add, edit, and remove questions before and after visits.
- Stores notes, recordings, and attachments per visit.
- Keeps a searchable repository of every visit and its outcomes.

## Technical overview

### Offline-first architecture

- Flutter app with Provider-driven state management.
- A local repository layer (`VisitRepository`) persists data to a JSON file inside the app documents directory (`medi_prep_data.json`).
- All CRUD operations are local and update the in-memory model before being persisted.

### On-device AI for question generation

- Inference runs fully on-device using the `flutter_gemma` runtime.
- The model is downloaded once from Hugging Face (token required for the current model) and then used offline.
- Generation is streamed to the UI, parsed, de-duplicated, and capped for clarity.

### Model used and why

- **Gemma 3 1B (instruction-tuned, quantized)**
  - Small enough for modern phones while still producing coherent, structured questions.
  - Download size is about 0.5 GB, making it feasible for offline use.
  - Optimized for fast local inference and lower memory budgets.

Model source:
- `https://huggingface.co/litert-community/Gemma3-1B-IT`

### On-device document understanding

- Attachments (images and PDFs) are processed locally.
- Google ML Kit runs text recognition and image labeling on-device.
- PDFs are rendered to images and OCR is applied to extract key text.
- Extracted context is summarized and passed into the question generation prompt.

### Audio capture

- Visit recordings are stored locally and managed via a global recording overlay.
- Playback and recording are scoped to a visit, with a persistent banner for background sessions.

## Privacy and data ownership

- No server-side storage and no data sent to a backend.
- Network use is limited to the one-time model download; inference runs offline on-device.
- Visit data, notes, attachments, and recordings remain on the device.

## Quick start

```bash
flutter pub get
flutter run
```

## Demo video

[mediprep_demo.MP4](mediprep_demo.MP4)

## Sources

- Wolters Kluwer survey: two-thirds of patients still have questions after visits (66%), and 19% develop new questions afterward. https://www.wolterskluwer.com/en/news/wolters-kluwer-survey-reveals-two-thirds-of-patients-still-have-questions-after-healthcare-visits
- Patients ask far fewer questions than clinicians (about 3 vs 15) in outpatient consultations. https://pmc.ncbi.nlm.nih.gov/articles/PMC9314071/
- Patients with limited health literacy ask fewer questions than those with adequate health literacy. https://pmc.ncbi.nlm.nih.gov/articles/PMC5384911/
