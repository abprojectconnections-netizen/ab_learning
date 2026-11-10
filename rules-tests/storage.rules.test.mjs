import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { getBytes, ref, uploadBytes } from 'firebase/storage';

// Storage rules read course ownership from Firestore, so both emulators run.
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-ab-learning',
    firestore: {
      host: '127.0.0.1',
      port: 8180,
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
    storage: {
      host: '127.0.0.1',
      port: 9199,
      rules: await readFile(new URL('../storage.rules', import.meta.url), 'utf8'),
    },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'courses/c1'), { instructorId: 'instructor-1', status: 'draft' });
  });
});

after(async () => environment?.cleanup());

const bytes = new Uint8Array([1, 2, 3]);
const video = { contentType: 'video/mp4' };
const storageFor = (uid) => environment.authenticatedContext(uid, { role: 'instructor' }).storage();

test('only the course owner can upload lesson videos, and only video files', async () => {
  await assertSucceeds(uploadBytes(ref(storageFor('instructor-1'), 'lesson_videos/c1/l1'), bytes, video));
  await assertFails(uploadBytes(ref(storageFor('instructor-2'), 'lesson_videos/c1/l1'), bytes, video));
  await assertFails(uploadBytes(ref(storageFor('instructor-1'), 'lesson_videos/c1/l2'), bytes, { contentType: 'text/html' }));
  await assertFails(uploadBytes(ref(environment.unauthenticatedContext().storage(), 'lesson_videos/c1/l1'), bytes, video));
});

test('lesson videos are never directly readable by clients', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), 'lesson_videos/c1/secret'), bytes, video);
  });
  await assertFails(getBytes(ref(storageFor('instructor-1'), 'lesson_videos/c1/secret')));
});

test('avatars: public read, owner-only image writes', async () => {
  const image = { contentType: 'image/png' };
  await assertSucceeds(uploadBytes(ref(storageFor('user-1'), 'avatars/user-1'), bytes, image));
  await assertFails(uploadBytes(ref(storageFor('user-2'), 'avatars/user-1'), bytes, image));
  await assertFails(uploadBytes(ref(storageFor('user-1'), 'avatars/user-1'), bytes, { contentType: 'video/mp4' }));
  await assertSucceeds(getBytes(ref(environment.unauthenticatedContext().storage(), 'avatars/user-1')));
});

test('unknown storage paths are denied', async () => {
  await assertFails(uploadBytes(ref(storageFor('user-1'), 'misc/file'), bytes, { contentType: 'image/png' }));
  assert.ok(true);
});
