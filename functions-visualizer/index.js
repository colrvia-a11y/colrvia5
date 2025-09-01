// functions-visualizer/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const enforceAppCheck = process.env.ENFORCE_APPCHECK === 'true';
function requireAppCheck(context) {
  if (enforceAppCheck && !context.app) {
    throw new functions.https.HttpsError('failed-precondition', 'AppCheck token required');
  }
}

const JOBS = new Map();

exports.renderFast = functions.runWith({ maxInstances: 5 }).https.onCall(async (data, context) => {
  requireAppCheck(context);
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const { imageUrl } = data || {};
  if (typeof imageUrl !== 'string') {
    functions.logger.warn('function_input_invalid', { name: 'renderFast' });
    throw new functions.https.HttpsError('invalid-argument', 'imageUrl required');
  }
  const jobId = 'job_' + Date.now();
  const previewUrl = 'https://picsum.photos/seed/' + Math.random().toString(36).slice(2) + '/800/450';
  JOBS.set(jobId, { jobId, status: 'preview', previewUrl, resultUrl: null });
  return JOBS.get(jobId);
});

exports.renderHq = functions.runWith({ maxInstances: 5 }).https.onCall(async (data, context) => {
  requireAppCheck(context);
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const { imageUrl, projectId } = data || {};
  if (typeof imageUrl !== 'string') {
    functions.logger.warn('function_input_invalid', { name: 'renderHq' });
    throw new functions.https.HttpsError('invalid-argument', 'imageUrl required');
  }
  const jobId = 'job_' + Date.now();
  JOBS.set(jobId, { jobId, status: 'queued', previewUrl: null, resultUrl: null });
  setTimeout(() => {
    JOBS.set(jobId, { jobId, status: 'complete', previewUrl: null, resultUrl: 'https://picsum.photos/seed/' + Math.random().toString(36).slice(2) + '/1600/900' });
    admin.messaging().send({
      topic: `user_${context.auth.uid}`,
      data: {
        type: 'viz_hq_complete',
        projectId: projectId || '',
        jobId: jobId,
      }
    }).catch(console.error);
  }, 8000);
  return JOBS.get(jobId);
});

exports.getJob = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const { jobId } = data || {};
  if (typeof jobId !== 'string') {
    functions.logger.warn('function_input_invalid', { name: 'getJob' });
    throw new functions.https.HttpsError('invalid-argument', 'jobId required');
  }
  return JOBS.get(jobId) || { jobId, status: 'unknown' };
});

exports.maskAssist = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const { imageUrl } = data || {};
  if (typeof imageUrl !== 'string') {
    functions.logger.warn('function_input_invalid', { name: 'maskAssist' });
    throw new functions.https.HttpsError('invalid-argument', 'imageUrl required');
  }
  // Stubbed response: simple rectangle mask for walls
  return {
    walls: [
      [
        { x: 0.1, y: 0.1 },
        { x: 0.9, y: 0.1 },
        { x: 0.9, y: 0.9 },
        { x: 0.1, y: 0.9 }
      ]
    ]
  };
});

