---
description: "Task list for OpenQA Hierarchical Navigation and Job Actions"
---

# Tasks: OpenQA Hierarchical Navigation and Job Actions

**Input**: Design documents from `specs/001-openqa-navigation/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: INCLUDED — the project constitution (Principle V) requires every user-facing behavior to
be exercisable by an ERT test. Tests use recorded JSON fixtures and stub `oqa--api-get` (research.md
Decision 7); no live network in CI.

**Organization**: By user story (P1→P6), each independently implementable and testable. Source files
are flat at the repo root (Emacs package convention); tests live under `test/`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different file, no dependency on an incomplete task)
- **[Story]**: US1…US6 for user-story phases only

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Correct the package baseline and record test fixtures.

- [X] T001 Update the `;; Package-Requires:` header in `oqa.el` to `((emacs "27.1") (transient "0.3.0") (dash "2.19.1") (s "1.12.0"))` and bump `;; Version:` (documents the deliberate 27.1 floor from research.md Decision 4)
- [X] T002 [P] Update `.github/workflows/test.yml` Emacs matrix to drop every version below 27.1 (keep 27.1, 27.2, 28.1, 28.2, 29.x, snapshot)
- [X] T003 [P] Record API fixtures into `test/fixtures/`: `job_groups.json`, `group_overview.json`, `jobs.json`, `workers.json`, `job.json`, `autoinst-log.txt` (saved from live o3 GETs per contracts/openqa-endpoints.md)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The API layer, instance/config, shared list mode, dispatch scaffold, and entry-point
rework that every story builds on.

**⚠️ CRITICAL**: No user story can begin until this phase is complete.

- [X] T004 Create `oqa-api.el`: single stubbable `oqa--api-get` (via `url.el`), `oqa--url` builder (query-string encoding incl. repeated multi-value params), `json-parse-buffer` wrapper stripping HTTP headers; `(provide 'oqa-api)`
- [X] T004a In `oqa-api.el`, make `oqa--api-get` return a *structured* error (unreachable host / non-200 / timeout / unparseable JSON) and add a shared `oqa--render-error`, so the spec Edge Cases (unreachable instance, timeout, unexpected schema) show a readable message instead of a raw Lisp error (depends on T004)
- [X] T005 [P] Create `oqa-instance.el`: `oqa-instances` defcustom defaulting to `o3 → https://openqa.opensuse.org` and `osd → https://openqa.suse.de`, buffer-local active-instance state, `oqa--host` resolver (default o3); `(provide 'oqa-instance)`
- [X] T006 Create `oqa-list.el`: `oqa-list-mode` derived from `tabulated-list-mode`, shared keymap (`RET`/`q`/`^`/`g`/`o`/`?`), buffer-local nav context (active instance, parent buffer, group/build/job ids + filter args), `oqa--drill` and `oqa--pop` helpers; `(provide 'oqa-list)`
- [X] T007 Create `oqa-transient.el`: base `transient-define-prefix oqa-dispatch` scaffold + `oqa-dispatch` command bound to `o`/`?` in `oqa-list-mode-map`; `(provide 'oqa-transient)` (depends on T006)
- [X] T008 Rework `oqa.el`: `require` the modules; rewrite the `;;;###autoload oqa` command to open the groups view; **delete** `oqa-status`, the dangling `oqa--save-line`/`oqa--pop-to-buffer`/`oqa--buffer-name`, the broken `(oqa-status 1)` call, and the placeholder `tsc-*` code; keep `(provide 'oqa)` (depends on T004–T007)
- [X] T009 [P] Create `test/oqa-fixture.el` helper (loads `test/fixtures/*` and stubs `oqa--api-get`) and register new test files in `test/oqa-test.el`
- [X] T009a [P] `test/oqa-api-error-test.el`: `oqa--api-get` yields a structured error for non-200 / timeout / bad-JSON (stubbed); `oqa--render-error` produces a readable message

**Checkpoint**: Package byte-compiles on 27.1+, `keg run test` runs (0 real tests yet), foundation ready. Views (T014–T017, T034) render fetch failures via `oqa--render-error`.

---

## Phase 3: User Story 1 - Browse the hierarchy (Priority: P1) 🎯 MVP

**Goal**: `M-x oqa` → all groups → builds → jobs → a job's settings/modules, with `q`/`^` back-nav.

**Independent Test**: Four `RET`s reach a job's modules and back-nav returns cleanly; entry view is
the full group list, not one fixed group (quickstart.md Story 1; SC-001/002).

### Tests for User Story 1 ⚠️ (write first, ensure they fail)

- [X] T010 [P] [US1] `test/oqa-groups-test.el`: groups rows (name + parent) parsed from `job_groups.json` fixture
- [X] T011 [P] [US1] `test/oqa-builds-test.el`: build rows (build/version/total/passed/failed/softfailed/unfinished) from `group_overview.json` fixture
- [X] T012 [P] [US1] `test/oqa-jobs-test.el`: job rows with Flavor/Arch/Machine read from `settings.*` in `jobs.json` fixture
- [X] T013 [P] [US1] `test/oqa-nav-test.el`: nav context set on drill and restored on pop (`oqa--drill`/`oqa--pop`)
- [X] T013a [P] [US1] `test/oqa-job-test.el`: single-job detail — settings key=value pairs and module rows parsed from `job.json` fixture (covers FR-004)

### Implementation for User Story 1

- [X] T014 [P] [US1] Create `oqa-groups.el`: groups view (GET `/api/v1/job_groups`, render Group/Parent, `RET`→builds); `(provide 'oqa-groups)`
- [X] T015 [P] [US1] Create `oqa-builds.el`: builds view (GET `/group_overview/<group_id>.json`, render Build/Version/Total/Pass/Fail/Soft/Unfin., `RET`→jobs) — this is the retired `oqa-status` generalized by group id; `(provide 'oqa-builds)`
- [X] T016 [US1] Create `oqa-jobs.el` (basic, no filters yet): jobs view (GET `/api/v1/jobs?group_id=&build=`, render Id/Test/Flavor/Arch/Machine/State/Result, `RET`→job); `(provide 'oqa-jobs)` (uses nav context from T006)
- [X] T017 [P] [US1] Create `oqa-job.el`: single-job view (GET `/api/v1/jobs/<id>` + `/details`, show settings key=value and module list); `(provide 'oqa-job)`
- [X] T018 [US1] Add the **Navigate** group (`g`/`b`/`j`) and `RET`-show-job to `oqa-dispatch` in `oqa-transient.el` (depends on T014–T017)
- [X] T019 [US1] Finalize the `oqa` entry in `oqa.el` to open the groups view and verify the `M-x oqa` flow end-to-end (depends on T014)

**Checkpoint**: MVP — browsing works top to bottom against o3 with no credentials.

---

## Phase 4: User Story 2 - Filter jobs by state and result (Priority: P2)

**Goal**: Narrow the jobs view by state (running…), result (failed/softfailed…), arch, flavor, etc.

**Independent Test**: A build's jobs narrow by state and by result+arch and widen again; impossible
combo shows an explicit empty state (quickstart.md Story 2; SC-003).

### Tests for User Story 2 ⚠️

- [X] T020 [P] [US2] `test/oqa-jobs-filter-test.el`: `transient-args` → query string, multi-value `state`/`result` become repeated params, default `limit=100`, empty-result path distinct from error

### Implementation for User Story 2

- [X] T021 [US2] In `oqa-jobs.el`, define `oqa-jobs-transient` infixes (`-s`/`-r`/`-a`/`-f`/`-m`/`-t`/`-d`/`-v`/`-n`) and `oqa--jobs-query` that builds the `/api/v1/jobs` query from `(transient-args …)` (depends on T016)
- [X] T022 [US2] In `oqa-jobs.el`, render an explicit "no matching jobs" state distinct from a load error (FR-013)
- [X] T023 [US2] Add the **Filter** group to `oqa-dispatch` in `oqa-transient.el`, showing active filters (depends on T021)

**Checkpoint**: US1 + US2 both work independently.

---

## Phase 5: User Story 3 - Job actions: restart / clone / trigger (Priority: P3)

**Goal**: From a job at point, restart (same), clone (custom settings), or trigger a new build —
confirmed, credentialed, outcome reported.

**Independent Test**: Restart creates a new run without hand-copying ids; clone reflects an edited
value; missing CLI/creds blocks with a message (quickstart.md Story 3; SC-004/006).

### Tests for User Story 3 ⚠️

- [X] T024 [P] [US3] `test/oqa-actions-test.el`: `openqa-cli`/`openqa-clone-job` argument construction for restart/clone/iso; `executable-find` guard blocks and submits nothing when the CLI is absent

### Implementation for User Story 3

- [X] T025 [P] [US3] Create `oqa-actions.el`: `oqa--require-cli` (`executable-find`) guard and `oqa--confirm` helper; `(provide 'oqa-actions)`
- [X] T026 [US3] In `oqa-actions.el`, `oqa-restart-job` → `openqa-cli api --host <HOST> -X POST jobs/<id>/restart`, report outcome (depends on T025)
- [X] T027 [US3] In `oqa-actions.el`, `oqa-clone-job`: `KEY=value` edit buffer (`oqa-clone-mode`, `C-c C-c` submit / `C-c C-k` cancel) prefilled from the job's `settings`, submit via `openqa-clone-job` (depends on T025)
- [X] T028 [US3] In `oqa-actions.el`, `oqa-trigger-iso`: read DISTRI/VERSION/FLAVOR/ARCH/BUILD (prefill from job at point), confirm, POST `isos` (depends on T025)
- [X] T029 [US3] Add the **On job at point** group (`r`/`c`/`T`) — placed in `oqa-jobs-transient` and bound directly in `oqa-jobs-mode`/`oqa-job-mode`, **not** the shared `oqa-dispatch` (per the US2 UX rework: context actions belong where a job is at point, not in the menu shared by groups/builds). Depends on T026–T028

**Checkpoint**: US1–US3 functional; reads still credential-free, only actions touch the CLIs.

---

## Phase 6: User Story 4 - Switch between instances (Priority: P4)

**Goal**: Default to o3; add/switch to osd (and others); all views/actions target the active instance.

**Independent Test**: Fresh start is o3 with no config; switching to osd reloads the entry view
against osd (quickstart.md Story 4; SC-005).

### Tests for User Story 4 ⚠️

- [X] T030 [P] [US4] `test/oqa-instance-test.el`: default active instance is o3; switching changes the host `oqa--url` produces; views read the active host

### Implementation for User Story 4

- [X] T031 [US4] In `oqa-instance.el`, add `oqa-switch-instance` (choose from `oqa-instances`), `oqa-use-o3`/`oqa-use-osd`, and reload the entry (groups) view after switching (depends on T005, T014)
- [X] T032 [US4] Add the **Instance** group (`O`/`D`/`i`) to `oqa-dispatch` in `oqa-transient.el` — also bound directly in `oqa-list-mode`/`oqa-job-mode` for buffer-direct switching (depends on T031)

**Checkpoint**: Multi-instance switching works within a session.

---

## Phase 7: User Story 5 - Inspect workers and their settings (Priority: P5)

**Goal**: List the active instance's workers with status; open a worker to see its properties.

**Independent Test**: Workers list with identity+status; a worker's settings render (quickstart.md
Story 5; SC-007). Independent of US1's job path — only needs Foundational.

### Tests for User Story 5 ⚠️

- [X] T033 [P] [US5] `test/oqa-workers-test.el`: worker rows (`host:instance` + status) from `workers.json` fixture; worker `properties` rendered as settings

### Implementation for User Story 5

- [X] T034 [P] [US5] Create `oqa-workers.el`: workers view (GET `/api/v1/workers`, render Identity/Status/Class, `RET`→worker properties); `(provide 'oqa-workers)` (depends on Foundational only)
- [X] T035 [US5] Add `w` (workers) and worker-`RET` to `oqa-dispatch` in `oqa-transient.el` — `w` also bound directly in `oqa-list-mode`/`oqa-job-mode`; worker `RET` is the list view's `oqa-open` (depends on T034)

**Checkpoint**: Workers surface available; can be built in parallel with US1.

---

## Phase 8: User Story 6 - View logs for a job or worker (Priority: P6)

**Goal**: Open a job's log; degrade worker "log" to status/error (+ running-job log); clear message
when unavailable.

**Independent Test**: Job/worker logs open in-tool; a not-started job reports "unavailable" without
erroring (quickstart.md Story 6; SC-008).

### Tests for User Story 6 ⚠️

- [X] T036 [P] [US6] `test/oqa-log-test.el`: job-log parse from `autoinst-log.txt` fixture; 404/absent path yields an "unavailable" result, not an error

### Implementation for User Story 6

- [X] T037 [US6] In `oqa-job.el`, `oqa-job-log`: GET `/tests/<id>/file/autoinst-log.txt` into a read-only buffer; "log unavailable" on 404 (depends on T017). New `oqa-log.el` holds the shared read-only `oqa-log-mode` + `oqa--log-outcome`; `oqa-api.el` gained `oqa--api-get-text` and a `status` slot on `oqa-error` for 404 detection
- [X] T038 [US6] In `oqa-workers.el`, `oqa-worker-log`: degrade to status/error (+ running-job log if any) with an "unavailable" message (depends on T034)
- [X] T039 [US6] Add `l` (log) on job and on worker — bound directly in `oqa-jobs-mode`/`oqa-job-mode` (→`oqa-job-log`) and `oqa-workers-mode` (→`oqa-worker-log`), plus the jobs transient's "On job at point" group, **not** the shared `oqa-dispatch` (groups/builds have no log, per the context-placement principle). Depends on T037, T038

**Checkpoint**: All six stories independently functional.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T040 [P] checkdoc/docstring pass across all `oqa-*.el` — **checkdoc clean** (error/user-error messages capitalized & de-prefixed per GNU convention; `message` status keeps the `oqa:` prefix). `package-lint` not installable locally (keg absent) — runs in CI
- [X] T041 byte-compiles with no warnings on Emacs 30.2 (`emacs -Q -f batch-byte-compile` over all `oqa-*.el`); package loads clean
- [X] T042 [P] Update `README.org`: usage (`M-x oqa`, dispatch, filters, instances, workers, logs); `master`→`main` badges + modern Actions badge
- [X] T043 [P] Update `CLAUDE.md`: new module map, entry points, `oqa-status` retired, `oqa` is the entry; require-cycle + header-line gotchas
- [X] T044 Full ERT suite green (57 tests); **live o3 read paths validated**: `/api/v1/job_groups` (110 groups), `/api/v1/workers` (716), and a job-log 404 → "unavailable". Interactive per-story keyboard walkthrough left to the user

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (P1)**: no dependencies.
- **Foundational (P2)**: after Setup — **blocks all stories**.
- **User stories (P3–P8)**: all require Foundational. Then:
  - **US1 (P1)** and **US5 (P5)** need only Foundational → can run in parallel.
  - **US2 (P2)** depends on US1 (jobs view).
  - **US3 (P3)** depends on US1 (a job at point).
  - **US4 (P4)** depends on US1 (an entry view to reload).
  - **US6 (P6)** depends on US1 (job log) and US5 (worker log).
- **Polish (P9)**: after the stories you intend to ship.

### Within a story

Tests (fail first) → view/model → transient wiring. Shared files (`oqa-transient.el`, `oqa-jobs.el`)
serialize the tasks that touch them; `[P]` marks only tasks in distinct files.

### Parallel opportunities

- Setup: T002, T003 in parallel.
- Foundational: T005 and T009 in parallel with the T004→T006→T007→T008 chain.
- US1 tests T010–T013 in parallel; views T014/T015/T017 in parallel (T016 after, T018 after all).
- **Whole stories in parallel**: US1 and US5 after Foundational.

---

## Parallel Example: User Story 1

```text
# Tests together (all fail first):
Task: T010 groups rows from fixture (test/oqa-groups-test.el)
Task: T011 build rows from fixture (test/oqa-builds-test.el)
Task: T012 job rows, flavor/arch/machine from settings (test/oqa-jobs-test.el)
Task: T013 nav context drill/pop (test/oqa-nav-test.el)

# Views together (distinct files):
Task: T014 oqa-groups.el
Task: T015 oqa-builds.el
Task: T017 oqa-job.el
```

---

## Implementation Strategy

### MVP first (US1 only)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **stop & validate** browsing on o3 →
demo. This alone kills the "only Tumbleweed" limitation.

### Incremental delivery

Foundation → US1 (MVP) → US2 filters → US3 actions → US4 instances → US5 workers → US6 logs. Each
adds value without breaking earlier stories. US5 can slot in early (parallel with US1) if desired.

---

## Notes

- `[P]` = different file, no incomplete-task dependency.
- Reads stay credential-free; only US3 (`oqa-actions.el`) touches `openqa-cli`/`openqa-clone-job`.
- Verify each story's tests fail before implementing it.
- Commit after each task or logical group; keep `keg run test` green at every checkpoint.
