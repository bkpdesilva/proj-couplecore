import { initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import fs from 'node:fs';

export const PROJECT_ID = 'couplecore-bae2e';

/**
 * Auth: uses GOOGLE_APPLICATION_CREDENTIALS (path to a service account JSON)
 * if set, otherwise falls back to gcloud Application Default Credentials
 * (`gcloud auth application-default login`). Neither path touches the
 * client-side API key in android/app/google-services.json — that key can't
 * do admin Firestore writes anyway.
 */
export function initDb() {
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const app = initializeApp({
    credential: keyPath
      ? cert(JSON.parse(fs.readFileSync(keyPath, 'utf8')))
      : applicationDefault(),
    projectId: PROJECT_ID,
  });
  return getFirestore(app);
}

export async function loadCoupleData(db, coupleId) {
  const coupleRef = db.collection('couples').doc(coupleId);
  const [sessionsSnap, solvedSnap] = await Promise.all([
    coupleRef.collection('problemSessions').get(),
    coupleRef.collection('solvedProblems').get(),
  ]);
  const sessions = sessionsSnap.docs.map((d) => ({
    id: d.id,
    ref: d.ref,
    ...d.data(),
  }));
  const solved = solvedSnap.docs.map((d) => ({
    id: d.id,
    ref: d.ref,
    ...d.data(),
  }));
  return { coupleRef, sessions, solved };
}

/**
 * There is no sourceId linking a solvedProblems doc back to the
 * problemSessions doc it came from — sourceTitle is copied verbatim from
 * session.title at save time (see saveSolvedProblem call site in
 * problem_solver_screen.dart), and that's the only correlation key we have.
 * A generic auto-generated title ("Problem 22/8/2026") can collide across
 * sessions, so a title match is necessary but not sufficient by itself:
 * exactly one candidate -> confident match; more than one -> ambiguous,
 * left for manual review rather than guessed at.
 */
export function classifySession(session, solvedDocs) {
  if (session.status !== 'solved') return { verdict: 'NOT_SOLVED' };
  if (session.starred === true) return { verdict: 'STARRED_SKIP' };

  const candidates = solvedDocs.filter((s) => s.sourceTitle === session.title);
  if (candidates.length === 1) {
    return { verdict: 'ALREADY_SAVED', match: candidates[0] };
  }
  if (candidates.length > 1) {
    return { verdict: 'AMBIGUOUS', candidates };
  }
  const hasLegacyData = Boolean(
    (session.problemSummary && session.problemSummary.trim()) ||
      (session.solution && session.solution.trim()),
  );
  return { verdict: hasLegacyData ? 'NEEDS_MIGRATION' : 'NO_DATA_TO_MIGRATE' };
}

export function parseArgs(argv) {
  const args = { execute: false, couple: null, only: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--execute') args.execute = true;
    else if (a === '--couple') args.couple = argv[++i];
    else if (a === '--only') args.only = argv[++i];
  }
  return args;
}
