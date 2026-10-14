import { defineString } from "firebase-functions/params";

/**
 * Region for every function. Override with the FUNCTION_REGION env var / param
 * (e.g. functions/.env.<project>: FUNCTION_REGION=europe-west1). Default: us-central1.
 *
 * NOTE: Firestore triggers must run in a region compatible with the Firestore
 * database location; set FUNCTION_REGION accordingly.
 */
export const FUNCTION_REGION = defineString("FUNCTION_REGION", {
  default: "us-central1",
  description: "Region in which Cloud Functions are deployed",
});

/** Android notification channel the Flutter app must create. */
export const ANDROID_CHANNEL_ID = "messages";
