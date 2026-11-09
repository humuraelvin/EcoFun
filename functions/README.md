# EcoStep password reset email function

The Flutter client never contains SMTP credentials. Set them as Firebase
Functions secrets before deploying:

```sh
firebase functions:secrets:set SMTP_USERNAME
firebase functions:secrets:set SMTP_PASSWORD
firebase deploy --only functions,firestore:rules
```

The Firebase CLI prompts for each value. Use the Gmail account address for
`SMTP_USERNAME` and its Google app password for `SMTP_PASSWORD`; do not put
either value in source files or command arguments. The function sends six-digit
codes through `smtp.gmail.com:587`. Codes expire after ten minutes, are limited
to five guesses, and can be reissued once per minute.

Enable **Email/Password** under Firebase Authentication > Sign-in method before
using email sign-up/sign-in. Create the project's default Firestore database if
it does not exist yet; the function stores only a short-lived, hashed reset
code there. The existing Android and iOS app registrations are used by
`lib/firebase_options.dart`. Cloud Functions and secret storage may require a
billing-enabled Firebase plan.

## Image classification

The app uploads a resized photo to the authenticated callable function. The
function forwards it to OpenRouter using the free `qwen/qwen3.8-27b:free`
vision model and returns a strict category, item, explanation, and uncertainty
result. The OpenRouter key exists only as a Functions secret:

```sh
firebase functions:secrets:set OPENROUTER_API_KEY
firebase deploy --only functions,firestore:rules,storage
```

Paste a newly rotated OpenRouter key at the CLI prompt. Never store it in the
Flutter app, `.env`, or source control. The key previously shared in chat should
be revoked and replaced before deployment.

## Community, points, and administration

Create the project's default Cloud Firestore database and Firebase Storage
bucket, then deploy the rules and functions above. Each member gets an account
document with a full name and points balance. Email stays out of public profiles.
Each member can rate a post once, and the author earns one point for that
rating. Each correct quiz answer is worth five points; quiz points can be earned
once per UTC day. Admin grants allow 1–500 points and create a private audit
record.

To give an account admin access, use a trusted Firebase Admin SDK environment
and set the custom claim `admin: true` for that account. The app has no
self-service admin promotion. Both the portal and callable check this claim.
With Application Default Credentials configured for the `ecostep-92e88`
project, run `node functions/set-admin.js member@example.com` from the app
directory to set the claim. The member must sign out and back in to refresh the
token. Use the requested account email only after it has been provided.
