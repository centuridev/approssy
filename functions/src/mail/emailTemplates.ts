import {Timestamp} from "firebase-admin/firestore";

const BUSINESS_NAME = "Rosi Beauty Premium";
const BUSINESS_EMAIL = "prenotazioni@rosibeautypremium.it";
const TIME_ZONE = "Europe/Rome";

export interface AppointmentEmailData {
  appointmentId: string;
  clientName: string;
  clientLastName?: string;
  clientEmail?: string;
  clientPhone?: string;
  serviceName: string;
  serviceDuration: number;
  servicePrice?: number;
  selectedDateTime: Timestamp;
  businessAddress?: string;
}

export interface EmailTemplate {
  subject: string;
  text: string;
  html: string;
}

interface TemplateCopy {
  title: string;
  message: string;
  accentMessage?: string;
  footerMessage?: string;
  showCalendarButton?: boolean;
}

interface FormattedAppointment {
  fullClientName: string;
  formattedDate: string;
  formattedTime: string;
  formattedPrice: string;
  calendarUrl: string;
}

/**
 * Genera l'email inviata al cliente quando la richiesta è in attesa.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildPendingClientEmail(
  appointment: AppointmentEmailData,
): EmailTemplate {
  const copy: TemplateCopy = {
    title: "Richiesta ricevuta",
    message:
      "Abbiamo ricevuto la tua richiesta di prenotazione. " +
      "L'appuntamento è in attesa di conferma.",
    accentMessage:
      "Riceverai una nuova comunicazione non appena la prenotazione " +
      "sarà confermata.",
    footerMessage:
      "Non è necessario inviare un'altra richiesta per lo stesso orario.",
  };

  return buildAppointmentTemplate(
    appointment,
    "Richiesta di prenotazione ricevuta – Rosi Beauty Premium",
    copy,
  );
}

/**
 * Genera l'email inviata all'amministratore per una nuova richiesta.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildNewBookingAdminEmail(
  appointment: AppointmentEmailData,
): EmailTemplate {
  const formatted = formatAppointment(appointment);

  const copy: TemplateCopy = {
    title: "Nuova richiesta di prenotazione",
    message:
      `<strong>${formatted.fullClientName}</strong> ha inviato una ` +
      "nuova richiesta di appuntamento.",
    accentMessage:
      "Apri l'applicazione amministratore per confermare o rifiutare " +
      "la prenotazione.",
    footerMessage:
      "La richiesta rimarrà in attesa fino alla gestione da parte " +
      "dell'amministratore.",
  };

  return buildAppointmentTemplate(
    appointment,
    `Nuova prenotazione – ${formatted.fullClientName}`,
    copy,
    true,
  );
}

/**
 * Genera l'email di conferma dell'appuntamento.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildConfirmedEmail(
  appointment: AppointmentEmailData,
): EmailTemplate {
  const copy: TemplateCopy = {
    title: "Prenotazione confermata",
    message:
      "La tua prenotazione è stata confermata. " +
      "Di seguito trovi tutti i dettagli dell'appuntamento.",
    accentMessage:
      "Ti consigliamo di presentarti qualche minuto prima " +
      "dell'orario indicato.",
    footerMessage:
      "Per eventuali comunicazioni puoi rispondere direttamente " +
      "a questa email.",
    showCalendarButton: true,
  };

  return buildAppointmentTemplate(
    appointment,
    "Prenotazione confermata – Rosi Beauty Premium",
    copy,
  );
}

/**
 * Genera l'email relativa a una prenotazione rifiutata.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildRejectedEmail(
  appointment: AppointmentEmailData,
): EmailTemplate {
  const copy: TemplateCopy = {
    title: "Prenotazione non confermata",
    message:
      "Purtroppo non è stato possibile confermare la richiesta " +
      "di appuntamento indicata.",
    accentMessage:
      "Puoi tornare nell'applicazione e scegliere una nuova data " +
      "o un nuovo orario disponibile.",
    footerMessage:
      "Ci dispiace per l'inconveniente e speriamo di poterti " +
      "accogliere presto.",
  };

  return buildAppointmentTemplate(
    appointment,
    "Aggiornamento prenotazione – Rosi Beauty Premium",
    copy,
  );
}

/**
 * Genera l'email relativa a una prenotazione annullata.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildCancelledEmail(
  appointment: AppointmentEmailData,
): EmailTemplate {
  const copy: TemplateCopy = {
    title: "Prenotazione annullata",
    message:
      "La prenotazione indicata è stata annullata correttamente.",
    accentMessage:
      "L'orario è nuovamente disponibile per altre prenotazioni.",
    footerMessage:
      "Puoi utilizzare l'applicazione per prenotare un nuovo " +
      "appuntamento.",
  };

  return buildAppointmentTemplate(
    appointment,
    "Prenotazione annullata – Rosi Beauty Premium",
    copy,
  );
}

/**
 * Genera il promemoria inviato circa 24 ore prima.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildReminder24HoursEmail(
  appointment: AppointmentEmailData,
): EmailTemplate {
  const copy: TemplateCopy = {
    title: "Ci vediamo domani",
    message:
      "Ti ricordiamo che il tuo appuntamento presso " +
      "<strong>Rosi Beauty Premium</strong> è previsto per domani.",
    accentMessage:
      "Controlla qui sotto data, orario e servizio prenotato.",
    footerMessage:
      "In caso di imprevisti, contattaci con il maggior anticipo " +
      "possibile.",
    showCalendarButton: true,
  };

  return buildAppointmentTemplate(
    appointment,
    "Promemoria appuntamento di domani – Rosi Beauty Premium",
    copy,
  );
}

/**
 * Genera il promemoria inviato circa due ore prima.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildReminder2HoursEmail(
  appointment: AppointmentEmailData,
): EmailTemplate {
  const copy: TemplateCopy = {
    title: "Il tuo appuntamento è tra poco",
    message:
      "Mancano circa due ore al tuo appuntamento presso " +
      "<strong>Rosi Beauty Premium</strong>.",
    accentMessage:
      "Ti aspettiamo all'orario indicato nella prenotazione.",
    footerMessage:
      "Ti consigliamo di arrivare qualche minuto prima.",
    showCalendarButton: true,
  };

  return buildAppointmentTemplate(
    appointment,
    "Il tuo appuntamento è tra due ore – Rosi Beauty Premium",
    copy,
  );
}

/**
 * Genera l'email di ringraziamento successiva all'appuntamento.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildThankYouEmail(
  appointment: AppointmentEmailData,
): EmailTemplate {
  const copy: TemplateCopy = {
    title: "Grazie per averci scelto",
    message:
      "È stato un piacere accoglierti presso " +
      "<strong>Rosi Beauty Premium</strong>.",
    accentMessage:
      "La tua soddisfazione è importante per noi.",
    footerMessage:
      "Speriamo di rivederti presto per il tuo prossimo appuntamento.",
  };

  return buildAppointmentTemplate(
    appointment,
    "Grazie per la tua visita – Rosi Beauty Premium",
    copy,
  );
}

/**
 * Costruisce la struttura completa dell'email.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @param {string} subject Oggetto dell'email.
 * @param {TemplateCopy} copy Testi specifici della comunicazione.
 * @param {boolean} showAdminDetails Mostra i contatti del cliente.
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
function buildAppointmentTemplate(
  appointment: AppointmentEmailData,
  subject: string,
  copy: TemplateCopy,
  showAdminDetails = false,
): EmailTemplate {
  const formatted = formatAppointment(appointment);
  const safeServiceName = escapeHtml(appointment.serviceName);
  const safeEmail = escapeHtml(appointment.clientEmail ?? "");
  const safePhone = escapeHtml(appointment.clientPhone ?? "");
  const safeAddress = escapeHtml(appointment.businessAddress ?? "");

  const adminDetails = showAdminDetails ?
    buildAdminDetails(safeEmail, safePhone) :
    "";

  const addressRow = safeAddress ?
    buildDetailRow("Indirizzo", safeAddress) :
    "";

  const priceRow = appointment.servicePrice !== undefined ?
    buildDetailRow("Prezzo", formatted.formattedPrice) :
    "";

  const calendarButton = copy.showCalendarButton ?
    buildCalendarButton(formatted.calendarUrl) :
    "";

  const html = `
<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width">
  <title>${escapeHtml(subject)}</title>
</head>
<body style="
  margin:0;
  padding:24px 12px;
  background:#f4f4f4;
  font-family:Arial,Helvetica,sans-serif;
  color:#222222;
">
  <div style="
    max-width:640px;
    margin:0 auto;
    overflow:hidden;
    background:#ffffff;
    border:1px solid #ead8b5;
    border-radius:16px;
  ">
    <div style="
      padding:30px 20px;
      background:#111111;
      text-align:center;
    ">
      <div style="
        color:#dda33b;
        font-size:28px;
        font-weight:700;
      ">
        Rosi Beauty Premium
      </div>

      <div style="
        margin-top:7px;
        color:#ffffff;
        font-size:12px;
        letter-spacing:1.5px;
      ">
        BEAUTY &amp; PRENOTAZIONI
      </div>
    </div>

    <div style="padding:32px;">
      <h1 style="
        margin:0 0 20px;
        color:#b47d19;
        font-size:25px;
        line-height:1.3;
      ">
        ${copy.title}
      </h1>

      <p style="
        margin:0 0 18px;
        font-size:16px;
        line-height:1.65;
      ">
        Ciao <strong>${formatted.fullClientName}</strong>,
      </p>

      <p style="
        margin:0 0 22px;
        font-size:16px;
        line-height:1.65;
      ">
        ${copy.message}
      </p>

      <div style="
        margin:24px 0;
        padding:20px;
        background:#fffaf1;
        border:1px solid #ead8b5;
        border-left:5px solid #dda33b;
        border-radius:10px;
      ">
        ${buildDetailRow("Servizio", safeServiceName)}
        ${buildDetailRow("Data", formatted.formattedDate)}
        ${buildDetailRow("Ora", formatted.formattedTime)}
        ${buildDetailRow(
    "Durata",
    `${appointment.serviceDuration} minuti`,
  )}
        ${priceRow}
        ${addressRow}
        ${adminDetails}
      </div>

      <div style="
        margin:22px 0;
        padding:17px;
        background:#f7f7f7;
        border-radius:9px;
        font-size:15px;
        line-height:1.6;
      ">
        ${copy.accentMessage ?? ""}
      </div>

      ${calendarButton}

      <p style="
        margin:24px 0 0;
        font-size:15px;
        line-height:1.65;
      ">
        ${copy.footerMessage ?? ""}
      </p>

      <p style="
        margin:30px 0 0;
        font-size:15px;
        line-height:1.6;
      ">
        Grazie,<br>
        <strong>Rosi Beauty Premium</strong>
      </p>
    </div>

    <div style="
      padding:20px;
      background:#111111;
      color:#dddddd;
      text-align:center;
      font-size:12px;
      line-height:1.6;
    ">
      Email automatica di Rosi Beauty Premium<br>
      ${BUSINESS_EMAIL}
    </div>
  </div>
</body>
</html>
  `.trim();

  const text = buildTextVersion(
    appointment,
    copy,
    formatted,
    showAdminDetails,
  );

  return {
    subject,
    text,
    html,
  };
}

/**
 * Costruisce una riga della scheda dei dettagli.
 *
 * @param {string} label Etichetta del valore.
 * @param {string} value Valore visualizzato.
 * @return {string} HTML della riga.
 */
function buildDetailRow(label: string, value: string): string {
  return `
    <p style="margin:0 0 10px;font-size:15px;line-height:1.5;">
      <strong>${label}:</strong> ${value}
    </p>
  `;
}

/**
 * Costruisce le informazioni riservate all'amministratore.
 *
 * @param {string} email Email del cliente.
 * @param {string} phone Numero di telefono del cliente.
 * @return {string} HTML dei dati di contatto.
 */
function buildAdminDetails(email: string, phone: string): string {
  const emailRow = email ? buildDetailRow("Email", email) : "";
  const phoneRow = phone ? buildDetailRow("Telefono", phone) : "";

  return `${emailRow}${phoneRow}`;
}

/**
 * Costruisce il pulsante per Google Calendar.
 *
 * @param {string} calendarUrl Collegamento generato per il calendario.
 * @return {string} HTML del pulsante.
 */
function buildCalendarButton(calendarUrl: string): string {
  return `
    <div style="margin:28px 0;text-align:center;">
      <a
        href="${calendarUrl}"
        target="_blank"
        rel="noopener noreferrer"
        style="
          display:inline-block;
          padding:14px 23px;
          background:#dda33b;
          color:#111111;
          text-decoration:none;
          font-size:14px;
          font-weight:700;
          border-radius:8px;
        "
      >
        AGGIUNGI A GOOGLE CALENDAR
      </a>
    </div>
  `;
}

/**
 * Prepara i dati formattati dell'appuntamento.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {FormattedAppointment} Valori pronti per la visualizzazione.
 */
function formatAppointment(
  appointment: AppointmentEmailData,
): FormattedAppointment {
  const date = appointment.selectedDateTime.toDate();

  const firstName = appointment.clientName.trim();
  const lastName = appointment.clientLastName?.trim() ?? "";

  const fullClientName = escapeHtml(
    [firstName, lastName].filter(Boolean).join(" "),
  );

  const formattedDate = new Intl.DateTimeFormat("it-IT", {
    timeZone: TIME_ZONE,
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(date);

  const formattedTime = new Intl.DateTimeFormat("it-IT", {
    timeZone: TIME_ZONE,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);

  const formattedPrice =
    typeof appointment.servicePrice === "number" ?
      new Intl.NumberFormat("it-IT", {
        style: "currency",
        currency: "EUR",
      }).format(appointment.servicePrice) :
      "";

  return {
    fullClientName: fullClientName || "Cliente",
    formattedDate,
    formattedTime,
    formattedPrice,
    calendarUrl: buildGoogleCalendarUrl(appointment),
  };
}

/**
 * Genera il collegamento per aggiungere l'evento a Google Calendar.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @return {string} Collegamento completo per Google Calendar.
 */
function buildGoogleCalendarUrl(
  appointment: AppointmentEmailData,
): string {
  const startDate = appointment.selectedDateTime.toDate();

  const endDate = new Date(
    startDate.getTime() +
    appointment.serviceDuration * 60 * 1000,
  );

  const parameters = new URLSearchParams({
    action: "TEMPLATE",
    text: `${BUSINESS_NAME} - ${appointment.serviceName}`,
    dates:
      `${toGoogleCalendarDate(startDate)}/` +
      `${toGoogleCalendarDate(endDate)}`,
    details:
      `Appuntamento per ${appointment.serviceName} presso ` +
      BUSINESS_NAME,
    location: appointment.businessAddress ?? "",
    ctz: TIME_ZONE,
  });

  return "https://calendar.google.com/calendar/render?" +
    parameters.toString();
}

/**
 * Converte una data nel formato richiesto da Google Calendar.
 *
 * @param {Date} date Data da convertire.
 * @return {string} Data compatibile con Google Calendar.
 */
function toGoogleCalendarDate(date: Date): string {
  return date
    .toISOString()
    .replace(/[-:]/g, "")
    .replace(/\.\d{3}Z$/, "Z");
}

/**
 * Costruisce la versione testuale alternativa dell'email.
 *
 * @param {AppointmentEmailData} appointment Dati dell'appuntamento.
 * @param {TemplateCopy} copy Testi della comunicazione.
 * @param {FormattedAppointment} formatted Dati formattati.
 * @param {boolean} showAdminDetails Mostra i dati del cliente.
 * @return {string} Versione testuale dell'email.
 */
function buildTextVersion(
  appointment: AppointmentEmailData,
  copy: TemplateCopy,
  formatted: FormattedAppointment,
  showAdminDetails: boolean,
): string {
  const lines = [
    BUSINESS_NAME,
    "",
    copy.title,
    "",
    `Ciao ${stripHtml(formatted.fullClientName)},`,
    "",
    stripHtml(copy.message),
    "",
    `Servizio: ${appointment.serviceName}`,
    `Data: ${formatted.formattedDate}`,
    `Ora: ${formatted.formattedTime}`,
    `Durata: ${appointment.serviceDuration} minuti`,
  ];

  if (appointment.servicePrice !== undefined) {
    lines.push(`Prezzo: ${formatted.formattedPrice}`);
  }

  if (appointment.businessAddress) {
    lines.push(`Indirizzo: ${appointment.businessAddress}`);
  }

  if (showAdminDetails && appointment.clientEmail) {
    lines.push(`Email cliente: ${appointment.clientEmail}`);
  }

  if (showAdminDetails && appointment.clientPhone) {
    lines.push(`Telefono cliente: ${appointment.clientPhone}`);
  }

  lines.push(
    "",
    stripHtml(copy.accentMessage ?? ""),
    "",
    stripHtml(copy.footerMessage ?? ""),
    "",
    BUSINESS_EMAIL,
  );

  return lines.join("\n");
}

/**
 * Protegge i valori dinamici inseriti nel contenuto HTML.
 *
 * @param {string} value Valore originale.
 * @return {string} Valore sicuro per l'HTML.
 */
function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

/**
 * Rimuove i tag HTML dalla versione testuale.
 *
 * @param {string} value Contenuto HTML.
 * @return {string} Contenuto senza tag.
 */
function stripHtml(value: string): string {
  return value.replace(/<[^>]*>/g, "");
}