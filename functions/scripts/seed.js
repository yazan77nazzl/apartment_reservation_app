'use strict';
// Intentionally refuses any production host/project. Does not overwrite existing data.
const host = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || 'demo-apartment-reservation';
if (!/^((127\.0\.0\.1)|(localhost)):\d+$/.test(host || '') || !/^((127\.0\.0\.1)|(localhost)):\d+$/.test(authHost || '') || projectId !== 'demo-apartment-reservation') throw new Error('Seed requires local Auth/Firestore emulators and demo-apartment-reservation project.');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
initializeApp({ projectId });
const db = getFirestore(), auth = getAuth();
async function main() {
  const marker = db.doc('_development/fictionalSeedV1');
  if ((await marker.get()).exists) { console.log('Fictional seed already installed; nothing overwritten.'); return; }
  const users = [
    ['demo-owner', 'owner', 'Layla', 'Demo', 'female'],
    ['demo-student', 'student', 'Maya', 'Demo', 'female'],
    ['demo-student-2', 'student', 'Omar', 'Demo', 'male']
  ];
  for (const [uid, role, firstName, lastName, gender] of users) {
    let account; try { account = await auth.getUser(uid); } catch (e) { if (e.code !== 'auth/user-not-found') throw e; account = await auth.createUser({ uid, email: `${uid}@example.test`, password: 'DemoOnly!2026', displayName: `${firstName} ${lastName}` }); }
    const r = db.doc(`users/${uid}`); if (!(await r.get()).exists) await r.create({ role, firstName, lastName, gender, email: account.email, phone: '0590000000', address: 'Fictional Jenin address', photoUrl: '', fictional: true, createdAt: Timestamp.now() });
  }
  const listings = [['demo-jenin', 'Campus Garden — fictional', 'Jenin · near AAUP', 'female', 'Gate 1'], ['demo-nablus', 'Olive Residence — fictional', 'Nablus · university district', 'any', 'Main gate'], ['demo-ramallah', 'Study Corner — fictional', 'Ramallah · student district', 'any', '']];
  const batch = db.batch();
  for (const [id, title, location, gender, nearestGate] of listings) {
    batch.create(db.doc(`apartments/${id}`), { ownerId: 'demo-owner', ownerName: 'Layla Demo', contactPhone: '0590000000', title, location, gender, nearestGate, housingType: 'residence', description: 'Fictional sample university housing. Furnished rooms, shared kitchen and quiet study area. Not a real property or advertisement.', images: [], minPriceMinor: 45000, ratingSum: id === 'demo-jenin' ? 4 : 0, averageRating: id === 'demo-jenin' ? 4 : 0, reviewCount: id === 'demo-jenin' ? 1 : 0, fictional: true, createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
    for (let i = 1; i <= 3; i++) batch.create(db.doc(`rooms/${id}-${i}`), { ownerId: 'demo-owner', apartmentId: id, number: `10${i}`, floor: 1, beds: i === 1 ? 1 : 2, priceMinor: 40000 + i * 5000, available: true, description: 'Fictional furnished room with desk, wardrobe and shared facilities.', lockVersion: 0, fictional: true, createdAt: Timestamp.now() });
  }
  const day = offset => new Date(Date.now() + offset * 86400000).toISOString().slice(0, 10);
  batch.create(db.doc('reservations/demo-stay'), { studentId: 'demo-student', ownerId: 'demo-owner', apartmentId: 'demo-jenin', roomId: 'demo-jenin-1', apartmentTitle: listings[0][1], roomNumber: '101', studentName: 'Maya Demo', studentAddress: 'Fictional Jenin address', studentPhone: '0590000000', start: day(-2), end: day(20), amountMinor: 45000, currency: 'ILS', status: 'confirmed', paymentStatus: 'paid_demo', parentId: '', fictional: true, createdAt: Timestamp.now() });
  batch.create(db.doc('payments/demo-stay'), { studentId: 'demo-student', ownerId: 'demo-owner', reservationId: 'demo-stay', amountMinor: 45000, currency: 'ILS', status: 'succeeded', demo: true, provider: 'emulator-sandbox', updatedAt: Timestamp.now() });
  batch.create(db.doc('reviews/demo-jenin_demo-student'), { studentId: 'demo-student', ownerId: 'demo-owner', apartmentId: 'demo-jenin', studentName: 'Maya Demo', reservationId: 'demo-stay', rating: 4, comment: 'Fictional review: a comfortable place to study.', updatedAt: Timestamp.now() });
  batch.create(marker, { fictional: true, createdAt: Timestamp.now() }); await batch.commit();
  console.log('Fictional emulator data created. Accounts: demo-owner@example.test, demo-student@example.test, demo-student-2@example.test. Password: DemoOnly!2026');
}
main().catch(e => { console.error(e.message); process.exitCode = 1; });
