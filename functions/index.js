const { createHash, randomInt, randomUUID } = require('node:crypto');
const nodemailer = require('nodemailer');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { defineSecret } = require('firebase-functions/params');
const { HttpsError, onCall } = require('firebase-functions/v2/https');

initializeApp();

const smtpUsername = defineSecret('SMTP_USERNAME');
const smtpPassword = defineSecret('SMTP_PASSWORD');
const openRouterApiKey = defineSecret('OPENROUTER_API_KEY');
const db = getFirestore();
const auth = getAuth();

function normalizedEmail(value) {
  if (typeof value !== 'string') throw new HttpsError('invalid-argument', 'Enter a valid email address.');
  const email = value.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError('invalid-argument', 'Enter a valid email address.');
  }
  return email;
}

function codeDocumentId(email) {
  return createHash('sha256').update(email).digest('hex');
}

function digestCode(email, code) {
  return createHash('sha256').update(`${email}:${code}`).digest('hex');
}

function mailer() {
  return nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: { user: smtpUsername.value(), pass: smtpPassword.value() },
  });
}

exports.sendPasswordResetOtp = onCall(
  { secrets: [smtpUsername, smtpPassword] },
  async (request) => {
    const email = normalizedEmail(request.data?.email);
    const ref = db.collection('passwordResetCodes').doc(codeDocumentId(email));
    const oldCode = await ref.get();
    const now = Date.now();
    const lastSentAt = oldCode.exists ? oldCode.get('sentAt')?.toMillis() ?? 0 : 0;
    // Use the same response for registered and unregistered addresses.
    if (now - lastSentAt < 60_000) return { ok: true };

    let account;
    try {
      account = await auth.getUserByEmail(email);
    } catch (error) {
      if (error.code === 'auth/user-not-found') return { ok: true };
      throw new HttpsError('internal', 'Could not send a reset code. Try again later.');
    }

    const code = String(randomInt(100000, 1000000));
    await ref.set({
      uid: account.uid,
      codeHash: digestCode(email, code),
      expiresAt: Timestamp.fromMillis(now + 10 * 60_000),
      sentAt: Timestamp.fromMillis(now),
      attempts: 0,
    });

    try {
      await mailer().sendMail({
        from: `EcoStep <${smtpUsername.value()}>`,
        to: email,
        subject: 'Your EcoStep password reset code',
        text: `Your EcoStep reset code is ${code}. It expires in 10 minutes. If you did not request this, you can ignore this email.`,
      });
    } catch (error) {
      await ref.delete();
      console.error('Reset email delivery failed', error.message);
      throw new HttpsError('internal', 'Could not send a reset code. Try again later.');
    }
    return { ok: true };
  },
);

exports.resetPasswordWithOtp = onCall(
  {},
  async (request) => {
    const email = normalizedEmail(request.data?.email);
    const code = String(request.data?.otp ?? '').trim();
    const newPassword = request.data?.newPassword;
    if (!/^\d{6}$/.test(code)) throw new HttpsError('invalid-argument', 'Enter the six-digit code.');
    if (typeof newPassword !== 'string' || newPassword.length < 6) {
      throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
    }

    const ref = db.collection('passwordResetCodes').doc(codeDocumentId(email));
    const valid = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      const data = snapshot.data();
      if (data.expiresAt.toMillis() <= Date.now() || data.attempts >= 5) {
        transaction.delete(ref);
        return false;
      }
      if (data.codeHash !== digestCode(email, code)) {
        transaction.update(ref, { attempts: data.attempts + 1 });
        return false;
      }
      transaction.delete(ref);
      return data.uid;
    });

    if (!valid) throw new HttpsError('invalid-argument', 'The code is invalid or expired. Request a new code.');
    try {
      await auth.updateUser(valid, { password: newPassword });
    } catch (error) {
      console.error('Password update failed', error.message);
      throw new HttpsError('internal', 'Could not update the password. Request a new code.');
    }
    return { ok: true };
  },
);

exports.classifyWastePhoto = onCall(
  { secrets: [openRouterApiKey], timeoutSeconds: 90, memory: '512MiB' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to classify a photo.');
    const imageBase64 = request.data?.imageBase64;
    const mimeType = request.data?.mimeType;
    if (typeof imageBase64 !== 'string' || imageBase64.length < 100 || imageBase64.length > 7_000_000) {
      throw new HttpsError('invalid-argument', 'Choose a clear image smaller than 5 MB.');
    }
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)) {
      throw new HttpsError('invalid-argument', 'Use a JPEG, PNG, or WebP image.');
    }
    let response;
    try {
      response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${openRouterApiKey.value()}`,
          'Content-Type': 'application/json',
          'X-Title': 'EcoStep waste classification',
        },
        body: JSON.stringify({
          model: 'qwen/qwen3.8-27b:free',
          temperature: 0,
          max_tokens: 180,
          response_format: { type: 'json_object' },
          messages: [{
            role: 'user',
            content: [
              { type: 'text', text: 'Inspect this photo for the main waste item. Classify only as biodegradable, non_biodegradable, or uncertain. Biodegradable includes food, leaves, untreated wood, and uncoated paper/cardboard. Non-biodegradable includes plastic, glass, metal, batteries, and synthetic materials. If there is no clear waste item, multiple conflicting items, or the material cannot be identified from the image, use uncertain. Return only JSON with keys category (one of those three values), item (short name), reason (one short sentence), confidence (number from 0 to 1). Do not infer compostability from appearance alone when ambiguous.' },
              { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
            ],
          }],
        }),
        signal: AbortSignal.timeout(75_000),
      });
    } catch (error) {
      console.error('OpenRouter request failed', error.message);
      throw new HttpsError('unavailable', 'Image analysis is temporarily unavailable. Try again.');
    }
    if (!response.ok) {
      console.error('OpenRouter returned', response.status);
      throw new HttpsError(response.status === 429 ? 'resource-exhausted' : 'unavailable', 'Image analysis is temporarily unavailable. Try again.');
    }
    let result;
    try {
      const payload = await response.json();
      const content = payload.choices?.[0]?.message?.content;
      result = JSON.parse(typeof content === 'string' ? content : '');
    } catch (error) {
      console.error('OpenRouter returned invalid classification JSON', error.message);
      throw new HttpsError('unavailable', 'The image could not be classified reliably. Try another photo.');
    }
    const allowed = ['biodegradable', 'non_biodegradable', 'uncertain'];
    if (!allowed.includes(result.category)) throw new HttpsError('unavailable', 'The image could not be classified reliably. Try another photo.');
    return {
      category: result.category,
      item: typeof result.item === 'string' ? result.item.slice(0, 80) : 'Unknown item',
      reason: typeof result.reason === 'string' ? result.reason.slice(0, 240) : '',
      confidence: Math.max(0, Math.min(1, Number(result.confidence) || 0)),
    };
  },
);

exports.rateCommunityPost = onCall({}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to rate a post.');
  const postId = request.data?.postId;
  const value = request.data?.value;
  if (typeof postId !== 'string' || !postId || !Number.isInteger(value) || value < 1 || value > 5) {
    throw new HttpsError('invalid-argument', 'Choose a rating from 1 to 5.');
  }
  const postRef = db.collection('communityPosts').doc(postId);
  const ratingRef = postRef.collection('ratings').doc(request.auth.uid);
  const result = await db.runTransaction(async (transaction) => {
    const post = await transaction.get(postRef);
    if (!post.exists) throw new HttpsError('not-found', 'This post is no longer available.');
    if (post.get('uid') === request.auth.uid) throw new HttpsError('failed-precondition', 'You cannot rate your own post.');
    const authorRef = db.collection('users').doc(post.get('uid'));
    const rating = await transaction.get(ratingRef);
    const author = await transaction.get(authorRef);
    if (rating.exists) return { alreadyRated: true, pointsAwarded: 0 };
    if (!author.exists) throw new HttpsError('not-found', 'The author profile is unavailable.');
    transaction.create(ratingRef, { uid: request.auth.uid, value, createdAt: Timestamp.now() });
    transaction.update(postRef, { ratingCount: (post.get('ratingCount') || 0) + 1, ratingTotal: (post.get('ratingTotal') || 0) + value });
    transaction.update(authorRef, { points: (author.get('points') || 0) + 1 });
    return { alreadyRated: false, pointsAwarded: 1 };
  });
  return result;
});

exports.createCommunityPost = onCall({}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to share a photo.');
  const objectPath = request.data?.objectPath;
  if (typeof objectPath !== 'string' || !objectPath.startsWith(`community/${request.auth.uid}/`) || objectPath.includes('..')) {
    throw new HttpsError('invalid-argument', 'Upload a photo to your community folder.');
  }
  const file = getStorage().bucket().file(objectPath);
  let metadata;
  try { [metadata] = await file.getMetadata(); }
  catch (_) { throw new HttpsError('not-found', 'Uploaded photo was not found.'); }
  if (!String(metadata.contentType || '').match(/^image\/(jpeg|png|webp)$/) || Number(metadata.size) > 5 * 1024 * 1024) {
    throw new HttpsError('invalid-argument', 'Use an image smaller than 5 MB.');
  }
  const userRef = db.collection('users').doc(request.auth.uid);
  const user = await userRef.get();
  if (!user.exists) throw new HttpsError('failed-precondition', 'Your profile is unavailable.');
  const token = metadata.metadata?.firebaseStorageDownloadTokens || randomUUID();
  if (!metadata.metadata?.firebaseStorageDownloadTokens) {
    await file.setMetadata({ metadata: { ...metadata.metadata, firebaseStorageDownloadTokens: token } });
  }
  const imageUrl = `https://firebasestorage.googleapis.com/v0/b/${getStorage().bucket().name}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
  const post = await db.collection('communityPosts').add({
    uid: request.auth.uid,
    fullName: user.get('fullName') || 'EcoStep member',
    imageUrl,
    createdAt: Timestamp.now(),
    ratingCount: 0,
    ratingTotal: 0,
  });
  return { postId: post.id };
});

const quizAnswers = [1, 1, 0, 2, 3];
exports.submitQuizAnswers = onCall({}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to submit the quiz.');
  const answers = request.data?.answers;
  if (!Array.isArray(answers) || answers.length !== quizAnswers.length || answers.some((v) => !Number.isInteger(v) || v < 0 || v > 3)) {
    throw new HttpsError('invalid-argument', 'Submit an answer for every quiz question.');
  }
  const dateKey = new Date().toISOString().slice(0, 10);
  const attemptRef = db.collection('quizAttempts').doc(`${request.auth.uid}_${dateKey}`);
  const userRef = db.collection('users').doc(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const attempt = await transaction.get(attemptRef);
    if (attempt.exists) return { alreadyCompleted: true, score: attempt.get('score'), pointsAwarded: 0 };
    const user = await transaction.get(userRef);
    if (!user.exists) throw new HttpsError('failed-precondition', 'Create your profile before taking the quiz.');
    const score = answers.reduce((total, answer, index) => total + (answer === quizAnswers[index] ? 1 : 0), 0);
    const pointsAwarded = score * 5;
    transaction.create(attemptRef, { uid: request.auth.uid, score, answers, createdAt: Timestamp.now() });
    if (pointsAwarded > 0) transaction.update(userRef, { points: (user.get('points') || 0) + pointsAwarded });
    return { alreadyCompleted: false, score, pointsAwarded };
  });
});

exports.adminGrantPoints = onCall({}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (request.auth.token.admin !== true) throw new HttpsError('permission-denied', 'Admin access is required.');
  const email = normalizedEmail(request.data?.email);
  const points = request.data?.points;
  const reason = typeof request.data?.reason === 'string' ? request.data.reason.trim().slice(0, 200) : '';
  if (!Number.isInteger(points) || points < 1 || points > 500 || !reason) {
    throw new HttpsError('invalid-argument', 'Provide a member email, 1–500 points, and a reason.');
  }
  let target;
  try { target = await auth.getUserByEmail(email); }
  catch (error) { if (error.code === 'auth/user-not-found') throw new HttpsError('not-found', 'No member account uses that email.'); throw error; }
  const uid = target.uid;
  const userRef = db.collection('users').doc(uid);
  const grantRef = db.collection('pointGrants').doc();
  await db.runTransaction(async (transaction) => {
    const user = await transaction.get(userRef);
    if (!user.exists) throw new HttpsError('not-found', 'The user profile was not found.');
    transaction.update(userRef, { points: (user.get('points') || 0) + points });
    transaction.create(grantRef, { uid, points, reason, adminUid: request.auth.uid, createdAt: Timestamp.now() });
  });
  return { ok: true };
});
