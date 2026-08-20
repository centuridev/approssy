import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

import {SMTP_PASSWORD} from "../config/emailConfig";
import {
  AppointmentEmailData,
} from "../mail/emailTemplates";
import {
  sendAppointmentEmail,
} from "../mail/sendAppointmentEmail";
import {
  sendAppointmentNotification,
} from "../notifications/sendAppointmentNotification";

const REGION = "europe-west1";

interface CancellationResult {
  userId: string;
  serviceName: string;
  emailData: AppointmentEmailData;
}

export const cancelAppointment = onCall(
  {
    region: REGION,
    secrets: [SMTP_PASSWORD],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Devi effettuare l'accesso.",
      );
    }

    const adminUid = request.auth.uid;

    const appointmentId =
      request.data?.appointmentId?.toString().trim();

    if (!appointmentId) {
      throw new HttpsError(
        "invalid-argument",
        "appointmentId è obbligatorio.",
      );
    }

    const db = getFirestore();

    const adminRef = db
      .collection("utenti")
      .doc(adminUid);

    const appointmentRef = db
      .collection("appointments")
      .doc(appointmentId);

    const result = await db.runTransaction<CancellationResult>(
      async (transaction) => {
        const adminSnapshot = await transaction.get(adminRef);

        const appointmentSnapshot =
          await transaction.get(appointmentRef);

        if (!adminSnapshot.exists) {
          throw new HttpsError(
            "permission-denied",
            "Profilo amministratore non trovato.",
          );
        }

        if (adminSnapshot.data()?.role !== "admin") {
          throw new HttpsError(
            "permission-denied",
            "Non hai i permessi per annullare appuntamenti.",
          );
        }

        if (!appointmentSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Appuntamento non trovato.",
          );
        }

        const appointment = appointmentSnapshot.data() ?? {};

        const currentStatus =
          appointment.status?.toString() ?? "";

        if (currentStatus === "cancelled") {
          throw new HttpsError(
            "already-exists",
            "L'appuntamento è già stato annullato.",
          );
        }

        if (currentStatus !== "confirmed") {
          throw new HttpsError(
            "failed-precondition",
            "Solo una prenotazione confermata può essere annullata.",
          );
        }

        const userId =
          appointment.userId?.toString().trim();

        if (!userId) {
          throw new HttpsError(
            "failed-precondition",
            "Cliente associato alla prenotazione non valido.",
          );
        }

        const serviceName =
          appointment.serviceName?.toString().trim() ||
          "Servizio beauty";

        const selectedDateTime =
          appointment.selectedDateTime;

        if (!(selectedDateTime instanceof Timestamp)) {
          throw new HttpsError(
            "failed-precondition",
            "Data della prenotazione non valida.",
          );
        }

        const rawDuration = appointment.serviceDuration;

        const serviceDuration =
          typeof rawDuration === "number" ?
            Math.trunc(rawDuration) :
            Number.parseInt(
              rawDuration?.toString() ?? "",
              10,
            );

        if (
          !Number.isFinite(serviceDuration) ||
          serviceDuration <= 0
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Durata del servizio non valida.",
          );
        }

        const clientName =
          typeof appointment.clientName === "string" &&
          appointment.clientName.trim() ?
            appointment.clientName.trim() :
            "Cliente";

        const clientLastName =
          typeof appointment.clientLastName === "string" ?
            appointment.clientLastName.trim() :
            "";

        const clientEmail =
          typeof appointment.email === "string" ?
            appointment.email.trim() :
            "";

        const clientPhone =
          typeof appointment.phone === "string" ?
            appointment.phone.trim() :
            "";

        const servicePrice =
          typeof appointment.servicePrice === "number" &&
          Number.isFinite(appointment.servicePrice) ?
            appointment.servicePrice :
            undefined;

        transaction.update(appointmentRef, {
          status: "cancelled",
          cancelledAt: FieldValue.serverTimestamp(),
          cancelledBy: adminUid,
          updatedAt: FieldValue.serverTimestamp(),

          blockedUntil: FieldValue.delete(),
          holdUntil: FieldValue.delete(),
        });

        return {
          userId,
          serviceName,
          emailData: {
            appointmentId,
            clientName,
            clientLastName,
            clientEmail,
            clientPhone,
            serviceName,
            serviceDuration,
            servicePrice,
            selectedDateTime,
          },
        };
      },
    );

    logger.info("Appointment cancelled.", {
      appointmentId,
      cancelledBy: adminUid,
    });

    const communicationResults = await Promise.allSettled([
      sendAppointmentNotification({
        userId: result.userId,
        appointmentId,
        status: "cancelled",
        title: "Appuntamento annullato",
        body:
          `L'appuntamento per ${result.serviceName} ` +
          "è stato annullato.",
      }),

      sendAppointmentEmail({
        type: "cancelled_client",
        appointment: result.emailData,
      }),
    ]);

    const pushResult = communicationResults[0];
    const emailResult = communicationResults[1];

    if (pushResult.status === "rejected") {
      logger.error(
        "Unable to send cancellation push notification.",
        {
          appointmentId,
          userId: result.userId,
          error:
            pushResult.reason instanceof Error ?
              pushResult.reason.message :
              String(pushResult.reason),
        },
      );
    }

    if (emailResult.status === "rejected") {
      logger.error(
        "Unable to send cancellation email.",
        {
          appointmentId,
          recipient: result.emailData.clientEmail,
          error:
            emailResult.reason instanceof Error ?
              emailResult.reason.message :
              String(emailResult.reason),
        },
      );
    }

    logger.info(
      "Cancellation communications processed.",
      {
        appointmentId,
        pushStatus: pushResult.status,
        emailStatus: emailResult.status,
      },
    );

    return {
      success: true,
      status: "cancelled",
    };
  },
);