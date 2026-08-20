import {defineSecret} from "firebase-functions/params";

export const SMTP_PASSWORD = defineSecret("SMTP_PASSWORD");

export const EMAIL_CONFIG = {
  host: "smtp.hostinger.com",
  port: 465,
  secure: true,
  user: "prenotazioni@rosibeautypremium.it",
  from: {
    name: "Rosi Beauty Premium",
    address: "prenotazioni@rosibeautypremium.it",
  },
  replyTo: "prenotazioni@rosibeautypremium.it",
} as const;