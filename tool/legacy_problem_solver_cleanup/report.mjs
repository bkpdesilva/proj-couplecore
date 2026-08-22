// STEP 1 — read-only. Prints a report of every problemSessions doc for one
// couple, classifies solved sessions against solvedProblems, and writes the
// same data to report.json next to this file for reference. Makes no writes.
//
// Usage:
//   node report.mjs --couple qs475cx3y2mc8bNdExLH
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { initDb, loadCoupleData, classifySession, parseArgs } from './lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const { couple } = parseArgs(process.argv.slice(2));
  if (!couple) {
    console.error('Usage: node report.mjs --couple <coupleId>');
    process.exit(1);
  }

  const db = initDb();
  const { sessions, solved } = await loadCoupleData(db, couple);

  const rows = sessions.map((s) => ({
    id: s.id,
    title: s.title ?? '',
    status: s.status ?? 'active',
    starred: s.starred === true,
    ...classifySession(s, solved),
  }));

  const counts = {
    total: rows.length,
    solved: rows.filter((r) => r.status === 'solved').length,
    active: rows.filter((r) => r.status !== 'solved').length,
    starred: rows.filter((r) => r.starred).length,
  };

  const byVerdict = (v) => rows.filter((r) => r.verdict === v);

  console.log(`\nCouple ${couple}`);
  console.log(`  problemSessions: ${counts.total} total`);
  console.log(`    status=solved : ${counts.solved}`);
  console.log(`    status=active : ${counts.active}`);
  console.log(`    starred       : ${counts.starred}`);
  console.log(`  solvedProblems  : ${solved.length} records\n`);

  console.log('Solved sessions, classified:');
  for (const r of rows.filter((r) => r.status === 'solved')) {
    console.log(`  [${r.verdict}] ${r.id}  "${r.title}"${r.starred ? '  (starred)' : ''}`);
    if (r.verdict === 'ALREADY_SAVED') {
      console.log(`      -> matches solvedProblems/${r.match.id} (safe to delete)`);
    }
    if (r.verdict === 'AMBIGUOUS') {
      console.log(
        `      -> ${r.candidates.length} candidates in solvedProblems: ${r.candidates
          .map((c) => c.id)
          .join(', ')} (NEEDS MANUAL REVIEW, will be skipped)`,
      );
    }
    if (r.verdict === 'NEEDS_MIGRATION') {
      console.log('      -> no matching solvedProblems record; will be created from legacy fields, then session deleted');
    }
    if (r.verdict === 'NO_DATA_TO_MIGRATE') {
      console.log('      -> no problemSummary/solution on the session and no solvedProblems match; NOTHING TO MIGRATE, will be skipped (nothing deleted)');
    }
  }

  const summary = {
    ALREADY_SAVED: byVerdict('ALREADY_SAVED').length,
    NEEDS_MIGRATION: byVerdict('NEEDS_MIGRATION').length,
    AMBIGUOUS: byVerdict('AMBIGUOUS').length,
    NO_DATA_TO_MIGRATE: byVerdict('NO_DATA_TO_MIGRATE').length,
  };
  console.log('\nSummary of solved sessions:');
  console.log(`  safe to delete now (already in solvedProblems) : ${summary.ALREADY_SAVED}`);
  console.log(`  needs migrating then deleting                  : ${summary.NEEDS_MIGRATION}`);
  console.log(`  ambiguous (multiple title matches)             : ${summary.AMBIGUOUS}  <- will be skipped by migrate.mjs`);
  console.log(`  no data to migrate                             : ${summary.NO_DATA_TO_MIGRATE}  <- will be skipped by migrate.mjs`);
  console.log('\nActive and starred sessions are never touched by migrate.mjs.\n');

  const outPath = path.join(__dirname, 'report.json');
  fs.writeFileSync(outPath, JSON.stringify({ coupleId: couple, generatedAt: new Date().toISOString(), counts, summary, rows }, null, 2));
  console.log(`Full report written to ${outPath}`);

  process.exit(0);
}

main().catch((err) => {
  console.error('Report failed:', err);
  process.exit(1);
});
