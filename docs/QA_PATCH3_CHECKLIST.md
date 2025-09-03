# QA Checklist — Patch 3: Schema-driven Interview (Thorough Testing on Emulator)

Scope:
- Validate that Interview prompts are dynamically compiled from JSON Schema at runtime.
- Confirm Patch 2 behaviors remain (Quick/Full modes, resume, voice).
- Target: Android Emulator (as requested).

How to run:
1) flutter pub get
2) flutter devices (confirm emulator or start one)
3) flutter emulators (list) and flutter emulators --launch <emulator_id> (if needed)
4) flutter run -d <device_id>

Record outcomes by checking boxes and filling notes.

---

## 1) App start → Create → Interview (Critical path)

- [ ] App launches to home/dashboard without errors
- [ ] Navigate: Create → Interview screen opens
- [ ] Loading spinner shows while schema compiles
- [ ] Engine starts with first prompt title visible
- [ ] Progress bar updates (non-null once sequence is computed)
- [ ] Confirm engine uses compiled prompts (not demo) by schema tweak + hot restart (see test #3)

Notes:

---

## 2) Answer flow basic (Critical path)

- Single-select
  - [ ] Tap an option advances to next question
  - [ ] Message bubble shows user selection
- Free-text
  - [ ] Typing Enter or Send enqueues user message, advances, persists
- Multi-select
  - [ ] Selecting multiple shows chips; Continue advances
  - [ ] Persist answers per step (_answers updated; see JourneyService seed)
- Resume
  - [ ] Exit/return to interview; previously entered answers are present (seedAnswers working)

Notes:

---

## 3) Dynamic schema change reflection

Action:
- Edit assets/schemas/single-room-color-intake.json (e.g., add enum value to existingElements.metals)
- Save; Hot restart

Validate:
- [ ] New option appears in the corresponding prompt
- [ ] No hard-coded prompts override the dynamic options

Notes (include field edited, value added):

---

## 4) Conditional visibility rules (if/then based)

- [ ] Set existingElements.floorLook = other → floorLookOtherNote becomes visible
- Kitchen (roomType = kitchen):
  - [ ] roomSpecific.backsplash = describe → roomSpecific.backsplashDescribe becomes visible
- Bathroom (roomType = bathroom):
  - [ ] roomSpecific.tileMainColor = color → roomSpecific.tileColorWhich becomes visible
- Entry (roomType = entryHall):
  - [ ] roomSpecific.stairsBanister = wood → roomSpecific.woodTone visible
  - [ ] roomSpecific.stairsBanister = painted → roomSpecific.paintColor visible

Notes:

---

## 5) Room branching and sequence recompute

- [ ] Switch roomType among: kitchen, bathroom, bedroom, livingRoom, diningRoom, office, kidsRoom, laundryMudroom, entryHall, other
- [ ] Sequence updates to include the room-specific prompts of the chosen branch
- [ ] Hidden prompts are skipped automatically (fast-forward logic)

Notes (include any branch anomalies):

---

## 6) Depth switching (Quick ↔ Full)

- [ ] Toggle to Full → extra prompts appear in sequence
- [ ] Toggle back to Quick → extras are removed
- [ ] Index repositioning does not break the flow (no index out of range, smooth continuation)

Notes:

---

## 7) Multi-select constraints (minItems/maxItems)

- [ ] For any prompt with minItems/maxItems, enforce limits in the UI
- [ ] Selecting fewer than minItems shows appropriate constraint feedback (or disabled Continue)
- [ ] Exceeding maxItems is prevented or properly handled

Notes (list tested fields):

---

## 8) Voice mode sanity (Talk)

- [ ] Toggle “Talk” mode
- [ ] Single-select: speech recognition accepts synonyms and maps to a value (veryBright, kindaBright, dim; bulb color variants; loveIt/maybe/noThanks)
- [ ] If ambiguous/unmatched speech → prompts guidance to tap an option
- [ ] Free-text: dictated input submits and advances
- [ ] Multi-select and yes/no: UI asks to tap choices

Notes:

---

## 9) Progress and persistence

- [ ] Progress bar increases as answers recorded
- [ ] Back/Next navigation works (where available)
- [ ] Answers persisted to JourneyService artifacts and rehydrated on resume

Notes:

---

## 10) Fallback behavior

Action:
- Temporarily alter the asset path in InterviewScreen _load() to a non-existent file (or temporarily rename the schema file), then hot restart.

Validate:
- [ ] Engine falls back to InterviewEngine.demo()
- [ ] Error banner shows “Schema load failed, using fallback prompts.”
- [ ] Restore the original path/file and confirm normal behavior resumes

Notes:

---

## Additional Observations

- [ ] No runtime exceptions during any flow
- [ ] Performance acceptable (prompt-to-prompt transition ≤ 200ms on emulator)
- [ ] UI text and help strings render as expected

Notes:

---

## Sign-off

- [ ] All critical-path checks pass (1–2)
- [ ] All thorough checks pass (3–10)
- [ ] Ready to ship Patch 3
