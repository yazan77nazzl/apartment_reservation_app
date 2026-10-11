const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, writeBatch, runTransaction, Timestamp, serverTimestamp } = require('firebase/firestore');
test('Spark rules protect free-plan client operations', { timeout: 120000 }, async t => {
  const env = await initializeTestEnvironment({ projectId: 'demo-apartment-reservation', firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firebase/firestore.spark.rules'), 'utf8') } });
  const prefix = `spark-${Date.now()}`, ownerId = `${prefix}-owner`, studentId = `${prefix}-student`, otherId = `${prefix}-other`;
  const owner = env.authenticatedContext(ownerId, { email: 'owner@example.test' }).firestore(), student = env.authenticatedContext(studentId, { email: 'student@example.test' }).firestore(), other = env.authenticatedContext(otherId, { email: 'other@example.test' }).firestore();
  const apartmentId = `${prefix}-apartment`, roomId = `${prefix}-room`, firstId = `${prefix}-r1`, secondId = `${prefix}-r2`;
  const apartment = { ownerId, ownerName: 'Owner Demo', contactPhone: '0590000000', title: 'Spark fictional home', description: 'Test residence', location: 'Jenin', nearestGate: 'Gate 1', gender: 'female', housingType: 'residence', images: ['assets/images/demo-garden.png'], createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ratingSum: 0, reviewCount: 0, averageRating: 0, minPriceMinor: 0 };
  const room = { ownerId, apartmentId, number: '101', floor: 1, beds: 2, priceMinor: 45000, description: 'Test room', available: true, activeReservationId: '', createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
  const start = new Date(); start.setUTCDate(start.getUTCDate()+5); start.setUTCHours(0,0,0,0); const end = new Date(start.getTime()+30*86400000);
  const reservation = { studentId, ownerId, apartmentId, roomId, apartmentTitle: apartment.title, roomNumber: '101', studentName: 'Student Demo', studentAddress: 'Jenin', studentPhone: '0590000000', start: start.toISOString().slice(0,10), end: end.toISOString().slice(0,10), startAt: Timestamp.fromDate(start), endAt: Timestamp.fromDate(end), rentalMonths: 1, amountMinor: 45000, currency: 'ILS', status: 'pending', paymentStatus: 'unpaid', parentId: '', createdAt: serverTimestamp() };
  try {
    await t.test('registration private profiles immutable roles and demo image persistence', async () => {
      for (const [db, uid, role, name, email] of [[owner,ownerId,'owner','Owner','owner@example.test'],[student,studentId,'student','Student','student@example.test'],[other,otherId,'student','Other','other@example.test']]) await assertSucceeds(setDoc(doc(db,'users',uid), { firstName:name,lastName:'Demo',role,gender:'female',email,phone:'0590000000',address:'Jenin',photoUrl:'',createdAt:serverTimestamp() }));
      await assertSucceeds(updateDoc(doc(student,'users',studentId), { photoUrl:'assets/images/demo-avatar.png',updatedAt:serverTimestamp() }));
      await assertFails(updateDoc(doc(student,'users',studentId), { role:'owner',updatedAt:serverTimestamp() }));
      await assertFails(getDoc(doc(other,'users',studentId)));
      await assertFails(setDoc(doc(student,'users','forged-id'), { role:'owner' }));
    });
    await t.test('owner creates listings/rooms; cross-owner and student writes denied', async () => {
      await assertSucceeds(setDoc(doc(owner,'apartments',apartmentId), apartment));
      await assertSucceeds(setDoc(doc(owner,'rooms',roomId), room));
      await assertFails(updateDoc(doc(student,'apartments',apartmentId), { title:'Attack',updatedAt:serverTimestamp() }));
      await assertFails(updateDoc(doc(student,'rooms',roomId), { priceMinor:1,updatedAt:serverTimestamp() }));
      await assertFails(updateDoc(doc(owner,'apartments',apartmentId), { averageRating:5,updatedAt:serverTimestamp() }));
    });
    await t.test('requests validate prices and prevent fabricated confirmation', async () => {
      const batch=writeBatch(student); batch.set(doc(student,'reservations',firstId), reservation); batch.set(doc(student,'notifications',`${firstId}_pending`), { userId:ownerId,reservationId:firstId,status:'pending',title:'New reservation request',body:apartment.title,read:false,createdAt:serverTimestamp() }); await assertSucceeds(batch.commit());
      await assertFails(setDoc(doc(student,'reservations',`${prefix}-cheap`), {...reservation,amountMinor:1}));
      await assertFails(setDoc(doc(student,'reservations',`${prefix}-paid`), {...reservation,status:'confirmed',paymentStatus:'paid'}));
      await assertFails(getDoc(doc(other,'reservations',firstId)));
      await assertSucceeds(setDoc(doc(other,'reservations',secondId), {...reservation,studentId:otherId,studentName:'Other Demo'}));
    });
    const hold=new Date(Date.now()+24*3600000);
    const approval={status:'awaiting_payment',holdUntil:Timestamp.fromDate(hold),holdExpiresAt:hold.getTime(),updatedAt:serverTimestamp()};
    await t.test('approval requires atomic room claim; simultaneous claims have one winner', async () => {
      await assertFails(updateDoc(doc(owner,'reservations',firstId),approval));
      async function approve(id) { return runTransaction(owner,async tx => { const rr=doc(owner,'rooms',roomId),r=doc(owner,'reservations',id); await tx.get(r); const snapshot=await tx.get(rr); if(snapshot.data().activeReservationId) throw Error('Already claimed'); tx.update(r,approval); tx.update(rr,{activeReservationId:id}); }); }
      const results=await Promise.allSettled([approve(firstId),approve(secondId)]); assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
      const active=(await getDoc(doc(owner,'rooms',roomId))).data().activeReservationId;
      const winningClient=active===firstId?student:other;
      await assertFails(updateDoc(doc(winningClient,'reservations',active),{status:'confirmed',paymentStatus:'paid',updatedAt:serverTimestamp()}));
      await assertFails(setDoc(doc(winningClient,'payments',active),{status:'succeeded'}));
      await assertFails(updateDoc(doc(owner,'rooms',roomId),{activeReservationId:''}));
      const b=writeBatch(winningClient); b.update(doc(winningClient,'reservations',active),{status:'cancelled',updatedAt:serverTimestamp()}); b.update(doc(winningClient,'rooms',roomId),{activeReservationId:''}); await assertSucceeds(b.commit());
    });
    await t.test('chat participation read tracking and immutable messages',async()=>{
      const chatId=`${studentId}_${ownerId}`;
      await assertSucceeds(setDoc(doc(student,'chats',chatId),{studentId,ownerId,participants:[studentId,ownerId],studentName:'Student Demo',ownerName:'Owner Demo',apartmentId,latestMessage:'',readAt:{},updatedAt:serverTimestamp()}));
      const b=writeBatch(student); b.set(doc(student,'chats',chatId,'messages','m1'),{senderId:studentId,body:'Hello',createdAt:serverTimestamp()}); b.update(doc(student,'chats',chatId),{latestMessage:'Hello',latestMessageId:'m1',latestSenderId:studentId,updatedAt:serverTimestamp()}); await assertSucceeds(b.commit());
      await assertSucceeds(updateDoc(doc(owner,'chats',chatId),{[`readAt.${ownerId}`]:serverTimestamp()}));
      await assertFails(getDoc(doc(other,'chats',chatId)));
      await assertFails(updateDoc(doc(owner,'chats',chatId,'messages','m1'),{body:'Edited'}));
      await assertFails(updateDoc(doc(student,'chats',chatId),{[`readAt.${ownerId}`]:serverTimestamp()}));
    });
    await t.test('reviews require verified past stays and cannot spoof another student',async()=>{
      const past=`${prefix}-past`;
      await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'reservations',past),{...reservation,status:'completed',startAt:Timestamp.fromDate(new Date('2020-01-01')),endAt:Timestamp.fromDate(new Date('2020-02-01'))}));
      const review={apartmentId,reservationId:past,studentId,ownerId,studentName:'Student Demo',rating:4,comment:'Verified stay',updatedAt:serverTimestamp()};
      await assertSucceeds(setDoc(doc(student,'reviews',`${apartmentId}_${studentId}`),review));
      await assertFails(setDoc(doc(other,'reviews',`${apartmentId}_${otherId}`),{...review,studentId:otherId,studentName:'Other Demo'}));
    });
  } finally { await env.cleanup(); }
});
