export interface EmailTemplate {
  subject: string;
  text: string;
  html: string;
}

/**
 * Genera l'email utilizzata per verificare la configurazione SMTP.
 *
 * @return {EmailTemplate} Contenuto completo dell'email.
 */
export function buildSmtpTestEmail(): EmailTemplate {
  const subject =
    "Configurazione email completata – Rosi Beauty Premium";

  const text = [
    "Rosi Beauty Premium",
    "",
    "Il sistema automatico di comunicazione è stato configurato",
    "correttamente.",
    "",
    "Le email saranno inviate da:",
    "prenotazioni@rosibeautypremium.it",
  ].join("\n");

  const html = `
    <!doctype html>
    <html lang="it">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width">
        <title>${subject}</title>
      </head>

      <body style="
        margin: 0;
        padding: 24px 12px;
        background: #f4f4f4;
        font-family: Arial, Helvetica, sans-serif;
        color: #222222;
      ">
        <div style="
          max-width: 620px;
          margin: 0 auto;
          overflow: hidden;
          background: #ffffff;
          border: 1px solid #ead8b5;
          border-radius: 16px;
        ">
          <div style="
            padding: 28px 20px;
            background: #111111;
            text-align: center;
          ">
            <div style="
              color: #dda33b;
              font-size: 27px;
              font-weight: 700;
            ">
              Rosi Beauty Premium
            </div>

            <div style="
              margin-top: 7px;
              color: #ffffff;
              font-size: 12px;
              letter-spacing: 1.5px;
            ">
              BEAUTY &amp; PRENOTAZIONI
            </div>
          </div>

          <div style="padding: 32px;">
            <h1 style="
              margin: 0 0 18px;
              color: #b47d19;
              font-size: 24px;
            ">
              Configurazione completata
            </h1>

            <p style="
              margin: 0 0 18px;
              font-size: 16px;
              line-height: 1.65;
            ">
              Il sistema automatico di comunicazione di
              <strong>Rosi Beauty Premium</strong> è stato configurato
              correttamente.
            </p>

            <div style="
              margin: 24px 0;
              padding: 18px;
              background: #fffaf1;
              border-left: 5px solid #dda33b;
              border-radius: 8px;
            ">
              <p style="margin: 0 0 8px;">
                <strong>Mittente:</strong>
              </p>

              <p style="margin: 0;">
                prenotazioni@rosibeautypremium.it
              </p>
            </div>

            <p style="
              margin: 22px 0 0;
              font-size: 15px;
              line-height: 1.6;
            ">
              Le conferme, gli annullamenti e i promemoria degli
              appuntamenti utilizzeranno questo indirizzo.
            </p>
          </div>

          <div style="
            padding: 18px;
            background: #111111;
            color: #dddddd;
            text-align: center;
            font-size: 12px;
          ">
            Email automatica di Rosi Beauty Premium
          </div>
        </div>
      </body>
    </html>
  `;

  return {
    subject,
    text,
    html,
  };
}