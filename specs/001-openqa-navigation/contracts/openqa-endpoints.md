# Contract: OpenQA REST endpoints oqa consumes

This is the upstream contract oqa depends on. `<HOST>` is the active instance's base URL
(default `https://openqa.opensuse.org`). Read endpoints require no credentials; write endpoints go
through `openqa-cli`/`openqa-clone-job` (which sign via `~/.config/openqa/client.conf`).

Verified live against o3 on 2026-08-02 unless marked (write — not exercised).

## Reads (GET, no auth)

### List job groups
```
GET <HOST>/api/v1/job_groups
→ 200  [ { "id": Int, "name": Str, "parent_id": Int|null, … }, … ]      (array; ~110 on o3)
```
oqa uses: `id`, `name`, `parent_id`.

### Build overview for a group
```
GET <HOST>/group_overview/<group_id>.json
→ 200  { "build_results": [ { "build":Str, "version":Str, "total":Int,
                              "passed":Int, "failed":Int, "softfailed":Int,
                              "unfinished":Int, "key":Str, … }, … ],
         "group": {…}, "children": […], … }
```
oqa uses: `build_results[].{build,version,total,passed,failed,softfailed,unfinished,key}`.
Empty `build_results` = valid "no builds" state.

### List jobs (filterable)
```
GET <HOST>/api/v1/jobs?group_id=<id>&build=<b>[&state=…][&result=…][&arch=…]
                       [&flavor=…][&machine=…][&test=…][&distri=…][&version=…][&limit=N]
→ 200  { "jobs": [ { "id":Int, "test":Str, "state":Str, "result":Str,
                     "settings": { "FLAVOR":Str, "ARCH":Str, "MACHINE":Str, "BUILD":Str,
                                   "DISTRI":Str, "VERSION":Str, … },
                     "clone_id":Int|null, "assigned_worker_id":Int|null, … }, … ] }
```
- `state` and `result` accept **multiple** values (repeat the param). Verified `state=running`,
  `result=failed`, `arch=x86_64`.
- `test` matches the **exact** job test name (verified: substring `crea` returns 0). Use the full
  test name, not a fragment.
- `limit` bounds the result; oqa always sends one (default 100).
- Empty `jobs` = valid "no matches" state.

### One job (+ modules)
```
GET <HOST>/api/v1/jobs/<id>            → 200 { "job": { …, "settings":{…}, "modules":[…] } }
GET <HOST>/api/v1/jobs/<id>/details    → 200 { "job": { …, "modules":[ {name,result,…} ] } }
```
oqa uses: `settings` (key=value view), `modules` (step results).

### List workers
```
GET <HOST>/api/v1/workers
→ 200  { "workers": [ { "id":Int, "host":Str, "instance":Int, "status":Str,
                        "alive":0|1, "connected":0|1, "error":Str?,
                        "properties": { "WORKER_CLASS":Str, "CPU_ARCH":Str, "MEM_MAX":Str, … }
                      }, … ] }
```
oqa uses: `host`+`instance` (identity), `status`, `error`, `properties`.

### Job log (plain text)
```
GET <HOST>/tests/<id>/file/autoinst-log.txt   → 200 text/plain  (may 404 if job not started)
```
404/absent → oqa reports "log unavailable" (FR-029). No uniform worker-log endpoint exists.

## Writes (via CLI, auth from client.conf) — not exercised in this plan

### Restart a job with identical settings
```
openqa-cli api --host <HOST> -X POST jobs/<id>/restart
```

### Clone a job with customized settings
```
openqa-clone-job --host <HOST> <HOST>/tests/<id>  KEY=value  [KEY2=value2 …]
```
oqa prefills the edit buffer from the job's `settings`; each edited line becomes a `KEY=value` arg.

### Trigger a new build/product (ISO)
```
openqa-cli api --host <HOST> -X POST isos  DISTRI=…  VERSION=…  FLAVOR=…  ARCH=…  BUILD=…
```

**Preconditions for all writes**: `executable-find` locates the CLI, and the user has confirmed
(FR-017). Missing CLI or missing creds → block with a clear message, no request sent (FR-020).
oqa surfaces the CLI's exit status + output as the outcome (FR-019).
