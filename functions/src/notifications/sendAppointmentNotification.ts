import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

interface AppointmentNotificationParams {
  userId: string;
  appointmentId: string;
  title: string;
  body: string;
  status: "pending" | "confirmed" | "rejected" | "cancelled";
}
/**
 * Invia una notifica push relativa allo stato di un appuntamento.
 *
 * Recupera tutti i token FCM registrati per l'utente,
 * invia la notifica ai dispositivi e rimuove eventuali
 * token non più validi.
 *
 * @param {AppointmentNotificationParams} params
 * Parametri della notifica da inviare.
 * @return {Promise<void>}
 * Promise completata al termine dell'invio.
 */
export async function sendAppointmentNotification({
  userId,
  appointmentId,
  title,
  body,
  status,
}: AppointmentNotificationParams): Promise<void> {
  const db = getFirestore();

  const tokensSnapshot = await db
    .collection("utenti")
    .doc(userId)
    .collection("fcmTokens")
    .get();

  if (tokensSnapshot.empty) {
    logger.warn("No FCM tokens found for user.", {
      userId,
      appointmentId,
      status,
    });

    return;
  }

  const tokenDocuments = tokensSnapshot.docs
    .map((document) => {
      const token = document.data().token;

      if (typeof token !== "string" || token.trim().length === 0) {
        return null;
      }

      return {
        reference: document.ref,
        token: token.trim(),
      };
    })
    .filter(
      (
        item,
      ): item is {
        reference: FirebaseFirestore.DocumentReference;
        token: string;
      } => item !== null,
    );

  if (tokenDocuments.length === 0) {
    logger.warn("No valid FCM tokens found for user.", {
      userId,
      appointmentId,
      status,
    });

    return;
  }

  /*
   * FCM permite hasta 500 tokens en una petición multicast.
   * En este proyecto normalmente habrá uno o pocos dispositivos.
   */
  const response = await getMessaging().sendEachForMulticast({
    tokens: tokenDocuments.map((item) => item.token),

    notification: {
      title,
      body,
    },

    data: {
      type: "appointment_status",
      appointmentId,
      status,
    },

    android: {
      priority: "high",
      notification: {
        channelId: "appointments",
        sound: "default",
      },
    },

    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });

  const invalidTokenReferences: FirebaseFirestore.DocumentReference[] = [];

  response.responses.forEach((result, index) => {
    if (result.success) {
      return;
    }

    const errorCode = result.error?.code;

    logger.error("FCM notification delivery failed.", {
      userId,
      appointmentId,
      status,
      errorCode,
      errorMessage: result.error?.message,
    });

    if (
      errorCode === "messaging/registration-token-not-registered" ||
      errorCode === "messaging/invalid-registration-token"
    ) {
      invalidTokenReferences.push(
        tokenDocuments[index].reference,
      );
    }
  });

  if (invalidTokenReferences.length > 0) {
    const batch = db.batch();

    for (const reference of invalidTokenReferences) {
      batch.delete(reference);
    }

    await batch.commit();
  }

  logger.info("Appointment notification processed.", {
    userId,
    appointmentId,
    status,
    successCount: response.successCount,
    failureCount: response.failureCount,
    removedInvalidTokens: invalidTokenReferences.length,
  });
}