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
