# Report analysis and implementation map

Source: `Reservation-Apartment-1.docx`, academic year 2021/2022. The entire report text is extracted to `report-text.txt`; all embedded images are retained in `report-media/`. Chapter numbering refers to printed report pages, not Word pagination.

## Conceptual model (Chapter 3, figures 3.1–3.6)

The ER diagram (image17) defines User(first/last name, email, gender, phone), disjoint Student and HomeOwner roles, Apartment(title, description, image, location, gender), Room(floor, bed, status), Reservation(start, end, amount), Review(rate, comment), and Message(content, created-on). Owners have many apartments; apartments have many rooms/reviews; students have many reservations/reviews; reservations belong to one room; messages connect students and owners. Passwords from the conceptual diagram belong exclusively in Firebase Authentication.

The DFD (image16) routes listing data and reservation decisions through the system/Firebase, and payment success/failure back to reservation processing. “Administrators” is interpreted as the owner actor: the text and owner use cases do not define an admin role.

Student use cases/activity/sequence (images19,21,24): register/login → profile/apartments → available rooms → request → owner decision → payment; reviews, renewal, chat branch from housing/reservation screens. Owner diagrams (images20,22,25): register/login → post apartment → add room → review incoming requests → approve/reject; profile, records, calendar, reviews, and chat. Registration sequence (image23) separates auth and user record creation.

## Screenshot inspection (Chapter 4, printed pages 21–28)

| Image | Original screen and controls | Implementation |
|---|---|---|
| 26–27 | Purple login/register, role, gender, name, email, address, password, phone, reset link | Auth screens and validated profiles |
| 28 | Owner welcome, Start Now, My Apartment | Empty owner dashboard and listing creation |
| 29 | Apartment name, description, gender/type selector, nearest gate, image, submit, rooms link | Apartment editor and room management |
| 30 | Floor, price, room number, availability, submit | Room editor with beds and description |
| 31–32 | Student name/date request, accept/decline, reservation records | Requests and history with student/address/payment snapshots |
| 33 | Profile image, name, location, email, phone, edit | Profile and editor |
| 34–35 | Search/listings/photos, available room number/floor/price | Browse filters, gallery, rooms |
| 36–37 | Room photo/details, Book Request, Complete Payment, timestamped chat | Room detail, reservation detail, payment, conversations |
| 38 | Apartment, room, start/end, amount, stars, review submit | Reservation detail, renewal, verified reviews |
| 39 | Payment sheet including card fields | Clearly marked sandbox checkout without storing/collecting card data |

## Functional checklist

- [x] Email registration/login/logout/reset and persistent Firebase sessions; immutable role, gender, address, first/last name, phone.
- [x] Student/owner route guards, auth/profile loading and failures.
- [x] Profile image upload, edit names/address/phone, authenticated email/password changes.
- [x] Owner listing CRUD (create/edit), gallery upload, gender, housing type, nearest gate, location/contact.
- [x] Owner room create/edit, floor/number/beds/price/availability.
- [x] Student apartment search, location/gender/price/rating filters and sorting; listing and room details.
- [x] Dated requests, owner approval/rejection, records, student details and payment records.
- [x] Backend transaction locking, interval conflict checks, server pricing and reservation transitions.
- [x] Sandbox success/failure, idempotent payment record, no real payment claim; production provider boundary.
- [x] Start/end dates, active/history grouping, cancellation, renewal as a new owner-approved request.
- [x] Owner month calendar and reservation history.
- [x] Real-time participant chat, previews, timestamps, per-user read tracking.
- [x] Verified tenant reviews and transactional rating aggregate; owner review access.
- [x] In-app notifications and optional FCM delivery/token registration.
- [x] English/Arabic text and Flutter RTL/localized date pickers.
- [x] Firestore/Storage rules, indexes, emulator-only fictional seed.
- [x] Domain tests and executable emulator security/concurrency tests.
- [x] Flutter analysis/widget tests and web build: workspace SDK installed; Android APK blocked by missing Android SDK.
- [x] Real Firebase project registration and tested Spark Firestore rules/indexes deployment.
- [ ] Android/iOS real-device integration and real payment provider: not verified/configured.

Nonfunctional: Material 3 purple theme, constrained responsive layouts, form validation, async loading/error/empty states; server-only sensitive mutations; participant privacy; no payment secrets/cards on device; Android first with iOS setup guidance. App store compliance requires release signing, privacy policy, actual provider and deployment review.
