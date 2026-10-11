'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging } = require('firebase-admin/messaging');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const d = require('./domain');
initializeApp();
const db = getFirestore();
const today = () => new Date().toISOString().slice(0, 10);
const ref = (collection, id) => db.collection(collection).doc(d.text(id, 'ID', 200));
function callable(fn) {
  return onCall({ region: 'us-central1', enforceAppCheck: process.env.REQUIRE_APP_CHECK === 'true' }, async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
    try { return await fn(request.auth.uid, request.data || {}); }
    catch (e) { if (e instanceof d.DomainError) throw new HttpsError(e.code, e.message); if (e instanceof HttpsError) throw e; console.error(e); throw new HttpsError('internal', 'Operation failed. Please retry.'); }
  });
}
async function profile(uid, role) {
  const s = await ref('users', uid).get();
  d.check(s.exists, 'Complete your profile first.');
  const p = s.data(); if (role) d.authorize(p.role, role); return p;
}
async function get(tx, r) { const s = await tx.get(r); d.check(s.exists, 'Record no longer exists.', 'not-found'); return { id: s.id, ...s.data() }; }
function notify(tx, userId, title, body, reservationId) {
  tx.create(db.collection('notifications').doc(), { userId, title, body, reservationId, read: false, createdAt: FieldValue.serverTimestamp() });
}
exports.registerProfile = callable(async (uid, data) => {
  const account = await getAuth().getUser(uid);
  d.check(['student', 'owner'].includes(data.role), 'Choose student or owner.', 'invalid-argument');
  d.check(['male', 'female', 'unspecified'].includes(data.gender), 'Choose a valid gender.', 'invalid-argument');
  const values = { firstName: d.text(data.firstName, 'First name', 80), lastName: d.text(data.lastName, 'Last name', 80), phone: d.text(data.phone, 'Phone', 30), address: d.text(data.address, 'Address', 200), gender: data.gender, role: data.role, email: account.email || '', photoUrl: '', createdAt: FieldValue.serverTimestamp() };
  await db.runTransaction(async tx => { const r = ref('users', uid); const s = await tx.get(r); d.check(!s.exists, 'Profile already exists.'); tx.create(r, values); });
  return { ok: true };
});
exports.updateProfile = callable(async (uid, data) => {
  await profile(uid); const account = await getAuth().getUser(uid);
  const values = { email: account.email || '', updatedAt: FieldValue.serverTimestamp() };
  for (const [key, max] of [['firstName', 80], ['lastName', 80], ['phone', 30], ['address', 200]]) if (data[key] !== undefined) values[key] = d.text(data[key], key, max);
  if (data.gender !== undefined) { d.check(['male', 'female', 'unspecified'].includes(data.gender), 'Invalid gender.', 'invalid-argument'); values.gender = data.gender; }
  if (data.photoUrl !== undefined) { d.check(typeof data.photoUrl === 'string' && data.photoUrl.length < 2000 && (data.photoUrl === '' || data.photoUrl.startsWith('http') || data.photoUrl === 'assets/images/demo-avatar.png'), 'Invalid image URL.', 'invalid-argument'); values.photoUrl = data.photoUrl; }
  await ref('users', uid).update(values); return { ok: true };
});
exports.saveApartment = callable(async (uid, data) => {
  const p = await profile(uid, 'owner');
  d.check(['male', 'female', 'any'].includes(data.gender), 'Invalid eligibility.', 'invalid-argument');
  d.check(['apartment', 'studio', 'residence'].includes(data.housingType), 'Invalid housing type.', 'invalid-argument');
  const images = data.images || [];
  d.check(Array.isArray(images) && images.length <= 10 && images.every(x => typeof x === 'string' && (x.startsWith('http') || ['assets/images/demo-garden.png', 'assets/images/demo-olive.png'].includes(x)) && x.length < 2000), 'Up to ten image URLs allowed.', 'invalid-argument');
  const values = { ownerId: uid, ownerName: `${p.firstName} ${p.lastName}`, contactPhone: p.phone, title: d.text(data.title, 'Apartment name', 120), description: d.text(data.description, 'Description', 4000), location: d.text(data.location, 'Location'), nearestGate: typeof data.nearestGate === 'string' ? data.nearestGate.slice(0, 100) : '', gender: data.gender, housingType: data.housingType, images, updatedAt: FieldValue.serverTimestamp() };
  const r = data.id ? ref('apartments', data.id) : db.collection('apartments').doc();
  await db.runTransaction(async tx => { if (data.id) d.owner(uid, await get(tx, r)); tx.set(r, data.id ? values : { ...values, ratingSum: 0, reviewCount: 0, averageRating: 0, minPriceMinor: 0, createdAt: FieldValue.serverTimestamp() }, { merge: true }); });
  return { id: r.id };
});
exports.saveRoom = callable(async (uid, data) => {
  await profile(uid, 'owner');
  const ar = ref('apartments', data.apartmentId), rr = data.id ? ref('rooms', data.id) : db.collection('rooms').doc();
  const values = { ownerId: uid, apartmentId: ar.id, number: d.text(data.number, 'Room number', 30), floor: d.integer(data.floor, 'Floor', -5, 100), beds: d.integer(data.beds, 'Beds', 1, 20), priceMinor: d.integer(data.priceMinor, 'Monthly price', 100, 100000000), description: d.text(data.description, 'Room description', 2000), available: data.available === true, updatedAt: FieldValue.serverTimestamp() };
  await db.runTransaction(async tx => {
    d.owner(uid, await get(tx, ar));
    if (data.id) { const old = await get(tx, rr); d.owner(uid, old); d.check(old.apartmentId === ar.id, 'Room cannot move to another apartment.'); }
    const rooms = await tx.get(db.collection('rooms').where('apartmentId', '==', ar.id));
    d.check(!rooms.docs.some(s => s.id !== rr.id && s.data().number === values.number), 'Room number already exists.');
    const prices = rooms.docs.filter(s => s.id !== rr.id && s.data().available).map(s => s.data().priceMinor);
    if (values.available) prices.push(values.priceMinor);
    tx.set(rr, { ...values, ...(data.id ? {} : { lockVersion: 0, createdAt: FieldValue.serverTimestamp() }) }, { merge: true });
    tx.update(ar, { minPriceMinor: prices.length ? Math.min(...prices) : 0 });
  }); return { id: rr.id };
});
exports.submitReservation = callable(async (uid, data) => {
  const p = await profile(uid, 'student'), stay = d.period(data.start, data.end);
  const rr = ref('rooms', data.roomId), reservationRef = db.collection('reservations').doc();
  await db.runTransaction(async tx => {
    const room = await get(tx, rr), apartment = await get(tx, ref('apartments', room.apartmentId));
    d.check(room.available, 'Room is unavailable.'); d.check(d.eligible(p.gender, apartment), 'This housing does not match your profile gender.');
    const existing = await tx.get(db.collection('reservations').where('roomId', '==', rr.id));
    d.check(!existing.docs.some(s => d.blocks(s.data()) && d.overlaps(stay, s.data())), 'Room is booked for these dates.', 'already-exists');
    d.check(!existing.docs.some(s => s.data().studentId === uid && s.data().status === 'pending' && d.overlaps(stay, s.data())), 'You already have a pending request for these dates.', 'already-exists');
    let parentId = '';
    if (data.parentId) { const parent = await get(tx, ref('reservations', data.parentId)); d.check(parent.studentId === uid && parent.roomId === rr.id && ['confirmed', 'completed'].includes(parent.status) && stay.start >= parent.end, 'Invalid renewal.'); parentId = parent.id; }
    const amountMinor = d.quote(room.priceMinor, stay.days);
    tx.create(reservationRef, { studentId: uid, ownerId: apartment.ownerId, apartmentId: apartment.id, roomId: rr.id, apartmentTitle: apartment.title, roomNumber: room.number, studentName: `${p.firstName} ${p.lastName}`, studentAddress: p.address, studentPhone: p.phone, start: stay.start, end: stay.end, amountMinor, currency: 'ILS', status: 'pending', paymentStatus: 'unpaid', parentId, createdAt: FieldValue.serverTimestamp() });
    tx.update(rr, { lockVersion: FieldValue.increment(1) });
    notify(tx, apartment.ownerId, 'New reservation request', `${p.firstName} requested room ${room.number}.`, reservationRef.id);
  }); return { id: reservationRef.id };
});
exports.decideReservation = callable(async (uid, data) => {
  await profile(uid, 'owner'); d.check(['approve', 'reject'].includes(data.action), 'Invalid decision.', 'invalid-argument');
  const r = ref('reservations', data.id);
  await db.runTransaction(async tx => {
    const reservation = await get(tx, r); d.owner(uid, reservation);
    const next = d.transition(reservation.status, data.action), rr = ref('rooms', reservation.roomId), room = await get(tx, rr);
    if (data.action === 'approve') {
      d.check(room.available && reservation.start >= today(), 'Room unavailable or stay already started.');
      const all = await tx.get(db.collection('reservations').where('roomId', '==', rr.id));
      d.check(!all.docs.some(s => s.id !== r.id && d.blocks(s.data()) && d.overlaps(reservation, s.data())), 'Another approved booking overlaps this stay.', 'already-exists');
    }
    tx.update(r, { status: next, holdExpiresAt: data.action === 'approve' ? Date.now() + 24 * 3600000 : 0, updatedAt: FieldValue.serverTimestamp() });
    tx.update(rr, { lockVersion: FieldValue.increment(1) });
    notify(tx, reservation.studentId, data.action === 'approve' ? 'Reservation approved' : 'Reservation rejected', data.action === 'approve' ? 'Complete payment within 24 hours.' : 'The owner declined your request.', r.id);
  }); return { ok: true };
});
exports.cancelReservation = callable(async (uid, data) => {
  const r = ref('reservations', data.id);
  await db.runTransaction(async tx => {
    const reservation = await get(tx, r); d.check(reservation.studentId === uid || reservation.ownerId === uid, 'Reservation participant required.', 'permission-denied');
    const next = d.transition(reservation.status, 'cancel');
    const rr = ref('rooms', reservation.roomId); await get(tx, rr);
    tx.update(r, { status: next, updatedAt: FieldValue.serverTimestamp() }); tx.update(rr, { lockVersion: FieldValue.increment(1) });
    notify(tx, reservation.studentId === uid ? reservation.ownerId : reservation.studentId, 'Reservation cancelled', reservation.apartmentTitle, r.id);
  }); return { ok: true };
});
// Production integration must verify provider signatures and settle through this
// same transaction boundary. No client-supplied success flag is trusted in production.
exports.demoPayment = callable(async (uid, data) => {
  d.check(process.env.FUNCTIONS_EMULATOR === 'true', 'Sandbox checkout is available only in the emulator. A real provider is not configured.');
  await profile(uid, 'student'); d.check(['success', 'decline'].includes(data.outcome), 'Invalid sandbox outcome.', 'invalid-argument');
  const r = ref('reservations', data.id), pr = ref('payments', data.id);
  return db.runTransaction(async tx => {
    const reservation = await get(tx, r); d.check(reservation.studentId === uid, 'This is not your reservation.', 'permission-denied');
    const payment = await tx.get(pr);
    if (payment.exists && payment.data().status === 'succeeded') return { status: 'succeeded', demo: true };
    d.transition(reservation.status, 'pay'); d.check(reservation.holdExpiresAt > Date.now() && reservation.start >= today(), 'Approval expired. Request again.');
    const rr = ref('rooms', reservation.roomId); await get(tx, rr);
    const all = await tx.get(db.collection('reservations').where('roomId', '==', rr.id));
    d.check(!all.docs.some(s => s.id !== r.id && d.blocks(s.data()) && d.overlaps(reservation, s.data())), 'Booking conflict.', 'already-exists');
    const status = data.outcome === 'success' ? 'succeeded' : 'failed';
    tx.set(pr, { reservationId: r.id, studentId: uid, ownerId: reservation.ownerId, amountMinor: reservation.amountMinor, currency: 'ILS', provider: 'emulator-sandbox', demo: true, status, updatedAt: FieldValue.serverTimestamp() });
    if (status === 'succeeded') {
      tx.update(r, { status: 'confirmed', paymentStatus: 'paid_demo', updatedAt: FieldValue.serverTimestamp() }); tx.update(rr, { lockVersion: FieldValue.increment(1) });
      for (const user of [uid, reservation.ownerId]) notify(tx, user, 'Sandbox reservation confirmed', 'Demo payment only — no money was transferred.', r.id);
    } return { status, demo: true };
  });
});
exports.saveReview = callable(async (uid, data) => {
  await profile(uid, 'student'); const rating = d.integer(data.rating, 'Rating', 1, 5), comment = d.text(data.comment, 'Review', 2000);
  const ar = ref('apartments', data.apartmentId), reviewRef = ref('reviews', `${ar.id}_${uid}`);
  await db.runTransaction(async tx => {
    const apartment = await get(tx, ar), reservation = await get(tx, ref('reservations', data.reservationId)), old = await tx.get(reviewRef);
    d.check(d.canReview(uid, reservation, ar.id, today()), 'Reviews require your paid stay to have begun.', 'permission-denied');
    const count = apartment.reviewCount + (old.exists ? 0 : 1), sum = apartment.ratingSum - (old.exists ? old.data().rating : 0) + rating;
    tx.set(reviewRef, { apartmentId: ar.id, studentId: uid, ownerId: apartment.ownerId, studentName: reservation.studentName, reservationId: reservation.id, rating, comment, updatedAt: FieldValue.serverTimestamp() });
    tx.update(ar, { reviewCount: count, ratingSum: sum, averageRating: sum / count });
  }); return { ok: true };
});
exports.openChat = callable(async (uid, data) => {
  const p = await profile(uid, 'student'), a = (await ref('apartments', data.apartmentId).get()).data(); d.check(a, 'Apartment not found.', 'not-found');
  const cr = ref('chats', `${uid}_${a.ownerId}`);
  await db.runTransaction(async tx => { const s = await tx.get(cr); if (!s.exists) tx.create(cr, { participants: [uid, a.ownerId], studentId: uid, ownerId: a.ownerId, studentName: `${p.firstName} ${p.lastName}`, ownerName: a.ownerName, latestMessage: '', readAt: {}, updatedAt: FieldValue.serverTimestamp() }); }); return { id: cr.id };
});
exports.sendMessage = callable(async (uid, data) => {
  const cr = ref('chats', data.chatId), body = d.text(data.body, 'Message', 4000), mr = cr.collection('messages').doc();
  await db.runTransaction(async tx => { const chat = await get(tx, cr); d.participant(uid, chat); tx.create(mr, { senderId: uid, body, createdAt: FieldValue.serverTimestamp() }); tx.update(cr, { latestMessage: body.slice(0, 120), latestSenderId: uid, updatedAt: FieldValue.serverTimestamp() }); }); return { id: mr.id };
});
exports.markChatRead = callable(async (uid, data) => {
  const cr = ref('chats', data.chatId);
  await db.runTransaction(async tx => { const chat = await get(tx, cr); d.participant(uid, chat); tx.update(cr, { [`readAt.${uid}`]: FieldValue.serverTimestamp() }); }); return { ok: true };
});
exports.registerPushToken = callable(async (uid, data) => { await profile(uid); const token = d.text(data.token, 'Token', 4096); await ref('users', uid).collection('tokens').doc(require('node:crypto').createHash('sha256').update(token).digest('hex')).set({ token, updatedAt: FieldValue.serverTimestamp() }); return { ok: true }; });
exports.deliverPush = onDocumentCreated('notifications/{id}', async event => {
  const n = event.data.data(); if (process.env.FUNCTIONS_EMULATOR === 'true') return;
  const tokens = await ref('users', n.userId).collection('tokens').limit(500).get(); if (tokens.empty) return;
  const response = await getMessaging().sendEachForMulticast({ tokens: tokens.docs.map(s => s.data().token), notification: { title: n.title, body: n.body }, data: { reservationId: n.reservationId || '' } });
  await Promise.all(response.responses.map((result, i) => ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(result.error?.code) ? tokens.docs[i].ref.delete() : Promise.resolve()));
});
exports.expireReservations = onSchedule('every 60 minutes', async () => {
  const snapshots = await db.collection('reservations').where('status', 'in', ['awaiting_payment', 'confirmed']).get();
  for (const snapshot of snapshots.docs) await db.runTransaction(async tx => {
    const r = await get(tx, snapshot.ref); const expired = r.status === 'awaiting_payment' && r.holdExpiresAt <= Date.now(); const completed = r.status === 'confirmed' && r.end <= today();
    if (!expired && !completed) return;
    const rr = ref('rooms', r.roomId); await get(tx, rr);
    tx.update(snapshot.ref, { status: expired ? 'expired' : 'completed', updatedAt: FieldValue.serverTimestamp() }); tx.update(rr, { lockVersion: FieldValue.increment(1) });
    notify(tx, r.studentId, expired ? 'Approval expired' : 'Stay completed', r.apartmentTitle, r.id);
  });
});
