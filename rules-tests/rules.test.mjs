import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = 'demo-ab-learning';
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8180,
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => environment?.cleanup());

async function seed(data) {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [path, value] of Object.entries(data)) {
      await setDoc(doc(db, path), value);
    }
  });
}

const learner = (uid = 'student-1') => environment.authenticatedContext(uid).firestore();
const instructor = (uid = 'instructor-1') =>
  environment.authenticatedContext(uid, { role: 'instructor' }).firestore();
const admin = () => environment.authenticatedContext('admin-1', { role: 'admin' }).firestore();

test('published catalog is readable; another instructor draft is hidden', async () => {
  await seed({
    'courses/public-course': { status: 'published', instructorId: 'instructor-1', price: 0 },
    'courses/private-draft': { status: 'draft', instructorId: 'instructor-2', price: 0 },
  });
  await assertSucceeds(getDoc(doc(learner(), 'courses/public-course')));
  await assertFails(getDoc(doc(learner(), 'courses/private-draft')));
});

test('instructor can create own draft but cannot publish directly', async () => {
  const db = instructor();
  const ownDraft = doc(db, 'courses/instructor-draft');
  await assertSucceeds(setDoc(ownDraft, {
    title: 'Draft',
    description: '',
    price: 0,
    categoryId: 'cat-it',
    instructorId: 'instructor-1',
    instructorName: 'Teacher',
    thumbnailUrl: '',
    status: 'draft',
    createdAt: new Date(),
    updatedAt: new Date(),
  }));
  await assertSucceeds(setDoc(doc(db, 'courses/instructor-draft/sections/section-1'), {
    title: 'Introduction', order: 1, createdAt: new Date(),
  }));
  await assertSucceeds(setDoc(doc(db, 'courses/instructor-draft/lessons/lesson-1'), {
    sectionId: 'section-1',
    title: 'Welcome',
    durationSeconds: 0,
    order: 1,
    isPreview: true,
    videoRef: null,
  }));
  await assertFails(updateDoc(ownDraft, { status: 'published' }));
  await assertFails(setDoc(doc(db, 'courses/other-owner-course'), {
    title: 'Not mine', instructorId: 'instructor-2', status: 'draft',
  }));
});

test('admin can publish only through a valid course status update', async () => {
  await seed({
    'courses/reviewed-course': {
      status: 'pending_review',
      instructorId: 'instructor-1',
      title: 'Reviewed',
    },
  });
  await assertSucceeds(updateDoc(doc(admin(), 'courses/reviewed-course'), {
    status: 'published',
    reviewedAt: new Date(),
    reviewedBy: 'admin-1',
  }));
  await assertFails(updateDoc(doc(admin(), 'courses/reviewed-course'), {
    instructorId: 'admin-1',
  }));
});

test('learner cannot self-promote profile role', async () => {
  await seed({ 'users/student-1': { uid: 'student-1', role: 'learner', status: 'active' } });
  await assertFails(updateDoc(doc(learner(), 'users/student-1'), { role: 'admin' }));
});

test('client cannot create an active paid-course enrollment', async () => {
  await seed({
    'courses/paid-course': { status: 'published', instructorId: 'instructor-1', price: 990 },
  });
  await assertFails(setDoc(doc(learner(), 'enrollments/student-1_paid-course'), {
    studentId: 'student-1',
    courseId: 'paid-course',
    status: 'active',
    enrolledAt: new Date(),
  }));
});

test('learner may enroll in a published free course', async () => {
  await seed({
    'courses/free-enrollment': { status: 'published', instructorId: 'instructor-1', price: 0 },
  });
  await assertSucceeds(setDoc(doc(learner(), 'enrollments/student-1_free-enrollment'), {
    studentId: 'student-1',
    courseId: 'free-enrollment',
    status: 'active',
    enrolledAt: new Date(),
  }));
});

test('learner progress requires own UID and active enrollment', async () => {
  await seed({
    'courses/free-course': { status: 'published', instructorId: 'instructor-1', price: 0 },
    'enrollments/student-1_free-course': {
      studentId: 'student-1', courseId: 'free-course', status: 'active',
    },
  });
  await assertSucceeds(setDoc(doc(learner(), 'users/student-1/progress/lesson-1'), {
    lessonId: 'lesson-1',
    courseId: 'free-course',
    completed: false,
    percentComplete: 35,
    updatedAt: new Date(),
  }));
  await assertFails(getDoc(doc(learner('student-2'), 'users/student-1/progress/lesson-1')));
});

test('payment can start pending but client cannot set terminal success', async () => {
  const db = learner();
  const payment = doc(db, 'payment_mock/payment-1');
  await assertSucceeds(setDoc(payment, {
    studentId: 'student-1',
    courseId: 'paid-course',
    amount: 990,
    currency: 'THB',
    status: 'pending',
    createdAt: new Date(),
  }));
  await assertFails(updateDoc(payment, { status: 'success' }));
});

test('filtered course listing does not expose private courses', async () => {
  await seed({
    'courses/published-2': { status: 'published', instructorId: 'instructor-2' },
    'courses/draft-2': { status: 'draft', instructorId: 'instructor-2' },
  });
  const results = await assertSucceeds(getDocs(query(
    collection(learner(), 'courses'),
    where('status', '==', 'published'),
  )));
  assert.equal(results.docs.every((result) => result.data().status === 'published'), true);
});

const enrolledSeed = {
  'courses/c1': { status: 'published', instructorId: 'instructor-1', price: 0 },
  'enrollments/student-1_c1': { studentId: 'student-1', courseId: 'c1', status: 'active' },
  'users/student-1': { uid: 'student-1', displayName: 'Student One', role: 'learner', status: 'active' },
};

test('quiz questions need enrollment; answer keys and attempts are never client writable', async () => {
  await seed({
    ...enrolledSeed,
    'quizzes/quiz-1': { courseId: 'c1', questions: [{ id: 'q1', text: 'Q', options: ['a', 'b'] }] },
    'quiz_answers/quiz-1': { answers: { q1: 0 } },
  });
  await assertSucceeds(getDoc(doc(learner(), 'quizzes/quiz-1')));
  await assertFails(getDoc(doc(learner('student-2'), 'quizzes/quiz-1')));
  await assertFails(getDoc(doc(learner(), 'quiz_answers/quiz-1')));
  await assertFails(getDoc(doc(instructor(), 'quiz_answers/quiz-1')));
  await assertFails(setDoc(doc(learner(), 'quizzes/quiz-2'), { courseId: 'c1' }));
  await assertFails(setDoc(doc(learner(), 'quiz_attempts/a1'), {
    studentId: 'student-1', courseId: 'c1', quizId: 'quiz-1', scorePercent: 100, passed: true,
  }));
});

test('quiz attempts are readable only by their owner', async () => {
  await seed({ 'quiz_attempts/a2': { studentId: 'student-1', courseId: 'c1', passed: true } });
  await assertSucceeds(getDoc(doc(learner(), 'quiz_attempts/a2')));
  await assertFails(getDoc(doc(learner('student-2'), 'quiz_attempts/a2')));
});

test('certificates cannot be forged; verification is get-only by code', async () => {
  await seed({
    'certificates/student-1_c1': { studentId: 'student-1', courseId: 'c1', verificationCode: 'AB-1' },
    'certificate_verifications/AB-1': { courseTitle: 'Course', learnerName: 'Student One' },
  });
  await assertFails(setDoc(doc(learner(), 'certificates/student-1_c2'), { studentId: 'student-1', courseId: 'c2' }));
  await assertFails(getDoc(doc(learner('student-2'), 'certificates/student-1_c1')));
  await assertSucceeds(getDoc(doc(environment.unauthenticatedContext().firestore(), 'certificate_verifications/AB-1')));
  await assertFails(getDocs(collection(environment.unauthenticatedContext().firestore(), 'certificate_verifications')));
  await assertFails(setDoc(doc(learner(), 'certificate_verifications/AB-2'), { courseTitle: 'x', learnerName: 'y' }));
});

test('reviews: enrolled learner, one per course, own name, rating 1-5', async () => {
  await seed(enrolledSeed);
  const review = {
    studentId: 'student-1', studentName: 'Student One', courseId: 'c1',
    rating: 5, comment: 'Great', createdAt: new Date(),
  };
  await assertFails(setDoc(doc(learner(), 'course_reviews/wrong-id'), review));
  await assertFails(setDoc(doc(learner(), 'course_reviews/student-1_c1'), { ...review, rating: 6 }));
  await assertFails(setDoc(doc(learner(), 'course_reviews/student-1_c1'), { ...review, studentName: 'Someone Else' }));
  await assertFails(setDoc(doc(learner('student-2'), 'course_reviews/student-2_c1'), { ...review, studentId: 'student-2' }));
  await assertSucceeds(setDoc(doc(learner(), 'course_reviews/student-1_c1'), review));
  await assertFails(updateDoc(doc(learner(), 'course_reviews/student-1_c1'), { rating: 1 }));
});

test('notifications: owner reads and may only flip read; cannot create', async () => {
  await seed({ 'users/student-1/notifications/n1': { title: 'Hi', message: 'm', read: false } });
  await assertSucceeds(getDoc(doc(learner(), 'users/student-1/notifications/n1')));
  await assertFails(getDoc(doc(learner('student-2'), 'users/student-1/notifications/n1')));
  await assertSucceeds(updateDoc(doc(learner(), 'users/student-1/notifications/n1'), { read: true }));
  await assertFails(updateDoc(doc(learner(), 'users/student-1/notifications/n1'), { title: 'Edited' }));
  await assertFails(setDoc(doc(learner(), 'users/student-1/notifications/n2'), { title: 'x', message: 'y', read: false }));
});

test('sales and payouts are visible only to the owning instructor and never client writable', async () => {
  await seed({
    'sales/s1': { instructorId: 'instructor-1', amount: 990 },
    'payouts/p1': { instructorId: 'instructor-1', amount: 1000, status: 'pending' },
  });
  await assertSucceeds(getDoc(doc(instructor(), 'sales/s1')));
  await assertSucceeds(getDoc(doc(instructor(), 'payouts/p1')));
  await assertFails(getDoc(doc(instructor('instructor-2'), 'sales/s1')));
  await assertFails(getDoc(doc(learner(), 'payouts/p1')));
  await assertFails(setDoc(doc(instructor(), 'payouts/p2'), { instructorId: 'instructor-1', amount: 999999, status: 'paid' }));
  await assertFails(updateDoc(doc(instructor(), 'payouts/p1'), { status: 'paid' }));
  await assertFails(getDoc(doc(admin(), 'platform_config/revenue')));
});

const orgSeed = {
  'organizations/org1': { name: 'Acme', ownerUid: 'corp-admin' },
  'org_members/org1_corp-admin': { orgId: 'org1', uid: 'corp-admin', role: 'admin', status: 'active', email: 'a@acme.co' },
  'org_members/org1_mgr': { orgId: 'org1', uid: 'mgr', role: 'manager', status: 'active', email: 'm@acme.co' },
  'org_members/org1_emp': { orgId: 'org1', uid: 'emp', role: 'member', status: 'active', email: 'e@acme.co' },
  'org_members/org2_other': { orgId: 'org2', uid: 'other', role: 'admin', status: 'active', email: 'o@other.co' },
};
const asUser = (uid, role) => environment.authenticatedContext(uid, { role }).firestore();

test('org members: staff read their org only; only org admin may suspend members', async () => {
  await seed(orgSeed);
  await assertSucceeds(getDoc(doc(asUser('mgr', 'corporate_manager'), 'org_members/org1_emp')));
  await assertFails(getDoc(doc(asUser('emp', 'learner'), 'org_members/org1_mgr')));
  await assertFails(getDoc(doc(asUser('other', 'corporate_admin'), 'org_members/org1_emp')));
  await assertSucceeds(updateDoc(doc(asUser('corp-admin', 'corporate_admin'), 'org_members/org1_emp'), { status: 'suspended' }));
  await assertFails(updateDoc(doc(asUser('mgr', 'corporate_manager'), 'org_members/org1_emp'), { status: 'suspended' }));
  await assertFails(updateDoc(doc(asUser('corp-admin', 'corporate_admin'), 'org_members/org1_emp'), { role: 'admin' }));
  await assertFails(setDoc(doc(asUser('corp-admin', 'corporate_admin'), 'org_members/org1_new'), { orgId: 'org1', uid: 'new', role: 'admin', status: 'active' }));
});

test('learning paths: org admin writes inside own org; members read; outsiders denied', async () => {
  await seed({ ...orgSeed, 'learning_paths/p1': { orgId: 'org1', title: 'Data', status: 'active' } });
  const path = { orgId: 'org1', title: 'Leadership', description: 'd', status: 'draft', createdBy: 'corp-admin', createdAt: new Date() };
  await assertSucceeds(setDoc(doc(asUser('corp-admin', 'corporate_admin'), 'learning_paths/p2'), path));
  await assertFails(setDoc(doc(asUser('corp-admin', 'corporate_admin'), 'learning_paths/p3'), { ...path, orgId: 'org2' }));
  await assertFails(setDoc(doc(asUser('mgr', 'corporate_manager'), 'learning_paths/p4'), path));
  await assertSucceeds(getDoc(doc(asUser('emp', 'learner'), 'learning_paths/p1')));
  await assertFails(getDoc(doc(asUser('other', 'corporate_admin'), 'learning_paths/p1')));
  await assertFails(updateDoc(doc(asUser('corp-admin', 'corporate_admin'), 'learning_paths/p1'), { orgId: 'org2' }));
});

test('job postings and applications respect employer ownership', async () => {
  await seed({
    'users/cand-1': { uid: 'cand-1', displayName: 'Candidate', role: 'learner', status: 'active' },
    'job_postings/j1': { employerId: 'emp-1', title: 'QA', location: 'BKK', status: 'open' },
    'job_postings/j2': { employerId: 'emp-1', title: 'Closed', location: 'BKK', status: 'closed' },
  });
  const employer = asUser('emp-1', 'employer');
  await assertSucceeds(setDoc(doc(employer, 'job_postings/j3'), { employerId: 'emp-1', title: 'Dev', location: 'Remote', status: 'open', createdAt: new Date() }));
  await assertFails(setDoc(doc(asUser('cand-1', 'learner'), 'job_postings/j4'), { employerId: 'cand-1', title: 'x', location: 'y', status: 'open', createdAt: new Date() }));
  await assertSucceeds(getDoc(doc(environment.unauthenticatedContext().firestore(), 'job_postings/j1')));
  await assertFails(getDoc(doc(asUser('cand-1', 'learner'), 'job_postings/j2')));

  const application = { jobId: 'j1', employerId: 'emp-1', candidateId: 'cand-1', candidateName: 'Candidate', status: 'new', createdAt: new Date() };
  await assertSucceeds(setDoc(doc(asUser('cand-1', 'learner'), 'job_applications/j1_cand-1'), application));
  await assertFails(setDoc(doc(asUser('cand-1', 'learner'), 'job_applications/j2_cand-1'), { ...application, jobId: 'j2' }));
  await assertFails(setDoc(doc(asUser('cand-1', 'learner'), 'job_applications/j1_cand-1'), { ...application, employerId: 'someone-else' }));
  await assertSucceeds(updateDoc(doc(employer, 'job_applications/j1_cand-1'), { status: 'interview' }));
  await assertFails(updateDoc(doc(asUser('emp-2', 'employer'), 'job_applications/j1_cand-1'), { status: 'offer' }));
  await assertFails(updateDoc(doc(asUser('cand-1', 'learner'), 'job_applications/j1_cand-1'), { status: 'offer' }));
});

test('admins can list users; learners cannot', async () => {
  await seed({ 'users/student-1': { uid: 'student-1', role: 'learner', status: 'active' } });
  await assertSucceeds(getDocs(collection(admin(), 'users')));
  await assertFails(getDocs(collection(learner(), 'users')));
});

test('job board: open postings can be listed by query; duplicate applications are blocked by id', async () => {
  await environment.clearFirestore(); // earlier tests leave open postings behind
  await seed({
    'users/cand-2': { uid: 'cand-2', displayName: 'Cand Two', role: 'learner', status: 'active' },
    'job_postings/open1': { employerId: 'emp-1', title: 'A', location: 'BKK', status: 'open', createdAt: new Date() },
    'job_postings/closed1': { employerId: 'emp-1', title: 'B', location: 'BKK', status: 'closed', createdAt: new Date() },
  });
  const db = asUser('cand-2', 'learner');
  const open = await getDocs(query(collection(db, 'job_postings'), where('status', '==', 'open')));
  if (open.size !== 1) throw new Error('expected one open posting');
  await assertFails(getDocs(collection(db, 'job_postings'))); // unfiltered listing exposes closed posts
  await assertFails(setDoc(doc(db, 'job_applications/open1_someone-else'), {
    jobId: 'open1', employerId: 'emp-1', candidateId: 'cand-2', candidateName: 'Cand Two', status: 'new', createdAt: new Date(),
  }));
});
