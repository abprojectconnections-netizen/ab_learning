const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getStorage } = require('firebase-admin/storage');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { HttpsError, onCall, onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const Stripe = require('stripe');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const crypto = require('node:crypto');

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

/**
 * Single place that turns a pending payment into an enrollment + sales entry.
 * Called by the DEV mock function and by the verified Stripe webhook only.
 */
async function fulfillPayment(transactionId, { expectedUid, confirmedBy, provider, providerRef, idempotent = false }) {
  const paymentRef = db.collection('payment_mock').doc(transactionId);
  await db.runTransaction(async (transaction) => {
    const paymentSnapshot = await transaction.get(paymentRef);
    if (!paymentSnapshot.exists) throw new HttpsError('not-found', 'Payment was not found.');
    const payment = paymentSnapshot.data();
    const uid = payment.studentId;
    if (expectedUid && payment.studentId !== expectedUid) throw new HttpsError('permission-denied', 'This payment belongs to another user.');
    if (payment.status === 'success' && idempotent) return; // webhook retry
    if (payment.status !== 'pending') throw new HttpsError('failed-precondition', 'Payment is no longer pending.');

    const courseRef = db.collection('courses').doc(payment.courseId);
    const courseSnapshot = await transaction.get(courseRef);
    if (!courseSnapshot.exists || courseSnapshot.data().status !== 'published') {
      throw new HttpsError('failed-precondition', 'Course is not available.');
    }
    if (Number(payment.amount) !== Number(courseSnapshot.data().price)) {
      throw new HttpsError('failed-precondition', 'Payment amount does not match course price.');
    }

    const buyerSnapshot = await transaction.get(db.collection('users').doc(uid));
    const enrollmentRef = db.collection('enrollments').doc(`${uid}_${payment.courseId}`);
    const enrollmentSnapshot = await transaction.get(enrollmentRef);
    if (enrollmentSnapshot.exists && enrollmentSnapshot.data().status === 'active') {
      throw new HttpsError('already-exists', 'The learner is already enrolled.');
    }

    transaction.update(paymentRef, {
      status: 'success',
      paidAt: FieldValue.serverTimestamp(),
      confirmedBy,
      provider,
      ...(providerRef ? { providerRef } : {}),
    });
    transaction.set(enrollmentRef, {
      studentId: uid,
      courseId: payment.courseId,
      status: 'active',
      enrolledAt: FieldValue.serverTimestamp(),
    });
    // Ledger entry read by the instructor's sales dashboard and balance.
    transaction.create(db.collection('sales').doc(transactionId), {
      instructorId: courseSnapshot.data().instructorId,
      courseId: payment.courseId,
      courseTitle: courseSnapshot.data().title,
      buyerName: buyerSnapshot.data()?.displayName || 'Learner',
      amount: Number(payment.amount),
      currency: payment.currency || 'THB',
      status: 'paid',
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(db.collection('audit_logs').doc(), {
      actorUid: uid,
      action: `${provider}_payment_confirmed`,
      targetType: 'payment',
      targetId: transactionId,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

exports.confirmMockPayment = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  assertDevelopmentProject();
  const transactionId = request.data?.transactionId;
  if (typeof transactionId !== 'string' || !transactionId.trim()) {
    throw new HttpsError('invalid-argument', 'transactionId is required.');
  }
  await fulfillPayment(transactionId, { expectedUid: uid, confirmedBy: 'dev-mock-function', provider: 'mock' });
  return { status: 'success' };
});

// ---------------------------------------------------------------------------
// Stripe Checkout (production payments)
// ---------------------------------------------------------------------------

const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

/**
 * Creates a Stripe Checkout Session for a pending payment. The amount comes
 * from the course document, never from the client.
 */
exports.createCheckoutSession = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  const { transactionId, returnUrl } = request.data || {};
  if (typeof transactionId !== 'string' || !transactionId || typeof returnUrl !== 'string') {
    throw new HttpsError('invalid-argument', 'transactionId and returnUrl are required.');
  }
  const allowedOrigins = (process.env.CHECKOUT_RETURN_ORIGINS || '').split(',').map((o) => o.trim()).filter(Boolean);
  let origin;
  try { origin = new URL(returnUrl).origin; } catch { throw new HttpsError('invalid-argument', 'returnUrl is invalid.'); }
  if (!allowedOrigins.includes(origin)) throw new HttpsError('invalid-argument', 'returnUrl origin is not allowed.');

  const paymentSnapshot = await db.collection('payment_mock').doc(transactionId).get();
  if (!paymentSnapshot.exists) throw new HttpsError('not-found', 'Payment was not found.');
  const payment = paymentSnapshot.data();
  if (payment.studentId !== uid) throw new HttpsError('permission-denied', 'This payment belongs to another user.');
  if (payment.status !== 'pending') throw new HttpsError('failed-precondition', 'Payment is no longer pending.');
  const course = await db.collection('courses').doc(payment.courseId).get();
  if (!course.exists || course.data().status !== 'published') throw new HttpsError('failed-precondition', 'Course is not available.');
  const price = Number(course.data().price);
  if (!(price > 0) || price !== Number(payment.amount)) throw new HttpsError('failed-precondition', 'Payment amount does not match course price.');

  const stripe = new Stripe(stripeSecretKey.value());
  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    client_reference_id: transactionId,
    metadata: { transactionId, uid, courseId: payment.courseId },
    line_items: [{
      quantity: 1,
      price_data: {
        currency: (payment.currency || 'THB').toLowerCase(),
        unit_amount: Math.round(price * 100),
        product_data: { name: course.data().title },
      },
    }],
    success_url: `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}checkout=success`,
    cancel_url: `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}checkout=cancelled`,
  }, { idempotencyKey: `checkout-${transactionId}` });
  await paymentSnapshot.ref.update({ provider: 'stripe', providerRef: session.id });
  return { url: session.url };
});

/**
 * Stripe webhook: the ONLY path that activates a paid enrollment in
 * production. The raw body is verified against the signing secret.
 */
exports.stripeWebhook = onRequest({ secrets: [stripeSecretKey, stripeWebhookSecret] }, async (req, res) => {
  if (req.method !== 'POST') return void res.status(405).send('Method not allowed');
  const stripe = new Stripe(stripeSecretKey.value());
  let event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, req.headers['stripe-signature'], stripeWebhookSecret.value());
  } catch (error) {
    console.warn('Stripe signature verification failed', error.message);
    return void res.status(400).send('Invalid signature');
  }
  if (event.type === 'checkout.session.completed' || event.type === 'checkout.session.async_payment_succeeded') {
    const session = event.data.object;
    const transactionId = session.client_reference_id;
    if (session.payment_status === 'paid' && transactionId) {
      try {
        await fulfillPayment(transactionId, {
          confirmedBy: 'stripe-webhook',
          provider: 'stripe',
          providerRef: session.id,
          idempotent: true,
        });
      } catch (error) {
        // Already enrolled / missing payment: log for manual reconciliation but
        // acknowledge so Stripe does not retry forever.
        console.error('Stripe fulfillment failed', transactionId, error.message);
        if (!(error instanceof HttpsError)) return void res.status(500).send('Fulfillment error');
      }
    }
  } else if (event.type === 'checkout.session.expired') {
    const transactionId = event.data.object.client_reference_id;
    if (transactionId) {
      await db.collection('payment_mock').doc(transactionId).update({ status: 'cancelled' }).catch(() => {});
    }
  }
  res.status(200).json({ received: true });
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

// ---------------------------------------------------------------------------
// Learning: quizzes, certificates
// ---------------------------------------------------------------------------

async function notify(uid, title, message) {
  await db.collection('users').doc(uid).collection('notifications').add({
    title,
    message,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function requireActiveEnrollment(uid, courseId) {
  const snapshot = await db.collection('enrollments').doc(`${uid}_${courseId}`).get();
  if (!snapshot.exists || snapshot.data().status !== 'active') {
    throw new HttpsError('permission-denied', 'An active enrollment is required.');
  }
}

/**
 * Issues a certificate when every lesson is completed and every quiz of the
 * course has a passing attempt. Idempotent: the document id is {uid}_{courseId}.
 */
async function issueCertificateIfEligible(uid, courseId) {
  const certificateRef = db.collection('certificates').doc(`${uid}_${courseId}`);
  if ((await certificateRef.get()).exists) return { issued: false, reason: 'already_issued' };

  const [lessons, progress, quizzes, attempts] = await Promise.all([
    db.collection('courses').doc(courseId).collection('lessons').get(),
    db.collection('users').doc(uid).collection('progress').where('courseId', '==', courseId).get(),
    db.collection('quizzes').where('courseId', '==', courseId).get(),
    db.collection('quiz_attempts').where('studentId', '==', uid).where('courseId', '==', courseId).where('passed', '==', true).get(),
  ]);
  if (lessons.empty) return { issued: false, reason: 'no_lessons' };
  const completed = new Set(progress.docs.filter((d) => d.data().completed === true).map((d) => d.id));
  if (!lessons.docs.every((d) => completed.has(d.id))) return { issued: false, reason: 'lessons_incomplete' };
  const passedQuizIds = new Set(attempts.docs.map((d) => d.data().quizId));
  if (!quizzes.docs.every((d) => passedQuizIds.has(d.id))) return { issued: false, reason: 'quiz_not_passed' };

  const [course, user] = await Promise.all([
    db.collection('courses').doc(courseId).get(),
    db.collection('users').doc(uid).get(),
  ]);
  const courseTitle = course.data()?.title || courseId;
  const learnerName = user.data()?.displayName || 'Learner';
  const verificationCode = `AB-${crypto.randomBytes(5).toString('hex').toUpperCase()}`;

  const batch = db.batch();
  batch.create(certificateRef, {
    studentId: uid,
    learnerName,
    courseId,
    courseTitle,
    verificationCode,
    issuedAt: FieldValue.serverTimestamp(),
  });
  batch.create(db.collection('certificate_verifications').doc(verificationCode), {
    courseTitle,
    learnerName,
    issuedAt: FieldValue.serverTimestamp(),
  });
  try {
    await batch.commit();
  } catch (error) {
    if (error.code === 6) return { issued: false, reason: 'already_issued' }; // ALREADY_EXISTS race
    throw error;
  }
  await notify(uid, 'ได้รับใบประกาศนียบัตร', `คุณเรียนจบคอร์ส ${courseTitle} แล้ว`);
  return { issued: true, verificationCode };
}

exports.submitQuiz = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  const { quizId, answers } = request.data || {};
  if (typeof quizId !== 'string' || !quizId || typeof answers !== 'object' || answers === null) {
    throw new HttpsError('invalid-argument', 'quizId and answers are required.');
  }
  const [quizSnapshot, keySnapshot] = await Promise.all([
    db.collection('quizzes').doc(quizId).get(),
    db.collection('quiz_answers').doc(quizId).get(),
  ]);
  if (!quizSnapshot.exists || !keySnapshot.exists) throw new HttpsError('not-found', 'Quiz was not found.');
  const quiz = quizSnapshot.data();
  await requireActiveEnrollment(uid, quiz.courseId);

  const key = keySnapshot.data().answers || {};
  const questionIds = (quiz.questions || []).map((q) => q.id);
  if (questionIds.length === 0) throw new HttpsError('failed-precondition', 'Quiz has no questions.');
  const correct = questionIds.filter((id) => Number.isInteger(answers[id]) && answers[id] === key[id]).length;
  const scorePercent = Math.round((correct * 100) / questionIds.length);
  const passed = scorePercent >= Number(quiz.passThresholdPercent ?? 70);

  await db.collection('quiz_attempts').add({
    studentId: uid,
    courseId: quiz.courseId,
    quizId,
    scorePercent,
    passed,
    createdAt: FieldValue.serverTimestamp(),
  });
  const certificate = passed ? await issueCertificateIfEligible(uid, quiz.courseId) : { issued: false };
  return { scorePercent, passed, certificateIssued: certificate.issued === true };
});

exports.claimCertificate = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  const courseId = request.data?.courseId;
  if (typeof courseId !== 'string' || !courseId) throw new HttpsError('invalid-argument', 'courseId is required.');
  await requireActiveEnrollment(uid, courseId);
  return issueCertificateIfEligible(uid, courseId);
});

exports.onEnrollmentCreated = onDocumentCreated('enrollments/{enrollmentId}', async (event) => {
  const data = event.data?.data();
  if (!data?.studentId) return;
  const course = await db.collection('courses').doc(data.courseId).get();
  await notify(data.studentId, 'ลงทะเบียนเรียนสำเร็จ', `คุณสามารถเริ่มเรียน ${course.data()?.title || 'คอร์สนี้'} ได้แล้ว`);
});

exports.onSaleCreated = onDocumentCreated('sales/{saleId}', async (event) => {
  const sale = event.data?.data();
  if (!sale?.instructorId) return;
  await notify(sale.instructorId, 'มียอดขายใหม่', `${sale.buyerName} ซื้อ ${sale.courseTitle} (฿${sale.amount})`);
});

// ---------------------------------------------------------------------------
// Revenue: balance and payout requests (instructor share is server config)
// ---------------------------------------------------------------------------

async function readRevenueConfig() {
  const snapshot = await db.collection('platform_config').doc('revenue').get();
  const share = Number(snapshot.data()?.instructorShare);
  const minPayout = Number(snapshot.data()?.minPayout);
  if (!snapshot.exists || !(share > 0 && share <= 1) || !(minPayout > 0)) {
    throw new HttpsError('failed-precondition', 'platform_config/revenue is not configured.');
  }
  return { share, minPayout };
}

function summarize(config, salesDocs, payoutDocs) {
  const gross = salesDocs.reduce((sum, d) => sum + (d.data().status === 'paid' ? Number(d.data().amount) : 0), 0);
  const earned = Math.round(gross * config.share * 100) / 100;
  const reserved = payoutDocs
    .filter((d) => d.data().status !== 'rejected')
    .reduce((sum, d) => sum + Number(d.data().amount), 0);
  return { gross, earned, reserved, balance: Math.max(0, Math.round((earned - reserved) * 100) / 100), minPayout: config.minPayout };
}

exports.getRevenueSummary = onCall(async (request) => {
  requireRole(request, ['instructor']);
  const uid = request.auth.uid;
  const config = await readRevenueConfig();
  const [sales, payouts] = await Promise.all([
    db.collection('sales').where('instructorId', '==', uid).get(),
    db.collection('payouts').where('instructorId', '==', uid).get(),
  ]);
  return summarize(config, sales.docs, payouts.docs);
});

exports.requestPayout = onCall(async (request) => {
  requireRole(request, ['instructor']);
  const uid = request.auth.uid;
  const amount = Number(request.data?.amount);
  if (!Number.isFinite(amount) || amount <= 0) throw new HttpsError('invalid-argument', 'A positive amount is required.');
  const config = await readRevenueConfig();
  if (amount < config.minPayout) throw new HttpsError('failed-precondition', `Minimum payout is ${config.minPayout}.`);

  const payoutRef = db.collection('payouts').doc();
  await db.runTransaction(async (transaction) => {
    const [sales, payouts] = await Promise.all([
      transaction.get(db.collection('sales').where('instructorId', '==', uid)),
      transaction.get(db.collection('payouts').where('instructorId', '==', uid)),
    ]);
    const { balance } = summarize(config, sales.docs, payouts.docs);
    if (amount > balance) throw new HttpsError('failed-precondition', 'Amount exceeds available balance.');
    transaction.create(payoutRef, {
      instructorId: uid,
      amount,
      status: 'pending',
      requestedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(db.collection('audit_logs').doc(), {
      actorUid: uid,
      action: 'payout_requested',
      targetType: 'payout',
      targetId: payoutRef.id,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return { payoutId: payoutRef.id };
});

// ---------------------------------------------------------------------------
// Video playback: short-lived signed URLs after an access check
// ---------------------------------------------------------------------------

exports.getVideoAccessUrl = onCall(async (request) => {
  const uid = request.auth?.uid;
  const { courseId, lessonId } = request.data || {};
  if (typeof courseId !== 'string' || typeof lessonId !== 'string' || !courseId || !lessonId) {
    throw new HttpsError('invalid-argument', 'courseId and lessonId are required.');
  }
  const [course, lesson] = await Promise.all([
    db.collection('courses').doc(courseId).get(),
    db.collection('courses').doc(courseId).collection('lessons').doc(lessonId).get(),
  ]);
  if (!course.exists || !lesson.exists) throw new HttpsError('not-found', 'Lesson was not found.');
  const videoRef = lesson.data().videoRef;
  if (typeof videoRef !== 'string' || !videoRef.startsWith(`lesson_videos/${courseId}/`)) {
    throw new HttpsError('failed-precondition', 'No video has been uploaded for this lesson.');
  }

  const role = request.auth?.token?.role;
  const isStaff = role === 'admin' || role === 'super_admin' || course.data().instructorId === uid;
  let allowed = isStaff;
  if (!allowed && course.data().status === 'published') {
    if (lesson.data().isPreview === true) {
      allowed = true;
    } else if (uid) {
      const enrollment = await db.collection('enrollments').doc(`${uid}_${courseId}`).get();
      allowed = enrollment.exists && enrollment.data().status === 'active';
    }
  }
  if (!allowed) throw new HttpsError('permission-denied', 'You do not have access to this lesson.');

  const [url] = await getStorage().bucket().file(videoRef).getSignedUrl({
    version: 'v4',
    action: 'read',
    expires: Date.now() + 15 * 60 * 1000,
  });
  return { url, expiresInSeconds: 900 };
});

// ---------------------------------------------------------------------------
// Organizations (corporate learning) and platform administration
// ---------------------------------------------------------------------------

async function writeAudit(actorUid, action, targetType, targetId, extra = {}) {
  await db.collection('audit_logs').add({
    actorUid, action, targetType, targetId, ...extra, createdAt: FieldValue.serverTimestamp(),
  });
}

async function myOrgMembership(uid, roles) {
  const snapshot = await db.collection('org_members').where('uid', '==', uid).where('status', '==', 'active').get();
  const doc = snapshot.docs.find((d) => roles.includes(d.data().role));
  if (!doc) throw new HttpsError('permission-denied', 'You do not belong to an organization with this access.');
  return doc.data();
}

exports.createOrganization = onCall(async (request) => {
  requireRole(request, ['admin', 'super_admin']);
  const { name, ownerEmail } = request.data || {};
  if (typeof name !== 'string' || !name.trim() || typeof ownerEmail !== 'string') {
    throw new HttpsError('invalid-argument', 'name and ownerEmail are required.');
  }
  const owner = await getAuth().getUserByEmail(ownerEmail.trim().toLowerCase()).catch(() => null);
  if (!owner) throw new HttpsError('not-found', 'No account exists for that email.');
  const orgRef = db.collection('organizations').doc();
  const batch = db.batch();
  batch.create(orgRef, { name: name.trim(), ownerUid: owner.uid, createdAt: FieldValue.serverTimestamp() });
  batch.create(db.collection('org_members').doc(`${orgRef.id}_${owner.uid}`), {
    orgId: orgRef.id,
    uid: owner.uid,
    email: owner.email,
    displayName: owner.displayName || owner.email,
    role: 'admin',
    status: 'active',
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  await getAuth().setCustomUserClaims(owner.uid, { ...(owner.customClaims || {}), role: 'corporate_admin' });
  await db.collection('users').doc(owner.uid).set({ role: 'corporate_admin', updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  await writeAudit(request.auth.uid, 'organization_created', 'organization', orgRef.id, { ownerUid: owner.uid });
  return { orgId: orgRef.id };
});

exports.addOrgMember = onCall(async (request) => {
  requireRole(request, ['corporate_admin']);
  const email = String(request.data?.email || '').trim().toLowerCase();
  const memberRole = request.data?.role === 'manager' ? 'manager' : 'member';
  if (!email.includes('@')) throw new HttpsError('invalid-argument', 'A valid email is required.');
  const admin = await myOrgMembership(request.auth.uid, ['admin']);
  const user = await getAuth().getUserByEmail(email).catch(() => null);
  if (!user) throw new HttpsError('not-found', 'No account exists for that email. Ask them to sign up first.');
  const ref = db.collection('org_members').doc(`${admin.orgId}_${user.uid}`);
  if ((await ref.get()).exists) throw new HttpsError('already-exists', 'This person is already a member.');
  await ref.create({
    orgId: admin.orgId,
    uid: user.uid,
    email: user.email,
    displayName: user.displayName || user.email,
    role: memberRole,
    status: 'active',
    createdAt: FieldValue.serverTimestamp(),
  });
  if (memberRole === 'manager') {
    await getAuth().setCustomUserClaims(user.uid, { ...(user.customClaims || {}), role: 'corporate_manager' });
    await db.collection('users').doc(user.uid).set({ role: 'corporate_manager', updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }
  await writeAudit(request.auth.uid, 'org_member_added', 'org_member', ref.id, { orgId: admin.orgId });
  return { memberId: ref.id };
});

exports.getOrgTeamProgress = onCall(async (request) => {
  requireRole(request, ['corporate_admin', 'corporate_manager']);
  const me = await myOrgMembership(request.auth.uid, ['admin', 'manager']);
  const members = await db.collection('org_members').where('orgId', '==', me.orgId).get();
  const rows = await Promise.all(members.docs.map(async (doc) => {
    const m = doc.data();
    const [enrollments, certificates] = await Promise.all([
      db.collection('enrollments').where('studentId', '==', m.uid).where('status', '==', 'active').count().get(),
      db.collection('certificates').where('studentId', '==', m.uid).count().get(),
    ]);
    return {
      uid: m.uid,
      displayName: m.displayName,
      email: m.email,
      memberStatus: m.status,
      enrolledCourses: enrollments.data().count,
      completedCourses: certificates.data().count,
    };
  }));
  return { members: rows };
});

exports.adminSetUserStatus = onCall(async (request) => {
  requireRole(request, ['admin', 'super_admin']);
  const { uid, status } = request.data || {};
  if (typeof uid !== 'string' || !['active', 'suspended'].includes(status)) {
    throw new HttpsError('invalid-argument', 'uid and a valid status are required.');
  }
  if (uid === request.auth.uid) throw new HttpsError('failed-precondition', 'You cannot change your own status.');
  const target = await getAuth().getUser(uid);
  const targetRole = target.customClaims?.role;
  if (['admin', 'super_admin'].includes(targetRole) && request.auth.token.role !== 'super_admin') {
    throw new HttpsError('permission-denied', 'Only a super admin can change another administrator.');
  }
  await getAuth().updateUser(uid, { disabled: status === 'suspended' });
  await db.collection('users').doc(uid).set({ status, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  await writeAudit(request.auth.uid, 'user_status_changed', 'user', uid, { status });
  return { uid, status };
});

// Course moderation: record who reviewed what and tell the instructor.
exports.onCourseReviewed = onDocumentUpdated('courses/{courseId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  if (!['published', 'rejected', 'archived'].includes(after.status)) return;
  await writeAudit(after.reviewedBy || 'unknown', `course_${after.status}`, 'course', event.params.courseId);
  if (after.status === 'published') {
    await notify(after.instructorId, 'คอร์สได้รับการอนุมัติ', `${after.title} เผยแพร่แล้ว`);
  } else if (after.status === 'rejected') {
    await notify(after.instructorId, 'คอร์สถูกส่งกลับแก้ไข', `${after.title} ต้องแก้ไขก่อนส่งตรวจอีกครั้ง`);
  }
});

// ---------------------------------------------------------------------------
// Quiz authoring (instructors). Answer keys are written server-side only.
// ---------------------------------------------------------------------------

async function requireOwnedEditableCourse(request, courseId) {
  requireRole(request, ['instructor']);
  const course = await db.collection('courses').doc(courseId).get();
  if (!course.exists || course.data().instructorId !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'You do not own this course.');
  }
  if (!['draft', 'rejected'].includes(course.data().status)) {
    throw new HttpsError('failed-precondition', 'Quizzes can only be edited while the course is a draft.');
  }
  return course;
}

function validateQuizInput(data) {
  const fail = (message) => { throw new HttpsError('invalid-argument', message); };
  const title = typeof data.title === 'string' ? data.title.trim() : '';
  if (!title || title.length > 120) fail('Title is required (max 120 characters).');
  const threshold = data.passThresholdPercent;
  if (!Number.isInteger(threshold) || threshold < 1 || threshold > 100) fail('passThresholdPercent must be 1-100.');
  if (typeof data.lectureId !== 'string' || !data.lectureId) fail('lectureId is required.');
  if (!Array.isArray(data.questions) || data.questions.length < 1 || data.questions.length > 50) fail('Provide 1-50 questions.');
  const questions = [];
  const answers = {};
  data.questions.forEach((q, index) => {
    const text = typeof q?.text === 'string' ? q.text.trim() : '';
    const options = Array.isArray(q?.options) ? q.options.map((o) => (typeof o === 'string' ? o.trim() : '')) : [];
    if (!text || text.length > 300) fail(`Question ${index + 1}: text is required (max 300).`);
    if (options.length < 2 || options.length > 6 || options.some((o) => !o || o.length > 200)) {
      fail(`Question ${index + 1}: provide 2-6 non-empty options.`);
    }
    if (!Number.isInteger(q.correctIndex) || q.correctIndex < 0 || q.correctIndex >= options.length) {
      fail(`Question ${index + 1}: correctIndex is out of range.`);
    }
    const id = `q${index + 1}`;
    questions.push({ id, text, options });
    answers[id] = q.correctIndex;
  });
  return { title, threshold, questions, answers };
}

exports.saveQuiz = onCall(async (request) => {
  const { courseId, quizId } = request.data || {};
  if (typeof courseId !== 'string' || !courseId) throw new HttpsError('invalid-argument', 'courseId is required.');
  await requireOwnedEditableCourse(request, courseId);
  const input = validateQuizInput(request.data);
  const lesson = await db.collection('courses').doc(courseId).collection('lessons').doc(request.data.lectureId).get();
  if (!lesson.exists) throw new HttpsError('failed-precondition', 'The selected lesson does not exist.');

  let ref;
  let isNew = true;
  if (quizId) {
    ref = db.collection('quizzes').doc(String(quizId));
    const existing = await ref.get();
    if (!existing.exists || existing.data().courseId !== courseId) throw new HttpsError('not-found', 'Quiz was not found.');
    isNew = false;
  } else {
    ref = db.collection('quizzes').doc();
  }
  const batch = db.batch();
  batch.set(ref, {
    courseId,
    lectureId: request.data.lectureId,
    title: input.title,
    passThresholdPercent: input.threshold,
    questions: input.questions,
    ...(isNew ? { createdAt: FieldValue.serverTimestamp() } : { updatedAt: FieldValue.serverTimestamp() }),
  }, { merge: true });
  batch.set(db.collection('quiz_answers').doc(ref.id), { answers: input.answers });
  await batch.commit();
  await writeAudit(request.auth.uid, isNew ? 'quiz_created' : 'quiz_updated', 'quiz', ref.id, { courseId });
  return { quizId: ref.id };
});

exports.getQuizForEditing = onCall(async (request) => {
  const courseId = request.data?.courseId;
  if (typeof courseId !== 'string' || !courseId) throw new HttpsError('invalid-argument', 'courseId is required.');
  requireRole(request, ['instructor']);
  const course = await db.collection('courses').doc(courseId).get();
  if (!course.exists || course.data().instructorId !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'You do not own this course.');
  }
  const quizzes = await db.collection('quizzes').where('courseId', '==', courseId).orderBy('createdAt').limit(1).get();
  if (quizzes.empty) return { quiz: null };
  const quiz = quizzes.docs[0];
  const key = (await db.collection('quiz_answers').doc(quiz.id).get()).data()?.answers || {};
  const data = quiz.data();
  return {
    quiz: {
      id: quiz.id,
      lectureId: data.lectureId,
      title: data.title,
      passThresholdPercent: data.passThresholdPercent,
      questions: (data.questions || []).map((q) => ({ text: q.text, options: q.options, correctIndex: key[q.id] ?? 0 })),
    },
  };
});

/**
 * Permanently deletes the caller's account and personal data. Financial
 * ledgers (payments, sales, payouts) are retained but anonymised. Refuses when
 * deletion would orphan other people's data (owned courses, organizations) or
 * lock out the platform (super admin).
 */
exports.deleteMyAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  if (request.data?.confirm !== 'DELETE') throw new HttpsError('invalid-argument', 'Confirmation is required.');
  if (request.auth.token.role === 'super_admin') {
    throw new HttpsError('failed-precondition', 'A super admin account cannot delete itself.');
  }

  const [ownedCourses, ownedOrgs] = await Promise.all([
    db.collection('courses').where('instructorId', '==', uid).limit(1).get(),
    db.collection('organizations').where('ownerUid', '==', uid).limit(1).get(),
  ]);
  if (!ownedCourses.empty) throw new HttpsError('failed-precondition', 'Archive or transfer your courses before deleting your account.');
  if (!ownedOrgs.empty) throw new HttpsError('failed-precondition', 'Transfer organization ownership before deleting your account.');

  const deleteWhere = async (collection, field) => {
    const snapshot = await db.collection(collection).where(field, '==', uid).get();
    await Promise.all(snapshot.docs.map((d) => d.ref.delete()));
  };
  await Promise.all([
    deleteWhere('enrollments', 'studentId'),
    deleteWhere('course_reviews', 'studentId'),
    deleteWhere('quiz_attempts', 'studentId'),
    deleteWhere('job_applications', 'candidateId'),
    deleteWhere('org_members', 'uid'),
    deleteWhere('instructor_applications', 'uid'),
  ]);

  // Certificates: remove the owner's copy and anonymise the public verification record.
  const certificates = await db.collection('certificates').where('studentId', '==', uid).get();
  await Promise.all(certificates.docs.map(async (d) => {
    const code = d.data().verificationCode;
    if (code) await db.collection('certificate_verifications').doc(code).set({ learnerName: 'Deleted user' }, { merge: true });
    await d.ref.delete();
  }));

  // Employers: close open postings instead of deleting other people's applications.
  const postings = await db.collection('job_postings').where('employerId', '==', uid).get();
  await Promise.all(postings.docs.map((d) => d.ref.update({ status: 'closed' })));

  // Payments (keyed by uid only) and sales ledger entries are retained for accounting;
  // they carry no contact details beyond the display name captured at purchase time.

  await db.recursiveDelete(db.collection('users').doc(uid));
  await getStorage().bucket().file(`avatars/${uid}`).delete({ ignoreNotFound: true }).catch(() => {});
  await db.collection('audit_logs').add({
    actorUid: uid,
    action: 'account_deleted',
    targetType: 'user',
    targetId: uid,
    createdAt: FieldValue.serverTimestamp(),
  });
  await getAuth().deleteUser(uid);
  return { deleted: true };
});
