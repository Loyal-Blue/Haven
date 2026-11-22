# Haven

Haven grows a pixel-art town from your weekly task completion. You can use it offline as a guest and keep an existing Haven save when upgrading.

- **Town** shows your districts, weekly score, upcoming plans, project progress and monthly finances. At the end of Sunday in your local time the town grows automatically. Each 20 percentage points, rounded up, earns a building, up to five per week. Haven catches up on missed construction when you return.
- **Todo and Routine** manage one-time tasks and tasks that recur every few days or weeks. Reset checkmarks manually or at a chosen daily or weekly time. Completion history and town credit are preserved.
- **Event** shows week and month calendars, dated tasks and project milestones. Android tasks can be added to your device calendar from their options menu. Android and iOS use local task notifications when permitted. On desktop, reminders appear while the app is open.
- **My** contains projects and subtasks, weekly and monthly reports, town growth history, and EUR spending and budgets.
- **More** contains Haven AI, settings, appearance, sync, updates and hobbies.

## Appearance

Open **More → Settings → Appearance**. Choose a preset or adjust individual colors using the sliders or hex field. The preview updates as you edit and colors apply as soon as you tap **Apply**. Black & White includes separate White and Black variants with a grayscale town. Custom colors are kept when you toggle Black & White off. Font scale, high contrast and reduced motion also save locally.

## Haven AI

Choose **More → Haven AI → Set up provider**. Use an API key and model for OpenAI, Anthropic or Google Gemini. API usage and billing are separate from ChatGPT and Claude subscriptions. Provider and model preferences are saved locally. API keys and chat history stay in memory for the current app session.

Use Ollama on the same Linux device at `http://127.0.0.1:11434`, or enter a private network or HTTPS address reachable from Android. Select a model using the name from `ollama list`. The OpenAI-compatible option accepts a custom base URL and requires HTTPS when an API key is supplied.

Choose **Photo tasks** from Todo, then take a photo on Android or iOS or choose a saved image. Confirm the image before it is sent to the selected provider. A vision-capable model creates up to 12 deduplicated tasks for today. The optional **Include this week’s tasks** switch shares task and project titles and weekly progress to help with planning. Transaction details and task notes are excluded from automatic context.

## Google sign-in and appearance sync

A Firebase project with Google Authentication and Firestore is required for sync. Guest saves work without it. Sync includes appearance preferences and accessibility settings. Tasks, finances, and other productivity data stay local.

1. Enable Google sign-in in Firebase Authentication, create the default Firestore database and deploy the rules in `firebase/`.
2. Register Android application ID `app.havenlife.haven` and the SHA-1 fingerprint of the key signing your APK. For GitHub release builds the SHA-1 is `F7:D0:41:53:51:A3:69:8C:3D:97:9C:95:C3:BC:0F:A5:87:76:43:41`.
3. Build with `--dart-define=HAVEN_FIREBASE_PROJECT=...`, `--dart-define=HAVEN_FIREBASE_WEB_API_KEY=...` and `--dart-define=HAVEN_GOOGLE_WEB_CLIENT_ID=...`. GitHub Actions accepts matching repository variables for Android.
4. On iOS register bundle ID `app.havenlife.haven`, add the reversed iOS Google client ID as a URL scheme in `ios/Runner/Info.plist`, and supply `--dart-define=HAVEN_GOOGLE_IOS_CLIENT_ID=...` alongside the previous defines.
5. On a configured Android or iOS build, choose **More → Appearance sync → Sign in with Google**. The newer saved appearance syncs automatically while signed in. Use **Sync now** to check immediately.

## Build order

Haven uses Flutter 3.50.1 and Dart 3.14. Build order is **Android → Linux → Windows → iOS**. Android requires JDK 21, API 36 and NDK 28.2.13676358.

On Arch Linux, these commands use Fish syntax:

```fish
fish_add_path ~/development/flutter/bin
flutter pub get
flutter analyze
flutter test

# Android
flutter run -d ANDROID_DEVICE_ID
flutter build apk --release

# Linux with GTK 3, Clang, CMake, Ninja and pkg-config
flutter build linux --release
tool/package_linux.sh build/linux/x64/release/bundle Haven-Linux-x86_64.tar.gz
tar -xzf Haven-Linux-x86_64.tar.gz
./Haven-Linux/haven
```

On Windows with Visual Studio's Desktop development with C++ workload, run `flutter build windows --release`. On a Mac with Xcode, run `flutter build ios --release --no-codesign`. Installing on iOS needs Apple signing and distribution.

## Automatic updates

Haven uses the [GitHub update feed](https://github.com/Loyal-Blue/Haven/releases/latest/download/haven-updates.json). Open **More → Updates** to check now or edit the feed. With automatic updates enabled, Haven checks on launch and periodically while open.

- **Android** downloads the APK, checks its checksum and signing identity, and opens Android’s installer when you choose **Install update**.
- **Linux** verifies and stages the update for the next launch when using the writable packaged launcher.
- **Windows** verifies and downloads the ZIP. Select **Show downloaded ZIP**, extract it and launch Haven from the new folder.
- **iOS** uses Apple distribution when a signed app is released.

To publish, create a version tag matching the version in `pubspec.yaml` and increment its build number. GitHub Actions publishes the Android, Linux and Windows packages with a checksummed manifest. Keep the same Android signing key so existing installations can upgrade in place. The repository uses `HAVEN_RELEASE_KEYSTORE_BASE64`, `HAVEN_RELEASE_STORE_PASSWORD`, `HAVEN_RELEASE_KEY_ALIAS` and `HAVEN_RELEASE_KEY_PASSWORD` to sign tagged Android builds.

The shared save and town logic are in `lib/domain.dart` and `lib/store.dart`. Original terrain artwork is in `assets/world/`. Font licensing is in `assets/fonts/`.
