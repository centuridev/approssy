import * as logger from "firebase-functions/logger";
import {EMAIL_CONFIG} from "../config/emailConfig";
import {createEmailTransporter} from "./emailTransporter";

export interface SendEmailParams {
  to: string;
  subject: string;
  html: string;
  text: string;
  appointmentId?: string;
  eventType?: string;
}

/**
 * Invia un'email tramite il server SMTP di Hostinger.
 *
 * @param {SendEmailParams} params Contenuto e destinatario dell'email.
 * @return {Promise<string>} Identificativo assegnato dal server SMTP.
 */
export async function sendEmail({
  to,
  subject,
  html,
  text,
  appointmentId,
  eventType,
}: SendEmailParams): Promise<string> {
  const recipient = to.trim().toLowerCase();

  if (!recipient) {
    throw new Error("Recipient email is missing.");
  }

  const transporter = createEmailTransporter();

  try {
    const result = await transporter.sendMail({
      from: {
        name: EMAIL_CONFIG.from.name,
        address: EMAIL_CONFIG.from.address,
      },
      replyTo: EMAIL_CONFIG.replyTo,
      to: recipient,
      subject,
      text,
      html,
    });

    logger.info("Email sent successfully.", {
      recipient,
      messageId: result.messageId,
      appointmentId: appointmentId ?? null,
      eventType: eventType ?? null,
    });

    return result.messageId;
  } catch (error) {
    logger.error("Email delivery failed.", {
      recipient,
      appointmentId: appointmentId ?? null,
      eventType: eventType ?? null,
      error: error instanceof Error ? error.message : String(error),
    });

    throw error;
  }
}