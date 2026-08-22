// STEP 2 — run only after reviewing report.mjs's output with the user.
//
// Defaults to a DRY RUN (prints planned actions, writes nothing). Pass
// --execute to actually perform them.
//
// For each problemSessions doc under the given couple:
//   ALREADY_SAVED (status=solved, not starred, exactly one matching
//     solvedProblems doc by sourceTitle): cascade-delete messages + session.
//   NEEDS_MIGRATION (status=solved, not starred, no matching solvedProblems
//     doc, has problemSummary and/or solution): create the solvedProblems
//     record, GET it back to confirm the write landed, only THEN
//     cascade-delete messages + session.
//   Anything else (active, starred, AMBIGUOUS, NO_DATA_TO_MIGRATE): skipped,
//     untouched, and listed in the summary for manual review.
//
// Usage:
//   node migrate.mjs --couple qs475cx3y2mc8bNdExLH            (dry run)
//   node migrate.mjs --couple qs475cx3y2mc8bNdExLH --execute  (writes)
//   node migrate.mjs --couple qs475cx3y2mc8bNdExLH --only <sessionId> --execute
import { FieldValue } from 'firebase-admin/firestore';
import { initDb, loadCoupleData, classifySession, parseArgs } from './lib.mjs';

const BATCH_LIMIT = 400; // stay under Firestore's 500-write batch cap

async function cascadeDeleteSession(db, coupleRef, session, execute) {
  const messagesSnap = await session.ref.collection('messages').get();
  const deletes = [...messagesSnap.docs.map((d) => d.ref), session.ref];

  if (!execute) {
    console.log(`      [dry-run] would delete ${messagesSnap.docs.length} message(s) + session doc`);
    return;
  }

  for (let i = 0; i < deletes.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const ref of deletes.slice(i, i + BATCH_LIMIT)) batch.delete(ref);
    await batch.commit();
  }
  console.log(`      deleted ${messagesSnap.docs.length} message(s) + session doc`);
}

async function main() {
  const { couple, execute, only } = parseArgs(process.argv.slice(2));
  if (!couple) {
    console.error('Usage: node migrate.mjs --couple <coupleId> [--execute] [--only <sessionId>]');
    process.exit(1);
  }
  console.log(execute ? '*** EXECUTE MODE — this will write/delete in Firestore ***' : 'Dry run (no writes) — pass --execute to apply');

  const db = initDb();
  const { coupleRef, sessions, solved } = await loadCoupleData(db, couple);

  const targets = only ? sessions.filter((s) => s.id === only) : sessions;

  const results = { migrated: [], deleted: [], skipped: [] };

  for (const session of targets) {
    const classification = classifySession(session, solved);
    const label = `${session.id} "${session.title ?? ''}"`;

    if (classification.verdict === 'ALREADY_SAVED') {
      console.log(`\n[DELETE] ${label} -> already in solvedProblems/${classification.match.id}`);
      await cascadeDeleteSession(db, coupleRef, session, execute);
      results.deleted.push(session.id);
      continue;
    }

    if (classification.verdict === 'NEEDS_MIGRATION') {
      console.log(`\n[MIGRATE] ${label} -> no existing solvedProblems record`);
      const record = {
        sourceTitle: session.title ?? '',
        problem: session.problemSummary ?? '',
        solution: session.solution ?? '',
        impact: '',
        createdAt: FieldValue.serverTimestamp(),
        // Audit trail only — SolvedProblem.fromMap ignores unknown fields.
        migratedFromSessionId: session.id,
        migratedAt: FieldValue.serverTimestamp(),
      };

      if (!execute) {
        console.log('      [dry-run] would create solvedProblems record:', JSON.stringify(record, null, 2));
        console.log('      [dry-run] would then delete messages + session');
        results.migrated.push(session.id);
        continue;
      }

      const newRef = await coupleRef.collection('solvedProblems').add(record);
      const verify = await newRef.get();
      if (!verify.exists) {
        console.error(`      FAILED to verify write for ${newRef.path} — leaving session untouched`);
        results.skipped.push({ id: session.id, reason: 'save-verify-failed' });
        continue;
      }
      console.log(`      created solvedProblems/${newRef.id}, verified`);
      await cascadeDeleteSession(db, coupleRef, session, execute);
      results.migrated.push(session.id);
      continue;
    }

    // NOT_SOLVED, STARRED_SKIP, AMBIGUOUS, NO_DATA_TO_MIGRATE
    results.skipped.push({ id: session.id, reason: classification.verdict });
  }

  console.log('\n--- Summary ---');
  console.log(`Deleted (already saved)      : ${results.deleted.length}`, results.deleted);
  console.log(`Migrated then deleted        : ${results.migrated.length}`, results.migrated);
  console.log(`Skipped (needs manual review or untouched by design):`);
  for (const s of results.skipped) console.log(`  ${s.id}: ${s.reason}`);

  if (!execute) console.log('\nThis was a DRY RUN. Re-run with --execute to apply.');
  process.exit(0);
}

main().catch((err) => {
  console.error('Migrate failed:', err);
  process.exit(1);
});
