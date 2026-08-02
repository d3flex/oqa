# Feature Specification: OpenQA Hierarchical Navigation and Job Actions

**Feature Branch**: `001-openqa-navigation`

**Created**: 2026-08-02

**Status**: Draft

**Input**: User description: "Model OpenQA as a drill-down hierarchy — a navigation stack of list views (groups → builds → jobs → job), each with a context-sensitive command menu that acts on the entry at point. Retire the single fixed-group 'status' view. Add filtering of jobs by state (running, done, etc.) and result (passed, failed, softfailed, etc.), per-job actions (restart, clone with custom settings, trigger a new build), a workers view showing workers and their settings, log viewing for jobs and workers, and switching between OpenQA instances — defaulting to o3 (openqa.opensuse.org) while allowing other servers such as osd (openqa.suse.de) to be configured and selected."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse the full hierarchy and reach a job's results (Priority: P1)

An OpenQA user opens the tool and sees **all** job groups on the active instance — not a single hard-coded distribution. They drill from a group into its builds, from a build into its jobs, and from a job into that job's settings and per-module results. At each level they can step back up to where they came from.

**Why this priority**: This is the core value and the reason the feature exists — it replaces the current prototype that only ever shows one group (Tumbleweed). Without it there is no product. It is the minimum viable slice: browsing alone is useful.

**Independent Test**: Launch the tool against a public instance, confirm the entry view lists many groups, drill down four levels to an individual job's results, and step back up to the top — all without configuring credentials.

**Acceptance Scenarios**:

1. **Given** the tool is launched against an instance, **When** the entry view loads, **Then** every job group the instance exposes is listed with its name and parent group.
2. **Given** the groups view, **When** the user opens a group, **Then** that group's builds are shown with version and pass/fail/total/unfinished counts.
3. **Given** a build's view, **When** the user opens a build, **Then** the jobs in that build are shown with id, test name, flavor, architecture, machine, state, and result.
4. **Given** a jobs view, **When** the user opens a job, **Then** the job's settings (key/value) and its module/step results are shown.
5. **Given** any view below the top, **When** the user requests "back", **Then** the previous view is restored.

---

### User Story 2 - Filter a build's jobs by state and result (Priority: P2)

Facing a large build with hundreds of jobs, the user narrows the list to what matters — for example only the jobs that are still **running**, or only **failed** and **softfailed** x86_64 jobs — by toggling filter criteria before the list loads, and adjusts those criteria without leaving the view.

**Why this priority**: Real builds have hundreds of jobs; browsing without filtering is impractical for daily triage. Filtering by execution state (what is still running) and by result (what failed) are the two triage questions asked most often. It builds directly on Story 1's jobs view but is independently valuable and testable.

**Independent Test**: From a build with many jobs, filter by state "running" and confirm only in-progress jobs appear; separately apply a result filter of "failed" plus an architecture filter, reload, confirm only matching jobs appear, then clear a filter and confirm the list widens.

**Acceptance Scenarios**:

1. **Given** a jobs view, **When** the user sets a state filter to "running", **Then** only jobs currently executing are listed.
2. **Given** a jobs view, **When** the user sets a result filter to "failed" and "softfailed", **Then** only jobs with those results are listed.
3. **Given** active filters, **When** the user adds an architecture criterion, **Then** the list further narrows to that architecture.
4. **Given** active filters, **When** the user inspects the command menu, **Then** the currently applied filters (state, result, and others) are visible.
5. **Given** a filter that matches nothing, **When** the list reloads, **Then** the user is shown an empty result with a clear indication that filters matched no jobs.

---

### User Story 3 - Act on a job: restart, clone with custom settings, trigger new build (Priority: P3)

From a job at point, the user re-runs it with identical settings, or clones it after editing selected settings, or triggers an entirely new build/product run by supplying product parameters. Each of these changes server state and is confirmed before it happens; the outcome is reported back.

**Why this priority**: These are the "act on it" capabilities that turn a viewer into a tool. They depend on Stories 1–2 to select a job and require configured credentials, so they come after browsing/filtering, but each is independently demonstrable.

**Independent Test**: With credentials configured, select a finished job, choose "restart with same settings", confirm, and verify a new run is created and reported; separately, choose "clone with custom settings", change one value, submit, and verify the new run reflects the change.

**Acceptance Scenarios**:

1. **Given** a job at point, **When** the user chooses "restart with same settings" and confirms, **Then** a new run is created from the job's existing settings and the result is reported.
2. **Given** a job at point, **When** the user chooses "clone with custom settings", **Then** the job's settings are presented for editing, and on submit a new run is created reflecting the edits.
3. **Given** the tool, **When** the user chooses "trigger new build" and supplies distribution, version, flavor, architecture, and build, **Then** a new product run is scheduled and the result is reported.
4. **Given** any state-changing action, **When** the user initiates it, **Then** they must explicitly confirm before it is submitted.
5. **Given** a state-changing action attempted without configured credentials, **When** it is initiated, **Then** the user is told credentials are required and no change is made.

---

### User Story 4 - Switch between OpenQA instances (Priority: P4)

The user works primarily against o3 (openqa.opensuse.org), which is the default active instance, but also configures additional servers such as osd (openqa.suse.de) and switches the active instance within a session; all subsequent views and actions target the newly selected instance.

**Why this priority**: o3 as a working default already delivers Stories 1–3 for the common case. Configuring and switching to additional servers is valuable for users spanning multiple deployments but is an additive convenience, so it is lower priority than the core browse/filter/act flow.

**Independent Test**: Start with o3 as the default and browse its groups; add and switch to a second instance (e.g., osd), and confirm the groups view now reflects the second instance.

**Acceptance Scenarios**:

1. **Given** no prior configuration, **When** the tool is first used, **Then** o3 is the active instance without the user configuring anything.
2. **Given** a configured additional instance, **When** the user switches the active instance, **Then** the entry view reloads against the newly selected instance.
3. **Given** an active instance, **When** the user performs any navigation or action, **Then** it targets that instance.

---

### User Story 5 - Inspect workers and their settings (Priority: P5)

The user opens a view of the workers registered on the active instance, sees each worker's status, and drills into a worker to view its settings/properties.

**Why this priority**: Worker visibility helps diagnose why jobs are queued, stuck, or failing to run, but it is a secondary diagnostic surface — the core job-centric flow (Stories 1–3) delivers value without it. Explicitly wanted, but "nice to have" relative to the drill-down spine.

**Independent Test**: Open the workers view against an instance, confirm registered workers are listed with their status, and open one worker to view its settings.

**Acceptance Scenarios**:

1. **Given** any view, **When** the user opens the workers view, **Then** the active instance's workers are listed with at least an identifier and status.
2. **Given** the workers view, **When** the user opens a worker, **Then** that worker's settings/properties are shown.

---

### User Story 6 - View logs for a job or a worker (Priority: P6)

From a job at point (or a worker at point), the user opens that entity's log output to inspect what happened, without leaving the tool.

**Why this priority**: Logs are the deepest triage step and depend on Stories 1 and 5 to select a job or worker first. Very useful for diagnosis, but the layers above must exist first, so it is last.

**Independent Test**: Select a finished job and open its log; select a worker and open its log; confirm each renders readable log content in the tool.

**Acceptance Scenarios**:

1. **Given** a job at point, **When** the user requests its log, **Then** the job's log output is displayed within the tool.
2. **Given** a worker at point, **When** the user requests its log, **Then** the worker's log output is displayed within the tool.
3. **Given** an entity whose log is unavailable (e.g., a job not yet started), **When** the user requests the log, **Then** the tool reports that no log is available rather than erroring.

---

### Edge Cases

- A group has no builds, or a build has no jobs — the view loads and clearly indicates it is empty rather than appearing broken.
- Filters match no jobs — an explicit empty state, distinguishable from a load failure.
- The active instance is unreachable or times out — the user is informed and the previous view is preserved.
- A job is still scheduled/running and has no module results yet — the job view renders available data without error.
- The user requests "back" at the top (groups) view — behaves sanely (no-op or exit) rather than erroring.
- A state-changing action is attempted without configured credentials — blocked with a clear message, no partial change.
- The active instance returns unexpected or changed data — the tool fails gracefully with a readable message instead of a raw error.
- The workers view is empty, or a worker is offline/stale — shown clearly rather than as an error.
- A log is requested for an entity that has no log yet (job not started) or whose log is too large to retrieve — the tool reports the situation instead of hanging or erroring.

## Requirements *(mandatory)*

### Functional Requirements

**Navigation**

- **FR-001**: The tool MUST present all job groups of the active instance as the entry view, showing at least group name and parent group.
- **FR-002**: Users MUST be able to drill from a job group into its builds, each showing version and pass/fail/total/unfinished counts.
- **FR-003**: Users MUST be able to drill from a build into its jobs, each showing id, test name, flavor, architecture, machine, state, and result.
- **FR-003a**: In the jobs view, the State and Result columns SHOULD be colour-coded (e.g. passed = green, running = blue, failed = red, softfailed = orange, inert states dimmed) using user-customisable faces; unrecognised values render without colour. Colour is presentation only and never changes the displayed text.
- **FR-004**: Users MUST be able to open a single job and view its settings (key/value) and its module/step results.
- **FR-005**: Users MUST be able to navigate back up the hierarchy to the previously viewed level.
- **FR-006**: The tool MUST provide a command menu, reachable from any view, that presents the navigation targets and actions available in the current context.
- **FR-007**: Browsing views MUST be read-only, so navigation cannot accidentally alter displayed data.
- **FR-008**: The tool MUST retire the current single fixed-group entry view; the group list, not any one group, is the entry point.

**Filtering**

- **FR-009**: Users MUST be able to filter the jobs view by execution state (e.g., running, done, scheduled), result (e.g., passed, failed, softfailed), architecture, flavor, machine, test name, distribution, and version.
- **FR-009a**: Filtering by state MUST allow isolating jobs that are still running (in progress) from those that are finished.
- **FR-010**: The state and result filters MUST each accept multiple values simultaneously (e.g., failed and softfailed together).
- **FR-011**: Users MUST be able to limit the number of jobs returned.
- **FR-012**: Applied filters MUST be visible and adjustable before the jobs view (re)loads.
- **FR-013**: When filters match no jobs, the tool MUST show an explicit empty result distinct from an error state.

**Actions on a job**

- **FR-014**: Users MUST be able to restart/re-run a selected job using its exact existing settings.
- **FR-015**: Users MUST be able to clone a selected job with customized settings, editing settings before submission.
- **FR-016**: Users MUST be able to trigger a new build/product run by supplying distribution, version, flavor, architecture, and build.
- **FR-017**: Every state-changing action MUST require explicit user confirmation before submission.
- **FR-018**: Browse/read operations MUST work without credentials; state-changing actions MUST use the user's existing configured OpenQA credentials and MUST NOT embed secrets.
- **FR-019**: The tool MUST report the outcome (success or failure) of each state-changing action.
- **FR-020**: When credentials are absent, state-changing actions MUST be blocked with a clear message and MUST make no change.

**Instances**

- **FR-021**: The tool MUST support multiple configured OpenQA instances and MUST let the user switch the active instance within a session.
- **FR-022**: No instance host, job group, product, or distribution may be hard-coded; all MUST derive from configuration or user selection.
- **FR-023**: All views and actions MUST operate against the currently active instance.
- **FR-023a**: The tool MUST default to o3 (openqa.opensuse.org) as the active instance out of the box, while allowing users to add other servers (e.g., osd, openqa.suse.de) and switch to them.

**Workers**

- **FR-024**: Users MUST be able to open a workers view listing the active instance's workers with at least an identifier and status.
- **FR-025**: Users MUST be able to open a single worker to view its settings/properties.
- **FR-026**: The workers view MUST be reachable from the command menu from any view.

**Logs**

- **FR-027**: Users MUST be able to view the log output of a selected job within the tool.
- **FR-028**: Users MUST be able to view the log output of a selected worker within the tool.
- **FR-029**: When a requested log is unavailable, the tool MUST report that clearly instead of erroring.

### Key Entities *(include if feature involves data)*

- **Instance**: A configured OpenQA deployment the user can target — a label, its location, and a reference to the user's credentials for that deployment. One instance is "active" at a time.
- **Job Group**: A named grouping of test builds, optionally under a parent group; the top level of navigation.
- **Build**: A versioned run of a group aggregating many jobs, with summary counts (total/passed/failed/unfinished).
- **Job**: A single test run — identity, test name, flavor, architecture, machine, state, result, a set of key/value settings, a list of module/step results, and log output.
- **Filter**: A set of criteria (state, result, architecture, flavor, machine, test, distribution, version, limit) applied when listing a build's jobs; state and result each accept multiple values.
- **Worker**: A registered execution host on the active instance — an identifier, a status, settings/properties, and log output.
- **Log**: The retrievable text output of a job or a worker, viewed within the tool.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can go from launching the tool to viewing a specific job's module results in four drill-down steps or fewer.
- **SC-002**: The entry view lists every job group the active instance exposes, for any configured instance — never a single fixed group or distribution.
- **SC-003**: A user can reduce a large build's job list to a targeted set — by state (e.g., only running jobs) or by result and architecture (e.g., only failed x86_64 jobs) — entirely within the tool, and widen it again by clearing a criterion.
- **SC-004**: A user can restart a failed job and receive confirmation of the new run without manually copying any job id or settings.
- **SC-005**: With o3 as the default, a user can add a second server (e.g., osd) and switch to it within one session, without restarting the tool, and see the second instance's data.
- **SC-006**: 100% of state-changing actions prompt for explicit confirmation before executing, and 0% execute when credentials are absent.
- **SC-007**: A user can list the active instance's workers and open one to see its settings, without leaving the tool.
- **SC-008**: A user can open the log of a selected job and of a selected worker within the tool, and receives a clear message when a log is unavailable.

## Assumptions

- The user interacts with the tool inside their editor via keyboard-driven list views and a command menu; the tool runs in both terminal and graphical sessions.
- o3 (openqa.opensuse.org) is the primary target and the default active instance; osd (openqa.suse.de) and other servers are user-configured additions.
- The active instance's read interface is reachable, and public instances can be browsed without credentials.
- State-changing actions rely on the user having valid OpenQA credentials already configured on their machine; configuring those credentials is out of scope for this feature.
- Authenticated operations reuse existing, maintained OpenQA tooling rather than re-implementing request signing (per the project constitution); this is an implementation choice, not a user-visible requirement.
- Statistics and other aggregate dashboards remain out of scope for this feature and are deferred to future work. (Workers and log viewing are in scope, as Stories 5 and 6.)
- Initial data retrieval may be synchronous; responsiveness/async improvements are out of scope here.
- The six priority stories are intended for incremental delivery — Story 1 alone is a viable release; Stories 2–6 layer on independently.
