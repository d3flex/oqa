# Implementation Plan: OpenQA Hierarchical Navigation and Job Actions

**Branch**: `001-openqa-navigation` | **Date**: 2026-08-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-openqa-navigation/spec.md`

## Summary

Turn the current single-group prototype into a Magit-style, drill-down OpenQA client inside
Emacs: a navigation stack of read-only `tabulated-list-mode` buffers (groups → builds → jobs →
job), each with a context-sensitive `transient` dispatch. Job filtering is expressed as transient
infix arguments that map to `/api/v1/jobs` query parameters (state, result, arch, flavor, machine,
test, distri, version, limit). Read paths hit the public OpenQA REST API with no credentials;
state-changing actions (restart, clone, trigger ISO) shell out to the user's installed
`openqa-cli` / `openqa-clone-job`, which already read `~/.config/openqa/client.conf`. Instances
(o3 default, osd and others configurable) are a `defcustom` alist plus a buffer-local "active
instance". Adds a workers view and job/worker log viewing.

All four confirmed live against o3: `/api/v1/job_groups` (110 groups), `/api/v1/jobs?…`
(`{jobs:[…]}`, honors `state`/`result`/`arch`), `/api/v1/workers` (716 workers with
`status`/`host`/`instance`/`properties`), and `/group_overview/<id>.json` (build_results with
total/passed/failed/softfailed/unfinished).

## Technical Context

**Language/Version**: Emacs Lisp, `lexical-binding: t`. **Target minimum Emacs 27.1** — a
deliberate, documented raise of `Package-Requires` from the current (fictional) `24.1`. Rationale:
the existing code already calls `json-parse-buffer` (C JSON, added in 27.1) and depends on modern
`transient` (needs 26.1+). See research.md → "Emacs version floor". This is the one Principle V
"deliberate floor change" and is not a violation.

**Primary Dependencies**: runtime — `transient`, `dash`, `s`, and Emacs built-ins (`url`,
`json` (`json-parse-buffer`), `tabulated-list`, `map`, `seq`, `subr-x`). External programs invoked
for authenticated mutations only — `openqa-cli`, `openqa-clone-job` (from the `openQA-client`
package). Dev — `undercover` (coverage), Keg (build/test/lint).

**Storage**: None persistent. Runtime state is in-memory/buffer-local (active instance, current
filter args, navigation context). User config via `defcustom` (`oqa-instances`, default active
instance). Credentials are never stored by oqa — they live in the user's existing `client.conf`
and are used only by the shelled-out CLIs.

**Testing**: ERT via `keg run test`; coverage via `undercover` (codecov). Network calls are
factored behind a single fetch function so tests stub it with recorded JSON fixtures (no live
network in CI).

**Target Platform**: Emacs 27.1+ on Linux/macOS, both terminal (`-nw`) and GUI frames.

**Project Type**: Single-file-origin Emacs package, split into a small set of feature files
(desktop-app-like, but "app" = a set of major modes + transient prefixes inside Emacs).

**Performance Goals**: Interactive. A view renders within ~2–3 s on o3 over a normal connection.
List endpoints are always bounded by an explicit `limit` (default 100, user-adjustable via the
`-n` infix) so a build with hundreds of jobs or 700+ workers never fetches unbounded.

**Constraints**: Read operations MUST work with zero credentials and MUST NOT mutate. Mutations
MUST confirm and MUST route through the user's configured credentials via the external CLIs. No
instance/group/product/distri hard-coded in any reachable path. Blocking synchronous retrieval is
acceptable for v1 (Assumptions), but the fetch layer is isolated so it can move to async later.

**Scale/Scope**: o3 exposes ~110 job groups; builds contain hundreds of jobs; ~700 workers. UI
must page/limit rather than render everything. Six prioritized, independently shippable stories
(P1 browse → P6 logs).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|---|---|---|
| I. Emacs-Native, Buffer-First | All views are read-only `tabulated-list-mode`; every action via `transient`; filters are infix args; `RET` drills, `q`/`^` pops. | ✅ By design (this is the plan's core). |
| II. Instance- & Scope-Agnostic | `oqa-instances` defcustom + buffer-local active instance; groups list is the entry point; no hard-coded host/group. | ✅ FR-021…023a. |
| III. Read/Write Separation & Safe Mutation | GET layer credential-free & non-mutating; restart/clone/trigger require confirm + existing creds; no embedded secrets. | ✅ FR-017/018/020. |
| IV. Reuse the OpenQA Ecosystem | Mutations shell out to `openqa-cli`/`openqa-clone-job`; no HMAC re-implementation. | ✅ research.md decision. |
| V. Multi-Version Correctness | ERT via `keg run test`; `keg lint` clean; **Package-Requires bumped to 27.1 deliberately and documented**. | ✅ Documented floor change, not incidental. |

**Post-Design re-check**: Still ✅ — the module split (below) keeps each file namespaced `oqa-`/
`oqa--`, licensed, and `provide`-d; no new runtime dependency beyond transient/dash/s; the external
CLIs are optional and only touched on mutation. No entries required in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-openqa-navigation/
├── plan.md              # This file
├── research.md          # Phase 0 — decisions (endpoints, auth, transient, version floor)
├── data-model.md        # Phase 1 — Instance/Group/Build/Job/Worker/Filter/Log
├── quickstart.md        # Phase 1 — per-story runnable validation
├── contracts/
│   ├── openqa-endpoints.md   # external REST endpoints oqa consumes (the upstream contract)
│   └── commands.md           # oqa's own command/keymap/transient surface (the user contract)
└── checklists/
    └── requirements.md  # from /speckit-specify
```

### Source Code (repository root)

The prototype is one file. This feature grows it into a small module set, each file `provide`-ing
a matching feature and required by the `oqa.el` entry point. This keeps `keg lint`/package-lint
happy (one feature per file) while separating API, config, views, and menus.

```text
oqa.el              # entry point: ;;;###autoload oqa, dispatch keymap, requires the modules
oqa-api.el          # fetch layer: URL builders, json-parse, the single stubbable request fn
oqa-instance.el     # oqa-instances defcustom, active-instance state, host resolution
oqa-list.el         # shared oqa-list-mode base (tabulated-list + nav stack: RET / q / ^)
oqa-groups.el       # groups view      (GET /api/v1/job_groups)
oqa-builds.el       # builds view      (GET /group_overview/<id>.json)  ← replaces oqa-status
oqa-jobs.el         # jobs view + filter infixes (GET /api/v1/jobs?…)
oqa-job.el          # single job: settings + modules; job log
oqa-workers.el      # workers view + worker settings; worker log
oqa-actions.el      # restart / clone / trigger-iso (shell out, confirm)
oqa-transient.el    # oqa-dispatch + context transients (navigate / filter / act / instance)

test/
├── oqa-test.el         # existing harness (undercover + ert)
├── oqa-api-test.el     # URL building, JSON parsing against fixtures
├── oqa-jobs-test.el    # filter args → query string; row extraction
├── oqa-instance-test.el# instance resolution, default = o3
└── fixtures/           # recorded JSON: job_groups, group_overview, jobs, workers, one job
```

**Structure Decision**: Multi-file split under the repo root (Emacs packages are flat, not
`src/`). `oqa.el` remains the loadable entry that `require`s the rest. The split is along the
constitution's own seams — API vs instance/config vs views vs actions vs menus — so read paths
(everything but `oqa-actions.el`) stay free of the credentialed CLI code. Retiring `oqa-status`:
its logic moves into `oqa-builds.el`, parameterized by group id, and `oqa-status` is dropped along
with the broken `oqa--save-line`/`oqa--pop-to-buffer`/`oqa--buffer-name` references and the
zero-arg/one-arg `(oqa-status 1)` bug.

## Complexity Tracking

> No constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none)    | —          | —                                    |
