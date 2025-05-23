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
const { DateTime } = require('luxon');

admin.initializeApp();

exports.deleteOldImages = functions
  .region('us-central1')
  .pubsub.schedule('every 24 hours')
  .onRun(async () => {
    const oneDayAgo = DateTime.now()
      .setZone('Europe/Dublin')
      .minus({ days: 7 })
      .toISO();
    const oldOrders = await admin.firestore()
      .collection('orders')
      .where('scheduledTime', '<', oneDayAgo)
      .get();
    const deletePromises = [];
    for (const doc of oldOrders.docs) {
      const images = doc.data().images || [];
      for (const url of images) {
        const pathMatch = url.match(/o\/(.*)\?/);
        if (pathMatch && pathMatch[1]) {
          const path = pathMatch[1].replace('%2F', '/');
          deletePromises.push(
            admin.storage().bucket().file(path).delete().catch((error) => {
              console.error(`Failed to delete ${path}: ${error}`);
            })
          );
        }
      }
    }
    await Promise.all(deletePromises);
    console.log(`Deleted ${deletePromises.length} images for old orders`);
    return null;
  });

exports.deleteUserAuth = functions.https.onCall(async (data, context) => {
  const userId = data.userId;
  try {
    await admin.auth().deleteUser(userId);
    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to delete auth record', error);
  }
});


exports.scheduleOrderNotificationsOnOrderChange = functions
  .region('us-central1')
  .firestore.document('orders/{orderId}')
  .onWrite(async (change, context) => {
    const orderId = context.params.orderId;
    const newData = change.after.data();
    const oldData = change.before.data();

    console.log(`Processing order ${orderId}: newData=${JSON.stringify(newData || {})}, oldData=${JSON.stringify(oldData || {})}`);

    try {
      // Handle deletion
      if (!newData) {
        if (oldData) {
          await cancelNotifications(orderId);
          console.log(`Order ${orderId} deleted, canceled notifications`);
        }
        return null;
      }

      // Check if notifications need to be updated
      const isCanceled = newData.orderStatus === 'Canceled' && oldData?.orderStatus !== 'Canceled';
      const timeChanged = newData.scheduledTime !== oldData?.scheduledTime;
      const statusChanged = newData.orderStatus !== oldData?.orderStatus;

      if (oldData && (isCanceled || timeChanged)) {
        await cancelNotifications(orderId);
        console.log(`Canceled notifications for ${orderId}: canceled=${isCanceled}, timeChanged=${timeChanged} (old: ${oldData?.scheduledTime}, new: ${newData.scheduledTime})`);
      } else if (oldData && !timeChanged && !statusChanged) {
        console.log(`No notification changes for ${orderId}: status=${newData.orderStatus}, time=${newData.scheduledTime}`);
        return null; // Skip if neither time nor status changed
      }

      // Skip if not Upcoming or Completed
      if (!['Upcoming', 'Completed'].includes(newData.orderStatus)) {
        console.log(`Skipping scheduling for ${orderId}: status=${newData.orderStatus}`);
        return null;
      }

      // Validate scheduledTime
      const orderDateTime = DateTime.fromISO(newData.scheduledTime, { zone: 'Europe/Dublin' });
      if (!orderDateTime.isValid) {
        console.error(`Invalid scheduledTime for ${orderId}: ${newData.scheduledTime}`);
        return null;
      }

      const formattedDate = orderDateTime.toFormat('dd MMMM yyyy');
      const formattedTime = orderDateTime.toFormat('h:mm a');
      const clientName = newData.clientName || 'Unknown';

      // Schedule notifications
      const batch = admin.firestore().batch();
      const now = DateTime.now().setZone('Europe/Dublin');
      const scheduledNotifications = new Set(); // Track scheduled times to deduplicate

      // 7 days before to 3 days before at 6:00 AM daily
      for (let daysBefore = 7; daysBefore >= 3; daysBefore--) {
        const reminderDateTime = orderDateTime.minus({ days: daysBefore }).set({ hour: 6, minute: 0, second: 0 });
        if (reminderDateTime > now) {
          const timeKey = reminderDateTime.toISO();
          if (!scheduledNotifications.has(timeKey)) {
            const notificationRef = admin.firestore().collection('scheduled_notifications').doc();
            batch.set(notificationRef, {
              orderId,
              title: 'Order Reminder',
              body: `Upcoming order for ${clientName} on ${formattedDate} at ${formattedTime}`,
              scheduledTime: timeKey,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              status: 'scheduled',
            });
            console.log(`Queued notification ${notificationRef.id} for ${orderId} at ${timeKey}`);
            scheduledNotifications.add(timeKey);
          }
        }
      }

      // 3 days before to 1 day before at 6:00 AM, 12:00 PM, 6:00 PM
      for (let daysBefore = 3; daysBefore >= 1; daysBefore--) {
        const reminderDate = orderDateTime.minus({ days: daysBefore });
        const dailyHours = [6, 12, 18]; // 6:00 AM, 12:00 PM, 6:00 PM
        for (const hour of dailyHours) {
          const reminderDateTime = reminderDate.set({ hour, minute: 0, second: 0 });
          if (reminderDateTime > now) {
            const timeKey = reminderDateTime.toISO();
            if (!scheduledNotifications.has(timeKey)) {
              const notificationRef = admin.firestore().collection('scheduled_notifications').doc();
              batch.set(notificationRef, {
                orderId,
                title: 'Order Reminder',
                body: `Upcoming order for ${clientName} on ${formattedDate} at ${formattedTime}`,
                scheduledTime: timeKey,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'scheduled',
              });
              console.log(`Queued notification ${notificationRef.id} for ${orderId} at ${timeKey}`);
              scheduledNotifications.add(timeKey);
            }
          }
        }
      }

      // Order day: 4, 6, 8 hours before scheduled time
      const hoursBefore = [4, 6, 8];
      for (const hours of hoursBefore) {
        const reminderDateTime = orderDateTime.minus({ hours });
        // Skip notifications before 4:00 AM or in the past
        if (reminderDateTime > now && reminderDateTime.hour >= 4) {
          const timeKey = reminderDateTime.toISO();
          if (!scheduledNotifications.has(timeKey)) {
            const notificationRef = admin.firestore().collection('scheduled_notifications').doc();
            batch.set(notificationRef, {
              orderId,
              title: 'Order Today',
              body: `Your order for ${clientName} is today at ${formattedTime} (in ${hours} hours)!`,
              scheduledTime: timeKey,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              status: 'scheduled',
            });
            console.log(`Queued notification ${notificationRef.id} for ${orderId} at ${timeKey}`);
            scheduledNotifications.add(timeKey);
          }
        }
      }

      await batch.commit();
      console.log(`Scheduled notifications for ${orderId}`);
      return null;
    } catch (error) {
      console.error(`Error processing ${orderId}:`, error);
      return null;
    }
  });


async function cancelNotifications(orderId) {
  try {
    const db = admin.firestore();
    const batch = db.batch();

    // Cancel scheduled_notifications
    const scheduledQuery = await db
      .collection('scheduled_notifications')
      .where('orderId', '==', orderId)
      .where('status', '==', 'scheduled')
      .get();

    scheduledQuery.docs.forEach((doc) => {
      batch.update(doc.ref, {
        status: 'canceled',
        canceledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Canceled scheduled_notification ${doc.id} for ${orderId}`);
    });

    // Delete pending_notifications
    const pendingQuery = await db
      .collection('pending_notifications')
      .where('orderId', '==', orderId)
      .where('status', '==', 'scheduled')
      .get();

    pendingQuery.docs.forEach((doc) => {
      batch.delete(doc.ref);
      console.log(`Deleted pending_notification ${doc.id} for ${orderId}`);
    });

    await batch.commit();
    console.log(`Canceled ${scheduledQuery.size} scheduled, ${pendingQuery.size} pending notifications for ${orderId}`);
    return null;
  } catch (error) {
    console.error(`Error canceling notifications for ${orderId}:`, error);
    throw error;
  }
}
exports.scheduleOrderNotification = functions.region('us-central1').firestore
  .document('scheduled_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    console.log(`Processing scheduled_notification ${context.params.notificationId}: ${JSON.stringify(data)}`);

    if (data.status !== 'scheduled') {
      console.log(`Skipping non-scheduled notification ${context.params.notificationId}: status=${data.status}`);
      return null;
    }

    const orderId = data.orderId;
    const title = data.title;
    const body = data.body;
    const scheduledTime = DateTime.fromISO(data.scheduledTime, { zone: 'Europe/Dublin' });
    const now = DateTime.now().setZone('Europe/Dublin');
    const timeDiffMs = scheduledTime.toMillis() - now.toMillis();

    const usersSnapshot = await admin.firestore().collection('users').get();
    const tokens = usersSnapshot.docs
      .map((doc) => doc.data().fcmToken)
      .filter((token) => token);

    if (tokens.length === 0) {
      console.log(`No user tokens found for notification ${context.params.notificationId}`);
      return null;
    }

    const payload = {
      notification: {
        title,
        body,
      },
      data: {
        orderId,
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
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

    if (timeDiffMs <= 0) {
      try {
        await admin.messaging().sendMulticast({ tokens, ...payload });
        console.log(`Sent immediate notification for order ${orderId}: ${title}`);
        return snap.ref.delete();
      } catch (error) {
        console.error(`Error sending immediate notification for order ${orderId}:`, error);
        return null;
      }
    }

    try {
      await admin.firestore().collection('pending_notifications').doc(context.params.notificationId).set({
        orderId,
        title,
        body,
        scheduledTime: data.scheduledTime,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'scheduled',
      });
      console.log(`Created pending_notification ${context.params.notificationId} for order ${orderId}`);
    } catch (error) {
      console.error(`Error creating pending_notification ${context.params.notificationId}:`, error);
    }

    return null;
  });

exports.checkPendingNotifications = functions.region('us-central1').pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    const now = DateTime.now().setZone('Europe/Dublin');
    const db = admin.firestore();

    const pendingSnapshot = await db
      .collection('pending_notifications')
      .where('status', '==', 'scheduled')
      .where('scheduledTime', '<=', now.toISO())
      .get();

    if (pendingSnapshot.empty) {
      console.log(`No notifications due at ${now.toISO()}`);
      return null;
    }

    const usersSnapshot = await db.collection('users').get();
    const tokens = usersSnapshot.docs
      .map((doc) => doc.data().fcmToken)
      .filter((token) => token);

    if (tokens.length === 0) {
      console.log('No user tokens found');
      return null;
    }

    const promises = pendingSnapshot.docs.map((doc) => {
      const data = doc.data();
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
              alert: { title: data.title, body: data.body },
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

      return admin.messaging().sendMulticast({ tokens, ...payload })
        .then(() => {
          console.log(`Sent notification ${doc.id} for order ${data.orderId} at ${data.scheduledTime}`);
          return doc.ref.delete();
        })
        .catch((error) => {
          console.error(`Error sending notification ${doc.id} for order ${data.orderId}:`, error);
        });
    });

    await Promise.all(promises);
    return null;
  });

exports.updateOrderNotification = functions.region('us-central1').firestore
  .document('scheduled_notifications/{notificationId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    console.log(`Updating scheduled_notification ${context.params.notificationId}: newData=${JSON.stringify(newData)}`);

    if (newData.status === 'canceled' && oldData.status !== 'canceled') {
      await change.after.ref.delete();
      const pendingDocRef = admin.firestore()
        .collection('pending_notifications')
        .doc(context.params.notificationId);
      const pendingDoc = await pendingDocRef.get();
      if (pendingDoc.exists) {
        await pendingDocRef.delete();
        console.log(`Deleted pending_notification ${context.params.notificationId}`);
      }
      return null;
    }

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
        console.log(`Updated pending_notification ${context.params.notificationId}`);
      } else if (DateTime.fromISO(newData.scheduledTime, { zone: 'Europe/Dublin' }) > DateTime.now().setZone('Europe/Dublin')) {
        await pendingDocRef.set({
          orderId: newData.orderId,
          title: newData.title,
          body: newData.body,
          scheduledTime: newData.scheduledTime,
          status: 'scheduled',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Created pending_notification ${context.params.notificationId}`);
      }
    }
    return null;
  });
