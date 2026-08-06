# CoupleCore

A private, two-person mobile application that helps a couple strengthen communication, understand each other's emotions, avoid misunderstandings, and coordinate shared relationship activities.

CoupleCore links exactly two people into a couple and gives them a shared space for daily mood check-ins, a multi-channel emergency signal, a shared calendar, memories, private messaging, and a set of emotional-support tools. Privacy between the two partners is a core, non-negotiable value of the product.

> Project status: active development. The application is partially implemented. This document describes the target product; see the Roadmap and Feature status sections for what exists today versus what is planned. The authoritative specification is the SRS in `docs/`.

## Table of contents

- [Features](#features)
- [Tech stack](#tech-stack)
- [Architecture](#architecture)
- [Data model](#data-model)
- [Getting started](#getting-started)
- [Project structure](#project-structure)
- [Security and privacy](#security-and-privacy)
- [Feature status](#feature-status)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Features

- Accounts and authentication. Email/password, Google, and Apple sign-in, with password reset and account deletion.
- Partner linking. Link by single-use invite code or by email invitation that the partner explicitly accepts, with mutual confirmation before a couple becomes active.
- Daily mood tracker. Each partner logs one of six moods per day; both partners' current moods appear live on the dashboard.
- Happiness detector. A short daily quiz that, on a sad result, sends the partner a gentle, supportive notification.
- Emergency alert. A one-tap signal to the partner carrying an optional message and location, delivered as a full-screen notification and escalating to SMS and an automated voice call if unacknowledged.
- Shared calendar. A single home for date-based events and reminders: anniversaries, birthdays, special days, exam timetables, lecture times, and discussion times.
- Menses reminder. A separate, cycle-aware module with shared or private visibility, where an actual recorded date corrects the prediction.
- Memories. Shared photos, videos, and written notes in a timeline view.
- Messaging. A private couple chat, including quick love-notes.
- Good deeds. A tracker where a partner confirms a logged good deed to award points.
- Emotional-support tools. Love-language suggestions based on the classic five love languages, a suggestion generator for compliments and mood-boosting notes, and an AI-assisted problem-solving tool that draws on the couple's own history of resolved issues.

## Tech stack

- Client: Flutter (Dart), Material 3, targeting iOS and Android.
- Authentication: Firebase Authentication.
- Database: Cloud Firestore.
- Media storage: Firebase Cloud Storage.
- Push notifications: Firebase Cloud Messaging (FCM).
- Serverless backend: Firebase Cloud Functions (Node.js) for AI calls, emergency escalation, scheduled reminders, and unlink cleanup.
- External services (accessed only through Cloud Functions): an LLM provider for AI features and a telephony provider for emergency SMS and voice.

## Architecture

CoupleCore uses a client plus serverless design. The Flutter app talks directly to Firebase for identity, data, media, and push. Anything that requires a secret key or cross-user coordination is delegated to Cloud Functions, so provider keys never ship in the client.

- Mood: the app writes to Firestore; the partner's app listens and re-renders. A mood update never triggers a notification.
- Problem-solving (AI): the app calls a Cloud Function with the couple's relevant problem and resolution history; the function calls the LLM and returns tailored tips. The key stays server-side, and only minimal context is sent.
- Emergency: the app writes an alert with location to Firestore and invokes the escalation function, which pushes a full-screen alert and, as a fallback, sends SMS and places a voice call. The partner acknowledges back into Firestore.
- Unlink: a function deletes the couple document, its subcollections, and associated media, and clears both users' link fields.

## Data model

Data is partitioned into three scopes so that security rules stay simple and privacy is enforced by structure rather than convention.

| Scope   | Location                  | Who can access                                              |
|---------|---------------------------|------------------------------------------------------------|
| Account | `users/{uid}`             | The owner: profile, settings, link state.                  |
| Private | `users/{uid}/private/**`  | The owner only. Encrypted. Onboarding answers, private menses, sensitive notes. |
| Shared  | `couples/{coupleId}/**`   | Only the two members listed in `memberUids`.               |

Principal shared collections live under `couples/{coupleId}/`: `moods`, `moodHistory`, `calendar`, `memories`, `messages`, `goodDeeds`, `menses`, `alerts`, and `problems`. Private-by-default items are stored in the owner's private scope with a per-item share flag and are copied into the couple scope only on an explicit share action.

## Getting started

### Prerequisites

- Flutter SDK (stable channel) and Dart.
- A Firebase project with Authentication, Cloud Firestore, Cloud Storage, and Cloud Messaging enabled.
- The FlutterFire CLI and the Firebase CLI.
- Node.js and npm for Cloud Functions.

### Setup

1. Clone the repository.

   ```bash
   git clone <your-repo-url>
   cd couple_core
   ```

2. Install Flutter dependencies.

   ```bash
   flutter pub get
   ```

3. Configure Firebase for the app. This generates `lib/firebase_options.dart`.

   ```bash
   flutterfire configure
   ```

4. In the Firebase console, enable the sign-in providers you intend to use (Email/Password, Google, Apple), and enable Firestore, Storage, and Cloud Messaging.

5. Deploy security rules and indexes.

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage:rules
   ```

6. Set up Cloud Functions. Provider keys are stored in server-side configuration, never in the client.

   ```bash
   cd functions
   npm install
   # configure secrets for the LLM and telephony providers using Firebase secrets or config
   firebase deploy --only functions
   cd ..
   ```

7. Run the app.

   ```bash
   flutter run
   ```

### Configuration notes

- Do not commit secrets. Client build values are passed with `--dart-define`; server secrets live in Cloud Functions configuration or Secret Manager.
- `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are generated per Firebase project. Keep them out of version control if the project is private.

## Project structure

The application is being refactored from a single entry point into a modular layout. The target structure is:

```
lib/
  core/          app-wide utilities, theming, constants
  models/        data models
  services/      Firebase, notifications, AI, telephony clients
  features/
    auth/
    linking/
    mood/
    emergency/
    calendar/
    memories/
    messaging/
    good_deeds/
    menses/
    support_tools/
  main.dart      entry point and routing
functions/       Cloud Functions (Node.js)
docs/            specification and design documents
```

Current state: most application logic still lives in `lib/main.dart`. Modularization is the first task in the roadmap.

## Security and privacy

Privacy is a primary requirement, not an afterthought. The following rules are enforced throughout the codebase.

- Couple-scoped access. Firestore rules grant read and write on `couples/{coupleId}/**` only to the two members, and on `users/{uid}/private/**` only to the owner. No collection is left open.
- No presence disclosure. The application never reveals whether a partner is online, was recently active, or has opened the app today. There are no presence indicators, last-seen timestamps, typing indicators, or read receipts. A mood shows its last logged value until updated, so activity cannot be inferred from it.
- Private-by-default. Sensitive and personalized data is stored per partner and is shared only on an explicit action.
- Encryption of sensitive data. Sensitive private fields are encrypted so they are unreadable in a raw data export.
- Secrets stay server-side. AI and telephony calls run in Cloud Functions; keys are never bundled into the client.
- Emergency safety. The emergency feature is a private signal to the partner and is not a substitute for professional emergency services. The interface states this clearly.
- Data efficiency. On unlink, the couple document, its subcollections, and associated media are deleted, and both users' link fields are cleared, leaving no orphaned data.

## Feature status

| Area                         | Status       |
|------------------------------|--------------|
| Email/password auth, routing | Implemented  |
| Social sign-in, password reset | Planned    |
| Mood tracker with live sync  | Implemented  |
| Partner linking              | Partial      |
| Emergency send               | Implemented  |
| Emergency receive and escalation | Planned  |
| Calendar, memories, messaging, good deeds | Placeholder screens |
| Menses reminder              | Planned      |
| Notifications and reminders  | Planned      |
| AI and emotional-support tools | Planned    |

## Roadmap

The build is planned in four phases, front-loading the architecture that everything else depends on.

1. Foundation. Social sign-in and password reset, robust linking with mutual confirmation, the couple-scoped data model with security rules and data migration, and a settings screen with quiet hours.
2. Core emotional. Mood history and patterns, the happiness detector, the full emergency pipeline, and push notifications.
3. Shared life. Calendar and reminders, memories, messaging, good deeds, and the menses module.
4. AI and polish. The problem journal and AI tips, love-language suggestions, the suggestion generator, and completion of the dashboard and navigation.

## Contributing

1. Create a feature branch from `main`.
2. Keep changes small and focused, and reference the relevant requirement in the commit message where applicable.
3. Run `flutter analyze` and `flutter test` before opening a pull request.
4. Update or add Firestore security rules for any collection you touch.
5. Do not introduce presence indicators, client-side secrets, or open collections.

## License

To be determined. Update this section with the project's chosen license before any public release.
