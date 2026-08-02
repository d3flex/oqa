# Phase 0 Research: OpenQA Hierarchical Navigation and Job Actions

All endpoint shapes below were verified live against `https://openqa.opensuse.org` (o3) on
2026-08-02 via read-only GETs.

## Decision 1 — Read endpoints per view

**Decision**: Back each navigation level with these endpoints.

| View | Endpoint | Response shape | Columns sourced |
|---|---|---|---|
| groups | `GET /api/v1/job_groups` | JSON array of group objects | `name`, `parent_id` (→ parent name) |
| builds | `GET /group_overview/<group_id>.json` | `{build_results:[…], group, …}` | `build`/`version`/`total`/`passed`/`failed`/`softfailed`/`unfinished` |
| jobs | `GET /api/v1/jobs?group_id=&build=&<filters>` | `{jobs:[…]}` | `id`, `test`, `settings.FLAVOR/ARCH/MACHINE`, `state`, `result` |
| job | `GET /api/v1/jobs/<id>` (+ `.../details` for modules) | `{job:{…}}` / details | `settings` (key=value), `modules` |
| workers | `GET /api/v1/workers` | `{workers:[…]}` | `host`+`instance`, `status`, `properties.WORKER_CLASS` |

**Rationale**: These are the stable documented REST routes; `group_overview/<id>.json` is the same
web route the prototype already uses and returns the pre-aggregated build counts, so the builds
view is a direct generalization of the old `oqa-status` (group id is now a parameter, not `1`).

**Alternatives considered**: Building the build overview from `/api/v1/jobs` aggregation ourselves —
rejected: `group_overview` already computes passed/failed/softfailed/total, so re-aggregating is
wasted work and drift risk (Principle IV).

**Field gotchas discovered live**:
- Job `flavor`/`arch`/`machine` are **inside `settings`** (uppercase `FLAVOR`/`ARCH`/`MACHINE`),
  not top-level job fields.
- Group `parent_id` is `null` for top-level groups → render parent as "" and support grouping.
- Worker identity is `host` + `instance` (e.g. `worker1:3`); `status` ∈ {running, idle, dead,
  broken, …}; per-worker config lives in `properties` (`WORKER_CLASS`, `CPU_ARCH`, `MEM_MAX`, …).

## Decision 2 — Job filter parameters (transient infixes → query string)

**Decision**: Represent filters as transient infix arguments; the jobs command reads
`(transient-args 'oqa-jobs-transient)` and builds the `/api/v1/jobs` query.

| Infix key | Arg | Query param | Notes |
|---|---|---|---|
| `-s` | `--state=` | `state=` | scheduled, assigned, setup, running, uploading, done, cancelled — multi |
| `-r` | `--result=` | `result=` | passed, failed, softfailed, incomplete, skipped, … — multi |
| `-a` | `--arch=` | `arch=` | x86_64, aarch64, ppc64le, s390x |
| `-f` | `--flavor=` | `flavor=` | |
| `-m` | `--machine=` | `machine=` | |
| `-t` | `--test=` | `test=` | **exact** job test name — verified live 2026-08-02: full name → hits, prefix `crea` → 0 hits (not a substring) |
| `-d` | `--distri=` | `distri=` | |
| `-v` | `--version=` | `version=` | |
| `-n` | `--limit=` | `limit=` | default 100 |

**Rationale**: This is exactly the `magit-log` args pattern; multi-value infixes (state, result)
map to repeated query params, which the API accepts (verified `state=running`, `result=failed`).
Filters therefore compose for free and are visible in the transient (FR-012).

**Alternatives considered**: `completing-read` prompts per filter — rejected: not composable, not
visible at a glance, violates Principle I ("filters as infix args when enumerable").

## Decision 3 — Authentication for mutations

**Decision**: Shell out to the user's installed `openqa-cli` and `openqa-clone-job` for all
state-changing actions; never implement request signing in Elisp.

- restart (same settings) → `openqa-cli api --host <HOST> -X POST jobs/<id>/restart`
- clone (custom settings) → `openqa-clone-job --host <HOST> <job-url-or-id> KEY=val …`
- trigger new (iso) → `openqa-cli api --host <HOST> -X POST isos DISTRI=… VERSION=… FLAVOR=… ARCH=… BUILD=…`

These read `~/.config/openqa/client.conf` (per-host `key`/`secret`) and sign requests themselves.
oqa passes `--host` from the active instance and shows the command's success/failure output.

**Rationale**: Principle IV + III. Zero secret handling in oqa; auth/retries/API-drift handled
upstream. Read paths stay pure `url.el` GETs with no credentials.

**Alternatives considered**: Native HMAC-SHA256 signing in Elisp against `/api/v1/*` — rejected for
v1: more code, more correctness/maintenance risk, duplicates a maintained tool for no user-visible
gain. Left open as a future option behind the same `oqa-actions.el` seam.

**Risk / mitigation**: The CLIs may be absent. oqa MUST detect this (`executable-find`) and, per
FR-020, block the action with a clear message rather than failing obscurely.

## Decision 4 — Emacs version floor

**Decision**: Set `Package-Requires` to `((emacs "27.1") (transient …) (dash …) (s …))`.

**Rationale**: The prototype already uses `json-parse-buffer` (C JSON parser, **Emacs 27.1**) and
`transient` (needs **26.1**). The declared `24.1` is therefore already false — code would not load
on 24.x. 27.1 is the true minimum and a clean, common baseline. Principle V requires floor changes
to be deliberate and documented; this is that record. CI matrix in `.github/workflows/test.yml`
should drop pre-27.1 Emacs versions accordingly.

**Alternatives considered**: Fall back to `json.el` (`json-read`) to keep 24.x — rejected: transient
already forces ≥26.1, so 24.x support is unattainable regardless; no reason to carry the slower
Lisp JSON path.

## Decision 5 — Navigation stack & shared list mode

**Decision**: One base mode `oqa-list-mode` (derived from `tabulated-list-mode`) that every view
derives from. Each buffer stores its context buffer-locally: the active instance, the "parent"
(where `^`/`q` returns), and the identifying ids (group id, build, job id) plus current filter
args. `RET` reads the entry at point (`tabulated-list-get-id`) and opens the child view; `q`/`^`
buries/returns to the parent buffer.

**Rationale**: Mirrors Magit's section→buffer drill model with minimal state; keeps each view a
plain tabulated list. Buffer-local context avoids a global stack that could desync across frames.

**Alternatives considered**: A single reused buffer that re-renders per level — rejected: loses the
back-stack and the ability to keep a parent list visible; harder to test level-by-level.

## Decision 6 — Logs

**Decision**:
- **Job log** — retrievable: `GET /tests/<id>/file/autoinst-log.txt` (plain text) rendered in a
  read-only buffer. (`worker-log.txt`, `serial0.txt` are siblings, offered later.)
- **Worker log** — the o3 REST API exposes **no uniform worker-log endpoint**; worker logs live on
  the worker host (journald/`/var/log`). So worker "log" degrades to showing the worker's live
  `status`/`error`/`properties` and, where present, the currently running job's log. FR-029 ("report
  clearly when a log is unavailable") is the contract that covers this.

**Rationale**: Deliver job logs (the high-value case) properly; be honest about worker logs rather
than pretend an endpoint exists. This keeps Story 6 shippable without over-promising.

**Alternatives considered**: SSH to the worker host for its journal — rejected for v1 (out of scope,
security surface, needs host access).

## Decision 7 — Testing without live network

**Decision**: All HTTP goes through one function in `oqa-api.el` (e.g. `oqa--api-get`). ERT tests
bind/stub that function to return recorded JSON from `test/fixtures/` (saved from the live probes),
so parsing, column extraction, and filter-arg→query-string logic are tested deterministically with
no network in CI.

**Rationale**: Principle V (tested) without flaky network dependence; fixtures double as API-shape
documentation.

**Alternatives considered**: Hitting o3 in CI — rejected: flaky, slow, rate-limited, and couples
tests to live data.
