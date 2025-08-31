const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.generateColorPlanV1 = functions.https.onCall(async (data, context) => {
  try {
    console.log('generateColorPlanV1 called with context:', JSON.stringify(context.auth));
    console.log('generateColorPlanV1 data:', JSON.stringify(data));
    
    const uid = context.auth?.uid;
    if (!uid) {
      console.error('generateColorPlanV1: No authenticated user');
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required to generate color plans. Please sign in and try again.');
    }

    console.log('generateColorPlanV1: Authenticated user:', uid);
    
    // Get basic data from request
    const { room = "living room", style = "modern", palette, paletteName, colors } = data || {};
    
    // Simple palette normalization
    let safeName = "Untitled Palette";
    let hexes = [];
    
    if (palette?.items?.length) {
      safeName = String(palette.name || "Untitled");
      hexes = palette.items.map(i => i.hex);
    } else if (Array.isArray(colors) && colors.length > 0 && paletteName) {
      safeName = String(paletteName);
      hexes = colors;
    }
    
    // Create Firestore document with minimal data
    const db = admin.firestore();
    const docRef = db.collection("colorStories").doc();
    
    await docRef.set({
      id: docRef.id,
      ownerId: uid,
      name: safeName,
      room,
      style,
      palette: {
        name: safeName,
        hexes,
        items: hexes.map(hex => ({ hex }))
      },
      status: "complete",
      progress: 1.0,
      progressMessage: "Story ready",
      narration: `This beautiful ${style} ${room} showcases a carefully curated palette. Each color has been selected to create harmony and visual interest.`,
      usageGuide: hexes.slice(0, 4).map((hex, i) => ({
        role: ["Main walls", "Trim", "Accent", "Details"][i],
        hex,
        name: `Color ${i + 1}`,
        brandName: "Premium Paint",
        code: `${i + 1}00`,
        surface: ["Walls", "Trim", "Feature wall", "Accents"][i],
        finishRecommendation: "Eggshell finish recommended",
        sheen: "Eggshell",
        howToUse: `Apply to ${["walls", "trim", "accent areas", "details"][i]} for best results`
      })),
      heroImageUrl: `data:image/svg+xml;base64,${Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300"><rect width="400" height="300" fill="${hexes[0] || '#888888'}"/></svg>`).toString('base64')}`,
      access: "private",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { storyId: docRef.id, docId: docRef.id };
    
  } catch (error) {
    console.error("generateColorPlanV1 error:", error);
    console.error("generateColorPlanV1 error type:", typeof error);
    console.error("generateColorPlanV1 error code:", error.code);
    console.error("generateColorPlanV1 error message:", error.message);
    
    // If it's already a proper HttpsError, rethrow it
    if (error.code && error.code.startsWith('functions/')) {
      throw error;
    }
    
    // Handle specific error types
    if (error.message && error.message.includes('auth')) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication error: ' + error.message);
    }
    
    throw new functions.https.HttpsError('internal', error.message || "Color story generation failed");
  }
});