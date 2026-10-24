const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

async function main() {
  const uid = process.argv[2];
  const expectedDevProjectId = process.argv[3];
  const projectId = process.env.GCLOUD_PROJECT;
  if (!uid || !expectedDevProjectId || projectId !== expectedDevProjectId || !/-dev/i.test(projectId)) {
    throw new Error('Usage: GCLOUD_PROJECT=<dev-id> node bootstrap_superadmin.js <auth-uid> <same-dev-id>');
  }

  initializeApp({ projectId });
  const auth = getAuth();
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, { ...(user.customClaims || {}), role: 'super_admin' });
  await getFirestore().collection('users').doc(uid).set({
    uid,
    email: user.email || '',
    displayName: user.displayName || '',
    role: 'super_admin',
    status: 'active',
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await getFirestore().collection('audit_logs').add({
    actorUid: 'bootstrap',
    action: 'initial_super_admin_bootstrapped',
    targetType: 'user',
    targetId: uid,
    createdAt: FieldValue.serverTimestamp(),
  });
  process.stdout.write(`Super Admin claim assigned to ${uid} in ${projectId}. Sign out and back in to refresh the ID token.\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
