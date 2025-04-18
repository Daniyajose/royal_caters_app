/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */
/*

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
*/

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

exports.deleteUserAuth = functions.https.onCall(async (data, context) => {
  const userId = data.userId;
  try {
    await admin.auth().deleteUser(userId);
    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to delete auth record', error);
  }
});
exports.scheduleOrderNotification = functions.region('us-central1').firestore
  .document('scheduled_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (data.status !== 'scheduled') return null;

    const orderId = data.orderId;
    const title = data.title;
    const body = data.body;
    const scheduledTime = new Date(data.scheduledTime); // Assumes ISO 8601 (e.g., "2025-03-31T10:00:00+05:30")

    const now = new Date(); // UTC time on the server
    const timeDiffMs = scheduledTime - now;

    const usersSnapshot = await admin.firestore().collection('users').get();
    const tokens = usersSnapshot.docs
      .map((doc) => doc.data().fcmToken)
      .filter((token) => token);

    if (tokens.length === 0) {
      console.log('No user tokens found');
      return null;
    }

  // iOS and Android compatible payload
      const payload = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          orderId: orderId,
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              sound: 'default', // iOS sound
              badge: 1, // Badge count for iOS
            },
          },
        },
        android: {
          notification: {
            sound: 'default', // Android sound
          },
        },
      };

    if (timeDiffMs <= 0) {
      // Send immediately if scheduled time is now or past
      return admin.messaging().sendToDevice(tokens, payload)
        .then((response) => {
          console.log('Notification sent successfully:', response);
          return snap.ref.delete();
        })
        .catch((error) => {
          console.error('Error sending notification:', error);
        });
    }

    // Move to pending_notifications for later processing
    await admin.firestore().collection('pending_notifications').doc(context.params.notificationId).set({
      orderId,
      title,
      body,
      scheduledTime: data.scheduledTime, // Keep original ISO string with offset
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'scheduled',
    });

    return null;
  });

  exports.checkPendingNotifications = functions.region('us-central1').pubsub
    .schedule('every 15 minutes')
    .onRun(async (context) => {
      const now = new Date(); // Current UTC time
      const nowISO = now.toISOString(); // e.g., "2025-04-01T01:35:00Z"
      const db = admin.firestore();

      // Query notifications due at or before now (7 AM local time converted to UTC)
      const pendingSnapshot = await db
        .collection('pending_notifications')
        .where('status', '==', 'scheduled')
        .where('scheduledTime', '<=', nowISO) // Only notifications due now or earlier
        .get();

      if (pendingSnapshot.empty) {
        console.log('No notifications due at or before', nowISO);
        return null;
      }

      // Fetch user tokens
      const usersSnapshot = await db.collection('users').get();
      const tokens = usersSnapshot.docs
        .map((doc) => doc.data().fcmToken)
        .filter((token) => token);

      if (tokens.length === 0) {
        console.log('No user tokens found');
        return null;
      }

      // Send due notifications
      const promises = [];
      for (const doc of pendingSnapshot.docs) {
        const data = doc.data();
        const scheduledTime = new Date(data.scheduledTime); // For logging

        const payload = {
                notification: {
                  title: data.title,
                  body: data.body,
                },
                data: {
                  orderId: data.orderId,
                },
                apns: {
                  payload: {
                    aps: {
                      alert: {
                        title: data.title,
                        body: data.body,
                      },
                      sound: 'default',
                      badge: 1,
                    },
                  },
                },
                android: {
                  notification: {
                    sound: 'default',
                  },
                },
              };

        promises.push(
          admin.messaging().sendToDevice(tokens, payload)
            .then((response) => {
              console.log('Notification sent for order:', {
                orderId: data.orderId,
                scheduledTime: data.scheduledTime,
                response,
              });
              return doc.ref.delete(); // Delete after sending
            })
            .catch((error) => {
              console.error('Error sending notification:', error);
            })
        );
      }

      await Promise.all(promises);
      return null;
    });

// Handle updates to scheduled_notifications
exports.updateOrderNotification = functions.region('us-central1').firestore
  .document('scheduled_notifications/{notificationId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

// If status changes to canceled, clean up related notifications
    if (newData.status === 'canceled' && oldData.status !== 'canceled') {
      const orderId = newData.orderId;

      // Delete the canceled notification from scheduled_notifications
      await change.after.ref.delete();

      // Check and delete all matching pending notifications for this orderId
      const pendingQuery = await admin.firestore()
        .collection('pending_notifications')
        .where('orderId', '==', orderId)
        .get();

      if (!pendingQuery.empty) {
        const deletePromises = pendingQuery.docs.map((doc) => doc.ref.delete());
        await Promise.all(deletePromises);
      }

      return null;
    }

    // If date changes and still scheduled, update pending_notifications
    if (newData.scheduledTime !== oldData.scheduledTime && newData.status === 'scheduled') {
      const pendingDocRef = admin.firestore()
        .collection('pending_notifications')
        .doc(context.params.notificationId);
      const pendingDoc = await pendingDocRef.get();

      if (pendingDoc.exists) {
        await pendingDocRef.update({
          scheduledTime: newData.scheduledTime,
          title: newData.title,
          body: newData.body,
        });
      } else if (new Date(newData.scheduledTime) > new Date()) {
        // If not in pending yet and future-dated, add it
        await pendingDocRef.set({
          orderId: newData.orderId,
          title: newData.title,
          body: newData.body,
          scheduledTime: newData.scheduledTime,
          status: 'scheduled',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    return null;
  });