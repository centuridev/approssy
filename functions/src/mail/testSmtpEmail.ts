import {Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {SMTP_PASSWORD} from "../config/emailConfig";
import {sendEmail} from "./sendEmail";
import {buildSmtpTestEmail} from "./templates";

const REGION = "europe-west8";

/**
 * Invia un'email di prova quando viene creato un documento
 * nella collezione smtpEmailTests.
 *
 * @return {Promise<void>} Operazione completata.
 */
export const testSmtpEmail = onDocumentCreated(
  {
    document: "smtpEmailTests/{testId}",
    region: REGION,
    secrets: [SMTP_PASSWORD],
  },
  async (event): Promise<void> => {
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn("SMTP test document is missing.");
      return;
    }

    const data = snapshot.data();
    const recipientEmail =
      typeof data.to === "string" ? data.to.trim() : "";

    if (!recipientEmail) {
      await snapshot.ref.update({
        status: "error",
        error: "Recipient email is missing.",
        updatedAt: Timestamp.now(),
      });

      return;
    }

    const template = buildSmtpTestEmail();

    try {
      const messageId = await sendEmail({
        to: recipientEmail,
        subject: template.subject,
        html: template.html,
        text: template.text,
        eventType: "smtp_test",
      });

      await snapshot.ref.update({
        status: "sent",
        messageId,
        sentAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);

      logger.error("SMTP test failed.", {
        testId: snapshot.id,
        error: errorMessage,
      });

      await snapshot.ref.update({
        status: "error",
        error: errorMessage,
        updatedAt: Timestamp.now(),
      });
    }
  },
);