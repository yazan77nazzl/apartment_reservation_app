# Supabase photo storage with Firebase Spark

Authentication and application records stay in Firebase project
`apartment-reservation-ap-d7a35`. Supabase stores JPG/PNG/WebP photos; their public
URLs are saved in the existing Firestore profile/apartment records.

## One-time setup

1. Create a **Free** Supabase project at https://supabase.com/dashboard.
2. In **Authentication → Third-Party Auth**, add **Firebase** with project ID
   `apartment-reservation-ap-d7a35`. This is required so Supabase verifies Firebase
   ID tokens. Do not enable anonymous uploads or change the app's Firebase login.
3. Run [storage.sql](../supabase/storage.sql) in the Supabase SQL Editor. It creates
   the public `housing-images` bucket, restricts each file to 8 MB and supported
   image MIME types, and grants uploads only to the matching Firebase user's
   folder. Use a new bucket without other permissive write policies.
4. Copy `config/image-storage.example.json` to `config/image-storage.json`. Fill
   `SUPABASE_URL` with the HTTPS project URL and `SUPABASE_PUBLISHABLE_KEY` with
   your **Publishable** key (a legacy **anon** key also works). Never use a secret
   or service_role key. The local config is ignored by Git.
5. Run `./scripts/run-android.ps1`, or `./scripts/run-live.ps1` for web. The scripts
   load the local config at build time. Rebuild after changing configuration.

```powershell
Copy-Item config/image-storage.example.json config/image-storage.json
# Fill the two values, then run:
./scripts/run-android.ps1
```

The image backend is selected through `IMAGE_STORAGE=supabase`, `demo`, or
`firebase`. Local Firebase-emulator demo sessions default to bundled assets.
The hosted Supabase integration does not accept local emulator JWTs.

## Permissions

The app sends the current Firebase ID token as the bearer token, with the public
Supabase key in `apikey`. Supabase verifies its signature, expiry, issuer, and
configured Firebase project. Object policies additionally check the issuer,
audience, and string UID. Profile objects use `profiles/<uid>/<random>.jpg`;
apartment photos use `apartments/<uid>/<apartmentId>/<random>.jpg`.

Firebase JWTs normally have no Postgres `role` claim. Supabase assigns these the
`anon` database role, so our policies cover both `anon` and `authenticated` and
require the verified Firebase JWT. A bare public/anon key has neither the required
Firebase issuer nor UID and cannot upload. This avoids custom Firebase claims or
Cloud Functions, keeping Firebase on Spark. No Supabase service key ships in the
app. Firestore still enforces profile ownership and apartment owner permissions.

These photos are **public by URL**, suitable for listings and public avatars;
do not put identification documents in this bucket. Deleting a photo reference
does not delete its stored object. Remove unused images through Supabase Storage
to manage the Free plan quota. Overwrite and client deletion are deliberately
disabled. Private document storage would require a separate bucket and design.

## Verify after setup

Sign in with a real Firebase account, choose a photo, and save the profile.
Reopen it to confirm the saved URL loads. Repeat for an apartment you own.
Verify the object path starts with your UID, a request without a Firebase token
is denied, and another user cannot upload to your path. Accounts continue to
appear in Firebase Authentication; Firestore contains only the image URLs.

## References

- [Supabase Firebase third-party auth](https://supabase.com/docs/guides/auth/third-party/firebase-auth)
- [Storage access control](https://supabase.com/docs/guides/storage/security/access-control)
- [Public buckets and MIME/size restrictions](https://supabase.com/docs/guides/storage/buckets/fundamentals)
- [Free plan limits](https://supabase.com/docs/guides/platform/billing-on-supabase)

Project credentials, third-party auth configuration, and SQL deployment are
required before a real upload can succeed. Local tests validate the request and
Firestore URL permissions; they do not claim a hosted Supabase upload passed.
