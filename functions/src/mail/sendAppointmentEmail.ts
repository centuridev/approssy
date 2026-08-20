import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  AppointmentEmailData,
  buildCancelledEmail,
  buildConfirmedEmail,
  buildNewBookingAdminEmail,
  buildPendingClientEmail,
  buildRejectedEmail,
  buildReminder2HoursEmail,
  buildReminder24HoursEmail,
  buildThankYouEmail,
  EmailTemplate,
} from "./emailTemplates";
import {sendEmail} from "./sendEmail";

const ADMIN_EMAIL = "prenotazioni@rosibeautypremium.it";

export type AppointmentEmailType =
  | "pending_client"
  | "new_booking_admin"
  | "confirmed_client"
  | "rejected_client"
  | "cancelled_client"
  | "reminder_24h_client"
  | "reminder_2h_client"
  | "thank_you_client";

export interface SendAppointmentEmailParams {
  type: AppointmentEmailType;
  appointment: AppointmentEmailData;
}

/**
 * Invia una comunicazione email relativa a un appuntamento.
 *
 * Registra inoltre lo stato dell'invio nella sottocollezione
 * appointments/{appointmentId}/communications.
 *
 * @param {SendAppointmentEmailParams} params Parametri dell'invio.
 * @return {Promise<string|null>} Identificativo SMTP o null se già inviato.
 */
export async function sendAppointmentEmail({
  type,
  appointment,
}: SendAppointmentEmailParams): Promise<string | null> {
  const db = getFirestore();

  const recipient = resolveRecipient(type, appointment);
  const template = resolveTemplate(type, appointment);

  if (!recipient) {
    logger.warn("Appointment email skipped: recipient missing.", {
      appointmentId: appointment.appointmentId,
      type,
    });

    return null;
  }

  const communicationReference = db
    .collection("appointments")
    .doc(appointment.appointmentId)
    .collection("communications")
    .doc(type);

  const shouldSend = await db.runTransaction(async (transaction) => {
    const communicationSnapshot =
      await transaction.get(communicationReference);

    if (communicationSnapshot.exists) {
      const existingData = communicationSnapshot.data();
      const existingStatus = existingData?.status;

      if (
        existingStatus === "sent" ||
        existingStatus === "processing"
      ) {
        return false;
      }
    }

    transaction.set(
      communicationReference,
      {
        channel: "email",
        eventType: type,
        recipient,
        status: "processing",
        subject: template.subject,
        appointmentId: appointment.appointmentId,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );

    return true;
  });

  if (!shouldSend) {
    logger.info("Appointment email already processed.", {
      appointmentId: appointment.appointmentId,
      type,
      recipient,
    });

    return null;
  }

  try {
    const messageId = await sendEmail({
      to: recipient,
      subject: template.subject,
      html: template.html,
      text: template.text,
      appointmentId: appointment.appointmentId,
      eventType: type,
    });

    await communicationReference.set(
      {
        status: "sent",
        messageId,
        sentAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        error: FieldValue.delete(),
      },
      {
        merge: true,
      },
    );

    logger.info("Appointment communication completed.", {
      appointmentId: appointment.appointmentId,
      type,
      recipient,
      messageId,
    });

    return messageId;
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : String(error);

    await communicationReference.set(
      {
        status: "error",
        error: errorMessage,
        failedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      },
      {
        merge: true,
      },
    );

    logger.error("Appointment communication failed.", {
      appointmentId: appointment.appointmentId,
      type,
      recipient,
      error: errorMessage,
    });

    throw error;
  }
}

/**
 * Determina il destinatario della comunicazione.
 *
 * @param {AppointmentEmailType} type Tipo di comunicazione.
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {string} Indirizzo email del destinatario.
 */
function resolveRecipient(
  type: AppointmentEmailType,
  appointment: AppointmentEmailData,
): string {
  if (type === "new_booking_admin") {
    return ADMIN_EMAIL;
  }

  return appointment.clientEmail?.trim().toLowerCase() ?? "";
}

/**
 * Seleziona la corretta email HTML.
 *
 * @param {AppointmentEmailType} type Tipo di comunicazione.
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Modello email completo.
 */
function resolveTemplate(
  type: AppointmentEmailType,
  appointment: AppointmentEmailData,
): EmailTemplate {
  switch (type) {
  case "pending_client":
    return buildPendingClientEmail(appointment);

  case "new_booking_admin":
    return buildNewBookingAdminEmail(appointment);

  case "confirmed_client":
    return buildConfirmedEmail(appointment);

  case "rejected_client":
    return buildRejectedEmail(appointment);

  case "cancelled_client":
    return buildCancelledEmail(appointment);

  case "reminder_24h_client":
    return buildReminder24HoursEmail(appointment);

  case "reminder_2h_client":
    return buildReminder2HoursEmail(appointment);

  case "thank_you_client":
    return buildThankYouEmail(appointment);

  default:
    throw new Error(`Unknown email template: ${type}`);
  }
}