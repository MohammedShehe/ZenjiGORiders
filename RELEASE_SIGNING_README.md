# ZenjiGO Riders — Google Play release signing

The previous Android release build was explicitly configured to use the **debug** signing key. This project now uses a dedicated release/upload keystore and deliberately refuses to build a release APK/AAB until the signing credentials are configured.

## 1. Create your upload keystore (Windows)

Open PowerShell in the extracted `ZenjiGORiders` project folder and run:

```powershell
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Choose and securely save the keystore password, key password, and certificate details. Do not lose the keystore or passwords. Keep a secure backup. If this is an update to an app already published, use the same existing upload key if you have one; do not create a new key without checking your Play App Signing setup.

## 2. Configure Gradle credentials

Copy `android/key.properties.example` to `android/key.properties`, then replace all placeholders:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

The `storeFile` path is relative to the `android/` directory. The provided `android/.gitignore` already excludes `key.properties` and `.jks` files. Never upload these secrets to Git or share them in support chats.

## 3. Build the Google Play App Bundle

From the project root:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

The resulting file should be:

`build/app/outputs/bundle/release/app-release.aab`

Upload that `.aab` in Google Play Console. Do not upload a debug APK.

## 4. Important

- This ZIP contains the release-signing configuration and instructions, **not** a generated private keystore. The keystore must be generated and kept securely by the app owner.
- If this app has already been published, preserve the existing upload key. Google Play App Signing normally uses your upload key to authenticate uploads and manages the app-signing key.
- Increment `version: 1.0.0+1` in `pubspec.yaml` before each subsequent Play release (increase the build number after `+`).
- I could not compile the AAB in this environment because the Flutter SDK is not installed here. Build it locally after creating `key.properties` and the keystore.
