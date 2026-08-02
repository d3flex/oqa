# Phase 1 Data Model: OpenQA Hierarchical Navigation and Job Actions

oqa holds no persistent store; these are the in-memory shapes read from the API (and the config
entities). Field names in `code font` are the actual JSON keys observed live on o3 (2026-08-02).

## Instance (config + runtime)

The one entity oqa owns rather than reads. A `defcustom` alist plus a buffer-local "active" pick.

| Field | Meaning |
|---|---|
| label | Short name shown in the instance switcher (e.g. `o3`, `osd`). |
| host | Base URL, e.g. `https://openqa.opensuse.org`. |
| (active) | Which instance is current — buffer-local, not stored in the alist. |

- **Default**: ships with `o3 → https://openqa.opensuse.org` and `osd → https://openqa.suse.de`;
  active defaults to `o3` (FR-023a). Users add/override via `oqa-instances`.
- **Credentials**: NOT stored here. They live in the user's `~/.config/openqa/client.conf`, keyed
  by host, and are used only by the shelled-out CLIs. oqa passes `host` as `--host`.
- **Rules**: every URL builder and every mutation command reads the active instance's `host`
  (FR-022/023). No default hard-codes a group/product/distri — only the host.

## Job Group  — `GET /api/v1/job_groups`

| Field (JSON) | Use |
|---|---|
| `id` | Row id; parameterizes the builds view (`group_overview/<id>.json`). |
| `name` | "Group" column. |
| `parent_id` | "Parent" column (resolve to parent name; `null` → top-level, render ""). |

Relationships: a Group has many Builds. `parent_id` optionally nests groups under a parent group.
Validation: `id` and `name` always present; treat missing `parent_id` as top-level.

## Build  — `GET /group_overview/<group_id>.json` → `build_results[]`

| Field (JSON) | Column |
|---|---|
| `build` | Build |
| `version` | Version |
| `total` | Total |
| `passed` | Pass |
| `failed` | Fail |
| `softfailed` | (Soft) — added beyond the prototype's columns |
| `unfinished` | Unfin. |
| `key` / `escaped_id` | opaque id for drilling into jobs (carries group_id + build) |

Relationships: a Build belongs to a Group and has many Jobs. Drilling a build → jobs view filtered
by that `group_id` + `build`. Validation: counts are integers ≥ 0; an empty `build_results` array
is a valid "no builds" state (edge case).

## Job  — `GET /api/v1/jobs?…` (list) / `GET /api/v1/jobs/<id>` (one)

| Field (JSON) | Column / use |
|---|---|
| `id` | Id |
| `test` | Test |
| `settings.FLAVOR` | Flavor |
| `settings.ARCH` | Arch |
| `settings.MACHINE` | Machine |
| `state` | State (scheduled…running…done, cancelled) |
| `result` | Result (passed, failed, softfailed, incomplete, skipped, …) |
| `settings` (full map) | Job view: key=value listing; source for clone/restart |
| `modules` | Job view: per-module/step results |
| `clone_id` | If restarted/cloned, points at the successor run |
| `assigned_worker_id` | Link to the worker that ran it |

Relationships: a Job belongs to a Build (via `group_id` + `BUILD`), may reference a Worker, and may
have parents/children (chained/parallel jobs — out of scope for v1 columns). State transitions
(informational, server-owned): `scheduled → assigned → setup → running → uploading → done`
(or `→ cancelled`); `result` is meaningful once `state = done`.

Validation: `flavor`/`arch`/`machine` may be absent in `settings` → render "". A `state != done`
job may have empty `modules`/`result` (edge case: still-running job renders without error).

## Worker  — `GET /api/v1/workers`

| Field (JSON) | Column / use |
|---|---|
| `host` + `instance` | Identifier column (`host:instance`) |
| `status` | Status (running, idle, dead, broken) |
| `alive` / `connected` | Liveness detail in the worker view |
| `error` | Shown when the worker is broken/offline |
| `properties` (map) | Worker settings view: `WORKER_CLASS`, `CPU_ARCH`, `MEM_MAX`, … |

Relationships: a Worker may currently run one Job. Validation: an empty workers list or a
`dead`/stale worker is a valid state shown clearly, not an error (edge case).

## Filter (runtime, buffer-local)

Not a server entity — the current set of transient infix args on the jobs view.

| Criterion | Values | Multi |
|---|---|---|
| state | scheduled/assigned/setup/running/uploading/done/cancelled | yes |
| result | passed/failed/softfailed/incomplete/skipped/… | yes |
| arch, flavor, machine, test, distri, version | free/enumerated | no |
| limit | integer (default 100) | no |

Rules: applied when building the `/api/v1/jobs` query; state and result contribute repeated params;
empty result set is a distinct "no matches" state (FR-013). Visible in the transient (FR-012).

## Log (runtime)

| Field | Meaning |
|---|---|
| source | job (`/tests/<id>/file/autoinst-log.txt`) or worker (status/error + running-job log) |
| content | Plain text rendered read-only |
| available? | If absent (job not started, no worker endpoint) → clear "unavailable" message (FR-029) |

## Entity relationship summary

```text
Instance (active) ──► Job Groups ──► Builds ──► Jobs ──► (settings, modules, Log)
                 └──► Workers ──► (properties, Log)
Filter shapes the Jobs query.  Job.assigned_worker_id ─┄► Worker.
```
