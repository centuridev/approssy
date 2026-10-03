import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  AppointmentEmailData,
  AppointmentEmailService,
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

  const enrichedAppointment =
    await enrichAppointmentWithStoredServices(
      appointment,
    );

  const recipient = resolveRecipient(
    type,
    enrichedAppointment,
  );

  const template = resolveTemplate(
    type,
    enrichedAppointment,
  );

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
 * Recupera dal documento Firestore la struttura completa dei servizi.
 *
 * Mantiene la compatibilità con le prenotazioni precedenti che non
 * dispongono ancora del campo services.
 *
 * @param {AppointmentEmailData} appointment Dati ricevuti dalla funzione.
 * @return {Promise<AppointmentEmailData>} Dati completi per l'email.
 */
async function enrichAppointmentWithStoredServices(
  appointment: AppointmentEmailData,
): Promise<AppointmentEmailData> {
  try {
    const db = getFirestore();

    const snapshot = await db
      .collection("appointments")
      .doc(appointment.appointmentId)
      .get();

    if (!snapshot.exists) {
      logger.warn(
        "Unable to enrich appointment email: document not found.",
        {
          appointmentId: appointment.appointmentId,
        },
      );

      return appointment;
    }

    const data = snapshot.data();

    if (!data) {
      return appointment;
    }

    const services = parseAppointmentServices(
      data.services,
    );

    if (services.length === 0) {
      return appointment;
    }

    const servicesCountValue =
      typeof data.servicesCount === "number" ?
        Math.trunc(data.servicesCount) :
        services.length;

    return {
      ...appointment,
      services,
      servicesCount: servicesCountValue,
    };
  } catch (error) {
    logger.error(
      "Unable to load services for appointment email.",
      {
        appointmentId: appointment.appointmentId,
        error,
      },
    );

    // Il sistema email continua a funzionare con il formato precedente.
    return appointment;
  }
}

/**
 * Converte il campo services di Firestore nel formato delle email.
 *
 * @param {unknown} value Campo services salvato nell'appuntamento.
 * @return {AppointmentEmailService[]} Servizi validi.
 */
function parseAppointmentServices(
  value: unknown,
): AppointmentEmailService[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter(
      (item): item is Record<string, unknown> =>
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item),
    )
    .map((service) => {
      const extrasValue = service.extras;

      const extras = Array.isArray(extrasValue) ?
        extrasValue
          .filter(
            (item): item is Record<string, unknown> =>
              item !== null &&
              typeof item === "object" &&
              !Array.isArray(item),
          )
          .map((extra) => ({
            id: optionalString(extra.id),
            name: optionalString(extra.name) || "Extra",
            price: optionalNumber(extra.price),
            duration: optionalNumber(extra.duration),
          })) :
        [];

      return {
        serviceId: optionalString(
          service.serviceId,
        ),
        name:
          optionalString(service.name) ||
          "Servizio",
        price: optionalNumber(service.price),
        duration: optionalNumber(
          service.duration,
        ),
        extras,
        totalPrice: optionalNumber(
          service.totalPrice,
        ),
        totalDuration: optionalNumber(
          service.totalDuration,
        ),
      };
    });
}

/**
 * Converte un valore in stringa opzionale.
 *
 * @param {unknown} value Valore originale.
 * @return {string|undefined} Stringa convertita.
 */
function optionalString(
  value: unknown,
): string | undefined {
  if (value === null || value === undefined) {
    return undefined;
  }

  const result = String(value).trim();

  return result.length > 0 ?
    result :
    undefined;
}

/**
 * Converte un valore numerico proveniente da Firestore.
 *
 * @param {unknown} value Valore originale.
 * @return {number|undefined} Numero convertito.
 */
function optionalNumber(
  value: unknown,
): number | undefined {
  if (typeof value === "number") {
    return Number.isFinite(value) ?
      value :
      undefined;
  }

  if (typeof value === "string") {
    const normalized = value
      .replace(",", ".")
      .trim();

    const parsed = Number(normalized);

    return Number.isFinite(parsed) ?
      parsed :
      undefined;
  }

  return undefined;
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