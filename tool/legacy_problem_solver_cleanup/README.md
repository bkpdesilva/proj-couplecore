# Legacy Problem Solver cleanup

One-time cleanup for `problemSessions` docs left behind by the *old* solve
flow, which flipped `status: 'solved'` in place instead of deleting the raw
chat (e.g. `couples/{coupleId}/problemSessions/VsgoIMNPlHgJvV1oYhTS`). The
current flow (extract -> confirm -> save -> delete) never leaves these
behind, so this only needs to run once against existing data.

These scripts must be run from your own machine/terminal — the coding
sandbox that wrote them is blocked from reaching live GCP/Firestore
directly, by design. Nothing here touches
`android/app/google-services.json` or any client API key; auth is via
Application Default Credentials or a service account, both admin-side.

## Setup

```
cd tool/legacy_problem_solver_cleanup
npm install
```

Auth — either works:
- `gcloud auth application-default login` (uses your own Google identity), or
- set `GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json` (a key
  with Firestore read/write on `couplecore-bae2e`).

## Step 1 — report (read-only)

```
node report.mjs --couple qs475cx3y2mc8bNdExLH
```

Prints every `problemSessions` doc for that couple: id, status, starred,
and — for solved ones — whether a matching `solvedProblems` record already
exists. Matching is by `sourceTitle === session.title`, the only
correlation key that exists (there's no `sourceId` link). Classifications:

- `ALREADY_SAVED` — exactly one matching solvedProblems doc -> safe to delete
- `NEEDS_MIGRATION` — no match, but the session has `problemSummary` and/or
  `solution` -> a record will be created from those before deleting
- `AMBIGUOUS` — more than one solvedProblems doc shares that title -> left
  alone, needs a human to pick the right one
- `NO_DATA_TO_MIGRATE` — no match and nothing to migrate (no
  problemSummary/solution) -> left alone rather than deleting a chat with
  no preserved record

Also writes `report.json` alongside this file. Nothing is written to
Firestore by this step.

**Review the output with Praveen before running Step 2.**

## Step 2 — migrate + delete

Dry run first (always):

```
node migrate.mjs --couple qs475cx3y2mc8bNdExLH
```

Prints exactly what it would do, writes nothing. Once that looks right:

```
node migrate.mjs --couple qs475cx3y2mc8bNdExLH --execute
```

Behavior:
- `ALREADY_SAVED` sessions: messages + session doc deleted in batched writes.
- `NEEDS_MIGRATION` sessions: the solvedProblems record is created first,
  then re-read to confirm the write landed, and only then are the messages
  + session doc deleted. If the verify read fails, the session is left
  completely untouched and reported under "skipped".
- `AMBIGUOUS` / `NO_DATA_TO_MIGRATE` / active / starred sessions: never
  touched.

To re-run against a single session (e.g. after resolving an AMBIGUOUS case
by hand): add `--only <sessionId>`.
