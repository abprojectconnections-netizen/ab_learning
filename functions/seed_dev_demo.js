// Fills the Auth + Firestore EMULATORS with 20-30 realistic records for every
// menu so the whole app can be tested. Deterministic IDs: safe to re-run.
// Accounts use a public demo password, so this never runs against a real project.
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');

const PASSWORD = 'Demo#12345';
const ORG_ID = 'demo-org';
const pad = (n) => String(n).padStart(2, '0');
const daysAgo = (d) => Timestamp.fromMillis(Date.now() - d * 86400000);

const THAI_NAMES = ['สมชาย ใจดี', 'สมหญิง รักเรียน', 'วิชัย มั่นคง', 'นภา สดใส', 'ธนากร เจริญ', 'พิมพ์ชนก งามตา', 'กิตติ ศรีสุข', 'อรทัย พูนสุข', 'ปิยะ ทองดี', 'ณัฐวุฒิ แก้วมณี', 'ชลธิชา บุญมา', 'ภาณุ วงศ์ไทย', 'รัตนา สุขใจ', 'อนุชา พรหมมา', 'จิราพร ศรีสวัสดิ์', 'ศุภชัย เพชรดี', 'มาลี ดอกไม้', 'สุรเชษฐ์ คงทน', 'กนกวรรณ ทิพย์มณี', 'เอกชัย รุ่งเรือง', 'ลลิตา สายสุข', 'ประเสริฐ ยอดเยี่ยม', 'วรรณา แสงจันทร์', 'ธีรพงษ์ ใจเย็น', 'ขวัญใจ มีสุข'];
const CATEGORY_NAMES = ['IT & Software', 'Design', 'Marketing', 'Business', 'Finance', 'Languages', 'Data Science', 'Mobile Development', 'Web Development', 'Cloud & DevOps', 'Cybersecurity', 'Photography', 'Video Production', 'Music', 'Health & Wellness', 'Leadership', 'Project Management', 'Sales', 'Customer Service', 'Personal Development'];
const COURSE_TITLES = ['Flutter พื้นฐานถึงใช้งานจริง', 'ออกแบบ UI/UX สำหรับมือใหม่', 'การตลาดออนไลน์ยุคใหม่', 'Python สำหรับวิเคราะห์ข้อมูล', 'Firebase สำหรับนักพัฒนา', 'ภาษาอังกฤษเพื่อการทำงาน', 'การเงินส่วนบุคคล', 'JavaScript ฉบับสมบูรณ์', 'React สำหรับเว็บแอป', 'Docker และ Kubernetes เบื้องต้น', 'ความปลอดภัยทางไซเบอร์เบื้องต้น', 'ถ่ายภาพด้วยมือถือ', 'ตัดต่อวิดีโอมืออาชีพ', 'ทฤษฎีดนตรีเบื้องต้น', 'โยคะเพื่อสุขภาพ', 'ภาวะผู้นำในองค์กร', 'บริหารโครงการด้วย Agile', 'เทคนิคการขายเชิงที่ปรึกษา', 'งานบริการลูกค้าระดับพรีเมียม', 'บริหารเวลาและเป้าหมาย', 'SQL และการออกแบบฐานข้อมูล', 'Machine Learning เบื้องต้น', 'Figma สำหรับนักออกแบบ', 'SEO และการทำคอนเทนต์', 'การนำเสนองานอย่างมั่นใจ'];
const PRICES = [0, 490, 990, 1290, 1490, 1990, 2490, 2990];
const JOB_TITLES = ['Flutter Developer', 'UI/UX Designer', 'Digital Marketing Specialist', 'Data Analyst', 'Backend Engineer', 'QA Engineer', 'Product Manager', 'DevOps Engineer', 'Content Creator', 'Customer Success Manager'];
const LOCATIONS = ['กรุงเทพฯ', 'เชียงใหม่', 'ขอนแก่น', 'ภูเก็ต', 'Remote'];
const COMMENTS = ['เนื้อหาเข้าใจง่าย นำไปใช้ได้จริง', 'ผู้สอนอธิบายดีมาก', 'คุ้มค่ากับราคา', 'อยากให้มีแบบฝึกหัดเพิ่ม', 'เหมาะกับมือใหม่', 'ตัวอย่างครบถ้วน', 'สอนเป็นขั้นตอนชัดเจน'];

async function ensureUser(auth, db, { email, name, role }) {
  const existing = await auth.getUserByEmail(email).catch(() => null);
  const user = existing
    ? await auth.updateUser(existing.uid, { password: PASSWORD, displayName: name })
    : await auth.createUser({ email, password: PASSWORD, displayName: name, emailVerified: true });
  await auth.setCustomUserClaims(user.uid, { role });
  await db.collection('users').doc(user.uid).set({
    uid: user.uid, email, displayName: name, role, status: 'active',
    createdAt: daysAgo(90), updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return user.uid;
}

async function commitAll(db, writes) {
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    for (const [ref, data] of writes.slice(i, i + 400)) batch.set(ref, data, { merge: true });
    await batch.commit();
  }
}

async function main() {
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Demo data is only created in the Auth and Firestore emulators. Set FIREBASE_AUTH_EMULATOR_HOST and FIRESTORE_EMULATOR_HOST.');
  }
  initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-ab-learning' });
  const auth = getAuth();
  const db = getFirestore();
  const w = []; // [ref, data]
  const add = (path, data) => w.push([db.doc(path), data]);

  // ---- Users -------------------------------------------------------------
  const instructors = [];
  for (let i = 1; i <= 5; i++) {
    instructors.push(await ensureUser(auth, db, { email: i === 1 ? 'instructor@demo.test' : `instructor${pad(i)}@demo.test`, name: `ผู้สอน ${i}`, role: 'instructor' }));
  }
  const employers = [];
  for (let i = 1; i <= 3; i++) {
    employers.push(await ensureUser(auth, db, { email: i === 1 ? 'employer@demo.test' : `employer${pad(i)}@demo.test`, name: `ผู้ว่าจ้าง ${i}`, role: 'employer' }));
  }
  const learners = [];
  for (let i = 1; i <= 25; i++) {
    learners.push({ uid: await ensureUser(auth, db, { email: `learner${pad(i)}@demo.test`, name: THAI_NAMES[i - 1], role: 'learner' }), name: THAI_NAMES[i - 1] });
  }
  const demoLearner = await ensureUser(auth, db, { email: 'learner@demo.test', name: 'Demo Learner', role: 'learner' });
  const corpAdmin = await ensureUser(auth, db, { email: 'corpadmin@demo.test', name: 'Demo Corporate Admin', role: 'corporate_admin' });
  const adminUid = await ensureUser(auth, db, { email: 'admin@demo.test', name: 'Demo Admin', role: 'admin' });
  const superUid = await ensureUser(auth, db, { email: 'superadmin@demo.test', name: 'Demo Super Admin', role: 'super_admin' });

  // ---- Categories (20) ---------------------------------------------------
  CATEGORY_NAMES.forEach((name, i) => add(`categories/demo-cat-${pad(i + 1)}`, { name, sortOrder: i + 1, active: true }));

  // ---- Courses (25 published + 3 pending review + 2 draft), sections, lessons, quizzes
  const courses = COURSE_TITLES.map((title, i) => {
    const n = i + 1;
    return {
      id: `demo-course-${pad(n)}`, title, price: PRICES[i % PRICES.length],
      categoryId: `demo-cat-${pad((i % CATEGORY_NAMES.length) + 1)}`,
      instructorId: instructors[i % instructors.length], instructorName: `ผู้สอน ${(i % instructors.length) + 1}`,
    };
  });
  courses.forEach((c, i) => {
    add(`courses/${c.id}`, {
      title: c.title, description: `${c.title} — เนื้อหาครบพร้อมตัวอย่างและแบบฝึกหัด`, categoryId: c.categoryId, price: c.price,
      instructorId: c.instructorId, instructorName: c.instructorName, thumbnailUrl: '', status: 'published',
      createdAt: daysAgo(80 - i), updatedAt: daysAgo(30),
    });
    for (let s = 1; s <= 2; s++) add(`courses/${c.id}/sections/section-${s}`, { title: s === 1 ? 'เริ่มต้น' : 'ต่อยอด', order: s, createdAt: daysAgo(80 - i) });
    for (let l = 1; l <= 3; l++) {
      add(`courses/${c.id}/lessons/lesson-${l}`, {
        sectionId: l === 3 ? 'section-2' : 'section-1', title: `บทเรียนที่ ${l}`, durationSeconds: 600 + l * 120,
        order: l, isPreview: l === 1, videoProvider: 'mock', videoReference: 'demo-video',
      });
    }
    add(`quizzes/demo-quiz-${pad(i + 1)}`, {
      courseId: c.id, lectureId: 'lesson-3', title: `แบบทดสอบ ${c.title}`, passThresholdPercent: 70,
      questions: [
        { id: 'q1', text: 'ข้อใดถูกต้อง?', options: ['ตัวเลือก ก', 'ตัวเลือก ข', 'ตัวเลือก ค', 'ตัวเลือก ง'] },
        { id: 'q2', text: 'เลือกคำตอบที่เหมาะสมที่สุด', options: ['ข้อ 1', 'ข้อ 2', 'ข้อ 3'] },
      ],
      createdAt: daysAgo(79 - i),
    });
    add(`quiz_answers/demo-quiz-${pad(i + 1)}`, { answers: { q1: 0, q2: 1 } });
  });
  [['pending_review', 26], ['pending_review', 27], ['pending_review', 28], ['draft', 29], ['draft', 30]].forEach(([status, n], k) => {
    add(`courses/demo-course-${pad(n)}`, {
      title: `คอร์สรอตรวจสอบ ${n}`, description: 'คอร์สสำหรับทดสอบขั้นตอนตรวจสอบ', categoryId: 'demo-cat-01', price: 990,
      instructorId: instructors[k % instructors.length], instructorName: `ผู้สอน ${(k % instructors.length) + 1}`,
      thumbnailUrl: '', status, createdAt: daysAgo(5 + k), updatedAt: daysAgo(2),
    });
    add(`courses/demo-course-${pad(n)}/sections/section-1`, { title: 'เริ่มต้น', order: 1, createdAt: daysAgo(5) });
    add(`courses/demo-course-${pad(n)}/lessons/lesson-1`, { sectionId: 'section-1', title: 'แนะนำ', durationSeconds: 300, order: 1, isPreview: true, videoProvider: 'mock', videoReference: 'demo-video' });
  });

  // ---- Purchases (25): payment + sale + enrollment; 20 completed with certificate
  const paid = courses.filter((c) => c.price > 0);
  const purchases = learners.map((learner, k) => ({ learner, course: paid[(k * 5 + 3) % paid.length], k }));
  purchases.forEach(({ learner, course, k }) => {
    const txn = `demo-txn-${pad(k + 1)}`;
    const when = daysAgo(60 - k * 2);
    add(`payment_mock/${txn}`, { studentId: learner.uid, courseId: course.id, amount: course.price, currency: 'THB', status: 'success', provider: 'demo', createdAt: when, paidAt: when });
    add(`sales/${txn}`, { instructorId: course.instructorId, courseId: course.id, courseTitle: course.title, buyerName: learner.name, amount: course.price, currency: 'THB', status: 'paid', createdAt: when });
    add(`enrollments/${learner.uid}_${course.id}`, { studentId: learner.uid, courseId: course.id, status: 'active', enrolledAt: when });
    const done = k < 20;
    for (let l = 1; l <= 3; l++) {
      if (!done && l > 1) continue;
      add(`users/${learner.uid}/progress/lesson-${l}`, { lessonId: `lesson-${l}`, courseId: course.id, completed: done || l === 1, lastPositionSeconds: 300, updatedAt: when });
    }
    if (done) {
      const quizId = `demo-quiz-${course.id.slice(-2)}`;
      add(`quiz_attempts/demo-attempt-${pad(k + 1)}`, { studentId: learner.uid, courseId: course.id, quizId, scorePercent: 100, passed: true, createdAt: when });
      const code = `DEMO-${pad(k + 1)}-${course.id.slice(-2)}`;
      add(`certificates/${learner.uid}_${course.id}`, { studentId: learner.uid, learnerName: learner.name, courseId: course.id, courseTitle: course.title, verificationCode: code, issuedAt: when });
      add(`certificate_verifications/${code}`, { courseTitle: course.title, learnerName: learner.name, issuedAt: when });
    }
    add(`course_reviews/${learner.uid}_${course.id}`, { studentId: learner.uid, studentName: learner.name, courseId: course.id, rating: 3 + (k % 3), comment: COMMENTS[k % COMMENTS.length], createdAt: when });
  });
  // free enrollments: every learner also takes a free course
  const free = courses.filter((c) => c.price === 0);
  learners.forEach((learner, k) => {
    const c = free[k % free.length];
    add(`enrollments/${learner.uid}_${c.id}`, { studentId: learner.uid, courseId: c.id, status: 'active', enrolledAt: daysAgo(40 - k) });
  });

  // ---- Payouts (20) ---------------------------------------------------------
  for (let i = 0; i < 20; i++) {
    add(`payouts/demo-payout-${pad(i + 1)}`, { instructorId: instructors[i % instructors.length], amount: 100 + (i % 4) * 50, status: i % 3 === 0 ? 'paid' : 'pending', requestedAt: daysAgo(30 - i) });
  }

  // ---- Notifications (25 for the demo learner, 5 for admin) ------------------
  for (let i = 1; i <= 25; i++) {
    add(`users/${demoLearner}/notifications/demo-n-${pad(i)}`, { title: i % 2 ? 'ได้รับใบประกาศนียบัตร' : 'มีคอร์สใหม่แนะนำ', message: `ข้อความแจ้งเตือนทดสอบ #${i}`, read: i > 10, createdAt: daysAgo(i) });
  }

  // ---- Jobs (25) + applications (30) ---------------------------------------------
  for (let i = 1; i <= 25; i++) {
    add(`job_postings/demo-job-${pad(i)}`, {
      employerId: employers[i % employers.length], title: `${JOB_TITLES[i % JOB_TITLES.length]} #${i}`,
      location: LOCATIONS[i % LOCATIONS.length], status: i % 6 === 0 ? 'closed' : 'open', createdAt: daysAgo(40 - i),
    });
  }
  const statuses = ['new', 'screened', 'interview', 'offer', 'rejected'];
  for (let i = 0; i < 30; i++) {
    const jobNo = (i % 20) + 1; // open postings only (no multiples of 6 -> use i%… check below)
    const job = jobNo % 6 === 0 ? jobNo + 1 : jobNo;
    const learner = learners[i % learners.length];
    add(`job_applications/demo-job-${pad(job)}_${learner.uid}`, {
      jobId: `demo-job-${pad(job)}`, employerId: employers[job % employers.length], candidateId: learner.uid,
      candidateName: learner.name, status: statuses[i % statuses.length], createdAt: daysAgo(20 - (i % 15)),
    });
  }

  // ---- Corporate: org, 25 members, 20 learning paths ----------------------------------
  add(`organizations/${ORG_ID}`, { name: 'Demo Company', ownerUid: corpAdmin, createdAt: daysAgo(90) });
  learners.forEach((l, i) => {
    add(`org_members/${ORG_ID}_${l.uid}`, { orgId: ORG_ID, uid: l.uid, email: `learner${pad(i + 1)}@demo.test`, displayName: l.name, role: 'member', status: i % 8 === 7 ? 'inactive' : 'active', createdAt: daysAgo(60 - i) });
  });
  for (let i = 1; i <= 20; i++) {
    add(`learning_paths/demo-path-${pad(i)}`, { orgId: ORG_ID, title: `เส้นทางการเรียนรู้ ${i}`, description: `หลักสูตรพัฒนาทักษะพนักงาน ชุดที่ ${i}`, status: i % 4 === 0 ? 'draft' : 'active', createdBy: corpAdmin, createdAt: daysAgo(50 - i) });
  }

  // ---- Admin: instructor applications (20) and audit log (20) ----------------------------
  for (let i = 5; i < 25; i++) {
    add(`instructor_applications/${learners[i].uid}`, { uid: learners[i].uid, displayName: learners[i].name, experience: `มีประสบการณ์ด้านการสอนและการทำงานจริงมากกว่า ${i} ปี พร้อมถ่ายทอดความรู้`, status: i % 5 === 0 ? 'rejected' : 'pending', createdAt: daysAgo(i) });
  }
  for (let i = 1; i <= 20; i++) {
    add(`audit_logs/demo-audit-${pad(i)}`, { actorUid: i % 2 ? adminUid : superUid, action: i % 2 ? 'course_approved' : 'user_status_changed', targetType: i % 2 ? 'course' : 'user', targetId: `demo-${i}`, createdAt: daysAgo(i) });
  }

  add('platform_config/revenue', { instructorShare: 0.7, minPayout: 1000 });

  await commitAll(db, w);
  const counts = {};
  for (const [ref] of w) { const c = ref.path.split('/')[0]; counts[c] = (counts[c] || 0) + 1; }
  process.stdout.write(`Seeded demo data. Documents per collection:\n${JSON.stringify(counts, null, 1)}\nPassword for all accounts: ${PASSWORD}\n`);
}

main().catch((e) => { process.stderr.write(`${e.stack || e.message}\n`); process.exitCode = 1; });
