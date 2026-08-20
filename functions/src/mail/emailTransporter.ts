import * as nodemailer from "nodemailer";
import {
  EMAIL_CONFIG,
  SMTP_PASSWORD,
} from "../config/emailConfig";

/**
 * Crea e restituisce il transporter SMTP configurato per Hostinger.
 *
 * @return {nodemailer.Transporter} Il transporter SMTP configurato.
 */
export function createEmailTransporter(): nodemailer.Transporter {
  return nodemailer.createTransport({
    host: EMAIL_CONFIG.host,
    port: EMAIL_CONFIG.port,
    secure: EMAIL_CONFIG.secure,
    auth: {
      user: EMAIL_CONFIG.user,
      pass: SMTP_PASSWORD.value(),
    },
    connectionTimeout: 15_000,
    greetingTimeout: 15_000,
    socketTimeout: 30_000,
  });
}