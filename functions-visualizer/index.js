import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getStorage } from 'firebase-admin/storage';
import { getFirestore } from 'firebase-admin/firestore';
import * as functions from 'firebase-functions';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { v4 as uuidv4 } from 'uuid';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const bucket = getStorage().bucket();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY; // Set in env
const MODEL_IMAGE = 'gemini-2.5-flash-image-preview'; // latest image-capable Flash model

function buildSurfaceInstruction({ roomType, surfaces, hex, keepAspect = true }) {
  const scope = surfaces && surfaces.length ? surfaces.join(', ') : 'walls';
  return [
    `Using the provided photo of a ${roomType}, change ONLY the ${scope} to color ${hex}.`,
    'Keep all other surfaces exactly the same (cabinets, countertops, flooring, furniture, metal finishes, appliances, windows, doors, textiles).',
    'Preserve the original lighting, textures, reflections, shadows, and perspective.',
    keepAspect ? 'Do not change the original aspect ratio.' : '',
    'Do not add or remove objects. No style changes beyond the paint color change.'
  ].join(' ');
}

async function fetchImageAsBase64(gsPath) {
  const [fileBuffer] = await bucket.file(gsPath.replace('gs://', '').split('.appspot.com/')[1]).download();
  return fileBuffer.toString('base64');
}

async function savePngToStorage({ uid, jobId, idx, base64Png }) {
  const filePath = `visualizer/${uid}/jobs/${jobId}/variant-${idx}.png`;
  const file = bucket.file(filePath);
  await file.save(Buffer.from(base64Png, 'base64'), { contentType: 'image/png', resumable: false });
  const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + 1000 * 60 * 60 * 24 * 7 });
  return { filePath: `gs://${bucket.name}/${filePath}`, downloadUrl: url };
}

export const visualizerGenerate = functions.region('us-central1').https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  const uid = context.auth.uid;
  const { inputGsPath, roomType = 'interior room', surfaces = ['walls'], variantHexes = [], note = '', storyId = null } = data || {};
  if (!inputGsPath) throw new functions.https.HttpsError('invalid-argument', 'inputGsPath is required (gs://...)');
  if (!Array.isArray(variantHexes) || variantHexes.length === 0) throw new functions.https.HttpsError('invalid-argument', 'variantHexes must be a non-empty array of HEX strings.');
  if (!GEMINI_API_KEY) throw new functions.https.HttpsError('failed-precondition', 'GEMINI_API_KEY not configured.');

  const jobId = uuidv4();
  const createdAt = new Date();
  await db.collection('visualizerJobs').doc(jobId).set({
    uid, inputGsPath, roomType, surfaces, variantHexes, note, storyId,
    status: 'running', createdAt, updatedAt: createdAt
  });

  const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
  // Important: Gemini image models require image+text with image output modality.
  const model = genAI.getGenerativeModel({ model: MODEL_IMAGE, generationConfig: { responseMimeType: 'image/png', responseModalities: ['TEXT','IMAGE'] } });

  // Load base image
  const base64 = await fetchImageAsBase64(inputGsPath);
  const imagePart = { inlineData: { mimeType: 'image/png', data: base64 } };

  const results = [];
  let idx = 0;
  for (const hex of variantHexes) {
    const prompt = buildSurfaceInstruction({ roomType, surfaces, hex });

    const response = await model.generateContent({
      contents: [{ role: 'user', parts: [ imagePart, { text: prompt } ] }]
    });

    // Gemini image output appears on candidates[0].content.parts with inlineData
    const cand = response?.response?.candidates?.[0];
    const parts = cand?.content?.parts || [];
    const firstImage = parts.find(p => p?.inlineData?.data);
    if (!firstImage) throw new Error('No image returned from Gemini.');
    const { data: outBase64 } = firstImage.inlineData;

    const saved = await savePngToStorage({ uid, jobId, idx, base64Png: outBase64 });
    results.push({ hex, ...saved });
    idx++;
  }

  await db.collection('visualizerJobs').doc(jobId).update({ status: 'complete', updatedAt: new Date(), results });

  if (storyId) {
    await db.collection('colorStories').doc(storyId).collection('visuals').add({ uid, jobId, results, createdAt: new Date() });
  }

  return { jobId, results };
});

export const visualizerMockup = functions.region('us-central1').https.onCall( async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  const uid = context.auth.uid;
  const { roomType = 'living room', style = 'modern minimal', aspect = 'landscape', variants = [], note = '' } = data || {};
  if (!variants.length) throw new functions.https.HttpsError('invalid-argument', 'variants is a non-empty array of HEX strings.');
  if (!GEMINI_API_KEY) throw new functions.https.HttpsError('failed-precondition', 'GEMINI_API_KEY not configured.');

  const jobId = uuidv4();
  const createdAt = new Date();
  await db.collection('visualizerJobs').doc(jobId).set({ uid, mode: 'mockup', roomType, style, aspect, variants, note, status: 'running', createdAt, updatedAt: createdAt });

  const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: MODEL_IMAGE, generationConfig: { responseMimeType: 'image/png', responseModalities: ['TEXT','IMAGE'] } });

  const basePrompt = (hex) => [
    `Photorealistic ${roomType} in ${style} style.`,
    `Paint the walls color ${hex}.`,
    'Trim is soft white; keep lighting soft and natural; no people; realistic furniture.',
    'Do not add text. Maintain consistent camera and composition across variants.'
  ].join(' ');

  const results = [];
  let idx = 0;
  for (const hex of variants) {
    const resp = await model.generateContent({ contents: [{ role: 'user', parts: [{ text: basePrompt(hex) }] }] });
    const cand = resp?.response?.candidates?.[0];
    const parts = cand?.content?.parts || [];
    const firstImage = parts.find(p => p?.inlineData?.data);
    if (!firstImage) throw new Error('No image returned from Gemini.');
    const outBase64 = firstImage.inlineData.data;
    const saved = await savePngToStorage({ uid, jobId, idx, base64Png: outBase64 });
    results.push({ hex, ...saved });
    idx++;
  }

  await db.collection('visualizerJobs').doc(jobId).update({ status: 'complete', updatedAt: new Date(), results });
  return { jobId, results };
});