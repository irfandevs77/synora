/**
 * Synora Push Notification Cloud Function
 * Deploy this to Firebase Cloud Functions to enable push notifications
 * 
 * Installation:
 * 1. Navigate to functions directory: cd functions
 * 2. Install dependencies: npm install
 * 3. Deploy: firebase deploy --only functions
 * 
 * This function listens to the notification_queue collection and sends FCM notifications
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Sends a notification to a user via FCM when a new notification_queue document is created
 * Triggered when a document is written to the notification_queue collection
 */
exports.sendNotificationOnCreate = functions
  .firestore
  .document('notification_queue/{docId}')
  .onCreate(async (snap, context) => {
    try {
      const notificationData = snap.data();
      const docId = context.params.docId;

      // Extract notification details
      const {
        targetUserId,
        fcmToken,
        title,
        body,
        notificationType,
        actionId,
        data = {}
      } = notificationData;

      const userSnapshot = await db.collection('users').doc(targetUserId).get();
      const preferences = userSnapshot.data()?.notificationPreferences || {};
      const category = notificationCategory(notificationType);
      if (preferences.all === false || preferences[category] === false) {
        await db.collection('notification_queue').doc(docId).update({
          status: 'skipped',
          reason: 'Disabled by recipient notification preferences',
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return;
      }

      console.log(`Processing notification for user: ${targetUserId}`);
      console.log(`Notification type: ${notificationType}`);

      // Validate required fields
      if (!fcmToken || !title || !body) {
        console.error('Missing required notification fields:', { fcmToken, title, body });
        
        // Mark as failed
        await db.collection('notification_queue').doc(docId).update({
          status: 'failed',
          error: 'Missing required fields',
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return;
      }

      // Build the notification message
      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          'type': notificationType,
          'actionId': actionId || '',
          'channelId': channelIdFor(notificationType),
          ...data  // Include any additional data
        },
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            icon: 'ic_launcher',
            channelId: channelIdFor(notificationType),
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            sound: 'default',
            defaultSound: true,
            defaultVibrateTimings: true,
            defaultLightSettings: true,
          }
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              sound: 'default',
              badge: 1,
            }
          }
        }
      };

      function notificationCategory(type) {
        switch (type) {
          case 'message':
          case 'reply':
          case 'mention':
          case 'reaction':
            return 'messages';
          case 'friend_request':
          case 'friend_accept':
            return 'friendRequests';
          case 'call':
          case 'incoming_call':
            return 'calls';
          default:
            return 'general';
        }
      }

      function channelIdFor(notificationType) {
        switch (notificationType) {
          case 'message':
          case 'reply':
          case 'mention':
          case 'reaction':
            return 'synora_messages';
          case 'friend_request':
          case 'friend_accept':
            return 'synora_friend_requests';
          case 'call':
          case 'incoming_call':
            return 'synora_calls';
          default:
            return 'synora_general';
        }
      }

      // Send the notification
      const response = await messaging.send(message);
      console.log('Notification sent successfully:', response);

      // Mark as sent
      await db.collection('notification_queue').doc(docId).update({
        status: 'sent',
        response: response,
        sentAt: admin.firestore.FieldValue.serverTimestamp()
      });

    } catch (error) {
      console.error('Error sending notification:', error);
      
      // Update the document to mark as failed
      try {
        await db.collection('notification_queue').doc(context.params.docId).update({
          status: 'failed',
          error: error.message,
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      } catch (updateError) {
        console.error('Failed to update notification status:', updateError);
      }
    }
  });

/**
 * Cleanup: Delete old processed notifications
 * Runs daily to clean up the notification_queue collection
 */
exports.cleanupOldNotifications = functions
  .pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const snapshot = await db.collection('notification_queue')
        .where('processedAt', '<', sevenDaysAgo)
        .get();

      console.log(`Found ${snapshot.size} old notifications to delete`);

      const batch = db.batch();
      snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log('Cleanup completed successfully');

    } catch (error) {
      console.error('Error during cleanup:', error);
    }
  });

/**
 * Handle invalid FCM tokens
 * When a notification fails due to invalid token, remove it from user profile
 */
exports.handleInvalidTokens = functions
  .https
  .onCall(async (data, context) => {
    try {
      const { userId, fcmToken } = data;

      if (!userId || !fcmToken) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing userId or fcmToken');
      }

      // Update user document to remove invalid token
      await db.collection('users').doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });

      console.log(`Removed invalid FCM token for user: ${userId}`);
      return { success: true, message: 'Token removed' };

    } catch (error) {
      console.error('Error handling invalid token:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });
