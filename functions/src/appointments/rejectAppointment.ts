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
const PENDING_HOLD_HOURS = 2;

type RejectionResult =
  | {
      status: "rejected";
      userId: string;
      serviceName: string;
      emailData: AppointmentEmailData;
    }
  | {
      status: "expired";
    };

export const rejectAppointment = onCall(
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

    const result = await db.runTransaction<RejectionResult>(
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

        const adminData = adminSnapshot.data();

        if (adminData?.role !== "admin") {
          throw new HttpsError(
            "permission-denied",
            "Non hai i permessi per rifiutare appuntamenti.",
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

        if (currentStatus === "rejected") {
          throw new HttpsError(
            "already-exists",
            "L'appuntamento è già stato rifiutato.",
          );
        }

        if (currentStatus !== "pending") {
          throw new HttpsError(
            "failed-precondition",
            "Solo una prenotazione in attesa può essere rifiutata.",
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

        const now = Timestamp.now();

        let holdUntil: Timestamp | null = null;

        if (appointment.holdUntil instanceof Timestamp) {
          holdUntil = appointment.holdUntil;
        } else if (appointment.createdAt instanceof Timestamp) {
          const fallbackMilliseconds =
            appointment.createdAt.toMillis() +
            PENDING_HOLD_HOURS * 60 * 60 * 1000;

          holdUntil = Timestamp.fromMillis(
            fallbackMilliseconds,
          );
        }

        const isExpired =
          holdUntil === null ||
          holdUntil.toMillis() <= now.toMillis();

        if (isExpired) {
          transaction.update(appointmentRef, {
            status: "expired",
            expiredAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            holdUntil: FieldValue.delete(),
          });

          return {
            status: "expired",
          };
        }

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
          status: "rejected",
          rejectedAt: FieldValue.serverTimestamp(),
          rejectedBy: adminUid,
          updatedAt: FieldValue.serverTimestamp(),

          holdUntil: FieldValue.delete(),
          blockedUntil: FieldValue.delete(),
          confirmedAt: FieldValue.delete(),
          confirmedBy: FieldValue.delete(),
          expiredAt: FieldValue.delete(),
        });

        return {
          status: "rejected",
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

    if (result.status === "expired") {
      logger.warn(
        "Expired appointment rejection attempted.",
        {
          appointmentId,
          attemptedBy: adminUid,
        },
      );

      throw new HttpsError(
        "deadline-exceeded",
        "La prenotazione è già scaduta.",
      );
    }

    logger.info("Appointment rejected.", {
      appointmentId,
      rejectedBy: adminUid,
    });

    const communicationResults = await Promise.allSettled([
      sendAppointmentNotification({
        userId: result.userId,
        appointmentId,
        status: "rejected",
        title: "Prenotazione rifiutata",
        body:
          `La richiesta per ${result.serviceName} ` +
          "non è stata accettata.",
      }),

      sendAppointmentEmail({
        type: "rejected_client",
        appointment: result.emailData,
      }),
    ]);

    const pushResult = communicationResults[0];
    const emailResult = communicationResults[1];

    if (pushResult.status === "rejected") {
      logger.error(
        "Unable to send rejection push notification.",
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
        "Unable to send rejection email.",
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
      "Rejection communications processed.",
      {
        appointmentId,
        pushStatus: pushResult.status,
        emailStatus: emailResult.status,
      },
    );

    return {
      success: true,
      status: "rejected",
    };
  },
);