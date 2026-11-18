'use strict';
// One-off MySQL -> Firebase migration. Dry run by default; pass --commit to write.
// Targets only the Firebase emulators or a project ID ending in -dev.
const mysql = require('mysql2/promise');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');

const ROLES = new Set(['learner', 'instructor', 'corporate_admin', 'corporate_manager', 'employer', 'admin', 'super_admin']);
const COURSE_STATUSES = new Set(['draft', 'pending_review', 'published', 'rejected', 'archived']);
const commit = process.argv.includes('--commit');

function need(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Set environment variable ${name}.`);
  return v;
}
const ts = (d) => (d ? Timestamp.fromDate(new Date(d)) : FieldValue.serverTimestamp());
const uidFor = (legacyId) => `legacy-${legacyId}`;

async function main() {
  const mapping = require('./mapping.js');
  const projectId = process.env.GCLOUD_PROJECT || '';
  const emulator = process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!emulator && !/-dev$/i.test(projectId)) {
    throw new Error('Refusing: target must be the Firebase emulators or a project ID ending in -dev.');
  }
  initializeApp({ projectId: projectId || 'demo-ab-learning' });
  const auth = getAuth();
  const db = getFirestore();
  const conn = await mysql.createConnection({
    host: need('MYSQL_HOST'), port: Number(process.env.MYSQL_PORT || 3306),
    user: need('MYSQL_USER'), password: need('MYSQL_PASSWORD'), database: need('MYSQL_DATABASE'),
  });

  const problems = [];
  const counts = { users: 0, courses: 0, enrollments: 0 };
  const [users] = await conn.query(mapping.users);
  const [courses] = await conn.query(mapping.courses);
  const [enrollments] = await conn.query(mapping.enrollments);
  const userIds = new Set();
  const courseIds = new Set();

  for (const u of users) {
    const email = String(u.email || '').trim().toLowerCase();
    const role = mapping.roleMap[u.role] || (ROLES.has(u.role) ? u.role : null);
    if (!/^[^@\s]+@[^@\s]+$/.test(email)) { problems.push(`user ${u.id}: invalid email`); continue; }
    if (!role) { problems.push(`user ${u.id}: unmapped role "${u.role}"`); continue; }
    userIds.add(String(u.id));
    counts.users++;
    if (!commit) continue;
    const uid = uidFor(u.id);
    // No password is imported: users set one through "forgot password".
    await auth.createUser({ uid, email, displayName: u.display_name || email, emailVerified: false })
      .catch(async (e) => { if (e.code !== 'auth/uid-already-exists') throw e; });
    await auth.setCustomUserClaims(uid, { role });
    await db.collection('users').doc(uid).set({
      uid, email, displayName: u.display_name || email, role, status: 'active',
      legacyId: String(u.id), createdAt: ts(u.created_at), updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  for (const c of courses) {
    const status = mapping.courseStatusMap[c.status] || (COURSE_STATUSES.has(c.status) ? c.status : null);
    const price = Number(c.price);
    if (!status) { problems.push(`course ${c.id}: unmapped status "${c.status}"`); continue; }
    if (!Number.isFinite(price) || price < 0) { problems.push(`course ${c.id}: invalid price`); continue; }
    if (!userIds.has(String(c.instructor_id))) { problems.push(`course ${c.id}: instructor ${c.instructor_id} not migrated`); continue; }
    courseIds.add(String(c.id));
    counts.courses++;
    if (!commit) continue;
    await db.collection('courses').doc(`legacy-${c.id}`).set({
      title: c.title, description: c.description || '', categoryId: c.category || '',
      price, status, instructorId: uidFor(c.instructor_id), instructorName: c.instructor_name || '',
      thumbnailUrl: '', legacyId: String(c.id),
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  for (const e of enrollments) {
    if (!userIds.has(String(e.user_id)) || !courseIds.has(String(e.course_id))) {
      problems.push(`enrollment ${e.user_id}/${e.course_id}: user or course not migrated`); continue;
    }
    counts.enrollments++;
    if (!commit) continue;
    const studentId = uidFor(e.user_id);
    const courseId = `legacy-${e.course_id}`;
    await db.collection('enrollments').doc(`${studentId}_${courseId}`).set({
      studentId, courseId, status: 'active', enrolledAt: ts(e.enrolled_at),
    }, { merge: true });
  }

  await conn.end();
  process.stdout.write(`${commit ? 'WROTE' : 'DRY RUN (nothing written)'}: ${JSON.stringify(counts)}\n`);
  if (problems.length) {
    process.stdout.write(`${problems.length} row(s) skipped:\n${problems.slice(0, 50).join('\n')}\n`);
  }
}

main().catch((e) => { process.stderr.write(`${e.message}\n`); process.exitCode = 1; });
