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

The web portal uses Google Maps JavaScript and Places. The rider app now uses the Google Maps native SDK for maps and Google Places Autocomplete/Place Details for destination selection. The existing public key from the web config is currently wired in the platform files and is used as the Places default. Google Cloud keys often have platform/referrer restrictions: if this key is browser-restricted, replace it with a key configured for the Android Maps SDK, iOS Maps SDK, and Places API. Set the Places key at build time if needed:

```bash
flutter run \
  --dart-define=ZENJIGO_API_URL=http://10.0.2.2:5000/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_PLACES_API_KEY
```

For Android, update `android/app/src/main/AndroidManifest.xml` `com.google.android.geo.API_KEY`. For iOS, update `ios/Runner/AppDelegate.swift` `GMSServices.provideAPIKey(...)`. Restrict keys to your app identifiers and only the required APIs before production release.

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
- The Google Maps/Places key matches `ZenjiGOWeb/js/config.js`. Restrict/authorize it for Android, iOS and the required Google Maps SDKs and Places/Geocoding APIs. You may override the Flutter Places key with `--dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY`; native Maps SDK keys must also be configured for each platform.
- Maps use device GPS, backend-provided nearby drivers, Google Places predictions/details, and backend ride quote/create/tracking APIs. No local ride is fabricated if the server fails to return a ride ID.


## Rider registration flow alignment (updated)

- Registration collects full name, phone, email, Island, and Region / Area before requesting the email OTP, matching `ZenjiGOWeb/rider/register.html`.
- OTP sending does not parse optional response fields into fixed types. The API call is considered successful based on the HTTP/API response.
- The registration profile (full name, Island, Region / Area) is sent to `POST /auth/rider/verify-otp`; the app only stores tokens and opens the next step after verification returns a rider account.
- Island and Region / Area are plain text fields, matching the website registration form. District and Ward are not required by this registration flow.
- API errors are converted to readable text instead of assuming a server error message is a String.

Build/test note: this archive was source-checked and ZIP integrity-checked. Flutter/Dart SDK was not available in this environment, so a Flutter compile or live backend registration test could not be run.

Runtime type-safety fix: rider profile fields and IDs returned as numeric JSON values are normalized to strings before creating the typed user model. Also removed unsafe String casts from the ride/payment selector.
