const { initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

async function main() {
  const projectId = process.env.GCLOUD_PROJECT || '';
  const isEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (!isEmulator && !/(^|-)dev($|-)/i.test(projectId)) {
    throw new Error('Seed data is restricted to Firestore Emulator or a DEV project ID ending in -dev.');
  }
  initializeApp({ projectId });
  const db = getFirestore();

  const categories = [
    { id: 'cat-it', name: 'IT & Software', sortOrder: 1, active: true },
    { id: 'cat-design', name: 'Design', sortOrder: 2, active: true },
    { id: 'cat-marketing', name: 'Marketing', sortOrder: 3, active: true },
  ];
  for (const category of categories) {
    const ref = db.collection('categories').doc(category.id);
    if (!(await ref.get()).exists) {
      const { id, ...data } = category;
      await ref.set(data);
    }
  }

  const courses = [
    {
      id: 'dev-flutter-basics',
      title: 'Flutter พื้นฐาน',
      description: 'เรียนรู้การสร้างแอป Flutter ตั้งแต่เริ่มต้น',
      categoryId: 'cat-it',
      price: 0,
    },
    {
      id: 'dev-ui-design',
      title: 'ออกแบบ UI สำหรับแอป',
      description: 'หลักการออกแบบหน้าจอที่ใช้งานง่ายและเข้าถึงได้',
      categoryId: 'cat-design',
      price: 990,
    },
  ];

  for (const course of courses) {
    const courseRef = db.collection('courses').doc(course.id);
    if ((await courseRef.get()).exists) continue;
    const { id, ...courseData } = course;
    await courseRef.set({
      ...courseData,
      instructorId: 'dev-seed-instructor',
      instructorName: 'AB Learning Instructor',
      thumbnailUrl: '',
      status: 'published',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    const sectionRef = courseRef.collection('sections').doc('section-1');
    await sectionRef.set({ title: 'เริ่มต้น', order: 1, createdAt: FieldValue.serverTimestamp() });
    await courseRef.collection('lessons').doc('lesson-1').set({
      sectionId: sectionRef.id,
      title: 'แนะนำคอร์ส',
      durationSeconds: 0,
      order: 1,
      isPreview: true,
      videoProvider: 'mock',
      videoReference: 'demo-video',
    });
    await courseRef.collection('lessons').doc('lesson-2').set({
      sectionId: sectionRef.id,
      title: 'บทเรียนแรก',
      durationSeconds: 0,
      order: 2,
      isPreview: false,
      videoProvider: 'mock',
      videoReference: 'demo-video',
    });
  }
  process.stdout.write('Seeded DEV categories and sample published courses.\n');
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
