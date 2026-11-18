// Creates one demo account per role in the Auth + Firestore EMULATORS only.
// Passwords are public demo values and must never exist in a real project.
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const PASSWORD = 'Demo#12345';
const ORG_ID = 'demo-org';
const USERS = [
  { email: 'learner@demo.test', name: 'Demo Learner', role: 'learner' },
  { email: 'instructor@demo.test', name: 'Demo Instructor', role: 'instructor' },
  { email: 'corpadmin@demo.test', name: 'Demo Corporate Admin', role: 'corporate_admin', orgRole: 'admin' },
  { email: 'corpmanager@demo.test', name: 'Demo Corporate Manager', role: 'corporate_manager', orgRole: 'manager' },
  { email: 'employer@demo.test', name: 'Demo Employer', role: 'employer' },
  { email: 'admin@demo.test', name: 'Demo Admin', role: 'admin' },
  { email: 'superadmin@demo.test', name: 'Demo Super Admin', role: 'super_admin' },
];

async function main() {
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Demo users are only created in the Auth and Firestore emulators. Set FIREBASE_AUTH_EMULATOR_HOST and FIRESTORE_EMULATOR_HOST.');
  }
  initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-ab-learning' });
  const auth = getAuth();
  const db = getFirestore();
  let ownerUid = null;
  for (const u of USERS) {
    const existing = await auth.getUserByEmail(u.email).catch(() => null);
    const user = existing
      ? await auth.updateUser(existing.uid, { password: PASSWORD, displayName: u.name })
      : await auth.createUser({ email: u.email, password: PASSWORD, displayName: u.name, emailVerified: true });
    await auth.setCustomUserClaims(user.uid, { role: u.role });
    await db.collection('users').doc(user.uid).set({
      uid: user.uid, email: u.email, displayName: u.name, role: u.role, status: 'active',
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    if (u.role === 'corporate_admin') ownerUid = user.uid;
    if (u.orgRole) {
      await db.collection('org_members').doc(`${ORG_ID}_${user.uid}`).set({
        orgId: ORG_ID, uid: user.uid, email: u.email, displayName: u.name,
        role: u.orgRole, status: 'active', createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }
  await db.collection('organizations').doc(ORG_ID).set({
    name: 'Demo Company', ownerUid, createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  process.stdout.write(`Created ${USERS.length} demo users. Password for all: ${PASSWORD}\n`);
}

main().catch((e) => { process.stderr.write(`${e.message}\n`); process.exitCode = 1; });
