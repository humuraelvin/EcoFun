const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

async function main() {
  const email = process.argv[2];
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('Configure Firebase Admin Application Default Credentials, then run: node set-admin.js member@example.com');
  }
  initializeApp({ credential: applicationDefault(), projectId: 'ecostep-92e88' });
  const auth = getAuth();
  const user = await auth.getUserByEmail(email.trim().toLowerCase());
  await auth.setCustomUserClaims(user.uid, { ...user.customClaims, admin: true });
  console.log(`Admin access granted to ${email.trim().toLowerCase()}. The account must sign out and back in to refresh its token.`);
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
