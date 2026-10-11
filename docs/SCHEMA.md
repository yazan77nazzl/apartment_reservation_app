# Firestore schema and security

| Collection | Relationships / fields | Access |
|---|---|---|
| users/{uid} | role, names, email, phone, address, gender, photoUrl, createdAt | Private to that UID; immutable role; no password |
| apartments/{id} | ownerId, title, description, location, nearestGate, gender, housingType, images, rating aggregates | Authenticated reads; owner's validated create/edit |
| rooms/{id} | apartmentId, ownerId, number, floor, beds, priceMinor, available, description, activeReservationId (Spark), lockVersion (backend) | Authenticated reads; owner's validated management |
| reservations/{id} | studentId, ownerId, apartmentId, roomId, student/contact snapshots, start/end, startAt/endAt (Spark), amountMinor, currency, status, hold, parentId | Student/owner only; pending → awaiting_payment/rejected/cancelled; clients cannot confirm payment |
| payments/{reservationId} | participants, amountMinor, currency, provider, status, demo | Participants read; trusted backend write only |
| reviews/{apartmentId_uid} | apartmentId, reservationId, studentId, ownerId, rating, comment | Authenticated read; own verified tenant review only |
| chats/{studentId_ownerId} | participants, names, apartmentId, latestMessage/ID, updatedAt, readAt map | Participants only |
| chats/{id}/messages/{id} | senderId, body, createdAt | Participants read/create with atomic preview; immutable after creation |
| notifications/{id} | userId, reservationId, status, title/body, read, createdAt | Recipient read/mark read; validated event creation or trusted backend |

`firestore.spark.rules` is the default deployed ruleset. `firestore.rules`/`firestore.backend.rules` retain the backend-only variant for an environment that has trusted Functions. Do not deploy the backend-only rules to Spark and expect direct client writes to work.

Security tests cover cross-owner modifications, role escalation, invalid prices/dates, forged payment success, missing/concurrent room lock claims, cancellation lock release, nonparticipant chat access, changing another user's read status, editing messages, and unauthorized reviews. Firestore rules are not filters: private reservation/payment/chat queries include the user's participation condition.

Storage rules limit images to JPEG/PNG/WebP under 8 MB, private ownership on upload paths and apartment ownership checks. Storage rules do not provision a bucket or require enabling billing for the current demo-image mode. Bundled assets are public fictional illustrations, not uploaded private photos.

Backend reservation and payment operations transactionally read/write the room lock. Approved holds and confirmed intervals block overlap; completed/cancelled records do not. Payment document IDs are reservation IDs for idempotency. Provider integration must verify signed webhooks, amount, currency and reservation metadata, then invoke the same authoritative confirmation boundary. Credentials belong in a trusted runtime's secret store. No provider implementation/credentials are included.
