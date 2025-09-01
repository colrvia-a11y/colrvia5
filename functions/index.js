const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

<<<<<<< HEAD
// NOTE: Replace model invocation with your actual AI provider call.
exports.generateColorPlanV2 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Auth required');
=======
// REGION: CODEX-ADD color-plan-fn
exports.generateColorPlanV2 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { projectId, paletteColorIds, vibe, context: ctx } = data || {};
  if (!projectId || !Array.isArray(paletteColorIds) || paletteColorIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing inputs');
  }

  const placementMap = paletteColorIds.map((id, i) => ({
    area: ['walls', 'trim', 'ceiling'][i] || 'walls',
    colorId: id,
    sheen: ['eggshell', 'semi-gloss', 'matte'][i] || 'eggshell',
  }));

  return {
    name: vibe || 'Color Plan',
    vibe: vibe || '',
    paletteColorIds,
    placementMap,
    cohesionTips: ['Repeat trim color for unity.', 'Limit palette to three main hues.'],
    accentRules: [
      { context: 'north-facing room', guidance: 'Favor warm undertones.' },
      { context: 'small space', guidance: 'Use lighter colors to expand feel.' },
    ],
    doDont: [
      { do: 'Prime before painting.', dont: "Don't skip surface prep." },
    ],
    sampleSequence: ['Order samples', 'Test in different light', 'Confirm selection'],
    roomPlaybook: [
      { roomType: 'living', placements: placementMap, notes: 'Adjust accents as needed.' },
    ],
  };
});
// END REGION: CODEX-ADD color-plan-fn

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
>>>>>>> 23841be2546629ccb041fa44367169f7b1649397
  }
  const { projectId, paletteColorIds, vibe, context: ctx } = data;
  if (!projectId || !Array.isArray(paletteColorIds) || paletteColorIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing inputs');
  }


  // Fake AI synthesis for scaffolding. Replace with real AI call.
  const placementMap = [
    { area: 'walls', colorId: paletteColorIds[0], sheen: 'eggshell' },
    { area: 'trim', colorId: paletteColorIds[1] || paletteColorIds[0], sheen: 'semi-gloss' },
    { area: 'ceiling', colorId: paletteColorIds[2] || paletteColorIds[0], sheen: 'matte' },
  ];
  const cohesionTips = [
    'Repeat trim color on doors for cohesion.',
    'Maintain consistent LRV deltas between adjacent rooms.',
  ];
  const accentRules = [
    { context: 'north-facing room', guidance: 'Prefer warmer undertones to balance cool light.' },
    { context: 'small room', guidance: 'Use lighter LRV on walls to expand perceived space.' }
  ];
  const doDont = [
    { do: 'Cut in with trim color after two wall coats.', dont: 'Don\'t mix sheens within the same surface.' }
  ];
  const sampleSequence = [ 'Order peel-and-stick for top 3 wall contenders', 'Evaluate in morning/evening', 'Commit to final set' ];
  const roomPlaybook = [
    { roomType: 'living', placements: [ placementMap[0], placementMap[1] ], notes: 'Feature wall optional.' },
    { roomType: 'kitchen', placements: [ { area: 'cabinets', colorId: paletteColorIds[1] || paletteColorIds[0], sheen: 'satin' } ], notes: 'Use scrub-resistant sheen.' },
  ];


  return {
    name: vibe || 'Balanced, cohesive home palette',
    vibe: vibe || 'Warm-modern comfort',
    paletteColorIds,
    placementMap,
    cohesionTips,
    accentRules,
    doDont,
    sampleSequence,
    roomPlaybook,
  };
});