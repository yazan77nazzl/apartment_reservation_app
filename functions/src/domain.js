'use strict';
class DomainError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
function check(condition, message, code = 'failed-precondition') {
  if (!condition) throw new DomainError(code, message);
}
function text(value, name, max = 200) {
  check(typeof value === 'string' && value.trim().length > 0 && value.trim().length <= max, `${name} is required (max ${max} characters).`, 'invalid-argument');
  return value.trim();
}
function integer(value, name, min, max) {
  check(Number.isSafeInteger(value) && value >= min && value <= max, `${name} must be an integer between ${min} and ${max}.`, 'invalid-argument');
  return value;
}
function day(value) {
  check(typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value), 'Use YYYY-MM-DD dates.', 'invalid-argument');
  const ms = Date.parse(value + 'T00:00:00Z');
  check(Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 10) === value, 'Invalid calendar date.', 'invalid-argument');
  return ms;
}
function period(start, end, now = Date.now()) {
  const a = day(start), b = day(end);
  check(a >= Math.floor(now / 86400000) * 86400000 && b > a && b - a <= 366 * 86400000, 'Choose a future stay of 1–366 days.', 'invalid-argument');
  return { start, end, days: (b - a) / 86400000 };
}
function overlaps(a, b) { return a.start < b.end && b.start < a.end; }
function blocks(r, now = Date.now()) {
  return r.status === 'confirmed' || (r.status === 'awaiting_payment' && r.holdExpiresAt > now);
}
function quote(priceMinor, days) { return integer(priceMinor, 'Monthly price', 100, 100000000) * Math.ceil(days / 30); }
function transition(status, action) {
  const map = { pending: { approve: 'awaiting_payment', reject: 'rejected', cancel: 'cancelled' }, awaiting_payment: { pay: 'confirmed', cancel: 'cancelled', expire: 'expired' }, confirmed: { complete: 'completed' } };
  const next = map[status]?.[action];
  check(next, `Cannot ${action} a ${status} reservation.`);
  return next;
}
function authorize(role, expected) { check(role === expected, `${expected} account required.`, 'permission-denied'); }
function owner(uid, object) { check(object.ownerId === uid, 'You can only manage your own records.', 'permission-denied'); }
function participant(uid, chat) { check(chat.participants.includes(uid), 'Conversation participant required.', 'permission-denied'); }
function eligible(gender, apartment) { return apartment.gender === 'any' || apartment.gender === gender; }
function canReview(uid, reservation, apartmentId, today) { return reservation.studentId === uid && reservation.apartmentId === apartmentId && ['confirmed', 'completed'].includes(reservation.status) && reservation.start <= today; }
module.exports = { DomainError, check, text, integer, day, period, overlaps, blocks, quote, transition, authorize, owner, participant, eligible, canReview };
