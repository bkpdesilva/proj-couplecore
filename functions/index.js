const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { defineSecret } = require('firebase-functions/params');
const { HttpsError, onCall } = require('firebase-functions/v2/https');

initializeApp();

const db = getFirestore();
const geminiApiKey = defineSecret('GEMINI_API_KEY');
const modelName = 'gemini-3.6-flash';

const systemInstruction = [
    'You are a compassionate relationship counselor AI helping a couple work through their problems together.',
    'Both partners share this conversation. Give balanced, empathetic advice that considers both perspectives equally.',
    'Be practical, concise, and constructive. Avoid taking sides.',
    "Draw on the couple's previous solved problems to give more personalised guidance.",
].join(' ');

function requireString(value, field, maxLength) {
    if (typeof value !== 'string' || value.trim().length === 0) {
        throw new HttpsError('invalid-argument', `${field} is required.`);
    }
    if (value.length > maxLength) {
        throw new HttpsError('invalid-argument', `${field} is too long.`);
    }
    return value.trim();
}

function toGeminiContent(message) {
    return {
        role: message.role === 'model' ? 'model' : 'user',
        parts: [{ text: message.content }],
    };
}

exports.sendProblemMessage = onCall(
    { region: 'us-central1', secrets: [geminiApiKey], timeoutSeconds: 60 },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError('unauthenticated', 'Sign-in is required.');
        }

        const coupleId = requireString(request.data?.coupleId, 'coupleId', 128);
        const sessionId = requireString(request.data?.sessionId, 'sessionId', 128);
        const content = requireString(request.data?.content, 'content', 4000);
        const uid = request.auth.uid;

        const coupleRef = db.collection('couples').doc(coupleId);
        const sessionRef = coupleRef.collection('problemSessions').doc(sessionId);
        const [coupleSnap, sessionSnap] = await Promise.all([
            coupleRef.get(),
            sessionRef.get(),
        ]);

        const memberUids = coupleSnap.data()?.memberUids;
        if (!coupleSnap.exists || !Array.isArray(memberUids) || !memberUids.includes(uid)) {
            throw new HttpsError('permission-denied', 'You are not a member of this couple.');
        }
        if (!sessionSnap.exists || sessionSnap.data()?.status !== 'active') {
            throw new HttpsError('failed-precondition', 'This problem session is not active.');
        }

        const userName = request.data?.senderName?.trim() || 'Partner';
        const messagesSnap = await sessionRef.collection('messages')
            .orderBy('createdAt', 'asc')
            .get();
        const solvedSnap = await coupleRef.collection('solvedProblems')
            .orderBy('createdAt', 'desc')
            .limit(5)
            .get();

        const priorMessages = messagesSnap.docs.map((doc) => doc.data());
        const solvedContext = solvedSnap.docs
            .map((doc) => doc.data())
            .map((problem) => `- ${problem.problem} Resolved by: ${problem.solution}`)
            .join('\n');
        const instruction = solvedContext
            ? `${systemInstruction}\n\nPrevious solved problems from this couple:\n${solvedContext}`
            : systemInstruction;

        await sessionRef.collection('messages').add({
            role: 'user',
            content,
            senderUid: uid,
            senderName: userName,
            createdAt: FieldValue.serverTimestamp(),
        });
        await sessionRef.update({
            updatedAt: FieldValue.serverTimestamp(),
            lastMessage: content,
        });

        const response = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(geminiApiKey.value())}`,
            {
                method: 'POST',
                headers: { 'content-type': 'application/json' },
                body: JSON.stringify({
                    systemInstruction: { parts: [{ text: instruction }] },
                    contents: [...priorMessages.map(toGeminiContent), { role: 'user', parts: [{ text: content }] }],
                    generationConfig: { temperature: 0.7, maxOutputTokens: 800 },
                }),
            },
        );

        if (!response.ok) {
            console.error('Gemini request failed', response.status, await response.text());
            throw new HttpsError('internal', 'The AI counselor could not respond.');
        }

        const payload = await response.json();
        const aiText = payload.candidates?.[0]?.content?.parts
            ?.map((part) => part.text || '')
            .join('')
            .trim();
        if (!aiText) {
            throw new HttpsError('internal', 'The AI counselor returned an empty response.');
        }

        await sessionRef.collection('messages').add({
            role: 'model',
            content: aiText,
            senderName: 'AI Counselor',
            createdAt: FieldValue.serverTimestamp(),
        });
        await sessionRef.update({
            updatedAt: FieldValue.serverTimestamp(),
            lastMessage: aiText,
        });

        return { response: aiText };
    },
);

exports.solveProblemSummary = onCall(
    { region: 'us-central1', secrets: [geminiApiKey], timeoutSeconds: 60 },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError('unauthenticated', 'Sign-in is required.');
        }

        const coupleId = requireString(request.data?.coupleId, 'coupleId', 128);
        const sessionId = requireString(request.data?.sessionId, 'sessionId', 128);
        const uid = request.auth.uid;
        const coupleRef = db.collection('couples').doc(coupleId);
        const sessionRef = coupleRef.collection('problemSessions').doc(sessionId);
        const [coupleSnap, sessionSnap] = await Promise.all([
            coupleRef.get(),
            sessionRef.get(),
        ]);

        const memberUids = coupleSnap.data()?.memberUids;
        if (!coupleSnap.exists || !Array.isArray(memberUids) || !memberUids.includes(uid)) {
            throw new HttpsError('permission-denied', 'You are not a member of this couple.');
        }
        if (!sessionSnap.exists) {
            throw new HttpsError('not-found', 'This problem session does not exist.');
        }

        const messagesSnap = await sessionRef.collection('messages')
            .orderBy('createdAt', 'asc')
            .get();
        const transcript = messagesSnap.docs
            .map((doc) => {
                const message = doc.data();
                const speaker = message.role === 'model'
                    ? 'Counselor'
                    : (message.senderName || 'Partner');
                return `${speaker}: ${message.content || ''}`;
            })
            .join('\n');
        if (!transcript.trim()) {
            throw new HttpsError('failed-precondition', 'This session has no messages to summarize.');
        }

        const prompt = `Summarize this couple's problem-solving conversation as it is being marked solved. Respond with strict JSON only — no markdown fences, no commentary, nothing outside the object — matching exactly this shape:
{"problem": "...", "solution": "...", "impact": "..."}

- problem: one or two sentences describing the problem that was raised.
- solution: one or two sentences describing how it was resolved or what was agreed, based only on what is in the conversation below.
- impact: one sentence on how this affected the couple or their relationship, based only on what is in the conversation below.

Conversation:
${transcript}`;
        const response = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(geminiApiKey.value())}`,
            {
                method: 'POST',
                headers: { 'content-type': 'application/json' },
                body: JSON.stringify({
                    contents: [{ role: 'user', parts: [{ text: prompt }] }],
                    generationConfig: { temperature: 0.2, maxOutputTokens: 500 },
                }),
            },
        );

        if (!response.ok) {
            console.error('Gemini summary request failed', response.status, await response.text());
            throw new HttpsError('internal', 'The AI counselor could not summarize this problem.');
        }

        const payload = await response.json();
        const text = payload.candidates?.[0]?.content?.parts
            ?.map((part) => part.text || '')
            .join('')
            .trim();
        if (!text) {
            throw new HttpsError('internal', 'The AI counselor returned an empty summary.');
        }

        const start = text.indexOf('{');
        const end = text.lastIndexOf('}');
        if (start === -1 || end < start) {
            throw new HttpsError('internal', 'The AI counselor returned an invalid summary.');
        }

        let record;
        try {
            record = JSON.parse(text.slice(start, end + 1));
        } catch (_) {
            throw new HttpsError('internal', 'The AI counselor returned an invalid summary.');
        }
        if (
            typeof record.problem !== 'string' || !record.problem.trim() ||
            typeof record.solution !== 'string' || !record.solution.trim() ||
            typeof record.impact !== 'string' || !record.impact.trim()
        ) {
            throw new HttpsError('internal', 'The AI counselor returned an incomplete summary.');
        }

        return {
            problem: record.problem.trim(),
            solution: record.solution.trim(),
            impact: record.impact.trim(),
        };
    },
);
