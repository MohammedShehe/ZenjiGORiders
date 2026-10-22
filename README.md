# ZenjiGO Riders

Flutter Rider app for **ZenjiGO** — wired to the live ZenjiGO backend API.

## Integrated flows

| Feature | API |
|---------|-----|
| Send / verify OTP (login & signup) | `POST /auth/rider/send-otp`, `POST /auth/rider/verify-otp` |
| Profile load / update | `GET/PATCH /rider/me` |
| Ride quote | `POST /rider/rides/quote` |
| Create ride | `POST /rider/rides` |
| Cancel ride | `POST /rider/rides/:id/cancel` |
| Rate ride | `POST /rider/rides/:id/rating` |
| Ride history | `GET /rider/rides` |
| Wallet balance & transactions | `GET /rider/wallet`, `GET /rider/wallet/transactions` |
| Wallet top-up | `POST /rider/wallet/topup` |
| Apply promo | `POST /promos/apply` |
| Book parcel | `POST /rider/parcels` |
| Tour packages / book | `GET /rider/tour-packages`, `POST /rider/tours` |
| Saved locations | `GET/POST/DELETE /rider/saved-locations` |
| Payment methods | `GET/POST/DELETE /rider/payment-methods` |
| Chat | `GET /rider/chat`, messages endpoints |
| JWT refresh | automatic on 401 |
| Sign out | clears tokens + logout |

## Configure API URL

```bash
flutter run --dart-define=ZENJIGO_API_URL=http://10.0.2.2:5000/api/v1
```

- Android emulator: `http://10.0.2.2:5000/api/v1`
- iOS simulator: `http://localhost:5000/api/v1`
- Physical device: your machine LAN IP

## Run

```bash
# Backend first
cd ZenjiGOAdmin/backend && npm install && npm run migrate && npm run seed && npm run dev

# Rider app
cd ZenjiGORiders
flutter pub get
flutter run --dart-define=ZENJIGO_API_URL=http://10.0.2.2:5000/api/v1
```

## Notes

- Map uses `flutter_map` (OpenStreetMap tiles) — no Google key required.
- Geolocator is available for real GPS; onboarding grants location when possible.
- Payment top-up creates a pending payment on the server; Admin can complete it, or wire a real PSP webhook later.

## Live backend configuration

The app now defaults to `http://10.0.2.2:5000/api/v1` for the Android emulator (the emulator's host-machine alias). Set the real backend URL when building:

```bash
flutter run --dart-define=ZENJIGO_API_URL=https://YOUR-BACKEND-HOST/api/v1
flutter build apk --release --dart-define=ZENJIGO_API_URL=https://YOUR-BACKEND-HOST/api/v1
```

A physical Android device cannot use `10.0.2.2`; configure the reachable LAN/deployed HTTPS backend URL with `ZENJIGO_API_URL`. The backend must expose the same `/api/v1` rider routes used by the ZenjiGO web portal.

Booking now requires a destination selected from saved locations (so a real latitude/longitude is sent; arbitrary typed text is no longer assigned fabricated coordinates). Pickup uses device geolocation and nearby-driver pins come from `/rider/drivers/nearby`. Ride status and driver coordinates are polled from `/rider/rides/:id` and `/rider/rides/:id/track`; the app no longer fabricates a driver or auto-advances ride status. Ratings are submitted to the backend, and failed wallet top-ups no longer credit the wallet locally.

The web portal currently uses Google Maps JavaScript + Places Autocomplete, while this Flutter app uses live Carto basemap tiles via `flutter_map`. The web's JavaScript-restricted Google Maps key is not suitable for native Maps SDK use. To use Google Maps natively, configure a separate Android-restricted Maps SDK key and enable the Maps SDK for Android; Places autocomplete also requires a key with Places API enabled. This archive intentionally does not embed additional API secrets.
