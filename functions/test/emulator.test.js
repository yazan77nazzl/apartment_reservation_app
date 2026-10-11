'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, createUserWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, connectFirestoreEmulator, doc, setDoc, getDoc } = require('firebase/firestore');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');
const { getStorage, ref: storageRef, uploadBytes } = require('firebase/storage');
const projectId = 'demo-apartment-reservation';
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Run using firebase emulators:exec --project demo-apartment-reservation. Never run against production.');
let env, owner, student, other, apartmentId, roomId;
const apps = [];
async function client(role, index) {
  const app = initializeApp({ projectId, apiKey: 'demo-emulator-only', appId: 'demo', storageBucket: `${projectId}.appspot.com` }, `test-${index}-${Date.now()}`); apps.push(app);
  const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = getFirestore(app); connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const functions = getFunctions(app); connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  const account = await createUserWithEmailAndPassword(auth, `test-${index}-${Date.now()}@example.test`, 'TestingOnly!2026');
  const c = { uid: account.user.uid, db, call: async (name, data) => (await httpsCallable(functions, name)(data)).data };
  await c.call('registerProfile', { firstName: 'Fictional', lastName: `Test ${index}`, address: 'Fictional Jenin', phone: '0590000000', gender: 'female', role }); return c;
}
before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firebase/firestore.rules'), 'utf8') }, storage: { host: '127.0.0.1', port: 9199, rules: fs.readFileSync(path.join(__dirname, '../../firebase/storage.rules'), 'utf8') } });
  owner = await client('owner', 1); student = await client('student', 2); other = await client('student', 3);
}, { timeout: 120000 });
after(async () => { await Promise.all(apps.map(deleteApp)); await env?.cleanup(); });
test('callable workflow and concurrent approvals', { timeout: 120000 }, async t => {
  await t.test('owner-only apartment creation and room validation', async () => {
    const apartment = { title: 'Fictional test residence', description: 'Emulator test', location: 'Jenin', gender: 'female', housingType: 'residence', images: [] };
    await assert.rejects(student.call('saveApartment', apartment));
    apartmentId = (await owner.call('saveApartment', apartment)).id;
    await assert.rejects(owner.call('saveRoom', { apartmentId, number: '101', floor: 1, beds: 0, priceMinor: 45000, description: 'Test', available: true }));
    roomId = (await owner.call('saveRoom', { apartmentId, number: '101', floor: 1, beds: 2, priceMinor: 45000, description: 'Test', available: true })).id;
    await assert.rejects(student.call('saveRoom', { apartmentId, number: '102', floor: 1, beds: 2, priceMinor: 45000, description: 'Test', available: true }));
  });
  let first, second, winner, winnerClient;
  const start = new Date(Date.now() + 5 * 86400000).toISOString().slice(0, 10), end = new Date(Date.now() + 35 * 86400000).toISOString().slice(0, 10);
  await t.test('requests enforce authorization; only one overlapping approval wins', async () => {
    first = (await student.call('submitReservation', { roomId, start, end })).id;
    second = (await other.call('submitReservation', { roomId, start, end })).id;
    await assert.rejects(student.call('decideReservation', { id: first, action: 'approve' }));
    const result = await Promise.allSettled([owner.call('decideReservation', { id: first, action: 'approve' }), owner.call('decideReservation', { id: second, action: 'approve' })]);
    assert.equal(result.filter(r => r.status === 'fulfilled').length, 1);
    const index = result.findIndex(r => r.status === 'fulfilled'); winner = index === 0 ? first : second; winnerClient = index === 0 ? student : other;
    await owner.call('decideReservation', { id: index === 0 ? second : first, action: 'reject' });
    await assert.rejects(student.call('submitReservation', { roomId, start, end }));
  });
  await t.test('client cannot forge payment; decline retry and idempotent success', async () => {
    await assertFails(setDoc(doc(winnerClient.db, 'payments', winner), { status: 'succeeded' }));
    const decline = await winnerClient.call('demoPayment', { id: winner, outcome: 'decline' }); assert.equal(decline.status, 'failed');
    assert.equal((await getDoc(doc(winnerClient.db, 'reservations', winner))).data().status, 'awaiting_payment');
    const success = await winnerClient.call('demoPayment', { id: winner, outcome: 'success' }); assert.equal(success.status, 'succeeded');
    assert.equal((await winnerClient.call('demoPayment', { id: winner, outcome: 'success' })).status, 'succeeded');
    assert.equal((await getDoc(doc(winnerClient.db, 'reservations', winner))).data().status, 'confirmed');
    await assert.rejects(winnerClient.call('cancelReservation', { id: winner }));
  });
  await t.test('chat messages and private records exclude nonparticipants', async () => {
    const chatId = (await student.call('openChat', { apartmentId })).id;
    await student.call('sendMessage', { chatId, body: 'Hello owner' });
    await owner.call('sendMessage', { chatId, body: 'Welcome' });
    await assert.rejects(other.call('sendMessage', { chatId, body: 'Intrusion' }));
    await assertFails(getDoc(doc(other.db, 'chats', chatId)));
    await assertSucceeds(getDoc(doc(owner.db, 'chats', chatId)));
    await assertFails(getDoc(doc(owner.db, 'users', student.uid)));
    await assertFails(setDoc(doc(student.db, 'users', student.uid), { role: 'owner' }));
  });
  await t.test('verified review and immutable client rating aggregate', async () => {
    await assert.rejects(winnerClient.call('saveReview', { apartmentId, reservationId: winner, rating: 5, comment: 'Too early' }));
    await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'reservations', 'test-past-stay'), { studentId: student.uid, apartmentId, ownerId: owner.uid, roomId, status: 'completed', start: '2020-01-01', end: '2020-02-01', studentName: 'Fictional Test' }));
    await student.call('saveReview', { apartmentId, reservationId: 'test-past-stay', rating: 4, comment: 'Verified test stay' });
    await student.call('saveReview', { apartmentId, reservationId: 'test-past-stay', rating: 5, comment: 'Updated test stay' });
    const a = (await getDoc(doc(student.db, 'apartments', apartmentId))).data(); assert.equal(a.averageRating, 5); assert.equal(a.reviewCount, 1);
    await assert.rejects(other.call('saveReview', { apartmentId, reservationId: 'test-past-stay', rating: 1, comment: 'Not my stay' }));
    await assertFails(setDoc(doc(owner.db, 'apartments', apartmentId), { averageRating: 5 }));
  });
  await t.test('storage disallows foreign profile and invalid content', async () => {
    const ctx = env.authenticatedContext(student.uid), storage = ctx.storage();
    await assertFails(uploadBytes(storageRef(storage, `profiles/${owner.uid}/attack.png`), Buffer.from('fake'), { contentType: 'image/png' }));
    await assertFails(uploadBytes(storageRef(storage, `profiles/${student.uid}/script.txt`), Buffer.from('fake'), { contentType: 'text/plain' }));
    await assertSucceeds(uploadBytes(storageRef(storage, `profiles/${student.uid}/sample.png`), Buffer.from('fake'), { contentType: 'image/png' }));
  });
});
