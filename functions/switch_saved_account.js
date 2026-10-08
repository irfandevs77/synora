const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

exports.switchSavedAccount = functions.https.onCall(async (data) => {
  const refreshToken = typeof data?.refreshToken === 'string'
    ? data.refreshToken.trim()
    : '';
  const apiKey = typeof data?.apiKey === 'string' ? data.apiKey.trim() : '';

  if (!refreshToken || refreshToken.length > 4096 || !apiKey) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A saved session is required.',
    );
  }

  let response;
  try {
    response = await fetch(
      `https://securetoken.googleapis.com/v1/token?key=${encodeURIComponent(apiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'refresh_token',
          refresh_token: refreshToken,
        }),
      },
    );
  } catch (error) {
    console.error('Saved-account token exchange failed to reach Firebase.');
    throw new functions.https.HttpsError(
      'unavailable',
      'Could not reach Firebase Authentication. Try again.',
    );
  }

  const tokenResponse = await response.json();
  if (!response.ok) {
    const authError = tokenResponse?.error?.message;
    if (
      ['INVALID_REFRESH_TOKEN', 'TOKEN_EXPIRED', 'USER_DISABLED', 'USER_NOT_FOUND']
        .includes(authError)
    ) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'This saved account session has expired.',
      );
    }
    console.error('Firebase rejected saved-account token exchange.');
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Could not validate the saved account session.',
    );
  }

  const idToken = tokenResponse?.id_token;
  const updatedRefreshToken = tokenResponse?.refresh_token;
  if (
    typeof idToken !== 'string' ||
    typeof updatedRefreshToken !== 'string' ||
    typeof tokenResponse?.user_id !== 'string'
  ) {
    throw new functions.https.HttpsError(
      'internal',
      'Firebase returned an invalid account session.',
    );
  }

  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken, true);
  } catch (error) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'This saved account session has expired.',
    );
  }

  if (decodedToken.uid !== tokenResponse.user_id) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The saved account session is invalid.',
    );
  }

  const customToken = await admin.auth().createCustomToken(decodedToken.uid);
  return {
    uid: decodedToken.uid,
    customToken,
    refreshToken: updatedRefreshToken,
  };
});
