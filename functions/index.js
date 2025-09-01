const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const rateLimits = new Map();
function checkRate(uid, name, ms) {
  const key = `${uid}_${name}`;
  const now = Date.now();
  const last = rateLimits.get(key) || 0;
  if (now - last < ms) {
    functions.logger.warn('rate_limited', { uid, name });
    throw new functions.https.HttpsError('resource-exhausted', 'Too many requests');
  }
  rateLimits.set(key, now);
}

// REGION: generateColorPlanV2
exports.generateColorPlanV2 = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  if (!context.app) throw new functions.https.HttpsError('failed-precondition', 'App Check required');

  const { projectId, paletteColorIds, vibe, context: ctx } = data || {};
  if (typeof projectId !== 'string' || !Array.isArray(paletteColorIds) || paletteColorIds.length === 0) {
    functions.logger.info('function_input_invalid', { name: 'generateColorPlanV2' });
    throw new functions.https.HttpsError('invalid-argument', 'Invalid inputs');
  }
  checkRate(context.auth.uid, 'generateColorPlanV2', 2000);

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
    debugLightingProfile: ctx?.lightingProfile || null,
  };
});
// END REGION: generateColorPlanV2

// REGION: generateColorPlanV1
exports.generateColorPlanV1 = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  if (!context.app) throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  checkRate(context.auth.uid, 'generateColorPlanV1', 2000);

  const { room = 'living room', style = 'modern', palette, paletteName, colors } = data || {};
  let safeName = 'Untitled Palette';
  let hexes = [];
  if (palette?.items?.length) {
    safeName = String(palette.name || 'Untitled');
    hexes = palette.items.map(i => i.hex);
  } else if (Array.isArray(colors) && colors.length > 0 && paletteName) {
    safeName = String(paletteName);
    hexes = colors;
  }

  const uid = context.auth.uid;
  const db = admin.firestore();
  const docRef = db.collection('colorStories').doc();
  await docRef.set({
    id: docRef.id,
    ownerId: uid,
    name: safeName,
    room,
    style,
    palette: {
      name: safeName,
      hexes,
      items: hexes.map(hex => ({ hex })),
    },
    status: 'complete',
    progress: 1.0,
    progressMessage: 'Story ready',
    narration: `This beautiful ${style} ${room} showcases a carefully curated palette. Each color has been selected to create harmony and visual interest.`,
    usageGuide: hexes.slice(0, 4).map((hex, i) => ({
      role: ['Main walls', 'Trim', 'Accent', 'Details'][i],
      hex,
      name: `Color ${i + 1}`,
      brandName: 'Premium Paint',
      code: `${i + 1}00`,
      surface: ['Walls', 'Trim', 'Feature wall', 'Accents'][i],
      finishRecommendation: 'Eggshell finish recommended',
      sheen: 'Eggshell',
      howToUse: `Apply to ${['walls','trim','accent areas','details'][i]} for best results`
    })),
    heroImageUrl: `data:image/svg+xml;base64,${Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300"><rect width="400" height="300" fill="${hexes[0] || '#888888'}"/></svg>`).toString('base64')}`,
    access: 'private',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { storyId: docRef.id, docId: docRef.id };
});
// END REGION: generateColorPlanV1

// REGION: viaReply
exports.viaReply = functions.https.onCall((data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  if (!context.app) throw new functions.https.HttpsError('failed-precondition', 'App Check required');

  const { context: ctx, state } = data || {};
  if (typeof ctx !== 'string') {
    functions.logger.info('function_input_invalid', { name: 'viaReply' });
    throw new functions.https.HttpsError('invalid-argument', 'context required');
  }
  checkRate(context.auth.uid, 'viaReply', 500);

  const action = (state && state.action) || '';
  let text;
  switch (action.toLowerCase()) {
    case 'explain':
      text = `Explanation for ${ctx}`;
      break;
    case 'simplify':
      text = `Simplified ${ctx}`;
      break;
    case 'budget':
      text = `Budget advice for ${ctx}`;
      break;
    default:
      text = `No suggestion for ${ctx}`;
  }
  return { text };
});
// END REGION: viaReply

// REGION: awardReferral
exports.awardReferral = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  }
  if (!context.app) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }
  const { referrerId } = data || {};
  if (typeof referrerId !== 'string') {
    functions.logger.info('function_input_invalid', { name: 'awardReferral' });
    throw new functions.https.HttpsError('invalid-argument', 'referrerId required');
  }
  checkRate(context.auth.uid, 'awardReferral', 1000);
  const db = admin.firestore();
  const increment = admin.firestore.FieldValue.increment(1);
  await db
      .collection('users').doc(referrerId)
      .collection('meta').doc('rewards')
      .set({ hqBonusRenders: increment }, { merge: true });
  await db
      .collection('users').doc(context.auth.uid)
      .collection('meta').doc('rewards')
      .set({ hqBonusRenders: increment }, { merge: true });
  functions.logger.info('reward_issued', { type: 'referral' });
  return { ok: true };
});
// END REGION: awardReferral

