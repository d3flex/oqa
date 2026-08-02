# Quickstart & Validation: OpenQA Hierarchical Navigation and Job Actions

How to run oqa during development and validate each user story end-to-end. See
[data-model.md](./data-model.md), [contracts/openqa-endpoints.md](./contracts/openqa-endpoints.md),
and [contracts/commands.md](./contracts/commands.md) for the details this guide references.

## Prerequisites

- Emacs **27.1+** (json-parse-buffer + transient). Terminal `-nw` is fine.
- Runtime deps loadable: `transient`, `dash`, `s` (already present via `package-initialize` on this
  machine).
- For Story 3 (mutations) only: `openqa-cli` / `openqa-clone-job` on `PATH` and a
  `~/.config/openqa/client.conf` entry for the target host. Not needed for Stories 1, 2, 4, 5, 6
  against public o3.

## Run it (dev loop)

```sh
cd ~/Projects/dev/oqa
emacs -nw -Q -L . --eval '(package-initialize)' --eval "(require 'oqa)"
```
Then `M-x oqa`. Edit a file → `M-x eval-buffer` → re-run `M-x oqa` to iterate.

## Automated tests

```sh
keg run test        # or, without keg:
emacs --batch --eval '(package-initialize)' -Q -L . \
  --load=test/oqa-test.el -f ert-run-tests-batch-and-exit
```
Tests stub `oqa--api-get` with `test/fixtures/*.json` — no live network (research.md, Decision 7).

## Story-by-story validation

### Story 1 (P1) — Browse the hierarchy
1. `M-x oqa` → **groups** view lists many groups (≈110 on o3), with a Parent column.
2. `RET` on a group → **builds** view with Build/Version/Total/Pass/Fail/Soft/Unfin.
3. `RET` on a build → **jobs** view with Id/Test/Flavor/Arch/Machine/State/Result.
4. `RET` on a job → **job** view: settings (key=value) + module results.
5. `q`/`^` steps back up to each parent.
✅ Pass when four `RET`s reach a job's modules and back-nav returns cleanly (SC-001), and the entry
view is the full group list, not one fixed group (SC-002).

### Story 2 (P2) — Filter jobs by state and result
1. In a jobs view, `o` → set `-s running` → refresh; only running jobs listed.
2. Set `-r failed` + `-r softfailed` + `-a x86_64` → refresh; only those remain.
3. Confirm the transient shows the active filters; clear one → list widens.
4. Set an impossible combo → explicit "no matches", distinct from an error.
✅ Pass when a build's jobs narrow by state and by result+arch and widen again (SC-003).

### Story 3 (P3) — Job actions (needs creds)
1. On a finished job, `o` → `r` (restart same) → confirm → new run reported.
2. `o` → `c` (clone custom) → edit one `KEY=value` → `C-c C-c` → new run reflects the edit.
3. `o` → `T` → supply DISTRI/VERSION/FLAVOR/ARCH/BUILD → confirm → product scheduled.
4. With CLI absent or no creds → action blocked with a clear message, nothing submitted.
✅ Pass when a restart creates a new run without hand-copying ids (SC-004) and every mutation
confirmed / 0 run without creds (SC-006).

### Story 4 (P4) — Instances
1. Fresh start → active instance is **o3** with no configuration (SC/FR-023a).
2. `o` → `D` (or `i` → choose) switch to osd → entry view reloads against osd.
✅ Pass when switching between two instances in one session shows the second's data (SC-005).

### Story 5 (P5) — Workers
1. `o` → `w` → workers listed with identity + status.
2. `RET` on a worker → its properties/settings.
✅ Pass when workers list and a worker's settings render (SC-007).

### Story 6 (P6) — Logs
1. On a finished job, `o` → `l` → autoinst log opens read-only.
2. On a not-yet-started job → "log unavailable" message, no error.
3. On a worker, `o` → `l` → status/error (+ running-job log if any) or "unavailable".
✅ Pass when job/worker logs open in-tool and unavailability is reported clearly (SC-008).

## Constitution smoke checks

- Reads work with **no** `client.conf` present (Principle III) — run Stories 1/2/4/5/6 on a machine
  with no credentials.
- `keg lint` clean; `Package-Requires` shows `emacs "27.1"` (Principle V, documented floor).
- No host/group/distri literal in any reached code path except the o3/osd defaults in
  `oqa-instances` (Principle II).
