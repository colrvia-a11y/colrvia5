# Color Canvas

A Flutter app for color palette management and visualization.

## Firebase Setup

This app uses Firebase for authentication and data storage. You have two options:

### Option 1: Quick Start (Runtime Configuration)
For immediate testing with your own Firebase project:

1. Copy `firebase.env.example` to `firebase.env`
2. Fill in your Firebase project credentials
3. Run with: `flutter run --dart-define-from-file=firebase.env`

### Option 2: Permanent Setup (Recommended)
For long-term development and production use:

1. **Automated Setup** (Windows):
   ```bash
   .\setup_firebase_permanent.ps1
   ```

2. **Manual Setup**:
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase
   flutterfire configure
   
   # Select your project and platforms
   ```

3. **Enable Authentication**:
   - Go to Firebase Console > Authentication > Sign-in method
   - Enable "Email/Password" provider

For detailed instructions, see [FIREBASE_PERMANENT_SETUP.md](FIREBASE_PERMANENT_SETUP.md).

## Getting Started

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Set up Firebase** (see above)

3. **Run the app**:
   ```bash
   flutter run
   ```

## Features

- Color palette creation and management
- Firebase authentication (email/password)
- Cross-platform support (Android, iOS, Web)
- Color visualization and editing

## Development

This project uses:
- Flutter/Dart
- Firebase (Auth, Firestore, Storage)
- Material Design 3

## Troubleshooting

### "API key not valid" errors
- Make sure you've completed Firebase setup (see above)
- Verify your Firebase project has Authentication enabled
- Check that Identity Toolkit API is enabled in Google Cloud Console

### Build issues
```bash
flutter clean
flutter pub get
flutter run
```

For more troubleshooting, see [FIREBASE_PERMANENT_SETUP.md](FIREBASE_PERMANENT_SETUP.md).