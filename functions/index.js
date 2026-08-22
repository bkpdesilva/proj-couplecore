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
