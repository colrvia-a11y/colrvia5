const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();

// Simple rate limiting helper
const rateLimits = new Map();
function checkRate(uid, name, ms) {
  const key = `${uid}_${name}`;
  const now = Date.now();
  const last = rateLimits.get(key) || 0;
  if (now - last < ms) {
    functions.logger.warn("rate_limited", { uid, name });
    throw new functions.https.HttpsError(
      "resource-exhausted",
      "Too many requests"
    );
  }
  rateLimits.set(key, now);
}

// ✅ Via Reply (Gemini version)
const gemini = new GoogleGenerativeAI(functions.config().gemini.key);

exports.viaReply = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Auth required");
  }
  if (!context.app) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "App Check required"
    );
  }

  const { context: ctx, state } = data || {};
  if (typeof ctx !== "string") {
    functions.logger.info("function_input_invalid", { name: "viaReply" });
    throw new functions.https.HttpsError("invalid-argument", "context required");
  }

  // Throttle repeated calls
  checkRate(context.auth.uid, "viaReply", 1000);

  const prompt = `
You are Via, a friendly paint and color design assistant.
Context: ${ctx}
User state: ${JSON.stringify(state)}
Give clear, conversational, and helpful guidance about home colors, palettes, and design.
`;

  try {
    const model = gemini.getGenerativeModel({ model: "gemini-1.5-flash" });

    const result = await model.generateContent(prompt);
    const text = result.response.text();

    return { text };
  } catch (err) {
    functions.logger.error("viaReply_error", err);
    throw new functions.https.HttpsError("internal", "AI request failed");
  }
});

// Deterministic palette generation onCall
const { generatePalette } = require("./generator.js");

exports.generatePaletteOnCall = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Auth required");
  }
  if (!context.app) {
    throw new functions.https.HttpsError("failed-precondition", "App Check required");
  }

  const uid = context.auth.uid;
  const answers = data && data.answers;
  if (!answers || typeof answers !== "object") {
    throw new functions.https.HttpsError("invalid-argument", "answers object required");
  }

  // Minimal validation for required fields
  const required = ["roomType","usage","moodWords","daytimeBrightness","bulbColor","boldDarkerSpot","brandPreference"];
  for (const k of required) {
    if (!(k in answers)) {
      throw new functions.https.HttpsError("invalid-argument", `Missing field: ${k}`);
    }
  }

  try {
    const out = generatePalette(answers);

    // Best-effort job log
    try {
      await admin.firestore().collection("paletteJobs").add({
        uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        answers,
        output: out,
      });
    } catch (e) {
      functions.logger.warn("palette_job_log_failed", { error: String(e) });
    }

    return { ok: true, palette: out };
  } catch (e) {
    functions.logger.error("generate_palette_error", e);
    throw new functions.https.HttpsError("failed-precondition", String(e.message || e));
  }
});

// Create a talk session (start-now or scheduled)
exports.createTalkSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Auth required");
  }
  if (!context.app) {
    throw new functions.https.HttpsError("failed-precondition", "App Check required");
  }

  const uid = context.auth.uid;
  const when = data && data.scheduledAt;
  const now = admin.firestore.Timestamp.now();

  const payload = {
    uid,
    status: when ? "scheduled" : "ready",
    scheduledAt: when ? admin.firestore.Timestamp.fromDate(new Date(when)) : null,
    answersSnapshot: (data && data.answers) || {},
    createdAt: now,
    progress: 0,
  };

  const docRef = await admin.firestore().collection("talkSessions").add(payload);
  return { sessionId: docRef.id };
});

// Issue an ephemeral token for the Voice Gateway (placeholder; replace with signed JWT)
exports.issueVoiceGatewayToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Auth required");
  }
  if (!context.app) {
    throw new functions.https.HttpsError("failed-precondition", "App Check required");
  }

  const uid = context.auth.uid;
  const sessionId = data && data.sessionId;
  if (!sessionId) {
    throw new functions.https.HttpsError("invalid-argument", "sessionId");
  }

  // Short-lived opaque token (5 minutes). Replace with real signed JWT from your Voice Gateway.
  const token = Buffer.from(JSON.stringify({ uid, sessionId, exp: Date.now() + 1000 * 60 * 5 })).toString("base64url");
  return { token };
});
