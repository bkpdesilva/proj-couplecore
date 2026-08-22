# CoupleCore Cloud Functions

Set the server-side Gemini key before deploying:

```powershell
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

The `sendProblemMessage` callable verifies Firebase Authentication, checks couple membership and the active session, loads conversation context from Firestore, calls Gemini, and stores the generated response in the session messages subcollection.
