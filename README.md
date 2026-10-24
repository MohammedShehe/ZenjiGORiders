# ZenjiGO Rider App

Flutter rider application aligned to the rider-facing ZenjiGO web portal in `ZenjiGOWeb`.

## Rider flow and backend endpoints

The app uses the same `/api/v1` endpoint paths and request fields as `ZenjiGOWeb/js/api.js`:

- OTP login / signup: `POST /auth/rider/send-otp`, `POST /auth/rider/verify-otp`
- Session refresh / logout: `POST /auth/refresh`, `POST /auth/logout`
- Rider profile: `GET/PATCH /rider/me`
- Saved places: `GET/POST /rider/saved-locations`, `DELETE /rider/saved-locations/:id`
- Payment methods: `GET/POST /rider/payment-methods`, `PATCH /rider/payment-methods/:id/default`, `DELETE /rider/payment-methods/:id`
- Quote and booking: `POST /rider/rides/quote`, `POST /rider/rides`
- Ride details and tracking: `GET /rider/rides/:id`, `GET /rider/rides/:id/track`
- Cancellation / rating: `POST /rider/rides/:id/cancel`, `GET /rider/rides/:id/cancel-preview`, `POST /rider/rides/:id/rating`
- Nearby drivers / history: `GET /rider/drivers/nearby`, `GET /rider/rides`
- Wallet: `GET /rider/wallet`, `GET /rider/wallet/transactions`, `POST /rider/wallet/topup`, `GET /rider/wallet/topup/:id`
- Promotions: `GET /promos`, `POST /promos/apply`
- Parcels / tours: `GET/POST /rider/parcels`, `GET /rider/tour-packages`, `GET/POST /rider/tours`
- Chat: `GET /rider/chat`, `POST /rider/chat/support`, `GET/POST /rider/chat/:id/messages`, `POST /rider/chat/:id/read`
- Notifications: `GET /rider/notifications`, `PATCH /rider/notifications/:id/read`, `POST /rider/notifications/token`

## Configure and run

Run `flutter pub get` first so Flutter resolves the Google Maps plugin and updates `pubspec.lock`.

### API URL

```bash
flutter run --dart-define=ZENJIGO_API_URL=http://10.0.2.2:5000/api/v1
```

- Android emulator: `http://10.0.2.2:5000/api/v1`
- iOS simulator: `http://localhost:5000/api/v1`
- Physical device: use the backend computer's reachable LAN IP, e.g. `http://192.168.x.x:5000/api/v1`
- Production: use the deployed HTTPS API URL.

### Google Maps and Places

The Rider app uses the native Google Places SDK (Places API New) for destination autocomplete/details and the platform geocoder for reverse geocoding. Do not use the website key restricted to HTTP referrers in the mobile app: native app requests do not send an HTTP Referer, which causes `Requests from referer <empty> are blocked`. Create a separate key in the same Google Cloud project, enable Places API (New), and restrict it to Android apps (package name + SHA-1) or iOS apps (bundle ID). Enable Maps SDK for Android/iOS on the corresponding map key. Use the platform-specific restricted key at build time:

```bash
flutter run \
  --dart-define=ZENJIGO_API_URL=http://10.0.2.2:5000/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_PLACES_API_KEY
```

For Android, put the Android-restricted key in `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`) and pass that same Android key through `--dart-define=GOOGLE_MAPS_API_KEY=...`. For iOS, put the iOS-restricted key in `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey(...)`) and pass that same iOS key through the Dart define for the iOS build. Keep the website HTTP-referrer key separate so the website continues to work. Do not remove application restrictions to work around this error.

## Important behavior

- No demo OTP, fabricated ride history, sample promotion codes, referral codes, fake trip progress, or local-only wallet top-ups are used for the rider flow.
- Pickup location comes from device GPS. Destination selection resolves a real Google Places result to latitude/longitude before booking.
- Ride quote, booking, status, driver positions, history, wallet transactions, saved places, payment methods, promotions, tour packages, and chat data are loaded from backend endpoints.
- A successful top-up request does not locally increase the balance; the backend/payment provider remains authoritative.
- API/network failures are surfaced in the UI where relevant. A working backend, valid rider account, and correctly configured Google Maps/Places key are required for live behavior.

## Build

```bash
flutter pub get
flutter analyze
flutter build apk --release --dart-define=ZENJIGO_API_URL=https://YOUR-BACKEND-HOST/api/v1
```

This source archive was edited in an environment without the Flutter SDK, so a Flutter build/analyze run has not been performed here. Please run the commands above before deployment.

## API, six-digit OTP and live maps

- Rider sign-in and sign-up use a six-digit OTP field and require exactly six digits before verification.
- API routes are the same `/api/v1` routes used by `ZenjiGOWeb/js/api.js`.
- Default API URL is `http://10.0.2.2:5000/api/v1` for the Android emulator. For a physical phone, pass your backend's LAN or HTTPS URL using `--dart-define=ZENJIGO_API_URL=http://YOUR_LAN_IP:5000/api/v1`.
- The Rider app must use a separate Android/iOS application-restricted Places SDK key; do not reuse the website HTTP-referrer key for mobile REST calls. Build with `--dart-define=GOOGLE_MAPS_API_KEY=YOUR_PLATFORM_RESTRICTED_KEY` and configure the matching native Maps SDK key in AndroidManifest.xml or AppDelegate.swift.
- Maps use device GPS, backend-provided nearby drivers, Google Places predictions/details, and backend ride quote/create/tracking APIs. No local ride is fabricated if the server fails to return a ride ID.


## Rider registration flow alignment (updated)

- Registration collects full name, phone, email, Island, and Region / Area before requesting the email OTP, matching `ZenjiGOWeb/rider/register.html`.
- OTP sending does not parse optional response fields into fixed types. The API call is considered successful based on the HTTP/API response.
- The registration profile (full name, Island, Region / Area) is sent to `POST /auth/rider/verify-otp`; the app only stores tokens and opens the next step after verification returns a rider account.
- Island and Region / Area are plain text fields, matching the website registration form. District and Ward are not required by this registration flow.
- API errors are converted to readable text instead of assuming a server error message is a String.

Build/test note: this archive was source-checked and ZIP integrity-checked. Flutter/Dart SDK was not available in this environment, so a Flutter compile or live backend registration test could not be run.

Runtime type-safety fix: rider profile fields and IDs returned as numeric JSON values are normalized to strings before creating the typed user model. Also removed unsafe String casts from the ride/payment selector.

## Maps, routes and live tracking (updated)

- **Road-following routes.** `lib/core/utils/directions_service.dart` calls the Google Routes API and now sends the
  app identity headers (`X-Android-Package` + `X-Android-Cert`, or `X-Ios-Bundle-Identifier`). App-restricted keys are
  rejected (HTTP 403) without them, which is why routes used to collapse into a straight line.
  If Google is unreachable the service falls back to OSRM (OpenStreetMap roads) and only then to a dashed straight line,
  which the UI labels as approximate. Run with `flutter run` and watch the console for `DirectionsService:` lines to see
  exactly why Google declined, if it ever does.
- **Key checklist (Google Cloud Console):** the key's *API restrictions* must include **Routes API**, and its
  *Android restrictions* must list `applicationId` + the SHA-1 of every signing certificate you install with
  (debug, release and, if you use Play App Signing, the Play signing certificate).
- **Shared map kit** in `lib/core/map/`: `map_style.dart` (light/dark map styles, cased route lines),
  `map_markers.dart` (crisp custom pins), `map_motion.dart` (smooth vehicle movement), `trip_map.dart` (reusable
  route map), `map_widgets.dart` (floating buttons / chips).
- Run `flutter pub get` after pulling this update (adds `package_info_plus`).
