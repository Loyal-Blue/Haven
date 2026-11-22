# Haven

Haven grows a pixel-art town from your weekly task completion. It runs offline as a guest.

- **Town** shows your weekly percentage and projected buildings. At the end of Sunday in your local time, the town builds automatically. A productive week earns one to five buildings, rounding up one building per 20 percentage points. New districts open when more room is needed. Missed weeks are processed when you return.
- **Tasks** supports one-off, daily and weekly schedules, notes, effort and completion history.
- **Planner** shows a week at a time and lets you add or edit dated tasks.
- **Money** records manual EUR transactions, monthly spending by category and a monthly spending limit.
- **AI** connects to your Ollama model for planning and breaking down tasks.
- **More** contains hobbies, practice goals, settings and updates.

Existing Android installations can upgrade using the same signing key and keep the local save. Existing buildings stay in their districts. Automatic construction starts with the first week you open Haven 0.4.

## AI assistant

Open **AI → Set up Ollama**, enter your server and use the model name shown by `ollama list`. If both apps run on the same Linux device, the default Ollama address is `http://127.0.0.1:11434`. For Android, enter the reachable private IP and port of the computer running Ollama, or an HTTPS endpoint. Ollama must be listening on that interface and reachable from the phone. Keep a plain HTTP endpoint on a trusted private network or VPN.

Messages are sent to the server you configure. The optional **Include this week’s tasks** switch sends task titles and completion counts with the message. It starts off, and the assistant has no app write access. Chat history stays in memory until the app closes or you clear it.

## Build order

The project targets **Android → Linux → iOS**. The shared client uses Flutter 3.50.1 with Dart 3.14. Android needs a JDK and Android SDK with API 36, build-tools 36 and NDK 28.2.13676358. Linux uses GTK 3, CMake, Ninja and Clang. iOS uses macOS and Xcode.

On Arch Linux, install the Flutter SDK and Android SDK first. For Flutter unpacked at `~/development/flutter`, these commands use Fish:

```fish
fish_add_path ~/development/flutter/bin
flutter doctor -v
flutter pub get
flutter analyze
flutter test

# Android
flutter devices
flutter run -d ANDROID_DEVICE_ID
flutter build apk --release

# Linux on a machine with GTK 3, Clang, CMake, Ninja and pkg-config
flutter run -d linux
flutter build linux --release
```

The Android APK is under `build/app/outputs/flutter-apk/`. The Linux build is under `build/linux/x64/release/bundle/`. For a Linux archive with in-place updates:

```fish
tool/package_linux.sh build/linux/x64/release/bundle Haven-Linux-x86_64.tar.gz
tar -xzf Haven-Linux-x86_64.tar.gz
./Haven-Linux/haven
```

Keep the extracted folder writable by your user. Linux needs GTK 3, GLES and a graphical session.

On a Mac, run `flutter pub get`, then `flutter build ios --release --no-codesign` to check the iOS runner. A device install or an App Store build needs Xcode signing configured for the project.

## Automatic updates

The default update feed is the [Haven GitHub release feed](https://github.com/Loyal-Blue/Haven/releases/latest/download/haven-updates.json). In **More → Settings → Updates**, check immediately, turn updates off, or change the feed. With automatic updates enabled, Haven checks on launch and while it stays open, with six hours between automatic checks during a session. 

- **Android** downloads the APK, verifies the checksum, package ID and signing certificate, then asks you to open Android's installer. Android may ask once whether Haven can install updates. Keep the signing key consistent across releases.
- **Linux** downloads and verifies the archive, keeps the previous version, and switches the packaged launcher to the new version on the next launch. The app profile remains in its existing data directory. A raw Flutter build can check for updates but needs the packaged launcher to install them.
- **iOS** uses the normal Apple distribution process when released.

The GitHub Actions workflow publishes Android, Linux and `haven-updates.json` on a version tag such as `v0.4.0`. Set the secrets `HAVEN_RELEASE_KEYSTORE_BASE64`, `HAVEN_RELEASE_STORE_PASSWORD`, `HAVEN_RELEASE_KEY_ALIAS` and `HAVEN_RELEASE_KEY_PASSWORD` for a persistent Android release key. A release signed with a different key cannot replace the developer preview. Increase both the version and build number in `pubspec.yaml` for the next release. Tag builds preconfigure their repository’s public release feed. For self-hosting, generate the manifest with `python3 tool/release_manifest.py --help`, upload it and both packages to the chosen HTTPS host, then enter the manifest URL in the app.

## Project files

- `lib/domain.dart` defines the save schema and the town economy.
- `lib/store.dart` serializes app changes and commits a local snapshot before announcing success.
- `lib/main.dart`, `lib/screens.dart`, `lib/town.dart` and `lib/editors.dart` implement the client.
- `assets/world/` contains original pixel art. Regenerate it with `python3 tool/draw_world.py` and Pillow. Font licenses are under `assets/fonts/`.
- [Architecture and roadmap](docs/architecture.md) covers the data model, sync and AI design, and acceptance criteria.
