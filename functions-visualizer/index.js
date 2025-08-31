// functions-visualizer/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const JOBS = new Map();

exports.renderFast = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const jobId = 'job_' + Date.now();
  const previewUrl = 'https://picsum.photos/seed/' + Math.random().toString(36).slice(2) + '/800/450';
  JOBS.set(jobId, { jobId, status: 'preview', previewUrl, resultUrl: null });
  return JOBS.get(jobId);
});

exports.renderHq = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const jobId = 'job_' + Date.now();
  JOBS.set(jobId, { jobId, status: 'queued', previewUrl: null, resultUrl: null });
  // Simulate async completion
  setTimeout(() => {
    JOBS.set(jobId, { jobId, status: 'complete', previewUrl: null, resultUrl: 'https://picsum.photos/seed/' + Math.random().toString(36).slice(2) + '/1600/900' });
  }, 8000);
  return JOBS.get(jobId);
});

exports.getJob = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const { jobId } = data;
  return JOBS.get(jobId) || { jobId, status: 'unknown' };
});

