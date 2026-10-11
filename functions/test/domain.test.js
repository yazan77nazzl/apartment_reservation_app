const { test } = require('node:test');
const assert = require('node:assert/strict');
const d = require('../src/domain');
test('profile and creation validation rejects empty fields and invalid numeric input', () => {
  assert.throws(() => d.text(' ', 'Title')); assert.throws(() => d.integer(1.2, 'Beds', 1, 20));
  assert.equal(d.text(' Housing ', 'Title'), 'Housing'); assert.equal(d.integer(2, 'Beds', 1, 20), 2);
});
test('roles and ownership reject unauthorized management', () => {
  assert.throws(() => d.authorize('student', 'owner')); assert.throws(() => d.owner('other', { ownerId: 'owner' }));
  d.authorize('owner', 'owner'); d.owner('owner', { ownerId: 'owner' });
});
test('reservation dates and server quote enforce valid intervals', () => {
  assert.throws(() => d.day('2026-02-30')); assert.throws(() => d.period('2026-11-02', '2026-11-01', Date.parse('2026-10-11')));
  assert.equal(d.period('2026-11-01', '2026-12-02', Date.parse('2026-10-11')).days, 31);
  assert.equal(d.quote(50000, 31), 100000);
});
test('half-open intervals allow adjoining stays but reject overlap', () => {
  const a = { start: '2026-11-01', end: '2026-12-01' };
  assert.equal(d.overlaps(a, { start: '2026-12-01', end: '2027-01-01' }), false);
  assert.equal(d.overlaps(a, { start: '2026-11-30', end: '2026-12-30' }), true);
});
test('approved holds and confirmed payments block inventory; pending and expired holds do not', () => {
  assert.equal(d.blocks({ status: 'confirmed' }), true);
  assert.equal(d.blocks({ status: 'pending' }), false);
  assert.equal(d.blocks({ status: 'awaiting_payment', holdExpiresAt: 101 }, 100), true);
  assert.equal(d.blocks({ status: 'awaiting_payment', holdExpiresAt: 100 }, 100), false);
});
test('approval rejection cancellation and payment state transitions', () => {
  assert.equal(d.transition('pending', 'approve'), 'awaiting_payment');
  assert.equal(d.transition('pending', 'reject'), 'rejected');
  assert.equal(d.transition('awaiting_payment', 'pay'), 'confirmed');
  assert.throws(() => d.transition('pending', 'pay')); assert.throws(() => d.transition('rejected', 'approve'));
  assert.throws(() => d.transition('confirmed', 'cancel'));
});
test('chat permission requires participation', () => {
  d.participant('student', { participants: ['student', 'owner'] });
  assert.throws(() => d.participant('stranger', { participants: ['student', 'owner'] }));
});
test('review permissions require paid stay that began and correct student and apartment', () => {
  const r = { studentId: 's', apartmentId: 'a', status: 'confirmed', start: '2026-10-01' };
  assert.equal(d.canReview('s', r, 'a', '2026-10-11'), true);
  assert.equal(d.canReview('other', r, 'a', '2026-10-11'), false);
  assert.equal(d.canReview('s', { ...r, status: 'pending' }, 'a', '2026-10-11'), false);
  assert.equal(d.canReview('s', r, 'a', '2026-09-01'), false);
});
test('gender eligibility respects any and explicit restrictions', () => {
  assert.equal(d.eligible('female', { gender: 'female' }), true);
  assert.equal(d.eligible('male', { gender: 'female' }), false);
  assert.equal(d.eligible('unspecified', { gender: 'any' }), true);
});
