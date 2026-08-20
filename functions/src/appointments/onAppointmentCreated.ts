import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

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

const REGION = "europe-west8";

/**
 * Inizializza una nuova prenotazione e invia le comunicazioni.
 */
export const onAppointmentCreated = onDocumentCreated(
  {
    document: "appointments/{appointmentId}",
    region: REGION,
    secrets: [SMTP_PASSWORD],
  },
  async (event): Promise<void> => {
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn("Appointment created without document data.");
      return;
    }

    const appointment = snapshot.data();
    const appointmentId = event.params.appointmentId;

    const updates: Record<string, unknown> = {
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (!appointment.createdAt) {
      updates.createdAt = FieldValue.serverTimestamp();
    }

    if (!appointment.status) {
      updates.status = "pending";
    }

    await snapshot.ref.update(updates);

    logger.info("Appointment initialized.", {
      appointmentId,
      status: appointment.status ?? "pending",
    });

    const clientName = getStringValue(appointment.clientName);
    const clientLastName = getStringValue(
      appointment.clientLastName,
    );

    const fullClientName = [
      clientName,
      clientLastName,
    ]
      .filter(Boolean)
      .join(" ")
      .trim();

    const serviceName =
      getStringValue(appointment.serviceName) ||
      "Servizio beauty";

    const notificationBody = fullClientName ?
      `${fullClientName} ha prenotato: ${serviceName}` :
      `Nuova prenotazione per: ${serviceName}`;

    await sendAdministratorPushNotifications({
      appointmentId,
      notificationBody,
    });

    const emailData = buildAppointmentEmailData({
      appointmentId,
      appointment,
      clientName,
      clientLastName,
      serviceName,
    });

    if (!emailData) {
      logger.warn(
        "Appointment emails skipped because appointment data is incomplete.",
        {
          appointmentId,
          hasSelectedDateTime:
            appointment.selectedDateTime instanceof Timestamp,
        },
      );

      return;
    }

    const emailResults = await Promise.allSettled([
      sendAppointmentEmail({
        type: "new_booking_admin",
        appointment: emailData,
      }),
      sendAppointmentEmail({
        type: "pending_client",
        appointment: emailData,
      }),
    ]);

    const failedEmails = emailResults.filter(
      (result) => result.status === "rejected",
    );

    if (failedEmails.length > 0) {
      logger.error(
        "Some appointment creation emails could not be sent.",
        {
          appointmentId,
          failureCount: failedEmails.length,
        },
      );
    }

    logger.info("Appointment creation communications processed.", {
      appointmentId,
      emailCount: emailResults.length,
      emailFailureCount: failedEmails.length,
    });
  },
);

interface AdministratorPushParams {
  appointmentId: string;
  notificationBody: string;
}

/**
 * Invia la notifica push a tutti gli amministratori.
 *
 * @param {AdministratorPushParams} params Parametri della notifica.
 * @return {Promise<void>} Operazione completata.
 */
async function sendAdministratorPushNotifications({
  appointmentId,
  notificationBody,
}: AdministratorPushParams): Promise<void> {
  const db = getFirestore();

  const administratorsSnapshot = await db
    .collection("utenti")
    .where("role", "==", "admin")
    .get();

  if (administratorsSnapshot.empty) {
    logger.warn(
      "No administrators found for appointment notification.",
      {
        appointmentId,
      },
    );

    return;
  }

  const notificationResults = await Promise.allSettled(
    administratorsSnapshot.docs.map((administratorDocument) =>
      sendAppointmentNotification({
        userId: administratorDocument.id,
        appointmentId,
        title: "Nuova prenotazione",
        body: notificationBody,
        status: "pending",
      }),
    ),
  );

  const failedNotifications = notificationResults.filter(
    (result) => result.status === "rejected",
  );

  if (failedNotifications.length > 0) {
    logger.error(
      "Some administrator notifications could not be processed.",
      {
        appointmentId,
        administratorsCount: administratorsSnapshot.size,
        failureCount: failedNotifications.length,
      },
    );
  }

  logger.info("Administrator push notifications processed.", {
    appointmentId,
    administratorsCount: administratorsSnapshot.size,
    failureCount: failedNotifications.length,
  });
}

interface BuildAppointmentEmailDataParams {
  appointmentId: string;
  appointment: Record<string, unknown>;
  clientName: string;
  clientLastName: string;
  serviceName: string;
}

/**
 * Converte il documento Firestore nei dati richiesti dalle email.
 *
 * @param {BuildAppointmentEmailDataParams} params Dati della prenotazione.
 * @return {AppointmentEmailData|null} Dati email oppure null.
 */
function buildAppointmentEmailData({
  appointmentId,
  appointment,
  clientName,
  clientLastName,
  serviceName,
}: BuildAppointmentEmailDataParams): AppointmentEmailData | null {
  const selectedDateTime = appointment.selectedDateTime;

  if (!(selectedDateTime instanceof Timestamp)) {
    return null;
  }

  const serviceDuration = getNumberValue(
    appointment.serviceDuration,
  );

  return {
    appointmentId,
    clientName: clientName || "Cliente",
    clientLastName,
    clientEmail: getStringValue(appointment.email),
    clientPhone: getStringValue(appointment.phone),
    serviceName,
    serviceDuration,
    servicePrice: getOptionalNumberValue(
      appointment.servicePrice,
    ),
    selectedDateTime,
  };
}

/**
 * Restituisce una stringa sicura da un valore Firestore.
 *
 * @param {unknown} value Valore originale.
 * @return {string} Stringa normalizzata.
 */
function getStringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Restituisce un numero oppure zero.
 *
 * @param {unknown} value Valore originale.
 * @return {number} Numero normalizzato.
 */
function getNumberValue(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ?
    value :
    0;
}

/**
 * Restituisce un numero opzionale.
 *
 * @param {unknown} value Valore originale.
 * @return {number|undefined} Numero normalizzato.
 */
function getOptionalNumberValue(
  value: unknown,
): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ?
    value :
    undefined;
}