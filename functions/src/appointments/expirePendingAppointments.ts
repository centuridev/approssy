import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";

const REGION = "europe-west1";
const TIME_ZONE = "Europe/Rome";
const BATCH_LIMIT = 400;

export const expirePendingAppointments = onSchedule(
  {
    schedule: "every 5 minutes",
    region: REGION,
    timeZone: TIME_ZONE,
    retryCount: 3,
    maxInstances: 1,
  },
  async () => {
    const db = getFirestore();
    const now = Timestamp.now();

    logger.info("Starting pending appointments expiration.", {
      checkedAt: now.toDate().toISOString(),
    });

    let totalExpired = 0;
    let hasMoreAppointments = true;

    while (hasMoreAppointments) {
      const snapshot = await db
        .collection("appointments")
        .where("status", "==", "pending")
        .where("holdUntil", "<=", now)
        .limit(BATCH_LIMIT)
        .get();

      if (snapshot.empty) {
        hasMoreAppointments = false;
        continue;
      }

      const batch = db.batch();

      for (const document of snapshot.docs) {
        batch.update(document.ref, {
          status: "expired",
          expiredAt: now,
          updatedAt: now,
          holdUntil: FieldValue.delete(),
        });
      }

      await batch.commit();

      totalExpired += snapshot.size;

      logger.info("Expired appointment batch processed.", {
        batchSize: snapshot.size,
        totalExpired,
      });

      hasMoreAppointments = snapshot.size === BATCH_LIMIT;
    }

    logger.info("Pending appointments expiration completed.", {
      totalExpired,
    });
  },
);