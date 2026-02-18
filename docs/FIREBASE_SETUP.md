# Firebase Setup & Configuration

This guide details how to set up the Firebase backend for the AdaptEd project.

## 1. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and follow the setup steps (name it `adapted-app` or similar).
3. Enable **Google Analytics** if desired (the code supports it).

## 2. Enable Authentication

1. In the Firebase Console, go to **Build > Authentication**.
2. Click **Get Started**.
3. Enable the following **Sign-in providers**:
   - **Email/Password**
   - **Google** (You may need to configure SHA-1 keys for Android/iOS later).

## 3. Create Cloud Firestore Database

1. Go to **Build > Firestore Database**.
2. Click **Create Database**.
3. Choose a location (e.g., `us-central1` or one close to your users).
4. Start in **Production mode** (we'll add rules below).

## 4. Security Rules

Go to the **Rules** tab in Firestore and replace the content with the following permissions. This ensures users can only read/write their own data, while Admins have broader access.

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is admin
    function isAdmin() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Users Collection
    match /users/{userId} {
      // Users can read and write their own profile
      allow read, write: if request.auth != null && request.auth.uid == userId;
      // Admins can read all profiles (optional)
      allow read: if request.auth != null && isAdmin();
    }

    // Analytics Collection
    match /analytics/{document=**} {
      // Authenticated users can log events
      allow create: if request.auth != null;
      // Only admins can read analytics
      allow read: if request.auth != null && isAdmin();
    }
  }
}
```

## 5. Data Model (Schema)

The application automatically creates user documents when they sign in or complete the quiz. You do NOT need to manually create these, but here is the schema for reference.

### Collection: `users`
**Document ID:** `<User UID>`

```json
{
  "displayName": "John Doe",
  "email": "john@example.com",
  "photoURL": "https://...",
  "role": "learner", // or "admin"
  "hasCompletedQuiz": true,
  "lastUpdated": Timestamp,
  
  // Gamefication
  "xp": 150,
  "level": 1,
  "badges": [
    {
      "id": "early_bird",
      "name": "Early Bird",
      "earnedAt": "2024-02-14T10:00:00.000Z"
    }
  ],

  // Adaptive Traits (Calculated config)
  "traits": {
    "isAutistic": false,
    "isADHD": true,
    "isDyslexic": false,
    "isDyspraxic": false,
    "learningProfileName": "The Energetic Explorer"
  }
}
```

### Collection: `analytics`
**Document ID:** Auto-generated

```json
{
  "event": "quiz_completed",
  "userId": "<User UID>",
  "timestamp": Timestamp,
  "score": 85
}
```

## 6. How to Run on Chrome

To run this project on the web (Chrome):

1. **Ensure Flutter is installed** and in your PATH.
2. **Enable Web Support** (if not already):
   ```bash
   flutter config --enable-web
   ```
3. **Run the App**:
   ```bash
   flutter run -d chrome
   ```
   *Note: If you run into CORS issues with images (firebase storage), you may need to configure CORS on your bucket or run Chrome with specific flags for development.*
