const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');

initializeApp();
const db = getFirestore();

function requireRole(request, roles) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  if (!roles.includes(request.auth.token.role)) {
    throw new HttpsError('permission-denied', 'Insufficient role.');
  }
}

function assertDevelopmentProject() {
  const projectId = process.env.GCLOUD_PROJECT || '';
  if (process.env.FUNCTIONS_EMULATOR === 'true' || /(^|-)dev($|-)/i.test(projectId)) return;
  throw new HttpsError('failed-precondition', 'Mock payment is enabled only in a DEV Firebase project.');
}

exports.confirmMockPayment = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  assertDevelopmentProject();

  const transactionId = request.data?.transactionId;
  if (typeof transactionId !== 'string' || !transactionId.trim()) {
    throw new HttpsError('invalid-argument', 'transactionId is required.');
  }

  const paymentRef = db.collection('payment_mock').doc(transactionId);
  await db.runTransaction(async (transaction) => {
    const paymentSnapshot = await transaction.get(paymentRef);
    if (!paymentSnapshot.exists) throw new HttpsError('not-found', 'Payment was not found.');
    const payment = paymentSnapshot.data();
    if (payment.studentId !== uid) throw new HttpsError('permission-denied', 'This payment belongs to another user.');
    if (payment.status !== 'pending') throw new HttpsError('failed-precondition', 'Payment is no longer pending.');

    const courseRef = db.collection('courses').doc(payment.courseId);
    const courseSnapshot = await transaction.get(courseRef);
    if (!courseSnapshot.exists || courseSnapshot.data().status !== 'published') {
      throw new HttpsError('failed-precondition', 'Course is not available.');
    }
    if (Number(payment.amount) !== Number(courseSnapshot.data().price)) {
      throw new HttpsError('failed-precondition', 'Payment amount does not match course price.');
    }

    const enrollmentRef = db.collection('enrollments').doc(`${uid}_${payment.courseId}`);
    const enrollmentSnapshot = await transaction.get(enrollmentRef);
    if (enrollmentSnapshot.exists && enrollmentSnapshot.data().status === 'active') {
      throw new HttpsError('already-exists', 'The learner is already enrolled.');
    }

    transaction.update(paymentRef, {
      status: 'success',
      paidAt: FieldValue.serverTimestamp(),
      confirmedBy: 'dev-mock-function',
    });
    transaction.set(enrollmentRef, {
      studentId: uid,
      courseId: payment.courseId,
      status: 'active',
      enrolledAt: FieldValue.serverTimestamp(),
    });
    transaction.create(db.collection('audit_logs').doc(), {
      actorUid: uid,
      action: 'mock_payment_confirmed',
      targetType: 'payment_mock',
      targetId: transactionId,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return { status: 'success' };
});

exports.setUserRole = onCall(async (request) => {
  requireRole(request, ['super_admin']);
  const uid = request.data?.uid;
  const role = request.data?.role;
  const allowedRoles = ['learner', 'instructor', 'corporate_admin', 'corporate_manager', 'employer', 'admin', 'super_admin'];
  if (typeof uid !== 'string' || !allowedRoles.includes(role)) {
    throw new HttpsError('invalid-argument', 'A valid uid and role are required.');
  }

  const user = await getAuth().getUser(uid);
  const claims = { ...(user.customClaims || {}), role };
  await getAuth().setCustomUserClaims(uid, claims);
  await db.collection('users').doc(uid).set({ role, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  await db.collection('audit_logs').add({
    actorUid: request.auth.uid,
    action: 'user_role_changed',
    targetType: 'user',
    targetId: uid,
    role,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { uid, role };
});

exports.approveInstructorApplication = onCall(async (request) => {
  requireRole(request, ['admin', 'super_admin']);
  const applicationId = request.data?.applicationId;
  if (typeof applicationId !== 'string' || !applicationId.trim()) {
    throw new HttpsError('invalid-argument', 'applicationId is required.');
  }
  const applicationRef = db.collection('instructor_applications').doc(applicationId);
  const applicationSnapshot = await applicationRef.get();
  if (!applicationSnapshot.exists || applicationSnapshot.data().status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Application is missing or already reviewed.');
  }
  const uid = applicationSnapshot.data().uid;
  const user = await getAuth().getUser(uid);
  await getAuth().setCustomUserClaims(uid, { ...(user.customClaims || {}), role: 'instructor' });
  await applicationRef.update({
    status: 'approved',
    reviewedAt: FieldValue.serverTimestamp(),
    reviewedBy: request.auth.uid,
  });
  await db.collection('users').doc(uid).set({ role: 'instructor', updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  await db.collection('audit_logs').add({
    actorUid: request.auth.uid,
    action: 'instructor_application_approved',
    targetType: 'instructor_application',
    targetId: applicationId,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { uid, role: 'instructor' };
});
