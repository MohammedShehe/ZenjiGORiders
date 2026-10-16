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
