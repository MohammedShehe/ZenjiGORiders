# ZenjiGORiders — push notification setup

This source includes Android notification permission declaration, Firebase Google Services Gradle integration, the `zenjigo_rides` default channel, foreground local display, FCM token diagnostics, and token registration retry after sign-in.

## Build and test
1. Keep `android/app/google-services.json` for Firebase project `zenjigo-8ac02` and confirm its Android package name matches this app.
2. Run `flutter clean`, `flutter pub get`, then `flutter run --dart-define=ZENJIGO_API_URL=https://YOUR-DEPLOYED-HOST/api/v1` (replace with the real API URL).
3. Accept the Android notification permission prompt. If it was previously denied, enable it in Android Settings > Apps > app name > Notifications or reinstall for a clean first-run test.
4. Sign in. Confirm logs show `[Push] FCM token available: true` and `[Push] FCM token registered with backend`.
5. Trigger a real notification from the backend. Verify it appears while app is backgrounded and while foregrounded.

Push delivery cannot be guaranteed by source changes alone: the app must reach the correct deployed API, the backend must have valid Firebase Admin credentials for the same Firebase project, and the device/OS must allow notifications. No live device/build test was available during packaging.
