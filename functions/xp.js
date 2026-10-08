const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();
const DAILY_TRANSFER_LIMIT = 100;
const WEEKLY_AD_LIMIT = 5;
const WEEKLY_USAGE_SECONDS = 15 * 60 * 60;

function requireUser(context) {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  return context.auth.uid;
}

function weekKey(date = new Date()) {
  const utc = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = utc.getUTCDay() || 7;
  utc.setUTCDate(utc.getUTCDate() - day + 1);
  return utc.toISOString().slice(0, 10);
}

function dayKey(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

function addXp(transaction, userRef, amount) {
  transaction.set(userRef, {
    xp: admin.firestore.FieldValue.increment(amount),
  }, { merge: true });
}

exports.completeSignup = functions.https.onCall(async (data, context) => {
  const uid = requireUser(context);
  const profile = data?.profile;
  if (!profile || typeof profile !== 'object') {
    throw new functions.https.HttpsError('invalid-argument', 'Profile is required.');
  }

  const userRef = db.collection('users').doc(uid);
  const referralId = typeof data.referralId === 'string' ? data.referralId.trim() : '';
  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    if (userSnapshot.exists) {
      return { created: false, xpAwarded: false };
    }

    transaction.create(userRef, {
      ...profile,
      uid,
      friendsCount: 0,
      xp: 20,
      xpSignupAwarded: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    let referralRewarded = false;
    if (referralId && referralId !== uid) {
      const referrerRef = db.collection('users').doc(referralId);
      const referrerSnapshot = await transaction.get(referrerRef);
      if (referrerSnapshot.exists) {
        const referralRef = db.collection('xp_referrals').doc(`${referralId}_${uid}`);
        const referralSnapshot = await transaction.get(referralRef);
        if (!referralSnapshot.exists) {
          addXp(transaction, referrerRef, 2);
          transaction.create(referralRef, {
            referrerId: referralId,
            referredUserId: uid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          referralRewarded = true;
        }
      }
    }

    if (referralRewarded) addXp(transaction, userRef, 2);
    return { created: true, xpAwarded: true, referralRewarded };
  });
  return result;
});

exports.recordUsage = functions.https.onCall(async (data, context) => {
  const uid = requireUser(context);
  const requestedSeconds = Number(data?.seconds);
  if (!Number.isInteger(requestedSeconds) || requestedSeconds < 1 || requestedSeconds > 90) {
    throw new functions.https.HttpsError('invalid-argument', 'Usage must be between 1 and 90 seconds.');
  }

  const userRef = db.collection('users').doc(uid);
  const key = weekKey();
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    if (!snapshot.exists) throw new functions.https.HttpsError('not-found', 'User profile not found.');
    const data = snapshot.data() || {};
    const usage = data.xpUsageWeek === key ? Number(data.xpUsageSeconds || 0) : 0;
    const nextUsage = Math.min(WEEKLY_USAGE_SECONDS, usage + requestedSeconds);
    const updates = { xpUsageWeek: key, xpUsageSeconds: nextUsage };
    if (usage < WEEKLY_USAGE_SECONDS && nextUsage >= WEEKLY_USAGE_SECONDS && data.xpUsageRewardedWeek !== key) {
      updates.xpUsageRewardedWeek = key;
      updates.xp = admin.firestore.FieldValue.increment(2);
    }
    transaction.set(userRef, updates, { merge: true });
    return { seconds: nextUsage, rewarded: updates.xpUsageRewardedWeek === key };
  });
});

exports.grantAdXp = functions.https.onCall(async (data, context) => {
  const uid = requireUser(context);
  const adId = typeof data?.adId === 'string' ? data.adId.trim() : '';
  if (!adId) throw new functions.https.HttpsError('invalid-argument', 'Ad receipt is required.');

  const userRef = db.collection('users').doc(uid);
  const rewardRef = db.collection('xp_ad_rewards').doc(adId);
  return db.runTransaction(async (transaction) => {
    const [userSnapshot, rewardSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(rewardRef),
    ]);
    if (rewardSnapshot.exists) return { rewarded: false, reason: 'already-claimed' };
    if (!userSnapshot.exists) throw new functions.https.HttpsError('not-found', 'User profile not found.');
    const userData = userSnapshot.data() || {};
    const key = weekKey();
    const ads = userData.xpAdWeek === key ? Number(userData.xpAdsWatched || 0) : 0;
    if (ads >= WEEKLY_AD_LIMIT) return { rewarded: false, reason: 'weekly-limit' };
    transaction.create(rewardRef, { uid, week: key, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    transaction.set(userRef, {
      xpAdWeek: key,
      xpAdsWatched: ads + 1,
      xp: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
    return { rewarded: true, adsWatched: ads + 1 };
  });
});

exports.transferXp = functions.https.onCall(async (data, context) => {
  const uid = requireUser(context);
  const receiverId = typeof data?.receiverId === 'string' ? data.receiverId.trim() : '';
  const amount = Number(data?.amount);
  if (!receiverId || receiverId === uid || !Number.isInteger(amount) || amount < 1) {
    throw new functions.https.HttpsError('invalid-argument', 'Choose a mutual friend and a positive XP amount.');
  }
  const transferId = typeof data?.transferId === 'string' ? data.transferId.trim() : '';
  if (!transferId) throw new functions.https.HttpsError('invalid-argument', 'Transfer ID is required.');

  const senderRef = db.collection('users').doc(uid);
  const receiverRef = db.collection('users').doc(receiverId);
  const transferRef = db.collection('xp_transfers').doc(transferId);
  const friendshipRef = db.collection('freinds').doc(uid < receiverId ? `${uid}_${receiverId}` : `${receiverId}_${uid}`);
  const dailyRef = db.collection('xp_transfer_days').doc(`${uid}_${dayKey()}`);
  return db.runTransaction(async (transaction) => {
    const [sender, receiver, friendship, transfer, daily] = await Promise.all([
      transaction.get(senderRef), transaction.get(receiverRef), transaction.get(friendshipRef),
      transaction.get(transferRef), transaction.get(dailyRef),
    ]);
    if (transfer.exists) return { transferred: false, reason: 'already-processed' };
    if (!receiver.exists || friendship.data()?.status !== 'accepted') {
      throw new functions.https.HttpsError('permission-denied', 'XP can only be sent to a mutual friend.');
    }
    const senderXp = Number(sender.data()?.xp || 0);
    const sentToday = Number(daily.data()?.amount || 0);
    if (senderXp < amount) throw new functions.https.HttpsError('failed-precondition', 'Not enough XP.');
    if (sentToday + amount > DAILY_TRANSFER_LIMIT) throw new functions.https.HttpsError('resource-exhausted', 'Daily XP transfer limit reached.');
    transaction.set(senderRef, { xp: admin.firestore.FieldValue.increment(-amount) }, { merge: true });
    transaction.set(receiverRef, { xp: admin.firestore.FieldValue.increment(amount) }, { merge: true });
    transaction.create(transferRef, { senderId: uid, receiverId, amount, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    transaction.set(dailyRef, { amount: sentToday + amount }, { merge: true });
    return { transferred: true, amount };
  });
});