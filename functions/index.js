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
