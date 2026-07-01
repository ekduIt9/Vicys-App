import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

initializeApp();

type NotificationEvent = {
  recipientId: string;
  actorId: string;
  type: "follow" | "like" | "comment";
  entityId: string;
  title: string;
  body: string;
};

/**
 * Persists an in-app notification and sends it to every registered device.
 *
 * Invalid FCM tokens are deleted after multicast delivery. The function is
 * idempotent per event ID, performs no media reads, and skips self-notifications.
 */
async function deliverNotification(
  eventId: string,
  event: NotificationEvent,
): Promise<void> {
  if (event.recipientId === event.actorId) return;

  const database = getFirestore();
  const notification = database.collection("notifications").doc(eventId);
  const existing = await notification.get();
  if (existing.exists) return;

  await notification.create({
    recipientId: event.recipientId,
    actorId: event.actorId,
    type: event.type,
    entityId: event.entityId,
    title: event.title,
    body: event.body,
    readAt: null,
    createdAt: FieldValue.serverTimestamp(),
  });

  const devices = await database
    .collection("profiles")
    .doc(event.recipientId)
    .collection("devices")
    .limit(20)
    .get();
  const registrations = devices.docs.flatMap((document) => {
    const token = document.data().token as string | undefined;
    return token ? [{ token, document }] : [];
  });
  if (registrations.length === 0) return;

  const result = await getMessaging().sendEachForMulticast({
    tokens: registrations.map(({ token }) => token),
    notification: { title: event.title, body: event.body },
    data: { type: event.type, entityId: event.entityId },
  });
  const invalidDeletes = result.responses.flatMap((response, index) => {
    const code = response.error?.code;
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      return [registrations[index].document.ref.delete()];
    }
    return [];
  });
  await Promise.all(invalidDeletes);
}

/** Sends a notification when one user follows another user. */
export const notifyFollow = onDocumentCreated(
  "follows/{followId}",
  async (event) => {
    const value = event.data?.data();
    if (!value) return;
    await deliverNotification(`follow_${event.params.followId}`, {
      recipientId: value.followingId,
      actorId: value.followerId,
      type: "follow",
      entityId: event.params.followId,
      title: "Người theo dõi mới",
      body: "Có người vừa theo dõi bạn trên Vicys.",
    });
  },
);

/** Sends a notification when a post receives a reaction. */
export const notifyReaction = onDocumentCreated(
  "reactions/{reactionId}",
  async (event) => {
    const value = event.data?.data();
    if (!value) return;
    const post = await getFirestore().collection("posts").doc(value.postId).get();
    if (!post.exists) return;
    await deliverNotification(`like_${event.params.reactionId}`, {
      recipientId: post.data()!.authorId,
      actorId: value.userId,
      type: "like",
      entityId: value.postId,
      title: "Lượt thích mới",
      body: "Tác phẩm của bạn vừa nhận được một lượt thích.",
    });
  },
);

/** Sends a notification when a post receives a comment. */
export const notifyComment = onDocumentCreated(
  "comments/{commentId}",
  async (event) => {
    const value = event.data?.data();
    if (!value) return;
    const post = await getFirestore().collection("posts").doc(value.postId).get();
    if (!post.exists) return;
    await deliverNotification(`comment_${event.params.commentId}`, {
      recipientId: post.data()!.authorId,
      actorId: value.authorId,
      type: "comment",
      entityId: value.postId,
      title: "Bình luận mới",
      body: "Có người vừa bình luận về tác phẩm của bạn.",
    });
  },
);
