# Contract: oqa command / keymap / transient surface

The user-facing contract — the interactive commands, keybindings, and transient menus oqa exposes.
This is the "UI contract" for a keyboard-driven Emacs application.

## Entry points (interactive commands)

| Command | Purpose |
|---|---|
| `oqa` | `;;;###autoload` entry — open the **groups** view for the active instance (replaces the broken prototype `oqa`). |
| `oqa-dispatch` | Open the context-sensitive transient (also bound to `o`/`?` in every view). |

Retired: `oqa-status` (folded into the builds view), and the dangling `oqa--save-line` /
`oqa--pop-to-buffer` / `oqa--buffer-name` references.

## Shared keymap (`oqa-list-mode`, all list views)

| Key | Action |
|---|---|
| `RET` | Drill into the entry at point (open its child view). |
| `q` | Bury this view / return to parent. |
| `^` | Go up one level (to parent view). |
| `g` | Refresh the current view. |
| `o` / `?` | Open `oqa-dispatch` transient. |
| `O` / `D` | Switch active instance to o3 / osd (also in transient). |

## `oqa-dispatch` transient (context-sensitive groups)

```
─ Navigate ──────────      ─ Filter (jobs view; infix args) ──
 g  groups                  -s --state=    (running,done,…)  [multi]
 b  builds (this group)     -r --result=   (failed,softfail…) [multi]
 j  jobs                    -a --arch=     -f --flavor=
 w  workers                 -m --machine=  -t --test=
                            -d --distri=   -v --version=
─ On job at point ───       -n --limit=    (default 100)
 RET show job
 s  settings               ─ Instance ────────────────────────
 l  log                     O  o3  (openqa.opensuse.org)
 r  restart (same)          D  osd (openqa.suse.de)
 c  clone (custom)          i  choose instance…
 T  trigger new (iso)
─ On worker at point ─      ─ Later (out of scope) ────────────
 RET show worker            x  statistics
 l  worker log
```

### Contract details per suffix

- **Navigate (`g`/`b`/`j`/`w`)**: open the corresponding view against the active instance.
  `b` requires a current group context; `j` requires group+build context (else prompt/deny).
- **Filter infixes**: accumulate as transient args; `j`/refresh reads
  `(transient-args 'oqa-jobs-transient)` and builds the query (see openqa-endpoints.md). State and
  result are multi-value. Applied filters are visible in the transient (FR-012).
- **Job actions (`r`/`c`/`T`)**: MUST prompt `y-or-n`/confirm before submitting (FR-017); MUST
  `executable-find` the CLI and verify creds path, else block with a message and make no change
  (FR-020); MUST report the CLI outcome (FR-019).
  - `r` → restart same settings.
  - `c` → pop `KEY=value` edit buffer prefilled from the job's `settings`; `C-c C-c` submits via
    `openqa-clone-job`; `C-c C-k` cancels.
  - `T` → read DISTRI/VERSION/FLAVOR/ARCH/BUILD (prefill from job at point when present), confirm,
    POST `isos`.
- **Logs (`l`)**: open the entity's log in a read-only buffer; "unavailable" message on 404/none.
- **Instance (`O`/`D`/`i`)**: set the active instance and reload the entry (groups) view (FR-021).

## Behavioral guarantees (map to spec)

- All list views are **read-only** (`tabulated-list-mode`) — navigation cannot mutate (FR-007).
- Reads issue no credentials (FR-018). Only `r`/`c`/`T` touch the credentialed CLIs.
- No command hard-codes a host/group/product; all derive from active instance + entry at point
  (FR-022).
