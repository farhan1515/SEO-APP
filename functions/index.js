const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendNotification = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    console.log("🔔 [DEBUG] Notification trigger started");
    console.log("🔔 [DEBUG] Notification ID:", context.params.notificationId);

    try {
      const notification = snap.data();
      console.log(
        "🔔 [DEBUG] Notification data:",
        JSON.stringify(notification, null, 2)
      );

      // Validate notification data
      if (!notification.recipientId) {
        console.error("❌ [DEBUG] Missing recipientId in notification");
        await snap.ref.delete();
        return null;
      }

      // Get the recipient's FCM tokens directly from the notification document
      const tokens = notification.fcmTokens || [];
      console.log("🔔 [DEBUG] Using tokens from notification:", tokens);

      if (!tokens.length) {
        console.log(
          "❌ [DEBUG] No FCM tokens found for user:",
          notification.recipientId
        );
        await snap.ref.delete();
        return null;
      }

      // Prepare notification message
      const message = {
        tokens: tokens,
        notification: {
          title: notification.title || "New Notification",
          body: notification.body || "",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: notification.type || "default",
          id: context.params.notificationId || "",
          chatId: notification.chatId || "",
          senderId: notification.senderId || "",
          senderName: notification.senderName || "",
          postId: notification.postId || "",
          postTitle: notification.postTitle || "",
          status: "done",
          timestamp: Date.now().toString(),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            defaultLightSettings: true,
            visibility: "public",
            icon: "@mipmap/ic_launcher",
            color: "#4B6BFB",
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              contentAvailable: true,
              mutableContent: true,
              category: "MESSAGE",
              sound: "default",
            },
          },
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
        },
        webpush: {
          headers: {
            Urgency: "high",
          },
          notification: {
            requireInteraction: true,
            icon: "/icon.png",
            badge: "/badge.png",
            vibrate: [100, 50, 100],
          },
        },
      };

      console.log(
        "🔔 [DEBUG] Prepared message:",
        JSON.stringify(message, null, 2)
      );

      console.log("🔔 [DEBUG] Attempting to send notification...");
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        "✅ [DEBUG] Notification send response:",
        JSON.stringify(response, null, 2)
      );

      // Track results and invalid tokens
      let successCount = 0;
      let failureCount = 0;
      const invalidTokens = [];
      const validTokens = [];

      response.responses.forEach((resp, idx) => {
        if (resp.success) {
          successCount++;
          validTokens.push(tokens[idx]);
          console.log("✅ [DEBUG] Successfully sent to token:", tokens[idx]);
        } else {
          failureCount++;
          console.log("❌ [DEBUG] Failed to send to token:", tokens[idx]);
          console.log("❌ [DEBUG] Error:", JSON.stringify(resp.error));
          const errorCode = resp.error && resp.error.code;
          console.log("❌ [DEBUG] Error code:", errorCode);
          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            invalidTokens.push(tokens[idx]);
          }
        }
      });

      console.log(
        `✅ [DEBUG] Success: ${successCount}, Failures: ${failureCount}`
      );

      // Update user's FCM tokens if there are invalid ones
      if (invalidTokens.length > 0) {
        console.log("🔔 [DEBUG] Removing invalid tokens:", invalidTokens);
        const userRef = admin
          .firestore()
          .collection("users")
          .doc(notification.recipientId);

        // Get current tokens
        const userDoc = await userRef.get();
        if (userDoc.exists) {
          const currentTokens = userDoc.data().fcmTokens || [];
          // Remove invalid tokens and keep valid ones
          const updatedTokens = currentTokens.filter(
            (token) => !invalidTokens.includes(token)
          );

          // Update user document with cleaned tokens
          await userRef.update({
            fcmTokens: updatedTokens,
            fcmToken: updatedTokens[0] || null, // Update single token for backward compatibility
            lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log("✅ [DEBUG] User tokens updated successfully");
        }
      }

      console.log("🔔 [DEBUG] Deleting notification document");
      await snap.ref.delete();
      console.log("✅ [DEBUG] Notification process completed successfully");

      return null;
    } catch (error) {
      console.error("❌ [DEBUG] Error sending notification:", error);
      console.error(
        "❌ [DEBUG] Error details:",
        JSON.stringify(error, null, 2)
      );

      try {
        await snap.ref.delete();
        console.log("🔔 [DEBUG] Notification document deleted after error");
      } catch (deleteError) {
        console.error(
          "❌ [DEBUG] Error deleting notification document:",
          deleteError
        );
      }

      return null;
    }
  });
